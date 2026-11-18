class_name Hud
extends CanvasLayer
## In-game HUD: location, ship / suit status, hints, message banner, world markers, black-hole warnings, screen FX.

const OVERLAY_SHADER := preload("res://shaders/overlay.gdshader")
const COL_MAIN := Color(0.62, 0.9, 1.0)
const COL_WARN := Color(1.0, 0.75, 0.25)
const COL_BAD := Color(1.0, 0.3, 0.25)
const COL_OK := Color(0.5, 1.0, 0.6)


class Bar extends Control:
	var value: float = 1.0
	var title: String = ""
	var color: Color = Color(0.5, 0.9, 1.0)
	var text: String = ""

	func _init() -> void:
		custom_minimum_size = Vector2(230, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
		draw_rect(Rect2(Vector2(2, 2), Vector2((size.x - 4) * clampf(value, 0.0, 1.0), size.y - 4)), Color(color.r, color.g, color.b, 0.85))
		draw_rect(Rect2(Vector2.ZERO, size), Color(color.r, color.g, color.b, 0.5), false, 1.0)
		draw_string(f, Vector2(8, size.y - 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.95))
		if text != "":
			draw_string(f, Vector2(0, size.y - 5), text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 12, Color(1, 1, 1, 0.95))


class Markers extends Control:
	var items: Array = []
	var crosshair_mode: int = 0  # 0 none, 1 foot, 2 ship
	var reticle_pos: Vector2 = Vector2.ZERO
	var mining: float = 0.0
	var velocity_marker: Variant = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var c := size * 0.5
		for it in items:
			var p: Vector2 = it["p"]
			var col: Color = it["col"]
			var shape: String = it.get("shape", "diamond")
			var s: float = it.get("s", 7.0)
			var off := p.clamp(Vector2(30, 30), size - Vector2(30, 30))
			var edge: bool = it.get("edge", false) and (p != off)
			if p != off and not edge:
				continue
			if edge:
				p = off
			match shape:
				"diamond":
					draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), Color(col.r, col.g, col.b, 0.25))
					draw_polyline(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0), p + Vector2(0, -s)]), col, 1.5)
				"circle":
					draw_arc(p, s, 0, TAU, 24, col, 1.5)
				"ring":
					draw_arc(p, s, 0, TAU, 32, col, 2.0)
					draw_arc(p, s * 0.55, 0, TAU, 24, Color(col.r, col.g, col.b, 0.6), 1.2)
				"tri":
					draw_colored_polygon(PackedVector2Array([p + Vector2(0, s), p + Vector2(-s, -s * 0.7), p + Vector2(s, -s * 0.7)]), Color(col.r, col.g, col.b, 0.7))
			var txt: String = it.get("text", "")
			if txt != "":
				draw_string(f, p + Vector2(s + 6, 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
			var sub: String = it.get("sub", "")
			if sub != "":
				draw_string(f, p + Vector2(s + 6, 19), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col.r, col.g, col.b, 0.75))
		# crosshair
		if crosshair_mode == 1:
			draw_circle(c, 2.0, Color(1, 1, 1, 0.8))
			draw_arc(c, 9.0, 0, TAU, 24, Color(1, 1, 1, 0.35), 1.2)
			if mining > 0.0:
				draw_arc(c, 14.0, -PI / 2, -PI / 2 + TAU * mining, 32, Color(0.4, 0.95, 1.0, 0.95), 3.0)
		elif crosshair_mode == 2:
			draw_arc(c, 16.0, 0, TAU, 32, Color(0.7, 0.95, 1.0, 0.55), 1.5)
			draw_line(c + Vector2(-26, 0), c + Vector2(-12, 0), Color(0.7, 0.95, 1.0, 0.6), 1.5)
			draw_line(c + Vector2(26, 0), c + Vector2(12, 0), Color(0.7, 0.95, 1.0, 0.6), 1.5)
			draw_line(c + Vector2(0, 12), c + Vector2(0, 22), Color(0.7, 0.95, 1.0, 0.6), 1.5)
			draw_circle(c, 1.8, Color(0.7, 0.95, 1.0, 0.9))
		if velocity_marker != null:
			var vp: Vector2 = velocity_marker
			draw_arc(vp, 8.0, 0, TAU, 20, Color(0.5, 1.0, 0.6, 0.9), 1.6)
			draw_line(vp + Vector2(-14, 0), vp + Vector2(-8, 0), Color(0.5, 1.0, 0.6, 0.9), 1.6)
			draw_line(vp + Vector2(14, 0), vp + Vector2(8, 0), Color(0.5, 1.0, 0.6, 0.9), 1.6)
			draw_line(vp + Vector2(0, -14), vp + Vector2(0, -8), Color(0.5, 1.0, 0.6, 0.9), 1.6)


var root: Control
var markers: Markers
var overlay: ColorRect
var overlay_mat: ShaderMaterial
var loc_label: Label
var sub_label: Label
var time_label: Label
var hint_label: Label
var banner: Label
var alert_label: Label
var alert_sub: Label
var speed_label: Label
var speed_sub: Label
var info_box: VBoxContainer
var bar_a: Bar
var bar_b: Bar
var bar_c: Bar
var bar_d: Bar
var inv_label: Label
var warn_panel: Control
var bh_label: Label
var fps_label: Label
var _msg_t: float = 0.0
var _msgs: Array = []
var flash: float = 0.0
var flash_col: Color = Color(1, 0.1, 0.05)
var fade: float = 0.0
var fade_col: Color = Color.BLACK
var tunnel: float = 0.0
var warp: float = 0.0
var bh_fx: float = 0.0
var heat_fx: float = 0.0
var underwater: float = 0.0
var show_fps: bool = false


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_mat = ShaderMaterial.new()
	overlay_mat.shader = OVERLAY_SHADER
	overlay.material = overlay_mat
	root.add_child(overlay)
	markers = Markers.new()
	root.add_child(markers)

	# top-left: location block
	var tl := VBoxContainer.new()
	tl.position = Vector2(24, 18)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	loc_label = _label(tl, 22, COL_MAIN)
	sub_label = _label(tl, 14, Color(0.75, 0.85, 0.95))
	time_label = _label(tl, 14, Color(0.75, 0.85, 0.95))

	# bottom-left: status bars
	info_box = VBoxContainer.new()
	info_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info_box.position = Vector2(24, -170)
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_theme_constant_override("separation", 4)
	root.add_child(info_box)
	bar_a = _bar(info_box)
	bar_b = _bar(info_box)
	bar_c = _bar(info_box)
	bar_d = _bar(info_box)
	inv_label = _label(info_box, 13, Color(0.85, 0.95, 1.0))

	# bottom centre: speed + hint
	var bc := VBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bc.position = Vector2(-200, -135)
	bc.custom_minimum_size = Vector2(400, 0)
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bc)
	speed_label = _label(bc, 30, Color(0.85, 0.97, 1.0))
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_sub = _label(bc, 14, Color(0.7, 0.85, 0.95))
	speed_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label = _label(bc, 17, Color(1, 1, 1))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint_label.add_theme_constant_override("outline_size", 5)

	# banner
	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-400, 90)
	banner.custom_minimum_size = Vector2(800, 0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 24)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner.add_theme_constant_override("outline_size", 6)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)

	# black-hole alert
	alert_label = Label.new()
	alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_label.position = Vector2(-450, 150)
	alert_label.custom_minimum_size = Vector2(900, 0)
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.add_theme_font_size_override("font_size", 34)
	alert_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	alert_label.add_theme_constant_override("outline_size", 8)
	alert_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(alert_label)
	alert_sub = Label.new()
	alert_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_sub.position = Vector2(-450, 196)
	alert_sub.custom_minimum_size = Vector2(900, 0)
	alert_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_sub.add_theme_font_size_override("font_size", 17)
	alert_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	alert_sub.add_theme_constant_override("outline_size", 5)
	alert_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(alert_sub)

	fps_label = Label.new()
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.position = Vector2(-120, 10)
	fps_label.add_theme_font_size_override("font_size", 13)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fps_label)


func _label(parent: Control, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Control) -> Bar:
	var b := Bar.new()
	parent.add_child(b)
	return b


func show_message(text: String, level: int = 0) -> void:
	_msgs.append([text, level])
	if _msgs.size() > 4:
		_msgs.pop_front()
	if _msg_t <= 0.0:
		_next_message()


func _next_message() -> void:
	if _msgs.is_empty():
		banner.text = ""
		return
	var m: Array = _msgs.pop_front()
	banner.text = m[0]
	banner.add_theme_color_override("font_color", [COL_MAIN, COL_WARN, COL_BAD][m[1]])
	_msg_t = 3.2


func set_visible_hud(v: bool) -> void:
	root.visible = v


func process_fx(dt: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= dt
		banner.modulate.a = clampf(_msg_t / 0.6, 0.0, 1.0)
		if _msg_t <= 0.0:
			_next_message()
	flash = maxf(flash - dt * 2.5, 0.0)
	overlay_mat.set_shader_parameter("heat", heat_fx)
	overlay_mat.set_shader_parameter("warp", warp)
	overlay_mat.set_shader_parameter("tunnel", tunnel)
	overlay_mat.set_shader_parameter("bh", bh_fx)
	overlay_mat.set_shader_parameter("flash", flash)
	overlay_mat.set_shader_parameter("flash_col", flash_col)
	overlay_mat.set_shader_parameter("fade", fade)
	overlay_mat.set_shader_parameter("fade_col", fade_col)
	overlay_mat.set_shader_parameter("underwater", underwater)
	overlay.visible = heat_fx > 0.001 or warp > 0.001 or tunnel > 0.001 or bh_fx > 0.001 or flash > 0.001 or fade > 0.001 or underwater > 0.001
	if show_fps:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	else:
		fps_label.text = ""


func hit_flash(col: Color = Color(1, 0.1, 0.05), amount: float = 0.45) -> void:
	flash = amount
	flash_col = col


# ------------------------------------------------------------------ per-frame content
func update_ship(s: Dictionary) -> void:
	loc_label.text = s["loc"]
	sub_label.text = s["sub"]
	time_label.text = s["time"]
	bar_a.title = "HULL"
	bar_a.value = s["hull"] / 100.0
	bar_a.color = COL_OK if s["hull"] > 40.0 else COL_BAD
	bar_a.text = "%d%%" % int(s["hull"])
	bar_b.title = "SHIELD"
	bar_b.value = s["shield"] / 100.0
	bar_b.color = COL_MAIN
	bar_b.text = "%d%%" % int(s["shield"])
	bar_c.title = "THROTTLE"
	bar_c.value = s["throttle"]
	bar_c.color = COL_WARN if s["boost"] else (Color(0.7, 0.6, 1.0) if s["pulse"] else COL_MAIN)
	bar_c.text = "PULSE" if s["pulse"] else ("BOOST" if s["boost"] else "%d%%" % int(s["throttle"] * 100.0))
	bar_d.visible = false
	inv_label.text = s.get("inv", "")
	var sp: float = s["speed"]
	speed_label.text = ("%.1f km/s" % (sp / 1000.0)) if sp > 1500.0 else ("%d m/s" % int(sp))
	speed_sub.text = s["alt_text"]
	hint_label.text = s["hint"]
	for b in [bar_a, bar_b, bar_c]:
		b.queue_redraw()
	markers.crosshair_mode = 2
	markers.mining = 0.0


func update_foot(s: Dictionary) -> void:
	loc_label.text = s["loc"]
	sub_label.text = s["sub"]
	time_label.text = s["time"]
	bar_a.title = "HEALTH"
	bar_a.value = s["health"] / 100.0
	bar_a.color = COL_OK if s["health"] > 40.0 else COL_BAD
	bar_a.text = "%d" % int(s["health"])
	bar_b.title = "HAZARD PROTECTION  (%d°C)" % int(s["temp"])
	bar_b.value = s["protection"] / 100.0
	bar_b.color = COL_WARN if s["protection"] > 30.0 else COL_BAD
	bar_b.text = "%d%%" % int(s["protection"])
	bar_c.title = "JETPACK"
	bar_c.value = s["jet"] / 100.0
	bar_c.color = COL_MAIN
	bar_c.text = ""
	bar_d.visible = false
	inv_label.text = s["inv"]
	speed_label.text = ""
	speed_sub.text = s.get("alt_text", "")
	hint_label.text = s["hint"]
	for b in [bar_a, bar_b, bar_c]:
		b.queue_redraw()
	markers.crosshair_mode = 1
	markers.mining = s.get("mining", 0.0)


func update_markers(items: Array, vel_marker: Variant = null) -> void:
	markers.items = items
	markers.velocity_marker = vel_marker
	markers.queue_redraw()


func set_alert(title: String, sub: String, col: Color, pulse_t: float) -> void:
	alert_label.text = title
	alert_sub.text = sub
	var a := 0.55 + 0.45 * sin(pulse_t * 8.0) if title != "" else 0.0
	alert_label.add_theme_color_override("font_color", col)
	alert_sub.add_theme_color_override("font_color", Color(col.r, col.g, col.b).lightened(0.3))
	alert_label.modulate.a = a
	alert_sub.modulate.a = 1.0 if title != "" else 0.0
