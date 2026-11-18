class_name UiKit
extends RefCounted
## Shared UI look: colours, fonts, panel / button styling, small builders.

const C_MAIN: Color = Color(0.45, 0.88, 1.0)
const C_MAIN_DIM: Color = Color(0.45, 0.88, 1.0, 0.45)
const C_WARN: Color = Color(1.0, 0.66, 0.22)
const C_DANGER: Color = Color(1.0, 0.28, 0.25)
const C_GOOD: Color = Color(0.5, 1.0, 0.62)
const C_TEXT: Color = Color(0.86, 0.94, 1.0)
const C_TEXT_DIM: Color = Color(0.7, 0.8, 0.9, 0.7)
const C_PANEL: Color = Color(0.03, 0.06, 0.1, 0.78)

static var _font: Font = null
static var _font_bold: Font = null

static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Consolas", "Arial"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		f.hinting = TextServer.HINTING_LIGHT
		_font = f
	return _font

static func font_bold() -> Font:
	if _font_bold == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Semibold", "Segoe UI", "Arial"])
		f.font_weight = 700
		f.antialiasing = TextServer.FONT_ANTIALIASING_LCD
		_font_bold = f
	return _font_bold

static func panel_style(alpha: float = 0.8, border: Color = C_MAIN_DIM, radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.1, alpha)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = 20
	th.set_color("font_color", "Label", C_TEXT)
	th.set_stylebox("normal", "Button", button_style(Color(0.05, 0.1, 0.16, 0.7), C_MAIN_DIM))
	th.set_stylebox("hover", "Button", button_style(Color(0.08, 0.22, 0.32, 0.9), C_MAIN))
	th.set_stylebox("pressed", "Button", button_style(Color(0.1, 0.32, 0.45, 0.95), C_MAIN))
	th.set_stylebox("focus", "Button", button_style(Color(0.08, 0.22, 0.32, 0.9), C_MAIN))
	th.set_stylebox("disabled", "Button", button_style(Color(0.05, 0.08, 0.1, 0.5), Color(0.3, 0.3, 0.3, 0.4)))
	th.set_color("font_color", "Button", C_TEXT)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_font_size("font_size", "Button", 24)
	th.set_stylebox("panel", "PanelContainer", panel_style())
	th.set_color("font_color", "CheckBox", C_TEXT)
	th.set_color("font_color", "HSlider", C_TEXT)
	return th

static func label(text: String, size: int = 20, color: Color = C_TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold())
	return l
