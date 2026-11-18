class_name UIToggle
extends Control
## Themed on/off switch. Emits toggled(on).

signal toggled(on: bool)

var on: bool = false
var accent: Color = UITheme.ACCENT
var _anim: float = 0.0
var _hover: bool = false

func _init(p_on: bool = false) -> void:
	on = p_on
	_anim = 1.0 if on else 0.0
	custom_minimum_size = Vector2(58, 30)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())

func set_on_silent(v: bool) -> void:
	on = v
	_anim = 1.0 if v else 0.0
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			on = not on
			UITheme.sfx("ui_click")
			toggled.emit(on)
			var tw := create_tween()
			tw.tween_method(func(v: float): _anim = v; queue_redraw(), _anim, 1.0 if on else 0.0, 0.14)
			accept_event()

func _draw() -> void:
	var w := 50.0
	var h := 24.0
	var r := Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)
	var bg := Color(1, 1, 1, 0.10).lerp(UITheme.ca(accent, 0.45), _anim)
	var sb := UITheme.flat(bg, UITheme.ca(accent, 0.35 + 0.5 * _anim + (0.15 if _hover else 0.0)), 1, 12)
	draw_style_box(sb, r)
	var kx := lerpf(r.position.x + 12.0, r.end.x - 12.0, _anim)
	var kc := UITheme.TEXT_DIM.lerp(Color.WHITE, _anim)
	draw_circle(Vector2(kx, r.position.y + h * 0.5), 8.0, kc)
