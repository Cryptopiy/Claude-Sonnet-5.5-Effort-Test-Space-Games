class_name WeatherFx
extends Node3D
## Camera-following weather: rain, snow, ash+embers, dust storms, glowing spores. Strength follows slow "storm" cycles
## (per planet seed) scaled by the biome's weather chance. Exposes `weather_mul` (hazard multiplier) and `kind`.

var world: SpaceWorld
var systems: Dictionary = {}
var kind: String = "none"
var intensity: float = 0.0
var weather_mul: float = 1.0
var _soft_tex: GradientTexture2D

func setup(w: SpaceWorld) -> void:
	world = w
	name = "WeatherFx"
	_soft_tex = GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_soft_tex.gradient = g
	_soft_tex.fill = GradientTexture2D.FILL_RADIAL
	_soft_tex.fill_from = Vector2(0.5, 0.5)
	_soft_tex.fill_to = Vector2(1.0, 0.5)
	_soft_tex.width = 64
	_soft_tex.height = 64

func _make_system(k: String) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	p.process_material = pm
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.layers = 1 << 19
	p.visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 80, 120))
	p.fixed_fps = 0
	p.emitting = false
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var mesh: Mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	match k:
		"rain":
			var b := BoxMesh.new()
			b.size = Vector3(0.012, 0.9, 0.012)
			mesh = b
			mat.albedo_color = Color(0.75, 0.85, 1.0, 0.35)
			p.amount = 5200
			p.lifetime = 1.1
			pm.emission_box_extents = Vector3(34, 1, 34)
			pm.direction = Vector3(0, -1, 0)
			pm.initial_velocity_min = 24.0
			pm.initial_velocity_max = 30.0
			pm.gravity = Vector3.ZERO
			pm.spread = 2.0
		"snow":
			var q := QuadMesh.new()
			q.size = Vector2(0.09, 0.09)
			mesh = q
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_texture = _soft_tex
			mat.albedo_color = Color(1, 1, 1, 0.85)
			p.amount = 4200
			p.lifetime = 7.0
			pm.emission_box_extents = Vector3(30, 1, 30)
			pm.direction = Vector3(0, -1, 0)
			pm.initial_velocity_min = 1.6
			pm.initial_velocity_max = 3.0
			pm.spread = 25.0
			pm.gravity = Vector3.ZERO
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.6
			pm.turbulence_noise_scale = 2.5
			pm.scale_min = 0.5
			pm.scale_max = 1.6
		"ash":
			var q2 := QuadMesh.new()
			q2.size = Vector2(0.12, 0.12)
			mesh = q2
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_texture = _soft_tex
			mat.albedo_color = Color(1, 1, 1, 0.9)
			p.amount = 3200
			p.lifetime = 7.0
			pm.emission_box_extents = Vector3(30, 1, 30)
			pm.direction = Vector3(0, -1, 0)
			pm.initial_velocity_min = 1.0
			pm.initial_velocity_max = 2.8
			pm.spread = 40.0
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 1.2
			pm.turbulence_noise_scale = 2.0
			pm.scale_min = 0.5
			pm.scale_max = 2.0
			var grad := Gradient.new()
			grad.set_color(0, Color(0.15, 0.13, 0.12, 0.9))
			grad.set_color(1, Color(1.0, 0.45, 0.1, 1.0))
			var gt := GradientTexture1D.new()
			gt.gradient = grad
			pm.color_initial_ramp = gt
		"dust":
			var q3 := QuadMesh.new()
			q3.size = Vector2(1.8, 1.8)
			mesh = q3
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_texture = _soft_tex
			mat.albedo_color = Color(0.74, 0.54, 0.34, 0.05)
			mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
			mat.distance_fade_min_distance = 2.5
			mat.distance_fade_max_distance = 10.0
			p.amount = 420
			p.lifetime = 3.0
			pm.emission_box_extents = Vector3(40, 10, 40)
			pm.direction = Vector3(1, 0, 0.2)
			pm.initial_velocity_min = 16.0
			pm.initial_velocity_max = 26.0
			pm.spread = 8.0
			pm.gravity = Vector3.ZERO
			pm.scale_min = 0.7
			pm.scale_max = 1.8
		"spores":
			var q4 := QuadMesh.new()
			q4.size = Vector2(0.16, 0.16)
			mesh = q4
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_texture = _soft_tex
			mat.albedo_color = Color(0.7, 1.0, 0.45, 0.9)
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			p.amount = 1200
			p.lifetime = 9.0
			pm.emission_box_extents = Vector3(28, 6, 28)
			pm.direction = Vector3(0, 1, 0)
			pm.initial_velocity_min = 0.3
			pm.initial_velocity_max = 1.2
			pm.spread = 80.0
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.8
			pm.turbulence_noise_scale = 3.0
			pm.scale_min = 0.5
			pm.scale_max = 2.2
			var grad2 := Gradient.new()
			grad2.set_color(0, Color(0.5, 1.0, 0.4, 1))
			grad2.set_color(1, Color(0.8, 0.4, 1.0, 1))
			var gt2 := GradientTexture1D.new()
			gt2.gradient = grad2
			pm.color_initial_ramp = gt2
	p.draw_pass_1 = mesh
	p.material_override = mat
	add_child(p)
	return p

## per frame: `cam` is the game camera
func update_weather(delta: float, cam: Camera3D, pc: PlayerController) -> void:
	var target_kind: String = "none"
	var target_int: float = 0.0
	if world.frame_idx >= 0:
		var pl: Planet = world.planets[world.frame_idx]
		var wx: Dictionary = pl.data.profile.get("weather", {})
		var k: String = String(wx.get("type", "none"))
		if k != "none" and world.air > 0.05:
			var chance: float = float(wx.get("chance", 0.0))
			var sd: float = float(pl.data.seed_i % 997)
			# slow storm cycle: strength rises above a threshold that depends on `chance`
			var cyc: float = 0.5 + 0.5 * sin(world.time * 0.0125 + sd) * (0.6 + 0.4 * sin(world.time * 0.0041 + sd * 1.7))
			var thr: float = 1.0 - chance
			target_int = clampf((cyc - thr * 0.75) / 0.3, 0.0, 1.0) * float(wx.get("intensity", 1.0))
			target_kind = k
			# fade out above the clouds
			target_int *= clampf(1.0 - (world.altitude - 150.0) / 500.0, 0.0, 1.0)
	if target_kind != kind and intensity < 0.04:
		kind = target_kind
	if kind != "none" and kind != target_kind:
		target_int = 0.0
	intensity = lerpf(intensity, target_int, 1.0 - exp(-0.8 * delta))
	weather_mul = 1.0 + 0.8 * intensity if kind != "none" else 1.0
	for k2 in systems.keys():
		(systems[k2] as GPUParticles3D).emitting = false
	if kind == "none" or intensity < 0.03:
		return
	if not systems.has(kind):
		systems[kind] = _make_system(kind)
	var ps: GPUParticles3D = systems[kind]
	if kind == "dust":
		# unshaded particles must follow the daylight, otherwise a dust storm glows at night
		var day: float = clampf(world.sun_up_at_viewer * 2.0 + 0.35, 0.0, 1.0)
		var dm: StandardMaterial3D = ps.material_override as StandardMaterial3D
		var f: float = lerpf(0.16, 1.0, day)
		dm.albedo_color = Color(0.74 * f, 0.54 * f, 0.34 * f, 0.05)
	ps.emitting = true
	ps.amount_ratio = clampf(intensity, 0.05, 1.0)
	var up: Vector3 = cam.global_position.normalized()
	var xf := Transform3D(U.basis_from_up(up), cam.global_position + up * (14.0 if kind == "rain" else 8.0))
	if kind == "dust":
		xf.origin = cam.global_position + up * 3.0
	if kind == "spores":
		xf.origin = cam.global_position + up * 1.0
	ps.global_transform = xf
	var pm: ParticleProcessMaterial = ps.process_material
	match kind:
		"rain":
			pm.gravity = -up * 4.0
		"snow", "ash":
			pm.gravity = -up * 0.8
		"spores":
			pm.gravity = up * 0.05
		_:
			pm.gravity = Vector3.ZERO
