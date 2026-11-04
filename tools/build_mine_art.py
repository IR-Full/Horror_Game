"""Original forestry props and a rigged CC0-body foreman adaptation; run in Blender."""
import bpy, math, json, sys, random
from pathlib import Path
from mathutils import Vector
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
if hasattr(bpy.context.preferences.filepaths,"use_save_preview_images"):bpy.context.preferences.filepaths.use_save_preview_images=False
OUT=ROOT/'assets/models';CAT=json.loads((OUT/'catalog.json').read_text(encoding='utf-8'));M={}
def coord(p):return Vector((p[0],-p[2],p[1]))
def mat(name,color,metal=0,rough=.8):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;M[name]=m;return m
mat('wood',(.28,.19,.10));mat('steel',(.18,.23,.22),.8,.52);mat('rust',(.24,.09,.035),.55);mat('Forest needles',(.055,.105,.065));mat('Forest endgrain',(.48,.34,.18));mat('Forest rubber',(.018,.022,.019));mat('Forest paint',(.14,.22,.16),.4);mat('Forest blood',(.12,.005,.003),0,.25);mat('Forest bone',(.46,.39,.23))
# Tileable bark and end grain are embedded glTF PBR images, also saved for editing.
n=512;rng=np.random.default_rng(7103);yy,xx=np.mgrid[0:n,0:n]/n
for name,base,h in [('Forest bark',(.19,.14,.09),np.sin(xx*95+np.sin(yy*35)*2)*.07+np.sin(xx*270+yy*10)*.025+rng.normal(0,.014,(n,n))),('Forest endgrain',(.45,.32,.16),np.sin(np.sqrt((xx-.5)**2+(yy-.5)**2)*240)*.035+rng.normal(0,.012,(n,n)))]:
 m=M.get(name) or mat(name,base);rgb=np.clip(np.array(base)+h[...,None],0,1);rgba=np.concatenate([rgb,np.ones((n,n,1))],axis=-1)
 image=bpy.data.images.new(name,n,n);image.pixels.foreach_set(rgba.astype(np.float32).ravel());image.filepath_raw=str(ROOT/'assets/textures'/('forest_'+name.split()[-1]+'.png'));image.file_format='PNG';image.save();image.pack()
 t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=image;m.node_tree.links.new(t.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
def clear():bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def finish(o,name,material,bone=None):
 o.name=name;o.data.materials.append(M[material])
 if bone:o['rig_bone']=bone
 return o
def box(name,p,size,material='steel',bone=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=coord(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 b=o.modifiers.new('Worn edges','BEVEL');b.width=min(.018,min(size)*.12);b.segments=2;bpy.ops.object.modifier_apply(modifier=b.name);return finish(o,name,material,bone)
def rod(name,a,b,r,material='steel',bone=None,vertices=10,end=None):
 av,bv=coord(a),coord(b);d=bv-av
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if end is None else end,depth=d.length,location=(av+bv)*.5);o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
 return finish(o,name,material,bone)
def export(name,rig=None):
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];bpy.ops.object.select_all(action='DESELECT')
 for o in meshes:
  if o.data.uv_layers:o.data.uv_layers.active.name='UVMap'
  o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();o=bpy.context.object;o.name=name;bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 if rig:
  mod=o.modifiers.new('Forester skin','ARMATURE');mod.object=rig;o.parent=rig;rig.select_set(True)
 tris=sum(len(p.vertices)-2 for p in o.data.polygons);bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=bool(rig),export_cameras=False,export_lights=False)
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art-source'/f'{name}.blend'));CAT[:]=[x for x in CAT if x['model']!=name];CAT.append({'model':name,'triangles':tris});print('FOREST_ART',name,tris,flush=True)
clear()
box('Lift floor',(0,.14,0),(2.1,.28,3.4),'rust')
for x in [-.98,.98]:
 for z in [-1.6,1.6]:box('Cage post',(x,1.45,z),(.1,2.7,.1))
 for z in [-1.4,-1,-.6,-.2,.2,.6,1,1.4]:rod('Safety bars',(x,.35,z),(x,2.2,z),.018)
box('Lift roof',(0,2.8,0),(2.2,.12,3.5))
export('mine_lift')
clear();from adapt_horror_maker import build_external
from creature_art import rig_creature
build_external({'coord':coord})
rod('Miner helmet rim',(0,2.52,0),(0,2.6,0),.2,'rust','Head',vertices=20)
rod('Collapsed hardhat',(0,2.6,0),(0,2.77,0),.18,'Forest paint','Head',vertices=20,end=.08)
rod('Broken headlamp',(0,2.64,-.16),(0,2.64,-.25),.065,'steel','Head',vertices=16)
box('Cracked respirator',(0,2.35,-.19),(.22,.13,.075),'Forest rubber','Head')
for x in [-.12,.12]:rod('Filter cartridge',(x,2.34,-.19),(x,2.34,-.28),.046,'rust','Head',vertices=10)
rod('Pickaxe haft',(-.44,.55,-.1),(-.44,-.02,-.1),.022,'wood','Hand_R')
rod('Pick head',(-.68,.02,-.1),(-.21,.02,-.1),.035,'rust','Hand_R',vertices=8,end=.01)
rig=rig_creature([o for o in bpy.context.scene.objects if o.type=='MESH'],{'coord':coord});export('entity_miner',rig)
(OUT/'catalog.json').write_text(json.dumps(CAT,indent=2)+'\n',encoding='utf-8');print('MINE_ART_PASS',flush=True)
