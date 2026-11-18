class_name Body
extends Node3D
## A planet / moon / gas giant. Terrain is a procedural cube-sphere (seeded), plus a high detail
## patch around the player. Everything is derived from d["seed"] so a planet is identical each visit.

const MODELS = {}
const FACES = [
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
	[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
]
const RES_NAMES = {"lush": "Carbon", "desert": "Sodium", "frozen": "Ferrite", "lava": "Pyrite", "toxic": "Nitrogen", "moon": "Silicate"}
const PATCH_N = 100
const PATCH_HALF = 125.0
const BASE_N = 128

var d: Dictionary
var key: String
var biome: Dictionary
var R: float
var landable := false
var gravity := 9.0
var atmo_h := 0.0
var noise: FastNoiseLite
var cnoise: FastNoiseLite
var dnoise: FastNoiseLite
var colnoise: FastNoiseLite
var flat_dir := Vector3.UP
var flat_h := 0.0
var cos_in := 1.0
var cos_out := 1.0
var axis := Vector3(0.15, 1, 0.1).normalized()
var sys_pos := Vector3.ZERO
var terrain_mat: ShaderMaterial
var patch_mat: ShaderMaterial
var base_mi: MeshInstance3D
var patch_mi: MeshInstance3D
var atmo_mi: MeshInstance3D
var cloud_mi: MeshInstance3D
var sea_mi: MeshInstance3D
var flora_built := false
var flora_root: Node3D
var fauna := []
var crystals := []
var pad_node: Node3D
var patch_dir := Vector3.ZERO
var patch_has := false
var thread: Thread
var patch_ready := false
var patch_arrays := []
var patch_pending_dir := Vector3.ZERO
var sea_level := -999.0
var day_phase := 0.0
var shell_scale := 1.0

func setup(data: Dictionary, models: Dictionary) -> void:
	d = data
	key = d["biome"]
	biome = Gal.BIOMES[key]
	R = d["radius"]
	landable = key != "gas"
	gravity = biome["grav"]
	name = d["name"]
	if key == "gas":
		_build_gas()
		return
	atmo_h = R * 0.4 if biome["atmo"] else 0.0
	sea_level = biome["sea"]
	noise = FastNoiseLite.new()
	noise.seed = d["seed"]
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	noise.frequency = 1.0
	if biome["shape"] == 2 or biome["shape"] == 1:
		noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED if biome["shape"] == 2 else FastNoiseLite.FRACTAL_FBM
	cnoise = FastNoiseLite.new()
	cnoise.seed = d["seed"] + 5
	cnoise.noise_type = FastNoiseLite.TYPE_CELLULAR
	cnoise.frequency = 1.0
	dnoise = FastNoiseLite.new()
	dnoise.seed = d["seed"] + 9
	dnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	dnoise.frequency = 0.07
	colnoise = FastNoiseLite.new()
	colnoise.seed = d["seed"] + 13
	colnoise.frequency = 9.0
	_choose_pad()
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://shaders/terrain.gdshader")
	patch_mat = ShaderMaterial.new()
	patch_mat.shader = load("res://shaders/terrain.gdshader")
	patch_mat.set_shader_parameter("sink_r1", -1000.0)
	base_mi = MeshInstance3D.new()
	add_child(base_mi)
	base_mi.mesh = _build_base()
	base_mi.material_override = terrain_mat
	patch_mi = MeshInstance3D.new()
	patch_mi.material_override = patch_mat
	add_child(patch_mi)
	if biome["atmo"]:
		var sh = ShaderMaterial.new()
		sh.shader = load("res://shaders/atmosphere.gdshader")
		var hz: Color = biome["horizon"]
		sh.set_shader_parameter("col", Color(hz.r * 0.6 + 0.1, hz.g * 0.6 + 0.15, hz.b * 0.8 + 0.2))
		atmo_mi = _sphere(R + atmo_h * 0.55, 64, sh)
		atmo_mi.name = "Atmosphere"
		add_child(atmo_mi)
	if biome["clouds"] > 0.0:
		var cm = ShaderMaterial.new()
		cm.shader = load("res://shaders/clouds.gdshader")
		cm.set_shader_parameter("cover", biome["clouds"])
		cm.set_shader_parameter("tint", biome["cloud_col"])
		cloud_mi = _sphere(R + 170.0, 64, cm)
		add_child(cloud_mi)
	if sea_level > -500.0:
		var m = StandardMaterial3D.new()
		var sc: Color = biome["sea_col"]
		m.albedo_color = sc
		m.roughness = 0.12
		m.metallic = 0.3
		if sc.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if biome["sea_emit"]:
			m.emission_enabled = true
			m.emission = Color(sc.r, sc.g, sc.b)
			m.emission_energy_multiplier = 1.6
		sea_mi = _sphere(R + sea_level, 96, m)
		add_child(sea_mi)
	_build_pad(models)

func _sphere(r: float, seg: int, mat: Material) -> MeshInstance3D:
	var s = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	var mi = MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _build_gas() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = d["seed"]
	var m = ShaderMaterial.new()
	m.shader = load("res://shaders/gasgiant.gdshader")
	var base = Color.from_hsv(rng.randf(), 0.45, 0.85)
	m.set_shader_parameter("c1", base)
	m.set_shader_parameter("c2", Color.from_hsv(fmod(base.h + 0.06, 1.0), 0.6, 0.6))
	m.set_shader_parameter("c3", Color.from_hsv(fmod(base.h + 0.5, 1.0), 0.15, 0.95))
	m.set_shader_parameter("seed", rng.randf() * 10.0)
	var mi = _sphere(R, 96, m)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	var am = ShaderMaterial.new()
	am.shader = load("res://shaders/atmosphere.gdshader")
	am.set_shader_parameter("col", base.lightened(0.3))
	am.set_shader_parameter("intensity", 1.2)
	atmo_mi = _sphere(R * 1.04, 64, am)
	add_child(atmo_mi)
	var ring = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(R * 5.0, R * 5.0)
	ring.mesh = pm
	var rm = ShaderMaterial.new()
	rm.shader = load("res://shaders/ring.gdshader")
	rm.set_shader_parameter("col", base.lightened(0.2))
	rm.set_shader_parameter("inner", 0.44)
	ring.material_override = rm
	ring.rotation = Vector3(0.35, 0, 0.2)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

# ---------- terrain function ----------
func shape_h(dir: Vector3) -> float:
	var a: float = biome["amp"]
	var n = noise.get_noise_3d(dir.x * 3.0, dir.y * 3.0, dir.z * 3.0)
	match biome["shape"]:
		0: return n * a
		1: return (1.0 - absf(noise.get_noise_3d(dir.x * 5.0, dir.y * 3.0, dir.z * 5.0))) * a - a * 0.4
		2: return pow(maxf(0.0, n * 0.5 + 0.5), 2.0) * a * 1.6 - a * 0.3
		3: return (roundf(n * 3.0) / 3.0 * 0.7 + n * 0.3) * a
		4:
			var c = cnoise.get_noise_3d(dir.x * 7.0, dir.y * 7.0, dir.z * 7.0)
			return (c * 0.7 + n * 0.35) * a
		_: return (n * 0.8 + noise.get_noise_3d(dir.x * 11.0, dir.y * 11.0, dir.z * 11.0) * 0.2) * a
	return 0.0

func height(dir: Vector3, detail: bool = true, fade: float = 1.0) -> float:
	var h = shape_h(dir)
	if detail:
		h += dnoise.get_noise_3d(dir.x * R, dir.y * R, dir.z * R) * 0.9 * fade
	var t = clampf((dir.dot(flat_dir) - cos_out) / (cos_in - cos_out), 0.0, 1.0)
	if t > 0.0:
		t = t * t * (3.0 - 2.0 * t)
		h = lerpf(h, flat_h, t)
	return h

func ground_radius(local_pos: Vector3) -> float:
	return R + height(local_pos.normalized(), true)

func _choose_pad() -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = d["seed"] + 77
	var best = 1e9
	var best_dir = Vector3.UP
	cos_in = 1.0
	cos_out = 0.5
	flat_h = 0.0
	for i in range(80):
		var v = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var h = shape_h(v)
		if sea_level > -500.0 and h < sea_level + 5.0:
			continue
		if absf(v.y) > 0.8:
			continue
		var var_ = 0.0
		var tg = v.cross(Vector3.UP).normalized()
		var tg2 = v.cross(tg)
		for off in [tg * 130.0 / R, -tg * 130.0 / R, tg2 * 130.0 / R, -tg2 * 130.0 / R]:
			var_ += absf(shape_h((v + off).normalized()) - h)
		if var_ < best:
			best = var_
			best_dir = v
	flat_dir = best_dir
	flat_h = shape_h(flat_dir)
	if sea_level > -500.0:
		flat_h = maxf(flat_h, sea_level + 4.0)
	cos_in = cos(60.0 / R)
	cos_out = cos(150.0 / R)

func pad_world_pos() -> Vector3:
	return flat_dir * (R + flat_h)

func tangent_of(dir: Vector3) -> Vector3:
	var ref_ = Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	return dir.cross(ref_).normalized()

func align_up(dir: Vector3, yaw: float) -> Basis:
	var t = tangent_of(dir)
	var b = Basis(t, dir, t.cross(dir))
	return b * Basis(Vector3.UP, yaw)

# ---------- color ----------
func _color(h: float, slope: float, dir: Vector3) -> Color:
	var a: float = biome["amp"]
	var t = clampf((h + a) / (2.0 * a), 0.0, 1.0)
	var c: Color = biome["low"].lerp(biome["mid"], smoothstep(0.25, 0.5, t)).lerp(biome["high"], smoothstep(0.6, 0.92, t))
	if sea_level > -500.0 and h < sea_level + 2.5:
		c = biome["shore"]
	c = c.lerp(biome["slope"], smoothstep(0.03, 0.14, slope))
	var v = 0.9 + 0.2 * colnoise.get_noise_3d(dir.x * 40.0, dir.y * 40.0, dir.z * 40.0)
	if key == "frozen":
		v = 0.95 + 0.1 * v
	return Color(c.r * v, c.g * v, c.b * v)

func _mesh_arrays(dirs: PackedVector3Array, hs: PackedFloat32Array, n: int) -> Array:
	var w = n + 3
	var P = PackedVector3Array()
	P.resize(w * w)
	for i in range(w * w):
		P[i] = dirs[i] * (R + hs[i])
	var m = n + 1
	var verts = PackedVector3Array()
	var norms = PackedVector3Array()
	var cols = PackedColorArray()
	verts.resize(m * m)
	norms.resize(m * m)
	cols.resize(m * m)
	var q = 0
	for j in range(1, n + 2):
		for i in range(1, n + 2):
			var k = j * w + i
			var nr = (P[k + 1] - P[k - 1]).cross(P[k + w] - P[k - w]).normalized()
			if nr.dot(dirs[k]) < 0.0:
				nr = -nr
			verts[q] = P[k]
			norms[q] = nr
			cols[q] = _color(hs[k], 1.0 - nr.dot(dirs[k]), dirs[k])
			q += 1
	var idx = PackedInt32Array()
	idx.resize(n * n * 6)
	var flip = false
	var fc = (verts[1] - verts[0]).cross(verts[m] - verts[0])
	if fc.dot(dirs[w + 1]) > 0.0:
		flip = true
	var o = 0
	for j in range(n):
		for i in range(n):
			var a = j * m + i
			var b = a + 1
			var c = a + m
			var dd = c + 1
			if flip:
				idx[o] = a; idx[o + 1] = c; idx[o + 2] = b
				idx[o + 3] = b; idx[o + 4] = c; idx[o + 5] = dd
			else:
				idx[o] = a; idx[o + 1] = b; idx[o + 2] = c
				idx[o + 3] = b; idx[o + 4] = dd; idx[o + 5] = c
			o += 6
	var arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	return arr

func _build_base() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var n = BASE_N
	var w = n + 3
	for f in FACES:
		var dirs = PackedVector3Array()
		var hs = PackedFloat32Array()
		dirs.resize(w * w)
		hs.resize(w * w)
		var o = 0
		for j in range(w):
			var v = (float(j - 1) / n) * 2.0 - 1.0
			for i in range(w):
				var u = (float(i - 1) / n) * 2.0 - 1.0
				# tan warp gives a more even cube-sphere
				var dir = (f[0] + f[1] * tan(u * 0.7854) + f[2] * tan(v * 0.7854)).normalized()
				dirs[o] = dir
				hs[o] = height(dir, false) - 0.8
				o += 1
		var arr = _mesh_arrays(dirs, hs, n)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

# ---------- detail patch ----------
func _gen_patch(dir: Vector3) -> void:
	var t1 = tangent_of(dir)
	var t2 = dir.cross(t1)
	var n = PATCH_N
	var w = n + 3
	var sp = PATCH_HALF * 2.0 / n
	var dirs = PackedVector3Array()
	var hs = PackedFloat32Array()
	dirs.resize(w * w)
	hs.resize(w * w)
	var o = 0
	for j in range(w):
		var v = (j - 1 - n * 0.5) * sp
		for i in range(w):
			var u = (i - 1 - n * 0.5) * sp
			var dr = (dir * R + t1 * u + t2 * v).normalized()
			var rn = maxf(absf(u), absf(v)) / PATCH_HALF
			var fade = 1.0 - smoothstep(0.7, 1.0, rn)
			dirs[o] = dr
			hs[o] = height(dr, true, 1.0) * 1.0 - 0.8 * smoothstep(0.82, 1.0, rn) - (0.0)
			if fade < 1.0:
				hs[o] = height(dr, true, fade) - 0.8 * smoothstep(0.82, 1.0, rn)
			o += 1
	patch_arrays = _mesh_arrays(dirs, hs, n)
	patch_ready = true

func build_patch_sync(dir: Vector3) -> void:
	_gen_patch(dir)
	_apply_patch(dir)

func _apply_patch(dir: Vector3) -> void:
	var m = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, patch_arrays)
	patch_mi.mesh = m
	patch_dir = dir
	patch_has = true
	patch_ready = false

func update_patch(local_pos: Vector3) -> void:
	if not landable:
		return
	if thread != null and patch_ready:
		thread.wait_to_finish()
		thread = null
		_apply_patch(patch_pending_dir)
	if thread != null:
		return
	var dir = local_pos.normalized()
	var need = not patch_has
	if patch_has:
		var ang = acos(clampf(dir.dot(patch_dir), -1.0, 1.0)) * R
		need = ang > 45.0
	if need:
		patch_pending_dir = dir
		thread = Thread.new()
		thread.start(_gen_patch.bind(dir))

func drop_patch() -> void:
	if thread != null:
		thread.wait_to_finish()
		thread = null
	patch_has = false
	patch_ready = false
	if patch_mi:
		patch_mi.mesh = null

# ---------- structures / props ----------
func _build_pad(models: Dictionary) -> void:
	pad_node = Node3D.new()
	add_child(pad_node)
	var p = pad_world_pos()
	var pad = models["landing_pad"].instantiate()
	pad.position = p + flat_dir * 0.05
	pad.basis = align_up(flat_dir, 0.0)
	pad_node.add_child(pad)
	var t = tangent_of(flat_dir)
	var od = (flat_dir * R + t * 38.0).normalized()
	var op = models["outpost"].instantiate()
	op.basis = align_up(od, 0.7) * Basis.from_scale(Vector3.ONE * 2.6)
	op.position = od * (R + height(od, true) - 0.3)
	pad_node.add_child(op)
	# beacon light so the pad is visible from the air
	var beacon = OmniLight3D.new()
	beacon.light_color = Color(0.4, 0.8, 1.0)
	beacon.omni_range = 40.0
	beacon.light_energy = 1.2
	beacon.position = p + flat_dir * 6.0
	pad_node.add_child(beacon)
	var bm = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.4
	cm.height = 300.0
	bm.mesh = cm
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.8, 1.0, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.material_override = mat
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bm.basis = align_up(flat_dir, 0.0)
	bm.position = p + flat_dir * 150.0
	pad_node.add_child(bm)

func _first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D:
		return n.mesh
	for c in n.get_children():
		var m = _first_mesh(c)
		if m:
			return m
	return null

func _tint_material() -> StandardMaterial3D:
	var tints = {"lush": Color(0.4, 1.0, 0.8), "desert": Color(1.0, 0.7, 0.2), "frozen": Color(0.6, 0.9, 1.0), "lava": Color(1.0, 0.4, 0.1), "toxic": Color(0.5, 1.0, 0.2), "moon": Color(0.9, 0.9, 1.0)}
	var m = StandardMaterial3D.new()
	var c: Color = tints[key]
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.9
	m.roughness = 0.2
	m.metallic = 0.2
	return m

func build_flora(models: Dictionary) -> void:
	if flora_built:
		flora_root.visible = true
		return
	flora_built = true
	flora_root = Node3D.new()
	add_child(flora_root)
	var rng = RandomNumberGenerator.new()
	rng.seed = d["seed"] + 4242
	var tint = _tint_material()
	for spec in biome["props"]:
		var mesh: Mesh = _first_mesh(models[spec[0]].instantiate())
		var count: int = spec[1]
		var xf = []
		var tries = 0
		while xf.size() < count and tries < count * 4:
			tries += 1
			var v = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			if v.dot(flat_dir) > cos(110.0 / R):
				continue
			var h = height(v, true)
			if sea_level > -500.0 and h < sea_level + 3.0:
				continue
			var s = rng.randf_range(spec[2], spec[3])
			var b = align_up(v, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s)
			xf.append(Transform3D(b, v * (R + h - 0.5)))
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xf.size()
		for i in range(xf.size()):
			mm.set_instance_transform(i, xf[i])
		var mmi = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if spec[0] == "crystal":
			mmi.material_override = tint
		flora_root.add_child(mmi)
	# fauna
	for i in range(biome["fauna"]):
		var v2 = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var j = models["jelly"].instantiate()
		var h2 = height(v2, true)
		if sea_level > -500.0 and h2 < sea_level:
			h2 = sea_level
		j.set_meta("home", v2 * (R + h2 + rng.randf_range(4.0, 14.0)))
		j.set_meta("ph", rng.randf() * TAU)
		j.position = j.get_meta("home")
		j.basis = align_up(v2, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * rng.randf_range(1.5, 3.0))
		flora_root.add_child(j)
		fauna.append(j)
	# collectible resource crystals around the pad
	for i in range(28):
		var ang = rng.randf() * TAU
		var dist = rng.randf_range(25.0, 330.0)
		var t = tangent_of(flat_dir)
		var v3 = (flat_dir * R + (t * cos(ang) + flat_dir.cross(t) * sin(ang)) * dist).normalized()
		var h3 = height(v3, true)
		if sea_level > -500.0 and h3 < sea_level + 1.0:
			continue
		var cr = models["crystal"].instantiate()
		cr.basis = align_up(v3, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * 0.8)
		cr.position = v3 * (R + h3 - 0.2)
		for m in cr.find_children("*", "MeshInstance3D", true, false):
			m.material_override = tint
		flora_root.add_child(cr)
		crystals.append(cr)

func hide_flora() -> void:
	if flora_built:
		flora_root.visible = false

func animate_fauna(t: float) -> void:
	for j in fauna:
		var hm: Vector3 = j.get_meta("home")
		var up = hm.normalized()
		j.position = hm + up * sin(t * 0.8 + j.get_meta("ph")) * 2.5 + tangent_of(up) * cos(t * 0.4 + j.get_meta("ph")) * 4.0

func nearest_crystal(local_pos: Vector3) -> Node3D:
	var best: Node3D = null
	var bd = 1e9
	for c in crystals:
		if c.visible:
			var dd = c.position.distance_to(local_pos)
			if dd < bd:
				bd = dd
				best = c
	return best

func resource_name() -> String:
	return RES_NAMES.get(key, "Ore")
