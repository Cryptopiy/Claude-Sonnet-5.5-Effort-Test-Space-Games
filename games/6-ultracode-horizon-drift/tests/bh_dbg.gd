extends RefCounted
## temporary debug: warp through the black hole and log the arrival velocity vector every few frames.

func run(game: Node) -> void:
	game.warp_to_system(1, "blackhole")
	while game.warping:
		await game.get_tree().process_frame
	var bhi := Universe.system.black_hole_index
	for i in 400:
		await game.get_tree().process_frame
		if i % 25 == 0:
			var s = game.ship
			var bh_local: Vector3 = Frame.to_local(Universe.body_pos(bhi))
			var to: Vector3 = (bh_local - s.global_position)
			var rad: Vector3 = to.normalized()
			var v: Vector3 = s.velocity
			print("[dbg] f=%d pos=%s bh=%s v=%s |v|=%.1f v_in=%.1f lat=%.1f dist=%.0f basis_fwd=%s anchor=%d ref_vel=%s assist=%.2f" % [i, str(s.global_position), str(bh_local), str(v), v.length(), v.dot(rad), (v - rad * v.dot(rad)).length(), to.length(), str(-s.global_transform.basis.z), Frame.anchor, str(s.get("_ref_vel")), float(s.get("_assist"))])
