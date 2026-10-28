"""Original low-poly station assets. Run with Blender --background --python this_file.

All dimensions and positions below use Godot coordinates (metres, Y up, -Z front).
No external assets, add-ons or downloads. A .blend library is saved outside res://.
"""
import bpy
import math
import random
import json
from array import array
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / 'assets' / 'models'
TEXTURES = ROOT / 'assets' / 'textures'
SOURCE = ROOT / 'art-source'
for folder in (MODELS, TEXTURES, SOURCE):
    folder.mkdir(parents=True, exist_ok=True)
(SOURCE / '.gdignore').write_text('')
random.seed(1703)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
M = {}


def mat(name, rgb, metal=0, emission=0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*rgb, 1)
    material.use_nodes = True
    node = material.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*rgb, 1)
    node.inputs['Roughness'].default_value = 0.78 if not metal else 0.48
    node.inputs['Metallic'].default_value = metal
    if emission:
        node.inputs['Emission Color'].default_value = (*rgb, 1)
        node.inputs['Emission Strength'].default_value = emission
    M[name] = material


mat('enamel', (0.16, 0.25, 0.21), 0.35)
mat('steel', (0.15, 0.18, 0.18), 0.7)
mat('black', (0.023, 0.029, 0.029))
mat('cream', (0.65, 0.62, 0.48))
mat('rust', (0.32, 0.12, 0.055), 0.35)
mat('wood', (0.29, 0.19, 0.095))
mat('fabric', (0.24, 0.28, 0.22))
mat('red', (0.48, 0.075, 0.035), 0.2)
mat('amber', (0.8, 0.31, 0.06), emission=0.7)
mat('screen', (0.12, 0.47, 0.32), emission=0.8)
mat('ivory', (0.56, 0.57, 0.46))
mat('entity', (0.035, 0.039, 0.038))
mat('eye', (0.73, 0.85, 0.68), emission=1.4)
mat('glass', (0.22, 0.34, 0.32), 0.55)


def coord(p):
    return Vector((p[0], -p[2], p[1]))


def finish(obj, name, material):
    obj.name = name
    obj.data.materials.append(M[material])
    return obj


def box(name, p, size, material, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=coord(p))
    obj = bpy.context.object
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('Worn edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, material)


def ball(name, p, size, material, detail=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=detail, radius=1, location=coord(p))
    obj = bpy.context.object
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, material)


def rod(name, a, b, radius, material, vertices=10, tip=None):
    a, b = coord(a), coord(b)
    direction = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
                                  radius2=radius if tip is None else tip,
                                  depth=direction.length, location=(a + b) / 2)
    obj = bpy.context.object
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = direction.to_track_quat('Z', 'Y')
    return finish(obj, name, material)


def wire(name, points, radius, material):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = radius
    curve.bevel_resolution = 0
    poly = curve.splines.new('POLY')
    poly.points.add(len(points) - 1)
    for point, value in zip(poly.points, points):
        point.co = (*coord(value), 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object, name, material)


def gauge(x, y, z, radius=0.1):
    rod('Gauge rim', (x, y, z + .025), (x, y, z - .025), radius, 'steel', 16)
    rod('Gauge face', (x, y, z - .026), (x, y, z - .03), radius * .83, 'cream', 16)
    rod('Needle', (x, y, z - .037), (x + radius * .47, y + radius * .42, z - .037), .007, 'black', 4)


def rivets(x, y, z, width, height):
    for sx in (-1, 1):
        for sy in (-1, 1):
            ball('Bolt', (x + sx * width / 2, y + sy * height / 2, z), (.015, .015, .009), 'steel')


def generator():
    box('Skid', (0, -.51, 0), (1.65, .16, 1.0), 'steel', .03)
    box('Fuel tank', (-.41, .07, 0), (.64, .77, .83), 'enamel', .07)
    box('Motor', (.28, -.06, 0), (.65, .65, .65), 'black', .06)
    for x in [.05, .17, .29, .41, .53]:
        box('Cooling fins', (x, -.01, 0), (.045, .72, .74), 'steel')
    box('Panel', (-.42, .18, -.45), (.59, .44, .06), 'cream', .02)
    gauge(-.55, .22, -.5, .09)
    ball('Start lamp', (-.26, .23, -.5), (.027, .027, .015), 'amber')
    box('Lever', (-.3, .06, -.52), (.08, .05, .07), 'red')
    rod('Cap', (-.41, .47, 0), (-.41, .51, 0), .095, 'steel')
    wire('Exhaust', [(.47, .2, .2), (.68, .4, .2), (.68, .72, .2), (.83, .74, .2)], .06, 'rust')
    for z in [-.44, .44]:
        wire('Safety frame', [(-.8, -.5, z), (-.8, .54, z), (.6, .54, z), (.8, -.5, z)], .033, 'steel')


def transmitter():
    box('Cabinet', (0, 0, 0), (1.47, 1.07, .61), 'enamel', .045)
    box('Faceplate', (0, .02, -.324), (1.35, .91, .04), 'cream', .018)
    for x in [-.45, -.15, .17]:
        gauge(x, .24, -.36, .115)
    box('Frequency glass', (0, -.025, -.359), (1.08, .12, .025), 'black')
    box('Frequency scale', (-.02, -.025, -.377), (1.0, .055, .012), 'screen')
    for x in [-.45, -.25, -.05, .15, .35, .55]:
        box('Dial tick', (x, -.015, -.39), (.008, .035, .008), 'cream')
        rod('Tuning knob', (x, -.26, -.35), (x, -.26, -.425), .055, 'black', 12)
    box('Tape slot', (.44, .25, -.363), (.2, .1, .018), 'black')
    rivets(0, .02, -.365, 1.2, .78)
    for x in [-.55, .55]:
        wire('Handle', [(x, -.36, -.37), (x, -.36, -.45), (x, .35, -.45), (x, .35, -.37)], .018, 'steel')
    wire('Radio cable', [(.65, -.25, 0), (.87, -.4, .1), (.9, -.63, .27), (.66, -.63, .43)], .026, 'black')


def power():
    box('Housing', (0, 0, 0), (.6, .9, .31), 'steel', .025)
    box('Cover', (0, 0, -.17), (.53, .82, .025), 'enamel', .01)
    box('Warning', (0, .18, -.188), (.23, .17, .008), 'cream')
    rod('Warning slash', (-.05, .2, -.2), (.05, .14, -.2), .018, 'black', 3)
    for x in [-.15, 0, .15]:
        box('Breaker', (x, -.12, -.205), (.085, .21, .06), 'black')
        box('Toggle', (x, -.08, -.25), (.045, .07, .05), 'red')
    ball('Power indicator', (0, .35, -.19), (.025, .025, .012), 'amber')
    rivets(0, 0, -.194, .44, .73)
    for x in [-.18, .18]:
        wire('Cable', [(x, -.45, .02), (x, -.6, .02), (x * 1.4, -.7, .02)], .025, 'black')


def door():
    box('Door panel', (0, 0, 0), (.14, 2.45, 1.86), 'enamel', .025)
    for side in [-1, 1]:
        for z in [-.82, .82]:
            box('Door reinforcement', (side * .079, 0, z), (.025, 2.27, .06), 'steel')
        for y in [-1.1, -.4, .4, 1.1]:
            box('Door crossbar', (side * .079, y, 0), (.025, .06, 1.7), 'steel')
        box('Handle plate', (side * .091, -.1, -.64), (.035, .25, .13), 'steel')
        rod('Door handle', (side * .17, -.1, -.64), (side * .17, -.1, -.43), .025, 'cream')


def cassette():
    box('Cassette', (0, 0, 0), (.32, .12, .21), 'black', .018)
    box('Paper label', (0, .064, 0), (.27, .008, .13), 'cream')
    for x in [-.072, .072]:
        rod('Tape reel', (x, .068, 0), (x, .077, 0), .033, 'steel', 12)
        rod('Spindle', (x, .078, 0), (x, .079, 0), .012, 'black', 8)
    box('Label stripe', (0, .071, -.065), (.25, .006, .013), 'red')


def fuel():
    box('Jerry can', (0, -.025, 0), (.39, .46, .24), 'red', .035)
    wire('Carry handle', [(-.1, .2, 0), (-.1, .3, 0), (.11, .3, 0), (.11, .2, 0)], .025, 'steel')
    rod('Cap', (-.15, .2, -.04), (-.15, .235, -.04), .055, 'steel')
    for z in [-.127, .127]:
        rod('Pressed rib', (-.12, -.17, z), (.12, .1, z), .012, 'rust', 5)
        rod('Pressed rib', (.12, -.17, z), (-.12, .1, z), .012, 'rust', 5)


def fuse():
    rod('Ceramic', (-.16, 0, 0), (.16, 0, 0), .047, 'cream', 12)
    for sign in [-1, 1]:
        rod('End cap', (sign * .11, 0, 0), (sign * .17, 0, 0), .052, 'steel', 12)
        box('Contact', (sign * .19, 0, 0), (.08, .025, .065), 'steel')


def key():
    # Solid stylized bow avoids alpha and remains readable from a distance.
    rod('Bow', (-.09, 0, 0), (-.09, .025, 0), .065, 'rust', 12)
    box('Shaft', (.025, .012, 0), (.2, .025, .025), 'cream')
    for x in [.08, .13]:
        box('Tooth', (x, .012, .025), (.025, .025, .05), 'cream')
    box('Archive tag', (-.09, .031, 0), (.06, .006, .065), 'cream')


def battery():
    rod('Cell', (-.12, 0, 0), (.12, 0, 0), .052, 'amber', 12)
    rod('Positive cap', (.12, 0, 0), (.14, 0, 0), .028, 'steel', 12)
    rod('Band', (-.12, 0, 0), (-.065, 0, 0), .054, 'black', 12)


def medkit():
    box('First aid case', (0, 0, 0), (.39, .19, .28), 'cream', .025)
    box('Cross horizontal', (0, .1, 0), (.19, .01, .045), 'red')
    box('Cross vertical', (0, .1, 0), (.045, .01, .18), 'red')
    for x in [-.12, .12]:
        box('Clasp', (x, 0, -.145), (.045, .08, .025), 'steel')


def shelf():
    for x in [-1.12, 1.12]:
        for z in [-.33, .33]:
            box('Upright', (x, .85, z), (.065, 1.7, .065), 'steel')
    for y in [.15, .8, 1.6]:
        box('Shelf board', (0, y, 0), (2.4, .08, .79), 'wood')
    for x in [-.78, -.2, .6]:
        box('Stored box', (x, .43, .06), (.43, .46, .48), 'enamel', .015)
        box('Inventory label', (x, .43, -.185), (.18, .07, .008), 'cream')


def cot():
    for x in [-1.53, 1.53]:
        for z in [-.47, .47]:
            rod('Bed leg', (x, 0, z), (x, .72, z), .035, 'steel')
        wire('Bed end', [(x, .2, -.49), (x, 1.02, -.49), (x, 1.02, .49), (x, .2, .49)], .032, 'steel')
    box('Mattress', (0, .59, 0), (3.05, .24, 1.04), 'fabric', .055)
    box('Blanket', (.28, .725, 0), (2.23, .05, 1.07), 'enamel')
    box('Pillow', (-1.08, .78, 0), (.55, .2, .72), 'cream', .06)
    for z in [-.4, -.2, 0, .2, .4]:
        box('Blanket seam', (.28, .753, z), (2.2, .008, .015), 'black')


def locker():
    box('Locker', (0, 1.1, 0), (.85, 2.2, .6), 'enamel', .025)
    box('Door inset', (0, 1.13, -.312), (.74, 2.0, .025), 'steel')
    for y in [.45, .5, .55, 1.85, 1.9, 1.95]:
        box('Vent', (0, y, -.328), (.46, .018, .012), 'black')
    box('Number plate', (0, 1.62, -.335), (.17, .1, .012), 'cream')
    wire('Handle', [(.25, .96, -.34), (.25, .96, -.39), (.25, 1.2, -.39), (.25, 1.2, -.34)], .016, 'rust')


def barrel():
    rod('Barrel', (0, .05, 0), (0, .9, 0), .34, 'rust', 16)
    for y in [.1, .27, .66, .85]:
        rod('Barrel hoop', (0, y, 0), (0, y + .035, 0), .355, 'steel', 16)
    rod('Bung', (.16, .9, 0), (.16, .925, 0), .045, 'black')


def desk():
    box('Desktop', (0, 1.0, 0), (2.5, .12, .85), 'wood', .025)
    for x in [-1.05, 1.05]:
        for z in [-.31, .31]:
            box('Desk leg', (x, .47, z), (.06, .94, .06), 'steel')
    box('Drawers', (.8, .75, 0), (.53, .39, .7), 'enamel')
    for y in [.67, .85]:
        box('Drawer handle', (.8, y, -.37), (.2, .025, .045), 'steel')


def chair():
    box('Seat', (0, .46, 0), (.48, .08, .45), 'wood', .02)
    box('Back', (0, .82, .21), (.48, .35, .07), 'wood', .02)
    for x in [-.19, .19]:
        for z in [-.17, .17]:
            rod('Chair leg', (x * 1.15, 0, z * 1.15), (x, .47, z), .018, 'steel')
        rod('Back support', (x, .4, .2), (x, .97, .2), .017, 'steel')


def crate():
    box('Crate core', (0, .37, 0), (.8, .7, .7), 'wood', .015)
    for x in [-.33, .33]:
        box('Lid brace', (x, .75, 0), (.06, .05, .75), 'steel')
    for z in [-.36, .36]:
        rod('Diagonal brace', (-.35, .07, z), (.35, .68, z), .025, 'cream', 4)


def lamp():
    box('Fixture', (0, 0, 0), (1.25, .09, .28), 'steel', .025)
    for z in [-.065, .065]:
        rod('Fluorescent tube', (-.53, -.06, z), (.53, -.06, z), .028, 'cream', 10)
    for x in [-.4, .4]:
        box('Grille', (x, -.095, 0), (.018, .025, .26), 'steel')


def flashlight():
    rod('Handle', (0, 0, .15), (0, 0, -.1), .055, 'black', 12)
    rod('Reflector', (0, 0, -.1), (0, 0, -.23), .06, 'steel', 12, .095)
    rod('Lens', (0, 0, -.23), (0, 0, -.236), .083, 'glass', 16)
    box('Switch', (0, .056, 0), (.03, .014, .07), 'red')


def avatar():
    for x in [-.13, .13]:
        box('Boot', (x, .1, -.05), (.19, .2, .37), 'black', .025)
        rod('Trouser leg', (x, .2, 0), (x, .86, 0), .11, 'enamel', 8)
        box('Knee patch', (x, .5, -.095), (.14, .18, .04), 'fabric')
    box('Jacket', (0, 1.12, 0), (.54, .61, .29), 'enamel', .08)
    box('Belt', (0, .88, 0), (.56, .075, .32), 'black')
    for x in [-.3, .3]:
        rod('Sleeve', (x, 1.34, 0), (x * 1.18, .8, -.015), .09, 'fabric', 8)
        ball('Glove', (x * 1.18, .75, -.03), (.08, .1, .075), 'black')
        box('Reflector stripe', (x, 1.3, -.08), (.1, .045, .16), 'cream')
    ball('Hood', (0, 1.59, 0), (.19, .23, .18), 'fabric', 2)
    box('Mask', (0, 1.56, -.17), (.23, .16, .08), 'black', .03)
    for x in [-.075, .075]:
        rod('Goggle', (x, 1.64, -.16), (x, 1.64, -.207), .061, 'glass', 12)
    rod('Respirator', (0, 1.52, -.2), (0, 1.52, -.29), .06, 'steel', 10)
    box('Backpack', (0, 1.16, .24), (.38, .49, .22), 'wood', .04)
    rod('Aerial', (.14, 1.3, .25), (.14, 1.92, .25), .008, 'black', 6)


def entity():
    ball('Torso', (0, 1.53, .06), (.25, .48, .15), 'entity', 2)
    ball('Pelvis', (0, 1.02, .03), (.16, .2, .13), 'black')
    for side in [-1, 1]:
        hip = (.12 * side, 1.08, .03)
        knee = (.19 * side, .54, -.07)
        ankle = (.17 * side, .1, .08)
        rod('Thigh', hip, knee, .082, 'entity', 7, .05)
        rod('Shin', knee, ankle, .047, 'entity', 7, .025)
        ball('Foot', (.17 * side, .045, -.055), (.07, .06, .19), 'black')
        shoulder = (.24 * side, 1.83, .035)
        elbow = (.43 * side, 1.18, -.045)
        wrist = (.48 * side, .62, -.12)
        rod('Upper arm', shoulder, elbow, .067, 'entity', 7, .04)
        rod('Forearm', elbow, wrist, .04, 'ivory', 7, .023)
        ball('Hand', (.48 * side, .57, -.12), (.055, .1, .045), 'entity')
        for finger in range(4):
            x = side * (.44 + finger * .025)
            wire('Long finger', [(x, .54, -.12), (x + side * .025, .36 - finger * .02, -.17), (x + side * .01, .29 - finger * .02, -.24)], .009, 'ivory')
    rod('Neck', (0, 1.89, .05), (.06, 2.1, -.02), .055, 'ivory', 8)
    head = ball('Head', (.065, 2.2, -.045), (.135, .25, .13), 'ivory', 2)
    head.rotation_euler.y = .16
    for x in [.013, .115]:
        ball('Eye socket', (x, 2.255, -.16), (.045, .055, .022), 'black', 2)
        ball('Pale pinhole', (x, 2.25, -.181), (.012, .01, .006), 'eye')
    ball('Mouth hollow', (.064, 2.085, -.163), (.055, .09, .015), 'black', 2)
    for i in range(6):
        x = .023 + i * .016
        rod('Tooth', (x, 2.14, -.18), (x, 2.105 + (i % 2) * .008, -.18), .007, 'cream', 4, .001)
    for i in range(7):
        y = 1.35 + i * .065
        wire('Rib cable', [(-.16, y, -.04), (0, y - .035, -.105), (.16, y, -.04)], .013, 'rust')
    for i in range(8):
        x = (i - 3.5) * .046
        wire('Frayed shroud', [(x, 1.65, .15), (x * 1.25, 1.12, .18), (x * 1.6, .65 + (i % 3) * .13, .12)], .025, 'black')


def radio_rack():
    box('Rack cabinet', (0, 1, 0), (.78, 2, .6), 'enamel', .025)
    for y in [.25, .67, 1.09, 1.51]:
        box('Rack module', (0, y, -.317), (.7, .36, .035), 'cream', .01)
        gauge(-.18, y + .035, -.35, .075)
        box('Tuning scale', (.12, y + .045, -.35), (.24, .075, .015), 'screen')
        for x in [.05, .22]:
            rod('Dial', (x, y - .09, -.35), (x, y - .09, -.4), .036, 'black', 10)
        for x in [-.29, .29]:
            box('Screw', (x, y + .12, -.343), (.018, .018, .012), 'steel')
    for x in [-.28, .28]:
        box('Rack foot', (x, .025, 0), (.1, .05, .7), 'steel')


def recorder():
    box('Recorder base', (0, 0, 0), (.68, .17, .47), 'enamel', .025)
    box('Top panel', (0, .095, 0), (.63, .025, .43), 'cream')
    for x in [-.17, .17]:
        rod('Reel', (x, .11, -.04), (x, .14, -.04), .13, 'black', 18)
        rod('Reel centre', (x, .14, -.04), (x, .145, -.04), .035, 'steel', 12)
        for i in range(3):
            a = i * math.tau / 3
            rod('Reel spoke', (x, .146, -.04), (x + math.cos(a) * .11, .146, -.04 + math.sin(a) * .11), .009, 'steel', 4)
    for x in [-.2, -.1, 0, .1, .2]:
        box('Transport key', (x, .125, .15), (.07, .03, .07), 'red' if x == -.2 else 'black')


def hand():
    rod('Sleeve', (0, -.17, .28), (0, -.04, .055), .078, 'enamel', 10, .065)
    ball('Gloved palm', (0, 0, .02), (.075, .075, .08), 'black', 2)
    for x in [-.052, -.018, .018, .052]:
        rod('Finger', (x, .02, .01), (x, .052, -.05), .018, 'black', 7)
    rod('Thumb', (-.065, 0, .04), (-.05, .065, -.01), .024, 'black', 8)


builders = {name: globals()[name] for name in ['generator', 'transmitter', 'power', 'door',
    'cassette', 'fuel', 'fuse', 'key', 'battery', 'medkit', 'shelf', 'cot', 'locker',
    'barrel', 'desk', 'chair', 'crate', 'lamp', 'flashlight', 'avatar', 'entity',
    'radio_rack', 'recorder', 'hand']}
catalog = []
for index, (name, builder) in enumerate(builders.items()):
    before = set(bpy.data.objects)
    builder()
    meshes = [obj for obj in bpy.data.objects if obj not in before and obj.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    triangles = sum(len(face.vertices) - 2 for face in obj.data.polygons)
    bpy.ops.export_scene.gltf(filepath=str(MODELS / f'{name}.glb'), export_format='GLB',
                              use_selection=True, export_yup=True, export_animations=False,
                              export_cameras=False, export_lights=False)
    catalog.append({'model': name, 'triangles': triangles})
    obj.location = coord(((index % 5) * 4, 0, (index // 5) * 4))
    print(f'ART_MODEL {name}: {triangles} triangles')


def texture(name, base, tile=False):
    n = 512
    image = bpy.data.images.new(name, n, n)
    pixels = array('f')
    rng = random.Random(173)
    grids = [(frequency, amount, [rng.uniform(-1, 1) for _ in range(frequency * frequency)])
             for frequency, amount in [(4, .04), (16, .022), (64, .012)]]
    for y in range(n):
        for x in range(n):
            variation = rng.uniform(-.016, .016)
            for frequency, amount, grid in grids:
                xx, yy = x / n * frequency, y / n * frequency
                ix, iy = int(xx), int(yy)
                fx, fy = xx - ix, yy - iy
                fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
                a = grid[(iy % frequency) * frequency + ix % frequency]
                b = grid[(iy % frequency) * frequency + (ix + 1) % frequency]
                c = grid[((iy + 1) % frequency) * frequency + ix % frequency]
                d = grid[((iy + 1) % frequency) * frequency + (ix + 1) % frequency]
                variation += ((a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy) * amount
            if tile:
                seam = x % 64 < 2 or y % 64 < 2
                variation += -.12 if seam else (.017 if (x // 64 + y // 64) % 2 else -.017)
            pixels.extend([max(.02, min(.95, c + variation)) for c in base] + [1])
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(TEXTURES / f'{name}.png')
    image.file_format = 'PNG'
    image.save()
    bpy.data.images.remove(image)


texture('plaster', (.57, .55, .46))
texture('paint', (.19, .28, .25))
texture('floor', (.29, .28, .24), tile=True)
texture('concrete', (.3, .32, .3))
(MODELS / 'catalog.json').write_text(json.dumps(catalog, indent=2), encoding='utf-8')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'station_assets.blend'))
print('ART_COMPLETE', len(catalog), 'models,', sum(item['triangles'] for item in catalog), 'triangles')
