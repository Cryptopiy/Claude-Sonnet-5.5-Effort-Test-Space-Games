class_name GalaxyMap
extends CanvasLayer
## Full-screen 3D galaxy map: drag to rotate, wheel to zoom, click a star to select, ENTER to hyperjump.

signal jump_requested(id: int)
signal closed

var world: World
var canvas: MapCanvas
var panel: PanelContainer
var lbl_name: Label
var lbl_info: Label
var lbl_status: Label
var btn_jump: Button
var selected := -1
var hovered := -1
var yaw := 0.35
var pitch := 0.95
var zoom := 0.0055
var focus := Vector3.ZERO
var dust := PackedVector3Array()
var dust_col := PackedFloat32Array()
var drag := false
var drag_moved := 0.0
var sys_cache := {}


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = MapCanvas.new()
	canvas.map = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(canvas)
	_make_dust()
	_build_panel()
	visible = false


func _make_dust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 5200:
		var u := rng.randf()
		var r := 2500.0 + (Galaxy.GALAXY_RADIUS + 3000.0 - 2500.0) * pow(u, 0.85)
		var arm := rng.randi() % 4
		var ang := arm * (TAU / 4.0) + r / 9000.0 * 1.15 + rng.randfn(0.0, 0.3)
		var y := rng.randfn(0.0, 500.0 + 900.0 * exp(-r / 14000.0))
		if rng.randf() < 0.18:
			r = rng.randf_range(100.0, 7000.0)
			ang = rng.randf() * TAU
			y = rng.randfn(0.0, 1200.0)
		dust.append(Vector3(cos(ang) * r, y, sin(ang) * r))
		dust_col.append(rng.randf())


func _build_panel() -> void:
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.09, 0.82)
	sb.border_color = Color(0.3, 0.8, 0.95, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.position = Vector2(-26, 0)
	panel.custom_minimum_size = Vector2(330, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var t := Label.new()
	t.text = "GALAXY MAP"
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	v.add_child(t)
	lbl_name = Label.new()
	lbl_name.add_theme_font_size_override("font_size", 28)
	v.add_child(lbl_name)
	lbl_info = Label.new()
	lbl_info.add_theme_font_size_override("font_size", 15)
	lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_info.custom_minimum_size = Vector2(300, 0)
	v.add_child(lbl_info)
	lbl_status = Label.new()
	lbl_status.add_theme_font_size_override("font_size", 14)
	lbl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_status.custom_minimum_size = Vector2(300, 0)
	v.add_child(lbl_status)
	btn_jump = Button.new()
	btn_jump.text = "HYPERJUMP  (Enter)"
	btn_jump.custom_minimum_size = Vector2(300, 46)
	btn_jump.add_theme_font_size_override("font_size", 20)
	btn_jump.pressed.connect(func(): _do_jump())
	v.add_child(btn_jump)
	var help := Label.new()
	help.text = "Drag: rotate · Wheel: zoom · Click: select\nT: recentre on ship · M / Esc: close"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85))
	v.add_child(help)


func open(w: World) -> void:
	world = w
	visible = true
	focus = w.star_info.pos
	selected = w.star_info.id
	_refresh_panel()


func close() -> void:
	visible = false
	closed.emit()


func _do_jump() -> void:
	if selected < 0 or world == null:
		return
	if selected == world.star_info.id:
		lbl_status.text = "You are already in this system."
		return
	var why := world.can_jump()
	if why != "":
		lbl_status.text = why
		lbl_status.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
		Sfx.play("warn")
		return
	jump_requested.emit(selected)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm"):
		_do_jump()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_T:
		focus = world.star_info.pos
		get_viewport().set_input_as_handled()


func project(p: Vector3, center: Vector2) -> Vector3:
	var b := Basis(Vector3.RIGHT, pitch) * Basis(Vector3.UP, yaw)
	var q := b * (p - focus)
	return Vector3(center.x + q.x * zoom, center.y - q.y * zoom, q.z)


func _pick(mp: Vector2, center: Vector2) -> int:
	var best := -1
	var bd := 16.0
	for s in Game.galaxy.stars:
		var sp := project(s.pos, center)
		var d := Vector2(sp.x, sp.y).distance_to(mp)
		if d < bd:
			bd = d
			best = s.id
	return best


func _refresh_panel() -> void:
	if selected < 0:
		return
	var s: Galaxy.StarInfo = Game.galaxy.stars[selected]
	lbl_name.text = s.name
	lbl_name.add_theme_color_override("font_color", s.color.lerp(Color.WHITE, 0.3))
	var here: Galaxy.StarInfo = world.star_info
	var d := s.pos.distance_to(here.pos)
	var txt := "Class %s star · %s\n" % [s.cls, _class_desc(s.cls)]
	if s.id == here.id:
		txt += "Current system\n"
	else:
		txt += "Distance: %s light years\n" % _fmt_ly(d)
	if not sys_cache.has(s.id):
		var sg := SystemGen.new()
		sg.build(s)
		var landable := 0
		var biomes := {}
		for p: PlanetData in sg.planets:
			if p.landable:
				landable += 1
			biomes[p.biome_name()] = true
		sys_cache[s.id] = {"n": sg.planets.size(), "land": landable, "biomes": biomes.keys()}
	var c: Dictionary = sys_cache[s.id]
	txt += "%d bodies · %d landable\n%s\n" % [c.n, c.land, ", ".join(c.biomes)]
	if s.has_bh:
		var dst: Galaxy.StarInfo = Game.galaxy.stars[s.bh_target]
		txt += "\nBLACK HOLE present — leads to %s (%s ly toward the core)\n" % [dst.name, _fmt_ly(s.pos.distance_to(dst.pos))]
	if s.visited:
		txt += "Visited\n"
	lbl_info.text = txt
	btn_jump.disabled = s.id == here.id
	var why := world.can_jump()
	if s.id == here.id:
		lbl_status.text = ""
	elif why != "":
		lbl_status.text = why
		lbl_status.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	else:
		lbl_status.text = "Hyperdrive ready."
		lbl_status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))


func _class_desc(c: String) -> String:
	match c:
		"O": return "blue giant"
		"B": return "blue-white"
		"A": return "white"
		"F": return "yellow-white"
		"G": return "yellow"
		"K": return "orange"
		"M": return "red dwarf"
	return ""


func _fmt_ly(d: float) -> String:
	return "%s" % String.num(d, 0)


class MapCanvas extends Control:
	var map: GalaxyMap
	var last_mouse := Vector2.ZERO

	func _process(_dt: float) -> void:
		if map != null and map.visible:
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var center := size * 0.5 - Vector2(120, 0)
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					map.drag = true
					map.drag_moved = 0.0
				else:
					map.drag = false
					if map.drag_moved < 5.0:
						var id := map._pick(mb.position, center)
						if id >= 0:
							map.selected = id
							map._refresh_panel()
							Sfx.play("click")
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				map.zoom = minf(map.zoom * 1.15, 0.06)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				map.zoom = maxf(map.zoom / 1.15, 0.0018)
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if map.drag:
				map.drag_moved += mm.relative.length()
				map.yaw += mm.relative.x * 0.006
				map.pitch = clampf(map.pitch + mm.relative.y * 0.006, -1.5, 1.5)
			else:
				map.hovered = map._pick(mm.position, center)
			last_mouse = mm.position

	func _draw() -> void:
		if map == null or map.world == null:
			return
		var font := ThemeDB.fallback_font
		var center := size * 0.5 - Vector2(120, 0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.01, 0.025, 0.96))
		# vignette-ish radial haze
		for i in 6:
			var r := size.y * (0.9 - i * 0.12)
			draw_circle(center, r, Color(0.03, 0.05, 0.1, 0.05))
		# galactic dust
		var b := Basis(Vector3.RIGHT, map.pitch) * Basis(Vector3.UP, map.yaw)
		for i in map.dust.size():
			var q := b * (map.dust[i] - map.focus)
			var p := Vector2(center.x + q.x * map.zoom, center.y - q.y * map.zoom)
			if p.x < 0 or p.y < 0 or p.x > size.x or p.y > size.y:
				continue
			var k := map.dust_col[i]
			var rr := map.dust[i].length()
			var col := Color(0.55, 0.65, 1.0, 0.22).lerp(Color(1.0, 0.85, 0.55, 0.3), clampf(1.0 - rr / 12000.0, 0.0, 1.0))
			col.a *= 0.5 + k * 0.7
			draw_rect(Rect2(p, Vector2(1.6, 1.6)), col)
		# galactic core glow
		var cc := map.project(Vector3.ZERO, center)
		for i in 9:
			var rad := (14.0 + i * 16.0) * (map.zoom / 0.0055) * 0.5 + 6.0
			draw_circle(Vector2(cc.x, cc.y), rad, Color(1.0, 0.85, 0.5, 0.045))
		draw_circle(Vector2(cc.x, cc.y), 5.0 * maxf(map.zoom / 0.0055, 0.6), Color(1.0, 0.95, 0.8, 0.9))
		draw_string(font, Vector2(cc.x + 14, cc.y - 10), "GALACTIC CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.55, 0.8))
		# stars sorted far -> near
		var order: Array = []
		for s in Game.galaxy.stars:
			var sp := map.project(s.pos, center)
			order.append([sp.z, s, sp])
		order.sort_custom(func(a, bb): return a[0] < bb[0])
		var here: Galaxy.StarInfo = map.world.star_info
		# black-hole links
		for s in Game.galaxy.stars:
			if s.has_bh and (s.id == here.id or s.id == map.selected or s.id == map.hovered):
				var a := map.project(s.pos, center)
				var bpos := map.project((Game.galaxy.stars[s.bh_target] as Galaxy.StarInfo).pos, center)
				var d := Vector2(bpos.x - a.x, bpos.y - a.y)
				var n := 28
				for i in n:
					if i % 2 == 0:
						draw_line(Vector2(a.x, a.y) + d * (float(i) / n), Vector2(a.x, a.y) + d * (float(i + 1) / n), Color(0.85, 0.4, 1.0, 0.8), 1.5)
		for o in order:
			var s: Galaxy.StarInfo = o[1]
			var sp: Vector3 = o[2]
			var p := Vector2(sp.x, sp.y)
			if p.x < -20 or p.y < -20 or p.x > size.x + 20 or p.y > size.y + 20:
				continue
			var r := 1.8 + s.size_mul * 1.1
			var col := s.color
			draw_circle(p, r * 3.0, Color(col.r, col.g, col.b, 0.10))
			draw_circle(p, r * 1.7, Color(col.r, col.g, col.b, 0.25))
			draw_circle(p, r, col)
			if s.visited:
				draw_arc(p, r + 3.5, 0, TAU, 16, Color(0.5, 1.0, 0.6, 0.8), 1.0)
			if s.has_bh:
				draw_arc(p, r + 6.0, 0, TAU, 20, Color(0.85, 0.4, 1.0, 0.9), 1.5)
			var label := ""
			var lcol := Color(0.85, 0.95, 1.0, 0.85)
			if s.id == here.id:
				draw_arc(p, r + 9.0, 0, TAU, 28, Color(0.5, 1.0, 0.6), 2.0)
				label = "%s  (you are here)" % s.name
				lcol = Color(0.5, 1.0, 0.6)
			elif s.id == map.selected:
				var q := 13.0
				draw_line(p + Vector2(-q, -q), p + Vector2(-q + 5, -q), Color(1, 0.85, 0.3), 2.0)
				draw_line(p + Vector2(-q, -q), p + Vector2(-q, -q + 5), Color(1, 0.85, 0.3), 2.0)
				draw_line(p + Vector2(q, q), p + Vector2(q - 5, q), Color(1, 0.85, 0.3), 2.0)
				draw_line(p + Vector2(q, q), p + Vector2(q, q - 5), Color(1, 0.85, 0.3), 2.0)
				label = s.name
				lcol = Color(1, 0.88, 0.4)
			elif s.id == map.hovered:
				label = s.name
			elif map.zoom > 0.012 and s.pos.distance_to(map.focus) < 2.2 / maxf(map.zoom, 0.0001) * 120.0:
				label = s.name
			elif s.has_bh and map.zoom > 0.004:
				label = "◉ " + s.name
				lcol = Color(0.85, 0.5, 1.0, 0.9)
			if label != "":
				draw_string(font, p + Vector2(10, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.8))
				draw_string(font, p + Vector2(9, -9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, lcol)
		# scale bar
		var bar_ly := 5000.0
		var bar_px := bar_ly * map.zoom
		draw_line(Vector2(40, size.y - 40), Vector2(40 + bar_px, size.y - 40), Color(0.6, 0.8, 0.9), 2.0)
		draw_string(font, Vector2(40, size.y - 50), "%d ly" % int(bar_ly), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.8, 0.9))
