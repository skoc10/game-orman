class_name Effects
extends RefCounted
## Küçük, tek seferlik görsel efektler (talaş, kan, kıvılcım).


## Bir noktadan saçılan küçük parçacıklar; bitince kendini siler.
static func burst(parent: Node, pos: Vector3, color: Color, amount := 10, speed := 3.0) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	mesh.material = MeshFactory.flat_material(color)
	p.mesh = mesh
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)
