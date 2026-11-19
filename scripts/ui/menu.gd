extends Control
## Menú principal.
## Pantalla limpia: barra superior (nivel + monedas/gemas), el mapa actual como protagonista
## con un gran botón Jugar, una columna de accesos a la derecha (diario, misiones, tienda,
## pase, tesoro, logros) que abren hojas emergentes, y un dock inferior con Mapas/Mejoras/Cartas.

const DOCK := [["maps", "Mapas", "map"], ["upgrades", "Fortaleza", "castle"], ["cards", "Cartas", "cards"]]
## Accesos de la columna derecha: [id, texto, icono, color]
const SIDE := [
	["daily", "Diario", "calendar", Color(0.95, 0.42, 0.4)],
	["quests", "Misiones", "quest", Color(0.36, 0.7, 0.32)],
	["shop", "Tienda", "chest", Color(0.95, 0.6, 0.2)],
	["collection", "Colección", "cards", Color(0.42, 0.5, 0.95)],
	["coop", "Cooperativo", "hero", Color(0.2, 0.62, 0.62)],
	["ranking", "Ranking", "trophy", Color(0.85, 0.45, 0.2)],
	["pass", "Pase", "crown", Color(0.6, 0.42, 0.9)],
	["treasury", "Tesoro", "coin_bag", Color(0.85, 0.62, 0.2)],
	["achievements", "Logros", "trophy", Color(0.25, 0.6, 0.9)],
]
const SHEETS := ["shop", "daily", "quests", "pass", "achievements", "collection"]
const TOP_H := 128.0
const DOCK_H := 118.0
const SHEET_MAX_H := 1280.0 - DOCK_H - 126.0 # la barra superior (oro, gemas, ajustes) queda siempre visible

static var _offer_shown := false

var current_tab := "maps"
## Modo superpuesto: el menú se abre ENCIMA de la batalla (pausada) solo para mostrar una hoja
## de la columna derecha (tienda, diario, misiones...). Al cerrarla se vuelve a la batalla.
var overlay := false
var _packs_anchor: Control


## Desplaza la Tienda hasta la sección de sobres (lo usa el tutorial).
func focus_packs() -> void:
	if sheet == null or not is_instance_valid(sheet) or _packs_anchor == null or not is_instance_valid(_packs_anchor):
		return
	var sc: ScrollContainer = sheet.get_meta("scroll")
	sc.scroll_vertical = int(_packs_anchor.global_position.y - sc.global_position.y + sc.scroll_vertical - 60)
var _overlay_base := 0
var _dock: Control
signal overlay_closed
var content: Control
var lbl_coins: Label
var lbl_gems: Label
var tab_buttons := {}
var side_buttons := {}
var side_col: VBoxContainer
var crest: LevelCrest
var sel_map := 0
var sheet: Control = null
var sheet_id := ""
var _last_coins := -1
var _last_gems := -1


## Vista previa de un mapa (suelo a cuadros, camino redondeado, bandera y castillo).
class MapPreview extends Control:
	var map_idx := 0

	func _draw() -> void:
		var m: Dictionary = GameData.MAPS[map_idx]
		var pts: Array = GameData.map_path(map_idx)
		var cols := GameData.COLS
		var rows := GameData.ROWS
		for p in pts:
			var c: Vector2i = p
			cols = maxi(cols, c.x + 1)
			rows = maxi(rows, c.y + 1)
		var s := minf(size.x / float(cols), size.y / float(rows))
		var o := (size - Vector2(cols, rows) * s) * 0.5
		var ground: Color = m["ground"]
		var bg := StyleBoxFlat.new()
		bg.bg_color = ground.darkened(0.25)
		bg.set_corner_radius_all(18)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		for x in cols:
			for y in rows:
				var col := ground if (x + y) % 2 == 0 else ground.lightened(0.06)
				draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(s, s)), col)
		var path_col: Color = m["path"]
		var w := s * 0.72
		for i in pts.size() - 1:
			var a: Vector2 = o + (Vector2(pts[i]) + Vector2(0.5, 0.5)) * s
			var b: Vector2 = o + (Vector2(pts[i + 1]) + Vector2(0.5, 0.5)) * s
			draw_line(a, b, path_col.darkened(0.2), w + 4.0)
			draw_circle(a, (w + 4.0) * 0.5, path_col.darkened(0.2))
		for i in pts.size() - 1:
			var a: Vector2 = o + (Vector2(pts[i]) + Vector2(0.5, 0.5)) * s
			var b: Vector2 = o + (Vector2(pts[i + 1]) + Vector2(0.5, 0.5)) * s
			draw_line(a, b, path_col, w)
			draw_circle(a, w * 0.5, path_col)
			draw_circle(b, w * 0.5, path_col)


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
		for i in 40:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_circle(p, rng.randf_range(1.0, 3.0), Color(1, 1, 0.9, rng.randf_range(0.08, 0.3)))
		for i in 6:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			draw_circle(p, rng.randf_range(80.0, 180.0), Color(1, 1, 1, 0.025))


func _ready() -> void:
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
	content.position = Vector2(0, TOP_H)
	content.size = Vector2(720, 1280 - TOP_H - DOCK_H)
	add_child(content)
	_build_side()
	_build_top()
	_build_dock()
	sel_map = clampi(GameData.current_map, 0, GameData.MAPS.size() - 1)
	if not Save.is_map_unlocked(sel_map):
		sel_map = 0
	Save.changed.connect(_refresh_currency)
	IAP.purchase_success.connect(_on_purchase_success)
	IAP.purchase_failed.connect(func(_pid: String, reason: String) -> void: UIKit.message(self, "Compra no realizada", reason))
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(_refresh_badges)
	add_child(timer)
	show_tab("maps")
	_refresh_currency()
	var away := Meta.seconds_away()
	var back := Meta.check_return_bonus()
	if away >= 300 and Meta.treasury_amount() >= 20:
		_offline_earnings(away)
	elif not back.is_empty():
		var cards := Meta.grant(back)
		UIKit.message(self, "¡Bienvenido de vuelta!", "Te echábamos de menos, comandante.\n" + Meta.reward_text(back))
		if not cards.is_empty():
			UIKit.show_pack_results(self, cards)
	elif Meta.daily_available():
		show_tab("daily")
	else:
		_maybe_offer()


func _ready_overlay() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UIKit.apply_theme(self)
	content = Control.new()
	content.visible = false
	add_child(content)
	_build_side()
	side_col.visible = false
	_build_top()
	_build_dock()
	_dock.visible = false
	sel_map = clampi(GameData.current_map, 0, GameData.MAPS.size() - 1)
	Save.changed.connect(_refresh_currency)
	IAP.purchase_success.connect(_on_purchase_success)
	IAP.purchase_failed.connect(func(_pid: String, reason: String) -> void: UIKit.message(self, "Compra no realizada", reason))
	_refresh_currency()


## Abre una sección de la columna derecha (en modo superpuesto).
func open_side(id: String) -> void:
	# Todo lo que se añada a partir de aquí (la hoja o ventanas emergentes) mantiene abierto el menú
	var base := get_child_count()
	_side_pressed(id)
	_overlay_base = base


func _process(_delta: float) -> void:
	# Superpuesto: cuando ya no queda ninguna hoja ni ventana abierta, volver a la batalla.
	if overlay and _overlay_base > 0 and (sheet == null or not is_instance_valid(sheet)) and get_child_count() <= _overlay_base:
		_overlay_base = 0
		overlay_closed.emit()
		queue_free()


## Cuántos avisos tiene cada acceso de la columna derecha (también los usa la batalla).
static func side_badge(id: String) -> int:
	match id:
		"daily": return 1 if Meta.daily_available() else 0
		"quests":
			var n := Meta.weekly_claimable()
			for q in Meta.quests():
				if not q["claimed"] and int(q["progress"]) >= int(Meta.quest_def(q["id"])["goal"]):
					n += 1
			return n
		"shop": return (1 if Meta.free_pack_ready() else 0) + (1 if Meta.ad_pack_ready() else 0)
		"pass": return Meta.season_claimable()
		"treasury": return 1 if Meta.treasury_amount() > 0 and Meta.treasury_full() else 0
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
	s.content_margin_left = 10
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 12
	top.add_theme_stylebox_override("panel", s)
	top.position = Vector2(12, 10)
	top.size = Vector2(696, 106)
	top.custom_minimum_size = Vector2(696, 106)
	add_child(top)
	_top_bar = top
	var row := UIKit.hbox(10)
	top.add_child(row)
	crest = LevelCrest.new()
	crest.custom_minimum_size = Vector2(84, 84)
	crest.mouse_filter = Control.MOUSE_FILTER_STOP
	UIKit.add_press_bounce(crest)
	crest.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_level_info())
	row.add_child(crest)
	var name_box := UIKit.vbox(0)
	name_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_box.add_child(UIKit.label("PUKIBA", 22, UIKit.GOLD))
	name_box.add_child(UIKit.label("Defense", 18, UIKit.GOLD))
	row.add_child(name_box)
	row.add_child(UIKit.spacer())
	var coin_pill := UIKit.pill("coin", "0", 24, Color.WHITE, 150)
	coin_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_coins = coin_pill.get_meta("label")
	row.add_child(coin_pill)
	var gem_btn := Button.new()
	gem_btn.flat = true
	gem_btn.focus_mode = Control.FOCUS_NONE
	gem_btn.custom_minimum_size = Vector2(172, 64)
	gem_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for st in ["normal", "hover", "pressed", "focus"]:
		gem_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var gem_pill := UIKit.pill("gem", "0", 24, Color.WHITE, 170)
	gem_pill.position = Vector2(0, 8)
	gem_btn.add_child(gem_pill)
	lbl_gems = gem_pill.get_meta("label")
	var plus := PanelContainer.new()
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plus.add_theme_stylebox_override("panel", UIKit.style(UIKit.GREEN, UIKit.GREEN.lightened(0.4), 14, 2))
	plus.position = Vector2(128, 13)
	plus.size = Vector2(36, 36)
	var pic := UIIcon.make("plus", 20)
	pic.outline = 6.0
	plus.add_child(pic)
	gem_btn.add_child(plus)
	gem_btn.pressed.connect(func() -> void: show_tab("shop"))
	UIKit.add_press_bounce(gem_btn)
	row.add_child(gem_btn)
	var settings := UIKit.icon_button("gear", UIKit.WOOD, 64, 0.62)
	settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings.pressed.connect(_open_settings)
	row.add_child(settings)


# ================================================================ Columna derecha
func _build_side() -> void:
	side_col = UIKit.vbox(6)
	side_col.position = Vector2(614, TOP_H + 8)
	side_col.custom_minimum_size = Vector2(100, 0)
	add_child(side_col)
	var packs := _side_item("packs", "Sobres", "gift", Color(0.95, 0.35, 0.45))
	side_col.add_child(packs)
	for it in SIDE:
		# Las funciones se revelan poco a poco con el nivel de cuenta
		if Meta.feature_unlocked(it[0]):
			side_col.add_child(_side_item(it[0], it[1], it[2], it[3]))


func _side_item(id: String, text: String, icon: String, col: Color) -> Control:
	var box := UIKit.vbox(-6)
	box.custom_minimum_size = Vector2(100, 0)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(100, 80)
	box.add_child(holder)
	var b := UIKit.icon_button(icon, col, 76, 0.66)
	b.position = Vector2(12, 0)
	b.size = Vector2(76, 76)
	b.pressed.connect(func() -> void: _side_pressed(id))
	holder.add_child(b)
	var l := UIKit.label(text, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", UIKit.font(true))
	box.add_child(l)
	side_buttons[id] = {"box": box, "holder": holder, "badge": null}
	return box


func _side_pressed(id: String) -> void:
	match id:
		"packs":
			var cards := Meta.open_pending_pack()
			if not cards.is_empty():
				UIKit.show_pack_results(self, cards, _refresh_badges)
			_refresh_badges()
		"treasury":
			_open_treasury()
		"coop":
			_open_coop()
		"ranking":
			_open_ranking()
		_:
			show_tab(id)


func _set_badge(id: String, count: int, show_mark := false) -> void:
	if not side_buttons.has(id) and not tab_buttons.has(id):
		return
	var d: Dictionary = side_buttons[id] if side_buttons.has(id) else tab_buttons[id]
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
	bd.position = Vector2(holder.custom_minimum_size.x - 34, -4)
	holder.add_child(bd)
	UIKit.pop_in(bd, 0.05, 0.2)
	d["badge"] = bd


func _quests_claimable() -> int:
	return _daily_quests_claimable() + Meta.weekly_claimable()


func _daily_quests_claimable() -> int:
	var n := 0
	for q in Meta.quests():
		if not q["claimed"] and int(q["progress"]) >= int(Meta.quest_def(q["id"])["goal"]):
			n += 1
	return n


func _refresh_badges() -> void:
	if side_col == null:
		return
	_set_badge("daily", 1 if Meta.daily_available() else 0)
	_set_badge("quests", _quests_claimable())
	_set_badge("shop", (1 if Meta.free_pack_ready() else 0) + (1 if Meta.ad_pack_ready() else 0))
	_set_badge("pass", Meta.season_claimable())
	_set_badge("treasury", 0, Meta.treasury_amount() > 0 and Meta.treasury_full())
	_set_badge("achievements", Meta.claimable_achievements())
	var pend := Meta.pending_packs().size()
	side_buttons["packs"]["box"].visible = pend > 0
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


# ================================================================ Dock inferior
func _build_dock() -> void:
	var dock := PanelContainer.new()
	var s := UIKit.card_style(Color(UIKit.NAVY, 0.97), UIKit.NAVY_DARK, 30, 6, 10)
	s.border_color = UIKit.NAVY_DARK
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	dock.add_theme_stylebox_override("panel", s)
	dock.position = Vector2(12, 1280 - DOCK_H)
	dock.custom_minimum_size = Vector2(696, DOCK_H - 10)
	add_child(dock)
	_dock = dock
	var bar := UIKit.hbox(8)
	dock.add_child(bar)
	for t in DOCK:
		var id: String = t[0]
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(218, 88)
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(holder)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(func() -> void: show_tab(id))
		holder.add_child(b)
		var v := UIKit.vbox(0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(v)
		var ic := UIIcon.make(t[2], 46)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := UIKit.label(t[1], 19, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_font_override("font", UIKit.font(true))
		v.add_child(l)
		UIKit.add_press_bounce(b)
		tab_buttons[id] = {"button": b, "icon": ic, "label": l, "holder": holder, "badge": null}


func _style_dock() -> void:
	for t in DOCK:
		var d: Dictionary = tab_buttons[t[0]]
		var b: Button = d["button"]
		var sel: bool = t[0] == current_tab
		var st: StyleBox
		if sel:
			var sb := UIKit.style(UIKit.GOLD, UIKit.GOLD.lightened(0.5), 22, 3)
			sb.border_width_bottom = 6
			sb.border_color = Color(0.82, 0.55, 0.12)
			st = sb
		else:
			var sb2 := UIKit.style(Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), 22, 0)
			st = sb2
		for k in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, st)
		var l: Label = d["label"]
		l.add_theme_color_override("font_color", Color.WHITE if sel else Color(0.8, 0.86, 1.0))
		l.add_theme_color_override("font_outline_color", Color(0.55, 0.32, 0.05) if sel else UIKit.NAVY_DARK)
		(d["icon"] as Control).modulate = Color.WHITE if sel else Color(1, 1, 1, 0.7)


# ================================================================ Monedas
func _refresh_currency() -> void:
	if lbl_coins == null:
		return
	var c := Save.coins()
	var g := Save.gems()
	lbl_coins.text = GameData.format_num(c)
	lbl_gems.text = GameData.format_num(g)
	if _last_coins >= 0 and c != _last_coins:
		UIKit.pop(lbl_coins.get_parent() as Control, 1.2)
	if _last_gems >= 0 and g != _last_gems:
		UIKit.pop(lbl_gems.get_parent() as Control, 1.2)
	_last_coins = c
	_last_gems = g
	_refresh_badges()


# ================================================================ Navegación
func show_tab(id: String) -> void:
	if overlay and not id in SHEETS:
		_close_sheet() # en batalla no se cambia de pestaña del menú: se vuelve a la partida
		return
	if id in SHEETS:
		var titles := {"collection": "Colección", "shop": "Tienda", "daily": "Recompensa diaria", "quests": "Misiones", "pass": "Pase Real", "achievements": "Logros"}
		var icons := {"collection": "cards", "shop": "chest", "daily": "calendar", "quests": "quest", "pass": "crown", "achievements": "trophy"}
		var sv := _open_sheet(id, titles[id], icons[id])
		match id:
			"shop": _tab_shop(sv)
			"daily": _tab_daily(sv)
			"quests": _tab_quests(sv)
			"pass": _tab_pass(sv)
			"achievements": _tab_achievements(sv)
			"collection": _collection_view(sv, true)
		_refresh_currency()
		return
	_close_sheet()
	current_tab = id
	for c in content.get_children():
		c.queue_free()
	side_col.visible = id == "maps"
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 16 # un clic con temblor no es un arrastre
	UIKit.drag_anywhere(scroll) # se arrastra desde cualquier punto, también sobre botones y cartas
	scroll.size = Vector2(604 if id == "maps" else 720, content.size.y)
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
	_style_dock()
	_refresh_currency()


## Hoja emergente (para diario, tienda, misiones...). Devuelve el contenedor donde construir.
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
	sheet.offset_bottom = -DOCK_H # la barra inferior (Mapas/Fortaleza/Cartas) siempre queda accesible
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	if _top_bar != null and is_instance_valid(_top_bar):
		move_child(_top_bar, -1) # la barra de arriba (oro, gemas, ajustes) siempre encima y tocable
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
	ps.content_margin_left = 14
	ps.content_margin_right = 14
	ps.content_margin_top = 12
	ps.content_margin_bottom = 14
	ps.shadow_color = Color(0, 0, 0, 0.45)
	p.add_theme_stylebox_override("panel", ps)
	p.position = Vector2(12, 120)
	p.custom_minimum_size = Vector2(696, SHEET_MAX_H)
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
	close.pressed.connect(_close_sheet)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 16 # un clic con temblor no es un arrastre
	UIKit.drag_anywhere(scroll) # se arrastra desde cualquier punto, también sobre botones y cartas
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	sheet.set_meta("scroll", scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_right", 10)
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


## Ajusta la altura de la hoja a su contenido y la centra (con animación de entrada).
func _fit_sheet(sh: Control, animate: bool) -> void:
	if not is_instance_valid(sh):
		return
	var p: PanelContainer = sh.get_meta("panel")
	var body: Control = sh.get_meta("body")
	var h := clampf(body.get_combined_minimum_size().y + 130.0, 420.0, SHEET_MAX_H)
	p.custom_minimum_size.y = h
	p.size.y = h
	var y := maxf(120.0, (1280.0 - DOCK_H - h) * 0.5 + 30.0)
	y = minf(y, 1280.0 - DOCK_H - h - 6.0)
	if not animate:
		p.position.y = y
		return
	p.position.y = y + 90.0
	var tw := sh.create_tween()
	tw.tween_property(sh, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(p, "position:y", y, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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


func _btn(text: String, color: Color, fs: int, min_size: Vector2, cb: Callable) -> Button:
	var b := UIKit.button(text, color, fs, min_size)
	b.mouse_filter = Control.MOUSE_FILTER_PASS # permite arrastrar el scroll en móvil
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
	if r.has("legendary"):
		return "crown"
	if r.has("pack"):
		return "cards"
	if r.has("gems"):
		return "gem"
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


## Mejoras exclusivas con gemas (al final de la pestaña Fortaleza).
func _gem_upgrades_section(v: VBoxContainer) -> void:
	_section(v, "Mejoras con gemas", "gem", false)
	v.add_child(UIKit.label("Exclusivas y permanentes para todos los mapas", 16, UIKit.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER))
	for id in GameData.GEM_UPGRADES.keys():
		var def: Dictionary = GameData.GEM_UPGRADES[id]
		var lvl := Save.gem_upgrade_level(id)
		var maxl := int(def["max"])
		var p := UIKit.card(Color(0.9, 0.94, 1.0))
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		var row := UIKit.hbox(12)
		p.add_child(row)
		var ic := UIIcon.make(def.get("icon", "gem"), 52)
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
			var b := _ibtn("gem", str(cost), UIKit.BLUE if Save.gems() >= cost else UIKit.RED, 21, Vector2(140, 68), func() -> void:
				if Meta.buy_gem_upgrade(id):
					show_tab("upgrades")
				else:
					_not_enough_gems(), 28)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		v.add_child(p)


## Entrenamiento de torres con gemas: cada torre empieza en un nivel más alto en todos los mapas.
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
			var b := _ibtn("gem", str(cost), UIKit.BLUE if Save.gems() >= cost else UIKit.RED, 21, Vector2(140, 68), func() -> void:
				if Meta.buy_tower_train(id):
					show_tab("upgrades")
				else:
					_not_enough_gems(), 28)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		v.add_child(p)


func _not_enough_coins() -> void:
	UIKit.popup(self, "Oro insuficiente", UIKit.label("Juega más oleadas o cambia gemas por oro en la tienda.", 20, UIKit.PARCHMENT), [
		["Ir a la tienda", func() -> void: show_tab("shop"), UIKit.GREEN], ["Cerrar", Callable(), UIKit.GREY]])


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
	scroll.custom_minimum_size = Vector2(640, 780)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UIKit.drag_anywhere(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
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
	UIKit.popup(self, "¡Sobres abiertos!", v, [["¡Genial!", func() -> void: show_tab("shop"), UIKit.GREEN]], 696)


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
	v.add_child(_wrap(UIKit.ink("Toca una carta para ver sus datos, subirla de nivel o elegir tu héroe. Las copias de los sobres suben su nivel (+10% de poder por nivel).", 16, txt_col, HORIZONTAL_ALIGNMENT_CENTER) if on_light else UIKit.label("Toca una carta para ver sus datos, subirla de nivel o elegir tu héroe. Las copias de los sobres suben su nivel (+10% de poder por nivel).", 16, txt_col, HORIZONTAL_ALIGNMENT_CENTER), 640))
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
		grid.columns = 4
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
%d gemas" % [Save.hero_level(id), Save.hero_level(id) + 1, hc], func() -> void:
			if Meta.level_hero(id):
				UIKit.toast(self, "¡%s sube a nivel %d!" % [def["name"], Save.hero_level(id)], UIKit.GOLD)
				_refresh_cards_view()
			else:
				_not_enough_gems(), UIKit.BLUE])
	if GameData.is_hero(id) and lvl > 0 and Save.data["selected_hero"] != id:
		buttons.append(["Elegir héroe", func() -> void:
			Save.data["selected_hero"] = id
			Save.save_game()
			_refresh_cards_view(), UIKit.PURPLE])
	if lvl == 0:
		buttons.append(["Ver sobres", func() -> void: show_tab("shop"), UIKit.BLUE])
	buttons.append(["Cerrar", Callable(), UIKit.GREY])
	UIKit.popup(self, def["name"], v, buttons, 696)


# ================================================================ Tienda
func _tab_shop(v: VBoxContainer) -> void:
	# Oferta del día
	var deal := Meta.daily_deal()
	var dbox := UIKit.card(Color(1.0, 0.9, 0.7))
	var drow := UIKit.hbox(12)
	dbox.add_child(drow)
	var dic := UIIcon.make(_reward_icon(deal["reward"]), 72)
	dic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	drow.add_child(dic)
	var dinfo := UIKit.vbox(2)
	dinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rb := UIKit.ribbon("OFERTA DEL DÍA", UIKit.RED, 15)
	rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dinfo.add_child(rb)
	dinfo.add_child(UIKit.ink(deal["name"], 24, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	dinfo.add_child(_wrap(UIKit.ink(Meta.reward_text(deal["reward"]), 16, UIKit.INK_SOFT), 300))
	drow.add_child(dinfo)
	var pv := UIKit.vbox(2)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var was := UIKit.ink("%d" % int(deal["was"]), 18, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, true)
	var strike := ColorRect.new()
	strike.color = UIKit.RED
	strike.anchor_right = 1.0
	strike.anchor_top = 0.5
	strike.anchor_bottom = 0.5
	strike.offset_top = -1
	strike.offset_bottom = 2
	strike.offset_left = -4
	strike.offset_right = 4
	strike.rotation = -0.12
	strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	was.add_child(strike)
	var was_box := CenterContainer.new()
	was_box.add_child(was)
	pv.add_child(was_box)
	if Meta.deal_available():
		var dprice := int(deal["gems"])
		pv.add_child(_ibtn("gem", str(dprice), UIKit.GREEN, 22, Vector2(140, 64), func() -> void:
			if Save.gems() < dprice:
				_not_enough_gems()
				return
			var cards := Meta.buy_daily_deal()
			UIKit.toast(self, "¡Oferta comprada!")
			if cards.is_empty():
				show_tab("shop")
			else:
				UIKit.show_pack_results(self, cards, func() -> void: show_tab("shop")), 28))
	else:
		pv.add_child(UIKit.icon_label("check", "Comprada", 18, UIKit.GREEN.darkened(0.3), 26, true))
	drow.add_child(pv)
	v.add_child(dbox)

	# Tienda diaria: cartas concretas por monedas
	_section(v, "Tienda del día (oro)", "coin")
	var shop_row := UIKit.hbox(10)
	shop_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(shop_row)
	for cid in Meta.daily_shop():
		var sb := UIKit.vbox(4)
		var w := UIKit.card_widget(cid, false, true)
		w.custom_minimum_size = Vector2(150, 180)
		sb.add_child(w)
		sb.add_child(UIKit.ink("x%d copias" % Meta.daily_shop_copies(cid), 15, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
		if Meta.daily_shop_bought(cid):
			sb.add_child(UIKit.icon_label("check", "Comprada", 16, UIKit.GREEN.darkened(0.3), 24, true))
		else:
			var price := Meta.daily_shop_price(cid)
			var bb := _ibtn("coin", GameData.format_num(price), UIKit.GREEN, 18, Vector2(150, 54), func() -> void:
				if Meta.buy_daily_card(cid):
					UIKit.toast(self, "+%d copias" % Meta.daily_shop_copies(cid))
					show_tab("shop")
				else:
					_not_enough_coins(), 24)
			bb.disabled = Save.coins() < price
			sb.add_child(bb)
		shop_row.add_child(sb)

	# Ofertas destacadas
	var starter_left := Meta.starter_seconds_left()
	if starter_left > 0:
		v.add_child(_offer_box("starter_pack", Color(1.0, 0.86, 0.62), "-50%"))
		v.add_child(UIKit.ink("La oferta de inicio termina en %dh %02dm" % [starter_left / 3600, (starter_left % 3600) / 60], 15, UIKit.RED.darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER, true))
	# Fondo del Reino (pase de crecimiento)
	if not bool(Save.data.get("growth_fund", false)):
		v.add_child(_offer_box("growth_fund", Color(0.9, 0.95, 0.82), "x6"))
	else:
		var gf := UIKit.card(Color(0.9, 0.95, 0.82))
		var gv := UIKit.vbox(6)
		gf.add_child(gv)
		gv.add_child(UIKit.ink("Fondo del Reino", 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
		var gr := HFlowContainer.new()
		gr.alignment = FlowContainer.ALIGNMENT_CENTER
		gv.add_child(gr)
		for lvl in GameData.GROWTH_FUND.keys():
			var claimed: bool = int(lvl) in Save.data["growth_claimed"]
			var lb := _ibtn("gem", "Nv.%d: %d" % [int(lvl), int(GameData.GROWTH_FUND[lvl])], UIKit.GREEN if not claimed else UIKit.GREY, 15, Vector2(150, 50), func() -> void:
				var g := Meta.claim_growth(int(lvl))
				if g > 0:
					UIKit.toast(self, "+%d gemas" % g, UIKit.GEM)
					show_tab("shop"), 22)
			lb.disabled = not int(lvl) in Meta.growth_claimable()
			gr.add_child(lb)
		v.add_child(gf)
	# Cofre Mensual
	if not Meta.monthly_active():
		v.add_child(_offer_box("monthly_card", Color(0.92, 0.88, 1.0), "2700"))
	else:
		v.add_child(UIKit.icon_label("crown", "Cofre Mensual activo: %d días restantes (reclama 60 gemas al día en el Diario)" % Meta.monthly_days_left(), 15, UIKit.PURPLE.darkened(0.3), 26, true))
	if not bool(Save.data["no_ads"]):
		v.add_child(_offer_box("no_ads", Color(0.85, 0.92, 1.0), ""))
	else:
		v.add_child(UIKit.icon_label("check", "Sin anuncios: ACTIVO. ¡Gracias por tu apoyo!", 18, UIKit.GREEN.darkened(0.3), 28, true))

	# Sobres
	_section(v, "Sobres de cartas", "cards")
	var packs := GridContainer.new()
	_packs_anchor = packs
	packs.columns = 3
	packs.add_theme_constant_override("h_separation", 10)
	packs.add_theme_constant_override("v_separation", 10)
	v.add_child(packs)
	var free := UIKit.card(Color(0.86, 0.95, 0.8))
	free.custom_minimum_size = Vector2(205, 250)
	var fv := UIKit.vbox(6)
	free.add_child(fv)
	var gic := UIIcon.make("gift", 64)
	gic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fv.add_child(gic)
	fv.add_child(UIKit.ink("¡GRATIS!", 22, UIKit.GREEN.darkened(0.35), HORIZONTAL_ALIGNMENT_CENTER, true))
	fv.add_child(UIKit.ink("Regalo · cada 12 h", 14, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var fsp := Control.new()
	fsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fv.add_child(fsp)
	if Meta.free_pack_ready():
		var fb := _ibtn("gift", "Abrir", UIKit.GREEN, 20, Vector2(0, 60), func() -> void:
			UIKit.show_pack_results(self, Meta.claim_free_pack(), func() -> void: show_tab("shop")), 30)
		fv.add_child(fb)
		UIKit.pulse(fb, 1.05)
	else:
		var s := Meta.free_pack_seconds_left()
		fv.add_child(UIKit.ink("Disponible en\n%dh %02dm" % [s / 3600, (s % 3600) / 60], 16, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	packs.add_child(free)
	# Sobre por anuncio, cada 3 horas
	var adp := UIKit.card(Color(0.92, 0.88, 1.0))
	adp.custom_minimum_size = Vector2(205, 250)
	var av := UIKit.vbox(6)
	adp.add_child(av)
	var aic := UIIcon.make("ad", 64)
	aic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	av.add_child(aic)
	av.add_child(UIKit.ink("CON ANUNCIO", 20, UIKit.PURPLE.darkened(0.3), HORIZONTAL_ALIGNMENT_CENTER, true))
	av.add_child(UIKit.ink("Bronce · cada 3 h", 14, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var asp := Control.new()
	asp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	av.add_child(asp)
	if Meta.ad_pack_ready():
		var ab := _ibtn("ad", "Ver y abrir", UIKit.PURPLE, 18, Vector2(0, 60), func() -> void:
			Ads.show_rewarded("ad_pack", func() -> void:
				UIKit.show_pack_results(self, Meta.claim_ad_pack(), func() -> void: show_tab("shop")), _ad_fail), 28)
		ab.disabled = not Ads.can_show_rewarded()
		av.add_child(ab)
	else:
		var asl := Meta.ad_pack_seconds_left()
		av.add_child(UIKit.ink("Disponible en\n%dh %02dm" % [asl / 3600, (asl % 3600) / 60], 16, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	packs.add_child(adp)
	# Sobre de Bronce con oro: 1 al día
	var gp := UIKit.card(Color(1.0, 0.93, 0.75))
	gp.custom_minimum_size = Vector2(205, 250)
	var gv := UIKit.vbox(6)
	gp.add_child(gv)
	var cic := UIIcon.make("coin_bag", 64)
	cic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gv.add_child(cic)
	gv.add_child(UIKit.ink("CON ORO", 20, UIKit.AMBER.darkened(0.35), HORIZONTAL_ALIGNMENT_CENTER, true))
	var gleft := Meta.gold_packs_left_today()
	gv.add_child(UIKit.ink("Bronce · quedan %d de %d hoy" % [gleft, Meta.GOLD_PACK_DAILY], 14, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var gsp := Control.new()
	gsp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gv.add_child(gsp)
	if gleft > 0:
		var gb := _ibtn("coin", str(Meta.GOLD_PACK_PRICE), UIKit.GOLD, 20, Vector2(0, 60), func() -> void:
			if Save.coins() < Meta.GOLD_PACK_PRICE:
				UIKit.toast(self, "Te falta oro (%d)" % Meta.GOLD_PACK_PRICE, UIKit.RED)
				return
			UIKit.show_pack_results(self, Meta.buy_gold_pack(), func() -> void: show_tab("shop")), 30)
		gv.add_child(gb)
	else:
		gv.add_child(UIKit.ink("Vuelve mañana", 16, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	packs.add_child(gp)
	# Sobres de torres y de héroes: bronce, plata y oro
	for kind in ["tower", "hero"]:
		_section(v, "Sobres de torres" if kind == "tower" else "Sobres de héroes", "castle" if kind == "tower" else "crown")
		v.add_child(_wrap(UIKit.ink("Solo torres: más baratos, para mejorar tus defensas." if kind == "tower" else "Solo héroes: más caros, porque los héroes son pocos y muy poderosos.", 15, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 680))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		v.add_child(grid)
		for pid in GameData.SHOP_PACKS[kind]:
			grid.add_child(_pack_box(pid))
	var ob := _ibtn("info", "Probabilidades", UIKit.GREY, 17, Vector2(260, 56), _show_odds, 26)
	ob.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ob)

	# Gemas con dinero real
	_section(v, "Gemas", "gem")
	var gems_row := GridContainer.new()
	gems_row.columns = 2
	gems_row.add_theme_constant_override("h_separation", 10)
	gems_row.add_theme_constant_override("v_separation", 14)
	v.add_child(gems_row)
	var gem_ids := ["gems_100", "gems_550", "gems_1200", "gems_2600"]
	for k in gem_ids.size():
		var pid: String = gem_ids[k]
		var p: Dictionary = GameData.IAP_PRODUCTS[pid]
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(318, 210)
		var box := UIKit.card(Color(0.86, 0.95, 1.0))
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_top = 10
		holder.add_child(box)
		var bv := UIKit.vbox(4)
		box.add_child(bv)
		var gi := UIKit.hbox(-14)
		gi.alignment = BoxContainer.ALIGNMENT_CENTER
		for j in k + 1:
			gi.add_child(UIIcon.make("gem", 44 + 4 * k))
		bv.add_child(gi)
		bv.add_child(UIKit.ink(p["name"], 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
		var desc_txt: String = p["desc"]
		if Meta.first_buy_bonus(pid):
			desc_txt = "%d gemas  ¡x2 en la 1ª compra!" % (int(p["gems"]) * 2)
		bv.add_child(UIKit.ink(desc_txt, 16, UIKit.BLUE.darkened(0.3), HORIZONTAL_ALIGNMENT_CENTER, true))
		bv.add_child(_btn(p["price"], UIKit.GREEN, 22, Vector2(0, 58), func() -> void: IAP.purchase(pid)))
		if pid == "gems_2600":
			var rib := UIKit.ribbon("¡MEJOR OFERTA!", UIKit.RED, 14)
			rib.position = Vector2(70, -4)
			holder.add_child(rib)
		elif pid == "gems_1200":
			var rib2 := UIKit.ribbon("POPULAR", UIKit.ORANGE, 14)
			rib2.position = Vector2(100, -4)
			holder.add_child(rib2)
		gems_row.add_child(holder)

	# Cambio de gemas por monedas
	_section(v, "Tesorería", "coin")
	for deal2 in [[50, 2500], [200, 11000], [600, 36000]]:
		var g: int = deal2[0]
		var c: int = deal2[1]
		var row := UIKit.inset()
		var rr := UIKit.hbox(10)
		row.add_child(rr)
		rr.add_child(UIIcon.make("coin_bag", 48))
		var tl := UIKit.ink("%s oro" % GameData.format_num(c), 21, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rr.add_child(tl)
		rr.add_child(_ibtn("gem", str(g), UIKit.BLUE, 20, Vector2(140, 60), func() -> void:
			if Save.spend_gems(g):
				Save.add_coins(c)
				UIKit.toast(self, "+%s oro" % GameData.format_num(c))
			else:
				_not_enough_gems(), 26))
		v.add_child(row)
	var rs := _btn("Restaurar compras", UIKit.GREY, 16, Vector2(240, 56), func() -> void:
		IAP.restore_purchases()
		UIKit.toast(self, "Restaurando compras..."))
	rs.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(rs)


func _offer_box(pid: String, color: Color, tag: String) -> Control:
	var p: Dictionary = GameData.IAP_PRODUCTS[pid]
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 150)
	var box := UIKit.card(color)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 10
	holder.add_child(box)
	var row := UIKit.hbox(12)
	box.add_child(row)
	var icons := {"starter_pack": "chest", "growth_fund": "upgrade", "monthly_card": "calendar", "no_ads": "ad"}
	var ic := UIIcon.make(icons.get(pid, "gem"), 70)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.ink(p["name"], 24, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	info.add_child(_wrap(UIKit.ink(p["desc"], 15, UIKit.INK_SOFT), 330))
	row.add_child(info)
	var b := _btn(p["price"], UIKit.GREEN, 22, Vector2(130, 70), func() -> void: IAP.purchase(pid))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	if tag != "":
		var rib := UIKit.ribbon(tag, UIKit.RED, 18)
		rib.position = Vector2(560, -4)
		holder.add_child(rib)
		UIKit.pulse(rib, 1.08)
	return holder


func _pack_box(pid: String) -> Control:
	var p: Dictionary = GameData.PACKS[pid]
	var pc: Color = p["color"]
	var box := UIKit.card(pc.lerp(Color.WHITE, 0.72))
	box.custom_minimum_size = Vector2(212, 0)
	var bv := UIKit.vbox(4)
	box.add_child(bv)
	var art_holder := CenterContainer.new()
	art_holder.custom_minimum_size = Vector2(0, 196)
	art_holder.add_child(PackOpening.pack_art(pid, Vector2(144, 192)))
	bv.add_child(art_holder)
	bv.add_child(UIKit.ink(p["name"], 19, pc.darkened(0.5), HORIZONTAL_ALIGNMENT_CENTER, true))
	var g := "1 %s+ seguro" % GameData.RARITIES[p["guarantee"]]["name"] if p["guarantee"] != "" else ""
	bv.add_child(UIKit.ink("%d cartas" % int(p["cards"]), 15, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	bv.add_child(UIKit.ink(g, 13, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bv.add_child(sp)
	var unit := int(p["gems"])
	# Cantidad: x1, x5 o x10 sobres de una vez (el precio del botón se actualiza)
	var state := {"qty": int(_pack_qty.get(pid, 1))}
	var usd := UIKit.ink(Meta.gems_usd(unit * int(state["qty"])), 12, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	var buy: Button
	var qrow := UIKit.hbox(4)
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	var qbtns: Array = []
	for q in [1, 5, 10]:
		var qb := UIKit.button("x%d" % q, UIKit.GOLD if q == int(state["qty"]) else UIKit.GREY, 15, Vector2(58, 36))
		qb.mouse_filter = Control.MOUSE_FILTER_PASS
		qbtns.append(qb)
		qrow.add_child(qb)
	bv.add_child(qrow)
	bv.add_child(usd)
	buy = _ibtn("gem", str(unit * int(state["qty"])), UIKit.BLUE, 21, Vector2(0, 56), func() -> void:
		if bool(Save.data.get("minor", false)):
			UIKit.message(self, "Sobres", "Los sobres pagados no están disponibles para menores. Puedes abrirlos viendo anuncios.")
			return
		var qty := int(state["qty"])
		var price := unit * qty
		if Save.gems() < price:
			_not_enough_gems()
			return
		var open_it := func() -> void:
			var cards := Meta.buy_packs_with_gems(pid, qty)
			if qty == 1:
				UIKit.show_pack_results(self, cards, func() -> void: show_tab("shop"))
			else:
				_multi_pack_results(cards, qty, p["name"])
		if price >= 400:
			var what: String = p["name"] if qty == 1 else "%d x %s" % [qty, p["name"]]
			UIKit.popup(self, "¿Confirmar compra?", UIKit.label("%s por %d gemas (%s)" % [what, price, Meta.gems_usd(price)], 20, UIKit.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER), [
				["Comprar", open_it, UIKit.GREEN], ["Cancelar", Callable(), UIKit.GREY]])
		else:
			open_it.call(), 28)
	bv.add_child(buy)
	for i in qbtns.size():
		var qv: int = [1, 5, 10][i]
		(qbtns[i] as Button).pressed.connect(func() -> void:
			state["qty"] = qv
			_pack_qty[pid] = qv
			for j in qbtns.size():
				UIKit.set_button_color(qbtns[j], UIKit.GOLD if j == i else UIKit.GREY)
			UIKit.set_button_content(buy, "gem", str(unit * qv), 21, 28)
			usd.text = Meta.gems_usd(unit * qv))
	# o verlo con anuncios (el progreso se guarda)
	var need := Meta.pack_ads_needed(pid)
	var have := Meta.pack_ads_progress(pid)
	var left := Meta.pack_ads_left_today(pid)
	if left <= 0:
		# Límite diario de sobres con anuncios alcanzado (bronce 3, plata 2, oro 1)
		var done_b := _ibtn("ad", "Mañana", UIKit.GREY, 18, Vector2(0, 50), func() -> void:
			UIKit.toast(self, "Límite diario: %d %s con anuncios. Vuelve mañana." % [Meta.pack_ad_daily_limit(pid), "sobre" if Meta.pack_ad_daily_limit(pid) == 1 else "sobres"], UIKit.PARCHMENT), 26)
		bv.add_child(done_b)
		return box
	bv.add_child(UIKit.ink("Hoy: %d de %d con anuncios" % [left, Meta.pack_ad_daily_limit(pid)], 13, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var ad_b := _ibtn("ad", "%d/%d" % [have, need], UIKit.PURPLE, 18, Vector2(0, 50), func() -> void:
		Ads.show_rewarded("pack_" + pid, func() -> void:
			var cards := Meta.add_pack_ad(pid)
			if cards.is_empty():
				UIKit.toast(self, "Anuncio %d/%d para el %s" % [Meta.pack_ads_progress(pid), need, p["name"]], UIKit.GEM)
				show_tab("shop")
			else:
				UIKit.show_pack_results(self, cards, func() -> void: show_tab("shop")), _ad_fail), 26)
	ad_b.disabled = not Ads.can_show_rewarded()
	bv.add_child(ad_b)
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
	UIKit.popup(self, "Probabilidades", v, [["Cerrar", Callable(), UIKit.GREY]], 696)


func _not_enough_gems() -> void:
	UIKit.popup(self, "Gemas insuficientes", UIKit.label("Consigue gemas en la tienda, en las misiones diarias\no superando hitos de oleadas.", 20, UIKit.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER), [
		["Comprar gemas", func() -> void: show_tab("shop"), UIKit.GREEN], ["Cerrar", Callable(), UIKit.GREY]])


func _on_purchase_success(pid: String) -> void:
	UIKit.message(self, "¡Compra completada!", "%s\n%s" % [GameData.IAP_PRODUCTS[pid]["name"], GameData.IAP_PRODUCTS[pid]["desc"]])
	if sheet_id != "":
		show_tab(sheet_id)
	else:
		show_tab(current_tab)


func _ad_fail(msg: String) -> void:
	UIKit.message(self, "Anuncio", msg)


# ================================================================ Diario
func _day_box(i: int, today: int, available: bool, w: float) -> Control:
	var r: Dictionary = GameData.DAILY_REWARDS[i]
	var claimed := (i < today) or (i == today and not available)
	var is_today := i == today and available
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, 170)
	var bg := UIKit.CREAM_SOFT
	if is_today:
		bg = Color(1.0, 0.88, 0.5)
	elif claimed:
		bg = Color(0.84, 0.92, 0.78)
	var box := PanelContainer.new()
	var st := UIKit.card_style(bg, UIKit.CREAM_DARK if not is_today else Color(0.95, 0.62, 0.12), 18, 6, 3)
	if is_today:
		st.shadow_color = Color(1.0, 0.8, 0.2, 0.85)
		st.shadow_size = 14
		st.shadow_offset = Vector2.ZERO
		st.set_border_width_all(4)
		st.border_width_bottom = 7
	st.content_margin_left = 6
	st.content_margin_right = 6
	box.add_theme_stylebox_override("panel", st)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_child(box)
	var bv := UIKit.vbox(2)
	box.add_child(bv)
	bv.add_child(UIKit.ink("Día %d" % (i + 1), 18, UIKit.INK if not is_today else Color(0.6, 0.3, 0.0), HORIZONTAL_ALIGNMENT_CENTER, true))
	var ic := UIIcon.make(_reward_icon(r), 56 if i < 6 else 72)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(ic)
	bv.add_child(_wrap(UIKit.ink(Meta.reward_text(r), 14, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true), w - 16))
	if claimed:
		box.modulate = Color(1, 1, 1, 0.8)
		var ck := UIIcon.make("check", 56)
		ck.position = Vector2(w * 0.5 - 28, 40)
		holder.add_child(ck)
	if is_today:
		UIKit.pulse(holder, 1.05, 1.0)
	return holder


func _tab_daily(v: VBoxContainer) -> void:
	v.add_child(_wrap(UIKit.ink("Entra cada día para conseguir premios. Si faltas un día puedes recuperar la racha con el escudo.", 17, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 640))
	if Meta.streak_recoverable():
		v.add_child(_wrap(UIKit.ink("¡Ayer no entraste! Usa el escudo de racha para no perderla.", 17, UIKit.RED.darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER, true), 640))
		var sr := UIKit.hbox(10)
		sr.alignment = BoxContainer.ALIGNMENT_CENTER
		sr.add_child(_ibtn("ad", "Recuperar (anuncio)", UIKit.PURPLE, 18, Vector2(260, 60), func() -> void:
			Ads.show_rewarded("streak_shield", func() -> void:
				Meta.recover_streak()
				show_tab("daily"), _ad_fail), 26))
		sr.add_child(_ibtn("gem", "Recuperar (%d)" % GameData.STREAK_SHIELD_GEMS, UIKit.BLUE, 18, Vector2(230, 60), func() -> void:
			if Save.spend_gems(GameData.STREAK_SHIELD_GEMS):
				Meta.recover_streak()
				show_tab("daily")
			else:
				_not_enough_gems(), 26))
		v.add_child(sr)
	elif Meta.streak_broken():
		v.add_child(_wrap(UIKit.ink("¡Perdiste tu racha! Vuelve mañana para no perderla otra vez.", 17, UIKit.RED.darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER, true), 640))
	if Meta.monthly_ready():
		var mb := _ibtn("crown", "Cofre Mensual: reclamar %d gemas" % GameData.MONTHLY_DAILY_GEMS, UIKit.AMBER, 19, Vector2(460, 64), func() -> void:
			UIKit.toast(self, "+%d gemas" % Meta.claim_monthly(), UIKit.GEM)
			show_tab("daily"), 28)
		mb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(mb)
	var today := Meta.daily_index()
	var available := Meta.daily_available()
	var r1 := UIKit.hbox(10)
	r1.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(r1)
	for i in 4:
		r1.add_child(_day_box(i, today, available, 150))
	var r2 := UIKit.hbox(10)
	r2.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(r2)
	for i in range(4, 7):
		r2.add_child(_day_box(i, today, available, 150 if i < 6 else 310))
	var spc := Control.new()
	spc.custom_minimum_size = Vector2(0, 6)
	v.add_child(spc)
	if available:
		var b := _ibtn("gift", "Reclamar día %d" % (today + 1), UIKit.GREEN, 26, Vector2(400, 84), func() -> void:
			var cards := Meta.claim_daily()
			UIKit.toast(self, "+" + Meta.reward_text(GameData.DAILY_REWARDS[today]))
			if cards.is_empty():
				show_tab("daily")
			else:
				UIKit.show_pack_results(self, cards, func() -> void: show_tab("daily")), 40)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b)
	elif Meta.can_double_daily():
		var b2 := _ibtn("ad", "+150 gemas extra" if GameData.DAILY_REWARDS[today].has("legendary") else "Duplicar premio de hoy", UIKit.PURPLE, 22, Vector2(440, 80), func() -> void:
			Ads.show_rewarded("daily_double", func() -> void:
				var cards := Meta.double_daily()
				UIKit.toast(self, "¡Recompensa duplicada!")
				if cards.is_empty():
					show_tab("daily")
				else:
					UIKit.show_pack_results(self, cards, func() -> void: show_tab("daily")), _ad_fail), 36)
		b2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(b2)
	else:
		v.add_child(UIKit.ink("Vuelve mañana para el día %d." % ((today + 1) % 7 + 1), 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	if _quests_claimable() > 0:
		var qb := _ibtn("quest", "Tienes misiones por reclamar", UIKit.TEAL, 19, Vector2(440, 64), func() -> void: show_tab("quests"), 30)
		qb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(qb)


# ================================================================ Misiones
func _tab_quests(v: VBoxContainer) -> void:
	v.add_child(_wrap(UIKit.ink("Completa misiones para ganar gemas. Se renuevan cada día.", 17, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 640))
	var qs := Meta.quests()
	for i in qs.size():
		var q: Dictionary = qs[i]
		var qd := Meta.quest_def(q["id"])
		var goal := int(qd["goal"])
		var prog := mini(int(q["progress"]), goal)
		var box := UIKit.card(UIKit.CREAM_SOFT if not q["claimed"] else Color(0.86, 0.93, 0.8))
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		var qr := UIKit.hbox(12)
		box.add_child(qr)
		var qi := UIIcon.make("check" if q["claimed"] else "quest", 52)
		qi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		qr.add_child(qi)
		var info := UIKit.vbox(6)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.ink(qd["desc"] % goal, 20, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
		info.add_child(UIKit.progress(prog, goal, UIKit.GREEN, 24, "%d / %d" % [prog, goal]))
		qr.add_child(info)
		if q["claimed"]:
			var dn := UIKit.ink("¡Hecha!", 18, UIKit.GREEN.darkened(0.35), HORIZONTAL_ALIGNMENT_CENTER, true)
			dn.custom_minimum_size = Vector2(130, 0)
			qr.add_child(dn)
		else:
			var b := _ibtn("gem", "+%d" % int(qd["gems"]), UIKit.GREEN, 21, Vector2(130, 64), func() -> void:
				if Meta.claim_quest(i):
					UIKit.toast(self, "+%d gemas" % int(qd["gems"]), UIKit.GEM)
					show_tab("quests"), 28)
			b.disabled = prog < goal
			UIKit.set_button_content(b, "gem", "+%d" % int(qd["gems"]), 21, 28)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			qr.add_child(b)
			if prog >= goal:
				UIKit.pulse(b, 1.06)
		v.add_child(box)
	v.add_child(UIKit.icon_label("ad", "Anuncios con recompensa restantes hoy: %d" % Meta.ads_left_today(), 15, UIKit.INK_SOFT, 24, true))
	_weekly_section(v)


## Evento de la semana y misiones semanales (más largas, más gemas y un sobre al completarlas todas).
func _weekly_section(v: VBoxContainer) -> void:
	var ev := Meta.current_event()
	var evc := UIKit.card(Color(0.98, 0.9, 0.7))
	var evr := UIKit.hbox(12)
	evc.add_child(evr)
	evr.add_child(UIIcon.make("crown", 56))
	var evi := UIKit.vbox(2)
	evi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evi.add_child(UIKit.ink("EVENTO SEMANAL: " + ev["name"], 20, UIKit.AMBER.darkened(0.3), HORIZONTAL_ALIGNMENT_LEFT, true))
	evi.add_child(UIKit.ink(ev["desc"], 17, UIKit.INK))
	evi.add_child(UIKit.ink("Quedan %d días" % Meta.event_days_left(), 14, UIKit.INK_SOFT))
	evr.add_child(evi)
	v.add_child(evc)
	_section(v, "Misiones semanales", "calendar")
	var w := Meta.weekly()
	for i in w["list"].size():
		var q: Dictionary = w["list"][i]
		var qd := Meta.weekly_def(q["id"])
		var goal := int(qd["goal"])
		var prog := mini(int(q["progress"]), goal)
		var box := UIKit.card(UIKit.CREAM_SOFT if not q["claimed"] else Color(0.86, 0.93, 0.8))
		box.mouse_filter = Control.MOUSE_FILTER_PASS
		var qr := UIKit.hbox(12)
		box.add_child(qr)
		var info := UIKit.vbox(6)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.ink(qd["desc"] % goal, 19, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
		info.add_child(UIKit.progress(prog, goal, UIKit.BLUE, 22, "%d / %d" % [prog, goal]))
		qr.add_child(info)
		if q["claimed"]:
			qr.add_child(UIKit.ink("¡Hecha!", 18, UIKit.GREEN.darkened(0.35), HORIZONTAL_ALIGNMENT_CENTER, true))
		else:
			var b := _ibtn("gem", "+%d" % int(qd["gems"]), UIKit.GREEN, 21, Vector2(130, 64), func() -> void:
				if Meta.claim_weekly(i):
					UIKit.toast(self, "+%d gemas" % int(qd["gems"]), UIKit.GEM)
					show_tab("quests"), 28)
			b.disabled = prog < goal
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			qr.add_child(b)
		v.add_child(box)
	var bonus := _ibtn("chest", "Completa todas: Sobre de Oro", UIKit.AMBER, 19, Vector2(0, 64), func() -> void:
		var cards := Meta.claim_weekly_bonus()
		if not cards.is_empty():
			UIKit.show_pack_results(self, cards, func() -> void: show_tab("quests")), 30)
	bonus.disabled = not Meta.weekly_bonus_ready()
	v.add_child(bonus)


# ================================================================ Pase de temporada
func _tab_pass(v: VBoxContainer) -> void:
	var s := Meta.season()
	var tier := Meta.season_tier()
	var premium := bool(s["premium"])
	var head := UIKit.card(Color(0.9, 0.86, 1.0))
	var hv := UIKit.vbox(8)
	head.add_child(hv)
	var hr := UIKit.hbox(10)
	hv.add_child(hr)
	var tl := UIKit.ink("Nivel de pase %d / %d" % [tier, GameData.SEASON_TIERS], 22, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tl)
	hr.add_child(UIKit.ink("Quedan %d días" % Meta.season_days_left(), 16, UIKit.PURPLE.darkened(0.3), HORIZONTAL_ALIGNMENT_RIGHT, true))
	var into := int(s["xp"]) % GameData.SEASON_XP_PER_TIER if tier < GameData.SEASON_TIERS else GameData.SEASON_XP_PER_TIER
	hv.add_child(UIKit.progress(into, GameData.SEASON_XP_PER_TIER, UIKit.PURPLE, 26, "%d / %d XP" % [into, GameData.SEASON_XP_PER_TIER]))
	hv.add_child(_wrap(UIKit.ink("Gana XP jugando oleadas, derrotando jefes y abriendo sobres.", 15, UIKit.INK_SOFT), 600))
	if not premium:
		var pp: Dictionary = GameData.IAP_PRODUCTS["season_pass"]
		var pb := _ibtn("crown", "Pase Real · %s" % pp["price"], UIKit.ORANGE, 22, Vector2(0, 72), func() -> void: IAP.purchase("season_pass"), 36)
		hv.add_child(pb)
	else:
		hv.add_child(UIKit.icon_label("crown", "¡Pase Real activo!", 20, UIKit.AMBER, 34, true))
	v.add_child(head)
	# Columnas
	var cols := UIKit.hbox(10)
	var c0 := UIKit.ink("Nv.", 16, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, true)
	c0.custom_minimum_size = Vector2(64, 0)
	cols.add_child(c0)
	var c1 := UIKit.ink("Gratis", 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(c1)
	var c2 := UIKit.icon_label("crown", "Pase Real", 18, UIKit.PURPLE.darkened(0.3), 26, true)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_child(c2)
	v.add_child(cols)
	for t in range(1, GameData.SEASON_TIERS + 1):
		var row := UIKit.hbox(10)
		var reached := t <= tier
		var num := PanelContainer.new()
		num.add_theme_stylebox_override("panel", UIKit.style(UIKit.TEAL if reached else Color(0.75, 0.72, 0.68), Color.WHITE, 32, 3))
		num.custom_minimum_size = Vector2(64, 64)
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nl := UIKit.label(str(t), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.add_child(nl)
		row.add_child(num)
		row.add_child(_pass_cell(t, false, reached, premium))
		row.add_child(_pass_cell(t, true, reached, premium))
		v.add_child(row)


func _pass_cell(t: int, prem: bool, reached: bool, premium_owned: bool) -> Control:
	var r := GameData.season_reward(t, prem)
	var s := Meta.season()
	var claimed: bool = t in s["prem" if prem else "free"]
	var bg := Color(0.93, 0.88, 1.0) if prem else UIKit.CREAM_SOFT
	var box := UIKit.inset(bg, 16)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(0, 84)
	var h := UIKit.hbox(6)
	box.add_child(h)
	var ic := UIIcon.make(_reward_icon(r), 46)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var tl := _wrap(UIKit.ink(Meta.reward_text(r), 13, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true), 100)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(tl)
	if claimed:
		h.add_child(UIIcon.make("check", 40))
		box.modulate = Color(1, 1, 1, 0.7)
	elif prem and not premium_owned:
		h.add_child(UIIcon.make("lock", 36))
	elif reached:
		var b := _btn("¡Coger!", UIKit.GREEN, 16, Vector2(86, 64), func() -> void:
			var cards := Meta.claim_season(t, prem)
			UIKit.toast(self, "+" + Meta.reward_text(r))
			if cards.is_empty():
				show_tab("pass")
			else:
				UIKit.show_pack_results(self, cards, func() -> void: show_tab("pass")))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	return box


# ================================================================ Logros
func _tab_achievements(v: VBoxContainer) -> void:
	v.add_child(_wrap(UIKit.ink("Cada logro tiene varios niveles. ¡Reclama gemas al completar cada uno!", 17, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 640))
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
			var gems: int = GameData.ACHIEVEMENT_GEMS[mini(nxt, GameData.ACHIEVEMENT_GEMS.size() - 1)]
			var b := _ibtn("gem", "+%d" % gems, UIKit.GREEN, 20, Vector2(124, 64), func() -> void:
				var got := Meta.claim_achievement(ad)
				if got > 0:
					UIKit.toast(self, "+%d gemas" % got, UIKit.GEM)
				show_tab("achievements"), 26)
			b.disabled = not Meta.can_claim_achievement(ad)
			UIKit.set_button_content(b, "gem", "+%d" % gems, 20, 26)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
			if not b.disabled:
				UIKit.pulse(b, 1.06)
		v.add_child(box)


# ================================================================ Tesoro del castillo
func _open_treasury() -> void:
	var amount := Meta.treasury_amount()
	var full := Meta.treasury_full()
	var v := UIKit.vbox(10)
	var ic := UIIcon.make("coin_bag", 120)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	if amount > 0:
		UIKit.pulse(ic, 1.06)
	var al := UIKit.icon_label("coin", GameData.format_num(amount), 36, UIKit.INK, 44, true)
	al.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(al)
	var since := Save.now() - int(Save.data["treasury_at"])
	var max_s := int(GameData.TREASURY_MAX_HOURS * 3600.0)
	v.add_child(UIKit.progress(mini(since, max_s), max_s, UIKit.GOLD, 26, "¡Lleno!" if full else "%dh %02dm / %dh" % [since / 3600, (since % 3600) / 60, int(GameData.TREASURY_MAX_HOURS)]))
	v.add_child(_wrap(UIKit.ink("Tu castillo acumula oro aunque no juegues (hasta %d horas). Desbloquear mapas aumenta el ritmo." % int(GameData.TREASURY_MAX_HOURS), 16, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 560))
	var buttons: Array = []
	if amount > 0:
		buttons.append(["Recoger", func() -> void:
			var got := Meta.claim_treasury(false)
			UIKit.toast(self, "+%s oro" % GameData.format_num(got)), UIKit.GREEN])
		buttons.append(["x2 con anuncio", func() -> void:
			Ads.show_rewarded("treasury", func() -> void:
				var got := Meta.claim_treasury(true)
				UIKit.toast(self, "+%s oro" % GameData.format_num(got)), _ad_fail), UIKit.PURPLE])
	buttons.append(["Cerrar", Callable(), UIKit.GREY])
	UIKit.popup(self, "Tesoro del castillo", v, buttons, 640)


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



# ================================================================ Ofertas y ajustes
func _maybe_offer() -> void:
	if _offer_shown or Meta.starter_seconds_left() <= 0:
		return
	_offer_shown = true
	var p: Dictionary = GameData.IAP_PRODUCTS["starter_pack"]
	var v := UIKit.vbox(8)
	var ic := UIIcon.make("chest", 110)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	UIKit.pulse(ic, 1.06)
	v.add_child(_wrap(UIKit.ink(p["desc"], 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true), 520))
	v.add_child(UIKit.ink("Oferta para nuevos comandantes.", 16, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	UIKit.popup(self, "¡OFERTA ESPECIAL!", v, [
		["Comprar %s" % p["price"], func() -> void: IAP.purchase("starter_pack"), UIKit.GREEN],
		["Más tarde", Callable(), UIKit.GREY]])


func _open_settings() -> void:
	SettingsPanel.open(self, false, func() -> void:
		Save.reset_all()
		show_tab("maps"))



# ================================================================ Cooperativo
func _open_coop() -> void:
	var sv := _open_sheet("coop", "Defensa cooperativa", "hero")
	sv.add_child(_wrap(UIKit.ink("Defended juntos un mapa entre 2 jugadores: cada uno construye en su mitad con su propio oro y las vidas son compartidas. Máximo 100 oleadas.", 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER), 640))
	var rw := UIKit.card(Color(0.9, 0.96, 1.0))
	var rv := UIKit.vbox(4)
	rw.add_child(rv)
	rv.add_child(UIKit.ink("Recompensa: 3 gemas cada 10 oleadas, +20 al llegar a la 100", 17, UIKit.BLUE.darkened(0.3), HORIZONTAL_ALIGNMENT_CENTER, true))
	rv.add_child(UIKit.ink("Partidas con recompensa hoy: %d de %d" % [Meta.coop_runs_left(), Meta.COOP_RUNS_PER_DAY], 15, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
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
	sv.add_child(_wrap(UIKit.ink("Para jugar por internet con jugadores de cualquier lugar hace falta un servidor de emparejamiento (ver README).", 14, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER), 640))
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



## Pregunta de edad en el primer inicio (protección de menores).
func _ask_age() -> void:
	var v := UIKit.vbox(10)
	v.add_child(_wrap(UIKit.ink("Antes de empezar, ¿qué edad tienes? Así podemos adaptar las compras del juego.", 19, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true), 560))
	UIKit.popup(self, "¡Bienvenido, comandante!", v, [
		["Menos de 16", func() -> void:
			Save.data["minor"] = true
			Save.data["age_asked"] = true
			Save.save_game()
			show_tab("daily"), UIKit.BLUE],
		["16 o más", func() -> void:
			Save.data["minor"] = false
			Save.data["age_asked"] = true
			Save.save_game()
			show_tab("daily"), UIKit.GREEN]])



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



## Ventana de ganancias por ausencia: monedas del tesoro acumuladas mientras no jugabas
## (x2 con anuncio; automático con "Sin Anuncios").
func _offline_earnings(away: int) -> void:
	var amount := Meta.treasury_amount()
	var v := UIKit.vbox(10)
	var ic := UIIcon.make("coin_bag", 96)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var hours := away / 3600
	var mins := (away % 3600) / 60
	v.add_child(UIKit.ink("Estuviste fuera %dh %02dm y tu fortaleza siguió trabajando." % [hours, mins], 19, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	if Ads.has_no_ads():
		var got := Meta.claim_treasury(true)
		v.add_child(UIKit.icon_label("coin", "+%s oro (x2 automático)" % GameData.format_num(got), 26, UIKit.AMBER.darkened(0.3), 40, true))
		UIKit.popup(self, "¡Bienvenido de vuelta!", v, [["Genial", Callable(), UIKit.GREEN]])
		return
	v.add_child(UIKit.icon_label("coin", "+%s oro" % GameData.format_num(amount), 26, UIKit.AMBER.darkened(0.3), 40, true))
	UIKit.popup(self, "¡Bienvenido de vuelta!", v, [
		["Recoger", func() -> void:
			var got := Meta.claim_treasury(false)
			UIKit.toast(self, "+%s oro" % GameData.format_num(got), UIKit.GOLD), UIKit.GREEN],
		["x2 con anuncio", func() -> void:
			Ads.show_rewarded("offline_x2", func() -> void:
				var got := Meta.claim_treasury(true)
				UIKit.toast(self, "+%s oro" % GameData.format_num(got), UIKit.GOLD), func(_m: String) -> void:
				Meta.claim_treasury(false)), UIKit.PURPLE]])
