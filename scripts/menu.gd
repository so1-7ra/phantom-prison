class_name Menu
extends CanvasLayer
## タイトル・一時停止・ゲームオーバー・設定の各画面。
## ゲームが一時停止していても動くよう、process_mode は ALWAYS にして使う。

signal start_requested
signal resume_requested
signal retry_requested
signal title_requested
signal quit_requested

const TITLE_COLOR := Color(0.75, 0.9, 1.0)
const DANGER_COLOR := Color(1.0, 0.3, 0.25)
## ドットフォント（DotGothic16）は 16 の倍数で表示するとくっきり見える
const FONT_SIZE := 32

var _title := Control.new()
var _pause := Control.new()
var _game_over := Control.new()
var _settings := Control.new()
var _best_label := Label.new()
var _game_over_label := Label.new()
var _sensitivity_slider: HSlider
var _volume_slider: HSlider
var _pixel_slider: HSlider
var _fullscreen_toggle := Button.new()
var _settings_return: Control
var _first_buttons := {}


func _ready() -> void:
	layer = 10
	_build_title()
	_build_pause()
	_build_game_over()
	_build_settings()
	hide_all()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _settings.visible:
		_close_settings()
	elif _pause.visible:
		resume_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func show_title(best_night: int) -> void:
	_best_label.text = "最高記録：夜 %d" % best_night if best_night > 0 else "まだ記録はありません"
	_show(_title)


func show_pause() -> void:
	_show(_pause)


func show_game_over(text: String) -> void:
	_game_over_label.text = text
	_show(_game_over)


func hide_all() -> void:
	for panel in [_title, _pause, _game_over, _settings]:
		panel.hide()


func is_open() -> bool:
	return _title.visible or _pause.visible or _game_over.visible or _settings.visible


func _show(panel: Control) -> void:
	hide_all()
	panel.show()
	var button: Button = _first_buttons.get(panel)
	if button:
		button.grab_focus.call_deferred()


func _build_title() -> void:
	var box := _make_panel(_title, 0.35)
	_add_label(box, "PHANTOM PRISON", 64, TITLE_COLOR)
	_add_label(box, "ファントム・プリズン", 32, TITLE_COLOR.darkened(0.3))
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_best_label)
	_add_spacer(box)
	_add_button(_title, box, "はじめる", start_requested.emit)
	_add_button(_title, box, "設定", _open_settings.bind(_title))
	_add_button(_title, box, "終了", quit_requested.emit)


func _build_pause() -> void:
	var box := _make_panel(_pause, 0.6)
	_add_label(box, "一時停止", 48, TITLE_COLOR)
	_add_spacer(box)
	_add_button(_pause, box, "再開", resume_requested.emit)
	_add_button(_pause, box, "設定", _open_settings.bind(_pause))
	_add_button(_pause, box, "タイトルへ", title_requested.emit)


func _build_game_over() -> void:
	var box := _make_panel(_game_over, 0.6)
	_add_label(box, "収監", 64, DANGER_COLOR)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_game_over_label)
	_add_spacer(box)
	_add_button(_game_over, box, "もう一度", retry_requested.emit)
	_add_button(_game_over, box, "タイトルへ", title_requested.emit)


func _build_settings() -> void:
	var box := _make_panel(_settings, 0.75)
	_add_label(box, "設定", 48, TITLE_COLOR)
	_add_spacer(box)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	_sensitivity_slider = _add_slider_row(grid, "マウス感度", 0.2, 3.0, 0.1, "%.1f",
		func(value: float) -> void: Config.mouse_sensitivity = value)
	_volume_slider = _add_slider_row(grid, "音量", 0.0, 1.0, 0.05, "%d%%",
		func(value: float) -> void: Config.master_volume = value, 100.0)
	_pixel_slider = _add_slider_row(grid, "画面の粗さ", 1.0, 4.0, 1.0, "%d",
		func(value: float) -> void: Config.pixel_size = int(value))
	var label := Label.new()
	label.text = "フルスクリーン"
	grid.add_child(label)
	_fullscreen_toggle.toggle_mode = true
	_fullscreen_toggle.custom_minimum_size = Vector2(160, 48)
	_fullscreen_toggle.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_fullscreen_toggle.toggled.connect(func(on: bool) -> void:
		_fullscreen_toggle.text = "オン" if on else "オフ"
		Config.fullscreen = on
		Config.apply())
	grid.add_child(_fullscreen_toggle)
	grid.add_child(Control.new())
	_add_spacer(box)
	_add_button(_settings, box, "戻る", _close_settings)


func _open_settings(from: Control) -> void:
	_settings_return = from
	_sensitivity_slider.value = Config.mouse_sensitivity
	_volume_slider.value = Config.master_volume
	_pixel_slider.value = Config.pixel_size
	_fullscreen_toggle.set_pressed_no_signal(Config.fullscreen)
	_fullscreen_toggle.text = "オン" if Config.fullscreen else "オフ"
	_show(_settings)


func _close_settings() -> void:
	Config.save_settings()
	_show(_settings_return if _settings_return else _title)


func _make_panel(root: Control, dim: float) -> VBoxContainer:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, dim)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	return box


func _add_label(box: Container, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	box.add_child(label)


func _add_spacer(box: Container) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	box.add_child(spacer)


func _add_button(panel: Control, box: Container, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(400, 60)
	button.pressed.connect(func() -> void:
		Sfx.play(self, &"ui_click")
		action.call())
	box.add_child(button)
	if not _first_buttons.has(panel):
		_first_buttons[panel] = button


## 表示倍率 display_scale は、0〜1 の値を「%」で見せるときなどに使う。
func _add_slider_row(grid: GridContainer, text: String, min_value: float, max_value: float,
		step: float, format: String, on_change: Callable, display_scale := 1.0) -> HSlider:
	var label := Label.new()
	label.text = text
	grid.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size = Vector2(320, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 96
	grid.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = format % (value * display_scale)
		on_change.call(value)
		Config.apply())
	return slider
