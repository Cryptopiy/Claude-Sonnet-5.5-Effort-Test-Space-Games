class_name BlackHole
extends Body
## A black hole: Schwarzschild ray-marching quad (visuals) + the numbers used by the gameplay (pull, point of no return).

const PULL_K := 3.6e9            # a(r) = K / r^2   (m/s^2)
const WARN_RADIUS := 70000.0     # first warnings
const PULL_RADIUS := 55000.0     # pull becomes noticeable (~1.2 m/s^2)
const PNR_BOOST := 3120.0        # pull exceeds boost thrust (370 m/s^2): point of no return
const PNR_NORMAL := 5300.0       # pull exceeds normal thrust (130 m/s^2)

var rs := 900.0
var quad: MeshInstance3D
var mat: ShaderMaterial
var orbit_radius := 800000.0
var orbit_phase := 3.4
var dest_id := -1
var dest_name := ""


func build(p_rs: float, p_orbit: float, p_phase: float) -> void:
	kind = "blackhole"
	rs = p_rs
	radius = p_rs
	orbit_radius = p_orbit
	orbit_phase = p_phase
	display_name = "Singularity"
	quad = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	quad.mesh = q
	var lens := 18.0
	quad.scale = Vector3(rs * lens * 2.0, rs * lens * 2.0, 1.0)
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/blackhole.gdshader")
	mat.set_shader_parameter("rs", rs)
	mat.set_shader_parameter("lens_rs", lens)
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.extra_cull_margin = 100000.0
	add_child(quad)
	# disc tilt (the Body node's rotation tilts the disc plane relative to the system)
	tilt_basis = Basis(Vector3(1, 0, 0), 0.32) * Basis(Vector3(0, 0, 1), 0.18)
	rot = tilt_basis


func update_state(t: float) -> void:
	apos = DV.new(orbit_radius * cos(orbit_phase), 0.0, orbit_radius * sin(orbit_phase))
	vel = Vector3.ZERO


## gravitational acceleration (system frame) of a ship at absolute position p
func pull_at(p: DV) -> Vector3:
	var d := Vector3(apos.x - p.x, apos.y - p.y, apos.z - p.z)
	var r := d.length()
	if r < 1.0:
		return Vector3.ZERO
	var a := PULL_K / (r * r)
	return d / r * a


func pull_magnitude(r: float) -> float:
	return PULL_K / maxf(r * r, 1.0)
