extends GutTest
## Dokunmatik kontroller: çubuk hareket eylemi üretir, düğmeler eylemleri basar,
## sağ tarafta sürüklemek bakışı çevirir, menü açıkken kontroller gizlenir.

const WORLD := preload("res://world/world.tscn")

var world: Node3D
var player: Player
var touch: CanvasLayer
var _saved_touch := ""


func before_all() -> void:
	_saved_touch = str(GameState.settings.touch_controls)
	GameState.settings.touch_controls = "on"
	GameState.save_path = "user://test_saves/touch.json"
	GameState.pending_load = {}
	GameState.new_game_seed = 42
	world = WORLD.instantiate()
	add_child(world)
	player = world.player
	touch = world.get_node("TouchControls")
	await wait_physics_frames(3)


func after_all() -> void:
	world.queue_free()
	await wait_physics_frames(2)
	GameState.settings.touch_controls = _saved_touch
	GameState.save_path = GameState.SAVE_PATH
	InputSetup._enter_tree()


func _screen() -> Vector2:
	return touch.get_viewport().get_visible_rect().size


func _tap(pos: Vector2, index: int, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	touch._input(e)


func _drag(pos: Vector2, rel: Vector2, index: int) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	touch._input(e)


func test_touch_mode_is_on() -> void:
	assert_true(touch.enabled)
	assert_true(player.touch_mode)
	for ev in InputMap.action_get_events("attack"):
		assert_false(ev is InputEventMouseButton, "dokunuştan türeyen tık vuruş sayılmamalı")


func test_stick_moves_player() -> void:
	var size := _screen()
	var start := Vector2(200, size.y - 200)
	_tap(start, 0, true)
	_drag(start + Vector2(0, -80), Vector2(0, -80), 0)
	await wait_physics_frames(1)
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	assert_lt(v.y, -0.7, "çubuk yukarı itilince ileri yürünmeli")
	_tap(start + Vector2(0, -80), 0, false)
	await wait_physics_frames(1)
	assert_eq(Input.get_vector("move_left", "move_right", "move_forward", "move_back"), Vector2.ZERO)


func test_attack_button_holds_action() -> void:
	var size := _screen()
	var c: Vector2 = touch._center(touch.BUTTONS[0], size)
	_tap(c, 1, true)
	await wait_physics_frames(1)
	assert_true(Input.is_action_pressed("attack"))
	_tap(c, 1, false)
	await wait_physics_frames(1)
	assert_false(Input.is_action_pressed("attack"))


func test_sprint_toggle() -> void:
	var size := _screen()
	var b: Array = touch.BUTTONS.filter(func(x: Array) -> bool: return x[0] == "sprint")[0]
	var c: Vector2 = touch._center(b, size)
	_tap(c, 2, true)
	_tap(c, 2, false)
	await wait_physics_frames(1)
	assert_true(Input.is_action_pressed("sprint"), "koş açık kalmalı")
	_tap(c, 2, true)
	_tap(c, 2, false)
	await wait_physics_frames(1)
	assert_false(Input.is_action_pressed("sprint"))


func test_drag_right_side_turns_camera() -> void:
	var size := _screen()
	var yaw := player.rotation.y
	var p := Vector2(size.x * 0.65, size.y * 0.4)
	_tap(p, 3, true)
	_drag(p + Vector2(120, 0), Vector2(120, 0), 3)
	_tap(p + Vector2(120, 0), 3, false)
	assert_ne(player.rotation.y, yaw, "sürükleyince bakış dönmeli")


func test_hidden_while_inventory_open() -> void:
	world.get_node("InventoryScreen").open()
	await wait_process_frames(2)
	assert_false(touch._is_active())
	world.get_node("InventoryScreen").close()
	await wait_process_frames(2)
	assert_true(touch._is_active())
