extends RefCounted
const CONTAINERS := {
	"hospital_fuse_safe":[Vector3(-23,.425,26),Vector3(-26,.425,23),Vector3(-10,.425,30)],
	"ward_case":[Vector3(-57,1.05,3),Vector3(-51,1.05,5),Vector3(-59,1.05,6)],
	"surgery_case":[Vector3(56,1.05,-43),Vector3(59,1.05,-47),Vector3(49,1.05,-47)],
	"morgue_safe":[Vector3(-24,.425,-85),Vector3(-10,.425,-88),Vector3(-26,.425,-90)],
	"badge_case":[Vector3(24,1,-72),Vector3(12,1,-70),Vector3(8,1,-75)],
	"scalpel_case":[Vector3(25,1.05,-44),Vector3(23,1.05,-47),Vector3(32,1.05,-47)]}
const AMMO := [Vector3(0,.045,4),Vector3(0,.045,-31),Vector3(0,.045,-55),Vector3(0,.045,-90),Vector3(-20,.045,22),Vector3(20,.045,38),Vector3(-41,.045,-45),Vector3(-41,.045,-25),Vector3(-41,.045,5),Vector3(41,.045,-45),Vector3(41,.045,-15),Vector3(41,.045,5),Vector3(-10,.045,-101),Vector3(10,.045,-101)]
static func apply(s: Node3D) -> void:
	var cfg := ConfigFile.new()
	var path: String = SettingsManager.save_path.get_base_dir().path_join("last_hospital_loot.cfg")
	cfg.load(path)
	var previous: Dictionary = cfg.get_value("loot","positions",{})
	var chosen: Dictionary = {}
	for id: String in CONTAINERS:
		var candidates: Array = CONTAINERS[id].duplicate(); candidates.erase(previous.get(id,Vector3.INF))
		var at: Vector3 = candidates.pick_random(); var shift: Vector3 = at-s.objects[id].position
		s.objects[id].position = at
		for item: Node3D in s.objects.values():
			if item.container_id == id: item.position += shift
		chosen[id] = at
	var slots: Array = range(14)
	for i: int in range(13):
		var candidates: Array = slots.duplicate(); candidates.erase(previous.get("supply_%d" % i,-1))
		var slot: int = candidates.pick_random(); slots.erase(slot); chosen["supply_%d" % i] = slot
		var item: Node3D = s.objects["hospital_supply_%d" % i]
		item.container_id = "hospital_supply_box_%d" % slot
		item.position = s.objects[item.container_id].position+Vector3(0,-.4,.1)
	var previous_ammo: Array = cfg.get_value("loot","ammo",[])
	var ammo: Array = []
	for i: int in range(6):
		var candidates: Array = AMMO.duplicate()
		for at: Vector3 in previous_ammo+ammo: candidates.erase(at)
		var at: Vector3 = candidates.pick_random(); ammo.append(at)
		s.objects["shell_%d" % i].position = at; s.objects["shell_%d" % i].taken = i>=int(s.rules.ammo)
		s.objects["shell_%d" % i].refresh()
	cfg.set_value("loot","positions",chosen); cfg.set_value("loot","ammo",ammo.slice(0,int(s.rules.ammo))); cfg.save(path)
	s.refresh_containers()
