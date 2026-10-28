extends CharacterBody3D
## Explicit finite state machine; only server runs perception and decisions.
enum State { DORMANT, PATROL, INVESTIGATE, CHASE, SEARCH, RETREAT }
var station: Node3D
var state: int = State.DORMANT
var net_position := Vector3.ZERO
var net_rotation: float = 0.0
var goal := Vector3.ZERO
var last_known := Vector3.ZERO
var path := PackedVector3Array()
var path_index: int = 0
var repath_clock: float = 0.0
var perception_clock: float = 0.0
var state_time: float = 0.0
var attack_clock: float = 0.0
var teleport_clock: float = 50.0
var target_id: int = 0
var mesh: Node3D
var visual_time: float = 0.0
var footstep_clock: float = 0.0
var animation: AnimationPlayer
var last_visual_position := Vector3.ZERO
var voice_clock: float = 0.0
var chase_started_at: float = 0.0
var crawl_amount: float = 0.0
var body_shape: CollisionShape3D
var clip_names: Dictionary = {}
var visual_mode: String = ""
var patrol_points: Array[Vector3] = [Vector3(0, 0, -10), Vector3(0, 0, 7), Vector3(-8, 0, 0), Vector3(8, 0, -8), Vector3(-7, 0, -8)]
var patrol_index: int = 0

func _ready() -> void:
	body_shape = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 2.45
	body_shape.shape = shape
	body_shape.position.y = 1.225
	add_child(body_shape)
	mesh = preload("res://scripts/art/art_factory.gd").model("entity")
	add_child(mesh)
	var found: Array[Node] = mesh.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		animation = found[0]
		for clip: StringName in animation.get_animation_list():
			var leaf: String = str(clip).split("|")[-1].split("/")[-1]
			clip_names[leaf] = clip
		_play_clip("Idle")
	preload("res://scripts/art/art_factory.gd").contact_shadow(self, Vector3.ZERO, Vector2(1.1, .85))
	last_visual_position = position
	var sync := MultiplayerSynchronizer.new()
	sync.name = "StateSync"
	sync.replication_interval = 0.1
	var config := SceneReplicationConfig.new()
	for property: String in ["net_position", "net_rotation", "state", "crawl_amount"]:
		var property_path := NodePath(".:" + property)
		config.add_property(property_path)
		config.property_set_replication_mode(property_path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config
	add_child(sync)
	net_position = position

func _process(delta: float) -> void:
	visual_time += delta
	mesh.rotation.z = sin(visual_time * 1.7) * .012
	body_shape.shape.height = lerpf(2.45, 1.15, crawl_amount)
	body_shape.position.y = body_shape.shape.height * .5
	if animation:
		var moving: bool = position.distance_squared_to(last_visual_position) > .000001
		if state == State.CHASE:
			if visual_mode not in ["DropToCrawl", "Crawl"]:
				_play_clip("DropToCrawl", false)
			elif visual_mode == "DropToCrawl" and not animation.is_playing():
				_play_clip("Crawl", true, 2.0)
		elif visual_mode in ["DropToCrawl", "Crawl"]:
			_play_clip("Rise", false)
		elif visual_mode == "Rise":
			if not animation.is_playing():
				_play_clip("Walk" if moving else "Idle")
		else:
			_play_clip("Walk" if moving else "Idle", true, 1.05)
	last_visual_position = position

func _play_clip(key: String, loop: bool = true, speed: float = 1.0) -> void:
	if not animation or not clip_names.has(key) or visual_mode == key:
		return
	visual_mode = key
	var clip: StringName = clip_names[key]
	animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	animation.speed_scale = speed
	animation.play(clip, .08)

func eye_position() -> Vector3:
	return position + Vector3.UP * lerpf(2.34, 1.08, crawl_amount)

func _physics_process(delta: float) -> void:
	visible = state != State.DORMANT
	if not NetworkManager.in_match or not station.objectives.result.is_empty():
		return
	if not multiplayer.is_server():
		position = position.lerp(net_position, minf(delta * 10.0, 1.0))
		rotation.y = lerp_angle(rotation.y, net_rotation, minf(delta * 10.0, 1.0))
		return
	state_time += delta
	attack_clock -= delta
	voice_clock -= delta
	crawl_amount = move_toward(crawl_amount, 1.0 if state == State.CHASE else 0.0, delta / .65)
	teleport_clock -= delta
	if state == State.DORMANT:
		if station.elapsed >= 30.0:
			change_state(State.PATROL, patrol_points[patrol_index])
		return
	perception_clock -= delta
	if perception_clock <= 0.0:
		perception_clock = 0.18
		_perceive()
	var target: Node3D = station.players.get_node_or_null(str(target_id))
	if state == State.CHASE:
		if target and target.health > 0.0:
			if position.distance_to(target.position) < 1.5 and station.elapsed - chase_started_at >= .65 and station.can_see(eye_position(), target, [get_rid()]):
				if attack_clock <= 0.0:
					attack_clock = 2.0
					target.damage(40.0)
			if state_time > 4.0:
				change_state(State.SEARCH, last_known)
		else:
			change_state(State.SEARCH, last_known)
	if state == State.SEARCH and state_time > 7.0:
		change_state(State.PATROL, patrol_points[patrol_index])
	if state == State.RETREAT and state_time > 2.5:
		change_state(State.SEARCH, last_known)
	if state in [State.PATROL, State.INVESTIGATE] and position.distance_to(goal) < 0.85:
		if state == State.INVESTIGATE:
			change_state(State.SEARCH, goal)
		else:
			patrol_index = (patrol_index + 1) % patrol_points.size()
			goal = patrol_points[patrol_index]
	if teleport_clock <= 0.0 and state == State.PATROL:
		teleport_clock = randf_range(45, 65)
		_try_relocate()
	repath_clock -= delta
	if repath_clock <= 0.0:
		repath_clock = 0.5
		path = station.find_path(position, goal)
		path_index = 1 if path.size() > 1 else 0
	var direction := Vector3.ZERO
	if path_index < path.size():
		var waypoint: Vector3 = path[path_index]
		waypoint.y = position.y
		if position.distance_to(waypoint) < 0.3:
			path_index += 1
		else:
			direction = (waypoint - position).normalized()
	var speed: float = 3.4 if state == State.CHASE else (2.3 if state == State.RETREAT else 1.25)
	if state == State.CHASE and station.elapsed - chase_started_at < .65:
		speed = .35 # A short, readable stare precedes the pursuit.
	if station.objectives.generator_on:
		speed *= 1.1
	velocity = Vector3(direction.x * speed, -0.5, direction.z * speed)
	move_and_slide()
	if state == State.CHASE and voice_clock <= 0.0:
		voice_clock = randf_range(3.4, 5.3)
		station.sound_event.rpc("growl", eye_position())
	footstep_clock -= delta
	if direction.length() > .1 and footstep_clock <= 0.0:
		footstep_clock = .18 if state == State.CHASE else .7
		station.sound_event.rpc("crawl_impact" if state == State.CHASE else "entity_step", position)
	if direction.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 6.0)
	net_position = position
	net_rotation = rotation.y

func change_state(next: int, destination: Vector3) -> void:
	if next == State.CHASE and state != State.CHASE:
		chase_started_at = station.elapsed
		if voice_clock <= 0.0:
			voice_clock = 4.0
			station.sound_event.rpc("roar", position + Vector3.UP * 1.7)
	state = next
	state_time = 0.0
	goal = destination
	repath_clock = 0.0

func hear_noise(pos: Vector3, radius: float) -> void:
	if state in [State.DORMANT, State.CHASE, State.RETREAT]:
		return
	var range_multiplier: float = 1.2 if station.objectives.generator_on else 1.0
	if position.distance_to(pos) <= radius * range_multiplier:
		last_known = pos
		change_state(State.INVESTIGATE, pos)

func _perceive() -> void:
	if state == State.RETREAT:
		return
	for player: Node3D in station.players.get_children():
		if player.health <= 0.0:
			continue
		var distance: float = position.distance_to(player.position)
		if distance > (14.0 if player.lamp_on else (6.0 if player.crouched else 10.0)):
			continue
		if not station.can_see(eye_position(), player, [get_rid()]):
			continue
		last_known = player.position
		target_id = player.peer_id
		var to_monster: Vector3 = (position + Vector3.UP * 1.5 - player.eye_position()).normalized()
		if player.lamp_on and player.battery > 0.0 and distance < 5.5 and player.look_direction().dot(to_monster) > 0.91:
			var away: Vector3 = position + (position - player.position).normalized() * 4.0
			away.x = clampf(away.x, -13, 13)
			away.z = clampf(away.z, -11, 11)
			change_state(State.RETREAT, away)
			return
		if state != State.CHASE:
			change_state(State.CHASE, player.position)
		else:
			goal = player.position
			state_time = 0.0
		return

func _try_relocate() -> void:
	var candidate: Vector3 = patrol_points.pick_random()
	for player: Node3D in station.players.get_children():
		if candidate.distance_to(player.position) < 9.0 or station.can_see(candidate + Vector3.UP, player, [get_rid()]):
			return
	position = candidate
	station.flicker_event.rpc()
	repath_clock = 0.0
