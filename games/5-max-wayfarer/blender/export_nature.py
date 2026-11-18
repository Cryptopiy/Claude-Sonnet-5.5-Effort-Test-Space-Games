"""Export specs + driver for brief 2 (flora, rocks, resource nodes, biome props).
Usage inside Blender:
    exec(compile(open(r'...\\blender\\export_nature.py', encoding='utf-8').read(), 'en', 'exec'));  run(['tree_lush_a', ...])
Per model: unpark -> name the single mesh object 'Body' -> sanity checks -> export_model (GLB + manifest.json entry) -> park again,
then one line per model is written to blender/PROGRESS.md and the .blend is saved.
(Models with a hierarchy / several nodes: add `root_name=None` in the spec and the node names are kept as they are.)
"""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\lib.py', encoding='utf-8').read(), 'lib', 'exec'))
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\export_lib.py', encoding='utf-8').read(), 'e', 'exec'))

PROGRESS = os.path.join(PROJECT, 'blender', 'PROGRESS.md')


def cyl(r, h, y0=0.0):
    return {"shape": "cylinder", "radius": r, "height": h, "offset": [0, round(y0 + h / 2, 3), 0]}


def sph(r, y):
    return {"shape": "sphere", "radius": r, "offset": [0, y, 0]}


def box(sx, sy, sz, y0=0.0, ox=0.0, oz=0.0):
    return {"shape": "box", "size": [sx, sy, sz], "offset": [ox, round(y0 + sy / 2, 3), oz]}


NONE = {"shape": "none"}


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


def auto_box(shrink=0.0, cap=None):
    """collision box from the model bounds (Godot axes); shrink = metres removed from every size; cap = max height"""
    def f(n):
        mn, mx = bounds_godot(n)
        sz = [mx[i] - mn[i] - shrink for i in range(3)]
        cy = (mx[1] + mn[1]) / 2
        if cap is not None and sz[1] > cap:
            sz[1] = cap
            cy = mn[1] + cap / 2
        return {"shape": "box", "size": [round(v, 2) for v in sz], "offset": [round((mx[0] + mn[0]) / 2, 2), round(cy, 2), round((mx[2] + mn[2]) / 2, 2)]}
    return f


def auto_sphere(r, y=None):
    """collision sphere of radius r centred on the model bounds (y overridable)"""
    def f(n):
        mn, mx = bounds_godot(n)
        return {"shape": "sphere", "radius": r, "offset": [round((mx[0] + mn[0]) / 2, 2), round(y if y is not None else (mx[1] + mn[1]) / 2, 2), round((mx[2] + mn[2]) / 2, 2)]}
    return f

SPECS = {}


def spec(name, category, collision, notes, **kw):
    SPECS[name] = dict(category=category, collision=collision, notes=notes, **kw)


FOLIAGE_NOTE = ("Tint contract: Foliage_A / Foliage_B / Foliage_Flower are recoloured by the game (planet foliage tint x value of the base colour; Foliage materials are "
                "double sided); Bark is multiplied by the wood tint. ")

spec('tree_lush_a', 'flora', cyl(0.5, 5.0),
     "Broadleaf tree ~9 m tall, crown ~7 m wide: gnarly tapering trunk with flared roots (a few cm below y=0), 4 big branches, 7 lumpy leaf blobs. "
     "Materials: Bark (trunk + branches), Foliage_A (light blobs), Foliage_B (darker blobs). " + FOLIAGE_NOTE + "Origin = ground contact at the trunk base. Single mesh node 'Body'.")
spec('tree_lush_b', 'flora', cyl(0.45, 7.0),
     "Tall slender broadleaf tree ~14 m, trunk leans ~5 deg towards +X, three layered umbrella canopy tiers (r 3.4 / 2.65 / 1.85 m) with leafy lumps and a top tuft. "
     "Materials: Bark, Foliage_A (lower + top tier), Foliage_B (middle tier). " + FOLIAGE_NOTE + "Origin = ground contact at the trunk base. Single mesh node 'Body'.")
spec('tree_lush_c', 'flora', cyl(0.7, 4.0),
     "Alien parasol tree ~7.4 m: thick curved trunk, one big flat canopy (r 5.2 m, scalloped drooping rim, rim height ~4.4 m so you can walk under it), radial ribs under the "
     "canopy, 11 hanging vines (Foliage_B) with 6 pods (Foliage_Flower), 9 blossoms on top (Foliage_Flower petals, Foliage_B core). Collision only covers the trunk. "
     + FOLIAGE_NOTE + "Origin = ground contact at the trunk base. Single mesh node 'Body'.")
spec('bush_lush', 'flora', NONE,
     "Rounded bush ~1.4 m: 7 lumpy leaf blobs (Foliage_A / Foliage_B) + 3 small twigs (Bark). " + FOLIAGE_NOTE + "Origin = ground contact. Single mesh node 'Body'.")
spec('fern', 'flora', NONE,
     "Fern ~1.1 m tall, ~2 m wide: 9 arching pinnate fronds (midrib + serrated leaflets, double sided Foliage_A) from a small Foliage_B base. " + FOLIAGE_NOTE
     + "Origin = ground contact at the centre. Single mesh node 'Body'.")
spec('flower_cluster', 'flora', NONE,
     "5 flowers ~0.65 m tall: stems + flower cores (Foliage_B), 8-petal heads (Foliage_Flower), 4 basal leaves (Foliage_A). NOTE: the game applies ONE tint key to all Foliage* "
     "materials of a model, so with the biome tint 'flower' the leaves are tinted like the petals (value differences keep them readable: petals brightest, stems darkest). "
     + FOLIAGE_NOTE + "Origin = ground contact. Single mesh node 'Body'.")
spec('grass_tuft', 'flora', NONE,
     "Grass tuft ~0.7 m: 11 bent pointed blades (5 triangles each, 55 triangles in total), double sided Foliage_A. " + FOLIAGE_NOTE + "Origin = ground contact at the centre. Single mesh node 'Body'.")


ROCK_NOTE = ("Rock_A / Rock_B are recoloured by the game with the planet's rock tint (Rock_B is the darker value, used for stained patches). Low-poly flat shading, "
             "base sinks ~8 cm below y=0 so it sits in the terrain. ")
spec('rock_a', 'rock', sph(1.1, 0.85),
     "Rounded low-poly boulder ~2.2 x 1.8 x 2.0 m (flat-shaded, a few flat facets). " + ROCK_NOTE + "Origin = ground contact (bottom centre). Single mesh node 'Body'.")
spec('rock_b', 'rock', auto_box(0.2),
     "Angular leaning slab ~2.6 x 1.5 m (+ a smaller slab leaning on it), chipped edges. " + ROCK_NOTE + "Collision = box around both. Origin = ground contact. Single mesh node 'Body'.")
spec('rock_c', 'rock', auto_sphere(1.5, 0.8),
     "Cluster of three stones (big rounded one + two angular ones), ~3.3 m wide, tallest ~1.5 m. " + ROCK_NOTE + "Origin = ground contact near the big stone. Single mesh node 'Body'.")
spec('rock_d', 'rock', cyl(0.9, 3.0),
     "Tall leaning rock spire ~3.5 m with two small boulders at its foot; faceted, banded Rock_A / Rock_B. " + ROCK_NOTE + "Origin = ground contact at the spire's base centre. Single mesh node 'Body'.")
spec('boulder_big', 'rock', auto_box(0.5),
     "Big tiered boulder ~8.8 x 6 x 7 m: three stacked ledge blocks with a flat top plus buttress blocks around the foot (collision = one box around everything). "
     + ROCK_NOTE + "Origin = ground contact at the centre of the base. Single mesh node 'Body'.")

RES_NOTE = "Fixed colours (Res_* materials are NOT tinted by the game). Origin = ground contact at the bottom centre. Single mesh node 'Body'. "
spec('resource_sodium', 'resource', sph(0.6, 0.55),
     "Sodium node ~1.3 m: 7 hexagonal amber crystals splaying out of a small rubble base. Res_Sodium = amber/orange-yellow emission strength 2.5 (the crystals), base stones use Rock_B (tinted). " + RES_NOTE)
spec('resource_ferrite', 'resource', sph(0.7, 0.5),
     "Ferrite node ~1.2 m: rocky lump (Rock_A / Rock_B, tinted) with raised orange-brown ore veins and ore nuggets (Res_Ferrite: metallic 0.9, rough 0.4, tiny emission 0.35 so it stays readable "
     "without sky reflections) and small shiny flecks (Res_Ferrite_Fleck: metallic 1.0). " + RES_NOTE)
spec('resource_carbon', 'resource', sph(0.55, 0.45),
     "Carbon node ~1.1 m: squat plant, 5 dark purple bulbs (Res_Carbon, faint purple emission 0.25) on short stems, 5 drooping leaf blades, a tall bud with a faintly glowing green tip "
     "(Res_Carbon_Tip: green emission 1.6) and two small glowing nubs. " + RES_NOTE)

ARID_NOTE = "Biome tint keys in biomes.gd: cactus -> 'cactus', dead_tree -> 'wood' (Bark), shrub -> 'shrub', rocks -> 'rock'. "
spec('cactus_a', 'flora', cyl(0.45, 4.0),
     "Saguaro cactus ~4.6 m with two upturned arms; flat-shaded, 8-ribbed body (Foliage_A, double sided), small blossoms on the three tips (Foliage_Flower petals + Foliage_B core). "
     + ARID_NOTE + "Origin = ground contact at the trunk base. Single mesh node 'Body'.")
spec('cactus_b', 'flora', auto_sphere(0.6, 0.45),
     "Cactus cluster ~1.45 m: one ribbed barrel cactus (Foliage_A) + a prickly-pear bush of 5 flat pads (Foliage_A) with blossoms (Foliage_Flower petals, Foliage_B core). "
     + ARID_NOTE + "Origin = ground contact; the cluster extends mostly towards -X/+Z(Godot). Single mesh node 'Body'.")
spec('dead_tree', 'flora', cyl(0.4, 4.0),
     "Twisted bare dead tree ~5.3 m: leaning trunk with root flare, three main limbs + side branches with forks and broken stubs. Only Bark (multiplied by the wood tint x1.8; "
     "very dark under the volcanic wood tint = charred look). " + ARID_NOTE + "Origin = ground contact at the trunk base. Single mesh node 'Body'.")
spec('desert_shrub', 'flora', NONE,
     "Spiky dry shrub ~0.9 m: 46 curved pointed blades (double sided Foliage_B) around a small core. " + ARID_NOTE + "Origin = ground contact at the centre. Single mesh node 'Body'.")
spec('mesa_rock', 'rock', {"shape": "box", "size": [5.4, 8.2, 5.4], "offset": [0, 4.1, 0]},
     "Banded mesa / hoodoo rock tower ~9.3 m: 9 tiered layers alternating Rock_A / Rock_B (flat ledges, overhanging cap rock), sloped talus skirt (r ~4.5 m at the foot) and 4 boulders around it. "
     "Collision box covers the tower only (not the talus skirt). " + ROCK_NOTE + "Origin = centre of the base at ground level. Single mesh node 'Body'.")
spec('rock_arch', 'rock', box(3.8, 6.5, 4.0, 0.0, -4.1, 0.0),
     "Natural stone arch ~9.5 m tall, ~11 m wide outside (opening ~5.5 m wide, ~7 m high): faceted pillars and a thinner crown, banded Rock_A / Rock_B, rubble at the feet. "
     "The `collision` hint is only the LEFT pillar (box centred x=-4.1 m); `collision_boxes` (extra manifest field) lists all three boxes (both pillars + crown) so the opening stays walkable. "
     + ROCK_NOTE + "Origin = ground level in the middle between the pillars (opening along the Godot X axis). Single mesh node 'Body'.",
     extra={"collision_boxes": [{"size": [3.8, 6.5, 4.0], "offset": [-4.1, 3.25, 0]}, {"size": [3.8, 6.5, 4.0], "offset": [4.1, 3.25, 0]},
                                {"size": [9.6, 3.4, 3.6], "offset": [0, 7.8, 0]}]})


# ---- run 3: toxic swamp (G) ----------------------------------------------------------------------------------------------
TOX_NOTE = ("The game applies ONE tint key per model to every tinted material: Foliage_* / Glow_Main / Crystal_Main take that key's colour (biomes.gd), Bark / Bark_Pale are "
            "multiplied by the wood tint. ")
spec('mushroom_giant', 'flora', cyl(0.85, 7.0),
     "Giant mushroom tree ~12 m: thick curved pale stalk (Bark_Pale, flared buttress base, pleated skirt ring at ~7 m), huge scalloped cap r ~5.4 m (Foliage_B) with 14 pale spots (Bark_Pale), "
     "glowing pleated gills under the cap (Glow_Main) and 4 baby mushrooms at the foot. You can walk under the cap (underside at ~8 m); collision = stalk only. " + TOX_NOTE
     + "Origin = ground contact at the stalk base. Single mesh node 'Body'.")
spec('mushroom_small', 'flora', NONE,
     "Cluster of 5 small mushrooms ~1.1 m (Glow_Main caps in dome / flat / cone shapes, Bark_Pale stems + gills) on 4 mossy lumps (Foliage_B). " + TOX_NOTE + "Origin = ground contact at the centre. Single mesh node 'Body'.")
spec('spore_pod', 'flora', NONE,
     "Bulb plant ~2.4 m: arching stem (Foliage_B), big ribbed pod (Foliage_A) with a glowing upper end (Glow_Main) + 5 sepals (Foliage_B), 5 glowing spore motes above it, a small second pod "
     "and 6 ground leaves (Foliage_A). " + TOX_NOTE + "Origin = ground contact at the stem base (pod leans towards +X Blender = +X Godot). Single mesh node 'Body'.")
spec('tentacle_plant', 'flora', NONE,
     "Alien tentacle plant ~2.6 m high / 3 m wide: lumpy fleshy base + 6 thick curving tentacles (Foliage_B, differently bent / long) with glowing tips and small glowing sucker nubs (Glow_Main). "
     + TOX_NOTE + "Origin = ground contact at the base centre. Single mesh node 'Body'.")
spec('toxic_crystal', 'resource', sph(1.0, 0.9),
     "Toxic crystal cluster ~2 m: 7 hexagonal / pentagonal translucent crystals (Crystal_Main, flat shaded) each with a glowing core (Glow_Main) inside, a glowing slime puddle (Glow_Main) and "
     "3 dark rubble stones (Rock_B) at the foot. " + TOX_NOTE + "Origin = ground contact at the centre. Single mesh node 'Body'.")


# ---- run 3: frozen (E) ---------------------------------------------------------------------------------------------------
ICE_NOTE = ("Tint keys in biomes.gd: pine trees -> 'pine' (Foliage_*), ice -> 'ice' (Crystal_Main keeps alpha 0.7), shrub -> 'frost', rocks -> 'rock'. Snow is a fixed white. ")
spec('tree_pine_snow', 'flora', cyl(0.5, 5.0),
     "Snow-laden conifer ~10.4 m: slim trunk (Bark) + 5 steep drooping skirt tiers (alternating Foliage_A / Foliage_B, scalloped rims, r 3.1 -> 1.1 m) each with a lumpy Snow cap on its upper part, "
     "pointed leader spike with a snow tip. Collision = trunk. " + ICE_NOTE + "Origin = ground contact at the trunk base. Single mesh node 'Body'.")
spec('tree_pine_snow_b', 'flora', cyl(0.45, 3.0),
     "Smaller, squatter fir ~6.1 m: slightly leaning trunk (Bark), 4 star-shaped tiers (r 2.05 -> 1.0 m, Foliage_B / Foliage_A) with thick Snow caps, snow-tipped spike and a snow drift at the foot. "
     "Collision = trunk. " + ICE_NOTE + "Origin = ground contact at the trunk base. Single mesh node 'Body'.")
spec('ice_spire', 'rock', cyl(1.2, 4.5),
     "Cluster of 8 translucent ice crystal spires, tallest ~5 m (flat shaded 5/6-sided prisms with long pointed tips, Crystal_Main alpha 0.7, game recolours with the 'ice' tint) on a Snow drift base. "
     + ICE_NOTE + "Origin = ground contact at the centre. Single mesh node 'Body'.")
spec('ice_boulder', 'rock', sph(1.0, 0.8),
     "Faceted translucent ice rock ~2.2 x 2 x 1.8 m (Crystal_Main, flat shaded, denser inner core shell, a smaller fused boulder, 3 crystal shards on top, Snow patches around the foot). "
     + ICE_NOTE + "Origin = ground contact at the centre. Single mesh node 'Body'.")
spec('frost_shrub', 'flora', NONE,
     "Frosted shrub ~1 m: 30 upright pointed blades (Foliage_B) with Snow-white tips, 5 leafy lumps (Foliage_B) capped with Snow and a Snow mound at the base. " + ICE_NOTE
     + "Origin = ground contact at the centre. Single mesh node 'Body'.")
spec('snow_rock', 'rock', sph(1.1, 0.85),
     "Tall angular rock ~2 m (Rock_A with Rock_B patches, flat shaded) plus a leaning companion stone, both capped with thick lumpy Snow, snow drifts piled at the foot. " + ROCK_NOTE
     + "Snow is a fixed white. Origin = ground contact at the centre. Single mesh node 'Body'.")


# ---- run 3: volcanic (F) -------------------------------------------------------------------------------------------------
VOLC_NOTE = ("Fixed colours: Obsidian (near-black glossy, metallic 0.15 rough 0.1) and Glow_Lava (orange emission 4.0; models.gd exempts it from the Glow* tint). Rock_A / Rock_B and Bark are tinted by the game "
              "(volcanic rock tint, wood tint = very dark). ")
spec('obsidian_spire', 'rock', cyl(1.2, 5.0),
     "Cluster of 8 glassy black blade shards, tallest ~6.1 m (flat shaded, flattened 4-sided prisms with sharp tips, two broken slanted tops, Obsidian) on dark rubble (Rock_B) with 3 tiny Glow_Lava glints "
     "at the foot. " + VOLC_NOTE + "Origin = ground contact at the centre. Single mesh node 'Body'.")
spec('lava_rock', 'rock', sph(1.1, 0.9),
     "Cracked dark boulder ~2.2 x 1.9 x 2 m: 8+ convex crust plates (Rock_B / Rock_A alternating, flat shaded) separated by ~13 cm gaps through which the Glow_Lava core glows; 3 loose chips at the foot. "
     + VOLC_NOTE + "Origin = ground contact at the centre. Single mesh node 'Body'.")
spec('charred_tree', 'flora', cyl(0.4, 4.0),
     "Burnt trunk ~4.7 m: ribbed split trunk with root flare (Bark only - the volcanic wood tint x1.8 makes it near black), splintered broken top with a glowing core, 4 snapped limbs + a twig, "
     "8 ember spots on the bark and a glowing ember mound at the foot (Glow_Lava). " + VOLC_NOTE + "Origin = ground contact at the trunk base. Single mesh node 'Body'.")
spec('vent_cone', 'rock', cyl(1.8, 2.5),
     "Small volcanic cone ~3 m high / ~5 m wide at the foot (Rock_B with two lighter Rock_A bands, 6 ridges): crater with a glowing lava lake (Glow_Lava) 0.5 m below the rim, 4 lava tongues running down the flanks, "
     "a crown of 6 jagged rim stones and 4 ash blocks around the foot. Collision = cone body (cylinder r 1.8, h 2.5). " + VOLC_NOTE + "Origin = ground contact at the centre. Single mesh node 'Body'.")


# ---- run 3: irradiated (I) -----------------------------------------------------------------------------------------------
RAD_NOTE = ("The game applies ONE tint key per model ('glow_a' / 'glow_b' in biomes.gd): Crystal_Main takes it as albedo (alpha 0.7 kept), Glow_Main as emission. Rock_B / Bark are tinted by the rock / wood tint. ")
spec('crystal_cluster_a', 'rock', cyl(1.2, 2.8),
     "Radial cluster of 8 glowing crystal prisms, tallest ~3 m (flat shaded; translucent Crystal_Main shell with a smaller Glow_Main crystal buried inside each, 5/6 sides, one broken slanted tip) on 3 dark "
     "rubble stones (Rock_B). " + RAD_NOTE + "Origin = ground contact at the centre. Single mesh node 'Body'.")
spec('crystal_cluster_b', 'rock', cyl(1.2, 1.2),
     "Wide low bed of 15 small glowing crystals (0.4 - 1.25 m, spread over ~2.8 m, Crystal_Main shell + Glow_Main core each) on a flat rubble pad (Rock_B). " + RAD_NOTE
     + "Origin = ground contact at the centre. Single mesh node 'Body'.")
spec('crystal_cluster_c', 'rock', cyl(1.1, 4.4),
     "Tall slender crystal towers, tallest ~4.6 m, 7 prisms (Crystal_Main shell + Glow_Main core, one broken slanted tip) with rubble (Rock_B) at the foot. " + RAD_NOTE
     + "Origin = ground contact at the centre. Single mesh node 'Body'.")
spec('rad_fungus', 'flora', NONE,
     "Glowing shelf fungus ~0.85 m: short gnarled splintered stump (Bark) with 7 flattened bracket shelves spiralling up it (Glow_Main) and 5 glowing buds at the foot. " + RAD_NOTE
     + "Origin = ground contact at the stump base. Single mesh node 'Body'.")


# ---- run 3: dead moon (H) ------------------------------------------------------------------------------------------------
MOON_NOTE = ("Rock_A is recoloured by the game with the planet's rock tint; the model is completely flat shaded with crisp facets (no smoothing). ")
spec('moon_rock_a', 'rock', sph(1.0, 0.7),
     "Sharp angular regolith rock ~2.6 x 1.5 x 1.9 m (convex faceted hull with chipped edges + a smaller fragment on each side). " + MOON_NOTE + "Origin = ground contact near the main rock. Single mesh node 'Body'.")
spec('moon_rock_b', 'rock', auto_box(0.4),
     "Flat shard-like rock ~2.9 x 1.5 x 2.7 m: a big leaning wedge plate, a second plate leaning against it, a flat shard and a splinter (all crisp facets). Collision = box around everything. "
     + MOON_NOTE + "Origin = ground contact near the big plate. Single mesh node 'Body'.")
spec('probe_wreck', 'structure', auto_box(1.2, cap=1.7),
     "Old crashed probe ~3.3 m (mast) / ~5 m wide: tilted boxy bus (Metal, scorched lower half + panels in Hull_Dark), torn parabolic dish leaning on the ground (dented, 2 of 3 feed struts intact), "
     "bent mast with cross bar, solar array with a hinged bent second panel (Hull_Dark cells, Metal ribs), a fuel tank sphere, scattered plates and one tiny red blink lamp (Emissive_Light, red in this GLB). "
     "NOT tinted (only Metal / Hull_Dark / Emissive_Light). Collision box covers the bus + dish area only (cap 1.7 m high), not the mast / panels. Origin = ground contact below the bus. Single mesh node 'Body'.",
     overrides={'Emissive_Light': dict(color='#FFB0A0', rough=0.4, emit='#FF2A1A', emit_strength=3.0)})


def _fmt_size(sz):
    return "%.1f x %.1f x %.1f" % (sz[0], sz[1], sz[2])


def _update_progress(name, entry, status):
    line = "- %s | %d | %s | %s" % (name, entry['tris'], _fmt_size(entry['size']), status)
    lines = open(PROGRESS, encoding='utf-8').read().split('\n') if os.path.exists(PROGRESS) else []
    out, done = [], False
    for ln in lines:
        if ln.startswith('- %s |' % name):
            out.append(line)
            done = True
        else:
            out.append(ln)
    if not done:
        while out and out[-1] == '':
            out.pop()
        if not any('Brief 2' in x for x in out):
            out += ['', 'Brief 2 (flora, rocks, resource nodes, biome props): scripts blender/model_flora_*.py, model_rocks.py ... (several models per script), export via blender/export_nature.py; helpers in blender/lib_nature.py (loaded by lib.py).',
                    'Tint contract (shared materials created once by nature_palette()): Foliage_A/B/Flower, Crystal_Main, Glow_Main, Rock_A/B, Bark(_Pale) are recoloured by the game; Snow, Obsidian, Emissive_Lava, Res_* keep their colour.', '']
        out.append(line)
    out.append('')
    open(PROGRESS, 'w', encoding='utf-8').write('\n'.join(out).rstrip('\n') + '\n')


def _check(name):
    c = bpy.data.collections[name]
    probs = []
    meshes = [o for o in c.all_objects if o.type == 'MESH']
    for o in c.all_objects:
        if '.' in o.name or ' ' in o.name:
            probs.append('bad name ' + o.name)
        r, s_ = o.rotation_euler, o.scale
        if max(abs(r.x), abs(r.y), abs(r.z)) > 1e-6 or max(abs(s_.x - 1), abs(s_.y - 1), abs(s_.z - 1)) > 1e-6:
            probs.append('non-identity rotation/scale on ' + o.name)
        if o.type == 'MESH':
            if o.modifiers:
                probs.append('modifiers left on ' + o.name)
            if not o.material_slots:
                probs.append('no material on ' + o.name)
            bm = bmesh.new()
            bm.from_mesh(o.data)
            if any(f.calc_area() < 1e-9 for f in bm.faces):
                probs.append('zero-area faces in ' + o.name)
            if any(not v.link_faces for v in bm.verts):
                probs.append('loose verts in ' + o.name)
            bm.free()
    if not meshes:
        probs.append('no mesh')
    return probs


def run(names, status=None, save=True):
    for n in names:
        sp = SPECS[n]
        unpark(n)
        coll = bpy.data.collections[n]
        meshes = [o for o in coll.all_objects if o.type == 'MESH']
        renamed = []
        try:
            if sp.get('root_name', 'Body') and len(meshes) == 1:
                ob = meshes[0]
                ob.name = sp.get('root_name', 'Body')
                ob.data.name = n
                renamed.append(ob)
                if ob.name != sp.get('root_name', 'Body'):
                    raise RuntimeError('object name clash: got %r - another object already uses the name' % ob.name)
            for k, v in sp.get('overrides', {}).items():
                mat(k, **v)
            probs = _check(n)
            if probs:
                print('PROBLEMS in', n, probs)
            col = sp['collision']
            if callable(col):
                col = col(n)
            ent = export_model(n, category=sp['category'], collision=col, notes=sp['notes'], extra=sp.get('extra'))
            _update_progress(n, ent, status or sp.get('status') or 'exported; mesh node Body; origin at ground contact')
        finally:
            if sp.get('overrides'):
                nature_palette()
                palette()
            for ob in renamed:
                ob.name = 'Body'
            park(n)
    if save:
        bpy.ops.wm.save_mainfile()
        print('saved', bpy.data.filepath)
