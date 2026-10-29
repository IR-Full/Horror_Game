"""Two original medical props: stained shroud and torn operating curtain."""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models'; catalog=json.loads((OUT/'catalog.json').read_text(encoding='utf-8'))
def coord(p):return Vector((p[0],-p[2],p[1]))
cloth=bpy.data.materials.new('Stained hospital linen');cloth.use_nodes=True
shader=cloth.node_tree.nodes.get('Principled BSDF');shader.inputs['Roughness'].default_value=.89
tex=cloth.node_tree.nodes.new('ShaderNodeTexImage')
tex.image=bpy.data.images.load(str(ROOT/'assets/textures/hospital_cloth_generated.png'));tex.image.scale(1024,1024);tex.image.pack()
cloth.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
steel=bpy.data.materials.new('Curtain worn steel');steel.use_nodes=True
steel.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.16,.22,.2,1)
steel.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value=.75
def surface(name,rows,cols,point,skip=None):
    verts=[]; faces=[]
    for r in range(rows+1):
        for c in range(cols+1):verts.append(tuple(coord(point(c/cols,r/rows))))
    for r in range(rows):
        for c in range(cols):
            if skip and skip(c/cols,r/rows):continue
            a=r*(cols+1)+c;faces.append((a,a+1,a+cols+2,a+cols+1))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);mesh.materials.append(cloth)
    uv=mesh.uv_layers.new(name='UVMap')
    for poly in mesh.polygons:
        poly.use_smooth=True
        for index in poly.loop_indices:
            vi=mesh.loops[index].vertex_index;uv.data[index].uv=(vi%(cols+1)/cols,vi//(cols+1)/rows)
    solid=obj.modifiers.new('Fabric thickness','SOLIDIFY');solid.thickness=.006
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=solid.name)
def rod(a,b,r):
    a,b=coord(a),coord(b);d=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=d.length,location=(a+b)*.5)
    obj=bpy.context.object;obj.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);obj.data.materials.append(steel)
def export(name):
    bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH');bpy.ops.object.join()
    obj=bpy.context.object;obj.name=name;bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'art-source/{name}.blend'))
    catalog[:]=[entry for entry in catalog if entry['model']!=name]
    catalog.append({'model':name,'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons)})
    print('HOSPITAL_HORROR',name,flush=True)
def clear():bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
clear()
def sheet(u,v):
    x=(u-.5)*1.0;z=(v-.5)*2.0
    body=.31*math.exp(-(x/.29)**2-((z+.08)/.78)**4)
    head=.12*math.exp(-(x/.21)**2-((z+.7)/.23)**2)
    fold=.014*math.sin(u*65+v*13)*math.sin(v*35)
    return (x,1.045+body+head+fold-max(0,abs(x)-.36)*1.2,z)
surface('Covered surgical stretcher',40,24,sheet);export('hospital_shroud')
clear()
surface('Ripped privacy curtain',32,40,lambda u,v:((u-.5)*1.8,.12+(1-v)*2.15,.055*math.sin(u*math.tau*8)),lambda u,v:(.39<u<.46 and v>.52) or (.73<u<.77 and v>.8))
rod((-.98,.04,0),(-.98,2.42,0),.025);rod((.98,.04,0),(.98,2.42,0),.025);rod((-.98,2.42,0),(.98,2.42,0),.025)
for x in [-.98,.98]:rod((x,.05,-.22),(x,.05,.22),.035)
export('hospital_curtain')
(OUT/'catalog.json').write_text(json.dumps(catalog,indent=2)+'\n',encoding='utf-8')
