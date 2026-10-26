extends Node
## Oturum durumu: kayıt/yükleme, ayarlar, rekor ve sahneler arası geçiş.

const SAVE_PATH := "user://saves/slot1.json"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_VERSION := 1
const WORLD_SCENE := "res://world/world.tscn"
const MENU_SCENE := "res://ui/main_menu.tscn"

## Kayıt dosyası yolu; testler kendi yolunu kullanır.
var save_path := SAVE_PATH
## Aktif dünya sahnesi (world.gd). Menüdeyken null.
var world: Node = null
## Ana menüden "Devam" seçilince dünyaya aktarılan kayıt verisi.
var pending_load: Dictionary = {}
## Yeni oyunda kullanılacak dünya tohumu. 0 ise rastgele seçilir.
var new_game_seed := 0
var best_days := 0
var settings := {
	"mouse_sensitivity": 0.25,
	"fov": 75.0,
	"master_volume": 0.8,
	"fullscreen": false,
	## "auto", "high" ya da "low". Otomatikte web ve dokunmatik cihazlarda düşük.
	"quality": "auto",
	## "auto", "on" ya da "off". Otomatikte dokunmatik ekranda açılır.
	"touch_controls": "auto",
}


## Dokunmatik cihazlarda arayüzün tasarlandığı temel boyut. Masaüstündeki
## 1600x900'e göre her şey 1,5 kat büyük görünür.
const TOUCH_UI_SIZE := Vector2i(1067, 600)
const DESKTOP_UI_SIZE := Vector2i(1600, 900)


func _ready() -> void:
	load_settings()
	# DebugCapture argümanları (--touch) okunabilsin diye ertelenir.
	apply_ui_scale.call_deferred()


## Sahne açılırken çağrılır: dokunmatik ayarı değiştiyse yeni sahnede geçerli olur.
func apply_ui_scale() -> void:
	var size := TOUCH_UI_SIZE if touch_controls_enabled() else DESKTOP_UI_SIZE
	if get_window().content_scale_size != size:
		get_window().content_scale_size = size
	UITheme.reset()


func has_save(path := "") -> bool:
	return FileAccess.file_exists(_path(path))


func write_save(data: Dictionary, path := "") -> bool:
	path = _path(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Kayıt yazılamadı: %s" % path)
		return false
	data["version"] = SAVE_VERSION
	file.store_string(JSON.stringify(data, "\t"))
	return true


func read_save(path := "") -> Dictionary:
	path = _path(path)
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
		return json.data
	push_error("Kayıt dosyası bozuk: %s" % path)
	return {}


func delete_save(path := "") -> void:
	path = _path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Aktif dünyanın durumunu toplayıp kaydeder.
func save_game() -> bool:
	if world == null or not world.has_method("collect_save"):
		return false
	var ok := write_save(world.collect_save())
	if ok:
		Events.game_saved.emit()
	return ok


func start_new_game(seed_value: int = 0) -> void:
	pending_load = {}
	new_game_seed = seed_value if seed_value != 0 else randi_range(1, 2_000_000_000)
	_change_scene(WORLD_SCENE)


func continue_game() -> void:
	pending_load = read_save()
	_change_scene(WORLD_SCENE)


func go_to_menu() -> void:
	_change_scene(MENU_SCENE)


func record_days(days: int) -> void:
	if days > best_days:
		best_days = days
		save_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for key in settings.keys():
			settings[key] = cfg.get_value("settings", key, settings[key])
		best_days = int(cfg.get_value("stats", "best_days", 0))
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in settings.keys():
		cfg.set_value("settings", key, settings[key])
	cfg.set_value("stats", "best_days", best_days)
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(settings.master_volume), 0.0001)))
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)
	if world and world.player:
		world.player.camera.fov = float(settings.fov)


## Web ve mobilde (ya da ayarda seçiliyse) hafif grafik: kısa görüş, seyrek
## çimen, az gölge. Dünya kurulurken bir kez okunur.
func low_quality() -> bool:
	var q := str(settings.get("quality", "auto"))
	if q == "low":
		return true
	if q == "high":
		return false
	var debug := get_node_or_null("/root/DebugCapture")
	if debug and debug.args.has("lowq"):
		return true
	return OS.has_feature("web") or OS.has_feature("mobile") or is_touch_device()


func is_touch_device() -> bool:
	return DisplayServer.is_touchscreen_available() and DisplayServer.get_name() != "headless"


## Fareyi oyun için yakalar; dokunmatik modda imleç serbest kalır.
func capture_mouse() -> void:
	if world and world.player and world.player.touch_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Ekran düğmeleri gösterilsin mi?
func touch_controls_enabled() -> bool:
	var t := str(settings.get("touch_controls", "auto"))
	var debug := get_node_or_null("/root/DebugCapture")
	if t == "on" or (debug and debug.args.has("touch")):
		return true
	if t == "off":
		return false
	return is_touch_device()


func _path(path: String) -> String:
	return path if path != "" else save_path


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)


# --- Kayıt dosyası yardımcıları: JSON'da Vector3 dizi olarak tutulur. ---

static func vec3_to_arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func arr_to_vec3(a: Variant, fallback := Vector3.ZERO) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback
