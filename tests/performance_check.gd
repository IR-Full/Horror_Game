extends Node
## Native high-preset comparison at a fixed camera; opt-in development benchmark.
func _ready() -> void: _run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1152,648))
	await get_tree().create_timer(.8).timeout
	NetworkManager.host_room("Performance QA",27952)
	NetworkManager.start_round(true)
	await get_tree().create_timer(.5).timeout
	var player: Node3D = GameManager.local_player()
	player.input_enabled = false
	player.local_aim = Vector2.ZERO
	GameManager.world.monster.set_physics_process(false)
	GameManager.world.objectives.generator_on = true
	var mode: int = DisplayServer.window_get_mode()
	SettingsManager.quality = 2
	SettingsManager.resolution_scale = .75
	SettingsManager.apply()
	if "--perf-south" in OS.get_cmdline_user_args():
		player.position = Vector3(0,.05,30)
		player.net_position = player.position
		player.local_aim = Vector2(PI,0)
	print("WINDOW_MODE_PASS" if mode == DisplayServer.window_get_mode() else "WINDOW_MODE_FAIL")
	await get_tree().create_timer(4).timeout
	var start: int = Time.get_ticks_usec()
	var calls: float = 0
	var objects: float = 0
	for i: int in range(120):
		await get_tree().process_frame
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var seconds: float = (Time.get_ticks_usec()-start)*.000001
	var result: Dictionary = {"fps":120.0/seconds,"draw_calls":calls/120,"objects":objects/120,"quality":"high","scale":.75,"resolution":"1152x648","gpu":RenderingServer.get_video_adapter_name()}
	var name: String = "plain" if "--no-batching" in OS.get_cmdline_user_args() else "batched"
	if "--perf-south" in OS.get_cmdline_user_args(): name += "-south"
	FileAccess.open("res://test-results/perf-%s.json" % name,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PERF_"+name.to_upper()+" "+JSON.stringify(result))
	NetworkManager.leave()
	get_tree().quit()
