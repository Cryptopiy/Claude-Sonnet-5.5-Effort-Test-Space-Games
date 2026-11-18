class_name UISlider
extends Control
## Themed horizontal slider (drag or click). Emits value_changed(v).

signal value_changed(v: float)

var min_v: float = 0.0
var max_v: float = 1.0
var step: float = 0.01
var value: float = 0.5
var accent: Color = UITheme.ACCENT
var _drag: bool = false
var _hover: bool = false

func _init(p_min: float = 0.0, p_max: float = 1.0, p_step: float = 0.01, p_value: float = 0.5) -> void:
	min_v = p_min
	max_v = p_max
	step = p_step
	value = p_value
	custom_minimum_size = Vector2(220, 28)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())

func set_value_silent(v: float) -> void:
	value = clampf(v, min_v, max_v)
	queue_redraw()

func _frac() -> float:
	return (value - min_v) / maxf(max_v - min_v, 0.00001)

func _set_from_x(x: float) -> void:
	var f := clampf((x - 8.0) / maxf(size.x - 16.0, 1.0), 0.0, 1.0)
	var v := min_v + f * (max_v - min_v)
	if step > 0.0:
		v = snappedf(v, step)
	v = clampf(v, min_v, max_v)
	if not is_equal_approx(v, value):
		value = v
		value_changed.emit(value)
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
			if mb.pressed:
				_set_from_x(mb.position.x)
				UITheme.sfx("ui_click")
			accept_event()
	elif ev is InputEventMouseMotion and _drag:
		_set_from_x((ev as InputEventMouseMotion).position.x)
		accept_event()

func _draw() -> void:
	var cy := size.y * 0.5
	var x0 := 8.0
	var x1 := size.x - 8.0
	draw_line(Vector2(x0, cy), Vector2(x1, cy), Color(1, 1, 1, 0.14), 4.0, true)
	var kx := lerpf(x0, x1, _frac())
	draw_line(Vector2(x0, cy), Vector2(kx, cy), UITheme.ca(accent, 0.85), 4.0, true)
	var rad := 9.0 if (_hover or _drag) else 7.5
	draw_circle(Vector2(kx, cy), rad + 3.0, UITheme.ca(accent, 0.22 if (_hover or _drag) else 0.0))
	draw_circle(Vector2(kx, cy), rad, UITheme.ACCENT_HI if (_hover or _drag) else UITheme.TEXT)
	draw_circle(Vector2(kx, cy), rad - 3.5, accent)
