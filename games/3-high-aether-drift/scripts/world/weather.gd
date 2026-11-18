class_name Weather
extends Node3D
## Ambient particles around the viewer: rain, snow, dust storms, ash, floating spores. Follows the camera and falls
## along the local gravity direction.

var kind: String = "none"
var particles: GPUParticles3D
var pmat: ParticleProcessMaterial
var _current: String = "none"


func _ready() -> void:
	particles = GPUParticles3D.new()
	particles.local_coords = false
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	pmat = ParticleProcessMaterial.new()
	particles.process_material = pmat


func set_kind(k: String) -> void:
	if k == _current:
		return
	_current = k
	if k == "none":
		particles.emitting = false
		return
	var quad := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = false
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(34, 4, 34)
	pmat.particle_flag_align_y = false
	pmat.direction = Vector3(0, -1, 0)
	pmat.spread = 0.0
	pmat.initial_velocity_min = 0.0
	pmat.initial_velocity_max = 0.0
	pmat.scale_min = 1.0
	pmat.scale_max = 1.0
	pmat.turbulence_enabled = false
	match k:
		"rain":
			quad.size = Vector2(0.025, 0.7)
			mat.albedo_color = Color(0.75, 0.85, 1.0, 0.35)
			pmat.particle_flag_align_y = true
			pmat.initial_velocity_min = 28.0
			pmat.initial_velocity_max = 34.0
			pmat.spread = 2.0
			particles.amount = 2200
			particles.lifetime = 1.0
		"snow":
			quad.size = Vector2(0.09, 0.09)
			mat.albedo_color = Color(1, 1, 1, 0.85)
			pmat.initial_velocity_min = 1.5
			pmat.initial_velocity_max = 3.0
			pmat.spread = 20.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_strength = 1.5
			pmat.turbulence_noise_scale = 3.0
			particles.amount = 2200
			particles.lifetime = 6.0
		"dust":
			quad.size = Vector2(0.06, 0.06)
			mat.albedo_color = Color(0.9, 0.72, 0.45, 0.45)
			pmat.initial_velocity_min = 4.0
			pmat.initial_velocity_max = 9.0
			pmat.spread = 90.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_strength = 3.0
			particles.amount = 1600
			particles.lifetime = 4.0
		"ash":
			quad.size = Vector2(0.1, 0.1)
			mat.albedo_color = Color(0.35, 0.32, 0.32, 0.8)
			pmat.initial_velocity_min = 0.8
			pmat.initial_velocity_max = 2.0
			pmat.spread = 40.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_strength = 1.0
			particles.amount = 1500
			particles.lifetime = 7.0
		"spores":
			quad.size = Vector2(0.12, 0.12)
			mat.albedo_color = Color(0.55, 1.0, 0.45, 0.9)
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			pmat.initial_velocity_min = 0.3
			pmat.initial_velocity_max = 1.0
			pmat.spread = 180.0
			pmat.turbulence_enabled = true
			pmat.turbulence_noise_strength = 0.8
			particles.amount = 700
			particles.lifetime = 9.0
	quad.material = mat
	particles.draw_pass_1 = quad
	particles.emitting = true


## Call every frame with the camera position and the local "up" (planet radial) direction.
func follow(cam_pos: Vector3, up: Vector3, wind: Vector3) -> void:
	if _current == "none":
		return
	var upv := up
	global_position = cam_pos + upv * 14.0
	var fwd := Vector3.FORWARD if absf(upv.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	global_basis = Basis.looking_at(fwd, upv)
	match _current:
		"rain":
			pmat.gravity = -upv * 12.0 + wind * 1.5
			pmat.direction = -upv
		"snow":
			pmat.gravity = -upv * 0.4 + wind * 2.0
			pmat.direction = -upv
		"dust":
			pmat.gravity = wind * 7.0
			pmat.direction = wind.normalized()
		"ash":
			pmat.gravity = -upv * 0.6 + wind * 1.0
			pmat.direction = -upv
		"spores":
			pmat.gravity = upv * 0.25 + wind * 0.3
			pmat.direction = upv
