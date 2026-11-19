extends Node
## Gestor de anuncios.
##
## Por defecto usa un anuncio SIMULADO (pantalla con cuenta atrás) para poder
## probar todo el flujo sin SDK. Para producción, instala un plugin de AdMob para
## Godot 4 y asigna un objeto a `backend` que implemente:
##   is_rewarded_ready() -> bool
##   show_rewarded(on_reward: Callable, on_closed: Callable) -> void
##   show_interstitial() -> void
## Ver README.md, sección "Monetización".

signal ad_started
signal ad_finished

# IDs de PRUEBA oficiales de Google. Sustitúyelos por los tuyos al publicar.
const REWARDED_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"
const INTERSTITIAL_UNIT_ID := "ca-app-pub-3940256099942544/1033173712"

const INTERSTITIAL_COOLDOWN := 180 # segundos mínimos entre intersticiales
const RUNS_BEFORE_FIRST_INTERSTITIAL := 2

var backend: Object = null
var _busy := false
var _runs_this_session := 0


func has_no_ads() -> bool:
	return bool(Save.data["no_ads"])


func can_show_rewarded() -> bool:
	if has_no_ads():
		return true
	return not _busy and Meta.ads_left_today() > 0


## Muestra un anuncio con recompensa. `on_reward` solo se llama si se vio completo.
func show_rewarded(placement: String, on_reward: Callable, on_fail: Callable = Callable()) -> void:
	# Con "Sin Anuncios" comprado, los premios por anuncio se dan al instante, sin ver nada.
	if has_no_ads():
		Firebase.log_event("ad_skipped_no_ads", {"placement": placement})
		on_reward.call()
		return
	if not can_show_rewarded():
		if on_fail.is_valid():
			on_fail.call("Has alcanzado el límite de anuncios de hoy.")
		return
	_busy = true
	ad_started.emit()
	var paused_before := get_tree().paused
	get_tree().paused = true
	var rewarded := [false]
	var done := func() -> void:
		_busy = false
		get_tree().paused = paused_before
		ad_finished.emit()
		if rewarded[0]:
			Meta.register_ad_watched()
			Firebase.log_event("ad_rewarded", {"placement": placement})
			on_reward.call()
		elif on_fail.is_valid():
			on_fail.call("El anuncio no se completó.")
	if backend != null and backend.call("is_rewarded_ready"):
		backend.call("show_rewarded", func() -> void: rewarded[0] = true, done)
	else:
		_show_simulated("Anuncio con recompensa\n(%s)" % placement, 4.0, func(completed: bool) -> void:
			rewarded[0] = completed
			done.call())


## Se llama al terminar una partida. Respeta "Sin anuncios" y un tiempo mínimo.
func maybe_show_interstitial() -> void:
	_runs_this_session += 1
	if has_no_ads() or _busy:
		return
	if _runs_this_session < RUNS_BEFORE_FIRST_INTERSTITIAL:
		return
	var now := Save.now()
	if now - int(Save.data["last_interstitial"]) < INTERSTITIAL_COOLDOWN:
		return
	Save.data["last_interstitial"] = now
	Save.save_game()
	if backend != null:
		backend.call("show_interstitial")
	else:
		_busy = true
		var paused_before := get_tree().paused
		get_tree().paused = true
		_show_simulated("Anuncio\n¿Cansado de anuncios? Compra 'Sin Anuncios' en la tienda.", 3.0, func(_c: bool) -> void:
			_busy = false
			get_tree().paused = paused_before)


# ---------------------------------------------------------------- Simulación
func _show_simulated(text: String, seconds: float, on_close: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 34)
	bg.add_child(lbl)
	var close := Button.new()
	close.text = "  Cerrar  "
	close.add_theme_font_size_override("font_size", 26)
	close.position = Vector2(540, 40)
	close.visible = false
	bg.add_child(close)
	var skip := Button.new()
	skip.text = "  Saltar (sin recompensa)  "
	skip.add_theme_font_size_override("font_size", 20)
	skip.position = Vector2(30, 30)
	bg.add_child(skip)
	var state := {"t": seconds, "finished": false}
	var finish := func(completed: bool) -> void:
		if state["finished"]:
			return
		state["finished"] = true
		layer.queue_free()
		on_close.call(completed)
	close.pressed.connect(func() -> void: finish.call(true))
	skip.pressed.connect(func() -> void: finish.call(false))
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(timer)
	timer.timeout.connect(func() -> void:
		state["t"] = float(state["t"]) - 0.1
		if float(state["t"]) <= 0.0:
			lbl.text = text + "\n\n¡Recompensa lista!"
			close.visible = true
			skip.visible = false
			timer.stop()
		else:
			lbl.text = text + "\n\n%d" % ceili(float(state["t"])))
	timer.start()
	lbl.text = text
