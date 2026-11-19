extends Node
## Recorre el tutorial de la primera partida (construir, mejorar en La Fortaleza, abrir un sobre)
## y guarda capturas de cada paso en user://screens/tut_*.png.
## Uso: godot --path . res://tests/tutorial_test.tscn

var errors := 0


func check(c: bool, msg: String) -> void:
	if not c:
		errors += 1
		printerr("FALLO: ", msg)


func _ready() -> void:
	Save.save_path = "user://tutorial_test.json"
	Save.reset_all()
	DirAccess.make_dir_recursive_absolute("user://screens")
	GameData.current_map = 0
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await _wait(0.5)
	check(Tutorial.step() == 0, "tutorial empieza en 0")
	await _shot("tut_1_construir")
	game._toggle_build_menu("progress")
	await _wait(0.2)
	await _shot("tut_2_elegir")
	game._choose_build("archer")
	await _wait(0.2)
	await _shot("tut_3_casilla")
	var tut: Node = null
	for c in game.get_children():
		if c is Tutorial:
			tut = c
	var cell: Vector2i = tut._good_cell()
	game._on_tap(game.screen_pos(GameData.cell_center(cell)))
	await _wait(0.2)
	await _shot("tut_4_otra_vez")
	game._on_tap(game.screen_pos(GameData.cell_center(cell)))
	await _wait(0.3)
	check(Tutorial.step() == 1, "paso 1: torre construida")
	await _wait(0.2)
	await _shot("tut_5_castillo")
	game._open_fortress()
	await _wait(0.3)
	await _shot("tut_6_mejora")
	check(Meta.buy_upgrade("damage"), "comprar mejora en el tutorial")
	await _wait(0.3)
	check(Tutorial.step() == 2, "paso 2: mejora comprada")
	await _shot("tut_6b_tras_mejora")
	get_tree().paused = false
	if game._fortress_popup != null and is_instance_valid(game._fortress_popup):
		game._fortress_popup.queue_free()
	await _wait(0.3)
	await _shot("tut_7_tienda")
	game._open_side("shop")
	await _wait(0.4)
	await _shot("tut_8_sobre")
	Meta.claim_free_pack()
	await _wait(0.3)
	check(Tutorial.step() == Tutorial.DONE, "paso 3: sobre abierto, tutorial terminado")
	get_tree().paused = false
	Save.reset_all()
	print("TUTORIAL TEST OK" if errors == 0 else "TUTORIAL TEST FALLÓ: %d" % errors)
	get_tree().quit(0 if errors == 0 else 1)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _shot(n: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://screens/%s.png" % n)
