extends SceneTree
## Prints every distinct material of the given models as Godot imported them (emission, transparency, colours) + node transforms of the pivot nodes.
##   powershell -File tools/godot.ps1 -Mode run -Script res://tools/qa_mats.gd -GodotArgs "-- models=a.glb,b.glb"

func _initialize() -> void:
	var models: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("models="):
			models = a.substr(7).split(",", false)
	for m in models:
		var ps := load("res://assets/models/" + m) as PackedScene
		if ps == null:
			print("LOAD FAILED ", m)
			continue
		var root := ps.instantiate()
		print("=== ", m)
		var seen := {}
		var stack: Array = [root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MeshInstance3D:
				var mi := n as MeshInstance3D
				if mi.mesh:
					for si in mi.mesh.get_surface_count():
						var mat := mi.get_active_material(si) as BaseMaterial3D
						if mat == null:
							print("  NO MATERIAL on ", n.name, " surface ", si)
							continue
						var key := mat.resource_name
						if seen.has(key):
							continue
						seen[key] = true
						var c := mat.albedo_color
						print("  %-34s albedo=(%.2f,%.2f,%.2f,%.2f) met=%.2f rough=%.2f emis=%s e=%.2f (%.2f,%.2f,%.2f) transp=%d cull=%d  first on %s s%d" % [
							key, c.r, c.g, c.b, c.a, mat.metallic, mat.roughness, str(mat.emission_enabled), mat.emission_energy_multiplier,
							mat.emission.r, mat.emission.g, mat.emission.b, mat.transparency, mat.cull_mode, n.name, si])
			if n is Node3D and n != root:
				var n3 := n as Node3D
				if String(n.name).begins_with("Anchor_") or n.name in ["Rotor", "Lid", "Hatch", "Dish_Az", "Dish_El", "Ring_Outer", "Ring_Inner", "Pod"] or String(n.name).begins_with("Panel_"):
					print("  node %-14s pos=(%.2f,%.2f,%.2f) rot_deg=(%.1f,%.1f,%.1f) parent=%s" % [n.name, n3.position.x, n3.position.y, n3.position.z,
						n3.rotation_degrees.x, n3.rotation_degrees.y, n3.rotation_degrees.z, n.get_parent().name])
			for k in n.get_children():
				stack.append(k)
		root.free()
	quit()
