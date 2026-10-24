class_name SpearProjectile
extends Node3D
## Fırlatılan mızrak: balistik uçar, her adımda ışınla çarpma kontrol eder.
## Hayvana çarparsa hasar verir; sonunda yere düşüp alınabilir eşyaya dönüşür.

const GRAVITY := 9.8
const LIFETIME := 6.0
const HIT_MASK := 1 | 8

var velocity := Vector3.ZERO
var damage := 0.0
var durability := -1.0
var thrower: Node3D

var _age := 0.0


func _ready() -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.item_mesh("spear")
	# Model +Y boyunca uzanır; uçuş yönüne (-Z) çevrilir.
	mi.rotation.x = -PI * 0.5
	mi.position.z = 0.8
	add_child(mi)
	_orient()


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	if thrower is CollisionObject3D:
		query.exclude = [(thrower as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var col: Object = hit.collider
		if col.has_method("take_hit"):
			col.take_hit(damage, thrower)
		_land(hit.position)
		return
	global_position = to
	_orient()
	var gen: WorldGen = GameState.world.gen if GameState.world else null
	if _age > LIFETIME or (gen and global_position.y < gen.height_at(global_position.x, global_position.z)):
		_land(global_position)


func _orient() -> void:
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP)


func _land(pos: Vector3) -> void:
	var world := GameState.world
	if world:
		var gen: WorldGen = world.gen
		var ground := Vector3(pos.x, maxf(gen.height_at(pos.x, pos.z), WorldGen.WATER_LEVEL - 2.0), pos.z)
		if durability > 1.0:
			world.spawn_pickup("spear", 1, ground, durability - 1.0, randf() * TAU)
	queue_free()
