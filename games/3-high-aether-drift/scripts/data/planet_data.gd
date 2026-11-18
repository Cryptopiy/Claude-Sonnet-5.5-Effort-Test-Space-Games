class_name PlanetData
extends RefCounted
## Everything needed to build one body of a star system. Derived purely from seeds (see Biomes.make).

var name: String = ""
var biome: String = "lush"
var seed: int = 1
var radius: float = 4000.0
var gravity: float = 9.0
var landable: bool = true
var kind: String = "planet"  # planet | moon | gas
var parent: int = -1  # index of parent body within the system (for moons), -1 = orbits the star
var orbit_r: float = 100000.0
var orbit_period: float = 5000.0
var orbit_phase: float = 0.0
var orbit_incl: float = 0.0
var spin_period: float = 900.0
var spin_phase: float = 0.0
var axis_tilt: float = 0.2

var terrain: TerrainParams = null
var look: Dictionary = {}
var sky: Dictionary = {}
var props: Array = []
var hazard: Dictionary = {}
var has_atmo: bool = true
var atm_color: Color = Color(0.4, 0.6, 1.0)
var atm_scale: float = 0.2  # shell thickness as a fraction of the radius
var rings: bool = false
var gas_colors: Array = []
var liquid: String = ""  # "", water, lava, toxic
var cloud_cover: float = 0.0
var cloud_color: Color = Color.WHITE
var weather: String = "none"  # none | rain | snow | dust | ash | spores
var resource_name: String = "Ferrite"
var resource_color: Color = Color(0.8, 0.9, 1.0)
var ore_name: String = "Carbon"
var fauna: Array = []
var site_dir: Vector3 = Vector3.UP
var poi_dirs: Array = []  # [{type, dir}]
var temp_c: float = 20.0
var desc: String = ""


func atmosphere_top() -> float:
	return radius * atm_scale


func sea_height() -> float:
	return terrain.sea_level if terrain != null else -100000.0
