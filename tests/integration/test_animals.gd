extends GutTest
## Hayvan davranışları: geyiğin kaçması, kurdun saldırması ve ateşten çekinmesi,
## leşten et alma, mızrak fırlatma, gece sürüleri ve kayıt.

const WORLD := preload("res://world/world.tscn")
const TEST_SAVE := "user://test_saves/animals.json"

var world: Node3D
var player: Player


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


func before_each() -> void:
	TimeOfDay.hour = 12.0
	player.stats.from_dict({})
	for a in get_tree().get_nodes_in_group("animal"):
		if a.global_position.distance_to(player.global_position) < 60.0:
			a.free()
	for f in get_tree().get_nodes_in_group("fire"):
		f.free()


func _spawn(species: String, offset: Vector3) -> AnimalBase:
	var p := player.global_position + offset
	p.y = world.gen.height_at(p.x, p.z) + 0.1
	return world.animals.spawn_animal(species, p)


func test_world_has_deer_and_wolves() -> void:
	assert_gt(world.animals.deer_count(), 5)
	assert_gt(world.animals.wolf_count(), 0)


func test_deer_flees_from_sprinting_player() -> void:
	var deer := _spawn("deer", Vector3(10, 0, 0)) as Deer
	await wait_physics_frames(1)
	player.is_sprinting = true
	deer.think(0.1, player, deer.global_position.distance_to(player.global_position))
	player.is_sprinting = false
	assert_eq(deer.state, AnimalBase.State.FLEE)


func test_crouching_lets_player_get_closer() -> void:
	var deer := _spawn("deer", Vector3(10, 0, 0)) as Deer
	await wait_physics_frames(1)
	player.is_crouching = true
	player.is_moving = false
	var crouch_r := deer.perception_radius(player)
	player.is_crouching = false
	assert_lt(crouch_r, deer.perception_radius(player))
	assert_lt(crouch_r, 10.0, "eğilen oyuncuyu 10 m'den fark etmemeli")


func test_hurt_deer_alerts_herd() -> void:
	var a := _spawn("deer", Vector3(20, 0, 0)) as Deer
	var b := _spawn("deer", Vector3(23, 0, 2)) as Deer
	await wait_physics_frames(1)
	a.take_hit(5.0, player)
	assert_eq(a.state, AnimalBase.State.FLEE)
	assert_eq(b.state, AnimalBase.State.FLEE)


func test_wolf_stalks_then_bites() -> void:
	var wolf := _spawn("wolf", Vector3(8, 0, 0)) as Wolf
	await wait_physics_frames(1)
	wolf.think(0.1, player, 8.0)
	assert_eq(wolf.state, AnimalBase.State.STALK)
	wolf.set_state(AnimalBase.State.CHASE)
	wolf.think(0.1, player, 1.5)
	assert_eq(wolf.state, AnimalBase.State.ATTACK)
	var hp := player.stats.health
	wolf.think(0.1, player, 1.5)
	assert_lt(player.stats.health, hp, "kurt ısırmalı")
	assert_true(wolf.is_threat())


func test_wolf_will_not_enter_fire() -> void:
	var fire: Node3D = load("res://buildables/campfire.tscn").instantiate()
	world.dynamic_root.add_child(fire)
	fire.global_position = player.global_position
	var wolf := _spawn("wolf", Vector3(4, 0, 0)) as Wolf
	await wait_physics_frames(1)
	wolf.set_state(AnimalBase.State.CHASE)
	wolf.think(0.1, player, 4.0)
	assert_ne(wolf.state, AnimalBase.State.CHASE, "ateşin yanında kovalamayı bırakmalı")
	var away := wolf.global_position - fire.global_position
	assert_gt(wolf._move_dir.dot(Vector3(away.x, 0, away.z).normalized()), 0.5, "ateşten uzaklaşmalı")
	fire.free()


func test_torch_makes_wolves_keep_distance() -> void:
	var wolf := _spawn("wolf", Vector3(8, 0, 0)) as Wolf
	await wait_physics_frames(1)
	assert_eq(wolf._keep_distance(player), 0.0)
	player.inventory.set_slot(0, {"id": "torch", "count": 1, "dur": 100.0})
	player.equipment.select(0)
	assert_eq(wolf._keep_distance(player), Balance.d.torch_fear_radius)
	player.inventory.set_slot(0, {})


func test_hurt_wolf_retreats() -> void:
	var wolf := _spawn("wolf", Vector3(8, 0, 0)) as Wolf
	await wait_physics_frames(1)
	wolf.take_hit(wolf.max_health * 0.7, player)
	wolf.think(0.1, player, 8.0)
	assert_eq(wolf.state, AnimalBase.State.RETREAT)
	assert_false(wolf.is_threat())


func test_kill_and_butcher_deer() -> void:
	var deer := _spawn("deer", Vector3(3, 0, 0)) as Deer
	await wait_physics_frames(1)
	deer.take_hit(999.0, player)
	assert_eq(deer.state, AnimalBase.State.DEAD)
	assert_true(deer.is_in_group("corpse"))
	player.inventory.remove("knife", player.inventory.count_of("knife"))
	var info: Dictionary = deer.get_interaction(player, 0)
	assert_false(info.has("action"), "bıçaksız kesilemez")
	player.inventory.add("knife")
	info = deer.get_interaction(player, 0)
	var meat := player.inventory.count_of("meat_raw")
	(info.action as Callable).call()
	assert_eq(player.inventory.count_of("meat_raw"), meat + 3)
	assert_true(player.inventory.has("hide"))


func test_thrown_spear_hits_deer_and_drops() -> void:
	var deer := _spawn("deer", Vector3(0, 0, -6)) as Deer
	await wait_physics_frames(2)
	# Mızrak mekaniğini sınamak için geyik yerinde tutulur (kaçışı ayrı testte).
	deer.set_physics_process(false)
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0
	var target := deer.global_position + Vector3(0, 0.9, 0)
	player.head.look_at(target)
	player.head.rotation.y = 0.0
	player.inventory.set_slot(0, {"id": "spear", "count": 1, "dur": 60.0})
	player.equipment.select(0)
	var hp := deer.health
	player.equipment.use_secondary()
	assert_false(player.inventory.has("spear"), "mızrak elden çıkmalı")
	await wait_physics_frames(30)
	assert_lt(deer.health, hp, "mızrak geyiğe isabet etmeli")
	var spears: Array = world.dynamic_root.get_children().filter(func(n: Node) -> bool: return n is Pickup and n.item_id == "spear")
	assert_eq(spears.size(), 1, "mızrak yere düşüp alınabilir olmalı")
	player.head.rotation = Vector3.ZERO


func test_night_brings_wolves_and_morning_clears_far_ones() -> void:
	var before: int = world.animals.wolf_count()
	world.animals._on_night()
	var night: Array = get_tree().get_nodes_in_group("night_only")
	assert_gt(night.size(), 0)
	assert_gt(world.animals.wolf_count(), before)
	world.animals.on_morning_skip()
	await wait_frames(1)
	for w in get_tree().get_nodes_in_group("night_only"):
		assert_lt(w.global_position.distance_to(player.global_position), 36.0)


func test_wolf_nearby_blocks_sleep() -> void:
	TimeOfDay.hour = 22.0
	player.stats.from_dict({})
	assert_eq(world.sleep_block_reason(player), "")
	_spawn("wolf", Vector3(10, 0, 0))
	await wait_physics_frames(1)
	assert_ne(world.sleep_block_reason(player), "")


func test_animals_are_saved() -> void:
	var deer := _spawn("deer", Vector3(12, 0, 0))
	await wait_physics_frames(1)
	deer.take_hit(999.0, player)
	var data: Dictionary = world.collect_save()
	var entries: Array = data.dynamic.filter(func(e: Dictionary) -> bool: return e.get("type", "") == "animal")
	assert_gt(entries.size(), 5)
	var dead: Array = entries.filter(func(e: Dictionary) -> bool: return int(e.died_day) >= 0)
	assert_gt(dead.size(), 0, "leş de kaydedilmeli")


func test_fleeing_deer_turns_away_smoothly_and_looks_back() -> void:
	var deer := _spawn("deer", Vector3(8, 0, 0)) as Deer
	await wait_physics_frames(1)
	deer.flee_from(player.global_position)
	deer.think(0.1, player, 8.0)
	var away := deer.global_position - player.global_position
	away.y = 0.0
	assert_gt(deer._move_dir.dot(away.normalized()), 0.6, "tehditten uzağa kaçmalı")
	assert_eq(deer._speed, deer.run_speed)
	# Güvenli mesafeye ulaşınca durup geri bakar.
	deer._state_time = 4.0
	deer.think(0.1, player, 60.0)
	assert_eq(deer.state, AnimalBase.State.ALERT)
	assert_true(deer._looking_back)


func test_herd_flees_in_same_direction() -> void:
	var a := _spawn("deer", Vector3(20, 0, 0)) as Deer
	var b := _spawn("deer", Vector3(22, 0, 4)) as Deer
	await wait_physics_frames(1)
	a.take_hit(5.0, player)
	assert_gt(b._flee_dir.dot(Vector3(1, 0, 0)), 0.7, "sürü aynı yöne kaçmalı")


func test_new_species_are_populated() -> void:
	assert_gt(get_tree().get_nodes_in_group("rabbit").size(), 3)
	assert_gt(get_tree().get_nodes_in_group("bear").size(), 0)
	assert_gt(get_tree().get_nodes_in_group("snake").size(), 5)
	assert_gt(get_tree().get_nodes_in_group("birds").size(), 5)


func test_rabbit_zigzags_away() -> void:
	var rabbit := _spawn("rabbit", Vector3(6, 0, 0)) as Rabbit
	await wait_physics_frames(1)
	rabbit.think(0.1, player, 6.0)
	assert_eq(rabbit.state, AnimalBase.State.FLEE)
	var first := rabbit._zig_angle
	rabbit.think(0.8, player, 7.0)
	assert_ne(rabbit._zig_angle, first, "zikzak yönü değişmeli")


func test_bear_warns_then_charges_and_swipes() -> void:
	var bear := _spawn("bear", Vector3(10, 0, 0)) as Bear
	await wait_physics_frames(1)
	bear.think(0.1, player, 10.0)
	assert_eq(bear.state, AnimalBase.State.ALERT, "önce kalkıp uyarmalı")
	bear._state_time = 2.0
	bear.think(0.1, player, 9.0)
	assert_eq(bear.state, AnimalBase.State.CHASE)
	bear.think(0.1, player, 2.0)
	assert_eq(bear.state, AnimalBase.State.ATTACK)
	var hp := player.stats.health
	bear.think(0.1, player, 2.0)
	assert_lt(player.stats.health, hp - 15.0, "ayı pençesi ağır vurmalı")


func test_bear_backs_off_when_player_leaves() -> void:
	var bear := _spawn("bear", Vector3(10, 0, 0)) as Bear
	await wait_physics_frames(1)
	bear.think(0.1, player, 10.0)
	bear._state_time = 2.0
	bear.think(0.1, player, 30.0)
	assert_eq(bear.state, AnimalBase.State.WANDER)


func test_sleeping_bear_wakes_only_when_close() -> void:
	var bear := _spawn("bear", Vector3(8, 0, 0)) as Bear
	await wait_physics_frames(1)
	bear.sleeping = true
	bear.think(0.1, player, 8.0)
	assert_true(bear.sleeping, "uzaktan sessizce geçilebilmeli")
	bear.think(0.1, player, 4.0)
	assert_false(bear.sleeping)


func test_snake_hisses_then_bites_with_venom() -> void:
	var snake := _spawn("snake", Vector3(3, 0, 0)) as Snake
	await wait_physics_frames(1)
	snake.think(0.1, player, 3.0)
	assert_eq(snake.state, AnimalBase.State.ALERT)
	snake._state_time = 1.0
	var hp := player.stats.health
	snake.think(0.1, player, 2.0)
	assert_lt(player.stats.health, hp)
	assert_true(player.stats.is_nauseous(), "ısırık zehirli olmalı")
	assert_eq(snake.state, AnimalBase.State.RETREAT)


func test_birds_take_off_when_approached() -> void:
	var flock := BirdFlock.new()
	flock.position = player.global_position + Vector3(5, 0, 0)
	world.animals.add_child(flock)
	await wait_process_frames(2)
	assert_eq(flock.mode, BirdFlock.Mode.FLYING)
	flock.queue_free()


func test_snake_rests_on_sloped_ground() -> void:
	# En eğimli noktalardan birini bul ve yılanı oraya koy.
	var best := Vector3.ZERO
	var best_slope := 0.0
	for i in 400:
		var x := randf_range(-150, 150)
		var z := randf_range(-150, 150)
		var s: float = world.gen.slope_at(x, z)
		if s > best_slope and s < 0.4 and world.gen.is_land(x, z, 1.0):
			best_slope = s
			best = Vector3(x, world.gen.height_at(x, z) + 0.1, z)
	var snake: Snake = world.animals.spawn_animal("snake", best)
	player.global_position = best + Vector3(40, 0, 0)
	await wait_physics_frames(10)
	for seg in snake._segments:
		var p: Vector3 = seg.global_position
		assert_almost_eq(p.y, world.gen.height_at(p.x, p.z), 0.15, "yılan halkası zemine değmeli")
	snake.queue_free()


func test_predators_vocalise_when_close() -> void:
	var wolf := _spawn("wolf", Vector3(8, 0, 0)) as Wolf
	var bear := _spawn("bear", Vector3(-10, 0, 0)) as Bear
	var snake := _spawn("snake", Vector3(0, 0, 3)) as Snake
	await wait_physics_frames(1)
	wolf.think(0.1, player, 8.0)
	assert_gt(wolf._vocal_cd, 0.0, "kurt fark edince hırlamalı")
	bear.think(0.1, player, 10.0)
	assert_gt(bear._vocal_cd, 0.0, "ayı fark edince kükremeli")
	snake.think(0.1, player, 3.0)
	assert_gt(snake._vocal_cd, 0.0, "yılan yaklaşınca tıslamalı")
	snake._vocal_cd = 0.0
	snake.think(0.1, player, 3.0)
	assert_gt(snake._vocal_cd, 0.0, "yılan uyarı boyunca tıslamaya devam etmeli")
