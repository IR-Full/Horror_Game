extends RefCounted
## A different layout on the same 126 x 172 m footprint, with 8804 m² of floor.
const FLOORS := [Rect2(-18,-21,36,48),Rect2(-63,-63,36,48),Rect2(27,-63,36,48),Rect2(-24,-105,48,33),Rect2(-24,37,48,30),Rect2(-27,-21,9,6),Rect2(18,-21,9,6),Rect2(-4,-72,8,51),Rect2(-4,27,8,10)]
const EXTENT := Rect2i(-64,-106,129,174)
const LEGEND := ["A • ГАРАЖ И ВОРОТА", "Машина • аварийный клапан • зона отдыха", "B • СКЛАД ШИН И ТОПЛИВА", "Колесо • клетка аккумулятора и бензина", "C • РЕМОНТНЫЕ БОКСЫ", "Сейф свечей • пусковой щит • схема", "D • СЕВЕРНАЯ СВАЛКА", "Ремень привода • первая половина кода", "E • ОБЩЕЖИТИЕ ОХРАНЫ", "Ключи • вторая половина кода • отдых"]
static func sector_at(p: Vector3) -> String:
	if p.z > 36: return "E • ОБЩЕЖИТИЕ ОХРАНЫ"
	if p.z < -71: return "D • СЕВЕРНАЯ СВАЛКА"
	if p.x < -26: return "B • СКЛАД ШИН И ТОПЛИВА"
	if p.x > 26: return "C • РЕМОНТНЫЕ БОКСЫ"
	if absf(p.x)>18 or p.z < -21 or p.z > 27: return "СЛУЖЕБНАЯ ДОРОГА"
	return "A • ГАРАЖ И ВОРОТА"

static func build(s: Node3D) -> void:
	s.environment.background_color = Color("04080e")
	s.environment.fog_light_color = Color("273641")
	for rect: Rect2 in FLOORS:
		s.block(Vector3(rect.get_center().x,-.2,rect.get_center().y),Vector3(rect.size.x,.4,rect.size.y),"313c3e")
	# All sectors and connecting passages are roofed; no bright void over corridors.
	_shell(s,FLOORS[0],{"left":[Vector2(-21,-15)],"right":[Vector2(-21,-15)],"north":[Vector2(-4,4)],"south":[Vector2(-4,4)]},true)
	_shell(s,FLOORS[1],{"right":[Vector2(-21,-15)]},true)
	_shell(s,FLOORS[2],{"left":[Vector2(-21,-15)]},true)
	_shell(s,FLOORS[3],{"south":[Vector2(-4,4)]},true)
	_shell(s,FLOORS[4],{"north":[Vector2(-4,4)]},true)
	for rect: Rect2 in FLOORS.slice(5):
		s.block(Vector3(rect.get_center().x,3.4,rect.get_center().y),Vector3(rect.size.x+.1,.2,rect.size.y+.1),"202c30")
		if rect.size.x < rect.size.y:
			for x: float in [rect.position.x,rect.end.x]: _segment(s,true,x,rect.position.y,rect.end.y)
		else:
			for z: float in [rect.position.y,rect.end.y]: _segment(s,false,z,rect.position.x,rect.end.x)
	# Each side building has a wide working aisle and four searchable bays.
	for cx: float in [-45,45]:
		# Gaps in these cross walls are doors, not cracks or blocked lintels.
		_remove_cross_wall(s,cx,-39)
		for z: float in [-51,-27]:
			for side: float in [-1,1]:
				for edge: float in [-1,1]: s.block(Vector3(cx+side*9+edge*5.05,1.6,z),Vector3(7.9,3.2,.25),"465354")
				var door: Node3D = s.add_object("depot_door_%d_%d_%d" % [int(cx),int(z),int(side)],"door","Дверь бокса",Vector3(cx+side*9,1.44,z))
				door.rotation.y = PI/2; door.opened = true; door.refresh()
				_light(s,Vector3(cx+side*9,2.9,z-5),Color("92a5a6"))
				s.LAYOUT._prop(s,"shelf",Vector3(cx+side*12,0,z-9),0,Vector3(2.4,1.7,.8))
		for z: float in [-18,-33,-45,-59]: _light(s,Vector3(cx,2.9,z),Color("c59a65"))
	# The guard dormitory: six rooms around the road used for the departure.
	for side: float in [-1,1]:
		for z: float in [47,57]: s.block(Vector3(side*14,1.6,z),Vector3(20,3.2,.22),"475653")
		for row: int in range(3):
			var z: float = 42+row*10
			for edge: float in [-1,1]: s.block(Vector3(side*4,1.6,z+edge*3.05),Vector3(.25,3.2,3.9),"465354")
			s.door_frame(side*4,z)
			var door: Node3D = s.add_object("dorm_door_%d_%d" % [int(side),row],"door","Комната охраны",Vector3(side*4,1.44,z))
			door.opened = true; door.refresh()
			_light(s,Vector3(side*14,2.9,z),Color("b5a984"))
			s.LAYOUT._prop(s,"cot",Vector3(side*19,0,z-2),0,Vector3(3.2,.7,1.2))
	for z: float in [-16,0,18,32,42,54,64,-35,-50,-65,-82,-99]: _light(s,Vector3(0,2.9,z),Color("869eab"))
	# Distinct yard dressing: fenced rows of stacked crates and stripped vehicles.
	for side: float in [-1,1]:
		for z: float in [-79,-91,-101]:
			for x: float in [side*10,side*19]: s.LAYOUT._prop(s,"crate",Vector3(x,0,z),0,Vector3(1.2,1.1,1.1))
		for z: float in [-8,5]:
			var wreck: Node3D = s.ART.model("escape_car")
			wreck.position = Vector3(side*12,0,z)
			wreck.rotation.y = PI/2
			wreck.scale.y = .65
			for part: Node3D in wreck.find_children("*","MeshInstance3D",true,false):
				if str(part.name).begins_with("Wheel_") or str(part.name).begins_with("Hub_"): part.hide()
			s.add_child(wreck)
			s._prop_collision(wreck.position+Vector3.UP*.7,Vector3(4.7,1.4,2.2))
	s.add_object("escape_car","vehicle","МАШИНА • удерживать E: установить детали / завести",Vector3(0,.8,23))
	var gate: Node3D = s.add_object("exit_gate","door","Выездные ворота • откроются при запуске",Vector3(.75,1.44,30))
	gate.rotation.y = PI/2; gate.locked = true
	# Six-metre roller gate with closed jambs; the marked side passage remains usable.
	gate.scale.z = 2.75
	gate.gate_rule = "depot_exit"
	for x: float in [-3.9,-2.375,3.875]:
		s.block(Vector3(x,1.65,30),Vector3(.25,3.3,.42),"475653")
	s.block(Vector3(0,3.08,30),Vector3(8.1,.44,.42),"475653")
	s.sign_text("ПРОХОД",Vector3(-3.15,2.65,29.76),0,13)
	s.add_object("generator","generator","Аварийный клапан топлива • удерживать E для ремонта",Vector3(-12,.6,17))
	s.add_object("ventilation","ventilation","Аварийная система автобазы",Vector3(12,.9,17))
	for i: int in range(3):
		s.add_object("depot_dial_%d" % i,"depot_dial","Контакт "+["L","N","PE"][i]+" • 0–5",Vector3(34+i*2,1.2,-33))
		s.block(Vector3(34+i*2,.55,-33),Vector3(.12,1.1,.12),"293e40",false)
	_storage(s,"battery_cage","cage",Vector3(-56,1,-57),true,"yard_key")
	_storage(s,"parts_safe","safe",Vector3(55,.425,-57),false)
	_storage(s,"wheel_locker","locker_container",Vector3(-35,1.05,-33),false)
	var belt: Node3D = _storage(s,"belt_locker","locker_container",Vector3(17,1.05,-97),true)
	belt.gate_rule = "depot_circuit"
	_storage(s,"guard_locker","locker_container",Vector3(-11,1.05,42),false)
	_storage(s,"ignition_locker","locker_container",Vector3(11,1.05,62),false)
	for data: Array in [["car_battery","battery_cage",-.5],["fuel","battery_cage",.25],["spark_plugs","parts_safe",-.2],["wheel","wheel_locker",-.2],["drive_belt","belt_locker",-.3],["yard_key","guard_locker",-.3],["car_key","ignition_locker",-.3]]:
		var box: Node3D = s.objects[data[1]]
		var item: Node3D = s.add_object(data[0],data[0],s.items.NAMES[data[0]],box.position+Vector3(0,data[2],.1))
		item.container_id = data[1]
	for data: Array in [["depot_note_a",Vector3(-17,1.08,-98),"Накладная склада"],["depot_note_b",Vector3(-14,1.08,42),"Журнал дежурного"],["depot_wiring_note",Vector3(54,1.08,-22),"Схема контактов"]]:
		s.LAYOUT._prop(s,"desk",data[1]-Vector3(0,1.08,0),0,Vector3(2.5,1.05,.85))
		s.LAYOUT._note(s,data[0],data[2],data[1],"Запись текущей смены")
	for i: int in range(12):
		var at: Vector3 = [Vector3(-8,1.05,-12),Vector3(8,1.05,-12),Vector3(-58,1.05,-22),Vector3(-32,1.05,-57),Vector3(32,1.05,-57),Vector3(58,1.05,-22),Vector3(-18,1.05,-82),Vector3(18,1.05,-82),Vector3(-8,1.05,52),Vector3(8,1.05,42),Vector3(-8,1.05,62),Vector3(8,1.05,52)][i]
		_storage(s,"depot_spare_%d" % i,"locker_container",at,false)
	s.calm_zones = [Vector3(12,0,9),Vector3(-14,0,42)]
	s.sign_text("ПУНКТ ОТДЫХА • СВЕТ И ЧАЙ",Vector3(12,2,12),PI,22)
	for data: Array in [["A • ГАРАЖ / СБОР МАШИНЫ",Vector3(0,3,7),PI],["B • ШИНЫ И ТОПЛИВО",Vector3(-22,2.6,-18),PI/2],["C • РЕМОНТНЫЕ БОКСЫ",Vector3(22,2.6,-18),-PI/2],["D • СЕВЕРНАЯ СВАЛКА",Vector3(0,2.6,-69),PI],["E • ОБЩЕЖИТИЕ ОХРАНЫ",Vector3(0,2.6,35),PI]]: s.sign_text(data[0],data[1],data[2],26)
	for i: int in range(11):
		var kind: String = ["battery","battery","battery","medkit","medkit","sedative","sedative","sedative","sedative","thermos","thermos"][i]
		s.add_object("depot_supply_%d" % i,kind,s.items.NAMES[kind],Vector3(0,.3,9))
	for i: int in range(6): s.add_object("shell_%d" % i,"shell","Патрон 12 калибра",Vector3(0,.05,8))
	s.refresh_containers()

static func _remove_cross_wall(s: Node3D,cx: float,z: float) -> void:
	# Only side spans exist in geometry and navigation; the six-metre aisle is open.
	for side: float in [-1,1]: s.block(Vector3(cx+side*10.5,1.6,z),Vector3(15,3.2,.22),"475653")

static func _storage(s: Node3D,id: String,kind: String,at: Vector3,locked: bool,key: String = "") -> Node3D:
	var object: Node3D = s.add_object(id,kind,"Хранилище • осмотреть",at)
	object.locked = locked; object.required_key = key
	return object

static func _shell(s: Node3D,rect: Rect2,holes: Dictionary,roof: bool) -> void:
	if roof: s.block(Vector3(rect.get_center().x,3.4,rect.get_center().y),Vector3(rect.size.x,.2,rect.size.y),"202c30")
	for side: String in ["left","right","north","south"]:
		var vertical: bool = side in ["left","right"]
		var start: float = rect.position.y if vertical else rect.position.x
		var end: float = rect.end.y if vertical else rect.end.x
		var at: float = (rect.position.x if side == "left" else rect.end.x) if vertical else (rect.position.y if side == "north" else rect.end.y)
		for hole: Vector2 in holes.get(side,[]):
			if hole.x > start: _segment(s,vertical,at,start,hole.x)
			start = maxf(start,hole.y)
		if end > start: _segment(s,vertical,at,start,end)

static func _segment(s: Node3D,vertical: bool,at: float,start: float,end: float) -> void:
	if end-start < .01: return
	s.block(Vector3(at,1.6,(start+end)*.5) if vertical else Vector3((start+end)*.5,1.6,at),Vector3(.25,3.2,end-start) if vertical else Vector3(end-start,3.2,.25),"465354")

static func _light(s: Node3D,at: Vector3,tint: Color) -> void:
	s.LAYOUT._light(s,at,tint)
