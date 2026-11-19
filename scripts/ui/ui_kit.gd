class_name UIKit
extends RefCounted
## Utilidades para construir la interfaz por código.
## Estilo "casual amable": paneles crema redondeados, acentos azul/turquesa y oro,
## botones con bisel y rebote al pulsar, ventanas que aparecen con un pequeño salto.

# ---------------------------------------------------------------- Paleta
# Colores heredados (se siguen usando en todo el juego como "color de botón" o de texto).
const WOOD := Color(0.62, 0.42, 0.27)          # botón secundario cálido
const WOOD_DARK := Color(0.13, 0.19, 0.33)      # fondo oscuro (azul noche)
const PARCHMENT := Color(1.0, 0.95, 0.84)       # texto claro sobre fondo oscuro
const GOLD := Color(1.0, 0.8, 0.26)
const GEM := Color(0.45, 0.86, 1.0)
const GREEN := Color(0.4, 0.76, 0.24)
const RED := Color(0.92, 0.36, 0.33)
const BLUE := Color(0.27, 0.57, 0.92)
const PURPLE := Color(0.6, 0.42, 0.9)
const GREY := Color(0.56, 0.6, 0.68)

# Colores nuevos
const CREAM := Color(1.0, 0.96, 0.87)           # panel pergamino
const CREAM_DARK := Color(0.87, 0.74, 0.55)     # borde del pergamino
const CREAM_SOFT := Color(0.96, 0.9, 0.78)      # recuadros dentro de un panel crema
const INK := Color(0.33, 0.22, 0.15)            # texto sobre crema
const INK_SOFT := Color(0.52, 0.42, 0.33)
const NAVY := Color(0.17, 0.25, 0.43)
const NAVY_DARK := Color(0.09, 0.13, 0.25)
const TEAL := Color(0.18, 0.62, 0.68)
const ORANGE := Color(1.0, 0.58, 0.2)
const AMBER := Color(0.78, 0.5, 0.08)           # "oro" legible sobre crema
const SHADOW := Color(0.02, 0.04, 0.12, 0.35)

const FONT_PATH := "res://assets/fonts/Fredoka.ttf"

static var _font: Font
static var _font_bold: Font
static var _theme: Theme


# ---------------------------------------------------------------- Tipografía y tema
static func _variation(weight: int) -> Font:
	var base: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font
	if not (base is FontFile):
		return base
	var fv := FontVariation.new()
	fv.base_font = base
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: weight}
	return fv


static func font(bold := false) -> Font:
	if _font == null:
		_font = _variation(500)
		_font_bold = _variation(620)
	return _font_bold if bold else _font


## Tema compartido: tipografía redondeada, barras de desplazamiento y barras de progreso suaves.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 20
	# Barras de desplazamiento finas y redondeadas
	for sb_type in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(1, 1, 1, 0.06)
		track.set_corner_radius_all(6)
		track.content_margin_left = 3
		track.content_margin_right = 3
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		var grab := StyleBoxFlat.new()
		grab.bg_color = Color(1, 0.95, 0.85, 0.35)
		grab.set_corner_radius_all(6)
		grab.content_margin_left = 3
		grab.content_margin_right = 3
		grab.content_margin_top = 3
		grab.content_margin_bottom = 3
		var grab_h := grab.duplicate() as StyleBoxFlat
		grab_h.bg_color = Color(1, 0.9, 0.6, 0.6)
		t.set_stylebox("scroll", sb_type, track)
		t.set_stylebox("grabber", sb_type, grab)
		t.set_stylebox("grabber_highlight", sb_type, grab_h)
		t.set_stylebox("grabber_pressed", sb_type, grab_h)
	# Barra de progreso por defecto
	t.set_stylebox("background", "ProgressBar", _bar_bg(14))
	t.set_stylebox("fill", "ProgressBar", _bar_fill(GOLD, 14))
	t.set_color("font_color", "ProgressBar", Color.WHITE)
	t.set_color("font_outline_color", "ProgressBar", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "ProgressBar", 4)
	t.set_font_size("font_size", "ProgressBar", 14)
	# Etiquetas y botones sueltos
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_font("font", "Button", font(true))
	_theme = t
	return t


## Aplica el tema a un Control raíz (y la tipografía como respaldo global).
static func apply_theme(root: Control) -> void:
	root.theme = theme()
	ThemeDB.fallback_font = font()


# ---------------------------------------------------------------- Estilos
static func style(bg: Color, border: Color = Color(0, 0, 0, 0), radius := 16, border_w := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border if border.a > 0 else bg.darkened(0.35)
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## Caja "3D": borde inferior más grueso y sombra suave.
static func card_style(bg: Color, border: Color, radius := 22, bottom := 6, shadow := 6) -> StyleBoxFlat:
	var s := style(bg, border, radius, 3)
	s.border_width_bottom = bottom
	if shadow > 0:
		s.shadow_color = SHADOW
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, 4)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 14
	s.content_margin_bottom = 14 + bottom - 3
	return s


static func _bar_bg(radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.08, 0.12, 0.35)
	s.border_color = Color(0, 0, 0, 0.18)
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	return s


static func _bar_fill(col: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.border_color = col.lightened(0.35)
	s.border_width_top = 3
	s.set_corner_radius_all(radius)
	s.corner_detail = 8
	return s


static func _btn_style(color: Color, state: String, radius: int) -> StyleBoxFlat:
	var bg := color
	var depth := 7
	var top := 8
	match state:
		"hover":
			bg = color.lightened(0.08)
		"pressed":
			bg = color.darkened(0.06)
			depth = 3
			top = 12
		"disabled":
			bg = color.lerp(Color(0.62, 0.62, 0.66), 0.72)
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.border_color = bg.darkened(0.32)
	s.set_border_width_all(3)
	s.border_width_bottom = depth
	s.border_blend = false
	if state != "pressed":
		s.shadow_color = Color(0, 0, 0, 0.22)
		s.shadow_size = 3
		s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = top
	s.content_margin_bottom = 12 - (top - 8)
	return s


## Brillo superior (bisel claro) del botón: se dibuja como un panel hijo encima.
static func _btn_shine(b: Button, radius: int) -> void:
	var shine := Panel.new()
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.22)
	s.corner_radius_top_left = maxi(radius - 4, 2)
	s.corner_radius_top_right = maxi(radius - 4, 2)
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	shine.add_theme_stylebox_override("panel", s)
	shine.anchor_right = 1.0
	shine.offset_left = 6
	shine.offset_right = -6
	shine.offset_top = 5
	shine.offset_bottom = 13
	shine.name = "Shine"
	b.add_child(shine)
	b.draw.connect(func() -> void:
		shine.visible = not b.disabled and b.get_draw_mode() != BaseButton.DRAW_PRESSED and b.size.y > 34)


# ---------------------------------------------------------------- Botones
static func button(text: String, color: Color = WOOD, font_size := 20, min_size := Vector2(0, 0)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	var radius := 18 if min_size.y >= 50 or min_size.y == 0 else 14
	set_button_color(b, color, radius)
	b.add_theme_font_override("font", font(true))
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_constant_override("outline_size", 6 if font_size >= 18 else 5)
	b.add_theme_constant_override("h_separation", 8)
	b.add_theme_constant_override("line_spacing", -2)
	_btn_shine(b, radius)
	add_press_bounce(b)
	b.pressed.connect(func() -> void: Audio.sfx("click", -6.0, 0.05, 0.03))
	return b


## Cambia el color de un botón ya creado (estados normal/hover/pulsado/desactivado).
static func set_button_color(b: Button, color: Color, radius := 18) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, _btn_style(color, st, radius))
	b.add_theme_stylebox_override("hover_pressed", _btn_style(color, "pressed", radius))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.75))
	b.add_theme_color_override("font_outline_color", color.darkened(0.55))
	b.add_theme_color_override("icon_normal_color", Color.WHITE)


## Botón redondo con un icono dibujado (pausa, velocidad, ajustes...).
static func icon_button(kind: String, color: Color = NAVY, px := 64.0, icon_frac := 0.5) -> Button:
	var b := button("", color, 20, Vector2(px, px))
	set_button_color(b, color, int(px * 0.5))
	var shine: Control = b.get_node("Shine")
	shine.offset_left = px * 0.24
	shine.offset_right = -px * 0.24
	shine.offset_top = 5
	shine.offset_bottom = 11
	var ic := UIIcon.make(kind, px * icon_frac)
	ic.outline = 8.0
	ic.position = Vector2(px, px - 4) * 0.5 - ic.custom_minimum_size * 0.5
	ic.size = ic.custom_minimum_size
	ic.name = "Icon"
	b.add_child(ic)
	b.set_meta("icon", ic)
	return b


## Pone un icono + texto centrado dentro de un botón (el texto propio del botón queda vacío).
## Se puede volver a llamar para actualizar el texto o el icono.
static func set_button_content(b: Button, kind: String, text: String, font_size := 20, icon_px := 30.0) -> void:
	b.text = ""
	var box: HBoxContainer = b.get_meta("content") if b.has_meta("content") else null
	if box == null:
		box = HBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 6)
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		box.offset_bottom = -4
		var ic := UIIcon.make(kind, icon_px)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.outline = 8.0
		box.add_child(ic)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", font(true))
		l.add_theme_font_size_override("font_size", font_size)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", b.get_theme_color("font_outline_color"))
		l.add_theme_constant_override("outline_size", 6 if font_size >= 18 else 5)
		l.add_theme_constant_override("line_spacing", -3)
		box.add_child(l)
		b.add_child(box)
		b.set_meta("content", box)
	var icon: UIIcon = box.get_child(0)
	icon.kind = kind
	icon.visible = kind != ""
	var lbl: Label = box.get_child(1)
	lbl.text = text
	lbl.add_theme_color_override("font_outline_color", b.get_theme_color("font_outline_color"))
	box.modulate = Color(1, 1, 1, 0.75) if b.disabled else Color.WHITE


# ---------------------------------------------------------------- Animaciones ("juice")
static func add_press_bounce(c: Control) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	if c is BaseButton:
		var bb: BaseButton = c
		bb.button_down.connect(func() -> void:
			if bb.disabled:
				return
			_scale_to(c, Vector2(0.9, 0.9), 0.07, Tween.TRANS_QUAD))
		bb.button_up.connect(func() -> void: _scale_to(c, Vector2.ONE, 0.32, Tween.TRANS_BACK))


static func _scale_to(c: Control, target: Vector2, dur: float, trans: int) -> void:
	if not c.is_inside_tree():
		return
	if c.has_meta("_scale_tw"):
		var old: Tween = c.get_meta("_scale_tw")
		if old != null and old.is_valid():
			old.kill()
	var tw := c.create_tween()
	tw.tween_property(c, "scale", target, dur).set_trans(trans).set_ease(Tween.EASE_OUT)
	c.set_meta("_scale_tw", tw)


## Pequeño salto de escala (para números que cambian).
static func pop(c: Control, amount := 1.3) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	if c.has_meta("_pop_tw"):
		var old: Tween = c.get_meta("_pop_tw")
		if old != null and old.is_valid():
			old.kill()
	var tw := c.create_tween()
	c.scale = Vector2(amount, amount)
	tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.set_meta("_pop_tw", tw)


## Aparición suave: transparencia + desplazamiento vertical.
static func fade_in(c: Control, dur := 0.22, delay := 0.0) -> void:
	c.modulate.a = 0.4
	var y := c.position.y
	c.position.y = y + 14.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, dur).set_delay(delay)
	tw.parallel().tween_property(c, "position:y", y, dur + 0.08).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Aparición con salto de escala (con retardo opcional para escalonar).
static func pop_in(c: Control, delay := 0.0, from := 0.4) -> void:
	c.scale = Vector2(from, from)
	c.modulate.a = 0.0
	c.pivot_offset = c.size * 0.5
	if not c.has_meta("_pivot_hook"):
		c.set_meta("_pivot_hook", true)
		c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Latido suave en bucle (para llamar la atención sobre algo reclamable).
static func pulse(c: Control, amount := 1.06, period := 0.9) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size * 0.5)
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2(amount, amount), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------------- Textos
static func label(text: String, font_size := 20, color: Color = Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", font(font_size >= 22))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.07, 0.16, 0.85))
	l.add_theme_constant_override("outline_size", 6 if font_size >= 22 else 4)
	return l


## Texto para paneles claros (crema): oscuro y sin contorno.
static func ink(text: String, font_size := 18, color: Color = INK, align := HORIZONTAL_ALIGNMENT_LEFT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", font(bold or font_size >= 22))
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Fila con icono + texto.
static func icon_label(kind: String, text: String, font_size := 20, color: Color = Color.WHITE, icon_px := 0.0, on_light := false) -> HBoxContainer:
	var h := hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UIIcon.make(kind, icon_px if icon_px > 0.0 else font_size * 1.35)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := ink(text, font_size, color) if on_light else label(text, font_size, color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	h.set_meta("label", l)
	h.set_meta("icon", ic)
	return h


## Píldora oscura con icono y valor (monedas, vidas, oleada...). La etiqueta está en get_meta("label").
static func pill(kind: String, text: String, font_size := 22, color: Color = Color.WHITE, min_w := 0.0, bg: Color = Color(0.05, 0.08, 0.18, 0.55)) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := style(bg, Color(1, 1, 1, 0.12), 24, 2)
	s.content_margin_left = 6
	s.content_margin_right = 16
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(min_w, 0)
	var h := icon_label(kind, text, font_size, color, font_size * 1.6)
	p.add_child(h)
	p.set_meta("label", h.get_meta("label"))
	p.set_meta("icon", h.get_meta("icon"))
	return p


## Barra de progreso redondeada con texto opcional encima.
static func progress(value: float, max_value: float, col: Color = GOLD, height := 22, text := "") -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxf(max_value, 0.001)
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := int(height * 0.5)
	bar.add_theme_stylebox_override("background", _bar_bg(r))
	bar.add_theme_stylebox_override("fill", _bar_fill(col, r))
	if text != "":
		var l := label(text, maxi(int(height * 0.68), 12), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.add_theme_constant_override("outline_size", 4)
		bar.add_child(l)
	return bar


## Globo rojo de notificación con número (se coloca en la esquina del padre).
static func badge(count: int) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := style(Color(0.95, 0.25, 0.25), Color.WHITE, 16, 3)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 0
	s.content_margin_bottom = 1
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(32, 32)
	var l := label(str(count) if count > 0 else "!", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font(true))
	l.add_theme_constant_override("outline_size", 0)
	p.add_child(l)
	return p


## Cinta de oferta ("¡MEJOR OFERTA!", "-50%").
static func ribbon(text: String, col: Color = RED, font_size := 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := style(col, col.lightened(0.4), 12, 2)
	s.border_width_bottom = 4
	s.border_color = col.darkened(0.35)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 2
	s.content_margin_bottom = 4
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", font(true))
	l.add_theme_color_override("font_outline_color", col.darkened(0.5))
	p.add_child(l)
	return p


# ---------------------------------------------------------------- Paneles
static func panel(color: Color = WOOD, radius := 20) -> PanelContainer:
	var p := PanelContainer.new()
	var s := card_style(color, color.darkened(0.3), radius, 6, 5)
	s.border_color = color.lightened(0.18)
	s.border_width_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	return p


## Tarjeta pergamino (fondo crema, texto oscuro).
static func card(bg: Color = CREAM, radius := 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style(bg, bg.darkened(0.2) if bg != CREAM else CREAM_DARK, radius, 6, 6))
	return p


## Recuadro plano dentro de una tarjeta.
static func inset(bg: Color = CREAM_SOFT, radius := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var s := style(bg, bg.darkened(0.08), radius, 2)
	p.add_theme_stylebox_override("panel", s)
	return p


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer() -> Control:
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp


## Convierte textos claros (pensados para fondo oscuro) en tinta legible sobre crema.
static func adapt_to_light(n: Node) -> void:
	if n is Label:
		var l: Label = n
		if l.has_theme_color_override("font_color"):
			var c: Color = l.get_theme_color("font_color")
			if c.get_luminance() > 0.5:
				if c.s < 0.3:
					l.add_theme_color_override("font_color", INK)
				else:
					l.add_theme_color_override("font_color", Color.from_hsv(c.h, minf(1.0, c.s + 0.15), 0.62))
		else:
			l.add_theme_color_override("font_color", INK)
		l.add_theme_constant_override("outline_size", 0)
		return
	if n is PanelContainer or n is BaseButton or n is SubViewportContainer:
		return
	for ch in n.get_children():
		adapt_to_light(ch)


# ---------------------------------------------------------------- Ventanas
## Ventana modal centrada. `buttons` = [[texto, Callable, Color], ...]
## Cada botón cierra la ventana antes de ejecutar su acción.
static func popup(parent: Node, title: String, body: Control, buttons: Array, width := 620) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	if root.theme == null:
		root.theme = theme()
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.16, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var p := PanelContainer.new()
	var ps := card_style(CREAM, CREAM_DARK, 30, 9, 14)
	ps.border_width_left = 4
	ps.border_width_right = 4
	ps.border_width_top = 4
	ps.content_margin_left = 22
	ps.content_margin_right = 22
	ps.content_margin_top = 18
	ps.content_margin_bottom = 24
	ps.shadow_color = Color(0, 0, 0, 0.4)
	ps.shadow_offset = Vector2(0, 8)
	p.add_theme_stylebox_override("panel", ps)
	p.custom_minimum_size = Vector2(mini(width, 696), 0)
	center.add_child(p)
	var v := vbox(16)
	p.add_child(v)
	# Título sobre una cinta azul
	var head := PanelContainer.new()
	var hs := style(NAVY, GOLD, 20, 3)
	hs.border_width_bottom = 6
	hs.border_color = Color(0.85, 0.62, 0.18)
	hs.content_margin_top = 6
	hs.content_margin_bottom = 10
	head.add_theme_stylebox_override("panel", hs)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.custom_minimum_size = Vector2(minf(float(mini(width, 696)) * 0.6, 380.0), 0)
	var tl := label(title, 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	tl.add_theme_font_override("font", font(true))
	tl.add_theme_color_override("font_outline_color", NAVY_DARK)
	head.add_child(tl)
	v.add_child(head)
	if body != null:
		adapt_to_light(body)
		var bm := MarginContainer.new()
		bm.add_theme_constant_override("margin_left", 4)
		bm.add_theme_constant_override("margin_right", 4)
		bm.add_child(body)
		v.add_child(bm)
	if not buttons.is_empty():
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 12)
		row.add_theme_constant_override("v_separation", 12)
		row.alignment = FlowContainer.ALIGNMENT_CENTER
		v.add_child(row)
		for bd in buttons:
			var b := button(bd[0], bd[2] if bd.size() > 2 else WOOD, 21, Vector2(170, 68))
			var cb: Callable = bd[1]
			b.pressed.connect(func() -> void:
				root.queue_free()
				if cb.is_valid():
					cb.call())
			row.add_child(b)
	parent.add_child(root)
	# Animación de entrada: fundido + salto de escala
	root.modulate.a = 0.0
	p.resized.connect(func() -> void: p.pivot_offset = p.size * 0.5)
	p.scale = Vector2(0.72, 0.72)
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.16)
	tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return root


static func message(parent: Node, title: String, text: String) -> Control:
	var l := label(text, 22, PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return popup(parent, title, l, [["Aceptar", Callable(), GREEN]])


## Aviso breve en forma de píldora que baja suavemente desde arriba.
static func toast(parent: Node, text: String, color: Color = GOLD) -> void:
	var n := 0
	for ch in parent.get_children():
		if ch.has_meta("ui_toast") and not ch.is_queued_for_deletion():
			n += 1
	var p := PanelContainer.new()
	p.set_meta("ui_toast", true)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := style(Color(0.08, 0.12, 0.24, 0.93), color, 26, 3)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, 23, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", font(true))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font(true).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 23).x > 600.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(600, 0)
	p.add_child(l)
	parent.add_child(p)
	p.reset_size()
	var y := 214.0 + 66.0 * float(mini(n, 3))
	p.position = Vector2((GameData.SCREEN.x - p.size.x) * 0.5, y - 24.0)
	p.pivot_offset = p.size * 0.5
	p.modulate.a = 0.0
	p.scale = Vector2(0.85, 0.85)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(p, "position:y", y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(p, "position:y", y - 18.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(p.queue_free)


## Muestra las cartas obtenidas al abrir un sobre.
static func show_pack_results(parent: Node, results: Array, on_close: Callable = Callable()) -> void:
	if results.is_empty():
		return
	# Animación de apertura con la carátula del último sobre abierto
	PackOpening.play(parent, results, Meta.last_pack_id, on_close)


## Versión sin animación (lista simple de cartas).
static func show_pack_list(parent: Node, results: Array, on_close: Callable = Callable()) -> void:
	if results.is_empty():
		return
	var grid := GridContainer.new()
	grid.columns = mini(results.size(), 4)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var center := CenterContainer.new()
	center.add_child(grid)
	var i := 0
	for r in results:
		var w := card_widget(r["id"], r["new"])
		grid.add_child(w)
		pop_in(w, 0.15 + 0.08 * i)
		i += 1
	popup(parent, "¡Sobre abierto!", center, [["¡Genial!", on_close, GREEN]], 696)


## Carta de colección: modelo 3D girando, nombre, rareza y nivel.
static func card_widget(id: String, is_new := false, show_level := false) -> Control:
	var def := GameData.card_def(id)
	var rar: Dictionary = GameData.RARITIES[def["rarity"]]
	var rc: Color = rar["color"]
	var owned := Save.owns(id)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(150, 176)
	var bg := Color(0.2, 0.25, 0.4).lerp(rc, 0.18)
	var ps := card_style(bg, rc, 18, 7, 4)
	ps.set_border_width_all(4)
	ps.border_width_bottom = 7
	ps.border_color = rc
	ps.content_margin_left = 8
	ps.content_margin_right = 8
	ps.content_margin_top = 8
	ps.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", ps)
	var v := vbox(3)
	p.add_child(v)
	# Ventana del modelo con fondo claro
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := style(rc.lerp(Color(0.85, 0.92, 1.0), 0.55) if owned else Color(0.35, 0.37, 0.42), Color(1, 1, 1, 0.25), 12, 0)
	fs.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", fs)
	v.add_child(frame)
	var icon := CardIcon.new()
	icon.card_id = id
	icon.custom_minimum_size = Vector2(110, 78)
	frame.add_child(icon)
	if not owned:
		var lk := UIIcon.make("lock", 34)
		lk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		frame.add_child(lk)
	var n := label(def["name"], 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	n.add_theme_font_override("font", font(true))
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(120, 0)
	n.add_theme_constant_override("line_spacing", -4)
	v.add_child(n)
	var sub := "Héroe · " if GameData.is_hero(id) else ""
	var rl := label(sub + rar["name"], 13, rc.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(rl)
	var foot: Control
	if is_new:
		foot = ribbon("¡NUEVA!", ORANGE, 15)
		foot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pulse(foot, 1.1, 0.8)
	elif show_level:
		var lvl := Save.card_level(id)
		if lvl > 0:
			# Nivel + barra de copias hacia el siguiente nivel
			var fv := vbox(2)
			var lv := icon_label("star", "Nv. %d" % lvl, 15, GOLD, 18)
			lv.alignment = BoxContainer.ALIGNMENT_CENTER
			fv.add_child(lv)
			var copies := int(Save.card(id)["copies"])
			var bar: ProgressBar
			if lvl >= GameData.MAX_CARD_LEVEL:
				bar = progress(1, 1, GOLD, 18, "MÁX")
			else:
				var need := Meta.copies_needed(lvl)
				bar = progress(mini(copies, need), need, GREEN if copies >= need else BLUE, 18, "%d/%d" % [copies, need])
			fv.add_child(bar)
			v.add_child(fv)
			return p
		else:
			# Bloqueada: copias juntadas / copias necesarias para desbloquearla
			var fv2 := vbox(2)
			var lk2 := icon_label("lock", "Bloqueada", 14, Color(0.78, 0.8, 0.86), 18)
			lk2.alignment = BoxContainer.ALIGNMENT_CENTER
			fv2.add_child(lk2)
			if not Meta.is_progress_tower(id) and Meta.unlock_copies(id) > 1: # barra solo si hacen falta varias copias
				var need_u := Meta.unlock_copies(id)
				var have_u := int(Save.card(id)["copies"])
				fv2.add_child(progress(mini(have_u, need_u), need_u, ORANGE, 18, "%d/%d" % [have_u, need_u]))
			v.add_child(fv2)
			return p
		(foot as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		var lvl0 := Save.card_level(id)
		if lvl0 == 0 and not Meta.is_progress_tower(id) and Meta.unlock_copies(id) > 1:
			foot = label("Copias %d/%d" % [int(Save.card(id)["copies"]), Meta.unlock_copies(id)], 15, PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			foot = label("+1 copia", 15, PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(foot)
	return p


# ---------------------------------------------------------------- Desplazamiento táctil
## Hace que se pueda arrastrar la lista desde CUALQUIER punto, no solo desde los huecos:
## todo Control que bloquee el ratón dentro del ScrollContainer pasa a dejarlo pasar
## (los botones siguen funcionando y el ScrollContainer cancela su pulsación al empezar a arrastrar).
static func drag_anywhere(scroll: ScrollContainer) -> void:
	var helper := _DragAnywhere.new()
	helper.scroll = scroll
	scroll.add_child(helper, false, Node.INTERNAL_MODE_BACK)


class _DragAnywhere extends Node:
	var scroll: ScrollContainer

	func _ready() -> void:
		get_tree().node_added.connect(_on_node_added)
		_fix.call_deferred(scroll)

	func _exit_tree() -> void:
		if get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.disconnect(_on_node_added)

	func _on_node_added(n: Node) -> void:
		if n is Control and is_instance_valid(scroll) and scroll.is_ancestor_of(n):
			_fix_one.call_deferred(n)

	func _fix(n: Node) -> void:
		if not is_instance_valid(n):
			return
		if n != scroll:
			_fix_one(n)
			if n is ScrollContainer:
				return # una lista anidada gestiona su propio arrastre
		for c in n.get_children():
			_fix(c)

	static func _fix_one(n: Node) -> void:
		if not is_instance_valid(n) or not n is Control or n is ScrollBar or n is LineEdit or n is Slider:
			return
		var c := n as Control
		if c.mouse_filter == Control.MOUSE_FILTER_STOP:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
