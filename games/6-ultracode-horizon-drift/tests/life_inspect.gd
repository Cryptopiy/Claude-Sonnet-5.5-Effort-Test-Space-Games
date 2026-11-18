extends SceneTree
## Prints the node hierarchy / pivots / mesh AABBs of models (dev tool).  godot --script res://tests/life_inspect.gd -- creature_quadruped_a ...
func _init() -> void:
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		ids.append(String(a))
	if ids.is_empty():
		ids = ["creature_quadruped_a", "creature_floater_a", "creature_flyer_a", "creature_crawler_a"]
	for id in ids:
		var ps = load("res://assets/models/%s.glb" % id)
		if ps == null:
			print("MISSING ", id)
			continue
		var root: Node3D = ps.instantiate()
		print("==== ", id, " root=", root.name, " children=", root.get_child_count())
		_dump(root, 0, Transform3D.IDENTITY)
		root.free()
	quit()

func _dump(n: Node, depth: int, parent_xf: Transform3D) -> void:
	var s := "  ".repeat(depth) + n.name + " [" + n.get_class() + "]"
	var xf := parent_xf
	if n is Node3D:
		var n3 := n as Node3D
		xf = parent_xf * n3.transform
		s += " pos=" + str(n3.position.snapped(Vector3(0.001, 0.001, 0.001))) + " rot=" + str((n3.rotation_degrees).snapped(Vector3(0.1, 0.1, 0.1))) + " scl=" + str(n3.scale.snapped(Vector3(0.01, 0.01, 0.01)))
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var bb := mi.mesh.get_aabb() if mi.mesh != null else AABB()
		s += " aabb_pos=" + str(bb.position.snapped(Vector3(0.01, 0.01, 0.01))) + " size=" + str(bb.size.snapped(Vector3(0.01, 0.01, 0.01)))
		var mats: Array = []
		for i in mi.get_surface_override_material_count():
			var m := mi.get_active_material(i)
			mats.append(m.resource_name if m != null else "-")
		s += " mats=" + str(mats)
	print(s)
	for c in n.get_children():
		_dump(c, depth + 1, xf)
