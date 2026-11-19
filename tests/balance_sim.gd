extends Node
## Simulación de balance: un bot construye y mejora torres con avaricia.
## Uso: godot --headless --fixed-fps 60 --path . res://tests/balance_sim.tscn [-- <escenario>]
## Imprime la oleada alcanzada por mapa con y sin mejoras globales.

## Cada escenario es una etapa del jugador: nivel de la Forja Real (daño), nivel del resto de
## mejoras de la Fortaleza y nivel de las cartas.
const SCENARIOS := [
	{"name": "nuevo (solo arqueros)", "map": 0, "dmg": 0, "other": 0, "cards": 0},
	{"name": "nuevo", "map": 0, "dmg": 0, "other": 0, "cards": 1},
	{"name": "inicial", "map": 0, "dmg": 15, "other": 5, "cards": 2},
	{"name": "medio", "map": 0, "dmg": 40, "other": 15, "cards": 3},
	{"name": "avanzado", "map": 0, "dmg": 80, "other": 25, "cards": 4},
	{"name": "medio en mapa 5", "map": 4, "dmg": 40, "other": 15, "cards": 3},
	{"name": "avanzado en mapa 10", "map": 9, "dmg": 80, "other": 25, "cards": 4},
	{"name": "experto en mapa 20", "map": 19, "dmg": 150, "other": 40, "cards": 5},
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var only := int(args[0]) if args.size() > 0 else -1
	Save.save_path = "user://balance_sim_save_%d.json" % only
	for si in SCENARIOS.size():
		if only >= 0 and si != only:
			continue
		var sc: Dictionary = SCENARIOS[si]
		Save.reset_all()
		Save.data["unlocked_maps"] = int(sc["map"]) + 1
		for m in int(sc["map"]) + 1:
			Save.data["best_wave"][str(m)] = 100
		for id in GameData.UPGRADES.keys():
			var lv := int(sc["dmg"]) if id == "damage" else int(sc["other"])
			Save.data["upgrades"][id] = mini(lv, int(GameData.UPGRADES[id]["max"]))
		for id in GameData.all_card_ids():
			Save.data["cards"][id]["level"] = int(sc["cards"])
		var r := await _run(int(sc["map"]))
		print("Mapa %2d | %s | daño x%.1f | cartas nv %d -> oleada %d" % [int(sc["map"]) + 1, sc["name"], 1.0 + Save.upgrade_value("damage"), int(sc["cards"]), r])
	Save.reset_all()
	get_tree().quit()


var _last_print := 0


func _run(map_idx: int) -> int:
	_last_print = 0
	GameData.current_map = map_idx
	var game: Node2D = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	# Casillas ordenadas por cantidad de camino cercano.
	var cells: Array = []
	for x in GameData.COLS:
		for y in GameData.ROWS:
			var c := Vector2i(x, y)
			if game.path_cells.has(c) or game.blocked.has(c):
				continue
			var score := 0
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					if game.path_cells.has(c + Vector2i(dx, dy)):
						score += 1
			cells.append([score, c])
	cells.sort_custom(func(a, b): return a[0] > b[0])
	game._try_build(game.HERO_KEY, cells.pop_front()[1])
	var rotation := ["archer", "cannon", "mage", "frost", "crossbow", "ballista", "storm", "poison", "obelisk", "inferno", "sanctuary", "druid", "rocket", "alchemist"]
	var ri := 0
	game.auto_wave = true
	Engine.time_scale = 4.0
	var frames := 0
	while not game.over and game.last_cleared < 500 and frames < 400000:
		frames += 1
		if game.hero != null and game.hero.ability_cd <= 0.0 and not game.enemies.is_empty():
			game._use_ability()
		# Decide: construir si hay casilla y la mejor torre es asequible; si no, mejorar.
		var id: String = rotation[ri % rotation.size()]
		if not Meta.tower_available(id):
			ri += 1
		elif not cells.is_empty() and game.towers.size() < 14 and game.gold >= game.tower_cost(id):
			game._try_build(id, cells.pop_front()[1])
			ri += 1
		else:
			var cheapest: Tower = null
			for t in game.towers.values():
				if t.upgrade_cost() > 0 and (cheapest == null or t.upgrade_cost() < cheapest.upgrade_cost()):
					cheapest = t
			if cheapest != null and game.gold >= cheapest.upgrade_cost():
				game._select(cheapest)
				game._upgrade_selected()
				game._select(null)
			elif game.towers.size() >= 14 and not cells.is_empty() and game.gold >= game.tower_cost(id) * 3:
				game._try_build(id, cells.pop_front()[1])
				ri += 1
		get_tree().paused = false # cierra avisos como "nuevo mapa"
		if game.last_cleared > 0 and game.last_cleared % 25 == 0 and game.last_cleared != _last_print:
			_last_print = game.last_cleared
			print("  progreso mapa %d: oleada %d, vidas %d" % [map_idx + 1, game.last_cleared, game.lives])
		await get_tree().physics_frame
	var reached: int = game.last_cleared
	Engine.time_scale = 1.0
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	return reached
