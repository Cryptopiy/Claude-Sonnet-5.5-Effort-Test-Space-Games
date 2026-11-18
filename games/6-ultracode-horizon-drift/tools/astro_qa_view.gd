extends SceneTree
## QA viewer for the astro group (does not touch game code).  Renders one model from custom views into ONE sheet png.
##   powershell -File tools/godot.ps1 -Mode run -Script res://tools/astro_qa_view.gd -GodotArgs "--resolution 600x450 -- model=astronaut.glb out=qa_astro views=215:10:1.2,35:10:1.2 [focus=Head] [rot=Leg_L:30,0,0;Arm_R:-40,0,0] [ground=1] [look=0,0.9,0]"
## views = az:el:distMult list (az 0 = camera on +Z looking toward -Z, i.e. looking at the model's BACK; az 180 = looking at the FRONT)
## focus=<node name>  centres the camera on that node's AABB;  look=x,y,z overrides the centre;  size controls radius via distMult * radius.

var _model := ""
var _out := "qa_view"
var _views: Array = []
var _rot := {}
var _focus := ""
var _look := Vector3.INF
var _ground := false
var _vw := 600
var _vh := 450
var _cur: Node3D
var _cam: Camera3D
var _radius := 1.0
var _center := Vector3.ZERO
var _view := 0
var _wait := 5
var _sheet: Image
var _cols := 2
var _bg := Color(0.30, 0.38, 0.50)
var _ready_done := false
var _cull := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("model="): _model = a.substr(6)
		elif a.begins_with("out="): _out = a.substr(4)
		elif a.begins_with("focus="): _focus = a.substr(6)
		elif a.begins_with("ground="): _ground = a.substr(7) != "0"
		elif a.begins_with("cols="): _cols = int(a.substr(5))
		elif a.begins_with("cull="): _cull = a.substr(5) != "0"
		elif a.begins_with("size="):
			var s := a.substr(5).split("x"); _vw = int(s[0]); _vh = int(s[1])
		elif a.begins_with("bg="):
			var p := a.substr(3).split(","); _bg = Color(float(p[0]), float(p[1]), float(p[2]))
		elif a.begins_with("look="):
			var p := a.substr(5).split(","); _look = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif a.begins_with("rot="):
			for item in a.substr(4).split(";", false):
				var kv := item.split(":")
				var v := kv[1].split(",")
				_rot[kv[0]] = Vector3(float(v[0]), float(v[1]), float(v[2]))
		elif a.begins_with("views="):
			for item in a.substr(6).split(",", false):
				var p := item.split(":")
				_views.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	if _views.is_empty():
		_views = [Vector3(180, 12, 1.4), Vector3(90, 12, 1.4), Vector3(0, 12, 1.4), Vector3(0, 80, 1.4)]
	root.size = Vector2i(_vw, _vh)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.8)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 40, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)
	_cam = Camera3D.new()
	_cam.near = 0.02
	_cam.far = 500.0
	_cam.fov = 40.0
	root.add_child(_cam)
	var ps := load("res://assets/models/" + _model) as PackedScene
	_cur = ps.instantiate()
	root.add_child(_cur)
	for k in _rot.keys():
		var n := _cur.find_child(k, true, false) as Node3D
		if n:
			var r: Vector3 = _rot[k]
			n.rotation_degrees = r
		else:
			print("rot target not found: ", k)
	if _cull:
		# inside-out test: force back-face culling on every material; faces that vanish have inverted winding/normals
		var st: Array = [_cur]
		while not st.is_empty():
			var c: Node = st.pop_back()
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				var mi := c as MeshInstance3D
				for si in mi.mesh.get_surface_count():
					var m := mi.mesh.surface_get_material(si)
					if m is BaseMaterial3D:
						(m as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
			for k in c.get_children():
				st.append(k)
	if _ground:
		var g := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(60, 60)
		g.mesh = pm
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.4, 0.45, 0.3)
		g.material_override = gm
		root.add_child(g)
	_sheet = Image.create(_vw * _cols, _vh * ((_views.size() + _cols - 1) / _cols), false, Image.FORMAT_RGBA8)

func _setup_view() -> void:
	var a := _aabb(_cur if _focus == "" else _cur.find_child(_focus, true, false))
	_center = a.get_center() if _look == Vector3.INF else _look
	_radius = maxf(a.size.length() * 0.5, 0.1)
	print("AABB size=", a.size, " center=", a.get_center())
	_place()
	_ready_done = true

func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var st: Array = [n]
	while not st.is_empty():
		var c: Node = st.pop_back()
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var b := mi.global_transform * mi.get_aabb()
			if first:
				out = b; first = false
			else:
				out = out.merge(b)
		for k in c.get_children():
			st.append(k)
	return out

func _place() -> void:
	var v: Vector3 = _views[_view]
	var az := deg_to_rad(v.x)
	var el := deg_to_rad(v.y)
	var d := _radius * v.z * 2.0
	_cam.global_position = _center + Vector3(sin(az) * cos(el) * d, sin(el) * d, cos(az) * cos(el) * d)
	var up := Vector3.UP if v.y < 70 else Vector3(0, 0, -1)
	_cam.look_at(_center, up)

func _process(_dt: float) -> bool:
	if not _ready_done:
		_setup_view()
		return false
	_wait -= 1
	if _wait > 0:
		return false
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	_sheet.blit_rect(img, Rect2i(0, 0, _vw, _vh), Vector2i((_view % _cols) * _vw, (_view / _cols) * _vh))
	_view += 1
	if _view >= _views.size():
		var out := ProjectSettings.globalize_path("res://.previews/%s.png" % _out)
		_sheet.save_png(out)
		print("SHEET: ", out)
		quit()
	else:
		_place()
		_wait = 3
	return false
