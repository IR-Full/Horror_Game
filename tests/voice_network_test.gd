extends Node
const TONES := preload("res://tests/voice_check.gd")
var mode: String = ""
var expected: int = 2
var port: int = 27955
var stage: int = -1
var remaining: int = 0
var send_clock: float = 0
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
			print("VOICE_TIMEOUT stage=",stage," reports=",reports," ready=",ready_reports," receipts=",receipts," remaining=",remaining)
			return check(false,"timeout waiting for voice peers")
		await get_tree().process_frame
	return true

func _run() -> void:
	if mode == "client":
		check(NetworkManager.join_room("127.0.0.1","Voice client",port) == OK,"voice client connects")
		return
	check(NetworkManager.host_room("Voice host",port) == OK,"voice host connects")
	if not await until(func(): return NetworkManager.members.size() == expected): return
	begin_stage.rpc(0)
	if not await until(func(): return ready_reports.size() == expected): return
	start_audio.rpc()
	if not await until(func(): return reports.size() == expected): return
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
	start_audio.rpc()
	if not await until(func(): return reports.size() == expected): return
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
	send_clock = .05
	receipts.clear()
	reported = false
	if multiplayer.is_server():
		reports.clear()
		ready_reports.clear()
		ready_reports[1] = stage
	else: stage_ready.rpc_id(1,stage)

@rpc("any_peer","call_remote","reliable")
func stage_ready(number: int) -> void:
	if multiplayer.is_server() and number == stage: ready_reports[multiplayer.get_remote_sender_id()] = number

@rpc("authority","call_local","reliable")
func start_audio() -> void:
	remaining = 25
	send_clock = .05

func _process(delta: float) -> void:
	if stage < 0 or failed or not NetworkManager.active: return
	send_clock -= delta
	if remaining > 0 and send_clock <= 0:
		send_clock += .02
		remaining -= 1
		var hz: float = (multiplayer.get_unique_id()%5+1)*100
		VoiceManager.send_frame(TONES.tone(.35,hz))
	if remaining > 0 or reported: return
	for id: int in NetworkManager.members:
		if id != multiplayer.get_unique_id() and int(receipts.get(id,0)) < 12: return
	reported = true
	check(receipts.size() == expected-1,"receive voice from every other player, without local echo")
	if multiplayer.is_server(): reports[1] = stage
	else:
		print("VOICE_SENDING_REPORT peer=",multiplayer.get_unique_id()," stage=",stage)
		report.rpc_id(1,stage)

func _received(speaker: int, _sequence: int, pcm: PackedByteArray) -> void:
	if stage < 0 or speaker == multiplayer.get_unique_id(): return
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
