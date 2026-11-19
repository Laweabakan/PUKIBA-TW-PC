extends Node
## Servicios online con Nakama (https://heroiclabs.com/nakama):
##   - inicio de sesión anónimo por dispositivo,
##   - guardado en la nube (para no perder el progreso al cambiar de móvil),
##   - rankings semanales por mapa (mejor oleada de la semana),
##   - emparejamiento para el cooperativo por internet (usa las mismas RPC que el modo
##     por Wi-Fi gracias a NakamaMultiplayerBridge).
## Si no hay servidor, todo falla en silencio y el juego funciona sin conexión.
## Configuración del servidor: ver server/README.md.

signal status_changed(online: bool)
signal leaderboard_loaded(map_idx: int, top: Array, mine: Dictionary)
signal match_found
signal match_failed(message: String)

# ---------------------------------------------------------------- Configuración
# Servidor de desarrollo local por defecto. Para publicar, cambia HOST/SCHEME/SERVER_KEY
# por los de tu servidor (los mismos que en server/docker-compose.yml).
const SERVER_KEY := "defaultkey"
const HOST := "127.0.0.1"
const PORT := 7350
const SCHEME := "http"
const CLOUD_COLLECTION := "partidas"
const CLOUD_KEY := "progreso"
const CLOUD_SAVE_INTERVAL := 30.0 # segundos mínimos entre subidas

var client: NakamaClient
var session: NakamaSession
var socket: NakamaSocket
var bridge: NakamaMultiplayerBridge
var online := false
var _busy_login := false
var _cloud_timer := 0.0
var _cloud_dirty := false
var _sent_waves := {} # map_idx -> última oleada enviada al ranking
var _ticket = null
## Cuenta aparte para las pruebas automáticas (nunca la del jugador).
var test_account := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	client = Nakama.create_client(SERVER_KEY, HOST, PORT, SCHEME, 3, NakamaLogger.LOG_LEVEL.ERROR)
	Save.changed.connect(func() -> void: _cloud_dirty = true)
	# Las escenas de prueba (res://tests/...) nunca inician sesión con la cuenta del jugador
	if " ".join(OS.get_cmdline_args()).contains("res://tests/"):
		return
	login()


func _process(delta: float) -> void:
	if not online:
		return
	_cloud_timer -= delta
	if _cloud_dirty and _cloud_timer <= 0.0:
		_cloud_timer = CLOUD_SAVE_INTERVAL
		_cloud_dirty = false
		upload_save()


# ---------------------------------------------------------------- Sesión
func device_id() -> String:
	if test_account != "":
		return test_account
	var id := OS.get_unique_id()
	if id == "":
		if not Save.data.has("device_uuid") or str(Save.data["device_uuid"]) == "":
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			Save.data["device_uuid"] = "%08x%08x%08x%08x" % [rng.randi(), rng.randi(), rng.randi(), rng.randi()]
			Save.save_game()
		id = str(Save.data["device_uuid"])
	return id + "-pukiba"


func login() -> void:
	if _busy_login:
		return
	_busy_login = true
	var s: NakamaSession = await client.authenticate_device_async(device_id())
	_busy_login = false
	if s.is_exception():
		_set_online(false)
		return
	session = s
	_set_online(true)
	await download_save()


func _set_online(v: bool) -> void:
	if online != v:
		online = v
		status_changed.emit(v)


func _ensure_session() -> bool:
	if session == null:
		return false
	if session.is_expired():
		var s: NakamaSession = await client.session_refresh_async(session)
		if s.is_exception():
			_set_online(false)
			return false
		session = s
	return true


# ---------------------------------------------------------------- Guardado en la nube
## Solo la partida real se sincroniza con la nube (las pruebas usan otra ruta de guardado
## y nunca deben subir ni descargar datos de la cuenta del jugador).
func _real_save() -> bool:
	return test_account != "" or Save.save_path == Save.SAVE_PATH


func upload_save() -> void:
	if not _real_save() or not online or not await _ensure_session():
		return
	var obj := NakamaWriteStorageObject.new(CLOUD_COLLECTION, CLOUD_KEY, 1, 1, JSON.stringify(Save.data), "")
	var res = await client.write_storage_objects_async(session, [obj])
	if res.is_exception():
		_cloud_dirty = true


## Descarga el guardado de la nube y se queda con el más reciente (por "saved_at").
func download_save() -> void:
	if not _real_save() or not online or not await _ensure_session():
		return
	var res = await client.read_storage_objects_async(session, [NakamaStorageObjectId.new(CLOUD_COLLECTION, CLOUD_KEY, session.user_id)])
	if res.is_exception() or res.objects.is_empty():
		_cloud_dirty = true # primera vez: subir el local
		return
	if not _real_save():
		return # la ruta cambió mientras se descargaba (prueba en marcha)
	var remote = JSON.parse_string(res.objects[0].value)
	if typeof(remote) != TYPE_DICTIONARY:
		return
	if int(remote.get("saved_at", 0)) > int(Save.data.get("saved_at", 0)):
		Save.data = Save.default_data()
		Save._merge(Save.data, remote)
		Save.migrate()
		Save.save_game()
	else:
		_cloud_dirty = true


## Enlaza la cuenta anónima con Google (código de acceso de Google Play Juegos), para poder
## recuperar el progreso al reinstalar o cambiar de móvil.
func link_google(token: String) -> void:
	if token == "" or not online or not await _ensure_session():
		return
	var res = await client.link_google_async(session, token)
	if not res.is_exception():
		Save.data["google_linked"] = true
		Save.save_game()


## Código corto del jugador (para soporte o para pedir el borrado de datos).
func player_code() -> String:
	if session != null:
		return str(session.user_id).substr(0, 8).to_upper()
	return device_id().substr(0, 8).to_upper()


# ---------------------------------------------------------------- Rankings semanales
## Envía la oleada alcanzada (el servidor guarda la mejor de la semana). Se llama al
## terminar cada oleada; solo manda cada 5 oleadas para no saturar.
func report_wave(map_idx: int, wave: int, force := false) -> void:
	if not online or not _real_save():
		return
	var last := int(_sent_waves.get(map_idx, 0))
	if wave <= last or (not force and wave - last < 5):
		return
	_sent_waves[map_idx] = wave
	if not await _ensure_session():
		return
	await client.write_leaderboard_record_async(session, "map_%d" % map_idx, wave)


## Carga el top 50 del mapa y la posición del jugador. Emite leaderboard_loaded.
func load_leaderboard(map_idx: int) -> void:
	if not online or not await _ensure_session():
		leaderboard_loaded.emit(map_idx, [], {})
		return
	var id := "map_%d" % map_idx
	var top: Array = []
	var res = await client.list_leaderboard_records_async(session, id, null, null, 50)
	if not res.is_exception():
		for r in res.records:
			top.append({"rank": int(r.rank), "name": _display_name(r), "wave": int(r.score), "me": r.owner_id == session.user_id})
	var mine := {}
	var around = await client.list_leaderboard_records_around_owner_async(session, id, session.user_id, null, 1)
	if not around.is_exception():
		for r in around.records:
			if r.owner_id == session.user_id:
				mine = {"rank": int(r.rank), "wave": int(r.score)}
	# Algunas versiones no devuelven el puesto en la consulta "alrededor de mí": usar el del top
	for r in top:
		if r["me"] and (mine.is_empty() or int(mine.get("rank", 0)) <= 0):
			mine = {"rank": int(r["rank"]), "wave": int(r["wave"])}
	leaderboard_loaded.emit(map_idx, top, mine)


func _display_name(r) -> String:
	var n: String = str(r.username) if r.username != null else ""
	if n == "" or n.length() > 20:
		n = "Comandante %s" % str(r.owner_id).substr(0, 4)
	return n


# ---------------------------------------------------------------- Cooperativo por internet
## Busca a otro jugador. Al encontrarlo, el primero queda como anfitrión y la partida
## arranca con el flujo normal del cooperativo (Coop.start_game()).
func find_coop_match() -> void:
	if not online or not await _ensure_session():
		match_failed.emit("Sin conexión con el servidor online.")
		return
	cancel_coop_search()
	socket = Nakama.create_socket_from(client)
	var conn = await socket.connect_async(session)
	if conn.is_exception():
		match_failed.emit("No se pudo conectar al servidor de partidas.")
		return
	bridge = NakamaMultiplayerBridge.new(socket)
	bridge.match_join_error.connect(func(e) -> void: match_failed.emit("Error al unirse: %s" % str(e)))
	bridge.match_joined.connect(_on_bridge_joined)
	get_tree().get_multiplayer().multiplayer_peer = bridge.multiplayer_peer
	_ticket = await socket.add_matchmaker_async("+properties.mode:coop", 2, 2, {"mode": "coop"})
	if _ticket.is_exception():
		match_failed.emit("No se pudo buscar partida.")
		return
	bridge.start_matchmaking(_ticket)


func cancel_coop_search() -> void:
	if bridge != null:
		bridge.leave()
		bridge = null
	if socket != null:
		socket.close()
		socket = null
	_ticket = null


func _on_bridge_joined() -> void:
	var host := get_tree().get_multiplayer().get_unique_id() == 1
	Coop.role = "host" if host else "client"
	match_found.emit()
	if host:
		# El anfitrión espera a que el otro jugador termine de conectarse y arranca.
		if get_tree().get_multiplayer().get_peers().is_empty():
			await get_tree().get_multiplayer().peer_connected
		Coop.start_game()
