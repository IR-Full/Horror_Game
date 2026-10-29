"""Original depot props, escape car and jointed human rig. Blender 5.2 build tool."""
import bpy
import math
import json
import shutil
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models'
CAT=json.loads((OUT/'catalog.json').read_text(encoding='utf-8'))
shutil.copy2(ROOT/'art-source/legacy/entity_bento_v06.glb',OUT/'entity_depot.glb')
if not any(entry['model']=='entity_depot' for entry in CAT):
    CAT.append({'model':'entity_depot','triangles':23820})
M={}
def mat(name,color,metal=0):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.62
    M[name]=m
for args in [('enamel',(.13,.23,.19),.3),('rust',(.3,.12,.06),.4),('steel',(.16,.19,.2),.7),('fabric',(.21,.25,.19),0),('black',(.025,.03,.03),0),('cream',(.67,.64,.5),0),('red',(.42,.05,.03),0),('glass',(.09,.16,.17),.5)]:mat(*args)
M['glass'].diffuse_color=(.09,.16,.17,.22)
M['glass'].node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.22
def coord(p):return Vector((p[0],-p[2],p[1]))
def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def finish(o,name,material):
    o.name=name;o.data.materials.append(M[material]);return o
def box(name,p,size,material,bevel=.015):
    bpy.ops.mesh.primitive_cube_add(size=1,location=coord(p));o=bpy.context.object
    o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Rounded seams','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,material)
def rod(name,a,b,r,material):
    av,bv=coord(a),coord(b);delta=bv-av
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=delta.length,location=(av+bv)*.5)
    o=bpy.context.object;o.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    for poly in o.data.polygons:poly.use_smooth=True
    return finish(o,name,material)
def ball(name,p,size,material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=coord(p));o=bpy.context.object
    o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for poly in o.data.polygons:poly.use_smooth=True
    return finish(o,name,material)
def export(name,blend=None):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
    CAT[:]=[e for e in CAT if e['model']!=name];CAT.append({'model':name,'triangles':triangles})
    if blend:bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source'/blend))
    print('DEPOT_ART',name,triangles,flush=True)

clear()
box('Chassis',(0,.48,0),(1.85,.25,4.35),'steel')
box('Body',(0,.78,0),(2.08,.58,4.15),'enamel',.11)
box('Hood',(0,1.05,1.35),(1.95,.12,1.25),'rust',.04)
box('Roof',(0,1.78,-.2),(1.82,.13,1.9),'enamel',.07)
box('Front windshield',(0,1.42,.79),(1.72,.56,.055),'glass')
box('Rear windshield',(0,1.42,-1.18),(1.72,.5,.055),'glass')
for side in [-1,1]:
    box('Side glass',(side*.96,1.43,-.2),(.04,.5,1.82),'glass')
    for z in [-1.1,.74]:box('Roof pillar',(side*.94,1.42,z),(.1,.62,.1),'steel')
    box('Door seam',(side*1.047,.9,-.2),(.012,.02,1.75),'rust',0)
    box('Handle',(side*1.07,1.05,-.4),(.04,.04,.2),'steel')
    for z,label in [(1.3,'F'),(-1.35,'R')]:
        rod('Wheel_'+('L' if side<0 else 'R')+label,(side*.88,.38,z),(side*1.15,.38,z),.36,'black')
        rod('Hub_'+('L' if side<0 else 'R')+label,(side*1.14,.38,z),(side*1.17,.38,z),.2,'steel')
    box('Headlamp',(side*.7,.87,2.09),(.42,.23,.06),'cream')
    box('Tail lamp',(side*.78,.82,-2.09),(.24,.17,.05),'red')
box('Front bumper',(0,.46,2.18),(2.2,.16,.17),'steel')
box('Rear bumper',(0,.46,-2.18),(2.2,.16,.17),'steel')
for x in [-.6,0,.6]:box('Grille',(x,.72,2.105),(.35,.16,.025),'black')
export('escape_car','vehicle_assets.blend')

clear();box('Car battery',(0,0,0),(.32,.25,.2),'black')
box('Battery lid',(0,.14,0),(.34,.035,.22),'steel')
for x,c in [(-.1,'red'),(.1,'steel')]:rod('Terminal',(x,.14,0),(x,.19,0),.018,c)
export('car_battery')
clear()
for i in range(4):
    x=-.09+i*.06;rod('Ceramic',(x,-.025,0),(x,.07,0),.018,'cream');rod('Contact',(x,-.09,0),(x,-.025,0),.014,'steel')
export('spark_plugs')
clear();bpy.ops.mesh.primitive_torus_add(major_radius=.13,minor_radius=.018,major_segments=24,minor_segments=8)
finish(bpy.context.object,'Drive belt','black');export('drive_belt')
clear();rod('Spare tyre',(-.1,0,0),(.1,0,0),.31,'black');rod('Spare rim',(.1,0,0),(.12,0,0),.18,'steel');export('wheel')
clear();box('Medicine case',(0,0,0),(.12,.18,.07),'cream');box('Label',(0,0,-.038),(.08,.07,.006),'red',0);export('sedative')
clear();rod('Thermos',(0,-.13,0),(0,.13,0),.065,'steel');rod('Thermos lid',(0,.13,0),(0,.17,0),.069,'black');export('thermos')

clear()
parts=[]
def bind(o,bone):parts.append((o,bone));return o
bind(box('Pelvis',(0,.88,0),(.38,.23,.27),'enamel',.045),'Hips')
bind(box('Jacket',(0,1.16,0),(.5,.44,.31),'enamel',.065),'Spine')
bind(box('Belt',(0,.95,0),(.43,.055,.32),'black'),'Hips')
bind(box('Chest panel',(0,1.25,-.17),(.3,.15,.035),'fabric'),'Chest')
bind(box('Pack',(0,1.15,.23),(.32,.39,.19),'fabric',.035),'Spine')
bind(ball('SelfHead_Hood',(0,1.61,0),(.17,.22,.17),'fabric'),'Head')
bind(box('SelfHead_Mask',(0,1.57,-.17),(.22,.18,.07),'black',.025),'Head')
for x in [-.075,.075]:bind(rod('SelfHead_Lens',(x,1.65,-.17),(x,1.65,-.21),.055,'glass'),'Head')
for side,suffix in [(-1,'L'),(1,'R')]:
    x=side*.13
    bind(rod('Leg_Thigh_'+suffix,(x,.87,0),(x,.49,0),.115,'fabric'),'Thigh_'+suffix)
    bind(rod('Leg_Shin_'+suffix,(x,.49,0),(x,.16,0),.09,'fabric'),'Shin_'+suffix)
    bind(box('Knee_'+suffix,(x,.49,-.09),(.15,.17,.05),'enamel'),'Shin_'+suffix)
    bind(box('Boot_'+suffix,(x,.1,-.08),(.2,.19,.36),'black',.025),'Foot_'+suffix)
    bind(rod('SelfArm_Upper_'+suffix,(side*.26,1.37,0),(side*.32,1.08,0),.09,'fabric'),'UpperArm_'+suffix)
    bind(rod('SelfArm_Fore_'+suffix,(side*.32,1.08,0),(side*.32,.81,-.025),.075,'enamel'),'Forearm_'+suffix)
    bind(ball('SelfArm_Glove_'+suffix,(side*.32,.76,-.04),(.077,.1,.07),'black'),'Hand_'+suffix)
arm=bpy.data.armatures.new('HumanRig');rig=bpy.data.objects.new('HumanRig',arm);bpy.context.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(name,a,b,parent=None):
    x=arm.edit_bones.new(name);x.head=coord(a);x.tail=coord(b)
    if parent:x.parent=arm.edit_bones[parent]
bone('Hips',(0,.84,0),(0,.98,0));bone('Spine',(0,.98,0),(0,1.24,0),'Hips');bone('Chest',(0,1.24,0),(0,1.43,0),'Spine');bone('Head',(0,1.43,0),(0,1.78,0),'Chest')
for side,suffix in [(-1,'L'),(1,'R')]:
    bone('Thigh_'+suffix,(side*.13,.88,0),(side*.13,.49,0),'Hips')
    bone('Shin_'+suffix,(side*.13,.49,0),(side*.13,.14,0),'Thigh_'+suffix)
    bone('Foot_'+suffix,(side*.13,.14,0),(side*.13,.08,-.22),'Shin_'+suffix)
    bone('UpperArm_'+suffix,(side*.26,1.37,0),(side*.32,1.08,0),'Chest')
    bone('Forearm_'+suffix,(side*.32,1.08,0),(side*.32,.81,-.025),'UpperArm_'+suffix)
    bone('Hand_'+suffix,(side*.32,.81,-.025),(side*.32,.68,-.04),'Forearm_'+suffix)
bpy.ops.object.mode_set(mode='OBJECT')
for o,name in parts:
    group=o.vertex_groups.new(name=name);group.add(list(range(len(o.data.vertices))),1,'REPLACE')
    modifier=o.modifiers.new('Human skin','ARMATURE');modifier.object=rig;o.parent=rig
export('avatar_rigged','player_rig.blend')
(OUT/'catalog.json').write_text(json.dumps(CAT,indent=2)+'\n',encoding='utf-8')
