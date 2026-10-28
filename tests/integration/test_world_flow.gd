extends GutTest
## Dünya sahnesini gerçekten yükleyip temel oyun döngüsünü dener:
## kaynak toplama, ağaç kesme, su içme, yemek yeme ve yeniden yetişme.

const WORLD := preload("res://world/world.tscn")

var world: Node3D
var player: Player


const TEST_SAVE := "user://test_saves/world_flow.json"


func before_all() -> void:
	GameState.save_path = TEST_SAVE
	GameState.pending_load = {}
	GameState.new_game_seed = 42
	world = WORLD.instantiate()
	add_child(world)
	player = world.player
	await wait_physics_frames(5)


func after_all() -> void:
	world.queue_free()
	await wait_frames(2)
	GameState.delete_save()
	GameState.save_path = GameState.SAVE_PATH


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
	assert_eq(player.inventory.count_of("berries"), before + int(ResourceNode.KINDS.bush.yields.berries))
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


func test_build_campfire_with_build_mode() -> void:
	var inv := player.inventory
	inv.add("stone", 4)
	inv.add("stick", 4)
	player.head.rotation.x = deg_to_rad(-45.0)
	await wait_frames(1)
	var before := _count_buildables()
	player.build.start(ItemDB.get_recipe("campfire"))
	assert_true(player.build.is_placing())
	# Önce önizlemeyi uygun bir yere taşı: oyuncunun önü açık değilse etrafında döndür.
	var placed := false
	for i in 16:
		player.rotation.y += TAU / 16.0
		player.build._update_ghost()
		if player.build.valid:
			placed = player.build.place()
			break
	assert_true(placed, "kamp ateşi yerleştirilebilmeli: %s" % player.build.reason)
	assert_false(player.build.is_placing())
	await wait_frames(1)
	assert_eq(_count_buildables(), before + 1)
	player.head.rotation.x = 0.0


func test_build_rejected_without_materials() -> void:
	var inv := player.inventory
	inv.remove("log", inv.count_of("log"))
	player.head.rotation.x = deg_to_rad(-45.0)
	player.build.start(ItemDB.get_recipe("shelter"))
	player.build._update_ghost()
	assert_false(player.build.valid)
	assert_false(player.build.place())
	player.build.cancel()
	player.head.rotation.x = 0.0


func test_sleep_skips_to_morning_and_saves() -> void:
	TimeOfDay.hour = 22.0
	var day := TimeOfDay.day
	player.stats.hunger = 80.0
	player.stats.thirst = 80.0
	assert_true(world.is_sleep_time())
	assert_eq(world.sleep_block_reason(player), "")
	await world.sleep_until_morning()
	assert_eq(TimeOfDay.day, day + 1)
	assert_almost_eq(TimeOfDay.hour, 6.0, 0.05)
	assert_almost_eq(player.stats.hunger, 80.0 - Balance.d.sleep_hunger_cost, 1.0)
	assert_true(GameState.has_save())
	assert_false(player.input_locked)


func test_cannot_sleep_when_starving() -> void:
	player.stats.hunger = 5.0
	assert_ne(world.sleep_block_reason(player), "")
	player.stats.hunger = 80.0


func test_save_and_load_roundtrip() -> void:
	player.inventory.add("rope", 2)
	world.trees.fell(5, Vector3.FORWARD)
	await wait_seconds(2.0)
	var box := BuildSystem.spawn(ItemDB.get_recipe("storage_box"), Transform3D(Basis(), player.global_position + Vector3(3, 0, 3)))
	box.inventory.add("mushroom", 4)
	TimeOfDay.hour = 15.5
	var data: Dictionary = JSON.parse_string(JSON.stringify(world.collect_save()))

	GameState.pending_load = data
	var loaded: Node3D = WORLD.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(loaded)
	await wait_physics_frames(3)
	assert_eq(loaded.gen.seed_value, world.gen.seed_value)
	assert_true(loaded.trees.felled.has(5), "kesilen ağaç kayıttan gelmeli")
	assert_eq(loaded.player.inventory.count_of("rope"), player.inventory.count_of("rope"))
	assert_almost_eq(TimeOfDay.hour, 15.5, 0.1)
	var boxes: Array = loaded.get_tree().get_nodes_in_group("buildable").filter(
		func(n: Node) -> bool: return loaded.is_ancestor_of(n) and n.recipe_id == "storage_box")
	assert_eq(boxes.size(), 1)
	if boxes.size() == 1:
		assert_eq(boxes[0].inventory.count_of("mushroom"), 4)
	var logs: Array = loaded.dynamic_root.get_children().filter(func(n: Node) -> bool: return n is Pickup and n.item_id == "log")
	assert_gt(logs.size(), 0, "yerdeki kütükler kayıttan gelmeli")
	loaded.queue_free()
	await wait_frames(2)
	world.process_mode = Node.PROCESS_MODE_INHERIT
	GameState.world = world


func _count_buildables() -> int:
	return get_tree().get_nodes_in_group("buildable").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()


func test_assisted_targeting_finds_item_without_exact_aim() -> void:
	# Oyuncunun önüne, tam nişan çizgisinin biraz yanına bir taş bırak.
	player.rotation.y = 0.0
	player.head.rotation.x = deg_to_rad(-35.0)
	var fwd := -player.global_transform.basis.z
	var side := player.global_transform.basis.x
	var p: Vector3 = player.global_position + fwd * 1.8 + side * 0.35
	p.y = world.gen.height_at(p.x, p.z)
	var pickup: Pickup = world.spawn_pickup("stone", 1, p)
	await wait_physics_frames(2)
	var info: Dictionary = player.interaction._scan()
	assert_string_contains(str(info.get("text", "")), "Taş", "yakındaki taş hedeflenmeli")
	assert_true(info.get("auto", false))
	pickup.queue_free()
	player.head.rotation.x = 0.0


func test_raft_is_placed_on_water_and_carries_player() -> void:
	var recipe := ItemDB.get_recipe("raft")
	assert_not_null(recipe)
	# Göl merkezine kur, bin, sür, in.
	var c: Vector2 = world.gen.lake_center
	var raft: Node3D = BuildSystem.spawn(recipe, Transform3D(Basis(), Vector3(c.x, 0, c.y)))
	await wait_physics_frames(2)
	assert_almost_eq(raft.global_position.y, WorldGen.WATER_LEVEL, 0.2, "sal suyun üstünde durmalı")
	raft.board(player)
	assert_eq(player.vehicle, raft)
	var start: Vector3 = raft.global_position
	for i in 60:
		raft.drive(Vector3.RIGHT, false, 1.0 / 60.0)
	assert_gt(raft.global_position.distance_to(start), 0.5, "sal kürekle ilerlemeli")
	await wait_physics_frames(2)
	assert_lt(player.global_position.distance_to(raft.seat_position()), 0.3, "oyuncu salda oturmalı")
	assert_false(player.is_swimming)
	assert_false(raft.can_float_at(world.spawn_point), "sal karaya çıkamamalı")
	var info: Dictionary = player.interaction._scan()
	assert_string_contains(str(info.get("text", "")), "Saldan in")
	raft.leave()
	assert_null(player.vehicle)
	raft.queue_free()
	player.teleport(world.spawn_point + Vector3.UP * 0.2)


func test_raft_ghost_needs_deep_water() -> void:
	player.inventory.add("log", 6)
	player.inventory.add("rope", 3)
	player.build.start(ItemDB.get_recipe("raft"))
	# Kuru arazide geçersiz olmalı.
	player.teleport(world.spawn_point + Vector3.UP * 0.2)
	player.head.rotation.x = deg_to_rad(-45.0)
	player.build._update_ghost()
	assert_false(player.build.valid)
	player.build.cancel()
	player.head.rotation.x = 0.0
