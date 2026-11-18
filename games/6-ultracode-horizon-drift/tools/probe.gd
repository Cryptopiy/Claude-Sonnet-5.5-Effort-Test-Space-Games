extends SceneTree
# Probe engine defaults + prove windowed screenshots work. Run:
#   Godot_console.exe --path <proj> --script res://tools/probe.gd --resolution 640x360

var _frames := 0

func _initialize() -> void:
	print("physics engine setting: ", ProjectSettings.get_setting("physics/3d/physics_engine", "<unset>"))
	print("rendering method: ", ProjectSettings.get_setting("rendering/renderer/rendering_method", "<unset>"))
	print("float is double? Vector3 size: ", Engine.get_version_info())
	print("PhysicsServer3D: ", PhysicsServer3D.get_class() if PhysicsServer3D else "none")
	print("RenderingDevice: ", RenderingServer.get_video_adapter_name(), " / ", RenderingServer.get_video_adapter_api_version())
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 4)
	root.add_child(cam)
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	root.add_child(mi)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(-0.8, 0.6, 0)
	root.add_child(l)

func _process(_dt: float) -> bool:
	_frames += 1
	if _frames == 6:
		var img := root.get_texture().get_image()
		print("image size: ", img.get_size())
		var err := img.save_png("res://tools/probe.png")
		print("save err: ", err)
		quit()
	return false
