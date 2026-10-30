extends Node
## Opt-in integration harness. Loaded only with --test=host/client.
var mode: String = ""
var expected: int = 2
var test_port: int = 27941
var failed: bool = false
var client_reports: Dictionary = {}
var movement_ready: bool = false

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
	# Scene creation and initial replication use different channels. Do not spend
	# the movement window while another process is still constructing its players.
	await get_tree().physics_frame
	await get_tree().physics_frame
	report.rpc_id(1,"ready")
	if not await until(func():return movement_ready):return
	check(NetworkManager.difficulty == 2 and int(world.rules.ammo) == 2,"host difficulty and hard ammunition rules replicate")
	check(player.role == NetworkManager.role_id(player.peer_id), "selected role exactly matches replicated character")
	if player.role == "hunter":
		check(player.loaded_shells == 2, "hunter starts with two replicated loaded shells")
	var start: Vector3 = player.position
	Input.action_press("forward")
	Input.action_press("sprint")
	var moved: bool=await until(func():return player.stamina<99 and player.position.distance_to(start)>.8,5)
	Input.action_release("forward")
	Input.action_release("sprint")
	if not moved:return
	await delay(0.1)
	check(player.stamina < 99,"sprint stamina is owned by host and replicated to client")
	if not check(player.position.distance_to(start) > 0.8, "client input moves authoritative body and replicates back"): return
	if player.role == "hunter":
		NetworkManager.request_player_action.rpc_id(1, NetworkManager.round_id, "shoot", 0)
		await delay(.25)
		check(player.loaded_shells == 1, "client shot consumes one of two server-owned shells")
	# A stale-round command must be rejected before reaching any character.
	NetworkManager.request_player_action.rpc_id(1, NetworkManager.round_id - 1, "flashlight", 0)
	NetworkManager.request_role.rpc_id(1, 99)
	report.rpc_id(1, "movement")
	if not await until(func(): return world.objectives.generator_on, 20.0): return
	check(world.objects.fuse.taken and world.objects.fuel.taken, "item and generator state replicated")
	check(world.last_speech_take == 5,"all participants receive the same host-selected monster phrase")
	check(world.objects.fuel_cage.position in preload("res://scripts/world/loot_spawns.gd").CONTAINERS.fuel_cage,"host-selected loot container position replicates")
	if not await until(func(): return world.objectives.emergency == "ventilation", 20.0): return
	check(world.objectives.emergency_left > 110, "two-minute emergency countdown replicates")
	if not await until(func(): return world.monster.state == world.monster.State.STUNNED): return
	await delay(.15) # Presentation follows the received replicated state on the next frame.
	check(world.monster.visible and world.monster.stunned_left > 50, "fallen monster remains visible on every peer")
	report.rpc_id(1, "emergency")
	if not await until(func(): return world.objectives.emergency.is_empty(), 12.0): return
	if not await until(func(): return world.sectors.ready_to_transmit(), 30.0): return
	check(not world.objects.door_sector_d.locked and world.sectors.circuit_ready, "all sector puzzles and bulkhead access replicate")
	check(world.drainage.drained and not world.objects.drain_reward.locked,"drainage completion and emergency supplies replicate")
	check(world.objects.archive_empty_10.opened,"empty cupboard door state replicates")
	report.rpc_id(1,"sectors")
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
	NetworkManager.choose_difficulty(2)
	NetworkManager.start_round()
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player() != null): return
	var world: Node3D = GameManager.world
	world.monster.set_physics_process(false)
	world.monster_speech.rpc(world.monster.position,5)
	var player: Node3D = GameManager.local_player()
	if not await until(func(): return client_reports.size()==expected-1 and client_reports.values().count("ready")==expected-1): return
	await get_tree().physics_frame
	await get_tree().physics_frame
	begin_movement.rpc()
	if not await until(func():return client_reports.values().count("movement")==expected-1):return
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
	place(player, Vector3(8, 0.1, 12.3), Vector3(8, 1.5, 20))
	Input.action_press("forward")
	await delay(0.65)
	Input.action_release("forward")
	check(player.position.z < 12.7, "outer wall blocks movement")
	place(player, Vector3(world.objects.fuse_safe.position.x,.05,world.objects.fuse_safe.position.z+1.7), world.objects.fuse_safe.position)
	await delay(.1)
	world.unlock_safe("fuse_safe", "000")
	check(world.objects.fuse.concealed, "wrong safe code keeps fuse inaccessible")
	world.unlock_safe("fuse_safe", world.objects.fuse_safe.code)
	await delay(.1)
	if not await pickup(player, world.objects.fuse, Vector3(world.objects.fuse_safe.position.x,.05,world.objects.fuse_safe.position.z+1.7)): return
	before = player.inventory.size()
	world.items.pickup(player, world.objects.fuse)
	check(player.inventory.size() == before, "same item cannot be picked up twice")
	place(player, Vector3(world.objects.work_locker.position.x,.05,world.objects.work_locker.position.z+1.7), world.objects.work_locker.position)
	await delay(.1)
	world.interact_object(player, world.objects.work_locker)
	await delay(.1)
	if not await pickup(player, world.objects.service_key, Vector3(world.objects.work_locker.position.x,.05,world.objects.work_locker.position.z+1.7)): return
	place(player, Vector3(world.objects.fuel_cage.position.x,.05,world.objects.fuel_cage.position.z+1.8), world.objects.fuel_cage.position)
	await delay(.1)
	world.interact_object(player, world.objects.fuel_cage)
	await delay(.1)
	if not await pickup(player, world.objects.fuel, Vector3(world.objects.fuel_cage.position.x,.05,world.objects.fuel_cage.position.z+1.8)): return
	place(player, Vector3(-10, 0.05, 2), world.objects.generator.position)
	Input.action_press("interact")
	if not await until(func(): return world.objectives.generator_on): return
	Input.action_release("interact")
	check(not "fuel" in player.inventory and not "fuse" in player.inventory, "generator consumes resources on host")
	player.inventory.erase("service_key")
	place(player, Vector3(world.objects.residence_locker.position.x,.05,world.objects.residence_locker.position.z+1.7), world.objects.residence_locker.position)
	await delay(.1)
	world.interact_object(player, world.objects.residence_locker)
	await delay(.1)
	if not await pickup(player, world.objects.key, Vector3(world.objects.residence_locker.position.x,.05,world.objects.residence_locker.position.z+1.7)): return
	place(player, Vector3(1.3, 0.05, 0), world.objects.door_9_0.position)
	await delay(0.1)
	world.interact_object(player, world.objects.door_9_0)
	check(world.objects.door_9_0.opened and not world.objects.door_9_0.locked, "key unlocks archive")
	place(player, Vector3(world.objects.archive_locker.position.x,.05,world.objects.archive_locker.position.z+1.7), world.objects.archive_locker.position)
	await delay(.1)
	world.interact_object(player, world.objects.archive_locker)
	await delay(.1)
	if not await pickup(player, world.objects.cassette, Vector3(world.objects.archive_locker.position.x,.05,world.objects.archive_locker.position.z+1.7)): return
	place(player,Vector3(10,.05,-.7),world.objects.archive_empty_10.position)
	await delay(.1)
	world.interact_object(player,world.objects.archive_empty_10)
	check(world.objects.archive_empty_10.opened,"empty archive cupboard can be inspected during a network round")
	for index: int in range(3):
		var relay: Node3D = world.objects["relay_%d" % index]
		place(player, relay.position + Vector3(0, -1.25, 1.8), relay.position)
		await delay(.1)
		for turn: int in range(world.objectives.relay_solution[index]):
			world.interact_object(player, relay)
	check(world.objectives.relay_values == world.objectives.relay_solution, "relay puzzle accepts the documented circuit")
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
	world.monster.neutralize()
	world.objectives.sabotage("ventilation")
	if not await until(func():
		for id: int in client_reports:
			if str(client_reports[id]) != "emergency": return false
		return true
	): return
	place(player, Vector3(-10, .05, -42.2), world.objects.ventilation.position)
	Input.action_press("interact")
	if not await until(func(): return world.objectives.emergency.is_empty(), 12.0): return
	Input.action_release("interact")
	check(world.objectives.emergency_left == 0, "emergency repair cancels countdown for the team")
	if not await _solve_sectors(world,player): return
	if not await until(func():
		for id: int in client_reports:
			if str(client_reports[id]) != "sectors": return false
		return true
	): return
	place(player, world.objects.transmitter.position+Vector3(0,-.75,2), world.objects.transmitter.position)
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
		member.dead = true
	GameManager.world.objectives.tick(0.1)
	check(GameManager.world.objectives.result.begins_with("Все"), "entire deceased team loses round")
	print("TEST_PASS host: %s-player LAN lifecycle" % expected)
	for id: int in NetworkManager.members:
		if id != 1: client_reports.erase(id)
	shutdown.rpc()
	if not await until(func():
		for id: int in NetworkManager.members:
			if id != 1 and str(client_reports.get(id,"")) != "shutdown": return false
		return true
	): return
	print("TEST_PASS host")
	get_tree().quit(0)

func _solve_sectors(world: Node3D, player: Node3D) -> bool:
	for i: int in range(3):
		var valve: Node3D=world.objects["valve_%d"%i]
		place(player,valve.position+Vector3(0,-1.1,1.7),valve.position)
		await delay(.07)
		for turn: int in range(world.sectors.valve_solution[i]): world.interact_object(player,valve)
	if not check(world.sectors.pressure_ready,"boiler valve puzzle completes on host"): return false
	place(player,Vector3(36,.05,-40.3),world.objects.circuit.position)
	await delay(.1)
	var moves: Array[int]=preload("res://tests/sector_check.gd").circuit_solution(world.sectors.circuit)
	for i: int in moves: world.circuit_command(NetworkManager.round_id,i)
	if not check(world.sectors.circuit_ready,"random circuit solved through validated command"): return false
	place(player,Vector3(world.objects.filter_locker.position.x,.05,world.objects.filter_locker.position.z+1.7),world.objects.filter_locker.position)
	await delay(.1)
	world.interact_object(player,world.objects.filter_locker)
	await delay(.1)
	if not await pickup(player,world.objects.air_filter,Vector3(world.objects.filter_locker.position.x,.05,world.objects.filter_locker.position.z+1.7)): return false
	place(player,Vector3(39,.05,-40.2),world.objects.purifier.position)
	Input.action_press("interact")
	if not await until(func():return world.sectors.purified,9): return false
	Input.action_release("interact")
	place(player,Vector3(0,.05,-61.2),world.objects.door_sector_d.position)
	await delay(.1)
	world.interact_object(player,world.objects.door_sector_d)
	for i: int in range(3):
		var tuner: Node3D=world.objects["tuner_%d"%i]
		place(player,tuner.position+Vector3(0,-1.2,1.7),tuner.position)
		await delay(.07)
		for turn: int in range(world.sectors.frequency_solution[i]):world.interact_object(player,tuner)
	for index: int in world.drainage.order:
		var switch: Node3D = world.objects["drain_switch_%d" % index]
		place(player,Vector3(switch.position.x,.05,switch.position.z+1.7),switch.position)
		await delay(.08)
		world.interact_object(player,switch)
	place(player,Vector3(3.5,.05,46),world.objects.drain_pump.position)
	await delay(.1)
	Input.action_press("interact")
	if not await until(func(): return world.drainage.drained,10): return false
	Input.action_release("interact")
	return check(world.sectors.ready_to_transmit(),"pressure, filtration, radio and drainage unlock final transmission")

@rpc("any_peer", "call_remote", "reliable")
func report(phase: String) -> void:
	if multiplayer.is_server():
		client_reports[multiplayer.get_remote_sender_id()] = phase

@rpc("authority","call_remote","reliable")
func begin_movement() -> void:
	movement_ready=true

@rpc("authority", "call_remote", "reliable")
func drive_power(look: Vector2) -> void:
	GameManager.local_player().local_aim = look
	Input.action_press("interact")

@rpc("authority", "call_remote", "reliable")
func leave_test() -> void:
	print("TEST_PASS client: disconnected after cooperative victory")
	NetworkManager.leave()
	get_tree().quit(0)

@rpc("authority", "call_remote", "reliable")
func shutdown() -> void:
	print("TEST_PASS " + mode)
	report.rpc_id(1,"shutdown")
	await delay(.3)
	get_tree().quit(0)
