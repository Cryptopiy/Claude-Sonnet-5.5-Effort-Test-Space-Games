extends RefCounted
## M4 vitals/hazard/swim test.  --test=res://tests/player_test2.gd --preset=foot:0 (hazards, volcanic)  or --preset=foot:1 (swimming, lush)

var g: Node
var fails := 0
var died := 0

func _wait(s: float) -> void:
	await g.get_tree().create_timer(s).timeout

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		fails += 1
		print("FAIL ", msg)

func _on_died() -> void:
	died += 1

func run(game: Node) -> void:
	g = game
	var p: Player = Game.player
	var planet := Frame.anchor_node() as Planet
	Events.player_died.connect(_on_died)
	await _wait(1.5)
	print("[test2] body=", planet.def.name, " biome=", planet.def.biome, " tel=", Game.tel)
	if planet.def.biome == "volcanic":
		_ok(Game.tel["hazard_level"] > 0.2, "volcanic hazard level %.2f (%s)" % [Game.tel["hazard_level"], Game.tel["hazard"]])
		# the ship is next to us: life support => no drain
		var prot0: float = p.vitals.protection
		await _wait(2.0)
		_ok(p.vitals.protection >= prot0 - 0.001, "no drain next to the ship")
		# walk away 30 m
		var far := p.global_position + p.global_transform.basis.x * 40.0
		var d := far.normalized()
		p.global_position = d * (planet.terrain_radius_at(d) + 0.5)
		await _wait(0.6)
		var prot1: float = p.vitals.protection
		p.vitals.protection = 0.5
		await _wait(3.0)
		_ok(p.vitals.protection < 0.5, "protection drains away from the ship (%.3f)" % p.vitals.protection)
		# sodium
		Game.inventory["sodium"] = 10
		p.vitals.protection = 0.2
		await _wait(1.5)
		_ok(int(Game.inventory["sodium"]) < 10 and p.vitals.protection > 0.25, "sodium recharges protection (sodium %d, prot %.2f)" % [Game.inventory["sodium"], p.vitals.protection])
		# damage when empty
		Game.inventory["sodium"] = 0
		p.vitals.protection = 0.0
		var h0: float = p.vitals.health
		await _wait(3.0)
		_ok(p.vitals.health < h0, "health drops without protection (%.3f -> %.3f)" % [h0, p.vitals.health])
		# death + respawn at the ship
		p.vitals.health = 0.0005
		await _wait(1.2)
		_ok(died >= 1, "player_died emitted (%d)" % died)
		_ok(p.vitals.health > 0.5 and not p.vitals.dead, "vitals restored after respawn (hp %.2f)" % p.vitals.health)
		var sd: float = Game.ship_distance_to_player()
		_ok(sd < 15.0, "respawned next to the ship (%.1f m)" % sd)
	else:
		# swimming: flood the current spot
		var d2 := p.global_position.normalized()
		var h := planet.height_at(d2)
		planet.water_level = h + 10.0
		await _wait(6.0)
		var st: Dictionary = p.debug_state()
		_ok(st["swim"], "swimming in deep water")
		var feet := p.global_position.length()
		var sea := planet.sea_radius()
		_ok(absf((sea - feet) - 1.44) < 0.5, "floats with the head above water (feet %.2f below surface)" % (sea - feet))
		Input.action_press("move_forward")
		await _wait(1.2)
		var spd: float = Game.tel["speed"]
		_ok(spd > 2.5 and spd < 4.3, "swim speed %.2f" % spd)
		Input.action_release("move_forward")
		Input.action_press("move_down")
		await _wait(1.5)
		_ok(p.global_position.length() < sea - 2.0, "dive with Ctrl")
		Input.action_release("move_down")
		Input.action_press("move_up")
		await _wait(2.5)
		_ok(p.global_position.length() > sea - 1.8, "surface with Space")
		Input.action_release("move_up")
		planet.water_level = h - 30.0
		await _wait(3.0)
		_ok(not p.debug_state()["swim"], "walks again once the water is gone")
	print("[test2] done fails=", fails)
