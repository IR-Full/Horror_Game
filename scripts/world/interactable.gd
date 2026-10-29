extends StaticBody3D
## Visual/collision representation. Authoritative state lives in Station/ItemSystem.
var object_id: String = ""
var kind: String = ""
var title: String = ""
var taken: bool = false
var opened: bool = false
var locked: bool = false
var concealed: bool = false
var container_id: String = ""
var required_key: String = ""
var description: String = ""
var code: String = ""
var destination := Vector3.ZERO
var cover: Node3D
var rotors: Array[Node3D] = []
var warning_light: OmniLight3D
var cover_collider: CollisionShape3D
var cover_width: float = .8
var gate_rule: String = ""
const ART := preload("res://scripts/art/art_factory.gd")
var mesh: Node3D
var collider: CollisionShape3D
var label: Label3D

func _ready() -> void:
	collision_layer = 4
	if kind in ["battery", "shell", "medkit", "key", "service_key", "cassette", "fuse", "fuel", "air_filter", "note", "car_battery", "spark_plugs", "drive_belt", "wheel", "car_key", "yard_key", "sedative", "thermos", "hospital_key", "scalpel", "specimen_a", "specimen_b", "specimen_c", "hospital_badge"]:
		collision_layer = 16 # Ray-targetable supplies never block characters or vision.
	collision_mask = 0
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.22, 0.32)
	var color := Color("d8ba70")
	match kind:
		"door": box.size = Vector3(0.24, 2.88, 2.18); color = Color("355251")
		"generator": box.size = Vector3(1.6, 1.2, 1.0); color = Color("5e7154")
		"transmitter": box.size = Vector3(1.5, 1.1, 0.65); color = Color("516e79")
		"power": box.size = Vector3(0.6, 0.9, 0.35); color = Color("bb723c")
		"fuel": box.size = Vector3(0.4, 0.55, 0.25); color = Color("9c4938")
		"cassette": box.size = Vector3(0.32, 0.14, 0.22); color = Color("70a4a7")
		"medkit": color = Color("9dcccc")
		"battery": color = Color("cfb746")
		"safe": box.size = Vector3(.85, .85, .65)
		"cage": box.size = Vector3(1.25, 1.9, .9)
		"locker_container": box.size = Vector3(.85, 2.1, .6)
		"ventilation": box.size = Vector3(1.5, 1.8, .8)
		"relay": box.size = Vector3(.6, .9, .35)
		"hatch": box.size = Vector3(1, .8, .12)
		"note": box.size = Vector3(.3, .024, .36)
		"valve": box.size = Vector3(.6, .6, .35)
		"purifier": box.size = Vector3(1.5, 1.8, .8)
		"circuit", "tuner", "drain_switch", "depot_dial", "hospital_control", "hospital_station": box.size = Vector3(.6, .9, .35)
		"drain_pump": box.size = Vector3(1.5,1.8,.8)
		"air_filter": box.size = Vector3(.18, .34, .18)
		"vehicle": box.size = Vector3(2.2,1.5,4.5)
	if kind == "door":
		mesh = Node3D.new()
		mesh.position.z = 1.09
		var leaf := ART.model(kind)
		leaf.position.z = -1.09
		mesh.add_child(leaf)
	else:
		var model_name: String = {"service_key": "key", "note": "cassette", "relay": "power", "hatch": "vent_grate", "ventilation": "vent_unit", "locker_container": "locker_shell", "circuit":"power", "tuner":"power", "purifier":"vent_unit", "drain_switch":"power", "drain_pump":"vent_unit", "depot_dial":"power", "vehicle":"escape_car", "car_key":"key", "yard_key":"key", "hospital_key":"key", "hospital_control":"power", "hospital_station":"hospital_console"}.get(kind, kind)
		mesh = _paper() if kind == "note" else ART.model(model_name)
		if kind in ["generator", "transmitter", "power", "circuit", "tuner"]:
			mesh.rotation.y = PI
	add_child(mesh)
	if kind == "vehicle": mesh.position.y = -.8
	if kind == "ventilation":
		for y: float in [-.42, .42]:
			var rotor: Node3D = ART.model("fan_blades")
			rotor.position = Vector3(0, y, .43)
			rotor.scale = Vector3.ONE * .55
			add_child(rotor)
			rotors.append(rotor)
	if kind in ["ventilation", "generator"]:
		warning_light = OmniLight3D.new()
		warning_light.light_color = Color("d94327")
		warning_light.omni_range = 2.6
		warning_light.position = Vector3(0, .8, .7)
		warning_light.hide()
		add_child(warning_light)
	if kind in ["safe", "locker_container", "cage"]:
		cover_width = .81 if kind == "locker_container" else (.8 if kind == "safe" else 1.2)
		var depth: float = .31 if kind == "locker_container" else (.32 if kind == "safe" else .43)
		cover = Node3D.new()
		cover.position = Vector3(-cover_width*.5, 0, depth)
		var leaf: Node3D = ART.model("locker_door" if kind == "locker_container" else ("safe_door" if kind == "safe" else "cage_door"))
		leaf.position = Vector3(cover_width*.5, 0, -depth)
		cover.add_child(leaf)
		add_child(cover)
		cover_collider = CollisionShape3D.new()
		var lid_shape := BoxShape3D.new()
		lid_shape.size = Vector3(cover_width, box.size.y, .06)
		cover_collider.shape = lid_shape
		add_child(cover_collider)
	collider = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collider.shape = shape
	if kind in ["safe", "locker_container", "cage"]:
		# Back panel stays solid while the front is open and contents are targetable.
		shape.size.z = .12
		collider.position.z = -.27 if kind != "cage" else -.4
	add_child(collider)
	label = Label3D.new()
	label.text = title
	label.position.y = box.size.y * 0.5 + 0.2
	label.font_size = 23
	label.pixel_size = 0.0035
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("b9ccc2")
	label.visibility_range_end = 3.2
	add_child(label)
	if kind in ["generator", "power", "transmitter", "ventilation", "vehicle"]:
		label.hide()
	if kind == "door":
		# The wall switch stays targetable while the actual door collision is open.
		var switch := StaticBody3D.new()
		switch.collision_layer = 4
		switch.collision_mask = 0
		switch.set_meta("door_switch", true)
		switch.position = Vector3(0.0, 0.15, 1.1)
		add_child(switch)
		var button_mesh := ART.model("power")
		button_mesh.scale = Vector3.ONE * .32
		button_mesh.rotation.y = signf(position.x) * PI / 2
		switch.add_child(button_mesh)
		var button_shape := CollisionShape3D.new()
		var button_collision := BoxShape3D.new()
		button_collision.size = Vector3(.3, .35, .22)
		button_shape.shape = button_collision
		switch.add_child(button_shape)
		label.hide()
	if kind == "vehicle":
		var view := Node.new()
		view.set_script(preload("res://scripts/art/vehicle_view.gd"))
		view.vehicle = self
		add_child(view)
	refresh()

func refresh() -> void:
	visible = not taken and not concealed
	if is_instance_valid(collider):
		collider.set_deferred("disabled", taken or concealed)
	if is_instance_valid(cover):
		cover_collider.rotation.y = -PI*.62 if opened else 0.0
		cover_collider.position = cover.position + Basis(Vector3.UP, cover_collider.rotation.y) * Vector3(cover_width*.5, 0, 0)
	if is_instance_valid(mesh) and kind == "door":
		mesh.rotation.y = (-1.0 if position.x >= 0 else 1.0) * PI / 2 if opened else 0.0
		collider.rotation.y = mesh.rotation.y
		collider.position = mesh.position + Basis(Vector3.UP, mesh.rotation.y) * Vector3(0, 0, -1.09)
	if is_instance_valid(label) and kind == "door":
		label.text = ("[E] Закрыть" if opened else "[E] Открыть") + (" • нужен ключ" if locked else "")

func _process(delta: float) -> void:
	if cover:
		cover.rotation.y = lerp_angle(cover.rotation.y, -PI*.62 if opened else 0.0, minf(1, delta*10))
	if not is_instance_valid(GameManager.world):
		return
	var goals: Node = GameManager.world.objectives
	if kind == "hospital_control":
		var index: int = int(object_id.get_slice("_",1))
		if object_id.begins_with("pressure_"): title = "Давление %s: %d" % [["I","II","III"][index],goals.pressure[index]]
		elif object_id.begins_with("mixture_"): title = "Реагент %s: %d" % [["A","B","C"][index],goals.mixture[index]]
		label.text = title
	if kind == "relay":
		var index: int = int(object_id.trim_prefix("relay_"))
		title = "Реле %s: %d • переключить" % [["A", "B", "C"][index], goals.relay_values[index]]
		label.text = title
	if kind in ["valve", "tuner"]:
		var index: int = int(object_id.get_slice("_", 1))
		var values: Array = GameManager.world.sectors.valves if kind == "valve" else GameManager.world.sectors.frequency
		title = ("Вентиль %s: %d" if kind == "valve" else "Частота %s: %d") % [["A","B","C"][index], values[index]]
		label.text = title
		if kind == "valve": mesh.rotation.z = -float(values[index])*TAU/4
	if warning_light:
		warning_light.visible = goals.emergency == kind
		warning_light.light_energy = .45 + .35 * sin(Time.get_ticks_msec() * .008)
	if goals.generator_on and goals.emergency != "ventilation":
		for rotor: Node3D in rotors:
			rotor.rotation.z += delta * 9

func _paper() -> Node3D:
	var root := Node3D.new()
	var paper := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.29, .008, .35)
	paper.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("b6a780")
	mat.roughness = .95
	paper.material_override = mat
	root.add_child(paper)
	var text := Label3D.new()
	text.text = "РС—17\nЖУРНАЛ\n\n________\n________"
	text.font_size = 28
	text.pixel_size = .0011
	text.rotation.x = -PI/2
	text.position.y = .006
	text.modulate = Color("292e28")
	text.outline_size = 0
	root.add_child(text)
	return root
