class_name SpaceProps
extends Node3D
## Orbital points of interest around a planet: a station with a rotating ring and a docking bay, derelict satellites and asteroid
## clusters. They are children of the planet node and turn with it (a "geostationary" arrangement), so they are placed correctly
## in both reference frames of SpaceWorld without any extra bookkeeping.

const DOCK_RANGE: float = 90.0
const DOCK_SPEED: float = 45.0

var planet: Planet
var ring: Node3D
var station_node: Node3D
var dock: Node3D
var station_name: String = ""
var _spins: Array = []                 # [Node3D, Vector3 axis, float rad/s]
var _dock_cd: float = 0.0
var _hint_cd: float = 0.0
var _announced: bool = false

func setup(p: Planet, pois: Array) -> void:
	planet = p
	name = "SpaceProps"
	for poi in pois:
		match String(poi.get("kind", "")):
			"station":
				_add_station(poi)
			"satellite":
				_add_satellite(poi)
			"asteroids":
				_add_asteroids(poi)

func _center(poi: Dictionary) -> Vector3:
	var dir: Vector3 = (poi["dir"] as Vector3).normalized()
	return dir * (planet.data.radius + float(poi.get("alt", 6000.0)))

func _set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = planet.layer_bit
	for c in n.get_children():
		_set_layers(c)

func _add_station(poi: Dictionary) -> void:
	var st: Node3D = Models.instantiate("space_station")
	st.name = "Station"
	var dir: Vector3 = (poi["dir"] as Vector3).normalized()
	var fwd: Vector3 = U.any_perp(dir)
	# the ring's axis (local Y) leans away from the radial direction so the ring is seen edge-on-ish from the ground
	var bas: Basis = U.basis_from_up(dir, fwd) * Basis(Vector3.RIGHT, deg_to_rad(52.0))
	var sc: float = float(poi.get("scale", 2.4))
	st.transform = Transform3D(bas.scaled(Vector3(sc, sc, sc)), _center(poi))
	add_child(st)
	_set_layers(st)
	station_node = st
	station_name = String(poi.get("name", "Orbital Station"))
	ring = st.find_child("Ring", true, false) as Node3D
	dock = st.find_child("Marker_Dock", true, false) as Node3D
	if ring != null:
		_spins.append([ring, Vector3.UP, 0.10])
	st.set_meta("station_scale", sc)

func _add_satellite(poi: Dictionary) -> void:
	var sat: Node3D = Models.instantiate("satellite")
	sat.name = "Satellite"
	var r := U.rng(int(poi.get("seed", 1)))
	var sc: float = float(poi.get("scale", 1.6))
	var bas := Basis.from_euler(Vector3(r.randf() * TAU, r.randf() * TAU, r.randf() * TAU))
	sat.transform = Transform3D(bas.scaled(Vector3(sc, sc, sc)), _center(poi))
	add_child(sat)
	_set_layers(sat)
	_spins.append([sat, U.rand_unit(r), r.randf_range(0.02, 0.06)])

func _add_asteroids(poi: Dictionary) -> void:
	var r := U.rng(int(poi.get("seed", 1)))
	var center: Vector3 = _center(poi)
	var count: int = int(poi.get("count", 14))
	var spread: float = float(poi.get("radius", 350.0))
	var names: Array = ["asteroid_a", "asteroid_b", "asteroid_c"]
	var root := Node3D.new()
	root.name = "AsteroidField"
	root.position = center
	add_child(root)
	for i in count:
		var a: Node3D = Models.instantiate(String(names[r.randi() % names.size()]))
		var off: Vector3 = U.rand_unit(r) * spread * pow(r.randf(), 0.6)
		off.y *= 0.55
		var sc: float = r.randf_range(0.35, 1.9)
		var bas := Basis.from_euler(Vector3(r.randf() * TAU, r.randf() * TAU, r.randf() * TAU))
		a.transform = Transform3D(bas.scaled(Vector3(sc, sc, sc)), off)
		root.add_child(a)
		_spins.append([a, U.rand_unit(r), r.randf_range(-0.05, 0.05)])
	_set_layers(root)

func _process(delta: float) -> void:
	for s in _spins:
		var n: Node3D = s[0]
		var ax: Vector3 = s[1]
		n.transform.basis = n.transform.basis * Basis(ax, float(s[2]) * delta)
	if dock != null:
		_dock_cd = maxf(_dock_cd - delta, 0.0)
		_check_dock()

## flying into the docking bay restores the shield and the boost reserve (and announces the station)
func _check_dock() -> void:
	var w := planet.get_parent() as SpaceWorld
	if w == null or w.actor == null:
		return
	var ship: Ship = w.actor.get("ship") as Ship
	if ship == null or ship.state != Ship.State.FLYING:
		return
	var d: float = ship.global_position.distance_to(dock.global_position)
	if not _announced and d < 3500.0:
		_announced = true
		Game.discover("station_" + station_name, "Orbital station: %s" % station_name)
	_hint_cd = maxf(_hint_cd - get_process_delta_time(), 0.0)
	if d < 420.0 and d >= DOCK_RANGE and ship.velocity.length() > DOCK_SPEED and _hint_cd <= 0.0 and _dock_cd <= 0.0:
		_hint_cd = 25.0
		Game.notify("%s: docking bay ahead - slow below %d m/s and fly into the bay" % [station_name, int(DOCK_SPEED)], 4.0)
	if d < DOCK_RANGE and ship.velocity.length() < DOCK_SPEED and _dock_cd <= 0.0:
		_dock_cd = 45.0
		ship.shield = 100.0
		ship.boost_energy = 1.0
		Game.notify("%s: docking clearance - shield and boost restored" % station_name, 4.0, "good")
		Game.play_sfx("pulse_on", -4.0, 1.2)
