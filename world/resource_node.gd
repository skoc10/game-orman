class_name ResourceNode
extends StaticBody3D
## Toplanabilir doğal kaynak: çalı, uzun ot, yerdeki dal ve taş, mantar.
## Toplanınca birkaç gün sonra yeniden çıkar (ResourceSpawner yönetir).

signal harvested(node: ResourceNode)

const KINDS := {
	"bush": {"verb": "Böğürtlen topla", "yields": {"berries": 4}, "regrow": 2, "hide": false},
	"fiber_plant": {"verb": "Lif topla", "yields": {"fiber": 3}, "regrow": 1, "hide": true},
	"stick": {"verb": "Dal al", "yields": {"stick": 2}, "regrow": 1, "hide": true},
	"stone": {"verb": "Taş al", "yields": {"stone": 2}, "regrow": 2, "hide": true},
	"mushroom": {"verb": "Mantar topla", "yields": {"mushroom": 1}, "regrow": 2, "hide": true},
	"mushroom_red": {"verb": "Kırmızı mantar topla", "yields": {"mushroom_red": 1}, "regrow": 2, "hide": true},
}
const VIEW_DISTANCE := 70.0

var node_id := 0
var kind := "stick"
var available := true

var _visual: MeshInstance3D
var _berries: MeshInstance3D
var _shape: CollisionShape3D


func setup(p_id: int, p_kind: String, xform: Transform3D) -> void:
	node_id = p_id
	kind = p_kind
	transform = xform
	collision_layer = 4
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.75 if kind == "bush" else 0.5
	_shape.shape = sphere
	_shape.position.y = 0.45 if kind == "bush" else 0.2
	add_child(_shape)

	_visual = MeshInstance3D.new()
	_visual.visibility_range_end = VIEW_DISTANCE
	match kind:
		"bush":
			_visual.mesh = MeshFactory.bush()
			_berries = MeshInstance3D.new()
			_berries.mesh = MeshFactory.bush_berries()
			_berries.visibility_range_end = VIEW_DISTANCE * 0.6
			_berries.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_berries)
		"fiber_plant":
			_visual.mesh = MeshFactory.fiber_plant()
		"stick", "stone":
			_visual.mesh = MeshFactory.item_mesh(kind)
			_visual.rotation = Vector3(0, 0, PI * 0.5) if kind == "stick" else Vector3.ZERO
			_visual.position.y = 0.03
			_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_:
			_visual.mesh = MeshFactory.item_mesh(kind)
			_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual)


func get_interaction(player: Player, _shape_idx: int) -> Dictionary:
	if not available:
		return {"text": tr("Henüz yeniden yetişmedi")} if kind == "bush" else {}
	return {"text": tr(KINDS[kind].verb), "action": _harvest.bind(player), "auto": true}


func set_available(v: bool) -> void:
	available = v
	var hide: bool = KINDS[kind].hide
	if hide:
		visible = v
		_shape.disabled = not v
	if _berries:
		_berries.visible = v


func regrow_days() -> int:
	return int(KINDS[kind].regrow)


func _harvest(player: Player) -> void:
	if not available:
		return
	var yields: Dictionary = KINDS[kind].yields
	var got_any := false
	for id in yields:
		var count := int(yields[id])
		if player.give(id, count) < count:
			got_any = true
	if got_any:
		set_available(false)
		harvested.emit(self)
