extends "res://tests/mine_check.gd"
var mode: String=""
var expected: int=2
var test_port: int=28013
var reports: Dictionary={}
var finished: bool=false
func until(predicate: Callable,seconds: float=20) -> bool:
	var deadline: int=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call():
		if failures>0 or Time.get_ticks_msec()>deadline:
			check(false,"network timeout "+mode+" reports="+str(reports));get_tree().quit(1);return false
		await get_tree().process_frame
	return true
func everyone(phase: String) -> bool:
	for id: int in NetworkManager.members:
		if id!=1 and reports.get(id,"")!=phase:return false
	return reports.size()==expected-1
func _run() -> void:
	name="MineNetworkRunner"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mine-test="):mode=argument.get_slice("=",1)
		if argument.begins_with("--players="):expected=int(argument.get_slice("=",1))
		if argument.begins_with("--port="):test_port=int(argument.get_slice("=",1))
	NetworkManager.left_room.connect(func():
		if finished:get_tree().quit(0)
	)
	if mode=="client":await client_run()
	else:await host_run()
func client_run() -> void:
	check(NetworkManager.join_room("127.0.0.1","Forest client",test_port)==OK,"client connects")
	if not await until(func():return NetworkManager.in_match and GameManager.local_player()!=null and GameManager.world.clues_ready):return
	world=GameManager.world;actor=GameManager.local_player();actor.input_enabled=false
	check(world.map_id==4 and world.objects.has("rail_cart"),"forest selected before client scene construction")
	NetworkManager.choose_map(0);check(NetworkManager.map_id==4,"client cannot replace selected forest map")
	report.rpc_id(1,"ready")
	if not await until(func():return world.objectives.installed.size()==2 and world.objectives.fueled and world.objectives.signals_ready and world.objects.forest_ignition.taken and world.objectives.emergency.is_empty(),55):return
	check(world.objectives.winch_ready and world.objectives.pump_ready and world.objects.rail_logs.position.x>8,"forest branches and moved rail obstruction replicate")
	check(world.objects.forest_fuse.taken and world.objects.forest_belt.taken and world.objects.forest_ignition.taken,"actual consumed forest pickups replicate")
	var helper: Node=preload("res://tests/random_check.gd").new();check(helper.valid_clues(world),"client journals match randomized forest solutions");helper.free()
	report.rpc_id(1,"assembled")
	if not await until(func():return world.objectives.escape_time>=0):return
	if not await until(func():return actor.in_vehicle):return
	check(world.objects.exit_gate.opened,"physical railway gate opens on client")
	if not await until(func():return world.objectives.result.begins_with("Победа")):return
	check(actor.position.y>10 and actor.in_vehicle,"passengers actually travel with the railcart")
	report.rpc_id(1,"victory")
	if not await until(func():return not NetworkManager.in_match and not NetworkManager.unloading):return
	if not await until(func():return NetworkManager.in_match and GameManager.local_player()!=null):return
	check(GameManager.world.map_id==0,"original map works after forest round")
	report.rpc_id(1,"station")
func host_run() -> void:
	check(NetworkManager.host_room("Forest host",test_port)==OK,"host connects")
	NetworkManager.choose_map(4);NetworkManager.choose_difficulty(3)
	if not await until(func():return NetworkManager.members.size()==expected):return
	NetworkManager.start_round()
	if not await until(func():return NetworkManager.in_match and GameManager.local_player()!=null):return
	world=GameManager.world;actor=GameManager.local_player();actor.input_enabled=false;world.monster.set_physics_process(false)
	if not await until(func():return everyone("ready")):return
	await solve_forest()
	if failures>0:get_tree().quit(1);return
	if not await until(func():return everyone("assembled")):return
	await hold("rail_cart",.6);check(world.objectives.escape_time<0 and world.objectives.exit_progress==0,"departure cannot abandon teammates")
	var index: int=0
	for p: Node3D in world.players.get_children():
		if p.peer_id==1:continue
		p.position=Vector3(-3,.05,-75+index*2);p.net_position=p.position;index+=1
	await hold("rail_cart",8.5)
	check(world.objectives.escape_time>=0,"all living teammates allow rail departure")
	if not await until(func():return world.objectives.result.begins_with("Победа")):return
	if not await until(func():return everyone("victory")):return
	NetworkManager.return_to_lobby()
	if not await until(func():return not NetworkManager.in_match and not NetworkManager.unloading):return
	NetworkManager.choose_map(0);NetworkManager.start_round()
	if not await until(func():return NetworkManager.in_match and GameManager.local_player()!=null):return
	if not await until(func():return everyone("station")):return
	finish.rpc();await get_tree().create_timer(.5).timeout;NetworkManager.leave(false)
	print("TEST_PASS forest host: %d-player tasks, sabotage, rail escape and rematch" % expected);get_tree().quit(0)
@rpc("any_peer","call_remote","reliable")
func report(phase: String) -> void:
	if multiplayer.is_server():reports[multiplayer.get_remote_sender_id()]=phase
@rpc("authority","call_remote","reliable")
func finish() -> void:
	finished=true;print("TEST_PASS forest client: tasks, clue sync, moving rail escape and map switching")
