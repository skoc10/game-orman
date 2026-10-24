extends GutTest

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new(6)


func test_items_are_loaded() -> void:
	assert_true(ItemDB.has_item("stick"))
	assert_true(ItemDB.has_item("axe"))
	assert_eq(ItemDB.display_name("stick"), "Dal")


func test_add_stacks_up_to_max() -> void:
	var max_stack := ItemDB.get_item("stick").max_stack
	assert_eq(inv.add("stick", max_stack + 5), 0)
	assert_eq(inv.count_of("stick"), max_stack + 5)
	assert_eq(int(inv.get_slot(0).count), max_stack)
	assert_eq(int(inv.get_slot(1).count), 5)


func test_add_fills_existing_stack_first() -> void:
	inv.add("stone", 3)
	inv.add("fiber", 2)
	inv.add("stone", 4)
	assert_eq(int(inv.get_slot(0).count), 7)
	assert_true(inv.get_slot(2).is_empty())


func test_overflow_returns_leftover() -> void:
	var log_max := ItemDB.get_item("log").max_stack
	var leftover := inv.add("log", log_max * 6 + 3)
	assert_eq(leftover, 3)
	assert_eq(inv.space_for("log"), 0)


func test_tools_do_not_stack_and_keep_durability() -> void:
	inv.add("axe", 2)
	assert_eq(int(inv.get_slot(0).count), 1)
	assert_eq(int(inv.get_slot(1).count), 1)
	assert_eq(float(inv.get_slot(0).dur), ItemDB.get_item("axe").durability)


func test_remove_takes_from_last_slots() -> void:
	inv.add("stick", 25)
	assert_true(inv.remove("stick", 3))
	assert_eq(int(inv.get_slot(0).count), ItemDB.get_item("stick").max_stack)
	assert_eq(inv.count_of("stick"), 22)
	assert_false(inv.remove("stick", 100))
	assert_eq(inv.count_of("stick"), 22)


func test_remove_clears_empty_slots() -> void:
	inv.add("stone", 2)
	inv.remove("stone", 2)
	assert_true(inv.get_slot(0).is_empty())


func test_move_swaps_and_merges() -> void:
	inv.add("stone", 3)
	inv.add("fiber", 2)
	inv.move(0, 1)
	assert_eq(inv.get_slot(0).id, "fiber")
	assert_eq(inv.get_slot(1).id, "stone")
	inv.set_slot(3, {"id": "stone", "count": 4, "dur": 0.0})
	inv.move(3, 1)
	assert_eq(int(inv.get_slot(1).count), 7)
	assert_true(inv.get_slot(3).is_empty())


func test_wear_breaks_tool() -> void:
	inv.add("knife")
	var dur := float(inv.get_slot(0).dur)
	assert_false(inv.wear(0, dur - 1.0))
	assert_true(inv.wear(0, 2.0))
	assert_true(inv.get_slot(0).is_empty())


func test_best_cold_resist() -> void:
	assert_eq(inv.best_cold_resist(), 1.0)
	inv.add("hide_clothes")
	assert_eq(inv.best_cold_resist(), ItemDB.get_item("hide_clothes").cold_resist)


func test_save_roundtrip() -> void:
	inv.add("stick", 7)
	inv.add("axe")
	inv.wear(1, 10.0)
	var json: Array = JSON.parse_string(JSON.stringify(inv.to_array()))
	var other := Inventory.new(6)
	other.from_array(json)
	assert_eq(other.count_of("stick"), 7)
	assert_almost_eq(float(other.get_slot(1).dur), ItemDB.get_item("axe").durability - 10.0, 0.001)
