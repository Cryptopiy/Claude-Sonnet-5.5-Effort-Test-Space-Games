class_name PauseMenu
extends Control
## PAUSE MENU (module M6): Resume / Controls / Settings / Quit to menu / Quit game. Shown on Events.game_paused(true). process_mode ALWAYS (main.gd).

var _bg: ColorRect
var _mat: ShaderMaterial
var _main: UIPanel
var _settings: SettingsPanel
var _info: Label
var _quit_btn: UIButton
var _confirm_t: float = 0.0
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	Events.game_paused.connect(_on_paused)
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/ui_blur.gdshader")
	_mat.set_shader_parameter("tint_amount", 0.42)
	_mat.set_shader_parameter("blur_lod", 3.0)
	_bg.material = _mat
	add_child(_bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	# --- main page
	_main = UIPanel.new(26, "")
	_main.custom_minimum_size = Vector2(440, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_main.add_content(vb)
	var tag := UITheme.label("GAME SUSPENDED", 13, UITheme.ACCENT, true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(tag)
	var title := UITheme.label("PAUSED", 44, UITheme.TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	_info = UITheme.label("", 14, UITheme.TEXT_DIM)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_info)
	vb.add_child(UITheme.spacer(6))
	var resume := _btn(vb, "RESUME", "menu")
	resume.pressed.connect(func(): Game.resume())
	var controls := _btn(vb, "CONTROLS", "menu")
	controls.pressed.connect(func(): Game.controls_panel.call("open"))
	var settings := _btn(vb, "SETTINGS", "menu")
	settings.pressed.connect(func(): _show_page(true))
	_quit_btn = _btn(vb, "QUIT TO MAIN MENU", "menu")
	_quit_btn.pressed.connect(_on_quit_menu)
	var quit := _btn(vb, "QUIT GAME", "menu")
	quit.set_accent(UITheme.DANGER)
	quit.pressed.connect(func(): get_tree().quit())
	center.add_child(_main)
	# --- settings page
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.back_requested.connect(func(): _show_page(false))
	center.add_child(_settings)

func _btn(parent: Control, text: String, kind: String) -> UIButton:
	var b := UIButton.new(text, kind)
	b.custom_minimum_size = Vector2(388, 52)
	parent.add_child(b)
	return b

func _show_page(settings: bool) -> void:
	_main.visible = not settings
	_settings.visible = settings
	if settings:
		_settings.sync_from_game()
	UITheme.sfx("ui_click")

func _on_quit_menu() -> void:
	if _confirm_t > 0.0:
		_confirm_t = 0.0
		visible = false
		# the system's extras (station, asteroids...) are about to be freed: unregister them first or Frame._update_nodes
		# trips over the dead instances every frame (see CORE CHANGE REQUEST: Game.end_game should call this itself)
		Frame.clear_space_objects()
		Game.quit_to_menu()
		return
	_confirm_t = 3.0
	_quit_btn.text = "CLICK AGAIN TO CONFIRM"
	_quit_btn.set_accent(UITheme.WARN)

func _process(dt: float) -> void:
	if _confirm_t > 0.0:
		_confirm_t -= dt
		if _confirm_t <= 0.0:
			_quit_btn.text = "QUIT TO MAIN MENU"
			_quit_btn.set_accent(UITheme.ACCENT)

func _on_paused(p: bool) -> void:
	visible = p
	if p:
		_show_page(false)
		_confirm_t = 0.0
		_quit_btn.text = "QUIT TO MAIN MENU"
		_quit_btn.set_accent(UITheme.ACCENT)
		var sys_name := Universe.system.name if Universe.system != null else "-"
		_info.text = "%s system   -   %s played" % [sys_name, UITheme.fmt_time(Game.playing_time)]
		modulate.a = 0.0
		scale = Vector2.ONE
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, 0.16)
		UITheme.sfx("ui_open")
	else:
		if Game.controls_panel != null and Game.controls_panel.visible and not Game.overlay_open:
			Game.controls_panel.call("close")

func _unhandled_input(ev: InputEvent) -> void:
	if visible and _settings.visible and ev.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_show_page(false)
