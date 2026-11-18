extends RefCounted
## Content test (M7a): close-up screenshots of every structure kind of the start area + interaction checks (loot, reveal, persistence).
##   godot.ps1 ... -GodotArgs "--resolution 1280x720 -- --autostart --preset=freecam:1:5 --test=res://tests/content_structures.gd"

var _events: Array = []

func _on_notify(text: String, kind: String) -> void:
	_events.append("%s: %s" % [kind, text])

func run(game: Node) -> void:
	var def: BodyDef = Frame.anchor_def()
	var planet: Node3D = Frame.anchor_node()
	var sm: ScatterManager = planet.get_node_or_null("ScatterManager")
	var R := def.radius
	var pois := PoiSites.for_body(def)
	Events.notify.connect(_on_notify)
	var fc: Node3D = game.freecam
	var seen: Dictionary = {}
	var order: Array = []
	for i in pois.size():
		var k: String = pois[i]["kind"]
		if not seen.has(k):
			seen[k] = i
			order.append(i)
	# prefer the settlement nearest to the start for outpost / tower / solar / depot
	var shots := 0
	for i in order:
		var p: Dictionary = pois[i]
		var cam_dir := ScatterGrid.walk(p["dir"], float(p["yaw"]), 26.0 if p["kind"] != "container" else 9.0, R)
		var r0: float = planet.call("terrain_radius_at", cam_dir)
		fc.global_position = cam_dir * (r0 + 3.0)
		var rp: float = planet.call("terrain_radius_at", p["dir"])
		var tgt: Vector3 = (p["dir"] as Vector3) * (rp + (4.0 if p["kind"] != "container" else 1.0))
		fc.look_at(tgt, cam_dir)
		await game.get_tree().create_timer(3.2).timeout
		var img := game.get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://.previews/content_struct_%s_%s.png" % [def.biome, p["kind"]])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		img.save_png(path)
		var node := sm.poi_node(i)
		print("[struct] %-12s model=%-22s node=%s fps=%d" % [p["kind"], p.get("model", ""), str(node != null), Engine.get_frames_per_second()])
		shots += 1
	# ---- interaction checks ------------------------------------------------------------------------------------------------------
	var before: Dictionary = Game.inventory.duplicate()
	var used := 0
	for i in order:
		var node := sm.poi_node(i)
		if node == null:
			continue
		var st := node as PoiStructure
		var it := st.interactable
		if it == null:
			continue
		if not it.can_interact(null):
			print("[interact] %-10s not usable: %s" % [st.kind, it.get_prompt()])
			continue
		var inv0: Dictionary = Game.inventory.duplicate()
		print("[interact] %-10s prompt=\"%s\"" % [st.kind, it.get_prompt()])
		it.interact(null)
		await game.get_tree().create_timer(0.3).timeout
		var changed := false
		for k in Game.inventory:
			if Game.inventory[k] != inv0.get(k, 0):
				changed = true
		print("[interact] %-10s inventory changed=%s now_usable=%s" % [st.kind, str(changed), str(it.can_interact(null))])
		used += 1
	print("[interact] events:")
	for e in _events:
		print("   ", e)
	print("[interact] inventory before=%s after=%s revealed=%d" % [str(before), str(Game.inventory), PoiSites.revealed.size()])
	print("PASS content_structures shots=%d interactions=%d" % [shots, used])
