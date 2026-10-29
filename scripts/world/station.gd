extends Node3D
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MONSTER_SCENE := preload("res://scenes/monster.tscn")
const OBJECT_SCRIPT := preload("res://scripts/world/interactable.gd")
const ART := preload("res://scripts/art/art_factory.gd")
var rules: Dictionary
var map_id: int = 0
var layout: Script
var calm_zones: Array = [Vector3(9,0,8)]
var light_clock: float = 0.0
var walls_for_map: Array[Rect2] = []
var players: Node3D
var spawner: MultiplayerSpawner
var monster: CharacterBody3D
var items: Node
var objectives: Node
var objects: Dictionary = {}
var lights: Array[OmniLight3D] = []
var astar := AStarGrid2D.new()
var environment: Environment
var elapsed: float = 0.0
var state_clock: float = 0.0
var event_clock: float = 25.0
var flicker: float = 0.0
var was_holding: Dictionary = {}
var revive_progress: Dictionary = {}
var materials: Dictionary = {}
var navigation_blocks: Array[AABB] = []
var atmosphere: Node3D
var sectors: Node
var drainage: Node
var static_navigation_count: int = 0
var last_speech_take: int = -1
var base_navigation: Dictionary = {}
const DEPOT := preload("res://scripts/world/depot_layout.gd")
const LAYOUT := preload("res://scripts/world/sector_layout.gd")

func _ready() -> void:
	GameManager.world = self
	map_id = NetworkManager.map_id
	layout = NetworkManager.MAPS.layout(map_id)
	rules = NetworkManager.RULES.profile(NetworkManager.difficulty)
	if map_id == 1:
		rules.chase_speed *= 1.08
		rules.sabotage_delay *= .85
	if map_id == 2:
		rules.ambient *= .35
		rules.lighting *= .75
		rules.sabotage_delay *= .8
	players = Node3D.new()
	players.name = "Players"
	add_child(players)
	spawner = MultiplayerSpawner.new()
	spawner.name = "PlayerSpawner"
	spawner.spawn_path = NodePath("../Players")
	spawner.spawn_limit = 4
	spawner.spawn_function = _create_player
	add_child(spawner)
	items = Node.new()
	items.set_script(preload("res://scripts/world/item_system.gd"))
	items.name = "ItemSystem"
	items.station = self
	add_child(items)
	objectives = Node.new()
	objectives.set_script(NetworkManager.MAPS.objectives(map_id))
	objectives.name = "ObjectiveSystem"
	objectives.station = self
	add_child(objectives)
	sectors = Node.new()
	sectors.set_script(preload("res://scripts/world/sector_system.gd"))
	sectors.name = "SectorSystem"
	sectors.station = self
	add_child(sectors)
	drainage = Node.new()
	drainage.set_script(preload("res://scripts/world/drainage_system.gd"))
	drainage.name = "DrainageSystem"
	drainage.station = self
	add_child(drainage)
	_build_station()
	atmosphere = Node3D.new()
	atmosphere.set_script(preload("res://scripts/art/station_atmosphere.gd"))
	add_child(atmosphere)
	atmosphere.build(self)
	if map_id == 0:
		for i: int in range(3):
			var kind: String = "sedative" if i < 2 else "thermos"
			var item: Node3D = add_object("calm_supply_%d" % i,kind,items.NAMES[kind],Vector3(9,.4,8))
			item.container_id = "medical_empty_locker"
		sign_text("ПУНКТ ОТДЫХА • СВЕТ И ЧАЙ",Vector3(9,2.0,12.7),PI,20)
	_ground_loose_items.call_deferred()
	static_navigation_count = navigation_blocks.size()
	# Only the authoritative host runs pathfinding. Building AStar on clients
	# stalls packet polling during initial loot replication on the larger map.
	if multiplayer.is_server():
		_register_equipment_obstacles()
		_build_navigation()
	if "--no-batching" not in OS.get_cmdline_user_args(): _batch_architecture()
	monster = MONSTER_SCENE.instantiate()
	monster.name = "Monster"
	monster.station = self
	monster.position = Vector3(0, 0.1, -10)
	add_child(monster)
	SettingsManager.changed.connect(apply_quality)
	apply_quality()
	AudioManager.set_ambience(true)
	NetworkManager.world_ready.call_deferred()

func _exit_tree() -> void:
	AudioManager.set_ambience(false)
	if GameManager.world == self:
		GameManager.world = null

func _create_player(data: Dictionary) -> Node:
	var player := PLAYER_SCENE.instantiate()
	player.name = str(data.id)
	player.peer_id = int(data.id)
	player.nickname = str(data.nickname)
	player.role = str(data.role)
	player.net_position = data.position
	player.position = data.position
	# Authority stays 1, including StateSync. Identity is separate from authority.
	return player

func spawn_players() -> void:
	if not multiplayer.is_server():
		return
	if map_id == 0:
		randomize_puzzles()
		preload("res://scripts/world/loot_spawns.gd").apply(self)
	elif map_id == 1:
		objectives.randomize_round()
		preload("res://scripts/world/depot_loot.gd").apply(self)
	else:
		objectives.randomize_round()
		preload("res://scripts/world/hospital_loot.gd").apply(self)
	_refresh_equipment_navigation()
	_ground_loose_items.call_deferred()
	var index: int = 0
	for id: int in NetworkManager.members:
		spawner.spawn({"id": id, "nickname": NetworkManager.members[id].name, "role": NetworkManager.role_id(id), "position": Vector3(-1.2 + (index % 2) * 2.0, 0.15, 10.5 - floori(index / 2.0) * 1.8)})
		index += 1
	sync_state()

func randomize_puzzles() -> void:
	var previous: Dictionary = NetworkManager.last_puzzles
	var code: String = str(randi_range(100, 999))
	while code == previous.get("safe", ""): code = str(randi_range(100, 999))
	objects.fuse_safe.code = code
	objects.safe_note.description = "КОД СЕЙФА ЭТОЙ СМЕНЫ: %s\nПредохранитель — на складе A—01. Ключ от клетки — в шкафчике A—07." % code
	objectives.relay_solution = _new_digits(4, previous.get("relays", []))
	sectors.valve_solution = _new_digits(4, previous.get("valves", []))
	sectors.frequency_solution = _new_digits(10, previous.get("frequency", []))
	objects.relay_note.description = "РЕЗЕРВНЫЕ РЕЛЕ ЭТОЙ СМЕНЫ\nA: %d • B: %d • C: %d\nНастройте в релейной A—09." % objectives.relay_solution
	objects.pressure_note.description = "КОНТУР B • ПЛАН СМЕНЫ\nВентиль A: %d • B: %d • C: %d\nПосле давления восстановите фильтрацию C." % sectors.valve_solution
	objects.frequency_note.description = "НЕСУЩАЯ ЭТОЙ СМЕНЫ\nРазряды D: %d / %d / %d\nЩит резервного питания остаётся в A—06." % sectors.frequency_solution
	NetworkManager.last_puzzles = {"safe":code, "relays":objectives.relay_solution.duplicate(), "valves":sectors.valve_solution.duplicate(), "frequency":sectors.frequency_solution.duplicate()}
	sectors.randomize_round()
	while sectors.circuit == previous.get("circuit",[]): sectors.randomize_round()
	NetworkManager.last_puzzles.circuit = sectors.circuit.duplicate()
	drainage.randomize_round()

func _new_digits(base: int, previous: Array) -> Array:
	var value: Array = [randi_range(0,base-1),randi_range(0,base-1),randi_range(0,base-1)]
	while value == previous or value == [0,0,0]:
		value = [randi_range(0,base-1),randi_range(0,base-1),randi_range(0,base-1)]
	return value

func _ground_loose_items() -> void:
	if not multiplayer.is_server(): return
	await get_tree().physics_frame
	for object: Node3D in objects.values():
		if object.kind not in ["battery","medkit","shell","sedative","thermos"] or not object.container_id.is_empty(): continue
		var bottom: float = INF
		for part: Node3D in object.mesh.find_children("*","MeshInstance3D",true,false):
			var bounds: AABB = part.global_transform*part.get_aabb()
			bottom = minf(bottom,bounds.position.y)
		var ray := PhysicsRayQueryParameters3D.create(object.position+Vector3.UP*.03,object.position-Vector3.UP*2.0,1|4,[object.get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and is_finite(bottom): object.position.y += hit.position.y+.008-bottom
	if NetworkManager.in_match: sync_state()

func _register_equipment_obstacles() -> void:
	for object: Node3D in objects.values():
		if object.collision_layer != 4 or object.kind in ["door", "hatch"]: continue
		var shape: BoxShape3D = object.collider.shape
		var bounds: AABB = object.collider.global_transform*AABB(-shape.size*.5,shape.size)
		navigation_blocks.append(bounds)

func _refresh_equipment_navigation() -> void:
	navigation_blocks.resize(static_navigation_count)
	_register_equipment_obstacles()
	_build_navigation()

func remove_player(id: int) -> void:
	var player := players.get_node_or_null(str(id))
	if player:
		items.drop_all(player)
		player.queue_free() # MultiplayerSpawner replicates the despawn.
	was_holding.erase(id)
	revive_progress.erase(id)

func living_player_count() -> int:
	var count: int = 0
	for player: Node3D in players.get_children():
		if player.health > 0.0:
			count += 1
	return count

func material(color: String, emission: float = 0.0) -> StandardMaterial3D:
	if emission == 0.0:
		if color == "313c3e":
			return ART.surface("floor")
		if color in ["465354", "4c5b58", "475653", "45524f"]:
			return ART.surface("plaster")
		if color == "202c30":
			return ART.surface("concrete")
	var key := color + str(emission)
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 0.9
	mat.emission_enabled = emission > 0.0
	mat.emission = Color(color)
	mat.emission_energy_multiplier = emission
	materials[key] = mat
	return mat

func block(pos: Vector3, size: Vector3, color: String, solid: bool = true, glow: float = 0.0) -> Node3D:
	if solid and size.y >= 3.0 and size.y <= 3.25:
		size.y += .2
		pos.y += .1 # Overlap the ceiling instead of leaving a bright 10 cm seam.
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.position = pos
	add_child(root)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material(color, glow)
	mesh.set_meta("architecture",true)
	root.add_child(mesh)
	if solid and size.y >= 3.0:
		walls_for_map.append(Rect2(pos.x-size.x*.5,pos.z-size.z*.5,size.x,size.z))
		# A second surface follows the wall, sharing the existing box collision.
		var lower := MeshInstance3D.new()
		var lower_box := BoxMesh.new()
		lower_box.size = Vector3(size.x + .012, 1.16, size.z + .012)
		lower.mesh = lower_box
		lower.position.y = .58 - pos.y
		lower.material_override = ART.surface("paint")
		lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lower.set_meta("architecture",true)
		root.add_child(lower)
	if solid:
		if pos.y + size.y * 0.5 > 0.2 and pos.y - size.y * 0.5 < 1.0:
			navigation_blocks.append(AABB(pos - size * 0.5, size))
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		root.add_child(collider)
	return root

func sign_text(text: String, pos: Vector3, yaw: float = 0.0, size: int = 40) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.rotation.y = yaw
	label.font_size = size
	label.pixel_size = 0.006
	label.modulate = Color("bbd5c9")
	label.no_depth_test = false
	add_child(label)

func _build_station() -> void:
	var world_environment := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0c141b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("91a6ac")
	environment.ambient_light_energy = float(rules.ambient)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	if map_id != 0:
		layout.build(self)
		return
	for x: float in [-9.0, 0.0, 9.0]:
		for z: float in [-8.5, 0.0, 8.5]:
			block(Vector3(x, -.2, z), Vector3(12 if x != 0 else 6, .4, 9 if z != 0 else 8), "313c3e")
	block(Vector3(0, 3.4, 0), Vector3(30, 0.2, 26), "202c30")
	for x: float in [-15.0, 15.0]:
		block(Vector3(x, 1.6, 0), Vector3(0.3, 3.2, 26), "465354")
	for x: float in [-9,9]: block(Vector3(x,1.6,13),Vector3(12,3.2,.3),"465354")
	for x: float in [-9, 9]:
		block(Vector3(x, 1.6, -13), Vector3(12, 3.2, .3), "465354")
	for x: float in [-3.0, 3.0]:
		for z: float in [-11.0, -4.0, 4.0, 11.0]:
			var depth: float = 3.8 if absf(z) == 11.0 else 5.8
			block(Vector3(x, 1.6, z), Vector3(0.22, 3.2, depth), "4c5b58")
		for z: float in [-8.0, 0.0, 8.0]:
			door_frame(x, z)
	for z: float in [-4.0, 4.0]:
		for x: float in [-9.0, 9.0]:
			block(Vector3(x, 1.6, z), Vector3(12, 3.2, 0.22), "475653")
	for z: int in range(-12, 13, 2):
		# Thin walkway seams and wall trim add scale without extra textures.
		block(Vector3(0, 0.008, z), Vector3(5.7, 0.012, 0.025), "17272c", false)
	for x: float in [-2.82, 2.82]:
		for z: float in [-11, -4, 4, 11]:
			block(Vector3(x, 1.17, z), Vector3(.035, .045, 3.8 if absf(z) == 11 else 5.8), "807c5f", false)
	var rooms := [
		["СКЛАД • 01", -9.0, 8.0], ["МЕДПУНКТ • 02", 9.0, 8.0],
		["ГЕНЕРАТОРНАЯ • 03", -9.0, 0.0], ["АРХИВ • 04", 9.0, 0.0],
		["ЖИЛОЙ БЛОК • 05", -9.0, -8.0], ["РАДИОРУБКА • 06", 9.0, -8.0]
	]
	for room: Array in rooms:
		var x: float = room[1]
		var z: float = room[2]
		var light := OmniLight3D.new()
		light.position = Vector3(x, 2.8, z)
		light.light_color = Color("a7c1b5") if x < 0 else Color("e8ba7c")
		light.omni_range = 6.5
		light.light_energy = 0.8
		light.set_meta("base_energy", .8)
		light.set_meta("standby", .23 if z == 8 else .08)
		add_child(light)
		lights.append(light)
		sign_text(str(room[0]), Vector3(x, 2.35, z - 3.78), 0.0, 34)
		var id := "door_%s_%s" % [int(x), int(z)]
		var door := add_object(id, "door", "Дверь", Vector3(signf(x) * 3.0, 1.44, z))
		door.opened = true
		if x > 0 and z == 0.0:
			door.opened = false
			door.locked = true
		door.refresh()
	for z: float in [-10.0, -2.0, 6.0, 11.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(0, 2.8, z)
		light.light_color = Color("e3c38b") if z in [6.0, -10.0] else Color("8ab0ad")
		light.omni_range = 5.5
		light.light_energy = 1.0
		light.set_meta("base_energy", 1.0)
		light.set_meta("standby", .45 if z == 6.0 else (.16 if z == -10 else .08))
		add_child(light)
		lights.append(light)
	sign_text("↓ E • ДРЕНАЖНЫЙ КОМПЛЕКС", Vector3(0, 2.7, 12.8), PI, 24)
	# Low-cost props, deliberately away from main routes and AI paths.
	for x: float in [-12.0, -7.0]:
		_prop_collision(Vector3(x, .8, 10.3), Vector3(2.4, 1.6, .8))
	for z: float in [-10.5, -5.4]:
		_prop_collision(Vector3(-11, .35, z), Vector3(3.2, .7, 1.2))
	_prop_collision(Vector3(11, .5, -10.3), Vector3(5.0, 1.0, .85))
	add_object("fuse", "fuse", "Предохранитель", Vector3(-7, 1.8, 10.2))
	add_object("fuel", "fuel", "Бензин", Vector3(-12, 1.95, 10.2))
	add_object("key", "key", "Ключ архива", Vector3(-11, 1.0, -10.4))
	add_object("cassette", "cassette", "Кассета №17", Vector3(10, 0.6, 1.5))
	add_object("battery_a", "battery", "Батарейка", Vector3(7.8, 1.17, 8.0))
	add_object("battery_b", "battery", "Батарейка", Vector3(-8, 0.25, -7))
	add_object("medkit", "medkit", "Аптечка", Vector3(11, 0.3, 9))
	add_object("generator", "generator", "ГЕНЕРАТОР • удерживать E", Vector3(-10, 0.6, 0))
	add_object("transmitter", "transmitter", "ПЕРЕДАТЧИК • удерживать E", Vector3(10, 0.8, -8))
	add_object("power", "power", "ЩИТ ПИТАНИЯ • удерживать E", Vector3(5.5, 1.2, -10.8))
	block(Vector3(5.5,.45,-10.73),Vector3(.12,.9,.12),"293e40",false)
	block(Vector3(5.5,.05,-10.73),Vector3(.65,.1,.5),"293e40",false)
	preload("res://scripts/world/station_extension.gd").build(self)
	LAYOUT.build(self)

func door_frame(x: float, z: float) -> void:
	block(Vector3(x, 3.09, z), Vector3(.32, .42, 2.28), "45524f")
	for side: float in [-1, 1]:
		block(Vector3(x, 1.44, z + side * 1.1), Vector3(.34, 2.88, .08), "293e40", false)

func _prop_collision(pos: Vector3, size: Vector3) -> void:
	var body := block(pos, size, "283d35")
	for child: Node in body.get_children():
		if child is MeshInstance3D:
			child.hide()

func add_object(id: String, kind: String, title: String, pos: Vector3) -> Node3D:
	var object := StaticBody3D.new()
	object.set_script(OBJECT_SCRIPT)
	object.object_id = id
	object.kind = kind
	object.title = title
	object.position = pos
	object.name = id
	objects[id] = object
	add_child(object)
	return object

@rpc("authority", "call_local", "reliable")
func create_drop(id: String, kind: String, pos: Vector3) -> void:
	if not objects.has(id):
		add_object(id, kind, items.NAMES.get(kind, kind), pos)

func apply_quality() -> void:
	environment.fog_enabled = true
	environment.fog_light_color = Color("334851")
	if map_id==2: environment.fog_light_color = Color("0a1312")
	environment.fog_density = [.005, .009, .013][SettingsManager.quality]
	# Compatibility supports depth fog; volumetric fog/SSR require Forward+.
	environment.volumetric_fog_enabled = false
	environment.ssr_enabled = false
	for light: OmniLight3D in lights:
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = 14.0
		light.distance_fade_length = 5.0

func _batch_architecture() -> void:
	var groups: Dictionary = {}
	for part: Node in find_children("*","MeshInstance3D",true,false):
		if not part.has_meta("architecture") or not part.visible: continue
		var key: String = layout.sector_at(part.global_position)+str(part.material_override.get_rid())+str(part.cast_shadow)
		if not groups.has(key): groups[key] = []
		groups[key].append(part)
	for group: Array in groups.values():
		var batch := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		multi.mesh = box
		multi.instance_count = group.size()
		batch.multimesh = multi
		batch.material_override = group[0].material_override
		batch.cast_shadow = group[0].cast_shadow
		add_child(batch)
		for i: int in range(group.size()):
			var part: MeshInstance3D = group[i]
			var transform: Transform3D = part.global_transform
			transform.basis = transform.basis.scaled(part.mesh.size)
			multi.set_instance_transform(i,transform)
			part.queue_free()
		batch.set_meta("architecture_batch",true)

func _build_navigation() -> void:
	astar.region = layout.EXTENT
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for x: int in range(astar.region.position.x, astar.region.end.x):
		for z: int in range(astar.region.position.y, astar.region.end.y):
			var floor_found: bool = false
			for floor_region: Rect2 in layout.FLOORS:
				if floor_region.has_point(Vector2(x, z)): floor_found = true; break
			var wall: bool = not floor_found
			if floor_found:
				for bounds: AABB in navigation_blocks:
					if x > bounds.position.x - .4 and x < bounds.end.x + .4 and z > bounds.position.z - .4 and z < bounds.end.z + .4:
						wall = true
						break
			base_navigation[Vector2i(x, z)] = wall
			astar.set_point_solid(Vector2i(x, z), wall)
	_update_doors_navigation()

func _update_doors_navigation() -> void:
	if base_navigation.is_empty(): return
	# Restore static occupancy around doors before applying all current leaf poses.
	for object: Node3D in objects.values():
		if object.kind == "door":
			for x: int in range(roundi(object.position.x)-3, roundi(object.position.x)+4):
				for z: int in range(roundi(object.position.z)-3, roundi(object.position.z)+4):
					var cell := Vector2i(x, z)
					if base_navigation.has(cell): astar.set_point_solid(cell, base_navigation[cell])
	for object: Node3D in objects.values():
		if object.kind != "door": continue
		var shape: BoxShape3D = object.collider.shape
		var bounds: AABB = object.collider.global_transform * AABB(-shape.size*.5, shape.size)
		bounds = bounds.grow(.35)
		for x: int in range(ceili(bounds.position.x), floori(bounds.end.x)+1):
			for z: int in range(ceili(bounds.position.z), floori(bounds.end.z)+1):
				if astar.is_in_boundsv(Vector2i(x,z)): astar.set_point_solid(Vector2i(x,z), true)

func find_path(from: Vector3, to: Vector3, for_monster: bool = false) -> PackedVector3Array:
	if for_monster:
		for object: Node3D in objects.values():
			if object.kind == "door" and not object.locked:
				astar.set_point_solid(Vector2i(roundi(object.position.x), roundi(object.position.z)), false)
	var start := _nearest_walkable(Vector2i(clampi(roundi(from.x), -63, 63), clampi(roundi(from.z), -105, 66)))
	var goal := _nearest_walkable(Vector2i(clampi(roundi(to.x), -63, 63), clampi(roundi(to.z), -105, 66)))
	var path := PackedVector3Array()
	if astar.is_point_solid(start) or astar.is_point_solid(goal):
		_update_doors_navigation()
		return path
	for point: Vector2 in astar.get_point_path(start, goal):
		path.append(Vector3(point.x, 0.05, point.y))
	if for_monster:
		_update_doors_navigation()
	return path

func _nearest_walkable(point: Vector2i) -> Vector2i:
	if not astar.is_point_solid(point):
		return point
	for radius: int in range(1, 3):
		for offset: Vector2i in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius)]:
			var candidate := point + offset
			if astar.is_in_boundsv(candidate) and not astar.is_point_solid(candidate):
				return candidate
	return point

func target_for(player: Node3D) -> Object:
	var origin: Vector3 = player.eye_position()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + player.look_direction() * 2.6, 23, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Object = hit.get("collider")
	if target and target.has_meta("door_switch"):
		return target.get_parent()
	return target

func can_see(from: Vector3, player: Node3D, exclude: Array = []) -> bool:
	var excluded_rids: Array[RID] = []
	excluded_rids.assign(exclude)
	var query := PhysicsRayQueryParameters3D.create(from, player.eye_position(), 7, excluded_rids)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == player

func _physics_process(delta: float) -> void:
	if not NetworkManager.in_match:
		return
	elapsed += delta
	flicker = maxf(0.0, flicker - delta)
	light_clock -= delta
	if light_clock <= 0:
		light_clock = .1
		var local: Node3D = GameManager.local_player()
		var nearest: OmniLight3D
		var distance: float = 10.0
		for light: OmniLight3D in lights:
			var base: float = float(light.get_meta("base_energy",1.0))
			var faulty: float = .96+sin(elapsed*9.0+light.position.z)*.04
			if bool(light.get_meta("hospital_fault",false)): faulty = .06 if sin(elapsed*2.1+light.position.z)>.4 else .82
			light.light_energy = base*(1.35 if objectives.generator_on else float(light.get_meta("standby",.3)))*faulty*float(rules.lighting)*(.04 if flicker>0 else 1.0)
			light.shadow_enabled = false
			if local and light.position.distance_to(local.position) < distance:
				nearest = light
				distance = light.position.distance_to(local.position)
		if nearest and SettingsManager.quality == 2: nearest.shadow_enabled = true
	if not multiplayer.is_server():
		return
	for actor: Node3D in players.get_children():
		actor.healing_progress = 0.0
		actor.rescue_progress = 0.0
	objectives.begin_frame()
	for player: Node3D in players.get_children():
		var id: int = player.peer_id
		var using: bool = player.holding and player.input_age <= 0.3 and player.health > 0.0 and objectives.result.is_empty()
		if using:
			var target: Object = target_for(player)
			if target:
				if target.is_in_group("players"):
					_revive_target(player, target, delta)
				elif target.get("object_id") != null:
					revive_progress.erase(id)
					if target.kind in ["generator", "transmitter", "power", "ventilation", "purifier", "drain_pump", "vehicle", "hospital_station"]:
						objectives.interact(player, target)
					elif not bool(was_holding.get(id, false)):
						interact_object(player, target)
				else:
					revive_progress.erase(id)
			else:
				revive_progress.erase(id)
		else:
			revive_progress.erase(id)
		was_holding[id] = using
	objectives.tick(delta)
	event_clock -= delta
	if event_clock <= 0.0 and objectives.result.is_empty():
		event_clock = randf_range(12.0, 22.0)
		flicker_event.rpc()
		_run_horror_event()
	state_clock -= delta
	if state_clock <= 0.0:
		state_clock = 0.2
		sync_state()

func _run_horror_event() -> void:
	if not multiplayer.is_server() or not objectives.result.is_empty() or not bool(rules.monster):
		return
	var living: Array[Node3D] = []
	for actor: Node3D in players.get_children():
		if actor.health > 0:
			living.append(actor)
	if living.is_empty():
		return
	var focus: Node3D = living.pick_random()
	var kind: int = randi_range(0, 2)
	var at := Vector3(0, 0, -9)
	var candidates: Array[Vector3] = [Vector3(0, 0, -9), Vector3(0, 0, -3), Vector3(0, 0, 5), Vector3(-7, 0, 0), Vector3(7, 0, -8), Vector3(-7, 0, -8)]
	if map_id==2:
		candidates = [Vector3(0,0,-80),Vector3(0,0,-55),Vector3(0,0,-20),Vector3(0,0,4),Vector3(0,0,36)]
		for room: Array in layout.map_rooms(): candidates.append(Vector3(room[0].get_center().x,0,room[0].get_center().y))
	candidates.shuffle()
	for candidate: Vector3 in candidates:
		var distance: float = candidate.distance_to(focus.position)
		if distance > 5.5 and distance < 12.0:
			at = candidate
			break
	if kind == 0:
		for object: Node3D in objects.values():
			if object.kind != "door" or not object.opened or object.locked or object.position.distance_to(focus.position) > 10:
				continue
			var clear: bool = true
			for actor: Node3D in players.get_children():
				if actor.position.distance_to(object.position) < 2.4:
					clear = false
			if is_instance_valid(monster) and monster.position.distance_to(object.position) < 2.4:
				clear = false
			if clear:
				object.opened = false
				object.refresh()
				_update_doors_navigation()
				at = Vector3(object.position.x, 0, object.position.z)
				sound_event.rpc("door", object.position)
				sync_state()
				break
	haunt_event.rpc(kind, at)

func interact_object(player: Node3D, object: Node3D) -> void:
	# Revalidate geometry even for host-side callers. Object IDs are never accepted from clients.
	if not multiplayer.is_server() or player.health <= 0.0 or target_for(player) != object:
		return
	if object.kind == "door":
		if object.locked:
			if not object.gate_rule.is_empty():
				if not sectors.is_unlocked(object.gate_rule):
					tell(player.peer_id, "Выезд откроется при запуске готовой машины." if map_id == 1 else "Шлюз D закрыт: нужны давление B и очистка воздуха C.")
					return
				object.locked = false
			elif not "key" in player.inventory:
				tell(player.peer_id, "Архив заперт. Ищите ключ в жилом блоке.")
				return
			object.locked = false
		if object.opened:
			if monster.position.distance_to(object.position - Vector3.UP * 1.44) < 2.1:
				return
			for other: Node3D in players.get_children():
				var local_at: Vector3 = object.to_local(other.global_position)
				if absf(local_at.x) < .6 and absf(local_at.z) < 1.3:
					return # Don't close a collision shape inside another player.
		object.opened = not object.opened
		object.refresh()
		_update_doors_navigation()
		make_noise(object.position, 7.0)
		sound_event.rpc("door", object.position)
		sync_state()
	elif object.kind in ["locker_container", "safe", "cage"]:
		if not object.gate_rule.is_empty() and not sectors.is_unlocked(object.gate_rule):
			tell(player.peer_id, "Хранилище заблокировано: завершите проверку отделения по журналам." if map_id == 2 else ("Хранилище заблокировано. Восстановите пусковой щит C." if map_id == 1 else "Хранилище заблокировано. Восстановите пульт C—01."))
			return
		if object.kind == "safe" and not object.opened:
			container_prompt.rpc_id(player.peer_id, object.object_id)
			return
		if object.locked and not object.required_key in player.inventory:
			tell(player.peer_id, "Ключ инструментального шкафа — в одном из медицинских шкафчиков больницы." if map_id == 2 else ("Нужен ключ клетки из шкафчика охраны E." if map_id == 1 else "Заперто. Служебный ключ — в шкафчике мастерской, сектор 07."))
			return
		object.locked = false
		object.opened = not object.opened
		object.refresh()
		refresh_containers()
		if object.opened:
			var contents: bool = false
			for item: Node3D in objects.values():
				if item.container_id == object.object_id and not item.taken: contents = true; break
			if not contents: tell(player.peer_id,"Шкаф осмотрен: пусто.")
		sound_event.rpc("door", object.position)
		sync_state()
	elif object.kind == "note":
		document_prompt.rpc_id(player.peer_id, object.title, object.description)
	elif object.kind == "hospital_control": objectives.control(player,object)
	elif object.kind == "depot_dial": objectives.turn_dial(player,object)
	elif object.kind == "drain_switch": drainage.press(player,object)
	elif object.kind in ["valve", "tuner", "circuit"]:
		sectors.handle_object(player, object)
	elif object.kind == "relay":
		var index: int = int(object.object_id.trim_prefix("relay_"))
		objectives.relay_values[index] = (int(objectives.relay_values[index]) + 1) % 4
		tell(player.peer_id, "Реле %s: %d" % [["A", "B", "C"][index], objectives.relay_values[index]])
		sound_event.rpc("knock", object.position)
		sync_state()
	elif object.kind == "hatch":
		if player.crouched:
			player.start_vent(object.destination)
			make_noise(object.position, 20)
			sound_event.rpc("scrape", object.position)
		else:
			tell(player.peer_id, "Присядьте, чтобы пролезть в вентканал.")
	else:
		items.pickup(player, object)

func refresh_containers() -> void:
	for object: Node3D in objects.values():
		if not object.container_id.is_empty():
			object.concealed = not objects[object.container_id].opened
			object.refresh()

@rpc("authority", "call_local", "reliable")
func container_prompt(id: String) -> void:
	GameManager.interface.open_safe(id)

@rpc("any_peer", "call_local", "reliable")
func unlock_safe(id: String, code: String) -> void:
	if not multiplayer.is_server() or not NetworkManager.in_match or not objects.has(id):
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1
	var player: Node3D = players.get_node_or_null(str(sender))
	var object: Node3D = objects[id]
	if not player or player.health <= 0 or not objectives.result.is_empty() or object.kind != "safe" or target_for(player) != object:
		return
	if code == object.code:
		object.opened = true
		object.refresh()
		refresh_containers()
		sync_state()
	else:
		tell(sender,"Неверный код. "+NetworkManager.MAPS.safe_hint(map_id))
	make_noise(object.position, 10)

@rpc("authority", "call_local", "reliable")
func document_prompt(title: String, content: String) -> void:
	GameManager.interface.show_document(title, content)

@rpc("authority", "call_local", "reliable")
func circuit_prompt() -> void:
	GameManager.interface.open_circuit()

@rpc("any_peer", "call_local", "reliable")
func circuit_command(number: int, index: int) -> void:
	if not multiplayer.is_server() or not NetworkManager.in_match or number != NetworkManager.round_id or not objectives.result.is_empty(): return
	var id: int = multiplayer.get_remote_sender_id()
	if id == 0: id = 1
	var actor: Node3D = players.get_node_or_null(str(id))
	if not actor or actor.health <= 0 or target_for(actor) != objects.circuit: return
	sectors.toggle_circuit(index)

@rpc("authority", "call_local", "reliable")
func announce(message: String) -> void:
	GameManager.notice(message)
	if message.begins_with("АВАРИЯ"):
		AudioManager.play_local("alarm")

func _revive_target(player: Node3D, other: Node3D, delta: float) -> void:
	if other.health > 0.0 or other.dead:
		revive_progress.erase(player.peer_id)
		return
	var entry: Dictionary = revive_progress.get(player.peer_id, {"target": other.peer_id, "time": 0.0})
	if int(entry.target) != other.peer_id:
		entry = {"target": other.peer_id, "time": 0.0}
	entry.time += delta * (2.0 if player.is_medic() else 1.0)
	revive_progress[player.peer_id] = entry
	player.healing_progress = float(entry.time)/6.0
	other.rescue_progress = maxf(other.rescue_progress,player.healing_progress)
	if float(entry.time) >= 6.0:
		other.revive()
		revive_progress.erase(player.peer_id)

func make_noise(pos: Vector3, radius: float) -> void:
	if multiplayer.is_server() and is_instance_valid(monster):
		monster.hear_noise(pos, radius)

@rpc("authority", "call_local", "unreliable", 2)
func sound_event(kind: String, pos: Vector3) -> void:
	AudioManager.play_at(kind, pos)

@rpc("authority", "call_local", "reliable", 2)
func monster_speech(pos: Vector3, take: int) -> void:
	if take < 0 or take >= AudioManager.sounds.get("monster_voice",[]).size(): return
	last_speech_take = take
	AudioManager.play_at("monster_voice",pos,0,take)
	var listener: Node3D=GameManager.local_player()
	if listener and listener.eye_position().distance_to(pos)<=40 and take<AudioManager.speech_captions.size():
		GameManager.interface.show_monster_caption(str(AudioManager.speech_captions[take]),AudioManager.sounds.monster_voice[take].get_length())

@rpc("authority", "call_local", "unreliable", 2)
func player_step(at: Vector3, yaw: float, left: bool, bloody: bool, quiet: bool) -> void:
	var kind: String = "step"
	if (absf(at.x)>15 and absf(at.x)<27) or (at.z < -51 and at.z > -63): kind = "step_metal"
	elif at.x < -27: kind = "step_gravel"
	if map_id == 2: kind = "step_metal" if at.x>18 and at.z>-51 and at.z<11 else "step"
	AudioManager.play_at(kind, at, -6.0 if quiet else 0.0)
	atmosphere.get_node("Footprints").stamp(at+Vector3.UP*.034, yaw, left, bloody)

func is_bloody(at: Vector3) -> bool:
	var pools: Array=atmosphere.get_node("BloodTraces").get_children()
	if is_instance_valid(monster) and is_instance_valid(monster.wounds):
		for pool: Node3D in monster.wounds.pools:
			if pool.visible: pools.append(pool)
	for pool: Node3D in pools:
		if pool.has_meta("blood_radius"):
			var radius: Vector2 = pool.get_meta("blood_radius")
			var delta: Vector3 = at-pool.global_position
			if Vector2(delta.x/radius.x,delta.z/radius.y).length() < .8: return true
	return false

@rpc("authority", "call_local", "reliable")
func shot_event(id: int) -> void:
	var player: Node3D = players.get_node_or_null(str(id))
	if player:
		player.show_shot()

@rpc("authority", "call_local", "reliable")
func flicker_event() -> void:
	flicker = 2.0

@rpc("authority", "call_local", "reliable")
func haunt_event(kind: int, pos: Vector3) -> void:
	atmosphere.trigger(kind, pos)

func tell(id: int, message: String) -> void:
	if id == multiplayer.get_unique_id():
		GameManager.notice(message)
	else:
		private_notice.rpc_id(id, message)

@rpc("authority", "call_remote", "reliable")
func private_notice(message: String) -> void:
	GameManager.notice(message)

func sync_state() -> void:
	if not multiplayer.is_server():
		return
	var state: Dictionary = {}
	for id: String in objects:
		var object: Node3D = objects[id]
		state[id] = [object.taken, object.opened, object.locked, object.position, object.container_id]
	receive_state.rpc(objectives.snapshot(), state)

@rpc("authority", "call_remote", "reliable")
func receive_state(goal: Dictionary, state: Dictionary) -> void:
	objectives.apply_snapshot(goal)
	for id: String in state:
		if objects.has(id):
			objects[id].taken = bool(state[id][0])
			objects[id].opened = bool(state[id][1])
			objects[id].locked = bool(state[id][2])
			objects[id].position = state[id][3]
			objects[id].container_id = state[id][4]
			objects[id].refresh()
	refresh_containers()
