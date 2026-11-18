class_name Galaxy
extends RefCounted
## Procedural galaxy: a few hundred stars on spiral arms. Every star has a seed that fully determines its system.

const STAR_CLASSES := ["O", "B", "A", "F", "G", "K", "M"]
const CLASS_COLOR := {
	"O": Color(0.62, 0.72, 1.0), "B": Color(0.72, 0.82, 1.0), "A": Color(0.88, 0.92, 1.0), "F": Color(1.0, 0.97, 0.88),
	"G": Color(1.0, 0.91, 0.72), "K": Color(1.0, 0.76, 0.5), "M": Color(1.0, 0.52, 0.36),
}
const CLASS_SIZE := {"O": 2.6, "B": 2.0, "A": 1.5, "F": 1.2, "G": 1.0, "K": 0.85, "M": 0.6}
const CLASS_LUM := {"O": 2.2, "B": 1.8, "A": 1.4, "F": 1.15, "G": 1.0, "K": 0.8, "M": 0.55}
const SYL_A := ["Ka", "Ve", "Ly", "Or", "Zan", "Mi", "Tau", "Ar", "Sol", "Cy", "Ne", "Xo", "Ha", "Ri", "Du", "Qu", "El", "Ma", "Vo", "Ky"]
const SYL_B := ["ra", "lo", "na", "xi", "dor", "ve", "ta", "mis", "ron", "lu", "ki", "ph", "sa", "gen", "thu", "ria", "zen"]
const SYL_C := ["s", "n", "x", "a", "is", "on", "ar", "um", "eth", "ix", "or", "ia", "us", "ae"]
const GALAXY_RADIUS := 52000.0
const HOME_ID := 0
const BH_JUMP_LY := 7000.0


class StarInfo:
	var id := 0
	var name := ""
	var pos := Vector3.ZERO        # light years, galaxy-centred
	var cls := "G"
	var color := Color.WHITE
	var seed := 0
	var has_bh := false
	var bh_target := -1
	var visited := false
	var size_mul := 1.0
	var lum := 1.0


var stars: Array = []
var seed := 0
var bh_stars: Array = []


static func make_name(rng: RandomNumberGenerator) -> String:
	var s: String = SYL_A[rng.randi() % SYL_A.size()] + SYL_B[rng.randi() % SYL_B.size()]
	if rng.randf() < 0.55:
		s += SYL_C[rng.randi() % SYL_C.size()]
	if rng.randf() < 0.25:
		s += "-" + str(rng.randi_range(2, 99))
	return s


func generate(p_seed: int, count := 420) -> void:
	seed = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	stars.clear()
	# home star first (fixed place, ~26k ly from the core)
	var home := StarInfo.new()
	home.id = 0
	home.name = "Solara"
	home.cls = "G"
	home.pos = Vector3(24500.0, 140.0, -9000.0)
	home.seed = 424242
	home.has_bh = true
	stars.append(home)
	var used_names := {"Solara": true}
	for i in range(1, count):
		var s := StarInfo.new()
		s.id = i
		var u := rng.randf()
		var r := 3500.0 + (GALAXY_RADIUS - 3500.0) * pow(u, 0.8)
		var bulge := rng.randf() < 0.16
		var ang := 0.0
		var y := 0.0
		if bulge:
			r = rng.randf_range(300.0, 6500.0) * rng.randf_range(0.5, 1.0)
			ang = rng.randf() * TAU
			y = rng.randfn(0.0, 1800.0)
		else:
			var arm := rng.randi() % 4
			ang = arm * (TAU / 4.0) + r / 9000.0 * 1.15 + rng.randfn(0.0, 0.33)
			y = rng.randfn(0.0, 700.0 + 1200.0 * exp(-r / 14000.0))
		s.pos = Vector3(cos(ang) * r, y, sin(ang) * r)
		s.cls = _pick_class(rng)
		s.color = CLASS_COLOR[s.cls]
		s.size_mul = CLASS_SIZE[s.cls]
		s.lum = CLASS_LUM[s.cls]
		s.seed = rng.randi() & 0x7FFFFFF
		var n := make_name(rng)
		while used_names.has(n):
			n = make_name(rng)
		used_names[n] = true
		s.name = n
		s.has_bh = rng.randf() < 0.045
		stars.append(s)
	var h: StarInfo = stars[0]
	h.color = CLASS_COLOR["G"]
	h.size_mul = 1.0
	h.lum = 1.0
	# black-hole destinations: ~7000 ly closer to the galactic centre
	bh_stars.clear()
	for s2 in stars:
		if s2.has_bh:
			bh_stars.append(s2)
			s2.bh_target = _bh_target(s2)
	# guarantee the home hole leads to a hand-picked K/M neighbour that is also a destination
	stars[0].bh_target = _bh_target(stars[0])


func _pick_class(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	if r < 0.01: return "O"
	if r < 0.04: return "B"
	if r < 0.10: return "A"
	if r < 0.22: return "F"
	if r < 0.42: return "G"
	if r < 0.70: return "K"
	return "M"


func _bh_target(s: StarInfo) -> int:
	var dir := (-s.pos).normalized()
	var target_pos: Vector3 = s.pos + dir * BH_JUMP_LY
	var best := -1
	var bd := 1e30
	for t in stars:
		if t.id == s.id:
			continue
		var d: float = t.pos.distance_to(target_pos)
		if d < bd:
			bd = d
			best = t.id
	return best


func distance_ly(a: int, b: int) -> float:
	return (stars[a] as StarInfo).pos.distance_to((stars[b] as StarInfo).pos)


func nearest(pos: Vector3, count: int, exclude := -1) -> Array:
	var arr: Array = []
	for s in stars:
		if s.id != exclude:
			arr.append([s.pos.distance_to(pos), s.id])
	arr.sort_custom(func(x, y): return x[0] < y[0])
	return arr.slice(0, count)
