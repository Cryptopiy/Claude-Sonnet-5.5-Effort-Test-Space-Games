extends RefCounted
## Content audit (M7a, round 2): ONE run per body does everything (GPU friendly):
##   1. placement audit of every loaded scatter instance (floating / buried / underwater / on a POI / tilt vs the terrain normal)
##   2. determinism (rebuild cells with a fresh builder and compare the buffers)
##   3. ground-level + ship-height screenshots around the start pad   (--views=... optional, see below)
##   4. a short "walk" along the ground with the free camera: render cpu / gpu times, scatter stats
##   godot.ps1 -Project <sandbox> -Mode run -GodotArgs "--resolution 1280x720 -- --autostart --preset=landed:1 --freecam --sun=35 --test=res://tests/content_r2.gd --tag=r2 --walk=14"

func _args() -> Dictionary:
	var o: Dictionary = {"tag": "r2", "walk": "12", "views": "", "sun": "35"}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--") and s.contains("="):
			o[s.substr(2, s.find("=") - 2)] = s.substr(s.find("=") + 1)
	return o

func _cam(game: Node, planet: Node3D, dir: Vector3, alt: float, look_dir: Vector3, look_alt: float) -> void:
	var r0: float = planet.call("terrain_radius_at", dir)
	var r1: float = planet.call("terrain_radius_at", look_dir)
	var fc: Node3D = game.freecam
	fc.global_position = dir * (r0 + alt)
	fc.look_at(look_dir * (r1 + look_alt), dir)

func _shot(game: Node, name: String, tag: String, biome: String) -> void:
	var img := game.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://.previews/%s_%s_%s.png" % [tag, biome, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)

# ---------------------------------------------------------------------------------------------------------------------
func _audit(sm: ScatterManager, planet: Node3D, def: BodyDef) -> void:
	var R := def.radius
	var sea: Variant = planet.get("water_level")
	var has_sea: bool = sea != null and float(sea) > -1.0e8
	var sea_h: float = float(sea) if has_sea else -1.0e9
	var per: Dictionary = {}
	var total := 0
	var bad_float := 0
	var bad_bury := 0
	var bad_water := 0
	var bad_poi := 0
	var pois := PoiSites.for_body(def)
	for l in 3:
		for c in (sm._cells[l] as Dictionary).values():
			var cell: ScatterManager.Cell = c
			if cell.state != 2:
				continue
			for g in cell.groups:
				var id := String(g["id"])
				var xf: PackedFloat32Array = g["xf"]
				var n: int = g["n"]
				var rec: Dictionary = per.get(id, {"n": 0, "above_max": -1e9, "below_min": 1e9, "tilt_max": 0.0, "water": 0, "scale_min": 1e9, "scale_max": 0.0, "lift": false})
				var sp: Dictionary = {}
				for s in (sm._species[l] as Array):
					if String(s["id"]) == id:
						sp = s
						break
				var lifted := sp.has("lift")
				for i in n:
					var o := i * 16
					var pos := Vector3(xf[o + 3], xf[o + 7], xf[o + 11]) + cell.origin
					var by := Vector3(xf[o + 1], xf[o + 5], xf[o + 9])
					var sc := by.length()
					var d := pos.normalized()
					var ground: float = planet.call("terrain_radius_at", d)
					var delta := pos.length() - ground           # metres above the ground at the model origin
					var rel := delta / maxf(sc, 0.01)             # in model heights (sink shows as negative)
					rec["n"] += 1
					rec["above_max"] = maxf(rec["above_max"], delta if not lifted else 0.0)
					rec["below_min"] = minf(rec["below_min"], rel)
					rec["scale_min"] = minf(rec["scale_min"], sc)
					rec["scale_max"] = maxf(rec["scale_max"], sc)
					var tilt := rad_to_deg(acos(clampf((by / sc).dot(d), -1.0, 1.0)))
					rec["tilt_max"] = maxf(rec["tilt_max"], tilt)
					total += 1
					if not lifted and delta > 0.35:
						bad_float += 1
					if rel < -1.2:
						bad_bury += 1
					if has_sea and ground - R < sea_h - 0.05 and not (id in ["coral_rock_a", "reed_cluster_a"]):
						rec["water"] += 1
						bad_water += 1
					for p in pois:
						if d.dot(p["dir"]) > 0.9992:
							var gd := ScatterGrid.ground_dist(d, p["dir"], R)
							if gd < float(p["radius"]) * 0.6 and bool(p["flat"]) and not (sp.get("g", "") in ["ground", "flower"]):
								bad_poi += 1
								break
				per[id] = rec
	print("[audit] body=%s biome=%s variant=%s instances=%d  floating(>0.35m)=%d buried(>1.2 heights)=%d underwater=%d on_poi=%d" % [def.name, def.biome, sm._variant_name, total, bad_float, bad_bury, bad_water, bad_poi])
	var ids: Array = per.keys()
	ids.sort()
	for id in ids:
		var r: Dictionary = per[id]
		print("[audit]   %-24s n=%5d above_max=%5.2f m  sunk_min=%5.2f h  tilt_max=%4.1f deg  scale=%.2f..%.2f water=%d" % [id, r["n"], r["above_max"], r["below_min"], r["tilt_max"], r["scale_min"], r["scale_max"], r["water"]])

func _determinism(sm: ScatterManager) -> void:
	var same := 0
	var diff := 0
	var checked := 0
	for l in 3:
		var n := 0
		for c in (sm._cells[l] as Dictionary).values():
			var cell: ScatterManager.Cell = c
			if cell.state != 2 or n >= 3:
				continue
			n += 1
			var fresh := ScatterBuilder.new()
			fresh.setup(sm.planet, sm.def, sm._species, sm._noises, sm._pois)
			var res := fresh.build_cell(l, cell.key, RefCounted.new())
			var gs: Array = res.get("groups", [])
			var ok := gs.size() == cell.groups.size()
			if ok:
				for k in gs.size():
					if hash(gs[k]["xf"]) != hash(cell.groups[k]["xf"]):
						ok = false
			checked += 1
			if ok:
				same += 1
			else:
				diff += 1
	# PoiSites twice
	var a: Array = PoiSites.for_body(sm.def)
	PoiSites._cache.erase(sm.def.seed)
	var b: Array = PoiSites.for_body(sm.def)
	var poi_same := a.size() == b.size()
	for i in mini(a.size(), b.size()):
		if (a[i]["dir"] as Vector3).distance_to(b[i]["dir"]) > 1e-7 or a[i]["kind"] != b[i]["kind"]:
			poi_same = false
	print("[determinism] cells rebuilt identical=%d different=%d (of %d); PoiSites same=%s -> %s" % [same, diff, checked, str(poi_same), "PASS" if diff == 0 and poi_same else "FAIL"])

# ---------------------------------------------------------------------------------------------------------------------
func run(game: Node) -> void:
	var o := _args()
	var def: BodyDef = Frame.anchor_def()
	var planet: Node3D = Frame.anchor_node()
	var sm: ScatterManager = planet.get_node_or_null("ScatterManager")
	if sm == null or game.freecam == null:
		print("FAIL need ScatterManager + --freecam")
		return
	var R := def.radius
	var tag := String(o["tag"])
	var biome := def.biome
	var start := PoiSites.start_dir(def)
	Universe.time = Universe.time_for_sun_elevation(def.index, start, float(o["sun"]), Universe.START_TIME, true)
	var vp := game.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	# ---- ground views --------------------------------------------------------------------------------------------------------
	var startup := float(o.get("startup", "0"))
	if startup > 0.0:
		var ts := 0.0
		while ts < startup:
			await game.get_tree().create_timer(1.0).timeout
			ts += 1.0
			var sst: Dictionary = sm.stats()
			print("[startup] t=%.0f active=%s alt=%.1f inst=%d bodies=%d res=%d pois=%d pending=%d inflight=%d built=%d" % [ts, str(sst["active"]), sst["alt"], sst["instances"], sst["bodies"], sst["res_nodes"], sst["pois"], sst["pending"], sst["inflight"], sst["built"]])
	if String(o.get("noviews", "0")) == "1":
		print("PASS content_r2 (startup only)")
		return
	var views: Array = [
		# name, cam dir, cam alt, look dir, look alt, wait
		["g_pad", ScatterGrid.walk(start, 0.6 + PI, 26.0, R), 1.7, start, 3.0, 5.0],
		["g_out_a", ScatterGrid.walk(start, 0.6, 30.0, R), 1.7, ScatterGrid.walk(start, 0.6, 160.0, R), 4.0, 3.0],
		["g_out_b", ScatterGrid.walk(start, 2.4, 30.0, R), 1.7, ScatterGrid.walk(start, 2.4, 160.0, R), 4.0, 3.0],
		["g_out_c", ScatterGrid.walk(start, 4.2, 70.0, R), 1.7, ScatterGrid.walk(start, 4.2, 250.0, R), 5.0, 3.0],
		["air_150", ScatterGrid.walk(start, 3.9, 110.0, R), 150.0, start, 0.0, 3.5],
		["air_500", ScatterGrid.walk(start, 1.3, 520.0, R), 220.0, ScatterGrid.walk(start, 1.3 + PI, 400.0, R), 0.0, 5.0],
	]
	var vi := 0
	for v in views:
		_cam(game, planet, v[1], v[2], v[3], v[4])
		await game.get_tree().create_timer(float(v[5])).timeout
		vi += 1
		if vi == 3:
			_audit(sm, planet, def)
			_determinism(sm)
		_shot(game, String(v[0]), tag, biome)
		var st: Dictionary = sm.stats()
		print("[view] %-8s fps=%d draws=%d prims=%dk inst=%d bodies=%d res=%d pois=%d tris_k=%d pending=%d" % [v[0], Engine.get_frames_per_second(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
			st["instances"], st["bodies"], st["res_nodes"], st["pois"], st["tris_k"], st["pending"]])
	# ---- walking (free camera at eye height, 11 m/s) ----------------------------------------------------------------------
	var secs := float(o["walk"])
	if secs > 0.0:
		var dirn := ScatterGrid.walk(start, 1.1, 40.0, R)
		var walk_pos := dirn
		var heading := 1.1
		var t := 0.0
		var cpu_max := 0.0
		var cpu_sum := 0.0
		var gpu_max := 0.0
		var gpu_sum := 0.0
		var proc_max := 0.0
		var n := 0
		var built0: int = sm._stat_built
		var last_us := Time.get_ticks_usec()
		var hitches: Array = []
		var proc_list: Array = []
		var nframes := 0
		while t < secs:
			await game.get_tree().process_frame
			var now_us := Time.get_ticks_usec()
			var wall_ms := float(now_us - last_us) / 1000.0
			last_us = now_us
			nframes += 1
			if nframes > 5:
				proc_list.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			if wall_ms > 70.0 and nframes > 4:
				hitches.append("t=%.1f:%.0fms(pend=%d)" % [t, wall_ms, sm._pending.size()])
			var dt := clampf(1.0 / maxf(Engine.get_frames_per_second(), 10.0), 0.004, 0.1)
			t += dt
			walk_pos = ScatterGrid.walk(walk_pos, heading, 11.0 * dt, R)
			_cam(game, planet, walk_pos, 1.7, ScatterGrid.walk(walk_pos, heading, 30.0, R), 2.0)
			var cpu := RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
			var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
			var pr := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			cpu_max = maxf(cpu_max, cpu)
			gpu_max = maxf(gpu_max, gpu)
			proc_max = maxf(proc_max, pr)
			cpu_sum += cpu
			gpu_sum += gpu
			n += 1
		var st2: Dictionary = sm.stats()
		print("[walk] %.0f s, %.0f m: render cpu avg=%.2f max=%.2f ms | gpu avg=%.2f max=%.2f ms | script process max=%.2f ms | cells built=%d (avg build %.1f ms) inst=%d bodies=%d pending=%d" % [secs, secs * 11.0, cpu_sum / maxf(n, 1), cpu_max, gpu_sum / maxf(n, 1), gpu_max, proc_max, sm._stat_built - built0, st2["avg_build_ms"], st2["instances"], st2["bodies"], st2["pending"]])
		proc_list.sort()
		if proc_list.size() > 10:
			print("[walk] script process ms: p50=%.2f p95=%.2f p99=%.2f max=%.2f" % [proc_list[proc_list.size() / 2], proc_list[int(proc_list.size() * 0.95)], proc_list[int(proc_list.size() * 0.99)], proc_list[proc_list.size() - 1]])
		print("[walk] frames=%d hitches(>70ms wall at 30fps cap)=%d %s" % [nframes, hitches.size(), str(hitches.slice(0, 12))])
		_shot(game, "walk_end", tag, biome)
	# ---- resource nodes close up ---------------------------------------------------------------------------------------------
	if String(o.get("res", "1")) == "1":
		var seen: Dictionary = {}
		var fpos: Vector3 = (game.freecam as Node3D).global_position
		var nodes := game.get_tree().get_nodes_in_group("resource_node")
		nodes.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(fpos) < b.global_position.distance_squared_to(fpos))
		var shots := 0
		for nd in nodes:
			var rn := nd as ResourceNode
			if rn == null or seen.has(rn.res_id) or shots >= 3:
				continue
			seen[rn.res_id] = true
			var rd := rn.position.normalized()
			var cam_d := ScatterGrid.walk(rd, 0.7, 4.5, R)
			_cam(game, planet, cam_d, 1.5, rd, 0.5 * rn.node_scale)
			await game.get_tree().create_timer(1.8).timeout
			_shot(game, "res_" + rn.res_id, tag, biome)
			shots += 1
		var cnt: Dictionary = {}
		for nd in nodes:
			var rn2 := nd as ResourceNode
			if rn2 != null:
				cnt[rn2.res_id] = int(cnt.get(rn2.res_id, 0)) + 1
		print("[res] loaded nodes by type: ", cnt, " shots=", shots)
	print("PASS content_r2")
