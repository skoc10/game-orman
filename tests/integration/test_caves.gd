extends GutTest
## Mağaralar: üç tür, birbirine bağlı tüneller, ağızlar, karanlık, içerideki
## hayvan ve erzak, labirentin kıyıya çıkması, kayıt.

const WORLD := preload("res://world/world.tscn")

var world: Node3D
var player: Player


func before_all() -> void:
	GameState.save_path = "user://test_saves/caves.json"
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


func _cave(kind: Cave.Kind) -> Cave:
	for c in world.caves.caves:
		if c.kind == kind:
			return c
	return null


func test_three_cave_kinds_exist() -> void:
	assert_not_null(_cave(Cave.Kind.DEN), "ayı ini olmalı")
	assert_not_null(_cave(Cave.Kind.MAZE), "labirent olmalı")
	assert_not_null(_cave(Cave.Kind.SNAKES), "yılan mağarası olmalı")


func test_every_cell_is_reachable() -> void:
	for cave in world.caves.caves:
		var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		var seen := {cave.entrance: true}
		var queue: Array[Vector2i] = [cave.entrance]
		while not queue.is_empty():
			var c: Vector2i = queue.pop_front()
			for d in 4:
				if cave.open[c][d]:
					var n: Vector2i = c + dirs[d]
					if not seen.has(n):
						seen[n] = true
						queue.append(n)
		assert_eq(seen.size(), cave.size.x * cave.size.y, "%s: tüm hücrelere gidilebilmeli" % cave.display_name())
		assert_true(seen.has(cave.far_end))


func test_mouths_are_on_climbable_land() -> void:
	var mouths: Array = world.caves.mouths()
	assert_eq(mouths.size(), 4, "3 giriş + labirentin kıyı ağzı")
	for m in mouths:
		var p: Vector3 = m.global_position
		assert_true(world.gen.is_land(p.x, p.z, 0.5))
		assert_lt(world.gen.slope_at(p.x, p.z), 0.36, "ağız tırmanılabilir yamaçta olmalı")


func test_maze_has_coast_exit() -> void:
	var maze := _cave(Cave.Kind.MAZE)
	var coast_mouths := 0
	for m in world.caves.mouths():
		if m.cave == maze and m.label != "":
			coast_mouths += 1
			assert_gt(Vector2(m.global_position.x, m.global_position.z).length(), WorldGen.ISLAND_RADIUS * 0.65, "kıyıya yakın olmalı")
	assert_eq(coast_mouths, 1)


func test_entering_cave_makes_it_dark_and_warm() -> void:
	var den := _cave(Cave.Kind.DEN)
	var mouth: CaveMouth = null
	for m in world.caves.mouths():
		if m.cave == den:
			mouth = m
	await world.travel(mouth.target, 0.0)
	assert_true(world.is_underground(player.global_position))
	assert_true(den.contains(player.global_position))
	assert_false(player.is_swimming, "mağarada yüzülmez")
	world.day_night.update_now()
	assert_false(world.day_night.sun.visible)
	assert_lt(world.day_night.env.ambient_light_energy, 0.4)
	TimeOfDay.hour = 23.0
	player._warmth_timer = 0.0
	player._update_stats(0.01)
	assert_gt(player.current_warmth_target(), 50.0, "mağara gece ılık olmalı")
	TimeOfDay.hour = 12.0
	await wait_physics_frames(5)
	assert_lt(absf(player.global_position.y - den.entrance_point().y), 1.0, "zemine basmalı, düşmemeli")


func test_den_has_sleeping_bear_and_loot() -> void:
	var den := _cave(Cave.Kind.DEN)
	var bear: Bear = null
	for b in get_tree().get_nodes_in_group("bear"):
		if den.contains(b.global_position):
			bear = b
	assert_not_null(bear, "inde ayı olmalı")
	assert_true(bear.sleeping)
	assert_true(bear.indoor)
	var loot: Array = world.dynamic_root.get_children().filter(func(n: Node) -> bool: return n is Pickup and den.contains(n.global_position))
	assert_gt(loot.size(), 2, "inde erzak olmalı")


func test_snake_cave_has_snakes() -> void:
	var cave := _cave(Cave.Kind.SNAKES)
	var n := 0
	for s in get_tree().get_nodes_in_group("snake"):
		if cave.contains(s.global_position):
			n += 1
	assert_eq(n, 3)


func test_cave_animals_are_saved_indoor() -> void:
	var data: Dictionary = world.collect_save()
	var indoor: Array = data.dynamic.filter(func(e: Dictionary) -> bool: return e.get("type", "") == "animal" and e.get("indoor", false))
	assert_gt(indoor.size(), 4)
