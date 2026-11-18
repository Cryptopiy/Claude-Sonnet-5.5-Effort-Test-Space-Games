"""Export specs for every model of brief 1 (except ship/astronaut, which have their own export scripts).
Usage inside Blender:  exec(open(this file)); run(["landing_pad", ...])
Each export: unpark -> per-model material overrides -> sanity checks -> export_model -> restore materials -> park again.
(Material names are global in a .blend, so a model that needs e.g. a red Emissive_Light sets it just for its export.)
"""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\export_lib.py', encoding='utf-8').read(), 'e', 'exec'))

EL_MINT = dict(color='#C8FFF0', emit='#7DFFD0', emit_strength=3.0, rough=0.4)
EL_WHITE = dict(color='#FFF6E0', emit='#FFF0CC', emit_strength=3.0, rough=0.4)
EL_RED = dict(color='#FF9A8A', emit='#FF1A0A', emit_strength=6.0, rough=0.4)

SPECS = {
    "landing_pad": dict(
        category="structure", overrides={'Emissive_Light': EL_WHITE},
        collision={"shape": "cylinder", "radius": 8.0, "height": 1.2, "offset": [0, -0.6, 0]},
        notes=("Round landing pad, diameter 16 m. Origin = pad centre on the top surface (top at y=0 in Godot, body extends down to y=-1.2 so it can sink "
               "into sloped ground). Inset ship glyph in the centre (nose towards -Z Godot), diagonal hazard ring (yellow/black), 12 recessed edge "
               "lights on the rim chamfer (alternating Emissive_Amber / Emissive_Light = warm white), 3 light pylons on the rim (angles 90/210/330 deg in Blender), "
               "service hatch with a step on the +Z (Godot) side. Single mesh object 'landing_pad'. Materials: Pad_Plate, Pad_Side, "
               "Pad_Marking, Pad_Seam, Hazard_Yellow, Hazard_Black, Hull_Dark, Hull_Accent, Metal, Emissive_Light, Emissive_Amber.")),
    "outpost_hab": dict(
        category="structure", overrides={'Emissive_Light': EL_MINT},
        collision={"shape": "box", "size": [9.3, 5.5, 6.8], "offset": [0, 1.95, -0.4]},
        notes=("Habitat module: capsule dome on a rim base, 8 x 4.9 m footprint (plinth 9.3 x 6 m), dome top 4.4 m, antenna to ~5.2 m. Origin = ground-contact "
               "centre; the concrete foundation extends 0.8 m below y=0. The AIRLOCK DOOR FACES +Y in Blender = -Z in Godot (porch with 2 steps in front of it, "
               "footprint reaches ~5.6 m towards -Z). Windows use Emissive_Window (warm amber), the airlock frame uses Emissive_Light (mint). Utility pipes, "
               "a tank and a generator box are on the +Z (Godot) back side. The collision box covers plinth + dome + airlock only (not the porch/back tank). "
               "Single mesh object 'outpost_hab'.")),
    "outpost_tower": dict(
        category="structure", overrides={'Emissive_Light': EL_RED},
        collision={"shape": "cylinder", "radius": 2.2, "height": 18.3, "offset": [0, 9.15, 0]},
        notes=("Lattice communications tower, 18 m tall (lamp top at 18.05 m), 3 x 3 m base tapering to 1 m. Origin = tower centre at ground level, foundation 0.8 m below. "
               "Child node 'Light_Top' (separate mesh, origin at the lamp centre, material Emissive_Light = RED): blink it by toggling visibility / emission energy. "
               "Equipment hut at +X (x=3.9 m) on a shared concrete slab; dish on the +Z (Godot) side, ladder on the -Z side. The collision cylinder only covers the tower "
               "base (add a box for the hut yourself if needed: x 2.3..5.5, z -1.4..1.4, height 2.6).")),
    "outpost_container": dict(
        category="structure", overrides={},
        collision={"shape": "box", "size": [6.1, 3.55, 2.8], "offset": [0, 0.975, 0]},
        notes=("Shipping container 6.0 x 2.5 x 2.6 m (orange, weathered: Container_Orange / Container_OrangeWorn). Raised 0.15 m on two concrete sleepers that extend 0.8 m "
               "below the origin plane. DOORS face +X (Blender and Godot). Single mesh object 'outpost_container'.")),
    "outpost_container_b": dict(
        category="structure", overrides={},
        collision={"shape": "box", "size": [9.1, 3.55, 2.8], "offset": [0, 0.975, 0]},
        notes=("Long (9 m) shipping container, teal body with white roof and white stripe, stencil-like marks (Container_Teal / Container_TealWorn / Container_White / "
               "Container_Mark). Three concrete sleepers extend 0.8 m below the origin plane. DOORS face +X. Single mesh object 'outpost_container_b'.")),
    "outpost_tank": dict(
        category="structure", overrides={'Emissive_Light': EL_MINT},
        collision=None,       # computed from the bounds
        notes=("Tank farm: 3 vertical storage tanks (4 m dia, 6.4 m tall, centres at x=-5/0/+5), overhead catwalk with railings at y=6.75, caged ladder at the +X end of the "
               "catwalk, valve manifold along the +Z (Godot) side, pump house at x=+11.8 (door on the -Z side). Origin = centre of the middle tank at ground level; "
               "concrete slab extends 0.8 m below. Level gauges use Emissive_Light (mint). Single mesh object 'outpost_tank'.")),
}


EL_GREEN = dict(color='#C8FFD0', emit='#3CFF6A', emit_strength=3.0, rough=0.4)
EL_EMBER = dict(color='#FFB070', emit='#FF6A10', emit_strength=4.5, rough=0.5)

SPECS.update({
    "outpost_solar": dict(
        category="structure", overrides={'Emissive_Light': EL_GREEN}, collision=None,
        notes=("Solar field: 8 tilted panels (2 rows x 4, 1.75 x 2.3 m each, tilt 30 deg, facing +Y Blender = -Z Godot) with blue-black Solar_Cell and thin Solar_Grid lines, "
               "light frames, stands with concrete footings that extend 0.8 m below y=0, battery box at +X (x=5.6) with Emissive_Light (green) / Emissive_Amber indicators, "
               "small weather mast at the -X back corner. Panel field is ~8 x 6 m. Origin = centre of the panel field at ground level. Single mesh object 'outpost_solar'.")),
    "beacon_pylon": dict(
        category="structure", overrides={},
        collision={"shape": "cylinder", "radius": 0.6, "height": 7.2, "offset": [0, 3.6, 0]},
        notes=("Beacon pylon ~7.1 m tall: octagonal base plate with Emissive_Light accents, tapered 8-sided column, 3 prongs holding a floating crystal and a ring, both in "
               "material Glow_Beacon (white-ish base colour, white emission strength 4: multiply / tint it per planet). Origin = base centre at ground level, "
               "concrete foundation extends 0.8 m below. Single mesh object 'beacon_pylon'.")),
    "monolith": dict(
        category="structure", overrides={},
        collision={"shape": "box", "size": [2.5, 7.45, 1.0], "offset": [0, 3.28, 0]},
        notes=("Alien monolith, irregular dark stone slab ~2.4 x 0.9 x 7 m (top is cut at a slant), standing in a sunken ring base (outer radius 3.95 m, rim at y=+0.07, pit floor at "
               "y=-0.45). Etched glyph lines in material Glow_Rune (white-ish emission, tintable) run up the +Y Blender = -Z Godot face and over the ring rim. "
               "Origin = ground-contact centre. Single mesh object 'monolith'. Collision box covers the slab only.")),
    "crate_supply": dict(
        category="prop", overrides={'Emissive_Light': EL_GREEN},
        collision={"shape": "box", "size": [1.25, 1.3, 1.25], "offset": [0, 0.65, 0]},
        notes=("Supply crate / drop pod ~1.2 x 1.3 x 1.2 m (orange body, white lid, dark corner guards, latches, handles). Origin = bottom centre (on four rubber feet). "
               "Indicator panel on the +Y Blender = -Z Godot face uses Emissive_Light (green) + Emissive_Amber; amber beacon on the lid. Single mesh object 'crate_supply'.")),
    "wreck_ship": dict(
        category="structure",
        overrides={'Emissive_Light': EL_EMBER, 'Hull_Paint': dict(color='#8A867F', metal=0.3, rough=0.84),
                   'Hull_Accent': dict(color='#B4561F', metal=0.25, rough=0.8)},
        collision=None, shrink=0.6,
        notes=("Crashed small ship ~10 m long: torn plating exposing ribs and a dark interior, bent/sheared left wing, wing stub + missing engine on the right (exposed ring frames and "
               "cables), broken fin and canopy frame, scorched weathered Hull_Paint (this model's Hull_Paint / Hull_Accent are exported in dirty colours) with Hull_Dark soot, "
               "glowing embers in Emissive_Light (orange). The ~14 deg nose-up pitch and ~6 deg roll are BAKED into the mesh; the ORIGIN is at the lowest centre point of the hull "
               "(everything is above y=0): sink it ~1-1.5 m into the ground to get the half-buried look. Single mesh object 'wreck_ship'. Collision box is slightly shrunk.")),
})


def bounds_godot(name):
    c = bpy.data.collections[name]
    dg = bpy.context.evaluated_depsgraph_get()
    mn = [1e9] * 3
    mx = [-1e9] * 3
    for o in c.all_objects:
        if o.type != 'MESH':
            continue
        me = o.evaluated_get(dg).to_mesh()
        for v in me.vertices:
            w = o.matrix_world @ v.co
            g = (w.x, w.z, -w.y)
            for i in range(3):
                mn[i] = min(mn[i], g[i])
                mx[i] = max(mx[i], g[i])
        o.evaluated_get(dg).to_mesh_clear()
    return mn, mx


def bbox_collision(name, shrink=0.0):
    mn, mx = bounds_godot(name)
    size = [round(mx[i] - mn[i] - shrink, 2) for i in range(3)]
    off = [round((mx[i] + mn[i]) / 2, 2) for i in range(3)]
    return {"shape": "box", "size": size, "offset": off}


def check_model(name):
    c = bpy.data.collections[name]
    problems = []
    seen = set()
    for o in c.all_objects:
        if o.name in seen:
            problems.append("duplicate name " + o.name)
        seen.add(o.name)
        if "." in o.name or " " in o.name:
            problems.append("bad name " + o.name)
        r, s = o.rotation_euler, o.scale
        if max(abs(r.x), abs(r.y), abs(r.z)) > 1e-6 or max(abs(s.x - 1), abs(s.y - 1), abs(s.z - 1)) > 1e-6:
            problems.append("non-identity rotation/scale on " + o.name)
        if o.type == 'MESH':
            dg = bpy.context.evaluated_depsgraph_get()
            me = o.evaluated_get(dg).to_mesh()
            me.calc_loop_triangles()
            vol = 0.0
            for t in me.loop_triangles:
                a, b, cc = (o.matrix_world @ me.vertices[i].co for i in t.vertices)
                vol += a.dot(b.cross(cc)) / 6.0
            o.evaluated_get(dg).to_mesh_clear()
            if vol <= 0:
                problems.append("%s signed volume %.3f (inverted?)" % (o.name, vol))
            if len(o.material_slots) == 0:
                problems.append("%s has no material" % o.name)
    return problems


def run(names):
    for n in names:
        spec = SPECS[n]
        unpark(n)
        roots = [o for o in bpy.data.collections[n].all_objects if o.parent is None and o.type == 'MESH']
        renamed = None
        try:
            if len(roots) == 1 and roots[0].name == n:
                renamed = roots[0]
                renamed.name = "Body"          # avoids Godot naming the scene root '<name>2' (child had the same name)
            set_material_overrides(spec.get("overrides", {}))
            probs = check_model(n)
            if probs:
                print("PROBLEMS in", n, probs)
            col = spec["collision"] if spec["collision"] else bbox_collision(n, spec.get("shrink", 0.0))
            notes = spec["notes"].replace("Single mesh object '%s'" % n, "Single mesh node 'Body'")
            export_model(n, category=spec["category"], collision=col, notes=notes)
        finally:
            restore_materials()
            if renamed is not None:
                renamed.name = n
            park(n)
    bpy.ops.wm.save_mainfile()
    print("saved", bpy.data.filepath)
