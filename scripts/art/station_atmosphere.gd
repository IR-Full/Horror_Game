extends Node3D
const ART := preload("res://scripts/art/art_factory.gd")
var station: Node3D
var time: float = 0.0
var apparition: Node3D
var apparition_time: float = 0.0
var overlay: ShaderMaterial
var heartbeat_clock: float = 0.0
var last_health: float = 100.0
var damage_flash: float = 0.0
var emergency_lights: Array[OmniLight3D] = []
var dust: MultiMeshInstance3D
var dust_seeds: Array[Vector3] = []
var generator_sound: AudioStreamPlayer3D

func build(world: Node3D) -> void:
	station = world
	name = "Atmosphere"
	_build_details()
	_build_overlay()
	_build_dust()
	if AudioManager.sounds.has("motor"):
		generator_sound = AudioStreamPlayer3D.new()
		generator_sound.stream = AudioManager.sounds.motor
		generator_sound.position = Vector3(-10, .8, 0)
		generator_sound.volume_db = -20
		generator_sound.max_distance = 15
		add_child(generator_sound)
	SettingsManager.changed.connect(_quality_changed)
	_quality_changed()

func prop(kind: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var model := ART.model(kind)
	model.position = at
	model.rotation.y = yaw
	add_child(model)
	return model

func _build_details() -> void:
	# Decorative models share the exact collision footprints of the old blockout.
	for x: float in [-12.0, -7.0]:
		prop("shelf", Vector3(x, 0, 10.3))
	for z: float in [-10.5, -5.4]:
		prop("cot", Vector3(-11, 0, z))
	for x: float in [7.0, 10.0, 13.0]:
		prop("locker", Vector3(x, 0, -2.4), PI)
	prop("desk", Vector3(9.5, 0, -10.3), PI)
	prop("desk", Vector3(12, 0, -10.3), PI)
	prop("recorder", Vector3(11.5, 1.17, -10.3))
	for pos: Vector3 in [Vector3(13.6, 0, -11.3), Vector3(7.2, 0, -11.3)]:
		prop("radio_rack", pos, PI)
		_collision_box(pos + Vector3(0, 1, 0), Vector3(.8, 2, .65))
	station.block(Vector3(10, .12, -8), Vector3(1.65, .24, .7), "1c2f2c")
	# Front windows carry a cold, faint mountain silhouette.
	for x: float in [-11.0, -7.0, 7.0, 11.0]:
		_window(Vector3(x, 2.0, -12.8))
	for z: float in [-10, -2, 6, 11]:
		prop("lamp", Vector3(0, 3.16, z))
		# Surface-mounted cable trays and hanging wires, no transparent fog cones.
		for x: float in [-1.8, 1.8]:
			_pipe(Vector3(x, 3.12, z - 1.0), Vector3(x, 3.12, z + 1.0), .045, "5d645d")
	for x: float in [-9, 9]:
		for z: float in [-8, 0, 8]:
			prop("lamp", Vector3(x, 3.16, z))
	for x: float in [-2.62, 2.62]:
		_pipe(Vector3(x, 2.98, -12.7), Vector3(x, 2.98, 12.7), .065, "705844")
		for z: int in range(-12, 13, 3):
			station.block(Vector3(x, 2.98, z), Vector3(.2, .17, .07), "35423e", false)
	for z: float in [-6.0, 2.0]:
		for side: float in [-1, 1]:
			_pipe(Vector3(side * 2.9, 2.85, z), Vector3(side * 2.9, 2.0, z), .024, "161d1d")
			_pipe(Vector3(side * 2.9, 2.0, z), Vector3(side * 2.75, 1.85, z + .2), .024, "161d1d")
	# Room names now sit on physical sign plates beside the openings.
	var room_names: Array[String] = ["01  СКЛАД", "02  МЕДПУНКТ", "03  ГЕНЕРАТОРНАЯ", "04  АРХИВ", "05  ЖИЛОЙ БЛОК", "06  РАДИОРУБКА"]
	var index: int = 0
	for z: float in [8, 0, -8]:
		for side: float in [-1, 1]:
			var pos := Vector3(side * 2.83, 2.38, z)
			station.block(pos, Vector3(.035, .29, 1.8), "1b302e", false)
			station.sign_text(room_names[index], pos + Vector3(-side * .035, 0, 0), PI / 2 if side < 0 else -PI / 2, 16)
			index += 1
	for x: float in [-2.79, 2.79]:
		for z: float in [-11, -4, 4, 11]:
			# Peeling paint patches and grime at the base of the walls.
			station.block(Vector3(x, .27, z), Vector3(.02, .22, .7), "33483d", false)
	_poster(Vector3(-2.79, 1.8, 4.3), PI / 2, "ПОМНИ!", "НЕ ОСТАВЛЯЙ\nТОВАРИЩА\nВ ТЕМНОТЕ", "b5a27b")
	_poster(Vector3(2.79, 1.8, -4.5), -PI / 2, "ПРИКАЗ №17", "ЭФИР ПРЕРВАТЬ.\nНА ГОЛОСА\nНЕ ОТВЕЧАТЬ.", "9aab94")
	_poster(Vector3(-9.0, 1.75, 12.79), PI, "ТЕХНИКА БЕЗОПАСНОСТИ", "ПРОВЕРЬ ПИТАНИЕ\nПЕРЕД ВЫХОДОМ\nНА ЛИНИЮ", "a99b7b")
	# Flat boot marks and scuff trails are opaque meshes, inexpensive on Intel UHD.
	for i: int in range(13):
		var at := Vector3(0.4 + sin(i * .7) * .18, .014, 7.0 - i * .7)
		var mark: Node3D = station.block(at, Vector3(.16, .006, .31), "202925", false)
		mark.rotation.y = -.2 if i % 2 else .2
	# Existing colliders keep decorative objects from changing the network tests.
	for pos: Vector3 in [Vector3(-13.7, 0, 1.8), Vector3(-13.7, 0, .8), Vector3(13.7, 0, 10.8)]:
		prop("barrel", pos)
		_collision_box(pos + Vector3(0, .45, 0), Vector3(.75, .9, .75))
	for pos: Vector3 in [Vector3(-13.4, 0, 11.9), Vector3(12.8, 0, 11.8), Vector3(13.6, 0, -6)]:
		prop("crate", pos)
		_collision_box(pos + Vector3(0, .4, 0), Vector3(.85, .8, .8))
	prop("chair", Vector3(11.8, 0, -8.8), .4)
	prop("chair", Vector3(-13, 0, -7), -.3)
	# Med bay gets an examination couch and medicine lockers.
	var bed := prop("cot", Vector3(11.5, 0, 6.3))
	bed.scale.x = .8
	_collision_box(Vector3(11.5, .35, 6.3), Vector3(2.5, .7, 1.2))
	prop("locker", Vector3(13.7, 0, 5.3), PI / 2)
	_collision_box(Vector3(13.7, 1.1, 5.3), Vector3(.65, 2.2, .9))
	for pos: Vector3 in [Vector3(-2.65, 2.75, -5), Vector3(2.65, 2.75, 9)]:
		var red := OmniLight3D.new()
		red.position = pos
		red.light_color = Color("d76436")
		red.light_energy = .5
		red.omni_range = 3.3
		red.shadow_enabled = false
		add_child(red)
		emergency_lights.append(red)
		station.block(pos, Vector3(.16, .15, .22), "b85333", false, 1.2)
	# Main dispatch board at the end of the corridor.
	station.block(Vector3(0, 1.9, -12.77), Vector3(3.4, 1.5, .06), "172723", false)
	station.sign_text("РАДИОСТАНЦИЯ РС–17", Vector3(0, 2.23, -12.71), 0, 27)
	station.sign_text("СМЕНА НЕ ЗАКОНЧЕНА", Vector3(0, 1.83, -12.7), 0, 20)
	station.sign_text("НЕ СЛУШАЙТЕ ЧАСТОТУ 17.4", Vector3(0, 1.47, -12.7), 0, 15)
	apparition = ART.model("entity")
	apparition.hide()
	add_child(apparition)

func _collision_box(pos: Vector3, size: Vector3) -> void:
	var body: Node3D = station.block(pos, size, "202b27", true)
	for child: Node in body.get_children():
		if child is MeshInstance3D:
			child.hide()

func _pipe(a: Vector3, b: Vector3, radius: float, color: String) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 8
	mesh.mesh = cylinder
	mesh.material_override = station.material(color)
	mesh.position = (a + b) * .5
	mesh.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	add_child(mesh)

func _poster(pos: Vector3, yaw: float, heading: String, text: String, paper: String) -> void:
	var board := Node3D.new()
	board.position = pos
	board.rotation.y = yaw
	add_child(board)
	var panel := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.76, 1.03, .018)
	panel.mesh = box
	panel.material_override = station.material(paper)
	board.add_child(panel)
	for data: Array in [[heading, .34, 19], [text, -.02, 18]]:
		var label := Label3D.new()
		label.text = data[0]
		label.position = Vector3(0, data[1], .015)
		label.font_size = data[2]
		label.pixel_size = .003
		label.modulate = Color("24352d")
		label.outline_size = 0
		board.add_child(label)

func _window(pos: Vector3) -> void:
	station.block(pos, Vector3(2.7, 1.32, .09), "142831", false, .2)
	for x: float in [-1.4, 0, 1.4]:
		station.block(pos + Vector3(x, 0, .07), Vector3(.065, 1.45, .08), "4a5a52", false)
	for y: float in [-.7, 0, .7]:
		station.block(pos + Vector3(0, y, .07), Vector3(2.86, .06, .08), "4a5a52", false)
	station.block(pos + Vector3(0, -.8, .14), Vector3(3, .12, .3), "798276", false)
	# Simple mountain shapes behind dirty glass, still inside the closed wall.
	for x: float in [-.85, .3, .85]:
		var shape := MeshInstance3D.new()
		var cone := PrismMesh.new()
		cone.size = Vector3(1.0, .65, .025)
		shape.mesh = cone
		shape.position = pos + Vector3(x, -.25, .055)
		shape.material_override = station.material("263b3d")
		add_child(shape)

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay = ShaderMaterial.new()
	overlay.shader = preload("res://assets/shaders/atmosphere.gdshader")
	rect.material = overlay
	layer.add_child(rect)

func _build_dust() -> void:
	dust = MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var mote := SphereMesh.new()
	mote.radius = .007
	mote.height = .014
	mote.radial_segments = 4
	mote.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("b2b1a0")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote.material = mat
	multi.mesh = mote
	multi.instance_count = 64
	dust.multimesh = multi
	var rng := RandomNumberGenerator.new()
	rng.seed = 174
	for i: int in range(64):
		dust_seeds.append(Vector3(rng.randf_range(-2.3, 2.3), rng.randf_range(.7, 2.8), rng.randf_range(-11, 11)))
	add_child(dust)

func _quality_changed() -> void:
	dust.visible = SettingsManager.quality > 0
	dust.multimesh.visible_instance_count = 32 if SettingsManager.quality == 1 else 64

func trigger(kind: int, pos: Vector3) -> void:
	if kind == 2:
		apparition.position = pos
		var player := GameManager.local_player()
		if player and pos.distance_to(player.position) > 5:
			apparition.look_at(Vector3(player.position.x, pos.y, player.position.z))
			apparition_time = .9
			apparition.show()
	AudioManager.play_at(["knock", "whisper", "radio"][kind % 3], pos)

func _process(delta: float) -> void:
	if not is_instance_valid(station) or not NetworkManager.in_match:
		return
	time += delta
	if is_instance_valid(generator_sound) and station.objectives.generator_on and not generator_sound.playing:
		generator_sound.play()
	apparition_time -= delta
	if apparition_time <= 0.0:
		apparition.hide()
	if dust.visible:
		for i: int in range(dust_seeds.size()):
			var pos: Vector3 = dust_seeds[i] + Vector3(sin(time * .13 + i) * .12, sin(time * .21 + i) * .1, 0)
			dust.multimesh.set_instance_transform(i, Transform3D(Basis(), pos))
	for light: OmniLight3D in emergency_lights:
		light.light_energy = .4 + sin(time * 1.4) * .08
	var player := GameManager.local_player()
	if not player:
		return
	if player.health < last_health:
		damage_flash = .8
	last_health = player.health
	damage_flash = maxf(0, damage_flash - delta * .55)
	var stress: float = 0.0
	if is_instance_valid(station.monster) and station.monster.state != 0 and station.objectives.result.is_empty():
		stress = clampf(1.0 - player.position.distance_to(station.monster.position) / 10.0, 0, 1)
	overlay.set_shader_parameter("stress", stress)
	overlay.set_shader_parameter("damage", maxf(damage_flash, .4 if player.health <= 0 else 0))
	heartbeat_clock -= delta
	if stress > .25 and heartbeat_clock <= 0.0 and player.health > 0:
		heartbeat_clock = lerpf(1.5, .65, stress)
		AudioManager.play_local("heartbeat")
