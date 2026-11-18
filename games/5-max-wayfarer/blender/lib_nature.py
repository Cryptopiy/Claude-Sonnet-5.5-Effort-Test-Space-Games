"""WAYFARER nature helpers (run 2: flora, rocks, crystals, resource nodes).  Loaded automatically at the end of lib.py, so every
script that does `exec(lib.py)` also has these.  Needs lib.py's MB / mat / fresh_collection / park ... (they are defined before this runs).

  * nature_palette()                shared materials (the tint contract with the game, identical settings in every model)
  * nz / fbm                        seeded 3D noise
  * ico / blob_bm / rock_bm / hull_bm / hull_rock_bm / crystal_bm / snow_cap_bm      bmesh generators (return a bmesh)
  * turtle / catmull / sweep        curved paths and tubes with per-angle radius (trunks with root flares, ribbed cacti, tentacles ...)
  * strip_bm / blade_bm / frond_bm / flower_bm       flat, double sided foliage pieces (grass blades, fern fronds, petals)
  * add_bm(mb, bm, ...)             append a generated bmesh into an MB builder (position / rotation / scale / material(s))
  * apply_game_tint / contact / ... previews that mimic the game's tinting (models.gd)
"""
from mathutils import noise as mnoise

# ----------------------------------------------------------------------------------------------
# shared materials  (TINT CONTRACT - see blender/BRIEF_2_flora_rocks_resources.md and scripts/core/models.gd)
#   models.gd recolours by name prefix:  Foliage* -> planet tint x clamp(V/0.62)   (V = HSV value of the base colour, only V matters)
#                                        Rock*    -> rock tint  x clamp(V/0.5)
#                                        Bark*    -> base x wood tint x 1.8
#                                        Crystal* -> albedo = tint (alpha kept), Glow* -> albedo tint*0.35 + emission tint
#   Everything else (Snow, Obsidian, Emissive_*, Res_*, Metal ...) keeps its own colour.
# ----------------------------------------------------------------------------------------------
def nature_palette():
    P = {}
    # --- tinted by the game: neutral base colours (value matters, hue does not) ---
    P['Foliage_A'] = mat('Foliage_A', '#929E86', rough=0.80, cull=False)            # V 0.62  light desaturated green-grey
    P['Foliage_B'] = mat('Foliage_B', '#747F68', rough=0.82, cull=False)            # V 0.50  darker variant
    P['Foliage_Flower'] = mat('Foliage_Flower', '#D9D6D0', rough=0.65, cull=False)  # V 0.85  near white
    P['Crystal_Main'] = mat('Crystal_Main', '#E8ECEF', rough=0.10, alpha=0.70, blended=True, cull=True)
    P['Glow_Main'] = mat('Glow_Main', '#2B2D30', rough=0.40, emit='#FFFFFF', emit_strength=3.0)
    P['Rock_A'] = mat('Rock_A', '#7F7870', rough=0.90)                              # V 0.50  warm grey-brown
    P['Rock_B'] = mat('Rock_B', '#6B645C', rough=0.92)                              # V 0.42
    P['Bark'] = mat('Bark', '#73655A', rough=0.90)                                  # neutral brown (game multiplies by wood tint x1.8)
    P['Bark_Pale'] = mat('Bark_Pale', '#F2EEE6', rough=0.85)                        # pale stalk (same wood tint rule)
    # --- fixed colours (never tinted: names do not start with Foliage/Crystal/Glow/Rock/Stone/Bark/Wood) ---
    P['Obsidian'] = mat('Obsidian', '#17151C', metal=0.15, rough=0.10)
    P['Emissive_Lava'] = mat('Emissive_Lava', '#FF8A2A', rough=0.6, emit='#FF5A0A', emit_strength=4.0)
    P['Glow_Lava'] = mat('Glow_Lava', '#FF8A2A', rough=0.6, emit='#FF5A0A', emit_strength=4.0)      # brief name; models.gd exempts it from the Glow* tint
    P['Snow'] = mat('Snow', '#F1F4F7', rough=0.60)
    P['Res_Sodium'] = mat('Res_Sodium', '#FFC247', rough=0.28, emit='#FFA812', emit_strength=2.5)
    P['Res_Ferrite'] = mat('Res_Ferrite', '#B9622C', metal=0.9, rough=0.40, emit='#C0551A', emit_strength=0.35)    # tiny self-illumination keeps the veins readable without sky reflections
    P['Res_Carbon'] = mat('Res_Carbon', '#3B2058', rough=0.45, emit='#4B1F7A', emit_strength=0.25)
    P['Res_Carbon_Tip'] = mat('Res_Carbon_Tip', '#6CCB6A', rough=0.4, emit='#55FF55', emit_strength=1.6)
    for n in ('Metal', 'Hull_Dark', 'Emissive_Light', 'Hull_Paint', 'Rubber'):
        if n not in bpy.data.materials:
            palette()
            break
    return P


# ----------------------------------------------------------------------------------------------
# noise
# ----------------------------------------------------------------------------------------------
def _off(seed):
    return Vector(((seed * 12.9898) % 53.0 + 11.1, (seed * 78.233) % 47.0 + 7.7, (seed * 37.719) % 59.0 + 3.3))


def nz(p, seed=0.0, freq=1.0):
    """smooth 3D noise, roughly -0.8..0.8"""
    return mnoise.noise(Vector(p) * freq + _off(seed))


def fbm(p, seed=0.0, freq=1.0, octaves=3, gain=0.5, lac=2.0):
    s, a, f, tot = 0.0, 1.0, freq, 0.0
    for _ in range(octaves):
        s += a * nz(p, seed, f)
        tot += a
        a *= gain
        f *= lac
    return s / tot


def rnd_dir(rng, zmin=-1.0, zmax=1.0):
    """random unit vector with z in [zmin, zmax]"""
    z = rng.uniform(zmin, zmax)
    a = rng.uniform(0, TAU)
    s = math.sqrt(max(0.0, 1 - z * z))
    return Vector((s * math.cos(a), s * math.sin(a), z))


def hexc(r, g, b):
    """float 0..1 sRGB -> '#RRGGBB'"""
    f = lambda c: max(0, min(255, int(round(c * 255))))
    return '#%02X%02X%02X' % (f(r), f(g), f(b))


# ----------------------------------------------------------------------------------------------
# bmesh generators
# ----------------------------------------------------------------------------------------------
def ico(subdiv=3, r=1.0):
    """icosphere: subdiv 1 = 20 tris, 2 = 80, 3 = 320, 4 = 1280"""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r)
    return bm


def blob_bm(r=1.0, subdiv=3, seed=0, amp=0.2, freq=1.2, amp2=0.07, freq2=3.1, sq=(1, 1, 1), flat_bottom=None):
    """lumpy leaf blob / bulb: noise displaced icosphere. flat_bottom = fraction of r below which z is clipped (None = round)."""
    bm = ico(subdiv, 1.0)
    for v in bm.verts:
        p = v.co.copy()
        d = 1.0 + amp * fbm(p, seed, freq, 2) + amp2 * nz(p, seed + 3.3, freq2)
        q = Vector((p.x * sq[0], p.y * sq[1], p.z * sq[2])) * (d * r)
        if flat_bottom is not None:
            q.z = max(q.z, -flat_bottom * r)
        v.co = q
    return bm


def rock_bm(size=(1.0, 1.0, 1.0), seed=0, subdiv=3, amp=0.22, freq=1.1, cuts=5, cut_lo=0.55, cut_hi=0.85,
            bottom=0.35, sink=0.05, zbias=(-0.35, 1.0), amp2=0.05, fit=True):
    """noise displaced, planar-cut boulder.  size = full extents (x, y, z) (fit=True rescales the result to exactly this size, height measured
    above the sink line).  Flat bottom, lowest point at z = -sink, centred on x/y = 0."""
    rng = random.Random(seed * 7 + 1)
    bm = ico(subdiv, 1.0)
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    for v in bm.verts:
        p = v.co.copy()
        d = 1.0 + amp * fbm(p, seed, freq, 3) + amp2 * nz(p, seed + 9.1, 3.3)
        v.co = Vector((p.x * d * sx, p.y * d * sy, p.z * d * sz))
    for i in range(cuts):
        n = rnd_dir(rng, zbias[0], zbias[1])
        # planes are given in 'unit' space so the cut depth scales with the anisotropic size
        nn = Vector((n.x / sx, n.y / sy, n.z / sz)).normalized()
        sup = max(v.co.dot(nn) for v in bm.verts)
        dcut = sup * rng.uniform(cut_lo, cut_hi)
        for v in bm.verts:
            s = v.co.dot(nn)
            if s > dcut:
                v.co -= nn * (s - dcut)
    if bottom is not None:
        zc = -bottom * sz
        for v in bm.verts:
            if v.co.z < zc:
                v.co.z = zc
    zmin = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z += -zmin - sink
    if fit:
        xs = [v.co.x for v in bm.verts]
        ys = [v.co.y for v in bm.verts]
        zs = [v.co.z for v in bm.verts]
        ex, ey, ez = max(xs) - min(xs), max(ys) - min(ys), max(zs) + sink
        cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
        for v in bm.verts:
            v.co.x = (v.co.x - cx) * size[0] / ex
            v.co.y = (v.co.y - cy) * size[1] / ey
            v.co.z = (v.co.z + sink) * size[2] / ez - sink
    return bm


def hull_bm(points):
    """convex hull of a point cloud (bmesh, triangles, outward)"""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector(p)) for p in points]
    res = bmesh.ops.convex_hull(bm, input=vs, use_existing_faces=False)
    junk = list({e for e in (res.get('geom_interior', []) + res.get('geom_unused', [])) if isinstance(e, bmesh.types.BMVert)})
    if junk:
        bmesh.ops.delete(bm, geom=junk, context='VERTS')
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def block_bm(size, seed=0, n=7, taper=0.85, jit=0.18, sink=0.05, skew=(0.0, 0.0), flat_top=True):
    """chunky irregular prism / ledge block: flat bottom (z=-sink) and flat top, slightly tapering, angled irregular sides (convex hull)."""
    rng = random.Random(seed * 29 + 3)
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2]
    a0 = rng.uniform(0, TAU)
    pts = []
    for k in range(n):
        a = a0 + TAU * (k + rng.uniform(-0.25, 0.25)) / n
        rr = 1 + rng.uniform(-jit, jit)
        pts.append((sx * rr * math.cos(a), sy * rr * math.sin(a), 0.0))
        rt = taper * (1 + rng.uniform(-jit, jit) * 0.8)
        a2 = a + rng.uniform(-0.12, 0.12)
        zt = sz if flat_top else sz * (1 + rng.uniform(-0.10, 0.10))
        pts.append((sx * rt * math.cos(a2) + skew[0] * sz, sy * rt * math.sin(a2) + skew[1] * sz, zt))
    bm = hull_bm(pts)
    for v in bm.verts:
        v.co.z -= sink
    return bm


def chip_edges(bm, rng, count=4, offset=0.12, min_angle=0.45):
    """bevel `count` random sharp convex edges (chipped corners). offset in model units."""
    cand = []
    for e in bm.edges:
        if len(e.link_faces) == 2:
            try:
                a = e.calc_face_angle(0.0)
            except ValueError:
                continue
            if a > min_angle and e.is_convex:
                cand.append(e)
    rng.shuffle(cand)
    sel = cand[:count]
    if sel:
        bmesh.ops.bevel(bm, geom=sel, offset=offset, segments=1, affect='EDGES', clamp_overlap=True)
    return bm


def patch_mats(bm, seed, thresh=0.12, freq=0.9, low=None):
    """material_index 1 on noise patches (and optionally on faces whose centre z < low) - two-tone rocks"""
    for f in bm.faces:
        c = f.calc_center_median()
        v = nz(c, seed, freq)
        f.material_index = 1 if (v > thresh or (low is not None and c.z < low)) else 0
    return bm


def hull_rock_bm(size=(1.0, 1.0, 1.0), seed=0, rings=((0.0, 7, 1.0), (0.45, 7, 1.0), (0.9, 5, 0.55)), jitter=0.22, ztop_jit=0.12,
                 sink=0.04, shear=0.0):
    """angular rock = convex hull of ring layers.  rings = ((z_fraction, n_points, radius_fraction), ...).  Flat bottom at z=-sink."""
    rng = random.Random(seed * 13 + 5)
    pts = []
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2]
    for (zf, n, rf) in rings:
        a0 = rng.uniform(0, TAU)
        for k in range(n):
            a = a0 + TAU * (k + rng.uniform(-0.3, 0.3)) / n
            rr = rf * (1 + rng.uniform(-jitter, jitter))
            z = sz * (zf + (rng.uniform(-ztop_jit, ztop_jit) if zf > 0.05 else 0.0))
            x, y = sx * rr * math.cos(a), sy * rr * math.sin(a)
            x += shear * z
            pts.append((x, y, z))
    bm = hull_bm(pts)
    zmin = min(v.co.z for v in bm.verts)
    cx = sum(v.co.x for v in bm.verts) / len(bm.verts)
    cy = sum(v.co.y for v in bm.verts) / len(bm.verts)
    for v in bm.verts:
        v.co += Vector((-cx, -cy, -zmin - sink))
    return bm


def crystal_bm(h=1.0, r=0.2, sides=6, tip=0.3, seed=0, taper=0.85, skew=(0.0, 0.0), jit=0.10, base_cap=True, rot0=None,
               cut=None, stretch=1.0):
    """hexagonal-ish crystal prism with a pointed (or slant-cut) tip. base at z=0, tip at z=h.  skew = apex xy offset (in r units).
    cut = (nx, ny, dz): replace the apex by a slanted flat cap (broken shard)."""
    rng = random.Random(seed * 31 + 7)
    bm = bmesh.new()
    n = sides
    a0 = rng.uniform(0, TAU) if rot0 is None else rot0
    jr = [1 + rng.uniform(-jit, jit) for _ in range(n)]
    base = [bm.verts.new(Vector((r * jr[k] * math.cos(a0 + TAU * k / n) * stretch, r * jr[k] * math.sin(a0 + TAU * k / n), 0.0))) for k in range(n)]
    zt = h * (1 - tip)
    mid = [bm.verts.new(Vector((r * taper * jr[k] * math.cos(a0 + TAU * k / n) * stretch + skew[0] * r * 0.4,
                                r * taper * jr[k] * math.sin(a0 + TAU * k / n) + skew[1] * r * 0.4, zt + rng.uniform(-0.03, 0.03) * h))) for k in range(n)]
    faces = []
    for k in range(n):
        k2 = (k + 1) % n
        faces.append((base[k], base[k2], mid[k2], mid[k]))
    if cut is None:
        apex = bm.verts.new(Vector((skew[0] * r, skew[1] * r, h)))
        for k in range(n):
            faces.append((mid[k], mid[(k + 1) % n], apex))
    else:
        nx, ny, dz = cut
        top = []
        for k in range(n):
            x, y = mid[k].co.x * 0.8, mid[k].co.y * 0.8
            top.append(bm.verts.new(Vector((x, y, h + nx * x + ny * y + dz))))
        for k in range(n):
            k2 = (k + 1) % n
            faces.append((mid[k], mid[k2], top[k2], top[k]))
        faces.append(tuple(top))
    if base_cap:
        faces.append(tuple(reversed(base)))
    for f in faces:
        try:
            bm.faces.new(f)
        except ValueError:
            pass
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def snow_cap_bm(src, min_nz=0.45, thick=0.10, seed=0, lumpy=0.35, grow=2.5, min_lift=0.012):
    """snow layer for the up-facing faces of a (closed, outward) bmesh `src`.  Returns a NEW open bmesh (white cap), thickest in the middle,
    touching the surface along its border.  src faces' normals must be up to date (they are recalculated here)."""
    src.normal_update()
    src.verts.ensure_lookup_table()
    sel = [f for f in src.faces if f.normal.z >= min_nz]
    if not sel:
        return None
    vset = {}
    out = bmesh.new()
    nrm = {}
    for f in sel:
        for v in f.verts:
            if v not in vset:
                vset[v] = out.verts.new(v.co.copy())
    # vertex normals (area weighted over ALL adjacent faces so the cap follows the true surface)
    for v in vset:
        nsum = Vector()
        for lf in v.link_faces:
            nsum += lf.normal * lf.calc_area()
        nrm[v] = nsum.normalized() if nsum.length > 0 else Vector((0, 0, 1))
    # border distance (edges) by BFS
    border = set()
    selset = set(sel)
    for f in sel:
        for e in f.edges:
            if sum(1 for lf in e.link_faces if lf in selset) < 2:
                border.add(e.verts[0])
                border.add(e.verts[1])
    dist = {v: 0 for v in border}
    frontier = list(border)
    while frontier:
        nxt = []
        for v in frontier:
            for e in v.link_edges:
                w = e.other_vert(v)
                if w in vset and w not in dist:
                    dist[w] = dist[v] + 1
                    nxt.append(w)
        frontier = nxt
    for v, nv in vset.items():
        d = dist.get(v, 3)
        k = min(1.0, d / grow)
        k = k * k * (3 - 2 * k)
        t = thick * k * (1.0 + lumpy * nz(v.co, seed, 2.1))
        nv.co = v.co + nrm[v] * max(min_lift if d > 0 else 0.004, t)
    for f in sel:
        try:
            out.faces.new([vset[v] for v in f.verts])
        except ValueError:
            pass
    out.normal_update()
    return out


# ----------------------------------------------------------------------------------------------
# paths and tubes
# ----------------------------------------------------------------------------------------------
def catmull(pts, n=6):
    """Catmull-Rom spline through the points (list of Vectors/tuples), n samples per segment."""
    P = [Vector(p) for p in pts]
    if len(P) < 3:
        return P
    ext = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for j in range(n):
            t = j / n
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-1].copy())
    return out


def turtle(p0, d0, length, n=6, bend=0.0, toward=(0, 0, -1), wobble=0.0, seed=0, bend_curve=1.0):
    """path of n+1 points starting at p0 heading d0; the heading turns by `bend` radians in total towards `toward`
    (bend_curve > 1 concentrates the turning at the end); wobble = random sideways heading noise (radians)."""
    rng = random.Random(seed * 3 + 11)
    d = Vector(d0).normalized()
    p = Vector(p0)
    tw = Vector(toward).normalized()
    step = length / n
    pts = [p.copy()]
    for i in range(n):
        u0, u1 = i / n, (i + 1) / n
        frac = (u1 ** bend_curve) - (u0 ** bend_curve)
        axis = d.cross(tw)
        if axis.length > 1e-6:
            ang = min(bend * frac, d.angle(tw))
            d = Quaternion(axis.normalized(), ang) @ d
        if wobble:
            side = d.cross(Vector((0, 0, 1)))
            if side.length < 1e-4:
                side = Vector((1, 0, 0))
            side.normalize()
            up_ = side.cross(d).normalized()
            d = (d + side * rng.uniform(-wobble, wobble) + up_ * rng.uniform(-wobble, wobble)).normalized()
        p = p + d * step
        pts.append(p.copy())
    return pts


def sweep(mb, path, rad, segs=8, mat='Bark', cap_a=False, cap_b=True, up=(0, 0, 1), smooth=True, twist=0.0, squash=1.0, phase=0.0):
    """tube along `path`.  rad = list of radii (one per point) or f(u, theta) -> radius  (u = 0..1 along the path).
    Rotation-minimising frames; windings are outward.  Both ends should be capped unless they are fully hidden."""
    pts = [Vector(p) for p in path]
    n = len(pts)
    rings = []
    prev_x = None
    for i in range(n):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
        t = t.normalized()
        if prev_x is None:
            u_ = Vector(up).normalized()
            if abs(t.dot(u_)) > 0.95:
                u_ = Vector((1, 0, 0))
            x = u_.cross(t).normalized()
        else:
            x = prev_x - t * prev_x.dot(t)
            if x.length < 1e-6:
                x = Vector((1, 0, 0)).cross(t)
            x = x.normalized()
        y = t.cross(x)
        prev_x = x
        uu = i / (n - 1)
        ring = []
        for k in range(segs):
            th = TAU * k / segs + phase + twist * uu
            r = rad(uu, th) if callable(rad) else rad[i]
            ring.append(pts[i] + (x * math.cos(th) + y * math.sin(th) * squash) * max(r, 0.0))
        rings.append(ring)
    return mb.grid(rings, closed=True, mat=mat, smooth=smooth, cap_a=cap_a, cap_b=cap_b, outward=False)


def trunk_radius(r_base, r_top, flare=1.0, lobes=4, phase=0.0, power=0.85, decay=11.0, seed=0, gnarl=0.07, twist=0.0):
    """radius function f(u, theta) for sweep(): taper + root flare lobes near the ground + gnarly noise (+ twisted lobes)"""
    def f(u, th):
        rt = lerp(r_base, r_top, u ** power)
        lobe = max(0.0, math.cos(lobes * (th - phase - twist * u))) ** 1.5
        fl = 1.0 + flare * math.exp(-u * decay) * (0.25 + 0.75 * lobe)
        g = 1.0 + gnarl * nz(Vector((math.cos(th) * 0.9, math.sin(th) * 0.9, u * 4.0)), seed, 1.0)
        return rt * fl * g
    return f


def at_height(tp, z):
    """point on the polyline tp at height z"""
    for i in range(len(tp) - 1):
        if tp[i].z <= z <= tp[i + 1].z:
            t = (z - tp[i].z) / max(1e-6, tp[i + 1].z - tp[i].z)
            return tp[i].lerp(tp[i + 1], t)
    return tp[-1] if z > tp[-1].z else tp[0]


def ribbed(radii, ribs=8, amp=0.12, phase=0.0, twist=0.0):
    """radius function for sweep(): per-point radii list modulated by `ribs` ridges (cactus / mushroom stalk look)"""
    n = len(radii)
    def f(u, th):
        i = min(n - 1, max(0, int(round(u * (n - 1)))))
        return radii[i] * (1.0 + amp * math.cos(ribs * (th - twist * u) + phase))
    return f


def dome_radii(n_body, r_body, r_top, n_dome=4, r_end=0.0, power=1.0):
    """list of radii: taper r_body -> r_top over n_body points, then a rounded dome closing to r_end over n_dome more points"""
    out = [lerp(r_body, r_top, (i / max(1, n_body - 1)) ** power) for i in range(n_body)]
    for k in range(1, n_dome + 1):
        a = (math.pi / 2) * k / n_dome
        out.append(max(r_end, r_top * math.cos(a)))
    return out


def dome_path(path, r_top, n_dome=4):
    """extend a path by n_dome points along its end tangent that follow a hemisphere of radius r_top (pair with dome_radii)"""
    pts = [Vector(p) for p in path]
    t = (pts[-1] - pts[-2]).normalized()
    end = pts[-1]
    out = list(pts)
    for k in range(1, n_dome + 1):
        a = (math.pi / 2) * k / n_dome
        out.append(end + t * (r_top * math.sin(a)))
    return out


def taper_radii(n, r0, r1, power=1.0):
    return [lerp(r0, r1, (i / (n - 1)) ** power) for i in range(n)]


# ----------------------------------------------------------------------------------------------
# flat foliage pieces (double sided materials)
# ----------------------------------------------------------------------------------------------
def strip_bm(spine, widths, wdir, smooth=True, tip=True, bm=None):
    """flat ribbon along `spine` (list of points); full width per point; `wdir` = width direction (Vector, or list per point).
    The last point becomes a pole when tip=True (pointed end).  Faces wind so that (tangent x wdir) is the front normal."""
    bm = bm or bmesh.new()
    n = len(spine)
    L, R = [], []
    for i, p in enumerate(spine):
        w = wdir[i] if isinstance(wdir, (list, tuple)) else wdir
        w = Vector(w).normalized()
        hw = widths[i] * 0.5
        if tip and i == n - 1:
            v = bm.verts.new(Vector(p))
            L.append(v)
            R.append(v)
        else:
            L.append(bm.verts.new(Vector(p) - w * hw))
            R.append(bm.verts.new(Vector(p) + w * hw))
    fs = []
    for i in range(n - 1):
        try:
            if L[i + 1] is R[i + 1]:
                f = bm.faces.new((L[i], R[i], L[i + 1]))
            else:
                f = bm.faces.new((L[i], R[i], R[i + 1], L[i + 1]))
            f.smooth = smooth
            fs.append(f)
        except ValueError:
            pass
    return bm


def blade_bm(base, lean_dir, height, width, bend=0.9, segs=3, curl_toward=(0, 0, -1), seed=0, bm=None, twist=0.0):
    """grass blade: width axis horizontal & perpendicular to the lean direction; pointed tip; `segs` quads-1 (last is the tip triangle)."""
    ld = Vector((lean_dir[0], lean_dir[1], 0)).normalized()
    # start heading mostly up with a small lean, curling over towards lean_dir*down
    d0 = (Vector((0, 0, 1)) * 0.96 + ld * 0.25).normalized()
    pts = [Vector(base)]
    d = d0
    step = height / segs
    p = Vector(base)
    tw = (ld * 0.8 + Vector((0, 0, -0.6))).normalized()
    for i in range(segs):
        axis = d.cross(tw)
        if axis.length > 1e-6:
            d = Quaternion(axis.normalized(), min(bend / segs, d.angle(tw))) @ d
        p = p + d * step
        pts.append(p.copy())
    w = Vector((-ld.y, ld.x, 0)).normalized()
    if twist:
        w = (w * math.cos(twist) + Vector((0, 0, 1)) * math.sin(twist)).normalized()
    widths = [width * (1.0 - 0.55 * (i / segs) ** 1.2) for i in range(segs)] + [0.0]
    return strip_bm(pts, widths, w, tip=True, bm=bm)


def flower_bm(center, normal, radius=0.12, petals=8, seed=0, cup=0.35, bm=None, petal_len=1.0, core_r=0.3, wide=0.62):
    """flower head: core fan + petals (5-gons whose shoulders overlap the neighbours, tips lifted by `cup`).
    Returns (bm, core_faces, petal_faces)."""
    rng = random.Random(seed * 17 + 3)
    bm = bm or bmesh.new()
    nrm = Vector(normal).normalized()
    ref = Vector((1, 0, 0)) if abs(nrm.x) < 0.9 else Vector((0, 1, 0))
    ux = (ref - nrm * ref.dot(nrm)).normalized()
    uy = nrm.cross(ux)
    c = Vector(center)
    a0 = rng.uniform(0, TAU)
    dirf = lambda a: ux * math.cos(a) + uy * math.sin(a)
    hub = bm.verts.new(c + nrm * radius * 0.12)
    inner = []
    for k in range(petals):
        a = a0 + TAU * k / petals
        inner.append(bm.verts.new(c + dirf(a) * radius * core_r + nrm * radius * 0.05))
    core, pet = [], []
    for k in range(petals):
        try:
            core.append(bm.faces.new((hub, inner[k], inner[(k + 1) % petals])))
        except ValueError:
            pass
    step = TAU / petals
    for k in range(petals):
        v, v2 = inner[k], inner[(k + 1) % petals]
        am = a0 + step * (k + 0.5)
        ln = radius * petal_len * (1 + rng.uniform(-0.12, 0.12))
        lift = nrm * radius * cup
        tipv = bm.verts.new(c + dirf(am) * ln + lift * (0.9 + rng.uniform(0, 0.3)))
        s1 = bm.verts.new(c + dirf(am - step * wide) * ln * 0.76 + lift * 0.40)
        s2 = bm.verts.new(c + dirf(am + step * wide) * ln * 0.76 + lift * 0.40)
        try:
            pet.append(bm.faces.new((v, s1, tipv, s2, v2)))
        except ValueError:
            pass
    return bm, core, pet


def rings_bm(rings, closed=True):
    """bmesh from rings of points (degenerate rings become poles); outward normals are recalculated (use for closed shells)."""
    bm = bmesh.new()
    n = len(rings[0])
    R = []
    for ring in rings:
        p0 = Vector(ring[0])
        if all((Vector(p) - p0).length < 1e-6 for p in ring):
            v = bm.verts.new(p0)
            R.append([v] * n)
        else:
            R.append([bm.verts.new(Vector(p)) for p in ring])
    for i in range(len(rings) - 1):
        for k in range(n if closed else n - 1):
            k2 = (k + 1) % n
            vs = []
            for v in (R[i][k], R[i][k2], R[i + 1][k2], R[i + 1][k]):
                if v not in vs:
                    vs.append(v)
            if len(vs) >= 3:
                try:
                    bm.faces.new(vs)
                except ValueError:
                    pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def prof_z(prof, rr, branch):
    """height of a lathe profile [(r, z) ...] (closed outline: underside outward, rim, top inward) at radius rr; branch 'under' or 'top'"""
    imax = max(range(len(prof)), key=lambda i: prof[i][0])
    pts = prof[:imax + 1] if branch == 'under' else list(reversed(prof[imax:]))
    pts = sorted(pts, key=lambda q: q[0])
    for a, b in zip(pts[:-1], pts[1:]):
        if a[0] <= rr <= b[0]:
            t = (rr - a[0]) / max(1e-9, b[0] - a[0])
            return lerp(a[1], b[1], t)
    return pts[-1][1] if rr > pts[-1][0] else pts[0][1]


# ----------------------------------------------------------------------------------------------
# putting generated bmeshes into an MB builder
# ----------------------------------------------------------------------------------------------
def add_bm(mb, src, loc=(0, 0, 0), rot=None, scale=(1, 1, 1), mat='Rock_A', smooth=True, closed=True, flat=False):
    """append a generated bmesh (consumed).  mat = name or list of names indexed by the source faces' material_index.
    closed=True -> winding is verified by the signed volume (closed outward shells); closed=False copies the faces as they are."""
    m = MB.xf(loc, rot, scale)
    sm = False if flat else smooth
    if closed and not isinstance(mat, (list, tuple)):
        return mb.append_bm(src, m, mat, sm)
    bm = mb.bm
    mats = list(mat) if isinstance(mat, (list, tuple)) else [mat]
    mis = [mb.mi(x) for x in mats]
    vmap = {v: bm.verts.new(m @ v.co) for v in src.verts}
    part = Part()
    for f in src.faces:
        try:
            nf = bm.faces.new([vmap[v] for v in f.verts])
        except ValueError:
            continue
        nf.material_index = mis[min(f.material_index, len(mis) - 1)]
        nf.smooth = sm
        part.faces.append(nf)
    part.verts = list(vmap.values())
    if closed:
        mb.fix_outward(part.faces)
    src.free()
    return part


class Cluster:
    """Adds closed outward shells (bmeshes) to an MB builder and removes the faces that are completely buried inside shells added EARLIER
    (union look without boolean: saves triangles + overdraw; the earlier shell stays complete so no holes appear)."""

    def __init__(self, mb):
        self.mb = mb
        self.bvhs = []

    def _inside(self, p, depth):
        for b in self.bvhs:
            loc, n, idx, d = b.find_nearest(p)
            if loc is not None and (p - loc).dot(n) < -depth:
                return True
        return False

    def add(self, bm, mat, loc=(0, 0, 0), rot=None, scale=(1, 1, 1), smooth=True, cull=True, depth=0.03, keep=True):
        bm.transform(MB.xf(loc, rot, scale))
        bm.normal_update()
        bvh = BVHTree.FromBMesh(bm)
        if cull and self.bvhs:
            dead = [f for f in bm.faces if all(self._inside(v.co, depth) for v in f.verts)]
            if dead:
                bmesh.ops.delete(bm, geom=dead, context='FACES')
        if keep:
            self.bvhs.append(bvh)
        return add_bm(self.mb, bm, mat=mat, smooth=smooth, closed=False)


def paint_ao(ob, strength=0.42, ground=0.30, gscale=0.9, skip=('Glow', 'Emissive', 'Crystal', 'Res_'), name='Col', extra=None, gmin=0.0):
    """cheap baked 'ambient occlusion' as a vertex colour (linear grey, multiplied with the albedo by Godot): undersides + ground contact
    are darker.  Glow / Emissive / Crystal / Res_ materials stay white.  extra(co, normal) -> multiplier is an optional extra term."""
    me = ob.data
    ca = me.color_attributes.get(name)
    if ca is None:
        ca = me.color_attributes.new(name, 'FLOAT_COLOR', 'CORNER')
    nl = len(me.loops)
    cols = [1.0] * (4 * nl)
    sk = []
    for sl in ob.material_slots:
        nm = sl.material.name if sl.material else ''
        sk.append(any(nm.startswith(k) for k in skip))
    cn = me.corner_normals
    verts = me.vertices
    loops = me.loops
    for poly in me.polygons:
        if poly.material_index < len(sk) and sk[poly.material_index]:
            continue
        for li in poly.loop_indices:
            co = verts[loops[li].vertex_index].co
            n = cn[li].vector
            ex = 0.5 + 0.5 * clamp(n.z, -1.0, 1.0)
            ao = lerp(1.0 - strength, 1.0, ex)
            ao *= lerp(1.0 - ground, 1.0, smoothstep(gmin, gmin + gscale, co.z))
            if extra is not None:
                ao *= extra(co, n)
            cols[4 * li] = cols[4 * li + 1] = cols[4 * li + 2] = ao
    ca.data.foreach_set('color', cols)
    me.color_attributes.active_color = ca
    try:
        me.color_attributes.render_color_index = [a.name for a in me.color_attributes].index(name)
    except Exception:
        pass
    me.update()


# ----------------------------------------------------------------------------------------------
# finishing / checks
# ----------------------------------------------------------------------------------------------
def finish_model(name, mb, coll, smooth_angle=40.0, weighted=False, tag='Body'):
    ob = mb.finish(tag, coll, smooth_angle=smooth_angle, weighted=weighted)
    return ob


def nature_check(name, budget=None, closed=True):
    """print triangle count / open edges / zero faces of a model collection; returns tris"""
    c = bpy.data.collections[name]
    tot = 0
    for o in c.all_objects:
        if o.type != 'MESH':
            continue
        me = o.data
        bm = bmesh.new()
        bm.from_mesh(me)
        open_e = sum(1 for e in bm.edges if len(e.link_faces) < 2)
        multi = sum(1 for e in bm.edges if len(e.link_faces) > 2)
        zero = sum(1 for f in bm.faces if f.calc_area() < 1e-9)
        loose = sum(1 for v in bm.verts if not v.link_faces)
        bm.free()
        t = tri_count(o)
        tot += t
        mn, mx = _bounds_of([o])
        print("%s: tris=%d open_edges=%d nonmanifold=%d zero=%d loose=%d  bbox x[%.2f %.2f] y[%.2f %.2f] z[%.2f %.2f]  mats=%s" % (
            name, t, open_e, multi, zero, loose, mn.x, mx.x, mn.y, mx.y, mn.z, mx.z, [s.material.name for s in o.material_slots]))
    if budget and tot > budget:
        print("!!! %s exceeds the triangle budget: %d > %d" % (name, tot, budget))
    return tot


# ----------------------------------------------------------------------------------------------
# game-like tinting for previews (mirrors scripts/core/models.gd :: _tinted_material) - preview only, restore with nature_palette()
# ----------------------------------------------------------------------------------------------
PLANET_TINTS = {
    'lush': {"foliage": (0.34, 0.62, 0.20), "foliage2": (0.80, 0.42, 0.62), "grass": (0.40, 0.66, 0.22), "flower": (1.0, 0.8, 0.3), "rock": (0.62, 0.58, 0.52)},
    'desert': {"foliage": (0.50, 0.58, 0.22), "cactus": (0.40, 0.58, 0.28), "wood": (0.62, 0.50, 0.40), "shrub": (0.62, 0.55, 0.26), "rock": (0.92, 0.62, 0.42)},
    'volcanic': {"rock": (0.30, 0.27, 0.26), "obsidian": (0.15, 0.13, 0.17), "wood": (0.14, 0.12, 0.11), "foliage": (0.3, 0.2, 0.15)},
    'frozen': {"pine": (0.30, 0.50, 0.42), "ice": (0.62, 0.84, 1.0), "frost": (0.55, 0.75, 0.85), "rock": (0.58, 0.62, 0.68), "foliage": (0.4, 0.6, 0.55)},
    'toxic': {"glow_a": (0.55, 1.0, 0.25), "glow_b": (0.85, 0.35, 1.0), "glow_c": (0.4, 1.0, 0.5), "tentacle": (0.55, 0.30, 0.70), "rock": (0.40, 0.36, 0.40), "foliage": (0.5, 0.7, 0.2)},
    'dead': {"rock": (0.62, 0.60, 0.58)},
    'radioactive': {"glow_a": (0.35, 1.0, 0.25), "glow_b": (0.7, 0.3, 1.0), "rock": (0.28, 0.30, 0.28), "foliage": (0.3, 0.6, 0.2)},
}


def _hsv_v(rgb):
    return max(rgb[:3])


def apply_game_tint(planet, key):
    """recolour the shared tinted materials like the game does for model tint key `key` of biome `planet`."""
    tints = PLANET_TINTS[planet]
    def get(k, *fallbacks, default=(1, 1, 1)):
        for kk in (k,) + fallbacks:
            if kk in tints:
                return tints[kk]
        return default
    base = {'Foliage_A': (0x92, 0x9E, 0x86), 'Foliage_B': (0x74, 0x7F, 0x68), 'Foliage_Flower': (0xD9, 0xD6, 0xD0),
            'Rock_A': (0x7F, 0x78, 0x70), 'Rock_B': (0x6B, 0x64, 0x5C), 'Bark': (0x73, 0x65, 0x5A), 'Bark_Pale': (0xF2, 0xEE, 0xE6)}
    for name, (r, g, b) in base.items():
        m = bpy.data.materials.get(name)
        if not m:
            continue
        v = max(r, g, b) / 255.0
        if name.startswith('Foliage'):
            t = get(key, 'foliage', default=(0.4, 0.6, 0.25))
            k = clamp(v / 0.62, 0.45, 1.4)
            col = (t[0] * k, t[1] * k, t[2] * k)
        elif name.startswith('Rock'):
            t = get('rock', default=(0.6, 0.58, 0.55))
            k = clamp(v / 0.5, 0.4, 1.5)
            col = (t[0] * k, t[1] * k, t[2] * k)
        else:
            t = get('wood', default=(0.5, 0.4, 0.32))
            col = (r / 255 * t[0] * 1.8, g / 255 * t[1] * 1.8, b / 255 * t[2] * 1.8)
        m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = srgb(hexc(*col))
    t = get(key, 'glow_a', 'ice', default=(0.6, 0.9, 1.0))
    m = bpy.data.materials.get('Crystal_Main')
    if m:
        bs = m.node_tree.nodes['Principled BSDF']
        bs.inputs['Base Color'].default_value = srgb(hexc(*t))
    m = bpy.data.materials.get('Glow_Main')
    if m:
        bs = m.node_tree.nodes['Principled BSDF']
        bs.inputs['Base Color'].default_value = srgb(hexc(t[0] * 0.35, t[1] * 0.35, t[2] * 0.35))
        bs.inputs['Emission Color'].default_value = srgb(hexc(*t))


_PV_DIRS = {"front": (0, -1, 0.0), "back": (0, 1, 0.0), "side": (1, 0, 0.0), "top": (0, -0.001, 1), "iso": (0.8, -1, 0.55),
            "iso2": (-0.8, 1, 0.5), "low": (0.7, -1, -0.25), "iso3": (0.9, 0.8, 0.45), "close": (0.5, -1, 0.35)}


def _pv_render(objs, path, view, res, margin=1.06, bg=(0.18, 0.2, 0.24), lens=50, target=None, extent=None):
    """render the given objects (everything else hidden) from a named view, camera distance fitted to the bounding box corners."""
    sc = bpy.context.scene
    keep = set(o.name for o in objs)
    hidden_before = {}
    for o in bpy.data.objects:
        if o.name not in keep:
            hidden_before[o.name] = o.hide_render
            o.hide_render = True
    mn, mx = _bounds_of(objs)
    ctr = (mn + mx) / 2 if target is None else Vector(target)
    d = Vector(_PV_DIRS[view]).normalized()
    f = -d
    r_ = f.cross(Vector((0, 0, 1)))
    if r_.length < 1e-4:
        r_ = Vector((1, 0, 0))
    r_.normalize()
    u_ = r_.cross(f)
    cd = bpy.data.cameras.new("__PVcam")
    cd.lens = lens
    cd.clip_start = 0.02
    cd.clip_end = 400
    cam = bpy.data.objects.new("__PVcam", cd)
    sc.collection.objects.link(cam)
    ang = cd.angle
    w, h = res
    if w >= h:
        tx = math.tan(ang / 2)
        ty = tx * h / w
    else:
        ty = math.tan(ang / 2)
        tx = ty * w / h
    dist = 0.0
    for ix in (mn.x, mx.x):
        for iy in (mn.y, mx.y):
            for iz in (mn.z, mx.z):
                c = Vector((ix, iy, iz)) - ctr
                zc = c.dot(d)
                dist = max(dist, zc + abs(c.dot(r_)) / tx, zc + abs(c.dot(u_)) / ty)
    dist *= margin
    cam.location = ctr + d * dist
    cam.rotation_euler = f.to_track_quat('-Z', 'Y').to_euler()
    rad_ = max((mx - mn).length / 2, 0.1)
    lights = []

    def add_light(kind, loc, energy, rot, color=(1, 1, 1)):
        ld = bpy.data.lights.new("__PVl", kind)
        ld.energy = energy
        ld.color = color
        lo = bpy.data.objects.new("__PVl", ld)
        sc.collection.objects.link(lo)
        lo.location = loc
        lo.rotation_euler = rot
        lights.append(lo)
    add_light('SUN', ctr + Vector((rad_, -rad_, rad_ * 1.5)), 3.2, (rad(50), 0, rad(35)))
    add_light('SUN', ctr + Vector((-rad_, rad_, rad_)), 1.2, (rad(60), 0, rad(215)), (0.8, 0.9, 1.0))
    add_light('SUN', ctr + Vector((0, 0, -rad_)), 0.5, (rad(180), 0, 0), (1.0, 0.95, 0.9))
    world = sc.world or bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    bgn = world.node_tree.nodes.get("Background")
    if bgn:
        bgn.inputs[0].default_value = (bg[0], bg[1], bg[2], 1)
        bgn.inputs[1].default_value = 1.0
    names = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    sc.render.engine = 'BLENDER_EEVEE' if 'BLENDER_EEVEE' in names else names[0]
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    try:
        sc.view_settings.view_transform = 'Standard'
    except Exception:
        pass
    sc.camera = cam
    sc.render.filepath = path
    sc.render.image_settings.file_format = 'PNG'
    bpy.ops.render.render(write_still=True)
    for lo in lights:
        ld = lo.data
        bpy.data.objects.remove(lo)
        bpy.data.lights.remove(ld)
    bpy.data.objects.remove(cam)
    bpy.data.cameras.remove(cd)
    for n_, hv in hidden_before.items():
        if n_ in bpy.data.objects:
            bpy.data.objects[n_].hide_render = hv


def _make_ground(rr):
    gm = bpy.data.meshes.new("__PVgm")
    bmg = bmesh.new()
    bmesh.ops.create_cone(bmg, cap_ends=True, segments=40, radius1=rr, radius2=rr, depth=0.05)
    for v in bmg.verts:
        v.co.z -= 0.025
    bmg.to_mesh(gm)
    bmg.free()
    gobj = bpy.data.objects.new("__PVground", gm)
    bpy.context.scene.collection.objects.link(gobj)
    gmat = bpy.data.materials.get("__PVgmat") or bpy.data.materials.new("__PVgmat")
    gmat.use_nodes = True
    gmat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.20, 0.17, 0.12, 1)
    gmat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 1.0
    if not gm.materials:
        gm.materials.append(gmat)
    return gobj


def _tile(files, res, cols, path):
    import numpy as np
    w, h = res
    cols = min(cols, len(files))
    rows = (len(files) + cols - 1) // cols
    sheet_ = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    for i, p in enumerate(files):
        im = bpy.data.images.load(p)
        a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)
        r_, c_ = divmod(i, cols)
        y0 = (rows - 1 - r_) * h
        sheet_[y0:y0 + h, c_ * w:(c_ + 1) * w, :] = a
        bpy.data.images.remove(im)
    out = bpy.data.images.new("__sheet", cols * w, rows * h, alpha=True)
    out.pixels = sheet_.ravel().tolist()
    out.filepath_raw = path
    out.file_format = 'PNG'
    out.save()
    bpy.data.images.remove(out)
    for p in files:
        try:
            os.remove(p)
        except Exception:
            pass


def contact(names, path, view='iso', res=(420, 420), cols=3, planet=None, key=None, ground=True, margin=1.06):
    """one tile per model (collection name) - or per (name, view) when `view` is a tuple of views - tiled into one PNG.
    planet/key -> preview with that biome's game tint (see PLANET_TINTS).  A thin ground disc shows the ground plane."""
    if planet:
        apply_game_tint(planet, key or 'foliage')
    views = view if isinstance(view, (tuple, list)) else (view,)
    tmp = []
    try:
        for i, n in enumerate(names):
            c = bpy.data.collections[n]
            objs = [o for o in c.all_objects if o.type in ('MESH', 'EMPTY')]
            mn, mx = _bounds_of([o for o in objs if o.type == 'MESH'])
            gobj = _make_ground(max(mx.x - mn.x, mx.y - mn.y) * 0.62 + 0.15) if ground else None
            for vi, vw in enumerate(views):
                p = os.path.join(os.path.dirname(path), "__ct%d_%d.png" % (i, vi))
                _pv_render(objs + ([gobj] if gobj else []), p, vw, res, margin=margin)
                tmp.append(p)
            if gobj is not None:
                gm = gobj.data
                bpy.data.objects.remove(gobj)
                bpy.data.meshes.remove(gm)
    finally:
        if planet:
            nature_palette()
    _tile(tmp, res, cols, path)
    print("contact sheet:", path)


# ----------------------------------------------------------------------------------------------
# run-3 helpers (toxic / frozen / volcanic / irradiated / dead moon)
# ----------------------------------------------------------------------------------------------
def lean_rot(az, tilt, spin=0.0):
    """3x3 rotation: spin about Z by `spin`, then tilt +Z by `tilt` rad towards azimuth `az`."""
    axis = Vector((-math.sin(az), math.cos(az), 0.0))
    return Matrix.Rotation(tilt, 3, axis) @ Matrix.Rotation(spin, 3, 'Z')


def lathe_rings(prof, c=(0, 0, 0), segs=14, lobes=0, lobe_amp=0.0, lobe_from=0.5, noise_amp=0.0, seed=0.0, ph=0.0, zig=None):
    """rings (lists of Vectors) of a closed lathe from profile [(r, z), ...] (r == 0 at the ends -> poles).
    lobes: scalloped rim (lobe_amp * cos(lobes*th + ph), faded in from radius fraction lobe_from); noise_amp = lumpiness;
    zig = (amp, r_from, r_to, ring_from): alternating +-amp z offsets per segment between those radii on rings >= ring_from (pleats / gills)."""
    c = Vector(c)
    rm = max(p[0] for p in prof) or 1.0
    rings = []
    for ri, (rr, zz) in enumerate(prof):
        ring = []
        for k in range(segs):
            th = TAU * k / segs
            lob = (1.0 + lobe_amp * math.cos(lobes * th + ph) * smoothstep(lobe_from, 1.0, rr / rm)) if lobes else 1.0
            nv = (1.0 + noise_amp * nz(Vector((math.cos(th) * 1.3, math.sin(th) * 1.3, zz * 1.7)), seed, 1.0)) if noise_amp else 1.0
            z_ = zz
            if zig and ri >= zig[3]:
                z_ += zig[0] * (1.0 if k % 2 == 0 else -1.0) * smoothstep(zig[1], zig[2], rr)
            r_ = rr * lob * nv
            ring.append(c + Vector((r_ * math.cos(th), r_ * math.sin(th), z_)))
        rings.append(ring)
    return rings


def contact_items(items, path, view='iso', res=(420, 420), cols=3, ground=True, margin=1.06):
    """items = [(collection, planet|None, tint_key|None), ...] - one tile per (item, view), each with its OWN game tint (see PLANET_TINTS)."""
    views = view if isinstance(view, (tuple, list)) else (view,)
    tmp = []
    try:
        for i, (n, planet, key) in enumerate(items):
            if planet:
                apply_game_tint(planet, key or 'foliage')
            c = bpy.data.collections[n]
            objs = [o for o in c.all_objects if o.type in ('MESH', 'EMPTY')]
            mn, mx = _bounds_of([o for o in objs if o.type == 'MESH'])
            gobj = _make_ground(max(mx.x - mn.x, mx.y - mn.y) * 0.62 + 0.15) if ground else None
            for vi, vw in enumerate(views):
                p = os.path.join(os.path.dirname(path), "__ct%d_%d.png" % (i, vi))
                _pv_render(objs + ([gobj] if gobj else []), p, vw, res, margin=margin)
                tmp.append(p)
            if gobj is not None:
                gm = gobj.data
                bpy.data.objects.remove(gobj)
                bpy.data.meshes.remove(gm)
            nature_palette()
    finally:
        nature_palette()
    _tile(tmp, res, cols, path)
    print("contact sheet:", path)


print("lib_nature.py loaded")
