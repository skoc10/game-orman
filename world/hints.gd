class_name Hints
extends Node
## Yeni oyuncu için bağlama göre bir kez gösterilen ipuçları: ilk toplama,
## alet yapma, susama, acıkma, hava kararması, kurtlar. Gösterilenler kayda yazılır.

## [kimlik, metin] — sırayla değil, koşulu sağlanan ilk gösterilmemiş ipucu çıkar.
const TEXTS := {
	"start": "Hayatta kal! Yerden dal, taş ve uzun otlardan lif topla (E). Kamptaki eşyalara da bak.",
	"craft": "Tab ile envanteri aç: liflerden ip, sonra taş balta yap.",
	"axe": "Baltayı hızlı erişimden seç (1–5) ve ağaca sol tıkla vur. Düşen kütükleri topla.",
	"thirst": "Susadın. Göl ya da dereye bakıp E'yi basılı tut. Deniz suyu tuzludur.",
	"hunger": "Acıktın. Böğürtlen ve mantar topla ya da geyik avla. Kırmızı mantarlar zehirlidir.",
	"dusk": "Hava kararıyor! Gece soğuk ve karanlık: kamp ateşi kur (B) ya da meşale yap.",
	"meat": "Çiğ eti kamp ateşinde pişir; çiğ yemek mideni bozabilir.",
	"canteen": "Matarayı elinde tutup suya bakarak doldur. Metal kapla suyu ateşte kaynatırsan güvenli olur.",
	"wolves": "Kurtlar! Ateşin yanında kal ya da meşaleyi elinde tut. Yalnız kalırsan mızrakla savun.",
	"shelter": "Barınak kurarsan geceyi uyuyarak geçirebilir ve oyunu kaydedebilirsin.",
	"bear": "Ayı! Ondan koşarak kaçamazsın. Ayağa kalkıp kükrerse yavaşça uzaklaş; ateşe yaklaşmaz.",
	"snake": "Yılan! Tıslıyorsa geri çekil; ısırığı zehirlidir.",
	"cave": "Mağara ağzı! İçerisi zifiri karanlık; girmeden önce meşale yap. Bazı mağaralarda ayı uyur.",
	"fish": "Suda balıklar var! Mızrakla vurabilir ya da 2 dal ve 1 ipten olta yapabilirsin.",
}

var shown := {}
var _timer := 3.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	var world := GameState.world
	if world == null or world.player.stats.dead:
		return
	var id := _next(world.player)
	if id != "":
		shown[id] = true
		Events.hint.emit(tr(TEXTS[id]))
		_timer = 12.0


func _next(p: Player) -> String:
	var inv := p.inventory
	var s := p.stats
	var conditions := {
		"start": true,
		"craft": inv.has("fiber", 3) and inv.has("stone") and inv.has("stick", 2) and not inv.has("axe"),
		"axe": inv.has("axe"),
		"thirst": s.thirst < 60.0,
		"hunger": s.hunger < 60.0,
		"dusk": TimeOfDay.hour >= 17.5 or TimeOfDay.is_night(),
		"meat": inv.has("meat_raw"),
		"canteen": inv.has("canteen"),
		"wolves": _wolf_near(p),
		"shelter": inv.has("log", 4),
		"bear": _near(p, "bear", 35.0),
		"snake": _near(p, "snake", 8.0),
		"fish": _fish_near(p),
		"cave": _near_mouth(p),
	}
	for id in ["start", "bear", "snake", "dusk", "wolves", "thirst", "hunger", "craft", "axe", "meat", "canteen", "cave", "fish", "shelter"]:
		if not shown.has(id) and conditions[id]:
			return id
	return ""


func _near(p: Player, group: String, radius: float) -> bool:
	for a in get_tree().get_nodes_in_group(group):
		if a.is_alive() and a.global_position.distance_to(p.global_position) < radius:
			return true
	return false


func _near_mouth(p: Player) -> bool:
	for m in get_tree().get_nodes_in_group("cave_mouth"):
		if m.outside and m.global_position.distance_to(p.global_position) < 14.0:
			return true
	return false


func _fish_near(p: Player) -> bool:
	for s in get_tree().get_nodes_in_group("fish_school"):
		if s.global_position.distance_to(p.global_position) < 15.0:
			return true
	return false


func _wolf_near(p: Player) -> bool:
	for w in get_tree().get_nodes_in_group("wolf"):
		if w.is_alive() and w.global_position.distance_to(p.global_position) < 40.0:
			return true
	return false


func save_state() -> Array:
	return shown.keys()


func load_state(ids: Array) -> void:
	for id in ids:
		shown[str(id)] = true
