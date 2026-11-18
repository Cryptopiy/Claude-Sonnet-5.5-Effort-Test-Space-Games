extends Node
## Game root: wires the universe, ship, astronaut, camera, HUD, menus and the transitions (warp, black hole).

enum Mode { MENU, SHIP, FOOT }

const DUST_SHADER := preload("res://shaders/dust.gdshader")
const FOV_BASE := 72.0

var galaxy: Galaxy
var uni: Universe
var ship: Ship
var player: Player
var camera: Camera3D
var hud: Hud
var menus: Menus
var map_layer: CanvasLayer
var map: GalaxyMap
var weather: Weather
var dust: MultiMeshInstance3D
var dust_mat: ShaderMaterial

var mode: int = Mode.MENU
var paused: bool = false
var map_open: bool = false
var in_game: bool = false
var current_id: int = 0
var units: int = 0
var look_accum: Vector2 = Vector2.ZERO
var just: Dictionary = {}
var fake_input: Dictionary = {}
var menu_t: float = 0.0
var cam_lag: Vector3 = Vector3.ZERO
var fov_cur: float = FOV_BASE
var alert_t: float = 0.0
var visited_bh: int = 0
var trans: Dictionary = {}  # active transition: {kind, t, dest, phase}
var autotest: Node = null
var audio: EngineAudio
var test_mode: bool = false
var _first_frame: bool = true
var discovered: Dictionary = {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("auto"):
			test_mode = true
	if test_mode:
		get_window().unfocusable = true
	galaxy = Galaxy.new()
	uni = Universe.new()
	uni.name = "Universe"
	add_child(uni)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.15
	camera.far = 4.0e6
	camera.fov = FOV_BASE
	camera.current = true
	add_child(camera)
	ship = Ship.new()
	ship.name = "Ship"
	player = Player.new()
	player.name = "Player"
	weather = Weather.new()
	add_child(weather)
	_make_dust()
	audio = EngineAudio.new()
	add_child(audio)
	hud = Hud.new()
	add_child(hud)
	hud.set_visible_hud(false)
	menus = Menus.new()
	add_child(menus)
	map_layer = CanvasLayer.new()
	map_layer.layer = 25
	add_child(map_layer)
	map = GalaxyMap.new()
	map_layer.add_child(map)
	map.warp_requested.connect(_on_warp_requested)
	map.closed.connect(_close_map)
	menus.start_game.connect(_start_game)
	menus.resume_game.connect(_resume)
	menus.open_map.connect(_open_map_from_pause)
	menus.quit_to_menu.connect(_to_menu)
	menus.quit_game.connect(func(): get_tree().quit())
	ship.message.connect(hud.show_message)
	ship.crashed.connect(func(dmg: float): hud.hit_flash(Color(1, 0.15, 0.05), clampf(dmg / 60.0, 0.15, 0.6)))
	ship.destroyed.connect(_on_ship_destroyed)
	ship.horizon_crossed.connect(_on_horizon_crossed)
	ship.landed.connect(_on_landed)
	ship.took_off.connect(func(): hud.show_message("LIFT OFF", 0))
	player.message.connect(hud.show_message)
	player.interact.connect(_on_interact)
	player.died.connect(_on_player_died)
	uni.add_child(ship)
	uni.load_system(galaxy.get_system(0))
	current_id = 0
	_set_mode_menu()
	if test_mode:
		var at := load("res://scripts/dev/autotest.gd")
		autotest = at.new()
		autotest.main = self
		add_child(autotest)


func _make_dust() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.center_offset = Vector3(0, 0.5, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = 700
	dust = MultiMeshInstance3D.new()
	dust.multimesh = mm
	dust_mat = ShaderMaterial.new()
	dust_mat.shader = DUST_SHADER
	dust.material_override = dust_mat
	dust.custom_aabb = AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.visible = false
	add_child(dust)


# ------------------------------------------------------------------ mode / state
func _set_mode_menu() -> void:
	mode = Mode.MENU
	in_game = false
	paused = false
	hud.set_visible_hud(false)
	menus.show_main()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ship.visible = false
	if camera.get_parent() != self:
		camera.reparent(self, false)
	weather.set_kind("none")


func _start_game() -> void:
	if current_id != 0:
		_switch_system(0, "home")
	var start: PlanetBody = uni.bodies[uni.system.start_planet]
	if player.get_parent():
		player.get_parent().remove_child(player)
	ship.visible = true
	ship.hull = Ship.MAX_HULL
	ship.shield = 100.0
	ship.place_on_pad(start)
	player.ship_ref = ship
	player.planet = start
	units = 0
	player.inventory.clear()
	player.power_cells = 2
	player.protection = 100.0
	player.health = 100.0
	trans = {}
	ship.warp_lock = false
	ship.vg = Vector3.ZERO
	hud.fade = 0.0
	hud.tunnel = 0.0
	in_game = true
	paused = false
	menus.hide_all()
	hud.set_visible_hud(true)
	_enter_ship_mode(true)
	uni.set_origin_at_world(ship.global_position)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_message("Welcome, Explorer. Your ship is on the landing pad of %s." % start.data.name, 0)
	hud.show_message("[E] exit ship  ·  [Space] take off  ·  [M] galaxy map", 0)


func _enter_ship_mode(first: bool = false) -> void:
	mode = Mode.SHIP
	player.visible = false
	camera.reparent(ship.cam_mount, false)
	ship.set_cockpit(false)
	camera.position = ship.camera_chase
	camera.rotation = Vector3.ZERO
	cam_lag = Vector3.ZERO
	weather.set_kind("none")
	if player.get_parent():
		player.get_parent().remove_child(player)


func _exit_ship_mode() -> void:
	if ship.state != Ship.State.LANDED:
		return
	var pl: PlanetBody = ship.planet
	var local := ship.position + ship.basis.x * 9.0 + ship.basis.z * 2.0
	player.spawn_at(pl, local.normalized() * (pl.data.radius + 10.0), -ship.basis.z)
	player.visible = true
	player.ship_ref = ship
	mode = Mode.FOOT
	ship.set_cockpit(false)
	camera.reparent(player.cam_mount, false)
	camera.position = player.camera_offset()
	camera.rotation = Vector3.ZERO
	weather.set_kind(pl.data.weather)
	hud.show_message("Exploring %s  ·  [Q] scanner  ·  hold [LMB] to mine crystals" % pl.data.name, 0)


func _pause() -> void:
	if not in_game or paused:
		return
	paused = true
	menus.show_pause()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume() -> void:
	paused = false
	menus.hide_all()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _to_menu() -> void:
	if ship.get_parent() != uni and ship.get_parent() != null:
		pass
	_set_mode_menu()


func _open_map() -> void:
	if not in_game or not trans.is_empty():
		return
	map_open = true
	hud.set_visible_hud(false)
	var ok := _can_warp()
	map.uni = uni
	uni.set_meta("ship_upos", uni.world_to_u(_actor_pos()))
	map.open(galaxy, uni, current_id, ok[0], ok[1])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _open_map_from_pause() -> void:
	paused = false
	menus.hide_all()
	_open_map()


func _close_map() -> void:
	map_open = false
	map.visible = false
	hud.set_visible_hud(in_game)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _can_warp() -> Array:
	if mode != Mode.SHIP or ship.state != Ship.State.FLYING:
		return [false, "Hyperdrive requires you to be flying your ship in open space."]
	var inf := uni.info
	var near: PlanetBody = uni.nearest_body(ship.global_position)
	if near and ship.altitude < near.data.radius * 3.0:
		return [false, "Too close to %s - climb out of its gravity well to warp." % near.data.name]
	if uni.bh and ship.bh_dist >= 0.0 and ship.bh_dist < BlackHole.SHEAR_RANGE:
		return [false, "Hyperdrive offline: gravitational shear from the black hole."]
	if uni.star and ship.global_position.distance_to(uni.star.global_position) < uni.star.radius * 5.0:
		return [false, "Too close to the star."]
	return [true, ""]


func _actor_pos() -> Vector3:
	return ship.global_position if mode != Mode.FOOT else player.global_position


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and in_game and not paused and not map_open:
		look_accum += (event as InputEventMouseMotion).relative
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		just[k] = true
		match k:
			KEY_ESCAPE:
				if map_open:
					_close_map()
				elif in_game:
					if paused:
						_resume()
					else:
						_pause()
			KEY_M:
				if in_game and not paused:
					if map_open:
						_close_map()
					else:
						_open_map()
			KEY_F3:
				hud.show_fps = not hud.show_fps


func _jp(k: int) -> bool:
	return just.get(k, false)


func _ship_input() -> Dictionary:
	var i := {}
	i["look"] = look_accum
	i["roll"] = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	i["thrust"] = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	i["strafe"] = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	i["vert"] = float(Input.is_physical_key_pressed(KEY_R)) - float(Input.is_physical_key_pressed(KEY_F))
	i["boost"] = Input.is_physical_key_pressed(KEY_SHIFT)
	i["brake"] = Input.is_physical_key_pressed(KEY_CTRL)
	i["cut"] = _jp(KEY_X)
	i["pulse_toggle"] = _jp(KEY_SPACE)
	i["takeoff"] = Input.is_physical_key_pressed(KEY_SPACE)
	for k in fake_input:
		i[k] = fake_input[k]
	return i


func _foot_input() -> Dictionary:
	var i := {}
	i["look"] = look_accum
	i["move"] = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	i["sprint"] = Input.is_physical_key_pressed(KEY_SHIFT)
	i["jump_pressed"] = _jp(KEY_SPACE)
	i["jump_held"] = Input.is_physical_key_pressed(KEY_SPACE)
	i["fire"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	i["interact"] = _jp(KEY_E)
	for k in fake_input:
		i[k] = fake_input[k]
	return i


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	hud.process_fx(dt)
	if not in_game:
		_menu_backdrop(dt)
		just.clear()
		look_accum = Vector2.ZERO
		return
	if paused or map_open:
		# keep rendering the scene, just don't simulate
		uni.update_environment(camera.global_position, 0.0)
		if map_open:
			uni.set_meta("ship_upos", uni.world_to_u(_actor_pos()))
		just.clear()
		look_accum = Vector2.ZERO
		return
	_update_transition(dt)
	# 1. world motion (orbits, spin) and ship frame-carry
	var carry_ship: Node3D = null
	if mode == Mode.SHIP and ship.state == Ship.State.FLYING:
		carry_ship = ship
	var vref := [ship.velocity]
	uni.advance(dt, carry_ship, vref)
	if carry_ship:
		ship.velocity = vref[0]
	# 2. actors
	var locked := not trans.is_empty()
	if mode == Mode.SHIP:
		var inp := _ship_input()
		if locked:
			inp = {"look": Vector2.ZERO}
		if _jp(KEY_V):
			ship.set_cockpit(not ship.cockpit_view)
			hud.show_message("Cockpit view" if ship.cockpit_view else "Chase view", 0)
		if _jp(KEY_E) and ship.state == Ship.State.LANDED and not locked:
			_exit_ship_mode()
		else:
			ship.update_ship(dt, inp, uni)
	elif mode == Mode.FOOT:
		var inp2 := _foot_input()
		player.update_player(dt, inp2, uni)
		if _jp(KEY_V):
			player.set_third_person(not player.third_person)
		if _jp(KEY_Q):
			player.do_scan()
		if _jp(KEY_R):
			player.use_power_cell()
	# 3. floating origin
	var shift := uni.rebase(_actor_pos(), [ship, dust, weather])
	# 4. camera + environment
	_update_camera(dt)
	uni.update_environment(camera.global_position, dt)
	_update_effects(dt)
	_update_audio()
	_update_hud(dt)
	just.clear()
	look_accum = Vector2.ZERO


func _menu_backdrop(dt: float) -> void:
	menu_t += dt * 0.05
	var idx := uni.system.start_planet
	var pb: PlanetBody = uni.bodies[idx]
	uni.sim_time += dt * 20.0
	uni._update_orbits(dt)
	var a := menu_t * 3.0
	var lp := Vector3(cos(a), 0.18, sin(a)).normalized() * pb.data.radius * 2.6
	var world := pb.global_position + pb.global_basis * lp
	uni.set_origin_at_world(world)
	camera.global_position = Vector3.ZERO
	var target: Vector3 = uni.bodies[idx].global_position
	camera.look_at(target, Vector3.UP)
	camera.fov = 55.0
	uni.update_environment(Vector3.ZERO, dt)
	dust.visible = false


func _update_camera(dt: float) -> void:
	var target_fov := FOV_BASE
	if mode == Mode.SHIP:
		var shake_v := Vector3(randf() - 0.5, randf() - 0.5, 0.0) * ship.shake * 0.35
		if ship.cockpit_view:
			camera.position = ship.camera_cockpit + shake_v * 0.4
			camera.rotation = Vector3.ZERO
		else:
			var lv := ship.global_basis.inverse() * ship.total_velocity()
			var want := Vector3(-clampf(lv.x * 0.012, -2.5, 2.5), -clampf(lv.y * 0.012, -2.0, 2.0), clampf(absf(lv.z) * 0.0015, 0.0, 5.0))
			cam_lag = cam_lag.lerp(want, 1.0 - exp(-4.0 * dt))
			camera.position = ship.camera_chase + cam_lag + shake_v
			camera.rotation = Vector3.ZERO
		if ship.state == Ship.State.FLYING:
			target_fov += clampf(ship.speed / 1100.0, 0.0, 1.0) * 10.0
			if ship.pulse:
				target_fov += 22.0
			if ship.bh_dist > 0.0 and ship.bh_dist < BlackHole.PNR * 3.0:
				target_fov += 18.0 * (1.0 - ship.bh_dist / (BlackHole.PNR * 3.0))
	elif mode == Mode.FOOT:
		camera.position = player.camera_offset()
		camera.rotation = Vector3.ZERO
		if player.sprinting:
			target_fov += 6.0
	fov_cur = lerpf(fov_cur, target_fov, 1.0 - exp(-5.0 * dt))
	camera.fov = fov_cur


func _update_effects(dt: float) -> void:
	# space dust / speed streaks
	var show_dust: bool = mode == Mode.SHIP and ship.state == Ship.State.FLYING and uni.info.get("atm", 0.0) < 0.04
	dust.visible = show_dust
	if show_dust:
		var L := 240.0
		dust_mat.set_shader_parameter("origin_mod", Vector3(fposmod(uni.origin[0], L), fposmod(uni.origin[1], L), fposmod(uni.origin[2], L)))
		dust_mat.set_shader_parameter("vel", ship.total_velocity())
		dust_mat.set_shader_parameter("L", L)
	# overlay fx
	var heat := ship.heat if mode == Mode.SHIP else 0.0
	hud.heat_fx = lerpf(hud.heat_fx, heat, 1.0 - exp(-6.0 * dt))
	var w := 0.0
	if mode == Mode.SHIP and ship.pulse:
		w = clampf(ship.speed / 14000.0, 0.0, 1.0) * 0.55
	if trans.get("kind", "") == "warp":
		w = maxf(w, clampf(trans["t"] / 2.2, 0.0, 1.0) * 0.9)
	hud.warp = lerpf(hud.warp, w, 1.0 - exp(-6.0 * dt))
	var b := 0.0
	if mode == Mode.SHIP and ship.bh_dist > 0.0 and uni.bh:
		b = clampf(1.0 - (ship.bh_dist - uni.bh.rs) / (BlackHole.PNR * 4.5), 0.0, 1.0)
		b = b * b
	if trans.get("kind", "") == "blackhole":
		b = 1.0
	hud.bh_fx = lerpf(hud.bh_fx, b, 1.0 - exp(-4.0 * dt))
	hud.underwater = 0.0
	if mode == Mode.FOOT and player.in_liquid and player.planet.data.liquid == "water":
		hud.underwater = 0.0
	# weather follows the camera
	if mode == Mode.FOOT and player.planet:
		var up := player.global_basis.y
		var wind := Vector3(0.7, 0.0, 0.4).normalized()
		wind = (wind - up * wind.dot(up)).normalized()
		weather.follow(camera.global_position, up, wind)
		player.weather_factor = 1.0


func _update_audio() -> void:
	audio.master = 0.0 if (paused or map_open) else 1.0
	var inf := uni.info
	if mode == Mode.SHIP:
		if ship.state == Ship.State.FLYING:
			audio.engine_power = clampf(ship.throttle * 0.7 + (0.6 if ship.boosting else 0.0) + (1.2 if ship.pulse else 0.0) + 0.2, 0.0, 2.0)
		else:
			audio.engine_power = 0.0
		audio.wind = clampf(inf.get("atm", 0.0), 0.0, 1.0) * clampf(ship.speed / 500.0, 0.0, 1.0) * 0.5
		audio.rumble = 0.0
		if uni.bh and ship.bh_dist > 0.0:
			audio.rumble = clampf(1.0 - ship.bh_dist / BlackHole.WARN_RANGE, 0.0, 1.0) * 0.8
	else:
		audio.engine_power = 0.0
		audio.wind = clampf(inf.get("atm", 0.0), 0.0, 1.0) * 0.12
		audio.rumble = 0.0


# ------------------------------------------------------------------ HUD
func _fmt_dist(m: float) -> String:
	if m >= 10000.0:
		return "%.1f km" % (m / 1000.0)
	if m >= 1000.0:
		return "%.2f km" % (m / 1000.0)
	return "%d m" % int(m)


func _loc_texts() -> Array:
	var inf := uni.info
	var nearest: PlanetBody = inf.get("nearest", null)
	var pos := _actor_pos()
	var loc := "%s SYSTEM" % uni.system.name.to_upper()
	var sub := "Deep space"
	var tm := ""
	if nearest:
		var d := pos.distance_to(nearest.global_position)
		var alt := d - nearest.data.radius
		if alt < nearest.data.radius * 3.0 or mode == Mode.FOOT:
			var dd := nearest.data
			loc = dd.name.to_upper()
			sub = "%s  ·  gravity %.1f m/s²  ·  %d°C" % [Biomes.BIOME_NAMES[dd.biome] + (" moon" if dd.kind == "moon" else " world"), dd.gravity, int(dd.temp_c)]
			if dd.has_atmo and inf.get("atm", 0.0) > 0.02:
				var sh: float = inf.get("sun_h", 0.0)
				tm = "Local time: " + ("DAY" if sh > 0.25 else ("DUSK / DAWN" if sh > -0.1 else "NIGHT"))
			elif not dd.has_atmo:
				tm = "No atmosphere"
		else:
			sub = "Nearest: %s  (%s)" % [nearest.data.name, _fmt_dist(alt)]
	return [loc, sub, tm]


func _update_hud(dt: float) -> void:
	var lt := _loc_texts()
	var markers: Array = []
	var inv := "Units %d   ·   Power cells %d" % [units, player.power_cells]
	for k in player.inventory:
		inv += "   ·   %s %d" % [k, player.inventory[k]]
	var alert_title := ""
	var alert_sub := ""
	var alert_col := Color(1.0, 0.75, 0.25)
	alert_t += dt
	if mode == Mode.SHIP:
		var s := ship
		var hint := ""
		var alt_text := ""
		var near: PlanetBody = uni.info.get("nearest", null)
		if s.state == Ship.State.LANDED:
			hint = "[E] Exit ship    [Space] Take off    [V] View    [M] Map"
			alt_text = "LANDED  ·  %s" % s.planet.data.name
		else:
			if near:
				if s.altitude < near.data.radius * 1.5:
					alt_text = "ALT %s  ·  %s" % [_fmt_dist(maxf(s.altitude, 0.0)), near.data.name]
				else:
					alt_text = "%s from %s" % [_fmt_dist(maxf(s.altitude, 0.0)), near.data.name]
			if s.pulse:
				hint = "PULSE DRIVE  ·  [Space] disengage"
			elif near and s.altitude < near.data.radius * 0.25 and not near.is_gas:
				if s.altitude < 400.0:
					hint = "Slow down and descend to land  ·  [R/F] thrust up/down  ·  [Ctrl] brake"
				else:
					hint = "Atmosphere  ·  [Shift] boost  ·  descend to land"
			elif s.bh_dist > 0.0 and s.bh_dist < BlackHole.SHEAR_RANGE:
				hint = "[Shift] BOOST AWAY FROM THE BLACK HOLE"
			else:
				hint = "[W/S] throttle  ·  [Shift] boost  ·  [Space] pulse drive  ·  [M] map"
			if s.heat > 0.3:
				hint = "ATMOSPHERIC ENTRY  ·  reduce speed"
		hud.update_ship({
			"loc": lt[0], "sub": lt[1], "time": lt[2], "hull": s.hull, "shield": s.shield, "throttle": s.throttle,
			"boost": s.boosting, "pulse": s.pulse, "speed": s.speed, "alt_text": alt_text, "hint": hint, "inv": inv,
		})
		# black-hole warnings
		if uni.bh and s.bh_dist > 0.0 and s.state == Ship.State.FLYING:
			var d := s.bh_dist
			var g := BlackHole.time_dilation(d, uni.bh.rs)
			if d < BlackHole.WARN_RANGE:
				alert_col = Color(1.0, 0.75, 0.25)
				alert_title = "GRAVITATIONAL ANOMALY"
				alert_sub = "%s  ·  %s  ·  pull %.1f m/s²" % [uni.bh.bh_name, _fmt_dist(d), s.pull_g]
				if d < BlackHole.SHEAR_RANGE:
					alert_title = "TIDAL SHEAR - PULSE DRIVE OFFLINE"
					alert_col = Color(1.0, 0.55, 0.2)
				if d < BlackHole.PNR * 2.2:
					alert_title = "WARNING: POINT OF NO RETURN AHEAD"
					alert_col = Color(1.0, 0.3, 0.2)
				if s.in_pnr:
					alert_title = "POINT OF NO RETURN - ENGINES CANNOT ESCAPE"
					alert_col = Color(1.0, 0.15, 0.15)
				alert_sub += "  ·  time dilation x%.2f" % g
		elif uni.bh:
			pass
		hud.update_markers(_space_markers())
	else:
		var p := player
		var hint2 := ""
		if not p.interact_info.is_empty():
			hint2 = p.interact_info["text"]
		elif p.protection < 25.0 and p.planet.data.hazard.get("rate", 0.0) > 0.0 and not p.sheltered:
			hint2 = "Hazard protection low!  [R] use power cell  ·  return to your ship"
		elif p.sheltered:
			hint2 = "Sheltered - suit recharging"
		var alt_txt := ""
		if p.in_liquid:
			alt_txt = "WADING IN %s" % p.planet.data.liquid.to_upper()
		hud.update_foot({
			"loc": lt[0], "sub": lt[1], "time": lt[2], "health": p.health, "protection": p.protection, "jet": p.jet_fuel,
			"temp": p.planet.data.temp_c, "inv": inv, "hint": hint2, "mining": p.mining_progress, "alt_text": alt_txt,
		})
		hud.update_markers(_foot_markers())
	hud.set_alert(alert_title, alert_sub, alert_col, alert_t)


func _screen_marker(world: Vector3, text: String, sub: String, col: Color, shape: String = "diamond", edge: bool = false, s: float = 7.0) -> Dictionary:
	if camera.is_position_behind(world):
		return {}
	return {"p": camera.unproject_position(world), "text": text, "sub": sub, "col": col, "shape": shape, "edge": edge, "s": s}


func _space_markers() -> Array:
	var out: Array = []
	var pos := camera.global_position
	if ship.state == Ship.State.LANDED:
		return out
	for b in uni.bodies:
		var pb: PlanetBody = b
		var d := pos.distance_to(pb.global_position)
		if d < pb.data.radius * 2.2:
			continue
		var col: Color = GalaxyMap.BIOME_COL.get(pb.data.biome, Color.WHITE)
		var m := _screen_marker(pb.global_position, pb.data.name, "%s  ·  %s" % [Biomes.BIOME_NAMES[pb.data.biome], _fmt_dist(d - pb.data.radius)], col, "circle", false, 9.0)
		if not m.is_empty():
			out.append(m)
	if uni.star:
		var d2 := pos.distance_to(uni.star.global_position)
		var m2 := _screen_marker(uni.star.global_position, uni.system.name + " (star)", _fmt_dist(d2), Color(1.0, 0.9, 0.6), "ring", false, 12.0)
		if not m2.is_empty() and d2 > uni.star.radius * 2.0:
			out.append(m2)
	if uni.bh:
		var d3 := pos.distance_to(uni.bh.global_position)
		var m3 := _screen_marker(uni.bh.global_position, "BLACK HOLE  " + uni.bh.bh_name, _fmt_dist(d3), Color(1.0, 0.5, 0.2), "ring", false, 14.0)
		if not m3.is_empty() and d3 > uni.bh.rs * 3.0:
			out.append(m3)
	return out


func _foot_markers() -> Array:
	var out: Array = []
	var pl := player.planet
	if ship and ship.get_parent() == pl:
		var d := ship.global_position.distance_to(camera.global_position)
		var m := _screen_marker(ship.global_position + ship.global_basis.y * 6.0, "SHIP", _fmt_dist(d), Color(0.5, 1.0, 0.6), "tri", false, 7.0)
		if not m.is_empty():
			out.append(m)
	if pl.props and pl.props.site_node:
		var sp := pl.props.site_node.global_position + pl.props.site_node.global_basis.y * 14.0
		var d2 := sp.distance_to(camera.global_position)
		if d2 > 40.0:
			var m2 := _screen_marker(sp, "OUTPOST", _fmt_dist(d2), Color(0.6, 0.9, 1.0), "diamond")
			if not m2.is_empty():
				out.append(m2)
	var show_all := player.scan_timer > 0.0
	if pl.props:
		for n in pl.props.poi_nodes:
			if not is_instance_valid(n) or player.used_pois.has(n.get_instance_id()):
				continue
			var d3: float = n.global_position.distance_to(camera.global_position)
			var typ: String = n.get_meta("poi", "")
			if typ == "":
				continue
			if show_all or d3 < 120.0:
				var nm: String = {"monolith": "MONOLITH", "beacon": "BEACON", "supply": "SUPPLY CACHE"}[typ]
				var m3 := _screen_marker(n.global_position + n.global_basis.y * 5.0, nm, _fmt_dist(d3), Color(0.9, 0.75, 1.0), "diamond", show_all)
				if not m3.is_empty():
					out.append(m3)
		if show_all:
			var cpos := pl.to_local(camera.global_position)
			for r in pl.props.resources_near(cpos, 280.0):
				var wp := pl.to_global(r["pos"]) + pl.global_basis * ((r["pos"] as Vector3).normalized() * 1.2)
				var nm2: String = pl.data.resource_name if r["kind"] == "crystal" else pl.data.ore_name
				var m4 := _screen_marker(wp, nm2, _fmt_dist(wp.distance_to(camera.global_position)), pl.data.resource_color if r["kind"] == "crystal" else Color(1.0, 0.85, 0.4), "diamond", false, 5.0)
				if not m4.is_empty():
					out.append(m4)
	return out


# ------------------------------------------------------------------ gameplay events
func _on_landed(pl: PlanetBody) -> void:
	hud.show_message("LANDED on %s" % pl.data.name, 0)
	if not discovered.has(pl.data.name):
		discovered[pl.data.name] = true
		var bonus := 150 + pl.data.biome.length() * 10
		units += bonus
		hud.show_message("New world discovered: %s  (+%d units)" % [pl.data.name, bonus], 0)


func _on_interact(kind: String, node: Node) -> void:
	match kind:
		"ship":
			_enter_ship_mode()
			hud.show_message("Back aboard.", 0)
		"monolith":
			units += 250
			player.add_item(player.planet.data.resource_name, 2)
			hud.show_message("The monolith hums with ancient light... knowledge gained (+250 units)", 0)
			hud.hit_flash(Color(0.5, 0.8, 1.0), 0.35)
		"beacon":
			player.scan_timer = 90.0
			hud.show_message("Beacon activated: nearby points of interest revealed", 0)
		"supply":
			player.power_cells += 2
			units += 60
			hud.show_message("Supply cache opened: +2 power cells, +60 units", 0)


func _on_player_died() -> void:
	hud.show_message("Your suit failed. You wake up beside your ship.", 2)
	hud.hit_flash(Color(0, 0, 0), 1.0)
	var pl := player.planet
	var local := ship.position + ship.basis.x * 9.0
	player.spawn_at(pl, local.normalized() * (pl.data.radius + 10.0), -ship.basis.z)
	player.protection = 100.0
	player.health = 100.0


func _on_ship_destroyed() -> void:
	hud.show_message("SHIP DESTROYED - emergency recovery to the home outpost", 2)
	hud.hit_flash(Color(1, 0.4, 0.1), 1.0)
	ship.repair()
	trans = {}
	hud.fade = 0.0
	hud.tunnel = 0.0
	ship.warp_lock = false
	if current_id != 0:
		_switch_system(0, "home")
	var start: PlanetBody = uni.bodies[uni.system.start_planet]
	ship.place_on_pad(start)
	_enter_ship_mode()
	uni.set_origin_at_world(ship.global_position)


# ------------------------------------------------------------------ system change: warp + black hole
func _on_warp_requested(star_id: int) -> void:
	_close_map()
	var ok := _can_warp()
	if not ok[0]:
		hud.show_message(ok[1], 1)
		return
	trans = {"kind": "warp", "t": 0.0, "dest": star_id, "phase": 0}
	ship.warp_lock = true
	hud.show_message("HYPERDRIVE CHARGING - warping to %s" % galaxy.star(star_id)["name"], 0)


func _on_horizon_crossed() -> void:
	if not trans.is_empty() or uni.bh == null:
		return
	trans = {"kind": "blackhole", "t": 0.0, "dest": uni.bh.dest, "phase": 0}
	ship.warp_lock = true
	hud.show_message("EVENT HORIZON CROSSED", 2)
	visited_bh += 1


func _update_transition(dt: float) -> void:
	if trans.is_empty():
		return
	trans["t"] += dt
	var t: float = trans["t"]
	var kind: String = trans["kind"]
	if kind == "warp":
		if trans["phase"] == 0:
			hud.tunnel = clampf(t / 2.0, 0.0, 1.0)
			hud.fade_col = Color(0.85, 0.93, 1.0)
			hud.fade = clampf((t - 1.4) / 0.8, 0.0, 1.0)
			ship.velocity = ship.velocity.lerp(-ship.global_basis.z * 6000.0, 1.0 - exp(-2.0 * dt))
			if t >= 2.3:
				_switch_system(trans["dest"], "warp")
				trans["phase"] = 1
				trans["t"] = 0.0
		else:
			hud.fade = clampf(1.0 - t / 1.6, 0.0, 1.0)
			hud.tunnel = clampf(1.0 - t / 1.2, 0.0, 1.0)
			if t > 1.6:
				_finish_transition()
	else:
		if trans["phase"] == 0:
			# spaghettification: stretch, white-out
			hud.fade_col = Color(1.0, 0.97, 0.9)
			hud.tunnel = clampf(t / 2.0, 0.0, 1.0)
			hud.fade = clampf((t - 1.6) / 1.4, 0.0, 1.0)
			ship.shake = 1.5
			if uni.bh:
				var rel := uni.black_hole_rel(ship.global_position)
				ship.vg += BlackHole.pull_accel(rel) * dt
			if t >= 3.2:
				_switch_system(trans["dest"], "blackhole")
				trans["phase"] = 1
				trans["t"] = 0.0
		else:
			hud.fade = clampf(1.0 - t / 2.4, 0.0, 1.0)
			hud.tunnel = clampf(1.0 - t / 1.5, 0.0, 1.0)
			if t > 2.4:
				_finish_transition()


func _finish_transition() -> void:
	trans = {}
	hud.fade = 0.0
	hud.tunnel = 0.0
	ship.warp_lock = false


func _switch_system(id: int, how: String) -> void:
	# make sure the ship is not parented to something we are about to delete
	if ship.get_parent() != uni:
		var xf := ship.global_transform
		ship.get_parent().remove_child(ship)
		uni.add_child(ship)
		ship.global_transform = xf
	if player.get_parent() and player.get_parent() != uni:
		player.get_parent().remove_child(player)
	var sys := galaxy.get_system(id)
	uni.load_system(sys)
	current_id = id
	ship.state = Ship.State.FLYING
	ship.pulse = false
	ship.vg = Vector3.ZERO
	var up_u: Array
	match how:
		"blackhole":
			var bhp: Vector3 = sys.black_hole["pos"] if not sys.black_hole.is_empty() else Vector3(300000, 0, 0)
			var dirv := Vector3(0.6, 0.1, 0.8).normalized()
			var u := bhp + dirv * 230000.0
			up_u = [u.x, u.y, u.z]
			uni.origin = up_u
			uni.set_origin_at_world(Vector3.ZERO)
			ship.global_position = Vector3.ZERO
			ship.global_basis = Basis.looking_at(dirv, Vector3.UP)
			ship.velocity = dirv * 1400.0
			ship.throttle = 0.6
		"warp":
			var maxr := 100000.0
			for b in sys.bodies:
				if b.parent < 0:
					maxr = maxf(maxr, b.orbit_r)
			var dirv2 := Vector3(0.8, 0.1, -0.6).normalized()
			var u2 := dirv2 * (maxr * 0.9)
			up_u = [u2.x, u2.y, u2.z]
			uni.origin = up_u
			uni.set_origin_at_world(Vector3.ZERO)
			ship.global_position = Vector3.ZERO
			ship.global_basis = Basis.looking_at(-dirv2, Vector3.UP)
			ship.velocity = -dirv2 * 400.0
			ship.throttle = 0.5
		_:
			uni.origin = [0.0, 0.0, 0.0]
			uni.set_origin_at_world(Vector3.ZERO)
	uni.update_environment(Vector3.ZERO, 0.0)
	var msg := "Arrived in the %s system  (class %s star)" % [sys.name, sys.star_class]
	if how == "blackhole":
		msg = "You emerge from a black hole in the %s system - %d ly from home" % [sys.name, int(galaxy.distance_ly(0, id))]
	hud.show_message(msg, 0)
