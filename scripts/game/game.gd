extends Node2D
## Controlador de partida: cuadrícula, oleadas, construcción, combate y HUD.

const T := GameData.TILE
const HERO_KEY := "__hero"

const MAX_ENEMIES := 320

var map_idx := 0
var map_def: Dictionary = {}
var path_cells := {}
var path_points: Array = []
var deco: Array = []
var towers := {} # Vector2i -> Tower
var enemies: Array = []
## Héroes en el campo (hasta MAX_HEROES a la vez, uno de cada).
const MAX_HEROES := 3
var heroes: Array = []
## Primer héroe en el campo (o null). Atajo para las pruebas y avisos.
var hero: Tower:
	get:
		return heroes[0] if not heroes.is_empty() else null
var world: Node3D
var camera: Camera3D
var path_dirs := {} # Vector2i (incluye casillas fuera de la cuadrícula) -> Vector2i
var deco_nodes := {} # Vector2i -> Node3D
var highlight_nodes := {} # Vector2i -> Node3D
var mapinfo: Dictionary = {} # ver MapGen.generate()
var paths_points: Array = [] # un Array de puntos (plano 2D) por cada entrada
var blocked := {} # casillas no construibles: agua y obstáculos
var _spawn_counter := 0
var evolutions := 0
var castle_plane := Vector2.ZERO
var heights := {} # Vector2i -> 1.0 (colinas de una casilla: más alcance para las torres)
const HEIGHT_RANGE_BONUS := 0.25 # +25% de alcance por cada casilla de altura # posición del castillo (para poder tocarlo)
var preview_cell := Vector2i(-99, -99) # casilla con vista previa del alcance al construir
var _preview_disc: Node3D
var _fortress_popup: Control
# Cooperativo
var coop := "" # "", "host", "client", "ai"
var my_side := 0 # 0 = mitad izquierda (anfitrión), 1 = mitad derecha
var partner_gold := 0
var _uid_counter := 0
var _snap_timer := 0.0
var _ai_timer := 0.0
var _puppets := {} # uid -> Enemy # torres evolucionadas a Maestría en esta partida (encarece la siguiente)
# Cámara (arrastrar para mover, pellizcar o rueda para zoom)
var cam_focus := Vector2.ZERO # punto del suelo (x, z) que mira la cámara
var cam_zoom := 1.0
var _cam_offset := Vector3.ZERO
var _cam_base := Vector3.ZERO # desplazamiento de la cámara sin girar
var view_rot := 0 # giro de la vista en pasos de 90° (0..3)
var _touches := {}
var _press_pos := Vector2.ZERO
var _dragged := false
var _pinch_dist := 0.0

## Oro: una sola moneda para todo. En solitario, el oro de la batalla ES el oro guardado
## (el mismo que se gasta en La Fortaleza, las cartas y la Tienda). En cooperativo cada
## partida lleva su propio oro, compartido entre los dos jugadores.
var _match_gold := 0
var gold: int:
	get:
		return _match_gold if coop != "" else Save.coins()
	set(v):
		if coop != "":
			_match_gold = v
		else:
			Save.data["coins"] = maxi(v, 0)
var lives := 50
var wave := 0
var last_cleared := 0
var spawn_queue: Array = []
var spawn_timer := 0.0
var auto_wave := true # las oleadas avanzan solas
var auto_timer := 10.0 # tiempo antes de la primera oleada para preparar la defensa
var speed := 1
var build_id := ""
var selected: Tower = null
var show_all_ranges := false
var revived := false
var doubled := false
var over := false
var coins_earned := 0
var haste_time := 0.0
var blessing_time := 0.0
var forge_time := 0.0 # Bram: +25% daño
var anthem_time := 0.0 # Isolde: +50% velocidad
var bounty_time := 0.0 # Korvin: oro x2
var _hud_timer := 0.0

# UI
var hud: CanvasLayer
var ui: Control
var side_col: VBoxContainer
var _side_badges := {}
var _menu_overlay: Control
## Accesos de la columna derecha en la batalla (los mismos que en el menú, sin cooperativo)
const BATTLE_SIDE := [
	["packs", "Sobres", "gift", Color(0.95, 0.35, 0.45)],
	["shop", "Tienda", "chest", Color(0.95, 0.6, 0.2)],
	["collection", "Colección", "cards", Color(0.42, 0.5, 0.95)],
	["achievements", "Logros", "trophy", Color(0.25, 0.6, 0.9)],
	["ranking", "Ranking", "trophy", Color(0.85, 0.45, 0.2)],
]
var lbl_lives: Label
var lbl_gold: Label

var lbl_wave: Label
var lbl_coins: Label
var lbl_next: Label
var btn_next: Button
var btn_speed: Button
var btn_auto: Button
var ability_row: HBoxContainer # un botón de habilidad por héroe en el campo (hasta 3)
var ability_btns: Array = []
var shop_list: HBoxContainer
var shop_buttons := {}
var info_panel: PanelContainer
var build_info: PanelContainer # ficha de la torre o héroe elegido para construir
var shop_panel: PanelContainer
var btn_build: Button
var btn_cards: Button
var shop_mode := "progress" # "progress": torres del juego · "cards": torres y héroes de sobres
var btn_demolish: Button
var demolish_mode := false


func _ready() -> void:
	map_idx = GameData.current_map
	map_def = GameData.MAPS[map_idx]
	mapinfo = MapGen.generate(map_idx)
	heights = mapinfo.get("heights", {})
	if ResourceLoader.exists("res://scripts/game/vfx.gd"):
		load("res://scripts/game/vfx.gd").prewarm() # evita tirones con el primer disparo
	GameData.COLS = int(mapinfo["cols"])
	GameData.ROWS = int(mapinfo["rows"])
	_build_path()
	_build_deco()
	_build_world()
	_build_hud()
	coop = Coop.role
	var run := Save.get_run(map_idx) if coop == "" else {}
	if coop != "":
		_coop_setup()
	elif run.is_empty():
		_ensure_min_gold()
		lives = GameData.START_LIVES + int(Save.upgrade_value("lives")) + int(Save.gem_upgrade_value("g_lives"))
		UIKit.toast(ui, "Coloca a tus héroes (botón Cartas, hasta %d) y construye torres" % MAX_HEROES if Save.owns(Save.data["selected_hero"]) else "Pulsa Construir y defiende el castillo", UIKit.PARCHMENT)
	else:
		_load_run(run)
	_rebuild_shop()
	_refresh_hud()
	Meta.level_up.connect(_on_level_up)
	Audio.play_music("battle" if map_idx % 2 == 0 else "battle2")
	# Tutorial de la primera partida: construir, mejorar en La Fortaleza y abrir un sobre
	if coop == "" and map_idx == 0 and Tutorial.active():
		var tut := Tutorial.new()
		add_child(tut)
		tut.setup(self)


func _on_level_up(lvl: int, reward: Dictionary) -> void:
	UIKit.toast(ui, "¡Nivel de cuenta %d!  %s" % [lvl, Meta.reward_text(reward)], UIKit.GOLD)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not over:
			_save_run()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not over and not get_tree().paused:
			_open_pause()


# ================================================================ Mapa
func _build_path() -> void:
	paths_points.clear()
	for cells in mapinfo["paths"]:
		var pts: Array = []
		for i in cells.size():
			var c: Vector2i = cells[i]
			var p := GameData.cell_center(c)
			# Alarga los extremos para que los enemigos aparezcan fuera del tablero.
			if i == 0:
				p += (p - GameData.cell_center(cells[1])).normalized() * T
			elif i == cells.size() - 1:
				p += (p - GameData.cell_center(cells[i - 1])).normalized() * T
			pts.append(p)
		paths_points.append(pts)
	path_points = paths_points[0]
	path_dirs = mapinfo["path_cells"]
	for c in path_dirs.keys():
		if _in_grid(c):
			path_cells[c] = true
	for c in mapinfo["water"].keys():
		if _in_grid(c):
			blocked[c] = "water"
	for c in mapinfo["obstacles"].keys():
		blocked[c] = mapinfo["obstacles"][c]


func _build_deco() -> void:
	pass # la decoración y los obstáculos los dibuja Scenery


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GameData.COLS and c.y < GameData.ROWS


const CAMERA_POS := Vector3(0, 16.5, 9.9)
const CAMERA_TARGET := Vector3(0, 0, 3.2)
const CAMERA_OFFSET := Vector2(0.0, 0.0)
const ZOOM_MIN := 0.5
const ZOOM_MAX := 1.5


func _build_world() -> void:
	world = Node3D.new()
	world.name = "World3D"
	add_child(world)
	var ground: Color = map_def["ground"]
	var path_col: Color = map_def["path"]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	# Estilo low-poly de papel: luz cálida y suave, y neblina que se come la lejanía.
	# Los colores de cada mapa no cambian: la neblina se mezcla con el color del propio mapa.
	var haze: Color = ground.lerp(Color(1.0, 0.86, 0.68), 0.45).lightened(0.15)
	e.background_color = haze.darkened(0.25)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.86, 0.78)
	e.ambient_light_energy = 0.38
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Mapas muy claros (nieve, hielo): menos exposición para que las facetas no se quemen en blanco
	var bright := clampf((ground.get_luminance() - 0.45) / 0.35, 0.0, 1.0)
	e.tonemap_exposure = lerpf(1.0, 0.82, bright)
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = haze
	e.fog_density = 0.85
	e.fog_depth_begin = 16.0
	e.fog_depth_end = 46.0
	e.fog_depth_curve = 1.4
	e.fog_sky_affect = 0.6
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.0
	e.adjustment_contrast = 1.12
	# Brillo suave en lo mágico (portales, runas, fuego)
	e.glow_enabled = true
	e.glow_intensity = 0.4
	e.glow_strength = 0.9
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.4
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = lerpf(1.1, 0.62, bright) # en la nieve el sol satura: más suave
	sun.light_color = Color(1.0, 0.89, 0.74) # sol de tarde, cálido
	sun.shadow_blur = 1.5
	sun.shadow_enabled = bool(Save.data.get("settings", {}).get("quality_high", true))
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL # 1 pasada de sombra en vez de 4
	world.add_child(sun)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH # el ancho de la pantalla abarca todas las columnas
	camera.fov = 62.0 # campo horizontal (pantalla 16:9)
	world.add_child(camera)
	camera.current = true
	# Mapa alargado en vertical: enemigos arriba, castillo abajo. Se recorre arriba y abajo con la cámara.
	# Distancia para que las columnas llenen el ancho de la pantalla (calibrado con capturas)
	_cam_base = (CAMERA_POS - CAMERA_TARGET).normalized() * ((GameData.COLS + 2.0) / 1.0)
	view_rot = 0
	_cam_offset = _cam_base
	cam_focus = Vector2(0.0, GameData.ROWS * 0.5 - 3.5) # empieza mirando el castillo (abajo)
	_apply_camera()
	# Base del tablero
	V3.box(Vector3(GameData.COLS + 0.3, 0.6, GameData.ROWS + 0.3), ground.darkened(0.18), Vector3(0, -0.44, 0), 0.0, world)
	# Casillas construibles: continuas y con variación de color muy suave (cuadrícula poco marcada)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + map_idx
	var ground_tiles: Array = []
	var raised_tiles := {1.0: []}
	for x in GameData.COLS:
		for y in GameData.ROWS:
			var c := Vector2i(x, y)
			if path_cells.has(c) or blocked.get(c, "") == "water":
				continue
			var center := V3.to3(GameData.cell_center(c))
			var tc := ground.lightened(0.018) if (x + y) % 2 == 0 else ground
			tc = tc.lightened(rng.randf_range(-0.02, 0.025))
			var ch := cell_h(c)
			if ch > 0.0:
				# Colina: columna de tierra que sube hasta su altura
				# Colina: ladera de tierra/roca más oscura y la cima con la hierba del mapa
				raised_tiles[ch].append([center + Vector3(0, ch - 0.1 - (ch + 0.32) * 0.5, 0), tc.lerp(Color(0.45, 0.36, 0.28), 0.45).darkened(0.12)])
				ground_tiles.append([center + Vector3(0, ch - 0.06, 0), tc.lightened(0.05)])
			else:
				ground_tiles.append([center + Vector3(0, -0.06, 0), tc])
			if blocked.has(c):
				continue
			var hl := V3.box(Vector3(0.9, 0.02, 0.9), Color(1, 1, 1, 0.22), center + Vector3(0, 0.012 + cell_h(c), 0), 0.0, world)
			hl.visible = false
			highlight_nodes[c] = hl
	world.add_child(_tile_multimesh(Vector3(1.0, 0.12, 1.0), ground_tiles, "sparse_grass"))
	for lvl in raised_tiles.keys():
		if not (raised_tiles[lvl] as Array).is_empty():
			world.add_child(_tile_multimesh(Vector3(0.995, lvl + 0.32, 0.995), raised_tiles[lvl], "dirt"))
	# Camino (también fuera del tablero), un poco hundido; los puentes los dibuja Scenery
	var has_scenery := ResourceLoader.exists(SCENERY_PATH)
	var path_tiles: Array = []
	for c in path_dirs.keys():
		var cc: Vector2i = c
		if mapinfo["bridges"].has(cc) and has_scenery:
			continue
		var center := V3.to3(GameData.cell_center(cc))
		path_tiles.append([center + Vector3(0, -0.085, 0), path_col.lightened(rng.randf_range(-0.025, 0.02))])
	world.add_child(_tile_multimesh(Vector3(1.0, 0.07, 1.0), path_tiles, "dirt"))
	# Paisaje, agua, puentes, obstáculos y vida (Scenery); respaldo simple si no existe
	if has_scenery:
		load(SCENERY_PATH).build(world, mapinfo, map_def)
	else:
		for c in mapinfo["obstacles"].keys():
			var rock := V3.build_deco("rock", 2.2)
			rock.position = V3.to3(GameData.cell_center(c))
			world.add_child(rock)
		for c in mapinfo["water"].keys():
			V3.box(Vector3(1, 0.05, 1), Color(0.2, 0.45, 0.75), V3.to3(GameData.cell_center(c), -0.12), 0.0, world)
	# Un portal por cada entrada
	for pts in paths_points:
		var start: Vector2 = pts[0].move_toward(pts[1], T * 0.6)
		var portal := V3.node("Portal", V3.to3(start, 0.5), world)
		var pd: Vector2 = pts[1] - pts[0]
		portal.rotation.y = V3.yaw(pd.angle()) + PI * 0.5
		var ring := V3.torus(0.38, 0.48, Color(0.65, 0.3, 1.0), Vector3.ZERO, 2.5, portal)
		ring.rotation.x = PI * 0.5
		var core := V3.cyl(0.38, 0.38, 0.02, Color(0.35, 0.05, 0.6, 0.7), Vector3.ZERO, 1.5, portal, 20)
		core.rotation.x = PI * 0.5
	# Castillo feudal europeo de destino (la puerta mira al camino)
	var n := path_points.size()
	var ed: Vector2 = (path_points[n - 1] - path_points[n - 2]).normalized()
	var castle := V3.build_castle()
	castle.position = V3.to3(path_points[n - 1] + ed * T * 0.9)
	castle.rotation.y = V3.yaw(ed.angle())
	world.add_child(castle)
	castle_plane = path_points[n - 1] + ed * T * 0.9
	# Estilo low-poly de papel: todo el paisaje, el castillo y los portales con caras planas
	preload("res://scripts/towers3d/models.gd").facet_tree(world)


const SCENERY_PATH := "res://scripts/game/scenery.gd"


## Muchas casillas iguales en una sola llamada de dibujo, cada una con su color.
## `tex`: textura CC0 de assets/textures/cc0 que da detalle al suelo (hierba, tierra).
func _tile_multimesh(size: Vector3, tiles: Array, tex := "") -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m: Material
	if tex != "" and ResourceLoader.exists("res://assets/textures/cc0/%s_diff.jpg" % tex):
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/ground.gdshader")
		sm.set_shader_parameter("tex_albedo", load("res://assets/textures/cc0/%s_diff.jpg" % tex))
		sm.set_shader_parameter("tex_normal", load("res://assets/textures/cc0/%s_nor.jpg" % tex))
		sm.set_shader_parameter("detail", 0.75 if tex == "dirt" else 0.95)
		m = sm
	else:
		var bm := (TowerModels.ArcherModel.M.mat(Color.WHITE) as StandardMaterial3D).duplicate() as StandardMaterial3D
		bm.vertex_color_use_as_albedo = true
		bm.roughness = 0.92
		bm.next_pass = null
		m = bm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = tiles.size()
	for i in tiles.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, tiles[i][0]))
		mm.set_instance_color(i, tiles[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	return mmi


func _apply_camera() -> void:
	var half_w := GameData.COLS * 0.5
	var half_h := GameData.ROWS * 0.5
	# Se puede recorrer todo el tablero (los mapas de PC son grandes)
	cam_focus.x = clampf(cam_focus.x, -half_w - 0.5, half_w + 0.5)
	cam_focus.y = clampf(cam_focus.y, -half_h - 0.5, half_h + 1.5)
	var target := Vector3(cam_focus.x, 0, cam_focus.y)
	camera.look_at_from_position(target + _cam_offset * cam_zoom, target, Vector3.UP)


## Botón de girar (R / Q / E): rota la vista del tablero 90° cada vez.
func _rotate_view(dir := 1) -> void:
	view_rot = (view_rot + dir + 4) % 4
	var from := _cam_offset
	var to := _cam_base.rotated(Vector3.UP, view_rot * PI * 0.5)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		# Giro suave alrededor del punto que se está mirando
		var a := from.slerp(to, k) if from.normalized().dot(to.normalized()) > -0.99 else from.rotated(Vector3.UP, PI * 0.5 * k)
		_cam_offset = a
		_apply_camera(), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_cam_offset = to
		_apply_camera())


func _zoom_by(factor: float) -> void:
	cam_zoom = clampf(cam_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_apply_camera()


func screen_pos(p: Vector2, h := 0.0) -> Vector2:
	return camera.unproject_position(V3.to3(p, h))


## Punto del plano (coordenadas lógicas) bajo una posición de pantalla, a la altura h.
func plane_from_screen(sp: Vector2, h := 0.0) -> Vector2:
	var o := camera.project_ray_origin(sp)
	var d := camera.project_ray_normal(sp)
	if absf(d.y) < 0.0001:
		return Vector2(-99999, -99999)
	var t := (h - o.y) / d.y
	return V3.to2(o + d * t)


## Altura de la casilla (0 en el llano).
func cell_h(c: Vector2i) -> float:
	return float(heights.get(c, 0.0))


## Casilla bajo un punto de la pantalla teniendo en cuenta las colinas.
func _pick_cell(screen: Vector2) -> Vector2i:
	for h in [1.0]:
		var c := _cell_at(plane_from_screen(screen, h))
		if cell_h(c) == h:
			return c
	return _cell_at(plane_from_screen(screen))


func _cell_at(p: Vector2) -> Vector2i:
	var rel := p - GameData.GRID_OFFSET
	return Vector2i(floori(rel.x / T), floori(rel.y / T))


## Círculo de alcance de la torre elegida en la casilla `c` (verde si se puede construir).
func _show_preview(c: Vector2i) -> void:
	if not GameData.TOWERS.has(build_id):
		return
	preview_cell = c
	var ok := _in_grid(c) and not path_cells.has(c) and not blocked.has(c) and not towers.has(c)
	if _preview_disc != null:
		_preview_disc.queue_free()
	var def: Dictionary = GameData.TOWERS[build_id]
	var start_lvl := Meta.tower_start_level(build_id)
	var r := float(def.get("range", 0.0)) * (1.0 + 0.03 * start_lvl) * (1.0 + Save.upgrade_value("range"))
	if not Meta.is_progress_tower(build_id):
		r *= GameData.PACK_TOWER_RANGE
	r *= 1.0 + HEIGHT_RANGE_BONUS * cell_h(c)
	var col := Color(0.4, 1.0, 0.5) if ok else Color(1.0, 0.35, 0.3)
	_preview_disc = V3.node("Alcance", V3.to3(GameData.cell_center(c), 0.05 + cell_h(c)), world)
	if r > 0.0:
		var fill := V3.cyl(1.0, 1.0, 0.01, Color(col, 0.16), Vector3.ZERO, 0.0, _preview_disc, 48)
		fill.scale = Vector3(r, 1, r)
		var edge := V3.torus(0.97, 1.0, col, Vector3(0, 0.01, 0), 1.5, _preview_disc)
		edge.scale = Vector3(r, 1, r)
	V3.box(Vector3(0.95, 0.03, 0.95), Color(col, 0.45), Vector3(0, 0.02, 0), 1.0, _preview_disc)


func _hide_preview() -> void:
	preview_cell = Vector2i(-99, -99)
	if _preview_disc != null:
		_preview_disc.queue_free()
		_preview_disc = null


func _update_highlights() -> void:
	if build_id == "" or build_id == HERO_KEY:
		_hide_preview()
	for c in highlight_nodes.keys():
		highlight_nodes[c].visible = build_id != "" and not towers.has(c) and not blocked.has(c)


## Capa 2D sobre el 3D: barras de vida e indicadores de estado.
func _draw() -> void:
	if camera == null:
		return
	for e in enemies:
		if e.dead or (e.hp >= e.max_hp and not e.is_boss and not e.elite):
			continue
		var top := screen_pos(e.position, e.height + e.radius / T * 2.6 + 0.2)
		var w := clampf(e.radius * 1.3, 28.0, 90.0)
		var r := Rect2(top - Vector2(w * 0.5, 0), Vector2(w, 6))
		draw_rect(r.grow(1), Color(0, 0, 0, 0.75))
		var hc := Color(0.95, 0.25, 0.2) if e.is_boss else (Color(1, 0.4, 0.9) if e.elite else Color(0.35, 0.95, 0.35))
		draw_rect(Rect2(r.position, Vector2(w * clampf(e.hp / e.max_hp, 0, 1), 6)), hc)
		if e.stun_time > 0.0:
			draw_circle(top + Vector2(w * 0.5 + 6, 3), 4, Color(1, 1, 0.4))
		if not e.dots.is_empty():
			draw_circle(top + Vector2(-w * 0.5 - 6, 3), 4, GameData.DAMAGE_TYPES[e.dots[0]["type"]]["color"])


# ================================================================ Bucle principal
func _process(delta: float) -> void:
	queue_redraw()
	if over:
		return
	_keyboard_pan(delta)
	if coop == "client":
		_hud_timer -= delta
		if _hud_timer <= 0.0:
			_hud_timer = 0.15
			_refresh_hud()
		return
	if coop == "host":
		_snap_timer -= delta
		if _snap_timer <= 0.0:
			_snap_timer = 0.1
			_coop_send_snapshot()
	elif coop == "ai":
		_ai_timer -= delta
		if _ai_timer <= 0.0:
			_ai_timer = 1.2
			_ai_ally_turn()
	haste_time = maxf(haste_time - delta, 0.0)
	# Las torres con aura de revelación (Santuario) descubren a los invisibles cercanos
	for t in towers.values():
		if t.def.has("reveal_range"):
			var rr: float = float(t.def["reveal_range"]) * T
			for e in enemies:
				if e.invisible and e.position.distance_to(t.position) <= rr:
					e.reveal_time = 0.4
	blessing_time = maxf(blessing_time - delta, 0.0)
	forge_time = maxf(forge_time - delta, 0.0)
	anthem_time = maxf(anthem_time - delta, 0.0)
	bounty_time = maxf(bounty_time - delta, 0.0)
	if not spawn_queue.is_empty():
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var entry: Dictionary = spawn_queue.pop_front()
			_spawn_enemy(entry)
			if not spawn_queue.is_empty():
				spawn_timer = float(spawn_queue[0]["delay"])
	elif enemies.is_empty() and wave > last_cleared:
		_on_wave_cleared()
	if auto_wave and spawn_queue.is_empty() and enemies.is_empty() and wave < GameData.MAX_WAVES:
		auto_timer -= delta
		if auto_timer <= 0.0:
			start_next_wave()
	else:
		auto_timer = 2.0
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.15
		_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if over or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_press_pos = st.position
				_dragged = false
			elif _touches.size() == 2:
				_dragged = true
				_pinch_dist = _touch_distance()
		else:
			if _touches.size() == 1 and not _dragged:
				_on_tap(st.position)
			_touches.erase(st.index)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		var prev: Vector2 = _touches.get(sd.index, sd.position)
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var d := _touch_distance()
			if _pinch_dist > 0.0 and d > 0.0:
				_zoom_by(_pinch_dist / d)
			_pinch_dist = d
		else:
			if sd.position.distance_to(_press_pos) > 14.0:
				_dragged = true
			if _dragged:
				var a := plane_from_screen(prev)
				var b := plane_from_screen(sd.position)
				cam_focus += (a - b) / T
				_apply_camera()
	elif event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)) != 0:
		# Clic derecho o central arrastrado: mover la cámara
		var mm := event as InputEventMouseMotion
		if mm.relative.length() > 0.0:
			_right_dragged = _right_dragged or mm.position.distance_to(_right_press) > 6.0
			var a := plane_from_screen(mm.position - mm.relative)
			var b := plane_from_screen(mm.position)
			cam_focus += (a - b) / T
			_apply_camera()
	elif event is InputEventMouseMotion and build_id != "" and build_id != HERO_KEY and _touches.is_empty():
		var hc := _pick_cell(event.position)
		if _in_grid(hc) and hc != preview_cell:
			_show_preview(hc)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			# Rueda del ratón para el zoom
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(0.9)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(1.1)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_right_press = mb.position
				_right_dragged = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not _right_dragged:
			_cancel_action() # clic derecho sin arrastrar: cancela la construcción o la selección
	elif event is InputEventKey and event.pressed and not event.echo:
		_on_key((event as InputEventKey).keycode)


var _right_press := Vector2.ZERO
var _right_dragged := false
const PAN_SPEED := 14.0 # casillas por segundo con WASD / flechas


## Cancela lo que se esté haciendo: construir, demoler o la torre seleccionada.
func _cancel_action() -> bool:
	if build_id != "":
		build_id = ""
		_hide_preview()
		_update_build_info()
		_update_highlights()
		_refresh_hud()
		return true
	if demolish_mode:
		_set_demolish(false)
		return true
	if selected != null:
		_select(null)
		return true
	if shop_panel != null and shop_panel.visible:
		shop_panel.visible = false
		_update_build_buttons()
		return true
	return false


## Atajos de teclado (PC).
func _on_key(k: Key) -> void:
	match k:
		KEY_ESCAPE:
			if not _cancel_action():
				_open_pause()
		KEY_SPACE, KEY_N:
			if not btn_next.disabled:
				start_next_wave()
		KEY_1:
			_set_speed(1)
		KEY_2:
			_set_speed(2)
		KEY_3:
			_set_speed(3)
		KEY_R, KEY_E:
			_rotate_view(1)
		KEY_Q:
			_rotate_view(-1)
		KEY_V:
			show_all_ranges = not show_all_ranges
		KEY_B:
			_toggle_build_menu("progress")
		KEY_C:
			_toggle_build_menu("cards")
		KEY_X:
			_toggle_demolish()
		KEY_U:
			if selected != null:
				_upgrade_selected()
		KEY_DELETE, KEY_BACKSPACE:
			if selected != null and not selected.is_hero:
				_sell_selected()
		KEY_F:
			_open_fortress()
		KEY_HOME:
			cam_focus = Vector2.ZERO
			cam_zoom = 1.0
			_apply_camera()
		KEY_EQUAL, KEY_KP_ADD:
			_zoom_by(0.9)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom_by(1.1)


## Desplazamiento de la cámara con WASD / flechas (en el sentido de la pantalla).
func _keyboard_pan(delta: float) -> void:
	if camera == null or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var dx := 0.0
	var dy := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dx -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dx += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dy += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dy -= 1.0
	if dx == 0.0 and dy == 0.0:
		return
	var b := camera.global_transform.basis
	var right := Vector2(b.x.x, b.x.z).normalized()
	var fwd := Vector2(-b.z.x, -b.z.z).normalized()
	var real_dt := delta / maxf(Engine.time_scale, 0.001) # igual de rápido a x1 que a x3
	cam_focus += (right * dx + fwd * dy) * PAN_SPEED * cam_zoom * real_dt
	_apply_camera()


func _touch_distance() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _on_tap(screen: Vector2) -> void:
	# Construyendo manda la casilla del suelo: tocar junto a una torre alta no debe seleccionarla.
	var ground := _pick_cell(screen)
	if build_id != "" and not demolish_mode and _in_grid(ground) and not towers.has(ground):
		if preview_cell == ground or build_id == HERO_KEY:
			_try_build(build_id, ground)
			_hide_preview()
		else:
			_show_preview(ground)
		return
	# Tocar el castillo abre La Fortaleza (mejoras permanentes)
	for h in [0.0, 0.8, 1.6]:
		if plane_from_screen(screen, h).distance_to(castle_plane) <= T * 1.5:
			_open_fortress()
			return
	var c := _pick_cell(screen)
	# Las torres son altas: si no hay torre en el suelo, prueba a media altura.
	if not towers.has(c):
		var c2 := _cell_at(plane_from_screen(screen, 0.8))
		if towers.has(c2):
			c = c2
	if not _in_grid(c):
		return
	if demolish_mode:
		if towers.has(c):
			_demolish(towers[c])
		elif _clearable(c):
			_clear_obstacle(c)
		return
	if towers.has(c):
		_select(towers[c])
		return
	if _clearable(c) and build_id == "":
		UIKit.toast(ui, "%s: pulsa Demoler y tócalo para quitarlo (%d oro)" % ["Árbol" if blocked[c] == "tree" else "Roca", CLEAR_COST], UIKit.PARCHMENT)
		return
	if build_id != "":
		# Primer toque: ver el alcance en esa casilla. Segundo toque en la misma: construir.
		if preview_cell == c or build_id == HERO_KEY:
			_try_build(build_id, c)
			_hide_preview()
		else:
			_show_preview(c)
		return
	_select(null)


# ================================================================ Construcción
func tower_cost(id: String) -> int:
	return discounted(int(GameData.TOWERS[id]["cost"]))


func discounted(n: int) -> int:
	return int(n * (1.0 - Save.upgrade_value("discount")))


## Héroe con ese id en el campo (o null).
func hero_on_field(hid: String) -> Tower:
	for h in heroes:
		if is_instance_valid(h) and h.id == hid:
			return h
	return null


## ¿Hay ya en el tablero una torre de este tipo? (las de cartas son únicas)
func has_tower(id: String) -> bool:
	for t in towers.values():
		if t.id == id and not t.is_hero and (coop == "" or int(t.get_meta("side", 0)) == my_side):
			return true
	return false


func _try_build(id: String, c: Vector2i) -> void:
	if path_cells.has(c):
		UIKit.toast(ui, "No puedes construir sobre el camino", UIKit.RED)
		return
	if blocked.has(c):
		UIKit.toast(ui, "Hay agua o un obstáculo aquí", UIKit.RED)
		return
	if coop != "" and side_of(c) != my_side:
		UIKit.toast(ui, "Esa mitad del tablero es de tu aliado", UIKit.RED)
		return
	if id != HERO_KEY and not Meta.is_progress_tower(id) and has_tower(id):
		UIKit.toast(ui, "Las torres de cartas son únicas: ya tienes %s en el campo" % GameData.TOWERS[id]["name"], UIKit.RED)
		return
	if id == HERO_KEY and not Save.owns(Save.data["selected_hero"]):
		return
	if id == HERO_KEY:
		if hero_on_field(Save.data["selected_hero"]) != null:
			return
		if heroes.size() >= MAX_HEROES:
			UIKit.toast(ui, "Máximo %d héroes en el campo: demuele uno para cambiarlo" % MAX_HEROES, UIKit.RED)
			return
	if coop == "client":
		if gold < tower_cost(id):
			UIKit.toast(ui, "Oro insuficiente", UIKit.RED)
			return
		Coop.request("build", [c.x, c.y, id])
		build_id = ""
		_update_highlights()
		return
	var t := Tower.new()
	if id == HERO_KEY:
		t.setup(self, Save.data["selected_hero"], c, true)
		t.level = Save.hero_level(t.id) # nivel permanente del héroe
		heroes.append(t)
	else:
		var cost := tower_cost(id)
		if gold < cost:
			UIKit.toast(ui, "Oro insuficiente", UIKit.RED)
			return
		gold -= cost
		t.setup(self, id, c)
		t.level = Meta.tower_start_level(id) # Entrenamiento + Arquitectos Arcanos
		t.spent = cost
		Meta.track("build", 1)
	add_child(t)
	towers[c] = t
	Audio.sfx("build", -3.0)
	Audio.vibrate(20)
	t.set_meta("side", my_side)
	_coop_broadcast("build", [c.x, c.y, t.id, my_side, t.level])
	build_id = ""
	_recalc_auras()
	_rebuild_shop()
	_refresh_hud()
	_update_highlights()
	if deco_nodes.has(c):
		deco_nodes[c].visible = false
	spawn_fx("build", t.position, T * 0.6, Color(0.75, 0.62, 0.45), 0.8)


func _select(t: Tower) -> void:
	if is_instance_valid(selected):
		selected.selected = false
	selected = t
	if t != null:
		t.selected = true
		build_id = ""
		_update_highlights()
	_update_info_panel()


func _upgrade_selected() -> void:
	var t := selected
	if t == null:
		return
	if t.is_hero:
		# Héroes: nivel permanente que se paga con oro
		if t.level >= GameData.HERO_MAX_LEVEL:
			return
		if not Meta.level_hero(t.id):
			UIKit.toast(ui, "Necesitas %s de oro" % GameData.format_num(Meta.hero_level_cost(t.id)), UIKit.RED)
			return
		t.level = Save.hero_level(t.id)
		spawn_fx("levelup", t.position, T * 0.7, UIKit.GOLD, 1.2)
		UIKit.toast(ui, "¡%s sube a nivel %d para siempre!" % [t.def["name"], t.level], UIKit.GOLD)
		_update_info_panel()
		_refresh_hud()
		return
	var cost := t.upgrade_cost()
	if cost < 0:
		return
	if gold < cost:
		UIKit.toast(ui, "Oro insuficiente", UIKit.RED)
		return
	if coop == "client":
		Coop.request("upgrade", [t.cell.x, t.cell.y])
		return
	gold -= cost
	t.spent += cost
	t.level += 1
	_coop_broadcast("upgrade", [t.cell.x, t.cell.y])
	Meta.track("upgrade", 1)
	spawn_fx("levelup", t.position, T * 0.7, UIKit.GOLD, 1.2)
	if t.level == GameData.MAX_TOWER_LEVEL and not t.is_hero:
		evolutions += 1
		Meta.track("evolve", 1)
		UIKit.toast(ui, "¡Maestría desbloqueada!", Color(1, 0.5, 0.95))
	_recalc_auras()
	_update_info_panel()
	_refresh_hud()


func _sell_selected() -> void:
	var t := selected
	if t == null or t.is_hero:
		return
	if coop == "client":
		Coop.request("sell", [t.cell.x, t.cell.y])
		_select(null)
		return
	gold += t.sell_value()
	_coop_broadcast("sell", [t.cell.x, t.cell.y])
	towers.erase(t.cell)
	_select(null)
	if deco_nodes.has(t.cell):
		deco_nodes[t.cell].visible = true
	t.queue_free()
	_recalc_auras()
	_refresh_hud()


func _cycle_target() -> void:
	if selected == null:
		return
	var i := Tower.TARGET_MODES.find(selected.target_mode)
	selected.target_mode = Tower.TARGET_MODES[(i + 1) % Tower.TARGET_MODES.size()]
	_update_info_panel()


func _recalc_auras() -> void:
	for t in towers.values():
		t.aura_mult = 1.0
		t.speed_aura_mult = 1.0
		t.range_aura_mult = 1.0
	# Campanario: acelera a las torres cercanas (no se acumula consigo mismo)
	for s in towers.values():
		if not s.def.has("speed_aura"):
			continue
		var sr: float = float(s.stat("aura_range", 0.0)) * T
		for t in towers.values():
			if t != s and t.position.distance_to(s.position) <= sr + 1.0:
				t.speed_aura_mult = maxf(t.speed_aura_mult, 1.0 + float(s.stat("speed_aura", 0.0)))
	for s in towers.values():
		if not s.def.has("aura"):
			continue
		var ar: float = float(s.stat("aura_range", 0.0)) * T
		for t in towers.values():
			if t != s and t.position.distance_to(s.position) <= ar + 1.0:
				t.aura_mult += float(s.stat("aura", 0.0))
				t.range_aura_mult += float(s.stat("range_aura", 0.0)) # Torre del Heraldo


# ================================================================ Oleadas
func start_next_wave() -> void:
	if coop == "client":
		Coop.request("next", [])
		return
	if coop != "" and wave >= Coop.MAX_WAVE:
		return
	if over or wave >= GameData.MAX_WAVES or not spawn_queue.is_empty():
		return
	if hero == null and wave == 0 and Save.owns(Save.data["selected_hero"]):
		UIKit.toast(ui, "Consejo: coloca a tus héroes desde Cartas (gratis)", UIKit.PARCHMENT)
	wave += 1
	# Registro de diagnóstico (llega al informe de cierre si el móvil cierra el juego)
	print("[PUKIBA] oleada %d | torres %d | enemigos %d | RAM %.0f MB | vídeo %.0f MB | draws %d" % [wave, towers.size(), enemies.size(), OS.get_static_memory_usage() / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	spawn_queue = WaveGen.generate(map_idx, wave)
	var kinds := {}
	for s in spawn_queue:
		kinds[s["id"]] = true
	print("[PUKIBA] mapa %d oleada %d: %s" % [map_idx, wave, ", ".join(kinds.keys())])
	Audio.sfx("boss" if WaveGen.is_boss_wave(wave) else "horn", -4.0, 0.0, 0.5)
	spawn_timer = 0.4
	var label := WaveGen.preview_text(map_idx, wave)
	if label != "":
		UIKit.toast(ui, "Oleada %d: %s" % [wave, label], UIKit.RED if WaveGen.is_boss_wave(wave) else UIKit.GOLD)
	_refresh_hud()


func _spawn_enemy(entry: Dictionary) -> void:
	var e := Enemy.new()
	var pts: Array = paths_points[_spawn_counter % paths_points.size()]
	if bool(GameData.ENEMIES[entry["id"]].get("boss", false)):
		pts = paths_points[randi() % paths_points.size()]
	_spawn_counter += 1
	e.setup(self, entry["id"], float(entry["hp"]), int(entry["gold"]), pts)
	_uid_counter += 1
	e.uid = _uid_counter
	if entry.get("elite", false):
		e.elite = true
		e.max_hp *= 6.0
		e.hp = e.max_hp
		e.radius *= 1.3
		e.gold_value *= 5
	add_child(e)
	enemies.append(e)


func spawn_enemy_at(id: String, base_hp: float, parent: Enemy, offset := Vector2.ZERO) -> void:
	if enemies.size() >= MAX_ENEMIES:
		return
	var e := Enemy.new()
	e.setup(self, id, base_hp, maxi(1, parent.gold_value / 3), parent.path, parent.path_idx, parent.position + offset)
	e.progress = parent.progress
	_uid_counter += 1
	e.uid = _uid_counter
	add_child(e)
	enemies.append(e)


func _on_wave_cleared() -> void:
	while last_cleared < wave:
		last_cleared += 1
		var w := last_cleared
		# Oro de partida: se gana matando enemigos y con las torres que recaudan (Recaudador)
		for t in towers.values():
			if not t.is_hero and t.def.has("gold_per_wave") and (coop == "" or int(t.get_meta("side", 0)) == my_side):
				var tg: int = t.gold_per_wave()
				gold += tg
				float_text(t.position, "+%d oro" % tg, UIKit.GOLD)
		var c := WaveGen.coins_for_wave(map_idx, w)
		coins_earned += c
		Save.data["coins"] = Save.coins() + c
		Save.set_best_wave(map_idx, w)
		if coop == "":
			Online.report_wave(map_idx, w) # ranking semanal (cada 5 oleadas)
		# Bono de gemas la primera vez que se llega a cada múltiplo de 50 en este mapa
		if w % 50 == 0 and coop == "":
			var key := "%d:%d" % [map_idx, w]
			if not Save.data["milestones"].has(key):
				Save.data["milestones"][key] = true
				var mg := GameData.milestone_gold(map_idx, w)
				Save.data["coins"] = Save.coins() + mg
				UIKit.toast(ui, "¡Oleada %d alcanzada! +%s oro" % [w, GameData.format_num(mg)], UIKit.GOLD)
		Save.data["stats"]["waves"] = int(Save.data["stats"]["waves"]) + 1
		Meta.track("waves", 1)
		if w == GameData.UNLOCK_WAVE and map_idx + 1 < GameData.MAPS.size() and int(Save.data["unlocked_maps"]) <= map_idx + 1:
			Save.data["unlocked_maps"] = map_idx + 2
			Save.data["coins"] = Save.coins() + 50 * GameData.GEM_GOLD
			_pause_popup("¡Nuevo mapa!", "Has sobrevivido 100 oleadas.\nDesbloqueado: %s\n+%s oro\n\nPuedes seguir hasta la oleada 500." % [GameData.MAPS[map_idx + 1]["name"], GameData.format_num(50 * GameData.GEM_GOLD)])
		if w >= GameData.MAX_WAVES or (coop != "" and w >= Coop.MAX_WAVE):
			if coop != "":
				_coop_end()
			else:
				_victory()
			return
	if coop == "":
		_save_run()
	_refresh_hud()


# ================================================================ Combate
func global_damage_mult() -> float:
	return (1.4 if blessing_time > 0.0 else 1.0) * (1.25 if forge_time > 0.0 else 1.0)


func global_speed_mult() -> float:
	return 2.0 if haste_time > 0.0 else (1.5 if anthem_time > 0.0 else 1.0)


func spawn_projectile(from: Vector2, from_h: float, target: Enemy, payload: Dictionary, style: String, fixed_pos := Vector2.INF) -> void:
	var p := Projectile.new()
	p.setup(self, from, from_h, target, payload, style, fixed_pos)
	add_child(p)


func resolve_hit(payload: Dictionary, target: Enemy, pos: Vector2, origin: Vector2, origin_h := 1.0) -> void:
	var color: Color = GameData.DAMAGE_TYPES[payload["type"]]["color"]
	var chain := int(payload.get("chain", 0))
	if chain > 0 and target != null:
		var hit: Array = [target]
		var pts := PackedVector2Array([origin, target.position])
		var hs: Array = [origin_h, target.height + 0.35]
		var mult := 1.0
		_apply_hit(payload, target, mult)
		var cur := target
		for k in chain:
			var nxt: Enemy = null
			var best := T * 1.8
			for e in enemies:
				if e in hit or e.dead:
					continue
				if (e.flying and not payload["air_ok"]) or (not e.flying and not payload["ground_ok"]):
					continue
				var d: float = e.position.distance_to(cur.position)
				if d < best:
					best = d
					nxt = e
			if nxt == null:
				break
			mult *= 0.8
			hit.append(nxt)
			pts.append(nxt.position)
			hs.append(nxt.height + 0.35)
			_apply_hit(payload, nxt, mult)
			cur = nxt
		var fx := Fx.new()
		fx.setup(self, "bolt", Vector2.ZERO, 0, color, 0.2)
		fx.points = pts
		fx.heights = hs
		add_child(fx)
		return
	var splash := float(payload.get("splash", 0.0))
	if splash > 0.0:
		for e in enemies.duplicate():
			if e.dead:
				continue
			if (e.flying and not payload["air_ok"]) or (not e.flying and not payload["ground_ok"]):
				continue
			if e.position.distance_to(pos) <= splash + e.radius * 0.5:
				_apply_hit(payload, e, 1.0 if e == target else 0.7)
		spawn_fx("impact", pos, splash, color, 0.5)
	elif target != null:
		_apply_hit(payload, target, 1.0)
		spawn_fx("hit", target.position, T * 0.25, color, 0.3)


func _apply_hit(payload: Dictionary, e: Enemy, mult: float) -> void:
	if e.dead:
		return
	var dmg := float(payload["damage"]) * mult
	if e.flying:
		dmg *= float(payload.get("air_bonus", 1.0))
	if bool(payload.get("crit", false)) and mult >= 1.0:
		float_text(e.position + Vector2(0, -e.radius - 14), "¡CRÍTICO!", Color(1, 0.4, 0.2))
	e.take_damage(dmg, payload["type"])
	if e.dead:
		return
	var ex := float(payload.get("execute", 0.0))
	if ex > 0.0 and not e.is_boss and e.hp / e.max_hp < ex:
		float_text(e.position, "¡EJECUTADO!", Color(0.8, 0.4, 1.0))
		e.die()
		return
	if float(payload.get("armor_break", 0.0)) > 0.0:
		e.armor_break = maxf(e.armor_break, float(payload["armor_break"]) * e.armor)
	if float(payload.get("slow", 0.0)) > 0.0:
		e.apply_slow(float(payload["slow"]), float(payload["slow_dur"]))
	if float(payload.get("dot", 0.0)) > 0.0:
		e.apply_dot(float(payload["dot"]), float(payload["dot_dur"]), payload["type"])
	if float(payload.get("stun_chance", 0.0)) > 0.0 and randf() < float(payload["stun_chance"]):
		e.apply_stun(float(payload["stun_dur"]))


func heal_area(pos: Vector2, r: float, pct: float) -> void:
	for e in enemies:
		if not e.dead and e.position.distance_to(pos) <= r:
			e.hp = minf(e.max_hp, e.hp + e.max_hp * pct)


func on_enemy_killed(e: Enemy) -> void:
	enemies.erase(e)
	spawn_fx("death", e.position, e.radius * 1.4, Color(e.def["color"], 1.0), 0.6)
	var g := int(ceil(e.gold_value * (1.0 + Save.upgrade_value("gold_kill")) * (2.0 if bounty_time > 0.0 else 1.0)))
	gold += g
	if coop != "":
		partner_gold += g
	# Monedas por monstruo: crecen con el mapa y la oleada (los jefes y élites dan mucho más)
	var kc := maxi(1, int(WaveGen.coins_for_wave(map_idx, wave) * (0.8 if e.is_boss else (0.2 if e.elite else 0.04))))
	coins_earned += kc
	Save.data["coins"] = Save.coins() + kc
	Save.data["stats"]["kills"] = int(Save.data["stats"]["kills"]) + 1
	Meta.track("kills", 1)
	if e.flying:
		Meta.track("flyers", 1)
	if e.is_boss:
		Meta.track("bosses", 1)
		var bg := int(round(GameData.boss_gold(map_idx, wave) * (1.0 + Save.gem_upgrade_value("g_coins"))))
		Save.add_coins(bg)
		coins_earned += bg
		float_text(e.position, "+%d oro" % g, UIKit.GOLD)
		float_text(e.position + Vector2(0, -26), "+%s oro (jefe)" % GameData.format_num(bg), UIKit.GOLD)
		_boss_banner(e.def["name"], bg)
		spawn_fx("boss_death", e.position, T * 1.8, Color(1, 0.8, 0.2), 1.6)
	elif e.elite:
		float_text(e.position, "+%d" % g, UIKit.GOLD)


func on_enemy_leaked(e: Enemy) -> void:
	enemies.erase(e)
	var loss := 10 if e.is_boss else (3 if e.elite else 1)
	lives -= loss
	spawn_fx("screen", Vector2.ZERO, 0, Color(1, 0, 0), 0.3)
	Audio.sfx("hurt", -2.0, 0.05, 0.15)
	Audio.vibrate(60 if loss > 1 else 30)
	if lives <= 0:
		lives = 0
		_game_over()
	_refresh_hud()


func float_text(pos: Vector2, text: String, color: Color) -> void:
	if not bool(Save.data.get("settings", {}).get("float_text", true)):
		return
	var fx := Fx.new()
	fx.setup(self, "text", pos, 0, color, 0.9)
	fx.text = text
	add_child(fx)


func spawn_fx(kind: String, pos: Vector2, r: float, color: Color, duration := 0.35) -> void:
	if kind == "levelup":
		Audio.sfx("levelup", -4.0, 0.0, 0.1)
	var fx := Fx.new()
	fx.setup(self, kind, pos, r, color, duration)
	add_child(fx)


# ================================================================ Héroe
func _use_ability(h: Tower = null) -> void:
	if h == null: # sin indicar: el primer héroe con la habilidad lista
		for x in heroes:
			if is_instance_valid(x) and x.ability_cd <= 0.0:
				h = x
				break
	if h == null or not is_instance_valid(h) or h.ability_cd > 0.0 or over:
		return
	var dmg := h.damage()
	match h.def["ability"]:
		"warcry":
			for e in enemies:
				if e.position.distance_to(h.position) <= T * 3.5:
					e.apply_stun(3.0)
			spawn_fx("heal", h.position, T * 3.5, Color(1, 0.9, 0.5), 0.6)
		"haste":
			haste_time = 8.0
			spawn_fx("screen", Vector2.ZERO, 0, Color(0.4, 1, 0.5), 0.5)
		"meteor":
			for e in enemies.duplicate():
				spawn_fx("burst", e.position, T * 0.6, Color(1, 0.4, 0.1), 0.5)
				e.take_damage(dmg * 15.0, "fire")
			spawn_fx("screen", Vector2.ZERO, 0, Color(1, 0.4, 0.1), 0.6)
		"shieldwall":
			lives += 2
			for e in enemies:
				if e.position.distance_to(h.position) <= T * 3.0:
					e.apply_slow(0.5, 6.0)
			spawn_fx("heal", h.position, T * 3.0, Color(0.6, 0.75, 1.0), 0.6)
		"blessing":
			lives += 3
			blessing_time = 10.0
			spawn_fx("screen", Vector2.ZERO, 0, Color(1, 1, 0.7), 0.6)
		"dragonbreath":
			for e in enemies:
				e.apply_dot(dmg * 1.5, 5.0, "fire")
				e.apply_slow(0.5, 5.0)
			spawn_fx("screen", Vector2.ZERO, 0, Color(0.8, 0.1, 0.05), 0.6)
		"volley":
			for e in enemies.duplicate():
				if is_instance_valid(e) and e.position.distance_to(h.position) <= T * 4.0:
					spawn_fx("burst", e.position, T * 0.4, Color(0.8, 0.7, 0.4), 0.4)
					e.take_damage(dmg * 6.0, "physical")
		"heal":
			lives += 6
			spawn_fx("heal", castle_plane, T * 2.0, Color(0.5, 1.0, 0.6), 0.8)
		"forge":
			forge_time = 12.0
			spawn_fx("screen", Vector2.ZERO, 0, Color(1.0, 0.6, 0.25), 0.5)
		"net":
			for e in enemies:
				if e.position.distance_to(h.position) <= T * 3.5:
					e.apply_slow(0.3, 5.0)
			spawn_fx("heal", h.position, T * 3.5, Color(0.75, 0.65, 0.45), 0.6)
		"thorns":
			for e in enemies:
				e.apply_dot(dmg * 1.2, 6.0, "poison")
			spawn_fx("screen", Vector2.ZERO, 0, Color(0.4, 0.85, 0.3), 0.5)
		"bounty":
			bounty_time = 15.0
			spawn_fx("screen", Vector2.ZERO, 0, Color(1.0, 0.85, 0.3), 0.5)
		"anthem":
			anthem_time = 10.0
			spawn_fx("screen", Vector2.ZERO, 0, Color(1.0, 0.6, 0.8), 0.5)
		"curse":
			for e in enemies.duplicate():
				if is_instance_valid(e) and not e.dead:
					spawn_fx("burst", e.position, T * 0.5, Color(0.55, 0.3, 0.75), 0.5)
					e.take_damage(e.hp * (0.06 if e.is_boss else 0.2), "true")
			spawn_fx("screen", Vector2.ZERO, 0, Color(0.45, 0.2, 0.6), 0.6)
		"storm":
			var pool: Array = enemies.duplicate()
			pool.shuffle()
			for e in pool.slice(0, 12):
				if is_instance_valid(e) and not e.dead:
					spawn_fx("burst", e.position, T * 0.5, Color(0.6, 0.8, 1.0), 0.4)
					e.apply_stun(1.0)
					e.take_damage(dmg * 10.0, "lightning")
			spawn_fx("screen", Vector2.ZERO, 0, Color(0.5, 0.65, 1.0), 0.5)
		# --- Héroes nuevos ---
		"sanctify":
			lives += 3
			for e in enemies:
				if e.position.distance_to(h.position) <= T * 3.0:
					e.apply_stun(1.5)
			spawn_fx("heal", h.position, T * 3.0, Color(1.0, 0.95, 0.7), 0.6)
		"timber":
			for e in enemies.duplicate():
				if is_instance_valid(e) and not e.dead and e.position.distance_to(h.position) <= T * 3.0:
					spawn_fx("burst", e.position, T * 0.5, Color(0.6, 0.4, 0.2), 0.4)
					e.apply_stun(1.0)
					e.take_damage(dmg * 8.0, "physical")
		"goldrain":
			var g := 25 + wave * 3
			gold += g
			float_text(h.position, "+%d oro" % g, UIKit.GOLD)
			spawn_fx("heal", h.position, T * 1.5, UIKit.GOLD, 0.6)
		"smite":
			var best = null
			for e in enemies:
				if is_instance_valid(e) and not e.dead and (best == null or e.hp > best.hp):
					best = e
			if best != null:
				spawn_fx("burst", best.position, T * 0.8, Color(1.0, 0.3, 0.3), 0.5)
				best.take_damage(dmg * 30.0, "physical")
		"rally":
			forge_time = maxf(forge_time, 8.0)
			anthem_time = maxf(anthem_time, 8.0)
			spawn_fx("screen", Vector2.ZERO, 0, Color(0.4, 0.55, 1.0), 0.5)
		"timewarp":
			for e in enemies:
				e.apply_slow(0.4, 6.0)
			spawn_fx("screen", Vector2.ZERO, 0, Color(0.35, 0.25, 0.6), 0.6)
		"skyspear":
			for e in enemies.duplicate():
				if is_instance_valid(e) and not e.dead and e.position.distance_to(h.position) <= T * 4.0:
					spawn_fx("burst", e.position, T * 0.5, Color(0.85, 0.9, 1.0), 0.4)
					e.apply_stun(1.5)
					e.take_damage(dmg * 12.0, "physical")
		"frostnova":
			for e in enemies:
				e.apply_stun(1.0 if e.is_boss else 3.0)
				e.apply_slow(0.5, 6.0)
			spawn_fx("screen", Vector2.ZERO, 0, Color(0.6, 0.85, 1.0), 0.7)
		"earthquake":
			for e in enemies.duplicate():
				if is_instance_valid(e) and not e.dead and not e.flying:
					e.apply_stun(1.5)
					e.take_damage(dmg * 12.0, "physical")
			spawn_fx("screen", Vector2.ZERO, 0, Color(0.6, 0.45, 0.3), 0.6)
		"dawn":
			lives += 6
			blessing_time = 10.0
			for e in enemies.duplicate():
				if is_instance_valid(e) and not e.dead:
					e.take_damage(dmg * 8.0, "holy")
			spawn_fx("screen", Vector2.ZERO, 0, Color(1.0, 0.95, 0.7), 0.7)
		"harvest":
			for e in enemies.duplicate():
				if not is_instance_valid(e) or e.dead:
					continue
				spawn_fx("burst", e.position, T * 0.5, Color(0.45, 1.0, 0.55), 0.4)
				if e.is_boss:
					e.take_damage(e.hp * 0.1, "true")
				elif e.hp < e.max_hp * 0.35:
					e.take_damage(e.hp + 1.0, "true")
			spawn_fx("screen", Vector2.ZERO, 0, Color(0.3, 0.6, 0.35), 0.6)
	h.ability_cd = float(h.def["cooldown"]) * (1.0 - Save.gem_upgrade_value("g_hero_cd"))
	_refresh_hud()


# ================================================================ Guardado de partida
func _run_state() -> Dictionary:
	var list: Array = []
	var hero_list: Array = []
	for t in towers.values():
		var d := {"id": t.id, "x": t.cell.x, "y": t.cell.y, "level": t.level, "spent": t.spent, "mode": t.target_mode}
		if t.is_hero:
			hero_list.append(d)
		else:
			list.append(d)
	return {"wave": last_cleared, "gold": gold, "lives": lives, "towers": list, "heroes": hero_list,
		"revived": revived, "coins_earned": coins_earned, "evolutions": evolutions, "cleared": cleared_obs}


func _save_run() -> void:
	Save.set_run(map_idx, _run_state())


## Al empezar o reanudar una partida en solitario: si el oro no llega al mínimo para jugar
## (oro inicial + Tesoro Real), se completa hasta ese mínimo.
func _ensure_min_gold() -> void:
	var floor_gold := GameData.START_GOLD + int(Save.upgrade_value("start_gold"))
	if gold < floor_gold:
		var gift := floor_gold - gold
		gold = floor_gold
		UIKit.toast(ui, "Tesoro Real: +%d oro para empezar" % gift, UIKit.GOLD)
	Save.save_game()


func _load_run(run: Dictionary) -> void:
	_ensure_min_gold() # el oro es el guardado: no se recupera el que había en la partida
	lives = int(run["lives"])
	wave = int(run["wave"])
	last_cleared = wave
	revived = bool(run.get("revived", false))
	evolutions = int(run.get("evolutions", 0))
	coins_earned = int(run.get("coins_earned", 0))
	for cl in run.get("cleared", []):
		var cc := Vector2i(int(cl[0]), int(cl[1]))
		if _clearable(cc):
			_clear_obstacle(cc, true)
	for d in run["towers"]:
		if not GameData.TOWERS.has(d["id"]):
			continue
		var cell := Vector2i(int(d["x"]), int(d["y"]))
		if not _in_grid(cell) or path_cells.has(cell) or blocked.has(cell):
			continue
		var t := Tower.new()
		t.setup(self, d["id"], cell)
		t.level = int(d["level"])
		t.spent = int(d["spent"])
		t.target_mode = d.get("mode", "first")
		add_child(t)
		towers[t.cell] = t
	# Héroes (las partidas antiguas guardaban uno solo en "hero")
	var hl: Array = run.get("heroes", [])
	if hl.is_empty() and run.get("hero") != null:
		hl = [run["hero"]]
	for h in hl:
		var hc := Vector2i(int(h["x"]), int(h["y"]))
		if not GameData.HEROES.has(h["id"]) or not Save.owns(h["id"]) or towers.has(hc) or heroes.size() >= MAX_HEROES or hero_on_field(h["id"]) != null:
			continue
		var t := Tower.new()
		t.setup(self, h["id"], hc, true)
		t.level = Save.hero_level(t.id)
		t.target_mode = h.get("mode", "first")
		add_child(t)
		towers[t.cell] = t
		heroes.append(t)
	_recalc_auras()
	for c in towers.keys():
		if deco_nodes.has(c):
			deco_nodes[c].visible = false


# ================================================================ HUD
const TOP_H := 84.0
const SHOP_H := 150.0
const BAR_H := 96.0 # barra inferior con Construir / Cartas / Demoler / habilidades


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ui)
	UIKit.apply_theme(ui)
	var W := GameData.screen().x

	# Sombra suave arriba para que las píldoras se lean sobre el mapa
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.04, 0.06, 0.14, 0.35)
	shade.size = Vector2(W, TOP_H - 2.0)
	ui.add_child(shade)

	# Una sola fila (pantalla ancha): pausa, vidas, oro, oleada ... botones y siguiente oleada
	var row := UIKit.hbox(10)
	row.position = Vector2(12, 10)
	row.size = Vector2(W - 24.0, 62)
	ui.add_child(row)
	var pause := UIKit.icon_button("pause", UIKit.NAVY, 60, 0.46)
	pause.tooltip_text = "Pausa (Esc)"
	pause.pressed.connect(_open_pause)
	row.add_child(pause)
	var p_lives := UIKit.pill("heart", "", 24, Color.WHITE, 120)
	p_lives.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p_lives.tooltip_text = "Vida de la fortaleza"
	lbl_lives = p_lives.get_meta("label")
	row.add_child(p_lives)
	var p_gold := UIKit.pill("coin", "", 24, Color(1.0, 0.9, 0.55), 170)
	p_gold.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p_gold.tooltip_text = "Oro"
	lbl_gold = p_gold.get_meta("label")
	row.add_child(p_gold)
	var p_wave := UIKit.pill("flag", "", 19, Color.WHITE, 520)
	p_wave.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_wave = p_wave.get_meta("label")
	lbl_wave.add_theme_font_override("font", UIKit.font(true))
	var wv := UIKit.vbox(-6)
	wv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wave_box: HBoxContainer = p_wave.get_child(0)
	wave_box.remove_child(lbl_wave)
	wv.add_child(lbl_wave)
	lbl_next = UIKit.label("", 15, UIKit.PARCHMENT)
	lbl_next.clip_text = true
	lbl_next.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_next.custom_minimum_size = Vector2(420, 0)
	wv.add_child(lbl_next)
	wave_box.add_child(wv)
	row.add_child(p_wave)
	var p_coins := UIKit.pill("coin_bag", "", 17, Color(1.0, 0.88, 0.6), 0)
	p_coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl_coins = p_coins.get_meta("label")
	row.add_child(p_coins)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	# Configuración siempre a mano durante la partida (la pausa mientras está abierta)
	var gear := UIKit.icon_button("gear", UIKit.WOOD, 58, 0.6)
	gear.tooltip_text = "Configuración"
	gear.pressed.connect(_open_settings_in_battle)
	row.add_child(gear)
	var ranges := UIKit.icon_button("eye", UIKit.NAVY, 58, 0.6)
	ranges.tooltip_text = "Ver el alcance de todas las torres (V)"
	ranges.pressed.connect(func() -> void:
		show_all_ranges = not show_all_ranges
		UIKit.set_button_color(ranges, UIKit.TEAL if show_all_ranges else UIKit.NAVY, 28))
	row.add_child(ranges)
	var rot := UIKit.icon_button("auto", UIKit.NAVY, 58, 0.6)
	rot.tooltip_text = "Girar la vista 90° (R)"
	rot.pressed.connect(_rotate_view)
	row.add_child(rot)
	btn_auto = UIKit.icon_button("auto", UIKit.NAVY, 58, 0.6)
	btn_auto.pressed.connect(func() -> void:
		auto_wave = not auto_wave
		_refresh_hud())
	row.add_child(btn_auto)
	btn_auto.visible = false # oleadas siempre automáticas
	btn_speed = UIKit.button("x1", UIKit.NAVY, 22, Vector2(64, 58))
	btn_speed.tooltip_text = "Velocidad (1, 2, 3)"
	UIKit.set_button_color(btn_speed, UIKit.NAVY, 28)
	btn_speed.pressed.connect(_cycle_speed)
	row.add_child(btn_speed)
	btn_next = UIKit.button("Iniciar oleada", UIKit.GREEN, 20, Vector2(250, 58))
	btn_next.tooltip_text = "Siguiente oleada (Espacio)"
	btn_next.pressed.connect(start_next_wave)
	row.add_child(btn_next)


	# Tienda de torres abajo (dock redondeado con desplazamiento horizontal)
	var bottom := PanelContainer.new()
	var bs := UIKit.card_style(Color(UIKit.NAVY, 0.94), UIKit.NAVY_DARK, 26, 3, 8)
	bs.border_color = Color(0.36, 0.5, 0.75)
	bs.set_border_width_all(2)
	bs.corner_radius_bottom_left = 0
	bs.corner_radius_bottom_right = 0
	bs.content_margin_left = 10
	bs.content_margin_right = 10
	bs.content_margin_top = 8
	bs.content_margin_bottom = 4
	bottom.add_theme_stylebox_override("panel", bs)
	bottom.position = Vector2(0, GameData.screen().y - BAR_H - SHOP_H)
	bottom.size = Vector2(W, SHOP_H)
	bottom.visible = false
	ui.add_child(bottom)
	shop_panel = bottom
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 16 # un clic con temblor no es un arrastre
	UIKit.drag_anywhere(scroll)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom.add_child(scroll)
	shop_list = UIKit.hbox(8)
	scroll.add_child(shop_list)

	# Barra inferior: Construir / Demoler / habilidad del héroe
	var bar := PanelContainer.new()
	var bar_style := UIKit.card_style(Color(UIKit.NAVY, 0.96), UIKit.NAVY_DARK, 0, 3, 8)
	bar_style.content_margin_left = 10
	bar_style.content_margin_right = 10
	bar_style.content_margin_top = 10
	bar_style.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.position = Vector2(0, GameData.screen().y - BAR_H)
	bar.size = Vector2(W, BAR_H)
	ui.add_child(bar)
	var bar_row := UIKit.hbox(10)
	bar.add_child(bar_row)
	btn_build = UIKit.button("", UIKit.GREEN, 19, Vector2(150, 72))
	UIKit.set_button_content(btn_build, "castle", "Construir", 18, 28.0)
	btn_build.pressed.connect(func() -> void: _toggle_build_menu("progress"))
	bar_row.add_child(btn_build)
	# Segundo menú: torres y héroes que se ganan en sobres
	btn_cards = UIKit.button("", UIKit.PURPLE, 19, Vector2(128, 72))
	UIKit.set_button_content(btn_cards, "cards", "Cartas", 18, 28.0)
	btn_cards.pressed.connect(func() -> void: _toggle_build_menu("cards"))
	bar_row.add_child(btn_cards)
	btn_demolish = UIKit.button("", UIKit.RED, 19, Vector2(128, 72))
	UIKit.set_button_content(btn_demolish, "hammer", "Demoler", 18, 28.0)
	btn_demolish.pressed.connect(_toggle_demolish)
	bar_row.add_child(btn_demolish)
	ability_row = UIKit.hbox(4)
	ability_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(ability_row)
	for i in MAX_HEROES:
		var ab := UIKit.button("", UIKit.PURPLE, 13, Vector2(0, 72))
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab.clip_text = true
		ab.visible = false
		var idx := i
		ab.pressed.connect(func() -> void:
			if idx < heroes.size():
				var hh: Tower = heroes[idx]
				if is_instance_valid(hh) and hh.ability_cd <= 0.0:
					UIKit.toast(ui, "%s: %s" % [hh.def["name"], hh.def["ability_name"]], UIKit.PURPLE)
				_use_ability(hh))
		ability_row.add_child(ab)
		ability_btns.append(ab)

	if coop == "" and Coop.role == "":
		_build_side_col()

	# Panel de información de la torre seleccionada (hoja crema redondeada)
	info_panel = UIKit.card(UIKit.CREAM, 26)
	info_panel.visible = false
	ui.add_child(info_panel)
	build_info = UIKit.card(UIKit.CREAM, 22)
	build_info.visible = false
	build_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(build_info)


## Columna derecha en la batalla: tienda, diario, misiones... Abre las mismas hojas del menú
## encima de la partida (que se pausa) y al cerrarlas se vuelve a jugar.
func _build_side_col() -> void:
	side_col = UIKit.vbox(4)
	side_col.position = Vector2(GameData.screen().x - 72.0, TOP_H + 12.0)
	ui.add_child(side_col)
	for it in BATTLE_SIDE:
		var id: String = it[0]
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(62, 62)
		var b := UIKit.icon_button(it[2], it[3], 58, 0.62)
		b.tooltip_text = it[1]
		b.pressed.connect(func() -> void: _open_side(id))
		holder.add_child(b)
		side_col.add_child(holder)
		_side_badges[id] = holder
	# Cambiar de mapa (se desbloquea al llegar a la oleada MAP_SWITCH_WAVE del primer mapa)
	if coop == "":
		var mh := Control.new()
		mh.custom_minimum_size = Vector2(62, 62)
		var unlocked := _map_switch_unlocked()
		var mb := UIKit.icon_button("map" if unlocked else "lock", Color(0.3, 0.62, 0.45) if unlocked else UIKit.GREY, 58, 0.62)
		mb.tooltip_text = "Mapas"
		mb.pressed.connect(_open_map_switch)
		mh.add_child(mb)
		side_col.add_child(mh)
	_refresh_side_badges()
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.autostart = true
	timer.timeout.connect(_refresh_side_badges)
	ui.add_child(timer)


func _refresh_side_badges() -> void:
	var menu_script: GDScript = load("res://scripts/ui/menu.gd")
	for id in _side_badges.keys():
		var holder: Control = _side_badges[id]
		var n: int = menu_script.side_badge(id)
		if id == "packs":
			holder.visible = n > 0
		var dot: Control = holder.get_node_or_null("Badge")
		if n <= 0:
			if dot != null:
				dot.queue_free()
			continue
		if dot == null:
			var p := PanelContainer.new()
			p.name = "Badge"
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_theme_stylebox_override("panel", UIKit.style(UIKit.RED, Color.WHITE, 12, 2))
			p.position = Vector2(38, -4)
			p.custom_minimum_size = Vector2(24, 24)
			var l := UIKit.label("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			l.name = "N"
			p.add_child(l)
			holder.add_child(p)
			dot = p
		(dot.get_node("N") as Label).text = str(n) if n < 10 else "9+"


func _open_side(id: String) -> void:
	if over or (_menu_overlay != null and is_instance_valid(_menu_overlay)):
		return
	_select(null)
	var was_paused := get_tree().paused
	get_tree().paused = true
	var m: Control = load("res://scenes/menu.tscn").instantiate()
	m.set("overlay", true)
	_menu_overlay = m
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	layer.add_child(m)
	m.connect("overlay_closed", func() -> void:
		layer.queue_free()
		get_tree().paused = was_paused
		_rebuild_shop() # las cartas nuevas de los sobres ya se pueden usar
		_refresh_side_badges()
		_refresh_hud())
	m.call("open_side", id)


## Botones Construir (torres del juego) y Cartas (torres y héroes de sobres):
## abren o cierran su menú; pulsar el otro cambia de lista.
func _toggle_build_menu(mode := "progress") -> void:
	_set_demolish(false)
	if shop_panel.visible and shop_mode == mode:
		shop_panel.visible = false
		build_id = ""
		_hide_preview()
		_update_highlights()
	else:
		if shop_mode != mode:
			build_id = ""
			_hide_preview()
		shop_mode = mode
		_rebuild_shop()
		shop_panel.visible = true
		_select(null)
	_update_build_buttons()


func _update_build_buttons() -> void:
	UIKit.set_button_color(btn_build, UIKit.GOLD if shop_panel.visible and shop_mode == "progress" else UIKit.GREEN)
	UIKit.set_button_color(btn_cards, UIKit.GOLD if shop_panel.visible and shop_mode == "cards" else UIKit.PURPLE)


## Botón Demoler: en este modo, tocar una torre la derriba y devuelve parte del oro.
func _toggle_demolish() -> void:
	_set_demolish(not demolish_mode)
	if demolish_mode:
		UIKit.toast(ui, "Toca una torre para demolerla (recuperas el 70%% del oro), un héroe para retirarlo, o un árbol o roca para quitarlo (%d oro)" % CLEAR_COST, UIKit.PARCHMENT)


## Árboles y rocas del tablero: se pueden quitar por oro para construir en su casilla.
const CLEAR_COST := 50
var cleared_obs: Array = [] # casillas [x, y] ya despejadas en esta partida


func _clearable(c: Vector2i) -> bool:
	return coop == "" and blocked.get(c, "") in ["tree", "rock"] and world.has_node("Obstacle_%d_%d" % [c.x, c.y])


func _clear_obstacle(c: Vector2i, free := false) -> void:
	if not free:
		if gold < CLEAR_COST:
			UIKit.toast(ui, "Necesitas %d de oro para quitarlo" % CLEAR_COST, UIKit.RED)
			return
		gold -= CLEAR_COST
	var node := world.get_node_or_null("Obstacle_%d_%d" % [c.x, c.y])
	var pos := V3.to3(GameData.cell_center(c))
	if node != null:
		node.queue_free()
	blocked.erase(c)
	cleared_obs.append([c.x, c.y])
	# La casilla pasa a ser construible: su marca de resaltado
	if not highlight_nodes.has(c):
		var hl := V3.box(Vector3(0.9, 0.02, 0.9), Color(1, 1, 1, 0.22), pos + Vector3(0, 0.012 + cell_h(c), 0), 0.0, world)
		hl.visible = false
		highlight_nodes[c] = hl
	if not free:
		spawn_fx("burst", GameData.cell_center(c), T * 0.7, Color(0.7, 0.62, 0.5), 0.5)
		float_text(GameData.cell_center(c), "-%d oro" % CLEAR_COST, UIKit.GOLD)
		Audio.sfx("build", -4.0, 0.0)
		_save_run()
		_update_highlights()
		_refresh_hud()


func _set_demolish(on: bool) -> void:
	demolish_mode = on
	if on:
		shop_panel.visible = false
		build_id = ""
		_select(null)
		_update_highlights()
		_update_build_buttons()
	UIKit.set_button_color(btn_demolish, Color(0.95, 0.35, 0.25) if on else UIKit.RED)
	for t in towers.values():
		t.set_demolish_mark(on)


func _demolish(t: Tower) -> void:
	if t.is_hero:
		# Retirar a un héroe libera su puesto (máximo 3 en el campo); no devuelve oro
		heroes.erase(t)
		towers.erase(t.cell)
		if deco_nodes.has(t.cell):
			deco_nodes[t.cell].visible = true
		if selected == t:
			_select(null)
		spawn_fx("burst", t.position, T * 0.7, Color(0.75, 0.65, 1.0), 0.5)
		float_text(t.position, "Retirado", UIKit.PARCHMENT)
		t.queue_free()
		_rebuild_shop()
		_recalc_auras()
		_refresh_hud()
		if towers.is_empty():
			_set_demolish(false)
		return
	if coop != "" and int(t.get_meta("side", 0)) != my_side:
		UIKit.toast(ui, "Esa torre es de tu aliado", UIKit.RED)
		return
	if coop == "client":
		Coop.request("sell", [t.cell.x, t.cell.y])
		return
	var refund := t.sell_value()
	gold += refund
	_coop_broadcast("sell", [t.cell.x, t.cell.y])
	towers.erase(t.cell)
	if deco_nodes.has(t.cell):
		deco_nodes[t.cell].visible = true
	spawn_fx("burst", t.position, T * 0.7, Color(0.7, 0.62, 0.5), 0.5)
	float_text(t.position, "+%d oro" % refund, UIKit.GOLD)
	t.queue_free()
	_rebuild_shop() # una torre de cartas demolida vuelve a estar disponible
	_recalc_auras()
	_refresh_hud()
	if towers.is_empty():
		_set_demolish(false)


func _rebuild_shop() -> void:
	for c in shop_list.get_children():
		c.queue_free()
	shop_buttons.clear()
	var ids: Array = []
	if shop_mode == "cards":
		# Menú de cartas: primero lo que tienes (héroes y luego torres), después lo que falta (bloqueado).
		# Cada grupo va ordenado por color de rareza (común → legendaria).
		# Héroes: se colocan gratis, hasta MAX_HEROES a la vez y uno de cada.
		var h_owned: Array = []
		var h_missing: Array = []
		if coop == "":
			for hid in GameData.sort_by_rarity(GameData.HEROES.keys()):
				(h_owned if Save.owns(hid) else h_missing).append(hid)
		var owned: Array = []
		var missing: Array = []
		for id in GameData.sort_by_rarity(GameData.TOWERS.keys()):
			if not Meta.is_progress_tower(id):
				(owned if Save.owns(id) else missing).append(id)
		ids.append_array(h_owned.map(func(h): return HERO_KEY + ":" + h))
		ids.append_array(owned)
		ids.append_array(h_missing.map(func(h): return HERO_KEY + ":" + h))
		ids.append_array(missing)
	else:
		# Menú normal: torres de oro. Primero las que tienes (por rareza), luego las que faltan (se consiguen en sobres)
		var prog: Array = GameData.sort_by_rarity(GameData.TOWERS.keys().filter(func(id): return Meta.is_progress_tower(id)), true)
		prog = prog.filter(func(id): return Meta.tower_available(id)) + prog.filter(func(id): return not Meta.tower_available(id))
		ids.append_array(prog)
	for id in ids:
		var is_hero_btn: bool = id.begins_with(HERO_KEY)
		var hero_id: String = id.substr(HERO_KEY.length() + 1) if is_hero_btn else ""
		var locked: bool = (not Save.owns(hero_id)) if is_hero_btn else not Meta.tower_available(id)
		var hero_out: bool = (is_hero_btn and hero_on_field(hero_id) != null) or (not is_hero_btn and not locked and not Meta.is_progress_tower(id) and has_tower(id))
		var card_id: String = hero_id if is_hero_btn else id
		var def: Dictionary = GameData.HEROES[hero_id] if is_hero_btn else GameData.TOWERS[id]
		var rc: Color = GameData.RARITIES[def["rarity"]]["color"]
		# Carta de la tienda: modelo 3D + nombre + píldora de coste
		var b := UIKit.button("", UIKit.PURPLE if is_hero_btn else Color(0.3, 0.38, 0.58).lerp(rc, 0.25), 15, Vector2(118, 128))
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		var bn: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
		bn.border_color = rc
		b.add_theme_stylebox_override("normal", bn)
		var v := UIKit.vbox(0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 4
		v.offset_right = -4
		v.offset_top = 4
		v.offset_bottom = -8
		b.add_child(v)
		var icon := CardIcon.new()
		icon.card_id = card_id
		icon.custom_minimum_size = Vector2(104, 66)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		var nl := UIKit.label(def["name"], 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size = Vector2(106, 0)
		v.add_child(nl)
		if locked:
			var lock_txt := "En sobres"
			var lp := UIKit.pill("lock", lock_txt, 13, Color(0.85, 0.85, 0.9), 0, Color(0, 0, 0, 0.5))
			lp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(lp)
			icon.modulate = Color(0.35, 0.35, 0.4)
			b.set_meta("locked", true)
		else:
			var cost := UIKit.pill("coin" if not is_hero_btn else "crown", "En el campo" if hero_out else (("Máx. %d" % MAX_HEROES if heroes.size() >= MAX_HEROES else "Gratis") if is_hero_btn else GameData.format_num(tower_cost(id))), 16 if not hero_out else 13, Color(1.0, 0.92, 0.6), 0, Color(0, 0, 0, 0.4))
			cost.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(cost)
			b.set_meta("cost_label", cost.get_meta("label"))
		if hero_out:
			b.set_meta("hero_out", true)
		var sel := Panel.new()
		sel.name = "Sel"
		sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ss := StyleBoxFlat.new()
		ss.draw_center = false
		ss.border_color = UIKit.GOLD
		ss.set_border_width_all(5)
		ss.set_corner_radius_all(20)
		ss.shadow_color = Color(1.0, 0.85, 0.3, 0.6)
		ss.shadow_size = 8
		sel.add_theme_stylebox_override("panel", ss)
		sel.set_anchors_preset(Control.PRESET_FULL_RECT)
		sel.offset_left = -3
		sel.offset_top = -3
		sel.offset_right = 3
		sel.offset_bottom = 3
		sel.visible = false
		b.add_child(sel)
		b.pressed.connect(func() -> void:
			if bool(b.get_meta("locked", false)):
				if is_hero_btn:
					UIKit.toast(ui, "%s: consíguelo en los sobres de héroes de la Tienda" % def["name"], UIKit.PURPLE)
				elif Meta.is_progress_tower(id):
					UIKit.toast(ui, "%s: %s" % [GameData.TOWERS[id]["name"], Meta.unlock_text(id)], UIKit.PARCHMENT)
				else:
					UIKit.toast(ui, "%s: consíguela en los sobres de la Tienda" % GameData.TOWERS[id]["name"], UIKit.PURPLE)
				return
			if bool(b.get_meta("hero_out", false)):
				UIKit.toast(ui, "Ya está en el campo: las cartas son únicas (una de cada una)", UIKit.PARCHMENT)
				return
			if is_hero_btn:
				if Save.data["selected_hero"] != hero_id:
					Save.data["selected_hero"] = hero_id
					Save.save_game()
					if build_id == HERO_KEY:
						build_id = "" # se elige el nuevo héroe en vez de anular la construcción
				_choose_build(HERO_KEY)
				return
			_choose_build(id))
		shop_list.add_child(b)
		shop_buttons[id] = b


func _choose_build(id: String) -> void:
	_hide_preview()
	if build_id == id:
		build_id = ""
	else:
		_select(null)
		build_id = id
	_update_build_info()
	_update_highlights()
	_refresh_hud()


## Ficha de lo elegido para construir: qué hace, daño, alcance, velocidad, nivel y rasgos.
func _update_build_info() -> void:
	if build_info == null:
		return
	for c in build_info.get_children():
		c.queue_free()
	if build_id == "" or not shop_panel.visible:
		build_info.visible = false
		return
	var hero := build_id == HERO_KEY
	var id: String = str(Save.data["selected_hero"]) if hero else build_id
	var def: Dictionary = GameData.HEROES[id] if hero else GameData.TOWERS[id]
	# Torre de prueba (sin añadir a la escena) para usar las mismas fórmulas que en la partida
	var t := Tower.new()
	t.setup(self, id, Vector2i(-99, -99), hero)
	t.level = Save.hero_level(id) if hero else Meta.tower_start_level(id)
	var v := UIKit.vbox(5)
	build_info.add_child(v)
	var rar: Dictionary = GameData.RARITIES[def["rarity"]]
	var head := UIKit.hbox(10)
	v.add_child(head)
	var nm := UIKit.ink(def["name"], 21, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var lvl_txt := "Nv. %d" % t.level
	if hero:
		lvl_txt = "Héroe · Carta Nv. %d" % Save.card_level(id) + ((" · Entreno %d" % t.level) if t.level > 0 else "")
	elif t.is_card:
		lvl_txt = "Carta Nv. %d" % Save.card_level(id)
	head.add_child(UIKit.ink("%s · %s" % [rar["name"], lvl_txt], 16, (rar["color"] as Color).darkened(0.35), HORIZONTAL_ALIGNMENT_RIGHT, true))
	var desc: String
	if hero:
		desc = "%s. %s: %s (recarga %ds)" % [def["title"], def["ability_name"], def["ability_desc"], int(def["cooldown"])]
	else:
		desc = str(def["desc"])
	var dl := UIKit.ink(desc, 16, UIKit.INK_SOFT)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(660, 0)
	v.add_child(dl)
	var stats := UIKit.hbox(18)
	v.add_child(stats)
	if float(def.get("damage", 0.0)) > 0.0:
		stats.add_child(UIKit.icon_label("sword", GameData.format_num(t.damage()), 18, UIKit.INK, 26, true))
		stats.add_child(UIKit.icon_label("range", "%.1f" % (t.range_px() / GameData.TILE), 18, UIKit.INK, 26, true))
		stats.add_child(UIKit.icon_label("bolt", "%.2f/s" % t.rate(), 18, UIKit.INK, 26, true))
		stats.add_child(UIKit.ink(GameData.DAMAGE_TYPES[def["dmg_type"]]["name"], 16, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true))
	elif def.has("range"):
		stats.add_child(UIKit.icon_label("range", "%.1f" % (t.range_px() / GameData.TILE), 18, UIKit.INK, 26, true))
	if not hero:
		stats.add_child(UIKit.icon_label("coin", str(tower_cost(id)), 18, UIKit.INK, 26, true))
	var traits: Array = []
	if not hero and def.has("air"):
		traits.append("Aire y tierra" if def.get("air", false) and def.get("ground", true) else ("Solo aire" if def.get("air", false) else "Solo tierra"))
	if float(def.get("splash", 0.0)) > 0.0:
		traits.append("Daño en área")
	if float(def.get("dot", 0.0)) > 0.0:
		traits.append("Daño continuo")
	if float(def.get("slow", 0.0)) > 0.0:
		traits.append("Ralentiza")
	if float(def.get("stun_chance", 0.0)) > 0.0:
		traits.append("Aturde")
	if int(def.get("chain", 0)) > 0:
		traits.append("Rebota a %d enemigos" % int(def["chain"]))
	if int(def.get("gold_per_wave", 0)) > 0:
		traits.append("+%d oro por oleada" % int(def["gold_per_wave"]))
	if not traits.is_empty():
		v.add_child(UIKit.ink(" · ".join(traits), 15, UIKit.BLUE.darkened(0.35), HORIZONTAL_ALIGNMENT_LEFT, true))
	t.free()
	v.add_child(UIKit.ink("Toca una casilla para ver su alcance y otra vez para colocarlo", 14, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var was_visible := build_info.visible
	build_info.visible = true
	build_info.custom_minimum_size = Vector2(704, 0)
	build_info.reset_size()
	build_info.position = Vector2(8, shop_panel.position.y - build_info.size.y - 8)
	_place_build_info.call_deferred()
	if not was_visible:
		UIKit.pop_in(build_info, 0.0, 0.9)


func _place_build_info() -> void:
	if build_info != null and build_info.visible:
		build_info.reset_size()
		build_info.position = Vector2(8, shop_panel.position.y - build_info.size.y - 8)


func _refresh_hud() -> void:
	if lbl_lives == null:
		return
	var t_lives := str(lives)
	var t_gold := GameData.format_num(gold)
	if lbl_lives.text != t_lives and lbl_lives.text != "":
		UIKit.pop(lbl_lives.get_parent() as Control, 1.25)
	if lbl_gold.text != t_gold and lbl_gold.text != "":
		UIKit.pop(lbl_gold, 1.18)
	lbl_lives.text = t_lives
	lbl_gold.text = t_gold
	lbl_wave.text = "Oleada %d / %d" % [wave, GameData.MAX_WAVES]
	var nxt := WaveGen.preview_text(map_idx, wave + 1)
	lbl_next.text = ("Siguiente: " + nxt) if nxt != "" else "Récord: %d" % Save.best_wave(map_idx)
	if auto_wave and spawn_queue.is_empty() and enemies.is_empty() and wave < GameData.MAX_WAVES and coop != "client":
		lbl_next.text = "Oleada %d en %ds" % [wave + 1, ceili(auto_timer)]
	# Un solo contador de oro: la bolsa solo se muestra en cooperativo (oro del aliado)
	(lbl_coins.get_parent().get_parent() as Control).visible = coop != "" # label -> fila icono+texto -> píldora
	if coop != "":
		lbl_coins.text = "Aliado: %s oro" % GameData.format_num(partner_gold)
	if bool(btn_auto.get_meta("on", false)) != auto_wave:
		btn_auto.set_meta("on", auto_wave)
		UIKit.set_button_color(btn_auto, UIKit.GREEN if auto_wave else UIKit.NAVY, 28)
	btn_speed.text = "x%d" % speed
	if int(btn_speed.get_meta("spd", 1)) != speed:
		btn_speed.set_meta("spd", speed)
		UIKit.set_button_color(btn_speed, UIKit.NAVY if speed == 1 else (UIKit.ORANGE if speed == 2 else UIKit.RED), 28)
	var spawning := not spawn_queue.is_empty()
	btn_next.disabled = spawning or wave >= GameData.MAX_WAVES
	if wave == 0:
		btn_next.text = "Iniciar oleada"
	elif not enemies.is_empty() and not spawning:
		btn_next.text = "Adelantar (+%d)" % (10 + wave)
	else:
		btn_next.text = "Siguiente oleada"
	for id in shop_buttons.keys():
		var b: Button = shop_buttons[id]
		var poor: bool = not id.begins_with(HERO_KEY) and gold < tower_cost(id)
		if bool(b.get_meta("locked", false)) or bool(b.get_meta("hero_out", false)):
			b.disabled = false # se puede tocar para ver cómo conseguirla
			b.modulate = Color(0.8, 0.8, 0.85, 0.85)
			continue
		b.disabled = poor
		b.modulate = Color(1, 1, 1, 0.78) if poor else Color.WHITE
		var sel_node := b.get_node_or_null("Sel")
		if sel_node != null:
			(sel_node as Control).visible = build_id == id or (build_id == HERO_KEY and id == HERO_KEY + ":" + str(Save.data["selected_hero"]))
		if b.has_meta("cost_label"):
			(b.get_meta("cost_label") as Label).add_theme_color_override("font_color", Color(1.0, 0.55, 0.5) if poor else Color(1.0, 0.92, 0.6))
	for i in ability_btns.size():
		var ab: Button = ability_btns[i]
		var hh: Tower = heroes[i] if i < heroes.size() and is_instance_valid(heroes[i]) else null
		ab.visible = hh != null
		if hh == null:
			continue
		var cd := hh.ability_cd
		ab.disabled = cd > 0.0
		var txt := "%s\n%s" % [str(hh.def["name"]).split(" ")[-1], ("%ds" % ceili(cd)) if cd > 0.0 else "¡YA!"]
		if ab.text != txt:
			ab.text = txt
			UIKit.set_button_color(ab, UIKit.GREY if cd > 0.0 else (hh.def["color"] as Color).lerp(UIKit.PURPLE, 0.55), 14)
	if selected != null and info_panel.visible and is_instance_valid(selected):
		_update_info_buttons()
	if build_info != null and build_info.visible and (build_id == "" or not shop_panel.visible):
		_update_build_info() # se construyó o se cerró el menú: fuera la ficha


var _info_up: Button
var _info_sell: Button


func _update_info_panel() -> void:
	for c in info_panel.get_children():
		c.queue_free()
	if selected == null or not is_instance_valid(selected):
		info_panel.visible = false
		return
	var t := selected
	var was_visible := info_panel.visible
	info_panel.visible = true
	var v := UIKit.vbox(8)
	info_panel.add_child(v)
	# Cabecera: modelo 3D + nombre + estrellas de nivel + cerrar
	var head := UIKit.hbox(10)
	v.add_child(head)
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := UIKit.style(Color(0.8, 0.88, 0.97), GameData.RARITIES[t.def["rarity"]]["color"], 18, 3)
	fs.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", fs)
	var icon := CardIcon.new()
	icon.card_id = t.id
	icon.level = t.level
	icon.custom_minimum_size = Vector2(84, 74)
	frame.add_child(icon)
	head.add_child(frame)
	var hv := UIKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hv.add_child(UIKit.ink(t.def["name"], 24, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	if t.is_hero:
		hv.add_child(UIKit.ink(t.def["title"], 14, UIKit.INK_SOFT))
	var stars := UIKit.hbox(2)
	var shown_lvl: int = Save.card_level(t.id) if t.is_card else t.level
	for k in (GameData.HERO_MAX_LEVEL if t.is_hero else (GameData.MAX_CARD_LEVEL if t.is_card else GameData.MAX_TOWER_LEVEL)):
		stars.add_child(UIIcon.make("star" if k < shown_lvl else "star_off", 18 if t.is_hero else (24 if t.is_card else 15)))
	stars.add_child(UIKit.ink("  Carta Nv. %d" % Save.card_level(t.id), 14, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, true))
	hv.add_child(stars)
	head.add_child(hv)
	var close := UIKit.icon_button("close", UIKit.RED, 56, 0.48)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func() -> void: _select(null))
	head.add_child(close)
	# Estadísticas con iconos
	if t.can_attack():
		var stats := UIKit.hbox(16)
		stats.add_child(UIKit.icon_label("sword", GameData.format_num(t.damage()), 19, UIKit.INK, 28, true))
		stats.add_child(UIKit.icon_label("range", "%.1f" % (t.range_px() / T), 19, UIKit.INK, 28, true))
		stats.add_child(UIKit.icon_label("bolt", "%.2f/s" % t.rate(), 19, UIKit.INK, 28, true))
		var dt: Dictionary = GameData.DAMAGE_TYPES[t.def["dmg_type"]]
		stats.add_child(UIKit.ink(dt["name"], 16, (dt["color"] as Color).darkened(0.45), HORIZONTAL_ALIGNMENT_LEFT, true))
		var air := t.is_hero or bool(t.def.get("air", false))
		var ground := t.is_hero or bool(t.def.get("ground", true))
		var target_txt := "Tierra y aire" if air and ground else ("Solo aire" if air else "Solo tierra")
		stats.add_child(UIKit.ink(target_txt, 16, UIKit.GREEN.darkened(0.35) if air and ground else UIKit.AMBER.darkened(0.3), HORIZONTAL_ALIGNMENT_LEFT, true))
		if t.def.get("detect", false):
			stats.add_child(UIKit.ink("Detecta invisibles", 16, UIKit.PURPLE.darkened(0.2), HORIZONTAL_ALIGNMENT_LEFT, true))
		for c in stats.get_children():
			(c as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_child(stats)
	var lines: Array = []
	if cell_h(t.cell) > 0.0:
		lines.append("En lo alto de una colina: +%d%% de alcance" % int(HEIGHT_RANGE_BONUS * cell_h(t.cell) * 100.0))
	var max_l := GameData.HERO_MAX_LEVEL if t.is_hero else GameData.MAX_TOWER_LEVEL
	if t.level < max_l and t.can_attack() and not t.is_card:
		var d0 := t.damage()
		var r0 := t.range_px() / T
		var s0 := t.rate()
		t.level += 1
		var d1 := t.damage()
		var r1 := t.range_px() / T
		var s1 := t.rate()
		t.level -= 1
		var nxt := "AL SUBIR DE NIVEL:  Daño %s → %s  ·  Alcance %.1f → %.1f  ·  Vel. %.2f → %.2f" % [GameData.format_num(d0), GameData.format_num(d1), r0, r1, s0, s1]
		if not t.is_hero and t.level + 1 == GameData.MAX_TOWER_LEVEL:
			nxt += "\n¡Desbloquea la MAESTRÍA! " + str(t.def["perk_desc"]).replace("Maestría: ", "")
		var nl := UIKit.ink(nxt, 15, UIKit.GREEN.darkened(0.35), HORIZONTAL_ALIGNMENT_LEFT, true)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(640, 0)
		v.add_child(nl)
	if t.aura_mult > 1.0:
		lines.append("Bendecida: +%d%% daño" % int(round((t.aura_mult - 1.0) * 100)))
	if t.range_aura_mult > 1.0:
		lines.append("Inspirada por un Heraldo: +%d%% alcance" % int(round((t.range_aura_mult - 1.0) * 100)))
	if t.speed_aura_mult > 1.0:
		lines.append("Campanario cerca: +%d%% velocidad" % int(round((t.speed_aura_mult - 1.0) * 100)))
	if t.is_hero:
		lines.append("Habilidad: %s - %s" % [t.def["ability_name"], t.def["ability_desc"]])
	else:
		lines.append(("MAESTRÍA ACTIVA: " + t.def["perk_desc"]) if t.mastered() else (t.def["perk_desc"] + (" (carta al nivel 5)" if t.is_card else "")))
	var info := UIKit.ink("\n".join(lines), 15, UIKit.INK_SOFT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(640, 0)
	v.add_child(info)
	var row := UIKit.hbox(10)
	v.add_child(row)
	_info_up = UIKit.button("", UIKit.GREEN, 18, Vector2(250, 68))
	_info_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_up.pressed.connect(_upgrade_selected)
	row.add_child(_info_up)
	if not t.is_hero:
		_info_sell = UIKit.button("", UIKit.RED, 17, Vector2(170, 68))
		UIKit.set_button_content(_info_sell, "coin", "Vender\n+%d" % t.sell_value(), 17, 30)
		_info_sell.pressed.connect(_sell_selected)
		row.add_child(_info_sell)
	if t.can_attack():
		var tm := UIKit.button("", UIKit.BLUE, 16, Vector2(180, 68))
		UIKit.set_button_content(tm, "target", "Objetivo\n" + Tower.TARGET_NAMES[t.target_mode], 16, 30)
		tm.pressed.connect(_cycle_target)
		row.add_child(tm)
	_update_info_buttons()
	# Coloca el panel en el lado (izquierdo o derecho) opuesto a la torre.
	info_panel.custom_minimum_size = Vector2(704, 0)
	info_panel.reset_size()
	var sx := screen_pos(t.position).x
	var x := 16.0 if sx > GameData.screen().x * 0.5 else GameData.screen().x - 704.0 - 90.0
	info_panel.position = Vector2(x, TOP_H + 10.0)
	if not was_visible:
		UIKit.pop_in(info_panel, 0.0, 0.85)


func _update_info_buttons() -> void:
	if _info_up == null or not is_instance_valid(_info_up) or selected == null:
		return
	var cost := selected.upgrade_cost()
	if selected.is_card:
		_info_up.disabled = true
		var cl := Save.card_level(selected.id)
		if cl >= GameData.MAX_CARD_LEVEL:
			UIKit.set_button_content(_info_up, "star", "CARTA AL MÁXIMO", 18, 32)
		else:
			UIKit.set_button_content(_info_up, "cards", "Sube con cartas\nCarta Nv. %d/%d" % [cl, GameData.MAX_CARD_LEVEL], 16, 30)
	elif cost < 0:
		_info_up.disabled = true
		UIKit.set_button_content(_info_up, "star", "NIVEL MÁXIMO", 19, 32)
	elif selected.is_hero:
		_info_up.disabled = false
		UIKit.set_button_content(_info_up, "coin", "Subir nivel (permanente)\n%s oro" % GameData.format_num(Meta.hero_level_cost(selected.id)), 15, 30)
	else:
		_info_up.disabled = gold < cost
		if selected.level == GameData.MAX_TOWER_LEVEL - 1:
			UIKit.set_button_content(_info_up, "star", "Maestría\n%s oro" % GameData.format_num(cost), 18, 34)
		else:
			UIKit.set_button_content(_info_up, "upgrade", "Mejorar (U)\n%s oro" % GameData.format_num(cost), 19, 34)


## Configuración durante la partida (la pausa mientras está abierta).
func _open_settings_in_battle() -> void:
	if over:
		return
	var was_paused := get_tree().paused
	get_tree().paused = true
	var sp := SettingsPanel.open(ui, true)
	sp.tree_exited.connect(func() -> void:
		if is_inside_tree() and not was_paused:
			get_tree().paused = false)


## Velocidad x1 → x2 → x3 (en PC sin restricciones).
func _cycle_speed() -> void:
	_set_speed(speed % 3 + 1)


func _set_speed(s: int) -> void:
	speed = s
	Engine.time_scale = float(s)
	_refresh_hud()


# ================================================================ Menús de pausa / fin
func _pause_popup(title: String, text: String) -> void:
	get_tree().paused = true
	var l := UIKit.label(text, 22, UIKit.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.popup(ui, title, l, [["Continuar", func() -> void: get_tree().paused = false, UIKit.GREEN]])


func _open_pause() -> void:
	if over:
		return
	get_tree().paused = true
	var v := UIKit.vbox(8)
	var ic := UIIcon.make("castle", 90)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(UIKit.ink(map_def["name"], 24, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	var st := UIKit.hbox(18)
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	st.add_child(UIKit.icon_label("flag", "Oleada %d" % wave, 19, UIKit.INK, 30, true))
	st.add_child(UIKit.icon_label("heart", str(lives), 19, UIKit.INK, 30, true))
	st.add_child(UIKit.icon_label("coin_bag", "+" + GameData.format_num(coins_earned), 19, UIKit.INK, 30, true))
	v.add_child(st)
	v.add_child(UIKit.ink("La partida se guarda al terminar cada oleada.", 16, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	UIKit.popup(ui, "Pausa", v, [
		["Continuar", func() -> void: get_tree().paused = false, UIKit.GREEN],
		["Salir al menú", func() -> void:
			if coop != "":
				_coop_leave()
				return
			_go_menu(), UIKit.BLUE],
		["Configuración", func() -> void:
			var sp := SettingsPanel.open(ui, true)
			sp.tree_exited.connect(func() -> void:
				if is_inside_tree() and not over:
					_open_pause()), UIKit.PURPLE],
		["Rendirse", func() -> void:
			get_tree().paused = false
			lives = 0
			_game_over(), UIKit.RED],
	])


func _game_over() -> void:
	if over:
		return
	Audio.play_music("defeat")
	if coop != "":
		_coop_end()
		return
	Online.report_wave(map_idx, last_cleared, true)
	over = true
	Engine.time_scale = 1.0
	speed = 1
	_select(null)
	Save.save_game()
	get_tree().paused = true
	_show_game_over()


func _show_game_over() -> void:
	var v := UIKit.vbox(10)
	var ic := UIIcon.make("skull", 90)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var msg := UIKit.ink("Los enemigos han tomado el castillo en la oleada %d." % wave, 21, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(600, 0)
	v.add_child(msg)
	var st := UIKit.hbox(24)
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	st.add_child(UIKit.icon_label("trophy", "Récord %d" % Save.best_wave(map_idx), 20, UIKit.AMBER, 34, true))
	st.add_child(UIKit.icon_label("coin_bag", "+%s%s" % [GameData.format_num(coins_earned), " (x2)" if doubled else ""], 20, UIKit.AMBER, 34, true))
	v.add_child(st)
	var buttons: Array = []
	# Revivir: gratis, sigue la partida con media vida de la fortaleza.
	buttons.append(["Revivir", _revive, UIKit.GREEN])
	buttons.append(["Salir", func() -> void:
		Save.set_run(map_idx, {})
		_go_menu(), UIKit.RED])
	UIKit.popup(ui, "Derrota", v, buttons, 760)


func _revive() -> void:
	over = false
	revived = true
	lives = 25 # media vida de la fortaleza
	for e in enemies:
		e.dead = true
		e.queue_free()
	enemies.clear()
	get_tree().paused = false
	UIKit.toast(ui, "¡Has vuelto a la batalla!", UIKit.GREEN)
	_refresh_hud()


func _victory() -> void:
	Audio.play_music("victory")
	over = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	Save.set_run(map_idx, {})
	Save.add_coins(500 * GameData.GEM_GOLD)
	var l := UIKit.vbox(10)
	var ic := UIIcon.make("trophy", 110)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.add_child(ic)
	UIKit.pulse(ic, 1.08)
	l.add_child(UIKit.ink("¡Has resistido las 500 oleadas de %s!" % map_def["name"], 22, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	var g := UIKit.icon_label("coin", "+%s oro" % GameData.format_num(500 * GameData.GEM_GOLD), 26, UIKit.AMBER.darkened(0.3), 40, true)
	g.alignment = BoxContainer.ALIGNMENT_CENTER
	l.add_child(g)
	UIKit.popup(ui, "¡VICTORIA LEGENDARIA!", l, [["Volver", _go_menu, UIKit.GREEN]])


## Cambiar de mapa desde la partida: se desbloquea al llegar a esta oleada en el primer mapa.
const MAP_SWITCH_WAVE := 100


func _map_switch_unlocked() -> bool:
	return Save.best_wave(0) >= MAP_SWITCH_WAVE


func _open_map_switch() -> void:
	if over:
		return
	if not _map_switch_unlocked():
		UIKit.toast(ui, "Cambiar de mapa se desbloquea al llegar a la oleada %d de %s" % [MAP_SWITCH_WAVE, GameData.MAPS[0]["name"]], UIKit.PARCHMENT)
		return
	get_tree().paused = true
	var v := UIKit.vbox(8)
	v.add_child(UIKit.ink("Elige el mapa al que quieres ir:", 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UIKit.drag_anywhere(scroll)
	var list := UIKit.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	v.add_child(scroll)
	var popup_ref := {"p": null}
	for i in GameData.MAPS.size():
		var name_txt: String = "%d. %s" % [i + 1, GameData.MAPS[i]["name"]]
		if i == map_idx:
			list.add_child(UIKit.icon_label("flag", name_txt + "  (estás aquí)", 18, UIKit.INK_SOFT, 26, true))
			continue
		if not Save.is_map_unlocked(i):
			list.add_child(UIKit.icon_label("lock", name_txt, 18, UIKit.INK_SOFT, 26, true))
			continue
		var target := i
		var b := UIKit.button("%s · récord %d" % [name_txt, Save.best_wave(i)], UIKit.GREEN, 18, Vector2(0, 56))
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(func() -> void: _confirm_map_switch(target, popup_ref["p"]))
		list.add_child(b)
	popup_ref["p"] = UIKit.popup(ui, "Cambiar de mapa", v, [["Cancelar", func() -> void: get_tree().paused = false, UIKit.GREY]], 690)


## Aviso: al irse se pierde el progreso de la partida de este mapa (torres, oleada actual).
func _confirm_map_switch(target: int, list_popup: Control) -> void:
	var msg := UIKit.label("Si cambias a %s se perderá el progreso de este mapa (oleada %d, torres y héroes colocados).\nTu récord y todo lo permanente se conservan." % [GameData.MAPS[target]["name"], wave], 19, UIKit.PARCHMENT, HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(600, 0)
	UIKit.popup(ui, "¿Cambiar de mapa?", msg, [
		["Cambiar de mapa", func() -> void:
			Save.set_run(map_idx, {}) # se pierde la partida de este mapa
			Save.save_game()
			GameData.current_map = target
			get_tree().paused = false
			Engine.time_scale = 1.0
			EnemyModels._templates.clear()
			EnemyModels._meshes.clear()
			preload("res://scripts/towers3d/models.gd")._meshes.clear()
			get_tree().change_scene_to_file("res://scenes/game.tscn"), UIKit.RED],
		["Cancelar", Callable(), UIKit.GREY]]) # vuelve a la lista de mapas (list_popup sigue abierta)


func _go_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Save.save_game()
	# Libera la geometría guardada de esta partida (enemigos del mapa, variantes de torres):
	# si no, se acumula de un mapa a otro y el sistema acaba cerrando el juego por memoria.
	EnemyModels._templates.clear()
	EnemyModels._meshes.clear()
	preload("res://scripts/towers3d/models.gd")._meshes.clear()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")



# ================================================================ Cooperativo
func side_of(c: Vector2i) -> int:
	return 0 if c.x < GameData.COLS / 2 else 1


func _coop_setup() -> void:
	Coop.game = self
	my_side = 1 if coop == "client" else 0
	gold = GameData.START_GOLD + int(Save.upgrade_value("start_gold"))
	partner_gold = gold
	lives = GameData.START_LIVES
	auto_wave = true
	# Línea dorada que separa las dos mitades del tablero
	var x := V3.to3(GameData.cell_center(Vector2i(GameData.COLS / 2, 0))).x - 0.5
	V3.box(Vector3(0.06, 0.03, GameData.ROWS), Color(1, 0.8, 0.3), Vector3(x, 0.02, 0), 1.2, world)
	var who := "con un aliado IA" if coop == "ai" else "con tu aliado"
	UIKit.toast(ui, "Cooperativo %s: tu mitad es la %s" % [who, "izquierda" if my_side == 0 else "derecha"], UIKit.GOLD)


func _coop_broadcast(ev: String, args: Array) -> void:
	if coop == "host":
		Coop.send_event(ev, args)


## Anfitrión: aplica una acción pedida por el jugador 2.
func coop_remote_action(action: String, args: Array) -> void:
	match action:
		"build":
			var c := Vector2i(int(args[0]), int(args[1]))
			var id: String = args[2]
			if not GameData.TOWERS.has(id) or towers.has(c) or path_cells.has(c) or blocked.has(c) or side_of(c) != 1:
				return
			var cost := tower_cost(id)
			if partner_gold < cost:
				return
			partner_gold -= cost
			_place_tower(id, c, 1, 0, cost)
			Coop.send_event("build", [c.x, c.y, id, 1, 0])
		"upgrade":
			var t: Tower = towers.get(Vector2i(int(args[0]), int(args[1])))
			if t == null or int(t.get_meta("side", 0)) != 1:
				return
			var cost := t.upgrade_cost()
			if cost < 0 or partner_gold < cost:
				return
			partner_gold -= cost
			t.spent += cost
			t.level += 1
			_recalc_auras()
			Coop.send_event("upgrade", [t.cell.x, t.cell.y])
		"sell":
			var t: Tower = towers.get(Vector2i(int(args[0]), int(args[1])))
			if t == null or int(t.get_meta("side", 0)) != 1:
				return
			partner_gold += t.sell_value()
			_remove_tower(t)
			Coop.send_event("sell", [t.cell.x, t.cell.y])
		"next":
			start_next_wave()


func _place_tower(id: String, c: Vector2i, side: int, level: int, spent: int) -> Tower:
	var t := Tower.new()
	t.setup(self, id, c)
	t.level = level
	t.spent = spent
	t.set_meta("side", side)
	add_child(t)
	towers[c] = t
	if deco_nodes.has(c):
		deco_nodes[c].visible = false
	_recalc_auras()
	_update_highlights()
	spawn_fx("build", t.position, T * 0.6, Color(0.75, 0.62, 0.45), 0.8)
	return t


func _remove_tower(t: Tower) -> void:
	towers.erase(t.cell)
	if selected == t:
		_select(null)
	t.queue_free()
	_recalc_auras()
	_update_highlights()


## Cliente: eventos que envía el anfitrión.
func coop_event(ev: String, args: Array) -> void:
	match ev:
		"build":
			var c := Vector2i(int(args[0]), int(args[1]))
			if not towers.has(c):
				_place_tower(args[2], c, int(args[3]), int(args[4]), 0)
		"upgrade":
			var t: Tower = towers.get(Vector2i(int(args[0]), int(args[1])))
			if t != null:
				t.level += 1
				spawn_fx("levelup", t.position, T * 0.7, UIKit.GOLD, 1.2)
				_recalc_auras()
				if selected == t:
					_update_info_panel()
		"sell":
			var t: Tower = towers.get(Vector2i(int(args[0]), int(args[1])))
			if t != null:
				_remove_tower(t)
		"end":
			wave = int(args[0])
			_coop_end()


func _coop_send_snapshot() -> void:
	var list: Array = []
	for e in enemies:
		if not e.dead:
			list.append([e.uid, e.id, e.position.x, e.position.y, e.hp, e.max_hp, e.elite])
	Coop.send_snapshot({"w": wave, "l": lives, "g": [gold, partner_gold], "e": list})


## Cliente: aplica el estado recibido (enemigos como títeres, oro, vidas y oleada).
func coop_snapshot(d: Dictionary) -> void:
	var prev_wave := wave
	wave = int(d["w"])
	last_cleared = maxi(wave - 1, 0)
	lives = int(d["l"])
	gold = int(d["g"][1])
	partner_gold = int(d["g"][0])
	if wave > prev_wave:
		var label := WaveGen.preview_text(map_idx, wave)
		if label != "":
			UIKit.toast(ui, "Oleada %d: %s" % [wave, label], UIKit.GOLD)
	var seen := {}
	for row in d["e"]:
		var uid := int(row[0])
		seen[uid] = true
		var e: Enemy = _puppets.get(uid)
		var pos := Vector2(float(row[2]), float(row[3]))
		if e == null or not is_instance_valid(e):
			e = Enemy.new()
			e.setup(self, row[1], 1.0, 0, paths_points[0], 1, pos)
			e.puppet = true
			e.uid = uid
			e.elite = bool(row[6])
			add_child(e)
			enemies.append(e)
			_puppets[uid] = e
		e.net_pos = pos
		e.max_hp = float(row[5])
		e.hp = float(row[4])
	for uid in _puppets.keys():
		if not seen.has(uid):
			var e: Enemy = _puppets[uid]
			_puppets.erase(uid)
			if is_instance_valid(e):
				enemies.erase(e)
				spawn_fx("death", e.position, e.radius * 1.4, Color(e.def["color"], 1.0), 0.6)
				e.dead = true
				e.queue_free()


## Aliado IA: construye y mejora torres en la mitad derecha con su propio oro.
func _ai_ally_turn() -> void:
	var options: Array = []
	for id in GameData.TOWERS.keys():
		if Meta.tower_available(id) and GameData.TOWERS[id]["rate"] > 0.0:
			options.append(id)
	if options.is_empty():
		return
	var id: String = options[randi() % options.size()]
	var mine: Array = []
	for t in towers.values():
		if int(t.get_meta("side", 0)) == 1:
			mine.append(t)
	if mine.size() < 7 and partner_gold >= tower_cost(id):
		var best := Vector2i(-1, -1)
		var best_score := -1
		for x in range(GameData.COLS / 2, GameData.COLS):
			for y in GameData.ROWS:
				var c := Vector2i(x, y)
				if towers.has(c) or path_cells.has(c) or blocked.has(c):
					continue
				var sc := 0
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						if path_cells.has(c + Vector2i(dx, dy)):
							sc += 1
				if sc > best_score:
					best_score = sc
					best = c
		if best.x >= 0:
			partner_gold -= tower_cost(id)
			_place_tower(id, best, 1, 0, tower_cost(id))
			return
	var cheapest: Tower = null
	for t in mine:
		var uc: int = t.upgrade_cost()
		if uc > 0 and t.level < GameData.MAX_TOWER_LEVEL - 1 and (cheapest == null or uc < cheapest.upgrade_cost()):
			cheapest = t
	if cheapest != null and partner_gold >= cheapest.upgrade_cost():
		partner_gold -= cheapest.upgrade_cost()
		cheapest.spent += cheapest.upgrade_cost()
		cheapest.level += 1
		_recalc_auras()


func coop_partner_left() -> void:
	if over:
		return
	if coop == "host":
		coop = "ai" # la partida sigue con un aliado IA
		UIKit.toast(ui, "Tu aliado se desconectó: ahora te ayuda la IA", UIKit.RED)
	elif coop == "client":
		UIKit.toast(ui, "Se perdió la conexión con la sala", UIKit.RED)
		_coop_end()


## Fin de la partida cooperativa: oro según la oleada alcanzada (máximo 100).
func _coop_end() -> void:
	if over:
		return
	over = true
	Engine.time_scale = 1.0
	_coop_broadcast("end", [wave])
	var reached := mini(maxi(last_cleared, wave - 1) if lives <= 0 else wave, Coop.MAX_WAVE)
	var v := UIKit.vbox(10)
	var ic := UIIcon.make("trophy" if reached >= Coop.MAX_WAVE else "shield", 90)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	v.add_child(UIKit.ink("Llegasteis a la oleada %d de %d" % [reached, Coop.MAX_WAVE], 22, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	var buttons: Array = []
	var got := Meta.claim_coop_reward(reached)
	var g := UIKit.icon_label("coin", "+%s oro" % GameData.format_num(got), 26, UIKit.AMBER.darkened(0.3), 40, true)
	g.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(g)
	buttons.append(["Volver", _coop_leave, UIKit.GREEN])
	UIKit.popup(ui, "Defensa cooperativa", v, buttons, 640)


func _coop_leave() -> void:
	Coop.leave()
	_go_menu()



## Cartel "¡JEFE DERROTADO!" con el oro ganado.
## No pausa la partida y desaparece solo.
func _boss_banner(boss_name: String, gold_won: int) -> void:
	Audio.sfx("coin", -2.0, 0.0)
	var card := UIKit.card(UIKit.CREAM, 26)
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.custom_minimum_size = Vector2(560, 0)
	card.position = Vector2((GameData.screen().x - 560.0) * 0.5, 160)
	var v := UIKit.vbox(6)
	card.add_child(v)
	var rib := UIKit.ribbon("¡JEFE DERROTADO!", UIKit.RED, 26)
	rib.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(rib)
	v.add_child(UIKit.ink(boss_name, 24, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER, true))
	var reward := UIKit.icon_label("coin", "+%s oro" % GameData.format_num(gold_won), 28, UIKit.AMBER.darkened(0.3), 40, true)
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(reward)
	# Se cierra solo a los pocos segundos (o con "Cerrar")
	get_tree().create_timer(5.0, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(card):
			card.queue_free())
	var close_b := UIKit.button("Cerrar", UIKit.GREY, 18, Vector2(200, 52))
	close_b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_b.pressed.connect(func() -> void:
		if is_instance_valid(card):
			card.queue_free())
	v.add_child(close_b)
	ui.add_child(card)
	card.scale = Vector2(0.6, 0.6)
	card.pivot_offset = Vector2(280, 100)
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)



## La Fortaleza desde la partida (tocando el castillo): las mismas mejoras permanentes
## del menú, con oro. Se aplican al momento.
func _open_fortress() -> void:
	if over or coop == "client":
		return
	get_tree().paused = true
	if _fortress_popup != null and is_instance_valid(_fortress_popup):
		_fortress_popup.queue_free()
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 16 # un clic con temblor no es un arrastre
	UIKit.drag_anywhere(scroll)
	scroll.custom_minimum_size = Vector2(700, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UIKit.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	list.add_child(UIKit.ink("Mejoras permanentes para todos los mapas", 17, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, true))
	for id in GameData.UPGRADES.keys():
		var def: Dictionary = GameData.UPGRADES[id]
		list.add_child(_fortress_row(def["name"], def["desc"], Save.upgrade_level(id), int(def["max"]), "coin", Meta.upgrade_cost(id), Save.coins(), func() -> bool: return Meta.buy_upgrade(id)))
	list.add_child(UIKit.ink("Mejoras especiales", 20, UIKit.BLUE.darkened(0.3), HORIZONTAL_ALIGNMENT_CENTER, true))
	for id in GameData.GEM_UPGRADES.keys():
		var def: Dictionary = GameData.GEM_UPGRADES[id]
		list.add_child(_fortress_row(def["name"], def["desc"], Save.gem_upgrade_level(id), int(def["max"]), "coin", Meta.gem_upgrade_cost(id), Save.coins(), func() -> bool: return Meta.buy_gem_upgrade(id)))
	list.add_child(UIKit.ink("Entrenamiento de torres", 20, UIKit.PURPLE.darkened(0.3), HORIZONTAL_ALIGNMENT_CENTER, true))
	list.add_child(UIKit.ink("Nivel con el que se construye cada torre, en todos los mapas", 15, UIKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	for id in GameData.TOWERS.keys():
		if not Meta.tower_available(id) or not Meta.is_progress_tower(id):
			continue
		var tdef: Dictionary = GameData.TOWERS[id]
		list.add_child(_fortress_row(tdef["name"], "Se construye en nivel %d" % Meta.tower_start_level(id), Save.tower_train_level(id), GameData.TOWER_TRAIN_MAX, "coin", Meta.tower_train_cost(id), Save.coins(), func() -> bool: return Meta.buy_tower_train(id)))
	_fortress_popup = UIKit.popup(ui, "La Fortaleza", scroll, [["Volver a la batalla", func() -> void:
		get_tree().paused = false, UIKit.GREEN]], 690)


func _fortress_row(title: String, desc: String, lvl: int, maxl: int, currency: String, cost: int, have: int, buy: Callable) -> Control:
	var p := UIKit.inset()
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := UIKit.hbox(10)
	p.add_child(row)
	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.ink("%s  (Nv. %d/%d)" % [title, lvl, maxl], 18, UIKit.INK, HORIZONTAL_ALIGNMENT_LEFT, true))
	var dl := UIKit.ink(desc, 14, UIKit.INK_SOFT)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(380, 0)
	info.add_child(dl)
	row.add_child(info)
	if lvl >= maxl:
		row.add_child(UIKit.ink("MÁX", 18, UIKit.AMBER.darkened(0.3), HORIZONTAL_ALIGNMENT_CENTER, true))
	else:
		var afford := have >= cost
		var b := UIKit.button("", (UIKit.GREEN if currency == "coin" else UIKit.BLUE) if afford else UIKit.RED, 18, Vector2(150, 58))
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		UIKit.set_button_content(b, currency, GameData.format_num(cost), 18, 26)
		b.pressed.connect(func() -> void:
			if not afford:
				UIKit.toast(ui, "Te faltan %s %s" % [GameData.format_num(cost - have), "oro" if currency == "coin" else "gemas"], UIKit.RED)
				return
			if buy.call():
				spawn_fx("levelup", castle_plane, T * 1.5, UIKit.GOLD, 1.2)
				_recalc_auras()
				_refresh_hud()
				_open_fortress())
		row.add_child(b)
	return p
