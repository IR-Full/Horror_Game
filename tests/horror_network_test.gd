extends "res://tests/horror_check.gd"
var mode: String=""
var expected: int=2
var port: int=27993
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
func run() -> void:
	name="HorrorNetworkRunner"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--horror-test="):mode=argument.get_slice("=",1)
		if argument.begins_with("--players="):expected=int(argument.get_slice("=",1))
		if argument.begins_with("--port="):port=int(argument.get_slice("=",1))
	NetworkManager.left_room.connect(func():
		if finished:get_tree().quit(0)
	)
	if mode=="client":await client()
	else:await host()
func client() -> void:
	check(NetworkManager.join_room("127.0.0.1","Horror client",port)==OK,"horror client connects")
	if not await until(func():return NetworkManager.in_match and GameManager.local_player()!=null and GameManager.world.players.get_child_count()==expected):return
	var w: Node3D=GameManager.world;var m: Node3D=w.monster;GameManager.local_player().input_enabled=false
	report.rpc_id(1,"ready")
	if not await until(func():return w.last_speech_take==0):return
	check(GameManager.interface.monster_caption.text.contains(str(AudioManager.speech_captions[0])),"same recorded line and translation reach clients")
	if not await until(func():return m.hit_serial==1 and m.state==m.State.STUNNED):return
	if not await until(func():return m.fall_elapsed>=m.fall_duration() and m.wounds.pools.size()==1 and m.wounds.pools[0].visible):return
	check(m.position.distance_to(Vector3(41,.05,-31))>.15 and face_down(m),"stumble motion and prone landing replicate")
	var pool: Node3D=m.wounds.pools[0];var anchor: Vector3=pool.global_position;var first: float=m.wounds.records[0].spread
	report.rpc_id(1,"down")
	if not await until(func():return float(m.wounds.records[0].spread)>first+.07):return
	check(pool.global_position.distance_to(anchor)<.01,"client blood grows at its fixed landing position")
	report.rpc_id(1,"growth")
	if not await until(func():return m.state!=m.State.STUNNED and m.position.distance_to(anchor)>6):return
	check(pool.visible and pool.global_position.distance_to(anchor)<.01,"blood stays on the floor after replicated recovery and movement")
	report.rpc_id(1,"recovered")
func host() -> void:
	check(NetworkManager.host_room("Horror host",port)==OK,"horror host connects")
	NetworkManager.choose_role(2);NetworkManager.choose_map(2)
	if not await until(func():return NetworkManager.members.size()==expected):return
	NetworkManager.start_round()
	if not await until(func():return NetworkManager.in_match and GameManager.local_player()!=null):return
	if not await until(func():return everyone("ready")):return
	var w: Node3D=GameManager.world;var m: Node3D=w.monster;var actor: Node3D=GameManager.local_player();actor.input_enabled=false;m.set_physics_process(false)
	var index: int=0
	for player: Node3D in w.players.get_children():
		player.position=Vector3(41+index*.8,.05,-24 if player.peer_id==1 else -22);player.net_position=player.position;index+=1
	m.position=Vector3(41,.05,-31);m.net_position=m.position;m.rotation.y=PI;m.net_rotation=PI;m.velocity=Vector3(0,0,3.4);m.change_state(m.State.PATROL,Vector3.ZERO)
	await get_tree().create_timer(.3).timeout
	w.monster_speech.rpc(m.eye_position(),0);aim(actor,m.position+Vector3.UP*1.4);await frames()
	actor.apply_action("shoot",0);m.set_physics_process(true)
	if not await until(func():return everyone("down")):return
	await get_tree().create_timer(4).timeout
	if not await until(func():return everyone("growth")):return
	m.stunned_left=.02
	if not await until(func():return m.state!=m.State.STUNNED and m.recovery_left<=0):return
	m.set_physics_process(false);m.position=Vector3(41,.05,-45);m.net_position=m.position
	if not await until(func():return everyone("recovered")):return
	finish.rpc();await get_tree().create_timer(.5).timeout;NetworkManager.leave(false);await get_tree().create_timer(.2).timeout
	print("TEST_PASS horror host: %d-player recorded speech, prone collapse and persistent bleeding" % expected);get_tree().quit(0)
@rpc("any_peer","call_remote","reliable")
func report(phase: String) -> void:
	if multiplayer.is_server():reports[multiplayer.get_remote_sender_id()]=phase
@rpc("authority","call_remote","reliable")
func finish() -> void:
	finished=true;print("TEST_PASS horror client: actor voice, fall and blood")
