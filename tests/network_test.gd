extends Node
## Opt-in integration harness. Loaded only with --test=host/client.
var mode: String = ""
var expected: int = 2
var test_port: int = 27941
var failed: bool = false
var client_reports: Dictionary = {}

func _ready() -> void:
	name = "TestRunner"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--test="): mode = arg.get_slice("=", 1)
		if arg.begins_with("--players="): expected = int(arg.get_slice("=", 1))
		if arg.begins_with("--port="): test_port = int(arg.get_slice("=", 1))
	_run.call_deferred()

func check(condition: bool, message: String) -> bool:
	if not condition:
		failed = true
		push_error("TEST_FAIL " + mode + ": " + message)
		get_tree().quit(1)
		return false
	print("CHECK " + mode + ": " + message)
	return true

func until(predicate: Callable, timeout: float = 10.0) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout * 1000)
	while not predicate.call():
		if failed: return false
		if Time.get_ticks_msec() >= deadline:
			check(false, "timeout waiting for condition")
			return false
		await get_tree().process_frame
	return true

func delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _run() -> void:
	if mode == "host":
		await _host()
	else:
		await _client()

func _client() -> void:
	if not check(NetworkManager.join_room("127.0.0.1", "Client", test_port) == OK, "ENet client created"): return
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player() != null): return
	var world: Node3D = GameManager.world
	var player: Node3D = GameManager.local_player()
	if not await until(func(): return world.players.get_child_count() == expected): return
	check(player.role != "", "role replicated in spawn data")
	var start: Vector3 = player.position
	Input.action_press("forward")
	await delay(0.85)
	Input.action_release("forward")
	await delay(0.25)
	if not check(player.position.distance_to(start) > 0.8, "client input moves authoritative body and replicates back"): return
	# A stale-round command must be rejected before reaching any character.
	NetworkManager.request_player_action.rpc_id(1, NetworkManager.round_id - 1, "flashlight", 0)
	NetworkManager.request_role.rpc_id(1, 99)
	report.rpc_id(1, "movement")
	if not await until(func(): return world.objectives.generator_on, 20.0): return
	check(world.objects.fuse.taken and world.objects.fuel.taken, "item and generator state replicated")
	if not await until(func(): return not world.objectives.result.is_empty(), 25.0): return
	if not check(world.objectives.result.begins_with("Победа"), "cooperative win replicated"): return
	report.rpc_id(1, "victory")

func place(player: Node3D, position: Vector3, target: Vector3) -> void:
	player.position = position
	player.net_position = position
	player.velocity = Vector3.ZERO
	var direction: Vector3 = (target - player.eye_position()).normalized()
	player.local_aim = Vector2(atan2(-direction.x, -direction.z), asin(direction.y))
	player.aim = player.local_aim

func pickup(player: Node3D, object: Node3D, position: Vector3) -> bool:
	place(player, position, object.position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not check(GameManager.world.target_for(player) == object, "ray reaches " + object.object_id): return false
	GameManager.world.interact_object(player, object)
	return check(object.taken and object.kind in player.inventory, "pickup " + object.object_id)

func _host() -> void:
	if not check(NetworkManager.host_room("Host", test_port) == OK, "ENet host created"): return
	if not await until(func(): return NetworkManager.members.size() == expected, 20.0): return
	check(NetworkManager.members.size() <= 4, "room capacity respected")
	var previous: int = NetworkManager.members[1].role
	NetworkManager.choose_role(99)
	check(int(NetworkManager.members[1].role) == previous, "invalid lobby role rejected")
	NetworkManager.start_round()
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player() != null): return
	var world: Node3D = GameManager.world
	world.monster.set_physics_process(false)
	var player: Node3D = GameManager.local_player()
	if not await until(func(): return client_reports.size() == expected - 1): return
	check(world.players.get_child_count() == expected, "MultiplayerSpawner created every player")
	check(player.lamp_on, "client cannot change another player's flashlight")
	var before: int = player.inventory.size()
	world.interact_object(player, world.objects.fuse)
	check(player.inventory.size() == before, "distant pickup rejected")
	var origin: Vector3 = player.position
	player.accept_input(Vector2(900, -900), Vector2.ZERO, true, false, false)
	check(player.move_input.length() <= 1.001, "oversized movement input clamped")
	player.accept_input(Vector2(NAN, 0), Vector2.ZERO, false, false, false)
	check(player.move_input.is_finite(), "NaN input rejected")
	# Let ordinary host polling replace the synthetic input.
	await delay(0.1)
	check(player.position.distance_to(origin) < 1.0, "input cannot teleport body")
	# Server-side movement meets station collision, not client-reported positions.
	place(player, Vector3(0, 0.1, 12.3), Vector3(0, 1.5, 20))
	Input.action_press("forward")
	await delay(0.65)
	Input.action_release("forward")
	check(player.position.z < 12.7, "outer wall blocks movement")
	if not await pickup(player, world.objects.fuse, Vector3(-7, 0.05, 8.5)): return
	before = player.inventory.size()
	world.items.pickup(player, world.objects.fuse)
	check(player.inventory.size() == before, "same item cannot be picked up twice")
	if not await pickup(player, world.objects.fuel, Vector3(-12, 0.05, 8.5)): return
	place(player, Vector3(-10, 0.05, 2), world.objects.generator.position)
	Input.action_press("interact")
	if not await until(func(): return world.objectives.generator_on): return
	Input.action_release("interact")
	check(not "fuel" in player.inventory and not "fuse" in player.inventory, "generator consumes resources on host")
	if not await pickup(player, world.objects.key, Vector3(-11, 0.05, -8.8)): return
	place(player, Vector3(1.3, 0.05, 0), world.objects.door_9_0.position)
	await delay(0.1)
	world.interact_object(player, world.objects.door_9_0)
	check(world.objects.door_9_0.opened and not world.objects.door_9_0.locked, "key unlocks archive")
	if not await pickup(player, world.objects.cassette, Vector3(10, 0.05, 3.2)): return
	# Perception unit checks run against real station collisions.
	world.monster.position = Vector3(0, 0.05, -7)
	world.monster.state = world.monster.State.PATROL
	world.monster.hear_noise(Vector3(0, 0, -3), 10.0)
	check(world.monster.state == world.monster.State.INVESTIGATE, "entity hears noise")
	place(player, Vector3(0, 0.05, -3), Vector3(0, 1.5, -7))
	player.lamp_on = false
	world.monster._perceive()
	check(world.monster.state == world.monster.State.CHASE, "entity sees and pursues a player")
	player.lamp_on = true
	world.monster._perceive()
	check(world.monster.state == world.monster.State.RETREAT, "direct flashlight repels entity")
	player.health = 0.0
	player.revive()
	check(player.health == 45.0, "downed teammate can be revived")
	player.battery = 10.0
	player.inventory.append("battery")
	world.items.use(player, player.inventory.size() - 1)
	check(player.battery == 75.0, "battery item restores flashlight")
	place(player, Vector3(10, 0.05, -6), world.objects.transmitter.position)
	Input.action_press("interact")
	await delay(1.0)
	check(world.objectives.cassette_loaded and world.objectives.transmit_progress == 0.0, "operator alone cannot transmit in a team")
	var client_id: int = int(client_reports.keys()[0])
	var client: Node3D = world.players.get_node(str(client_id))
	client.position = Vector3(5.5, 0.05, -8.9)
	client.net_position = client.position
	client.velocity = Vector3.ZERO
	var dir: Vector3 = (world.objects.power.position - client.eye_position()).normalized()
	drive_power.rpc_id(client_id, Vector2(atan2(-dir.x, -dir.z), asin(dir.y)))
	if not await until(func(): return not world.objectives.result.is_empty(), 18.0): return
	Input.action_release("interact")
	check(world.objectives.result.begins_with("Победа"), "two distinct players complete transmitter objective")
	if not await until(func():
		for id: int in client_reports:
			if str(client_reports[id]) != "victory": return false
		return true
	): return
	client.inventory.append("battery")
	var drops_before: int = world.items.next_drop
	leave_test.rpc_id(client_id)
	if not await until(func(): return NetworkManager.members.size() == expected - 1): return
	await delay(0.4)
	check(world.players.get_child_count() == expected - 1, "disconnect despawns character")
	check(world.items.next_drop > drops_before, "disconnect returns carried items to world")
	NetworkManager.return_to_lobby()
	if not await until(func(): return not NetworkManager.unloading): return
	await delay(0.3)
	NetworkManager.start_round(expected == 2)
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player() != null): return
	check(not GameManager.world.objectives.generator_on, "rematch resets objectives")
	check(GameManager.world.players.get_child_count() == expected - 1, "rematch respawns remaining players")
	GameManager.world.objectives.seconds_left = 0.01
	GameManager.world.objectives.tick(0.1)
	check(GameManager.world.objectives.result.begins_with("Время"), "time limit ends round in defeat")
	NetworkManager.return_to_lobby()
	if not await until(func(): return not NetworkManager.unloading): return
	await delay(0.2)
	NetworkManager.start_round(expected == 2)
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player() != null): return
	for member: Node3D in GameManager.world.players.get_children():
		member.health = 0.0
	GameManager.world.objectives.tick(0.1)
	check(GameManager.world.objectives.result.begins_with("Все"), "entire downed team loses round")
	print("TEST_PASS host: %s-player LAN lifecycle" % expected)
	shutdown.rpc()

@rpc("any_peer", "call_remote", "reliable")
func report(phase: String) -> void:
	if multiplayer.is_server():
		client_reports[multiplayer.get_remote_sender_id()] = phase

@rpc("authority", "call_remote", "reliable")
func drive_power(look: Vector2) -> void:
	GameManager.local_player().local_aim = look
	Input.action_press("interact")

@rpc("authority", "call_remote", "reliable")
func leave_test() -> void:
	print("TEST_PASS client: disconnected after cooperative victory")
	NetworkManager.leave()
	get_tree().quit(0)

@rpc("authority", "call_local", "reliable")
func shutdown() -> void:
	print("TEST_PASS " + mode)
	get_tree().quit(0)
