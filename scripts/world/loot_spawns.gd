extends RefCounted
## Authoritative curated slots: no random coordinates inside walls or under furniture.
const CONTAINERS := {
	"fuse_safe":[Vector3(-7,.425,8),Vector3(-5.3,.425,5.6),Vector3(-5.4,.425,9)],
	"fuel_cage":[Vector3(-12.6,1,4.9),Vector3(-12.6,1,6.3),Vector3(-12.6,1,7.7)],
	"work_locker":[Vector3(-10,1.05,-20),Vector3(-13,1.05,-18),Vector3(-6,1.05,-23)],
	"residence_locker":[Vector3(-8,1.05,-9),Vector3(-5,1.05,-6),Vector3(-13,1.05,-7)],
	"archive_locker":[Vector3(9,1.05,1.5),Vector3(5.3,1.05,1),Vector3(13,1.05,.5)],
	"filter_locker":[Vector3(49,1.05,-20),Vector3(54,1.05,-24),Vector3(59,1.05,-22)],
	"supply_b":[Vector3(-32,1.05,-19),Vector3(-39,1.05,-15),Vector3(-32,1.05,-25)],
	"supply_c":[Vector3(58,1.05,-44),Vector3(50,1.05,-50),Vector3(61,1.05,-39)],
	"supply_d":[Vector3(17,1.05,-68),Vector3(7,1.05,-68),Vector3(18,1.05,-80)],
	"drain_reward":[Vector3(20,1.05,62),Vector3(7,1.05,63),Vector3(17,1.05,55.5)]
}
const LOOSE := [Vector3(8,.2,6),Vector3(5.3,.2,10.7),Vector3(-5,.2,-9),Vector3(6,.2,-18),Vector3(-5,.2,-32),Vector3(10,.2,-44),Vector3(-30,.2,-39),Vector3(-57,.2,-23),Vector3(30,.2,-19),Vector3(49,.2,-39),Vector3(-7,.2,30),Vector3(7,.2,58)]
const AMMO := [Vector3(-6,.045,6),Vector3(11,.045,-6),Vector3(-6,.045,-18),Vector3(6,.045,-22),Vector3(6,.045,-33),Vector3(-6,.045,-42),Vector3(10,.045,-47),Vector3(-13,.045,-30),Vector3(-30,.045,-24),Vector3(-40,.045,-39),Vector3(30,.045,-44),Vector3(49,.045,-24),Vector3(-6,.045,35),Vector3(7,.045,61)]

static func apply(station: Node3D) -> void:
	var config := ConfigFile.new()
	var path: String = SettingsManager.save_path.get_base_dir().path_join("last_loot.cfg")
	config.load(path)
	var previous: Dictionary = config.get_value("loot","positions",{})
	var previous_ammo: Array = config.get_value("loot","ammo",NetworkManager.last_shell_positions)
	var chosen: Dictionary = {}
	for id: String in CONTAINERS:
		var object: Node3D = station.objects[id]
		var candidates: Array = CONTAINERS[id].duplicate()
		candidates.erase(previous.get(id,Vector3.INF))
		var at: Vector3 = candidates.pick_random()
		var displacement: Vector3 = at-object.position
		object.position = at
		for item: Node3D in station.objects.values():
			if item.container_id == id: item.position += displacement
		chosen[id] = at
	var occupied: Array = []
	for id: String in ["battery_a","battery_b","medkit"]:
		var candidates: Array = LOOSE.duplicate()
		candidates.erase(previous.get(id,Vector3.INF))
		for at: Vector3 in occupied: candidates.erase(at)
		var at: Vector3 = candidates.pick_random()
		station.objects[id].position = at
		occupied.append(at)
		chosen[id] = at
	var used_ammo: Array = []
	for i: int in range(6):
		var id: String = "shell_%d" % i
		var candidates: Array = AMMO.duplicate()
		for at: Vector3 in used_ammo: candidates.erase(at)
		# Also prevent a location from the previous visible ammo layout recurring.
		for at: Vector3 in previous_ammo: candidates.erase(at)
		candidates.erase(previous.get(id,Vector3.INF))
		var at: Vector3 = candidates.pick_random()
		station.objects[id].position = at
		station.objects[id].taken = i >= int(station.rules.ammo)
		station.objects[id].refresh()
		used_ammo.append(at)
		chosen[id] = at
	NetworkManager.last_shell_positions = used_ammo.slice(0,int(station.rules.ammo))
	config.set_value("loot","positions",chosen)
	config.set_value("loot","ammo",NetworkManager.last_shell_positions)
	config.save(path)
	station.refresh_containers()
