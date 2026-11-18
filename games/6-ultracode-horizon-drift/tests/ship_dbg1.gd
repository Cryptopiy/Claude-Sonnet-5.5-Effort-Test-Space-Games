extends RefCounted
func run(game: Node) -> void:
	var ship: Ship = game.ship
	await game.get_tree().create_timer(1.5).timeout
	print("[dbg] anchor=", Frame.anchor, " near_idx=", ship._near_idx, " near_alt=", ship._near_alt, " reason='", ship._pulse_block_reason(), "' atmo=", ship.atmo_density, " locked=", ship.pulse_locked, " landed=", ship.is_landed, " piloted=", ship.piloted, " input=", Game.input_enabled(), " pos=", ship.global_position)
	for i in 4:
		Input.action_press("pulse_drive")
		await game.get_tree().process_frame
		print("[dbg] after press state=", ship.pulse_state, " reason='", ship._pulse_block_reason(), "'")
		Input.action_release("pulse_drive")
		await game.get_tree().process_frame
		print("[dbg] after release state=", ship.pulse_state)
