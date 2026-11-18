class_name World
extends Node3D
## Orchestrates the whole simulation every frame: orbits -> controllers -> floating origin -> placement -> camera -> lighting.
## Render origin == the focus (ship or astronaut) every frame; absolute positions are doubles (DV).

enum CamMode { CHASE, COCKPIT, FOOT3, FOOT1, MENU }

signal system_built
signal warp_started
signal jumped(info: Galaxy.StarInfo, via_bh: bool)

const STAR_ENERGY_BASE := 1.5

var galaxy: Galaxy
var star_info: Galaxy.StarInfo
var sysgen: SystemGen
var bodies: Array = []
var star: StarBody
var bh: BlackHole
var home_planet: Body
var stations: Array = []
var belt: AsteroidBelt
var t := 0.0
var time_scale := 1.0
var origin := DV.new()
var ship: Ship
var player: Player
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var bodies_root: Node3D
var cam_mode: int = CamMode.MENU
var on_foot := false
var mouse_accum := Vector2.ZERO
var test_input := {}
var cam_basis_s := Basis.IDENTITY
var cam_pos_s := Vector3.ZERO
var menu_t := 0.0
var frame_count := 0
var warp_active := false
var env_info := {}                 # data for HUD / FX
var nearest_planet: Body
var bh_dist := 1e12
var bh_zone := 0
var fx := {"speed": 0.0, "heat": 0.0, "bh": 0.0, "warp": 0.0, "flash": 0.0, "damage": 0.0, "dark": 0.0}
var fp_tool: Node3D
var fov_cur := 75.0
var props_mgr: Node = null          # PropField manager (set by main)
var extras: Array = []              # objects with update(world, dt)
var sun_dir_cam := Vector3.UP
var day_factor := 1.0
var atm_amount := 0.0
var cam_up := Vector3.UP
var cam_alt := 1e9
var last_msg_zone := -1
var transit_t := 0.0
var jump_target := -1


func _ready() -> void:
	galaxy = Game.galaxy
	bodies_root = Node3D.new()
	bodies_root.name = "Bodies"
	add_child(bodies_root)
	_make_environment()
	ship = Ship.new()
	ship.name = "Ship"
	add_child(ship)
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.visible = false
	cam = Camera3D.new()
	cam.name = "Camera"
	cam.near = 0.1
	cam.far = 1.6e6
	cam.fov = 75.0
	add_child(cam)
	cam.make_current()
	var ts: PackedScene = load("res://assets/models/multitool.glb")
	fp_tool = ts.instantiate()
	cam.add_child(fp_tool)
	fp_tool.position = Vector3(0.22, -0.2, -0.45)
	fp_tool.rotation = Vector3(0, 0, 0)
	fp_tool.visible = false
	player.died.connect(_on_player_died)
	ship.landed.connect(func(): pass)


func _make_environment() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 300.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.7
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set("glow_levels/1", 0.6)
	env.set("glow_levels/3", 1.0)
	env.set("glow_levels/5", 1.0)
	env.set("glow_levels/7", 0.8)
	env.fog_enabled = false
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.03
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ======================================================================= system building
func clear_system() -> void:
	for c in bodies_root.get_children():
		c.queue_free()
	bodies.clear()
	stations.clear()
	belt = null
	star = null
	bh = null
	home_planet = null
	for e in extras:
		if e.has_method("on_system_cleared"):
			e.on_system_cleared()


func build_system(star_id: int) -> void:
	clear_system()
	last_msg_zone = -1
	star_info = galaxy.stars[star_id]
	star_info.visited = true
	Game.visited_systems[star_id] = true
	sysgen = SystemGen.new()
	sysgen.build(star_info)
	star = StarBody.new()
	star.name = "Star"
	bodies_root.add_child(star)
	star.build(sysgen.star_radius, sysgen.star_color, sysgen.star_lum, star_info.seed)
	star.display_name = star_info.name
	for d: PlanetData in sysgen.planets:
		var p := Planet.new()
		p.name = d.name
		bodies_root.add_child(p)
		p.build(d)
		p.body_index = d.index
		if d.parent_idx >= 0:
			p.parent_body = bodies[d.parent_idx]
		else:
			p.parent_body = star
		bodies.append(p)
		if star_info.id == Galaxy.HOME_ID and d.name == "Verdant":
			home_planet = p
	if home_planet == null:
		for b: Body in bodies:
			if b.is_landable() and b.data.atmo_height > 0.0:
				home_planet = b
				break
		if home_planet == null:
			home_planet = bodies[0]
	if sysgen.bh_present:
		bh = BlackHole.new()
		bh.name = "BlackHole"
		bodies_root.add_child(bh)
		bh.build(sysgen.bh_radius, sysgen.bh_orbit, sysgen.bh_phase)
		var dst: Galaxy.StarInfo = galaxy.stars[star_info.bh_target]
		bh.dest_id = dst.id
		bh.dest_name = dst.name
	# orbital station around the first planet with an atmosphere, asteroid belt between the middle planets
	var st_host: Body = null
	if home_planet != null and home_planet.data.atmo_height > 0.0 and home_planet.data.parent_idx < 0:
		st_host = home_planet
	else:
		for b: Body in bodies:
			if b.is_landable() and b.data.atmo_height > 0.0 and b.data.parent_idx < 0:
				st_host = b
				break
	for b: Body in bodies:
		if b == st_host:
			var st := Station.new()
			st.name = "Station"
			bodies_root.add_child(st)
			st.build(b, 9000.0, "%s ORBITAL STATION" % b.display_name.to_upper())
			stations.append(st)
			break
	var outer: Array = []
	for d: PlanetData in sysgen.planets:
		if d.parent_idx < 0:
			outer.append(d.orbit_radius)
	outer.sort()
	if outer.size() >= 4:
		var mid: int = outer.size() / 2
		belt = AsteroidBelt.new()
		belt.name = "Belt"
		bodies_root.add_child(belt)
		belt.build(star, (float(outer[mid - 1]) + float(outer[mid])) * 0.5, star_info.seed + 5)
	# sky orientation: the galaxy as seen from this star
	var to_core := (-star_info.pos).normalized()
	var core_dist := star_info.pos.length()
	sky_mat.set_shader_parameter("gal_center", to_core)
	sky_mat.set_shader_parameter("gal_normal", Vector3(0.1, 0.97, 0.2).normalized())
	sky_mat.set_shader_parameter("gal_bright", clampf(1.5 - core_dist / 45000.0, 0.55, 1.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = star_info.seed
	sky_mat.set_shader_parameter("sky_seed", int(star_info.seed & 0xFFFF))
	sky_mat.set_shader_parameter("neb_col1", Color.from_hsv(rng.randf(), 0.7, 1.0))
	sky_mat.set_shader_parameter("neb_col2", Color.from_hsv(rng.randf(), 0.6, 1.0))
	sky_mat.set_shader_parameter("neb_amt", rng.randf_range(0.35, 0.9))
	t = 0.0
	for b: Body in bodies:
		b.update_state(t)
	for st in stations:
		st.update_state(t)
	if belt:
		belt.update_state(t)
	if bh:
		bh.update_state(t)
	system_built.emit()
	Game.msg("System: %s  (class %s star, %d bodies)" % [star_info.name, star_info.cls, bodies.size()], "info")


func body_by_name(n: String) -> Body:
	for b: Body in bodies:
		if b.display_name == n:
			return b
	return null


# ======================================================================= spawning
func spawn_on_surface(b: Body, dir: Vector3 = Vector3.ZERO, morning := true) -> void:
	var d := dir
	if d == Vector3.ZERO:
		d = SystemGen.find_landing_site(b.data)
	if morning:
		set_local_time(b, d, 0.5)
	(b as Planet).landing_dir = d
	ship.teleport_surface(b, d, Ship.GEAR_H + 0.1)
	ship.gear_down = true
	ship.gear_t = 1.0
	ship.is_landed = true
	ship.throttle = 0.0
	ship.hull = 100.0
	# settle exactly on the ground
	var dd := ship.lpos.normalized()
	var n := b.data.normal_at(dd, 3.0)
	var fwd := ship.lbasis.z * -1.0
	fwd = (fwd - n * fwd.dot(n)).normalized()
	ship.lbasis = Basis.looking_at(fwd, n)
	ship.lpos = dd * (b.radius + b.data.height_at(dd) + Ship.GEAR_H)
	ship._apply_gear_pose()
	# astronaut next to the ship (ship's right side)
	var right := ship.lbasis.x
	var p_pos := (ship.lpos.normalized() * b.radius + right * 9.0).normalized()
	player.place_at(b, p_pos, -ship.lbasis.x)
	player.health = 100.0
	player.protection = 100.0
	player.fuel = 100.0
	set_on_foot(true)
	cam_mode = CamMode.FOOT3
	cam_basis_s = player.world_basis()
	if props_mgr != null and props_mgr.has_method("start_pad"):
		props_mgr.start_pad(b, ship.lpos.normalized(), ship.lbasis)


## advance system time so the sun stands `target_elev` (sine of elevation) above the horizon at `dir` and is rising
func set_local_time(b: Body, dir: Vector3, target_elev: float) -> void:
	var t0 := t
	var best := t0
	var best_err := 1e9
	var period := b.data.spin_period
	for k in 144:
		var tt := t0 + period * float(k) / 144.0
		var e1 := _sun_elev_at(b, dir, tt)
		var e2 := _sun_elev_at(b, dir, tt + 25.0)
		var err := absf(e1 - target_elev) + (0.0 if e2 > e1 else 1.5)
		if err < best_err:
			best_err = err
			best = tt
	t = best
	for bb: Body in bodies:
		bb.update_state(t)


func _sun_elev_at(b: Body, dir: Vector3, tt: float) -> float:
	for bb: Body in bodies:
		bb.update_state(tt)
	var sun_l := (b.rot.transposed() * star.apos.minus(b.apos)).normalized()
	return sun_l.dot(dir)


func spawn_in_orbit(b: Body, alt: float = 9000.0) -> void:
	set_on_foot(false)
	var dir_to_star := (star.apos.minus(b.apos)).normalized()
	var side := dir_to_star.cross(Vector3.UP).normalized()
	var p := b.apos.plus(dir_to_star * (b.radius + alt) + side * 200.0)
	var look := (b.apos.minus(p)).normalized()
	ship.teleport_space(p, b.vel, Basis.looking_at(look.rotated(side, -0.3), Vector3.UP))
	ship.set_gear(false)
	ship.gear_t = 0.0
	ship._apply_gear_pose()
	ship.throttle = 0.0
	cam_mode = CamMode.CHASE
	cam_basis_s = ship.world_basis()
	ship.disabled = false


func set_on_foot(v: bool) -> void:
	on_foot = v
	player.visible = v
	ship.disabled = v
	if v:
		ship.throttle = 0.0
		ship.pulse_on = false
		Sfx.set_loop("engine", -80.0)
		Sfx.set_loop("pulse", -80.0)
	if cam_mode == CamMode.CHASE or cam_mode == CamMode.COCKPIT or cam_mode == CamMode.FOOT3 or cam_mode == CamMode.FOOT1:
		cam_mode = (CamMode.FOOT3 if v else CamMode.CHASE)


func exit_ship() -> void:
	if on_foot or not ship.is_landed or ship.frame == null:
		return
	var b := ship.frame
	var right := ship.lbasis.x
	var dirp := (ship.lpos + right * -4.2 + ship.lbasis.z * 1.0).normalized()
	player.place_at(b, dirp, ship.lbasis.x * -1.0 + ship.lbasis.z * -1.0)
	player.fwd_dir = (ship.lbasis.z * -1.0 - dirp * (ship.lbasis.z * -1.0).dot(dirp)).normalized()
	player.protection = maxf(player.protection, 60.0)
	set_on_foot(true)
	cam_basis_s = player.world_basis()
	Game.msg("Exited ship - E near the ship to board", "info")
	Sfx.play("select")


func board_ship() -> void:
	if not on_foot or ship.frame == null:
		return
	var d := (ship.lpos - player.lpos).length() if player.frame == ship.frame else 1e9
	if d > 9.0:
		Game.msg("Too far from the ship (%d m)" % int(d), "warn")
		return
	player.refill()
	set_on_foot(false)
	cam_mode = CamMode.CHASE
	cam_basis_s = ship.world_basis()
	Game.msg("Boarded - life support restored. SPACE to lift off", "good")
	Sfx.play("select")


func _on_player_died() -> void:
	Game.msg("Suit failure - emergency teleport to ship", "warn")
	player.health = 100.0
	player.protection = 100.0
	if ship.frame != null:
		var dirp := (ship.lpos + ship.lbasis.x * 6.0).normalized()
		player.place_at(ship.frame, dirp)
	Sfx.play("boom")


# ======================================================================= main step
func step(dt: float) -> void:
	frame_count += 1
	var gdt := dt * time_scale
	t += gdt
	star.update_state(t)
	for b: Body in bodies:
		b.update_state(t)
	for st in stations:
		st.update_state(t)
	if belt:
		belt.update_state(t)
	if bh:
		bh.update_state(t)
	_check_hull()
	var inp := _gather_input()
	var playing := Game.state == Game.State.PLAYING
	_bh_forces(dt)
	_space_hazards(dt)
	if on_foot:
		player.props = props_mgr
		player.sim(dt, inp.foot if playing else {})
		ship.sim(dt, self, {})
	else:
		ship.sim(dt, self, inp.ship if playing else {})
		if playing:
			ship.update_audio()
	var fa: DV = player.abs_pos() if on_foot else ship.abs_pos()
	origin = fa
	_place_all()
	_update_camera(dt)
	_update_fx(dt)
	_update_planets()
	_update_environment(dt)
	for e in extras:
		e.update(self, dt)


func _place_all() -> void:
	star.place(origin)
	for b: Body in bodies:
		b.place(origin)
	for st in stations:
		st.place(origin)
	if belt:
		belt.place(origin)
	if bh:
		bh.place(origin)
	ship.global_transform = Transform3D(ship.world_basis(), ship.abs_pos().minus(origin))
	if on_foot:
		player.global_transform = Transform3D(player.world_basis(), Vector3.ZERO)


# ======================================================================= input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Game.state == Game.State.PLAYING:
		mouse_accum += (event as InputEventMouseMotion).relative
	if Game.state != Game.State.PLAYING or warp_active:
		return
	if event.is_action_pressed("gear") and not on_foot:
		if ship.frame == null and ship.alt > 2000.0 and not ship.gear_down:
			Game.msg("Landing gear only deploys near a planet surface", "info")
		ship.set_gear(not ship.gear_down)
		Game.msg("Landing mode: gear %s" % ("DOWN - auto-descent, SPACE lift, CTRL lower" if ship.gear_down else "retracted"), "info")
	elif event.is_action_pressed("exit_ship") and not on_foot:
		if ship.is_landed:
			exit_ship()
		else:
			Game.msg("Land first (press L for landing mode)", "info")
	elif event.is_action_pressed("use") and on_foot:
		if props_mgr != null and props_mgr.has_method("interact") and props_mgr.interact(self):
			return
		board_ship()
	elif event.is_action_pressed("cam"):
		_cycle_camera()
	elif event.is_action_pressed("target"):
		cycle_target()
	elif event.is_action_pressed("untarget"):
		ship.target_body = null
		Game.msg("Target cleared", "info")
	elif event.is_action_pressed("cut") and not on_foot:
		ship.throttle = 0.0
	elif event.is_action_pressed("refill") and on_foot:
		_refill_from_inventory()
	elif event.is_action_pressed("lamp"):
		Game.lamp_enabled = not Game.lamp_enabled
		Game.msg("Lights %s" % ("on (auto at night)" if Game.lamp_enabled else "off"), "info")
	elif event.is_action_pressed("timewarp"):
		if ship.frame == null and not on_foot and ship.alt > 20000.0:
			time_scale = 1.0 if time_scale > 1.5 else 60.0
			Game.msg("Time x%d" % int(time_scale), "info")
		else:
			time_scale = 1.0


func _refill_from_inventory() -> void:
	for k in ["Sodium", "Sodium Nitrate", "Carbon", "Radon", "Pyrite", "Frost Crystal", "Helium-3", "Chromatic Metal"]:
		if int(Game.inventory.get(k, 0)) > 0:
			Game.inventory[k] -= 1
			player.protection = minf(player.protection + 55.0, 100.0)
			Game.msg("Hazard protection recharged with %s" % k, "good")
			Sfx.play("chime")
			return
	Game.msg("No resource to recharge protection - mine some (hold LMB at glowing crystals)", "warn")


func _gather_input() -> Dictionary:
	var m := mouse_accum
	mouse_accum = Vector2.ZERO
	if not test_input.is_empty():
		var ti := test_input.duplicate()
		ti["mouse"] = ti.get("mouse", Vector2.ZERO)
		return {"ship": ti, "foot": ti}
	var gear := ship.gear_down
	var up_p := Input.is_action_pressed("up")
	var dn_p := Input.is_action_pressed("down")
	var si := {
		"mouse": m,
		"roll": Input.get_axis("roll_r", "roll_l"),
		"thr": Input.get_axis("back", "fwd"),
		"strafe": Input.get_axis("left", "right"),
		"vert": (float(up_p) - float(dn_p)) if gear else 0.0,
		"boost": Input.is_action_pressed("boost"),
		"pulse": up_p and not gear,
		"brake": dn_p and not gear,
	}
	var fi := {
		"mouse": m,
		"move": Vector2(Input.get_axis("left", "right"), Input.get_axis("back", "fwd")),
		"sprint": Input.is_action_pressed("boost"),
		"jump": up_p,
		"jump_pressed": Input.is_action_just_pressed("up"),
	}
	return {"ship": si, "foot": fi}


func _cycle_camera() -> void:
	if on_foot:
		cam_mode = CamMode.FOOT1 if cam_mode == CamMode.FOOT3 else CamMode.FOOT3
	else:
		cam_mode = CamMode.COCKPIT if cam_mode == CamMode.CHASE else CamMode.CHASE
	Sfx.play("click")


func cycle_target() -> void:
	var list: Array = []
	var cur := ship.abs_pos()
	for b: Body in bodies:
		list.append([cur.dist(b.apos), b])
	if bh:
		list.append([cur.dist(bh.apos), bh])
	for st in stations:
		list.append([cur.dist(st.apos), st])
	list.append([cur.dist(star.apos), star])
	list.sort_custom(func(a, b): return a[0] < b[0])
	var idx := -1
	for i in list.size():
		if list[i][1] == ship.target_body:
			idx = i
	var nxt: Body = list[(idx + 1) % list.size()][1]
	ship.target_body = nxt
	Game.msg("Target: %s" % _body_label(nxt), "info")
	Sfx.play("beep")


func _body_label(b: Body) -> String:
	return b.display_name


# ======================================================================= black hole
func _bh_forces(dt: float) -> void:
	ship.ext_accel = Vector3.ZERO
	ship.pulse_locked = false
	bh_zone = 0
	bh_dist = 1e12
	if bh == null:
		return
	var p := ship.abs_pos()
	bh_dist = p.dist(bh.apos)
	ship.pulse_locked = bh_dist < 90000.0
	if bh_dist < BlackHole.WARN_RADIUS:
		bh_zone = 1
	if bh_dist < BlackHole.PULL_RADIUS:
		bh_zone = 2
	if bh_dist < BlackHole.PNR_NORMAL * 2.5:
		bh_zone = 3
	if bh_dist < BlackHole.PNR_BOOST * 1.15:
		bh_zone = 4
	if ship.frame == null and not on_foot:
		ship.ext_accel = bh.pull_at(p)
		if bh_dist < bh.rs * 1.02 and not warp_active:
			_enter_black_hole()
	if bh_zone != last_msg_zone:
		match bh_zone:
			1: Game.msg("WARNING: gravitational anomaly ahead - singularity detected", "warn")
			2: Game.msg("Spacetime curvature rising - pulse drive offline", "warn")
			3: Game.msg("DANGER: escape requires BOOST (Shift) pointing away", "warn")
			4: Game.msg("POINT OF NO RETURN crossed", "bad")
		if bh_zone > 0:
			Sfx.play("warn")
		last_msg_zone = bh_zone


func _check_hull() -> void:
	if ship.hull > 0.0 or warp_active or Game.state != Game.State.PLAYING:
		return
	Game.msg("HULL BREACH - emergency recovery beacon engaged", "bad")
	Sfx.play("boom")
	ship.hull = 60.0
	ship.shield = 100.0
	ship.damage_flash = 1.0
	if ship.frame != null:
		var up := ship.lpos.normalized()
		ship.lvel = Vector3.ZERO
		ship.lpos += up * 200.0
		ship.is_landed = false
	else:
		ship.vel = ship.ref_vel
	ship.throttle = 0.0
	ship.pulse_on = false


func _space_hazards(dt: float) -> void:
	if ship.frame != null or on_foot:
		return
	var p := ship.abs_pos()
	if belt != null:
		var c := belt.collide(p, 8.0)
		if c.w > 0.0:
			var n := Vector3(c.x, c.y, c.z)
			ship.apos.add_in_place(n * c.w)
			var vn := ship.vel.dot(n)
			if vn < 0.0:
				var rel := ship.rel_vel.dot(n)
				ship.vel -= n * vn * 1.4
				if absf(rel) > 8.0:
					ship._damage(absf(rel) * 0.12)
					ship.shake = 0.8
					Sfx.play("thud", 2.0, 0.7)
					Game.msg("Asteroid impact! %d%% hull" % int(ship.hull), "warn")
	for st in stations:
		var d: float = p.dist(st.apos)
		st.service_cd = maxf(st.service_cd - dt, 0.0)
		if d < 260.0 and (ship.hull < 99.5 or ship.shield < 99.5):
			ship.hull = minf(ship.hull + dt * 25.0, 100.0)
			ship.shield = minf(ship.shield + dt * 40.0, 100.0)
			if st.service_cd <= 0.0:
				Game.msg("Station beacon: repairing hull and recharging shields", "good")
				st.service_cd = 12.0
	# gas giants: crushing pressure barrier
	for b: Body in bodies:
		if b.kind == "gas":
			var dg: float = p.dist(b.apos) - b.radius
			if dg < 0.0:
				var outv := Vector3(p.x - b.apos.x, p.y - b.apos.y, p.z - b.apos.z).normalized()
				ship.apos.add_in_place(outv * (-dg + 30.0))
				var vi := ship.vel.dot(outv)
				if vi < 0.0:
					ship.vel -= outv * vi * 1.5
				ship._damage(25.0)
				ship.shake = 1.0
				Sfx.play("boom", -2.0)
				Game.msg("HULL CRUSH WARNING: atmospheric pressure of %s exceeds hull limits" % b.display_name, "bad")
			elif dg < 400.0 and frame_count % 150 == 0:
				Game.msg("Extreme atmospheric pressure ahead - turn away from %s" % b.display_name, "warn")
	var ds := p.dist(star.apos) - star.radius
	if ds < star.radius * 0.8:
		ship._damage(dt * 12.0)
		ship.shake = 0.5
		var away := Vector3(p.x - star.apos.x, p.y - star.apos.y, p.z - star.apos.z).normalized()
		ship.vel += away * 400.0 * dt
		if ds < star.radius * 0.05:
			ship.apos.add_in_place(away * 50.0)
		if frame_count % 120 == 0:
			Game.msg("WARNING: extreme stellar heat - pull away!", "bad")


func _enter_black_hole() -> void:
	warp_active = true
	Game.set_state(Game.State.WARP)
	ship.disabled = true
	ship.pulse_on = false
	Game.msg("EVENT HORIZON CROSSED - transiting to %s" % bh.dest_name, "bad")
	Sfx.play("boom", 3.0)
	Sfx.set_loop("rumble", -4.0, 0.7)
	var dest := bh.dest_id
	var tw := create_tween()
	tw.tween_property(self, "transit_t", 1.0, 4.2)
	await tw.finished
	await _swap_system(dest, true)
	Sfx.set_loop("rumble", -80.0)
	warp_active = false
	transit_t = 0.0
	Game.set_state(Game.State.PLAYING)


# ======================================================================= hyperjump (galaxy map)
func can_jump() -> String:
	if on_foot:
		return "Return to your ship first"
	if ship.frame != null:
		return "Hyperdrive needs open space (leave the atmosphere)"
	if ship.alt < 15000.0:
		return "Too close to a planet (%d km): fly farther out" % int(ship.alt / 1000.0)
	if bh != null and bh_dist < 120000.0:
		return "Gravity well interference"
	return ""


func jump_to_star(id: int) -> void:
	var why := can_jump()
	if why != "":
		Game.msg(why, "warn")
		return
	if warp_active:
		return
	warp_active = true
	jump_target = id
	ship.disabled = true
	Game.set_state(Game.State.WARP)
	Game.msg("Hyperdrive charging... jumping to %s (%.0f ly)" % [galaxy.stars[id].name, galaxy.stars[id].pos.distance_to(star_info.pos)], "good")
	Sfx.play("warp")
	warp_started.emit()
	var tw := create_tween()
	tw.tween_property(self, "transit_t", 1.0, 3.0)
	await tw.finished
	await _swap_system(id, false)
	warp_active = false
	transit_t = 0.0
	Game.set_state(Game.State.PLAYING)


func _swap_system(id: int, via_bh: bool) -> void:
	var fl := create_tween()
	fx.dark = 0.0
	fl.tween_property(self, "fx:flash", 1.0, 0.35)
	await fl.finished
	var old := star_info
	build_system(id)
	# arrival point: sunlit side ~200 km from the star, between the inner planets
	var rng := RandomNumberGenerator.new()
	rng.seed = star_info.seed + 3
	var ang := rng.randf() * TAU
	var rdist := 150000.0 * sqrt(star_info.size_mul) + 60000.0
	var p := DV.new(cos(ang) * rdist, rng.randf_range(-8000.0, 8000.0), sin(ang) * rdist)
	var look := Vector3(-p.x, -p.y, -p.z).normalized()
	ship.teleport_space(p, look * -250.0 if via_bh else Vector3.ZERO, Basis.looking_at(look, Vector3.UP))
	ship.set_gear(false)
	ship.gear_t = 0.0
	ship.throttle = 0.2
	ship.target_body = null
	set_on_foot(false)
	cam_mode = CamMode.CHASE
	cam_basis_s = ship.world_basis()
	ship.disabled = false
	jumped.emit(star_info, via_bh)
	if via_bh:
		Game.msg("Emerged from the singularity: %s - %.0f light years from %s" % [star_info.name, star_info.pos.distance_to(old.pos), old.name], "good")
	else:
		Game.msg("Arrived at %s" % star_info.name, "good")
	var fo := create_tween()
	fo.tween_property(self, "fx:flash", 0.0, 1.4)
	await fo.finished


# ======================================================================= camera
func _update_camera(dt: float) -> void:
	var target_fov := Game.fov_base
	var shake_amt := 0.0
	if cam_mode == CamMode.MENU:
		menu_t += dt
		var wb := ship.world_basis()
		var a := menu_t * 0.12
		var off := wb * Vector3(sin(a) * 26.0, 5.0 + sin(a * 0.7) * 2.0, cos(a) * 26.0)
		cam.global_position = off
		cam.look_at(wb * Vector3(0, 0.5, 0), Vector3.UP)
		return
	if on_foot:
		_foot_camera(dt)
		shake_amt = player.shake
	else:
		_ship_camera(dt)
		shake_amt = ship.shake
		target_fov += fx.speed * 30.0
	shake_amt += fx.bh * fx.bh * 0.4 + fx.heat * 0.12
	if shake_amt > 0.001:
		var s := shake_amt * 0.05
		cam.global_position += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
		cam.rotation += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s)) * 0.3
	fov_cur = lerpf(fov_cur, target_fov, 1.0 - exp(-dt * 5.0))
	cam.fov = fov_cur
	# near/far ratio must stay moderate or Godot's frustum maths breaks (everything gets culled)
	var close := on_foot or cam_alt < 4000.0
	cam.near = 0.1 if close else 0.6
	cam.far = 1.6e6 if close else 4.0e6
	fp_tool.visible = on_foot and cam_mode == CamMode.FOOT1 and player.mining


func _ship_camera(dt: float) -> void:
	var sb := ship.world_basis()
	var lag := 7.0 - 4.5 * clampf(ship.pulse_spool, 0.0, 1.0)
	cam_basis_s = cam_basis_s.orthonormalized().slerp(sb, 1.0 - exp(-dt * lag)).orthonormalized()
	if cam_mode == CamMode.COCKPIT:
		cam.global_transform = Transform3D(sb, sb * Vector3(0, 0.84, -0.95))
		ship.set_cockpit_visible(false)
	else:
		ship.set_cockpit_visible(true)
		var dist := 15.5 + clampf(ship.speed / 400.0, 0.0, 1.0) * 3.0 + ship.pulse_spool * 4.0
		var pos := cam_basis_s * Vector3(0.0, 4.6, dist)
		# keep the chase camera above terrain
		if ship.frame != null:
			var fr := ship.frame
			var local_cam := ship.lpos + (fr.rot.transposed() * pos)
			var d := local_cam.length()
			var gr := fr.radius + fr.data.height_at(local_cam / d) + 2.0
			if d < gr:
				pos += (fr.rot * (local_cam / d)) * (gr - d)
		var tgt := cam_basis_s * Vector3(0.0, 1.4, -22.0)
		cam.global_position = pos
		cam.look_at(tgt, cam_basis_s.y)


func _foot_camera(dt: float) -> void:
	var fr := player.frame
	var up_l := player.lpos.normalized()
	var look_l := player.fwd_dir * cos(player.pitch) + up_l * sin(player.pitch)
	var right_l := player.fwd_dir.cross(up_l)
	var up_w := fr.rot * up_l
	var look_w := fr.rot * look_l
	if cam_mode == CamMode.FOOT1:
		var head := fr.rot * (up_l * Player.EYE_H)
		cam.global_transform = Transform3D(Basis.looking_at(look_w, up_w), head)
		player.model.visible = false
	else:
		player.model.visible = true
		var head_l := up_l * 1.55 + right_l * 0.45
		var dist := 4.4
		var cam_l := head_l - look_l * dist + up_l * 0.25
		# avoid clipping into terrain
		var cp := player.lpos + cam_l
		var d := cp.length()
		var gr := fr.radius + fr.data.height_at(cp / d) + 0.7
		if d < gr:
			cam_l += up_l * (gr - d)
		var pos_w := fr.rot * cam_l
		var aim := fr.rot * (head_l + look_l * 20.0)
		cam.global_position = pos_w
		cam.look_at(aim, up_w)


# ======================================================================= FX state
func _update_fx(dt: float) -> void:
	var sp := 0.0
	if not on_foot:
		sp = clampf(ship.speed / 1800.0, 0.0, 0.7) + ship.pulse_spool * 0.9
		if ship.boosting:
			sp = maxf(sp, 0.25)
	fx.speed = lerpf(fx.speed, clampf(sp, 0.0, 1.0), 1.0 - exp(-dt * 4.0))
	fx.heat = ship.entry_heat if not on_foot else 0.0
	fx.damage = ship.damage_flash
	var bhfx := 0.0
	if bh != null and bh_dist < 70000.0:
		bhfx = clampf(1.0 - (bh_dist - bh.rs) / 70000.0, 0.0, 1.0)
		bhfx = pow(bhfx, 1.6)
	fx.bh = lerpf(fx.bh, bhfx, 1.0 - exp(-dt * 3.0))
	# transit/jump tunnel
	if warp_active:
		fx.warp = transit_t
	else:
		fx.warp = move_toward(fx.warp, 0.0, dt * 1.5)
	if bh != null and not warp_active:
		if fx.bh > 0.02:
			Sfx.set_loop("rumble", -34.0 + fx.bh * 26.0, 0.6 + fx.bh * 0.4)
		else:
			Sfx.set_loop("rumble", -80.0)


# ======================================================================= planets / environment
func _update_planets() -> void:
	var cp := cam.global_position
	var sdist := (star.global_position - cp).length()
	star.corona_mat.set_shader_parameter("global_fade", clampf(sdist / (star.radius * 14.0), 0.18, 1.0))
	var col := star.star_color
	var star_pos := star.global_position
	var lum := star.light_energy / STAR_ENERGY_BASE
	for i in bodies.size():
		var b: Planet = bodies[i]
		var sd := (star_pos - b.global_position).normalized()
		var d := (b.global_position - cp).length() - b.radius
		var full := (frame_count + i) % 6 == 0 or d < b.radius * 30.0
		b.update_visuals(cp, sd, col, 20.0 * lum, full)


func _update_environment(dt: float) -> void:
	var cp := cam.global_position
	# nearest body with an atmosphere or terrain
	var best: Body = null
	var bd := 1e30
	for b: Body in bodies:
		var d := (b.global_position - cp).length() - b.radius
		if d < bd:
			bd = d
			best = b
	nearest_planet = best
	var sd := (star.global_position - cp).normalized()
	sun_dir_cam = sd
	var up := Vector3.UP
	var alt := 1e9
	var atm := 0.0
	var atm_in := 0.0
	var data: PlanetData = best.data if best != null else null
	if best != null:
		var rel := cp - best.global_position
		var dc := rel.length()
		up = rel / dc
		alt = dc - best.radius
		if data != null and data.atmo_height > 0.0:
			atm = best.atmosphere_density_at(maxf(alt, 0.0))
			atm_in = clampf(atm * 2.5, 0.0, 1.0)
	cam_up = up
	cam_alt = alt
	atm_amount = atm_in
	var elev := sd.dot(up)
	var day := smoothstep(-0.10, 0.07, elev)
	day_factor = lerpf(1.0, day, atm_in)
	# directional light
	var lum := star.light_energy
	sun.light_energy = lum * day_factor
	var redden := atm_in * (1.0 - smoothstep(0.0, 0.32, elev))
	var lc := star.star_color.lerp(Color(1.0, 0.5, 0.25), clampf(redden * 0.85, 0.0, 1.0))
	sun.light_color = lc
	sun.look_at_from_position(Vector3.ZERO, -sd, Vector3.UP if absf(sd.y) < 0.98 else Vector3.RIGHT)
	# shadows only matter close to a surface or the ship
	sun.directional_shadow_max_distance = 320.0 if (alt < 6000.0 or true) else 60.0
	# ambient / fog / sky
	var amb := Color(0.012, 0.014, 0.022)
	if on_foot or cam_alt < 3000.0:
		amb = Color(0.03, 0.036, 0.055)       # starlight
	var fog_on := false
	if data != null and atm_in > 0.01:
		var beta := data.atmo_beta
		var zen := Color(beta.x, beta.y, beta.z) / maxf(maxf(beta.x, beta.y), beta.z)
		zen = zen.lerp(Color.WHITE, 0.2)
		var haze := data.atmo_haze
		amb = (zen * 0.5 + haze * 0.5) * (0.22 * day_factor + 0.012) * lerpf(0.0, 1.0, atm_in)
		amb += Color(0.03, 0.036, 0.055)
		fog_on = true
		env.fog_enabled = true
		env.fog_light_color = (haze * (0.12 + 0.88 * day_factor)).lerp(Color(0.02, 0.02, 0.04), 1.0 - day_factor) * Color(lc.r, lc.g, lc.b).lerp(Color.WHITE, 0.6)
		env.fog_density = data.fog_density * clampf(atm_in, 0.0, 1.0) * (1.0 + _storm_level() * 2.2)
		env.fog_aerial_perspective = 0.6
		env.fog_sun_scatter = 0.25 * day_factor
		sky_mat.set_shader_parameter("refl_zenith", zen.lerp(Color.WHITE, 0.4) * (0.1 + day_factor * 0.8))
		sky_mat.set_shader_parameter("refl_horizon", haze * (0.1 + day_factor * 0.8))
		sky_mat.set_shader_parameter("refl_amt", atm_in * 0.5)
	else:
		env.fog_enabled = false
		sky_mat.set_shader_parameter("refl_amt", 0.0)
	if data != null and data.atmo_height <= 0.0 and alt < 20000.0:
		amb = Color(0.03, 0.03, 0.035)
	env.ambient_light_color = amb
	env.ambient_light_energy = 1.0
	sky_mat.set_shader_parameter("up_vec", up)
	sky_mat.set_shader_parameter("refl_sun_dir", sd)
	sky_mat.set_shader_parameter("refl_sun_col", lc)
	sky_mat.set_shader_parameter("day_dim", clampf(day_factor * atm_in * 0.97, 0.0, 0.97))
	env_info = {"alt": alt, "atm": atm_in, "day": day_factor, "elev": elev}
	var dark := elev < 0.05 and alt < 4000.0 and best != null and best.is_landable()
	player.lamp.visible = on_foot and dark and Game.lamp_enabled
	ship.nose_light.visible = (not on_foot) and dark and alt < 2500.0 and Game.lamp_enabled


func _storm_level() -> float:
	if props_mgr != null and props_mgr.get("wind_level") != null:
		return clampf(float(props_mgr.wind_level), 0.0, 1.0)
	return 0.0


func star_distance() -> float:
	return star.global_position.length()


## screen position of a render-space point (for HUD markers); returns Vector3(x, y, visible 0/1)
func project(p: Vector3) -> Vector3:
	if cam.is_position_behind(p):
		return Vector3(0, 0, 0)
	var sp := cam.unproject_position(p)
	return Vector3(sp.x, sp.y, 1.0)
