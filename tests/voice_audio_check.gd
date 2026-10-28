extends Node
var failures: int = 0

func _ready() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	if ok: print("VOICE_AUDIO_CHECK "+label)
	else: failures += 1; push_error("VOICE_AUDIO_FAIL "+label)

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	NetworkManager.host_room("Audio QA",27956)
	VoiceManager.set_process(false)
	VoiceManager._ensure_capture()
	await get_tree().create_timer(.3).timeout
	print("VOICE_DEVICE "+AudioServer.get_driver_name()+" • input devices: "+str(AudioServer.get_input_device_list().size()))
	check(VoiceManager.capture.get_frames_available() > 0,"system microphone provides capture frames; no recording is saved")
	VoiceManager._stop_capture()
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = 16000
	tone.data = preload("res://tests/voice_check.gd").tone()
	tone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	tone.loop_end = 320
	var source := AudioStreamPlayer.new()
	source.stream = tone
	source.bus = "MicrophoneCapture"
	add_child(source)
	source.play()
	for i: int in range(5):
		await get_tree().create_timer(.025).timeout
		VoiceManager._capture_frames(false)
	print("VOICE_CAPTURE_LEVEL "+str(VoiceManager.local_level))
	check(VoiceManager.local_level > .1 and not VoiceManager.transmitting,"muted microphone bus captures and resamples without local echo or transmission")
	source.stop()
	source.queue_free()
	var index: int = AudioServer.get_bus_index("Voice")
	AudioServer.set_bus_mute(index,true)
	var output := AudioEffectCapture.new()
	output.buffer_length = .5
	AudioServer.add_bus_effect(index,output)
	NetworkManager.members[9003] = {"name":"Synthetic speaker","role":0}
	for i: int in range(15):
		VoiceManager._queue_frame(9003,i,tone.data)
		VoiceManager._play_queues()
		await get_tree().create_timer(.02).timeout
	var frames: PackedVector2Array = output.get_buffer(output.get_frames_available())
	var peak: float = 0
	for frame: Vector2 in frames: peak = maxf(peak,absf(frame.x))
	check(peak > .1,"remote generator decodes PCM into actual mixer output")
	VoiceManager.set_peer_muted(9003,true)
	check(not VoiceManager.streams.has(9003),"muting a participant immediately stops playback")
	AudioServer.remove_bus_effect(index,AudioServer.get_bus_effect_count(index)-1)
	AudioServer.set_bus_mute(index,false)
	NetworkManager.members.erase(9003)
	NetworkManager.leave()
	VoiceManager.set_process(true)
	await get_tree().process_frame
	print("VOICE_AUDIO_PASS" if failures == 0 else "VOICE_AUDIO_FAIL")
	get_tree().quit(0 if failures == 0 else 1)
