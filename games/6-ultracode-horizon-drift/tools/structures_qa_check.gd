extends SceneTree
## Numeric QA for the `structures` model group (independent reviewer).
##   powershell -File tools/godot.ps1 -Mode run -Script res://tools/structures_qa_check.gd -GodotArgs "-- models=a,b,c"   (ids without .glb; default: all in manifest_structures.json)
## Prints per model: triangles whose winding disagrees with the vertex normals (inside-out suspects), emissive materials (+strength),
## materials with NaN/odd values, and pivot sanity tests (lid / rotor / rings / dish / hatch / panels).

var _ids: PackedStringArray = []
var _verbose := false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("models="):
			_ids = a.substr(7).split(",", false)
		elif a == "verbose=1":
			_verbose = true
	if _ids.is_empty():
		var f := FileAccess.open("res://assets/models/manifest_structures.json", FileAccess.READ)
		var j = JSON.parse_string(f.get_as_text())
		for m in j["models"]:
			_ids.append(m["id"])
	for id in _ids:
		_check(id)
	quit()

func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_meshes(c, out)

func _xf_rel(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t

func _subtree_aabb(n: Node3D, root: Node3D) -> AABB:
	var arr: Array = []
	_meshes(n, arr)
	var first := true
	var out := AABB()
	for mi in arr:
		var m := mi as MeshInstance3D
		var xf: Transform3D = _xf_rel(m, root)
		var a := xf * m.get_aabb()
		if first:
			out = a; first = false
		else:
			out = out.merge(a)
	return out

func _check(id: String) -> void:
	var ps := load("res://assets/models/%s.glb" % id) as PackedScene
	if ps == null:
		print("!! LOAD FAILED ", id)
		return
	var root := ps.instantiate() as Node3D
	get_root().add_child(root)
	print("===== ", id)
	var meshes: Array = []
	_meshes(root, meshes)
	var total_tris := 0
	var bad_tris := 0
	var seen_mats := {}
	for mi in meshes:
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for si in m.mesh.get_surface_count():
			var arr := m.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns = arr[Mesh.ARRAY_NORMAL]
			var idx = arr[Mesh.ARRAY_INDEX]
			var tcount: int = (idx.size() / 3) if idx != null else (vs.size() / 3)
			var agree := 0
			var disagree := 0
			for t in tcount:
				var i0: int = idx[t * 3] if idx != null else t * 3
				var i1: int = idx[t * 3 + 1] if idx != null else t * 3 + 1
				var i2: int = idx[t * 3 + 2] if idx != null else t * 3 + 2
				var gn := (vs[i2] - vs[i0]).cross(vs[i1] - vs[i0])   # Godot front faces are clockwise
				if gn.length_squared() < 1e-12:
					continue
				var vn: Vector3 = ns[i0] + ns[i1] + ns[i2] if ns != null else Vector3.ZERO
				if vn.length_squared() < 1e-9:
					continue
				if gn.normalized().dot(vn.normalized()) < -0.2:
					disagree += 1
					if _verbose and disagree <= 6:
						var cen := (vs[i0] + vs[i1] + vs[i2]) / 3.0
						print("    bad tri at (%.2f,%.2f,%.2f) area=%.4f gn=%s vn=%s" % [cen.x, cen.y, cen.z, gn.length() * 0.5, str(gn.normalized()), str(vn.normalized())])
				else:
					agree += 1
			total_tris += tcount
			bad_tris += disagree
			var mat := m.get_active_material(si)
			var mname := mat.resource_name if mat else "<none>"
			if disagree > 0:
				print("  winding/normal mismatch: %s surf %d (%s): %d of %d" % [m.name, si, mname, disagree, agree + disagree])
			if mat is StandardMaterial3D and not seen_mats.has(mname):
				seen_mats[mname] = true
				var sm := mat as StandardMaterial3D
				var line := "  mat %-34s alb=%s metal=%.2f rough=%.2f cull=%d" % [mname, sm.albedo_color.to_html(true), sm.metallic, sm.roughness, sm.cull_mode]
				if sm.emission_enabled:
					line += "  EMISSIVE %s x%.2f" % [sm.emission.to_html(false), sm.emission_energy_multiplier]
				if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					line += "  transp=%d" % sm.transparency
				print(line)
	print("  tris=%d  mismatched=%d  materials=%d" % [total_tris, bad_tris, seen_mats.size()])
	_pivots(id, root)
	root.queue_free()

func _find(root: Node, n: String) -> Node3D:
	return root.find_child(n, true, false) as Node3D

func _pivots(id: String, root: Node3D) -> void:
	match id:
		"wind_turbine_a":
			var r := _find(root, "Rotor")
			if r == null: print("  !! no Rotor"); return
			print("  Rotor local rot(deg)=", r.rotation_degrees, " pos=", r.position)
			var ext := []
			for ang in [0.0, 30.0, 60.0, 90.0, 120.0]:
				r.rotation = r.get_meta("r0") if r.has_meta("r0") else r.rotation
				if not r.has_meta("r0"):
					r.set_meta("r0", r.rotation)
				r.rotate_object_local(Vector3.UP, deg_to_rad(ang))
				var a := _subtree_aabb(r, root)
				ext.append("ang%d: size=(%.2f,%.2f,%.2f) ctr=(%.2f,%.2f,%.2f)" % [ang, a.size.x, a.size.y, a.size.z, a.get_center().x, a.get_center().y, a.get_center().z])
			for e in ext: print("   ", e)
			print("   (shaft axis Z extent must stay constant, centre must not drift)")
		"beacon_monolith_a":
			for nm in ["Ring_Outer", "Ring_Inner"]:
				var r := _find(root, nm)
				if r == null: print("  !! no ", nm); continue
				var a0 := _subtree_aabb(r, root)
				r.set_meta("r0", r.rotation)
				var s := "  %s pos=%s rot=%s " % [nm, str(r.position), str(r.rotation_degrees)]
				for ang in [0.0, 45.0, 90.0]:
					r.rotation = r.get_meta("r0")
					r.rotate_object_local(Vector3.UP, deg_to_rad(ang))
					var a := _subtree_aabb(r, root)
					s += " | %d: c=(%.2f,%.2f,%.2f) s=(%.2f,%.2f,%.2f)" % [ang, a.get_center().x, a.get_center().y, a.get_center().z, a.size.x, a.size.y, a.size.z]
				print(s)
		"supply_container_a":
			var l := _find(root, "Lid")
			if l == null: print("  !! no Lid"); return
			var s := "  Lid local rot=%s pos=%s" % [str(l.rotation_degrees), str(l.position)]
			print(s)
			var body_a := _subtree_aabb(root, root)
			for ang in [0.0, 60.0, 105.0]:
				l.rotation_degrees = Vector3(ang, 0, 0)
				var a := _subtree_aabb(l, root)
				print("   lid x=%d: y range %.2f..%.2f  z range %.2f..%.2f" % [ang, a.position.y, a.end.y, a.position.z, a.end.z])
		"comm_dish_a":
			var az := _find(root, "Dish_Az")
			var el := _find(root, "Dish_El")
			if az == null or el == null: print("  !! missing Dish_Az/Dish_El"); return
			print("  Dish_Az rot=", az.rotation_degrees, " pos=", az.position, "; Dish_El rot=", el.rotation_degrees, " pos=", el.position)
			var base := _subtree_aabb(az, root)
			var c0 := base.get_center()
			for ang in [0.0, 90.0, 180.0]:
				az.rotation_degrees = Vector3(0, ang, 0)
				var a := _subtree_aabb(az, root)
				print("   Az=%d: dish centre (%.2f,%.2f,%.2f) size (%.2f,%.2f,%.2f)" % [ang, a.get_center().x, a.get_center().y, a.get_center().z, a.size.x, a.size.y, a.size.z])
			az.rotation_degrees = Vector3.ZERO
			for e in [0.0, 40.0, 80.0]:
				el.rotation_degrees = Vector3(e, 0, 0)
				var a := _subtree_aabb(el, root)
				print("   El=%d: dish aabb y %.2f..%.2f z %.2f..%.2f" % [e, a.position.y, a.end.y, a.position.z, a.end.z])
		"drop_pod_a":
			var h := _find(root, "Hatch")
			if h == null: print("  !! no Hatch"); return
			print("  Hatch rot=", h.rotation_degrees, " pos=", h.position)
			for ang in [-105.0, 0.0]:
				h.rotation_degrees = Vector3(0, ang, 0)
				var a := _subtree_aabb(h, root)
				print("   hatch y=%d: aabb min=(%.2f,%.2f,%.2f) max=(%.2f,%.2f,%.2f)" % [ang, a.position.x, a.position.y, a.position.z, a.end.x, a.end.y, a.end.z])
		"solar_array_a":
			for i in 6:
				var p := _find(root, "Panel_%d" % i)
				if p == null: print("  !! no Panel_", i); continue
				print("  Panel_%d rot=%s pos=%s" % [i, str(p.rotation_degrees), str(p.position)])
			var p0 := _find(root, "Panel_0")
			if p0:
				for ang in [-30.0, 0.0, -60.0]:
					p0.rotation_degrees = Vector3(ang, 0, 0)
					var a := _subtree_aabb(p0, root)
					print("   Panel_0 x=%d: y %.2f..%.2f z %.2f..%.2f" % [ang, a.position.y, a.end.y, a.position.z, a.end.z])
	# anchors present
	var names: PackedStringArray = []
	for n in root.find_children("Anchor_*", "Node3D", true, false):
		var o := _xf_rel(n as Node3D, root).origin
		names.append("%s@(%.2f,%.2f,%.2f)" % [n.name, o.x, o.y, o.z])
	print("  anchors: ", ", ".join(names))
