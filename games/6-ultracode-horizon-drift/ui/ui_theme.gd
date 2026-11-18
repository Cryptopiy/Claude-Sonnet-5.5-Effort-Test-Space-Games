class_name UITheme
extends RefCounted
## Shared look & feel for every HORIZON DRIFT screen (module M6): palette, fonts, theme, drawing + formatting helpers.
## The whole UI is laid out in a virtual 1440x810 canvas; apply_scaling() makes the window scale it (crisp at 720p / 1080p / 1440p).

const BASE_SIZE := Vector2i(1440, 810)

const ACCENT := Color(0.36, 0.86, 1.00)
const ACCENT_DIM := Color(0.20, 0.50, 0.64)
const ACCENT_HI := Color(0.72, 0.96, 1.00)
const TEXT := Color(0.90, 0.96, 1.00)
const TEXT_DIM := Color(0.60, 0.72, 0.82)
const TEXT_FAINT := Color(0.42, 0.53, 0.63)
const PANEL := Color(0.030, 0.050, 0.085, 0.80)
const PANEL_SOLID := Color(0.025, 0.040, 0.070, 0.97)
const PANEL_DARK := Color(0.012, 0.020, 0.040, 0.88)
const LINE := Color(0.30, 0.62, 0.80, 0.50)
const WARN := Color(1.00, 0.72, 0.22)
const DANGER := Color(1.00, 0.33, 0.30)
const GOOD := Color(0.42, 1.00, 0.62)
const DISCOVER := Color(0.84, 0.52, 1.00)
const GOLD := Color(1.00, 0.82, 0.40)
const VIOLET := Color(0.64, 0.48, 1.00)

static var _font: Font = null
static var _font_caps: Font = null
static var _font_bold: Font = null
static var _font_mono: Font = null
static var _theme: Theme = null
static var _glow: Texture2D = null

# ------------------------------------------------------------------------------------------------------------------------
# colours / small helpers
# ------------------------------------------------------------------------------------------------------------------------
static func ca(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

static func kind_color(kind: String) -> Color:
	match kind:
		"good": return GOOD
		"warn": return WARN
		"danger": return DANGER
		"discover": return DISCOVER
		"gold": return GOLD
	return ACCENT

static func ease_out(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u)

static func biome_color(biome: String) -> Color:
	var b: Dictionary = BiomeDB.get_biome(biome)
	return b.get("ui_color", ACCENT)

static func body_color(b: BodyDef) -> Color:
	if b.kind == BodyDef.Kind.BLACK_HOLE:
		return VIOLET
	return biome_color(b.biome)

static func resource_color(id: String) -> Color:
	var info: Dictionary = ResourceDB.info(id)
	return info.get("color", ACCENT)

# ------------------------------------------------------------------------------------------------------------------------
# fonts
# ------------------------------------------------------------------------------------------------------------------------
static func _system_font(names: Array, weight: int = 400) -> SystemFont:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(names)
	sf.font_weight = weight
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sf.hinting = TextServer.HINTING_LIGHT
	sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	var fb: Array[Font] = [ThemeDB.fallback_font]
	sf.fallbacks = fb
	return sf

static func font() -> Font:
	if _font == null:
		_font = _system_font(["Bahnschrift", "Segoe UI", "Roboto", "Arial", "Helvetica"], 400)
	return _font

static func font_bold() -> Font:
	if _font_bold == null:
		var fv := FontVariation.new()
		fv.base_font = font()
		fv.variation_embolden = 0.55
		_font_bold = fv
	return _font_bold

## tracked-out capitals (labels, headings)
static func font_caps() -> Font:
	if _font_caps == null:
		var fv := FontVariation.new()
		fv.base_font = font()
		fv.spacing_glyph = 2
		fv.variation_embolden = 0.25
		_font_caps = fv
	return _font_caps

static func font_mono() -> Font:
	if _font_mono == null:
		_font_mono = _system_font(["Consolas", "Cascadia Mono", "Courier New"], 400)
	return _font_mono

# ------------------------------------------------------------------------------------------------------------------------
# window scaling (virtual 1440x810 canvas)
# ------------------------------------------------------------------------------------------------------------------------
static func apply_scaling(window: Window) -> void:
	if window == null:
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = BASE_SIZE
	var f := float(Game.settings.get("ui_scale", 1.0))
	window.content_scale_factor = clampf(f, 0.6, 2.0)

# ------------------------------------------------------------------------------------------------------------------------
# formatting
# ------------------------------------------------------------------------------------------------------------------------
static func fmt_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out

static func fmt_dist(m: float) -> String:
	var a := absf(m)
	if a < 1000.0:
		return "%d m" % int(a)
	if a < 10000.0:
		return "%.1f km" % (a / 1000.0)
	return "%s km" % fmt_int(int(a / 1000.0))

## [number, unit] for a speed in m/s
static func fmt_speed(v: float) -> Array:
	var a := absf(v)
	if a < 1000.0:
		return ["%d" % int(round(a)), "m/s"]
	return ["%.2f" % (a / 1000.0), "km/s"]

static func fmt_ly(ly: float) -> String:
	if ly < 100.0:
		return "%.1f ly" % ly
	return "%s ly" % fmt_int(int(round(ly)))

static func fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]

# ------------------------------------------------------------------------------------------------------------------------
# drawing primitives (call from a CanvasItem's _draw)
# ------------------------------------------------------------------------------------------------------------------------
## draw text with a soft drop shadow. ax: 0 = pos is the left edge, 0.5 = centre, 1 = right edge. pos.y is the baseline.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, ax: float = 0.0, fnt: Font = null, shadow: bool = true) -> float:
	var f: Font = fnt if fnt != null else font()
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(pos.x - w * ax, pos.y)
	if shadow:
		ci.draw_string(f, p + Vector2(1.0, 1.6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, col.a * 0.7))
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return w

static func text_width(s: String, size: int, fnt: Font = null) -> float:
	var f: Font = fnt if fnt != null else font()
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

static func draw_chamfer(ci: CanvasItem, r: Rect2, cut: float, fill: Color, line: Color, line_w: float = 1.0) -> void:
	var pts := PackedVector2Array([
		Vector2(r.position.x + cut, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - cut),
		Vector2(r.end.x - cut, r.end.y), Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y + cut)])
	if fill.a > 0.0:
		ci.draw_colored_polygon(pts, fill)
	if line.a > 0.0 and line_w > 0.0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		ci.draw_polyline(loop, line, line_w, true)

## segmented bar. value 0..1
static func draw_bar(ci: CanvasItem, r: Rect2, value: float, col: Color, segments: int = 24, back: Color = Color(1, 1, 1, 0.08)) -> void:
	var gap := 2.0
	var sw := (r.size.x - gap * float(segments - 1)) / float(segments)
	var v := clampf(value, 0.0, 1.0) * float(segments)
	for i in segments:
		var x := r.position.x + float(i) * (sw + gap)
		var seg := Rect2(x, r.position.y, sw, r.size.y)
		var f := clampf(v - float(i), 0.0, 1.0)
		ci.draw_rect(seg, back)
		if f > 0.0:
			ci.draw_rect(Rect2(x, r.position.y, sw * f if f < 1.0 else sw, r.size.y), col)

static func draw_diamond(ci: CanvasItem, c: Vector2, r: float, col: Color, filled: bool = false, w: float = 1.5) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if filled:
		ci.draw_colored_polygon(pts, col)
	else:
		var loop := pts.duplicate()
		loop.append(pts[0])
		ci.draw_polyline(loop, col, w, true)

static func draw_brackets(ci: CanvasItem, r: Rect2, ln: float, col: Color, w: float = 1.5) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	ci.draw_polyline(PackedVector2Array([Vector2(x0, y0 + ln), Vector2(x0, y0), Vector2(x0 + ln, y0)]), col, w)
	ci.draw_polyline(PackedVector2Array([Vector2(x1 - ln, y0), Vector2(x1, y0), Vector2(x1, y0 + ln)]), col, w)
	ci.draw_polyline(PackedVector2Array([Vector2(x1, y1 - ln), Vector2(x1, y1), Vector2(x1 - ln, y1)]), col, w)
	ci.draw_polyline(PackedVector2Array([Vector2(x0 + ln, y1), Vector2(x0, y1), Vector2(x0, y1 - ln)]), col, w)

static func draw_triangle(ci: CanvasItem, c: Vector2, dir: Vector2, size: float, col: Color) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([c + d * size, c - d * size * 0.7 + n * size * 0.75, c - d * size * 0.35, c - d * size * 0.7 - n * size * 0.75]), col)

## soft radial sprite (white, alpha falloff) for additive glows
static func glow_tex() -> Texture2D:
	if _glow == null:
		var n := 96
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var half := float(n) * 0.5
		for y in n:
			for x in n:
				var d := Vector2(float(x) - half + 0.5, float(y) - half + 0.5).length() / half
				var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.3)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_glow = ImageTexture.create_from_image(img)
	return _glow

static var _scrim: Texture2D = null
## soft rounded "plate" (flat-ish centre, feathered edges, white): stretch it behind readouts so small text stays legible over bright
## ground / sky. Tint with the modulate colour (typically near-black with alpha 0.5..0.8).
static func scrim_tex() -> Texture2D:
	if _scrim == null:
		var nx_n := 128
		var ny_n := 64
		var img := Image.create(nx_n, ny_n, false, Image.FORMAT_RGBA8)
		for y in ny_n:
			var ny := absf((float(y) + 0.5) / float(ny_n) * 2.0 - 1.0)
			for x in nx_n:
				var nx := absf((float(x) + 0.5) / float(nx_n) * 2.0 - 1.0)
				var k := clampf((1.0 - pow(nx, 3.0)) * (1.0 - pow(ny, 3.0)), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, k * k * (3.0 - 2.0 * k)))
		_scrim = ImageTexture.create_from_image(img)
	return _scrim

static var _vig: Texture2D = null
## radial vignette (transparent centre -> opaque edges), white; tint with modulate
static func vignette_tex() -> Texture2D:
	if _vig == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var half := float(n) * 0.5
		for y in n:
			for x in n:
				var d := Vector2(float(x) - half + 0.5, float(y) - half + 0.5).length() / half
				var a := clampf((d - 0.45) / 0.75, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_vig = ImageTexture.create_from_image(img)
	return _vig

static func additive_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

# ------------------------------------------------------------------------------------------------------------------------
# Control factories
# ------------------------------------------------------------------------------------------------------------------------
static func label(s: String, size: int = 16, col: Color = TEXT, caps: bool = false) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font_caps() if caps else font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func spacer(h: float = 0.0, w: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func hline(col: Color = LINE, margin: float = 0.0) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func sfx(name: String) -> void:
	if Audio != null:
		Audio.sfx(name)

# ------------------------------------------------------------------------------------------------------------------------
# Theme resource (default look for stock controls: ScrollBar, LineEdit, Tooltip ...)
# ------------------------------------------------------------------------------------------------------------------------
static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 2, margin: float = 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	if margin > 0.0:
		s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_font("font", "Label", font())
	t.set_font_size("font_size", "Label", 16)
	# scroll bars
	for sb_name in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_name, flat(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 3))
		t.set_stylebox("grabber", sb_name, flat(ca(ACCENT, 0.35), Color(0, 0, 0, 0), 0, 3))
		t.set_stylebox("grabber_highlight", sb_name, flat(ca(ACCENT, 0.65), Color(0, 0, 0, 0), 0, 3))
		t.set_stylebox("grabber_pressed", sb_name, flat(ca(ACCENT, 0.9), Color(0, 0, 0, 0), 0, 3))
	# tooltip
	t.set_stylebox("panel", "TooltipPanel", flat(PANEL_SOLID, LINE, 1, 3, 8.0))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 15)
	# stock buttons (non-UIButton) get a decent look as well
	var bn := flat(Color(0.06, 0.10, 0.15, 0.85), ca(ACCENT, 0.4), 1, 3, 10.0)
	var bh := flat(Color(0.10, 0.22, 0.30, 0.95), ACCENT, 1, 3, 10.0)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bh)
	t.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), ACCENT, 1, 3, 10.0))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT_HI)
	_theme = t
	return t
