class_name StarBody
extends Node3D
## The system's star: turbulent emissive sphere + animated corona billboard.

const STAR_SHADER := preload("res://shaders/star.gdshader")
const CORONA_SHADER := preload("res://shaders/corona.gdshader")

var radius: float = 6000.0
var color: Color = Color(1.0, 0.9, 0.65)
var upos: Array = [0.0, 0.0, 0.0]


func setup(r: float, col: Color) -> void:
	radius = r
	color = col
	name = "Star"
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 96
	sm.rings = 48
	var m := ShaderMaterial.new()
	m.shader = STAR_SHADER
	m.set_shader_parameter("star_col", col)
	m.set_shader_parameter("intensity", 3.2)
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	var cm := ShaderMaterial.new()
	cm.shader = CORONA_SHADER
	cm.set_shader_parameter("star_col", col)
	cm.set_shader_parameter("core", 1.0 / 7.0)
	cm.set_shader_parameter("intensity", 1.6)
	var cmi := MeshInstance3D.new()
	cmi.mesh = q
	cmi.material_override = cm
	cmi.scale = Vector3.ONE * r * 7.0
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cmi.extra_cull_margin = 16384.0
	add_child(cmi)
