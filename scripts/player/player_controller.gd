extends CharacterBody3D
## Server owns the body and every gameplay property. Owner only submits intent.
const ROLE_NAMES := {
	"tech_scout": "Техник-разведчик", "med_operator": "Медик-оператор",
	"technician": "Техник", "scout": "Разведчик", "medic": "Медик", "operator": "Оператор", "hunter": "Охотник"
}
var peer_id: int = 1
var nickname: String = "Техник"
var role: String = "tech_scout"
var health: float = 100.0
var battery: float = 100.0
var lamp_on: bool = true
var crouched: bool = false
var dead: bool = false
var down_time: float = 0.0
var inventory := PackedStringArray()
var net_position := Vector3.ZERO
var net_yaw: float = 0.0
var net_pitch: float = 0.0
var camera: Camera3D
var rig: Node3D
var lamp: SpotLight3D
var body_mesh: Node3D
var held_flashlight: Node3D
var view_time: float = 0.0
var move_input := Vector2.ZERO
var aim := Vector2.ZERO
var sprinting: bool = false
var holding: bool = false
var local_aim := Vector2.ZERO
var input_age: float = 0.0
var send_clock: float = 0.0
var noise_clock: float = 0.0
var action_cooldown: float = 0.0
var shout_cooldown: float = 0.0
var selected_slot: int = 0
var input_enabled: bool = true
var invulnerable: float = 0.0
var loaded_shells: int = 0
var reserve_shells: int = 0
var reload_left: float = 0.0
var sos_cooldown: float = 0.0
var pain_clock: float = 2.0
var fall_amount: float = 0.0
var body_pivot: Node3D
var body_collision: CollisionShape3D
var blood_pool: MeshInstance3D
var shotgun: Node3D
var recoil: float = 0.0
var next_left_foot: bool = true
var bloody_steps: int = 0

func _ready() -> void:
	add_to_group("players")
	var collision := CollisionShape3D.new()
	body_collision = collision
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.75
	collision.shape = shape
	collision.position.y = 0.88
	add_child(collision)
	body_mesh = preload("res://scripts/art/art_factory.gd").model("avatar")
	body_pivot = Node3D.new()
	body_pivot.position.y = .9
	add_child(body_pivot)
	body_pivot.add_child(body_mesh)
	body_mesh.position.y = -.9
	blood_pool = preload("res://scripts/art/blood_traces.gd").make_pool(Vector3(0, .028, 0), Vector2(.8, .55), float(peer_id % 100))
	add_child(blood_pool)
	blood_pool.hide()
	if role == "hunter":
		loaded_shells = 1
	var tag := Label3D.new()
	tag.text = nickname
	tag.position.y = 2.05
	tag.font_size = 32
	tag.pixel_size = 0.008
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(tag)
	rig = Node3D.new()
	rig.name = "Head"
	rig.position.y = 1.55
	add_child(rig)
	camera = Camera3D.new()
	camera.fov = 78.0
	camera.near = 0.06
	camera.far = 70.0
	rig.add_child(camera)
	if is_local():
		held_flashlight = preload("res://scripts/art/art_factory.gd").model("flashlight")
		held_flashlight.position = Vector3(.24, -.26, -.38)
		held_flashlight.rotation = Vector3(.04, -.08, -.12)
		camera.add_child(held_flashlight)
		var hand := preload("res://scripts/art/art_factory.gd").model("hand")
		hand.position = Vector3(.24, -.32, -.31)
		camera.add_child(hand)
		for model: Node3D in [held_flashlight, hand]:
			for child: Node in model.find_children("*", "MeshInstance3D", true, false):
				child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if role == "hunter":
		shotgun = preload("res://scripts/art/art_factory.gd").model("shotgun")
		if is_local():
			camera.add_child(shotgun)
			shotgun.position = Vector3(.18, -.24, -.34)
			held_flashlight.position.x = -.25
		else:
			body_pivot.add_child(shotgun)
			shotgun.position = Vector3(.2, .35, -.3)
	lamp = SpotLight3D.new()
	lamp.light_color = Color("e4e9dc")
	lamp.light_energy = 3.0
	lamp.spot_range = 13.0
	lamp.spot_angle = 34.0
	lamp.position = Vector3(0.18, -0.12, -0.1)
	rig.add_child(lamp)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "StateSync"
	sync.replication_interval = 0.05
	var config := SceneReplicationConfig.new()
	for property: String in ["net_position", "net_yaw", "net_pitch", "health", "battery", "lamp_on", "crouched", "dead", "inventory", "down_time", "sos_cooldown", "loaded_shells", "reserve_shells", "reload_left"]:
		var path := NodePath(".:" + property)
		config.add_property(path)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config
	add_child(sync)
	position = net_position
	if is_local():
		camera.make_current()
		body_mesh.hide()
		tag.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SettingsManager.changed.connect(_apply_quality)
	_apply_quality()

func _apply_quality() -> void:
	lamp.shadow_enabled = SettingsManager.quality > 0 and is_local()
	camera.far = [75.0, 90.0, 110.0][SettingsManager.quality]

func is_local() -> bool:
	return multiplayer.get_unique_id() == peer_id

func is_technician() -> bool:
	return role in ["technician", "tech_scout"]

func is_medic() -> bool:
	return role in ["medic", "med_operator"]

func capacity() -> int:
	return 4

func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		local_aim.x = wrapf(local_aim.x - event.relative.x * SettingsManager.sensitivity, -PI, PI)
		local_aim.y = clampf(local_aim.y - event.relative.y * SettingsManager.sensitivity, -1.35, 1.35)
	if event.is_action_pressed("slot"):
		selected_slot = (selected_slot + 1) % maxi(1, inventory.size())
	for action: String in ["flashlight", "shout", "drop", "use_item", "shoot", "reload", "sos"]:
		if event.is_action_pressed(action) and not event.is_echo():
			if multiplayer.is_server():
				apply_action(action, selected_slot)
			else:
				NetworkManager.request_player_action.rpc_id(1, NetworkManager.round_id, action, selected_slot)

func _physics_process(delta: float) -> void:
	if is_local():
		selected_slot = selected_slot % maxi(1, inventory.size())
		rig.rotation = Vector3(local_aim.y, local_aim.x, 0.0)
		send_clock -= delta
		if send_clock <= 0.0 and NetworkManager.in_match:
			send_clock = 1.0 / 30.0
			var moving := Input.get_vector("left", "right", "forward", "back") if input_enabled and health > 0.0 else Vector2.ZERO
			var running := input_enabled and Input.is_action_pressed("sprint")
			var ducking := input_enabled and Input.is_action_pressed("crouch")
			var use := input_enabled and Input.is_action_pressed("interact")
			if multiplayer.is_server():
				accept_input(moving, local_aim, running, ducking, use)
			else:
				NetworkManager.submit_player_input.rpc_id(1, NetworkManager.round_id, moving, local_aim, running, ducking, use)
	else:
		rig.rotation = Vector3(net_pitch, net_yaw, 0.0)
	if multiplayer.is_server() and NetworkManager.in_match:
		_server_tick(delta)
	elif not multiplayer.is_server():
		position = position.lerp(net_position, minf(1.0, delta * 18.0))
	rig.position.y = lerpf(rig.position.y, 0.45 if health <= 0.0 else (1.0 if crouched else 1.55), delta * 12.0)
	lamp.visible = lamp_on and battery > 0.0 and health > 0.0
	fall_amount = move_toward(fall_amount, 1.0 if health <= 0 else 0.0, delta / .85)
	var eased: float = smoothstep(0, 1, fall_amount)
	body_pivot.rotation = Vector3(-PI * .5 * eased, net_yaw, .08 * eased)
	body_pivot.position.y = lerpf(.9, .32, eased)
	body_collision.shape.height = lerpf(1.75, .65, eased)
	body_collision.position.y = body_collision.shape.height * .5
	blood_pool.visible = health <= 0
	blood_pool.material_override.set_shader_parameter("spread", clampf(.12 + down_time / 120.0 * .88, .12, 1))
	if is_local():
		body_mesh.visible = health <= 0
		for child: Node in camera.get_children():
			if child is Node3D:
				child.visible = health > 0
		camera.rotation.z = .18 * eased
		if shotgun:
			shotgun.visible = health > 0
			recoil = move_toward(recoil, 0, delta * 4)
			shotgun.rotation.x = recoil * -.25
			shotgun.position.z = -.34 + recoil * .12
	if is_local():
		view_time += delta
		var moving: float = Input.get_vector("left", "right", "forward", "back").length() if input_enabled and health > 0 else 0.0
		camera.position.y = sin(view_time * (11.0 if Input.is_action_pressed("sprint") else 7.0)) * .012 * moving
		held_flashlight.rotation.z = -.12 + sin(view_time * 6.0) * .018 * moving
		lamp.light_energy = 3.0 * (.6 + .4 * absf(sin(view_time * 19.0)) if battery < 15.0 else 1.0)

func accept_input(direction: Vector2, look: Vector2, run: bool, duck: bool, use: bool) -> void:
	if not direction.is_finite() or not look.is_finite():
		return
	move_input = direction.limit_length(1.0)
	aim = Vector2(wrapf(look.x, -PI, PI), clampf(look.y, -1.35, 1.35))
	sprinting = run
	crouched = duck
	holding = use
	input_age = 0.0

func _server_tick(delta: float) -> void:
	input_age += delta
	action_cooldown = maxf(0.0, action_cooldown - delta)
	shout_cooldown = maxf(0.0, shout_cooldown - delta)
	sos_cooldown = maxf(0.0, sos_cooldown - delta)
	if reload_left > 0:
		reload_left = maxf(0.0, reload_left - delta)
		if reload_left <= 0 and health > 0 and reserve_shells > 0:
			loaded_shells = 1
			reserve_shells -= 1
	invulnerable = maxf(0.0, invulnerable - delta)
	if input_age > 0.3 or GameManager.world.objectives.result != "":
		move_input = Vector2.ZERO
		holding = false
	if health <= 0.0:
		move_input = Vector2.ZERO
		holding = false
		lamp_on = false
		down_time += delta
		pain_clock -= delta
		if not dead and pain_clock <= 0:
			pain_clock = randf_range(7, 12)
			GameManager.world.sound_event.rpc("pain", position)
		if down_time >= 120.0 and not dead:
			dead = true
			GameManager.world.items.drop_all(self)
	var speed: float = 1.35 if crouched else (4.5 if sprinting else 2.8)
	if is_technician():
		speed *= 0.9
	var direction := Basis(Vector3.UP, aim.x) * Vector3(move_input.x, 0, move_input.y)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = velocity.y - 18.0 * delta if not is_on_floor() else -0.1
	move_and_slide()
	net_position = position
	net_yaw = aim.x
	net_pitch = aim.y
	if lamp_on and health > 0.0:
		battery = maxf(0.0, battery - delta * 0.42)
		if battery <= 0.0:
			lamp_on = false
	noise_clock -= delta
	if move_input.length() > 0.1 and health > 0.0 and noise_clock <= 0.0:
		noise_clock = .48 if crouched else (.25 if sprinting else .32)
		var radius: float = 12.0 if sprinting and not crouched else (1.4 if crouched else 4.0)
		GameManager.world.make_noise(position, radius)
		if GameManager.world.is_bloody(position): bloody_steps = 9
		GameManager.world.player_step.rpc(position, net_yaw, next_left_foot, bloody_steps > 0, crouched)
		next_left_foot = not next_left_foot
		bloody_steps = maxi(0,bloody_steps-1)

func apply_action(action: String, slot: int) -> void:
	if not NetworkManager.in_match or GameManager.world.objectives.result != "":
		return
	if action == "sos":
		if health <= 0 and not dead and sos_cooldown <= 0:
			sos_cooldown = 15
			GameManager.world.sound_event.rpc("sos", position)
			GameManager.world.announce.rpc("SOS! %s ранен. Осталось %d сек. до гибели." % [nickname, maxi(0, ceili(120 - down_time))])
		return
	if health <= 0 or action_cooldown > 0:
		return
	action_cooldown = 0.18
	match action:
		"shoot": _fire_shotgun()
		"reload":
			if role == "hunter" and loaded_shells == 0 and reserve_shells > 0 and reload_left <= 0:
				reload_left = 1.7
				GameManager.world.sound_event.rpc("reload", position)
		"flashlight": lamp_on = not lamp_on and battery > 0.0
		"shout":
			if shout_cooldown <= 0.0:
				shout_cooldown = 4.0
				GameManager.world.make_noise(position, 24.0)
				GameManager.world.sound_event.rpc("radio", position)
		"drop": GameManager.world.items.drop(self, slot)
		"use_item": GameManager.world.items.use(self, slot)

func _fire_shotgun() -> void:
	if role != "hunter" or loaded_shells <= 0 or reload_left > 0:
		return
	loaded_shells = 0
	action_cooldown = 1.2
	var world: Node3D = GameManager.world
	world.make_noise(position, 60)
	world.sound_event.rpc("shotgun", eye_position())
	world.shot_event.rpc(peer_id)
	var hit_monster: bool = false
	var forward: Vector3 = look_direction()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	for i: int in range(9):
		var angle: float = i * TAU / 8
		var spread: float = 0.0 if i == 0 else .055
		var direction: Vector3 = (forward + (right * cos(angle) + Vector3.UP * sin(angle)) * spread).normalized()
		var ray := PhysicsRayQueryParameters3D.create(eye_position(), eye_position() + direction * 14, 1 | 4 | 8, [get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.get("collider") == world.monster:
			hit_monster = true
	if hit_monster:
		world.monster.neutralize()

func show_shot() -> void:
	recoil = 1
	var flash := OmniLight3D.new()
	flash.light_color = Color("ffc079")
	flash.light_energy = 5
	flash.omni_range = 5
	flash.position = Vector3(0, 1.3, 0)
	add_child(flash)
	get_tree().create_timer(.065).timeout.connect(flash.queue_free)

func eye_position() -> Vector3:
	return global_position + Vector3.UP * (1.0 if crouched else 1.55)

func look_direction() -> Vector3:
	return Basis.from_euler(Vector3(aim.y, aim.x, 0.0)) * Vector3.FORWARD

func damage(amount: float) -> void:
	if not multiplayer.is_server() or health <= 0.0 or invulnerable > 0.0:
		return
	health = maxf(0.0, health - amount)
	invulnerable = 1.5
	GameManager.world.sound_event.rpc("hurt", position)

func revive() -> void:
	health = 45.0
	down_time = 0.0
	dead = false
	invulnerable = 5.0
