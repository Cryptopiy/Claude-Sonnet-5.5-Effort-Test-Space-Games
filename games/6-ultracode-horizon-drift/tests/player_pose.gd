extends RefCounted
## 3rd-person close-up poses of the astronaut:  --test=res://tests/player_pose.gd --preset=foot:1  -> .previews/pose_*.png

var g: Node

func _wait(s: float) -> void:
	await g.get_tree().create_timer(s).timeout

func _shot(name: String) -> void:
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	DebugCLI._save_shot(".previews/pose_%s.png" % name)

func run(game: Node) -> void:
	g = game
	var p: Player = Game.player
	await _wait(1.0)
	p.third_person = true
	p._apply_view_mode()
	for yaw in [PI * 0.85, PI * 0.5]:
		p.debug_orbit = Vector3(yaw, 0.9, 3.4)
		var tag := "f" if yaw > 2.0 else "s"
		await _wait(0.6)
		await _shot("idle_" + tag)
		Input.action_press("move_forward")
		await _wait(0.9)
		await _shot("walk_" + tag)
		await _wait(0.13)
		await _shot("walk2_" + tag)
		Input.action_press("sprint")
		await _wait(1.0)
		await _shot("run_" + tag)
		await _wait(0.1)
		await _shot("run2_" + tag)
		Input.action_release("sprint")
		Input.action_release("move_forward")
		await _wait(0.5)
		Input.action_press("fire")
		await _wait(0.6)
		await _shot("fire_" + tag)
		Input.action_release("fire")
		Input.action_press("move_down")
		await _wait(0.7)
		await _shot("crouch_" + tag)
		Input.action_release("move_down")
		await _wait(0.5)
		Input.action_press("move_up")
		await _wait(0.45)
		await _shot("jump_" + tag)
		await _wait(0.9)
		await _shot("jet_" + tag)
		Input.action_release("move_up")
		await _wait(4.0)
	print("[player_pose] done")
