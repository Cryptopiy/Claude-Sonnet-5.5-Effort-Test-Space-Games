class_name PoiStructure
extends Node3D
## One placed point of interest (landing pad, outpost, tower, monolith, wreck, container, ruin, wind turbine, solar array). Module M7a.
## Built from the Blender models (ModelLib) + simple colliders (layer 2) + interactables (group "interactable") + small behaviours
## (blinking lights, spinning rotors/rings, sun-tracking solar panels, smoke, opening crates).

var poi: Dictionary = {}
var planet: Node3D
var def: BodyDef
var kind: String = ""
var model_id: String = ""
var model: Node3D
var body: StaticBody3D
var interactable: PoiInteractable
var _blink: Array = []          # [{mat, base, phase, speed}]
var _spinners: Array = []       # [{node, speed}]
var _panels: Array = []         # Node3D
var _t := 0.0
var _smoke: Array = []
var _flicker: OmniLight3D
var _lid: Node3D
var _status_mat: StandardMaterial3D
var _rings_boost := 0.0
var _glow_light: OmniLight3D
var _used_key := ""
var _dist := 9999.0
var _shape_cache: Dictionary = {}

static var _smoke_tex: Texture2D

## transform (planet space) for a POI: up along the planet up (flat sites) or the blended terrain normal (loose props), forward -Z = bearing `yaw`
static func compute_transform(p: Dictionary, planet_node: Node3D) -> Transform3D:
	var dir: Vector3 = p["dir"]
	var rg: float = planet_node.call("terrain_radius_at", dir)
	var up := dir
	if not bool(p["flat"]):
		var nrm: Vector3 = planet_node.call("normal_at", dir)
		up = dir.lerp(nrm, 0.8).normalized()
	var t := ScatterGrid.tangents(dir)
	var yaw: float = p["yaw"]
	var fwd: Vector3 = t[0] * cos(yaw) + t[1] * sin(yaw)
	fwd = (fwd - up * fwd.dot(up)).normalized()
	var zv := -fwd
	var xv := up.cross(zv)
	var lift := 0.04 if String(p["kind"]) == "landing_pad" else (-0.05 if not bool(p["flat"]) else 0.0)
	return Transform3D(Basis(xv, up, zv), dir * rg + up * lift)

func setup(p_poi: Dictionary, p_planet: Node3D, p_def: BodyDef) -> void:
	poi = p_poi
	planet = p_planet
	def = p_def
	kind = String(poi["kind"])
	model_id = String(poi.get("model", ""))
	_used_key = "poi:%d" % int(poi["seed"])

func _ready() -> void:
	add_to_group("structures")
	if kind == "ruin":
		_build_ruin()
	else:
		model = ModelLib.instantiate(model_id)
		add_child(model)
		body = StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		add_child(body)
		ScatterModels.add_shapes(body, model_id, 1.0, _shape_cache)
		_extra_colliders()
	match kind:
		"landing_pad": _setup_pad()
		"outpost": _setup_outpost()
		"tower": _setup_tower()
		"beacon": _setup_beacon()
		"wreck": _setup_wreck()
		"container": _setup_container()
		"depot": _setup_depot()
		"solar": _setup_solar()

func _extra_colliders() -> void:
	var extra: Array = []
	match model_id:
		"outpost_tower_a": extra = [[Vector3(3.2, 20.0, 3.2), Vector3(0, 10.0, 0)]]
		"beacon_monolith_a": extra = [[Vector3(1.7, 7.0, 1.7), Vector3(0, 3.5, 0)]]
	for e in extra:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = e[0]
		cs.shape = bs
		cs.position = e[1]
		body.add_child(cs)

func is_used() -> bool:
	return Game.depleted_nodes.has(_used_key)

func _set_used() -> void:
	Game.depleted_nodes[_used_key] = true

func _find(n: String) -> Node3D:
	if model == null:
		return null
	return ModelLib.find_node(model, n) as Node3D

func _dup_mat(mi: MeshInstance3D) -> StandardMaterial3D:
	if mi == null or mi.mesh == null:
		return null
	var m := mi.get_active_material(0) as StandardMaterial3D
	if m == null:
		return null
	var d := m.duplicate() as StandardMaterial3D
	mi.material_override = d
	return d

func _add_blink(node_name: String, speed: float, phase: float = 0.0) -> void:
	var mi := _find(node_name) as MeshInstance3D
	var m := _dup_mat(mi)
	if m != null:
		_blink.append({"mat": m, "base": maxf(m.emission_energy_multiplier, 1.0), "phase": phase, "speed": speed})

func _add_interactable(anchor_name: String, prompt: String, cb: Callable, usable: Callable = Callable(), up_offset: float = 1.0) -> PoiInteractable:
	var it := PoiInteractable.new()
	it.prompt = prompt
	it.on_use = cb
	it.usable = usable
	var anchor := _find(anchor_name)
	if anchor != null:
		anchor.add_child(it)
		it.position = Vector3(0, up_offset, 0)
	else:
		add_child(it)
		it.position = Vector3(0, up_offset, 0)
	interactable = it
	return it

func _add_light(pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.5
	l.shadow_enabled = false
	l.position = pos
	add_child(l)
	return l

# ---------------------------------------------------------------------------------------------------------------------
# helpers shared by the interactions
# ---------------------------------------------------------------------------------------------------------------------
func _give(loot: Dictionary, title: String) -> void:
	for k in loot:
		Game.add_resource(String(k), int(loot[k]))
	Events.notify.emit("%s  (%s)" % [title, PoiLoot.describe(loot)], "good")

## mark POIs within `range_m` as revealed (map markers); `only` limits kinds (empty = all). Returns the number newly revealed.
func _reveal(range_m: float, skip_kinds: Array = []) -> int:
	var n := 0
	var R := def.radius
	for p in PoiSites.for_body(def):
		if String(p["kind"]) in skip_kinds:
			continue
		if ScatterGrid.ground_dist(p["dir"], poi["dir"], R) <= range_m and not PoiSites.is_revealed(p):
			PoiSites.reveal(p)
			n += 1
	return n

# ---------------------------------------------------------------------------------------------------------------------
# per-kind setup
# ---------------------------------------------------------------------------------------------------------------------
func _setup_pad() -> void:
	# chase-light ring + soft glow + console
	for i in 12:
		var mi := _find("PadLight_%02d" % i) as MeshInstance3D
		var m := _dup_mat(mi)
		if m != null:
			_blink.append({"mat": m, "base": maxf(m.emission_energy_multiplier, 2.0), "phase": float(i) * 0.52, "speed": -3.2, "chase": true})
	_glow_light = _add_light(Vector3(0, 3.0, 0), Color(0.45, 0.9, 1.0), 0.9, 24.0)
	_add_interactable("Anchor_Door", "Recharge pulse drive", _use_pad_console, _pad_needs_service)
	if interactable != null:
		interactable.prompt_fn = _pad_prompt

func _pad_needs_service() -> bool:
	return Game.ship_fuel < 0.995 or Game.ship_hull < 0.995

func _pad_prompt() -> String:
	return "Recharge pulse drive and repair hull" if _pad_needs_service() else "Ship systems nominal"

func _not_used() -> bool:
	return not is_used()

func _use_pad_console(player: Node) -> void:
	Game.ship_fuel = 1.0
	Game.ship_hull = minf(Game.ship_hull + 0.35, 1.0)
	Events.notify.emit("Landing pad service: pulse drive recharged, hull plating restored", "good")
	Events.screen_flash.emit(Color(0.4, 0.9, 1.0, 0.25), 0.4)

func _setup_outpost() -> void:
	_add_blink("BlinkLight", 2.2, float(poi["seed"] & 15) * 0.4)
	_glow_light = _add_light(Vector3(0, 2.8, -2.5), Color(1.0, 0.78, 0.45), 0.8, 13.0)
	_add_interactable("Anchor_Door", "Access outpost terminal", _use_terminal, _not_used)

func _use_terminal(player: Node) -> void:
	if is_used():
		return
	_set_used()
	var n := _reveal(6500.0, ["container"])
	var loot := PoiLoot.roll("outpost", int(poi["seed"]), def.biome)
	Events.notify.emit(PoiLoot.pick(PoiLoot.TERMINAL_LOG, int(poi["seed"]), 5), "discover")
	_give(loot, "Outpost supplies released")
	if n > 0:
		Events.notify.emit("%d new sites marked on your map" % n, "info")

func _setup_tower() -> void:
	_add_blink("BlinkLight", 1.4, 0.0)
	_add_interactable("Anchor_Door", "Activate comm tower", _use_tower, _not_used)

func _use_tower(player: Node) -> void:
	if is_used():
		return
	_set_used()
	var n := _reveal(1.0e9, ["container"])
	_give(PoiLoot.roll("tower", int(poi["seed"]), def.biome), "Relay calibrated")
	Events.notify.emit("Comm tower online - %d sites marked across the planet" % n, "discover")

func _setup_beacon() -> void:
	for nm in ["Ring_Outer", "Ring_Inner"]:
		var r := _find(nm)
		if r != null:
			_spinners.append({"node": r, "speed": 0.35 if nm == "Ring_Outer" else -0.6, "axis": Vector3.UP})
	_glow_light = _add_light(Vector3(0, 4.5, 0), Color(0.3, 1.0, 0.85), 1.2, 22.0)
	_add_interactable("Anchor_Door", "Touch the monolith", _use_beacon, _not_used, 1.2)

func _use_beacon(player: Node) -> void:
	if is_used():
		return
	_set_used()
	_rings_boost = 3.0
	var n := _reveal(7000.0)
	Events.screen_flash.emit(Color(0.4, 1.0, 0.9, 0.35), 0.8)
	Events.notify.emit(PoiLoot.lore_for(int(poi["seed"])), "discover")
	_give(PoiLoot.roll("beacon", int(poi["seed"]), def.biome), "The monolith yields its gift")
	if n > 0:
		Events.notify.emit("%d sites revealed" % n, "info")
	Events.poi_discovered.emit(String(poi["name"]))

func _setup_wreck() -> void:
	for i in 2:
		var a := _find("Anchor_Smoke_%d" % i)
		if a != null:
			var sm := _make_smoke()
			a.add_child(sm)
			_smoke.append(sm)
	var a1 := _find("Anchor_Smoke_1")
	_flicker = OmniLight3D.new()
	_flicker.light_color = Color(1.0, 0.5, 0.2)
	_flicker.light_energy = 1.0
	_flicker.omni_range = 9.0
	(a1 if a1 != null else self).add_child(_flicker)
	_add_interactable("Anchor_Door", "Salvage wreckage", _use_wreck, _not_used)

func _use_wreck(player: Node) -> void:
	if is_used():
		return
	_set_used()
	Events.notify.emit(PoiLoot.pick(PoiLoot.WRECK_LOG, int(poi["seed"]), 7), "discover")
	_give(PoiLoot.roll("wreck", int(poi["seed"]), def.biome), "Wreck salvaged")

func _setup_container() -> void:
	_lid = _find("Lid")
	var sl := _find("StatusLight") as MeshInstance3D
	_status_mat = _dup_mat(sl)
	if is_used() and _lid != null:
		_lid.rotation_degrees.x = 105.0
		_paint_status(false)
	var it := _add_interactable("Anchor_Top", "Open supply crate", _use_container, _not_used, 0.2)
	if _find("Anchor_Top") == null:
		it.position = Vector3(0, 1.0, 0)

func _paint_status(on: bool) -> void:
	if _status_mat == null:
		return
	var c := Color(0.2, 1.0, 0.5) if on else Color(1.0, 0.35, 0.15)
	_status_mat.albedo_color = c
	_status_mat.emission = c

func _use_container(player: Node) -> void:
	if is_used():
		return
	_set_used()
	if _lid != null:
		var tw := create_tween()
		tw.tween_property(_lid, "rotation_degrees:x", 105.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_paint_status(false)
	_give(PoiLoot.roll("container", int(poi["seed"]), def.biome), "Supply crate opened")

func _setup_depot() -> void:
	var rotor := _find("Rotor")
	if rotor != null:
		_spinners.append({"node": rotor, "speed": 1.1 + float(poi["seed"] & 7) * 0.05, "axis": Vector3.UP})
	_add_blink("BlinkLight", 1.1, 0.5)

func _setup_solar() -> void:
	for i in 6:
		var pn := _find("Panel_%d" % i)
		if pn != null:
			_panels.append(pn)
	_add_blink("StatusLight", 0.8, 0.0)

# ---------------------------------------------------------------------------------------------------------------------
# procedural ruin (no Blender model): ring of standing stones, lintels and a glowing altar
# ---------------------------------------------------------------------------------------------------------------------
func _build_ruin() -> void:
	model = Node3D.new()
	model.name = "Ruin"
	add_child(model)
	body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	add_child(body)
	var sd := int(poi["seed"])
	var rng := SeedUtil.rng(sd, 991)
	var stone := StandardMaterial3D.new()
	var tint := Color.from_hsv(rng.randf_range(0.05, 0.12), rng.randf_range(0.08, 0.22), rng.randf_range(0.45, 0.62))
	stone.albedo_color = tint
	stone.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = tint.darkened(0.45)
	dark.roughness = 1.0
	var glow := StandardMaterial3D.new()
	var gcol := Color.from_hsv(rng.randf_range(0.42, 0.52), 0.8, 1.0)
	glow.albedo_color = gcol
	glow.emission_enabled = true
	glow.emission = gcol
	glow.emission_energy_multiplier = 3.5
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var n := 9
	var radius := 6.5
	var tops: Array = []
	for i in n:
		var ang := TAU * float(i) / float(n)
		var h := rng.randf_range(4.0, 5.6)
		var broken := rng.randf() < 0.35
		if broken:
			h *= rng.randf_range(0.35, 0.7)
		var w := rng.randf_range(0.9, 1.25)
		var d := rng.randf_range(0.8, 1.1)
		var pos := Vector3(cos(ang) * radius, 0, sin(ang) * radius)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, d)
		mi.mesh = bm
		mi.material_override = stone
		mi.position = pos + Vector3(0, h * 0.5 - 0.4, 0)
		mi.rotation = Vector3(rng.randf_range(-0.06, 0.06), -ang + PI * 0.5, rng.randf_range(-0.07, 0.07))
		model.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(w, h + 0.4, d)
		cs.shape = bs
		cs.position = mi.position
		cs.rotation = mi.rotation
		body.add_child(cs)
		if not broken:
			tops.append([i, pos, h])
			# glyph strip facing the centre
			var gm := MeshInstance3D.new()
			var gb := BoxMesh.new()
			gb.size = Vector3(0.12, h * 0.5, 0.04)
			gm.mesh = gb
			gm.material_override = glow
			var inward := -pos.normalized()
			gm.position = mi.position + inward * (d * 0.5 + 0.02) + Vector3(0, h * 0.1, 0)
			gm.rotation = Vector3(0, -ang + PI * 0.5, 0)
			model.add_child(gm)
	# lintels over neighbouring intact pillars
	for a in tops.size():
		var b := (a + 1) % tops.size()
		var ia: int = tops[a][0]
		var ib: int = tops[b][0]
		if (ib - ia) % n != 1 and not (ia == n - 1 and ib == 0):
			continue
		var pa: Vector3 = tops[a][1]
		var pb: Vector3 = tops[b][1]
		var top_y := minf(float(tops[a][2]), float(tops[b][2])) - 0.4
		var mid := (pa + pb) * 0.5 + Vector3(0, top_y + 0.35, 0)
		var chord := pa.distance_to(pb)
		var lm := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(chord + 0.9, 0.7, 1.0)
		lm.mesh = lb
		lm.material_override = dark
		lm.position = mid
		var along := (pb - pa).normalized()
		lm.rotation = Vector3(0, atan2(-along.z, along.x), 0)
		model.add_child(lm)
	# central altar + hovering crystal
	var altar := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.35
	cm.height = 1.1
	altar.mesh = cm
	altar.material_override = stone
	altar.position = Vector3(0, 0.15, 0)
	model.add_child(altar)
	var acs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.3
	cyl.height = 1.1
	acs.shape = cyl
	acs.position = altar.position
	body.add_child(acs)
	var gem := MeshInstance3D.new()
	var gm2 := BoxMesh.new()
	gm2.size = Vector3(0.55, 0.55, 0.55)
	gem.mesh = gm2
	gem.material_override = glow
	gem.position = Vector3(0, 1.75, 0)
	gem.rotation = Vector3(0.6, 0.0, 0.6)
	model.add_child(gem)
	_spinners.append({"node": gem, "speed": 0.9, "axis": Vector3.UP})
	_glow_light = _add_light(Vector3(0, 2.2, 0), gcol, 1.3, 16.0)
	var it := PoiInteractable.new()
	it.prompt = "Examine the altar"
	it.on_use = _use_ruin
	it.usable = _not_used
	model.add_child(it)
	it.position = Vector3(0, 1.4, 0)
	interactable = it

func _use_ruin(player: Node) -> void:
	if is_used():
		return
	_set_used()
	_rings_boost = 2.0
	var n := _reveal(4500.0)
	Events.screen_flash.emit(Color(0.5, 1.0, 0.9, 0.3), 0.7)
	Events.notify.emit(PoiLoot.lore_for(int(poi["seed"]) + 17), "discover")
	_give(PoiLoot.roll("ruin", int(poi["seed"]), def.biome), "The altar yields its gift")
	if n > 0:
		Events.notify.emit("%d sites revealed" % n, "info")
	Events.poi_discovered.emit(String(poi["name"]))

# ---------------------------------------------------------------------------------------------------------------------
func _make_smoke() -> CPUParticles3D:
	if _smoke_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.9))
		g.set_color(1, Color(1, 1, 1, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_smoke_tex = gt
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 2.2)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _smoke_tex
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	p.amount = 16
	p.lifetime = 5.0
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 1.4
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, 0.5, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 2.6))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.16, 0.15, 0.15, 0.55))
	ramp.set_color(1, Color(0.3, 0.3, 0.32, 0.0))
	p.color_ramp = ramp
	p.local_coords = false
	p.emitting = false
	return p

func _process(dt: float) -> void:
	_t += dt
	var f := Frame.focus
	_dist = 99999.0
	if f != null and is_instance_valid(f):
		_dist = global_position.distance_to(f.global_position)
	var near := _dist < 260.0
	for b in _blink:
		var m: StandardMaterial3D = b["mat"]
		var base: float = b["base"]
		if b.has("chase"):
			var s := 0.5 + 0.5 * sin(_t * -float(b["speed"]) + float(b["phase"]))
			m.emission_energy_multiplier = base * (0.25 + 1.0 * s * s)
		else:
			var s2 := 0.5 + 0.5 * sin(_t * TAU / maxf(float(b["speed"]), 0.1) + float(b["phase"]))
			m.emission_energy_multiplier = base * (0.15 + 1.6 * pow(s2, 4.0))
	if _rings_boost > 0.0:
		_rings_boost = maxf(_rings_boost - dt * 0.4, 0.0)
	for sp in _spinners:
		var nd: Node3D = sp["node"]
		if is_instance_valid(nd):
			nd.rotate_object_local(sp["axis"], dt * float(sp["speed"]) * (1.0 + _rings_boost * 2.0))
	if not _panels.is_empty() and near:
		var sun_local := global_transform.basis.orthonormalized().inverse() * Frame.sun_dir
		var target := atan2(sun_local.z, sun_local.y) if sun_local.y > -0.05 else deg_to_rad(-30.0)
		target = clampf(target, deg_to_rad(-80.0), deg_to_rad(80.0))
		for pn in _panels:
			var pnode: Node3D = pn
			pnode.rotation.x = lerp_angle(pnode.rotation.x, target, minf(dt * 0.8, 1.0))
	if not _smoke.is_empty():
		for sm in _smoke:
			(sm as CPUParticles3D).emitting = _dist < 450.0
		if _flicker != null:
			_flicker.light_energy = 0.9 + 0.5 * sin(_t * 9.0) * sin(_t * 3.7) + (randf() - 0.5) * 0.2
			_flicker.visible = _dist < 200.0
	if _glow_light != null:
		_glow_light.visible = _dist < 300.0
	if _lid != null and not is_used() and near:
		# idle: status light blinks until looted
		if _status_mat != null:
			var on := fmod(_t, 1.6) < 0.8
			var c := Color(0.2, 1.0, 0.6) if on else Color(0.05, 0.3, 0.2)
			_status_mat.albedo_color = c
			_status_mat.emission = c
