class_name RecipeData
extends Resource
## Bir crafting ya da inşa tarifi. data/recipes/ altında .tres olarak durur.

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
## Eşya id -> adet.
@export var ingredients: Dictionary = {}
@export var result_id := ""
@export var result_count := 1
## true ise envantere eşya vermez, inşa modunda yere yerleştirilir.
@export var is_build := false
@export_file("*.tscn") var build_scene := ""
## Listelerdeki sıra.
@export var order := 0
