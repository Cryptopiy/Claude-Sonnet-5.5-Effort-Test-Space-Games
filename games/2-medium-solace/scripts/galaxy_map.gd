class_name GalaxyMap
extends Control
## Interactive top-down galaxy map. Click a star, Enter to hyperjump.

signal jump_requested(idx: int)
signal closed

const JUMP_RANGE := 14000.0

var current := 0
var selected := -1
var zoom := 0.0095
var pan := Vector2.ZERO
var dragging := false
var font: Font
var t := 0.0
var msg := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	font = ThemeDB.fallback_font
	visible = false

func open(cur: int) -> void:
	current = cur
	selected = cur
	pan = -(Galaxy.stars[cur]["pos"] as Vector2)
	zoom = 0.013
	msg = ""
	visible = true

func _to_screen(p: Vector2) -> Vector2:
	return size * 0.5 + (p + pan) * zoom

func _process(delta: float) -> void:
	t += delta
	size = get_viewport().get_visible_rect().size
	if visible:
		queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom = minf(zoom * 1.15, 0.2)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom = maxf(zoom / 1.15, 0.004)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var best := -1
			var bd := 16.0
			for i in Galaxy.stars.size():
				var d := _to_screen(Galaxy.stars[i]["pos"]).distance_to(mb.position)
				if d < bd:
					bd = d
					best = i
			if best >= 0:
				selected = best
				msg = ""
	elif e is InputEventMouseMotion and dragging:
		pan += (e as InputEventMouseMotion).relative / zoom
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var k := (e as InputEventKey).keycode
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			try_jump()
		elif k == KEY_ESCAPE or k == KEY_M or k == KEY_TAB:
			closed.emit()

func distance_to(idx: int) -> float:
	return (Galaxy.stars[idx]["pos"] as Vector2).distance_to(Galaxy.stars[current]["pos"])

func try_jump() -> void:
	if selected < 0 or selected == current:
		msg = "Select a different star first."
		return
	if distance_to(selected) > JUMP_RANGE:
		msg = "Out of hyperdrive range (%d ly max)." % int(JUMP_RANGE)
		return
	jump_requested.emit(selected)

func _txt(p: Vector2, s: String, sz := 16, col := Color(0.8, 0.92, 1.0), al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var q := p
	if al != HORIZONTAL_ALIGNMENT_LEFT:
		q.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x * 0.5
	draw_string(font, q + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0, 0, 0, 0.8))
	draw_string(font, q, s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.015, 0.04, 0.96))
	# glow of the galactic core
	var core := _to_screen(Vector2.ZERO)
	for i in 14:
		draw_circle(core, (14 - i) * 28.0 * zoom * 70.0 * 0.06 + 6.0, Color(1.0, 0.8, 0.5, 0.012))
	var cur_pos := _to_screen(Galaxy.stars[current]["pos"])
	# range ring
	draw_arc(cur_pos, JUMP_RANGE * zoom, 0, TAU, 96, Color(0.3, 0.6, 1.0, 0.35), 1.5)
	for i in Galaxy.stars.size():
		var st: Dictionary = Galaxy.stars[i]
		var p := _to_screen(st["pos"])
		if p.x < -20 or p.y < -20 or p.x > size.x + 20 or p.y > size.y + 20:
			continue
		var col: Color = Galaxy.CLASSES[st["cls"]]["color"]
		var r: float = 1.6 + zoom * 120.0 * (0.5 + 0.2 * float(st["cls"]))
		draw_circle(p, r * 2.2, Color(col.r, col.g, col.b, 0.12))
		draw_circle(p, r, col)
	# black hole link of current system
	var sysd := Galaxy.make_system(current)
	var tp := _to_screen(Galaxy.stars[sysd["bh_target"]]["pos"])
	draw_dashed_line(cur_pos, tp, Color(0.8, 0.3, 1.0, 0.6), 1.5, 8.0)
	draw_arc(tp, 11.0, 0, TAU, 20, Color(0.8, 0.3, 1.0, 0.8), 1.5)
	_txt(tp + Vector2(14, 4), "Black hole exit", 12, Color(0.85, 0.5, 1.0))
	# markers
	draw_arc(cur_pos, 9.0 + 2.0 * sin(t * 3.0), 0, TAU, 24, Color(1.0, 0.85, 0.3), 2.0)
	_txt(cur_pos + Vector2(12, -8), "YOU ARE HERE", 12, Color(1.0, 0.85, 0.3))
	if selected >= 0:
		var sp := _to_screen(Galaxy.stars[selected]["pos"])
		draw_rect(Rect2(sp - Vector2(10, 10), Vector2(20, 20)), Color(0.4, 1.0, 0.8), false, 2.0)
		draw_line(cur_pos, sp, Color(0.4, 1.0, 0.8, 0.5), 1.0)
	# info
	_txt(Vector2(30, 44), "GALAXY MAP", 30, Color(0.9, 0.97, 1.0))
	_txt(Vector2(30, 68), "Wheel: zoom   Right-drag: pan   Click: select star   Enter: hyperjump   Esc/M: close", 14, Color(0.6, 0.8, 1.0))
	if selected >= 0:
		var st2: Dictionary = Galaxy.stars[selected]
		var sy := Galaxy.make_system(selected)
		var lines := [
			"%s  (system %d)" % [st2["name"], selected],
			"Class %s star" % Galaxy.CLASSES[st2["cls"]]["id"],
			"Planets & moons: %d" % (sy["bodies"] as Array).size(),
			"Distance: %d ly" % int(distance_to(selected)),
			"Black hole -> %s" % Galaxy.stars[sy["bh_target"]]["name"],
		]
		for i in lines.size():
			_txt(Vector2(30, size.y - 140 + i * 22), lines[i], 17 if i > 0 else 22, Color(0.85, 0.97, 1.0) if i > 0 else Color(1.0, 0.9, 0.6))
	if msg != "":
		_txt(Vector2(size.x * 0.5, size.y - 40), msg, 20, Color(1.0, 0.5, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
