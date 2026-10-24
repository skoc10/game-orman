extends Node
## Oyun saati ve gün sayacı. 06:00–20:00 gündüz, 20:00–06:00 gece.
## Gündüz ve gece farklı hızda akar (Balance.d.day_length_sec / night_length_sec).

signal day_changed(day: int)
signal hour_changed(hour: int)
signal night_started
signal day_started

const DAWN := 6.0
const DUSK := 20.0

var day := 1
var hour := 8.0
## Dünya sahnesi açıkken true olur; menüde saat akmaz.
var running := false
## Hata ayıklama için zaman hızlandırma çarpanı.
var time_scale := 1.0


func _process(delta: float) -> void:
	if running:
		advance(delta * time_scale)


func reset(start_hour: float = Balance.d.start_hour) -> void:
	day = 1
	hour = start_hour


func is_night() -> bool:
	return hour >= DUSK or hour < DAWN


## Bir gerçek saniyede kaç oyun saati geçer.
func hours_per_second() -> float:
	if is_night():
		return (24.0 - DUSK + DAWN) / Balance.d.night_length_sec
	return (DUSK - DAWN) / Balance.d.day_length_sec


## Saati gerçek saniye cinsinden ilerletir. Gündüz/gece sınırını geçerken
## kalan süreyi yeni hıza göre hesaplar.
func advance(real_seconds: float) -> void:
	var remaining := real_seconds
	var guard := 0
	while remaining > 0.0 and guard < 64:
		guard += 1
		var rate := hours_per_second()
		var boundary := _next_boundary()
		var hours_to_boundary := fposmod(boundary - hour, 24.0)
		if hours_to_boundary <= 0.0:
			hours_to_boundary = 24.0
		var secs_to_boundary := hours_to_boundary / rate
		if remaining < secs_to_boundary:
			_set_hour(hour + remaining * rate)
			remaining = 0.0
		else:
			_set_hour(hour + hours_to_boundary)
			remaining -= secs_to_boundary


## Belirli bir saate atlar (uyku). Hedef saat şimdiden küçükse ertesi güne geçer.
func skip_to(target_hour: float) -> void:
	var hours := fposmod(target_hour - hour, 24.0)
	_set_hour(hour + hours)


## 0 gece, 1 tam gündüz. Şafak ve alacakaranlıkta yumuşak geçiş yapar.
func daylight() -> float:
	var h := hour
	if h >= DAWN - 0.5 and h < DAWN + 1.5:
		return smoothstep(DAWN - 0.5, DAWN + 1.5, h)
	if h >= DUSK - 1.5 and h < DUSK + 0.5:
		return 1.0 - smoothstep(DUSK - 1.5, DUSK + 0.5, h)
	return 0.0 if is_night() else 1.0


## Açıkta, ateşsiz ortamın hedef ısısı.
func ambient_warmth() -> float:
	return lerpf(Balance.d.night_warmth, Balance.d.day_warmth, daylight())


func clock_text() -> String:
	var minutes := int(hour * 60.0) % 60
	return "%02d:%02d" % [int(hour), minutes]


func to_dict() -> Dictionary:
	return {"day": day, "hour": hour}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	hour = float(d.get("hour", Balance.d.start_hour))


func _next_boundary() -> float:
	return DAWN if is_night() else DUSK


func _set_hour(new_hour: float) -> void:
	var was_night := is_night()
	var prev_hour := int(hour)
	hour = new_hour
	while hour >= 24.0:
		hour -= 24.0
		day += 1
		day_changed.emit(day)
	if int(hour) != prev_hour:
		hour_changed.emit(int(hour))
	if is_night() != was_night:
		if is_night():
			night_started.emit()
		else:
			day_started.emit()
