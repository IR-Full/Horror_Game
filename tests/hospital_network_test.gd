extends "res://tests/hospital_check.gd"
var mode: String=""
var expected: int=2
var test_port: int=27983
var reports: Dictionary={}
var finished: bool=false
func until(predicate: Callable,seconds: float=20) -> bool:
	var deadline: int=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call():
		if failures>0 or Time.get_ticks_msec()>deadline:
			check(false,"network timeout "+mode+" reports="+str(reports)); get_tree().quit(1); return false
		await get_tree().process_frame
	return true
func everyone(phase: String) -> bool:
	for id: int in NetworkManager.members:
		if id!=1 and reports.get(id,"")!=phase: return false
	return reports.size()==expected-1
func _run() -> void:
	name="HospitalNetworkRunner"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hospital-test="): mode=argument.get_slice("=",1)
		if argument.begins_with("--players="): expected=int(argument.get_slice("=",1))
		if argument.begins_with("--port="): test_port=int(argument.get_slice("=",1))
	NetworkManager.left_room.connect(func():
		if finished: get_tree().quit(0)
	)
	if mode=="client": await client_run()
	else: await host_run()
func client_run() -> void:
	check(NetworkManager.join_room("127.0.0.1","Hospital client",test_port)==OK,"hospital client connects")
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player()!=null): return
	world=GameManager.world; actor=GameManager.local_player(); actor.input_enabled=false
	check(world.map_id==2 and world.objects.has("hospital_exit"),"hospital selection reaches clients before construction")
	NetworkManager.choose_map(0); check(NetworkManager.map_id==2,"clients cannot override hospital selection")
	if not await until(func(): return world.objectives.serum_ready,55): return
	check(world.objectives.samples.size()==3 and world.objectives.surgery_ready and world.objectives.ward_ready,"all hospital puzzle branches replicate")
	check(world.objects.hospital_fuse_safe.opened and world.objects.morgue_safe.opened and world.objects.scalpel.taken,"safes and instrument consumption replicate")
	check(world.objects.ward_case.position in preload("res://scripts/world/hospital_loot.gd").CONTAINERS.ward_case,"randomized hospital storage agrees with host")
	report.rpc_id(1,"assembled")
	if not await until(func(): return world.objectives.result.begins_with("Победа"),20): return
	check(actor.position.z>57,"teammates are gathered at the actual evacuation lift")
	report.rpc_id(1,"victory")
	if not await until(func(): return not NetworkManager.in_match and not NetworkManager.unloading): return
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player()!=null): return
	check(GameManager.world.map_id==0 and GameManager.world.objects.has("transmitter"),"return to lobby and original station work after hospital")
	report.rpc_id(1,"station")
func host_run() -> void:
	check(NetworkManager.host_room("Hospital host",test_port)==OK,"hospital host connects")
	NetworkManager.choose_map(2); NetworkManager.choose_difficulty(3)
	if not await until(func(): return NetworkManager.members.size()==expected): return
	NetworkManager.start_round()
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player()!=null): return
	world=GameManager.world; actor=GameManager.local_player(); actor.input_enabled=false; world.monster.set_physics_process(false)
	await solve_hospital()
	if failures>0: get_tree().quit(1); return
	if not await until(func(): return everyone("assembled")): return
	await pickup("hospital_badge"); await hold("hospital_exit",.6)
	check(world.objectives.exit_progress==0,"hospital escape cannot abandon teammates")
	var index: int=0
	for player: Node3D in world.players.get_children():
		if player.peer_id==1: continue
		player.position=Vector3(-1.5+index,.05,61); player.net_position=player.position; index+=1
	await hold("hospital_exit",8.4)
	check(world.objectives.result.begins_with("Победа"),"cooperative hospital escape succeeds")
	if not await until(func(): return everyone("victory")): return
	NetworkManager.return_to_lobby()
	if not await until(func(): return not NetworkManager.in_match and not NetworkManager.unloading): return
	NetworkManager.choose_map(0); NetworkManager.start_round()
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player()!=null): return
	if not await until(func(): return everyone("station")): return
	finish.rpc(); await get_tree().create_timer(.5).timeout
	NetworkManager.leave(false); await get_tree().create_timer(.2).timeout
	print("TEST_PASS hospital host: %d-player puzzles and evacuation" % expected); get_tree().quit(0)
@rpc("any_peer","call_remote","reliable")
func report(phase: String) -> void:
	if multiplayer.is_server(): reports[multiplayer.get_remote_sender_id()]=phase
@rpc("authority","call_remote","reliable")
func finish() -> void:
	finished=true; print("TEST_PASS hospital client: puzzles and map switching")
