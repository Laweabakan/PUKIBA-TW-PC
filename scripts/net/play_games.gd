extends Node
## Google Play Juegos (autoload "PlayGames").
## Usa el plugin gratuito y de código abierto "Godot Play Game Services" (licencia MIT):
## https://github.com/godot-sdk-integrations/godot-play-game-services
## Sin el plugin (PC o compilación sin él) todo responde "no disponible" y el juego sigue igual.
##
## Al conectar: se obtiene el nombre del jugador y, si hay servidor online, se enlaza la
## cuenta de Nakama con Google para recuperar el progreso en otro móvil.

signal status_changed(signed_in: bool)

## ID de cliente web de OAuth (Google Cloud > Credenciales) para el acceso desde el servidor.
## Déjalo vacío si no usas el enlace con Nakama.
const SERVER_CLIENT_ID := ""

var signed_in := false
var player_name := ""
var _plugin: Object


func _ready() -> void:
	for n in ["GodotPlayGameServices", "GodotGooglePlayGameServices"]:
		if Engine.has_singleton(n):
			_plugin = Engine.get_singleton(n)
			break
	if _plugin == null:
		return
	_connect("userAuthenticated", _on_authenticated)
	_connect("currentPlayerLoaded", _on_player_loaded)
	_connect("serverSideAccessRequested", _on_server_token)
	if _plugin.has_method("initialize"):
		_plugin.call("initialize")
	# Google Play inicia sesión solo si el jugador ya aceptó antes
	if _plugin.has_method("isAuthenticated"):
		_plugin.call("isAuthenticated")


func available() -> bool:
	return _plugin != null


func _connect(sig: String, cb: Callable) -> void:
	if _plugin.has_signal(sig):
		_plugin.connect(sig, cb)


## Botón "Conectar con Google Play Juegos".
func sign_in() -> void:
	if _plugin == null:
		return
	if _plugin.has_method("signIn"):
		_plugin.call("signIn")


func _on_authenticated(ok: bool) -> void:
	signed_in = ok
	Save.data["play_games_linked"] = ok
	Save.save_game()
	status_changed.emit(ok)
	if not ok:
		return
	if _plugin.has_method("loadCurrentPlayer"):
		_plugin.call("loadCurrentPlayer", false)
	if SERVER_CLIENT_ID != "" and _plugin.has_method("requestServerSideAccess"):
		_plugin.call("requestServerSideAccess", SERVER_CLIENT_ID, false)
	Firebase.log_event("play_games_sign_in", {})


func _on_player_loaded(json: String) -> void:
	var d = JSON.parse_string(json)
	if typeof(d) == TYPE_DICTIONARY:
		player_name = str(d.get("displayName", ""))
		status_changed.emit(signed_in)


func _on_server_token(token: String) -> void:
	Online.link_google(token)
