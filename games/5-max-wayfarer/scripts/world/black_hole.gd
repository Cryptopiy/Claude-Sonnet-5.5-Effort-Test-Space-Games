class_name BlackHole
extends Node3D
## Black hole: lensing billboard (see shaders/black_hole.gdshader), gravity zones, pull on the ship, point of no return,
## horizon capture. Design (see README): the ship is pulled with a = K / d^2. The point of no return is the radius at which the
## pull equals the maximum (boosted) engine acceleration; below it the ship's top speed is below the local escape speed, so
## nothing can climb out any more. Crossing the event horizon transports the ship to the system `bh_dest_index`.

const K_PULL: float = 6.35e9                  # m^3 / s^2
const PULL_CAP: float = 5200.0
const DISC_IN: float = 3.0                    # in horizon radii
const DISC_OUT: float = 14.0
const LENS_RADIUS_RS: float = 70.0
const ZONE_DETECT: float = 140000.0
const ZONE_DANGER: float = 26000.0

var rs: float = 620.0
var axis_sys: Vector3 = Vector3(0.2, 0.95, 0.24)
var lens_mi: MeshInstance3D
var lens_mat: ShaderMaterial
var pnr_mi: MeshInstance3D
var pnr_mat: ShaderMaterial
var light: OmniLight3D
var pnr_dist: float = 5500.0
var captured_sent: bool = false
var zone: int = 0
var last_dist: float = 1e9
var tidal: float = 0.0
var bh_time_scale: float = 1.0
var disabled: bool = false

func setup(s: SystemData) -> void:
	name = "BlackHole"
	rs = s.bh_rs
	axis_sys = s.bh_axis.normalized()
	pnr_dist = sqrt(K_PULL / (Ship.ACC_FWD * 2.7))
	lens_mat = ShaderMaterial.new()
	lens_mat.shader = load("res://shaders/black_hole.gdshader")
	lens_mat.render_priority = 5
	lens_mat.set_shader_parameter("rs", rs)
	lens_mat.set_shader_parameter("disc_in", DISC_IN)
	lens_mat.set_shader_parameter("disc_out", DISC_OUT)
	lens_mat.set_shader_parameter("lens_half", rs * LENS_RADIUS_RS)
	lens_mat.set_shader_parameter("nebula_a", s.nebula_a)
	lens_mat.set_shader_parameter("nebula_b", s.nebula_b)
	lens_mat.set_shader_parameter("sky_seed", s.sky_seed)
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	lens_mi = MeshInstance3D.new()
	lens_mi.mesh = qm
	lens_mi.material_override = lens_mat
	lens_mi.extra_cull_margin = rs * LENS_RADIUS_RS * 2.0
	lens_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lens_mi.layers = 1 << 19
	add_child(lens_mi)
	# point-of-no-return hologram
	pnr_mat = ShaderMaterial.new()
	pnr_mat.shader = load("res://shaders/pnr_shell.gdshader")
	pnr_mat.render_priority = 6
	var sm := SphereMesh.new()
	sm.radius = pnr_dist
	sm.height = pnr_dist * 2.0
	sm.radial_segments = 64
	sm.rings = 32
	pnr_mi = MeshInstance3D.new()
	pnr_mi.mesh = sm
	pnr_mi.material_override = pnr_mat
	pnr_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pnr_mi.layers = 1 << 19
	pnr_mi.visible = false
	add_child(pnr_mi)
	# warm light from the disc for the ship
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.omni_range = 60000.0
	light.omni_attenuation = 1.6
	light.light_energy = 0.0
	light.light_cull_mask = 1
	add_child(light)

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func update_bh(w: SpaceWorld, delta: float) -> void:
	var ship: Ship = null
	if w.actor != null:
		ship = w.actor.get("ship") as Ship
	# lens uniforms
	var axis_world: Vector3 = (global_basis * axis_sys).normalized()
	var xa: Vector3 = U.any_perp(axis_world)
	var za: Vector3 = xa.cross(axis_world).normalized()
	lens_mat.set_shader_parameter("bh_basis", Basis(xa, axis_world, za))
	lens_mat.set_shader_parameter("sky_inv", Basis.from_euler(w.env.sky_rotation).transposed())
	var rel: Vector3 = global_position - w.viewer_pos
	if w.frame_idx >= 0:
		rel = global_position - w.viewer_pos
	var d: float = rel.length()
	last_dist = d
	# --- zones and pull (system frame only; in a planet frame the hole is hundreds of km away)
	var zone_now: int = 0
	var pull: float = 0.0
	var pull_ratio: float = 0.0
	if d < ZONE_DETECT:
		zone_now = 1
	if d < ZONE_DANGER:
		zone_now = 2
	if d < pnr_dist * 1.18:
		zone_now = 3
	pull = minf(K_PULL / maxf(d * d, 1.0), PULL_CAP)
	pull_ratio = pull / (Ship.ACC_FWD * 2.7)
	zone = zone_now
	if zone_now > 0 and w.frame_idx < 0:
		w.bh_info = {"zone": zone_now, "dist": maxf(d - rs, 0.0), "pull_ratio": pull_ratio, "pull": pull, "pnr": pnr_dist}
	else:
		w.bh_info = {}
	# --- shell / light visibility
	var show_shell: bool = d < pnr_dist * 3.0
	pnr_mi.visible = show_shell
	if show_shell:
		pnr_mat.set_shader_parameter("fade", clampf(1.0 - (d - pnr_dist) / (pnr_dist * 1.7), 0.0, 1.0))
		pnr_mat.set_shader_parameter("pulse", 1.0 if zone >= 3 else 0.0)
		pnr_mat.set_shader_parameter("color", Color(1.0, 0.18, 0.12) if d < pnr_dist else Color(1.0, 0.5, 0.15))
	light.light_energy = 6.0 * U.smooth(70000.0, 6000.0, d)
	# --- ship interaction
	if ship != null and w.frame_idx < 0 and not w.paused and not disabled:
		var dir: Vector3 = rel.normalized()
		if zone_now > 0:
			ship.velocity += dir * pull * delta
		ship.bh_control_loss = clampf((pull_ratio - 0.35) / 1.0, 0.0, 0.88)
		ship.shake = maxf(ship.shake, clampf(pull_ratio * 0.5, 0.0, 0.9) * (1.0 if zone_now >= 2 else 0.0))
		tidal = clampf((3300.0 - d) / (3300.0 - rs), 0.0, 1.0)
		ship.tidal = tidal
		ship.bh_dir = dir
		# slow time near the horizon
		var ts: float = lerpf(1.0, 0.38, U.smooth(7.0 * rs, 1.3 * rs, d))
		Engine.time_scale = ts
		if d < rs * 1.02 and not captured_sent:
			captured_sent = true
			w.bh_captured.emit()
	else:
		if ship != null:
			ship.bh_control_loss = 0.0
			ship.tidal = 0.0
		if Engine.time_scale != 1.0 and not w.paused:
			Engine.time_scale = 1.0
