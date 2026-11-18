extends SceneTree
## Custom close-up renderer for the `ship` group.  Renders N camera shots of one glb into .previews/ship_<tag>_<n>.png and
## optionally poses named nodes first (to verify retract axes, glow scale ...).
##   powershell -File tools/godot.ps1 -Mode run -Script res://tools/ship_shot.gd -GodotArgs "--resolution 960x600 -- model=ship_player.glb tag=a shots=35,18,20,0,0.2,0;215,10,14,0,0,0 pose=Gear_Front:-80,0,0 scale=EngineGlow_L:1,0.3,1"
## shots = az,el,dist,tx,ty,tz  (az 0 = camera on +Z (behind a -Z facing model); el degrees)  separated by ';'
## pose  = Node:rx,ry,rz  (degrees, added to the node's rest rotation about its LOCAL axes, X then Y then Z)   separated by ';'
## scale = Node:sx,sy,sz   separated by ';'      bg=r,g,b   ground=1 (a grey disc at y=min)   sun=az,el

var _model := "ship_player.glb"
var _tag := "a"
var _shots: Array = []
var _poses := {}
var _scales := {}
var _vw := 960
var _vh := 600
var _cam: Camera3D
var _cur: Node3D
var _idx := 0
var _wait := 6
var _ground := false
var _bg := Color(0.16, 0.18, 0.22)
var _sun := Vector2(-50, 35)
var _env_energy := 0.35
var _fov := 40.0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("model="):
			_model = a.substr(6)
		elif a.begins_with("tag="):
			_tag = a.substr(4)
		elif a.begins_with("size="):
			var s := a.substr(5).split("x")
			_vw = int(s[0]); _vh = int(s[1])
		elif a.begins_with("shots="):
			for sh in a.substr(6).split(";", false):
				var f := sh.split(",")
				var v: Array = []
				for x in f:
					v.append(float(x))
				_shots.append(v)
		elif a.begins_with("pose="):
			for p in a.substr(5).split(";", false):
				var kv := p.split(":")
				var f := kv[1].split(",")
				_poses[kv[0]] = Vector3(float(f[0]), float(f[1]), float(f[2]))
		elif a.begins_with("scale="):
			for p in a.substr(6).split(";", false):
				var kv := p.split(":")
				var f := kv[1].split(",")
				_scales[kv[0]] = Vector3(float(f[0]), float(f[1]), float(f[2]))
		elif a.begins_with("ground="):
			_ground = a.substr(7) != "0"
		elif a.begins_with("fov="):
			_fov = float(a.substr(4))
		elif a.begins_with("bg="):
			var p := a.substr(3).split(",")
			_bg = Color(float(p[0]), float(p[1]), float(p[2]))
		elif a.begins_with("env="):
			_env_energy = float(a.substr(4))
	root.size = Vector2i(_vw, _vh)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = _env_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, -150, 0)
	fill.light_energy = 0.25
	root.add_child(fill)
	_cam = Camera3D.new()
	_cam.near = 0.02
	_cam.far = 5000.0
	_cam.fov = _fov
	root.add_child(_cam)
	var p := _model
	if not p.begins_with("res://"):
		p = "res://assets/models/" + p
	var ps := load(p) as PackedScene
	if ps == null:
		print("LOAD FAILED ", p)
		quit(1)
		return
	_cur = ps.instantiate()
	root.add_child(_cur)
	for k in _poses.keys():
		var n := _cur.find_child(k, true, false)
		if n is Node3D:
			var nd := n as Node3D
			var r: Vector3 = _poses[k]
			nd.rotate_object_local(Vector3.RIGHT, deg_to_rad(r.x))
			nd.rotate_object_local(Vector3.UP, deg_to_rad(r.y))
			nd.rotate_object_local(Vector3.BACK, deg_to_rad(r.z))
		else:
			print("POSE: node not found ", k)
	for k in _scales.keys():
		var n := _cur.find_child(k, true, false)
		if n is Node3D:
			(n as Node3D).scale = _scales[k]
		else:
			print("SCALE: node not found ", k)
	if _ground:
		var m := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(60, 60)
		m.mesh = pm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.32, 0.30, 0.27)
		mat.roughness = 0.95
		m.material_override = mat
		m.position = Vector3(0, -1.9, 0)
		root.add_child(m)

func _place() -> void:
	var s: Array = _shots[_idx]
	var az := deg_to_rad(s[0])
	var el := deg_to_rad(s[1])
	var d: float = s[2]
	var t := Vector3(s[3], s[4], s[5])
	_cam.global_position = t + Vector3(sin(az) * cos(el) * d, sin(el) * d, cos(az) * cos(el) * d)
	_cam.look_at(t, Vector3.UP)
	_wait = 5

var _started := false

func _process(_dt: float) -> bool:
	if not _started:
		_started = true
		_place()
		return false
	_wait -= 1
	if _wait > 0:
		return false
	var img := root.get_texture().get_image()
	var out := ProjectSettings.globalize_path("res://.previews/ship_%s_%d.png" % [_tag, _idx])
	img.save_png(out)
	print("SHOT: ", out)
	_idx += 1
	if _idx >= _shots.size():
		quit()
		return true
	_place()
	return false
