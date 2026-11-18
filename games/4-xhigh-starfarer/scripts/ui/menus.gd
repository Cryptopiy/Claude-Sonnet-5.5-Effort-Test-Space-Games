class_name Menus
extends CanvasLayer
## Main menu, pause menu, settings and controls overview.

signal start_new_game(ground: bool)
signal resume_game
signal back_to_menu
signal quit_game

const CYAN := Color(0.45, 0.95, 1.0)

var root: Control
var main_panel: Control
var pause_panel: Control
var controls_panel: Control
var settings_panel: Control
var dim: ColorRect
var controls_return: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0.01, 0.03, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	_build_main()
	_build_pause()
	_build_controls()
	_build_settings()
	show_main()


func _style_button(b: Button, size := 22) -> void:
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(420, 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.03, 0.09, 0.13, 0.78)
	n.border_color = Color(0.3, 0.8, 0.95, 0.6)
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	n.content_margin_left = 16
	n.content_margin_right = 16
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.08, 0.28, 0.38, 0.9)
	h.border_color = Color(0.6, 1.0, 1.0, 1.0)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color(0.12, 0.4, 0.5, 1.0)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_color_override("font_color", Color(0.9, 0.97, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.mouse_entered.connect(func(): Sfx.play("click", -10.0))


func _label(text: String, size: int, col: Color, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	return l


func _button(text: String, parent: Node, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	_style_button(b)
	b.pressed.connect(func():
		Sfx.play("select", -6.0)
		cb.call())
	parent.add_child(b)
	return b


func _centered_box(parent: Node, width := 360.0) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(width, 0)
	c.add_child(v)
	return v


func _build_main() -> void:
	main_panel = Control.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(main_panel)
	var left := MarginContainer.new()
	left.set_anchors_preset(Control.PRESET_FULL_RECT)
	left.add_theme_constant_override("margin_left", 90)
	left.add_theme_constant_override("margin_top", 120)
	left.add_theme_constant_override("margin_bottom", 70)
	main_panel.add_child(left)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(640, 0)
	v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(v)
	var t := _label("S T A R F A R E R", 64, Color(0.92, 0.98, 1.0), v)
	t.add_theme_constant_override("outline_size", 8)
	_label("A procedurally generated galaxy to explore — land on spherical worlds, cross star systems, survive the singularity.", 17, CYAN, v).custom_minimum_size = Vector2(620, 0)
	(v.get_child(1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	v.add_child(sp)
	_button("NEW GAME  (start on the surface)", v, func(): start_new_game.emit(true))
	_button("QUICK START  (in orbit)", v, func(): start_new_game.emit(false))
	_button("CONTROLS", v, func(): show_controls(main_panel))
	_button("SETTINGS", v, func(): show_settings(main_panel))
	_button("QUIT", v, func(): quit_game.emit())
	var foot := Control.new()
	foot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(foot)
	var gl := _label("Galaxy seed 20260610 · %d stars · home system SOLARA: 7 landable worlds, a gas giant and a black hole" % Game.galaxy.stars.size(), 14, Color(0.6, 0.75, 0.85), v)
	gl.custom_minimum_size = Vector2(620, 0)
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_pause() -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(pause_panel)
	var v := _centered_box(pause_panel)
	var t := _label("PAUSED", 48, Color(0.92, 0.98, 1.0), v)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button("RESUME", v, func(): resume_game.emit())
	_button("CONTROLS", v, func(): show_controls(pause_panel))
	_button("SETTINGS", v, func(): show_settings(pause_panel))
	_button("MAIN MENU", v, func(): back_to_menu.emit())
	_button("QUIT GAME", v, func(): quit_game.emit())


func _build_controls() -> void:
	controls_panel = Control.new()
	controls_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(controls_panel)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls_panel.add_child(c)
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.06, 0.09, 0.92)
	sb.border_color = Color(0.3, 0.8, 0.95, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(22)
	pc.add_theme_stylebox_override("panel", sb)
	c.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	_label("CONTROLS", 30, Color(0.92, 0.98, 1.0), v)
	var g := HBoxContainer.new()
	g.add_theme_constant_override("separation", 44)
	v.add_child(g)
	g.add_child(_ctl_column("SPACESHIP", [
		["Mouse", "Pitch / yaw"], ["W / S", "Throttle up / down"], ["A / D", "Strafe left / right"], ["Q / E", "Roll"],
		["SHIFT", "Boost (afterburner)"], ["SPACE (hold)", "Pulse drive (space only)"], ["CTRL", "Air-brake"], ["X", "Cut throttle"],
		["L", "Landing mode / gear (auto-descent)"], ["SPACE / CTRL", "Lift / lower (landing mode)"], ["F", "Exit ship (when landed)"],
		["T / Y", "Next target / clear target"], ["M", "Galaxy map (hyperdrive)"], ["V", "Chase / cockpit camera"], ["N", "Time warp x60 (deep space)"]]))
	g.add_child(_ctl_column("ON FOOT", [
		["Mouse", "Look"], ["W A S D", "Walk"], ["SHIFT", "Sprint"], ["SPACE", "Jump · hold in air = jetpack"],
		["LMB (hold)", "Mining beam — collect resources"], ["Q", "Scanner pulse (reveals resources & sites)"], ["R", "Recharge hazard protection"],
		["E", "Board ship / use sites"], ["V", "First / third person"], ["I", "Inventory"], ["G", "Headlamp on / off"],
		["GENERAL", ""], ["ESC", "Pause"], ["F1", "This screen"], ["H", "Toggle HUD"], ["F12", "Screenshot"]]))
	var b := Button.new()
	b.text = "BACK"
	_style_button(b, 18)
	b.custom_minimum_size = Vector2(200, 40)
	b.pressed.connect(func(): hide_controls())
	v.add_child(b)
	controls_panel.visible = false


func _ctl_column(title: String, rows: Array) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_label(title, 18, CYAN, v)
	for r in rows:
		var h := HBoxContainer.new()
		var k := Label.new()
		k.text = r[0]
		k.custom_minimum_size = Vector2(130, 0)
		k.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		k.add_theme_font_size_override("font_size", 14)
		var d := Label.new()
		d.text = r[1]
		d.add_theme_font_size_override("font_size", 14)
		d.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		h.add_child(k)
		h.add_child(d)
		v.add_child(h)
	return v


func _build_settings() -> void:
	settings_panel = Control.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(settings_panel)
	var v := _centered_box(settings_panel, 480.0)
	_label("SETTINGS", 36, Color(0.92, 0.98, 1.0), v)
	_slider(v, "Mouse sensitivity", 0.2, 3.0, Game.mouse_sens, func(x): Game.mouse_sens = x)
	_slider(v, "Field of view", 60.0, 100.0, Game.fov_base, func(x): Game.fov_base = x)
	_slider(v, "Master volume", 0.0, 1.0, Game.master_volume, func(x): Game.master_volume = x)
	var cb := CheckBox.new()
	cb.text = "Invert Y axis"
	cb.add_theme_font_size_override("font_size", 18)
	cb.toggled.connect(func(on): Game.invert_y = on)
	v.add_child(cb)
	var b := Button.new()
	b.text = "BACK"
	_style_button(b, 20)
	b.pressed.connect(func(): hide_settings())
	v.add_child(b)
	settings_panel.visible = false


func _slider(parent: Node, title: String, lo: float, hi: float, val: float, cb: Callable) -> void:
	var l := _label("%s: %.2f" % [title, val], 18, Color(0.9, 0.97, 1.0), parent)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = val
	s.custom_minimum_size = Vector2(420, 24)
	s.value_changed.connect(func(x):
		cb.call(x)
		l.text = "%s: %.2f" % [title, x])
	parent.add_child(s)


# ---------------------------------------------------------------- visibility
func _hide_all() -> void:
	main_panel.visible = false
	pause_panel.visible = false
	controls_panel.visible = false
	settings_panel.visible = false


func show_main() -> void:
	_hide_all()
	main_panel.visible = true
	dim.color.a = 0.0
	root.visible = true


func show_pause() -> void:
	_hide_all()
	pause_panel.visible = true
	dim.color.a = 0.45
	root.visible = true


func show_none() -> void:
	_hide_all()
	root.visible = false


func show_controls(ret: Control = null) -> void:
	controls_return = ret
	_hide_all()
	controls_panel.visible = true
	dim.color.a = 0.65


func hide_controls() -> void:
	controls_panel.visible = false
	if controls_return != null:
		controls_return.visible = true
		dim.color.a = 0.45 if controls_return == pause_panel else 0.0
	else:
		show_none()


func show_settings(ret: Control = null) -> void:
	controls_return = ret
	_hide_all()
	settings_panel.visible = true
	dim.color.a = 0.65


func hide_settings() -> void:
	settings_panel.visible = false
	if controls_return != null:
		controls_return.visible = true
		dim.color.a = 0.45 if controls_return == pause_panel else 0.0
	else:
		show_none()


func is_overlay_open() -> bool:
	return root.visible
