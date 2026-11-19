class_name SettingsPanel
extends RefCounted
## Ventana de Configuración (engranaje arriba a la derecha en el menú y "Ajustes" en la pausa):
## sonido, vibración, gráficos, notificaciones, cuenta de Google Play Juegos, compras,
## documentos legales y estadísticas.


static func open(parent: Control, in_battle := false, on_reset := Callable()) -> Control:
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 16
	UIKit.drag_anywhere(scroll)
	scroll.custom_minimum_size = Vector2(640, 820)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := UIKit.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	# ---- Sonido
	v.add_child(_section("Sonido"))
	v.add_child(_slider_row("Música", "music_vol", 0.7))
	v.add_child(_slider_row("Efectos", "sfx_vol", 0.8))
	v.add_child(_toggle_row("Vibración", "vibration", true, func(_on: bool) -> void: Audio.vibrate(60)))

	# ---- Gráficos
	v.add_child(_section("Gráficos"))
	v.add_child(_toggle_row("Calidad alta (sombras y suavizado)", "quality_high", true, func(_on: bool) -> void:
		apply_graphics(parent.get_viewport())
		UIKit.toast(parent, "Las sombras cambian en la próxima partida", UIKit.PARCHMENT)))
	v.add_child(_toggle_row("Números de oro flotantes", "float_text", true))

	# ---- Avisos
	v.add_child(_section("Notificaciones"))
	v.add_child(_toggle_row("Recordatorios (tesoro lleno, sobres listos)", "notifications", true))

	# ---- Ayuda: reportar errores por correo al equipo
	v.add_child(_section("Ayuda"))
	var bug := UIKit.button("", UIKit.BLUE, 18, Vector2(0, 60))
	UIKit.set_button_content(bug, "quest", "Reportar un error", 19, 30)
	bug.mouse_filter = Control.MOUSE_FILTER_PASS
	bug.pressed.connect(func() -> void:
		CrashReport.open_bug_report()
		UIKit.toast(parent, "Se abre tu correo con un mensaje para %s" % CrashReport.BUG_EMAIL, UIKit.PARCHMENT))
	v.add_child(bug)
	var bug_note := UIKit.ink("Se abre tu app de correo con un mensaje para el equipo (incluye la versión y el registro del juego).", 14, UIKit.INK_SOFT)
	bug_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bug_note.custom_minimum_size = Vector2(600, 0)
	v.add_child(bug_note)

	# ---- Cuenta
	v.add_child(_section("Cuenta"))
	var gp := UIKit.button("", UIKit.GREEN, 18, Vector2(0, 64))
	gp.mouse_filter = Control.MOUSE_FILTER_PASS
	var refresh_gp := func() -> void:
		if PlayGames.signed_in:
			UIKit.set_button_content(gp, "check", "Google Play Juegos: %s" % (PlayGames.player_name if PlayGames.player_name != "" else "conectado"), 18, 28)
		else:
			UIKit.set_button_content(gp, "play", "Conectar con Google Play Juegos", 18, 28)
	refresh_gp.call()
	gp.pressed.connect(func() -> void:
		if not PlayGames.available():
			UIKit.toast(parent, "Disponible en la versión de Android con Google Play Juegos", UIKit.PARCHMENT)
		elif not PlayGames.signed_in:
			PlayGames.sign_in())
	PlayGames.status_changed.connect(func(_ok: bool) -> void:
		if is_instance_valid(gp):
			refresh_gp.call())
	v.add_child(gp)
	v.add_child(UIKit.ink("Guardado en la nube: %s" % ("activo" if Online.online else "sin conexión (se guarda en el móvil)"), 16, UIKit.GREEN.darkened(0.3) if Online.online else UIKit.INK_SOFT))
	v.add_child(UIKit.ink("Código de jugador: %s" % Online.player_code(), 16, UIKit.INK_SOFT))
	var restore := UIKit.button("Restaurar compras", UIKit.BLUE, 17, Vector2(0, 56))
	restore.mouse_filter = Control.MOUSE_FILTER_PASS
	restore.pressed.connect(func() -> void:
		IAP.restore_purchases()
		UIKit.toast(parent, "Buscando compras anteriores...", UIKit.PARCHMENT))
	v.add_child(restore)

	# ---- Legal
	v.add_child(_section("Legal"))
	var legal := UIKit.hbox(8)
	legal.alignment = BoxContainer.ALIGNMENT_CENTER
	for doc in [["Términos", "terminos"], ["Privacidad", "privacidad"], ["Licencias", "licencias"]]:
		var d: String = doc[1]
		var lb := UIKit.button(doc[0], UIKit.PURPLE, 16, Vector2(170, 52))
		lb.mouse_filter = Control.MOUSE_FILTER_PASS
		lb.pressed.connect(func() -> void: show_legal(parent, d))
		legal.add_child(lb)
	v.add_child(legal)

	# ---- Estadísticas
	v.add_child(_section("Estadísticas"))
	var st: Dictionary = Save.data["stats"]
	for line in [["skull", "Enemigos derrotados: %d" % int(st["kills"])], ["flag", "Oleadas superadas: %d" % int(st["waves"])], ["cards", "Sobres abiertos: %d" % int(st["packs"])]]:
		v.add_child(UIKit.icon_label(line[0], line[1], 18, UIKit.INK, 28, true))
	v.add_child(UIKit.ink("Versión %s · Facturación: %s" % [ProjectSettings.get_setting("application/config/version", "1.0"), "Google Play" if IAP.is_real_billing() else "simulada"], 14, UIKit.INK_SOFT))

	if not in_battle and on_reset.is_valid():
		var reset := UIKit.button("Borrar todo el progreso", UIKit.RED, 16, Vector2(300, 54))
		reset.mouse_filter = Control.MOUSE_FILTER_PASS
		reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		reset.pressed.connect(func() -> void:
			UIKit.popup(parent, "¿Seguro?", UIKit.label("Se borrará TODO tu progreso. No se puede deshacer.", 20, UIKit.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER), [
				["Borrar", on_reset, UIKit.RED],
				["Cancelar", Callable(), UIKit.GREY]]))
		v.add_child(reset)
	return UIKit.popup(parent, "Configuración", scroll, [["Cerrar", Callable(), UIKit.GREY]], 690)


## Suavizado (MSAA) según la calidad elegida. Las sombras las lee la partida al empezar.
static func apply_graphics(vp: Viewport) -> void:
	if vp == null:
		return
	var high := bool(Save.data.get("settings", {}).get("quality_high", true))
	# Con el estilo low-poly la GPU va sobrada: bordes suavizados siempre, también en el móvil
	# (en las caras planas los bordes dentados se notan mucho). Calidad alta: 4x.
	vp.msaa_3d = Viewport.MSAA_4X if high else Viewport.MSAA_2X


static func setting(key: String, default_value = true):
	return Save.data.get("settings", {}).get(key, default_value)


static func _section(title: String) -> Control:
	var l := UIKit.ink(title, 21, UIKit.BLUE.darkened(0.35), HORIZONTAL_ALIGNMENT_LEFT, true)
	return l


static func _row(title: String) -> HBoxContainer:
	var row := UIKit.hbox(10)
	var l := UIKit.ink(title, 18, UIKit.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	return row


static func _slider_row(title: String, key: String, default_value: float) -> Control:
	var row := _row(title)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(setting(key, default_value))
	s.custom_minimum_size = Vector2(300, 44)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := UIKit.style(Color(0.45, 0.35, 0.25, 0.35), Color(0, 0, 0, 0), 8, 0)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := UIKit.style(UIKit.GREEN, Color(0, 0, 0, 0), 8, 0)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	var pct := UIKit.ink("%d%%" % roundi(s.value * 100.0), 16, UIKit.INK_SOFT)
	pct.custom_minimum_size = Vector2(56, 0)
	s.value_changed.connect(func(val: float) -> void:
		pct.text = "%d%%" % roundi(val * 100.0)
		Save.data["settings"][key] = val
		Audio.apply_settings())
	s.drag_ended.connect(func(_changed: bool) -> void:
		Save.save_game()
		Audio.sfx("coin" if key == "sfx_vol" else "click"))
	row.add_child(s)
	row.add_child(pct)
	return row


static func _toggle_row(title: String, key: String, default_value: bool, on_change := Callable()) -> Control:
	var row := _row(title)
	var b := UIKit.button("", UIKit.GREEN, 17, Vector2(110, 52))
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var paint := func() -> void:
		var on := bool(setting(key, default_value))
		b.text = "SÍ" if on else "NO"
		UIKit.set_button_color(b, UIKit.GREEN if on else UIKit.GREY)
	paint.call()
	b.pressed.connect(func() -> void:
		var on := not bool(setting(key, default_value))
		Save.data["settings"][key] = on
		Save.save_game()
		Audio.apply_settings()
		paint.call()
		if on_change.is_valid():
			on_change.call(on))
	row.add_child(b)
	return row


static var _knob: Texture2D


static func _knob_texture() -> Texture2D:
	if _knob != null:
		return _knob
	var n := 36
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for x in n:
		for y in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(n * 0.5 - d, 0.0, 1.0)
			var col := Color.WHITE if d < n * 0.5 - 4.0 else UIKit.GREEN.darkened(0.3)
			img.set_pixel(x, y, Color(col, a))
	_knob = ImageTexture.create_from_image(img)
	return _knob


## Muestra un documento legal de assets/legal (en "licencias" añade la licencia MIT de Godot).
static func show_legal(parent: Control, doc: String) -> void:
	var text := "No se pudo cargar el documento."
	var f := FileAccess.open("res://assets/legal/%s.txt" % doc, FileAccess.READ)
	if f != null:
		text = f.get_as_text()
	if doc == "licencias":
		text += "\n\n——— Godot Engine (MIT) ———\n" + Engine.get_license_text()
	var lines := text.split("\n")
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 16
	scroll.custom_minimum_size = Vector2(620, 820)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lbl := UIKit.ink("\n".join(lines.slice(1)).strip_edges(), 15, UIKit.INK)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(600, 0)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lbl)
	var titles := {"terminos": "Términos y condiciones", "privacidad": "Privacidad", "licencias": "Licencias"}
	UIKit.popup(parent, titles.get(doc, "Legal"), scroll, [["Cerrar", Callable(), UIKit.GREY]], 690)
