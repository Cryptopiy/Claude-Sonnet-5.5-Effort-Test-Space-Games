extends SceneTree
# Usage: godot --headless --path <proj> --script res://tools/inspect_glb.gd -- res://assets/models/foo.glb
# Prints the node tree (names, types, transforms), meshes' AABBs, and materials of a GLB.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- res://assets/models/x.glb")
		quit()
		return
	for a in args:
		var ps: PackedScene = load(a)
		if ps == null:
			print("FAILED to load ", a)
			continue
		var root: Node = ps.instantiate()
		print("=== ", a, " root=", root.name, " (", root.get_class(), ")")
		_dump(root, 0)
		root.free()
	quit()

func _dump(n: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var line := "%s%s [%s]" % [pad, n.name, n.get_class()]
	if n is Node3D:
		var t := (n as Node3D).transform
		line += " pos=(%.2f, %.2f, %.2f)" % [t.origin.x, t.origin.y, t.origin.z]
		if not t.basis.is_equal_approx(Basis.IDENTITY):
			line += " rotdeg=(%.0f, %.0f, %.0f)" % [rad_to_deg(t.basis.get_euler().x), rad_to_deg(t.basis.get_euler().y), rad_to_deg(t.basis.get_euler().z)]
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			var ab := mi.mesh.get_aabb()
			line += " aabb_size=(%.2f, %.2f, %.2f) surfaces=%d" % [ab.size.x, ab.size.y, ab.size.z, mi.mesh.get_surface_count()]
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				if m is BaseMaterial3D:
					var bm := m as BaseMaterial3D
					line += "\n%s    mat[%d] %s albedo=%s metal=%.2f rough=%.2f emis=%s(%.1f) transp=%d" % [pad, i, m.resource_name, str(bm.albedo_color), bm.metallic, bm.roughness, str(bm.emission_enabled), bm.emission_energy_multiplier, bm.transparency]
	print(line)
	for c in n.get_children():
		_dump(c, depth + 1)
