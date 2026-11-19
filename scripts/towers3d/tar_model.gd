extends Node3D
## Modelo 3D de la torre "Catapulta de Brea" (id tar): un mangonel de torsión (madeja de cuerda,
## brazo con cuchara y tope acolchado) que lanza ollas de brea ardiendo. En una esquina hierve un
## caldero de brea negra sobre el fuego (con burbujas y humo) y en la otra se apilan barriles.
## La catapulta y su ingeniero giran juntos sobre cat_pivot y apuntan a -Z: el ingeniero da vueltas
## al torno que baja el brazo; al disparar, el brazo salta hacia delante contra el tope.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const Arch := preload("res://scripts/towers3d/archer_model.gd")

const STONE_DARK := Color(0.42, 0.41, 0.39)
const WOOD_DARK := Color(0.33, 0.21, 0.12)
const IRON := Color(0.27, 0.27, 0.3)
const STEEL := Color(0.47, 0.49, 0.54)
const ROPE := Color(0.82, 0.72, 0.52)
const LEATHER := Color(0.45, 0.28, 0.15)
const LEATHER_DARK := Color(0.3, 0.18, 0.1)
const TAR := Color(0.06, 0.05, 0.05)
const TAR_SHEEN := Color(0.14, 0.12, 0.11)
const CLAY := Color(0.74, 0.43, 0.26)
const EMBER := Color(1.0, 0.5, 0.12)
const FIRE := Color(1.0, 0.6, 0.15)
const ORANGE := Color(0.95, 0.5, 0.12)
const GOLD := Color(0.95, 0.75, 0.3)
const BRASS := Color(0.82, 0.62, 0.3)
const COPPER := Color(0.8, 0.46, 0.28)
const MARBLE := Color(0.97, 0.95, 0.9)
const ROYAL := Color(0.16, 0.26, 0.62)
const INFERNAL := Color(0.45, 1.0, 0.25)
const RED := Color(0.72, 0.14, 0.12)
const CREAM := Color(0.95, 0.9, 0.78)
const SOOT := Color(0.12, 0.11, 0.12)

# Altura de la plataforma por etapa (0 = campo de tierra; 1 = plataforma de piedra; 2-3 = bastión)
const PLAT_BY_TIER := [0.04, 0.2, 0.38, 0.48]
# Mangonel (coordenadas de cat_pivot): eje de la madeja de torsión y brazo
const AXLE := Vector3(0, 0.2, -0.04)
const ARM_LEN := 0.46
# Ángulos del brazo (giro en X): + inclina la cuchara hacia atrás (+Z)
const A_REST := 0.75
const A_COCK := 1.42
const A_FIRE := -0.22
# Olla de brea dentro de la cuchara (coordenadas del brazo)
const POT_LOCAL := Vector3(0, ARM_LEN, -0.08)
# Torno y operador
const DRUM := Vector3(0, 0.13, 0.18)
const CRANK_X := 0.17
const CRANK_R := 0.06
const OP_POS := Vector3(0.3, 0, 0.17)
const OP_YAW := PI * 0.5
const OP_SCALE := 0.86
# Caldero (esquina -X +Z) y barriles (esquina +X -Z)
const CAUL := Vector3(-0.31, 0, 0.3)
const CAUL_SURF := [0.17, 0.2, 0.23, 0.25]
const CAUL_R := [0.066, 0.07, 0.08, 0.085]

var cat_pivot: Node3D
var tier := 0
var _arm: Node3D
var _pot: Node3D
var _crank: Node3D
var _cord: MeshInstance3D
var _operator: Node3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _hand_l: MeshInstance3D
var _hand_r: MeshInstance3D
var _bubbles: Array[Node3D] = []
var _flames: Array[Node3D] = []
var _pennants: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _floaters: Array[Node3D] = []


func _init(level := 0) -> void:
	tier = Arch.tier_of(level)
	M.add_baked(self, M.baked("tar_tower_t%d" % tier, _build_tower))
	_build_cauldron_fx()
	_build_tier_fx()
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, PLAT_BY_TIER[tier], 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("tar_frame_t%d" % tier, _build_frame))
	_operator = Node3D.new()
	_operator.position = OP_POS
	_operator.rotation.y = OP_YAW
	_operator.scale = Vector3.ONE * OP_SCALE
	cat_pivot.add_child(_operator)
	M.add_baked(_operator, M.baked("tar_engineer_t%d" % tier, _build_engineer))
	_arm = Node3D.new()
	_arm.position = AXLE
	cat_pivot.add_child(_arm)
	M.add_baked(_arm, M.baked("tar_arm_t%d" % tier, _build_arm))
	_build_moving_parts()
	animate({"t": 0.0, "charge": 0.0, "fire": 0.0, "has_target": false})


## s = {t, charge (0..1), fire (1 -> 0), has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = s.get("charge", 0.0)
	var fire: float = s.get("fire", 0.0)
	# Brazo: el torno lo baja hacia atrás al cargar; al disparar salta contra el tope y vibra
	var a := lerpf(A_REST, A_COCK, charge)
	if fire > 0.0:
		a = lerpf(a, A_FIRE, clampf(fire * 1.6, 0.0, 1.0)) + sin(t * 70.0) * 0.04 * fire
	_arm.rotation.x = a
	# La olla de brea va en la cuchara mientras se carga
	_pot.visible = fire <= 0.05 and charge > 0.15
	# Torno: gira mientras se carga; la cuerda tira de la punta del brazo
	_crank.rotation.x = -charge * TAU * 1.5
	_cord.visible = charge > 0.05 and fire <= 0.0
	if _cord.visible:
		var hook := AXLE + Basis(Vector3.RIGHT, a) * Vector3(0, ARM_LEN * 0.78, 0.035)
		M.orient_segment(_cord, DRUM + Vector3(0, 0.04, 0.0), hook)
	_update_hands()
	_operator.position = OP_POS + Vector3(0, absf(sin(t * 2.0)) * 0.006, 0)
	_operator.rotation.x = -charge * 0.12 if fire <= 0.0 else 0.0
	# Burbujas del caldero: crecen, revientan y vuelven a salir
	for i in _bubbles.size():
		var ph := fposmod(t * 0.8 + i * 0.37, 1.0)
		var sc := sin(ph * PI)
		_bubbles[i].scale = Vector3.ONE * maxf(sc, 0.05)
		var bp: Vector3 = _bubbles[i].get_meta("base", Vector3.ZERO)
		_bubbles[i].position = bp + Vector3(0, sc * 0.008, 0)
	Arch.animate_fx(t, _flames, _pennants, _spinners, _floaters)


## Punto de salida del proyectil: la cuchara del brazo en el momento de soltar.
func muzzle_global() -> Vector3:
	return cat_pivot.to_global(AXLE + Basis(Vector3.RIGHT, A_FIRE) * POT_LOCAL)


# Manos del ingeniero sobre la manivela del torno
func _update_hands() -> void:
	var ang := _crank.rotation.x
	var handle := DRUM + Vector3(0, -sin(ang) * CRANK_R, cos(ang) * CRANK_R)
	var hr := handle + Vector3(CRANK_X + 0.07, 0, 0)
	var hl := handle + Vector3(CRANK_X + 0.025, 0, 0)
	var op_xf := _operator.transform
	_hand_r.position = hr
	_hand_l.position = hl
	M.orient_segment(_arm_r, op_xf * Human.R_SHOULDER, hr)
	M.orient_segment(_arm_l, op_xf * Human.L_SHOULDER, hl)


# =====================================================================
# --- Piezas sueltas ---
# =====================================================================

# Barril de duelas con flejes; `lying` lo tumba de lado. `top` = tapa (o brea si es negra)
static func _barrel(p: Node3D, pos: Vector3, r: float, h: float, wood: Material, hoop: Material, top: Material, lying := false, yaw := 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation = Vector3(0, yaw, PI * 0.5 if lying else 0.0)
	p.add_child(n)
	var y0 := 0.0 if lying else h * 0.5
	M.cyl(n, r, r, h, wood, Vector3(0, y0, 0), Vector3.ZERO, 14)
	M.cyl(n, r * 1.07, r * 1.07, h * 0.5, wood, Vector3(0, y0, 0), Vector3.ZERO, 14)
	for f: float in [-0.38, 0.38]:
		M.cyl(n, r * 1.04, r * 1.04, 0.016, hoop, Vector3(0, y0 + h * f, 0), Vector3.ZERO, 14)
	M.cyl(n, r * 1.09, r * 1.09, 0.012, hoop, Vector3(0, y0 + h * 0.16, 0), Vector3.ZERO, 14)
	M.cyl(n, r * 0.9, r * 0.9, 0.012, top, Vector3(0, y0 + h * 0.5, 0), Vector3.ZERO, 14)


# Olla de barro con tapón de trapo (munición en reserva)
static func _clay_pot(p: Node3D, pos: Vector3, s: float, clay: Material, rag: Material) -> void:
	M.sphere(p, 0.045 * s, clay, pos + Vector3(0, 0.04 * s, 0), Vector3(1, 0.9, 1), 10)
	M.cyl(p, 0.022 * s, 0.03 * s, 0.03 * s, clay, pos + Vector3(0, 0.085 * s, 0), Vector3.ZERO, 8)
	M.sphere(p, 0.022 * s, rag, pos + Vector3(0, 0.105 * s, 0), Vector3(1, 0.8, 1), 6)


# Chorretones de brea que caen por el borde de una cara (n = normal de la cara)
static func _tar_drips(p: Node3D, y: float, half: float, n: Vector3, offs: Array, m: Material) -> void:
	var tg := Vector3(n.z, 0, n.x)
	for i in offs.size():
		var o: float = offs[i]
		var l := 0.05 + 0.03 * (i % 3)
		var base := n * (half + 0.004) + tg * o + Vector3(0, y, 0)
		M.box(p, Vector3(0.03, l, 0.03) if absf(n.z) > 0.5 else Vector3(0.03, l, 0.03), m, base - Vector3(0, l * 0.5, 0))
		M.sphere(p, 0.018, m, base - Vector3(0, l, 0), Vector3(1, 1.2, 1), 6)


# Humo que sube del caldero (partículas oscuras y translúcidas)
static func _smoke(col: Color, pos: Vector3, amount: int, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 2.4
	p.preprocess = 2.4
	p.position = pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.03
	p.direction = Vector3.UP
	p.spread = 14.0
	p.gravity = Vector3(0.02, 0.05, 0)
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.14
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.max_value = 2.0
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.8))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(col, 0.7))
	ramp.set_color(1, Color(col, 0.0))
	p.color_ramp = ramp
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = m
	p.mesh = mesh
	return p


# =====================================================================
# --- Torre (base estática) ---
# =====================================================================

func _build_tower(p: Node3D) -> void:
	match tier:
		0: _tower_t0(p)
		1: _tower_t1(p)
		2: _tower_t2(p)
		_: _tower_t3(p)
	_cauldron(p, PLAT_BY_TIER[tier])


# Etapa 0: campo de tierra manchado de brea, cerca de estacas, barriles y una hoguera
func _tower_t0(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[0]
	var bark := M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36))
	var log_dark := M.mat(Color(0.4, 0.26, 0.15))
	var plank := M.tex_mat("wood", 2.0, Color(0.82, 0.66, 0.46))
	var rope := M.mat(ROPE)
	var tar := M.metal(TAR_SHEEN)
	var clay := M.mat(CLAY)
	M.cyl(p, 0.46, 0.48, 0.04, M.mat(Color(0.52, 0.4, 0.27)), Vector3(0, 0.02, 0), Vector3.ZERO, 20)
	M.cyl(p, 0.34, 0.34, 0.004, M.mat(Color(0.45, 0.34, 0.22)), Vector3(0, py + 0.001, 0), Vector3.ZERO, 18)
	# manchas de brea en la tierra
	for sp: Vector3 in [Vector3(-0.18, 0, 0.3), Vector3(0.24, 0, -0.18), Vector3(-0.3, 0, -0.1), Vector3(0.1, 0, 0.36)]:
		M.sphere(p, 0.05, tar, sp + Vector3(0, py, 0), Vector3(1.4, 0.12, 1.0), 10)
	# cerca de estacas por detrás y a los lados
	for k in 9:
		var a := PI * 0.15 + k * PI * 0.2125
		var pos := Vector3(sin(a + PI), 0, cos(a + PI)) * 0.45
		if pos.z > 0.2 or (pos.x > 0.25 and pos.z < -0.2):
			continue
		M.cyl(p, 0.022, 0.025, 0.2, bark, pos + Vector3(0, 0.1, 0), Vector3.ZERO, 6)
		M.cyl(p, 0.0, 0.022, 0.05, log_dark, pos + Vector3(0, 0.225, 0), Vector3.ZERO, 6)
		M.cyl(p, 0.028, 0.028, 0.02, rope, pos + Vector3(0, 0.15, 0), Vector3.ZERO, 6)
	# barriles de brea (uno tumbado y derramado) en la esquina +X -Z
	_barrel(p, Vector3(0.33, py, -0.3), 0.06, 0.15, plank, log_dark, tar)
	_barrel(p, Vector3(0.24, py + 0.055, -0.38), 0.055, 0.14, plank, log_dark, M.tex_mat("wood", 2.0, Color(0.7, 0.55, 0.38)), true, 0.4)
	M.sphere(p, 0.07, tar, Vector3(0.2, py, -0.3), Vector3(1.3, 0.1, 1.1), 10)
	# ollas de barro en reserva y un fardo de leña
	for b: Vector3 in [Vector3(0.38, py, 0.08), Vector3(0.39, py, 0.18), Vector3(0.33, py, 0.13)]:
		_clay_pot(p, b, 0.9, clay, M.mat(CREAM))
	for k in 3:
		M.cyl(p, 0.022, 0.022, 0.2, log_dark, Vector3(-0.38, py + 0.022 + (0.04 if k == 2 else 0.0), -0.24 + k * 0.045 - (0.067 if k == 2 else 0.0)), Vector3(90, 15, 0), 7)
	# estaca para la banderola
	M.cyl(p, 0.012, 0.016, 0.54, log_dark, Vector3(0.38, 0.27, 0.36), Vector3.ZERO, 6)
	Arch._ground_details(p, false)


# Plataforma cuadrada de sillares (etapa 1) con losas y chorretones de brea
func _tower_t1(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[1]
	var bricks := M.tex_mat("bricks", 2.2, Color(0.82, 0.8, 0.75))
	var dark := M.mat(STONE_DARK)
	var stones: Array[Material] = [M.mat(Color(0.6, 0.58, 0.54)), M.mat(Color(0.52, 0.5, 0.47)), M.mat(Color(0.66, 0.64, 0.6))]
	var wood := M.tex_mat("wood", 2.0, Color(0.78, 0.6, 0.42))
	var wood_dark := M.mat(WOOD_DARK)
	var iron := M.metal(IRON)
	var tar := M.metal(TAR_SHEEN)
	var clay := M.mat(CLAY)
	M.box(p, Vector3(0.92, 0.05, 0.92), dark, Vector3(0, 0.025, 0))
	M.box(p, Vector3(0.86, py - 0.05, 0.86), bricks, Vector3(0, 0.05 + (py - 0.05) * 0.5, 0))
	M.box(p, Vector3(0.9, 0.035, 0.9), stones[1], Vector3(0, py - 0.0175, 0))
	for ix in 3:
		for iz in 3:
			M.box(p, Vector3(0.24, 0.012, 0.24), stones[0] if (ix + iz) % 2 == 0 else stones[2], Vector3(-0.26 + ix * 0.26, py + 0.006, -0.26 + iz * 0.26))
	# sillares salientes en las esquinas
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(p, Vector3(0.1, py - 0.03, 0.1), stones[1], Vector3(0.42 * sx, (py - 0.03) * 0.5 + 0.03, 0.42 * sz))
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		_tar_drips(p, py - 0.005, 0.45, face, [-0.2, 0.05, 0.22], tar)
	# barriles con flejes de hierro
	_barrel(p, Vector3(0.33, py, -0.31), 0.065, 0.16, wood, iron, tar)
	_barrel(p, Vector3(0.2, py, -0.37), 0.055, 0.13, wood, iron, M.mat(Color(0.6, 0.45, 0.3)))
	_barrel(p, Vector3(0.37, py, -0.15), 0.05, 0.12, wood, iron, tar)
	# ollas de reserva en un cajón
	M.box(p, Vector3(0.14, 0.06, 0.14), wood_dark, Vector3(0.36, py + 0.03, 0.17))
	for b: Vector3 in [Vector3(0.33, py + 0.06, 0.14), Vector3(0.39, py + 0.06, 0.2), Vector3(0.39, py + 0.06, 0.13), Vector3(0.33, py + 0.06, 0.21)]:
		_clay_pot(p, b, 0.75, clay, M.mat(CREAM))
	# asta de la banderola (esquina -X -Z)
	M.box(p, Vector3(0.1, 0.05, 0.1), stones[2], Vector3(-0.38, py + 0.025, -0.38))
	M.cyl(p, 0.015, 0.02, 0.6, wood_dark, Vector3(-0.38, py + 0.3, -0.38), Vector3.ZERO, 8)
	M.sphere(p, 0.025, M.metal(GOLD), Vector3(-0.38, py + 0.61, -0.38), Vector3.ONE, 8)
	# escalón
	M.box(p, Vector3(0.28, 0.08, 0.06), stones[1], Vector3(0.05, 0.04, 0.455))
	Arch._ground_details(p, false)


# Bastión de sillares con parapeto bajo y dos torreones (esquinas +X+Z y -X-Z)
func _bastion(p: Node3D, py: float, wall: Material, stones: Array[Material], dark: Material, cap: Material, roof: Material, finial: Material, roof_h: float) -> Array[Vector3]:
	M.box(p, Vector3(0.94, 0.06, 0.94), dark, Vector3(0, 0.03, 0))
	M.box(p, Vector3(0.86, py - 0.06, 0.86), wall, Vector3(0, 0.06 + (py - 0.06) * 0.5, 0))
	Arch._stone_blocks(p, 0.43, 0.12, int((py - 0.12) / 0.15) + 1, [[0, 1], [1, 1]], stones)
	M.box(p, Vector3(0.9, 0.04, 0.9), stones[1], Vector3(0, py - 0.02, 0))
	for ix in 3:
		for iz in 3:
			M.box(p, Vector3(0.24, 0.012, 0.24), stones[0] if (ix + iz) % 2 == 0 else stones[2], Vector3(-0.26 + ix * 0.26, py + 0.006, -0.26 + iz * 0.26))
	# parapeto bajo con albardilla
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.6, 0.06, 0.04), wall, Vector3(0, py + 0.03, 0.43 * s))
		M.box(p, Vector3(0.04, 0.06, 0.6), wall, Vector3(0.43 * s, py + 0.03, 0))
		M.box(p, Vector3(0.62, 0.02, 0.06), cap, Vector3(0, py + 0.07, 0.43 * s))
		M.box(p, Vector3(0.06, 0.02, 0.62), cap, Vector3(0.43 * s, py + 0.07, 0))
	var tops: Array[Vector3] = []
	for c: Vector3 in [Vector3(0.37, 0, 0.37), Vector3(-0.37, 0, -0.37)]:
		M.cyl(p, 0.1, 0.1, py - 0.1, wall, c + Vector3(0, (py - 0.1) * 0.5, 0), Vector3.ZERO, 14)
		tops.append(Arch.turret(p, c, 0.1, py - 0.1, py + 0.24, wall, roof, roof_h, cap, finial))
	return tops


# Etapa 2: bastión con torreones de pizarra, horno de ladrillo, estandartes negro y naranja
func _tower_t2(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[2]
	var wall := M.tex_mat("bricks", 2.2, Color(0.84, 0.82, 0.77))
	var stones: Array[Material] = [M.mat(Color(0.6, 0.58, 0.54)), M.mat(Color(0.52, 0.5, 0.47)), M.mat(Color(0.66, 0.64, 0.6))]
	var iron := M.metal(IRON)
	var gold := M.metal(GOLD)
	var slate := M.tex_mat("roof", 3.0, Color(0.5, 0.56, 0.72))
	var tar := M.metal(TAR_SHEEN)
	var wood := M.tex_mat("wood", 2.0, Color(0.7, 0.52, 0.36))
	var tops := _bastion(p, py, wall, stones, M.mat(STONE_DARK), stones[2], slate, gold, 0.32)
	for top in tops:
		M.cyl(p, 0.007, 0.007, 0.2, iron, top + Vector3(0, 0.1, 0), Vector3.ZERO, 4)
	# estandartes en las dos caras y antorchas
	for sz: float in [-1.0, 1.0]:
		var yaw := 0.0 if sz > 0.0 else PI
		Arch.hang_banner(p, Vector3(0, py - 0.03, (0.43 + 0.014) * sz), yaw, 0.2, 0.26, M.mat(SOOT), M.metal(BRASS), M.mat(ORANGE), 2)
		for sx: float in [-1.0, 1.0]:
			Arch.wall_torch(p, Vector3(0.24 * sx, py - 0.16, 0.43 * sz), Vector3(0, 0, sz), iron)
	for face: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		_tar_drips(p, py - 0.01, 0.43, face, [-0.25, -0.05, 0.15, 0.27], tar)
	# barriles encadenados (esquina +X -Z)
	_barrel(p, Vector3(0.3, py, -0.3), 0.07, 0.17, wood, iron, tar)
	_barrel(p, Vector3(0.18, py, -0.35), 0.06, 0.14, wood, iron, tar)
	_barrel(p, Vector3(0.34, py, -0.15), 0.055, 0.13, wood, iron, M.mat(Color(0.6, 0.45, 0.3)))
	M.cyl(p, 0.085, 0.085, 0.014, iron, Vector3(0.3, py + 0.13, -0.3), Vector3.ZERO, 14)
	# escalinata
	M.box(p, Vector3(0.3, 0.1, 0.06), stones[1], Vector3(-0.12, 0.05, 0.46))
	Arch._ground_details(p, false)


# Etapa 3 (Maestría): bastión de mármol y oro con tejados azul real y brea infernal verde
func _tower_t3(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[3]
	var wall := M.tex_mat("bricks", 2.2, MARBLE)
	var stones: Array[Material] = [M.mat(Color(0.93, 0.91, 0.86)), M.mat(Color(0.86, 0.84, 0.8)), M.mat(Color(1.0, 0.98, 0.94))]
	var gold := M.metal(GOLD)
	var roof := M.tex_mat("roof", 3.0, Color(0.42, 0.55, 0.95))
	var glow := M.mat(INFERNAL, 2.0)
	var wood := M.tex_mat("wood", 2.0, Color(0.6, 0.42, 0.3))
	var royal := M.mat(ROYAL)
	var tops := _bastion(p, py, wall, stones, M.mat(Color(0.74, 0.72, 0.68)), gold, roof, gold, 0.4)
	for top in tops:
		M.cyl(p, 0.008, 0.008, 0.24, gold, top + Vector3(0, 0.12, 0), Vector3.ZERO, 4)
	# bandas de oro y saeteras con resplandor verde
	M.box(p, Vector3(0.88, 0.025, 0.88), gold, Vector3(0, py * 0.36, 0))
	M.box(p, Vector3(0.95, 0.025, 0.95), gold, Vector3(0, py - 0.045, 0))
	Arch._slits(p, 0.43, [py * 0.62], glow)
	# estandartes azul real en las dos caras, antorchas de llama verde y escudos laterales
	for sz: float in [-1.0, 1.0]:
		var yaw := 0.0 if sz > 0.0 else PI
		Arch.hang_banner(p, Vector3(0, py - 0.06, (0.43 + 0.016) * sz), yaw, 0.22, 0.3, royal, gold, glow, 2)
		for sx: float in [-1.0, 1.0]:
			Arch.wall_torch(p, Vector3(0.25 * sx, py - 0.2, 0.43 * sz), Vector3(0, 0, sz), gold)
	for sx: float in [-1.0, 1.0]:
		Arch.heater(p, Vector3(0.442 * sx, py * 0.62, 0.0), PI * 0.5 * sx, 1.4, royal, gold, gold)
	# barriles de brea infernal con flejes de oro y vetas brillantes
	var iron := M.metal(IRON)
	_barrel(p, Vector3(0.3, py, -0.3), 0.07, 0.17, wood, gold, glow)
	_barrel(p, Vector3(0.18, py, -0.36), 0.058, 0.14, wood, iron, glow)
	_barrel(p, Vector3(0.34, py, -0.15), 0.055, 0.13, wood, iron, M.mat(Color(0.6, 0.45, 0.3)))
	for b: Vector3 in [Vector3(0.3, py + 0.09, -0.23), Vector3(0.24, py + 0.07, -0.34)]:
		M.sphere(p, 0.012, glow, b, Vector3(1, 2.5, 1), 6)
	M.box(p, Vector3(0.32, 0.12, 0.06), stones[2], Vector3(-0.12, 0.06, 0.46))
	M.box(p, Vector3(0.34, 0.015, 0.07), gold, Vector3(-0.12, 0.125, 0.46))
	Arch._ground_details(p, false)


# Caldero de brea sobre el fuego (esquina -X +Z); su forma depende de la etapa
func _cauldron(p: Node3D, py: float) -> void:
	var base := CAUL + Vector3(0, py, 0)
	var surf: float = CAUL_SURF[tier]
	var r: float = CAUL_R[tier]
	var iron := M.metal(IRON)
	var ember := M.mat(EMBER, 1.8)
	var log_dark := M.mat(Color(0.4, 0.26, 0.15))
	var tar_m: Material = M.mat(Color(0.12, 0.42, 0.08), 1.6) if tier == 3 else M.metal(TAR_SHEEN)
	var pot_m: Material = iron
	match tier:
		0:
			# hoguera: anillo de piedras, troncos y brasas; trípode con cadena
			for k in 7:
				var a := TAU * k / 7.0
				M.sphere(p, 0.028, M.mat(Color(0.58, 0.56, 0.52)), base + Vector3(cos(a) * 0.1, 0.012, sin(a) * 0.1), Vector3(1, 0.7, 1), 6)
			for k in 3:
				M.cyl(p, 0.013, 0.013, 0.14, log_dark, base + Vector3(0, 0.02, 0), Vector3(90, k * 60.0, 0), 5)
			M.sphere(p, 0.04, ember, base + Vector3(0, 0.02, 0), Vector3(1.2, 0.4, 1.2), 8)
			var apex := base + Vector3(0, 0.37, 0)
			for k in 3:
				var a := TAU * k / 3.0 + 0.4
				M.segment(p, 0.012, log_dark, base + Vector3(cos(a) * 0.14, 0.0, sin(a) * 0.14), apex + Vector3(cos(a) * 0.01, 0.02, sin(a) * 0.01), 5)
			M.cyl(p, 0.022, 0.022, 0.03, M.mat(ROPE), apex, Vector3.ZERO, 6)
			M.segment(p, 0.005, iron, apex, base + Vector3(0, surf + 0.09, 0), 4)
			M.segment(p, 0.005, iron, base + Vector3(-r - 0.01, surf, 0), base + Vector3(0, surf + 0.09, 0), 4)
			M.segment(p, 0.005, iron, base + Vector3(r + 0.01, surf, 0), base + Vector3(0, surf + 0.09, 0), 4)
		1:
			# hogar de piedra con boca de fuego
			M.cyl(p, 0.115, 0.125, 0.1, M.mat(Color(0.55, 0.53, 0.5)), base + Vector3(0, 0.05, 0), Vector3.ZERO, 10)
			for k in 8:
				var a := TAU * k / 8.0
				M.box(p, Vector3(0.05, 0.04, 0.03), M.mat(Color(0.62, 0.6, 0.56)) if k % 2 == 0 else M.mat(STONE_DARK), base + Vector3(cos(a) * 0.12, 0.08, sin(a) * 0.12), Vector3(0, -rad_to_deg(a) + 90.0, 0))
			for d: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1)]:
				M.box(p, Vector3(0.07, 0.05, 0.03), ember, base + d * 0.115 + Vector3(0, 0.035, 0))
		2:
			# horno de ladrillo con bocas incandescentes
			var bricks := M.tex_mat("bricks", 3.0, Color(0.85, 0.55, 0.45))
			M.cyl(p, 0.12, 0.135, 0.13, bricks, base + Vector3(0, 0.065, 0), Vector3.ZERO, 12)
			M.cyl(p, 0.13, 0.13, 0.02, M.mat(STONE_DARK), base + Vector3(0, 0.125, 0), Vector3.ZERO, 12)
			for d: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0)]:
				var mouth := M.cyl(p, 0.035, 0.035, 0.03, ember, base + d * 0.122 + Vector3(0, 0.055, 0), Vector3(90, 0, 0), 10)
				mouth.rotation.y = atan2(d.x, d.z)
				M.box(p, Vector3(0.07, 0.035, 0.03), ember, base + d * 0.122 + Vector3(0, 0.035, 0), Vector3(0, rad_to_deg(atan2(d.x, d.z)), 0))
			pot_m = M.metal(COPPER)
		_:
			# brasero de mármol con bandas de oro y fuego infernal
			var marble := M.mat(MARBLE)
			var gold := M.metal(GOLD)
			var glow := M.mat(INFERNAL, 2.2)
			M.cyl(p, 0.12, 0.14, 0.14, marble, base + Vector3(0, 0.07, 0), Vector3.ZERO, 14)
			for y: float in [0.02, 0.135]:
				M.cyl(p, 0.145 if y < 0.1 else 0.128, 0.145 if y < 0.1 else 0.128, 0.02, gold, base + Vector3(0, y, 0), Vector3.ZERO, 14)
			for k in 6:
				var a := TAU * k / 6.0
				var g := M.box(p, Vector3(0.03, 0.06, 0.02), glow, base + Vector3(cos(a), 0, sin(a)) * 0.128 + Vector3(0, 0.07, 0))
				g.rotation.y = -a + PI * 0.5
			pot_m = gold
	# olla del caldero con borde, asas y brea
	var body_y := surf - r * 0.75
	if tier == 3:
		M.sphere(p, r + 0.022, M.metal(Color(0.2, 0.2, 0.24)), base + Vector3(0, body_y, 0), Vector3(1, 0.8, 1), 14)
		for k in 3:
			var a := TAU * k / 3.0
			M.sphere(p, 0.02, pot_m, base + Vector3(cos(a), 0, sin(a)) * (r + 0.01) + Vector3(0, body_y - 0.05, 0), Vector3(1, 1.3, 1), 6)
	M.sphere(p, r + 0.02, pot_m, base + Vector3(0, body_y, 0), Vector3(1, 0.85, 1), 14)
	var rim := TorusMesh.new()
	rim.inner_radius = r - 0.004
	rim.outer_radius = r + 0.014
	M.add(p, rim, M.metal(GOLD) if tier == 3 else pot_m, base + Vector3(0, surf, 0))
	M.cyl(p, r, r, 0.012, tar_m, base + Vector3(0, surf - 0.004, 0), Vector3.ZERO, 14)
	for sx: float in [-1.0, 1.0]:
		var ear := TorusMesh.new()
		ear.inner_radius = 0.012
		ear.outer_radius = 0.02
		M.add(p, ear, pot_m, base + Vector3((r + 0.025) * sx, surf - 0.02, 0), Vector3(90, 0, 0))
	# grumos de brea en la superficie (y vetas ardientes en las etapas altas)
	if tier == 3:
		for k in 3:
			var a := TAU * k / 3.0 + 0.5
			M.sphere(p, 0.022, M.metal(TAR), base + Vector3(cos(a) * r * 0.5, surf + 0.002, sin(a) * r * 0.5), Vector3(1.3, 0.25, 1.0), 8)
	else:
		M.sphere(p, 0.02, M.metal(TAR), base + Vector3(r * 0.4, surf + 0.002, -r * 0.3), Vector3(1.3, 0.3, 1.0), 8)
		if tier >= 1:
			M.sphere(p, 0.012, ember, base + Vector3(-r * 0.45, surf + 0.002, r * 0.2), Vector3(1.4, 0.3, 1.0), 6)
	# cucharón de mango largo apoyado en el borde
	var ladle_m: Material = M.metal(GOLD) if tier == 3 else (M.mat(WOOD_DARK) if tier == 0 else iron)
	var inside := base + Vector3(-r * 0.3, surf + 0.01, -r * 0.2)
	var outside := base + Vector3(r * 0.4, surf + 0.17, -r * 1.6)
	M.segment(p, 0.009, ladle_m, inside, outside, 6)
	M.sphere(p, 0.012, ladle_m, outside, Vector3.ONE, 6)


# =====================================================================
# --- Mangonel (gira con el pivote) ---
# =====================================================================

func _frame_mats() -> Array[Material]:
	# [madera, madera oscura, herrajes, cuerda]
	match tier:
		0:
			return [M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36)), M.mat(Color(0.4, 0.26, 0.15)), M.mat(ROPE), M.mat(ROPE)]
		1:
			return [M.tex_mat("wood", 2.2, Color(0.8, 0.62, 0.46)), M.mat(WOOD_DARK), M.metal(IRON), M.mat(ROPE)]
		2:
			return [M.tex_mat("wood", 2.2, Color(0.62, 0.45, 0.33)), M.mat(Color(0.22, 0.14, 0.09)), M.metal(IRON), M.mat(Color(0.7, 0.6, 0.42))]
	return [M.tex_mat("wood", 2.2, Color(0.62, 0.4, 0.32)), M.mat(ROYAL), M.metal(GOLD), M.mat(Color(0.9, 0.82, 0.6))]


func _build_frame(c: Node3D) -> void:
	var mats := _frame_mats()
	var wood := mats[0]
	var dark := mats[1]
	var fit := mats[2]
	var rope := mats[3]
	var iron := M.metal(IRON)
	var leather := M.mat(LEATHER)
	# Largueros y travesaños
	for sx: float in [-1.0, 1.0]:
		M.box(c, Vector3(0.06, 0.06, 0.7), wood, Vector3(0.15 * sx, 0.04, 0.0))
		for z: float in [-0.33, 0.33]:
			M.box(c, Vector3(0.07, 0.07, 0.03), fit, Vector3(0.15 * sx, 0.04, z))
	for z: float in [-0.29, 0.06, 0.31]:
		M.box(c, Vector3(0.36, 0.045, 0.06), dark, Vector3(0, 0.05, z))
	# Postes del eje con tornapuntas
	for sx: float in [-1.0, 1.0]:
		var top := Vector3(0.15 * sx, AXLE.y, AXLE.z)
		M.box(c, Vector3(0.055, AXLE.y + 0.02, 0.07), wood, Vector3(0.15 * sx, (AXLE.y + 0.1) * 0.5, AXLE.z))
		M.box(c, Vector3(0.065, 0.04, 0.08), fit, top + Vector3(0, 0.06, 0))
		M.segment(c, 0.022, wood, Vector3(0.15 * sx, 0.07, -0.25), top + Vector3(0, 0.03, -0.03), 6)
		M.segment(c, 0.022, wood, Vector3(0.15 * sx, 0.07, 0.2), top + Vector3(0, 0.03, 0.03), 6)
		# poste delantero del tope
		M.segment(c, 0.024, wood, Vector3(0.15 * sx, 0.07, -0.26), Vector3(0.15 * sx, 0.53, -0.2), 6)
		M.segment(c, 0.016, dark, Vector3(0.15 * sx, 0.07, -0.05), Vector3(0.15 * sx, 0.42, -0.21), 6)
	# Travesaño del tope con cojín de cuero
	M.box(c, Vector3(0.36, 0.05, 0.05), dark, Vector3(0, 0.51, -0.2))
	M.sphere(c, 0.04, leather, Vector3(0, 0.5, -0.165), Vector3(1.4, 1.0, 0.7), 10)
	M.box(c, Vector3(0.1, 0.012, 0.03), fit, Vector3(0, 0.53, -0.17))
	# Madeja de torsión alrededor del eje, con ruedas de trinquete y palancas
	M.cyl(c, 0.05, 0.05, 0.24, rope, AXLE, Vector3(0, 0, 90), 12)
	for k in 5:
		M.cyl(c, 0.054, 0.054, 0.01, M.mat(ROPE.darkened(0.3)), AXLE + Vector3(-0.1 + k * 0.05, 0, 0), Vector3(0, 0, 90), 12)
	M.cyl(c, 0.016, 0.016, 0.44, iron, AXLE, Vector3(0, 0, 90), 8)
	for sx: float in [-1.0, 1.0]:
		var hub := AXLE + Vector3(0.2 * sx, 0, 0)
		M.cyl(c, 0.055, 0.055, 0.025, fit, hub, Vector3(0, 0, 90), 12)
		for k in 8:
			var a := TAU * k / 8.0
			M.box(c, Vector3(0.026, 0.02, 0.02), fit, hub + Vector3(0, sin(a) * 0.06, cos(a) * 0.06), Vector3(rad_to_deg(a), 0, 0))
		M.box(c, Vector3(0.02, 0.2, 0.025), dark, hub + Vector3(0.018 * sx, 0.0, 0), Vector3(30, 0, 0))
		if tier == 3:
			M.sphere(c, 0.02, M.mat(INFERNAL, 2.2), hub + Vector3(0.02 * sx, 0, 0), Vector3.ONE, 8)
	# Torno con cuerda (las manivelas se animan aparte)
	for sx: float in [-1.0, 1.0]:
		M.box(c, Vector3(0.03, DRUM.y + 0.02, 0.06), wood, Vector3(0.15 * sx, DRUM.y * 0.5 + 0.04, DRUM.z))
	M.cyl(c, 0.04, 0.04, 0.26, dark if tier != 3 else wood, DRUM, Vector3(0, 0, 90), 12)
	for k in 3:
		M.cyl(c, 0.045, 0.045, 0.02, rope, DRUM + Vector3(-0.05 + k * 0.05, 0, 0), Vector3(0, 0, 90), 12)
	# Detalles por etapa
	match tier:
		0:
			# ruedas macizas y ataduras de cuerda
			for sx: float in [-1.0, 1.0]:
				for wz: float in [-0.24, 0.24]:
					M.cyl(c, 0.07, 0.07, 0.035, dark, Vector3(0.2 * sx, 0.03, wz), Vector3(0, 0, 90), 12)
					M.cyl(c, 0.022, 0.022, 0.04, wood, Vector3(0.21 * sx, 0.03, wz), Vector3(0, 0, 90), 8)
		1:
			for sx: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.065, 0.12, 0.012), fit, Vector3(0.15 * sx, 0.12, AXLE.z + 0.04))
		2:
			# planchas de hierro remachadas y escuditos en los largueros
			for sx: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.065, 0.065, 0.16), fit, Vector3(0.15 * sx, 0.04, -0.27))
				for z: float in [-0.32, -0.27, -0.22]:
					M.sphere(c, 0.008, M.metal(STEEL), Vector3(0.184 * sx, 0.05, z), Vector3.ONE, 4)
				Arch.heater(c, Vector3(0.185 * sx, 0.08, 0.17), PI * 0.5 * sx, 0.7, M.mat(SOOT), M.mat(ORANGE), fit)
		3:
			# paneles azul real con filete de oro y gemas verdes
			for sx: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.012, 0.045, 0.5), M.mat(ROYAL), Vector3(0.183 * sx, 0.04, 0.0))
				M.box(c, Vector3(0.014, 0.012, 0.52), fit, Vector3(0.184 * sx, 0.066, 0.0))
				M.box(c, Vector3(0.014, 0.012, 0.52), fit, Vector3(0.184 * sx, 0.014, 0.0))
				for z: float in [-0.15, 0.15]:
					M.sphere(c, 0.014, M.mat(INFERNAL, 2.2), Vector3(0.19 * sx, 0.04, z), Vector3(0.6, 1, 1), 8)
				M.sphere(c, 0.022, fit, Vector3(0.15 * sx, 0.56, -0.2), Vector3.ONE, 8)


# Brazo con la cuchara (eje +Y del brazo; la cuchara se abre hacia -Z del brazo)
func _build_arm(a: Node3D) -> void:
	var mats := _frame_mats()
	var wood := mats[0]
	var dark := mats[1]
	var fit := mats[2]
	var rope := mats[3]
	var tail := 0.08
	M.box(a, Vector3(0.055, ARM_LEN + tail, 0.06), wood, Vector3(0, (ARM_LEN - tail) * 0.5, 0))
	# flejes (en la Maestría, bandas azules con filete de oro)
	for y: float in [0.06, 0.18, 0.3]:
		if tier == 3:
			M.box(a, Vector3(0.068, 0.04, 0.072), M.mat(ROYAL), Vector3(0, y, 0))
			M.box(a, Vector3(0.072, 0.01, 0.076), fit, Vector3(0, y + 0.02, 0))
			M.box(a, Vector3(0.072, 0.01, 0.076), fit, Vector3(0, y - 0.02, 0))
		else:
			M.box(a, Vector3(0.068, 0.025, 0.072), fit, Vector3(0, y, 0))
	if tier == 3:
		M.sphere(a, 0.016, M.mat(INFERNAL, 2.2), Vector3(0, 0.24, -0.032), Vector3(1, 1.4, 0.5), 8)
	# gancho de la cuerda del torno
	var hook := TorusMesh.new()
	hook.inner_radius = 0.01
	hook.outer_radius = 0.018
	M.add(a, hook, M.metal(IRON) if tier < 3 else fit, Vector3(0, ARM_LEN * 0.78, 0.04), Vector3(0, 0, 90))
	# Cuchara: cuenco que se abre hacia -Z del brazo
	var cup := Vector3(0, ARM_LEN, -0.04)
	match tier:
		0:
			M.cyl(a, 0.07, 0.045, 0.06, dark, cup, Vector3(-90, 0, 0), 12)
			M.cyl(a, 0.074, 0.074, 0.014, rope, cup + Vector3(0, 0, -0.028), Vector3(-90, 0, 0), 12)
		_:
			M.cyl(a, 0.075, 0.048, 0.065, dark if tier < 3 else M.metal(GOLD), cup, Vector3(-90, 0, 0), 14)
			M.cyl(a, 0.08, 0.08, 0.014, fit, cup + Vector3(0, 0, -0.03), Vector3(-90, 0, 0), 14)
			for k in 4:
				var ang := TAU * k / 4.0 + PI * 0.25
				M.box(a, Vector3(0.012, 0.012, 0.06), fit, cup + Vector3(cos(ang) * 0.062, sin(ang) * 0.062, 0.0))
	M.cyl(a, 0.06, 0.06, 0.012, M.metal(TAR), cup + Vector3(0, 0, -0.026), Vector3(-90, 0, 0), 12)
	# remate de la punta
	M.box(a, Vector3(0.07, 0.03, 0.07), fit, Vector3(0, ARM_LEN + 0.02, 0.0))


# Olla de brea ardiendo, manivelas del torno, cuerda y brazos del ingeniero
func _build_moving_parts() -> void:
	var mats := _frame_mats()
	var dark := mats[1]
	var fit := mats[2]
	# Olla de brea (su +Y apunta hacia la boca de la cuchara)
	_pot = Node3D.new()
	_pot.position = POT_LOCAL
	_pot.rotation.x = -PI * 0.5
	_arm.add_child(_pot)
	var glow_col := INFERNAL if tier == 3 else FIRE
	M.sphere(_pot, 0.046, M.mat(CLAY) if tier < 3 else M.mat(Color(0.2, 0.22, 0.2)), Vector3(0, 0.0, 0), Vector3(1, 0.9, 1), 12)
	M.cyl(_pot, 0.03, 0.034, 0.02, M.metal(TAR), Vector3(0, 0.038, 0), Vector3.ZERO, 10)
	if tier >= 2:
		var band := TorusMesh.new()
		band.inner_radius = 0.042
		band.outer_radius = 0.05
		M.add(_pot, band, M.mat(glow_col, 1.6) if tier == 3 else M.metal(IRON), Vector3(0, 0.005, 0))
	M.sphere(_pot, 0.016, M.mat(CREAM) if tier < 3 else M.mat(glow_col, 2.0), Vector3(0, 0.055, 0), Vector3(1, 0.8, 1), 6)
	_flames.append(Arch.flame_node(_pot, Vector3(0, 0.06, 0), 0.55, glow_col))
	# Manivelas del torno
	_crank = Node3D.new()
	_crank.position = DRUM
	cat_pivot.add_child(_crank)
	for sx: float in [-1.0, 1.0]:
		M.box(_crank, Vector3(0.02, 0.025, CRANK_R * 2.0 + 0.03), fit if tier > 0 else dark, Vector3(CRANK_X * sx, 0, 0))
	M.cyl(_crank, 0.012, 0.012, 0.09, dark, Vector3(CRANK_X + 0.05, 0, CRANK_R), Vector3(0, 0, 90), 6)
	M.cyl(_crank, 0.012, 0.012, 0.09, dark, Vector3(-CRANK_X - 0.05, 0, -CRANK_R), Vector3(0, 0, 90), 6)
	M.cyl(_crank, 0.014, 0.014, CRANK_X * 2.0, M.metal(IRON), Vector3.ZERO, Vector3(0, 0, 90), 6)
	# Cuerda del torno a la punta del brazo
	_cord = M.add(cat_pivot, M.tube_mesh(0.007, 4), M.mat(ROPE.darkened(0.15)))
	# Brazos del ingeniero (se reorientan cada fotograma)
	var sleeve: Material = [M.mat(Color(0.55, 0.45, 0.32)), M.mat(LEATHER), M.metal(Color(0.43, 0.45, 0.49)), M.metal(Color(0.82, 0.84, 0.9))][tier]
	var glove: Material = M.mat(Human.SKIN) if tier == 0 else (M.metal(GOLD) if tier == 3 else M.mat(LEATHER_DARK))
	_arm_l = M.add(cat_pivot, M.tube_mesh(0.04, 8), sleeve)
	_arm_r = M.add(cat_pivot, M.tube_mesh(0.04, 8), sleeve)
	_hand_l = M.sphere(cat_pivot, 0.042, glove, Vector3.ZERO, Vector3.ONE, 8)
	_hand_r = M.sphere(cat_pivot, 0.042, glove, Vector3.ZERO, Vector3.ONE, 8)


# =====================================================================
# --- Ingeniero ---
# =====================================================================

# Gafas de latón sobre la frente (las del ingeniero de brea)
static func _goggles(h: Node3D, frame: Material, lens: Material, y: float) -> void:
	for sx: float in [-1.0, 1.0]:
		M.cyl(h, 0.032, 0.032, 0.03, frame, Vector3(0.048 * sx, y, -0.128), Vector3(90, 0, 0), 10)
		M.cyl(h, 0.023, 0.023, 0.032, lens, Vector3(0.048 * sx, y, -0.131), Vector3(90, 0, 0), 10)
	M.box(h, Vector3(0.03, 0.012, 0.012), frame, Vector3(0, y, -0.14))


# Ingeniero: peón con delantal y gorro de lana (0), artesano con gafas (1),
# zapador con cota y tabardo negro (2) o maestro de asedio en armadura con capa azul real (3)
func _build_engineer(c: Node3D) -> void:
	var leather := M.mat(LEATHER)
	var leather_dark := M.mat(LEATHER_DARK)
	var tar := M.metal(TAR)
	var gold := M.metal(GOLD)
	var brass := M.metal(BRASS)
	match tier:
		0:
			Human.body(c, M.mat(Color(0.55, 0.45, 0.32)), M.mat(Color(0.42, 0.32, 0.2)))
		1:
			Human.body(c, M.mat(Color(0.42, 0.44, 0.5)), leather_dark)
			M.box(c, Vector3(0.2, 0.2, 0.03), leather, Vector3(0, 0.2, -0.11), Vector3(-6, 0, 0))
		2:
			Human.body(c, M.metal(Color(0.43, 0.45, 0.49)), leather_dark)
			M.box(c, Vector3(0.18, 0.27, 0.02), M.mat(SOOT), Vector3(0, 0.13, -0.124), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.18, 0.27, 0.02), M.mat(SOOT), Vector3(0, 0.13, 0.124), Vector3(4, 0, 0))
			for k: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.09, 0.024, 0.012), M.mat(ORANGE), Vector3(0.03 * k, 0.17, -0.137), Vector3(-4, 0, 38.0 * k))
			for sx: float in [-1.0, 1.0]:
				M.sphere(c, 0.07, M.metal(STEEL), Vector3(0.135 * sx, 0.285, 0), Vector3(1, 0.7, 1), 10)
		_:
			Human.body(c, M.metal(Color(0.82, 0.84, 0.9)), gold)
			var royal := M.mat(ROYAL)
			M.box(c, Vector3(0.18, 0.27, 0.02), royal, Vector3(0, 0.13, -0.124), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.19, 0.02, 0.024), gold, Vector3(0, 0.0, -0.13), Vector3(-4, 0, 0))
			M.sphere(c, 0.022, M.mat(INFERNAL, 2.2), Vector3(0, 0.17, -0.138), Vector3(1, 1.2, 0.4), 8)
			M.box(c, Vector3(0.012, 0.25, 0.024), gold, Vector3(-0.088, 0.13, -0.126), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.012, 0.25, 0.024), gold, Vector3(0.088, 0.13, -0.126), Vector3(-4, 0, 0))
			for sx: float in [-1.0, 1.0]:
				M.sphere(c, 0.072, gold, Vector3(0.135 * sx, 0.285, 0), Vector3(1, 0.7, 1), 10)
			# capa azul real con borde dorado
			M.box(c, Vector3(0.27, 0.32, 0.02), royal, Vector3(0, 0.15, 0.145), Vector3(10, 0, 0))
			M.box(c, Vector3(0.28, 0.025, 0.026), gold, Vector3(0, 0.0, 0.172), Vector3(10, 0, 0))
	if tier <= 1:
		# delantal de cuero manchado de brea
		M.box(c, Vector3(0.19, 0.24, 0.02), leather if tier == 0 else M.mat(Color(0.36, 0.22, 0.12)), Vector3(0, 0.1, -0.142), Vector3(-6, 0, 0))
		for sp: Vector3 in [Vector3(-0.04, 0.05, -0.155), Vector3(0.05, 0.13, -0.15), Vector3(0.0, 0.0, -0.16)]:
			M.sphere(c, 0.022, tar, sp, Vector3(1.2, 1.0, 0.25), 6)
	var belt := TorusMesh.new()
	belt.inner_radius = 0.135
	belt.outer_radius = 0.16
	M.add(c, belt, leather_dark, Vector3(0, 0.1, 0))
	M.box(c, Vector3(0.04, 0.03, 0.03), gold if tier == 3 else brass, Vector3(0, 0.1, -0.155))
	# martillo y cucharón al cinto
	M.box(c, Vector3(0.02, 0.12, 0.02), M.mat(WOOD_DARK), Vector3(0.16, 0.06, 0.02), Vector3(0, 0, 10))
	M.box(c, Vector3(0.06, 0.03, 0.03), M.metal(IRON), Vector3(0.17, 0.12, 0.02))
	for sx: float in [-1.0, 1.0]:
		M.cyl(c, 0.045, 0.05, 0.05, leather_dark if tier < 3 else gold, Vector3(0.06 * sx, 0.01, -0.02), Vector3.ZERO, 8)
	# cabeza con barba y tocado según la etapa
	var beard := Color(0.5, 0.3, 0.14) if tier != 3 else Color(0.85, 0.85, 0.82)
	var h := Human.head(c, true, tier < 2, beard)
	M.sphere(h, 0.08, M.mat(beard), Vector3(0, -0.09, -0.06), Vector3(1.1, 0.8, 0.8), 10)
	M.box(h, Vector3(0.04, 0.008, 0.01), M.mat(Color(0.6, 0.3, 0.28)), Vector3(0, -0.07, -0.138))
	match tier:
		0:
			# gorro de lana caído hacia atrás y tizne en la mejilla
			var wool := M.mat(Color(0.6, 0.22, 0.16))
			M.sphere(h, 0.145, wool, Vector3(0, 0.07, 0.02), Vector3(1.0, 0.75, 1.0), 14)
			M.sphere(h, 0.07, wool, Vector3(0, 0.1, 0.13), Vector3(1.0, 0.8, 1.2), 10)
			M.cyl(h, 0.148, 0.148, 0.03, M.mat(Color(0.5, 0.18, 0.13)), Vector3(0, 0.03, 0.02), Vector3(-6, 0, 0), 14)
			M.sphere(h, 0.018, M.mat(SOOT), Vector3(-0.07, -0.02, -0.116), Vector3(1.3, 0.8, 0.3), 6)
		1:
			# gorro de cuero con gafas de latón
			M.sphere(h, 0.148, leather, Vector3(0, 0.07, 0.025), Vector3(1.0, 0.72, 1.0), 14)
			var band := TorusMesh.new()
			band.inner_radius = 0.13
			band.outer_radius = 0.155
			M.add(h, band, leather_dark, Vector3(0, 0.07, 0.02), Vector3(-8, 0, 0))
			_goggles(h, brass, M.mat(Color(0.55, 0.75, 0.8), 0.6), 0.08)
		2:
			# capacete de acero con gafas
			var helm := M.metal(STEEL)
			M.sphere(h, 0.15, helm, Vector3(0, 0.07, 0.02), Vector3(1.0, 0.8, 1.0), 14)
			M.cyl(h, 0.16, 0.2, 0.025, helm, Vector3(0, 0.035, 0.02), Vector3.ZERO, 16)
			M.box(h, Vector3(0.02, 0.03, 0.17), M.metal(IRON), Vector3(0, 0.17, 0.03))
			_goggles(h, brass, M.mat(Color(1.0, 0.6, 0.2), 1.2), 0.085)
		_:
			# yelmo plateado con cresta de oro, penacho azul y gafas de lentes verdes
			var helm := M.metal(Color(0.85, 0.87, 0.92))
			M.sphere(h, 0.15, helm, Vector3(0, 0.07, 0.02), Vector3(1.0, 0.8, 1.0), 14)
			M.cyl(h, 0.16, 0.2, 0.025, gold, Vector3(0, 0.035, 0.02), Vector3.ZERO, 16)
			M.box(h, Vector3(0.024, 0.04, 0.18), gold, Vector3(0, 0.17, 0.03))
			for k in 3:
				M.sphere(h, 0.036, M.mat(ROYAL) if k != 1 else M.mat(Color(0.97, 0.96, 0.94)), Vector3(0, 0.2 + k * 0.012, 0.06 + k * 0.04), Vector3(0.6, 1.0, 1.4), 8)
			_goggles(h, gold, M.mat(INFERNAL, 2.0), 0.085)


# =====================================================================
# --- Efectos (burbujas, llamas, humo, banderolas y aura) ---
# =====================================================================

func _build_cauldron_fx() -> void:
	var py: float = PLAT_BY_TIER[tier]
	var surf: float = CAUL_SURF[tier]
	var r: float = CAUL_R[tier]
	var base := CAUL + Vector3(0, py, 0)
	var bub_m: Material = M.mat(INFERNAL, 2.0) if tier == 3 else M.metal(TAR_SHEEN)
	for k in 4:
		var a := TAU * k / 4.0 + 0.3
		var b := Node3D.new()
		var bp := base + Vector3(cos(a) * r * 0.55, surf + 0.004, sin(a) * r * 0.55)
		b.position = bp
		b.set_meta("base", bp)
		add_child(b)
		M.sphere(b, 0.017 - k * 0.002, bub_m, Vector3.ZERO, Vector3(1, 0.8, 1), 8)
		_bubbles.append(b)
	var fire_col := Color(0.55, 1.0, 0.3) if tier == 3 else FIRE
	match tier:
		0:
			_flames.append(Arch.flame_node(self, base + Vector3(0, 0.02, 0), 1.0, fire_col))
			_flames.append(Arch.flame_node(self, base + Vector3(0.04, 0.01, 0.03), 0.7, fire_col))
		1:
			for d: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1)]:
				_flames.append(Arch.flame_node(self, base + d * 0.13 + Vector3(0, 0.02, 0), 0.55, fire_col))
		_:
			for d: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0)]:
				_flames.append(Arch.flame_node(self, base + d * 0.14 + Vector3(0, 0.03, 0), 0.6, fire_col))
	var smoke_col := Color(0.25, 0.42, 0.2) if tier == 3 else Color(0.2, 0.19, 0.19)
	add_child(_smoke(smoke_col, base + Vector3(0, surf + 0.03, 0), 6 + tier * 2, 0.025 + tier * 0.003))


func _build_tier_fx() -> void:
	var py: float = PLAT_BY_TIER[tier]
	match tier:
		0:
			_pennants.append(Arch.pennant_node(self, Vector3(0.38, 0.52, 0.36), SOOT, ORANGE, 0.2, 2.6))
		1:
			_pennants.append(Arch.pennant_node(self, Vector3(-0.38, py + 0.58, -0.38), SOOT, ORANGE, 0.24, 0.6))
		2:
			for sz: float in [-1.0, 1.0]:
				for sx: float in [-1.0, 1.0]:
					_flames.append(Arch.flame_node(self, Vector3(0.24 * sx, py - 0.16, 0.43 * sz) + Vector3(0, 0, 0.075 * sz) + Vector3(0, 0.05, 0)))
			_pennants.append(Arch.pennant_node(self, Vector3(0.37, py + 0.24 + 0.015 + 0.32 + 0.18, 0.37), SOOT, ORANGE, 0.26, 2.4))
			_pennants.append(Arch.pennant_node(self, Vector3(-0.37, py + 0.24 + 0.015 + 0.32 + 0.18, -0.37), SOOT, ORANGE, 0.26, 0.6))
		_:
			var green := Color(0.55, 1.0, 0.3)
			for sz: float in [-1.0, 1.0]:
				for sx: float in [-1.0, 1.0]:
					_flames.append(Arch.flame_node(self, Vector3(0.25 * sx, py - 0.2, 0.43 * sz) + Vector3(0, 0, 0.075 * sz) + Vector3(0, 0.05, 0), 1.1, green))
			_pennants.append(Arch.pennant_node(self, Vector3(0.37, py + 0.24 + 0.015 + 0.4 + 0.22, 0.37), ROYAL, GOLD, 0.3, 2.4))
			_pennants.append(Arch.pennant_node(self, Vector3(-0.37, py + 0.24 + 0.015 + 0.4 + 0.22, -0.37), ROYAL, GOLD, 0.3, 0.6))
			_spinners.append(Arch.aura_ring(self, 0.47, INFERNAL, py * 0.36 + 0.02))
			add_child(Arch.sparkles(INFERNAL, Vector3(0, py + 0.4, 0), Vector3(0.42, 0.4, 0.42), 20, 0.012))
