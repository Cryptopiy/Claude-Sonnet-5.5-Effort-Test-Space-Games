class_name StarVisual
extends Node3D
## THE STAR (module M2). Position + uniform scale are set by Frame (star at abs origin; far stars are moved closer and scaled so the angular size is kept).
## Children (everything inherits that uniform scale, so nothing here depends on it):
##   * Photosphere : sphere with shaders/star_surface.gdshader (granulation cells, sun spots, limb darkening + reddening, HDR emission -> bloom),
##   * Corona      : camera-facing additive billboard (shaders/star_corona.gdshader): inner corona, halo and slowly drifting rays,
##   * Flare       : full-screen additive overlay (shaders/star_flare.gdshader): halo, anamorphic streak and ghosts along the star-centre axis, depth-tested so
##                   planets / terrain / the ship hide it, tinted by the global sun colour (reddens at sunset, fades at night).
## The DirectionalLight is owned by SkyController, not here.

var def: StarDef
var _surface: MeshInstance3D
var _corona: MeshInstance3D
var _flare: MeshInstance3D
var _mat_surf: ShaderMaterial
var _mat_cor: ShaderMaterial
var _mat_flare: ShaderMaterial
var _t_sent := -1.0
var _flare_k := 1.0
var _corona_k := 1.0

func setup(p_def: StarDef) -> void:
	def = p_def

## surface "hot" and "cool" colours are derived from the class colour; hotter stars (O/B/A) are bluer-white, cool ones (K/M) deep orange / red
func _surface_color() -> Color:
	var c: Color = def.color
	# bring the visible colour into a usable HDR tint: keep hue, push saturation a little
	return Color.from_hsv(c.h, clampf(c.s * 1.45, 0.0, 1.0), 1.0)

func _ready() -> void:
	if def == null:
		return
	var seed_f := float(abs(hash(def.name)) % 997) * 0.137 + 1.0
	var col := _surface_color()
	var tmp_k := clampf((def.temperature - 3000.0) / 9000.0, 0.0, 1.0)       # 0 = cool red dwarf, 1 = hot blue-white

	# --- photosphere ----------------------------------------------------------------------------------------------------------------------------
	var sm := SphereMesh.new()
	sm.radius = def.radius
	sm.height = def.radius * 2.0
	sm.radial_segments = 96
	sm.rings = 48
	_mat_surf = ShaderMaterial.new()
	_mat_surf.shader = load("res://shaders/star_surface.gdshader") as Shader
	_mat_surf.set_shader_parameter("star_col", Vector3(col.r, col.g, col.b))
	_mat_surf.set_shader_parameter("seed", seed_f)
	_mat_surf.set_shader_parameter("spot_amount", lerpf(0.9, 0.25, tmp_k))
	_mat_surf.set_shader_parameter("emission", 2.4)
	# limb darkening: strong, and strongest in blue (cool stars redden harder at the rim; hot blue-white stars keep a whiter edge)
	var lk := lerpf(1.0, 0.80, tmp_k)
	_mat_surf.set_shader_parameter("limb_k", Vector3(0.80, 0.93, 1.0) * lk)
	_mat_surf.set_shader_parameter("gran_scale", lerpf(17.0, 11.0, tmp_k))
	_surface = MeshInstance3D.new()
	_surface.name = "Photosphere"
	_surface.mesh = sm
	_surface.material_override = _mat_surf
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_surface)

	# --- corona / rays billboard ----------------------------------------------------------------------------------------------------------------
	var cs := maxf(def.corona_scale, 3.0)
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	_mat_cor = ShaderMaterial.new()
	_mat_cor.shader = load("res://shaders/star_corona.gdshader") as Shader
	_mat_cor.render_priority = -2
	_mat_cor.set_shader_parameter("star_col", Vector3(col.r, col.g, col.b))
	_mat_cor.set_shader_parameter("corona_scale", cs)
	_mat_cor.set_shader_parameter("seed", seed_f)
	_mat_cor.set_shader_parameter("star_radius_hint", def.radius)
	_mat_cor.set_shader_parameter("intensity", 1.0)
	_corona = MeshInstance3D.new()
	_corona.name = "Corona"
	_corona.mesh = q
	_corona.material_override = _mat_cor
	var ext := def.radius * cs * 1.2
	_corona.custom_aabb = AABB(Vector3(-ext, -ext, -ext), Vector3(ext, ext, ext) * 2.0)
	_corona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_corona.ignore_occlusion_culling = true
	add_child(_corona)

	# --- lens flare overlay ---------------------------------------------------------------------------------------------------------------------
	var fq := QuadMesh.new()
	fq.size = Vector2(2.0, 2.0)
	_mat_flare = ShaderMaterial.new()
	_mat_flare.shader = load("res://shaders/star_flare.gdshader") as Shader
	_mat_flare.render_priority = 5
	var tint := col.lerp(Color(1, 1, 1), 0.35)
	_mat_flare.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_flare = MeshInstance3D.new()
	_flare.name = "LensFlare"
	_flare.mesh = fq
	_flare.material_override = _mat_flare
	_flare.custom_aabb = AABB(Vector3(-1.0e7, -1.0e7, -1.0e7), Vector3(2.0e7, 2.0e7, 2.0e7))
	_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flare.ignore_occlusion_culling = true
	add_child(_flare)

func _process(_dt: float) -> void:
	if _mat_flare == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var sc := global_transform.basis.get_scale().x
	var dist := maxf((global_position - cam.global_position).length(), 1.0)
	var ang := clampf(def.radius * sc / dist, 0.0005, 1.2)
	_mat_flare.set_shader_parameter("star_ang", ang)
	# Inside a bright atmosphere the sky already provides the sun glow (forward scattering): tone the sprites down
	var sky = Game.sky
	var thick := 0.0
	if sky != null and sky.get("in_atmosphere") != null:
		thick = clampf(float(sky.get("in_atmosphere")) * float(sky.get("daylight")), 0.0, 1.0)
	var fk := lerpf(1.0, 0.55, thick)
	var ck := lerpf(1.0, 0.30, thick)
	if absf(fk - _flare_k) > 0.01 or absf(ck - _corona_k) > 0.01:
		_flare_k = fk
		_corona_k = ck
		_mat_flare.set_shader_parameter("strength", fk)
		_mat_cor.set_shader_parameter("intensity", ck)
