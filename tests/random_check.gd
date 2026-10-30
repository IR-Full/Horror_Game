extends Node
const RANDOM:=preload("res://scripts/core/round_random.gd")
const CLUES:=preload("res://scripts/world/loot_clues.gd")
const LOOT: Array=[preload("res://scripts/world/loot_spawns.gd"),preload("res://scripts/world/depot_loot.gd"),preload("res://scripts/world/hospital_loot.gd")]
var failures: int=0
func _ready() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;push_error("RANDOM_FAIL "+label)
func puzzle_state(w: Node3D) -> Dictionary:
	if w.map_id==0:return {"safe":w.objects.fuse_safe.code,"relays":w.objectives.relay_solution.duplicate(),"valves":w.sectors.valve_solution.duplicate(),"frequency":w.sectors.frequency_solution.duplicate(),"circuit":w.sectors.circuit.duplicate(),"pump":w.drainage.order.duplicate()}
	if w.map_id==1:return {"safe":w.objects.parts_safe.code,"circuit":w.objectives.circuit_solution.duplicate()}
	return {"safe":w.objects.hospital_fuse_safe.code,"morgue":w.objects.morgue_safe.code,"ward":w.objectives.ward_solution.duplicate(),"pressure":w.objectives.pressure_solution.duplicate(),"mixture":w.objectives.mixture_solution.duplicate()}
func inspect(w: Node3D) -> Dictionary:
	var places: Dictionary={};var notes: Dictionary={};var kinds: Dictionary={}
	for id: String in w.objects:
		var item: Node3D=w.objects[id]
		if item.taken:continue
		if w.items.NAMES.has(item.kind) or item.kind=="note":
			places[id]=[item.position,item.container_id];kinds[id]=item.kind
			if item.kind=="note":notes[id]=item.description
	return {"places":places,"notes":notes,"kinds":kinds,"puzzles":puzzle_state(w)}
func changed(previous: Dictionary,current: Dictionary) -> bool:
	for id: String in current.places:
		if previous.places.has(id):
			var a: Vector3=current.places[id][0];var b: Vector3=previous.places[id][0]
			if Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))<.05:return false
	for id: String in current.places:
		if current.kinds[id] not in ["battery","medkit","sedative","thermos","shell"]:continue
		for old: String in previous.places:
			if current.kinds[id]!=previous.kinds[old]:continue
			var a: Vector3=current.places[id][0];var b: Vector3=previous.places[old][0]
			if Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))<.05:return false
	for key: String in current.puzzles:
		var a: Variant=current.puzzles[key];var b: Variant=previous.puzzles[key]
		if a==b:return false
		if key!="circuit" or (a is Array and a.size()==3):
			for i: int in range(a.length() if a is String else a.size()):
				if a[i]==b[i]:return false
	return true
func regenerate(w: Node3D) -> void:
	if w.map_id==0:w.randomize_puzzles()
	else:w.objectives.randomize_round()
	LOOT[w.map_id].apply(w);CLUES.apply(w);w.sync_clues()
	await w._ground_loose_items()
func valid_clues(w: Node3D) -> bool:
	if w.map_id==0:
		if not w.objects.safe_note.description.contains(w.objects.fuse_safe.code):return false
		if preload("res://tests/sector_check.gd").circuit_solution(w.sectors.circuit).is_empty():return false
		for i: int in range(3):
			if not w.objects.relay_note.description.contains(["A: %d","B: %d","C: %d"][i] % w.objectives.relay_solution[i]):return false
		var pump: PackedStringArray=[]
		for i: int in w.drainage.order:pump.append(w.drainage.BUTTONS[i]+" • "+w.drainage.ROOMS[i])
		return w.objects.pressure_note.description.contains("A: %d • B: %d • C: %d" % w.sectors.valve_solution) and w.objects.frequency_note.description.contains("%d / %d / %d" % w.sectors.frequency_solution) and w.objects.drain_note.description.contains(" → ".join(pump))
	if w.map_id==1:
		return w.objects.depot_note_a.description.contains(w.objects.parts_safe.code.left(2)) and w.objects.depot_note_b.description.contains(w.objects.parts_safe.code.right(2)) and w.objects.depot_wiring_note.description.contains("%d / %d / %d" % w.objectives.circuit_solution)
	var ward: PackedStringArray=[]
	for i: int in w.objectives.ward_solution:ward.append(str(i+1))
	return w.objects.admission_note.description.contains(w.objects.hospital_fuse_safe.code.left(2)) and w.objects.ward_note.description.contains(w.objects.hospital_fuse_safe.code.right(2)) and w.objects.ward_note.description.contains(" → ".join(ward)) and w.objects.laboratory_note.description.contains(w.objects.morgue_safe.code) and w.objects.surgery_note.description.contains("%d / %d / %d" % w.objectives.pressure_solution) and w.objects.laboratory_note.description.contains("%d / %d / %d" % w.objectives.mixture_solution)
func aim(p: Node3D,at: Vector3,target: Vector3) -> void:
	p.position=at;p.net_position=at
	var d: Vector3=(target-p.eye_position()).normalized();p.local_aim=Vector2(atan2(-d.x,-d.z),asin(d.y));p.aim=p.local_aim
func run() -> void:
	# Dense near-full matchings must not strand the final item or swap equal supplies.
	var ids: Array=[];var kinds: Dictionary={};var previous: Dictionary={}
	for i: int in range(13):ids.append(str(i));kinds[str(i)]=str(i%4)
	for n: int in range(512):
		var selected: Dictionary=RANDOM.assign(ids,range(14),previous,kinds)
		check(selected.size()==13,"complete matching "+str(n))
		if selected.size()!=13:get_tree().quit(1);return
		var used: Array=[]
		for id: String in selected:
			check(not selected[id] in used,"unique slot");used.append(selected[id])
			for old: String in previous:
				if kinds[id]==kinds[old]:check(selected[id]!=previous[old],"same type cannot reuse a previous slot")
		previous=selected
	for map_id: int in range(3):
		NetworkManager.host_room("Random QA",28001);NetworkManager.choose_map(map_id);NetworkManager.choose_difficulty(0);NetworkManager.start_round(true)
		await get_tree().create_timer(.4).timeout
		var w: Node3D=GameManager.world;var p: Node3D=GameManager.local_player();p.input_enabled=false;p.set_physics_process(false);w.monster.set_physics_process(false)
		var last: Dictionary=inspect(w)
		for iteration: int in range(12):
			# Repeat the same RNG seed while forgetting manager caches, as on a fresh launch.
			seed(1789);NetworkManager.last_puzzles={};NetworkManager.last_depot_puzzles={};NetworkManager.last_hospital_puzzles={};NetworkManager.last_pump_order=[]
			await regenerate(w)
			var current: Dictionary=inspect(w)
			check(changed(last,current),"fresh codes, individual settings, all pickups and notes after cache reset: map %d / %d" % [map_id,iteration])
			check(valid_clues(w),"matching clue text and solvable board")
			var ammo: int=0
			for item: Node3D in w.objects.values():
				if item.kind=="shell" and not item.taken:ammo+=1
			check(ammo==6,"easy stock preserved")
			last=current
		# Probe every desk variant with actual item rays and furniture left solid.
		for id: String in CLUES.DESKS[map_id]:w.objects[id].position=Vector3(0,-100,0)
		for id: String in CLUES.DESKS[map_id]:
			var item: Node3D=w.objects[id]
			for at: Vector3 in CLUES.candidates(map_id,id):
				item.position=at;await w._ground_loose_items()
				aim(p,Vector3(at.x,.05,at.z+1.7),item.position)
				await get_tree().physics_frame;await get_tree().physics_frame
				check(w.target_for(p)==item,"reachable journal variant: "+id+" "+str(at))
			item.position=Vector3(0,-100,0)
		print("RANDOM_MAP_PASS ",map_id," twelve seeded restarts, every pickup and clue slot")
		NetworkManager.leave();await get_tree().process_frame;await get_tree().process_frame
	print("RANDOM_PASS" if failures==0 else "RANDOM_FAIL %d" % failures);get_tree().quit(0 if failures==0 else 1)
