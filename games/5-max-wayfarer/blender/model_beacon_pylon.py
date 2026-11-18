"""beacon_pylon - slim tapered pylon ~7 m tall with a glowing crystal + ring on top (Glow_Beacon, tintable) and a base plate with
Emissive_Light accents.  Origin = base centre at ground level; foundation extends 0.8 m below.  Re-runnable."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
mat('Concrete', '#8B8E91', metal=0.0, rough=0.92)
mat('Glow_Beacon', '#EAF6FF', rough=0.25, emit='#FFFFFF', emit_strength=4.0)
COLL_NAME = "beacon_pylon"
coll = fresh_collection(COLL_NAME)


def build():
    mb = MB("beacon_pylon")
    # foundation + octagonal base plate
    mb.cyl(1.25, 0.85, center=(0, 0, -0.38), segs=16, mat='Concrete')
    mb.cyl(1.38, 0.34, center=(0, 0, 0.17), segs=8, mat='Hull_Dark', bevel=0.05, bsegs=1, rot=(0, 0, rad(22.5)))
    mb.cyl(1.05, 0.05, center=(0, 0, 0.36), segs=8, mat='Metal', rot=(0, 0, rad(22.5)))
    # light accents on the plate: 8 radial bars + inner ring
    for k in range(8):
        a = TAU * k / 8
        c = Vector((math.cos(a), math.sin(a), 0.0)) * 1.12
        mb.rbox((0.42, 0.10, 0.05), center=c + Vector((0, 0, 0.36)), rot=Matrix.Rotation(a, 3, 'Z'), bevel=0.012, bsegs=1, mat='Emissive_Light')
    mb.torus(0.80, 0.025, center=(0, 0, 0.385), segs=24, tsegs=4, mat='Emissive_Light')
    # base collar and tapered 8-sided column with orange collars
    prof = [(0.0, 0.34, 'Hull_Dark'), (0.62, 0.34, 'Hull_Dark'), (0.58, 0.80, 'Hull_Accent'), (0.44, 0.86, 'Hull_Paint'),
            (0.37, 1.80, 'Hull_Paint'), (0.30, 3.40, 'Hull_Paint'), (0.22, 4.90, 'Hull_Paint'), (0.19, 5.30, 'Hull_Paint')]
    mb.lathe_mats(prof, 8, MB.xf((0, 0, 0), Matrix.Rotation(rad(22.5), 3, 'Z')), cap_a=False, cap_b=True)
    for z, r in ((2.4, 0.335), (4.0, 0.262)):
        mb.cyl(r + 0.035, 0.12, center=(0, 0, z), segs=8, mat='Hull_Accent', rot=(0, 0, rad(22.5)))
    for z, r in ((1.35, 0.395), (4.45, 0.24)):
        mb.cyl(r + 0.02, 0.07, center=(0, 0, z), segs=8, mat='Emissive_Light', rot=(0, 0, rad(22.5)))
    # top head + prongs
    mb.cyl(0.26, 0.16, center=(0, 0, 5.34), segs=8, mat='Hull_Dark', bevel=0.02, bsegs=1, rot=(0, 0, rad(22.5)))
    for k in range(3):
        a = TAU * k / 3 + 0.4
        d = Vector((math.cos(a), math.sin(a), 0))
        path = [d * 0.18 + Vector((0, 0, 5.4)), d * 0.34 + Vector((0, 0, 5.75)), d * 0.50 + Vector((0, 0, 6.2)),
                d * 0.48 + Vector((0, 0, 6.65)), d * 0.34 + Vector((0, 0, 6.95))]
        mb.tube(path, 0.035, segs=6, mat='Metal')
        mb.sphere(0.055, center=path[-1], segs=8, mat='Hull_Accent')
    # glowing crystal and ring
    cprof = [(0.0, 5.68, 'Glow_Beacon'), (0.16, 5.95, 'Glow_Beacon'), (0.29, 6.35, 'Glow_Beacon'), (0.22, 6.78, 'Glow_Beacon'),
             (0.0, 7.12, 'Glow_Beacon')]
    mb.lathe_mats(cprof, 6, MB.xf((0, 0, 0)), cap_a=False, cap_b=False, smooth=False)
    mb.torus(0.47, 0.04, center=(0, 0, 6.3), segs=28, tsegs=6, mat='Glow_Beacon')
    ob = mb.finish("beacon_pylon", coll, smooth_angle=40, weighted=True)
    return ob


ob = build()
bpy.context.view_layer.update()
check(COLL_NAME)
park(COLL_NAME)
