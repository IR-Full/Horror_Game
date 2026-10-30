extends RefCounted
## Accessible desks only: a prerequisite clue never enters a locked task reward.
const DESKS := [
	{"safe_note":[Vector3(7,1.08,8)],"relay_note":[Vector3(12,1.08,-35.6),Vector3(7,1.08,-28.2)],"pressure_note":[Vector3(-36,1.08,-17)],"circuit_note":[Vector3(33,1.08,-17)],"frequency_note":[Vector3(33,1.08,-17)],"drain_note":[Vector3(-13,1.08,29)]},
	{"depot_note_a":[Vector3(-17,1.08,-98)],"depot_note_b":[Vector3(-14,1.08,42)],"depot_wiring_note":[Vector3(54,1.08,-22)]},
	{"admission_note":[Vector3(-18,1.08,28)],"ward_note":[Vector3(-53,1.08,-44)],"surgery_note":[Vector3(52,1.08,5)],"laboratory_note":[Vector3(18,1.08,-98)]}]
const OFFSETS := [Vector3(-.72,0,-.18),Vector3(0,0,-.18),Vector3(.72,0,-.18),Vector3(-.72,0,.18),Vector3(0,0,.18),Vector3(.72,0,.18)]

static func candidates(map_id: int,id: String) -> Array:
	var result: Array=[]
	for desk: Vector3 in DESKS[map_id][id]:
		for offset: Vector3 in OFFSETS:result.append(desk+offset)
	return result

static func apply(world: Node3D) -> void:
	if not world.multiplayer.is_server():return
	var randoms:=preload("res://scripts/core/round_random.gd")
	var name: String="clues_%d" % world.map_id
	var previous: Dictionary=randoms.history(name)
	var chosen: Dictionary={};var used: Array=[]
	for id: String in DESKS[world.map_id]:
		var options: Array=candidates(world.map_id,id)
		options.erase(previous.get(id,Vector3.INF))
		for occupied: Vector3 in used:options.erase(occupied)
		var at: Vector3=options.pick_random();used.append(at);chosen[id]=at
		world.objects[id].position=at
	randoms.remember(name,chosen)
