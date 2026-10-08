class_name Hud
extends CanvasLayer
## 画面表示：ステータス、操作ヒント、中央メッセージ、被ダメージ演出。

var _stats := Label.new()
var _hint := Label.new()
var _message := Label.new()
var _crosshair := Label.new()
var _damage_overlay := ColorRect.new()
var _message_timer := 0.0
var _damage_alpha := 0.0


func _ready() -> void:
	_damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_overlay.color = Color(0.6, 0.0, 0.0, 0.0)
	add_child(_damage_overlay)

	_setup_label(_stats, 32)
	_stats.position = Vector2(16, 12)

	_setup_label(_crosshair, 24)
	_crosshair.text = "+"
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_setup_label(_hint, 32)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.offset_bottom = -64
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	_setup_label(_message, 48)
	_message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_message.offset_top = -160
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _setup_label(label: Label, font_size: int) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.text = ""
	_damage_alpha = move_toward(_damage_alpha, 0.0, delta * 1.5)
	_damage_overlay.color.a = _damage_alpha


func set_stats(night: int, quota: int, earned: int, time_left: float, hp: float) -> void:
	var seconds := int(ceil(time_left))
	_stats.text = "夜 %d\nノルマ ¥%d / 収益 ¥%d\n残り %d:%02d\nHP %d" % [
		night, quota, earned, seconds / 60, seconds % 60, int(ceil(hp))
	]


func set_hint(text: String) -> void:
	_hint.text = text


## duration が 0 以下なら消えずに残る。
func show_message(text: String, duration := 3.0) -> void:
	_message.text = text
	_message_timer = duration


func flash_damage(amount: float) -> void:
	_damage_alpha = minf(_damage_alpha + amount * 0.03, 0.5)
