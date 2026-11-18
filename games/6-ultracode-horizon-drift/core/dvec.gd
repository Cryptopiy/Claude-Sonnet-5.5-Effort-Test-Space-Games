class_name DVec
extends RefCounted
## Double-precision 3-vector. GDScript `float` is 64-bit but `Vector3` is 32-bit, so absolute star-system
## coordinates (millions of metres) are kept in DVec and only converted to Vector3 *relative to the local frame*
## (see autoload/frame.gd). Never store absolute positions in Vector3.

var x: float = 0.0
var y: float = 0.0
var z: float = 0.0

func _init(px: float = 0.0, py: float = 0.0, pz: float = 0.0) -> void:
	x = px
	y = py
	z = pz

static func from_v3(v: Vector3) -> DVec:
	return DVec.new(v.x, v.y, v.z)

func to_v3() -> Vector3:
	return Vector3(x, y, z)

func copy() -> DVec:
	return DVec.new(x, y, z)

func assign(o: DVec) -> void:
	x = o.x
	y = o.y
	z = o.z

func add(o: DVec) -> DVec:
	return DVec.new(x + o.x, y + o.y, z + o.z)

func sub(o: DVec) -> DVec:
	return DVec.new(x - o.x, y - o.y, z - o.z)

func add_v3(v: Vector3) -> DVec:
	return DVec.new(x + v.x, y + v.y, z + v.z)

func sub_v3(v: Vector3) -> DVec:
	return DVec.new(x - v.x, y - v.y, z - v.z)

func scaled(s: float) -> DVec:
	return DVec.new(x * s, y * s, z * s)

func dot(o: DVec) -> float:
	return x * o.x + y * o.y + z * o.z

func length_squared() -> float:
	return x * x + y * y + z * z

func length() -> float:
	return sqrt(x * x + y * y + z * z)

func distance_to(o: DVec) -> float:
	var dx := x - o.x
	var dy := y - o.y
	var dz := z - o.z
	return sqrt(dx * dx + dy * dy + dz * dz)

## (o - self) as a float32 Vector3 (precise because the subtraction is done in double).
func offset_to_v3(o: DVec) -> Vector3:
	return Vector3(o.x - x, o.y - y, o.z - z)

## unit direction from self to o as Vector3
func dir_to_v3(o: DVec) -> Vector3:
	var v := Vector3(o.x - x, o.y - y, o.z - z)
	return v.normalized()

func lerp_to(o: DVec, t: float) -> DVec:
	return DVec.new(x + (o.x - x) * t, y + (o.y - y) * t, z + (o.z - z) * t)

func _to_string() -> String:
	return "DVec(%.3f, %.3f, %.3f)" % [x, y, z]
