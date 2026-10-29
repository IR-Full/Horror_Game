extends Node
func _ready() -> void: _run.call_deferred()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-results/"+name)
func look(at: Vector3,target: Vector3) -> void:
	var p: Node3D=GameManager.local_player(); p.position=at; p.net_position=at; p.velocity=Vector3.ZERO
	var direction: Vector3=(target-p.eye_position()).normalized()
	p.local_aim=Vector2(atan2(-direction.x,-direction.z),asin(direction.y)); p.aim=p.local_aim
	p.rig.rotation=Vector3(p.local_aim.y,p.local_aim.x,0)
func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED); DisplayServer.window_set_size(Vector2i(1152,648))
	var fx: int=AudioServer.get_bus_index("Effects"); AudioServer.set_bus_mute(fx,true)
	await get_tree().create_timer(.3).timeout
	NetworkManager.host_room("Техник",27982); NetworkManager.choose_map(2)
	GameManager.interface._show_lobby(); await get_tree().create_timer(.3).timeout; await shot("v11_lobby.png")
	NetworkManager.start_round(true); await get_tree().create_timer(.6).timeout
	var w: Node3D=GameManager.world; var p: Node3D=GameManager.local_player(); p.input_enabled=false; w.monster.set_physics_process(false)
	SettingsManager.quality=2; SettingsManager.resolution_scale=.75; SettingsManager.apply()
	w.monster.position=Vector3(41,.05,-20); w.monster.change_state(w.monster.State.PATROL,Vector3.ZERO)
	w.monster.rotation.y=PI
	look(Vector3(41,.05,-15),Vector3(41,1.55,-20)); await get_tree().create_timer(1.2).timeout; await shot("v11_doctor.png")
	w.monster.position=Vector3(0,.05,-90); w.monster.change_state(w.monster.State.DORMANT,Vector3.ZERO)
	look(Vector3(28,.05,-19),Vector3(28,1,-24)); await get_tree().create_timer(.5).timeout; await shot("v11_theatre.png")
	p.lamp_on=false; await get_tree().create_timer(.4).timeout; await shot("v11_darkness.png")
	p.lamp_on=true; look(Vector3(0,.05,-2),Vector3(-3.85,1.7,-8)); await get_tree().create_timer(.4).timeout; await shot("v11_writing.png")
	GameManager.interface.open_map(); await get_tree().create_timer(.3).timeout; await shot("v11_map.png"); GameManager.interface.close_map()
	w.objectives.generator_on=true; w.objectives.powered=true
	look(Vector3(41,.05,-15),Vector3(41,1.55,-20)); w.monster.position=Vector3(41,.05,-19); w.monster.change_state(w.monster.State.CHASE,p.position)
	await get_tree().create_timer(.6).timeout; await shot("v11_doctor_crawl.png")
	w.monster.neutralize(); await get_tree().create_timer(1.2).timeout; await shot("v11_doctor_fall.png")
	NetworkManager.leave(); AudioServer.set_bus_mute(fx,false)
	print("HOSPITAL_UI_PASS"); get_tree().quit()
