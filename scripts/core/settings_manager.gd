extends Node
## Only local preferences. Never synchronizes settings through the network.
signal changed

const SAVE_PATH := "user://settings.cfg"
var quality: int = 0
var resolution_scale: float = 0.75
var sensitivity: float = 0.0024
var volume: float = 0.65
var fullscreen: bool = false
var music_volume: float = .45
var effects_volume: float = .85
var ambience_volume: float = .65
var bindings: Dictionary = {}
const DEFAULT_KEYS := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "crouch": KEY_CTRL, "interact": KEY_E, "flashlight": KEY_F, "shout": KEY_V, "drop": KEY_G, "use_item": KEY_R, "slot": KEY_Q, "reload": KEY_T, "sos": KEY_H, "pause": KEY_ESCAPE}
const ACTION_LABELS := {"forward": "Вперёд", "back": "Назад", "left": "Влево", "right": "Вправо", "sprint": "Бег", "crouch": "Присесть", "interact": "Взаимодействие", "flashlight": "Фонарь", "shout": "Отвлечь шумом", "drop": "Положить предмет", "use_item": "Использовать предмет", "slot": "Следующая ячейка", "reload": "Перезарядить", "shoot": "Выстрел", "sos": "Позвать на помощь"}

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		quality = clampi(int(cfg.get_value("video", "quality", 0)), 0, 2)
		resolution_scale = clampf(float(cfg.get_value("video", "scale", 0.75)), 0.5, 1.0)
		sensitivity = clampf(float(cfg.get_value("input", "sensitivity", 0.0024)), 0.0005, 0.006)
		volume = clampf(float(cfg.get_value("audio", "volume", 0.65)), 0.0, 1.0)
		fullscreen = bool(cfg.get_value("video", "fullscreen", false))
		music_volume = clampf(float(cfg.get_value("audio", "music", .45)), 0, 1)
		effects_volume = clampf(float(cfg.get_value("audio", "effects", .85)), 0, 1)
		ambience_volume = clampf(float(cfg.get_value("audio", "ambience", .65)), 0, 1)
		bindings = cfg.get_value("input", "bindings", {})
	install_controls()
	for bus_name: String in ["Music", "Effects", "Ambience"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	apply()

func install_controls() -> void:
	for action: String in DEFAULT_KEYS:
		set_binding(action, bindings.get(action, ["key", DEFAULT_KEYS[action]]), false)
	set_binding("shoot", bindings.get("shoot", ["mouse", MOUSE_BUTTON_LEFT]), false)

func set_binding(action: String, value: Array, remember: bool = true) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var event: InputEvent
	if value[0] == "mouse":
		event = InputEventMouseButton.new()
		event.button_index = int(value[1])
	else:
		event = InputEventKey.new()
		event.physical_keycode = int(value[1])
	InputMap.action_add_event(action, event)
	if remember:
		bindings[action] = value

func key_label(action: String) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	if events[0] is InputEventKey:
		return OS.get_keycode_string(events[0].physical_keycode)
	return {MOUSE_BUTTON_LEFT: "ЛКМ", MOUSE_BUTTON_RIGHT: "ПКМ", MOUSE_BUTTON_MIDDLE: "СКМ"}.get(events[0].button_index, "Мышь %d" % events[0].button_index)

func reset_controls() -> void:
	bindings.clear()
	install_controls()

func apply() -> void:
	get_viewport().scaling_3d_scale = resolution_scale
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if quality == 0 else Viewport.MSAA_2X
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	AudioServer.set_bus_mute(0, volume <= 0)
	for entry: Array in [["Music", music_volume], ["Effects", effects_volume], ["Ambience", ambience_volume]]:
		var index: int = AudioServer.get_bus_index(entry[0])
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(entry[1], .001)))
			AudioServer.set_bus_mute(index, entry[1] <= 0)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "scale", resolution_scale)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("input", "sensitivity", sensitivity)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "effects", effects_volume)
	cfg.set_value("audio", "ambience", ambience_volume)
	cfg.set_value("input", "bindings", bindings)
	cfg.save(SAVE_PATH)
	apply()
