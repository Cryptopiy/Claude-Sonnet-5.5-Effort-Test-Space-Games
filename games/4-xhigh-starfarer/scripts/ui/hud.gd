class_name Hud
extends CanvasLayer
## In-game HUD: location, speed/altitude/throttle, hull/shield, suit meters, nav markers, black-hole warning, messages, hints.

const CYAN := Color(0.45, 0.95, 1.0)
const WHITE := Color(0.92, 0.97, 1.0)
const AMBER := Color(1.0, 0.75, 0.25)
const RED := Color(1.0, 0.3, 0.25)
const GREEN := Color(0.5, 1.0, 0.55)
const PANEL_BG := Color(0.02, 0.06, 0.09, 0.62)

var root: Control
var nav: NavOverlay
var fx_rect: ColorRect
var fx_mat: ShaderMaterial
var lbl_system: Label
var lbl_loc: Label
var lbl_env: Label
var lbl_speed: Label
var lbl_speed_unit: Label
var lbl_alt: Label
var lbl_mode: Label
var lbl_hint: Label
var lbl_target: Label
var lbl_banner: Label
var bar_throttle: ProgressBar
var bar_hull: ProgressBar
var bar_shield: ProgressBar
var bar_health: ProgressBar
var bar_prot: ProgressBar
var bar_fuel: ProgressBar
var ship_panel: Control
var foot_panel: Control
var bh_panel: Control
var lbl_bh_title: Label
var lbl_bh_info: Label
var bar_bh_pull: ProgressBar
var lbl_bh_pnr: Label
var msg_box: VBoxContainer
var inv_panel: PanelContainer
var lbl_inv: Label
var lbl_fps: Label
var crosshair: Control
var banner_t := 0.0
var last_loc := ""
var msgs: Array = []
var show_inventory := false
var first_hint_t := 0.0
var scan_markers: Array = []


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# screen fx (below the HUD widgets)
	fx_rect = ColorRect.new()
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_mat = ShaderMaterial.new()
	fx_mat.shader = load("res://shaders/fx_overlay.gdshader")
	fx_rect.material = fx_mat
	root.add_child(fx_rect)
	nav = NavOverlay.new()
	nav.set_anchors_preset(Control.PRESET_FULL_RECT)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nav)
	_build_top_left()
	_build_ship_panel()
	_build_foot_panel()
	_build_bh_panel()
	_build_center()
	_build_messages()
	_build_inventory()
	Game.message.connect(_on_message)


# ---------------------------------------------------------------- widget helpers
func _lbl(text: String, size: int, col: Color, parent: Node = root) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _panel(parent: Node = root) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(0.3, 0.8, 0.95, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _bar(parent: Node, col: Color, w := 200.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, 10)
	b.show_percentage = false
	b.max_value = 100.0
	b.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_corner_radius_all(2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b


func _row(parent: Node, title: String, bar: ProgressBar, col := WHITE) -> void:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	var l := _lbl(title, 13, col, h)
	l.custom_minimum_size = Vector2(74, 0)
	h.add_child(bar)


func _corner(c: Control, right: bool, bottom: bool, mx: float, my: float) -> void:
	c.anchor_left = 1.0 if right else 0.0
	c.anchor_right = c.anchor_left
	c.anchor_top = 1.0 if bottom else 0.0
	c.anchor_bottom = c.anchor_top
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	c.offset_left = -mx if right else mx
	c.offset_right = c.offset_left
	c.offset_top = -my if bottom else my
	c.offset_bottom = c.offset_top


func _vbox(parent: Node, sep := 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	return v


# ---------------------------------------------------------------- layout
func _build_top_left() -> void:
	var p := _panel()
	p.position = Vector2(20, 18)
	var v := _vbox(p, 2)
	lbl_system = _lbl("SOLARA SYSTEM", 13, CYAN, v)
	lbl_loc = _lbl("Deep space", 24, WHITE, v)
	lbl_env = _lbl("", 14, GREEN, v)
	lbl_fps = _lbl("", 11, Color(0.6, 0.7, 0.8, 0.7), v)


func _build_ship_panel() -> void:
	ship_panel = Control.new()
	ship_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ship_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ship_panel)
	# bottom centre: speed
	var c := VBoxContainer.new()
	c.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.position.y = -26
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ship_panel.add_child(c)
	lbl_mode = _lbl("", 14, AMBER, c)
	lbl_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sp := HBoxContainer.new()
	sp.alignment = BoxContainer.ALIGNMENT_CENTER
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(sp)
	lbl_speed = _lbl("0", 44, WHITE, sp)
	lbl_speed_unit = _lbl(" m/s", 18, CYAN, sp)
	lbl_speed_unit.size_flags_vertical = Control.SIZE_SHRINK_END
	bar_throttle = _bar(c, CYAN, 320.0)
	bar_throttle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lbl_alt = _lbl("", 15, WHITE, c)
	lbl_alt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# bottom right: hull/shield
	var p := _panel(ship_panel)
	_corner(p, true, true, 24, 24)
	var v := _vbox(p, 6)
	bar_shield = _bar(v, Color(0.35, 0.75, 1.0), 170.0)
	bar_hull = _bar(v, Color(0.95, 0.6, 0.25), 170.0)
	v.move_child(bar_shield, 0)
	var t1 := _lbl("SHIELD", 11, CYAN, v)
	v.move_child(t1, 0)
	var t2 := _lbl("HULL", 11, AMBER, v)
	v.move_child(t2, 2)


func _build_foot_panel() -> void:
	foot_panel = Control.new()
	foot_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	foot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(foot_panel)
	var p := _panel(foot_panel)
	_corner(p, false, true, 24, 24)
	var v := _vbox(p, 6)
	bar_health = _bar(v, Color(0.9, 0.3, 0.3), 220.0)
	bar_prot = _bar(v, Color(0.35, 0.95, 0.6), 220.0)
	bar_fuel = _bar(v, Color(0.5, 0.75, 1.0), 220.0)
	_label_before(v, "HEALTH", bar_health, Color(1.0, 0.5, 0.5))
	_label_before(v, "HAZARD PROTECTION", bar_prot, GREEN)
	_label_before(v, "JETPACK", bar_fuel, CYAN)


func _label_before(v: Node, text: String, bar: Control, col: Color) -> void:
	var l := _lbl(text, 11, col, v)
	v.move_child(l, bar.get_index())


func _build_bh_panel() -> void:
	var wrap := CenterContainer.new()
	wrap.anchor_left = 0.0
	wrap.anchor_right = 1.0
	wrap.offset_top = 96
	wrap.offset_bottom = 300
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wrap)
	bh_panel = _panel(wrap)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.02, 0.02, 0.7)
	sb.border_color = Color(1.0, 0.25, 0.2, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	bh_panel.add_theme_stylebox_override("panel", sb)
	var v := _vbox(bh_panel, 3)
	lbl_bh_title = _lbl("GRAVITATIONAL ANOMALY", 22, RED, v)
	lbl_bh_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_bh_info = _lbl("", 14, WHITE, v)
	lbl_bh_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_bh_pull = _bar(v, RED, 360.0)
	lbl_bh_pnr = _lbl("", 14, AMBER, v)
	lbl_bh_pnr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bh_panel.visible = false


func _build_center() -> void:
	crosshair = CrossHair.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	lbl_hint = _lbl("", 17, WHITE)
	lbl_hint.anchor_left = 0.0
	lbl_hint.anchor_right = 1.0
	lbl_hint.anchor_top = 1.0
	lbl_hint.anchor_bottom = 1.0
	lbl_hint.offset_top = -200
	lbl_hint.offset_bottom = -170
	lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_banner = _lbl("", 40, WHITE)
	lbl_banner.anchor_left = 0.0
	lbl_banner.anchor_right = 1.0
	lbl_banner.offset_top = 130
	lbl_banner.offset_bottom = 230
	lbl_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_banner.modulate.a = 0.0
	lbl_target = _lbl("", 15, AMBER)
	_corner(lbl_target, true, false, 24, 20)
	lbl_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _build_messages() -> void:
	msg_box = VBoxContainer.new()
	msg_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	msg_box.position = Vector2(24, 150)
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_box.add_theme_constant_override("separation", 2)
	root.add_child(msg_box)


func _build_inventory() -> void:
	inv_panel = _panel()
	_corner(inv_panel, true, false, 24, 260)
	var v := _vbox(inv_panel, 4)
	_lbl("INVENTORY", 14, CYAN, v)
	lbl_inv = _lbl("(empty)", 14, WHITE, v)
	inv_panel.visible = false


func _on_message(text: String, kind: String) -> void:
	var col := WHITE
	match kind:
		"warn": col = AMBER
		"bad": col = RED
		"good": col = GREEN
		"info": col = Color(0.8, 0.92, 1.0)
	var l := _lbl(text, 15, col, msg_box)
	msgs.append({"node": l, "t": 7.0})
	if msgs.size() > 6:
		var old: Dictionary = msgs.pop_front()
		old.node.queue_free()


func show_banner(text: String, sub := "") -> void:
	lbl_banner.text = text if sub == "" else "%s\n%s" % [text, sub]
	banner_t = 5.0


func fmt_dist(m: float) -> String:
	if m < 1000.0:
		return "%d m" % int(m)
	if m < 100000.0:
		return "%.1f km" % (m / 1000.0)
	return "%d km" % int(m / 1000.0)


func fmt_speed(v: float) -> Array:
	if v < 1000.0:
		return ["%d" % int(v), " m/s"]
	return ["%.2f" % (v / 1000.0), " km/s"]


# ---------------------------------------------------------------- per-frame update
func update_hud(w: World, dt: float) -> void:
	var playing := Game.state == Game.State.PLAYING or Game.state == Game.State.WARP
	root.visible = (Game.show_hud or not playing) and Game.state != Game.State.MAP
	var in_menu := Game.state == Game.State.MENU
	if in_menu:
		for c in root.get_children():
			c.visible = (c == fx_rect)
		_update_fx(w)
		return
	else:
		for c in root.get_children():
			if c != bh_panel.get_parent() and c != inv_panel and c != ship_panel and c != foot_panel:
				c.visible = true
	_update_fx(w)
	var ship := w.ship
	ship_panel.visible = not w.on_foot
	foot_panel.visible = w.on_foot
	crosshair.visible = (w.cam_mode != World.CamMode.CHASE) or true
	(crosshair as CrossHair).ship_mode = not w.on_foot
	lbl_fps.text = "%d fps" % Engine.get_frames_per_second()
	# --- location
	lbl_system.text = "%s SYSTEM  ·  CLASS %s STAR" % [w.star_info.name.to_upper(), w.star_info.cls]
	var loc := "Deep space"
	var np := w.nearest_planet
	var alt: float = w.cam_alt
	if np != null and alt < np.radius * 4.0 + 30000.0:
		loc = np.display_name
		if np.data != null:
			var d: PlanetData = np.data
			lbl_env.text = "%s · %s · g %.1f" % [d.biome_name(), d.hazard_text(), d.gravity / 9.81 * 1.0]
			lbl_env.add_theme_color_override("font_color", AMBER if d.hazard != "" else GREEN)
	else:
		lbl_env.text = "Interstellar space"
		lbl_env.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	if w.bh != null and w.bh_dist < 120000.0:
		loc = "Singularity vicinity"
		lbl_env.text = "EXTREME GRAVITY"
		lbl_env.add_theme_color_override("font_color", RED)
	lbl_loc.text = loc
	if loc != last_loc:
		if last_loc != "" and np != null and loc == np.display_name and np.data != null:
			show_banner(loc.to_upper(), "%s world" % np.data.biome_name())
		last_loc = loc
	banner_t = maxf(banner_t - dt, 0.0)
	lbl_banner.modulate.a = clampf(banner_t, 0.0, 1.0) * clampf((5.0 - banner_t) * 3.0, 0.0, 1.0)
	# --- ship readouts
	if not w.on_foot:
		var sp := fmt_speed(ship.speed)
		lbl_speed.text = sp[0]
		lbl_speed_unit.text = sp[1]
		bar_throttle.value = ship.throttle * 100.0
		bar_hull.value = ship.hull
		bar_shield.value = ship.shield
		var mode := "FLIGHT"
		if ship.is_landed:
			mode = "LANDED"
		elif ship.gear_down:
			mode = "LANDING MODE"
		elif ship.pulse_spool > 0.3:
			mode = "PULSE DRIVE"
		elif ship.boosting:
			mode = "BOOST"
		if ship.entry_heat > 0.15:
			mode = "ATMOSPHERIC ENTRY"
		lbl_mode.text = mode
		if ship.alt < 1e8:
			lbl_alt.text = "ALT %s" % fmt_dist(maxf(ship.alt, 0.0))
		else:
			lbl_alt.text = ""
	else:
		var p := w.player
		bar_health.value = p.health
		bar_prot.value = p.protection
		bar_fuel.value = p.fuel
		var sp2 := fmt_speed(p.speed_h)
	# --- target
	var tb := ship.target_body
	if tb != null:
		var d2 := (tb.global_position - w.cam.global_position).length() - tb.radius
		var line := "TARGET  %s\n%s" % [tb.display_name.to_upper(), fmt_dist(maxf(d2, 0.0))]
		var dirv := (tb.global_position - w.cam.global_position).normalized()
		var closing := -ship.rel_vel.dot(-dirv) if not w.on_foot else 0.0
		if closing > 5.0:
			line += "   ETA %ds" % int(maxf(d2, 0.0) / closing)
		lbl_target.text = line
	else:
		lbl_target.text = ""
	# --- messages fade
	for m in msgs.duplicate():
		m.t -= dt
		var l: Label = m.node
		if is_instance_valid(l):
			l.modulate.a = clampf(m.t, 0.0, 1.0)
		if m.t <= 0.0:
			msgs.erase(m)
			if is_instance_valid(l):
				l.queue_free()
	# --- black hole panel
	_update_bh(w)
	# --- hints
	lbl_hint.text = _hint(w)
	# --- inventory
	inv_panel.visible = show_inventory
	if show_inventory:
		var s := ""
		for k in Game.inventory:
			s += "%s  x%d\n" % [k, Game.inventory[k]]
		lbl_inv.text = s if s != "" else "(empty)\nMine glowing crystals with LMB"
	# --- markers
	_update_markers(w)


func _update_fx(w: World) -> void:
	fx_mat.set_shader_parameter("speed", w.fx.speed)
	fx_mat.set_shader_parameter("heat", w.fx.heat)
	fx_mat.set_shader_parameter("bh", w.fx.bh)
	fx_mat.set_shader_parameter("warp", w.fx.warp)
	fx_mat.set_shader_parameter("flash", w.fx.flash)
	fx_mat.set_shader_parameter("damage", w.fx.damage)
	var vs := get_viewport().get_visible_rect().size
	fx_mat.set_shader_parameter("aspect", vs.x / maxf(vs.y, 1.0))
	if w.bh != null:
		var sp := w.project(w.bh.global_position)
		if sp.z > 0.5:
			fx_mat.set_shader_parameter("bh_pos", Vector2(sp.x / vs.x, sp.y / vs.y))


func _update_bh(w: World) -> void:
	var show := w.bh != null and w.bh_zone > 0 and not w.on_foot
	bh_panel.visible = show
	bh_panel.get_parent().visible = show
	if not show:
		return
	var flash := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012)
	var titles := ["", "GRAVITATIONAL ANOMALY", "SPACETIME CURVATURE", "ESCAPE VELOCITY EXCEEDED", "POINT OF NO RETURN"]
	lbl_bh_title.text = titles[w.bh_zone]
	lbl_bh_title.modulate.a = flash if w.bh_zone >= 3 else 1.0
	var pull := w.bh.pull_magnitude(w.bh_dist)
	lbl_bh_info.text = "Singularity %s  ·  pull %.1f m/s²  ·  engine max %d m/s²" % [fmt_dist(w.bh_dist), pull, 370 if w.ship.boosting else 130]
	bar_bh_pull.value = clampf(pull / 370.0 * 100.0, 0.0, 100.0)
	if w.bh_zone >= 4:
		lbl_bh_pnr.text = "NO ESCAPE POSSIBLE — INEVITABLE TRANSIT TO %s" % w.bh.dest_name.to_upper()
	elif w.bh_zone == 3:
		lbl_bh_pnr.text = "BOOST (SHIFT) directly away to escape"
	elif w.bh_zone == 2:
		lbl_bh_pnr.text = "Pulse drive offline · turn away now"
	else:
		lbl_bh_pnr.text = "Distance %s · stay clear" % fmt_dist(w.bh_dist)


func _hint(w: World) -> String:
	var ship := w.ship
	if Game.state == Game.State.WARP:
		return ""
	if w.on_foot:
		var d := 1e9
		if w.player.frame == ship.frame and ship.frame != null:
			d = (ship.lpos - w.player.lpos).length()
		var near_res := ""
		if w.props_mgr != null and w.props_mgr.has_method("harvest_hint"):
			near_res = w.props_mgr.harvest_hint()
		if near_res != "":
			return near_res
		if d < 9.0:
			return "[E] Board ship"
		if w.player.protection < 30.0 and w.player.frame.data.hazard != "":
			return "[R] Recharge hazard protection (uses a mined resource)"
		if w.player.fuel < 10.0:
			return "Jetpack empty — recharges on the ground"
		return "WASD walk · SHIFT sprint · SPACE jump / hold for jetpack · LMB mine · Q scan · V camera"
	if ship.is_landed:
		return "[F] Exit ship    [SPACE] Take off    [L] retract gear"
	if ship.gear_down:
		return "LANDING MODE — ship descends automatically · SPACE lift · CTRL lower · WASD adjust · [L] retract"
	if ship.frame != null and ship.alt < 1500.0:
		return "[L] Deploy landing gear to land"
	if w.bh != null and w.bh_zone > 0:
		return ""
	if ship.pulse_spool > 0.3:
		return "Pulse drive spooling down automatically near gravity wells"
	if ship.frame == null and ship.alt > 30000.0:
		return "[SPACE] Pulse drive   [T] Target planet   [M] Galaxy map   [SHIFT] Boost"
	return "W/S throttle · mouse steer · Q/E roll · SHIFT boost · [L] landing gear"


func _update_markers(w: World) -> void:
	var list: Array = []
	var cp := w.cam.global_position
	var vs := get_viewport().get_visible_rect().size
	var lim := 200000.0
	var add_body := func(b: Body, col: Color, label: String, big: bool) -> void:
		var pos := b.global_position
		var dist := (pos - cp).length() - b.radius
		if dist > lim * 40.0 or dist < b.radius * 0.0:
			return
		var s := w.project(pos)
		list.append({"p": Vector2(s.x, s.y), "vis": s.z > 0.5, "label": label, "dist": maxf(dist, 0.0), "col": col, "big": big,
			"target": b == w.ship.target_body, "dir": (pos - cp).normalized()})
	for b: Body in w.bodies:
		var col := CYAN
		if b.data != null:
			col = Color(0.8, 0.9, 1.0)
		var near := (b.global_position - cp).length() - b.radius
		if near < b.radius * 0.6 and not w.on_foot and b.data != null:
			continue
		if w.on_foot and (near < b.radius * 8.0 or b != w.ship.target_body):
			continue
		add_body.call(b, col, b.display_name, b == w.ship.target_body)
	for st in w.stations:
		if not w.on_foot or st == w.ship.target_body:
			add_body.call(st, Color(0.5, 1.0, 0.8), st.display_name, false)
	if not w.on_foot:
		add_body.call(w.star, Color(1.0, 0.85, 0.4), w.star_info.name, false)
	if w.bh != null and not w.on_foot:
		add_body.call(w.bh, Color(0.9, 0.4, 1.0), "SINGULARITY", true)
	if w.on_foot and w.ship.frame != null:
		var sp := w.project(w.ship.global_position)
		list.append({"p": Vector2(sp.x, sp.y), "vis": sp.z > 0.5, "label": "SHIP", "dist": w.ship.global_position.length(), "col": GREEN, "big": false, "target": false, "dir": w.ship.global_position.normalized()})
	if w.props_mgr != null and w.props_mgr.has_method("poi_markers"):
		for m in w.props_mgr.poi_markers(w):
			list.append(m)
	nav.items = list
	nav.vsize = vs
	nav.queue_redraw()


# ---------------------------------------------------------------- inner classes
class CrossHair extends Control:
	var ship_mode := true

	func _draw() -> void:
		var c := Color(0.8, 0.97, 1.0, 0.8)
		if ship_mode:
			draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.55), 1.5)
			draw_circle(Vector2.ZERO, 1.8, c)
			for a in [0.0, PI / 2, PI, PI * 1.5]:
				var d := Vector2(cos(a), sin(a))
				draw_line(d * 20.0, d * 28.0, Color(c.r, c.g, c.b, 0.6), 1.5)
		else:
			draw_circle(Vector2.ZERO, 2.0, c)
			draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, Color(c.r, c.g, c.b, 0.35), 1.0)


class NavOverlay extends Control:
	var items: Array = []
	var vsize := Vector2(1280, 720)

	func _fmt(m: float) -> String:
		if m < 1000.0:
			return "%d m" % int(m)
		if m < 100000.0:
			return "%.1f km" % (m / 1000.0)
		return "%d km" % int(m / 1000.0)

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var centre := vsize * 0.5
		for it in items:
			var col: Color = it.col
			var p: Vector2 = it.p
			var on_screen: bool = it.vis and p.x > 30 and p.x < vsize.x - 30 and p.y > 30 and p.y < vsize.y - 30
			var is_target: bool = it.target
			if on_screen:
				var r := 9.0 if not it.big else 12.0
				if is_target:
					r = 15.0
					var bl := 5.0
					draw_line(p + Vector2(-r, -r), p + Vector2(-r + bl, -r), col, 2.0)
					draw_line(p + Vector2(-r, -r), p + Vector2(-r, -r + bl), col, 2.0)
					draw_line(p + Vector2(r, -r), p + Vector2(r - bl, -r), col, 2.0)
					draw_line(p + Vector2(r, -r), p + Vector2(r, -r + bl), col, 2.0)
					draw_line(p + Vector2(-r, r), p + Vector2(-r + bl, r), col, 2.0)
					draw_line(p + Vector2(-r, r), p + Vector2(-r, r - bl), col, 2.0)
					draw_line(p + Vector2(r, r), p + Vector2(r - bl, r), col, 2.0)
					draw_line(p + Vector2(r, r), p + Vector2(r, r - bl), col, 2.0)
				var pts := PackedVector2Array([p + Vector2(0, -r * 0.6), p + Vector2(r * 0.6, 0), p + Vector2(0, r * 0.6), p + Vector2(-r * 0.6, 0), p + Vector2(0, -r * 0.6)])
				draw_polyline(pts, col, 1.5)
				var txt: String = "%s  %s" % [it.label, _fmt(it.dist)]
				draw_string(font, p + Vector2(r + 6, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.8))
				draw_string(font, p + Vector2(r + 5, 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
			elif is_target:
				# off-screen arrow for the target only
				var d: Vector2 = p - centre
				if not it.vis:
					d = -d
				d = d.normalized()
				var e := centre + d * (minf(vsize.x, vsize.y) * 0.42)
				var perp := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([e + d * 14, e - d * 8 + perp * 9, e - d * 8 - perp * 9]), col)
				draw_string(font, e - d * 30 - Vector2(30, -4), it.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
