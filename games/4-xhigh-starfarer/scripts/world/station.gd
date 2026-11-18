class_name Station
extends Body
## Orbital space station (Blender model) circling a planet. Flying close repairs the ship.

var orbit_r := 14000.0
var orbit_period := 340.0
var orbit_phase := 0.0
var model: Node3D
var service_cd := 0.0


func build(p_parent: Body, alt: float, p_name: String) -> void:
	kind = "station"
	parent_body = p_parent
	display_name = p_name
	radius = 60.0
	orbit_r = p_parent.radius + alt
	orbit_period = 650.0 * pow(orbit_r / 22000.0, 1.5)
	orbit_phase = 1.1
	model = ModelLib.instance("space_station")
	add_child(model)


func update_state(t: float) -> void:
	var a := orbit_phase + TAU * t / orbit_period
	var w := TAU / orbit_period
	apos = DV.new(parent_body.apos.x + orbit_r * cos(a), parent_body.apos.y + orbit_r * 0.12 * sin(a), parent_body.apos.z + orbit_r * sin(a))
	vel = parent_body.vel + Vector3(-orbit_r * w * sin(a), orbit_r * 0.12 * w * cos(a), orbit_r * w * cos(a))
	tilt_basis = Basis(Vector3(1, 0, 0), 0.35)
	rot = tilt_basis * Basis(Vector3.UP, t * 0.06)
