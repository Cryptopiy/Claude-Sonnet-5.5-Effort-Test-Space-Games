extends Node
# End-to-end flow test (hidden desktop): fly -> auto-pulse -> atmosphere entry -> landing assist -> exit -> walk -> jet -> re-enter -> take off.
var world: SpaceWorld
var pc: PlayerController
var out_dir := "res://scratch/flow/"
var last_msg := ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	world = SpaceWorld.new()
	add_child(world)
	world.load_system(SystemGen.home_system())
	pc = PlayerController.new()
	pc.setup(world, world)
	Game.message.connect(func(t: String, secs: float, kind: String) -> void: print("MSG[%s] %s" % [kind, t]))
	_run()

func tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var ev2 := InputEventAction.new()
	ev2.action = action
	ev2.pressed = false
	Input.parse_input_event(ev2)

func _shot(nm: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(out_dir + nm + ".png"))
	print("SHOT ", nm)

func _status(tag: String) -> void:
	var s: Ship = pc.ship
	var apos: Vector3 = pc.astro.global_position if pc.mode == PlayerController.Mode.FOOT else Vector3.ZERO
	print("[%s] t=%.1f mode=%d frame=%d alt=%.0f speed=%.0f state=%d gear=%.2f pulse=%s heat=%.2f shield=%.0f prot=%.0f fps=%d astro_alt=%.1f" % [tag, world.time, pc.mode, world.frame_idx, world.altitude, s.velocity.length(), s.state, s.gear, str(s.pulse_on), s.heat, s.shield, pc.protection, Engine.get_frames_per_second(), apos.length() - 4300.0])

func _wait(sec: float, tag: String = "", every: float = 3.0) -> void:
	var t0 := Time.get_ticks_msec()
	var last := 0.0
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame
		var el := float(Time.get_ticks_msec() - t0) / 1000.0
		if tag != "" and el - last >= every:
			last = el
			_status(tag)

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var eden: BodyData = world.sys.find_body("Eden")
	var s: Ship = pc.ship
	pc.spawn_flying_near(eden.index, 70000.0)
	Game.in_game = true
	await _wait(1.0)
	_status("start")
	await _shot("01_space_start")
	# --- auto pulse to Eden, then keep thrusting across the frame boundary
	s.target_idx = eden.index
	await tap("auto_pulse")
	var guard := 0
	while world.frame_idx < 0 and guard < 160:
		if not s.pulse_on and s.speed_ref < 400.0:
			var v: Vector3 = s.target_vector(eden.index).normalized()
			s.basis = Basis.looking_at(v, Vector3.UP)
			Input.action_press("thrust_fwd")
		await _wait(0.25, "approach", 3.0)
		guard += 1
	Input.action_release("thrust_fwd")
	_status("entered_frame")
	await _shot("02_frame_entered")
	# --- dive toward the first outpost, boosting
	var o: Dictionary = eden.outposts[0]
	var od: Vector3 = o["dir"]
	var target_pos: Vector3 = od * (eden.radius + float(o["flat_h"]) + 700.0)
	guard = 0
	while world.altitude > 1600.0 and guard < 200 and world.frame_idx >= 0:
		var dir: Vector3 = (target_pos - s.position).normalized()
		s.basis = Basis.looking_at(dir, s.position.normalized())
		Input.action_press("thrust_fwd")
		Input.action_press("boost")
		await _wait(0.25, "descend", 2.0)
		guard += 1
	_status("below_1600")
	await _shot("03_entry")
	Input.action_release("boost")
	Input.action_release("thrust_fwd")
	await _wait(3.0, "slow", 1.5)
	await tap("land_assist")
	guard = 0
	while s.state != Ship.State.LANDED and guard < 120:
		await _wait(0.5, "landing", 2.0)
		guard += 1
	_status("landed")
	await _wait(1.5)
	await _shot("04_landed")
	# --- exit ship
	pc.exit_ship()
	await _wait(1.0)
	_status("on_foot")
	await _shot("05_exit")
	Input.action_press("move_fwd")
	Input.action_press("sprint")
	await _wait(2.5, "walk", 1.0)
	Input.action_press("jump")
	await _wait(2.5, "jet", 0.5)
	await _shot("06_jetpack")
	Input.action_release("jump")
	Input.action_release("move_fwd")
	Input.action_release("sprint")
	await _wait(2.5, "fall", 1.0)
	# --- back to ship
	pc.astro.global_position = pc.ship.hatch_world() + (pc.ship.position.normalized()) * 0.3
	await _wait(0.6)
	await tap("interact")
	await _wait(0.6)
	_status("reentered")
	Input.action_press("thrust_up")
	await _wait(4.0, "takeoff", 1.0)
	Input.action_release("thrust_up")
	await _shot("07_takeoff")
	Input.action_press("thrust_fwd")
	Input.action_press("boost")
	await _wait(10.0, "climb", 2.0)
	Input.action_release("thrust_fwd")
	Input.action_release("boost")
	_status("final")
	await _shot("08_final")
	print("FLOW DONE")
	get_tree().quit()
