extends GutTest
## Yerli köyü: yer seçimi, temizlenmiş meydan, köylüler, takas, misafir çadırı,
## kurt/ayıların köye girmemesi ve kayıt.

const WORLD := preload("res://world/world.tscn")

var world: Node3D
var player: Player


func before_all() -> void:
	GameState.save_path = "user://test_saves/village.json"
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


func test_village_is_on_dry_land_away_from_spawn() -> void:
	var v: Village = world.village
	assert_not_null(v, "köy kurulmalı")
	var c := v.global_position
	assert_true(world.gen.is_land(c.x, c.z, 1.0))
	var d := Vector2(c.x - world.spawn_point.x, c.z - world.spawn_point.z).length()
	assert_between(d, 60.0, 170.0, "köy başlangıçtan uzakta olmalı")
	for m in world.caves.mouths():
		assert_gt(m.global_position.distance_to(c), 40.0, "köy mağara ağzına yakın olmamalı")


func test_same_seed_same_village() -> void:
	var again := Village.find_center(world.gen, world.spawn_point, [world.spawn_point] + world.caves.mouths().map(func(m: Node3D) -> Vector3: return m.global_position))
	assert_almost_eq(again.x, world.village.global_position.x, 0.01)
	assert_almost_eq(again.z, world.village.global_position.z, 0.01)


func test_square_is_cleared_of_trees() -> void:
	var c: Vector3 = world.village.global_position
	var trees: TreeField = world.trees
	for id in trees.count():
		var p := trees.positions[id]
		if Vector2(p.x - c.x, p.z - c.z).length() < Village.RADIUS:
			assert_true((trees._shapes[id] as CollisionShape3D).disabled, "meydanda ağaç kalmamalı")


func test_villagers_and_chief_exist_and_are_peaceful() -> void:
	var villagers := get_tree().get_nodes_in_group("villager")
	assert_eq(villagers.size(), Village.VILLAGERS + 1)
	var chief: Villager = world.village.chief
	assert_true(chief.is_chief)
	var hp := chief.health
	chief.take_hit(50.0, player)
	assert_eq(chief.health, hp, "köylüler zarar görmez")
	assert_false(chief.is_in_group("persist_dynamic"), "köylüler kayda yazılmaz")
	var info: Dictionary = chief.get_interaction(player, 0)
	assert_string_contains(str(info.text), "takas")


func test_trade_through_screen() -> void:
	var screen := world.get_node("TradeScreen")
	var t: Trading = world.village.trading
	var o: Dictionary = t.offers[0]
	for id in o.give:
		player.inventory.add(id, int(o.give[id]))
	(world.village.chief.get_interaction(player, 0).action as Callable).call()
	assert_true(screen.is_open)
	assert_true(player.input_locked)
	screen._trade(0)
	for id in o.get:
		assert_true(player.inventory.has(id, int(o.get[id])), "takas edilen eşya envantere gelmeli")
	screen.close()
	assert_false(player.input_locked)


func test_village_fire_never_goes_out() -> void:
	var fire: Node3D = world.village.fire
	assert_true(fire.eternal)
	var fuel: float = fire.fuel
	fire._process(100.0)
	assert_eq(fire.fuel, fuel)
	assert_false(fire.is_in_group("persist_dynamic"))


func test_guest_tent_allows_sleep() -> void:
	var guest: VillageTent = null
	for c in world.village.get_children():
		if c is VillageTent and c.guest:
			guest = c
	assert_not_null(guest)
	TimeOfDay.hour = 22.0
	player.stats.from_dict({})
	var info: Dictionary = guest.get_interaction(player, 0)
	assert_string_contains(str(info.text), "uyu")
	TimeOfDay.hour = 12.0


func test_wolves_and_bears_do_not_enter() -> void:
	var c: Vector3 = world.village.global_position
	var wolf: Wolf = world.animals.spawn_animal("wolf", c + Vector3(40, 0, 0))
	var bear: Bear = world.animals.spawn_animal("bear", c + Vector3(-40, 0, 0))
	await wait_physics_frames(1)
	assert_false(wolf._walkable(c + Vector3(3, 0, 0)))
	assert_false(bear._walkable(c + Vector3(3, 0, 0)))
	wolf.queue_free()
	bear.queue_free()


func test_trade_stock_is_saved() -> void:
	var t: Trading = world.village.trading
	var data: Dictionary = JSON.parse_string(JSON.stringify(world.collect_save()))
	assert_true(data.has("village"))
	assert_eq(int(data.village.trade.day), t.day)
