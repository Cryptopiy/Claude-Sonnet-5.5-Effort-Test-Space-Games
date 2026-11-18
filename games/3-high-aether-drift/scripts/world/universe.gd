class_name Universe
extends Node3D
## Owns the current star system: bodies on orbits, the star, the black hole, sun light, sky and fog.
##
## Floating origin: every body keeps a double-precision position `upos` (universe coordinates). The Godot nodes live
## in a frame whose origin follows the player (`origin`), so geometry near the camera always has small, precise
## float32 coordinates. Moving bodies drag the ship along smoothly (frame carry) so planets never slide under it.

signal system_loaded(system: StarSystem)

const SKY_SHADER := preload("res://shaders/sky.gdshader")
const REBASE_DIST := 1500.0

var galaxy: Galaxy
var system: StarSystem
var bodies: Array = []
var star: StarBody
var bh: BlackHole = null
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var env: Environment
var sky_mat: ShaderMaterial
var origin: Array = [0.0, 0.0, 0.0]
var sim_time: float = 0.0
var star_world: Vector3 = Vector3.ZERO
var info: Dictionary = {}  # per-frame environment summary for HUD / actors
var _sun_energy_target: float = 2.0
var _first_env: bool = true
var frame_wt: Array = []
var frame_wr: Array = []


func _ready() -> void:
	_setup_environment()


func _setup_environment() -> void:
	env = Environment.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.055, 0.07)
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 2.0
	env.set("glow_blend_mode", Environment.GLOW_BLEND_MODE_SCREEN)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0
	env.fog_sky_affect = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 450.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.2
	sun.directional_shadow_split_3 = 0.5
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 0.4
	add_child(sun)


# ------------------------------------------------------------------ system loading
func clear_system() -> void:
	for b in bodies:
		if is_instance_valid(b):
			b.queue_free()
	bodies.clear()
	if star:
		star.queue_free()
		star = null
	if bh:
		bh.queue_free()
		bh = null


func load_system(sys: StarSystem, origin_hint: Vector3 = Vector3.ZERO) -> void:
	clear_system()
	system = sys
	sim_time = 0.0
	for i in sys.bodies.size():
		var pb := PlanetBody.new()
		add_child(pb)
		pb.setup(sys.bodies[i], i)
		bodies.append(pb)
	star = StarBody.new()
	add_child(star)
	star.setup(sys.star_radius, sys.star_color)
	if not sys.black_hole.is_empty():
		bh = BlackHole.new()
		add_child(bh)
		bh.setup(sys.black_hole)
		var p: Vector3 = sys.black_hole["pos"]
		bh.upos = [p.x, p.y, p.z]
	# galaxy backdrop orientation / colours from the system's position in the galaxy
	var gp := sys.galaxy_pos
	var n := Vector3(0.12, 0.97, 0.2).normalized()
	var to_c := Vector3(-gp.x, 0.0, -gp.z).normalized()
	var c := (to_c - n * to_c.dot(n)).normalized()
	sky_mat.set_shader_parameter("galaxy_n", n)
	sky_mat.set_shader_parameter("galaxy_c", c)
	var rng := RandomNumberGenerator.new()
	rng.seed = sys.seed
	sky_mat.set_shader_parameter("neb_a", Color.from_hsv(rng.randf(), 0.6, 0.8))
	sky_mat.set_shader_parameter("neb_b", Color.from_hsv(rng.randf(), 0.5, 0.8))
	sun.light_color = sys.star_color
	_update_orbits(0.0, true)
	system_loaded.emit(sys)


# ------------------------------------------------------------------ coordinates
func to_world(u: Array) -> Vector3:
	return Vector3(u[0] - origin[0], u[1] - origin[1], u[2] - origin[2])


func world_to_u(p: Vector3) -> Array:
	return [origin[0] + p.x, origin[1] + p.y, origin[2] + p.z]


func set_origin_at_world(p: Vector3) -> void:
	## make world point p the new origin (shift everything by -p)
	origin = [origin[0] + p.x, origin[1] + p.y, origin[2] + p.z]
	_apply_positions()


func _orbit_pos(i: int, t: float) -> Array:
	var d: PlanetData = system.bodies[i]
	var c: Array = [0.0, 0.0, 0.0]
	if d.parent >= 0:
		c = bodies[d.parent].upos
	var ang := d.orbit_phase + TAU * t / d.orbit_period
	var r := d.orbit_r
	return [c[0] + cos(ang) * r, c[1] + sin(d.orbit_incl) * sin(ang) * r, c[2] + sin(ang) * r * cos(d.orbit_incl)]


func _planet_basis(d: PlanetData, t: float) -> Basis:
	return Basis(Vector3.RIGHT, d.axis_tilt) * Basis(Vector3.UP, d.spin_phase + TAU * t / d.spin_period)


func _update_orbits(dt: float, snap: bool = false) -> void:
	for i in bodies.size():
		var b: PlanetBody = bodies[i]
		var u := _orbit_pos(i, sim_time)
		if dt > 0.0:
			b.vel_u = Vector3(u[0] - b.upos[0], u[1] - b.upos[1], u[2] - b.upos[2]) / dt
		b.upos = u
	_apply_positions()


func _apply_positions() -> void:
	for i in bodies.size():
		var b: PlanetBody = bodies[i]
		b.position = to_world(b.upos)
		b.basis = _planet_basis(b.data, sim_time)
	if star:
		star.position = to_world(star.upos)
	if bh:
		bh.position = to_world(bh.upos)
		bh.scale = Vector3.ONE


## Advance simulation. `ship` (optional) is dragged along by nearby moving/rotating bodies.
func advance(dt: float, ship: Node3D, ship_vel_ref: Array) -> void:
	var old_pos: Array = []
	for b in bodies:
		old_pos.append((b as PlanetBody).global_position)
	var spin_prev: Array = []
	sim_time += dt
	_update_orbits(dt)
	if ship == null:
		frame_wt.clear()
		frame_wr.clear()
		return
	# frame carry: the ship is dragged by the body it is closest to (relative to that body's size); weights are
	# smoothed so switching between bodies never makes the ship jump.
	var sp := ship.global_position
	var cand := -1
	var best_rel := 1e30
	for i in bodies.size():
		var b: PlanetBody = bodies[i]
		var rel := (sp.distance_to(old_pos[i]) - b.data.radius) / b.data.radius
		if rel < best_rel:
			best_rel = rel
			cand = i
	var fresh := frame_wt.is_empty()
	while frame_wt.size() < bodies.size():
		frame_wt.append(0.0)
		frame_wr.append(0.0)
	var wt: Array = []
	var wr: Array = []
	for i in bodies.size():
		var b: PlanetBody = bodies[i]
		var d := sp.distance_to(old_pos[i])
		var R := b.data.radius
		var tt := (1.0 - smoothstep(4.0 * R, 20.0 * R, d)) if i == cand else 0.0
		var tr := (1.0 - smoothstep(1.6 * R, 4.5 * R, d)) if i == cand else 0.0
		var rate := dt * 0.6
		if fresh:
			frame_wt[i] = tt
			frame_wr[i] = tr
		else:
			frame_wt[i] = move_toward(frame_wt[i], tt, rate)
			frame_wr[i] = move_toward(frame_wr[i], tr, rate)
		wt.append(frame_wt[i])
		wr.append(frame_wr[i])
	var nt := 1.0
	var nr := 1.0
	var vel: Vector3 = ship_vel_ref[0]
	for i in bodies.size():
		var b: PlanetBody = bodies[i]
		if wt[i] > 0.0001:
			var dpos: Vector3 = b.global_position - old_pos[i]
			ship.global_position += dpos * (wt[i] / nt)
		if wr[i] > 0.0001:
			var axis: Vector3 = (b.global_transform.basis * Vector3.UP).normalized()
			var ang: float = TAU * dt / b.data.spin_period * (wr[i] / nr)
			var rel := ship.global_position - b.global_position
			rel = rel.rotated(axis, ang)
			ship.global_position = b.global_position + rel
			ship.global_basis = (Basis(axis, ang) * ship.global_basis).orthonormalized()
			vel = vel.rotated(axis, ang)
	ship_vel_ref[0] = vel


## Keep the actor close to the origin (call after actors moved). Returns shift applied.
func rebase(actor_world: Vector3, shiftables: Array) -> Vector3:
	if actor_world.length() < REBASE_DIST:
		return Vector3.ZERO
	var sh := actor_world
	origin = [origin[0] + sh.x, origin[1] + sh.y, origin[2] + sh.z]
	_apply_positions()
	for n in shiftables:
		if is_instance_valid(n) and (n as Node3D).get_parent() == self:
			(n as Node3D).position -= sh
	return sh


# ------------------------------------------------------------------ queries
func nearest_body(world_pos: Vector3) -> PlanetBody:
	var best: PlanetBody = null
	var best_d := 1e30
	for b in bodies:
		var pb: PlanetBody = b
		var d := world_pos.distance_to(pb.global_position) - pb.data.radius
		if d < best_d:
			best_d = d
			best = pb
	return best


func altitude_above(b: PlanetBody, world_pos: Vector3) -> float:
	return b.altitude_local(b.to_local(world_pos))


func black_hole_rel(world_pos: Vector3) -> Vector3:
	if bh == null:
		return Vector3.ZERO
	return world_pos - bh.global_position


# ------------------------------------------------------------------ environment (sky, light, fog)
func update_environment(cam_pos: Vector3, dt: float) -> void:
	star_world = to_world(star.upos) if star else Vector3.ZERO
	var best: PlanetBody = null
	var best_w := 0.0
	var best_alt := 1e30
	var nearest: PlanetBody = null
	var nearest_alt := 1e30
	for b in bodies:
		var pb: PlanetBody = b
		pb.set_sun((star_world - pb.global_position).normalized())
		var local := pb.to_local(cam_pos)
		var l := local.length()
		var alt := l - pb.data.radius
		var atm_fade := 1.0
		if pb.data.has_atmo:
			atm_fade = clampf(alt / maxf(pb.data.atmosphere_top(), 1.0), 0.0, 1.0)
		pb.update_visuals(cam_pos, dt, atm_fade)
		if alt < nearest_alt:
			nearest_alt = alt
			nearest = pb
		if pb.data.has_atmo:
			var w := exp(-maxf(alt, 0.0) / (pb.data.radius * 0.17))
			if alt < 0.0:
				w = 1.0
			if w > best_w:
				best_w = w
				best = pb
				best_alt = alt
	var to_star := (star_world - cam_pos)
	var sun_dir := to_star.normalized() if to_star.length() > 1.0 else Vector3(0, 0, -1)
	var sun_h := 1.0
	var up := Vector3.UP
	var atm := 0.0
	if best:
		up = (cam_pos - best.global_position).normalized()
		sun_h = up.dot(sun_dir)
		atm = best_w
	elif nearest and nearest_alt < nearest.data.radius * 0.5:
		up = (cam_pos - nearest.global_position).normalized()
		sun_h = up.dot(sun_dir)
	# eclipse / night: any body between us and the star?
	var lit := 1.0
	for b in bodies:
		var pb: PlanetBody = b
		var rel := cam_pos - pb.global_position
		var dist := rel.length()
		var R := pb.data.radius
		if dist < R * 1.6:
			var h := rel.normalized().dot(sun_dir)
			lit = minf(lit, smoothstep(-0.05, 0.05, h))
		else:
			var tc := -rel.dot(sun_dir)
			if tc < 0.0:
				var dc := (rel + sun_dir * tc).length()
				lit = minf(lit, smoothstep(R * 0.98, R * 1.02, dc))
	var energy: float = system.star_energy * 0.82 * lit
	sun.light_energy = lerpf(sun.light_energy, energy, 1.0 if _first_env else minf(dt * 8.0, 1.0))
	var warm := Color(1.0, 0.55, 0.3)
	var sc := system.star_color
	if best:
		sc = sc.lerp(warm, 1.0 - smoothstep(0.0, 0.3, sun_h)) if sun_h > -0.05 else sc
	sun.light_color = sc
	var upv := Vector3.UP if absf(sun_dir.y) < 0.95 else Vector3.RIGHT
	sun.global_transform = Transform3D(Basis.looking_at(-sun_dir, upv), cam_pos)
	# sky + ambient + fog
	var d: PlanetData = best.data if best else null
	var day := smoothstep(-0.16, 0.2, sun_h) if best else 1.0
	var zen := Color(0.1, 0.3, 0.8)
	var hor := Color(0.6, 0.8, 0.95)
	var twi := Color(1.0, 0.5, 0.3)
	var fog_c := Color(0.6, 0.7, 0.9)
	var fog_d := 0.0
	if d:
		zen = d.sky["zenith"]
		hor = d.sky["horizon"]
		twi = d.sky["twilight"]
		fog_c = d.sky["fog"]
		fog_d = d.sky["fog_d"]
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("up_dir", up)
	sky_mat.set_shader_parameter("atm", atm)
	sky_mat.set_shader_parameter("zenith", zen)
	sky_mat.set_shader_parameter("horizon", hor)
	sky_mat.set_shader_parameter("twilight", twi)
	sky_mat.set_shader_parameter("sun_col", system.star_color.lerp(Color.WHITE, 0.3))
	# ambient
	var amb_day := hor.lerp(zen, 0.5) * 0.55
	var amb_night := Color(0.12, 0.14, 0.22)
	var amb_space := Color(0.045, 0.05, 0.065)
	var amb := amb_space
	if best:
		amb = amb_night.lerp(amb_day, day).lerp(amb_space, 1.0 - atm)
		if best.data.biome == "barren":
			amb = amb_space
	env.ambient_light_color = amb
	env.ambient_light_energy = 1.0
	env.fog_density = fog_d * atm
	env.fog_enabled = fog_d * atm > 0.00002
	var fc := fog_c * (0.06 + 0.94 * day)
	env.fog_light_color = fc
	env.fog_sun_scatter = 0.12 * day
	env.fog_sky_affect = 0.0
	env.tonemap_exposure = 1.0
	_first_env = false
	info = {
		"atm": atm, "day": day, "sun_h": sun_h, "up": up, "planet": best, "nearest": nearest,
		"nearest_alt": nearest_alt, "sun_dir": sun_dir, "lit": lit, "alt": best_alt,
	}
