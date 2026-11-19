extends Control
## Menú principal (versión de PC, pantalla horizontal 16:9).
## Barra superior (nivel, oro y ajustes), navegación a la izquierda (Jugar, Fortaleza, Cartas,
## Tienda, Logros, Cooperativo, Ranking) y el contenido a la derecha. La Tienda, los Logros, el
## Cooperativo y el Ranking se abren como ventanas (hojas) encima del contenido.

var W := 1920.0 # tamaño real de la pantalla (se lee en _ready)
var H := 1080.0
const TOP_H := 124.0
const NAV_W := 270.0
## Pestañas de la navegación: [id, texto, icono, color]
const NAV := [
	["maps", "Jugar", "map", Color(0.3, 0.62, 0.45)],
	["upgrades", "Fortaleza", "castle", Color(0.45, 0.5, 0.75)],
	["cards", "Cartas", "cards", Color(0.42, 0.5, 0.95)],
	["shop", "Tienda", "chest", Color(0.95, 0.6, 0.2)],
	["achievements", "Logros", "trophy", Color(0.25, 0.6, 0.9)],
	["coop", "Cooperativo", "hero", Color(0.2, 0.62, 0.62)],
	["ranking", "Ranking", "trophy", Color(0.85, 0.45, 0.2)],
]
const SHEETS := ["shop", "achievements", "collection"]
const SHEET_W := 1240.0
var SHEET_MAX_H := 1080.0 - TOP_H - 24.0 # la barra superior (oro, ajustes) queda siempre visible

var current_tab := "maps"
## Modo superpuesto: el menú se abre ENCIMA de la batalla (pausada) solo para mostrar una hoja
## (tienda, colección, logros). Al cerrarla se vuelve a la batalla.
var overlay := false
var _packs_anchor: Control


## Desplaza la Tienda hasta la sección de sobres (lo usa el tutorial).
func focus_packs() -> void:
	if sheet == null or not is_instance_valid(sheet) or _packs_anchor == null or not is_instance_valid(_packs_anchor):
		return
	var sc: ScrollContainer = sheet.get_meta("scroll")
	sc.scroll_vertical = 0
var _overlay_base := 0
signal overlay_closed
var content: Control
var lbl_coins: Label
var tab_buttons := {}
var side_buttons := {}
var nav_col: VBoxContainer
var crest: LevelCrest
var sel_map := 0
var sheet: Control = null
var sheet_id := ""
var _last_coins := -1


## Vista previa de un mapa (suelo a cuadros, caminos redondeados). En PC se dibuja apaisada,
## igual que se ve en la batalla: las entradas a la izquierda y el castillo a la derecha.
class MapPreview extends Control:
	var map_idx := 0

	func _draw() -> void:
		var m: Dictionary = GameData.MAPS[map_idx]
		var info: Dictionary = MapGen.generate(map_idx)
		var cols := int(info["cols"])
		var rows := int(info["rows"])
		# Apaisado: la fila del mapa es la columna en pantalla
		var s := minf(size.x / float(rows), size.y / float(cols))
		var o := (size - Vector2(rows, cols) * s) * 0.5
		var ground: Color = m["ground"]
		var bg := StyleBoxFlat.new()
		bg.bg_color = ground.darkened(0.25)
		bg.set_corner_radius_all(18)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		for x in cols:
			for y in rows:
				var col := ground if (x + y) % 2 == 0 else ground.lightened(0.06)
				draw_rect(Rect2(o + Vector2(y, cols - 1 - x) * s, Vector2(s, s)), col)
		for c in info["water"].keys():
			var cc: Vector2i = c
			if cc.x >= 0 and cc.y >= 0 and cc.x < cols and cc.y < rows:
				draw_rect(Rect2(o + Vector2(cc.y, cols - 1 - cc.x) * s, Vector2(s, s)), Color(0.3, 0.55, 0.85))
		var path_col: Color = m["path"]
		var w := s * 0.72
		for pts in info["paths"]:
			for pass_i in 2:
				var pc: Color = path_col.darkened(0.2) if pass_i == 0 else path_col
				var pw: float = w + 4.0 if pass_i == 0 else w
				for i in pts.size() - 1:
					var a := _pt(pts[i], o, s, cols)
					var b := _pt(pts[i + 1], o, s, cols)
					draw_line(a, b, pc, pw)
					draw_circle(a, pw * 0.5, pc)
					draw_circle(b, pw * 0.5, pc)

	func _pt(c: Vector2i, o: Vector2, s: float, cols: int) -> Vector2:
		var cx := clampf(float(c.x), -0.4, cols - 0.6)
		var cy := clampf(float(c.y), -0.6, float(MapGen.generate(map_idx)["rows"]) - 0.4)
		return o + (Vector2(cy, cols - 1 - cx) + Vector2(0.5, 0.5)) * s


## Escudo de nivel de cuenta con anillo de experiencia.
class LevelCrest extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		var lvl := int(Save.data.get("level", 1))
		var need := maxi(GameData.xp_to_next(lvl), 1)
		var f := clampf(float(int(Save.data.get("xp", 0))) / float(need), 0.0, 1.0)
		draw_circle(c + Vector2(0, 3), r + 3.0, Color(0, 0, 0, 0.3))
		draw_circle(c, r + 2.0, UIKit.NAVY_DARK)
		draw_arc(c, r - 3.0, 0.0, TAU, 48, Color(1, 1, 1, 0.15), 7.0, true)
		if f > 0.0:
			draw_arc(c, r - 3.0, -PI / 2.0, -PI / 2.0 + TAU * f, 48, UIKit.GOLD, 7.0, true)
		draw_circle(c, r - 8.0, UIKit.TEAL.darkened(0.15))
		draw_circle(c - Vector2(0, 3), r - 11.0, UIKit.TEAL)
		var fnt := UIKit.font(true)
		var txt := str(lvl)
		var fs := 30 if lvl < 100 else 24
		var tw := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := c + Vector2(-tw * 0.5, fs * 0.36 + 4.0)
		draw_string_outline(fnt, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, UIKit.NAVY_DARK)
		draw_string(fnt, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		var sw := fnt.get_string_size("NIVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(fnt, c + Vector2(-sw * 0.5, -r * 0.42), "NIVEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))


## Fondo con degradado azul noche y destellos suaves.
class Backdrop extends Control:
	func _draw() -> void:
		var top := Color(0.2, 0.36, 0.55)
		var bot := Color(0.09, 0.13, 0.27)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([top, top, bot, bot]))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 70:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_circle(p, rng.randf_range(1.0, 3.0), Color(1, 1, 0.9, rng.randf_range(0.08, 0.3)))
		for i in 9:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_circle(p, rng.randf_range(80.0, 220.0), Color(1, 1, 1, 0.025))


func _ready() -> void:
	var vs := GameData.screen()
	W = vs.x
	H = vs.y
	SHEET_MAX_H = H - TOP_H - 24.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if overlay:
		_ready_overlay()
		return
	Audio.play_music("menu")
	SettingsPanel.apply_graphics(get_viewport())
	CrashReport.call_deferred("show_popup", self)
	UIKit.apply_theme(self)
	var bg := Backdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	content = Control.new()
	content.position = Vector2(NAV_W + 24.0, TOP_H)
	content.size = Vector2(W - NAV_W - 40.0, H - TOP_H)
	add_child(content)
	_build_nav()
	_build_top()
	sel_map = clampi(GameData.current_map, 0, GameData.MAPS.size() - 1)
	if not Save.is_map_unlocked(sel_map):
		sel_map = 0
	Save.changed.connect(_refresh_currency)
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(_refresh_badges)
	add_child(timer)
	show_tab("maps")
	_refresh_currency()


func _ready_overlay() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UIKit.apply_theme(self)
	content = Control.new()
	content.visible = false
	add_child(content)
	_build_top()
	sel_map = clampi(GameData.current_map, 0, GameData.MAPS.size() - 1)
	Save.changed.connect(_refresh_currency)
	_refresh_currency()


## Abre una sección (en modo superpuesto, desde la batalla).
func open_side(id: String) -> void:
	# Todo lo que se añada a partir de aquí (la hoja o ventanas emergentes) mantiene abierto el menú
	var base := get_child_count()
	_nav_pressed(id)
	_overlay_base = base


func _process(_delta: float) -> void:
	# Superpuesto: cuando ya no queda ninguna hoja ni ventana abierta, volver a la batalla.
	if overlay and _overlay_base > 0 and (sheet == null or not is_instance_valid(sheet)) and get_child_count() <= _overlay_base:
		_overlay_base = 0
		overlay_closed.emit()
		queue_free()


func _unhandled_input(event: InputEvent) -> void:
	# Escape cierra la ventana abierta
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if sheet != null and is_instance_valid(sheet):
			_close_sheet()
			get_viewport().set_input_as_handled()


## Cuántos avisos tiene cada acceso (también los usa la batalla).
static func side_badge(id: String) -> int:
	match id:
		"achievements": return Meta.claimable_achievements()
		"packs": return Meta.pending_packs().size()
	return 0


# ================================================================ Barra superior
var _top_bar: Control


func _build_top() -> void:
	var top := PanelContainer.new()
	var s := UIKit.card_style(Color(UIKit.NAVY, 0.96), Color(0.36, 0.5, 0.75), 28, 6, 8)
	s.border_color = UIKit.NAVY_DARK
	s.border_width_top = 2
	s.border_width_left = 2
	s.border_width_right = 2
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 12
	top.add_theme_stylebox_override("panel", s)
	top.position = Vector2(16, 10)
	top.size = Vector2(W - 32.0, 100)
	top.custom_minimum_size = Vector2(W - 32.0, 100)
	add_child(top)
	_top_bar = top
	var row := UIKit.hbox(14)
	top.add_child(row)
	crest = LevelCrest.new()
	crest.custom_minimum_size = Vector2(80, 80)
	crest.mouse_filter = Control.MOUSE_FILTER_STOP
	crest.tooltip_text = "Nivel de cuenta"
	UIKit.add_press_bounce(crest)
	crest.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_level_info())
	row.add_child(crest)
	var name_box := UIKit.hbox(10)
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_box.add_child(UIKit.label("PUKIBA", 34, UIKit.GOLD))
	name_box.add_child(UIKit.label("Tower Defense", 26, Color(1.0, 0.92, 0.7)))
	row.add_child(name_box)
	row.add_child(UIKit.spacer())
	var coin_pill := UIKit.pill("coin", "0", 28, Color.WHITE, 220)
	coin_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_pill.tooltip_text = "Oro: se gana en las partidas y sirve para todo"
	lbl_coins = coin_pill.get_meta("label")
	row.add_child(coin_pill)
	var settings := UIKit.icon_button("gear", UIKit.WOOD, 68, 0.62)
	settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings.tooltip_text = "Configuración"
	settings.pressed.connect(_open_settings)
	row.add_child(settings)
	if overlay:
		var back := UIKit.button("Volver a la batalla", UIKit.GREEN, 22, Vector2(260, 68))
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		back.pressed.connect(_close_sheet)
		row.add_child(back)


# ================================================================ Navegación (izquierda)
func _build_nav() -> void:
	var panel := PanelContainer.new()
	var s := UIKit.card_style(Color(UIKit.NAVY, 0.94), UIKit.NAVY_DARK, 26, 6, 10)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", s)
	panel.position = Vector2(16, TOP_H)
	panel.custom_minimum_size = Vector2(NAV_W - 8.0, H - TOP_H - 16.0)
	add_child(panel)
	nav_col = UIKit.vbox(8)
	panel.add_child(nav_col)
	for it in NAV:
		nav_col.add_child(_nav_item(it[0], it[1], it[2], it[3]))
	# Sobres pendientes (premios de nivel): solo aparece si hay alguno
	nav_col.add_child(_nav_item("packs", "Abrir sobre", "gift", Color(0.95, 0.35, 0.45)))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_col.add_child(sp)
	var quit := _nav_item("quit", "Salir", "close", UIKit.RED)
	nav_col.add_child(quit)


func _nav_item(id: String, text: String, icon: String, col: Color) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(NAV_W - 32.0, 78)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void: _nav_pressed(id))
	holder.add_child(b)
	var h := UIKit.hbox(12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	b.add_child(h)
	var ic_bg := PanelContainer.new()
	ic_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic_bg.add_theme_stylebox_override("panel", UIKit.style(col, col.lightened(0.35), 16, 2))
	ic_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := UIIcon.make(icon, 44)
	ic_bg.add_child(ic)
	h.add_child(ic_bg)
	var l := UIKit.label(text, 23, Color.WHITE)
	l.add_theme_font_override("font", UIKit.font(true))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	UIKit.add_press_bounce(b)
	var d := {"button": b, "icon": ic_bg, "label": l, "holder": holder, "badge": null, "box": holder}
	tab_buttons[id] = d
	side_buttons[id] = d
	return holder


func _nav_pressed(id: String) -> void:
	match id:
		"packs":
			var cards := Meta.open_pending_pack()
			if not cards.is_empty():
				UIKit.show_pack_results(self, cards, _refresh_badges)
			_refresh_badges()
		"coop":
			_open_coop()
		"ranking":
			_open_ranking()
		"quit":
			get_tree().quit()
		_:
			show_tab(id)


func _set_badge(id: String, count: int, show_mark := false) -> void:
	if not tab_buttons.has(id):
		return
	var d: Dictionary = tab_buttons[id]
	var holder: Control = d["holder"]
	var old: Control = d["badge"]
	var visible_now := count > 0 or show_mark
	if old != null and is_instance_valid(old):
		if visible_now and int(old.get_meta("count")) == count:
			return
		old.queue_free()
		d["badge"] = null
	if not visible_now:
		return
	var bd := UIKit.badge(count)
	bd.set_meta("count", count)
	bd.position = Vector2(holder.custom_minimum_size.x - 40, 4)
	holder.add_child(bd)
	UIKit.pop_in(bd, 0.05, 0.2)
	d["badge"] = bd


func _refresh_badges() -> void:
	if nav_col == null:
		return
	_set_badge("achievements", Meta.claimable_achievements())
	var pend := Meta.pending_packs().size()
	tab_buttons["packs"]["holder"].visible = pend > 0
	_set_badge("packs", pend)
	_set_badge("cards", _cards_levelable())
	if crest != null:
		crest.queue_redraw()


func _cards_levelable() -> int:
	var n := 0
	for id in GameData.all_card_ids():
		if Meta.can_level_card(id):
			n += 1
	return n


func _style_nav() -> void:
	for t in NAV:
		var d: Dictionary = tab_buttons[t[0]]
		var b: Button = d["button"]
		var sel: bool = t[0] == current_tab or t[0] == sheet_id
		var st: StyleBox
		if sel:
			var sb := UIKit.style(UIKit.GOLD, UIKit.GOLD.lightened(0.5), 20, 3)
			sb.border_width_bottom = 6
			sb.border_color = Color(0.82, 0.55, 0.12)
			st = sb
		else:
			var sb2 := UIKit.style(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.0), 20, 0)
			st = sb2
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("pressed", st)
		var hov := (st as StyleBoxFlat).duplicate() as StyleBoxFlat
		hov.bg_color = hov.bg_color.lightened(0.15) if sel else Color(1, 1, 1, 0.14)
		b.add_theme_stylebox_override("hover", hov)
		var l: Label = d["label"]
		l.add_theme_color_override("font_color", Color.WHITE if sel else Color(0.85, 0.9, 1.0))
		l.add_theme_color_override("font_outline_color", Color(0.55, 0.32, 0.05) if sel else UIKit.NAVY_DARK)


# ================================================================ Oro
func _refresh_currency() -> void:
	if lbl_coins == null:
		return
	var c := Save.coins()
	lbl_coins.text = GameData.format_num(c)
	if _last_coins >= 0 and c != _last_coins:
		UIKit.pop(lbl_coins.get_parent() as Control, 1.2)
	_last_coins = c
	_refresh_badges()


# ================================================================ Navegación
func show_tab(id: String) -> void:
	if overlay and not id in SHEETS:
		_close_sheet() # en batalla no se cambia de pestaña del menú: se vuelve a la partida
		return
	if id in SHEETS:
		var titles := {"collection": "Colección", "shop": "Tienda de sobres", "achievements": "Logros"}
		var icons := {"collection": "cards", "shop": "chest", "achievements": "trophy"}
		var sv := _open_sheet(id, titles[id], icons[id])
		match id:
			"shop": _tab_shop(sv)
			"achievements": _tab_achievements(sv)
			"collection": _collection_view(sv, true)
		_refresh_currency()
		if not overlay:
			_style_nav()
		return
	_close_sheet()
	current_tab = id
	for c in content.get_children():
		c.queue_free()
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 16
	UIKit.drag_anywhere(scroll) # se arrastra desde cualquier punto, también sobre botones y cartas
	scroll.size = content.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(margin)
	var v := UIKit.vbox(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(v)
	match id:
		"maps": _tab_maps(v)
		"upgrades": _tab_upgrades(v)
		"cards": _tab_cards(v)
	UIKit.fade_in(scroll, 0.2)
	_style_nav()
	_refresh_currency()


## Ventana emergente (tienda, logros...). Devuelve el contenedor donde construir.
func _open_sheet(id: String, title: String, icon: String) -> VBoxContainer:
	var animate := sheet == null or not is_instance_valid(sheet) or sheet_id != id
	var keep_scroll := 0
	if sheet != null and is_instance_valid(sheet):
		if sheet_id == id:
			keep_scroll = (sheet.get_meta("scroll") as ScrollContainer).scroll_vertical
		sheet.queue_free()
	sheet_id = id
	sheet = Control.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	if _top_bar != null and is_instance_valid(_top_bar):
		move_child(_top_bar, -1) # la barra de arriba (oro, ajustes) siempre encima y tocable
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.16, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_sheet())
	sheet.add_child(dim)
	var p := PanelContainer.new()
	var ps := UIKit.card_style(UIKit.CREAM, UIKit.CREAM_DARK, 30, 8, 16)
	ps.border_width_left = 4
	ps.border_width_right = 4
	ps.border_width_top = 4
	ps.content_margin_left = 18
	ps.content_margin_right = 18
	ps.content_margin_top = 12
	ps.content_margin_bottom = 14
	ps.shadow_color = Color(0, 0, 0, 0.45)
	p.add_theme_stylebox_override("panel", ps)
	p.position = Vector2((W - SHEET_W) * 0.5 + (NAV_W * 0.5 if not overlay else 0.0), TOP_H)
	p.custom_minimum_size = Vector2(SHEET_W, SHEET_MAX_H)
	p.size = p.custom_minimum_size
	sheet.add_child(p)
	var v := UIKit.vbox(10)
	p.add_child(v)
	# Cabecera: icono + título + cerrar
	var head := UIKit.hbox(10)
	v.add_child(head)
	head.add_child(UIIcon.make(icon, 52))
	var tl := UIKit.ink(title, 32, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var close := UIKit.icon_button("close", UIKit.RED, 60, 0.5)
	close.tooltip_text = "Cerrar (Esc)"
	close.pressed.connect(_close_sheet)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 16
	UIKit.drag_anywhere(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	sheet.set_meta("scroll", scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	scroll.add_child(margin)
	var body := UIKit.vbox(12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(body)
	sheet.set_meta("panel", p)
	sheet.set_meta("body", body)
	if animate:
		sheet.modulate.a = 0.0
	_fit_sheet.call_deferred(sheet, animate)
	if not animate and keep_scroll > 0:
		var restore := func() -> void:
			if is_instance_valid(scroll):
				scroll.scroll_vertical = keep_scroll
		restore.call_deferred()
	return body


## Ajusta la altura de la ventana a su contenido (con animación de entrada).
func _fit_sheet(sh: Control, animate: bool) -> void:
	if not is_instance_valid(sh):
		return
	var p: PanelContainer = sh.get_meta("panel")
	var body: Control = sh.get_meta("body")
	var h := clampf(body.get_combined_minimum_size().y + 130.0, 420.0, SHEET_MAX_H)
	p.custom_minimum_size.y = h
	p.size.y = h
	var y := TOP_H + (SHEET_MAX_H - h) * 0.5
	if not animate:
		p.position.y = y
		return
	p.position.y = y + 60.0
	var tw := sh.create_tween()
	tw.tween_property(sh, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(p, "position:y", y, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_sheet() -> void:
	if sheet != null and is_instance_valid(sheet):
		var s := sheet
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := s.create_tween()
		tw.tween_property(s, "modulate:a", 0.0, 0.12)
		tw.tween_callback(s.queue_free)
	sheet = null
	sheet_id = ""
	_refresh_badges()
	if not overlay and nav_col != null:
		_style_nav()


func _btn(text: String, color: Color, fs: int, min_size: Vector2, cb: Callable) -> Button:
	var b := UIKit.button(text, color, fs, min_size)
	b.mouse_filter = Control.MOUSE_FILTER_PASS # permite arrastrar el scroll
	b.pressed.connect(cb)
	return b


## Botón con icono + texto.
func _ibtn(icon: String, text: String, color: Color, fs: int, min_size: Vector2, cb: Callable, icon_px := 30.0) -> Button:
	var b := _btn("", color, fs, min_size, cb)
	UIKit.set_button_content(b, icon, text, fs, icon_px)
	return b


func _section(v: VBoxContainer, text: String, icon := "", on_light := true) -> void:
	var h := UIKit.hbox(8)
	if icon != "":
		h.add_child(UIIcon.make(icon, 34))
	h.add_child(UIKit.ink(text, 26, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true) if on_light else UIKit.label(text, 26, UIKit.GOLD))
	v.add_child(h)


func _wrap(l: Label, w: float) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	return l


func _reward_icon(r: Dictionary) -> String:
	if r.has("pack"):
		return "cards"
	return "coin"


# ================================================================ Mapas (pantalla principal)
func _tab_maps(v: VBoxContainer) -> void:
	v.add_child(_map_card(sel_map))
	v.add_child(_hero_card())


func _map_card(i: int) -> Control:
	var m: Dictionary = GameData.MAPS[i]
	var unlocked := Save.is_map_unlocked(i)
	var p := UIKit.card()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := UIKit.vbox(10)
	p.add_child(v)
	# Cabecera con flechas para cambiar de mapa
	var head := UIKit.hbox(8)
	v.add_child(head)
	var prev_b := UIKit.icon_button("arrow_l", UIKit.TEAL, 64, 0.5)
	prev_b.disabled = i <= 0
	prev_b.pressed.connect(func() -> void: _change_map(-1))
	head.add_child(prev_b)
	var tv := UIKit.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UIKit.ink("MAPA %d DE %d" % [i + 1, GameData.MAPS.size()], 15, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, true))
	tv.add_child(UIKit.ink(m["name"], 28, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	head.add_child(tv)
	var next_b := UIKit.icon_button("arrow_r", UIKit.TEAL, 64, 0.5)
	next_b.disabled = i >= GameData.MAPS.size() - 1
	next_b.pressed.connect(func() -> void: _change_map(1))
	head.add_child(next_b)
	# Vista previa
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(0, 480)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(frame)
	var prev := MapPreview.new()
	prev.map_idx = i
	prev.set_anchors_preset(Control.PRESET_FULL_RECT)
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		prev.modulate = Color(0.45, 0.45, 0.5)
	frame.add_child(prev)
	var best := Save.best_wave(i)
	if unlocked:
		var diff := UIKit.pill("skull", "x%.1f" % GameData.map_difficulty(i), 18, Color.WHITE)
		diff.position = Vector2(10, 10)
		frame.add_child(diff)
		var rec := UIKit.pill("trophy", "Récord %d" % best, 18, Color.WHITE)
		rec.position = Vector2(10, 58)
		frame.add_child(rec)
	else:
		var lk := UIIcon.make("lock", 110)
		lk.anchor_left = 0.5
		lk.anchor_right = 0.5
		lk.anchor_top = 0.5
		lk.anchor_bottom = 0.5
		lk.offset_left = -55
		lk.offset_right = 55
		lk.offset_top = -55
		lk.offset_bottom = 55
		frame.add_child(lk)
	if unlocked:
		var target := GameData.UNLOCK_WAVE
		var h := UIKit.hbox(8)
		h.add_child(UIIcon.make("flag", 34))
		var bar := UIKit.progress(mini(best, target), target, UIKit.GOLD, 28, "Oleada %d / %d" % [mini(best, target), target])
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		v.add_child(h)
		# Solo se muestran los enemigos ya descubiertos; el resto queda como "???"
		var enemies_names: Array = []
		var unknown := 0
		for k in m["roster"].size():
			if Save.best_wave(i) + 1 >= GameData.enemy_intro_wave(k):
				enemies_names.append(GameData.ENEMIES[m["roster"][k]]["name"])
			else:
				unknown += 1
		var etxt := "Enemigos: " + ", ".join(enemies_names)
		if unknown > 0:
			etxt += "  ·  %d por descubrir" % unknown
		v.add_child(_wrap(UIKit.ink(etxt, 15, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 520))
		var run := Save.get_run(i)
		if run.is_empty():
			v.add_child(_ibtn("play", "JUGAR", UIKit.GREEN, 34, Vector2(0, 92), func() -> void: _play(i), 40))
		else:
			v.add_child(_ibtn("play", "CONTINUAR · Oleada %d" % int(run["wave"]), UIKit.GREEN, 28, Vector2(0, 92), func() -> void: _play(i), 36))
			var nb := _btn("Nueva partida", UIKit.WOOD, 18, Vector2(240, 56), func() -> void:
				UIKit.popup(self, "¿Nueva partida?", UIKit.label("Perderás la partida guardada en la oleada %d." % int(run["wave"]), 20, UIKit.PARCHMENT), [
					["Sí, empezar", func() -> void:
						Save.set_run(i, {})
						_play(i), UIKit.RED],
					["Cancelar", Callable(), UIKit.GREY]]))
			nb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(nb)
	else:
		v.add_child(_wrap(UIKit.ink("Sobrevive hasta la oleada %d en %s para desbloquearlo." % [GameData.UNLOCK_WAVE, GameData.MAPS[i - 1]["name"]], 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER), 520))
		if Save.is_map_unlocked(i - 1):
			var pb := mini(Save.best_wave(i - 1), GameData.UNLOCK_WAVE)
			v.add_child(UIKit.progress(pb, GameData.UNLOCK_WAVE, UIKit.TEAL, 28, "%d / %d" % [pb, GameData.UNLOCK_WAVE]))
		var lb := _ibtn("lock", "BLOQUEADO", UIKit.GREY, 28, Vector2(0, 80), func() -> void: pass, 34)
		lb.disabled = true
		v.add_child(lb)
	return p


func _change_map(d: int) -> void:
	sel_map = clampi(sel_map + d, 0, GameData.MAPS.size() - 1)
	show_tab("maps")


func _hero_card() -> Control:
	var hero_id: String = Save.data["selected_hero"]
	var p := UIKit.card(UIKit.CREAM)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := UIKit.hbox(12)
	p.add_child(row)
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := UIKit.style(Color(0.75, 0.86, 0.95), UIKit.TEAL, 44, 4)
	fs.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", fs)
	var icon := CardIcon.new()
	icon.card_id = hero_id
	icon.custom_minimum_size = Vector2(88, 88)
	frame.add_child(icon)
	row.add_child(frame)
	var info := UIKit.vbox(0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(UIKit.ink("TU HÉROE", 14, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true))
	info.add_child(UIKit.ink(GameData.HEROES[hero_id]["name"], 24, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	if Save.owns(hero_id):
		info.add_child(UIKit.ink(GameData.HEROES[hero_id]["title"], 15, UIKit.INK_SOFT))
	else:
		info.add_child(UIKit.ink("Consigue héroes en los sobres de héroes de la Tienda", 15, UIKit.RED.darkened(0.2), HORIZONTAL_ALIGNMENT_LEFT, true))
	row.add_child(info)
	var b := _btn("Cambiar", UIKit.PURPLE, 19, Vector2(126, 64), func() -> void: show_tab("cards"))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	return p


func _play(i: int) -> void:
	GameData.current_map = i
	get_tree().change_scene_to_file("res://scenes/game.tscn")


# ================================================================ Mejoras globales
const UPGRADE_ICONS := {"damage": "sword", "range": "range", "speed": "bolt", "start_gold": "coin_bag", "lives": "heart",
	"gold_kill": "coin", "crit": "target", "discount": "hammer", "hero": "crown", "coins": "chest"}


func _tab_upgrades(v: VBoxContainer) -> void:
	v.add_child(UIKit.label("La Fortaleza", 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_castle_view())
	v.add_child(UIKit.label("Mejoras permanentes para todos los mapas", 17, UIKit.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER))
	for id in GameData.UPGRADES.keys():
		var def: Dictionary = GameData.UPGRADES[id]
		var lvl := Save.upgrade_level(id)
		var maxl := Meta.upgrade_cap(id)
		var hard_max := int(def["max"])
		var p := UIKit.card()
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		var row := UIKit.hbox(12)
		p.add_child(row)
		var ic_frame := PanelContainer.new()
		ic_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fs := UIKit.style(UIKit.CREAM_SOFT, UIKit.CREAM_DARK, 18, 2)
		fs.set_content_margin_all(8)
		ic_frame.add_theme_stylebox_override("panel", fs)
		ic_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic_frame.add_child(UIIcon.make(UPGRADE_ICONS.get(id, "star"), 52))
		row.add_child(ic_frame)
		var info := UIKit.vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UIKit.hbox(8)
		t.add_child(UIKit.ink(def["name"], 22, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
		t.add_child(UIKit.ink("Nv. %d/%d" % [lvl, maxl], 16, UIKit.AMBER, HORIZONTAL_ALIGNMENT_LEFT, true))
		info.add_child(t)
		info.add_child(UIKit.ink(def["desc"], 16, UIKit.INK_SOFT))
		info.add_child(UIKit.progress(lvl, maxl, UIKit.GREEN, 14))
		row.add_child(info)
		if lvl >= maxl and lvl < hard_max:
			info.add_child(UIKit.ink("Desbloquea más mapas para subir el límite", 14, UIKit.RED, HORIZONTAL_ALIGNMENT_LEFT, true))
		if lvl >= maxl:
			var mx := UIKit.ribbon("MÁX" if lvl >= hard_max else "LÍMITE", UIKit.AMBER, 20)
			mx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mx)
		else:
			var cost := Meta.upgrade_cost(id)
			var b := _ibtn("coin", GameData.format_num(cost), UIKit.GREEN if Save.coins() >= cost else UIKit.RED, 21, Vector2(150, 68), func() -> void:
				if Meta.buy_upgrade(id):
					show_tab("upgrades")
				else:
					_not_enough_coins(), 28)
			UIKit.set_button_content(b, "coin", GameData.format_num(cost), 21, 28)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		v.add_child(p)
	_gem_upgrades_section(v)
	_tower_train_section(v)


## Mejoras especiales (al final de la pestaña Fortaleza): más caras y más potentes.
func _gem_upgrades_section(v: VBoxContainer) -> void:
	_section(v, "Mejoras especiales", "crown", false)
	v.add_child(UIKit.label("Exclusivas y permanentes para todos los mapas", 16, UIKit.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER))
	for id in GameData.GEM_UPGRADES.keys():
		var def: Dictionary = GameData.GEM_UPGRADES[id]
		var lvl := Save.gem_upgrade_level(id)
		var maxl := int(def["max"])
		var p := UIKit.card(Color(0.9, 0.94, 1.0))
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		var row := UIKit.hbox(12)
		p.add_child(row)
		var ic := UIIcon.make(def.get("icon", "star"), 52)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var info := UIKit.vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UIKit.hbox(8)
		t.add_child(UIKit.ink(def["name"], 21, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
		t.add_child(UIKit.ink("Nv. %d/%d" % [lvl, maxl], 16, UIKit.BLUE.darkened(0.2), HORIZONTAL_ALIGNMENT_LEFT, true))
		info.add_child(t)
		info.add_child(UIKit.ink(def["desc"], 15, UIKit.INK_SOFT))
		info.add_child(UIKit.progress(lvl, maxl, UIKit.BLUE, 12))
		row.add_child(info)
		if lvl >= maxl:
			var mx := UIKit.ribbon("MÁX", UIKit.BLUE, 20)
			mx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mx)
		else:
			var cost := Meta.gem_upgrade_cost(id)
			var b := _ibtn("coin", GameData.format_num(cost), UIKit.GREEN if Save.coins() >= cost else UIKit.RED, 21, Vector2(170, 68), func() -> void:
				if Meta.buy_gem_upgrade(id):
					show_tab("upgrades")
				else:
					_not_enough_coins(), 28)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		v.add_child(p)


## Entrenamiento de torres con oro: cada torre empieza en un nivel más alto en todos los mapas.
func _tower_train_section(v: VBoxContainer) -> void:
	_section(v, "Entrenamiento de torres", "upgrade", false)
	v.add_child(UIKit.label("Sube con gemas el nivel con el que se construye cada torre de oro (en todos los mapas).\nLas torres de cartas suben juntando cartas.", 16, UIKit.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER))
	var ids: Array = GameData.TOWERS.keys().filter(func(tid): return Meta.is_progress_tower(tid))
	ids.sort_custom(func(a, b) -> bool: return Meta.tower_available(a) and not Meta.tower_available(b))
	for id in ids:
		var def: Dictionary = GameData.TOWERS[id]
		var avail := Meta.tower_available(id)
		var lvl := Save.tower_train_level(id)
		var maxl := GameData.TOWER_TRAIN_MAX
		var p := UIKit.card(Color(0.95, 0.9, 1.0))
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		var row := UIKit.hbox(12)
		p.add_child(row)
		var icon := CardIcon.new()
		icon.card_id = id
		icon.level = 2
		icon.lit = avail
		icon.custom_minimum_size = Vector2(80, 70)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var info := UIKit.vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UIKit.hbox(8)
		t.add_child(UIKit.ink(def["name"], 19, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
		t.add_child(UIKit.ink("Nv. %d/%d" % [lvl, maxl], 16, UIKit.PURPLE.darkened(0.2), HORIZONTAL_ALIGNMENT_LEFT, true))
		info.add_child(t)
		info.add_child(UIKit.ink("Se construye en nivel %d" % Meta.tower_start_level(id) if avail else (Meta.unlock_text(id) if Meta.is_progress_tower(id) else "Consíguela en los sobres"), 15, UIKit.INK_SOFT))
		info.add_child(UIKit.progress(lvl, maxl, UIKit.PURPLE, 12))
		row.add_child(info)
		if lvl >= maxl:
			var mx := UIKit.ribbon("MÁX", UIKit.PURPLE, 20)
			mx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mx)
		elif avail:
			var cost := Meta.tower_train_cost(id)
			var b := _ibtn("coin", GameData.format_num(cost), UIKit.GREEN if Save.coins() >= cost else UIKit.RED, 21, Vector2(170, 68), func() -> void:
				if Meta.buy_tower_train(id):
					show_tab("upgrades")
				else:
					_not_enough_coins(), 28)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		v.add_child(p)


func _not_enough_coins() -> void:
	UIKit.popup(self, "Oro insuficiente", UIKit.label("Juega más oleadas para ganar oro: cada enemigo, oleada y jefe te da más.", 20, UIKit.PARCHMENT), [
		["Cerrar", Callable(), UIKit.GREY]])


# ================================================================ Cartas / Colección
var _coll_filter := "all" # all | heroes | towers | missing
var _pack_qty := {} # sobre -> cantidad elegida (1, 5 o 10) en la Tienda


## Resumen al abrir varios sobres de golpe (x5, x10): cada carta una vez con cuántas copias
## salieron, de la más rara a la más común. Las que se desbloquean ahora llevan "¡NUEVA!".
func _multi_pack_results(cards: Array, qty: int, pack_name: String) -> void:
	if cards.is_empty():
		return
	var count := {}
	var is_new := {}
	var order: Array = []
	for r in cards:
		var id: String = r["id"]
		if not count.has(id):
			order.append(id)
			count[id] = 0
		count[id] = int(count[id]) + 1
		if bool(r.get("new", false)):
			is_new[id] = true
	order = GameData.sort_by_rarity(order)
	order.reverse() # las más raras primero
	var v := UIKit.vbox(10)
	v.add_child(UIKit.ink("%d x %s · %d cartas" % [qty, pack_name, cards.size()], 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1100, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UIKit.drag_anywhere(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	v.add_child(scroll)
	for id in order:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(150, 186)
		var w := UIKit.card_widget(id, is_new.has(id))
		w.custom_minimum_size = Vector2(150, 186)
		holder.add_child(w)
		var badge := UIKit.ribbon("x%d" % int(count[id]), UIKit.ORANGE, 15)
		badge.position = Vector2(104, -8)
		holder.add_child(badge)
		grid.add_child(holder)
	Audio.sfx("coin", -2.0, 0.0)
	UIKit.popup(self, "¡Sobres abiertos!", v, [["¡Genial!", func() -> void: show_tab("shop"), UIKit.GREEN]], 1160)


func _tab_cards(v: VBoxContainer) -> void:
	_collection_view(v, false)


## Vuelve a dibujar la colección donde esté abierta (hoja de la columna o pestaña Cartas).
func _refresh_cards_view() -> void:
	if sheet_id == "collection":
		show_tab("collection")
	elif not overlay:
		show_tab("cards")
	_refresh_badges()


## Colección de cartas: resumen, filtros y cuadrícula. `on_light` = dentro de una hoja crema.
func _collection_view(v: VBoxContainer, on_light: bool) -> void:
	var txt_col: Color = UIKit.INK if on_light else UIKit.PARCHMENT
	var all_ids: Array = GameData.all_card_ids()
	var owned_n := 0
	for id in all_ids:
		if Save.owns(id):
			owned_n += 1
	if not on_light:
		v.add_child(UIKit.label("Colección", 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	# Resumen: cuántas tienes, por rareza
	v.add_child(UIKit.progress(owned_n, all_ids.size(), UIKit.GREEN, 28, "Tienes %d de %d cartas" % [owned_n, all_ids.size()]))
	var rar_row := UIKit.hbox(6)
	rar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for r in GameData.RARITY_ORDER:
		var tot := 0
		var have := 0
		for id in all_ids:
			if GameData.card_def(id)["rarity"] == r:
				tot += 1
				if Save.owns(id):
					have += 1
		if tot == 0:
			continue
		var rc: Color = GameData.RARITIES[r]["color"]
		rar_row.add_child(UIKit.pill("star", "%d/%d" % [have, tot], 15, rc.lightened(0.3), 0, Color(0.05, 0.08, 0.18, 0.75)))
	v.add_child(rar_row)
	v.add_child(_wrap(UIKit.ink("Toca una carta para ver sus datos, subirla de nivel o elegir tu héroe. Las copias de los sobres suben su nivel (+10% de poder por nivel).", 16, txt_col, HORIZONTAL_ALIGNMENT_CENTER) if on_light else UIKit.label("Toca una carta para ver sus datos, subirla de nivel o elegir tu héroe. Las copias de los sobres suben su nivel (+10% de poder por nivel).", 16, txt_col, HORIZONTAL_ALIGNMENT_CENTER), 1000))
	# Filtros
	var filters := UIKit.hbox(8)
	filters.alignment = BoxContainer.ALIGNMENT_CENTER
	for f in [["all", "Todas"], ["heroes", "Héroes"], ["towers", "Torres"], ["missing", "Me faltan"]]:
		var fid: String = f[0]
		var b := _btn(f[1], UIKit.TEAL if _coll_filter == fid else UIKit.GREY, 18, Vector2(140, 54), func() -> void:
			_coll_filter = fid
			_refresh_cards_view())
		filters.add_child(b)
	v.add_child(filters)
	var cw := 150.0 if on_light else 163.0
	var ch := 186.0 if on_light else 200.0
	var sections: Array = []
	if _coll_filter != "towers":
		sections.append(["Héroes", GameData.HEROES.keys(), "crown"])
	if _coll_filter != "heroes":
		sections.append(["Torres", GameData.TOWERS.keys(), "castle"])
	for section in sections:
		var ids: Array = section[1].duplicate()
		if _coll_filter == "missing":
			ids = ids.filter(func(id) -> bool: return not Save.owns(id))
		# Por color de rareza (común → legendaria); dentro de cada una, primero las que tienes
		ids = GameData.sort_by_rarity(ids, true)
		var have := 0
		for id in section[1]:
			if Save.owns(id):
				have += 1
		var h := UIKit.hbox(8)
		h.add_child(UIIcon.make(section[2], 36))
		var title := "%s  (%d/%d)" % [section[0], have, section[1].size()]
		h.add_child(UIKit.ink(title, 26, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true) if on_light else UIKit.label(title, 26, UIKit.GOLD))
		v.add_child(h)
		if ids.is_empty():
			v.add_child(UIKit.ink("¡Las tienes todas!", 18, UIKit.GREEN.darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER, true) if on_light else UIKit.label("¡Las tienes todas!", 18, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER))
			continue
		var grid := GridContainer.new()
		grid.columns = 7 if on_light else 8
		grid.add_theme_constant_override("h_separation", 8 if on_light else 10)
		grid.add_theme_constant_override("v_separation", 12)
		v.add_child(grid)
		for id in ids:
			var w := UIKit.card_widget(id, false, true)
			w.custom_minimum_size = Vector2(cw, ch)
			w.mouse_filter = Control.MOUSE_FILTER_PASS
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(cw, ch)
			holder.mouse_filter = Control.MOUSE_FILTER_PASS
			holder.add_child(w)
			if id == Save.data["selected_hero"] and Save.owns(id):
				var sel := UIKit.ribbon("EN USO", UIKit.TEAL, 13)
				sel.position = Vector2(cw * 0.5 - 42, -8)
				holder.add_child(sel)
			if Meta.can_level_card(id):
				var up := UIIcon.make("upgrade", 38)
				up.position = Vector2(cw - 38, -10)
				holder.add_child(up)
				UIKit.pulse(up, 1.15, 0.9)
			_make_tappable(holder, func() -> void: _card_detail(id))
			grid.add_child(holder)


func _make_tappable(c: Control, cb: Callable) -> void:
	var state := {"start": Vector2.ZERO}
	c.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				state["start"] = ev.global_position
				c.pivot_offset = c.size * 0.5
				c.scale = Vector2(0.95, 0.95)
			else:
				var tw := c.create_tween()
				tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				if ev.global_position.distance_to(state["start"]) < 12.0:
					cb.call())


func _card_detail(id: String) -> void:
	var def := GameData.card_def(id)
	var c := Save.card(id)
	var lvl := int(c["level"])
	var v := UIKit.vbox(10)
	var row := UIKit.hbox(16)
	v.add_child(row)
	row.add_child(UIKit.card_widget(id, false, true))
	var info := UIKit.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	if GameData.is_hero(id):
		info.add_child(UIKit.ink(def["title"], 18, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true))
		info.add_child(_wrap(UIKit.ink("%s: %s" % [def["ability_name"], def["ability_desc"]], 17), 440))
		info.add_child(UIKit.icon_label("bolt", "Recarga %ds" % int(def["cooldown"]), 17, UIKit.INK, 24, true))
	else:
		info.add_child(_wrap(UIKit.ink(def["desc"], 17), 440))
		info.add_child(_wrap(UIKit.ink(def["perk_desc"], 16, UIKit.INK_SOFT), 440))
		info.add_child(UIKit.icon_label("coin", "%d oro" % int(def["cost"]), 17, UIKit.INK, 24, true))
	if float(def.get("damage", 0.0)) > 0.0:
		var stats := UIKit.hbox(14)
		stats.add_child(UIKit.icon_label("sword", "%.0f" % (float(def["damage"]) * Meta.card_power(id)), 18, UIKit.INK, 26, true))
		stats.add_child(UIKit.icon_label("range", "%.1f" % float(def["range"]), 18, UIKit.INK, 26, true))
		stats.add_child(UIKit.icon_label("bolt", "%.2f/s" % float(def["rate"]), 18, UIKit.INK, 26, true))
		info.add_child(stats)
		info.add_child(UIKit.ink("Daño: " + GameData.DAMAGE_TYPES[def["dmg_type"]]["name"], 15, UIKit.INK_SOFT))
	if lvl > 0:
		v.add_child(UIKit.ink("Nivel de carta %d/%d  ·  Poder +%d%%" % [lvl, GameData.MAX_CARD_LEVEL, int(round((Meta.card_power(id) - 1.0) * 100))], 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
		if lvl < GameData.MAX_CARD_LEVEL:
			var need := Meta.copies_needed(lvl)
			v.add_child(UIKit.progress(mini(int(c["copies"]), need), need, UIKit.GREEN, 26, "Copias %d / %d" % [int(c["copies"]), need]))
	else:
		v.add_child(UIKit.icon_label("lock", "Bloqueada: consíguela en sobres.", 18, UIKit.INK, 26, true))
	var buttons: Array = []
	if lvl > 0 and lvl < GameData.MAX_CARD_LEVEL:
		var cost := Meta.card_upgrade_cost(lvl)
		buttons.append(["Subir nivel\n%s oro" % GameData.format_num(cost), func() -> void:
			if Meta.level_card(id):
				UIKit.toast(self, "¡%s sube a nivel %d!" % [def["name"], lvl + 1])
				_refresh_cards_view()
			else:
				UIKit.message(self, "No es posible", "Necesitas %d copias y %s oro." % [Meta.copies_needed(lvl), GameData.format_num(cost)]), UIKit.GREEN])
	if GameData.is_hero(id) and lvl > 0 and Save.hero_level(id) < GameData.HERO_MAX_LEVEL:
		var hc := Meta.hero_level_cost(id)
		buttons.append(["Nivel de héroe %d → %d
%s oro" % [Save.hero_level(id), Save.hero_level(id) + 1, GameData.format_num(hc)], func() -> void:
			if Meta.level_hero(id):
				UIKit.toast(self, "¡%s sube a nivel %d!" % [def["name"], Save.hero_level(id)], UIKit.GOLD)
				_refresh_cards_view()
			else:
				_not_enough_coins(), UIKit.GOLD])
	if GameData.is_hero(id) and lvl > 0 and Save.data["selected_hero"] != id:
		buttons.append(["Elegir héroe", func() -> void:
			Save.data["selected_hero"] = id
			Save.save_game()
			_refresh_cards_view(), UIKit.PURPLE])
	if lvl == 0:
		buttons.append(["Ver sobres", func() -> void: show_tab("shop"), UIKit.BLUE])
	buttons.append(["Cerrar", Callable(), UIKit.GREY])
	UIKit.popup(self, def["name"], v, buttons, 820)


# ================================================================ Tienda
func _tab_shop(v: VBoxContainer) -> void:
	v.add_child(_wrap(UIKit.ink("Las torres y los héroes solo se consiguen en sobres. Cómpralos con el oro que ganas defendiendo el reino: la primera copia desbloquea la carta y las siguientes la suben de nivel.", 17, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 1000))
	_packs_anchor = v
	# Sobres de torres y de héroes: bronce, plata y oro
	for kind in ["tower", "hero"]:
		_section(v, "Sobres de torres" if kind == "tower" else "Sobres de héroes", "castle" if kind == "tower" else "crown")
		v.add_child(_wrap(UIKit.ink("Solo torres: más baratos, para ampliar y mejorar tus defensas." if kind == "tower" else "Solo héroes: más caros, porque los héroes son pocos y muy poderosos.", 15, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 1000))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 18)
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(grid)
		for pid in GameData.SHOP_PACKS[kind]:
			grid.add_child(_pack_box(pid))
	var ob := _ibtn("info", "Probabilidades", UIKit.GREY, 17, Vector2(260, 56), _show_odds, 26)
	ob.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ob)


func _pack_box(pid: String) -> Control:
	var p: Dictionary = GameData.PACKS[pid]
	var pc: Color = p["color"]
	var box := UIKit.card(pc.lerp(Color.WHITE, 0.72))
	box.custom_minimum_size = Vector2(300, 0)
	var bv := UIKit.vbox(6)
	box.add_child(bv)
	var art_holder := CenterContainer.new()
	art_holder.custom_minimum_size = Vector2(0, 212)
	art_holder.add_child(PackOpening.pack_art(pid, Vector2(156, 208)))
	bv.add_child(art_holder)
	bv.add_child(UIKit.ink(p["name"], 21, pc.darkened(0.5), HORIZONTAL_ALIGNMENT_CENTER, true))
	var g := "1 %s+ seguro" % GameData.RARITIES[p["guarantee"]]["name"] if p["guarantee"] != "" else " "
	bv.add_child(UIKit.ink("%d cartas" % int(p["cards"]), 16, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	bv.add_child(UIKit.ink(g, 14, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bv.add_child(sp)
	var unit := Meta.pack_price(pid)
	# Cantidad: x1, x5 o x10 sobres de una vez (el precio del botón se actualiza)
	var state := {"qty": int(_pack_qty.get(pid, 1))}
	var buy: Button
	var qrow := UIKit.hbox(6)
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	var qbtns: Array = []
	for q in [1, 5, 10]:
		var qb := UIKit.button("x%d" % q, UIKit.GOLD if q == int(state["qty"]) else UIKit.GREY, 16, Vector2(70, 40))
		qb.mouse_filter = Control.MOUSE_FILTER_PASS
		qbtns.append(qb)
		qrow.add_child(qb)
	bv.add_child(qrow)
	buy = _ibtn("coin", GameData.format_num(unit * int(state["qty"])), UIKit.GREEN, 22, Vector2(0, 60), func() -> void:
		var qty := int(state["qty"])
		var price := unit * qty
		if Save.coins() < price:
			_not_enough_coins()
			return
		var cards := Meta.buy_packs(pid, qty)
		if qty == 1:
			UIKit.show_pack_results(self, cards, func() -> void: show_tab("shop"))
		else:
			_multi_pack_results(cards, qty, p["name"]), 28)
	bv.add_child(buy)
	for i in qbtns.size():
		var qv: int = [1, 5, 10][i]
		(qbtns[i] as Button).pressed.connect(func() -> void:
			state["qty"] = qv
			_pack_qty[pid] = qv
			for j in qbtns.size():
				UIKit.set_button_color(qbtns[j], UIKit.GOLD if j == i else UIKit.GREY)
			UIKit.set_button_content(buy, "coin", GameData.format_num(unit * qv), 22, 28))
	return box


func _pity_text() -> String:
	return "Garantías: Épica o mejor en %d cartas · Legendaria en %d cartas (la probabilidad sube desde la carta %d)" % [Meta.pity_left("epic"), Meta.pity_left("legendary"), GameData.SOFT_PITY_START]


func _show_odds() -> void:
	var v := UIKit.vbox(8)
	v.add_child(UIKit.ink("Probabilidad de rareza por carta:", 18, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	for pid in GameData.PACKS.keys():
		var p: Dictionary = GameData.PACKS[pid]
		var parts: Array = []
		for r in GameData.RARITY_ORDER:
			parts.append("%s %.1f%%" % [GameData.RARITIES[r]["name"], float(p["weights"][r])])
		var box := UIKit.inset()
		var bv := UIKit.vbox(2)
		box.add_child(bv)
		bv.add_child(UIKit.ink(p["name"], 17, (p["color"] as Color).darkened(0.45), HORIZONTAL_ALIGNMENT_LEFT, true))
		bv.add_child(_wrap(UIKit.ink(", ".join(parts), 15), 600))
		v.add_child(box)
	v.add_child(_wrap(UIKit.ink("Dentro de cada rareza todas las cartas tienen la misma probabilidad. Los sobres con garantía aseguran al menos una carta de esa rareza.", 15, UIKit.INK_SOFT), 620))
	v.add_child(_wrap(UIKit.ink(_pity_text(), 15, UIKit.PURPLE.darkened(0.3), HORIZONTAL_ALIGNMENT_LEFT, true), 620))
	UIKit.popup(self, "Probabilidades", v, [["Cerrar", Callable(), UIKit.GREY]], 820)



# ================================================================ Logros
func _tab_achievements(v: VBoxContainer) -> void:
	v.add_child(_wrap(UIKit.ink("Cada logro tiene varios niveles. ¡Reclama oro al completar cada uno!", 17, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 1000))
	for a in GameData.ACHIEVEMENTS:
		var ad: Dictionary = a
		var tiers: Array = ad["tiers"]
		var nxt := Meta.achievement_next(ad)
		var val := Meta.achievement_value(ad["id"])
		var done := nxt < 0
		var box := UIKit.card(UIKit.CREAM_SOFT if not done else Color(1.0, 0.92, 0.7))
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		var row := UIKit.hbox(12)
		box.add_child(row)
		var tv := UIKit.vbox(2)
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tv.add_child(UIIcon.make("trophy", 56))
		var stars := UIKit.hbox(-5)
		var claimed_n := tiers.size() if done else nxt
		for k in tiers.size():
			stars.add_child(UIIcon.make("star" if k < claimed_n else "star_off", 16))
		tv.add_child(stars)
		row.add_child(tv)
		var info := UIKit.vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.ink(ad["name"], 20, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
		var goal := int(tiers[tiers.size() - 1]) if done else int(tiers[nxt])
		info.add_child(UIKit.ink(ad["desc"] % GameData.format_num(goal), 15, UIKit.INK_SOFT))
		info.add_child(UIKit.progress(mini(val, goal), goal, UIKit.GOLD, 22, "%s / %s" % [GameData.format_num(mini(val, goal)), GameData.format_num(goal)]))
		row.add_child(info)
		if done:
			var mx := UIKit.ribbon("¡COMPLETO!", UIKit.AMBER, 14)
			mx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(mx)
		else:
			var reward := Meta.achievement_reward(ad)
			var b := _ibtn("coin", "+" + GameData.format_num(reward), UIKit.GREEN, 20, Vector2(150, 64), func() -> void:
				var got := Meta.claim_achievement(ad)
				if got > 0:
					UIKit.toast(self, "+%s oro" % GameData.format_num(got), UIKit.GOLD)
				show_tab("achievements"), 26)
			b.disabled = not Meta.can_claim_achievement(ad)
			UIKit.set_button_content(b, "coin", "+" + GameData.format_num(reward), 20, 26)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
			if not b.disabled:
				UIKit.pulse(b, 1.06)
		v.add_child(box)


# ================================================================ Nivel de cuenta
func _level_info() -> void:
	var lvl := int(Save.data["level"])
	var need := GameData.xp_to_next(lvl)
	var v := UIKit.vbox(10)
	v.add_child(UIKit.ink("Nivel de cuenta %d" % lvl, 26, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	v.add_child(UIKit.progress(int(Save.data["xp"]), need, UIKit.GOLD, 28, "%d / %d XP" % [int(Save.data["xp"]), need]))
	var r := GameData.level_reward(lvl + 1)
	var rl := UIKit.icon_label(_reward_icon(r), "Premio nivel %d: %s" % [lvl + 1, Meta.reward_text(r)], 18, UIKit.INK, 34, true)
	rl.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(rl)
	v.add_child(_wrap(UIKit.ink("Gana XP superando oleadas, derrotando jefes, construyendo y abriendo sobres.", 16, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 560))
	UIKit.popup(self, "Tu nivel", v, [["Genial", Callable(), UIKit.GREEN]], 620)


func _open_settings() -> void:
	SettingsPanel.open(self, false, func() -> void:
		Save.reset_all()
		show_tab("maps"))



# ================================================================ Cooperativo
func _open_coop() -> void:
	var sv := _open_sheet("coop", "Defensa cooperativa", "hero")
	sv.add_child(_wrap(UIKit.ink("Defended juntos un mapa entre 2 jugadores: cada uno construye en su mitad con su propio oro y las vidas son compartidas. Máximo 100 oleadas.", 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER), 1000))
	var rw := UIKit.card(Color(0.9, 0.96, 1.0))
	var rv := UIKit.vbox(4)
	rw.add_child(rv)
	rv.add_child(UIKit.ink("Recompensa: %s oro cada 10 oleadas y un gran premio al llegar a la 100" % GameData.format_num(3 * GameData.GEM_GOLD), 17, UIKit.BLUE.darkened(0.3), HORIZONTAL_ALIGNMENT_CENTER, true))
	sv.add_child(rw)
	var status := UIKit.ink("", 17, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	# Crear sala
	sv.add_child(_ibtn("castle", "Crear sala (misma red Wi-Fi)", UIKit.GREEN, 20, Vector2(0, 70), func() -> void:
		var code := Coop.host()
		if code == "":
			return
		status.text = "Código de la sala: %s\nEsperando a tu aliado..." % code
		if not Coop.partner_joined.is_connected(_on_coop_partner):
			Coop.partner_joined.connect(_on_coop_partner), 30))
	# Unirse
	var row := UIKit.hbox(8)
	var code_in := LineEdit.new()
	code_in.placeholder_text = "Código (ej. 192.168.1.20)"
	code_in.custom_minimum_size = Vector2(380, 64)
	code_in.add_theme_font_size_override("font_size", 20)
	row.add_child(code_in)
	row.add_child(_ibtn("play", "Unirse", UIKit.BLUE, 20, Vector2(200, 64), func() -> void:
		if code_in.text.strip_edges() == "":
			return
		Coop.join(code_in.text)
		status.text = "Conectando... el anfitrión empezará la partida.", 28))
	sv.add_child(row)
	# Por internet (Nakama): emparejamiento automático con otro jugador
	var online_btn := _ibtn("castle", "Buscar partida online", UIKit.ORANGE, 20, Vector2(0, 70), func() -> void:
		if not Online.online:
			status.text = "Sin conexión con el servidor online."
			return
		status.text = "Buscando aliado en todo el reino..."
		if not Online.match_failed.is_connected(_on_online_failed):
			Online.match_failed.connect(_on_online_failed.bind(status))
		Online.find_coop_match(), 30)
	sv.add_child(online_btn)
	sv.add_child(_ibtn("hero", "Jugar con un aliado IA", UIKit.PURPLE, 20, Vector2(0, 66), func() -> void:
		Coop.play_with_ai()
		Coop.start_game(), 30))
	sv.add_child(status)
	sv.add_child(_wrap(UIKit.ink("Para jugar por internet con jugadores de cualquier lugar hace falta un servidor de emparejamiento (ver README).", 14, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 1000))
	if not Coop.failed.is_connected(_on_coop_failed):
		Coop.failed.connect(_on_coop_failed)


func _on_coop_partner() -> void:
	if Coop.role == "host":
		UIKit.toast(self, "¡Tu aliado se ha unido!", UIKit.GREEN)
		Coop.start_game()


func _on_coop_failed(msg: String) -> void:
	UIKit.message(self, "Cooperativo", msg)



## Vista 3D del castillo (girando despacio) para la cabecera de La Fortaleza.
func _castle_view() -> Control:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(0, 260)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	box.add_child(vp)
	var pivot := Node3D.new()
	vp.add_child(pivot)
	var castle := V3.build_castle()
	pivot.add_child(castle)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.88, 0.95)
	e.ambient_light_energy = 0.6
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 34.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 3.6, 6.8), Vector3(0, 1.1, 0), Vector3.UP)
	var tw := pivot.create_tween().set_loops()
	tw.tween_property(pivot, "rotation:y", TAU, 24.0).from(0.0)
	return box



func _on_online_failed(msg: String, status: Label) -> void:
	if is_instance_valid(status):
		status.text = msg


# ================================================================ Ranking semanal
func _open_ranking() -> void:
	var sv := _open_sheet("ranking", "Ranking semanal", "trophy")
	var m: Dictionary = GameData.MAPS[sel_map]
	sv.add_child(UIKit.ink("Mejor oleada de la semana en %s" % m["name"], 19, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	sv.add_child(UIKit.ink("Se reinicia cada lunes. Cambia de mapa con las flechas de la pantalla principal.", 14, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var list := UIKit.vbox(6)
	sv.add_child(list)
	if not Online.online:
		list.add_child(UIKit.ink("Sin conexión con el servidor online.", 18, UIKit.RED.darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER, true))
		return
	list.add_child(UIKit.ink("Cargando...", 17, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var on_loaded := func(map_idx: int, top: Array, mine: Dictionary) -> void:
		if not is_instance_valid(list) or map_idx != sel_map:
			return
		for c in list.get_children():
			c.queue_free()
		if top.is_empty():
			list.add_child(UIKit.ink("Aún nadie ha jugado este mapa esta semana. ¡Sé el primero!", 17, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
		for r in top:
			var row := UIKit.inset()
			var h := UIKit.hbox(10)
			row.add_child(h)
			var medal := ["", "trophy", "star", "star"]
			var rk := int(r["rank"])
			if rk <= 3:
				h.add_child(UIIcon.make(medal[rk], 30))
			h.add_child(UIKit.ink("#%d" % rk, 18, UIKit.AMBER.darkened(0.3), HORIZONTAL_ALIGNMENT_LEFT, true))
			var n := UIKit.ink(r["name"] + ("  (tú)" if r["me"] else ""), 18, UIKit.BLUE.darkened(0.3) if r["me"] else UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(n)
			h.add_child(UIKit.icon_label("flag", "Oleada %d" % int(r["wave"]), 17, UIKit.INK, 24, true))
			list.add_child(row)
		if not mine.is_empty():
			list.add_child(UIKit.ink("Tu posición: #%d con la oleada %d" % [int(mine["rank"]), int(mine["wave"])], 18, UIKit.GREEN.darkened(0.3), HORIZONTAL_ALIGNMENT_CENTER, true))
	Online.leaderboard_loaded.connect(on_loaded, CONNECT_ONE_SHOT)
	Online.load_leaderboard(sel_map)

