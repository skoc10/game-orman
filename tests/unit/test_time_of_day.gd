extends GutTest

var _saved := {}


func before_each() -> void:
	_saved = TimeOfDay.to_dict()
	TimeOfDay.running = false


func after_each() -> void:
	TimeOfDay.from_dict(_saved)


func test_day_runs_slower_than_night() -> void:
	TimeOfDay.hour = 12.0
	var day_rate := TimeOfDay.hours_per_second()
	TimeOfDay.hour = 23.0
	var night_rate := TimeOfDay.hours_per_second()
	assert_gt(night_rate, day_rate)


func test_full_day_takes_day_plus_night_length() -> void:
	TimeOfDay.day = 1
	TimeOfDay.hour = 6.0
	TimeOfDay.advance(Balance.d.day_length_sec + Balance.d.night_length_sec)
	assert_eq(TimeOfDay.day, 2)
	assert_almost_eq(TimeOfDay.hour, 6.0, 0.01)


func test_advance_crosses_dusk_with_new_rate() -> void:
	TimeOfDay.hour = 19.0
	var secs_to_dusk := 1.0 / ((TimeOfDay.DUSK - TimeOfDay.DAWN) / Balance.d.day_length_sec)
	var night_rate := (24.0 - TimeOfDay.DUSK + TimeOfDay.DAWN) / Balance.d.night_length_sec
	TimeOfDay.advance(secs_to_dusk + 10.0)
	assert_almost_eq(TimeOfDay.hour, 20.0 + 10.0 * night_rate, 0.001)
	assert_true(TimeOfDay.is_night())


func test_skip_to_next_morning_increments_day() -> void:
	TimeOfDay.day = 3
	TimeOfDay.hour = 22.0
	TimeOfDay.skip_to(6.0)
	assert_eq(TimeOfDay.day, 4)
	assert_almost_eq(TimeOfDay.hour, 6.0, 0.001)
	assert_false(TimeOfDay.is_night())


func test_daylight_and_warmth() -> void:
	TimeOfDay.hour = 13.0
	assert_eq(TimeOfDay.daylight(), 1.0)
	assert_eq(TimeOfDay.ambient_warmth(), Balance.d.day_warmth)
	TimeOfDay.hour = 1.0
	assert_eq(TimeOfDay.daylight(), 0.0)
	assert_eq(TimeOfDay.ambient_warmth(), Balance.d.night_warmth)


func test_clock_text() -> void:
	TimeOfDay.hour = 7.5
	assert_eq(TimeOfDay.clock_text(), "07:30")
