class_name InventoryPanel
extends Control
## INVENTORY (module M6): resources (colour-coded icons), warp cells (+ progress to the next cell), pulse fuel + hull, exosuit status.
## Zyrite refuels the pulse drive, Ferrite repairs the hull (USE buttons). Overlay contract: open() / close() (process_mode ALWAYS).

class ResIcon extends Control:
	var rid: String = "ferrite"
	var pulse: float = 0.0
	func _init() -> void:
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var col := UITheme.resource_color(rid)
		var c := size * 0.5
		draw_texture_rect(UITheme.glow_tex(), Rect2(c - Vector2(34, 34), Vector2(68, 68)), false, UITheme.ca(col, 0.55))
		match rid:
			"ferrite":
				var pts := PackedVector2Array()
				for i in 7:
					var a := TAU * float(i) / 6.0 + 0.3
					pts.append(c + Vector2(cos(a), sin(a)) * (21.0 if i % 2 == 0 else 24.0))
				pts.resize(6)
				draw_colored_polygon(pts, Color(0.30, 0.31, 0.34))
				for q in 3:
					var a2 := 0.9 + float(q) * 2.0
					draw_line(c + Vector2(cos(a2), sin(a2)) * 4.0, c + Vector2(cos(a2 + 0.3), sin(a2 + 0.3)) * 19.0, col, 2.5)
				var loop := pts.duplicate()
				loop.append(pts[0])
				draw_polyline(loop, UITheme.ca(col, 0.9), 1.5, true)
			"zyrite":
				for k in 3:
					var off := Vector2(float(k - 1) * 12.0, float(absi(k - 1)) * 5.0)
					var h := 26.0 - float(absi(k - 1)) * 7.0
					draw_colored_polygon(PackedVector2Array([c + off + Vector2(0, -h), c + off + Vector2(8, 0), c + off + Vector2(0, h * 0.55), c + off + Vector2(-8, 0)]), col.lerp(Color.WHITE, 0.15 * float(k)))
				draw_polyline(PackedVector2Array([c + Vector2(0, -26), c + Vector2(8, 0), c + Vector2(0, 14), c + Vector2(-8, 0), c + Vector2(0, -26)]), Color(1, 1, 1, 0.7), 1.2, true)
			"sodium":
				draw_circle(c + Vector2(0, 4), 16.0, col.darkened(0.25))
				draw_circle(c + Vector2(-3, 1), 13.0, col)
				draw_circle(c + Vector2(-7, -4), 4.0, col.lerp(Color.WHITE, 0.7))
				draw_line(c + Vector2(0, -12), c + Vector2(4, -24), col.darkened(0.3), 3.0)
				draw_line(c + Vector2(4, -24), c + Vector2(12, -26), col.darkened(0.3), 3.0)
			"voidstone":
				var s := 24.0
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(6, -6), c + Vector2(s * 0.7, 0), c + Vector2(6, 6), c + Vector2(0, s), c + Vector2(-6, 6), c + Vector2(-s * 0.7, 0), c + Vector2(-6, -6)]), col)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.55), c + Vector2(3.5, -3.5), c + Vector2(0, s * 0.3), c + Vector2(-3.5, -3.5)]), col.lerp(Color.WHITE, 0.65))
			_:
				draw_circle(c, 18.0, col)

class BarRow extends Control:
	var title: String = ""
	var color: Color = UITheme.ACCENT
	var getter: Callable
	var _v: float = 0.0
	var _has: bool = true
	func _init(p_title: String, p_color: Color, p_get: Callable) -> void:
		title = p_title
		color = p_color
		getter = p_get
		custom_minimum_size = Vector2(0, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(dt: float) -> void:
		if not is_visible_in_tree():
			return
		var g: Variant = getter.call()
		if g == null:
			_has = false
		else:
			_has = true
			_v = lerpf(_v, float(g), 1.0 - exp(-8.0 * dt))
		queue_redraw()
	func _draw() -> void:
		UITheme.text(self, Vector2(0, 12), title, 12, UITheme.TEXT_DIM, 0.0, UITheme.font_caps(), false)
		if not _has:
			UITheme.text(self, Vector2(size.x, 12), "-", 13, UITheme.TEXT_FAINT, 1.0, null, false)
			UITheme.draw_bar(self, Rect2(0, 19, size.x, 7), 0.0, color, 36)
			return
		var c := color
		if _v < 0.25:
			c = UITheme.DANGER
		UITheme.text(self, Vector2(size.x, 12), "%d%%" % int(round(_v * 100.0)), 13, UITheme.TEXT, 1.0, null, false)
		UITheme.draw_bar(self, Rect2(0, 19, size.x, 7), _v, c, 36)

class WarpIcon extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(70, 70)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_dt: float) -> void:
		if is_visible_in_tree():
			queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var t := Time.get_ticks_msec() / 1000.0
		draw_texture_rect(UITheme.glow_tex(), Rect2(c - Vector2(48, 48), Vector2(96, 96)), false, UITheme.ca(UITheme.VIOLET, 0.55 + 0.15 * sin(t * 2.0)))
		UITheme.draw_diamond(self, c, 25.0, UITheme.VIOLET, true)
		UITheme.draw_diamond(self, c, 25.0, Color.WHITE, false, 1.5)
		UITheme.draw_diamond(self, c, 12.0, UITheme.VIOLET.lerp(Color.WHITE, 0.7), true)
		draw_arc(c, 32.0 + 2.0 * sin(t * 2.0), t, t + 2.0, 16, UITheme.ca(UITheme.VIOLET, 0.8), 2.0, true)
		draw_arc(c, 32.0 + 2.0 * sin(t * 2.0), t + PI, t + PI + 2.0, 16, UITheme.ca(UITheme.VIOLET, 0.8), 2.0, true)

var _bg: ColorRect
var _mat: ShaderMaterial
var _amount: Dictionary = {}       # id -> Label
var _use_btn: Dictionary = {}      # id -> UIButton
var _warp_num: Label
var _warp_prog: Label
var _warp_bar: Control
var _t_refresh: float = 0.0
var _tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/ui_blur.gdshader")
	_mat.set_shader_parameter("tint_amount", 0.62)
	_bg.material = _mat
	add_child(_bg)
	_build()
	Events.inventory_changed.connect(_refresh)
	visible = false
	set_process(false)

func _build() -> void:
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 150)
	outer.add_theme_constant_override("margin_right", 150)
	outer.add_theme_constant_override("margin_top", 70)
	outer.add_theme_constant_override("margin_bottom", 70)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(outer)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	outer.add_child(vb)
	var head := HBoxContainer.new()
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UITheme.label("CARGO AND SYSTEMS", 13, UITheme.ACCENT, true))
	hv.add_child(UITheme.label("INVENTORY", 40, UITheme.TEXT, true))
	head.add_child(hv)
	var close_btn := UIButton.new("CLOSE   [I]", "primary")
	close_btn.custom_minimum_size = Vector2(170, 44)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): Game.close_overlays())
	head.add_child(close_btn)
	vb.add_child(head)
	vb.add_child(UITheme.hline(UITheme.ca(UITheme.ACCENT, 0.5)))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(cols)
	# --- resources (2 x 2)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(grid)
	for id in ["ferrite", "zyrite", "sodium", "voidstone"]:
		grid.add_child(_resource_card(id))
	# --- right column
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	right.custom_minimum_size = Vector2(340, 0)
	cols.add_child(right)
	right.add_child(_warp_card())
	right.add_child(_ship_card())
	right.add_child(_suit_card())

func _resource_card(id: String) -> UIPanel:
	var info: Dictionary = ResourceDB.info(id)
	var col: Color = info.get("color", UITheme.ACCENT)
	var card := UIPanel.new(16, str(info.get("name", id)).to_upper())
	card.accent = col
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_content(vb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	var icon := ResIcon.new()
	icon.rid = id
	hb.add_child(icon)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", -4)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var amt := UITheme.label("0", 46, UITheme.TEXT)
	amt.add_theme_font_override("font", UITheme.font_bold())
	nv.add_child(amt)
	nv.add_child(UITheme.label("UNITS IN CARGO", 11, UITheme.TEXT_FAINT, true))
	hb.add_child(nv)
	vb.add_child(hb)
	var desc := UITheme.label(str(info.get("use", "")), 14, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(250, 0)
	vb.add_child(desc)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sp)
	match id:
		"zyrite":
			var b := UIButton.new("REFUEL PULSE DRIVE  (-1)", "small")
			b.pressed.connect(func(): _use("zyrite"))
			vb.add_child(b)
			_use_btn[id] = b
		"ferrite":
			var b2 := UIButton.new("REPAIR HULL  (-1)", "small")
			b2.pressed.connect(func(): _use("ferrite"))
			vb.add_child(b2)
			_use_btn[id] = b2
		"sodium":
			var l := UITheme.label("Used automatically on foot when protection runs low", 12, UITheme.TEXT_FAINT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(250, 0)
			vb.add_child(l)
		"voidstone":
			_warp_prog = UITheme.label("", 13, UITheme.VIOLET)
			vb.add_child(_warp_prog)
	_amount[id] = amt
	return card

func _warp_card() -> UIPanel:
	var card := UIPanel.new(16, "HYPERDRIVE")
	card.accent = UITheme.VIOLET
	card.custom_minimum_size = Vector2(340, 0)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	hb.add_child(WarpIcon.new())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_warp_num = UITheme.label("0", 46, UITheme.TEXT)
	_warp_num.add_theme_font_override("font", UITheme.font_bold())
	v.add_child(_warp_num)
	v.add_child(UITheme.label("WARP CELLS", 12, UITheme.TEXT_DIM, true))
	hb.add_child(v)
	card.add_content(hb)
	return card

func _ship_card() -> UIPanel:
	var card := UIPanel.new(16, "WANDERER  -  SHIP SYSTEMS")
	card.custom_minimum_size = Vector2(340, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(BarRow.new("HULL INTEGRITY", UITheme.GOOD, func() -> Variant: return Game.ship_hull))
	v.add_child(BarRow.new("PULSE FUEL", UITheme.ACCENT, func() -> Variant: return Game.ship_fuel))
	card.add_content(v)
	return card

func _suit_card() -> UIPanel:
	var card := UIPanel.new(16, "EXOSUIT")
	card.accent = UITheme.GOOD
	card.custom_minimum_size = Vector2(340, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(BarRow.new("HEALTH", UITheme.GOOD, func() -> Variant: return Game.tel.get("health", null)))
	v.add_child(BarRow.new("HAZARD PROTECTION", UITheme.WARN, func() -> Variant: return Game.tel.get("protection", null)))
	v.add_child(BarRow.new("JETPACK", UITheme.ACCENT, func() -> Variant: return Game.tel.get("jetpack", null)))
	card.add_content(v)
	return card

# ==============================================================================================================================
func _use(id: String) -> void:
	if int(Game.inventory.get(id, 0)) <= 0:
		Events.notify.emit("No %s in cargo" % str(ResourceDB.info(id).get("name", id)), "warn")
		return
	match id:
		"zyrite":
			if Game.ship_fuel >= 0.995:
				Events.notify.emit("Pulse drive fuel is already full", "info")
				return
			Game.consume_resource("zyrite", 1)
			Game.ship_fuel = minf(1.0, Game.ship_fuel + 0.2)
			Events.notify.emit("Pulse drive refuelled  (%d%%)" % int(round(Game.ship_fuel * 100.0)), "good")
		"ferrite":
			if Game.ship_hull >= 0.995:
				Events.notify.emit("Hull is already at full integrity", "info")
				return
			Game.consume_resource("ferrite", 1)
			Game.ship_hull = minf(1.0, Game.ship_hull + 0.12)
			Events.notify.emit("Hull repaired  (%d%%)" % int(round(Game.ship_hull * 100.0)), "good")
	UITheme.sfx("pickup")
	_refresh()

func _refresh() -> void:
	for id in _amount:
		var n: int = int(Game.inventory.get(id, 0))
		var l: Label = _amount[id]
		l.text = str(n)
		l.add_theme_color_override("font_color", UITheme.TEXT if n > 0 else UITheme.TEXT_FAINT)
		if _use_btn.has(id):
			(_use_btn[id] as UIButton).disabled = n <= 0
	if _warp_num != null:
		_warp_num.text = str(Game.warp_cells)
	if _warp_prog != null:
		var vs: int = int(Game.inventory.get("voidstone", 0))
		_warp_prog.text = "Next warp cell: %d / 3" % vs

func open() -> void:
	visible = true
	set_process(true)
	_refresh()
	modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	UITheme.sfx("ui_open")

func close() -> void:
	visible = false
	set_process(false)

func _process(dt: float) -> void:
	_t_refresh -= dt
	if _t_refresh <= 0.0:
		_t_refresh = 0.4
		_refresh()
