extends SceneTree
## QA: draws the manifest colliders (translucent red) over a structure model, renders 3 views.
##   powershell -File tools/godot.ps1 -Mode run -Script res://tools/structures_col_view.gd -GodotArgs "-- models=a,b,c"   (ids without .glb)
## Output: .previews/structcol_<id>.png  (front-3/4 | side | top).   Reads assets/models/manifest_structures.json.

var _ids: PackedStringArray = []
var _man := {}
var _cw := 560
var _ch := 420
var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D
var _cur: Node3D
var _idx := 0
var _view := 0
var _wait := 0
var _imgs: Array = []
var _center := Vector3.ZERO
var _radius := 1.0
var _views := [Vector2(150, 22), Vector2(90, 8), Vector2(0, 85)]

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("models="):
			_ids = a.substr(7).split(",", false)
	var f := FileAccess.open("res://assets/models/manifest_structures.json", FileAccess.READ)
	var j = JSON.parse_string(f.get_as_text())
	for m in j["models"]:
		_man[m["id"]] = m
	_vp = SubViewport.new()
	_vp.size = Vector2i(_cw, _ch)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.34, 0.45, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 150, 0)
	sun.light_energy = 1.2
	_vp.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.36, 0.28)
	ground.material_override = gm
	ground.position.y = -0.02
	_vp.add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.far = 3000.0
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)

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

func _col_mesh(c: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if c["shape"] == "box":
		var bm := BoxMesh.new()
		var s: Array = c["size"]
		bm.size = Vector3(s[0], s[1], s[2])
		mi.mesh = bm
	elif c["shape"] == "cylinder":
		var cm := CylinderMesh.new()
		cm.top_radius = c["radius"]
		cm.bottom_radius = c["radius"]
		cm.height = c["height"]
		mi.mesh = cm
	else:
		return null
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.1, 0.1, 0.38)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	var ce: Array = c["center"]
	mi.position = Vector3(ce[0], ce[1], ce[2])
	return mi

func _load_next() -> bool:
	if _cur:
		_cur.queue_free()
		_cur = null
	if _idx >= _ids.size():
		return false
	var id := _ids[_idx]
	var ps := load("res://assets/models/%s.glb" % id) as PackedScene
	if ps == null or not _man.has(id):
		print("LOAD/MANIFEST FAILED: ", id)
		_idx += 1
		return _load_next()
	_cur = ps.instantiate()
	_holder.add_child(_cur)
	var m: Dictionary = _man[id]
	var cols: Array = m.get("colliders", [m["collider"]])
	var n := 0
	for c in cols:
		var mi := _col_mesh(c)
		if mi:
			_cur.add_child(mi)
			n += 1
	# main collider as a green outline marker if colliders list exists (shown as thin box)
	var a := _aabb_of(_cur)
	_center = a.get_center()
	_radius = maxf(a.size.length() * 0.5, 0.2)
	print("=== ", id, " colliders=", n)
	_imgs.clear()
	_view = 0
	_place()
	_wait = 5
	return true

func _place() -> void:
	var v: Vector2 = _views[_view]
	var az := deg_to_rad(v.x)
	var el := deg_to_rad(v.y)
	var d := _radius * 2.3
	_cam.global_position = _center + Vector3(sin(az) * cos(el) * d, sin(el) * d, cos(az) * cos(el) * d)
	_cam.look_at(_center, Vector3.UP if v.y < 70.0 else Vector3(0, 0, -1))

func _process(_dt: float) -> bool:
	if _cur == null:
		if not _load_next():
			quit()
			return true
	_wait -= 1
	if _wait > 0:
		return false
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	_imgs.append(img)
	_view += 1
	if _view >= _views.size():
		var sheet := Image.create(_cw * 2, _ch * 2, false, Image.FORMAT_RGBA8)
		for i in _imgs.size():
			sheet.blit_rect(_imgs[i], Rect2i(0, 0, _cw, _ch), Vector2i((i % 2) * _cw, (i / 2) * _ch))
		var out := ProjectSettings.globalize_path("res://.previews/structcol_%s.png" % _ids[_idx])
		sheet.save_png(out)
		print("SHEET: ", out)
		_idx += 1
		_cur.queue_free()
		_cur = null
	else:
		_place()
		_wait = 4
	return false
