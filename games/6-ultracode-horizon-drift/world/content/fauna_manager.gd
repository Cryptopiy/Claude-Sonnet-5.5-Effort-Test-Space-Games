class_name FaunaManager
extends Node3D
## FAUNA (module m7b_life).  One instance (Game.fauna).  Spawns deterministic herds / flocks of the Blender creatures around the focus (ship / player) while the
## frame is anchored on a planet with life.  Cells = a 90 m 3-D grid shell around the surface (planet space == local space), hash(def.seed, cell) decides whether a herd
## lives there, which species, how many and where; the same planet therefore always holds the same wildlife.  At most MAX_ACTIVE creatures exist at once, far ones are
## despawned (scaled away), near ones animate procedurally (see creature.gd).  Species are recoloured per biome / planet (FaunaTables).
##
## Public API:  creatures (Dictionary key -> Creature), creature_count(), nearest_creature(pos, max_dist) -> Creature, scan_targets(origin, radius) -> Array[{pos, label, kind}],
##              enabled, set_debug_density(mult)  (also --fauna=<mult> user arg).  Creatures are in group "creature" (meta "label", "species").

const CELL := 90.0
const SPAWN_R := 250.0
const DESPAWN_R := 340.0
const MAX_ACTIVE := 40
const MAX_GROUND := 20           # walkers + crawlers
const MAX_FLOATERS := 8
const MAX_FLYERS := 12           # flocks are 3-6 strong; without a class budget they used to crowd out every ground animal
const PAD_GROUP_DIST := [50.0, 64.0, 80.0, 98.0, 122.0]     # start-pad herds: ground distance from the landing pad (the first minutes must show life)
const MAX_ALT := 450.0           # no wildlife spawns around a focus higher than this above the ground

static var _logged: Dictionary = {}      # "planetseed:species" -> true  (species already announced this game)

var enabled: bool = true
var creatures: Dictionary = {}
var _planet: Planet
var _def: BodyDef
var _tick: float = 0.0
var _burst: int = 0
var _cell_cache: Dictionary = {}
var _mat_cache: Dictionary = {}
var _glow_mats: Array = []
var _night: float = 0.0
var _glow_t: float = 0.0
var _last_focus: Vector3 = Vector3.ZERO
var _have_last: bool = false
var _focus_speed: float = 0.0
var _density_mult: float = 1.0
var debug_threat_scale: float = 1.0      # test hook: 0 = creatures never flee
var _pad_groups: Array = []              # deterministic herds around the start landing pad (see _build_pad_groups)
var _first_fill: bool = false            # the first spawn pass after entering a planet's frame pops creatures in at full size (no grow-in on the pad)

func _ready() -> void:
	process_priority = 50
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--fauna="):
			_density_mult = float(s.substr(8))
	Frame.frame_changed.connect(func(_o: int, _n: int) -> void: _clear_all())
	Events.system_loaded.connect(func(_id: int) -> void: _clear_all(true))
	Events.game_started.connect(func() -> void: _logged.clear())
	Events.returned_to_menu.connect(func() -> void: _clear_all(true))

func set_debug_density(mult: float) -> void:
	_density_mult = mult

func creature_count() -> int:
	return creatures.size()

func nearest_creature(pos: Vector3, max_dist: float = 1.0e9) -> Creature:
	var best: Creature = null
	var bd := max_dist
	for c in creatures.values():
		var d := (c as Creature).position.distance_to(pos)
		if d < bd and not (c as Creature).dying:
			bd = d
			best = c
	return best

## scanner helper: Array of {pos: Vector3 (local), label: String, kind: "creature"} within `radius` of origin
func scan_targets(origin: Vector3, radius: float) -> Array:
	var out: Array = []
	for c in creatures.values():
		var cr := c as Creature
		if cr.dying:
			continue
		if cr.position.distance_to(origin) <= radius:
			out.append({"pos": cr.position, "label": cr.label, "kind": "creature"})
	return out

# =====================================================================================================================
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	var focus: Node3D = Frame.focus
	if not enabled or Game.state != Game.State.PLAYING or focus == null or not is_instance_valid(focus) or not focus.is_inside_tree() or Frame.anchor < 0:
		if not creatures.is_empty():
			_clear_all()
		_have_last = false
		return
	var pl := Frame.anchor_node() as Planet
	if pl == null or Frame.anchor_def() == null or not Frame.anchor_def().landable:
		if not creatures.is_empty():
			_clear_all()
		return
	if pl != _planet:
		_clear_all(true)
		_planet = pl
		_def = Frame.anchor_def()
		_burst = 10
		_tick = 0.0
		_first_fill = true
		_build_pad_groups()
	var fpos := focus.global_position
	if _have_last and dt > 0.0:
		var v := (fpos - _last_focus).length() / dt
		if v < 5000.0:
			_focus_speed = lerpf(_focus_speed, v, 1.0 - exp(-dt * 6.0))
	_last_focus = fpos
	_have_last = true
	var threat := 1.0
	if _focus_speed > 28.0:
		threat = 1.9
	elif _focus_speed > 8.0:
		threat = 1.35
	var ctx := {"focus": fpos, "t": Universe.time, "threat": threat * debug_threat_scale}
	_tick -= dt
	if _tick <= 0.0:
		_tick = 0.3
		_update_population(fpos)
	var dead: Array = []
	for k in creatures:
		var c: Creature = creatures[k]
		c.update(dt, ctx)
		if c.dying and c.grow <= 0.0:
			dead.append(k)
	for k in dead:
		(creatures[k] as Creature).queue_free()
		creatures.erase(k)
	_glow_t -= dt
	if _glow_t <= 0.0:
		_glow_t = 0.5
		_update_night(fpos)

func _clear_all(reset_caches: bool = false) -> void:
	for k in creatures:
		(creatures[k] as Creature).queue_free()
	creatures.clear()
	_have_last = false
	if reset_caches:
		_cell_cache.clear()
		_mat_cache.clear()
		_glow_mats.clear()
		_planet = null
		_def = null

# =====================================================================================================================
# population management
# =====================================================================================================================
func _update_population(fpos: Vector3) -> void:
	var fdir := fpos.normalized()
	var g_r := _planet.terrain_radius_at(fdir)
	var f_alt := fpos.length() - g_r
	var active := 0
	var by_class: Dictionary = {"ground": 0, "floater": 0, "flyer": 0}
	for k in creatures:
		var c: Creature = creatures[k]
		if c.dying:
			continue
		var lim := DESPAWN_R * (1.5 if c.type == "flyer" else 1.0)
		if f_alt > MAX_ALT or c.position.distance_to(fpos) > lim:
			c.dying = true
		else:
			active += 1
			by_class[_class_of(c.type)] = int(by_class[_class_of(c.type)]) + 1
	# announce species the first time one is close
	for k in creatures:
		var c2: Creature = creatures[k]
		if not c2.dying and c2.position.distance_to(fpos) < 55.0:
			var lk := "%d:%s" % [_def.seed, c2.species]
			if not _logged.has(lk):
				_logged[lk] = true
				Events.notify.emit("Species logged: %s" % c2.label, "discover")
	if f_alt > MAX_ALT or active >= MAX_ACTIVE:
		return
	var biome_e := FaunaTables.biome_entry(_def.biome)
	var p: float = float(biome_e["p"]) * _density_mult
	if p <= 0.0:
		return
	var k_cells := int(ceil(SPAWN_R / CELL))
	var c0 := Vector3i(floori(fpos.x / CELL), floori(fpos.y / CELL), floori(fpos.z / CELL))
	var wanted: Array = []
	for grp in _pad_groups:
		var hpp: Vector3 = (grp["dir"] as Vector3) * g_r
		if hpp.distance_to(fpos) < SPAWN_R:
			for m in int(grp["n"]):
				var pk := "%s_%d" % [grp["key"], m]
				if not creatures.has(pk):
					wanted.append([hpp.distance_to(fpos) - 1000.0, grp, m, pk])     # pad herds go first
	for ix in range(c0.x - k_cells, c0.x + k_cells + 1):
		for iy in range(c0.y - k_cells, c0.y + k_cells + 1):
			for iz in range(c0.z - k_cells, c0.z + k_cells + 1):
				var center := (Vector3(ix, iy, iz) + Vector3(0.5, 0.5, 0.5)) * CELL
				if absf(center.length() - g_r) > CELL * 1.1:
					continue
				for grp in _cell_groups(ix, iy, iz, p, biome_e):
					for m in int(grp["n"]):
						var key := "%s_%d" % [grp["key"], m]
						if creatures.has(key):
							continue
						var hp: Vector3 = (grp["dir"] as Vector3) * g_r
						var d := hp.distance_to(fpos)
						if d < SPAWN_R:
							wanted.append([d, grp, m, key])
	if wanted.is_empty():
		return
	wanted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var budget := 3
	var instant := false
	if _burst > 0:
		budget = 8
		_burst -= 1
		if _first_fill and _focus_speed < 25.0:
			budget = 40
			instant = true
	_first_fill = false
	var limits: Dictionary = {"ground": MAX_GROUND, "floater": MAX_FLOATERS, "flyer": MAX_FLYERS}
	for w in wanted:
		if budget <= 0 or active >= MAX_ACTIVE:
			break
		var cls := _class_of(String(FaunaTables.SPECIES[String((w[1] as Dictionary)["species"])]["type"]))
		if int(by_class[cls]) >= int(limits[cls]):
			continue
		_spawn(w[1], int(w[2]), String(w[3]), instant)
		by_class[cls] = int(by_class[cls]) + 1
		budget -= 1
		active += 1

static func _class_of(t: String) -> String:
	if t == "flyer":
		return "flyer"
	if t == "floater":
		return "floater"
	return "ground"

## deterministic herds near the start landing pad: they graze 50-120 m from the pad, mostly ahead of the ship, so the first minutes of the game already show life.
## Species come from the biome mix (best ground species first); a floater / flock is added when the biome has them.  Placement avoids water and steep ground.
func _build_pad_groups() -> void:
	_pad_groups.clear()
	if _planet == null or _def == null:
		return
	var biome_e := FaunaTables.biome_entry(_def.biome)
	var mix: Dictionary = biome_e["mix"]
	var ground: Array = []
	var floater := ""
	var flyer := ""
	for sp in mix:
		var ty := String(FaunaTables.SPECIES[sp]["type"])
		if ty == "walker" or ty == "crawler":
			ground.append(sp)
		elif ty == "floater":
			floater = sp
		else:
			flyer = sp
	ground.sort_custom(func(a: String, b: String) -> bool: return float(mix[a]) > float(mix[b]))
	var wanted_species: Array = []
	if not ground.is_empty():
		wanted_species.append(ground[0])
		wanted_species.append(ground[0])
		wanted_species.append(ground[1] if ground.size() > 1 else ground[0])
	if floater != "":
		wanted_species.append(floater)
	if flyer != "":
		wanted_species.append(flyer)
	var up := PoiSites.start_dir(_def)
	var north := Vector3.UP - up * up.y
	if north.length() < 0.2:
		north = Vector3.FORWARD - up * up.dot(Vector3.FORWARD)
	north = north.normalized()
	# bearings (rad from the ship's nose): two herds in the forward arc, one off to each side, one behind
	var bearings := [-0.7, 0.45, 1.25, -1.5, 2.9]
	var sea := _planet.sea_radius()
	var rng := SeedUtil.rng(_def.seed, 6061)
	for i in wanted_species.size():
		var sp: String = wanted_species[i]
		var spec: Dictionary = FaunaTables.SPECIES[sp]
		var ty := String(spec["type"])
		var chosen := Vector3.ZERO
		for tries in 10:
			var bearing: float = float(bearings[i % bearings.size()]) + (rng.randf() - 0.5) * 0.5 + (0.0 if tries < 3 else float(tries) * 0.35)
			var dist: float = float(PAD_GROUP_DIST[i % PAD_GROUP_DIST.size()]) * (1.0 if tries < 5 else 1.25) + rng.randf() * 8.0
			var tdir := north.rotated(up, bearing)
			var ang := dist / _def.radius
			var d := (up * cos(ang) + tdir * sin(ang)).normalized()
			var r := _planet.terrain_radius_at(d)
			if (ty == "walker" or ty == "crawler") and sea > 0.0 and r < sea + 1.5:
				continue
			if _planet.normal_at(d).dot(d) < 0.86:
				continue
			chosen = d
			break
		if chosen == Vector3.ZERO:
			continue
		var hr: Array = spec["herd"]
		var n_members := rng.randi_range(int(hr[0]) + (1 if ty == "walker" else 0), int(hr[1]))
		_pad_groups.append({"key": "pad%d" % i, "species": sp, "dir": chosen, "n": n_members, "seed": SeedUtil.hash2(_def.seed, 6100 + i)})

## deterministic herds of one grid cell (cached): Array of {key, species, dir, n, seed}
func _cell_groups(ix: int, iy: int, iz: int, p: float, biome_e: Dictionary) -> Array:
	var ck := Vector3i(ix, iy, iz)
	if _cell_cache.has(ck):
		return _cell_cache[ck]
	var out: Array = []
	var h := SeedUtil.hash3(_def.seed ^ 0x51F7, ix, SeedUtil.hash2(iy, iz))
	if SeedUtil.rand01(h, 1) < p:
		var mix: Dictionary = biome_e["mix"]
		var names: Array = mix.keys()
		var weights: Array = []
		for n in names:
			weights.append(float(mix[n]))
		var rng := SeedUtil.rng(h, 9)
		var sp: String = names[SeedUtil.pick_weighted(rng, weights)]
		var spec: Dictionary = FaunaTables.SPECIES[sp]
		var hr: Array = spec["herd"]
		var n_members := rng.randi_range(int(hr[0]), int(hr[1]))
		var pt := (Vector3(ix, iy, iz) + Vector3(SeedUtil.rand01(h, 2), SeedUtil.rand01(h, 3), SeedUtil.rand01(h, 4))) * CELL
		var hd := pt.normalized()
		var ok := true
		var sea := _planet.sea_radius()
		if sea > 0.0 and (spec["type"] == "walker" or spec["type"] == "crawler"):
			ok = _planet.terrain_radius_at(hd) > sea + 1.5
		if ok:
			out.append({"key": "%d_%d_%d" % [ix, iy, iz], "species": sp, "dir": hd, "n": n_members, "seed": h})
	_cell_cache[ck] = out
	if _cell_cache.size() > 6000:
		_cell_cache.clear()
	return out

func _spawn(grp: Dictionary, member: int, key: String, instant: bool = false) -> void:
	var sp: String = grp["species"]
	var spec: Dictionary = FaunaTables.SPECIES[sp]
	var mseed := SeedUtil.hash2(int(grp["seed"]), member + 100)
	var model := ModelLib.instantiate(String(spec["model"]))
	var variant := SeedUtil.rand_int(mseed, 5, 0, 2)
	_apply_tint(model, variant)
	var c := Creature.new()
	var fseed := int(grp["seed"]) if spec["type"] == "flyer" else mseed      # flock members share path parameters
	add_child(c)
	c.setup(_planet, _def, key, sp, model, grp["dir"], fseed, FaunaTables.species_name(_def, sp))
	if spec["type"] == "flyer":
		c.phase = float(member) * 0.7 + SeedUtil.rand01(mseed, 6) * 0.3
	if instant:
		c.grow = 1.0
	creatures[key] = c

# =====================================================================================================================
# recolouring
# =====================================================================================================================
func _apply_tint(model: Node3D, variant: int) -> void:
	var tt := FaunaTables.tint_entry(_def.biome)
	var stack: Array = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null:
				continue
			var nm := src.resource_name
			var role := ""
			if nm.ends_with("glow"):
				role = "glow"
			elif nm.ends_with("skin") or nm.ends_with("shell") or nm.ends_with("bell") or nm.ends_with("membrane") or nm.ends_with("tentacle"):
				role = "skin"
			if role == "":
				continue
			mi.set_surface_override_material(s, _tinted(src, role, tt, variant))

func _tinted(src: BaseMaterial3D, role: String, tt: Dictionary, variant: int) -> Material:
	var ck := "%d:%s:%d" % [src.get_instance_id(), role, variant]
	if _mat_cache.has(ck):
		return _mat_cache[ck]
	var m := src.duplicate() as BaseMaterial3D
	var target_h: float = float(tt.get(role + "_h", -1.0))
	var s_mul: float = float(tt.get(role + "_s", 1.0))
	var v_mul: float = float(tt.get(role + "_v", 1.0))
	var pjit := (SeedUtil.rand01(_def.palette_seed, 77) - 0.5) * 0.36        # planet-specific hue drift
	var vjit := float(variant - 1) * 0.035
	m.albedo_color = _recolor(src.albedo_color, target_h, s_mul, v_mul, pjit, vjit)
	if src.emission_enabled:
		m.emission = _recolor(src.emission, target_h, 1.0 if role == "glow" else s_mul, 1.0, pjit, vjit)
		if role == "glow":
			_glow_mats.append([m, src.emission_energy_multiplier])
	_mat_cache[ck] = m
	return m

func _recolor(c: Color, target_h: float, s_mul: float, v_mul: float, planet_jit: float, var_jit: float) -> Color:
	var h := c.h
	if target_h >= 0.0:
		h = fposmod(target_h + planet_jit * 0.12 + var_jit, 1.0)
	else:
		h = fposmod(c.h + planet_jit + var_jit, 1.0)
	return Color.from_hsv(h, clampf(c.s * s_mul, 0.0, 1.0), clampf(c.v * v_mul, 0.0, 1.0), c.a)

func _update_night(fpos: Vector3) -> void:
	var day := smoothstep(-0.15, 0.25, fpos.normalized().dot(Frame.sun_dir))
	_night = 1.0 - day
	for e in _glow_mats:
		(e[0] as BaseMaterial3D).emission_energy_multiplier = float(e[1]) * (1.0 + 2.0 * _night)
