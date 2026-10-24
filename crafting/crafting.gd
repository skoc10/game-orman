class_name Crafting
extends RefCounted
## Tarif kontrolü ve üretim. Envanterde yer yoksa üretim geri alınır.


## Eksik malzemeler: eşya id -> eksik adet. Boşsa malzemeler tamam.
static func missing(inv: Inventory, recipe: RecipeData) -> Dictionary:
	var out := {}
	for id in recipe.ingredients:
		var need := int(recipe.ingredients[id])
		var have := inv.count_of(id)
		if have < need:
			out[id] = need - have
	return out


static func has_ingredients(inv: Inventory, recipe: RecipeData) -> bool:
	return missing(inv, recipe).is_empty()


## Eşya tarifini üretir. Malzeme eksikse ya da sonuç sığmıyorsa false döner
## ve envanter değişmez.
static func craft(inv: Inventory, recipe: RecipeData) -> bool:
	if recipe.is_build or not has_ingredients(inv, recipe):
		return false
	var snapshot := inv.to_array()
	inv.remove_all(recipe.ingredients)
	if inv.add(recipe.result_id, recipe.result_count) > 0:
		inv.from_array(snapshot)
		return false
	return true


## Malzemeleri listeler: "Taş 2/2, Dal 1/2".
static func ingredients_text(inv: Inventory, recipe: RecipeData) -> String:
	var parts := PackedStringArray()
	for id in recipe.ingredients:
		parts.append("%s %d/%d" % [ItemDB.display_name(id), mini(inv.count_of(id), int(recipe.ingredients[id])), int(recipe.ingredients[id])])
	return ", ".join(parts)
