extends Node
## Push-to-talk team radio. The host relays authenticated audio and derives AI noise.
signal frame_received(speaker: int, sequence: int, pcm: PackedByteArray)
const CODEC := preload("res://scripts/core/voice_codec.gd")
const JITTER := preload("res://scripts/core/voice_jitter.gd")
const LOUD_LEVEL := .065
var capture: AudioEffectCapture
var microphone: AudioStreamPlayer
var streams: Dictionary = {}
var activity: Dictionary = {}
var muted_peers: Dictionary = {}
var server_limits: Dictionary = {}
var monitor_enabled: bool = false
var transmitting: bool = false
var local_level: float = 0
var input_status: String = ""
var sequence: int = 0
var current_phase: int = -999
var capture_started: float = 0
var last_capture_data: float = 0
var sent_until: float = 0
var previous_sample: float = 0
var previous_filtered: float = 0

func _ready() -> void:
	SettingsManager.changed.connect(_settings_changed)
	_settings_changed()

func phase() -> int:
	return NetworkManager.round_id if NetworkManager.in_match else -1

func _settings_changed() -> void:
	if DisplayServer.get_name() == "headless": return
	var devices: PackedStringArray = AudioServer.get_input_device_list()
	var wanted: String = SettingsManager.microphone_device
	if not wanted in devices: wanted = "Default"
	if AudioServer.input_device != wanted:
		_stop_capture()
		AudioServer.input_device = wanted
	if not SettingsManager.voice_enabled:
		_stop_capture()
		_clear_streams()

func _ensure_capture() -> void:
	if not is_instance_valid(microphone):
		var index: int = AudioServer.get_bus_index("MicrophoneCapture")
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count-1
			AudioServer.set_bus_name(index,"MicrophoneCapture")
		capture = AudioEffectCapture.new()
		capture.buffer_length = .2
		AudioServer.add_bus_effect(index,capture)
		# Capture is before the muted bus output: no local microphone echo.
		AudioServer.set_bus_mute(index,true)
		microphone = AudioStreamPlayer.new()
		microphone.stream = AudioStreamMicrophone.new()
		microphone.bus = "MicrophoneCapture"
		add_child(microphone)
	if not microphone.playing:
		capture.clear_buffer()
		previous_sample = 0
		previous_filtered = 0
		capture_started = Time.get_ticks_msec()*.001
		last_capture_data = capture_started
		input_status = "Ожидание микрофона…"
		microphone.play()

func _stop_capture() -> void:
	if is_instance_valid(microphone) and microphone.playing: microphone.stop()
	if capture: capture.clear_buffer()
	transmitting = false
	sent_until = 0
	local_level = 0
	input_status = ""

func _may_talk() -> bool:
	if not NetworkManager.active or NetworkManager.loading or NetworkManager.unloading: return false
	if not NetworkManager.members.has(multiplayer.get_unique_id()): return false
	if not SettingsManager.voice_enabled or SettingsManager.microphone_muted: return false
	if not Input.is_action_pressed("voice") or not get_window().has_focus(): return false
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit: return false
	if is_instance_valid(GameManager.interface) and not GameManager.interface.rebind_action.is_empty(): return false
	return true

func _process(_delta: float) -> void:
	_ensure_phase()
	transmitting = false
	if DisplayServer.get_name() != "headless":
		var talk: bool = _may_talk()
		var monitor: bool = monitor_enabled and SettingsManager.voice_enabled and get_window().has_focus()
		if talk or monitor:
			_ensure_capture()
			_capture_frames(talk)
			transmitting = talk and Time.get_ticks_msec()*.001 < sent_until
		else: _stop_capture()
		_play_queues()
	for id: int in activity.keys():
		if not NetworkManager.members.has(id): drop_peer(id)

func _capture_frames(talk: bool) -> void:
	var now: float = Time.get_ticks_msec()*.001
	var frames: int = maxi(1,roundi(AudioServer.get_mix_rate()*.02))
	if capture.get_frames_available() > frames*6: capture.clear_buffer()
	var processed: int = 0
	while capture.can_get_buffer(frames) and processed < 5:
		processed += 1
		last_capture_data = now
		var samples: PackedFloat32Array = CODEC.resample(capture.get_buffer(frames),SettingsManager.microphone_gain)
		for i: int in range(samples.size()):
			var filtered: float = samples[i]-previous_sample+.97*previous_filtered
			previous_sample = samples[i]
			previous_filtered = filtered
			samples[i] = clampf(filtered,-.95,.95)
		var pcm: PackedByteArray = CODEC.encode(samples)
		local_level = CODEC.level(pcm)
		input_status = "Громко — сущность может услышать" if local_level >= LOUD_LEVEL else "Микрофон работает"
		if talk and local_level >= SettingsManager.microphone_gate:
			sent_until = now+.10
			transmitting = true
			send_frame(pcm)
	if processed == 0 and now-last_capture_data > 1.5:
		input_status = "Нет данных микрофона. Проверьте устройство и доступ в ОС."

func send_frame(pcm: PackedByteArray) -> void:
	# Shared by microphone capture and the opt-in synthetic network test.
	if pcm.size() != CODEC.BYTES or not NetworkManager.active: return
	sequence = (sequence+1)&0x7fffffff
	if multiplayer.is_server(): _accept_frame(1,phase(),sequence,pcm)
	else: submit_voice.rpc_id(1,phase(),sequence,pcm)

@rpc("any_peer","call_remote","unreliable",3)
func submit_voice(number: int, number_sequence: int, pcm: PackedByteArray) -> void:
	if multiplayer.is_server():
		_accept_frame(multiplayer.get_remote_sender_id(),number,number_sequence,pcm)

func _accept_frame(speaker: int, number: int, number_sequence: int, pcm: PackedByteArray) -> bool:
	_ensure_phase()
	if not multiplayer.is_server() or not NetworkManager.active or NetworkManager.loading or NetworkManager.unloading: return false
	if number != phase() or not NetworkManager.members.has(speaker) or pcm.size() != CODEC.BYTES: return false
	if number_sequence < 0 or number_sequence > 0x7fffffff: return false
	var now: float = Time.get_ticks_msec()*.001
	var limit: Dictionary = server_limits.get(speaker,{"tokens":12.0,"time":now,"highest":-1,"mask":0,"noise_at":-100.0,"speech":0,"last_speech":-100.0})
	var highest: int = int(limit.highest)
	var age: int = highest-number_sequence
	if highest >= 0 and age >= 0 and (age >= 16 or (int(limit.mask)&(1<<age)) != 0): return false
	var tokens: float = minf(12,float(limit.tokens)+(now-float(limit.time))*55)
	if tokens < 1: return false
	limit.tokens = tokens-1
	limit.time = now
	if number_sequence > highest:
		var shift: int = mini(16,number_sequence-highest)
		limit.mask = ((int(limit.mask)<<shift)|1)&65535
		limit.highest = number_sequence
	else: limit.mask = int(limit.mask)|(1<<age)
	server_limits[speaker] = limit
	var level: float = CODEC.level(pcm)
	_voice_noise(speaker,level,limit,now)
	_queue_frame(speaker,number_sequence,pcm)
	for id: int in NetworkManager.members:
		if id != 1 and id != speaker: receive_voice.rpc_id(id,number,speaker,number_sequence,pcm)
	return true

@rpc("authority","call_remote","unreliable",3)
func receive_voice(number: int, speaker: int, number_sequence: int, pcm: PackedByteArray) -> void:
	_ensure_phase()
	if not NetworkManager.active or number != phase() or not NetworkManager.members.has(speaker): return
	if pcm.size() != CODEC.BYTES or number_sequence < 0: return
	_queue_frame(speaker,number_sequence,pcm)

static func noise_radius(level: float) -> float:
	return 0.0 if level < .015 else clampf(4+(level-.015)*100,4,30)

func _voice_noise(speaker: int, level: float, limit: Dictionary, now: float) -> void:
	var radius: float = noise_radius(level)
	if radius <= 0: limit.speech = 0; return
	if now-float(limit.last_speech) > .15: limit.speech = 0
	limit.speech = int(limit.speech)+1
	limit.last_speech = now
	if int(limit.speech) < 3 or now-float(limit.noise_at) < .4: return
	if not NetworkManager.in_match or not is_instance_valid(GameManager.world): return
	var actor: Node3D = GameManager.world.players.get_node_or_null(str(speaker))
	if not actor or actor.dead or actor.vent_time > 0 or not GameManager.world.objectives.result.is_empty(): return
	limit.noise_at = now
	GameManager.world.make_noise(actor.position,radius)

func _queue_frame(speaker: int, number_sequence: int, pcm: PackedByteArray) -> void:
	var now: float = Time.get_ticks_msec()*.001
	activity[speaker] = now+.3
	frame_received.emit(speaker,number_sequence,pcm)
	if speaker == multiplayer.get_unique_id() or muted_peers.has(speaker) or not SettingsManager.voice_enabled: return
	if DisplayServer.get_name() == "headless": return
	if not streams.has(speaker):
		var player := AudioStreamPlayer.new()
		var generator := AudioStreamGenerator.new()
		generator.mix_rate = CODEC.RATE
		generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
		generator.buffer_length = .12
		player.stream = generator
		player.bus = "Voice"
		add_child(player)
		streams[speaker] = {"queue":JITTER.new(),"player":player,"playback":null}
	var state: Dictionary = streams[speaker]
	var was_started: bool = state.queue.started
	state.queue.insert(number_sequence,pcm,now)
	if was_started and not state.queue.started:
		state.player.stop()
		state.playback = null

func _play_queues() -> void:
	var now: float = Time.get_ticks_msec()*.001
	for id: int in streams.keys():
		var state: Dictionary = streams[id]
		var queue: RefCounted = state.queue
		if now-float(queue.last_packet) > .45:
			_drop_stream(id)
			continue
		if now < float(queue.start_at): continue
		if not state.player.playing:
			state.player.play()
			state.playback = state.player.get_stream_playback()
		var playback: AudioStreamGeneratorPlayback = state.playback
		if not playback: continue
		for i: int in range(6):
			if not playback.can_push_buffer(CODEC.FRAMES): break
			var pcm: PackedByteArray = queue.pop(now)
			if pcm.is_empty(): break
			playback.push_buffer(CODEC.decode(pcm))

func set_peer_muted(id: int, muted: bool) -> void:
	if muted: muted_peers[id] = true; _drop_stream(id)
	else: muted_peers.erase(id)

func _drop_stream(id: int) -> void:
	if not streams.has(id): return
	var player: AudioStreamPlayer = streams[id].player
	player.stop()
	player.stream = null
	player.queue_free()
	streams.erase(id)

func drop_peer(id: int) -> void:
	_drop_stream(id)
	activity.erase(id)
	server_limits.erase(id)
	muted_peers.erase(id)

func _clear_streams() -> void:
	for id: int in streams.keys(): _drop_stream(id)
	activity.clear()

func _ensure_phase() -> void:
	if current_phase == phase(): return
	current_phase = phase()
	_clear_streams()
	server_limits.clear()

func clear_session() -> void:
	_stop_capture()
	_clear_streams()
	server_limits.clear()
	muted_peers.clear()
	monitor_enabled = false
	sequence = 0
	current_phase = -999

func speakers() -> PackedStringArray:
	var result := PackedStringArray()
	var now: float = Time.get_ticks_msec()*.001
	for id: int in activity:
		if id != multiplayer.get_unique_id() and not muted_peers.has(id) and float(activity[id]) > now and NetworkManager.members.has(id):
			result.append(NetworkManager.members[id].name)
	return result

func _exit_tree() -> void:
	clear_session()
