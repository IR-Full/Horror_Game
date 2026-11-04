extends RefCounted
## Closed mine galleries, six chambers and a vertically moving rescue cage.
const FLOORS := preload("res://scripts/world/forest_layout.gd").CLEAR+preload("res://scripts/world/forest_layout.gd").ROOFS+[Rect2(-20,30,10,12),Rect2(35,50,15,15),Rect2(-8,0,70,12),Rect2(35,-13,14,28),Rect2(-8,60,70,6)]
const EXTENT := Rect2i(-64,-106,129,174)
const ROOFS := [Rect2(-24,14,16,20),Rect2(-58,-26,23,22),Rect2(25,-43,32,30),Rect2(-58,-93,24,21),Rect2(9,-99,22,24),Rect2(30,35,25,25)]
const TITLES := ["A • ЛАМПОВАЯ", "B • ПОДСТАНЦИЯ", "C • ВЗРЫВНОЙ УЧАСТОК", "D • ВОДОСБОРНИК", "E • СТВОЛ ПОДЪЁМНИКА", "F • СПАСАТЕЛЬНЫЙ ПОСТ"]
const LEGEND := ["НУЛЕВАЯ ОТМЕТКА • ШАХТА", "A • Ламповая: журналы, сейф, генератор", "B • Подстанция: аккумулятор, пуск взрывного пульта", "C • Взрывной участок: порядок захватов, ремень", "D • Водосборник: давление и топливо", "E • Подъёмник: контакторы, клеть", "F • Спасательный пост: ключ зажигания, отдых", "Тёмные полосы: подземные штреки и рельсы", "Штрековый слышит механизмы, шаги и голос."]
const CLEAR := [Rect2(-8,-104,16,170),Rect2(-62,-25,124,13),Rect2(-49,-99,15,155),Rect2(33,-99,16,155),Rect2(-58,-82,116,14),Rect2(-56,37,112,15)]
static func sector_at(p: Vector3) -> String:
	for i: int in range(ROOFS.size()):
		if ROOFS[i].grow(4).has_point(Vector2(p.x,p.z)):return TITLES[i]
	if absf(p.x)<8:return "ГЛАВНЫЙ ШТРЕК"
	return "НУЛЕВАЯ ОТМЕТКА • ВЫРАБОТКИ"
static func map_rooms() -> Array:
	var rooms: Array=[]
	for rect: Rect2 in CLEAR:rooms.append([rect,"",Color("24352d")])
	for i: int in range(ROOFS.size()):rooms.append([ROOFS[i],["A ЛАМПЫ","B ЭЛЕКТРО","C ЗАРЯД","D НАСОС","E СТВОЛ","F ПОСТ"][i],Color("514937")])
	return rooms
static func timber(s: Node3D,at: Vector3,size: Vector3,solid: bool=true) -> Node3D:
	var node: Node3D=s.block(at,size,"394431",solid)
	for child: Node in node.get_children():
		if child is MeshInstance3D:child.material_override=s.ART.surface("plaster")
	return node
static var wood: ShaderMaterial
static func timber_material() -> ShaderMaterial:
	if wood:return wood
	wood=ShaderMaterial.new();wood.shader=preload("res://assets/shaders/forest_timber.gdshader");return wood
static func build(s: Node3D) -> void:
	s.environment.background_color=Color("02050a");s.environment.ambient_light_color=Color("718b98")
	var ground: Node3D=s.block(Vector3(0,-.21,-19),Vector3(126,.42,172),"19241c")
	for child: Node in ground.get_children():
		if child is MeshInstance3D:child.material_override=ground_material()
	# Solid perimeter and visible timber fencing keep the forest traversable and bounded.
	for x: float in [-63,63]:timber(s,Vector3(x,1.65,-19),Vector3(.35,3.3,172))
	for z: float in [-105,67]:timber(s,Vector3(0,1.65,z),Vector3(126,3.3,.35))
	for rect: Rect2 in CLEAR:
		var road: Node3D=s.block(Vector3(rect.get_center().x,.003,rect.get_center().y),Vector3(rect.size.x,.006,rect.size.y),"273127",false)
		for child: Node in road.get_children():
			if child is MeshInstance3D:child.material_override=ground_material(true)
	for i: int in range(ROOFS.size()):cabin(s,ROOFS[i],i)
	tunnels(s)
	# Rails and sleepers remain low enough for both character and monster capsules.
	for x: float in [-.76,.76]:s.block(Vector3(x,.035,-42),Vector3(.075,.07,124),"5a625b",false)
	for z: int in range(-103,22,2):timber(s,Vector3(0,.014,z),Vector3(2.4,.028,.23),false)
	for at: Vector3 in [Vector3(-16,0,27),Vector3(-46,0,-12),Vector3(40,0,-22),Vector3(-46,0,-80),Vector3(20,0,-86),Vector3(42,0,48)]:s.LAYOUT._prop(s,"desk",at,0,Vector3(2.5,1.05,.85))
	for at: Vector3 in [Vector3(-53,0,-19),Vector3(29,0,-32),Vector3(52,0,-36),Vector3(14,0,-93),Vector3(26,0,-94)]:s.LAYOUT._prop(s,"shelf",at,0,Vector3(2.4,1.7,.8))
	for at: Vector3 in [Vector3(35,0,42),Vector3(35,0,53),Vector3(50,0,43),Vector3(50,0,54)]:s.LAYOUT._prop(s,"cot",at,0,Vector3(2.8,.7,1.2))
	for at: Vector3 in [Vector3(38,0,-35),Vector3(48,0,-30)]:s.LAYOUT._prop(s,"radio_rack",at,0,Vector3(.85,2,.65))
	s.LAYOUT._prop(s,"forest_winch",Vector3(-40,0,-20),0,Vector3(2.2,1.2,1.25))
	for at: Vector3 in [Vector3(22,0,-37),Vector3(58,0,-30),Vector3(-27,0,-44),Vector3(28,0,15),Vector3(-30,0,48)]:s.LAYOUT._prop(s,"forest_logs",at,PI/2,Vector3(5.5,1.5,2.3))

	s.calm_zones=[Vector3(42,0,48)]
	s.add_object("generator","generator","Дизель A • предохранитель и бензин, удерживать E",Vector3(-12,.6,19))
	s.add_object("ventilation","ventilation","Насос D • давление, удерживать E / ремонт утечки",Vector3(-40,.9,-86))
	s.add_object("winch","forest_station","Взрывной пульт B • взрывные цепи C, удерживать E",Vector3(-38,.9,-17))
	s.add_object("rail_cart","forest_cart","Клеть E • установить детали / ключ / вся команда",Vector3(0,.8,-74))
	var barrier: Node3D=s.add_object("rail_logs","forest_barrier","Завал на пути • лебёдка B",Vector3(0,.75,-48));barrier.rotation.y=PI/2
	for i: int in range(4):s.add_object("log_%d" % i,"forest_control","Цепь %d • нажать" % (i+1),Vector3(34+i*2,1.25,-18))
	for i: int in range(3):
		s.add_object("pump_%d" % i,"forest_control","Давление %s • 0–5" % ["I","II","III"][i],Vector3(-52+i*2.5,1.25,-87))
		s.add_object("signal_%d" % i,"forest_control","Контактор %s • 0–3" % ["A","B","C"][i],Vector3(16+i*2,1.25,-79))
	for data: Array in [["forest_safe","safe",Vector3(-21,.425,19),"",""],["battery_safe","safe",Vector3(-54,.425,-8),"",""],["belt_case","locker_container",Vector3(52,1.05,-18),"forest_winch",""],["fuel_case","cage",Vector3(-53,1,-78),"forest_pump",""],["key_case","locker_container",Vector3(46,1.05,56),"","service_key"]]:
		var box: Node3D=s.add_object(data[0],data[1],"Хранилище шахты • осмотреть",data[2]);box.gate_rule=data[3];box.required_key=data[4];box.locked=not str(data[4]).is_empty()
	for data: Array in [["forest_fuse","fuse","forest_safe"],["forest_battery","car_battery","battery_safe"],["forest_belt","drive_belt","belt_case"],["forest_diesel","fuel","fuel_case"],["forest_ignition","car_key","key_case"]]:
		var box: Node3D=s.objects[data[2]];var item: Node3D=s.add_object(data[0],data[1],s.items.NAMES[data[1]],box.position+Vector3(0,-.15 if box.kind=="safe" else -.4,.1));item.container_id=data[2]
	for data: Array in [["forest_office_note",Vector3(-16,1.08,27),"Приказ о закрытии шахты"],["forest_winch_note",Vector3(-46,1.08,-12),"Журнал стропальщика"],["forest_pump_note",Vector3(-46,1.08,-80),"Последняя смена насосной"],["forest_signal_note",Vector3(20,1.08,-86),"Маршрут на станцию"],["forest_barracks_note",Vector3(42,1.08,48),"Записка пропавшей бригады"]]:s.LAYOUT._note(s,data[0],data[2],data[1],"Журнал этой смены")
	for i: int in range(16):
		var at: Vector3=preload("res://scripts/world/mine_loot.gd").BOXES[i]
		s.add_object("forest_box_%d" % i,"locker_container","Шкаф шахты • осмотреть",at)
	for i: int in range(14):
		var kind: String=["service_key","fuel","battery","battery","air_filter","medkit","medkit","sedative","sedative","air_filter","thermos","thermos","thermos","air_filter"][i]
		s.add_object("forest_supply_%d" % i,kind,s.items.NAMES[kind],Vector3(0,.3,10))
	for i: int in range(6):s.add_object("shell_%d" % i,"shell","Патрон 12 калибра",Vector3(0,.05,8))
	# The final shutter is a real solid obstruction until the engine has started.
	var gate: Node3D=s.add_object("exit_gate","door","Аварийная решётка",Vector3(0,1.44,-96));gate.rotation.y=PI/2;gate.scale.z=2.75;gate.locked=true;gate.gate_rule="forest_exit";gate.refresh()
	for x: float in [-4.7,4.7]:timber(s,Vector3(x,1.65,-96),Vector3(3.2,3.3,.5))
	for at: Vector3 in [Vector3(-5,3,-94),Vector3(4,3,-48),Vector3(-36,3,-19),Vector3(26,3,-20)]:
		timber(s,Vector3(at.x,1.6,at.z),Vector3(.16,3.2,.16),false);s.LAYOUT._light(s,at,Color("c3a56a"));s.lights.back().set_meta("standby",.02)
	s.refresh_containers()
static func cabin(s: Node3D,rect: Rect2,index: int) -> void:
	var cx: float=rect.get_center().x
	for x: float in [rect.position.x,rect.end.x]:timber(s,Vector3(x,1.6,rect.get_center().y),Vector3(.28,3.2,rect.size.y))
	timber(s,Vector3(cx,1.6,rect.position.y),Vector3(rect.size.x,3.2,.28))
	for side: float in [-1,1]:timber(s,Vector3(cx+side*(rect.size.x/4+.55),1.6,rect.end.y),Vector3(rect.size.x/2-1.1,3.2,.28))
	timber(s,Vector3(cx,3.09,rect.end.y),Vector3(2.3,.42,.3))
	timber(s,Vector3(cx,3.35,rect.get_center().y),Vector3(rect.size.x+.6,.3,rect.size.y+.6))
	# Plank corners, lintels and sloped eaves make each cabin read as a timber building.
	for x: float in [rect.position.x-.06,rect.end.x+.06]:
		for z: float in [rect.position.y-.06,rect.end.y+.06]:timber(s,Vector3(x,1.55,z),Vector3(.18,3.1,.18),false)
	for side: float in [-1,1]:
		var roof: Node3D=s.block(Vector3(cx+side*rect.size.x*.25,3.68,rect.get_center().y),Vector3(rect.size.x*.52,.12,rect.size.y+.8),"29342d",false)
		roof.rotation.z=side*-.07
	for z: float in [rect.position.y,rect.end.y]:timber(s,Vector3(cx,3.58,z),Vector3(rect.size.x+.7,.16,.2),false)
	var door: Node3D=s.add_object("forest_door_%d" % index,"door","Дверь: "+TITLES[index],Vector3(cx,1.44,rect.end.y));door.rotation.y=PI/2;door.opened=true;door.refresh()
	s.sign_text(TITLES[index],Vector3(cx,2.7,rect.end.y+.17),0,24)
	s.LAYOUT._light(s,Vector3(cx,2.95,rect.get_center().y),Color("b9a171"));s.lights.back().omni_range=9;s.lights.back().set_meta("standby",.06)
static func ground_material(road: bool=false) -> ShaderMaterial:
	var m:=ShaderMaterial.new();m.shader=preload("res://assets/shaders/forest_ground.gdshader");m.set_shader_parameter("road",1.0 if road else 0.0);return m
static func tunnels(s: Node3D) -> void:
	var cells: Dictionary={}
	for rect: Rect2 in FLOORS:
		for x: int in range(int(rect.position.x),int(rect.end.x)):
			for z: int in range(int(rect.position.y),int(rect.end.y)):cells[Vector2i(x,z)]=true
	var edges: Dictionary={}
	for cell: Vector2i in cells:
		for d: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if cells.has(cell+d):continue
			var vertical: bool=d.x!=0;var line: int=cell.x+(1 if d.x>0 else 0) if vertical else cell.y+(1 if d.y>0 else 0)
			var key:=Vector2i(1 if vertical else 0,line)
			if not edges.has(key):edges[key]=[]
			edges[key].append(cell.y if vertical else cell.x)
	for key: Vector2i in edges:
		var points: Array=edges[key];points.sort();var start: int=points[0];var end: int=start+1
		for n: int in points.slice(1)+[9999]:
			if n==end:end+=1;continue
			s.block(Vector3(key.y,2,(start+end)*.5) if key.x==1 else Vector3((start+end)*.5,2,key.y),Vector3(.35,4,end-start) if key.x==1 else Vector3(end-start,4,.35),"465354")
			start=n;end=n+1
	# Rock ceilings over every connecting tunnel; the lift shaft intentionally rises above them.
	for rect: Rect2 in FLOORS:
		if rect.position.x==-8 and rect.size.x==16:
			for span: Vector2 in [Vector2(-104,-79),Vector2(-69,66)]:s.block(Vector3(0,4.15,(span.x+span.y)*.5),Vector3(16,.3,span.y-span.x),"202c30")
		else:s.block(Vector3(rect.get_center().x,4.15,rect.get_center().y),Vector3(rect.size.x,.3,rect.size.y),"202c30")
	for x: float in [-4,4]:s.block(Vector3(x,10,-74),Vector3(.3,20,10),"465354")
	for z: float in [-79,-69]:s.block(Vector3(0,12,z),Vector3(8,16,.3),"465354")
	s.block(Vector3(0,20,-74),Vector3(8,.3,10),"202c30")
	for z: int in range(-100,60,8):
		for x: float in [-3.6,3.6]:s.block(Vector3(x,1.8,z),Vector3(.18,3.6,.18),"293e40",false)
		s.block(Vector3(0,3.7,z),Vector3(7.4,.18,.18),"293e40",false)
	s.sign_text("ГЛУБИНА 420 • НА ПЕРЕКЛИЧКУ НЕ ОТВЕЧАТЬ",Vector3(0,2.5,14),0,22)
