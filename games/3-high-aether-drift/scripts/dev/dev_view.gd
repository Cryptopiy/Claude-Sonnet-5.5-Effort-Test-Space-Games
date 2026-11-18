extends Node3D
## Developer harness: places a free camera at scripted viewpoints around the home system and saves screenshots.
## usage: godot --path . scenes/dev_view.tscn -- ground:Verdance orbit:Pyrrhus:9000 star bh

var uni: Universe
var cam: Camera3D
var galaxy: Galaxy


func _ready() -> void:
	get_window().unfocusable = true
	galaxy = Galaxy.new()
	uni = Universe.new()
	add_child(uni)
	cam = Camera3D.new()
	cam.near = 0.2
	cam.far = 4.0e6
	cam.fov = 70.0
	add_child(cam)
	uni.load_system(galaxy.get_system(0))
	uni.update_environment(Vector3(0, 1, 0), 0.0)
	_run()


func body_of(n: String) -> PlanetBody:
	return uni.bodies[uni.system.body_index(n)]


func place_local(b: PlanetBody, local_pos: Vector3, look_local: Vector3) -> void:
	var xf := b.global_transform
	var pos_world := xf * local_pos
	uni.set_origin_at_world(pos_world)
	xf = b.global_transform
	cam.global_position = Vector3.ZERO
	var up := (xf.basis * local_pos.normalized()).normalized()
	var look_w := (xf.basis * look_local).normalized()
	if absf(look_w.dot(up)) > 0.98:
		up = Vector3.UP
	cam.look_at(look_w, up)
	cam.global_position = Vector3.ZERO


func shot(sname: String, wait_frames: int = 20) -> void:
	for i in wait_frames:
		await get_tree().process_frame
		uni.update_environment(cam.global_position, 0.016)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://.shots/%s.png" % sname)
	print("shot ", sname)


func _run() -> void:
	var tests := OS.get_cmdline_user_args()
	await get_tree().process_frame
	for t in tests:
		var parts: PackedStringArray = t.split(":")
		match parts[0]:
			"orbit":
				var b := body_of(parts[1])
				var alt := float(parts[2])
				var d := Vector3(0.2, 0.3, 1.0).normalized()
				place_local(b, d * (b.data.radius + alt), -d)
				await shot("orbit_" + parts[1], 40)
			"ground":
				var b := body_of(parts[1])
				if parts.size() > 3:
					uni.sim_time = float(parts[3])
					uni._update_orbits(0.0)
				var sd := b.data.site_dir
				var h := b.data.terrain.site_h
				var site := sd * (b.data.radius + h)
				var t1 := sd.cross(Vector3.UP if absf(sd.y) < 0.9 else Vector3.RIGHT).normalized()
				var fwd := t1.cross(sd).normalized() # +z of the site frame
				var yaw := float(parts[2]) if parts.size() > 2 else 0.0
				var pos := site + sd * 2.0 + fwd * (-12.0)
				var dir := (fwd + sd * 0.08).normalized().rotated(sd, yaw)
				place_local(b, pos, pos + dir * 100.0 - pos)
				await shot("ground_" + parts[1], 150)
			"air":
				var b := body_of(parts[1])
				var sd := b.data.site_dir
				var alt := float(parts[2])
				var site := sd * (b.data.radius + b.data.terrain.site_h + alt)
				var t1 := sd.cross(Vector3.UP if absf(sd.y) < 0.9 else Vector3.RIGHT).normalized()
				var fwd := t1.cross(sd).normalized()
				var pos := site + fwd * -300.0
				var dir := (fwd - sd * 0.25).normalized()
				place_local(b, pos, dir)
				await shot("air_" + parts[1], 150)
			"gas":
				var b := body_of("Titanus")
				var d := Vector3(0.3, 0.12, 1.0).normalized()
				place_local(b, d * (b.data.radius * 3.2), -d)
				await shot("gas", 40)
			"star":
				var b := body_of("Pyrrhus")
				var d := (Vector3.ZERO - b.global_position)
				place_local(b, b.to_local(b.global_position + Vector3(0, 0, 3000.0)) , b.to_local(Vector3.ZERO) - b.to_local(b.global_position + Vector3(0, 0, 3000.0)))
				await shot("star", 40)
			"bh":
				var dist := float(parts[1]) if parts.size() > 1 else 60000.0
				var bpos := uni.bh.global_position
				uni.set_origin_at_world(bpos + Vector3(1, 0.1, 0.4).normalized() * dist)
				cam.global_position = Vector3.ZERO
				cam.look_at(uni.bh.global_position, Vector3.UP)
				await shot("bh_%d" % int(dist), 40)
	get_tree().quit()
