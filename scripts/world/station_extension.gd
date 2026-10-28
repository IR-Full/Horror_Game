extends RefCounted
## Northern wing, authored routes, searchable storage and equipment puzzles.
static func build(s: Node3D) -> void:
	s.block(Vector3(0, -.2, -32), Vector3(30, .4, 38), "313c3e")
	s.block(Vector3(0, 3.4, -32), Vector3(30, .2, 38), "202c30")
	for x: float in [-15, 15]:
		for z: float in [-42.5, -21.5]:
			s.block(Vector3(x, 1.6, z), Vector3(.3, 3.2, 17), "465354")
	for x: float in [-9, 9]:
		s.block(Vector3(x, 1.6, -51), Vector3(12, 3.2, .3), "465354")
	for z: float in [-26, -38]:
		for x: float in [-9, 9]:
			s.block(Vector3(x, 1.6, z), Vector3(12, 3.2, .22), "475653")
	var names: Array = [["МАСТЕРСКАЯ • 07", "КАРАНТИН • 08"], ["РЕЛЕЙНАЯ • 09", "ЛАБОРАТОРИЯ • 10"], ["НАСОСНАЯ • 11", "ХОЛОДИЛЬНИК • 12"]]
	for index: int in range(3):
		var z: float = -20.0 - index * 12.0
		for side: float in [-1, 1]:
			var x: float = side * 3.0
			for offset: float in [-3.55, 3.55]:
				s.block(Vector3(x, 1.6, z + offset), Vector3(.22, 3.2, 4.9), "4c5b58")
			s.door_frame(x, z)
			var door: Node3D = s.add_object("door_n_%s_%d" % [int(side), index], "door", "Дверь", Vector3(x, 1.44, z))
			door.opened = true
			door.refresh()
			s.sign_text(names[index][0 if side < 0 else 1], Vector3(side * 9, 2.35, z - 5.75), 0, 32)
			var light := OmniLight3D.new()
			light.position = Vector3(side * 9, 2.8, z)
			light.light_color = Color("8da3a1")
			light.omni_range = 7
			light.set_meta("base_energy", .6)
			light.set_meta("standby", .07)
			s.add_child(light)
			s.lights.append(light)
			for p: Vector3 in [Vector3(side * 12, 0, z - 3.6), Vector3(side * 7, 0, z + 3.8)]:
				var prop: Node3D = s.ART.model("desk" if index == 1 else ("shelf" if side < 0 else "cot"))
				prop.position = p
				s.add_child(prop)
				s._prop_collision(p + Vector3.UP * .5, Vector3(2.5, 1, .85))
			var ceiling_lamp: Node3D = s.ART.model("lamp")
			ceiling_lamp.position = Vector3(side * 9, 3.16, z)
			s.add_child(ceiling_lamp)
		var hall_light := OmniLight3D.new()
		hall_light.position = Vector3(0, 2.9, z)
		hall_light.light_color = Color("9f9d7b")
		hall_light.omni_range = 7.0
		hall_light.set_meta("base_energy", .6)
		hall_light.set_meta("standby", .14)
		s.add_child(hall_light)
		s.lights.append(hall_light)
		var fixture: Node3D = s.ART.model("lamp")
		fixture.position = Vector3(0, 3.16, z)
		s.add_child(fixture)
		s.sign_text("← %02d      СЕВЕРНЫЙ БЛОК      %02d →" % [7 + index * 2, 8 + index * 2], Vector3(0, 2.8, z + 4.8), 0, 26)
	s.add_object("ventilation", "ventilation", "ВЕНТИЛЯЦИЯ • удерживать E для ремонта", Vector3(-10, 1.05, -44))
	for i: int in range(3):
		s.add_object("relay_%d" % i, "relay", "Реле %s • E: переключить 0–3" % ["A", "B", "C"][i], Vector3(-7.0 - i * 1.5, 1.3, -36.5))
		s.block(Vector3(-7.0-i*1.5, .55, -36.55), Vector3(.08, 1.1, .08), "293e40", false)
	var note: Node3D = s.add_object("relay_note", "note", "Журнал электрика", Vector3(12, 1.08, -35.6))
	note.description = "РЕЗЕРВНЫЙ КОНТУР\nA — один импульс. B — три. C — два.\nВыставить реле 1 / 3 / 2 в релейной, сектор 09.\nБез этого передатчик не держит частоту."
	var desk: Node3D = s.ART.model("desk")
	desk.position = Vector3(7, 0, 8)
	s.add_child(desk)
	s._prop_collision(Vector3(7, .52, 8), Vector3(2.5, 1.04, .85))
	note = s.add_object("safe_note", "note", "Листок кладовщика", Vector3(7, 1.08, 8))
	note.description = "КОД СЕЙФА\nЧетыре смены. Один выживший. Семь пропавших.\n4 — 1 — 7. Предохранитель заперт в сейфе на складе.\nКлюч от топливной клетки — в шкафчике мастерской, сектор 07."
	var safe: Node3D = s.add_object("fuse_safe", "safe", "Сейф • кодовый замок", Vector3(-7, .9, 8))
	safe.code = "417"
	s.objects.fuse.container_id = "fuse_safe"
	s.objects.fuse.position = safe.position + Vector3(0, -.28, .1)
	var cage: Node3D = s.add_object("fuel_cage", "cage", "Топливная клетка • нужен служебный ключ", Vector3(-12, 1, 8))
	cage.locked = true
	cage.required_key = "service_key"
	s.objects.fuel.container_id = "fuel_cage"
	s.objects.fuel.position = cage.position + Vector3(0, -.65, 0)
	var locker: Node3D = s.add_object("work_locker", "locker_container", "Шкафчик мастерской • осмотреть", Vector3(-10, 1.05, -20))
	var key: Node3D = s.add_object("service_key", "service_key", "Служебный ключ", locker.position + Vector3(0, -.4, .1))
	key.container_id = "work_locker"
	locker = s.add_object("residence_locker", "locker_container", "Шкафчик дежурного • осмотреть", Vector3(-8, 1.05, -9))
	s.objects.key.container_id = "residence_locker"
	s.objects.key.position = locker.position + Vector3(0, -.4, .1)
	locker = s.add_object("archive_locker", "locker_container", "Шкаф архива • осмотреть", Vector3(9, 1.05, 1.5))
	s.objects.cassette.container_id = "archive_locker"
	s.objects.cassette.position = locker.position + Vector3(0, -.37, .1)
	# A noisy crawl shortcut. Both hatches remain reachable from ordinary routes.
	for i: int in range(2):
		var hatch: Node3D = s.add_object("hatch_%d" % i, "hatch", "Вентканал • присядьте и нажмите E", Vector3(14.78 if i == 0 else -14.78, .5, -21 if i == 0 else -45))
		hatch.rotation.y = -PI/2 if i == 0 else PI/2
		hatch.destination = Vector3(-10.5, .05, -45) if i == 0 else Vector3(10.5, .05, -21)
	var ammo_positions: Array[Vector3] = [Vector3(-6, .045, 6), Vector3(11, .045, -6), Vector3(-6, .045, -18), Vector3(6, .045, -22), Vector3(6, .045, -33), Vector3(-6, .045, -42), Vector3(10, .045, -47), Vector3(-13, .045, -30)]
	for i: int in range(4):
		s.add_object("shell_%d" % i, "shell", "Патрон 12 калибра", ammo_positions[i])
	s.set_meta("ammo_positions", ammo_positions)
	s.refresh_containers()
