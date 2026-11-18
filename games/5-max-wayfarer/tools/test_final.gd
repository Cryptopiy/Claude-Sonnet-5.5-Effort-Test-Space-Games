extends Node
# FINAL micro visual check - ONE short run at a tiny resolution (about 45 s). Start it only through the supervised, memory-capped runner:
#   powershell -File tools\guarded_run.ps1 -Scene res://tools/test_final.tscn -UserArgs "--parts=bh,station,wildlife" -Resolution 640x360 -MaxFps 12
# Shots: the black hole at three distances, the space station (far / near / docking bay), the wildlife of Eden and Mire.
# Under --headless the shots are skipped, so the same script doubles as a logic dry run.
var main: Node
var world: SpaceWorld
var pc: PlayerController
var parts: String = "bh,station,wildlife"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--parts="):
			parts = a.substr(8)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	world = main.world
	pc = main.pc
	Game.quality = 1                      # Medium: MSAA 2x, no SSAO - the lightest look that still shows everything
	Game.apply_settings()
	Game.message.connect(func(t: String, _s: float, k: String) -> void: print("MSG[%s] %s" % [k, t]))
	_run()

func _shot(nm: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT skipped (headless) ", nm)
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://scratch/final/" + nm + ".png"))
	print("SHOT ", nm)

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame

func _place_bh(dist: float, dirv: Vector3) -> void:
	var ship: Ship = pc.ship
	var bhp: D3 = world.bh_pos_sys()
	var dn: Vector3 = dirv.normalized()
	world.frame_idx = -1
	world.viewer_pos = Vector3.ZERO
	world.viewer_sys = bhp.plus_v(dn * dist)
	ship.velocity = Vector3.ZERO
	ship.basis = Basis.looking_at(-dn, Vector3.UP)
	ship.cam_basis = ship.basis
	ship.bh_control_loss = 0.0

## puts the flying ship at a planet-frame position, looking at another planet-frame point
func _fly_to(pidx: int, pos: Vector3, look_at_pos: Vector3) -> void:
	var ship: Ship = pc.ship
	world.frame_idx = pidx
	pc.mode = PlayerController.Mode.SHIP
	pc.astro.set_active(false)
	ship.set_pilot_inside(true)
	ship.state = Ship.State.FLYING
	ship._set_collider(false)
	ship.position = pos
	ship.velocity = Vector3.ZERO
	ship.basis = Basis.looking_at((look_at_pos - pos).normalized(), pos.normalized())
	ship.cam_basis = ship.basis
	ship.gear = 0.0
	ship.gear_target = 0.0
	world.viewer_pos = pos

func _part_bh() -> void:
	pc.ship.cam_mode = 0
	var dirv := Vector3(0.45, 0.10, 0.88)
	for pair in [[30000.0, "b1_far"], [9000.0, "b2_close"], [4200.0, "b3_pnr"]]:
		_place_bh(float(pair[0]), dirv)
		await _wait(1.8)
		await _shot(String(pair[1]))
		print("[", pair[1], "] bh_info=", world.bh_info)

func _part_station() -> void:
	world.bh_info = {}
	var eden: Planet = world.planets[2]
	if eden.props == null or eden.props.station_node == null:
		print("NO STATION on Eden")
		return
	var st: Node3D = eden.props.station_node
	var inv: Transform3D = eden.global_transform.affine_inverse()
	var sp: Vector3 = inv * st.global_position
	var out: Vector3 = sp.normalized()
	var side: Vector3 = U.any_perp(out)
	for sh in [[out * 1100.0 + side * 500.0, "s1_far"], [out * 380.0 + side * 260.0, "s2_near"]]:
		_fly_to(2, sp + (sh[0] as Vector3), sp)
		await _wait(2.2)
		await _shot(String(sh[1]))
	var dock: Node3D = eden.props.dock
	if dock != null:
		# the planet frame is active now: take a fresh inverse (the one above belongs to the system frame)
		var inv2: Transform3D = eden.global_transform.affine_inverse()
		var dp: Vector3 = inv2 * dock.global_position
		var dout: Vector3 = (inv2.basis * (-dock.global_transform.basis.z)).normalized()
		print("[dock] planet-frame position ", dp, " distance from the planet centre ", dp.length())
		_fly_to(2, dp + dout * 150.0, dp)
		await _wait(2.2)
		await _shot("s3_dock")
		_fly_to(2, dp + dout * 45.0 + dout.cross(dp.normalized()) * 20.0, dp)
		await _wait(1.8)
		await _shot("s4_dock_close")

func _wildlife(planet_idx: int, tag: String) -> void:
	world.time = 0.0
	pc.spawn_landed(planet_idx, 0, false)
	await _wait(10.0)
	var pl: Planet = world.planets[planet_idx]
	var apos: Vector3 = pc.astro.global_position
	var up: Vector3 = apos.normalized()
	var cf: Vector3 = -world.camera.global_transform.basis.z
	var fwd: Vector3 = (cf - up * cf.dot(up)).normalized()
	var right: Vector3 = fwd.cross(up).normalized()
	# model check: take one creature of each kind out of the manager (so it is no longer moved), pose it in front of the camera
	main.hud.visible = false
	var placed: Dictionary = {}
	var list: Array = main.fauna.creatures.duplicate()
	for c in list:
		if placed.has(c.kind):
			continue
		placed[c.kind] = true
		main.fauna.creatures.erase(c)
		var off: Vector3 = Vector3.ZERO
		var lift: float = 0.02
		var head: Vector3 = right
		match String(c.kind):
			"grazer":
				off = fwd * 6.5 - right * 3.2
				head = (right * 0.8 + fwd * 0.6).normalized()
			"crawler":
				off = fwd * 4.2 + right * 2.2
				head = (-right * 0.7 - fwd * 0.7).normalized()
			"floater":
				off = fwd * 10.0 + right * 0.5
				lift = 4.0
			"flyer":
				off = fwd * 8.0 + right * 0.5
				lift = 3.2
				head = (right * 0.9 + fwd * 0.4).normalized()
		var tdir: Vector3 = (apos + off).normalized()
		var ppos: Vector3 = tdir * (pl.data.radius + pl.ground_height(tdir) + lift)
		var pup: Vector3 = ppos.normalized()
		head = (head - pup * head.dot(pup)).normalized()
		c.transform = Transform3D(U.basis_from_up(pup, head), ppos)
	print("[wildlife %s] species posed: %s" % [tag, str(placed.keys())])
	await _wait(0.5)
	await _shot("w_%s_1" % tag)
	for c in main.fauna.get_children():
		if c is Node3D and not (c as Node3D).is_queued_for_deletion() and main.fauna.creatures.find(c) < 0:
			(c as Node3D).rotate(((c as Node3D).global_position).normalized(), 1.6)
	await _wait(0.5)
	await _shot("w_%s_2" % tag)
	main.hud.visible = true

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/final/"))
	await _wait(2.0)
	main._on_start_game()
	await _wait(2.0)
	if parts.contains("bh"):
		await _part_bh()
	if parts.contains("station"):
		await _part_station()
	if parts.contains("wildlife"):
		await _wildlife(2, "eden")
		await _wildlife(4, "mire")
	print("FINAL TEST DONE")
	get_tree().quit()
