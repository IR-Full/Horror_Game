extends Node
var failures: int=0
func _ready() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	if ok: print("HORROR_CHECK "+label)
	else: failures+=1; push_error("HORROR_FAIL "+label)
func frames() -> void:
	await get_tree().physics_frame; await get_tree().physics_frame
func aim(actor: Node3D,point: Vector3) -> void:
	var direction: Vector3=(point-actor.eye_position()).normalized()
	actor.local_aim=Vector2(atan2(-direction.x,-direction.z),asin(direction.y)); actor.aim=actor.local_aim
func face_down(monster: Node3D) -> bool:
	var skel: Skeleton3D=monster.mesh.find_children("*","Skeleton3D",true,false)[0]
	var head: int=skel.find_bone("Head")
	var original: Vector3=skel.get_bone_global_rest(head).basis.inverse()*Vector3.FORWARD
	var facing: Vector3=(skel.get_bone_global_pose(head).basis*original).normalized()
	print("HORROR_FACE ",facing," head=",skel.get_bone_global_pose(head).origin)
	return facing.y<-.55 and skel.get_bone_global_pose(head).origin.y<.65
func run() -> void:
	var bank: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/bank.json"))
	check(bank.speech.actor=="Tim Rockk" and not bank.speech.synthesized and bank.speech.captions_ru.size()==18,"downloaded human actor replaces synthesized speech with eighteen translated takes")
	var voice_sources: Array=[]
	for clip: Dictionary in bank.clips:
		if str(clip.file).begins_with("monster_voice_"): voice_sources.append_array(clip.sources)
	check(voice_sources.size()==18 and str(voice_sources[0]).begins_with("timrockk_"),"active monster speech uses attributed recording sources")
	for map_id: int in range(3):
		NetworkManager.host_room("Horror QA",27991); NetworkManager.choose_role(2); NetworkManager.choose_map(map_id); NetworkManager.start_round(true)
		await get_tree().create_timer(.5).timeout
		var world: Node3D=GameManager.world; var actor: Node3D=GameManager.local_player(); var m: Node3D=world.monster
		actor.input_enabled=false; m.set_physics_process(false)
		actor.position=Vector3(0,.05,-23); actor.net_position=actor.position
		m.position=Vector3(0,.05,-30); m.net_position=m.position; m.rotation.y=PI; m.net_rotation=PI
		m.change_state(m.State.PATROL,Vector3.ZERO); m.velocity=Vector3(0,0,3.4)
		aim(actor,m.position+Vector3.UP*1.4); await frames()
		world.monster_speech(m.eye_position(),0)
		check(GameManager.interface.monster_caption.text.contains(str(AudioManager.speech_captions[0])),"nearby actor line has its matching Russian caption on map "+str(map_id))
		var start: Vector3=m.position
		actor.apply_action("shoot",0); m.set_physics_process(true)
		check(m.state==m.State.STUNNED and m.hit_serial==1,"real shotgun hit starts the fall on map "+str(map_id))
		m.neutralize(); check(m.hit_serial==1,"another hit cannot reset a currently neutralized monster")
		await get_tree().create_timer(.7).timeout
		check(m.position.distance_to(start)>.15 and actor.health==100,"wounded monster stumbles forward without attacking")
		await get_tree().create_timer(2.2).timeout
		check(m.visual_mode=="Down" and face_down(m),"articulated fall ends on the stomach on map "+str(map_id))
		check(m.wounds.pools.size()==1 and m.wounds.pools[0].visible,"a wound pool appears only after the landing")
		var pool: Node3D=m.wounds.pools[0]; var anchor: Vector3=pool.global_position
		var first: float=m.wounds.records[0].spread
		m.wounds.records[0].born-=16000; await frames()
		check(float(m.wounds.records[0].spread)>first+.3 and world.is_bloody(anchor),"blood grows gradually and transfers to footwear")
		m.stunned_left=.02; await get_tree().create_timer(2.6).timeout
		check(m.state!=m.State.STUNNED and m.recovery_left<=0 and pool.visible,"monster pushes up from prone while leaving blood behind")
		m.set_physics_process(false); m.position=Vector3(2.35 if map_id==0 else 3.4,.05,-30); m.net_position=m.position
		m.crawl_amount=1; m.change_state(m.State.CHASE,actor.position); m.rotation.y=PI; m.net_rotation=PI
		await get_tree().create_timer(.75).timeout
		m.velocity=Vector3(0,0,3.4); aim(actor,m.position+Vector3.UP*.6); await frames()
		var wall_x: float=m.position.x
		actor.apply_action("shoot",0); m.set_physics_process(true)
		check(m.fell_crawling and m.hit_serial==2,"quadruped chase has its own wounded collapse")
		await get_tree().create_timer(2.2).timeout
		check(face_down(m) and m.position.x<wall_x-.12,"collapse finds floor clearance beside a wall")
		check(m.wounds.pools.size()==2 and pool.global_position.distance_to(anchor)<.01,"separate neutralizations keep separate fixed wound pools")
		if map_id==2:
			var dressing: Node=world.atmosphere.get_node("HospitalDressing")
			check(dressing.pool_count>=84 and dressing.message_count>=16,"hospital has additional drag trails, handprints, blood writing and shrouded tables")
		NetworkManager.leave(); await frames()
	print("HORROR_PASS" if failures==0 else "HORROR_FAIL %d" % failures); get_tree().quit(0 if failures==0 else 1)
