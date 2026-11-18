"""crate_supply - small (~1.2 m) supply crate / drop pod: rounded corners, lid, latches, Emissive_Light indicator.
Origin = bottom centre (on the ground).  Re-runnable."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
COLL_NAME = "crate_supply"
coll = fresh_collection(COLL_NAME)


def build():
    mb = MB("crate_supply")
    # feet + body + lid
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.cyl(0.11, 0.10, center=(sx * 0.46, sy * 0.46, 0.05), segs=10, mat='Rubber', bevel=0.02, bsegs=1)
    mb.rbox((1.20, 1.20, 0.92), center=(0, 0, 0.56), bevel=0.13, bsegs=3, mat='Hull_Accent')
    mb.rbox((1.10, 1.10, 0.24), center=(0, 0, 1.13), bevel=0.09, bsegs=2, mat='Hull_Paint')
    mb.rbox((1.14, 1.14, 0.045), center=(0, 0, 1.012), bevel=0.02, bsegs=1, mat='Rubber')          # gasket at the seam
    # corner guards (vertical) and top/bottom rails
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.rbox((0.15, 0.15, 0.94), center=(sx * 0.545, sy * 0.545, 0.56), bevel=0.05, bsegs=2, mat='Hull_Dark')
    for sz in (0.14, 0.99):
        for sx in (-1, 1):
            mb.rbox((0.07, 1.0, 0.07), center=(sx * 0.605, 0, sz), bevel=0.02, bsegs=1, mat='Hull_Dark')
            mb.rbox((1.0, 0.07, 0.07), center=(0, sx * 0.605, sz), bevel=0.02, bsegs=1, mat='Hull_Dark')
    # latches on the four sides
    for ang in (0, 90, 180, 270):
        Rz = Matrix.Rotation(rad(ang), 3, 'Z')
        mb.rbox((0.20, 0.06, 0.26), center=Rz @ Vector((0, 0.615, 0.98)), rot=Rz, bevel=0.02, bsegs=1, mat='Metal')
        mb.rbox((0.12, 0.05, 0.05), center=Rz @ Vector((0, 0.65, 1.04)), rot=Rz, bevel=0.01, bsegs=1, mat='Hull_Accent')
    # carrying handles (two sides)
    for sx in (-1, 1):
        mb.tube([(sx * 0.63, -0.22, 0.62), (sx * 0.74, -0.22, 0.62), (sx * 0.74, 0.22, 0.62), (sx * 0.63, 0.22, 0.62)], 0.032, segs=6, mat='Metal')
    # indicator panel on the +Y (front) face
    mb.rbox((0.56, 0.05, 0.34), center=(0, 0.605, 0.55), bevel=0.02, bsegs=1, mat='Hull_Dark')
    mb.rbox((0.44, 0.03, 0.07), center=(0, 0.635, 0.63), bevel=0.01, bsegs=1, mat='Emissive_Light')
    mb.rbox((0.30, 0.03, 0.035), center=(-0.07, 0.635, 0.50), bevel=0.005, bsegs=1, mat='Emissive_Light')
    mb.cyl(0.035, 0.03, center=(0.17, 0.635, 0.50), segs=10, rot=(PI / 2, 0, 0), mat='Emissive_Amber')
    # stencil marks + warning stripes on the sides
    for k in range(3):
        mb.rbox((0.26 - 0.05 * k, 0.012, 0.045), center=(0.0, -0.607, 0.70 - 0.11 * k), bevel=0.0, mat='Hull_Paint')
    for sx in (-1, 1):
        for k in range(4):
            mb.rbox((0.012, 0.06, 0.22), center=(sx * 0.607, -0.30 + 0.2 * k, 0.52), rot=(0, 0, 0), bevel=0.0, mat='Hull_Dark')
    # lid top: beacon + antenna + strap rings
    mb.cyl(0.10, 0.05, center=(-0.28, -0.28, 1.27), segs=12, mat='Hull_Dark', bevel=0.01, bsegs=1)
    mb.sphere(0.065, center=(-0.28, -0.28, 1.31), segs=10, mat='Emissive_Amber')
    mb.cyl(0.012, 0.42, center=(0.30, -0.30, 1.45), segs=6, mat='Metal')
    mb.sphere(0.03, center=(0.30, -0.30, 1.66), segs=8, mat='Hull_Accent')
    for sx in (-1, 1):
        mb.torus(0.075, 0.016, center=(sx * 0.34, 0.30, 1.26), segs=12, tsegs=5, mat='Metal', rot=(PI / 2, 0, 0) if False else None)
    ob = mb.finish("crate_supply", coll, smooth_angle=40, weighted=True)
    return ob


set_material_overrides({'Emissive_Light': dict(color='#C8FFD0', emit='#3CFF6A', emit_strength=3.0, rough=0.4)})
ob = build()
bpy.context.view_layer.update()
check(COLL_NAME)
restore_materials()
park(COLL_NAME)
