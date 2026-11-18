class_name Planet
extends Node3D
## A procedurally generated spherical world: quadtree cube-sphere terrain LOD, water, atmosphere,
## instanced flora, landing pad / outpost points of interest, or a gas giant.

const TILE_N := 24
const MAX_DEPTH := 9

class Tile:
	var face := 0
	var depth := 0
	var ix := 0
	var iy := 0
	var state := 0       # 0 empty, 1 generating, 2 ready
	var task := -1
	var dead := false
	var serial := 0
	var data: Dictionary
	var mi: MeshInstance3D
	var children: Array = []
	var center := Vector3.ZERO
	var size := 1.0
	var hidden_since := -1.0

var body: Dictionary
var biome: Dictionary
var gen: TerrainGen
var R := 2000.0
var atmo_h := 600.0
var gas := false
var density := 0.0
var gravity := 9.0
var landable := true
var spin_axis := Vector3.UP
var spin_rate := 0.0
var sys_pos := Vector3.ZERO
var parent_planet: Planet = null
var now := 0.0

var terrain_mat: ShaderMaterial
var fog_shader: Shader
var nofog_shader: Shader
var fogged := true
var roots: Array = []
var pending: Array = []
var water: MeshInstance3D
var atmo_mi: MeshInstance3D
var atmo_mat: ShaderMaterial
var max_depth := MAX_DEPTH

var flora_mmis: Array = []
const FLORA_CAP := 2400
var prop_center := Vector3(0, 1, 0)
var prop_has := false
var prop_task := -1
var prop_result: Dictionary = {}
var prop_pending_center := Vector3.ZERO
var collected: Dictionary = {}
var res_nodes: Dictionary = {}
var current_res: Array = []

var pois: Array = []          # {node, kind, dir}
var pad_dir := Vector3.UP
var pad_pos := Vector3.ZERO

static var detail_tex: ImageTexture
static var model_cache: Dictionary = {}

static func model(name: String) -> PackedScene:
	if not model_cache.has(name):
		model_cache[name] = load("res://assets/models/%s.glb" % name)
	return model_cache[name]

static func model_mesh(name: String) -> Mesh:
	var inst := model(name).instantiate()
	var found := inst.find_children("*", "MeshInstance3D", true, false)
	var m: Mesh = (found[0] as MeshInstance3D).mesh
	inst.free()
	return m

static func get_detail_tex() -> ImageTexture:
	if detail_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.03
		n.fractal_octaves = 4
		var img := n.get_seamless_image(256, 256, false, false, 0.2, false)
		img.convert(Image.FORMAT_RGB8)
		img.generate_mipmaps()
		detail_tex = ImageTexture.create_from_image(img)
	return detail_tex

func setup(b: Dictionary) -> void:
	body = b
	name = b["name"]
	R = b["radius"]
	gas = b["biome"] == "gas"
	landable = not gas
	atmo_h = R * 0.3
	spin_axis = Vector3(sin(b["tilt"]), cos(b["tilt"]), 0.0).normalized()
	spin_rate = TAU / b["spin"]
	if gas:
		_setup_gas()
		return
	biome = Biomes.get_def(b["biome"])
	density = biome["density"]
	gravity = biome["gravity"]
	gen = TerrainGen.new()
	gen.setup(R, biome, b["seed"])
	_setup_pois()
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://shaders/terrain.gdshader")
	fog_shader = terrain_mat.shader
	nofog_shader = Shader.new()
	nofog_shader.code = fog_shader.code.replace("render_mode ", "render_mode fog_disabled, ")
	terrain_mat.set_shader_parameter("detail", get_detail_tex())
	if biome["id"] == "volcanic":
		terrain_mat.set_shader_parameter("emit_strength", 4.0)
	# six root tiles, built synchronously
	for f in 6:
		var t := _new_tile(f, 0, 0, 0)
		t.data = gen.build_tile(f, 0, 0, 0, TILE_N)
		_finalize(t)
		roots.append(t)
	# water
	if biome.has("water") and gen.has_sea:
		water = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = R + gen.sea
		sm.height = 2.0 * (R + gen.sea)
		sm.radial_segments = 224
		sm.rings = 112
		water.mesh = sm
		var wm := ShaderMaterial.new()
		wm.shader = load("res://shaders/water.gdshader")
		wm.set_shader_parameter("water_color", biome["water"])
		water.material_override = wm
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(water)
	# atmosphere shell (visual, from space)
	if density > 0.0:
		_make_atmo(R * 1.09, biome["atmo"], density)
	# flora multimeshes
	for fl in biome["flora"]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = model_mesh(fl["model"])
		mm.instance_count = FLORA_CAP
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-R, -R, -R) * 1.2, Vector3(R, R, R) * 2.4)
		mmi.multimesh = mm
		add_child(mmi)
		flora_mmis.append(mmi)

func _make_atmo(rad: float, col: Color, dens: float) -> void:
	atmo_mi = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rad
	s.height = rad * 2.0
	s.radial_segments = 96
	s.rings = 48
	atmo_mi.mesh = s
	atmo_mat = ShaderMaterial.new()
	atmo_mat.shader = load("res://shaders/atmosphere.gdshader")
	atmo_mat.set_shader_parameter("atmo_color", col)
	atmo_mat.set_shader_parameter("intensity", dens)
	atmo_mi.material_override = atmo_mat
	atmo_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# shell must not spin with the surface: counter-rotated each frame by main
	add_child(atmo_mi)

func _setup_gas() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = R
	sm.height = R * 2.0
	sm.radial_segments = 128
	sm.rings = 64
	mi.mesh = sm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/gas.gdshader")
	var gs: float = body["gas_seed"]
	m.set_shader_parameter("seed", gs)
	var pals := [
		[Color(0.88, 0.68, 0.42), Color(0.55, 0.34, 0.22), Color(0.96, 0.88, 0.72)],
		[Color(0.45, 0.62, 0.78), Color(0.22, 0.34, 0.55), Color(0.82, 0.9, 0.95)],
		[Color(0.7, 0.45, 0.62), Color(0.35, 0.2, 0.4), Color(0.95, 0.8, 0.85)]]
	var pal: Array = pals[int(gs * 3.0) % 3]
	m.set_shader_parameter("c1", pal[0])
	m.set_shader_parameter("c2", pal[1])
	m.set_shader_parameter("c3", pal[2])
	mi.material_override = m
	add_child(mi)
	_make_atmo(R * 1.05, pal[0].lerp(Color.WHITE, 0.3), 0.7)
	# rings
	var ring := MeshInstance3D.new()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var segs := 128
	var r0 := R * 1.45
	var r1 := R * 2.5
	for i in segs + 1:
		var a := TAU * float(i) / segs
		var c := Vector3(cos(a), 0, sin(a))
		verts.append(c * r0)
		uvs.append(Vector2(0, 0))
		verts.append(c * r1)
		uvs.append(Vector2(1, 0))
	for i in segs:
		var k := i * 2
		idx.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	nrm.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	ring.mesh = am
	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/ring.gdshader")
	rm.set_shader_parameter("col", pal[0].lerp(Color(0.9, 0.85, 0.75), 0.5))
	ring.material_override = rm
	ring.rotation = Vector3(0.35, 0, 0.2)
	add_child(ring)

# ----------------------------------------------------------------- POIs
func _setup_pois() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = body["seed"] * 13 + 7
	var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
	for tries in 40:
		var h := gen.height(d)
		var bad := (gen.has_sea and h < gen.sea + 4.0) or (gen.has_lava and h < gen.lava_h + 12.0)
		if not bad:
			break
		d = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
	pad_dir = d
	var h0 := gen.height(d)
	gen.flats.append({"dir": d, "h": h0, "r0": 12.0, "r1": 55.0, "pad_r": 5.9, "pad_h": 0.55})
	var t1 := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var t2 := d.cross(t1).normalized()
	var od := (d + (t1 * 30.0 + t2 * 6.0) / R).normalized()
	gen.flats.append({"dir": od, "h": h0, "r0": 9.0, "r1": 26.0, "pad_r": 0.0, "pad_h": 0.0})
	pad_pos = d * (R + h0)
	_add_poi("landing_pad", d, h0, "pad")
	_add_poi("outpost", od, gen.height(od), "outpost", PI)
	var bd := (d + (t1 * -16.0 + t2 * -9.0) / R).normalized()
	_add_poi("beacon", bd, gen.height(bd), "beacon")

func _add_poi(model_name: String, dir: Vector3, h: float, kind: String, yaw := 0.0) -> void:
	var n: Node3D = model(model_name).instantiate()
	var up := dir
	var ref := Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT
	var rx := ref.cross(up).normalized()
	var rz := rx.cross(up).normalized()
	var b := Basis(rx, up, rz).rotated(up, yaw + float(pois.size()))
	n.transform = Transform3D(b, dir * (R + h))
	add_child(n)
	pois.append({"node": n, "kind": kind, "dir": dir})

# ----------------------------------------------------------------- tiles
func _new_tile(f: int, d: int, ix: int, iy: int) -> Tile:
	var t := Tile.new()
	t.face = f
	t.depth = d
	t.ix = ix
	t.iy = iy
	var s := 2.0 / float(1 << d)
	t.center = TerrainGen.face_dir(f, -1.0 + (ix + 0.5) * s, -1.0 + (iy + 0.5) * s) * R
	t.size = R * s * 0.85
	return t

func _make_children(t: Tile) -> void:
	for dy in 2:
		for dx in 2:
			t.children.append(_new_tile(t.face, t.depth + 1, t.ix * 2 + dx, t.iy * 2 + dy))

func _request(t: Tile) -> void:
	if t.state != 0:
		return
	t.state = 1
	t.dead = false
	t.serial += 1
	t.task = WorkerThreadPool.add_task(_tile_job.bind(t))
	pending.append([t, t.task, t.serial])

func _tile_job(t: Tile) -> void:
	t.data = gen.build_tile(t.face, t.depth, t.ix, t.iy, TILE_N)

func _finalize(t: Tile) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = t.data["verts"]
	arrays[Mesh.ARRAY_NORMAL] = t.data["norms"]
	arrays[Mesh.ARRAY_COLOR] = t.data["cols"]
	arrays[Mesh.ARRAY_INDEX] = t.data["idx"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = t.data["origin"]
	mi.set_instance_shader_parameter("tile_origin", t.data["origin"])
	mi.visible = false
	add_child(mi)
	t.mi = mi
	t.data = {}
	t.state = 2

func _pump() -> void:
	var budget := 3
	var i := 0
	while i < pending.size() and budget > 0:
		var e: Array = pending[i]
		var t: Tile = e[0]
		if WorkerThreadPool.is_task_completed(e[1]):
			WorkerThreadPool.wait_for_task_completion(e[1])
			pending.remove_at(i)
			if t.serial == e[2] and t.state == 1 and not t.dead and not t.data.is_empty():
				_finalize(t)
				budget -= 1
		else:
			i += 1

func _free_subtree(t: Tile) -> void:
	for c in t.children:
		_free_subtree(c)
	t.children.clear()
	t.dead = true
	t.data = {}
	if t.mi:
		t.mi.queue_free()
		t.mi = null
	t.state = 0

func _unshow(t: Tile) -> void:
	if t.mi:
		t.mi.visible = false
	if t.hidden_since < 0.0:
		t.hidden_since = now
	for c in t.children:
		_unshow(c)
	if now - t.hidden_since > 8.0 and t.depth > 0:
		_free_subtree(t)

func _visit(t: Tile, cam: Vector3, split_k: float) -> void:
	var want := t.depth < max_depth and cam.distance_to(t.center) < t.size * split_k
	if want:
		if t.children.is_empty():
			_make_children(t)
		var all := true
		for c in t.children:
			if c.state == 0:
				_request(c)
			if c.state != 2:
				all = false
		if all:
			if t.mi:
				t.mi.visible = false
			t.hidden_since = -1.0
			for c in t.children:
				_visit(c, cam, split_k)
			return
	if t.mi:
		t.mi.visible = true
	t.hidden_since = -1.0
	for c in t.children:
		_unshow(c)

func update_lod(cam_local: Vector3, p_now: float) -> void:
	now = p_now
	if gas:
		return
	_pump()
	for t in roots:
		_visit(t, cam_local, 2.7)

func tile_count() -> int:
	var n := 0
	var stack: Array = roots.duplicate()
	while not stack.is_empty():
		var t: Tile = stack.pop_back()
		if t.mi and t.mi.visible:
			n += 1
		stack.append_array(t.children)
	return n

# ----------------------------------------------------------------- props
func update_props(cam_dir: Vector3, force: bool) -> void:
	if gas:
		return
	if prop_task >= 0:
		if WorkerThreadPool.is_task_completed(prop_task):
			WorkerThreadPool.wait_for_task_completion(prop_task)
			prop_task = -1
			_apply_props()
		return
	if force or not prop_has or (cam_dir - prop_center).length() * R > 28.0:
		prop_pending_center = cam_dir
		prop_task = WorkerThreadPool.add_task(_prop_job.bind(cam_dir, collected.duplicate()))

func _prop_job(c: Vector3, col: Dictionary) -> void:
	prop_result = gen.gen_props(c, col)

func _apply_props() -> void:
	prop_has = true
	prop_center = prop_pending_center
	var mms: Array = prop_result["mm"]
	for i in flora_mmis.size():
		var arr: PackedFloat32Array = mms[i]
		var n := mini(arr.size() / 12, FLORA_CAP)
		var mm: MultiMesh = (flora_mmis[i] as MultiMeshInstance3D).multimesh
		var buf := PackedFloat32Array()
		buf.resize(FLORA_CAP * 12)
		for k in n * 12:
			buf[k] = arr[k]
		mm.buffer = buf
		mm.visible_instance_count = n
	current_res = prop_result["res"]
	var keep := {}
	for r in current_res:
		keep[r["id"]] = true
		if not res_nodes.has(r["id"]):
			var nd: Node3D = model("resource").instantiate()
			var up: Vector3 = r["dir"]
			var ref := Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT
			var rx := ref.cross(up).normalized()
			var rz := rx.cross(up).normalized()
			nd.transform = Transform3D(Basis(rx, up, rz), r["pos"])
			add_child(nd)
			res_nodes[r["id"]] = nd
	for id in res_nodes.keys():
		if not keep.has(id):
			(res_nodes[id] as Node3D).queue_free()
			res_nodes.erase(id)

func collect_resource(id: int) -> void:
	collected[id] = true
	if res_nodes.has(id):
		(res_nodes[id] as Node3D).queue_free()
		res_nodes.erase(id)
	for i in current_res.size():
		if current_res[i]["id"] == id:
			current_res.remove_at(i)
			break

func set_atmo_params(sun_dir: Vector3, fade: float) -> void:
	if atmo_mat:
		atmo_mat.set_shader_parameter("sun_dir", sun_dir)
		atmo_mat.set_shader_parameter("fade", fade)

func ground_r(dir_local: Vector3) -> float:
	if gas:
		return R
	return gen.ground_radius(dir_local)

func surface_up_h(dir_local: Vector3) -> float:
	return gen.height(dir_local)

func set_fog(on: bool) -> void:
	if gas or terrain_mat == null or on == fogged:
		return
	fogged = on
	terrain_mat.shader = fog_shader if on else nofog_shader
	terrain_mat.set_shader_parameter("detail", get_detail_tex())
