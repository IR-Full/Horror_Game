extends Node
func _ready() -> void: _run.call_deferred()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-results/"+name)
func look(at: Vector3, target: Vector3) -> void:
	var p: Node3D = GameManager.local_player()
	p.position = at; p.net_position = at; p.velocity = Vector3.ZERO
	var direction: Vector3 = (target-p.eye_position()).normalized()
	p.local_aim = Vector2(atan2(-direction.x,-direction.z),asin(direction.y))
	p.aim = p.local_aim
func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1152,648))
	NetworkManager.host_room("Техник",27960)
	NetworkManager.start_round(true)
	await get_tree().create_timer(.6).timeout
	var w: Node3D = GameManager.world
	w.monster.set_physics_process(false)
	GameManager.local_player().input_enabled = false
	SettingsManager.quality = 2
	SettingsManager.resolution_scale = .75
	SettingsManager.apply()
	await get_tree().create_timer(3).timeout
	look(Vector3(0,.05,28),Vector3(0,1.4,55))
	await get_tree().create_timer(.4).timeout
	await shot("v09_south_hall.png")
	look(Vector3(8,.05,51),Vector3(17,.35,43))
	await get_tree().create_timer(.3).timeout
	await shot("v09_water.png")
	look(Vector3(-10,.05,32),w.objects.drain_note.position)
	await get_tree().create_timer(.3).timeout
	await shot("v09_office.png")
	GameManager.interface.open_map()
	await get_tree().create_timer(.2).timeout
	await shot("v09_map.png")
	GameManager.interface.close_map()
	var object: Node3D = w.objects.archive_empty_10
	look(Vector3(10,.05,-.6),object.position)
	object.opened = true; object.refresh()
	await get_tree().create_timer(.3).timeout
	await shot("v09_empty_locker.png")
	NetworkManager.leave()
	print("EXPANSION_UI_PASS")
	get_tree().quit()
