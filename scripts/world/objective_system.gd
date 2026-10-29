extends Node
## Final power requires a different player from the transmitter operator.
var station: Node3D
var fuel_loaded: bool = false
var fuse_loaded: bool = false
var generator_on: bool = false
var cassette_loaded: bool = false
var repair_progress: float = 0.0
var transmit_progress: float = 0.0
var seconds_left: float = 1800.0
var result: String = ""
var power_holders: Array[int] = []
var operators: Array[int] = []
var repairers: Array[int] = []
var frame_holders: Array[int] = []
var emergency: String = ""
var emergency_left: float = 0.0
var emergency_repair: float = 0.0
var emergency_holders: Array[int] = []
var relay_values: Array = [0, 0, 0]
var relay_solution: Array = [1, 3, 2]

func begin_frame() -> void:
	station.sectors.begin_frame()
	station.drainage.begin_frame()
	power_holders.clear()
	operators.clear()
	repairers.clear()
	frame_holders.clear()
	emergency_holders.clear()

func interact(player: Node3D, object: Node3D) -> void:
	if not result.is_empty():
		return
	if object.kind == "purifier":
		station.sectors.interact_purifier(player)
		return
	if object.kind == "drain_pump":
		station.drainage.interact_pump(player)
		return
	if (object.kind == "generator" and emergency == "generator") or (object.kind == "ventilation" and emergency == "ventilation"):
		emergency_holders.append(player.peer_id)
		return
	match object.kind:
		"generator":
			if generator_on:
				return
			if not fuse_loaded and station.items.consume(player, "fuse"):
				fuse_loaded = true
			if not fuel_loaded and station.items.consume(player, "fuel"):
				fuel_loaded = true
			if fuel_loaded and fuse_loaded:
				repairers.append(player.peer_id)
			frame_holders.append(player.peer_id)
		"power":
			if generator_on:
				power_holders.append(player.peer_id)
		"transmitter":
			if not cassette_loaded and station.items.consume(player, "cassette"):
				cassette_loaded = true
			if generator_on and cassette_loaded and relay_values == relay_solution and emergency.is_empty() and station.sectors.ready_to_transmit():
				operators.append(player.peer_id)

func tick(delta: float) -> void:
	if not result.is_empty():
		return
	station.sectors.tick(delta)
	station.drainage.tick(delta)
	seconds_left = maxf(0.0, seconds_left - delta)
	var living: int = 0
	var recoverable: int = 0
	for player: Node3D in station.players.get_children():
		if player.health > 0.0:
			living += 1
		if not player.dead:
			recoverable += 1
	if station.players.get_child_count() > 0 and living == 0:
		finish("Все участники ранены. Сигнал оборвался.")
		return
	if seconds_left <= 0.0:
		finish("Время вышло. Станция замолчала.")
		return
	if not emergency.is_empty():
		emergency_left = maxf(0.0, emergency_left - delta)
		if not emergency_holders.is_empty():
			var rate: float = 1.0
			for id: int in emergency_holders:
				if station.players.get_node(str(id)).is_technician():
					rate = 1.7
			emergency_repair = minf(8.0, emergency_repair + delta * rate)
			if emergency_repair >= 8.0:
				if emergency == "generator":
					generator_on = true
				emergency = ""
				emergency_left = 0.0
				emergency_repair = 0.0
				station.announce.rpc("Авария устранена. Системы жизнеобеспечения восстановлены.")
				station.sound_event.rpc("power", station.objects.ventilation.position)
		if not emergency.is_empty() and emergency_left <= 0.0:
			finish("Команда погибла от холода: отопление остановилось." if emergency == "generator" else "Команда погибла: вентиляция остановилась, кислород исчерпан.")
			return
	if not generator_on and emergency != "generator" and not repairers.is_empty():
		var rate: float = 1.0
		for id: int in repairers:
			if station.players.get_node(str(id)).is_technician():
				rate = 1.8
		repair_progress = minf(4.0, repair_progress + delta * rate)
		if repair_progress >= 4.0:
			generator_on = true
			station.make_noise(Vector3(-10, 0, 0), 30.0)
			station.sound_event.rpc("power", Vector3(-10, 1, 0))
	var transmitting: bool = false
	for operator_id: int in operators:
		if living == 1:
			transmitting = true # Practice / last connected survivor fallback.
		for power_id: int in power_holders:
			if power_id != operator_id:
				transmitting = true
	if transmitting:
		transmit_progress = minf(12.0, transmit_progress + delta)
		if transmit_progress >= 12.0:
			finish("Победа! Спасатели приняли последний сигнал.")
	else:
		transmit_progress = maxf(0.0, transmit_progress - delta * 0.35)

func finish(message: String) -> void:
	result = message
	station.sync_state()

func sabotage(kind: String) -> bool:
	if kind not in ["generator", "ventilation"] or not multiplayer.is_server() or not emergency.is_empty() or not result.is_empty():
		return false
	if kind == "generator" and not generator_on:
		return false
	emergency = kind
	emergency_left = 120.0
	emergency_repair = 0.0
	if kind == "generator":
		generator_on = false
	station.announce.rpc("АВАРИЯ: отопление отключено! 2 минуты на ремонт генератора." if kind == "generator" else "АВАРИЯ: вентиляция разрушена! 2 минуты на ремонт в насосной, сектор 11.")
	station.sound_event.rpc("alarm", station.objects[kind].position)
	station.sync_state()
	return true

func snapshot() -> Dictionary:
	return {"fuel": fuel_loaded, "fuse": fuse_loaded, "generator": generator_on, "cassette": cassette_loaded, "repair": repair_progress, "transmit": transmit_progress, "time": seconds_left, "result": result, "emergency": emergency, "emergency_left": emergency_left, "emergency_repair": emergency_repair, "relays": relay_values, "relay_solution":relay_solution, "sectors":station.sectors.snapshot(), "drainage":station.drainage.snapshot()}

func apply_snapshot(state: Dictionary) -> void:
	fuel_loaded = bool(state.fuel)
	fuse_loaded = bool(state.fuse)
	generator_on = bool(state.generator)
	cassette_loaded = bool(state.cassette)
	repair_progress = float(state.repair)
	transmit_progress = float(state.transmit)
	seconds_left = float(state.time)
	result = str(state.result)
	emergency = str(state.emergency)
	emergency_left = float(state.emergency_left)
	emergency_repair = float(state.emergency_repair)
	relay_values = state.relays.duplicate()
	relay_solution = state.relay_solution.duplicate()
	station.sectors.apply_snapshot(state.sectors)
	station.drainage.apply_snapshot(state.drainage)

func task_text() -> String:
	if not emergency.is_empty():
		var seconds: int = ceili(emergency_left)
		return "АВАРИЯ • %02d:%02d ДО ГИБЕЛИ\n%s\nУдерживайте E для ремонта: %d%%" % [seconds / 60, seconds % 60, "Генератор / холод • сектор 03" if emergency == "generator" else "Вентиляция / кислород • сектор 11", int(emergency_repair / 8.0 * 100)]
	if not generator_on:
		return "ВОССТАНОВИТЕ ПИТАНИЕ\nПредохранитель: %s  /  Бензин: %s\nУ генератора удерживайте E: %d%%" % ["✓" if fuse_loaded else "—", "✓" if fuel_loaded else "—", int(repair_progress / 4.0 * 100)]
	if not cassette_loaded and not station.objects.cassette.taken:
		return "НАЙДИТЕ ЗАПИСЬ В АРХИВЕ A\nКлюч — в шкафчике жилого блока A—05.\nЗатем откройте секторы B, C и D."
	if relay_values != relay_solution:
		return "НАСТРОЙТЕ РЕЛЕ • СЕКТОР 09\nA: %d / B: %d / C: %d\nСхема настройки — в лаборатории, сектор 10." % relay_values
	if not station.sectors.ready_to_transmit(): return station.sectors.task_text()
	if not cassette_loaded: return "ДОСТАВЬТЕ КАССЕТУ В СЕКТОР D\nУ передатчика удерживайте E.\nЗапись берётся в архиве A—04."
	return "ПЕРЕДАЙТЕ СИГНАЛ  •  %d%%\nЩит питания — радиорубка A—06.\nПередатчик — узел связи D." % int(transmit_progress / 12.0 * 100)
