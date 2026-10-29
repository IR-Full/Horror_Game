extends Node
## Fictional hospital escape. All puzzle solutions, inventory and outcomes belong to host.
var station: Node3D
var seconds_left: float = 2400
var result: String = ""
var generator_on: bool = false
var powered: bool = false
var emergency: String = ""
var emergency_left: float = 0
var emergency_repair: float = 0
var power_progress: float = 0
var ward_solution: Array = [0,1,2,3]
var ward_input: Array = []
var ward_ready: bool = false
var ward_lock: float = 0
var pressure: Array = [0,0,0]
var pressure_solution: Array = [1,2,3]
var pressure_ready: bool = false
var surgery_progress: float = 0
var surgery_ready: bool = false
var mixture: Array = [0,0,0]
var mixture_solution: Array = [1,2,3]
var samples: Array = []
var analyzer_progress: float = 0
var analyzer_item: String = ""
var analyzer_owner: int = 0
var serum_progress: float = 0
var serum_ready: bool = false
var exit_progress: float = 0
var holders: Dictionary = {}
var hazard_clock: float = 3
const SAMPLES := ["specimen_a","specimen_b","specimen_c"]

func randomize_round() -> void:
	var history := ConfigFile.new()
	var history_path: String = SettingsManager.save_path.get_base_dir().path_join("last_hospital_puzzles.cfg")
	history.load(history_path)
	var previous: Dictionary = NetworkManager.last_hospital_puzzles if not NetworkManager.last_hospital_puzzles.is_empty() else history.get_value("puzzles","solutions",{})
	var safe: String = str(randi_range(1000,9999))
	while safe == previous.get("safe",""): safe = str(randi_range(1000,9999))
	var morgue: String = str(randi_range(1000,9999))
	while morgue == previous.get("morgue","") or morgue == safe: morgue = str(randi_range(1000,9999))
	station.objects.hospital_fuse_safe.code = safe; station.objects.morgue_safe.code = morgue
	ward_solution = [0,1,2,3]; ward_solution.shuffle()
	while ward_solution == previous.get("ward",[]): ward_solution.shuffle()
	pressure_solution = _digits(6,previous.get("pressure",[])); mixture_solution = _digits(4,previous.get("mixture",[]))
	station.objects.admission_note.description = "ПАВИЛЬОН 13. ЖУРНАЛ ПОСТУПЛЕНИЙ\nПервые две цифры сейфа электрощитовой A: "+safe.left(2)+". Продолжение у дежурного палат B.\nПредохранитель вставить в щит A03, удерживая E.\nЭто заброшенный комплекс: доктор не человек. Не отвечайте на его обход.\nПосле получения допуска соберите всех у лифта A."
	station.objects.ward_note.description = "ДЕЖУРСТВО В ПАЛАТАХ\nПоследние две цифры сейфа A: "+safe.right(2)+".\nПри работающем питании нажмите вызовы коек в порядке: %d → %d → %d → %d. Ошибка поднимет тревогу.\nПосле проверки разблокируется шкаф образца I в B.\nКлюч инструментального шкафа C — в одном из медицинских шкафчиков больницы." % [ward_solution[0]+1,ward_solution[1]+1,ward_solution[2]+1,ward_solution[3]+1]
	station.objects.surgery_note.description = "ЖУРНАЛ АВТОКЛАВА\nДавление I / II / III: %d / %d / %d (значения 0–5).\nВозьмите окровавленный скальпель из запертого инструментального шкафа C. При включённом питании удерживайте E у автоклава шесть секунд.\nПосле стерилизации откроется шкаф образца II. Не оставляйте товарищей в операционной." % pressure_solution
	station.objects.laboratory_note.description = "РЕЦЕПТУРА И ХОЛОДИЛЬНАЯ\nСейф морга D: "+morgue+". В нём образец III. Без питания морг переохлаждает.\nДля анализатора E нужны образцы I, II, III. Подносите каждый и удерживайте E.\nРеагенты A / B / C: %d / %d / %d (значения 0–3). После загрузки удерживайте E ещё шесть секунд.\nОткроется клетка допуска к эвакуационному лифту. Во время аварии работать нельзя." % mixture_solution
	NetworkManager.last_hospital_puzzles = {"safe":safe,"morgue":morgue,"ward":ward_solution.duplicate(),"pressure":pressure_solution.duplicate(),"mixture":mixture_solution.duplicate()}
	history.set_value("puzzles","solutions",NetworkManager.last_hospital_puzzles); history.save(history_path)
func _digits(limit: int,previous: Array) -> Array:
	var digits: Array = [randi_range(0,limit-1),randi_range(0,limit-1),randi_range(0,limit-1)]
	while digits == previous or digits == [0,0,0]: digits = [randi_range(0,limit-1),randi_range(0,limit-1),randi_range(0,limit-1)]
	return digits
func begin_frame() -> void: holders.clear()
func is_unlocked(rule: String) -> bool:
	match rule:
		"hospital_wards": return ward_ready
		"hospital_surgery": return surgery_ready
		"hospital_serum": return serum_ready
	return true
func interact(player: Node3D,object: Node3D) -> void:
	if not result.is_empty(): return
	if not holders.has(object.object_id): holders[object.object_id] = []
	holders[object.object_id].append(player.peer_id)
func _actor(id: String) -> Node3D:
	for peer: int in holders.get(id,[]):
		var player: Node3D = station.players.get_node_or_null(str(peer))
		if player and player.health>0 and not player.dead: return player
	return null
func _tell(player: Node3D,text: String) -> void:
	if player.action_cooldown>0: return
	station.tell(player.peer_id,text); player.action_cooldown = 1.5
func control(player: Node3D,object: Node3D) -> void:
	if not result.is_empty(): return
	if not generator_on or not emergency.is_empty(): _tell(player,"Нужно питание, а авария должна быть устранена."); return
	var index: int = int(object.object_id.get_slice("_",1))
	if object.object_id.begins_with("ward_"):
		if ward_ready or ward_lock>0: return
		ward_input.append(index)
		if ward_input != ward_solution.slice(0,ward_input.size()):
			ward_input.clear(); ward_lock = 4
			player.stress = minf(100,player.stress+8)
			station.make_noise(object.position,35); station.sound_event.rpc("alarm",object.position)
			_tell(player,"Неверный порядок коек. Защита на четыре секунды.")
		elif ward_input.size()==4:
			ward_ready = true; station.announce.rpc("Вызовы коек проверены. Шкаф образца I в B открыт.")
		else: _tell(player,"Вызовы: %d / 4" % ward_input.size())
	elif object.object_id.begins_with("pressure_") and not pressure_ready:
		pressure[index] = (int(pressure[index])+1)%6; pressure_ready = pressure == pressure_solution
		_tell(player,"Давление I / II / III: %d / %d / %d" % pressure)
	elif object.object_id.begins_with("mixture_") and not serum_ready:
		mixture[index] = (int(mixture[index])+1)%4
		_tell(player,"Реагенты A / B / C: %d / %d / %d" % mixture)
	station.sound_event.rpc("switch",object.position); station.sync_state()
func tick(delta: float) -> void:
	if not result.is_empty(): return
	seconds_left = maxf(0,seconds_left-delta); ward_lock = maxf(0,ward_lock-delta)
	var living: int = 0
	for player: Node3D in station.players.get_children():
		if player.health>0: living += 1
	if station.players.get_child_count()>0 and living==0: finish("Все участники ранены. Доктор продолжает обход."); return
	if seconds_left<=0: finish("Время вышло. Павильон 13 остался заперт."); return
	if not emergency.is_empty():
		emergency_left = maxf(0,emergency_left-delta)
		var repairer: Node3D = _actor(emergency)
		if repairer:
			emergency_repair += delta*(1.5 if repairer.is_technician() else 1)
			if emergency_repair>=6:
				emergency = ""; emergency_left = 0; emergency_repair = 0; generator_on = powered
				station.announce.rpc("Авария больницы устранена.")
		else: emergency_repair = maxf(0,emergency_repair-delta*.3)
		if not emergency.is_empty() and emergency_left<=0: finish("Вытяжка остановилась. Команда погибла в павильоне."); return
	var player: Node3D = _actor("generator")
	if not powered and emergency.is_empty():
		if player and "fuse" in player.inventory:
			power_progress += delta*(1.5 if player.is_technician() else 1)
			if power_progress>=4 and station.items.consume(player,"fuse"):
				powered = true; generator_on = true; station.announce.rpc("Резервное питание включено. Начните проверку палат и автоклава.")
		else:
			power_progress = maxf(0,power_progress-delta)
			if player: _tell(player,"Нужен предохранитель из сейфа приёмного отделения A.")
	if generator_on and emergency.is_empty():
		_tick_surgery(delta); _tick_analyzer(delta); _tick_exit(delta)
	else: exit_progress = maxf(0,exit_progress-delta)
	hazard_clock -= delta
	if hazard_clock<=0:
		hazard_clock = 3
		if not generator_on:
			for actor: Node3D in station.players.get_children():
				if actor.position.x < -4 and actor.position.z < -66 and actor.health>0: actor.damage(2)
func _tick_surgery(delta: float) -> void:
	if surgery_ready: return
	var player: Node3D = _actor("sterilizer")
	if not player or not pressure_ready or not "scalpel" in player.inventory:
		surgery_progress = maxf(0,surgery_progress-delta*.4)
		if player: _tell(player,"Нужны скальпель и давление из журнала C.")
		return
	surgery_progress += delta*(1.5 if player.is_technician() else 1)
	if surgery_progress>=6 and station.items.consume(player,"scalpel"):
		surgery_ready = true; station.announce.rpc("Автоклав завершил цикл. Образец II доступен в C."); station.sync_state()
func _tick_analyzer(delta: float) -> void:
	if serum_ready: return
	var player: Node3D = _actor("analyzer")
	if not player:
		analyzer_progress = maxf(0,analyzer_progress-delta)
		if analyzer_progress<=0: analyzer_item = ""; analyzer_owner = 0
		serum_progress = maxf(0,serum_progress-delta*.4); return
	if samples.size()<3:
		if analyzer_owner != 0 and analyzer_owner != player.peer_id: return
		for sample: String in SAMPLES:
			if not sample in samples and sample in player.inventory:
				if analyzer_item != sample: analyzer_item = sample; analyzer_owner = player.peer_id; analyzer_progress = 0
				analyzer_progress += delta
				if analyzer_progress>=2 and station.items.consume(player,sample):
					samples.append(sample); analyzer_item = ""; analyzer_owner = 0; analyzer_progress = 0; station.sync_state()
				return
		_tell(player,"Поднесите недостающий образец I / II / III.")
	elif mixture == mixture_solution:
		serum_progress += delta
		if serum_progress>=6:
			serum_ready = true; station.announce.rpc("Анализ завершён. Клетка допуска E разблокирована. Соберите команду у лифта A."); station.sync_state()
	else: _tell(player,"Реагенты выставлены неверно. Рецептура — в журнале E.")
func _tick_exit(delta: float) -> void:
	var player: Node3D = _actor("hospital_exit")
	if not player or not serum_ready or not "hospital_badge" in player.inventory:
		exit_progress = maxf(0,exit_progress-delta)
		if player: _tell(player,"Нужен допуск из лаборатории E и работающая резервная сеть.")
		return
	for actor: Node3D in station.players.get_children():
		if not actor.dead and actor.position.distance_to(station.objects.hospital_exit.position)>7:
			_tell(player,"Соберите всех выживших в пределах семи метров от лифта."); exit_progress = 0; return
	exit_progress += delta; station.make_noise(station.objects.hospital_exit.position,24)
	if exit_progress>=8 and station.items.consume(player,"hospital_badge"): finish("Победа! Аварийный лифт вывез команду из павильона 13.")
func sabotage(kind: String) -> bool:
	if not multiplayer.is_server() or not result.is_empty() or not emergency.is_empty(): return false
	emergency = kind if kind in ["generator","ventilation"] else "ventilation"
	emergency_left = 120; emergency_repair = 0
	if emergency=="generator": generator_on = false
	station.announce.rpc("АВАРИЯ: доктор повредил "+("щит A" if emergency=="generator" else "вытяжку C")+". Две минуты на ремонт: удерживайте E.")
	station.sound_event.rpc("alarm",station.objects[emergency].position); station.sync_state(); return true
func finish(message: String) -> void:
	result = message; station.sync_state()
func task_text() -> String:
	if not emergency.is_empty(): return "АВАРИЯ • %02d:%02d\n%s • ремонт: %d%%" % [ceili(emergency_left)/60,ceili(emergency_left)%60,"Щит A" if emergency=="generator" else "Вытяжка C",int(emergency_repair/6*100)]
	if not powered: return "ПАВИЛЬОН 13 • ПИТАНИЕ\nКод сейфа A: журналы A + B. Найдите предохранитель.\nЩит A03 • удерживать E: %d%%" % int(power_progress/4*100)
	if not serum_ready: return "ОБРАЗЦЫ I / II / III • %d / 3\nB: вызовы %d/4 • C: автоклав %d%% • D: сейф по журналу E\nАнализатор E: образец %d%% • синтез %d%%" % [samples.size(),4 if ward_ready else ward_input.size(),100 if surgery_ready else int(surgery_progress/6*100),int(analyzer_progress/2*100),int(serum_progress/6*100)]
	return "ДОПУСК ГОТОВ • ЛИФТ A\nВозьмите карту из клетки E. Всем выжившим к лифту.\nУдерживать E: %d%%" % int(exit_progress/8*100)
func snapshot() -> Dictionary:
	return {"time":seconds_left,"result":result,"generator":generator_on,"powered":powered,"emergency":emergency,"emergency_left":emergency_left,"repair":emergency_repair,"power_progress":power_progress,"ward_solution":ward_solution,"ward_input":ward_input,"ward_ready":ward_ready,"ward_lock":ward_lock,"pressure":pressure,"pressure_solution":pressure_solution,"pressure_ready":pressure_ready,"surgery_progress":surgery_progress,"surgery_ready":surgery_ready,"mixture":mixture,"mixture_solution":mixture_solution,"samples":samples,"analyzer_progress":analyzer_progress,"serum_progress":serum_progress,"serum_ready":serum_ready,"exit_progress":exit_progress}
func apply_snapshot(data: Dictionary) -> void:
	seconds_left=data.time; result=data.result; generator_on=data.generator; powered=data.powered; emergency=data.emergency; emergency_left=data.emergency_left; emergency_repair=data.repair; power_progress=data.power_progress
	ward_solution=data.ward_solution.duplicate(); ward_input=data.ward_input.duplicate(); ward_ready=data.ward_ready; ward_lock=data.ward_lock
	pressure=data.pressure.duplicate(); pressure_solution=data.pressure_solution.duplicate(); pressure_ready=data.pressure_ready; surgery_progress=data.surgery_progress; surgery_ready=data.surgery_ready
	mixture=data.mixture.duplicate(); mixture_solution=data.mixture_solution.duplicate(); samples=data.samples.duplicate(); analyzer_progress=data.analyzer_progress; serum_progress=data.serum_progress; serum_ready=data.serum_ready; exit_progress=data.exit_progress
