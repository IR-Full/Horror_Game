extends Node
## Runtime checks for imported art, quality changes and cosmetic event lifetime.
const ART := preload("res://scripts/art/art_factory.gd")
var failures: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("ART_FAIL " + message)
	else:
		print("ART_CHECK " + message)

func _run() -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/catalog.json"))
	check(catalog.size() == 29, "all 29 authored models are catalogued")
	for entry: Dictionary in catalog:
		var model := ART.model(str(entry.model))
		var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty(), "imported mesh: " + str(entry.model))
		if str(entry.model) == "entity":
			check(not model.find_children("*", "Skeleton3D", true, false).is_empty(), "entity skeleton imports")
			var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
			check(not players.is_empty(), "entity animation player imports")
			if not players.is_empty():
				check(players[0].get_animation_list().size() >= 5, "five creature clips import")
		model.free()
	for kind: String in ["plaster", "paint", "floor", "concrete", "metal_wear"]:
		check(ResourceLoader.exists("res://assets/textures/%s_normal.png" % kind), "normal map: " + kind)
	NetworkManager.host_room("Art QA", 27947)
	NetworkManager.start_round(true)
	await get_tree().create_timer(.3).timeout
	var world: Node3D = GameManager.world
	var creature: Node3D = world.monster
	check(creature.clip_names.has_all(["Idle", "Walk", "DropToCrawl", "Crawl", "Rise"]), "all creature animation states resolve")
	if creature.animation:
		creature.set_process(false)
		var skeletons: Array[Node] = creature.mesh.find_children("*", "Skeleton3D", true, false)
		var skeleton: Skeleton3D = skeletons[0]
		var head_index: int = skeleton.find_bone("Head")
		check(head_index >= 0, "creature head bone exists")
		creature.animation.play(creature.clip_names.Walk)
		creature.animation.advance(0)
		var standing_height: float = (skeleton.global_transform * skeleton.get_bone_global_pose(head_index)).origin.y
		creature.animation.play(creature.clip_names.Crawl)
		creature.animation.advance(.15)
		var crawling_height: float = (skeleton.global_transform * skeleton.get_bone_global_pose(head_index)).origin.y
		check(crawling_height < standing_height - .6, "quadruped animation lowers the head and body")
		creature.animation.play(creature.clip_names.Idle)
		creature.animation.advance(0)
		creature.visual_mode = "Idle"
		creature.set_process(true)
	check(world.atmosphere.get_node("StationDressing").paper_count == 45, "batched papers built")
	check(world.atmosphere.get_node("BloodTraces").pool_count == 6, "six authored blood pools built")
	check(world.atmosphere.get_node("BloodTraces").message_count == 3, "blood writing built")
	var player: Node3D = GameManager.local_player()
	player.input_enabled = false
	check(world.find_path(Vector3(0, 0, 10), Vector3(-10, 0, 2)).size() > 1, "new props leave generator route open")
	check(world.find_path(Vector3(0, 0, 10), Vector3(9, 0, -6)).size() > 1, "new props leave radio room route open")
	var door: Node3D = world.objects.door_9_0
	for opened: bool in [true, false]:
		door.opened = opened
		door.refresh()
		world._update_doors_navigation()
		await get_tree().physics_frame
		check(not door.collider.disabled, "door keeps physical collision in both poses")
		check(world.astar.is_point_solid(Vector2i(3, 0)) == not opened, "doorway navigation follows door pose")
	for quality: int in range(3):
		SettingsManager.quality = quality
		SettingsManager.apply()
		await get_tree().process_frame
		check(world.atmosphere.dust.visible == (quality > 0), "dust preset " + str(quality))
	world.haunt_event.rpc(0, Vector3(0, 0, -6))
	world.haunt_event.rpc(1, Vector3(0, 0, -6))
	world.haunt_event.rpc(2, Vector3(0, 0, -6))
	check(world.atmosphere.apparition.visible, "brief apparition appears")
	await get_tree().create_timer(1.1).timeout
	check(not world.atmosphere.apparition.visible, "apparition disappears without leaving a permanent NPC")
	# Exercise the actual authoritative transition and chase, not just the clips.
	player.position = Vector3(0, .05, 5)
	player.lamp_on = false
	creature.position = Vector3(0, .05, -2)
	creature.net_position = creature.position
	world.elapsed = 35.0
	creature.target_id = player.peer_id
	creature.change_state(creature.State.CHASE, player.position)
	await get_tree().create_timer(.95).timeout
	check(creature.crawl_amount > .9 and creature.body_shape.shape.height < 1.3, "chase lowers authoritative collision body")
	check(creature.visual_mode == "Crawl", "drop transitions into quadruped run")
	check(creature.position.z > -1.5, "quadruped pursuit moves toward the victim")
	for kind: String in ["whisper", "knock", "heartbeat", "motor", "breath", "scrape", "roar", "growl", "crawl_impact"]:
		var sound: AudioStreamWAV = AudioManager._make_sound(kind)
		check(sound.data.size() > 6000, "generated audio: " + kind)
	NetworkManager.leave()
	await get_tree().process_frame
	print("ART_PASS" if failures == 0 else "ART_FAIL %d checks" % failures)
	get_tree().quit(0 if failures == 0 else 1)
