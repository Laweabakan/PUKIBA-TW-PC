class_name SettingsPanel
extends RefCounted
## Ventana de Configuración (engranaje en el menú y en la batalla):
## sonido, pantalla completa, gráficos, atajos de teclado, guardado en la nube,
## documentos legales y estadísticas.


static func open(parent: Control, in_battle := false, on_reset := Callable()) -> Control:
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 16
	UIKit.drag_anywhere(scroll)
	scroll.custom_minimum_size = Vector2(780, 680)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := UIKit.vbox(10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	# ---- Sonido
	v.add_child(_section("Sonido"))
	v.add_child(_slider_row("Música", "music_vol", 0.7))
	v.add_child(_slider_row("Efectos", "sfx_vol", 0.8))

	# ---- Pantalla y gráficos
	v.add_child(_section("Pantalla y gráficos"))
	v.add_child(_toggle_row("Pantalla completa (F11)", "fullscreen", false, func(_on: bool) -> void:
		apply_window()))
	v.add_child(_toggle_row("Sincronización vertical (VSync)", "vsync", true, func(_on: bool) -> void:
		apply_window()))
	v.add_child(_toggle_row("Calidad alta (sombras y suavizado)", "quality_high", true, func(_on: bool) -> void:
		apply_graphics(parent.get_viewport())
		UIKit.toast(parent, "Las sombras cambian en la próxima partida", UIKit.PARCHMENT)))
	v.add_child(_toggle_row("Números de oro flotantes", "float_text", true))

	# ---- Ayuda: reportar errores por correo al equipo
	v.add_child(_section("Ayuda"))
	v.add_child(UIKit.ink("Atajos: Espacio = siguiente oleada · 1/2/3 = velocidad · R = girar vista · Q/E = girar\nRueda = zoom · Clic derecho o WASD = mover la cámara · Esc = pausa · F11 = pantalla completa", 16, UIKit.INK))
	var bug := UIKit.button("", UIKit.BLUE, 18, Vector2(0, 60))
	UIKit.set_button_content(bug, "quest", "Reportar un error", 19, 30)
	bug.mouse_filter = Control.MOUSE_FILTER_PASS
	bug.pressed.connect(func() -> void:
		CrashReport.open_bug_report()
		UIKit.toast(parent, "Se abre tu correo con un mensaje para %s" % CrashReport.BUG_EMAIL, UIKit.PARCHMENT))
	v.add_child(bug)
	var bug_note := UIKit.ink("Se abre tu programa de correo con un mensaje para el equipo (incluye la versión y el registro del juego).", 14, UIKit.INK_SOFT)
	bug_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bug_note.custom_minimum_size = Vector2(720, 0)
	v.add_child(bug_note)

	# ---- Cuenta
	v.add_child(_section("Cuenta"))
	v.add_child(UIKit.ink("Guardado en la nube: %s" % ("activo" if Online.online else "sin conexión (se guarda en este PC)"), 16, UIKit.GREEN.darkened(0.3) if Online.online else UIKit.INK_SOFT))
	v.add_child(UIKit.ink("Código de jugador: %s" % Online.player_code(), 16, UIKit.INK_SOFT))

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
	v.add_child(UIKit.ink("Versión %s (PC)" % ProjectSettings.get_setting("application/config/version", "1.0"), 14, UIKit.INK_SOFT))

	if not in_battle and on_reset.is_valid():
		var reset := UIKit.button("Borrar todo el progreso", UIKit.RED, 16, Vector2(300, 54))
		reset.mouse_filter = Control.MOUSE_FILTER_PASS
		reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		reset.pressed.connect(func() -> void:
			UIKit.popup(parent, "¿Seguro?", UIKit.label("Se borrará TODO tu progreso. No se puede deshacer.", 20, UIKit.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER), [
				["Borrar", on_reset, UIKit.RED],
				["Cancelar", Callable(), UIKit.GREY]]))
		v.add_child(reset)
	return UIKit.popup(parent, "Configuración", scroll, [["Cerrar", Callable(), UIKit.GREY]], 840)


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
	scroll.custom_minimum_size = Vector2(760, 680)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var lbl := UIKit.ink("\n".join(lines.slice(1)).strip_edges(), 15, UIKit.INK)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(740, 0)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lbl)
	var titles := {"terminos": "Términos y condiciones", "privacidad": "Privacidad", "licencias": "Licencias"}
	UIKit.popup(parent, titles.get(doc, "Legal"), scroll, [["Cerrar", Callable(), UIKit.GREY]], 840)


## Pantalla completa y VSync según la configuración (se llama al arrancar y al cambiarlas).
static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var full := bool(setting("fullscreen", false))
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and not (not full and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
		DisplayServer.window_set_mode(want)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(setting("vsync", true)) else DisplayServer.VSYNC_DISABLED)


## F11 (o Alt+Intro): cambia entre ventana y pantalla completa y lo recuerda.
static func toggle_fullscreen() -> void:
	Save.data["settings"]["fullscreen"] = not bool(setting("fullscreen", false))
	Save.save_game()
	apply_window()
