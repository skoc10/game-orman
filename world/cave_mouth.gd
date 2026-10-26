class_name CaveMouth
extends StaticBody3D
## Mağara ağzı: yüzeyde, kayalardan bir kemer ve karanlık bir açıklık. İçeride
## de eşi vardır ("Dışarı çık"). E ile karşı tarafa geçilir (ekran kararır).

var cave: Cave
## Yüzeydeki ağız için true, mağara içindeki çıkış için false.
var outside := true
## Karşı taraftaki nokta ve bakış yönü.
var target := Vector3.ZERO
var target_yaw := 0.0
var label := ""


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group("cave_mouth")
	if outside:
		_build_arch()
	else:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.9
		shape.shape = sphere
		shape.position.y = 1.0
		add_child(shape)
		collision_layer = 4


func get_interaction(player: Player, _shape_idx: int) -> Dictionary:
	var text := label if label != "" else (tr("%s: içeri gir") % cave.display_name() if outside else tr("Dışarı çık"))
	return {"text": text, "action": _travel.bind(player)}


func _travel(player: Player) -> void:
	var world := GameState.world
	if world and world.has_method("travel"):
		world.travel(target, target_yaw)


## Yamaca gömülü kayalar: iki yan sütun, üstte kemer ve karanlık ağız.
func _build_arch() -> void:
	var rock := MeshFactory.flat_material(Color(0.42, 0.4, 0.38), 0.0, 1.0)
	var dark := MeshFactory.flat_material(Color(0.02, 0.02, 0.025), 0.0, 1.0)
	var parts := [
		[MeshFactory.sphere(1.0, 6, 4), MeshFactory.at(Vector3(-1.9, 1.2, 0.4), Vector3.ZERO, Vector3(1.3, 1.9, 1.6)), rock],
		[MeshFactory.sphere(1.0, 6, 4), MeshFactory.at(Vector3(1.9, 1.1, 0.4), Vector3.ZERO, Vector3(1.3, 1.8, 1.5)), rock],
		[MeshFactory.sphere(1.0, 6, 4), MeshFactory.at(Vector3(0, 3.2, 0.6), Vector3.ZERO, Vector3(3.0, 1.2, 1.8)), rock],
		[MeshFactory.sphere(1.0, 6, 4), MeshFactory.at(Vector3(0, 2.0, 2.2), Vector3.ZERO, Vector3(3.2, 2.6, 2.0)), rock],
		[MeshFactory.box(Vector3(2.4, 2.6, 0.2)), MeshFactory.at(Vector3(0, 1.3, 0.9)), dark],
	]
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.combine(parts)
	add_child(mi)
	for spec in [[Vector3(-1.9, 1.2, 0.4), 1.4], [Vector3(1.9, 1.1, 0.4), 1.4], [Vector3(0, 2.0, 2.2), 2.0]]:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = spec[1]
		shape.shape = sphere
		shape.position = spec[0]
		add_child(shape)
	# Etkileşim için açıklığın önünde görünmez bir hedef.
	var door := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.4, 0.6)
	door.shape = box
	door.position = Vector3(0, 1.2, 0.8)
	add_child(door)
