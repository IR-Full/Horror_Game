extends RefCounted
const RANDOM:=preload("res://scripts/core/round_random.gd")
const CONTAINERS: Dictionary={
	"forest_safe":[Vector3(-21,.425,19),Vector3(-21,.425,24),Vector3(-10,.425,30)],
	"battery_safe":[Vector3(-54,.425,-8),Vector3(-40,.425,-8),Vector3(-54,.425,-22)],
	"belt_case":[Vector3(52,1.05,-18),Vector3(28,1.05,-18),Vector3(52,1.05,-39)],
	"fuel_case":[Vector3(-53,1,-78),Vector3(-37,1,-78),Vector3(-53,1,-89)],
	"key_case":[Vector3(46,1.05,56),Vector3(39,1.05,56),Vector3(52,1.05,48)]}
const BOXES := [Vector3(-21,1.05,30),Vector3(-10,1.05,18),Vector3(-10,1.05,24),Vector3(-54,1.05,-17),Vector3(-40,1.05,-23),Vector3(-40,1.05,-12),Vector3(29,1.05,-39),Vector3(52,1.05,-24),Vector3(29,1.05,-27),Vector3(-53,1.05,-84),Vector3(-37,1.05,-90),Vector3(13,1.05,-80),Vector3(27,1.05,-80),Vector3(13,1.05,-96),Vector3(39,1.05,39),Vector3(46,1.05,39)]
const AMMO := [Vector3(-12,.045,32),Vector3(-22,.045,16),Vector3(-38,.045,-6),Vector3(-55,.045,-24),Vector3(29,.045,-15),Vector3(54,.045,-40),Vector3(-36,.045,-74),Vector3(-55,.045,-91),Vector3(12,.045,-77),Vector3(27,.045,-97),Vector3(32,.045,38),Vector3(53,.045,58),Vector3(-31,.045,-18),Vector3(7,.045,-65)]
static func apply(s: Node3D) -> void:
	if not s.multiplayer.is_server():return
	var old: Dictionary=RANDOM.history("forest_loot");var chosen: Dictionary={}
	for id: String in CONTAINERS:
		var options: Array=CONTAINERS[id].duplicate();options.erase(old.get(id,Vector3.INF));var at: Vector3=options.pick_random();var shift: Vector3=at-s.objects[id].position;s.objects[id].position=at
		for item: Node3D in s.objects.values():
			if item.container_id==id:item.position+=shift
		chosen[id]=at
	var ids: Array=[];var kinds: Dictionary={}
	for i: int in range(14):
		var id: String="forest_supply_%d" % i;ids.append(id);kinds[id]=s.objects[id].kind
	var assignment: Dictionary=RANDOM.assign(ids,range(16),old,kinds)
	for id: String in assignment:
		var item: Node3D=s.objects[id];item.container_id="forest_box_%d" % assignment[id];item.position=s.objects[item.container_id].position+Vector3(0,-.4,.1);chosen[id]=assignment[id]
	var ammo_ids: Array=[];var old_ammo: Dictionary={}
	for i: int in range(6):
		var id: String="shell_%d" % i;ammo_ids.append(id)
		if old.has(id):old_ammo[id]=old[id]
	var ammo: Dictionary=RANDOM.assign(ammo_ids,AMMO,old_ammo,{},true)
	for i: int in range(6):
		var id: String=ammo_ids[i];s.objects[id].position=ammo[id];s.objects[id].taken=i>=int(s.rules.ammo);s.objects[id].refresh();chosen[id]=ammo[id]
	RANDOM.remember("forest_loot",chosen);s.refresh_containers()
