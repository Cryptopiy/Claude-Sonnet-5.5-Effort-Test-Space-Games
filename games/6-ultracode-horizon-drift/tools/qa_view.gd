extends SceneTree
## QA viewer: renders models with SubViewports at a fixed, larger resolution (independent of --resolution).
##   powershell -File tools/godot.ps1 -Mode run -Script res://tools/qa_view.gd -GodotArgs "-- models=a.glb,b.glb [cell=640x480] [views=front,back,side,top] [tag=qa] [shot=name:az:el:zoom:cx:cy:cz]"
## Output: .previews/qa_<model>_<tag>.png (2x2 sheet of the views) ; shots -> .previews/qa_<model>_<name>.png
## az: 0 = camera on +Z looking at the model (sees the BACK, front is -Z), 180 = camera at -Z (sees the front).
## shot centre cx,cy,cz are offsets (metres) from the model AABB centre; zoom multiplies the fit distance (smaller = closer).

var _models: PackedStringArray = []
var _cw := 640
var _ch := 480
var _tag := "qa"
var _views: PackedStringArray = ["front", "back", "side", "top"]
var _shots: Array = []
var _state := 0
var _idx := 0
var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D
var _cur: Node3D
var _wait := 0
var _jobs: Array = []   # each: {name, az, el, zoom, off}
var _job_i := 0
var _imgs: Array = []
var _center := Vector3.ZERO
var _radius := 1.0
var _night := false
var _rots: Array = []
var _spins: Array = []

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("models="):
			_models = a.substr(7).split(",", false)
		elif a.begins_with("cell="):
			var s := a.substr(5).split("x")
			_cw = int(s[0]); _ch = int(s[1])
		elif a.begins_with("views="):
			_views = a.substr(6).split(",", false)
		elif a.begins_with("tag="):
			_tag = a.substr(4)
		elif a.begins_with("night="):
			_night = a.substr(6) == "1"
		elif a.begins_with("rot="):
			_rots.append(a.substr(4))
		elif a.begins_with("spin="):
			_spins.append(a.substr(5))
		elif a.begins_with("shot="):
			_shots.append(a.substr(5))
	_vp = SubViewport.new()
	_vp.size = Vector2i(_cw, _ch)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.1) if _night else Color(0.34, 0.45, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.6)
	env.ambient_light_energy = 0.15 if _night else 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 150, 0)   # sun in front-left of the model (light travels toward +Z): lights the front (-Z) faces
	sun.light_energy = 0.15 if _night else 1.3
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	_vp.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.36, 0.28)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position.y = -0.06
	_vp.add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.near = 0.05
	_cam.far = 3000.0
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	if _models.is_empty():
		print("qa_view: no models=")
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

func _view_def(v: String) -> Dictionary:
	match v:
		"front": return {"name": v, "az": 150.0, "el": 20.0, "zoom": 1.0, "off": Vector3.ZERO}
		"back": return {"name": v, "az": 330.0, "el": 20.0, "zoom": 1.0, "off": Vector3.ZERO}
		"side": return {"name": v, "az": 90.0, "el": 10.0, "zoom": 1.0, "off": Vector3.ZERO}
		"top": return {"name": v, "az": 0.0, "el": 80.0, "zoom": 1.0, "off": Vector3.ZERO}
		"eye": return {"name": v, "az": 180.0, "el": 4.0, "zoom": 0.55, "off": Vector3(0, -_center.y + 1.7, 0)}   # a player standing in front, eye height 1.7
	return {"name": v, "az": 150.0, "el": 20.0, "zoom": 1.0, "off": Vector3.ZERO}

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
	for r in _rots:
		var f := String(r).split(":")
		var nd := _cur.find_child(f[0], true, false) as Node3D
		if nd:
			nd.rotation_degrees = Vector3(float(f[1]), float(f[2]), float(f[3]))
		else:
			print("rot: node not found ", f[0])
	for sp in _spins:
		var f2 := String(sp).split(":")
		var nd2 := _cur.find_child(f2[0], true, false) as Node3D
		if nd2:
			nd2.rotate_object_local(Vector3.UP, deg_to_rad(float(f2[1])))
	var a := _aabb_of(_cur)
	_center = a.get_center()
	_radius = maxf(a.size.length() * 0.5, 0.2)
	print("=== ", p, " size=", a.size, " min_y=", a.position.y)
	_jobs.clear()
	for v in _views:
		if v != "":
			_jobs.append(_view_def(v))
	for s in _shots:
		var f := String(s).split(":")
		_jobs.append({"name": f[0], "az": float(f[1]), "el": float(f[2]), "zoom": float(f[3]), "off": Vector3(float(f[4]), float(f[5]), float(f[6]))})
	_job_i = 0
	_imgs.clear()
	_place()
	_wait = 5
	return true

func _place() -> void:
	var j: Dictionary = _jobs[_job_i]
	var az := deg_to_rad(float(j["az"]))
	var el := deg_to_rad(float(j["el"]))
	var d := _radius * 2.45 * float(j["zoom"])
	var c: Vector3 = _center + (j["off"] as Vector3)
	_cam.global_position = c + Vector3(sin(az) * cos(el) * d, sin(el) * d, cos(az) * cos(el) * d)
	var up := Vector3.UP if float(j["el"]) < 70.0 else Vector3(0, 0, -1)
	_cam.look_at(c, up)

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
	_job_i += 1
	if _job_i >= _jobs.size():
		var base := _models[_idx].get_file().get_basename()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.previews"))
		var nviews := _views.size()
		# sheet for the standard views
		if nviews > 0:
			var cols := 2 if nviews > 1 else 1
			var rows := int(ceil(float(nviews) / cols))
			var sheet := Image.create(_cw * cols, _ch * rows, false, Image.FORMAT_RGBA8)
			for i in nviews:
				sheet.blit_rect(_imgs[i], Rect2i(0, 0, _cw, _ch), Vector2i((i % cols) * _cw, (i / cols) * _ch))
			var out := ProjectSettings.globalize_path("res://.previews/qa_%s_%s.png" % [base, _tag])
			sheet.save_png(out)
			print("SHEET: ", out)
		for k in range(nviews, _jobs.size()):
			var out2 := ProjectSettings.globalize_path("res://.previews/qa_%s_%s.png" % [base, _jobs[k]["name"]])
			(_imgs[k] as Image).save_png(out2)
			print("SHOT: ", out2)
		_idx += 1
		_cur.queue_free()
		_cur = null
	else:
		_place()
		_wait = 4
	return false
