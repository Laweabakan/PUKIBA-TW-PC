extends Node
## Detector de cierres inesperados (autoload "CrashReport").
## El juego guarda su registro en user://logs (también en Android). Si la sesión anterior
## terminó de golpe (sin pasar por pausa ni cierre normal), al volver a abrir el juego se
## muestran las últimas líneas de aquel registro con un botón para copiarlas.

const FLAG := "user://session_open.flag"
const SHOW_LINES := 40

var previous_crashed := false
var previous_log := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Las pruebas automáticas no cuentan
	if " ".join(OS.get_cmdline_args()).contains("res://tests/"):
		return
	previous_crashed = FileAccess.file_exists(FLAG)
	if previous_crashed:
		previous_log = _last_log_tail()
	_mark_open(true)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_EXIT_TREE:
			_mark_open(false) # salida normal (o el sistema la cierra en segundo plano)
		NOTIFICATION_APPLICATION_RESUMED:
			_mark_open(true)


func _mark_open(open: bool) -> void:
	if open:
		var f := FileAccess.open(FLAG, FileAccess.WRITE)
		if f != null:
			f.store_string(str(Time.get_unix_time_from_system()))
	elif FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG))


## Últimas líneas del registro de la sesión anterior (el más reciente de los rotados).
func _last_log_tail() -> String:
	var dir := DirAccess.open("user://logs")
	if dir == null:
		return ""
	var files: Array = []
	for f in dir.get_files():
		if f.begins_with("godot") and f.ends_with(".log") and f != "godot.log":
			files.append(f)
	if files.is_empty():
		return ""
	files.sort() # llevan la fecha en el nombre: el último es el más reciente
	var fa := FileAccess.open("user://logs/" + str(files[-1]), FileAccess.READ)
	if fa == null:
		return ""
	var lines := fa.get_as_text().split("\n")
	var useful: Array = []
	for l in lines:
		if l.contains("mesh_get_surface_count") or l.contains("Parameter \"m\" is null"):
			continue
		useful.append(l)
	return "\n".join(useful.slice(maxi(0, useful.size() - SHOW_LINES)))


## Ventana con el registro (la abre el menú al empezar si hubo un cierre inesperado).
func show_popup(parent: Control) -> void:
	if not previous_crashed:
		return
	previous_crashed = false
	var v := UIKit.vbox(8)
	v.add_child(UIKit.ink("El juego se cerró de forma inesperada la última vez. Copia este registro y envíalo para poder arreglarlo.", 17, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lbl := UIKit.ink(previous_log if previous_log != "" else "(no se encontró registro)", 12, UIKit.INK_SOFT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(600, 0)
	scroll.add_child(lbl)
	v.add_child(scroll)
	var text := previous_log
	UIKit.popup(parent, "Informe de cierre", v, [
		["Enviar por correo", func() -> void: open_bug_report(text), UIKit.BLUE],
		["Copiar registro", func() -> void:
			DisplayServer.clipboard_set(text)
			UIKit.toast(parent, "Registro copiado", UIKit.GREEN), UIKit.GREEN],
		["Cerrar", Callable(), UIKit.GREY]], 690)


# ---------------------------------------------------------------- Reportar errores
const BUG_EMAIL := "equipo@pukibagames.com"


## Abre la app de correo con un mensaje al equipo ya preparado: versión, dispositivo y las
## últimas líneas del registro (para poder reproducir el fallo). El jugador escribe el resto.
func open_bug_report(extra_log := "") -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", "1.0"))
	var device := "%s %s · %s" % [OS.get_name(), OS.get_version(), OS.get_model_name()]
	var log_tail := extra_log if extra_log != "" else _current_log_tail(15)
	if log_tail.length() > 1200:
		log_tail = log_tail.substr(log_tail.length() - 1200)
	var body := "Describe el error (qué estabas haciendo y qué pasó):\n\n\n\n---\nVersión: %s\nDispositivo: %s\nRegistro:\n%s" % [version, device, log_tail]
	var url := "mailto:%s?subject=%s&body=%s" % [BUG_EMAIL, ("Error en PUKIBA Defense %s" % version).uri_encode(), body.uri_encode()]
	if OS.shell_open(url) != OK:
		DisplayServer.clipboard_set(BUG_EMAIL + "\n\n" + body)


## Últimas líneas del registro de ESTA sesión.
func _current_log_tail(n: int) -> String:
	var fa := FileAccess.open("user://logs/godot.log", FileAccess.READ)
	if fa == null:
		return ""
	var lines := fa.get_as_text().split("\n")
	return "\n".join(lines.slice(maxi(0, lines.size() - n)))
