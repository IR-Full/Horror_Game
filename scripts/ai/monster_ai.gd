extends CharacterBody3D
## Explicit finite state machine; only server runs perception and decisions.
enum State { DORMANT, PATROL, INVESTIGATE, CHASE, SEARCH, RETREAT, STUNNED, SABOTAGE }
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
var stunned_left: float = 0.0
var lonely_time: float = 0.0
var rage_clock: float = 5.0
var speech_clock: float = 8.0
var speech_bag: Array[int] = []
var last_speech_take: int = -1
var gesture: String = ""
var gesture_left: float = 0.0
var sabotage_cooldown: float = 35.0
var sabotage_target: String = ""
var sabotage_striking: bool = false
var door_strike: float = 0.0
var stuck_clock: float = 0.0
var stuck_position := Vector3.ZERO
var front_shape: CollisionShape3D
var fell_crawling: bool = false
var recovery_left: float = 0.0
var fall_elapsed: float = 0.0
var fall_direction := Vector3.FORWARD
var fall_speed: float = 0.0
var fall_yaw: float = 0.0
var fall_center := Vector3.ZERO
var fall_cleared: bool = true
var blood_anchor := Vector3.ZERO
var hit_serial: int = 0
var impact_played: bool = false
var fall_probe: BoxShape3D
var wounds: Node3D
var patrol_points: Array[Vector3] = [Vector3(0, 0, -10), Vector3(0, 0, 7), Vector3(-8, 0, 0), Vector3(0, 0, -22), Vector3(-45, 0, -32), Vector3(-54, 0, -43), Vector3(45, 0, -32), Vector3(54, 0, -43), Vector3(0, 0, -44), Vector3(0, 0, -84), Vector3(-7, 0, -8),Vector3(0,0,35),Vector3(-12,0,46),Vector3(12,0,60)]
var patrol_index: int = 0

func _ready() -> void:
	if station.map_id == 1:
		patrol_points = [Vector3(0,0,-9),Vector3(-45,0,-18),Vector3(-54,0,-57),Vector3(45,0,-18),Vector3(54,0,-57),Vector3(0,0,-85),Vector3(0,0,33),Vector3(-12,0,42),Vector3(12,0,62)]
	if station.map_id == 2:
		patrol_points = [Vector3(0,0,12),Vector3(0,0,-20),Vector3(-41,0,-20),Vector3(-54,0,-42),Vector3(41,0,-20),Vector3(54,0,-42),Vector3(0,0,-80),Vector3(-17,0,-85),Vector3(17,0,-85),Vector3(0,0,54)]
	sabotage_cooldown = float(station.rules.sabotage_delay)
	body_shape = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.43
	shape.height = 2.67
	body_shape.shape = shape
	body_shape.position.y = 1.335
	add_child(body_shape)
	collision_layer = 8 if bool(station.rules.monster) else 0
	collision_mask = 1 | 2 | 4
	front_shape = CollisionShape3D.new()
	var front := SphereShape3D.new()
	front.radius = .39
	front_shape.shape = front
	front_shape.position = Vector3(0, 1.2, -.12)
	add_child(front_shape)
	mesh = preload("res://scripts/art/art_factory.gd").model(NetworkManager.MAPS.monster_model(station.map_id))
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
	fall_probe=BoxShape3D.new(); fall_probe.size=Vector3(1.1,.65,2.8)
	wounds=Node3D.new(); wounds.name="Wounds"; wounds.set_script(preload("res://scripts/art/monster_wounds.gd")); wounds.actor=self; add_child(wounds)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "StateSync"
	sync.replication_interval = 0.1
	var config := SceneReplicationConfig.new()
	for property: String in ["net_position", "net_rotation", "state", "crawl_amount", "stunned_left", "gesture", "gesture_left", "fell_crawling", "fall_elapsed", "blood_anchor", "hit_serial", "recovery_left"]:
		var property_path := NodePath(".:" + property)
		config.add_property(property_path)
		config.property_set_replication_mode(property_path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config
	add_child(sync)
	net_position = position

func _process(delta: float) -> void:
	visible = state != State.DORMANT and bool(station.rules.monster)
	if not bool(station.rules.monster):
		body_shape.disabled = true
		front_shape.disabled = true
		return
	visual_time += delta
	mesh.rotation.z = sin(visual_time * 1.7) * .012
	body_shape.shape.height = lerpf(2.67, 1.15, crawl_amount)
	body_shape.position.y = body_shape.shape.height * .5
	front_shape.position = Vector3(0, lerpf(2.28, .67, crawl_amount), lerpf(-.10, -.43, crawl_amount))
	body_shape.disabled = (state == State.STUNNED and fall_elapsed>=1.05) or recovery_left>0
	front_shape.disabled = state == State.STUNNED or recovery_left>0
	if animation:
		if state == State.STUNNED:
			if fall_elapsed>=fall_duration(): _play_clip("Down")
			elif visual_mode not in ["Fall", "FallCrawl", "Down"]:
				_play_clip("FallCrawl" if fell_crawling else "Fall", false)
				animation.seek(minf(fall_elapsed,fall_duration()),true)
			elif visual_mode in ["Fall", "FallCrawl"] and not animation.is_playing():
				_play_clip("Down")
			return
		if visual_mode in ["Fall", "FallCrawl", "Down", "GetUp"]:
			if visual_mode != "GetUp":
				_play_clip("GetUp", false)
			elif not animation.is_playing():
				_play_clip("Idle")
			return
		if gesture_left > 0 and (state != State.CHASE or gesture == "Bash"):
			_play_clip(gesture, false)
			return
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
	visible = state != State.DORMANT and bool(station.rules.monster)
	if not bool(station.rules.monster): return
	if not NetworkManager.in_match or not station.objectives.result.is_empty():
		return
	if not multiplayer.is_server():
		position = position.lerp(net_position, minf(delta * 10.0, 1.0))
		rotation.y = lerp_angle(rotation.y, net_rotation, minf(delta * 10.0, 1.0))
		return
	state_time += delta
	attack_clock -= delta
	voice_clock -= delta
	speech_clock -= delta
	gesture_left = maxf(0, gesture_left - delta)
	if state == State.STUNNED:
		_tick_fall(delta)
		stunned_left = maxf(0, stunned_left - delta)
		if stunned_left <= 0:
			change_state(State.SEARCH, position)
			recovery_left = 2.4
			gesture_left = 2.3
			gesture = "GetUp"
		return
	if recovery_left > 0:
		recovery_left = maxf(0, recovery_left - delta)
		return
	lonely_time += delta
	sabotage_cooldown -= delta
	rage_clock -= delta
	if state not in [State.DORMANT, State.CHASE, State.RETREAT] and rage_clock <= 0 and gesture_left <= 0 and voice_clock <= 0:
		rage_clock = randf_range(6, 11)
		gesture = "Roar" if randf() < .5 else "Bash"
		gesture_left = 1.3
		station.sound_event.rpc("roar" if gesture == "Roar" else "smash", eye_position())
		voice_clock = 2.2
	if state not in [State.DORMANT,State.RETREAT] and speech_clock <= 0 and gesture_left <= 0 and voice_clock <= 0:
		speech_clock = randf_range(10,17) if state != State.CHASE else randf_range(8,12)
		station.monster_speech.rpc(eye_position(),next_speech_take())
		voice_clock = maxf(7,AudioManager.sounds.monster_voice[last_speech_take].get_length()+.5)
	# Follow a fresh audible lead before returning to unattended sabotage.
	var fresh_noise: bool = state == State.INVESTIGATE and state_time < 3.0
	if not fresh_noise and lonely_time >= float(station.rules.sabotage_delay) and sabotage_cooldown <= 0 and state in [State.PATROL, State.SEARCH, State.INVESTIGATE] and station.objectives.emergency.is_empty():
		sabotage_target = "generator" if station.map_id == 1 or (station.objectives.generator_on and randf() < .5) else "ventilation"
		sabotage_striking = false
		change_state(State.SABOTAGE, station.objects[sabotage_target].position + Vector3(0, 0, 1.7))
	crawl_amount = move_toward(crawl_amount, 1.0 if state == State.CHASE else 0.0, delta / .65)
	teleport_clock -= delta
	if state == State.DORMANT:
		if station.elapsed >= 20.0:
			change_state(State.PATROL, patrol_points[patrol_index])
		return
	perception_clock -= delta
	if perception_clock <= 0.0:
		perception_clock = 0.18
		_perceive()
	var target: Node3D = station.players.get_node_or_null(str(target_id))
	if state == State.SABOTAGE and position.distance_to(Vector3(goal.x, position.y, goal.z)) < 1.0:
		if not sabotage_striking:
			sabotage_striking = true
			gesture = "Bash"
			gesture_left = 1.3
			station.sound_event.rpc("smash", station.objects[sabotage_target].position)
		elif gesture_left <= 0:
			station.objectives.sabotage(sabotage_target)
			sabotage_cooldown = float(station.rules.sabotage_cooldown)
			lonely_time = 0
			change_state(State.PATROL, patrol_points[patrol_index])
		return
	if state == State.CHASE:
		if target and target.health > 0.0 and target.vent_time <= 0:
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
		path = station.find_path(position, goal, true)
		if path.is_empty() and state == State.PATROL:
			patrol_index = (patrol_index+1)%patrol_points.size()
			goal = patrol_points[patrol_index]
		path_index = 1 if path.size() > 1 else 0
	var direction := Vector3.ZERO
	if path_index < path.size():
		var waypoint: Vector3 = path[path_index]
		waypoint.y = position.y
		if position.distance_to(waypoint) < 0.3:
			path_index += 1
		else:
			direction = (waypoint - position).normalized()
	# Stop and strike the actual door; never force the body through its collider.
	for object: Node3D in station.objects.values():
		if object.kind != "door" or object.opened or object.locked:
			continue
		var door_local: Vector3 = object.to_local(global_position)
		if absf(door_local.x) < 1.9 and absf(door_local.z) < .65:
			door_strike += delta
			direction = Vector3.ZERO
			if gesture_left <= 0:
				gesture = "Bash"
				gesture_left = 1.1
				station.sound_event.rpc("smash", object.position)
			if door_strike >= 1.2:
				object.opened = true
				object.refresh()
				station._update_doors_navigation()
				station.sync_state()
				door_strike = 0
				repath_clock = 0
			break
	if gesture_left > 0 and state != State.CHASE:
		direction = Vector3.ZERO
	var speed: float = float(station.rules.chase_speed) if state == State.CHASE else (2.3 if state == State.RETREAT else 1.25)
	if state == State.CHASE and station.elapsed - chase_started_at < .65:
		speed = .35 # A short, readable stare precedes the pursuit.
	if station.objectives.generator_on:
		speed *= 1.1
	if direction.length() > .1:
		direction = _avoid_obstacle(direction)
	velocity = Vector3(direction.x * speed, -0.5, direction.z * speed)
	move_and_slide()
	stuck_clock += delta
	if stuck_clock >= 1.4:
		if position.distance_to(stuck_position) < .15 and direction.length() > .1:
			repath_clock = 0
			if state == State.PATROL:
				patrol_index = (patrol_index + 1) % patrol_points.size()
				goal = patrol_points[patrol_index]
		stuck_position = position
		stuck_clock = 0
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

func next_speech_take() -> int:
	var count: int = AudioManager.sounds.get("monster_voice",[]).size()
	if count == 0: return -1
	if speech_bag.is_empty():
		speech_bag.assign(range(count))
		speech_bag.shuffle()
		if count > 1 and speech_bag.back() == last_speech_take:
			var swap: int = speech_bag[0]
			speech_bag[0] = speech_bag[-1]
			speech_bag[-1] = swap
	last_speech_take = speech_bag.pop_back()
	return last_speech_take

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
	if not bool(station.rules.monster) or state in [State.DORMANT, State.STUNNED]:
		return
	var range_multiplier: float = 1.2 if station.objectives.generator_on else 1.0
	if station.map_id == 1: range_multiplier *= 1.3
	if station.map_id == 2: range_multiplier *= 1.15
	if position.distance_to(pos) <= radius * range_multiplier:
		last_known = pos
		if state == State.CHASE:
			goal = pos
			return
		change_state(State.INVESTIGATE, pos)

func _perceive() -> void:
	if state == State.STUNNED:
		return
	var candidates: Array = station.players.get_children()
	candidates.sort_custom(func(a: Node3D, b: Node3D): return position.distance_squared_to(a.position) < position.distance_squared_to(b.position))
	for player: Node3D in candidates:
		if player.health <= 0.0 or player.vent_time > 0:
			continue
		var distance: float = position.distance_to(player.position)
		if state == State.RETREAT and distance > 2.2:
			continue
		if distance > (14.0 if player.lamp_on else (6.0 if player.crouched else 10.0)):
			continue
		if not station.can_see(eye_position(), player, [get_rid()]):
			continue
		last_known = player.position
		lonely_time = 0
		target_id = player.peer_id
		var to_monster: Vector3 = (position + Vector3.UP * 1.5 - player.eye_position()).normalized()
		if player.lamp_on and player.battery > 0.0 and distance > 2.2 and distance < (3.2 if station.map_id == 1 else 4.2) and player.look_direction().dot(to_monster) > 0.96:
			var away: Vector3 = position + (position - player.position).normalized() * 4.0
			away.x = clampf(away.x, -62, 62)
			away.z = clampf(away.z, -104, 65)
			change_state(State.RETREAT, away)
			return
		if state != State.CHASE:
			change_state(State.CHASE, player.position)
		else:
			goal = player.position
			state_time = 0.0
		return

func neutralize() -> void:
	if not multiplayer.is_server() or state == State.STUNNED:
		return
	stunned_left = 60.0
	fell_crawling = crawl_amount > .5 or recovery_left>0
	fall_elapsed=0; hit_serial+=1; impact_played=false
	fall_speed=clampf(Vector2(velocity.x,velocity.z).length(),1.6,4.2)
	fall_yaw=rotation.y
	fall_center=position
	var found: bool=false
	for shift: Vector3 in [Vector3.ZERO,Vector3.LEFT*.45,Vector3.RIGHT*.45,Vector3.FORWARD*.45,Vector3.BACK*.45,Vector3.LEFT*.9,Vector3.RIGHT*.9,Vector3.FORWARD*.9,Vector3.BACK*.9]:
		for offset: float in [0.0,PI/2,-PI/2,PI]:
			if _fall_space_clear(position+shift,rotation.y+offset):
				fall_yaw=rotation.y+offset; fall_center=position+shift; found=true; break
		if found: break
	fall_direction=Vector3.FORWARD.rotated(Vector3.UP,fall_yaw)
	fall_cleared=position.distance_to(fall_center)<.06
	blood_anchor=position+Vector3.UP*.028
	recovery_left=0
	gesture_left = 0
	velocity = Vector3.ZERO
	change_state(State.STUNNED, position)
	station.sound_event.rpc("monster_hurt", position)
	visual_mode=""

func fall_duration() -> float: return 44.0/24 if fell_crawling else 2.5

func _fall_space_clear(at: Vector3,yaw: float) -> bool:
	for corner: Vector2 in [Vector2(-.55,-1.4),Vector2(.55,-1.4),Vector2(-.55,1.4),Vector2(.55,1.4)]:
		var offset: Vector3=Vector3(corner.x,0,corner.y).rotated(Vector3.UP,yaw)
		var on_floor: bool=false
		for floor_rect: Rect2 in station.layout.FLOORS:
			if floor_rect.has_point(Vector2(at.x+offset.x,at.z+offset.z)): on_floor=true; break
		if not on_floor: return false
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=fall_probe; query.transform=Transform3D(Basis(Vector3.UP,yaw),at+Vector3.UP*.38)
	query.collision_mask=1|4; query.exclude=[get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _tick_fall(delta: float) -> void:
	fall_elapsed=minf(fall_duration(),fall_elapsed+delta)
	rotation.y=lerp_angle(rotation.y,fall_yaw,minf(1,delta*8))
	var effort: float=maxf(0,1-fall_elapsed/1.0)
	var moving: Vector3=fall_direction*fall_speed*effort*(.7 if fell_crawling else 1.0)
	var clearance_shift: Vector3=fall_center-position; clearance_shift.y=0
	if clearance_shift.length()<=.06: fall_cleared=true
	var clearing_wall: bool=effort>0 and not fall_cleared
	if clearing_wall: moving=clearance_shift.normalized()*minf(2.4,clearance_shift.length()/maxf(delta,.001))
	if effort>0 and (clearing_wall or _fall_space_clear(position+moving*delta,fall_yaw)):
		velocity=Vector3(moving.x,-.5,moving.z); move_and_slide()
	else: velocity=Vector3.ZERO
	if fall_elapsed<=fall_duration()-.25:
		var at: Vector3=position+fall_direction*.15
		var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.6,at-Vector3.UP*2,1|4,[get_rid()])
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		blood_anchor=(hit.position if not hit.is_empty() else at)+Vector3.UP*.028
	elif not impact_played:
		impact_played=true; station.sound_event.rpc("crawl_impact",blood_anchor)
	net_position=position; net_rotation=rotation.y

func _try_relocate() -> void:
	var candidate: Vector3 = patrol_points.pick_random()
	if candidate.z < -63 and not station.sectors.is_unlocked("sector_d"): return
	for player: Node3D in station.players.get_children():
		if candidate.distance_to(player.position) < 9.0 or station.can_see(candidate + Vector3.UP, player, [get_rid()]):
			return
	position = candidate
	station.flicker_event.rpc()
	repath_clock = 0.0

func _avoid_obstacle(wanted: Vector3) -> Vector3:
	if not test_move(global_transform,wanted*.5): return wanted
	var best := Vector3.ZERO
	var score: float = -INF
	for angle: float in [-.52,.52,-1.05,1.05,-1.57,1.57]:
		var option: Vector3 = wanted.rotated(Vector3.UP,angle)
		if test_move(global_transform,option*.55): continue
		var alignment: float = option.dot((goal-position).normalized())
		if alignment > score: score = alignment; best = option
	if best == Vector3.ZERO: repath_clock = 0.0
	return best
