extends Node
# Visual smoke test of the planet system. Run via tools/run_godot.ps1 (hidden desktop).
# args: --only=<comma list of shot names>   --wait=<seconds for terrain jobs>

var world: SpaceWorld
var actor: FlyActor
var out_dir: String = "res://scratch/shots/"
var only: Array = []
var max_wait: float = 8.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
		if a.begins_with("--wait="):
			max_wait = float(a.substr(7))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	world = SpaceWorld.new()
	add_child(world)
	var sys: SystemData = SystemGen.home_system()
	world.load_system(sys)
	actor = FlyActor.new()
	actor.world = world
	world.actor = actor
	world.cam_driver = actor
	_run()

func _wanted(n: String) -> bool:
	return only.is_empty() or only.has(n)

func _settle(planet_i: int) -> void:
	var t0: int = Time.get_ticks_msec()
	await get_tree().process_frame
	while float(Time.get_ticks_msec() - t0) / 1000.0 < max_wait:
		await get_tree().process_frame
		if planet_i >= 0:
			var p: Planet = world.planets[planet_i]
			if p.terrain != null and p.terrain.pending_jobs() == 0 and float(Time.get_ticks_msec() - t0) > 1500.0:
				break
		else:
			if float(Time.get_ticks_msec() - t0) > 1500.0:
				break
	for i in 4:
		await get_tree().process_frame

func _shot(shot_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(out_dir + shot_name + ".png")
	img.save_png(path)
	print("SHOT ", shot_name, " -> ", path, " fps=", Engine.get_frames_per_second())

func _orbit_shot(body_name: String, dist_factor: float, label: String) -> void:
	if not _wanted(label):
		return
	var b: BodyData = world.sys.find_body(body_name)
	var pk: D3 = world.body_pos(b.index, world.time)
	var to_star: Vector3 = (Vector3.ZERO - pk.to_v3()).normalized()
	var side: Vector3 = to_star.cross(Vector3.UP).normalized()
	var dir: Vector3 = (to_star * 0.55 + side * 0.8 + Vector3.UP * 0.15).normalized()
	var pos: D3 = pk.plus_v(dir * b.radius * dist_factor)
	actor.place_system(pos, pk)
	await _settle(b.index)
	await _shot(label)

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("TEST START bodies=", world.sys.bodies.size())
	if only.has("logic"):
		# headless friendly: exercise terrain generation + frames without taking screenshots
		var eden0: BodyData = world.sys.find_body("Eden")
		var pk0: D3 = world.body_pos(eden0.index, world.time)
		actor.place_system(pk0.plus_v(Vector3(0, 0, 1) * eden0.radius * 4.0), pk0)
		var t0: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 4000:
			await get_tree().process_frame
		var pe: Planet = world.planets[eden0.index]
		print("ORBIT chunks=", pe.terrain.chunks.size(), " ready=", pe.terrain.stat_ready, " visible=", pe.terrain.stat_visible, " pending=", pe.terrain.pending_jobs(), " frame=", world.frame_idx)
		var o0: Dictionary = eden0.outposts[0]
		var d0: Vector3 = o0["dir"]
		actor.place_planet(eden0.index, d0 * (eden0.radius + float(o0["flat_h"]) + 3.0), U.any_perp(d0))
		t0 = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 7000:
			await get_tree().process_frame
		print("SURFACE chunks=", pe.terrain.chunks.size(), " ready=", pe.terrain.stat_ready, " visible=", pe.terrain.stat_visible, " pending=", pe.terrain.pending_jobs(), " alt=", world.altitude, " air=", world.air, " maxlevel=", pe.gen.max_level)
		for k in world.sys.bodies.size():
			var bb: BodyData = world.sys.bodies[k]
			if bb.kind != "gas":
				var gg: TerrainGen = world.planets[k].gen
				print("BODY ", bb.name, " biome=", bb.biome, " R=", bb.radius, " H=", gg.H, " maxlvl=", gg.max_level, " g=", bb.gravity, " day=", int(bb.spin_period), " outposts=", bb.outposts.size())
		get_tree().quit()
		return
	# planets from orbit
	await _orbit_shot("Eden", 5.5, "eden_orbit")
	await _orbit_shot("Cinder", 5.5, "cinder_orbit")
	await _orbit_shot("Dune", 5.5, "dune_orbit")
	await _orbit_shot("Mire", 5.5, "mire_orbit")
	await _orbit_shot("Glacia", 5.5, "glacia_orbit")
	await _orbit_shot("Vesper", 5.5, "vesper_orbit")
	await _orbit_shot("Selene", 5.0, "selene_orbit")
	await _orbit_shot("Rime", 5.0, "rime_orbit")
	await _orbit_shot("Goliath", 3.2, "goliath_orbit")
	# star
	if _wanted("star"):
		var pos: D3 = D3.new(60000.0, 8000.0, 60000.0)
		actor.place_system(pos, D3.new(0, 0, 0))
		await _settle(-1)
		await _shot("star")
	# surface of Eden at the first outpost
	if _wanted("eden_surface") or _wanted("eden_surface2") or _wanted("eden_low"):
		var eden: BodyData = world.sys.find_body("Eden")
		var p: Planet = world.planets[eden.index]
		var o: Dictionary = eden.outposts[0]
		var dir: Vector3 = o["dir"]
		var base: Vector3 = dir * (eden.radius + float(o["flat_h"]))
		var east: Vector3 = U.any_perp(dir)
		var look: Vector3 = (east + dir * 0.05).normalized()
		actor.place_planet(eden.index, base + dir * 2.0 + east * -28.0, look)
		await _settle(eden.index)
		await _shot("eden_surface")
		actor.place_planet(eden.index, base + dir * 120.0 + east * -160.0, (east + dir * -0.25).normalized())
		await _settle(eden.index)
		await _shot("eden_low")
		world.time += 300.0
		actor.place_planet(eden.index, base + dir * 2.0 + east * -28.0, (east + dir * 0.35).normalized())
		await _settle(eden.index)
		await _shot("eden_surface2")
	print("TEST DONE")
	get_tree().quit()
