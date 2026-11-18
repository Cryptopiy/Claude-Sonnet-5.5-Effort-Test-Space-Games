extends RefCounted
## dumps the ship's material parameters
func run(game: Node) -> void:
	await game.get_tree().create_timer(1.0).timeout
	var ship: Ship = game.ship
	var seen := {}
	_walk(ship.model, seen)
func _walk(n: Node, seen: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var m := mi.mesh
		if m != null:
			for s in m.get_surface_count():
				var mat := mi.get_active_material(s)
				var key := str(mat.get_instance_id()) if mat != null else "null"
				if seen.has(key):
					continue
				seen[key] = true
				if mat is StandardMaterial3D:
					var sm := mat as StandardMaterial3D
					print("[mat] ", n.name, " s", s, " ", sm.resource_name, " albedo=", sm.albedo_color, " metal=", sm.metallic, " rough=", sm.roughness, " spec=", sm.metallic_specular, " emis=", sm.emission_enabled, " ", sm.emission, " x", sm.emission_energy_multiplier, " transp=", sm.transparency, " blend=", sm.blend_mode, " shading=", sm.shading_mode, " cull=", sm.cull_mode, " layers=", mi.layers)
				else:
					print("[mat] ", n.name, " s", s, " ", mat)
	for c in n.get_children():
		_walk(c, seen)
