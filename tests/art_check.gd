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
	check(catalog.size() == 24, "all 24 authored models are catalogued")
	for entry: Dictionary in catalog:
		var model := ART.model(str(entry.model))
		var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		check(not meshes.is_empty(), "imported mesh: " + str(entry.model))
		model.free()
	NetworkManager.host_room("Art QA", 27947)
	NetworkManager.start_round(true)
	await get_tree().create_timer(.3).timeout
	var world: Node3D = GameManager.world
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
	for kind: String in ["whisper", "knock", "heartbeat", "motor"]:
		var sound: AudioStreamWAV = AudioManager._make_sound(kind)
		check(sound.data.size() > 6000, "generated audio: " + kind)
	NetworkManager.leave()
	await get_tree().process_frame
	print("ART_PASS" if failures == 0 else "ART_FAIL %d checks" % failures)
	get_tree().quit(0 if failures == 0 else 1)
