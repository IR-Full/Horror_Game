extends Node
var failures: int = 0

func _ready() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	if ok: print("SECTOR_CHECK "+label)
	else: failures+=1; push_error("SECTOR_FAIL "+label)
func delay(seconds: float) -> void: await get_tree().create_timer(seconds).timeout
func place(actor: Node3D, at: Vector3, target: Vector3) -> void:
	actor.position=at
	actor.net_position=at
	actor.velocity=Vector3.ZERO
	var direction: Vector3=(target-actor.eye_position()).normalized()
	actor.local_aim=Vector2(atan2(-direction.x,-direction.z),asin(direction.y))
	actor.aim=actor.local_aim

static func circuit_solution(values: Array) -> Array[int]:
	var initial: int = 0
	for i: int in range(9): initial |= int(values[i])<<i
	for pattern: int in range(512):
		var state: int = initial
		for i: int in range(9):
			if not pattern & (1<<i): continue
			var at:=Vector2i(i%3,i/3)
			for offset: Vector2i in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var cell:=at+offset
				if cell.x>=0 and cell.x<3 and cell.y>=0 and cell.y<3: state ^= 1<<(cell.y*3+cell.x)
		if state==0:
			var result: Array[int]=[]
			for i: int in range(9):
				if pattern & (1<<i): result.append(i)
			return result
	return []

func _run() -> void:
	NetworkManager.host_room("Sector QA",27946)
	NetworkManager.start_round(true)
	await delay(.35)
	var w: Node3D=GameManager.world
	var p: Node3D=GameManager.local_player()
	var system: Node=w.sectors
	w.monster.set_physics_process(false)
	p.input_enabled=false
	check(w.find_path(Vector3(0,0,10),Vector3(-54,0,-43)).size()>60,"physical route into boiler sector B")
	check(w.find_path(Vector3(0,0,10),Vector3(54,0,-21)).size()>60,"physical route into laboratory sector C")
	check(w.find_path(Vector3(0,0,10),Vector3(12,0,-96)).is_empty(),"sector D cannot be reached through its locked bulkhead")
	check(not w.items.pickup(p,w.objects.air_filter),"filter cannot be taken through a locked cabinet")
	var cross_door: Node3D=w.objects["door_sector_-1_0"]
	cross_door.opened=false
	cross_door.refresh()
	w._update_doors_navigation()
	place(p,Vector3(-54,.05,-40),Vector3(-54,1.4,-48))
	p.lamp_on=false
	w.monster.position=Vector3(-54,.05,-32)
	w.monster.net_position=w.monster.position
	w.monster.target_id=p.peer_id
	w.monster.rage_clock=100
	w.monster.sabotage_cooldown=200
	w.elapsed=35
	w.monster.change_state(w.monster.State.CHASE,p.position)
	w.monster.set_physics_process(true)
	await delay(4.5)
	check(cross_door.opened and w.monster.position.z < -36,"monster strikes and traverses a rotated sector door")
	w.monster.set_physics_process(false)
	p.health=100
	p.invulnerable=0
	var saved: Array=system.circuit.duplicate()
	w.circuit_command(NetworkManager.round_id,4)
	check(system.circuit==saved,"remote circuit command rejected without proximity and sight")
	for i: int in range(3):
		var valve: Node3D=w.objects["valve_%d"%i]
		place(p,valve.position+Vector3(0,-1.1,1.7),valve.position)
		await delay(.06)
		check(w.target_for(p)==valve,"ray reaches valve "+str(i))
		for turn: int in range(system.valve_solution[i]): w.interact_object(p,valve)
	check(system.pressure_ready and w.objects.door_sector_d.locked,"pressure alone does not bypass filtration requirement")
	place(p,Vector3(36,.05,-40.3),w.objects.circuit.position)
	await delay(.1)
	w.circuit_command(NetworkManager.round_id,99)
	check(system.circuit==saved,"invalid circuit cell rejected")
	var solution: Array[int]=circuit_solution(system.circuit)
	check(not solution.is_empty(),"randomized circuit has a legal solution")
	for index: int in solution: w.circuit_command(NetworkManager.round_id,index)
	check(system.circuit_ready and not w.objects.filter_locker.locked,"solving Lights Out unlocks the filter cabinet")
	place(p,Vector3(w.objects.filter_locker.position.x,.05,w.objects.filter_locker.position.z+1.7),w.objects.filter_locker.position)
	await delay(.1)
	w.interact_object(p,w.objects.filter_locker)
	await delay(.1)
	place(p,Vector3(w.objects.filter_locker.position.x,.05,w.objects.filter_locker.position.z+1.7),w.objects.air_filter.position)
	await delay(.06)
	w.interact_object(p,w.objects.air_filter)
	check("air_filter" in p.inventory,"filter cartridge must be retrieved from the opened cabinet")
	w.objectives.generator_on=true
	place(p,Vector3(39,.05,-40.2),w.objects.purifier.position)
	p.input_enabled=true
	Input.action_press("interact")
	await delay(4.4)
	Input.action_release("interact")
	p.input_enabled=false
	check(system.purified and not w.objects.door_sector_d.locked,"cartridge and actual held interaction restore filtering and unlock D")
	var gate: Node3D=w.objects.door_sector_d
	place(p,Vector3(0,.05,-61.2),gate.position)
	await delay(.1)
	w.interact_object(p,gate)
	check(gate.opened and w.find_path(Vector3(0,0,10),Vector3(12,0,-96)).size()>100,"opening the bulkhead creates a physical route to transmitter D")
	for i: int in range(3):
		var tuner: Node3D=w.objects["tuner_%d"%i]
		place(p,tuner.position+Vector3(0,-1.2,1.7),tuner.position)
		await delay(.06)
		for turn: int in range(system.frequency_solution[i]): w.interact_object(p,tuner)
	check(not system.ready_to_transmit(),"unfinished drainage E blocks transmission after B/C/D")
	w.drainage.drained = true
	check(system.ready_to_transmit(),"all sector tasks are required before transmission")
	var footprints: Node3D=w.atmosphere.get_node("Footprints")
	var before: int=footprints.total_stamps
	w.player_step(Vector3(0,.01,8),0,true,true,false)
	check(footprints.total_stamps==before+1,"network footstep creates an actual boot stamp")
	for i: int in range(200): footprints.stamp(Vector3(0,.034,5),0,i%2==0,false)
	check(footprints.stamps.multimesh.instance_count==160,"footprint memory and instance count stay bounded")
	var image: Image=load("res://assets/textures/decals/bootprint.png").get_image()
	check(image.get_width()>=512 and image.get_pixel(0,0).a==0,"boot texture preserves high-resolution transparent tread")
	for kind: String in ["pain","hurt","roar","growl","step","step_metal","step_gravel","smash","door","alarm","shotgun","reload"]:
		var sound: AudioStream=AudioManager.stream_for(kind)
		check(sound is AudioStreamOggVorbis and sound.get_length()>.1,"recorded sound bank: "+kind)
	NetworkManager.leave()
	await get_tree().process_frame
	print("SECTOR_PASS" if failures==0 else "SECTOR_FAIL %d checks"%failures)
	get_tree().quit(0 if failures==0 else 1)
