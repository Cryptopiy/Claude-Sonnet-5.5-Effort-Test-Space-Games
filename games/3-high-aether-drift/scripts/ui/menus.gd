class_name Menus
extends CanvasLayer
## Main menu, pause menu and the controls overview.

signal start_game()
signal resume_game()
signal open_map()
signal quit_to_menu()
signal quit_game()

const TITLE := "AETHER DRIFT"

const CONTROLS_TEXT := """[b][color=#9fe3ff]SHIP[/color][/b]
Mouse  -  pitch / yaw           Q / E  -  roll
W / S  -  throttle up / down    X  -  cut throttle        Ctrl  -  air brake
A / D  -  strafe left / right   R / F  -  thrust up / down
Shift  -  boost                 Space  -  pulse drive (open space) / take off when landed
V  -  cockpit / chase camera    M  -  galaxy map & hyperdrive warp

[b][color=#9fe3ff]LANDING[/color][/b]
Fly low and slow (under ~40 m/s sideways, gentle descent, level ship). Landing gear drops automatically near the
ground. Press Space on the ground to lift off. Liquid surfaces and steep slopes cannot be landed on.

[b][color=#9fe3ff]ON FOOT[/color][/b]
W A S D  -  walk          Shift  -  sprint        Space  -  jump (hold in the air for jetpack)
Mouse  -  look            Left mouse  -  mining laser (aim at glowing crystals / ore)
Q  -  scanner pulse (reveals resources & points of interest)       R  -  use power cell (recharge suit)
E  -  interact / enter ship        V  -  first / third person

[b][color=#9fe3ff]GENERAL[/color][/b]
M  -  galaxy map (select a star, Enter to warp)         Esc  -  pause          F3  -  FPS counter

[b][color=#ffb86b]BLACK HOLES[/color][/b]
They pull harder the closer you get. Beyond the POINT OF NO RETURN your engines cannot escape. Cross the event
horizon and you are thrown to a distant star system.
"""

var root: Control
var main_panel: Control
var pause_panel: Control
var controls_panel: Control
var title_label: Label
var _return_to: Control = null
var in_game: bool = false


func _ready() -> void:
	layer = 30
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	main_panel = _build_main()
	pause_panel = _build_pause()
	controls_panel = _build_controls()
	root.add_child(main_panel)
	root.add_child(pause_panel)
	root.add_child(controls_panel)
	show_main()


func _panel_style(alpha: float = 0.82) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.1, alpha)
	sb.border_color = Color(0.35, 0.7, 0.9, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(24)
	return sb


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 48)
	b.add_theme_font_size_override("font_size", 20)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.06, 0.12, 0.18, 0.9)
	n.border_color = Color(0.35, 0.75, 1.0, 0.8)
	n.set_border_width_all(1)
	n.set_corner_radius_all(3)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.12, 0.3, 0.45, 0.95)
	h.border_color = Color(0.7, 0.95, 1.0, 1.0)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", h)
	b.pressed.connect(cb)
	return b


func _build_main() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(110, -190)
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	title_label = Label.new()
	title_label.text = TITLE
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.4, 0.7, 0.9))
	title_label.add_theme_constant_override("outline_size", 10)
	v.add_child(title_label)
	var sub := Label.new()
	sub.text = "A procedural space exploration game"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	v.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	v.add_child(sp)
	v.add_child(_button("START EXPLORING", func(): start_game.emit()))
	v.add_child(_button("CONTROLS", func(): _show_controls(main_panel)))
	v.add_child(_button("QUIT", func(): quit_game.emit()))
	var hint := Label.new()
	hint.text = "\nKeyboard + mouse   ·   Esc to pause in game"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.75, 0.85))
	v.add_child(hint)
	return c


func _build_pause() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0.01, 0.03, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _panel_style())
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.position = Vector2(-190, -190)
	c.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	var t := Label.new()
	t.text = "PAUSED"
	t.add_theme_font_size_override("font_size", 38)
	t.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_button("RESUME", func(): resume_game.emit()))
	v.add_child(_button("GALAXY MAP", func(): open_map.emit()))
	v.add_child(_button("CONTROLS", func(): _show_controls(pause_panel)))
	v.add_child(_button("MAIN MENU", func(): quit_to_menu.emit()))
	v.add_child(_button("QUIT GAME", func(): quit_game.emit()))
	return c


func _build_controls() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0.01, 0.03, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(bg)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _panel_style(0.92))
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.custom_minimum_size = Vector2(980, 0)
	pc.position = Vector2(-490, -290)
	c.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	var t := Label.new()
	t.text = "CONTROLS"
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", Color(0.85, 0.96, 1.0))
	v.add_child(t)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(930, 0)
	rt.text = CONTROLS_TEXT
	rt.add_theme_font_size_override("normal_font_size", 16)
	rt.add_theme_font_size_override("bold_font_size", 17)
	v.add_child(rt)
	v.add_child(_button("BACK", func(): _hide_controls()))
	return c


func _show_controls(from: Control) -> void:
	_return_to = from
	for p in [main_panel, pause_panel]:
		p.visible = false
	controls_panel.visible = true


func _hide_controls() -> void:
	controls_panel.visible = false
	if _return_to == pause_panel and in_game:
		pause_panel.visible = true
	else:
		main_panel.visible = true


func show_main() -> void:
	in_game = false
	root.visible = true
	main_panel.visible = true
	pause_panel.visible = false
	controls_panel.visible = false


func show_pause() -> void:
	in_game = true
	root.visible = true
	main_panel.visible = false
	pause_panel.visible = true
	controls_panel.visible = false


func hide_all() -> void:
	root.visible = false
	controls_panel.visible = false
