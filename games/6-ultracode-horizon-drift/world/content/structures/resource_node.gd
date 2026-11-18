class_name ResourceNode
extends StaticBody3D
## A mineable resource deposit (ferrite / zyrite / sodium / voidstone). Module M7a.
## Contract with the player (M4): group "resource_node", physics layer 3, `mine(dmg) -> {destroyed, resource, amount, progress}`.
## `amount` is only non-zero in the call that destroys the node. Mined nodes are remembered in `Game.depleted_nodes` (never respawn this game).

var res_id: String = "ferrite"
var node_id: String = ""
var node_seed: int = 0
var hp: float = 3.0
var max_hp: float = 3.0
var amount: int = 5
var node_scale: float = 1.0
var model: Node3D
var light: OmniLight3D
var near_player: bool = false
var _hit_t: float = 0.0
var _time: float = 0.0
var _destroyed := false
var _base_model_pos := Vector3.ZERO
var _light_base := 1.0
var _spin := 0.0

func setup(p_res: String, p_id: String, p_seed: int, p_scale: float) -> void:
	res_id = p_res
	node_id = p_id
	node_seed = p_seed
	node_scale = p_scale

func _ready() -> void:
	add_to_group("resource_node")
	collision_layer = 4           # layer 3
	collision_mask = 0
	var info := ResourceDB.info(res_id)
	var mid: String = str(info.get("model", "res_ore_ferrite"))
	hp = float(info.get("hp", 3.0))
	max_hp = hp
	var y: Array = info.get("yield", [4, 8])
	amount = SeedUtil.rand_int(node_seed, 11, int(y[0]), int(y[1]))
	model = ModelLib.instantiate(mid)
	model.scale = Vector3.ONE * node_scale
	add_child(model)
	_base_model_pos = model.position
	ScatterModels.add_shapes(self, mid, node_scale)
	# glow light (only switched on when the player is close: see set_near)
	var col: Color = info.get("color", Color.WHITE)
	light = OmniLight3D.new()
	light.light_color = col
	light_energy_init()
	light.omni_range = 7.0 * node_scale + 2.0
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.position = Vector3(0, 0.8 * node_scale, 0)
	light.visible = false
	add_child(light)
	_spin = 0.35 if res_id == "voidstone" else 0.0
	set_process(res_id == "voidstone")

func light_energy_init() -> void:
	_light_base = 1.4 if res_id == "voidstone" else (1.1 if res_id == "zyrite" else 0.7)
	light.light_energy = _light_base

func set_near(on: bool) -> void:
	if near_player == on:
		return
	near_player = on
	if light != null:
		light.visible = on

func get_scan_label() -> String:
	return String(ResourceDB.info(res_id).get("name", res_id.capitalize()))

func _process(dt: float) -> void:
	_time += dt
	if model == null:
		return
	if _hit_t > 0.0:
		_hit_t = maxf(_hit_t - dt, 0.0)
	var jitter := Vector3.ZERO
	if _hit_t > 0.0:
		jitter = Vector3(sin(_time * 90.0), 0.0, cos(_time * 77.0)) * 0.035 * _hit_t / 0.18
	var bob := 0.0
	if res_id == "voidstone":
		bob = sin(_time * 1.4 + float(node_seed & 255)) * 0.12 * node_scale
		model.rotate_y(_spin * dt)
	model.position = _base_model_pos + jitter + Vector3(0, bob, 0)
	if light != null and light.visible:
		light.light_energy = _light_base * (1.0 + 0.25 * sin(_time * 2.3 + float(node_seed & 63)))
	if _hit_t <= 0.0 and res_id != "voidstone":
		set_process(false)

## mining beam damage. Returns {"destroyed": bool, "resource": String, "amount": int, "progress": 0..1}
func mine(dmg: float) -> Dictionary:
	if _destroyed:
		return {"destroyed": true, "resource": res_id, "amount": 0, "progress": 1.0}
	hp -= maxf(dmg, 0.0)
	_hit_t = 0.18
	set_process(true)
	var prog := clampf(1.0 - hp / max_hp, 0.0, 1.0)
	if model != null:
		var sc := lerpf(1.0, 0.62, prog)
		model.scale = Vector3.ONE * node_scale * sc
	if hp <= 0.0:
		_destroyed = true
		var g := get_node_or_null("/root/Game")
		if g != null:
			g.depleted_nodes[node_id] = true
		_spawn_burst()
		queue_free()
		return {"destroyed": true, "resource": res_id, "amount": amount, "progress": 1.0}
	return {"destroyed": false, "resource": res_id, "amount": 0, "progress": prog}

func _spawn_burst() -> void:
	var par := get_parent()
	if par == null:
		return
	var col: Color = ResourceDB.info(res_id).get("color", Color.WHITE)
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	sm.material = mat
	p.mesh = sm
	p.amount = 18
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3.ZERO
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	p.local_coords = true
	p.transform = Transform3D(global_transform.basis.orthonormalized(), global_transform.origin + global_transform.basis.y.normalized() * 0.6)
	par.add_child(p)
	p.emitting = true
	var tree := par.get_tree()
	if tree != null:
		tree.create_timer(1.6).timeout.connect(p.queue_free)
