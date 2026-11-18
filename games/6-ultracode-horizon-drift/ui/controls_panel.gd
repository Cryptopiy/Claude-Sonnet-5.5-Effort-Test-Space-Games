class_name ControlsPanel
extends Control
## CONTROLS OVERVIEW (module M6). Built from Game.ACTIONS, grouped by section, with key caps. Opened from the main menu, the pause menu and F1.
## Overlay contract: open() / close(). Esc closes it when the game is not running (Game.gd handles Esc while playing/paused).

const SECTION_ORDER := ["Movement", "Ship", "Actions", "Interface"]
const SECTION_ICON_COLOR := {"Movement": Color(0.42, 1.0, 0.62), "Ship": Color(0.36, 0.86, 1.0), "Actions": Color(1.0, 0.72, 0.22), "Interface": Color(0.84, 0.52, 1.0)}
const TIPS := [
	"X in open space engages the pulse drive. Zyrite refuels it.",
	"3 Voidstone = 1 warp cell for hyperdrive jumps (M).",
	"Past the point of no return a black hole pulls you to another star.",
]

var _fade: float = 0.0
var _root: Control
var _bg: ColorRect
var _mat: ShaderMaterial
var _built: bool = false
var _tween: Tween
var _prev_index: int = -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/ui_blur.gdshader")
	_mat.set_shader_parameter("tint_amount", 0.72)
	_bg.material = _mat
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_build()

func _key_name(code: int) -> String:
	match code:
		KEY_CTRL: return "Ctrl"
		KEY_SHIFT: return "Shift"
		KEY_SPACE: return "Space"
		KEY_ESCAPE: return "Esc"
		KEY_ALT: return "Alt"
		KEY_TAB: return "Tab"
		KEY_ENTER: return "Enter"
	return OS.get_keycode_string(code)

static func make_keycap(text: String, accent: Color = UITheme.ACCENT) -> Control:
	var pc := PanelContainer.new()
	var sb := UITheme.flat(Color(0.10, 0.15, 0.21, 0.95), UITheme.ca(accent, 0.55), 1, 4, 0.0)
	sb.border_width_bottom = 3
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(34, 30)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label(text, 15, UITheme.TEXT)
	l.add_theme_font_override("font", UITheme.font_bold())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(l)
	return pc

func _action_caps(a: Dictionary, accent: Color) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	var keys: Array = a.get("keys", [])
	for k in keys:
		hb.add_child(make_keycap(_key_name(int(k)), accent))
	var mouse: Array = a.get("mouse", [])
	for mb in mouse:
		var nm := "LMB" if int(mb) == MOUSE_BUTTON_LEFT else ("RMB" if int(mb) == MOUSE_BUTTON_RIGHT else "MMB")
		hb.add_child(make_keycap(nm, accent))
	return hb

func _section_card(section: String) -> UIPanel:
	var accent: Color = SECTION_ICON_COLOR.get(section, UITheme.ACCENT)
	var card := UIPanel.new(18, section.to_upper())
	card.accent = accent
	card.custom_minimum_size = Vector2(0, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	card.add_content(vb)
	for action in Game.ACTIONS:
		var a: Dictionary = Game.ACTIONS[action]
		if str(a.get("section", "")) != section:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var caps_box := Control.new()
		caps_box.custom_minimum_size = Vector2(112, 30)
		var caps := _action_caps(a, accent)
		caps_box.add_child(caps)
		row.add_child(caps_box)
		var label: String = str(a.get("label", action))
		var parts := label.split("|", false, 1)
		var main_l := UITheme.label(parts[0].strip_edges(), 16, UITheme.TEXT)
		main_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		main_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -2)
		col.add_child(main_l)
		if parts.size() > 1:
			col.add_child(UITheme.label(parts[1].strip_edges(), 13, UITheme.TEXT_DIM))
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		vb.add_child(row)
	return card

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 70)
	outer.add_theme_constant_override("margin_right", 70)
	outer.add_theme_constant_override("margin_top", 38)
	outer.add_theme_constant_override("margin_bottom", 34)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(outer)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	outer.add_child(vb)
	# header
	var head := HBoxContainer.new()
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.add_child(UITheme.label("FLIGHT MANUAL", 13, UITheme.ACCENT, true))
	var title := UITheme.label("CONTROLS", 40, UITheme.TEXT, true)
	hv.add_child(title)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var close_btn := UIButton.new("BACK   [ESC]", "primary")
	close_btn.custom_minimum_size = Vector2(190, 44)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): _close_request())
	head.add_child(close_btn)
	vb.add_child(head)
	vb.add_child(UITheme.hline(UITheme.ca(UITheme.ACCENT, 0.5)))
	# two columns
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	cols.add_child(right)
	left.add_child(_section_card("Movement"))
	left.add_child(_section_card("Ship"))
	right.add_child(_section_card("Actions"))
	right.add_child(_section_card("Interface"))
	# tips strip
	var tips := UIPanel.new(14, "FIELD NOTES")
	tips.accent = UITheme.GOLD
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 3)
	for t in TIPS:
		var l := UITheme.label("▸  " + str(t), 14, UITheme.TEXT_DIM)
		tv.add_child(l)
	tips.add_content(tv)
	left.add_child(tips)
	_built = true

func open() -> void:
	if get_parent() != null:
		_prev_index = get_index()
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	visible = true
	_fade = 0.0
	modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	UITheme.sfx("ui_open")

func close() -> void:
	visible = false
	if get_parent() != null and _prev_index >= 0:
		get_parent().move_child(self, mini(_prev_index, get_parent().get_child_count() - 1))
		_prev_index = -1

func _close_request() -> void:
	UITheme.sfx("ui_back")
	if Game.overlay_open and Game.state != Game.State.MENU:
		Game.close_overlays()
	else:
		close()

func _unhandled_input(ev: InputEvent) -> void:
	if not visible:
		return
	# Esc / F1 close it from every place it can be opened (menu, pause menu, in-game overlay)
	if ev.is_action_pressed("pause") or (ev.is_action_pressed("controls") and not ev.is_echo()):
		get_viewport().set_input_as_handled()
		_close_request()
