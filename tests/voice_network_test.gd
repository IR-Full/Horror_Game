extends Node
const TONES := preload("res://tests/voice_check.gd")
const BURST_FRAMES: int = 100
const MIN_RECEIVED: int = 50
var mode: String = ""
var expected: int = 2
var port: int = 27955
var selected_map: int = 0
var stage: int = -1
var remaining: int = 0
var next_send_ms: int = 0
var accepted_own: int = 0
var receipts: Dictionary = {}
var reports: Dictionary = {}
var ready_reports: Dictionary = {}
var failed: bool = false
var reported: bool = false
var finished: bool = false

func _ready() -> void:
	name = "VoiceTestRunner"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--voice-test="): mode = argument.get_slice("=",1)
		if argument.begins_with("--players="): expected = int(argument.get_slice("=",1))
		if argument.begins_with("--port="): port = int(argument.get_slice("=",1))
		if argument.begins_with("--map-id="): selected_map = int(argument.get_slice("=",1))
	VoiceManager.frame_received.connect(_received)
	NetworkManager.left_room.connect(func():
		if finished: get_tree().quit(0)
	)
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	if ok: print("CHECK "+mode+": "+label)
	else: failed = true; push_error("TEST_FAIL voice "+mode+": "+label); get_tree().quit(1)
	return ok

func until(predicate: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec()+15000
	while not predicate.call():
		if Time.get_ticks_msec() > deadline:
			print("VOICE_TIMEOUT stage=",stage," reports=",reports," ready=",ready_reports," receipts=",receipts," remaining=",remaining," own_accepted=",accepted_own)
			return check(false,"timeout waiting for voice peers")
		await get_tree().process_frame
	return true

func _run() -> void:
	if mode == "client":
		check(NetworkManager.join_room("127.0.0.1","Voice client",port) == OK,"voice client connects")
		return
	check(NetworkManager.host_room("Voice host",port) == OK,"voice host connects")
	NetworkManager.choose_map(selected_map)
	if not await until(func(): return NetworkManager.members.size() == expected): return
	begin_stage.rpc(0)
	if not await until(func(): return ready_reports.size() == expected): return
	start_audio.rpc()
	if not await until(func(): return reports.size() == expected): return
	check(accepted_own == BURST_FRAMES,"all paced host audio frames pass the server rate limit in the lobby")
	check(true,"all lobby voices relay to every other participant")
	NetworkManager.start_round(true)
	if not await until(func(): return NetworkManager.in_match and GameManager.local_player() != null): return
	var world: Node3D = GameManager.world
	world.monster.set_physics_process(false)
	world.monster.position = Vector3(0,.05,-12)
	world.monster.change_state(world.monster.State.PATROL,Vector3(0,0,-15))
	var host: Node3D = GameManager.local_player()
	host.position = Vector3(0,.05,0); host.net_position = host.position; host.input_enabled = false
	begin_stage.rpc(1)
	if not await until(func(): return ready_reports.size() == expected): return
	# Scene readiness precedes the initial unreliable world snapshots. Let that traffic drain
	# before measuring steady voice relay; a half-second utterance could be lost in startup.
	await get_tree().create_timer(1.0).timeout
	start_audio.rpc()
	if not await until(func(): return reports.size() == expected): return
	check(accepted_own == BURST_FRAMES,"all paced host audio frames pass the server rate limit in the round")
	check(world.monster.state == world.monster.State.INVESTIGATE,"network voice attracts the host-owned monster")
	var matched: bool = false
	for player: Node3D in world.players.get_children():
		if world.monster.last_known.distance_to(player.position) < .2: matched = true
	check(matched,"voice noise is placed at an actual participant")
	check(not VoiceManager._accept_frame(1,-1,999,TONES.tone()),"late lobby audio cannot enter a running round")
	finish.rpc()
	await get_tree().create_timer(.5).timeout
	stage = -1
	NetworkManager.leave(false)
	await get_tree().create_timer(.2).timeout
	print("TEST_PASS voice host: %d-player relay" % expected)
	get_tree().quit(0)

@rpc("authority","call_local","reliable")
func begin_stage(number: int) -> void:
	print("VOICE_STAGE peer=",multiplayer.get_unique_id()," stage=",number)
	stage = number
	remaining = 0
	next_send_ms = Time.get_ticks_msec()+50
	accepted_own = 0
	receipts.clear()
	reported = false
	if multiplayer.is_server():
		reports.clear()
		ready_reports.clear()
	if number==1:
		var deadline: int=Time.get_ticks_msec()+15000
		while not is_instance_valid(GameManager.world) or GameManager.world.players.get_child_count()!=expected or GameManager.local_player()==null:
			if Time.get_ticks_msec()>deadline:
				check(false,"all player scenes must exist before match audio starts"); return
			await get_tree().physics_frame
		# Spawn packets use another channel; wait for each peer's heavy setup, not only begin_round.
		await get_tree().physics_frame
		await get_tree().physics_frame
	if multiplayer.is_server(): ready_reports[1] = stage
	else: stage_ready.rpc_id(1,stage)

@rpc("any_peer","call_remote","reliable")
func stage_ready(number: int) -> void:
	if multiplayer.is_server() and number == stage: ready_reports[multiplayer.get_remote_sender_id()] = number

@rpc("authority","call_local","reliable")
func start_audio() -> void:
	remaining = BURST_FRAMES
	next_send_ms = Time.get_ticks_msec()+50

func _process(_delta: float) -> void:
	if stage < 0 or failed or not NetworkManager.active: return
	var now: int = Time.get_ticks_msec()
	if remaining > 0 and now >= next_send_ms:
		# A stalled frame must not become a catch-up burst rejected by the voice limiter.
		next_send_ms = now+20
		remaining -= 1
		var hz: float = (multiplayer.get_unique_id()%5+1)*100
		VoiceManager.send_frame(TONES.tone(.35,hz))
		if remaining == 0: print("VOICE_BURST peer=",multiplayer.get_unique_id()," stage=",stage," receipts=",receipts," own_accepted=",accepted_own)
	if remaining > 0 or reported: return
	for id: int in NetworkManager.members:
		if id != multiplayer.get_unique_id() and int(receipts.get(id,0)) < MIN_RECEIVED: return
	reported = true
	check(receipts.size() == expected-1,"receive voice from every other player, without local echo")
	if multiplayer.is_server(): reports[1] = stage
	else:
		print("VOICE_SENDING_REPORT peer=",multiplayer.get_unique_id()," stage=",stage)
		report.rpc_id(1,stage)

func _received(speaker: int, _sequence: int, pcm: PackedByteArray) -> void:
	if stage < 0: return
	if speaker == multiplayer.get_unique_id():
		accepted_own += 1
		return
	var hz: float = (speaker%5+1)*100
	if pcm != TONES.tone(.35,hz):
		check(false,"relayed PCM preserves sender identity and samples")
		return
	if not receipts.has(speaker): check(true,"verified PCM from authenticated speaker "+str(speaker))
	receipts[speaker] = int(receipts.get(speaker,0))+1

@rpc("any_peer","call_remote","reliable")
func report(number: int) -> void:
	print("VOICE_INCOMING_REPORT peer=",multiplayer.get_remote_sender_id()," number=",number," current=",stage)
	if multiplayer.is_server() and number == stage:
		reports[multiplayer.get_remote_sender_id()] = number
		print("VOICE_REPORT stage=",number," peer=",multiplayer.get_remote_sender_id()," count=",reports.size())

@rpc("authority","call_remote","reliable")
func finish() -> void:
	print("TEST_PASS voice client: lobby and match relay")
	finished = true
	stage = -1
