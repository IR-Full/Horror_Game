extends Node
## Captures the actual renderer for development QA, then exits.
func _ready() -> void:
	_run.call_deferred()

func shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-results/" + filename)

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1152,648))
	await get_tree().create_timer(0.8).timeout
	await shot("menu.png")
	NetworkManager.host_room("Техник", 27948)
	NetworkManager.choose_role(2)
	var roster: Dictionary = NetworkManager.members.duplicate(true)
	for id: int in [2,3,4]: NetworkManager.members[id] = {"name":"Участник %d" % id,"role":(id-1)%3}
	GameManager.interface._show_lobby()
	await get_tree().create_timer(.25).timeout
	await shot("lobby.png")
	NetworkManager.members = roster
	NetworkManager.start_round(true)
	await get_tree().create_timer(1.5).timeout
	var helper: Node3D = GameManager.world.PLAYER_SCENE.instantiate()
	helper.name = "9001"
	helper.peer_id = 9001
	helper.nickname = "Медик"
	helper.position = Vector3(-13,.05,-8)
	helper.net_position = helper.position
	GameManager.world.players.add_child(helper)
	var player: Node3D = GameManager.local_player()
	player.input_enabled = false
	player.inventory = PackedStringArray(["fuse", "fuel", "key", "medkit"])
	player.local_aim = Vector2.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(.3).timeout
	await shot("station.png")
	player.position = Vector3(-5.5, 0.05, 6.5)
	player.net_position = player.position
	player.local_aim = Vector2(2.2, 0.1)
	await get_tree().create_timer(0.4).timeout
	await shot("storage.png")
	player.position = Vector3(7.4, .05, -5.4)
	player.net_position = player.position
	player.local_aim = Vector2(-.65, -.08)
	await get_tree().create_timer(.6).timeout
	await shot("radio_room.png")
	player.position = Vector3(0, .05, -2)
	player.net_position = player.position
	player.local_aim = Vector2(.89, .08)
	await get_tree().create_timer(.4).timeout
	await shot("blood_wall.png")
	player.position = Vector3(0, .05, 4)
	player.net_position = player.position
	player.local_aim = Vector2(-.6, -.5)
	await get_tree().create_timer(.4).timeout
	await shot("blood_floor.png")
	player.position = Vector3(-10, .05, 2.3)
	player.net_position = player.position
	player.local_aim = Vector2(0, -.23)
	await get_tree().create_timer(.6).timeout
	await shot("generator.png")
	SettingsManager.quality = 1
	SettingsManager.apply()
	await get_tree().create_timer(2.0).timeout
	await shot("generator_detail.png")
	SettingsManager.quality = 2
	SettingsManager.apply()
	player.position = Vector3(-7,.05,1.6)
	player.net_position = player.position
	player.local_aim = Vector2(-1.1,-.1)
	await get_tree().create_timer(.4).timeout
	await shot("flashlight_high_angle.png")
	GameManager.world.set_physics_process(false)
	for light: OmniLight3D in GameManager.world.lights: light.shadow_enabled = false
	await get_tree().create_timer(.25).timeout
	await shot("flashlight_local_only.png")
	player.lamp.shadow_enabled = false
	await get_tree().create_timer(.25).timeout
	await shot("flashlight_no_shadow.png")
	player.lamp.shadow_enabled = true
	player.lamp.shadow_bias = 1.0
	player.lamp.shadow_normal_bias = 4.0
	await get_tree().create_timer(.25).timeout
	await shot("flashlight_bias.png")
	GameManager.world.set_physics_process(true)
	SettingsManager.quality = 0
	SettingsManager.apply()
	GameManager.world.monster.set_physics_process(false)
	GameManager.world.monster.state = 1
	GameManager.world.monster.show()
	GameManager.world.monster.position = Vector3(0, .05, -2)
	GameManager.world.monster.rotation.y = PI
	player.position = Vector3(0, .05, 1.5)
	player.net_position = player.position
	player.local_aim = Vector2(0, .05)
	await get_tree().create_timer(.6).timeout
	await shot("entity_standing.png")
	GameManager.world.monster.state = 3
	await get_tree().create_timer(.3).timeout
	await shot("entity_drop.png")
	await get_tree().create_timer(.7).timeout
	await shot("entity_crawl.png")
	await shot("entity.png")
	GameManager.world.monster.neutralize()
	await get_tree().create_timer(1.3).timeout
	await shot("entity_down.png")
	player.position = Vector3(0, .05, -16)
	player.net_position = player.position
	player.local_aim = Vector2(0, .02)
	await get_tree().create_timer(.5).timeout
	await shot("north_wing.png")
	player.position = Vector3(-10, .05, -41.5)
	player.net_position = player.position
	player.local_aim = Vector2(0, -.05)
	await get_tree().create_timer(.5).timeout
	GameManager.world.objectives.sabotage("ventilation")
	await get_tree().create_timer(.3).timeout
	await shot("vent_emergency.png")
	GameManager.world.objectives.emergency = ""
	GameManager.interface.show_notice("")
	player.position = Vector3(0, .05, -16)
	player.net_position = player.position
	player.damage(100)
	player.down_time = 75
	await get_tree().create_timer(1.1).timeout
	var observer := Camera3D.new()
	GameManager.world.add_child(observer)
	observer.position = player.position + Vector3(2.1, 1.9, 1.8)
	observer.look_at(player.position + Vector3(0, .2, 0))
	observer.make_current()
	var qa_light := OmniLight3D.new()
	qa_light.position = observer.position
	qa_light.omni_range = 7
	qa_light.light_energy = 1.2
	GameManager.world.add_child(qa_light)
	await get_tree().create_timer(.3).timeout
	await shot("player_down.png")
	player.revive()
	player.lamp_on = true
	player.camera.make_current()
	qa_light.queue_free()
	player.position = Vector3(1,.05,3)
	player.net_position = player.position
	player.local_aim = Vector2(-.12,-.72)
	await get_tree().create_timer(.5).timeout
	await shot("bootprints.png")
	player.position = Vector3(-54,.05,-39)
	player.net_position = player.position
	player.local_aim = Vector2(0,.02)
	await get_tree().create_timer(.6).timeout
	await shot("sector_b.png")
	player.position = Vector3(36,.05,-39.8)
	player.net_position = player.position
	player.local_aim = Vector2(0,-.08)
	await get_tree().create_timer(.6).timeout
	await shot("sector_c.png")
	GameManager.interface.open_circuit()
	await get_tree().create_timer(.3).timeout
	await shot("circuit.png")
	GameManager.interface._resume()
	player.input_enabled = false
	GameManager.interface.open_map()
	await get_tree().create_timer(.3).timeout
	await shot("sector_map.png")
	GameManager.interface._resume()
	player.input_enabled = false
	player.position = Vector3(12,.05,-92)
	player.net_position = player.position
	player.local_aim = Vector2(0,-.08)
	await get_tree().create_timer(.6).timeout
	await shot("sector_d.png")
	GameManager.interface._show_pause()
	GameManager.interface._show_settings(true)
	await get_tree().create_timer(0.3).timeout
	await shot("settings.png")
	GameManager.interface._show_settings(true, 1)
	await get_tree().create_timer(.3).timeout
	await shot("audio_settings.png")
	GameManager.interface._show_settings(true, 2)
	await get_tree().create_timer(.3).timeout
	await shot("controls_settings.png")
	GameManager.interface._resume()
	player.input_enabled = false
	helper.invulnerable = 0
	helper.damage(100)
	helper.apply_action("sos",0)
	await get_tree().create_timer(.5).timeout
	await shot("sos_direction.png")
	GameManager.interface.open_map()
	await get_tree().create_timer(.2).timeout
	await shot("sos_map.png")
	GameManager.interface.close_map()
	player.position = helper.position+Vector3(1.8,0,0)
	player.net_position = player.position
	var help_direction: Vector3 = (helper.position+Vector3.UP*.3-player.eye_position()).normalized()
	player.local_aim = Vector2(atan2(-help_direction.x,-help_direction.z),asin(help_direction.y))
	player.input_enabled = true
	Input.action_press("interact")
	await get_tree().create_timer(.8).timeout
	await shot("healing_progress.png")
	Input.action_release("interact")
	player.input_enabled = false
	helper.revive()
	player.start_vent(Vector3(0,.05,4))
	await get_tree().create_timer(1.5).timeout
	await shot("vent_crawl.png")
	NetworkManager.leave()
	get_tree().quit()
