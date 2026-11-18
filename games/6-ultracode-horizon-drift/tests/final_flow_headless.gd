extends RefCounted
## Headless (NO GPU) end-to-end logic test of the core loop. Run with:
##   & tools\godot.ps1 -Mode run -Headless -TimeoutSec 180 -Tag flow -GodotArgs "-- --autostart --preset=landed --test=res://tests/final_flow_headless.gd"
## Prints FLOW lines; every check prints PASS or FAIL.

var _fails := 0

func _check(name: String, ok: bool, detail: String = "") -> void:
	print("FLOW %s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		_fails += 1

func _wait(game: Node, s: float) -> void:
	await game.get_tree().create_timer(s).timeout

func run(game: Node) -> void:
	await _wait(game, 1.5)
	var sys := Universe.system
	_check("system loaded", sys != null and sys.name == "Aurelia" and sys.bodies.size() >= 8, "bodies=%d biomes=%s" % [sys.bodies.size(), str(sys.biome_set())])
	_check("start frame anchored on Verdant", Frame.anchor == 1, "anchor=%d" % Frame.anchor)
	_check("ship landed at start", bool(game.ship.is_landed), "state=%s" % str(game.tel.get("state")))
	# --- on foot
	game.exit_ship()
	await _wait(game, 1.0)
	_check("exit ship -> FOOT", game.mode == game.Mode.FOOT, "mode=%d" % game.mode)
	var p0: Vector3 = game.player.global_position
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(game, 3.0)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var p1: Vector3 = game.player.global_position
	var up := p1.normalized()
	var ground: float = Frame.anchor_node().terrain_radius_at(up)
	_check("player walked", p0.distance_to(p1) > 5.0, "moved %.1f m" % p0.distance_to(p1))
	_check("player on ground (sphere radial)", absf(p1.length() - ground) < 3.0, "height above ground %.2f m" % (p1.length() - ground))
	Input.action_press("move_up")
	await _wait(game, 0.6)
	Input.action_release("move_up")
	await _wait(game, 1.5)
	game.enter_ship()
	await _wait(game, 0.5)
	_check("enter ship -> SHIP", game.mode == game.Mode.SHIP, "mode=%d" % game.mode)
	# --- take off
	Input.action_press("move_up")
	await _wait(game, 6.0)
	Input.action_release("move_up")
	await _wait(game, 0.5)
	_check("take-off", not bool(game.ship.is_landed) and float(game.tel.get("altitude", 0.0)) > 20.0, "alt=%.1f state=%s" % [float(game.tel.get("altitude", 0.0)), str(game.tel.get("state"))])
	# --- space: teleport beyond Verdant's capture radius, expect frame switch to SPACE
	var bp := Universe.body_pos(1)
	var to_star := Vector3(-bp.x, -bp.y, -bp.z).normalized()
	game.place_ship_abs(bp.add_v3(to_star * 150000.0), -to_star)
	await _wait(game, 1.0)
	_check("space frame (floating origin)", Frame.anchor == -1 and game.ship.global_position.length() < 3000.0, "anchor=%d |ship|=%.0f" % [Frame.anchor, game.ship.global_position.length()])
	# fly toward the planet: capture must switch the frame to Verdant without a position pop
	var fwd: Vector3 = -game.ship.global_transform.basis.z
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var captured := false
	for i in 70:
		await _wait(game, 1.0)
		if Frame.anchor == 1:
			captured = true
			break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("capture into planet frame while flying in", captured, "anchor=%d speed=%.0f" % [Frame.anchor, float(game.tel.get("speed", 0.0))])
	# --- black hole: spawn at 40 km, let the pull take the ship, expect transition to system 1
	var off := Vector3(40000.0, 8000.0, 0.0)
	game.place_ship_abs(Universe.body_pos(Universe.system.black_hole_index).add_v3(off), -off.normalized())
	await _wait(game, 1.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	var warned := {}
	var arrived := false
	for i in 120:
		await _wait(game, 1.0)
		warned[int(game.tel.get("bh_level", 0))] = true
		if Universe.current_id == Universe.SECOND_ID and not game.warping:
			arrived = true
			break
	Input.action_release("move_forward")
	Input.action_release("sprint")
	_check("black-hole warnings escalate to point of no return", warned.has(2) and warned.has(3), "levels seen=%s" % str(warned.keys()))
	_check("black hole transports to system 1 (Kepler's Rest)", arrived, "current_id=%d warping=%s" % [Universe.current_id, str(game.warping)])
	if arrived:
		await _wait(game, 2.0)
		var s2 := Universe.system
		_check("destination system has >=5 bodies, >=4 landable, >=4 biomes", s2.bodies.size() >= 5 and s2.landable_bodies().size() >= 4 and s2.biome_set().size() >= 4, "%s: bodies=%d landable=%d biomes=%s" % [s2.name, s2.bodies.size(), s2.landable_bodies().size(), str(s2.biome_set())])
		var bh2 := Universe.body_pos(s2.black_hole_index)
		var d: float = Frame.to_abs(game.ship.global_position).distance_to(bh2)
		_check("arrived near the destination gate", d < 400000.0, "distance to gate %.0f km" % (d / 1000.0))
	# --- hyperdrive via galaxy map logic (not in atmosphere)
	game.warp_cells = 5
	await _wait(game, 1.0)
	var target_id: int = Universe.HOME_ID if Universe.current_id != Universe.HOME_ID else int(Universe.nearest_stars(Universe.HOME_ID, 1)[0].id)
	var why: String = game.try_hyperdrive(target_id)
	_check("hyperdrive accepted in space", why == "", "target=%d reason='%s'" % [target_id, why])
	await _wait(game, 9.0)
	_check("hyperdrive arrived at the target star", Universe.current_id == target_id and not game.warping, "current_id=%d warping=%s system=%s" % [Universe.current_id, str(game.warping), Universe.system.name])
	var s3 := Universe.system
	_check("arrival system also valid (>=5 bodies, >=4 landable, >=4 biomes)", s3.bodies.size() >= 5 and s3.landable_bodies().size() >= 4 and s3.biome_set().size() >= 4, "%s: bodies=%d landable=%d biomes=%s" % [s3.name, s3.bodies.size(), s3.landable_bodies().size(), str(s3.biome_set())])
	print("FLOW SUMMARY: %d failed checks" % _fails)
