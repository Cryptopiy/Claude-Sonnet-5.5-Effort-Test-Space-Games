extends RefCounted
## Pure-CPU terrain consistency test (run it headless: godot.ps1 -Headless ... --preset=freecam:<body> --test=res://tests/terrain_seam.gd):
##  1. walks 3 full great circles (through cube-face edges / corners / both poles) in 1 m steps: reports the largest height jump between neighbouring samples
##     (a seam / discontinuity would show up as a jump >> the local slope) and the largest normal flip.
##  2. every flat POI site: height spread inside its flat radius, normal tilt at the centre, and clearance above the sea.
func run(game: Node) -> void:
	var body := Frame.anchor
	var pl := Frame.anchor_node() as Planet
	if pl == null:
		pl = Universe.body_nodes[Universe.system.start_body] as Planet
		body = pl.def.index
	var R := pl.radius
	var circ := TAU * R
	var step := 1.0
	var n := int(circ / step)
	var axes: Array = [
		[Vector3(1, 0, 0), Vector3(0, 1, 0)],                       # through two face centres and both poles
		[Vector3(1, 1, 0).normalized(), Vector3(0, 0, 1)],          # through cube edges
		[Vector3(1, 1, 1).normalized(), Vector3(1, -1, 0).normalized().cross(Vector3(1, 1, 1).normalized())],   # through cube corners
	]
	var worst_all := 0.0
	var worst_dn := 0.0
	var t_start := Time.get_ticks_msec()
	for ci in axes.size():
		var a: Vector3 = axes[ci][0]
		var b: Vector3 = (axes[ci][1] as Vector3)
		b = (b - a * a.dot(b)).normalized()
		var prev_h := pl.height_at(a)
		var prev_n := pl.normal_at(a)
		var worst := 0.0
		var worst_at := 0
		for i in range(1, n):
			var ang := TAU * float(i) / float(n)
			var d := a * cos(ang) + b * sin(ang)
			var h := pl.height_at(d)
			var jump := absf(h - prev_h)
			if jump > worst:
				worst = jump
				worst_at = i
			prev_h = h
			if i % 8 == 0:
				var nn := pl.normal_at(d)
				worst_dn = maxf(worst_dn, 1.0 - nn.dot(prev_n)) if i > 8 else worst_dn
				prev_n = nn
		print("[seam] circle ", ci, " samples=", n, " max |dh| per ", step, " m = ", worst, " at ", worst_at)
		worst_all = maxf(worst_all, worst)
	print("[seam] normals: worst 1-cos between samples 8 m apart = ", worst_dn, "   time_ms=", Time.get_ticks_msec() - t_start)
	var ok := worst_all < 4.0
	print("PASS" if ok else "FAIL", " terrain seam continuity (worst jump ", worst_all, " m)")
	# --- POIs
	var pois := pl.get_pois()
	var poi_fail := 0
	for st in pois:
		if not bool(st.get("flat", false)):
			continue
		var d0: Vector3 = (st["dir"] as Vector3).normalized()
		var r: float = float(st["radius"])
		var t1 := d0.cross(Vector3.UP if absf(d0.y) < 0.95 else Vector3.RIGHT).normalized()
		var t2 := d0.cross(t1)
		var hmin := 1.0e9
		var hmax := -1.0e9
		for ring in [0.0, 0.35, 0.7, 1.0]:
			for k in 12:
				var an := float(k) / 12.0 * TAU
				var q := (d0 * R + (t1 * cos(an) + t2 * sin(an)) * (r * ring)).normalized()
				var hq := pl.height_at(q)
				hmin = minf(hmin, hq)
				hmax = maxf(hmax, hq)
		var nrm := pl.normal_at(d0)
		var tilt := rad_to_deg(acos(clampf(nrm.dot(d0), -1.0, 1.0)))
		var clearance := (pl.height_at(d0) - pl.water_level) if pl.water_level > -1.0e8 else 999.0
		var good := (hmax - hmin) < 0.25 and tilt < 1.0 and clearance > 1.5
		if not good:
			poi_fail += 1
		print("[poi] ", st.get("kind", "?"), " ", st.get("name", ""), " r=", r, " height spread=", snappedf(hmax - hmin, 0.001), " m  centre tilt=", snappedf(tilt, 0.01), " deg  clearance over sea=", snappedf(clearance, 0.1), "  ", "OK" if good else "BAD")
	print("PASS" if poi_fail == 0 else "FAIL", " terrain flat POI sites (", pois.size(), " sites)")
