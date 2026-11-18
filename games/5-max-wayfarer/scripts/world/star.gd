class_name StarBody
extends Node3D
## The system's star: animated photosphere + camera facing corona/flare sprite.

var radius: float = 2700.0
var color: Color = Color(1.0, 0.93, 0.76)
var sphere_mi: MeshInstance3D
var glow_mi: MeshInstance3D
var sphere_mat: ShaderMaterial
var glow_mat: ShaderMaterial

func setup(sys: SystemData) -> void:
	name = "Star"
	radius = sys.star_radius
	color = sys.star_color
	sphere_mat = ShaderMaterial.new()
	sphere_mat.shader = load("res://shaders/star.gdshader")
	sphere_mat.set_shader_parameter("star_color", color)
	sphere_mat.set_shader_parameter("seed", float(sys.seed_i % 64))
	sphere_mat.set_shader_parameter("intensity", 6.5)
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 96
	sm.rings = 48
	sphere_mi = MeshInstance3D.new()
	sphere_mi.mesh = sm
	sphere_mi.material_override = sphere_mat
	sphere_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sphere_mi.layers = 1 << 19
	add_child(sphere_mi)
	# glow sprite (QuadMesh 1x1 scaled)
	glow_mat = ShaderMaterial.new()
	glow_mat.shader = load("res://shaders/corona.gdshader")
	glow_mat.render_priority = 2
	glow_mat.set_shader_parameter("glow_color", color.lerp(Color.WHITE, 0.15))
	glow_mat.set_shader_parameter("strength", 1.15)
	glow_mat.set_shader_parameter("seed", float(sys.seed_i % 32))
	var sprite_size: float = radius * 16.0
	glow_mat.set_shader_parameter("core_radius", radius / (sprite_size * 0.5))
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	glow_mi = MeshInstance3D.new()
	glow_mi.mesh = qm
	glow_mi.material_override = glow_mat
	glow_mi.scale = Vector3(sprite_size, sprite_size, 1.0)
	glow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow_mi.layers = 1 << 19
	glow_mi.extra_cull_margin = sprite_size
	add_child(glow_mi)
