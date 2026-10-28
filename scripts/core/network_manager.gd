extends Node
## ENet is isolated here, so a future transport can preserve gameplay code.
signal lobby_changed
signal error_message(message: String)
signal prepare_world
signal match_started
signal left_room

const DEFAULT_PORT := 27840
const MAX_PLAYERS := 4
const PROTOCOL := 7
const RULES := preload("res://scripts/core/round_rules.gd")
var difficulty: int = 1
var last_puzzles: Dictionary = {}
const ROLES := ["technician", "medic", "hunter"]
const ROLE_LABELS := ["Техник", "Медик", "Охотник"]
var members: Dictionary = {}
var active: bool = false
var in_match: bool = false
var loading: bool = false
var local_name: String = "Техник"
var port: int = DEFAULT_PORT
var ready_peers: Dictionary = {}
var load_deadline: float = 0.0
var connect_deadline: float = 0.0
var unloading: bool = false
var unload_acks: Dictionary = {}
var unload_notice: String = ""
var unload_sent: bool = false
var round_id: int = 0
var last_shell_positions: Array = []

func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)

func _process(delta: float) -> void:
	if unloading and not unload_sent:
		if not is_instance_valid(GameManager.world) or GameManager.world.players.get_child_count() == 0:
			unload_sent = true
			if multiplayer.is_server():
				_mark_unloaded(1)
			else:
				client_unloaded.rpc_id(1)
	if connect_deadline > 0.0:
		connect_deadline -= delta
		if connect_deadline <= 0.0:
			_connection_failed()
	if loading and multiplayer.is_server():
		load_deadline -= delta
		if load_deadline <= 0.0:
			abort_round("Игрок не загрузил карту за 20 секунд. Попробуйте ещё раз.")

func host_room(nickname: String, chosen_port: int = DEFAULT_PORT) -> Error:
	leave(false)
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(chosen_port, MAX_PLAYERS - 1)
	if result != OK:
		error_message.emit("Не удалось открыть UDP-порт %s (код %s)." % [chosen_port, result])
		return result
	multiplayer.multiplayer_peer = peer
	active = true
	port = chosen_port
	local_name = clean_name(nickname)
	members = {1: {"name": local_name, "role": 0}}
	lobby_changed.emit()
	return OK

func join_room(address: String, nickname: String, chosen_port: int = DEFAULT_PORT) -> Error:
	leave(false)
	var ip := address.strip_edges()
	if not ip.is_valid_ip_address():
		error_message.emit("Введите локальный IP, например 192.168.1.10.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(ip, chosen_port)
	if result != OK:
		error_message.emit("Не удалось начать подключение (код %s)." % result)
		return result
	local_name = clean_name(nickname)
	port = chosen_port
	multiplayer.multiplayer_peer = peer
	active = true
	connect_deadline = 10.0
	lobby_changed.emit()
	return OK

func clean_name(value: String) -> String:
	return value.strip_edges().replace("\n", " ").replace("\r", " ").left(20) if not value.strip_edges().is_empty() else "Техник"

func leave(announce: bool = true) -> void:
	active = false
	in_match = false
	loading = false
	unloading = false
	connect_deadline = 0.0
	members.clear()
	ready_peers.clear()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if announce:
		left_room.emit()

func _peer_connected(_id: int) -> void:
	pass # Registration, rather than this signal, admits a player to the roster.

func _connected() -> void:
	connect_deadline = 0.0
	register_player.rpc_id(1, local_name, PROTOCOL)

@rpc("any_peer", "call_remote", "reliable")
func register_player(nickname: String, protocol: int) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL or in_match or loading or unloading or members.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	if members.has(sender):
		return
	var taken: Array = []
	for entry: Dictionary in members.values():
		taken.append(int(entry.role))
	var role: int = 0
	while role in taken and role < 2:
		role += 1
	if role in taken:
		role = 0
	members[sender] = {"name": clean_name(nickname), "role": role}
	_sync_lobby.rpc(members, difficulty)

func choose_role(role: int) -> void:
	if multiplayer.is_server():
		_set_role(1, role)
	else:
		request_role.rpc_id(1, role)

@rpc("any_peer", "call_remote", "reliable")
func request_role(role: int) -> void:
	if multiplayer.is_server():
		_set_role(multiplayer.get_remote_sender_id(), role)

func _set_role(id: int, role: int) -> void:
	if in_match or loading or unloading or not members.has(id):
		return
	var count: int = 3
	if role < 0 or role >= count:
		return
	members[id].role = role
	_sync_lobby.rpc(members, difficulty)

func choose_difficulty(level: int) -> void:
	if not multiplayer.is_server() or in_match or loading or unloading or level < 0 or level > 3: return
	difficulty = level
	_sync_lobby.rpc(members, difficulty)

@rpc("authority", "call_local", "reliable")
func _sync_lobby(roster: Dictionary, level: int) -> void:
	members = roster.duplicate(true)
	difficulty = clampi(level, 0, 3)
	lobby_changed.emit()

func role_id(peer_id: int) -> String:
	var index: int = int(members[peer_id].role)
	return ROLES[clampi(index, 0, 2)]

func start_round(practice: bool = false) -> void:
	if not multiplayer.is_server() or not active or loading or unloading or in_match:
		return
	if members.size() < 2 and not practice:
		return
	ready_peers.clear()
	_prepare_round.rpc(round_id + 1)

@rpc("authority", "call_local", "reliable")
func _prepare_round(number: int) -> void:
	round_id = number
	loading = true
	load_deadline = 20.0
	prepare_world.emit()

func world_ready() -> void:
	if multiplayer.is_server():
		_mark_ready(1)
	else:
		client_world_ready.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func client_world_ready() -> void:
	if multiplayer.is_server():
		_mark_ready(multiplayer.get_remote_sender_id())

func _mark_ready(id: int) -> void:
	if not loading or not members.has(id):
		return
	ready_peers[id] = true
	if ready_peers.size() == members.size():
		# All peers now have the exact same World/Players/Spawner paths.
		_begin_round.rpc()
		GameManager.world.spawn_players()

@rpc("authority", "call_local", "reliable")
func _begin_round() -> void:
	loading = false
	in_match = true
	match_started.emit()

func return_to_lobby() -> void:
	if multiplayer.is_server() and active:
		abort_round("")

func abort_round(message: String) -> void:
	if not multiplayer.is_server() or unloading:
		return
	unload_acks.clear()
	_freeze_round.rpc(message)
	if is_instance_valid(GameManager.world):
		for player: Node in GameManager.world.players.get_children():
			player.queue_free()

@rpc("authority", "call_local", "reliable")
func _freeze_round(message: String) -> void:
	loading = false
	in_match = false
	unloading = true
	unload_sent = false
	unload_notice = message
	if is_instance_valid(GameManager.world):
		GameManager.world.monster.get_node("StateSync").public_visibility = false

@rpc("any_peer", "call_remote", "reliable")
func client_unloaded() -> void:
	if multiplayer.is_server():
		_mark_unloaded(multiplayer.get_remote_sender_id())

func _mark_unloaded(id: int) -> void:
	if not unloading or not members.has(id):
		return
	unload_acks[id] = true
	if unload_acks.size() == members.size():
		_finish_lobby.rpc()

@rpc("authority", "call_local", "reliable")
func _finish_lobby() -> void:
	unloading = false
	ready_peers.clear()
	left_room.emit() # UI removes the old world but retains this connected session.
	lobby_changed.emit()
	if not unload_notice.is_empty():
		error_message.emit(unload_notice)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_player_input(number: int, direction: Vector2, look: Vector2, run: bool, duck: bool, use: bool) -> void:
	if not multiplayer.is_server() or not in_match or number != round_id:
		return
	var player: Node3D = GameManager.world.players.get_node_or_null(str(multiplayer.get_remote_sender_id()))
	if player:
		player.accept_input(direction, look, run, duck, use)

@rpc("any_peer", "call_remote", "reliable")
func request_player_action(number: int, action: String, slot: int) -> void:
	if not multiplayer.is_server() or not in_match or number != round_id:
		return
	var player: Node3D = GameManager.world.players.get_node_or_null(str(multiplayer.get_remote_sender_id()))
	if player:
		player.apply_action(action, slot)

func _peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not members.has(id):
		return
	if in_match and is_instance_valid(GameManager.world):
		GameManager.world.remove_player(id)
	members.erase(id)
	_sync_lobby.rpc(members, difficulty)
	if loading:
		abort_round("Загрузка отменена: игрок отключился.")
	if unloading:
		unload_acks.erase(id)
		_mark_unloaded(1)

func _connection_failed() -> void:
	leave()
	error_message.emit("Не удалось подключиться. Проверьте IP, порт и частную сеть в брандмауэре.")

func _server_disconnected() -> void:
	leave()
	error_message.emit("Хост закрыл комнату или связь прервалась. Возврат в меню.")
