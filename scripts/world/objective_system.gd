extends Node
## Final power requires a different player from the transmitter operator.
var station: Node3D
var fuel_loaded: bool = false
var fuse_loaded: bool = false
var generator_on: bool = false
var cassette_loaded: bool = false
var repair_progress: float = 0.0
var transmit_progress: float = 0.0
var seconds_left: float = 900.0
var result: String = ""
var power_holders: Array[int] = []
var operators: Array[int] = []
var repairers: Array[int] = []
var frame_holders: Array[int] = []

func begin_frame() -> void:
	power_holders.clear()
	operators.clear()
	repairers.clear()
	frame_holders.clear()

func interact(player: Node3D, object: Node3D) -> void:
	if not result.is_empty():
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
			if generator_on and cassette_loaded:
				operators.append(player.peer_id)

func tick(delta: float) -> void:
	if not result.is_empty():
		return
	seconds_left = maxf(0.0, seconds_left - delta)
	var living: int = 0
	for player: Node3D in station.players.get_children():
		if player.health > 0.0:
			living += 1
	if station.players.get_child_count() > 0 and living == 0:
		finish("Все техники потеряны. Сигнал оборвался.")
		return
	if seconds_left <= 0.0:
		finish("Время вышло. Станция замолчала.")
		return
	if not generator_on and not repairers.is_empty():
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

func snapshot() -> Dictionary:
	return {"fuel": fuel_loaded, "fuse": fuse_loaded, "generator": generator_on, "cassette": cassette_loaded, "repair": repair_progress, "transmit": transmit_progress, "time": seconds_left, "result": result}

func apply_snapshot(state: Dictionary) -> void:
	fuel_loaded = bool(state.fuel)
	fuse_loaded = bool(state.fuse)
	generator_on = bool(state.generator)
	cassette_loaded = bool(state.cassette)
	repair_progress = float(state.repair)
	transmit_progress = float(state.transmit)
	seconds_left = float(state.time)
	result = str(state.result)

func task_text() -> String:
	if not generator_on:
		return "ВОССТАНОВИТЕ ПИТАНИЕ\nПредохранитель: %s  /  Бензин: %s\nУ генератора удерживайте E: %d%%" % ["✓" if fuse_loaded else "—", "✓" if fuel_loaded else "—", int(repair_progress / 4.0 * 100)]
	if not cassette_loaded:
		return "НАЙДИТЕ ЗАПИСЬ\nКлюч — в жилой комнате. Кассета — в архиве.\nВставьте кассету в передатчик: E."
	return "ПЕРЕДАЙТЕ СИГНАЛ  •  %d%%\nОдин удерживает E у щита питания.\nВторой удерживает E у передатчика." % int(transmit_progress / 12.0 * 100)
