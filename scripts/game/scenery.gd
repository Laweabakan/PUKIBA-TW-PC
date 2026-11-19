class_name Scenery
extends RefCounted
## Paisaje de cada mapa: agua animada, puentes, obstáculos del tablero, terreno exterior
## con bosques, montañas, aldea o ruinas, y "vida" (pájaros, partículas, molino, niebla...).
##
## Uso (una vez por mapa, después de dibujar el tablero):
##     var scenery := Scenery.build(world, MapGen.generate(map_idx), GameData.MAPS[map_idx])
##
## Rendimiento: los objetos repetidos se dibujan con MultiMesh (una llamada por material),
## las animaciones van en shaders (agua, follaje, aleteo) o en scripts mínimos (scenery_life.gd).

const M := preload("res://scripts/towers3d/models.gd")
const SM := preload("res://scripts/game/scenery_models.gd")
const Life := preload("res://scripts/game/scenery_life.gd")

const MARGIN := 16.0      # paisaje hasta 16 casillas más allá del tablero
const MARGIN_TOP := 26.0  # hacia arriba (lejos de la cámara) se ve hasta el horizonte
const STEP := 0.5         # resolución del terreno
const GROUND_Y := -0.14   # suelo exterior junto al tablero
const WATER_Y := -0.1     # superficie del agua
const WATER_OUT := -0.22  # fuera del tablero el agua va más baja que el suelo (-0.14)
const CASTLE_R := 2.5     # zona libre alrededor del castillo

## Modelos que siempre se fusionan en la malla estática aunque haya muchos
const BAKE_IDS := ["house_timber", "house_timber2", "house_snow", "house_stone", "house_adobe", "house_elven",
	"house_ruin", "chapel", "windmill_body", "tent", "stilt_hut", "crypt", "bridge_wood", "bridge_stone",
	"giant_gate", "dark_tower", "ribcage", "volcano_cone", "fence", "iron_fence", "gravestones",
	"grave_small", "grave_cross"]

## Detalles pequeños del paisaje: sin sombra (ahorra llamadas de dibujo)
const SMALL_IDS := ["bush", "flowers", "pebble", "sheep", "grass", "mushrooms", "bones", "crystal_shards",
	"reeds", "grave_small", "grave_cross", "dune", "skull_pile"]

static var _shaders := {}


# ================================================================== Entrada
static func build(world: Node3D, info: Dictionary, map_def: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Scenery"
	world.add_child(root)
	if info.is_empty():
		return root
	var ctx := _make_ctx(info, map_def, root)
	_extra_water(ctx)
	_build_terrain(ctx)
	_build_water(ctx)
	_build_bridges(ctx)
	_build_obstacles(ctx)
	_build_landscape(ctx)
	_build_life(ctx)
	_flush(ctx)
	return root


# ================================================================== Configuración por temática
static func _cfg(theme: String) -> Dictionary:
	# props: [id, cantidad, distancia mínima al tablero, distancia máxima]
	var c := {
		"trees": ["oak"], "forest": 0.35, "props": [], "mount": "mountain_snow", "mount_n": 22,
		"settle": "none", "houses": ["house_timber"], "n_houses": 8, "fields": false, "windmill": false,
		"chapel": false, "smoke": false, "birds": "", "parts": [], "mist": Color(0, 0, 0, 0),
		"clouds": "", "hills": 0.9, "rise": 1.6, "high": Color(0.5, 0.5, 0.48), "high_snow": false,
		"grass": 0, "landmark": "", "ponds": 0, "floaters": "", "fence": "fence",
		"obs": {"rock": "boulder", "tree": "oak", "ruin": "pillar_ruin", "log": "log_pile"},
	}
	match theme:
		"meadow":
			c.trees = ["oak", "oak", "poplar"]; c.forest = 0.3; c.settle = "village"
			c.houses = ["house_timber", "house_timber2"]; c.n_houses = 10; c.fields = true; c.windmill = true
			c.chapel = true; c.smoke = true; c.birds = "birds"; c.parts = ["pollen", "butterflies"]; c.clouds = "white"
			c.props = [["bush", 45, 0.6, 14.0], ["flowers", 50, 0.5, 9.0], ["sheep", 10, 2.0, 9.0], ["pebble", 12, 0.6, 12.0], ["well", 1, 2.5, 5.0]]
			c.grass = 160; c.ponds = 1; c.high = Color(0.42, 0.58, 0.3)
			c.obs = {"rock": "boulder", "tree": "oak", "ruin": "haystack", "log": "cart"}
		"whispering_forest":
			c.trees = ["oak_dark", "pine", "pine", "oak_dark"]; c.forest = 0.8; c.settle = "village"
			c.houses = ["house_timber"]; c.n_houses = 5; c.smoke = true; c.birds = "birds"
			c.parts = ["fireflies", "leaves"]; c.mist = Color(0.7, 0.82, 0.7, 0.18); c.mount = "mountain"
			c.props = [["bush", 50, 0.6, 14.0], ["mushrooms", 10, 0.6, 8.0], ["boulder_mossy", 14, 0.6, 12.0], ["standing_stones", 2, 3.0, 9.0]]
			c.grass = 90; c.high = Color(0.2, 0.36, 0.2)
			c.obs = {"rock": "boulder_mossy", "tree": "oak_dark", "ruin": "shrine", "log": "mushrooms"}
		"stone_hills":
			c.trees = ["pine", "oak", "poplar"]; c.forest = 0.18; c.settle = "village"; c.hills = 1.8; c.rise = 2.2
			c.houses = ["house_stone"]; c.n_houses = 8; c.fields = true; c.windmill = true; c.smoke = true
			c.birds = "birds"; c.clouds = "white"; c.high = Color(0.46, 0.5, 0.36)
			c.props = [["boulder", 40, 0.6, 15.0], ["pebble", 30, 0.5, 12.0], ["standing_stones", 3, 3.0, 10.0], ["sheep", 12, 2.0, 10.0], ["bush", 15, 0.6, 10.0]]
			c.grass = 80
			c.obs = {"rock": "boulder", "tree": "pine", "ruin": "standing_stones", "log": "log_pile"}
		"swamp":
			c.trees = ["willow", "dead", "willow"]; c.forest = 0.45; c.mount = "mountain"; c.hills = 0.4; c.rise = 1.0
			c.birds = "bats"; c.parts = ["fireflies"]; c.mist = Color(0.6, 0.75, 0.55, 0.6); c.ponds = 5
			c.props = [["reeds", 60, 0.5, 12.0], ["mushroom", 8, 0.8, 10.0], ["boulder_mossy", 10, 0.6, 12.0], ["stilt_hut", 4, 2.5, 9.0]]
			c.high = Color(0.3, 0.34, 0.24)
			c.obs = {"rock": "boulder_mossy", "tree": "willow", "ruin": "stilt_hut", "log": "mushrooms"}
		"graveyard":
			c.trees = ["dead", "dead", "oak_dark"]; c.forest = 0.3; c.settle = "ruins"; c.mount = "mountain"
			c.houses = ["house_ruin"]; c.n_houses = 4; c.birds = "crows"; c.parts = ["wisps"]; c.fence = "iron_fence"
			c.mist = Color(0.7, 0.72, 0.78, 0.6); c.high = Color(0.3, 0.32, 0.32)
			c.props = [["grave_small", 70, 0.6, 9.0], ["grave_cross", 45, 0.6, 9.0], ["crypt", 5, 1.5, 9.0], ["boulder", 10, 0.6, 12.0]]
			c.obs = {"rock": "boulder", "tree": "dead", "ruin": "crypt", "log": "gravestones"}
		"frost_mountains":
			c.trees = ["snowpine", "snowpine", "pine"]; c.forest = 0.55; c.settle = "village"; c.hills = 1.6; c.rise = 3.0
			c.houses = ["house_snow"]; c.n_houses = 7; c.smoke = true; c.birds = "birds"; c.parts = ["snow"]
			c.high = Color(0.95, 0.97, 1.0); c.high_snow = true; c.mount_n = 26
			c.props = [["snow_rock", 25, 0.6, 14.0], ["watchtower_ruin", 1, 3.0, 8.0]]
			c.obs = {"rock": "snow_rock", "tree": "snowpine", "ruin": "watchtower_ruin", "log": "frozen_log"}
		"glacier":
			c.trees = ["ice_spike"]; c.forest = 0.22; c.settle = "camp"; c.houses = ["tent"]; c.n_houses = 4
			c.parts = ["snow", "snow"]; c.high = Color(0.92, 0.96, 1.0); c.high_snow = true; c.hills = 1.4; c.rise = 3.0
			c.props = [["ice_block", 22, 0.6, 14.0], ["snow_rock", 14, 0.6, 14.0], ["crystal_shards", 8, 0.6, 10.0]]
			c.obs = {"rock": "ice_block", "tree": "ice_spike", "ruin": "frozen_statue", "log": "frozen_log"}
		"ash_desert":
			c.trees = ["palm", "dead"]; c.forest = 0.08; c.settle = "village"; c.houses = ["house_adobe"]; c.n_houses = 8
			c.mount = "mesa"; c.mount_n = 16; c.smoke = true; c.birds = "vultures"; c.parts = ["ash"]; c.ponds = 1
			c.hills = 0.7; c.high = Color(0.82, 0.68, 0.45)
			c.props = [["sand_rock", 22, 0.6, 15.0], ["bones", 6, 0.8, 10.0], ["tent", 3, 2.5, 8.0]]
			c.obs = {"rock": "sand_rock", "tree": "palm", "ruin": "tent", "log": "bones"}
		"volcano":
			c.trees = ["obsidian", "burnt"]; c.forest = 0.22; c.mount = "mountain"; c.landmark = "volcano_cone"
			c.parts = ["embers", "ash"]; c.ponds = 6; c.hills = 1.2; c.rise = 2.4; c.high = Color(0.14, 0.11, 0.1)
			c.props = [["lava_rock", 26, 0.6, 15.0], ["charred_log", 6, 0.8, 10.0]]
			c.obs = {"rock": "lava_rock", "tree": "obsidian", "ruin": "dark_obelisk", "log": "charred_log"}
		"elven_ruins":
			c.trees = ["birch", "birch", "oak"]; c.forest = 0.45; c.settle = "village"; c.houses = ["house_elven"]
			c.n_houses = 6; c.birds = "birds"; c.parts = ["fireflies", "leaves"]; c.clouds = "white"
			c.props = [["pillar_ruin_white", 8, 1.0, 12.0], ["elven_arch", 3, 2.0, 10.0], ["flowers", 45, 0.5, 9.0], ["bush", 20, 0.6, 12.0]]
			c.grass = 100; c.high = Color(0.4, 0.55, 0.42)
			c.obs = {"rock": "boulder_mossy", "tree": "birch", "ruin": "elven_arch", "log": "pillar_ruin_white"}
		"fallen_fortress":
			c.trees = ["burnt", "dead"]; c.forest = 0.2; c.settle = "ruins"; c.houses = ["house_ruin"]; c.n_houses = 7
			c.mount = "mountain"; c.birds = "crows"; c.parts = ["embers", "smoke"]; c.high = Color(0.36, 0.34, 0.31)
			c.props = [["broken_wall", 12, 0.8, 12.0], ["weapons", 10, 0.6, 9.0], ["boulder", 10, 0.6, 12.0]]
			c.obs = {"rock": "boulder", "tree": "burnt", "ruin": "broken_wall", "log": "weapons"}
		"dragon_canyon":
			c.trees = ["dead"]; c.forest = 0.08; c.mount = "mesa"; c.mount_n = 26; c.hills = 2.2; c.rise = 2.5
			c.birds = "dragons"; c.parts = ["embers"]; c.landmark = "ribcage"; c.high = Color(0.62, 0.36, 0.22)
			c.props = [["sand_rock", 30, 0.6, 15.0], ["bones", 10, 0.6, 10.0], ["dragon_bones", 3, 1.0, 9.0]]
			c.obs = {"rock": "sand_rock", "tree": "dead", "ruin": "dragon_bones", "log": "bones"}
		"crystal_forest":
			c.trees = ["crystal_tree", "crystal_tree", "mushroom"]; c.forest = 0.5; c.mount = "spire"; c.settle = "ruins"
			c.houses = ["pillar_ruin"]; c.n_houses = 4; c.parts = ["sparkles"]; c.mist = Color(0.6, 0.6, 0.95, 0.35)
			c.props = [["crystal_cluster", 22, 0.6, 14.0], ["crystal_shards", 15, 0.6, 10.0], ["mushroom", 6, 0.8, 10.0]]
			c.high = Color(0.3, 0.3, 0.45)
			c.obs = {"rock": "crystal_cluster", "tree": "crystal_tree", "ruin": "pillar_ruin", "log": "crystal_shards"}
		"void_abyss":
			c.trees = ["void_spire"]; c.forest = 0.2; c.mount = "spire"; c.birds = "bats"; c.parts = ["motes"]
			c.mist = Color(0.45, 0.25, 0.7, 0.55); c.floaters = "void_rock"; c.high = Color(0.1, 0.08, 0.14)
			c.props = [["void_rock", 14, 0.6, 14.0], ["dark_obelisk", 4, 1.5, 10.0], ["crystal_shards", 8, 0.6, 10.0]]
			c.obs = {"rock": "void_rock", "tree": "void_spire", "ruin": "dark_obelisk", "log": "crystal_shards"}
		"lich_citadel":
			c.trees = ["dead"]; c.forest = 0.3; c.mount = "spire"; c.birds = "bats"; c.parts = ["wisps"]
			c.mist = Color(0.45, 0.8, 0.5, 0.5); c.landmark = "dark_tower"; c.fence = "iron_fence"; c.high = Color(0.2, 0.23, 0.22)
			c.props = [["grave_small", 35, 0.6, 9.0], ["grave_cross", 20, 0.6, 9.0], ["dark_obelisk", 4, 1.5, 10.0], ["cage", 4, 0.8, 8.0]]
			c.obs = {"rock": "boulder", "tree": "dead", "ruin": "dark_obelisk", "log": "cage"}
		"hellfire":
			c.trees = ["demon_spikes", "burnt"]; c.forest = 0.25; c.mount = "spire"; c.parts = ["embers", "embers"]
			c.ponds = 6; c.hills = 1.2; c.rise = 2.0; c.high = Color(0.18, 0.06, 0.05); c.birds = "bats"
			c.props = [["lava_rock", 22, 0.6, 15.0], ["skull_pile", 10, 0.6, 10.0], ["demon_altar", 2, 2.0, 9.0]]
			c.obs = {"rock": "lava_rock", "tree": "demon_spikes", "ruin": "demon_altar", "log": "skull_pile"}
		"sky_islands":
			c.trees = ["oak", "poplar"]; c.forest = 0.3; c.settle = "village"; c.houses = ["house_timber", "house_timber2"]
			c.n_houses = 6; c.windmill = true; c.smoke = true; c.birds = "birds"; c.clouds = "white"; c.mount = ""
			c.floaters = "sky_island"; c.hills = 0.25; c.rise = 0.0; c.grass = 70
			c.props = [["bush", 20, 0.6, 4.0], ["flowers", 30, 0.5, 4.0], ["gazebo", 1, 1.0, 3.5]]
			c.obs = {"rock": "floating_rock", "tree": "oak", "ruin": "gazebo", "log": "cart"}
		"ice_throne":
			c.trees = ["ice_spike"]; c.forest = 0.35; c.settle = "ruins"; c.houses = ["frozen_statue"]; c.n_houses = 5
			c.parts = ["snow", "sparkles"]; c.high = Color(0.42, 0.55, 0.78); c.mount = "mountain_snow"
			c.hills = 1.3; c.rise = 3.0; c.landmark = "dark_tower"
			c.props = [["ice_block", 22, 0.6, 14.0], ["crystal_cluster", 10, 0.6, 12.0], ["broken_wall", 6, 1.0, 10.0]]
			c.obs = {"rock": "ice_block", "tree": "ice_spike", "ruin": "frozen_statue", "log": "crystal_shards"}
		"abyss_gate":
			c.trees = ["demon_spikes", "dead"]; c.forest = 0.25; c.mount = "spire"; c.landmark = "giant_gate"
			c.parts = ["embers"]; c.birds = "bats"; c.ponds = 5; c.high = Color(0.14, 0.05, 0.1)
			c.props = [["skull_pile", 12, 0.6, 10.0], ["lava_rock", 16, 0.6, 14.0], ["dark_obelisk", 4, 1.5, 10.0]]
			c.obs = {"rock": "lava_rock", "tree": "demon_spikes", "ruin": "dark_obelisk", "log": "skull_pile"}
		"chaos_citadel":
			c.trees = ["void_spire", "demon_spikes"]; c.forest = 0.3; c.mount = "spire"; c.landmark = "dark_tower"
			c.parts = ["motes", "embers"]; c.birds = "bats"; c.floaters = "void_rock"
			c.mist = Color(0.5, 0.15, 0.25, 0.45); c.high = Color(0.08, 0.06, 0.08)
			c.props = [["void_rock", 12, 0.6, 14.0], ["broken_wall", 8, 1.0, 10.0], ["weapons", 8, 0.6, 9.0], ["dark_obelisk", 4, 1.5, 10.0]]
			c.obs = {"rock": "void_rock", "tree": "void_spire", "ruin": "broken_wall", "log": "weapons"}
	# Paisaje exterior más lleno en todos los mapas: más bosque, más objetos y más casas
	c.forest = minf(c.forest * 1.6 + 0.1, 0.92)
	for e in c.props:
		e[1] = int(ceil(int(e[1]) * 1.5))
	c.n_houses = int(c.n_houses) + 3
	c.grass = int(int(c.grass) * 1.3)
	return c


# ================================================================== Contexto
static func _make_ctx(info: Dictionary, map_def: Dictionary, root: Node3D) -> Dictionary:
	var theme: String = info.get("theme", map_def.get("deco", "meadow"))
	var cols: int = info["cols"]
	var rows: int = info["rows"]
	var ctx := {
		"root": root, "info": info, "theme": theme, "cfg": _cfg(theme), "pal": SM.palette(theme),
		"cols": cols, "rows": rows, "hx": cols * 0.5, "hz": rows * 0.5,
		"ground": map_def.get("ground", Color(0.36, 0.55, 0.26)), "path_col": map_def.get("path", Color(0.6, 0.5, 0.35)),
		"water_kind": String(info.get("water_kind", "water")), "inst": {}, "noshadow": {}, "big": [],
		"bake_root": Node3D.new(), "smoke_pts": PackedVector3Array(), "sky": theme == "sky_islands",
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("paisaje:%s:%d:%d" % [theme, cols, rows])
	ctx["rng"] = rng
	ctx.pal["ground"] = ctx.ground
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	ctx["noise"] = noise
	var noise2 := FastNoiseLite.new()
	noise2.seed = rng.randi()
	noise2.frequency = 0.13
	ctx["noise2"] = noise2
	# Agua extendida: agua + puentes (el agua pasa por debajo), prolongando los ríos hasta el borde
	var wext := {}
	var water: Dictionary = info.get("water", {})
	var bridges: Dictionary = info.get("bridges", {})
	for c in water.keys():
		wext[c] = true
	for c in bridges.keys():
		wext[c] = true
	var min_x := 9999
	var max_x := -9999
	for c in wext.keys():
		var cc: Vector2i = c
		min_x = mini(min_x, cc.x)
		max_x = maxi(max_x, cc.x)
	if min_x < 0 and max_x >= cols:
		var lefts: Array = []
		var rights: Array = []
		for c in wext.keys():
			var cc: Vector2i = c
			if cc.x == min_x:
				lefts.append(cc.y)
			if cc.x == max_x:
				rights.append(cc.y)
		for x in range(min_x - 1, -int(MARGIN) - 3, -1):
			for y in lefts:
				wext[Vector2i(x, y)] = true
		for x in range(max_x + 1, cols + int(MARGIN) + 3):
			for y in rights:
				wext[Vector2i(x, y)] = true
		ctx["river"] = true
	else:
		ctx["river"] = false
	ctx["wext"] = wext
	# Caminos exteriores (se prolongan como senderos hasta el horizonte) y castillo
	var roads: Array = []
	var paths: Array = info.get("paths", [])
	for pts in paths:
		var a: Vector2i = pts[0]
		var b: Vector2i = pts[1]
		var out := Vector2(a - b).normalized()
		var pa := _c2(ctx, a)
		roads.append([_c2(ctx, b), pa + out * (MARGIN_TOP + 8.0)])
	var exit: Vector2i = info.get("exit", Vector2i(cols / 2, rows))
	var castle := _c2(ctx, exit) + Vector2(0, 0.9)
	ctx["castle"] = castle
	if paths.size() > 0:
		var last: Array = paths[0]
		roads.append([_c2(ctx, last[last.size() - 2]), castle])
	ctx["roads"] = roads
	# Distancia (en casillas) al agua para suavizar las colinas junto a los ríos
	var wdist := {}
	var frontier: Array = wext.keys()
	for c in frontier:
		wdist[c] = 0
	for step in 4:
		var nxt: Array = []
		for c in frontier:
			var cc: Vector2i = c
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = cc + d
				if not wdist.has(n):
					wdist[n] = step + 1
					nxt.append(n)
		frontier = nxt
	ctx["wdist"] = wdist
	return ctx


# Casilla -> posición XZ del centro
static func _c2(ctx: Dictionary, c: Vector2i) -> Vector2:
	return Vector2(c.x + 0.5 - ctx.hx, c.y + 0.5 - ctx.hz)


# Posición XZ -> casilla
static func _cell(ctx: Dictionary, x: float, z: float) -> Vector2i:
	return Vector2i(floori(x + ctx.hx), floori(z + ctx.hz))


# Distancia de un punto al borde del tablero (0 dentro)
static func _board_d(ctx: Dictionary, x: float, z: float) -> float:
	var dx := maxf(absf(x) - ctx.hx, 0.0)
	var dz := maxf(absf(z) - ctx.hz, 0.0)
	return sqrt(dx * dx + dz * dz)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# Distancia al pasillo libre más cercano (senderos de entrada, camino al castillo y el propio castillo)
static func _corridor_d(ctx: Dictionary, x: float, z: float) -> float:
	var p := Vector2(x, z)
	var c: Vector2 = ctx.castle
	var d := maxf(p.distance_to(c) - CASTLE_R + 0.6, 0.0)
	for r in ctx.roads:
		d = minf(d, _seg_dist(p, r[0], r[1]))
	return d


static func _is_water(ctx: Dictionary, x: float, z: float) -> bool:
	return ctx.wext.has(_cell(ctx, x, z))


# Altura del terreno exterior (sin el cauce del agua)
static func _h(ctx: Dictionary, x: float, z: float) -> float:
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	if absf(x) < hx - 0.3 and absf(z) < hz - 0.3:
		return -0.45 # bajo el tablero (oculto por su base)
	var cfg: Dictionary = ctx.cfg
	var d := _board_d(ctx, x, z)
	var n: float = ctx.noise.get_noise_2d(x, z) * 0.5 + 0.5
	var hills: float = cfg.hills
	var rise: float = cfg.rise
	if ctx.sky:
		# Isla flotante: borde irregular a unas 3-4 casillas del tablero
		var edge := 3.2 + n * 1.6
		var cd0 := Vector2(x, z).distance_to(ctx.castle)
		if cd0 < 3.4:
			edge = maxf(edge, d + 1.0)
		if d > edge:
			return lerpf(GROUND_Y, -5.0, clampf((d - edge) / 1.2, 0.0, 1.0))
		return GROUND_Y + smoothstep(1.0, 3.0, d) * hills * n
	var h := GROUND_Y + smoothstep(1.2, 7.0, d) * hills * n * 1.6 + smoothstep(8.0, 16.0, d) * rise * (0.5 + 0.7 * n)
	var cd := _corridor_d(ctx, x, z)
	h = lerpf(GROUND_Y, h, smoothstep(0.7, 3.0, cd))
	var wd: int = ctx.wdist.get(_cell(ctx, x, z), 5)
	h = lerpf(GROUND_Y, h, smoothstep(0.5, 4.0, float(wd)))
	return h


# Comprueba que un objeto de radio r cabe en (x, z) sin invadir tablero, pasillos, agua ni edificios
static func _free(ctx: Dictionary, x: float, z: float, r: float, board_gap := 0.6, road_gap := 0.9) -> bool:
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	if absf(x) > hx + MARGIN or z > hz + MARGIN or z < -hz - MARGIN_TOP:
		return false
	if absf(x) < hx + board_gap + r * 0.5 and absf(z) < hz + board_gap + r * 0.5:
		return false
	if _corridor_d(ctx, x, z) < road_gap + r:
		return false
	for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if _is_water(ctx, x + o.x, z + o.y):
			return false
	if ctx.sky and _h(ctx, x, z) < GROUND_Y - 0.05:
		return false
	for b in ctx.big:
		var bp: Vector2 = b[0]
		var br: float = b[1]
		if bp.distance_to(Vector2(x, z)) < br + r:
			return false
	return true


# Registra una instancia del modelo `id` (se agrupan en MultiMesh al final)
static func _put(ctx: Dictionary, id: String, pos: Vector3, yaw := 0.0, s := 1.0, shadow := true) -> void:
	_put_xf(ctx, id, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), pos), shadow)


static func _put_xf(ctx: Dictionary, id: String, xf: Transform3D, shadow := true) -> void:
	# Las copias sin sombra van a un grupo aparte ("id@ns") para no gastar el pase de sombras
	var key := id if shadow else id + "@ns"
	var inst: Dictionary = ctx.inst
	if not inst.has(key):
		inst[key] = []
	inst[key].append(xf)
	if not shadow:
		ctx.noshadow[key] = true


# ================================================================== Charcas extra fuera del tablero
static func _extra_water(ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	var n: int = cfg.ponds
	if n <= 0:
		return
	var rng: RandomNumberGenerator = ctx.rng
	var wext: Dictionary = ctx.wext
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var placed := 0
	for t in 60:
		if placed >= n:
			break
		var x := rng.randf_range(-hx - 11.0, hx + 11.0)
		var z := rng.randf_range(-hz - 10.0, hz + 6.0)
		if _board_d(ctx, x, z) < 2.0 or _corridor_d(ctx, x, z) < 3.0:
			continue
		var rx := rng.randf_range(1.0, 2.2)
		var rz := rng.randf_range(0.8, 1.8)
		var ok := true
		var cells: Array = []
		for cx in range(floori(x - rx) - 1, floori(x + rx) + 2):
			for cz in range(floori(z - rz) - 1, floori(z + rz) + 2):
				var p := Vector2(cx + 0.5, cz + 0.5)
				var dx := (p.x - x) / rx
				var dz := (p.y - z) / rz
				if dx * dx + dz * dz <= 1.0:
					if _board_d(ctx, p.x, p.y) < 1.5 or _corridor_d(ctx, p.x, p.y) < 2.0:
						ok = false
					cells.append(_cell(ctx, p.x, p.y))
		if ok and cells.size() >= 2:
			for c in cells:
				wext[c] = true
			placed += 1
			if ctx.water_kind == "oasis":
				ctx["oasis"] = Vector2(x, z)
	# recalcula la distancia al agua con las charcas nuevas
	var wdist: Dictionary = ctx.wdist
	for c in wext.keys():
		var cc: Vector2i = c
		for dx in range(-3, 4):
			for dz in range(-3, 4):
				var nb := cc + Vector2i(dx, dz)
				var dd := maxi(absi(dx), absi(dz))
				if wdist.get(nb, 5) > dd:
					wdist[nb] = dd


# ================================================================== Terreno exterior
static func _build_terrain(ctx: Dictionary) -> void:
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var nx := int((hx + MARGIN) * 2.0 / STEP) + 1
	var nz := int((hz * 2.0 + MARGIN + MARGIN_TOP) / STEP) + 1
	var x0 := -hx - MARGIN
	var z0 := -hz - MARGIN_TOP
	var cfg: Dictionary = ctx.cfg
	var pal: Dictionary = ctx.pal
	var ground: Color = ctx.ground
	var path_col: Color = ctx.path_col
	var high: Color = cfg.high
	var wext: Dictionary = ctx.wext
	var kind: String = ctx.water_kind
	var bank := ground.darkened(0.25).lerp(Color(0.45, 0.38, 0.26), 0.4)
	match kind:
		"oasis": bank = Color(0.86, 0.76, 0.52)
		"lava": bank = Color(0.12, 0.08, 0.07)
		"ice": bank = Color(0.9, 0.95, 1.0)
		"void": bank = Color(0.12, 0.08, 0.16)
		"swamp": bank = Color(0.25, 0.24, 0.16)
	var noise2: FastNoiseLite = ctx.noise2
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	var colors := PackedColorArray()
	colors.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := x0 + i * STEP
			var z := z0 + j * STEP
			var h := _h(ctx, x, z)
			# Cauce: fracción de agua en las 4 casillas alrededor del vértice
			var wf := 0.0
			for o in [Vector2(-0.25, -0.25), Vector2(0.25, -0.25), Vector2(-0.25, 0.25), Vector2(0.25, 0.25)]:
				if wext.has(_cell(ctx, x + o.x, z + o.y)):
					wf += 0.25
			var outside: bool = _board_d(ctx, x, z) > 0.35 and not ctx.sky
			var jit := fposmod(sin(x * 12.9898 + z * 78.233) * 43758.5453, 1.0)
			var lip := WATER_OUT + 0.04 + jit * 0.08
			if wf > 0.0:
				var bed := -0.6 if not ctx.sky else -1.6
				if outside and wf < 1.0:
					# Orilla irregular: unos vértices del borde quedan sobre el agua y otros debajo
					h = lerpf(lip, bed, clampf(wf + (jit - 0.5) * 0.9, 0.0, 1.0))
				else:
					h = minf(h, lerpf(-0.18, bed, wf))
			elif outside and int(ctx.wdist.get(_cell(ctx, x, z), 5)) <= 1 and h < lip and _corridor_d(ctx, x, z) > 0.8:
				h = lip # ribazo: la orilla queda un poco por encima del agua
			heights[j * nx + i] = h
			# Color
			var n2 := noise2.get_noise_2d(x, z) * 0.5 + 0.5
			var col := ground.darkened(0.12).lerp(ground.lightened(0.06), n2)
			col = col.lerp(high, smoothstep(0.5, 2.6, h) * 0.85)
			if cfg.high_snow:
				col = col.lerp(Color(0.97, 0.98, 1.0), smoothstep(1.2, 2.8, h))
			var cd := _corridor_d(ctx, x, z)
			var cx := Vector2(x, z).distance_to(ctx.castle)
			if cd < 0.7 and cx > CASTLE_R - 0.4:
				col = col.lerp(path_col.darkened(0.12), smoothstep(0.7, 0.35, cd))
			if wf > 0.0 or (int(ctx.wdist.get(_cell(ctx, x, z), 5)) <= 0):
				col = bank
			elif h < GROUND_Y + 0.02 and int(ctx.wdist.get(_cell(ctx, x, z), 5)) == 1:
				col = col.lerp(bank, 0.35)
			if ctx.sky and h < GROUND_Y - 0.1:
				col = SM.palette("sky_islands").rock.darkened(clampf(-h * 0.1, 0.0, 0.5))
			colors[j * nx + i] = col
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	for j in nz:
		for i in nx:
			var k := j * nx + i
			var h := heights[k]
			verts[k] = Vector3(x0 + i * STEP, h, z0 + j * STEP)
			var hl := heights[j * nx + maxi(i - 1, 0)]
			var hr := heights[j * nx + mini(i + 1, nx - 1)]
			var hu := heights[maxi(j - 1, 0) * nx + i]
			var hd := heights[mini(j + 1, nz - 1) * nx + i]
			norms[k] = Vector3(hl - hr, 2.0 * STEP, hu - hd).normalized()
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			# Saltamos los cuadros completamente bajo el tablero
			if heights[a] < -0.44 and heights[a + 1] < -0.44 and heights[a + nx] < -0.44 and heights[a + nx + 1] < -0.44:
				continue
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0 # terreno de papel: las facetas las da la malla (caras planas)
	m.metallic_specular = 0.1
	var mi := MeshInstance3D.new()
	mi.name = "Terreno"
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ctx.root.add_child(mi)
	ctx["heights"] = heights
	if ctx.sky:
		# Mar de nubes bajo la isla
		var sea := MeshInstance3D.new()
		sea.name = "MarDeNubes"
		var pm := PlaneMesh.new()
		pm.size = Vector2((hx + MARGIN) * 2.0 + 40.0, (hz + MARGIN) * 2.0 + 40.0)
		pm.subdivide_width = 24
		pm.subdivide_depth = 24
		sea.mesh = pm
		sea.material_override = _water_mat("sky", Vector2(0.2, 0.05))
		sea.position = Vector3(0, -2.6, 0)
		sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ctx.root.add_child(sea)


# ================================================================== Agua
static func _shader(path: String) -> Shader:
	if not _shaders.has(path):
		_shaders[path] = load(path)
	return _shaders[path]


static func _water_mat(kind: String, flow: Vector2, pal: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var glow: Color = pal.get("glow", Color(1.0, 0.42, 0.06))
	match kind:
		"lava":
			m.shader = _shader("res://shaders/lava.gdshader")
			m.set_shader_parameter("flow", flow * 0.35)
			m.set_shader_parameter("hot_color", glow)
			m.set_shader_parameter("core_color", glow.lerp(Color(1, 0.95, 0.6), 0.6))
		"ice":
			m.shader = _shader("res://shaders/ice.gdshader")
		"void":
			m.shader = _shader("res://shaders/void.gdshader")
			m.set_shader_parameter("glow_color", glow)
		"sky":
			m.shader = _shader("res://shaders/sky.gdshader")
		_:
			m.shader = _shader("res://shaders/water.gdshader")
			m.set_shader_parameter("flow", flow)
			if kind == "swamp":
				m.set_shader_parameter("deep_color", Color(0.1, 0.15, 0.09))
				m.set_shader_parameter("shallow_color", Color(0.24, 0.3, 0.14))
				m.set_shader_parameter("foam_color", Color(0.45, 0.5, 0.32))
				m.set_shader_parameter("foam_amount", 0.35)
				m.set_shader_parameter("sparkle", 0.25)
				m.set_shader_parameter("weed_amount", 1.0)
				m.set_shader_parameter("wave_height", 0.004)
				m.set_shader_parameter("flow", flow * 0.2)
			elif kind == "oasis":
				m.set_shader_parameter("deep_color", Color(0.04, 0.42, 0.52))
				m.set_shader_parameter("shallow_color", Color(0.3, 0.78, 0.72))
				m.set_shader_parameter("foam_color", Color(0.95, 0.92, 0.8))
	return m


static func _build_water(ctx: Dictionary) -> void:
	var wext: Dictionary = ctx.wext
	if wext.is_empty():
		return
	var verts := PackedVector3Array()
	var cols_arr := PackedColorArray()
	var idx := PackedInt32Array()
	for c in wext.keys():
		var cc: Vector2i = c
		var base := verts.size()
		var o := _c2(ctx, cc) - Vector2(0.5, 0.5)
		var cell_out := _board_d(ctx, o.x + 0.5, o.y + 0.5) > 0.0
		for j in 3:
			for i in 3:
				var pc := Vector2(cc.x + i * 0.5, cc.y + j * 0.5) # punto en coordenadas de casilla
				var shore := 0.0
				for d in [Vector2(-0.01, -0.01), Vector2(0.01, -0.01), Vector2(-0.01, 0.01), Vector2(0.01, 0.01)]:
					var q: Vector2 = pc + d
					if not wext.has(Vector2i(floori(q.x), floori(q.y))):
						shore = 1.0
				# Los bordes del agua se estiran un poco bajo la orilla para no dejar huecos
				var reach: float = 0.3 if (cell_out and not ctx.sky) else 0.06
				var ext := Vector2((i - 1) * reach, (j - 1) * reach) * shore
				verts.append(Vector3(o.x + i * 0.5 + ext.x, WATER_OUT if (cell_out and not ctx.sky) else WATER_Y, o.y + j * 0.5 + ext.y))
				cols_arr.append(Color(shore, 0, 0))
		for j in 2:
			for i in 2:
				var a := base + j * 3 + i
				idx.append_array([a, a + 1, a + 3, a + 1, a + 4, a + 3])
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	norms.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols_arr
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var flow := Vector2(0.35, 0.0) if ctx.river else Vector2(0.06, 0.04)
	var mi := MeshInstance3D.new()
	mi.name = "Agua"
	mi.mesh = mesh
	mi.material_override = _water_mat(ctx.water_kind, flow, ctx.pal)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ctx.root.add_child(mi)
	# Orillas: piedras (y cañas fuera del tablero) en los bordes del agua
	var rng: RandomNumberGenerator = ctx.rng
	var path_cells: Dictionary = ctx.info.get("path_cells", {})
	var kind: String = ctx.water_kind
	var reeds := kind in ["water", "swamp", "oasis"]
	for c in wext.keys():
		var cc: Vector2i = c
		var center := _c2(ctx, cc)
		if absf(center.x) > ctx.hx + MARGIN - 1.0:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cc + d
			if wext.has(nb) or path_cells.has(nb):
				continue
			var dir := Vector2(d)
			var side := Vector2(-dir.y, dir.x)
			var inside := _board_d(ctx, center.x, center.y) <= 0.0
			var n := 1 if inside else 2
			for k in n:
				var p := center + dir * rng.randf_range(0.38, 0.46) + side * rng.randf_range(-0.38, 0.38)
				if kind == "sky":
					continue
				var ps := rng.randf_range(0.7, 1.3)
				_put_xf(ctx, "pebble", Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(ps * rng.randf_range(0.8, 1.4), ps * rng.randf_range(0.7, 1.3), ps)), Vector3(p.x, (WATER_Y if inside else WATER_OUT) - 0.02, p.y)), false)
			if reeds and not inside and rng.randf() < 0.45:
				var p2 := center + dir * 0.35 + side * rng.randf_range(-0.3, 0.3)
				if _corridor_d(ctx, p2.x, p2.y) > 0.8:
					_put(ctx, "reeds", Vector3(p2.x, WATER_OUT, p2.y), rng.randf() * TAU, rng.randf_range(0.8, 1.2), false)
	# Palmeras alrededor del oasis
	if ctx.has("oasis"):
		var oc: Vector2 = ctx.oasis
		for k in 9:
			var a := TAU * k / 9.0 + rng.randf() * 0.3
			var p := oc + Vector2(cos(a), sin(a)) * rng.randf_range(2.2, 3.0)
			if _free(ctx, p.x, p.y, 0.3):
				_put(ctx, "palm", Vector3(p.x, _h(ctx, p.x, p.y), p.y), rng.randf() * TAU, rng.randf_range(1.1, 1.6))


# ================================================================== Puentes
static func _build_bridges(ctx: Dictionary) -> void:
	var bridges: Dictionary = ctx.info.get("bridges", {})
	var kind: String = ctx.water_kind
	var id := "bridge_stone" if kind in ["lava", "ice", "void"] else "bridge_wood"
	for c in bridges.keys():
		var cc: Vector2i = c
		var dir: Vector2i = bridges[c]
		var p := _c2(ctx, cc)
		var yaw := PI * 0.5 if dir.x != 0 else 0.0
		_put(ctx, id, Vector3(p.x, -0.03 if id == "bridge_wood" else 0.0, p.y), yaw, 1.0, true)


# ================================================================== Obstáculos del tablero
static func _build_obstacles(ctx: Dictionary) -> void:
	var obstacles: Dictionary = ctx.info.get("obstacles", {})
	if obstacles.is_empty():
		return
	var cfg: Dictionary = ctx.cfg
	var obs: Dictionary = cfg.obs
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("obstaculos:%s" % ctx.theme)
	var pads: Array = []
	for c in obstacles.keys():
		var cc: Vector2i = c
		var kind: String = obstacles[c]
		var id: String = obs.get(kind, "boulder")
		var p := _c2(ctx, cc)
		var yaw := (rng.randi() % 4) * PI * 0.5 + rng.randf_range(-0.25, 0.25)
		var s := rng.randf_range(1.12, 1.25)
		if kind == "rock" or kind == "tree":
			# Árboles y rocas se pueden demoler (por oro): van sueltos, con nombre, para poder quitarlos
			var holder := Node3D.new()
			holder.name = "Obstacle_%d_%d" % [cc.x, cc.y]
			holder.position = Vector3(p.x, 0.0, p.y)
			ctx.root.add_child(holder)
			var mi := MeshInstance3D.new()
			mi.mesh = SM.get_mesh(ctx.theme, id, ctx.pal)
			mi.position.y = 0.02
			mi.rotation.y = yaw
			mi.scale = Vector3.ONE * s
			holder.add_child(mi)
			var pad := M.add(holder, M.box_mesh(Vector3(0.98, 0.14, 0.98)), M.mat((ctx.ground as Color).darkened(0.28)), Vector3(0, -0.05, 0))
			pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		pads.append(Transform3D(Basis(), Vector3(p.x, -0.05, p.y)))
		_put(ctx, id, Vector3(p.x, 0.02, p.y), yaw, s)
	# Losa de tierra elevada bajo cada obstáculo (deja claro que la casilla está ocupada)
	var ground: Color = ctx.ground
	var pad_mesh := M.box_mesh(Vector3(0.98, 0.14, 0.98))
	var mmi := M.multimesh(ctx.root, pad_mesh, M.mat(ground.darkened(0.28)), pads)
	mmi.name = "LosasObstaculos"


# ================================================================== Paisaje exterior
static func _build_landscape(ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	match String(cfg.settle):
		"village", "camp", "ruins":
			_build_settlement(ctx)
	if cfg.fields:
		_build_fields(ctx)
	_build_mountains(ctx)
	_build_landmark(ctx)
	_build_props(ctx)
	_build_forest(ctx)
	_build_grass(ctx)


static func _build_settlement(ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	var rng: RandomNumberGenerator = ctx.rng
	var castle: Vector2 = ctx.castle
	var houses: Array = cfg.houses
	var n: int = cfg.n_houses
	var smoke := PackedVector3Array()
	# Molino a un lado del castillo, sobre un pequeño alto
	if cfg.windmill:
		for t in 40:
			var a := rng.randf_range(-PI, PI)
			var p := castle + Vector2(cos(a), sin(a) * 0.8) * rng.randf_range(4.5, 7.5)
			if _free(ctx, p.x, p.y, 0.9):
				_add_windmill(ctx, p, rng.randf() * TAU)
				break
	if cfg.chapel:
		for t in 40:
			var a := rng.randf_range(-PI, PI)
			var p := castle + Vector2(cos(a), sin(a)) * rng.randf_range(3.6, 6.0)
			if _free(ctx, p.x, p.y, 0.8):
				var yaw := atan2(castle.x - p.x, castle.y - p.y)
				_put(ctx, "chapel", Vector3(p.x, _h(ctx, p.x, p.y), p.y), yaw, 1.4)
				ctx.big.append([p, 0.8])
				break
	# Dos barrios a ambos lados del castillo (algo por debajo), casas apiñadas mirando a la plaza
	var hoods: Array = [castle + Vector2(-4.2, 1.2), castle + Vector2(4.2, 1.2), castle + Vector2(0, 4.6)]
	var placed := 0
	for t in 400:
		if placed >= n:
			break
		var hc: Vector2 = hoods[t % hoods.size()]
		var p := hc + Vector2(rng.randf_range(-2.6, 2.6), rng.randf_range(-2.0, 2.0))
		var s := rng.randf_range(1.15, 1.45)
		if not _free(ctx, p.x, p.y, 0.55 * s, 0.6, 0.75):
			continue
		var id: String = houses[rng.randi() % houses.size()]
		var yaw := atan2(hc.x - p.x, hc.y - p.y)
		yaw = snappedf(yaw, PI * 0.25) + rng.randf_range(-0.15, 0.15)
		var y := _h(ctx, p.x, p.y)
		_put(ctx, id, Vector3(p.x, y, p.y), yaw, s)
		ctx.big.append([p, 0.55 * s])
		placed += 1
		if cfg.smoke and smoke.size() < 6 and id.begins_with("house"):
			var local := Vector3(0.25, 1.0, -0.1)
			if id == "house_adobe":
				local = Vector3(0.1, 0.95, -0.05)
			smoke.append(Vector3(p.x, y, p.y) + Basis(Vector3.UP, yaw) * (local * s))
	ctx["smoke_pts"] = smoke


static func _add_windmill(ctx: Dictionary, p: Vector2, yaw: float) -> void:
	var y := _h(ctx, p.x, p.y)
	var s := 1.5
	_put(ctx, "windmill_body", Vector3(p.x, y, p.y), yaw, s)
	ctx.big.append([p, 0.9 * s])
	var spin := Life.Spinner.new()
	spin.name = "AspasMolino"
	spin.axis = Vector3.BACK
	spin.speed = 0.9
	spin.position = Vector3(p.x, y, p.y) + Basis(Vector3.UP, yaw) * (Vector3(0, 1.35, 0.6) * s)
	spin.rotation.y = yaw
	spin.scale = Vector3.ONE * s
	ctx.root.add_child(spin)
	var mi := MeshInstance3D.new()
	mi.mesh = SM.get_mesh(ctx.theme, "windmill_blades", ctx.pal)
	spin.add_child(mi)


static func _build_fields(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var root: Node3D = ctx.bake_root
	var crops := [Color(0.86, 0.72, 0.3), Color(0.45, 0.62, 0.25), Color(0.5, 0.36, 0.22), Color(0.72, 0.78, 0.35), Color(0.62, 0.5, 0.75)]
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var made := 0
	for t in 200:
		if made >= 7:
			break
		var x := rng.randf_range(-hx - 10.0, hx + 10.0)
		var z := rng.randf_range(-hz - 6.0, hz + 9.0)
		var w := rng.randf_range(2.0, 3.4)
		var d := rng.randf_range(1.5, 2.4)
		var r := maxf(w, d) * 0.6
		if not _free(ctx, x, z, r, 1.2, 1.0):
			continue
		var hs: Array = []
		for o in [Vector2(-w, -d), Vector2(w, -d), Vector2(-w, d), Vector2(w, d), Vector2.ZERO]:
			hs.append(_h(ctx, x + o.x * 0.5, z + o.y * 0.5))
		var lo: float = hs.min()
		var hi: float = hs.max()
		if hi - lo > 0.35:
			continue
		var y := hi + 0.01
		var col: Color = crops[rng.randi() % crops.size()]
		var yaw := rng.randf_range(-0.3, 0.3)
		var f := Node3D.new()
		f.position = Vector3(x, y, z)
		f.rotation.y = yaw
		root.add_child(f)
		SM.bx(f, Vector3(w, 0.06 + (hi - lo), d), SM.flat(col.darkened(0.2)), Vector3(0, -(hi - lo) * 0.5, 0))
		var rows := int(d / 0.25)
		for k in rows:
			SM.bx(f, Vector3(w - 0.1, 0.06, 0.12), SM.flat(col), Vector3(0, 0.05, -d * 0.5 + 0.15 + k * (d - 0.3) / maxf(rows - 1, 1)))
		# Valla alrededor (con un hueco de entrada)
		var bas := Basis(Vector3.UP, yaw)
		var gap := rng.randi() % 4
		for side in 4:
			var along := w if side % 2 == 0 else d
			var segs := int(round(along))
			for k in segs:
				if side == gap and k == segs / 2:
					continue
				var tpos := -along * 0.5 + (k + 0.5) * along / segs
				var lp := Vector3(tpos, 0, -d * 0.5 - 0.1) if side == 0 else (Vector3(tpos, 0, d * 0.5 + 0.1) if side == 2 else Vector3(-w * 0.5 - 0.1 if side == 1 else w * 0.5 + 0.1, 0, tpos))
				var wp := Vector3(x, 0, z) + bas * lp
				var fy := yaw + (0.0 if side % 2 == 0 else PI * 0.5)
				var xf := Transform3D(Basis(Vector3.UP, fy).scaled(Vector3(along / segs, 1, 1)), Vector3(wp.x, _h(ctx, wp.x, wp.z), wp.z))
				_put_xf(ctx, String(ctx.cfg.fence), xf)
		ctx.big.append([Vector2(x, z), r])
		# Almiares junto al campo
		if rng.randf() < 0.6:
			var hp := Vector3(x, 0, z) + bas * Vector3(w * 0.5 + 0.5, 0, rng.randf_range(-0.5, 0.5))
			if _free(ctx, hp.x, hp.z, 0.3):
				_put(ctx, "haystack", Vector3(hp.x, _h(ctx, hp.x, hp.z), hp.z), rng.randf() * TAU, 0.8)
		made += 1


static func _build_mountains(ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	var id: String = cfg.mount
	var rng: RandomNumberGenerator = ctx.rng
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	if id != "":
		var n: int = cfg.mount_n
		var tall_k := 1.3 if cfg.high_snow else 1.0
		# Cordillera del fondo: una fila densa que tapa el horizonte
		var back := int(n * 0.6)
		for k in back:
			var x := lerpf(-hx - 30.0, hx + 30.0, (k + rng.randf_range(0.0, 0.8)) / back)
			var z := -hz - rng.randf_range(20.0, 27.0)
			var rad := rng.randf_range(4.0, 6.5)
			var tall := rng.randf_range(6.0, 10.0) * tall_k
			if _corridor_d(ctx, x, z) < rad * 0.5:
				x += rad * (1.0 if x > 0 else -1.0)
			_put_xf(ctx, id, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rad, tall, rad)), Vector3(x, _h(ctx, x, z) - 0.4, z)), false)
		# Montañas sueltas a los lados y arriba
		for k in n - back:
			var t := rng.randf()
			var side := rng.randi() % 4
			var dist := rng.randf_range(11.0, 16.0)
			var x := 0.0
			var z := 0.0
			match side:
				0, 1:
					x = lerpf(-hx - dist, hx + dist, t)
					z = -hz - dist
				2:
					x = -hx - dist
					z = lerpf(-hz - 8.0, hz + 2.0, t)
				3:
					x = hx + dist
					z = lerpf(-hz - 8.0, hz + 2.0, t)
			var rad := rng.randf_range(2.4, 4.4)
			var tall := rng.randf_range(3.0, 6.5) * tall_k
			if _corridor_d(ctx, x, z) < rad * 0.7 + 0.5:
				continue
			if _is_water(ctx, x, z):
				continue
			var y := _h(ctx, x, z) - 0.3
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rad, tall, rad)), Vector3(x, y, z))
			_put_xf(ctx, id, xf, false)
	_build_backdrop(ctx)
	# Dunas del desierto
	if ctx.theme == "ash_desert":
		for k in 14:
			var x := rng.randf_range(-hx - 15.0, hx + 15.0)
			var z := rng.randf_range(-hz - 15.0, hz + 10.0)
			if _board_d(ctx, x, z) < 4.0 or _corridor_d(ctx, x, z) < 3.0 or _is_water(ctx, x, z):
				continue
			var s := rng.randf_range(1.2, 2.6)
			_put_xf(ctx, "dune", Transform3D(Basis(Vector3.UP, rng.randf_range(-0.4, 0.4)).scaled(Vector3(s, s, s)), Vector3(x, _h(ctx, x, z) - 0.05, z)), false)


## Colores del cielo [horizonte, cénit, vetas] según la temática
static func _sky_colors(theme: String) -> Array:
	match theme:
		"ash_desert", "dragon_canyon":
			return [Color(0.96, 0.8, 0.58), Color(0.55, 0.62, 0.8), Color(1.0, 0.9, 0.75)]
		"volcano", "hellfire":
			return [Color(0.75, 0.28, 0.08), Color(0.14, 0.04, 0.04), Color(0.35, 0.12, 0.08)]
		"abyss_gate":
			return [Color(0.6, 0.15, 0.25), Color(0.1, 0.02, 0.06), Color(0.3, 0.06, 0.12)]
		"void_abyss":
			return [Color(0.4, 0.2, 0.6), Color(0.05, 0.02, 0.1), Color(0.7, 0.45, 0.95)]
		"chaos_citadel":
			return [Color(0.45, 0.12, 0.25), Color(0.04, 0.02, 0.05), Color(0.6, 0.2, 0.35)]
		"graveyard", "swamp", "lich_citadel", "fallen_fortress":
			return [Color(0.55, 0.6, 0.6), Color(0.16, 0.18, 0.22), Color(0.7, 0.72, 0.72)]
		"ice_throne":
			return [Color(0.6, 0.72, 0.92), Color(0.1, 0.14, 0.36), Color(0.55, 0.95, 0.9)]
		"frost_mountains", "glacier":
			return [Color(0.9, 0.95, 1.0), Color(0.5, 0.66, 0.88), Color(1, 1, 1)]
		"crystal_forest":
			return [Color(0.7, 0.68, 0.95), Color(0.2, 0.18, 0.42), Color(0.85, 0.8, 1.0)]
		"elven_ruins":
			return [Color(0.98, 0.9, 0.72), Color(0.45, 0.66, 0.85), Color(1, 1, 1)]
	return [Color(0.88, 0.93, 0.97), Color(0.42, 0.63, 0.9), Color(1, 1, 1)]


static func _build_backdrop(ctx: Dictionary) -> void:
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var cols_sky := _sky_colors(ctx.theme)
	var mi := MeshInstance3D.new()
	mi.name = "Cielo"
	var q := QuadMesh.new()
	q.size = Vector2((hx + MARGIN) * 2.0 + 90.0, 34.0)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _shader("res://shaders/sky_backdrop.gdshader")
	m.set_shader_parameter("horizon_color", cols_sky[0])
	m.set_shader_parameter("top_color", cols_sky[1])
	m.set_shader_parameter("streak_color", cols_sky[2])
	mi.material_override = m
	mi.position = Vector3(0, 13.0, -hz - MARGIN_TOP - 4.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ctx.root.add_child(mi)


static func _build_landmark(ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	var lm: String = cfg.landmark
	if lm == "":
		return
	var rng: RandomNumberGenerator = ctx.rng
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var spots: Array = []
	for t in 60:
		var x := rng.randf_range(-hx - 6.0, hx + 6.0)
		var z := rng.randf_range(-hz - 11.0, -hz - 5.0)
		if _corridor_d(ctx, x, z) > 4.0 and not _is_water(ctx, x, z):
			spots.append(Vector2(x, z))
		if spots.size() >= 3:
			break
	if spots.is_empty():
		return
	var p: Vector2 = spots[0]
	match lm:
		"volcano_cone":
			var s := Vector3(6.0, 5.5, 6.0)
			var y := _h(ctx, p.x, p.y) - 0.3
			_put_xf(ctx, "volcano_cone", Transform3D(Basis.from_scale(s), Vector3(p.x, y, p.y)), false)
			ctx["volcano_top"] = Vector3(p.x, y + s.y, p.y)
		"giant_gate":
			var y := _h(ctx, p.x, p.y)
			_put_xf(ctx, "giant_gate", Transform3D(Basis.from_scale(Vector3.ONE * 1.6), Vector3(p.x, y, p.y)), true)
			ctx.big.append([p, 3.0])
		"ribcage":
			for q in spots:
				var qq: Vector2 = q
				_put(ctx, "ribcage", Vector3(qq.x, _h(ctx, qq.x, qq.y) - 0.1, qq.y), rng.randf() * TAU, rng.randf_range(1.0, 1.4))
				ctx.big.append([qq, 2.0])
		"dark_tower":
			for q in spots:
				var qq: Vector2 = q
				var s := rng.randf_range(1.6, 2.4)
				_put_xf(ctx, "dark_tower", Transform3D(Basis.from_scale(Vector3(s, s * 1.2, s)), Vector3(qq.x, _h(ctx, qq.x, qq.y), qq.y)), true)
				ctx.big.append([qq, 0.8 * s])


static func _build_props(ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	var rng: RandomNumberGenerator = ctx.rng
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var props: Array = cfg.props
	var big_ids := ["crypt", "stilt_hut", "watchtower_ruin", "dark_obelisk", "demon_altar", "gazebo", "elven_arch", "standing_stones", "broken_wall", "pillar_ruin_white", "dragon_bones", "well", "tent", "cage"]
	for e in props:
		var id: String = e[0]
		var count: int = e[1]
		var dmin: float = e[2]
		var dmax: float = e[3]
		var placed := 0
		var big := id in big_ids
		var r := 0.45 if big else 0.2
		# Las tumbas se agrupan en cementerios
		var cluster := id.begins_with("grave")
		var centers: Array = []
		if cluster:
			for k in 4:
				centers.append(Vector2(rng.randf_range(-hx - 6.0, hx + 6.0), rng.randf_range(-hz - 5.0, hz + 5.0)))
		for t in count * 8:
			if placed >= count:
				break
			var x := 0.0
			var z := 0.0
			if cluster:
				var cc: Vector2 = centers[rng.randi() % centers.size()]
				x = cc.x + rng.randf_range(-2.5, 2.5)
				z = cc.y + rng.randf_range(-2.0, 2.0)
				x = roundf(x * 1.4) / 1.4
				z = roundf(z * 1.2) / 1.2
			else:
				x = rng.randf_range(-hx - dmax, hx + dmax)
				z = rng.randf_range(-hz - dmax, hz + dmax)
			var d := _board_d(ctx, x, z)
			if d < dmin or d > dmax:
				continue
			if not _free(ctx, x, z, r, dmin):
				continue
			var yaw := rng.randf() * TAU if not cluster else rng.randf_range(-0.15, 0.15)
			var s := rng.randf_range(0.85, 1.25) if not big else rng.randf_range(1.0, 1.3)
			if id == "dune":
				s = rng.randf_range(1.5, 3.0)
			_put(ctx, id, Vector3(x, _h(ctx, x, z) - 0.01, z), yaw, s, not (id in SMALL_IDS))
			if big:
				ctx.big.append([Vector2(x, z), r * s])
			placed += 1


static func _build_forest(ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	var trees: Array = cfg.trees
	if trees.is_empty():
		return
	var rng: RandomNumberGenerator = ctx.rng
	var noise2: FastNoiseLite = ctx.noise2
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var forest: float = cfg.forest
	var max_trees := 520
	var spacing := 0.85
	# Primero se reúnen los candidatos y luego se quedan los más cercanos al tablero (lo que más se ve)
	var cands: Array = []
	var z := -hz - 20.0
	while z < hz + MARGIN - 0.5:
		var x := -hx - MARGIN + 0.5
		while x < hx + MARGIN - 0.5:
			var px := x + rng.randf_range(-0.35, 0.35)
			var pz := z + rng.randf_range(-0.35, 0.35)
			x += spacing
			var d := _board_d(ctx, px, pz)
			if d < 0.7:
				continue
			var mask := noise2.get_noise_2d(px * 0.6, pz * 0.6) * 0.5 + 0.5
			var p := smoothstep(1.0 - forest, 1.0 - forest + 0.25, mask) * 0.85
			p = maxf(p, forest * 0.06)
			if rng.randf() > p:
				continue
			if not _free(ctx, px, pz, 0.25, 0.7, 0.8):
				continue
			cands.append([d + rng.randf() * 3.0, px, pz, d])
		z += spacing
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in mini(cands.size(), max_trees):
		var c: Array = cands[k]
		var px: float = c[1]
		var pz: float = c[2]
		var d: float = c[3]
		var id: String = trees[rng.randi() % trees.size()]
		var s := rng.randf_range(1.2, 1.6) * (1.0 + smoothstep(4.0, 14.0, d) * 0.4)
		_put(ctx, id, Vector3(px, _h(ctx, px, pz) - 0.02, pz), rng.randf() * TAU, s, d < 4.5)


static func _build_grass(ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	var n: int = cfg.grass
	var rng: RandomNumberGenerator = ctx.rng
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var placed := 0
	for t in n * 4:
		if placed >= n:
			break
		var x := rng.randf_range(-hx - 9.0, hx + 9.0)
		var z := rng.randf_range(-hz - 8.0, hz + 8.0)
		if not _free(ctx, x, z, 0.05, 0.35, 0.55):
			continue
		_put(ctx, "grass", Vector3(x, _h(ctx, x, z) - 0.01, z), rng.randf() * TAU, rng.randf_range(0.8, 1.5), false)
		placed += 1


# ================================================================== Vida
static func _build_life(ctx: Dictionary) -> void:
	var cfg: Dictionary = ctx.cfg
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	if cfg.birds != "":
		_build_flock(ctx, String(cfg.birds))
	for p in cfg.parts:
		_build_particles(ctx, String(p))
	var smoke: PackedVector3Array = ctx.smoke_pts
	if smoke.size() > 0:
		_smoke(ctx, smoke, Color(0.85, 0.85, 0.88, 0.55), 0.35)
	if ctx.has("volcano_top"):
		var vt: Vector3 = ctx.volcano_top
		_smoke(ctx, PackedVector3Array([vt]), Color(0.3, 0.27, 0.27, 0.7), 1.6)
	var mist: Color = cfg.mist
	if mist.a > 0.0:
		var mi := MeshInstance3D.new()
		mi.name = "Bruma"
		var pm := PlaneMesh.new()
		pm.size = Vector2((hx + MARGIN) * 2.0, (hz + MARGIN) * 2.0)
		mi.mesh = pm
		var m := ShaderMaterial.new()
		m.shader = _shader("res://shaders/mist.gdshader")
		m.set_shader_parameter("mist_color", Color(mist.r, mist.g, mist.b))
		m.set_shader_parameter("density", mist.a)
		m.set_shader_parameter("board_half", Vector2(hx, hz))
		mi.material_override = m
		mi.position = Vector3(0, 0.35, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ctx.root.add_child(mi)
	if cfg.clouds != "":
		_build_clouds(ctx)
	if cfg.floaters != "":
		_build_floaters(ctx, String(cfg.floaters))


static func _bird_mesh() -> ArrayMesh:
	# Silueta en V: cuerpo + dos alas (el aleteo lo hace el shader según |x|)
	var v := PackedVector3Array([
		Vector3(0, 0, -0.12), Vector3(0.03, 0, 0.08), Vector3(-0.03, 0, 0.08),
		Vector3(0.02, 0, -0.04), Vector3(0.22, 0.0, 0.02), Vector3(0.02, 0, 0.05),
		Vector3(-0.02, 0, -0.04), Vector3(-0.02, 0, 0.05), Vector3(-0.22, 0.0, 0.02),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	var nn := PackedVector3Array()
	nn.resize(v.size())
	nn.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = nn
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _build_flock(ctx: Dictionary, kind: String) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var col := Color(0.15, 0.14, 0.16)
	var flap := 9.0
	var n := 10
	var size := 1.0
	var height := 3.5
	var jitter := 0.2
	match kind:
		"birds":
			col = Color(0.95, 0.95, 0.95)
		"crows":
			col = Color(0.06, 0.06, 0.08); flap = 6.0; size = 1.3
		"bats":
			col = Color(0.12, 0.08, 0.14); flap = 16.0; n = 14; jitter = 0.6; height = 2.5
		"vultures":
			col = Color(0.25, 0.2, 0.16); flap = 2.5; n = 5; size = 1.8; height = 5.0
		"dragons":
			col = Color(0.35, 0.1, 0.08); flap = 2.0; n = 3; size = 6.0; height = 6.5
	var birds: Array = []
	var groups := 2 if n > 6 else 1
	for g in groups:
		# Cada grupo gira alrededor de un centro fuera del tablero (arriba o a un lado)
		var center := Vector3(rng.randf_range(-hx, hx), height + rng.randf_range(-0.5, 1.0), -hz - rng.randf_range(2.0, 7.0))
		if g == 1:
			center = Vector3((hx + rng.randf_range(2.0, 5.0)) * (1.0 if rng.randf() < 0.5 else -1.0), height, rng.randf_range(-hz, hz * 0.5))
		var w := rng.randf_range(0.35, 0.6) * (1.0 if rng.randf() < 0.5 else -1.0)
		if kind == "dragons":
			w *= 0.4
		for k in n / groups:
			birds.append([center + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.8, 0.8)),
				rng.randf_range(2.0, 4.0) * (1.6 if kind == "dragons" else 1.0), w * rng.randf_range(0.85, 1.15),
				rng.randf() * TAU, rng.randf_range(0.6, 1.0), size * rng.randf_range(0.8, 1.2), jitter])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _bird_mesh()
	mm.instance_count = birds.size()
	var flock := Life.Flock.new()
	flock.name = "Bandada"
	flock.multimesh = mm
	flock.birds = birds
	var m := ShaderMaterial.new()
	m.shader = _shader("res://shaders/bird.gdshader")
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("flap_speed", flap)
	flock.material_override = m
	flock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ctx.root.add_child(flock)
	flock._process(0.0)


static func _soft_tex() -> Texture2D:
	if not _shaders.has("soft_tex"):
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 32
		t.height = 32
		_shaders["soft_tex"] = t
	return _shaders["soft_tex"]


static func _particle_mat(emissive: bool) -> StandardMaterial3D:
	var key := "pmat%s" % emissive
	if not _shaders.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = _soft_tex()
		if emissive:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_shaders[key] = m
	return _shaders[key]


static func _fade_ramp(col: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	g.add_point(0.2, col)
	g.add_point(0.75, col)
	return g


static func _new_particles(ctx: Dictionary, name: String, amount: int, life: float, size: float, col: Color, emissive: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = name
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _particle_mat(emissive)
	p.mesh = q
	p.color_ramp = _fade_ramp(col)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ctx.root.add_child(p)
	return p


static func _build_particles(ctx: Dictionary, kind: String) -> void:
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var area := Vector3(hx + 7.0, 0.5, hz + 8.0)
	var pal: Dictionary = ctx.pal
	match kind:
		"snow":
			var p := _new_particles(ctx, "Nieve", 260, 7.0, 0.16, Color(1, 1, 1, 0.95), false)
			p.position = Vector3(0, 7.0, -2.0)
			p.emission_box_extents = area
			p.direction = Vector3(0.3, -1, 0)
			p.spread = 15.0
			p.gravity = Vector3(0.15, -0.6, 0)
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 0.9
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.4
		"embers":
			var p := _new_particles(ctx, "Brasas", 140, 4.0, 0.15, Color(pal.glow.r, pal.glow.g * 0.9, pal.glow.b, 1.0), true)
			p.position = Vector3(0, 0.2, -1.0)
			p.emission_box_extents = Vector3(hx + 6.0, 0.2, hz + 7.0)
			p.direction = Vector3(0, 1, 0)
			p.spread = 25.0
			p.gravity = Vector3(0.2, 0.5, 0)
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.9
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.5
		"ash":
			var p := _new_particles(ctx, "Ceniza", 140, 7.0, 0.14, Color(0.5, 0.48, 0.46, 0.8), false)
			p.position = Vector3(0, 6.0, -2.0)
			p.emission_box_extents = area
			p.direction = Vector3(1, -0.4, 0)
			p.spread = 30.0
			p.gravity = Vector3(0.1, -0.25, 0)
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.6
		"fireflies", "sparkles", "wisps", "motes", "pollen":
			var col: Color = pal.glow
			var size := 0.16
			var amount := 70
			var up := 0.0
			if kind == "sparkles":
				col = Color(0.75, 0.85, 1.0)
				size = 0.12
				amount = 90
			elif kind == "wisps":
				size = 0.26
				amount = 40
				up = 0.15
			elif kind == "motes":
				size = 0.18
				amount = 90
				up = 0.35
			elif kind == "pollen":
				col = Color(1.0, 0.95, 0.7)
				size = 0.09
				amount = 60
			var p := _new_particles(ctx, "Luciernagas", amount, 5.0, size, Color(col.r, col.g, col.b, 0.9), true)
			p.position = Vector3(0, 0.6, -1.0)
			p.emission_box_extents = Vector3(hx + 6.0, 0.5, hz + 7.0)
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.gravity = Vector3(0, up, 0)
			p.initial_velocity_min = 0.05
			p.initial_velocity_max = 0.25
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.3
		"leaves":
			var col: Color = pal.leaf2
			var p := _new_particles(ctx, "Hojas", 60, 8.0, 0.15, Color(col.r, col.g * 0.9, col.b * 0.6, 0.95), false)
			p.position = Vector3(0, 4.0, -2.0)
			p.emission_box_extents = area
			p.direction = Vector3(1, -0.3, 0.2)
			p.spread = 40.0
			p.gravity = Vector3(0.15, -0.3, 0)
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.5
			p.angular_velocity_min = -180.0
			p.angular_velocity_max = 180.0
		"butterflies":
			var p := _new_particles(ctx, "Mariposas", 24, 6.0, 0.14, Color(1.0, 0.85, 0.35, 1.0), false)
			p.position = Vector3(0, 0.5, 0)
			p.emission_box_extents = Vector3(hx + 6.0, 0.3, hz + 7.0)
			p.direction = Vector3(1, 0.3, 0)
			p.spread = 180.0
			p.gravity = Vector3(0, 0.02, 0)
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.45
			p.hue_variation_min = -0.3
			p.hue_variation_max = 0.3
		"smoke":
			# Humo de las ruinas que aún arden
			var pts := PackedVector3Array()
			var rng: RandomNumberGenerator = ctx.rng
			for t in 30:
				var x := rng.randf_range(-hx - 8.0, hx + 8.0)
				var z := rng.randf_range(-hz - 8.0, hz + 6.0)
				if _board_d(ctx, x, z) > 1.0 and _corridor_d(ctx, x, z) > 1.0:
					pts.append(Vector3(x, _h(ctx, x, z) + 0.2, z))
				if pts.size() >= 5:
					break
			_smoke(ctx, pts, Color(0.2, 0.18, 0.18, 0.6), 0.8)


static func _smoke(ctx: Dictionary, pts: PackedVector3Array, col: Color, size: float) -> void:
	if pts.is_empty():
		return
	var p := _new_particles(ctx, "Humo", 12 * pts.size(), 4.0, size, col, false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	p.direction = Vector3(0.2, 1, 0)
	p.spread = 12.0
	p.gravity = Vector3(0.25, 0.15, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve


static func _build_clouds(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var items: Array = []
	for k in 9:
		var z := rng.randf_range(-hz - 18.0, -hz - 2.0)
		var x := rng.randf_range(-hx - 18.0, hx + 18.0)
		var s := rng.randf_range(1.2, 2.4)
		items.append([Vector3(x, rng.randf_range(5.0, 7.5), z), rng.randf_range(0.25, 0.5), Vector3(s * 1.4, s * 0.8, s)])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = SM.get_mesh(ctx.theme, "cloud", ctx.pal)
	mm.instance_count = items.size()
	var d := Life.Drifter.new()
	d.name = "Nubes"
	d.multimesh = mm
	d.items = items
	d.x_min = -hx - 20.0
	d.x_max = hx + 20.0
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ctx.root.add_child(d)
	d._process(0.0)


static func _build_floaters(ctx: Dictionary, id: String) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var hx: float = ctx.hx
	var hz: float = ctx.hz
	var bases: Array = []
	var phases: Array = []
	for t in 80:
		if bases.size() >= 12:
			break
		var x := rng.randf_range(-hx - 14.0, hx + 14.0)
		var z := rng.randf_range(-hz - 14.0, hz + 8.0)
		var d := _board_d(ctx, x, z)
		var s := rng.randf_range(1.0, 2.4)
		if d < 3.0 + s or _corridor_d(ctx, x, z) < 2.0 + s:
			continue
		if ctx.sky and _h(ctx, x, z) > GROUND_Y - 0.1:
			continue
		var y := rng.randf_range(-1.2, 1.2) if ctx.sky else rng.randf_range(1.0, 3.5)
		bases.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, y, z)))
		phases.append(rng.randf() * TAU)
	if bases.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = SM.get_mesh(ctx.theme, id, ctx.pal)
	mm.instance_count = bases.size()
	var b := Life.Bobber.new()
	b.name = "RocasFlotantes"
	b.multimesh = mm
	b.bases = bases
	b.phases = phases
	b.amp = 0.2
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ctx.root.add_child(b)
	b._process(0.0)


# ================================================================== Volcado final
static func _flush(ctx: Dictionary) -> void:
	var inst: Dictionary = ctx.inst
	# Los modelos con pocas copias (edificios, puentes, monumentos...) se fusionan en una sola
	# malla estática: una llamada por material para todos ellos en vez de una por modelo.
	var solid := Node3D.new()
	for id in inst.keys():
		var xfs: Array = inst[id]
		var real: String = String(id).get_slice("@", 0)
		var mesh := SM.get_mesh(ctx.theme, real, ctx.pal)
		var sways := false
		for s in mesh.get_surface_count():
			if mesh.surface_get_material(s) is ShaderMaterial:
				sways = true
		if not sways and (xfs.size() <= 8 or real in BAKE_IDS):
			var into: Node3D = solid if not ctx.noshadow.has(id) else ctx.bake_root
			for xf in xfs:
				var holder := Node3D.new()
				holder.transform = xf
				into.add_child(holder)
				SM.build(holder, real, ctx.pal)
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MM_" + String(id)
		mmi.multimesh = mm
		if ctx.noshadow.has(id):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ctx.root.add_child(mmi)
	# Geometría única fusionada: con sombra (edificios) y sin sombra (campos, cosas planas)
	if solid.get_child_count() > 0:
		var mi := MeshInstance3D.new()
		mi.name = "Construcciones"
		mi.mesh = M.bake(solid)
		ctx.root.add_child(mi)
	solid.free()
	var st: Node3D = ctx.bake_root
	if st.get_child_count() > 0:
		var mi := MeshInstance3D.new()
		mi.name = "Campos"
		mi.mesh = M.bake(st)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ctx.root.add_child(mi)
	st.free()
