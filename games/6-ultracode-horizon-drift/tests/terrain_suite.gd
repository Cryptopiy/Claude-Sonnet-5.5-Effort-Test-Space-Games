extends RefCounted
## One-process terrain verification suite (saves Godot start-ups = less GPU time):
##   --preset=freecam:<body>:20 --test=res://tests/terrain_suite.gd --log-tel=5 [--parts=seam,walk,descent] [--speed=450] [--walk-secs=14] [--alt0=100000]
## seam: height continuity around 3 great circles + flat POI sites;  walk: low flight along the ground (default 450 m/s, 25 m up) with hole checks;
## descent: radial dive from --alt0 to the surface with view-hole checks.   Everything prints PASS/FAIL lines.
func run(game: Node) -> void:
	var parts := "seam,walk,descent"
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--parts="):
			parts = s.substr(8)
	var list := parts.split(",", false)
	for p in list:
		match p:
			"seam":
				await (load("res://tests/terrain_seam.gd").new()).run(game)
			"walk":
				await (load("res://tests/terrain_walk.gd").new()).run(game)
			"descent":
				await (load("res://tests/terrain_descent.gd").new()).run(game)
		print("[suite] part done: ", p)
