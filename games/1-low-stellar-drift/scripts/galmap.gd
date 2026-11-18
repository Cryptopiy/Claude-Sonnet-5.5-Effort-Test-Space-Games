extends Control
## Galaxy map + live schematic of the current star system.

signal warp_requested(id: int)

var stars := []
var current := 0
var selected := -1
var sysd := {}
var t := 0.0
var dust := []
var info := ""
var warp_btn: Button
var close_btn: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	var r = RandomNumberGenerator.new()
	r.seed = 99
	for i in range(1400):
		var arm = i % 3
		var tt = r.randf_range(0.05, 1.0)
		var ang = arm * TAU / 3.0 + tt * 4.2 + r.randfn(0.0, 0.3)
		dust.append(Vector2(cos(ang), sin(ang)) * tt * 12000.0 * (1.0 + r.randfn(0.0, 0.05)))
	warp_btn = Button.new()
	warp_btn.text = "WARP TO SELECTED STAR  (Enter)"
	warp_btn.pressed.connect(func(): if selected >= 0 and selected != current: warp_requested.emit(selected))
	add_child(warp_btn)
	close_btn = Button.new()
	close_btn.text = "Close map  (M)"
	close_btn.pressed.connect(func(): visible = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED; get_parent().get_parent().call("map_closed"))
	add_child(close_btn)

func open(sys: Dictionary, cur: int) -> void:
	sysd = sys
	current = cur
	if selected < 0 or selected == current:
		selected = Gal.DEST_STAR if current == Gal.HOME_STAR else Gal.HOME_STAR
	visible = true

func _center_g() -> Vector2:
	return Vector2(size.x * 0.32, size.y * 0.5)

func _scale_g() -> float:
	return minf(size.x * 0.30, size.y * 0.42) / 12500.0

func _to_screen(p: Vector3) -> Vector2:
	return _center_g() + Vector2(p.x, p.z) * _scale_g()

func _process(dt: float) -> void:
	if visible:
		t += dt
		warp_btn.position = Vector2(size.x * 0.64, size.y - 110)
		warp_btn.size = Vector2(size.x * 0.3, 44)
		close_btn.position = Vector2(size.x * 0.64, size.y - 58)
		close_btn.size = Vector2(size.x * 0.3, 40)
		queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var best = -1
		var bd = 16.0
		for s in stars:
			var d = _to_screen(s["pos"]).distance_to(ev.position)
			if d < bd:
				bd = d
				best = s["id"]
		if best >= 0:
			selected = best

func _draw() -> void:
	var f = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.015, 0.04, 1.0))
	draw_string(f, Vector2(30, 40), "GALAXY MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.6, 0.85, 1.0))
	draw_string(f, Vector2(30, 64), "Click a star to select it.  Warping costs 3 resource units.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.7, 0.8))
	var c = _center_g()
	var sc = _scale_g()
	# glowing core
	for i in range(8):
		draw_circle(c, (8 - i) * 22.0, Color(1.0, 0.8, 0.5, 0.025))
	for p in dust:
		draw_circle(c + p * sc, 1.0, Color(0.5, 0.6, 0.9, 0.35))
	# black hole link
	var hp = _to_screen(stars[Gal.HOME_STAR]["pos"])
	var dp = _to_screen(stars[Gal.DEST_STAR]["pos"])
	draw_dashed_line(hp, dp, Color(0.9, 0.5, 0.2, 0.8), 2.0, 8.0)
	draw_string(f, (hp + dp) * 0.5 + Vector2(8, -6), "black hole link", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.65, 0.3))
	for s in stars:
		var p2 = _to_screen(s["pos"])
		var col: Color = Gal.STAR_TYPES[s["type"]]["col"]
		draw_circle(p2, 3.5, col)
		draw_circle(p2, 7.0, Color(col.r, col.g, col.b, 0.2))
		if s["id"] == current:
			draw_arc(p2, 11.0, 0, TAU, 24, Color(0.3, 1.0, 0.4), 2.0)
			draw_string(f, p2 + Vector2(12, 4), "YOU: " + s["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.4, 1.0, 0.5))
		elif s["id"] == selected:
			draw_arc(p2, 11.0, 0, TAU, 24, Color(1.0, 0.9, 0.3), 2.0)
			draw_string(f, p2 + Vector2(12, 4), s["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.95, 0.5))
	# right side: info + system schematic
	var rx = size.x * 0.64
	var w = size.x * 0.3
	if selected >= 0:
		var s = stars[selected]
		var st = Gal.STAR_TYPES[s["type"]]
		var dist = stars[current]["pos"].distance_to(s["pos"])
		draw_string(f, Vector2(rx, 100), "Selected: %s" % s["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.95, 0.6))
		draw_string(f, Vector2(rx, 126), "Class %s star   Distance %.0f ly" % [st["c"], dist], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		if selected == Gal.DEST_STAR or selected == Gal.HOME_STAR:
			draw_string(f, Vector2(rx, 148), "Linked to a black hole route", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.65, 0.3))
	draw_string(f, Vector2(rx, 200), "CURRENT SYSTEM: %s" % sysd.get("name", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.5, 1.0, 0.6))
	var sc2 = Vector2(rx + w * 0.5, 360.0)
	var maxr = 1.0
	for b in sysd.get("bodies", []):
		maxr = maxf(maxr, b["orbit_r"] + (4500.0 if b["parent"] >= 0 else 0.0))
	var k = (w * 0.48) / maxr
	draw_circle(sc2, 7.0, Gal.STAR_TYPES[stars[current]["type"]]["col"])
	var bodies = sysd.get("bodies", [])
	var pos_cache = {}
	for i in range(bodies.size()):
		var b = bodies[i]
		if b["parent"] < 0:
			draw_arc(sc2, b["orbit_r"] * k, 0, TAU, 64, Color(1, 1, 1, 0.13), 1.0)
	for i in range(bodies.size()):
		var b = bodies[i]
		var a = b["phase"] + t * 0.35 * (12000.0 / b["period"]) * 0.05 * 10.0
		var p3 = sc2 + Vector2(cos(a), sin(a)) * b["orbit_r"] * k
		if b["parent"] >= 0:
			var pb = bodies[b["parent"]]
			var pa = pb["phase"] + t * 0.35 * (12000.0 / pb["period"]) * 0.05 * 10.0
			var pp = sc2 + Vector2(cos(pa), sin(pa)) * pb["orbit_r"] * k
			p3 = pp + Vector2(cos(a * 4.0), sin(a * 4.0)) * 14.0
		var colr = Color(0.7, 0.7, 0.7)
		match b["biome"]:
			"lush": colr = Color(0.3, 0.8, 0.3)
			"desert": colr = Color(0.9, 0.6, 0.3)
			"frozen": colr = Color(0.8, 0.95, 1.0)
			"lava": colr = Color(1.0, 0.35, 0.1)
			"toxic": colr = Color(0.6, 0.9, 0.2)
			"gas": colr = Color(0.9, 0.7, 0.5)
		draw_circle(p3, 4.0 if b["biome"] != "gas" else 8.0, colr)
		draw_string(f, p3 + Vector2(6, -6), b["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.85, 0.9))
	var y = 560.0
	for b in bodies:
		var bi = Gal.BIOMES[b["biome"]]
		draw_string(f, Vector2(rx, y), "%s - %s" % [b["name"], bi["name"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.8, 0.9))
		y += 17.0
