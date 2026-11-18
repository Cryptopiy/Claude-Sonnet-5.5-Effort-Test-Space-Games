extends RefCounted
## M4 debug: where is the muzzle / beam in camera space?  (headless ok)   --preset=foot:1 --test=res://tests/player_beamdbg.gd
var g: Node

func _wait(s: float) -> void:
	await g.get_tree().create_timer(s).timeout

func run(game: Node) -> void:
	g = game
	var p: Player = Game.player
	await _wait(1.5)
	var cam := p.cam
	var inv := cam.global_transform.affine_inverse()
	print("[bdbg] viewmodel node pos=", p.viewmodel.position, " model pos=", p.viewmodel.model.position, " scale=", p.viewmodel.model.scale)
	var mz := p.viewmodel.muzzle_global().origin
	print("[bdbg] muzzle in camera space: ", inv * mz, "  (muzzle found: ", p.viewmodel.muzzle != null, ")")
	Input.action_press("fire")
	await _wait(0.6)
	var b: MiningBeam = p.beam
	var bm: MeshInstance3D = b._beam
	print("[bdbg] beam visible=", b.visible, " amount=", b._amount, " beam xform in cam space: origin=", inv * bm.global_position, " y-axis(len)=", (inv.basis * bm.global_transform.basis.y), " x-axis=", inv.basis * bm.global_transform.basis.x)
	print("[bdbg] muzzle glow scale=", b._muzzle_glow.scale, " pos in cam=", inv * b._muzzle_glow.global_position)
	var sp1 := cam.unproject_position(mz)
	var sp2 := cam.unproject_position(bm.global_position + bm.global_transform.basis.y * 0.5)
	print("[bdbg] screen muzzle=", sp1, " beam end=", sp2, " viewport=", cam.get_viewport().get_visible_rect().size)
	Input.action_release("fire")
	print("[bdbg] done")
