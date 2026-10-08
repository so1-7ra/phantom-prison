extends Node
## Autoload「Config」。プレイヤー設定（感度・音量など）を全体で共有する。

signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"

var mouse_sensitivity := 1.0
var master_volume := 0.8
## 1 で等倍、数字が大きいほど画面が粗くなる（PS1 風）
var pixel_size := 3
var fullscreen := false


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	mouse_sensitivity = config.get_value("settings", "mouse_sensitivity", mouse_sensitivity)
	master_volume = config.get_value("settings", "master_volume", master_volume)
	pixel_size = config.get_value("settings", "pixel_size", pixel_size)
	fullscreen = config.get_value("settings", "fullscreen", fullscreen)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("settings", "master_volume", master_volume)
	config.set_value("settings", "pixel_size", pixel_size)
	config.set_value("settings", "fullscreen", fullscreen)
	config.save(SETTINGS_PATH)


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001)))
	var mode := DisplayServer.window_get_mode()
	var is_fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_fullscreen != fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	settings_changed.emit()
