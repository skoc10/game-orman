extends Node
## Tüm eşya ve tarifleri data/ klasöründen yükler.

const ITEMS_DIR := "res://data/items"
const RECIPES_DIR := "res://data/recipes"

var items: Dictionary = {}  # id -> ItemData
var recipes: Array[RecipeData] = []


func _init() -> void:
	for path in _resource_paths(ITEMS_DIR):
		var item := load(path) as ItemData
		if item == null or item.id.is_empty():
			push_error("Geçersiz eşya dosyası: %s" % path)
			continue
		items[item.id] = item
	for path in _resource_paths(RECIPES_DIR):
		var recipe := load(path) as RecipeData
		if recipe == null or recipe.id.is_empty():
			push_error("Geçersiz tarif dosyası: %s" % path)
			continue
		recipes.append(recipe)
	recipes.sort_custom(func(a: RecipeData, b: RecipeData) -> bool: return a.order < b.order)


func get_item(id: String) -> ItemData:
	return items.get(id) as ItemData


func has_item(id: String) -> bool:
	return items.has(id)


func display_name(id: String) -> String:
	var item := get_item(id)
	return item.display_name if item else id


func get_recipe(id: String) -> RecipeData:
	for r in recipes:
		if r.id == id:
			return r
	return null


func craft_recipes() -> Array[RecipeData]:
	return recipes.filter(func(r: RecipeData) -> bool: return not r.is_build)


func build_recipes() -> Array[RecipeData]:
	return recipes.filter(func(r: RecipeData) -> bool: return r.is_build)


## Dışa aktarılmış oyunda .tres dosyaları .remap uzantısıyla listelenir.
static func _resource_paths(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			out.append(dir.path_join(name))
	out.sort()
	return out
