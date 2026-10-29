"""Close-up prop library. Godot metres/Y-up; original geometry, shared material atlas.

Run last after the environment/vehicle/hospital builders. The GLBs deliberately
omit raster images: ArtFactory binds one shared atlas, avoiding per-GLB copies.
"""
import bpy
import math
import json
from array import array
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'assets/models'
SOURCE = ROOT/'art-source/detailed-props'
SOURCE.mkdir(exist_ok=True)
CAT = json.loads((OUT/'catalog.json').read_text(encoding='utf-8'))
M = {}
ATLAS = bpy.data.images.load(str(ROOT/'assets/textures/props_materials_generated.png'))
ATLAS.filepath="//../../assets/textures/props_materials_generated.png"

def detail_map(name, normal=False):
    size=512; pixels=array('f')
    # Independently authored microdetail, not a conversion of the generated albedo.
    for y in range(size):
        for x in range(size):
            quadrant=(x>=size//2)+2*(y>=size//2)
            grain=math.sin(x*.73+math.sin(y*.12)*3)*math.sin(y*.43+x*.07)
            fine=math.sin(x*2.13+y*1.37)*.35
            if normal:
                a=.022 if quadrant==2 else .012
                pixels.extend((.5+a*grain,.5+a*fine,1,1))
            else:
                rough=[.64,.79,.43,.32][quadrant]+(grain+fine)*.035
                metal=[.28,0,0,.92][quadrant]
                pixels.extend((1,rough,metal,1))
    image=bpy.data.images.new(name,width=size,height=size,alpha=False)
    image.colorspace_settings.name='Non-Color'; image.pixels.foreach_set(pixels)
    image.filepath_raw=str(ROOT/'assets/textures'/f'{name}.png'); image.file_format='PNG'; image.save();image.filepath='//../../assets/textures/'+name+'.png'
    return image

NORMAL=detail_map('props_detail_normal',True)
ORM=detail_map('props_detail_orm')

def material(name,color,metal=0,rough=.5,tile=None):
    m=bpy.data.materials.new('Prop '+name);m.use_nodes=True;m.diffuse_color=(*color,1)
    m['atlas_tile']=-1 if tile is None else tile
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    if tile is not None:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=ATLAS
        m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
    M[name]=m

for args in [('Walnut',(.19,.09,.035),0,.43,2),('Blued steel',(.09,.105,.12),.92,.32,3),('Paint',(.21,.25,.18),.28,.64,0),('Rubber',(.035,.037,.04),0,.79,1),('Brushed alloy',(.46,.49,.51),.86,.31),('Brass',(.52,.33,.11),.78,.32),('Ivory polymer',(.72,.72,.62),0,.68),('Paper',(.72,.69,.55),0,.91),('Red polymer',(.33,.035,.018),0,.52),('Green polymer',(.07,.24,.13),0,.59),('Blood',(.16,.008,.004),0,.3),('Glass',(.29,.38,.4),.15,.19),('Black recess',(.006,.008,.009),0,.87)]:material(*args)

def coord(p):return Vector((p[0],-p[2],p[1]))
def finish(o,name,mat):
    o.name=name;o.data.materials.append(M[mat]);return o
def box(name,p,size,mat,bevel=.003):
    bpy.ops.mesh.primitive_cube_add(size=1,location=coord(p));o=bpy.context.object
    o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        b=o.modifiers.new('Rounded manufactured edge','BEVEL');b.width=bevel;b.segments=3
        bpy.ops.object.modifier_apply(modifier=b.name)
        n=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');n.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=n.name)
    return finish(o,name,mat)
def rod(name,a,b,r,mat,n=24,tip=None):
    av,bv=coord(a),coord(b);d=bv-av
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=r if tip is None else tip,depth=d.length,location=(av+bv)/2)
    o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    for poly in o.data.polygons:poly.use_smooth=len(poly.vertices)==4
    return finish(o,name,mat)
def ball(name,p,size,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=coord(p));o=bpy.context.object
    o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for f in o.data.polygons:f.use_smooth=True
    return finish(o,name,mat)
def wire(name,points,r,mat,n=6):
    vertices=[];faces=[]
    for i,p in enumerate(points):
        d=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        rot=coord(d).to_track_quat('Z','Y')
        for j in range(n):vertices.append(coord(p)+rot@Vector((r*math.cos(j*math.tau/n),r*math.sin(j*math.tau/n),0)))
    for i in range(len(points)-1):
        for j in range(n):a=i*n+j;b=i*n+(j+1)%n;faces.append((a,b,b+n,a+n))
    return mesh(name,vertices,faces,mat,True)
def mesh(name,vertices,faces,mat,smooth=False):
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
    for f in data.polygons:f.use_smooth=smooth
    return finish(o,name,mat)
def ring(name,p,outer,inner,depth,mat,axis='z',n=32):
    # Annulus with a real bore; no flat black disc over the muzzle.
    verts=[]
    for h,r in [(-depth/2,outer),(depth/2,outer),(-depth/2,inner),(depth/2,inner)]:
        for i in range(n):
            a=i*math.tau/n;v=(r*math.cos(a),r*math.sin(a),h)
            if axis=='y':v=(v[0],v[2],v[1])
            if axis=='x':v=(v[2],v[0],v[1])
            verts.append(coord(tuple(p[k]+v[k] for k in range(3))))
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
    return mesh(name,verts,faces,mat,True)
def loft(name,sections,mat,n=16):
    verts=[]
    for z,y,w,h in sections:
        for i in range(n):
            a=i*math.tau/n;verts.append(coord((math.copysign(abs(math.cos(a))**.65,math.cos(a))*w,y+math.sin(a)*h,z)))
    faces=[tuple(reversed(range(n))),tuple((len(sections)-1)*n+i for i in range(n))]
    for row in range(len(sections)-1):
        for j in range(n):a=row*n+j;b=row*n+(j+1)%n;faces.append((a,b,b+n,a+n))
    return mesh(name,verts,faces,mat,True)
def screw(p,r=.004,axis='z'):
    delta={'x':(r*.2,0,0),'y':(0,r*.2,0),'z':(0,0,r*.2)}[axis]
    rod('Slotted fastener',p,tuple(p[k]+delta[k] for k in range(3)),r,'Brushed alloy',12)
    if axis=='z':box('Screw slot',(p[0],p[1],p[2]+delta[2]*1.1),(r*1.3,r*.2,.0005),'Black recess',0)
    elif axis=='x':box('Screw slot',(p[0]+delta[0]*1.1,p[1],p[2]),(.0005,r*1.3,r*.2),'Black recess',0)
def label(text,p,size=.015,rot=(math.pi/2,0,0),mat='Black recess'):
    curve=bpy.data.curves.new('Engraved marking','FONT');curve.body=text;curve.size=size;curve.align_x='CENTER';curve.extrude=0;curve.resolution_u=1
    o=bpy.data.objects.new('Marking '+text,curve);bpy.context.collection.objects.link(o);o.location=coord(p);o.rotation_euler=rot
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');finish(bpy.context.object,o.name,mat)
def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def uv_map(o):
    for old in list(o.data.uv_layers):o.data.uv_layers.remove(old)
    uv=o.data.uv_layers.new(name='UVMap');o.data.uv_layers.active=uv;uv.active_render=True
    for face in o.data.polygons:
        mat=o.data.materials[face.material_index];tile=mat.get('atlas_tile',-1)
        # Original surface orientation, in metres, keeps grain consistent along the object.
        normal=face.normal;axes=sorted(range(3),key=lambda a:abs(normal[a]))[:2]
        for li in face.loop_indices:
            pos=o.matrix_world@o.data.vertices[o.data.loops[li].vertex_index].co
            u=(pos[axes[0]]*1.35+.21)%1;v=(pos[axes[1]]*1.35+.37)%1
            if tile>=0:u=(tile%2)*.5+.015+u*.47;v=(tile//2)*.5+.015+v*.47
            uv.data[li].uv=(u,v)
def join_group(objects,name,parent=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    if parent:
        world=o.matrix_world.copy();o.parent=parent;o.matrix_world=world
    return o
def export(name,articulated=False):
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for o in objects:uv_map(o)
    if articulated:
        pivot=bpy.data.objects.new('BreechPivot',None);bpy.context.collection.objects.link(pivot);pivot.location=coord((0,.015,-.055))
        moving=[o for o in objects if o.get('breech',False)]
        join_group(moving,'BarrelAssembly',pivot)
        join_group([o for o in objects if o not in moving],'StockAndReceiver')
    else:join_group(objects,name)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/f'{name}.blend'),relative_remap=False)
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_image_format='NONE',export_cameras=False,export_lights=False)
    tri=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
    CAT[:]=[e for e in CAT if e['model']!=name];CAT.append({'model':name,'triangles':tri,'detail_version':13})
    print('DETAILED_PROP',name,tri,flush=True)

def shotgun():
    loft('Shaped walnut stock',[(.07,-.012,.027,.045),(.14,-.035,.027,.047),(.2,-.065,.032,.053),(.29,-.07,.041,.085),(.42,-.065,.043,.095)],'Walnut')
    loft('Ribbed butt pad',[(.417,-.065,.044,.096),(.438,-.065,.045,.096),(.446,-.065,.039,.09)],'Rubber')
    for y in [-.12,-.08,-.04,0]:wire('Butt pad traction',[(-.041,y,.44),(0,y,.447),(.041,y,.44)],.0013,'Black recess')
    box('Machined receiver',(0,.012,.012),(.073,.09,.145),'Blued steel',.01)
    for x in [-.037,.037]:
        box('Receiver sideplate',(x,.012,.025),(.002,.057,.1),'Brushed alloy',.005)
        for z in [-.012,.058]:screw((x+math.copysign(.001,x),.012,z),axis='x')
        wire('Fine side engraving',[(x,.025,-.004),(x,.034,.013),(x,.026,.032),(x,.035,.05)],.0006,'Blued steel',4)
    wire('Oval trigger guard',[(0,-.027,-.022),(0,-.074,-.025),(0,-.092,-.005),(0,-.09,.068),(0,-.065,.092),(0,-.028,.076)],.0048,'Blued steel',8)
    for z in [.012,.044]:wire('Curved trigger',[(0,-.03,z),(0,-.058,z-.012),(0,-.072,z-.002)],.0032,'Brushed alloy',8)
    rod('Hinge axle',(-.042,.015,-.055),(.042,.015,-.055),.009,'Brushed alloy',24)
    wire('Top opening lever',[(0,.061,.04),(.018,.065,.066),(.024,.064,.09)],.006,'Blued steel',10)
    box('Safety slider',(0,.045,.11),(.013,.007,.027),'Brushed alloy',.003)
    before=set(bpy.context.scene.objects)
    for x in [-.0215,.0215]:
        ring('Hollow barrel',(x,.043,-.372),.0207,.0105,.63,'Blued steel',n=40)
        ring('Polished muzzle crown',(x,.043,-.688),.0209,.0105,.003,'Brushed alloy',n=40)
        ring('Dark bore lining',(x,.043,-.65),.0106,.0098,.07,'Black recess',n=32)
        rod('Bore depth',(x,.043,-.53),(x,.043,-.532),.0105,'Black recess',32)
        ring('Chamber rim',(x,.043,-.053),.0207,.0115,.004,'Brushed alloy',n=32)
    box('Top barrel rib',(0,.064,-.367),(.009,.007,.61),'Blued steel',.001)
    for z in [-.15,-.28,-.41,-.54]:box('Rib knurl',(0,.068,z),(.009,.001,.002),'Brushed alloy',0)
    loft('Sculpted fore-end',[(-.39,-.002,.029,.017),(-.35,-.008,.041,.027),(-.15,-.008,.042,.028),(-.095,0,.025,.019)],'Walnut')
    for x in [-.038,.038]:
        for i in range(16):
            z=-.33+i*.011
            wire('Fine diamond grip',[(x,-.025,z),(x*.95,-.038,z+.018)],.0007,'Black recess',4)
            wire('Fine diamond grip',[(x,-.025,z+.018),(x*.95,-.038,z)],.0007,'Black recess',4)
    ball('Brass front bead',(0,.076,-.666),(.004,.004,.004),'Brass')
    for o in set(bpy.context.scene.objects)-before:o['breech']=True

def flashlight():
    rod('Anodised tube',(0,0,.13),(0,0,-.09),.041,'Blued steel',40)
    for z in [.08,.095,.11,.125]:ring('Tail thread',(0,0,z),.044,.039,.006,'Rubber')
    for z in [-.052,-.035,-.018,0,.018,.036]:ring('Grip ring',(0,0,z),.044,.04,.008,'Rubber')
    for i in range(20):
        a=i*math.tau/20
        wire('Grip knurl',[(.043*math.cos(a),.043*math.sin(a),-.06),(.044*math.cos(a+.15),.044*math.sin(a+.15),.06)],.001,'Blued steel',4)
    ring('Flared head',(0,0,-.12),.067,.052,.07,'Blued steel',n=48)
    ring('Bezel lip',(0,0,-.16),.071,.06,.018,'Rubber',n=48)
    for i in range(6):
        a=i*math.tau/6
        rod('Cooling rib',(.067*math.cos(a),.067*math.sin(a),-.145),(.067*math.cos(a),.067*math.sin(a),-.095),.004,'Brushed alloy',8)
    # Five concentric steps form an open reflector bowl around the LED.
    for i in range(5):ring('Reflector',(0,0,-.153+i*.009),.059-i*.008,.05-i*.008,.012,'Brushed alloy',n=48)
    rod('LED board',(0,0,-.112),(0,0,-.116),.019,'Brass',24)
    box('LED emitter',(0,0,-.119),(.011,.011,.002),'Ivory polymer',.001)
    rod('Protective lens',(0,0,-.163),(0,0,-.165),.059,'Glass',48)
    box('Switch rubber boot',(0,.043,.065),(.025,.013,.035),'Rubber',.006)
    box('Switch slider',(0,.051,.06),(.016,.007,.018),'Green polymer',.003)
    ring('Tail bumper',(0,0,.139),.045,.028,.014,'Rubber')
    wire('Wrist lanyard',[(-.025,-.015,.146),(-.05,-.06,.185),(-.035,-.09,.235),(0,-.07,.26),(.016,-.04,.215),(-.025,-.015,.146)],.0023,'Rubber')

def shell():
    rod('Ribbed red hull',(0,-.024,0),(0,.032,0),.012,'Red polymer',32)
    for i in range(14):
        a=i*math.tau/14;rod('Hull seam',(.012*math.cos(a),-.022,.012*math.sin(a)),(.012*math.cos(a),.028,.012*math.sin(a)),.0004,'Red polymer',4)
    rod('Brass head',(0,-.039,0),(0,-.024,0),.0126,'Brass',32)
    ring('Extraction rim',(0,-.038,0),.0133,.009,.002,'Brass','y')
    rod('Primer',(0,-.0405,0),(0,-.041,0),.0038,'Brushed alloy',20)
    for i in range(6):a=i*math.tau/6;wire('Star crimp',[(0,.0325,0),(.01*math.cos(a),.0325,.01*math.sin(a))],.0006,'Black recess',4)

def medkit():
    box('Case lower',(0,-.019,0),(.39,.15,.28),'Paint',.022)
    box('Water seal',(0,.051,0),(.392,.008,.282),'Rubber',.018)
    box('Rounded lid',(0,.078,0),(.398,.05,.288),'Ivory polymer',.018)
    box('First aid patch',(0,.105,0),(.122,.002,.122),'Green polymer',.005)
    box('White cross',(0,.107,0),(.085,.002,.025),'Ivory polymer',.002)
    box('White cross',(0,.108,0),(.025,.002,.085),'Ivory polymer',.002)
    wire('Carry handle',[(-.07,.012,-.149),(-.07,-.028,-.175),(.07,-.028,-.175),(.07,.012,-.149)],.009,'Rubber',10)
    for x in [-.14,.14]:
        box('Latch',(x,.039,-.149),(.032,.06,.012),'Brushed alloy',.004)
        rod('Latch hinge',(x-.019,.017,-.157),(x+.019,.017,-.157),.004,'Brass',12)
        screw((x,.045,-.157),.003)
        rod('Rear hinge',(x-.026,.052,.147),(x+.026,.052,.147),.007,'Brushed alloy',16)
        for z in [-.09,.09]:box('Rubber foot',(x,-.101,z),(.04,.009,.04),'Rubber',.004)

def battery():
    rod('Cell sleeve',(-.105,0,0),(.105,0,0),.043,'Paint',40)
    for x in [-.105,.105]:ring('Crimped steel end',(x,0,0),.044,.036,.008,'Brushed alloy','x')
    rod('Negative terminal',(-.11,0,0),(-.112,0,0),.033,'Brushed alloy',32)
    rod('Positive button',(.108,0,0),(.123,0,0),.017,'Brass',24)
    ring('Insulation washer',(.108,0,0),.032,.017,.003,'Rubber','x')
    box('Cell paper label',(0,.043,0),(.125,.002,.045),'Paper',.001)
    label('1.5 V',(0,.044,-.012),.018,(0,0,0))

def fuel():
    box('Pressed can body',(0,-.026,0),(.38,.44,.235),'Paint',.034)
    box('Welded perimeter',(0,-.028,0),(.386,.446,.018),'Blued steel',.025)
    for z in [-.12,.12]:
        for sign in [-1,1]:wire('Stamped reinforcing rib',[(-.125,-.16*sign,z),(0,-.02,z),(.125,.12*sign,z)],.008,'Paint',8)
    for z in [-.05,.05]:wire('Can handle',[(-.07,.17,z),(-.07,.258,z),(.115,.258,z),(.15,.17,z)],.014,'Paint',10)
    rod('Filler neck',(-.12,.177,0),(-.14,.21,0),.046,'Brushed alloy',32)
    rod('Sealed filler cap',(-.14,.211,0),(-.145,.23,0),.05,'Paint',32)
    wire('Cap locking bail',[(-.18,.225,0),(-.185,.25,0),(-.1,.25,0),(-.1,.225,0)],.004,'Brushed alloy',6)
    label('FUEL',(0,.025,-.124),.031,(math.pi/2,0,0),'Paper')

def fuse():
    rod('Ceramic cartridge',(-.12,0,0),(.12,0,0),.041,'Ivory polymer',32)
    for x in [-.14,.14]:
        rod('Nickel cap',(x-.025,0,0),(x+.025,0,0),.044,'Brushed alloy',32)
        box('Copper blade',(x+math.copysign(.04,x),0,0),(.05,.014,.053),'Brass',.001)
        ring('Cap seam',(x,0,0),.045,.043,.003,'Blued steel','x')
    label('16A  500V',(0,.041,-.011),.017,(0,0,0))

def key(kind):
    if kind=='car_key':
        box('Moulded key head',(-.085,.014,0),(.085,.027,.07),'Rubber',.017)
        ring('Keyring',(-.11,.014,.043),.029,.025,.003,'Brushed alloy','y')
    else:
        ring('Machined key bow',(-.079,.012,0),.044,.027,.012,'Brass','y')
        wire('Tag retaining ring',[(-.115,.02,-.012),(-.145,.025,-.027),(-.165,.02,.005),(-.14,.015,.03),(-.115,.02,-.012)],.002,'Brushed alloy')
        tag_material={'key':'Paper','service_key':'Paint','yard_key':'Green polymer','hospital_key':'Red polymer'}[kind]
        tag_size={'key':(.065,.01,.055),'service_key':(.05,.01,.07),'yard_key':(.07,.01,.043),'hospital_key':(.061,.01,.057)}[kind]
        box('Worn identity tag',(-.17,.014,.035),tag_size,tag_material,.007)
        label({'key':'A','service_key':'S','yard_key':'Y','hospital_key':'H'}[kind],(-.17,.020,.028),.022,(0,0,0),'Black recess' if kind=='key' else 'Paper')
    box('Key blade',(.026,.013,0),(.19,.012,.021),'Brass',.001)
    for i in range(5):box('Cut key tooth',(.02+i*.019,.013,.013),(.012,.012,.014+(i%3)*.005),'Brass',.001)
    wire('Keyway groove',[(-.025,.02,-.003),(.114,.02,-.003)],.0012,'Blued steel',4)

def cassette():
    box('Cassette shell',(0,0,0),(.31,.037,.20),'Rubber',.012)
    box('Worn paper label',(0,.020,.005),(.27,.002,.125),'Paper',.004)
    box('Tape window',(0,.022,.015),(.163,.001,.052),'Black recess',.005)
    for x in [-.067,.067]:
        ring('Reel teeth',(x,.025,.015),.029,.012,.005,'Ivory polymer','y',24)
        for i in range(6):
            a=i*math.tau/6;box('Spindle lug',(x+.013*math.cos(a),.029,.015+.013*math.sin(a)),(.004,.003,.004),'Rubber',0)
    for x in [-.13,.13]:
        for z in [-.074,.074]:screw((x,.021,z),.003,'y')
    box('Recording stripe',(0,.023,-.056),(.245,.002,.013),'Red polymer',0)
    label('LAST SIGNAL  /  A',(0,.024,-.047),.014,(0,0,0))

def air_filter():
    rod('Inner cartridge',(0,-.14,0),(0,.14,0),.071,'Black recess',32)
    for y in [-.155,.155]:ring('Filter end seal',(0,y,0),.095,.046,.023,'Rubber','y')
    for i in range(48):
        a=i*math.tau/48;r=.086
        wire('Pleated paper fold',[(r*math.cos(a),-.14,r*math.sin(a)),((r+.007)*math.cos(a),0,(r+.007)*math.sin(a)),(r*math.cos(a),.14,r*math.sin(a))],.0028,'Paper',4)
    for y in [-.1,0,.1]:ring('Retaining mesh band',(0,y,0),.092,.089,.005,'Brushed alloy','y')

def car_battery():
    box('Battery moulding',(0,-.012,0),(.32,.24,.2),'Rubber',.012)
    box('Sealed lid',(0,.12,0),(.33,.025,.21),'Rubber',.007)
    for x in [-.11,-.065,-.02,.025,.07,.115]:rod('Cell cap',(x,.134,0),(x,.141,0),.017,'Rubber',16)
    for x in [-.12,.12]:
        rod('Lead terminal',(x,.135,-.065),(x,.17,-.065),.017,'Brushed alloy',20,tip=.014)
        ring('Terminal washer',(x,.139,-.065),.024,.016,.005,'Red polymer' if x<0 else 'Blued steel','y')
    wire('Folding carry handle',[(-.09,.135,.052),(-.09,.19,.052),(.09,.19,.052),(.09,.135,.052)],.008,'Rubber',8)
    box('Battery specification label',(0,.015,-.102),(.22,.09,.002),'Paper',.001)
    label('12V / 60Ah',(0,.018,-.104),.023)
    for x in [-.12,.12]:box('Case reinforcing rib',(x,-.02,-.105),(.006,.19,.005),'Rubber',.001)

def spark_plugs():
    for i in range(4):
        x=-.09+i*.06
        rod('Ceramic insulator',(x,-.015,0),(x,.057,0),.013,'Ivory polymer',24)
        for y in [.01,.02,.03,.04]:ring('Ceramic rib',(x,y,0),.016,.012,.005,'Ivory polymer','y',12)
        rod('Contact nut',(x,.058,0),(x,.076,0),.007,'Brushed alloy',16)
        rod('Hex plug seat',(x,-.031,0),(x,-.014,0),.019,'Brushed alloy',6)
        rod('Threaded shell',(x,-.065,0),(x,-.032,0),.011,'Brushed alloy',24)
        for j in range(6):ring('Plug thread',(x,-.063+j*.0055,0),.012,.010,.0015,'Blued steel','y',10)
        wire('Ground electrode',[(x+.01,-.062,0),(x+.01,-.074,0),(x,-.074,0)],.002,'Brushed alloy',6)

def drive_belt():
    ring('Belt loop',(0,0,0),.153,.139,.026,'Rubber','y',64)
    for i in range(64):
        a=i*math.tau/64
        o=box('Inner toothed rib',(.138*math.cos(a),0,.138*math.sin(a)),(.009,.023,.006),'Rubber',0)
        o.rotation_euler.z=-a

def wheel():
    ring('Rounded sidewall',(0,0,0),.315,.19,.145,'Rubber','x',48)
    for side in [-1,1]:
        ring('Shoulder bead',(side*.078,0,0),.304,.193,.024,'Rubber','x',48)
        ring('Rim lip',(side*.091,0,0),.196,.177,.012,'Brushed alloy','x',40)
    for row in [-1,0,1]:
        for i in range(40):
            a=i*math.tau/40+row*.035
            o=box('Tread block',(row*.043,.314*math.cos(a),.314*math.sin(a)),(.036,.017,.033),'Rubber',0)
            o.rotation_euler.x=a
    for i in range(8):
        a=i*math.tau/8
        wire('Stamped rim spoke',[(.086,.055*math.cos(a),.055*math.sin(a)),(.088,.182*math.cos(a+.12),.182*math.sin(a+.12))],.018,'Paint',8)
    rod('Hub',(.075,0,0),(.103,0,0),.059,'Brushed alloy',32)
    for i in range(5):
        a=i*math.tau/5;rod('Lug bolt',(.103,.043*math.cos(a),.043*math.sin(a)),(.112,.043*math.cos(a),.043*math.sin(a)),.007,'Brushed alloy',6)

def sedative():
    rod('Medicine bottle',(0,-.075,0),(0,.066,0),.044,'Ivory polymer',32)
    rod('Childproof cap',(0,.067,0),(0,.091,0),.048,'Rubber',32)
    for i in range(24):
        a=i*math.tau/24;rod('Cap knurl',(.048*math.cos(a),.07,.048*math.sin(a)),(.048*math.cos(a),.087,.048*math.sin(a)),.0012,'Rubber',4)
    box('Prescription label',(0,-.005,-.044),(.065,.08,.002),'Paper',.002)
    label('CALM',(0,.006,-.046),.016)
    for y in [-.014,-.025]:box('Printed dose line',(0,y,-.046),(.05,.001,.001),'Blued steel',0)

def thermos():
    rod('Insulated steel body',(0,-.125,0),(0,.108,0),.063,'Brushed alloy',40)
    for y in [-.13,.11]:ring('Rolled seam',(0,y,0),.065,.06,.009,'Blued steel','y')
    rod('Cup lid',(0,.115,0),(0,.175,0),.067,'Paint',40)
    ring('Lid rubber grip',(0,.15,0),.069,.064,.035,'Rubber','y')
    ring('Thermos foot',(0,-.13,0),.065,.057,.012,'Rubber','y')
    wire('Folding handle',[(.059,-.05,0),(.1,-.05,0),(.105,.075,0),(.059,.075,0)],.006,'Rubber',8)

def scalpel():
    loft('Flattened surgical handle',[(-.145,0,.012,.003),(-.12,0,.015,.004),(.055,0,.011,.003),(.09,0,.005,.002)],'Brushed alloy',12)
    for z in [-.11+i*.009 for i in range(13)]:box('Handle traction groove',(0,.004,z),(.018,.001,.002),'Blued steel',0)
    mesh('Sharpened scalpel blade',[coord(p) for p in [(-.005,0,.07),(-.005,0,.16),(.014,0,.138),(.014,0,.09),(-.005,.002,.07),(-.005,.002,.16),(.014,.002,.138),(.014,.002,.09)]],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'Brushed alloy')
    for z in [.09,.105,.122]:box('Dried blood on blade',(.005,.0025,z),(.013,.001,.009),'Blood',.001)

def specimen(index):
    rod('Sealed sample tube',(0,-.078,0),(0,.059,0),.034,'Glass',32)
    rod('Collected sample',(0,-.073,0),(0,.012+index*.008,0),.030,'Blood',32)
    rod('Screw stopper',(0,.06,0),(0,.089,0),.038,'Red polymer' if index==0 else ('Green polymer' if index==1 else 'Rubber'),32)
    for y in [.065,.075,.085]:ring('Stopper ridge',(0,y,0),.039,.036,.003,'Rubber','y')
    box('Sample paper label',(0,0,-.034),(.05,.045,.002),'Paper',.001)
    label(['I','II','III'][index],(0,-.008,-.036),.024)

def hospital_badge():
    box('Laminated access card',(0,0,0),(.16,.009,.1),'Ivory polymer',.006)
    box('Badge header',(0,.005,-.03),(.151,.001,.018),'Red polymer',.001)
    box('Photograph',( -.045,.006,.005),(.035,.001,.039),'Blued steel',.001)
    for i in range(9):box('Printed barcode',(.008+i*.005,.006,.024),(.001+(i%2)*.001,.001,.019),'Black recess',0)
    ring('Lanyard eyelet',(0,.007,-.043),.005,.0028,.002,'Brushed alloy','y',16)

def hand():
    ring('Elastic wrist cuff',(0,-.035,.055),.054,.044,.022,'Rubber','z')
    ball('Gloved palm',(0,0,.02),(.065,.058,.07),'Rubber')
    for i,x in enumerate([-.048,-.016,.016,.048]):
        wire('Articulated gloved finger',[(x,.016,.012),(x,.054,-.026),(x,.048,-.068),(x,.023,-.074)],.0145 if i<3 else .013,'Rubber',10)
        ball('Finger knuckle',(x,.052,-.025),(.016,.016,.017),'Rubber')
        box('Knuckle protection',(x,.058,-.006),(.022,.008,.025),'Rubber',.004)
    wire('Opposed thumb',[(-.055,-.01,.055),(-.077,.025,.03),(-.062,.058,-.012),(-.038,.05,-.031)],.02,'Rubber',10)

def desk():
    box('Rounded laminated worktop',(0,1,0),(2.5,.12,.85),'Walnut',.016)
    for x in [-1.05,1.05]:
        for z in [-.31,.31]:
            rod('Tubular desk leg',(x,.04,z),(x,.94,z),.027,'Blued steel',16)
            box('Levelling foot',(x,.012,z),(.085,.024,.085),'Rubber',.004)
        rod('Side brace',(x,.26,-.31),(x,.26,.31),.019,'Blued steel',12)
    rod('Rear brace',(-1.05,.78,.31),(1.05,.78,.31),.019,'Blued steel',12)
    box('Drawer housing',(.8,.73,0),(.54,.42,.7),'Paint',.012)
    for y in [.62,.82]:
        box('Drawer front',(.8,y,-.363),(.5,.18,.026),'Paint',.006)
        wire('Pull handle',[(.73,y,-.38),(.73,y,-.409),(.87,y,-.409),(.87,y,-.38)],.006,'Brushed alloy')

def shelf():
    for x in [-1.12,1.12]:
        for z in [-.33,.33]:
            box('Slotted upright',(x,.85,z),(.046,1.7,.046),'Blued steel',.002)
            for y in [.35,.65,.95,1.25,1.55]:box('Upright slot',(x,y,z-.024),(.013,.03,.001),'Black recess',0)
    for y in [.15,.8,1.6]:
        box('Folded steel shelf',(0,y,0),(2.4,.045,.79),'Paint',.004)
        box('Shelf front fold',(0,y-.026,-.38),(2.4,.055,.018),'Blued steel',.002)
    for sign in [-1,1]:wire('Rear cross brace',[(-1.1,.17,.35),(1.1,1.59,.35)] if sign==1 else [(1.1,.17,.35),(-1.1,1.59,.35)],.007,'Brushed alloy')
    for x in [-.78,-.2,.6]:
        box('Stored parts case',(x,.415,.06),(.43,.48,.48),'Paint',.012)
        box('Paper stock label',(x,.42,-.185),(.16,.065,.002),'Paper',.001)

def cot():
    for x in [-1.53,1.53]:
        for z in [-.47,.47]:
            rod('Bed foot',(x,.018,z),(x,.73,z),.027,'Blued steel',16)
            box('Bed foot pad',(x,.009,z),(.065,.018,.065),'Rubber',.003)
        wire('Rounded end frame',[(x,.2,-.49),(x,.94,-.49),(x,1.01,-.4),(x,1.01,.4),(x,.94,.49),(x,.2,.49)],.026,'Paint',12)
    for z in [-.46,.46]:rod('Mattress side rail',(-1.52,.5,z),(1.52,.5,z),.025,'Blued steel',16)
    box('Mattress',(0,.61,0),(3.02,.24,1.02),'Ivory polymer',.075)
    box('Folded wool blanket',(.3,.746,0),(2.17,.046,1.04),'Paint',.015)
    for z in [-.48,.48]:wire('Mattress piping',[(-1.4,.68,z),(0,.68,z),(1.4,.68,z)],.005,'Paper')
    for z in [-.4,-.2,0,.2,.4]:wire('Blanket seam',[(-.76,.772,z),(.3,.775,z+.02),(1.36,.772,z)],.0015,'Rubber',4)
    ball('Compressed pillow',(-1.05,.79,0),(.31,.095,.38),'Ivory polymer')

def chair():
    box('Moulded seat',(0,.46,0),(.48,.08,.45),'Walnut',.025)
    box('Shaped backrest',(0,.8,.21),(.48,.34,.06),'Walnut',.02)
    for x in [-.19,.19]:
        for z in [-.17,.17]:
            rod('Chair leg',(x*1.15,.02,z*1.15),(x,.44,z),.016,'Blued steel',12)
            rod('Rubber foot',(x*1.15,.005,z*1.15),(x*1.15,.03,z*1.15),.019,'Rubber',12)
        rod('Back tube',(x,.35,.2),(x,.97,.2),.014,'Blued steel',12)
        screw((x,.8,.174),.004)

def radio_rack():
    box('Rack cabinet',(0,1,0),(.78,2,.58),'Paint',.012)
    for x in [-.34,.34]:box('Rack rail',(x,1,-.304),(.025,1.88,.018),'Brushed alloy',.002)
    for y in [.18,.42,.75,1.12,1.49,1.8]:
        box('Service equipment face',(0,y,-.316),(.64,.18,.036),'Blued steel',.003)
        box('Dark display',(-.11,y+.015,-.338),(.19,.065,.003),'Glass',.002)
        for x in [.08,.17,.25]:rod('Control knob',(x,y,-.335),(x,y,-.36),.016,'Rubber',16)
        for x in [-.3,.3]:screw((x,y,-.337),.003)
        for i in range(5):box('Vent grille',(-.2+i*.045,y-.054,-.337),(.027,.009,.002),'Black recess',0)
    for x in [-.31,.31]:box('Rack levelling pad',(x,.012,0),(.08,.024,.42),'Rubber',.004)

def crate():
    box('Crate body',(0,.37,0),(.8,.7,.7),'Walnut',.012)
    for z in [-.356,.356]:
        for x in [-.34,.34]:box('Reinforcing cleat',(x,.38,z),(.055,.65,.03),'Walnut',.004)
        for y in [.09,.66]:box('Reinforcing rail',(0,y,z),(.79,.055,.035),'Walnut',.003)
        for x in [-.34,.34]:
            for y in [.1,.64]:screw((x,y,z+math.copysign(.019,z)),.004)
    for x in [-.27,.27]:box('Crate skid',(x,.016,0),(.09,.032,.7),'Blued steel',.004)

def barrel():
    rod('Drum shell',(0,.035,0),(0,.87,0),.335,'Paint',40)
    for y in [.04,.26,.65,.86]:ring('Rolled reinforcing rib',(0,y,0),.351,.329,.027,'Blued steel','y',40)
    rod('Drum lid',(0,.871,0),(0,.887,0),.329,'Paint',40)
    ring('Filler rim',(.16,.891,0),.045,.026,.008,'Brushed alloy','y',24)
    rod('Bung',(.16,.89,0),(.16,.9,0),.025,'Blued steel',8)

def hospital_console():
    box('Floor plinth',(0,.045,0),(.74,.09,.58),'Blued steel',.012)
    box('Clinical console cabinet',(0,.49,0),(.67,.83,.52),'Paint',.018)
    box('Instrument face',(0,.7,-.276),(.59,.34,.026),'Ivory polymer',.006)
    box('Screen surround',(-.055,.742,-.295),(.38,.2,.02),'Rubber',.007)
    box('Display glass',(-.055,.745,-.308),(.333,.15,.003),'Glass',.003)
    for x in [-.19,0,.19]:
        rod('Recessed button',(x,.56,-.295),(x,.56,-.31),.02,'Brushed alloy',16)
        rod('Status lens',(x,.56,-.31),(x,.56,-.314),.013,'Red polymer' if x<0 else 'Green polymer',16)
    box('Service hatch',(0,.26,-.268),(.5,.28,.01),'Paint',.005)
    for x in [-.22,.22]:screw((x,.26,-.276),.004)
    for i in range(6):box('Cooling slit',(-.16+i*.065,.16,-.276),(.035,.008,.002),'Black recess',0)

def garage_gate():
    for i in range(16):
        y=-1.35+i*.18
        box('Interlocking shutter slat',(0,y,0),(.14,.173,2.18),'Paint',.006)
        box('Rolled slat joint',(-.076,y-.084,0),(.018,.019,2.18),'Blued steel',.002)
    for z in [-1.065,1.065]:box('Shutter edge',(0,0,z),(.16,2.88,.04),'Blued steel',.003)
    box('Bottom safety seal',(-.015,-1.428,0),(.17,.024,2.18),'Rubber',.003)

BUILDERS={'shotgun':shotgun,'flashlight':flashlight,'hand':hand,'shell':shell,'medkit':medkit,'battery':battery,'fuel':fuel,'fuse':fuse,'cassette':cassette,'air_filter':air_filter,'car_battery':car_battery,'spark_plugs':spark_plugs,'drive_belt':drive_belt,'wheel':wheel,'sedative':sedative,'thermos':thermos,'scalpel':scalpel,'hospital_badge':hospital_badge,'desk':desk,'shelf':shelf,'cot':cot,'chair':chair,'radio_rack':radio_rack,'crate':crate,'barrel':barrel,'hospital_console':hospital_console,'garage_gate':garage_gate}
for kind in ['key','service_key','car_key','yard_key','hospital_key']:BUILDERS[kind]=lambda kind=kind:key(kind)
for i,kind in enumerate(['specimen_a','specimen_b','specimen_c']):BUILDERS[kind]=lambda i=i:specimen(i)
for name,builder in BUILDERS.items():clear();builder();export(name,name=='shotgun')
(OUT/'catalog.json').write_text(json.dumps(CAT,indent=2)+'\n',encoding='utf-8')
print('DETAILED_PROPS_COMPLETE',len(BUILDERS),'models',flush=True)
