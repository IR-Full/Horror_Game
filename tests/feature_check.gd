extends Node
## Gameplay regression checks against real colliders, AI, input and saved settings.
var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		print("FEATURE_CHECK " + label)
	else:
		failures += 1
		push_error("FEATURE_FAIL " + label)

func delay(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func place(player: Node3D, at: Vector3, target: Vector3) -> void:
	player.position = at
	player.net_position = at
	player.velocity = Vector3.ZERO
	var direction: Vector3 = (target - player.eye_position()).normalized()
	player.local_aim = Vector2(atan2(-direction.x, -direction.z), asin(direction.y))
	player.aim = player.local_aim

func _run() -> void:
	NetworkManager.host_room("Feature QA", 27949)
	NetworkManager.choose_role(2)
	NetworkManager.start_round(true)
	await delay(.35)
	var world: Node3D = GameManager.world
	var player: Node3D = GameManager.local_player()
	var creature: Node3D = world.monster
	creature.set_physics_process(false)
	player.input_enabled = false
	check(player.role == "hunter" and player.loaded_shells == 1, "practice preserves chosen hunter and exactly one loaded shell")
	var shell_locations: Dictionary = {}
	for i: int in range(4):
		var at: Vector3 = world.objects["shell_%d" % i].position
		shell_locations[at] = true
	check(shell_locations.size() == 4, "four spare shells occupy distinct random locations")
	for target: Vector3 in [Vector3(-9, 0, -20), Vector3(9, 0, -32), Vector3(-10, 0, -42), Vector3(9, 0, -44)]:
		check(world.find_path(Vector3(0, 0, 10), target).size() > 20, "extended wing reachable: " + str(target))
	check(world.items.pickup(player, world.objects.fuse) == false, "closed safe prevents direct item pickup")
	check(world.items.pickup(player, world.objects.service_key) == false, "closed locker conceals its key")
	var hatch: Node3D = world.objects.hatch_0
	place(player, Vector3(13, .05, -21), hatch.position)
	player.input_enabled = true
	Input.action_press("crouch")
	await delay(.15)
	place(player, Vector3(13, .05, -21), hatch.position)
	await get_tree().physics_frame
	world.interact_object(player, hatch)
	Input.action_release("crouch")
	player.input_enabled = false
	check(player.position.distance_to(hatch.destination) < .1, "crouched interaction traverses the ventilation shortcut")
	# The old archive door: the upper head ray must hit the closed leaf.
	var door: Node3D = world.objects.door_9_0
	var ray := PhysicsRayQueryParameters3D.create(Vector3(1, 2.6, 0), Vector3(5, 2.6, 0), 4)
	check(world.get_world_3d().direct_space_state.intersect_ray(ray).get("collider") == door, "closed door covers the monster's head height")
	creature.state = creature.State.PATROL
	creature.show()
	creature.position = Vector3(6, .05, 0)
	place(player, Vector3(0, .05, 0), Vector3(6, 1.4, 0))
	await delay(.1)
	player.apply_action("shoot", 0)
	check(creature.state != creature.State.STUNNED and player.loaded_shells == 0, "shotgun cannot hit through a closed door")
	await delay(1.3)
	player.reserve_shells = 1
	player.apply_action("reload", 0)
	await delay(1.9)
	check(player.loaded_shells == 1 and player.reserve_shells == 0, "reload consumes one reserve shell on host")
	creature.position = Vector3(0, .05, 1)
	place(player, Vector3(0, .05, 6), Vector3(0, 1.4, 1))
	await delay(.1)
	player.apply_action("shoot", 0)
	await delay(1.2)
	check(creature.state == creature.State.STUNNED and creature.visible and creature.visual_mode == "Down", "shot monster falls and remains visible on the floor")
	check(creature.stunned_left == 60, "neutralization lasts one minute, without despawning")
	creature.stunned_left = .02
	creature.set_physics_process(true)
	await delay(.2)
	check(creature.state != creature.State.STUNNED, "creature recovers when its one-minute timer expires")
	creature.set_physics_process(false)
	await delay(1.5)
	# An unlocked closed doorway is a physical obstacle, then opened with a strike.
	door = world.objects["door_-9_0"]
	door.opened = false
	door.refresh()
	world._update_doors_navigation()
	creature.position = Vector3(0, .05, 0)
	creature.net_position = creature.position
	creature.crawl_amount = 0
	creature.gesture_left = 0
	creature.rage_clock = 100
	creature.recovery_left = 0
	creature.sabotage_cooldown = 100
	place(player, Vector3(-8, .05, 0), Vector3(-12, 1.4, 0))
	player.lamp_on = false
	creature.target_id = player.peer_id
	creature.change_state(creature.State.CHASE, player.position)
	creature.set_physics_process(true)
	await delay(4.6)
	check(door.opened and creature.position.x < -4.2, "creature strikes a closed door then walks through its open doorway")
	creature.set_physics_process(false)
	creature.state = creature.State.PATROL
	creature.position = Vector3(0, .05, 4)
	place(player, Vector3(0, .05, 4.9), Vector3(0, 1.4, 9))
	player.health = 100
	player.lamp_on = true
	creature._perceive()
	check(creature.state == creature.State.CHASE, "a player immediately behind the creature is detected at close range")
	creature.state = creature.State.RETREAT
	creature._perceive()
	check(creature.state == creature.State.CHASE, "retreating from light does not grant point-blank immunity")
	# Exercise actual travel and strike at equipment rather than calling sabotage.
	place(player, Vector3(0, .05, 10), Vector3(0, 1.4, 12))
	creature.position = Vector3(-10, .05, -40.5)
	creature.net_position = creature.position
	creature.lonely_time = 36
	creature.sabotage_cooldown = 0
	creature.perception_clock = 100
	creature.gesture_left = 0
	creature.rage_clock = 100
	creature.change_state(creature.State.PATROL, Vector3(-10, 0, -44))
	creature.set_physics_process(true)
	await delay(4.7)
	check(world.objectives.emergency == "ventilation" and world.objectives.emergency_left > 115, "lonely creature physically reaches and sabotages ventilation")
	creature.set_physics_process(false)
	place(player, Vector3(-10, .05, -42.2), world.objects.ventilation.position)
	player.input_enabled = true
	Input.action_press("interact")
	await delay(8.4)
	Input.action_release("interact")
	player.input_enabled = false
	check(world.objectives.emergency.is_empty(), "holding interaction at damaged ventilation cancels the fatal emergency")
	world.objectives.sabotage("ventilation")
	world.objectives.emergency_left = .01
	world.objectives.begin_frame()
	world.objectives.tick(.1)
	check(world.objectives.result.contains("кислород"), "unrepaired emergency ends in oxygen-loss defeat")
	world.objectives.result = ""
	world.objectives.emergency = ""
	world.objectives.generator_on = true
	world.objectives.sabotage("generator")
	check(not world.objectives.generator_on and world.objectives.emergency_left == 120, "generator sabotage removes power and starts cold countdown")
	world.objectives.emergency = ""
	player.invulnerable = 0
	player.damage(100)
	await delay(1)
	check(player.fall_amount > .95 and player.blood_pool.visible and not player.dead, "injured player falls and begins bleeding")
	player.apply_action("sos", 0)
	var cooldown: float = player.sos_cooldown
	player.apply_action("sos", 0)
	check(cooldown > 14 and player.sos_cooldown == cooldown, "SOS is limited to one call every fifteen seconds")
	player.down_time = 65
	await delay(.1)
	check(float(player.blood_pool.material_override.get_shader_parameter("spread")) > .55, "blood pool spreads as bleed-out progresses")
	player.revive()
	await delay(.2)
	check(not player.blood_pool.visible and player.down_time == 0, "revival stops bleeding and clears the active pool")
	player.invulnerable = 0
	player.damage(100)
	player.down_time = 119.98
	await delay(.15)
	check(player.dead, "injured survivor dies permanently after two minutes")
	SettingsManager.set_binding("interact", ["key", KEY_J])
	SettingsManager.effects_volume = .37
	SettingsManager.save()
	var config := ConfigFile.new()
	config.load(SettingsManager.SAVE_PATH)
	check(config.get_value("input", "bindings").interact[1] == KEY_J and is_equal_approx(config.get_value("audio", "effects"), .37), "remapped controls and independent audio levels persist")
	SettingsManager.reset_controls()
	NetworkManager.leave()
	await get_tree().process_frame
	print("FEATURE_PASS" if failures == 0 else "FEATURE_FAIL %d checks" % failures)
	get_tree().quit(0 if failures == 0 else 1)
