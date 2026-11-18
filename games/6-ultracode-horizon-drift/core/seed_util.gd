class_name SeedUtil
extends RefCounted
## Deterministic hashing / RNG helpers. Everything procedural in the game derives from these so a planet is identical on every visit.
## splitmix64 on GDScript's wrapping signed 64-bit ints (logical shifts emulated with masks).

const _GOLD := -7046029254386353131      # 0x9E3779B97F4A7C15
const _M1 := -4658895280553007687        # 0xBF58476D1CE4E5B9
const _M2 := -7723592293110705685        # 0x94D049BB133111EB

static func _lsr(v: int, n: int) -> int:
	return (v >> n) & ((1 << (64 - n)) - 1)

## 64-bit mix of one integer.
static func mix(a: int) -> int:
	var z: int = a + _GOLD
	z = (z ^ _lsr(z, 30)) * _M1
	z = (z ^ _lsr(z, 27)) * _M2
	return z ^ _lsr(z, 31)

## combine two/three ints into one hash
static func hash2(a: int, b: int) -> int:
	return mix(mix(a) ^ (b * 0x2545F4914F6CDD1D))

static func hash3(a: int, b: int, c: int) -> int:
	return hash2(hash2(a, b), c)

## deterministic float in [0,1) from (seed, index)
static func rand01(seed_value: int, index: int = 0) -> float:
	return float(hash2(seed_value, index) & 0xFFFFFFFFFFFF) / 281474976710656.0

static func rand_range(seed_value: int, index: int, lo: float, hi: float) -> float:
	return lo + (hi - lo) * rand01(seed_value, index)

static func rand_int(seed_value: int, index: int, lo: int, hi: int) -> int:
	return lo + int(rand01(seed_value, index) * float(hi - lo + 1)) if hi >= lo else lo

## fresh RandomNumberGenerator seeded from `seed_value` (PCG32, deterministic across runs)
static func rng(seed_value: int, salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash2(seed_value, salt) if salt != 0 else mix(seed_value)
	return r

## uniformly distributed unit vector from (seed, index)
static func rand_dir(seed_value: int, index: int = 0) -> Vector3:
	var u := rand01(seed_value, index * 2 + 1) * 2.0 - 1.0
	var a := rand01(seed_value, index * 2 + 2) * TAU
	var s := sqrt(maxf(0.0, 1.0 - u * u))
	return Vector3(s * cos(a), u, s * sin(a))

## weighted pick: weights is Array[float]; returns index
static func pick_weighted(r: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var t := r.randf() * total
	for i in weights.size():
		t -= float(weights[i])
		if t <= 0.0:
			return i
	return weights.size() - 1

const _SYL_A := ["Ka", "Zo", "Ar", "Vel", "Tor", "Syl", "Ny", "Or", "Ix", "Ha", "Lu", "Mer", "Quo", "Ra", "Sa", "Thal", "Ul", "Va", "Xen", "Yo", "Cae", "Dra", "El", "Fen", "Gor", "Hy", "Is", "Jun", "Kel", "Lyr"]
const _SYL_B := ["ra", "li", "ta", "no", "ve", "sa", "ki", "mo", "ri", "ph", "de", "ru", "ni", "la", "ze", "th", "co", "bi", "su", "ga"]
const _SYL_C := ["x", "n", "s", "r", "th", "m", "d", "k", "ia", "on", "us", "ar", "is", "eth", "ix", "or", "a", "um", "es", "al"]

## pronounceable procedural name
static func make_name(seed_value: int) -> String:
	var r := rng(seed_value, 77)
	var s: String = _SYL_A[r.randi() % _SYL_A.size()]
	if r.randf() < 0.75:
		s += _SYL_B[r.randi() % _SYL_B.size()]
	s += _SYL_C[r.randi() % _SYL_C.size()]
	return s

static func roman(n: int) -> String:
	var vals := [10, 9, 5, 4, 1]
	var syms := ["X", "IX", "V", "IV", "I"]
	var out := ""
	var v := n
	for i in vals.size():
		while v >= vals[i]:
			out += syms[i]
			v -= vals[i]
	return out
