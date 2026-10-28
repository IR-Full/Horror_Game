extends Node
func _ready() -> void: _run.call_deferred()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-results/"+name)
func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1152,648))
	await get_tree().create_timer(.5).timeout
	NetworkManager.host_room("Техник",27958)
	for id: int in [2,3,4]: NetworkManager.members[id] = {"name":"Напарник %d" % id,"role":(id-1)%3}
	GameManager.interface._show_lobby()
	await get_tree().create_timer(.25).timeout
	await shot("voice_lobby.png")
	GameManager.interface._show_settings(false,1)
	NetworkManager.lobby_changed.emit()
	if GameManager.interface.screen_kind != "settings": push_error("VOICE_UI_FAIL lobby updates must preserve audio settings")
	await get_tree().create_timer(.25).timeout
	var scroll: ScrollContainer = GameManager.interface.microphone_meter.get_parent().get_parent()
	scroll.scroll_vertical = 285
	await get_tree().create_timer(.2).timeout
	await shot("voice_settings.png")
	var monitor: CheckButton = GameManager.interface.microphone_meter.get_parent().get_child(GameManager.interface.microphone_meter.get_index()-1)
	monitor.button_pressed = true
	scroll.scroll_vertical = 9999
	await get_tree().create_timer(.4).timeout
	await shot("voice_microphone.png")
	GameManager.interface.finish_settings()
	if GameManager.interface.screen_kind != "lobby": push_error("VOICE_UI_FAIL settings must return to lobby")
	VoiceManager._stop_capture()
	NetworkManager.members = {1:{"name":"Техник","role":0}}
	NetworkManager.start_round(true)
	await get_tree().create_timer(.7).timeout
	GameManager.local_player().input_enabled = false
	VoiceManager.set_process(false)
	NetworkManager.members[9004] = {"name":"Напарник","role":1}
	VoiceManager.activity[9004] = Time.get_ticks_msec()*.001+2
	VoiceManager.transmitting = true
	VoiceManager.local_level = .1
	await get_tree().create_timer(.25).timeout
	await shot("voice_hud.png")
	NetworkManager.members.erase(9004)
	NetworkManager.leave()
	VoiceManager.set_process(true)
	print("VOICE_UI_PASS")
	get_tree().quit()
