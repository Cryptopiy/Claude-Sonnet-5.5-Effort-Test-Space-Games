class_name Creature
extends Node3D
## One wandering animal (module m7b_life).  Lives in PLANET space (= LOCAL space while the frame is anchored on the planet), child of FaunaManager (identity transform).
## Types (see FaunaTables): walker (quadruped grazer), crawler (six-legged beetle), floater (hovering jelly), flyer (flock member, analytic orbit -> deterministic in Universe.time).
## Movement happens on the sphere: direction `dir` + heading `fwd`; height from Planet.terrain_radius_at(dir).  All limb animation = rotating the named model nodes.

enum State { IDLE, WALK, FLEE }

var planet: Planet
var def: BodyDef
var species: String = ""
var spec: Dictionary = {}
var type: String = "walker"
var key: String = ""
var label: String = ""
var model: Node3D
var model_scale: float = 1.0
var grow: float = 0.0          # 0..1 spawn fade-in (model scale), dying => shrinks back to 0
var dying: bool = false
var home_dir: Vector3 = Vector3.UP
var home_r: float = 1.0
var e1: Vector3 = Vector3.RIGHT      # tangent basis at home (e1 x e2 = home_dir)
var e2: Vector3 = Vector3.BACK
var dir: Vector3 = Vector3.UP
var fwd: Vector3 = Vector3.FORWARD
var up_s: Vector3 = Vector3.UP
var cur_r: float = 1.0
var speed: float = 0.0
var state: int = State.IDLE
var state_t: float = 1.0
var target_p: Vector3 = Vector3.ZERO
var phase: float = 0.0
var gait: float = 0.0
var amp_cur: float = 0.0
var rng := RandomNumberGenerator.new()
var speed_var: float = 1.0
var sea_r: float = 0.0
var y_off: float = 0.0
var parts: Dictionary = {}
var rest: Dictionary = {}
var dist_focus: float = 0.0
var _flee_dir: Vector3 = Vector3.FORWARD
var _nrm_t: float = 0.0
var _avoid: Vector3 = Vector3.ZERO
var _hover: float = 5.0
var _lis: Array = [1.0, 1.0, 0.0, 0.0]       # floater / flyer path params
var _w: float = 0.03
var _orbit_r: float = 80.0
var _orbit_ecc: float = 1.0
var _alt: float = 40.0
var _spin: float = 1.0
var _tail_t: float = 0.0

const PART_NAMES := ["Body", "Head", "Tail", "Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR", "Leg_1", "Leg_2", "Leg_3", "Leg_4", "Leg_5", "Leg_6",
	"Wing_L", "Wing_R", "Tentacle_1", "Tentacle_2", "Tentacle_3", "Tentacle_4", "Tentacle_5", "Tentacle_6"]

func setup(p_planet: Planet, p_def: BodyDef, p_key: String, p_species: String, p_model: Node3D, p_home_dir: Vector3, p_seed: int, p_label: String) -> void:
	planet = p_planet
	def = p_def
	key = p_key
	species = p_species
	spec = FaunaTables.SPECIES[p_species]
	type = String(spec["type"])
	label = p_label
	rng.seed = p_seed
	name = "Creature_" + p_key
	add_to_group("creature")
	set_meta("species", p_species)
	set_meta("label", p_label)
	model = p_model
	add_child(model)
	for n in PART_NAMES:
		var nd := model.find_child(n, true, false) as Node3D
		if nd != null:
			parts[n] = nd
			rest[n] = nd.transform.basis
	var sc: Array = spec["scale"]
	model_scale = rng.randf_range(float(sc[0]), float(sc[1]))
	model.scale = Vector3.ONE * 0.01
	sea_r = planet.sea_radius()
	home_dir = p_home_dir
	home_r = planet.terrain_radius_at(home_dir)
	var ref := Vector3.UP if absf(home_dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	e1 = home_dir.cross(ref).normalized()
	e2 = home_dir.cross(e1).normalized()
	e2 = -e2 if e1.cross(e2).dot(home_dir) < 0.0 else e2
	phase = rng.randf() * TAU
	speed_var = rng.randf_range(0.8, 1.25)
	_spin = 1.0 if rng.randf() < 0.5 else -1.0
	match type:
		"walker", "crawler":
			var off := _rand_offset(10.0)
			dir = (home_dir * home_r + off).normalized()
			cur_r = planet.terrain_radius_at(dir)
			fwd = (e1 * cos(phase) + e2 * sin(phase)).slide(dir).normalized()
			state = State.IDLE
			state_t = rng.randf_range(0.3, 6.0)
		"floater":
			var hv: Array = spec["hover"]
			_hover = rng.randf_range(float(hv[0]), float(hv[1]))
			var leash: float = float(spec["leash"])
			_lis = [rng.randf_range(0.45, 1.0) * leash, rng.randf_range(0.45, 1.0) * leash, rng.randf_range(0.0, TAU), rng.randf_range(0.0, TAU)]
			_w = rng.randf_range(0.022, 0.05)    # angular speed of the drift path (rad/s)
			_orbit_ecc = rng.randf_range(0.7, 1.4)
			dir = home_dir
			cur_r = home_r
		"flyer":
			var orb: Array = spec["orbit"]
			var al: Array = spec["alt"]
			# flock parameters come from the flock seed (shared by every member); member offset in `phase`
			var fr := RandomNumberGenerator.new()
			fr.seed = p_seed >> 3
			_orbit_r = fr.randf_range(float(orb[0]), float(orb[1]))
			_alt = fr.randf_range(float(al[0]), float(al[1]))
			_orbit_ecc = fr.randf_range(0.7, 1.0)
			_spin = 1.0 if fr.randf() < 0.5 else -1.0
			_lis = [fr.randf_range(0.0, TAU), fr.randf_range(-30.0, 30.0), fr.randf_range(-30.0, 30.0), 0.0]
			dir = home_dir
			cur_r = home_r
	up_s = dir
	_place(0.0)

func _rand_offset(max_d: float) -> Vector3:
	var a := rng.randf() * TAU
	var d := sqrt(rng.randf()) * max_d
	return e1 * (cos(a) * d) + e2 * (sin(a) * d)

# =====================================================================================================================
func update(dt: float, ctx: Dictionary) -> void:
	var focus: Vector3 = ctx["focus"]
	dist_focus = position.distance_to(focus)
	if dying:
		grow = maxf(grow - dt * 1.2, 0.0)
	else:
		grow = minf(grow + dt * 0.8, 1.0)
	var gs := smoothstep(0.0, 1.0, grow)
	model.scale = Vector3.ONE * (model_scale * maxf(gs, 0.001))
	match type:
		"walker", "crawler":
			_update_walker(dt, ctx)
		"floater":
			_update_floater(dt, ctx)
		"flyer":
			_update_flyer(dt, ctx)

# ---------------------------------------------------------------------------------------------------------------------
# ground animals
# ---------------------------------------------------------------------------------------------------------------------
func _update_walker(dt: float, ctx: Dictionary) -> void:
	var focus: Vector3 = ctx["focus"]
	var p := position
	var up := dir
	var to_f := focus - p
	var dist := to_f.length()
	var flee_d: float = float(spec["flee"]) * float(ctx["threat"])
	var leash: float = float(spec.get("leash", 40.0))
	var home_p := home_dir * home_r
	if state != State.FLEE and dist < flee_d:
		state = State.FLEE
		state_t = 0.0
		var away := (-to_f).slide(up)
		if away.length() < 0.01:
			away = fwd
		_flee_dir = away.normalized().rotated(up, rng.randf_range(-0.6, 0.6))
	var want_speed := 0.0
	var want_dir := fwd
	match state:
		State.IDLE:
			state_t -= dt
			if state_t <= 0.0:
				_pick_target(home_p, leash)
		State.WALK:
			var to_t := (target_p - p).slide(up)
			if to_t.length() < 1.3:
				state = State.IDLE
				state_t = rng.randf_range(2.5, 9.0)
			else:
				want_dir = to_t.normalized()
				want_speed = float(spec["walk"]) * speed_var
		State.FLEE:
			state_t += dt
			want_dir = _flee_dir
			var from_home := (p - home_p).slide(up)
			if from_home.length() > leash * 2.5:
				want_dir = (want_dir - from_home.normalized() * 0.9).normalized()
			want_speed = float(spec["run"]) * speed_var
			if dist > flee_d * 1.8 and state_t > 2.5:
				state = State.IDLE
				state_t = rng.randf_range(2.0, 5.0)
	# steering
	var ang := fwd.signed_angle_to(want_dir, up)
	var turn_rate: float = float(spec["turn"]) * (2.0 if state == State.FLEE else 1.0)
	fwd = fwd.rotated(up, clampf(ang, -turn_rate * dt, turn_rate * dt))
	var slow := clampf(1.0 - absf(ang) / PI * 0.9, 0.2, 1.0)
	speed = move_toward(speed, want_speed * slow, (6.0 if state == State.FLEE else 2.5) * dt)
	if speed > 0.02:
		var step := fwd * (speed * dt)
		var nd := (up * p.length() + step).normalized()
		var nr := planet.terrain_radius_at(nd)
		var blocked := sea_r > 0.0 and nr < sea_r + 0.5
		if not blocked:
			# refuse very steep steps (cliffs): compare height change with the horizontal step
			if absf(nr - cur_r) > maxf(speed * dt * 1.6, 0.05):
				blocked = true
		if blocked:
			speed = 0.0
			fwd = fwd.rotated(up, PI * 0.6 * (1.0 if rng.randf() < 0.5 else -1.0))
			if state == State.WALK:
				state = State.IDLE
				state_t = rng.randf_range(0.5, 2.0)
		else:
			dir = nd
			cur_r = nr
	fwd = fwd.slide(dir).normalized()
	_nrm_t -= dt
	if _nrm_t <= 0.0:
		_nrm_t = 0.12 + rng.randf() * 0.1
		if dist_focus < 180.0:
			up_s = up_s.slerp(planet.normal_at(dir), 0.5).normalized()
		else:
			up_s = dir
	_place(dt)
	if dist_focus < 230.0:
		_animate_walker(dt, ctx)

func _pick_target(home_p: Vector3, leash: float) -> void:
	for tries in 4:
		var off := _rand_offset(leash)
		var d := (home_p + off).normalized()
		var r := planet.terrain_radius_at(d)
		if sea_r > 0.0 and r < sea_r + 1.0:
			continue
		if planet.normal_at(d).dot(d) < 0.82:
			continue
		target_p = d * r
		state = State.WALK
		return
	state = State.IDLE
	state_t = rng.randf_range(1.5, 4.0)

func _place(dt: float) -> void:
	var r := cur_r + y_off
	up_s = up_s.normalized()
	var f := fwd.slide(up_s)
	if f.length() < 0.001:
		f = fwd
	var b := Basis.looking_at(f.normalized(), up_s)
	transform = Transform3D(b, dir * r)

func _animate_walker(dt: float, ctx: Dictionary) -> void:
	var t: float = ctx["t"]
	var moving := clampf(speed / maxf(float(spec["walk"]), 0.1), 0.0, 1.6)
	amp_cur = move_toward(amp_cur, moving * float(spec.get("amp", 0.5)), 3.0 * dt)
	gait += speed / (float(spec["stride"]) * model_scale) * TAU * dt
	var a := amp_cur * sin(gait)
	if type == "walker":
		_rot("Leg_FL", a)
		_rot("Leg_BR", a)
		_rot("Leg_FR", -a)
		_rot("Leg_BL", -a)
		var graze := 1.0 if (state == State.IDLE and speed < 0.1) else 0.0
		var hp: Node3D = parts.get("Head")
		if hp != null:
			var tgt := -0.62 * graze * (0.6 + 0.4 * sin(t * 0.7 + phase)) + 0.07 * sin(gait * 2.0) * moving
			if state == State.FLEE:
				tgt = 0.18
			hp.transform.basis = (rest["Head"] as Basis) * Basis(Vector3.RIGHT, tgt) * Basis(Vector3.UP, 0.25 * sin(t * 0.45 + phase) * graze)
		var tl: Node3D = parts.get("Tail")
		if tl != null:
			tl.transform.basis = (rest["Tail"] as Basis) * Basis(Vector3.UP, 0.4 * sin(t * (1.6 + moving * 1.4) + phase)) * Basis(Vector3.RIGHT, 0.12 * sin(t * 0.9))
	else:
		for i in 6:
			var leg: Node3D = parts.get("Leg_%d" % (i + 1))
			if leg == null:
				continue
			var ph := gait + (PI if (i + 1) % 2 == 0 else 0.0)
			var sw := amp_cur * sin(ph)
			var lift := maxf(0.0, cos(ph)) * 0.35 * clampf(moving, 0.0, 1.0)
			var side := -1.0 if (i == 0 or i == 3 or i == 4) else 1.0      # L = -X  (legs 1, 4, 5), R = +X (2, 3, 6)
			leg.transform.basis = (rest["Leg_%d" % (i + 1)] as Basis) * Basis(Vector3.RIGHT, sw) * Basis(Vector3.BACK, side * lift)
		var hd: Node3D = parts.get("Head")
		if hd != null:
			hd.transform.basis = (rest["Head"] as Basis) * Basis(Vector3.UP, 0.3 * sin(t * 1.3 + phase) * (1.0 - moving * 0.5))

func _rot(part: String, ang: float) -> void:
	var n: Node3D = parts.get(part)
	if n != null:
		n.transform.basis = (rest[part] as Basis) * Basis(Vector3.RIGHT, ang)

# ---------------------------------------------------------------------------------------------------------------------
# floaters: Lissajous drift around the home point (deterministic) + dodge the player
# ---------------------------------------------------------------------------------------------------------------------
func _update_floater(dt: float, ctx: Dictionary) -> void:
	var t: float = ctx["t"]
	var focus: Vector3 = ctx["focus"]
	var w1 := _w
	var w2 := _w * 0.73 * _orbit_ecc
	var x := float(_lis[0]) * sin(t * w1 + float(_lis[2]))
	var y := float(_lis[1]) * sin(t * w2 + float(_lis[3]))
	var vx := float(_lis[0]) * w1 * cos(t * w1 + float(_lis[2]))
	var vy := float(_lis[1]) * w2 * cos(t * w2 + float(_lis[3]))
	var q := home_dir * home_r + e1 * x + e2 * y
	var d := q.normalized()
	var r := planet.terrain_radius_at(d)
	if sea_r > 0.0:
		r = maxf(r, sea_r)
	var h := r + _hover + 0.9 * sin(t * 0.55 + phase)
	var base := d * h
	# dodge: slide away from the viewer and up
	var to_f := focus - base
	var dist := to_f.length()
	var flee_d: float = float(spec["flee"]) * float(ctx["threat"])
	var want := Vector3.ZERO
	if dist < flee_d:
		var k := 1.0 - dist / flee_d
		want = (-to_f).slide(d).normalized() * (flee_d * k * 1.1) + d * (4.0 * k)
	_avoid = _avoid.lerp(want, 1.0 - exp(-dt * 1.2))
	var pos := base + _avoid
	var v := (e1 * vx + e2 * vy).slide(d)
	if v.length() > 0.001:
		fwd = fwd.slerp(v.normalized(), clampf(dt * 1.5, 0.0, 1.0)).normalized()
	dir = d
	cur_r = r
	up_s = d
	var f := fwd.slide(d)
	if f.length() < 0.01:
		f = e1.slide(d)
	var b := Basis.looking_at(f.normalized(), d)
	transform = Transform3D(b, pos)
	speed = v.length()
	if dist_focus < 260.0:
		_animate_floater(t)

func _animate_floater(t: float) -> void:
	var bd: Node3D = parts.get("Body")
	if bd != null:
		var s := sin(t * 2.1 + phase)
		bd.scale = Vector3(1.0 - 0.05 * s, 1.0 + 0.10 * s, 1.0 - 0.05 * s)
	for i in 6:
		var tn: Node3D = parts.get("Tentacle_%d" % (i + 1))
		if tn == null:
			continue
		var ph := phase + float(i) * 1.05
		var rb: Basis = rest["Tentacle_%d" % (i + 1)]
		tn.transform.basis = rb * Basis(Vector3.RIGHT, 0.24 * sin(t * 1.5 + ph)) * Basis(Vector3.FORWARD, 0.24 * cos(t * 1.2 + ph * 1.3))

# ---------------------------------------------------------------------------------------------------------------------
# flyers: banked circling flights, flapping with glide phases (pure function of Universe.time)
# ---------------------------------------------------------------------------------------------------------------------
func _update_flyer(dt: float, ctx: Dictionary) -> void:
	var t: float = ctx["t"]
	var w := float(spec["walk"]) / _orbit_r * _spin
	var ang := float(_lis[0]) + phase * 0.35 + t * w
	var cx := float(_lis[1]) * sin(t * 0.011 + float(_lis[0]))
	var cy := float(_lis[2]) * sin(t * 0.0083 + float(_lis[0]) * 2.0)
	var rr := _orbit_r * (1.0 + 0.08 * sin(phase * 3.0))
	var ox := cx + rr * cos(ang)
	var oy := cy + rr * _orbit_ecc * sin(ang)
	var q := home_dir * home_r + e1 * ox + e2 * oy
	var d := q.normalized()
	var r := planet.terrain_radius_at(d)
	if sea_r > 0.0:
		r = maxf(r, sea_r)
	var alt := _alt + 5.0 * sin(t * 0.37 + phase * 2.0) + 3.0 * sin(phase * 5.0)
	var pos := d * (r + alt)
	var vx := -rr * sin(ang) * w
	var vy := rr * _orbit_ecc * cos(ang) * w
	var f := (e1 * vx + e2 * vy).slide(d).normalized()
	# bank into the turn
	var left := d.cross(f)
	var bank := 0.42 * signf(w) * clampf(float(spec["walk"]) * absf(w) * 9.0, 0.0, 1.0)
	var upb := (d * cos(bank) + left * sin(bank)).normalized()
	transform = Transform3D(Basis.looking_at(f, upb), pos)
	dir = d
	cur_r = r
	speed = float(spec["walk"])
	if dist_focus < 420.0:
		var flap_f := 2.7 + 0.4 * sin(phase)
		var glide := smoothstep(0.15, 0.85, 0.5 + 0.5 * sin(t * 0.21 + phase * 3.0))
		var amp := lerpf(0.65, 0.07, glide)
		var fl := amp * sin(t * TAU * flap_f + phase) + 0.1
		var wr: Node3D = parts.get("Wing_R")
		var wl: Node3D = parts.get("Wing_L")
		if wr != null:
			wr.transform.basis = (rest["Wing_R"] as Basis) * Basis(Vector3.BACK, fl)
		if wl != null:
			wl.transform.basis = (rest["Wing_L"] as Basis) * Basis(Vector3.BACK, -fl)
		var tl: Node3D = parts.get("Tail")
		if tl != null:
			tl.transform.basis = (rest["Tail"] as Basis) * Basis(Vector3.RIGHT, 0.15 * sin(t * 2.0 + phase)) * Basis(Vector3.UP, 0.2 * sin(t * 1.3 + phase))
		var hd: Node3D = parts.get("Head")
		if hd != null:
			hd.transform.basis = (rest["Head"] as Basis) * Basis(Vector3.UP, 0.25 * sin(t * 0.8 + phase * 2.0))
