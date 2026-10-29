extends Node
func _ready() -> void:run.call_deferred()
func look(at: Vector3,target: Vector3) -> void:
	var p: Node3D=GameManager.local_player();p.position=at;p.net_position=at;p.velocity=Vector3.ZERO
	var direction: Vector3=(target-p.eye_position()).normalized()
	p.local_aim=Vector2(atan2(-direction.x,-direction.z),asin(direction.y));p.aim=p.local_aim
func capture(name: String) -> void:
	await get_tree().create_timer(.6).timeout;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-results/"+name+".png")
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1152,648))
	for id: int in range(3):
		NetworkManager.host_room("Проверка карты",27989);NetworkManager.choose_role(2);NetworkManager.choose_map(id);NetworkManager.start_round(true)
		await get_tree().create_timer(.7).timeout
		SettingsManager.quality=2;SettingsManager.resolution_scale=.75;SettingsManager.apply()
		var w: Node3D=GameManager.world;w.monster.set_physics_process(false)
		var p: Node3D=GameManager.local_player();p.input_enabled=false
		await get_tree().create_timer(3).timeout
		if id==0:
			look(Vector3(9,.05,-6),Vector3(11,1,-10.3));await capture("v13-radio-furniture")
			look(Vector3(11,.05,-32),Vector3(12,1,-35.6));await capture("v13-relay-note-supported")
		elif id==1:
			look(Vector3(.4,.05,26),Vector3(.75,1.5,30));await capture("v13-depot-gate-closed")
			w.objects.exit_gate.opened=true;w.objects.exit_gate.refresh();w._update_doors_navigation()
			await get_tree().create_timer(1.3).timeout;await capture("v13-depot-gate-open")
			look(Vector3(0,.05,-56),Vector3(0,3.3,-60));await capture("v13-depot-roof")
			look(Vector3(0,.05,-84),Vector3(-10,2,-91));await capture("v13-depot-north-hangar")
		else:
			look(Vector3(0,.05,60),Vector3(0,.65,64));await capture("v13-hospital-console-grounded")
			look(Vector3(54,.05,-19),Vector3(54,1.1,-24));await capture("v13-hospital-furniture")
			var runner: Node3D=w._create_player({"id":2,"nickname":"Проверка бега","role":"medic","position":Vector3(0,.05,-31)})
			w.players.add_child(runner);runner.set_physics_process(false);runner.input_enabled=false
			runner.motion_speed=5;runner.running_motion=true;runner.motion.set_process(false)
			look(Vector3(3,.05,-30),Vector3(0,1,-31))
			for phase: float in [PI/2,PI*1.5]:
				runner.motion.phase=phase;runner.motion.blend=1;runner.motion._process(.001)
				await capture("v13-run-phase-"+str(int(phase)))
		NetworkManager.leave();await get_tree().process_frame;await get_tree().process_frame
	print("MAP_FINISH_UI_PASS");get_tree().quit()
