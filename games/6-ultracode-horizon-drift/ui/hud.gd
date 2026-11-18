class_name Hud
extends Control
## IN-GAME HUD (module M6). One custom-drawn control: location banner, compass strip, flight / vitals readouts, bars, crosshair,
## world markers (bodies, star, black hole, nav target, scanner results), context + transient hints, toast stack, black-hole warning,
## flash overlay and FPS counter. Reads Game.tel (+ Game.context_hint) and listens to the Events bus. Runs at process priority 150
## (after Frame has finished moving everything this frame, before Game clears the context hint at 200).

const MARGIN := 26.0
const BH_ZONE_FAR := 420000.0

# ---- state --------------------------------------------------------------------------------------------------------------
var _t: float = 0.0
var _hud_a: float = 0.0                 # global fade (intro / warp)
var _poll: float = 0.0
var _disp: Dictionary = {}              # smoothed display values

# location banner
var _loc_system: String = ""
var _loc_title: String = ""
var _loc_sub: String = ""
var _loc_flag: String = ""
var _banner_t: float = 99.0
var _last_anchor: int = -2
var _last_sys: int = -2

# toasts / hints
var _toasts: Array = []                 # {text, kind, age, life, h}
var _hint_text: String = ""
var _hint_age: float = 99.0
var _hint_life: float = 0.0
var _ctx_text: String = ""
var _ctx_a: float = 0.0
var _picks: Array = []                  # {id, amt, age}
var _scan_t: float = 99.0

# flash
var _flash_col: Color = Color(1, 1, 1, 0)
var _flash_t: float = 0.0
var _flash_dur: float = 0.01

# black hole
var _bh_level: int = 0
var _bh_a: float = 0.0
var _bh_dist: float = 0.0

var _markers: Array = []
var _placed: Array = []                  # label rects already placed this frame (world + scan markers avoid each other)
var _heading: float = 0.0
var _ninfo: Array = []                  # [north, east, up] in local space
var _fps_text: String = ""
var _env: Dictionary = {}               # cached ship environment readouts (see _ship_env)
var _env_age: float = 99.0

func _ready() -> void:
	process_priority = 150
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()
	UITheme.apply_scaling(get_window())
	Events.hint.connect(_on_hint)
	Events.notify.connect(_on_notify)
	Events.location_changed.connect(_on_location)
	Events.screen_flash.connect(_on_flash)
	Events.poi_discovered.connect(_on_poi)
	Events.blackhole_warning.connect(_on_bh)
	Events.resource_collected.connect(_on_pickup)
	Events.scan_pulse.connect(func(_o: Vector3): _scan_t = 0.0)
	Events.game_started.connect(_on_game_started)
	Events.returned_to_menu.connect(_reset)
	Events.warp_finished.connect(func(_id: int): _last_anchor = -2)
	visibility_changed.connect(func(): if visible: _hud_a = 0.0)

func _reset() -> void:
	_toasts.clear()
	_picks.clear()
	_hint_age = 99.0
	_bh_level = 0
	_bh_a = 0.0
	_ctx_a = 0.0
	_last_anchor = -2
	_last_sys = -2
	_banner_t = 99.0
	_disp.clear()

func _on_game_started() -> void:
	_reset()
	_hud_a = 0.0

# =========================================================================================================================
# events
# =========================================================================================================================
func _on_hint(text: String, seconds: float) -> void:
	_hint_text = text
	_hint_age = 0.0
	_hint_life = maxf(seconds, 1.5)

func _on_notify(text: String, kind: String) -> void:
	for t in _toasts:
		if t["text"] == text and float(t["age"]) < 2.5:
			t["age"] = 0.35
			t["count"] = int(t.get("count", 1)) + 1
			return
	var f := UITheme.font()
	var sz := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, 292.0, 15)
	_toasts.append({"text": text, "kind": kind, "age": 0.0, "life": clampf(3.4 + 0.045 * float(text.length()), 3.6, 8.0), "h": maxf(sz.y, 18.0) + 20.0, "count": 1})
	while _toasts.size() > 6:
		_toasts.pop_front()

func _on_location(text: String) -> void:
	var parts := text.split("  -  ", false, 1)
	_loc_title = parts[0] if parts.size() > 0 else text
	_loc_sub = parts[1] if parts.size() > 1 else ""
	_loc_system = Universe.system.name if Universe.system != null else ""
	_banner_t = 0.0

func _on_flash(col: Color, dur: float) -> void:
	_flash_col = col
	_flash_dur = maxf(dur, 0.05)
	_flash_t = _flash_dur

func _on_poi(poi_name: String) -> void:
	_on_notify("Discovered: %s" % poi_name, "discover")

func _on_bh(level: int, dist: float) -> void:
	_bh_level = level
	_bh_dist = dist

func _on_pickup(id: String, amount: int) -> void:
	for p in _picks:
		if p["id"] == id and float(p["age"]) < 1.0:
			p["amt"] = int(p["amt"]) + amount
			p["age"] = 0.0
			return
	_picks.append({"id": id, "amt": amount, "age": 0.0})
	while _picks.size() > 5:
		_picks.pop_front()

# =========================================================================================================================
# input (T = cycle navigation target)
# =========================================================================================================================
func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev.is_action_pressed("nav_next") and Game.input_enabled():
		UINav.cycle()
		get_viewport().set_input_as_handled()

# =========================================================================================================================
# per-frame update
# =========================================================================================================================
func _process(dt: float) -> void:
	if not visible:
		return
	dt = minf(dt, 0.1)
	_t += dt
	var target_a := 1.0
	if Game.warping:
		target_a = 0.0
	_hud_a = move_toward(_hud_a, target_a, dt * (1.2 if target_a > 0.5 else 2.5))
	_poll += dt
	_env_age += dt
	if _poll >= 0.25:
		_poll = 0.0
		_poll_location()
	_banner_t += dt
	_hint_age += dt
	_scan_t += dt
	_flash_t = maxf(_flash_t - dt, 0.0)
	for t in _toasts:
		t["age"] = float(t["age"]) + dt
	_toasts = _toasts.filter(func(t: Dictionary) -> bool: return float(t["age"]) < float(t["life"]) + 0.5)
	for p in _picks:
		p["age"] = float(p["age"]) + dt
	_picks = _picks.filter(func(p: Dictionary) -> bool: return float(p["age"]) < 2.4)
	# context hint smoothing
	var ctx: String = Game.context_hint
	if ctx != "":
		_ctx_text = ctx
	_ctx_a = move_toward(_ctx_a, 1.0 if ctx != "" else 0.0, dt * 6.0)
	_bh_a = move_toward(_bh_a, 1.0 if _bh_level > 0 else 0.0, dt * 3.0)
	_fps_text = "%d FPS" % Engine.get_frames_per_second()
	queue_redraw()

func _poll_location() -> void:
	var sys := Universe.system
	if sys == null or Game.state == Game.State.MENU:
		return
	var a := Frame.anchor
	if a == _last_anchor and Universe.current_id == _last_sys:
		return
	var new_sys := Universe.current_id != _last_sys
	_last_anchor = a
	_last_sys = Universe.current_id
	var title: String
	var sub: String
	_loc_flag = ""
	if a >= 0:
		var b: BodyDef = sys.bodies[a]
		title = b.name.to_upper()
		sub = b.type_label()
		if Game.mark_discovered(a):
			_loc_flag = "NEWLY DISCOVERED"
			if Game.playing_time > 6.0:
				Events.notify.emit("Discovered %s  (%s)" % [b.name, b.type_label()], "discover")
				Audio.sfx("discover")
			else:
				_loc_flag = ""
	else:
		title = sys.name.to_upper()
		sub = "%s-class star  -  %d bodies" % [sys.star.spectral_class, sys.bodies.size()]
		if not new_sys:
			sub = "%s-class star  -  Interplanetary space" % sys.star.spectral_class
	Events.location_changed.emit("%s  -  %s" % [title, sub])

# =========================================================================================================================
# helpers
# =========================================================================================================================
func _tf(key: String, default: float = 0.0) -> float:
	var v: Variant = Game.tel.get(key, default)
	if v is float or v is int:
		return float(v)
	return default

func _tb(key: String) -> bool:
	return bool(Game.tel.get(key, false))

func _ts(key: String, default: String = "") -> String:
	return str(Game.tel.get(key, default))

func _sm(key: String, target: float, rate: float = 8.0) -> float:
	var cur: float = float(_disp.get(key, target))
	cur = lerpf(cur, target, 1.0 - exp(-rate * get_process_delta_time()))
	_disp[key] = cur
	return cur

func _pulse(hz: float) -> float:
	return 0.5 + 0.5 * sin(_t * TAU * hz)

func _txt(pos: Vector2, s: String, sz: int, col: Color, ax: float = 0.0, fnt: Font = null) -> float:
	return UITheme.text(self, pos, s, sz, col, ax, fnt)

func _cap(pos: Vector2, s: String, sz: int, col: Color, ax: float = 0.0) -> float:
	return UITheme.text(self, pos, s, sz, col, ax, UITheme.font_caps())

func _a(c: Color, k: float = 1.0) -> Color:
	return Color(c.r, c.g, c.b, c.a * k * _hud_a)

# =========================================================================================================================
# drawing
# =========================================================================================================================
func _draw() -> void:
	if not visible or Game.state == Game.State.MENU:
		return
	var cam: Camera3D = Game.active_camera()
	var cx := size.x * 0.5
	var foot: bool = Game.mode == Game.Mode.FOOT
	_draw_vignette()
	if cam != null:
		_ninfo = _nav_frame(cam)
		var fwd: Vector3 = -cam.global_transform.basis.z
		_heading = fposmod(rad_to_deg(atan2(fwd.dot(_ninfo[1]), fwd.dot(_ninfo[0]))), 360.0)
		_collect_markers(cam)
		_placed.clear()
		_draw_markers(cam)
		_draw_scan_markers(cam)
		if not foot and Game.mode == Game.Mode.SHIP:
			_draw_prograde(cam)
	_draw_crosshair(cam)
	_draw_compass(cx, 34.0)
	_draw_banner()
	_draw_flight(cx)
	_draw_bars()
	_draw_right_panel()
	_draw_pickups(cx)
	_draw_hints(cx)
	_draw_bh_warning(cx)
	_draw_toasts()
	if bool(Game.settings.get("show_fps", false)):
		_txt(Vector2(size.x - MARGIN, size.y - 8.0), _fps_text, 13, _a(UITheme.TEXT_DIM, 0.8), 1.0)
	if _flash_t > 0.0:
		var k := pow(_flash_t / _flash_dur, 1.5)
		draw_rect(Rect2(Vector2.ZERO, size), Color(_flash_col.r, _flash_col.g, _flash_col.b, _flash_col.a * k))

func _draw_vignette() -> void:
	var low := 0.0
	if Game.mode == Game.Mode.FOOT and Game.tel.has("health"):
		low = clampf((0.4 - _tf("health", 1.0)) / 0.4, 0.0, 1.0)
	if Game.mode == Game.Mode.SHIP:
		low = maxf(low, clampf((0.25 - _tf("hull", Game.ship_hull)) / 0.25, 0.0, 1.0) * 0.8)
	var k := low * (0.55 + 0.45 * _pulse(1.4))
	var kv := k * 0.9
	if _bh_level >= 2:
		kv = maxf(kv, 0.35 * _bh_a * (0.6 + 0.4 * _pulse(2.0 if _bh_level == 2 else 5.0)))
	if kv > 0.01:
		var col := Color(1.0, 0.1, 0.08, kv * _hud_a)
		draw_texture_rect(UITheme.vignette_tex(), Rect2(Vector2.ZERO, size), false, col)

# ---- navigation frame / compass -------------------------------------------------------------------------------------------
func _nav_frame(cam: Camera3D) -> Array:
	var pos := cam.global_position
	var u: Vector3
	var n: Vector3
	if Frame.anchor >= 0 and pos.length() > 50.0:
		u = pos.normalized()
		n = Vector3.UP - u * u.y
		if n.length() < 0.05:
			n = Vector3(0, 0, -1) - u * (-u.z)
		n = n.normalized()
	else:
		u = Frame.abs_dir_to_local(Vector3.UP)
		n = Frame.abs_dir_to_local(Vector3(0, 0, -1))
	var e := n.cross(u).normalized()
	return [n, e, u]

func _bearing_to(dir: Vector3) -> float:
	var n: Vector3 = _ninfo[0]
	var e: Vector3 = _ninfo[1]
	return rad_to_deg(atan2(dir.dot(e), dir.dot(n)))

func _draw_compass(cx: float, y: float) -> void:
	var w := 540.0
	var half := w * 0.5
	var span := 110.0
	var ppd := w / span
	var cam: Camera3D = Game.active_camera()
	# soft strip background
	draw_rect(Rect2(cx - half - 14.0, y, w + 28.0, 24.0), _a(Color(0.01, 0.03, 0.06, 0.62)))
	draw_line(Vector2(cx - half - 14.0, y), Vector2(cx + half + 14.0, y), _a(UITheme.LINE, 0.5), 1.0)
	draw_line(Vector2(cx - half - 14.0, y + 24.0), Vector2(cx + half + 14.0, y + 24.0), _a(UITheme.LINE, 0.8), 1.0)
	var base := int(round(_heading / 5.0)) * 5
	for k in range(-13, 14):
		var d := base + k * 5
		var dx := (float(d) - _heading) * ppd
		if absf(dx) > half:
			continue
		var fade := 1.0 - pow(absf(dx) / half, 3.0)
		var deg := posmod(d, 360)
		var x := cx + dx
		var col := UITheme.TEXT_DIM
		if deg % 45 == 0:
			draw_line(Vector2(x, y + 24.0), Vector2(x, y + 12.0), _a(UITheme.TEXT, fade), 2.0)
			var lbl := ""
			match deg:
				0: lbl = "N"
				45: lbl = "NE"
				90: lbl = "E"
				135: lbl = "SE"
				180: lbl = "S"
				225: lbl = "SW"
				270: lbl = "W"
				315: lbl = "NW"
			var cc := UITheme.ACCENT_HI if deg % 90 == 0 else UITheme.TEXT_DIM
			_cap(Vector2(x, y + 10.0), lbl, 15 if deg % 90 == 0 else 12, _a(cc, fade), 0.5)
		elif deg % 15 == 0:
			draw_line(Vector2(x, y + 24.0), Vector2(x, y + 15.0), _a(col, fade * 0.9), 1.5)
			if deg % 30 == 0:
				_txt(Vector2(x, y + 10.0), str(deg), 11, _a(col, fade * 0.8), 0.5)
		else:
			draw_line(Vector2(x, y + 24.0), Vector2(x, y + 19.0), _a(col, fade * 0.6), 1.0)
	# centre caret + numeric heading
	draw_colored_polygon(PackedVector2Array([Vector2(cx, y + 26.0), Vector2(cx - 6.0, y + 36.0), Vector2(cx + 6.0, y + 36.0)]), _a(UITheme.ACCENT))
	_txt(Vector2(cx, y + 54.0), "%03d" % int(round(_heading)) + "°", 17, _a(UITheme.TEXT), 0.5, UITheme.font_bold())
	# marker ticks on the strip
	for m in _markers:
		var dir: Vector3 = (m["p"] as Vector3) - cam.global_position
		if dir.length() < 1.0:
			continue
		var br := _bearing_to(dir.normalized())
		var diff := wrapf(br - _heading, -180.0, 180.0)
		if absf(diff) > span * 0.5 - 2.0:
			continue
		var mx := cx + diff * ppd
		var mc: Color = m["color"]
		if bool(m["nav"]):
			UITheme.draw_diamond(self, Vector2(mx, y - 6.0), 6.0, _a(UITheme.ACCENT_HI), true)
			UITheme.draw_diamond(self, Vector2(mx, y - 6.0), 10.0, _a(UITheme.ACCENT), false, 1.5)
		elif m["kind"] != "star":
			UITheme.draw_diamond(self, Vector2(mx, y - 5.0), 3.5, _a(mc, 0.9), true)
	# nav target line
	if Game.nav_target >= 0 and Universe.system != null and Game.nav_target < Universe.system.bodies.size():
		var nb: BodyDef = Universe.system.bodies[Game.nav_target]
		var dist := (Frame.to_local(Universe.body_pos(nb.index)) - cam.global_position).length()
		var label := "%s   %s" % [nb.name.to_upper(), UITheme.fmt_dist(maxf(dist - nb.radius, 0.0))]
		var tw := UITheme.text_width(label, 14, UITheme.font_caps())
		UITheme.draw_diamond(self, Vector2(cx - tw * 0.5 - 14.0, y + 75.0), 5.0, _a(UITheme.ACCENT), true)
		_cap(Vector2(cx - tw * 0.5, y + 80.0), label, 14, _a(UITheme.ACCENT_HI))

# ---- banner ---------------------------------------------------------------------------------------------------------------
func _draw_banner() -> void:
	if _loc_title == "":
		return
	var big_t := clampf(_banner_t / 0.7, 0.0, 1.0)
	var hold := 6.5
	var shrink := UITheme.ease_out((_banner_t - hold) / 1.2)
	var k := lerpf(1.0, 0.7, shrink)
	var alpha := UITheme.ease_out(big_t) * lerpf(1.0, 0.82, shrink)       # the settled banner stays readable (720p: nothing below ~11 px / faint)
	var p := Vector2(MARGIN + 4.0 - (1.0 - UITheme.ease_out(big_t)) * 30.0, MARGIN + 18.0)
	# soft dark scrim so the banner stays legible over bright skies / clouds
	draw_texture_rect(UITheme.glow_tex(), Rect2(p.x - 150.0, p.y - 70.0, 620.0, 250.0), false, _a(Color(0.0, 0.01, 0.03, 0.55), alpha))
	var head_txt := _loc_system.to_upper() + "  SYSTEM" if _last_anchor >= 0 else "STAR SYSTEM"
	_cap(p, head_txt, int(13.0 * lerpf(1.0, 0.95, shrink)), _a(UITheme.ACCENT, alpha))
	var title_sz := int(40.0 * k)
	var tw0 := UITheme.text_width(_loc_title, title_sz, UITheme.font_caps())
	if tw0 > 380.0:                                 # long names shrink to stay clear of the compass strip
		title_sz = maxi(int(float(title_sz) * 380.0 / tw0), 18)
	var w := _txt(p + Vector2(0, 14.0 + 30.0 * k), _loc_title, title_sz, _a(UITheme.TEXT, alpha), 0.0, UITheme.font_caps())
	var line_y := p.y + 14.0 + 30.0 * k + 10.0
	var lw := lerpf(0.0, maxf(w, 170.0), UITheme.ease_out(_banner_t / 1.0))
	draw_line(Vector2(p.x, line_y), Vector2(p.x + lw, line_y), _a(UITheme.ACCENT, alpha), 2.0)
	draw_line(Vector2(p.x + lw, line_y), Vector2(p.x + lw + 10.0, line_y), _a(UITheme.ACCENT, alpha * 0.4), 2.0)
	_txt(Vector2(p.x, line_y + 22.0 * lerpf(1.0, 0.9, shrink)), _loc_sub, maxi(int(17.0 * k + 1.0), 14), _a(UITheme.TEXT_DIM.lerp(UITheme.TEXT, 0.3), alpha))
	if _loc_flag != "" and shrink < 0.99:
		var fa := alpha * (0.7 + 0.3 * _pulse(1.5)) * (1.0 - shrink)
		UITheme.draw_diamond(self, Vector2(p.x + 6.0, line_y + 48.0), 5.0, _a(UITheme.GOLD, fa), true)
		_cap(Vector2(p.x + 20.0, line_y + 53.0), _loc_flag, 14, _a(UITheme.GOLD, fa))

# ---- markers --------------------------------------------------------------------------------------------------------------
func _collect_markers(cam: Camera3D) -> void:
	_markers.clear()
	var sys := Universe.system
	if sys == null:
		return
	var cpos := cam.global_position
	for b in sys.bodies:
		var bd: BodyDef = b
		if bd.index == Frame.anchor:
			continue
		var lp := Frame.to_local(Universe.body_pos(bd.index))
		_markers.append({"p": lp, "name": bd.name, "color": UITheme.body_color(bd), "dist": maxf((lp - cpos).length() - bd.radius, 0.0),
			"radius": bd.radius, "nav": Game.nav_target == bd.index, "kind": "bh" if bd.is_black_hole() else "body", "idx": bd.index})
	var sp := Frame.star_local
	_markers.append({"p": sp, "name": sys.name, "color": sys.star.color, "dist": maxf((sp - cpos).length() - sys.star.radius, 0.0),
		"radius": sys.star.radius, "nav": false, "kind": "star", "idx": -1})
	if Game.mode == Game.Mode.FOOT and Game.ship != null and is_instance_valid(Game.ship):
		var shp := Game.ship.global_position
		var sd := (shp - cpos).length()
		if sd > 10.0:
			_markers.append({"p": shp + Vector3.ZERO, "name": "Ship", "color": UITheme.GOOD, "dist": sd, "radius": 5.0, "nav": false, "kind": "ship", "idx": -2})

func _draw_markers(cam: Camera3D) -> void:
	var px_per_rad := (size.y * 0.5) / tan(deg_to_rad(maxf(cam.fov, 10.0)) * 0.5)
	var safe := Rect2(Vector2(30, 90), size - Vector2(60, 190))
	var vis: Array = []
	for m in _markers:
		var p: Vector3 = m["p"]
		var behind := cam.is_position_behind(p)
		var sp := cam.unproject_position(p)
		var on := (not behind) and safe.has_point(sp)
		if not on:
			if bool(m["nav"]):
				_draw_edge_arrow(cam, p, m["color"], m["name"], m["dist"])
			continue
		vis.append({"m": m, "sp": sp})
	# priority: nav target first, then nearest first (their labels win the free space)
	vis.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var nx: bool = x["m"]["nav"]
		var ny: bool = y["m"]["nav"]
		if nx != ny:
			return nx
		return float(x["m"]["dist"]) < float(y["m"]["dist"]))
	for v in vis:
		var m: Dictionary = v["m"]
		var sp: Vector2 = v["sp"]
		var col: Color = m["color"]
		var nav: bool = m["nav"]
		var kind: String = m["kind"]
		var dist: float = m["dist"]
		var apparent: float = (float(m["radius"]) / maxf(dist + float(m["radius"]), 1.0)) * px_per_rad
		var fade := 1.0
		if kind == "ship":
			fade = clampf((dist - 10.0) / 30.0, 0.0, 1.0)
		var r := 8.0
		if kind != "star" and apparent > 7.0 and apparent < 260.0:
			r = apparent + 8.0
		var ringc := _a(col, 0.85 * fade)
		match kind:
			"star":
				draw_arc(sp, 12.0, 0, TAU, 28, _a(col, 0.55), 1.5, true)
				draw_line(sp + Vector2(-20, 0), sp + Vector2(-14, 0), _a(col, 0.7), 1.5)
				draw_line(sp + Vector2(20, 0), sp + Vector2(14, 0), _a(col, 0.7), 1.5)
				r = 14.0
			"bh":
				draw_arc(sp, 11.0, 0, TAU, 28, _a(UITheme.VIOLET, 0.9), 2.0, true)
				draw_arc(sp, 17.0 + 3.0 * _pulse(0.7), 0, TAU, 32, _a(UITheme.VIOLET, 0.4), 1.0, true)
				draw_circle(sp, 4.0, _a(Color(0, 0, 0, 1), 0.9))
				r = 17.0
			"ship":
				UITheme.draw_diamond(self, sp, 8.0, ringc, false, 2.0)
				UITheme.draw_diamond(self, sp, 3.0, ringc, true)
			_:
				if r > 12.0:
					for q in 4:
						var a0 := float(q) * PI * 0.5 + 0.35
						draw_arc(sp, r, a0, a0 + 0.9, 10, _a(col, 0.5 * fade), 1.5, true)
				else:
					draw_arc(sp, r, 0, TAU, 24, ringc, 1.5, true)
					draw_circle(sp, 2.2, ringc)
		if nav:
			UITheme.draw_brackets(self, Rect2(sp - Vector2(r + 8.0, r + 8.0), Vector2((r + 8.0) * 2.0, (r + 8.0) * 2.0)), 8.0, _a(UITheme.ACCENT_HI), 2.0)
			r += 8.0
		# label with simple de-cluttering against labels already placed this frame
		var nm: String = str(m["name"]).to_upper()
		var sub := UITheme.fmt_dist(dist)
		if nav:
			sub = "NAV  •  " + sub
		var w := maxf(UITheme.text_width(nm, 14, UITheme.font_caps()), UITheme.text_width(sub, 13)) + 6.0
		var side := 1.0
		var lx := sp.x + r + 8.0
		if lx + w > size.x - 24.0:
			side = -1.0
			lx = sp.x - r - 8.0 - w
		var ly := sp.y - 16.0
		var oy := _free_label_y(lx, ly, w, 32.0)
		if is_nan(oy):
			if not nav:
				continue
		else:
			ly = oy
		var ax := 0.0 if side > 0.0 else 0.0
		var tcol := UITheme.TEXT if nav else col.lerp(Color.WHITE, 0.45)
		draw_rect(Rect2(lx - 5.0, ly - 1.0, w + 6.0, 33.0), _a(Color(0.0, 0.015, 0.04, 0.42), fade))     # backing: readable over the sun glare
		_cap(Vector2(lx, ly + 13.0), nm, 14, _a(tcol, fade), ax)
		_txt(Vector2(lx, ly + 29.0), sub, 13, _a(UITheme.TEXT_DIM, fade), ax)

func _draw_edge_arrow(cam: Camera3D, p: Vector3, col: Color, nm: String, dist: float) -> void:
	var rel := cam.global_transform.affine_inverse() * p
	var d2 := Vector2(rel.x, -rel.y)
	if d2.length() < 0.001:
		d2 = Vector2(0, 1)
	d2 = d2.normalized()
	var c := size * 0.5
	var ext := Vector2(size.x * 0.5 - 70.0, size.y * 0.5 - 140.0)
	var k := minf(ext.x / maxf(absf(d2.x), 0.0001), ext.y / maxf(absf(d2.y), 0.0001))
	var pos := c + d2 * k
	var pulse := 0.7 + 0.3 * _pulse(1.5)
	draw_arc(pos - d2 * 5.0, 24.0, 0, TAU, 32, _a(UITheme.ACCENT, 0.30 * pulse), 1.5, true)
	draw_circle(pos - d2 * 5.0, 22.0, _a(Color(0.0, 0.02, 0.05, 0.45)))
	UITheme.draw_triangle(self, pos, d2, 16.0, _a(UITheme.ACCENT_HI, pulse))
	var nm_u := nm.to_upper()
	var dist_s := UITheme.fmt_dist(dist)
	var lw := maxf(UITheme.text_width(nm_u, 14, UITheme.font_caps()), UITheme.text_width(dist_s, 13)) + 14.0
	var tx := clampf(pos.x, 18.0 + lw * 0.5, size.x - 18.0 - lw * 0.5)
	var ty := pos.y + (40.0 if d2.y < 0.5 else -38.0)
	draw_rect(Rect2(tx - lw * 0.5, ty - 15.0, lw, 36.0), _a(Color(0.0, 0.015, 0.04, 0.55)))
	draw_rect(Rect2(tx - lw * 0.5, ty - 15.0, lw, 1.5), _a(UITheme.ACCENT, 0.7))
	_cap(Vector2(tx, ty), nm_u, 14, _a(UITheme.ACCENT_HI), 0.5)
	_txt(Vector2(tx, ty + 16.0), dist_s, 13, _a(UITheme.TEXT_DIM), 0.5)

## find a free y for a label box (w x h) starting at (lx, ly): tries the preferred spot, then steps up / down. Registers the box in _placed.
## Returns NAN when every candidate collides.
func _free_label_y(lx: float, ly: float, w: float, h: float) -> float:
	for attempt in 7:
		var off := 0.0
		match attempt:
			1: off = h
			2: off = -h
			3: off = h * 2.0
			4: off = -h * 2.0
			5: off = h * 3.0
			6: off = -h * 3.0
		var rect := Rect2(lx - 5.0, ly + off - 1.0, w + 8.0, h + 1.0)
		var clash := false
		for pr in _placed:
			if (pr as Rect2).intersects(rect):
				clash = true
				break
		if not clash:
			_placed.append(rect)
			return ly + off
	return NAN

func _draw_scan_markers(cam: Camera3D) -> void:
	if Game.player == null or not is_instance_valid(Game.player):
		return
	var sm: Variant = Game.player.get("scan_markers")
	if not (sm is Array):
		return
	var vis: Array = []
	var cpos := cam.global_position
	for m in (sm as Array):
		if not (m is Dictionary):
			continue
		var d: Dictionary = m
		var p: Vector3 = d.get("pos", Vector3.ZERO)
		if cam.is_position_behind(p):
			continue
		var sp := cam.unproject_position(p)
		if not Rect2(Vector2(20, 90), size - Vector2(40, 190)).has_point(sp):
			continue
		vis.append({"d": d, "sp": sp, "dist": (p - cpos).length()})
	vis.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dist"]) < float(b["dist"]))
	var shown := 0
	for v in vis:
		var d2: Dictionary = v["d"]
		var sp2: Vector2 = v["sp"]
		var dist: float = v["dist"]
		var kind: String = str(d2.get("kind", "poi"))
		var col := UITheme.GOLD
		match kind:
			"resource": col = UITheme.ACCENT
			"creature", "fauna": col = UITheme.WARN
			"ship": col = UITheme.GOOD
			"structure", "poi": col = UITheme.GOLD
		var fade := clampf((dist - 6.0) / 20.0, 0.0, 1.0)
		var lbl: String = str(d2.get("label", "")).to_upper()
		var sub := UITheme.fmt_dist(dist)
		var w := maxf(UITheme.text_width(lbl, 13, UITheme.font_caps()), UITheme.text_width(sub, 12)) + 6.0
		var lx := sp2.x + 15.0
		if lx + w > size.x - 24.0:
			lx = sp2.x - 15.0 - w
		var oy := _free_label_y(lx, sp2.y - 10.0, w, 30.0)
		UITheme.draw_diamond(self, sp2, 7.0, _a(col, 0.95 * fade), false, 2.0)
		UITheme.draw_diamond(self, sp2, 2.5, _a(col, fade), true)
		if is_nan(oy):
			continue                       # too crowded: keep just the diamond
		shown += 1
		var ly := oy
		if absf(ly - (sp2.y - 10.0)) > 1.0:    # label was pushed away: thin leader line back to its marker
			draw_line(sp2 + Vector2(8.0 if lx > sp2.x else -8.0, 0.0), Vector2(lx - 3.0 if lx > sp2.x else lx + w + 3.0, ly + 10.0), _a(col, 0.45 * fade), 1.0)
		draw_rect(Rect2(lx - 5.0, ly - 1.0, w + 8.0, 31.0), _a(Color(0.0, 0.015, 0.04, 0.5), fade))
		draw_rect(Rect2(lx - 5.0, ly - 1.0, 2.0, 31.0), _a(col, 0.8 * fade))
		_cap(Vector2(lx, ly + 12.0), lbl, 13, _a(col.lerp(Color.WHITE, 0.45), fade))
		_txt(Vector2(lx, ly + 26.0), sub, 12, _a(UITheme.TEXT_DIM, fade))

func _draw_prograde(cam: Camera3D) -> void:
	if Game.ship == null or not is_instance_valid(Game.ship):
		return
	var v: Vector3 = Game.ship.get("velocity")
	if v.length() < 12.0:
		return
	var p := cam.global_position + v.normalized() * 2000.0
	if cam.is_position_behind(p):
		return
	var sp := cam.unproject_position(p)
	var col := _a(UITheme.GOOD, 0.9)
	draw_arc(sp, 9.0, 0, TAU, 24, col, 1.8, true)
	draw_line(sp + Vector2(-17, 0), sp + Vector2(-9, 0), col, 1.8)
	draw_line(sp + Vector2(17, 0), sp + Vector2(9, 0), col, 1.8)
	draw_line(sp + Vector2(0, -17), sp + Vector2(0, -9), col, 1.8)

# ---- crosshair ------------------------------------------------------------------------------------------------------------
func _draw_crosshair(cam: Camera3D) -> void:
	var c := size * 0.5
	var foot: bool = Game.mode == Game.Mode.FOOT
	if foot:
		var firing := Input.is_action_pressed("fire") and Game.input_enabled()
		var gap := 9.0 if not firing else 5.0
		var col := _a(UITheme.ACCENT_HI if firing else UITheme.TEXT, 0.9)
		draw_circle(c, 1.8, col)
		for q in 4:
			var d := Vector2.from_angle(float(q) * PI * 0.5 + PI * 0.25)
			draw_line(c + d * gap, c + d * (gap + 6.0), col, 1.6)
	else:
		var col2 := _a(UITheme.TEXT, 0.75)
		draw_arc(c, 13.0, 0, TAU, 32, col2, 1.4, true)
		draw_circle(c, 1.6, _a(UITheme.ACCENT_HI, 0.95))
		for q in 4:
			var d2 := Vector2.from_angle(float(q) * PI * 0.5)
			draw_line(c + d2 * 17.0, c + d2 * 24.0, col2, 1.4)
	# mining progress ring
	var mp := _tf("mine_progress", 0.0)
	if foot and mp > 0.01:
		draw_arc(c, 21.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(mp, 0.0, 1.0), 48, _a(UITheme.ACCENT_HI), 3.0, true)
		draw_arc(c, 21.0, 0, TAU, 48, _a(Color(1, 1, 1, 0.12)), 1.0, true)
	# scanner sweep
	if _scan_t < 1.4:
		var k := _scan_t / 1.4
		draw_arc(c, 30.0 + k * 360.0, 0, TAU, 96, _a(UITheme.ACCENT, (1.0 - k) * 0.6), 2.5, true)

# ---- flight readouts (bottom centre) --------------------------------------------------------------------------------------
func _state_color(s: String) -> Color:
	var u := s.to_upper()
	if "ENTRY" in u or "HEAT" in u or "DANGER" in u or "CRASH" in u:
		return UITheme.WARN
	if "PULSE" in u or "JETPACK" in u:
		return UITheme.ACCENT_HI
	if "LANDED" in u:
		return UITheme.GOOD
	if "FOOT" in u:
		return UITheme.TEXT
	if "SPRINT" in u or "AIRBORNE" in u:
		return UITheme.TEXT
	return UITheme.ACCENT

func _draw_flight(cx: float) -> void:
	var foot: bool = Game.mode == Game.Mode.FOOT
	var base_y := size.y - MARGIN
	var speed := _sm("speed", _tf("speed"), 9.0)
	var alt := _tf("altitude", -1.0)
	var st := _ts("state", "ON FOOT" if foot else "SPACE")
	if st == "":
		st = "ON FOOT" if foot else "SPACE"
	if foot:
		var fs := _ts("foot_state", "")
		if fs != "" and fs != "IDLE" and fs != "WALKING":
			st = fs
	# soft dark plate behind the cluster so the small labels stay readable over snow, sand and bright pads
	var plate_top := _cluster_top() - 12.0
	draw_texture_rect(UITheme.scrim_tex(), Rect2(cx - 372.0, plate_top, 744.0, base_y + 12.0 - plate_top), false, _a(Color(0.0, 0.012, 0.03, 0.62)))
	# state chip
	var sc := _state_color(st)
	var chip_w := UITheme.text_width(st.to_upper(), 14, UITheme.font_caps()) + 36.0
	var chip := Rect2(cx - chip_w * 0.5, base_y - 150.0 + (34.0 if foot else 0.0), chip_w, 26.0)
	var flash := 1.0
	if "ENTRY" in st.to_upper():
		flash = 0.65 + 0.35 * _pulse(3.0)
	UITheme.draw_chamfer(self, chip, 6.0, _a(Color(sc.r * 0.14, sc.g * 0.14, sc.b * 0.14, 0.7)), _a(sc, 0.8 * flash), 1.0)
	_cap(Vector2(cx, chip.position.y + 18.0), st.to_upper(), 14, _a(sc, flash), 0.5)
	# speed (number + unit centred as a group)
	var sp: Array = UITheme.fmt_speed(speed)
	var num_s: String = str(sp[0])
	var unit_s: String = str(sp[1])
	var nw := UITheme.text_width(num_s, 54, UITheme.font_bold())
	var uw := UITheme.text_width(unit_s, 15, UITheme.font_caps())
	var gap_x := 16.0
	var sx := cx - (nw + gap_x + maxf(uw, 44.0)) * 0.5
	var sy := base_y - 70.0 + (34.0 if foot else 0.0)
	_txt(Vector2(sx, sy), num_s, 54, _a(UITheme.TEXT), 0.0, UITheme.font_bold())
	_cap(Vector2(sx + nw + gap_x, sy), unit_s, 15, _a(UITheme.TEXT_DIM), 0.0)
	_cap(Vector2(sx + nw + gap_x, sy - 21.0), "SPEED", 11, _a(UITheme.TEXT_DIM), 0.0)
	# altitude (left) / vertical speed (right)
	var lx := cx - 190.0
	_cap(Vector2(lx, sy - 30.0), "ALTITUDE", 12, _a(UITheme.TEXT_DIM), 1.0)
	var alt_s := "---" if alt < 0.0 else UITheme.fmt_dist(alt)
	_txt(Vector2(lx, sy), alt_s, 28, _a(UITheme.TEXT), 1.0, UITheme.font_bold())
	var rx := cx + 190.0
	if Game.tel.has("vspeed") and alt >= 0.0:
		var vs := _tf("vspeed", 0.0)
		_cap(Vector2(rx, sy - 30.0), "VERTICAL", 12, _a(UITheme.TEXT_DIM), 0.0)
		var vcol := UITheme.TEXT
		if vs < -25.0:
			vcol = UITheme.WARN
		_txt(Vector2(rx, sy), "%+.0f m/s" % vs, 28, _a(vcol), 0.0, UITheme.font_bold())
	if foot:
		# on-foot indicator chips: flashlight, scanner (charging bar while cooling down), jetpack, sprint
		var scan_cd := clampf(_tf("scan_cooldown", 0.0), 0.0, 1.0)
		var jet_on := _ts("foot_state") == "JETPACK"
		var chips_f := [["LIGHT", _tb("flashlight"), UITheme.WARN, -1.0], ["SCAN", scan_cd <= 0.02, UITheme.ACCENT, scan_cd],
			["JET", jet_on, UITheme.ACCENT_HI, -1.0], ["SPRINT", _ts("foot_state") == "SPRINTING", UITheme.GOOD, -1.0]]
		var cwid := 66.0
		var cx0 := cx - (cwid * 4.0 + 6.0 * 3.0) * 0.5
		for ch in chips_f:
			var on_f: bool = ch[1]
			var cc_f: Color = ch[2]
			var rf := Rect2(cx0, base_y - 24.0, cwid, 20.0)
			UITheme.draw_chamfer(self, rf, 5.0, _a(UITheme.ca(cc_f, 0.22) if on_f else Color(0.0, 0.02, 0.05, 0.5)), _a(cc_f if on_f else UITheme.TEXT_FAINT, 0.9 if on_f else 0.55), 1.0)
			var cool: float = ch[3]
			if cool > 0.02:
				draw_rect(Rect2(rf.position.x + 2.0, rf.end.y - 4.0, (cwid - 4.0) * (1.0 - cool), 2.0), _a(cc_f, 0.8))
			_cap(rf.get_center() + Vector2(0, 4.0), str(ch[0]), 11, _a(cc_f if on_f else UITheme.TEXT_DIM, 1.0 if on_f else 0.8), 0.5)
			cx0 += cwid + 6.0
	else:
		# indicator chips + throttle bar
		var chips := [["GEAR", _tb("gear"), UITheme.GOOD], ["BOOST", _tb("boost"), UITheme.WARN], ["PULSE", _tb("pulse"), UITheme.ACCENT_HI]]
		var chip_x := cx - 123.0
		for ch in chips:
			var on: bool = ch[1]
			var cc: Color = ch[2]
			var r := Rect2(chip_x, base_y - 44.0, 78.0, 20.0)
			UITheme.draw_chamfer(self, r, 5.0, _a(UITheme.ca(cc, 0.22) if on else Color(0.0, 0.02, 0.05, 0.5)), _a(cc if on else UITheme.TEXT_FAINT, 0.9 if on else 0.55), 1.0)
			_cap(r.get_center() + Vector2(0, 5.0), str(ch[0]), 11, _a(cc if on else UITheme.TEXT_DIM, 1.0 if on else 0.8), 0.5)
			chip_x += 84.0
		var th := _sm("throttle", _tf("throttle", 0.0), 10.0)
		var bar := Rect2(cx - 100.0, base_y - 12.0, 200.0, 5.0)
		UITheme.draw_bar(self, bar, th, _a(UITheme.ACCENT), 25, _a(Color(1, 1, 1, 0.1)))
		_cap(Vector2(bar.position.x - 10.0, base_y - 4.0), "THR", 11, _a(UITheme.TEXT_FAINT), 1.0)
		_txt(Vector2(bar.end.x + 10.0, base_y - 4.0), "%d%%" % int(round(th * 100.0)), 12, _a(UITheme.TEXT_DIM), 0.0)

# ---- bars (bottom left) ---------------------------------------------------------------------------------------------------
func _bar_row(x: float, y: float, w: float, label: String, key: String, fallback: float, col: Color, inverse: bool = false) -> void:
	var v := _sm("bar_" + key, clampf(_tf(key, fallback), 0.0, 1.0), 7.0)
	var raw := _tf(key, fallback)
	var c := col
	var crit := (raw > 0.75) if inverse else (raw < 0.25)
	if crit:
		c = UITheme.DANGER.lerp(col, 0.35 * _pulse(2.5))
	_cap(Vector2(x, y), label, 12, _a(UITheme.TEXT_DIM if not crit else UITheme.DANGER), 0.0)
	_txt(Vector2(x + w, y), "%d%%" % int(round(raw * 100.0)), 12, _a(UITheme.TEXT if not crit else UITheme.DANGER), 1.0)
	UITheme.draw_bar(self, Rect2(x, y + 6.0, w, 7.0), v, _a(c), 30, _a(Color(1, 1, 1, 0.09)))

func _draw_bars() -> void:
	var foot: bool = Game.mode == Game.Mode.FOOT
	var rows: Array = []
	if foot:
		rows.append(["HEALTH", "health", 1.0, UITheme.GOOD])
		rows.append(["PROTECTION", "protection", 1.0, UITheme.WARN])
		rows.append(["JETPACK", "jetpack", 1.0, UITheme.ACCENT])
		if Game.tel.has("stamina"):
			rows.append(["STAMINA", "stamina", 1.0, UITheme.ACCENT_DIM])
	else:
		rows.append(["HULL", "hull", Game.ship_hull, UITheme.GOOD])
		rows.append(["PULSE FUEL", "fuel", Game.ship_fuel, UITheme.ACCENT])
		if Game.tel.has("shield"):
			rows.append(["SHIELD", "shield", 1.0, Color(0.5, 0.65, 1.0)])
		if _tf("heat", 0.0) > 0.02:
			rows.append(["ENTRY HEAT", "heat", 0.0, UITheme.WARN, true])
		if _tf("pressure", 0.0) > 0.02:
			rows.append(["PRESSURE", "pressure", 0.0, Color(1.0, 0.5, 0.3), true])
	var w := 262.0
	var h := 26.0 + float(rows.size()) * 34.0
	var x0 := MARGIN
	var y0 := size.y - MARGIN - h
	UITheme.draw_chamfer(self, Rect2(x0, y0, w + 28.0, h), 10.0, _a(UITheme.PANEL), _a(UITheme.LINE, 0.7), 1.0)
	draw_line(Vector2(x0 + 10.0, y0 + 0.5), Vector2(x0 + 44.0, y0 + 0.5), _a(UITheme.ACCENT), 2.0)
	var y := y0 + 30.0
	for r in rows:
		var key: String = r[1]
		var fb: float = r[2]
		_bar_row(x0 + 14.0, y, w, str(r[0]), key, fb, r[3], r.size() > 4 and bool(r[4]))
		y += 34.0

# ---- right panel: environment + resources ---------------------------------------------------------------------------------
## ambient environment readouts for the SHIP (the ship does not publish them; the on-foot player does through Game.tel).
## Cached ~5x per second. Returns {gravity (m/s^2), air (0..1), temp (deg C or NAN), hazard (String), level (0..1), body (String)}
func _ship_env() -> Dictionary:
	if _env_age < 0.2 and not _env.is_empty():
		return _env
	_env_age = 0.0
	var out := {"gravity": 0.0, "air": 0.0, "temp": NAN, "hazard": "", "level": 0.0, "body": ""}
	var def: BodyDef = Frame.anchor_def()
	var who: Node3D = Game.ship
	if def != null and who != null and is_instance_valid(who):
		var pl: Node = Frame.anchor_node()
		var p := who.global_position
		out["body"] = def.name
		if pl != null and pl.has_method("gravity_at"):
			var g: Variant = pl.call("gravity_at", p)
			out["gravity"] = (g as Vector3).length() if g is Vector3 else float(g)
		else:
			out["gravity"] = def.gravity * pow(def.radius / maxf(p.length(), def.radius), 2.0)     # inverse-square from the surface value
		if pl != null and pl.has_method("atmosphere_density_at"):
			out["air"] = clampf(float(pl.call("atmosphere_density_at", p)), 0.0, 1.0)
		elif def.has_atmosphere:
			out["air"] = 0.5
		# ambient temperature: night side <-> day side blended by the sun elevation at the ship's position (same rule as the exosuit)
		var sun_sin := p.normalized().dot(Frame.sun_dir) if p.length() > 1.0 else 0.0
		var t := lerpf(def.temp_night_c, def.temp_day_c, smoothstep(-0.10, 0.28, sun_sin))
		out["temp"] = t
		if float(out["air"]) < 0.02 and not def.has_atmosphere:
			out["temp"] = t                      # airless: still report the surface temperature
		var heat := clampf((t - 42.0) / 45.0, 0.0, 1.0)
		var cold := clampf((-8.0 - t) / 65.0, 0.0, 1.0)
		var tox: float = def.toxicity if def.has_atmosphere else 0.0
		var best := 0.0
		var label := ""
		if heat > best:
			best = heat
			label = "Extreme heat"
		if cold > best:
			best = cold
			label = "Extreme cold"
		if tox > best:
			best = tox
			label = "Toxic atmosphere"
		if def.radiation > best:
			best = def.radiation
			label = "Radiation"
		if best >= 0.04:
			out["hazard"] = label
			out["level"] = best
	_env = out
	return out

func _draw_right_panel() -> void:
	var lines: Array = []    # [label, value, color]
	var foot: bool = Game.mode == Game.Mode.FOOT
	var hz := ""
	var hl := 0.0
	if foot:
		if Game.tel.has("gravity") and (_tf("gravity", 0.0) > 0.05):
			lines.append(["GRAVITY", "%.2f g" % (_tf("gravity") / 9.81), UITheme.TEXT])
		if Game.tel.has("temp_c"):
			var tc := _tf("temp_c")
			lines.append(["TEMPERATURE", "%d °C" % int(round(tc)), _temp_color(tc)])
		hz = _ts("hazard", "")
		hl = _tf("hazard_level", 0.0)
	else:
		var env := _ship_env()
		var g: float = env["gravity"]
		lines.append(["GRAVITY", "%.2f g" % (g / 9.81) if g > 0.05 else "ZERO-G", UITheme.TEXT if g > 0.05 else UITheme.TEXT_DIM])
		var air: float = env["air"]
		if str(env["body"]) != "":
			var air_s := "VACUUM" if air < 0.02 else ("THIN" if air < 0.25 else ("DENSE" if air > 0.7 else "NORMAL"))
			lines.append(["ATMOSPHERE", air_s, UITheme.TEXT if air >= 0.02 else UITheme.TEXT_DIM])
			var tc2: float = env["temp"]
			if not is_nan(tc2):
				lines.append(["EXT. TEMP", "%d °C" % int(round(tc2)), _temp_color(tc2)])
		hz = str(env["hazard"])
		hl = float(env["level"])
	if hz != "" and hz.to_lower() != "none":
		var hc := UITheme.WARN if hl < 0.6 else UITheme.DANGER
		lines.append(["HAZARD", hz.to_upper(), hc])
	var w := 250.0
	var rows := lines.size()
	var res_h := 62.0
	var h := 14.0 + res_h + (10.0 + float(rows) * 24.0 if rows > 0 else 0.0) + (14.0 if hl > 0.01 and hz != "" else 0.0)
	var x0 := size.x - MARGIN - w
	var y0 := size.y - MARGIN - h
	UITheme.draw_chamfer(self, Rect2(x0, y0, w, h), 10.0, _a(UITheme.PANEL), _a(UITheme.LINE, 0.7), 1.0)
	draw_line(Vector2(x0 + w - 44.0, y0 + h - 0.5), Vector2(x0 + w - 10.0, y0 + h - 0.5), _a(UITheme.ACCENT), 2.0)
	# resources row
	var rx := x0 + 16.0
	var ry := y0 + 16.0
	for id in ["ferrite", "zyrite", "sodium", "voidstone"]:
		var rc := UITheme.resource_color(id)
		var cnt: int = int(Game.inventory.get(id, 0))
		draw_rect(Rect2(rx, ry + 1.0, 8.0, 8.0), _a(rc, 0.95 if cnt > 0 else 0.4))
		_cap(Vector2(rx + 13.0, ry + 9.0), str(id).substr(0, 3).to_upper(), 10, _a(UITheme.TEXT_FAINT if cnt == 0 else UITheme.TEXT_DIM))
		_txt(Vector2(rx, ry + 29.0), str(cnt), 17, _a(UITheme.TEXT if cnt > 0 else UITheme.TEXT_FAINT), 0.0, UITheme.font_bold())
		rx += 54.0
	# warp cells
	var wc := Game.warp_cells
	UITheme.draw_diamond(self, Vector2(x0 + 24.0, ry + 47.0), 6.0, _a(UITheme.VIOLET), true)
	_cap(Vector2(x0 + 38.0, ry + 52.0), "WARP CELLS", 11, _a(UITheme.TEXT_DIM))
	_txt(Vector2(x0 + w - 16.0, ry + 52.0), str(wc), 17, _a(UITheme.TEXT), 1.0, UITheme.font_bold())
	var y := y0 + 14.0 + res_h + 12.0
	if rows > 0:
		draw_line(Vector2(x0 + 14.0, y - 14.0), Vector2(x0 + w - 14.0, y - 14.0), _a(UITheme.LINE, 0.6), 1.0)
	for l in lines:
		_cap(Vector2(x0 + 16.0, y + 5.0), str(l[0]), 11, _a(UITheme.TEXT_FAINT))
		_txt(Vector2(x0 + w - 16.0, y + 5.0), str(l[1]), 16, _a(l[2]), 1.0, UITheme.font_bold())
		y += 24.0
	if hl > 0.01 and hz != "" and rows > 0:
		var hcol := UITheme.WARN if hl < 0.6 else UITheme.DANGER
		UITheme.draw_bar(self, Rect2(x0 + 16.0, y - 8.0, w - 32.0, 5.0), hl, _a(hcol), 24)

# ---- pickups / hints / toasts ---------------------------------------------------------------------------------------------
func _draw_pickups(cx: float) -> void:
	var cy := size.y * 0.5
	var i := 0
	for p in _picks:
		var age: float = p["age"]
		var k := age / 2.4
		var a := (1.0 - pow(k, 2.0)) * minf(age / 0.12, 1.0)
		var info: Dictionary = ResourceDB.info(str(p["id"]))
		var col: Color = info.get("color", UITheme.ACCENT)
		var nm: String = str(info.get("name", p["id"]))
		var pos := Vector2(cx + 46.0, cy + 54.0 + float(i) * 22.0 - k * 14.0)
		draw_rect(Rect2(pos.x - 16.0, pos.y - 10.0, 8.0, 8.0), _a(col, a))
		_cap(pos, "+%d  %s" % [int(p["amt"]), nm.to_upper()], 15, _a(UITheme.TEXT, a))
		i += 1

func _temp_color(tc: float) -> Color:
	var col := UITheme.TEXT
	if tc > 45.0 or tc < -25.0:
		col = UITheme.WARN
	if tc > 85.0 or tc < -60.0:
		col = UITheme.DANGER
	return col

## y where the bottom-centre flight cluster (state chip / speed / altitude / chips) starts; hints and prompts stack ABOVE it, never over it
func _cluster_top() -> float:
	var foot: bool = Game.mode == Game.Mode.FOOT
	return size.y - MARGIN - 150.0 + (34.0 if foot else 0.0)

func _draw_hints(cx: float) -> void:
	var top := _cluster_top() - 16.0               # lowest free y of the hint stack
	var prompt_h := 40.0
	var lift := 0.0
	# context prompt ("[F] Exit ship"): directly above the flight cluster
	if _ctx_a > 0.01:
		var pk := UITheme.ease_out(_ctx_a)
		_draw_prompt(cx, top - prompt_h + 24.0 + (1.0 - pk) * 8.0, _ctx_text, _ctx_a)
		lift = (prompt_h + 10.0) * pk
	# transient hint: wraps within a fixed width, bottom-anchored above the prompt (grows upwards, so it can never run into the cluster)
	if _hint_age < _hint_life + 0.6:
		var a := minf(_hint_age / 0.3, 1.0) * clampf((_hint_life + 0.6 - _hint_age) / 0.6, 0.0, 1.0)
		var f := UITheme.font()
		var wmax := minf(size.x - 640.0, 760.0)    # keep clear of the bottom-left / bottom-right panels
		var msz := f.get_multiline_string_size(_hint_text, HORIZONTAL_ALIGNMENT_CENTER, wmax - 44.0, 17)
		var hh := msz.y + 22.0
		var slide := (1.0 - UITheme.ease_out(_hint_age / 0.3)) * 8.0
		var r := Rect2(cx - msz.x * 0.5 - 22.0, top - lift - hh + slide, msz.x + 44.0, hh)
		UITheme.draw_chamfer(self, r, 8.0, _a(UITheme.PANEL_DARK, a), _a(UITheme.ACCENT, 0.6 * a), 1.0)
		draw_multiline_string(f, Vector2(r.position.x + 22.0, r.position.y + 25.0), _hint_text, HORIZONTAL_ALIGNMENT_CENTER, msz.x, 17, -1, _a(UITheme.TEXT, a))

## "[F] Enter ship" -> key cap + text
func _draw_prompt(cx: float, y: float, s: String, a: float) -> void:
	var key := ""
	var rest := s
	if s.begins_with("["):
		var e := s.find("]")
		if e > 0:
			key = s.substr(1, e - 1)
			rest = s.substr(e + 1).strip_edges()
	var tw := UITheme.text_width(rest, 18)
	var kw := 0.0
	if key != "":
		kw = maxf(UITheme.text_width(key, 17, UITheme.font_bold()) + 18.0, 32.0)
	var total := kw + (10.0 if key != "" else 0.0) + tw
	var x := cx - total * 0.5
	var r := Rect2(x - 18.0, y - 24.0, total + 36.0, 40.0)
	UITheme.draw_chamfer(self, r, 8.0, _a(UITheme.PANEL_DARK, a), _a(UITheme.LINE, 0.8 * a), 1.0)
	if key != "":
		var kr := Rect2(x, y - 17.0, kw, 26.0)
		draw_rect(kr, _a(Color(0.9, 0.97, 1.0, 0.92), a))
		_txt(Vector2(kr.get_center().x, kr.position.y + 19.0), key, 17, Color(0.04, 0.08, 0.12, a * _hud_a), 0.5, UITheme.font_bold())
		x += kw + 10.0
	_txt(Vector2(x, y + 3.0), rest, 18, _a(UITheme.TEXT, a))

func _draw_toasts() -> void:
	var f := UITheme.font()
	var w := 330.0
	var y := MARGIN + 6.0
	if bool(Game.settings.get("show_fps", false)):
		y += 0.0
	var x_right := size.x - MARGIN
	for t in _toasts:
		var age: float = t["age"]
		var life: float = t["life"]
		var kind: String = t["kind"]
		var col := UITheme.kind_color(kind)
		var h: float = t["h"]
		var slide := 1.0 - UITheme.ease_out(age / 0.28)
		var a := minf(age / 0.18, 1.0)
		if age > life:
			a *= clampf(1.0 - (age - life) / 0.5, 0.0, 1.0)
		var x := x_right - w + slide * 60.0
		var r := Rect2(x, y, w, h)
		UITheme.draw_chamfer(self, r, 7.0, _a(Color(0.02, 0.04, 0.07, 0.86), a), _a(col, 0.55 * a), 1.0)
		draw_rect(Rect2(x, y + 7.0, 3.0, h - 14.0), _a(col, a))
		draw_multiline_string(f, Vector2(x + 18.0, y + 20.0), str(t["text"]), HORIZONTAL_ALIGNMENT_LEFT, w - 34.0, 15, -1, _a(UITheme.TEXT, a))
		var cnt: int = int(t.get("count", 1))
		if cnt > 1:
			_txt(Vector2(x + w - 10.0, y + 18.0), "x%d" % cnt, 12, _a(col, a), 1.0)
		y += h + 8.0 - (1.0 - a) * 0.0

# ---- black hole warning ---------------------------------------------------------------------------------------------------
func _draw_bh_warning(cx: float) -> void:
	if _bh_a < 0.01:
		return
	var lv := _bh_level
	if lv <= 0:
		lv = 1
	var title := "GRAVITATIONAL ANOMALY"
	var sub := "Singularity detected  -  keep your distance"
	var col := UITheme.WARN
	var hz := 0.0
	match lv:
		1:
			col = UITheme.WARN
			hz = 0.8
		2:
			title = "DANGER  -  GRAVITY WELL"
			sub = "Pulse drive offline  -  controls degrading  -  burn away now"
			col = Color(1.0, 0.5, 0.2)
			hz = 2.0
		3:
			title = "POINT OF NO RETURN"
			sub = "Escape is no longer possible"
			col = UITheme.DANGER
			hz = 4.5
		4:
			title = "EVENT HORIZON"
			sub = "Crossing the singularity"
			col = Color(1, 1, 1)
			hz = 8.0
	var flash := 0.55 + 0.45 * _pulse(hz)
	var w := 560.0
	var h := 112.0
	var r := Rect2(cx - w * 0.5, 132.0 - (1.0 - _bh_a) * 20.0, w, h)
	var a := _bh_a
	UITheme.draw_chamfer(self, r, 12.0, _a(Color(col.r * 0.12, col.g * 0.08, col.b * 0.08, 0.86), a), _a(col, (0.45 + 0.55 * flash) * a), 2.0)
	# hazard stripes along the top
	var x := r.position.x + 20.0
	while x < r.end.x - 30.0:
		draw_line(Vector2(x, r.position.y + 6.0), Vector2(x + 10.0, r.position.y + 6.0), _a(col, 0.6 * a * flash), 4.0)
		x += 20.0
	# icon
	var ic := Vector2(r.position.x + 52.0, r.position.y + 54.0)
	draw_circle(ic, 15.0, _a(Color(0, 0, 0, 1), a))
	draw_arc(ic, 16.0, 0, TAU, 32, _a(col, a * flash), 3.0, true)
	draw_arc(ic, 26.0, 0.4, 2.7, 24, _a(col, 0.6 * a), 2.0, true)
	draw_arc(ic, 26.0, 3.5, 5.8, 24, _a(col, 0.6 * a), 2.0, true)
	_cap(Vector2(r.position.x + 96.0, r.position.y + 38.0), title, 20, _a(col.lerp(Color.WHITE, 0.25), a * (0.75 + 0.25 * flash)))
	_txt(Vector2(r.position.x + 96.0, r.position.y + 60.0), sub, 14, _a(UITheme.TEXT, a))
	# live distance + zone scale (log)
	var dist := _bh_live_distance()
	if dist < 0.0:
		dist = _bh_dist
	_cap(Vector2(r.end.x - 20.0, r.position.y + 38.0), UITheme.fmt_dist(dist), 18, _a(UITheme.TEXT, a), 1.0)
	var bar := Rect2(r.position.x + 96.0, r.position.y + 78.0, w - 130.0, 8.0)
	draw_rect(bar, _a(Color(1, 1, 1, 0.1), a))
	var zones := [BlackHoleParams.WARN_RADIUS, BlackHoleParams.DANGER_RADIUS, BlackHoleParams.POINT_OF_NO_RETURN, BlackHoleParams.RS * 1.05]
	var zcols := [UITheme.WARN, Color(1.0, 0.5, 0.2), UITheme.DANGER, Color.WHITE]
	var lmax := log(BH_ZONE_FAR)
	var lmin := log(BlackHoleParams.RS)
	for zi in zones.size():
		var zx := bar.position.x + bar.size.x * (1.0 - (log(maxf(zones[zi], 1.0)) - lmin) / (lmax - lmin))
		draw_line(Vector2(zx, bar.position.y - 3.0), Vector2(zx, bar.end.y + 3.0), _a(zcols[zi], 0.9 * a), 2.0)
	var pk := bar.position.x + bar.size.x * (1.0 - clampf((log(maxf(dist, 1.0)) - lmin) / (lmax - lmin), 0.0, 1.0))
	draw_rect(Rect2(bar.position.x, bar.position.y, pk - bar.position.x, bar.size.y), _a(col, 0.55 * a))
	draw_colored_polygon(PackedVector2Array([Vector2(pk, bar.position.y - 2.0), Vector2(pk - 5.0, bar.position.y - 10.0), Vector2(pk + 5.0, bar.position.y - 10.0)]), _a(Color.WHITE, a))

func _bh_live_distance() -> float:
	var sys := Universe.system
	if sys == null or sys.black_hole_index < 0:
		return -1.0
	var who: Node3D = Game.ship if Game.mode != Game.Mode.FOOT else Game.player
	if who == null or not is_instance_valid(who):
		return -1.0
	return (Frame.to_local(Universe.body_pos(sys.black_hole_index)) - who.global_position).length()
