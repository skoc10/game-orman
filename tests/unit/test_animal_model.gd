extends GutTest


func _fake_model() -> Node3D:
	var root := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 2, 3)
	mesh.mesh = box
	mesh.position.y = 1.0
	root.add_child(mesh)
	var player := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	for n in ["AnimalArmature|Idle", "AnimalArmature|Walk", "AnimalArmature|Gallop", "AnimalArmature|Attack_Headbutt", "AnimalArmature|Death", "AnimalArmature|Eating"]:
		lib.add_animation(n.replace("|", "_"), Animation.new())
	player.add_animation_library("", lib)
	root.add_child(player)
	return root


func test_missing_files_fall_back_to_placeholder() -> void:
	assert_null(AnimalModel.try_load(["YokBoyleDosya.gltf"], 1.0))


func test_maps_animations_by_keyword() -> void:
	var m := AnimalModel.from_instance(_fake_model(), 1.0)
	assert_eq(m.anims.run, "AnimalArmature_Gallop")
	assert_eq(m.anims.idle, "AnimalArmature_Idle")
	assert_eq(m.anims.attack, "AnimalArmature_Attack_Headbutt")
	assert_eq(m.anims.death, "AnimalArmature_Death")
	assert_eq(m.anims.eat, "AnimalArmature_Eating")
	assert_eq(m.player.get_animation(m.anims.walk).loop_mode, Animation.LOOP_LINEAR)
	assert_eq(m.player.get_animation(m.anims.death).loop_mode, Animation.LOOP_NONE)
	m.root.free()


func test_scales_to_height_and_sits_on_ground() -> void:
	var m := AnimalModel.from_instance(_fake_model(), 1.0)
	var inst := m.root.get_child(0) as Node3D
	assert_almost_eq(inst.scale.y, 0.5, 0.001, "2 m'lik model 1 m'ye ölçeklenmeli")
	assert_almost_eq(inst.position.y, 0.0, 0.001, "taban zemine oturmalı")
	m.root.free()


func test_animals_use_placeholder_without_files() -> void:
	var wolf := Wolf.new()
	add_child_autofree(wolf)
	assert_null(wolf.ext)
	assert_not_null(wolf.model)
