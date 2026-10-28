class_name ItemData
extends Resource
## Bir eşyanın tüm özellikleri. Her eşya data/items/ altında bir .tres dosyasıdır;
## yeni eşya eklemek için kod değiştirmeye gerek yok.

enum Category { RESOURCE, FOOD, DRINK, TOOL, WEAPON, LIGHT, MEDICAL, CLOTHING, CONTAINER }

@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
@export var category: Category = Category.RESOURCE
@export var max_stack := 10
## Yer tutucu ikon ve model rengi.
@export var color := Color(0.6, 0.6, 0.6)
## İkon üzerinde görünen kısa yazı.
@export var abbr := ""

@export_group("Tüketim")
@export var hunger := 0.0
@export var thirst := 0.0
@export var health := 0.0
@export_range(0.0, 1.0) var nausea_chance := 0.0
@export var nausea_duration := 0.0

@export_group("Alet ve silah")
@export var damage := 0.0
## Ağaç kesme gücü. 0 ise bu eşyayla ağaç kesilemez.
@export var chop_power := 0.0
@export var reach := 2.0
## 0 ise kırılmaz. Meşale için yanma süresi (saniye).
@export var durability := 0.0
@export var swing_time := 0.5
## 0'dan büyükse sağ tıkla fırlatılabilir.
@export var throw_damage := 0.0
## Hayvan kesip et alınabilir mi?
@export var can_butcher := false

@export_group("Pişirme")
@export var cooks_into := ""
@export var burns_into := ""
@export var boils_into := ""

@export_group("Diğer")
## Ateşe atılınca eklenen yakıt süresi (saniye).
@export var fuel := 0.0
## Isı kaybı çarpanı. Envanterdeki en iyi giysi geçerlidir.
@export var cold_resist := 1.0
## Yenince mide bulantısını ve zehri geçirir.
@export var cures_nausea := false


func is_consumable() -> bool:
	return category in [Category.FOOD, Category.DRINK, Category.MEDICAL]


func has_durability() -> bool:
	return durability > 0.0
