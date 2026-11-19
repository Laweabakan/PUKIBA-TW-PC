extends Node3D
## Modelo 3D de la torre del gato mago de hielo (inspirado en el arte conceptual):
## torre de piedra nevada con carámbanos y cristales de hielo brillantes, estandartes azules
## con copo de nieve, faroles azules, escudo con copo y puerta de hielo resplandeciente.
## El gato es un viejo mago: barba y cejas blancas, sombrero de mago azul, túnica azul con ribetes
## de piel blanca y un bastón con estrella de hielo.

const M := preload("res://scripts/towers3d/models.gd")
const Cat := preload("res://scripts/towers3d/human_common.gd")
const ArcherModel := preload("res://scripts/towers3d/archer_model.gd")   # piedras de la base

const SNOW := Color(0.95, 0.97, 1.0)
const ICE := Color(0.42, 0.76, 1.0)
const ICE_GLOW := Color(0.25, 0.6, 1.0)
const BLUE := Color(0.16, 0.3, 0.66)
const BLUE_DARK := Color(0.1, 0.18, 0.42)
const SILVER := Color(0.78, 0.8, 0.86)
const STONE_DARK := Color(0.32, 0.34, 0.4)

const PLATFORM_Y := 1.06
const STAFF_HAND := Vector3(0.2, 0.26, -0.12)
const STAR_LOCAL := Vector3(0, 0.56, 0)

var cat_pivot: Node3D
var _staff: Node3D
var _star: Node3D
var _hand_ice: Node3D
var _cape: Node3D
var _sparks: CPUParticles3D

## Altura de la plataforma (pies del mago) en cada etapa visual
const TIER_PY := [0.78, 0.96, 1.06, 1.42]
## Etapa 3: el cuerpo de la torre se eleva sobre un zócalo de hielo y sillería clara
const T3_LIFT := 0.36

var _tier := 0
var _py := PLATFORM_Y
var _shards: Node3D            # etapa 3: esquirlas de hielo flotando en órbita
var _pennants: Array[Node3D] = []


static func _tier_of(level: int) -> int:
	if level >= 5:
		return 3
	if level >= 4:
		return 2
	if level >= 2:
		return 1
	return 0


## level: nivel de la torre. Etapas: 0 cabaña de troncos nevada sobre un mojón de piedras, 1 torre de piedra
## con planta de madera, 2 torre nevada de cristales, 3 (Maestría) ciudadela de hielo con agujas y esquirlas en órbita.
func _init(level := 0) -> void:
	_tier = _tier_of(level)
	_py = TIER_PY[_tier]
	M.add_baked(self, M.baked("ice_tower_t%d" % _tier, _build_tower_tier))
	add_child(_snowfall(_tier))
	if _tier == 3:
		_build_majestic_parts()
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, _py, 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("ice_cat_t%d" % _tier, _build_cat_body))
	_build_cat_parts()
	set_pose(0.3, 0.0, 0.0)


## charge: 0..1 carga del hechizo (la estrella gira más rápido y crece). cast: estocada al lanzar.
func set_pose(charge: float, cast: float, t: float, charging := false) -> void:
	_staff.rotation.x = lerpf(-0.15 + charge * 0.5, -0.95, cast)
	_star.rotation.z = t * (1.2 + charge * 7.0)
	_star.scale = Vector3.ONE * (0.75 + charge * 0.6)
	_sparks.emitting = charging
	_hand_ice.scale = Vector3.ONE * (0.7 + charge * 0.6 + sin(t * 9.0) * 0.05)
	if _shards:
		_shards.rotation.y = -t * (0.6 + charge * 1.5)
		_shards.position.y = _py + 0.45 + sin(t * 1.6) * 0.03
		for i in _shards.get_child_count():
			var sh := _shards.get_child(i) as Node3D
			sh.rotation.y = t * 2.0 + i
	for i in _pennants.size():
		_pennants[i].rotation.y = sin(t * 3.0 + i * 1.7) * 0.35 + (0.25 if i == 0 else -0.25)
	_cape.rotation.x = -deg_to_rad(18.0 + sin(t * 5.0) * 7.0)


func star_global() -> Vector3:
	return _star.global_position


# Copos de nieve que caen alrededor de la torre
static func _snowfall(tier: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = [8, 12, 16, 28][tier]
	p.lifetime = 2.2
	p.position = Vector3(0, [1.2, 1.4, 1.5, 1.95][tier], 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.55, 0.2, 0.55)
	p.direction = Vector3.DOWN
	p.spread = 25.0
	p.gravity = Vector3(0, -0.25, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.15
	var mesh := SphereMesh.new()
	mesh.radius = 0.014
	mesh.height = 0.028
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = M.mat(Color(0.92, 0.97, 1.0), 0.8)
	p.mesh = mesh
	return p


# --- Torre ---

func _build_tower_tier(parent: Node3D) -> void:
	match _tier:
		0:
			_build_hut(parent)
		1:
			_build_keep(parent)
		2:
			_build_tower(parent)
		_:
			_build_plinth(parent)
			_build_tower(parent, T3_LIFT)
			_build_majestic(parent)


## lift: en la Maestría el cuerpo se eleva sobre el zócalo de hielo (pilares, estacas y nieve quedan en el suelo).
func _build_tower(root: Node3D, lift := 0.0) -> void:
	var parent := Node3D.new()
	parent.position.y = lift
	root.add_child(parent)
	var stone := M.tex_mat("bricks", 2.2, Color(0.62, 0.66, 0.74) if lift == 0.0 else Color(0.86, 0.92, 1.0))
	var stones := [M.mat(Color(0.38, 0.42, 0.5)), M.mat(Color(0.33, 0.36, 0.43)), M.mat(Color(0.44, 0.48, 0.56))] if lift == 0.0 else [M.mat(Color(0.78, 0.86, 0.96)), M.mat(Color(0.7, 0.8, 0.92)), M.mat(Color(0.88, 0.93, 1.0))]
	var snow := M.mat(SNOW)
	var ice := M.mat(ICE, 0.45)
	var glow := M.mat(ICE_GLOW, 1.0)
	var wood := M.tex_mat("wood", 2.0, Color(0.6, 0.55, 0.55))
	var wood_dark := M.mat(Color(0.28, 0.2, 0.16))
	var silver := M.metal(SILVER)
	var blue := M.mat(BLUE)
	var white := M.mat(Color(0.95, 0.97, 1.0))
	var dark := M.mat(STONE_DARK)

	# Zócalo y base de piedra con nieve encima y carámbanos colgando
	if lift == 0.0:
		M.box(parent, Vector3(0.9, 0.08, 0.9), dark, Vector3(0, 0.04, 0))
	M.box(parent, Vector3(0.74, 0.46, 0.74), stone, Vector3(0, 0.31, 0))
	ArcherModel._stone_blocks(parent, 0.37, 0.15, 3, [[0, 1]] if lift == 0.0 else [], stones)
	M.box(parent, Vector3(0.8, 0.05, 0.8), snow, Vector3(0, 0.56, 0))
	_icicles(parent, 0.535, 0.4, 7, ice)

	if lift == 0.0:
		# Puerta en arco con resplandor y cristales de hielo dentro
		M.box(parent, Vector3(0.28, 0.3, 0.03), dark, Vector3(0, 0.23, 0.372))
		M.cyl(parent, 0.14, 0.14, 0.03, dark, Vector3(0, 0.38, 0.372), Vector3(90, 0, 0), 20)
		M.box(parent, Vector3(0.2, 0.26, 0.02), glow, Vector3(0, 0.22, 0.385))
		M.cyl(parent, 0.1, 0.1, 0.02, glow, Vector3(0, 0.36, 0.385), Vector3(90, 0, 0), 18)
		for x in [-0.05, 0.0, 0.05]:
			Cat.crystal(parent, Vector3(x, 0.09, 0.392), 0.14 if x == 0.0 else 0.1, 0.022, Vector3(0, 0, -x * 200.0), ice)
		M.box(parent, Vector3(0.06, 0.06, 0.03), silver, Vector3(0, 0.53, 0.385), Vector3(0, 0, 45))
		M.box(parent, Vector3(0.03, 0.03, 0.03), glow, Vector3(0, 0.53, 0.395), Vector3(0, 0, 45))
		# escalones nevados
		M.box(parent, Vector3(0.34, 0.03, 0.08), stones[2], Vector3(0, 0.015, 0.43))
		M.box(parent, Vector3(0.34, 0.012, 0.08), snow, Vector3(0, 0.035, 0.43))

	# Pilares con ventana de copo de nieve a los lados de la puerta
	for s in [-1.0, 1.0]:
		M.box(root, Vector3(0.15, 0.36, 0.15), stone, Vector3(0.42 * s, 0.18, 0.42))
		M.box(root, Vector3(0.1, 0.12, 0.015), dark, Vector3(0.42 * s, 0.2, 0.496))
		M.box(root, Vector3(0.08, 0.1, 0.02), glow, Vector3(0.42 * s, 0.2, 0.5))
		Cat.snowflake(root, Vector3(0.42 * s, 0.2, 0.512), 0.55, white)
		M.box(root, Vector3(0.18, 0.04, 0.18), snow, Vector3(0.42 * s, 0.38, 0.42))
		Cat.crystal_cluster(root, Vector3(0.42 * s, 0.4, 0.42), 0.9, ice, 11 + int(s))

	# Cuerpo superior de piedra con vigas de madera, placas de plata y gemas
	M.box(parent, Vector3(0.66, 0.28, 0.66), stone, Vector3(0, 0.71, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.08, 0.32, 0.08), wood_dark, Vector3(0.33 * sx, 0.71, 0.33 * sz))
			M.box(parent, Vector3(0.1, 0.08, 0.1), silver, Vector3(0.33 * sx, 0.82, 0.33 * sz))
			M.box(parent, Vector3(0.035, 0.035, 0.035), glow, Vector3(0.33 * sx, 0.82, 0.33 * sz + 0.05 * sz), Vector3(0, 0, 45))
	for s in [-1.0, 1.0]:
		M.box(parent, Vector3(0.7, 0.045, 0.045), wood, Vector3(0, 0.58, 0.335 * s))
		M.box(parent, Vector3(0.045, 0.045, 0.7), wood, Vector3(0.335 * s, 0.58, 0))
	M.box(parent, Vector3(0.74, 0.04, 0.74), snow, Vector3(0, 0.865, 0))
	_icicles(parent, 0.845, 0.37, 6, ice)

	# Estandartes azules con copo de nieve, borde blanco y olas
	for s in [-1.0, 1.0]:
		var bx: float = 0.2 * s
		M.box(parent, Vector3(0.2, 0.022, 0.022), silver, Vector3(bx, 0.85, 0.355))
		M.box(parent, Vector3(0.17, 0.32, 0.016), white, Vector3(bx, 0.68, 0.352))
		M.box(parent, Vector3(0.145, 0.3, 0.02), blue, Vector3(bx, 0.685, 0.355))
		Cat.snowflake(parent, Vector3(bx, 0.72, 0.368), 0.75, white)
		for k in 2:
			M.box(parent, Vector3(0.11, 0.01, 0.006), white, Vector3(bx, 0.58 + k * 0.025, 0.367))
		for k in [-1.0, 1.0]:
			M.cyl(parent, 0.0, 0.035, 0.05, blue, Vector3(bx + 0.04 * k, 0.51, 0.355), Vector3(180, 0, 0), 4)
		M.cyl(parent, 0.01, 0.022, 0.06, M.mat(BLUE.lightened(0.2)), Vector3(bx + 0.1 * s, 0.76, 0.36), Vector3.ZERO, 8)
	# Escudo de plata con copo de nieve (sobre la puerta)
	M.cyl(parent, 0.085, 0.085, 0.02, silver, Vector3(0, 0.66, 0.35), Vector3(90, 0, 0), 20)
	M.cyl(parent, 0.068, 0.068, 0.022, M.mat(BLUE_DARK), Vector3(0, 0.66, 0.354), Vector3(90, 0, 0), 20)
	Cat.snowflake(parent, Vector3(0, 0.66, 0.367), 0.6, white)

	# Faroles azules colgando a los lados
	for s in [-1.0, 1.0]:
		var lp := Vector3(0.47 * s, 0.76, 0.0)
		M.box(parent, Vector3(0.16, 0.03, 0.03), wood_dark, Vector3(0.4 * s, 0.93, 0.0))
		M.segment(parent, 0.006, silver, lp + Vector3(0, 0.08, 0), lp + Vector3(0, 0.17, 0), 4)
		M.box(parent, Vector3(0.1, 0.13, 0.1), M.metal(Color(0.3, 0.32, 0.38)), lp)
		M.box(parent, Vector3(0.08, 0.11, 0.105), glow, lp)
		M.box(parent, Vector3(0.105, 0.11, 0.08), glow, lp)
		M.cyl(parent, 0.0, 0.065, 0.05, snow, lp + Vector3(0, 0.09, 0), Vector3.ZERO, 4)
		M.cyl(parent, 0.0, 0.015, 0.04, ice, lp + Vector3(0, -0.085, 0), Vector3(180, 0, 0), 6)

	# Grandes grupos de cristales en las esquinas y los lados
	var spots := [Vector3(0.33, 0.88, 0.33), Vector3(-0.33, 0.88, 0.33), Vector3(0.38, 0.58, -0.25), Vector3(-0.38, 0.58, -0.25),
			Vector3(0.0, 0.58, 0.38)]
	for i in spots.size():
		Cat.crystal_cluster(parent, spots[i], 1.0 if i < 2 else 1.2, ice, 30 + i)

	# Plataforma de madera nevada con barandilla, remates de plata y colmillos
	M.box(parent, Vector3(0.66, 0.06, 0.66), wood, Vector3(0, 1.03, 0))
	for y in [1.1, 1.17]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.58, 0.025, 0.025), wood_dark, Vector3(0, y, 0.3 * s))
			M.box(parent, Vector3(0.025, 0.025, 0.58), wood_dark, Vector3(0.3 * s, y, 0))
	for s in [-1.0, 1.0]:
		M.box(parent, Vector3(0.6, 0.02, 0.045), snow, Vector3(0, 1.19, 0.3 * s))
		M.box(parent, Vector3(0.045, 0.02, 0.6), snow, Vector3(0.3 * s, 1.19, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.06, 0.16, 0.06), wood_dark, Vector3(0.3 * sx, 1.13, 0.3 * sz))
			M.box(parent, Vector3(0.08, 0.06, 0.08), silver, Vector3(0.3 * sx, 1.22, 0.3 * sz))
			M.box(parent, Vector3(0.03, 0.03, 0.03), glow, Vector3(0.3 * sx, 1.22, 0.3 * sz + 0.04 * sz), Vector3(0, 0, 45))
	for sx in [-1.0, 1.0]:
		var tusk := Node3D.new()
		tusk.position = Vector3(0.34 * sx, 1.12, -0.34)
		tusk.rotation = Vector3(-0.6, 0, -0.6 * sx)
		parent.add_child(tusk)
		M.cyl(tusk, 0.0, 0.032, 0.17, white, Vector3(0, 0.085, 0), Vector3.ZERO, 8)
		Cat.crystal_cluster(parent, Vector3(0.28 * sx, 1.2, -0.28), 0.8, ice, 50 + int(sx))

	# Estacas nevadas con cuerda, arbustos escarchados y nieve alrededor
	for p in [Vector3(0.46, 0, 0.3), Vector3(-0.46, 0, 0.3), Vector3(0.46, 0, -0.2)]:
		M.cyl(root, 0.03, 0.03, 0.24, wood_dark, p + Vector3(0, 0.12, 0), Vector3.ZERO, 6)
		M.cyl(root, 0.0, 0.034, 0.07, snow, p + Vector3(0, 0.27, 0), Vector3.ZERO, 6)
		M.cyl(root, 0.035, 0.035, 0.025, M.mat(Color(0.82, 0.7, 0.5)), p + Vector3(0, 0.14, 0), Vector3.ZERO, 8)
	var frost := M.mat(Color(0.72, 0.84, 0.86))
	for p in [Vector3(-0.3, 0.05, 0.47), Vector3(0.3, 0.05, 0.47), Vector3(-0.47, 0.05, -0.1), Vector3(0.1, 0.05, -0.47)]:
		M.sphere(root, 0.07, frost, p, Vector3(1.2, 0.8, 1.0), 10)
		M.sphere(root, 0.04, snow, p + Vector3(0.02, 0.04, 0.0), Vector3(1.2, 0.5, 1.0), 8)
	for p in [Vector3(-0.44, 0.0, 0.0), Vector3(0.0, 0.0, -0.46), Vector3(0.44, 0.0, 0.12), Vector3(-0.2, 0.0, 0.46)]:
		M.sphere(root, 0.09, snow, p, Vector3(1.4, 0.25, 1.0), 10)


# --- Etapa 0: cabaña de troncos nevada sobre un mojón de piedras ---

func _build_hut(parent: Node3D) -> void:
	var py := _py
	var stones := [M.mat(Color(0.5, 0.52, 0.56)), M.mat(Color(0.42, 0.44, 0.49)), M.mat(Color(0.58, 0.6, 0.64))]
	var snow := M.mat(SNOW)
	var ice := M.mat(ICE, 0.45)
	var glow := M.mat(ICE_GLOW, 1.0)
	var planks := M.tex_mat("wood", 2.5, Color(0.66, 0.56, 0.5))
	var log_m := M.mat(Color(0.4, 0.3, 0.22))
	var log_dark := M.mat(Color(0.27, 0.2, 0.15))
	var rope := M.mat(Color(0.8, 0.7, 0.5))

	# Suelo nevado y mojón de piedras irregulares
	M.cyl(parent, 0.45, 0.47, 0.04, snow, Vector3(0, 0.02, 0), Vector3.ZERO, 18)
	M.box(parent, Vector3(0.58, 0.3, 0.58), stones[1], Vector3(0, 0.18, 0))
	ArcherModel._stone_blocks(parent, 0.29, 0.1, 2, [[0, 1]], stones)
	M.box(parent, Vector3(0.62, 0.04, 0.62), snow, Vector3(0, 0.34, 0))
	_icicles(parent, 0.32, 0.31, 4, ice)
	# puertecilla de tablas escarchada
	M.box(parent, Vector3(0.16, 0.24, 0.03), log_dark, Vector3(0, 0.16, 0.295))
	M.box(parent, Vector3(0.12, 0.2, 0.02), planks, Vector3(0, 0.15, 0.31))
	M.box(parent, Vector3(0.16, 0.03, 0.04), snow, Vector3(0, 0.29, 0.305))

	# Cabaña de troncos horizontales (con las puntas cruzadas en las esquinas)
	var hh := py - 0.4
	M.box(parent, Vector3(0.5, hh, 0.5), planks, Vector3(0, 0.36 + hh / 2.0, 0))
	var n_logs := int(hh / 0.075)
	for k in n_logs:
		var y := 0.395 + k * 0.075
		var off := 0.02 if k % 2 == 0 else 0.0
		for s in [-1.0, 1.0]:
			M.cyl(parent, 0.032, 0.032, 0.6 + off, log_m if k % 2 == 0 else log_dark, Vector3(0, y, 0.26 * s), Vector3(0, 0, 90), 7)
			M.cyl(parent, 0.032, 0.032, 0.62 - off, log_dark if k % 2 == 0 else log_m, Vector3(0.26 * s, y + 0.035, 0), Vector3(90, 0, 0), 7)
	# ventanuco con luz azul
	M.box(parent, Vector3(0.1, 0.1, 0.03), log_dark, Vector3(0, 0.55, 0.29))
	M.box(parent, Vector3(0.07, 0.07, 0.03), glow, Vector3(0, 0.55, 0.296))

	# Plataforma de tablones nevada con barandilla de troncos
	M.box(parent, Vector3(0.68, 0.06, 0.68), planks, Vector3(0, py - 0.03, 0))
	M.box(parent, Vector3(0.7, 0.02, 0.7), snow, Vector3(0, py - 0.065, 0))
	_icicles(parent, py - 0.07, 0.34, 4, ice)
	var corners := [Vector3(0.31, 0, 0.31), Vector3(-0.31, 0, 0.31), Vector3(-0.31, 0, -0.31), Vector3(0.31, 0, -0.31)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		M.cyl(parent, 0.022, 0.026, 0.2, log_m, a + Vector3(0, py + 0.1, 0), Vector3.ZERO, 6)
		M.sphere(parent, 0.03, snow, a + Vector3(0, py + 0.21, 0), Vector3(1.2, 0.6, 1.2), 8)
		if i == 2:
			continue    # lateral izquierdo abierto: por ahí sube la escalera
		M.segment(parent, 0.017, log_m, a + Vector3(0, py + 0.16, 0), b + Vector3(0, py + 0.16, 0), 6)
		M.box(parent, (b - a).abs() + Vector3(0.035, 0.012, 0.035), snow, (a + b) * 0.5 + Vector3(0, py + 0.18, 0))
	for p in [Vector3(0.31, 0, 0.31), Vector3(-0.31, 0, -0.31)]:
		M.cyl(parent, 0.03, 0.03, 0.02, rope, p + Vector3(0, py + 0.15, 0), Vector3.ZERO, 6)
	# Escalera de mano en el lado izquierdo
	for s in [-1.0, 1.0]:
		M.segment(parent, 0.016, log_m, Vector3(-0.46, 0.02, 0.09 * s), Vector3(-0.34, py + 0.12, 0.09 * s), 6)
	for k in 5:
		var f := (k + 0.6) / 5.6
		var lx := lerpf(-0.46, -0.34, f)
		var ly := 0.02 + f * (py + 0.1)
		M.segment(parent, 0.01, log_dark, Vector3(lx, ly, -0.09), Vector3(lx, ly + 0.0001, 0.09), 4)

	# Farolillo azul en un poste de la esquina delantera
	var lp := Vector3(0.31, py + 0.3, 0.31)
	M.cyl(parent, 0.016, 0.016, 0.12, log_m, lp + Vector3(0, -0.08, 0), Vector3.ZERO, 6)
	M.box(parent, Vector3(0.07, 0.08, 0.07), M.metal(Color(0.3, 0.32, 0.38)), lp)
	M.box(parent, Vector3(0.055, 0.065, 0.075), glow, lp)
	M.cyl(parent, 0.0, 0.05, 0.04, snow, lp + Vector3(0, 0.06, 0), Vector3(0, 45, 0), 4)

	# Muñeco de nieve con bufanda azul, leña nevada y montoncitos de nieve
	var sm := Vector3(0.36, 0, 0.26)
	M.sphere(parent, 0.075, snow, sm + Vector3(0, 0.07, 0), Vector3.ONE, 12)
	M.sphere(parent, 0.055, snow, sm + Vector3(0, 0.17, 0), Vector3.ONE, 12)
	M.sphere(parent, 0.04, snow, sm + Vector3(0, 0.25, 0), Vector3.ONE, 10)
	M.cyl(parent, 0.045, 0.05, 0.02, M.mat(BLUE), sm + Vector3(0, 0.215, 0), Vector3.ZERO, 10)
	M.cyl(parent, 0.0, 0.01, 0.05, M.mat(Color(1.0, 0.5, 0.15)), sm + Vector3(0, 0.25, 0.055), Vector3(90, 0, 0), 5)
	for s in [-1.0, 1.0]:
		M.sphere(parent, 0.007, M.mat(Color(0.08, 0.08, 0.1)), sm + Vector3(0.015 * s, 0.265, 0.035), Vector3.ONE, 4)
	for i in 4:
		M.cyl(parent, 0.026, 0.026, 0.2, log_m if i % 2 == 0 else log_dark, Vector3(0.37, 0.06 + (0.05 if i >= 3 else 0.0), -0.34 + (i % 3) * 0.055), Vector3(90, 0, 0), 7)
	M.box(parent, Vector3(0.1, 0.025, 0.2), snow, Vector3(0.37, 0.14, -0.29))
	for p in [Vector3(-0.42, 0.0, 0.3), Vector3(0.1, 0.0, -0.44), Vector3(-0.3, 0.0, -0.4)]:
		M.sphere(parent, 0.08, snow, p, Vector3(1.4, 0.3, 1.0), 10)


# --- Etapa 1: planta baja de piedra nevada y planta alta de madera azul ---

func _build_keep(parent: Node3D) -> void:
	var py := _py
	var stone := M.tex_mat("bricks", 2.2, Color(0.62, 0.66, 0.74))
	var stones := [M.mat(Color(0.38, 0.42, 0.5)), M.mat(Color(0.33, 0.36, 0.43)), M.mat(Color(0.44, 0.48, 0.56))]
	var snow := M.mat(SNOW)
	var ice := M.mat(ICE, 0.45)
	var glow := M.mat(ICE_GLOW, 1.0)
	var blue_wood := M.tex_mat("wood", 2.2, Color(0.55, 0.68, 0.9))
	var wood_dark := M.mat(Color(0.28, 0.2, 0.16))
	var silver := M.metal(SILVER)
	var iron := M.metal(Color(0.3, 0.32, 0.38))
	var blue := M.mat(BLUE)
	var white := M.mat(Color(0.95, 0.97, 1.0))

	M.box(parent, Vector3(0.86, 0.06, 0.86), M.mat(STONE_DARK), Vector3(0, 0.03, 0))
	M.box(parent, Vector3(0.68, 0.44, 0.68), stone, Vector3(0, 0.28, 0))
	ArcherModel._stone_blocks(parent, 0.34, 0.14, 3, [[0, 1]], stones)
	M.box(parent, Vector3(0.74, 0.045, 0.74), snow, Vector3(0, 0.515, 0))
	_icicles(parent, 0.495, 0.37, 5, ice)
	# esquinas con flejes de hierro
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for y in [0.15, 0.4]:
				M.box(parent, Vector3(0.085, 0.04, 0.085), iron, Vector3(0.34 * sx, y, 0.34 * sz))
	# puerta de madera azul con bandas de hierro y luz helada en el dintel
	var door := Vector3(0, 0, 0.345)
	M.box(parent, Vector3(0.24, 0.26, 0.04), stones[2], door + Vector3(0, 0.19, 0))
	M.cyl(parent, 0.12, 0.12, 0.04, stones[2], door + Vector3(0, 0.32, 0), Vector3(90, 0, 0), 16)
	M.box(parent, Vector3(0.18, 0.22, 0.03), blue_wood, door + Vector3(0, 0.17, 0.016))
	M.cyl(parent, 0.09, 0.09, 0.03, glow, door + Vector3(0, 0.29, 0.016), Vector3(90, 0, 0), 14)
	for y in [0.1, 0.22]:
		M.box(parent, Vector3(0.19, 0.022, 0.012), iron, door + Vector3(0, y, 0.035))
	M.box(parent, Vector3(0.3, 0.025, 0.07), snow, door + Vector3(0, 0.44, 0.0))

	# Planta alta de tablones azules con postes oscuros y ventanas heladas
	var y0 := 0.535
	var hh := py - 0.05 - y0
	M.box(parent, Vector3(0.6, hh, 0.6), blue_wood, Vector3(0, y0 + hh / 2.0, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.07, hh, 0.07), wood_dark, Vector3(0.3 * sx, y0 + hh / 2.0, 0.3 * sz))
			M.box(parent, Vector3(0.085, 0.05, 0.085), silver, Vector3(0.3 * sx, y0 + hh * 0.5, 0.3 * sz))
	for face in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)]:
		var w := Node3D.new()
		w.position = face * 0.302 + Vector3(0, y0 + hh * 0.5, 0)
		w.rotation.y = atan2(face.x, face.z)
		parent.add_child(w)
		M.box(w, Vector3(0.12, 0.13, 0.02), wood_dark)
		M.box(w, Vector3(0.09, 0.1, 0.02), glow, Vector3(0, 0, 0.006))
		Cat.snowflake(w, Vector3(0, 0, 0.02), 0.45, white)
	# estandarte azul con copo de nieve al frente
	M.box(parent, Vector3(0.22, 0.02, 0.02), silver, Vector3(0, py - 0.08, 0.32))
	M.box(parent, Vector3(0.17, 0.3, 0.016), white, Vector3(0, py - 0.24, 0.318))
	M.box(parent, Vector3(0.145, 0.28, 0.02), blue, Vector3(0, py - 0.235, 0.32))
	Cat.snowflake(parent, Vector3(0, py - 0.21, 0.333), 0.7, white)
	for k in [-1.0, 1.0]:
		M.cyl(parent, 0.0, 0.035, 0.05, blue, Vector3(0.04 * k, py - 0.4, 0.32), Vector3(180, 0, 0), 4)

	# Plataforma nevada con barandilla de madera y remates de plata
	M.box(parent, Vector3(0.7, 0.06, 0.7), M.tex_mat("wood", 2.0, Color(0.6, 0.55, 0.55)), Vector3(0, py - 0.03, 0))
	M.box(parent, Vector3(0.72, 0.02, 0.72), snow, Vector3(0, py - 0.065, 0))
	_icicles(parent, py - 0.075, 0.35, 5, ice)
	for y in [py + 0.07, py + 0.14]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.6, 0.025, 0.025), wood_dark, Vector3(0, y, 0.3 * s))
			M.box(parent, Vector3(0.025, 0.025, 0.6), wood_dark, Vector3(0.3 * s, y, 0))
	for s in [-1.0, 1.0]:
		M.box(parent, Vector3(0.62, 0.02, 0.045), snow, Vector3(0, py + 0.16, 0.3 * s))
		M.box(parent, Vector3(0.045, 0.02, 0.62), snow, Vector3(0.3 * s, py + 0.16, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.055, 0.17, 0.055), wood_dark, Vector3(0.3 * sx, py + 0.08, 0.3 * sz))
			M.box(parent, Vector3(0.07, 0.05, 0.07), silver, Vector3(0.3 * sx, py + 0.18, 0.3 * sz))
	Cat.crystal_cluster(parent, Vector3(-0.28, py + 0.17, -0.28), 0.7, ice, 61)

	# Farol azul colgado en el lateral y cristales junto a la base
	var lp := Vector3(0.45, 0.66, 0.0)
	M.box(parent, Vector3(0.16, 0.03, 0.03), wood_dark, Vector3(0.38, 0.82, 0.0))
	M.segment(parent, 0.006, silver, lp + Vector3(0, 0.07, 0), lp + Vector3(0, 0.15, 0), 4)
	M.box(parent, Vector3(0.09, 0.11, 0.09), iron, lp)
	M.box(parent, Vector3(0.07, 0.09, 0.095), glow, lp)
	M.cyl(parent, 0.0, 0.06, 0.05, snow, lp + Vector3(0, 0.08, 0), Vector3(0, 45, 0), 4)
	for i in 2:
		Cat.crystal_cluster(parent, [Vector3(-0.4, 0.04, 0.3), Vector3(0.38, 0.04, -0.34)][i], 1.0, ice, 70 + i)
	for p in [Vector3(-0.44, 0.0, 0.0), Vector3(0.0, 0.0, -0.46), Vector3(0.44, 0.0, 0.25)]:
		M.sphere(parent, 0.09, snow, p, Vector3(1.4, 0.25, 1.0), 10)


# --- Etapa 3 (Maestría): zócalo de sillería clara y hielo con portal resplandeciente ---

func _build_plinth(parent: Node3D) -> void:
	var marble := M.mat(Color(0.93, 0.96, 1.0))
	var silver := M.metal(SILVER)
	var gold := M.metal(Color(1.0, 0.8, 0.35))
	var glow := M.mat(ICE_GLOW, 1.4)
	var ice := M.mat(ICE, 0.6)
	var lift := T3_LIFT + 0.08
	M.box(parent, Vector3(0.94, 0.06, 0.94), marble, Vector3(0, 0.03, 0))
	M.box(parent, Vector3(0.78, lift, 0.78), M.mat(Color(0.8, 0.86, 0.94)), Vector3(0, lift / 2.0, 0))
	ArcherModel._stone_blocks(parent, 0.39, 0.12, 2, [[0, 1]], [marble, M.mat(Color(0.86, 0.92, 1.0)), M.mat(Color(0.95, 0.98, 1.0))])
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for k in 3:
				var big := k % 2 == 0
				M.box(parent, Vector3(0.13 if big else 0.1, 0.12, 0.13 if big else 0.1), marble,
						Vector3(0.39 * sx, 0.08 + k * 0.13, 0.39 * sz))
	for y in [0.07, lift - 0.02]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.84, 0.03, 0.03), gold, Vector3(0, y, 0.405 * s))
			M.box(parent, Vector3(0.03, 0.03, 0.84), gold, Vector3(0.405 * s, y, 0))
	_icicles(parent, lift - 0.04, 0.41, 7, ice)
	# portal de hielo resplandeciente con marco de plata y oro
	var door := Vector3(0, 0, 0.4)
	M.box(parent, Vector3(0.24, 0.24, 0.03), silver, door + Vector3(0, 0.15, 0))
	M.cyl(parent, 0.12, 0.12, 0.03, silver, door + Vector3(0, 0.27, 0), Vector3(90, 0, 0), 18)
	M.box(parent, Vector3(0.19, 0.22, 0.03), glow, door + Vector3(0, 0.14, 0.008))
	M.cyl(parent, 0.095, 0.095, 0.03, glow, door + Vector3(0, 0.25, 0.008), Vector3(90, 0, 0), 16)
	Cat.snowflake(parent, door + Vector3(0, 0.2, 0.03), 1.0, M.mat(Color.WHITE, 1.0))
	M.box(parent, Vector3(0.06, 0.06, 0.03), gold, door + Vector3(0, 0.37, 0.005), Vector3(0, 0, 45))
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(0.402 * s, 0.24, 0.0)
		w.rotation.y = PI / 2.0 * s
		parent.add_child(w)
		M.box(w, Vector3(0.12, 0.14, 0.02), silver)
		M.box(w, Vector3(0.09, 0.11, 0.02), glow, Vector3(0, 0, 0.006))
		Cat.snowflake(w, Vector3(0, 0, 0.02), 0.5, M.mat(Color.WHITE))


# Remates fijos de la Maestría: grandes agujas de hielo y mástiles con gallardetes
func _build_majestic(parent: Node3D) -> void:
	var ice := M.mat(Color(0.6, 0.88, 1.0), 0.9)
	var silver := M.metal(SILVER)
	var gold := M.metal(Color(1.0, 0.8, 0.35))
	var py := _py
	# agujas de hielo que brotan de las esquinas delanteras de la plataforma
	for s in [-1.0, 1.0]:
		var base := Vector3(0.34 * s, py + 0.02, 0.34)
		Cat.crystal(parent, base, 0.55, 0.06, Vector3(-8, 0, -10.0 * s), ice)
		Cat.crystal(parent, base + Vector3(0.05 * s, 0, -0.04), 0.3, 0.04, Vector3(-20, 0, -35.0 * s), ice)
		Cat.crystal(parent, base + Vector3(-0.04 * s, 0, 0.03), 0.25, 0.035, Vector3(25, 0, 15.0 * s), ice)
	# mástiles de plata con estrella de oro en las esquinas traseras
	for s in [-1.0, 1.0]:
		var mp := Vector3(0.36 * s, 0, -0.36)
		M.cyl(parent, 0.02, 0.024, 0.72, silver, mp + Vector3(0, py + 0.32, 0), Vector3.ZERO, 8)
		M.sphere(parent, 0.032, gold, mp + Vector3(0, py + 0.7, 0), Vector3.ONE, 10)
		for i in 4:
			M.cyl(parent, 0.0, 0.014, 0.06, gold, mp + Vector3(0, py + 0.7, 0), Vector3(0, 45, 90.0 * i), 4)
		Cat.crystal(parent, mp + Vector3(0, py + 0.72, 0), 0.12, 0.022, Vector3.ZERO, ice)


# Partes animadas de la Maestría: esquirlas de hielo en órbita y gallardetes al viento
func _build_majestic_parts() -> void:
	var ice := M.mat(Color(0.7, 0.92, 1.0), 1.3)
	_shards = Node3D.new()
	_shards.position = Vector3(0, _py + 0.45, 0)
	add_child(_shards)
	for i in 6:
		var a := TAU * i / 6.0
		var sh := Node3D.new()
		sh.position = Vector3(cos(a), sin(a * 2.0) * 0.08, sin(a)) * 0.5
		_shards.add_child(sh)
		Cat.crystal(sh, Vector3(0, -0.06, 0), 0.12, 0.025, Vector3.ZERO, ice)
		Cat.crystal(sh, Vector3(0, 0.06, 0), 0.08, 0.02, Vector3(180, 0, 0), ice)
	for s in [-1.0, 1.0]:
		var pn := Node3D.new()
		pn.position = Vector3(0.36 * s, _py + 0.6, -0.36)
		add_child(pn)
		_pennants.append(pn)
		M.box(pn, Vector3(0.28, 0.1, 0.012), M.mat(BLUE), Vector3(-0.15 * s, 0, 0))
		M.box(pn, Vector3(0.28, 0.02, 0.014), M.mat(Color(0.97, 0.98, 1.0)), Vector3(-0.15 * s, -0.045, 0))
		M.cyl(pn, 0.0, 0.05, 0.1, M.mat(BLUE), Vector3(-0.32 * s, 0, 0), Vector3(0, 0, 90.0 * s), 4)


# Carámbanos colgando bajo un borde a la altura y, alrededor de la torre
static func _icicles(parent: Node3D, y: float, half: float, per_side: int, m: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(y * 1000.0)
	for side in 4:
		for i in per_side:
			var along := -half + 2.0 * half * (i + 0.5) / per_side
			var p := Vector3(along, y, half) if side == 0 else Vector3(half, y, along) if side == 1 \
					else Vector3(-half, y, along) if side == 2 else Vector3(along, y, -half)
			var h := rng.randf_range(0.04, 0.1)
			M.cyl(parent, 0.0, 0.016, h, m, p + Vector3(0, -h / 2.0, 0), Vector3(180, 0, 0), 5)


# --- Gatito mago de hielo ---

# Color de la túnica: lana gris azulada (0), azul de mago (1-2), blanco de escarcha en la Maestría (3)
func _robe_col() -> Color:
	return [Color(0.42, 0.47, 0.58), BLUE, BLUE, Color(0.9, 0.94, 1.0)][_tier]


func _build_cat_body(c: Node3D) -> void:
	var blue := M.mat(_robe_col())
	var fur := M.mat(Color(0.97, 0.97, 1.0) if _tier > 0 else Color(0.82, 0.78, 0.7))
	var silver := M.metal(SILVER) if _tier < 3 else M.metal(Color(1.0, 0.8, 0.35))
	if _tier == 0:
		silver = M.mat(Color(0.45, 0.32, 0.2))
	var glow := M.mat(ICE_GLOW, 1.0)
	Cat.tail(c)
	Cat.body(c, blue, fur)
	Cat.head(c, false, false)   # sin orejas ni rayas: quedan bajo el sombrero
	_old_face(c)
	_wizard_hat(c)
	# ribetes de piel blanca: bajo de la túnica, cuello grande y franja delantera
	var hem := TorusMesh.new()
	hem.inner_radius = 0.15
	hem.outer_radius = 0.2
	M.add(c, hem, fur, Vector3(0, 0.02, 0))
	var collar := TorusMesh.new()
	collar.inner_radius = 0.08
	collar.outer_radius = 0.15
	M.add(c, collar, fur, Vector3(0, 0.33, 0), Vector3(8, 0, 0))
	M.box(c, Vector3(0.055, 0.22, 0.03), fur, Vector3(0, 0.15, -0.135))
	# broche de copo de nieve y cinturón con hebilla
	M.cyl(c, 0.038, 0.038, 0.02, silver, Vector3(0, 0.25, -0.15), Vector3(80, 0, 0), 16)
	M.sphere(c, 0.02, glow, Vector3(0, 0.25, -0.16), Vector3.ONE, 8)
	M.cyl(c, 0.15, 0.15, 0.025, M.mat(Color(0.35, 0.25, 0.2)), Vector3(0, 0.12, 0), Vector3.ZERO, 16)
	M.box(c, Vector3(0.04, 0.035, 0.02), silver, Vector3(0, 0.12, -0.15))
	M.sphere(c, 0.016, glow, Vector3(0.09, 0.09, -0.12), Vector3.ONE, 6)
	# brazos con puños de piel
	Cat.arm(c, Cat.L_SHOULDER, Vector3(-0.14, 0.33, -0.25), blue, fur)
	Cat.arm(c, Cat.R_SHOULDER, STAFF_HAND, blue, fur)
	if _tier == 3:
		# esclavina azul real con orla de oro y hombreras de plata con gemas heladas
		M.cyl(c, 0.13, 0.2, 0.1, M.mat(BLUE_DARK), Vector3(0, 0.29, 0.01), Vector3.ZERO, 18)
		for s in [-1.0, 1.0]:
			M.sphere(c, 0.07, M.metal(SILVER), Vector3(0.14 * s, 0.3, 0), Vector3(1.0, 0.6, 1.0), 12)
			M.sphere(c, 0.018, M.mat(ICE_GLOW, 1.6), Vector3(0.15 * s, 0.32, -0.06), Vector3.ONE, 6)
		M.cyl(c, 0.152, 0.152, 0.03, M.mat(BLUE), Vector3(0, 0.12, 0), Vector3.ZERO, 16)


func _build_cat_parts() -> void:
	var c := cat_pivot
	_cape = Node3D.new()
	_cape.position = Vector3(0, 0.33, 0.1)
	c.add_child(_cape)
	match _tier:
		0:
			M.box(_cape, Vector3(0.26, 0.28, 0.02), M.mat(Color(0.32, 0.36, 0.45)), Vector3(0, -0.13, 0))
		3:
			M.box(_cape, Vector3(0.36, 0.44, 0.02), M.mat(BLUE), Vector3(0, -0.21, 0))
			M.box(_cape, Vector3(0.38, 0.045, 0.035), M.mat(Color(0.97, 0.97, 1.0)), Vector3(0, -0.43, 0))
			for s in [-1.0, 1.0]:
				M.box(_cape, Vector3(0.025, 0.44, 0.026), M.metal(Color(1.0, 0.8, 0.35)), Vector3(0.18 * s, -0.21, 0))
			Cat.snowflake(_cape, Vector3(0, -0.2, 0.016), 1.4, M.mat(Color(0.95, 0.97, 1.0)))
		_:
			M.box(_cape, Vector3(0.3, 0.32, 0.02), M.mat(BLUE_DARK), Vector3(0, -0.15, 0))
			M.box(_cape, Vector3(0.32, 0.04, 0.03), M.mat(Color(0.97, 0.97, 1.0)), Vector3(0, -0.31, 0))

	# bastón con media luna de plata y estrella de hielo
	_staff = Node3D.new()
	_staff.position = STAFF_HAND
	c.add_child(_staff)
	var silver := M.metal(SILVER) if _tier > 0 else M.mat(Color(0.32, 0.22, 0.14))
	var shaft := M.mat(Color(0.42, 0.26, 0.15)) if _tier < 3 else M.metal(SILVER)
	M.segment(_staff, 0.018, shaft, Vector3(0, -0.24, 0), Vector3(0, 0.44, 0), 8)
	if _tier == 3:
		for y in [-0.12, 0.15]:
			M.cyl(_staff, 0.024, 0.024, 0.03, M.metal(Color(1.0, 0.8, 0.35)), Vector3(0, y, 0), Vector3.ZERO, 8)
	for y in [0.0, 0.3]:
		M.cyl(_staff, 0.024, 0.024, 0.035, silver, Vector3(0, y, 0), Vector3.ZERO, 8)
	var hook := TorusMesh.new()
	hook.inner_radius = 0.09
	hook.outer_radius = 0.11
	M.add(_staff, hook, silver, STAR_LOCAL, Vector3(90, 0, 0))
	_star = Node3D.new()
	_star.position = STAR_LOCAL
	_staff.add_child(_star)
	var ice := M.mat(ICE, 0.6)
	var points := 3 if _tier == 0 else 6
	var plen: float = [0.08, 0.11, 0.11, 0.14][_tier]
	for i in points:
		Cat.crystal(_star, Vector3.ZERO, plen, 0.022, Vector3(0, 0, 360.0 / points * i), ice)
	if _tier == 3:
		for i in 6:
			Cat.crystal(_star, Vector3.ZERO, 0.07, 0.016, Vector3(0, 0, 30.0 + 60.0 * i), M.mat(Color(0.85, 0.95, 1.0), 1.2))
	M.sphere(_star, 0.04, M.mat(Color(0.55, 0.85, 1.0), 1.3), Vector3.ZERO, Vector3.ONE, 12)

	_hand_ice = Node3D.new()
	_hand_ice.position = Vector3(-0.14, 0.38, -0.27)
	c.add_child(_hand_ice)
	Cat.crystal_cluster(_hand_ice, Vector3.ZERO, 0.6, ice, 7)

	# copitos que giran y se concentran en la estrella mientras carga
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.amount = 20
	_sparks.lifetime = 0.5
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	_sparks.emission_sphere_radius = 0.26
	_sparks.gravity = Vector3.ZERO
	_sparks.radial_accel_min = -3.0
	_sparks.radial_accel_max = -2.0
	_sparks.tangential_accel_min = 2.0
	_sparks.tangential_accel_max = 3.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.015
	mesh.height = 0.03
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = M.mat(Color(0.85, 0.97, 1.0), 1.8)
	_sparks.mesh = mesh
	_star.add_child(_sparks)


# Rostro de anciano: cejas pobladas, bigote y larga barba blanca que cae sobre el pecho
func _old_face(c: Node3D) -> void:
	var h := Cat.HEAD
	var white := M.mat(Color(0.96, 0.96, 0.98))
	var shade := M.mat(Color(0.86, 0.88, 0.92))
	for s in [-1.0, 1.0]:
		var brow := M.sphere(c, 0.032, white, h + Vector3(0.068 * s, 0.05, -0.138), Vector3(1.7, 0.6, 0.7), 10)
		brow.rotation.z = -0.3 * s
		var stache := M.sphere(c, 0.034, white, h + Vector3(0.042 * s, -0.068, -0.158), Vector3(1.6, 0.6, 0.7), 10)
		stache.rotation.z = 0.35 * s
		M.sphere(c, 0.018, white, h + Vector3(0.09 * s, -0.085, -0.15), Vector3(1.2, 0.8, 0.8), 8)
	var beard := [[Vector3(0, -0.11, -0.12), 0.085, 1.25], [Vector3(0, -0.19, -0.135), 0.072, 1.1],
			[Vector3(0, -0.27, -0.142), 0.056, 1.0], [Vector3(0, -0.34, -0.142), 0.04, 0.9]]
	for i in beard.size():
		var b: Array = beard[i]
		M.sphere(c, b[1], white if i % 2 == 0 else shade, h + b[0], Vector3(b[2], 1.0, 0.65), 12)
	M.cyl(c, 0.0, 0.03, 0.08, white, h + Vector3(0, -0.4, -0.14), Vector3(180, 0, 0), 8)


# Sombrero de mago azul: ala con piel blanca, banda plateada con gema, copa alta con la punta
# doblada, estrella plateada y copos de nieve
func _wizard_hat(c: Node3D) -> void:
	var h := Cat.HEAD
	var hat := M.mat(BLUE if _tier > 0 else Color(0.38, 0.43, 0.54))
	var dark := M.mat(BLUE_DARK if _tier > 0 else Color(0.28, 0.32, 0.4))
	var silver := M.metal(SILVER) if _tier > 0 else M.mat(Color(0.45, 0.32, 0.2))
	var white := M.mat(Color(0.96, 0.97, 1.0))
	M.cyl(c, 0.21, 0.22, 0.03, hat, h + Vector3(0, 0.12, 0.01), Vector3(6, 0, 0), 24)
	var fur := TorusMesh.new()
	fur.inner_radius = 0.19
	fur.outer_radius = 0.235
	M.add(c, fur, white, h + Vector3(0, 0.12, 0.01), Vector3(6, 0, 0))
	M.cyl(c, 0.12, 0.13, 0.05, silver, h + Vector3(0, 0.16, 0.01), Vector3.ZERO, 18)
	M.cyl(c, 0.075, 0.12, 0.22, hat, h + Vector3(0, 0.29, 0.02), Vector3.ZERO, 18)
	var tip := Node3D.new()
	tip.position = h + Vector3(0, 0.39, 0.03)
	tip.rotation = Vector3(0.7, 0, -0.2)
	c.add_child(tip)
	M.cyl(tip, 0.035, 0.075, 0.13, hat, Vector3(0, 0.055, 0), Vector3.ZERO, 14)
	var tip2 := Node3D.new()
	tip2.position = Vector3(0, 0.11, 0)
	tip2.rotation = Vector3(0.6, 0, 0)
	tip.add_child(tip2)
	M.cyl(tip2, 0.0, 0.035, 0.11, dark, Vector3(0, 0.05, 0), Vector3.ZERO, 12)
	for i in 5:
		var a := TAU * i / 5.0
		M.cyl(tip2, 0.0, 0.012, 0.035, silver, Vector3(0, 0.11, 0) + Vector3(cos(a), sin(a), 0) * 0.018, Vector3(0, 0, rad_to_deg(a) - 90.0), 4)
	M.sphere(tip2, 0.018, silver, Vector3(0, 0.11, 0), Vector3.ONE, 8)
	if _tier == 0:
		return
	if _tier == 3:
		# corona de cristales de hielo sobre la banda
		var crown := M.mat(Color(0.65, 0.9, 1.0), 1.1)
		for i in 9:
			var a := TAU * i / 9.0
			Cat.crystal(c, h + Vector3(cos(a) * 0.125, 0.18, sin(a) * 0.125 + 0.01), 0.1 if i % 2 == 0 else 0.07, 0.018,
					Vector3(rad_to_deg(sin(a)) * 0.3, 0, -rad_to_deg(cos(a)) * 0.3), crown)
	# gema helada en la banda y copos de nieve en la copa
	M.box(c, Vector3(0.04, 0.04, 0.02), silver, h + Vector3(0, 0.165, -0.125), Vector3(0, 0, 45))
	M.box(c, Vector3(0.025, 0.025, 0.02), M.mat(ICE_GLOW, 1.0), h + Vector3(0, 0.165, -0.133), Vector3(0, 0, 45))
	Cat.snowflake(c, h + Vector3(0.0, 0.27, -0.1), 0.35, white)
	Cat.snowflake(c, h + Vector3(0.055, 0.33, -0.065), 0.25, white)
	Cat.snowflake(c, h + Vector3(-0.06, 0.22, -0.11), 0.22, white)