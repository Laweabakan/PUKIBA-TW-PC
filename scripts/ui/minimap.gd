class_name Minimap
extends Control
## Minimapa de la batalla (PC): el tablero entero en pequeño con caminos, agua, torres,
## enemigos (los jefes más grandes) y el recuadro de lo que se ve en pantalla.
## Clic o arrastrar sobre él mueve la cámara a ese punto.

var game: Node
var _base: ImageTexture # suelo, agua, caminos y obstáculos (no cambian)
var _dragging := false
var _t := 0.0


func setup(g: Node, width: float) -> void:
	game = g
	var cols := float(GameData.COLS)
	var rows := float(GameData.ROWS)
	custom_minimum_size = Vector2(width, width * rows / cols)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # casillas nítidas
	tooltip_text = "Minimapa: haz clic para mover la cámara"
	_build_base()


## Imagen fija del tablero (1 píxel por casilla, se escala sin suavizar).
func _build_base() -> void:
	var cols := GameData.COLS
	var rows := GameData.ROWS
	var img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	var ground: Color = game.map_def["ground"]
	var path: Color = game.map_def["path"]
	for x in cols:
		for y in rows:
			var c := Vector2i(x, y)
			var col := ground.lightened(0.04) if (x + y) % 2 == 0 else ground
			if game.path_cells.has(c):
				col = path.lightened(0.1)
			elif game.blocked.get(c, "") == "water":
				col = Color(0.3, 0.55, 0.9)
			elif game.blocked.has(c):
				col = ground.darkened(0.35)
			elif game.cell_h(c) > 0.0:
				col = ground.lightened(0.12)
			img.set_pixel(x, y, col)
	_base = ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if game == null or not is_instance_valid(game) or _base == null:
		return
	var s := size.x / float(GameData.COLS)
	var r := Rect2(Vector2.ZERO, size)
	# Marco con sombra
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.07, 0.14, 0.9)
	frame.border_color = UIKit.GOLD.darkened(0.15)
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(10)
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 8
	frame.expand_margin_left = 6
	frame.expand_margin_right = 6
	frame.expand_margin_top = 6
	frame.expand_margin_bottom = 6
	draw_style_box(frame, r)
	draw_texture_rect(_base, r, false)
	# Torres y héroes
	for t in game.towers.values():
		if not is_instance_valid(t):
			continue
		var tc: Vector2i = t.cell
		var col: Color = UIKit.PURPLE if t.is_hero else (t.def.get("color", Color.WHITE) as Color)
		var rr := Rect2(Vector2(tc) * s + Vector2(s * 0.12, s * 0.12), Vector2(s * 0.76, s * 0.76))
		draw_rect(rr.grow(1.0), Color(0, 0, 0, 0.7))
		draw_rect(rr, col.lightened(0.15))
	# Castillo
	var cp := _plane_to_map(game.castle_plane, s)
	cp = Vector2(clampf(cp.x, s, size.x - s), clampf(cp.y, s, size.y - s))
	draw_circle(cp, s * 1.3, Color(0.15, 0.2, 0.4))
	draw_circle(cp, s * 1.0, UIKit.GOLD)
	# Enemigos (parpadeo suave de los jefes)
	for e in game.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var ep := _plane_to_map(e.position, s)
		if e.is_boss:
			var pulse := 1.0 + 0.25 * sin(_t * 8.0)
			draw_circle(ep, s * 0.9 * pulse + 1.0, Color(0, 0, 0, 0.7))
			draw_circle(ep, s * 0.9 * pulse, Color(1.0, 0.2, 0.15))
		else:
			draw_circle(ep, maxf(s * 0.32, 2.0) + 1.0, Color(0, 0, 0, 0.6))
			draw_circle(ep, maxf(s * 0.32, 2.0), Color(1.0, 0.85, 0.3) if e.elite else Color(1.0, 0.35, 0.3))
	# Lo que se ve en pantalla
	var vp := get_viewport_rect().size
	var corners: Array = [Vector2(0, 84), Vector2(vp.x, 84), Vector2(vp.x, vp.y - 96), Vector2(0, vp.y - 96)]
	var poly := PackedVector2Array()
	for c in corners:
		var p: Vector2 = game.plane_from_screen(c)
		if p.x < -90000:
			return
		var m := _plane_to_map(p, s)
		poly.append(Vector2(clampf(m.x, 0, size.x), clampf(m.y, 0, size.y)))
	poly.append(poly[0])
	draw_polyline(poly, Color(1, 1, 1, 0.95), 2.0, true)


func _plane_to_map(p: Vector2, s: float) -> Vector2:
	return (p - GameData.GRID_OFFSET) / float(GameData.TILE) * s


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_dragging = ev.pressed
		if ev.pressed:
			_jump(ev.position)
		accept_event()
	elif ev is InputEventMouseMotion and _dragging:
		_jump(ev.position)
		accept_event()


func _jump(local: Vector2) -> void:
	var s := size.x / float(GameData.COLS)
	var cell := local / s
	game.cam_focus = Vector2(cell.x - GameData.COLS * 0.5, cell.y - GameData.ROWS * 0.5)
	game._apply_camera()
