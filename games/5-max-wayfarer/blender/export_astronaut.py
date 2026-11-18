"""Verify + export astronaut (run after model_astronaut.py)."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\export_lib.py', encoding='utf-8').read(), 'e', 'exec'))

NAME = "astronaut"
unpark(NAME)
c = bpy.data.collections[NAME]
tree = {
    'Pelvis': None, 'Torso': 'Pelvis', 'Head': 'Torso', 'Visor': 'Head',
    'Arm_L_Upper': 'Torso', 'Arm_L_Lower': 'Arm_L_Upper', 'Hand_L': 'Arm_L_Lower',
    'Arm_R_Upper': 'Torso', 'Arm_R_Lower': 'Arm_R_Upper', 'Hand_R': 'Arm_R_Lower',
    'Backpack': 'Torso', 'Marker_JetL': 'Backpack', 'Marker_JetR': 'Backpack', 'Chest_Light': 'Torso', 'Marker_Eye': 'Torso',
    'Leg_L_Upper': 'Pelvis', 'Leg_L_Lower': 'Leg_L_Upper', 'Foot_L': 'Leg_L_Lower',
    'Leg_R_Upper': 'Pelvis', 'Leg_R_Lower': 'Leg_R_Upper', 'Foot_R': 'Leg_R_Lower', 'Marker_Tool': 'Hand_R'}
try:
    names = {o.name: o for o in c.all_objects}
    assert set(names) == set(tree), (set(names) ^ set(tree))
    for n, p in tree.items():
        o = names[n]
        assert (o.parent.name if o.parent else None) == p, (n, o.parent)
        r, s = o.rotation_euler, o.scale
        assert max(abs(r.x), abs(r.y), abs(r.z)) < 1e-6 and max(abs(s.x - 1), abs(s.y - 1), abs(s.z - 1)) < 1e-6, n
    for n in ('Pelvis', 'Torso', 'Head', 'Arm_L_Upper', 'Arm_L_Lower', 'Hand_L', 'Arm_R_Upper', 'Arm_R_Lower', 'Hand_R',
              'Leg_L_Upper', 'Leg_L_Lower', 'Foot_L', 'Leg_R_Upper', 'Leg_R_Lower', 'Foot_R', 'Backpack'):
        print("%-12s pivot (blender) %s" % (n, tuple(round(v, 3) for v in names[n].matrix_world.translation)))
    # bounds
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    dg = bpy.context.evaluated_depsgraph_get()
    for o in c.all_objects:
        if o.type != 'MESH':
            continue
        me = o.evaluated_get(dg).to_mesh()
        for v in me.vertices:
            w = o.matrix_world @ v.co
            for i in range(3):
                mn[i] = min(mn[i], w[i])
                mx[i] = max(mx[i], w[i])
        o.evaluated_get(dg).to_mesh_clear()
    print("bounds min", tuple(round(a, 3) for a in mn), "max", tuple(round(a, 3) for a in mx))
    assert abs(mn.z) < 0.003 and abs(mx.z - 1.8) < 0.03, (mn.z, mx.z)
    notes = ("Faces -Z in Godot (+Y in Blender). Origin = on the ground between the feet, height 1.8 m, relaxed A-pose (arms ~17 deg out, palms inward, "
             "knees straight). Every joint is its own mesh node with its ORIGIN ON THE JOINT, rotation 0 / scale 1, nested as: Pelvis(hip centre) > "
             "[Torso(waist) > [Head(neck) > Visor, Arm_L_Upper(shoulder) > Arm_L_Lower(elbow) > Hand_L(wrist), Arm_R_*, Backpack > Marker_JetL/R, "
             "Chest_Light, Marker_Eye], Leg_L_Upper(hip) > Leg_L_Lower(knee) > Foot_L(ankle), Leg_R_*]. _L = character's left = -X. Marker_Eye is a child "
             "of Torso (does not follow Head rotation). Marker_Tool = right palm. Marker_JetL/R = nozzle exit centres (flame goes along -Y Godot, i.e. down). "
             "Godot rotation conventions: rotation.x > 0 swings a limb FORWARD (towards -Z) - use it for the walk cycle on Arm_*_Upper/Leg_*_Upper/Leg_*_Lower; "
             "arms out (abduction): Arm_R_Upper rotation.z = +angle, Arm_L_Upper rotation.z = -angle. Limbs overlap with joint balls so "
             "no gaps at +-60 deg. Materials: Suit_White, Suit_Accent (orange), Suit_Dark, Metal, Visor (metal 0.9, rough 0.08, amber), "
             "Emissive_Light (chest light, helmet lamps), Emissive_Jet (jetpack core + nozzle glow).")
    entry = export_model(NAME, category="character",
                         collision={"shape": "capsule", "radius": 0.35, "height": 1.8, "offset": [0, 0.9, 0]}, notes=notes)
    bpy.ops.wm.save_mainfile()
finally:
    park(NAME)
print("saved", bpy.data.filepath)
