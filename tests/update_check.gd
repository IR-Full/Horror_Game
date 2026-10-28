extends Node
var failures: int = 0

func _ready() -> void: _run.call_deferred()
func check(ok: bool, title: String) -> void:
	if ok: print("UPDATE_CHECK "+title)
	else: failures += 1; push_error("UPDATE_FAIL "+title)
func delay(seconds: float) -> void: await get_tree().create_timer(seconds).timeout

func round_at(level: int) -> void:
	if NetworkManager.in_match:
		NetworkManager.return_to_lobby()
		while NetworkManager.unloading: await get_tree().process_frame
		await delay(.15)
	NetworkManager.choose_difficulty(level)
	NetworkManager.choose_role(2)
	NetworkManager.start_round(true)
	await delay(.3)
	GameManager.world.monster.set_physics_process(false)
	GameManager.local_player().input_enabled = false

func _run() -> void:
	NetworkManager.host_room("Update QA",27951)
	await round_at(0)
	var w: Node3D = GameManager.world
	var p: Node3D = GameManager.local_player()
	check(NetworkManager.difficulty == 0,"lobby difficulty reaches the created world")
	var count: int = 0
	for object: Node3D in w.objects.values():
		if object.kind == "shell" and not object.taken: count += 1
		if object.kind in ["battery","shell"]: check(object.collision_layer == 16,"supply is targetable without blocking movement: "+object.object_id)
	check(count == 6 and p.loaded_shells == 2,"easy has six spare shells and two loaded chambers")
	var previous: Dictionary = NetworkManager.last_puzzles.duplicate(true)
	check(w.objects.safe_note.description.contains(w.objects.fuse_safe.code),"safe clue matches the current randomized combination")
	check(w.objects.battery_a.position.y > 1.1,"med-bay battery is on the table")
	p.position = Vector3(7.8,.05,10)
	p.net_position = p.position
	var direction: Vector3 = (w.objects.battery_a.position-p.eye_position()).normalized()
	p.aim = Vector2(atan2(-direction.x,-direction.z),asin(direction.y))
	p.local_aim = p.aim
	await get_tree().physics_frame
	check(w.target_for(p) == w.objects.battery_a,"med-bay battery is reachable by an unobstructed interaction ray")
	for z: float in [-13.5,-50.5]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(2,1.5,z),Vector3(4,1.5,z),1)
		check(not w.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"northern wall closes former vertical gap at "+str(z))
	var ceiling_ray := PhysicsRayQueryParameters3D.create(Vector3(2,3.25,-5),Vector3(4,3.25,-5),1)
	check(not w.get_world_3d().direct_space_state.intersect_ray(ceiling_ray).is_empty(),"wall meets ceiling without a bright open seam")
	var batches: int = 0
	for node: Node in w.get_children():
		if node.has_meta("architecture_batch"): batches += 1
	check(batches > 0 and batches < 80,"architecture is grouped into bounded batches")
	var press := InputEventAction.new()
	press.action = "map"; press.pressed = true
	GameManager.interface._input(press)
	check(is_instance_valid(GameManager.interface.map_overlay) and not GameManager.interface.paused,"holding map keeps movement and the round active")
	var release := InputEventAction.new()
	release.action = "map"; release.pressed = false
	GameManager.interface._input(release)
	check(not is_instance_valid(GameManager.interface.map_overlay),"releasing M removes the map")
	p.inventory = PackedStringArray(["battery","medkit","fuse","key"])
	p.input_enabled = true
	for i: int in range(4):
		var event := InputEventAction.new()
		event.action = "slot_%d" % (i+1); event.pressed = true
		p._unhandled_input(event)
		check(p.selected_slot == i,"direct inventory slot "+str(i+1))
	p.input_enabled = false
	p.set_physics_process(false)
	p.position = Vector3(0,.05,10)
	for i: int in range(24):
		p.accept_input(Vector2(0,-1),Vector2.ZERO,true,false,false)
		p._server_tick(.25)
	check(p.stamina < 1 and p.exhausted,"continuous sprint exhausts server-owned stamina")
	for i: int in range(24):
		p.accept_input(Vector2.ZERO,Vector2.ZERO,false,false,false)
		p._server_tick(.25)
	check(p.stamina > 28 and not p.exhausted,"rest restores stamina and clears exhaustion")
	p.set_physics_process(true)
	p.position = Vector3(0,.05,8); p.net_position = p.position
	p.loaded_shells = 2; p.shot_cooldown = 0
	p._fire_shotgun()
	check(p.loaded_shells == 1 and p.shot_cooldown > 0,"first barrel leaves the second chamber loaded")
	p._fire_shotgun()
	check(p.loaded_shells == 1,"shot cooldown prevents duplicate firing")
	await delay(.7)
	p._fire_shotgun()
	check(p.loaded_shells == 0,"second barrel consumes the second shell")
	p.reserve_shells = 2; p.action_cooldown = 0
	p.apply_action("reload",0)
	await delay(2.15)
	check(p.loaded_shells == 2 and p.reserve_shells == 0,"reload fills both empty chambers")
	var monster: Node3D = w.monster
	monster.position = Vector3(0,.05,-6); monster.state = monster.State.PATROL
	p.position = Vector3(0,.05,0); p.net_position = p.position; p.noise_clock = 0
	p.accept_input(Vector2(0,-1),Vector2.ZERO,false,false,false)
	p._server_tick(.02)
	check(monster.state == monster.State.INVESTIGATE,"an actual walking step attracts the monster")
	w.objects.battery_b.position = Vector3(0,.2,3)
	w.objects.shell_0.position = Vector3(0,.1,4)
	monster.position = Vector3(0,.05,6); monster.net_position = monster.position
	p.position = Vector3(0,.05,0); p.net_position = p.position; p.lamp_on = false; p.invulnerable = 100
	monster.target_id = p.peer_id; monster.gesture_left = 0; monster.rage_clock = 100
	monster.change_state(monster.State.CHASE,p.position)
	monster.set_physics_process(true)
	await delay(2.5)
	check(monster.position.z < 2.5,"chase crosses batteries and shells without sticking")
	monster.set_physics_process(false)
	var injured: Node3D = w.PLAYER_SCENE.instantiate()
	injured.name = "9002"; injured.peer_id = 9002
	injured.position = Vector3(1,.05,1); injured.net_position = injured.position
	w.players.add_child(injured)
	injured.health = 0
	w._revive_target(p,injured,1.0)
	check(p.healing_progress > .1 and injured.rescue_progress > .1,"helper and wounded receive treatment progress")
	injured.apply_action("sos",0)
	check(injured.sos_left > 10,"SOS exposes a timed position marker")
	p.health = 0
	w.objectives.tick(.01)
	check(w.objectives.result.begins_with("Все"),"all wounded immediately ends the round in defeat")
	await round_at(2)
	w = GameManager.world; p = GameManager.local_player(); monster = w.monster
	count = 0
	for object: Node3D in w.objects.values():
		if object.kind == "shell" and not object.taken: count += 1
	check(count == 2 and float(w.rules.chase_speed) > 4.5 and float(w.rules.sabotage_delay) < 35,"hard reduces ammunition and increases pursuit and sabotage pressure")
	for key: String in previous:
		check(previous[key] != NetworkManager.last_puzzles[key],"next round changes puzzle "+key)
	monster.state = monster.State.PATROL; monster.lonely_time = 19; monster.sabotage_cooldown = 0; monster.rage_clock = 100; monster.perception_clock = 100
	monster._physics_process(.01)
	check(monster.state == monster.State.SABOTAGE,"hard starts sabotage after the shorter unseen interval")
	await round_at(3)
	w = GameManager.world
	w.elapsed = 100
	w.monster._physics_process(.2)
	check(not w.monster.visible and w.monster.collision_layer == 0 and w.monster.state == 0,"no-monster mode has no visible or colliding threat")
	NetworkManager.leave()
	await get_tree().process_frame
	print("UPDATE_PASS" if failures == 0 else "UPDATE_FAIL %d checks" % failures)
	get_tree().quit(0 if failures == 0 else 1)
