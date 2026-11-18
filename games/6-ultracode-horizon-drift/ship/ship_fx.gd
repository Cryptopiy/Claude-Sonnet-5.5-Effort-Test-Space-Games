class_name ShipFX
extends Node3D
## Visual effects of the ship (all children of the Ship => frame-shift safe).
##  * engine flames: EngineGlow_L/R scaled along their thrust axis + engine point lights
##  * pulse / boost star-streak field (shaders/ship_streak.gdshader) and world-static space dust for speed cues (shaders/ship_dust.gdshader)
##  * atmospheric-entry plasma shell (shaders/entry_shell.gdshader) + ember particles
##  * landing / take-off dust blown off the ground (GPUParticles3D, colour per biome)
##  * nav lights (blinking tail light) and a switchable floodlight (L)

const STREAK_COUNT := 420
const DUST_COUNT := 240
const DUST_CELL := 150.0
const SHIP_LIGHT_BIT := 1 << 19             # render layer 20: the ship's own key/fill lights only touch the ship model (crisp hull in every environment)

var ship: Ship
var model: Node3D
var lights_on := false
var _lights_manual := false

var _glow_l: Node3D
var _glow_r: Node3D
var _light_l: OmniLight3D
var _light_r: OmniLight3D
var _nav_tail: Node3D
var _flood: SpotLight3D
var _key: DirectionalLight3D
var _fill: DirectionalLight3D
var _rim: DirectionalLight3D
var _key_e := 0.0
var _t := 0.0

var _streaks: MultiMeshInstance3D
var _streak_mat: ShaderMaterial
var _scroll := 0.0
var _dust: MultiMeshInstance3D
var _dust_mat: ShaderMaterial
var _dust_anchor := Vector3.ZERO
var _shell: MeshInstance3D
var _shell_mat: ShaderMaterial
var _embers: GPUParticles3D
var _heat_layer: CanvasLayer
var _heat_rect: ColorRect
var _heat_mat: ShaderMaterial
var _ground_dust: GPUParticles3D
var _ground_dust_mat: StandardMaterial3D
var _dust_color_key := ""
var _last_pos := Vector3.ZERO
var _dbg_off := ""

func setup(p_ship: Ship, p_model: Node3D) -> void:
	ship = p_ship
	model = p_model
	_glow_l = ModelLib.find_node(model, "EngineGlow_L") as Node3D
	_glow_r = ModelLib.find_node(model, "EngineGlow_R") as Node3D
	_nav_tail = ModelLib.find_node(model, "NavLight_Tail") as Node3D
	_tune_materials(model)
	_light_l = _make_light(ship.anchor_engine(true))
	_light_r = _make_light(ship.anchor_engine(false))
	_build_flood()
	_build_ship_lights()
	_build_streaks()
	_build_dust()
	_build_shell()
	_build_heat_overlay()
	_build_embers()
	_build_ground_dust()
	_last_pos = ship.global_position
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--fx-off="):
			_dbg_off = String(a).substr(9)

## keep the emissive parts from blooming the whole hull into a blue haze (flames/glow strips were far too hot for the global bloom)
func _tune_materials(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i) as StandardMaterial3D
				if m == null:
					continue
				var nm := m.resource_name
				if nm.contains("flame_outer"):
					m.emission_energy_multiplier = 1.3
					m.albedo_color.a = 0.32
				elif nm.contains("flame_inner"):
					m.emission_energy_multiplier = 2.2
				elif nm.ends_with("_glow"):
					m.emission_energy_multiplier = 2.4
				elif nm.contains("screen"):
					m.emission_energy_multiplier = minf(m.emission_energy_multiplier, 2.0)
				elif nm.contains("hull") or nm.contains("accent") or nm.contains("trim") or nm.contains("dark"):
					m.metallic = minf(m.metallic, 0.18)         # less sky reflection (blue sheen), more readable paint
					m.roughness = maxf(m.roughness, 0.45)
	for c in n.get_children():
		_tune_materials(c)

func _make_light(pos: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.88, 1.0)
	l.omni_range = 8.0
	l.light_energy = 0.0
	l.shadow_enabled = false
	l.position = pos + Vector3(0, 0, 1.6)
	add_child(l)
	return l

func _build_flood() -> void:
	_flood = SpotLight3D.new()
	_flood.light_color = Color(1.0, 0.96, 0.88)
	_flood.light_energy = 0.0
	_flood.spot_range = 160.0
	_flood.spot_angle = 34.0
	_flood.spot_attenuation = 0.7
	_flood.shadow_enabled = false
	_flood.position = Vector3(0, -0.4, -5.4)
	_flood.rotation_degrees = Vector3(-14, 0, 0)
	add_child(_flood)

## Ship-only lights: a warm key from above/behind (what the chase camera sees), a soft warm fill from below and a cool rim from the front.
## They only affect render layer 20 (the ship meshes are tagged with it), so terrain and props are untouched. Energy follows the scene brightness.
func _tag_layers(n: Node) -> void:
	if n is VisualInstance3D:
		var vi := n as VisualInstance3D
		vi.layers = vi.layers | SHIP_LIGHT_BIT
	for c in n.get_children():
		_tag_layers(c)

func _make_dir_light(col: Color, dir: Vector3) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.light_color = col
	l.light_energy = 0.0
	l.light_cull_mask = SHIP_LIGHT_BIT
	l.shadow_enabled = false
	l.light_specular = 0.6
	l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	l.transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), Vector3.ZERO)
	add_child(l)
	return l

func _build_ship_lights() -> void:
	_tag_layers(model)
	_key = _make_dir_light(Color(1.0, 0.95, 0.86), Vector3(-0.42, -0.72, -0.55))
	_fill = _make_dir_light(Color(0.95, 0.88, 0.8), Vector3(0.25, 0.8, -0.35))
	_rim = _make_dir_light(Color(0.78, 0.88, 1.0), Vector3(0.1, -0.25, 0.95))

func _update_ship_lights(dt: float) -> void:
	if _key == null:
		return
	var sun_e := 1.0
	var sky: Node = Game.sky
	if sky != null and "sun_energy_now" in sky:
		sun_e = float(sky.get("sun_energy_now"))
	var day := clampf(sun_e / 2.0, 0.0, 1.0)
	# in daylight the sun does most of the work; in shade / at night / in space the ship keeps a readable, slightly warm look
	var ke := lerpf(0.55, 0.42, day)
	var fe := lerpf(0.30, 0.16, day)
	var re := lerpf(0.30, 0.22, day)
	var ex := 1.0
	if ship.heat > 0.0:
		ex = 1.0 - 0.3 * ship.heat
	var k := 1.0 - exp(-4.0 * dt)
	_key.light_energy = lerpf(_key.light_energy, ke * ex, k)
	_fill.light_energy = lerpf(_fill.light_energy, fe, k)
	_rim.light_energy = lerpf(_rim.light_energy, re, k)

func _quad_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	return q

func _build_multimesh(count: int, mat: ShaderMaterial, seed_v: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _quad_mesh()
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in count:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-4000, -4000, -4000), Vector3(8000, 8000, 8000))
	mi.visible = false
	add_child(mi)
	return mi

func _build_streaks() -> void:
	_streak_mat = ShaderMaterial.new()
	_streak_mat.shader = load("res://shaders/ship_streak.gdshader")
	_streaks = _build_multimesh(STREAK_COUNT, _streak_mat, 9101)

func _build_dust() -> void:
	_dust_mat = ShaderMaterial.new()
	_dust_mat.shader = load("res://shaders/ship_dust.gdshader")
	_dust_mat.set_shader_parameter("cell", DUST_CELL)
	_dust = _build_multimesh(DUST_COUNT, _dust_mat, 4417)

func _build_shell() -> void:
	_shell_mat = ShaderMaterial.new()
	_shell_mat.shader = load("res://shaders/entry_shell.gdshader")
	_shell = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 40
	sm.rings = 24
	_shell.mesh = sm
	_shell.material_override = _shell_mat
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell.visible = false
	add_child(_shell)

## full-screen heat glow at the screen edges during atmospheric entry (CanvasLayer 4: below the HUD, above the 3D view)
func _build_heat_overlay() -> void:
	_heat_layer = CanvasLayer.new()
	_heat_layer.layer = 4
	_heat_layer.name = "EntryHeat"
	_heat_mat = ShaderMaterial.new()
	_heat_mat.shader = load("res://shaders/entry_vignette.gdshader")
	_heat_rect = ColorRect.new()
	_heat_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_heat_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heat_rect.material = _heat_mat
	_heat_rect.visible = false
	_heat_layer.add_child(_heat_rect)
	add_child(_heat_layer)

func _soft_dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func _build_embers() -> void:
	_embers = GPUParticles3D.new()
	_embers.amount = 70
	_embers.lifetime = 0.9
	_embers.local_coords = true
	_embers.emitting = false
	_embers.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(4.5, 1.2, 4.0)
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 12.0
	pm.initial_velocity_min = 40.0
	pm.initial_velocity_max = 110.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.12
	pm.scale_max = 0.4
	var cr := Gradient.new()
	cr.set_color(0, Color(1.0, 0.9, 0.55, 1.0))
	cr.add_point(0.4, Color(1.0, 0.45, 0.1, 0.85))
	cr.set_color(2, Color(0.5, 0.08, 0.02, 0.0))
	var ct := GradientTexture1D.new()
	ct.gradient = cr
	pm.color_ramp = ct
	_embers.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_dot_texture()
	q.material = m
	_embers.draw_pass_1 = q
	_embers.position = Vector3(0, 0.3, 2.0)
	add_child(_embers)

func _build_ground_dust() -> void:
	_ground_dust = GPUParticles3D.new()
	_ground_dust.amount = 120
	_ground_dust.lifetime = 2.6
	_ground_dust.local_coords = false
	_ground_dust.emitting = false
	_ground_dust.top_level = true
	_ground_dust.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 40, 120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_radius = 5.5
	pm.emission_ring_inner_radius = 1.5
	pm.emission_ring_height = 0.3
	pm.direction = Vector3(0, 0.12, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.radial_velocity_min = 7.0
	pm.radial_velocity_max = 20.0
	pm.damping_min = 3.0
	pm.damping_max = 6.0
	pm.gravity = Vector3(0, 0.5, 0)
	pm.scale_min = 1.8
	pm.scale_max = 3.6
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.8))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var cr := Gradient.new()
	cr.set_color(0, Color(1, 1, 1, 0.0))
	cr.add_point(0.15, Color(1, 1, 1, 0.55))
	cr.set_color(2, Color(1, 1, 1, 0.0))
	var ct := GradientTexture1D.new()
	ct.gradient = cr
	pm.color_ramp = ct
	_ground_dust.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	_ground_dust_mat = StandardMaterial3D.new()
	_ground_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ground_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ground_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_ground_dust_mat.vertex_color_use_as_albedo = true
	_ground_dust_mat.albedo_texture = _soft_dot_texture()
	_ground_dust_mat.albedo_color = Color(0.7, 0.65, 0.58)
	_ground_dust_mat.disable_receive_shadows = true
	q.material = _ground_dust_mat
	_ground_dust.draw_pass_1 = q
	add_child(_ground_dust)

func reset() -> void:
	_scroll = 0.0
	_dust_anchor = ship.global_position if ship != null else Vector3.ZERO
	if _shell != null:
		_shell.visible = false
	if _streaks != null:
		_streaks.visible = false
	if _embers != null:
		_embers.emitting = false
	if _heat_rect != null:
		_heat_rect.visible = false
	if _ground_dust != null:
		_ground_dust.emitting = false

func on_frame_shift(rot: Basis, shift: Vector3) -> void:
	_dust_anchor = rot * _dust_anchor + shift

func update(dt: float) -> void:
	_t += dt
	_update_engines(dt)
	_update_streaks(dt)
	_update_dust(dt)
	_update_shell(dt)
	_update_ground_dust(dt)
	_update_lights(dt)
	_update_ship_lights(dt)
	if _dbg_off != "":
		_dbg_apply()

# ---------------------------------------------------------------------------------------------------------------------------------
func _update_engines(dt: float) -> void:
	var thrust := ship.fx_thrust
	var length_scale := 0.10 + 0.78 * thrust + 0.50 * ship.fx_boost + 1.15 * ship.fx_pulse + 0.7 * ship.fx_spool
	var width_scale := 0.5 + 0.22 * thrust + 0.14 * ship.fx_boost + 0.08 * ship.fx_pulse + 0.25 * ship.fx_spool
	if ship.is_landed and ship.fx_spool < 0.02:
		length_scale = 0.0
	var flick := 1.0 + 0.07 * sin(_t * 47.0) + 0.05 * sin(_t * 83.0 + 1.3)
	var on := length_scale > 0.02
	for g in [_glow_l, _glow_r]:
		var gn := g as Node3D
		if gn == null:
			continue
		gn.visible = on
		gn.scale = Vector3(width_scale, maxf(length_scale * flick, 0.01), width_scale)
	var le := clampf(thrust * 0.5 + ship.fx_boost * 0.55 + ship.fx_pulse * 0.7 + ship.fx_spool * 0.4, 0.0, 1.4)
	if ship.is_landed and ship.fx_spool < 0.02:
		le = 0.0
	for l in [_light_l, _light_r]:
		var ol := l as OmniLight3D
		ol.light_energy = lerpf(ol.light_energy, le, 1.0 - exp(-10.0 * dt))
		ol.omni_range = 6.0 + 7.0 * clampf(le, 0.0, 1.0)

func _update_streaks(dt: float) -> void:
	var amt := clampf(maxf(ship.fx_pulse * 1.0, ship.fx_boost * 0.5), 0.0, 1.0)
	if ship.is_landed or amt < 0.01:
		_streaks.visible = false
		return
	_streaks.visible = true
	var spd := ship.fx_speed
	_scroll += minf(maxf(spd, 300.0), 2400.0) * dt
	var len := clampf(spd * 0.012, 8.0, 520.0)
	_streak_mat.set_shader_parameter("scroll", fposmod(_scroll, 100000.0))
	_streak_mat.set_shader_parameter("amount", amt)
	_streak_mat.set_shader_parameter("streak_len", len)
	_streak_mat.set_shader_parameter("depth", clampf(len * 9.0, 500.0, 2400.0))
	_streak_mat.set_shader_parameter("radius_max", 100.0 + 70.0 * ship.fx_pulse)
	_streak_mat.set_shader_parameter("flow_dir", ship.fx_flow_dir if ship.fx_speed > 20.0 else Vector3(0, 0, -1))
	var warm := clampf(ship.fx_boost * (1.0 - ship.fx_pulse), 0.0, 1.0)
	_streak_mat.set_shader_parameter("color_a", Color(0.35, 0.65, 1.0).lerp(Color(0.8, 0.85, 1.0), warm))

func _update_dust(dt: float) -> void:
	var spd := ship.fx_speed
	var amt := smoothstep(2.0, 40.0, spd) * (1.0 - ship.fx_pulse) * (1.0 - 0.6 * ship.atmo_density)
	if ship.is_landed or amt < 0.01:
		_dust.visible = false
		return
	_dust.visible = true
	var p := ship.global_position
	var d := p - _dust_anchor
	var o := Vector3(fposmod(d.x, DUST_CELL), fposmod(d.y, DUST_CELL), fposmod(d.z, DUST_CELL))
	_dust_mat.set_shader_parameter("field_origin", o)
	# direction of travel relative to the reference body (fx_flow_dir is in ship space)
	var wdir := ship.global_transform.basis * ship.fx_flow_dir
	_dust_mat.set_shader_parameter("vel_dir", wdir)
	_dust_mat.set_shader_parameter("streak_len", clampf(spd * 0.010, 0.2, 14.0))
	_dust_mat.set_shader_parameter("amount", amt)

func _update_shell(dt: float) -> void:
	var h := ship.heat
	var ov := h > 0.04 and ship.piloted and not ship.is_landed
	if _heat_rect != null:
		_heat_rect.visible = ov
		if ov:
			_heat_mat.set_shader_parameter("heat", clampf(h * 1.2, 0.0, 1.0))
	if h < 0.05 or ship.is_landed:
		_shell.visible = false
		_embers.emitting = false
		return
	_shell.visible = true
	_shell_mat.set_shader_parameter("heat", clampf(h * 1.6, 0.0, 1.0))
	# +Y of the shell = direction of travel (ship space); ellipsoid hugging the ship
	var f := ship.fx_flow_dir.normalized()
	var up_ref := Vector3.UP if absf(f.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := f.cross(up_ref).normalized()
	var z := x.cross(f).normalized()
	var bas := Basis(x * 7.4, f * 13.0, z * 3.9)
	_shell.transform = Transform3D(bas, Vector3(0, 0.4, 0) - f * 4.1)
	_embers.emitting = h > 0.12
	_embers.amount_ratio = clampf(h, 0.1, 1.0)
	var pm := _embers.process_material as ParticleProcessMaterial
	# embers stream away from the direction of travel
	pm.direction = -f
	pm.initial_velocity_min = 30.0 + 80.0 * h
	pm.initial_velocity_max = 70.0 + 160.0 * h

func _dust_color_for(biome: String) -> Color:
	match biome:
		"desert": return Color(0.86, 0.68, 0.45)
		"frozen": return Color(0.92, 0.96, 1.0)
		"volcanic": return Color(0.30, 0.27, 0.26)
		"barren": return Color(0.58, 0.56, 0.54)
		"toxic": return Color(0.58, 0.64, 0.32)
		"lush": return Color(0.62, 0.58, 0.45)
		"ocean": return Color(0.85, 0.9, 0.9)
		"exotic": return Color(0.75, 0.55, 0.85)
	return Color(0.65, 0.6, 0.55)

func _update_ground_dust(dt: float) -> void:
	var clearance := ship.fx_ground_dist
	var push := clampf(ship.fx_thrust * 0.9 + ship.fx_spool * 1.2, 0.0, 1.5)
	var k := (1.0 - smoothstep(4.0, 34.0, clearance)) * push
	if not ship.fx_ground_valid or ship.pulse_state != Ship.Pulse.OFF:
		k = 0.0
	if ship.is_landed and ship.fx_spool < 0.05:
		k = 0.0
	if k < 0.03 or ship._def == null:
		_ground_dust.emitting = false
		return
	var key := ship._def.biome
	if key != _dust_color_key:
		_dust_color_key = key
		_ground_dust_mat.albedo_color = _dust_color_for(key)
	var n := ship.fx_ground_normal
	var up_ref := Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := n.cross(up_ref).normalized()
	var z := x.cross(n).normalized()
	_ground_dust.global_transform = Transform3D(Basis(x, n, z), ship.fx_ground_point + n * 0.4)
	_ground_dust.emitting = true
	_ground_dust.amount_ratio = clampf(k, 0.1, 1.0)
	var pm := _ground_dust.process_material as ParticleProcessMaterial
	pm.radial_velocity_min = 6.0 + 8.0 * k
	pm.radial_velocity_max = 14.0 + 16.0 * k
	pm.emission_ring_radius = 3.5 + 4.0 * clampf(clearance / 30.0, 0.0, 1.0)

func _update_lights(dt: float) -> void:
	if _nav_tail != null:
		var blink := fposmod(_t, 1.3) < 0.14
		_nav_tail.scale = Vector3.ONE * (1.0 if blink else 0.15)
	if not _lights_manual:
		# dark when the sun is below the local horizon (body frame): floodlights come on by themselves near the ground
		var night := 0.0
		if ship._def != null:
			night = clampf(-Frame.sun_dir.dot(ship._up) * 6.0 - 0.3, 0.0, 1.0)
		lights_on = night > 0.5 and ship.altitude >= 0.0 and ship.altitude < 500.0
	_flood.light_energy = lerpf(_flood.light_energy, 5.0 if lights_on else 0.0, 1.0 - exp(-6.0 * dt))

func toggle_lights() -> void:
	_lights_manual = true
	lights_on = not lights_on

func _dbg_apply() -> void:
	if _dbg_off.contains("dust"):
		_dust.visible = false
	if _dbg_off.contains("streaks"):
		_streaks.visible = false
