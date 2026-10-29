extends Node
## All parts, installation, gate controls and escape are owned by the host.
const PARTS := ["car_battery","spark_plugs","drive_belt","wheel","fuel","car_key"]
const LABELS := {"car_battery":"Аккумулятор","spark_plugs":"Свечи зажигания","drive_belt":"Ремень привода","wheel":"Запасное колесо","fuel":"Бензин","car_key":"Ключ зажигания"}
var station: Node3D
var installed: Array = []
var installing: String = ""
var installer_id: int = 0
var install_progress: float = 0
var seconds_left: float = 2100
var result: String = ""
var generator_on: bool = false
var emergency: String = ""
var emergency_left: float = 0
var emergency_repair: float = 0
var circuit: Array = [0,0,0]
var circuit_solution: Array = [1,2,3]
var circuit_ready: bool = false
var starter_progress: float = 0
var escape_time: float = -1
var holders: Array[int] = []
var repairers: Array[int] = []
var engine_holder: int = 0
var car_origin := Vector3(0,.8,23)

func randomize_round() -> void:
	var previous: Dictionary = NetworkManager.last_depot_puzzles
	var code: String = str(randi_range(1000,9999))
	while code == previous.get("safe",""): code = str(randi_range(1000,9999))
	station.objects.parts_safe.code = code
	station.objects.depot_note_a.description = "ЗАКАЗ НА СВЕЧИ\nСейф ремонтного бокса C. Первые две цифры: "+code.left(2)+".\nВторую половину кода оставили в общежитии E.\nКлюч топливной клетки хранится в шкафчике охраны E."
	station.objects.depot_note_b.description = "ЖУРНАЛ ДЕЖУРНОГО\nПоследние две цифры сейфа C: "+code.right(2)+".\nАккумулятор и бензин — в клетке B.\nКолесо — в шкафу склада шин B; ремень — в северном хранилище D.\nКлюч зажигания — в личном шкафчике общежития."
	circuit_solution = [randi_range(0,5),randi_range(0,5),randi_range(0,5)]
	while circuit_solution == previous.get("circuit",[]) or circuit_solution == [0,0,0]: circuit_solution = [randi_range(0,5),randi_range(0,5),randi_range(0,5)]
	station.objects.depot_wiring_note.description = "ПУСКОВОЙ ЩИТ\nКонтакты L / N / PE этой смены: %d / %d / %d.\nНа каждом регуляторе значения 0–5. Восстановленная цепь включает освещение и снимает замок хранилища D.\nФонарь не защищает от смотрителя вблизи." % circuit_solution
	NetworkManager.last_depot_puzzles = {"safe":code,"circuit":circuit_solution.duplicate()}

func begin_frame() -> void:
	holders.clear()
	repairers.clear()

func turn_dial(player: Node3D, object: Node3D) -> void:
	if circuit_ready: return
	var index: int = int(object.object_id.trim_prefix("depot_dial_"))
	circuit[index] = (int(circuit[index])+1)%6
	station.tell(player.peer_id,"Контакты L / N / PE: %d / %d / %d" % circuit)
	station.sound_event.rpc("switch",object.position)
	if circuit == circuit_solution:
		circuit_ready = true
		generator_on = true
		station.objects.belt_locker.locked = false
		station.announce.rpc("Пусковой щит восстановлен. Северное хранилище D разблокировано.")
	station.sync_state()

func interact(player: Node3D, object: Node3D) -> void:
	if not result.is_empty() or escape_time >= 0: return
	if object.kind in ["generator","ventilation"]:
		if not emergency.is_empty(): repairers.append(player.peer_id)
		return
	if object.kind != "vehicle": return
	if installed.size() == PARTS.size():
		holders.append(player.peer_id)
		return
	if not installing.is_empty() and installer_id != player.peer_id: return
	for part: String in PARTS:
		if not part in installed and part in player.inventory:
			if installing != part:
				installing = part
				installer_id = player.peer_id
				install_progress = 0
			holders.append(player.peer_id)
			return
	if player.action_cooldown <= 0:
		station.tell(player.peer_id,"Нужна недостающая деталь. Поднесите её к машине и удерживайте E.")
		player.action_cooldown = 1.5

func tick(delta: float) -> void:
	if not result.is_empty(): return
	if escape_time >= 0:
		escape_time += delta
		_update_escape()
		if escape_time >= 4: finish("Победа! Машина вырвалась с автобазы. Последний рейс завершён.")
		return
	seconds_left = maxf(0,seconds_left-delta)
	var living: int = 0
	for actor: Node3D in station.players.get_children():
		if actor.health > 0: living += 1
	if station.players.get_child_count() > 0 and living == 0: finish("Все участники ранены. Автобаза осталась вашей могилой."); return
	if seconds_left <= 0: finish("Время вышло. Вы не успели подготовить машину."); return
	if not emergency.is_empty():
		emergency_left = maxf(0,emergency_left-delta)
		if not repairers.is_empty():
			emergency_repair += delta
			if emergency_repair >= 6:
				emergency = ""; emergency_left = 0; emergency_repair = 0
				generator_on = circuit_ready
				station.announce.rpc("Аварийная блокировка ворот снята. Можно продолжить ремонт машины.")
		if not emergency.is_empty() and emergency_left <= 0: finish("Топливные пары воспламенились. Команда не успела устранить утечку."); return
	if holders.is_empty():
		install_progress = maxf(0,install_progress-delta*.4)
		if install_progress <= 0: installing = ""; installer_id = 0
		starter_progress = maxf(0,starter_progress-delta)
		return
	var actor: Node3D = station.players.get_node_or_null(str(holders[0]))
	if not actor: return
	if installed.size() < PARTS.size():
		if not installing in actor.inventory: return
		install_progress += delta*(1.5 if actor.is_technician() else 1.0)
		if install_progress >= 2.5:
			if station.items.consume(actor,installing):
				installed.append(installing)
				station.sound_event.rpc("mechanism",station.objects.escape_car.position)
				station.make_noise(station.objects.escape_car.position,18)
			installing = ""; install_progress = 0; installer_id = 0
	elif emergency.is_empty():
		var missing := PackedStringArray()
		for other: Node3D in station.players.get_children():
			if not other.dead and other.position.distance_to(car_origin) > 6: missing.append(other.nickname)
		if not missing.is_empty():
			if actor.action_cooldown <= 0:
				station.tell(actor.peer_id,"Соберите команду у машины: "+", ".join(missing))
				actor.action_cooldown = 2
			return
		starter_progress += delta
		station.make_noise(car_origin,45)
		if starter_progress >= 4:
			escape_time = 0
			var seat: int = 0
			for other: Node3D in station.players.get_children():
				if other.dead: continue
				other.in_vehicle = true
				other.vehicle_seat = seat
				seat += 1
			station.objects.exit_gate.opened = true
			station.objects.exit_gate.refresh()
			station.announce.rpc("Двигатель завёлся. Выезжаем!")
			station.sync_state()

func _update_escape() -> void:
	station.objects.escape_car.position = car_origin+Vector3(0,0,minf(escape_time,4)*5)
	for actor: Node3D in station.players.get_children():
		if actor.in_vehicle:
			actor.position = station.objects.escape_car.position+Vector3(-.55 if actor.vehicle_seat%2 == 0 else .55,-.65,-.6 if actor.vehicle_seat < 2 else .7)
			actor.net_position = actor.position
			actor.net_yaw = PI
			actor.velocity = Vector3.ZERO

func sabotage(_kind: String) -> bool:
	if not multiplayer.is_server() or not emergency.is_empty() or escape_time >= 0 or not result.is_empty(): return false
	emergency = "generator"; emergency_left = 120; emergency_repair = 0
	generator_on = false
	station.announce.rpc("АВАРИЯ: смотритель повредил топливную магистраль! 2 минуты на ремонт аварийного клапана A.")
	station.sound_event.rpc("alarm",station.objects.generator.position)
	station.sync_state()
	return true

func finish(message: String) -> void:
	result = message
	station.sync_state()

func task_text() -> String:
	if escape_time >= 0: return "ПОСЛЕДНИЙ РЕЙС\nКоманда покидает автобазу…"
	if not emergency.is_empty(): return "УТЕЧКА • %02d:%02d ДО ВЗРЫВА\nАварийный клапан A, удерживайте E: %d%%" % [ceili(emergency_left)/60,ceili(emergency_left)%60,int(emergency_repair/6*100)]
	if installed.size() == PARTS.size(): return "МАШИНА ГОТОВА • %d%%\nВсем выжившим — к машине A.\nУдерживайте E, чтобы завести двигатель." % int(starter_progress/4*100)
	var missing := PackedStringArray()
	for part: String in PARTS:
		if not part in installed: missing.append(LABELS[part])
	return "ПОДГОТОВЬТЕ МАШИНУ • %d / 6\n%s\nУ машины удерживать E: %d%%" % [installed.size(),", ".join(missing),int(install_progress/2.5*100)]

func snapshot() -> Dictionary:
	return {"installed":installed,"installing":installing,"install_progress":install_progress,"time":seconds_left,"result":result,"generator":generator_on,"emergency":emergency,"emergency_left":emergency_left,"emergency_repair":emergency_repair,"circuit":circuit,"solution":circuit_solution,"circuit_ready":circuit_ready,"starter":starter_progress,"escape":escape_time}

func apply_snapshot(data: Dictionary) -> void:
	installed = data.installed.duplicate(); installing = data.installing; install_progress = data.install_progress
	seconds_left = data.time; result = data.result; generator_on = data.generator
	emergency = data.emergency; emergency_left = data.emergency_left; emergency_repair = data.emergency_repair
	circuit = data.circuit.duplicate(); circuit_solution = data.solution.duplicate(); circuit_ready = data.circuit_ready
	starter_progress = data.starter; escape_time = data.escape
