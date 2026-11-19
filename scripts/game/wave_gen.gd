class_name WaveGen
extends RefCounted
## Generación procedural de las 500 oleadas de cada mapa.
## Cada mapa usa su propia lista de enemigos ("roster") y su jefe.

const HP_BASE := 16.0
const HP_GROWTH := 1.025


const NORMAL_HP_MULT := 1.6 # vida extra de los monstruos normales y élites
const BOSS_HP_MULT := 0.4 # los jefes: x1.6 x 0.4 = 64% de la vida que tenían


static func base_hp(map_idx: int, wave: int) -> float:
	return HP_BASE * GameData.map_difficulty(map_idx) * (1.0 + 0.11 * wave) * pow(HP_GROWTH, wave)


## Oro por enemigo: es la ÚNICA fuente de oro en la partida (no hay bonos por oleada).
static func kill_gold(wave: int) -> int:
	return 4 + int(wave * 0.14)


static func clear_bonus(wave: int) -> int:
	return 20 + wave * 2


## Monedas por oleada: crecen mucho con la dificultad del mapa (los mapas nuevos
## financian las mejoras que permiten llegar más lejos en los antiguos).
static func coins_for_wave(map_idx: int, wave: int) -> int:
	var c := 3.0 * pow(GameData.map_difficulty(map_idx), 1.8) * (1.0 + wave / 20.0) * pow(1.012, wave)
	return int(c * (1.0 + Save.upgrade_value("coins") + Save.gem_upgrade_value("g_coins")) * Meta.event_mult("coins"))


static func is_boss_wave(wave: int) -> bool:
	return wave % GameData.BOSS_EVERY == 0


## Devuelve una lista de entradas {id, hp, gold, delay, elite}.
static func generate(map_idx: int, wave: int) -> Array:
	var map: Dictionary = GameData.MAPS[map_idx]
	var roster: Array = map["roster"]
	# Monstruos normales más duros y jefes más débiles (antes los normales caían solos y el jefe era un muro)
	var hp := base_hp(map_idx, wave) * NORMAL_HP_MULT
	var gold := kill_gold(wave)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(map_idx) + ":" + str(wave))

	# Los 15 tipos de enemigo se van presentando con las oleadas (el último hacia la 195).
	var available: Array = []
	var newest := 0
	for k in roster.size():
		if GameData.enemy_intro_wave(k) <= wave:
			available.append(roster[k])
			newest = k
	var flyers: Array = available.filter(func(id): return bool(GameData.ENEMIES[id].get("flying", false)))
	var walkers: Array = available.filter(func(id): return not bool(GameData.ENEMIES[id].get("flying", false)))
	if walkers.is_empty():
		walkers = ["goblin"]

	var count := mini(5 + int(wave * 0.35), 45)
	var interval := maxf(0.28, 0.95 - wave * 0.004)
	var out: Array = []

	var pool: Array = available
	var label := ""
	if wave % 7 == 0 and not flyers.is_empty():
		pool = flyers # Oleada aérea
		label = "air"
	elif wave % 5 == 0:
		pool = [available[rng.randi() % available.size()]] # Horda de un solo tipo
		count = int(count * 1.3)
		label = "horde"

	# Pesos: los recién llegados aparecen más (durante unas 15 oleadas tras presentarse)
	var weights: Array = []
	var total_w := 0.0
	for id in pool:
		var k := roster.find(id)
		var w := 1.0 + 0.12 * k
		if wave - GameData.enemy_intro_wave(k) < 15:
			w *= 3.0
		weights.append(w)
		total_w += w
	for i in count:
		var roll := rng.randf() * total_w
		var pick := 0
		while pick < pool.size() - 1 and roll > float(weights[pick]):
			roll -= float(weights[pick])
			pick += 1
		var id: String = pool[pick]
		var speed_mult := float(GameData.ENEMIES[id].get("speed", 1.0))
		# Los rápidos llegan en grupos más apretados.
		var delay := interval / clampf(speed_mult, 0.6, 1.6)
		out.append({"id": id, "hp": hp, "gold": gold, "delay": delay, "elite": false})

	if wave % 5 == 0 and not is_boss_wave(wave):
		var strongest: String = available[available.size() - 1]
		out.append({"id": strongest, "hp": hp, "gold": gold, "delay": 1.5, "elite": true})

	if is_boss_wave(wave):
		var boss_hp := hp * (1.0 + wave / 100.0) * BOSS_HP_MULT
		out.append({"id": map["boss"], "hp": boss_hp, "gold": gold * 30, "delay": 2.0, "elite": false})
		# Cada 100 oleadas aparece un segundo jefe.
		if wave % 100 == 0:
			out.append({"id": map["boss"], "hp": boss_hp, "gold": gold * 30, "delay": 3.0, "elite": false})

	if out.size() > 0:
		out[0]["label"] = label
	return out


static func preview_text(map_idx: int, wave: int) -> String:
	if is_boss_wave(wave):
		return "¡JEFE! " + GameData.ENEMIES[GameData.MAPS[map_idx]["boss"]]["name"]
	if wave % 7 == 0:
		return "Oleada aérea"
	if wave % 5 == 0:
		return "Horda con élite"
	if false:
		return "Horda"
	return ""
