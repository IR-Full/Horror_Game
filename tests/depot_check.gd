extends Node
var failures: int = 0
var world: Node3D
var actor: Node3D
func _ready() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> bool:
	if ok: print("DEPOT_CHECK "+label)
	else: failures += 1; push_error("DEPOT_FAIL "+label)
	return ok
func frames() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
func place(at: Vector3,target: Vector3) -> void:
	actor.position = at; actor.net_position = at; actor.velocity = Vector3.ZERO
	var direction: Vector3 = (target-actor.eye_position()).normalized()
	actor.local_aim = Vector2(atan2(-direction.x,-direction.z),asin(direction.y))
	actor.aim = actor.local_aim
func pickup(kind: String) -> void:
	var item: Node3D = world.objects[kind]
	var box: Node3D = world.objects[item.container_id]
	place(Vector3(box.position.x,.05,box.position.z+1.7),box.position)
	await frames()
	if not box.opened:
		if box.kind == "safe": world.unlock_safe(box.object_id,box.code)
		else: world.interact_object(actor,box)
	await frames()
	place(Vector3(box.position.x,.05,box.position.z+1.7),item.position)
	await frames()
	check(world.target_for(actor) == item,"real pickup ray reaches "+kind)
	world.interact_object(actor,item)
	check(kind in actor.inventory,"retrieve locked or stored component "+kind)
func install_until(count: int) -> void:
	place(Vector3(-2,.05,23),world.objects.escape_car.position)
	await frames()
	check(world.target_for(actor) == world.objects.escape_car,"vehicle interaction is reachable")
	actor.input_enabled = true
	Input.action_press("interact")
	var deadline: int = Time.get_ticks_msec()+12000
	while world.objectives.installed.size() < count and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	Input.action_release("interact"); actor.input_enabled = false
	await get_tree().create_timer(.12).timeout
	check(world.objectives.installed.size() >= count,"held repair installs inventory components: "+str(count))

func _run() -> void:
	NetworkManager.host_room("Depot QA",27971)
	NetworkManager.choose_map(1)
	NetworkManager.choose_difficulty(3)
	NetworkManager.start_round(true)
	await get_tree().create_timer(.5).timeout
	world = GameManager.world; actor = GameManager.local_player()
	actor.input_enabled = false
	world.monster.set_physics_process(false)
	check(world.map_id == 1 and world.layout == NetworkManager.MAPS.layout(1),"selected solo map is used to build the world")
	check(world.objects.has("escape_car") and not world.objects.has("transmitter"),"depot has its own objectives and geometry")
	var area: float = 0
	for rect: Rect2 in world.layout.FLOORS: area += rect.get_area()
	check(area == 8804 and world.layout.EXTENT == world.LAYOUT.EXTENT,"second map keeps the full 126 by 172 metre footprint")
	check(NetworkManager.MAPS.monster_model(1) != NetworkManager.MAPS.monster_model(0),"second map uses a different monster model")
	for at: Vector3 in [Vector3(-56,0,-57),Vector3(55,0,-57),Vector3(17,0,-97),Vector3(-11,0,42),Vector3(11,0,62)]:
		check(not world.find_path(Vector3(0,0,10),at,true).is_empty(),"physical route exists to sector destination "+str(at))
	var c: Node = actor.condition
	actor.set_physics_process(false)
	actor.stress = 20; actor.lamp_on = false
	place(Vector3(0,.05,0),Vector3(0,1,-2))
	c.server_tick(5)
	check(actor.stress > 20,"darkness and isolation raise stress on the server")
	place(Vector3(12,.05,9),Vector3(12,1,7)); actor.lamp_on = true
	var stressed: float = actor.stress
	c.server_tick(5)
	check(actor.stress < stressed,"illuminated rest zone lowers stress")
	actor.inventory = PackedStringArray(["sedative","thermos"]); actor.stress = 90; actor.stamina = 20; actor.calm_cooldown = 0
	world.items.use(actor,0)
	check(actor.stress == 55 and actor.inventory.size() == 1,"calming item restores sanity and is consumed")
	world.items.use(actor,0)
	check(actor.inventory.size() == 1,"server blocks repeated calming items during cooldown")
	actor.calm_cooldown = 0; world.items.use(actor,0)
	check(actor.stress == 35 and actor.stamina == 40,"tea restores some sanity and stamina")
	check(c.breath_level(80,0) < c.breath_level(50,0) and c.breath_level(50,0) < c.breath_level(25,0) and c.breath_level(25,0) < c.breath_level(10,0),"four exertion ranges produce increasing breathing intensity")
	check(actor.motion.skeleton != null and actor.motion.bones.size() >= 16,"player has an articulated human skeleton")
	check(not actor.body_mesh.find_child("Chest panel",true,false).visible and actor.body_mesh.find_child("Leg_Thigh_L",true,false).visible,"local torso does not obstruct the visible legs")
	print("DEPOT_BONES ",actor.motion.bones)
	actor.motion_speed = 4.5; actor.running_motion = true; actor.motion._process(.2)
	check(actor.motion.skeleton.get_bone_global_pose(actor.motion.bones.Head).origin.y > 1.3,"gait preserves the rig's original height and bone transforms")
	if actor.motion.bones.has("Thigh_L") and actor.motion.bones.has("Thigh_R"):
		check(actor.motion.skeleton.get_bone_pose_rotation(actor.motion.bones.Thigh_L).angle_to(actor.motion.skeleton.get_bone_pose_rotation(actor.motion.bones.Thigh_R)) > .1,"run gait moves legs in opposite phases")
	else: check(false,"human rig exposes both leg bones")
	actor.motion_speed = 0; actor.running_motion = false; actor.stress = 0; actor.set_physics_process(true)
	await preload("res://tests/depot_spawn_check.gd").run(self)
	await collect_and_assemble()
	world.objectives.sabotage("generator")
	check(not world.objectives.emergency.is_empty(),"depot monster has a map-specific sabotage emergency")
	place(Vector3(-12,.05,19),world.objects.generator.position); await frames()
	actor.input_enabled = true; Input.action_press("interact")
	await get_tree().create_timer(6.4).timeout
	Input.action_release("interact"); actor.input_enabled = false
	check(world.objectives.emergency.is_empty(),"held emergency repair prevents the fuel explosion")
	place(Vector3(-2,.05,23),world.objects.escape_car.position); await frames()
	actor.input_enabled = true; Input.action_press("interact")
	await get_tree().create_timer(4.4).timeout
	Input.action_release("interact")
	check(actor.in_vehicle and world.objectives.escape_time >= 0,"assembled vehicle starts and boards the lone survivor")
	await get_tree().create_timer(4.2).timeout
	check(world.objectives.result.begins_with("Победа") and world.objects.escape_car.position.z > 40,"departure moves the car and ends in victory")
	NetworkManager.leave()
	await frames()
	NetworkManager.host_room("Station QA",27971); NetworkManager.choose_map(0); NetworkManager.start_round(true)
	await get_tree().create_timer(.4).timeout
	check(GameManager.world.map_id == 0 and GameManager.world.objects.has("transmitter"),"original station remains available after switching maps")
	NetworkManager.leave(); await get_tree().process_frame
	print("DEPOT_PASS" if failures == 0 else "DEPOT_FAIL %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func collect_and_assemble() -> void:
	var cage: Node3D = world.objects.battery_cage
	place(Vector3(cage.position.x,.05,cage.position.z+1.7),cage.position); await frames()
	world.interact_object(actor,cage)
	check(not cage.opened,"fuel cage cannot be opened without the guard key")
	await pickup("yard_key")
	await pickup("car_key")
	await pickup("car_battery")
	world.items.drop(actor,actor.inventory.find("yard_key"))
	await pickup("fuel")
	await install_until(3)
	var safe: Node3D = world.objects.parts_safe
	place(Vector3(safe.position.x,.05,safe.position.z+1.7),safe.position); await frames()
	world.unlock_safe("parts_safe","0000")
	check(not safe.opened,"wrong four-digit safe code keeps plugs locked")
	check(world.objects.depot_note_a.description.contains(safe.code.left(2)) and world.objects.depot_note_b.description.contains(safe.code.right(2)),"two clues agree with the randomized safe code")
	await pickup("spark_plugs")
	await pickup("wheel")
	for i: int in range(3):
		var dial: Node3D = world.objects["depot_dial_%d" % i]
		place(Vector3(dial.position.x,.05,dial.position.z+1.7),dial.position); await frames()
		for turn: int in range(world.objectives.circuit_solution[i]): world.interact_object(actor,dial)
	check(world.objectives.circuit_ready and not world.objects.belt_locker.locked,"wiring puzzle unlocks the northern part store")
	await pickup("drive_belt")
	await install_until(6)
