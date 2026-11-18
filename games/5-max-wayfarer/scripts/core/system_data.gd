class_name SystemData
extends RefCounted
## One star system: a star, a list of bodies, an optional black hole.

var seed_i: int = 1
var name: String = "Unknown"
var galaxy_index: int = 0

# star
var star_class: String = "G"
var star_color: Color = Color(1.0, 0.92, 0.72)
var star_radius: float = 2700.0
var star_temp: float = 5700.0
var star_light: float = 1.0
var star_name: String = "Star"

var bodies: Array[BodyData] = []

# black hole (optional)
var has_black_hole: bool = false
var bh_orbit_r: float = 700000.0
var bh_phase: float = 1.0
var bh_incl: float = 0.0
var bh_rs: float = 600.0                 # event horizon radius (m)
var bh_dest_index: int = -1              # galaxy index of the system you emerge in
var bh_axis: Vector3 = Vector3(0.18, 0.96, 0.2)

# galactic sky parameters (per system flavour)
var nebula_a: Color = Color(0.3, 0.35, 0.7)
var nebula_b: Color = Color(0.7, 0.3, 0.5)
var sky_seed: float = 1.0

# points of interest in open space (asteroid fields, stations...)
var stations: Array = []                 # [{name, orbit_r, phase, parent_body}]

func planet_count() -> int:
	return bodies.size()

func landable_bodies() -> Array[BodyData]:
	var out: Array[BodyData] = []
	for b in bodies:
		if b.landable:
			out.append(b)
	return out

func find_body(bname: String) -> BodyData:
	for b in bodies:
		if b.name == bname:
			return b
	return null

func star_dim_factor(orbit_r: float) -> float:
	## light intensity multiplier for a body at the given distance from the star (softened inverse square)
	var d: float = maxf(orbit_r, 60000.0) / 220000.0
	return clampf(1.0 / pow(d, 0.7), 0.55, 1.9) * star_light
