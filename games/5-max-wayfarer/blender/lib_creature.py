"""Creature helpers (brief 3).  exec'd by model_creatures.py after lib.py.
  loft_frames / loft_y / loft_z   superellipse lofts along a path (bodies, legs, heads)
  tube_path                       catmull spline tube with per-point radii
  creature_mats()                 fixed colour materials (Fur_*, Skin_*, Shell_*, Horn ...)
  put(mb, name, coll, pivot)      finish an MB into an object with its ORIGIN ON THE JOINT (mesh stays where it was built)
"""


def loft_frames(mb, P, A, B, U, W, n=12, p=2.0, mat='Fur_Tan', cap_a=True, cap_b=True, rot=0.0):
    rings = []
    for i, pt in enumerate(P):
        ring = []
        for k in range(n):
            t = TAU * k / n + rot
            ring.append(Vector(pt) + Vector(U[i]) * (A[i] * spow(math.cos(t), 2.0 / p)) + Vector(W[i]) * (B[i] * spow(math.sin(t), 2.0 / p)))
        rings.append(ring)
    return mb.loft(rings, mat=mat, cap_a=cap_a, cap_b=cap_b)


def loft_y(mb, st, n=14, p=2.0, mat='Fur_Tan', **kw):
    """stations (y, cz, rx, rz[, cx]) along +Y; ring in the XZ plane"""
    P = [(s[4] if len(s) > 4 else 0.0, s[0], s[1]) for s in st]
    return loft_frames(mb, P, [s[2] for s in st], [s[3] for s in st], [(1, 0, 0)] * len(st), [(0, 0, 1)] * len(st), n=n, p=p, mat=mat, **kw)


def loft_z(mb, st, n=12, p=2.0, mat='Fur_Tan', **kw):
    """stations (z, cx, cy, rx, ry) along Z (given top to bottom or bottom to top); ring in the XY plane"""
    P = [(s[1], s[2], s[0]) for s in st]
    return loft_frames(mb, P, [s[3] for s in st], [s[4] for s in st], [(1, 0, 0)] * len(st), [(0, 1, 0)] * len(st), n=n, p=p, mat=mat, **kw)


def tube_path(mb, pts, radii, segs=6, mat='Fur_Tan', cap_a=True, cap_b=True, per=5, closed=False):
    """catmull spline through pts (per samples per segment) with radii interpolated along it"""
    path = catmull(pts, per)
    n = len(path)
    rr = [lerp_list(radii, i / (n - 1)) for i in range(n)]
    return mb.tube(path, rr, segs=segs, mat=mat, cap_a=cap_a, cap_b=cap_b)


def lerp_list(vals, u):
    if len(vals) == 1:
        return vals[0]
    x = u * (len(vals) - 1)
    i = min(int(x), len(vals) - 2)
    return lerp(vals[i], vals[i + 1], x - i)


def cone(mb, base, tip, r, mat, segs=6, r2=0.004):
    base, tip = Vector(base), Vector(tip)
    d = tip - base
    return mb.cyl(r, d.length, center=(base + tip) / 2, segs=segs, mat=mat, rot=MB.aim(d), r2=r2, caps=True)


def ball(mb, c, r, mat, segs=8, rings=4, scale=(1, 1, 1), rot=None):
    return mb.sphere(r, center=c, segs=segs, rings=rings, mat=mat, scale=scale, rot=rot)


def put(mb, name, coll, pivot=None, smooth_angle=60, weighted=False):
    ob = mb.finish(name, coll, smooth_angle=smooth_angle, weighted=weighted)
    if pivot is not None:
        set_origin(ob, Vector(pivot))
    return ob


def creature_mats():
    M = {}
    M['Fur_Tan'] = mat('Fur_Tan', '#C4915A', rough=0.92)
    M['Fur_Cream'] = mat('Fur_Cream', '#EFE2C4', rough=0.92)
    M['Fur_Teal'] = mat('Fur_Teal', '#1FA7A0', rough=0.9)
    M['Fur_Orange'] = mat('Fur_Orange', '#E8741F', rough=0.9)
    M['Horn'] = mat('Horn', '#E9DFC6', rough=0.5)
    M['Hoof'] = mat('Hoof', '#3A2E29', rough=0.6)
    M['Skin_Nose'] = mat('Skin_Nose', '#4B3030', rough=0.5)
    M['Eye_Dark'] = mat('Eye_Dark', '#161313', rough=0.2)
    M['Eye_White'] = mat('Eye_White', '#F4F2EC', rough=0.3)
    # flyer
    M['Skin_Wing'] = mat('Skin_Wing', '#2E56B8', rough=0.6, cull=False)
    M['Skin_WingUnder'] = mat('Skin_WingUnder', '#F6CFA4', rough=0.7, cull=False)
    M['Skin_Back'] = mat('Skin_Back', '#3A86C4', rough=0.7)
    M['Skin_Belly'] = mat('Skin_Belly', '#F3E6CB', rough=0.75)
    M['Skin_Crest'] = mat('Skin_Crest', '#F0781F', rough=0.65, cull=False)
    M['Skin_Beak'] = mat('Skin_Beak', '#F2B544', rough=0.5)
    # floater
    M['Skin_Bell'] = mat('Skin_Bell', '#C9BEFF', rough=0.15, alpha=0.58, blended=True, cull=False)
    M['Skin_Arm'] = mat('Skin_Arm', '#FF86B8', rough=0.5, cull=False)
    M['Skin_Tentacle'] = mat('Skin_Tentacle', '#B77CF0', rough=0.45)
    # crawler
    M['Shell_Main'] = mat('Shell_Main', '#B8432C', metal=0.15, rough=0.4)
    M['Shell_Dark'] = mat('Shell_Dark', '#3B2425', metal=0.1, rough=0.5)
    M['Shell_Light'] = mat('Shell_Light', '#EBA95B', metal=0.1, rough=0.45)
    M['Skin_Under'] = mat('Skin_Under', '#5D4A44', rough=0.8)
    if 'Glow_Main' not in bpy.data.materials:
        nature_palette()
    return M


def set_glow(color_hex, strength=3.0, base=None):
    """give the shared Glow_Main material the default colour baked into a creature GLB (the game may tint it later)"""
    mat('Glow_Main', color=base or '#2B2D30', rough=0.4, emit=color_hex, emit_strength=strength)
