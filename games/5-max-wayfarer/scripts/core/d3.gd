class_name D3
extends RefCounted
## Minimal double-precision 3-vector (GDScript floats are 64-bit, Vector3 is 32-bit).
## Used for true system-space positions so that floating-origin math stays exact over hundreds of km.

var x: float = 0.0
var y: float = 0.0
var z: float = 0.0

func _init(px: float = 0.0, py: float = 0.0, pz: float = 0.0) -> void:
	x = px
	y = py
	z = pz

static func of(v: Vector3) -> D3:
	return D3.new(v.x, v.y, v.z)

func copy() -> D3:
	return D3.new(x, y, z)

func set_to(o: D3) -> D3:
	x = o.x
	y = o.y
	z = o.z
	return self

func to_v3() -> Vector3:
	return Vector3(x, y, z)

func plus(o: D3) -> D3:
	return D3.new(x + o.x, y + o.y, z + o.z)

func minus(o: D3) -> D3:
	return D3.new(x - o.x, y - o.y, z - o.z)

func plus_v(v: Vector3) -> D3:
	return D3.new(x + v.x, y + v.y, z + v.z)

func minus_v(v: Vector3) -> D3:
	return D3.new(x - v.x, y - v.y, z - v.z)

func times(s: float) -> D3:
	return D3.new(x * s, y * s, z * s)

## in-place add of a float vector
func add_v(v: Vector3) -> D3:
	x += v.x
	y += v.y
	z += v.z
	return self

func add_scaled(v: Vector3, s: float) -> D3:
	x += v.x * s
	y += v.y * s
	z += v.z * s
	return self

func length() -> float:
	return sqrt(x * x + y * y + z * z)

func length_sq() -> float:
	return x * x + y * y + z * z

## (self - o) as float32 vector: exact subtraction in double precision first
func rel(o: D3) -> Vector3:
	return Vector3(x - o.x, y - o.y, z - o.z)

func dist(o: D3) -> float:
	var dx: float = x - o.x
	var dy: float = y - o.y
	var dz: float = z - o.z
	return sqrt(dx * dx + dy * dy + dz * dz)

func _to_string() -> String:
	return "D3(%.2f, %.2f, %.2f)" % [x, y, z]
