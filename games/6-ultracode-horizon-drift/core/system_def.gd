class_name SystemDef
extends RefCounted
## A fully generated star system (deterministic from the galaxy seed + star id).

var id: int = 0                    # galaxy star id
var name: String = ""
var seed: int = 0
var star: StarDef
var bodies: Array = []             # Array[BodyDef]; index == BodyDef.index (planets, moons, gas giants, then the black hole if any)
var black_hole_index: int = -1     # index into bodies, -1 if none
var arrival_body: int = 0          # body index near which hyperdrive arrivals appear (first landable planet)
var start_body: int = 0            # body index of the planet the game starts on (home system: Verdant)

func landable_bodies() -> Array:
	var out: Array = []
	for b in bodies:
		if b.landable:
			out.append(b)
	return out

func biome_set() -> Array:
	var seen: Dictionary = {}
	for b in bodies:
		if b.landable:
			seen[b.biome] = true
	return seen.keys()

func body_by_name(n: String) -> BodyDef:
	for b in bodies:
		if b.name == n:
			return b
	return null
