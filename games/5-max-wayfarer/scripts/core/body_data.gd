class_name BodyData
extends RefCounted
## Static description of one celestial body (planet, moon, gas giant). Orbits are kinematic (analytic).

var index: int = 0
var name: String = ""
var kind: String = "planet"        # "planet" | "moon" | "gas"
var biome: String = "dead"
var seed_i: int = 1
var radius: float = 3000.0         # metres
var gravity: float = 9.0           # surface m/s^2
var landable: bool = true
var parent: int = -1               # index of parent body or -1 (orbits the star)

var orbit_r: float = 100000.0
var orbit_period: float = 3600.0
var orbit_phase: float = 0.0
var orbit_incl: float = 0.0        # radians (about X)
var orbit_node: float = 0.0        # radians (about Y), longitude of ascending node

var spin_period: float = 900.0
var spin_phase: float = 0.0
var tilt: float = 0.0              # axial tilt, radians

var profile: Dictionary = {}       # resolved biome profile (see Biomes.make_profile)
var outposts: Array = []           # [{dir:Vector3, kind:String, seed:int, r_in:float, r_out:float, flat_h:float}]
var rings: Dictionary = {}         # gas giants: {inner, outer, color}
var pois: Array = []               # orbital points of interest: [{kind: station|satellite|asteroids, dir, alt, seed, ...}] (see SpaceProps)
var gas_colors: Array = []         # gas giants band colours
var moons: Array[int] = []

# derived
var atm_height: float = 0.0        # atmosphere thickness (m)
var frame_radius: float = 0.0      # distance from centre at which the planet-fixed frame takes over

func derive() -> void:
	var atm: Dictionary = profile.get("atm", {})
	atm_height = radius * float(atm.get("thick", 0.0)) if atm.get("on", false) else 0.0
	if kind == "gas":
		frame_radius = 0.0
	else:
		frame_radius = radius + maxf(radius * 2.2, 6000.0)
	gravity = float(profile.get("g", gravity))

func biome_label() -> String:
	if kind == "gas":
		return "Gas Giant"
	return String(profile.get("label", biome.capitalize()))
