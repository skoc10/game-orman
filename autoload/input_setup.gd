extends Node
## Oyun girdilerini çalışma anında tanımlar: klavye, fare ve gamepad.
## Tuşlar fiziksel konuma göre bağlanır, klavye düzeninden etkilenmez.

const DEADZONE := 0.2


func _enter_tree() -> void:
	_bind("move_forward", [KEY_W, KEY_UP], [], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("move_back", [KEY_S, KEY_DOWN], [], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("move_left", [KEY_A, KEY_LEFT], [], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("look_up", [], [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_bind("look_down", [], [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_bind("look_left", [], [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_bind("look_right", [], [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_bind("jump", [KEY_SPACE], [], [JOY_BUTTON_A])
	_bind("sprint", [KEY_SHIFT], [], [JOY_BUTTON_LEFT_STICK])
	_bind("crouch", [KEY_CTRL, KEY_C], [], [JOY_BUTTON_RIGHT_STICK])
	_bind("interact", [KEY_E], [], [JOY_BUTTON_X])
	_bind("attack", [], [MOUSE_BUTTON_LEFT], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_bind("alt_action", [], [MOUSE_BUTTON_RIGHT], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_bind("inventory", [KEY_TAB, KEY_I], [], [JOY_BUTTON_Y])
	_bind("build", [KEY_B], [], [JOY_BUTTON_DPAD_UP])
	_bind("rotate_build", [KEY_R], [], [JOY_BUTTON_DPAD_RIGHT])
	_bind("hotbar_next", [], [MOUSE_BUTTON_WHEEL_DOWN], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("hotbar_prev", [], [MOUSE_BUTTON_WHEEL_UP], [JOY_BUTTON_LEFT_SHOULDER])
	for i in 5:
		_bind("hotbar_%d" % (i + 1), [KEY_1 + i])
	_bind("quick_save", [KEY_F5], [], [JOY_BUTTON_BACK])
	_bind("pause", [KEY_ESCAPE], [], [JOY_BUTTON_START])


func _bind(action: StringName, keys: Array = [], mouse: Array = [], joy_buttons: Array = [], joy_axes: Array = []) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, DEADZONE)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in mouse:
		var ev := InputEventMouseButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
	for b in joy_buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
	for a in joy_axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = a[0]
		ev.axis_value = a[1]
		InputMap.action_add_event(action, ev)
