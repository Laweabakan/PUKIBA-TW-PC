class_name UIIcon
extends Control
## Iconos dibujados por código (sin arte externo): monedas, gemas, corazón, bandera...
## Se dibujan en un espacio de 100x100 que se escala al tamaño del control.
## Uso: UIIcon.make("coin", 36)

const INK := Color(0.2, 0.12, 0.1, 0.95)

var kind := "coin":
	set(v):
		kind = v
		queue_redraw()
## Si su alfa es > 0 reemplaza el color principal de los iconos monocromos (pausa, play, +...).
var tint := Color(0, 0, 0, 0):
	set(v):
		tint = v
		queue_redraw()
## Grosor del contorno oscuro (en unidades de 100). 0 = sin contorno.
var outline := 10.0


static func make(icon_kind: String, px := 32.0, icon_tint := Color(0, 0, 0, 0)) -> UIIcon:
	var i := UIIcon.new()
	i.kind = icon_kind
	i.tint = icon_tint
	i.custom_minimum_size = Vector2(px, px)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


# ---------------------------------------------------------------- Utilidades de dibujo
var _base := Transform2D.IDENTITY


func _set_rot(angle: float) -> void:
	var r := Transform2D(angle, Vector2(50, 50)) * Transform2D(0.0, Vector2(-50, -50))
	draw_set_transform_matrix(_base * r)


func _poly(pts: PackedVector2Array, col: Color, ol := -1.0) -> void:
	var w := outline if ol < 0.0 else ol
	if w > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, INK, w, true)
		for p in pts:
			draw_circle(p, w * 0.5, INK)
	draw_colored_polygon(pts, col)


func _circ(c: Vector2, r: float, col: Color, ol := -1.0) -> void:
	var w := outline if ol < 0.0 else ol
	if w > 0.0:
		draw_circle(c, r + w * 0.5, INK)
	draw_circle(c, r, col)


func _line(a: Vector2, b: Vector2, col: Color, w: float, ol := -1.0) -> void:
	var o := outline if ol < 0.0 else ol
	if o > 0.0:
		draw_line(a, b, INK, w + o, true)
		draw_circle(a, (w + o) * 0.5, INK)
		draw_circle(b, (w + o) * 0.5, INK)
	draw_line(a, b, col, w, true)
	draw_circle(a, w * 0.5, col)
	draw_circle(b, w * 0.5, col)


func _rrect(r: Rect2, col: Color, radius := 10, ol := -1.0) -> void:
	var w := outline if ol < 0.0 else ol
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	if w > 0.0:
		sb.border_color = INK
		sb.set_border_width_all(int(w * 0.5))
		sb.expand_margin_left = w * 0.5
		sb.expand_margin_right = w * 0.5
		sb.expand_margin_top = w * 0.5
		sb.expand_margin_bottom = w * 0.5
		sb.border_blend = false
	draw_style_box(sb, r)


func _star_pts(c: Vector2, r_out: float, r_in: float, n := 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := -PI / 2.0 + PI * float(i) / float(n)
		var r := r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _main(def: Color) -> Color:
	return tint if tint.a > 0.0 else def


# ---------------------------------------------------------------- Dibujo
func _draw() -> void:
	var s := minf(size.x, size.y) / 100.0
	if s <= 0.0:
		return
	var o := (size - Vector2(100, 100) * s) * 0.5
	_base = Transform2D(0.0, Vector2(s, s), 0.0, o)
	draw_set_transform_matrix(_base)
	match kind:
		"coin": _d_coin()
		"gem": _d_gem()
		"heart": _d_heart()
		"flag": _d_flag()
		"sword": _d_sword()
		"range", "target": _d_target()
		"speed", "bolt": _d_bolt()
		"star": _d_star()
		"star_off": _d_star(true)
		"lock": _d_lock()
		"pause": _d_pause()
		"play": _d_play()
		"fast": _d_fast()
		"auto": _d_auto()
		"eye": _d_eye()
		"gear": _d_gear()
		"plus": _d_plus()
		"check": _d_check()
		"close": _d_close()
		"map": _d_map()
		"upgrade": _d_upgrade()
		"cards": _d_cards()
		"shop", "chest": _d_chest()
		"calendar": _d_calendar()
		"crown": _d_crown()
		"skull": _d_skull()
		"hammer": _d_hammer()
		"shield": _d_shield()
		"ad": _d_ad()
		"castle": _d_castle()
		"coin_bag": _d_coin_bag()
		"hero": _d_hero()
		"sell": _d_sell()
		"info": _d_info()
		"trophy": _d_trophy()
		"arrow_l": _d_arrow(true)
		"arrow_r": _d_arrow(false)
		"quest": _d_quest()
		"gift": _d_gift()
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _d_coin() -> void:
	_circ(Vector2(50, 50), 44, Color(0.96, 0.66, 0.12))
	draw_circle(Vector2(50, 47), 40, Color(1.0, 0.83, 0.25))
	draw_circle(Vector2(50, 50), 29, Color(0.93, 0.62, 0.1))
	draw_circle(Vector2(50, 48), 27, Color(1.0, 0.78, 0.2))
	draw_colored_polygon(_star_pts(Vector2(50, 49), 17, 7.5), Color(0.98, 0.95, 0.7))
	draw_arc(Vector2(50, 47), 34, PI * 1.08, PI * 1.45, 10, Color(1, 1, 0.9, 0.85), 5, true)


func _d_gem() -> void:
	var outer := PackedVector2Array([Vector2(28, 18), Vector2(72, 18), Vector2(92, 40), Vector2(50, 90), Vector2(8, 40)])
	_poly(outer, Color(0.22, 0.62, 0.95))
	draw_colored_polygon(PackedVector2Array([Vector2(28, 18), Vector2(72, 18), Vector2(92, 40), Vector2(8, 40)]), Color(0.55, 0.9, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(30, 40), Vector2(70, 40), Vector2(50, 90)]), Color(0.32, 0.75, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(38, 18), Vector2(62, 18), Vector2(70, 40), Vector2(30, 40)]), Color(0.75, 0.97, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(30, 23), Vector2(40, 23), Vector2(24, 36)]), Color(1, 1, 1, 0.9))


func _d_heart() -> void:
	var col := Color(0.97, 0.3, 0.38)
	var w := outline
	if w > 0.0:
		draw_circle(Vector2(31, 38), 22 + w * 0.5, INK)
		draw_circle(Vector2(69, 38), 22 + w * 0.5, INK)
		draw_colored_polygon(PackedVector2Array([Vector2(9 - w * 0.4, 46), Vector2(91 + w * 0.4, 46), Vector2(50, 91 + w * 0.7)]), INK)
	draw_circle(Vector2(31, 38), 22, col)
	draw_circle(Vector2(69, 38), 22, col)
	draw_colored_polygon(PackedVector2Array([Vector2(9.5, 45), Vector2(90.5, 45), Vector2(50, 90)]), col)
	draw_circle(Vector2(29, 33), 8, Color(1, 0.85, 0.88, 0.9))


func _d_flag() -> void:
	_line(Vector2(24, 12), Vector2(24, 90), Color(0.62, 0.42, 0.24), 8)
	var fl := PackedVector2Array([Vector2(28, 14), Vector2(56, 10), Vector2(86, 18), Vector2(70, 32), Vector2(86, 48), Vector2(56, 42), Vector2(28, 48)])
	_poly(fl, Color(0.25, 0.7, 0.85))
	draw_colored_polygon(PackedVector2Array([Vector2(28, 14), Vector2(56, 10), Vector2(86, 18), Vector2(28, 24)]), Color(0.5, 0.88, 0.95))
	_circ(Vector2(24, 10), 6, Color(1.0, 0.8, 0.25), outline * 0.6)


func _d_sword() -> void:
	_set_rot(PI / 4.0)
	_poly(PackedVector2Array([Vector2(50, 2), Vector2(59, 14), Vector2(59, 62), Vector2(41, 62), Vector2(41, 14)]), Color(0.86, 0.9, 0.96))
	draw_colored_polygon(PackedVector2Array([Vector2(50, 2), Vector2(59, 14), Vector2(59, 62), Vector2(50, 62)]), Color(0.68, 0.74, 0.84))
	_rrect(Rect2(28, 61, 44, 10), Color(1.0, 0.76, 0.22), 4)
	_rrect(Rect2(45, 71, 10, 17), Color(0.55, 0.32, 0.2), 3)
	_circ(Vector2(50, 92), 6, Color(1.0, 0.76, 0.22))
	draw_set_transform_matrix(_base)


func _d_target() -> void:
	_circ(Vector2(50, 50), 42, Color(1, 0.97, 0.92))
	draw_circle(Vector2(50, 50), 32, Color(0.95, 0.35, 0.35))
	draw_circle(Vector2(50, 50), 22, Color(1, 0.97, 0.92))
	draw_circle(Vector2(50, 50), 12, Color(0.95, 0.35, 0.35))


func _d_bolt() -> void:
	_poly(PackedVector2Array([Vector2(60, 4), Vector2(18, 56), Vector2(46, 56), Vector2(36, 96), Vector2(84, 40), Vector2(55, 40), Vector2(70, 4)]), _main(Color(1.0, 0.85, 0.2)))
	draw_colored_polygon(PackedVector2Array([Vector2(60, 8), Vector2(66, 8), Vector2(50, 40), Vector2(30, 52)]), Color(1, 1, 0.85, 0.7))


func _d_star(off := false) -> void:
	var col := Color(0.55, 0.52, 0.5) if off else _main(Color(1.0, 0.8, 0.2))
	_poly(_star_pts(Vector2(50, 53), 46, 21), col)
	if not off:
		draw_colored_polygon(_star_pts(Vector2(46, 47), 18, 8), Color(1, 0.97, 0.7, 0.75))


func _d_lock() -> void:
	draw_arc(Vector2(50, 44), 20, PI, TAU, 16, INK, 16 + outline * 0.6, true)
	draw_arc(Vector2(50, 44), 20, PI, TAU, 16, Color(0.75, 0.77, 0.82), 10, true)
	_line(Vector2(30, 44), Vector2(30, 50), Color(0.75, 0.77, 0.82), 10, 6)
	_line(Vector2(70, 44), Vector2(70, 50), Color(0.75, 0.77, 0.82), 10, 6)
	_rrect(Rect2(18, 46, 64, 46), _main(Color(1.0, 0.75, 0.25)), 12)
	draw_circle(Vector2(50, 64), 7, INK)
	draw_rect(Rect2(47, 64, 6, 14), INK)


func _d_pause() -> void:
	_rrect(Rect2(24, 18, 18, 64), _main(Color.WHITE), 7)
	_rrect(Rect2(58, 18, 18, 64), _main(Color.WHITE), 7)


func _d_play() -> void:
	_poly(PackedVector2Array([Vector2(30, 16), Vector2(86, 50), Vector2(30, 84)]), _main(Color.WHITE))


func _d_fast() -> void:
	_poly(PackedVector2Array([Vector2(10, 20), Vector2(50, 50), Vector2(10, 80)]), _main(Color.WHITE))
	_poly(PackedVector2Array([Vector2(48, 20), Vector2(90, 50), Vector2(48, 80)]), _main(Color.WHITE))


func _d_auto() -> void:
	var col := _main(Color.WHITE)
	var c := Vector2(50, 50)
	for k in 2:
		var a0 := 0.35 + PI * k
		var a1 := PI - 0.45 + PI * k
		draw_arc(c, 32, a0, a1, 18, INK, 12 + outline, true)
		draw_arc(c, 32, a0, a1, 18, col, 12, true)
		var p := c + Vector2(cos(a1), sin(a1)) * 32.0
		var d := Vector2(-sin(a1), cos(a1))
		var rad := Vector2(cos(a1), sin(a1))
		_poly(PackedVector2Array([p + d * 16.0, p + rad * 15.0, p - rad * 15.0]), col)


func _d_eye() -> void:
	var pts := PackedVector2Array()
	for t in 17:
		pts.append(Vector2(8 + 84.0 * t / 16.0, 50 - 30.0 * sin(PI * t / 16.0)))
	for t in range(15, 0, -1):
		pts.append(Vector2(8 + 84.0 * t / 16.0, 50 + 30.0 * sin(PI * t / 16.0)))
	_poly(pts, Color(1, 1, 1))
	draw_circle(Vector2(50, 50), 18, Color(0.25, 0.6, 0.95))
	draw_circle(Vector2(50, 50), 9, INK)
	draw_circle(Vector2(44, 44), 5, Color(1, 1, 1, 0.9))


func _d_gear() -> void:
	var pts := PackedVector2Array()
	var n := 8
	var step := TAU / float(n)
	for k in n:
		var a0 := step * k
		for e in [[-0.32, 33.0], [-0.17, 45.0], [0.17, 45.0], [0.32, 33.0]]:
			var a: float = a0 + step * float(e[0])
			pts.append(Vector2(50, 50) + Vector2(cos(a), sin(a)) * float(e[1]))
	_poly(pts, _main(Color(0.86, 0.9, 0.96)))
	draw_circle(Vector2(50, 50), 15, INK)
	draw_circle(Vector2(50, 50), 9, _main(Color(0.86, 0.9, 0.96)).darkened(0.35))


func _d_plus() -> void:
	_line(Vector2(50, 18), Vector2(50, 82), _main(Color.WHITE), 18)
	_line(Vector2(18, 50), Vector2(82, 50), _main(Color.WHITE), 18)
	draw_line(Vector2(50, 22), Vector2(50, 78), _main(Color.WHITE), 18)


func _d_check() -> void:
	var pts := PackedVector2Array([Vector2(18, 52), Vector2(40, 74), Vector2(84, 26)])
	if outline > 0.0:
		draw_polyline(pts, INK, 18 + outline, true)
		for p in pts:
			draw_circle(p, (18 + outline) * 0.5, INK)
	draw_polyline(pts, _main(Color(0.45, 0.9, 0.35)), 18, true)
	for p in pts:
		draw_circle(p, 9, _main(Color(0.45, 0.9, 0.35)))


func _d_close() -> void:
	_line(Vector2(24, 24), Vector2(76, 76), _main(Color.WHITE), 16)
	_line(Vector2(76, 24), Vector2(24, 76), _main(Color.WHITE), 16)
	draw_line(Vector2(28, 28), Vector2(72, 72), _main(Color.WHITE), 16)


func _d_map() -> void:
	var pts := PackedVector2Array([Vector2(8, 20), Vector2(36, 10), Vector2(64, 20), Vector2(92, 10), Vector2(92, 80), Vector2(64, 90), Vector2(36, 80), Vector2(8, 90)])
	_poly(pts, Color(0.99, 0.9, 0.68))
	draw_colored_polygon(PackedVector2Array([Vector2(36, 10), Vector2(64, 20), Vector2(64, 90), Vector2(36, 80)]), Color(0.9, 0.78, 0.55))
	for seg in [[Vector2(18, 70), Vector2(30, 56)], [Vector2(38, 50), Vector2(52, 44)], [Vector2(60, 40), Vector2(70, 36)]]:
		draw_line(seg[0], seg[1], Color(0.85, 0.3, 0.25), 5, true)
	_line(Vector2(72, 26), Vector2(84, 38), Color(0.9, 0.25, 0.2), 6, 0)
	_line(Vector2(84, 26), Vector2(72, 38), Color(0.9, 0.25, 0.2), 6, 0)


func _d_upgrade() -> void:
	_poly(PackedVector2Array([Vector2(50, 6), Vector2(90, 48), Vector2(66, 48), Vector2(66, 92), Vector2(34, 92), Vector2(34, 48), Vector2(10, 48)]), _main(Color(0.45, 0.88, 0.3)))
	draw_colored_polygon(PackedVector2Array([Vector2(50, 12), Vector2(56, 18), Vector2(28, 44), Vector2(20, 44)]), Color(1, 1, 1, 0.45))


func _d_cards() -> void:
	_set_rot(-0.28)
	_rrect(Rect2(18, 18, 46, 66), Color(0.35, 0.55, 0.95), 9)
	draw_rect(Rect2(26, 26, 30, 50), Color(0.55, 0.72, 1.0))
	_set_rot(0.22)
	_rrect(Rect2(38, 14, 46, 66), Color(1.0, 0.95, 0.82), 9)
	draw_colored_polygon(_star_pts(Vector2(61, 47), 16, 7), Color(1.0, 0.72, 0.15))
	draw_set_transform_matrix(_base)


func _d_chest() -> void:
	var lid := PackedVector2Array()
	for t in 13:
		var a := PI + PI * t / 12.0
		lid.append(Vector2(50 + cos(a) * 40.0, 44 + sin(a) * 26.0))
	_poly(lid, Color(0.78, 0.45, 0.22))
	_rrect(Rect2(10, 44, 80, 44), Color(0.68, 0.38, 0.18), 6)
	draw_rect(Rect2(10, 44, 80, 6), Color(1.0, 0.76, 0.22))
	draw_rect(Rect2(22, 22, 9, 66), Color(1.0, 0.76, 0.22))
	draw_rect(Rect2(69, 22, 9, 66), Color(1.0, 0.76, 0.22))
	_rrect(Rect2(42, 40, 16, 20), Color(1.0, 0.85, 0.35), 4, 6)
	draw_circle(Vector2(50, 49), 3, INK)


func _d_calendar() -> void:
	_rrect(Rect2(12, 18, 76, 72), Color(1, 0.98, 0.94), 12)
	_rrect(Rect2(12, 18, 76, 22), Color(0.95, 0.35, 0.35), 10, 0)
	draw_rect(Rect2(12, 30, 76, 10), Color(0.95, 0.35, 0.35))
	for x in [32, 68]:
		_rrect(Rect2(x - 5, 8, 10, 20), Color(0.85, 0.85, 0.9), 4, 6)
	for r in 2:
		for c in 3:
			draw_rect(Rect2(24 + c * 20, 50 + r * 18, 12, 10), Color(0.6, 0.55, 0.6) if r + c != 3 else Color(0.95, 0.35, 0.35))


func _d_crown() -> void:
	var pts := PackedVector2Array([Vector2(10, 80), Vector2(8, 32), Vector2(30, 52), Vector2(50, 18), Vector2(70, 52), Vector2(92, 32), Vector2(90, 80)])
	_poly(pts, Color(1.0, 0.8, 0.22))
	draw_rect(Rect2(10, 68, 80, 12), Color(0.92, 0.62, 0.12))
	draw_circle(Vector2(50, 74), 5, Color(0.95, 0.3, 0.35))
	draw_circle(Vector2(28, 74), 4, Color(0.35, 0.75, 1.0))
	draw_circle(Vector2(72, 74), 4, Color(0.35, 0.75, 1.0))
	for p in [Vector2(8, 30), Vector2(50, 16), Vector2(92, 30)]:
		_circ(p, 6, Color(1.0, 0.9, 0.45), outline * 0.6)
	draw_colored_polygon(PackedVector2Array([Vector2(16, 44), Vector2(28, 56), Vector2(16, 64)]), Color(1, 1, 0.85, 0.6))


func _d_skull() -> void:
	_circ(Vector2(50, 42), 34, Color(0.96, 0.94, 0.88))
	_rrect(Rect2(30, 60, 40, 26), Color(0.96, 0.94, 0.88), 8)
	draw_circle(Vector2(50, 42), 34, Color(0.96, 0.94, 0.88))
	draw_circle(Vector2(37, 44), 10, INK)
	draw_circle(Vector2(63, 44), 10, INK)
	draw_colored_polygon(PackedVector2Array([Vector2(50, 56), Vector2(45, 66), Vector2(55, 66)]), INK)
	for x in [40, 50, 60]:
		draw_line(Vector2(x, 74), Vector2(x, 86), INK, 3)


func _d_hammer() -> void:
	_set_rot(-PI / 4.0)
	_rrect(Rect2(44, 30, 12, 64), Color(0.62, 0.4, 0.22), 5)
	_rrect(Rect2(22, 8, 56, 26), Color(0.72, 0.76, 0.82), 6)
	draw_rect(Rect2(22, 8, 56, 8), Color(0.88, 0.9, 0.95))
	draw_set_transform_matrix(_base)


func _d_shield() -> void:
	var pts := PackedVector2Array([Vector2(50, 6), Vector2(88, 18), Vector2(84, 56), Vector2(50, 94), Vector2(16, 56), Vector2(12, 18)])
	_poly(pts, Color(1.0, 0.78, 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(50, 16), Vector2(78, 25), Vector2(75, 54), Vector2(50, 82), Vector2(25, 54), Vector2(22, 25)]), Color(0.25, 0.5, 0.9))
	draw_colored_polygon(PackedVector2Array([Vector2(50, 16), Vector2(78, 25), Vector2(75, 54), Vector2(50, 82)]), Color(0.2, 0.42, 0.8))


func _d_ad() -> void:
	_rrect(Rect2(8, 18, 84, 62), _main(Color(0.62, 0.4, 0.9)), 14)
	_poly(PackedVector2Array([Vector2(40, 34), Vector2(64, 49), Vector2(40, 64)]), Color.WHITE, 0)
	_line(Vector2(34, 88), Vector2(66, 88), Color(0.85, 0.85, 0.9), 6, 0)


func _d_castle() -> void:
	var c := Color(0.86, 0.84, 0.8)
	_rrect(Rect2(14, 40, 72, 52), c, 4)
	for x in [14, 38, 62]:
		_rrect(Rect2(x, 26, 24, 22), c, 3)
	draw_rect(Rect2(14, 40, 72, 52), c)
	_rrect(Rect2(40, 62, 20, 30), Color(0.45, 0.28, 0.18), 10, 0)
	_line(Vector2(50, 26), Vector2(50, 6), Color(0.5, 0.35, 0.25), 4, 0)
	draw_colored_polygon(PackedVector2Array([Vector2(52, 6), Vector2(70, 11), Vector2(52, 16)]), Color(0.95, 0.3, 0.3))


func _d_coin_bag() -> void:
	_circ(Vector2(50, 62), 32, Color(0.78, 0.55, 0.3))
	_poly(PackedVector2Array([Vector2(36, 34), Vector2(30, 14), Vector2(50, 22), Vector2(70, 14), Vector2(64, 34)]), Color(0.78, 0.55, 0.3))
	draw_circle(Vector2(50, 62), 32, Color(0.78, 0.55, 0.3))
	draw_rect(Rect2(34, 32, 32, 6), Color(1.0, 0.76, 0.22))
	draw_colored_polygon(_star_pts(Vector2(50, 64), 14, 6), Color(1.0, 0.82, 0.25))


func _d_hero() -> void:
	_d_shield()
	_set_rot(0.0)
	_line(Vector2(50, 26), Vector2(50, 62), Color(0.9, 0.93, 0.98), 8, 4)
	_line(Vector2(38, 56), Vector2(62, 56), Color(1.0, 0.8, 0.25), 7, 4)
	draw_set_transform_matrix(_base)


func _d_sell() -> void:
	_d_coin()
	_line(Vector2(66, 72), Vector2(90, 72), Color(0.95, 0.35, 0.3), 9, 6)


func _d_info() -> void:
	_circ(Vector2(50, 50), 42, _main(Color(0.3, 0.6, 0.95)))
	draw_circle(Vector2(50, 30), 7, Color.WHITE)
	_line(Vector2(50, 46), Vector2(50, 74), Color.WHITE, 11, 0)


func _d_trophy() -> void:
	draw_arc(Vector2(26, 38), 14, PI * 0.5, PI * 1.5, 12, INK, 10, true)
	draw_arc(Vector2(74, 38), 14, -PI * 0.5, PI * 0.5, 12, INK, 10, true)
	_poly(PackedVector2Array([Vector2(20, 20), Vector2(80, 20), Vector2(78, 42), Vector2(62, 62), Vector2(38, 62), Vector2(22, 42)]), Color(1.0, 0.8, 0.22))
	_rrect(Rect2(42, 62, 16, 14), Color(0.92, 0.62, 0.12), 2)
	_rrect(Rect2(28, 76, 44, 14), Color(0.62, 0.4, 0.22), 5)
	draw_colored_polygon(_star_pts(Vector2(50, 38), 11, 5), Color(1, 0.97, 0.75))


func _d_arrow(left: bool) -> void:
	var pts := PackedVector2Array([Vector2(34, 12), Vector2(80, 50), Vector2(34, 88), Vector2(22, 74), Vector2(52, 50), Vector2(22, 26)])
	if left:
		for i in pts.size():
			pts[i] = Vector2(100.0 - pts[i].x, pts[i].y)
	_poly(pts, _main(Color.WHITE))


func _d_quest() -> void:
	_rrect(Rect2(18, 10, 64, 82), Color(1.0, 0.95, 0.8), 10)
	_rrect(Rect2(12, 6, 76, 14), Color(0.86, 0.66, 0.42), 7, 6)
	_rrect(Rect2(12, 84, 76, 12), Color(0.86, 0.66, 0.42), 6, 6)
	for y in [34, 50, 66]:
		draw_line(Vector2(44, y), Vector2(72, y), Color(0.6, 0.5, 0.42), 5, true)
		draw_circle(Vector2(32, y), 5, Color(0.4, 0.78, 0.3))


func _d_gift() -> void:
	_rrect(Rect2(12, 40, 76, 50), Color(0.95, 0.35, 0.4), 8)
	_rrect(Rect2(6, 28, 88, 18), Color(1.0, 0.45, 0.5), 6)
	draw_rect(Rect2(44, 28, 12, 62), Color(1.0, 0.82, 0.25))
	draw_arc(Vector2(38, 20), 10, 0.0, TAU, 16, Color(1.0, 0.82, 0.25), 6, true)
	draw_arc(Vector2(62, 20), 10, 0.0, TAU, 16, Color(1.0, 0.82, 0.25), 6, true)
