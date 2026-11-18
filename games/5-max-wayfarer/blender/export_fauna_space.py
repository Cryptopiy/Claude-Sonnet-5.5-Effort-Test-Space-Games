"""Export specs + driver for brief 3 (creatures + space objects).  Usage inside Blender:
    exec(compile(open(r'...\blender\export_fauna_space.py', encoding='utf-8').read(), 'efs', 'exec'));  run(['space_station'])
(reuses export_nature.run: unpark -> export_model -> park -> PROGRESS.md line -> save).  All models here keep their node names (root_name=None)."""
exec(compile(open(r'W:\YouTube\Sonnet 5.5 Effort Test\5. Max Effort\blender\export_nature.py', encoding='utf-8').read(), 'en', 'exec'))

spec('space_station', 'space', NONE,
     "Orbital station, real size: ring outer diameter 150 m (inner 114 m), whole model ~150 x 180 x 130 m (game scales x2.4). Node tree: Station (root mesh: hub, solar wings, antennas, "
     "radiator fins, docking pier + bay) > Ring (rotating ring + hub collar + 4 spokes + 4 docking ports + hull plates; ORIGIN EXACTLY AT THE HUB CENTRE (0,0,0), rotation 0, scale 1; spin it around "
     "its local Y axis (= Blender Z) - the spokes and collar belong to the Ring mesh on purpose so they turn with it) and Marker_Dock (empty at the docking bay mouth, 106.6 m from the hub "
     "along -Z Godot, 33 m 'up' in Godot Y; +Y Blender / -Z Godot = out of the bay, bay opening 21 m wide x 15 m high, 36 m deep). The docking pier sits above the ring plane (Godot +Y side) so the ring never "
     "sweeps through it. Materials (fixed colours, nothing tinted): Hull_Paint (white), Hull_Accent (orange), Hull_Dark, Metal, Solar_Cell / Solar_Grid, Emissive_Window (warm window strips "
     "on the ring), Emissive_Light (cyan guide lights in the bay + port lights), Emissive_Amber, Emissive_Screen, Emissive_NavRed / Emissive_NavGreen (mouth corner lights). Origin = hub centre.",
     root_name=None, status='exported; nodes Station > Ring (pivot at hub centre, spins about local Y) + Marker_Dock (bay mouth, -Z Godot = out); no collision')


CR_NOTE = ("Fixed colours (the game does not tint creatures; Fur_* / Skin_* / Shell_* / Horn / Hoof / Eye_* keep their colour). Front = -Z Godot (+Y Blender). Every joint is its own mesh node whose ORIGIN IS ON THE JOINT "
           "(rotation 0, scale 1, rest pose = neutral standing / flying), children of the root mesh. Joint names are exactly what scripts/world/fauna.gd looks up. ")
spec('creature_grazer', 'creature', auto_box(0.25, cap=1.3),
     "Chunky four-legged herbivore ~2.3 m long, 1.45 m tall (horn tips): barrel body with shoulder hump, tabby teal stripes on the tan back, cream belly + socks, dark hooves, big head with curved banded horns, ears, "
     "teal crest, tufted teal tail. Nodes: Body (root) > Head (pivot at the neck (0,-0.71,0.93) Godot), Tail (pivot at the tail root, swings about Y), Leg_FL / Leg_FR / Leg_BL / Leg_BR (pivots at the hips/shoulders, 0.65 m above "
     "the ground, whole leg + hoof as one mesh, swing about X). L = -X. " + CR_NOTE + "Materials: Fur_Tan, Fur_Cream, Fur_Teal, Horn, Hoof, Skin_Nose, Eye_Dark, Eye_White. Origin = ground contact below the body centre.",
     root_name=None, status='exported; nodes Body > Head, Tail, Leg_FL/FR/BL/BR (hip pivots); ~2.3 m long, 1.45 m tall; box collision')
spec('creature_flyer', 'creature', NONE,
     "Pterosaur / manta glider, wingspan 2.7 m: flat blue body, big eyes, yellow beak, swept-back orange head crest, long tail with an orange diamond fin and a small vertical fin, two broad cambered wings "
     "(blue top, peach underside, orange leading edge + tips, scalloped trailing edge, slight droop). Nodes: Body (root) > Wing_L (-X) / Wing_R (+X) (pivot at the wing root on the body side (+-0.22,-0.04,0.03) Godot; "
     "the game flaps them by rotation.z = +-flap, wings extend outwards along +-X), Tail (optional, pivot at the tail root). " + CR_NOTE
     + "Materials: Skin_Back, Skin_Belly, Skin_Wing, Skin_WingUnder, Skin_Crest, Skin_Beak, Eye_Dark, Eye_White. Origin = body centre (gliders: no collision).",
     root_name=None, status='exported; nodes Body > Wing_L/Wing_R (root pivots, flap about Z Godot), Tail; wingspan 2.7 m; no collision')
spec('creature_floater', 'creature', NONE,
     "Jellyfish-like sky drifter: translucent lavender bell diameter ~3.2 m (Skin_Bell alpha 0.58, scalloped ruffled rim) with a glowing core + 8 radial glow canals (Glow_Main), 3 frilly pink oral arms (Skin_Arm, ~2.1 m) "
     "and 8 violet tentacles (Skin_Tentacle, 3.4 / 4.1 m long, glowing bands + tips + rim knobs in Glow_Main). Nodes: Bell (root mesh, pivot = bell centre = model origin; the game pulses its scale) > Tentacle_01 ... "
     "Tentacle_08 (children of Bell, pivot at the rim attachment point 1.4 m from the axis, 0.14 m below the bell centre; hang ~4 m down, the game sways them about X/Z). " + CR_NOTE
     + "Glow_Main default colour baked into this GLB = cyan (#7FF2FF, emission 3.0); the game may tint it. Origin = bell centre; bell top +1.16 m, tentacle tips -4.3 m.",
     root_name=None, overrides={'Glow_Main': dict(color='#2B3238', rough=0.4, emit='#7FF2FF', emit_strength=3.0)},
     status='exported; nodes Bell > Tentacle_01..08 (rim pivots); bell dia 3.3 m, tentacles up to 4.1 m; translucent Skin_Bell; no collision')
spec('creature_crawler', 'creature', auto_box(0.1),
     "Beetle / crab ~0.95 m wide: rust-red domed carapace (Shell_Main, dark rim Shell_Dark, light rear plate Shell_Light) with 8 glowing spots (Glow_Main), dark head shield, two eye stalks with big eyes, two small pincers, "
     "six legs. Nodes: Body (root) > Leg_1 ... Leg_6 (pivots at the hips 0.19 m above the ground; 1/3/5 = left (-X) front to back, 2/4/6 = right; swing about X). " + CR_NOTE
     + "Glow_Main default colour baked into this GLB = aqua green (#46FFC8, emission 3.0); the game may tint it. Materials: Shell_Main/Dark/Light, Skin_Under, Eye_Dark, Eye_White. Origin = ground contact below the body centre.",
     root_name=None, overrides={'Glow_Main': dict(color='#1E3A33', rough=0.4, emit='#46FFC8', emit_strength=3.0)},
     status='exported; nodes Body > Leg_1..Leg_6 (hip pivots, 1/3/5 left); 0.95 m wide; box collision')


AST_NOTE = ("Real size (game scales x0.35 - 1.9 and spins them). Flat shaded Rock_A (main) + Rock_B (crater floors / noise patches), both recoloured by the game's rock tint. Cube-sphere base displaced by noise + craters, "
            "plus 3 half-buried chunks. Origin = centre of the rock. Single mesh node 'Body'. No collision (the game handles proximity itself).")
spec('asteroid_a', 'space', NONE, "Elongated bent potato ~33 x 17 x 15 m: long ridge along the top, a big gouge crater and 6 smaller craters, slight neck pinch in the middle. " + AST_NOTE, status='exported; elongated ~33 x 15 x 17 m; Rock_A/Rock_B; no collision')
spec('asteroid_b', 'space', NONE, "Round pitted rock ~29 m: 15 craters of various sizes (two big ones) with raised rims. " + AST_NOTE, status='exported; round pitted ~29 m; Rock_A/Rock_B; no collision')
spec('asteroid_c', 'space', NONE, "Two-lobed rock ~32 x 21 x 22 m (lobes 22 m and 18 m) with a deep crack ring between the lobes, three flat fracture facets and 5 craters. " + AST_NOTE, status='exported; two lobes + crack ~32 x 22 x 21 m; Rock_A/Rock_B; no collision')
spec('satellite', 'space', NONE,
     "Derelict comms satellite ~8.5 m wide x 7 m tall (incl. whip antenna): gold-foil bus 1.6 x 1.6 x 1.7 m with white top module + dark thruster module + scorch marks, big dented dish (2.6 m) on a mast with feed arms, small side dish, "
     "whip antennas (one bent), two solar wings (left: flat + bent panel, right: flat + torn stub), loose cable, thruster nozzle, one dim red nav lamp (Emissive_NavRed). Materials: Foil_Gold, Scorch, Hull_Paint, Hull_Dark, Metal, "
     "Solar_Cell, Solar_Grid, Emissive_NavRed (fixed colours, nothing tinted). Origin = centre of the bus (the game spins it about a random axis). Single mesh node 'Body'. No collision.",
     status='exported; ~8.5 m wide derelict comms sat (dish, bent + torn solar wings, scorched foil); no collision')
