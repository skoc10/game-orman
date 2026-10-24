extends GutTest

var b: BalanceData
var c: Cooking


func before_each() -> void:
	b = BalanceData.new()
	c = Cooking.new(b)


func test_only_raw_food_can_be_cooked() -> void:
	assert_eq(c.add("stick"), -1)
	assert_eq(c.add("meat_cooked"), -1)
	assert_eq(c.add("meat_raw"), 0)


func test_cooking_progresses_only_while_burning() -> void:
	c.add("meat_raw")
	c.tick(b.cook_time + 1.0, false)
	assert_eq(c.state(0), "cooking")
	c.tick(b.cook_time + 1.0, true)
	assert_eq(c.state(0), "cooked")
	assert_eq(c.result_id(0), "meat_cooked")


func test_food_burns_if_left_too_long() -> void:
	c.add("meat_raw")
	c.tick(b.burn_time + 1.0, true)
	assert_eq(c.state(0), "burnt")
	assert_eq(c.take(0), "meat_burnt")
	assert_eq(c.state(0), "empty")


func test_taking_early_returns_raw() -> void:
	c.add("meat_raw")
	c.tick(1.0, true)
	assert_eq(c.ready_slot(), -1)
	assert_eq(c.take(0), "meat_raw")


func test_slots_fill_up() -> void:
	for i in Cooking.SLOTS:
		assert_eq(c.add("meat_raw"), i)
	assert_eq(c.add("meat_raw"), -1)


func test_boiling_water() -> void:
	assert_eq(c.pot_state(), "none")
	c.place_pot(3)
	assert_eq(c.pot_state(), "boiling")
	c.tick(b.boil_time * 0.5, true)
	assert_eq(c.pot_state(), "boiling")
	c.tick(b.boil_time, true)
	assert_eq(c.pot_state(), "boiled")
	var out := c.take_pot()
	assert_eq(int(out.water), 3)
	assert_true(out.clean)
	assert_eq(c.pot_state(), "none")


func test_pot_taken_early_is_not_clean() -> void:
	c.place_pot(2)
	c.tick(1.0, true)
	assert_false(c.take_pot().clean)


func test_save_roundtrip() -> void:
	c.add("meat_raw")
	c.tick(10.0, true)
	c.place_pot(2)
	var json: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var other := Cooking.new(b)
	other.from_dict(json)
	assert_eq(other.slots[0].id, "meat_raw")
	assert_almost_eq(float(other.slots[0].t), 10.0, 0.001)
	assert_eq(other.pot_water, 2)
	assert_true(other.has_pot)
