extends SceneTree
## Renders contact sheets of .glb models as Godot sees them, and prints the node tree + bounds.
##   powershell -File tools/godot.ps1 -Mode run -Script res://tools/model_viewer.gd -GodotArgs "-- models=ship_player.glb,tree_a.glb sheet=mysheet"
## Output: .previews/godot_<modelname>.png  (2x2 views: front-ish, side, back, top)  -- LOOK at them with the Read tool.
## models= paths are relative to res://assets/models/ (or full res:// paths).  Optional: bg=r,g,b  size=400x300  tree=0/1

var _models: PackedStringArray = []
var _idx := 0
var _view := 0
var _wait := 0
var _cam: Camera3D
var _holder: Node3D
var _cur: Node3D
var _pole: MeshInstance3D
var _center := Vector3.ZERO
var _radius := 1.0
var _sheet: Image
var _vw := 400
var _vh := 300
var _show_tree := false
var _dist := 1.75
var _ref := true
var _tag := "zoom"
var _views := [Vector2(35, 18), Vector2(125, 18), Vector2(215, 18), Vector2(0, 80)]  # azimuth, elevation

func _initialize() -> void:
	var bg := Color(0.16, 0.18, 0.22)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("models="):
			_models = a.substr(7).split(",", false)
		elif a.begins_with("bg="):
			var p := a.substr(3).split(",")
			bg = Color(float(p[0]), float(p[1]), float(p[2]))
		elif a.begins_with("size="):
			var s := a.substr(5).split("x")
			_vw = int(s[0]); _vh = int(s[1])
		elif a.begins_with("dist="):
			_dist = float(a.substr(5))
		elif a.begins_with("ref="):
			_ref = a.substr(4) != "0"
		elif a.begins_with("tree="):
			_show_tree = a.substr(5) != "0"
	root.size = Vector2i(_vw, _vh)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.35
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
	root.add_child(_cam)
	_holder = Node3D.new()
	root.add_child(_holder)
	if _ref:
		var g := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 6.0; cm.bottom_radius = 6.0; cm.height = 0.02
		g.mesh = cm
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.25, 0.3, 0.25)
		g.material_override = gm
		g.position = Vector3(0, -0.011, 0)
		root.add_child(g)
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.04; pm.bottom_radius = 0.04; pm.height = 1.8
		pole.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(1, 1, 1)
		pole.material_override = pmat
		pole.position = Vector3(-1.0, 0.9, 1.5)
		_pole = pole
		root.add_child(pole)
	if _models.is_empty():
		print("model_viewer: no models= given")
		quit(1)

func _aabb_of(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var a := mi.global_transform * mi.get_aabb()
			if first:
				out = a; first = false
			else:
				out = out.merge(a)
		for k in c.get_children():
			stack.append(k)
	return out

func _print_tree(n: Node, depth: int) -> void:
	var s := "  ".repeat(depth) + n.name + " [" + n.get_class() + "]"
	if n is Node3D:
		var p := (n as Node3D).position
		s += " pos=(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z]
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var a := mi.get_aabb()
		var tris := 0
		var mats: PackedStringArray = []
		if mi.mesh:
			for si in mi.mesh.get_surface_count():
				var arr := mi.mesh.surface_get_arrays(si)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() / 3) if idx != null else (arr[Mesh.ARRAY_VERTEX].size() / 3)
				var m := mi.get_active_material(si)
				mats.append(m.resource_name if m else "<none>")
		s += " aabb_size=(%.2f, %.2f, %.2f) tris=%d mats=%s" % [a.size.x, a.size.y, a.size.z, tris, str(mats)]
	print(s)
	for c in n.get_children():
		_print_tree(c, depth + 1)

func _load_next() -> bool:
	if _cur:
		_cur.queue_free()
		_cur = null
	if _idx >= _models.size():
		return false
	var p := _models[_idx]
	if not p.begins_with("res://"):
		p = "res://assets/models/" + p
	var ps := load(p) as PackedScene
	if ps == null:
		print("MODEL LOAD FAILED: ", p)
		_idx += 1
		return _load_next()
	_cur = ps.instantiate()
	_holder.add_child(_cur)
	print("=== ", p)
	if _show_tree:
		_print_tree(_cur, 0)
	var a := _aabb_of(_cur)
	_center = a.get_center()
	if _pole:
		_pole.position = Vector3(a.position.x - 0.5, 0.9, a.get_center().z)
	_radius = maxf(a.size.length() * 0.5, 0.2)
	print("TOTAL aabb size=", a.size, " center=", a.get_center(), " min_y=", a.position.y)
	_sheet = Image.create(_vw * 2, _vh * 2, false, Image.FORMAT_RGBA8)
	_view = 0
	_wait = 4
	_place_cam()
	return true

func _place_cam() -> void:
	var v: Vector2 = _views[_view]
	var az := deg_to_rad(v.x)
	var el := deg_to_rad(v.y)
	var d := _radius * _dist
	var pos := _center + Vector3(sin(az) * cos(el) * d, sin(el) * d, cos(az) * cos(el) * d)
	_cam.global_position = pos
	var up := Vector3.UP if v.y < 70 else Vector3(0, 0, -1)
	_cam.look_at(_center, up)

func _process(_dt: float) -> bool:
	if _cur == null:
		if not _load_next():
			quit()
			return true
	_wait -= 1
	if _wait > 0:
		return false
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	var cx := (_view % 2) * _vw
	var cy := (_view / 2) * _vh
	_sheet.blit_rect(img, Rect2i(0, 0, _vw, _vh), Vector2i(cx, cy))
	_view += 1
	if _view >= _views.size():
		var base := _models[_idx].get_file().get_basename()
		var out := ProjectSettings.globalize_path("res://.previews/zoom_%s.png" % base)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.previews"))
		_sheet.save_png(out)
		print("SHEET: ", out)
		_idx += 1
		_cur.queue_free()
		_cur = null
	else:
		_place_cam()
		_wait = 3
	return false
