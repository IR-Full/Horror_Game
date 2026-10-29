extends Node
func _ready() -> void:run.call_deferred()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-results/"+name)
func look(at: Vector3,target: Vector3) -> void:
	var actor: Node3D=GameManager.local_player();actor.position=at;actor.net_position=at;actor.velocity=Vector3.ZERO
	var direction: Vector3=(target-actor.eye_position()).normalized()
	actor.local_aim=Vector2(atan2(-direction.x,-direction.z),asin(direction.y));actor.aim=actor.local_aim
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED);DisplayServer.window_set_size(Vector2i(1152,648))
	var fx: int=AudioServer.get_bus_index("Effects");AudioServer.set_bus_mute(fx,true)
	NetworkManager.host_room("Охотник",27992);NetworkManager.choose_role(2);NetworkManager.choose_map(2);NetworkManager.start_round(true)
	await get_tree().create_timer(.7).timeout
	var w: Node3D=GameManager.world;var m: Node3D=w.monster;var actor: Node3D=GameManager.local_player();actor.input_enabled=false;m.set_physics_process(false)
	SettingsManager.quality=2;SettingsManager.resolution_scale=.75;SettingsManager.apply()
	m.position=Vector3(41,.05,-31);m.net_position=m.position;m.rotation.y=PI;m.net_rotation=PI;m.velocity=Vector3(0,0,3.4);m.change_state(m.State.PATROL,Vector3.ZERO)
	look(Vector3(41,.05,-24),m.position+Vector3.UP*1.4)
	await get_tree().create_timer(.4).timeout
	var capture:=AudioEffectCapture.new();capture.buffer_length=1;AudioServer.add_bus_effect(fx,capture)
	w.monster_speech(m.eye_position(),0);await get_tree().create_timer(.8).timeout
	var samples: PackedVector2Array=capture.get_buffer(capture.get_frames_available());var peak: float=0
	for frame: Vector2 in samples:peak=maxf(peak,absf(frame.x))
	print("ACTOR_AUDIO_PASS ",peak) if peak>.005 else push_error("ACTOR_AUDIO_FAIL silent actor playback")
	AudioServer.remove_bus_effect(fx,AudioServer.get_bus_effect_count(fx)-1)
	await shot("v12_caption.png")
	actor.apply_action("shoot",0);m.set_physics_process(true)
	await get_tree().create_timer(.55).timeout;await shot("v12_stumble.png")
	await get_tree().create_timer(.9).timeout;await shot("v12_brace.png")
	await get_tree().create_timer(1.4).timeout;await shot("v12_prone.png")
	look(Vector3(41,.05,-26),m.blood_anchor)
	m.wounds.records.back().born-=30000;await get_tree().create_timer(.3).timeout;await shot("v12_bleeding.png")
	m.stunned_left=.02;await get_tree().create_timer(1.1).timeout;await shot("v12_rising.png")
	await get_tree().create_timer(1.5).timeout;m.set_physics_process(false);m.change_state(m.State.DORMANT,Vector3.ZERO)
	look(Vector3(54,.05,-19),Vector3(54,1.2,-24));await get_tree().create_timer(.5).timeout;await shot("v12_theatre.png")
	look(Vector3(58,.05,-32),Vector3(61.9,1.3,-36));await get_tree().create_timer(.4).timeout;await shot("v12_curtain.png")
	NetworkManager.leave();AudioServer.set_bus_mute(fx,false);print("HORROR_UI_PASS");get_tree().quit()
