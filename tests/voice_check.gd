extends Node
const CODEC := preload("res://scripts/core/voice_codec.gd")
const JITTER := preload("res://scripts/core/voice_jitter.gd")
var failures: int = 0

func _ready() -> void: _run.call_deferred()
func check(ok: bool, title: String) -> void:
	if ok: print("VOICE_CHECK "+title)
	else: failures += 1; push_error("VOICE_FAIL "+title)

static func tone(amplitude: float = .3, frequency: float = 500) -> PackedByteArray:
	var samples := PackedFloat32Array()
	samples.resize(CODEC.FRAMES)
	for i: int in range(CODEC.FRAMES): samples[i] = sin(TAU*frequency*i/CODEC.RATE)*amplitude
	return CODEC.encode(samples)

func _run() -> void:
	var pcm: PackedByteArray = tone()
	var decoded: PackedVector2Array = CODEC.decode(pcm)
	check(pcm.size() == 640 and decoded.size() == 320,"20 ms PCM packets stay below the network MTU")
	var error: float = 0
	for i: int in range(decoded.size()):
		error = maxf(error,absf(decoded[i].x-sin(TAU*500*i/CODEC.RATE)*.3))
	check(error < .00005 and decoded[8].x == decoded[8].y,"PCM round trip preserves speech samples and mono channels")
	check(absf(CODEC.level(pcm)-.3/sqrt(2.0)) < .001,"host measures RMS from audio bytes")
	check(CODEC.decode(PackedByteArray([1,2])).is_empty(),"malformed packet is not decoded")
	var source := PackedVector2Array()
	source.resize(960)
	for i: int in range(960): source[i] = Vector2(.2,.4)
	var reduced: PackedFloat32Array = CODEC.resample(source)
	check(reduced.size() == 320 and absf(reduced[100]-.3) < .001,"capture resamples and folds stereo into mono")
	var queue := JITTER.new()
	var a: PackedByteArray = tone(.1)
	var b: PackedByteArray = tone(.2)
	var c: PackedByteArray = tone(.3)
	queue.insert(2,c,0)
	queue.insert(0,a,.01)
	queue.insert(1,b,.02)
	check(not queue.insert(1,b,.03),"duplicate audio is rejected")
	check(queue.pop(.05).is_empty(),"jitter buffer waits for the short prefill")
	check(queue.pop(.07) == a and queue.pop(.07) == b and queue.pop(.07) == c,"reordered packets play in sequence")
	check(not queue.insert(0,a,.08),"already played audio cannot replay")
	queue = JITTER.new()
	queue.insert(0,a,0); queue.insert(2,c,.01)
	queue.pop(.07)
	check(CODEC.level(queue.pop(.07)) == 0 and queue.pop(.07) == c,"lost packets use bounded silence without stalling later speech")
	for i: int in range(100): queue.insert(1000+i,a,.10+i*.001)
	check(queue.pending.size() <= JITTER.LIMIT,"slow or malicious senders cannot grow the playback queue")
	NetworkManager.host_room("Voice QA",27954)
	var voice: Node = VoiceManager
	voice.clear_session()
	check(not voice._accept_frame(999,-1,1,pcm),"unregistered senders cannot relay audio")
	check(not voice._accept_frame(1,99,1,pcm),"stale game-phase packets are rejected")
	check(not voice._accept_frame(1,-1,1,PackedByteArray([1])),"invalid frame size is rejected before relay")
	check(voice._accept_frame(1,-1,1,pcm) and not voice._accept_frame(1,-1,1,pcm),"host rejects replayed voice frames")
	var accepted: int = 1
	for i: int in range(2,40):
		if voice._accept_frame(1,-1,i,pcm): accepted += 1
	check(accepted <= 12,"host bounds voice packet bursts")
	NetworkManager.start_round(true)
	await get_tree().create_timer(.3).timeout
	var world: Node3D = GameManager.world
	var actor: Node3D = GameManager.local_player()
	actor.input_enabled = false
	actor.position = Vector3(0,.05,0)
	actor.net_position = actor.position
	var monster: Node3D = world.monster
	monster.set_physics_process(false)
	monster.position = Vector3(0,.05,-12)
	monster.change_state(monster.State.PATROL,Vector3(0,0,-15))
	voice._ensure_phase()
	var quiet: PackedByteArray = tone(.005)
	for i: int in range(3): voice._accept_frame(1,NetworkManager.round_id,100+i,quiet)
	check(monster.state == monster.State.PATROL,"background microphone noise does not attract the monster")
	for i: int in range(3): voice._accept_frame(1,NetworkManager.round_id,103+i,pcm)
	check(monster.state == monster.State.INVESTIGATE and monster.last_known.distance_to(actor.position) < .1,"loud speech attracts the monster at the authoritative speaker position")
	check(voice.noise_radius(.04) < voice.noise_radius(.2),"louder speech reaches farther")
	monster.lonely_time = 100
	monster.sabotage_cooldown = 0
	monster.perception_clock = 100
	monster._physics_process(.01)
	check(monster.state == monster.State.INVESTIGATE,"fresh voice lead takes priority over overdue sabotage")
	actor.dead = true
	monster.change_state(monster.State.PATROL,Vector3(0,0,-15))
	voice.server_limits[1].noise_at = -100
	for i: int in range(3): voice._accept_frame(1,NetworkManager.round_id,106+i,pcm)
	check(monster.state == monster.State.PATROL,"dead-player radio cannot produce physical voice noise")
	actor.dead = false
	NetworkManager.leave()
	await get_tree().process_frame
	check(voice.streams.is_empty() and voice.activity.is_empty() and voice.server_limits.is_empty(),"disconnect clears audio, activity and server state")
	print("VOICE_PASS" if failures == 0 else "VOICE_FAIL %d checks" % failures)
	get_tree().quit(0 if failures == 0 else 1)
