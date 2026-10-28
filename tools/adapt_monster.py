"""Repose Bento's CC BY 4.0 Smily model and bind it to our authored gameplay rig.

The untouched download and license metadata stay in art-source/third_party.
Only geometry, UVs, original material textures and skin weights are reused;
all eleven gameplay animations are authored by creature_art.py.
"""
from pathlib import Path
import bpy
from mathutils import Vector, Matrix

def build_external(api):
    coord=api['coord']
    path=Path(__file__).resolve().parents[1]/'art-source'/'third_party'/'bento_smily'/'source.glb'
    before=set(bpy.data.objects)
    actions_before=set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported=[o for o in bpy.data.objects if o not in before]
    rig=next(o for o in imported if o.type=='ARMATURE')
    rig.animation_data_clear()
    for pose in rig.pose.bones: pose.matrix_basis.identity()
    bpy.context.view_layer.update()
    meshes=[o for o in imported if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
    rest={b.name:rig.matrix_world@b.matrix_local for b in rig.data.bones}
    heads={n:m.translation.copy() for n,m in rest.items()}
    source_up=(heads['neck_04']-heads['spinebase_01']).normalized()
    right=(heads['Arm.R_022']-heads['Arm.L_09']).normalized()
    right=(right-source_up*right.dot(source_up)).normalized()
    forward=source_up.cross(right).normalized()
    source_frame=Matrix((right,forward,source_up)).transposed()
    rotation=source_frame.transposed()
    total_leg=sum((rig.matrix_world.to_3x3()@(rig.data.bones[n].tail_local-rig.data.bones[n].head_local)).length for n in ['leg.L_036','sheen.L_037'])
    scale=1.16/total_leg
    common=Matrix.Translation(coord((0,1.22,.045)))@rotation.to_4x4()@Matrix.Scale(scale,4)@Matrix.Translation(-heads['spinebase_01'])
    root=rig.pose.bones['_rootJoint']
    root.matrix=rig.matrix_world.inverted()@common@rest[root.name]
    bpy.context.view_layer.update()
    targets={
        'spinebase_01':((0,1.22,.045),(0,1.50,.04)),
        'belly_02':((0,1.50,.04),(0,1.90,.03)),
        'chest_03':((0,1.90,.03),(0,2.18,.02)),
        'neck_04':((0,2.18,.02),(0,2.35,-.025)),
        'head_05':((0,2.35,-.025),(0,2.63,-.065)),
    }
    # The source uses anatomical left/right; our animation rig labels +X as L.
    names={-1:('L_08','L_09','L_010','L_011','L_035','L_036','L_037','L_038'),1:('R_021','R_022','R_023','R_024','R_040','R_041','R_042','R_043')}
    for side, parts in names.items():
        shoulder=(side*.28,2.12,.02);elbow=(side*.38,1.31,-.015);wrist=(side*.44,.58,-.06)
        hip=(side*.15,1.22,.045);knee=(side*.18,.64,-.06);ankle=(side*.17,.09,.02)
        targets.update({'shoulder.'+parts[0]:((0,2.12,.02),shoulder),'Arm.'+parts[1]:(shoulder,elbow),'Forearm.'+parts[2]:(elbow,wrist),'Hand.'+parts[3]:(wrist,(side*.44,.26,-.19)),'Hip.'+parts[4]:((0,1.22,.045),hip),'leg.'+parts[5]:(hip,knee),'sheen.'+parts[6]:(knee,ankle),'foot.'+parts[7]:(ankle,(side*.17,.065,-.2))})
    for name,(a,b) in targets.items():
        bone=rig.data.bones[name]
        original=rest[name]
        old_axis=(original.to_3x3()@Vector((0,1,0))).normalized()
        direction=coord(Vector(b)-Vector(a))
        base_axis=rotation@old_axis
        q=base_axis.rotation_difference(direction.normalized())@rotation.to_quaternion()@original.to_quaternion()
        original_scale=original.to_scale()
        sizes=Vector((original_scale.x*scale,direction.length/bone.length,original_scale.z*scale))
        if name.startswith('Hand.'):
            sizes.y=original_scale.y*scale
        desired=Matrix.Translation(coord(a))@q.to_matrix().to_4x4()@Matrix.Diagonal((*sizes,1))
        rig.pose.bones[name].matrix=rig.matrix_world.inverted()@desired
        bpy.context.view_layer.update()
    for obj in meshes:
        bpy.context.view_layer.objects.active=obj
        for modifier in list(obj.modifiers):
            if modifier.type=='ARMATURE': bpy.ops.object.modifier_apply(modifier=modifier.name)
        world=obj.matrix_world.copy()
        obj.parent=None
        obj.data.transform(world)
        obj.matrix_world=Matrix.Identity(4)
        old_groups={g.index:g.name for g in obj.vertex_groups}
        weights=[]
        def group_name(name):
            side='R' if '.L' in name else 'L'
            if name.startswith('Forearm.'):return 'Forearm_'+side
            if name.startswith('Arm.'):return 'Arm_'+side
            if any(name.startswith(p) for p in ['Hand.','finguer.','middle.','ring.','pinky.','Tumb.']):return 'Hand_'+side
            if name.startswith('leg.'):return 'Thigh_'+side
            if name.startswith('sheen.'):return 'Shin_'+side
            if name.startswith('foot.') or name.startswith('toes.'):return 'Foot_'+side
            if any(name.startswith(p) for p in ['neck','head','jaw','frontface']):return 'Head'
            if name.startswith('spinebase') or name.startswith('Hip.') or name=='_rootJoint':return 'Root'
            return 'Spine'
        for vertex in obj.data.vertices:
            mapped={}
            for entry in vertex.groups:
                name=group_name(old_groups[entry.group]);mapped[name]=mapped.get(name,0)+entry.weight
            weights.append(mapped)
        obj.vertex_groups.clear()
        groups={n:obj.vertex_groups.new(name=n) for n in {n for w in weights for n in w}}
        for i,mapped in enumerate(weights):
            total=sum(mapped.values()) or 1
            for name,weight in mapped.items():groups[name].add([i],weight/total,'REPLACE')
        # Keep the original facial proportions while fitting the existing doorway.
        head_vertices=[v for v,w in zip(obj.data.vertices,weights) if w.get('Head',0)>.5]
        if head_vertices:
            top=max(v.co.z for v in head_vertices)
            if top>2.67:
                factor=.49/max(top-2.18,.001)
                anchor=coord((0,2.18,.02))
                for vertex in head_vertices:
                    offset=(vertex.co-anchor)*factor
                    offset.y*=1.35
                    vertex.co=anchor+offset
            width=max(v.co.x for v in head_vertices)-min(v.co.x for v in head_vertices)
            center=(max(v.co.x for v in head_vertices)+min(v.co.x for v in head_vertices))*.5
            for vertex in head_vertices:
                vertex.co.x=center+(vertex.co.x-center)*(.34/max(width,.001))
        obj.name='Bento Smily adapted'
    for obj in imported:
        if obj not in meshes and obj.name in bpy.data.objects:bpy.data.objects.remove(obj,do_unlink=True)
    for action in list(bpy.data.actions):
        if action not in actions_before:bpy.data.actions.remove(action)
