class_name AnimalModel
extends RefCounted
## Dışarıdan gelen animasyonlu hayvan modelini (örn. Quaternius glTF) oyuna uyarlar:
## boyunu ölçekler, yönünü çevirir, animasyonları isimdeki anahtar kelimelerle bulur.
## Dosya yoksa hayvan kendi yer tutucu modelini kullanır.

const MODEL_DIR := "res://assets/models/animals/"
## Animasyon türü -> isimde aranacak kelimeler (küçük harf).
const KEYWORDS := {
	"idle": ["idle"],
	"walk": ["walk"],
	"run": ["gallop", "run"],
	"attack": ["attack", "bite"],
	"death": ["death", "die"],
	"eat": ["eat"],
}
const LOOPING := ["idle", "walk", "run", "eat"]

## Hayvanın altına eklenecek kök düğüm.
var root: Node3D
var player: AnimationPlayer
## Tür -> animasyon adı
var anims := {}
var current := ""


## Dosyalardan ilk bulunanı yükler; hiçbiri yoksa null.
static func try_load(files: Array, height: float) -> AnimalModel:
	for f in files:
		var path: String = MODEL_DIR + str(f)
		if ResourceLoader.exists(path):
			var scene := load(path) as PackedScene
			if scene:
				return from_instance(scene.instantiate() as Node3D, height)
	return null


static func from_instance(inst: Node3D, height: float) -> AnimalModel:
	var m := AnimalModel.new()
	m.root = Node3D.new()
	m.root.name = "Model"
	m.root.add_child(inst)
	var box := _measure(inst, Transform3D.IDENTITY)
	if box.size.y > 0.01:
		var s := height / box.size.y
		inst.scale = Vector3.ONE * s
		inst.position.y = -box.position.y * s
	# Quaternius modelleri +Z'ye bakar; oyunda ileri yön -Z'dir.
	inst.rotation.y = PI
	m.player = _find_player(inst)
	if m.player:
		var names := m.player.get_animation_list()
		for kind in KEYWORDS:
			var found := _match(names, KEYWORDS[kind])
			if found != "":
				m.anims[kind] = found
				var anim := m.player.get_animation(found)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR if kind in LOOPING else Animation.LOOP_NONE
	return m


func has_anim(kind: String) -> bool:
	return anims.has(kind)


func play(kind: String, speed := 1.0) -> void:
	if player == null or not anims.has(kind) or not player.is_inside_tree():
		return
	player.speed_scale = speed
	if current == kind:
		return
	current = kind
	player.play(anims[kind], 0.2)


## Animasyonu son karesinde durdurur (kayıttan gelen leş için).
func hold_last(kind: String) -> void:
	if player == null or not anims.has(kind) or not player.is_inside_tree():
		return
	current = kind
	player.play(anims[kind])
	player.seek(player.current_animation_length, true)
	player.pause()


## İsmi kelimelere böler ve kelime başlarını karşılaştırır; böylece "Death"
## içindeki "eat" yanlışlıkla yemek animasyonu sanılmaz.
static func _match(names: PackedStringArray, keywords: Array) -> String:
	var splitter := RegEx.create_from_string("[a-z]+")
	for n in names:
		var words := splitter.search_all(n.to_lower()).map(func(m: RegExMatch) -> String: return m.get_string())
		for k in keywords:
			for w in words:
				if (w as String).begins_with(k):
					return n
	return ""


static func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var p := _find_player(c)
		if p:
			return p
	return null


## Ağaçtaki tüm görsel örneklerin, kök düğüme göre birleşik sınır kutusu.
static func _measure(node: Node, xform: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var local := xform
	if node is Node3D:
		local = xform * (node as Node3D).transform
	if node is VisualInstance3D:
		box = local * (node as VisualInstance3D).get_aabb()
		first = false
	for c in node.get_children():
		var child := _measure(c, local)
		if child.size == Vector3.ZERO:
			continue
		box = child if first else box.merge(child)
		first = false
	return box
