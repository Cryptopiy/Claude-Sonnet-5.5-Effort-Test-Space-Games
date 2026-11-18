class_name GasGiant
extends Node3D
## GAS GIANT visual (module M2). Not landable. Transform is set by Frame (and is a rotating frame when anchored on it).
##   * cloud tops : full-screen quad (shaders/gas_giant.gdshader) that ray-traces the sphere analytically: zonal bands, vortex storms, polar caps, terminator,
##                  ring shadow. Perfect limb at any distance, writes real depth.
##   * rings      : planar annulus mesh (shaders/ring.gdshader) in the equatorial plane (planet-space), with the planet's shadow across it.
##   * haze / limb: AtmosphereEffect with the "gas" profile (limb glow, thick coloured haze while diving into the cloud tops).
## pressure_depth(p) -> 0..1 is the "crushing pressure" query used by the ship.

const PALETTES := [
	# jovian cream / orange / brown
	{"c": [Color(0.93, 0.85, 0.70), Color(0.86, 0.55, 0.30), Color(0.52, 0.34, 0.24), Color(0.97, 0.94, 0.86), Color(0.42, 0.52, 0.70)],
		"storm": Color(0.78, 0.26, 0.16), "pole": Color(0.40, 0.40, 0.46), "ring_a": Color(0.82, 0.72, 0.56), "ring_b": Color(0.46, 0.40, 0.34)},
	# neptune blue
	{"c": [Color(0.62, 0.80, 0.97), Color(0.28, 0.50, 0.90), Color(0.10, 0.22, 0.58), Color(0.88, 0.95, 1.0), Color(0.20, 0.58, 0.68)],
		"storm": Color(0.07, 0.12, 0.42), "pole": Color(0.30, 0.50, 0.75), "ring_a": Color(0.62, 0.74, 0.88), "ring_b": Color(0.34, 0.40, 0.52)},
	# saturn gold
	{"c": [Color(0.96, 0.88, 0.64), Color(0.82, 0.64, 0.36), Color(0.58, 0.44, 0.28), Color(0.99, 0.95, 0.82), Color(0.70, 0.62, 0.48)],
		"storm": Color(0.68, 0.40, 0.20), "pole": Color(0.45, 0.50, 0.55), "ring_a": Color(0.86, 0.76, 0.56), "ring_b": Color(0.52, 0.44, 0.34)},
	# violet / magenta
	{"c": [Color(0.90, 0.78, 0.92), Color(0.74, 0.42, 0.72), Color(0.40, 0.22, 0.48), Color(0.98, 0.90, 0.98), Color(0.34, 0.42, 0.75)],
		"storm": Color(0.95, 0.35, 0.55), "pole": Color(0.30, 0.28, 0.45), "ring_a": Color(0.80, 0.68, 0.82), "ring_b": Color(0.44, 0.36, 0.50)},
	# teal / jade
	{"c": [Color(0.78, 0.94, 0.86), Color(0.30, 0.72, 0.62), Color(0.12, 0.38, 0.40), Color(0.94, 1.0, 0.94), Color(0.24, 0.46, 0.66)],
		"storm": Color(0.90, 0.60, 0.20), "pole": Color(0.25, 0.42, 0.48), "ring_a": Color(0.70, 0.84, 0.78), "ring_b": Color(0.36, 0.46, 0.44)},
]

var def: BodyDef
var system: SystemDef
var _mat: ShaderMaterial
var _quad: MeshInstance3D
var _ring: MeshInstance3D
var _ring_mat: ShaderMaterial
var _atmo: AtmosphereEffect

func setup(p_def: BodyDef, p_sys: SystemDef) -> void:
	def = p_def
	system = p_sys

func _ready() -> void:
	if def == null:
		return
	var s := def.palette_seed if def.palette_seed != 0 else def.seed
	var pal: Dictionary = PALETTES[int(SeedUtil.rand01(s, 70) * float(PALETTES.size())) % PALETTES.size()]
	var cols: Array = pal["c"]

	# --- cloud tops --------------------------------------------------------------------------------------------------------------------------------
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/gas_giant.gdshader") as Shader
	_mat.render_priority = 0
	_mat.set_shader_parameter("planet_r", def.radius)
	_mat.set_shader_parameter("ring_in", def.ring_inner if def.has_rings else 0.0)
	_mat.set_shader_parameter("ring_out", def.ring_outer if def.has_rings else 0.0)
	for i in 5:
		var c: Color = cols[i]
		_mat.set_shader_parameter("c%d" % i, Vector3(c.r, c.g, c.b))
	var sc: Color = pal["storm"]
	var pc: Color = pal["pole"]
	_mat.set_shader_parameter("storm_col", Vector3(sc.r, sc.g, sc.b))
	_mat.set_shader_parameter("pole_col", Vector3(pc.r, pc.g, pc.b))
	_mat.set_shader_parameter("seed", SeedUtil.rand01(s, 71) * 20.0 + 1.0)
	_mat.set_shader_parameter("band_freq", 5.0 + SeedUtil.rand01(s, 72) * 5.0)
	_mat.set_shader_parameter("turb", 0.8 + SeedUtil.rand01(s, 73) * 0.6)
	_mat.set_shader_parameter("storm0", SeedUtil.rand_dir(s, 74) * Vector3(1, 0.35, 1))
	_mat.set_shader_parameter("storm0_r", 0.12 + SeedUtil.rand01(s, 75) * 0.08)
	_mat.set_shader_parameter("storm1", SeedUtil.rand_dir(s, 76) * Vector3(1, 0.6, 1))
	_mat.set_shader_parameter("storm1_r", 0.05 + SeedUtil.rand01(s, 77) * 0.04)
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	_quad = MeshInstance3D.new()
	_quad.name = "CloudTops"
	_quad.mesh = q
	_quad.material_override = _mat
	_quad.custom_aabb = AABB(Vector3(-1.0e7, -1.0e7, -1.0e7), Vector3(2.0e7, 2.0e7, 2.0e7))
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.ignore_occlusion_culling = true
	add_child(_quad)

	# --- rings ----------------------------------------------------------------------------------------------------------------------------------------
	if def.has_rings and def.ring_outer > def.ring_inner:
		_ring_mat = ShaderMaterial.new()
		_ring_mat.shader = load("res://shaders/ring.gdshader") as Shader
		_ring_mat.render_priority = 1
		_ring_mat.set_shader_parameter("ring_in", def.ring_inner)
		_ring_mat.set_shader_parameter("ring_out", def.ring_outer)
		_ring_mat.set_shader_parameter("planet_r", def.radius)
		var ra: Color = pal["ring_a"]
		var rb: Color = pal["ring_b"]
		_ring_mat.set_shader_parameter("col_a", Vector3(ra.r, ra.g, ra.b))
		_ring_mat.set_shader_parameter("col_b", Vector3(rb.r, rb.g, rb.b))
		_ring_mat.set_shader_parameter("seed", SeedUtil.rand01(s, 78) * 10.0 + 1.0)
		_ring = MeshInstance3D.new()
		_ring.name = "Rings"
		_ring.mesh = _build_ring_mesh(def.ring_inner * 0.99, def.ring_outer * 1.01, 192)
		_ring.material_override = _ring_mat
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ring)

	# --- limb glow / haze -------------------------------------------------------------------------------------------------------------------------------
	_atmo = AtmosphereEffect.new()
	_atmo.name = "Atmosphere"
	_atmo.setup(self, def)
	add_child(_atmo)

func _build_ring_mesh(r_in: float, r_out: float, segs: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	# a few radial subdivisions so the polygonal outline stays circular and depth sorting stays stable
	var rings_n := 4
	for r in rings_n + 1:
		var rr := lerpf(r_in, r_out, float(r) / float(rings_n))
		for i in segs:
			var a := TAU * float(i) / float(segs)
			verts.append(Vector3(cos(a) * rr, 0.0, sin(a) * rr))
			norms.append(Vector3.UP)
	for r in rings_n:
		for i in segs:
			var i2 := (i + 1) % segs
			var a0 := r * segs + i
			var a1 := r * segs + i2
			var b0 := (r + 1) * segs + i
			var b1 := (r + 1) * segs + i2
			idx.append_array([a0, b0, a1, a1, b0, b1])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.custom_aabb = AABB(Vector3(-r_out, -50.0, -r_out), Vector3(r_out * 2.0, 100.0, r_out * 2.0))
	return m

## 0 above the cloud tops .. 1 deep inside (ship refuses to go deeper than ~0.5)
func pressure_depth(p: Vector3) -> float:
	return clampf((def.radius - p.length()) / (def.radius * 0.2) + 1.0, 0.0, 1.0) if p.length() < def.radius * 1.02 else 0.0
