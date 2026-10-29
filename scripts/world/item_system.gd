extends Node
## Inventory mutations and pickups are called on the host only.
const NAMES := {"fuse": "Предохранитель", "fuel": "Бензин", "key": "Ключ архива", "service_key": "Служебный ключ", "cassette": "Кассета", "battery": "Батарейка", "medkit": "Аптечка", "shell": "Патрон 12 калибра", "air_filter":"Воздушный фильтр", "car_battery":"Аккумулятор машины", "spark_plugs":"Свечи зажигания", "drive_belt":"Ремень привода", "wheel":"Запасное колесо", "car_key":"Ключ зажигания", "yard_key":"Ключ топливной клетки", "sedative":"Успокоительное", "thermos":"Термос с чаем"}
var station: Node3D
var next_drop: int = 0

func pickup(player: Node3D, object: Node3D) -> bool:
	if not multiplayer.is_server() or object.taken or object.concealed or not NAMES.has(object.kind):
		return false
	if object.kind == "shell":
		if player.role != "hunter":
			station.tell(player.peer_id, "Патроны может забрать охотник.")
			return false
		player.reserve_shells += 1
		object.taken = true
		object.refresh()
		station.sound_event.rpc("pickup", object.position)
		station.sync_state()
		return true
	if player.inventory.size() >= player.capacity():
		station.tell(player.peer_id, "Инвентарь заполнен. Q — выбрать предмет, G — положить.")
		return false
	player.inventory.append(object.kind)
	object.taken = true
	object.refresh()
	station.sound_event.rpc("pickup", object.position)
	station.sync_state()
	return true

func consume(player: Node3D, kind: String) -> bool:
	var index: int = player.inventory.find(kind)
	if index < 0:
		return false
	player.inventory.remove_at(index)
	return true

func drop(player: Node3D, slot: int) -> void:
	if slot < 0 or slot >= player.inventory.size():
		return
	var kind: String = player.inventory[slot]
	player.inventory.remove_at(slot)
	# Drop at feet: never through a wall or outside the playable station.
	spawn_drop(kind, player.position + Vector3(0.0, 0.25, 0.0))
	station.make_noise(player.position, 7.0)
	station.sync_state()

func spawn_drop(kind: String, position: Vector3) -> void:
	var id := "drop_%s" % next_drop
	next_drop += 1
	station.create_drop.rpc(id, kind, position)

func drop_all(player: Node3D) -> void:
	for kind: String in player.inventory:
		spawn_drop(kind, player.position + Vector3(0.0, 0.25, 0.0))
	player.inventory.clear()
	station.sync_state()

func use(player: Node3D, slot: int) -> void:
	if slot < 0 or slot >= player.inventory.size():
		return
	match player.inventory[slot]:
		"battery":
			player.battery = minf(100.0, player.battery + 65.0)
			player.inventory.remove_at(slot)
		"sedative", "thermos":
			if player.calm_cooldown > 0:
				station.tell(player.peer_id,"Подождите %d сек. перед повторным применением." % ceili(player.calm_cooldown))
				return
			var tea: bool = player.inventory[slot] == "thermos"
			player.stress = maxf(0,player.stress-(20.0 if tea else 35.0))
			if tea: player.stamina = minf(100,player.stamina+20)
			player.calm_cooldown = 20
			player.inventory.remove_at(slot)
		"medkit":
			player.health = minf(100.0, player.health + (70.0 if player.is_medic() else 45.0))
			player.stress = maxf(0,player.stress-8)
			player.inventory.remove_at(slot)
		_:
			station.tell(player.peer_id, "Этот предмет используют через E у нужного устройства.")
