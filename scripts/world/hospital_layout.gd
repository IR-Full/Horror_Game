extends RefCounted
## Pavilion 13: a roofed hospital, six wards, six theatres, morgue and laboratory.
const FLOORS := [Rect2(-4,-105,8,172),Rect2(-30,19,26,48),Rect2(4,19,26,48),Rect2(-63,-50,44,60),Rect2(19,-50,44,60),Rect2(-30,-105,26,39),Rect2(4,-105,26,39),Rect2(-19,-23,15,6),Rect2(4,-23,15,6)]
const EXTENT := Rect2i(-64,-106,129,174)
const LEGEND := ["A • ПРИЁМНОЕ ОТДЕЛЕНИЕ", "01 Регистратура • 02 Приёмная • 03 Электрощитовая", "04 Аптека • 05 Комната персонала • 06 Лифт", "B • ЗАКРЫТЫЕ ПАЛАТЫ", "B01–B06 • койки • вызовы • образец I", "C • ОПЕРАЦИОННЫЙ БЛОК", "C01–C06 • инструменты • автоклав • образец II", "D • МОРГ И АРХИВ", "D01 Холодильная • D02 Сейф • D03 Документы", "E • ЛАБОРАТОРИЯ", "E01 Рецептура • E02 Анализатор • E03 Карта доступа"]
static func sector_at(p: Vector3) -> String:
	if p.x < -18 and p.z > -51 and p.z < 11: return "B • ЗАКРЫТЫЕ ПАЛАТЫ"
	if p.x > 18 and p.z > -51 and p.z < 11: return "C • ОПЕРАЦИОННЫЙ БЛОК"
	if p.z < -65: return "D • МОРГ И АРХИВ" if p.x < -4 else ("E • ЛАБОРАТОРИЯ" if p.x > 4 else "СЕВЕРНЫЙ КОРИДОР")
	if p.z >= 19: return "A • ПРИЁМНОЕ ОТДЕЛЕНИЕ"
	return "ЦЕНТРАЛЬНЫЙ КОРИДОР"
static func map_rooms() -> Array:
	var rooms: Array = []
	for side: int in [-1,1]:
		for row: int in range(3):
			rooms.append([Rect2(-30 if side < 0 else 4,19+row*16,26,16),"A%02d" % (row*2+(1 if side<0 else 2)),Color("3d4f48")])
			rooms.append([Rect2(-30 if side < 0 else 4,-105+row*13,26,13),("D" if side<0 else "E")+"%02d" % (row+1),Color("48454f")])
			for edge: int in [-1,1]:
				rooms.append([Rect2(side*41+(-22 if edge<0 else 4),-50+row*20,18,20),("B" if side<0 else "C")+"%02d" % (row*2+(1 if edge<0 else 2)),Color("513b3d")])
	return rooms
static func build(s: Node3D) -> void:
	s.environment.background_color = Color("010204")
	s.environment.fog_light_color = Color("142321")
	for rect: Rect2 in FLOORS:
		s.block(Vector3(rect.get_center().x,-.2,rect.get_center().y),Vector3(rect.size.x,.4,rect.size.y),"313c3e")
		s.block(Vector3(rect.get_center().x,3.4,rect.get_center().y),Vector3(rect.size.x,.2,rect.size.y),"202c30")
	# Shared corridor walls only where no ward touches the corridor.
	for side: float in [-1,1]:
		for span: Vector2 in [Vector2(-66,-23),Vector2(-17,19)]: _segment(s,true,side*4,span.x,span.y)
		for z: float in [-23,-17]: _segment(s,false,z,-19 if side<0 else 4,-4 if side<0 else 19)
	_segment(s,false,-105,-4,4); _segment(s,false,67,-4,4)
	for side: float in [-1,1]:
		# Six reception/staff rooms and six archive/laboratory rooms.
		for north: bool in [false,true]:
			var start: float = -105 if north else 19
			var depth: float = 13 if north else 16
			var rect := Rect2(-30 if side<0 else 4,start,26,depth*3)
			var gaps: Array = []
			for row: int in range(3): gaps.append(Vector2(start+row*depth+5.9,start+row*depth+8.1))
			s.DEPOT._shell(s,rect,{"right" if side<0 else "left":gaps},false)
			for row: int in range(3):
				var z: float = start+row*depth+7
				s.door_frame(side*4,z)
				var door: Node3D = s.add_object("hospital_door_%d_%d_%d" % [int(side),int(north),row],"door","Дверь отделения",Vector3(side*4,1.44,z))
				door.opened = true; door.refresh()
				if row>0: _segment(s,false,start+row*depth,rect.position.x,rect.end.x)
				var room_at := Vector3(side*19,0,start+row*depth+9)
				if north and side<0:
					s.LAYOUT._prop(s,"operating_table",room_at,PI/2,Vector3(2.1,1.05,1.6))
				elif not north and row==2: s.LAYOUT._prop(s,"cot",room_at,0,Vector3(2.8,.7,1.2))
				else: s.LAYOUT._prop(s,"desk",room_at,0,Vector3(2.5,1.05,.85))
		# Two wings: a central aisle, three pairs of rooms, no solid obstacle in the aisle.
		var cx: float = side*41
		var rect := Rect2(cx-22,-50,44,60)
		s.DEPOT._shell(s,rect,{"right" if side<0 else "left":[Vector2(-23,-17)]},false)
		for edge: float in [-1,1]:
			var x: float = cx+edge*4
			for span: Vector2 in [Vector2(-50,-41.1),Vector2(-38.9,-21.1),Vector2(-18.9,-1.1),Vector2(1.1,10)]: _segment(s,true,x,span.x,span.y)
			for row: int in range(3):
				var z: float = -40+row*20
				s.door_frame(x,z)
				var door: Node3D = s.add_object("hospital_bay_%d_%d_%d" % [int(side),int(edge),row],"door","Палата" if side<0 else "Операционная",Vector3(x,1.44,z))
				door.opened = true; door.refresh()
				var at := Vector3(cx+edge*13,0,z-4)
				if side<0:
					for dz: float in [-2,5]: s.LAYOUT._prop(s,"cot",at+Vector3(0,0,dz),0,Vector3(2.8,.7,1.2))
				else:
					s.LAYOUT._prop(s,"operating_table",at,0,Vector3(1.55,1.05,2.1))
					s.LAYOUT._prop(s,"hospital_trolley",at+Vector3(3,0,2),.25,Vector3(.8,1.1,.6))
					if row==1: s.LAYOUT._prop(s,"surgical_lamp",at+Vector3(-2,0,-1),0,Vector3(.6,2.5,.6))
			for z: float in [-30,-10]: _segment(s,false,z,cx-22 if edge<0 else cx+4,cx-4 if edge<0 else cx+22)
	# Only a few working lamps; most light must come from players' flashlights.
	for at: Vector3 in [Vector3(0,2.95,10),Vector3(0,2.95,-37),Vector3(0,2.95,-80),Vector3(-41,2.95,-30),Vector3(-41,2.95,3),Vector3(41,2.95,-35),Vector3(41,2.95,5),Vector3(-18,2.95,-98),Vector3(18,2.95,-85),Vector3(-18,2.95,58),Vector3(18,2.95,42)]:
		s.LAYOUT._light(s,at,Color("809b89"))
		var light: OmniLight3D = s.lights.back()
		light.omni_range = 6; light.set_meta("base_energy",.32); light.set_meta("standby",.11)
		light.set_meta("hospital_fault",at.z != 58)
	s.calm_zones = [Vector3(-19,0,58)]
	s.sign_text("ПАВИЛЬОН 13 • ПСИХИАТРИЧЕСКАЯ БОЛЬНИЦА",Vector3(0,2.4,18.8),PI,23)
	s.sign_text("КОМНАТА ПЕРСОНАЛА • ОТДЫХ",Vector3(-4,2.35,58),PI/2,14)
	s.sign_text("МОРГ • БЕЗ ПИТАНИЯ ОПАСНЫЙ ХОЛОД",Vector3(-4,2.3,-72),PI/2,13)
	s.add_object("generator","generator","Щит питания A • предохранитель, удерживать E",Vector3(-23,.6,42))
	s.add_object("ventilation","ventilation","Вытяжка C • удерживать E при аварии",Vector3(57,.9,-5))
	station(s,"sterilizer",Vector3(22,.9,-25),"Автоклав C • скальпель и давление, удерживать E")
	station(s,"analyzer",Vector3(21,.9,-84),"Анализатор E • три образца, рецептура, удерживать E")
	station(s,"hospital_exit",Vector3(0,.9,64),"Аварийный лифт A • карта допуска, вся команда рядом, удерживать E")
	for i: int in range(4): control(s,"ward_%d" % i,Vector3(-58+i*3,1.25,-9),"Вызов койки %d" % (i+1))
	for i: int in range(3):
		control(s,"pressure_%d" % i,Vector3(27+i*2,1.25,-29),"Давление "+["I","II","III"][i]+" • 0–5")
		control(s,"mixture_%d" % i,Vector3(12+i*2,1.25,-86),"Реагент "+["A","B","C"][i]+" • 0–3")
	for data: Array in [["hospital_fuse_safe","safe",Vector3(-23,.425,26),""],["ward_case","locker_container",Vector3(-57,1.05,3),"hospital_wards"],["surgery_case","locker_container",Vector3(56,1.05,-43),"hospital_surgery"],["morgue_safe","safe",Vector3(-24,.425,-85),""],["badge_case","cage",Vector3(24,1,-72),"hospital_serum"],["scalpel_case","locker_container",Vector3(25,1.05,-44),""]]:
		var box: Node3D = s.add_object(data[0],data[1],"Хранилище больницы • осмотреть",data[2]); box.gate_rule = data[3]
		if data[0] == "scalpel_case": box.locked = true; box.required_key = "hospital_key"
	for data: Array in [["fuse","hospital_fuse_safe"],["specimen_a","ward_case"],["specimen_b","surgery_case"],["specimen_c","morgue_safe"],["hospital_badge","badge_case"],["scalpel","scalpel_case"]]:
		var box: Node3D = s.objects[data[1]]
		var item: Node3D = s.add_object(data[0],data[0],s.items.NAMES[data[0]],box.position+Vector3(0,-.15 if box.kind=="safe" else -.4,.1)); item.container_id = data[1]
	for data: Array in [["admission_note",Vector3(-18,1.08,28),"Журнал поступлений"],["ward_note",Vector3(-53,1.08,-44),"Дежурство в палатах"],["surgery_note",Vector3(52,1.08,5),"Журнал автоклава"],["laboratory_note",Vector3(18,1.08,-98),"Рецептура и морг"]]:
		s.LAYOUT._prop(s,"desk",data[1]-Vector3(0,1.08,0),0,Vector3(2.5,1.05,.85))
		s.LAYOUT._note(s,data[0],data[2],data[1],"Журнал этой смены")
	var boxes: Array = [Vector3(23,1.05,25),Vector3(-25,1.05,60),Vector3(23,1.05,60),Vector3(-26,1.05,45),Vector3(-57,1.05,-44),Vector3(-25,1.05,-24),Vector3(-57,1.05,-4),Vector3(57,1.05,-24),Vector3(25,1.05,-4),Vector3(57,1.05,4),Vector3(-24,1.05,-72),Vector3(-24,1.05,-98),Vector3(24,1.05,-98),Vector3(9,1.05,-72)]
	for i: int in range(boxes.size()): s.add_object("hospital_supply_box_%d" % i,"locker_container","Медицинский шкаф • осмотреть",boxes[i])
	for i: int in range(13):
		var kind: String = ["hospital_key","battery","battery","battery","medkit","medkit","sedative","sedative","sedative","sedative","thermos","thermos","thermos"][i]
		s.add_object("hospital_supply_%d" % i,kind,s.items.NAMES[kind],Vector3(0,.3,10))
	for i: int in range(6): s.add_object("shell_%d" % i,"shell","Патрон 12 калибра",Vector3(0,.05,8))
	s.refresh_containers()
static func station(s: Node3D,id: String,at: Vector3,title: String) -> void:
	s.add_object(id,"hospital_station",title,at)
static func control(s: Node3D,id: String,at: Vector3,title: String) -> void:
	s.add_object(id,"hospital_control",title,at)
	s.block(at-Vector3(0,.65,0),Vector3(.1,1.3,.1),"293e40",false)
static func _segment(s: Node3D,vertical: bool,at: float,start: float,end: float) -> void:
	s.DEPOT._segment(s,vertical,at,start,end)
