extends Node
## Prueba de los servicios online (necesita el servidor Nakama local; ver server/README.md).
##   godot --headless --path . res://tests/online_test.tscn -- basic
##   godot --headless --path . res://tests/online_test.tscn -- coop   (en DOS terminales a la vez)

var mode := "basic"


func _ready() -> void:
	await get_tree().process_frame
	# La prueba sobrevive al cambio de escena (cooperativo): se mueve a la raíz
	var tree := get_tree()
	var dummy := Node.new()
	get_parent().remove_child(self)
	tree.root.add_child(dummy)
	tree.current_scene = dummy
	tree.root.add_child(self)
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else "basic"
	Save.save_path = "user://online_test_%d.json" % (OS.get_process_id())
	Save.reset_all()
	# Cuenta de pruebas propia: nunca tocar la cuenta/nube del jugador
	Online.test_account = "pukiba-test-%d" % OS.get_process_id()
	Online.session = null
	Online._set_online(false)
	Online.login()
	# Esperar el inicio de sesión
	for i in 50:
		if Online.online:
			break
		await tree.create_timer(0.2).timeout
	print("ONLINE: sesión ", "OK " + Online.session.user_id if Online.online else "FALLÓ")
	if not Online.online:
		tree.quit(1)
		return
	if mode == "basic":
		await _basic()
	else:
		await _coop()


func _basic() -> void:
	# Guardado en la nube: subir, cambiar en local, descargar (gana el más reciente)
	Save.data["coins"] = 777777
	Save.save_game()
	await Online.upload_save()
	Save.data["coins"] = 1
	Save.data["saved_at"] = 0
	await Online.download_save()
	print("ONLINE: guardado en la nube ", "OK" if Save.coins() == 777777 else "FALLÓ (%d)" % Save.coins())
	# Ranking
	await Online.report_wave(0, 42, true)
	Online.load_leaderboard(0)
	var res: Array = await Online.leaderboard_loaded
	var top: Array = res[1]
	var mine: Dictionary = res[2]
	print("ONLINE: ranking top=%d, mi puesto=%s" % [top.size(), str(mine)])
	get_tree().quit(0)


func _coop() -> void:
	Coop.game_starting.connect(func(_m: int) -> void: _watch())
	Online.match_failed.connect(func(msg: String) -> void:
		print("ONLINE coop: ", msg)
		get_tree().quit(1))
	Online.find_coop_match()
	print("ONLINE coop: buscando partida...")
	await get_tree().create_timer(60.0).timeout
	print("ONLINE coop: TIMEOUT")
	get_tree().quit(1)


func _watch() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var game: Node = get_tree().current_scene
	print("ONLINE coop: partida iniciada, rol %s, mapa %d" % [game.coop, Coop.map_idx])
	await get_tree().create_timer(1.0).timeout
	var side: int = game.my_side
	var built := 0
	for x in GameData.COLS:
		for y in GameData.ROWS:
			var c := Vector2i(x, y)
			if built < 2 and game.side_of(c) == side and not game.path_cells.has(c) and not game.blocked.has(c) and not game.towers.has(c):
				game._try_build("archer", c)
				built += 1
	game.start_next_wave()
	await get_tree().create_timer(10.0).timeout
	print("ONLINE coop: rol %s oleada %d, torres %d, enemigos %d" % [game.coop, game.wave, game.towers.size(), game.enemies.size()])
	get_tree().quit(0)
