class_name FlyActor
extends RefCounted
## Test controller implementing the SpaceWorld actor protocol: free flight with scripted placement.

var world: SpaceWorld
var velocity: Vector3 = Vector3.ZERO
var basis: Basis = Basis.IDENTITY
var ship: Object = null
var cam_offset: Vector3 = Vector3.ZERO

func step(delta: float) -> void:
	if world.frame_idx < 0:
		world.viewer_sys.add_scaled(velocity, delta)
	else:
		world.viewer_pos += velocity * delta

func convert_to_planet(rt: Basis, r_s: Vector3, vk: Vector3, om: Vector3) -> void:
	velocity = rt * (velocity - vk - om.cross(r_s))
	basis = rt * basis

func convert_to_system(rk: Basis, r_s: Vector3, vk: Vector3, om: Vector3) -> void:
	velocity = rk * velocity + vk + om.cross(r_s)
	basis = rk * basis

func update_camera(w: SpaceWorld, _delta: float) -> void:
	w.camera.global_transform = Transform3D(basis, w.viewer_pos + basis * cam_offset)

## Place the viewer in the system frame at `pos`, looking at the (system-space) point `target`.
func place_system(pos: D3, target: D3) -> void:
	world.frame_idx = -1
	world.viewer_sys = pos.copy()
	world.viewer_pos = Vector3.ZERO
	var d: Vector3 = target.rel(pos).normalized()
	basis = Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT)
	velocity = Vector3.ZERO
	world.frame_changed.emit(-1)

## Enter the frame of body k and stand at planet-local position `local_pos`, looking along `look_dir` (planet axes).
func place_planet(k: int, local_pos: Vector3, look_dir: Vector3, up_hint: Vector3 = Vector3.ZERO) -> void:
	world.frame_idx = k
	world.viewer_pos = local_pos
	var up: Vector3 = up_hint if up_hint != Vector3.ZERO else local_pos.normalized()
	var d: Vector3 = look_dir.normalized()
	if absf(d.dot(up)) > 0.995:
		up = U.any_perp(d)
	basis = Basis.looking_at(d, up)
	velocity = Vector3.ZERO
	world.frame_changed.emit(k)
