class_name CardIcon
extends SubViewportContainer
## Muestra el modelo 3D de una torre o héroe dentro de una carta.
##
## Para no saturar el móvil, cada modelo se dibuja UNA sola vez en un mundo 3D temporal,
## se guarda como imagen (caché por carta y nivel) y el mundo 3D se libera. Antes cada carta
## tenía su propio mundo 3D vivo: con la colección y el menú de cartas abiertos eran 40-80 a la vez.
## Con `live = true` se mantiene el modelo 3D girando (y en modo sin pantalla, para las pruebas).

var card_id := ""
var level := 0
var lit := false # true: siempre a color (carátulas de sobres), aunque no se tenga la carta
var snap_px := 0 # lado de la foto en píxeles a escala base (0 = el normal de las cartas)
var live := false
var _model: Node3D
var _vp: SubViewport
var _acc := 0.0
var _tex_rect: TextureRect
const FPS := 15.0 # modo en vivo: gira a 15 fps
## Resolución de la foto de la carta (cuadrada): 176 px a la escala base (720x1280) multiplicado
## por la escala real de la pantalla (hasta x2), para que en móviles HD se vea nítida.
static func snap_size() -> Vector2i:
	var k := 1.0
	if DisplayServer.get_name() != "headless":
		k = clampf(float(DisplayServer.window_get_size().y) / 1280.0, 1.0, 2.0)
	var s := int(176.0 * k)
	return Vector2i(s, s)

static var _cache := {} # "id|nivel" -> Texture2D
static var _waiting := {} # "id|nivel" -> [CardIcon] que esperan esa foto
static var _queue: Array = []
static var _renderer: _Renderer


## Clave de la foto: carta, nivel y lado en píxeles reales (las carátulas grandes piden más).
func _key() -> String:
	var px := snap_size().x if snap_px <= 0 else int(snap_px * float(snap_size().x) / 176.0)
	return "%s|%d|%d" % [card_id, level, px]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not lit and not Save.owns(card_id):
		modulate = Color(0.3, 0.3, 0.3)
	if live or DisplayServer.get_name() == "headless":
		_build_live()
		return
	_tex_rect = TextureRect.new()
	_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex_rect)
	var key := _key()
	if _cache.has(key):
		_tex_rect.texture = _cache[key]
		return
	if not _waiting.has(key):
		_waiting[key] = []
		_queue.append(key)
	_waiting[key].append(self)
	if _renderer == null or not is_instance_valid(_renderer):
		_renderer = _Renderer.new()
		get_tree().root.add_child.call_deferred(_renderer)
	else:
		_renderer.kick()


## Borra las fotos guardadas (p. ej. si cambian los modelos).
static func clear_cache() -> void:
	_cache.clear()


## Monta modelo, luz y cámara dentro de un SubViewport.
static func _populate(vp: SubViewport, id: String, lvl: int) -> Node3D:
	var hero := GameData.is_hero(id)
	var model: Node3D = V3.build_hero(id) if hero else TowerModels.build(id, lvl)
	# De frente a la cámara: las torres miran a -Z y los héroes a +X
	model.rotation.y = -PI * 0.5 if hero else PI
	var mark := model.get_node_or_null("Ready")
	if mark != null:
		mark.visible = false
	vp.add_child(model)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.95)
	e.ambient_light_energy = 0.6
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	var h := 0.75 if hero else 1.05
	# Los héroes son más bajos que las torres: cámara más cerca para que llenen la carta
	if hero:
		cam.look_at_from_position(Vector3(0, h + 0.85, 2.3), Vector3(0, h - 0.05, 0), Vector3.UP)
	else:
		cam.look_at_from_position(Vector3(0, h + 1.4, 3.6), Vector3(0, h, 0), Vector3.UP)
	return model


## Modo en vivo (como antes): SubViewport propio con el modelo girando.
func _build_live() -> void:
	if _vp != null:
		return
	if _tex_rect != null:
		_tex_rect.queue_free()
		_tex_rect = null
	stretch = true
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp = vp
	add_child(vp)
	_model = _populate(vp, card_id, level)


func _process(delta: float) -> void:
	if _model == null or _vp == null:
		return
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	# Solo se redibuja si está en pantalla
	if not is_visible_in_tree() or not get_global_rect().intersects(get_viewport_rect()):
		return
	_model.rotation.y += _acc * 0.7
	_acc = 0.0
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Hace las fotos de una en una (un solo mundo 3D temporal a la vez).
class _Renderer extends Node:
	var _running := false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		kick()

	func kick() -> void:
		if not _running and is_inside_tree():
			_run()

	func _run() -> void:
		_running = true
		while not CardIcon._queue.is_empty():
			var key: String = CardIcon._queue.pop_front()
			var parts := key.split("|")
			var vp := SubViewport.new()
			vp.own_world_3d = true
			vp.transparent_bg = true
			vp.size = Vector2i(int(parts[2]), int(parts[2]))
			vp.msaa_3d = Viewport.MSAA_4X # foto única: bordes suaves
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			add_child(vp)
			CardIcon._populate(vp, parts[0], int(parts[1]))
			await RenderingServer.frame_post_draw
			var img: Image = vp.get_texture().get_image()
			vp.queue_free()
			var tex: Texture2D = null
			if img != null and not img.is_empty():
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
				CardIcon._cache[key] = tex
			for ic in CardIcon._waiting.get(key, []):
				if is_instance_valid(ic):
					if tex != null and ic._tex_rect != null:
						ic._tex_rect.texture = tex
					else:
						ic._build_live() # sin foto posible: modelo en vivo como antes
			CardIcon._waiting.erase(key)
		_running = false
