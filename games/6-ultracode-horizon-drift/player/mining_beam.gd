class_name MiningBeam
extends Node3D
## Visuals of the multitool mining beam (module M4): energy cylinder (shaders/player_beam.gdshader), muzzle glow, impact glow, impact sparks
## and two small lights.  The node is top_level: Player feeds it GLOBAL (local-frame) positions every frame via update_beam().

const BEAM_SHADER := preload("res://shaders/player_beam.gdshader")

static var _glow_tex: GradientTexture2D = null

var _beam: MeshInstance3D
var _mat: ShaderMaterial
var _muzzle_glow: MeshInstance3D
var _hit_glow: MeshInstance3D
var _sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _light_muzzle: OmniLight3D
var _light_hit: OmniLight3D
var _amount: float = 0.0       # 0..1 smoothed on/off
var _t: float = 0.0
var _color: Color = Color(0.20, 0.85, 1.0)
var _hit_color: Color = Color(1.0, 0.8, 0.5)

static func glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 128
		tex.height = 128
		_glow_tex = tex
	return _glow_tex

static func glow_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = glow_texture()
	m.albedo_color = c
	m.disable_receive_shadows = true
	m.no_depth_test = false
	m.render_priority = 5
	return m

func _ready() -> void:
	top_level = true
	visible = false
	_mat = ShaderMaterial.new()
	_mat.shader = BEAM_SHADER
	_beam = MeshInstance3D.new()
	_beam.mesh = _ribbon_mesh(32)
	_beam.material_override = _mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.extra_cull_margin = 50.0
	add_child(_beam)
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	_muzzle_glow = MeshInstance3D.new()
	_muzzle_glow.mesh = qm
	_muzzle_glow.material_override = glow_material(Color(0.4, 0.95, 1.0, 1.0))
	_muzzle_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_muzzle_glow)
	_hit_glow = MeshInstance3D.new()
	_hit_glow.mesh = qm
	_hit_glow.material_override = glow_material(Color(1.0, 0.85, 0.5, 1.0))
	_hit_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hit_glow)
	_light_muzzle = OmniLight3D.new()
	_light_muzzle.light_color = Color(0.4, 0.9, 1.0)
	_light_muzzle.omni_range = 5.0
	_light_muzzle.light_energy = 0.0
	_light_muzzle.shadow_enabled = false
	add_child(_light_muzzle)
	_light_hit = OmniLight3D.new()
	_light_hit.light_color = Color(1.0, 0.8, 0.5)
	_light_hit.omni_range = 7.0
	_light_hit.light_energy = 0.0
	_light_hit.shadow_enabled = false
	add_child(_light_hit)
	_build_sparks()

## unit strip (x -0.5..0.5, y -0.5..0.5) with `segs` quads along y; the shader turns it into a camera-facing ribbon between muzzle and target
static func _ribbon_mesh(segs: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in segs + 1:
		var y := float(i) / float(segs) - 0.5
		verts.append(Vector3(-0.5, y, 0.0))
		verts.append(Vector3(0.5, y, 0.0))
		uvs.append(Vector2(0.0, y + 0.5))
		uvs.append(Vector2(1.0, y + 0.5))
	for i in segs:
		var a := i * 2
		idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.custom_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	return m

func _build_sparks() -> void:
	_sparks = GPUParticles3D.new()
	_sparks.amount = 48
	_sparks.lifetime = 0.55
	_sparks.explosiveness = 0.0
	_sparks.local_coords = false
	_sparks.emitting = false
	_sparks.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 62.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.5
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.10
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 0.8, 0.45, 0.8), Color(1, 0.3, 0.1, 0)])
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	_sparks.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_texture = glow_texture()
	sm.albedo_color = Color(1.6, 1.4, 1.0, 1.0)
	q.material = sm
	_sparks.draw_pass_1 = q
	add_child(_sparks)

## colour of the beam (resource tint mixed in) and of the impact
func set_colors(beam_col: Color, hit_col: Color) -> void:
	_color = beam_col
	_hit_color = hit_col

## from/to: GLOBAL positions. active: firing. hit: the ray hit something at `to` (normal = surface normal there). up: planet up (for beam roll).
func update_beam(dt: float, active: bool, from: Vector3, to: Vector3, hit: bool, normal: Vector3, up: Vector3, gravity_dir: Vector3, size_k: float = 1.0) -> void:
	_t += dt
	var target := 1.0 if active else 0.0
	_amount = move_toward(_amount, target, dt * (9.0 if active else 6.0))
	if _amount <= 0.002 and not active:
		visible = false
		_sparks.emitting = false
		_light_hit.light_energy = 0.0
		_light_muzzle.light_energy = 0.0
		return
	visible = true
	var dir := to - from
	var len := dir.length()
	if len < 0.05:
		dir = Vector3.FORWARD
		len = 0.05
	dir /= len
	# camera-facing ribbon: identity basis at the midpoint, the shader orients it (first person is thinner but ~20 % wider than the plain
	# size ratio because the beam is seen almost end-on)
	var wk := size_k * (1.0 + 0.5 * (1.0 - size_k))
	var width := (0.11 * (0.75 + 0.25 * _amount) + 0.012 * sin(_t * 55.0)) * wk
	_beam.global_transform = Transform3D(Basis.IDENTITY, (from + to) * 0.5)
	_mat.set_shader_parameter("beam_dir", dir)
	_mat.set_shader_parameter("beam_width", width)
	_mat.set_shader_parameter("beam_length", len)
	_mat.set_shader_parameter("beam_color", _color)
	_mat.set_shader_parameter("tip_fade", 0.0 if hit else 1.0)
	_mat.set_shader_parameter("intensity", 2.6 * _amount)
	_mat.set_shader_parameter("flicker", 0.25 if hit else 0.0)
	# muzzle glow
	_muzzle_glow.global_position = from
	var ms := (0.34 + 0.08 * sin(_t * 47.0)) * lerpf(0.5, 1.0, size_k)
	_muzzle_glow.scale = Vector3(ms, ms, ms) * _amount
	(_muzzle_glow.material_override as StandardMaterial3D).albedo_color = Color(_color.r, _color.g, _color.b, 0.75)
	_light_muzzle.global_position = from
	_light_muzzle.light_color = _color
	_light_muzzle.light_energy = 0.9 * _amount * lerpf(0.35, 0.55, size_k)
	# impact
	_hit_glow.visible = hit
	_sparks.emitting = hit
	_light_hit.visible = hit
	if hit:
		var hp := to + normal * 0.12
		_hit_glow.global_position = hp
		var hs := (1.0 + 0.2 * sin(_t * 33.0) + 0.1 * sin(_t * 71.0))
		_hit_glow.scale = Vector3(hs, hs, hs) * _amount
		(_hit_glow.material_override as StandardMaterial3D).albedo_color = Color(_hit_color.r, _hit_color.g, _hit_color.b, 0.85)
		_light_hit.global_position = to + normal * 0.5
		_light_hit.light_color = _hit_color
		_light_hit.light_energy = (1.3 + 0.5 * sin(_t * 41.0)) * _amount
		var nx := normal.cross(Vector3.RIGHT)
		if nx.length_squared() < 0.01:
			nx = normal.cross(Vector3.FORWARD)
		nx = nx.normalized()
		_sparks.global_transform = Transform3D(Basis(nx, normal, nx.cross(normal).normalized()), to + normal * 0.05)
		var pm := _sparks.process_material as ParticleProcessMaterial
		pm.gravity = gravity_dir * 5.0
		pm.color = Color(_hit_color.r * 0.5 + 0.5, _hit_color.g * 0.5 + 0.5, _hit_color.b * 0.5 + 0.5, 1.0)

func stop() -> void:
	_amount = 0.0
	visible = false
	if _sparks != null:
		_sparks.emitting = false
