class_name TestDriver
extends Node
## Scripted scenarios for automated testing (only active with --scn=...). Takes screenshots from the off-screen viewport.

var main: Node
var w: World


func setup(m: Node) -> void:
	main = m
	w = m.world
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name_: String) -> void:
	var path := "%s/%s.png" % [Game.args.get("out", "shots"), name_]
	var vp: SubViewport = main.vp
	if vp:
		vp.get_texture().get_image().save_png(path)
	else:
		get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _run() -> void:
	var scn: String = Game.args.scn
	Game.message.connect(func(t, k): print("   MSG[", k, "] ", t))
	await _frames(6)
	match scn:
		"ground": await _scn_ground()
		"orbit": await _scn_orbit()
		"menu": await _scn_menu()
		"flow": await _scn_flow()
		"foot": await _scn_foot()
		"bh": await _scn_bh()
		"jump": await _scn_jump()
		"biomes": await _scn_biomes()
		"mine": await _scn_mine()
		"space": await _scn_space()
		"ui": await _scn_ui()
		"extras": await _scn_extras()
		"perf": await _scn_perf()
		"entry": await _scn_entry()
		"jitter": await _scn_jitter()
		_: print("unknown scenario ", scn)
	get_tree().quit()


func _dump() -> void:
	print("cam pos ", w.cam.global_position, " fwd ", -w.cam.global_transform.basis.z, " fov ", w.cam.fov, " near ", w.cam.near, " far ", w.cam.far)
	print("ship pos ", w.ship.global_position, " frame ", w.ship.frame, " abs ", w.ship.abs_pos().to_v3())
	print("home pos ", w.home_planet.global_position, " radius ", w.home_planet.radius, " vis ", w.home_planet.visible, " chunks ", (w.home_planet as Planet).terrain.leaves.size())
	print("star pos ", w.star.global_position, " origin ", w.origin.to_v3())
	var vrid: RID = main.vp.get_viewport_rid() if main.vp else get_viewport().get_viewport_rid()
	print("objects in frame ", RenderingServer.viewport_get_render_info(vrid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME), " draw calls ", RenderingServer.viewport_get_render_info(vrid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	print("ship children ", w.ship.get_child_count(), " model ", w.ship.model, " body ", w.ship.body_node)
	print("sun energy ", w.sun.light_energy, " day ", w.day_factor, " atm ", w.atm_amount)


func _scn_menu() -> void:
	await _frames(40)
	_dump()
	_shot("menu")


func _scn_orbit() -> void:
	main._on_start(false)
	await _frames(60)
	_shot("orbit_chase")
	await _perf("orbit")


func _perf(tag: String, frames := 40) -> void:
	var vrid: RID = main.vp.get_viewport_rid() if main.vp else get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vrid, true)
	var t0 := Time.get_ticks_usec()
	await _frames(frames)
	var dt := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vrid)
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(vrid)
	print("PERF %s: frame %.1f ms (%.1f fps)  gpu %.1f ms  render-cpu %.1f ms  process %.1f ms  objects %d draws %d" % [tag, dt, 1000.0 / dt, gpu, cpu,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		RenderingServer.viewport_get_render_info(vrid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vrid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)])


func _scn_ground() -> void:
	main._on_start(true)
	await _frames(120)
	_shot("ground_foot3")
	await _perf("ground")
	w.cam_mode = World.CamMode.FOOT1
	w.player.pitch = 0.1
	await _frames(20)
	_shot("ground_foot1")


# ------------------------------------------------------------------ helpers for the flow test
func _until(cond: Callable, max_frames: int, tag: String) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	print("TIMEOUT waiting for: ", tag)
	return false


func _state(tag: String) -> void:
	var s := w.ship
	print("[%s] t=%.0f frame=%s alt=%.0f speed=%.0f landed=%s gear=%s heat=%.2f pulse=%.2f on_foot=%s hull=%.0f" % [tag, w.t, s.frame.display_name if s.frame else "SPACE",
		s.alt, s.speed, s.is_landed, s.gear_down, s.entry_heat, s.pulse_spool, w.on_foot, s.hull])


func _aim_ship_at(p: DV) -> void:
	var cur := w.ship.abs_pos()
	var d := Vector3(p.x - cur.x, p.y - cur.y, p.z - cur.z).normalized()
	if w.ship.frame == null:
		w.ship.basis_w = Basis.looking_at(d, Vector3.UP)
	else:
		var fr := w.ship.frame
		w.ship.lbasis = Basis.looking_at(fr.rot.transposed() * d, w.ship.lpos.normalized())


func _wait(sec: float, cond: Callable = Callable()) -> bool:
	var t0 := w.t
	while w.t - t0 < sec:
		if cond.is_valid() and cond.call():
			return true
		await get_tree().process_frame
	return cond.is_valid() and cond.call()


func _scn_flow() -> void:
	main._on_start(false)
	Engine.time_scale = 2.0
	var home := w.home_planet
	# ---- 1. start 60 km out, pulse-drive toward the planet
	var dirs := (home.apos.minus(w.ship.abs_pos())).normalized()
	var p := home.apos.plus(-dirs * (home.radius + 60000.0))
	w.ship.teleport_space(p, home.vel, Basis.looking_at(dirs, Vector3.UP))
	await _frames(5)
	w.test_input = {"pulse": true, "thr": 0.0}
	var shot_done := false
	var t0 := w.t
	while w.t - t0 < 40.0 and w.ship.frame == null and w.ship.alt > 5000.0:
		_aim_ship_at(home.apos)
		if not shot_done and w.ship.pulse_spool > 0.9:
			_shot("flow_1_pulse")
			shot_done = true
		await get_tree().process_frame
	_state("pulse end")
	w.test_input = {"thr": 1.0}
	# ---- 2. approach, entry and landing
	var land_dir: Vector3 = (home as Planet).landing_dir if (home as Planet).landing_dir != Vector3.UP else SystemGen.find_landing_site(home.data)
	t0 = w.t
	var n := 0
	while w.t - t0 < 240.0:
		var site_abs := home.local_to_abs(land_dir * (home.radius + home.data.height_at(land_dir) + 300.0))
		_aim_ship_at(site_abs)
		if w.ship.frame != null and w.ship.alt < 900.0 and not w.ship.gear_down:
			w.ship.set_gear(true)
			w.test_input = {}
		if w.ship.is_landed:
			break
		n += 1
		if n % 120 == 0:
			_state("descent")
		if w.ship.entry_heat > 0.25 and not FileAccess.file_exists("shots/flow_2_entry.png"):
			_shot("flow_2_entry")
		await get_tree().process_frame
	Engine.time_scale = 1.0
	_state("LANDED?")
	await _frames(60)
	_shot("flow_3_landed")
	await _part_foot()


func _scn_foot() -> void:
	main._on_start(true)
	await _frames(60)
	await _part_foot()


func _scn_bh() -> void:
	main._on_start(false)
	await _frames(30)
	await _bh_test()


func _part_foot() -> void:
	# ---- 3. exit, walk, jump, jetpack
	w.exit_ship()
	await _frames(30)
	print("on foot: ", w.on_foot, " player alt ", w.player.alt, " grounded ", w.player.grounded)
	w.test_input = {"move": Vector2(0, 1), "sprint": true}
	await _wait(2.5)
	print("sprinted: speed_h=%.1f grounded=%s" % [w.player.speed_h, w.player.grounded])
	_shot("flow_4_walk")
	w.test_input = {"move": Vector2(0, 1), "jump": true, "jump_pressed": true}
	await _frames(2)
	w.test_input = {"move": Vector2(0, 1), "jump": true}
	await _wait(1.6)
	print("jetpack: alt=%.1f fuel=%.1f grounded=%s" % [w.player.alt, w.player.fuel, w.player.grounded])
	_shot("flow_5_jetpack")
	w.test_input = {}
	await _wait(8.0, func(): return w.player.grounded)
	# ---- 4. walk back to the ship and board
	for i in 4000:
		if w.player.frame == w.ship.frame:
			var to := w.ship.lpos - w.player.lpos
			var up := w.player.lpos.normalized()
			var tf := to - up * to.dot(up)
			if tf.length() < 6.0:
				break
			w.player.fwd_dir = tf.normalized()
			w.test_input = {"move": Vector2(0, 1), "sprint": true}
		await get_tree().process_frame
	w.test_input = {}
	w.board_ship()
	print("boarded: on_foot=", w.on_foot)
	await _frames(10)
	# ---- 5. take off
	w.test_input = {"vert": 1.0}
	await _wait(4.0, func(): return not w.ship.is_landed)
	await _wait(5.0)
	_state("takeoff")
	_shot("flow_6_takeoff")
	w.ship.set_gear(false)
	Engine.time_scale = 2.0
	w.test_input = {"thr": 1.0, "boost": true}
	await _wait(120.0, func(): return w.ship.frame == null)
	_state("in space again")
	_shot("flow_7_space")
	Engine.time_scale = 1.0
	await _bh_test()


func _bh_test() -> void:
	var bh := w.bh
	if bh == null:
		print("NO BLACK HOLE in this system")
		return
	var star_dir := Vector3(bh.apos.x, bh.apos.y, bh.apos.z).normalized()
	# --- escape test: 30 km out, boost directly away => must get free
	var p := bh.apos.plus(star_dir * 30000.0)
	w.ship.teleport_space(p, Vector3.ZERO, Basis.looking_at(star_dir, Vector3.UP))
	w.ship.throttle = 1.0
	w.test_input = {"thr": 1.0, "boost": true}
	await _wait(25.0)
	print("ESCAPE TEST: dist after 25 s boosting away from 30 km: %.0f m (started 30000)" % w.bh_dist)
	# --- fall-in test
	p = bh.apos.plus(-star_dir * 60000.0 + Vector3(0, 3000, 0))
	w.ship.teleport_space(p, Vector3.ZERO, Basis.looking_at(star_dir, Vector3.UP))
	w.ship.throttle = 1.0
	w.test_input = {"thr": 1.0, "boost": true}
	Engine.time_scale = 3.0
	var last_zone := -1
	var t0 := w.t
	while w.t - t0 < 200.0:
		_aim_ship_at(bh.apos)
		if w.bh_zone != last_zone:
			last_zone = w.bh_zone
			print("BH zone ", w.bh_zone, " dist ", int(w.bh_dist), " speed ", int(w.ship.speed))
			_shot("flow_8_bh_zone%d" % w.bh_zone)
		if w.warp_active:
			break
		await get_tree().process_frame
	print("warp_active ", w.warp_active, " dist ", w.bh_dist)
	Engine.time_scale = 1.0
	await _wait(2.0)
	_shot("flow_9_transit")
	await _wait(3.5)
	_shot("flow_9b_transit")
	await _wait(30.0, func(): return not w.warp_active)
	await _wait(2.5)
	print("NEW SYSTEM: ", w.star_info.name, " class ", w.star_info.cls, " bodies ", w.bodies.size(), " bh ", w.bh != null)
	_shot("flow_10_new_system")
	_state("arrived")


func _scn_jump() -> void:
	main._on_start(false)
	await _frames(20)
	w.ship.teleport_space(DV.new(180000, 2000, -150000), Vector3.ZERO, Basis.looking_at(Vector3(-1, 0, 0.8), Vector3.UP))
	await _frames(40)
	main.open_map()
	await _frames(30)
	_shot("jump_map")
	var near: Array = Game.galaxy.nearest(w.star_info.pos, 6, w.star_info.id)
	var target: int = near[2][1]
	main.gmap.selected = target
	main.gmap.zoom = 0.012
	main.gmap._refresh_panel()
	await _frames(20)
	_shot("jump_map_selected")
	main.gmap.close()
	await _frames(5)
	print("JUMP -> ", Game.galaxy.stars[target].name)
	w.jump_to_star(target)
	await _wait(1.6)
	_shot("jump_tunnel")
	await _wait(30.0, func(): return not w.warp_active)
	await _wait(2.5)
	print("ARRIVED: ", w.star_info.name, " class ", w.star_info.cls, " bodies ", w.bodies.size())
	_shot("jump_arrived")
	for b in w.bodies:
		print("  body ", b.display_name, " ", (b as Planet).data.biome_name(), " R=", b.radius)


func _scn_biomes() -> void:
	main._on_start(true)
	await _wait(1.0)
	var only: String = Game.args.get("only", "")
	for b in w.bodies:
		if not b.is_landable():
			continue
		if only != "" and only != b.display_name:
			continue
		w.spawn_on_surface(b)
		Game.set_state(Game.State.PLAYING)
		w.test_input = {}
		w.player.pitch = 0.05
		await _wait(7.0)
		_shot("biome_%s_ground" % b.display_name)
		w.player.pitch = 0.45
		w.player.fwd_dir = w.player.fwd_dir.rotated(w.player.lpos.normalized(), 2.2)
		await _wait(1.0)
		_shot("biome_%s_ground2" % b.display_name)
		print("biome ", b.display_name, " ", b.data.biome_name(), " props cells t0=", w.props_mgr.cells[0].size(), " t1=", w.props_mgr.cells[1].size(), " res=", w.props_mgr.res_nodes.size(), " creatures=", w.props_mgr.creatures.size())
	for b in w.bodies:
		if only != "" and only != b.display_name:
			continue
		w.spawn_in_orbit(b, b.radius * 1.2 + 2000.0)
		Game.set_state(Game.State.PLAYING)
		await _wait(1.5)
		_shot("biome_%s_orbit" % b.display_name)


func _scn_mine() -> void:
	main._on_start(true)
	await _wait(8.0)
	var pm: PropManager = w.props_mgr
	print("resource nodes loaded: ", pm.res_nodes.size())
	# scanner
	Input.action_press("scan")
	await _frames(2)
	Input.action_release("scan")
	await _wait(1.0)
	_shot("mine_scan")
	if pm.res_nodes.is_empty():
		print("NO RESOURCES")
		return
	# walk to the nearest node and mine it
	var best: Dictionary = pm.res_nodes[0]
	for r in pm.res_nodes:
		if (r.pos as Vector3).distance_to(w.player.lpos) < (best.pos as Vector3).distance_to(w.player.lpos):
			best = r
	print("target ", best.type, " at ", (best.pos as Vector3).distance_to(w.player.lpos), " m")
	for i in 4000:
		var to: Vector3 = (best.pos as Vector3) - w.player.lpos
		var up := w.player.lpos.normalized()
		var tf := to - up * to.dot(up)
		if tf.length() < 9.0:
			break
		w.player.fwd_dir = tf.normalized()
		w.test_input = {"move": Vector2(0, 1), "sprint": true}
		await get_tree().process_frame
	w.test_input = {}
	# aim the camera at the node
	var to2: Vector3 = (best.pos as Vector3) + (best.pos as Vector3).normalized() * 0.8 - (w.player.lpos + w.player.lpos.normalized() * 1.55)
	var up2 := w.player.lpos.normalized()
	var flat := to2 - up2 * to2.dot(up2)
	w.player.fwd_dir = flat.normalized()
	w.player.pitch = atan2(to2.dot(up2), flat.length())
	await _frames(10)
	print("hint: ", pm.harvest_hint())
	Input.action_press("mine")
	await _wait(0.8)
	_shot("mine_beam")
	await _wait(2.0)
	Input.action_release("mine")
	print("inventory: ", Game.inventory)
	await _frames(20)
	_shot("mine_after")
	# interact with the nearest site
	if not pm.sites.is_empty():
		var s0: Dictionary = pm.sites[0]
		w.player.place_at(w.player.frame, (s0.dir as Vector3), Vector3.RIGHT)
		await _wait(2.0)
		print("site prompt: ", pm.harvest_hint())
		_shot("site_outpost")


func _scn_space() -> void:
	main._on_start(false)
	await _wait(1.0)
	# station
	var st: Station = w.stations[0]
	var look := Vector3(0, 0, 1)
	var p := st.apos.plus(Vector3(180, 70, 260))
	w.ship.teleport_space(p, st.vel, Basis.looking_at((st.apos.minus(p)).normalized(), Vector3.UP))
	await _wait(1.5)
	_shot("space_station")
	# belt
	var belt := w.belt
	var rock: Array = belt.rocks[10]
	var rpos: Vector3 = belt.rot * (rock[0] as Vector3)
	var bp := belt.apos.plus(rpos + Vector3(300, 120, 700))
	w.ship.teleport_space(bp, Vector3.ZERO, Basis.looking_at(-Vector3(300, 120, 700).normalized(), Vector3.UP))
	await _wait(1.5)
	_shot("space_belt")
	# fly into an asteroid: collision test
	var hull0 := w.ship.hull
	w.ship.throttle = 1.0
	w.test_input = {"thr": 1.0, "boost": true}
	var t0 := w.t
	while w.t - t0 < 6.0:
		var cur := w.ship.abs_pos()
		var tgt := belt.apos.plus(belt.rot * (rock[0] as Vector3))
		_aim_ship_at(tgt)
		await get_tree().process_frame
	print("asteroid collision: hull ", hull0, " -> ", w.ship.hull)
	w.test_input = {}
	# star close
	var sp := w.star.apos.plus(Vector3(w.star.radius * 3.0, 800, 0))
	w.ship.teleport_space(sp, Vector3.ZERO, Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP))
	await _wait(1.5)
	_shot("space_star")
	# gas giant ring
	var g := w.body_by_name("Goliath")
	var gp := g.apos.plus(Vector3(g.radius * 2.2, g.radius * 0.5, g.radius * 1.8))
	w.ship.teleport_space(gp, g.vel, Basis.looking_at((g.apos.minus(gp)).normalized(), Vector3.UP))
	await _wait(1.5)
	_shot("space_goliath")
	# black hole from afar
	var bh := w.bh
	var bp2 := bh.apos.plus(Vector3(-30000, 4000, 9000))
	w.ship.teleport_space(bp2, Vector3.ZERO, Basis.looking_at((bh.apos.minus(bp2)).normalized(), Vector3.UP))
	await _wait(1.5)
	_shot("space_bh_far")
	_perf("space")


func _scn_ui() -> void:
	await _wait(2.0)
	_shot("ui_menu")
	main.menus.show_controls(main.menus.main_panel)
	await _frames(10)
	_shot("ui_controls")
	main.menus.hide_controls()
	main.menus.show_settings(main.menus.main_panel)
	await _frames(10)
	_shot("ui_settings")
	main.menus.hide_settings()
	main._on_start(true)
	await _wait(5.0)
	Game.add_resource("Carbon", 5)
	Game.add_resource("Sodium", 3)
	main.hud.show_inventory = true
	await _frames(10)
	_shot("ui_inventory")
	main.hud.show_inventory = false
	main.pause()
	await _frames(10)
	_shot("ui_pause")
	main.menus.show_controls(main.menus.pause_panel)
	await _frames(10)
	_shot("ui_controls_pause")


func _face(dir_to: Vector3) -> void:
	var up := w.player.lpos.normalized()
	var flat := dir_to - up * dir_to.dot(up)
	if flat.length() > 0.01:
		w.player.fwd_dir = flat.normalized()


func _scn_extras() -> void:
	main._on_start(true)
	await _wait(3.0)
	var home := w.home_planet as Planet
	var d := home.data
	print("START elev=", w.env_info.get("elev"), " day=", w.day_factor, " atm=", w.atm_amount, " cam_alt=", w.cam_alt, " lamp=", w.player.lamp.visible)
	# a) lake shore: search for a shoreline close to the start
	var start_dir := home.landing_dir
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var shore := Vector3.ZERO
	var water_dir := Vector3.ZERO
	for i in 4000:
		var cand := (start_dir * d.radius + Vector3(rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500), rng.randf_range(-1500, 1500))).normalized()
		var h := d.height_at(cand)
		if h > d.sea_level + 1.5 and h < d.sea_level + 4.0:
			var e1 := (cand * d.radius + cand.cross(Vector3.UP).normalized() * 40.0).normalized()
			if d.height_at(e1) < d.sea_level - 2.0:
				shore = cand
				water_dir = e1
				break
	if shore != Vector3.ZERO:
		w.player.place_at(home, shore, Vector3.RIGHT)
		_face(water_dir * d.radius - shore * d.radius)
		w.player.pitch = 0.0
		await _wait(5.0)
		print("LAKE elev=", w.env_info.get("elev"), " day=", w.day_factor, " atm=", w.atm_amount, " cam_alt=", w.cam_alt, " lamp=", w.player.lamp.visible, " near=", w.nearest_planet.display_name)
		_shot("extra_lake")
		# wade in: drop the player into the lake
		w.player.place_at(home, water_dir, Vector3.RIGHT)
		await _wait(3.0)
		print("wading: swimming=", w.player.swimming, " depth=", w.player.liquid_depth)
		_shot("extra_swim")
	else:
		print("no shore found")
	# b) night with headlamp
	var off_dir := (start_dir * d.radius + start_dir.cross(Vector3.UP).normalized() * 16.0).normalized()
	w.player.place_at(home, off_dir, Vector3.RIGHT)
	w.t += d.spin_period * 0.5
	for b in w.bodies:
		b.update_state(w.t)
	await _wait(4.0)
	print("night elev ", w.env_info.get("elev"), " lamp ", w.player.lamp.visible)
	_shot("extra_night")
	# c) sunrise
	w.set_local_time(home, start_dir, 0.07)
	await _wait(4.0)
	_shot("extra_sunrise")
	# d) rain
	w.set_local_time(home, start_dir, 0.5)
	w.props_mgr.weather.level = 1.0
	w.props_mgr.weather.target_level = 1.0
	await _wait(0.5)
	w.props_mgr.weather.level = 1.0
	await _frames(30)
	_shot("extra_rain")
	# e) wildlife
	await _wait(12.0)
	var best: Creature = null
	for c in w.props_mgr.creatures:
		if (c as Creature).kind != "flyer":
			best = c
			break
	print("creatures: ", w.props_mgr.creatures.size(), " pick ", best.kind if best else "none")
	if best:
		var up := best.lpos.normalized()
		var side := up.cross(best.fwd).normalized()
		w.player.place_at(home, (best.lpos + side * 9.0).normalized(), Vector3.RIGHT)
		await _frames(3)
		_face(best.lpos - w.player.lpos)
		w.player.pitch = 0.0
		await _frames(30)
		_shot("extra_creature")
	# f) cockpit
	main._on_start(false)
	await _wait(1.0)
	w.cam_mode = World.CamMode.COCKPIT
	await _frames(30)
	_shot("extra_cockpit")


class FrameStats:
	var times: Array = []
	var worst := 0.0

	func add(dt: float) -> void:
		times.append(dt)
		worst = maxf(worst, dt)

	func report(tag: String) -> void:
		var t := times.duplicate()
		t.sort()
		var n := t.size()
		var sum := 0.0
		for x in t:
			sum += x
		print("FRAMES %s: n=%d avg=%.1f ms p50=%.1f p95=%.1f p99=%.1f max=%.1f ms  (%d spikes >33ms)" % [tag, n, sum / n * 1000.0, t[n / 2] * 1000.0, t[int(n * 0.95)] * 1000.0, t[int(n * 0.99)] * 1000.0, worst * 1000.0, t.filter(func(x): return x > 0.033).size()])


func _record(sec: float, tag: String) -> void:
	var fs := FrameStats.new()
	var t0 := w.t
	var last := Time.get_ticks_usec()
	while w.t - t0 < sec:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		fs.add(float(now - last) / 1.0e6)
		last = now
	fs.report(tag)


func _scn_perf() -> void:
	main._on_start(true)
	await _wait(6.0)
	await _record(5.0, "standing")
	w.test_input = {"move": Vector2(0, 1), "sprint": true}
	var home := w.home_planet
	# run in a straight line, turning every few seconds so new terrain/props keep streaming in
	var fs := FrameStats.new()
	var t0 := w.t
	var last := Time.get_ticks_usec()
	var nt := 0.0
	while w.t - t0 < 40.0:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		fs.add(float(now - last) / 1.0e6)
		last = now
		nt += 1.0
		if int(nt) % 500 == 0:
			w.player.fwd_dir = w.player.fwd_dir.rotated(w.player.lpos.normalized(), 0.6)
	fs.report("sprinting 40s (prop streaming)")
	w.test_input = {}
	# low flight over forest
	main._on_start(false)
	await _wait(1.0)
	var land_dir := (home as Planet).landing_dir
	w.ship.teleport_surface(home, land_dir, 120.0)
	w.ship.set_gear(false)
	w.ship.gear_t = 0.0
	w.ship.throttle = 0.7
	w.test_input = {"thr": 1.0, "boost": true}
	fs = FrameStats.new()
	t0 = w.t
	last = Time.get_ticks_usec()
	while w.t - t0 < 25.0:
		await get_tree().process_frame
		var now2 := Time.get_ticks_usec()
		fs.add(float(now2 - last) / 1.0e6)
		last = now2
		# hold ~120 m above ground
		var up := w.ship.lpos.normalized()
		if w.ship.frame != null and w.ship.alt < 100.0:
			w.ship.lbasis = w.ship.lbasis * Basis(Vector3.RIGHT, 0.02)
		elif w.ship.frame != null and w.ship.alt > 150.0:
			w.ship.lbasis = w.ship.lbasis * Basis(Vector3.RIGHT, -0.02)
	fs.report("low flight 25s")
	_shot("perf_lowflight")
	print("end state: alt=", w.ship.alt, " speed=", w.ship.speed, " cells=", w.props_mgr.cells[0].size(), "/", w.props_mgr.cells[1].size())


func _scn_entry() -> void:
	main._on_start(false)
	await _wait(1.0)
	var home := w.home_planet as Planet
	var dir := SystemGen.find_landing_site(home.data)
	w.ship.teleport_surface(home, dir, 3000.0)
	w.ship.lbasis = Basis.looking_at((-dir + Vector3(0.3, 0, 0)).normalized(), dir)
	w.ship.set_gear(false)
	w.ship.gear_t = 0.0
	w.ship.throttle = 1.0
	w.test_input = {"thr": 1.0, "boost": true}
	var shot := false
	var t0 := w.t
	while w.t - t0 < 20.0 and w.ship.alt > 500.0:
		await get_tree().process_frame
		if not shot and w.ship.entry_heat > 0.6:
			_shot("entry_heat")
			shot = true
	print("entry: heat=%.2f speed=%.0f alt=%.0f shot=%s" % [w.ship.entry_heat, w.ship.speed, w.ship.alt, shot])
	w.test_input = {}


func _scn_jitter() -> void:
	main._on_start(true)
	await _wait(6.0)
	# stand still on the rotating, orbiting planet: relative ship<->player vector and camera must be smooth
	var prev := w.ship.global_position - w.player.global_position
	var prev_d := Vector3.ZERO
	var max_acc := 0.0
	var max_cam := 0.0
	var cam_prev := w.cam.global_position - w.player.global_position
	var cam_prev_d := Vector3.ZERO
	for i in 600:
		await get_tree().process_frame
		var cur := w.ship.global_position - w.player.global_position
		var d := cur - prev
		max_acc = maxf(max_acc, (d - prev_d).length())
		prev_d = d
		prev = cur
		var cc := w.cam.global_position - w.player.global_position
		var cd := cc - cam_prev
		max_cam = maxf(max_cam, (cd - cam_prev_d).length())
		cam_prev_d = cd
		cam_prev = cc
	print("JITTER standing on orbiting+rotating planet: max 2nd-difference ship-player %.6f m, camera %.6f m (planet speed %.0f m/s)" % [max_acc, max_cam, (w.home_planet as Planet).vel.length()])
	# same at 5 m/s walking, far from the origin of the planet frame
	w.test_input = {"move": Vector2(0, 1)}
	await _wait(1.0)
	var p0 := w.cam.global_position
	var pp := p0
	var pd := Vector3.ZERO
	var max_w := 0.0
	for i in 400:
		await get_tree().process_frame
		var c := w.cam.global_position
		var d2 := c - pp
		max_w = maxf(max_w, (d2 - pd).length())
		pd = d2
		pp = c
	print("JITTER walking: max camera 2nd-difference %.6f m" % max_w)
