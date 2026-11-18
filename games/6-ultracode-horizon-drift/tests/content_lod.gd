extends RefCounted
## Content LOD probe (M7a): background decimation of every scatter model (ScatterModels.request_lods / lod_variant).
func run(game: Node) -> void:
	var ids: Array = []
	for m in ModelLib.all_ids():
		var k := String(ModelLib.manifest(m).get("kind", ""))
		if k in ["flora", "rock", "resource"]:
			ids.append(m)
	ids.sort()
	var tasks: Array = []
	var t0 := Time.get_ticks_msec()
	for id in ids:
		var t := ScatterModels.request_lods(id, ModelLib.merged_mesh(id))
		if t >= 0:
			tasks.append(t)
	print("[lod] requested %d tasks in %d ms (main thread)" % [tasks.size(), Time.get_ticks_msec() - t0])
	for t in tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	print("[lod] all done after %d ms" % (Time.get_ticks_msec() - t0))
	var pal := {"leaf": [0.0, 1.0, 1.0], "glow": [0.0, 1.0, 1.0], "rock": [0.0, 1.0, 1.0]}
	for id in ids:
		var base := ScatterModels.tinted_mesh(id, pal)
		if base == null:
			continue
		var a := ScatterModels.total_tris(base)
		var l1 := ScatterModels.lod_variant(base, id, 1)
		var l2 := ScatterModels.lod_variant(base, id, 2)
		print("[lod] %-24s tris=%5d lod1=%5s lod2=%5s" % [id, a, str(ScatterModels.total_tris(l1)) if l1 != null else "-", str(ScatterModels.total_tris(l2)) if l2 != null else "-"])
