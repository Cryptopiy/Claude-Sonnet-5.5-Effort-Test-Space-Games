class_name DV
extends RefCounted
## Double-precision 3-vector (GDScript floats are 64-bit, Vector3 is 32-bit). Used for absolute
## positions in star-system space so the floating-origin subtraction is exact.

var x := 0.0
var y := 0.0
var z := 0.0


func _init(px := 0.0, py := 0.0, pz := 0.0) -> void:
	x = px
	y = py
	z = pz


static func from_v3(v: Vector3) -> DV:
	return DV.new(v.x, v.y, v.z)


func copy() -> DV:
	return DV.new(x, y, z)


func set_dv(o: DV) -> void:
	x = o.x
	y = o.y
	z = o.z


func plus(v: Vector3) -> DV:
	return DV.new(x + v.x, y + v.y, z + v.z)


func add_in_place(v: Vector3) -> void:
	x += v.x
	y += v.y
	z += v.z


func plus_dv(o: DV) -> DV:
	return DV.new(x + o.x, y + o.y, z + o.z)


## (self - other) computed in double precision, returned as float32 vector
func minus(o: DV) -> Vector3:
	return Vector3(x - o.x, y - o.y, z - o.z)


func dist(o: DV) -> float:
	var dx := x - o.x
	var dy := y - o.y
	var dz := z - o.z
	return sqrt(dx * dx + dy * dy + dz * dz)


func length() -> float:
	return sqrt(x * x + y * y + z * z)


func to_v3() -> Vector3:
	return Vector3(x, y, z)
