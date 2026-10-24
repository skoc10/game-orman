extends GutTest
## Dünya sahnesini gerçekten yükleyip temel oyun döngüsünü dener:
## kaynak toplama, ağaç kesme, su içme, yemek yeme ve yeniden yetişme.

const WORLD := preload("res://world/world.tscn")

var world: Node3D
var player: Player


func before_all() -> void:
	GameState.pending_load = {}
	GameState.new_game_seed = 42
	world = WORLD.instantiate()
	add_child(world)
	player = world.player
	await wait_physics_frames(5)


func after_all() -> void:
	world.queue_free()
	await wait_frames(2)


func test_world_builds_with_everything() -> void:
	assert_gt(world.trees.count(), 1000)
	assert_gt(world.resources.nodes.size(), 500)
	var picks: Array = world.dynamic_root.get_children().filter(func(n: Node) -> bool: return n is Pickup)
	var ids: Array = picks.map(func(p: Pickup) -> String: return p.item_id)
	assert_has(ids, "pot", "kampta metal kap olmalı")
	assert_has(ids, "canteen", "kampta matara olmalı")


func test_player_starts_on_dry_ground() -> void:
	var p := player.global_position
	assert_gt(world.gen.height_at(p.x, p.z), 0.5)
	assert_false(player.is_swimming)


func test_harvest_and_regrow() -> void:
	var node: ResourceNode = null
	for n in world.resources.nodes:
		if n.kind == "bush":
			node = n
			break
	assert_not_null(node)
	var before := player.inventory.count_of("berries")
	var info: Dictionary = node.get_interaction(player, 0)
	(info.action as Callable).call()
	assert_eq(player.inventory.count_of("berries"), before + 3)
	assert_false(node.available)
	assert_eq(node.get_interaction(player, 0).get("action", null), null, "toplanmış çalı tekrar toplanamaz")
	var start_day := TimeOfDay.day
	TimeOfDay.day_changed.emit(start_day + node.regrow_days())
	assert_true(node.available, "çalı birkaç gün sonra yeniden yetişmeli")


func test_pickup_goes_to_inventory() -> void:
	var p: Pickup = world.spawn_pickup("stone", 3, player.global_position + Vector3(1, 0, 0))
	var before := player.inventory.count_of("stone")
	(p.get_interaction(player, 0).action as Callable).call()
	assert_eq(player.inventory.count_of("stone"), before + 3)
	await wait_frames(1)
	assert_false(is_instance_valid(p), "alınan eşya dünyadan silinmeli")


func test_chop_tree_drops_logs() -> void:
	var trees: TreeField = world.trees
	var id := 0
	var logs_before := _count_pickups("log")
	for i in 3:
		trees.hit(id, 25.0, trees.positions[id] + Vector3(2, 0, 0))
	assert_false(trees.felled.has(id), "üç vuruşta devrilmemeli")
	trees.hit(id, 25.0, trees.positions[id] + Vector3(2, 0, 0))
	assert_true(trees.felled.has(id))
	await wait_seconds(2.0)
	assert_eq(_count_pickups("log"), logs_before + TreeField.LOGS[trees.kinds[id]])


func test_drink_and_eat() -> void:
	player.stats.thirst = 50.0
	player.drink_fresh_water()
	assert_almost_eq(player.stats.thirst, 50.0 + Balance.d.lake_sip_thirst, 0.5)
	player.inventory.add("berries", 1)
	player.stats.hunger = 50.0
	var idx := -1
	for i in player.inventory.size():
		if player.inventory.get_slot(i).get("id", "") == "berries":
			idx = i
	player.equipment.select(0)
	player.inventory.move(idx, 0)
	player.equipment._consume(player.inventory.slot_item(0))
	assert_almost_eq(player.stats.hunger, 50.0 + ItemDB.get_item("berries").hunger, 0.5)


func test_clothes_reduce_cold() -> void:
	assert_eq(player.cold_resist(), 1.0)
	player.inventory.add("hide_clothes")
	assert_lt(player.cold_resist(), 1.0)
	player.inventory.remove("hide_clothes")


func _count_pickups(id: String) -> int:
	var n := 0
	for c in world.dynamic_root.get_children():
		if c is Pickup and c.item_id == id and not c.is_queued_for_deletion():
			n += 1
	return n


func test_campfire_cooks_boils_and_warms() -> void:
	var fire: Node3D = load("res://buildables/campfire.tscn").instantiate()
	world.dynamic_root.add_child(fire)
	fire.global_position = player.global_position + Vector3(2, 0, 0)
	assert_true(fire.is_burning())
	assert_true(fire.is_in_group("persist_dynamic"))
	assert_gt(fire.warmth_for(player.global_position), TimeOfDay.ambient_warmth() - 0.1)

	var inv := player.inventory
	inv.add("meat_raw", 1)
	var info: Dictionary = fire.get_interaction(player, 0)
	assert_string_contains(str(info.text), "pişir")
	(info.action as Callable).call()
	assert_eq(fire.cooking.state(0), "cooking")
	fire.cooking.tick(Balance.d.cook_time + 1.0, true)
	info = fire.get_interaction(player, 0)
	(info.action as Callable).call()
	assert_true(inv.has("meat_cooked"))

	inv.add("pot", 1)
	inv.add("water_raw", 2)
	info = fire.get_interaction(player, 0)
	assert_string_contains(str(info.text), "kaynat")
	(info.action as Callable).call()
	assert_false(inv.has("pot"), "kap ateşe konmalı")
	fire.cooking.tick(Balance.d.boil_time + 1.0, true)
	(fire.get_interaction(player, 0).action as Callable).call()
	assert_eq(inv.count_of("water_clean"), 2)
	assert_true(inv.has("pot"))

	fire.fuel = 0.0
	assert_false(fire.is_burning())
	assert_eq(fire.warmth_for(player.global_position), -1.0)
	inv.add("stick", 1)
	(fire.get_interaction(player, 0).action as Callable).call()
	assert_true(fire.is_burning(), "dal ekleyince ateş yeniden yanmalı")
	fire.queue_free()


func test_fill_canteen_respects_capacity() -> void:
	var inv := player.inventory
	inv.remove("water_raw", inv.count_of("water_raw"))
	inv.remove("water_clean", inv.count_of("water_clean"))
	inv.remove("canteen", inv.count_of("canteen"))
	assert_eq(player.canteen_space(), 0)
	inv.add("canteen", 1)
	player.fill_canteen()
	assert_eq(inv.count_of("water_raw"), Balance.d.canteen_capacity)
	player.fill_canteen()
	assert_eq(inv.count_of("water_raw"), Balance.d.canteen_capacity, "kapasite aşılmamalı")
