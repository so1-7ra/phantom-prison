class_name InputSetup
extends RefCounted
## 入力アクションをコードで登録する（project.godot を手で編集しなくて済むように）。


static func register() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("grab", KEY_E)
	_add_mouse("grab", MOUSE_BUTTON_LEFT)
	_add_mouse("throw", MOUSE_BUTTON_RIGHT)
	_add_key("end_night", KEY_F)
	_add_key("restart", KEY_R)
	_add_key("pause", KEY_ESCAPE)


static func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


static func _add_key(action: StringName, keycode: Key) -> void:
	_ensure_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)


static func _add_mouse(action: StringName, button: MouseButton) -> void:
	_ensure_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
