class_name WeatherFx
extends Node3D
## GPU-particle weather (rain, snow, dust, ash, spores) that follows the camera. Intensity cycles over time per planet.

var gp: GPUParticles3D
var pm: ParticleProcessMaterial
var kind := ""
var level := 0.0            # 0..1 current intensity (also used for fog / wind audio)
var target_level := 0.0
var t_off := 0.0


func _ready() -> void:
	gp = GPUParticles3D.new()
	gp.local_coords = false
	gp.emitting = false
	gp.visibility_aabb = AABB(Vector3(-80, -80, -80), Vector3(160, 160, 160))
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gp)


func configure(d: PlanetData) -> void:
	if d == null or d.weather == "none" or d.atmo_height <= 0.0:
		kind = ""
		gp.emitting = false
		return
	if kind == d.weather:
		return
	kind = d.weather
	t_off = float(d.seed % 1000)
	pm = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.direction = Vector3(0, -1, 0)
	pm.gravity = Vector3.ZERO
	var mesh: Mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	var col := d.weather_color
	match kind:
		"rain":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.012, 0.6, 0.012)
			mesh = bm
			mat.albedo_color = Color(col.r, col.g, col.b, 0.32)
			pm.emission_box_extents = Vector3(32, 2, 32)
			pm.initial_velocity_min = 24.0
			pm.initial_velocity_max = 28.0
			pm.spread = 2.0
			gp.amount = 3200
			gp.lifetime = 1.3
		"snow":
			var qm := QuadMesh.new()
			qm.size = Vector2(0.09, 0.09)
			mesh = qm
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_color = Color(1, 1, 1, 0.85)
			pm.emission_box_extents = Vector3(30, 2, 30)
			pm.initial_velocity_min = 2.0
			pm.initial_velocity_max = 3.6
			pm.spread = 25.0
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 1.6
			pm.turbulence_noise_scale = 3.0
			pm.gravity = Vector3(3.0, 0, 1.0)
			gp.amount = 4200
			gp.lifetime = 8.0
		"dust":
			var qm2 := QuadMesh.new()
			qm2.size = Vector2(0.7, 0.7)
			mesh = qm2
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_texture = Textures.soft_dot()
			mat.albedo_color = Color(col.r, col.g, col.b, 0.1)
			pm.emission_box_extents = Vector3(32, 6, 32)
			pm.direction = Vector3(1, -0.05, 0.3)
			pm.initial_velocity_min = 12.0
			pm.initial_velocity_max = 20.0
			pm.spread = 10.0
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 3.0
			gp.amount = 900
			gp.lifetime = 4.0
		"ash":
			var qm3 := QuadMesh.new()
			qm3.size = Vector2(0.11, 0.11)
			mesh = qm3
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_color = Color(0.2, 0.18, 0.17, 0.8)
			pm.emission_box_extents = Vector3(30, 2, 30)
			pm.initial_velocity_min = 1.2
			pm.initial_velocity_max = 2.4
			pm.spread = 35.0
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 2.2
			pm.gravity = Vector3(2.0, 0, 0.5)
			gp.amount = 2600
			gp.lifetime = 9.0
		_:  # spores
			var qm4 := QuadMesh.new()
			qm4.size = Vector2(0.16, 0.16)
			mesh = qm4
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			mat.albedo_texture = Textures.soft_dot()
			mat.albedo_color = Color(col.r, col.g, col.b, 0.9)
			mat.emission_enabled = true
			mat.emission = col
			mat.emission_energy_multiplier = 2.5
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			pm.emission_box_extents = Vector3(26, 8, 26)
			pm.initial_velocity_min = 0.2
			pm.initial_velocity_max = 0.7
			pm.spread = 180.0
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 1.2
			pm.turbulence_noise_scale = 2.0
			gp.amount = 800
			gp.lifetime = 9.0
	mesh.surface_set_material(0, mat)
	gp.process_material = pm
	gp.draw_pass_1 = mesh
	gp.emitting = true


func update_weather(w: World, dt: float, d: PlanetData, up: Vector3, active: bool) -> void:
	if d == null or kind == "" or not active or d.atmo_height <= 0.0:
		level = move_toward(level, 0.0, dt * 0.3)
		gp.amount_ratio = clampf(level, 0.0, 1.0)
		gp.emitting = level > 0.01 and kind != ""
		return
	var ep := 0.5 + 0.5 * sin(w.t * 0.0042 + t_off) * cos(w.t * 0.0019 + t_off * 0.3)
	var lo := 1.0 - d.storm_chance * 1.3
	target_level = smoothstep(lo, lo + 0.25, ep)
	if kind == "ash" or kind == "spores":
		target_level = maxf(target_level, 0.45)
	if kind == "dust":
		target_level = maxf(target_level, 0.2)
	level = move_toward(level, target_level, dt * 0.08)
	gp.emitting = level > 0.02
	gp.amount_ratio = clampf(level, 0.02, 1.0)
	# emitter follows the camera with its +Y axis along local "up"
	var cp := w.cam.global_position
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var bas := Basis.looking_at(up.cross(ref).normalized(), up)
	var height := 16.0
	if kind == "spores":
		height = 4.0
	gp.global_transform = Transform3D(bas, cp + up * height)
	pm.emission_box_extents = pm.emission_box_extents
