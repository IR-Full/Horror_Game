extends Node
const LOOT := preload("res://scripts/world/loot_spawns.gd")
var failures: int = 0
func _ready() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	if ok: print("EXPANSION_CHECK "+label)
	else: failures += 1; push_error("EXPANSION_FAIL "+label)
func place(actor: Node3D, at: Vector3, target: Vector3) -> void:
	actor.position = at; actor.net_position = at; actor.velocity = Vector3.ZERO
	var direction: Vector3 = (target-actor.eye_position()).normalized()
	actor.local_aim = Vector2(atan2(-direction.x,-direction.z),asin(direction.y))
	actor.aim = actor.local_aim
func frames() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame

func reachable_from_floor(world: Node3D, actor: Node3D, item: Node3D) -> bool:
	for offset: Vector3 in [Vector3(0,0,1.5),Vector3(0,0,-1.5),Vector3(1.5,0,0),Vector3(-1.5,0,0)]:
		place(actor,Vector3(item.position.x,.05,item.position.z)+offset,item.position)
		await frames()
		if world.target_for(actor) == item: return true
	return false

func _run() -> void:
	NetworkManager.host_room("Expansion QA",27959)
	NetworkManager.start_round(true)
	await get_tree().create_timer(.4).timeout
	var w: Node3D = GameManager.world
	var p: Node3D = GameManager.local_player()
	w.monster.set_physics_process(false)
	p.input_enabled = false
	var floor_area: float = 0
	for rect: Rect2 in w.LAYOUT.FLOORS: floor_area += rect.get_area()
	check(floor_area == 8820,"five-sector floor area grows to 8820 square metres")
	for side: float in [-1,1]:
		for z: float in [32,46,60]:
			check(w.find_path(Vector3(0,0,10),Vector3(side*10,0,z),true).size()>20,"southern room has a walkable route: "+str(Vector2(side*10,z)))
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0,1.5,12),Vector3(0,1.5,26),1)
	check(w.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"south bridge is physically open")
	ray = PhysicsRayQueryParameters3D.create(Vector3(8,1.5,66),Vector3(8,1.5,69),1)
	check(not w.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"southern outer wall closes the expanded floor")
	# Former scenery cupboards must work even without any linked contents.
	for id: String in ["archive_empty_7","archive_empty_10","archive_empty_13","medical_empty_locker"]:
		var object: Node3D = w.objects[id]
		var at: Vector3 = object.to_global(Vector3(0,0,1.7)); at.y = .05
		place(p,at,object.position)
		await frames()
		w.interact_object(p,object)
		check(object.opened,"empty cupboard opens: "+id)
		await frames()
		w.interact_object(p,object)
		check(not object.opened,"empty cupboard closes: "+id)
	var d: Node = w.drainage
	var button: Node3D = w.objects["drain_switch_%d" % int(d.order[0])]
	place(p,Vector3(button.position.x,.05,button.position.z+1.7),button.position)
	await frames()
	w.interact_object(p,button)
	check(d.entered == 0,"pump circuit cannot bypass missing generator power")
	w.objectives.generator_on = true
	button = w.objects["drain_switch_%d" % ((int(d.order[0])+1)%4)]
	place(p,Vector3(button.position.x,.05,button.position.z+1.7),button.position)
	await frames()
	w.interact_object(p,button)
	check(d.entered == 0 and d.tripped > 3,"incorrect sequence trips protection and resets the puzzle")
	d.tripped = 0
	check(w.objects.drain_reward.locked and not d.drained,"emergency supplies stay gated until drainage completes")
	for index: int in d.order:
		button = w.objects["drain_switch_%d" % index]
		place(p,Vector3(button.position.x,.05,button.position.z+1.7),button.position)
		await frames()
		check(w.target_for(p) == button,"validated ray reaches contactor "+str(index))
		w.interact_object(p,button)
	check(d.circuit_on and d.entered == 4,"documented random order restores the start circuit")
	place(p,Vector3(10,.05,49),Vector3(10,1,46))
	p.invulnerable = 0
	var health: float = p.health
	d.hazard_clock = 0
	d.tick(.01)
	check(p.health == health-7,"powered flooded machine hall damages a living player")
	place(p,Vector3(3.5,.05,46),w.objects.drain_pump.position)
	await frames()
	check(w.target_for(p) == w.objects.drain_pump,"pump can be reached from the dry doorway")
	p.input_enabled = true
	Input.action_press("interact")
	await get_tree().create_timer(5.9).timeout
	Input.action_release("interact")
	p.input_enabled = false
	check(d.drained and d.progress >= 8 and not w.objects.drain_reward.locked,"actual held interaction drains water and unlocks supplies")
	check(not d.water.visible,"drained water is removed on the presentation side")
	var saved: Dictionary = d.snapshot()
	d.drained = false
	d.apply_snapshot(saved)
	check(d.drained and d.circuit_on,"drainage progress and completion survive state replication")
	# Every authored container slot must expose its contents to a real pickup ray.
	for id: String in LOOT.CONTAINERS:
		var object: Node3D = w.objects[id]
		for at: Vector3 in LOOT.CONTAINERS[id]:
			var shift: Vector3 = at-object.position
			object.position = at
			for item: Node3D in w.objects.values():
				if item.container_id == id: item.position += shift
			object.opened = true; object.refresh(); w.refresh_containers()
			await frames()
			for item: Node3D in w.objects.values():
				if item.container_id != id: continue
				place(p,Vector3(at.x,.05,at.z+1.65),item.position)
				await frames()
				check(w.target_for(p) == item,"reachable contents at candidate "+id+" "+str(at))
	var prior: Dictionary = {}
	# Probe one curated slot at a time without another randomly placed pickup
	# occupying the exact probe location. Solid furniture remains in place.
	var hidden_pickups: Dictionary = {}
	for object: Node3D in w.objects.values():
		if object.object_id != "battery_a" and w.items.NAMES.has(object.kind):
			hidden_pickups[object.object_id] = object.taken
			object.taken = true
			object.refresh()
	await frames()
	for at: Vector3 in LOOT.LOOSE+LOOT.AMMO:
		var shape := SphereShape3D.new()
		shape.radius = .22
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = 1|4
		query.transform.origin = Vector3(at.x,.65,at.z)
		check(w.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"loose item slot avoids furniture and walls: "+str(at))
		var probe_item: Node3D = w.objects.battery_a
		probe_item.position = at
		await w._ground_loose_items()
		check(await reachable_from_floor(w,p,probe_item),"loose item has a real pickup approach: "+str(at))
	for id: String in hidden_pickups:
		w.objects[id].taken = hidden_pickups[id]
		w.objects[id].refresh()
	for attempt: int in range(12):
		LOOT.apply(w)
		var changed: bool = true
		var unique_ammo: Array = []
		for id: String in w.objects:
			var object: Node3D = w.objects[id]
			if id in LOOT.CONTAINERS or id in ["battery_a","battery_b","medkit"] or id.begins_with("shell_"):
				if prior.has(id) and prior[id] == object.position: changed = false
				prior[id] = object.position
			if object.kind == "shell" and not object.taken:
				if object.position in unique_ammo: changed = false
				unique_ammo.append(object.position)
		check(changed and unique_ammo.size() == int(w.rules.ammo),"new round changes every loot placement and keeps difficulty stock: "+str(attempt))
	var old_order: Array = d.order.duplicate()
	d.randomize_round()
	check(d.order != old_order and w.objects.drain_note.description.contains(d.BUTTONS[int(d.order[0])]),"pump code changes with matching in-world clue")
	check(AudioManager.sounds.monster_voice.size() == 18,"eighteen baked neural speech variations load")
	var spoken: Array[int] = []
	w.monster.speech_bag.clear()
	for i: int in range(18):
		var take: int = w.monster.next_speech_take()
		if not take in spoken: spoken.append(take)
	check(spoken.size() == 18,"all eighteen monster lines are heard before the vocabulary repeats")
	var last_take: int = w.monster.last_speech_take
	check(w.monster.next_speech_take() != last_take,"next vocabulary cycle avoids an immediate repeat")
	w.monster_speech(Vector3.ZERO,5)
	check(w.last_speech_take == 5,"host-selected speech index reaches the shared playback event")
	NetworkManager.leave()
	await get_tree().process_frame
	print("EXPANSION_PASS" if failures == 0 else "EXPANSION_FAIL %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
