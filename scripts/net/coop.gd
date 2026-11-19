extends Node
## Modo cooperativo para 2 jugadores.
##
## - "host": crea la sala (servidor ENet) y ejecuta la partida; envía el estado al otro jugador.
## - "client": se une con el código (IP del anfitrión en la red local), manda sus acciones
##   al anfitrión y dibuja lo que este le envía.
## - "ai": partida local con un aliado controlado por la IA (si no hay otro jugador).
##
## Para jugar por internet con desconocidos (emparejamiento) hace falta un servidor
## (p. ej. Nakama, Google Play Games o un relay WebSocket): ver README, sección "Cooperativo".

signal partner_joined
signal partner_left
signal failed(message: String)
signal game_starting(map_idx: int)

const PORT := 24680
const MAX_WAVE := 100

var role := "" # "", "host", "client", "ai"
var map_idx := 3
var game: Node = null # partida en curso (scripts/game/game.gd)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func() -> void: partner_joined.emit())
	multiplayer.connection_failed.connect(func() -> void:
		leave()
		failed.emit("No se pudo conectar con la sala."))
	multiplayer.server_disconnected.connect(func() -> void:
		partner_left.emit()
		if game != null:
			game.coop_partner_left())


func is_online() -> bool:
	return role == "host" or role == "client"


## Mapa del modo cooperativo: siempre con al menos 2 entradas, según el progreso del jugador.
func pick_map() -> int:
	return clampi(maxi(int(Save.data["unlocked_maps"]) - 1, 3), 3, 19)


## Crea la sala y devuelve el código para compartir (IP local), o "" si falla.
func host() -> String:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1)
	if err != OK:
		failed.emit("No se pudo crear la sala (error %d)." % err)
		return ""
	multiplayer.multiplayer_peer = peer
	role = "host"
	return local_code()


func join(code: String) -> void:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(code.strip_edges(), PORT)
	if err != OK:
		failed.emit("Código no válido.")
		return
	multiplayer.multiplayer_peer = peer
	role = "client"


func play_with_ai() -> void:
	leave()
	role = "ai"
	map_idx = pick_map()


func leave() -> void:
	if has_node("/root/Online"):
		get_node("/root/Online").cancel_coop_search()
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	role = ""
	game = null


## IP local del anfitrión (lo que el otro jugador escribe para unirse).
func local_code() -> String:
	for a in IP.get_local_addresses():
		var s: String = a
		if s.begins_with("192.168.") or s.begins_with("10.") or (s.begins_with("172.") and s.count(".") == 3):
			return s
	return "127.0.0.1"


## El anfitrión empieza la partida para los dos.
func start_game() -> void:
	if role == "host":
		map_idx = pick_map()
		_rpc_start.rpc(map_idx)
	_begin(map_idx)


func _begin(idx: int) -> void:
	map_idx = idx
	GameData.current_map = idx
	game_starting.emit(idx)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/game.tscn")


# ---------------------------------------------------------------- Mensajes
## Cliente -> anfitrión: acción del jugador 2 (construir, mejorar, vender, siguiente oleada).
func request(action: String, args: Array) -> void:
	if role == "client":
		_rpc_request.rpc_id(1, action, args)


## Anfitrión -> cliente: evento de la partida (torre construida, fin...).
func send_event(ev: String, args: Array) -> void:
	if role == "host" and multiplayer.get_peers().size() > 0:
		_rpc_event.rpc(ev, args)


## Anfitrión -> cliente: estado periódico (enemigos, oro, vidas, oleada).
func send_snapshot(data: Dictionary) -> void:
	if role == "host" and multiplayer.get_peers().size() > 0:
		_rpc_snapshot.rpc(data)


@rpc("authority", "call_remote", "reliable")
func _rpc_start(idx: int) -> void:
	_begin(idx)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(action: String, args: Array) -> void:
	if role == "host" and game != null:
		game.coop_remote_action(action, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_event(ev: String, args: Array) -> void:
	if role == "client" and game != null:
		game.coop_event(ev, args)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_snapshot(data: Dictionary) -> void:
	if role == "client" and game != null:
		game.coop_snapshot(data)


func _on_peer_connected(_id: int) -> void:
	if role == "host":
		partner_joined.emit()


func _on_peer_disconnected(_id: int) -> void:
	partner_left.emit()
	if game != null:
		game.coop_partner_left()
