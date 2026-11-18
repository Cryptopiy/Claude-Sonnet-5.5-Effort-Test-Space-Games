class_name ScreenFx
extends ColorRect
## Full-screen post effects layer (heat, damage, black hole, warp, fades, underwater). Drawn above the 3D view, below the HUD.

var mat: ShaderMaterial
var fade: float = 0.0
var flash: float = 0.0
var damage: float = 0.0
var warp: float = 0.0
var bh: float = 0.0
var bh_swirl: float = 0.0
var heat: float = 0.0
var under: float = 0.0
var speed_lines: float = 0.0
var aberration: float = 0.0

func _init() -> void:
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/screen_fx.gdshader")
	material = mat
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	damage = maxf(0.0, damage - delta * 1.8)
	flash = maxf(0.0, flash - delta * 1.5)
	var active: bool = fade > 0.001 or flash > 0.001 or damage > 0.001 or warp > 0.001 or bh > 0.001 or heat > 0.01 or under > 0.001 or speed_lines > 0.01 or aberration > 0.001
	visible = active
	if not active:
		return
	mat.set_shader_parameter("fade", fade)
	mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("damage", damage)
	mat.set_shader_parameter("warp", warp)
	mat.set_shader_parameter("bh", bh)
	mat.set_shader_parameter("bh_swirl", bh_swirl)
	mat.set_shader_parameter("heat", heat)
	mat.set_shader_parameter("under", under)
	mat.set_shader_parameter("speed_lines", speed_lines)
	mat.set_shader_parameter("aberration", aberration)

func hit(amount: float = 1.0) -> void:
	damage = clampf(damage + amount, 0.0, 1.0)
