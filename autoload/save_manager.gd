extends Node
## Persistencia del progreso del jugador en user://save.json (versión de PC)
## Incluye una firma simple para dificultar la edición manual del archivo.

signal changed

const SAVE_PATH := "user://save.json"
var save_path := SAVE_PATH # la prueba de humo usa otra ruta
const SALT := "pukiba-defense-v1-salt" # Cámbialo antes de publicar.

var data: Dictionary = {}

func _ready() -> void:
	load_game()

func default_data() -> Dictionary:
	var cards := {}
	for id in GameData.all_card_ids():
		cards[id] = {"copies": 0, "level": 0}
	# Versión de PC: solo la torre inicial viene de serie; todo lo demás (torres y héroes) sale en sobres.
	cards[GameData.STARTER_TOWER] = {"copies": 0, "level": 1}
	var ups := {}
	for id in GameData.UPGRADES.keys():
		ups[id] = 0
	return {
		"version": 1,
		"coins": 500,
		"unlocked_maps": 1,
		"best_wave": {}, # "map_idx" -> int
		"milestones": {}, # "map_idx:wave" -> true
		"upgrades": ups,
		"cards": cards,
		"selected_hero": "aldric",
		"tutorial": 0, # 0..3 (3 = tutorial terminado)
		"runs": {}, # "map_idx" -> estado de partida guardada
		"stats": {"kills": 0, "waves": 0, "packs": 0, "bosses": 0, "build": 0, "upgrade": 0, "flyers": 0},
		"level": 1,
		"xp": 0,
		"achievements": {}, # id -> niveles reclamados
		"gem_upgrades": {}, # mejoras especiales de la Fortaleza (con oro)
		"pity": {"epic": 0, "legendary": 0}, # cartas desde la última de esa rareza
		"settings": {"sound": true, "music": true, "quality_high": true, "fullscreen": false},
	}

func load_game() -> void:
	data = default_data()
	if not FileAccess.file_exists(save_path) and not FileAccess.file_exists(save_path + ".bak"):
		save_game()
		return
	# Si el archivo principal quedó a medias (se cerró el juego mientras guardaba),
	# se usa la copia anterior en vez de empezar de cero.
	var loaded = _read_save(save_path)
	if loaded == null:
		loaded = _read_save(save_path + ".bak")
		if loaded != null:
			push_warning("Guardado principal dañado: se recupera la copia de seguridad.")
	if typeof(loaded) == TYPE_DICTIONARY:
		_merge(data, loaded)
	migrate()
	# La torre inicial siempre está disponible
	if int(data["cards"][GameData.STARTER_TOWER]["level"]) < 1:
		data["cards"][GameData.STARTER_TOWER]["level"] = 1
	# El héroe en uso debe ser uno que tengas: si no, el primero de tu colección
	var sel := str(data.get("selected_hero", ""))
	if not GameData.HEROES.has(sel) or not owns(sel):
		for hid in GameData.HEROES.keys():
			if owns(hid):
				data["selected_hero"] = hid
				break
		if not GameData.HEROES.has(str(data["selected_hero"])):
			data["selected_hero"] = GameData.FIRST_HERO

## Lee y valida un archivo de guardado. Devuelve el diccionario o null si falta o está dañado.
func _read_save(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("payload"):
		push_warning("Partida guardada corrupta: " + path)
		return null
	var payload: String = str(parsed["payload"])
	if (payload + SALT).sha256_text() != str(parsed.get("sig", "")):
		push_warning("Firma de guardado inválida: " + path)
		return null
	var loaded = JSON.parse_string(payload)
	return loaded if typeof(loaded) == TYPE_DICTIONARY else null

## Mezcla lo cargado sobre los valores por defecto (así las versiones nuevas añaden claves).
func _merge(base: Dictionary, loaded: Dictionary) -> void:
	for k in loaded.keys():
		if base.has(k) and typeof(base[k]) == TYPE_DICTIONARY and typeof(loaded[k]) == TYPE_DICTIONARY \
				and k != "runs" and k != "best_wave" and k != "milestones":
			_merge(base[k], loaded[k])
		else:
			base[k] = loaded[k]

## Guardado seguro: se escribe en un archivo temporal y luego se cambia por el bueno,
## así un cierre a mitad de escritura nunca deja la partida dañada (y queda una copia .bak).
func save_game() -> void:
	data["saved_at"] = now() # para sincronizar con la nube (gana el más reciente)
	var payload := JSON.stringify(data)
	var wrapper := {"payload": payload, "sig": (payload + SALT).sha256_text()}
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo guardar la partida")
		return
	f.store_string(JSON.stringify(wrapper))
	f.close()
	var real := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		var bak := ProjectSettings.globalize_path(save_path + ".bak")
		if FileAccess.file_exists(save_path + ".bak"):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(real, bak)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), real) != OK:
		push_error("No se pudo reemplazar el guardado")
	changed.emit()

func reset_all() -> void:
	data = default_data()
	save_game()

# ---------------------------------------------------------------- Oro
func coins() -> int:
	return int(data["coins"])

func add_coins(n: int) -> void:
	data["coins"] = coins() + n
	save_game()

func spend_coins(n: int) -> bool:
	if coins() < n:
		return false
	data["coins"] = coins() - n
	save_game()
	return true

# ---------------------------------------------------------------- Mapas
func best_wave(map_idx: int) -> int:
	return int(data["best_wave"].get(str(map_idx), 0))

func set_best_wave(map_idx: int, wave: int) -> void:
	if wave > best_wave(map_idx):
		data["best_wave"][str(map_idx)] = wave

func is_map_unlocked(map_idx: int) -> bool:
	return map_idx < int(data["unlocked_maps"])

func get_run(map_idx: int) -> Dictionary:
	return data["runs"].get(str(map_idx), {})

func set_run(map_idx: int, run: Dictionary) -> void:
	if run.is_empty():
		data["runs"].erase(str(map_idx))
	else:
		data["runs"][str(map_idx)] = run
	save_game()

# ---------------------------------------------------------------- Mejoras y cartas
func hero_level(id: String) -> int:
	# PC: el nivel del héroe lo marca su carta (sube juntando copias en los sobres)
	return int(GameData.CARD_TO_HERO_LEVEL[clampi(card_level(id), 0, GameData.CARD_TO_HERO_LEVEL.size() - 1)])

## Nivel inicial permanente de una torre (Entrenamiento de la Fortaleza).
func tower_train_level(id: String) -> int:
	return int(data.get("tower_train", {}).get(id, 0))

func gem_upgrade_level(id: String) -> int:
	return int(data.get("gem_upgrades", {}).get(id, 0))

func gem_upgrade_value(id: String) -> float:
	var def: Dictionary = GameData.GEM_UPGRADES[id]
	if def.get("mult", false):
		return pow(1.0 + float(def["per_level"]), gem_upgrade_level(id)) - 1.0
	return gem_upgrade_level(id) * float(def["per_level"])

func upgrade_level(id: String) -> int:
	return int(data["upgrades"].get(id, 0))

func upgrade_value(id: String) -> float:
	var def: Dictionary = GameData.UPGRADES[id]
	if def.get("mult", false):
		# Mejora acumulativa: devuelve el bono total (x(1+p)^nivel - 1)
		return pow(1.0 + float(def["per_level"]), upgrade_level(id)) - 1.0
	return upgrade_level(id) * float(def["per_level"])

func card(id: String) -> Dictionary:
	return data["cards"].get(id, {"copies": 0, "level": 0})

func card_level(id: String) -> int:
	return int(card(id)["level"])

func owns(id: String) -> bool:
	return card_level(id) > 0

func today() -> String:
	return Time.get_date_string_from_system()

func now() -> int:
	return int(Time.get_unix_time_from_system())

## Ajustes de partidas guardadas con versiones anteriores (también para las que llegan de la nube).
func migrate() -> void:
	pass
