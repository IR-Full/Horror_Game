extends RefCounted
const CONTAINERS := {
	"battery_cage":[Vector3(-56,1,-57),Vector3(-60,1,-58),Vector3(-50,1,-59)],
	"parts_safe":[Vector3(55,.425,-57),Vector3(59,.425,-58),Vector3(48,.425,-60)],
	"wheel_locker":[Vector3(-35,1.05,-33),Vector3(-31,1.05,-36),Vector3(-57,1.05,-33)],
	"belt_locker":[Vector3(17,1.05,-97),Vector3(-17,1.05,-94),Vector3(8,1.05,-102)],
	"guard_locker":[Vector3(-11,1.05,42),Vector3(-6,1.05,40),Vector3(-10,1.05,44.5)],
	"ignition_locker":[Vector3(11,1.05,62),Vector3(6,1.05,60),Vector3(14,1.05,64)]
}
const AMMO := [Vector3(-5,.045,8),Vector3(5,.045,-10),Vector3(-31,.045,-22),Vector3(-58,.045,-45),Vector3(31,.045,-45),Vector3(58,.045,-18),Vector3(-7,.045,-78),Vector3(7,.045,-92),Vector3(-14,.045,45.5),Vector3(12,.045,65),Vector3(0,.045,-41),Vector3(0,.045,33),Vector3(0,.045,-59),Vector3(0,.045,-66)]
static func apply(s: Node3D) -> void:
	var cfg := ConfigFile.new()
	var path: String = SettingsManager.save_path.get_base_dir().path_join("last_depot_loot.cfg")
	cfg.load(path)
	var previous: Dictionary = cfg.get_value("loot","positions",{})
	var chosen: Dictionary = {}
	for id: String in CONTAINERS:
		var candidates: Array = CONTAINERS[id].duplicate()
		candidates.erase(previous.get(id,Vector3.INF))
		var at: Vector3 = candidates.pick_random()
		var delta: Vector3 = at-s.objects[id].position
		s.objects[id].position = at
		for item: Node3D in s.objects.values():
			if item.container_id == id: item.position += delta
		chosen[id] = at
	var slots: Array = range(12)
	var kinds: Array = ["battery","battery","battery","medkit","medkit","sedative","sedative","sedative","sedative","thermos","thermos"]
	for i: int in range(kinds.size()):
		var candidates: Array = slots.duplicate()
		candidates.erase(previous.get("supply_%d" % i,-1))
		var slot: int = candidates.pick_random()
		slots.erase(slot)
		chosen["supply_%d" % i] = slot
		var box_id: String = "depot_spare_%d" % slot
		var item: Node3D = s.objects["depot_supply_%d" % i]
		item.container_id = box_id
		item.position = s.objects[box_id].position+Vector3(0,-.4,.1)
	var previous_ammo: Array = cfg.get_value("loot","ammo",[])
	var ammo: Array = []
	for i: int in range(6):
		var candidates: Array = AMMO.duplicate()
		for at: Vector3 in previous_ammo+ammo: candidates.erase(at)
		var at: Vector3 = candidates.pick_random()
		ammo.append(at)
		s.objects["shell_%d" % i].position = at
		s.objects["shell_%d" % i].taken = i >= int(s.rules.ammo)
		s.objects["shell_%d" % i].refresh()
	cfg.set_value("loot","positions",chosen)
	cfg.set_value("loot","ammo",ammo.slice(0,int(s.rules.ammo)))
	cfg.save(path)
	s.refresh_containers()
