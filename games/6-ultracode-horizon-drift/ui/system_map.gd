class_name SystemMap
extends Control
## SYSTEM MAP / NAVIGATION (module M6). Top-down orbit diagram of the current system with animated orbits (visual time x1 / x60 / x600),
## bodies coloured by biome, click a body to set Game.nav_target (Events.nav_target_changed), list + detail card, ship marker.
## Overlay contract: Game.toggle_overlay() calls open() / close() (process_mode ALWAYS).

class MapLayer extends Control:
	var map: SystemMap
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if map != null:
			map._draw_map(self)

class Row extends Control:
	signal picked(idx: int)
	var body_idx: int = -1
	var map: SystemMap
	var _hover: bool = false
	func _init() -> void:
		custom_minimum_size = Vector2(0, 30)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true; map._hover_row = body_idx; queue_redraw())
		mouse_exited.connect(func():
			_hover = false
			if map._hover_row == body_idx:
				map._hover_row = -1
			queue_redraw())
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			UITheme.sfx("ui_click")
			picked.emit(body_idx)
			accept_event()
	func _draw() -> void:
		if body_idx < 0 or Universe.system == null:
			return
		var b: BodyDef = Universe.system.bodies[body_idx]
		var sel: bool = map != null and map._selected == body_idx
		var col := UITheme.body_color(b)
		var indent := 16.0 if b.kind == BodyDef.Kind.MOON else 0.0
		if _hover or sel:
			draw_rect(Rect2(Vector2.ZERO, size), UITheme.ca(UITheme.ACCENT, 0.15 if sel else 0.08))
			draw_rect(Rect2(0, 0, 3, size.y), UITheme.ACCENT if sel else UITheme.ca(UITheme.ACCENT, 0.5))
		var c := Vector2(18.0 + indent, size.y * 0.5)
		var r := 4.0 if b.kind == BodyDef.Kind.MOON else 5.5
		draw_circle(c, r + 3.0, UITheme.ca(col, 0.2))
		if b.kind == BodyDef.Kind.BLACK_HOLE:
			draw_circle(c, r, Color.BLACK)
			draw_arc(c, r + 1.0, 0, TAU, 16, col, 1.5, true)
		else:
			draw_circle(c, r, col)
		var nw := UITheme.text(self, Vector2(34.0 + indent, size.y * 0.5 + 5.0), b.name, 15, UITheme.TEXT, 0.0, null, false)
		if Game.nav_target == body_idx:
			var tx := 34.0 + indent + nw + 10.0
			var tw := UITheme.text_width("NAV", 10, UITheme.font_caps()) + 10.0
			UITheme.draw_chamfer(self, Rect2(tx, size.y * 0.5 - 9.0, tw, 18.0), 4.0, UITheme.ca(UITheme.ACCENT, 0.22), UITheme.ACCENT, 1.0)
			UITheme.text(self, Vector2(tx + 5.0, size.y * 0.5 + 4.0), "NAV", 10, UITheme.ACCENT_HI, 0.0, UITheme.font_caps(), false)
		var dist := map._dist_from_ship(body_idx)
		var tlabel := UITheme.fmt_dist(dist) if dist >= 0.0 else ""
		UITheme.text(self, Vector2(size.x - 8.0, size.y * 0.5 + 5.0), tlabel, 13, UITheme.TEXT_DIM, 1.0, null, false)

const SPEEDS := [1.0, 60.0, 600.0]

var _bg: ColorRect
var _mat: ShaderMaterial
var _layer: MapLayer
var _t: float = 0.0
var _sim_speed: float = 60.0
var _sim_off: float = 0.0
var _hover: int = -1
var _hover_row: int = -1
var _selected: int = -1
var _disp: Array = []
var _rmax: float = 1.0
var _center: Vector2 = Vector2.ZERO
var _rpx: float = 300.0
var _dust: Array = []
var _list_box: VBoxContainer
var _list_for: int = -2
var _rows: Array = []
var _sub: Label
var _card: UIPanel
var _c_name: Label
var _c_type: Label
var _c_desc: Label
var _c_grid: Dictionary = {}
var _c_btn: UIButton
var _c_extra: Label
var _speed_btns: Array = []
var _card_for: int = -2
var _card_t: float = 0.0
var _open_t: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/ui_blur.gdshader")
	_mat.set_shader_parameter("tint_amount", 0.80)
	_mat.set_shader_parameter("blur_lod", 3.5)
	_mat.set_shader_parameter("vignette", 0.75)
	_bg.material = _mat
	add_child(_bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in 160:
		_dust.append({"p": Vector2(rng.randf(), rng.randf()), "s": rng.randf_range(0.6, 1.8), "ph": rng.randf() * TAU})
	_layer = MapLayer.new()
	_layer.map = self
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	_build_ui()
	Events.nav_target_changed.connect(func(_i: int): _card_t = 0.0)
	visible = false
	set_process(false)

# ==============================================================================================================================
func _build_ui() -> void:
	# header
	var head := HBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 30.0
	head.offset_right = -30.0
	head.offset_top = 20.0
	head.offset_bottom = 84.0
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(UITheme.label("NAVIGATION", 13, UITheme.ACCENT, true))
	tv.add_child(UITheme.label("SYSTEM MAP", 36, UITheme.TEXT, true))
	_sub = UITheme.label("", 14, UITheme.TEXT_DIM)
	tv.add_child(_sub)
	head.add_child(tv)
	var close_btn := UIButton.new("CLOSE   [N]", "primary")
	close_btn.custom_minimum_size = Vector2(170, 44)
	close_btn.pressed.connect(func(): Game.close_overlays())
	var cw := VBoxContainer.new()
	cw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cw.add_child(close_btn)
	head.add_child(cw)
	# right column: list + card
	var col := VBoxContainer.new()
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.anchor_top = 0.0
	col.anchor_bottom = 0.0
	col.offset_left = -26.0 - 380.0
	col.offset_right = -26.0
	col.offset_top = 100.0
	col.offset_bottom = 100.0
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var lp := UIPanel.new(10, "BODIES")
	lp.custom_minimum_size = Vector2(380, 0)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(350, 238)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 0)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list_box)
	lp.add_content(sc)
	col.add_child(lp)
	_card = UIPanel.new(16, "BODY DETAILS")
	_card.custom_minimum_size = Vector2(380, 0)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 5)
	_card.add_content(cv)
	_c_name = UITheme.label("", 26, UITheme.TEXT, true)
	cv.add_child(_c_name)
	_c_type = UITheme.label("", 14, UITheme.TEXT_DIM)
	cv.add_child(_c_type)
	_c_desc = UITheme.label("", 13, UITheme.TEXT_DIM)
	_c_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_c_desc.custom_minimum_size = Vector2(340, 0)
	cv.add_child(_c_desc)
	cv.add_child(UITheme.hline())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 3)
	for k in ["DISTANCE", "ORBIT", "RADIUS", "GRAVITY", "DAY LENGTH", "TEMPERATURE", "ATMOSPHERE", "HAZARDS", "STATUS"]:
		var kl := UITheme.label(k, 11, UITheme.TEXT_FAINT, true)
		kl.custom_minimum_size = Vector2(112, 0)
		grid.add_child(kl)
		var vl := UITheme.label("-", 14, UITheme.TEXT)
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(vl)
		_c_grid[k] = vl
	cv.add_child(grid)
	_c_extra = UITheme.label("", 13, UITheme.WARN)
	_c_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_c_extra.custom_minimum_size = Vector2(340, 0)
	cv.add_child(_c_extra)
	_c_btn = UIButton.new("SET NAVIGATION TARGET", "primary")
	_c_btn.custom_minimum_size = Vector2(0, 42)
	_c_btn.pressed.connect(_toggle_nav)
	cv.add_child(_c_btn)
	col.add_child(_card)
	# bottom-left: simulation speed
	var bl := HBoxContainer.new()
	bl.anchor_left = 0.0
	bl.anchor_right = 0.0
	bl.anchor_top = 1.0
	bl.anchor_bottom = 1.0
	bl.offset_left = 28.0
	bl.offset_top = -78.0
	bl.offset_bottom = -44.0
	bl.offset_right = 28.0 + 420.0
	bl.add_theme_constant_override("separation", 8)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := UITheme.label("ORBITAL TIME", 12, UITheme.TEXT_FAINT, true)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bl.add_child(lbl)
	for i in SPEEDS.size():
		var sp: float = SPEEDS[i]
		var b := UIButton.new("LIVE" if sp == 1.0 else "x%d" % int(sp), "small")
		b.custom_minimum_size = Vector2(66, 32)
		b.pressed.connect(func(): _set_speed(sp))
		bl.add_child(b)
		_speed_btns.append(b)
	add_child(bl)

func _set_speed(sp: float) -> void:
	_sim_speed = sp
	if sp == 1.0:
		_sim_off = 0.0

# ==============================================================================================================================
func open() -> void:
	visible = true
	set_process(true)
	_t = 0.0
	_open_t = 0.0
	_sim_off = 0.0
	_hover = -1
	_selected = Game.nav_target
	_card_for = -2
	_list_for = -2
	_rebuild_list()
	UITheme.sfx("ui_open")

func close() -> void:
	visible = false
	set_process(false)

func _rebuild_list() -> void:
	for c in _list_box.get_children():
		c.queue_free()
	_rows.clear()
	var sys := Universe.system
	if sys == null:
		return
	_list_for = Universe.current_id
	_sub.text = "%s system   -   %s-class star   -   %d bodies" % [sys.name, sys.star.spectral_class, sys.bodies.size()]
	var order: Array = []
	for b in sys.bodies:
		var bd: BodyDef = b
		if bd.parent < 0 and not bd.is_black_hole():
			order.append(bd.index)
			var ms: Array = bd.moons.duplicate()
			ms.sort_custom(func(x: int, y: int) -> bool: return (sys.bodies[x] as BodyDef).orbit_radius < (sys.bodies[y] as BodyDef).orbit_radius)
			for m in ms:
				order.append(int(m))
	if sys.black_hole_index >= 0:
		order.append(sys.black_hole_index)
	for idx in order:
		var r := Row.new()
		r.body_idx = int(idx)
		r.map = self
		r.picked.connect(_on_row_picked)
		_list_box.add_child(r)
		_rows.append(r)

func _on_row_picked(idx: int) -> void:
	_select(idx)

func _select(idx: int) -> void:
	_selected = idx
	if idx >= 0:
		UINav.set_target(idx, true)
	_card_t = 0.0

func _toggle_nav() -> void:
	var idx := _selected if _selected >= 0 else _hover
	if idx < 0:
		return
	if Game.nav_target == idx:
		UINav.set_target(-1)
	else:
		UINav.set_target(idx)
	_card_t = 0.0

# ==============================================================================================================================
# helpers
# ==============================================================================================================================
func _ship_abs() -> DVec:
	var who: Node3D = Game.ship
	if Game.mode == Game.Mode.FOOT and Game.player != null:
		who = Game.player
	if who == null or not is_instance_valid(who):
		return null
	return Frame.to_abs(who.global_position)

func _dist_from_ship(idx: int) -> float:
	var sa := _ship_abs()
	if sa == null or Universe.system == null:
		return -1.0
	return maxf(Universe.body_pos(idx).distance_to(sa) - (Universe.system.bodies[idx] as BodyDef).radius, 0.0)

func _f(r: float) -> float:
	return _rpx * pow(clampf(r / _rmax, 0.0, 1.6), 0.55)

func _icon_r(b: BodyDef) -> float:
	match b.kind:
		BodyDef.Kind.GAS_GIANT: return 15.0
		BodyDef.Kind.MOON: return 3.5 + 1.8 * clampf((b.radius - 1900.0) / 3600.0, 0.0, 1.0)
		BodyDef.Kind.BLACK_HOLE: return 9.0
	return 6.0 + 5.0 * clampf((b.radius - 2000.0) / 9000.0, 0.0, 1.0)

func _layout() -> void:
	var sys := Universe.system
	if sys == null:
		return
	var rw := size.x - 440.0
	_center = Vector2(rw * 0.5 + 26.0, size.y * 0.5 + 24.0)
	_rpx = minf(rw * 0.5, size.y * 0.5) - 52.0
	var t := Universe.time + _sim_off
	var n := sys.bodies.size()
	_disp.resize(n)
	_rmax = 1.0
	for b in sys.bodies:
		var bd: BodyDef = b
		if bd.parent < 0:
			var r0 := bd.orbit_radius
			if bd.is_black_hole():
				r0 = Vector2(bd.fixed_pos.x, bd.fixed_pos.z).length()
			_rmax = maxf(_rmax, r0)
	_rmax *= 1.08
	for b in sys.bodies:
		var bd2: BodyDef = b
		if bd2.parent < 0:
			var p := Universe.body_pos(bd2.index, t)
			var r := sqrt(p.x * p.x + p.z * p.z)
			var ang := atan2(p.z, p.x)
			_disp[bd2.index] = _center + Vector2(cos(ang), sin(ang)) * _f(r)
	for b in sys.bodies:
		var bd3: BodyDef = b
		if bd3.parent >= 0:
			var pp := Universe.body_pos(bd3.parent, t)
			var mp := Universe.body_pos(bd3.index, t)
			var rel := Vector2(mp.x - pp.x, mp.z - pp.z)
			var parent_def: BodyDef = sys.bodies[bd3.parent]
			var ms: Array = parent_def.moons.duplicate()
			ms.sort_custom(func(x: int, y: int) -> bool: return (sys.bodies[x] as BodyDef).orbit_radius < (sys.bodies[y] as BodyDef).orbit_radius)
			var rank := maxi(ms.find(bd3.index), 0)
			var rr := _icon_r(parent_def) + 16.0 + 12.0 * float(rank)
			var a2 := atan2(rel.y, rel.x)
			_disp[bd3.index] = (_disp[bd3.parent] as Vector2) + Vector2(cos(a2), sin(a2)) * rr

func _pick(pos: Vector2) -> int:
	var sys := Universe.system
	if sys == null:
		return -1
	var best := -1
	var bd := 1.0e9
	for b in sys.bodies:
		var def: BodyDef = b
		if def.index >= _disp.size():
			continue
		var d := (_disp[def.index] as Vector2).distance_to(pos)
		var lim := _icon_r(def) + 10.0
		if d < lim and d < bd:
			bd = d
			best = def.index
	return best

# ==============================================================================================================================
func _process(dt: float) -> void:
	if not visible:
		return
	dt = minf(dt, 0.05)
	_t += dt
	_open_t += dt
	if _sim_speed != 1.0:
		_sim_off += dt * (_sim_speed - 1.0)
	_layout()
	if _list_for != Universe.current_id:
		_rebuild_list()
	var hc := get_viewport().gui_get_hovered_control()
	if hc == self:
		_hover = _pick(get_local_mouse_position())
	elif hc != null:
		_hover = -1
	_card_t -= dt
	var want := _selected
	if _hover >= 0:
		want = _hover
	elif _hover_row >= 0:
		want = _hover_row
	if want < 0:
		want = Game.nav_target
	if want < 0 and Universe.system != null:
		want = Universe.system.start_body
	if want != _card_for or _card_t <= 0.0:
		_card_for = want
		_card_t = 0.5
		_update_card()
	for r in _rows:
		(r as Control).queue_redraw()
	for i in _speed_btns.size():
		(_speed_btns[i] as UIButton).set_accent(UITheme.ACCENT_HI if is_equal_approx(_sim_speed, SPEEDS[i]) else UITheme.ACCENT_DIM)
	_layer.queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var id := _pick(mb.position)
			if id >= 0:
				_select(id)
			accept_event()
	elif ev is InputEventMouseMotion:
		_hover = _pick((ev as InputEventMouseMotion).position)
		accept_event()

func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev.is_action_pressed("nav_next"):
		UINav.cycle()
		_selected = Game.nav_target
		_card_t = 0.0
		get_viewport().set_input_as_handled()

# ==============================================================================================================================
func _update_card() -> void:
	var sys := Universe.system
	if sys == null or _card_for < 0 or _card_for >= sys.bodies.size():
		return
	var b: BodyDef = sys.bodies[_card_for]
	_c_name.text = b.name.to_upper()
	_c_type.text = b.type_label()
	_c_type.add_theme_color_override("font_color", UITheme.body_color(b))
	_c_desc.text = str(BiomeDB.get_biome(b.biome).get("desc", ""))
	var dist := _dist_from_ship(b.index)
	(_c_grid["DISTANCE"] as Label).text = UITheme.fmt_dist(dist) if dist >= 0.0 else "-"
	if b.is_black_hole():
		(_c_grid["ORBIT"] as Label).text = "Fixed  -  %s from the star" % UITheme.fmt_dist(Vector2(b.fixed_pos.x, b.fixed_pos.z).length())
		(_c_grid["RADIUS"] as Label).text = "Horizon %s" % UITheme.fmt_dist(b.radius)
		(_c_grid["GRAVITY"] as Label).text = "Extreme"
		(_c_grid["DAY LENGTH"] as Label).text = "-"
		(_c_grid["TEMPERATURE"] as Label).text = "-"
		(_c_grid["ATMOSPHERE"] as Label).text = "-"
		(_c_grid["HAZARDS"] as Label).text = "Lethal gravity well"
		(_c_grid["STATUS"] as Label).text = "Leads to %s" % Universe.get_star(b.bh_dest_system).name
		_c_extra.text = "Cross the point of no return and the singularity carries you to another star system."
		_c_extra.add_theme_color_override("font_color", UITheme.VIOLET)
	else:
		var orbit_txt := UITheme.fmt_dist(b.orbit_radius)
		if b.parent >= 0:
			orbit_txt += "  around %s" % (sys.bodies[b.parent] as BodyDef).name
		(_c_grid["ORBIT"] as Label).text = orbit_txt
		(_c_grid["RADIUS"] as Label).text = UITheme.fmt_dist(b.radius)
		if b.is_gas_giant():
			(_c_grid["GRAVITY"] as Label).text = "Crushing"
		else:
			(_c_grid["GRAVITY"] as Label).text = "%.2f g   (%.1f m/s²)" % [b.gravity / 9.81, b.gravity]
		(_c_grid["DAY LENGTH"] as Label).text = "%d min" % int(round(b.spin_period / 60.0))
		(_c_grid["TEMPERATURE"] as Label).text = "%d / %d °C" % [int(round(b.temp_day_c)), int(round(b.temp_night_c))]
		var at := "None"
		if b.has_atmosphere:
			at = "Present"
		if b.has_ocean:
			at += "  -  %s seas" % b.ocean_kind
		(_c_grid["ATMOSPHERE"] as Label).text = at
		var hz: Array = []
		if b.toxicity > 0.05:
			hz.append("Toxic %d%%" % int(round(b.toxicity * 100.0)))
		if b.radiation > 0.05:
			hz.append("Radiation %d%%" % int(round(b.radiation * 100.0)))
		(_c_grid["HAZARDS"] as Label).text = ", ".join(hz) if not hz.is_empty() else "None"
		var disc := Game.is_discovered(b.index)
		(_c_grid["STATUS"] as Label).text = "Surveyed" if disc else "Unsurveyed"
		(_c_grid["STATUS"] as Label).add_theme_color_override("font_color", UITheme.GOOD if disc else UITheme.TEXT_DIM)
		if b.is_gas_giant():
			_c_extra.text = "No solid surface - pressure destroys any ship that descends too deep."
			_c_extra.add_theme_color_override("font_color", UITheme.WARN)
		elif not b.landable:
			_c_extra.text = ""
		else:
			_c_extra.text = ""
	var is_nav := Game.nav_target == b.index
	_c_btn.text = "CLEAR NAVIGATION TARGET" if is_nav else "SET NAVIGATION TARGET"
	_c_btn.set_accent(UITheme.WARN if is_nav else UITheme.ACCENT)

# ==============================================================================================================================
# drawing
# ==============================================================================================================================
func _draw_map(ci: Control) -> void:
	var sys := Universe.system
	if sys == null or _disp.size() != sys.bodies.size():
		return
	var vp := size
	var open_k := UITheme.ease_out(_open_t / 0.7)
	# dust
	for d in _dust:
		var p: Vector2 = (d["p"] as Vector2) * vp
		var tw := 0.5 + 0.5 * sin(_t * 0.8 + float(d["ph"]))
		ci.draw_circle(p, float(d["s"]), Color(0.75, 0.88, 1.0, 0.25 * tw))
	# faint scale rings + crosshair axes
	ci.draw_line(Vector2(_center.x - _rpx - 30.0, _center.y), Vector2(_center.x + _rpx + 30.0, _center.y), UITheme.ca(UITheme.ACCENT, 0.06), 1.0)
	ci.draw_line(Vector2(_center.x, _center.y - _rpx - 30.0), Vector2(_center.x, _center.y + _rpx + 30.0), UITheme.ca(UITheme.ACCENT, 0.06), 1.0)
	var nav := Game.nav_target
	var sel := _selected
	# orbits
	for b in sys.bodies:
		var bd: BodyDef = b
		if bd.is_black_hole():
			continue
		var is_hot := bd.index == _hover or bd.index == _hover_row or bd.index == sel or bd.index == nav
		var col := UITheme.body_color(bd)
		var a := (0.55 if is_hot else 0.2) * open_k
		if bd.parent < 0:
			var rad := _f(bd.orbit_radius) * open_k
			ci.draw_arc(_center, rad, 0, TAU, 160, UITheme.ca(col.lerp(UITheme.ACCENT, 0.5) if not is_hot else col, a), 1.5 if is_hot else 1.0, true)
		else:
			var pd: BodyDef = sys.bodies[bd.parent]
			var ms: Array = pd.moons.duplicate()
			ms.sort_custom(func(x: int, y: int) -> bool: return (sys.bodies[x] as BodyDef).orbit_radius < (sys.bodies[y] as BodyDef).orbit_radius)
			var rank := maxi(ms.find(bd.index), 0)
			var rr := _icon_r(pd) + 16.0 + 12.0 * float(rank)
			ci.draw_arc(_disp[bd.parent] as Vector2, rr, 0, TAU, 48, UITheme.ca(col, a * 0.9), 1.0, true)
	# star
	var sc: Color = sys.star.color
	var pulse := 0.9 + 0.1 * sin(_t * 1.3)
	var gtex := UITheme.glow_tex()
	ci.draw_texture_rect(gtex, Rect2(_center - Vector2(110, 110) * pulse, Vector2(220, 220) * pulse), false, UITheme.ca(sc, 0.55 * open_k))
	ci.draw_texture_rect(gtex, Rect2(_center - Vector2(46, 46), Vector2(92, 92)), false, UITheme.ca(sc.lerp(Color.WHITE, 0.5), 0.9 * open_k))
	ci.draw_circle(_center, 12.0, sc.lerp(Color.WHITE, 0.6))
	UITheme.text(ci, _center + Vector2(0, 34.0), sys.name.to_upper(), 11, UITheme.ca(sc.lerp(Color.WHITE, 0.4), 0.85), 0.5, UITheme.font_caps(), false)
	# nav line from the ship marker to the target
	var ship_pos := _ship_marker()
	if nav >= 0 and nav < _disp.size() and ship_pos != Vector2(-9999, -9999):
		var tp: Vector2 = _disp[nav]
		var dir := (tp - ship_pos)
		var dl := dir.length()
		if dl > 20.0:
			var n := dir / dl
			var phase := -_t * 28.0
			var pos := 14.0
			while pos < dl - 14.0:
				var m := fposmod(pos + phase, 18.0)
				if m < 9.0:
					ci.draw_line(ship_pos + n * pos, ship_pos + n * minf(pos + 9.0 - m, dl - 14.0), UITheme.ca(UITheme.ACCENT, 0.7), 1.6, true)
				pos += 9.0 - m if m < 9.0 else 18.0 - m
	# bodies (moons last so they are on top)
	for pass_i in 2:
		for b in sys.bodies:
			var bd2: BodyDef = b
			if (bd2.parent >= 0) != (pass_i == 1):
				continue
			_draw_body(ci, bd2, open_k)
	# ship marker
	if ship_pos != Vector2(-9999, -9999):
		var pr := 0.5 + 0.5 * sin(_t * 3.0)
		ci.draw_arc(ship_pos, 11.0 + 4.0 * pr, 0, TAU, 28, UITheme.ca(UITheme.GOOD, 0.8), 1.6, true)
		UITheme.draw_triangle(ci, ship_pos, Vector2(0, -1), 6.0, UITheme.GOOD)
		UITheme.text(ci, ship_pos + Vector2(-19.0, 4.0), "YOU", 11, UITheme.GOOD, 1.0, UITheme.font_caps(), true)
	# simulation badge
	if _sim_speed != 1.0:
		var lbl := "SIMULATION  x%d" % int(_sim_speed)
		var w := UITheme.text_width(lbl, 12, UITheme.font_caps()) + 24.0
		UITheme.draw_chamfer(ci, Rect2(_center.x - w * 0.5, 22.0, w, 24.0), 6.0, UITheme.ca(UITheme.WARN, 0.12), UITheme.ca(UITheme.WARN, 0.8), 1.0)
		UITheme.text(ci, Vector2(_center.x, 39.0), lbl, 12, UITheme.WARN, 0.5, UITheme.font_caps(), false)
	UITheme.text(ci, Vector2(28.0, vp.y - 22.0), "CLICK a body to set the navigation target   -   T cycles targets   -   N / ESC closes", 11, UITheme.ca(UITheme.TEXT_DIM, 0.85), 0.0, UITheme.font_caps(), false)

func _ship_marker() -> Vector2:
	var sys := Universe.system
	if Game.ship == null or sys == null:
		return Vector2(-9999, -9999)
	if Frame.anchor >= 0 and Frame.anchor < _disp.size():
		var bd: BodyDef = sys.bodies[Frame.anchor]
		return (_disp[Frame.anchor] as Vector2) + Vector2(-_icon_r(bd) - 10.0, _icon_r(bd) + 10.0)      # lower-left: the body / moon labels sit above and to the right
	var sa := _ship_abs()
	if sa == null:
		return Vector2(-9999, -9999)
	var r := sqrt(sa.x * sa.x + sa.z * sa.z)
	var ang := atan2(sa.z, sa.x)
	return _center + Vector2(cos(ang), sin(ang)) * _f(r)

func _draw_body(ci: Control, b: BodyDef, open_k: float) -> void:
	var p: Vector2 = _disp[b.index]
	var r := _icon_r(b) * open_k
	var col := UITheme.body_color(b)
	var hot := b.index == _hover or b.index == _hover_row or b.index == _selected
	var gtex := UITheme.glow_tex()
	if b.kind == BodyDef.Kind.BLACK_HOLE:
		ci.draw_texture_rect(gtex, Rect2(p - Vector2(46, 46), Vector2(92, 92)), false, UITheme.ca(UITheme.VIOLET, 0.55 * open_k))
		ci.draw_circle(p, r, Color.BLACK)
		ci.draw_arc(p, r + 2.0, 0, TAU, 32, UITheme.ca(UITheme.VIOLET.lerp(Color.WHITE, 0.4), 0.95), 2.0, true)
		for q in 3:
			var a0 := _t * 1.6 + float(q) * TAU / 3.0
			ci.draw_arc(p, r + 8.0, a0, a0 + 0.9, 10, UITheme.ca(UITheme.VIOLET, 0.8), 2.0, true)
		ci.draw_set_transform(p, 0.0, Vector2(1.0, 0.28))
		ci.draw_arc(Vector2.ZERO, r + 14.0, 0, TAU, 48, UITheme.ca(Color(1.0, 0.7, 0.4), 0.7), 2.0, true)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_texture_rect(gtex, Rect2(p - Vector2(r * 3.6, r * 3.6), Vector2(r * 7.2, r * 7.2)), false, UITheme.ca(col, 0.4 * open_k))
		ci.draw_circle(p, r, col.darkened(0.5))
		ci.draw_circle(p + Vector2(-r * 0.12, -r * 0.12), r * 0.86, col)
		ci.draw_circle(p + Vector2(-r * 0.32, -r * 0.32), r * 0.34, col.lerp(Color.WHITE, 0.5))
		if b.is_gas_giant():
			# bands + ring
			for k in range(-1, 2):
				var yy := float(k) * r * 0.4
				var hw := sqrt(maxf(r * r - yy * yy, 0.0)) * 0.92
				ci.draw_line(p + Vector2(-hw, yy), p + Vector2(hw, yy), UITheme.ca(col.darkened(0.35), 0.55), 1.6)
			if b.has_rings:
				ci.draw_set_transform(p, -0.28, Vector2(1.0, 0.3))
				ci.draw_arc(Vector2.ZERO, r * 1.75, 0, TAU, 64, UITheme.ca(col.lightened(0.2), 0.85), 2.2, true)
				ci.draw_arc(Vector2.ZERO, r * 2.1, 0, TAU, 64, UITheme.ca(col.lightened(0.1), 0.5), 1.4, true)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if Game.is_discovered(b.index):
			ci.draw_arc(p, r + 3.5, 0.2, 0.9, 6, UITheme.ca(UITheme.GOOD, 0.8), 1.4, true)
	# labels
	var lbl_col := UITheme.TEXT if (hot or b.index == Game.nav_target) else UITheme.ca(col.lerp(Color.WHITE, 0.55), 0.95)
	var fs := 14 if b.kind != BodyDef.Kind.MOON else 12
	var off := Vector2(r + 9.0, 4.0)
	var lax := 0.0
	if b.kind == BodyDef.Kind.GAS_GIANT and b.has_rings:
		off.x += r * 1.2
	if not b.moons.is_empty():
		off = Vector2(0.0, -(r + 12.0) - (r * 0.7 if b.kind == BodyDef.Kind.GAS_GIANT else 0.0))
		lax = 0.5
	if b.kind == BodyDef.Kind.BLACK_HOLE:
		off = Vector2(0.0, r + 34.0)
		lax = 0.5
	UITheme.text(ci, p + off, b.name.to_upper(), fs, lbl_col, lax, UITheme.font_caps(), true)
	# selection / nav reticle
	if b.index == _selected or b.index == _hover:
		var rr := r + 10.0 + 1.5 * sin(_t * 4.0)
		UITheme.draw_brackets(ci, Rect2(p - Vector2(rr, rr), Vector2(rr, rr) * 2.0), 5.0, UITheme.ACCENT_HI, 1.6)
	if b.index == Game.nav_target:
		var rn := r + 15.0
		UITheme.draw_diamond(ci, p, rn, UITheme.ca(UITheme.ACCENT, 0.9), false, 1.6)
		UITheme.text(ci, p + Vector2(0, rn + 14.0), "NAV TARGET", 10, UITheme.ACCENT_HI, 0.5, UITheme.font_caps(), true)
