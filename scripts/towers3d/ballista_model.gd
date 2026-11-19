extends Node3D
## Modelo 3D de la torre "Balista Real" (id ballista): torre cuadrada de sillares con almenas,
## matacanes, puerta claveteada y estandartes reales azules con león rampante y cruz dorados.
## Arriba, una gran balista sobre un montaje giratorio apuntada por un soldado humano con
## capacete de ala ancha (chapel de hierro) y sobreveste azul con cruz dorada.
## La balista y el soldado miran hacia -Z dentro de cat_pivot.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const Arch := preload("res://scripts/towers3d/archer_model.gd")

const STONE_DARK := Color(0.4, 0.39, 0.37)
const WOOD_DARK := Color(0.32, 0.2, 0.11)
const IRON := Color(0.27, 0.27, 0.3)
const STEEL := Color(0.46, 0.48, 0.53)
const ROYAL := Color(0.14, 0.24, 0.62)
const ROYAL_DARK := Color(0.09, 0.15, 0.4)
const GOLD := Color(0.97, 0.76, 0.26)
const ROPE := Color(0.84, 0.75, 0.56)
const MAIL := Color(0.42, 0.44, 0.48)

const PLATFORM_Y := 1.0
const PLAT_BY_TIER := [0.74, 0.88, 1.0, 1.3]
const MARBLE := Color(0.97, 0.95, 0.9)
# Balista (coordenadas de _gun)
const GUN_POS := Vector3(0, 0.28, -0.04)
const ARM_ROOT := Vector3(0.08, 0.0, -0.3)
const ARM_LEN := 0.31
const NOCK_REST := -0.3
const NOCK_DRAWN := 0.06
const BOLT_LEN := 0.52
const GRIP := Vector3(0.085, 0.0, 0.2)
const SOLDIER_POS := Vector3(0, 0, 0.27)

var cat_pivot: Node3D
var _gun: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _str_l: MeshInstance3D
var _str_r: MeshInstance3D
var _bolt: Node3D
var _soldier: Node3D
var _sl_arm_l: MeshInstance3D
var _sl_arm_r: MeshInstance3D
var _hand_l: MeshInstance3D
var _hand_r: MeshInstance3D
var _pennant: Node3D
var tier := 0
var _flames: Array[Node3D] = []
var _pennants: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _floaters: Array[Node3D] = []


func _init(level := 0) -> void:
	tier = Arch.tier_of(level)
	M.add_baked(self, M.baked("ballista_tower_t%d" % tier, _build_tower))
	if tier == 2:
		_build_pennant()
	_build_tier_fx()
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, PLAT_BY_TIER[tier], 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("ballista_mount_t%d" % tier, _build_mount))
	_gun = Node3D.new()
	_gun.position = GUN_POS
	cat_pivot.add_child(_gun)
	M.add_baked(_gun, M.baked("ballista_gun_t%d" % tier, _build_gun))
	_soldier = Node3D.new()
	_soldier.position = SOLDIER_POS
	cat_pivot.add_child(_soldier)
	M.add_baked(_soldier, M.baked("ballista_soldier_t%d" % tier, _build_soldier))
	_build_moving_parts()
	animate({"t": 0.0, "charge": 0.0, "fire": 0.0, "has_target": false})


## s = {t, charge (0..1), fire (1 -> 0), has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = s.get("charge", 0.0)
	var fire: float = s.get("fire", 0.0)
	var has_target: bool = s.get("has_target", false)
	var pull := charge if has_target else minf(charge, 0.3)
	# Retroceso: la balista da un golpe hacia atrás y el morro sube un poco
	_gun.position = GUN_POS + Vector3(0, 0, fire * 0.05)
	_gun.rotation.x = fire * 0.12 + (0.0 if has_target else sin(t * 1.2) * 0.03)
	# Brazos: se doblan hacia atrás al tensar; al soltar vibran
	var bend := lerpf(0.15, 0.55, pull)
	if fire > 0.0:
		bend = 0.1 + sin(t * 70.0) * 0.08 * fire
	_arm_r.rotation.y = -bend
	_arm_l.rotation.y = bend
	var tip_r := _arm_r.transform * Vector3(ARM_LEN, 0, 0)
	var tip_l := _arm_l.transform * Vector3(-ARM_LEN, 0, 0)
	var nz := lerpf(NOCK_REST, NOCK_DRAWN, pull)
	if fire > 0.0:
		nz = NOCK_REST - 0.03 + sin(t * 70.0) * 0.03 * fire
	var nock := Vector3(0, 0.045, nz)
	M.orient_segment(_str_r, nock, tip_r)
	M.orient_segment(_str_l, nock, tip_l)
	_bolt.visible = fire <= 0.05 and pull > 0.5
	_bolt.position = nock
	# Manos del soldado en las empuñaduras traseras
	var sxf := _soldier.transform
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var hand := _gun.transform * (GRIP * Vector3(side, 1, 1))
		var hand_node := _hand_l if k == 0 else _hand_r
		var arm_node := _sl_arm_l if k == 0 else _sl_arm_r
		hand_node.position = hand
		M.orient_segment(arm_node, sxf * (Human.L_SHOULDER if k == 0 else Human.R_SHOULDER), hand)
	_soldier.position = SOLDIER_POS + Vector3(0, absf(sin(t * 1.6)) * 0.005, fire * 0.03)
	# Banderola
	if _pennant != null:
		_pennant.rotation.y = 0.6 + sin(t * 2.1) * 0.25
		_pennant.rotation.x = sin(t * 3.3) * 0.05
	Arch.animate_fx(t, _flames, _pennants, _spinners, _floaters)


## Punta del virote cargado (posición global)
func muzzle_global() -> Vector3:
	return _gun.to_global(Vector3(0, 0.045, NOCK_DRAWN - BOLT_LEN - 0.04))


# --- Heráldica ---

# León rampante esquemático (mirando a +Z del nodo)
static func lion(p: Node3D, pos: Vector3, s: float, m: Material) -> void:
	M.sphere(p, 0.045 * s, m, pos, Vector3(0.75, 1.25, 0.35), 8)
	M.sphere(p, 0.035 * s, m, pos + Vector3(0.022, 0.065, 0) * s, Vector3(1.0, 1.0, 0.4), 8)
	M.sphere(p, 0.018 * s, m, pos + Vector3(0.05, 0.068, 0) * s, Vector3(1.0, 0.8, 0.4), 6)
	# patas delanteras levantadas y traseras
	M.box(p, Vector3(0.06, 0.016, 0.01) * s, m, pos + Vector3(0.045, 0.04, 0) * s, Vector3(0, 0, 35))
	M.box(p, Vector3(0.05, 0.016, 0.01) * s, m, pos + Vector3(0.05, 0.0, 0) * s, Vector3(0, 0, 10))
	M.box(p, Vector3(0.016, 0.06, 0.01) * s, m, pos + Vector3(-0.01, -0.07, 0) * s, Vector3(0, 0, -10))
	M.box(p, Vector3(0.016, 0.055, 0.01) * s, m, pos + Vector3(0.025, -0.065, 0) * s, Vector3(0, 0, 25))
	# cola en S
	M.box(p, Vector3(0.014, 0.06, 0.01) * s, m, pos + Vector3(-0.045, -0.02, 0) * s, Vector3(0, 0, -30))
	M.box(p, Vector3(0.014, 0.045, 0.01) * s, m, pos + Vector3(-0.06, 0.03, 0) * s, Vector3(0, 0, 20))
	M.sphere(p, 0.012 * s, m, pos + Vector3(-0.055, 0.06, 0) * s, Vector3.ONE, 6)


# Estandarte colgante con borde dorado y cola de golondrina; `cross` = cruz en vez de león
static func banner(p: Node3D, pos: Vector3, facing_y: float, cross: bool) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = facing_y
	p.add_child(n)
	var royal := M.mat(ROYAL)
	var gold := M.metal(GOLD)
	M.box(n, Vector3(0.34, 0.025, 0.025), gold, Vector3(0, 0.0, 0.02))
	for k: float in [-1.0, 1.0]:
		M.sphere(n, 0.022, gold, Vector3(0.17 * k, 0, 0.02), Vector3.ONE, 8)
	M.box(n, Vector3(0.27, 0.38, 0.014), gold, Vector3(0, -0.2, 0.0))
	M.box(n, Vector3(0.24, 0.36, 0.02), royal, Vector3(0, -0.19, 0.004))
	for k: float in [-1.0, 1.0]:
		M.cyl(n, 0.0, 0.07, 0.1, royal, Vector3(0.067 * k, -0.42, 0.004), Vector3(180, 45, 0), 4)
	if cross:
		M.box(n, Vector3(0.045, 0.26, 0.012), gold, Vector3(0, -0.19, 0.016))
		M.box(n, Vector3(0.18, 0.045, 0.012), gold, Vector3(0, -0.13, 0.016))
	else:
		lion(n, Vector3(0, -0.2, 0.016), 1.5, gold)
		# corona sobre el león
		M.box(n, Vector3(0.07, 0.02, 0.012), gold, Vector3(0.01, -0.04, 0.016))
		for k in 3:
			M.cyl(n, 0.0, 0.01, 0.025, gold, Vector3(-0.015 + k * 0.025, -0.02, 0.016), Vector3.ZERO, 4)


# --- Torre ---

func _build_tower(p: Node3D) -> void:
	match tier:
		0: _tower_t0(p)
		1: _tower_t1(p)
		3: _tower_t3(p)
		_:
			_tower_t2(p)
			_t2_extras(p)


# Etapa 2: torre real de sillares con almenas (diseño original)
func _tower_t2(p: Node3D) -> void:
	var bricks := M.tex_mat("bricks", 2.2, Color(0.86, 0.84, 0.8))
	var dark := M.mat(STONE_DARK)
	var stones: Array[Material] = [M.mat(Color(0.62, 0.6, 0.56)), M.mat(Color(0.53, 0.51, 0.48)), M.mat(Color(0.68, 0.66, 0.62))]
	var wood := M.tex_mat("wood", 2.0, Color(0.7, 0.56, 0.45))
	var wood_dark := M.mat(WOOD_DARK)
	var iron := M.metal(IRON)
	var black := M.mat(Color(0.08, 0.07, 0.07))

	# Zócalo, cuerpo y cornisa sobre ménsulas
	M.box(p, Vector3(0.88, 0.08, 0.88), dark, Vector3(0, 0.04, 0))
	M.box(p, Vector3(0.8, 0.08, 0.8), stones[1], Vector3(0, 0.11, 0))
	M.box(p, Vector3(0.72, 0.8, 0.72), bricks, Vector3(0, 0.53, 0))
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, face.x)
		for k in 5:
			M.box(p, Vector3(0.06, 0.06, 0.06), stones[k % 3], face * 0.39 + tg * (-0.3 + k * 0.15) + Vector3(0, 0.9, 0))
		# sillares de esquina salientes
		for row in 4:
			var cy := 0.22 + row * 0.18
			var off := 0.33 if row % 2 == 0 else 0.3
			M.box(p, Vector3(0.12, 0.08, 0.03) if absf(face.z) > 0.5 else Vector3(0.03, 0.08, 0.12),
					stones[(row + 1) % 3], face * 0.365 + tg * off + Vector3(0, cy, 0))
			M.box(p, Vector3(0.12, 0.08, 0.03) if absf(face.z) > 0.5 else Vector3(0.03, 0.08, 0.12),
					stones[row % 3], face * 0.365 - tg * off + Vector3(0, cy + 0.09, 0))
	M.box(p, Vector3(0.86, 0.06, 0.86), stones[2], Vector3(0, 0.96, 0))
	M.box(p, Vector3(0.82, 0.03, 0.82), wood, Vector3(0, 0.99, 0))

	# Parapeto con almenas (esquinas y centros)
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.86, 0.09, 0.06), bricks, Vector3(0, 1.035, 0.4 * s))
		M.box(p, Vector3(0.06, 0.09, 0.86), bricks, Vector3(0.4 * s, 1.035, 0))
	for sx: float in [-1.0, 0.0, 1.0]:
		for sz: float in [-1.0, 0.0, 1.0]:
			if sx == 0.0 and sz == 0.0:
				continue
			var mp := Vector3(0.4 * sx, 1.14, 0.4 * sz)
			var size := Vector3(0.12, 0.13, 0.08) if sx == 0.0 else (Vector3(0.08, 0.13, 0.12) if sz == 0.0 else Vector3(0.1, 0.13, 0.1))
			M.box(p, size, bricks, mp)
			M.box(p, size + Vector3(0.02, -0.11, 0.02), stones[2], mp + Vector3(0, 0.07, 0))

	# Puerta claveteada con arco (frente +Z) y otra cara con arco ciego
	for sz: float in [-1.0, 1.0]:
		var d := Node3D.new()
		d.position = Vector3(0, 0, 0.362 * sz)
		d.rotation.y = 0.0 if sz > 0.0 else PI
		p.add_child(d)
		M.cyl(d, 0.12, 0.12, 0.03, stones[2], Vector3(0, 0.33, 0.0), Vector3(90, 0, 0), 14)
		M.box(d, Vector3(0.24, 0.2, 0.03), stones[2], Vector3(0, 0.23, 0.0))
		M.cyl(d, 0.095, 0.095, 0.03, wood_dark, Vector3(0, 0.33, 0.008), Vector3(90, 0, 0), 14)
		M.box(d, Vector3(0.19, 0.19, 0.03), wood_dark, Vector3(0, 0.235, 0.008))
		for k in 3:
			M.box(d, Vector3(0.012, 0.28, 0.01), black, Vector3(-0.05 + k * 0.05, 0.27, 0.026))
		for y: float in [0.2, 0.32]:
			M.box(d, Vector3(0.18, 0.02, 0.01), iron, Vector3(0, y, 0.027))
		M.add(d, _ring_mesh(), iron, Vector3(0.05, 0.25, 0.03), Vector3(90, 0, 0))
	M.box(p, Vector3(0.3, 0.05, 0.1), stones[0], Vector3(0, 0.025, 0.47))

	# Saeteras en los laterales
	for sx: float in [-1.0, 1.0]:
		for y: float in [0.45, 0.72]:
			M.box(p, Vector3(0.02, 0.13, 0.028), black, Vector3(0.362 * sx, y, 0))
			M.box(p, Vector3(0.02, 0.025, 0.07), black, Vector3(0.362 * sx, y, 0))

	# Estandartes reales: león coronado delante y cruz detrás
	banner(p, Vector3(0, 0.86, 0.372), 0.0, false)
	banner(p, Vector3(0, 0.86, -0.372), PI, true)

	# Asta de la banderola en la almena de una esquina
	M.cyl(p, 0.014, 0.018, 0.42, wood_dark, Vector3(-0.4, 1.4, 0.4), Vector3.ZERO, 6)
	M.sphere(p, 0.025, M.metal(GOLD), Vector3(-0.4, 1.62, 0.4), Vector3.ONE, 8)

	# Virotes de repuesto apoyados en el parapeto y hierba al pie
	for k in 3:
		M.cyl(p, 0.012, 0.012, 0.4, wood, Vector3(0.43, 0.3 + k * 0.0, -0.18 + k * 0.05), Vector3(0, 0, 12), 6)
	var grass := M.mat(Color(0.32, 0.6, 0.2))
	for gp: Vector3 in [Vector3(-0.44, 0, -0.1), Vector3(0.44, 0, 0.2), Vector3(-0.22, 0, -0.45), Vector3(0.22, 0, 0.46), Vector3(-0.45, 0, 0.3)]:
		for b in 3:
			var ga := TAU * b / 3.0
			var blade := Node3D.new()
			blade.position = gp + Vector3(cos(ga), 0, sin(ga)) * 0.02
			blade.rotation = Vector3(sin(ga) * 0.4, 0, -cos(ga) * 0.4)
			p.add_child(blade)
			M.cyl(blade, 0.0, 0.016, 0.09, grass, Vector3(0, 0.045, 0), Vector3.ZERO, 4)


static func _ring_mesh() -> TorusMesh:
	var r := TorusMesh.new()
	r.inner_radius = 0.016
	r.outer_radius = 0.026
	return r


# Banderola de doble punta (animada) en lo alto del asta
func _build_pennant() -> void:
	_pennant = Node3D.new()
	_pennant.position = Vector3(-0.4, 1.57, 0.4)
	add_child(_pennant)
	var royal := M.mat(ROYAL)
	var gold := M.mat(GOLD)
	M.box(_pennant, Vector3(0.2, 0.09, 0.012), royal, Vector3(0.1, -0.02, 0))
	M.box(_pennant, Vector3(0.2, 0.02, 0.016), gold, Vector3(0.1, -0.02, 0))
	for k: float in [-1.0, 1.0]:
		M.cyl(_pennant, 0.0, 0.03, 0.1, royal, Vector3(0.24, -0.02 + 0.022 * k, 0), Vector3(0, 0, -90), 4)


# --- Montaje giratorio ---

func _build_mount(c: Node3D) -> void:
	var wood := M.tex_mat("wood", 2.0, Color(0.7, 0.56, 0.45))
	var wood_dark := M.mat(WOOD_DARK)
	var iron := M.metal(IRON)
	M.cyl(c, 0.2, 0.22, 0.04, wood_dark, Vector3(0, 0.02, 0), Vector3.ZERO, 16)
	M.cyl(c, 0.21, 0.21, 0.015, M.metal(GOLD) if tier == 3 else iron, Vector3(0, 0.035, 0), Vector3.ZERO, 16)
	M.cyl(c, 0.05, 0.06, 0.22, wood, Vector3(0, 0.14, -0.04), Vector3.ZERO, 10)
	for y: float in [0.08, 0.2]:
		M.cyl(c, 0.063, 0.063, 0.02, iron, Vector3(0, y, -0.04), Vector3.ZERO, 10)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		M.segment(c, 0.016, wood_dark, Vector3(cos(a) * 0.17, 0.04, -0.04 + sin(a) * 0.17), Vector3(cos(a) * 0.04, 0.17, -0.04 + sin(a) * 0.04), 6)
	# Horquilla
	for sx: float in [-1.0, 1.0]:
		M.box(c, Vector3(0.025, 0.1, 0.08), iron, Vector3(0.055 * sx, 0.26, -0.04))


# --- Balista (retrocede con _gun) ---

func _build_gun(g: Node3D) -> void:
	var wood := M.tex_mat("wood", 2.0, Color(0.72, 0.52, 0.38))
	var wood_dark := M.mat(WOOD_DARK)
	var iron := M.metal(IRON)
	var rope := M.mat(ROPE)
	var gold := M.metal(GOLD)
	var royal := M.mat(ROYAL)
	# Caja (afuste) con canal para el virote
	M.box(g, Vector3(0.1, 0.06, 0.66), wood, Vector3(0, 0.0, -0.1))
	M.box(g, Vector3(0.03, 0.012, 0.6), wood_dark, Vector3(0, 0.032, -0.1))
	for z: float in [-0.38, -0.12, 0.1]:
		M.box(g, Vector3(0.112, 0.07, 0.025), iron, Vector3(0, 0.0, z))
	M.box(g, Vector3(0.12, 0.06, 0.04), iron, Vector3(0, 0.0, -0.44))
	# Bastidor de torsión con madejas de cuerda
	M.box(g, Vector3(0.26, 0.03, 0.08), wood_dark, Vector3(0, 0.08, -0.3))
	M.box(g, Vector3(0.26, 0.03, 0.08), wood_dark, Vector3(0, -0.07, -0.3))
	for sx: float in [-1.0, 1.0]:
		M.cyl(g, 0.035, 0.035, 0.13, rope, Vector3(ARM_ROOT.x * sx, 0.005, ARM_ROOT.z), Vector3.ZERO, 10)
		M.cyl(g, 0.04, 0.04, 0.02, iron, Vector3(ARM_ROOT.x * sx, 0.1, ARM_ROOT.z), Vector3.ZERO, 10)
		M.cyl(g, 0.04, 0.04, 0.02, iron, Vector3(ARM_ROOT.x * sx, -0.09, ARM_ROOT.z), Vector3.ZERO, 10)
		M.box(g, Vector3(0.025, 0.17, 0.08), wood_dark, Vector3(0.14 * sx, 0.005, -0.3))
	# Escudete real al frente (desde la etapa 1) y herrajes dorados en la Maestría
	if tier >= 1:
		M.box(g, Vector3(0.09, 0.07, 0.015), royal, Vector3(0, 0.03, -0.348))
		M.box(g, Vector3(0.02, 0.06, 0.018), gold, Vector3(0, 0.03, -0.35))
		M.box(g, Vector3(0.07, 0.016, 0.018), gold, Vector3(0, 0.04, -0.35))
	if tier == 3:
		for z: float in [-0.2, 0.0]:
			M.box(g, Vector3(0.114, 0.072, 0.02), gold, Vector3(0, 0.0, z))
		for sx: float in [-1.0, 1.0]:
			M.cyl(g, 0.042, 0.042, 0.022, gold, Vector3(ARM_ROOT.x * sx, 0.1, ARM_ROOT.z), Vector3.ZERO, 10)
			M.cyl(g, 0.042, 0.042, 0.022, gold, Vector3(ARM_ROOT.x * sx, -0.09, ARM_ROOT.z), Vector3.ZERO, 10)
		M.sphere(g, 0.03, M.mat(Color(0.55, 0.8, 1.0), 1.6), Vector3(0, 0.07, -0.35), Vector3.ONE, 10)
	# Torno trasero con manivelas y empuñaduras
	M.cyl(g, 0.03, 0.03, 0.16, wood_dark, Vector3(0, 0.0, 0.16), Vector3(0, 0, 90), 10)
	for sx: float in [-1.0, 1.0]:
		M.box(g, Vector3(0.015, 0.08, 0.02), iron, Vector3(0.085 * sx, -0.03, 0.16))
		M.cyl(g, 0.016, 0.016, 0.06, wood_dark, GRIP * Vector3(sx, 1, 1) + Vector3(0, -0.02, 0), Vector3.ZERO, 6)
	# Gatillo
	M.box(g, Vector3(0.015, 0.05, 0.015), iron, Vector3(0, -0.05, 0.08), Vector3(20, 0, 0))
	# Muñón del eje
	M.cyl(g, 0.02, 0.02, 0.14, iron, Vector3(0, -0.02, 0.0), Vector3(0, 0, 90), 8)


# Soldado humano con capacete, cota de malla y sobreveste azul con cruz dorada
func _build_soldier(c: Node3D) -> void:
	var mail := M.metal(MAIL)
	var royal := M.mat(ROYAL)
	var royal_dark := M.mat(ROYAL_DARK)
	var gold := M.mat(GOLD)
	var steel := M.metal(STEEL)
	var leather := M.mat(Color(0.35, 0.22, 0.12))
	var shiny := M.metal(Color(0.8, 0.82, 0.88))
	if tier == 0:
		# recluta con jubón acolchado y gorro de cuero
		Human.body(c, M.mat(Color(0.62, 0.5, 0.34)), leather)
	else:
		Human.body(c, mail if tier < 3 else shiny, royal_dark if tier < 3 else M.metal(GOLD))
		# sobreveste azul (con cruz dorada desde la etapa 2)
		M.box(c, Vector3(0.19, 0.28, 0.02), royal, Vector3(0, 0.14, -0.123), Vector3(-4, 0, 0))
		M.box(c, Vector3(0.19, 0.28, 0.02), royal, Vector3(0, 0.14, 0.123), Vector3(4, 0, 0))
		if tier >= 2:
			M.box(c, Vector3(0.035, 0.2, 0.012), gold, Vector3(0, 0.16, -0.136), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.13, 0.035, 0.012), gold, Vector3(0, 0.2, -0.138), Vector3(-4, 0, 0))
		if tier == 3:
			M.box(c, Vector3(0.2, 0.02, 0.026), M.metal(GOLD), Vector3(0, 0.005, -0.121))
			for sx: float in [-1.0, 1.0]:
				M.sphere(c, 0.075, M.metal(GOLD), Vector3(0.135 * sx, 0.285, 0), Vector3(1, 0.7, 1), 10)
			# capa corta azul con borde dorado
			M.box(c, Vector3(0.26, 0.3, 0.02), royal, Vector3(0, 0.16, 0.145), Vector3(10, 0, 0))
			M.box(c, Vector3(0.27, 0.025, 0.026), M.metal(GOLD), Vector3(0, 0.02, 0.17), Vector3(10, 0, 0))
	var belt := TorusMesh.new()
	belt.inner_radius = 0.13
	belt.outer_radius = 0.155
	M.add(c, belt, leather, Vector3(0, 0.09, 0))
	M.box(c, Vector3(0.04, 0.03, 0.02), M.metal(GOLD if tier >= 1 else IRON), Vector3(0, 0.09, -0.15))
	# espada envainada
	M.box(c, Vector3(0.025, 0.2, 0.03), leather, Vector3(-0.15, 0.03, 0.02), Vector3(0, 0, -15))
	M.box(c, Vector3(0.08, 0.015, 0.015), steel, Vector3(-0.13, 0.14, 0.02), Vector3(0, 0, -15))
	# botas
	for sx: float in [-1.0, 1.0]:
		M.cyl(c, 0.045, 0.05, 0.05, leather, Vector3(0.06 * sx, 0.01, -0.02), Vector3.ZERO, 8)
	if tier == 0:
		var h0 := Human.head(c, true, true, Color(0.5, 0.32, 0.16))
		M.sphere(h0, 0.15, leather, Vector3(0, 0.06, 0.025), Vector3(1.0, 0.72, 1.0), 14)
		M.cyl(h0, 0.15, 0.15, 0.025, M.mat(Color(0.28, 0.17, 0.09)), Vector3(0, 0.03, 0.02), Vector3(-6, 0, 0), 16)
		return
	# cabeza con capacete de ala ancha
	var h := Human.head(c, true, false)
	M.sphere(h, 0.15, steel, Vector3(0, 0.07, 0.02), Vector3(1.0, 0.78, 1.0), 14)
	M.cyl(h, 0.17, 0.2, 0.02, steel, Vector3(0, 0.06, 0.02), Vector3(-5, 0, 0), 18)
	M.cyl(h, 0.152, 0.152, 0.025, M.metal(IRON), Vector3(0, 0.08, 0.02), Vector3(-5, 0, 0), 18)
	M.box(h, Vector3(0.02, 0.02, 0.15), M.metal(IRON), Vector3(0, 0.168, 0.03))
	if tier == 3:
		M.cyl(h, 0.202, 0.202, 0.012, M.metal(GOLD), Vector3(0, 0.05, 0.02), Vector3(-5, 0, 0), 18)
		for k in 3:
			M.sphere(h, 0.035, M.mat(Color(0.3, 0.45, 0.9)) if k == 1 else M.mat(Color(0.97, 0.96, 0.94)), Vector3(0, 0.19 + k * 0.012, 0.06 + k * 0.04), Vector3(0.6, 1.0, 1.4), 8)


func _build_moving_parts() -> void:
	var wood := M.tex_mat("wood", 2.0, Color(0.72, 0.52, 0.38))
	var iron := M.metal(IRON)
	var steel := M.metal(STEEL)
	var rope := M.mat(ROPE)
	# Brazos de la balista
	_arm_r = Node3D.new()
	_arm_r.position = ARM_ROOT
	_gun.add_child(_arm_r)
	_arm_l = Node3D.new()
	_arm_l.position = ARM_ROOT * Vector3(-1, 1, 1)
	_gun.add_child(_arm_l)
	for k in 2:
		var arm := _arm_r if k == 0 else _arm_l
		var dx := 1.0 if k == 0 else -1.0
		M.box(arm, Vector3(ARM_LEN, 0.05, 0.05), wood, Vector3(ARM_LEN * 0.5 * dx, 0, 0))
		M.box(arm, Vector3(0.025, 0.05, 0.05), iron, Vector3(ARM_LEN * 0.55 * dx, 0, 0))
		M.cyl(arm, 0.0, 0.025, 0.05, iron, Vector3((ARM_LEN + 0.015) * dx, 0, 0), Vector3(0, 0, -90.0 * dx), 6)
	# Cuerda
	_str_r = M.add(_gun, M.tube_mesh(0.007, 4), rope)
	_str_l = M.add(_gun, M.tube_mesh(0.007, 4), rope)
	# Virote cargado (la cola en el origen, apunta a -Z)
	_bolt = Node3D.new()
	_gun.add_child(_bolt)
	M.cyl(_bolt, 0.018, 0.018, BOLT_LEN, M.mat(Color(0.8, 0.66, 0.44)), Vector3(0, 0, -BOLT_LEN * 0.5), Vector3(90, 0, 0), 6)
	M.cyl(_bolt, 0.0, 0.032, 0.1, steel, Vector3(0, 0, -BOLT_LEN - 0.04), Vector3(-90, 0, 0), 4)
	M.box(_bolt, Vector3(0.08, 0.005, 0.08), M.mat(ROYAL), Vector3(0, 0, -0.06))
	M.box(_bolt, Vector3(0.005, 0.06, 0.08), M.mat(GOLD), Vector3(0, 0.02, -0.06))
	# Brazos del soldado
	var sleeve: Material = [M.mat(Color(0.62, 0.5, 0.34)), M.metal(MAIL), M.metal(MAIL), M.metal(Color(0.8, 0.82, 0.88))][tier]
	_sl_arm_l = M.add(cat_pivot, M.tube_mesh(0.042, 8), sleeve)
	_sl_arm_r = M.add(cat_pivot, M.tube_mesh(0.042, 8), sleeve)
	_hand_l = M.sphere(cat_pivot, 0.043, M.mat(Color(0.35, 0.22, 0.12)), Vector3.ZERO, Vector3.ONE, 8)
	_hand_r = M.sphere(cat_pivot, 0.043, M.mat(Color(0.35, 0.22, 0.12)), Vector3.ZERO, Vector3.ONE, 8)


# =====================================================================
# --- Etapas visuales ---
# =====================================================================

func _build_tier_fx() -> void:
	var py: float = PLAT_BY_TIER[tier]
	match tier:
		0:
			_pennants.append(Arch.pennant_node(self, Vector3(-0.37, py + 0.4, 0.37), ROYAL, Color(0.85, 0.75, 0.5), 0.2, 0.6))
		1:
			_flames.append(Arch.flame_node(self, Vector3(0.21, 0.47, 0.36 + 0.075)))
			_pennants.append(Arch.pennant_node(self, Vector3(-0.39, py + 0.5, 0.39), ROYAL, GOLD, 0.24, 0.6))
		2:
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.24 * sx, 0.45, 0.362 + 0.075)))
			_pennants.append(Arch.pennant_node(self, Vector3(0.4, 1.78, -0.4), ROYAL, GOLD, 0.26, 2.7))
		3:
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.24 * sx, 0.47, 0.35 + 0.075), 1.1, Color(1.0, 0.82, 0.4)))
				_pennants.append(Arch.pennant_node(self, Vector3(0.35 * sx, py + 0.97, -0.35), ROYAL, GOLD, 0.32, 0.4 if sx < 0.0 else 2.7))
			_spinners.append(Arch.aura_ring(self, 0.47, Color(0.55, 0.75, 1.0), 0.12))
			add_child(Arch.sparkles(Color(0.75, 0.88, 1.0), Vector3(0, 0.7, 0), Vector3(0.45, 0.6, 0.45), 18, 0.012))


# Etapa 0: torre de troncos apilados (cabaña) con cubierta de tablones
func _tower_t0(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[0]
	var bark := M.tex_mat("wood", 2.5, Color(0.68, 0.52, 0.37))
	var bark2 := M.tex_mat("wood", 2.5, Color(0.58, 0.44, 0.31))
	var log_dark := M.mat(Color(0.4, 0.26, 0.15))
	var plank := M.tex_mat("wood", 2.0, Color(0.88, 0.74, 0.55))
	var plank2 := M.tex_mat("wood", 2.0, Color(0.76, 0.6, 0.43))
	var iron := M.metal(IRON)
	var rope := M.mat(ROPE)
	var cut := M.mat(Color(0.86, 0.7, 0.48))
	M.cyl(p, 0.45, 0.47, 0.03, M.mat(Color(0.52, 0.4, 0.27)), Vector3(0, 0.015, 0), Vector3.ZERO, 16)
	var half := 0.3
	M.box(p, Vector3(0.56, 0.62, 0.56), log_dark, Vector3(0, 0.34, 0))
	for row in 8:
		var y := 0.06 + row * 0.083
		for s: float in [-1.0, 1.0]:
			var m := bark if (row + int(s > 0.0)) % 2 == 0 else bark2
			if row % 2 == 0:
				M.cyl(p, 0.045, 0.045, 0.76, m, Vector3(0, y, half * s), Vector3(0, 0, 90), 8)
				for e: float in [-1.0, 1.0]:
					M.cyl(p, 0.038, 0.038, 0.012, cut, Vector3(0.38 * e, y, half * s), Vector3(0, 0, 90), 8)
			else:
				M.cyl(p, 0.045, 0.045, 0.76, m, Vector3(half * s, y, 0), Vector3(90, 0, 0), 8)
				for e: float in [-1.0, 1.0]:
					M.cyl(p, 0.038, 0.038, 0.012, cut, Vector3(half * s, y, 0.38 * e), Vector3(90, 0, 0), 8)
	# puerta y troneras
	M.box(p, Vector3(0.18, 0.3, 0.03), plank2, Vector3(0, 0.17, half + 0.05))
	for y: float in [0.1, 0.24]:
		M.box(p, Vector3(0.19, 0.022, 0.01), iron, Vector3(0, y, half + 0.067))
	for sx: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.03, 0.1, 0.06), M.mat(Color(0.08, 0.07, 0.07)), Vector3((half + 0.04) * sx, 0.46, 0))
	# cubierta de tablones con barandilla de troncos
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.84, 0.05, 0.06), log_dark, Vector3(0, py - 0.06, 0.36 * s))
	for k in 8:
		M.box(p, Vector3(0.8 + (k % 3) * 0.02, 0.04, 0.1), plank if k % 2 == 0 else plank2, Vector3((k % 2) * 0.012, py - 0.02, -0.37 + k * 0.105), Vector3(0, (k % 3 - 1) * 2.0, 0))
	var corners := [Vector3(-0.37, 0, 0.37), Vector3(0.37, 0, 0.37), Vector3(0.37, 0, -0.37), Vector3(-0.37, 0, -0.37)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		M.cyl(p, 0.03, 0.03, 0.18, bark, a + Vector3(0, py + 0.09, 0), Vector3.ZERO, 8)
		M.sphere(p, 0.032, cut, a + Vector3(0, py + 0.18, 0), Vector3(1, 0.4, 1), 8)
		M.segment(p, 0.02, bark2, a + Vector3(0, py + 0.15, 0), b + Vector3(0, py + 0.15, 0), 6)
	# mástil con banderola azul
	M.cyl(p, 0.014, 0.018, 0.42, log_dark, Vector3(-0.37, py + 0.21, 0.37), Vector3.ZERO, 6)
	# haz de virotes, tonel y cuerdas
	for k in 3:
		M.cyl(p, 0.011, 0.011, 0.42, plank, Vector3(0.43, 0.2, -0.16 + k * 0.05), Vector3(0, 0, 14), 6)
	M.cyl(p, 0.016, 0.016, 0.02, rope, Vector3(0.43, 0.2, -0.11), Vector3(90, 0, 0), 8)
	M.cyl(p, 0.06, 0.055, 0.14, plank, Vector3(-0.41, 0.07, -0.2), Vector3.ZERO, 12)
	for y: float in [0.03, 0.11]:
		M.cyl(p, 0.063, 0.063, 0.014, log_dark, Vector3(-0.41, y, -0.2), Vector3.ZERO, 12)
	Arch._ground_details(p, false)


# Etapa 1: planta baja de piedra y cadalso de madera con tornapuntas
func _tower_t1(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[1]
	var bricks := M.tex_mat("bricks", 2.2, Color(0.86, 0.84, 0.8))
	var dark := M.mat(STONE_DARK)
	var stones: Array[Material] = [M.mat(Color(0.62, 0.6, 0.56)), M.mat(Color(0.53, 0.51, 0.48)), M.mat(Color(0.68, 0.66, 0.62))]
	var wood := M.tex_mat("wood", 2.0, Color(0.78, 0.62, 0.48))
	var wood_dark := M.mat(WOOD_DARK)
	var iron := M.metal(IRON)
	var gold := M.metal(GOLD)
	M.box(p, Vector3(0.88, 0.08, 0.88), dark, Vector3(0, 0.04, 0))
	M.box(p, Vector3(0.72, 0.5, 0.72), bricks, Vector3(0, 0.31, 0))
	Arch._stone_blocks(p, 0.36, 0.2, 2, [[0, 1]], stones)
	Arch._door(p, 0.364, stones[2], wood_dark, iron)
	M.box(p, Vector3(0.3, 0.05, 0.1), stones[0], Vector3(0, 0.025, 0.47))
	Arch.wall_torch(p, Vector3(0.21, 0.42, 0.36), Vector3(0, 0, 1), iron)
	# ménsulas de madera y piso de tablas en voladizo
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, face.x)
		for o: float in [-0.25, 0.0, 0.25]:
			M.segment(p, 0.022, wood_dark, face * 0.36 + tg * o + Vector3(0, 0.46, 0), face * 0.42 + tg * o + Vector3(0, 0.56, 0), 6)
	M.box(p, Vector3(0.86, 0.05, 0.86), wood_dark, Vector3(0, 0.585, 0))
	# cadalso: tablas verticales, postes y aspas
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, face.x)
		var h := py - 0.61
		M.box(p, tg.abs() * 0.8 + Vector3(0, h, 0) + face.abs() * 0.03, wood, face * 0.4 + Vector3(0, 0.61 + h * 0.5, 0))
		for o: float in [-0.4, 0.0, 0.4]:
			M.box(p, Vector3(0.045, h + 0.02, 0.045), wood_dark, face * 0.41 + tg * o + Vector3(0, 0.61 + h * 0.5, 0))
		for side: float in [-1.0, 1.0]:
			var d := M.box(p, tg.abs() * 0.035 + Vector3(0, 0.3, 0) + face.abs() * 0.02, wood_dark, face * 0.418 + tg * (0.2 * side) + Vector3(0, 0.61 + h * 0.5, 0))
			d.rotate(face, 0.75 * side)
		M.box(p, tg.abs() * 0.84 + Vector3(0, 0.03, 0) + face.abs() * 0.04, iron, face * 0.405 + Vector3(0, 0.63, 0))
	M.box(p, Vector3(0.86, 0.04, 0.86), wood, Vector3(0, py - 0.02, 0))
	# parapeto de tablas con almenas de madera
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, face.x)
		M.box(p, tg.abs() * 0.86 + Vector3(0, 0.08, 0) + face.abs() * 0.04, wood, face * 0.41 + Vector3(0, py + 0.04, 0))
		for o: float in [-0.39, 0.0, 0.39]:
			M.box(p, tg.abs() * 0.1 + Vector3(0, 0.08, 0) + face.abs() * 0.05, wood_dark, face * 0.41 + tg * o + Vector3(0, py + 0.12, 0))
	# mástil con banderola y estandarte real pequeño
	M.cyl(p, 0.014, 0.018, 0.52, wood_dark, Vector3(-0.39, py + 0.26, 0.39), Vector3.ZERO, 6)
	M.sphere(p, 0.022, gold, Vector3(-0.39, py + 0.53, 0.39), Vector3.ONE, 8)
	Arch.hang_banner(p, Vector3(0, py - 0.05, 0.43), 0.0, 0.18, 0.2, M.mat(ROYAL), gold, gold, 0)
	Arch._ground_details(p, false)


# Etapa 2: añadidos al diseño original (torreón trasero y antorchas junto a la puerta)
func _t2_extras(p: Node3D) -> void:
	var bricks := M.tex_mat("bricks", 2.2, Color(0.86, 0.84, 0.8))
	var slate := M.tex_mat("roof", 3.0, Color(0.5, 0.56, 0.72))
	var iron := M.metal(IRON)
	var top := Arch.turret(p, Vector3(0.4, 0, -0.4), 0.1, 1.0, 1.3, bricks, slate, 0.28, M.mat(Color(0.68, 0.66, 0.62)), M.metal(GOLD))
	M.cyl(p, 0.007, 0.007, 0.2, iron, top + Vector3(0, 0.1, 0), Vector3.ZERO, 4)
	for sx: float in [-1.0, 1.0]:
		Arch.wall_torch(p, Vector3(0.24 * sx, 0.4, 0.362), Vector3(0, 0, 1), iron)


# Etapa 3 (Maestría): torre real de mármol y oro con cuatro torreones y estandartes del león
func _tower_t3(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[3]
	var half := 0.35
	var wall := M.tex_mat("bricks", 2.2, MARBLE)
	var stones: Array[Material] = [M.mat(Color(0.93, 0.91, 0.86)), M.mat(Color(0.86, 0.84, 0.8)), M.mat(Color(1.0, 0.98, 0.94))]
	var dark := M.mat(Color(0.74, 0.72, 0.68))
	var gold := M.metal(GOLD)
	var slate := M.tex_mat("roof", 3.0, Color(0.42, 0.55, 0.95))
	var glow := M.mat(Color(0.7, 0.85, 1.0), 1.5)
	Arch._stone_keep(p, py, half, wall, stones, dark, gold, null, [[0, 1], [1, 1]])
	M.box(p, Vector3(2.0 * half + 0.03, 0.025, 2.0 * half + 0.03), gold, Vector3(0, 0.18, 0))
	M.box(p, Vector3(2.0 * half + 0.18, 0.025, 2.0 * half + 0.18), gold, Vector3(0, py - 0.085, 0))
	Arch._door(p, half + 0.004, gold, M.mat(ROYAL_DARK), gold)
	M.box(p, Vector3(0.38, 0.05, 0.1), stones[2], Vector3(0, 0.025, 0.47))
	Arch._slits(p, half, [0.55, 0.95], glow)
	for sx: float in [-1.0, 1.0]:
		var top := Arch.turret(p, Vector3(0.35 * sx, 0, -0.35), 0.125, py - 0.3, py + 0.3, wall, slate, 0.44, gold, gold)
		M.cyl(p, 0.008, 0.008, 0.22, gold, top + Vector3(0, 0.11, 0), Vector3.ZERO, 4)
		Arch.turret(p, Vector3(0.35 * sx, 0, 0.35), 0.085, py - 0.12, py + 0.12, wall, slate, 0.2, gold, gold)
		Arch.wall_torch(p, Vector3(0.24 * sx, 0.42, half - 0.01), Vector3(0, 0, 1), gold)
	banner(p, Vector3(0, py - 0.2, half + 0.012), 0.0, false)
	banner(p, Vector3(0, py - 0.2, -half - 0.012), PI, true)
	for sx: float in [-1.0, 1.0]:
		Arch.heater(p, Vector3((half + 0.012) * sx, py * 0.6, 0.0), PI * 0.5 * sx, 1.4, M.mat(ROYAL), gold, gold)
	Arch._ground_details(p, false)
