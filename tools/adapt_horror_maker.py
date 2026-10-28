"""Adapt the CC0 HorrorGameMaker.com creature to the authored gameplay rig."""
from pathlib import Path
import math
import bpy
from mathutils import Vector, Matrix


def build_external(api):
    folder = Path(__file__).resolve().parents[1]/'art-source/third_party/horror_game_maker'
    coord = api['coord']
    before = set(bpy.data.objects)
    old_actions = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=str(folder/'Idle.fbx'))
    imported = [o for o in bpy.data.objects if o not in before]
    mesh = next(o for o in imported if o.type=='MESH' and len(o.data.vertices)>1000)
    rig = next(m.object for m in mesh.modifiers if m.type=='ARMATURE')
    rest = {b.name:rig.matrix_world@b.head_local for b in rig.data.bones}
    transforms = {}
    names = {}
    rotation = Matrix.Rotation(math.pi,4,'Z')

    def segment(name, end, a, b, group):
        source = rest[name]
        old = rest[end]-source
        target = coord(b)-coord(a)
        axis = old.normalized()
        q = (rotation.to_3x3()@axis).rotation_difference(target.normalized()).to_matrix().to_4x4()@rotation
        thickness = 1.13
        parallel = target.length/old.length/thickness
        stretch = Matrix.Identity(4)
        for i in range(3):
            for j in range(3):stretch[i][j] += (parallel-1)*axis[i]*axis[j]
        transforms[name] = Matrix.Translation(coord(a))@q@Matrix.Scale(thickness,4)@stretch@Matrix.Translation(-source)
        names[name] = group

    segment('joint1','joint2',(0,1.22,.045),(0,1.50,.04),'Root')
    segment('joint2','joint3',(0,1.50,.04),(0,1.90,.03),'Spine')
    segment('joint3','joint4',(0,1.90,.03),(0,2.18,.02),'Spine')
    for side, tail in [(-1,''),(1,'.001')]:
        suffix = 'R' if side < 0 else 'L'
        shoulder=(side*.28,2.12,.02);elbow=(side*.38,1.31,-.015);wrist=(side*.44,.58,-.06)
        segment('joint14'+tail,'joint11'+tail,shoulder,elbow,'Arm_'+suffix)
        segment('joint11'+tail,'joint12'+tail,elbow,wrist,'Forearm_'+suffix)
        segment('joint5' if side < 0 else 'joint64','joint6'+tail,(side*.15,1.22,.045),(side*.18,.64,-.06),'Thigh_'+suffix)
        segment('joint6'+tail,'joint7'+tail,(side*.18,.64,-.06),(side*.17,.09,.02),'Shin_'+suffix)
        old_hand=(rest['joint13'+tail]-rest['joint12'+tail]).normalized()
        new_hand=(coord((side*.44,.26,-.19))-coord(wrist)).normalized()
        hand_rotation=(rotation.to_3x3()@old_hand).rotation_difference(new_hand).to_matrix().to_4x4()@rotation
        hand = Matrix.Translation(coord(wrist))@hand_rotation@Matrix.Scale(1.18,4)@Matrix.Translation(-rest['joint12'+tail])
        foot = Matrix.Translation(coord((side*.17,.09,.02)))@rotation@Matrix.Scale(1.13,4)@Matrix.Translation(-rest['joint7'+tail])
        for name, head in rest.items():
            if (head.x > 0) != (side < 0):continue
            if abs(head.x)>.72:transforms[name]=hand;names[name]='Hand_'+suffix
            elif head.z<.2:transforms[name]=foot;names[name]='Foot_'+suffix
    head = Matrix.Translation(coord((0,2.18,.02)))@rotation@Matrix.Scale(1.2,4)@Matrix.Translation(-rest['joint4'])
    for name, at in rest.items():
        if name.startswith('Clav_'):
            names[name]='Spine';transforms[name]=transforms['joint3']
        elif at.z>1.6 and abs(at.x)<.24:
            names[name]='Head';transforms[name]=head
    world = mesh.matrix_world.copy()
    original_groups = {g.index:g.name for g in mesh.vertex_groups}
    new_weights=[]
    for vertex in mesh.data.vertices:
        point = world@vertex.co
        posed = Vector((0,0,0));mapped={};total=0.0
        for item in vertex.groups:
            name = original_groups[item.group]
            transform = transforms.get(name,transforms['joint2'])
            group = names.get(name,'Spine')
            posed += (transform@point)*item.weight
            mapped[group]=mapped.get(group,0)+item.weight
            total+=item.weight
        vertex.co = posed/max(total,.00001)
        new_weights.append(mapped)
    mesh.modifiers.clear()
    mesh.parent=None
    mesh.matrix_world=Matrix.Identity(4)
    mesh.vertex_groups.clear()
    groups = {name:mesh.vertex_groups.new(name=name) for name in {n for w in new_weights for n in w}}
    for index, weights in enumerate(new_weights):
        total=sum(weights.values()) or 1
        for name, weight in weights.items():groups[name].add([index],weight/total,'REPLACE')
    material=bpy.data.materials.new('HGM_flesh')
    material.use_nodes=True
    nodes=material.node_tree.nodes;links=material.node_tree.links
    shader=nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value=.68
    shader.inputs['Metallic'].default_value=.02
    for kind,name in [('color','test_StingrayPBS1SG_AlbedoTransparency.png'),('normal','test_StingrayPBS1SG_Normal.png')]:
        image=bpy.data.images.load(str(folder/name),check_existing=False)
        image.scale(2048 if kind=='color' else 1024,2048 if kind=='color' else 1024)
        image.pack()
        texture=nodes.new('ShaderNodeTexImage');texture.image=image
        if kind=='color':links.new(texture.outputs['Color'],shader.inputs['Base Color'])
        else:
            image.colorspace_settings.name='Non-Color'
            normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.7
            links.new(texture.outputs['Color'],normal.inputs['Color'])
            links.new(normal.outputs['Normal'],shader.inputs['Normal'])
    mesh.data.materials.clear();mesh.data.materials.append(material)
    for polygon in mesh.data.polygons:polygon.material_index=0;polygon.use_smooth=True
    mesh.name='HorrorGameMaker adapted creature'
    for obj in imported:
        if obj!=mesh and obj.name in bpy.data.objects:bpy.data.objects.remove(obj,do_unlink=True)
    for action in list(bpy.data.actions):
        if action not in old_actions:bpy.data.actions.remove(action)
