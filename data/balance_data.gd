class_name BalanceData
extends Resource
## Oyunun tüm denge sayıları. Varsayılanlar burada, ayarlamalar data/balance.tres
## içinde yapılır. Süreler gerçek saniye cinsindendir.

@export_group("Zaman")
## 06:00–20:00 arası gündüzün gerçek süresi.
@export var day_length_sec := 960.0
## 20:00–06:00 arası gecenin gerçek süresi.
@export var night_length_sec := 480.0
@export var start_hour := 8.0

@export_group("Açlık ve susuzluk")
## Tokluk 100'den 0'a yaklaşık 45 dakikada iner.
@export var hunger_per_sec := 0.037
## Su 100'den 0'a yaklaşık 26 dakikada iner.
@export var thirst_per_sec := 0.064
## Koşarken ve yüzerken açlık/susuzluk çarpanı.
@export var exertion_drain_mult := 1.6
@export var starve_damage := 0.5
@export var dehydrate_damage := 0.8

@export_group("Can")
@export var health_regen := 0.3
## Tokluk ve su bu değerin üstündeyken can yavaşça dolar.
@export var regen_threshold := 40.0
## Bu düşüş hızının (m/s) üstünde hasar alınır.
@export var fall_damage_speed := 11.0
@export var fall_damage_per_speed := 8.0

@export_group("Dayanıklılık")
@export var sprint_stamina_per_sec := 14.0
@export var swim_stamina_per_sec := 4.0
@export var jump_stamina := 10.0
@export var swing_stamina := 8.0
@export var stamina_regen := 18.0
## Aç ya da susuzken dayanıklılık dolma çarpanı.
@export var tired_regen_mult := 0.4

@export_group("Isı")
@export var warmth_loss_per_sec := 0.35
@export var warmth_gain_per_sec := 3.0
@export var freeze_damage := 0.5
@export var day_warmth := 80.0
@export var night_warmth := 5.0
@export var fire_warmth := 100.0
@export var shelter_warmth := 60.0
@export var torch_warmth := 35.0
@export var water_warmth := 10.0
@export var fire_warm_radius := 6.0

@export_group("Mide bulantısı")
@export var nausea_drain_mult := 2.0
@export var nausea_damage := 0.15

@export_group("Hareket")
@export var walk_speed := 4.0
@export var sprint_speed := 7.0
@export var crouch_speed := 2.0
@export var swim_speed := 2.5
@export var jump_velocity := 5.0
@export var unarmed_damage := 4.0

@export_group("Ateş ve pişirme")
@export var fire_start_fuel := 120.0
@export var fire_max_fuel := 600.0
@export var cook_time := 25.0
## Pişmeye konulduktan bu kadar saniye sonra yanar.
@export var burn_time := 55.0
@export var boil_time := 20.0
## Bir mataranın taşıdığı yudum sayısı.
@export var canteen_capacity := 3

@export_group("Uyku")
@export var sleep_from_hour := 18.0
@export var sleep_hunger_cost := 15.0
@export var sleep_thirst_cost := 20.0
@export var sleep_heal := 30.0
@export var sleep_danger_radius := 25.0

@export_group("Hayvanlar")
@export var deer_herds := 6
@export var day_wolf_packs := 1
@export var night_wolf_packs := 2
@export var max_wolves := 7
@export var wolf_bite_damage := 12.0
@export var fire_fear_radius := 10.0
@export var torch_fear_radius := 6.0
