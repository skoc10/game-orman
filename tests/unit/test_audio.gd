extends GutTest

const SOUNDS := [
	"footstep_0", "footstep_1", "footstep_2", "footstep_3", "swing", "chop", "hit_flesh",
	"pickup", "eat", "drink", "craft", "ignite", "splash", "tree_fall", "bite",
	"deer_alarm", "wolf_growl", "wolf_howl", "ui_click", "bear_roar", "snake_hiss", "bird_takeoff",
]
const LOOPS := ["fire_loop", "wind_loop", "birds_loop", "crickets_loop"]


func test_all_sounds_exist_and_have_audio() -> void:
	for name in SOUNDS + LOOPS:
		var path: String = Sfx.DIR + name + ".res"
		assert_true(ResourceLoader.exists(path), "%s eksik; tools/gen_sfx.gd çalıştırılmalı" % name)
		var wav := load(path) as AudioStreamWAV
		assert_not_null(wav)
		if wav:
			assert_gt(wav.get_length(), 0.03, "%s çok kısa" % name)


func test_loops_are_set_to_loop() -> void:
	for name in LOOPS:
		var wav := load(Sfx.DIR + name + ".res") as AudioStreamWAV
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s döngü olmalı" % name)
		assert_gt(wav.loop_end, 0)


func test_one_shots_do_not_loop() -> void:
	for name in SOUNDS:
		var wav := load(Sfx.DIR + name + ".res") as AudioStreamWAV
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_DISABLED, "%s döngü olmamalı" % name)
