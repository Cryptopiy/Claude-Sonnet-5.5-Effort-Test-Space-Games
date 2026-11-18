extends SceneTree
# Minimal check that off-screen / hidden windows still render and that viewport screenshots work.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := "res://scratch/shot_test.png"
	var wait_s := 0.0
	for a in args:
		if a.begins_with("--out="):
			out_path = a.substr(6)
		if a.begins_with("--wait="):
			wait_s = float(a.substr(7))
	var root3d := Node3D.new()
	get_root().add_child(root3d)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.position = Vector3(0, 0.5, 4)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.4, 0.1)
	mi.material_override = mat
	root3d.add_child(mi)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-40, 30, 0)
	root3d.add_child(l)
	for i in 8:
		await process_frame
	var img := get_root().get_texture().get_image()
	var ok := img.save_png(ProjectSettings.globalize_path(out_path) if out_path.begins_with("res://") else out_path)
	print("ADAPTER: ", RenderingServer.get_video_adapter_name())
	print("WINDOW pos=", DisplayServer.window_get_position(), " size=", DisplayServer.window_get_size(), " mode=", DisplayServer.window_get_mode(), " focused=", DisplayServer.window_is_focused())
	print("IMG ", img.get_width(), "x", img.get_height(), " save_ok=", ok, " center_px=", img.get_pixel(img.get_width() / 2, img.get_height() / 2))
	print("SCREENS count=", DisplayServer.get_screen_count(), " primary=", DisplayServer.get_primary_screen(), " rect0=", DisplayServer.screen_get_usable_rect(0))
	if wait_s > 0.0:
		print("WAITING ", wait_s)
		await create_timer(wait_s).timeout
	quit()
