class_name SpaceDust
extends MultiMeshInstance3D
## Speed streaks / space dust wrapped around the camera (see shaders/dust.gdshader). Needed because in the system frame
## the ship never moves in float space: the viewer's motion is fed to the shader as a wrapped offset instead.

const COUNT: int = 1100
const BOX: float = 220.0

var mat: ShaderMaterial

func _init() -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = qm
	mm.instance_count = COUNT
	multimesh = mm
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/dust.gdshader")
	mat.set_shader_parameter("box", BOX)
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = 1 << 19
	custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
	extra_cull_margin = 2000.0

func update_dust(world: SpaceWorld, pc: PlayerController) -> void:
	var on: bool = pc.mode == PlayerController.Mode.SHIP and not pc.cinematic
	visible = on
	if not on:
		return
	var vpos: Vector3
	if world.frame_idx < 0:
		var d: D3 = world.viewer_sys
		vpos = Vector3(fposmod(d.x, BOX), fposmod(d.y, BOX), fposmod(d.z, BOX))
	else:
		var p: Vector3 = world.viewer_pos
		vpos = Vector3(fposmod(p.x, BOX), fposmod(p.y, BOX), fposmod(p.z, BOX))
	mat.set_shader_parameter("offset", vpos)
	mat.set_shader_parameter("velocity", pc.ship.velocity)
	var thin: float = 1.0 - clampf(world.air * 3.0, 0.0, 1.0)
	mat.set_shader_parameter("intensity", 0.9 * thin)
