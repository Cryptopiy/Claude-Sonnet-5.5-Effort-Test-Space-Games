import bpy, bmesh, math, os, random
OUT = r"W:\YouTube\Sonnet 5.5 Effort Test\2. Medium Effort\assets\models"
os.makedirs(OUT, exist_ok=True)

for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
for m in list(bpy.data.meshes): bpy.data.meshes.remove(m)
for m in list(bpy.data.materials): bpy.data.materials.remove(m)

def mat(name, col, metal=0.0, rough=0.5, emit=None, estr=3.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = estr
    return m

def finish(o, m, smooth=True):
    o.data.materials.append(m)
    if smooth:
        for p in o.data.polygons: p.use_smooth = True
    return o

def cyl(name, r, h, loc, m, rot=(0,0,0), verts=16, r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=(r if r2 is None else r2), depth=h, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; return finish(o, m)

def sph(name, r, loc, m, scale=(1,1,1), seg=16, rot=(0,0,0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg//2, radius=r, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m)

def box(name, size, loc, m, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, m, smooth=False)

def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.object; o.name = name
    return o

def export(o, fname):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True); bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, fname), use_selection=True, export_format='GLB', export_apply=True, export_yup=True)
    global _x
    o.location.x = _x; _x += 14
    o.name = fname[:-4]

_x = 0
def bmesh_obj(name, bm, m):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    me.materials.append(m)
    return o

# ============ SHIP (nose +Y) ============
def make_ship():
    hull = mat("ShipHull", (0.72,0.74,0.78), 0.25, 0.35)
    dark = mat("ShipDark", (0.10,0.11,0.13), 0.2, 0.5)
    accent = mat("ShipAccent", (0.95,0.38,0.05), 0.15, 0.4)
    glass = mat("ShipGlass", (0.05,0.25,0.4), 0.0, 0.05, emit=(0.1,0.5,0.9), estr=0.6)
    glow = mat("ShipEngine", (0.2,0.6,1.0), 0, 0.3, emit=(0.3,0.7,1.0), estr=2.0)
    parts = []
    parts.append(sph("Fus", 1.0, (0,0,0), hull, scale=(0.9,3.4,0.6), seg=24))
    parts.append(cyl("Nose", 0.45, 2.2, (0,3.3,0), hull, rot=(-math.pi/2,0,0), r2=0.06))
    parts.append(sph("Canopy", 0.7, (0,1.1,0.38), glass, scale=(0.85,1.5,0.7), seg=20))
    for s in (-1,1):
        bm = bmesh.new()
        pts = [(0.6*s,1.0,0.0),(4.6*s,-2.0,-0.1),(4.6*s,-2.9,-0.1),(0.8*s,-2.4,0.0)]
        top=[bm.verts.new((x,y,z+0.12)) for x,y,z in pts]; bot=[bm.verts.new((x,y,z-0.12)) for x,y,z in pts]
        bm.faces.new(top); bm.faces.new(bot[::-1])
        for i in range(4):
            j=(i+1)%4
            bm.faces.new([top[i],bot[i],bot[j],top[j]])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        w = bmesh_obj("Wing", bm, hull)
        parts.append(w)
        parts.append(box("WingStripe",(0.5,0.9,0.05),(3.4*s,-2.0,0.13),accent,rot=(0,0,0.35*s)))
        parts.append(cyl("Pod",0.3,2.4,(4.4*s,-2.2,-0.05),dark,rot=(-math.pi/2,0,0),r2=0.22))
        parts.append(cyl("PodGlow",0.2,0.15,(4.4*s,-3.45,-0.05),glow,rot=(-math.pi/2,0,0)))
        parts.append(box("Fin",(0.08,1.4,1.1),(1.1*s,-2.4,0.6),accent,rot=(0.0,0.3*s,0)))
        parts.append(cyl("Leg",0.07,1.2,(1.3*s,-0.6,-0.9),dark,rot=(0,0.25*s,0)))
        parts.append(cyl("Foot",0.28,0.08,(1.45*s,-0.6,-1.52),dark))
    parts.append(cyl("LegF",0.07,1.2,(0,2.0,-0.8),dark,rot=(0.15,0,0)))
    parts.append(cyl("FootF",0.25,0.08,(0,2.1,-1.4),dark))
    for x in (-0.55,0.55):
        parts.append(cyl("Eng",0.38,1.0,(x,-3.4,0),dark,rot=(-math.pi/2,0,0),r2=0.3))
        parts.append(cyl("EngGlow",0.28,0.12,(x,-3.95,0),glow,rot=(-math.pi/2,0,0)))
    parts.append(box("Dorsal",(0.5,1.6,0.25),(0,-0.8,0.55),dark))
    return join(parts, "Ship")

# ============ ASTRONAUT (feet z=0, facing +Y) ============
def make_astro():
    suit = mat("Suit",(0.85,0.87,0.9),0.1,0.5)
    orange = mat("SuitOrange",(0.95,0.4,0.05),0.1,0.5)
    visor = mat("Visor",(0.9,0.6,0.1),0.3,0.15,emit=(0.8,0.5,0.1),estr=0.4)
    dark = mat("SuitDark",(0.1,0.1,0.12),0.4,0.6)
    p=[]
    p.append(sph("Torso",0.28,(0,0,1.15),suit,scale=(1.15,0.8,1.3)))
    p.append(sph("Helmet",0.22,(0,0.02,1.62),suit))
    p.append(sph("Visor",0.17,(0,0.11,1.63),visor,scale=(1.1,0.7,0.9)))
    p.append(box("Pack",(0.45,0.22,0.6),(0,-0.26,1.2),dark))
    p.append(cyl("Tank1",0.07,0.55,(-0.13,-0.4,1.2),orange,verts=10))
    p.append(cyl("Tank2",0.07,0.55,(0.13,-0.4,1.2),orange,verts=10))
    p.append(cyl("Jet1",0.07,0.1,(-0.13,-0.4,0.9),dark,verts=10))
    p.append(cyl("Jet2",0.07,0.1,(0.13,-0.4,0.9),dark,verts=10))
    for s in (-1,1):
        p.append(cyl("Leg",0.1,0.8,(0.12*s,0,0.45),suit,r2=0.08))
        p.append(box("Boot",(0.16,0.3,0.14),(0.12*s,0.05,0.07),orange))
        p.append(cyl("Arm",0.07,0.6,(0.36*s,0,1.2),suit,rot=(0,0.25*s,0),r2=0.06))
        p.append(sph("Hand",0.07,(0.44*s,0.0,0.9),dark))
    p.append(box("Belt",(0.5,0.3,0.08),(0,0,0.85),orange))
    return join(p,"Astronaut")

def make_tree_lush():
    bark=mat("Bark",(0.28,0.17,0.09),0,0.9); leaf=mat("Leaf",(0.12,0.5,0.15),0,0.7)
    p=[cyl("Trunk",0.25,3.0,(0,0,1.5),bark,r2=0.15,verts=10)]
    for z,r in [(3.4,1.5),(4.4,1.1),(5.2,0.7)]:
        p.append(sph("Crown",r,(0,0,z),leaf,scale=(1,1,0.8),seg=12))
    return join(p,"TreeLush")
def make_tree_alien():
    bark=mat("AlienStem",(0.3,0.1,0.4),0,0.5); leaf=mat("AlienLeaf",(0.2,0.9,0.8),0,0.3,emit=(0.1,0.8,0.7),estr=1.5)
    p=[cyl("Stem",0.2,4.0,(0,0,2.0),bark,r2=0.08,verts=8)]
    for i in range(5):
        a=i*2*math.pi/5
        p.append(cyl("Frond",0.05,2.4,(math.cos(a)*0.9,math.sin(a)*0.9,4.2),leaf,rot=(math.sin(a)*0.9,-math.cos(a)*0.9,0),r2=0.02,verts=6))
        p.append(sph("Bulb",0.28,(math.cos(a)*1.6,math.sin(a)*1.6,3.6),leaf,seg=8))
    p.append(sph("TopBulb",0.45,(0,0,4.1),leaf,seg=10))
    return join(p,"TreeAlien")
def make_cactus():
    g=mat("Cactus",(0.55,0.62,0.25),0,0.7); f=mat("CactusFlower",(0.95,0.3,0.5),0,0.5)
    p=[cyl("Body",0.35,3.0,(0,0,1.5),g,r2=0.3,verts=10),sph("Top",0.3,(0,0,3.0),g,seg=10)]
    p.append(cyl("Arm1",0.18,1.2,(0.7,0,1.6),g,rot=(0,math.pi/2,0),verts=8)); p.append(cyl("Arm1u",0.18,1.0,(1.25,0,2.1),g,verts=8))
    p.append(cyl("Arm2",0.15,1.0,(-0.6,0,2.0),g,rot=(0,math.pi/2,0),verts=8)); p.append(cyl("Arm2u",0.15,0.8,(-1.05,0,2.4),g,verts=8))
    p.append(sph("Fl",0.15,(0,0,3.3),f,seg=8))
    return join(p,"Cactus")
def make_ice_spike():
    ice=mat("Ice",(0.7,0.9,1.0),0.0,0.08,emit=(0.3,0.6,0.9),estr=0.5)
    p=[]
    for x,y,h,r,t in [(0,0,5,0.7,0),(0.8,0.3,3.2,0.5,0.2),(-0.7,0.4,3.8,0.5,-0.25),(0.2,-0.8,2.4,0.4,0.3),(-0.4,-0.7,2.0,0.35,-0.3)]:
        p.append(cyl("Spike",r,h,(x,y,h/2-0.2),ice,rot=(t,-t*0.6,0),r2=0.0,verts=6))
    return join(p,"IceSpike")
def make_crystal(name,col,emitcol):
    c=mat(name+"M",col,0.1,0.15,emit=emitcol,estr=3)
    p=[]
    for x,y,h,r,tx,ty in [(0,0,3.5,0.5,0,0),(0.6,0.2,2.2,0.35,0.3,0.2),(-0.5,0.3,2.6,0.4,-0.3,0.1),(0.1,-0.6,1.8,0.3,0.1,-0.35),(-0.3,-0.4,1.4,0.25,-0.2,-0.3)]:
        p.append(cyl("Cr",r,h,(x,y,h/2-0.1),c,rot=(tx,ty,0),r2=0.04,verts=6))
    return join(p,name)
def make_rock(name,col,seed,sc=(1,1,0.7)):
    random.seed(seed)
    bm=bmesh.new(); bmesh.ops.create_icosphere(bm,subdivisions=2,radius=1.0)
    for v in bm.verts:
        v.co*=0.75+random.random()*0.5
        v.co.x*=sc[0];v.co.y*=sc[1];v.co.z*=sc[2]
        v.co.z+=0.3
    m=mat(name+"M",col,0.0,0.95)
    return bmesh_obj(name,bm,m)
def make_mushroom():
    stem=mat("MStem",(0.9,0.85,0.7),0,0.7); cap=mat("MCap",(0.85,0.15,0.55),0,0.4,emit=(0.8,0.1,0.5),estr=0.8)
    p=[cyl("Stem",0.3,2.5,(0,0,1.25),stem,r2=0.2,verts=10),sph("Cap",1.5,(0,0,2.6),cap,scale=(1,1,0.55),seg=16)]
    return join(p,"Mushroom")
def make_dead_tree():
    b=mat("Dead",(0.15,0.12,0.1),0,0.95)
    p=[cyl("T",0.22,3.5,(0,0,1.75),b,r2=0.08,verts=7)]
    for a,z in [(0,2.2),(2.1,2.8),(4.2,1.6)]:
        p.append(cyl("B",0.07,1.6,(math.cos(a)*0.6,math.sin(a)*0.6,z),b,rot=(math.sin(a)*0.9,-math.cos(a)*0.9,0),r2=0.02,verts=6))
    return join(p,"DeadTree")
def make_pad():
    base=mat("PadBase",(0.25,0.27,0.3),0.15,0.6); lt=mat("PadLight",(1,0.7,0.2),0,0.3,emit=(1,0.6,0.1),estr=5)
    p=[cyl("Disc",6.0,0.5,(0,0,0.25),base,verts=32)]
    p.append(cyl("Ring",5.0,0.55,(0,0,0.27),lt,verts=32))
    p.append(cyl("Inner",4.7,0.6,(0,0,0.27),base,verts=32))
    for i in range(8):
        a=i*math.pi/4
        p.append(cyl("L",0.2,0.4,(math.cos(a)*5.4,math.sin(a)*5.4,0.6),lt,verts=8))
    return join(p,"LandingPad")
def make_outpost():
    wall=mat("OutWall",(0.78,0.8,0.82),0.3,0.5); roof=mat("OutRoof",(0.3,0.33,0.38),0.15,0.5); win=mat("OutWin",(1,0.8,0.4),0,0.2,emit=(1,0.75,0.3),estr=3)
    p=[sph("Dome",4.0,(0,0,0),wall,scale=(1,1,0.6),seg=24)]
    p.append(cyl("Base",4.2,0.6,(0,0,0.3),roof,verts=24))
    p.append(box("Door",(1.4,0.3,2.0),(0,3.7,1.0),roof))
    for i in range(6):
        a=i*math.pi/3+0.3
        p.append(box("Win",(0.9,0.2,0.6),(math.cos(a)*3.2,math.sin(a)*3.2,1.8),win,rot=(0,0,a-math.pi/2)))
    p.append(cyl("Mast",0.1,5.0,(2,-2,4),roof,verts=6))
    p.append(sph("Beacon",0.3,(2,-2,6.6),win,seg=8))
    p.append(box("Tank",(1.5,1.5,2),(-3.6,-2.4,1),roof))
    return join(p,"Outpost")
def make_beacon():
    m=mat("BeaconM",(0.2,0.2,0.25),0.2,0.5); g=mat("BeaconG",(0.2,1.0,0.5),0,0.2,emit=(0.2,1.0,0.5),estr=6)
    p=[cyl("P",0.25,3.0,(0,0,1.5),m,r2=0.15,verts=8),sph("Orb",0.45,(0,0,3.4),g,seg=12),cyl("Base",0.6,0.2,(0,0,0.1),m,verts=12)]
    return join(p,"Beacon")
def make_resource():
    g=mat("ResM",(1.0,0.75,0.1),0.3,0.3,emit=(1,0.6,0.05),estr=2)
    p=[]
    for x,y,h,r in [(0,0,1.0,0.3),(0.3,0.1,0.7,0.2),(-0.25,0.15,0.6,0.2)]:
        p.append(cyl("R",r,h,(x,y,h/2),g,r2=0.02,verts=5))
    return join(p,"Resource")
def make_grass():
    gm=mat("Grass",(0.35,0.7,0.2),0,0.8)
    p=[]
    for i in range(7):
        a=i*0.9
        p.append(cyl("Bl",0.06,0.9,(math.cos(a)*0.15,math.sin(a)*0.15,0.45),gm,rot=(math.sin(a)*0.3,-math.cos(a)*0.3,0),r2=0.0,verts=4))
    return join(p,"Grass")
def make_lava_spire():
    r=mat("Basalt",(0.08,0.06,0.06),0,0.9); l=mat("LavaVein",(1,0.3,0.03),0,0.4,emit=(1,0.3,0.02),estr=5)
    p=[cyl("Sp",1.0,5,(0,0,2.4),r,r2=0.12,verts=7),cyl("Vein",0.55,3,(0.1,0,1.4),l,r2=0.3,verts=5),sph("Tip",0.2,(0,0,5.0),l,seg=6)]
    return join(p,"LavaSpire")

export(make_ship(),"ship.glb")
export(make_astro(),"astronaut.glb")
export(make_tree_lush(),"tree_lush.glb")
export(make_tree_alien(),"tree_alien.glb")
export(make_cactus(),"cactus.glb")
export(make_ice_spike(),"ice_spike.glb")
export(make_crystal("CrystalBlue",(0.2,0.5,1.0),(0.2,0.5,1.0)),"crystal_blue.glb")
export(make_crystal("CrystalRed",(1.0,0.2,0.2),(1.0,0.15,0.1)),"crystal_red.glb")
export(make_rock("RockGrey",(0.4,0.4,0.42),1),"rock_a.glb")
export(make_rock("RockTall",(0.5,0.35,0.28),7,(0.7,0.7,1.6)),"rock_b.glb")
export(make_mushroom(),"mushroom.glb")
export(make_dead_tree(),"dead_tree.glb")
export(make_pad(),"landing_pad.glb")
export(make_outpost(),"outpost.glb")
export(make_beacon(),"beacon.glb")
export(make_resource(),"resource.glb")
export(make_grass(),"grass.glb")
export(make_lava_spire(),"lava_spire.glb")
print(sorted(os.listdir(OUT)))

bpy.ops.wm.save_mainfile()
