extends Node
## Ventana del juego en PC: aplica pantalla completa y VSync al arrancar, atiende F11 / Alt+Intro
## en cualquier pantalla y pone un cursor de ratón propio (flecha dorada con borde oscuro).


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SettingsPanel.apply_window.call_deferred()
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(_cursor(false), Input.CURSOR_ARROW, Vector2(3, 2))
		Input.set_custom_mouse_cursor(_cursor(true), Input.CURSOR_POINTING_HAND, Vector2(3, 2))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			SettingsPanel.toggle_fullscreen()
			get_viewport().set_input_as_handled()


## Flecha dibujada por código (con suavizado). `hot` = versión iluminada para lo que se puede pulsar.
static func _cursor(hot: bool) -> Image:
	var n := 40
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var tip := PackedVector2Array([Vector2(3, 2), Vector2(3, 30), Vector2(10, 23.5), Vector2(15, 34), Vector2(20, 31.5), Vector2(15, 21.5), Vector2(24.5, 21)])
	var fill_top := Color(1.0, 0.93, 0.55) if hot else Color(1.0, 0.86, 0.38)
	var fill_bot := Color(1.0, 0.7, 0.2) if hot else Color(0.86, 0.55, 0.14)
	var outline := Color(0.22, 0.12, 0.04)
	var ss := 4 # supermuestreo para bordes suaves
	for y in n:
		for x in n:
			var cov_in := 0
			var cov_edge := 0
			for sy in ss:
				for sx in ss:
					var p := Vector2(x + (sx + 0.5) / ss, y + (sy + 0.5) / ss)
					if Geometry2D.is_point_in_polygon(p, tip):
						cov_in += 1
					elif _near_poly(p, tip, 1.8):
						cov_edge += 1
			var total := float(ss * ss)
			if cov_in == 0 and cov_edge == 0:
				# Sombra suave desplazada
				var ps := Vector2(x - 2.0, y - 2.5)
				if Geometry2D.is_point_in_polygon(ps, tip):
					img.set_pixel(x, y, Color(0, 0, 0, 0.28))
				continue
			var t := clampf(float(y) / 32.0, 0.0, 1.0)
			var fc := fill_top.lerp(fill_bot, t)
			var inner := cov_in / total
			var edge := cov_edge / total
			var col := fc * inner + outline * edge
			var a := inner + edge
			if a > 0.0:
				col /= a
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0)))
	return img


static func _near_poly(p: Vector2, poly: PackedVector2Array, d: float) -> bool:
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= d:
			return true
	return false
