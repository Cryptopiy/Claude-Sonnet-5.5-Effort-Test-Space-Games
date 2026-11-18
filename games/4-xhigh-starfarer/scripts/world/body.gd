class_name Body
extends Node3D
## A celestial body (star, planet, moon, gas giant, black hole). Absolute position/velocity are analytic functions of
## system time; the node transform is re-derived every frame relative to the floating render origin.

var data: PlanetData
var kind := "planet"          # star, planet, gas, blackhole
var parent_body: Body
var apos := DV.new()          # absolute position in star-system space (double precision)
var vel := Vector3.ZERO       # absolute velocity (m/s)
var radius := 1.0
var rot := Basis.IDENTITY     # local -> system rotation
var omega := Vector3.ZERO     # angular velocity (system frame, rad/s)
var tilt_basis := Basis.IDENTITY
var display_name := ""
var frame_alt := 3000.0       # below this altitude ship/player live in this body's rotating frame
var body_index := -1
var spin_angle := 0.0


func is_landable() -> bool:
	return data != null and data.landable


func update_state(t: float) -> void:
	if data == null:
		return
	if parent_body != null and data.orbit_radius > 0.0:
		var w := TAU / data.orbit_period
		var th := data.orbit_phase + w * t
		var a := data.orbit_radius
		var si := sin(data.orbit_incl)
		var ci := cos(data.orbit_incl)
		var cx := a * cos(th)
		var cz0 := a * sin(th)
		apos = DV.new(parent_body.apos.x + cx, parent_body.apos.y + cz0 * si, parent_body.apos.z + cz0 * ci)
		var vx := -a * w * sin(th)
		var vz0 := a * w * cos(th)
		vel = parent_body.vel + Vector3(vx, vz0 * si, vz0 * ci)
	var sr := TAU / data.spin_period
	spin_angle = fmod(sr * t + data.orbit_phase * 3.0, TAU)
	tilt_basis = Basis(Vector3(0, 0, 1), data.axial_tilt)
	rot = tilt_basis * Basis(Vector3.UP, spin_angle)
	omega = tilt_basis * Vector3.UP * sr


## surface/atmosphere velocity at a body-local point (system frame)
func local_point_velocity(lpos: Vector3) -> Vector3:
	return vel + omega.cross(rot * lpos)


func local_to_abs(lpos: Vector3) -> DV:
	var r := rot * lpos
	return DV.new(apos.x + r.x, apos.y + r.y, apos.z + r.z)


func abs_to_local(p: DV) -> Vector3:
	return rot.transposed() * Vector3(p.x - apos.x, p.y - apos.y, p.z - apos.z)


func place(origin: DV) -> void:
	global_transform = Transform3D(rot, apos.minus(origin))


## altitude above terrain (or above the nominal sphere for non-terrain bodies) of a body-local position
func altitude_local(lpos: Vector3) -> float:
	var d := lpos.length()
	if data != null and data.landable:
		return d - (radius + data.height_at(lpos / d))
	return d - radius


func surface_distance_abs(p: DV) -> float:
	return p.dist(apos) - radius


func atmosphere_density_at(alt: float) -> float:
	if data == null or data.atmo_height <= 0.0:
		return 0.0
	return exp(-maxf(alt, 0.0) / (data.atmo_height * 0.28)) * data.atmo_density
