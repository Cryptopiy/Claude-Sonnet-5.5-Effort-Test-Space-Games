class_name UIPanel
extends Control
## Chamfered glass panel with accent ticks. Put children into `body` (a MarginContainer) - the panel sizes itself to its content.

var fill: Color = UITheme.PANEL
var line: Color = UITheme.LINE
var accent: Color = UITheme.ACCENT
var cut: float = 12.0
var title: String = ""
var body: MarginContainer

func _init(margin: int = 16, p_title: String = "") -> void:
	title = p_title
	body = MarginContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_theme_constant_override("margin_left", margin)
	body.add_theme_constant_override("margin_right", margin)
	body.add_theme_constant_override("margin_bottom", margin)
	body.add_theme_constant_override("margin_top", margin + (14 if p_title != "" else 0))
	add_child(body)
	body.minimum_size_changed.connect(update_minimum_size)
	mouse_filter = Control.MOUSE_FILTER_STOP

func add_content(c: Control) -> void:
	body.add_child(c)

func _get_minimum_size() -> Vector2:
	return body.get_combined_minimum_size()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	UITheme.draw_chamfer(self, r, cut, fill, line, 1.0)
	# accent ticks on the cut corners
	draw_line(Vector2(cut, 0.5), Vector2(cut + 34.0, 0.5), accent, 2.0)
	draw_line(Vector2(size.x - cut - 34.0, size.y - 0.5), Vector2(size.x - cut, size.y - 0.5), accent, 2.0)
	if title != "":
		UITheme.text(self, Vector2(cut + 46.0, 15.0), title, 12, UITheme.ca(accent, 0.9), 0.0, UITheme.font_caps(), false)
