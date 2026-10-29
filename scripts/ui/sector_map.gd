extends Control
const LAYOUT := preload("res://scripts/world/sector_layout.gd")
const LEGEND := ["A • ЖИЛОЙ И СЛУЖЕБНЫЙ СЕКТОР", "01 Склад • 02 Медпункт • 03 Генераторная", "04 Архив • 05 Жилой блок • 06 Радиорубка", "07 Мастерская • 08 Карантин • 09 Релейная", "10 Лаборатория • 11 Насосная • 12 Холодильник", "B • КОТЕЛЬНАЯ", "01 Котельный зал • 02 Коллектор", "03 Топливное хранилище • 04 Диспетчерская", "C • ЛАБОРАТОРИИ", "01 Фильтрация • 02 Культуры", "03 Чистая комната • 04 Токсичный архив", "D • УЗЕЛ СВЯЗИ", "01 Настройка • 02 Аппаратная", "03 Резерв • 04 Передача сигнала", "E • ДРЕНАЖНЫЙ КОМПЛЕКС", "01 Дежурная • 02 Запчасти • 03 Контакторная", "04 Машинный зал • 05 Приёмник • 06 Аварийный склад"]
const SCALE := 3.1
var rooms: Array = []
var clock: float = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in range(6):
		var z: float = [4,-4,-13,-26,-38,-51][i]
		var depth: float = [9,8,9,13,12,13][i]
		for side: int in range(2):
			rooms.append([Rect2(-15 if side == 0 else 3,z,12,depth),"A%02d" % (i*2+side+1),Color("314e4a")])
	for cx: float in [-45,45]:
		for i: int in range(4):
			rooms.append([Rect2(cx-18+(i%2)*18,-52 if i<2 else -29,18,17), ("B" if cx<0 else "C")+"%02d" % (i+1),Color("514538") if cx<0 else Color("314a51")])
	for i: int in range(4):
		rooms.append([Rect2(-21 if i%2==0 else 3,-84 if i<2 else -105,18,21),"D%02d" % (i+1),Color("3e4358")])

	for i: int in range(6):
		rooms.append([Rect2(-24 if i%2==0 else 3,25+(i/2)*14,21,14),"E%02d" % (i+1),Color("324f52")])

func point(p: Vector2) -> Vector2:
	return Vector2(325+p.x*SCALE,340+p.y*SCALE)

func _process(delta: float) -> void:
	clock -= delta
	if clock <= 0: clock=.1; queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for region: Rect2 in LAYOUT.FLOORS:
		draw_rect(Rect2(point(region.position),region.size*SCALE),Color("172c2e"))
	for room: Array in rooms:
		var rect := Rect2(point(room[0].position),room[0].size*SCALE)
		draw_rect(rect,room[2])
		draw_string(font,rect.position+Vector2(5,13),room[1],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("c9c9b2"))
	if not is_instance_valid(GameManager.world): return
	var world: Node3D = GameManager.world
	for wall: Rect2 in world.walls_for_map:
		draw_rect(Rect2(point(wall.position),Vector2(maxf(1.4,wall.size.x*SCALE),maxf(1.4,wall.size.y*SCALE))),Color("8da49a"))
	for object: Node3D in world.objects.values():
		var at: Vector2 = point(Vector2(object.position.x,object.position.z))
		if object.kind == "door":
			var along := Vector2(0,5).rotated(-object.rotation.y)
			draw_line(at-along,at+along,Color("d18469") if object.locked else (Color("5caf9d") if object.opened else Color("c5b37d")),2)
		elif object.kind in ["generator","transmitter","power","purifier","circuit","drain_pump","drain_switch"]:
			draw_string(font,at+Vector2(-3,-2),{"generator":"G","transmitter":"T","power":"P","purifier":"F","circuit":"C","drain_pump":"W","drain_switch":"E"}[object.kind],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f1cc78"))
		elif object.kind == "hatch": draw_circle(at,3,Color("aa94cc"))
	for player: Node3D in world.players.get_children():
		var at: Vector2 = point(Vector2(player.position.x,player.position.z))
		var tint: Color = Color("f2cd77") if player.is_local() else Color("8de4ba")
		if player.health <= 0: tint = Color("f5836b")
		if player.sos_left > 0 and player.health <= 0: draw_arc(at,8+sin(Time.get_ticks_msec()*.01)*2,0,TAU,24,tint,2)
		draw_circle(at,3.5,tint)
		draw_line(at,at+Vector2(-sin(player.net_yaw),-cos(player.net_yaw))*9,tint,2)
		draw_string(font,at+Vector2(6,-6),player.nickname,HORIZONTAL_ALIGNMENT_LEFT,-1,11,tint)
	draw_string(font,Vector2(10,597),"Комнаты • коридоры • двери • оборудование • вентиляция • участники",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("9cb6ab"))
