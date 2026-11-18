extends RefCounted
## Content test (M7a): PoiSites determinism, counts, spacing and flat-site budget for every landable body of the loaded system(s).

func run(game: Node) -> void:
	var ok := true
	for sid in [0, 1, 5, 17]:
		var sys := Universe.get_system(sid)
		for b in sys.bodies:
			if not b.landable:
				continue
			var a: Array = PoiSites.for_body(b)
			PoiSites._cache.erase(b.seed)
			var c: Array = PoiSites.for_body(b)
			var same := a.size() == c.size()
			for i in a.size():
				if not same:
					break
				if (a[i]["dir"] as Vector3).distance_to(c[i]["dir"]) > 1e-6 or a[i]["seed"] != c[i]["seed"] or a[i]["kind"] != c[i]["kind"]:
					same = false
			var flat := 0
			var kinds: Dictionary = {}
			var near_start := 0.0
			var min_sep := 1e9
			var start: Vector3 = a[0]["dir"]
			for i in a.size():
				var p: Dictionary = a[i]
				kinds[p["kind"]] = int(kinds.get(p["kind"], 0)) + 1
				if p["flat"]:
					flat += 1
				if i > 0 and p["kind"] == "outpost" and near_start == 0.0:
					near_start = ScatterGrid.ground_dist(start, p["dir"], b.radius)
				if p["flat"] and i > 0:
					for j in range(i):
						if a[j]["flat"]:
							var sep := ScatterGrid.ground_dist(a[j]["dir"], p["dir"], b.radius) - float(a[j]["radius"]) - float(p["radius"]) * 0.5
							min_sep = minf(min_sep, sep)
			print("[pois] sys=%d #%d %-14s %-9s R=%5.0f pois=%2d flat=%2d first_outpost=%4.0fm min_flat_gap=%5.0fm deterministic=%s kinds=%s" % [sid, b.index, b.name, b.biome, b.radius, a.size(), flat, near_start, min_sep, str(same), str(kinds)])
			if not same:
				ok = false
				print("FAIL non-deterministic PoiSites for ", b.name)
	print("PASS content_pois" if ok else "FAIL content_pois")
