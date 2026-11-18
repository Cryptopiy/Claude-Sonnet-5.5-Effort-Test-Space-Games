extends RefCounted
## Headless (NO GPU) feature sweep: exercises the gameplay paths that the flow test does not (overlays, pause, cameras, gear, crash, scanner, mining,
## interaction, death/respawn, gas-giant barrier, restart). The point is "no SCRIPT ERROR anywhere"; check the log for SCRIPT ERROR / Parse Error afterwards:
##   & tools\godot.ps1 -Mode run -Headless -TimeoutSec 240 -Tag feat -GodotArgs "-- --autostart --preset=landed --test=res://tests/final_features_headless.gd"

var _fails := 0

func _check(name: String, ok: bool, detail: String = "") -> void:
	print("FEAT %s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		_fails += 1

func _wait(game: Node, s: float) -> void:
	await game.get_tree().create_timer(s).timeout

func _tap(game: Node, action: String, hold: float = 0.15) -> void:
	Input.action_press(action)
	await _wait(game, hold)
	Input.action_release(action)
	await _wait(game, 0.15)

func _nearest(game: Node, group: String) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for n in game.get_tree().get_nodes_in_group(group):
		var n3 := n as Node3D
		if n3 == null or not n3.is_inside_tree():
			continue
		var d := n3.global_position.distance_to(game.player.global_position)
		if d < bd:
			bd = d
			best = n3
	return best

func run(game: Node) -> void:
	await _wait(game, 2.0)
	# ---- overlays / pause / settings -------------------------------------------------------------------------------------
	for kind in ["map", "system", "inventory", "controls"]:
		game.toggle_overlay(kind)
		await _wait(game, 0.5)
		_check("overlay %s opens" % kind, game.overlay_open)
		game.close_overlays()
		await _wait(game, 0.3)
		_check("overlay %s closes" % kind, not game.overlay_open)
	game.toggle_pause()
	await _wait(game, 0.5)
	_check("pause", game.state == game.State.PAUSED and game.get_tree().paused)
	game.resume()
	await _wait(game, 0.3)
	_check("resume", game.state == game.State.PLAYING and not game.get_tree().paused)
	game.settings["fov"] = 90.0
	game.settings["invert_y"] = true
	await _wait(game, 0.4)
	game.settings["fov"] = 78.0
	game.settings["invert_y"] = false
	# ---- ship controls on the ground -------------------------------------------------------------------------------------
	await _tap(game, "toggle_camera")
	await _wait(game, 0.5)
	await _tap(game, "toggle_camera")
	await _tap(game, "landing_gear")
	await _tap(game, "landing_gear")
	await _tap(game, "nav_next")
	await _tap(game, "scan")
	await _tap(game, "toggle_light")
	_check("ship controls (camera, gear, nav, scan, light) ran", true)
	# ---- take off, fly with every axis, crash into the ground -------------------------------------------------------------------
	Input.action_press("move_up")
	await _wait(game, 5.0)
	Input.action_release("move_up")
	for a in ["move_forward", "move_back", "move_left", "move_right", "roll_left", "roll_right", "move_down", "sprint"]:
		Input.action_press(a)
		await _wait(game, 0.5)
		Input.action_release(a)
	var hull0: float = game.ship_hull
	var sdir := PoiSites.start_dir(Universe.system.bodies[1])
	Frame.set_body_frame(1)
	game.ship.call("place_flying", sdir, 90.0, 0.0)
	await _wait(game, 0.5)
	Input.action_press("move_down")
	Input.action_press("sprint")
	var crashed := false
	for i in 12:
		await _wait(game, 0.5)
		if game.ship_hull < hull0 - 0.001 or game.ship.is_landed:
			crashed = true
			break
	Input.action_release("move_down")
	Input.action_release("sprint")
	await _wait(game, 1.5)
	_check("dive into the ground: ship survives, lands or takes damage", is_instance_valid(game.ship) and (game.ship.is_landed or game.ship_hull < hull0), "hull %.2f -> %.2f landed=%s vspeed=%s" % [hull0, game.ship_hull, str(game.ship.is_landed), str(game.tel.get("vspeed"))])
	# ---- gas-giant pressure barrier -----------------------------------------------------------------------------------------
	var gp := Universe.body_pos(5)
	var gdef: BodyDef = Universe.system.bodies[5]
	game.place_ship_abs(gp.add_v3(Vector3(gdef.radius * 1.5, 0, 0)), Vector3.LEFT)
	game.ship.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(game, 12.0)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var gd: float = Frame.to_abs(game.ship.global_position).distance_to(Universe.body_pos(5))
	_check("gas giant barrier keeps the ship out of the core", gd > gdef.radius * 0.5, "distance to centre %.0f m (R=%.0f)" % [gd, gdef.radius])
	# ---- back to the surface, on foot ---------------------------------------------------------------------------------------------
	game.place_ship_abs(Universe.body_pos(1).add_v3(Vector3(0, 0, 0)), Vector3.LEFT)   # just to leave the gas giant frame
	var b: BodyDef = Universe.system.bodies[1]
	Universe.time = Universe.time_for_sun_elevation(1, PoiSites.start_dir(b), 20.0, Universe.time, true)
	Frame.set_body_frame(1)
	game.ship.call("place_landed", PoiSites.start_dir(b), 0.0)
	await _wait(game, 3.0)
	game.exit_ship()
	await _wait(game, 1.5)
	_check("on foot again", game.mode == game.Mode.FOOT)
	await _tap(game, "toggle_camera")
	await _wait(game, 0.8)
	await _tap(game, "toggle_camera")
	await _tap(game, "toggle_light")
	await _tap(game, "toggle_light")
	Input.action_press("crouch") if InputMap.has_action("crouch") else null
	Input.action_press("move_down")
	await _wait(game, 0.5)
	Input.action_release("move_down")
	await _tap(game, "move_up")
	Input.action_press("move_up")
	Input.action_press("move_forward")
	await _wait(game, 2.5)
	Input.action_release("move_up")
	Input.action_release("move_forward")
	await _wait(game, 1.5)
	await _tap(game, "scan")
	await _wait(game, 2.0)
	var markers: Array = game.player.get("scan_markers")
	_check("scanner produced markers or ran cleanly", markers != null, "markers=%d" % markers.size())
	# ---- interaction + mining (teleport next to the closest nodes) ------------------------------------------------------------------
	var planet := Frame.anchor_node() as Planet
	var inter := _nearest(game, "interactable")
	_check("interactables exist near the start", inter != null, "closest=%s" % (str(inter.name) if inter else "none"))
	if inter != null:
		var dir := inter.global_position.normalized()
		var pos := dir * planet.terrain_radius_at(dir)
		var tang := dir.cross(Vector3.UP).normalized()
		game.player.call("spawn_at", pos + tang * 3.0, dir, -tang)
		await _wait(game, 1.5)
		await _tap(game, "interact")
		await _wait(game, 1.0)
		_check("interact ran", true, "prompt=%s" % str(inter.call("get_prompt")) if inter.has_method("get_prompt") else "")
	if game.mode == game.Mode.SHIP:
		print("FEAT INFO interact near the ship put the player back in the ship (expected): exiting again")
		game.exit_ship(true)
		await _wait(game, 1.5)
	var res := _nearest(game, "resource_node")
	if res != null:
		var res_name := str(res.name)
		var rdir := res.global_position.normalized()
		var rpos := rdir * planet.terrain_radius_at(rdir)
		var rt := rdir.cross(Vector3.UP).normalized()
		game.player.call("spawn_at", rpos + rt * 3.5, rdir, -rt)
		await _wait(game, 1.5)
		var inv0 := 0
		for k in game.inventory:
			inv0 += int(game.inventory[k])
		game.player.call("debug_look", 0.0, 0.42)
		await _wait(game, 0.3)
		Input.action_press("fire")
		await _wait(game, 6.0)
		Input.action_release("fire")
		var inv1 := 0
		for k in game.inventory:
			inv1 += int(game.inventory[k])
		print("FEAT INFO mining: inventory %d -> %d (node %s, still loaded: %s)" % [inv0, inv1, res_name, str(is_instance_valid(res))])
	else:
		print("FEAT INFO no resource node within the loaded cells")
	# ---- death + respawn -----------------------------------------------------------------------------------------------------------------
	if game.mode == game.Mode.SHIP:
		game.exit_ship(true)
		await _wait(game, 1.5)
	print("FEAT INFO before death: mode=%d dead=%s health=%.2f" % [game.mode, str(game.player.vitals.dead), game.player.vitals.health])
	game.player.vitals.damage(5.0)
	await _wait(game, 2.5)
	print("FEAT INFO after death: mode=%d dead=%s health=%.2f dist_to_ship=%.1f" % [game.mode, str(game.player.vitals.dead), game.player.vitals.health, game.ship_distance_to_player()])
	_check("death -> emergency respawn beside the ship, alive, on foot", is_instance_valid(game.player) and game.mode == game.Mode.FOOT and game.player.vitals.health > 0.2 and game.ship_distance_to_player() < 30.0)
	game.enter_ship()
	await _wait(game, 0.5)
	# ---- restart: back to menu and a fresh game --------------------------------------------------------------------------------------------
	await game.quit_to_menu()
	await _wait(game, 1.0)
	_check("back in menu", game.state == game.State.MENU and game.ship == null)
	await game.start_game({"preset": "landed"})
	await _wait(game, 3.0)
	_check("fresh game after restart", game.state == game.State.PLAYING and game.ship != null and Frame.anchor == 1)
	print("FEAT SUMMARY: %d failed checks" % _fails)
