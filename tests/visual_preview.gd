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
	NetworkManager.start_round(true)
	await get_tree().create_timer(1.5).timeout
	var player: Node3D = GameManager.local_player()
	player.input_enabled = false
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
	player.position = Vector3(-10, .05, 2.3)
	player.net_position = player.position
	player.local_aim = Vector2(0, -.23)
	await get_tree().create_timer(.6).timeout
	await shot("generator.png")
	GameManager.world.monster.set_physics_process(false)
	GameManager.world.monster.state = 3
	GameManager.world.monster.show()
	GameManager.world.monster.position = Vector3(0, .05, -2)
	GameManager.world.monster.rotation.y = PI
	player.position = Vector3(0, .05, 2.5)
	player.net_position = player.position
	player.local_aim = Vector2(0, .05)
	await get_tree().create_timer(.6).timeout
	await shot("entity.png")
	GameManager.interface._show_pause()
	GameManager.interface._show_settings(true)
	await get_tree().create_timer(0.3).timeout
	await shot("settings.png")
	NetworkManager.leave()
	get_tree().quit()
