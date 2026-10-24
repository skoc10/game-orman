extends GutTest

var b: BalanceData
var s: SurvivalStats
var rng: RandomNumberGenerator


func before_each() -> void:
	b = BalanceData.new()
	s = SurvivalStats.new(b)
	rng = RandomNumberGenerator.new()
	rng.seed = 1


func test_hunger_and_thirst_drain_over_time() -> void:
	s.tick(100.0, {"warmth_target": 80.0})
	assert_almost_eq(s.hunger, 100.0 - b.hunger_per_sec * 100.0, 0.01)
	assert_almost_eq(s.thirst, 100.0 - b.thirst_per_sec * 100.0, 0.01)
	assert_lt(s.thirst, s.hunger, "susuzluk açlıktan hızlı düşmeli")


func test_sprinting_drains_faster_and_uses_stamina() -> void:
	var walker := SurvivalStats.new(b)
	walker.tick(10.0, {})
	s.tick(10.0, {"sprinting": true})
	assert_lt(s.hunger, walker.hunger)
	assert_lt(s.stamina, 100.0)


func test_starving_damages_health_and_kills() -> void:
	watch_signals(s)
	s.hunger = 0.0
	s.tick(1.0, {})
	assert_almost_eq(s.health, 100.0 - b.starve_damage, 0.001)
	for i in 400:
		s.tick(1.0, {})
	assert_true(s.dead)
	assert_eq(s.death_cause, "açlık")
	assert_signal_emitted(s, "died")


func test_thirst_is_reported_as_death_cause_over_hunger() -> void:
	s.hunger = 0.0
	s.thirst = 0.0
	s.health = 0.5
	s.tick(1.0, {})
	assert_true(s.dead)
	assert_eq(s.death_cause, "susuzluk")


func test_health_regenerates_when_fed() -> void:
	s.health = 50.0
	s.tick(10.0, {})
	assert_gt(s.health, 50.0)


func test_no_regen_while_starving_or_cold() -> void:
	s.health = 50.0
	s.warmth = 20.0
	s.tick(1.0, {"warmth_target": 20.0})
	assert_eq(s.health, 50.0)


func test_warmth_moves_toward_target() -> void:
	s.tick(10.0, {"warmth_target": 0.0})
	assert_almost_eq(s.warmth, 100.0 - b.warmth_loss_per_sec * 10.0, 0.01)
	s.warmth = 10.0
	s.tick(5.0, {"warmth_target": 100.0})
	assert_almost_eq(s.warmth, 10.0 + b.warmth_gain_per_sec * 5.0, 0.01)


func test_cold_resist_slows_warmth_loss() -> void:
	var bare := SurvivalStats.new(b)
	bare.tick(10.0, {"warmth_target": 0.0})
	s.tick(10.0, {"warmth_target": 0.0, "cold_resist": 0.5})
	assert_gt(s.warmth, bare.warmth)


func test_freezing_damages() -> void:
	s.warmth = 0.0
	s.tick(1.0, {"warmth_target": 0.0})
	assert_lt(s.health, 100.0)


func test_exhaustion_blocks_sprint_until_recovered() -> void:
	s.stamina = 1.0
	s.tick(1.0, {"sprinting": true})
	assert_true(s.exhausted)
	assert_false(s.can_sprint())
	s.tick(0.5, {})
	assert_false(s.can_sprint(), "bir miktar dolana kadar koşulamaz")
	s.tick(5.0, {})
	assert_true(s.can_sprint())


func test_drowning_when_exhausted_in_water() -> void:
	s.stamina = 0.0
	s.tick(1.0, {"swimming": true})
	assert_almost_eq(s.health, 100.0 - b.drown_damage, 0.01)


func test_use_stamina() -> void:
	assert_true(s.use_stamina(30.0))
	assert_eq(s.stamina, 70.0)
	s.stamina = 5.0
	assert_false(s.use_stamina(10.0))
	assert_eq(s.stamina, 5.0)


func test_consume_food_restores_and_can_cause_nausea() -> void:
	var meat := ItemData.new()
	meat.hunger = 10.0
	meat.nausea_chance = 1.0
	meat.nausea_duration = 45.0
	s.hunger = 50.0
	assert_true(s.consume(meat, rng))
	assert_eq(s.hunger, 60.0)
	assert_eq(s.nausea_time, 45.0)


func test_nausea_drains_and_damages_then_wears_off() -> void:
	s.nausea_time = 2.0
	s.tick(1.0, {})
	assert_lt(s.health, 100.0)
	assert_almost_eq(s.hunger, 100.0 - b.hunger_per_sec * b.nausea_drain_mult, 0.001)
	s.tick(1.5, {})
	assert_false(s.is_nauseous())


func test_consume_poison_hurts() -> void:
	var poison := ItemData.new()
	poison.health = -10.0
	s.consume(poison, rng)
	assert_eq(s.health, 90.0)


func test_values_are_clamped() -> void:
	var water := ItemData.new()
	water.thirst = 50.0
	s.consume(water, rng)
	assert_eq(s.thirst, 100.0)


func test_save_roundtrip() -> void:
	s.health = 42.0
	s.hunger = 33.0
	s.nausea_time = 7.0
	var other := SurvivalStats.new(b)
	other.from_dict(s.to_dict())
	assert_eq(other.health, 42.0)
	assert_eq(other.hunger, 33.0)
	assert_eq(other.nausea_time, 7.0)
