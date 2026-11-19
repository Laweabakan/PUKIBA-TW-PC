extends Node
## Prueba de humo: ejecuta menú, metaprogresión y una partida simulada.
## Uso: godot --headless --path . res://tests/smoke_test.tscn
## Usa una ruta de guardado aparte para no tocar la partida real.

var errors: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)
		printerr("FALLO: ", msg)


func _ready() -> void:
	Save.save_path = "user://smoke_test_save.json"
	Save.reset_all()
	await _test_meta()
	await _test_menu()
	await _test_game()
	Save.reset_all()
	if errors.is_empty():
		print("SMOKE TEST OK")
	else:
		print("SMOKE TEST FALLÓ: %d errores" % errors.size())
	get_tree().quit(0 if errors.is_empty() else 1)


func _test_meta() -> void:
	# PC: solo la torre básica de serie; nada de héroes ni otras torres
	check(Save.owns("archer") and not Save.owns("obelisk") and not Save.owns("poison"), "cartas iniciales: solo la torre básica")
	check(Meta.tower_available("archer") and not Meta.tower_available("mage"), "torres de oro bloqueadas hasta su carta")
	for hid in GameData.HEROES.keys():
		check(not Save.owns(hid), "sin héroes al empezar: " + hid)
	# Sobres con oro
	Save.data["coins"] = 0
	check(Meta.buy_packs("tower_bronze", 1).is_empty(), "sin oro no hay sobre")
	Save.add_coins(100000)
	var c_before := Save.coins()
	var res := Meta.buy_packs("tower_gold", 1)
	check(res.size() == 5, "sobre da 5 cartas")
	check(Save.coins() == c_before - Meta.pack_price("tower_gold"), "el sobre se cobra en oro")
	var has_epic := false
	for r in res:
		if GameData.RARITY_ORDER.find(r["rarity"]) >= 3:
			has_epic = true
	check(has_epic, "garantía épica del sobre de oro")
	var multi := Meta.buy_packs("tower_bronze", 10)
	check(multi.size() == 50, "x10 sobres = 50 cartas")
	# Las torres de oro se desbloquean al conseguir su carta
	Meta.add_card("mage")
	check(Meta.tower_available("mage"), "carta de torre de oro la desbloquea")
	check(Meta.buy_upgrade("damage"), "comprar mejora")
	check(Save.upgrade_level("damage") == 1, "nivel mejora")
	# Subir carta
	Save.data["cards"]["archer"]["level"] = 1
	Save.data["cards"]["archer"]["copies"] = 5
	check(Meta.level_card("archer"), "subir carta (solo con copias)")
	Save.data["cards"]["mage"] = {"copies": 0, "level": 1}
	for k in 3:
		Meta.add_card("mage")
	check(Save.card_level("mage") == 2 and Meta.tower_start_level("mage") == GameData.CARD_TO_TOWER_LEVEL[2], "la carta sube sola con copias y sube el nivel de la torre")
	check(Save.card_level("archer") == 2, "nivel carta")
	for i in 20:
		check(GameData.map_path(i).size() >= 2, "camino mapa %d" % i)
	var hp := Meta.open_pack("hero_gold")
	var only_heroes := true
	for r in hp:
		if not GameData.is_hero(r["id"]):
			only_heroes = false
	check(hp.size() == 5 and only_heroes, "sobre de héroes solo trae héroes")
	var tp := Meta.open_pack("tower_bronze")
	var only_towers := true
	for r in tp:
		if GameData.is_hero(r["id"]):
			only_towers = false
	check(only_towers, "sobre de torres solo trae torres")
	Save.data["pity"] = {"epic": 0, "legendary": GameData.PITY_LEGENDARY - 1}
	var pr := Meta.open_pack("common")
	check(pr[0]["rarity"] == "legendary", "pity garantiza legendaria")
	Save.data["cards"]["archer"]["level"] = GameData.MAX_CARD_LEVEL
	var c0 := Save.coins()
	Meta.add_card("archer")
	check(Save.coins() > c0, "duplicado al máximo da oro")
	Save.data["cards"]["archer"]["level"] = 1
	# Fortaleza: mejoras especiales con oro (cada nivel más caro)
	Save.add_coins(10000000)
	var gc0 := Meta.gem_upgrade_cost("g_damage")
	var cb := Save.coins()
	check(Meta.buy_gem_upgrade("g_damage"), "mejora especial con oro")
	check(Save.coins() == cb - gc0, "la mejora especial se cobra en oro")
	check(Meta.gem_upgrade_cost("g_damage") > gc0, "cada nivel más caro")
	check(Save.gem_upgrade_value("g_damage") > 0.0, "efecto de la mejora especial")
	Save.data["cards"]["aldric"]["level"] = 1
	Save.data["cards"]["aldric"] = {"copies": 0, "level": 1}
	for k in 3:
		Meta.add_card("aldric")
	check(not Meta.level_hero("aldric") and Save.hero_level("aldric") == GameData.CARD_TO_HERO_LEVEL[2], "héroe sube de nivel solo con cartas")
	# Progresión a largo plazo
	var lvl0 := int(Save.data["level"])
	Meta.add_xp(5000)
	check(int(Save.data["level"]) > lvl0, "subida de nivel de cuenta")
	Save.data["stats"]["kills"] = 150
	var a0: Dictionary = GameData.ACHIEVEMENTS[0]
	check(Meta.claim_achievement(a0) > 0, "reclamar logro")
	check(not Save.data.has("gems"), "sin gemas en el guardado")
	for mi in 20:
		var info := MapGen.generate(mi)
		check(not info.is_empty() and info["paths"].size() == int(MapGen.layout(mi)["entries"]), "mapa %d generado" % mi)
		if not info.is_empty():
			check(int(info["cols"]) >= 13 and int(info["rows"]) >= 24, "mapa %d grande" % mi)
	check(int(MapGen.layout(19)["entries"]) == 4, "los últimos mapas tienen 4 caminos")
	var hills := 0
	for mi2 in 20:
		hills += (MapGen.generate(mi2)["heights"] as Dictionary).size()
	check(hills > 20, "mapas con colinas")
	var w := WaveGen.generate(19, 500)
	check(w.size() > 10, "oleada 500")
	check(WaveGen.generate(0, 20).size() >= 18, "oleadas con más enemigos")
	await get_tree().process_frame


func _test_menu() -> void:
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	for tab in ["maps", "upgrades", "cards", "shop", "achievements"]:
		menu.show_tab(tab)
		await get_tree().process_frame
	menu._card_detail("vex")
	menu._show_odds()
	await get_tree().process_frame
	menu.queue_free()
	await get_tree().process_frame


func _test_game() -> void:
	Save.data["tutorial"] = Tutorial.DONE # el tutorial se prueba aparte
	# Desbloquea todo para probar todas las torres y héroes.
	for id in GameData.all_card_ids():
		Save.data["cards"][id]["level"] = 3
	Save.data["selected_hero"] = "lyra"
	GameData.current_map = 8
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.gold = 10000000
	var free_cells: Array = []
	for x in GameData.COLS:
		for y in GameData.ROWS:
			if not game.path_cells.has(Vector2i(x, y)) and not game.blocked.has(Vector2i(x, y)):
				free_cells.append(Vector2i(x, y))
	game._try_build(game.HERO_KEY, free_cells[0])
	check(game.hero != null, "héroe colocado")
	# Hasta 3 héroes a la vez, uno de cada
	game._try_build(game.HERO_KEY, free_cells[1])
	check(game.heroes.size() == 1, "el mismo héroe no se coloca dos veces")
	for k in 3:
		Save.data["selected_hero"] = ["vex", "malakar", "seraphina"][k]
		game._try_build(game.HERO_KEY, free_cells[1 + k])
	check(game.heroes.size() == 3, "máximo 3 héroes en el campo")
	game._demolish(game.heroes[2])
	check(game.heroes.size() == 2, "retirar un héroe libera su puesto")
	var tcount := {}
	var hcount := {}
	for tid in GameData.TOWERS.keys():
		tcount[GameData.TOWERS[tid]["rarity"]] = int(tcount.get(GameData.TOWERS[tid]["rarity"], 0)) + 1
	for hid2 in GameData.HEROES.keys():
		hcount[GameData.HEROES[hid2]["rarity"]] = int(hcount.get(GameData.HEROES[hid2]["rarity"], 0)) + 1
	check(int(tcount["legendary"]) == 5 and int(hcount["legendary"]) == 3, "5 torres (2 de oro) y 3 héroes legendarios")
	var prev_t := 999
	var prev_h := 999
	for r in GameData.RARITY_ORDER:
		check(int(hcount[r]) < prev_h, "menos héroes cuanto más raro: " + r)
		prev_t = int(tcount[r])
		prev_h = int(hcount[r])
	var ids: Array = GameData.TOWERS.keys()
	var n_heroes_on: int = game.towers.size()
	for i in ids.size():
		game._try_build(ids[i], free_cells[i + 4])
	check(game.towers.size() == ids.size() + n_heroes_on, "torres construidas")
	for t in game.towers.values():
		game._select(t)
		for k in GameData.MAX_TOWER_LEVEL:
			game._upgrade_selected()
		if t.is_hero:
			check(t.level <= GameData.HERO_MAX_LEVEL, "héroe dentro de su máximo")
		elif t.is_card:
			check(t.level == 0, "torre de cartas no sube con oro: " + t.id)
		elif true:
			check(t.level == Meta.tower_start_level(t.id) and t.level == GameData.CARD_TO_TOWER_LEVEL[3], "torre de oro: nivel de su carta, sin mejoras con oro: " + t.id)
		else:
			check(t.level == GameData.MAX_TOWER_LEVEL, "torre nivel 15: " + t.id)
	game._select(null)
	# Invisibles: solo los atacan las torres detectoras; el Santuario los revela
	var ghost := Enemy.new()
	ghost.setup(game, "m0_10", 10.0, 1, game.paths_points[0])
	game.add_child(ghost)
	var arch_t: Tower = null
	var cross_t: Tower = null
	for tw in game.towers.values():
		if tw.id == "archer": arch_t = tw
		if tw.id == "crossbow": cross_t = tw
	check(ghost.invisible, "enemigo asesino es invisible")
	check(not arch_t.can_target(ghost) and cross_t.can_target(ghost), "solo detectoras ven invisibles")
	ghost.reveal_time = 1.0
	check(arch_t.can_target(ghost), "revelado por el Santuario")
	ghost.queue_free()
	var ball_t: Tower = null
	for tw in game.towers.values():
		if tw.id == "ballista": ball_t = tw
	var walker := Enemy.new()
	walker.setup(game, "m0_0", 10.0, 1, game.paths_points[0])
	check(not ball_t.can_target(walker), "balista solo aire")
	walker.free()
	game.auto_wave = true
	Engine.time_scale = 4.0
	var frames := 0
	while game.last_cleared < 26 and frames < 30000 and not game.over:
		if game.hero.ability_cd <= 0.0:
			game._use_ability()
		await get_tree().physics_frame
		frames += 1
	print("Oleadas superadas: %d, vidas: %d, frames: %d" % [game.last_cleared, game.lives, frames])
	check(game.last_cleared >= 26 or game.over, "progreso de oleadas")
	check(not Save.get_run(8).is_empty() or game.over, "partida guardada")
	# Todas las habilidades de héroe funcionan (y sus modelos se construyen)
	var counts := {}
	for hid in GameData.HEROES.keys():
		var r: String = GameData.HEROES[hid]["rarity"]
		counts[r] = int(counts.get(r, 0)) + 1
		var hv := V3.build_hero(hid)
		check(hv != null, "modelo del héroe " + hid)
		hv.free()
		if game.hero != null and not game.over:
			game.hero.def = GameData.HEROES[hid]
			game.hero.ability_cd = 0.0
			game._use_ability()
			check(game.hero.ability_cd > 0.0, "habilidad de " + hid)
	check(int(counts["common"]) > int(counts["uncommon"]) and int(counts["uncommon"]) > int(counts["rare"]) and int(counts["rare"]) > int(counts["legendary"]), "más héroes comunes que raros")
	# Recargar la partida guardada
	game.queue_free()
	await get_tree().process_frame
	var game2: Node2D = load("res://scenes/game.tscn").instantiate()
	add_child(game2)
	await get_tree().process_frame
	check(game2.towers.size() == ids.size() + n_heroes_on, "partida cargada con torres y héroes")
	game2.lives = 1
	game2._game_over()
	await get_tree().process_frame
	game2._revive()
	check(not game2.over and game2.lives == 25, "revivir")
	# Tocar el castillo abre La Fortaleza
	game2._on_tap(game2.screen_pos(game2.castle_plane, 0.5))
	check(game2._fortress_popup != null and is_instance_valid(game2._fortress_popup), "tocar el castillo abre la Fortaleza")
	get_tree().paused = false
	game2._fortress_popup.queue_free()
	# Girar la vista 90° y volver (4 giros = posición inicial)
	var off0: Vector3 = game2._cam_offset
	for k in 4:
		game2._rotate_view()
		await get_tree().create_timer(0.6, true, false, true).timeout
	check(game2.view_rot == 0 and game2._cam_offset.distance_to(off0) < 0.01, "girar la vista 90°")
	# 19 torres de oro (12 + 7 de fin de juego)
	var gold_n := 0
	for tid in GameData.TOWERS.keys():
		if Meta.is_progress_tower(tid):
			gold_n += 1
	check(gold_n == 19, "19 torres de oro")
	check(GameData.TOWERS["herald"]["rarity"] == "rare" and not Meta.is_progress_tower("herald"), "Torre del Heraldo: rara de cartas")
	# Columna derecha en la batalla: la Tienda se abre encima y al cerrarla se vuelve a jugar
	game2._open_side("shop")
	await get_tree().process_frame
	check(game2._menu_overlay != null and is_instance_valid(game2._menu_overlay) and get_tree().paused, "tienda en la batalla")
	game2._menu_overlay._close_sheet()
	for i in 20:
		await get_tree().process_frame
	check(not is_instance_valid(game2._menu_overlay) and not get_tree().paused, "cerrar la tienda vuelve a la batalla")
	get_tree().paused = false
	# Construir con vista previa del alcance: 1er clic muestra, 2º clic construye (con ratón basta pasar por encima)
	var free_c := Vector2i(-1, -1)
	for x in GameData.COLS:
		for y in GameData.ROWS:
			var cc := Vector2i(x, y)
			if free_c.x < 0 and not game2.path_cells.has(cc) and not game2.blocked.has(cc) and not game2.towers.has(cc) and game2.cell_h(cc) == 0.0:
				free_c = cc
	game2.gold = 100000
	game2._choose_build("archer")
	var sp: Vector2 = game2.screen_pos(GameData.cell_center(free_c))
	var n0: int = game2.towers.size()
	game2._on_tap(sp)
	check(game2.preview_cell == free_c and game2.towers.size() == n0, "primer toque: vista previa del alcance")
	game2._on_tap(sp)
	check(game2.towers.size() == n0 + 1, "segundo toque: construye")
	# Construir / Demoler
	game2._toggle_build_menu("progress")
	var prog_n := 0
	for tid in GameData.TOWERS.keys():
		if Meta.is_progress_tower(tid):
			prog_n += 1
	check(game2.shop_panel.visible and game2.shop_buttons.size() == GameData.TOWERS.size(), "menú Torres muestra todas las torres")
	game2._toggle_build_menu("heroes")
	check(game2.shop_panel.visible and game2.shop_buttons.size() == GameData.HEROES.size(), "menú Héroes muestra todos los héroes")
	game2._toggle_demolish()
	check(game2.demolish_mode and not game2.shop_panel.visible, "modo demoler")
	var n_before: int = game2.towers.size()
	var victim: Tower = null
	for tw in game2.towers.values():
		if not tw.is_hero:
			victim = tw
			break
	var gold_before: int = game2.gold
	game2._demolish(victim)
	check(game2.towers.size() == n_before - 1 and game2.gold > gold_before, "demoler torre devuelve oro")
	Engine.time_scale = 1.0
	get_tree().paused = false
	game2.queue_free()
	await get_tree().process_frame
