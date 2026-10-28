extends Node
## Captures the actual renderer for development QA, then exits.
func _ready() -> void:
	_run.call_deferred()

func shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-results/" + filename)

func _run() -> void:
	await get_tree().create_timer(0.8).timeout
	await shot("menu.png")
	NetworkManager.host_room("Техник", 27948)
	NetworkManager.choose_role(2)
	NetworkManager.start_round(true)
	await get_tree().create_timer(1.5).timeout
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
	player.camera.make_current()
	qa_light.queue_free()
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
	NetworkManager.leave()
	get_tree().quit()
