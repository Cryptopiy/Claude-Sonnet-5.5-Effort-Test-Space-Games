extends RefCounted
## M4: first-person viewmodel framing variants (rendered run):  --preset=foot:1 --test=res://tests/player_vm.gd
## Optional args: --vm=<scale>,<x>,<y>,<z> (repeatable) additional variants; default list below.
var g: Node

func _wait(s: float) -> void:
	await g.get_tree().create_timer(s).timeout

func _shot(name: String) -> void:
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	DebugCLI._save_shot(".previews/vm_%s.png" % name)

func run(game: Node) -> void:
	g = game
	var p: Player = Game.player
	await _wait(5.0)
	p.debug_look(0.0, 0.42)
	var variants: Array = []
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--vm="):
			var f := String(a).substr(5).split(",")
			variants.append([float(f[0]), Vector3(float(f[1]), float(f[2]), float(f[3]))])
	if variants.is_empty():
		variants = [[0.66, Vector3(0.095, -0.05, -0.10)], [0.60, Vector3(0.10, -0.05, -0.08)]]
	var i := 0
	for v in variants:
		p.viewmodel.model.scale = Vector3.ONE * float(v[0])
		p.viewmodel.model.position = v[1]
		await _wait(0.5)
		await _shot("v%d_idle" % i)
		Input.action_press("fire")
		await _wait(0.5)
		await _shot("v%d_fire" % i)
		Input.action_release("fire")
		i += 1
	print("[vm] done")
