extends RefCounted
const LOOT := preload("res://scripts/world/depot_loot.gd")
static func approach(qa: Node,item: Node3D,at: Vector3) -> bool:
	for offset: Vector3 in [Vector3(0,0,1.7),Vector3(0,0,-1.7),Vector3(1.7,0,0),Vector3(-1.7,0,0)]:
		qa.place(Vector3(at.x,.05,at.z)+offset,item.position)
		await qa.frames()
		if qa.world.target_for(qa.actor) == item: return true
	return false

static func run(qa: Node) -> void:
	var w: Node3D = qa.world
	var saved: Dictionary = {}
	for id: String in w.objects:
		var object: Node3D = w.objects[id]
		saved[id] = [object.position,object.opened,object.taken,object.container_id]
	for id: String in LOOT.CONTAINERS:
		var box: Node3D = w.objects[id]
		for at: Vector3 in LOOT.CONTAINERS[id]:
			var shift: Vector3 = at-box.position
			box.position = at; box.opened = true; box.refresh()
			for item: Node3D in w.objects.values():
				if item.container_id == id: item.position += shift
			w.refresh_containers(); await qa.frames()
			for item: Node3D in w.objects.values():
				if item.container_id != id: continue
				qa.place(Vector3(at.x,.05,at.z+1.7),item.position)
				await qa.frames()
				qa.check(w.target_for(qa.actor) == item,"all depot storage slots expose contents: "+id+" "+str(at))
	# Test one probe against solid furniture without random pickups masking it.
	var probe: Node3D = w.objects.depot_supply_0
	for item: Node3D in w.objects.values():
		if w.items.NAMES.has(item.kind) and item != probe: item.taken = true; item.refresh()
	for i: int in range(12):
		var box: Node3D = w.objects["depot_spare_%d" % i]
		box.opened = true; box.refresh()
		probe.container_id = box.object_id
		probe.position = box.position+Vector3(0,-.4,.1)
		w.refresh_containers(); await qa.frames()
		qa.check(await approach(qa,probe,box.position),"supply cupboard has an accessible pickup: "+box.object_id)
	probe.container_id = ""
	w.refresh_containers()
	for at: Vector3 in LOOT.AMMO:
		var floor_found: bool = false
		for rect: Rect2 in w.layout.FLOORS:
			if rect.has_point(Vector2(at.x,at.z)): floor_found = true
		qa.check(floor_found,"ammunition slot stays on the playable floor: "+str(at))
		probe.position = at
		await w._ground_loose_items()
		qa.check(await approach(qa,probe,at),"ammunition slot has a real interaction ray: "+str(at))
	for id: String in saved:
		var object: Node3D = w.objects[id]
		object.position = saved[id][0]; object.opened = saved[id][1]; object.taken = saved[id][2]; object.container_id = saved[id][3]
		object.refresh()
	w.refresh_containers()
	await qa.frames()
	var previous: Dictionary = {}
	for repeat: int in range(6):
		LOOT.apply(w)
		var changed: bool = true
		for id: String in LOOT.CONTAINERS:
			if previous.get(id,Vector3.INF) == w.objects[id].position: changed = false
			previous[id] = w.objects[id].position
		var unique: Array = []
		for i: int in range(11):
			var box_id: String = w.objects["depot_supply_%d" % i].container_id
			if box_id in unique: changed = false
			unique.append(box_id)
		qa.check(changed and unique.size() == 11,"new depot round changes storage and keeps distinct supply containers: "+str(repeat))
