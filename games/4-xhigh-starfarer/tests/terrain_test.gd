extends Node3D
## Visual test: one planet, camera at a given altitude. Args: --biome=N --alt=M --lat=deg --lon=deg --pitch=deg --shot=path --frames=N --seed=N

var args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1]
	var vp := Stealth.make_viewport(self, Vector2i(int(args.get("w", 1280)), int(args.get("h", 720))))
	var biome := int(args.get("biome", 0))
	var seed := int(args.get("seed", 5))
	var radius := float(args.get("radius", 5000.0))
	var d := Biomes.make(biome, seed, radius, "Test")
	var planet := Node3D.new()
	vp.add_child(planet)
	var terr := PlanetTerrain.new()
	planet.add_child(terr)
	var mat := PlanetMaterials.terrain(d)
	terr.setup(d, mat, null)

	var lat := deg_to_rad(float(args.get("lat", 20.0)))
	var lon := deg_to_rad(float(args.get("lon", 40.0)))
	var dir := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)).normalized()
	var alt := float(args.get("alt", 3.0))
	var ground := d.radius + d.height_at(dir)
	var cam_pos := dir * (ground + alt)
	var cam := Camera3D.new()
	cam.far = 2.0e6
	cam.near = 0.1
	cam.fov = float(args.get("fov", 75.0))
	vp.add_child(cam)
	var up := dir
	var east := up.cross(Vector3.UP).normalized()
	var north := east.cross(up).normalized()
	var pitch := deg_to_rad(float(args.get("pitch", 0.0)))
	var yaw := deg_to_rad(float(args.get("yaw", 0.0)))
	var fwd := (north * cos(yaw) + east * sin(yaw)) * cos(pitch) + up * sin(pitch)
	cam.global_transform = Transform3D(Basis.looking_at(fwd, up), cam_pos)
	if args.has("far"):
		cam.global_position = dir * (d.radius * float(args.far))
		cam.look_at(Vector3.ZERO, Vector3.UP)

	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	vp.add_child(sun)
	var sun_dir := Vector3(float(args.get("sx", 0.6)), float(args.get("sy", 0.5)), float(args.get("sz", 0.5))).normalized()
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.62, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.7, 0.9)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	terr.update_lod(cam.global_position, true)
	print("chunks: ", terr.leaves.size(), " max_level ", terr.max_level, " ground h ", d.height_at(dir))
	var frames := int(args.get("frames", 10))
	for i in frames:
		await get_tree().process_frame
	terr.update_lod(cam.global_position, true)
	for i in 6:
		await get_tree().process_frame
	if args.has("shot"):
		Stealth.shot(vp, args.shot)
		print("saved ", args.shot, " fps ", Engine.get_frames_per_second())
	get_tree().quit()
