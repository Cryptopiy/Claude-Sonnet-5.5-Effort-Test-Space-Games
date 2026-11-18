extends RefCounted
## Content test (M7a): resource nodes: contract of mine(), Game.depleted_nodes, determinism of the node set (same view twice).

func _snapshot(sm: ScatterManager) -> Array:
	var out: Array = []
	for n in sm.get_tree().get_nodes_in_group("resource_node"):
		var rn := n as ResourceNode
		if rn != null and rn.get_parent() == sm:
			out.append("%s@%.1f,%.1f,%.1f" % [rn.node_id, rn.position.x, rn.position.y, rn.position.z])
	out.sort()
	return out

func run(game: Node) -> void:
	var def: BodyDef = Frame.anchor_def()
	var planet: Node3D = Frame.anchor_node()
	var sm: ScatterManager = planet.get_node_or_null("ScatterManager")
	var fc: Node3D = game.freecam
	var start := PoiSites.start_dir(def)
	await game.get_tree().create_timer(4.0).timeout
	var snap1 := _snapshot(sm)
	print("[mine] nodes near start: %d" % snap1.size())
	var counts: Dictionary = {}
	for n in game.get_tree().get_nodes_in_group("resource_node"):
		var rn := n as ResourceNode
		if rn != null:
			counts[rn.res_id] = int(counts.get(rn.res_id, 0)) + 1
	print("[mine] by type: ", counts)
	# determinism: leave (far away, nodes unload), come back, compare the set
	var far := ScatterGrid.walk(start, 1.0, 5000.0, def.radius)
	fc.global_position = far * (float(planet.call("terrain_radius_at", far)) + 3000.0)
	await game.get_tree().create_timer(6.0).timeout
	print("[mine] while away: nodes=%d stats=%s" % [_snapshot(sm).size(), str(sm.stats())])
	fc.global_position = start * (float(planet.call("terrain_radius_at", start)) + 5.0)
	await game.get_tree().create_timer(5.0).timeout
	var snap2 := _snapshot(sm)
	print("[mine] same view twice: %s (%d vs %d nodes)" % ["PASS" if snap1 == snap2 else "FAIL", snap1.size(), snap2.size()])
	# mining contract
	var target: ResourceNode = null
	for n in game.get_tree().get_nodes_in_group("resource_node"):
		var rn2 := n as ResourceNode
		if rn2 != null and rn2.res_id == "ferrite":
			target = rn2
			break
	if target == null:
		print("FAIL no ferrite node found")
		return
	var id := target.node_id
	var last: Dictionary = {}
	var hits := 0
	while hits < 40:
		last = target.mine(0.5)
		hits += 1
		if last["destroyed"]:
			break
	print("[mine] result=%s after %d hits" % [str(last), hits])
	await game.get_tree().create_timer(0.3).timeout
	var ok: bool = bool(last["destroyed"]) and int(last["amount"]) > 0 and Game.depleted_nodes.has(id) and not is_instance_valid(target)
	print("[mine] depleted registered=%s node freed=%s" % [str(Game.depleted_nodes.has(id)), str(not is_instance_valid(target))])
	# leave & return: the depleted node must stay gone
	fc.global_position = far * (float(planet.call("terrain_radius_at", far)) + 3000.0)
	await game.get_tree().create_timer(6.0).timeout
	fc.global_position = start * (float(planet.call("terrain_radius_at", start)) + 5.0)
	await game.get_tree().create_timer(5.0).timeout
	var again := false
	for s in _snapshot(sm):
		if s.begins_with(id + "@"):
			again = true
	print("[mine] depleted node respawned: %s" % str(again))
	print("PASS content_mine" if ok and not again and snap1 == snap2 else "FAIL content_mine")
