class_name BlackHole
extends Node3D
## A black hole: ray-marched lensing + accretion disc visuals, plus the gameplay constants used by the ship / HUD.
##
## Design (see README): gravity pull a(r) = K / r^2 grows as you approach; engines can still beat it down to the
## POINT OF NO RETURN (where pull equals boost thrust). Past that radius escape is impossible; crossing the event
## horizon (r < 1.15 rs) sends the ship through the singularity to a fixed distant star system.

const BH_SHADER := preload("res://shaders/black_hole.gdshader")

const K := 8.3e11  # m^3/s^2 (pull a = K / r^2)
const WARN_RANGE := 400000.0  # first HUD warning, pull starts to be felt
const SHEAR_RANGE := 220000.0  # pulse drive is disabled inside this
const PNR := 60000.0  # point of no return: pull (~230 m/s^2) equals the ship's boost acceleration
const HORIZON_FACTOR := 1.15

var rs: float = 3000.0
var upos: Array = [0.0, 0.0, 0.0]
var bh_name: String = "Eventide"
var dest: int = 1
var mat: ShaderMaterial


func setup(info: Dictionary) -> void:
	rs = info["rs"]
	bh_name = info["name"]
	dest = info["dest"]
	name = "BlackHole"
	# tilt the accretion disc so it is seen at an angle
	rotation_degrees = Vector3(-14.0, 0.0, 9.0)
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mat = ShaderMaterial.new()
	mat.shader = BH_SHADER
	mat.set_shader_parameter("rs", rs)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.extra_cull_margin = 1.0e7
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Lens"
	add_child(mi)


## Acceleration (m/s^2) felt by something at offset `rel` from the hole (pointing at the hole).
static func pull_accel(rel: Vector3) -> Vector3:
	var r := maxf(rel.length(), 1.0)
	return -rel / r * (K / (r * r))


static func pull_mag(r: float) -> float:
	return K / (maxf(r, 1.0) * maxf(r, 1.0))


static func time_dilation(r: float, rs_: float) -> float:
	return 1.0 / sqrt(maxf(1.0 - rs_ / maxf(r, rs_ * 1.001), 0.0005))
