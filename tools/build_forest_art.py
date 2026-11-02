"""Original forestry props and a rigged CC0-body foreman adaptation; run in Blender."""
import bpy, math, json, sys, random
from pathlib import Path
from mathutils import Vector
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
bpy.context.preferences.filepaths.use_save_preview_images=False
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
clear();rod('Rooted pine trunk',(0,-.08,0),(0,9,0),.31,'Forest bark',vertices=12,end=.045)
for level in range(8):
 y=2.1+level*.81;reach=2.25-level*.21
 for side in range(5):
  a=side*math.tau/5+level*1.7;tip=(math.cos(a)*reach,y-.45,math.sin(a)*reach);rod('Tapered branch',(0,y,0),tip,.055,'Forest bark',vertices=5,end=.008)
  # Layered irregular clusters retain a conifer silhouette without alpha overdraw.
  for j in range(3):
   f=.4+j*.27;p=(tip[0]*f,y-.25*f,tip[2]*f);bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=coord(p));o=bpy.context.object;o.scale=(reach*.4,.38,reach*.33);o.rotation_euler.z=a;finish(o,'Needle cluster','Forest needles')
export('forest_pine')
clear();rod('Dead split trunk',(0,-.08,0),(.14,6.8,0),.24,'Forest bark',vertices=10,end=.035)
for i in range(7):
 a=i*2.4;y=2+i*.55;rod('Broken snag',(.08,y,0),(math.cos(a)*(.9-i*.07),y+.4,math.sin(a)*.9),.05,'Forest bark',vertices=6,end=.007)
export('forest_snag')
clear()
for row in range(3):
 for col in range(4-row):
  x=(col-(3-row)*.5)*.52;y=.28+row*.45;z=(col%2)*.11
  rod('Stacked pine log',(x,y,z-2.6),(x,y,z+2.6),.265,'Forest bark',vertices=12)
  for side in [-1,1]:rod('Cut growth rings',(x,y,z+side*2.601),(x,y,z+side*2.607),.253,'Forest endgrain',vertices=12)
export('forest_logs')
clear();box('Saw bed',(0,.82,0),(2.5,.2,1.1),'Forest paint')
for x in [-1,1]:
 for z in [-.4,.4]:box('Saw leg',(x,.4,z),(.12,.8,.12))
for x in [-.8,-.4,0,.4,.8]:rod('Feed roller',(x,.95,-.46),(x,.95,.46),.075)
rod('Circular blade',(0,1.12,.05),(0,1.12,.085),.6,vertices=48)
for i in range(32):
 a=i*math.tau/32;o=box('Carbide tooth',(math.sin(a)*.61,1.12+math.cos(a)*.61,.068),(.045,.075,.035));o.rotation_euler.y=-a
box('Motor',(.85,.44,0),(.55,.4,.7),'Forest paint');box('Red stop switch',(1.15,1.12,.4),(.11,.1,.11),'Forest blood');export('forest_saw')
clear();rod('Cable drum',(-.65,.65,0),(.65,.65,0),.38,'Forest rubber',vertices=24)
for x in [-.7,.7]:
 rod('Drum flange',(x-.025,.65,0),(x+.025,.65,0),.49,vertices=24);box('Winch bearing',(x,.32,0),(.18,.64,.7))
box('Winch base',(0,.07,0),(1.9,.14,1.25),'Forest paint');box('Gearbox',(.98,.65,0),(.4,.4,.5),'rust');export('forest_winch')
clear();box('Railcart chassis',(0,.42,0),(1.7,.18,3.4),'Forest paint')
for side in [-1,1]:
 for z in [-1.12,1.12]:
  rod('Steel flanged wheel',(side*.67,.24,z),(side*.9,.24,z),.26,vertices=24)
  rod('Wheel flange',(side*.65,.24,z),(side*.69,.24,z),.3,vertices=24)
 box('Timber bench',(side*.57,.88,.55),(.42,.12,1.8),'wood');box('Bench back',(side*.82,1.12,.55),(.07,.5,1.8),'wood')
for z in [-1.12,1.12]:rod('Axle',(-.83,.24,z),(.83,.24,z),.07)
box('Diesel bonnet',(0,.92,-1.04),(1.32,.78,.95),'Forest paint');box('Oil radiator',(0,.88,-1.53),(.95,.5,.025),'Forest rubber')
for x in [-.5,.5]:rod('Headlight housing',(x,1.15,-1.5),(x,1.15,-1.63),.13,vertices=16);rod('Headlight glass',(x,1.15,-1.636),(x,1.15,-1.64),.105,'Forest bone',vertices=16)
rod('Exhaust',(0,1.24,-.9),(0,2.25,-.9),.05,'rust');rod('Control column',(0,.52,.15),(0,1.22,-.02),.035);rod('Brake lever',(0,1.22,-.02),(.28,1.43,-.02),.025)
for side in [-1,1]:rod('Handrail',(side*.82,.52,-.15),(side*.82,1.27,-.15),.025)
export('forest_cart')
# A separate authored silhouette retains the licensed anatomical body and animations.
clear();from adapt_horror_maker import build_external
from creature_art import rig_creature
build_external({'coord':coord})
for i in range(7):
 a=(i-3)*.27;x=math.sin(a)*.155;z=-.11-math.cos(a)*.11
 o=box('Split bark face',(x,2.48+math.sin(i*3)*.012,z),(.047,.29 if i%2 else .35,.036),'Forest bark','Head');o.rotation_euler.z=-a
for x in [-.065,.065]:box('Hollow eye slit',(x,2.50,-.242),(.07,.045,.016),'Forest rubber','Head')
for side,suffix in [(1,'L'),(-1,'R')]:
 rod('Torn leather sleeve',(side*.29,2.08,.02),(side*.36,1.55,0),.12,'Forest rubber','Arm_'+suffix)
 for i in range(3):rod('Mask staples',(side*.13,2.37+i*.065,-.25),(side*.18,2.37+i*.065,-.22),.005,'steel','Head')
# Curved torn apron panels with actual folds and a ragged hem.
verts=[];faces=[]
for row in range(9):
 for col in range(15):
  x=-.25+col/14*.5;y=.94+row*.12+(math.sin(col*2.7)*.065 if row==0 else 0);z=-.23+abs(x)*.23+math.sin(col*1.6)*.012
  verts.append(tuple(coord((x,y,z))))
for row in range(8):
 for col in range(14):
  if row<2 and col in [2,7,11]:continue
  i=row*15+col;faces.append((i,i+1,i+16,i+15))
mesh=bpy.data.meshes.new('Torn leather apron');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Torn leather apron',mesh);bpy.context.collection.objects.link(o);finish(o,'Torn leather apron','Forest rubber','Spine')
for material in ['Forest blood']:mesh.materials.append(M[material])
for face in mesh.polygons:face.material_index=1 if face.index%17 in [1,2,3] else 0;face.use_smooth=True
solid=o.modifiers.new('Leather thickness','SOLIDIFY');solid.thickness=.007;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=solid.name)
box('Foreman belt',(0,1.25,0),(.5,.07,.48),'rust','Root')
rod('Broken saw handle',(-.44,.5,-.05),(-.44,.21,-.06),.03,'wood','Hand_R')
for i in range(8):box('Blunt saw teeth',(-.44,.19-i*.03,-.12),(.06,.02,.09),'rust','Hand_R')
rig=rig_creature([o for o in bpy.context.scene.objects if o.type=='MESH'],{'coord':coord});export('entity_forester',rig)
(OUT/'catalog.json').write_text(json.dumps(CAT,indent=2)+'\n',encoding='utf-8');print('FOREST_ART_COMPLETE',flush=True)
