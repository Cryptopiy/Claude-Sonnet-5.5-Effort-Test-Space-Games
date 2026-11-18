extends Node
## Renders terrain_height() on the GPU for N directions into a tiny viewport and compares with PlanetData.height_at() on the CPU.

const COUNT := 24
const SHADER := """
shader_type canvas_item;
uniform float t_radius = 5000.0;
uniform float t_freq = 2.0;
uniform vec3 t_seed_off = vec3(0.0);
uniform int t_seed = 0;
uniform float t_a_cont = 100.0;
uniform float t_a_hill = 150.0;
uniform int t_hill_oct = 8;
uniform float t_hill_gain = 0.5;
uniform float t_a_ridge = 0.0;
uniform float t_ridge_freq = 1.0;
uniform float t_ridge_lo = 0.05;
uniform float t_ridge_hi = 0.45;
uniform int t_ridge_oct = 5;
uniform float t_a_dune = 0.0;
uniform float t_dune_freq = 16.0;
uniform float t_a_crater = 0.0;
uniform float t_crater_freq = 2.5;
uniform float t_a_detail = 2.0;
uniform float t_detail_cell = 24.0;
uniform float t_terrace = 0.0;
uniform float t_terrace_step = 30.0;
#include "res://shaders/inc/tnoise.gdshaderinc"
#include "res://shaders/inc/terrain_fn.gdshaderinc"
uniform vec4 dirs[24];
void fragment() {
	int i = int(floor(UV.x * 24.0));
	vec3 dir = normalize(dirs[i].xyz);
	float h = terrain_height(dir, 0.0);
	float v = clamp((h + 2048.0) / 4096.0, 0.0, 0.99999) * 16777215.0;
	float r = floor(v / 65536.0);
	float g = floor((v - r * 65536.0) / 256.0);
	float b = floor(v - r * 65536.0 - g * 256.0);
	COLOR = vec4(r / 255.0, g / 255.0, b / 255.0, 1.0);
}
"""


func _ready() -> void:
	var worst := 0.0
	for biome in [PlanetData.Biome.LUSH, PlanetData.Biome.DESERT, PlanetData.Biome.BARREN, PlanetData.Biome.VOLCANIC, PlanetData.Biome.EXOTIC]:
		var d := Biomes.make(biome, 11, 4800.0, "P")
		var vp := SubViewport.new()
		vp.size = Vector2i(COUNT, 1)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.transparent_bg = false
		add_child(vp)
		var cr := ColorRect.new()
		cr.size = Vector2(COUNT, 1)
		var sh := Shader.new()
		sh.code = SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		var tu := d.terrain_uniforms()
		for k in tu:
			m.set_shader_parameter(k, tu[k])
		var dirs := PackedVector4Array()
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var dv: Array = []
		for i in COUNT:
			var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			dv.append(v)
			dirs.append(Vector4(v.x, v.y, v.z, 0))
		m.set_shader_parameter("dirs", dirs)
		cr.material = m
		vp.add_child(cr)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var img := vp.get_texture().get_image()
		var maxerr := 0.0
		var line := ""
		for i in COUNT:
			var c := img.get_pixel(i, 0)
			var v: float = (roundf(c.r * 255.0) * 65536.0 + roundf(c.g * 255.0) * 256.0 + roundf(c.b * 255.0)) / 16777215.0
			var gpu: float = v * 4096.0 - 2048.0
			var cpu := d.height_at(dv[i])
			maxerr = maxf(maxerr, absf(gpu - cpu))
			if i < 3:
				line += " [gpu %.3f cpu %.3f]" % [gpu, cpu]
		print("biome ", PlanetData.BIOME_NAMES[biome], " max |gpu-cpu| = ", maxerr, line)
		worst = maxf(worst, maxerr)
		vp.queue_free()
	print("PARITY worst error m: ", worst)
	get_tree().quit()
