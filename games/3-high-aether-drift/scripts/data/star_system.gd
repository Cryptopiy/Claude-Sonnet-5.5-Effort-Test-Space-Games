class_name StarSystem
extends RefCounted
## A generated star system: star + bodies (+ optional black hole). Built by SystemGen.

var id: int = 0
var name: String = ""
var seed: int = 0
var star_class: String = "G"
var star_color: Color = Color(1.0, 0.9, 0.65)
var star_radius: float = 6000.0
var star_energy: float = 2.0
var bodies: Array = []  # of PlanetData
var black_hole: Dictionary = {}  # {pos: Vector3, rs: float, name: String, dest: int}
var galaxy_pos: Vector3 = Vector3.ZERO
var start_planet: int = 0  # body index where a new game spawns


func body_index(bname: String) -> int:
	for i in bodies.size():
		if bodies[i].name == bname:
			return i
	return -1
