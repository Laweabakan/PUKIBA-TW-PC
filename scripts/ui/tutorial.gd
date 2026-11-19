class_name Tutorial
extends CanvasLayer
## Tutorial básico de la primera partida, sobre el propio juego (sin bloquear nada):
##   1) colocar una torre (Construir → elegir torre → tocar casilla → tocar otra vez),
##   2) comprar una mejora en La Fortaleza (tocando el castillo),
##   3) comprar y abrir un sobre de torres con oro en la Tienda.
## Una flecha que rebota señala dónde tocar y un globo explica qué hacer.
## El progreso se guarda en Save.data["tutorial"] (0..3; 3 = terminado).

const DONE := 3
const GIFT_GOLD := 1500
const BUBBLE_POS := Vector2(660, 100) # arriba, centrado (pantalla de 1920x1080)
const BUBBLE_SIDE := Vector2(10, 160) # a la izquierda, cuando hay una ventana abierta en el centro

var game: Node
var _bubble: PanelContainer
var _text: Label
var _arrow: Arrow
var _skip: Button
var _upgrades_before := -1
var _t := 0.0
var _scrolled := false


static func step() -> int:
	return int(Save.data.get("tutorial", 0))


static func active() -> bool:
	return step() < DONE


func setup(g: Node) -> void:
	game = g
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_arrow = Arrow.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.size = Vector2(64, 64)
	root.add_child(_arrow)
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UIKit.card_style(UIKit.CREAM, UIKit.GOLD.darkened(0.2), 22, 6, 4)
	st.set_border_width_all(4)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	_bubble.add_theme_stylebox_override("panel", st)
	_bubble.position = BUBBLE_POS
	_bubble.custom_minimum_size = Vector2(600, 0)
	root.add_child(_bubble)
	var v := UIKit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(v)
	var head := UIKit.ink("TUTORIAL", 15, UIKit.AMBER.darkened(0.3), HORIZONTAL_ALIGNMENT_CENTER, true)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	_text = UIKit.ink("", 20, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(560, 0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_text)
	_skip = UIKit.button("Saltar tutorial", UIKit.GREY, 14, Vector2(150, 40))
	_skip.position = Vector2(20, 100)
	_skip.pressed.connect(func() -> void: _finish(false))
	root.add_child(_skip)
	Meta.pack_opened.connect(_on_pack_opened)


func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game) or not active():
		queue_free()
		return
	_t += delta
	match step():
		0: _step_build()
		1: _step_fortress()
		2: _step_pack()


# ---------------------------------------------------------------- Paso 1: construir
func _step_build() -> void:
	# Las oleadas esperan a que el jugador coloque su primera torre
	game.auto_timer = maxf(game.auto_timer, 9.5)
	var built := false
	for t in game.towers.values():
		if not t.is_hero:
			built = true
	if built:
		_advance("¡Bien hecho! Tu primera torre ya defiende el camino.")
		return
	if not game.shop_panel.visible:
		_say("Pulsa CONSTRUIR (o la tecla B) para ver tus torres.")
		_point_rect(game.btn_build.get_global_rect())
	elif game.build_id == "":
		_say("Elige la Torre de Arqueros.")
		var b: Control = game.shop_buttons.get("archer")
		if b != null:
			_point_rect(b.get_global_rect())
	elif game.preview_cell == Vector2i(-99, -99):
		_say("Pasa el ratón por una casilla libre junto al camino: verás el alcance de la torre.")
		_point_screen(game.screen_pos(GameData.cell_center(_good_cell())), true)
	else:
		_say("Haz clic en esa casilla para construir la torre. (Clic derecho: cancelar)")
		_point_screen(game.screen_pos(GameData.cell_center(game.preview_cell)), true)


## Casilla libre junto al camino, cerca del centro del tablero (sugerencia del tutorial).
func _good_cell() -> Vector2i:
	var best := Vector2i(1, 1)
	var best_d := 1e9
	var mid := Vector2(GameData.COLS * 0.5, GameData.ROWS * 0.55)
	for x in GameData.COLS:
		for y in GameData.ROWS:
			var c := Vector2i(x, y)
			if game.path_cells.has(c) or game.blocked.has(c) or game.towers.has(c):
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if game.path_cells.has(c + d):
					near = true
			if near and Vector2(c).distance_to(mid) < best_d:
				best_d = Vector2(c).distance_to(mid)
				best = c
	return best


# ---------------------------------------------------------------- Paso 2: La Fortaleza
func _step_fortress() -> void:
	var lv := _total_upgrades()
	if _upgrades_before < 0:
		_upgrades_before = lv
		# Asegura que pueda pagar la primera mejora
		var cheapest := 1 << 30
		for id in GameData.UPGRADES.keys():
			cheapest = mini(cheapest, Meta.upgrade_cost(id))
		if Save.coins() < cheapest:
			Save.add_coins(cheapest - Save.coins())
			UIKit.toast(game.ui, "Regalo del tutorial: oro para tu primera mejora", UIKit.GOLD)
	if lv > _upgrades_before:
		_advance("¡Mejora comprada! Las mejoras de La Fortaleza son permanentes en todos los mapas.")
		return
	var popup_open: bool = game._fortress_popup != null and is_instance_valid(game._fortress_popup)
	_bubble.position = BUBBLE_SIDE if popup_open else BUBBLE_POS # que no tape las mejoras
	if popup_open:
		_say("Compra una mejora con oro (por ejemplo, Forja Real: más daño para todas las torres).")
		_arrow.visible = false
	else:
		_say("Haz clic en el CASTILLO (o pulsa F) para abrir La Fortaleza y comprar mejoras permanentes.")
		_point_screen(game.screen_pos(game.castle_plane, 1.2), true)


func _total_upgrades() -> int:
	var n := 0
	for id in GameData.UPGRADES.keys():
		n += Save.upgrade_level(id)
	for id in GameData.GEM_UPGRADES.keys():
		n += Save.gem_upgrade_level(id)
	return n


# ---------------------------------------------------------------- Paso 3: abrir un sobre
func _step_pack() -> void:
	# Asegura oro para el primer sobre de torres (regalo del tutorial)
	var price := Meta.pack_price("tower_bronze")
	if Save.coins() < price:
		Save.add_coins(price - Save.coins())
		UIKit.toast(game.ui, "Regalo del tutorial: oro para tu primer sobre", UIKit.GOLD)
	var overlay_open: bool = game._menu_overlay != null and is_instance_valid(game._menu_overlay)
	var fortress_open: bool = game._fortress_popup != null and is_instance_valid(game._fortress_popup)
	_bubble.position = BUBBLE_SIDE if overlay_open or fortress_open else BUBBLE_POS # que no tape la tienda ni las mejoras
	if fortress_open and not overlay_open:
		_say("¡Bien! Pulsa «Volver a la batalla» y luego abre tu primer sobre en la TIENDA.")
		_arrow.visible = false
	elif overlay_open:
		_say("Compra un sobre de Torres de Bronce con oro: cada carta nueva desbloquea una torre.")
		if not _scrolled:
			_scrolled = true
			game._menu_overlay.call_deferred("focus_packs")
		_arrow.visible = false
	else:
		_say("Las torres nuevas salen en los sobres: pulsa TIENDA (el cofre, al lado de Cartas).")
		var holder: Control = game.btn_shop
		if holder != null:
			_point_rect(holder.get_global_rect())
		else:
			_arrow.visible = false


func _on_pack_opened(_results: Array) -> void:
	if step() == 2:
		_finish(true)


# ---------------------------------------------------------------- Utilidades
func _advance(msg: String) -> void:
	# Cierra el panel de construir para que se vea el castillo en el siguiente paso
	if game.shop_panel.visible:
		game._toggle_build_menu(game.shop_mode)
	Save.data["tutorial"] = step() + 1
	Save.save_game()
	UIKit.toast(game.ui, msg, UIKit.GREEN)
	Audio.sfx("levelup", -4.0, 0.0)
	_upgrades_before = -1


func _finish(completed: bool) -> void:
	Save.data["tutorial"] = DONE
	if completed:
		Save.add_coins(GIFT_GOLD)
		UIKit.toast(game.ui, "¡Tutorial completado! +%d oro" % GIFT_GOLD, UIKit.GOLD)
	Save.save_game()
	queue_free()


func _say(text: String) -> void:
	if _text.text != text:
		_text.text = text
		UIKit.pop(_bubble, 1.06)


## Flecha encima de un botón (apunta hacia abajo).
func _point_rect(r: Rect2) -> void:
	_point_screen(Vector2(r.get_center().x, r.position.y), false)


## Flecha que rebota apuntando a un punto de la pantalla.
func _point_screen(p: Vector2, world_point: bool) -> void:
	_arrow.visible = true
	var bob := sin(_t * 6.0) * 10.0
	_arrow.position = p - Vector2(32, 70 + bob)
	_arrow.ring = world_point


## Flecha dorada con contorno (y un aro en el punto si señala algo del tablero).
class Arrow extends Control:
	var ring := false

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(18, 0), Vector2(46, 0), Vector2(46, 30), Vector2(62, 30), Vector2(32, 62), Vector2(2, 30), Vector2(18, 30)])
		var outline := PackedVector2Array(pts)
		outline.append(pts[0])
		draw_colored_polygon(pts, Color(1.0, 0.82, 0.25))
		draw_polyline(outline, Color(0.35, 0.2, 0.05), 4.0)
		if ring:
			var a := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
			draw_arc(Vector2(32, 72), 22.0 + 6.0 * a, 0, TAU, 32, Color(1, 0.9, 0.3, 0.9), 4.0)
