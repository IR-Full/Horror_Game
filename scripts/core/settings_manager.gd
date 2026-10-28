extends Node
## Only local preferences. Never synchronizes settings through the network.
signal changed

const SAVE_PATH := "user://settings.cfg"
var quality: int = 0
var resolution_scale: float = 0.75
var sensitivity: float = 0.0024
var volume: float = 0.65
var fullscreen: bool = false

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		quality = clampi(int(cfg.get_value("video", "quality", 0)), 0, 2)
		resolution_scale = clampf(float(cfg.get_value("video", "scale", 0.75)), 0.5, 1.0)
		sensitivity = clampf(float(cfg.get_value("input", "sensitivity", 0.0024)), 0.0005, 0.006)
		volume = clampf(float(cfg.get_value("audio", "volume", 0.65)), 0.0, 1.0)
		fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	apply()

func apply() -> void:
	get_viewport().scaling_3d_scale = resolution_scale
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if quality == 0 else Viewport.MSAA_2X
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
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
	cfg.save(SAVE_PATH)
	apply()
