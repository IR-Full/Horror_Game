extends Node
## Host-owned start sequence and continuous pump operation in the southern sector.
var station: Node3D
var order: Array = [0,1,2,3]
var entered: int = 0
var tripped: float = 0
var circuit_on: bool = false
var progress: float = 0
var drained: bool = false
var holders: Array[int] = []
var hazard_clock: float = 2
var water: MeshInstance3D
const BUTTONS := ["СОЛЬ", "ПЕПЕЛ", "ПЛОТЬ", "ТИШИНА"]
const ROOMS := ["E—02", "E—03", "E—05", "E—06"]

func randomize_round() -> void:
	if not multiplayer.is_server():return
	var randoms:=preload("res://scripts/core/round_random.gd")
	var previous: Array=NetworkManager.last_pump_order
	if previous.is_empty():previous=randoms.history("pump_order").get("order",[])
	order = randoms.order(4,previous)
	NetworkManager.last_pump_order = order.duplicate()
	randoms.remember("pump_order",{"order":order})
	var lines := PackedStringArray()
	for i: int in order: lines.append(BUTTONS[i]+" • "+ROOMS[i])
	station.objects.drain_note.description = "ПУСКОВАЯ ЦЕПЬ ЭТОЙ СМЕНЫ\nПитание — генератор A.\nВключить контакторы строго по порядку:\n"+" → ".join(lines)+"\nОшибка сбрасывает цепь и поднимает шум.\nЗатем удерживать пуск насоса в E—04.\nЗатопленный зал опасен при включённом питании."

func begin_frame() -> void:
	holders.clear()

func press(player: Node3D, object: Node3D) -> void:
	if circuit_on or drained: return
	if not station.objectives.generator_on:
		station.tell(player.peer_id,"Нет питания. Сначала восстановите генератор A.")
		return
	if tripped > 0:
		station.tell(player.peer_id,"Защита сработала. Подождите %d сек." % ceili(tripped))
		return
	var index: int = int(object.object_id.trim_prefix("drain_switch_"))
	if index != int(order[entered]):
		entered = 0
		tripped = 4
		station.make_noise(object.position,28)
		station.sound_event.rpc("smash",object.position)
		station.tell(player.peer_id,"Неверный порядок! Цепь сброшена. Журнал — в E—01.")
	else:
		entered += 1
		circuit_on = entered == 4
		station.sound_event.rpc("switch",object.position)
		station.tell(player.peer_id,"Пусковая цепь: %d / 4" % entered)
		if circuit_on: station.announce.rpc("Контакторы E включены. Запустите насос в E—04.")
	station.sync_state()

func interact_pump(player: Node3D) -> void:
	if drained: return
	if not circuit_on or not station.objectives.generator_on:
		if player.action_cooldown <= 0:
			station.tell(player.peer_id,"Нужны генератор A и пусковая цепь E. Порядок — в журнале E—01.")
			player.action_cooldown = 1.5
		return
	holders.append(player.peer_id)

func tick(delta: float) -> void:
	tripped = maxf(0,tripped-delta)
	if not drained:
		if circuit_on and station.objectives.generator_on and not holders.is_empty():
			var rate: float = 1
			for id: int in holders:
				var actor: Node3D = station.players.get_node_or_null(str(id))
				if actor and actor.is_technician(): rate = 1.5
			progress = minf(8,progress+delta*rate)
		else: progress = maxf(0,progress-delta*.3)
		if progress >= 8:
			drained = true
			station.sectors._update_access()
			station.refresh_containers()
			station.announce.rpc("Дренаж E восстановлен. Вода ушла, резерв связи и аварийный запас доступны.")
			station.sound_event.rpc("power",station.objects.drain_pump.position)
	hazard_clock -= delta
	if hazard_clock <= 0:
		hazard_clock = 2
		if not drained and station.objectives.generator_on:
			for actor: Node3D in station.players.get_children():
				if actor.health > 0 and in_water(actor.position):
					actor.damage(7)
					station.tell(actor.peer_id,"Вода под напряжением! Отойдите из E—04 и восстановите дренаж.")

static func in_water(at: Vector3) -> bool:
	return at.x > 4 and at.x < 23 and at.z > 40 and at.z < 52

func _process(_delta: float) -> void:
	if is_instance_valid(water):
		water.visible = not drained
		water.position.y = .075*(1-progress/8.0)+.012
	if not is_instance_valid(station): return
	for i: int in range(4):
		var object: Node3D = station.objects.get("drain_switch_%d" % i)
		if object:
			object.label.text = BUTTONS[i]+(" • ВКЛ" if circuit_on or i in order.slice(0,entered) else " • E")

func task_text() -> String:
	if not circuit_on: return "ПУСКОВАЯ ЦЕПЬ E • %d / 4\nЖурнал порядка — E—01.\nКонтакторы: E—02, E—03, E—05, E—06." % entered
	return "ОТКАЧАЙТЕ ВОДУ E • %d%%\nНасос — E—04, у входа. Удерживайте E.\nВода в машинном зале под напряжением!" % int(progress/8*100)

func snapshot() -> Dictionary:
	return {"order":order,"entered":entered,"tripped":tripped,"circuit":circuit_on,"progress":progress,"drained":drained}

func apply_snapshot(data: Dictionary) -> void:
	order = data.order.duplicate()
	entered = int(data.entered)
	tripped = float(data.tripped)
	circuit_on = bool(data.circuit)
	progress = float(data.progress)
	drained = bool(data.drained)
