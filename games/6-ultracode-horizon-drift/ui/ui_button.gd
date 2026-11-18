class_name UIButton
extends Button
## Sci-fi button with an animated hover state. kind: "menu" (big, left aligned), "primary", "ghost", "danger", "small".

var kind: String = "primary"
var accent: Color = UITheme.ACCENT
var hv: float = 0.0:
	set(v):
		hv = v
		_refresh()
var _sb: StyleBoxFlat
var _tween: Tween
var _down: bool = false
var _fsize: int = 18

func _init(p_text: String = "", p_kind: String = "primary") -> void:
	text = p_text
	kind = p_kind
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_sb = StyleBoxFlat.new()
	_sb.anti_aliasing = true
	match kind:
		"menu":
			custom_minimum_size = Vector2(340, 54)
			alignment = HORIZONTAL_ALIGNMENT_LEFT
			_fsize = 21
			_sb.set_corner_radius_all(2)
			_sb.content_margin_left = 26
			_sb.border_width_left = 3
			_sb.border_width_bottom = 1
		"small":
			custom_minimum_size = Vector2(0, 32)
			_fsize = 14
			_sb.set_corner_radius_all(3)
			_sb.set_border_width_all(1)
			_sb.content_margin_left = 12
			_sb.content_margin_right = 12
		_:
			custom_minimum_size = Vector2(0, 44)
			_fsize = 17
			_sb.set_corner_radius_all(3)
			_sb.set_border_width_all(1)
			_sb.content_margin_left = 18
			_sb.content_margin_right = 18
	if kind == "danger":
		accent = UITheme.DANGER
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(st, _sb)
	add_theme_font_override("font", UITheme.font_caps())
	add_theme_font_size_override("font_size", _fsize)
	button_down.connect(func(): _down = true; _refresh())
	button_up.connect(func(): _down = false; _refresh())
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	pressed.connect(func(): UITheme.sfx("ui_click"))
	_refresh()

func set_accent(c: Color) -> void:
	accent = c
	_refresh()

func _on_enter() -> void:
	if disabled:
		return
	_animate(1.0, 0.12)

func _on_exit() -> void:
	_animate(0.0, 0.2)

func _animate(to: float, dur: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "hv", to, dur)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_RESIZED:
		if not is_visible_in_tree():
			hv = 0.0

func _refresh() -> void:
	if _sb == null:
		return
	var h := hv
	var base_bg := Color(0.045, 0.075, 0.115, 0.62)
	var hot_bg := Color(accent.r * 0.20 + 0.03, accent.g * 0.30 + 0.04, accent.b * 0.34 + 0.06, 0.88)
	var bg := base_bg.lerp(hot_bg, h)
	if _down:
		bg = bg.lightened(0.12)
	var edge := UITheme.ca(accent, lerpf(0.35, 1.0, h))
	var fc := UITheme.TEXT.lerp(Color.WHITE, h)
	match kind:
		"menu":
			_sb.border_width_left = int(lerpf(3.0, 8.0, h))
			edge = UITheme.ca(accent, lerpf(0.55, 1.0, h))
			_sb.border_color = edge
			bg.a = lerpf(0.45, 0.88, h)
		"ghost":
			bg = Color(1, 1, 1, lerpf(0.0, 0.08, h))
			_sb.border_color = UITheme.ca(accent, lerpf(0.30, 0.9, h))
		_:
			_sb.border_color = edge
	_sb.bg_color = bg
	if disabled:
		_sb.bg_color = Color(0.05, 0.07, 0.10, 0.5)
		_sb.border_color = UITheme.ca(UITheme.TEXT_FAINT, 0.4)
		fc = UITheme.TEXT_FAINT
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		add_theme_color_override(c, fc)
