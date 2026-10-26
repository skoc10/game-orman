class_name Fish
extends CharacterBody3D
## Tek balık. Fizikle yürümez; sürünün verdiği yolda süzülür. Çarpışma katmanı
## hayvanlarla aynıdır, böylece mızrak vuruşu ve fırlatma onu bulur.

var school: FishSchool
var phase := 0.0
var lane := 1.0
var color := Color(0.45, 0.55, 0.38)
var dead := false

var _t := 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.12
	capsule.height = 0.45
	shape.shape = capsule
	shape.rotation.x = PI * 0.5
	add_child(shape)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = MeshFactory.fish_mesh(color, 0.35)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_t = randf() * 20.0
	position = school.swim_point(self, _t)


func _physics_process(delta: float) -> void:
	if dead or not visible:
		return
	_t += delta
	var target := school.swim_point(self, _t)
	var prev := position
	position = position.lerp(target, clampf(delta * 2.0, 0.0, 1.0))
	var move := position - prev
	if move.length() > 0.0005:
		rotation.y = lerp_angle(rotation.y, atan2(-move.x, -move.z), clampf(delta * 5.0, 0.0, 1.0))
	_mesh.rotation.y = sin(_t * 9.0 + phase) * 0.18


func take_hit(_damage: float, _attacker: Node3D) -> void:
	if dead:
		return
	dead = true
	school.scatter()
	school.remove_fish(self)
	var world := GameState.world
	if world:
		Effects.burst(world, global_position, Color(0.75, 0.85, 0.9), 8, 2.0)
		var p := global_position
		p.y = WorldGen.WATER_LEVEL + 0.02
		var pickup: Pickup = world.spawn_pickup("fish_raw", 1, p)
		pickup.floating = true
	Sfx.play_at("splash", global_position, -6.0, 25.0, 0.2)
	queue_free()
