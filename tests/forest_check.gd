extends Node
var world: Node3D
var actor: Node3D
var failures: int = 0
func _ready() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> bool:
	if ok: print("FOREST_CHECK "+label)
	else: failures += 1; push_error("FOREST_FAIL "+label)
	return ok
func frames() -> void:
	await get_tree().physics_frame; await get_tree().physics_frame
func place(at: Vector3,target: Vector3) -> void:
	actor.position=at; actor.net_position=at; actor.velocity=Vector3.ZERO
	var direction: Vector3 = (target-actor.eye_position()).normalized()
	actor.local_aim=Vector2(atan2(-direction.x,-direction.z),asin(direction.y)); actor.aim=actor.local_aim
func approach(object: Node3D) -> void:
	place(Vector3(object.position.x,.05,object.position.z+1.7),object.position); await frames()
	check(world.target_for(actor)==object,"real interaction ray reaches "+object.object_id+" at "+str(object.position)+" hit "+str(world.target_for(actor)))
func pickup(id: String) -> void:
	var item: Node3D=world.objects[id]
	if not item.container_id.is_empty():
		var box: Node3D=world.objects[item.container_id]
		if not box.opened:
			await approach(box)
			if box.kind=="safe": world.unlock_safe(box.object_id,box.code)
			else: world.interact_object(actor,box)
		await frames()
	await approach(item); world.interact_object(actor,item)
	check(item.kind in actor.inventory,"retrieve "+id)
func hold(id: String,seconds: float) -> void:
	await approach(world.objects[id]); actor.input_enabled=true; Input.action_press("interact")
	await get_tree().create_timer(seconds).timeout
	Input.action_release("interact"); actor.input_enabled=false; await frames()
func press(id: String) -> void:
	await approach(world.objects[id]); world.interact_object(actor,world.objects[id]); await frames()
func solve_forest() -> void:
	var o: Node=world.objectives
	await hold("rail_cart",.25);check(o.escape_time<0,"unprepared cart cannot skip the forest")
	await pickup("forest_fuse")
	await pickup("forest_supply_1")
	await hold("generator",3.1);check(o.powered and o.generator_on,"diesel consumes the actual fuse and fuel")
	check(not "fuse" in actor.inventory and not "fuel" in actor.inventory,"power consumes both prerequisites")
	await hold("winch",.25);check(not o.winch_ready,"winch requires the grip sequence")
	await press("log_%d" % ((o.log_solution[0]+1)%4));check(o.log_input.is_empty() and o.control_lock>0,"wrong grip sequence resets and locks the controls")
	o.control_lock=0
	for i: int in o.log_solution:await press("log_%d" % i)
	check(o.log_ready,"four valid physical controls release the grips")
	await hold("winch",4.3);check(o.winch_ready and world.objects.rail_logs.position.x>=8.9,"winch visibly moves the solid obstruction off the rails")
	for i: int in range(3):
		for turn: int in range(o.pressure_solution[i]):await press("pump_%d" % i)
	await hold("ventilation",3.1);check(o.pump_ready,"pressure and held pump interaction unlock diesel")
	await pickup("forest_battery");await hold("rail_cart",1.9)
	await pickup("forest_belt");await hold("rail_cart",1.9)
	await pickup("forest_diesel");await hold("rail_cart",1.9)
	check(o.installed.size()==2 and o.fueled,"cart receives and consumes battery, belt and fuel")
	for i: int in range(3):
		for turn: int in range(o.signal_solution[i]):await press("signal_%d" % i)
	check(o.signals_ready,"randomized railway route is set using real controls")
	await pickup("forest_supply_0");await pickup("forest_ignition")
	check(o.sabotage("ventilation"),"forester can sabotage the pump")
	await hold("ventilation",4.3);check(o.emergency.is_empty() and o.generator_on,"technician repairs a real sabotage without losing task progress")
func _run() -> void:
	NetworkManager.host_room("Forest QA",28011);NetworkManager.choose_map(3);NetworkManager.choose_difficulty(3);NetworkManager.start_round(true)
	await get_tree().create_timer(.6).timeout
	world=GameManager.world;actor=GameManager.local_player();actor.input_enabled=false;world.monster.set_physics_process(false)
	check(world.map_id==3 and world.has_meta("forest_trees") and int(world.get_meta("forest_trees"))>200,"fourth map is a large authored forest with instanced trees")
	check(world.monster.clip_names.size()==11,"forester has upright, crawling, attack, collapse and recovery animation")
	for rect: Rect2 in world.layout.ROOFS:
		var at:=Vector3(rect.get_center().x,0,rect.get_center().y)
		check(not world.find_path(Vector3(0,0,10),at,true).is_empty(),"monster route reaches cabin "+str(at))
		var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*2.6,at+Vector3.UP*4,1)
		check(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"each cabin has a solid roof")
	var open_ray:=PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(0,12,0),1)
	check(world.get_world_3d().direct_space_state.intersect_ray(open_ray).is_empty(),"forest clearing has an intentional open night sky")
	var helper: Node=preload("res://tests/random_check.gd").new();check(helper.valid_clues(world),"all forest clues match the current solution");helper.free()
	# Exhaust every curated storage and floor slot using physical targeting.
	var loot:=preload("res://scripts/world/forest_loot.gd")
	for id: String in loot.CONTAINERS:
		var box: Node3D=world.objects[id];var saved: Vector3=box.position
		for at: Vector3 in loot.CONTAINERS[id]:box.position=at;await approach(box)
		box.position=saved
	var hidden: Dictionary={}
	for id: String in world.objects:
		if world.items.NAMES.has(world.objects[id].kind):hidden[id]=world.objects[id].taken;world.objects[id].taken=true;world.objects[id].refresh()
	var battery: Node3D=world.objects.forest_supply_2;battery.taken=false;var saved_at: Vector3=battery.position;var saved_box: String=battery.container_id
	for i: int in range(16):
		var box: Node3D=world.objects["forest_box_%d" % i];box.opened=true;box.refresh();battery.container_id=box.object_id;battery.position=box.position+Vector3(0,-.4,.1);world.refresh_containers();await world._ground_loose_items();await approach(battery)
	var shell: Node3D=world.objects.shell_0;shell.taken=false;shell.refresh()
	for at: Vector3 in loot.AMMO:
		shell.position=at;await world._ground_loose_items();await approach(shell)
	battery.container_id=saved_box;battery.position=saved_at;world.refresh_containers();await world._ground_loose_items()
	for id: String in hidden:world.objects[id].taken=hidden[id];world.objects[id].refresh()
	for i: int in range(16):world.objects["forest_box_%d" % i].opened=false;world.objects["forest_box_%d" % i].refresh()
	world.refresh_containers()
	# Loss of an interrupted installer's component must release their claim.
	world.objectives.install_owner=actor.peer_id;world.objectives.install_kind="car_battery";world.objectives.install_progress=.1
	world.objectives._tick_cart(.2)
	check(world.objectives.install_owner==0,"dropped component or departed installer cannot deadlock cooperative installation")
	var m: Node3D=world.monster;world.rules.monster=true
	m.position=Vector3(0,.05,-27);m.net_position=m.position;m.change_state(m.State.PATROL,m.position)
	place(Vector3(0,.05,-24),m.eye_position());await frames();m._perceive()
	check(m.state==m.State.CHASE,"forester attacks a nearby flashlight-bearing player instead of retreating")
	m.change_state(m.State.PATROL,m.position);m.hear_noise(Vector3(30,0,-27),25)
	check(m.state==m.State.INVESTIGATE,"forester investigates distant loud machinery")
	world.rules.monster=false;m.change_state(m.State.DORMANT,m.position)
	await solve_forest()
	await hold("rail_cart",8.5);check(world.objectives.escape_time>=0 and actor.in_vehicle,"prepared cart gathers the player and opens the real gate")
	await get_tree().create_timer(8.2).timeout
	check(world.objectives.result.begins_with("Победа") and actor.position.z<-100,"rail departure carries the player to the escape")
	NetworkManager.return_to_lobby();await get_tree().create_timer(.3).timeout
	NetworkManager.choose_map(0);NetworkManager.start_round(true);await get_tree().create_timer(.4).timeout
	check(GameManager.world.map_id==0 and GameManager.world.objects.has("transmitter"),"original station loads after forest")
	print("FOREST_PASS" if failures==0 else "FOREST_FAIL %d" % failures);get_tree().quit(0 if failures==0 else 1)

