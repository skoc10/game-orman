extends Node
## Komut satırından dünya durumunu ayarlayıp ekran görüntüsü almak için.
## Örnek:
##   godot --path . -- --seed=42 --time=21.5 --pos=10,-30 --height=2 \
##       --yaw=90 --pitch=-10 --shot=/tmp/gece.png --frames=60
## Argümanlar: seed, time (saat), pos (x,z), height (yere göre m), fly,
## yaw/pitch (derece), shot (PNG yolu), frames (beklenecek kare), timescale,
## stats (can,tokluk,su,ısı), atlake (göl kıyısına suya bakarak yerleş),
## damage (miktar), nausea (saniye), give (eşya:adet,...).
## shot verilirse görüntü alındıktan sonra oyun kapanır.

var args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("seed"):
		GameState.new_game_seed = int(args.seed)


func on_world_ready(world: Node) -> void:
	if args.is_empty():
		return
	if args.has("time"):
		TimeOfDay.hour = float(args.time)
	if args.has("timescale"):
		TimeOfDay.time_scale = float(args.timescale)
	var player: Player = world.player
	if args.has("pos") or args.has("height"):
		var p := player.global_position
		if args.has("pos"):
			var xz: PackedStringArray = str(args.pos).split(",")
			p.x = float(xz[0])
			p.z = float(xz[1])
		p.y = world.gen.height_at(p.x, p.z) + float(args.get("height", "0.2"))
		player.teleport(p)
	if args.has("fly") or float(args.get("height", "0")) > 3.0:
		player.debug_fly = true
	if args.has("atlake"):
		_place_at_lake(world, player)
	if args.has("yaw") or args.has("pitch"):
		player.teleport(player.global_position, float(args.get("yaw", rad_to_deg(player.rotation.y))), float(args.get("pitch", "0")))
	if args.has("stats"):
		var v: PackedStringArray = str(args.stats).split(",")
		var keys := ["health", "hunger", "thirst", "warmth"]
		for i in mini(v.size(), keys.size()):
			player.stats.set(keys[i], float(v[i]))
	if args.has("nausea"):
		player.stats.nausea_time = float(args.nausea)
	if args.has("damage"):
		player.take_damage.call_deferred(float(args.damage), "kurt")
	if args.has("give") and player.has_method("debug_give"):
		player.debug_give(str(args.give))
	if args.has("campfire"):
		var fire: Node3D = load("res://buildables/campfire.tscn").instantiate()
		var fwd := -player.global_transform.basis.z
		var fp := player.global_position + fwd * 3.5
		fp.y = world.gen.height_at(fp.x, fp.z)
		world.dynamic_root.add_child(fire)
		fire.global_position = fp
		if str(args.campfire) == "cook":
			fire.cooking.add("meat_raw")
			fire.cooking.add("meat_raw")
			fire.cooking.tick(Balance.d.cook_time + 1.0, true)
			fire.cooking.add("meat_raw")
			fire.cooking.place_pot(3)
	if args.has("inventory"):
		world.get_node("InventoryScreen").open.call_deferred()
	if args.has("select"):
		player.equipment.select(int(args.select))
	if args.has("shot"):
		_capture.call_deferred(str(args.shot), int(args.get("frames", "45")))


func _place_at_lake(world: Node, player: Player) -> void:
	var gen: WorldGen = world.gen
	var c := gen.lake_center
	var dir := (Vector2(world.spawn_point.x, world.spawn_point.z) - c).normalized()
	var p := c
	for i in 200:
		p = c + dir * (i * 0.5)
		if gen.height_at(p.x, p.y) > 0.35:
			break
	var pos := Vector3(p.x, gen.height_at(p.x, p.y) + 0.1, p.y)
	player.teleport(pos, rad_to_deg(atan2(dir.x, dir.y)), -35.0)


func _capture(path: String, frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var world := GameState.world
	if world:
		var pp: Vector3 = world.player.global_position
		print("Oyuncu: %s, zemin: %.2f, FPS: %d" % [pp, world.gen.height_at(pp.x, pp.z), Engine.get_frames_per_second()])
	var img := get_viewport().get_texture().get_image()
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := img.save_png(abs_path)
	print("Ekran görüntüsü: %s (%s)" % [abs_path, error_string(err)])
	get_tree().quit()
