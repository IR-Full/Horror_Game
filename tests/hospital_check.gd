extends Node
var world: Node3D
var actor: Node3D
var failures: int = 0
func _ready() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> bool:
	if ok: print("HOSPITAL_CHECK "+label)
	else: failures += 1; push_error("HOSPITAL_FAIL "+label)
	return ok
func frames() -> void:
	await get_tree().physics_frame; await get_tree().physics_frame
func place(at: Vector3,target: Vector3) -> void:
	actor.position=at; actor.net_position=at; actor.velocity=Vector3.ZERO
	var direction: Vector3 = (target-actor.eye_position()).normalized()
	actor.local_aim=Vector2(atan2(-direction.x,-direction.z),asin(direction.y)); actor.aim=actor.local_aim
func approach(object: Node3D) -> void:
	place(Vector3(object.position.x,.05,object.position.z+1.7),object.position); await frames()
	check(world.target_for(actor)==object,"real interaction ray reaches "+object.object_id)
func pickup(id: String) -> void:
	var item: Node3D=world.objects[id]
	if not item.container_id.is_empty():
		var box: Node3D=world.objects[item.container_id]
		await approach(box)
		if box.kind=="safe": world.unlock_safe(box.object_id,box.code)
		elif not box.opened: world.interact_object(actor,box)
		await frames()
	await approach(item); world.interact_object(actor,item)
	check(item.kind in actor.inventory,"retrieve "+id)
func hold(id: String,seconds: float) -> void:
	await approach(world.objects[id]); actor.input_enabled=true; Input.action_press("interact")
	await get_tree().create_timer(seconds).timeout
	Input.action_release("interact"); actor.input_enabled=false; await frames()
func press(id: String) -> void:
	await approach(world.objects[id]); world.interact_object(actor,world.objects[id]); await frames()
func _run() -> void:
	NetworkManager.host_room("Hospital QA",27981); NetworkManager.choose_map(2); NetworkManager.choose_difficulty(3); NetworkManager.start_round(true)
	await get_tree().create_timer(.5).timeout
	world=GameManager.world; actor=GameManager.local_player(); actor.input_enabled=false; world.monster.set_physics_process(false)
	check(world.map_id==2 and world.objects.has("hospital_exit") and not world.objects.has("escape_car"),"third map has its own physical layout and objective")
	var area: float=0
	for rect: Rect2 in world.layout.FLOORS: area+=rect.get_area()
	check(area==11360 and world.layout.map_rooms().size()==24,"hospital has 11360 square metres and 24 rooms")
	check(world.monster.clip_names.size()==11 and world.monster.mesh.find_children("*","Skeleton3D",true,false)[0].get_bone_count()==15,"doctor has all eleven movement, fall and attack clips")
	var dressing: Node=world.atmosphere.get_node("HospitalDressing")
	check(dressing.pool_count>=50 and dressing.message_count>=6,"hospital has authored blood pools, smears and wall messages")
	check(world.lights.size()<16 and world.lights[0].get_meta("hospital_fault",false),"sparse faulty lamps replace normal hospital lighting")
	for at: Vector3 in [Vector3(-18,0,26),Vector3(-41,0,-20),Vector3(41,0,-20),Vector3(-18,0,-85),Vector3(18,0,-85),Vector3(0,0,62)]:
		check(not world.find_path(Vector3(0,0,10),at,true).is_empty(),"navigation reaches hospital destination "+str(at))
	for room: Array in world.layout.map_rooms():
		var center: Vector2=room[0].get_center()
		check(not world.find_path(Vector3(0,0,10),Vector3(center.x,0,center.y),true).is_empty(),"doctor navigation reaches room "+str(room[1]))
	actor.stress=100; actor.lamp_on=false
	actor.condition.server_tick(1)
	check(actor.stress==100 and actor.health==100 and not actor.dead,"zero sanity alone never kills the player")
	actor.stress=0; actor.lamp_on=true
	var prior: Dictionary=NetworkManager.last_hospital_puzzles.duplicate(true)
	world.objectives.randomize_round()
	var changed: bool=true
	for key: String in prior:
		if prior[key]==NetworkManager.last_hospital_puzzles[key]: changed=false
	check(changed,"every hospital code and puzzle differs from the previous round")
	check(world.objects.admission_note.description.contains(world.objects.hospital_fuse_safe.code.left(2)) and world.objects.ward_note.description.contains(world.objects.hospital_fuse_safe.code.right(2)) and world.objects.laboratory_note.description.contains(world.objects.morgue_safe.code),"randomized safe codes agree with in-world journals")
	await approach(world.objects.hospital_fuse_safe); world.unlock_safe("hospital_fuse_safe","0000")
	check(not world.objects.hospital_fuse_safe.opened,"incorrect hospital safe code cannot release the fuse")
	await press("ward_0")
	check(world.objectives.ward_input.is_empty(),"bed calls cannot bypass the power requirement")
	await approach(world.objects.ward_case); world.interact_object(actor,world.objects.ward_case)
	check(not world.objects.ward_case.opened,"sample I stays locked until the bed puzzle is solved")
	await preload("res://tests/hospital_spawn_check.gd").run(self)
	await solve_hospital()
	check(world.objectives.serum_ready and world.objectives.samples.size()==3,"all three puzzle branches unlock the evacuation pass")
	await pickup("hospital_badge")
	world.objectives.sabotage("ventilation"); await hold("hospital_exit",.3)
	check(world.objectives.exit_progress==0,"emergency blocks escape even with a valid pass")
	await hold("ventilation",4.4)
	check(world.objectives.emergency.is_empty(),"technician can repair the doctor's sabotage through actual held interaction")
	await hold("hospital_exit",8.4)
	check(world.objectives.result.begins_with("Победа"),"full physical hospital quest ends in evacuation")
	NetworkManager.return_to_lobby(); await get_tree().create_timer(.3).timeout
	NetworkManager.choose_map(1); NetworkManager.start_round(true); await get_tree().create_timer(.4).timeout
	check(GameManager.world.map_id==1 and GameManager.world.objects.has("escape_car"),"depot remains available after the hospital")
	NetworkManager.leave(); await frames()
	print("HOSPITAL_PASS" if failures==0 else "HOSPITAL_FAIL %d" % failures); get_tree().quit(0 if failures==0 else 1)
func solve_hospital() -> void:
	await pickup("fuse")
	await hold("generator",3.1)
	check(world.objectives.generator_on,"fuse restores hospital power with a held repair")
	var wrong: int=(int(world.objectives.ward_solution[0])+1)%4
	await press("ward_%d" % wrong)
	check(world.objectives.ward_input.is_empty() and world.objectives.ward_lock>0,"wrong bed sequence resets and triggers a noisy lockout")
	await get_tree().create_timer(4.2).timeout
	for index: int in world.objectives.ward_solution: await press("ward_%d" % index)
	check(world.objectives.ward_ready,"correct randomized bed calls unlock sample I")
	await pickup("specimen_a")
	await pickup("hospital_supply_0")
	await pickup("scalpel")
	for i: int in range(3):
		for turn: int in range(world.objectives.pressure_solution[i]): await press("pressure_%d" % i)
	await hold("sterilizer",4.4)
	check(world.objectives.surgery_ready and not "scalpel" in actor.inventory,"autoclave consumes scalpel and unlocks sample II")
	world.items.drop(actor,actor.inventory.find("hospital_key"))
	await pickup("specimen_b"); await pickup("specimen_c")
	for i: int in range(3):
		for turn: int in range(world.objectives.mixture_solution[i]): await press("mixture_%d" % i)
	await hold("analyzer",12.7)
