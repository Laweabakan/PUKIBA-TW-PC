class_name PackOpening
extends RefCounted
## Sobres: la carátula (sobre metálico de bronce/plata/oro con una torre o un héroe en 3D)
## y la animación de apertura: el sobre tiembla, se rasga, destella y las cartas salen
## boca abajo y se voltean una a una (las raras con más brillo). Tocar acelera la animación.

const TIER_COLORS := {
	"bronze": [Color(0.86, 0.55, 0.3), Color(0.55, 0.3, 0.14)],
	"silver": [Color(0.86, 0.9, 0.97), Color(0.5, 0.55, 0.66)],
	"gold": [Color(1.0, 0.86, 0.35), Color(0.75, 0.5, 0.1)],
	"royal": [Color(0.85, 0.45, 1.0), Color(0.4, 0.15, 0.6)],
}


## Colores [claro, oscuro] del metal del sobre.
static func tier_colors(pack_id: String) -> Array:
	var p: Dictionary = GameData.PACKS.get(pack_id, GameData.PACKS["common"])
	var tier: String = p.get("tier", {"common": "bronze", "rare": "silver", "epic": "gold", "legendary": "royal"}.get(pack_id, "bronze"))
	return TIER_COLORS[tier]


static func cover_id(pack_id: String) -> String:
	var p: Dictionary = GameData.PACKS.get(pack_id, {})
	return p.get("cover", {"common": "archer", "rare": "mage", "epic": "inferno", "legendary": "obelisk"}.get(pack_id, "archer"))


## Carátula del sobre lista para poner en la interfaz.
static func pack_art(pack_id: String, size := Vector2(150, 200)) -> Control:
	var art := PackArt.new()
	art.pack_id = pack_id
	art.custom_minimum_size = size
	art.size = size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := CardIcon.new()
	icon.card_id = cover_id(pack_id)
	icon.level = 3
	icon.lit = true
	# Foto del modelo a la resolución con la que se ve (el sobre de la apertura es grande): nítida
	icon.snap_px = int(maxf(size.x * 0.8, size.y * 0.55))
	icon.position = Vector2(size.x * 0.1, size.y * 0.2)
	icon.size = Vector2(size.x * 0.8, size.y * 0.55)
	icon.custom_minimum_size = icon.size
	art.add_child(icon)
	var p: Dictionary = GameData.PACKS.get(pack_id, GameData.PACKS["common"])
	var kind: String = p.get("kind", "")
	var lbl := UIKit.label("HÉROES" if kind == "hero" else ("TORRES" if kind == "tower" else "CARTAS"), int(size.x * 0.11), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.add_theme_font_override("font", UIKit.font(true))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", (tier_colors(pack_id)[1] as Color).darkened(0.4))
	lbl.position = Vector2(0, size.y * 0.76)
	lbl.size = Vector2(size.x, size.y * 0.14)
	art.add_child(lbl)
	return art


## Animación completa de apertura. Al terminar muestra las cartas y el botón "¡Genial!".
static func play(parent: Node, results: Array, pack_id: String, on_close: Callable = Callable()) -> void:
	if results.is_empty():
		return
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = UIKit.theme()
	parent.add_child(root)
	var W := GameData.screen().x
	var H := GameData.screen().y
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.1, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	# Rayos de luz detrás del sobre
	var rays := Rays.new()
	rays.position = Vector2(W * 0.5, H * 0.45)
	rays.color = tier_colors(pack_id)[0]
	rays.modulate.a = 0.0
	root.add_child(rays)
	var art := pack_art(pack_id, Vector2(300, 400))
	art.position = Vector2((W - 300) * 0.5, H * 0.45 - 200)
	art.pivot_offset = Vector2(150, 200)
	art.scale = Vector2(0.2, 0.2)
	root.add_child(art)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	var hint := UIKit.label("Haz clic para abrir", 22, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, H * 0.45 + 230)
	hint.size = Vector2(W, 40)
	hint.modulate.a = 0.0
	root.add_child(hint)

	var best := 0
	for r in results:
		best = maxi(best, GameData.RARITY_ORDER.find(r["rarity"]))
	var state := {"phase": 0, "fast": false}
	var tw := root.create_tween()
	tw.tween_property(dim, "color:a", 0.82, 0.25)
	tw.parallel().tween_property(art, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rays, "modulate:a", 0.6, 0.5)
	tw.tween_property(hint, "modulate:a", 1.0, 0.2)
	Audio.sfx("magic", -4.0, 0.0)

	var open := func() -> void:
		if state["phase"] != 0:
			return
		state["phase"] = 1
		hint.queue_free()
		# Temblor creciente
		var t2 := root.create_tween()
		for k in 8:
			var amp := 3.0 + k * 1.6
			t2.tween_property(art, "rotation_degrees", amp if k % 2 == 0 else -amp, 0.05)
		t2.tween_property(art, "rotation_degrees", 0.0, 0.04)
		t2.tween_callback(func() -> void:
			Audio.sfx("slash", 0.0, 0.0)
			Audio.vibrate(40))
		# Se rasga: la tapa sale volando y el sobre cae
		t2.tween_property(art, "scale", Vector2(1.12, 1.12), 0.08)
		t2.tween_property(flash, "color:a", 0.9, 0.08)
		t2.tween_callback(func() -> void:
			_burst_particles(root, Vector2(W * 0.5, H * 0.45), tier_colors(pack_id)[0], 26)
			Audio.sfx("gem" if best >= 3 else "coin", -2.0, 0.0))
		t2.tween_property(flash, "color:a", 0.0, 0.3)
		t2.parallel().tween_property(rays, "modulate:a", 0.18, 0.5)
		t2.parallel().tween_property(art, "position:y", H + 100.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t2.parallel().tween_property(art, "rotation_degrees", 12.0, 0.45)
		t2.tween_callback(func() -> void: _deal_cards(root, results, best, on_close, state))
	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if state["phase"] == 0:
				open.call())
	# Si no se toca, se abre solo tras un momento
	# (el temporizador es hijo de la ventana: si se cierra antes, desaparece con ella)
	var auto := Timer.new()
	auto.one_shot = true
	auto.wait_time = 1.6
	auto.process_mode = Node.PROCESS_MODE_ALWAYS
	auto.timeout.connect(open)
	root.add_child(auto)
	auto.start()


static func _deal_cards(root: Control, results: Array, best: int, on_close: Callable, state: Dictionary) -> void:
	var n := results.size()
	var W := GameData.screen().x
	var H := GameData.screen().y
	var cols := mini(n, 5) # pantalla ancha: las 5 cartas en una fila
	var cw := 180.0
	var ch := 212.0
	var gap := 26.0
	var rows := ceili(n / float(cols))
	var top := H * 0.45 - (rows * ch + (rows - 1) * gap) * 0.5
	var title := UIKit.label("¡Sobre abierto!", 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_override("font", UIKit.font(true))
	title.position = Vector2(0, top - 90)
	title.size = Vector2(W, 50)
	title.modulate.a = 0.0
	root.add_child(title)
	root.create_tween().tween_property(title, "modulate:a", 1.0, 0.3)
	var delay := 0.0
	for i in n:
		var r: Dictionary = results[i]
		var row := i / cols
		var in_row := mini(cols, n - row * cols)
		var x0 := (W - (in_row * cw + (in_row - 1) * gap)) * 0.5
		var target := Vector2(x0 + (i % cols) * (cw + gap), top + row * (ch + gap))
		var rar_idx := GameData.RARITY_ORDER.find(r["rarity"])
		var rc: Color = GameData.RARITIES[r["rarity"]]["color"]
		# Dorso de la carta
		var back := PanelContainer.new()
		var bs := UIKit.card_style(Color(0.2, 0.25, 0.45), Color(0.95, 0.8, 0.4), 18, 6, 4)
		bs.set_border_width_all(4)
		back.add_theme_stylebox_override("panel", bs)
		back.custom_minimum_size = Vector2(cw, ch)
		back.size = Vector2(cw, ch)
		back.pivot_offset = Vector2(cw, ch) * 0.5
		back.position = Vector2(W * 0.5 - cw * 0.5, H * 0.45 - ch * 0.5)
		back.scale = Vector2(0.3, 0.3)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var crest := UIIcon.make("castle", 64)
		crest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		back.add_child(crest)
		root.add_child(back)
		var front := UIKit.card_widget(r["id"], r["new"])
		front.custom_minimum_size = Vector2(cw, ch)
		front.pivot_offset = Vector2(cw, ch) * 0.5
		front.position = target
		front.scale = Vector2(0.0, 1.0)
		front.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(front)
		var tw := root.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void: Audio.sfx("click", -4.0, 0.15, 0.0))
		tw.tween_property(back, "position", target, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(back, "scale", Vector2.ONE, 0.28)
		tw.parallel().tween_property(back, "rotation_degrees", 360.0, 0.28)
		# Pausa con suspense mayor para las cartas raras
		tw.tween_interval(0.15 + 0.12 * rar_idx)
		tw.tween_property(back, "scale:x", 0.0, 0.12)
		tw.tween_callback(func() -> void:
			back.visible = false
			if rar_idx >= 2:
				var glow := Rays.new()
				glow.color = rc
				glow.radius = 140.0 + 30.0 * rar_idx
				glow.position = target + Vector2(cw, ch) * 0.5
				glow.modulate.a = 0.0
				root.add_child(glow)
				root.move_child(glow, front.get_index())
				root.create_tween().tween_property(glow, "modulate:a", 0.75, 0.25)
				_burst_particles(root, target + Vector2(cw, ch) * 0.5, rc, 8 + rar_idx * 6)
				Audio.sfx("gem" if rar_idx >= 3 else "levelup", -3.0, 0.0, 0.0)
				Audio.vibrate(30 + rar_idx * 20)
			else:
				Audio.sfx("coin", -6.0, 0.1, 0.0))
		tw.tween_property(front, "scale:x", 1.0, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if r["new"]:
			tw.tween_callback(func() -> void: UIKit.pulse(front, 1.06))
		delay += 0.32
	# Botón final
	var done := root.create_tween()
	done.tween_interval(delay + 0.9 + 0.12 * best)
	done.tween_callback(func() -> void:
		var b := UIKit.button("¡Genial!", UIKit.GREEN, 26, Vector2(260, 76))
		b.position = Vector2((W - 260.0) * 0.5, top + rows * (ch + gap) + 40)
		b.pressed.connect(func() -> void:
			root.queue_free()
			if on_close.is_valid():
				on_close.call())
		root.add_child(b)
		UIKit.pop_in(b))


static func _burst_particles(root: Control, center: Vector2, col: Color, count: int) -> void:
	for k in count:
		var d := ColorRect.new()
		var s := randf_range(6.0, 14.0)
		d.size = Vector2(s, s)
		d.pivot_offset = d.size * 0.5
		d.color = col.lerp(Color.WHITE, randf() * 0.5)
		d.position = center - d.size * 0.5
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.rotation = randf() * TAU
		root.add_child(d)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(120.0, 320.0)
		var t := root.create_tween().set_parallel(true)
		t.tween_property(d, "position", d.position + dir, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(d, "rotation", d.rotation + randf_range(-6.0, 6.0), 0.7)
		t.tween_property(d, "modulate:a", 0.0, 0.7).set_delay(0.2)
		t.chain().tween_callback(d.queue_free)


## Sobre metálico dibujado: cuerpo con brillo, bordes sellados en zigzag arriba y abajo.
class PackArt extends Control:
	var pack_id := "common"

	func _draw() -> void:
		var cols := PackOpening.tier_colors(pack_id)
		var light: Color = cols[0]
		var dark: Color = cols[1]
		var w := size.x
		var h := size.y
		var crimp := h * 0.07
		# Cuerpo con degradado vertical (franjas)
		var bands := 14
		for i in bands:
			var y0 := crimp + (h - crimp * 2.0) * i / bands
			var y1 := crimp + (h - crimp * 2.0) * (i + 1) / bands
			var t := absf(float(i) / (bands - 1) - 0.35)
			draw_rect(Rect2(0, y0, w, y1 - y0 + 1.0), light.lerp(dark, clampf(t * 1.4, 0.0, 1.0)))
		# Bordes sellados (zigzag)
		for edge in [0, 1]:
			var y := 0.0 if edge == 0 else h - crimp
			draw_rect(Rect2(0, y, w, crimp), dark.darkened(0.15))
			var teeth := 16
			for k in range(1, teeth, 2):
				var x0 := w * (k - 1) / teeth
				var x1 := w * (k + 1) / teeth
				var xm := w * k / teeth
				var by := y if edge == 0 else y + crimp
				var ty := by + (crimp * 0.5 if edge == 0 else -crimp * 0.5)
				draw_colored_polygon(PackedVector2Array([Vector2(x0, by), Vector2(xm, ty), Vector2(x1, by)]), Color(0, 0, 0, 0.25))
			for k in 6:
				draw_line(Vector2(0, y + crimp * (k + 0.5) / 6.0), Vector2(w, y + crimp * (k + 0.5) / 6.0), Color(1, 1, 1, 0.12), 1.0)
		# Ventana para el modelo
		var win := Rect2(w * 0.08, h * 0.18, w * 0.84, h * 0.58)
		draw_rect(win, Color(1, 1, 1, 0.18))
		draw_rect(win, light.lightened(0.4), false, 3.0)
		# Brillo diagonal
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.55, crimp), Vector2(w * 0.75, crimp), Vector2(w * 0.25, h - crimp), Vector2(w * 0.05, h - crimp)]), Color(1, 1, 1, 0.13))
		# Contorno
		draw_rect(Rect2(0, 0, w, h), dark.darkened(0.45), false, 3.0)


## Rayos de luz girando (detrás del sobre y de las cartas raras).
class Rays extends Node2D:
	var color := Color.WHITE
	var radius := 420.0

	func _process(delta: float) -> void:
		rotation += delta * 0.6
		queue_redraw()

	func _draw() -> void:
		var n := 14
		for k in n:
			var a0 := TAU * k / n
			var a1 := a0 + TAU / n * 0.45
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a0) * radius, Vector2.from_angle(a1) * radius]), Color(color, 0.35))
		draw_circle(Vector2.ZERO, radius * 0.25, Color(color, 0.35))
