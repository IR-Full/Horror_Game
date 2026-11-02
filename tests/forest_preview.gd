extends Node
func _ready() -> void:run.call_deferred()
func look(at: Vector3,target: Vector3) -> void:
	var p: Node3D=GameManager.local_player();p.position=at;p.net_position=at;p.velocity=Vector3.ZERO
	var d: Vector3=(target-p.eye_position()).normalized();p.local_aim=Vector2(atan2(-d.x,-d.z),asin(d.y));p.aim=p.local_aim
func capture(label: String) -> void:
	await get_tree().create_timer(1.8).timeout;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-results/forest-"+label+".png")
	print("FOREST_RENDER ",label," fps=",Engine.get_frames_per_second()," draws=",RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1152,648))
	NetworkManager.host_room("Лесобаза: проверка",28017);NetworkManager.choose_role(2);NetworkManager.choose_map(3);NetworkManager.start_round(true)
	await get_tree().create_timer(.8).timeout
	SettingsManager.quality=2;SettingsManager.resolution_scale=.75;SettingsManager.apply()
	var w: Node3D=GameManager.world;var p: Node3D=GameManager.local_player();p.input_enabled=false;w.monster.set_physics_process(false)
	w.objectives.generator_on=true
	look(Vector3(-16,.05,37),Vector3(-16,1.8,28));await capture("office")
	look(Vector3(0,.05,-30),Vector3(-8,2,-39));await capture("night-clearing")
	look(Vector3(36,.05,-26),Vector3(38,1,-35));await capture("sawmill")
	look(Vector3(-42,.05,-73),Vector3(-46,1,-86));await capture("pump")
	look(Vector3(0,.05,-68),Vector3(0,1,-74));await capture("railcart")
	w.monster.position=Vector3(0,.05,-33);w.monster.net_position=w.monster.position;w.monster.rotation.y=PI;w.monster.net_rotation=PI
	w.monster.change_state(w.monster.State.PATROL,Vector3.ZERO)
	look(Vector3(0,.05,-28),Vector3(0,1.5,-33));await capture("forester")
	p.lamp_on=false;await capture("flashlight-off");p.lamp_on=true
	GameManager.interface.open_map();await capture("plan")
	GameManager.interface.close_map()
	look(Vector3(0,.05,-30),Vector3(-8,2,-39))
	await get_tree().create_timer(3).timeout
	var start: int=Time.get_ticks_usec();var calls: float=0
	for i: int in range(120):
		await get_tree().process_frame;calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("FOREST_PERF fps=",120000000.0/(Time.get_ticks_usec()-start)," draws=",calls/120," high scale=.75 1152x648")
	print("FOREST_UI_PASS");get_tree().quit()

