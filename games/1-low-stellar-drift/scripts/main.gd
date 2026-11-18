extends Node3D
## Game manager: star system, ship, on-foot player, black hole, lighting, HUD and menus.

const DAY_LEN := 420.0
const BH_HORIZON := 500.0
const BH_PONR := 2800.0
const BH_DISC_OUT := 3600.0
const BH_DISC_IN := 800.0
const GEAR_H := 1.45
const SHIP_ACC := 120.0
const SHIP_ACC_BOOST := 220.0
const MODEL_NAMES = ["ship", "astronaut", "tree", "cactus", "mushroom", "rock", "crystal", "landing_pad", "outpost", "jelly"]
enum S { MENU, SPACE, LANDED, FOOT, WARP }

var models := {}
var state := S.MENU
var paused := false
var loading := true
var sysd := {}
var sys_id := 0
var bodies: Array = []
var star_root: Node3D
var star_mesh: MeshInstance3D
var corona: MeshInstance3D
var star_r := 900.0
var star_sys_pos := Vector3.ZERO
var bh_root: Node3D
var bh_sys := Vector3.ZERO
var origin := Vector3.ZERO
var orbit_t := 0.0
var day_t := 0.0
var game_t := 0.0
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var cam: Camera3D
var ship: Node3D
var ship_model: Node3D
var exhaust: Array = []
var heat_fx: CPUParticles3D
var vel := Vector3.ZERO
var player: Node3D
var pv := Vector3.ZERO
var heading := Vector3.FORWARD
var cam_pitch := 0.0
var cam_basis := Basis()
var orbit_yaw := 0.0
var cur_body: Body = null
var hull := 100.0
var suit := 100.0
var jet_fuel := 100.0
var health := 100.0
var resources := 6
var cockpit := false
var pulse_on := false
var boost_on := false
var mouse_d := Vector2.ZERO
var messages := []
var msg_time := 0.0
var warp_t := 0.0
var warp_phase := 0
var warp_dest := -1
var warp_kind := ""
var heat := 0.0
var flash := 0.0
var shake := 0.0
var lens_str := 0.0
var cur_atmo := 0.0
var sun_dir := Vector3.UP
var night_amt := 0.0
var info := {}
var scan_target: Node3D = null
var scan_time := 0.0
var player_light: OmniLight3D
var weather: CPUParticles3D
var weather_kind := ""
var bh_warn_level := 0
var last_horizon := Color(0.5, 0.6, 0.8)
var last_zenith := Color(0.1, 0.2, 0.5)
var last_fog := 0.0
var autotest := false
var shot_dir := ""

# UI
var hud: CanvasLayer
var lbl_loc: Label
var lbl_speed: Label
var lbl_hint: Label
var lbl_warn: Label
var lbl_msg: Label
var lbl_stats: Label
var cross: Label
var fx_rect: ColorRect
var fx_mat: ShaderMaterial
var menu_panel: Control
var pause_panel: Control
var controls_panel: Control
var loading_panel: ColorRect
var loading_lbl: Label
var galmap
var markers := {}
var markers_used := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
		if a.begins_with("--shotdir="):
			shot_dir = a.substr(10)
	_setup_world()
	_setup_ui()
	await _load_models()
	await load_system(Gal.HOME_STAR, "pad")
	loading = false
	loading_panel.visible = false
	_show_menu()
	if autotest:
		_run_autotest()

func _load_models() -> void:
	for n in MODEL_NAMES:
		models[n] = load("res://assets/models/%s.glb" % n)

# ---------------------------------------------------------------- world setup
func _setup_world() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.light_angular_distance = 0.4
	add_child(sun)
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.12, 0.2)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 4.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_density = 0.0
	env.fog_sky_affect = 0.0
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	cam = Camera3D.new()
	cam.near = 0.15
	cam.far = 400000.0
	cam.fov = 72.0
	add_child(cam)
	cam.make_current()
	player_light = OmniLight3D.new()
	player_light.omni_range = 22.0
	player_light.light_energy = 0.0
	player_light.light_color = Color(1.0, 0.92, 0.8)
	add_child(player_light)
	# ship
	ship = Node3D.new()
	add_child(ship)
	ship_model = models.get("ship", null)
	# weather particles
	weather = CPUParticles3D.new()
	weather.emitting = false
	weather.local_coords = false
	add_child(weather)
	# ship exhaust
	for sx in [-1.0, 1.0]:
		var p = CPUParticles3D.new()
		p.amount = 40
		p.lifetime = 0.5
		p.local_coords = false
		p.emitting = false
		p.direction = Vector3(0, 0, 1)
		p.spread = 6.0
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 12.0
		p.gravity = Vector3.ZERO
		var qm = QuadMesh.new()
		qm.size = Vector2(0.5, 0.5)
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.vertex_color_use_as_albedo = true
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.material = m
		p.mesh = qm
		var grad = Gradient.new()
		grad.set_color(0, Color(0.5, 0.8, 1.0, 1.0))
		grad.set_color(1, Color(0.2, 0.3, 1.0, 0.0))
		p.color_ramp = grad
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.2
		p.position = Vector3(sx * 0.9, -0.1, 2.3)
		ship.add_child(p)
		exhaust.append(p)
	heat_fx = CPUParticles3D.new()
	heat_fx.amount = 120
	heat_fx.lifetime = 0.6
	heat_fx.local_coords = false
	heat_fx.emitting = false
	heat_fx.direction = Vector3(0, 0, 1)
	heat_fx.spread = 25.0
	heat_fx.initial_velocity_min = 20.0
	heat_fx.initial_velocity_max = 50.0
	heat_fx.gravity = Vector3.ZERO
	heat_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	heat_fx.emission_sphere_radius = 2.0
	var hq = QuadMesh.new()
	hq.size = Vector2(1.6, 1.6)
	var hm = StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.vertex_color_use_as_albedo = true
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hq.material = hm
	heat_fx.mesh = hq
	var hg = Gradient.new()
	hg.set_color(0, Color(1.0, 0.8, 0.3, 1.0))
	hg.set_color(1, Color(1.0, 0.2, 0.0, 0.0))
	heat_fx.color_ramp = hg
	heat_fx.position = Vector3(0, 0, -2.5)
	ship.add_child(heat_fx)

func _attach_ship_model() -> void:
	if ship.get_node_or_null("Model") == null:
		var m = models["ship"].instantiate()
		m.name = "Model"
		ship.add_child(m)
		ship_model = m
	if player == null:
		player = models["astronaut"].instantiate()
		add_child(player)
		player.visible = false

# ---------------------------------------------------------------- system loading
func _clear_system() -> void:
	for b in bodies:
		if is_instance_valid(b):
			b.drop_patch()
			b.queue_free()
	bodies.clear()
	if star_root:
		star_root.queue_free()
	if bh_root:
		bh_root.queue_free()

func load_system(id: int, mode: String) -> void:
	loading = true
	loading_panel.visible = true
	loading_lbl.text = "Generating star system..."
	await get_tree().process_frame
	_clear_system()
	_attach_ship_model()
	sys_id = id
	sysd = Gal.make_system(id)
	star_r = sysd["star_radius"]
	origin = Vector3.ZERO
	orbit_t = 0.0
	# star
	star_root = Node3D.new()
	add_child(star_root)
	var stp = sysd["star"]
	star_mesh = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = star_r
	sm.height = star_r * 2.0
	sm.radial_segments = 64
	sm.rings = 32
	star_mesh.mesh = sm
	var smat = ShaderMaterial.new()
	smat.shader = load("res://shaders/star.gdshader")
	smat.set_shader_parameter("col", stp["col"])
	star_mesh.material_override = smat
	star_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star_root.add_child(star_mesh)
	corona = MeshInstance3D.new()
	var qm = QuadMesh.new()
	qm.size = Vector2(star_r * 10.0, star_r * 10.0)
	corona.mesh = qm
	var cmat = ShaderMaterial.new()
	cmat.shader = load("res://shaders/corona.gdshader")
	cmat.set_shader_parameter("col", stp["col"])
	cmat.set_shader_parameter("inner", 0.1)
	corona.material_override = cmat
	corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corona.extra_cull_margin = 100000.0
	star_root.add_child(corona)
	# black hole
	bh_root = Node3D.new()
	add_child(bh_root)
	bh_sys = sysd["bh_pos"]
	var hz = MeshInstance3D.new()
	var hs = SphereMesh.new()
	hs.radius = BH_HORIZON
	hs.height = BH_HORIZON * 2.0
	hs.radial_segments = 48
	hs.rings = 24
	hz.mesh = hs
	var hm = StandardMaterial3D.new()
	hm.albedo_color = Color.BLACK
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hz.material_override = hm
	hz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bh_root.add_child(hz)
	var disc = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(BH_DISC_OUT * 2.0, BH_DISC_OUT * 2.0)
	disc.mesh = pm
	var dm = ShaderMaterial.new()
	dm.shader = load("res://shaders/blackhole_disc.gdshader")
	dm.set_shader_parameter("inner", BH_DISC_IN / BH_DISC_OUT)
	dm.set_shader_parameter("outer", BH_DISC_OUT)
	disc.material_override = dm
	disc.rotation = Vector3(0.22, 0.0, 0.12)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.extra_cull_margin = 50000.0
	bh_root.add_child(disc)
	# bodies
	var idx = 0
	for bd in sysd["bodies"]:
		loading_lbl.text = "Generating planet %d / %d  -  %s" % [idx + 1, sysd["bodies"].size(), bd["name"]]
		await get_tree().process_frame
		var b = Body.new()
		add_child(b)
		b.setup(bd, models)
		bodies.append(b)
		idx += 1
	_update_body_positions()
	# sky colours per system
	sky_mat.set_shader_parameter("seed", float(id) * 3.7 + 1.0)
	sky_mat.set_shader_parameter("neb_col", Color.from_hsv(fmod(id * 0.137, 1.0), 0.6, 0.6))
	var gr = RandomNumberGenerator.new()
	gr.seed = id + 5
	sky_mat.set_shader_parameter("galaxy_axis", Vector3(gr.randf_range(-1, 1), gr.randf_range(0.3, 1), gr.randf_range(-1, 1)).normalized())
	# spawn
	var b0: Body = bodies[0]
	if mode == "pad":
		_place_ship_on_pad(b0)
		_set_day_noon(b0)
	else:
		cur_body = null
		state = S.SPACE
		var d = (Vector3(0.6, 0.35, 0.7)).normalized()
		var wp = b0.global_position + d * (b0.R + 6500.0)
		ship.global_position = wp
		ship.basis = Basis.looking_at((b0.global_position - wp).normalized(), Vector3.UP)
		vel = Vector3.ZERO
		_toast("Arrived in the %s system" % sysd["name"])
	loading = false
	loading_panel.visible = false

func _set_day_noon(b: Body) -> void:
	var up = b.flat_dir
	var star_dir = (star_sys_pos - b.sys_pos).normalized()
	var best = 0.0
	var bd = 9.0
	for i in range(72):
		var a = i * TAU / 72.0
		var s = star_dir.rotated(b.axis, a)
		var e = acos(clampf(s.dot(up), -1.0, 1.0))
		if e < bd:
			bd = e
			best = a
	day_t = (best + 0.35) / TAU * DAY_LEN
	# rotation direction is taken as +a per day_t, noon slightly before the peak

func _place_ship_on_pad(b: Body) -> void:
	cur_body = b
	var up = b.flat_dir
	b.build_patch_sync(up)
	b.build_flora(models)
	ship.global_position = b.global_position + up * (b.R + b.flat_h + GEAR_H + 0.25)
	var fwd = b.tangent_of(up)
	ship.basis = Basis.looking_at(fwd, up)
	vel = Vector3.ZERO
	state = S.LANDED
	ship_model.visible = true

func _update_body_positions() -> void:
	star_sys_pos = Vector3.ZERO
	for i in range(bodies.size()):
		var bd = sysd["bodies"][i]
		bodies[i].sys_pos = _orbit_pos(i)
		bodies[i].global_position = bodies[i].sys_pos - origin
	star_root.global_position = star_sys_pos - origin
	bh_root.global_position = bh_sys - origin

func _orbit_pos(i: int) -> Vector3:
	var bd = sysd["bodies"][i]
	var a = bd["phase"] + orbit_t * TAU / bd["period"]
	var p = Vector3(cos(a), sin(bd["incl"]) * sin(a), sin(a)) * bd["orbit_r"]
	if bd["parent"] >= 0:
		p += _orbit_pos(bd["parent"])
	return p

# ---------------------------------------------------------------- UI
func _lab(text: String, size: int = 18, col: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _setup_ui() -> void:
	hud = CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	fx_rect = ColorRect.new()
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = load("res://shaders/fx.gdshader")
	fx_rect.material = fx_mat
	hud.add_child(fx_rect)
	lbl_loc = _lab("", 18)
	lbl_loc.position = Vector2(24, 16)
	hud.add_child(lbl_loc)
	lbl_stats = _lab("", 17)
	lbl_stats.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lbl_stats.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lbl_stats.position = Vector2(-24, 16)
	lbl_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(lbl_stats)
	lbl_speed = _lab("", 22, Color(0.7, 0.95, 1.0))
	lbl_speed.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	lbl_speed.position = Vector2(24, -140)
	hud.add_child(lbl_speed)
	lbl_hint = _lab("", 18, Color(1, 1, 0.8))
	lbl_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl_hint.offset_top = -62
	lbl_hint.offset_bottom = -20
	lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(lbl_hint)
	lbl_warn = _lab("", 28, Color(1, 0.3, 0.2))
	lbl_warn.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl_warn.offset_top = 90
	lbl_warn.offset_bottom = 180
	lbl_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(lbl_warn)
	lbl_msg = _lab("", 24, Color(0.8, 1.0, 0.8))
	lbl_msg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl_msg.offset_top = 190
	lbl_msg.offset_bottom = 260
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(lbl_msg)
	cross = _lab("+", 26, Color(1, 1, 1, 0.6))
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-8, -18)
	hud.add_child(cross)
	# galaxy map
	galmap = load("res://scripts/galmap.gd").new()
	galmap.set_anchors_preset(Control.PRESET_FULL_RECT)
	galmap.visible = false
	galmap.stars = Gal.stars()
	galmap.warp_requested.connect(_on_map_warp)
	hud.add_child(galmap)
	# menus
	menu_panel = _make_menu()
	hud.add_child(menu_panel)
	pause_panel = _make_pause()
	hud.add_child(pause_panel)
	controls_panel = _make_controls()
	hud.add_child(controls_panel)
	loading_panel = ColorRect.new()
	loading_panel.color = Color(0.01, 0.01, 0.03, 1.0)
	loading_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_lbl = _lab("Loading...", 28, Color(0.7, 0.9, 1.0))
	loading_lbl.set_anchors_preset(Control.PRESET_CENTER)
	loading_lbl.position = Vector2(-300, -20)
	loading_panel.add_child(loading_lbl)
	hud.add_child(loading_panel)

func _btn(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b

func _panel(title: String, sub: String) -> Control:
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.03, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(box)
	var t = _lab(title, 64, Color(0.85, 0.95, 1.0))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s = _lab(sub, 20, Color(0.7, 0.8, 0.95))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	root.set_meta("box", box)
	return root

func _make_menu() -> Control:
	var r = _panel("STELLAR DRIFT", "A procedural space exploration game")
	var box: VBoxContainer = r.get_meta("box")
	box.add_child(_btn("START EXPLORING", _start_game))
	box.add_child(_btn("Controls", func(): controls_panel.visible = true))
	box.add_child(_btn("Quit", func(): get_tree().quit()))
	return r

func _make_pause() -> Control:
	var r = _panel("PAUSED", "")
	var box: VBoxContainer = r.get_meta("box")
	box.add_child(_btn("Resume", func(): _set_pause(false)))
	box.add_child(_btn("Controls", func(): controls_panel.visible = true))
	box.add_child(_btn("Quit game", func(): get_tree().quit()))
	r.visible = false
	return r

func _make_controls() -> Control:
	var r = _panel("CONTROLS", "")
	var box: VBoxContainer = r.get_meta("box")
	var txt = "SHIP\nW / S  thrust forward / back      A / D  strafe      R / Ctrl  up / down\nMouse  pitch & yaw      Q / E  roll\nShift  boost      Space (hold)  PULSE drive (speed limited near planets)\nV  camera (chase / cockpit)      Landing: slow below 12 m/s over flat ground, gear is automatic\nW / Space / R while landed  take off\n\nON FOOT\nW A S D  walk      Shift  sprint      Space  jump (hold in air = jetpack)\nMouse  look      E  collect resource      T  scan for resources\n\nGENERAL\nF  exit / board ship (stand next to it)      M  galaxy map (warp between stars)\nEsc  pause menu      Black holes: fly into one to cross the galaxy"
	var l = _lab(txt, 19)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	box.add_child(_btn("Back", func(): controls_panel.visible = false))
	r.visible = false
	return r

func _show_menu() -> void:
	state = S.MENU
	menu_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud_visible(false)

func _hud_visible(v: bool) -> void:
	for l in [lbl_loc, lbl_stats, lbl_speed, lbl_hint, lbl_warn, lbl_msg, cross]:
		l.visible = v

func _start_game() -> void:
	menu_panel.visible = false
	controls_panel.visible = false
	state = S.LANDED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hud_visible(true)
	_toast("Welcome to Aurelia. Press F to leave the ship and explore Eden.")

func _set_pause(p: bool) -> void:
	paused = p
	pause_panel.visible = p
	if not p:
		controls_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED

func map_closed() -> void:
	pass

func _toast(t: String) -> void:
	lbl_msg.text = t
	msg_time = 5.0

# ---------------------------------------------------------------- input
func _input(ev: InputEvent) -> void:
	if loading:
		return
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_d += ev.relative
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k = ev.keycode
		if k == KEY_ESCAPE:
			if galmap.visible:
				galmap.visible = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif controls_panel.visible:
				controls_panel.visible = false
			elif state != S.MENU and state != S.WARP:
				_set_pause(not paused)
			return
		if state == S.MENU or paused or state == S.WARP:
			return
		if k == KEY_M:
			galmap.visible = not galmap.visible
			if galmap.visible:
				galmap.open(sysd, sys_id)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if galmap.visible:
			if k == KEY_ENTER or k == KEY_KP_ENTER:
				if galmap.selected >= 0 and galmap.selected != sys_id:
					_on_map_warp(galmap.selected)
			return
		if k == KEY_F:
			_interact()
		elif k == KEY_V:
			cockpit = not cockpit
		elif k == KEY_E and state == S.FOOT:
			_collect()
		elif k == KEY_T and state == S.FOOT:
			_scan()

func _interact() -> void:
	if state == S.LANDED:
		_exit_ship()
	elif state == S.FOOT:
		if player.global_position.distance_to(ship.global_position) < 9.0:
			state = S.LANDED
			player.visible = false
			ship_model.visible = true
			suit = 100.0
			jet_fuel = 100.0
			_toast("Boarded ship. Suit recharged.")
		else:
			_toast("Too far from the ship.")

func _exit_ship() -> void:
	if cur_body == null:
		return
	var b = cur_body
	var pos = ship.global_position + ship.global_basis.x * 3.6
	var rel = pos - b.global_position
	var dir = rel.normalized()
	player.global_position = b.global_position + dir * (b.R + b.height(dir, true))
	heading = -ship.global_basis.z
	pv = Vector3.ZERO
	cam_pitch = -0.15
	player.visible = true
	state = S.FOOT
	cockpit = false

func _collect() -> void:
	if cur_body == null:
		return
	var rel = player.global_position - cur_body.global_position
	var c = cur_body.nearest_crystal(rel)
	if c and c.position.distance_to(rel) < 6.5:
		c.visible = false
		resources += 1
		_toast("Collected %s  (+1)   Resources: %d" % [cur_body.resource_name(), resources])
	else:
		_toast("Nothing to collect here. Press T to scan.")

func _scan() -> void:
	if cur_body == null:
		return
	var rel = player.global_position - cur_body.global_position
	var c = cur_body.nearest_crystal(rel)
	if c:
		scan_target = c
		scan_time = 12.0
		_toast("Scan: %s deposit %.0f m away (marked on HUD)" % [cur_body.resource_name(), c.position.distance_to(rel)])
	else:
		_toast("Scan: no deposits left nearby.")

func _on_map_warp(id: int) -> void:
	if state == S.SPACE and info.get("alt", 0.0) > 3000.0:
		if resources < 3:
			_toast("Not enough resources to warp (need 3). Collect crystals on planets.")
			return
		resources -= 3
		galmap.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_begin_warp(id, "map")
	else:
		_toast("Hyperdrive needs open space: fly higher than 3 km above any planet.")

func _begin_warp(id: int, kind: String) -> void:
	warp_dest = id
	warp_kind = kind
	warp_t = 0.0
	warp_phase = 0
	state = S.WARP

# ---------------------------------------------------------------- main loop
func _process(delta: float) -> void:
	if loading:
		return
	var dt = minf(delta, 0.05)
	_markers_begin()
	if paused:
		_markers_end()
		return
	game_t += dt
	day_t += dt
	_update_body_positions()
	focus_update_info()
	_update_orbits(dt)
	match state:
		S.MENU:
			_menu_cam(dt)
		S.SPACE:
			_ship_flight(dt)
			_chase_cam(dt)
		S.LANDED:
			_landed(dt)
			_chase_cam(dt)
		S.FOOT:
			_foot(dt)
		S.WARP:
			_warp(dt)
	_floating_origin()
	_streaming()
	_update_light_env(dt)
	_update_weather()
	_update_hud(dt)
	_update_fx(dt)
	_markers_end()
	mouse_d = Vector2.ZERO

func focus_pos() -> Vector3:
	if state == S.FOOT:
		return player.global_position
	return ship.global_position

func focus_update_info() -> void:
	var p = focus_pos()
	var best = {"alt": 1e12, "body": null, "kind": "space", "dist": 1e12, "rel": Vector3.UP}
	for b in bodies:
		var rel = p - b.global_position
		var dist = rel.length()
		var alt = dist - b.R
		if b.landable and dist < b.R + 3000.0:
			alt = dist - (b.R + b.height(rel / dist, true))
		if alt < best["alt"]:
			best = {"alt": alt, "body": b, "kind": "planet", "dist": dist, "rel": rel}
	var srel = p - star_root.global_position
	var salt = srel.length() - star_r
	if salt < best["alt"]:
		best = {"alt": salt, "body": null, "kind": "star", "dist": srel.length(), "rel": srel}
	info = best

func _update_orbits(dt: float) -> void:
	var near = false
	var p = focus_pos()
	for b in bodies:
		if (p - b.global_position).length() < b.R * 2.6:
			near = true
	if near:
		return
	var a = info.get("alt", 1e9)
	var ts = lerpf(1.0, 10.0, smoothstep(3000.0, 9000.0, a))
	orbit_t += dt * ts

func _floating_origin() -> void:
	var p = focus_pos()
	if p.length() > 2500.0:
		origin += p
		ship.global_position -= p
		if player and player.visible:
			player.global_position -= p
		_update_body_positions()

func _streaming() -> void:
	var p = focus_pos()
	for b in bodies:
		if not b.landable:
			continue
		var dist = (p - b.global_position).length()
		if dist < b.R + 1200.0:
			b.update_patch(p - b.global_position)
		elif b.patch_has and dist > b.R + 2500.0:
			b.drop_patch()
		if dist < b.R * 3.2:
			b.build_flora(models)
			b.animate_fauna(game_t)
		elif dist > b.R * 4.5:
			b.hide_flora()
		# terrain sink so the detail patch never z-fights with the coarse mesh
		if b.patch_has and dist < b.R + 600.0:
			b.terrain_mat.set_shader_parameter("sink_center", p)
			b.terrain_mat.set_shader_parameter("sink_r1", 95.0)
		else:
			b.terrain_mat.set_shader_parameter("sink_center", Vector3(1e9, 1e9, 1e9))
		if b.cloud_mi:
			b.cloud_mi.rotation.y += 0.002 * get_process_delta_time() * 10.0

# ---------------------------------------------------------------- ship
func _speed_cap(alt: float) -> float:
	return 8.0 + maxf(alt, 0.0) * 0.5

func _ship_flight(dt: float) -> void:
	var f = -ship.basis.z
	# rotation
	var sens = 0.0022
	ship.rotate_object_local(Vector3.UP, -mouse_d.x * sens)
	ship.rotate_object_local(Vector3.RIGHT, -mouse_d.y * sens)
	var roll = 0.0
	if Input.is_key_pressed(KEY_Q): roll += 1.0
	if Input.is_key_pressed(KEY_E): roll -= 1.0
	ship.rotate_object_local(Vector3.FORWARD, -roll * 1.6 * dt)
	ship.basis = ship.basis.orthonormalized()
	# thrust input
	var inp = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): inp.z -= 1.0
	if Input.is_key_pressed(KEY_S): inp.z += 0.5
	if Input.is_key_pressed(KEY_D): inp.x += 0.6
	if Input.is_key_pressed(KEY_A): inp.x -= 0.6
	if Input.is_key_pressed(KEY_R): inp.y += 0.6
	if Input.is_key_pressed(KEY_CTRL): inp.y -= 0.6
	boost_on = Input.is_key_pressed(KEY_SHIFT)
	pulse_on = Input.is_key_pressed(KEY_SPACE)
	var alt: float = info["alt"]
	var cap = _speed_cap(alt)
	var bh_rel = ship.global_position - bh_root.global_position
	var bh_d = bh_rel.length()
	if bh_d < 40000.0:
		cap = minf(cap, 60.0 + maxf(bh_d - BH_PONR, 0.0) * 0.18)
	var vmax = 150.0
	var acc = SHIP_ACC
	if boost_on:
		vmax = 420.0
		acc = SHIP_ACC_BOOST
	var desired = Vector3.ZERO
	if pulse_on:
		desired = f * 2600.0
		acc = 1800.0
	elif inp != Vector3.ZERO:
		desired = ship.basis * (inp.normalized() * vmax * minf(inp.length(), 1.0))
	if info["body"] != null and info["body"].landable and alt < 70.0 and not pulse_on and not Input.is_key_pressed(KEY_R):
		desired += -info["rel"].normalized() * minf(12.0, 1.5 + alt * 0.4)   # gentle sink near the ground
	var dlen = desired.length()
	if dlen > cap:
		desired = desired / dlen * cap
	var braking = false
	if vel.length() > cap and not (bh_d < BH_PONR):
		vel = vel.move_toward(vel.normalized() * cap, 4500.0 * dt)
		braking = true
	vel = vel.move_toward(desired, acc * dt)
	# black hole gravity
	_bh_gravity(dt, bh_rel, bh_d)
	ship.global_position += vel * dt
	# collisions
	_ship_collide(dt)
	# landing assist
	if info["body"] != null and info["body"].landable and info["alt"] < 70.0 and vel.length() < 45.0:
		var up = info["rel"].normalized()
		var cur_up = ship.basis.y
		var axis = cur_up.cross(up)
		if axis.length() > 0.001:
			var ang = cur_up.angle_to(up)
			ship.rotate(axis.normalized(), minf(ang, 1.4 * dt))
	# exhaust
	var thr = clampf(vel.length() / 60.0, 0.0, 1.0) if (inp.z < 0.0 or pulse_on) else 0.0
	for p in exhaust:
		p.emitting = thr > 0.1 and not cockpit
		p.initial_velocity_min = 6.0 + (20.0 if boost_on or pulse_on else 0.0)
		p.initial_velocity_max = 12.0 + (30.0 if boost_on or pulse_on else 0.0)
	ship_model.visible = not cockpit
	# atmosphere entry heat
	var inward = -vel.dot(info["rel"].normalized()) if info["body"] != null else 0.0
	var atm = 0.0
	if info["body"] != null and info["body"].landable and info["body"].atmo_h > 0.0:
		atm = clampf(1.0 - alt / info["body"].atmo_h, 0.0, 1.0)
	var target_heat = atm * smoothstep(35.0, 130.0, inward) if alt > 12.0 else 0.0
	heat = lerpf(heat, target_heat, 1.0 - exp(-dt * 4.0))
	heat_fx.emitting = heat > 0.1 and not cockpit
	shake = maxf(shake - dt * 2.0, heat * 0.5)
	_bh_hud_state(bh_d)

func _bh_gravity(dt: float, rel: Vector3, d: float) -> void:
	if d > 30000.0:
		bh_warn_level = 0
		return
	var a = SHIP_ACC_BOOST * pow(BH_PONR / maxf(d, 1.0), 2.0)
	a = minf(a, 6000.0)
	vel += -rel.normalized() * a * dt
	# horizon crossing
	if d < BH_HORIZON * 1.05:
		var dest = Gal.DEST_STAR if sys_id == Gal.HOME_STAR else Gal.HOME_STAR
		_begin_warp(dest, "blackhole")

func _bh_hud_state(d: float) -> void:
	if d > 30000.0:
		bh_warn_level = 0
	elif d > 12000.0:
		bh_warn_level = 1
	elif d > BH_PONR * 1.5:
		bh_warn_level = 2
	elif d > BH_PONR:
		bh_warn_level = 3
	else:
		bh_warn_level = 4
	var s = clampf(1.0 - d / 20000.0, 0.0, 1.0)
	shake = maxf(shake, s * s * 0.9)

func _ship_collide(dt: float) -> void:
	var b = info["body"]
	if info["kind"] == "star":
		if info["alt"] < 100.0:
			hull -= 25.0 * dt
			flash = 1.0
			_warn_text("STAR PROXIMITY - HULL OVERHEATING")
			if info["alt"] < 0.0:
				ship.global_position = star_root.global_position + info["rel"].normalized() * (star_r + 5.0)
				vel = info["rel"].normalized() * 80.0
		return
	if b == null:
		return
	if not b.landable:
		if info["alt"] < 40.0:
			hull -= 20.0 * dt
			flash = 0.6
			_warn_text("CRUSHING PRESSURE - PULL UP")
		if info["alt"] < 0.0:
			var dir = info["rel"].normalized()
			ship.global_position = b.global_position + dir * (b.R + 1.0)
			vel = dir * 60.0
		return
	if info["alt"] < GEAR_H:
		var up = info["rel"].normalized()
		var vr = vel.dot(up)
		var level = ship.basis.y.dot(up)
		var thrust_up = Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_SPACE)
		if vr > 0.5 and thrust_up:
			return
		ship.global_position += up * (GEAR_H - info["alt"])
		if vr < -12.0 or vel.length() > 25.0 or level < 0.55:
			hull -= clampf(absf(vr) * 1.2, 4.0, 40.0)
			vel = up * absf(vr) * 0.35
			flash = 1.0
			shake = 0.8
			_toast("Hard landing! Hull damaged. Slow down and level the ship.")
			if hull <= 0.0:
				hull = 100.0
		else:
			state = S.LANDED
			cur_body = b
			vel = Vector3.ZERO
			var fwd = -ship.basis.z
			fwd = (fwd - up * fwd.dot(up)).normalized()
			ship.basis = Basis.looking_at(fwd, up)
			_toast("Landed on %s. Press F to exit the ship." % b.name)

func _landed(dt: float) -> void:
	vel = Vector3.ZERO
	var up = (ship.global_position - cur_body.global_position).normalized()
	orbit_yaw += -mouse_d.x * 0.004
	cam_pitch = clampf(cam_pitch - mouse_d.y * 0.003, -0.6, 1.0)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_R):
		state = S.SPACE
		vel = up * 14.0
		ship.global_position += up * 0.2
		_toast("Take-off! Climb out of the atmosphere, then use SPACE to pulse.")
	ship_model.visible = not cockpit
	for p in exhaust:
		p.emitting = false
	heat_fx.emitting = false
	heat = lerpf(heat, 0.0, dt * 3.0)
	shake = 0.0

func _warn_text(t: String) -> void:
	lbl_warn.text = t

# ---------------------------------------------------------------- warp / black hole transition
func _warp(dt: float) -> void:
	warp_t += dt
	var dur = 2.2
	if warp_kind == "blackhole":
		dur = 3.0
		vel = vel.move_toward(Vector3.ZERO, 50.0 * dt)
		shake = 0.8
	else:
		shake = 0.3
	var w = clampf(warp_t / dur, 0.0, 1.0)
	fx_mat.set_shader_parameter("warp", smoothstep(0.0, 1.0, w) if warp_phase == 0 else 1.0 - smoothstep(0.0, 1.0, clampf((warp_t - dur) / 1.8, 0.0, 1.0)))
	if warp_kind == "blackhole" and warp_phase == 0:
		ship.global_position += vel * dt
	_chase_cam(dt)
	if warp_phase == 0 and warp_t >= dur:
		warp_phase = 1
		_do_warp_load()
	elif warp_phase == 2 and warp_t >= dur + 1.8:
		state = S.SPACE
		fx_mat.set_shader_parameter("warp", 0.0)

func _do_warp_load() -> void:
	await load_system(warp_dest, "arrive")
	state = S.WARP
	warp_phase = 2
	warp_t = (3.0 if warp_kind == "blackhole" else 2.2)
	if warp_kind == "blackhole":
		_toast("You were spat out across the galaxy by the black hole: %s system" % sysd["name"])

# ---------------------------------------------------------------- on foot
func _foot(dt: float) -> void:
	var b = cur_body
	var rel = player.global_position - b.global_position
	var up = rel.normalized()
	heading = (heading - up * heading.dot(up)).normalized()
	heading = heading.rotated(up, -mouse_d.x * 0.0025)
	cam_pitch = clampf(cam_pitch - mouse_d.y * 0.0025, -1.2, 1.3)
	var right = heading.cross(up)
	var fwd = 0.0
	var str_ = 0.0
	if Input.is_key_pressed(KEY_W): fwd += 1.0
	if Input.is_key_pressed(KEY_S): fwd -= 1.0
	if Input.is_key_pressed(KEY_D): str_ += 1.0
	if Input.is_key_pressed(KEY_A): str_ -= 1.0
	var sprint = Input.is_key_pressed(KEY_SHIFT)
	var spd = 13.0 if sprint else 6.5
	var wish = (heading * fwd + right * str_)
	if wish.length() > 0.01:
		wish = wish.normalized() * spd
	var gr = b.R + b.height(up, true)
	var r = rel.length()
	var grounded = r <= gr + 0.08
	var g = b.gravity
	var vr = up * pv.dot(up)
	var vt = pv - vr
	var in_sea = b.sea_level > -500.0 and r < b.R + b.sea_level
	if in_sea:
		spd *= 0.6
		wish *= 0.6
	var jet = false
	if grounded:
		vt = vt.move_toward(wish, 70.0 * dt)
		vr = Vector3.ZERO
		if Input.is_key_pressed(KEY_SPACE):
			vr = up * (g * 0.55 + 4.0)
		jet_fuel = minf(100.0, jet_fuel + 30.0 * dt)
	else:
		vt = vt.move_toward(wish, 14.0 * dt)
		vr -= up * g * dt
		if Input.is_key_pressed(KEY_SPACE) and jet_fuel > 0.0:
			vr += up * (g * 2.2 + 6.0) * dt
			jet_fuel = maxf(0.0, jet_fuel - 24.0 * dt)
			jet = true
	pv = vt + vr
	if vr.dot(up) < -60.0:
		pv -= up * (vr.dot(up) + 60.0)
	var np = rel + pv * dt
	var nd = np.normalized()
	var ngr = b.R + b.height(nd, true)
	if np.length() < ngr:
		np = nd * ngr
		var vn = pv.dot(nd)
		if vn < 0.0:
			pv -= nd * vn
	player.global_position = b.global_position + np
	# orientation
	var nup = np.normalized()
	heading = (heading - nup * heading.dot(nup)).normalized()
	var z = -heading
	var x = nup.cross(z).normalized()
	player.global_basis = Basis(x, nup, z)
	# hazards
	var hz: float = b.biome["haz_rate"]
	var near_ship = player.global_position.distance_to(ship.global_position) < 12.0
	if hz > 0.0 and not near_ship:
		var mult = 1.0
		if b.key == "frozen" or b.key == "desert":
			mult = 1.0 + 0.8 * night_amt
		suit -= hz * mult * dt
	else:
		suit = minf(100.0, suit + 25.0 * dt)
	if suit <= 0.0:
		suit = 0.0
		health -= 6.0 * dt
		_warn_text("EXOSUIT PROTECTION DEPLETED - RETURN TO SHIP")
		if health <= 0.0:
			health = 100.0
			suit = 100.0
			player.global_position = ship.global_position + ship.global_basis.x * 3.6
			pv = Vector3.ZERO
			_toast("Exosuit failure - you were recovered at your ship.")
	else:
		health = minf(100.0, health + 5.0 * dt)
	# camera
	var look = heading * cos(cam_pitch) + nup * sin(cam_pitch)
	var pivot = player.global_position + nup * 1.7 + right * 0.5
	var cpos = pivot - look * 5.2
	var cdir = (cpos - b.global_position)
	var cg = b.R + b.height(cdir.normalized(), true) + 0.7
	if cdir.length() < cg:
		cpos = b.global_position + cdir.normalized() * cg
	cam.global_transform = Transform3D(Basis.looking_at(pivot + look * 20.0 - cpos, nup), cpos)
	cam.fov = lerpf(cam.fov, 78.0 if sprint else 72.0, dt * 6.0)
	jet_fx(jet)

func jet_fx(on: bool) -> void:
	if on:
		shake = maxf(shake, 0.05)

# ---------------------------------------------------------------- cameras
func _menu_cam(dt: float) -> void:
	orbit_yaw += dt * 0.12
	cam_pitch = 0.18
	_chase_cam(dt)

func _chase_cam(dt: float) -> void:
	var sp = ship.global_position
	if state == S.LANDED or state == S.MENU:
		var up = ship.basis.y
		var base = Basis(up, orbit_yaw)
		var back = base * ship.basis.z
		var look = (up * sin(cam_pitch) + back * cos(cam_pitch)) * 15.0
		var cpos = sp + look + up * 2.0
		cam.global_transform = Transform3D(Basis.looking_at(sp + up * 1.0 - cpos, up), cpos)
		cam_basis = cam.global_basis
		return
	var target_basis = ship.global_basis
	if cam_basis.determinant() < 0.5:
		cam_basis = target_basis
	cam_basis = cam_basis.slerp(target_basis, 1.0 - exp(-dt * 9.0)).orthonormalized()
	var off = Vector3(0, 2.8, 10.0) + Vector3(0, 0, clampf(vel.length() / 2600.0, 0.0, 1.0) * 8.0)
	if cockpit:
		off = Vector3(0, 0.55, -0.9)
		cam_basis = target_basis
	var cp = sp + cam_basis * off
	var sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.12
	cam.global_transform = Transform3D(cam_basis, cp + sh)
	var tf = 72.0 + clampf(vel.length() / 2600.0, 0.0, 1.0) * 28.0 + (6.0 if boost_on else 0.0)
	cam.fov = lerpf(cam.fov, tf, 1.0 - exp(-dt * 5.0))

# ---------------------------------------------------------------- light / environment
func _update_light_env(dt: float) -> void:
	var p = focus_pos()
	var nb: Body = info["body"]
	var star_true = star_root.global_position
	var to_star = star_true - p
	var sdist = to_star.length()
	var sdir = to_star / sdist
	# day cycle when near a planet
	var w = 0.0
	if nb != null and nb.landable:
		w = 1.0 - smoothstep(nb.R * 1.2, nb.R * 3.5, info["dist"])
		var ang = day_t / DAY_LEN * TAU
		sdir = (sdir * (1.0 - w) + sdir.rotated(nb.axis, ang) * w).normalized()
	elif nb != null:
		pass
	sun_dir = sdir
	star_mesh.visible = true
	star_root.global_position = p + sdir * sdist if w > 0.001 else star_true
	if w > 0.001 and nb != null:
		pass
	var up = info["rel"].normalized() if info["body"] != null else Vector3.UP
	var elev = up.dot(sun_dir)
	var occ = 1.0
	if nb != null and nb.landable:
		var occ_w = 1.0 - smoothstep(nb.R * 0.15, nb.R * 1.2, info["alt"])
		occ = lerpf(1.0, smoothstep(-0.06, 0.1, elev), occ_w)
	sun.basis = Basis.looking_at(-sun_dir, Vector3.UP if absf(sun_dir.y) < 0.95 else Vector3.RIGHT)
	var stp = sysd["star"]
	sun.light_color = Color(1, 1, 1).lerp(stp["col"], 0.55)
	sun.light_energy = stp["energy"] * 1.6 * occ
	var atmo = 0.0
	if nb != null and nb.landable and nb.atmo_h > 0.0:
		atmo = smoothstep(0.0, 1.0, clampf(1.0 - info["alt"] / nb.atmo_h, 0.0, 1.0))
		last_horizon = nb.biome["horizon"]
		last_zenith = nb.biome["zenith"]
		last_fog = nb.biome["fog"]
	cur_atmo = lerpf(cur_atmo, atmo, 1.0 - exp(-dt * 6.0))
	var sunlit = smoothstep(-0.18, 0.3, elev) * clampf(sun.light_energy, 0.0, 1.0) if false else smoothstep(-0.18, 0.3, elev)
	night_amt = 1.0 - smoothstep(-0.1, 0.25, elev) if nb != null and nb.landable else 0.0
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("up_dir", up)
	sky_mat.set_shader_parameter("atmo", cur_atmo)
	sky_mat.set_shader_parameter("horizon_col", Vector3(last_horizon.r, last_horizon.g, last_horizon.b))
	sky_mat.set_shader_parameter("zenith_col", Vector3(last_zenith.r, last_zenith.g, last_zenith.b))
	env.fog_density = last_fog * cur_atmo
	var fogc = last_horizon * (0.12 + 0.88 * sunlit)
	env.fog_light_color = Color(fogc.r, fogc.g, fogc.b)
	var amb_sky = last_horizon.lerp(last_zenith, 0.4) * (0.25 + 0.75 * sunlit)
	var amb_space = Color(0.07, 0.08, 0.13)
	var ac = amb_space.lerp(amb_sky, cur_atmo)
	env.ambient_light_color = ac
	env.ambient_light_energy = lerpf(0.55, 0.9 * (0.3 + 0.7 * sunlit), cur_atmo) + (0.0 if cur_atmo > 0.3 else 0.0)
	# player flashlight at night
	player_light.light_energy = 0.0
	if state == S.FOOT:
		player_light.global_position = player.global_position + up * 2.5
		player_light.light_energy = 1.4 * night_amt
	# distant star appears at fixed apparent direction - corona orientation handled by shader billboard

# ---------------------------------------------------------------- weather
func _update_weather() -> void:
	var b: Body = info["body"]
	var kind = ""
	if b != null and b.landable and info["alt"] < 120.0 and state != S.WARP:
		kind = b.biome["weather"]
	if kind != weather_kind:
		weather_kind = kind
		_configure_weather(kind)
	weather.emitting = kind != ""
	if kind != "":
		var up = info["rel"].normalized()
		var base = b.align_up(up, 0.0)
		weather.global_transform = Transform3D(base, focus_pos() + up * 14.0)

func _configure_weather(kind: String) -> void:
	var p = weather
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(35, 0.5, 35)
	p.amount = 700
	p.lifetime = 4.0
	p.direction = Vector3(0, -1, 0)
	p.spread = 5.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 4.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	var qm = QuadMesh.new()
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = m
	var col = Color.WHITE
	match kind:
		"rain":
			qm.size = Vector2(0.03, 0.6); p.initial_velocity_min = 22.0; p.initial_velocity_max = 28.0; p.lifetime = 1.0; p.amount = 1200
			col = Color(0.7, 0.8, 1.0, 0.45); p.emission_box_extents = Vector3(30, 0.5, 30)
		"snow":
			qm.size = Vector2(0.09, 0.09); col = Color(1, 1, 1, 0.85); p.spread = 30.0; p.lifetime = 6.0; p.amount = 1400
			p.initial_velocity_min = 1.5; p.initial_velocity_max = 3.5
		"ash":
			qm.size = Vector2(0.08, 0.08); col = Color(1.0, 0.45, 0.1, 0.9); p.spread = 40.0; p.lifetime = 6.0
			p.initial_velocity_min = 0.5; p.initial_velocity_max = 2.0
		"dust":
			qm.size = Vector2(0.12, 0.12); col = Color(0.9, 0.7, 0.45, 0.35); p.direction = Vector3(1, -0.1, 0.3); p.spread = 25.0
			p.initial_velocity_min = 10.0; p.initial_velocity_max = 18.0; p.lifetime = 3.0; p.amount = 1000
		"spores":
			qm.size = Vector2(0.14, 0.14); col = Color(0.6, 1.0, 0.3, 0.7); p.direction = Vector3(0, 1, 0); p.spread = 60.0
			p.initial_velocity_min = 0.3; p.initial_velocity_max = 1.2; p.lifetime = 8.0; p.amount = 500
			p.emission_box_extents = Vector3(30, 8.0, 30)
	p.color = col
	p.mesh = qm

# ---------------------------------------------------------------- HUD
func _markers_begin() -> void:
	markers_used.clear()

func _marker(id: String, text: String, wpos: Vector3, col: Color) -> void:
	if cam.is_position_behind(wpos):
		return
	var sp = cam.unproject_position(wpos)
	var vs = get_viewport().get_visible_rect().size
	if sp.x < 0 or sp.y < 0 or sp.x > vs.x or sp.y > vs.y:
		return
	var l: Label = markers.get(id, null)
	if l == null:
		l = _lab(text, 15, col)
		hud.add_child(l)
		markers[id] = l
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.position = sp + Vector2(10, -10)
	l.visible = true
	markers_used[id] = true

func _markers_end() -> void:
	for id in markers.keys():
		if not markers_used.has(id):
			markers[id].visible = false

func _fmt_dist(d: float) -> String:
	return "%.0f m" % d if d < 2000.0 else "%.1f km" % (d / 1000.0)

func _update_hud(dt: float) -> void:
	if state == S.MENU:
		return
	lbl_warn.text = "" if lbl_warn.text == "" else lbl_warn.text
	var warn = ""
	msg_time -= dt
	if msg_time <= 0.0:
		lbl_msg.text = ""
	var b: Body = info["body"]
	var s = "SYSTEM  %s   (class %s star)\n" % [sysd["name"], sysd["star"]["c"]]
	if b != null and info["dist"] < b.R * 5.0 + 3000.0:
		s += "%s  -  %s\n" % [b.name, b.biome["name"] if b.landable else "Gas Giant (not landable)"]
		s += "Altitude %s" % _fmt_dist(maxf(info["alt"], 0.0))
		if b.landable:
			s += "    Gravity %.1f m/s2" % b.gravity
			if b.biome["hazard"] != "":
				s += "\nHazard: %s" % b.biome["hazard"]
			else:
				s += "\nHazard: none"
			if cur_atmo > 0.02:
				s += "    Atmosphere %d%%" % int(cur_atmo * 100)
			elif not b.biome["atmo"]:
				s += "    No atmosphere"
	elif info["kind"] == "star":
		s += "Near the star - altitude %s" % _fmt_dist(maxf(info["alt"], 0.0))
	else:
		s += "Interplanetary space"
	lbl_loc.text = s
	var st = "Resources %d     Hull %d%%\n" % [resources, int(hull)]
	if state == S.FOOT:
		st += "Suit %d%%   Jetpack %d%%   Health %d%%" % [int(suit), int(jet_fuel), int(health)]
	else:
		st += "Hyperdrive cost: 3 resources"
	lbl_stats.text = st
	# speed
	var sp = vel.length()
	if state == S.FOOT:
		lbl_speed.text = "Speed %.1f m/s" % pv.length()
	elif state == S.LANDED:
		lbl_speed.text = "LANDED"
	else:
		var mode = "CRUISE"
		if pulse_on: mode = "PULSE DRIVE"
		elif boost_on: mode = "BOOST"
		lbl_speed.text = "%s   %s m/s\nspeed limit here: %s m/s" % [mode, ("%.0f" % sp), ("%.0f" % minf(_speed_cap(info["alt"]), 99999.0))]
	# hints & warnings
	var hint = ""
	match state:
		S.LANDED:
			hint = "[F] Exit ship    [W / Space] Take off    [M] Galaxy map    [V] Camera    mouse: orbit view"
		S.SPACE:
			hint = "WASD thrust   mouse steer   Q/E roll   Shift boost   hold Space = pulse drive   [M] map   [V] view"
			if b != null and b.landable and info["alt"] < 80.0:
				hint = "LANDING: keep below 12 m/s, level the ship, use R / Ctrl to adjust height  -  gear is automatic"
			elif info["alt"] > 3000.0 and info["kind"] == "planet":
				hint = "Open space.  Hold SPACE for pulse drive.  Fly to a planet marker and descend.  [M] galaxy map"
		S.FOOT:
			hint = "WASD walk  Shift sprint  Space jump / hold = jetpack  [E] collect  [T] scan  [F] board ship (near ship)"
	lbl_hint.text = hint
	var wtxt = ""
	if state == S.FOOT and cur_body and cur_body.biome["hazard"] != "" and suit < 100.0 and suit > 0.0:
		wtxt = "%s - suit protection %d%%" % [cur_body.biome["hazard"], int(suit)]
	if lbl_warn.text.begins_with("EXOSUIT") and suit > 0.0:
		lbl_warn.text = ""
	if hull < 35.0:
		wtxt = "HULL CRITICAL"
	match bh_warn_level:
		1: wtxt = "WARNING: gravitational anomaly detected - black hole ahead"
		2: wtxt = "DANGER: strong gravity well - pulse drive disabled"
		3: wtxt = "ALERT: PONR in %s - BOOST AWAY NOW!" % _fmt_dist(maxf(ship.global_position.distance_to(bh_root.global_position) - BH_PONR, 0.0))
		4: wtxt = "POINT OF NO RETURN CROSSED - ENGINES CANNOT ESCAPE"
	if state == S.WARP:
		wtxt = ""
	lbl_warn.text = wtxt
	cross.visible = state == S.SPACE or state == S.FOOT
	# markers
	if state == S.SPACE or state == S.LANDED:
		for bd in bodies:
			var dd = ship.global_position.distance_to(bd.global_position)
			if dd > bd.R * 1.2 or true:
				_marker("b" + bd.name, "%s  %s" % [bd.name, _fmt_dist(dd)], bd.global_position, Color(0.7, 0.9, 1.0))
		_marker("star", "%s star  %s" % [sysd["name"], _fmt_dist(ship.global_position.distance_to(star_root.global_position))], star_root.global_position, Color(1.0, 0.9, 0.5))
		var bhd = ship.global_position.distance_to(bh_root.global_position)
		_marker("bh", "BLACK HOLE  %s" % _fmt_dist(bhd), bh_root.global_position, Color(1.0, 0.5, 0.3))
		if state == S.SPACE and b != null and b.landable and info["alt"] < 3000.0:
			_marker("pad", "Landing pad  %s" % _fmt_dist(ship.global_position.distance_to(b.global_position + b.pad_world_pos())), b.global_position + b.pad_world_pos(), Color(0.4, 1.0, 0.6))
	elif state == S.FOOT:
		_marker("ship", "Ship  %s" % _fmt_dist(player.global_position.distance_to(ship.global_position)), ship.global_position + ship.basis.y * 3.0, Color(0.5, 1.0, 0.6))
		if scan_time > 0.0 and scan_target and scan_target.visible:
			scan_time -= dt
			_marker("scan", "%s deposit  %s" % [cur_body.resource_name(), _fmt_dist(player.global_position.distance_to(scan_target.global_position))], scan_target.global_position + scan_target.global_basis.y * 2.0, Color(1.0, 0.8, 0.3))
		var cn = cur_body.nearest_crystal(player.global_position - cur_body.global_position)
		if cn and cn.position.distance_to(player.global_position - cur_body.global_position) < 6.5:
			lbl_hint.text = "[E] Collect %s" % cur_body.resource_name()
		if player.global_position.distance_to(ship.global_position) < 9.0:
			lbl_hint.text = "[F] Board ship   |   " + lbl_hint.text

func _update_fx(dt: float) -> void:
	var vs = get_viewport().get_visible_rect().size
	fx_mat.set_shader_parameter("aspect", vs.x / vs.y)
	# black hole lens
	var bhp = bh_root.global_position
	var d = cam.global_position.distance_to(bhp)
	var str_ = smoothstep(70000.0, 15000.0, d)
	if cam.is_position_behind(bhp):
		str_ = 0.0
	if str_ > 0.0:
		var sp = cam.unproject_position(bhp)
		fx_mat.set_shader_parameter("bh_center", sp / vs)
		var rs = BH_HORIZON / d * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
		fx_mat.set_shader_parameter("bh_rs", rs)
	fx_mat.set_shader_parameter("bh_str", str_)
	bh_root.get_child(0).visible = str_ < 0.25
	var pl = 0.0
	if state == S.SPACE:
		pl = clampf((vel.length() - 500.0) / 2500.0, 0.0, 1.0)
	fx_mat.set_shader_parameter("speed_lines", pl)
	fx_mat.set_shader_parameter("heat", heat)
	flash = maxf(flash - dt * 2.5, 0.0)
	fx_mat.set_shader_parameter("flash", flash)
	if state != S.WARP:
		fx_mat.set_shader_parameter("warp", 0.0)

# ---------------------------------------------------------------- autotest (screenshots)
func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img = get_viewport().get_texture().get_image()
	var dir = shot_dir if shot_dir != "" else "res://shots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	img.save_png(ProjectSettings.globalize_path(dir) + "/" + name + ".png")
	print("SHOT ", name)

func _tp_ship(i: int, alt: float, dirv: Vector3 = Vector3(0.3, 0.5, 0.8)) -> void:
	var b: Body = bodies[i]
	var d = dirv.normalized()
	var wp = b.global_position + d * (b.R + alt)
	ship.global_position = wp
	ship.basis = Basis.looking_at((b.global_position - wp).normalized(), Vector3.UP)
	vel = Vector3.ZERO
	state = S.SPACE
	player.visible = false
	ship_model.visible = true

func _run_autotest() -> void:
	await get_tree().create_timer(1.0).timeout
	await _shot("00_menu")
	_start_game()
	await get_tree().create_timer(1.5).timeout
	await _shot("01_pad")
	galmap.open(sysd, sys_id)
	await get_tree().create_timer(0.5).timeout
	await _shot("01b_map")
	galmap.visible = false
	_exit_ship()
	await get_tree().create_timer(1.5).timeout
	await _shot("02_foot_lush")
	# test movement
	for i in range(60):
		pv = heading * 6.0
		await get_tree().process_frame
	await _shot("02b_walk")
	_interact_force_board()
	# fly sequence around
	_tp_ship(0, 500.0, Vector3(0.4, 0.6, 0.7))
	await get_tree().create_timer(1.0).timeout
	await _shot("03_atmo_lush")
	_tp_ship(0, 3500.0, Vector3(0.5, 0.3, 0.8))
	await get_tree().create_timer(0.8).timeout
	await _shot("04_orbit_lush")
	for i in range(1, bodies.size()):
		_tp_ship(i, bodies[i].R * 1.6 + 600.0, Vector3(0.5, 0.35, 0.8))
		await get_tree().create_timer(0.9).timeout
		await _shot("05_body_%d_%s" % [i, bodies[i].key])
	# landing test: drop onto pad from 60 m
	var b1: Body = bodies[0]
	ship.global_position = b1.global_position + b1.flat_dir * (b1.R + b1.flat_h + 60.0)
	ship.basis = Basis.looking_at(b1.tangent_of(b1.flat_dir), b1.flat_dir)
	state = S.SPACE
	vel = -b1.flat_dir * 12.0
	await get_tree().create_timer(0.5).timeout
	await _shot("03b_descending")
	for i in range(8):
		await get_tree().create_timer(1.0).timeout
		print("  t", i, " alt=", info["alt"], " vel=", vel, " state=", state, " body=", info["body"].name if info["body"] else "none")
	print("LANDING TEST state=", state, " expected LANDED=", S.LANDED, " hull=", hull)
	await _shot("03c_landed")
	# land + walk on every landable body
	for i in range(1, bodies.size()):
		if not bodies[i].landable:
			continue
		_place_ship_on_pad(bodies[i])
		await get_tree().create_timer(0.6).timeout
		_exit_ship()
		await get_tree().create_timer(1.2).timeout
		await _shot("06_foot_%d_%s" % [i, bodies[i].key])
		_interact_force_board()
	# star
	var sw = star_sys_pos - origin
	state = S.SPACE
	ship.global_position = sw + Vector3(0, 1500, 6500)
	ship.basis = Basis.looking_at((sw - ship.global_position).normalized(), Vector3.UP)
	await get_tree().create_timer(0.8).timeout
	await _shot("07_star")
	# black hole
	for dd in [20000.0, 9000.0, 4500.0, 3200.0]:
		ship.global_position = bh_root.global_position + Vector3(0.5, 0.25, 0.8).normalized() * dd
		ship.basis = Basis.looking_at((bh_root.global_position - ship.global_position).normalized(), Vector3.UP)
		vel = Vector3.ZERO
		await get_tree().create_timer(0.7).timeout
		await _shot("08_bh_%d" % int(dd))
	# fall in
	ship.global_position = bh_root.global_position + Vector3(0.5, 0.25, 0.8).normalized() * 2400.0
	ship.basis = Basis.looking_at((bh_root.global_position - ship.global_position).normalized(), Vector3.UP)
	await get_tree().create_timer(1.6).timeout
	await _shot("09_bh_warp")
	await get_tree().create_timer(5.0).timeout
	await _shot("10_new_system")
	print("AUTOTEST DONE state=", state, " sys=", sysd["name"])
	get_tree().quit()

func _interact_force_board() -> void:
	player.visible = false
	state = S.LANDED
