extends RefCounted
## visual scenario for the on-foot player: screenshots into .previews/pv_*.png     --test=res://tests/player_visual.gd --preset=foot:1

class MockRes extends StaticBody3D:
	var hp := 6.0
	var taken := 0.0
	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		add_to_group("resource_node")
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.8
		cs.shape = sh
		add_child(cs)
		var mi := MeshInstance3D.new()
		var m := ModelLib.instantiate("res_ore_ferrite")
		add_child(m)
	func mine(dmg: float) -> Dictionary:
		taken += dmg
		var done := taken >= hp
		return {"destroyed": false, "resource": "ferrite", "amount": 7, "progress": clampf(taken / hp, 0.0, 1.0)}
	func get_label() -> String:
		return "Ferrite"

var g: Node

func _wait(s: float) -> void:
	await g.get_tree().create_timer(s).timeout

func _shot(name: String) -> void:
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	DebugCLI._save_shot(".previews/pv_%s.png" % name)

func run(game: Node) -> void:
	g = game
	var p: Player = Game.player
	await _wait(1.5)
	var planet := Frame.anchor_node() as Planet
	var fwd := -p.global_transform.basis.z
	var up := p.global_transform.basis.y
	var right := p.global_transform.basis.x
	var origin := p.global_position
	var nodes: Array = []
	for i in 3:
		var res := MockRes.new()
		Game.local_root.add_child(res)
		var pos := origin + fwd * (7.0 + 6.0 * i) + right * (float(i) - 1.0) * 3.0
		var d := pos.normalized()
		res.global_position = d * planet.terrain_radius_at(d)
		nodes.append(res)
	await _wait(0.5)
	await _shot("fp_idle")
	# scan
	Input.action_press("scan")
	await _wait(0.12)
	Input.action_release("scan")
	await _wait(0.25)
	await _shot("scan_a")
	await _wait(0.5)
	await _shot("scan_b")
	await _wait(2.5)
	await _shot("scan_markers")
	# aim at first resource and fire
	var first: Node3D = nodes[0]
	var to := (first.global_position + up * 0.5) - p.global_position
	var yaw_dir := (to - up * to.dot(up)).normalized()
	var cur := (fwd - up * fwd.dot(up)).normalized()
	var ang := cur.signed_angle_to(yaw_dir, up)
	p.debug_look(-ang, 0.0)
	await _wait(0.2)
	Input.action_press("fire")
	await _wait(0.6)
	await _shot("beam_a")
	await _wait(0.6)
	await _shot("beam_b")
	Input.action_release("fire")
	# third person
	Input.action_press("toggle_camera")
	await _wait(0.12)
	Input.action_release("toggle_camera")
	await _wait(0.6)
	await _shot("tp_idle")
	Input.action_press("fire")
	await _wait(0.5)
	await _shot("tp_beam")
	Input.action_release("fire")
	Input.action_press("move_forward")
	await _wait(0.7)
	await _shot("tp_walk")
	Input.action_press("sprint")
	await _wait(0.8)
	await _shot("tp_sprint")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	Input.action_press("move_up")
	await _wait(1.4)
	await _shot("tp_jet")
	await _wait(0.8)
	await _shot("tp_jet2")
	Input.action_release("move_up")
	await _wait(5.0)
	Input.action_press("move_down")
	await _wait(0.8)
	await _shot("tp_crouch")
	Input.action_release("move_down")
	print("[player_visual] done")
