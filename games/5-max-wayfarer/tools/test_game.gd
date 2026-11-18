extends Node
# Full game smoke test through the real main scene: menu -> start -> dive -> land -> exit -> scan -> walk -> time skip -> back -> take off.
var main: Node
var world: SpaceWorld
var pc: PlayerController

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	world = main.world
	pc = main.pc
	Game.message.connect(func(t: String, _s: float, k: String) -> void: print("MSG[%s] %s" % [k, t]))
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
	if DisplayServer.get_name() == "headless":
		print("SHOT skipped (headless) ", nm)
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://scratch/game/" + nm + ".png"))
	print("SHOT ", nm, " fps=", Engine.get_frames_per_second())

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await get_tree().process_frame

func _st(tag: String) -> void:
	var s: Ship = pc.ship
	print("[%s] t=%.0f frame=%d alt=%.0f spd=%.0f state=%d mode=%d heat=%.2f air=%.2f weather=%s/%.2f prot=%.0f" % [tag, world.time, world.frame_idx, world.altitude, s.velocity.length(), s.state, pc.mode, s.heat, world.air, main.weather.kind, main.weather.intensity, pc.protection])

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/game/"))
	await _wait(2.0)
	main._on_start_game()
	await _wait(3.0)
	var eden: BodyData = world.sys.find_body("Eden")
	var s: Ship = pc.ship
	pc.spawn_flying_near(eden.index, 8200.0)
	s.target_idx = eden.index
	await _wait(1.0)
	_st("spawned")
	var o: Dictionary = eden.outposts[0]
	var od: Vector3 = o["dir"]
	var target_pos: Vector3 = od * (eden.radius + float(o["flat_h"]) + 600.0)
	var guard := 0
	while world.frame_idx < 0 and guard < 60:
		var v: Vector3 = s.target_vector(eden.index).normalized()
		s.basis = Basis.looking_at(v, Vector3.UP)
		Input.action_press("thrust_fwd")
		await _wait(0.25)
		guard += 1
	_st("in_frame")
	guard = 0
	while world.altitude > 1400.0 and guard < 200 and world.frame_idx >= 0:
		var dir: Vector3 = (target_pos - s.position).normalized()
		s.basis = Basis.looking_at(dir, s.position.normalized())
		Input.action_press("thrust_fwd")
		Input.action_press("boost")
		await _wait(0.25)
		guard += 1
	await _shot("g1_dive")
	Input.action_release("boost")
	Input.action_release("thrust_fwd")
	await _wait(2.0)
	await tap("land_assist")
	guard = 0
	while s.state != Ship.State.LANDED and guard < 160:
		await _wait(0.5)
		guard += 1
	_st("landed")
	await _wait(1.0)
	await _shot("g2_landed")
	await tap("interact")
	await _wait(1.2)
	_st("exited")
	await _shot("g3_on_foot")
	await tap("scan")
	await _wait(1.0)
	await _shot("g4_scan")
	Input.action_press("move_fwd")
	Input.action_press("sprint")
	await _wait(3.0)
	Input.action_release("move_fwd")
	Input.action_release("sprint")
	await _shot("g5_walk")
	# time skip: watch the sun move
	Input.action_press("time_skip")
	await _wait(4.0)
	Input.action_release("time_skip")
	_st("time_skipped")
	await _shot("g6_after_skip")
	# weather check: force a storm phase for the screenshot
	main.weather.intensity = 1.0
	await _wait(2.0)
	await _shot("g7_weather")
	# back to the ship and take off
	pc.astro.global_position = s.hatch_world() + s.position.normalized() * 0.3
	await _wait(0.4)
	await tap("interact")
	await _wait(0.6)
	Input.action_press("thrust_up")
	await _wait(5.0)
	Input.action_release("thrust_up")
	_st("airborne")
	await _shot("g8_takeoff")
	print("GAME TEST DONE")
	get_tree().quit()
