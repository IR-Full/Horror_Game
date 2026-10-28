"""Original muscle creature and authored upright / quadruped animation clips.

Called by build_art.py inside Blender. Coordinates are Godot metres (Y up).
"""
import math
import bpy
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree

HIP = Vector((0, 1.22, .045))
CHEST = Vector((0, 2.18, .02))


def build_creature(api):
    ball, rod, wire = api['ball'], api['rod'], api['wire']
    finish, coord = api['finish'], api['coord']
    api['mat']('muscle', (.19, .025, .018))
    api['mat']('muscle_dark', (.08, .008, .006))
    api['mat']('tendon', (.38, .265, .19))
    api['mat']('cavity', (.009, .006, .005))
    api['mat']('clotted_blood', (.045, .0025, .002))
    api['mat']('torn_edge', (.27, .019, .012))
    api['M']['clotted_blood'].node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .25

    def tag(obj, bone):
        obj['rig_bone'] = bone
        for face in obj.data.polygons:
            face.use_smooth = True
        return obj

    def tissue(name, pos, size, material, bone, detail=2):
        obj = tag(ball(name, pos, size, material, max(2, detail)), bone)
        for v in obj.data.vertices:
            p = v.co
            ripple = math.sin(p.x*47+p.z*19)*math.sin(p.y*39+p.z*13)
            p *= 1 + ripple*.035
        return obj

    def line(name, a, b, radius, material, bone, tip=None):
        return tag(rod(name, a, b, radius, material, 9, tip), bone)

    def muscle(name, a, b, radius, bone):
        av, bv = coord(a), coord(b)
        direction = bv - av
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=12, radius=1, location=(av + bv) * .5)
        obj = bpy.context.object
        obj.scale = (radius, radius * .85, direction.length * .54)
        obj.rotation_mode = 'QUATERNION'
        obj.rotation_quaternion = direction.to_track_quat('Z', 'Y')
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        tag(finish(obj, name, 'muscle'), bone)
        for offset in [-.032, 0, .032]:
            aa = Vector(a) + Vector((offset, 0, -.052))
            bb = Vector(b) + Vector((offset * .6, 0, -.043))
            line('Muscle fibre', aa.lerp(bb, .12), aa.lerp(bb, .87), .005, 'muscle_dark', bone)

    tissue('Pelvis', HIP, (.19, .17, .14), 'muscle_dark', 'Root')
    tissue('Ribcage core', (0, 1.91, .045), (.235, .3, .14), 'muscle_dark', 'Spine')
    tissue('Abdomen', (0, 1.56, .015), (.145, .22, .1), 'muscle_dark', 'Spine')
    for side in [-1, 1]:
        suffix = 'L' if side > 0 else 'R'
        tissue('Pectoral', (side * .135, 2.015, -.095), (.155, .105, .063), 'muscle', 'Spine')
        tissue('Latissimus', (side * .14, 1.93, .17), (.15, .245, .055), 'muscle', 'Spine')
        for i in range(4):
            tissue('Abdominal bundle', (side * .065, 1.78 - i * .115, -.09), (.07, .055, .018), 'muscle', 'Spine')
        for i in range(6):
            y = 1.83 + i * .047
            tag(wire('Rib tendon', [(side * .025, y, -.15), (side * .155, y + .035, -.11), (side * .215, y + .06, .01)], .009, 'tendon'), 'Spine')
        shoulder = Vector((side * .28, 2.12, .02))
        elbow = Vector((side * .38, 1.31, -.015))
        wrist = Vector((side * .44, .58, -.06))
        tissue('Deltoid', shoulder, (.085, .12, .085), 'muscle', 'Arm_' + suffix)
        muscle('Upper arm', shoulder, elbow, .078, 'Arm_' + suffix)
        muscle('Forearm', elbow, wrist, .06, 'Forearm_' + suffix)
        tissue('Torn upper arm', shoulder.lerp(elbow, .43) + Vector((0, 0, -.067)), (.028, .1, .012), 'clotted_blood', 'Arm_' + suffix)
        tissue('Torn forearm edge', elbow.lerp(wrist, .42) + Vector((0, 0, -.055)), (.025, .09, .01), 'torn_edge', 'Forearm_' + suffix)
        tissue('Forearm wound', elbow.lerp(wrist, .42) + Vector((0, 0, -.064)), (.013, .07, .006), 'clotted_blood', 'Forearm_' + suffix)
        tissue('Chest tear', (side * .12, 2.035, -.157), (.025, .063, .008), 'clotted_blood', 'Spine')
        for strand in range(5):
            tag(wire('Chest striation', [(side * .026, 1.96 + strand * .027, -.155), (side * .12, 1.97 + strand * .025, -.163), (side * .23, 2.01 + strand * .018, -.11)], .0035, 'muscle_dark'), 'Spine')
        line('Elbow tendon', elbow, wrist, .016, 'tendon', 'Forearm_' + suffix)
        tissue('Palm', (side * .44, .48, -.075), (.065, .115, .045), 'muscle_dark', 'Hand_' + suffix)
        for i in range(4):
            x = side * (.385 + i * .035)
            points = [(x, .44, -.08), (x + side * .02, .27 - i * .018, -.13), (x + side * .01, .14 - i * .01, -.22)]
            tag(wire('Finger tendon', points, .012, 'muscle'), 'Hand_' + suffix)
            line('Nail', points[-1], (points[-1][0], points[-1][1] - .035, -.26), .012, 'tendon', 'Hand_' + suffix, .002)
        hip = Vector((side * .15, 1.22, .045))
        knee = Vector((side * .18, .64, -.06))
        ankle = Vector((side * .17, .09, .02))
        muscle('Quadriceps', hip, knee, .095, 'Thigh_' + suffix)
        muscle('Calf', knee, ankle, .067, 'Shin_' + suffix)
        tissue('Knee blood', knee + Vector((0, 0, -.06)), (.044, .065, .014), 'clotted_blood', 'Shin_' + suffix)
        line('Shin tendon', knee, ankle, .017, 'tendon', 'Shin_' + suffix)
        tissue('Foot', (side * .17, .065, -.075), (.075, .06, .18), 'muscle_dark', 'Foot_' + suffix)
        for toe in [-1, 0, 1]:
            line('Toe', (side * .17 + toe * .035, .065, -.12), (side * .17 + toe * .04, .04, -.25), .016, 'muscle', 'Foot_' + suffix)
    line('Neck core', (0, 2.18, .02), (0, 2.41, -.045), .045, 'muscle_dark', 'Head')
    for x in [-.035, .035]:
        line('Neck cord', (x, 2.18, -.035), (x * .7, 2.42, -.1), .012, 'tendon', 'Head')
    tissue('Skull muscle', (0, 2.47, -.07), (.125, .19, .12), 'muscle', 'Head', 3)
    for side in [-1, 1]:
        tissue('Temple bundle', (side * .105, 2.49, -.035), (.034, .12, .095), 'muscle_dark', 'Head')
        tissue('Eye cavity', (side * .055, 2.505 + side * .008, -.176), (.038, .024, .022), 'cavity', 'Head')
        line('Cheek ridge', (side * .09, 2.47, -.15), (side * .055, 2.37, -.175), .016, 'tendon', 'Head')
    tissue('Mouth cavity', (0, 2.34, -.16), (.06, .09, .034), 'cavity', 'Head')
    tissue('Mouth blood', (.045, 2.27, -.152), (.045, .05, .018), 'clotted_blood', 'Head')
    tag(wire('Open jaw', [(-.08, 2.39, -.14), (-.07, 2.27, -.13), (.015, 2.23, -.18), (.075, 2.29, -.14), (.08, 2.4, -.13)], .02, 'muscle'), 'Head')
    for i in range(8):
        x = -.05 + i * .014
        line('Irregular tooth', (x, 2.4, -.192), (x + .002, 2.35 - (i % 3) * .012, -.196), .008, 'tendon', 'Head', .001)
    for i in range(8):
        y = 1.4 + i * .085
        tissue('Exposed spine', (0, y, .18), (.026, .025, .027), 'tendon', 'Spine', 1)
    # Fuse the anatomy into one deforming surface, retaining the nearest anatomical
    # weights. Separate bony edges, torn strands and clots remain layered details.
    organic_surface(api)


def organic_surface(api):
    names = ('Pelvis', 'Ribcage core', 'Abdomen', 'Pectoral', 'Latissimus',
             'Abdominal bundle', 'Deltoid', 'Upper arm', 'Forearm', 'Palm',
             'Quadriceps', 'Calf', 'Foot', 'Skull muscle', 'Temple bundle', 'Neck core')
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.name.split('.')[0] in names and 'rig_bone' in o]
    samples = []
    for obj in meshes:
        samples.extend((obj.matrix_world @ v.co, obj['rig_bone']) for v in obj.data.vertices)
    tree = KDTree(len(samples))
    for i, (p, _) in enumerate(samples): tree.insert(p, i)
    tree.balance()
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes: obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = 'Continuous exposed anatomy'
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    remesh = obj.modifiers.new('Sculpt union', 'REMESH')
    remesh.mode, remesh.voxel_size, remesh.adaptivity = 'VOXEL', .0105, .25
    remesh.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth = obj.modifiers.new('Relax anatomy', 'SMOOTH')
    smooth.factor, smooth.iterations = .7, 4
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    # Actual recessed sockets replace the earlier eyes stuck onto a rounded head.
    for side in [-1, 1]:
        cutter = api['ball']('Socket sculpt', (side*.055, 2.505+side*.008, -.183), (.047, .034, .046), 'cavity', 3)
        bpy.context.view_layer.objects.active = obj
        cut = obj.modifiers.new('Recessed orbit', 'BOOLEAN')
        cut.operation, cut.object = 'DIFFERENCE', cutter
        bpy.ops.object.modifier_apply(modifier=cut.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
    obj.data.materials.clear()
    obj.data.materials.append(api['M']['muscle'])
    for face in obj.data.polygons:
        face.material_index = 0
        face.use_smooth = True
    groups = {name: obj.vertex_groups.new(name=name) for name in set(b for _, b in samples)}
    for v in obj.data.vertices:
        nearby = tree.find_n(obj.matrix_world @ v.co, 4)
        weights = {}
        for _, index, distance in nearby:
            bone = samples[index][1]
            weights[bone] = weights.get(bone, 0) + 1/max(distance, .004)**2
        total = sum(weights.values())
        for bone, weight in weights.items(): groups[bone].add([v.index], weight/total, 'REPLACE')


def rig_creature(meshes, api):
    coord = api['coord']
    bpy.ops.object.select_all(action='DESELECT')
    data = bpy.data.armatures.new('CreatureSkeleton')
    rig = bpy.data.objects.new('CreatureRig', data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    specs = [('Root', HIP, HIP + Vector((0, .28, 0)), None),
             ('Spine', HIP, CHEST, 'Root'),
             ('Head', CHEST, Vector((0, 2.68, -.06)), 'Spine')]
    for side, suffix in [(1, 'L'), (-1, 'R')]:
        shoulder = (side * .28, 2.12, .02)
        elbow = (side * .38, 1.31, -.015)
        wrist = (side * .44, .58, -.06)
        hip, knee, ankle = (side * .15, 1.22, .045), (side * .18, .64, -.06), (side * .17, .09, .02)
        specs += [('Arm_' + suffix, shoulder, elbow, 'Spine'), ('Forearm_' + suffix, elbow, wrist, 'Arm_' + suffix),
                  ('Hand_' + suffix, wrist, (side * .44, .26, -.19), 'Forearm_' + suffix),
                  ('Thigh_' + suffix, hip, knee, 'Root'), ('Shin_' + suffix, knee, ankle, 'Thigh_' + suffix),
                  ('Foot_' + suffix, ankle, (side * .17, .065, -.2), 'Shin_' + suffix)]
    for name, head, tail, parent in specs:
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = coord(head), coord(tail)
        if parent:
            bone.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj in meshes:
        if obj.vertex_groups:
            continue
        group = obj.vertex_groups.new(name=obj.get('rig_bone', 'Spine'))
        group.add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
    lengths = {name: (Vector(tail) - Vector(head)).length for name, head, tail, _ in specs}
    rest = {name: data.bones[name].matrix_local.to_quaternion() for name, _, _, _ in specs}
    rest_dirs = {name: coord(Vector(tail) - Vector(head)).normalized() for name, head, tail, _ in specs}

    def ik(a, c, upper, lower, pole):
        a, c = Vector(a), Vector(c)
        axis = (c - a).normalized()
        distance = min((c - a).length, (upper + lower) * .998)
        c = a + axis * distance
        along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
        height = math.sqrt(max(0, upper * upper - along * along))
        pole = Vector(pole)
        bend = pole - axis * pole.dot(axis)
        bend.normalize()
        return a + axis * along + bend * height, c

    def targets(phase, crawl):
        bob = math.cos(phase * 2) * (.025 if crawl else .014)
        hip = Vector((0, .86 + bob, .4)) if crawl else Vector((0, 1.19 + bob, .045))
        chest = Vector((0, .9 + bob, -.55)) if crawl else Vector((0, 2.15 + bob, .02))
        pose = {'Root': (hip, hip + Vector((0, .28, 0))), 'Spine': (hip, chest),
                'Head': (chest, chest + Vector((.015 * math.sin(phase), .5, -.08)))}
        for side, suffix in [(1, 'L'), (-1, 'R')]:
            cycle = phase + (math.pi if side < 0 else 0)
            if crawl:
                shoulder = chest + Vector((side * .3, -.02, .05))
                wrist = Vector((side * .42, .09 + max(0, math.sin(cycle)) * .16, -1.03 + math.cos(cycle) * .27))
                legcycle = cycle + math.pi
                foot = Vector((side * .34, .085 + max(0, math.sin(legcycle)) * .14, .95 + math.cos(legcycle) * .27))
                armpole = (side, .15, .15)
            else:
                shoulder = chest + Vector((side * .28, -.06, 0))
                wrist = Vector((side * .44, .59 + bob, -.04 - math.cos(cycle) * .2))
                foot = Vector((side * .17, .085 + max(0, math.sin(cycle)) * .12, .02 + math.cos(cycle) * .26))
                armpole = (side * .35, 0, .4)
            elbow, wrist = ik(shoulder, wrist, lengths['Arm_' + suffix], lengths['Forearm_' + suffix], armpole)
            hipjoint = hip + Vector((side * .15, 0, 0))
            knee, foot = ik(hipjoint, foot, lengths['Thigh_' + suffix], lengths['Shin_' + suffix], (side * .3, 0, -1))
            pose['Arm_' + suffix] = (shoulder, elbow)
            pose['Forearm_' + suffix] = (elbow, wrist)
            pose['Hand_' + suffix] = (wrist, wrist + Vector((0, -.02, -.34)) if crawl else wrist + Vector((0, -.32, -.13)))
            pose['Thigh_' + suffix] = (hipjoint, knee)
            pose['Shin_' + suffix] = (knee, foot)
            pose['Foot_' + suffix] = (foot, foot + Vector((0, -.025, -.22)))
        return pose

    bpy.context.scene.render.fps = 24
    actions = []
    for clip, frames in [('Idle', 49), ('Walk', 25), ('DropToCrawl', 17), ('Crawl', 17), ('Rise', 17), ('Roar', 33), ('Bash', 29), ('Fall', 25), ('FallCrawl', 25), ('Down', 25), ('GetUp', 33)]:
        if rig.animation_data:
            rig.animation_data.action = None
        for frame in range(1, frames + 1, 2):
            t = (frame - 1) / (frames - 1)
            phase = t * math.tau
            if clip in ['DropToCrawl', 'Rise']:
                mix = t * t * (3 - 2 * t)
                if clip == 'Rise': mix = 1 - mix
                upright, low = targets(0, False), targets(0, True)
                pose = {name: (upright[name][0].lerp(low[name][0], mix), upright[name][1].lerp(low[name][1], mix)) for name in upright}
            else:
                pose = targets(phase if clip != 'Idle' else 0, clip == 'Crawl')
                if clip == 'Idle':
                    a, b = pose['Head']
                    pose['Head'] = (a, b + Vector((math.sin(phase) * .015, 0, 0)))
            if clip in ['Roar', 'Bash']:
                lift = math.sin(t*math.pi)**2
                a, b = pose['Head']
                pose['Head'] = (a, b + Vector((.035*math.sin(phase*2), .035*lift, .12*lift)))
                for side, suffix in [(1, 'L'), (-1, 'R')]:
                    shoulder = pose['Arm_'+suffix][0]
                    if clip == 'Bash':
                        strike = max(0, min(1, (t-.48)*5))
                        wrist = Vector((side*.35, 2.5*(1-strike)+.3*strike, -.5-.5*strike))
                    else:
                        wrist = Vector((side*(.44+.2*lift), .59+.45*lift, -.1))
                    elbow, wrist = ik(shoulder, wrist, lengths['Arm_'+suffix], lengths['Forearm_'+suffix], (side, .1, .2))
                    pose['Arm_'+suffix] = (shoulder, elbow)
                    pose['Forearm_'+suffix] = (elbow, wrist)
                    pose['Hand_'+suffix] = (wrist, wrist+Vector((0,-.22,-.13)))
            if clip in ['Fall', 'FallCrawl', 'Down', 'GetUp']:
                amount = 1 if clip == 'Down' else (t if clip in ['Fall', 'FallCrawl'] else 1-t)
                amount = amount*amount*(3-2*amount)
                rotation = Matrix.Rotation(math.pi*.5*amount, 3, 'X')
                center = Vector((0, 1.19*(1-amount)+.22*amount, 0))
                pose = {name: (center+rotation@(a-Vector((0,1.19,0))), center+rotation@(b-Vector((0,1.19,0)))) for name,(a,b) in targets(0,False).items()}
                if clip == 'FallCrawl':
                    fallen_center = Vector((0,.22,0))
                    fallen_rotation = Matrix.Rotation(math.pi*.5, 3, 'X')
                    low, upright = targets(0, True), targets(0, False)
                    pose = {name: (low[name][0].lerp(fallen_center+fallen_rotation@(upright[name][0]-Vector((0,1.19,0))),amount), low[name][1].lerp(fallen_center+fallen_rotation@(upright[name][1]-Vector((0,1.19,0))),amount)) for name in low}
            for name, _, _, _ in specs:
                head, tail = pose[name]
                direction = coord(tail - head)
                rotation = rest_dirs[name].rotation_difference(direction.normalized()) @ rest[name]
                bone = rig.pose.bones[name]
                bone.rotation_mode = 'QUATERNION'
                matrix = Matrix.Translation(coord(head)) @ rotation.to_matrix().to_4x4()
                bone.matrix = matrix
                bone.scale.y = direction.length / lengths[name]
                bone.keyframe_insert(data_path='location', frame=frame)
                bone.keyframe_insert(data_path='rotation_quaternion', frame=frame)
                bone.keyframe_insert(data_path='scale', frame=frame)
                bpy.context.view_layer.update()
        rig.animation_data.action.name = clip
        actions.append(rig.animation_data.action)
    rig.animation_data.action = actions[0]
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, 49
    bpy.context.scene.frame_set(1)
    return rig
