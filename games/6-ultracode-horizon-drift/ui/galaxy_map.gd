class_name GalaxyMap
extends Control
## GALAXY MAP (module M6). Full-screen map of the 720 stars: volumetric spiral-galaxy backdrop (ui_galaxy shader) + additive star sprites,
## orbit / pan / zoom camera, hover + click selection, info card with warp cost, black-hole links, hyperdrive range rings.
## Overlay contract: Game.toggle_overlay() calls open() / close() (process_mode ALWAYS).

const CLASS_SIZE := {"O": 1.55, "B": 1.4, "A": 1.22, "F": 1.1, "G": 1.0, "K": 0.9, "M": 0.78}
const CLASS_DESC := {
	"O": "Blue supergiant", "B": "Blue-white giant", "A": "White main-sequence star", "F": "Yellow-white star",
	"G": "Yellow dwarf", "K": "Orange dwarf", "M": "Red dwarf",
}
const DIST_MIN := 1500.0
const DIST_MAX := 150000.0

# ------------------------------------------------------------------------------------------------------------------------------
class StarLayer extends Control:
	var map: GalaxyMap
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = UITheme.additive_material()
	func _draw() -> void:
		if map != null:
			map._draw_stars(self)

class OverLayer extends Control:
	var map: GalaxyMap
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if map != null:
			map._draw_overlay(self)

class Row extends Control:
	signal picked(id: int)
	var star_id: int = -1
	var map: GalaxyMap
	var _hover: bool = false
	func _init() -> void:
		custom_minimum_size = Vector2(0, 33)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			UITheme.sfx("ui_click")
			picked.emit(star_id)
			accept_event()
	func _draw() -> void:
		if star_id < 0:
			return
		var gs: GalaxyStar = Universe.galaxy[star_id]
		var sel: bool = map != null and map._selected == star_id
		if _hover or sel:
			draw_rect(Rect2(Vector2.ZERO, size), UITheme.ca(UITheme.ACCENT, 0.14 if sel else 0.08))
			draw_rect(Rect2(0, 0, 3, size.y), UITheme.ACCENT if sel else UITheme.ca(UITheme.ACCENT, 0.5))
		var c := Vector2(20.0, size.y * 0.5)
		draw_texture_rect(UITheme.glow_tex(), Rect2(c - Vector2(11, 11), Vector2(22, 22)), false, UITheme.ca(gs.color, 0.6))
		draw_circle(c, 3.6, gs.color.lerp(Color.WHITE, 0.4))
		var nw := UITheme.text(self, Vector2(38.0, size.y * 0.5 + 5.0), gs.name, 15, UITheme.TEXT, 0.0, null, false)
		var cur: GalaxyStar = Universe.current_star()
		var d := cur.distance_to(gs)
		UITheme.text(self, Vector2(size.x - 10.0, size.y * 0.5 + 5.0), UITheme.fmt_ly(d), 13, UITheme.TEXT_DIM, 1.0, null, false)
		if gs.has_black_hole:
			draw_arc(Vector2(38.0 + nw + 14.0, size.y * 0.5), 5.0, 0, TAU, 16, UITheme.ca(UITheme.VIOLET, 0.9), 1.5, true)
			draw_circle(Vector2(38.0 + nw + 14.0, size.y * 0.5), 1.8, UITheme.VIOLET)

# ------------------------------------------------------------------------------------------------------------------------------
var _cam: GalaxyCam = GalaxyCam.new()
var _t_yaw: float = 0.0
var _t_pitch: float = 0.85
var _t_dist: float = 92000.0
var _t_focus: Vector3 = Vector3.ZERO
var _bg: ColorRect
var _mat: ShaderMaterial
var _stars_layer: StarLayer
var _over: OverLayer
var _screen: PackedVector2Array = PackedVector2Array()
var _depth: PackedFloat32Array = PackedFloat32Array()
var _hover: int = -1
var _selected: int = -1
var _drag: int = 0               # 0 none, 1 orbit, 2 pan
var _press_pos: Vector2 = Vector2.ZERO
var _drag_dist: float = 0.0
var _t: float = 0.0
var _idle: float = 0.0
var _open_t: float = 0.0
var _msg_text: String = ""
var _msg_col: Color = Color.WHITE
var _msg_t: float = 0.0
var _shake: float = 0.0
var _card_for: int = -2
var _card_refresh: float = 0.0
var _show_rings: bool = true

# UI nodes
var _panel_top: Control
var _cells_label: Label
var _sub_label: Label
var _list_box: VBoxContainer
var _card: UIPanel
var _c_swatch: Control
var _c_name: Label
var _c_class: Label
var _c_tag: Label
var _c_grid: Dictionary = {}
var _c_biomes: RichTextLabel
var _c_cost: Label
var _c_msg: Label
var _c_btn: UIButton
var _list_panel: UIPanel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/ui_galaxy.gdshader")
	_mat.set_shader_parameter("steps", 44)
	_mat.set_shader_parameter("brightness", 1.5)
	_bg.material = _mat
	add_child(_bg)
	_stars_layer = StarLayer.new()
	_stars_layer.map = self
	_stars_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stars_layer)
	_over = OverLayer.new()
	_over.map = self
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_over)
	_screen.resize(Universe.galaxy.size())
	_depth.resize(Universe.galaxy.size())
	_build_ui()
	visible = false
	set_process(false)

# ==============================================================================================================================
# UI construction
# ==============================================================================================================================
func _build_ui() -> void:
	# ---- top bar
	_panel_top = Control.new()
	_panel_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_panel_top.offset_bottom = 96.0
	_panel_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_top)
	var grad := ColorRect.new()
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grad.color = Color(0, 0.01, 0.03, 0.0)
	_panel_top.add_child(grad)
	var tb := HBoxContainer.new()
	tb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tb.offset_left = 30.0
	tb.offset_right = -30.0
	tb.offset_top = 20.0
	tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_top.add_child(tb)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(UITheme.label("HYPERDRIVE NAVIGATION", 13, UITheme.ACCENT, true))
	tv.add_child(UITheme.label("GALAXY MAP", 36, UITheme.TEXT, true))
	_sub_label = UITheme.label("", 14, UITheme.TEXT_DIM)
	tv.add_child(_sub_label)
	tb.add_child(tv)
	var cells := UIPanel.new(10, "")
	cells.cut = 8.0
	cells.custom_minimum_size = Vector2(200, 0)
	_cells_label = UITheme.label("", 18, UITheme.TEXT, true)
	_cells_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cells.add_content(_cells_label)
	var cwrap := VBoxContainer.new()
	cwrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cwrap.add_child(cells)
	tb.add_child(cwrap)
	tb.add_child(UITheme.spacer(0, 14))
	var close_btn := UIButton.new("CLOSE   [M]", "primary")
	close_btn.custom_minimum_size = Vector2(170, 44)
	close_btn.pressed.connect(func(): Game.close_overlays())
	var cb2 := VBoxContainer.new()
	cb2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cb2.add_child(close_btn)
	tb.add_child(cb2)
	# ---- left: nearby stars
	_list_panel = UIPanel.new(12, "NEARBY STARS")
	_list_panel.anchor_left = 0.0
	_list_panel.anchor_right = 0.0
	_list_panel.anchor_top = 0.0
	_list_panel.anchor_bottom = 0.0
	_list_panel.offset_left = 26.0
	_list_panel.offset_right = 26.0 + 300.0
	_list_panel.offset_top = 112.0
	_list_panel.offset_bottom = 112.0
	_list_panel.custom_minimum_size = Vector2(300, 0)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 1)
	_list_panel.add_content(_list_box)
	add_child(_list_panel)
	# ---- right: info card
	_card = UIPanel.new(18, "STAR SYSTEM")
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.anchor_top = 0.0
	_card.anchor_bottom = 0.0
	_card.offset_left = -26.0 - 350.0
	_card.offset_right = -26.0
	_card.offset_top = 112.0
	_card.offset_bottom = 112.0
	_card.custom_minimum_size = Vector2(350, 0)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	_card.add_content(cv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_c_swatch = Control.new()
	_c_swatch.custom_minimum_size = Vector2(40, 40)
	_c_swatch.draw.connect(_draw_swatch)
	head.add_child(_c_swatch)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", -2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c_name = UITheme.label("", 26, UITheme.TEXT, true)
	hv.add_child(_c_name)
	_c_class = UITheme.label("", 14, UITheme.TEXT_DIM)
	hv.add_child(_c_class)
	head.add_child(hv)
	cv.add_child(head)
	_c_tag = UITheme.label("", 13, UITheme.GOLD, true)
	cv.add_child(_c_tag)
	cv.add_child(UITheme.hline())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	for k in ["DISTANCE", "SYSTEM", "BLACK HOLE", "STATUS"]:
		var kl := UITheme.label(k, 12, UITheme.TEXT_FAINT, true)
		kl.custom_minimum_size = Vector2(110, 0)
		grid.add_child(kl)
		var vl := UITheme.label("-", 15, UITheme.TEXT)
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(vl)
		_c_grid[k] = vl
	cv.add_child(grid)
	_c_biomes = RichTextLabel.new()
	_c_biomes.bbcode_enabled = true
	_c_biomes.fit_content = true
	_c_biomes.scroll_active = false
	_c_biomes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c_biomes.add_theme_font_override("normal_font", UITheme.font())
	_c_biomes.add_theme_font_size_override("normal_font_size", 14)
	_c_biomes.add_theme_color_override("default_color", UITheme.TEXT_DIM)
	cv.add_child(_c_biomes)
	cv.add_child(UITheme.hline())
	cv.add_child(UITheme.label("HYPERDRIVE", 12, UITheme.TEXT_FAINT, true))
	_c_cost = UITheme.label("", 16, UITheme.TEXT)
	cv.add_child(_c_cost)
	_c_msg = UITheme.label("", 14, UITheme.DANGER)
	_c_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_c_msg.custom_minimum_size = Vector2(300, 0)
	cv.add_child(_c_msg)
	_c_btn = UIButton.new("ENGAGE HYPERDRIVE   [ENTER]", "primary")
	_c_btn.custom_minimum_size = Vector2(0, 48)
	_c_btn.pressed.connect(_engage)
	cv.add_child(_c_btn)
	add_child(_card)
	# ---- bottom-left: view buttons
	var bl := HBoxContainer.new()
	bl.anchor_left = 0.0
	bl.anchor_right = 0.0
	bl.anchor_top = 1.0
	bl.anchor_bottom = 1.0
	bl.offset_left = 26.0
	bl.offset_top = -80.0
	bl.offset_bottom = -46.0
	bl.offset_right = 26.0 + 520.0
	bl.add_theme_constant_override("separation", 8)
	var b1 := UIButton.new("GALAXY VIEW", "small")
	b1.pressed.connect(_view_galaxy)
	var b2 := UIButton.new("FOCUS SELECTED", "small")
	b2.pressed.connect(func(): _focus_on(_selected if _selected >= 0 else Universe.current_id, 12000.0))
	var b3 := UIButton.new("CENTRE ON ME", "small")
	b3.pressed.connect(func(): _focus_on(Universe.current_id, 14000.0))
	var b4 := UIButton.new("RANGE RINGS", "small")
	b4.pressed.connect(func(): _show_rings = not _show_rings)
	for b in [b1, b2, b3, b4]:
		bl.add_child(b)
	add_child(bl)

func _draw_swatch() -> void:
	var id := _card_for if _card_for >= 0 else Universe.current_id
	var gs: GalaxyStar = Universe.get_star(id)
	var c := Vector2(20, 20)
	_c_swatch.draw_texture_rect(UITheme.glow_tex(), Rect2(c - Vector2(20, 20), Vector2(40, 40)), false, UITheme.ca(gs.color, 0.9))
	_c_swatch.draw_circle(c, 8.0, gs.color.lerp(Color.WHITE, 0.35))
	_c_swatch.draw_arc(c, 13.0, 0, TAU, 32, UITheme.ca(gs.color, 0.7), 1.5, true)

# ==============================================================================================================================
# open / close
# ==============================================================================================================================
func open() -> void:
	visible = true
	set_process(true)
	_set_world_rendering(false)
	_t = 0.0
	_open_t = 0.0
	_selected = -1
	_hover = -1
	_drag = 0
	_card_for = -2
	var cur: GalaxyStar = Universe.current_star()
	_t_yaw = atan2(cur.pos.x, cur.pos.z)
	_t_pitch = 0.82
	_t_dist = 98000.0
	_t_focus = Vector3.ZERO
	_cam.yaw = _t_yaw + 0.5
	_cam.pitch = 0.35
	_cam.dist = 160000.0
	_cam.target = Vector3.ZERO
	_msg_text = ""
	_rebuild_list()
	_update_header()
	UITheme.sfx("ui_open")
	_apply_cam()

func close() -> void:
	visible = false
	set_process(false)
	_drag = 0
	_set_world_rendering(true)

## the map is a fully opaque screen: skip the (expensive) 3D world render behind it while it is open
func _set_world_rendering(on: bool) -> void:
	var vp := get_viewport()
	if vp != null:
		vp.disable_3d = not on

func _exit_tree() -> void:
	_set_world_rendering(true)

func _update_header() -> void:
	var visited := Game.visited_systems.size()
	_sub_label.text = "%d stars charted   -   %d visited   -   you are in the %s system" % [Universe.galaxy.size(), visited, Universe.current_star().name]
	_cells_label.text = "WARP CELLS   %d" % Game.warp_cells

func _rebuild_list() -> void:
	for c in _list_box.get_children():
		c.queue_free()
	var cur_id := Universe.current_id
	var near := Universe.nearest_stars(cur_id, 9)
	for s in near:
		var r := Row.new()
		r.star_id = (s as GalaxyStar).id
		r.map = self
		r.picked.connect(func(id: int):
			_selected = id
			_focus_on(id, 9000.0))
		_list_box.add_child(r)

# ==============================================================================================================================
# camera
# ==============================================================================================================================
func _apply_cam() -> void:
	_cam.update()
	_cam.apply(_mat, size)

func _view_galaxy() -> void:
	var cur: GalaxyStar = Universe.current_star()
	_t_focus = Vector3.ZERO
	_t_dist = 98000.0
	_t_pitch = 0.82
	_t_yaw = atan2(cur.pos.x, cur.pos.z)

func _focus_on(id: int, dist: float) -> void:
	var gs: GalaxyStar = Universe.get_star(id)
	_t_focus = gs.pos
	_t_dist = clampf(dist, DIST_MIN, DIST_MAX)

# ==============================================================================================================================
# frame update
# ==============================================================================================================================
func _process(dt: float) -> void:
	if not visible:
		return
	dt = minf(dt, 0.05)
	_t += dt
	_open_t += dt
	_idle += dt
	_msg_t = maxf(_msg_t - dt, 0.0)
	_shake = maxf(_shake - dt * 3.0, 0.0)
	# smooth camera
	var k := 1.0 - exp(-9.0 * dt)
	if _drag == 0 and _idle > 14.0:
		_t_yaw += dt * 0.015
	_cam.yaw = lerp_angle(_cam.yaw, _t_yaw, k)
	_t_pitch = clampf(_t_pitch, 0.08, 1.5)
	_cam.pitch = lerpf(_cam.pitch, _t_pitch, k)
	_t_dist = clampf(_t_dist, DIST_MIN, DIST_MAX)
	_cam.dist = exp(lerpf(log(_cam.dist), log(_t_dist), 1.0 - exp(-6.0 * dt)))
	_cam.target = _cam.target.lerp(_t_focus, 1.0 - exp(-7.0 * dt))
	_apply_cam()
	_project_all()
	# hover (only when the pointer is on the map itself, not on a panel)
	if _drag == 0:
		var hc := get_viewport().gui_get_hovered_control()
		if hc == self:
			_hover = _pick(get_local_mouse_position())
		elif hc != null:
			_hover = -1            # pointer is over a panel / button
		elif _hover >= 0 and _depth[_hover] < 1.0:
			_hover = -1
	_card_refresh -= dt
	var want := _selected if _selected >= 0 else Universe.current_id
	if want != _card_for or _card_refresh <= 0.0:
		_card_for = want
		_card_refresh = 0.4
		_update_card()
		_update_header()
	_stars_layer.queue_redraw()
	_over.queue_redraw()

func _project_all() -> void:
	var vp := size
	var n := Universe.galaxy.size()
	for i in n:
		var gs: GalaxyStar = Universe.galaxy[i]
		var p := _cam.project(gs.pos, vp)
		_screen[i] = Vector2(p.x, p.y)
		_depth[i] = p.z

func _core_size(i: int) -> float:
	var gs: GalaxyStar = Universe.galaxy[i]
	var cs: float = CLASS_SIZE.get(gs.spectral_class, 1.0)
	var persp := clampf(_cam.dist / maxf(_depth[i], 1.0), 0.45, 2.6)
	return (1.5 + 1.25 * cs) * pow(persp, 0.65)

func _pick(pos: Vector2) -> int:
	var best := -1
	var bd := 1.0e9
	for i in _screen.size():
		if _depth[i] < 1.0:
			continue
		var d := _screen[i].distance_to(pos)
		var lim := maxf(12.0, _core_size(i) * 2.0 + 4.0)
		if d < lim and d - _core_size(i) < bd:
			bd = d - _core_size(i)
			best = i
	return best

# ==============================================================================================================================
# input
# ==============================================================================================================================
func _gui_input(ev: InputEvent) -> void:
	_idle = 0.0
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_drag = 1
					_press_pos = mb.position
					_drag_dist = 0.0
					if mb.double_click:
						var id := _pick(mb.position)
						if id >= 0:
							_selected = id
							_focus_on(id, 7000.0)
				else:
					if _drag == 1 and _drag_dist < 6.0:
						var id2 := _pick(mb.position)
						_selected = id2
						if id2 >= 0:
							UITheme.sfx("ui_click")
					_drag = 0
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_drag = 2 if mb.pressed else 0
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom(0.86, mb.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom(1.0 / 0.86, mb.position)
		accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _drag == 0:
			_hover = _pick(mm.position)
		if _drag == 1:
			_drag_dist += mm.relative.length()
			if _drag_dist >= 6.0:
				_t_yaw -= mm.relative.x * 0.0055
				_t_pitch += mm.relative.y * 0.0045
				_cam.yaw = _t_yaw
				_cam.pitch = clampf(_t_pitch, 0.08, 1.5)
		elif _drag == 2:
			var scale := _cam.dist * _cam.tan_half * 2.0 / maxf(size.y, 1.0)
			var right := _cam.basis.x
			var fwd := Vector3(-sin(_cam.yaw), 0.0, -cos(_cam.yaw))
			_t_focus += (-right * mm.relative.x + fwd * mm.relative.y / maxf(sin(_cam.pitch), 0.25)) * scale
			_t_focus.y = clampf(_t_focus.y, -6000.0, 6000.0)
			_cam.target = _t_focus
		accept_event()
	elif ev is InputEventMagnifyGesture:
		_zoom(1.0 / maxf((ev as InputEventMagnifyGesture).factor, 0.1), size * 0.5)

func _zoom(f: float, _at: Vector2) -> void:
	_t_dist = clampf(_t_dist * f, DIST_MIN, DIST_MAX)

func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	if ev is InputEventKey and (ev as InputEventKey).pressed:
		var kc := (ev as InputEventKey).keycode
		_idle = 0.0
		match kc:
			KEY_ENTER, KEY_KP_ENTER:
				_engage()
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				_t_yaw += 0.15
			KEY_RIGHT:
				_t_yaw -= 0.15
			KEY_UP:
				_t_pitch += 0.1
			KEY_DOWN:
				_t_pitch -= 0.1
			KEY_EQUAL, KEY_KP_ADD, KEY_PAGEUP:
				_t_dist *= 0.8
			KEY_MINUS, KEY_KP_SUBTRACT, KEY_PAGEDOWN:
				_t_dist *= 1.25
			KEY_HOME:
				_view_galaxy()
			KEY_BACKSPACE:
				_selected = -1
			KEY_TAB:
				_cycle_selection()
				get_viewport().set_input_as_handled()

func _cycle_selection() -> void:
	var near := Universe.nearest_stars(Universe.current_id, 9)
	if near.is_empty():
		return
	var idx := -1
	for i in near.size():
		if (near[i] as GalaxyStar).id == _selected:
			idx = i
	var nxt: GalaxyStar = near[(idx + 1) % near.size()]
	_selected = nxt.id
	_focus_on(nxt.id, 9000.0)

# ==============================================================================================================================
# warp
# ==============================================================================================================================
func _engage() -> void:
	if _selected < 0:
		_say("Select a destination star first", UITheme.WARN)
		UITheme.sfx("warn_beep")
		return
	if _selected == Universe.current_id:
		_say("You are already in the %s system" % Universe.current_star().name, UITheme.WARN)
		return
	var reason := Game.try_hyperdrive(_selected)
	if reason != "":
		_say(reason, UITheme.DANGER)
		Events.notify.emit(reason, "warn")
		UITheme.sfx("warn_beep")
		_shake = 1.0
	else:
		UITheme.sfx("ui_warp_confirm")

func _say(text: String, col: Color) -> void:
	_msg_text = text
	_msg_col = col
	_msg_t = 6.0
	_update_card()

# ==============================================================================================================================
# card
# ==============================================================================================================================
func _update_card() -> void:
	var id := _card_for if _card_for >= 0 else Universe.current_id
	var gs: GalaxyStar = Universe.get_star(id)
	var cur: GalaxyStar = Universe.current_star()
	var is_cur := id == cur.id
	_c_name.text = gs.name.to_upper()
	_c_class.text = "%s-class  -  %s" % [gs.spectral_class, CLASS_DESC.get(gs.spectral_class, "Star")]
	var tag := ""
	if is_cur:
		tag = "YOUR CURRENT SYSTEM"
	elif _selected == id:
		tag = "SELECTED DESTINATION"
	if gs.special:
		tag += ("   -   " if tag != "" else "") + "CHARTED"
	_c_tag.text = tag
	_card.title = "STAR SYSTEM"
	_c_swatch.queue_redraw()
	var d := cur.distance_to(gs)
	(_c_grid["DISTANCE"] as Label).text = "0 ly" if is_cur else UITheme.fmt_ly(d)
	var sys := Universe.get_system(id)
	var planets := 0
	var moons := 0
	var gas := 0
	for b in sys.bodies:
		match (b as BodyDef).kind:
			BodyDef.Kind.PLANET: planets += 1
			BodyDef.Kind.MOON: moons += 1
			BodyDef.Kind.GAS_GIANT: gas += 1
	(_c_grid["SYSTEM"] as Label).text = "%d planets, %d moons" % [planets + gas, moons]
	if gs.has_black_hole:
		var dest := Universe.black_hole_destination(id)
		(_c_grid["BLACK HOLE"] as Label).text = "Yes  >  %s" % Universe.get_star(dest).name
		(_c_grid["BLACK HOLE"] as Label).add_theme_color_override("font_color", UITheme.VIOLET)
	else:
		(_c_grid["BLACK HOLE"] as Label).text = "None detected"
		(_c_grid["BLACK HOLE"] as Label).add_theme_color_override("font_color", UITheme.TEXT)
	var visited := Game.visited_systems.has(id)
	(_c_grid["STATUS"] as Label).text = "Visited" if visited else "Unexplored"
	(_c_grid["STATUS"] as Label).add_theme_color_override("font_color", UITheme.GOOD if visited else UITheme.TEXT_DIM)
	# biome chips
	var bb := ""
	for biome in sys.biome_set():
		var col := UITheme.biome_color(str(biome))
		var nm: String = BiomeDB.get_biome(str(biome)).get("name", str(biome))
		bb += "[color=#%s]●[/color] %s    " % [col.to_html(false), nm]
	_c_biomes.text = bb
	# cost / button
	var cost := Game.hyperdrive_cost(id)
	if is_cur:
		_c_cost.text = "You are here"
		_c_cost.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		_c_btn.visible = false
	else:
		_c_btn.visible = true
		var enough := Game.warp_cells >= cost
		_c_cost.text = "Cost:  %d warp cell%s      (you have %d)" % [cost, "" if cost == 1 else "s", Game.warp_cells]
		_c_cost.add_theme_color_override("font_color", UITheme.TEXT if enough else UITheme.WARN)
		_c_btn.disabled = false
		_c_btn.text = "ENGAGE HYPERDRIVE   [ENTER]" if _selected == id else "SELECT TO WARP"
		_c_btn.set_accent(UITheme.ACCENT if enough else UITheme.WARN)
	if _msg_t > 0.0 and _msg_text != "":
		_c_msg.text = _msg_text
		_c_msg.add_theme_color_override("font_color", _msg_col)
	else:
		_c_msg.text = ""

# ==============================================================================================================================
# drawing: additive star layer
# ==============================================================================================================================
func _draw_stars(ci: Control) -> void:
	var tex := UITheme.glow_tex()
	var rect := Rect2(Vector2(-40, -40), size + Vector2(80, 80))
	var open_k := UITheme.ease_out(_open_t / 1.2)
	for i in _screen.size():
		if _depth[i] < 1.0:
			continue
		var sp := _screen[i]
		if not rect.has_point(sp):
			continue
		var gs: GalaxyStar = Universe.galaxy[i]
		var core := _core_size(i)
		var persp := clampf(_cam.dist / maxf(_depth[i], 1.0), 0.45, 2.6)
		var a := clampf(0.55 + 0.35 * persp, 0.5, 1.0) * open_k
		var gsz := core * 7.5
		ci.draw_texture_rect(tex, Rect2(sp - Vector2(gsz, gsz) * 0.5, Vector2(gsz, gsz)), false, UITheme.ca(gs.color, 0.62 * a))
		ci.draw_circle(sp, core * 0.62, UITheme.ca(Color(1, 1, 1).lerp(gs.color, 0.25), 0.95 * a))
		if CLASS_SIZE.get(gs.spectral_class, 1.0) >= 1.4 and persp > 0.9:
			var ln := core * 3.6
			ci.draw_line(sp + Vector2(-ln, 0), sp + Vector2(ln, 0), UITheme.ca(gs.color, 0.22 * a), 1.0)
			ci.draw_line(sp + Vector2(0, -ln), sp + Vector2(0, ln), UITheme.ca(gs.color, 0.22 * a), 1.0)
	# hover / selected / current halo (additive glow)
	for id in [_hover, _selected, Universe.current_id]:
		if id >= 0 and _depth[id] >= 1.0:
			var sp2 := _screen[id]
			var g2 := _core_size(id) * 11.0
			var gs2: GalaxyStar = Universe.galaxy[id]
			ci.draw_texture_rect(tex, Rect2(sp2 - Vector2(g2, g2) * 0.5, Vector2(g2, g2)), false, UITheme.ca(gs2.color, 0.55))

# ==============================================================================================================================
# drawing: overlay layer (rings, links, labels, reticles)
# ==============================================================================================================================
func _p3(p: Vector3) -> Vector3:
	return _cam.project(p, size)

func _poly(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		var s := _p3(p as Vector3)
		if s.z >= 1.0:
			out.append(Vector2(s.x, s.y))
	return out

func _clip_t(a: Vector2, b: Vector2, r: Rect2) -> Vector2:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	var p: Array[float] = [-d.x, d.x, -d.y, d.y]
	var q: Array[float] = [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y]
	for i in 4:
		if absf(p[i]) < 1.0e-9:
			if q[i] < 0.0:
				return Vector2(1.0, 0.0)
		else:
			var t: float = q[i] / p[i]
			if p[i] < 0.0:
				if t > t1:
					return Vector2(1.0, 0.0)
				t0 = maxf(t0, t)
			else:
				if t < t0:
					return Vector2(1.0, 0.0)
				t1 = minf(t1, t)
	return Vector2(t0, t1)

func _dashed(ci: Control, pts: PackedVector2Array, col: Color, w: float, dash: float, gap: float, phase: float) -> void:
	var pat := dash + gap
	var acc := -fposmod(phase, pat)
	var rect := Rect2(Vector2(-60, -60), size + Vector2(120, 120))
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.01:
			continue
		var tt := _clip_t(a, b, rect)
		if tt.x < tt.y:
			var dir := (b - a) / seg
			var pos := tt.x * seg
			var end := tt.y * seg
			var guard := 0
			while pos < end and guard < 700:
				guard += 1
				var m := fposmod(acc + pos, pat)
				if m < dash:
					var len_d := maxf(minf(dash - m, end - pos), 0.05)
					ci.draw_line(a + dir * pos, a + dir * (pos + len_d), col, w, true)
					pos += len_d
				else:
					pos += maxf(pat - m, 0.05)
		acc += seg

func _bh_arc(a: Vector3, b: Vector3) -> PackedVector2Array:
	var pts: Array = []
	var span := a.distance_to(b)
	for k in 25:
		var t := float(k) / 24.0
		pts.append(a.lerp(b, t) + Vector3(0.0, sin(t * PI) * span * 0.13, 0.0))
	return _poly(pts)

func _draw_overlay(ci: Control) -> void:
	var vp := size
	var cur: GalaxyStar = Universe.current_star()
	var open_k := UITheme.ease_out(_open_t / 1.0)
	# ---- hyperdrive range rings (cost tiers) on the galactic plane around the current system
	if _show_rings:
		for k in range(1, 5):
			var r := 6000.0 * float(k)
			var pts: Array = []
			for j in 97:
				var an := TAU * float(j) / 96.0
				pts.append(cur.pos + Vector3(cos(an) * r, 0.0, sin(an) * r))
			var pl := _poly(pts)
			if pl.size() > 3:
				_dashed(ci, pl, UITheme.ca(UITheme.ACCENT, 0.20 * open_k), 1.0, 6.0, 8.0, _t * 8.0)
				var best := pl[0]
				for q in pl:
					if q.x > best.x:
						best = q
				UITheme.text(ci, best + Vector2(8.0, 4.0), "%d CELLS" % (k + 1), 11, UITheme.ca(UITheme.ACCENT, 0.65 * open_k), 0.0, UITheme.font_caps(), false)
	# ---- galactic core label
	var core := _p3(Vector3.ZERO)
	if core.z >= 1.0 and _cam.dist > 30000.0:
		var cl := Vector2(core.x, core.y + 52.0)
		var cw := UITheme.text_width("GALACTIC CORE", 11, UITheme.font_caps())
		ci.draw_rect(Rect2(cl + Vector2(-cw * 0.5 - 8.0, -13.0), Vector2(cw + 16.0, 19.0)), Color(0.01, 0.02, 0.05, 0.55 * open_k))
		UITheme.text(ci, cl, "GALACTIC CORE", 11, UITheme.ca(UITheme.TEXT, 0.8 * open_k), 0.5, UITheme.font_caps(), false)
	# ---- black hole links (home <-> second system always; plus the hovered / selected / current star's link)
	var link_ids: Dictionary = {}
	link_ids[Universe.HOME_ID] = true
	for id in [_hover, _selected, cur.id]:
		if id >= 0 and Universe.get_star(id).has_black_hole:
			link_ids[id] = true
	for id in link_ids:
		var gs: GalaxyStar = Universe.get_star(id)
		var dest := Universe.black_hole_destination(id)
		var gd: GalaxyStar = Universe.get_star(dest)
		var arc := _bh_arc(gs.pos, gd.pos)
		if arc.size() > 3:
			var strong: bool = (id == Universe.HOME_ID or id == Universe.SECOND_ID)
			_dashed(ci, arc, UITheme.ca(UITheme.VIOLET, (0.85 if strong else 0.55) * open_k), 2.0 if strong else 1.4, 9.0, 6.0, -_t * 26.0)
			if strong and _cam.dist < 60000.0 and arc.size() > 8:
				var mid := arc[arc.size() / 2]
				UITheme.text(ci, mid + Vector2(0, -12), "SINGULARITY LINK", 11, UITheme.ca(UITheme.VIOLET, 0.9), 0.5, UITheme.font_caps(), false)
	# ---- route current -> selected
	if _selected >= 0 and _selected != cur.id and _depth[_selected] >= 1.0 and _depth[cur.id] >= 1.0:
		var a := _screen[cur.id]
		var b := _screen[_selected]
		var enough := Game.warp_cells >= Game.hyperdrive_cost(_selected)
		var rc := UITheme.ACCENT if enough else UITheme.WARN
		_dashed(ci, PackedVector2Array([a, b]), UITheme.ca(rc, 0.9), 2.0, 12.0, 7.0, -_t * 30.0)
		var dist_ly := cur.distance_to(Universe.get_star(_selected))
		var lbl := "%s   -   %d CELL%s" % [UITheme.fmt_ly(dist_ly), Game.hyperdrive_cost(_selected), "" if Game.hyperdrive_cost(_selected) == 1 else "S"]
		var tw := UITheme.text_width(lbl, 13, UITheme.font_caps())
		# the route label slides along / beside the route until it clears the "YOU ARE HERE" block and the destination's reticle + name
		var avoid: Array = [Rect2(a + Vector2(-64.0, 34.0), Vector2(128.0, 46.0)), Rect2(a - Vector2(40.0, 40.0), Vector2(80.0, 80.0)),
			Rect2(b - Vector2(26.0, 26.0), Vector2(52.0, 52.0)), Rect2(b + Vector2(24.0, -22.0), Vector2(200.0, 48.0))]
		var rdir := (b - a).normalized() if a.distance_to(b) > 1.0 else Vector2.RIGHT
		var rn := Vector2(-rdir.y, rdir.x)
		if rn.y > 0.0:
			rn = -rn                                  # prefer the side above the route (the name / "you are here" texts sit below)
		var lbl_pos := (a + b) * 0.5
		var found := false
		for off: float in [0.0, 24.0, -24.0, 48.0, -48.0]:
			for tt: float in [0.5, 0.62, 0.38, 0.74, 0.26]:
				var cand: Vector2 = a.lerp(b, tt) + rn * off
				var cr := Rect2(cand - Vector2(tw * 0.5 + 8.0, 14.0), Vector2(tw + 16.0, 22.0))
				var hit := false
				for ar in avoid:
					if (ar as Rect2).intersects(cr):
						hit = true
						break
				if not hit:
					lbl_pos = cand
					found = true
					break
			if found:
				break
		ci.draw_rect(Rect2(lbl_pos - Vector2(tw * 0.5 + 8.0, 14.0), Vector2(tw + 16.0, 22.0)), Color(0.01, 0.03, 0.06, 0.82))
		ci.draw_rect(Rect2(lbl_pos - Vector2(tw * 0.5 + 8.0, 14.0), Vector2(2.0, 22.0)), UITheme.ca(rc, 0.9))
		UITheme.text(ci, lbl_pos + Vector2(0, 2.0), lbl, 13, rc, 0.5, UITheme.font_caps(), false)
	# ---- per-star markers
	var rect := Rect2(Vector2(-20, -20), vp + Vector2(40, 40))
	var label_budget := 26
	var near_zoom := _cam.dist < 26000.0
	var centre := vp * 0.5
	for i in _screen.size():
		if _depth[i] < 1.0:
			continue
		var sp := _screen[i]
		if not rect.has_point(sp):
			continue
		var gs2: GalaxyStar = Universe.galaxy[i]
		var cs := _core_size(i)
		if gs2.has_black_hole and (_cam.dist < 34000.0 or gs2.special or i == _hover or i == _selected or i == cur.id):
			ci.draw_arc(sp, cs + 5.5, 0, TAU, 20, UITheme.ca(UITheme.VIOLET, 0.8 * open_k), 1.4, true)
		if gs2.special and i != cur.id and i != _selected:
			UITheme.text(ci, sp + Vector2(cs + 10.0, 4.0), gs2.name.to_upper(), 12, UITheme.ca(UITheme.VIOLET.lerp(Color.WHITE, 0.5), 0.95 * open_k), 0.0, UITheme.font_caps(), true)
		if Game.visited_systems.has(i) and i != cur.id:
			ci.draw_arc(sp, cs + 3.0, -0.6, 0.6, 8, UITheme.ca(UITheme.GOOD, 0.9 * open_k), 1.6, true)
			ci.draw_arc(sp, cs + 3.0, PI - 0.6, PI + 0.6, 8, UITheme.ca(UITheme.GOOD, 0.9 * open_k), 1.6, true)
		if near_zoom and label_budget > 0 and i != _hover and i != _selected and i != cur.id:
			if sp.distance_to(centre) < vp.y * 0.55:
				label_budget -= 1
				UITheme.text(ci, sp + Vector2(cs + 9.0, 4.0), gs2.name, 12, UITheme.ca(UITheme.TEXT_DIM, 0.8), 0.0, null, true)
	# ---- current system marker
	if _depth[cur.id] >= 1.0:
		var cp := _screen[cur.id]
		var pulse := fposmod(_t * 0.7, 1.0)
		ci.draw_arc(cp, 14.0 + pulse * 30.0, 0, TAU, 40, UITheme.ca(UITheme.GOOD, (1.0 - pulse) * 0.7), 2.0, true)
		ci.draw_arc(cp, 14.0, 0, TAU, 32, UITheme.ca(UITheme.GOOD, 0.95), 2.0, true)
		UITheme.draw_triangle(ci, cp + Vector2(0, 30.0), Vector2(0, -1), 6.0, UITheme.GOOD)
		UITheme.text(ci, cp + Vector2(0, 52.0), "YOU ARE HERE", 12, UITheme.GOOD, 0.5, UITheme.font_caps(), true)
		UITheme.text(ci, cp + Vector2(0, 68.0), cur.name, 13, UITheme.TEXT, 0.5, null, true)
	# ---- selected reticle
	if _selected >= 0 and _depth[_selected] >= 1.0:
		var sp3 := _screen[_selected]
		var rr := 17.0 + 2.0 * sin(_t * 3.0)
		UITheme.draw_brackets(ci, Rect2(sp3 - Vector2(rr, rr), Vector2(rr, rr) * 2.0), 7.0, UITheme.ACCENT_HI, 2.0)
		var gs3: GalaxyStar = Universe.galaxy[_selected]
		UITheme.text(ci, sp3 + Vector2(rr + 8.0, -2.0), gs3.name.to_upper(), 15, UITheme.TEXT, 0.0, UITheme.font_caps(), true)
		UITheme.text(ci, sp3 + Vector2(rr + 8.0, 14.0), "%s-class  -  %s" % [gs3.spectral_class, UITheme.fmt_ly(cur.distance_to(gs3))], 12, UITheme.TEXT_DIM, 0.0, null, true)
	# ---- hover tooltip
	if _hover >= 0 and _hover != _selected and _depth[_hover] >= 1.0:
		var sp4 := _screen[_hover]
		var cs4 := _core_size(_hover)
		ci.draw_arc(sp4, cs4 + 8.0, 0, TAU, 28, UITheme.ca(UITheme.ACCENT_HI, 0.9), 1.5, true)
		var gs4: GalaxyStar = Universe.galaxy[_hover]
		var l1 := gs4.name.to_upper()
		var l2 := "%s-class   %s" % [gs4.spectral_class, UITheme.fmt_ly(cur.distance_to(gs4))]
		if gs4.has_black_hole:
			l2 += "   [singularity]"
		var wmax := maxf(UITheme.text_width(l1, 15, UITheme.font_caps()), UITheme.text_width(l2, 12)) + 22.0
		var tp := sp4 + Vector2(cs4 + 16.0, -18.0)
		if tp.x + wmax > vp.x - 20.0:
			tp.x = sp4.x - wmax - cs4 - 16.0
		UITheme.draw_chamfer(ci, Rect2(tp, Vector2(wmax, 44.0)), 6.0, Color(0.02, 0.04, 0.07, 0.92), UITheme.ca(UITheme.ACCENT, 0.7), 1.0)
		UITheme.text(ci, tp + Vector2(11.0, 19.0), l1, 15, UITheme.TEXT, 0.0, UITheme.font_caps(), false)
		UITheme.text(ci, tp + Vector2(11.0, 36.0), l2, 12, UITheme.TEXT_DIM, 0.0, null, false)
	# ---- legend + hints
	_draw_legend(ci, vp)

func _draw_legend(ci: Control, vp: Vector2) -> void:
	var y := vp.y - 22.0
	# right-aligned legend
	var items: Array = []
	for c in Universe.CLASS_ORDER:
		items.append([c, Universe.STAR_CLASSES[c]["color"]])
	var total := 0.0
	for it in items:
		total += 34.0
	var x := vp.x - 28.0 - total - 190.0
	UITheme.text(ci, Vector2(x, y), "STAR CLASS", 11, UITheme.TEXT_FAINT, 0.0, UITheme.font_caps(), false)
	var cx := x + UITheme.text_width("STAR CLASS", 11, UITheme.font_caps()) + 16.0
	for it in items:
		ci.draw_circle(Vector2(cx, y - 4.0), 5.0, it[1])
		UITheme.text(ci, Vector2(cx + 9.0, y), str(it[0]), 12, UITheme.TEXT_DIM, 0.0, UITheme.font_caps(), false)
		cx += 34.0
	ci.draw_arc(Vector2(cx + 12.0, y - 4.0), 5.5, 0, TAU, 16, UITheme.VIOLET, 1.5, true)
	UITheme.text(ci, Vector2(cx + 24.0, y), "BLACK HOLE", 11, UITheme.TEXT_DIM, 0.0, UITheme.font_caps(), false)
	var hint := "DRAG orbit  -  RIGHT-DRAG pan  -  WHEEL zoom  -  CLICK select  -  DOUBLE-CLICK focus  -  ENTER warp  -  HOME reset"
	UITheme.text(ci, Vector2(28.0, y), hint, 11, UITheme.ca(UITheme.TEXT_DIM, 0.85), 0.0, UITheme.font_caps(), false)
