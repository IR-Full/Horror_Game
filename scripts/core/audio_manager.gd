extends Node
## Original synthesized sound design; no microphone or downloaded recordings.
var sounds: Dictionary = {}
var ambience: AudioStreamPlayer

func _ready() -> void:
	# Headless LAN tests have no audio device and do not need playback resources.
	if DisplayServer.get_name() == "headless":
		return
	for kind: String in ["step", "radio", "pickup", "door", "hurt", "power", "knock", "whisper", "heartbeat", "entity_step", "motor"]:
		sounds[kind] = _make_sound(kind)
	ambience = AudioStreamPlayer.new()
	ambience.stream = _make_sound("hum")
	ambience.volume_db = -25.0
	add_child(ambience)

func _make_sound(kind: String) -> AudioStreamWAV:
	var rate: int = 16000
	var duration: float = 4.0 if kind in ["hum", "motor"] else (1.6 if kind == "whisper" else (1.0 if kind == "knock" else (.7 if kind in ["heartbeat", "radio"] else .22)))
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 718 + kind.hash()
	var filtered: float = 0.0
	for i: int in range(count):
		var t: float = float(i) / rate
		var envelope: float = pow(1.0 - float(i) / count, 2.0)
		var value: float
		filtered = lerpf(filtered, rng.randf_range(-1, 1), .17)
		match kind:
			"hum": value = sin(TAU * 43.0 * t) * .17 + sin(TAU * 67.0 * t) * .09 + filtered * .3 * (.6 + .2 * sin(TAU * .25 * t))
			"motor": value = (sin(TAU * 52 * t) * .45 + sin(TAU * 104 * t) * .16 + filtered * .26) * (.8 + sin(TAU * 7 * t) * .15)
			"radio": value = (filtered * .8 + sin(TAU * 810.0 * t) * 0.03) * envelope
			"whisper": value = filtered * sin(PI * float(i) / count) * (.24 + .5 * absf(sin(t * 13.0) * cos(t * 8)))
			"knock":
				var pulse: float = 0.0
				for strike: float in [.03, .28, .67]:
					if t >= strike:
						pulse += exp(-(t - strike) * 38.0)
				value = (sin(TAU * 105 * t) * .7 + filtered * .5) * pulse
			"heartbeat":
				var beat: float = exp(-pow((t - .06) * 27, 2)) + .7 * exp(-pow((t - .24) * 30, 2))
				value = sin(TAU * 58 * t) * beat * .7
			"entity_step": value = (sin(TAU * 61 * t) * .6 + filtered * .6) * envelope
			"pickup": value = sin(TAU * 660.0 * t) * envelope * 0.45
			"hurt": value = (rng.randf_range(-0.3, 0.3) + sin(TAU * 70.0 * t)) * envelope * 0.5
			"power": value = sin(TAU * (95.0 + 160.0 * t) * t) * envelope * 0.6
			_: value = (rng.randf_range(-0.6, 0.6) + sin(TAU * 100.0 * t) * 0.3) * envelope
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 22000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	if kind in ["hum", "motor"]:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream

func set_ambience(enabled: bool) -> void:
	if not is_instance_valid(ambience):
		return
	if enabled and not ambience.playing:
		ambience.play()
	elif not enabled:
		ambience.stop()

func play_local(kind: String) -> void:
	if not sounds.has(kind):
		return
	var player := AudioStreamPlayer.new()
	player.stream = sounds[kind]
	player.volume_db = -16.0
	if kind == "heartbeat":
		player.volume_db = -20.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_at(kind: String, position: Vector3) -> void:
	if not sounds.has(kind) or not is_instance_valid(GameManager.world):
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = sounds[kind]
	player.volume_db = -10.0
	if kind in ["whisper", "entity_step"]:
		player.volume_db = -15.0
	player.max_distance = 24.0
	GameManager.world.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()
