class_name Menus
extends Control
## Main menu, pause menu, controls overview and settings pages (all built in code).

signal start_game
signal resume_game
signal quit_to_menu
signal quit_game
signal open_map
signal page_changed(page: int)

enum Page { NONE, MAIN, PAUSE, CONTROLS, SETTINGS }

var page: int = Page.NONE
var _back_page: int = Page.MAIN
var _pages: Dictionary = {}
var _backdrop: TextureRect
var _fade_t: float = 0.0
var _title_t: float = 0.0
var _title_label: Label
var _sub_label: Label
var _stats_label: Label

func _ready() -> void:
	theme = UiKit.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_backdrop()
	_pages[Page.MAIN] = _build_main()
	_pages[Page.PAUSE] = _build_pause()
	_pages[Page.CONTROLS] = _build_controls()
	_pages[Page.SETTINGS] = _build_settings()
	for k in _pages.keys():
		add_child(_pages[k])
	show_page(Page.NONE)

func _build_backdrop() -> void:
	_backdrop = TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.02, 0.88))
	g.set_color(1, Color(0.0, 0.0, 0.02, 0.0))
	g.add_point(0.55, Color(0.0, 0.0, 0.02, 0.45))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	gt.width = 512
	gt.height = 8
	_backdrop.texture = gt
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_backdrop.visible = false

func _btn(text: String, cb: Callable, width: float = 380.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 54)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(cb)
	b.pressed.connect(func() -> void: Game.play_sfx("click", -4.0))
	b.mouse_entered.connect(func() -> void: Game.play_sfx("hover", -14.0))
	b.focus_mode = Control.FOCUS_NONE
	return b

func _column(parent: Control, left: float, top_frac: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.set_anchors_preset(Control.PRESET_TOP_LEFT)
	v.anchor_left = 0.0
	v.anchor_top = top_frac
	v.offset_left = left
	parent.add_child(v)
	return v

func _build_main() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := _column(root, 120, 0.2)
	_title_label = UiKit.label("WAYFARER", 118, Color(0.95, 0.98, 1.0), true)
	_title_label.add_theme_color_override("font_outline_color", Color(0.2, 0.7, 1.0, 0.5))
	_title_label.add_theme_constant_override("outline_size", 6)
	col.add_child(_title_label)
	_sub_label = UiKit.label("An open galaxy.  Seven worlds.  One black hole.", 24, UiKit.C_MAIN)
	col.add_child(_sub_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 36)
	col.add_child(gap)
	col.add_child(_btn("BEGIN JOURNEY", func() -> void: start_game.emit()))
	col.add_child(_btn("CONTROLS", func() -> void: _open_sub(Page.CONTROLS, Page.MAIN)))
	col.add_child(_btn("SETTINGS", func() -> void: _open_sub(Page.SETTINGS, Page.MAIN)))
	col.add_child(_btn("QUIT", func() -> void: quit_game.emit()))
	var foot := UiKit.label("Godot 4.7 - all ships, props and characters modelled in Blender - everything else procedural", 15, UiKit.C_TEXT_DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 120
	foot.offset_top = -50
	root.add_child(foot)
	return root

func _build_pause() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.03, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var col := _column(root, 120, 0.2)
	col.add_child(UiKit.label("PAUSED", 80, Color(0.95, 0.98, 1.0), true))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	col.add_child(gap)
	col.add_child(_btn("RESUME", func() -> void: resume_game.emit()))
	col.add_child(_btn("GALAXY MAP", func() -> void: open_map.emit()))
	_stats_label = UiKit.label("", 16, UiKit.C_TEXT_DIM)
	col.add_child(_stats_label)
	col.add_child(_btn("CONTROLS", func() -> void: _open_sub(Page.CONTROLS, Page.PAUSE)))
	col.add_child(_btn("SETTINGS", func() -> void: _open_sub(Page.SETTINGS, Page.PAUSE)))
	col.add_child(_btn("MAIN MENU", func() -> void: quit_to_menu.emit()))
	col.add_child(_btn("QUIT GAME", func() -> void: quit_game.emit()))
	return root

func _open_sub(p: int, back: int) -> void:
	_back_page = back
	show_page(p)

func _kv_column(title: String, rows: Array) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(420, 0)
	v.add_child(UiKit.label(title, 24, UiKit.C_MAIN, true))
	var sep := HSeparator.new()
	v.add_child(sep)
	for r in rows:
		var h := HBoxContainer.new()
		var k := UiKit.label(String(r[0]), 19, Color(1.0, 0.86, 0.5), true)
		k.custom_minimum_size = Vector2(150, 0)
		h.add_child(k)
		h.add_child(UiKit.label(String(r[1]), 19, UiKit.C_TEXT))
		v.add_child(h)
	return v

func _build_controls() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	panel.add_child(outer)
	outer.add_child(UiKit.label("CONTROLS", 52, Color(0.95, 0.98, 1.0), true))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 46)
	outer.add_child(cols)
	cols.add_child(_kv_column("SHIP", [
		["Mouse", "steer: pitch / yaw"], ["W / S", "thrust forward / reverse"], ["A / D", "strafe left / right"],
		["Space / Ctrl", "thrust up / down"], ["Q / E", "roll"], ["Shift", "boost (burns energy)"],
		["X", "pulse drive (deep space only)"], ["T", "cycle target"], ["Z", "auto-pulse to target"],
		["L", "landing assist (below 2 km)"], ["V", "chase / cockpit camera"], ["F", "exit ship (when landed)"],
		["Space / W", "take off (when landed)"]]))
	cols.add_child(_kv_column("ON FOOT", [
		["Mouse", "look"], ["W A S D", "walk"], ["Shift", "sprint"], ["Space", "jump; hold in air = jetpack"],
		["F", "interact / enter ship / open crates"], ["R", "scanner pulse"], ["G", "recharge hazard protection"],
		["V", "first / third person"], ["Y", "skip time (day/night)"], ["Left mouse", "mine a resource (hold)"]]))
	cols.add_child(_kv_column("GENERAL", [
		["M / Tab", "galaxy map"], ["H / F1", "controls overlay"], ["Esc", "pause menu"], ["F11", "fullscreen on / off"],
		["Map: drag", "rotate galaxy"], ["Map: wheel", "zoom"], ["Map: click", "select star"], ["Map: Enter", "hyperdrive jump"]]))
	var hint := UiKit.label("Black holes pull ships in with growing force. Past the point of no return there is no escape - it transports you across the galaxy.", 18, UiKit.C_TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(1100, 0)
	outer.add_child(hint)
	outer.add_child(_btn("BACK", func() -> void: show_page(_back_page), 200))
	return root

func _slider_row(parent: Control, text: String, vmin: float, vmax: float, val: float, step: float, cb: Callable, fmt: String = "%.2f") -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	var l := UiKit.label(text, 22, UiKit.C_TEXT)
	l.custom_minimum_size = Vector2(250, 0)
	h.add_child(l)
	var sl := HSlider.new()
	sl.min_value = vmin
	sl.max_value = vmax
	sl.step = step
	sl.value = val
	sl.custom_minimum_size = Vector2(320, 30)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sl)
	var vl := UiKit.label(fmt % val, 22, UiKit.C_MAIN)
	vl.custom_minimum_size = Vector2(80, 0)
	h.add_child(vl)
	sl.value_changed.connect(func(v: float) -> void:
		vl.text = fmt % v
		cb.call(v))
	parent.add_child(h)

func _toggle(text: String, initial: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = initial
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 21)
	var upd := func() -> void:
		b.text = "%s   [ %s ]" % [text, "ON" if b.button_pressed else "OFF"]
	upd.call()
	b.toggled.connect(func(on: bool) -> void:
		upd.call()
		cb.call(on))
	return b

func _build_settings() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	v.add_child(UiKit.label("SETTINGS", 52, Color(0.95, 0.98, 1.0), true))
	_slider_row(v, "Mouse sensitivity", 0.25, 3.0, Game.mouse_sens, 0.05, func(x: float) -> void: Game.mouse_sens = x; Game.save_settings())
	_slider_row(v, "Field of view", 60.0, 110.0, Game.fov_setting, 1.0, func(x: float) -> void: Game.fov_setting = x; Game.save_settings(), "%d")
	_slider_row(v, "Master volume", 0.0, 1.0, Game.master_volume, 0.05, func(x: float) -> void: Game.master_volume = x; Game.apply_settings(); Game.save_settings())
	v.add_child(_toggle("Invert Y axis (mouse up = nose down)", Game.invert_y, func(on: bool) -> void: Game.invert_y = on; Game.save_settings()))
	v.add_child(_toggle("Show FPS counter", Game.show_fps, func(on: bool) -> void: Game.show_fps = on; Game.save_settings()))
	v.add_child(_toggle("Fullscreen (F11)", Game.is_fullscreen(), func(on: bool) -> void: Game.set_fullscreen(on)))
	var qh := HBoxContainer.new()
	qh.add_theme_constant_override("separation", 18)
	var ql := UiKit.label("Graphics quality", 22, UiKit.C_TEXT)
	ql.custom_minimum_size = Vector2(250, 0)
	qh.add_child(ql)
	var ob := OptionButton.new()
	ob.add_item("Low (FXAA, short view)", 0)
	ob.add_item("Medium (MSAA 2x)", 1)
	ob.add_item("High (MSAA 4x)", 2)
	ob.selected = Game.quality
	ob.add_theme_font_size_override("font_size", 20)
	ob.item_selected.connect(func(i: int) -> void: Game.quality = i; Game.apply_settings(); Game.save_settings())
	qh.add_child(ob)
	v.add_child(qh)
	v.add_child(_btn("BACK", func() -> void: show_page(_back_page), 200))
	return root

func show_page(p: int) -> void:
	page = p
	if p == Page.PAUSE and _stats_label != null:
		var st: Dictionary = Game.stats
		_stats_label.text = "Distance flown %s   Landings %d   Scans %d   Resources %d   Black hole jumps %d   Warps %d" % [U.fmt_dist(float(st["distance"])), int(st["landings"]), int(st["scans"]), int(st["collected"]), int(st["bh_jumps"]), int(st["warps"])]
	for k in _pages.keys():
		(_pages[k] as Control).visible = (k == p)
	_backdrop.visible = (p == Page.MAIN)
	visible = p != Page.NONE
	mouse_filter = Control.MOUSE_FILTER_STOP if p != Page.NONE else Control.MOUSE_FILTER_IGNORE
	page_changed.emit(p)

func _process(delta: float) -> void:
	if page == Page.MAIN and _title_label != null:
		_title_t += delta
		var a: float = 0.92 + 0.08 * sin(_title_t * 1.6)
		_title_label.modulate = Color(1, 1, 1, a)
