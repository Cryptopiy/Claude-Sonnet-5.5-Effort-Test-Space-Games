class_name GalaxyMap
extends Control
## Full-screen galaxy map (rotatable 3D star cloud, hyperdrive jumps) and system orrery (planets on accelerated orbits).

signal closed
signal jump_requested(dest: int)

const JUMP_RANGE_LY: float = 3600.0
const ORRERY_SPEED: float = 900.0

enum Tab { GALAXY, SYSTEM }

var world: SpaceWorld
var pc: PlayerController
var galaxy: Galaxy
var tab: int = Tab.GALAXY
var yaw: float = 0.6
var pitch: float = 0.85
var zoom: float = 0.012                 # pixels per light year
var focus: Vector3 = Vector3.ZERO
var focus_target: Vector3 = Vector3.ZERO
var selected: int = -1
var hover: int = -1
var current: int = 0
var _dragging: bool = false
var _t: float = 0.0
var _glow: GradientTexture2D
var _sys_cache: Dictionary = {}
var _orr_t: float = 0.0
var _sel_body: int = -1
var _msg: String = ""
var _msg_t: float = 0.0
var _jump_btn: Button
var _craft_btn: Button
var _tab_btns: Array[Button] = []
var _screen_pts: PackedVector2Array = PackedVector2Array()
var _screen_depth: PackedFloat32Array = PackedFloat32Array()
var s: float = 1.0

func _ready() -> void:
	theme = UiKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	galaxy = Galaxy.get_galaxy()
	_screen_pts.resize(Galaxy.COUNT)
	_screen_depth.resize(Galaxy.COUNT)
	_glow = GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_glow.gradient = g
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)
	_glow.width = 128
	_glow.height = 128
	_jump_btn = Button.new()
	_jump_btn.text = "HYPERDRIVE JUMP  (Enter)"
	_jump_btn.pressed.connect(_do_jump)
	_jump_btn.focus_mode = Control.FOCUS_NONE
	add_child(_jump_btn)
	_craft_btn = Button.new()
	_craft_btn.text = "CRAFT WARP CELL  (30 Sodium + 20 Ferrite)"
	_craft_btn.pressed.connect(_craft)
	_craft_btn.focus_mode = Control.FOCUS_NONE
	add_child(_craft_btn)
	for i in 2:
		var b := Button.new()
		b.text = ["GALAXY", "SYSTEM"][i]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_set_tab.bind(i))
		add_child(b)
		_tab_btns.append(b)
	var close := Button.new()
	close.text = "CLOSE  (Esc / M)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_map)
	add_child(close)
	close.name = "CloseBtn"

func open(w: SpaceWorld, p: PlayerController) -> void:
	world = w
	pc = p
	current = Game.current_system_index
	focus = galaxy.stars[current]["pos"]
	focus_target = focus
	if selected < 0 or selected == current:
		selected = -1
	_sel_body = -1
	_orr_t = 0.0
	visible = true
	_layout()
	queue_redraw()

func close() -> void:
	close_map()

func close_map() -> void:
	visible = false
	closed.emit()

func _set_tab(i: int) -> void:
	tab = i
	_sel_body = -1

func _layout() -> void:
	s = maxf(size.y / 1080.0, 0.6)
	var w: float = size.x
	var h: float = size.y
	_jump_btn.position = Vector2(w - 440.0 * s, h - 150.0 * s)
	_jump_btn.size = Vector2(410.0 * s, 56.0 * s)
	_craft_btn.position = Vector2(w - 440.0 * s, h - 84.0 * s)
	_craft_btn.size = Vector2(410.0 * s, 44.0 * s)
	_craft_btn.add_theme_font_size_override("font_size", int(15 * s))
	_jump_btn.add_theme_font_size_override("font_size", int(21 * s))
	for i in _tab_btns.size():
		_tab_btns[i].position = Vector2(34.0 * s + i * 170.0 * s, 24.0 * s)
		_tab_btns[i].size = Vector2(160.0 * s, 44.0 * s)
		_tab_btns[i].add_theme_font_size_override("font_size", int(20 * s))
	var cb: Button = get_node("CloseBtn")
	cb.position = Vector2(w - 260.0 * s, 24.0 * s)
	cb.size = Vector2(230.0 * s, 44.0 * s)
	cb.add_theme_font_size_override("font_size", int(18 * s))

# ----------------------------------------------------------------------------------------- input
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: Key = (event as InputEventKey).physical_keycode
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			_do_jump()
			get_viewport().set_input_as_handled()
		elif k == KEY_M or k == KEY_TAB:
			close_map()
			get_viewport().set_input_as_handled()
		elif k == KEY_1:
			_set_tab(0)
		elif k == KEY_2:
			_set_tab(1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom = clampf(zoom * 1.12, 0.0015, 0.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom = clampf(zoom / 1.12, 0.0015, 0.5)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_press_pos = mb.position
			else:
				_dragging = false
				if mb.position.distance_to(_press_pos) < 5.0:
					_click(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if selected >= 0:
				focus_target = galaxy.stars[selected]["pos"]
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging and tab == Tab.GALAXY:
			yaw -= mm.relative.x * 0.006
			pitch = clampf(pitch + mm.relative.y * 0.006, -1.5, 1.5)
		else:
			_update_hover(mm.position)

var _press_pos: Vector2 = Vector2.ZERO

func _project(p: Vector3) -> Vector3:
	var q: Vector3 = p - focus
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var r: Vector3 = b.inverse() * q
	return r

func _screen_of(r: Vector3) -> Vector2:
	return size * 0.5 + Vector2(r.x, -r.y) * zoom

func _update_hover(mp: Vector2) -> void:
	if tab != Tab.GALAXY:
		hover = -1
		return
	var best: int = -1
	var bd: float = 14.0 * s
	for i in Galaxy.COUNT:
		var d: float = _screen_pts[i].distance_to(mp)
		if d < bd:
			bd = d
			best = i
	hover = best

func _click(mp: Vector2) -> void:
	if tab == Tab.GALAXY:
		_update_hover(mp)
		if hover >= 0:
			selected = hover
			_msg = ""
	else:
		var best: int = -1
		var bd: float = 22.0 * s
		for i in world.sys.bodies.size():
			var d: float = _orrery_pos(i, _orr_t).distance_to(mp)
			if d < bd:
				bd = d
				best = i
		_sel_body = best
		if best >= 0 and pc != null:
			pc.ship.target_idx = best
			Game.notify("Target set: %s" % world.sys.bodies[best].name, 2.0)

# ----------------------------------------------------------------------------------------- actions
func _jump_status(dest: int) -> String:
	## returns "" when the jump is possible, otherwise the reason
	if dest < 0:
		return "Select a destination star"
	if dest == current:
		return "You are already in this system"
	var d: float = galaxy.distance_ly(current, dest)
	if d > JUMP_RANGE_LY:
		return "Out of range (%d ly > %d ly)" % [int(d), int(JUMP_RANGE_LY)]
	if Game.get_item("warp_cells") < 1:
		return "No warp cell - craft one below"
	if pc.mode != PlayerController.Mode.SHIP:
		return "Return to your ship first"
	if world.frame_idx >= 0:
		return "Leave the planetary gravity well first"
	if not pc.ship._pulse_allowed():
		return "Too close to a massive body for hyperdrive"
	if pc.ship.bh_control_loss > 0.05 or int(world.bh_info.get("zone", 0)) > 0:
		return "Hyperdrive disabled near the black hole"
	return ""

func _do_jump() -> void:
	if not visible or tab != Tab.GALAXY:
		return
	var why: String = _jump_status(selected)
	if why != "":
		_msg = why
		_msg_t = 3.0
		return
	Game.inventory["warp_cells"] = int(Game.inventory["warp_cells"]) - 1
	var dest: int = selected
	visible = false
	jump_requested.emit(dest)

func _craft() -> void:
	if Game.get_item("sodium") >= 30 and Game.get_item("ferrite") >= 20:
		Game.inventory["sodium"] = int(Game.inventory["sodium"]) - 30
		Game.inventory["ferrite"] = int(Game.inventory["ferrite"]) - 20
		Game.inventory["warp_cells"] = int(Game.inventory["warp_cells"]) + 1
		_msg = "Warp cell crafted"
		_msg_t = 2.5
	else:
		_msg = "Not enough resources: need 30 Sodium and 20 Ferrite"
		_msg_t = 3.0

# ----------------------------------------------------------------------------------------- draw
func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_msg_t = maxf(0.0, _msg_t - delta)
	_orr_t += delta * ORRERY_SPEED
	focus = focus.lerp(focus_target, 1.0 - exp(-6.0 * delta))
	var is_gal: bool = tab == Tab.GALAXY
	_jump_btn.visible = is_gal
	_craft_btn.visible = is_gal
	_jump_btn.disabled = _jump_status(selected) != ""
	queue_redraw()

func _txt(pos: Vector2, text: String, fs: float, col: Color, bold: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f: Font = UiKit.font_bold() if bold else UiKit.font()
	var px: int = int(maxf(8.0, fs * s))
	draw_string_outline(f, pos, text, align, width, px, 4, Color(0, 0, 0, 0.7))
	draw_string(f, pos, text, align, width, px, col)

func _draw() -> void:
	if not visible or world == null:
		return
	_layout()
	var sz: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.004, 0.008, 0.02, 1.0))
	if tab == Tab.GALAXY:
		_draw_galaxy(sz)
	else:
		_draw_system(sz)
	# header
	_txt(Vector2(380.0 * s, 54.0 * s), "GALAXY MAP" if tab == Tab.GALAXY else "%s SYSTEM" % world.sys.name.to_upper(), 26.0, UiKit.C_MAIN, true)
	if _msg_t > 0.0:
		_txt(Vector2(0, sz.y - 36.0 * s), _msg, 20.0, UiKit.C_WARN, true, HORIZONTAL_ALIGNMENT_CENTER, sz.x - 460.0 * s)

func _draw_galaxy(sz: Vector2) -> void:
	# galaxy core glow
	var core: Vector3 = _project(Vector3.ZERO)
	var cs: Vector2 = _screen_of(core)
	var gr: float = 7000.0 * zoom
	draw_texture_rect(_glow, Rect2(cs - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(1.0, 0.8, 0.5, 0.22))
	var gr2: float = 2400.0 * zoom
	draw_texture_rect(_glow, Rect2(cs - Vector2(gr2, gr2), Vector2(gr2, gr2) * 2.0), false, Color(1.0, 0.9, 0.7, 0.35))
	# jump range ring (in the galactic plane around the current star)
	var cur_pos: Vector3 = galaxy.stars[current]["pos"]
	var ring := PackedVector2Array()
	for k in 65:
		var a: float = float(k) / 64.0 * TAU
		var rp: Vector3 = _project(cur_pos + Vector3(cos(a), 0.0, sin(a)) * JUMP_RANGE_LY)
		ring.append(_screen_of(rp))
	draw_polyline(ring, Color(0.45, 0.88, 1.0, 0.28), 1.5 * s, true)
	# stars (soft glows first -> the spiral arms light up where stars cluster)
	for i in Galaxy.COUNT:
		var st0: Dictionary = galaxy.stars[i]
		var sp0: Vector2 = _screen_of(_project(st0["pos"]))
		_screen_pts[i] = sp0
		if i % 3 == 0 and sp0.x > -30.0 and sp0.y > -30.0 and sp0.x < sz.x + 30.0 and sp0.y < sz.y + 30.0:
			var gc: Color = st0["color"]
			var gs: float = (9.0 + 16.0 * minf(zoom * 60.0, 1.0)) * s
			draw_texture_rect(_glow, Rect2(sp0 - Vector2(gs, gs), Vector2(gs, gs) * 2.0), false, Color(gc.r, gc.g, gc.b, 0.07))
	for i in Galaxy.COUNT:
		var st: Dictionary = galaxy.stars[i]
		var r3: Vector3 = _project(st["pos"])
		var sp: Vector2 = _screen_pts[i]
		if sp.x < -20.0 or sp.y < -20.0 or sp.x > sz.x + 20.0 or sp.y > sz.y + 20.0:
			continue
		var col: Color = st["color"]
		var in_range: bool = galaxy.distance_ly(current, i) <= JUMP_RANGE_LY
		var depth_f: float = clampf(0.55 + r3.z * zoom * 0.0006, 0.35, 1.0)
		var rad: float = 1.5 * s + (1.5 * s if in_range else 0.0)
		var a2: float = 0.7 * depth_f + (0.3 if in_range else 0.0)
		draw_circle(sp, rad, Color(col.r, col.g, col.b, a2))
		if bool(st["bh"]):
			draw_arc(sp, 6.0 * s, 0.0, TAU, 20, Color(0.85, 0.45, 1.0, 0.85), 1.4 * s, true)
	# special markers
	var cs2: Vector2 = _screen_pts[current]
	draw_arc(cs2, 11.0 * s + 2.0 * s * sin(_t * 3.0), 0.0, TAU, 32, UiKit.C_MAIN, 2.0 * s, true)
	_txt(cs2 + Vector2(16.0, -8.0) * s, "YOU ARE HERE - %s" % galaxy.stars[current]["name"], 16.0, UiKit.C_MAIN, true)
	if selected >= 0:
		var ssp: Vector2 = _screen_pts[selected]
		draw_arc(ssp, 10.0 * s, 0.0, TAU, 32, UiKit.C_WARN, 2.0 * s, true)
		draw_dashed_line(cs2, ssp, Color(1.0, 0.7, 0.3, 0.6), 1.5 * s, 8.0 * s)
		_txt(ssp + Vector2(14.0, -8.0) * s, String(galaxy.stars[selected]["name"]), 16.0, UiKit.C_WARN, true)
	if hover >= 0 and hover != selected:
		var hp: Vector2 = _screen_pts[hover]
		draw_arc(hp, 8.0 * s, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 1.5 * s, true)
		_txt(hp + Vector2(12.0, -6.0) * s, "%s (%s)  %d ly" % [galaxy.stars[hover]["name"], galaxy.stars[hover]["cls"], int(galaxy.distance_ly(current, hover))], 15.0, UiKit.C_TEXT)
	# galactic core label
	_txt(cs + Vector2(10.0, -10.0) * s, "GALACTIC CORE", 15.0, Color(1.0, 0.85, 0.6, 0.8), true)
	_draw_info_panel(sz)
	_txt(Vector2(34.0 * s, sz.y - 30.0 * s), "Drag: rotate   Wheel: zoom   Click: select star   Right click: centre on selection   Purple ring: black hole system", 15.0, UiKit.C_TEXT_DIM)

func _draw_info_panel(sz: Vector2) -> void:
	var r := Rect2(Vector2(sz.x - 440.0 * s, 90.0 * s), Vector2(410.0 * s, sz.y - 270.0 * s))
	draw_rect(r, Color(0.02, 0.05, 0.09, 0.78))
	draw_rect(r, Color(UiKit.C_MAIN.r, UiKit.C_MAIN.g, UiKit.C_MAIN.b, 0.3), false, 1.0)
	var x: float = r.position.x + 22.0 * s
	var y: float = r.position.y + 40.0 * s
	if selected < 0:
		_txt(Vector2(x, y), "No star selected", 22.0, UiKit.C_TEXT_DIM, true)
		_txt(Vector2(x, y + 36.0 * s), "Click a star to see its system.", 16.0, UiKit.C_TEXT_DIM)
		_txt(Vector2(x, y + 62.0 * s), "Stars inside the ring are in jump range.", 16.0, UiKit.C_TEXT_DIM)
		_txt(Vector2(x, y + 100.0 * s), "Warp cells: %d" % Game.get_item("warp_cells"), 18.0, UiKit.C_TEXT, true)
		_txt(Vector2(x, y + 126.0 * s), "Sodium %d   Ferrite %d" % [Game.get_item("sodium"), Game.get_item("ferrite")], 16.0, UiKit.C_TEXT_DIM)
		return
	var st: Dictionary = galaxy.stars[selected]
	_txt(Vector2(x, y), String(st["name"]), 30.0, UiKit.C_WARN, true)
	y += 30.0 * s
	_txt(Vector2(x, y), "%s   |   Class %s star" % [galaxy.region_name(selected), st["cls"]], 16.0, UiKit.C_TEXT_DIM)
	y += 38.0 * s
	var dly: float = galaxy.distance_ly(current, selected)
	_txt(Vector2(x, y), "Distance: %s ly" % _fmt_int(int(dly)), 20.0, UiKit.C_TEXT, true)
	y += 28.0 * s
	var from_core: float = (st["pos"] as Vector3).length()
	_txt(Vector2(x, y), "From the galactic core: %s ly" % _fmt_int(int(from_core)), 16.0, UiKit.C_TEXT_DIM)
	y += 30.0 * s
	var sys2: SystemData = _get_system(selected)
	if sys2 != null:
		_txt(Vector2(x, y), "%d worlds, %d landable" % [sys2.bodies.size(), sys2.landable_bodies().size()], 18.0, UiKit.C_TEXT, true)
		y += 26.0 * s
		var kinds: Dictionary = {}
		for b in sys2.bodies:
			if b.kind == "gas":
				kinds["Gas giant"] = true
			else:
				kinds[b.biome_label()] = true
		_txt(Vector2(x, y), ", ".join(kinds.keys()), 15.0, UiKit.C_TEXT_DIM, false, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40.0 * s)
		y += 28.0 * s
		if sys2.has_black_hole:
			_txt(Vector2(x, y), "BLACK HOLE in this system", 17.0, Color(0.9, 0.55, 1.0), true)
			y += 24.0 * s
			var dest: int = sys2.bh_dest_index
			if dest >= 0:
				_txt(Vector2(x, y), "leads ~7,000 ly towards the core: %s" % galaxy.stars[dest]["name"], 15.0, UiKit.C_TEXT_DIM)
				y += 22.0 * s
	y += 14.0 * s
	var why: String = _jump_status(selected)
	if why == "":
		_txt(Vector2(x, y), "Jump ready - costs 1 warp cell", 18.0, UiKit.C_GOOD, true)
	else:
		_txt(Vector2(x, y), why, 17.0, UiKit.C_WARN, true, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40.0 * s)
	y += 44.0 * s
	_txt(Vector2(x, y), "Warp cells: %d" % Game.get_item("warp_cells"), 18.0, UiKit.C_TEXT, true)
	_txt(Vector2(x, y + 26.0 * s), "Sodium %d   Ferrite %d" % [Game.get_item("sodium"), Game.get_item("ferrite")], 16.0, UiKit.C_TEXT_DIM)

func _fmt_int(v: int) -> String:
	var t: String = str(v)
	var out: String = ""
	var n: int = t.length()
	for i in n:
		out += t[i]
		if (n - i - 1) % 3 == 0 and i < n - 1:
			out += ","
	return out

func _get_system(idx: int) -> SystemData:
	if not _sys_cache.has(idx):
		_sys_cache[idx] = SystemGen.generate(idx)
	return _sys_cache[idx]

# ----------------------------------------------------------------------------------------- system orrery
func _orrery_scale() -> float:
	var maxr: float = 100000.0
	for b in world.sys.bodies:
		if b.parent < 0:
			maxr = maxf(maxr, b.orbit_r)
	if world.sys.has_black_hole:
		maxr = maxf(maxr, world.sys.bh_orbit_r)
	return (minf(size.x - 700.0 * s, size.y - 220.0 * s) * 0.5) / sqrt(maxr)

func _orr_xy(sys_pos: D3) -> Vector2:
	# square-root radial scaling so inner planets stay readable
	var v := Vector2(sys_pos.x, sys_pos.z)
	var r: float = v.length()
	if r < 1.0:
		return Vector2.ZERO
	var rr: float = sqrt(r) * _orrery_scale()
	return v / r * rr

func _orrery_pos(i: int, t: float) -> Vector2:
	var b: BodyData = world.sys.bodies[i]
	var center: Vector2 = Vector2(size.x * 0.5 - 140.0 * s, size.y * 0.5 + 10.0 * s)
	if b.parent >= 0:
		var pp: D3 = world.body_pos(b.parent, t)
		var base: Vector2 = _orr_xy(pp)
		var moon_off: Vector3 = SystemGen.orbit_offset(b, t)
		var dir: Vector2 = Vector2(moon_off.x, moon_off.z).normalized()
		return center + base + dir * (24.0 * s + 9.0 * s * float(b.index % 3))
	return center + _orr_xy(world.body_pos(i, t))

func _draw_system(sz: Vector2) -> void:
	var sys: SystemData = world.sys
	var center: Vector2 = Vector2(sz.x * 0.5 - 140.0 * s, sz.y * 0.5 + 10.0 * s)
	var sc: float = _orrery_scale()
	# star
	draw_texture_rect(_glow, Rect2(center - Vector2(60, 60) * s, Vector2(120, 120) * s), false, Color(sys.star_color.r, sys.star_color.g, sys.star_color.b, 0.5))
	draw_circle(center, 9.0 * s, sys.star_color)
	_txt(center + Vector2(14, -12) * s, sys.star_name, 15.0, UiKit.C_TEXT_DIM)
	# orbits
	for b in sys.bodies:
		if b.parent < 0:
			draw_arc(center, sqrt(b.orbit_r) * sc, 0.0, TAU, 128, Color(0.4, 0.7, 0.9, 0.22), 1.0 * s, true)
	if sys.has_black_hole:
		draw_arc(center, sqrt(sys.bh_orbit_r) * sc, 0.0, TAU, 128, Color(0.8, 0.4, 1.0, 0.18), 1.0 * s, true)
		var bp: Vector2 = center + _orr_xy(world.bh_pos_sys())
		draw_circle(bp, 7.0 * s, Color(0, 0, 0))
		draw_arc(bp, 9.0 * s, 0.0, TAU, 24, Color(1.0, 0.6, 0.3), 2.0 * s, true)
		_txt(bp + Vector2(14, 4) * s, "Black hole", 15.0, Color(0.95, 0.6, 1.0), true)
	# planets (accelerated time) and real "now" markers
	for i in sys.bodies.size():
		var b: BodyData = sys.bodies[i]
		var p: Vector2 = _orrery_pos(i, world.time + _orr_t)
		var pnow: Vector2 = _orrery_pos(i, world.time)
		var col: Color = _body_color(b)
		var rad: float = (7.0 + b.radius / 3000.0 * 1.8) * s
		if b.kind == "moon":
			rad = 4.0 * s
		if b.kind == "gas":
			rad = 12.0 * s
			if not b.rings.is_empty():
				draw_arc(p, 18.0 * s, 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.5), 2.0 * s, true)
		draw_arc(pnow, rad + 3.0 * s, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 1.0 * s, true)
		draw_circle(p, rad, col)
		var sel: bool = i == _sel_body or i == pc.ship.target_idx
		if sel:
			draw_arc(p, rad + 6.0 * s, 0.0, TAU, 28, UiKit.C_WARN, 2.0 * s, true)
		_txt(p + Vector2(rad + 8.0 * s, 5.0 * s), b.name, 15.0, UiKit.C_WARN if sel else UiKit.C_TEXT)
	# the ship at its real position
	var vs: D3 = world.viewer_sys_now()
	var sp: Vector2 = center + _orr_xy(vs)
	var tri := PackedVector2Array([sp + Vector2(0, -9) * s, sp + Vector2(7, 7) * s, sp + Vector2(-7, 7) * s])
	draw_colored_polygon(tri, UiKit.C_MAIN)
	_txt(sp + Vector2(10, -6) * s, "YOU", 14.0, UiKit.C_MAIN, true)
	# info panel
	var r := Rect2(Vector2(sz.x - 440.0 * s, 90.0 * s), Vector2(410.0 * s, sz.y - 180.0 * s))
	draw_rect(r, Color(0.02, 0.05, 0.09, 0.78))
	draw_rect(r, Color(UiKit.C_MAIN.r, UiKit.C_MAIN.g, UiKit.C_MAIN.b, 0.3), false, 1.0)
	var x: float = r.position.x + 22.0 * s
	var y: float = r.position.y + 40.0 * s
	_txt(Vector2(x, y), "ORRERY  x%d" % int(ORRERY_SPEED), 20.0, UiKit.C_MAIN, true)
	_txt(Vector2(x, y + 24.0 * s), "filled dots: accelerated orbits   rings: real positions now", 13.0, UiKit.C_TEXT_DIM)
	y += 62.0 * s
	var bi: int = _sel_body if _sel_body >= 0 else pc.ship.target_idx
	if bi >= 0 and bi < sys.bodies.size():
		var b2: BodyData = sys.bodies[bi]
		_txt(Vector2(x, y), b2.name, 28.0, UiKit.C_WARN, true)
		y += 28.0 * s
		var kind_txt: String = "Gas giant" if b2.kind == "gas" else "%s %s" % [b2.biome_label(), "moon" if b2.kind == "moon" else "planet"]
		_txt(Vector2(x, y), kind_txt, 18.0, UiKit.C_TEXT, true)
		y += 26.0 * s
		_txt(Vector2(x, y), "Radius %.1f km   Gravity %.1f m/s2" % [b2.radius / 1000.0, b2.gravity], 15.0, UiKit.C_TEXT_DIM)
		y += 22.0 * s
		_txt(Vector2(x, y), "Day %d min   Orbit %.1f h" % [int(b2.spin_period / 60.0), b2.orbit_period / 3600.0], 15.0, UiKit.C_TEXT_DIM)
		y += 22.0 * s
		var hz: Dictionary = b2.profile.get("hazard", {})
		if b2.kind != "gas":
			_txt(Vector2(x, y), "Hazard: %s   Temp %d C" % [String(hz.get("type", "none")), int(hz.get("temp", 20))], 15.0, UiKit.C_TEXT_DIM)
			y += 22.0 * s
			_txt(Vector2(x, y), "Atmosphere: %s" % ("breathable-looking haze" if bool(b2.profile.get("atm", {}).get("on", false)) else "none (vacuum)"), 15.0, UiKit.C_TEXT_DIM)
		y += 34.0 * s
		var dist: float = world.viewer_sys_now().dist(world.body_pos(bi, world.time))
		_txt(Vector2(x, y), "Distance now: %s" % U.fmt_dist(dist), 17.0, UiKit.C_TEXT, true)
		_txt(Vector2(x, y + 26.0 * s), "Target set - press Z in flight for auto-pulse", 15.0, UiKit.C_GOOD)
	else:
		_txt(Vector2(x, y), "Click a world to target it.", 17.0, UiKit.C_TEXT_DIM)

func _body_color(b: BodyData) -> Color:
	match b.biome:
		"lush": return Color(0.35, 0.8, 0.4)
		"desert": return Color(0.9, 0.62, 0.32)
		"volcanic": return Color(1.0, 0.35, 0.15)
		"frozen": return Color(0.75, 0.9, 1.0)
		"toxic": return Color(0.7, 0.85, 0.2)
		"dead": return Color(0.7, 0.7, 0.72)
		"radioactive": return Color(0.45, 1.0, 0.4)
		"gas": return Color(0.9, 0.75, 0.5)
	return Color.WHITE
