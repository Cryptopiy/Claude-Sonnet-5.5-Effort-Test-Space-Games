class_name AsteroidBelt
extends Body
## A ring of asteroids around the star (MultiMesh of three Blender rock models) with simple sphere collisions.

var belt_r := 415000.0
var rocks: Array = []                # [local pos Vector3, radius float]
var mmis: Array = []


func build(p_star: Body, r: float, seed: int, count := 420) -> void:
	kind = "belt"
	parent_body = p_star
	belt_r = r
	display_name = "Asteroid belt"
	radius = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var names := ["asteroid_a", "asteroid_b", "asteroid_c"]
	var groups := [[], [], []]
	for i in count:
		var ang := rng.randf() * TAU
		var rr := belt_r + rng.randfn(0.0, 9000.0)
		var pos := Vector3(cos(ang) * rr, rng.randfn(0.0, 1400.0), sin(ang) * rr)
		var sc := rng.randf_range(20.0, 150.0)
		if rng.randf() < 0.08:
			sc = rng.randf_range(180.0, 420.0)
		var bas := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.7, 1.1), sc))
		groups[i % 3].append(Transform3D(bas, pos))
		rocks.append([pos, sc * 0.95])
	for k in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ModelLib.mesh(names[k], {"asteroid": Color(0.42 + k * 0.04, 0.38, 0.34 - k * 0.03)})
		var arr: Array = groups[k]
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.extra_cull_margin = 50000.0
		mmi.custom_aabb = AABB(Vector3(-belt_r * 1.1, -6000, -belt_r * 1.1), Vector3(belt_r * 2.2, 12000, belt_r * 2.2))
		add_child(mmi)
		mmis.append(mmi)


func update_state(t: float) -> void:
	apos = DV.new(parent_body.apos.x, parent_body.apos.y, parent_body.apos.z)
	vel = Vector3.ZERO
	rot = Basis(Vector3.UP, t * 0.00035)


## push (xyz = system-frame direction, w = depth) if the point (absolute position) is inside an asteroid
func collide(p: DV, margin: float) -> Vector4:
	var rel := rot.transposed() * Vector3(p.x - apos.x, p.y - apos.y, p.z - apos.z)
	var rd := Vector2(rel.x, rel.z).length()
	if absf(rd - belt_r) > 40000.0 or absf(rel.y) > 12000.0:
		return Vector4(0, 0, 0, 0)
	for r in rocks:
		var d: Vector3 = rel - (r[0] as Vector3)
		var dl := d.length()
		var rr: float = float(r[1]) + margin
		if dl < rr:
			var n := rot * (d / maxf(dl, 0.001))
			return Vector4(n.x, n.y, n.z, rr - dl)
	return Vector4(0, 0, 0, 0)
