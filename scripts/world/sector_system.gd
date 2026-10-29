extends Node
## Host-owned sector progression: pressure, Lights Out, filter purge and radio tuning.
var station: Node3D
var valves: Array = [0, 0, 0]
var frequency: Array = [0, 0, 0]
var circuit: Array = [1, 0, 1, 0, 1, 0, 1, 0, 1]
var pressure_ready: bool = false
var circuit_ready: bool = false
var filter_loaded: bool = false
var purge_progress: float = 0.0
var purified: bool = false
var tuned: bool = false
var purge_holders: Array[int] = []
var hazard_clock: float = 2.0
var valve_solution: Array = [2, 1, 3]
var frequency_solution: Array = [4, 7, 2]

func begin_frame() -> void:
	purge_holders.clear()

func randomize_round() -> void:
	circuit = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var moves: Array = range(9)
	moves.shuffle()
	for i: int in range(4): _toggle(moves[i])
	if circuit.count(1) == 0: _toggle(4)

func is_unlocked(rule: String) -> bool:
	if station.map_id == 1:
		return station.objectives.circuit_ready if rule == "depot_circuit" else (station.objectives.escape_time >= 0 if rule == "depot_exit" else true)
	if rule == "drainage": return station.drainage.drained
	return (pressure_ready and purified) if rule == "sector_d" else (circuit_ready if rule == "circuit" else true)

func handle_object(player: Node3D, object: Node3D) -> void:
	match object.kind:
		"valve":
			if pressure_ready: return
			var index: int = int(object.object_id.trim_prefix("valve_"))
			valves[index] = (int(valves[index])+1)%4
			if valves == valve_solution:
				pressure_ready = true
				station.announce.rpc("Контур B: давление выровнено. Нужна фильтрация C для открытия шлюза D.")
			station.sound_event.rpc("mechanism", object.position)
		"tuner":
			if tuned: return
			var index: int = int(object.object_id.trim_prefix("tuner_"))
			frequency[index] = (int(frequency[index])+1)%10
			if frequency == frequency_solution:
				tuned = true
				station.announce.rpc("Несущая установлена. Передатчик D готов к работе.")
			station.sound_event.rpc("switch", object.position)
		"circuit": station.circuit_prompt.rpc_id(player.peer_id)
	_update_access()
	station.sync_state()

func toggle_circuit(index: int) -> void:
	if index < 0 or index >= 9 or circuit_ready: return
	_toggle(index)
	if circuit.count(1) == 0:
		circuit_ready = true
		station.announce.rpc("Схема C восстановлена. Шкаф с фильтром разблокирован.")
	_update_access()
	station.sound_event.rpc("switch", station.objects.circuit.position)
	station.sync_state()

func _toggle(index: int) -> void:
	var x: int = index%3
	var y: int = index/3
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var at := Vector2i(x, y)+offset
		if at.x >= 0 and at.x < 3 and at.y >= 0 and at.y < 3:
			var cell: int = at.y*3+at.x
			circuit[cell] = 1-int(circuit[cell])

func interact_purifier(player: Node3D) -> void:
	if purified: return
	if not station.objectives.generator_on or not pressure_ready:
		if player.action_cooldown <= 0:
			station.tell(player.peer_id, "Для очистки нужны питание генератора A и давление котельной B.")
			player.action_cooldown = 1.5
		return
	if not filter_loaded:
		filter_loaded = station.items.consume(player, "air_filter")
	if filter_loaded: purge_holders.append(player.peer_id)
	elif player.action_cooldown <= 0:
		station.tell(player.peer_id, "Нужен картридж из запертого шкафа C—04. Разблокируйте пульт C—01.")
		player.action_cooldown = 1.5

func tick(delta: float) -> void:
	if not purified and filter_loaded and pressure_ready and station.objectives.generator_on and not purge_holders.is_empty():
		var rate: float = 1.0
		for id: int in purge_holders:
			if station.players.get_node(str(id)).is_technician(): rate = 1.5
		purge_progress = minf(6, purge_progress+delta*rate)
		if purge_progress >= 6:
			purified = true
			_update_access()
			station.announce.rpc("Воздух очищен. Шлюз в сектор D разблокирован.")
			station.sound_event.rpc("power", station.objects.purifier.position)
	hazard_clock -= delta
	if hazard_clock <= 0:
		hazard_clock = 2
		if not purified:
			for player: Node3D in station.players.get_children():
				if is_contaminated(player.position) and player.health > 0:
					player.damage(6)
					station.tell(player.peer_id, "Загрязнённый воздух! Покиньте архив C—04 или восстановите фильтрацию.")

func is_contaminated(at: Vector3) -> bool:
	return not purified and at.x > 46 and at.x < 62 and at.z > -28 and at.z < -13

func _update_access() -> void:
	for id: String in ["door_sector_d", "filter_locker", "drain_reward"]:
		if station.objects.has(id):
			station.objects[id].locked = not is_unlocked(station.objects[id].gate_rule)
	station._update_doors_navigation()

func ready_to_transmit() -> bool:
	return pressure_ready and purified and tuned and station.drainage.drained

func task_text() -> String:
	if not pressure_ready: return "ВЫРОВНЯЙТЕ ДАВЛЕНИЕ B\nТри вентиля в котельной: %d / %d / %d.\nСхема — в диспетчерской B—04." % valves
	if not circuit_ready: return "ВОССТАНОВИТЕ ПУЛЬТ C—01\nПогасите все лампы логической схемы.\nИнструкция — в чистой комнате C—03."
	if not purified: return "ФИЛЬТРАЦИЯ C • %d%%\nКартридж — в шкафу C—04.\nВставьте в C—01 и удерживайте E." % int(purge_progress/6*100)
	if not station.drainage.drained: return station.drainage.task_text()
	if not tuned: return "ШЛЮЗ D ОТКРЫТ\nНастройте несущую в D: %d / %d / %d.\nЧастотный журнал — в чистой комнате C—03." % frequency
	return ""

func snapshot() -> Dictionary:
	return {"valves":valves, "frequency":frequency, "circuit":circuit, "pressure":pressure_ready, "circuit_ready":circuit_ready, "filter":filter_loaded, "purge":purge_progress, "purified":purified, "tuned":tuned}

func apply_snapshot(data: Dictionary) -> void:
	valves = data.valves.duplicate()
	frequency = data.frequency.duplicate()
	circuit = data.circuit.duplicate()
	pressure_ready = data.pressure
	circuit_ready = data.circuit_ready
	filter_loaded = data.filter
	purge_progress = data.purge
	purified = data.purified
	tuned = data.tuned
