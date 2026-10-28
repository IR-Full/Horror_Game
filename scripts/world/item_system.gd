extends Node
## Inventory mutations and pickups are called on the host only.
const NAMES := {"fuse": "Предохранитель", "fuel": "Бензин", "key": "Ключ архива", "cassette": "Кассета", "battery": "Батарейка", "medkit": "Аптечка"}
var station: Node3D
var next_drop: int = 0

func pickup(player: Node3D, object: Node3D) -> bool:
	if not multiplayer.is_server() or object.taken or not NAMES.has(object.kind):
		return false
	if player.inventory.size() >= player.capacity():
		station.tell(player.peer_id, "Инвентарь заполнен. Q — выбрать предмет, G — положить.")
		return false
	if player.is_medic() and object.kind == "fuel" and station.living_player_count() > 1:
		station.tell(player.peer_id, "Тяжёлую канистру должен нести напарник.")
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
		"medkit":
			player.health = minf(100.0, player.health + (70.0 if player.is_medic() else 45.0))
			player.inventory.remove_at(slot)
		_:
			station.tell(player.peer_id, "Этот предмет используют через E у нужного устройства.")
