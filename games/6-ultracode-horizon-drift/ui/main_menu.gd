class_name MainMenu
extends Control
## MAIN MENU (module M6): animated volumetric-galaxy backdrop + planet horizon, title, Start / Controls / Settings / Quit.

const VERSION := "v0.1.0"

class Deco extends Control:
	## title, drifting stars, shooting stars, loading spinner (all custom drawn)
	var menu: MainMenu
	var stars: Array = []
	var shoot_t: float = 4.0
	var shoot: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 424242
		for i in 150:
			stars.append({"p": Vector2(rng.randf(), rng.randf()), "z": rng.randf_range(0.2, 1.0), "ph": rng.randf() * TAU, "s": rng.randf_range(0.8, 2.2)})

	func _process(dt: float) -> void:
		if not is_visible_in_tree():
			return
		shoot_t -= dt
		if shoot_t <= 0.0 and shoot.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			shoot = {"p": Vector2(rng.randf_range(0.35, 1.0), rng.randf_range(0.02, 0.35)), "t": 0.0, "dir": Vector2(-1.0, 0.45).normalized()}
			shoot_t = rng.randf_range(5.0, 11.0)
		if not shoot.is_empty():
			shoot["t"] = float(shoot["t"]) + dt
			if float(shoot["t"]) > 0.9:
				shoot = {}
		queue_redraw()

	func _draw() -> void:
		var t := menu._t
		# left-side darkening for legibility
		var w := size.x
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.62, 0), Vector2(w * 0.62, h), Vector2(0, h)]),
			PackedColorArray([Color(0.0, 0.01, 0.03, 0.82), Color(0.0, 0.01, 0.03, 0.0), Color(0.0, 0.01, 0.03, 0.0), Color(0.0, 0.01, 0.03, 0.82)]))
		draw_polygon(PackedVector2Array([Vector2(0, h * 0.78), Vector2(w, h * 0.78), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55)]))
		# drifting stars
		for s in stars:
			var z: float = s["z"]
			var p: Vector2 = s["p"]
			var x := fposmod(p.x * w - t * 6.0 * z, w)
			var y := p.y * h + sin(t * 0.2 + float(s["ph"])) * 3.0 * z
			var tw := 0.55 + 0.45 * sin(t * (0.8 + z) + float(s["ph"]))
			var r := float(s["s"]) * z
			draw_circle(Vector2(x, y), r, Color(0.8, 0.9, 1.0, 0.55 * tw * z))
		# shooting star
		if not shoot.is_empty():
			var k := float(shoot["t"]) / 0.9
			var p0: Vector2 = (shoot["p"] as Vector2) * size
			var dir: Vector2 = shoot["dir"]
			var head := p0 + dir * k * 420.0
			var tail := head - dir * 110.0 * sin(k * PI)
			draw_line(tail, head, Color(0.85, 0.95, 1.0, 0.9 * sin(k * PI)), 2.0, true)
		# title block
		var intro: float = menu._intro
		var ix := 96.0
		var ty := h * 0.5 - 150.0
		var a1 := UITheme.ease_out(clampf(intro / 0.7, 0.0, 1.0))
		var a2 := UITheme.ease_out(clampf((intro - 0.25) / 0.7, 0.0, 1.0))
		var a3 := UITheme.ease_out(clampf((intro - 0.5) / 0.7, 0.0, 1.0))
		var cap := UITheme.font_caps()
		UITheme.text(self, Vector2(ix + 4.0, ty - 62.0 + (1.0 - a1) * 14.0), "A  S P A C E   E X P L O R A T I O N   G A M E", 14, UITheme.ca(UITheme.ACCENT, 0.85 * a1), 0.0, cap, false)
		# glow behind title
		var title := "HORIZON DRIFT"
		var tp := Vector2(ix - 4.0 - (1.0 - a2) * 40.0, ty + 36.0)
		var f := UITheme.font_bold()
		var tfs := 78
		for gi in range(4, 0, -1):
			var off := float(gi) * 1.6
			for d in [Vector2(off, 0), Vector2(-off, 0), Vector2(0, off), Vector2(0, -off)]:
				draw_string(cap, tp + d, title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(0.2, 0.7, 1.0, 0.045 * a2))
		draw_string(cap, tp + Vector2(2, 3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(0, 0, 0, 0.6 * a2))
		draw_string(cap, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(0.94, 0.98, 1.0, a2))
		# gradient underline + diamond
		var lw := 560.0 * a3
		draw_polygon(PackedVector2Array([Vector2(ix, ty + 56.0), Vector2(ix + lw, ty + 56.0), Vector2(ix + lw, ty + 58.0), Vector2(ix, ty + 58.0)]),
			PackedColorArray([UITheme.ACCENT, Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.0), Color(UITheme.ACCENT.r, UITheme.ACCENT.g, UITheme.ACCENT.b, 0.0), UITheme.ACCENT]))
		UITheme.draw_diamond(self, Vector2(ix + 3.0, ty + 57.0), 5.0, UITheme.ca(UITheme.ACCENT_HI, a3), true)
		UITheme.text(self, Vector2(ix + 2.0, ty + 90.0), "Chart the stars. Land on any world. Fall through a black hole.", 19, UITheme.ca(UITheme.TEXT_DIM, a3), 0.0, null, true)
		# footer
		UITheme.text(self, Vector2(ix, h - 34.0), "HORIZON DRIFT  " + VERSION + "   -   Godot 4.7  -  seed %d  -  %d stars charted" % [Universe.GALAXY_SEED, Universe.galaxy.size()], 13, UITheme.ca(UITheme.TEXT_FAINT, 0.9 * a3), 0.0, null, false)
		UITheme.text(self, Vector2(w - 40.0, h - 34.0), "ENTER  -  begin journey", 13, UITheme.ca(UITheme.TEXT_FAINT, 0.9 * a3), 1.0, null, false)
		# loading state
		if menu._loading:
			var c := Vector2(ix + 14.0, h * 0.5 + 58.0)
			for i in 3:
				var a0 := t * 3.0 + float(i) * TAU / 3.0
				draw_arc(c, 13.0, a0, a0 + 1.2, 12, UITheme.ca(UITheme.ACCENT, 0.9 - 0.25 * float(i)), 2.5, true)
			UITheme.text(self, c + Vector2(30.0, 6.0), menu._status_text, 17, UITheme.ca(UITheme.TEXT, 0.9), 0.0, cap, true)

var _t: float = 0.0
var _intro: float = 0.0
var _loading: bool = false
var _status_text: String = ""
var _gcam: GalaxyCam = GalaxyCam.new()
var _bg: ColorRect
var _bg_mat: ShaderMaterial
var _planet: ColorRect
var _planet_mat: ShaderMaterial
var _deco: Deco
var _box: VBoxContainer
var _buttons: Array = []
var _settings: SettingsPanel
var _settings_wrap: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.apply_scaling(get_window())
	# --- backdrop
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = load("res://shaders/ui_galaxy.gdshader")
	_bg_mat.set_shader_parameter("steps", 34)
	_bg_mat.set_shader_parameter("brightness", 1.7)
	_bg.material = _bg_mat
	add_child(_bg)
	_planet = ColorRect.new()
	_planet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_planet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_planet_mat = ShaderMaterial.new()
	_planet_mat.shader = load("res://shaders/ui_planet.gdshader")
	_planet.material = _planet_mat
	add_child(_planet)
	_deco = Deco.new()
	_deco.menu = self
	_deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_deco)
	# --- buttons
	_box = VBoxContainer.new()
	_box.anchor_left = 0.0
	_box.anchor_right = 0.0
	_box.anchor_top = 0.5
	_box.anchor_bottom = 0.5
	_box.offset_left = 96.0
	_box.offset_right = 96.0 + 380.0
	_box.offset_top = 46.0
	_box.offset_bottom = 46.0 + 290.0
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)
	var start := _add_button("START JOURNEY")
	start.pressed.connect(_on_start)
	var controls := _add_button("CONTROLS")
	controls.pressed.connect(func(): Game.controls_panel.call("open"))
	var settings := _add_button("SETTINGS")
	settings.pressed.connect(func(): _show_settings(true))
	var quit := _add_button("QUIT")
	quit.pressed.connect(func(): get_tree().quit())
	# --- settings modal
	_settings_wrap = CenterContainer.new()
	_settings_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_wrap.visible = false
	add_child(_settings_wrap)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	move_child(dim, _settings_wrap.get_index())
	_settings_wrap.visibility_changed.connect(func(): dim.visible = _settings_wrap.visible)
	dim.visible = false
	_settings = SettingsPanel.new()
	_settings.back_requested.connect(func(): _show_settings(false))
	_settings_wrap.add_child(_settings)
	SettingsPanel.load_saved()
	_settings.sync_from_game()
	resized.connect(_update_backdrop)
	visibility_changed.connect(_on_visibility)
	Events.returned_to_menu.connect(func(): Frame.clear_space_objects())
	_play_intro()
	_update_backdrop()

func _add_button(text: String) -> UIButton:
	var b := UIButton.new(text, "menu")
	b.custom_minimum_size = Vector2(380, 54)
	_box.add_child(b)
	_buttons.append(b)
	return b

func _show_settings(on: bool) -> void:
	_settings_wrap.visible = on
	_box.visible = not on
	if on:
		_settings.sync_from_game()

func _play_intro() -> void:
	_intro = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_intro", 2.0, 2.0)
	for i in _buttons.size():
		var b: UIButton = _buttons[i]
		b.modulate.a = 0.0
		var t2 := create_tween()
		t2.tween_interval(0.55 + 0.09 * float(i))
		t2.tween_property(b, "modulate:a", 1.0, 0.4)

func _on_visibility() -> void:
	if visible:
		_loading = false
		_show_settings(false)
		for b in _buttons:
			(b as UIButton).disabled = false
		_play_intro()

func _on_start() -> void:
	if _loading:
		return
	_loading = true
	_status_text = "CHARTING THE AURELIA SYSTEM"
	for b in _buttons:
		(b as UIButton).disabled = true
	await get_tree().create_timer(0.3).timeout
	await Game.start_game({})
	_loading = false

func _unhandled_input(ev: InputEvent) -> void:
	if not visible or _loading:
		return
	# F1 = controls overview (action based, so remapped keys and injected actions work too)
	if ev.is_action_pressed("controls") and not ev.is_echo():
		if not _settings_wrap.visible and Game.controls_panel != null and not Game.controls_panel.visible:
			get_viewport().set_input_as_handled()
			Game.controls_panel.call("open")
		return
	if ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		var kc := (ev as InputEventKey).keycode
		if (kc == KEY_ENTER or kc == KEY_KP_ENTER) and not _settings_wrap.visible and not (Game.controls_panel != null and Game.controls_panel.visible):
			get_viewport().set_input_as_handled()
			_on_start()
		elif kc == KEY_ESCAPE and _settings_wrap.visible:
			get_viewport().set_input_as_handled()
			_show_settings(false)
		elif kc == KEY_F1 and not _settings_wrap.visible and Game.controls_panel != null and not Game.controls_panel.visible:
			get_viewport().set_input_as_handled()
			Game.controls_panel.call("open")

func _update_backdrop() -> void:
	var vp := size
	if vp.y < 1.0:
		return
	_planet_mat.set_shader_parameter("aspect", vp.x / vp.y)
	_bg_mat.set_shader_parameter("aspect", vp.x / vp.y)

func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	_t += dt
	# galaxy: orbit slowly, galaxy centre off to the right of the frame
	_gcam.target = Vector3(-17000.0, -1500.0, 4000.0)
	_gcam.yaw = 0.55 + _t * 0.010
	_gcam.pitch = 0.40 + 0.03 * sin(_t * 0.07)
	_gcam.dist = 60000.0
	_gcam.fov_deg = 52.0
	_gcam.update()
	_gcam.apply(_bg_mat, size)
	_bg_mat.set_shader_parameter("rot", 0.0)
	_planet_mat.set_shader_parameter("time_s", _t)
	var appear := UITheme.ease_out(clampf((_t - 0.3) / 1.6, 0.0, 1.0))
	_planet.modulate.a = appear
	_planet_mat.set_shader_parameter("center", Vector2(1.38 + (1.0 - appear) * 0.25, 1.52))
	_planet_mat.set_shader_parameter("radius", 0.92)
