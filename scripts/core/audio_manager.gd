extends Node
## Attributed CC0 recordings, voice variations and procedural radio/music fallback.
var sounds: Dictionary = {}
var ambience: AudioStreamPlayer
var music: AudioStreamPlayer
var alert: AudioStreamPlayer
var last_take: Dictionary = {}

func _ready() -> void:
	var bank: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/bank.json"))
	for kind: String in bank.sounds:
		var takes: Array[AudioStream] = []
		for path: String in bank.sounds[kind]:
			var stream: AudioStream = load(path)
			if kind in bank.loops and stream is AudioStreamOggVorbis: stream.loop = true
			takes.append(stream)
		sounds[kind] = takes
	# Headless LAN tests have no audio device and do not need playback resources.
	if DisplayServer.get_name() == "headless":
		return
	for kind: String in ["step", "radio", "pickup", "door", "hurt", "power", "knock", "whisper", "heartbeat", "entity_step", "motor", "breath", "scrape", "roar", "growl", "crawl_impact", "smash", "shotgun", "reload", "pain", "sos", "alarm"]:
		if not sounds.has(kind): sounds[kind] = [_make_sound(kind)]
	ambience = AudioStreamPlayer.new()
	ambience.stream = stream_for("hum") if sounds.has("hum") else _make_sound("hum")
	ambience.volume_db = -25.0
	ambience.bus = "Ambience"
	add_child(ambience)
	music = AudioStreamPlayer.new()
	music.stream = _make_sound("score")
	music.volume_db = -26
	music.bus = "Music"
	add_child(music)
	alert = AudioStreamPlayer.new()
	alert.stream = stream_for("alarm").duplicate()
	if alert.stream is AudioStreamOggVorbis: alert.stream.loop = true
	alert.volume_db = -23
	alert.bus = "Effects"
	add_child(alert)
	for bus_name: String in ["Room", "Occluded"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Effects" if bus_name == "Room" else "Room")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = .65
	reverb.damping = .65
	reverb.wet = .12
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Room"),reverb)
	var muffled := AudioEffectLowPassFilter.new()
	muffled.cutoff_hz = 1800
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Occluded"),muffled)

func stream_for(kind: String) -> AudioStream:
	if not sounds.has(kind): return null
	var takes: Array = sounds[kind]
	var index: int = randi()%takes.size()
	if takes.size()>1 and int(last_take.get(kind,-1)) == index: index=(index+1)%takes.size()
	last_take[kind] = index
	return takes[index]

func _process(_delta: float) -> void:
	if not is_instance_valid(alert): return
	var active: bool = NetworkManager.in_match and is_instance_valid(GameManager.world) and not GameManager.world.objectives.emergency.is_empty() and GameManager.world.objectives.result.is_empty()
	if active and not alert.playing: alert.play()
	elif not active and alert.playing: alert.stop()

func _make_sound(kind: String) -> AudioStreamWAV:
	var rate: int = 16000
	var duration: float = 4.0 if kind in ["hum", "motor", "score"] else (1.6 if kind in ["whisper", "sos", "alarm"] else (1.0 if kind in ["knock", "pain"] else (.7 if kind in ["heartbeat", "radio", "smash", "shotgun"] else .22)))
	if kind in ["breath", "scrape"]:
		duration = 1.4
	if kind in ["roar", "growl"]:
		duration = 1.9 if kind == "roar" else 1.15
	if kind == "sos":
		duration = 2.7
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
			"score": value = (sin(TAU * 55 * t) * .19 + sin(TAU * 58.25 * t) * .1 + sin(TAU * 82.5 * t) * .12) * (.6 + .3 * cos(TAU * .25 * t))
			"shotgun": value = tanh((rng.randf_range(-1, 1) * .9 + sin(TAU * 49 * t) * .7) * 2) * exp(-t * 12) + filtered * .3 * exp(-t * 4)
			"smash": value = (sin(TAU * 61 * t) * .65 + sin(TAU * 183 * t) * .17 + filtered * .8) * exp(-t * 8)
			"reload": value = filtered * .7 * (exp(-t * 80) + exp(-absf(t - .15) * 85))
			"pain": value = (sin(TAU * 115 * t + sin(t * 29) * 2) * .24 + filtered * .3) * pow(sin(PI * float(i) / count), 2)
			"sos":
				var pulse: float = 0
				for interval: Vector2 in [Vector2(0,.1), Vector2(.2,.3), Vector2(.4,.5), Vector2(.7,1), Vector2(1.1,1.4), Vector2(1.5,1.8), Vector2(2,2.1), Vector2(2.2,2.3), Vector2(2.4,2.5)]:
					if t >= interval.x and t < interval.y:
						pulse = minf(1, (t-interval.x)*200) * minf(1, (interval.y-t)*200)
				value = sin(TAU * 780 * t) * .6 * pulse
			"alarm": value = sin(TAU * (580 + 90 * sin(t * 8)) * t) * .4 * (.6 + .4 * sin(t * 13))
			"hum": value = sin(TAU * 43.0 * t) * .17 + sin(TAU * 67.0 * t) * .09 + filtered * .3 * (.6 + .2 * sin(TAU * .25 * t))
			"motor": value = (sin(TAU * 52 * t) * .45 + sin(TAU * 104 * t) * .16 + filtered * .26) * (.8 + sin(TAU * 7 * t) * .15)
			"radio": value = (filtered * .8 + sin(TAU * 810.0 * t) * 0.03) * envelope
			"whisper": value = filtered * sin(PI * float(i) / count) * (.24 + .5 * absf(sin(t * 13.0) * cos(t * 8)))
			"breath":
				var throat: float = sin(TAU * 87 * t + sin(t * 17) * .5) * .13 + sin(TAU * 174 * t) * .045
				value = (filtered * .65 + throat) * pow(sin(PI * float(i) / count), 2) * (.5 + .25 * sin(t * 5))
			"scrape": value = (filtered * .5 + sin(TAU * 337 * t + sin(t * 27) * .4) * .04) * sin(PI * float(i) / count) * (.35 + .4 * absf(sin(t * 7)))
			"roar", "growl":
				var pitch: float = (67.0 if kind == "roar" else 45.0) - 13.0 * float(i) / count
				var throat: float = sin(TAU * pitch * t + sin(t * 24) * .8) * .44 + sin(TAU * pitch * 2.06 * t) * .15 + sin(TAU * 387 * t) * .07
				var attack: float = minf(1.0, t * 16)
				value = tanh((throat + filtered * .8) * 2.1) * attack * pow(1.0 - float(i) / count, .55) * .9
			"crawl_impact": value = (sin(TAU * 53 * t) * .82 + filtered * .52) * exp(-t * 19) * minf(1, t * 160)
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
	if kind in ["hum", "motor", "score"]:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream

func set_ambience(enabled: bool) -> void:
	if not is_instance_valid(ambience):
		return
	if enabled and not ambience.playing:
		ambience.play()
		music.play()
	elif not enabled:
		ambience.stop()
		music.stop()

func play_local(kind: String) -> void:
	if DisplayServer.get_name() == "headless": return
	if not sounds.has(kind):
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream_for(kind)
	player.bus = "Effects"
	player.volume_db = -16.0
	if kind == "heartbeat":
		player.volume_db = -20.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_at(kind: String, position: Vector3, volume_offset: float = 0.0) -> void:
	if DisplayServer.get_name() == "headless": return
	if not sounds.has(kind) or not is_instance_valid(GameManager.world):
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream_for(kind)
	player.bus = "Room"
	player.pitch_scale = randf_range(.97,1.03) if kind in ["step","step_metal","step_gravel","growl","pain","hurt"] else 1.0
	player.volume_db = -10.0
	if kind in ["whisper", "entity_step", "breath", "scrape"]:
		player.volume_db = -15.0
	if kind in ["roar", "growl"]:
		player.volume_db = -1.0 if kind == "roar" else -5.0
	if kind == "crawl_impact":
		player.volume_db = -7.0
	if kind in ["smash", "shotgun", "alarm"]:
		player.volume_db = -2.0
	player.volume_db += volume_offset
	player.max_distance = 65.0 if kind in ["roar","smash","shotgun"] else 24.0
	var listener: Node3D = GameManager.local_player()
	if listener and listener.position.distance_to(position) > 2:
		var ray := PhysicsRayQueryParameters3D.create(listener.eye_position(),position+Vector3.UP*.25,1|4,[listener.get_rid()])
		if not GameManager.world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			player.bus = "Occluded"
			player.volume_db -= 7
	GameManager.world.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()
