extends Node3D
## Game controller: star system, reference frames, ship flight, on-foot play, black hole, hyperjumps.

enum Mode { MENU, SHIP, FOOT, MAP, WARP }

const SHIP_H := 1.62
const BH_RS := 900.0
const BH_K := 140.0 * 5200.0 * 5200.0
const BH_ZONE := 48000.0
const BH_PONR := 6000.0
const BH_HORIZON := 1150.0

var mode: int = Mode.MENU
var paused := false
var game_time := 0.0

# --- scene
var world: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var hud: Hud
var gmap: GalaxyMap
var lens_rect: ColorRect
var warp_rect: ColorRect
var entry_rect: ColorRect
var star_root: Node3D
var star_mesh: MeshInstance3D
var corona: MeshInstance3D
var bh_root: Node3D
var bh_disc: MeshInstance3D
var bh_sys := Vector3.ZERO
var ship: Node3D
var ship_flames: Array = []
var astro: Node3D
var dust_mm: MultiMesh
var dust_rel: PackedVector3Array = PackedVector3Array()
var weather_nodes: Dictionary = {}
var weather_kind := ""

# --- system
var sys: Dictionary
var sys_idx := 0
var planets: Array = []
var gal_n := Vector3(0.25, 0.95, 0.15).normalized()

# --- frame
var ref: Planet = null
var fmode := 0
var fb := Basis.IDENTITY
var origin_sys := Vector3.ZERO

# --- ship state
var ship_pos := Vector3.ZERO
var ship_vel := Vector3.ZERO
var ship_basis := Basis.IDENTITY
var landed := false
var pulse := false
var pulse_speed := 0.0
var throttle := 0.0
var hull := 100.0
var cockpit := false
var cam_basis := Basis.IDENTITY
var mouse_acc := Vector2.ZERO
var ship_alt := 99999.0
var boosting := false

# --- player state
var p_pos := Vector3.ZERO
var p_vel := Vector3.ZERO
var p_basis := Basis.IDENTITY
var p_pitch := 0.0
var p_health := 100.0
var p_prot := 100.0
var p_fuel := 100.0
var p_grounded := false
var p_first := false
var scan_time := -100.0
var inventory: Dictionary = {}
var units := 0
var beacons_done: Dictionary = {}
var walk_phase := 0.0

# --- misc
var notif := ""
var notif_t := 0.0
var jump_t := 0.0
var jump_target := 0
var jump_kind := ""
var jump_swapped := false
var lod_timer := 0.0
var lod_far_timer := 0.0
var shake := 0.0
var damage_flash := 0.0
var bh_state := 0     # 0 none, 1 warning, 2 pull, 3 past point of no return
var last_hint_t := 0.0
var test_mode := ""
var shot_path := ""

func _ready() -> void:
	_register_inputs()
	Galaxy.init_galaxy()
	_build_scene()
	_load_system(Galaxy.HOME)
	_place_start()
	_enter_menu()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--test="):
			test_mode = a.substr(7)
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
	if test_mode == "bhfull":
		test_mode = "full"
		_fs = 10
	if test_mode != "":
		_start_game()
		set_process_input(false)

# ============================================================== INPUT
func _register_inputs() -> void:
	var map := {
		"fwd": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "up": KEY_SPACE, "down": KEY_CTRL,
		"boost": KEY_SHIFT, "pulse": KEY_F, "interact": KEY_E, "view": KEY_V, "map": KEY_M, "pause": KEY_ESCAPE,
	}
	for k in map.keys():
		if not InputMap.has_action(k):
			InputMap.add_action(k)
		var ev := InputEventKey.new()
		ev.physical_keycode = map[k]
		InputMap.action_add_event(k, ev)
	var ev2 := InputEventKey.new()
	ev2.physical_keycode = KEY_TAB
	InputMap.action_add_event("map", ev2)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_acc += (e as InputEventMouseMotion).relative
	if mode == Mode.MENU:
		return
	if e.is_action_pressed("pause") and mode != Mode.MAP and mode != Mode.WARP:
		_set_paused(not paused)
	if paused:
		return
	if e.is_action_pressed("map") and (mode == Mode.SHIP or mode == Mode.FOOT):
		_open_map()
	elif e.is_action_pressed("view"):
		if mode == Mode.SHIP:
			cockpit = not cockpit
		elif mode == Mode.FOOT:
			p_first = not p_first
	elif e.is_action_pressed("pulse"):
		if mode == Mode.SHIP:
			_toggle_pulse()
		elif mode == Mode.FOOT:
			scan_time = game_time
			_notify("Scanner pulse emitted")
	elif e.is_action_pressed("interact"):
		if mode == Mode.SHIP:
			_exit_ship()
		elif mode == Mode.FOOT:
			_interact_foot()

func _set_paused(v: bool) -> void:
	paused = v
	hud.show_menu("pause" if v else "")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if v else Input.MOUSE_MODE_CAPTURED

func _enter_menu() -> void:
	mode = Mode.MENU
	hud.show_menu("main")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _start_game() -> void:
	mode = Mode.SHIP
	paused = false
	hud.show_menu("")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_acc = Vector2.ZERO
	_notify("Welcome, Traveller. Fly to a planet, land, and explore.")

func _open_map() -> void:
	mode = Mode.MAP
	gmap.open(sys_idx)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gmap.grab_focus()

func _close_map() -> void:
	gmap.visible = false
	mode = Mode.SHIP if _ship_active else Mode.FOOT
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

var _ship_active := true

# ============================================================== SCENE BUILD
func _build_scene() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.12
	cam.far = 1500000.0
	cam.current = true
	world.add_child(cam)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.light_angular_distance = 0.4
	world.add_child(sun)
	# environment + procedural sky
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.12, 0.2)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.6
	env.fog_enabled = true
	env.fog_density = 0.0
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	we.environment = env
	add_child(we)
	# models
	ship = Planet.model("ship").instantiate()
	world.add_child(ship)
	for x in [-0.55, 0.55, -4.4, 4.4]:
		var f := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.26 if abs(x) < 1.0 else 0.18
		cm.height = 1.0
		cm.radial_segments = 10
		f.mesh = cm
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.albedo_color = Color(0.4, 0.75, 1.0, 0.8)
		fm.emission_enabled = true
		fm.emission = Color(0.3, 0.7, 1.0)
		fm.emission_energy_multiplier = 4.0
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		f.material_override = fm
		f.rotation = Vector3(PI * 0.5, 0, 0)
		f.set_meta("x", x)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ship.add_child(f)
		ship_flames.append(f)
	astro = Planet.model("astronaut").instantiate()
	astro.visible = false
	world.add_child(astro)
	# star
	star_root = Node3D.new()
	world.add_child(star_root)
	star_mesh = MeshInstance3D.new()
	var ss := SphereMesh.new()
	ss.radial_segments = 64
	ss.rings = 32
	star_mesh.mesh = ss
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/star.gdshader")
	star_mesh.material_override = sm
	star_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star_root.add_child(star_mesh)
	corona = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	corona.mesh = qm
	var cmat := ShaderMaterial.new()
	cmat.shader = load("res://shaders/corona.gdshader")
	corona.material_override = cmat
	corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corona.extra_cull_margin = 100000.0
	star_root.add_child(corona)
	# black hole
	bh_root = Node3D.new()
	world.add_child(bh_root)
	var hor := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = BH_RS
	hs.height = BH_RS * 2.0
	hs.radial_segments = 48
	hs.rings = 24
	hor.mesh = hs
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = Color.BLACK
	hor.material_override = hm
	hor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bh_root.add_child(hor)
	bh_disc = MeshInstance3D.new()
	bh_disc.mesh = _make_disc_mesh(BH_RS * 1.5, BH_RS * 7.5)
	var dm := ShaderMaterial.new()
	dm.shader = load("res://shaders/disc.gdshader")
	bh_disc.material_override = dm
	bh_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bh_disc.rotation = Vector3(deg_to_rad(14.0), 0, deg_to_rad(6.0))
	bh_root.add_child(bh_disc)
	# space dust
	var dmm := MultiMeshInstance3D.new()
	dust_mm = MultiMesh.new()
	dust_mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 1.0)
	dust_mm.mesh = bm
	dust_mm.instance_count = 160
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color(0.8, 0.9, 1.0, 0.8)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.material = dmat
	dmm.multimesh = dust_mm
	dmm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dmm.custom_aabb = AABB(Vector3(-200, -200, -200), Vector3(400, 400, 400))
	world.add_child(dmm)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 160:
		dust_rel.append(Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized() * rng.randf_range(10.0, 90.0))
	# 2D layers
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	lens_rect = _fullrect("res://shaders/lens.gdshader")
	lens_rect.visible = false
	cl.add_child(lens_rect)
	entry_rect = _fullrect("res://shaders/entry.gdshader")
	entry_rect.visible = false
	cl.add_child(entry_rect)
	warp_rect = _fullrect("res://shaders/warp.gdshader")
	warp_rect.visible = false
	cl.add_child(warp_rect)
	var cl2 := CanvasLayer.new()
	cl2.layer = 2
	add_child(cl2)
	hud = Hud.new()
	hud.start_pressed.connect(_start_game)
	hud.resume_pressed.connect(func(): _set_paused(false))
	hud.quit_pressed.connect(func(): get_tree().quit())
	hud.menu_pressed.connect(func():
		paused = false
		_enter_menu())
	cl2.add_child(hud)
	gmap = GalaxyMap.new()
	gmap.jump_requested.connect(_on_jump_requested)
	gmap.closed.connect(_close_map)
	cl2.add_child(gmap)

func _fullrect(shader_path: String) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(shader_path)
	r.material = m
	return r

func _make_disc_mesh(r0: float, r1: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var segs := 160
	var rings := 6
	for j in rings + 1:
		var r := lerpf(r0, r1, float(j) / rings)
		for i in segs + 1:
			var a := TAU * float(i) / segs
			verts.append(Vector3(cos(a) * r, 0, sin(a) * r))
			uvs.append(Vector2(float(j) / rings, float(i) / segs))
	for j in rings:
		for i in segs:
			var a := j * (segs + 1) + i
			var b := a + 1
			var c := a + segs + 1
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

# ============================================================== SYSTEM
func _load_system(idx: int) -> void:
	for p in planets:
		(p as Planet).queue_free()
	planets.clear()
	sys_idx = idx
	sys = Galaxy.make_system(idx)
	var bodies: Array = sys["bodies"]
	for b in bodies:
		var p := Planet.new()
		world.add_child(p)
		p.setup(b)
		planets.append(p)
	var sr: float = sys["star_radius"]
	var scol: Color = sys["star_color"]
	(star_mesh.mesh as SphereMesh).radius = sr
	(star_mesh.mesh as SphereMesh).height = sr * 2.0
	(star_mesh.material_override as ShaderMaterial).set_shader_parameter("star_color", scol)
	corona.scale = Vector3(sr * 9.0, sr * 9.0, 1.0)
	(corona.material_override as ShaderMaterial).set_shader_parameter("star_color", scol)
	(corona.material_override as ShaderMaterial).set_shader_parameter("core_radius", 1.0 / 4.5 * 1.02)
	var ba: float = sys["bh_angle"]
	var bd: float = sys["bh_distance"]
	bh_sys = Vector3(cos(ba) * bd, 0.0, sin(ba) * bd)
	var h := idx * 2654435761 % 1000
	gal_n = Vector3(sin(h * 0.37), 0.9, cos(h * 0.73)).normalized()
	sky_mat.set_shader_parameter("tint_a", scol.lerp(Color(0.5, 0.6, 1.0), 0.6))
	sky_mat.set_shader_parameter("tint_b", scol.lerp(Color(1.0, 0.7, 0.5), 0.5))
	sky_mat.set_shader_parameter("sun_col", scol)
	sun.light_color = scol.lerp(Color.WHITE, 0.45)
	_update_bodies()

func _place_start() -> void:
	var target: Planet = null
	for p in planets:
		if (p as Planet).landable and (p as Planet).biome["id"] == "lush":
			target = p
			break
	if target == null:
		for p in planets:
			if (p as Planet).landable:
				target = p
				break
	_update_bodies()
	ref = target
	fmode = 1
	fb = Basis.IDENTITY
	origin_sys = ref.sys_pos
	var sunward := (-ref.sys_pos).normalized()
	var side := sunward.cross(Vector3.UP).normalized()
	ship_pos = sunward * ref.R * 5.0 + side * ref.R * 3.2 + Vector3.UP * ref.R * 0.8
	ship_basis = Basis.looking_at(-ship_pos.normalized(), Vector3.UP)
	ship_vel = Vector3.ZERO
	landed = false
	pulse = false
	pulse_speed = 0.0
	cam_basis = ship_basis
	_ship_active = true
	astro.visible = false
	ship.visible = true

func spin_basis(p: Planet) -> Basis:
	return Basis(p.spin_axis, p.spin_rate * game_time + float(p.body["phase"]))

func _update_bodies() -> void:
	for i in planets.size():
		var p: Planet = planets[i]
		var bd: Dictionary = p.body
		var ang: float = float(bd["phase"]) + TAU * game_time / float(bd["period"])
		var o := Vector3(cos(ang), 0.0, sin(ang)) * float(bd["orbit"])
		o = o.rotated(Vector3.RIGHT, float(bd["incl"]))
		var par: int = bd["parent"]
		if par >= 0:
			o += (planets[par] as Planet).sys_pos
		p.sys_pos = o
	if fmode != 0 and ref:
		origin_sys = ref.sys_pos
	fb = spin_basis(ref).inverse() if fmode == 2 else Basis.IDENTITY

func ship_sys() -> Vector3:
	match fmode:
		0: return origin_sys + ship_pos
		1: return ref.sys_pos + ship_pos
	return ref.sys_pos + spin_basis(ref) * ship_pos

func _place_nodes() -> void:
	for p in planets:
		var pl: Planet = p
		pl.position = fb * (pl.sys_pos - origin_sys)
		pl.basis = fb * spin_basis(pl)
	star_root.position = fb * (-origin_sys)
	bh_root.position = fb * (bh_sys - origin_sys)
	bh_disc.rotation.y = game_time * 0.0

# ============================================================== MAIN LOOP
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if mode == Mode.MENU:
		game_time += dt * 0.5
		_update_bodies()
		ship_basis = ship_basis.rotated(Vector3.UP, dt * 0.02).orthonormalized()
		_update_frame_and_view(dt)
		hud.d = {"show": false}
		if test_mode != "":
			_test_step(dt)
		return
	if paused:
		if test_mode != "":
			_test_step(dt)
		return
	game_time += dt
	_update_bodies()
	match mode:
		Mode.SHIP: _ship_step(dt)
		Mode.FOOT: _foot_step(dt)
		Mode.WARP: _warp_step(dt)
	if mode == Mode.MAP:
		pass
	_update_frame_and_view(dt)
	_update_hud(dt)
	if test_mode != "":
		_test_step(dt)

func _update_frame_and_view(dt: float) -> void:
	_check_frame()
	_place_nodes()
	_update_ship_node(dt)
	_update_camera(dt)
	_update_environment(dt)
	_update_lod(dt)
	_update_dust(dt)
	_update_black_hole(dt)

# ------------------------------------------------------------- frames
func _check_frame() -> void:
	match fmode:
		0:
			origin_sys += ship_pos
			ship_pos = Vector3.ZERO
			var ss := origin_sys
			for p in planets:
				var pl: Planet = p
				if (ss - pl.sys_pos).length() < pl.R * 8.0:
					_enter_orbit(pl)
					break
		1:
			var d := ship_pos.length()
			var ssys := ref.sys_pos + ship_pos
			for p in planets:
				var pl2: Planet = p
				if pl2 != ref and (ssys - pl2.sys_pos).length() < pl2.R * 5.0:
					ship_pos = ssys - pl2.sys_pos
					ref = pl2
					origin_sys = ref.sys_pos
					return
			if d > ref.R * 9.0:
				origin_sys = ssys
				ship_pos = Vector3.ZERO
				ref = null
				fmode = 0
			elif ref.landable and d - ref.R < ref.atmo_h * 0.95:
				_enter_surface()
		2:
			if not landed and ship_pos.length() - ref.R > ref.atmo_h * 1.1 and mode == Mode.SHIP:
				_exit_surface()

func _enter_orbit(p: Planet) -> void:
	ship_pos = origin_sys - p.sys_pos
	ref = p
	fmode = 1
	origin_sys = p.sys_pos
	if pulse:
		_set_pulse(false, true)

func _enter_surface() -> void:
	var s := spin_basis(ref)
	var inv := s.inverse()
	var w := ref.spin_axis * ref.spin_rate
	ship_vel = inv * (ship_vel - w.cross(ship_pos))
	ship_pos = inv * ship_pos
	ship_basis = inv * ship_basis
	cam_basis = inv * cam_basis
	fmode = 2
	fb = inv
	if pulse:
		_set_pulse(false, true)
	_notify("Entering atmosphere of %s" % ref.name if ref.density > 0.0 else "Approaching surface of %s" % ref.name)

func _exit_surface() -> void:
	var s := spin_basis(ref)
	var w := ref.spin_axis * ref.spin_rate
	var po := s * ship_pos
	ship_vel = s * ship_vel + w.cross(po)
	ship_pos = po
	ship_basis = s * ship_basis
	cam_basis = s * cam_basis
	fmode = 1
	fb = Basis.IDENTITY

func nearest_surface_dist() -> float:
	var ss := ship_sys()
	var best: float = ss.length() - float(sys["star_radius"])
	for p in planets:
		var pl: Planet = p
		best = minf(best, (ss - pl.sys_pos).length() - pl.R)
	return best

func nearest_body() -> Planet:
	var ss := ship_sys()
	var best: Planet = null
	var bd := 1e12
	for p in planets:
		var pl: Planet = p
		var dd := (ss - pl.sys_pos).length() - pl.R * 1.0
		if dd < bd:
			bd = dd
			best = pl
	return best

# ============================================================== SHIP
func _toggle_pulse() -> void:
	if landed:
		return
	if pulse:
		_set_pulse(false)
		return
	if fmode != 0:
		_notify("Pulse drive requires open space")
		return
	if (bh_sys - ship_sys()).length() < 30000.0:
		_notify("Pulse drive jammed by gravitational shear")
		return
	_set_pulse(true)

func _set_pulse(v: bool, silent := false) -> void:
	pulse = v
	if v:
		pulse_speed = maxf(ship_vel.length(), 300.0)
		_notify("PULSE DRIVE ENGAGED")
	elif not silent:
		_notify("Pulse drive disengaged")

func _ship_step(dt: float) -> void:
	var md := mouse_acc
	mouse_acc = Vector2.ZERO
	var fwd := -ship_basis.z
	var upv := ship_basis.y
	var w := Input.is_action_pressed("fwd")
	var s := Input.is_action_pressed("back")
	var boost := Input.is_action_pressed("boost")
	boosting = boost and not pulse
	var thr_in := (1.0 if w else 0.0) - (0.4 if s else 0.0)
	var alt_cap := 1e9
	var ground_up := Vector3.UP
	var near := nearest_body()
	# ---- altitude above terrain
	ship_alt = 99999.0
	if fmode == 2 and ref.landable:
		var dist := ship_pos.length()
		ground_up = ship_pos / dist
		ship_alt = dist - ref.ground_r(ground_up) - SHIP_H
		alt_cap = clampf(ship_alt * 0.35 + 14.0, 14.0, 1e9)
	elif fmode == 1:
		ship_alt = ship_pos.length() - ref.R
		alt_cap = clampf(ship_alt * 0.35 + 14.0, 14.0, 1e9)
	if landed:
		if w or Input.is_action_pressed("up"):
			landed = false
			ship_vel = ground_up * 5.0
			_notify("Take-off")
		else:
			ship_vel = Vector3.ZERO
			_align_landed(dt, ground_up)
			return
	# ---- rotation (disabled while pulsing precisely: reduced)
	var sens := 0.0022 * (0.5 if pulse else 1.0)
	var yaw := -md.x * sens
	var pitch := -md.y * sens
	var roll := (float(Input.is_action_pressed("left")) - float(Input.is_action_pressed("right"))) * 1.7 * dt
	ship_basis = (ship_basis * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3(0, 0, 1), roll)).orthonormalized()
	# auto-level near the ground
	if fmode == 2 and ship_alt < 90.0:
		var k := smoothstep(90.0, 8.0, ship_alt)
		var f2 := (-ship_basis.z)
		var rr := f2.cross(ground_up)
		if rr.length() > 0.2:
			rr = rr.normalized()
			var up2 := rr.cross(f2).normalized()
			var tgt := Basis(rr, up2, -f2).orthonormalized()
			ship_basis = ship_basis.orthonormalized().slerp(tgt, clampf(k * dt * 2.0, 0.0, 1.0)).orthonormalized()
	fwd = -ship_basis.z
	upv = ship_basis.y
	# ---- velocity control
	var max_speed := 170.0
	var a_max := 120.0
	if boost:
		max_speed = 480.0
		a_max = 230.0
	var v_target := Vector3.ZERO
	if pulse:
		var tgt_speed := minf(12000.0, nearest_surface_dist() * 0.55)
		if tgt_speed < 260.0 or fmode != 0:
			_set_pulse(false)
		else:
			pulse_speed = move_toward(pulse_speed, tgt_speed, maxf(400.0, pulse_speed * 1.1) * dt)
			if pulse_speed > tgt_speed:
				pulse_speed = lerpf(pulse_speed, tgt_speed, clampf(dt * 3.0, 0, 1))
			max_speed = pulse_speed
			a_max = 9000.0
			thr_in = 1.0
	max_speed = minf(max_speed, alt_cap)
	if thr_in != 0.0:
		v_target = fwd * thr_in * max_speed
	var vert := float(Input.is_action_pressed("up")) - float(Input.is_action_pressed("down"))
	if vert != 0.0:
		v_target += upv * vert * minf(70.0, max_speed)
	if v_target.length() > max_speed:
		v_target = v_target.normalized() * max_speed
	if not pulse and ship_vel.length() > max_speed * 1.02 and thr_in == 0.0:
		v_target = Vector3.ZERO
	var pull_a := 0.0
	if fmode == 0:
		pull_a = _bh_pull(dt)
	var dv := v_target - ship_vel
	var step := maxf(a_max - pull_a * 2.2, 0.0) * dt
	if dv.length() > step:
		dv = dv.normalized() * step
	ship_vel += dv
	throttle = clampf(ship_vel.length() / maxf(max_speed if pulse else 480.0, 1.0), 0.0, 1.0)
	# ---- hazards: black hole pull
	if fmode == 0:
		var ssd := ship_sys()
		var sr: float = sys["star_radius"]
		var ds := ssd.length()
		if ds < sr * 1.25:
			ship_vel += ssd.normalized() * 400.0 * dt
			_damage(30.0 * dt)
			_notify("STELLAR HEAT - TURN BACK!", 0.5)
			if ds < sr * 1.02:
				ship_vel = ssd.normalized() * 300.0
	if fmode == 1 and ref.gas and ship_pos.length() < ref.R * 1.06:
		ship_vel += ship_pos.normalized() * 500.0 * dt
		_damage(25.0 * dt)
		_notify("Crushing atmospheric pressure!", 0.5)
	ship_pos += ship_vel * dt
	# ---- terrain contact
	if fmode == 2 and ref.landable:
		var dist2 := ship_pos.length()
		var dir := ship_pos / dist2
		var gr := ref.ground_r(dir)
		if dist2 - gr - SHIP_H <= 0.0:
			var nrm := _ground_normal(ref, dir)
			var vn := ship_vel.dot(nrm)
			ship_pos = dir * (gr + SHIP_H)
			if vn < -20.0:
				_damage((-vn - 20.0) * 2.5 + 5.0)
				ship_vel = ship_vel.bounce(nrm) * 0.3
				shake = 1.0
				_notify("Hard impact!", 1.0)
			else:
				if vn < 0.0:
					ship_vel -= nrm * vn
				ship_vel *= maxf(0.0, 1.0 - 3.0 * dt)
				var tilt := acos(clampf(ship_basis.y.dot(nrm), -1.0, 1.0))
				if ship_vel.length() < 5.0 and thr_in <= 0.05 and vert <= 0.0:
					if tilt < 0.7:
						landed = true
						ship_vel = Vector3.ZERO
						_notify("Landed on %s. Press E to exit the ship." % ref.name)
					else:
						_align_landed(dt, nrm)
	if hull <= 0.0:
		_respawn()

func _ground_normal(p: Planet, dir: Vector3) -> Vector3:
	var t1 := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var t2 := dir.cross(t1)
	var e := 4.0 / p.R
	var h0 := p.ground_r((dir + t1 * e).normalized()) * (dir + t1 * e).normalized() - p.ground_r((dir - t1 * e).normalized()) * (dir - t1 * e).normalized()
	var h1 := p.ground_r((dir + t2 * e).normalized()) * (dir + t2 * e).normalized() - p.ground_r((dir - t2 * e).normalized()) * (dir - t2 * e).normalized()
	var n := h0.cross(h1).normalized()
	if n.dot(dir) < 0.0:
		n = -n
	return n

func _align_landed(dt: float, ground_up: Vector3) -> void:
	if fmode != 2:
		return
	var dist := ship_pos.length()
	var dir := ship_pos / dist
	var nrm := _ground_normal(ref, dir)
	var gr := ref.ground_r(dir)
	ship_pos = dir * (gr + SHIP_H)
	var f2 := (-ship_basis.z).slide(nrm)
	if f2.length() < 0.1:
		return
	f2 = f2.normalized()
	var rr := f2.cross(nrm).normalized()
	var tgt := Basis(rr, nrm, -f2).orthonormalized()
	ship_basis = ship_basis.orthonormalized().slerp(tgt, clampf(dt * 3.0, 0, 1)).orthonormalized()

func _damage(a: float) -> void:
	hull = maxf(hull - a, 0.0)
	damage_flash = 1.0

func _respawn() -> void:
	hull = 100.0
	_notify("Hull breached - systems rebooted at a safe distance")
	if sys_idx != Galaxy.HOME and false:
		pass
	_set_pulse(false, true)
	_place_start()

# ---- black hole
func _bh_pull(dt: float) -> float:
	var ss := ship_sys()
	var to := bh_sys - ss
	var d := to.length()
	var a := BH_K / maxf(d * d, 1.0)
	var applied := 0.0
	if d < BH_ZONE:
		ship_vel += to.normalized() * a * dt
		applied = a
	if pulse and d < 30000.0:
		_set_pulse(false)
		_notify("Pulse drive jammed by gravitational shear", 1.0)
	if d < BH_HORIZON:
		_start_jump(Galaxy.make_system(sys_idx)["bh_target"], "bh")
	return applied

func _update_black_hole(dt: float) -> void:
	if fmode != 0 and not (fmode == 1):
		lens_rect.visible = false
		return
	var rel := bh_root.position
	var d := rel.length()
	var show_lens := false
	if not cam.is_position_behind(rel) and d > BH_RS * 1.1:
		var sp := cam.unproject_position(rel)
		var vp := get_viewport().get_visible_rect().size
		var tanh := tan(deg_to_rad(cam.fov) * 0.5)
		var rs_uv := (BH_RS / d) / (2.0 * tanh)
		if rs_uv > 0.0025:
			show_lens = true
			var m := lens_rect.material as ShaderMaterial
			m.set_shader_parameter("center", Vector2(sp.x / vp.x, sp.y / vp.y))
			m.set_shader_parameter("rs", rs_uv)
			m.set_shader_parameter("aspect", vp.x / vp.y)
			m.set_shader_parameter("strength", clampf(rs_uv * 40.0, 0.2, 1.0))
	lens_rect.visible = show_lens and mode != Mode.MENU

# ============================================================== ON FOOT
func _exit_ship() -> void:
	if not landed or fmode != 2:
		_notify("Land the ship first (hold S / Ctrl near the ground)")
		return
	mode = Mode.FOOT
	_ship_active = false
	var up := ship_pos.normalized()
	var spot := ship_pos + ship_basis.x * 5.5
	var dir := spot.normalized()
	p_pos = dir * (ref.ground_r(dir) + 0.05)
	p_vel = Vector3.ZERO
	p_basis = _tangent_basis(p_pos.normalized(), (-ship_basis.z))
	p_pitch = -0.1
	p_grounded = true
	p_fuel = 100.0
	astro.visible = true
	_notify("Exosuit active. Explore! (F scanner, E interact)")

func _tangent_basis(up: Vector3, f: Vector3) -> Basis:
	var fw := f.slide(up)
	if fw.length() < 0.01:
		fw = up.cross(Vector3.RIGHT)
	fw = fw.normalized()
	return Basis(fw.cross(up).normalized(), up, -fw)

func _foot_step(dt: float) -> void:
	var md := mouse_acc
	mouse_acc = Vector2.ZERO
	var up := p_pos.normalized()
	p_basis = _tangent_basis(up, -p_basis.z)
	p_basis = (Basis(up, -md.x * 0.0024) * p_basis).orthonormalized()
	p_pitch = clampf(p_pitch - md.y * 0.0024, -1.3, 1.3)
	var fwd := -p_basis.z
	var right := p_basis.x
	var inp := Vector2(float(Input.is_action_pressed("right")) - float(Input.is_action_pressed("left")),
		float(Input.is_action_pressed("fwd")) - float(Input.is_action_pressed("back")))
	var sprint := Input.is_action_pressed("boost")
	var g: float = ref.gravity
	var gr_r := ref.ground_r(up)
	var feet_r := p_pos.length()
	var in_water := ref.gen.has_sea and ref.gen.height(up) < ref.gen.sea - 0.2
	var speed := (11.0 if sprint else 5.5) * (0.55 if in_water else 1.0)
	var wish := (fwd * inp.y + right * inp.x)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var v_up := p_vel.dot(up)
	var v_h := p_vel - up * v_up
	var accel := 40.0 if p_grounded else 7.0
	v_h = v_h.move_toward(wish * speed, accel * dt)
	v_up -= g * dt
	var jet := false
	if Input.is_action_pressed("up"):
		if p_grounded:
			v_up = 4.6 + g * 0.1
			p_grounded = false
		elif p_fuel > 0.0:
			v_up = move_toward(v_up, 7.0, (g * 1.9) * dt)
			p_fuel = maxf(p_fuel - 30.0 * dt, 0.0)
			jet = true
	if p_grounded or feet_r - gr_r < 0.1:
		p_fuel = minf(p_fuel + 45.0 * dt, 100.0)
	p_vel = v_h + up * v_up
	p_pos += p_vel * dt
	up = p_pos.normalized()
	gr_r = ref.ground_r(up)
	feet_r = p_pos.length()
	if feet_r <= gr_r:
		p_pos = up * gr_r
		var vu := p_vel.dot(up)
		if vu < -22.0:
			p_health -= (-vu - 22.0) * 3.0
			damage_flash = 1.0
		if vu < 0.0:
			p_vel -= up * vu
		p_grounded = true
	else:
		p_grounded = feet_r - gr_r < 0.15 and v_up <= 0.0
	# ship collision (cylinder, radius 4.2)
	var rel := p_pos - ship_pos
	var relh := rel.slide(up)
	if relh.length() < 4.4 and absf(rel.dot(up)) < 3.5:
		p_pos += relh.normalized() * (4.4 - relh.length())
		p_pos = p_pos.normalized() * maxf(p_pos.length(), ref.ground_r(p_pos.normalized()))
	# bobbing
	if p_grounded and wish.length() > 0.1:
		walk_phase += dt * (14.0 if sprint else 9.0)
	# hazard
	_hazard_step(dt)
	if p_health <= 0.0:
		p_health = 100.0
		p_prot = 100.0
		_notify("Exosuit failure - revived at your ship")
		_exit_ship_respawn()

func _exit_ship_respawn() -> void:
	var dir := (ship_pos + ship_basis.x * 5.5).normalized()
	p_pos = dir * (ref.ground_r(dir) + 0.05)
	p_vel = Vector3.ZERO

func _near_outpost(pos: Vector3, rad: float) -> bool:
	for poi in ref.pois:
		if poi["kind"] == "outpost" or poi["kind"] == "pad":
			if (pos - (poi["node"] as Node3D).position).length() < rad:
				return true
	return false

func _hazard_step(dt: float) -> void:
	var haz: String = ref.biome["hazard"]
	var rate: float = ref.biome["hazard_rate"]
	var sunv := _sun_dir_render()
	var day := smoothstep(-0.15, 0.25, p_pos.normalized().dot(sunv))
	var mult := 1.0
	if haz == "cold":
		mult = 0.5 + 1.2 * (1.0 - day)
	elif haz == "heat":
		mult = 0.4 + 1.3 * day
	if haz == "none":
		p_prot = minf(p_prot + 6.0 * dt, 100.0)
	elif _near_outpost(p_pos, 20.0) or (p_pos - ship_pos).length() < 8.0:
		p_prot = minf(p_prot + 25.0 * dt, 100.0)
	else:
		p_prot = maxf(p_prot - rate * mult * dt * 0.9, 0.0)
	if p_prot <= 0.0:
		p_health -= 3.0 * dt
		damage_flash = maxf(damage_flash, 0.4)
	else:
		p_health = minf(p_health + 3.0 * dt, 100.0)

func _interact_foot() -> void:
	# board ship
	if (p_pos - ship_pos).length() < 9.0:
		mode = Mode.SHIP
		_ship_active = true
		astro.visible = false
		landed = true
		_notify("Back aboard. Press W or Space to take off.")
		return
	# resources
	var best_id := -1
	var bd := 5.0
	for r in ref.current_res:
		var dd := (p_pos - (r["pos"] as Vector3)).length()
		if dd < bd:
			bd = dd
			best_id = r["id"]
	if best_id >= 0:
		ref.collect_resource(best_id)
		var rn: String = ref.biome["resource"]
		inventory[rn] = int(inventory.get(rn, 0)) + 10
		units += 40
		p_prot = minf(p_prot + 12.0, 100.0)
		_notify("Collected %s x10  (+40 Units, hazard protection recharged)" % rn)
		return
	for poi in ref.pois:
		if poi["kind"] == "beacon" and (p_pos - (poi["node"] as Node3D).position).length() < 7.0:
			var key := "%d_beacon" % sys_idx + ref.name
			if beacons_done.has(key):
				_notify("Beacon already scanned")
			else:
				beacons_done[key] = true
				units += 300
				_notify("Beacon data downloaded: +300 Units. Black hole coordinates charted.")
			return
	_notify("Nothing to interact with here")

# ============================================================== JUMPS
func _on_jump_requested(idx: int) -> void:
	if fmode != 0:
		gmap.msg = "Hyperdrive needs open space - leave the planet's vicinity first."
		return
	if mode == Mode.FOOT:
		gmap.msg = "Return to your ship first."
		return
	gmap.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_start_jump(idx, "warp")

func _start_jump(idx: int, kind: String) -> void:
	if mode == Mode.WARP:
		return
	jump_target = idx
	jump_kind = kind
	jump_t = 0.0
	jump_swapped = false
	mode = Mode.WARP
	_set_pulse(false, true)
	var m := warp_rect.material as ShaderMaterial
	m.set_shader_parameter("mode", 1.0 if kind == "bh" else 0.0)
	m.set_shader_parameter("tint", Color(0.8, 0.5, 1.0) if kind == "bh" else Color(0.5, 0.75, 1.0))
	warp_rect.visible = true
	_notify("SINGULARITY TRANSIT..." if kind == "bh" else "HYPERDRIVE ENGAGED", 3.0)

func _warp_step(dt: float) -> void:
	var dur := 5.0 if jump_kind == "bh" else 4.0
	jump_t += dt
	var prog := jump_t / dur
	(warp_rect.material as ShaderMaterial).set_shader_parameter("progress", prog)
	shake = 0.6 * sin(clampf(prog, 0, 1) * PI)
	# stream forward during the jump
	ship_vel = -ship_basis.z * (2000.0 * sin(clampf(prog, 0, 1) * PI) + 100.0)
	ship_pos += ship_vel * dt
	if prog >= 0.5 and not jump_swapped:
		jump_swapped = true
		_arrive(jump_target, jump_kind)
	if prog >= 1.0:
		warp_rect.visible = false
		mode = Mode.SHIP
		_ship_active = true

func _arrive(idx: int, kind: String) -> void:
	_load_system(idx)
	ref = null
	fmode = 0
	fb = Basis.IDENTITY
	landed = false
	var rng := RandomNumberGenerator.new()
	rng.seed = idx * 31 + 7
	if kind == "bh":
		var toward := (-bh_sys).normalized()
		origin_sys = bh_sys + toward * 70000.0 + Vector3(0, 4000, 0)
		ship_basis = Basis.looking_at(toward, Vector3.UP)
		_notify("You emerged from the singularity in the %s system - far across the galaxy." % sys["name"], 6.0)
	else:
		var a := rng.randf() * TAU
		origin_sys = Vector3(cos(a), 0.05, sin(a)) * 52000.0
		ship_basis = Basis.looking_at(-origin_sys.normalized(), Vector3.UP)
		_notify("Arrived in the %s system (class %s star)." % [sys["name"], sys["star_class"]], 6.0)
	ship_pos = Vector3.ZERO
	ship_vel = ship_basis * Vector3(0, 0, -150)
	cam_basis = ship_basis
	_update_bodies()

# ============================================================== VISUALS
func _update_ship_node(dt: float) -> void:
	ship.visible = (mode != Mode.FOOT or true) and not (cockpit and mode == Mode.SHIP)
	ship.transform = Transform3D(ship_basis, ship_pos)
	var thr := 0.0
	if mode == Mode.SHIP and not landed:
		thr = clampf(ship_vel.length() / 200.0, 0.1, 1.0)
		if pulse:
			thr = 3.0
		elif boosting:
			thr = 1.8
	for f in ship_flames:
		var fm: MeshInstance3D = f
		var x: float = fm.get_meta("x")
		var len := thr * 2.6 + 0.05
		fm.scale = Vector3(1, len, 1)
		fm.position = Vector3(x, -0.05 if absf(x) < 1.0 else -0.05, 3.95 + len * 0.5 + (0.0 if absf(x) < 1.0 else -0.5))
		fm.visible = thr > 0.12
	if mode == Mode.FOOT or astro.visible:
		var up := p_pos.normalized()
		var bob := sin(walk_phase) * 0.05 if p_grounded else 0.0
		astro.transform = Transform3D(p_basis.rotated(p_basis.x, 0.04 * sin(walk_phase * 0.5)), p_pos + up * bob)
		astro.visible = mode == Mode.FOOT and not p_first

func _update_camera(dt: float) -> void:
	var fov_t := 75.0
	if mode == Mode.FOOT:
		var up := p_pos.normalized()
		var cb := p_basis * Basis(Vector3.RIGHT, p_pitch)
		cam.near = 0.1
		if p_first:
			cam.global_transform = Transform3D(cb, p_pos + up * 1.65)
		else:
			var target := p_pos + up * 1.7
			var cp := target + cb * Vector3(0.7, 0.45, 4.2)
			var ur := cp.normalized()
			var min_r := ref.ground_r(ur) + 0.5
			if cp.length() < min_r:
				cp = ur * min_r
			cam.global_transform = Transform3D(cb, cp)
		fov_t = 80.0 if Input.is_action_pressed("boost") else 75.0
	else:
		cam.near = 0.15
		cam_basis = cam_basis.orthonormalized().slerp(ship_basis.orthonormalized(), clampf(dt * 9.0, 0.0, 1.0)).orthonormalized()
		var off := Vector3(0.0, 3.4, 12.5)
		var sp := ship_vel.length()
		if pulse:
			off.z += 5.0
		if cockpit:
			off = Vector3(0, 0.75, -0.4)
			cam_basis = ship_basis
		cam.global_transform = Transform3D(cam_basis, ship_pos + cam_basis * off)
		fov_t = 75.0 + (28.0 if pulse else (8.0 if boosting else 0.0))
	# black hole stretching & shake
	var k := 0.0
	if fmode == 0:
		var d := (bh_sys - ship_sys()).length()
		k = smoothstep(26000.0, 1800.0, d)
		fov_t += 35.0 * k
	shake = maxf(shake - dt * 1.5, 0.0)
	var amt := shake * 0.25 + k * 0.5 * clampf(1.0, 0, 1)
	if amt > 0.002:
		cam.global_transform = cam.global_transform.translated_local(Vector3(randf() - 0.5, randf() - 0.5, 0) * amt)
	cam.fov = lerpf(cam.fov, fov_t, clampf(dt * 4.0, 0.0, 1.0))

func _cam_local() -> Vector3:
	# camera position expressed relative to the frame origin (planet centre when in a planet frame)
	return cam.global_position

func _sun_dir_render() -> Vector3:
	return (star_root.position - cam.global_position).normalized()

func _update_environment(dt: float) -> void:
	var cpos := cam.global_position
	var sundir := (star_root.position - cpos).normalized()
	var up := Vector3.UP
	var alt := 1e9
	var dens := 0.0
	var pl: Planet = ref
	var amb := 0.12
	var zen := Color(0.1, 0.2, 0.5)
	var hor := Color(0.5, 0.6, 0.8)
	var fog := 0.0
	if pl != null and fmode >= 1:
		up = cpos.normalized()
		alt = cpos.length() - pl.R
		if pl.landable and not pl.gas:
			alt = cpos.length() - pl.ground_r(up) if alt < 3000.0 else alt
		dens = pl.density
		if not pl.gas and pl.biome.has("sky_zenith"):
			zen = pl.biome["sky_zenith"]
			hor = pl.biome["sky_horizon"]
			amb = pl.biome["ambient"]
			fog = pl.biome["fog"]
	var atmo_k := dens * (1.0 - smoothstep(pl.R * 0.04 if pl else 1.0, pl.R * 0.75 if pl else 2.0, maxf(alt, 0.0))) if pl and fmode >= 1 else 0.0
	var day := smoothstep(-0.15, 0.25, up.dot(sundir))
	sky_mat.set_shader_parameter("sun_dir", sundir)
	sky_mat.set_shader_parameter("up_dir", up)
	sky_mat.set_shader_parameter("zenith", zen)
	sky_mat.set_shader_parameter("horizon", hor)
	sky_mat.set_shader_parameter("atmo", atmo_k)
	sky_mat.set_shader_parameter("gal_n", fb * gal_n)
	env.ambient_light_energy = lerpf(0.5, amb, atmo_k) * (0.22 + 0.78 * (day if atmo_k > 0.05 else 1.0))
	env.ambient_light_color = Color(0.12, 0.14, 0.22).lerp(hor.lerp(zen, 0.4).lerp(Color.WHITE, 0.25), atmo_k)
	env.fog_density = fog * atmo_k
	env.fog_light_color = hor * (0.15 + 0.85 * day)
	var star_dist := star_root.position.distance_to(cpos)
	var en: float = clampf(pow(60000.0 / maxf(star_dist, 6000.0), 0.4), 0.55, 1.5) * (float(sys["lum"]) ** 0.4)
	sun.light_energy = 1.25 * en * (0.04 + 0.96 * (smoothstep(-0.06, 0.12, up.dot(sundir)) if atmo_k > 0.05 else 1.0))
	var up_ref := Vector3.UP if absf(sundir.y) < 0.95 else Vector3.RIGHT
	sun.global_transform = Transform3D(Basis.looking_at(-sundir, up_ref), cpos)
	# planet atmosphere shells
	for p in planets:
		var q: Planet = p
		var local := q.basis.inverse() * (cpos - q.position)
		var h := local.length() - q.R
		var fade := smoothstep(q.R * 0.06, q.R * 0.5, h)
		q.set_atmo_params(sundir if true else Vector3.UP, fade)
		q.set_fog(q == ref and fmode >= 1)
		if q.atmo_mi:
			q.atmo_mi.visible = h > q.R * 0.05
	# weather
	_update_weather(up, alt)
	# atmospheric entry glow
	var spd := ship_vel.length()
	var entry := 0.0
	if mode == Mode.SHIP and pl != null and fmode >= 1 and dens > 0.0 and not landed:
		entry = smoothstep(120.0, 400.0, spd) * dens * smoothstep(pl.R * 0.9, pl.R * 0.25, maxf(alt, 0.0)) * smoothstep(0.0, 80.0, alt)
	entry_rect.visible = entry > 0.02
	(entry_rect.material as ShaderMaterial).set_shader_parameter("intensity", entry)
	if entry > 0.3:
		shake = maxf(shake, entry * 0.25)

func _update_weather(up: Vector3, alt: float) -> void:
	var kind := ""
	if ref and fmode == 2 and not ref.gas and alt < 120.0 and (mode == Mode.FOOT or mode == Mode.SHIP):
		kind = ref.biome["weather"]
		if kind == "none":
			kind = ""
	for k in weather_nodes.keys():
		(weather_nodes[k] as GPUParticles3D).emitting = (k == kind)
	if kind == "":
		return
	if not weather_nodes.has(kind):
		weather_nodes[kind] = _make_weather(kind)
	var wn: GPUParticles3D = weather_nodes[kind]
	var ref_axis := Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD
	var rx := ref_axis.cross(up).normalized()
	var rz := rx.cross(up).normalized()
	wn.global_transform = Transform3D(Basis(rx, up, rz), cam.global_position + up * 12.0)

func _make_weather(kind: String) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(38, 0.5, 38)
	pm.gravity = Vector3.ZERO
	var mesh: Mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match kind:
		"rain":
			gp.amount = 1400
			gp.lifetime = 0.9
			pm.direction = Vector3(0.1, -1, 0)
			pm.initial_velocity_min = 38.0
			pm.initial_velocity_max = 44.0
			pm.particle_flag_align_y = true
			var cm := CylinderMesh.new()
			cm.top_radius = 0.008
			cm.bottom_radius = 0.008
			cm.height = 1.4
			cm.radial_segments = 4
			cm.rings = 1
			mesh = cm
			mat.albedo_color = Color(0.7, 0.8, 1.0, 0.45)
		"snow":
			gp.amount = 1800
			gp.lifetime = 5.0
			pm.direction = Vector3(0.2, -1, 0.1)
			pm.spread = 25.0
			pm.initial_velocity_min = 2.5
			pm.initial_velocity_max = 4.5
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 1.5
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.1
			sm.radial_segments = 6
			sm.rings = 3
			mesh = sm
			mat.albedo_color = Color(1, 1, 1, 0.9)
		"ash":
			gp.amount = 1000
			gp.lifetime = 6.0
			pm.direction = Vector3(0.5, -0.6, 0.2)
			pm.spread = 30.0
			pm.initial_velocity_min = 1.5
			pm.initial_velocity_max = 3.5
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 2.0
			var am := SphereMesh.new()
			am.radius = 0.06
			am.height = 0.12
			am.radial_segments = 6
			am.rings = 3
			mesh = am
			mat.albedo_color = Color(1.0, 0.45, 0.12, 0.9)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.35, 0.05)
			mat.emission_energy_multiplier = 2.0
		"dust":
			gp.amount = 1600
			gp.lifetime = 2.2
			pm.direction = Vector3(1, 0.05, 0.35)
			pm.spread = 12.0
			pm.initial_velocity_min = 20.0
			pm.initial_velocity_max = 30.0
			pm.emission_box_extents = Vector3(38, 14, 38)
			var dm := SphereMesh.new()
			dm.radius = 0.12
			dm.height = 0.24
			dm.radial_segments = 6
			dm.rings = 3
			mesh = dm
			mat.albedo_color = Color(0.85, 0.65, 0.4, 0.28)
		_:
			gp.amount = 500
			gp.lifetime = 7.0
			pm.direction = Vector3(0.1, 1, 0.1)
			pm.spread = 40.0
			pm.initial_velocity_min = 0.4
			pm.initial_velocity_max = 1.2
			pm.emission_box_extents = Vector3(38, 12, 38)
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = 0.8
			var spm := SphereMesh.new()
			spm.radius = 0.07
			spm.height = 0.14
			spm.radial_segments = 6
			spm.rings = 3
			mesh = spm
			mat.albedo_color = Color(0.6, 1.0, 0.4, 0.7)
			mat.emission_enabled = true
			mat.emission = Color(0.4, 1.0, 0.3)
			mat.emission_energy_multiplier = 2.5
	mesh.material = mat
	gp.process_material = pm
	gp.draw_pass_1 = mesh
	gp.local_coords = false
	gp.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	gp.emitting = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(gp)
	return gp

func _update_dust(dt: float) -> void:
	var sp := ship_vel.length()
	var vis := (mode == Mode.SHIP or mode == Mode.WARP) and (fmode == 0 or (ref and cam.global_position.length() - ref.R > ref.R * 0.3))
	dust_mm.visible_instance_count = 160 if vis else 0
	if not vis:
		return
	var vdir := ship_vel.normalized() if sp > 0.5 else -ship_basis.z
	var basis := Basis.looking_at(vdir, Vector3.UP if absf(vdir.y) < 0.95 else Vector3.RIGHT)
	var len := clampf(sp * 0.012, 0.2, 90.0)
	var rng := RandomNumberGenerator.new()
	for i in 160:
		var rel := dust_rel[i]
		rel -= ship_vel * dt
		if rel.length() > 95.0:
			rng.randomize()
			rel = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized() * 90.0
			if sp > 5.0:
				rel = rel.slide(vdir) + vdir * 90.0
		dust_rel[i] = rel
		var b := basis.scaled(Vector3(1, 1, len))
		dust_mm.set_instance_transform(i, Transform3D(b, ship_pos + rel))

func _update_lod(dt: float) -> void:
	lod_timer += dt
	lod_far_timer += dt
	var near_pass := lod_timer > 0.1
	var far_pass := lod_far_timer > 0.9
	if near_pass:
		lod_timer = 0.0
	if far_pass:
		lod_far_timer = 0.0
	var cpos := cam.global_position
	for p in planets:
		var q: Planet = p
		if q.gas:
			continue
		var d := cpos.distance_to(q.position)
		if (d < q.R * 14.0 and near_pass) or far_pass or q.roots.is_empty():
			var local := q.basis.inverse() * (cpos - q.position)
			q.update_lod(local, game_time)
	if ref and fmode >= 1 and ref.landable:
		var pos := p_pos if mode == Mode.FOOT else ship_pos
		var alt := pos.length() - ref.R
		if alt < 500.0 and fmode == 2:
			ref.update_props(pos.normalized(), false)

# ============================================================== HUD
func _notify(s: String, t := 4.0) -> void:
	notif = s
	notif_t = t

func _project_marker(world_pos: Vector3, text: String, col: Color, out: Array) -> void:
	if cam.is_position_behind(world_pos):
		return
	var sp := cam.unproject_position(world_pos)
	var vp := get_viewport().get_visible_rect().size
	if sp.x < 30 or sp.y < 30 or sp.x > vp.x - 30 or sp.y > vp.y - 30:
		return
	out.append({"pos": sp, "text": text, "col": col})

func _fmt_dist(m: float) -> String:
	if m < 1000.0:
		return "%d m" % int(m)
	return "%.1f km" % (m / 1000.0)

func _update_hud(dt: float) -> void:
	var d := {"show": mode != Mode.MAP and mode != Mode.MENU}
	d["sys_name"] = "%s system  |  %s-class star" % [sys["name"], sys["star_class"]]
	d["mode"] = "ship" if mode == Mode.SHIP or mode == Mode.WARP else "foot"
	var loc := "Deep Space"
	var sub := "Interplanetary space"
	var on_planet := false
	var markers: Array = []
	var near := nearest_body()
	var ss := ship_sys()
	if ref != null:
		loc = ref.name
		on_planet = ref.landable and fmode == 2
		sub = ("Gas giant" if ref.gas else "%s world" % ref.biome["label"])
	elif near != null and (ss - near.sys_pos).length() < near.R * 25.0:
		loc = "Near " + near.name
	d["loc_name"] = loc
	d["loc_sub"] = sub
	d["on_planet"] = on_planet
	if on_planet:
		d["gravity"] = ref.gravity
		var hz: String = ref.biome["hazard"]
		d["hazard"] = hz.capitalize() if hz != "none" else "None"
		var dv := smoothstep(-0.15, 0.25, cam.global_position.normalized().dot(_sun_dir_render()))
		d["daytime"] = "Day" if dv > 0.8 else ("Night" if dv < 0.15 else "Dusk / Dawn")
	d["inv"] = inventory
	d["units"] = units
	d["hull"] = hull / 100.0
	d["health"] = p_health / 100.0
	d["prot"] = p_prot / 100.0
	d["fuel"] = p_fuel / 100.0
	d["throttle"] = throttle
	var spd := ship_vel.length()
	d["speed"] = spd
	if fmode >= 1 and ref and mode == Mode.SHIP:
		d["alt"] = ship_pos.length() - (ref.ground_r(ship_pos.normalized()) if fmode == 2 and ref.landable else ref.R)
	var status := ""
	if mode == Mode.WARP:
		status = "JUMPING"
	elif landed:
		status = "LANDED  -  E: exit ship   |   W / Space: take off"
	elif pulse:
		status = "PULSE DRIVE"
	elif boosting:
		status = "BOOST"
	elif fmode == 2:
		status = "ATMOSPHERIC FLIGHT"
	elif fmode == 1:
		status = "PLANETARY ORBIT"
	else:
		status = "INTERPLANETARY CRUISE"
	d["status"] = status
	# notification
	notif_t -= dt
	d["notif"] = notif if notif_t > 0.0 else ""
	d["notif_a"] = notif_t
	damage_flash = maxf(damage_flash - dt * 2.0, 0.0)
	d["vignette"] = damage_flash
	# hints
	var hints: Array = []
	if mode == Mode.SHIP:
		if landed:
			hints = ["E  Exit ship", "W / Space  Take off", "M  Galaxy map"]
		elif fmode == 2:
			hints = ["Hold S / Ctrl to descend gently - land with gear down", "F  Pulse drive   Shift  Boost   M  Galaxy map"]
		else:
			hints = ["W  Throttle   Mouse  Steer   F  Pulse drive   Shift  Boost", "M  Galaxy map & hyperjump   V  Camera"]
	elif mode == Mode.FOOT:
		hints = ["WASD walk   Shift sprint   Space jump / jetpack", "E  Interact   F  Scanner   V  Camera"]
		if (p_pos - ship_pos).length() < 9.0:
			hints.append("E  Board ship")
	d["hints"] = hints
	# markers
	if mode == Mode.SHIP and fmode != 2:
		for p in planets:
			var q: Planet = p
			var dist := (ss - q.sys_pos).length()
			if dist > q.R * 2.5:
				_project_marker(q.position, "%s  %s" % [q.name, _fmt_dist(dist)], Color(0.6, 0.9, 1.0), markers)
		_project_marker(star_root.position, "%s  %s" % [sys["name"], _fmt_dist(ss.length())], Color(1.0, 0.85, 0.4), markers)
		_project_marker(bh_root.position, "SINGULARITY  %s" % _fmt_dist((bh_sys - ss).length()), Color(0.9, 0.4, 1.0), markers)
	if (mode == Mode.FOOT) and game_time - scan_time < 14.0 and ref:
		for poi in ref.pois:
			var pn: Node3D = poi["node"]
			var wp := ref.to_global(pn.position + pn.position.normalized() * 6.0)
			var kind: String = poi["kind"]
			var label := {"pad": "Landing pad", "outpost": "Outpost", "beacon": "Beacon"}.get(kind, kind)
			_project_marker(wp, "%s  %s" % [label, _fmt_dist((p_pos - pn.position).length())], Color(1.0, 0.8, 0.3), markers)
		for r in ref.current_res:
			var wp2 := ref.to_global((r["pos"] as Vector3) + (r["dir"] as Vector3) * 1.2)
			_project_marker(wp2, "%s  %s" % [ref.biome["resource"], _fmt_dist((p_pos - (r["pos"] as Vector3)).length())], ref.biome["res_color"], markers)
	d["markers"] = markers
	# velocity marker
	if mode == Mode.SHIP and spd > 5.0:
		var vp2 := get_viewport().get_visible_rect().size
		var wv := cam.global_position + ship_vel.normalized() * 200.0
		if not cam.is_position_behind(wv):
			d["vel_marker"] = cam.unproject_position(wv)
	# star flare
	var sp2 := star_root.position
	if not cam.is_position_behind(sp2):
		var scr := cam.unproject_position(sp2)
		var vps := get_viewport().get_visible_rect().size
		var fx := 1.0 - clampf(((scr - vps * 0.5) / (vps * 0.5)).length() / 1.6, 0.0, 1.0)
		var sdist := sp2.distance_to(cam.global_position)
		d["flare"] = Vector3(scr.x, scr.y, fx * clampf(60000.0 / sdist, 0.3, 1.5) * (1.0 if fmode < 2 else 0.5))
		d["flare_col"] = (sys["star_color"] as Color)
	# black hole warning
	var bd := (bh_sys - ss).length() if fmode == 0 else 1e9
	if bd < BH_ZONE:
		d["bh_text"] = "GRAVITATIONAL ANOMALY"
		d["bh_level"] = smoothstep(BH_ZONE, BH_PONR, bd)
		var sub2 := "Singularity %s - pull %.0f m/s²" % [_fmt_dist(bd), BH_K / (bd * bd)]
		if bd < BH_PONR:
			d["bh_text"] = "POINT OF NO RETURN"
			sub2 = "Thrusters cannot overcome the pull - %s to the event horizon" % _fmt_dist(bd - BH_RS)
		elif bd < 12000.0:
			d["bh_text"] = "DANGER - CLOSE TO EVENT HORIZON"
		d["bh_sub"] = sub2
	if mode == Mode.FOOT and p_prot <= 0.0:
		d["warn"] = "HAZARD PROTECTION DEPLETED - seek shelter or recharge with resources!"
	elif mode == Mode.FOOT and p_prot < 25.0 and ref.biome["hazard"] != "none":
		d["warn"] = "Hazard protection low: " + ref.biome["hazard"].to_upper()
	hud.d = d

# ============================================================== TEST HARNESS
var _test_t := 0.0
var _test_stage := 0
var _shot_n := 0

func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := "%s_%s.png" % [shot_path, tag]
	img.save_png(path)
	print("SHOT ", path)

var _fps_t := 0.0
func _test_step(dt: float) -> void:
	_test_t += dt
	_fps_t += dt
	if _fps_t > 1.0:
		_fps_t = 0.0
		var tc := 0
		var pc := 0
		if ref:
			tc = ref.tile_count()
			pc = ref.pending.size()
		print("t=%.1f fps=%d tiles_vis=%d pending=%d mode=%d fmode=%d" % [_test_t, Engine.get_frames_per_second(), tc, pc, mode, fmode])
	match test_mode:
		"space":
			if _test_t > 1.5 and _test_stage == 0:
				_test_stage = 1
				_shot("orbit_view")
			if _test_t > 2.0:
				get_tree().quit()
		"flow":
			_test_flow(dt)
		"full":
			_test_full(dt)
		"ui":
			_test_ui(dt)
		"bh":
			_test_bh(dt)

func _goto(p: Planet, dir_h: float, alt_m: float, face_down := false) -> void:
	# put ship in surface frame above planet p, at fixed direction
	var dir := Vector3(0.3, 0.8, 0.5).normalized()
	ref = p
	fmode = 2
	_update_bodies()
	origin_sys = p.sys_pos
	fb = spin_basis(p).inverse()
	ship_pos = dir * (p.ground_r(dir) + alt_m)
	var fwd := dir.cross(Vector3.UP).normalized()
	ship_basis = _tangent_basis(dir, fwd)
	ship_vel = Vector3.ZERO
	landed = false
	cam_basis = ship_basis

func _test_flow(dt: float) -> void:
	# scripted tour: for each landable planet teleport near surface, shoot screenshots
	var landables: Array = []
	for p in planets:
		if (p as Planet).landable:
			landables.append(p)
	var stage_len := 4.5
	var i := int(_test_t / stage_len)
	var local_t := fmod(_test_t, stage_len)
	if i >= landables.size() + 1:
		print("TEST DONE")
		get_tree().quit()
		return
	if i == 0 and _test_stage == 0:
		_test_stage = 1
		_shot("start")
		var pl: Planet = landables[1]
		_goto(pl, 0.0, 60.0)
	if i >= 1 and i <= landables.size():
		var pl2: Planet = landables[i - 1]
		if _test_stage != i + 1:
			_test_stage = i + 1
			_goto(pl2, 0.0, 12.0)
			landed = true
			ship_vel = Vector3.ZERO
			_ship_active = false
			mode = Mode.FOOT
			p_first = false
			var dir := ship_pos.normalized()
			p_pos = dir * (pl2.ground_r(dir) + 0.05)
			p_basis = _tangent_basis(dir, ship_basis.z)
			p_pitch = -0.05
			p_grounded = true
			astro.visible = true
			ship_pos = dir * (pl2.ground_r(dir) + SHIP_H)
			ship_pos += (ship_basis.x * -9.0)
			ship_pos = ship_pos.normalized() * (pl2.ground_r(ship_pos.normalized()) + SHIP_H)
			pl2.update_props(dir, true)
		if local_t > 3.8 and _test_stage == i + 1:
			_test_stage = -1
			_shot("planet%d_%s" % [i, pl2.name])
			_test_stage = i + 1000

func _test_bh(dt: float) -> void:
	if _test_stage == 0:
		_test_stage = 1
		ref = null
		fmode = 0
		fb = Basis.IDENTITY
		origin_sys = bh_sys + Vector3(-1, 0.1, -0.3).normalized() * 30000.0
		ship_pos = Vector3.ZERO
		ship_basis = Basis.looking_at((bh_sys - origin_sys).normalized(), Vector3.UP)
		ship_vel = Vector3.ZERO
		cam_basis = ship_basis
	if _test_t > 2.0 and _test_stage == 1:
		_test_stage = 2
		_shot("bh_far")
		origin_sys = bh_sys + Vector3(-1, 0.1, -0.3).normalized() * 14000.0
		ship_basis = Basis.looking_at((bh_sys - origin_sys).normalized(), Vector3.UP)
		cam_basis = ship_basis
	if _test_t > 4.0 and _test_stage == 2:
		_test_stage = 3
		_shot("bh_mid")
		origin_sys = bh_sys + Vector3(-1, 0.1, -0.3).normalized() * 7000.0
		ship_basis = Basis.looking_at((bh_sys - origin_sys).normalized(), Vector3.UP)
		cam_basis = ship_basis
	if _test_t > 6.0 and _test_stage == 3:
		_test_stage = 4
		_shot("bh_near")
	if _test_t > 12.0:
		print("jump mode: ", mode, " sys ", sys_idx)
		get_tree().quit()

var _fs := 0
var _ft := 0.0
func _aim(target_local: Vector3) -> void:
	var dirv := (target_local - ship_pos).normalized()
	var upr := ship_pos.normalized() if fmode >= 1 else Vector3.UP
	if absf(dirv.dot(upr)) > 0.98:
		upr = Vector3.RIGHT
	ship_basis = Basis.looking_at(dirv, upr)

func _stage(n: int, msg: String) -> void:
	_fs = n
	_ft = 0.0
	print("STAGE %d: %s (t=%.1f fmode=%d alt=%.0f landed=%s)" % [n, msg, _test_t, fmode, ship_alt, str(landed)])

func _test_full(dt: float) -> void:
	_ft += dt
	match _fs:
		0:
			_stage(1, "approach planet")
		1:
			Input.action_press("fwd")
			Input.action_press("boost")
			if ref and fmode == 1:
				_aim(Vector3.ZERO)
			elif ref and fmode == 2:
				_stage(2, "in atmosphere")
			elif fmode == 0:
				_aim(ref.sys_pos - origin_sys if ref else Vector3.ZERO)
			if _ft > 60.0:
				_stage(99, "TIMEOUT approach")
		2:
			Input.action_release("boost")
			var target := ref.pad_pos + ref.pad_pos.normalized() * 25.0
			_aim(target)
			var horiz := (ship_pos - ref.pad_pos).slide(ref.pad_pos.normalized()).length()
			if horiz < 60.0:
				Input.action_release("fwd")
				Input.action_press("down")
				_stage(3, "descend over pad")
			if _ft > 90.0:
				_stage(99, "TIMEOUT to pad")
		3:
			var horiz2 := (ship_pos - ref.pad_pos).slide(ref.pad_pos.normalized()).length()
			if horiz2 > 14.0:
				Input.action_press("fwd")
				_aim(ref.pad_pos + ref.pad_pos.normalized() * 6.0)
			else:
				Input.action_release("fwd")
			if _ft > 3.0 and int(_ft * 2.0) % 6 == 0:
				pass
			if landed:
				Input.action_release("down")
				_shot("landed")
				_stage(4, "landed")
			if _ft > 80.0:
				_stage(99, "TIMEOUT landing")
		4:
			if _ft > 1.0:
				_exit_ship()
				_stage(5, "exited ship; walk")
		5:
			Input.action_press("fwd")
			if _ft > 1.0 and _ft < 1.1:
				Input.action_press("up")
			if _ft > 1.3:
				Input.action_release("up")
			if _ft > 4.0:
				_shot("walking")
				Input.action_release("fwd")
				scan_time = game_time
				_stage(6, "scanner")
		6:
			if _ft > 1.0:
				_shot("scan")
				_stage(7, "return to ship")
		7:
			var dirs := (ship_pos - p_pos)
			p_basis = _tangent_basis(p_pos.normalized(), dirs)
			Input.action_press("fwd")
			if dirs.length() < 8.0:
				Input.action_release("fwd")
				_interact_foot()
				_stage(8, "boarded: mode=%d" % mode)
			if _ft > 40.0:
				_stage(99, "TIMEOUT return")
		8:
			if _ft > 1.0:
				Input.action_press("up")
				Input.action_press("fwd")
				_stage(9, "takeoff")
		9:
			ship_basis = _tangent_basis(ship_pos.normalized(), ship_basis.y).rotated(ship_basis.x, 0.0)
			ship_basis = Basis.looking_at(ship_pos.normalized() * 0.4 + (-ship_basis.z).slide(ship_pos.normalized()).normalized() * 0.6, ship_pos.normalized())
			if fmode != 2 or _ft > 25.0:
				Input.action_release("up")
				Input.action_release("fwd")
				_stage(10, "reached space fmode=%d" % fmode)
		10:
			# black hole: teleport to 20 km
			Input.action_press("fwd")
			ref = null
			fmode = 0
			fb = Basis.IDENTITY
			origin_sys = bh_sys + Vector3(-1, 0.1, -0.3).normalized() * 8000.0
			ship_pos = Vector3.ZERO
			ship_basis = Basis.looking_at(Vector3(1, 0, 0.3).normalized(), Vector3.UP)
			ship_vel = Vector3.ZERO
			cam_basis = ship_basis
			Input.action_release("fwd")
			_stage(11, "bh pull")
		11:
			var bd := (bh_sys - ship_sys()).length()
			if int(_ft) != int(_ft - dt):
				print("bh d=%.0f v=%.1f mode=%d landed=%s pulse=%s" % [bd, ship_vel.length(), mode, str(landed), str(pulse)])
			if bd < 8500.0 and not _shot_done("bh1"):
				_shot("bh_approach")
			if bd < 4000.0 and not _shot_done("bh2"):
				_shot("bh_close")
			if bd < 1800.0 and not _shot_done("bh3"):
				_shot("bh_horizon")
			if mode == Mode.WARP:
				_stage(12, "bh jump started")
			if _ft > 70.0:
				_stage(99, "TIMEOUT bh")
		12:
			if _ft > 3.0:
				_shot("bh_warp")
			if mode == Mode.SHIP:
				_stage(13, "arrived sys=%d name=%s" % [sys_idx, sys["name"]])
		13:
			if _ft > 3.0:
				_shot("arrived")
				print("FULL TEST DONE")
				get_tree().quit()
		99:
			print("FULL TEST FAILED")
			get_tree().quit()

var _shots_done := {}
func _shot_done(k: String) -> bool:
	if _shots_done.has(k):
		return true
	_shots_done[k] = true
	return false

func _test_ui(dt: float) -> void:
	if _test_stage == 0 and _test_t > 0.2:
		_test_stage = 1
		_enter_menu()
	if _test_stage == 1 and _test_t > 1.2:
		_test_stage = 2
		_shot("menu")
		hud._show_controls(hud.main_menu)
	if _test_stage == 2 and _test_t > 1.8:
		_test_stage = 3
		_shot("controls")
		hud._hide_controls()
		_start_game()
	if _test_stage == 3 and _test_t > 3.0:
		_test_stage = 4
		_set_paused(true)
	if _test_stage == 4 and _test_t > 3.6:
		_test_stage = 5
		_shot("pause")
		_set_paused(false)
		_open_map()
		gmap.selected = 12
	if _test_stage == 5 and _test_t > 4.5:
		_test_stage = 6
		_shot("map")
		ref = null
		fmode = 0
		fb = Basis.IDENTITY
		origin_sys = Vector3(60000, 0, 0)
		ship_pos = Vector3.ZERO
		_on_jump_requested(gmap.selected)
		gmap.visible = false
	if _test_stage == 6 and _test_t > 6.0:
		_test_stage = 7
		_shot("warp")
	if _test_stage == 7 and _test_t > 9.5:
		_test_stage = 8
		_shot("arrived_sys")
		print("UI TEST DONE sys=", sys_idx, " ", sys["name"])
		get_tree().quit()
