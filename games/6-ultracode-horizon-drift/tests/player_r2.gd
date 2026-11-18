extends RefCounted
## M4 round-2 integrated verification against the REAL terrain / props / resources / POIs.
##   --preset=foot:<body> --test=res://tests/player_r2.gd  --sect=basics,slope,props,res,scan,hazard,ship,shots   (default: all logic sections)
## "shots" needs a rendered run (not --headless); everything else also works with `godot.ps1 -Headless` (zero GPU load).
var g: Node
var fails := 0
var sect := ""
var p: Player
var planet: Planet

func _wait(s: float) -> void:
	await g.get_tree().create_timer(s).timeout

func _frames(n: int) -> void:
	for i in n:
		await g.get_tree().process_frame

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		fails += 1
		print("FAIL ", msg)

func _has(s: String) -> bool:
	if sect == "":
		return s != "shots"
	return sect.split(",").has(s)

func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _frames(2)
	DebugCLI._save_shot(".previews/r2_%s.png" % name)

func _alt() -> float:
	# true height above the analytic surface (the tel value is clamped to >= 0 for the HUD)
	var d := p.global_position.normalized()
	return p.global_position.length() - planet.terrain_radius_at(d)

func _hspeed() -> float:
	var up := p.global_transform.basis.y
	return (p.velocity - up * p.velocity.dot(up)).length()

func _sm() -> Node:
	for c in planet.get_children():
		if c is ScatterManager:
			return c
	return null

## place the player on the ground at planet direction d facing `facing_dir` (tangent hint) and wait for the collision patch
func _place(d: Vector3, facing: Vector3, lift: float = 0.6) -> void:
	var gr := planet.terrain_radius_at(d)
	p.spawn_at(d * (gr + lift), d, facing)
	for i in 240:
		await g.get_tree().process_frame
		if planet.is_collision_ready(p.global_position) and p._grounded:
			break
	await _frames(6)

## turn the camera so it looks at world point `t` (yaw + pitch)
func _aim_at(t: Vector3) -> void:
	var up := p.global_transform.basis.y
	var from := p.cam.global_position
	var to := t - from
	var flat := to - up * to.dot(up)
	if flat.length() > 0.01:
		var fwd := -p.global_transform.basis.z
		var cur := (fwd - up * fwd.dot(up)).normalized()
		var ang := cur.signed_angle_to(flat.normalized(), up)
		p.debug_look(-ang, 0.0)
	var pitch_t := asin(clampf(to.normalized().dot(up), -1.0, 1.0))
	var cur_pitch: float = p.debug_state()["pitch"]
	p.debug_look(0.0, cur_pitch - pitch_t)

func run(game: Node) -> void:
	g = game
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--sect="):
			sect = String(a).substr(7)
	p = Game.player
	planet = Frame.anchor_node() as Planet
	await _wait(1.5)
	print("[r2] body=%s biome=%s r=%.0f g=%.2f temp=%.0f/%.0f tox=%.2f rad=%.2f atmo=%s ocean=%s  headless=%s" % [planet.def.name, planet.def.biome, planet.radius,
		planet.def.gravity, planet.def.temp_day_c, planet.def.temp_night_c, planet.def.toxicity, planet.def.radiation, str(planet.def.has_atmosphere), planet.def.ocean_kind,
		str(DisplayServer.get_name() == "headless")])
	# let the scatter manager finish its first cells (colliders / resource nodes) before the content sections
	if _has("props") or _has("res") or _has("scan") or _has("shots"):
		var smw := _sm()
		var tw := 0.0
		while smw != null and tw < 25.0 and (int(smw.call("stats").get("bodies", 0)) == 0 or g.get_tree().get_nodes_in_group("resource_node").is_empty()):
			await _wait(0.5)
			tw += 0.5
		print("[r2] scatter warm-up %.1f s: %s" % [tw, str(smw.call("stats") if smw != null else "no scatter manager")])
	var home_dir := p.global_position.normalized()
	var home_fwd := -p.global_transform.basis.z

	if _has("basics"):
		print("---- basics")
		_ok(p != null and p.active, "player active")
		_ok(absf(_alt()) < 0.4, "standing on ground alt=%.3f" % _alt())
		for k in ["speed", "state", "health", "protection", "jetpack", "stamina", "gravity", "temp_c", "hazard", "hazard_level", "altitude", "vspeed"]:
			_ok(Game.tel.has(k), "tel key '%s' = %s" % [k, str(Game.tel.get(k))])
		_ok(str(Game.tel.get("state")) == "ON FOOT", "tel state ON FOOT")
		p._find_interactable()
		_ok(p._interact_is_ship, "ship is the interact target near the hull (hint '[F] Enter ship')")
		_ok(abs(float(Game.tel["gravity"]) - planet.def.gravity) < 0.6, "gravity tel %.2f vs def %.2f" % [float(Game.tel["gravity"]), planet.def.gravity])
		# flashlight
		Input.action_press("toggle_light")
		await _wait(0.15)
		Input.action_release("toggle_light")
		await _wait(0.2)
		_ok(p.flashlight.visible and bool(Game.tel.get("flashlight")), "flashlight on")
		Input.action_press("toggle_light")
		await _wait(0.15)
		Input.action_release("toggle_light")
		await _wait(0.2)
		_ok(not p.flashlight.visible, "flashlight off")
		# walk / sprint / jump / jetpack / crouch
		var min_alt := 1.0e9
		var max_hs := 0.0
		Input.action_press("move_forward")
		await _wait(1.0)
		for i in 60:
			await _frames(1)
			max_hs = maxf(max_hs, _hspeed())
			min_alt = minf(min_alt, _alt())
		_ok(max_hs > 5.2 and max_hs < 6.8, "walk speed %.2f" % max_hs)
		Input.action_press("sprint")
		await _wait(1.0)
		max_hs = 0.0
		for i in 60:
			await _frames(1)
			max_hs = maxf(max_hs, _hspeed())
			min_alt = minf(min_alt, _alt())
		_ok(max_hs > 9.3 and max_hs < 12.0, "sprint speed %.2f" % max_hs)
		Input.action_release("sprint")
		Input.action_release("move_forward")
		_ok(min_alt > -0.4, "never below ground while walking (min alt %.2f)" % min_alt)
		await _wait(0.6)
		Input.action_press("move_up")
		await _wait(0.12)
		Input.action_release("move_up")
		var jmax := 0.0
		for i in 50:
			await _frames(1)
			jmax = maxf(jmax, _alt())
		_ok(jmax > 0.7 and jmax < 3.0, "jump height %.2f" % jmax)
		await _wait(1.2)
		Input.action_press("move_up")
		await _wait(2.4)
		var ja := _alt()
		_ok(ja > 6.0, "jetpack climb alt=%.1f fuel=%.2f" % [ja, p.vitals.jetpack])
		await _shot("jet_fp")
		Input.action_release("move_up")
		await _wait(5.0)
		_ok(absf(_alt()) < 0.5, "landed again alt=%.2f" % _alt())
		Input.action_press("move_down")
		await _wait(0.8)
		_ok(p.debug_state()["crouch"] and p.head.position.y < 1.4, "crouch eye %.2f" % p.head.position.y)
		Input.action_release("move_down")
		await _wait(0.6)

	if _has("slope"):
		print("---- slope")
		# find the steepest walkable and the steepest overall slope in 150 m around the spawn
		var best_a := 0.0
		var best_d := Vector3.ZERO
		var steep_a := 0.0
		var steep_d := Vector3.ZERO
		var ref := home_dir.cross(Vector3.RIGHT).normalized()
		var tan2 := home_dir.cross(ref)
		for ix in range(-30, 31):
			for iz in range(-30, 31):
				var off := (ref * float(ix) + tan2 * float(iz)) * 5.0
				var d := (home_dir * planet.radius + off).normalized()
				var n := planet.normal_at(d)
				var ang := rad_to_deg(acos(clampf(n.dot(d), -1.0, 1.0)))
				if ang > best_a and ang < 40.0:
					best_a = ang
					best_d = d
				if ang > steep_a:
					steep_a = ang
					steep_d = d
		print("[slope] steepest <40: %.1f deg   steepest overall: %.1f deg" % [best_a, steep_a])
		for case in [[best_d, best_a, "walkable"], [steep_d, steep_a, "steepest"]]:
			var d0: Vector3 = case[0]
			if d0 == Vector3.ZERO or float(case[1]) < 8.0:
				print("[slope] no %s slope found near the spawn" % case[2])
				continue
			var n0 := planet.normal_at(d0)
			var down := (n0 - d0 * n0.dot(d0))
			var uphill := (-down).normalized()
			# start ~14 m downhill of the point (tangent step), facing uphill
			var sd := (d0 * planet.radius + down.normalized() * 14.0).normalized()
			await _place(sd, uphill)
			var a0 := p.global_position.length()
			var t_in_air := 0.0
			var min_alt2 := 1.0e9
			Input.action_press("move_forward")
			var tt := 0.0
			while tt < 4.0:
				await _frames(1)
				tt += g.get_process_delta_time()
				if not p._grounded:
					t_in_air += g.get_process_delta_time()
				min_alt2 = minf(min_alt2, _alt())
			Input.action_release("move_forward")
			var rise := p.global_position.length() - a0
			print("[slope] %s %.1f deg: rise %.2f m in 4 s, speed %.2f, airborne %.2f s, min alt %.2f" % [case[2], case[1], rise, _hspeed(), t_in_air, min_alt2])
			_ok(min_alt2 > -0.4, "%s slope: never inside the ground (min alt %.2f)" % [case[2], min_alt2])
			if case[2] == "walkable":
				_ok(rise > 1.0 or float(case[1]) < 12.0, "walkable slope climbed (rise %.2f)" % rise)

	if _has("props"):
		print("---- props")
		var sm := _sm()
		var bodies: Dictionary = sm.get("_bodies") if sm != null else {}
		print("[props] collider bodies around the player: %d" % bodies.size())
		# nearest prop collider that is at least 6 m from anything else we care about
		var cands: Array = []
		for k in bodies:
			var b: Node3D = bodies[k]
			if is_instance_valid(b):
				cands.append(b)
		cands.sort_custom(func(a: Node3D, b: Node3D): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
		var tested := 0
		for ci in mini(cands.size(), 14):
			if tested >= 3:
				break
			var b2: Node3D = cands[ci]
			var bp := b2.global_position
			var bd := bp.normalized()
			var shape_info := ""
			for c in b2.get_children():
				if c is CollisionShape3D and (c as CollisionShape3D).shape != null:
					var sh := (c as CollisionShape3D).shape
					shape_info += sh.get_class() + " "
					if sh is CylinderShape3D:
						shape_info += "(r=%.2f h=%.1f) " % [(sh as CylinderShape3D).radius, (sh as CylinderShape3D).height]
					elif sh is BoxShape3D:
						shape_info += str((sh as BoxShape3D).size) + " "
			# approach from 7 m away along an arbitrary tangent
			var tangent := bd.cross(Vector3.RIGHT)
			if tangent.length() < 0.2:
				tangent = bd.cross(Vector3.UP)
			tangent = tangent.normalized().rotated(bd, float(ci) * 1.3)
			var start := (bp + tangent * 7.0)
			var sdir := start.normalized()
			await _place(sdir, -tangent)
			var start_pos := p.global_position
			_aim_at(bp + bd * 0.5)
			Input.action_press("move_forward")
			await _wait(4.0)
			Input.action_release("move_forward")
			await _frames(3)
			var rel := p.global_position - bp
			var along := rel.dot(-tangent)           # >0: still on the near side, <0: passed the prop
			var horiz := (rel - bd * rel.dot(bd)).length()
			print("[props] #%d %s shape=%s  start %.1f m  final horizontal distance %.2f m  along %.2f  speed %.2f  alt %.2f" % [ci, b2.name, shape_info, (start_pos - bp).length(), horiz, along, _hspeed(), _alt()])
			if shape_info != "":
				_ok(along < -0.15, "prop %s blocks the player (still on the near side, dist %.2f)" % [b2.name, horiz])
				tested += 1
			await _shot("prop_%d" % tested)

	if _has("res"):
		print("---- resources")
		var nodes := g.get_tree().get_nodes_in_group("resource_node")
		print("[res] resource nodes in the tree: %d" % nodes.size())
		var best: Node3D = null
		var bd2 := 1.0e9
		for n in nodes:
			var n3 := n as Node3D
			if n3 == null or not n3.is_inside_tree():
				continue
			var d3 := n3.global_position.distance_to(p.global_position)
			if d3 < bd2:
				bd2 = d3
				best = n3
		if best == null:
			print("[res] none in range -> teleporting 400 m along the terrain to find some")
		else:
			var rn := best as ResourceNode
			var rid := rn.res_id if rn != null else "?"
			print("[res] nearest: %s (%s) at %.1f m, hp=%.1f amount=%d scale=%.2f" % [best.name, rid, bd2, rn.hp if rn else -1.0, rn.amount if rn else -1, rn.node_scale if rn else -1.0])
			var bpos := best.global_position
			var bdir := bpos.normalized()
			var tan := bdir.cross(Vector3.RIGHT).normalized()
			await _place((bpos + tan * 6.0).normalized(), -tan)
			_aim_at(bpos + bdir * 0.6)
			await _frames(4)
			var have0 := int(Game.inventory.get(rid, 0))
			Input.action_press("fire")
			await _wait(1.0)
			await _shot("beam_a")
			var prog1 := float(Game.tel.get("mine_progress", 0.0))
			var t := 1.0
			while is_instance_valid(best) and t < 12.0:
				await _wait(0.5)
				t += 0.5
			Input.action_release("fire")
			_ok(not is_instance_valid(best) or best.is_queued_for_deletion(), "resource node destroyed in %.1f s (progress at 1 s: %.2f)" % [t, prog1])
			var have1 := int(Game.inventory.get(rid, 0))
			_ok(have1 > have0 or rid == "voidstone", "inventory %s %d -> %d" % [rid, have0, have1])
			await _wait(0.4)
			_ok(float(Game.tel.get("mine_progress", 1.0)) == 0.0, "mine_progress reset")
		# beam on bare terrain / prop must not error
		var gd := p.global_position.normalized()
		await _place(gd, home_fwd)
		_aim_at(p.global_position + home_fwd * 6.0 - gd * 1.5)
		Input.action_press("fire")
		await _wait(1.0)
		await _shot("beam_ground")
		Input.action_release("fire")

	if _has("scan"):
		print("---- scan")
		await _place(home_dir, home_fwd)
		Input.action_press("scan")
		await _wait(0.15)
		Input.action_release("scan")
		await _wait(1.2)
		await _shot("scan_a")
		await _wait(3.0)
		var kinds := {}
		for m in p.scan_markers:
			kinds[m["kind"]] = int(kinds.get(m["kind"], 0)) + 1
		print("[scan] markers: ", kinds)
		for m in p.scan_markers:
			print("   %s  %s  %.0f m" % [m["kind"], m["label"], (m["pos"] as Vector3).distance_to(p.global_position)])
		_ok(p.scan_markers.size() > 0, "scan found something (%d markers)" % p.scan_markers.size())
		await _shot("scan_markers")
		_ok(float(Game.tel.get("scan_cooldown", 0.0)) >= 0.0, "scan cooldown tel")

	if _has("hazard"):
		print("---- hazard")
		var died := [0]
		Events.player_died.connect(func(): died[0] += 1)
		# walk >10 m away from the ship (no life support there)
		var ship_dir := (Game.ship.global_position).normalized()
		var tan3 := ship_dir.cross(Vector3.RIGHT).normalized()
		await _place((Game.ship.global_position + tan3 * 40.0).normalized(), tan3)
		p.vitals.protection = 1.0
		await _wait(0.5)
		print("[hazard] %s level %.2f temp %.1f body %.1f prot %.3f" % [p.vitals.hazard, p.vitals.hazard_level, p.vitals.temp_c, p.vitals.body_temp_c, p.vitals.protection])
		var pr0 := p.vitals.protection
		await _wait(5.0)
		var drain := (pr0 - p.vitals.protection) / 5.0
		print("[hazard] drain %.4f /s -> ~%.0f s of protection" % [drain, 1.0 / maxf(drain, 1e-6)])
		if p.vitals.hazard_level > 0.0:
			_ok(drain > 0.0, "protection drains in '%s' (%.4f/s)" % [p.vitals.hazard, drain])
		else:
			_ok(absf(drain) < 0.001 or drain < 0.0, "no hazard, no drain here")
		await _shot("hazard")
		# damage + death + respawn
		Game.inventory["sodium"] = 0
		p.vitals.protection = 0.0
		p.vitals.health = 0.02
		if p.vitals.hazard_level > 0.0:
			await _wait(3.0)
			_ok(died[0] >= 1, "player_died emitted (%d)" % died[0])
			_ok(p.vitals.health > 0.5 and not p.vitals.dead, "vitals restored hp=%.2f" % p.vitals.health)
			_ok(Game.ship_distance_to_player() < 15.0, "respawned at the ship (%.1f m)" % Game.ship_distance_to_player())
		else:
			p.vitals.damage(1.0)
			await _wait(1.5)
			print("[hazard] (no ambient hazard here) forced death: died=%d" % died[0])
			_ok(died[0] >= 1 and Game.ship_distance_to_player() < 15.0, "forced death respawns at the ship")

	if _has("liquid"):
		print("---- liquid")
		var sea := planet.sea_radius()
		var found := Vector3.ZERO
		if sea > 0.0:
			var ref2 := home_dir.cross(Vector3.RIGHT).normalized()
			var tan4 := home_dir.cross(ref2)
			for ring in range(1, 40):
				var rr := float(ring) * 60.0
				for k in 24:
					var ang := float(k) / 24.0 * TAU
					var dd := (home_dir * planet.radius + (ref2 * cos(ang) + tan4 * sin(ang)) * rr).normalized()
					if planet.terrain_radius_at(dd) < sea - 1.2:
						found = dd
						break
				if found != Vector3.ZERO:
					break
		print("[liquid] kind=%s sea=%.1f found=%s" % [planet.def.ocean_kind, sea, str(found != Vector3.ZERO)])
		if found != Vector3.ZERO:
			# step from the liquid back toward the spawn until dry land
			var shore := found
			for s in 400:
				shore = (shore * planet.radius + (home_dir - shore) * 6.0).normalized()
				if planet.terrain_radius_at(shore) > sea + 0.4:
					break
			var to_liq := (found - shore)
			var facing := (to_liq - shore * to_liq.dot(shore)).normalized()
			await _place(shore, facing)
			await _wait(0.4)
			await _shot("liquid_shore")
			p.vitals.protection = 1.0
			p.vitals.health = 1.0
			Input.action_press("move_forward")
			var t0 := 0.0
			var max_depth := 0.0
			var min_speed := 99.0
			var shot_done := false
			while t0 < 9.0 and not p.vitals.dead:
				await _frames(1)
				t0 += g.get_process_delta_time()
				max_depth = maxf(max_depth, p._water_depth)
				if p._water_depth > 0.3:
					min_speed = minf(min_speed, _hspeed())
				if t0 > 4.0 and not shot_done:
					shot_done = true
					await _shot("liquid_in")
			Input.action_release("move_forward")
			print("[liquid] after 9 s: depth max %.2f  swim=%s hazard='%s' lvl=%.2f prot=%.2f health=%.2f min_speed_in_liquid=%.2f" % [max_depth, str(p._swimming), p.vitals.hazard, p.vitals.hazard_level, p.vitals.protection, p.vitals.health, min_speed])
			_ok(max_depth > 0.3, "walked into the liquid (depth %.2f)" % max_depth)
			if planet.def.ocean_kind == "lava" or planet.def.ocean_kind == "acid":
				_ok(p.vitals.hazard_level > 0.3 or p.vitals.health < 1.0 or p.vitals.protection < 0.9, "liquid '%s' hurts (prot %.2f hp %.2f)" % [planet.def.ocean_kind, p.vitals.protection, p.vitals.health])
	if _has("interact"):
		print("---- interact (POI interactables)")
		var smi := _sm()
		var tgts: Array = smi.call("get_scan_targets", p.global_position, 600.0)
		var tried := 0
		var want_kinds := ["Cache", "Container", "Monolith", "Beacon", "Terminal", "Outpost", "Tower", "Wreck"]
		tgts = tgts.filter(func(t: Dictionary): return t["kind"] == "poi")
		tgts.sort_custom(func(a: Dictionary, b: Dictionary): return (a["pos"] as Vector3).distance_to(p.global_position) < (b["pos"] as Vector3).distance_to(p.global_position))
		print("[interact] POIs within 600 m: ", tgts.map(func(t: Dictionary): return t["label"]))
		for t in tgts:
			if tried >= 3:
				break
			var tp: Vector3 = t["pos"]
			var td := tp.normalized()
			var tn := td.cross(Vector3.RIGHT).normalized()
			await _place((tp + tn * 16.0).normalized(), -tn)
			await _wait(3.0)       # the PoiStructure is instantiated once the focus is near
			# nearest interactable node in the tree
			var best_i: Node3D = null
			var best_d := 1.0e9
			for n in g.get_tree().get_nodes_in_group("interactable"):
				var n3 := n as Node3D
				if n3 == null or not n3.is_inside_tree():
					continue
				var dd := n3.global_position.distance_to(tp)
				if dd < best_d and dd < 30.0:
					best_d = dd
					best_i = n3
			if best_i == null:
				print("[interact] %s: no interactable node found near it (it may only be decorative)" % t["label"])
				continue
			tried += 1
			var ip := best_i.global_position
			var idir := ip.normalized()
			# stand 2.2 m from the interaction point, facing it
			var tan5 := idir.cross(Vector3.RIGHT).normalized()
			await _place((ip + tan5 * 2.2).normalized(), -tan5, 0.3)
			_aim_at(ip)
			await _wait(0.5)
			p._find_interactable()
			var prompt := str(best_i.call("get_prompt")) if best_i.has_method("get_prompt") else "?"
			print("[interact] %s: node=%s prompt='%s' target_ok=%s ship=%s" % [t["label"], best_i.name, prompt, str(p._interact_target == best_i), str(p._interact_is_ship)])
			_ok(p._interact_target == best_i, "player targets the %s interactable ('%s')" % [t["label"], prompt])
			var inv0 := Game.inventory.duplicate()
			Input.action_press("interact")
			await _wait(0.12)
			Input.action_release("interact")
			await _wait(0.8)
			var changed := false
			for k in Game.inventory:
				if Game.inventory[k] != inv0[k]:
					changed = true
			print("[interact]   inventory changed=%s  now=%s  prompt now='%s'" % [str(changed), str(Game.inventory), str(best_i.call("get_prompt")) if is_instance_valid(best_i) and best_i.has_method("get_prompt") else "-"])
	if _has("ship"):
		print("---- ship")
		var ship: Node3D = Game.ship
		var ex: Vector3 = ship.call("exit_position")
		p.spawn_at(ex, ex.normalized(), ship.call("exit_facing"))
		await _wait(1.0)
		p._find_interactable()
		_ok(p._interact_is_ship, "ship interactable from the exit point (dist %.1f)" % p._ship_distance())
		Input.action_press("interact")
		await _wait(0.12)
		Input.action_release("interact")
		await _wait(0.6)
		_ok(Game.mode == Game.Mode.SHIP and not p.active, "F enters the ship")
		_ok(p.scan_markers.is_empty(), "scan markers cleared when entering the ship")
		await _wait(0.5)
		Game.exit_ship(true)
		await _wait(1.0)
		_ok(Game.mode == Game.Mode.FOOT and p.active, "exit ship -> on foot")
		var up_err := acos(clampf(p.global_transform.basis.y.dot(p.global_position.normalized()), -1.0, 1.0))
		_ok(up_err < 0.01 and absf(_alt()) < 0.6, "exit: standing on the ground alt=%.2f" % _alt())
		# frame shift unit test (rotation + shift while the player is a passenger of the frame)
		var rot := Basis(Vector3(0.3, 0.8, 0.2).normalized(), 0.7)
		var v0 := Vector3(3, 0, -2)
		p.velocity = v0
		p.scan_markers.append({"pos": Vector3(10, 0, 0), "label": "t", "kind": "poi", "time_left": 5.0})
		p._on_frame_shift(rot, Vector3(1, 2, 3), Vector3(0.5, 0, 0))
		_ok(p.velocity.distance_to(rot * v0 + Vector3(0.5, 0, 0)) < 1e-4, "frame shift converts velocity")
		_ok((p.scan_markers[0]["pos"] as Vector3).distance_to(rot * Vector3(10, 0, 0) + Vector3(1, 2, 3)) < 1e-4, "frame shift converts scan markers")
		p.scan_markers.clear()

	if _has("shots"):
		print("---- shots")
		await _place(home_dir, home_fwd)
		await _shot("fp_idle")
		p.debug_look(0.0, 0.35)
		await _wait(0.4)
		await _shot("fp_down")
		p.debug_look(0.0, -0.35)
		# flashlight (most useful at night: run with --sun=-25)
		p.flashlight.visible = true
		await _wait(0.5)
		await _shot("fp_light")
		p.flashlight.visible = false
		Input.action_press("move_forward")
		Input.action_press("sprint")
		await _wait(1.5)
		await _shot("fp_sprint")
		Input.action_release("sprint")
		Input.action_release("move_forward")
		Input.action_press("toggle_camera")
		await _wait(0.12)
		Input.action_release("toggle_camera")
		await _wait(0.8)
		await _shot("tp_idle")
		Input.action_press("move_forward")
		await _wait(1.0)
		await _shot("tp_walk")
		Input.action_release("move_forward")
		Input.action_press("move_up")
		await _wait(1.8)
		await _shot("tp_jet")
		Input.action_release("move_up")
	print("[r2] done fails=", fails)
