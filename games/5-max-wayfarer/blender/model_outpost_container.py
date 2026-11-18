"""outpost_container / outpost_container_b - shipping containers (a: 6 m orange, b: 9 m teal/white with stencil marks).
Origin = ground-contact centre; sleepers extend 0.8 m below.  Doors face +X (Blender) = -Z... (see notes), i.e. +X end.
Run this file to build both; set CONTAINER_ONLY = 'a' or 'b' before exec to build one.  Re-runnable."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
mat('Concrete', '#8B8E91', metal=0.0, rough=0.92)
mat('Container_Orange', '#D5581C', metal=0.35, rough=0.55)
mat('Container_OrangeWorn', '#B04516', metal=0.3, rough=0.85)
mat('Container_Teal', '#1F8A86', metal=0.35, rough=0.5)
mat('Container_TealWorn', '#176E6B', metal=0.3, rough=0.82)
mat('Container_White', '#E4E7E2', metal=0.2, rough=0.6)
mat('Container_Mark', '#F0F0EA', metal=0.0, rough=0.7)
mat('Container_Frame', '#4A4D52', metal=0.7, rough=0.6)

W_, H_, Z0 = 2.5, 2.6, 0.15            # width, height, floor level
PITCH, DEPTH = 0.26, 0.045


def hash01(a, b=0):
    x = math.sin(a * 127.1 + b * 311.7) * 43758.5453
    return x - math.floor(x)


def wall_long(mb, L, sy, mat_, z_a, z_b):
    """corrugated side wall; sy=+1/-1 chooses the side (ribs face outwards)"""
    poly = corrugated_poly(L - 0.34, PITCH, DEPTH, 0.05)
    if sy > 0:
        M = Matrix.Translation((0, W_ / 2 - 0.085, z_a))
    else:
        M = Matrix.Translation((0, -(W_ / 2 - 0.085), z_a)) @ Matrix.Rotation(PI, 4, 'Z')
    return mb.slab(poly, z_b - z_a, mat=mat_, m=M, bevel=0.0)


def wall_end(mb, sx, mat_, z_a, z_b):
    poly = corrugated_poly(W_ - 0.34, PITCH, DEPTH, 0.05)
    # local +y of the polygon must point to +/-X
    M = Matrix.Translation((sx * 0.0, 0, z_a)) @ Matrix.Rotation(sx * PI / 2, 4, 'Z')
    return M, poly


def build_container(name, L, body, worn, roof, band=None, marks=False):
    coll = fresh_collection(name)
    mb = MB(name)
    zb, zt = Z0, Z0 + H_
    # sleepers / foundation
    for x in (-L / 2 + 0.6, L / 2 - 0.6):
        mb.rbox((0.45, W_ + 0.3, 0.95), center=(x, 0, -0.8 + 0.475), bevel=0.04, bsegs=1, mat='Concrete')
    if L > 7:
        mb.rbox((0.45, W_ + 0.3, 0.95), center=(0, 0, -0.8 + 0.475), bevel=0.04, bsegs=1, mat='Concrete')
    # floor
    mb.rbox((L - 0.2, W_ - 0.2, 0.14), center=(0, 0, zb + 0.07), bevel=0.02, bsegs=1, mat='Container_Frame')
    # frame: corner posts, top & bottom rails
    px, py = L / 2 - 0.07, W_ / 2 - 0.07
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.rbox((0.14, 0.14, H_), center=(sx * px, sy * py, zb + H_ / 2), bevel=0.02, bsegs=1, mat='Container_Frame')
    for z in (zb + 0.06, zt - 0.06):
        for sy in (-1, 1):
            mb.rbox((L - 0.28, 0.12, 0.12), center=(0, sy * py, z), bevel=0.02, bsegs=1, mat='Container_Frame')
        for sx in (-1, 1):
            mb.rbox((0.12, W_ - 0.28, 0.12), center=(sx * px, 0, z), bevel=0.02, bsegs=1, mat='Container_Frame')
    # corner castings with oval holes
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z, sz in ((zb + 0.08, 1), (zt - 0.08, -1)):
                mb.rbox((0.22, 0.2, 0.16), center=(sx * (L / 2 - 0.11), sy * (W_ / 2 - 0.1), z), bevel=0.025, bsegs=1, mat='Hull_Dark')
                mb.rbox((0.10, 0.03, 0.05), center=(sx * (L / 2 - 0.11), sy * (W_ / 2 + 0.005), z), bevel=0.01, bsegs=1, mat='Container_Frame')
    # corrugated long walls (+ weathering zones by bisecting the wall)
    wall_parts = []
    for sy in (-1, 1):
        part = wall_long(mb, L, sy, body, zb + 0.14, zt - 0.12)
        wall_parts.append(part)
    # roof (corrugation across the width), extruded along Y
    roof_poly = corrugated_poly(L - 0.3, PITCH * 1.1, 0.04, 0.05)
    mb.slab(roof_poly, W_ - 0.28, mat=roof, m=Matrix.Translation((0, W_ / 2 - 0.14, zt - 0.1)) @ Matrix.Rotation(PI / 2, 4, 'X'), bevel=0.0)
    # closed end (-X): corrugated panel
    ep = corrugated_poly(W_ - 0.34, PITCH, DEPTH, 0.05)
    mb.slab(ep, H_ - 0.26, mat=body, m=Matrix.Translation((-L / 2 + 0.085, 0, zb + 0.14)) @ Matrix.Rotation(PI / 2 + PI, 4, 'Z'), bevel=0.0)
    # door end (+X)
    xd = L / 2 - 0.03
    for sy in (-1, 1):
        cy = sy * 0.585
        mb.rbox((0.05, 1.12, H_ - 0.3), center=(xd, cy, zb + H_ / 2), bevel=0.012, bsegs=1, mat=body)
        for k in range(3):
            mb.rbox((0.025, 0.06, H_ - 0.5), center=(xd + 0.02, cy - 0.34 + 0.34 * k, zb + H_ / 2), bevel=0.008, bsegs=1, mat=worn)
        for ry in (-0.40, 0.40):
            mb.cyl(0.021, H_ - 0.18, center=(xd + 0.075, cy + ry * 0.62 + (0.08 * sy), zb + H_ / 2), segs=6, mat='Metal')
            mb.rbox((0.05, 0.08, 0.20), center=(xd + 0.075, cy + ry * 0.62 + 0.08 * sy, zb + H_ / 2 + 0.2), bevel=0.01, bsegs=1, mat='Hull_Dark')
            mb.rbox((0.04, 0.16, 0.05), center=(xd + 0.09, cy + ry * 0.62 + 0.08 * sy, zb + 0.62), bevel=0.008, bsegs=1, mat='Hull_Accent')
        for hz in (zb + 0.4, zb + H_ / 2, zt - 0.4):
            mb.cyl(0.032, 0.14, center=(xd + 0.03, sy * 1.2, hz), segs=8, mat='Hull_Dark')
    mb.rbox((0.03, 0.025, H_ - 0.4), center=(xd + 0.03, 0.0, zb + H_ / 2), bevel=0.0, mat='Hull_Dark')       # door gap
    # ID plate + stencil strips on both long sides
    for sy in (-1, 1):
        px_ = -L / 2 + 1.4
        mb.rbox((1.05, 0.03, 0.62), center=(px_, sy * (W_ / 2 + 0.02), zb + 1.55), bevel=0.01, bsegs=1, mat='Container_Frame')
        if marks:
            for r in range(3):
                for c in range(6):
                    w_ = 0.10 + 0.06 * hash01(r * 7 + c, 3)
                    mb.rbox((w_, 0.012, 0.07), center=(px_ - 0.4 + c * 0.16, sy * (W_ / 2 + 0.042), zb + 1.72 - r * 0.17), bevel=0.0, mat='Container_Mark')
            mb.rbox((0.5, 0.012, 0.05), center=(px_, sy * (W_ / 2 + 0.042), zb + 1.28), bevel=0.0, mat='Container_Mark')
        else:
            mb.rbox((0.7, 0.012, 0.06), center=(px_, sy * (W_ / 2 + 0.042), zb + 1.78), bevel=0.0, mat='Container_Mark')
            mb.rbox((0.7, 0.012, 0.06), center=(px_, sy * (W_ / 2 + 0.042), zb + 1.62), bevel=0.0, mat='Container_Mark')
            mb.rbox((0.30, 0.012, 0.06), center=(px_ + 0.2, sy * (W_ / 2 + 0.042), zb + 1.46), bevel=0.0, mat='Container_Mark')
    # weathering: horizontal bands on the corrugated walls (bisect, then paint by height + per-rib noise)
    zs = (zb + 0.55, zb + 1.1, zb + 1.5, zb + 2.0)
    for z in zs:
        mb.cut_plane((0, 0, z), (0, 0, 1), faces=[f for p in wall_parts for f in p.faces if f.is_valid])
    bodym = mb.mi(body)
    wornm = mb.mi(worn)
    bandm = mb.mi(band) if band else None
    for p in wall_parts:
        for f in [f for f in mb.bm.faces if f.material_index == bodym and abs(abs(f.calc_center_median().y) - W_ / 2) < 0.2]:
            c = f.calc_center_median()
            if c.z < zs[0]:
                f.material_index = wornm
            elif band and zs[1] < c.z < zs[2]:
                f.material_index = bandm
            elif hash01(math.floor(c.x / PITCH), math.floor(c.z * 2)) > 0.86 and c.z < zs[3]:
                f.material_index = wornm
    ob = mb.finish(name, coll, smooth_angle=35, weighted=True)
    return ob


ONLY = globals().get('CONTAINER_ONLY', None)
if ONLY in (None, 'a'):
    build_container("outpost_container", 6.0, 'Container_Orange', 'Container_OrangeWorn', 'Container_OrangeWorn')
    check("outpost_container")
    park("outpost_container")
if ONLY in (None, 'b'):
    build_container("outpost_container_b", 9.0, 'Container_Teal', 'Container_TealWorn', 'Container_White', band='Container_White', marks=True)
    check("outpost_container_b")
    park("outpost_container_b")
