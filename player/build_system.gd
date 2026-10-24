class_name BuildSystem
extends Node
## İnşa modu: seçilen yapının önizlemesi bakılan yere yerleşir; uygun yerde
## yeşil, değilse kırmızı görünür. Sol tık inşa eder, R döndürür, sağ tık iptal eder.

signal placing_changed(active: bool)

const REACH := 7.0
const MIN_FLATNESS := 0.8
const ROTATE_STEP := PI / 8.0

var player: Player
var recipe: RecipeData
var ghost: Buildable
var valid := false
var reason := ""

var _yaw_offset := 0.0


func is_placing() -> bool:
	return ghost != null


func start(r: RecipeData) -> void:
	cancel()
	recipe = r
	ghost = (load(r.build_scene) as PackedScene).instantiate() as Buildable
	ghost.make_ghost()
	GameState.world.add_child(ghost)
	ghost.set_ghost_valid(false)
	_yaw_offset = 0.0
	placing_changed.emit(true)


func cancel() -> void:
	if ghost:
		ghost.queue_free()
		ghost = null
		recipe = null
		Events.interaction_changed.emit("", -1.0)
		placing_changed.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing() or player.input_locked:
		return
	if event.is_action_pressed("rotate_build"):
		_yaw_offset += ROTATE_STEP
	elif event.is_action_pressed("attack"):
		place()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("alt_action") or event.is_action_pressed("build"):
		cancel()
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not is_placing():
		return
	if player.stats.dead:
		cancel()
		return
	_update_ghost()
	var text := tr("[Sol tık] %s inşa et · [R] döndür · [Sağ tık] iptal") % recipe.display_name
	if not valid:
		text = "%s\n%s" % [reason, tr("[Sağ tık] iptal")]
	Events.interaction_changed.emit(text, -1.0)


func place() -> bool:
	if not is_placing() or not valid:
		if is_placing():
			player.notify(reason)
		return false
	if not player.inventory.remove_all(recipe.ingredients):
		player.notify(tr("Malzemeler yetersiz."))
		return false
	var built := spawn(recipe, ghost.global_transform)
	player.notify(tr("İnşa edildi: %s") % recipe.display_name)
	cancel()
	return built != null


## Yapıyı dünyaya ekler (inşa ve kayıttan yükleme ortak yolu).
static func spawn(r: RecipeData, xform: Transform3D, extra := {}) -> Buildable:
	var b := (load(r.build_scene) as PackedScene).instantiate() as Buildable
	if not extra.is_empty():
		b.load_extra(extra)
	GameState.world.dynamic_root.add_child(b)
	b.global_transform = xform
	return b


func _update_ghost() -> void:
	var cam := player.camera
	var from := cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + player.look_direction() * REACH, 1)
	query.exclude = [player.get_rid()]
	var space := player.get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		var p := from + player.look_direction() * REACH
		var gen: WorldGen = GameState.world.gen
		ghost.global_position = Vector3(p.x, gen.height_at(p.x, p.z), p.z)
		_set_valid(false, tr("Çok uzak."))
		return
	var pos: Vector3 = hit.position
	var face := player.rotation.y + PI + _yaw_offset
	ghost.global_transform = Transform3D(Basis(Vector3.UP, face), pos)
	_set_valid(check_placement(space, hit), reason)


## Yerleşim kuralları: arazi üstünde, düz, kuru, başka bir şeyle çakışmayan yer
## ve yeterli malzeme.
func check_placement(space: PhysicsDirectSpaceState3D, hit: Dictionary) -> bool:
	var collider: Object = hit.collider
	if not (collider is Node and (collider as Node).is_in_group("terrain")):
		reason = tr("Buraya inşa edilemez.")
		return false
	if (hit.normal as Vector3).y < MIN_FLATNESS:
		reason = tr("Zemin çok eğimli.")
		return false
	var gen: WorldGen = GameState.world.gen
	var pos: Vector3 = hit.position
	if gen.height_at(pos.x, pos.z) < WorldGen.WATER_LEVEL + 0.3:
		reason = tr("Suya inşa edilemez.")
		return false
	var box := BoxShape3D.new()
	box.size = ghost.footprint
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = box
	shape_query.transform = Transform3D(ghost.global_transform.basis, pos + Vector3.UP * (ghost.footprint.y * 0.5 + 0.15))
	shape_query.collision_mask = 1 | 2
	var exclude: Array[RID] = []
	for t in player.get_tree().get_nodes_in_group("terrain"):
		exclude.append((t as CollisionObject3D).get_rid())
	shape_query.exclude = exclude
	if not space.intersect_shape(shape_query, 1).is_empty():
		reason = tr("Yer dar: ağaç, kaya ya da başka bir yapı var.")
		return false
	var miss := Crafting.missing(player.inventory, recipe)
	if not miss.is_empty():
		var parts := PackedStringArray()
		for id in miss:
			parts.append("%d %s" % [miss[id], ItemDB.display_name(id)])
		reason = tr("Eksik: %s") % ", ".join(parts)
		return false
	reason = ""
	return true


func _set_valid(v: bool, why: String) -> void:
	reason = why
	if v != valid or ghost.get_meta("shown", -1) != int(v):
		valid = v
		ghost.set_meta("shown", int(v))
		ghost.set_ghost_valid(v)
