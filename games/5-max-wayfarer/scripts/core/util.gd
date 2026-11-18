class_name U
extends RefCounted
## Static helpers: integer hashing, seeded random, naming, easing and colour utilities.

const TAU_D: float = 6.283185307179586
const PI_D: float = 3.141592653589793

static func hash_u32(v: int) -> int:
	var x: int = v & 0xFFFFFFFF
	x ^= x >> 16
	x = (x * 0x7feb352d) & 0xFFFFFFFF
	x ^= x >> 15
	x = (x * 0x846ca68b) & 0xFFFFFFFF
	x ^= x >> 16
	return x

static func hash2(a: int, b: int) -> int:
	return hash_u32(hash_u32(a) ^ ((b * 0x9E3779B1) & 0xFFFFFFFF) ^ 0x85EBCA6B)

static func hash3(a: int, b: int, c: int) -> int:
	return hash2(hash2(a, b), c)

static func hash_str(s: String) -> int:
	return hash_u32(s.hash())

## 0..1 float from an integer
static func hf(v: int) -> float:
	return float(hash_u32(v)) / 4294967295.0

static func hf2(a: int, b: int) -> float:
	return float(hash2(a, b)) / 4294967295.0

static func rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash_u32(seed_value) + 1
	return r

static func smooth(e0: float, e1: float, x: float) -> float:
	var t: float = clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func remap(v: float, a0: float, a1: float, b0: float, b1: float) -> float:
	return b0 + (b1 - b0) * ((v - a0) / (a1 - a0))

static func damp(current: float, target: float, rate: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-rate * delta))

static func damp_v3(current: Vector3, target: Vector3, rate: float, delta: float) -> Vector3:
	return current.lerp(target, 1.0 - exp(-rate * delta))

## Random unit vector from three uniform numbers
static func unit_from(a: float, b: float) -> Vector3:
	var z: float = a * 2.0 - 1.0
	var t: float = b * TAU_D
	var r: float = sqrt(maxf(0.0, 1.0 - z * z))
	return Vector3(r * cos(t), z, r * sin(t))

static func rand_unit(r: RandomNumberGenerator) -> Vector3:
	return unit_from(r.randf(), r.randf())

## Any vector perpendicular to v
static func any_perp(v: Vector3) -> Vector3:
	var a: Vector3 = Vector3.UP if absf(v.y) < 0.95 else Vector3.RIGHT
	return v.cross(a).normalized()

## Basis whose Y axis is `up`, with some stable forward
static func basis_from_up(up: Vector3, fwd_hint: Vector3 = Vector3.FORWARD) -> Basis:
	var u: Vector3 = up.normalized()
	var f: Vector3 = fwd_hint - u * fwd_hint.dot(u)
	if f.length_squared() < 1e-6:
		f = any_perp(u)
	f = f.normalized()
	var r: Vector3 = f.cross(u).normalized()
	# columns: X = right, Y = up, Z = back(-forward)
	return Basis(r, u, -f)

static func fmt_dist(m: float) -> String:
	var a: float = absf(m)
	if a >= 100000.0:
		return "%.0f km" % (m / 1000.0)
	if a >= 1000.0:
		return "%.1f km" % (m / 1000.0)
	return "%.0f m" % m

static func fmt_speed(mps: float) -> String:
	var a: float = absf(mps)
	if a >= 1000.0:
		return "%.2f km/s" % (mps / 1000.0)
	return "%.0f m/s" % mps

static func fmt_time(sec: float) -> String:
	var s: int = int(sec)
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]

const _SYL_A := ["ka", "ro", "ven", "ta", "li", "mar", "xe", "os", "an", "dra", "zu", "phe", "ion", "tek", "sol", "ar", "el", "um", "bri", "cyn", "ve", "no", "ith", "ur", "ae", "quo", "ly", "sa", "ke", "ba", "thi", "or", "ny", "mi", "ga", "zen", "pra", "ul", "ex", "de"]
const _SYL_END := ["a", "on", "is", "us", "ia", "ar", "ix", "or", "ae", "um", "eth", "ara", "os", "yn", "ion"]

static func gen_name(seed_value: int, syllables: int = -1) -> String:
	var r := rng(seed_value)
	var n: int = syllables if syllables > 0 else r.randi_range(2, 3)
	var s := ""
	for i in n:
		s += _SYL_A[r.randi() % _SYL_A.size()]
	s += _SYL_END[r.randi() % _SYL_END.size()]
	return s.capitalize()

static func roman(n: int) -> String:
	var vals := [10, 9, 5, 4, 1]
	var syms := ["X", "IX", "V", "IV", "I"]
	var out := ""
	var x: int = n
	for i in vals.size():
		while x >= vals[i]:
			out += syms[i]
			x -= vals[i]
	return out

static func col_lerp3(a: Color, b: Color, c: Color, t: float) -> Color:
	if t < 0.5:
		return a.lerp(b, t * 2.0)
	return b.lerp(c, (t - 0.5) * 2.0)

static func srgb_to_lin(c: Color) -> Color:
	return c.srgb_to_linear()
