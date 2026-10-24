extends GutTest

var gen: WorldGen


func before_all() -> void:
	gen = WorldGen.new(42)


func test_same_seed_produces_same_terrain() -> void:
	var other := WorldGen.new(42)
	assert_eq(other.heights.size(), gen.heights.size())
	for i in [0, 1000, 33000, 66000]:
		assert_eq(other.heights[i], gen.heights[i])
	assert_eq(other.lake_center, gen.lake_center)


func test_different_seed_produces_different_terrain() -> void:
	var other := WorldGen.new(43)
	assert_ne(other.lake_center, gen.lake_center)


func test_height_at_matches_grid_vertices() -> void:
	for ix in [0, 17, 128, 255]:
		for iz in [3, 90, 200]:
			var p := gen.vertex_pos(ix, iz)
			assert_almost_eq(gen.height_at(p.x, p.z), p.y, 0.001)


func test_island_edges_are_sea() -> void:
	assert_true(gen.is_water(250.0, 0.0))
	assert_true(gen.is_water(-250.0, 0.0))
	assert_false(gen.is_fresh_water(250.0, 0.0))


func test_lake_center_is_fresh_water() -> void:
	var c := gen.lake_center
	assert_true(gen.is_water(c.x, c.y))
	assert_true(gen.is_fresh_water(c.x, c.y))


func test_spawn_is_dry_flat_land_near_lake() -> void:
	var s := gen.find_spawn()
	assert_true(gen.is_land(s.x, s.z, 1.0))
	assert_lt(gen.slope_at(s.x, s.z), 0.15)
	assert_lt(Vector2(s.x, s.z).distance_to(gen.lake_center), gen.lake_radius * 3.0)


func test_stream_starts_at_lake_and_reaches_sea() -> void:
	assert_gt(gen.stream.size(), 10)
	var last := gen.stream[gen.stream.size() - 1]
	assert_gt(last.length(), WorldGen.ISLAND_RADIUS)
	var mid := gen.stream[gen.stream.size() / 2]
	assert_true(gen.is_water(mid.x, mid.y), "derenin ortası su altında olmalı")
