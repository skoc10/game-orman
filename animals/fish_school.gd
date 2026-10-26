class_name FishSchool
extends Node3D
## Balık sürüsü: suyun altında bir merkez etrafında süzülür. Oyuncu suya girip
## yaklaşınca ya da yakına bir şey düşünce dağılır. Mızrakla vurulan balık su
## yüzeyine çıkar ve alınabilir. Oltayla avlanırken yakındaki sürü balığın daha
## çabuk vurmasını sağlar.

const FAR := 90.0

var count := 5
var radius := 5.0
## true ise deniz balığı (mavi), değilse göl balığı (yeşil).
var sea := false
var floor_y := -2.0

var fish: Array[Fish] = []
var _scatter := 0.0


func _ready() -> void:
	add_to_group("fish_school")
	for i in count:
		var f := Fish.new()
		f.school = self
		f.phase = randf() * TAU
		f.lane = randf_range(0.4, 1.0)
		f.color = Color(0.35, 0.5, 0.62) if sea else Color(0.45, 0.55, 0.38)
		add_child(f)
		fish.append(f)


func _process(delta: float) -> void:
	_scatter = maxf(0.0, _scatter - delta * 0.4)
	var world := GameState.world
	var player: Player = world.player if world else null
	var far := player == null or global_position.distance_to(player.global_position) > FAR
	for f in fish:
		f.visible = not far
	if far:
		return
	if player and player.is_swimming and global_position.distance_to(player.global_position) < radius + 4.0:
		scatter()


## Balıklar kaçışıp sürünün yarıçapı geçici olarak büyür.
func scatter() -> void:
	_scatter = 1.0


func alive_count() -> int:
	return fish.filter(func(f: Fish) -> bool: return is_instance_valid(f) and not f.dead).size()


## Yakındaki (oltanın düştüğü) bir noktaya balık var mı?
func near(point: Vector3, dist := 8.0) -> bool:
	return alive_count() > 0 and Vector2(point.x - global_position.x, point.z - global_position.z).length() < radius + dist


## Sürünün içindeki balığın o anki hedef konumu.
func swim_point(f: Fish, t: float) -> Vector3:
	var r := radius * f.lane * (1.0 + _scatter * 1.5)
	var speed := 0.35 + _scatter * 1.2
	var a := t * speed / maxf(f.lane, 0.3) + f.phase
	var deepest := maxf(floor_y + 0.3, WorldGen.WATER_LEVEL - 1.3)
	var depth := lerpf(deepest, WorldGen.WATER_LEVEL - 0.25, 0.5 + 0.45 * sin(t * 0.3 + f.phase))
	return Vector3(cos(a) * r, depth - global_position.y, sin(a * 1.3) * r * 0.7)


func remove_fish(f: Fish) -> void:
	fish.erase(f)
