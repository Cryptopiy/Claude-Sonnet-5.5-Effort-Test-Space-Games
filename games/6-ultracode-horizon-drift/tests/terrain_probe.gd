extends SceneTree
## Height statistics + timing per biome (headless-safe). Run: godot.ps1 -Script res://tests/terrain_probe.gd

func _init() -> void:
	var biomes := ["lush", "desert", "frozen", "volcanic", "toxic", "barren", "ocean", "exotic", "swamp", "radioactive"]
	for b in biomes:
		var d := BodyDef.new()
		d.biome = b
		d.radius = 8000.0
		d.seed = 12345 + b.hash()
		d.palette_seed = 777 + b.hash()
		d.has_ocean = b in ["lush", "ocean", "swamp", "volcanic", "toxic"]
		var g := TerrainGen.new(d, [])
		var hs: Array = []
		var t0 := Time.get_ticks_usec()
		var n := 6000
		for i in n:
			var dir := SeedUtil.rand_dir(99, i)
			hs.append(g.height(dir))
		var t1 := Time.get_ticks_usec()
		var c0 := Time.get_ticks_usec()
		for i in 2000:
			g.color_at(SeedUtil.rand_dir(98, i), 10.0, 1.0)
		var c1 := Time.get_ticks_usec()
		hs.sort()
		var mean := 0.0
		for h in hs:
			mean += h
		mean /= n
		print("%-12s h: min %7.1f  p5 %7.1f  p25 %7.1f  p50 %7.1f p75 %7.1f p95 %7.1f max %7.1f mean %7.1f  | height %.1f us  color %.1f us" % [b, hs[0], hs[int(n * 0.05)], hs[int(n * 0.25)], hs[int(n * 0.5)], hs[int(n * 0.75)], hs[int(n * 0.95)], hs[n - 1], mean, float(t1 - t0) / n, float(c1 - c0) / 2000.0])
	# cellular noise range
	var nc := FastNoiseLite.new()
	nc.noise_type = FastNoiseLite.TYPE_CELLULAR
	nc.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	nc.frequency = 0.01
	var mn := 9.0
	var mx := -9.0
	var nv := FastNoiseLite.new()
	nv.noise_type = FastNoiseLite.TYPE_CELLULAR
	nv.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	nv.frequency = 0.01
	var vmn := 9.0
	var vmx := -9.0
	for i in 20000:
		var p := SeedUtil.rand_dir(5, i) * 5000.0
		var v := nc.get_noise_3d(p.x, p.y, p.z)
		mn = minf(mn, v)
		mx = maxf(mx, v)
		var w := nv.get_noise_3d(p.x, p.y, p.z)
		vmn = minf(vmn, w)
		vmx = maxf(vmx, w)
	print("cellular distance range ", mn, " .. ", mx, "  cell value range ", vmn, " .. ", vmx)
	var nr := FastNoiseLite.new()
	nr.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nr.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	nr.fractal_octaves = 5
	nr.frequency = 0.001
	var rmn := 9.0
	var rmx := -9.0
	var rs := 0.0
	var nf := FastNoiseLite.new()
	nf.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nf.fractal_type = FastNoiseLite.FRACTAL_FBM
	nf.fractal_octaves = 5
	nf.frequency = 0.001
	var fmn := 9.0
	var fmx := -9.0
	for i in 20000:
		var p2 := SeedUtil.rand_dir(6, i) * 5000.0
		var v2 := nr.get_noise_3d(p2.x, p2.y, p2.z)
		rmn = minf(rmn, v2)
		rmx = maxf(rmx, v2)
		rs += v2
		var v3 := nf.get_noise_3d(p2.x, p2.y, p2.z)
		fmn = minf(fmn, v3)
		fmx = maxf(fmx, v3)
	print("ridged range ", rmn, " .. ", rmx, " mean ", rs / 20000.0, "   fbm range ", fmn, " .. ", fmx)
	# mesher timing
	var d2 := BodyDef.new()
	d2.biome = "lush"
	d2.radius = 9000.0
	d2.seed = 4242
	d2.palette_seed = 99
	d2.has_ocean = true
	var g2 := TerrainGen.new(d2, [])
	var t2 := Time.get_ticks_usec()
	var res := TerrainMesher.build(g2, 0, 6, 10, 20, 100.0)
	var t3 := Time.get_ticks_usec()
	print("chunk build ms: ", float(t3 - t2) / 1000.0, "  mesh surfaces: ", (res["mesh"] as ArrayMesh).get_surface_count())
	var t4 := Time.get_ticks_usec()
	var cres := TerrainMesher.build_collision(g2, Vector3(0.3, 0.5, 0.8).normalized(), 60.0, 1.2)
	var t5 := Time.get_ticks_usec()
	print("collision build ms: ", float(t5 - t4) / 1000.0)
	quit()
