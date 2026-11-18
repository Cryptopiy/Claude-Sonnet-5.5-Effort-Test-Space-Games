class_name StarBody
extends Body
## The system's star: emissive sphere + corona billboard. Also owns the colour/intensity used for lighting.

var star_color := Color(1.0, 0.9, 0.7)
var light_energy := 1.6
var sphere: MeshInstance3D
var corona: MeshInstance3D
var corona_mat: ShaderMaterial
var star_mat: ShaderMaterial


func build(r: float, col: Color, lum: float, seed: int) -> void:
	kind = "star"
	radius = r
	star_color = col
	light_energy = 1.5 * lum
	display_name = "Star"
	sphere = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 96
	sm.rings = 48
	sphere.mesh = sm
	star_mat = ShaderMaterial.new()
	star_mat.shader = load("res://shaders/star.gdshader")
	star_mat.set_shader_parameter("star_col", col)
	star_mat.set_shader_parameter("intensity", 5.0)
	star_mat.set_shader_parameter("seed", seed & 0xFFFF)
	sphere.material_override = star_mat
	sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sphere)
	corona = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	corona.mesh = q
	corona.scale = Vector3(r * 2.0 * 7.0, r * 2.0 * 7.0, 1.0)
	corona_mat = ShaderMaterial.new()
	corona_mat.shader = load("res://shaders/corona.gdshader")
	corona_mat.set_shader_parameter("glow_col", col.lerp(Color.WHITE, 0.25))
	corona_mat.set_shader_parameter("core", 1.0 / 7.0)
	corona_mat.set_shader_parameter("intensity", 1.2)
	corona.material_override = corona_mat
	corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corona.extra_cull_margin = 16384.0
	add_child(corona)
