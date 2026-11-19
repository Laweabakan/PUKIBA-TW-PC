extends Node3D
## Modelo 3D de la torre lanzacohetes. Cambia de aspecto con la etapa visual (TowerModels.tier):
##   0 (nv 0-1): rampa de cohetes desvencijada: zancos de troncos con riostras, tablones, escalera,
##               tubos de caña atados con cuerda y un artificiero con túnica de lino y gorro de tela.
##   1 (nv 2-3): planta baja de piedra y armazón de roble con herrajes, estandartes rojos y faroles;
##               artificiero con chaqueta acolchada roja, gorro de cuero y gafas de bronce.
##   2 (nv 4):   bastión de sillería con matacanes, almenas, garitas de pizarra, escudos, antorchas y
##               estandartes heráldicos; tubos de hierro; artificiero con cota de malla y tabardo.
##   3 (nv 5):   bastión alquímico de piedra blanca con molduras doradas, pináculos y torreones con
##               agujas doradas, gallardetes ondeando, runas y círculo alquímico brillantes, chispas
##               doradas en el aire; tubos de bronce y oro; artificiero con armadura ornamentada y capa.
## El lanzador y el artificiero giran juntos (cat_pivot) hacia el enemigo (miran a -Z).

const M := preload("res://scripts/towers3d/models.gd")
const Cat := preload("res://scripts/towers3d/human_common.gd")
const ArcherModel := preload("res://scripts/towers3d/archer_model.gd")   # piedras y hierba de la base

const RED := Color(0.78, 0.14, 0.1)
const RED_DARK := Color(0.5, 0.08, 0.06)
const GOLD := Color(1.0, 0.76, 0.28)
const WOOD_DARK := Color(0.32, 0.2, 0.12)
const IRON := Color(0.28, 0.26, 0.26)
const WARM := Color(1.0, 0.65, 0.25)
const ROPE := Color(0.82, 0.7, 0.5)
const LINEN := Color(0.62, 0.5, 0.34)
const WHITE_STONE := Color(1.35, 1.3, 1.16)   # tinte >1: aclara el dibujo de ladrillo
const ALCH_GLOW := Color(1.0, 0.62, 0.18)
const ROYAL_BLUE := Color(0.18, 0.3, 0.7)

const PLATFORM_HEIGHTS := [0.8, 1.06, 1.3, 1.5]
const TUBES := 6
const TUBE_PITCH := -50.0                 # inclinación de los tubos (apuntan hacia delante y arriba)
const TUBE_LEN := 0.42
const CAT_OFFSET := Vector3(-0.17, 0, 0.06)

var cat_pivot: Node3D
var _tier := 0
var _py := 0.8
var _tubes: Array[Node3D] = []
var _loaded: Array[Node3D] = []
var _tube_rest: Array[Vector3] = []
var _spark: Node3D
var _pennants: Array[Node3D] = []
var _aura_ring: Node3D


static func _tier_of(level: int) -> int:
	if level >= 5:
		return 3
	if level >= 4:
		return 2
	if level >= 2:
		return 1
	return 0


func _init(level := 0) -> void:
	_tier = _tier_of(level)
	_py = PLATFORM_HEIGHTS[_tier]
	M.add_baked(self, M.baked("rocket_tower_t%d" % _tier, _build_tower))
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, _py, 0)
	add_child(cat_pivot)
	var cat := Node3D.new()
	cat.position = CAT_OFFSET
	cat_pivot.add_child(cat)
	M.add_baked(cat, M.baked("rocket_cat_t%d" % _tier, _build_cat_body))
	_build_launcher()
	_build_sparkler(cat)
	if _tier >= 2:
		_build_pennants()
	if _tier == 3:
		_build_aura()
	set_pose(0.0, [])


## t: tiempo; recoil: retroceso 0..1 de cada tubo (tras disparar).
func set_pose(t: float, recoil: Array) -> void:
	for i in _tubes.size():
		var r: float = recoil[i] if i < recoil.size() else 0.0
		var dir := _tube_dir()
		_tubes[i].position = _tube_rest[i] - dir * r * 0.07
		_loaded[i].visible = r < 0.05
	_spark.scale = Vector3.ONE * (0.8 + sin(t * 31.0) * 0.25 + sin(t * 17.0) * 0.15)
	for i in _pennants.size():
		_pennants[i].rotation.y = sin(t * 2.6 + i * 1.7) * 0.35
		_pennants[i].rotation.z = sin(t * 3.4 + i) * 0.08
	if _aura_ring:
		_aura_ring.rotation.y = t * 0.5


# Boca del tubo i en coordenadas globales y dirección de salida
func tube_mouth(i: int) -> Vector3:
	return _tubes[i % TUBES].to_global(Vector3(0, TUBE_LEN / 2.0, 0))


func tube_direction() -> Vector3:
	return (cat_pivot.global_transform.basis * _tube_dir()).normalized()


static func _tube_dir() -> Vector3:
	var a := deg_to_rad(TUBE_PITCH)
	return Vector3(0, cos(a), sin(a))


# Cohete decorativo (apunta a +Y local)
static func rocket_prop(parent: Node3D, pos: Vector3, rot_deg: Vector3, s: float, trim: Material = null) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot_deg
	parent.add_child(n)
	var band: Material = trim if trim else M.metal(GOLD)
	M.cyl(n, 0.03 * s, 0.03 * s, 0.18 * s, M.mat(RED), Vector3(0, 0.09 * s, 0), Vector3.ZERO, 10)
	M.cyl(n, 0.033 * s, 0.033 * s, 0.025 * s, band, Vector3(0, 0.16 * s, 0), Vector3.ZERO, 10)
	M.cyl(n, 0.0, 0.034 * s, 0.07 * s, M.mat(RED), Vector3(0, 0.215 * s, 0), Vector3.ZERO, 10)
	M.sphere(n, 0.008 * s, band, Vector3(0, 0.25 * s, 0), Vector3.ONE, 6)
	M.cyl(n, 0.033 * s, 0.033 * s, 0.02 * s, band, Vector3(0, 0.03 * s, 0), Vector3.ZERO, 10)


# Emblema dorado en forma de nube/flor (mirando a +Z)
static func emblem(parent: Node3D, pos: Vector3, s: float, m: Material = null) -> void:
	var gold: Material = m if m else M.metal(GOLD)
	M.sphere(parent, 0.03 * s, gold, pos + Vector3(0, 0.02, 0) * s, Vector3(1, 1, 0.35), 10)
	for a: float in [-50.0, 50.0, 180.0]:
		var d := Vector2.from_angle(deg_to_rad(a - 90.0))
		M.sphere(parent, 0.024 * s, gold, pos + Vector3(d.x, -d.y, 0) * 0.035 * s, Vector3(1, 1, 0.35), 8)
	M.box(parent, Vector3(0.012, 0.04, 0.008) * Vector3(s, s, 1), gold, pos + Vector3(0, -0.03, 0) * s)


# Nodo orientado para decorar una cara (su +Z mira hacia `n`)
static func _face_node(parent: Node3D, n: Vector3, pos: Vector3) -> Node3D:
	var f := Node3D.new()
	f.position = pos
	f.rotation.y = atan2(n.x, n.z)
	parent.add_child(f)
	return f


const FACES := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]


# --- Torre ---

func _build_tower(parent: Node3D) -> void:
	match _tier:
		0: _build_rack(parent)
		1: _build_timber_tower(parent)
		_: _build_bastion(parent, _tier == 3)
	ArcherModel._ground_details(parent, false)


# Etapa 0: rampa de cohetes de troncos, desvencijada
func _build_rack(parent: Node3D) -> void:
	var log_m := M.tex_mat("wood", 2.0, Color(0.7, 0.55, 0.4))
	var plank := M.tex_mat("wood", 2.4, Color(0.82, 0.66, 0.48))
	var plank_dark := M.tex_mat("wood", 2.4, Color(0.62, 0.48, 0.34))
	var bark := M.mat(Color(0.36, 0.25, 0.16))
	var rope := M.mat(ROPE)
	var dirt := M.mat(Color(0.48, 0.37, 0.26))
	var iron := M.metal(IRON)
	var py := _py

	# Suelo de tierra pisada con piedras sueltas
	M.cyl(parent, 0.4, 0.44, 0.04, dirt, Vector3(0, 0.02, -0.02), Vector3.ZERO, 14)
	for p: Vector3 in [Vector3(0.36, 0.03, -0.3), Vector3(-0.28, 0.03, 0.34), Vector3(0.1, 0.03, -0.4)]:
		M.sphere(parent, 0.04, M.mat(Color(0.58, 0.56, 0.52)), p, Vector3(1.2, 0.6, 1.0), 6)

	# Zancos de troncos algo torcidos, con cuñas de piedra en el pie
	var legs := [Vector3(-0.3, 0, -0.3), Vector3(0.3, 0, -0.3), Vector3(-0.3, 0, 0.3), Vector3(0.3, 0, 0.3)]
	var tops: Array[Vector3] = []
	for i in legs.size():
		var b: Vector3 = legs[i]
		var foot := b * 1.12 + Vector3(0, 0.0, 0)
		var top := b * 0.92 + Vector3(0.012 * (i % 2), py - 0.06, 0.0)
		tops.append(top)
		M.segment(parent, 0.04, log_m, foot, top + Vector3(0, 0.05, 0), 8)
		M.cyl(parent, 0.042, 0.042, 0.012, bark, top + Vector3(0, 0.055, 0), Vector3.ZERO, 8)
		M.box(parent, Vector3(0.1, 0.05, 0.09), M.mat(Color(0.55, 0.53, 0.5)), foot + Vector3(0, 0.025, 0), Vector3(0, 20.0 * i, 0))
	# Riostras en aspa en cada cara, atadas con cuerda
	var pairs := [[0, 1], [2, 3], [0, 2], [1, 3]]
	for pr: Array in pairs:
		var a0: Vector3 = legs[pr[0]] * 1.08
		var a1: Vector3 = legs[pr[1]] * 1.08
		var lo := 0.12
		var hi := py - 0.2
		var p0 := a0 + Vector3(0, lo, 0)
		var p1 := a1 * 0.96 + Vector3(0, hi, 0)
		var q0 := a1 + Vector3(0, lo, 0)
		var q1 := a0 * 0.96 + Vector3(0, hi, 0)
		M.segment(parent, 0.022, log_m, p0, p1, 6)
		M.segment(parent, 0.022, log_m, q0, q1, 6)
		var mid := (p0 + p1) * 0.5
		M.sphere(parent, 0.032, rope, mid, Vector3(1, 1.2, 1), 6)
		# travesaño horizontal bajo
		M.segment(parent, 0.02, log_m, a0 + Vector3(0, 0.3, 0), a1 + Vector3(0, 0.32, 0), 6)
	for top: Vector3 in tops:
		M.cyl(parent, 0.05, 0.05, 0.03, rope, top + Vector3(0, -0.04, 0), Vector3.ZERO, 8)

	# Vigas y tablones del suelo, mal alineados
	for s: float in [-1.0, 1.0]:
		M.box(parent, Vector3(0.7, 0.05, 0.06), plank_dark, Vector3(0, py - 0.07, 0.28 * s))
	for k in 6:
		var x := -0.29 + k * 0.116
		var m: Material = plank if k % 2 == 0 else plank_dark
		M.box(parent, Vector3(0.105, 0.035, 0.7 - (k % 3) * 0.03), m, Vector3(x, py - 0.02, (k % 2) * 0.012),
				Vector3((k % 3 - 1) * 1.5, (k % 2) * 3.0 - 1.5, 0))
	for p: Vector3 in [Vector3(-0.2, py, 0.3), Vector3(0.24, py, -0.31), Vector3(0.0, py, 0.3)]:
		M.sphere(parent, 0.008, iron, p, Vector3.ONE, 4)

	# Barandilla de troncos en tres lados (delante queda libre para los tubos)
	for top: Vector3 in tops:
		M.segment(parent, 0.025, log_m, top + Vector3(0, 0.03, 0), top + Vector3(0, 0.2, 0), 6)
	var rail_y := py + 0.13
	M.segment(parent, 0.018, log_m, tops[0] + Vector3(0, 0.13, 0), tops[2] + Vector3(0, 0.12, 0), 6)
	M.segment(parent, 0.018, log_m, tops[1] + Vector3(0, 0.12, 0), tops[3] + Vector3(0, 0.14, 0), 6)
	M.segment(parent, 0.018, log_m, tops[2] + Vector3(0, 0.12, 0), tops[3] + Vector3(0, 0.14, 0), 6)
	# rail roto colgando en la cara trasera
	M.segment(parent, 0.016, log_m, tops[0] + Vector3(0, 0.15, 0), tops[0] + Vector3(0.25, 0.04, -0.02), 6)
	M.segment(parent, 0.008, rope, Vector3(-0.27, rail_y, 0.27), Vector3(-0.27, rail_y - 0.06, 0.27), 4)

	# Escalera de mano apoyada en el lado +X
	var l0 := Vector3(0.47, 0.0, 0.1)
	var l1 := Vector3(0.33, py - 0.02, 0.1)
	for s: float in [-1.0, 1.0]:
		M.segment(parent, 0.014, log_m, l0 + Vector3(0, 0, 0.07 * s), l1 + Vector3(0, 0.1, 0.07 * s), 6)
	for k in 5:
		var u := (k + 0.6) / 6.0
		var rp := l0.lerp(l1, u)
		M.segment(parent, 0.009, log_m, rp + Vector3(0, 0, -0.07), rp + Vector3(0, 0, 0.07), 4)

	# Toldo de lona remendada sobre dos varas en la parte trasera
	for s: float in [-1.0, 1.0]:
		M.segment(parent, 0.014, log_m, Vector3(0.28 * s, py, -0.3), Vector3(0.28 * s, py + 0.48, -0.32), 6)
	var tarp := Node3D.new()
	tarp.position = Vector3(0, py + 0.46, -0.24)
	tarp.rotation_degrees.x = 28.0
	parent.add_child(tarp)
	M.box(tarp, Vector3(0.66, 0.02, 0.2), M.mat(Color(0.82, 0.74, 0.58)), Vector3.ZERO)
	M.box(tarp, Vector3(0.14, 0.024, 0.1), M.mat(Color(0.62, 0.44, 0.3)), Vector3(0.16, 0.0, 0.02))
	M.box(tarp, Vector3(0.1, 0.024, 0.08), M.mat(Color(0.5, 0.56, 0.4)), Vector3(-0.2, 0.0, -0.03))

	# Barriles de pólvora y un cubo de arena bajo la plataforma
	for p: Vector3 in [Vector3(-0.08, 0, -0.08), Vector3(0.1, 0, 0.02)]:
		M.cyl(parent, 0.07, 0.07, 0.17, plank_dark, p + Vector3(0, 0.085, 0), Vector3.ZERO, 10)
		for y: float in [0.03, 0.14]:
			M.cyl(parent, 0.073, 0.073, 0.015, rope, p + Vector3(0, y, 0), Vector3.ZERO, 10)
		M.cyl(parent, 0.04, 0.04, 0.01, M.mat(Color(0.15, 0.12, 0.1)), p + Vector3(0, 0.175, 0), Vector3.ZERO, 8)
	M.cyl(parent, 0.05, 0.04, 0.08, M.tex_mat("wood", 3.0, Color(0.7, 0.55, 0.4)), Vector3(-0.4, 0.04, 0.12), Vector3.ZERO, 8)
	M.cyl(parent, 0.044, 0.044, 0.01, M.mat(Color(0.86, 0.78, 0.55)), Vector3(-0.4, 0.075, 0.12), Vector3.ZERO, 8)
	# Caja de cohetes abierta a un lado y cohetes sueltos apoyados en un zanco
	M.box(parent, Vector3(0.16, 0.12, 0.13), plank, Vector3(-0.36, 0.06, -0.2), Vector3(0, 12, 0))
	for k in 3:
		rocket_prop(parent, Vector3(-0.4 + k * 0.04, 0.08, -0.2), Vector3(-6 + k * 5, 0, 8 - k * 7), 0.75, rope)
	for k in 2:
		rocket_prop(parent, Vector3(0.38, 0.0, -0.08 - k * 0.07), Vector3(0, 0, 14 + k * 4), 0.9, rope)
	# Farolillo de aceite colgado de un zanco
	var lp := tops[3] + Vector3(0.07, -0.2, 0.02)
	M.segment(parent, 0.005, iron, lp + Vector3(0, 0.05, 0), tops[3] + Vector3(0.03, -0.1, 0), 4)
	M.cyl(parent, 0.03, 0.035, 0.06, iron, lp, Vector3.ZERO, 6)
	M.sphere(parent, 0.025, M.mat(WARM, 1.6), lp, Vector3.ONE, 6)


# Etapa 1: planta baja de piedra y armazón de roble con herrajes
func _build_timber_tower(parent: Node3D) -> void:
	var stone := M.tex_mat("bricks", 2.2, Color(0.78, 0.74, 0.7))
	var stones := [M.mat(Color(0.6, 0.57, 0.54)), M.mat(Color(0.52, 0.5, 0.47)), M.mat(Color(0.66, 0.63, 0.6))]
	var oak := M.tex_mat("wood", 2.0, Color(0.72, 0.52, 0.36))
	var wood_dark := M.mat(WOOD_DARK)
	var iron := M.metal(IRON)
	var brass := M.metal(Color(0.78, 0.58, 0.3))
	var red := M.mat(RED)
	var glow := M.mat(WARM, 1.6)
	var rope := M.mat(ROPE)
	var py := _py

	# Base de piedra
	M.box(parent, Vector3(0.9, 0.08, 0.9), M.mat(Color(0.4, 0.37, 0.35)), Vector3(0, 0.04, 0))
	M.box(parent, Vector3(0.76, 0.3, 0.76), stone, Vector3(0, 0.23, 0))
	ArcherModel._stone_blocks(parent, 0.38, 0.15, 2, [], stones)

	# Armazón de roble con postes, vigas, tornapuntas y escuadras de hierro
	M.box(parent, Vector3(0.68, 0.52, 0.68), oak, Vector3(0, 0.64, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(parent, Vector3(0.09, 0.56, 0.09), wood_dark, Vector3(0.34 * sx, 0.64, 0.34 * sz))
			for y: float in [0.44, 0.84]:
				M.box(parent, Vector3(0.105, 0.05, 0.105), iron, Vector3(0.34 * sx, y, 0.34 * sz))
				M.sphere(parent, 0.012, brass, Vector3(0.34 * sx, y, 0.34 * sz + 0.055 * sz), Vector3.ONE, 6)
	for y: float in [0.4, 0.64, 0.88]:
		for s: float in [-1.0, 1.0]:
			M.box(parent, Vector3(0.72, 0.045, 0.045), wood_dark, Vector3(0, y, 0.35 * s))
			M.box(parent, Vector3(0.045, 0.045, 0.72), wood_dark, Vector3(0.35 * s, y, 0))
	# tornapuntas en aspa en los laterales
	for s: float in [-1.0, 1.0]:
		var f := _face_node(parent, Vector3(s, 0, 0), Vector3(0.352 * s, 0.64, 0))
		for k: float in [-1.0, 1.0]:
			M.box(f, Vector3(0.035, 0.52, 0.02), wood_dark, Vector3(0, 0, 0), Vector3(0, 0, 42.0 * k))

	# Un estandarte rojo con emblema dorado en el frente
	M.box(parent, Vector3(0.24, 0.024, 0.024), wood_dark, Vector3(0, 0.86, 0.385))
	M.box(parent, Vector3(0.18, 0.34, 0.02), red, Vector3(0, 0.685, 0.383))
	emblem(parent, Vector3(0, 0.72, 0.396), 1.0)
	for k: float in [-1.0, 1.0]:
		M.cyl(parent, 0.0, 0.045, 0.05, red, Vector3(0.045 * k, 0.495, 0.383), Vector3(180, 0, 0), 4)
	# Faroles cálidos colgando a los lados
	for s: float in [-1.0, 1.0]:
		var lp := Vector3(0.48 * s, 0.7, 0.05)
		M.box(parent, Vector3(0.16, 0.03, 0.03), wood_dark, Vector3(0.41 * s, 0.88, 0.05))
		M.segment(parent, 0.006, iron, lp + Vector3(0, 0.08, 0), lp + Vector3(0, 0.17, 0), 4)
		M.box(parent, Vector3(0.1, 0.13, 0.1), iron, lp)
		M.box(parent, Vector3(0.08, 0.11, 0.105), glow, lp)
		M.box(parent, Vector3(0.105, 0.11, 0.08), glow, lp)
		M.cyl(parent, 0.0, 0.065, 0.05, iron, lp + Vector3(0, 0.09, 0), Vector3.ZERO, 4)

	# Cajas de cohetes al pie de la torre (a los lados: el frente queda libre)
	for c: Array in [[Vector3(-0.4, 0.085, 0.26), 0.16], [Vector3(0.4, 0.085, -0.3), 0.16]]:
		var p: Vector3 = c[0]
		var w: float = c[1]
		M.box(parent, Vector3(0.14, 0.17, w), oak, p)
		M.box(parent, Vector3(0.145, 0.025, w + 0.01), iron, p + Vector3(0, 0.07, 0))
		M.box(parent, Vector3(0.145, 0.025, w + 0.01), iron, p + Vector3(0, -0.07, 0))
		for k in 3:
			rocket_prop(parent, p + Vector3(0.0, 0.06, (k - 1) * w * 0.3), Vector3(8 - k * 6, 0, -6 + k * 5), 0.8, brass)
	for k in 3:
		rocket_prop(parent, Vector3(0.43, 0.06, 0.0 + k * 0.06), Vector3(0, 0, 12), 1.0, brass)
	M.cyl(parent, 0.11, 0.11, 0.03, rope, Vector3(0.45, 0.17, 0.06), Vector3(0, 0, 12), 12)

	# Plataforma con barandilla de roble y postes con remate de hierro
	M.box(parent, Vector3(0.74, 0.06, 0.74), wood_dark, Vector3(0, py - 0.03, 0))
	for y: float in [0.05, 0.12]:
		for s: float in [-1.0, 1.0]:
			M.box(parent, Vector3(0.62, 0.03, 0.03), oak, Vector3(0, py + y, 0.32 * s))
			M.box(parent, Vector3(0.03, 0.03, 0.62), oak, Vector3(0.32 * s, py + y, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(parent, Vector3(0.06, 0.18, 0.06), wood_dark, Vector3(0.32 * sx, py + 0.08, 0.32 * sz))
			M.cyl(parent, 0.0, 0.045, 0.07, iron, Vector3(0.32 * sx, py + 0.2, 0.32 * sz), Vector3(0, 45, 0), 4)
	# Estacas con cuerda
	for p: Vector3 in [Vector3(-0.47, 0, -0.28), Vector3(0.47, 0, 0.3)]:
		M.cyl(parent, 0.03, 0.03, 0.24, wood_dark, p + Vector3(0, 0.12, 0), Vector3.ZERO, 6)
		M.cyl(parent, 0.0, 0.035, 0.06, iron, p + Vector3(0, 0.27, 0), Vector3.ZERO, 4)
		for y: float in [0.1, 0.16]:
			M.cyl(parent, 0.035, 0.035, 0.022, rope, p + Vector3(0, y, 0), Vector3.ZERO, 8)


# Etapas 2 y 3: bastión de sillería (3: piedra blanca, oro y resplandor alquímico)
func _build_bastion(parent: Node3D, master: bool) -> void:
	var stone_col := WHITE_STONE if master else Color(0.78, 0.75, 0.7)
	var stone := M.tex_mat("bricks", 2.4, stone_col)
	var stones: Array
	if master:
		stones = [M.mat(Color(0.78, 0.74, 0.66)), M.mat(Color(0.7, 0.66, 0.58)), M.mat(Color(0.74, 0.7, 0.6))]
	else:
		stones = [M.mat(Color(0.6, 0.57, 0.54)), M.mat(Color(0.52, 0.5, 0.47)), M.mat(Color(0.66, 0.63, 0.6))]
	var dark := M.mat(Color(0.7, 0.66, 0.6) if master else Color(0.42, 0.39, 0.37))
	var trim: Material = stones[1]
	if master:
		trim = M.metal(GOLD)
	var gold := M.metal(GOLD)
	var iron := M.metal(IRON)
	var oak := M.tex_mat("wood", 2.0, Color(0.72, 0.52, 0.36))
	var red := M.mat(RED)
	var banner_col: Color = ROYAL_BLUE if master else RED
	var banner := M.mat(banner_col)
	var roof := M.tex_mat("roof", 3.0, Color(0.62, 0.66, 0.76) if not master else Color(0.75, 0.85, 1.25))
	var flame := M.mat(WARM, 2.0)
	var alch := M.mat(ALCH_GLOW, 1.8)
	var py := _py
	var half := 0.37

	# Zócalo en talud y cuerpo de sillería
	M.box(parent, Vector3(0.9, 0.08, 0.9), dark, Vector3(0, 0.04, 0))
	M.cyl(parent, 0.5, 0.58, 0.14, stones[1], Vector3(0, 0.15, 0), Vector3(0, 45, 0), 4)
	var body_h := py - 0.22
	M.box(parent, Vector3(half * 2.0, body_h, half * 2.0), stone, Vector3(0, 0.08 + body_h * 0.5, 0))
	ArcherModel._stone_blocks(parent, half, 0.3, 4, [[0, 1]], stones)
	# esquinas reforzadas con sillares alternos
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var k := 0
			var y := 0.26
			while y < py - 0.2:
				var big := k % 2 == 0
				var sz3 := Vector3(0.14 if big else 0.1, 0.1, 0.1 if big else 0.14)
				M.box(parent, sz3, stones[k % 3], Vector3((half - 0.02) * sx, y, (half - 0.02) * sz))
				y += 0.12
				k += 1
	# impostas
	for y: float in [0.22, py * 0.62]:
		M.box(parent, Vector3(half * 2.0 + 0.04, 0.035, half * 2.0 + 0.04), trim, Vector3(0, y, 0))

	# Puerta de roble en arco con herrajes (+Z)
	var door := Vector3(0, 0.08, half + 0.005)
	M.box(parent, Vector3(0.24, 0.26, 0.04), dark, door + Vector3(0, 0.13, 0))
	M.cyl(parent, 0.12, 0.12, 0.04, dark, door + Vector3(0, 0.26, 0), Vector3(90, 0, 0), 16)
	M.box(parent, Vector3(0.18, 0.24, 0.03), oak, door + Vector3(0, 0.12, 0.012))
	M.cyl(parent, 0.09, 0.09, 0.03, oak, door + Vector3(0, 0.24, 0.012), Vector3(90, 0, 0), 14)
	for y: float in [0.07, 0.19]:
		M.box(parent, Vector3(0.16, 0.018, 0.01), gold if master else iron, door + Vector3(0, y, 0.03))
	# Saeteras
	for n: Vector3 in FACES:
		if n.z > 0.5:
			continue
		var f := _face_node(parent, n, n * (half + 0.004) + Vector3(0, py * 0.78, 0))
		M.box(f, Vector3(0.07, 0.17, 0.02), dark)
		M.box(f, Vector3(0.025, 0.13, 0.02), M.mat(Color(0.08, 0.06, 0.05)) if not master else alch, Vector3(0, 0, 0.006))

	# Matacanes: ménsulas bajo el parapeto voladizo
	var mach_y := py - 0.13
	for n: Vector3 in FACES:
		var tg := Vector3(n.z, 0, n.x)
		for k in 5:
			var o := -0.3 + k * 0.15
			M.box(parent, Vector3(0.05, 0.09, 0.05), stones[k % 3], n * (half + 0.02) + tg * o + Vector3(0, mach_y, 0))
	M.box(parent, Vector3(0.88, 0.1, 0.88), stone, Vector3(0, py - 0.05, 0))
	M.box(parent, Vector3(0.9, 0.025, 0.9), trim, Vector3(0, py - 0.1, 0))
	# Almenas con caperuza
	for n: Vector3 in FACES:
		var tg := Vector3(n.z, 0, n.x)
		for k in 4:
			var o := -0.33 + k * 0.22
			var size := Vector3(0.1, 0.11, 0.06) if absf(n.z) > 0.5 else Vector3(0.06, 0.11, 0.1)
			var mp := n * 0.41 + tg * o + Vector3(0, py + 0.055, 0)
			M.box(parent, size, stone, mp)
			M.box(parent, size * Vector3(1.15, 0.2, 1.15), trim, mp + Vector3(0, 0.06, 0))

	# Estandartes heráldicos colgando del parapeto (frente) con emblema dorado
	for s: float in [-1.0, 1.0]:
		var bx := 0.17 * s
		var top := py - 0.16
		M.box(parent, Vector3(0.16, 0.022, 0.022), gold if master else iron, Vector3(bx, top, half + 0.03))
		M.box(parent, Vector3(0.14, 0.36, 0.016), gold, Vector3(bx, top - 0.18, half + 0.02))
		M.box(parent, Vector3(0.12, 0.35, 0.02), banner, Vector3(bx, top - 0.175, half + 0.024))
		emblem(parent, Vector3(bx, top - 0.13, half + 0.038), 0.9)
		for k: float in [-1.0, 1.0]:
			M.cyl(parent, 0.0, 0.035, 0.05, banner, Vector3(bx + 0.03 * k, top - 0.375, half + 0.024), Vector3(180, 0, 0), 4)
	# Escudos en los laterales (rojo con cheurón dorado)
	for s: float in [-1.0, 1.0]:
		var f := _face_node(parent, Vector3(s, 0, 0), Vector3((half + 0.012) * s, py * 0.5, 0.12))
		M.box(f, Vector3(0.15, 0.12, 0.025), gold)
		M.box(f, Vector3(0.13, 0.11, 0.03), M.mat(banner_col), Vector3(0, 0.002, 0))
		M.cyl(f, 0.0, 0.075, 0.09, gold, Vector3(0, -0.1, 0), Vector3(180, 45, 0), 4)
		M.cyl(f, 0.0, 0.064, 0.08, M.mat(banner_col), Vector3(0, -0.095, 0.004), Vector3(180, 45, 0), 4)
		for k: float in [-1.0, 1.0]:
			M.box(f, Vector3(0.022, 0.09, 0.012), gold, Vector3(0.03 * k, -0.02, 0.02), Vector3(0, 0, 50.0 * k))

	# Antorchas de pared a los lados de la puerta
	for s: float in [-1.0, 1.0]:
		var tp := Vector3(0.23 * s, 0.5, half + 0.03)
		M.box(parent, Vector3(0.04, 0.05, 0.03), iron, tp + Vector3(0, -0.06, -0.01))
		M.segment(parent, 0.014, M.mat(WOOD_DARK), tp + Vector3(0, -0.07, 0.0), tp + Vector3(0, 0.05, 0.04), 6)
		M.cyl(parent, 0.026, 0.02, 0.03, iron, tp + Vector3(0, 0.05, 0.04), Vector3.ZERO, 8)
		M.cyl(parent, 0.0, 0.026, 0.08, flame, tp + Vector3(0, 0.1, 0.04), Vector3.ZERO, 6)
		M.sphere(parent, 0.016, M.mat(Color(1.0, 0.95, 0.6), 2.4), tp + Vector3(0, 0.08, 0.04), Vector3.ONE, 6)

	# Garitas con tejado cónico en las esquinas traseras
	for sx: float in [-1.0, 1.0]:
		var gp := Vector3(0.37 * sx, 0, -0.37)
		var r := 0.1 if master else 0.09
		var base_y := py - 0.36
		var top_y := py + (0.3 if master else 0.18)
		M.cyl(parent, r, 0.02, 0.18, stone, gp + Vector3(0, base_y - 0.09, 0), Vector3.ZERO, 12)
		M.cyl(parent, r, r, top_y - base_y, stone, gp + Vector3(0, (base_y + top_y) * 0.5, 0), Vector3.ZERO, 12)
		M.cyl(parent, r + 0.015, r + 0.015, 0.025, trim, gp + Vector3(0, top_y, 0), Vector3.ZERO, 12)
		var roof_h := 0.38 if master else 0.3
		M.cyl(parent, 0.0, r + 0.035, roof_h, roof, gp + Vector3(0, top_y + roof_h * 0.5, 0), Vector3.ZERO, 12)
		var f := _face_node(parent, Vector3(sx, 0, 0.6).normalized(), gp + Vector3(sx, 0, 0.6).normalized() * r + Vector3(0, top_y - 0.1, 0))
		M.box(f, Vector3(0.03, 0.08, 0.02), alch if master else M.mat(Color(0.08, 0.06, 0.05)))
		var fin_y := top_y + roof_h
		if master:
			M.sphere(parent, 0.03, gold, gp + Vector3(0, fin_y, 0), Vector3.ONE, 8)
			M.cyl(parent, 0.0, 0.016, 0.12, gold, gp + Vector3(0, fin_y + 0.08, 0), Vector3.ZERO, 6)
		else:
			M.sphere(parent, 0.018, iron, gp + Vector3(0, fin_y, 0), Vector3.ONE, 6)

	# Cajas de cohetes y munición al pie
	for c: Array in [[Vector3(-0.43, 0.075, 0.2), 0.15], [Vector3(0.43, 0.075, 0.14), 0.15]]:
		var p: Vector3 = c[0]
		var w: float = c[1]
		M.box(parent, Vector3(0.1, 0.15, w), oak, p)
		M.box(parent, Vector3(0.105, 0.022, w + 0.01), gold if master else iron, p + Vector3(0, 0.06, 0))
		for k in 2:
			rocket_prop(parent, p + Vector3(0.0, 0.05, (k - 0.5) * w * 0.4), Vector3(6 - k * 12, 0, 0), 0.8)

	if not master:
		return
	# --- Maestría: molduras doradas, pináculos, runas y círculo alquímico ---
	# Pináculos dorados sobre las almenas delanteras
	for sx: float in [-1.0, 1.0]:
		var pp := Vector3(0.41 * sx, py, 0.41)
		M.box(parent, Vector3(0.1, 0.16, 0.1), stone, pp + Vector3(0, 0.08, 0))
		M.box(parent, Vector3(0.12, 0.025, 0.12), gold, pp + Vector3(0, 0.17, 0))
		M.cyl(parent, 0.0, 0.055, 0.2, M.tex_mat("roof", 3.0, Color(0.75, 0.85, 1.25)), pp + Vector3(0, 0.28, 0), Vector3(0, 45, 0), 4)
		M.sphere(parent, 0.022, gold, pp + Vector3(0, 0.39, 0), Vector3.ONE, 8)
	# Bandas de runas alquímicas brillantes en el fuste
	for n: Vector3 in FACES:
		var tg := Vector3(n.z, 0, n.x)
		for k in 5:
			var o := -0.26 + k * 0.13
			if n.z > 0.5 and absf(o) < 0.15:
				continue
			var f := _face_node(parent, n, n * (half + 0.006) + tg * o + Vector3(0, 0.36, 0))
			var shape := k % 3
			if shape == 0:
				M.cyl(f, 0.025, 0.025, 0.01, alch, Vector3.ZERO, Vector3(90, 0, 0), 3)
			elif shape == 1:
				M.box(f, Vector3(0.035, 0.035, 0.01), alch, Vector3.ZERO, Vector3(0, 0, 45))
			else:
				M.box(f, Vector3(0.01, 0.05, 0.01), alch)
				M.box(f, Vector3(0.04, 0.01, 0.01), alch, Vector3(0, 0.01, 0))
	# Círculo alquímico dorado sobre la puerta
	var cc := Vector3(0, py * 0.62 + 0.13, half + 0.012)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.07
	ring.outer_radius = 0.085
	ring.rings = 18
	ring.ring_segments = 5
	M.add(parent, ring, gold, cc, Vector3(90, 0, 0))
	M.cyl(parent, 0.07, 0.07, 0.01, M.mat(Color(0.25, 0.12, 0.08)), cc, Vector3(90, 0, 0), 18)
	M.cyl(parent, 0.055, 0.055, 0.016, alch, cc + Vector3(0, 0, 0.002), Vector3(90, 0, 0), 3)
	M.cyl(parent, 0.03, 0.03, 0.02, M.mat(Color(1.0, 0.9, 0.55), 2.2), cc + Vector3(0, 0, 0.004), Vector3(90, 0, 0), 14)
	# brasero alquímico en las almenas traseras centrales
	var bp := Vector3(0, py + 0.12, -0.41)
	M.cyl(parent, 0.06, 0.035, 0.05, gold, bp, Vector3.ZERO, 10)
	M.cyl(parent, 0.0, 0.045, 0.12, alch, bp + Vector3(0, 0.08, 0), Vector3.ZERO, 6)


# Gallardetes que ondean (sólo etapas 2 y 3)
func _build_pennants() -> void:
	var master := _tier == 3
	var pole_m := M.metal(GOLD) if master else M.mat(WOOD_DARK)
	var cols: Array = [RED, ROYAL_BLUE] if master else [RED, RED_DARK]
	var tops: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		var r_top := _py + (0.3 + 0.38 + 0.12 if master else 0.18 + 0.3)
		tops.append(Vector3(0.37 * sx, r_top, -0.37))
	for i in tops.size():
		var tp: Vector3 = tops[i]
		M.segment(self, 0.007, pole_m, tp, tp + Vector3(0, 0.2, 0), 4)
		var pn := Node3D.new()
		pn.position = tp + Vector3(0, 0.18, 0)
		add_child(pn)
		var col: Color = cols[i % cols.size()]
		var flag := M.cyl(pn, 0.0, 0.05, 0.24 if master else 0.18, M.mat(col), Vector3(0.12 if master else 0.09, -0.02, 0), Vector3(0, 0, -90), 3)
		flag.scale = Vector3(1, 1, 0.25)
		if master:
			M.sphere(pn, 0.012, M.metal(GOLD), Vector3(0, 0.03, 0), Vector3.ONE, 6)
		_pennants.append(pn)


# Aura de Maestría: anillo dorado que gira bajo la plataforma y chispas que suben
func _build_aura() -> void:
	_aura_ring = Node3D.new()
	_aura_ring.position = Vector3(0, _py + 0.02, 0)
	add_child(_aura_ring)
	var glow := M.mat(Color(1.0, 0.78, 0.35), 2.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.5
	ring.outer_radius = 0.52
	ring.rings = 32
	ring.ring_segments = 4
	M.add(_aura_ring, ring, glow)
	for i in 8:
		var a := TAU * i / 8.0
		M.box(_aura_ring, Vector3(0.05, 0.05, 0.012), glow, Vector3(cos(a), 0, sin(a)) * 0.51, Vector3(0, 90.0 - rad_to_deg(a), 45))
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.6
	p.position = Vector3(0, _py * 0.55, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.45, _py * 0.45, 0.45)
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0, 0.15, 0)
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.18
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.02
	mesh.height = 0.04
	mesh.radial_segments = 4
	mesh.rings = 2
	mesh.material = M.mat(Color(1.0, 0.8, 0.35), 2.4)
	p.mesh = mesh
	add_child(p)


# --- Lanzador de 6 tubos (animado: retrocede al disparar) ---

func _build_launcher() -> void:
	var tube_m: Material
	var band: Material
	var frame: Material
	var mouth: Material = M.mat(Color(0.08, 0.06, 0.05))
	match _tier:
		0:
			tube_m = M.tex_mat("wood", 3.0, Color(0.9, 0.78, 0.55))
			band = M.mat(ROPE)
			frame = M.tex_mat("wood", 2.0, Color(0.7, 0.55, 0.4))
		1:
			tube_m = M.tex_mat("wood", 2.0, Color(0.85, 0.5, 0.4))
			band = M.metal(Color(0.78, 0.58, 0.3))
			frame = M.mat(WOOD_DARK)
		2:
			tube_m = M.metal(Color(0.34, 0.33, 0.36))
			band = M.metal(GOLD)
			frame = M.mat(WOOD_DARK)
		_:
			tube_m = M.metal(Color(0.85, 0.55, 0.28))
			band = M.metal(GOLD)
			frame = M.metal(Color(0.92, 0.9, 0.86))
			mouth = M.mat(ALCH_GLOW, 2.0)
	var rack := Node3D.new()
	rack.position = Vector3(0.12, 0, 0.0)
	cat_pivot.add_child(rack)
	# soporte
	M.box(rack, Vector3(0.3, 0.06, 0.26), frame, Vector3(0, 0.05, 0.02))
	for s: float in [-1.0, 1.0]:
		var side := M.box(rack, Vector3(0.025, 0.3, 0.06), frame, Vector3(0.15 * s, 0.17, 0.02))
		side.rotation_degrees = Vector3(TUBE_PITCH + 90.0, 0, 0)
		M.sphere(rack, 0.02, band, Vector3(0.155 * s, 0.2, -0.02), Vector3.ONE, 8)
	if _tier == 0:
		# tubos de caña atados en haz: cuerda que los rodea
		M.box(rack, Vector3(0.32, 0.03, 0.03), frame, Vector3(0, 0.1, 0.12), Vector3(0, 0, 4))
	if _tier == 3:
		# anillo de runas brillantes alrededor del haz
		M.box(rack, Vector3(0.26, 0.02, 0.02), M.mat(ALCH_GLOW, 1.8), Vector3(0, 0.08, 0.15))
	var k := 0
	for row in 2:
		for col in 3:
			var tube := Node3D.new()
			var center := Vector3(-0.09 + col * 0.09, 0.15 + row * 0.085, 0.04 + row * 0.03)
			tube.position = center
			tube.rotation_degrees = Vector3(TUBE_PITCH, 0, 0)
			rack.add_child(tube)
			var r := 0.036 if _tier == 0 else 0.04
			M.cyl(tube, r, r, TUBE_LEN, tube_m, Vector3.ZERO, Vector3.ZERO, 12)
			var bands: Array = [-0.12, 0.1] if _tier == 0 else [-0.15, 0.0, 0.17]
			for y: float in bands:
				M.cyl(tube, r + 0.005, r + 0.005, 0.025 if _tier > 0 else 0.018, band, Vector3(0, y, 0), Vector3.ZERO, 12)
			if _tier >= 2:
				M.cyl(tube, 0.048, 0.044, 0.03, band, Vector3(0, TUBE_LEN / 2.0 - 0.01, 0), Vector3.ZERO, 12)
			M.cyl(tube, r - 0.008, r - 0.008, 0.012, mouth, Vector3(0, TUBE_LEN / 2.0, 0), Vector3.ZERO, 12)
			# cohete cargado asomando por la boca
			var loaded := Node3D.new()
			loaded.position = Vector3(0, TUBE_LEN / 2.0 - 0.02, 0)
			tube.add_child(loaded)
			M.cyl(loaded, 0.0, 0.034, 0.08, M.mat(RED), Vector3(0, 0.04, 0), Vector3.ZERO, 10)
			M.cyl(loaded, 0.035, 0.035, 0.02, band, Vector3(0, 0.0, 0), Vector3.ZERO, 10)
			_tubes.append(tube)
			_loaded.append(loaded)
			_tube_rest.append(center)
			k += 1


# --- Artificiero ---

func _build_cat_body(c: Node3D) -> void:
	match _tier:
		0: _dress_peasant(c)
		1: _dress_gambeson(c)
		2: _dress_mail(c)
		_: _dress_ornate(c)
	# brazos: el derecho en alto con la bengala, el izquierdo sujeta la mecha
	var sleeve: Material
	var cuff: Material
	match _tier:
		0:
			sleeve = M.mat(LINEN)
			cuff = M.mat(Color(0.45, 0.34, 0.22))
		1:
			sleeve = M.mat(RED)
			cuff = M.metal(GOLD)
		2:
			sleeve = M.metal(Color(0.4, 0.42, 0.46))
			cuff = M.mat(Color(0.42, 0.27, 0.15))
		_:
			sleeve = M.metal(Color(0.72, 0.75, 0.8))
			cuff = M.metal(GOLD)
	Cat.arm(c, Cat.R_SHOULDER, Vector3(0.17, 0.42, -0.1), sleeve, cuff)
	Cat.arm(c, Cat.L_SHOULDER, Vector3(-0.08, 0.2, -0.17), sleeve, cuff)
	M.segment(c, 0.008, M.mat(Color(0.75, 0.62, 0.42)), Vector3(-0.08, 0.2, -0.17), Vector3(0.1, 0.06, -0.12), 4)
	M.segment(c, 0.012, M.mat(Color(0.4, 0.25, 0.12)), Vector3(0.17, 0.42, -0.1), Vector3(0.19, 0.62, -0.14), 6)


# Gafas de bronce sobre el gorro
static func _goggles(h: Node3D, frame: Material, lens: Material) -> void:
	for s2: float in [-1.0, 1.0]:
		M.cyl(h, 0.032, 0.032, 0.02, frame, Vector3(0.05 * s2, 0.085, -0.13), Vector3(70, 0, 0), 12)
		M.cyl(h, 0.024, 0.024, 0.022, lens, Vector3(0.05 * s2, 0.085, -0.132), Vector3(70, 0, 0), 12)


# Etapa 0: túnica de lino remendada, cinto de cuerda y gorro de tela
func _dress_peasant(c: Node3D) -> void:
	var linen := M.mat(LINEN)
	var brown := M.mat(Color(0.45, 0.34, 0.22))
	var rope := M.mat(ROPE)
	Cat.body(c, linen, brown)
	M.sphere(c, 0.13, linen, Vector3(0, 0.19, -0.02), Vector3(1.1, 1.1, 0.9), 14)
	M.box(c, Vector3(0.06, 0.06, 0.02), M.mat(Color(0.5, 0.56, 0.4)), Vector3(0.06, 0.2, -0.14), Vector3(0, 0, 12))
	M.cyl(c, 0.152, 0.152, 0.022, rope, Vector3(0, 0.1, 0), Vector3.ZERO, 16)
	M.segment(c, 0.01, rope, Vector3(0.05, 0.1, -0.15), Vector3(0.07, 0.03, -0.15), 4)
	M.sphere(c, 0.035, brown, Vector3(-0.12, 0.07, -0.1), Vector3(1, 1.2, 1), 8)   # zurrón
	var h := Cat.head(c, true, true)
	M.sphere(h, 0.145, brown, Vector3(0.02, 0.07, 0.03), Vector3(1.05, 0.6, 1.05), 12)
	M.sphere(h, 0.05, brown, Vector3(0.1, 0.12, 0.05), Vector3.ONE, 8)
	# pañuelo al cuello
	M.cyl(c, 0.09, 0.11, 0.04, M.mat(Color(0.7, 0.3, 0.2)), Vector3(0, 0.33, 0), Vector3.ZERO, 12)


# Etapa 1: chaqueta acolchada roja, gorro de cuero con gafas y bufanda
func _dress_gambeson(c: Node3D) -> void:
	var red := M.mat(RED)
	var dark := M.mat(Color(0.22, 0.16, 0.14))
	var gold := M.metal(GOLD)
	Cat.body(c, dark, gold)
	M.sphere(c, 0.13, red, Vector3(0, 0.19, -0.02), Vector3(1.1, 1.1, 0.9), 14)
	for y: float in [0.13, 0.19, 0.25]:
		M.box(c, Vector3(0.2, 0.01, 0.02), M.mat(RED_DARK), Vector3(0, y, -0.13))
	M.box(c, Vector3(0.04, 0.22, 0.03), gold, Vector3(0, 0.17, -0.135))
	M.cyl(c, 0.152, 0.152, 0.03, M.mat(Color(0.45, 0.3, 0.15)), Vector3(0, 0.1, 0), Vector3.ZERO, 16)
	M.cyl(c, 0.035, 0.035, 0.02, gold, Vector3(0, 0.1, -0.15), Vector3(90, 0, 0), 14)
	for s: float in [-1.0, 1.0]:
		M.sphere(c, 0.03, M.mat(Color(0.45, 0.3, 0.15)), Vector3(0.12 * s, 0.08, -0.1), Vector3.ONE, 8)
	var h := Cat.head(c)
	M.sphere(h, 0.15, M.mat(Color(0.4, 0.26, 0.14)), Vector3(0, 0.05, 0.02), Vector3(1.0, 0.75, 1.0), 14)
	_goggles(h, M.metal(Color(0.72, 0.5, 0.25)), M.mat(Color(0.6, 0.85, 1.0), 0.6))
	var scarf := TorusMesh.new()
	scarf.inner_radius = 0.085
	scarf.outer_radius = 0.13
	M.add(c, scarf, red, Vector3(0, 0.335, 0), Vector3(8, 0, 0))
	M.box(c, Vector3(0.07, 0.2, 0.02), red, Vector3(-0.08, 0.24, 0.14), Vector3(25, 0, 15))


# Etapa 2: cota de malla, tabardo heráldico, hombreras y capacete con gafas
func _dress_mail(c: Node3D) -> void:
	var mail := M.metal(Color(0.4, 0.42, 0.46))
	var steel := M.metal(Color(0.5, 0.52, 0.57))
	var red := M.mat(RED)
	var gold := M.metal(GOLD)
	var leather := M.mat(Color(0.42, 0.27, 0.15))
	Cat.body(c, mail, leather)
	M.sphere(c, 0.13, mail, Vector3(0, 0.19, -0.02), Vector3(1.1, 1.1, 0.9), 14)
	# tabardo rojo con emblema
	M.box(c, Vector3(0.17, 0.28, 0.025), red, Vector3(0, 0.15, -0.13), Vector3(-6, 0, 0))
	M.box(c, Vector3(0.17, 0.28, 0.025), red, Vector3(0, 0.15, 0.12), Vector3(6, 0, 0))
	M.box(c, Vector3(0.18, 0.02, 0.03), gold, Vector3(0, 0.02, -0.12))
	var em := Node3D.new()
	em.position = Vector3(0, 0.19, -0.148)
	em.rotation.y = PI
	c.add_child(em)
	emblem(em, Vector3.ZERO, 0.8)
	M.cyl(c, 0.153, 0.153, 0.03, leather, Vector3(0, 0.1, 0), Vector3.ZERO, 16)
	M.box(c, Vector3(0.035, 0.03, 0.015), gold, Vector3(0, 0.1, -0.155))
	for s: float in [-1.0, 1.0]:
		M.sphere(c, 0.075, steel, Vector3(0.14 * s, 0.29, 0), Vector3(1, 0.65, 1), 10)
	var h := Cat.head(c, false, false)
	# capacete de acero con ala ancha y gafas
	M.sphere(h, 0.15, steel, Vector3(0, 0.05, 0.01), Vector3(1.0, 0.8, 1.0), 14)
	var brim := TorusMesh.new()
	brim.inner_radius = 0.12
	brim.outer_radius = 0.2
	brim.rings = 16
	brim.ring_segments = 4
	M.add(h, brim, steel, Vector3(0, 0.04, 0.01), Vector3.ZERO, Vector3(1, 0.3, 1))
	M.box(h, Vector3(0.02, 0.03, 0.2), gold, Vector3(0, 0.15, 0.02))
	_goggles(h, M.metal(Color(0.72, 0.5, 0.25)), M.mat(Color(0.6, 0.85, 1.0), 0.6))


# Etapa 3: armadura blanca ornamentada con oro, capa y yelmo con penacho
func _dress_ornate(c: Node3D) -> void:
	var plate := M.metal(Color(0.72, 0.75, 0.8))
	var gold := M.metal(GOLD)
	var cape := M.mat(ROYAL_BLUE)
	var red := M.mat(RED)
	Cat.body(c, plate, gold)
	M.sphere(c, 0.135, plate, Vector3(0, 0.19, -0.02), Vector3(1.1, 1.1, 0.9), 14)
	# peto con filetes dorados y sol alquímico
	M.box(c, Vector3(0.025, 0.22, 0.03), gold, Vector3(0, 0.18, -0.14))
	for y: float in [0.1, 0.26]:
		M.box(c, Vector3(0.22, 0.02, 0.03), gold, Vector3(0, y, -0.12))
	M.sphere(c, 0.03, M.mat(ALCH_GLOW, 2.0), Vector3(0, 0.2, -0.15), Vector3(1, 1, 0.5), 10)
	# faldar de placas
	M.cyl(c, 0.14, 0.19, 0.1, plate, Vector3(0, 0.05, 0), Vector3.ZERO, 16)
	M.cyl(c, 0.195, 0.195, 0.02, gold, Vector3(0, 0.005, 0), Vector3.ZERO, 16)
	# hombreras grandes con ribete dorado
	for s: float in [-1.0, 1.0]:
		M.sphere(c, 0.085, plate, Vector3(0.145 * s, 0.29, 0), Vector3(1, 0.65, 1), 12)
		M.cyl(c, 0.075, 0.075, 0.015, gold, Vector3(0.15 * s, 0.26, 0), Vector3(0, 0, 18.0 * s), 12)
	# capa azul real con borde dorado
	M.box(c, Vector3(0.24, 0.34, 0.025), cape, Vector3(0, 0.15, 0.15), Vector3(-16, 0, 0))
	M.box(c, Vector3(0.25, 0.025, 0.03), gold, Vector3(0, -0.01, 0.2), Vector3(-16, 0, 0))
	for s: float in [-1.0, 1.0]:
		M.sphere(c, 0.022, gold, Vector3(0.11 * s, 0.33, 0.08), Vector3.ONE, 8)
	var h := Cat.head(c, false, false)
	# yelmo con cresta dorada, penacho rojo y gafas incandescentes
	M.sphere(h, 0.152, plate, Vector3(0, 0.05, 0.01), Vector3(1.0, 0.85, 1.0), 14)
	M.box(h, Vector3(0.03, 0.06, 0.24), gold, Vector3(0, 0.17, 0.02))
	var plume := Node3D.new()
	plume.position = Vector3(0, 0.2, 0.08)
	plume.rotation.x = 0.6
	h.add_child(plume)
	M.sphere(plume, 0.05, red, Vector3(0, 0.06, 0), Vector3(0.5, 1.6, 0.8), 10)
	_goggles(h, gold, M.mat(ALCH_GLOW, 1.6))


# Chispa de la bengala (animada)
func _build_sparkler(cat: Node3D) -> void:
	_spark = Node3D.new()
	_spark.position = Vector3(0.19, 0.64, -0.145)
	cat.add_child(_spark)
	M.sphere(_spark, 0.035, M.mat(Color(1.0, 0.9, 0.5), 2.5), Vector3.ZERO, Vector3.ONE, 10)
	for i in 6:
		var ray := Node3D.new()
		ray.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		_spark.add_child(ray)
		M.cyl(ray, 0.0, 0.008, 0.09, M.mat(Color(1.0, 0.8, 0.35), 2.0), Vector3(0, 0.05, 0), Vector3.ZERO, 4)
	var sparks := CPUParticles3D.new()
	sparks.amount = 10
	sparks.lifetime = 0.4
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.gravity = Vector3(0, -2.0, 0)
	sparks.initial_velocity_min = 0.3
	sparks.initial_velocity_max = 0.7
	var mesh := SphereMesh.new()
	mesh.radius = 0.008
	mesh.height = 0.016
	mesh.radial_segments = 4
	mesh.rings = 2
	mesh.material = M.mat(Color(1.0, 0.8, 0.35), 2.0)
	sparks.mesh = mesh
	_spark.add_child(sparks)
