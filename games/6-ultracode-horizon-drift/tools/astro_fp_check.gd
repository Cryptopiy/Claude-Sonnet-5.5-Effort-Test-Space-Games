extends SceneTree
## Renders the first-person view model exactly as a player camera sees it (camera at origin, looking -Z, vertical FOV 75).
##   powershell -File tools/godot.ps1 -Mode run -Script res://tools/astro_fp_check.gd -GodotArgs "--resolution 960x540"
## Output: .previews/godot_fp_cam.png   (astro group tool; does not touch game code)

var _frames := 0
var _cam: Camera3D

func _initialize() -> void:
	root.size = Vector2i(960, 540)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.58, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	root.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.near = 0.03
	_cam.far = 500.0
	root.add_child(_cam)
	var ps := load("res://assets/models/fp_viewmodel.glb") as PackedScene
	var n := ps.instantiate()
	_cam.add_child(n)
	# a ground reference far below/ahead so the lighting reads like gameplay
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.5, 0.3)
	ground.material_override = gm
	ground.position = Vector3(0, -1.7, -5)
	root.add_child(ground)

func _process(_dt: float) -> bool:
	_frames += 1
	if _frames == 6:
		var img := root.get_texture().get_image()
		var out := ProjectSettings.globalize_path("res://.previews/godot_fp_cam.png")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.previews"))
		img.save_png(out)
		print("SHEET: ", out)
		quit()
	return false
