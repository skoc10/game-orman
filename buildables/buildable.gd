class_name Buildable
extends StaticBody3D
## İnşa edilebilir yapıların ortak tabanı: kayıt, yerleştirme boyutu ve
## inşa önizlemesi (yarı saydam, çarpışmasız kopya).

const GHOST_OK := Color(0.4, 1.0, 0.45, 0.45)
const GHOST_BAD := Color(1.0, 0.35, 0.3, 0.45)

@export var recipe_id := ""
## Yerleşim kontrolünde kullanılan taban kutusu (genişlik, yükseklik, derinlik).
@export var footprint := Vector3(1, 1, 1)
## "land": kuru, düz arazi. "water": kıyıya yakın, yeterince derin su (sal).
var placement := "land"

var is_ghost := false


func _ready() -> void:
	if is_ghost:
		return
	add_to_group("persist_dynamic")
	add_to_group("buildable")


func save_state() -> Dictionary:
	var d := {
		"type": "build", "recipe": recipe_id,
		"pos": GameState.vec3_to_arr(global_position), "yaw": rotation.y,
	}
	d.merge(save_extra())
	return d


## Alt sınıfların ek kayıt verisi.
func save_extra() -> Dictionary:
	return {}


func load_extra(_d: Dictionary) -> void:
	pass


## Önizleme moduna geçirir: çarpışma ve işlem kapanır, tüm mesh'ler saydamlaşır.
## add_child'dan önce çağrılmalıdır.
func make_ghost() -> void:
	is_ghost = true
	collision_layer = 0
	collision_mask = 0
	process_mode = Node.PROCESS_MODE_DISABLED


func set_ghost_valid(valid: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = GHOST_OK if valid else GHOST_BAD
	_apply_ghost_material(self, mat)


func _apply_ghost_material(node: Node, mat: Material) -> void:
	for c in node.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).material_override = mat
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if c is Light3D or c is CPUParticles3D:
			c.visible = false
		_apply_ghost_material(c, mat)
