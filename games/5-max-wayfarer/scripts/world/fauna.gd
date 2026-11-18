class_name FaunaManager
extends Node3D
## Wildlife around the player on landable planets: ground grazers and crawlers (walk on the analytic terrain, flee from
## the player), floating jellyfish-like drifters and flying gliders. Species come from the biome's "fauna" list.

const KIND_MODEL := {"grazer": "creature_grazer", "floater": "creature_floater", "flyer": "creature_flyer", "crawler": "creature_crawler"}
const KIND_TARGET := {"grazer": 5, "floater": 4, "flyer": 4, "crawler": 6}
const SPAWN_MIN: float = 55.0
const SPAWN_MAX: float = 190.0
const DESPAWN: float = 270.0

class Creature:
	extends Node3D
	var kind: String = "grazer"
	var planet: Planet
	var model: Node3D
	var parts: Dictionary = {}
	var heading: Vector3 = Vector3.FORWARD
	var speed: float = 1.5
	var target_speed: float = 1.5
	var wander_t: float = 0.0
	var phase: float = 0.0
	var hover: float = 0.0
	var center: Vector3 = Vector3.ZERO
	var orbit_r: float = 40.0
	var orbit_dir: float = 1.0
	var bob: float = 0.0
	var species: String = ""
	var fleeing: bool = false
	var _t: float = 0.0
	var _nrm: Vector3 = Vector3.UP
	var _frame: int = 0

	func setup_creature(k: String, pl: Planet, sp: String) -> void:
		kind = k
		planet = pl
		species = sp
		model = Models.instantiate(FaunaManager.KIND_MODEL[k])
		add_child(model)
		_set_layers(model)
		for nm in ["Body", "Head", "Tail", "Bell", "Wing_L", "Wing_R", "Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR", "Leg_1", "Leg_2", "Leg_3", "Leg_4", "Leg_5", "Leg_6"]:
			var n: Node = model.find_child(nm, true, false)
			if n != null:
				parts[nm] = n
		for i in 8:
			var tn: Node = model.find_child("Tentacle_%02d" % (i + 1), true, false)
			if tn != null:
				parts["Tentacle_%d" % i] = tn
		phase = randf() * TAU
		match k:
			"grazer":
				target_speed = 1.6
				hover = 0.0
			"crawler":
				target_speed = 2.6
			"floater":
				target_speed = 0.9
				hover = randf_range(5.0, 34.0)
			"flyer":
				target_speed = 13.0
				hover = randf_range(30.0, 85.0)
				orbit_r = randf_range(35.0, 80.0)
				orbit_dir = 1.0 if randf() < 0.5 else -1.0
		add_to_group("fauna")

	func _set_layers(n: Node) -> void:
		if n is VisualInstance3D:
			(n as VisualInstance3D).layers = planet.layer_bit | 1
		for c in n.get_children():
			_set_layers(c)

	func surface_up() -> Vector3:
		return position.normalized()

	func ground_r(dir: Vector3) -> float:
		return planet.data.radius + planet.ground_height(dir)

	func step(delta: float, player_pos: Vector3) -> void:
		_t += delta
		_frame += 1
		var up: Vector3 = position.normalized()
		var to_p: Vector3 = player_pos - position
		var dist_p: float = to_p.length()
		wander_t -= delta
		match kind:
			"grazer", "crawler":
				var flee_d: float = 9.0 if kind == "grazer" else 6.0
				fleeing = dist_p < flee_d
				if fleeing:
					var away: Vector3 = -(to_p - up * to_p.dot(up))
					if away.length_squared() > 0.01:
						heading = heading.lerp(away.normalized(), 1.0 - exp(-4.0 * delta)).normalized()
					speed = lerpf(speed, target_speed * 3.6, 1.0 - exp(-4.0 * delta))
				elif wander_t <= 0.0:
					wander_t = randf_range(2.5, 7.0)
					if randf() < 0.35:
						speed = 0.0
					else:
						speed = target_speed * randf_range(0.5, 1.0)
						heading = heading.rotated(up, randf_range(-1.6, 1.6))
				heading = (heading - up * heading.dot(up)).normalized() if (heading - up * heading.dot(up)).length_squared() > 0.001 else U.any_perp(up)
				var step_v: Vector3 = heading * speed * delta
				var np: Vector3 = (position + step_v).normalized()
				var gr: float = ground_r(np)
				# do not walk into the sea / lava
				var blocked: bool = false
				if planet.gen != null and planet.gen.has_sea and gr - planet.data.radius < planet.gen.sea_h + 0.8:
					blocked = true
				if planet.gen != null and planet.gen.has_lava and gr - planet.data.radius < planet.gen.lava_h + 12.0:
					blocked = true
				if blocked:
					heading = -heading
					speed = target_speed * 0.6
				else:
					position = np * (gr + 0.02)
				if _frame % 3 == 0:
					var e: float = 1.2 / planet.data.radius
					var t1: Vector3 = U.any_perp(np)
					var h0: float = ground_r(np)
					var hx: float = ground_r((np + t1 * e).normalized())
					var hz: float = ground_r((np + np.cross(t1) * e).normalized())
					_nrm = (np * 1.0 - t1 * ((hx - h0) / 1.2) - np.cross(t1) * ((hz - h0) / 1.2)).normalized()
				basis = U.basis_from_up(up.lerp(_nrm, 0.7).normalized(), heading)
				_animate_legs(delta, speed)
			"floater":
				if wander_t <= 0.0:
					wander_t = randf_range(5.0, 12.0)
					heading = heading.rotated(up, randf_range(-1.8, 1.8))
				heading = (heading - up * heading.dot(up)).normalized() if (heading - up * heading.dot(up)).length_squared() > 0.001 else U.any_perp(up)
				var np2: Vector3 = (position + heading * target_speed * delta).normalized()
				var alt: float = hover + sin(_t * 0.5 + phase) * 3.0
				position = np2 * (maxf(ground_r(np2), planet.data.radius + (planet.gen.sea_h if planet.gen != null and planet.gen.has_sea else 0.0)) + alt)
				basis = U.basis_from_up(up, heading)
				var pulse: float = sin(_t * 1.6 + phase)
				if parts.has("Bell"):
					(parts["Bell"] as Node3D).scale = Vector3(1.0 + 0.07 * pulse, 1.0 - 0.1 * pulse, 1.0 + 0.07 * pulse)
				for i in 8:
					var key: String = "Tentacle_%d" % i
					if parts.has(key):
						(parts[key] as Node3D).rotation = Vector3(sin(_t * 1.2 + i * 0.9 + phase) * 0.16, 0.0, cos(_t * 1.0 + i * 1.3) * 0.16)
				model.position.y = sin(_t * 0.8 + phase) * 0.4
			"flyer":
				# circle around a centre that follows the player loosely
				var cdir: Vector3 = center.normalized()
				var ang: float = _t * (target_speed / maxf(orbit_r, 10.0)) * orbit_dir + phase
				var t1b: Vector3 = U.any_perp(cdir)
				var t2b: Vector3 = cdir.cross(t1b)
				var off: Vector3 = (t1b * cos(ang) + t2b * sin(ang)) * orbit_r
				var np3: Vector3 = (center + off).normalized()
				var alt2: float = hover + sin(_t * 0.35 + phase) * 8.0
				var newp: Vector3 = np3 * (ground_r(np3) + alt2)
				var vel: Vector3 = (newp - position) / maxf(delta, 0.0001)
				position = newp
				if vel.length() > 0.5:
					var hd: Vector3 = (vel - up * vel.dot(up)).normalized()
					basis = U.basis_from_up(up, hd)
					basis = basis * Basis(Vector3.BACK, -0.35 * orbit_dir)
				var flap: float = sin(_t * 5.5 + phase) * 0.55
				if parts.has("Wing_L"):
					(parts["Wing_L"] as Node3D).rotation.z = flap
				if parts.has("Wing_R"):
					(parts["Wing_R"] as Node3D).rotation.z = -flap

	func _animate_legs(delta: float, spd: float) -> void:
		var w: float = clampf(spd / 2.0, 0.0, 2.5)
		phase += delta * (3.0 + spd * 2.2)
		var amp: float = 0.55 * clampf(w, 0.0, 1.2)
		var pairs := [["Leg_FL", 0.0], ["Leg_BR", 0.0], ["Leg_FR", PI], ["Leg_BL", PI], ["Leg_1", 0.0], ["Leg_3", 0.0], ["Leg_5", 0.0], ["Leg_2", PI], ["Leg_4", PI], ["Leg_6", PI]]
		for p in pairs:
			if parts.has(p[0]):
				(parts[p[0]] as Node3D).rotation.x = sin(phase + float(p[1])) * amp
		if parts.has("Head"):
			(parts["Head"] as Node3D).rotation.x = sin(_t * 0.7 + phase * 0.1) * 0.08 + (-0.42 if spd < 0.2 and kind == "grazer" else 0.0)
		if parts.has("Tail"):
			(parts["Tail"] as Node3D).rotation.y = sin(_t * 2.0) * 0.3

var world: SpaceWorld
var creatures: Array = []
var _spawn_timer: float = 0.0
var _names: Dictionary = {}

func setup(w: SpaceWorld) -> void:
	world = w
	name = "Fauna"

func clear_all() -> void:
	for c in creatures:
		if is_instance_valid(c):
			c.queue_free()
	creatures.clear()

func species_name(planet: BodyData, kind: String) -> String:
	var key: String = "%d_%s" % [planet.seed_i, kind]
	if not _names.has(key):
		var nm: String = U.gen_name(U.hash2(planet.seed_i, kind.hash()), 2)
		var adj: Array = {"grazer": ["Grazer", "Browser", "Herder"], "floater": ["Drifter", "Floater", "Veilfin"], "flyer": ["Glider", "Skysail", "Windrider"], "crawler": ["Scuttler", "Crawler", "Skitter"]}[kind]
		_names[key] = "%s %s" % [nm, adj[abs(key.hash()) % adj.size()]]
	return _names[key]

func update_fauna(delta: float, pc: PlayerController) -> void:
	if world.frame_idx < 0 or Game.paused:
		if not creatures.is_empty() and world.frame_idx < 0:
			clear_all()
		return
	var pl: Planet = world.planets[world.frame_idx]
	var kinds: Array = pl.data.profile.get("fauna", [])
	if kinds.is_empty() or not pl.data.landable:
		if not creatures.is_empty():
			clear_all()
		return
	var ppos: Vector3 = pc.astro.global_position if pc.mode == PlayerController.Mode.FOOT else world.camera.global_position
	# (de)spawn
	var i: int = creatures.size() - 1
	while i >= 0:
		var c: Creature = creatures[i]
		if not is_instance_valid(c) or c.planet != pl or c.position.distance_to(ppos) > DESPAWN:
			if is_instance_valid(c):
				c.queue_free()
			creatures.remove_at(i)
		i -= 1
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and creatures.size() < 14 and world.altitude < 700.0:
		_spawn_timer = 0.6
		var counts: Dictionary = {}
		for c2 in creatures:
			counts[(c2 as Creature).kind] = int(counts.get((c2 as Creature).kind, 0)) + 1
		for k in kinds:
			if int(counts.get(k, 0)) < int(KIND_TARGET[k]):
				_spawn(k, pl, ppos)
				break
	for c3 in creatures:
		(c3 as Creature).center = ppos
		(c3 as Creature).step(delta, ppos)

func _spawn(kind: String, pl: Planet, ppos: Vector3) -> void:
	var up: Vector3 = ppos.normalized()
	var ang: float = randf() * TAU
	var dist: float = randf_range(SPAWN_MIN, SPAWN_MAX)
	var t1: Vector3 = U.any_perp(up)
	var dir: Vector3 = (up + (t1.rotated(up, ang) * dist) / pl.data.radius).normalized()
	var gr: float = pl.data.radius + pl.ground_height(dir)
	if pl.gen != null and pl.gen.has_sea and gr - pl.data.radius < pl.gen.sea_h + 1.0 and kind != "flyer" and kind != "floater":
		return
	if pl.gen != null and pl.gen.has_lava and gr - pl.data.radius < pl.gen.lava_h + 14.0:
		return
	var c := Creature.new()
	add_child(c)
	c.setup_creature(kind, pl, species_name(pl.data, kind))
	c.position = dir * (gr + c.hover)
	c.heading = U.any_perp(dir).rotated(dir, randf() * TAU)
	c.center = ppos
	creatures.append(c)
