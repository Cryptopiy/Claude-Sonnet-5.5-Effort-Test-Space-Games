class_name BodyDef
extends RefCounted
## Definition of one celestial body in a star system (planet, moon, gas giant or black hole).
## Pure data, derived deterministically from seeds by Universe. Positions are NOT stored here: ask Universe.body_pos(index, t).

enum Kind { PLANET, MOON, GAS_GIANT, BLACK_HOLE }

var index: int = 0
var name: String = ""
var kind: int = Kind.PLANET
var seed: int = 0                 # every procedural decision for this body derives from this (use SeedUtil with it)
var biome: String = "barren"      # BiomeDB id; "gas" for gas giants, "blackhole" for black holes
var parent: int = -1              # -1 = orbits the star; otherwise body index of the planet this moon orbits

# geometry / physics (metres, seconds, m/s^2)
var radius: float = 6000.0        # base sphere radius (terrain height is added on top). Black hole: event-horizon (Schwarzschild) radius
var gravity: float = 9.0          # surface gravity m/s^2 (0 for non-landable)
var capture_radius: float = 0.0   # distance within which the local frame becomes this body's rotating frame (0 = never)
var landable: bool = true

# orbit (circular, optionally inclined). Black hole: orbit_radius = 0, fixed_pos is used instead
var orbit_radius: float = 0.0
var orbit_period: float = 1.0     # seconds for one revolution
var orbit_phase: float = 0.0      # radians at t = 0
var orbit_u: Vector3 = Vector3.RIGHT      # orbital plane basis vectors (unit, orthogonal)
var orbit_v: Vector3 = Vector3.BACK
var fixed_pos: Vector3 = Vector3.ZERO     # absolute position for static bodies (black hole); Vector3 is fine (metres, < 1e7)

# rotation
var spin_period: float = 900.0    # seconds per day (planet-local +Y axis is the pole)
var spin_phase: float = 0.0
var axial_tilt: float = 0.0       # radians
var tilt_azimuth: float = 0.0     # radians, direction of tilt around world up

# environment (design intent; modules read what they need)
var has_atmosphere: bool = false
var atmo_height: float = 0.0      # metres above radius where the atmosphere visually fades out
var has_ocean: bool = false
var ocean_kind: String = ""       # "water" | "lava" | "acid" | ""
var temp_day_c: float = 20.0      # surface temperature at noon
var temp_night_c: float = 5.0
var toxicity: float = 0.0         # 0..1 hazard strength
var radiation: float = 0.0        # 0..1
var has_rings: bool = false
var ring_inner: float = 0.0       # metres (gas giants)
var ring_outer: float = 0.0
var palette_seed: int = 0         # seed for the colour variant of the biome palette
var tint: Color = Color.WHITE     # small per-planet hue shift applied to biome palette (M1/M7 may use)

# black hole only
var bh_mu: float = 0.0            # gravitational parameter GM (m^3/s^2): accel = mu / r^2
var bh_disc_inner: float = 0.0
var bh_disc_outer: float = 0.0
var bh_dest_system: int = -1      # galaxy star id this singularity leads to
var bh_influence: float = 0.0     # radius within which the lensing/pull effects matter

# bookkeeping
var moons: Array = []             # indices of moons (filled by Universe)
var system_id: int = 0

func is_black_hole() -> bool:
	return kind == Kind.BLACK_HOLE

func is_gas_giant() -> bool:
	return kind == Kind.GAS_GIANT

## "Lush world", "Gas giant", ... for UI
func type_label() -> String:
	if kind == Kind.BLACK_HOLE:
		return "Black hole"
	if kind == Kind.GAS_GIANT:
		return "Gas giant"
	var b := BiomeDB.get_biome(biome)
	var label: String = b.get("name", biome.capitalize())
	return label + (" moon" if kind == Kind.MOON else " world")

func spin_axis_world() -> Vector3:
	return (rest_basis() * Vector3.UP).normalized()

## orientation of the body's local frame at spin angle 0 (tilted pole)
func rest_basis() -> Basis:
	return Basis(Vector3.UP, tilt_azimuth) * Basis(Vector3.RIGHT, axial_tilt)
