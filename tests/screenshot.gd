extends Node
## Genera capturas del menú y de una partida en user://screens/ (requiere ventana, no headless).
## Uso: godot --path . res://tests/screenshot.tscn

func _ready() -> void:
	Save.save_path = "user://screenshot_save.json"
	Save.reset_all()
	Save.data["age_asked"] = true
	Save.data["level"] = 5
	Save.data["coins"] = 20000
	DirAccess.make_dir_recursive_absolute("user://screens")
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	for tab in ["daily", "maps", "cards", "shop", "upgrades"]:
		menu.show_tab(tab)
		await _shot("menu_" + tab)
	menu.queue_free()
	for id in GameData.all_card_ids():
		Save.data["cards"][id]["level"] = 2
	Save.data["selected_hero"] = "vex"
	var margs := OS.get_cmdline_user_args()
	GameData.current_map = int(margs[0]) if margs.size() > 0 else 0
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.gold = 50000
	var placed := 0
	var ids: Array = GameData.TOWERS.keys()
	game._try_build(game.HERO_KEY, Vector2i(3, 5))
	for x in GameData.COLS:
		for y in GameData.ROWS:
			var c := Vector2i(x, y)
			if placed < ids.size() and not game.path_cells.has(c) and not game.blocked.has(c) and not game.towers.has(c) and (x + y) % 3 == 0:
				game._try_build(ids[placed], c)
				game.towers[c].level = placed % 6
				placed += 1
	game.wave = 24
	game.last_cleared = 24
	game.start_next_wave()
	Engine.time_scale = 2.0
	for i in 420:
		await get_tree().process_frame
	game._toggle_demolish()
	await _shot("game")
	Save.reset_all()
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://screens/%s.png" % name)
	print("saved ", ProjectSettings.globalize_path("user://screens/%s.png" % name))
