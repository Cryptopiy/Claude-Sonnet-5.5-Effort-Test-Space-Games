class_name Hud
extends Control
## All 2D UI: flight/foot HUD (custom drawn), main menu, pause menu and controls overview.

signal start_pressed
signal resume_pressed
signal quit_pressed
signal menu_pressed

var d: Dictionary = {}
var font: Font
var main_menu: Control
var pause_menu: Control
var controls_panel: Control
var controls_from: Control
var t := 0.0

const CONTROLS := [
	["SHIP", ""],
	["Mouse", "Pitch / yaw"],
	["W / S", "Throttle forward / reverse"],
	["A / D", "Roll left / right"],
	["Space / Ctrl", "Vertical thrusters up / down (landing, take-off)"],
	["Shift", "Boost"],
	["F", "Toggle pulse drive (fast interplanetary cruise)"],
	["V", "Chase / cockpit camera"],
	["E", "Exit ship (when landed)"],
	["M / Tab", "Galaxy map (Enter = hyperjump to selected star)"],
	["ON FOOT", ""],
	["W A S D", "Walk"],
	["Shift", "Sprint"],
	["Space", "Jump (hold in air for jetpack)"],
	["E", "Collect resource / use beacon / board ship"],
	["F", "Scanner pulse (reveals points of interest)"],
	["V", "First / third person camera"],
	["GENERAL", ""],
	["Esc", "Pause menu"],
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	_build_menus()

func _style_btn(b: Button) -> void:
	b.custom_minimum_size = Vector2(300, 46)
	b.add_theme_font_size_override("font_size", 22)

func _panel(title: String, sub: String) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.03, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(box)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var l2 := Label.new()
	l2.text = sub
	l2.add_theme_font_size_override("font_size", 18)
	l2.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l2)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 24)
	box.add_child(sp)
	root.set_meta("box", box)
	return root

func _btn(root: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	_style_btn(b)
	b.pressed.connect(cb)
	(root.get_meta("box") as VBoxContainer).add_child(b)

func _build_menus() -> void:
	main_menu = _panel("S O L A C E", "A procedural voyage between the stars")
	_btn(main_menu, "Begin Journey", func(): start_pressed.emit())
	_btn(main_menu, "Controls", func(): _show_controls(main_menu))
	_btn(main_menu, "Quit", func(): quit_pressed.emit())
	add_child(main_menu)
	pause_menu = _panel("PAUSED", "")
	_btn(pause_menu, "Resume", func(): resume_pressed.emit())
	_btn(pause_menu, "Controls", func(): _show_controls(pause_menu))
	_btn(pause_menu, "Main Menu", func(): menu_pressed.emit())
	_btn(pause_menu, "Quit", func(): quit_pressed.emit())
	pause_menu.visible = false
	add_child(pause_menu)
	controls_panel = _panel("CONTROLS", "Keyboard & mouse")
	var box: VBoxContainer = controls_panel.get_meta("box")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 2)
	for row in CONTROLS:
		var a := Label.new()
		var b := Label.new()
		a.text = row[0]
		b.text = row[1]
		if row[1] == "":
			a.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
			a.add_theme_font_size_override("font_size", 18)
		else:
			a.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.custom_minimum_size = Vector2(160, 0)
		grid.add_child(a)
		grid.add_child(b)
	box.add_child(grid)
	_btn(controls_panel, "Back", func(): _hide_controls())
	controls_panel.visible = false
	add_child(controls_panel)

func _show_controls(from: Control) -> void:
	controls_from = from
	from.visible = false
	controls_panel.visible = true

func _hide_controls() -> void:
	controls_panel.visible = false
	if controls_from:
		controls_from.visible = true

func show_menu(kind: String) -> void:
	main_menu.visible = kind == "main"
	pause_menu.visible = kind == "pause"
	controls_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE if kind == "" else Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	t += delta
	size = get_viewport().get_visible_rect().size
	queue_redraw()

func _txt(p: Vector2, s: String, size := 16, col := Color(0.8, 0.92, 1.0), align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var q := p
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		q.x -= w * (0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 1.0)
	draw_string(font, q + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7))
	draw_string(font, q, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _bar(p: Vector2, w: float, v: float, col: Color, label: String) -> void:
	draw_rect(Rect2(p, Vector2(w, 9)), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(p, Vector2(w * clampf(v, 0, 1), 9)), col)
	draw_rect(Rect2(p, Vector2(w, 9)), Color(1, 1, 1, 0.35), false, 1.0)
	_txt(p + Vector2(-60, 9), label, 12, Color(0.8, 0.9, 1.0, 0.9))

func _draw() -> void:
	if d.is_empty() or not d.get("show", false):
		return
	var sz := size
	# flare
	if d.has("flare") and d["flare"].z > 0.0:
		var f: Vector3 = d["flare"]
		var c: Color = d.get("flare_col", Color(1, 0.9, 0.7))
		var ctr := Vector2(f.x, f.y)
		for i in 7:
			var rr := (14.0 + i * 20.0) * f.z
			draw_circle(ctr, rr, Color(c.r, c.g, c.b, 0.045 * f.z))
		var dir := (sz * 0.5 - ctr)
		for k in 4:
			var pp := ctr + dir * (0.5 + k * 0.45)
			draw_circle(pp, 10.0 + k * 9.0, Color(c.r, c.g * 0.8, c.b * 0.8, 0.05 * f.z))
		draw_line(ctr - Vector2(160, 0) * f.z, ctr + Vector2(160, 0) * f.z, Color(c.r, c.g, c.b, 0.25 * f.z), 1.5)
	# top left info
	_txt(Vector2(24, 34), d.get("sys_name", ""), 20, Color(1.0, 0.85, 0.5))
	_txt(Vector2(24, 58), d.get("loc_name", ""), 26, Color(0.9, 0.97, 1.0))
	_txt(Vector2(24, 80), d.get("loc_sub", ""), 15, Color(0.6, 0.8, 1.0))
	if d.get("on_planet", false):
		_txt(Vector2(24, 102), "Gravity %.1f m/s²   Hazard: %s" % [d.get("gravity", 9.8), d.get("hazard", "none")], 14, Color(0.9, 0.85, 0.6))
		_txt(Vector2(24, 120), "Time of day: %s" % d.get("daytime", ""), 14, Color(0.7, 0.85, 1.0))
	# inventory top right
	var inv: Dictionary = d.get("inv", {})
	var y := 34.0
	_txt(Vector2(sz.x - 24, y), "INVENTORY", 14, Color(1.0, 0.85, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
	for k in inv.keys():
		y += 20
		_txt(Vector2(sz.x - 24, y), "%s  x%d" % [k, inv[k]], 15, Color(0.85, 0.95, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	y += 26
	_txt(Vector2(sz.x - 24, y), "Units %d" % d.get("units", 0), 14, Color(0.6, 1.0, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	# markers
	for m in d.get("markers", []):
		var p: Vector2 = m["pos"]
		var col: Color = m.get("col", Color(0.6, 0.9, 1.0))
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), col, false, 1.5)
		_txt(p + Vector2(10, -2), m["text"], 13, col)
	# crosshair
	var c0 := sz * 0.5
	if d.get("mode", "") == "ship":
		draw_arc(c0, 7.0, 0, TAU, 24, Color(0.8, 0.95, 1.0, 0.7), 1.5)
		draw_line(c0 + Vector2(-18, 0), c0 + Vector2(-10, 0), Color(0.8, 0.95, 1.0, 0.5), 1.5)
		draw_line(c0 + Vector2(18, 0), c0 + Vector2(10, 0), Color(0.8, 0.95, 1.0, 0.5), 1.5)
		if d.has("vel_marker"):
			var vm: Vector2 = d["vel_marker"]
			draw_arc(vm, 10.0, 0, TAU, 20, Color(0.4, 1.0, 0.6, 0.8), 1.5)
			draw_line(vm + Vector2(-16, 0), vm + Vector2(-10, 0), Color(0.4, 1.0, 0.6, 0.8), 1.5)
			draw_line(vm + Vector2(16, 0), vm + Vector2(10, 0), Color(0.4, 1.0, 0.6, 0.8), 1.5)
			draw_line(vm + Vector2(0, -16), vm + Vector2(0, -10), Color(0.4, 1.0, 0.6, 0.8), 1.5)
	else:
		draw_circle(c0, 2.0, Color(1, 1, 1, 0.7))
	# bottom centre readout
	var bx := sz.x * 0.5
	var by := sz.y - 70.0
	if d.get("mode", "") == "ship":
		var sp: float = d.get("speed", 0.0)
		var sp_txt := "%d m/s" % int(sp) if sp < 3000.0 else "%.1f km/s" % (sp / 1000.0)
		_txt(Vector2(bx, by), sp_txt, 30, Color(0.9, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		var st: String = d.get("status", "")
		_txt(Vector2(bx, by + 24), st, 16, Color(1.0, 0.8, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
		if d.has("alt"):
			var a: float = d["alt"]
			_txt(Vector2(bx, by - 36), "ALT %s" % (("%d m" % int(a)) if a < 5000.0 else ("%.1f km" % (a / 1000.0))), 18, Color(0.7, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		# throttle bar
		_bar(Vector2(bx - 90, by + 38), 180, d.get("throttle", 0.0), Color(0.3, 0.8, 1.0), "THR")
	else:
		if d.has("alt"):
			pass
	# status bars bottom right
	var bxr := sz.x - 220.0
	var byr := sz.y - 110.0
	_bar(Vector2(bxr, byr), 180, d.get("hull", 1.0), Color(0.9, 0.4, 0.3), "HULL")
	if d.get("mode", "") == "foot":
		_bar(Vector2(bxr, byr + 22), 180, d.get("health", 1.0), Color(0.4, 0.9, 0.4), "HEALTH")
		_bar(Vector2(bxr, byr + 44), 180, d.get("prot", 1.0), Color(1.0, 0.8, 0.2), "HAZARD")
		_bar(Vector2(bxr, byr + 66), 180, d.get("fuel", 1.0), Color(0.4, 0.8, 1.0), "JETPACK")
	# hints
	var hy := sz.y - 24.0
	var hints: Array = d.get("hints", [])
	for i in hints.size():
		_txt(Vector2(24, hy - (hints.size() - 1 - i) * 20), hints[i], 15, Color(0.75, 0.9, 1.0, 0.9))
	# notification
	if d.get("notif", "") != "":
		_txt(Vector2(bx, 150), d["notif"], 24, Color(1.0, 0.95, 0.7, clampf(d.get("notif_a", 1.0), 0, 1)), HORIZONTAL_ALIGNMENT_CENTER)
	# black hole warning
	if d.get("bh_text", "") != "":
		var flash := 0.6 + 0.4 * sin(t * (6.0 + 10.0 * d.get("bh_level", 0.0)))
		var col := Color(1.0, 0.25, 0.15, flash)
		_txt(Vector2(bx, 210), "⚠ " + d["bh_text"], 28, col, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(bx, 238), d.get("bh_sub", ""), 18, Color(1.0, 0.7, 0.5, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	# hazard warning
	if d.get("warn", "") != "":
		_txt(Vector2(bx, 280), d["warn"], 20, Color(1.0, 0.5, 0.2, 0.6 + 0.4 * sin(t * 6.0)), HORIZONTAL_ALIGNMENT_CENTER)
	# damage vignette
	if d.get("vignette", 0.0) > 0.0:
		var vv: float = d["vignette"]
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.8, 0.0, 0.0, 0.18 * vv))
