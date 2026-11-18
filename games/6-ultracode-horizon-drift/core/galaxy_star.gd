class_name GalaxyStar
extends RefCounted
## One star of the galaxy (for the galaxy map and for generating its system on demand).

var id: int = 0
var name: String = ""
var pos: Vector3 = Vector3.ZERO     # light-years from the galactic centre (x,z = galactic plane, y = height)
var spectral_class: String = "G"
var color: Color = Color.WHITE
var seed: int = 0
var has_black_hole: bool = false
var special: bool = false           # hand-tuned systems (home + second system)

func distance_to(o: GalaxyStar) -> float:
	return pos.distance_to(o.pos)
