"""Verify + export ship_explorer (run after model_ship_explorer.py)."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\export_lib.py', encoding='utf-8').read(), 'e', 'exec'))

NAME = "ship_explorer"
unpark(NAME)
try:
    c = bpy.data.collections[NAME]
    required = ['Hull', 'Cockpit_Glass', 'Cockpit_Interior', 'Engine_L', 'Engine_R', 'Engine_Glow_L', 'Engine_Glow_R',
                'Gear_Front', 'Gear_RearL', 'Gear_RearR', 'Light_Nav_L', 'Light_Nav_R', 'Light_Beacon',
                'Marker_Eye', 'Marker_EngineL', 'Marker_EngineR', 'Marker_Exit', 'Marker_FootFront', 'Marker_FootRearL',
                'Marker_FootRearR', 'Marker_Headlight_L', 'Marker_Headlight_R', 'Marker_Hatch']
    names = [o.name for o in c.all_objects]
    missing = [n for n in required if n not in names]
    print("missing:", missing, "extra:", [n for n in names if n not in required])
    tops = [o.name for o in c.all_objects if o.parent is None]
    print("top-level:", tops)
    assert tops == ['Hull'], tops
    # every object descends from Hull
    hull = bpy.data.objects['Hull']
    for o in c.all_objects:
        p = o
        while p.parent is not None:
            p = p.parent
        assert p is hull, o.name
    # signed volume of each mesh must be positive (outward normals)
    for o in c.all_objects:
        if o.type != 'MESH':
            continue
        dg = bpy.context.evaluated_depsgraph_get()
        me = o.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        vol = 0.0
        mw = o.matrix_world
        for t in me.loop_triangles:
            a, b, cc = (mw @ me.vertices[i].co for i in t.vertices)
            vol += a.dot(b.cross(cc)) / 6.0
        o.evaluated_get(dg).to_mesh_clear()
        print("%-18s signed volume %.3f" % (o.name, vol))
    # pivots / transforms
    for o in c.all_objects:
        r, s = o.rotation_euler, o.scale
        assert max(abs(r.x), abs(r.y), abs(r.z)) < 1e-6 and max(abs(s.x - 1), abs(s.y - 1), abs(s.z - 1)) < 1e-6, o.name
    for n in ('Gear_Front', 'Gear_RearL', 'Gear_RearR'):
        print(n, "hinge origin", tuple(round(v, 3) for v in bpy.data.objects[n].matrix_world.translation))
    for n in ('Marker_FootFront', 'Marker_FootRearL', 'Marker_FootRearR'):
        print(n, tuple(round(v, 3) for v in bpy.data.objects[n].matrix_world.translation))

    notes = ("Nose points to -Z in Godot. Hull = root mesh, every other node is its descendant. "
             "GEAR: Gear_Front, Gear_RearL, Gear_RearR have their origin exactly on the hinge, rotation 0, legs hang straight down (extended). "
             "To RETRACT rotate each of the three nodes about its local X axis by -90 degrees (Godot rotation.x = -PI/2; feet swing to +Z = tail and up); "
             "the legs then disappear completely inside the hull / engine pods. Marker_FootFront/RearL/RearR = bottom centre of the foot pads "
             "(ground contact, all at y=-3.0 in model space). Hull origin = centre of the ship; belly is 1.6 m above the ground with the gear extended. "
             "Cockpit_Interior is its own node (hide it for first person if desired); Cockpit_Glass uses the Glass material (alpha 0.25, double sided). "
             "Marker_Eye = pilot eye (inside canopy, 0.65 m above the seat). Engine_L/Engine_R = engine pods, each with child Engine_Glow_L/R "
             "(material Emissive_Engine, origin = centre of the nozzle exit plane; scale/hide it to modulate thrust). Marker_EngineL/R = nozzle exit centre "
             "(exhaust flows towards +Z). Marker_Exit = point on the ground plane 3 m to the left of the side hatch (Marker_Hatch, left side, -X). "
             "Marker_Headlight_L/R at the nose. Light_Nav_L (red, left/-X), Light_Nav_R (green, right/+X), Light_Beacon (amber, on the fin). "
             "Materials: Hull_Paint, Hull_Accent, Hull_Dark, Metal, Rubber, Glass, Emissive_Engine, Emissive_Light, Emissive_Amber, Emissive_Screen, "
             "Emissive_ScreenAmber, Emissive_NavRed, Emissive_NavGreen, Emissive_Window, Emissive_Beacon. Wingspan 12.9 m, length 14.0 m.")
    entry = export_model(NAME, category="ship",
                         collision={"shape": "box", "size": [3.9, 3.4, 14.0], "offset": [0, 0.3, 0]}, notes=notes)
    bpy.ops.wm.save_mainfile()
    print("saved", bpy.data.filepath)

finally:
    park(NAME)
