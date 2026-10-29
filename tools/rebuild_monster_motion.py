"""Refresh the common eleven clips without rebuilding the environment or replacing geometry."""
from pathlib import Path
import sys
import json
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from creature_art import rig_creature
from adapt_horror_maker import build_external as hgm
from adapt_monster import build_external as bento
def coord(p):return Vector((p[0],-p[2],p[1]))
catalog=json.loads((ROOT/'assets/models/catalog.json').read_text(encoding='utf-8'))
def refresh(name,meshes,save=None):
    for obj in meshes:
        if obj.data.uv_layers:obj.data.uv_layers.active.name='UVMap'
    rig=rig_creature(meshes,{'coord':coord})
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:obj.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();mesh=bpy.context.object;mesh.name=name
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    mod=mesh.modifiers.new('Creature skin','ARMATURE');mod.object=rig;mesh.parent=rig;rig.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/f'assets/models/{name}.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_cameras=False,export_lights=False)
    if save:bpy.ops.wm.save_as_mainfile(filepath=str(save))
    triangles=sum(len(face.vertices)-2 for face in mesh.data.polygons)
    for entry in catalog:
        if entry['model']==name:entry['triangles']=triangles
    print('MONSTER_MOTION',name,triangles,flush=True)
for name,builder in [('entity',hgm),('entity_depot',bento)]:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions):bpy.data.actions.remove(action)
    builder({'coord':coord});refresh(name,[o for o in bpy.context.scene.objects if o.type=='MESH'])
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art-source/hospital_doctor.blend'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
for mesh in meshes:
    matrix=mesh.matrix_world.copy();mesh.parent=None;mesh.matrix_world=matrix;mesh.modifiers.clear()
for obj in list(bpy.data.objects):
    if obj.type=='ARMATURE':bpy.data.objects.remove(obj,do_unlink=True)
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
refresh('entity_doctor',meshes,ROOT/'art-source/hospital_doctor.blend')
(ROOT/'assets/models/catalog.json').write_text(json.dumps(catalog,indent=2)+'\n',encoding='utf-8')
