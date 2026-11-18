class_name Hud
extends Control
## In-game HUD drawn with custom _draw(): speed / altitude gauges, bars, location panel, target + scan markers,
## context prompt, toast messages, discovery banner, black hole warnings, controls cheat-sheet.

var world: SpaceWorld
var pc: PlayerController
var _t: float = 0.0
var toasts: Array = []
var banner_text: String = ""
var banner_life: float = 0.0
var help_t: float = 22.0
var show_fps: bool = false
var _prev_sun: float = 0.0
var _sun_rising: bool = true
var _hz_flash: float = 0.0
var s: float = 1.0
var cam: Camera3D

func setup(w: SpaceWorld, p: PlayerController) -> void:
	world = w
	pc = p
	cam = w.camera
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.message.connect(_on_message)
	Game.discovery.connect(_on_discovery)

func _on_message(text: String, secs: float, kind: String) -> void:
	for tt in toasts:
		if tt["text"] == text:
			tt["life"] = secs
			tt["max"] = secs
			return
	toasts.append({"text": text, "life": secs, "max": secs, "kind": kind})
	while toasts.size() > 5:
		toasts.pop_front()

func _on_discovery(text: String) -> void:
	banner_text = text
	banner_life = 6.0

func _process(delta: float) -> void:
	_t += delta
	help_t = maxf(0.0, help_t - delta)
	banner_life = maxf(0.0, banner_life - delta)
	for tt in toasts:
		tt["life"] = float(tt["life"]) - delta
	toasts = toasts.filter(func(x: Dictionary) -> bool: return float(x["life"]) > 0.0)
	_hz_flash = fmod(_hz_flash + delta * 3.0, TAU)
	if Input.is_action_just_pressed("help"):
		help_t = 0.0 if help_t > 0.5 else 30.0
	if world != null and world.frame_idx >= 0:
		var su: float = world.sun_up_at_viewer
		if absf(su - _prev_sun) > 0.00005:
			_sun_rising = su > _prev_sun
		_prev_sun = su
	queue_redraw()

# ----------------------------------------------------------------------------------------- helpers
func _txt(pos: Vector2, text: String, fs: float, col: Color, bold: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f: Font = UiKit.font_bold() if bold else UiKit.font()
	var px: int = int(maxf(8.0, fs * s))
	draw_string_outline(f, pos, text, align, width, px, 4, Color(0, 0, 0, 0.75))
	draw_string(f, pos, text, align, width, px, col)

func _ctext(center: Vector2, text: String, fs: float, col: Color, bold: bool = false) -> void:
	_txt(center - Vector2(900.0 * s, 0), text, fs, col, bold, HORIZONTAL_ALIGNMENT_CENTER, 1800.0 * s)

func _rtext(right_pos: Vector2, text: String, fs: float, col: Color, bold: bool = false) -> void:
	_txt(right_pos - Vector2(600.0 * s, 0), text, fs, col, bold, HORIZONTAL_ALIGNMENT_RIGHT, 600.0 * s)

func _bar(pos: Vector2, w: float, h: float, frac: float, col: Color, label_text: String, value_text: String = "") -> void:
	var f: float = clampf(frac, 0.0, 1.0)
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.02, 0.05, 0.09, 0.62))
	draw_rect(Rect2(pos, Vector2(w * f, h)), Color(col.r, col.g, col.b, 0.85))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(col.r, col.g, col.b, 0.5), false, 1.0)
	_txt(pos + Vector2(0, -5.0 * s), label_text, 15.0, UiKit.C_TEXT_DIM, true)
	if value_text != "":
		_rtext(pos + Vector2(w, -5.0 * s), value_text, 15.0, UiKit.C_TEXT)

func _panel(rect: Rect2, accent: Color = UiKit.C_MAIN) -> void:
	draw_rect(rect, Color(0.02, 0.05, 0.09, 0.55))
	draw_rect(Rect2(rect.position, Vector2(3.0 * s, rect.size.y)), accent)
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.25), false, 1.0)

func _on_screen(p: Vector2, margin: float = 60.0) -> bool:
	return p.x > -margin and p.y > -margin and p.x < size.x + margin and p.y < size.y + margin

func _diamond(c: Vector2, r: float, col: Color, filled: bool = false) -> void:
	if not _on_screen(c, 200.0):
		return
	if filled:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), col)
	else:
		draw_polyline(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0), c + Vector2(0, -r)]), col, 1.6, true)

func _project(p: Vector3) -> Variant:
	if cam == null or cam.is_position_behind(p):
		return null
	return cam.unproject_position(p)

func _edge_arrow(p: Vector3, col: Color, label_text: String) -> void:
	# arrow on the screen border pointing to an off-screen point
	var sz: Vector2 = size
	var ctr: Vector2 = sz * 0.5
	var local: Vector3 = cam.global_transform.affine_inverse() * p
	var d2 := Vector2(local.x, -local.y)
	if d2.length() < 0.001:
		d2 = Vector2(0, -1)
	d2 = d2.normalized()
	var m: float = 60.0 * s
	var k: float = minf((sz.x * 0.5 - m) / maxf(absf(d2.x), 0.001), (sz.y * 0.5 - m) / maxf(absf(d2.y), 0.001))
	var pos: Vector2 = ctr + d2 * k
	var ang: float = d2.angle()
	var tri := PackedVector2Array([pos + Vector2(14, 0).rotated(ang) * s, pos + Vector2(-8, -9).rotated(ang) * s, pos + Vector2(-8, 9).rotated(ang) * s])
	draw_colored_polygon(tri, col)
	_ctext(pos + Vector2(0, 28.0 * s) - d2 * 20.0 * s, label_text, 14.0, col)

# ----------------------------------------------------------------------------------------- draw
func _draw() -> void:
	if world == null or pc == null or world.sys == null:
		return
	s = maxf(size.y / 1080.0, 0.5)
	cam = world.camera
	var sz: Vector2 = size
	var ship: Ship = pc.ship
	var on_ship: bool = pc.mode == PlayerController.Mode.SHIP
	_draw_location_panel()
	_draw_markers(ship, on_ship)
	if on_ship:
		_draw_ship_hud(ship, sz)
	else:
		_draw_foot_hud(sz)
	_draw_prompt(sz)
	_draw_toasts(sz)
	_draw_bh_warning(sz)
	_draw_banner(sz)
	if help_t > 0.0:
		_draw_help(sz)
	else:
		_txt(Vector2(34.0 * s, sz.y - 22.0 * s), "H - controls   M - map   Esc - pause", 14.0, UiKit.C_TEXT_DIM)
	if show_fps:
		_rtext(Vector2(sz.x - 24.0 * s, 28.0 * s), "%d FPS" % Engine.get_frames_per_second(), 16.0, UiKit.C_TEXT_DIM)

func _draw_location_panel() -> void:
	var r := Rect2(Vector2(34.0, 30.0) * s, Vector2(430.0, 132.0) * s)
	_panel(r)
	var x: float = r.position.x + 20.0 * s
	var y: float = r.position.y + 30.0 * s
	var sys: SystemData = world.sys
	_txt(Vector2(x, y), "%s SYSTEM" % sys.name.to_upper(), 15.0, UiKit.C_TEXT_DIM, true)
	var star_txt: String = "Class %s star" % sys.star_class
	_rtext(Vector2(r.end.x - 16.0 * s, y), star_txt, 14.0, UiKit.C_TEXT_DIM)
	y += 34.0 * s
	if world.frame_idx >= 0:
		var b: BodyData = sys.bodies[world.frame_idx]
		_txt(Vector2(x, y), b.name.to_upper(), 28.0, UiKit.C_MAIN, true)
		y += 24.0 * s
		_txt(Vector2(x, y), "%s %s  |  g %.1f m/s2" % [b.biome_label(), "moon" if b.kind == "moon" else "world", b.gravity], 16.0, UiKit.C_TEXT)
		y += 22.0 * s
		var hz: Dictionary = b.profile.get("hazard", {})
		var ht: String = String(hz.get("type", "none"))
		var temp: int = int(hz.get("temp", 20))
		var sun_txt: String = _day_phase()
		_txt(Vector2(x, y), "%d C  |  %s  |  %s" % [temp, ("no hazard" if ht == "none" else ht + " hazard"), sun_txt], 15.0, UiKit.C_TEXT_DIM)
	else:
		var nb: int = world.nearest_body
		if nb >= 0:
			var b2: BodyData = sys.bodies[nb]
			_txt(Vector2(x, y), "DEEP SPACE", 26.0, UiKit.C_MAIN, true)
			y += 24.0 * s
			_txt(Vector2(x, y), "Nearest: %s  (%s)" % [b2.name, U.fmt_dist(maxf(world.nearest_dist - b2.radius, 0.0))], 16.0, UiKit.C_TEXT)
			y += 22.0 * s
			_txt(Vector2(x, y), "Star distance %s" % U.fmt_dist(world.viewer_sys.length()), 15.0, UiKit.C_TEXT_DIM)

func _day_phase() -> String:
	var su: float = world.sun_up_at_viewer
	var deg: float = rad_to_deg(asin(clampf(su, -1.0, 1.0)))
	var phase: String
	if su > 0.55:
		phase = "midday"
	elif su > 0.12:
		phase = "morning" if _sun_rising else "afternoon"
	elif su > -0.08:
		phase = "sunrise" if _sun_rising else "sunset"
	else:
		phase = "night"
	return "%s (sun %+d deg)" % [phase, int(deg)]

func _draw_markers(ship: Ship, on_ship: bool) -> void:
	var sys: SystemData = world.sys
	var cpos: Vector3 = cam.global_position
	var target_idx: int = ship.target_idx
	var n: int = sys.bodies.size()
	# bodies
	for i in n:
		var p: Planet = world.planets[i]
		var wp: Vector3 = p.global_position
		var b: BodyData = sys.bodies[i]
		var dist: float = maxf(cpos.distance_to(wp) - b.radius, 0.0)
		var is_target: bool = i == target_idx
		if world.frame_idx == i:
			continue
		# hide labels of bodies that already fill much of the screen
		var ang: float = atan2(b.radius, maxf(cpos.distance_to(wp), 1.0))
		var q: Variant = _project(wp)
		var col: Color = UiKit.C_WARN if is_target else Color(0.6, 0.92, 1.0, 0.8)
		if q != null:
			var qp: Vector2 = q
			if not Rect2(Vector2.ZERO, size).has_point(qp):
				if is_target:
					_edge_arrow(wp, col, "%s %s" % [b.name, U.fmt_dist(dist)])
				continue
			if ang > 0.35 and not is_target:
				continue
			var rr: float = (7.0 if not is_target else 10.0) * s
			_diamond(qp, rr, col, false)
			_txt(qp + Vector2(rr + 8.0 * s, 4.0 * s), b.name, 16.0, col, is_target)
			_txt(qp + Vector2(rr + 8.0 * s, 22.0 * s), U.fmt_dist(dist), 14.0, UiKit.C_TEXT_DIM)
		elif is_target:
			_edge_arrow(wp, col, "%s %s" % [b.name, U.fmt_dist(dist)])
	# star
	var sp: Vector3 = world.star.global_position
	var sdist: float = maxf(cpos.distance_to(sp) - sys.star_radius, 0.0)
	var star_is_target: bool = target_idx == n
	var sq: Variant = _project(sp)
	var scol: Color = UiKit.C_WARN if star_is_target else Color(1.0, 0.9, 0.6, 0.85)
	if sq != null and Rect2(Vector2.ZERO, size).has_point(sq):
		_diamond(sq, (10.0 if star_is_target else 7.0) * s, scol)
		_txt((sq as Vector2) + Vector2(16.0, 4.0) * s, sys.star_name + " (star)", 16.0, scol, star_is_target)
		_txt((sq as Vector2) + Vector2(16.0, 22.0) * s, U.fmt_dist(sdist), 14.0, UiKit.C_TEXT_DIM)
	elif star_is_target:
		_edge_arrow(sp, scol, "%s %s" % [sys.star_name, U.fmt_dist(sdist)])
	# orbital stations
	for pl in world.planets:
		var pr: SpaceProps = (pl as Planet).props
		if pr == null or pr.station_node == null:
			continue
		var stpos: Vector3 = pr.station_node.global_position
		var stdist: float = cpos.distance_to(stpos)
		if stdist > 120000.0 or stdist < 150.0:
			continue
		var stq: Variant = _project(stpos)
		if stq != null and _on_screen(stq as Vector2, 10.0):
			var stc := Color(0.55, 1.0, 0.8, 0.9)
			_diamond(stq, 6.0 * s, stc, false)
			_txt((stq as Vector2) + Vector2(14.0, 4.0) * s, pr.station_name, 15.0, stc)
			_txt((stq as Vector2) + Vector2(14.0, 20.0) * s, U.fmt_dist(stdist), 13.0, UiKit.C_TEXT_DIM)
	# black hole
	if world.bh != null:
		var bp: Vector3 = world.bh.global_position
		var bdist: float = maxf(cpos.distance_to(bp) - sys.bh_rs, 0.0)
		var bh_target: bool = target_idx == n + 1
		var bq: Variant = _project(bp)
		var bcol: Color = UiKit.C_WARN if bh_target else Color(0.95, 0.5, 1.0, 0.85)
		if bq != null and Rect2(Vector2.ZERO, size).has_point(bq):
			_diamond(bq, (10.0 if bh_target else 7.0) * s, bcol)
			_txt((bq as Vector2) + Vector2(16.0, 4.0) * s, "BLACK HOLE", 16.0, bcol, bh_target)
			_txt((bq as Vector2) + Vector2(16.0, 22.0) * s, U.fmt_dist(bdist), 14.0, UiKit.C_TEXT_DIM)
		elif bh_target:
			_edge_arrow(bp, bcol, "BLACK HOLE %s" % U.fmt_dist(bdist))
	# ship marker when on foot
	if not on_ship and world.frame_idx >= 0:
		var shp: Vector3 = ship.global_position + ship.global_basis.y * 2.0
		var d: float = cpos.distance_to(shp)
		var qs: Variant = _project(shp)
		if qs != null and d > 14.0:
			_diamond(qs, 7.0 * s, UiKit.C_GOOD)
			_txt((qs as Vector2) + Vector2(14.0, 4.0) * s, "SHIP  %s" % U.fmt_dist(d), 15.0, UiKit.C_GOOD)
	# scan results
	if pc.scan_t < 30.0 and not pc.scan_hits.is_empty():
		var fade: float = clampf((30.0 - pc.scan_t) / 6.0, 0.0, 1.0)
		for h in pc.scan_hits:
			var wp2: Vector3 = h["pos"]
			if world.frame_idx >= 0:
				wp2 = world.planets[world.frame_idx].global_transform * wp2 if String(h.get("kind", "")) == "resource" or String(h.get("kind", "")) == "base" or true else wp2
			var q2: Variant = _project(wp2)
			if q2 == null or not _on_screen(q2):
				continue
			var kind: String = String(h.get("kind", ""))
			var c2: Color = Color(0.55, 1.0, 0.7, fade)
			if kind == "resource":
				c2 = Color(0.45, 0.85, 1.0, fade)
			elif kind == "crate":
				c2 = Color(1.0, 0.8, 0.3, fade)
			elif kind == "creature":
				c2 = Color(1.0, 0.55, 0.85, fade)
			var d2: float = cpos.distance_to(wp2)
			_diamond(q2, 6.0 * s, c2, true)
			_txt((q2 as Vector2) + Vector2(12.0, 5.0) * s, "%s  %s" % [h["label"], U.fmt_dist(d2)], 14.0, c2)
	# scan pulse ring
	if pc.scan_t < 1.6:
		var ctr: Vector2 = size * 0.5
		var rad: float = pc.scan_t / 1.6 * size.y * 0.7
		draw_arc(ctr, rad, 0, TAU, 96, Color(0.5, 1.0, 0.8, 0.5 * (1.0 - pc.scan_t / 1.6)), 3.0 * s, true)

func _draw_ship_hud(ship: Ship, sz: Vector2) -> void:
	var c := Vector2(sz.x * 0.5, sz.y - 108.0 * s)
	var spd: float = ship.speed_ref
	# --- reticle at the nose
	var nose_world: Vector3 = ship.global_position - ship.global_basis.z * 400.0
	var nq: Variant = _project(nose_world)
	var rp: Vector2 = sz * 0.5
	if nq != null and ship.cam_mode == 0:
		rp = nq
	var rc: Color = UiKit.C_MAIN
	draw_arc(rp, 17.0 * s, 0, TAU, 40, Color(rc.r, rc.g, rc.b, 0.7), 1.8 * s, true)
	draw_line(rp + Vector2(-30, 0) * s, rp + Vector2(-20, 0) * s, rc, 1.8 * s)
	draw_line(rp + Vector2(30, 0) * s, rp + Vector2(20, 0) * s, rc, 1.8 * s)
	draw_line(rp + Vector2(0, -30) * s, rp + Vector2(0, -20) * s, rc, 1.8 * s)
	draw_circle(rp, 2.0 * s, rc)
	# velocity vector (prograde)
	if spd > 6.0 and ship.state == Ship.State.FLYING:
		var vq: Variant = _project(cam.global_position + ship.velocity.normalized() * 1000.0)
		if vq != null:
			var vp: Vector2 = vq
			draw_arc(vp, 10.0 * s, 0, TAU, 24, UiKit.C_GOOD, 1.6 * s, true)
			draw_line(vp + Vector2(0, -10) * s, vp + Vector2(0, -20) * s, UiKit.C_GOOD, 1.6 * s)
			draw_line(vp + Vector2(-10, 0) * s, vp + Vector2(-20, 0) * s, UiKit.C_GOOD, 1.6 * s)
			draw_line(vp + Vector2(10, 0) * s, vp + Vector2(20, 0) * s, UiKit.C_GOOD, 1.6 * s)
	# --- speed gauge
	var radius: float = 80.0 * s
	var a0: float = deg_to_rad(150.0)
	var a1: float = deg_to_rad(390.0)
	draw_arc(c, radius, a0, a1, 64, Color(0.1, 0.2, 0.3, 0.55), 9.0 * s, true)
	var cap: float = 450.0
	var frac: float
	if ship.pulse_on:
		frac = 0.55 + 0.45 * clampf(spd / Ship.PULSE_SPEED, 0.0, 1.0)
	else:
		frac = clampf(spd / (1300.0 if ship.boosting else cap), 0.0, 0.55) / 0.55 * 0.55
	var gcol: Color = UiKit.C_MAIN
	if ship.pulse_on:
		gcol = Color(0.7, 0.6, 1.0)
	elif ship.boosting:
		gcol = UiKit.C_WARN
	draw_arc(c, radius, a0, a0 + (a1 - a0) * clampf(frac, 0.0, 1.0), 64, gcol, 9.0 * s, true)
	_ctext(c + Vector2(0, 10.0 * s), U.fmt_speed(spd).split(" ")[0], 38.0, UiKit.C_TEXT, true)
	_ctext(c + Vector2(0, 34.0 * s), U.fmt_speed(spd).split(" ")[1], 16.0, UiKit.C_TEXT_DIM)
	var mode_txt: String = "CRUISE"
	var mode_col: Color = UiKit.C_MAIN
	if ship.state == Ship.State.LANDED:
		mode_txt = "PARKED"
		mode_col = UiKit.C_GOOD
	elif ship.auto_pulse:
		mode_txt = "AUTO-PULSE"
		mode_col = Color(0.75, 0.65, 1.0)
	elif ship.pulse_on:
		mode_txt = "PULSE DRIVE"
		mode_col = Color(0.75, 0.65, 1.0)
	elif ship.landing_assist:
		mode_txt = "LANDING ASSIST"
		mode_col = UiKit.C_GOOD
	elif ship.boosting:
		mode_txt = "BOOST"
		mode_col = UiKit.C_WARN
	_ctext(c + Vector2(0, -44.0 * s), mode_txt, 17.0, mode_col, true)
	# --- left: ship bars
	var lx: float = 60.0 * s
	var ly: float = sz.y - 170.0 * s
	_bar(Vector2(lx, ly), 300.0 * s, 12.0 * s, ship.shield / 100.0, UiKit.C_MAIN if ship.shield > 35.0 else UiKit.C_DANGER, "SHIELD", "%d%%" % int(ship.shield))
	_bar(Vector2(lx, ly + 44.0 * s), 300.0 * s, 12.0 * s, ship.boost_energy, UiKit.C_WARN, "BOOST", "%d%%" % int(ship.boost_energy * 100.0))
	var gear_txt: String = "GEAR %s" % ("DOWN" if ship.gear > 0.9 else ("UP" if ship.gear < 0.1 else "..."))
	_txt(Vector2(lx, ly + 84.0 * s), gear_txt, 15.0, UiKit.C_GOOD if ship.gear > 0.9 else UiKit.C_TEXT_DIM, true)
	if ship.heat > 0.05:
		_txt(Vector2(lx + 130.0 * s, ly + 84.0 * s), "ATMOSPHERIC ENTRY  %d%%" % int(ship.heat * 100.0), 15.0, UiKit.C_WARN, true)
	# --- right: altitude / target
	var rx: float = sz.x - 60.0 * s
	var ry: float = sz.y - 190.0 * s
	if world.frame_idx >= 0:
		var alt: float = world.altitude
		_rtext(Vector2(rx, ry), "ALTITUDE", 15.0, UiKit.C_TEXT_DIM, true)
		_rtext(Vector2(rx, ry + 34.0 * s), U.fmt_dist(alt), 32.0, UiKit.C_TEXT, true)
		var vs: float = ship.velocity.dot(ship.position.normalized())
		var vcol: Color = UiKit.C_TEXT_DIM
		if alt < 300.0 and vs < -12.0:
			vcol = UiKit.C_WARN
		_rtext(Vector2(rx, ry + 62.0 * s), "V/S %+d m/s" % int(vs), 17.0, vcol, true)
		var air_txt: String = "air density %d%%" % int(world.air * 100.0)
		_rtext(Vector2(rx, ry + 86.0 * s), air_txt, 14.0, UiKit.C_TEXT_DIM)
	else:
		var info: Dictionary = ship.target_info()
		_rtext(Vector2(rx, ry), "TARGET", 15.0, UiKit.C_TEXT_DIM, true)
		if info.is_empty():
			_rtext(Vector2(rx, ry + 34.0 * s), "none", 28.0, UiKit.C_TEXT_DIM, true)
			_rtext(Vector2(rx, ry + 62.0 * s), "T - select target", 15.0, UiKit.C_TEXT_DIM)
		else:
			var d: float = float(info["dist"])
			_rtext(Vector2(rx, ry + 34.0 * s), String(info["name"]), 28.0, UiKit.C_WARN, true)
			_rtext(Vector2(rx, ry + 62.0 * s), U.fmt_dist(d), 20.0, UiKit.C_TEXT, true)
			if spd > 50.0:
				var eta: float = d / maxf(spd, 1.0)
				_rtext(Vector2(rx, ry + 86.0 * s), "ETA %s" % (("%d s" % int(eta)) if eta < 600.0 else ("%d min" % int(eta / 60.0))), 15.0, UiKit.C_TEXT_DIM)
	# --- inventory strip
	var inv := "Carbon %d   Ferrite %d   Sodium %d   Warp cells %d" % [Game.get_item("carbon"), Game.get_item("ferrite"), Game.get_item("sodium"), Game.get_item("warp_cells")]
	_rtext(Vector2(rx, sz.y - 40.0 * s), inv, 15.0, UiKit.C_TEXT_DIM)

func _draw_foot_hud(sz: Vector2) -> void:
	var astro: Astronaut = pc.astro
	var ctr: Vector2 = sz * 0.5
	var over: bool = pc.prompt != ""
	draw_circle(ctr, 2.5 * s, Color(1, 1, 1, 0.9))
	draw_arc(ctr, (11.0 if over else 7.0) * s, 0, TAU, 28, Color(UiKit.C_MAIN.r, UiKit.C_MAIN.g, UiKit.C_MAIN.b, 0.75 if over else 0.35), 1.6 * s, true)
	var lx: float = 60.0 * s
	var ly: float = sz.y - 190.0 * s
	_bar(Vector2(lx, ly), 300.0 * s, 12.0 * s, pc.health / 100.0, UiKit.C_GOOD if pc.health > 40.0 else UiKit.C_DANGER, "HEALTH", "%d%%" % int(pc.health))
	var pcol: Color = UiKit.C_MAIN
	if pc.protection < 30.0:
		pcol = UiKit.C_DANGER
	elif pc.protection < 60.0:
		pcol = UiKit.C_WARN
	var hz_label: String = "HAZARD PROTECTION"
	if pc.hazard_type != "none":
		hz_label = "%s PROTECTION" % pc.hazard_type.to_upper()
	_bar(Vector2(lx, ly + 44.0 * s), 300.0 * s, 12.0 * s, pc.protection / 100.0, pcol, hz_label, "%d%%" % int(pc.protection))
	_bar(Vector2(lx, ly + 88.0 * s), 300.0 * s, 12.0 * s, astro.jet_fuel, Color(0.55, 0.8, 1.0), "JETPACK", "%d%%" % int(astro.jet_fuel * 100.0))
	if pc.hazard_type != "none" and not pc.in_safe_zone:
		var a: float = 0.6 + 0.4 * sin(_hz_flash)
		var lvl: Color = UiKit.C_DANGER if pc.protection < 30.0 else UiKit.C_WARN
		_txt(Vector2(lx, ly - 34.0 * s), "! %s HAZARD  -%.1f%%/s   [G] recharge (Sodium)" % [pc.hazard_type.to_upper(), pc.hazard_rate], 16.0, Color(lvl.r, lvl.g, lvl.b, a), true)
	var rx: float = sz.x - 60.0 * s
	var ry: float = sz.y - 190.0 * s
	_rtext(Vector2(rx, ry), "SPEED", 15.0, UiKit.C_TEXT_DIM, true)
	_rtext(Vector2(rx, ry + 34.0 * s), "%.1f m/s" % astro.speed_h, 30.0, UiKit.C_TEXT, true)
	var alt_txt: String = "%.0f m above ground" % maxf(world.altitude, 0.0)
	if astro.in_water:
		alt_txt = "SWIMMING"
	_rtext(Vector2(rx, ry + 62.0 * s), alt_txt, 16.0, UiKit.C_TEXT_DIM, true)
	var inv := "Carbon %d   Ferrite %d   Sodium %d   Warp cells %d" % [Game.get_item("carbon"), Game.get_item("ferrite"), Game.get_item("sodium"), Game.get_item("warp_cells")]
	_rtext(Vector2(rx, sz.y - 40.0 * s), inv, 15.0, UiKit.C_TEXT_DIM)

func _draw_prompt(sz: Vector2) -> void:
	if pc.prompt == "":
		return
	var c := Vector2(sz.x * 0.5, sz.y * 0.68)
	var key: String = pc.prompt_key
	var pulse: float = 0.85 + 0.15 * sin(_t * 4.0)
	if key != "":
		var kr := Rect2(c + Vector2(-190.0 * s, -26.0 * s), Vector2(44.0 * s, 44.0 * s))
		draw_rect(kr, Color(0.03, 0.08, 0.12, 0.85))
		draw_rect(kr, Color(UiKit.C_MAIN.r, UiKit.C_MAIN.g, UiKit.C_MAIN.b, pulse), false, 2.0 * s)
		_txt(kr.position + Vector2(0, 31.0 * s), key, 26.0, UiKit.C_MAIN, true, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x)
		_txt(Vector2(kr.end.x + 18.0 * s, c.y + 6.0 * s), pc.prompt, 22.0, UiKit.C_TEXT, true)
	else:
		_ctext(c, pc.prompt, 22.0, UiKit.C_TEXT, true)

func _draw_toasts(sz: Vector2) -> void:
	var y: float = sz.y * 0.61
	var i: int = toasts.size() - 1
	while i >= 0:
		var tt: Dictionary = toasts[i]
		var life: float = float(tt["life"])
		var a: float = clampf(life / 0.6, 0.0, 1.0) * clampf((float(tt["max"]) - life) / 0.15 + 0.2, 0.0, 1.0)
		var col: Color = UiKit.C_TEXT
		match String(tt["kind"]):
			"warn":
				col = UiKit.C_WARN
			"good":
				col = UiKit.C_GOOD
		col.a = a
		_ctext(Vector2(sz.x * 0.5, y), String(tt["text"]), 20.0, col, String(tt["kind"]) == "warn")
		y -= 28.0 * s
		i -= 1

func _draw_banner(sz: Vector2) -> void:
	if banner_life <= 0.0:
		return
	var a: float = clampf(banner_life / 1.2, 0.0, 1.0) * clampf((6.0 - banner_life) / 0.6, 0.0, 1.0)
	var c := Vector2(sz.x * 0.5, sz.y * 0.2)
	draw_rect(Rect2(c + Vector2(-380.0 * s, -34.0 * s), Vector2(760.0 * s, 78.0 * s)), Color(0.02, 0.06, 0.1, 0.6 * a))
	draw_line(c + Vector2(-380.0 * s, -34.0 * s), c + Vector2(380.0 * s, -34.0 * s), Color(UiKit.C_MAIN.r, UiKit.C_MAIN.g, UiKit.C_MAIN.b, a), 2.0 * s)
	_ctext(c + Vector2(0, -8.0 * s), "DISCOVERY", 15.0, Color(UiKit.C_MAIN.r, UiKit.C_MAIN.g, UiKit.C_MAIN.b, a), true)
	_ctext(c + Vector2(0, 26.0 * s), banner_text, 26.0, Color(1, 1, 1, a), true)

func _draw_bh_warning(sz: Vector2) -> void:
	var info: Dictionary = world.bh_info
	if info.is_empty():
		return
	var zone: int = int(info.get("zone", 0))
	if zone <= 0:
		return
	var c := Vector2(sz.x * 0.5, 120.0 * s)
	var flash: float = 0.55 + 0.45 * sin(_t * (3.0 + zone * 2.5))
	var col: Color = UiKit.C_WARN
	var head: String = "GRAVITATIONAL ANOMALY"
	if zone == 2:
		head = "DANGER - STRONG GRAVITY"
		col = Color(1.0, 0.45, 0.2)
	elif zone >= 3:
		head = "POINT OF NO RETURN"
		col = UiKit.C_DANGER
	_ctext(c, head, 30.0, Color(col.r, col.g, col.b, flash), true)
	var dist: float = float(info.get("dist", 0.0))
	var pull: float = float(info.get("pull_ratio", 0.0))
	_ctext(c + Vector2(0, 30.0 * s), "Horizon %s    Pull %d%% of thrust" % [U.fmt_dist(dist), int(clampf(pull, 0.0, 9.99) * 100.0)], 18.0, UiKit.C_TEXT)
	# thrust margin bar
	var bw: float = 360.0 * s
	var bx: float = c.x - bw * 0.5
	var by: float = c.y + 52.0 * s
	draw_rect(Rect2(bx, by, bw, 10.0 * s), Color(0.02, 0.05, 0.09, 0.6))
	var fill: float = clampf(pull, 0.0, 1.5) / 1.5
	draw_rect(Rect2(bx, by, bw * fill, 10.0 * s), Color(col.r, col.g, col.b, 0.9))
	draw_line(Vector2(bx + bw * (1.0 / 1.5), by - 4.0 * s), Vector2(bx + bw * (1.0 / 1.5), by + 14.0 * s), Color.WHITE, 2.0 * s)
	_ctext(Vector2(c.x, by + 32.0 * s), "pull exceeds engine power past the white mark", 14.0, UiKit.C_TEXT_DIM)

func _draw_help(sz: Vector2) -> void:
	var a: float = clampf(help_t / 1.5, 0.0, 1.0)
	var rows: Array = []
	if pc.mode == PlayerController.Mode.SHIP:
		rows = [
			["Mouse", "steer (pitch / yaw)"], ["W / S", "thrust forward / reverse"], ["A / D", "strafe"], ["Space / Ctrl", "up / down"],
			["Q / E", "roll"], ["Shift", "boost"], ["X", "pulse drive (deep space only)"], ["T / Z", "select target / auto-pulse"],
			["L", "landing assist (below 2 km)"], ["F", "exit ship when landed"], ["V", "chase / cockpit view"], ["M", "galaxy map"],
		]
	else:
		rows = [
			["Mouse", "look"], ["W A S D", "walk"], ["Shift", "sprint"], ["Space", "jump / hold for jetpack"],
			["F", "interact / enter ship"], ["R", "scanner pulse"], ["G", "recharge protection (Sodium)"], ["V", "first / third person"],
			["M", "galaxy map"], ["Esc", "pause menu"],
		]
	var w: float = 520.0 * s
	var h: float = (rows.size() * 27.0 + 54.0) * s
	var r := Rect2(Vector2(sz.x - w - 40.0 * s, 40.0 * s), Vector2(w, h))
	draw_rect(r, Color(0.02, 0.05, 0.09, 0.7 * a))
	draw_rect(r, Color(UiKit.C_MAIN.r, UiKit.C_MAIN.g, UiKit.C_MAIN.b, 0.35 * a), false, 1.0)
	_txt(r.position + Vector2(20.0, 32.0) * s, "CONTROLS", 17.0, Color(UiKit.C_MAIN.r, UiKit.C_MAIN.g, UiKit.C_MAIN.b, a), true)
	var y: float = r.position.y + 62.0 * s
	for row in rows:
		_txt(Vector2(r.position.x + 22.0 * s, y), String(row[0]), 16.0, Color(1, 0.86, 0.5, a), true)
		_txt(Vector2(r.position.x + 170.0 * s, y), String(row[1]), 16.0, Color(UiKit.C_TEXT.r, UiKit.C_TEXT.g, UiKit.C_TEXT.b, a))
		y += 27.0 * s
