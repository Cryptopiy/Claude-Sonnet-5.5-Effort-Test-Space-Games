"""monolith - ancient alien monolith ~7 m tall: slightly irregular dark stone slab, etched glyph lines (Glow_Rune, tintable) running up the
+Y face (= -Z in Godot) and a sunken ring base.  Origin = ground-contact centre (ring rim at y=0, pit floor at -0.45).  Re-runnable."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))

P = palette()
mat('Stone_Dark', '#26272D', metal=0.15, rough=0.88)
mat('Stone_Mid', '#4C4D56', metal=0.1, rough=0.93)
mat('Glow_Rune', '#DDF3FF', rough=0.3, emit='#FFFFFF', emit_strength=3.5)
COLL_NAME = "monolith"
coll = fresh_collection(COLL_NAME)
rng = random.Random(11)

ZS = [-0.45, -0.02, 0.9, 2.0, 3.1, 4.2, 5.3, 6.25, 6.62, 6.74]
NP = 40


def noise(th, z, seed=0.0):
    return 0.6 * math.sin(2 * th + 0.9 * z + seed) + 0.3 * math.sin(5 * th - 1.7 * z + 2 * seed) + 0.1 * math.sin(9 * th + 3.1 * z)


def slab(mb):
    rings = []
    for i, z in enumerate(ZS):
        t = z / 7.0
        a = 1.20 - 0.10 * t + 0.02 * math.sin(2.2 * z)
        b = 0.46 - 0.04 * t + 0.015 * math.sin(1.7 * z + 1.0)
        if i >= len(ZS) - 2:
            ins = 0.05 if i == len(ZS) - 2 else 0.12
            a -= ins
            b -= ins
        cx = 0.05 * math.sin(0.55 * z + 0.4)
        cy = 0.035 * t
        ring = []
        for k in range(NP):
            th = TAU * k / NP
            c, s = math.cos(th), math.sin(th)
            x = a * spow(c, 2 / 6.0)
            y = b * spow(s, 2 / 6.0)
            n_ = 1 + 0.012 * noise(th, z)
            zz = z
            if i >= len(ZS) - 3:
                zz = z + 0.30 * (x / 1.2)                  # sloped top
            ring.append(Vector((cx + x * n_, cy + y * n_, zz)))
        rings.append(ring)
    return mb.loft(rings, mat='Stone_Dark', cap_a=True, cap_b=True, cap_kind='fan')


def base_ring(mb):
    prof = [(0.0, -0.45, 'Stone_Dark'), (2.30, -0.45, 'Stone_Dark'), (2.50, -0.10, 'Stone_Mid'), (2.72, 0.07, 'Stone_Mid'),
            (3.60, 0.07, 'Stone_Mid'), (3.88, -0.12, 'Stone_Mid'), (3.95, -0.80, 'Stone_Mid'), (0.0, -0.80, 'Stone_Mid')]
    mb.lathe_mats(prof, 40, None, cap_a=False, cap_b=False)
    # rune rings and radial ticks on the rim
    mb.torus(3.0, 0.028, center=(0, 0, 0.07), segs=48, tsegs=4, mat='Glow_Rune')
    mb.torus(3.42, 0.020, center=(0, 0, 0.07), segs=48, tsegs=4, mat='Glow_Rune')
    for k in range(24):
        a = TAU * k / 24 + 0.05
        ln = 0.22 if k % 3 else 0.34
        c = Vector((math.cos(a), math.sin(a), 0.075)) * (3.21)
        mb.rbox((ln, 0.04, 0.02), center=c, rot=Matrix.Rotation(a + PI / 2, 3, 'Z'), bevel=0.0, mat='Glow_Rune')
    # fallen rubble stones around the pit
    for k in range(5):
        a = rad(35 + k * 71)
        c = Vector((math.cos(a), math.sin(a), 0.0)) * 4.25
        sz = 0.35 + 0.25 * rng.random()
        mb.rbox((sz * 1.3, sz, sz * 0.7), center=c + Vector((0, 0, sz * 0.2 - 0.25)), rot=(0.2 * k, 0.3, a), bevel=0.06, bsegs=1, mat='Stone_Mid')


def P3(x, z):
    return (x, 5.0, z)


def circle(cx, cz, r, n=22, a0=0.0, a1=TAU):
    return [P3(cx + r * math.cos(a0 + (a1 - a0) * i / n), cz + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def spiral(cx, cz, r0, r1, turns, n=34):
    return [P3(cx + (r0 + (r1 - r0) * i / n) * math.cos(TAU * turns * i / n), cz + (r0 + (r1 - r0) * i / n) * math.sin(TAU * turns * i / n))
            for i in range(n + 1)]


def glyphs(mb, surf):
    W = 0.055

    def line(pts, w=W):
        strip_on_surface(mb, surf, pts, w, 'Glow_Rune', lift=0.012, height=0.012, direction=(0, -1, 0), step=0.12)
    # spine + side lines with ticks
    line([P3(0, 0.75), P3(0, 6.05)])
    for sx in (-1, 1):
        line([P3(sx * 0.82, 0.95), P3(sx * 0.82, 5.95)], 0.045)
        for zz in np_range(1.2, 5.9, 0.5):
            line([P3(sx * 0.82, zz), P3(sx * 0.66, zz)], 0.04)
    # symbols along the spine
    cz = 1.35
    line(circle(0, cz, 0.30))
    line(circle(0, cz, 0.12, 12), 0.045)
    cz = 2.3
    line([P3(0, cz + 0.36), P3(0.34, cz - 0.22), P3(-0.34, cz - 0.22), P3(0, cz + 0.36)])
    line([P3(-0.2, cz - 0.02), P3(0.2, cz - 0.02)], 0.045)
    cz = 3.25
    for s_ in (0.30, 0.17):
        line([P3(-s_, cz - s_), P3(s_, cz - s_), P3(s_, cz + s_), P3(-s_, cz + s_), P3(-s_, cz - s_)], 0.045)
    cz = 4.2
    line([P3(-0.40, cz), P3(-0.22, cz + 0.13), P3(0, cz + 0.18), P3(0.22, cz + 0.13), P3(0.40, cz)], 0.05)
    line([P3(-0.40, cz), P3(-0.22, cz - 0.13), P3(0, cz - 0.18), P3(0.22, cz - 0.13), P3(0.40, cz)], 0.05)
    line(circle(0, cz, 0.07, 10), 0.05)
    cz = 5.1
    line(spiral(0, cz, 0.04, 0.32, 1.6), 0.05)
    cz = 5.78
    line([P3(0, cz - 0.2), P3(0, cz + 0.2)], 0.05)
    line([P3(-0.2, cz), P3(0.2, cz)], 0.05)
    line(circle(0, cz, 0.24, 18, rad(20), rad(70)), 0.045)
    line(circle(0, cz, 0.24, 18, rad(110), rad(160)), 0.045)
    line(circle(0, cz, 0.24, 18, rad(200), rad(250)), 0.045)
    line(circle(0, cz, 0.24, 18, rad(290), rad(340)), 0.045)
    # connectors from the spine to the side lines
    for zz in (1.35, 2.3, 3.25, 4.2, 5.1):
        for sx in (-1, 1):
            line([P3(sx * 0.34, zz), P3(sx * 0.82, zz)], 0.04)


def np_range(a, b, step):
    out, v = [], a
    while v < b:
        out.append(v)
        v += step
    return out


def build():
    mb = MB("monolith")
    sp = slab(mb)
    base_ring(mb)
    surf = Surf(faces=sp.faces)
    glyphs(mb, surf)
    ob = mb.finish("monolith", coll, smooth_angle=50, weighted=False)
    return ob


ob = build()
bpy.context.view_layer.update()
check(COLL_NAME)
park(COLL_NAME)
