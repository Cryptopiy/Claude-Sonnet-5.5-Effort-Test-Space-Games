class_name SpaceWorld
extends Node3D
## Runtime world of one star system.
##
## Precision strategy (floating origin with two kinds of reference frame):
##  * SYSTEM frame: the viewer (ship) always sits at the scene origin; every body is placed at (true position - viewer
##    position) computed in double precision. Nothing big is ever far from the camera in float32 space.
##  * PLANET frame: when the ship comes within `frame_radius` of a landable body the scene switches to that body's
##    body-fixed (rotating) frame with the planet centre at the origin, so terrain colliders are static and the
##    player can walk around the whole sphere with sub-millimetre float precision. Everything else (star, other
##    planets, sky) is re-expressed in that frame, so the day/night cycle is simply the sun moving across the sky.
## All motion is integrated in _process() with the frame's delta: no physics interpolation issues.

signal frame_changed(idx: int)
signal system_loaded(sys: SystemData)
signal bh_captured

var sys: SystemData
var time: float = 0.0
var time_scale: float = 1.0
var planets: Array[Planet] = []
var star: StarBody = null
var bh: Node3D = null
var lights: Array[DirectionalLight3D] = []
var deep_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var world_env: WorldEnvironment
var env: Environment
var sky_mat: ShaderMaterial
var camera: Camera3D
var attrs: CameraAttributesPractical

# frame / viewer state
var frame_idx: int = -1
var viewer_sys: D3 = D3.new()          # true system position of the viewer (ship); authoritative in system frame
var viewer_pos: Vector3 = Vector3.ZERO # viewer position in the current frame (ZERO in system frame)
var cam_world: Vector3 = Vector3.ZERO
var sun_dir_view: Vector3 = Vector3.UP # direction to the star as seen by the viewer (world axes of current frame)
var sun_up_at_viewer: float = 1.0      # dot(local up, sun dir) when in a planet frame
var altitude: float = 1e9              # altitude over the surface of the active planet (m); 1e9 if none
var air: float = 0.0                   # relative air density at viewer 0..1
var nearest_body: int = -1
var nearest_dist: float = 1e12
var actor: Object = null               # current controller with step(delta)
var cam_driver: Object = null          # object with update_camera(world, delta)
var paused: bool = false
var on_frame_event: Callable = Callable()
var bh_info: Dictionary = {}           # filled by BlackHole: zone, dist, pull_ratio ... (HUD warnings)

const FRAME_EXIT_MARGIN: float = 1.08

func _init() -> void:
	name = "SpaceWorld"
	process_priority = -50
	_build_environment()
	camera = Camera3D.new()
	camera.name = "GameCamera"
	camera.near = 0.2
	camera.far = 1500000.0
	camera.fov = 75.0
	camera.cull_mask = 0xFFFFF
	camera.attributes = attrs
	add_child(camera)
	fill_light = DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_color = Color(0.62, 0.74, 1.0)
	fill_light.light_energy = 0.55
	fill_light.light_cull_mask = 1
	fill_light.shadow_enabled = false
	add_child(fill_light)

func _ready() -> void:
	camera.make_current()
	Game.settings_applied.connect(_apply_quality)
	_apply_quality()

func _apply_quality() -> void:
	env.ssao_enabled = Game.quality >= 2
	env.glow_enabled = Game.quality >= 1
	for p in planets:
		if p.terrain != null:
			p.terrain.split_scale = [0.78, 0.92, 1.0][clampi(Game.quality, 0, 2)]

# ---------------------------------------------------------------------------------------------------------
func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.25, 0.4)
	env.ambient_light_energy = 0.3
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.3
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 1.0)
	env.set_glow_level(5, 0.6)
	env.set_glow_level(6, 0.4)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.04
	env.fog_enabled = false
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.4
	env.ssao_power = 1.6
	env.ssao_detail = 0.5
	attrs = CameraAttributesPractical.new()
	world_env = WorldEnvironment.new()
	world_env.environment = env
	world_env.camera_attributes = attrs
	add_child(world_env)

func load_system(s: SystemData) -> void:
	clear_system()
	sys = s
	var sp: Dictionary = {}
	sky_mat.set_shader_parameter("nebula_a", s.nebula_a)
	sky_mat.set_shader_parameter("nebula_b", s.nebula_b)
	sky_mat.set_shader_parameter("sky_seed", s.sky_seed)
	star = StarBody.new()
	add_child(star)
	star.setup(s)
	for i in s.bodies.size():
		var p := Planet.new()
		add_child(p)
		p.setup(s.bodies[i], i)
		planets.append(p)
		if p.terrain != null:
			p.terrain.split_scale = [0.78, 0.92, 1.0][clampi(Game.quality, 0, 2)]
		var l := DirectionalLight3D.new()
		l.name = "Light_" + s.bodies[i].name
		l.light_cull_mask = p.layer_bit
		l.light_color = s.star_color
		l.shadow_enabled = false
		l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		l.directional_shadow_max_distance = 420.0
		l.directional_shadow_blend_splits = true
		l.shadow_bias = 0.04
		l.shadow_normal_bias = 1.6
		l.light_angular_distance = 0.4
		add_child(l)
		lights.append(l)
	deep_light = DirectionalLight3D.new()
	deep_light.name = "DeepSpaceLight"
	deep_light.light_cull_mask = 1
	deep_light.light_color = s.star_color
	deep_light.light_energy = 2.4
	deep_light.shadow_enabled = true
	deep_light.directional_shadow_max_distance = 120.0
	add_child(deep_light)
	if s.has_black_hole:
		var b: Node3D = BlackHole.new()
		add_child(b)
		(b as BlackHole).setup(s)
		bh = b
	time = 0.0
	frame_idx = -1
	viewer_sys = D3.new(0.0, 6000.0, 330000.0)
	system_loaded.emit(s)

func clear_system() -> void:
	for p in planets:
		p.shutdown()
		p.queue_free()
	planets.clear()
	for l in lights:
		l.queue_free()
	lights.clear()
	if star != null:
		star.queue_free()
		star = null
	if deep_light != null:
		deep_light.queue_free()
		deep_light = null
	if bh != null:
		bh.queue_free()
		bh = null
	bh_info = {}
	frame_idx = -1

# ---------------------------------------------------------------------------------------------------------
# Kinematics (double precision)
func body_pos(i: int, t: float) -> D3:
	var b: BodyData = sys.bodies[i]
	var th: float = b.orbit_phase + TAU * t / b.orbit_period
	var r: float = b.orbit_r
	var x: float = r * cos(th)
	var z: float = r * sin(th)
	var si: float = sin(b.orbit_incl)
	var ci: float = cos(b.orbit_incl)
	var y2: float = -z * si
	var z2: float = z * ci
	var sn: float = sin(b.orbit_node)
	var cn: float = cos(b.orbit_node)
	var res := D3.new(x * cn + z2 * sn, y2, -x * sn + z2 * cn)
	if b.parent >= 0:
		res = res.plus(body_pos(b.parent, t))
	return res

func body_basis(i: int, t: float) -> Basis:
	var b: BodyData = sys.bodies[i]
	var ang: float = fposmod(b.spin_phase + TAU * t / b.spin_period, TAU)
	return Basis(Vector3.BACK, b.tilt) * Basis(Vector3.UP, ang)

func body_vel(i: int, t: float) -> Vector3:
	var a: D3 = body_pos(i, t + 0.05)
	var c: D3 = body_pos(i, t - 0.05)
	return a.rel(c) / 0.1

func body_omega(i: int, t: float) -> Vector3:
	var b: BodyData = sys.bodies[i]
	var axis: Vector3 = Basis(Vector3.BACK, b.tilt) * Vector3.UP
	return axis * (TAU / b.spin_period)

func star_pos_in_frame() -> Vector3:
	if frame_idx < 0:
		return Vector3.ZERO - viewer_sys.to_v3()
	var pk: D3 = body_pos(frame_idx, time)
	var rt: Basis = body_basis(frame_idx, time).transposed()
	return rt * (Vector3.ZERO - pk.to_v3())

func bh_pos_sys() -> D3:
	var b := sys
	var r: float = b.bh_orbit_r
	var th: float = b.bh_phase
	var x: float = r * cos(th)
	var z: float = r * sin(th)
	var si: float = sin(b.bh_incl)
	var ci: float = cos(b.bh_incl)
	return D3.new(x, -z * si, z * ci)

func viewer_sys_now() -> D3:
	if frame_idx < 0:
		return viewer_sys
	var pk: D3 = body_pos(frame_idx, time)
	var rk: Basis = body_basis(frame_idx, time)
	return pk.plus_v(rk * viewer_pos)

# ---------------------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if sys == null:
		return
	delta = minf(delta, 0.1)
	if paused:
		delta = 0.0
	time += delta * time_scale
	if actor != null and not paused:
		actor.call("step", delta)
	_update_frame()
	_place_bodies()
	_update_lighting(delta)
	if cam_driver != null:
		cam_driver.call("update_camera", self, delta)
	fill_light.global_basis = camera.global_basis * Basis.from_euler(Vector3(deg_to_rad(-38.0), deg_to_rad(28.0), 0.0))
	fill_light.light_energy = 0.55 if frame_idx < 0 else 0.2
	cam_world = camera.global_position
	var vv := Vector3.ZERO
	if actor != null and actor.get("ship") != null and int(actor.get("mode")) == 0:
		vv = (actor.get("ship") as Node3D).get("velocity")
	for p in planets:
		p.update_planet(delta, cam_world, p.body_index == frame_idx, vv)
	if bh != null:
		(bh as BlackHole).update_bh(self, delta)

func _update_frame() -> void:
	if frame_idx < 0:
		# look for a body to enter
		var best: int = -1
		var best_d: float = 1e30
		for i in sys.bodies.size():
			var b: BodyData = sys.bodies[i]
			var d: float = viewer_sys.dist(body_pos(i, time))
			if d < best_d:
				best_d = d
				best = i
			if b.landable and d < b.frame_radius:
				_enter_frame(i)
				break
		nearest_body = best
		nearest_dist = best_d
	else:
		var p: Planet = planets[frame_idx]
		var d2: float = viewer_pos.length()
		nearest_body = frame_idx
		nearest_dist = d2
		if d2 > p.data.frame_radius * FRAME_EXIT_MARGIN:
			_leave_frame()

func _enter_frame(k: int) -> void:
	var t: float = time
	var pk: D3 = body_pos(k, t)
	var rt: Basis = body_basis(k, t).transposed()
	var r_s: Vector3 = viewer_sys.rel(pk)
	var vk: Vector3 = body_vel(k, t)
	var om: Vector3 = body_omega(k, t)
	var sh: Node3D = actor.get("ship") if actor != null and actor.get("ship") != null else null
	if actor != null:
		actor.call("convert_to_planet", rt, r_s, vk, om)
	frame_idx = k
	viewer_pos = rt * r_s
	frame_changed.emit(k)

func _leave_frame() -> void:
	var k: int = frame_idx
	var t: float = time
	var pk: D3 = body_pos(k, t)
	var rk: Basis = body_basis(k, t)
	var vk: Vector3 = body_vel(k, t)
	var om: Vector3 = body_omega(k, t)
	var r_s: Vector3 = rk * viewer_pos
	if actor != null:
		actor.call("convert_to_system", rk, r_s, vk, om)
	viewer_sys = pk.plus_v(r_s)
	frame_idx = -1
	viewer_pos = Vector3.ZERO
	frame_changed.emit(-1)

func _place_bodies() -> void:
	var t: float = time
	var star_w: Vector3
	if frame_idx < 0:
		for p in planets:
			var d: D3 = body_pos(p.body_index, t)
			p.transform = Transform3D(body_basis(p.body_index, t), d.rel(viewer_sys))
		star_w = Vector3.ZERO - viewer_sys.to_v3()
		if bh != null:
			bh.position = bh_pos_sys().rel(viewer_sys)
			bh.basis = Basis.IDENTITY
	else:
		var k: int = frame_idx
		var pk: D3 = body_pos(k, t)
		var rt: Basis = body_basis(k, t).transposed()
		for p in planets:
			if p.body_index == k:
				p.transform = Transform3D.IDENTITY
			else:
				var d2: Vector3 = body_pos(p.body_index, t).rel(pk)
				p.transform = Transform3D(rt * body_basis(p.body_index, t), rt * d2)
		star_w = rt * (Vector3.ZERO - pk.to_v3())
		if bh != null:
			bh.position = rt * bh_pos_sys().rel(pk)
			bh.basis = rt
		env.sky_rotation = rt.get_euler()
	star.position = star_w
	if frame_idx < 0:
		env.sky_rotation = Vector3.ZERO
	sun_dir_view = (star_w - viewer_pos).normalized() if frame_idx >= 0 else star_w.normalized()

func _dir_from_to(from_p: Vector3, to_p: Vector3) -> Vector3:
	return (to_p - from_p).normalized()

func _look_basis(dir: Vector3) -> Basis:
	## Basis whose -Z axis points along dir
	if dir.length_squared() < 1e-8:
		return Basis.IDENTITY
	var up: Vector3 = Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(dir.normalized(), up)

func _update_lighting(delta: float) -> void:
	var star_w: Vector3 = star.position
	var active_light: DirectionalLight3D = null
	altitude = 1e9
	air = 0.0
	sun_up_at_viewer = 1.0
	for i in planets.size():
		var p: Planet = planets[i]
		var to_sun: Vector3 = (star_w - p.position).normalized()
		var power: float = _sun_power(i)
		p.set_sun(to_sun, sys.star_color, power)
		var l: DirectionalLight3D = lights[i]
		var is_active: bool = i == frame_idx
		var dir_to_sun: Vector3 = to_sun
		if is_active:
			dir_to_sun = (star_w - viewer_pos).normalized()
		l.basis = _look_basis(-dir_to_sun)
		l.position = Vector3.ZERO
		var energy: float = 2.7 * power * float(p.data.profile.get("sun_boost", 1.0))
		var lcolor: Color = sys.star_color
		if is_active:
			var up: Vector3 = viewer_pos.normalized()
			sun_up_at_viewer = up.dot(dir_to_sun)
			altitude = p.altitude_of(viewer_pos)
			air = p.air_density(viewer_pos.length() - p.data.radius)
			var atm: Dictionary = p.data.profile.get("atm", {})
			if atm.get("on", false):
				# sun dims & reddens as it sets; fades out below the horizon
				var set_f: float = U.smooth(-0.12, 0.28, sun_up_at_viewer)
				var red: Color = Color(1.0, 0.52, 0.28).lerp(Color(1, 1, 1), U.smooth(0.0, 0.5, sun_up_at_viewer))
				var tint_amt: float = air * 0.9
				lcolor = sys.star_color.lerp(sys.star_color * red, tint_amt)
				energy *= lerpf(1.0, U.smooth(-0.10, 0.10, sun_up_at_viewer), air)
			l.light_energy = energy
			l.light_color = lcolor
			l.shadow_enabled = energy > 0.05
			l.light_cull_mask = p.layer_bit | 1
			active_light = l
			_update_ambient_planet(p, delta)
		else:
			l.light_energy = energy
			l.light_color = lcolor
			l.shadow_enabled = false
			l.light_cull_mask = p.layer_bit
	if active_light == null:
		deep_light.visible = true
		deep_light.basis = _look_basis(-sun_dir_view)
		var dp: float = 1.0
		if sys.bodies.size() > 0 and nearest_body >= 0:
			dp = _sun_power(nearest_body)
		deep_light.light_energy = 2.5 * dp
		deep_light.light_color = sys.star_color
		_update_ambient_space()
	else:
		deep_light.visible = false

func _sun_power(body_i: int) -> float:
	var b: BodyData = sys.bodies[body_i]
	var top: BodyData = b
	if b.parent >= 0:
		top = sys.bodies[b.parent]
	return sys.star_dim_factor(top.orbit_r)

func _update_ambient_planet(p: Planet, _delta: float) -> void:
	var atm: Dictionary = p.data.profile.get("atm", {})
	var day: float = U.smooth(-0.22, 0.30, sun_up_at_viewer)
	if not atm.get("on", false):
		# airless: harsh sun, faint starlight / earthshine fill
		env.ambient_light_color = Color(0.40, 0.45, 0.62)
		env.ambient_light_energy = 0.22 + 0.12 * day
		return
	var amb: Color = atm["ambient"]
	var night: Color = Color(0.30, 0.40, 0.70)
	env.ambient_light_color = night.lerp(amb, day)
	var base: float = float(atm.get("ambient_e", 0.5))
	env.ambient_light_energy = base * (0.30 + 0.70 * day) * (0.35 + 0.65 * air) + 0.62 * (1.0 - day) + 0.10

func _update_ambient_space() -> void:
	env.ambient_light_color = Color(0.30, 0.34, 0.50)
	env.ambient_light_energy = 0.22

func lit_factor_at_viewer() -> float:
	return U.smooth(-0.15, 0.2, sun_up_at_viewer)

# ---------------------------------------------------------------------------------------------------------
## Test / teleport helpers
func set_viewer_system(pos: D3) -> void:
	viewer_sys = pos.copy()
	if frame_idx >= 0:
		frame_idx = -1
		viewer_pos = Vector3.ZERO

func orbit_position_near(body_i: int, altitude_m: float, dir_hint: Vector3 = Vector3(0, 0, 1)) -> D3:
	## a system-space position `altitude_m` above the surface of body `body_i` on the star-facing side
	var b: BodyData = sys.bodies[body_i]
	var pk: D3 = body_pos(body_i, time)
	var to_star: Vector3 = (Vector3.ZERO - pk.to_v3()).normalized()
	var off: Vector3 = (to_star + dir_hint * 0.25).normalized() * (b.radius + altitude_m)
	return pk.plus_v(off)
