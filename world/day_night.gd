class_name DayNight
extends Node
## Güneşi, ayı, gökyüzünü, ortam ışığını ve sisi TimeOfDay saatine göre ayarlar.
## Gece bilerek karanlıktır: ateş ya da meşale olmadan uzağı görmek zordur.

const SKY_SHADER := preload("res://world/sky.gdshader")

const DAY_TOP := Color(0.24, 0.47, 0.85)
const DAY_HORIZON := Color(0.68, 0.79, 0.90)
const DUSK_TOP := Color(0.28, 0.30, 0.55)
const DUSK_HORIZON := Color(0.95, 0.52, 0.28)
const NIGHT_TOP := Color(0.008, 0.012, 0.03)
const NIGHT_HORIZON := Color(0.03, 0.045, 0.08)
const DAY_AMBIENT := Color(0.55, 0.62, 0.72)
const NIGHT_AMBIENT := Color(0.11, 0.14, 0.24)

var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ShaderMaterial
## Su malzemesi; gece kararması için world.gd tarafından atanır.
var water_mat: ShaderMaterial
## Sis yoğunluğu çarpanı (ana menü manzarası için düşürülür).
var fog_scale := 1.0


func _ready() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_sky_affect = 0.25
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.light_angular_distance = 0.5
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45.0
	moon.light_color = Color(0.62, 0.72, 1.0)
	add_child(moon)
	update_now()


func _process(_delta: float) -> void:
	update_now()


func update_now() -> void:
	var dl := TimeOfDay.daylight()
	var h := TimeOfDay.hour
	# Şafak ve alacakaranlıkta 1, tam gündüz ve tam gecede 0.
	var dusk := 1.0 - absf(dl * 2.0 - 1.0)

	var day_p := clampf((h - TimeOfDay.DAWN) / (TimeOfDay.DUSK - TimeOfDay.DAWN), 0.0, 1.0)
	var elev := sin(day_p * PI) * 62.0
	sun.rotation_degrees = Vector3(-maxf(elev, 3.0), lerpf(90.0, -90.0, day_p), 0.0)
	sun.light_energy = dl * 1.5
	sun.light_color = Color(1.0, 0.95, 0.86).lerp(Color(1.0, 0.58, 0.32), dusk)
	sun.visible = dl > 0.01

	var night_p := clampf(fposmod(h - TimeOfDay.DUSK, 24.0) / (24.0 - TimeOfDay.DUSK + TimeOfDay.DAWN), 0.0, 1.0)
	var moon_elev := sin(night_p * PI) * 50.0
	moon.rotation_degrees = Vector3(-maxf(moon_elev, 6.0), lerpf(110.0, -70.0, night_p), 0.0)
	moon.light_energy = (1.0 - dl) * 0.14
	moon.visible = dl < 0.99

	var top := NIGHT_TOP.lerp(DAY_TOP, dl).lerp(DUSK_TOP, dusk * 0.6)
	var horizon := NIGHT_HORIZON.lerp(DAY_HORIZON, dl).lerp(DUSK_HORIZON, dusk * 0.75)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", horizon)
	sky_mat.set_shader_parameter("ground_color", horizon * 0.35)
	sky_mat.set_shader_parameter("sun_dir", sun.global_transform.basis.z)
	sky_mat.set_shader_parameter("sun_amount", dl)
	sky_mat.set_shader_parameter("sun_color", sun.light_color)
	sky_mat.set_shader_parameter("moon_dir", moon.global_transform.basis.z)
	sky_mat.set_shader_parameter("moon_amount", 1.0 - dl)
	sky_mat.set_shader_parameter("star_amount", clampf(1.0 - dl * 3.0, 0.0, 1.0))

	env.ambient_light_color = NIGHT_AMBIENT.lerp(DAY_AMBIENT, dl)
	env.ambient_light_energy = lerpf(0.26, 0.6, dl)
	env.fog_light_color = horizon.lerp(top, 0.3)
	env.fog_density = lerpf(0.012, 0.0025, dl) * fog_scale
	if water_mat:
		water_mat.set_shader_parameter("brightness", lerpf(0.22, 1.0, dl))
	var world := GameState.world
	if world and world.player and world.is_underground(world.player.global_position):
		# Mağara içi: güneş ve ay yok, ortam neredeyse karanlık.
		sun.visible = false
		moon.visible = false
		env.ambient_light_color = Color(0.05, 0.05, 0.06)
		env.ambient_light_energy = 0.35
		env.fog_light_color = Color(0.0, 0.0, 0.0)
		env.fog_density = 0.05
