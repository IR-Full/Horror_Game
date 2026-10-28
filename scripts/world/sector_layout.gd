extends RefCounted
## Four physically connected sectors. Rectangles are also the walkable floor mask.
const FLOORS := [Rect2(-15, -51, 30, 64), Rect2(-63, -52, 36, 40), Rect2(27, -52, 36, 40), Rect2(-21, -105, 42, 42), Rect2(-27, -34, 12, 4), Rect2(15, -34, 12, 4), Rect2(-3, -63, 6, 12)]
const EXTENT := Rect2i(-64, -106, 129, 120)

static func sector_at(p: Vector3) -> String:
	if p.x < -26: return "B • КОТЕЛЬНАЯ"
	if p.x > 26: return "C • ЛАБОРАТОРИИ"
	if p.z < -62: return "D • УЗЕЛ СВЯЗИ"
	if absf(p.x) > 15 or p.z < -51: return "СЛУЖЕБНЫЙ ПЕРЕХОД"
	return "A • ЖИЛОЙ БЛОК"

static func build(s: Node3D) -> void:
	for side: float in [-1, 1]:
		var x: float = side * 21
		s.block(Vector3(x, -.2, -32), Vector3(12, .4, 4), "313c3e")
		s.block(Vector3(x, 3.4, -32), Vector3(12, .2, 4), "202c30")
		for z: float in [-34, -30]:
			s.block(Vector3(x, 1.6, z), Vector3(12, 3.2, .25), "465354")
		s.sign_text("СЕКТОР B • КОТЕЛЬНАЯ" if side < 0 else "СЕКТОР C • ЛАБОРАТОРИИ", Vector3(x, 2.8, -32), -side*PI/2, 28)
		_wing(s, side)
	s.block(Vector3(0, -.2, -57), Vector3(6, .4, 12), "313c3e")
	s.block(Vector3(0, 3.4, -57), Vector3(6, .2, 12), "202c30")
	for x: float in [-3, 3]:
		s.block(Vector3(x, 1.6, -57), Vector3(.25, 3.2, 12), "465354")
	_north(s)
	_props_and_tasks(s)
	s.sign_text("A • ЖИЛОЙ БЛОК\nB ← КОТЕЛЬНАЯ    ЛАБОРАТОРИИ → C\n↑ D • УЗЕЛ СВЯЗИ\nM — СХЕМА СТАНЦИИ", Vector3(-2.85, 2.0, -28), PI/2, 20)

static func _wing(s: Node3D, side: float) -> void:
	var cx: float = side * 45
	s.block(Vector3(cx, -.2, -32), Vector3(36, .4, 40), "313c3e")
	s.block(Vector3(cx, 3.4, -32), Vector3(36, .2, 40), "202c30")
	s.block(Vector3(side*63, 1.6, -32), Vector3(.3, 3.2, 40), "465354")
	for z: float in [-52, -12]:
		s.block(Vector3(cx, 1.6, z), Vector3(36, 3.2, .3), "465354")
	for z: float in [-43, -21]:
		s.block(Vector3(side*27, 1.6, z), Vector3(.3, 3.2, 18), "465354")
		s.block(Vector3(cx, 1.6, z), Vector3(.22, 3.2, 18), "475653")
	var titles: Array = ["КОТЕЛЬНЫЙ ЗАЛ", "КОЛЛЕКТОР", "ТОПЛИВНОЕ ХРАНИЛИЩЕ", "ДИСПЕТЧЕРСКАЯ"] if side < 0 else ["ФИЛЬТРАЦИЯ", "КУЛЬТУРЫ", "ЧИСТАЯ КОМНАТА", "ТОКСИЧНЫЙ АРХИВ"]
	var index: int = 0
	for z: float in [-35, -29]:
		for offset: float in [-9, 9]:
			var x: float = cx + offset
			for sign_x: float in [-1, 1]:
				s.block(Vector3(x+sign_x*5.05, 1.6, z), Vector3(7.9, 3.2, .22), "4c5b58")
			s.block(Vector3(x, 3.09, z), Vector3(2.28, .42, .32), "45524f")
			var door: Node3D = s.add_object("door_sector_%s_%d" % [int(side), index], "door", "Герметичная дверь", Vector3(x, 1.44, z))
			door.rotation.y = PI/2
			door.opened = true
			door.refresh()
			s.sign_text(("B" if side < 0 else "C") + "—%02d • " % [index+1] + titles[index], Vector3(x, 2.3, -51.75 if z == -35 else -12.25), 0 if z == -35 else PI, 26)
			_light(s, Vector3(x, 2.9, -43 if z == -35 else -21), Color("b78d67") if side < 0 else Color("82a9af"))
			index += 1
	for x: float in [cx-12, cx, cx+12]: _light(s, Vector3(x, 2.9, -32), Color("879f92"))

static func _north(s: Node3D) -> void:
	s.block(Vector3(0, -.2, -84), Vector3(42, .4, 42), "313c3e")
	s.block(Vector3(0, 3.4, -84), Vector3(42, .2, 42), "202c30")
	for x: float in [-21, 21]: s.block(Vector3(x, 1.6, -84), Vector3(.3, 3.2, 42), "465354")
	s.block(Vector3(0, 1.6, -105), Vector3(42, 3.2, .3), "465354")
	for x: float in [-12, 12]:
		s.block(Vector3(x, 1.6, -63), Vector3(18, 3.2, .3), "465354")
		s.block(Vector3(x, 1.6, -84), Vector3(18, 3.2, .22), "475653")
	for side: float in [-1, 1]:
		for data: Array in [[-66.95, 7.9], [-84, 21.8], [-101.05, 7.9]]:
			s.block(Vector3(side*3, 1.6, data[0]), Vector3(.22, 3.2, data[1]), "4c5b58")
		for z: float in [-72, -96]:
			s.door_frame(side*3, z)
			var door: Node3D = s.add_object("door_d_%d_%d" % [int(side), int(z)], "door", "Дверь узла связи", Vector3(side*3, 1.44, z))
			door.opened = true
			door.refresh()
			_light(s, Vector3(side*12, 2.9, z), Color("8e9ba9"))
			s.sign_text("D • НАСТРОЙКА ЧАСТОТЫ" if side < 0 else ("D • АППАРАТНАЯ" if z == -72 else "D • ПЕРЕДАЧА СИГНАЛА"), Vector3(side*12, 2.3, z-8.75), 0, 28)
	for z: float in [-68, -82, -98]: _light(s, Vector3(0, 2.9, z), Color("bfa578"))
	# Bulkhead at the sector entrance. Side panels close the wider bridge.
	for x: float in [-2.05, 2.05]: s.block(Vector3(x, 1.6, -63), Vector3(1.9, 3.2, .3), "475653")
	s.block(Vector3(0, 3.09, -63), Vector3(2.28, .42, .32), "45524f")
	var gate: Node3D = s.add_object("door_sector_d", "door", "Шлюз D • восстановите давление и фильтрацию", Vector3(0, 1.44, -63))
	gate.rotation.y = PI/2
	gate.locked = true
	gate.gate_rule = "sector_d"
	s.sign_text("СЕКТОР D • ШЛЮЗ\nДАВЛЕНИЕ B + ФИЛЬТРАЦИЯ C", Vector3(0, 3.16, -62.75), 0, 20)

static func _props_and_tasks(s: Node3D) -> void:
	for at: Vector3 in [Vector3(-58, 0, -47), Vector3(-50, 0, -47), Vector3(-33, 0, -47)]:
		_prop(s, "boiler", at, 0, Vector3(2.0, 2.8, 2.0))
	for i: int in range(3):
		var at: Vector3 = [Vector3(-54, 1.15, -42), Vector3(-36, 1.15, -42), Vector3(-54, 1.15, -20)][i]
		s.add_object("valve_%d" % i, "valve", "Вентиль • повернуть", at)
		_prop(s, "radiator", at-Vector3(0, 1.15, .25), PI, Vector3(1.5, 1, .45))
	_prop(s, "desk", Vector3(-36, 0, -17), 0, Vector3(2.5, 1.05, .85))
	_note(s, "pressure_note", "Схема отопления", Vector3(-36, 1.08, -17), "КОНТУР B\nТри вентиля: A — 2, B — 1, C — 3.\nПосле выравнивания давления запускается шлюз D.\nФильтрацию нужно восстановить отдельно в секторе C.")
	s.add_object("circuit", "circuit", "Пульт фильтров • логическая схема", Vector3(36, 1.25, -42))
	s.sign_text("C—04 • ЗАГРЯЗНЁННЫЙ АРХИВ", Vector3(57,2,-29.15),PI,16)
	var locker: Node3D = s.add_object("filter_locker", "locker_container", "Фильтр • блокировка пультом C", Vector3(54, 1.05, -20))
	locker.locked = true
	locker.gate_rule = "circuit"
	var cartridge: Node3D = s.add_object("air_filter", "air_filter", "Фильтрующий картридж", Vector3(54, .75, -19.9))
	cartridge.container_id = "filter_locker"
	s.add_object("purifier", "purifier", "Фильтрация C • вставить картридж, удерживать E", Vector3(39, 1.05, -42))
	for at: Vector3 in [Vector3(36,.65,-42),Vector3(-15,.65,-76),Vector3(-13,.65,-76),Vector3(-11,.65,-76)]:
		s.block(at,Vector3(.12,1.3,.12),"293e40",false)
		s.block(Vector3(at.x,.05,at.z),Vector3(.7,.1,.5),"293e40",false)
	_prop(s, "desk", Vector3(33, 0, -17), 0, Vector3(2.5, 1.05, .85))
	_note(s, "circuit_note", "Инструкция очистки", Vector3(33, 1.08, -17), "ПУЛЬТ C\nНажатая лампа меняет себя и соседей по кресту.\nПогасите все девять ламп — откроется шкаф фильтра.\nАрхив C—04 загрязнён: не задерживайтесь внутри.\nКартридж вставить в установку у пульта.\nДля запуска нужны генератор A и давление B.")
	for at: Vector3 in [Vector3(32, 0, -48), Vector3(40, 0, -48), Vector3(57, 0, -48), Vector3(57, 0, -15)]: _prop(s, "shelf", at, 0, Vector3(2.4, 1.7, .8))
	for i: int in range(3):
		s.add_object("tuner_%d" % i, "tuner", "Частота • повернуть", Vector3(-15+i*2, 1.25, -76))
	_note(s, "frequency_note", "Частотный журнал", Vector3(33.6, 1.08, -17), "ПЕРЕДАТЧИК D\nСтарая несущая: 47.2.\nТри разряда настройки: 4 / 7 / 2.\nРезервные реле A также должны быть настроены.\nЩит аварийного питания остаётся в радиорубке A—06.")
	for side: float in [-1, 1]:
		for z: float in [-72, -96]:
			for x: float in [side*10, side*17]: _prop(s, "radio_rack", Vector3(x, 0, z-5), PI, Vector3(.85, 2, .65))
	s.objects.transmitter.position = Vector3(12, .8, -96)
	s.block(Vector3(12, .12, -96), Vector3(1.65, .24, .7), "1c2f2c")
	# Extra supplies compensate for the much longer expedition; they are searchable.
	for data: Array in [["supply_b", Vector3(-32, 1.05, -19), "battery"], ["supply_c", Vector3(58, 1.05, -44), "medkit"], ["supply_d", Vector3(17, 1.05, -68), "battery"]]:
		var box: Node3D = s.add_object(data[0], "locker_container", "Шкаф снабжения • осмотреть", data[1])
		var item: Node3D = s.add_object(data[0]+"_item", data[2], s.items.NAMES[data[2]], box.position+Vector3(0, -.35, .1))
		item.container_id = data[0]
	s.refresh_containers()

static func _note(s: Node3D, id: String, title: String, at: Vector3, text: String) -> void:
	var obj: Node3D = s.add_object(id, "note", title, at)
	obj.description = text

static func _light(s: Node3D, at: Vector3, tint: Color) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = tint
	light.omni_range = 8.5
	light.set_meta("base_energy", .75)
	light.set_meta("standby", .1)
	s.add_child(light)
	s.lights.append(light)
	var lamp: Node3D = s.ART.model("lamp")
	lamp.position = Vector3(at.x, 3.16, at.z)
	s.add_child(lamp)

static func _prop(s: Node3D, kind: String, at: Vector3, yaw: float, bounds: Vector3) -> void:
	var model: Node3D = s.ART.model(kind)
	model.position = at
	model.rotation.y = yaw
	s.add_child(model)
	s._prop_collision(at+Vector3.UP*bounds.y*.5, bounds)
