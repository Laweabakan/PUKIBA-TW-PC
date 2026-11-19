extends Node2D
## Vista previa de proyectiles y efectos (requiere ventana, no headless).
## Uso: godot --path . res://tests/vfx_preview.tscn [-- close]
## Hace de "juego falso": expone world, screen_pos, resolve_hit y spawn_fx como game.gd.
## Guarda capturas en user://screens/vfx_*.png

const STYLES := {"arrow": "physical", "arrow_poison": "poison", "bolt": "physical", "rock": "physical",
	"flask": "poison", "fireball": "fire", "ice": "ice", "rocket": "fire", "orb": "magic", "fire": "fire",
	"void": "magic", "holy": "holy", "slash": "physical"}
const SPLASH := ["rock", "flask", "fireball", "rocket"]

var world: Node3D
var camera: Camera3D
var tag := "far"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://screens")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	if tag == "game":
		await _phase_real_game()
		get_tree().quit()
		return
	GameData.COLS = 11
	GameData.ROWS = 18
	_build_world()
	await _phase_projectiles()
	await _phase_fx()
	get_tree().quit()


func _build_world() -> void:
	world = Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.15, 0.2, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.82, 0.95)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	world.add_child(sun)
	V3.box(Vector3(11.3, 0.6, 18.3), Color(0.42, 0.62, 0.3), Vector3(0, -0.3, 0), 0.0, world)
	for i in 6:
		V3.box(Vector3(0.9, 0.04, 0.9), Color(0.7, 0.6, 0.42), Vector3(-4 + i * 1.6, 0.01, 2.0), 0.0, world)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 47.0
	world.add_child(camera)
	camera.current = true
	_aim(Vector3(0, 0, 0.5), 17.0 if tag == "far" else 8.0)


func _aim(target: Vector3, dist: float) -> void:
	var off := (Vector3(0, 16.5, 9.9) - Vector3(0, 0, 3.2)).normalized() * dist
	camera.look_at_from_position(target + off, target, Vector3.UP)


func screen_pos(p: Vector2, h := 0.0) -> Vector2:
	return camera.unproject_position(V3.to3(p, h))


func spawn_fx(kind: String, pos: Vector2, r: float, color: Color, duration := 0.35) -> Fx:
	var fx := Fx.new()
	fx.setup(self, kind, pos, r, color, duration)
	add_child(fx)
	return fx


func resolve_hit(payload: Dictionary, _target: Enemy, pos: Vector2, _origin: Vector2, _oh := 1.0) -> void:
	var color: Color = GameData.DAMAGE_TYPES[payload["type"]]["color"]
	if payload.get("splash", false):
		spawn_fx("impact", pos, 0.8 * GameData.TILE, color, 0.5)
	else:
		spawn_fx("hit", pos, GameData.TILE * 0.25, color, 0.3)


func _p(cx: float, cy: float) -> Vector2:
	# celda (cx, cy) relativa al centro del tablero -> píxeles de plano
	return V3.to2(Vector3(cx, 0, cy))


func _phase_projectiles() -> void:
	var names: Array = STYLES.keys()
	var close := tag != "far"
	for i in names.size():
		var s: String = names[i]
		var lane := (i - names.size() * 0.5) * (0.55 if close else 1.0) + 0.5
		var from := _p(-6.0 if close else -5.0, lane)
		var to := _p(6.0 if close else 5.0, lane)
		var p := Projectile.new()
		p.setup(self, from, 0.8, null, {"type": STYLES[s], "splash": s in SPLASH}, s, to)
		if close:
			p.speed *= 0.35
		add_child(p)
		var l := Label3D.new()
		l.text = s
		l.font_size = 48 if close else 96
		l.pixel_size = 0.004
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = V3.to3(_p(-4.6 if close else -5.3, lane), 0.3)
		world.add_child(l)
	if close:
		_aim(Vector3(-2.6, 0, 0.3), 6.5)
	await _wait(0.3 if not close else 1.2)
	await _shot("proj_a")
	await _wait(0.25 if not close else 0.9)
	await _shot("proj_b")
	await _wait(1.6 if not close else 3.0)
	await _shot("proj_end")
	for c in world.get_children():
		if c is Label3D:
			c.queue_free()
	await _wait(1.0)


func _phase_fx() -> void:
	var T := float(GameData.TILE)
	var close := tag != "far"
	var sp := 2.1 if close else 2.3
	var kinds := [["build", 0.8, Color(0.75, 0.62, 0.45), 0.6], ["levelup", 1.2, UIKit.GOLD, 0.7],
		["death", 0.6, Color(0.8, 0.3, 0.25), 0.3], ["boss_death", 1.6, Color(1, 0.8, 0.2), 1.8],
		["impact:fire", 0.5, GameData.DAMAGE_TYPES["fire"]["color"], 0.9], ["impact:ice", 0.5, GameData.DAMAGE_TYPES["ice"]["color"], 0.9],
		["impact:poison", 0.5, GameData.DAMAGE_TYPES["poison"]["color"], 0.9], ["impact:physical", 0.5, GameData.DAMAGE_TYPES["physical"]["color"], 0.9],
		["impact:lightning", 0.5, GameData.DAMAGE_TYPES["lightning"]["color"], 0.9], ["impact:holy", 0.5, GameData.DAMAGE_TYPES["holy"]["color"], 0.9],
		["impact:magic", 0.5, GameData.DAMAGE_TYPES["magic"]["color"], 0.9], ["hit", 0.3, GameData.DAMAGE_TYPES["fire"]["color"], 0.25],
		["heal", 0.6, Color(1, 0.9, 0.5), 2.0], ["burst", 0.5, Color(1, 0.4, 0.1), 0.6], ["bolt", 0.2, GameData.DAMAGE_TYPES["lightning"]["color"], 0],
		["text", 0.9, UIKit.GOLD, 0]]
	if close:
		_aim(Vector3(0, 0, 0.5), 11.0)
	for i in kinds.size():
		var k: Array = kinds[i]
		var cx := (i % 4 - 1.5) * sp
		var cy := (int(i / 4) - 1.5) * sp + 0.5
		var pos := _p(cx, cy)
		var kind: String = String(k[0]).split(":")[0]
		if kind == "bolt":
			var fx := Fx.new()
			fx.setup(self, "bolt", Vector2.ZERO, 0, k[2], 0.2)
			fx.points = PackedVector2Array([_p(cx - 0.8, cy + 0.6), _p(cx - 0.2, cy - 0.3), _p(cx + 0.5, cy + 0.2), _p(cx + 0.9, cy - 0.6)])
			fx.heights = [1.2, 0.35, 0.35, 1.5]
			add_child(fx)
		elif kind == "text":
			var fx2 := Fx.new()
			fx2.setup(self, "text", pos, 0, k[2], 0.9)
			fx2.text = "+125 oro"
			add_child(fx2)
		else:
			spawn_fx(kind, pos, float(k[3]) * T, k[2], float(k[1]))
	var t := 0.0
	for st in [0.05, 0.15, 0.3, 0.55, 0.9, 1.4]:
		await _wait(st - t)
		t = st
		await _shot("fx_%02d" % int(st * 100))


func _wait(sec: float) -> void:
	if sec > 0.0:
		await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://screens/vfx_%s_%s.png" % [tag, name]
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


## Partida real (como tests/screenshot.gd): torres de todo tipo disparando a una oleada.
func _phase_real_game() -> void:
	Save.save_path = "user://vfx_preview_save.json"
	Save.reset_all()
	for id in GameData.all_card_ids():
		Save.data["cards"][id]["level"] = 3
	GameData.current_map = 0
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.gold = 100000
	var ids: Array = GameData.TOWERS.keys()
	var placed := 0
	# Torres pegadas al camino, en la mitad superior (donde pasa la oleada)
	for y in range(2, GameData.ROWS):
		for x in GameData.COLS:
			var c := Vector2i(x, y)
			if placed >= ids.size() or game.path_cells.has(c) or game.blocked.has(c) or game.towers.has(c):
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if game.path_cells.has(c + d):
					near = true
			if near and (x + y) % 2 == 0:
				game._try_build(ids[placed], c)
				game.towers[c].level = 3
				placed += 1
	game.wave = 19
	game.last_cleared = 19
	game.start_next_wave()
	Engine.time_scale = 1.5
	for k in 520:
		await get_tree().process_frame
	for i in 6:
		for k in 25:
			await get_tree().process_frame
		print("paused=", get_tree().paused, " enemies=", game.enemies.size(), " first=", game.enemies[0].position if game.enemies.size() > 0 else Vector2.ZERO)
		await _shot("game_%d" % i)
	Engine.time_scale = 1.0
	Save.reset_all()
