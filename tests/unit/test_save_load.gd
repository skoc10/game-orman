extends GutTest

const TEST_PATH := "user://test_saves/test_slot.json"


func after_each() -> void:
	GameState.delete_save(TEST_PATH)


func test_write_then_read_roundtrip() -> void:
	var data := {
		"seed": 12345,
		"time": {"day": 4, "hour": 21.5},
		"player": {"pos": GameState.vec3_to_arr(Vector3(1.5, 2.0, -3.25))},
		"felled_trees": [3, 17, 42],
	}
	assert_true(GameState.write_save(data, TEST_PATH))
	assert_true(GameState.has_save(TEST_PATH))
	var loaded := GameState.read_save(TEST_PATH)
	assert_eq(int(loaded.seed), 12345)
	assert_eq(int(loaded.time.day), 4)
	assert_almost_eq(float(loaded.time.hour), 21.5, 0.0001)
	assert_eq(GameState.arr_to_vec3(loaded.player.pos), Vector3(1.5, 2.0, -3.25))
	assert_eq(loaded.felled_trees.size(), 3)
	assert_eq(int(loaded.version), GameState.SAVE_VERSION)


func test_missing_save_returns_empty() -> void:
	GameState.delete_save(TEST_PATH)
	assert_false(GameState.has_save(TEST_PATH))
	assert_eq(GameState.read_save(TEST_PATH), {})


func test_corrupt_save_returns_empty() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_PATH.get_base_dir())
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{bozuk")
	f.close()
	assert_eq(GameState.read_save(TEST_PATH), {})
	assert_push_error("bozuk")
