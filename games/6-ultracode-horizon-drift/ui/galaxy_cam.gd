class_name GalaxyCam
extends RefCounted
## Orbit camera maths shared by the galaxy map and the main-menu backdrop. Units: light years.
## project() and the ui_galaxy shader use the same camera description, so 2D star markers line up with the volumetric disc.

var target: Vector3 = Vector3.ZERO
var yaw: float = 0.6
var pitch: float = 0.7
var dist: float = 90000.0
var fov_deg: float = 50.0
var pos: Vector3 = Vector3.ZERO
var basis: Basis = Basis.IDENTITY
var tan_half: float = 0.4663

func update() -> void:
	pitch = clampf(pitch, -1.45, 1.45)
	var cp := cos(pitch)
	pos = target + Vector3(cp * sin(yaw), sin(pitch), cp * cos(yaw)) * dist
	var fwd := (target - pos).normalized()
	basis = Basis.looking_at(fwd, Vector3.UP)
	tan_half = tan(deg_to_rad(fov_deg) * 0.5)

## screen position for a viewport of size `vp`; z = depth in front of the camera (< 1 means behind / invalid)
func project(p: Vector3, vp: Vector2) -> Vector3:
	var q: Vector3 = basis.transposed() * (p - pos)
	var depth := -q.z
	if depth < 1.0:
		return Vector3(-9999.0, -9999.0, depth)
	var f := 1.0 / tan_half
	var asp := vp.x / vp.y
	var x := q.x / depth * f / asp
	var y := q.y / depth * f
	return Vector3(vp.x * 0.5 * (1.0 + x), vp.y * 0.5 * (1.0 - y), depth)

## world-space ray direction through a screen pixel
func ray(px: Vector2, vp: Vector2) -> Vector3:
	var u := (px.x / vp.x) * 2.0 - 1.0
	var v := 1.0 - (px.y / vp.y) * 2.0
	var asp := vp.x / vp.y
	return (basis.x * (u * asp * tan_half) + basis.y * (v * tan_half) - basis.z).normalized()

func apply(mat: ShaderMaterial, vp: Vector2) -> void:
	mat.set_shader_parameter("cam_pos", pos)
	mat.set_shader_parameter("cam_right", basis.x)
	mat.set_shader_parameter("cam_up", basis.y)
	mat.set_shader_parameter("cam_back", basis.z)
	mat.set_shader_parameter("tan_half_fov", tan_half)
	mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
