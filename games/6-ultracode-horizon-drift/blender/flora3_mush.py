"""Mushroom builder shared by the flora3 toxic-fungus models.  Material index convention (caller passes its own list):
   MI = dict(stem=0, cap=1, glow=2, band=3)"""
import math, random
import bmesh
from mathutils import Vector, Matrix, noise
import lib_common as L
import flora3_lib as F

CAPS = {
    "dome": [(1.0, 0.0), (0.94, 0.30), (0.74, 0.64), (0.42, 0.89), (0.0, 1.0)],
    "cone": [(1.0, 0.0), (0.78, 0.28), (0.56, 0.56), (0.3, 0.82), (0.0, 1.0)],
    "bell": [(1.0, 0.0), (0.96, 0.38), (0.82, 0.68), (0.52, 0.9), (0.0, 1.0)],
    "flat": [(1.0, 0.0), (0.92, 0.32), (0.62, 0.74), (0.3, 0.95), (0.0, 1.0)],
}


def mushroom(base, height, cap_r, bend=(0.3, 0.1), seed=0, style="dome", spots=10, MI=None, gills=True, skirt=True,
             cap_h=None, stem_r=None, bulb=1.5, segs=20, spot_scale=1.0, band=True, edge_glow=True, tilt=(0.0, 0.0), spot_big=0.0, stem_segs=11):
    MI = MI or dict(stem=0, cap=1, glow=2, band=3)
    rg = random.Random(seed)
    H = height
    R = cap_r
    sr = stem_r if stem_r else max(0.06, R * 0.17)
    ch = cap_h if cap_h else R * 0.55
    bx, by = bend
    # --- stem
    zc = H - ch * 0.78        # underside z where the stem meets the cap
    pts = []
    radii = []
    n = 9
    for i in range(n + 1):
        t = i / n
        z = -0.05 + (zc + 0.05) * t
        off = t ** 1.6
        pts.append(Vector((bx * off, by * off, z)))
        r = sr * (1.0 + (bulb - 1.0) * max(0.0, 1 - t * 3.2) ** 1.7 + 0.18 * math.sin(t * 3.1) + 0.12 * t)
        radii.append(r)
    stem = F.tube(pts, radii, segs=stem_segs, mat=MI["stem"], rough=0.05, seed=seed,
                  mat_fn=(lambda i: MI["band"] if (band and i in (3, 6)) else MI["stem"]),
                  ring_fn=lambda i, k, a: 1.0 + 0.05 * math.sin(a * 5 + i), cap_start=True, cap_end=False)
    top = pts[-1]
    # --- cap (lathe: underside out, around the rim, over the top)
    rim_z = zc + ch * 0.05
    under = [(sr * 0.9, zc), (R * 0.35, zc - ch * 0.02), (R * 0.7, zc + ch * 0.0), (R * 0.94, rim_z - ch * 0.12)]
    upper = [(R * rf, rim_z + ch * zf) for (rf, zf) in CAPS[style]]
    prof = under + [(R * 1.0, rim_z - ch * 0.10)] + upper
    mat_fn = lambda i: (MI["glow"] if (gills and i < 3) else (MI["glow"] if (edge_glow and i == 3) else MI["cap"]))
    nu = len(under)

    def ring_fn(i, k, a):
        w = 1.0
        if 2 <= i <= nu + 1:
            w *= 1.0 + 0.06 * math.sin(a * 9 + seed) + 0.03 * math.sin(a * 17)
        w *= 1.0 + 0.035 * noise.noise(Vector((math.cos(a) * 1.5 + seed, math.sin(a) * 1.5, i * 0.5)))
        return w

    def z_fn(i, k, a):
        if gills and 1 <= i <= 3:
            return -ch * 0.075 * (0.5 + 0.5 * math.sin(a * 26)) * (i / 3.0)
        return 0.0

    cap = F.lathe(prof, segs=segs, mat_fn=mat_fn, ring_fn=ring_fn, z_fn=z_fn, cap_last=False, seed=seed,
                  center=(top.x, top.y, 0.0))
    parts = [stem, cap]
    # --- skirt
    if skirt:
        zs = zc - ch * 0.38
        rs = sr * 1.05
        sp = [(rs, zs - 0.02), (rs * 2.0, zs - ch * 0.28), (rs * 2.15, zs - ch * 0.3), (rs * 2.0, zs - ch * 0.22), (rs * 1.0, zs + 0.05)]
        tt = max(0.0, min(1.0, (zs + 0.05) / (zc + 0.05)))
        o = tt ** 1.6
        parts.append(F.lathe(sp, segs=14, mat=MI["band"], ring_fn=lambda i, k, a: 1.0 + 0.1 * math.sin(a * 7 + seed),
                             center=(bx * o, by * o, 0.0)))
    # --- spots on the cap
    bvh = F.bvh_of(cap)
    for j in range(spots):
        a = rg.uniform(0, math.tau)
        s_ = math.sqrt(rg.uniform(0.02, 0.62))
        o = Vector((top.x + math.cos(a) * R * s_ * 0.92, top.y + math.sin(a) * R * s_ * 0.92, H + 2.0))
        hit = bvh.ray_cast(o, Vector((0, 0, -1)))
        if hit[0] is None:
            continue
        loc, nrm = hit[0], hit[1]
        rr = (R * rg.uniform(0.06, 0.12) + spot_big * rg.random() * R * 0.1) * spot_scale
        sph = L.bm_sphere(rr, subdiv=1 if rr < 0.2 else 2, mat_index=MI["glow"])
        bmesh.ops.scale(sph, vec=Vector((1.0, 1.0, 0.55)), verts=sph.verts)
        m = Matrix.Translation(loc - nrm * rr * 0.15) @ F.rot_to(nrm)
        bmesh.ops.transform(sph, matrix=m, verts=sph.verts)
        parts.append(sph)
    bm = F.join(*parts)
    T = Matrix.Translation(Vector(base)) @ L.xf((0, 0, 0), (tilt[0], tilt[1], 0))
    bmesh.ops.transform(bm, matrix=T, verts=bm.verts)
    return bm


def mycelium(center, radius, mats_stem, mats_glow, seed=0, n=6, bump=0.28):
    """Low lumpy mound + creeping roots with glowing nubs."""
    rg = random.Random(seed)
    parts = [F.rock_blob(radius, 3, 0.25, 1.2, seed, (1, 1, bump), flat_bottom=0.1, mat=mats_stem, center=center)]
    for i in range(n):
        a = i * math.tau / n + rg.uniform(-0.3, 0.3)
        ca, sa = math.cos(a), math.sin(a)
        L1 = radius * rg.uniform(1.3, 1.9)
        cx, cy, cz = center
        pts = F.bez((cx + ca * radius * 0.4, cy + sa * radius * 0.4, 0.12), (cx + ca * radius * 0.9, cy + sa * radius * 0.9, 0.22),
                    (cx + ca * L1 * 0.8 + sa * 0.2, cy + sa * L1 * 0.8 - ca * 0.2, 0.1), (cx + ca * L1, cy + sa * L1, 0.05), 5)
        parts.append(F.tube(pts, [0.12, 0.1, 0.085, 0.06, 0.04, 0.0], segs=5, mat=mats_stem, rough=0.1, seed=seed + i, cap_start=False))
        parts.append(L.bm_sphere(0.07, subdiv=1, matrix=L.xf((cx + ca * L1 * 0.62, cy + sa * L1 * 0.62, 0.13)), mat_index=mats_glow))
    return F.join(*parts)
