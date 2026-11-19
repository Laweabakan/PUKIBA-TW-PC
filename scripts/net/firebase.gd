extends Node
## Analítica y notificaciones (Firebase en Android).
##
## Detecta en tiempo de ejecución un plugin de Firebase para Godot 4 en Android
## (singleton "GodotFirebaseAnalytics"/"GodotFirebaseMessaging" o similar) y un plugin de
## notificaciones locales ("GodotLocalNotification" o similar). Sin plugins (PC, editor),
## todas las funciones no hacen nada. Ver README, sección "Firebase".

const ANALYTICS_SINGLETONS := ["GodotFirebaseAnalytics", "FirebaseAnalytics", "Firebase"]
const MESSAGING_SINGLETONS := ["GodotFirebaseMessaging", "FirebaseMessaging", "Firebase"]
const LOCAL_NOTIF_SINGLETONS := ["GodotLocalNotification", "LocalNotification", "NotificationScheduler"]

# Identificadores de los avisos locales
const NOTIF_TREASURY := 1
const NOTIF_FREE_PACK := 2
const NOTIF_AD_PACK := 3
const NOTIF_STREAK := 4

var _analytics: Object = null
var _messaging: Object = null
var _local: Object = null


func _ready() -> void:
	_analytics = _find(ANALYTICS_SINGLETONS)
	_messaging = _find(MESSAGING_SINGLETONS)
	_local = _find(LOCAL_NOTIF_SINGLETONS)
	log_event("app_open", {})


func _find(names: Array) -> Object:
	for n in names:
		if Engine.has_singleton(n):
			return Engine.get_singleton(n)
	return null


func available() -> bool:
	return _analytics != null or _messaging != null or _local != null


# ---------------------------------------------------------------- Analítica
func log_event(event_name: String, params: Dictionary) -> void:
	if _analytics == null:
		return
	if _analytics.has_method("log_event"):
		_analytics.call("log_event", event_name, params)
	elif _analytics.has_method("logEvent"):
		_analytics.call("logEvent", event_name, params)


func set_user_property(prop: String, value: String) -> void:
	if _analytics != null and _analytics.has_method("set_user_property"):
		_analytics.call("set_user_property", prop, value)


# ---------------------------------------------------------------- Notificaciones
func request_push_permission() -> void:
	if _messaging != null and _messaging.has_method("request_permission"):
		_messaging.call("request_permission")
	elif _local != null and _local.has_method("request_permission"):
		_local.call("request_permission")


## Programa un aviso local dentro de `seconds` segundos (reemplaza el anterior con el mismo id).
func schedule_local(id: int, title: String, body: String, seconds: int) -> void:
	if _local == null or seconds <= 0:
		return
	if _local.has_method("cancel"):
		_local.call("cancel", id)
	if _local.has_method("schedule"):
		_local.call("schedule", body, seconds, id, title)
	elif _local.has_method("show"):
		_local.call("show", body, title, seconds, id)


func cancel_local(id: int) -> void:
	if _local != null and _local.has_method("cancel"):
		_local.call("cancel", id)


## Al salir o pasar a segundo plano: programa los recordatorios útiles (máximo 3-4 al día,
## siempre ligados a algo que el jugador dejó pendiente).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_schedule_reminders()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		for id in [NOTIF_TREASURY, NOTIF_FREE_PACK, NOTIF_AD_PACK, NOTIF_STREAK]:
			cancel_local(id)


func _schedule_reminders() -> void:
	if _local == null or not bool(Save.data.get("settings", {}).get("notifications", true)):
		return
	var treasury_left := int(Save.data.get("treasury_at", 0)) + int(GameData.TREASURY_MAX_HOURS * 3600.0) - Save.now()
	schedule_local(NOTIF_TREASURY, "¡Tu tesoro está lleno!", "Las arcas del castillo rebosan de oro. ¡Recógelo!", treasury_left)
	schedule_local(NOTIF_FREE_PACK, "Sobre de regalo listo", "El reino te regala un sobre de cartas.", Meta.free_pack_seconds_left())
	schedule_local(NOTIF_AD_PACK, "Sobre extra disponible", "Mira un anuncio y abre otro sobre.", Meta.ad_pack_seconds_left())
	# Racha: avisar por la tarde del día siguiente si aún no se reclamó
	var d := Time.get_datetime_dict_from_system()
	var secs_to_tomorrow_18 := (24 - int(d["hour"]) + 18) * 3600 - int(d["minute"]) * 60
	schedule_local(NOTIF_STREAK, "¡No pierdas tu racha!", "Entra hoy para reclamar tu recompensa diaria.", secs_to_tomorrow_18)
