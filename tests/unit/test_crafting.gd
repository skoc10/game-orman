extends GutTest

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new(10)


func test_recipes_are_loaded_and_sorted() -> void:
	assert_gt(ItemDB.craft_recipes().size(), 5)
	assert_eq(ItemDB.build_recipes().size(), 3)
	assert_eq(ItemDB.craft_recipes()[0].id, "rope")


func test_every_recipe_uses_known_items() -> void:
	for r in ItemDB.recipes:
		for id in r.ingredients:
			assert_true(ItemDB.has_item(id), "%s tarifinde bilinmeyen eşya: %s" % [r.id, id])
		if not r.is_build:
			assert_true(ItemDB.has_item(r.result_id), "%s sonucu bilinmiyor" % r.id)


func test_missing_lists_shortfall() -> void:
	inv.add("stone", 1)
	var axe := ItemDB.get_recipe("axe")
	var miss := Crafting.missing(inv, axe)
	assert_eq(int(miss.stone), 1)
	assert_eq(int(miss.stick), 2)
	assert_eq(int(miss.rope), 1)


func test_craft_consumes_and_produces() -> void:
	inv.add("fiber", 7)
	assert_true(Crafting.craft(inv, ItemDB.get_recipe("rope")))
	assert_eq(inv.count_of("rope"), 1)
	assert_eq(inv.count_of("fiber"), 4)


func test_craft_fails_without_ingredients() -> void:
	inv.add("stick", 1)
	assert_false(Crafting.craft(inv, ItemDB.get_recipe("knife")))
	assert_eq(inv.count_of("stick"), 1)


func test_craft_rolls_back_when_no_space() -> void:
	# İp için 3 lif harcanır ama 2 lif slotta kalır; balta da diğer slotu tutar.
	var tiny := Inventory.new(2)
	tiny.add("fiber", 5)
	tiny.add("axe")
	assert_false(Crafting.craft(tiny, ItemDB.get_recipe("rope")))
	assert_eq(tiny.count_of("fiber"), 5)
	assert_eq(tiny.count_of("rope"), 0)


func test_build_recipes_are_not_crafted() -> void:
	inv.add("stone", 4)
	inv.add("stick", 4)
	assert_false(Crafting.craft(inv, ItemDB.get_recipe("campfire")))
	assert_eq(inv.count_of("stone"), 4)


func test_build_scenes_exist_and_are_buildables() -> void:
	for r in ItemDB.build_recipes():
		assert_true(ResourceLoader.exists(r.build_scene), "%s sahnesi yok" % r.id)
		var b := (load(r.build_scene) as PackedScene).instantiate()
		assert_true(b is Buildable, "%s Buildable olmalı" % r.id)
		b.free()
