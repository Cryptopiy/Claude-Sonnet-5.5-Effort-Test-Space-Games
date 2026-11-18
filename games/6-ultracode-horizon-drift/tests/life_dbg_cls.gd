extends SceneTree
func _init() -> void:
	print("[cls] exists stub=", FileAccess.file_exists("res://tests/sky_stub_planet.gd"), " planet=", FileAccess.file_exists("res://world/planet/planet.gd"))
	var s = load("res://tests/sky_stub_planet.gd")
	print("[cls] stub load=", s)
	var p = load("res://world/planet/planet.gd")
	print("[cls] planet load=", p, " can_inst=", p.can_instantiate() if p != null else false)
	for gc in ProjectSettings.get_global_class_list():
		if String(gc["class"]) == "Planet":
			print("[cls] global class Planet -> ", gc["path"])
	quit()
