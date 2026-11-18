class_name ScannerFX
extends MeshInstance3D
## Scanner pulse visual (module M4): a full-screen quad (shaders/player_scan.gdshader) that reads the depth buffer and draws a ring
## expanding from the player over the terrain/props/everything, with a short glowing wake.  Player owns timing + the HUD markers.

const SHADER := preload("res://shaders/player_scan.gdshader")
const DURATION := 1.9
const MAX_RADIUS := 600.0

var _mat: ShaderMaterial
var _t: float = -1.0
var _origin: Vector3 = Vector3.ZERO

func _ready() -> void:
	top_level = true
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.render_priority = 30
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	custom_aabb = AABB(Vector3(-4000, -4000, -4000), Vector3(8000, 8000, 8000))
	visible = false

## radius of the ring after u in 0..1 of the animation (ease-out so it races away quickly)
static func radius_at(u: float) -> float:
	return MAX_RADIUS * pow(clampf(u, 0.0, 1.0), 1.12)

## seconds after the pulse started until the ring reaches distance d
static func delay_for(d: float) -> float:
	var e := clampf(d / MAX_RADIUS, 0.0, 1.0)
	return pow(e, 1.0 / 1.12) * DURATION

func fire(origin: Vector3) -> void:
	_origin = origin
	_t = 0.0
	visible = true
	global_position = origin

func is_running() -> bool:
	return _t >= 0.0

func _process(dt: float) -> void:
	if _t < 0.0:
		return
	_t += dt
	var u := _t / DURATION
	if u >= 1.0:
		_t = -1.0
		visible = false
		return
	global_position = _origin
	var r := radius_at(u)
	_mat.set_shader_parameter("scan_origin", _origin)
	_mat.set_shader_parameter("scan_radius", r)
	_mat.set_shader_parameter("scan_max", MAX_RADIUS)
	_mat.set_shader_parameter("scan_width", lerpf(2.5, 9.0, u))
	_mat.set_shader_parameter("scan_alpha", 1.0 - smoothstep(0.75, 1.0, u))

func _on_frame_shift(rot: Basis, shift: Vector3, vel_offset: Vector3) -> void:
	_origin = rot * _origin + shift
