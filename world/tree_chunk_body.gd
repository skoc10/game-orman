extends StaticBody3D
## Bir arazi parçasındaki tüm ağaçların çarpışma gövdesi. Işın bir ağaca
## çarptığında şekil indeksinden ağaç kimliği bulunur ve TreeField'a iletilir.

var field: TreeField


func tree_id_for_shape(shape_idx: int) -> int:
	var owner_id := shape_find_owner(shape_idx)
	var node := shape_owner_get_owner(owner_id) as Node
	return int(node.get_meta("tree_id", -1)) if node else -1


func get_interaction(player: Player, shape_idx: int) -> Dictionary:
	return field.interaction_for(tree_id_for_shape(shape_idx), player)


func take_tree_hit(shape_idx: int, power: float, player: Player) -> void:
	field.hit(tree_id_for_shape(shape_idx), power, player.global_position)
