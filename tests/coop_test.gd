extends Node
## Prueba del cooperativo.
##   godot --headless --path . res://tests/coop_test.tscn -- ai
##   godot --headless --path . res://tests/coop_test.tscn -- host   (y en otra terminal)
##   godot --headless --path . res://tests/coop_test.tscn -- client
## Imprime el estado de la partida y termina sola.

var role := "ai"
var game: Node = null


func _ready() -> void:
	# La prueba sobrevive al cambio de escena: se mueve a la raíz y deja una escena vacía.
	await get_tree().process_frame
	var dummy := Node.new()
	var tree := get_tree()
	var root := tree.root
	get_parent().remove_child(self)
	root.add_child(dummy)
	tree.current_scene = dummy
	root.add_child(self)
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "ai"
	Save.save_path = "user://coop_test_%s.json" % role
	Save.reset_all()
	Coop.game_starting.connect(func(_m: int) -> void: _watch())
	match role:
		"ai":
			Coop.play_with_ai()
			Coop.start_game()
		"host":
			print("HOST código: ", Coop.host())
			Coop.partner_joined.connect(func() -> void:
				print("HOST: aliado conectado")
				Coop.start_game())
		"client":
			await get_tree().create_timer(1.0).timeout
			Coop.join("127.0.0.1")
	await get_tree().create_timer(60.0).timeout
	print("TIMEOUT ", role)
	get_tree().quit(1)


func _watch() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	game = get_tree().current_scene
	print("%s: partida iniciada en mapa %d (rol %s)" % [role, Coop.map_idx, game.coop])
	await get_tree().create_timer(1.0).timeout
	# Cada jugador construye en su mitad
	var side: int = game.my_side
	var built := 0
	for x in GameData.COLS:
		for y in GameData.ROWS:
			var c := Vector2i(x, y)
			if built < 3 and game.side_of(c) == side and not game.path_cells.has(c) and not game.blocked.has(c) and not game.towers.has(c):
				game._try_build("archer", c)
				built += 1
	if role != "client":
		game.start_next_wave()
	else:
		game.start_next_wave() # pide la siguiente oleada al anfitrión
	await get_tree().create_timer(12.0).timeout
	var mine := 0
	var theirs := 0
	for t in game.towers.values():
		if int(t.get_meta("side", 0)) == side:
			mine += 1
		else:
			theirs += 1
	print("%s: oleada %d, vidas %d, enemigos %d, mis torres %d, del aliado %d, oro %d, oro aliado %d" % [role, game.wave, game.lives, game.enemies.size(), mine, theirs, game.gold, game.partner_gold])
	get_tree().quit(0)
