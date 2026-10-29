"""Hospital props and an authored surgeon adaptation of the licensed CC0 HGM body."""
import bpy
import math
import json
import sys
from pathlib import Path
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
OUT = ROOT/'assets/models'
CAT = json.loads((OUT/'catalog.json').read_text(encoding='utf-8'))
M = {}
def coord(p): return Vector((p[0],-p[2],p[1]))
def material(name, color, metal=0, rough=.65):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    M[name]=m
    return m
material('Hospital steel',(.23,.28,.29),.8,.34)
material('Hospital enamel',(.28,.37,.32),.3,.71)
material('Hospital rubber',(.025,.032,.029),0,.8)
material('Hospital blood',(.16,.009,.006),0,.23)
material('Hospital bone',(.61,.53,.37),0,.7)
cloth=material('Surgeon stained cloth',(.69,.68,.56),0,.92)
n=1024; rng=np.random.default_rng(13011)
yy,xx=np.mgrid[0:n,0:n]/n
dirt=.07*np.sin(xx*81)*np.sin(yy*57)+rng.normal(0,.018,(n,n))
stains=np.zeros((n,n))
for i in range(44):
    cx,cy=rng.uniform(.04,.96,2); rx=rng.uniform(.008,.11); ry=rng.uniform(.01,.12)
    d=((xx-cx)/rx)**2+((yy-cy)/ry)**2
    stains=np.maximum(stains,np.clip((1.05-d+np.sin(xx*380)*np.sin(yy*290)*.2)*4,0,1))
base=np.stack([.67+dirt,.66+dirt,.55+dirt],axis=-1)
base=base*(1-stains[...,None]*.88)+np.array([.18,.009,.006])*stains[...,None]*.88
height=dirt*.13+stains*.04
normal=np.stack([-np.gradient(height,axis=1)*18,-np.gradient(height,axis=0)*18,np.ones((n,n))],axis=-1)
normal/=np.linalg.norm(normal,axis=-1)[...,None]
for label,rgb in [('color',base),('normal',normal*.5+.5)]:
    image=bpy.data.images.new('Hospital cloth '+label,n,n)
    image.colorspace_settings.name='sRGB' if label=='color' else 'Non-Color'
    rgba=np.concatenate([np.clip(rgb,0,1),np.ones((n,n,1))],axis=-1)
    image.pixels.foreach_set(rgba.astype(np.float32).ravel())
    image.filepath_raw=str(ROOT/f'assets/textures/hospital_cloth_{label}.png'); image.file_format='PNG'; image.save(); image.pack()
    tex=cloth.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=image
    if label=='color':
        generated=ROOT/'assets/textures/hospital_cloth_generated.png'
        if generated.exists():
            detailed=bpy.data.images.load(str(generated),check_existing=False); detailed.scale(1024,1024); detailed.pack(); tex.image=detailed
        cloth.node_tree.links.new(tex.outputs['Color'],cloth.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    else:
        bump=cloth.node_tree.nodes.new('ShaderNodeNormalMap'); bump.inputs['Strength'].default_value=.4
        cloth.node_tree.links.new(tex.outputs['Color'],bump.inputs['Color'])
        cloth.node_tree.links.new(bump.outputs['Normal'],cloth.node_tree.nodes.get('Principled BSDF').inputs['Normal'])
def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def finish(o,name,mat,bone=None):
    o.name=name; o.data.materials.append(M[mat])
    if bone: o['rig_bone']=bone
    return o
def box(name,p,size,mat='Hospital steel',bone=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=coord(p)); o=bpy.context.object
    o.scale=(size[0],size[2],size[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    b=o.modifiers.new('Rounded worn edges','BEVEL'); b.width=min(.016,min(size)*.15); b.segments=3
    bpy.ops.object.modifier_apply(modifier=b.name)
    return finish(o,name,mat,bone)
def rod(name,a,b,r,mat='Hospital steel',bone=None):
    av,bv=coord(a),coord(b); d=bv-av
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=d.length,location=(av+bv)*.5)
    o=bpy.context.object; o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    for p in o.data.polygons:p.use_smooth=True
    return finish(o,name,mat,bone)
def ball(name,p,size,mat,bone=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=coord(p)); o=bpy.context.object
    o.scale=(size[0],size[2],size[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for face in o.data.polygons:face.use_smooth=True
    return finish(o,name,mat,bone)
def export(name,rig=None,blend=None):
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    # Joining meshes with different UV-layer names otherwise leaves new cloth at (0,0).
    for mesh in meshes:
        if mesh.data.uv_layers: mesh.data.uv_layers.active.name='UVMap'
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]; bpy.ops.object.join(); obj=bpy.context.object
    obj.name=name; bpy.context.scene.cursor.location=(0,0,0); bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    if rig:
        mod=obj.modifiers.new('Surgeon skin','ARMATURE'); mod.object=rig; obj.parent=rig; rig.select_set(True)
    triangles=sum(len(p.vertices)-2 for p in obj.data.polygons)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=bool(rig),export_cameras=False,export_lights=False)
    CAT[:]=[entry for entry in CAT if entry['model']!=name]; CAT.append({'model':name,'triangles':triangles})
    if blend:bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source'/blend))
    print('HOSPITAL_ART',name,triangles,flush=True)
def stains_on_top(at,size,count=12):
    for i in range(count):
        p=(at[0]+math.sin(i*7.3)*size[0],at[1]+.003,at[2]+math.cos(i*5.1)*size[1])
        ball('Clotted stain',p,(.04+(i%4)*.018,.003,.06+(i%3)*.023),'Hospital blood')
def scalpel(at=(0,0,0),bone=None,scale=1):
    x,y,z=at
    box('Scalpel grip',(x,y,z),(.025*scale,.012*scale,.15*scale),'Hospital steel',bone)
    for i in range(8):box('Grip groove',(x,y+.007*scale,z-.05*scale+i*.012*scale),(.027*scale,.0015*scale,.002*scale),'Hospital rubber',bone)
    box('Scalpel blade',(x,y,z-.11*scale),(.013*scale,.003*scale,.08*scale),'Hospital steel',bone)
    box('Blood on blade',(x,y+.002*scale,z-.13*scale),(.012*scale,.001*scale,.038*scale),'Hospital blood',bone)

clear()
box('Table base',(0,.09,0),(.75,.18,1.25))
rod('Hydraulic pedestal',(0,.13,0),(0,.85,0),.12)
box('Table frame',(0,.88,0),(.76,.12,2.0))
for z in [-.65,0,.65]:box('Split surgical cushion',(0,.98,z),(.7,.12,.61),'Surgeon stained cloth')
for side in [-1,1]:
    rod('Side rail',(side*.43,.9,-.8),(side*.43,.9,.8),.018)
    rod('Restraint post',(side*.44,.88,-.25),(side*.75,.98,-.25),.025)
    box('Arm board',(side*.7,.99,-.25),(.48,.06,.24),'Hospital rubber')
    box('Restraint strap',(side*.7,1.04,-.25),(.065,.035,.27),'Hospital rubber')
    for z in [-.45,.45]:rod('Caster',(side*.3,.08,z-.06),(side*.3,.08,z+.06),.07,'Hospital rubber')
stains_on_top((0,1.045,0),(.25,.72),22)
export('operating_table')
clear()
for x in [-.34,.34]:
    for z in [-.23,.23]:
        rod('Trolley leg',(x,.08,z),(x,1.02,z),.02)
        rod('Trolley wheel',(x,.07,z-.04),(x,.07,z+.04),.065,'Hospital rubber')
for y in [.3,1.0]:box('Tray',(0,y,0),(.76,.035,.56))
for z in [-.28,.28]:rod('Tray rim',(-.38,1.04,z),(.38,1.04,z),.015)
scalpel((-.14,1.028,.04)); scalpel((.12,1.028,.1))
for x in [-.03,.02]:rod('Bloody forceps',(x,1.028,-.17),(x+.025,1.028,.03),.005)
stains_on_top((0,1.025,0),(.26,.17),12)
export('hospital_trolley')
clear()
box('Lamp base',(0,.06,0),(.6,.12,.6)); rod('Lamp pole',(0,.1,0),(0,2.2,0),.035)
rod('Joint arm',(0,2.2,0),(.55,2.45,0),.03); rod('Lamp boom',(.55,2.45,0),(.9,2.1,0),.025)
ball('Operating reflector',(.9,2.08,0),(.35,.07,.35),'Hospital enamel')
for i in range(6):
    a=i*math.tau/6; ball('Dead lamp lens',(.9+math.cos(a)*.2,2.025,math.sin(a)*.2),(.07,.018,.07),'Hospital bone')
export('surgical_lamp')
clear();scalpel(); export('scalpel')
for i,name in enumerate(['specimen_a','specimen_b','specimen_c']):
    clear(); rod('Sealed vial',(0,-.08,0),(0,.06,0),.035,'Hospital blood')
    rod('Vial stopper',(0,.06,0),(0,.09,0),.04,'Hospital rubber')
    box('Sample label',(0,0,-.035),(.05,.05,.004),'Hospital bone')
    for mark in range(i+1):box('Sample index',(-.015+mark*.015,0,-.038),(.006,.035,.002),'Hospital blood')
    export(name)
clear(); box('Doctor access card',(0,0,0),(.16,.012,.1),'Hospital bone')
box('Red card stripe',(0,.008,0),(.16,.003,.024),'Hospital blood'); export('hospital_badge')
clear();box('Pedestal',(0,0,0),(.7,.9,.55),'Hospital enamel')
box('Console screen',(0,.22,-.29),(.49,.24,.03),'Hospital rubber')
for i in range(3):ball('Indicator',(-.16+i*.16,.02,-.3),(.025,.025,.012),'Hospital blood')
export('hospital_console')

# Keep the licensed textured anatomy; add a distinct, torn surgical silhouette.
clear()
from adapt_horror_maker import build_external
from creature_art import rig_creature
build_external({'coord':coord})
def coat_panel(side):
    verts=[]; faces=[]
    for row in range(14):
        y=.73+row*.105
        for col in range(17):
            t=col/16; angle=-math.pi/2+t*math.pi
            width=.32 if y<1.55 else .31+(y-1.55)*.23
            x=side*(.015+abs(math.cos(angle))*width)
            z=math.sin(angle)*(.19 if y>1.5 else .23)+.045
            y1=y+(.045*math.sin(col*5.7) if row==0 else .007*math.sin(col*3+row))
            verts.append(tuple(coord((x,y1,z))))
    for row in range(13):
        for col in range(16):
            if row<2 and col in [3,8,12]:continue
            a=row*17+col; faces.append((a,a+1,a+18,a+17) if side>0 else (a+17,a+18,a+1,a))
    mesh=bpy.data.meshes.new('Torn coat panels');mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new('Torn surgeon coat',mesh);bpy.context.collection.objects.link(obj)
    mesh.materials.append(cloth); uv=mesh.uv_layers.new()
    for poly in mesh.polygons:
        poly.use_smooth=True
        for index in poly.loop_indices:
            vi=mesh.loops[index].vertex_index; uv.data[index].uv=(vi%17/16,vi//17/13)
    for bone in ['Root','Spine']:obj.vertex_groups.new(name=bone)
    for vertex in mesh.vertices:
        weight=max(0,min(1,(vertex.co.z-1.2)/.5))
        obj.vertex_groups['Root'].add([vertex.index],1-weight,'REPLACE')
        obj.vertex_groups['Spine'].add([vertex.index],weight,'REPLACE')
    solid=obj.modifiers.new('Cloth thickness','SOLIDIFY');solid.thickness=.006;bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_apply(modifier=solid.name)
for side in [-1,1]:coat_panel(side)
box('Blood soaked apron',(0,1.7,-.205),(.39,.7,.022),'Surgeon stained cloth','Spine')
for side,suffix in [(1,'L'),(-1,'R')]:
    rod('Ragged sleeve',(side*.29,2.1,.02),(side*.36,1.52,0),.105,'Surgeon stained cloth','Arm_'+suffix)
    ball('Surgical glove',(side*.44,.49,-.075),(.08,.14,.06),'Hospital blood','Hand_'+suffix)
    for y in [1.65,1.82,1.96]:box('Coat fastener',(side*.04,y,-.22),(.017,.025,.018),'Hospital steel','Spine')
ball('Torn surgical cap',(0,2.54,-.06),(.155,.075,.15),'Surgeon stained cloth','Head')
ball('Bloody gauze mask',(0,2.38,-.18),(.12,.095,.045),'Surgeon stained cloth','Head')
for side in [-1,1]:
    rod('Mask strap',(side*.1,2.43,-.18),(side*.13,2.46,.05),.008,'Hospital rubber','Head')
    ball('Hollow eye',(side*.056,2.515,-.184),(.029,.021,.012),'Hospital rubber','Head')
for y in [2.4,2.44,2.48]:rod('Cranial staple',(.105,y,-.1),(.13,y,-.08),.005,'Hospital steel','Head')
scalpel((-.44,.31,-.16),'Hand_R',2.5)
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
rig=rig_creature(meshes,{'coord':coord})
export('entity_doctor',rig,'hospital_doctor.blend')
(OUT/'catalog.json').write_text(json.dumps(CAT,indent=2)+'\n',encoding='utf-8')
print('HOSPITAL_ART_COMPLETE',len(CAT),flush=True)
