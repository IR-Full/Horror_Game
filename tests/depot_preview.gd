extends Node
func _ready() -> void: _run.call_deferred()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-results/"+name)
func look(at: Vector3,target: Vector3) -> void:
	var p: Node3D = GameManager.local_player()
	p.position = at; p.net_position = at; p.velocity = Vector3.ZERO
	var direction: Vector3 = (target-p.eye_position()).normalized()
	p.local_aim = Vector2(atan2(-direction.x,-direction.z),asin(direction.y)); p.aim = p.local_aim
	p.rig.rotation = Vector3(p.local_aim.y,p.local_aim.x,0)
func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1152,648))
	var fx: int = AudioServer.get_bus_index("Effects")
	AudioServer.set_bus_mute(fx,true)
	await get_tree().create_timer(.4).timeout
	await shot("v10_menu.png")
	NetworkManager.host_room("Техник",27972); NetworkManager.choose_map(1)
	for id: int in [2,3,4]: NetworkManager.members[id] = {"name":"Напарник %d" % id,"role":(id-1)%3}
	GameManager.interface._show_lobby()
	await get_tree().create_timer(.3).timeout
	await shot("v10_lobby.png")
	NetworkManager.members = {1:{"name":"Техник","role":0}}
	NetworkManager.start_round(true)
	await get_tree().create_timer(.8).timeout
	var w: Node3D = GameManager.world
	var p: Node3D = GameManager.local_player()
	w.monster.set_physics_process(false); p.input_enabled = false
	SettingsManager.quality = 2; SettingsManager.resolution_scale = .75; SettingsManager.apply()
	look(Vector3(-4,.05,18),Vector3(0,1,23))
	await get_tree().create_timer(2).timeout
	await shot("v10_car.png")
	w.monster.position = Vector3(0,.05,-1); w.monster.change_state(w.monster.State.PATROL,Vector3.ZERO)
	look(Vector3(0,.05,6),Vector3(0,1.5,-1))
	await get_tree().create_timer(.5).timeout
	await shot("v10_monster.png")
	w.monster.change_state(w.monster.State.DORMANT,Vector3.ZERO)
	look(Vector3(0,.05,-74),Vector3(0,1.2,-98))
	await get_tree().create_timer(.4).timeout
	await shot("v10_yard.png")
	GameManager.interface.open_map()
	await get_tree().create_timer(.2).timeout
	await shot("v10_map.png")
	GameManager.interface.close_map()
	var other: Node3D = w.PLAYER_SCENE.instantiate()
	other.name = "77"; other.peer_id = 77; other.nickname = "Напарник"
	other.position = Vector3(0,.05,0); other.net_position = other.position
	w.players.add_child(other)
	other.set_physics_process(false); other.motion_speed = 4.5; other.running_motion = true
	other.body_pivot.rotation.y = PI
	look(Vector3(0,.05,4),Vector3(0,1.05,0))
	await get_tree().create_timer(.45).timeout
	await shot("v10_player_run.png")
	p.set_physics_process(false); p.stamina = 8; p.stress = 92
	var capture := AudioEffectCapture.new(); capture.buffer_length = .5
	AudioServer.add_bus_effect(fx,capture)
	await get_tree().create_timer(1.5).timeout
	var samples: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
	var peak: float = 0
	for frame: Vector2 in samples: peak = maxf(peak,absf(frame.x))
	if peak > .01: print("BREATH_AUDIO_PASS ",peak)
	else: push_error("BREATH_AUDIO_FAIL mixer silent")
	AudioServer.remove_bus_effect(fx,AudioServer.get_bus_effect_count(fx)-1)
	await shot("v10_stress.png")
	look(Vector3(0,.05,8),Vector3(0,.1,7.6))
	await get_tree().create_timer(.25).timeout
	await shot("v10_view_legs.png")
	other.hide()
	p.set_physics_process(true)
	w.objectives.installed = w.objectives.PARTS.duplicate()
	w.objectives.escape_time = 0
	w.objects.exit_gate.opened = true
	w.objects.exit_gate.refresh()
	p.in_vehicle = true
	p.vehicle_seat = 0
	await get_tree().create_timer(1.3).timeout
	await shot("v10_departure.png")
	NetworkManager.leave()
	AudioServer.set_bus_mute(fx,false)
	print("DEPOT_UI_PASS")
	get_tree().quit()
