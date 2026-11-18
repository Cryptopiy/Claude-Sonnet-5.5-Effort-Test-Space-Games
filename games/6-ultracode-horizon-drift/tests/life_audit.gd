extends RefCounted
## Periodic audit of the life module while a normal preset runs (no camera tricks): logs creatures near the focus, weather state, fps, extras.
##   --test=res://tests/life_audit.gd --preset=foot:1 [--every=4] [--n=6] [--pt=400 (sets Game.playing_time so the weather ramp is open)]
func run(game: Node) -> void:
	var every := 4.0
	var n := 6
	var pt := -1.0
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--every="):
			every = float(s.substr(8))
		elif s.begins_with("--n="):
			n = int(s.substr(4))
		elif s.begins_with("--pt="):
			pt = float(s.substr(5))
	var tree: SceneTree = game.get_tree()
	if pt >= 0.0:
		Game.playing_time = pt
	var ex: SystemExtras = game.system_node.get_node_or_null("Extras")
	if ex != null:
		print("[audit] extras: station=", ex.station != null, " freighters=", ex.freighters.size(), " sats=", ex.satellites.size(), " fields=", ex.fields.size())
	for i in n:
		await tree.create_timer(every).timeout
		var f: Node3D = Frame.focus
		var fp: Vector3 = f.global_position if f != null else Vector3.ZERO
		var fm: FaunaManager = game.fauna
		var c80 := 0
		var c150 := 0
		var c250 := 0
		var sp: Dictionary = {}
		var st: Dictionary = {}
		var min_alt := 1e9
		var max_alt := -1e9
		var pl := Frame.anchor_node() as Planet
		for c in fm.creatures.values():
			var cr := c as Creature
			var d: float = cr.position.distance_to(fp)
			if d < 80.0: c80 += 1
			if d < 150.0: c150 += 1
			if d < 250.0: c250 += 1
			sp[cr.species] = int(sp.get(cr.species, 0)) + 1
			st[cr.state] = int(st.get(cr.state, 0)) + 1
			if pl != null and (cr.type == "walker" or cr.type == "crawler"):
				var h := cr.position.length() - pl.terrain_radius_at(cr.position.normalized())
				min_alt = minf(min_alt, h)
				max_alt = maxf(max_alt, h)
		var w: WeatherFX = game.weather
		print("[audit] t=%.0f pt=%.0f anchor=%d fps=%d | creatures total=%d <80=%d <150=%d <250=%d species=%s states=%s walkerH=[%.2f..%.2f] | weather kind=%s int=%.2f fog=%.2f wind=%.1f" % [
			Time.get_ticks_msec() / 1000.0, Game.playing_time, Frame.anchor, Engine.get_frames_per_second(), fm.creature_count(), c80, c150, c250, sp, st,
			min_alt if min_alt < 1e8 else 0.0, max_alt if max_alt > -1e8 else 0.0, w.kind, w.intensity, w.fog_boost, w.wind.length()])
	print("[audit] done")
