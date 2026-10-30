extends "res://tests/random_check.gd"
var mode: String="host"
var expected: int=2
var port: int=28003
var reports: Dictionary={}
var fixtures: Dictionary={}
var finished: bool=false
func until(predicate: Callable,seconds: float=20) -> bool:
	var deadline: int=Time.get_ticks_msec()+int(seconds*1000)
	while not predicate.call():
		if failures>0 or Time.get_ticks_msec()>deadline:
			check(false,"network timeout "+mode+" reports="+str(reports));get_tree().quit(1);return false
		await get_tree().process_frame
	return true
func everyone(epoch: int) -> bool:
	for id: int in NetworkManager.members:
		if id!=1 and reports.get(id,-1)!=epoch:return false
	return reports.size()==expected-1
func agrees(w: Node3D,wanted: Dictionary) -> bool:
	var actual: Dictionary=inspect(w)
	if actual.puzzles!=wanted.puzzles or actual.notes!=wanted.notes or actual.kinds!=wanted.kinds:return false
	if actual.places.size()!=wanted.places.size():return false
	for id: String in wanted.places:
		if not actual.places.has(id) or actual.places[id][1]!=wanted.places[id][1]:return false
		var a: Vector3=actual.places[id][0];var b: Vector3=wanted.places[id][0]
		if a.distance_to(b)>.005:return false
	return true
func run() -> void:
	name="RandomNetworkRunner"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--random-test="):mode=argument.get_slice("=",1)
		if argument.begins_with("--players="):expected=int(argument.get_slice("=",1))
		if argument.begins_with("--port="):port=int(argument.get_slice("=",1))
	NetworkManager.left_room.connect(func():
		if finished:get_tree().quit(0)
	)
	if mode=="host":check(NetworkManager.host_room("Random host",port)==OK,"host opens")
	else:check(NetworkManager.join_room("127.0.0.1","Random client",port)==OK,"client connects")
	if mode=="host" and not await until(func():return NetworkManager.members.size()==expected):return
	var last_round: int=-1;var history: Dictionary={}
	for epoch: int in range(4):
		var map_id: int=[0,1,2,0][epoch]
		if mode=="host":
			NetworkManager.choose_map(map_id);NetworkManager.choose_difficulty(3);NetworkManager.start_round()
		if not await until(func():return NetworkManager.in_match and NetworkManager.round_id!=last_round and GameManager.local_player()!=null and GameManager.world.clues_ready):return
		last_round=NetworkManager.round_id
		var w: Node3D=GameManager.world;var p: Node3D=GameManager.local_player()
		p.input_enabled=false;p.set_physics_process(false);w.monster.set_physics_process(false)
		await get_tree().create_timer(.25).timeout
		check(w.map_id==map_id,"map selection")
		if mode=="host":
			var current: Dictionary=inspect(w)
			check(valid_clues(w),"host clues match")
			if history.has(map_id):check(changed(history[map_id],current),"actual new round changes station layout")
			history[map_id]=current
			fixture.rpc(epoch,current)
			if not await until(func():return everyone(epoch)):return
			if epoch<3:
				NetworkManager.return_to_lobby()
				if not await until(func():return not NetworkManager.in_match and not NetworkManager.unloading):return
		else:
			if not await until(func():return fixtures.has(epoch) and agrees(w,fixtures[epoch])):return
			check(valid_clues(w),"client reads actual host solution")
			var before: Dictionary=inspect(w)
			if map_id==0:w.randomize_puzzles()
			else:w.objectives.randomize_round()
			LOOT[map_id].apply(w);CLUES.apply(w)
			check(inspect(w)==before,"client cannot reroll loot or solutions")
			report.rpc_id(1,epoch)
			if epoch<3 and not await until(func():return not NetworkManager.in_match and not NetworkManager.unloading):return
	if mode=="host":
		finish.rpc();await get_tree().create_timer(.5).timeout
		NetworkManager.leave(false)
		print("TEST_PASS random host: all maps, clues, pickups, round restart");get_tree().quit(0)
@rpc("authority","call_remote","reliable")
func fixture(epoch: int,value: Dictionary) -> void:fixtures[epoch]=value
@rpc("any_peer","call_remote","reliable")
func report(epoch: int) -> void:
	if multiplayer.is_server():reports[multiplayer.get_remote_sender_id()]=epoch
@rpc("authority","call_remote","reliable")
func finish() -> void:
	finished=true;print("TEST_PASS random client: authoritative solutions, readable clues and matching loot")
