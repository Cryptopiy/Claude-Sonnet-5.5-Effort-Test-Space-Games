class_name SettingsPanel
extends UIPanel
## Settings page used by the main menu and the pause menu. Writes Game.settings (+ Audio volume, UI scale) and persists them to user://.

signal back_requested

const CFG_PATH := "user://horizon_drift_settings.cfg"
const KEYS := ["mouse_sens", "fov", "invert_y", "volume", "show_fps", "head_bob", "ui_scale"]
const DEFAULTS := {"mouse_sens": 1.0, "fov": 78.0, "invert_y": false, "volume": 0.8, "show_fps": false, "head_bob": true, "ui_scale": 1.0}

var _rows: Dictionary = {}     # key -> control (UISlider / UIToggle)
var _vals: Dictionary = {}     # key -> Label

func _init() -> void:
	super(24, "SETTINGS")
	fill = UITheme.PANEL_SOLID
	for k in DEFAULTS:
		if not Game.settings.has(k):
			Game.settings[k] = DEFAULTS[k]
	custom_minimum_size = Vector2(560, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	add_content(vb)
	_slider(vb, "mouse_sens", "MOUSE SENSITIVITY", 0.2, 3.0, 0.05, func(v: float) -> String: return "%.2fx" % v)
	_slider(vb, "fov", "FIELD OF VIEW", 60.0, 110.0, 1.0, func(v: float) -> String: return "%d°" % int(v))
	_slider(vb, "volume", "MASTER VOLUME", 0.0, 1.0, 0.01, func(v: float) -> String: return "%d%%" % int(round(v * 100.0)))
	_slider(vb, "ui_scale", "INTERFACE SCALE", 0.8, 1.5, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100.0)))
	vb.add_child(UITheme.hline(UITheme.ca(UITheme.LINE, 0.4)))
	_toggle(vb, "invert_y", "INVERT Y AXIS")
	_toggle(vb, "head_bob", "HEAD BOB")
	_toggle(vb, "show_fps", "SHOW FPS COUNTER")
	vb.add_child(UITheme.spacer(6))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	var reset := UIButton.new("RESET DEFAULTS", "ghost")
	reset.pressed.connect(_reset_defaults)
	var back := UIButton.new("BACK", "primary")
	back.custom_minimum_size = Vector2(150, 44)
	back.pressed.connect(func(): back_requested.emit())
	hb.add_child(reset)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	hb.add_child(back)
	vb.add_child(hb)
	sync_from_game()

func _row_label(text: String) -> Label:
	var l := UITheme.label(text, 14, UITheme.TEXT_DIM, true)
	l.custom_minimum_size = Vector2(210, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _slider(parent: Control, key: String, text: String, lo: float, hi: float, step_v: float, fmt: Callable) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.add_child(_row_label(text))
	var s := UISlider.new(lo, hi, step_v, float(Game.settings.get(key, lo)))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(s)
	var vl := UITheme.label("", 16, UITheme.TEXT)
	vl.custom_minimum_size = Vector2(70, 0)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(vl)
	parent.add_child(hb)
	_rows[key] = s
	_vals[key] = vl
	s.value_changed.connect(func(v: float):
		Game.settings[key] = v
		vl.text = str(fmt.call(v))
		_apply(key)
		save())
	vl.text = str(fmt.call(s.value))

func _toggle(parent: Control, key: String, text: String) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.add_child(_row_label(text))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var t := UIToggle.new(bool(Game.settings.get(key, false)))
	hb.add_child(t)
	parent.add_child(hb)
	_rows[key] = t
	t.toggled.connect(func(on: bool):
		Game.settings[key] = on
		_apply(key)
		save())

func sync_from_game() -> void:
	for k in _rows:
		var c: Control = _rows[k]
		if c is UISlider:
			(c as UISlider).set_value_silent(float(Game.settings.get(k, 0.0)))
			var fmtv: float = float(Game.settings.get(k, 0.0))
			var lbl: Label = _vals[k]
			match k:
				"mouse_sens": lbl.text = "%.2fx" % fmtv
				"fov": lbl.text = "%d°" % int(fmtv)
				"volume": lbl.text = "%d%%" % int(round(fmtv * 100.0))
				"ui_scale": lbl.text = "%d%%" % int(round(fmtv * 100.0))
		elif c is UIToggle:
			(c as UIToggle).set_on_silent(bool(Game.settings.get(k, false)))

func _reset_defaults() -> void:
	for k in DEFAULTS:
		Game.settings[k] = DEFAULTS[k]
	for k in KEYS:
		_apply(k)
	sync_from_game()
	save()
	UITheme.sfx("ui_back")

static func _apply(key: String) -> void:
	match key:
		"volume":
			Audio.set_master_volume(float(Game.settings.get("volume", 0.8)))
		"ui_scale":
			UITheme.apply_scaling(Game.main.get_window() if Game.main != null else null)

static func save() -> void:
	var cf := ConfigFile.new()
	for k in KEYS:
		cf.set_value("settings", k, Game.settings.get(k))
	cf.save(CFG_PATH)

static func load_saved() -> void:
	for k in DEFAULTS:
		if not Game.settings.has(k):
			Game.settings[k] = DEFAULTS[k]
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		return
	for k in KEYS:
		if cf.has_section_key("settings", k):
			Game.settings[k] = cf.get_value("settings", k)
	Audio.set_master_volume(float(Game.settings.get("volume", 0.8)))
	UITheme.apply_scaling(Game.main.get_window() if Game.main != null else null)
