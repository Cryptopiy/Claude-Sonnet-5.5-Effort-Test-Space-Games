extends RefCounted
## prints LOD statistics of the anchored planet every second for N seconds. Use with --preset=freecam:<body>:<alt> --test=res://tests/terrain_stats.gd
func run(game: Node) -> void:
	for i in 14:
		await game.get_tree().create_timer(1.0).timeout
		var pl := Frame.anchor_node() as Planet
		if pl != null:
			print("[stats] t=", i + 1, " ", pl.debug_stats(), " fps=", Engine.get_frames_per_second())
