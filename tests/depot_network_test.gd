extends "res://tests/depot_check.gd"
var mode: String = ""
var expected: int = 2
var test_port: int = 27973
var reports: Dictionary = {}
var finished: bool = false

func until(predicate: Callable,seconds: float = 20) -> bool:
	var deadline: int = Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call():
		if failures > 0 or Time.get_ticks_msec() > deadline:
			check(false,"network timeout in "+mode+" reports="+str(reports))
			get_tree().quit(1)
			return false
		await get_tree().process_frame
	return true
func everyone(phase: String) -> bool:
	for id: int in NetworkManager.members:
		if id != 1 and reports.get(id,"") != phase: return false
	return reports.size() == expected-1

func _run() -> void:
	name = "DepotNetworkRunner"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--depot-test="): mode = argument.get_slice("=",1)
		if argument.begins_with("--players="): expected = int(argument.get_slice("=",1))
		if argument.begins_with("--port="): test_port = int(argument.get_slice("=",1))
	NetworkManager.left_room.connect(func():
		if finished: get_tree().quit(0)
	)
	if mode == "client": await client_run()
	else: await host_run()

func client_run() -> void:
	check(NetworkManager.join_room("127.0.0.1","Depot client",test_port) == OK,"depot client connects")
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player() != null): return
	world = GameManager.world; actor = GameManager.local_player(); actor.input_enabled = false
	check(NetworkManager.map_id == 1 and world.map_id == 1 and world.objects.has("escape_car"),"host map choice is applied before client world construction")
	NetworkManager.choose_map(0)
	check(NetworkManager.map_id == 1,"client cannot change the active map")
	if not await until(func(): return actor.stress > 75 and actor.stamina < 45): return
	check(actor.motion.skeleton != null,"rigged player and condition state exist on client")
	report.rpc_id(1,"condition")
	if not await until(func(): return actor.stress < 60 and actor.calm_cooldown > 0): return
	check(not "sedative" in actor.inventory,"server calming item consumption replicates")
	report.rpc_id(1,"calm")
	if not await until(func(): return world.objectives.installed.size() == 6,40): return
	check(world.objectives.circuit_ready and world.objects.parts_safe.opened,"car parts, safe and wiring puzzle replicate")
	check(world.objects.car_battery.taken and world.objects.drive_belt.taken,"stored vehicle parts are removed on every peer")
	check(world.objects.battery_cage.position in preload("res://scripts/world/depot_loot.gd").CONTAINERS.battery_cage,"randomized depot storage locations agree with host")
	report.rpc_id(1,"assembled")
	if not await until(func(): return actor.in_vehicle): return
	await get_tree().create_timer(.15).timeout
	check(actor.body_collision.disabled,"boarded clients stop colliding with the moving car")
	if not await until(func(): return world.objectives.result.begins_with("Победа"),10): return
	check(world.objects.escape_car.position.z > 40 and actor.position.distance_to(world.objects.escape_car.position) < 3,"car departure and passenger motion replicate")
	report.rpc_id(1,"victory")
	if not await until(func(): return not NetworkManager.in_match and not NetworkManager.unloading): return
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player() != null): return
	check(NetworkManager.map_id == 0 and GameManager.world.objects.has("transmitter") and not GameManager.world.objects.has("escape_car"),"return to lobby and switch back to the station work on clients")
	report.rpc_id(1,"station")

func host_run() -> void:
	check(NetworkManager.host_room("Depot host",test_port) == OK,"depot host connects")
	NetworkManager.choose_map(1)
	if not await until(func(): return NetworkManager.members.size() == expected): return
	NetworkManager.start_round()
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player() != null): return
	world = GameManager.world; actor = GameManager.local_player(); actor.input_enabled = false
	world.monster.set_physics_process(false)
	for player: Node3D in world.players.get_children():
		if player.peer_id != 1: player.stress = 82; player.stamina = 10
	if not await until(func(): return everyone("condition")): return
	for player: Node3D in world.players.get_children():
		if player.peer_id == 1: continue
		player.inventory.append("sedative"); player.calm_cooldown = 0
		world.items.use(player,player.inventory.size()-1)
	if not await until(func(): return everyone("calm")): return
	await collect_and_assemble()
	if failures > 0: get_tree().quit(1); return
	if not await until(func(): return everyone("assembled")): return
	place(Vector3(-2,.05,23),world.objects.escape_car.position); await frames()
	actor.input_enabled = true; Input.action_press("interact")
	await get_tree().create_timer(1.2).timeout
	Input.action_release("interact"); actor.input_enabled = false
	check(world.objectives.starter_progress == 0 and not actor.in_vehicle,"escape cannot abandon living teammates across the map")
	var index: int = 0
	for player: Node3D in world.players.get_children():
		if player.peer_id == 1: continue
		player.position = Vector3(-1.5+index,.05,20); player.net_position = player.position
		index += 1
	await get_tree().create_timer(.2).timeout
	actor.input_enabled = true; Input.action_press("interact")
	if not await until(func(): return world.objectives.result.begins_with("Победа"),12): return
	Input.action_release("interact"); actor.input_enabled = false
	if not await until(func(): return everyone("victory")): return
	NetworkManager.return_to_lobby()
	if not await until(func(): return not NetworkManager.in_match and not NetworkManager.unloading): return
	NetworkManager.choose_map(0)
	NetworkManager.start_round()
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player() != null): return
	GameManager.world.monster.set_physics_process(false)
	if not await until(func(): return everyone("station")): return
	finish.rpc()
	await get_tree().create_timer(.5).timeout
	NetworkManager.leave(false)
	await get_tree().create_timer(.2).timeout
	print("TEST_PASS depot host: %d-player escape, stress and map switching" % expected)
	get_tree().quit(0)

@rpc("any_peer","call_remote","reliable")
func report(phase: String) -> void:
	if multiplayer.is_server(): reports[multiplayer.get_remote_sender_id()] = phase

@rpc("authority","call_remote","reliable")
func finish() -> void:
	finished = true
	print("TEST_PASS depot client: escape and map switching")
