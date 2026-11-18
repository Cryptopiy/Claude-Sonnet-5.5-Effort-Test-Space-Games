class_name PoiMarker
extends Node3D
## Vertical light shaft + floating name label for landing pads and revealed points of interest (M7a). The node is placed at the POI's ground
## position with its +Y along the planet up. Visible from kilometres away.

const BEAM_SHADER := "res://shaders/scatter_beam.gdshader"
static var _shader: Shader

var label_text := ""
var color := Color(0.3, 0.9, 1.0)
var beam_h := 160.0
var beam: MeshInstance3D
var label: Label3D
var _t := 0.0
var _poi_dir := Vector3.UP

func setup(p_label: String, p_color: Color, p_height: float = 160.0) -> void:
	label_text = p_label
	color = p_color
	beam_h = p_height

func _ready() -> void:
	if _shader == null:
		_shader = load(BEAM_SHADER) as Shader
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45
	cyl.bottom_radius = 0.8
	cyl.height = beam_h
	cyl.radial_segments = 16
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam = MeshInstance3D.new()
	beam.mesh = cyl
	beam.position.y = beam_h * 0.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("beam_color", color)
	m.set_shader_parameter("beam_height", beam_h)
	m.set_shader_parameter("intensity", 1.25)
	beam.material_override = m
	add_child(beam)
	label = Label3D.new()
	label.text = label_text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.00055
	label.font_size = 52
	label.outline_size = 12
	label.modulate = color.lightened(0.3)
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.position.y = 14.0
	label.double_sided = true
	add_child(label)

func _process(dt: float) -> void:
	_t += dt
	if _t < 0.4:
		return
	_t = 0.0
	if label == null:
		return
	var f := Frame.focus
	if f == null or not is_instance_valid(f):
		return
	var d := global_position.distance_to(f.global_position)
	label.visible = d > 30.0 and d < 9000.0
	if label.visible:
		var ds := "%d m" % int(d) if d < 1000.0 else "%.1f km" % (d / 1000.0)
		label.text = "%s\n%s" % [label_text, ds]
	if beam != null:
		beam.visible = d > 12.0
