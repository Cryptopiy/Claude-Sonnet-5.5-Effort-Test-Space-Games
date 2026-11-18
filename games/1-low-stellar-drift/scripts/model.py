import bpy, math, random
OUT=r"W:/YouTube/Sonnet 5.5 Effort Test/1. Low Effort/assets/models/"
for o in list(bpy.data.objects): bpy.data.objects.remove(o)
def mat(name,col,metal=0.0,rough=0.5,emit=None):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True
    b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=col
    b.inputs["Metallic"].default_value=metal
    b.inputs["Roughness"].default_value=rough
    if emit:
        b.inputs["Emission Color"].default_value=emit
        b.inputs["Emission Strength"].default_value=3.0
    return m
parts=[]
def add(kind,loc=(0,0,0),scale=(1,1,1),rot=(0,0,0),m=None,**kw):
    f=getattr(bpy.ops.mesh,"primitive_%s_add"%kind)
    f(location=loc,rotation=rot,**kw)
    o=bpy.context.active_object
    o.scale=scale
    bpy.ops.object.transform_apply(scale=True,rotation=True)
    if m: o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    parts.append(o);return o
def export(name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join()
    o=bpy.context.active_object;o.name=name
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.export_scene.gltf(filepath=OUT+name+".glb",use_selection=True,export_format='GLB',export_yup=True)
    o.location=(len(bpy.data.objects)*6,0,0)
    parts.clear()
hull=mat("hull",(0.75,0.77,0.8,1),0.6,0.35)
dark=mat("dark",(0.05,0.05,0.07,1),0.5,0.4)
red=mat("red",(0.8,0.1,0.05,1),0.3,0.4)
glow=mat("glow",(0.2,0.6,1,1),0,0.3,(0.2,0.6,1,1))
glass=mat("glass",(0.1,0.25,0.4,1),0.9,0.1)
# SHIP: nose points -Y in blender => +Z... we use forward = -Z in Godot = +Y in blender (yup export maps Y->-Z)
add("cone",(0,1.6,0),(0.55,0.55,1.8),(-math.pi/2,0,0),hull,vertices=16,radius1=1,radius2=0.05)
add("cylinder",(0,-0.4,0),(0.8,0.8,2.2),(math.pi/2,0,0),hull,vertices=16)
add("uv_sphere",(0,0.7,0.5),(0.5,1.0,0.35),(0,0,0),glass)
for s in(-1,1):
    add("cube",(s*1.7,-0.8,-0.1),(1.6,1.0,0.07),(0,0,s*0.1),hull)
    add("cube",(s*2.9,-1.0,0.2),(0.07,0.7,0.5),(0,0,0),red)
    add("cylinder",(s*0.9,-1.7,-0.1),(0.28,0.28,0.9),(math.pi/2,0,0),dark,vertices=12)
    add("cylinder",(s*0.9,-2.2,-0.1),(0.2,0.2,0.1),(math.pi/2,0,0),glow,vertices=12)
    add("cylinder",(s*1.0,0.2,-0.95),(0.05,0.05,0.5),(0,0,0),dark,vertices=6)
    add("cylinder",(s*1.0,0.2,-1.2),(0.25,0.25,0.05),(0,0,0),dark,vertices=10)
add("cylinder",(0,1.6,-0.95),(0.05,0.05,0.5),(0,0,0),dark,vertices=6)
add("cylinder",(0,1.6,-1.2),(0.25,0.25,0.05),(0,0,0),dark,vertices=10)
export("ship")
# ASTRONAUT
suit=mat("suit",(0.9,0.9,0.92,1),0,0.6); orange=mat("orange",(1,0.45,0.05,1),0,0.5)
visor=mat("visor",(0.9,0.6,0.1,1),0.9,0.1)
add("cube",(0,0,1.0),(0.38,0.22,0.5),(0,0,0),suit)
add("uv_sphere",(0,0,1.65),(0.24,0.24,0.26),(0,0,0),suit)
add("uv_sphere",(0,0.15,1.67),(0.2,0.12,0.15),(0,0,0),visor)
add("cube",(0,-0.3,1.1),(0.3,0.15,0.4),(0,0,0),orange)
for s in(-1,1):
    add("cylinder",(s*0.15,0,0.35),(0.1,0.1,0.35),(0,0,0),suit,vertices=10)
    add("cylinder",(s*0.5,0,1.05),(0.08,0.08,0.4),(0,0,0),suit,vertices=10)
    add("cylinder",(s*0.15,0,0.05),(0.12,0.16,0.05),(0,0,0),orange,vertices=10)
export("astronaut")
# FLORA: tree
bark=mat("bark",(0.35,0.2,0.1,1),0,0.9); leaf=mat("leaf",(0.1,0.6,0.15,1),0,0.7)
add("cylinder",(0,0,1.5),(0.15,0.15,1.5),(0,0,0),bark,vertices=8)
for i,(z,r) in enumerate([(3.0,1.2),(3.7,0.9),(4.3,0.55)]):
    add("cone",(0,0,z),(r,r,0.9),(0,0,0),leaf,vertices=10,radius1=1,radius2=0)
export("tree")
# cactus
cac=mat("cactus",(0.45,0.6,0.2,1),0,0.8)
add("cylinder",(0,0,1.2),(0.28,0.28,1.2),(0,0,0),cac,vertices=10)
add("uv_sphere",(0,0,2.4),(0.28,0.28,0.28),(0,0,0),cac)
add("cylinder",(0.55,0,1.3),(0.18,0.18,0.5),(0,0,0),cac,vertices=8)
add("cylinder",(0.28,0,0.9),(0.4,0.12,0.12),(0,math.pi/2,0),cac,vertices=8)
add("cylinder",(-0.5,0,1.7),(0.15,0.15,0.4),(0,0,0),cac,vertices=8)
add("cylinder",(-0.25,0,1.4),(0.3,0.1,0.1),(0,math.pi/2,0),cac,vertices=8)
export("cactus")
# mushroom
stem=mat("stem",(0.9,0.85,0.7,1),0,0.8); cap=mat("cap",(0.8,0.1,0.6,1),0,0.4,(0.8,0.1,0.6,1))
add("cylinder",(0,0,1.0),(0.25,0.25,1.0),(0,0,0),stem,vertices=10)
add("uv_sphere",(0,0,2.0),(1.1,1.1,0.55),(0,0,0),cap)
export("mushroom")
# rock
rk=mat("rock",(0.45,0.42,0.4,1),0,0.95)
r=add("ico_sphere",(0,0,0.5),(1.0,0.8,0.6),(0.2,0.3,0.5),rk,subdivisions=2)
random.seed(4)
for v in r.data.vertices:
    f=0.75+random.random()*0.5; v.co*=f
add("ico_sphere",(0.9,0.4,0.25),(0.5,0.4,0.3),(0,0,0),rk,subdivisions=1)
export("rock")
# crystal
cr=mat("crystal",(0.3,0.9,1,1),0.2,0.1,(0.3,0.9,1,1))
for i,(x,y,h,t) in enumerate([(0,0,2.4,0),(0.5,0.2,1.5,0.4),(-0.4,0.3,1.2,-0.5),(0.1,-0.5,1.0,0.3)]):
    add("cone",(x,y,h/2),(0.25,0.25,h),(t,t*0.5,0),cr,vertices=6,radius1=1,radius2=0.0)
export("crystal")
# landing pad
metal=mat("padmetal",(0.3,0.3,0.34,1),0.7,0.5); yel=mat("yellow",(0.9,0.75,0.1,1),0,0.5)
add("cylinder",(0,0,0.1),(6,6,0.2),(0,0,0),metal,vertices=32)
add("cylinder",(0,0,0.21),(5,5,0.02),(0,0,0),yel,vertices=32)
add("cylinder",(0,0,0.23),(4.6,4.6,0.02),(0,0,0),metal,vertices=32)
for a in range(8):
    t=a*math.pi/4
    add("cube",(5.6*math.cos(t),5.6*math.sin(t),0.35),(0.15,0.15,0.15),(0,0,0),glow)
export("landing_pad")
# outpost
wall=mat("wall",(0.7,0.72,0.75,1),0.3,0.6)
add("cylinder",(0,0,1.2),(3,3,2.4),(0,0,0),wall,vertices=20)
add("uv_sphere",(0,0,2.4),(3,3,1.2),(0,0,0),wall,segments=20,ring_count=8)
add("cube",(3.2,0,0.9),(1.2,1.0,0.9),(0,0,0),wall)
add("cylinder",(-1,-1,4.2),(0.08,0.08,1.5),(0,0,0),dark,vertices=6)
add("uv_sphere",(-1,-1,5.0),(0.2,0.2,0.2),(0,0,0),red)
for k in range(6):
    add("cube",(2.9*math.cos(k*1.0),2.9*math.sin(k*1.0),1.5),(0.35,0.1,0.25),(0,0,k*1.0),glow)
export("outpost")
# alien fauna: floating jelly
jel=mat("jelly",(1,0.5,0.9,1),0,0.2,(1,0.4,0.8,1))
add("uv_sphere",(0,0,1.2),(0.6,0.6,0.4),(0,0,0),jel)
for a in range(5):
    t=a*1.256
    add("cylinder",(0.25*math.cos(t),0.25*math.sin(t),0.5),(0.04,0.04,0.7),(0,0,0),jel,vertices=5)
export("jelly")
bpy.ops.wm.save_mainfile()
print("done")
