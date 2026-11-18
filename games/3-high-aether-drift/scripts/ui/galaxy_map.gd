class_name GalaxyMap
extends Control
## Galaxy map (spiral of procedural stars) and live local-system orbit view.

signal warp_requested(star_id: int)
signal closed()

const CLASS_COL := {
	"O": Color(0.6, 0.7, 1.0), "B": Color(0.7, 0.8, 1.0), "A": Color(0.9, 0.93, 1.0), "F": Color(1.0, 0.97, 0.85),
	"G": Color(1.0, 0.9, 0.55), "K": Color(1.0, 0.7, 0.4), "M": Color(1.0, 0.45, 0.3),
}
const BIOME_COL := {
	"lush": Color(0.4, 0.85, 0.4), "desert": Color(0.95, 0.7, 0.35), "frozen": Color(0.75, 0.9, 1.0), "volcanic": Color(1.0, 0.4, 0.2),
	"toxic": Color(0.7, 0.95, 0.3), "barren": Color(0.7, 0.7, 0.7), "gas": Color(0.9, 0.75, 0.5),
}

var galaxy: Galaxy
var uni: Universe
var current_id: int = 0
var selected: int = -1
var hovered: int = -1
var zoom: float = 0.0125  # px per light year
var center_ly: Vector2 = Vector2.ZERO
var mode: int = 0  # 0 galaxy, 1 system
var warp_ok: bool = false
var warp_reason: String = ""
var _dragging: bool = false
var _warp_btn: Button
var _mode_btn: Button
var _close_btn: Button
var _t: float = 0.0
var sys_zoom: float = 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_warp_btn = _mk_button("WARP  [Enter]", Vector2(0, 0), func(): _do_warp())
	_mode_btn = _mk_button("SYSTEM VIEW  [Tab]", Vector2(0, 0), func(): _toggle_mode())
	_close_btn = _mk_button("CLOSE  [M]", Vector2(0, 0), func(): closed.emit())
	visible = false


func _mk_button(t: String, p: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(190, 38)
	b.add_theme_font_size_override("font_size", 16)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.06, 0.12, 0.18, 0.92)
	n.border_color = Color(0.35, 0.75, 1.0, 0.8)
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.12, 0.3, 0.45, 0.95)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("focus", n)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	add_child(b)
	return b


func open(g: Galaxy, u: Universe, cur: int, can_warp: bool, reason: String) -> void:
	galaxy = g
	uni = u
	current_id = cur
	warp_ok = can_warp
	warp_reason = reason
	if selected < 0:
		selected = cur
	visible = true
	mode = 0
	center_ly = Vector2(0, 0)
	zoom = 0.0125
	_layout()


func _layout() -> void:
	size = get_viewport().get_visible_rect().size
	var s := size
	_warp_btn.position = Vector2(s.x - 230, s.y - 70)
	_mode_btn.position = Vector2(s.x - 230, s.y - 120)
	_close_btn.position = Vector2(s.x - 230, 20)
	_mode_btn.text = "GALAXY VIEW  [Tab]" if mode == 1 else "SYSTEM VIEW  [Tab]"


func _toggle_mode() -> void:
	mode = 1 - mode
	_layout()


func _do_warp() -> void:
	if selected < 0 or selected == current_id:
		return
	if warp_ok:
		warp_requested.emit(selected)


func _to_screen(p: Vector3) -> Vector2:
	return size * 0.5 + (Vector2(p.x, p.z) - center_ly) * zoom


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	size = get_viewport().get_visible_rect().size
	_warp_btn.disabled = not (warp_ok and selected >= 0 and selected != current_id)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if mode == 0:
		if event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if _dragging:
				center_ly -= mm.relative / zoom
			else:
				hovered = _pick(mm.position)
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				_zoom_at(mb.position, 1.18)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				_zoom_at(mb.position, 1.0 / 1.18)
			elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
				_dragging = mb.pressed
			elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var p := _pick(mb.position)
				if p >= 0:
					selected = p
					if mb.double_click:
						_do_warp()
	else:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			var mb2 := event as InputEventMouseButton
			if mb2.button_index == MOUSE_BUTTON_WHEEL_UP:
				sys_zoom = clampf(sys_zoom * 1.2, 0.3, 40.0)
			elif mb2.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				sys_zoom = clampf(sys_zoom / 1.2, 0.3, 40.0)


func _zoom_at(mp: Vector2, f: float) -> void:
	var before := center_ly + (mp - size * 0.5) / zoom
	zoom = clampf(zoom * f, 0.004, 0.4)
	var after := center_ly + (mp - size * 0.5) / zoom
	center_ly += before - after


func _pick(mp: Vector2) -> int:
	var best := -1
	var bd := 14.0
	for st in galaxy.stars:
		var d := _to_screen(st["pos"]).distance_to(mp)
		if d < bd:
			bd = d
			best = st["id"]
	return best


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_TAB:
				_toggle_mode()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_do_warp()
				get_viewport().set_input_as_handled()


func _draw() -> void:
	if galaxy == null:
		return
	var f := ThemeDB.fallback_font
	_layout()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.04, 0.985))
	draw_string(f, Vector2(30, 46), "GALAXY MAP" if mode == 0 else "SYSTEM MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.85, 0.96, 1.0))
	if mode == 0:
		_draw_galaxy(f)
	else:
		_draw_system(f)


func _draw_galaxy(f: Font) -> void:
	var c0 := _to_screen(Vector3.ZERO)
	# soft galactic glow
	for i in 14:
		var r := (50000.0 * (1.0 - i / 14.0)) * zoom
		draw_circle(c0, r, Color(0.25, 0.3, 0.6, 0.025))
	draw_circle(c0, 3500.0 * zoom, Color(1.0, 0.85, 0.5, 0.06))
	for st in galaxy.stars:
		var p := _to_screen(st["pos"])
		if p.x < -20 or p.y < -20 or p.x > size.x + 20 or p.y > size.y + 20:
			continue
		var col: Color = CLASS_COL[st["cls"]]
		var r := clampf(1.6 + zoom * 120.0, 1.6, 4.5)
		draw_circle(p, r, col)
		if st["bh"]:
			draw_arc(p, r + 3.5, 0, TAU, 16, Color(1.0, 0.45, 0.2, 0.85), 1.3)
	# black hole links
	for st in galaxy.stars:
		if st["bh"] and st["id"] == current_id:
			var q := _to_screen(galaxy.stars[st["bh_dest"]]["pos"])
			var p2 := _to_screen(st["pos"])
			draw_dashed_line(p2, q, Color(1.0, 0.5, 0.2, 0.7), 1.5, 6.0)
	# markers
	var cp := _to_screen(galaxy.stars[current_id]["pos"])
	draw_arc(cp, 11.0, 0, TAU, 28, Color(0.5, 1.0, 0.6), 2.0)
	draw_string(f, cp + Vector2(14, -10), "YOU ARE HERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 1.0, 0.6))
	if selected >= 0:
		var sp := _to_screen(galaxy.stars[selected]["pos"])
		draw_arc(sp, 14.0 + 2.0 * sin(_t * 4.0), 0, TAU, 28, Color(0.5, 0.85, 1.0), 2.0)
	if hovered >= 0:
		var hp := _to_screen(galaxy.stars[hovered]["pos"])
		var st2: Dictionary = galaxy.stars[hovered]
		draw_string(f, hp + Vector2(12, 16), "%s  (class %s)" % [st2["name"], st2["cls"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))
	# info panel
	var px := 30.0
	var py := size.y - 330.0
	draw_rect(Rect2(px - 10, py - 12, 440, 320), Color(0.03, 0.07, 0.12, 0.85))
	draw_rect(Rect2(px - 10, py - 12, 440, 320), Color(0.35, 0.7, 0.9, 0.5), false, 1.0)
	if selected >= 0:
		var st: Dictionary = galaxy.stars[selected]
		var sys := galaxy.get_system(selected)
		var d := galaxy.distance_ly(current_id, selected)
		draw_string(f, Vector2(px, py + 14), st["name"] + ("  (current system)" if selected == current_id else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CLASS_COL[st["cls"]])
		draw_string(f, Vector2(px, py + 40), "Class %s star   ·   %s ly away" % [st["cls"], str(int(d)).insert(max(str(int(d)).length() - 3, 0), ",") if d >= 1000.0 else str(int(d))], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.9, 1))
		var y := py + 68.0
		var np := 0
		for b in sys.bodies:
			var pd: PlanetData = b
			if y > py + 290:
				break
			var bc: Color = BIOME_COL.get(pd.biome, Color.WHITE)
			draw_circle(Vector2(px + 6, y - 5), 4.0, bc)
			var tag := (" moon" if pd.kind == "moon" else ("" if pd.kind == "gas" else " planet"))
			draw_string(f, Vector2(px + 18, y), "%s  -  %s%s" % [pd.name, Biomes.BIOME_NAMES[pd.biome], tag], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.95, 1))
			y += 20.0
			np += 1
		if st["bh"]:
			draw_string(f, Vector2(px, py + 300), "BLACK HOLE detected  ->  leads to %s" % galaxy.stars[st["bh_dest"]]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.55, 0.25))
	var msg := ""
	if selected == current_id:
		msg = "Select another star to warp to it."
	elif not warp_ok:
		msg = warp_reason
	else:
		msg = "Hyperdrive ready - press Enter / double-click to warp."
	draw_string(f, Vector2(size.x - 560, size.y - 18), msg, HORIZONTAL_ALIGNMENT_RIGHT, 520, 15, Color(0.7, 0.9, 1.0) if warp_ok else Color(1.0, 0.7, 0.4))
	draw_string(f, Vector2(30, size.y - 350 - 12 if false else 74), "Wheel: zoom   ·   Right-drag: pan   ·   Click: select   ·   Double-click: warp   ·   Tab: system view", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.75, 0.85))


func _draw_system(f: Font) -> void:
	if uni == null or uni.system == null:
		return
	var c := size * 0.5 + Vector2(0, 10)
	var max_r := 1.0
	for b in uni.bodies:
		if b.data.parent < 0:
			max_r = maxf(max_r, b.data.orbit_r)
	if uni.bh:
		max_r = maxf(max_r, (uni.bh.upos[0] as float) * 0.0 + Vector2(uni.bh.upos[0], uni.bh.upos[2]).length())
	var sc := (minf(size.x, size.y) * 0.44) / max_r * sys_zoom
	draw_circle(c, 9.0, uni.system.star_color)
	draw_arc(c, 14.0, 0, TAU, 24, Color(uni.system.star_color.r, uni.system.star_color.g, uni.system.star_color.b, 0.4), 2.0)
	draw_string(f, c + Vector2(14, -12), uni.system.name + " (class %s)" % uni.system.star_class, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.8))
	for b in uni.bodies:
		var pb: PlanetBody = b
		var d: PlanetData = pb.data
		var pos2 := Vector2(pb.upos[0], pb.upos[2])
		var parent_pos := Vector2.ZERO
		if d.parent >= 0:
			var pp: PlanetBody = uni.bodies[d.parent]
			parent_pos = Vector2(pp.upos[0], pp.upos[2])
		var oc := c + parent_pos * sc
		draw_arc(oc, d.orbit_r * sc, 0, TAU, 96, Color(0.4, 0.6, 0.8, 0.18 if d.parent < 0 else 0.3), 1.0)
		var p := c + pos2 * sc
		var col: Color = BIOME_COL.get(d.biome, Color.WHITE)
		var rr := clampf(d.radius * sc * 0.55, 3.0, 12.0) if d.kind != "gas" else clampf(d.radius * sc * 0.4, 6.0, 16.0)
		draw_circle(p, rr, col)
		if d.rings:
			draw_arc(p, rr * 1.8, 0.0, TAU, 24, Color(0.9, 0.8, 0.6, 0.6), 1.5)
		if d.kind != "moon" or sys_zoom > 4.0:
			draw_string(f, p + Vector2(rr + 5, 4), "%s  [%s]" % [d.name, Biomes.BIOME_NAMES[d.biome]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	if uni.bh:
		var bp := c + Vector2(uni.bh.upos[0], uni.bh.upos[2]) * sc
		draw_circle(bp, 7.0, Color(0, 0, 0))
		draw_arc(bp, 9.0, 0, TAU, 24, Color(1.0, 0.55, 0.2), 2.0)
		draw_arc(bp, 13.0, 0, TAU, 24, Color(1.0, 0.55, 0.2, 0.45), 1.0)
		draw_string(f, bp + Vector2(16, 4), "BLACK HOLE: " + uni.bh.bh_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.6, 0.3))
	# ship marker
	if uni.has_meta("ship_upos"):
		var su: Array = uni.get_meta("ship_upos")
		var sp := c + Vector2(su[0], su[2]) * sc
		draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -7), sp + Vector2(6, 6), sp + Vector2(-6, 6)]), Color(0.5, 1.0, 0.6))
		draw_string(f, sp + Vector2(10, 4), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 1.0, 0.6))
	draw_string(f, Vector2(30, 74), "Wheel: zoom   ·   Positions update live   ·   Tab: galaxy view", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.75, 0.85))
