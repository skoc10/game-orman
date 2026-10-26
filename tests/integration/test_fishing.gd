extends GutTest
## Balıklar ve balık avı: sürülerin yerleşmesi, mızrakla vurma, olta ile tutma, pişirme.

const WORLD := preload("res://world/world.tscn")

var world: Node3D
var player: Player


func before_all() -> void:
	GameState.save_path = "user://test_saves/fishing.json"
	GameState.pending_load = {}
	GameState.new_game_seed = 42
	world = WORLD.instantiate()
	add_child(world)
	player = world.player
	await wait_physics_frames(5)


func after_all() -> void:
	world.queue_free()
	await wait_physics_frames(2)
	GameState.delete_save()
	GameState.save_path = GameState.SAVE_PATH


func _schools() -> Array:
	return get_tree().get_nodes_in_group("fish_school")


func test_fish_live_in_lake_and_sea() -> void:
	var lake := 0
	var sea := 0
	for s in _schools():
		if s.sea:
			sea += 1
		else:
			lake += 1
			assert_true(world.gen.is_fresh_water(s.global_position.x, s.global_position.z))
	assert_gt(lake, 0, "gölde balık olmalı")
	assert_gt(sea, 0, "denizde balık olmalı")


func test_fish_swim_under_water() -> void:
	await wait_physics_frames(10)
	for s in _schools():
		for f in s.fish:
			assert_lt(f.global_position.y, WorldGen.WATER_LEVEL, "balık su altında olmalı")


func test_hit_fish_floats_up_as_pickup() -> void:
	var school: FishSchool = _schools()[0]
	var f: Fish = school.fish[0]
	var before := school.alive_count()
	f.take_hit(30.0, player)
	await wait_physics_frames(2)
	assert_eq(school.alive_count(), before - 1)
	var floating: Array = world.dynamic_root.get_children().filter(func(n: Node) -> bool: return n is Pickup and n.item_id == "fish_raw")
	assert_eq(floating.size(), 1)
	assert_true(floating[0].floating)


func test_fishing_rod_catches_fish_on_time() -> void:
	player.inventory.set_slot(0, {"id": "fishing_rod", "count": 1, "dur": 25.0})
	player.equipment.select(0)
	var school: FishSchool = _schools()[0]
	var point := school.global_position
	player.global_position = point + Vector3(3, 0, 0)
	player.fishing.cast(point)
	assert_true(player.fishing.active)
	assert_false(player.fishing.biting)
	player.fishing._wait = 0.0
	await wait_process_frames(2)
	assert_true(player.fishing.biting, "balık vurmalı")
	var before := player.inventory.count_of("fish_raw")
	(player.fishing.interaction_info().action as Callable).call()
	assert_eq(player.inventory.count_of("fish_raw"), before + 1)
	assert_false(player.fishing.active)
	assert_lt(float(player.inventory.get_slot(0).dur), 25.0, "olta yıpranmalı")


func test_late_reel_loses_fish() -> void:
	var school: FishSchool = _schools()[0]
	player.global_position = school.global_position + Vector3(3, 0, 0)
	player.fishing.cast(school.global_position)
	player.fishing._wait = 0.0
	await wait_process_frames(2)
	player.fishing._bite_left = 0.0
	await wait_process_frames(2)
	assert_false(player.fishing.biting, "geç kalınca balık kaçmalı")
	player.fishing.stop()


func test_fish_can_be_cooked() -> void:
	assert_true(Cooking.can_cook("fish_raw"))
	var c := Cooking.new()
	c.add("fish_raw")
	c.tick(Balance.d.cook_time + 1.0, true)
	assert_eq(c.result_id(0), "fish_cooked")
	assert_not_null(ItemDB.get_recipe("fishing_rod"))
