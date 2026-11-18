class_name Planet
extends Node3D
## One planet / moon / gas giant in the scene: terrain LOD sphere, atmosphere shell, clouds, ocean, rings.

var data: BodyData
var gen: TerrainGen
var terrain: TerrainSphere
var atmo_mi: MeshInstance3D
var atmo_mat: ShaderMaterial
var cloud_mi: MeshInstance3D
var cloud_mat: ShaderMaterial
var ring_mi: MeshInstance3D
var ring_mat: ShaderMaterial
var gas_mi: MeshInstance3D
var gas_mat: ShaderMaterial
var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial
var outposts_root: Node3D
var props: SpaceProps
var layer_bit: int = 2
var body_index: int = 0

var atmo_on: bool = false
var atmo_r: float = 0.0
var h_r: float = 200.0
var _lod_timer: float = 0.0
var _outpost_timer: float = 0.0
var _outposts_built: Dictionary = {}
var sun_dir_world: Vector3 = Vector3.UP
var sun_color: Color = Color.WHITE
var sun_power: float = 1.0
var lod_enabled: bool = true

func setup(b: BodyData, idx: int) -> void:
	data = b
	body_index = idx
	layer_bit = 1 << (idx + 1)
	name = b.name
	if b.kind == "gas":
		_setup_gas()
		_make_pois()
		return
	gen = TerrainGen.new(b)
	DetailTex.ensure()
	_make_materials()
	terrain = TerrainSphere.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(b, gen, terrain_mat, water_mat, layer_bit)
	_make_atmosphere()
	_make_clouds()
	outposts_root = Node3D.new()
	outposts_root.name = "Outposts"
	add_child(outposts_root)
	_make_pois()

func _make_pois() -> void:
	if data.pois.is_empty():
		return
	props = SpaceProps.new()
	add_child(props)
	props.setup(self, data.pois)

# ---------------------------------------------------------------------------------------------------------
func _make_materials() -> void:
	var prof: Dictionary = data.profile
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://shaders/terrain.gdshader")
	terrain_mat.set_shader_parameter("detail_nrm", DetailTex.nrm)
	terrain_mat.set_shader_parameter("detail_h", DetailTex.hgt)
	terrain_mat.set_shader_parameter("roughness_base", float(prof.get("roughness", 0.9)))
	terrain_mat.set_shader_parameter("sheen_rough", 0.12 if prof.get("ice", false) else 0.25)
	terrain_mat.set_shader_parameter("veg_blades", 1.0 if prof.get("ground", "") == "grass" else 0.0)
	terrain_mat.set_shader_parameter("ground_spec", 0.5 if prof.get("ice", false) else 0.3)
	if prof.has("lava_color"):
		terrain_mat.set_shader_parameter("emis_color", prof["lava_color"])
		terrain_mat.set_shader_parameter("emis_strength", 1.0)
		terrain_mat.set_shader_parameter("emis_flow", 1.0)
	elif prof.get("glow_veins", false):
		var vc: Color = prof.get("vein_color", Color(0.55, 1.0, 0.25) if data.biome == "toxic" else Color(0.35, 1.0, 0.25))
		terrain_mat.set_shader_parameter("emis_color", vc)
		terrain_mat.set_shader_parameter("emis_strength", 0.34)
		terrain_mat.set_shader_parameter("emis_flow", 0.3)
	water_mat = null
	var oc: Dictionary = prof.get("ocean", {})
	if oc.get("on", false):
		water_mat = ShaderMaterial.new()
		water_mat.shader = load("res://shaders/ocean.gdshader")
		water_mat.set_shader_parameter("wave_nrm", DetailTex.wave)
		water_mat.set_shader_parameter("shallow_color", oc["shallow"])
		water_mat.set_shader_parameter("deep_color", oc["deep"])
		water_mat.set_shader_parameter("foam_color", oc["foam"])
		var atm: Dictionary = prof.get("atm", {})
		water_mat.set_shader_parameter("sky_reflect", (atm.get("haze", Color(0.5, 0.7, 1.0)) as Color))
		if String(oc.get("kind", "water")) == "acid":
			water_mat.set_shader_parameter("emission_glow", 0.35)
			water_mat.set_shader_parameter("clarity", 0.12)
		water_mat.render_priority = 0

func _make_atmosphere() -> void:
	var atm: Dictionary = data.profile.get("atm", {})
	atmo_on = bool(atm.get("on", false)) and float(atm.get("thick", 0.0)) > 0.0
	if not atmo_on:
		return
	var thick: float = float(atm["thick"]) * data.radius
	atmo_r = data.radius + thick
	h_r = thick / 5.0
	var h_m: float = h_r * 0.45
	var ray: Vector3 = atm["rayleigh"]
	atmo_mat = ShaderMaterial.new()
	atmo_mat.shader = load("res://shaders/atmosphere.gdshader")
	atmo_mat.render_priority = 10
	atmo_mat.set_shader_parameter("planet_radius", data.radius)
	atmo_mat.set_shader_parameter("atmo_radius", atmo_r)
	atmo_mat.set_shader_parameter("beta_r", ray / h_r)
	atmo_mat.set_shader_parameter("beta_m", float(atm["mie"]) / h_m)
	atmo_mat.set_shader_parameter("h_r", h_r)
	atmo_mat.set_shader_parameter("h_m", h_m)
	atmo_mat.set_shader_parameter("mie_g", float(atm["mie_g"]))
	atmo_mat.set_shader_parameter("sun_intensity", 7.0)
	atmo_mat.set_shader_parameter("haze_tint", Color(1, 1, 1))
	atmo_mat.set_shader_parameter("inside_k", float(atm.get("sky_k", 7.0)))
	atmo_mat.set_shader_parameter("inside_sat", float(atm.get("sky_sat", 1.35)))
	atmo_mat.set_shader_parameter("inside_tint", atm.get("sky_tint", Vector3(1, 1, 1)))
	var sm := SphereMesh.new()
	sm.radius = atmo_r * 1.03
	sm.height = atmo_r * 2.06
	sm.radial_segments = 64
	sm.rings = 32
	atmo_mi = MeshInstance3D.new()
	atmo_mi.name = "Atmosphere"
	atmo_mi.mesh = sm
	atmo_mi.material_override = atmo_mat
	atmo_mi.layers = 1 << 19
	atmo_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	atmo_mi.extra_cull_margin = 16384.0
	add_child(atmo_mi)

func _make_clouds() -> void:
	var cl: Dictionary = data.profile.get("clouds", {})
	if float(cl.get("cover", 0.0)) <= 0.01:
		return
	cloud_mat = ShaderMaterial.new()
	cloud_mat.shader = load("res://shaders/clouds.gdshader")
	cloud_mat.render_priority = 1
	cloud_mat.set_shader_parameter("cloud_color", cl["color"])
	cloud_mat.set_shader_parameter("cover", float(cl["cover"]))
	cloud_mat.set_shader_parameter("speed", float(cl["speed"]))
	cloud_mat.set_shader_parameter("darkness", float(cl["dark"]))
	cloud_mat.set_shader_parameter("seed", float(data.seed_i % 97))
	cloud_mat.set_shader_parameter("freq", 4.0 + float(data.seed_i % 5))
	var atm: Dictionary = data.profile.get("atm", {})
	cloud_mat.set_shader_parameter("ambient_color", atm.get("ambient", Color(0.5, 0.6, 0.8)))
	var sm := SphereMesh.new()
	var cr: float = data.radius * (1.0 + float(cl["alt"]))
	sm.radius = cr
	sm.height = cr * 2.0
	sm.radial_segments = 96
	sm.rings = 48
	cloud_mi = MeshInstance3D.new()
	cloud_mi.name = "Clouds"
	cloud_mi.mesh = sm
	cloud_mi.material_override = cloud_mat
	cloud_mi.layers = 1 << 19
	cloud_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloud_mi)

# ---------------------------------------------------------------------------------------------------------
func _setup_gas() -> void:
	var gm: ShaderMaterial = ShaderMaterial.new()
	gm.shader = load("res://shaders/gas_giant.gdshader")
	gas_mat = gm
	var cols: Array = data.gas_colors
	gm.set_shader_parameter("col_a", cols[0])
	gm.set_shader_parameter("col_b", cols[1])
	gm.set_shader_parameter("col_c", cols[2])
	gm.set_shader_parameter("col_d", cols[3])
	gm.set_shader_parameter("seed", float(data.seed_i % 50))
	gm.set_shader_parameter("planet_radius", data.radius)
	var sm := SphereMesh.new()
	sm.radius = data.radius
	sm.height = data.radius * 2.0
	sm.radial_segments = 128
	sm.rings = 64
	gas_mi = MeshInstance3D.new()
	gas_mi.mesh = sm
	gas_mi.material_override = gm
	gas_mi.layers = 1 << 19
	gas_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gas_mi)
	# haze shell
	atmo_on = true
	atmo_r = data.radius * 1.045
	h_r = data.radius * 0.0085
	atmo_mat = ShaderMaterial.new()
	atmo_mat.shader = load("res://shaders/atmosphere.gdshader")
	atmo_mat.render_priority = 10
	atmo_mat.set_shader_parameter("planet_radius", data.radius)
	atmo_mat.set_shader_parameter("atmo_radius", atmo_r)
	var tint: Color = (cols[1] as Color)
	atmo_mat.set_shader_parameter("beta_r", Vector3(tint.r, tint.g, tint.b) * 0.5 / h_r + Vector3(0.0001, 0.0001, 0.0001))
	atmo_mat.set_shader_parameter("beta_m", 0.12 / (h_r * 0.5))
	atmo_mat.set_shader_parameter("h_r", h_r)
	atmo_mat.set_shader_parameter("h_m", h_r * 0.5)
	atmo_mat.set_shader_parameter("mie_g", 0.7)
	atmo_mat.set_shader_parameter("sun_intensity", 7.0)
	var asm := SphereMesh.new()
	asm.radius = atmo_r * 1.03
	asm.height = atmo_r * 2.06
	asm.radial_segments = 64
	asm.rings = 32
	atmo_mi = MeshInstance3D.new()
	atmo_mi.mesh = asm
	atmo_mi.material_override = atmo_mat
	atmo_mi.layers = 1 << 19
	atmo_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	atmo_mi.extra_cull_margin = 65536.0
	add_child(atmo_mi)
	if not data.rings.is_empty():
		_make_rings()

func _make_rings() -> void:
	var inner: float = float(data.rings["inner"])
	var outer: float = float(data.rings["outer"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg: int = 160
	for i in seg:
		var a0: float = float(i) / seg * TAU
		var a1: float = float(i + 1) / seg * TAU
		var p0 := Vector3(cos(a0) * inner, 0, sin(a0) * inner)
		var p1 := Vector3(cos(a0) * outer, 0, sin(a0) * outer)
		var p2 := Vector3(cos(a1) * inner, 0, sin(a1) * inner)
		var p3 := Vector3(cos(a1) * outer, 0, sin(a1) * outer)
		for p in [p0, p2, p1, p1, p2, p3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	ring_mat = ShaderMaterial.new()
	ring_mat.shader = load("res://shaders/ring.gdshader")
	ring_mat.set_shader_parameter("inner", inner)
	ring_mat.set_shader_parameter("outer", outer)
	ring_mat.set_shader_parameter("planet_radius", data.radius)
	ring_mat.set_shader_parameter("seed", float(data.seed_i % 30))
	var cols: Array = data.gas_colors
	ring_mat.set_shader_parameter("ring_color", (cols[1] as Color).lerp(Color(0.8, 0.75, 0.68), 0.5))
	ring_mi = MeshInstance3D.new()
	ring_mi.mesh = st.commit()
	ring_mi.material_override = ring_mat
	ring_mi.layers = 1 << 19
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_mi.rotation = Vector3(float(data.rings.get("tilt", 0.2)), 0.0, 0.0)
	ring_mi.extra_cull_margin = 65536.0
	add_child(ring_mi)

# ---------------------------------------------------------------------------------------------------------
## Called by SpaceWorld each frame with the sun direction (world space, planet -> star) and sun colour/power.
func set_sun(dir_world: Vector3, col: Color, power: float) -> void:
	sun_dir_world = dir_world
	sun_color = col
	sun_power = power
	if atmo_mat != null:
		atmo_mat.set_shader_parameter("sun_dir", dir_world)
		atmo_mat.set_shader_parameter("sun_color", col)
		atmo_mat.set_shader_parameter("sun_intensity", 7.0 * power)
	if cloud_mat != null:
		cloud_mat.set_shader_parameter("sun_dir", dir_world)
		cloud_mat.set_shader_parameter("sun_color", col)
	if gas_mat != null:
		gas_mat.set_shader_parameter("sun_dir", dir_world)
		gas_mat.set_shader_parameter("sun_color", Color(col.r, col.g, col.b) * power)
	if ring_mat != null:
		ring_mat.set_shader_parameter("sun_dir", dir_world)
		ring_mat.set_shader_parameter("sun_color", Color(col.r, col.g, col.b) * power)
	if water_mat != null:
		var atm: Dictionary = data.profile.get("atm", {})
		var haze: Color = atm.get("haze", Color(0.5, 0.7, 1.0))
		var up_world: Vector3 = Vector3.UP
		water_mat.set_shader_parameter("sky_reflect", Color(haze.r, haze.g, haze.b) * power * 0.55)

## Per-frame update: terrain job processing, LOD refresh, outposts.
func update_planet(delta: float, cam_world: Vector3, planet_active: bool, vel: Vector3 = Vector3.ZERO) -> void:
	if terrain == null:
		return
	terrain.process_jobs(4000 if planet_active else 2500)
	_lod_timer -= delta
	if _lod_timer <= 0.0 and lod_enabled:
		_lod_timer = 0.08 if planet_active else 0.4
		var cam_local: Vector3 = global_transform.affine_inverse() * cam_world
		var la: Vector3 = Vector3.ZERO
		if planet_active and vel.length() > 25.0:
			la = vel.limit_length(480.0) * 1.1
		terrain.idle_trim = not planet_active
		terrain.update_lod(cam_local, la)
		if planet_active:
			_outpost_timer -= 0.08
			if _outpost_timer <= 0.0:
				_outpost_timer = 0.6
				_update_outposts(cam_local)

func _update_outposts(cam_local: Vector3) -> void:
	for i in data.outposts.size():
		var o: Dictionary = data.outposts[i]
		var pos: Vector3 = (o["dir"] as Vector3) * (data.radius + float(o["flat_h"]))
		var d: float = cam_local.distance_to(pos)
		var built: bool = _outposts_built.has(i)
		if not built and d < 1400.0:
			var n: Node3D = Outposts.build(self, o, i)
			if n != null:
				outposts_root.add_child(n)
				_outposts_built[i] = n
		elif built and d > 2600.0:
			(_outposts_built[i] as Node).queue_free()
			_outposts_built.erase(i)

# ---------------------------------------------------------------------------------------------------------
func ground_height(dir: Vector3) -> float:
	if gen != null:
		return gen.height_exact(dir)
	return 0.0

## scanner: points of interest (outposts, resources) within `radius` metres of a planet-local position
func find_points_of_interest(local_pos: Vector3, radius: float) -> Array:
	var out: Array = []
	for i in data.outposts.size():
		var o: Dictionary = data.outposts[i]
		var p: Vector3 = (o["dir"] as Vector3) * (data.radius + float(o["flat_h"]))
		if p.distance_to(local_pos) < radius:
			var lbl: String = "Outpost"
			match String(o["kind"]):
				"beacon": lbl = "Signal beacon"
				"crash": lbl = "Crash site"
				"monolith": lbl = "Ancient monolith"
				"base": lbl = "Landing pad / outpost"
			out.append({"pos": p, "label": lbl, "kind": String(o["kind"])})
	if terrain != null:
		out.append_array(terrain.find_resources(local_pos, radius))
	return out

## small bump under landing pads so ship feet rest on the pad plate
func pad_bonus(local_pos: Vector3) -> float:
	var dn: Vector3 = local_pos.normalized()
	for o in data.outposts:
		if o["kind"] == "base":
			var od: Vector3 = o["dir"]
			if dn.dot(od) > 0.9999:
				if (dn - od).length() * data.radius < 8.2:
					return 0.12
	return 0.0

func surface_radius_at(dir: Vector3) -> float:
	return data.radius + ground_height(dir)

func altitude_of(local_pos: Vector3) -> float:
	var d: Vector3 = local_pos.normalized()
	return local_pos.length() - (data.radius + ground_height(d))

## relative air density 0..1 at a given height above the base sphere
func air_density(height_above_base: float) -> float:
	if not atmo_on or data.kind == "gas":
		return 0.0
	return exp(-maxf(height_above_base, 0.0) / h_r) * U.smooth(atmo_r - data.radius, atmo_r - data.radius - h_r, height_above_base)

func gravity_at(radius_from_center: float) -> float:
	var h: float = radius_from_center - data.radius
	var g0: float = data.gravity
	var top: float = maxf(data.atm_height, 800.0)
	if h <= top:
		return g0
	return g0 * U.smooth(top * 2.2, top, h)

func shutdown() -> void:
	if terrain != null:
		terrain.free_all()
