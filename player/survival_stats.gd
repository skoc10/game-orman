class_name SurvivalStats
extends RefCounted
## Oyuncunun hayatta kalma değerleri ve zamanla değişimi. Sahneden bağımsızdır;
## oranlar BalanceData'dan gelir. Tüm değerler 0–100 arasıdır.

signal damaged(amount: float, cause: String)
signal died(cause: String)

const MAX := 100.0
## Dayanıklılık sıfırlanınca koşmak için bu değere kadar dolması beklenir.
const EXHAUST_RECOVER := 25.0

var health := MAX
## Tokluk: 100 tok, 0 aç.
var hunger := MAX
## Su: 100 kana kana, 0 susuz.
var thirst := MAX
var stamina := MAX
var warmth := MAX
## Kalan mide bulantısı süresi (saniye).
var nausea_time := 0.0
var exhausted := false
var dead := false
var death_cause := ""

var _b: BalanceData


func _init(balance: BalanceData = null) -> void:
	_b = balance if balance else BalanceData.new()


## Bir kare ilerletir. env anahtarları:
## sprinting, swimming (bool), warmth_target (float), cold_resist (çarpan).
func tick(delta: float, env: Dictionary = {}) -> void:
	if dead:
		return
	var sprinting: bool = env.get("sprinting", false)
	var swimming: bool = env.get("swimming", false)
	var nauseous := nausea_time > 0.0

	var drain := _b.exertion_drain_mult if (sprinting or swimming) else 1.0
	if nauseous:
		drain *= _b.nausea_drain_mult
		nausea_time = maxf(0.0, nausea_time - delta)
	hunger = maxf(0.0, hunger - _b.hunger_per_sec * drain * delta)
	thirst = maxf(0.0, thirst - _b.thirst_per_sec * drain * delta)

	var target: float = env.get("warmth_target", _b.day_warmth)
	if target < warmth:
		warmth = move_toward(warmth, target, _b.warmth_loss_per_sec * float(env.get("cold_resist", 1.0)) * delta)
	else:
		warmth = move_toward(warmth, target, _b.warmth_gain_per_sec * delta)

	if sprinting:
		stamina = maxf(0.0, stamina - _b.sprint_stamina_per_sec * delta)
	elif swimming:
		stamina = maxf(0.0, stamina - _b.swim_stamina_per_sec * delta)
	else:
		var regen := _b.stamina_regen
		if hunger < 25.0 or thirst < 25.0:
			regen *= _b.tired_regen_mult
		if nauseous:
			regen *= 0.5
		stamina = minf(MAX, stamina + regen * delta)
	if stamina <= 0.0:
		exhausted = true
	elif stamina >= EXHAUST_RECOVER:
		exhausted = false

	var dps := 0.0
	var cause := ""
	if nauseous:
		dps += _b.nausea_damage
		cause = "zehirlenme"
	if warmth <= 0.0:
		dps += _b.freeze_damage
		cause = "soğuk"
	if hunger <= 0.0:
		dps += _b.starve_damage
		cause = "açlık"
	if thirst <= 0.0:
		dps += _b.dehydrate_damage
		cause = "susuzluk"
	if swimming and stamina <= 0.0:
		dps += _b.drown_damage
		cause = "boğulma"
	if dps > 0.0:
		damage(dps * delta, cause)
	elif hunger > _b.regen_threshold and thirst > _b.regen_threshold and warmth > 30.0:
		health = minf(MAX, health + _b.health_regen * delta)


func damage(amount: float, cause: String) -> void:
	if dead or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	damaged.emit(amount, cause)
	if health <= 0.0:
		dead = true
		death_cause = cause
		died.emit(cause)


func heal(amount: float) -> void:
	if not dead:
		health = clampf(health + amount, 0.0, MAX)


func can_sprint() -> bool:
	return not exhausted and stamina > 0.0


## Yeterli dayanıklılık varsa harcar ve true döner.
func use_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	return true


## Yiyecek, içecek ya da ilacın etkisini uygular. Mide bulantısı tutarsa
## true döner.
func consume(item: ItemData, rng: RandomNumberGenerator) -> bool:
	hunger = clampf(hunger + item.hunger, 0.0, MAX)
	thirst = clampf(thirst + item.thirst, 0.0, MAX)
	if item.cures_nausea:
		nausea_time = 0.0
	if item.health > 0.0:
		heal(item.health)
	elif item.health < 0.0:
		damage(-item.health, "zehirlenme")
	return roll_nausea(item.nausea_chance, item.nausea_duration, rng)


func drink(amount: float, nausea_chance: float, nausea_duration: float, rng: RandomNumberGenerator) -> bool:
	thirst = clampf(thirst + amount, 0.0, MAX)
	return roll_nausea(nausea_chance, nausea_duration, rng)


func roll_nausea(chance: float, duration: float, rng: RandomNumberGenerator) -> bool:
	if chance > 0.0 and rng.randf() < chance:
		nausea_time = maxf(nausea_time, duration)
		return true
	return false


func is_nauseous() -> bool:
	return nausea_time > 0.0


func to_dict() -> Dictionary:
	return {
		"health": health, "hunger": hunger, "thirst": thirst,
		"stamina": stamina, "warmth": warmth, "nausea": nausea_time,
	}


func from_dict(d: Dictionary) -> void:
	health = float(d.get("health", MAX))
	hunger = float(d.get("hunger", MAX))
	thirst = float(d.get("thirst", MAX))
	stamina = float(d.get("stamina", MAX))
	warmth = float(d.get("warmth", MAX))
	nausea_time = float(d.get("nausea", 0.0))
	dead = false
	exhausted = false
