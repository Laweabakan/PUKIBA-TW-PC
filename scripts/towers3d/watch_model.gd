extends Node3D
## Modelo 3D de la "Atalaya del Vigía" (id watch): la torre más alta y esbelta del juego.
## Etapas:
##  0 = atalaya de troncos sobre patas arriostradas, con escalera y un brasero de señales en un mástil.
##  1 = zócalo de sillares con fuste de entramado, cadalso de tablas, brasero grande y garita de tejas.
##  2 = gran torre de piedra con matacanes, almenas y un torreón-linterna (faro) en la esquina.
##  3 = Maestría: torre de mármol y oro con torreones de pizarra azul y el Ojo que Todo lo Ve,
##      un faro dorado que flota y gira vigilando en todas direcciones.
## Arriba, un vigía arquero con arco largo y catalejo en el cinto. Cuando no hay enemigo
## se lleva el catalejo al ojo; al detectar uno, tensa el arco. Mira hacia -Z dentro de cat_pivot.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const Arch := preload("res://scripts/towers3d/archer_model.gd")

const TIMBER := Color(0.3, 0.19, 0.1)
const IRON := Color(0.24, 0.24, 0.27)
const STEEL := Color(0.5, 0.52, 0.57)
const BRASS := Color(0.86, 0.66, 0.3)
const GOLD := Color(0.95, 0.75, 0.3)
const ROPE := Color(0.82, 0.7, 0.5)
const LEATHER := Color(0.4, 0.25, 0.13)
const FOREST := Color(0.22, 0.4, 0.2)
const RED := Color(0.72, 0.14, 0.12)
const CREAM := Color(0.95, 0.9, 0.78)
const MARBLE := Color(0.97, 0.95, 0.9)
const ROYAL := Color(0.16, 0.26, 0.62)
const EMBER := Color(1.0, 0.5, 0.12)
const LAMP := Color(1.0, 0.82, 0.45)
const EYE_GLOW := Color(0.5, 0.8, 1.0)
const BOW_WOOD := Color(0.55, 0.3, 0.13)

# Altura de la plataforma del vigía según la etapa (es la torre más alta)
const PLAT_BY_TIER := [1.15, 1.32, 1.48, 1.6]
# Arco largo (coordenadas locales del vigía): arco de circunferencia poco curvado
const BOW_X := -0.16
const BOW_Y := 0.34
const BOW_C_Z := 0.28
const BOW_R := 0.5
const BOW_SPAN := 0.72
const FULL_PULL_Z := 0.03
const ARROW_LEN := 0.5
const R_SHOULDER := Vector3(0.13, 0.27, -0.02)
const L_SHOULDER := Vector3(-0.13, 0.27, -0.02)
# Catalejo: ocular junto al ojo derecho o colgado del cinto
const EYE_R := Vector3(0.048, 0.47, -0.135)
const HIP := Vector3(0.185, 0.22, -0.02)

var cat_pivot: Node3D
var tier := 0
var _cape: Node3D
var _str_top: MeshInstance3D
var _str_bot: MeshInstance3D
var _nocked: Node3D
var _arm_r: MeshInstance3D
var _hand_r: MeshInstance3D
var _glass: Node3D
var _tip_top: Vector3
var _tip_bot: Vector3
var _flames: Array[Node3D] = []
var _pennants: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _floaters: Array[Node3D] = []


func _init(level := 0) -> void:
	tier = Arch.tier_of(level)
	M.add_baked(self, M.baked("watch_tower_t%d" % tier, _build_tower))
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, PLAT_BY_TIER[tier], 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("watch_man_t%d" % tier, _build_man))
	_build_moving_parts()
	_build_tier_fx()
	animate({"t": 0.0, "charge": 0.0, "fire": 0.0, "has_target": false})


static func bow_point(a: float) -> Vector3:
	return Vector3(BOW_X, BOW_Y + BOW_R * sin(a), BOW_C_Z - BOW_R * cos(a))


## s = {t, charge (0..1), fire (1 -> 0), has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = s.get("charge", 0.0)
	var fire: float = s.get("fire", 0.0)
	var has_target: bool = s.get("has_target", false)
	var scouting := not has_target and fire <= 0.0
	var pull := charge if has_target else 0.0
	# Cuerda del arco largo: se tensa con la carga y vibra al soltar
	var nz := lerpf(_tip_top.z, FULL_PULL_Z, pull)
	if fire > 0.0:
		nz = _tip_top.z + sin(t * 90.0) * fire * 0.03
	var nock := Vector3(BOW_X, BOW_Y, nz)
	M.orient_segment(_str_bot, _tip_bot, nock)
	M.orient_segment(_str_top, nock, _tip_top)
	_nocked.visible = has_target and fire <= 0.05
	_nocked.position = nock
	var hand: Vector3
	if scouting:
		# Sin enemigos: otea el horizonte con el catalejo, barriendo despacio
		_glass.position = EYE_R
		_glass.rotation = Vector3(0.06 + sin(t * 0.7) * 0.03, sin(t * 0.45) * 0.14, 0.0)
		hand = _glass.transform * Vector3(0, -0.026, -0.12)
	else:
		# Catalejo colgado del cinto; la mano derecha tensa la cuerda
		_glass.position = HIP
		_glass.rotation = Vector3(deg_to_rad(-78.0), 0.0, deg_to_rad(6.0))
		if fire > 0.0:
			hand = Vector3(BOW_X + 0.05, BOW_Y + 0.03, FULL_PULL_Z + 0.06)
		else:
			hand = nock + Vector3(0.02, 0, 0.03)
	_hand_r.position = hand
	M.orient_segment(_arm_r, R_SHOULDER, hand)
	_cape.rotation.x = -deg_to_rad(14.0 + sin(t * 4.0) * 6.0)
	Arch.animate_fx(t, _flames, _pennants, _spinners, _floaters)


## Punta de la flecha cargada (posición global)
func muzzle_global() -> Vector3:
	return cat_pivot.to_global(Vector3(BOW_X, BOW_Y, FULL_PULL_Z - ARROW_LEN))


# =====================================================================
# --- Utilidades de la torre ---
# =====================================================================

# Fuste troncopiramidal de planta cuadrada (semiancho h0 abajo y h1 arriba)
static func _taper(p: Node3D, y0: float, y1: float, h0: float, h1: float, m: Material) -> void:
	M.cyl(p, h1 / 0.7071, h0 / 0.7071, y1 - y0, m, Vector3(0, (y0 + y1) * 0.5, 0), Vector3(0, 45, 0), 4)


static func _half_at(y: float, y0: float, y1: float, h0: float, h1: float) -> float:
	return lerpf(h0, h1, clampf((y - y0) / (y1 - y0), 0.0, 1.0))


# Sillares de esquina alternados (cadena de esquina) a lo largo del fuste
static func _quoins(p: Node3D, y0: float, y1: float, h0: float, h1: float, mats: Array) -> void:
	var n := int((y1 - y0 - 0.04) / 0.1)
	for k in n:
		var y := y0 + 0.06 + k * 0.1
		var hh := _half_at(y, y0, y1, h0, h1)
		var i := 0
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var along_x := (k + i) % 2 == 0
				var size := Vector3(0.11 if along_x else 0.075, 0.08, 0.075 if along_x else 0.11)
				var pos := Vector3(sx * (hh - size.x * 0.5 + 0.012), y, sz * (hh - size.z * 0.5 + 0.012))
				M.box(p, size, mats[(k + i) % mats.size()], pos)
				i += 1


# Saetera con marco de piedra en una cara del fuste
static func _slit(p: Node3D, face: Vector3, y: float, hh: float, frame: Material, hole: Material) -> void:
	var n := Node3D.new()
	n.position = face * hh + Vector3(0, y, 0)
	n.rotation.y = atan2(face.x, face.z)
	p.add_child(n)
	M.box(n, Vector3(0.07, 0.17, 0.03), frame, Vector3(0, 0, 0.004))
	M.box(n, Vector3(0.026, 0.13, 0.03), hole, Vector3(0, 0, 0.012))
	M.box(n, Vector3(0.07, 0.026, 0.03), hole, Vector3(0, 0.0, 0.01))


# Imposta (cornisa fina) alrededor del fuste a la altura y
static func _band(p: Node3D, hh: float, y: float, m: Material, th := 0.035) -> void:
	M.box(p, Vector3(2.0 * hh + 0.05, th, 2.0 * hh + 0.05), m, Vector3(0, y, 0))


# Matacanes: ménsulas que sostienen la plataforma volada sobre el fuste
static func _corbels(p: Node3D, hh: float, py: float, n: int, mats: Array, gap: Material) -> void:
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, face.x)
		for k in n:
			var o := -hh + 0.04 + k * (2.0 * hh - 0.08) / float(n - 1)
			var size := Vector3(0.05, 0.13, 0.1) if absf(face.z) > 0.5 else Vector3(0.1, 0.13, 0.05)
			M.box(p, size, mats[k % mats.size()], face * (hh + 0.04) + tg * o + Vector3(0, py - 0.15, 0))
			M.box(p, size * Vector3(0.9, 0.5, 0.9), mats[(k + 1) % mats.size()], face * (hh + 0.06) + tg * o + Vector3(0, py - 0.235, 0))
			if k < n - 1:
				var o2 := o + (2.0 * hh - 0.08) / float(n - 1) * 0.5
				M.box(p, Vector3(0.05, 0.03, 0.05), gap, face * (hh + 0.075) + tg * o2 + Vector3(0, py - 0.095, 0))


# Brasero de hierro con brasas (la llama animada va aparte en _build_tier_fx)
static func _brazier(p: Node3D, pos: Vector3, s: float, iron: Material, coal: Material) -> void:
	M.cyl(p, 0.09 * s, 0.05 * s, 0.08 * s, iron, pos, Vector3.ZERO, 12)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.085 * s
	rim.outer_radius = 0.1 * s
	M.add(p, rim, iron, pos + Vector3(0, 0.04 * s, 0))
	for k in 6:
		var a := TAU * k / 6.0
		M.segment(p, 0.008 * s, iron, pos + Vector3(cos(a) * 0.05, -0.04, sin(a) * 0.05) * s, pos + Vector3(cos(a) * 0.1, 0.07, sin(a) * 0.1) * s, 4)
	M.sphere(p, 0.075 * s, coal, pos + Vector3(0, 0.045 * s, 0), Vector3(1, 0.4, 1), 10)


# Leña apilada (combustible para las señales)
static func _woodpile(p: Node3D, pos: Vector3, yaw: float, bark: Material, cut: Material) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	p.add_child(n)
	var rows := [[-0.06, 0.0, 0.06], [-0.03, 0.03], [0.0]]
	for r in rows.size():
		var row: Array = rows[r]
		for x: float in row:
			M.cyl(n, 0.028, 0.028, 0.2, bark, Vector3(x, 0.028 + r * 0.048, 0), Vector3(90, 0, 0), 8)
			M.cyl(n, 0.022, 0.022, 0.204, cut, Vector3(x, 0.028 + r * 0.048, 0), Vector3(90, 0, 0), 8)


# =====================================================================
# --- Torre ---
# =====================================================================

func _build_tower(p: Node3D) -> void:
	match tier:
		0: _tower_t0(p)
		1: _tower_t1(p)
		2: _tower_t2(p)
		_: _tower_t3(p)


static func _leg0(sx: float, sz: float, y: float, py: float) -> Vector3:
	var r := lerpf(0.37, 0.235, y / (py + 0.3))
	return Vector3(r * sx, y, r * sz)


# Etapa 0: atalaya de troncos arriostrados con escalera larga y brasero en un mástil
func _tower_t0(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[0]
	var bark := M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36))
	var bark2 := M.tex_mat("wood", 2.5, Color(0.56, 0.42, 0.3))
	var log_dark := M.mat(Color(0.4, 0.26, 0.15))
	var plank_a := M.tex_mat("wood", 2.0, Color(0.9, 0.76, 0.56))
	var plank_b := M.tex_mat("wood", 2.0, Color(0.78, 0.62, 0.45))
	var cut := M.mat(Color(0.86, 0.72, 0.5))
	var rope := M.mat(ROPE)
	var iron := M.metal(IRON)
	var stone := M.mat(Color(0.58, 0.56, 0.52))
	var bone := M.mat(CREAM)
	M.cyl(p, 0.46, 0.48, 0.03, M.mat(Color(0.52, 0.4, 0.27)), Vector3(0, 0.015, 0), Vector3.ZERO, 16)
	var corners := [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]
	# Patas inclinadas sobre zapatas de piedra
	for c: Vector2 in corners:
		M.sphere(p, 0.085, stone, _leg0(c.x, c.y, 0.0, py) + Vector3(0, 0.03, 0), Vector3(1.2, 0.6, 1.2), 8)
		var top := _leg0(c.x, c.y, py + 0.3, py)
		M.segment(p, 0.046, bark, _leg0(c.x, c.y, 0.03, py), top, 8)
		M.cyl(p, 0.0, 0.046, 0.07, log_dark, top + Vector3(0, 0.035, 0), Vector3.ZERO, 8)
		for y: float in [0.42, 0.8, py + 0.1]:
			M.cyl(p, 0.052, 0.052, 0.03, rope, _leg0(c.x, c.y, y, py), Vector3.ZERO, 8)
	# Aspas de arriostramiento en tres tramos y largueros horizontales
	var levels := [0.06, 0.42, 0.8, py - 0.1]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		for k in 3:
			var y0: float = levels[k]
			var y1: float = levels[k + 1]
			M.segment(p, 0.02, log_dark, _leg0(a.x, a.y, y0, py), _leg0(b.x, b.y, y1, py), 6)
			M.segment(p, 0.02, log_dark, _leg0(b.x, b.y, y0, py), _leg0(a.x, a.y, y1, py), 6)
			var mid := (_leg0(a.x, a.y, (y0 + y1) * 0.5, py) + _leg0(b.x, b.y, (y0 + y1) * 0.5, py)) * 0.5
			M.sphere(p, 0.026, rope, mid, Vector3.ONE, 8)
		for y: float in [0.42, 0.8]:
			M.segment(p, 0.027, bark2, _leg0(a.x, a.y, y, py), _leg0(b.x, b.y, y, py), 6)
		# barandilla de troncos
		for y: float in [py + 0.11, py + 0.22]:
			M.segment(p, 0.018, bark, _leg0(a.x, a.y, y, py), _leg0(b.x, b.y, y, py), 6)
	# Vigas y tablones de la plataforma (en voladizo)
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.72, 0.05, 0.06), log_dark, Vector3(0, py - 0.07, 0.22 * s))
	for k in 7:
		var z := -0.3 + k * 0.1
		M.box(p, Vector3(0.64 + (k % 3) * 0.03, 0.04, 0.092), plank_a if k % 2 == 0 else plank_b,
				Vector3((k % 2) * 0.015 - 0.007, py - 0.02, z), Vector3(0, (k % 3 - 1) * 2.0, 0))
	# Escalera larga por la cara +X
	for sz: float in [-1.0, 1.0]:
		M.segment(p, 0.018, bark, Vector3(0.47, 0.0, 0.09 * sz), Vector3(0.31, py + 0.08, 0.09 * sz), 6)
	for k in 10:
		var f := (k + 0.6) / 10.5
		M.box(p, Vector3(0.025, 0.022, 0.2), log_dark, Vector3(lerpf(0.47, 0.31, f), f * (py + 0.08), 0))
	# Mástil de señales con brasero (esquina trasera izquierda)
	var mp := Vector3(-0.21, 0, -0.21)
	M.segment(p, 0.03, bark, mp + Vector3(0, py - 0.06, 0), mp + Vector3(0, py + 0.62, 0), 8)
	M.segment(p, 0.014, log_dark, mp + Vector3(0, py + 0.3, 0), mp + Vector3(0.07, py + 0.02, 0.07), 4)
	for y: float in [py + 0.15, py + 0.45]:
		M.cyl(p, 0.036, 0.036, 0.025, rope, mp + Vector3(0, y, 0), Vector3.ZERO, 8)
	_brazier(p, mp + Vector3(0, py + 0.66, 0), 1.0, iron, M.mat(EMBER, 1.6))
	# Asta del banderín (esquina trasera derecha)
	M.segment(p, 0.014, log_dark, Vector3(0.235, py + 0.28, -0.235), Vector3(0.235, py + 0.62, -0.235), 6)
	# Cuerno de aviso colgado de la barandilla frontal
	var horn := [Vector3(0.06, py + 0.17, 0.27), Vector3(0.11, py + 0.13, 0.28), Vector3(0.15, py + 0.14, 0.285), Vector3(0.17, py + 0.19, 0.29)]
	for k in 3:
		var ha: Vector3 = horn[k]
		var hb: Vector3 = horn[k + 1]
		M.segment(p, 0.012 + k * 0.006, bone, ha, hb, 6)
	M.cyl(p, 0.03, 0.022, 0.03, M.mat(LEATHER), horn[3] + Vector3(0, 0.01, 0), Vector3.ZERO, 8)
	# Leña, barril de flechas y rollo de cuerda al pie
	_woodpile(p, Vector3(-0.1, 0.0, 0.05), 0.3, bark2, cut)
	M.cyl(p, 0.06, 0.055, 0.15, plank_b, Vector3(0.12, 0.075, -0.12), Vector3.ZERO, 12)
	for y: float in [0.03, 0.12]:
		M.cyl(p, 0.063, 0.063, 0.014, log_dark, Vector3(0.12, y, -0.12), Vector3.ZERO, 12)
	for k in 4:
		var a := TAU * k / 4.0
		M.segment(p, 0.007, M.mat(BOW_WOOD), Vector3(0.12 + cos(a) * 0.025, 0.12, -0.12 + sin(a) * 0.025), Vector3(0.12 + cos(a) * 0.04, 0.27, -0.12 + sin(a) * 0.04), 4)
		M.box(p, Vector3(0.02, 0.035, 0.004), M.mat(RED) if k % 2 == 0 else bone, Vector3(0.12 + cos(a) * 0.04, 0.27, -0.12 + sin(a) * 0.04))
	var coil := TorusMesh.new()
	coil.inner_radius = 0.035
	coil.outer_radius = 0.06
	M.add(p, coil, rope, Vector3(-0.38, 0.018, 0.3))
	M.add(p, coil, rope, Vector3(-0.38, 0.04, 0.3), Vector3(0, 0, 8))
	Arch._ground_details(p, false)


# Etapa 1: zócalo de sillares, fuste de entramado, cadalso de tablas y garita con tejado de tejas
func _tower_t1(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[1]
	var wall := M.tex_mat("bricks", 2.2, Color(0.86, 0.84, 0.8))
	var stones := [M.mat(Color(0.62, 0.6, 0.56)), M.mat(Color(0.53, 0.51, 0.48)), M.mat(Color(0.7, 0.68, 0.64))]
	var dark := M.mat(Color(0.42, 0.4, 0.38))
	var timber := M.mat(TIMBER)
	var plaster := M.mat(Color(0.93, 0.89, 0.8))
	var plank := M.tex_mat("wood", 2.0, Color(0.82, 0.66, 0.48))
	var plank2 := M.tex_mat("wood", 2.0, Color(0.7, 0.55, 0.4))
	var shingle := M.tex_mat("roof", 3.0, Color(0.8, 0.5, 0.36))
	var iron := M.metal(IRON)
	var black := M.mat(Color(0.08, 0.07, 0.07))
	var gold := M.metal(GOLD)
	var glow := M.mat(Color(1.0, 0.78, 0.4), 0.9)
	# Zócalo troncopiramidal de sillares
	M.box(p, Vector3(0.86, 0.08, 0.86), dark, Vector3(0, 0.04, 0))
	_taper(p, 0.08, 0.72, 0.34, 0.27, wall)
	_quoins(p, 0.08, 0.72, 0.34, 0.27, stones)
	_band(p, 0.27, 0.73, stones[2], 0.045)
	Arch._door(p, 0.322, stones[2], M.mat(Color(0.36, 0.22, 0.11)), iron)
	M.box(p, Vector3(0.3, 0.05, 0.12), stones[1], Vector3(0, 0.025, 0.42))
	for face: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)]:
		_slit(p, face, 0.45, _half_at(0.45, 0.08, 0.72, 0.34, 0.27), stones[2], black)
	# Fuste alto de entramado (paredes encaladas, postes y aspas)
	var y0 := 0.75
	var y1 := py - 0.13
	var fh := y1 - y0
	M.box(p, Vector3(0.46, fh, 0.46), plaster, Vector3(0, (y0 + y1) * 0.5, 0))
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var f := Node3D.new()
		f.position = face * 0.232 + Vector3(0, (y0 + y1) * 0.5, 0)
		f.rotation.y = atan2(face.x, face.z)
		p.add_child(f)
		for x: float in [-0.21, 0.21]:
			M.box(f, Vector3(0.05, fh, 0.03), timber, Vector3(x, 0, 0))
		for y: float in [-fh * 0.5 + 0.02, fh * 0.5 - 0.02]:
			M.box(f, Vector3(0.47, 0.04, 0.032), timber, Vector3(0, y, 0))
		var ang := rad_to_deg(atan2(0.4, fh))
		M.box(f, Vector3(0.03, sqrt(0.16 + fh * fh) - 0.04, 0.02), timber, Vector3(0, 0, 0), Vector3(0, 0, ang))
		M.box(f, Vector3(0.03, sqrt(0.16 + fh * fh) - 0.04, 0.02), timber, Vector3(0, 0, 0), Vector3(0, 0, -ang))
		if face.z > 0.5 or face.z < -0.5:
			# ventanuco con luz y contraventanas
			M.box(f, Vector3(0.12, 0.13, 0.03), timber, Vector3(0, 0.02, 0.008))
			M.box(f, Vector3(0.08, 0.09, 0.03), glow, Vector3(0, 0.02, 0.014))
			for side: float in [-1.0, 1.0]:
				M.box(f, Vector3(0.045, 0.11, 0.015), M.mat(FOREST), Vector3(0.085 * side, 0.02, 0.026), Vector3(0, 22.0 * side, 0))
	# Jabalcones y plataforma volada
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, face.x)
		for o: float in [-0.15, 0.15]:
			M.segment(p, 0.018, timber, face * 0.24 + tg * o + Vector3(0, py - 0.32, 0), face * 0.33 + tg * o + Vector3(0, py - 0.08, 0), 6)
			M.box(p, Vector3(0.05, 0.05, 0.05), timber, face * 0.33 + tg * o + Vector3(0, py - 0.08, 0))
	M.box(p, Vector3(0.74, 0.06, 0.74), plank, Vector3(0, py - 0.04, 0))
	M.box(p, Vector3(0.76, 0.025, 0.76), timber, Vector3(0, py - 0.075, 0))
	# Cadalso: tablas con huecos y pasamanos
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, face.x)
		for k in 6:
			var o := -0.3 + k * 0.12
			var tall := 0.15 + (k % 2) * 0.03
			var sz := tg.abs() * 0.1 + face.abs() * 0.025 + Vector3(0, tall, 0)
			M.box(p, sz, plank2 if k % 2 == 0 else plank, face * 0.355 + tg * o + Vector3(0, py + tall * 0.5, 0))
		M.box(p, tg.abs() * 0.74 + face.abs() * 0.04 + Vector3(0, 0.03, 0), timber, face * 0.355 + Vector3(0, py + 0.06, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(p, Vector3(0.05, 0.24, 0.05), timber, Vector3(0.355 * sx, py + 0.1, 0.355 * sz))
	# Brasero grande sobre poste (esquina trasera izquierda)
	M.cyl(p, 0.03, 0.04, 0.32, iron, Vector3(-0.3, py + 0.16, -0.3), Vector3.ZERO, 8)
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		M.segment(p, 0.01, iron, Vector3(-0.3, py + 0.26, -0.3), Vector3(-0.3 + cos(a) * 0.08, py + 0.36, -0.3 + sin(a) * 0.08), 4)
	_brazier(p, Vector3(-0.3, py + 0.38, -0.3), 1.2, iron, M.mat(EMBER, 1.6))
	# Garita con tejado de tejas (esquina trasera derecha)
	var top := Arch.turret(p, Vector3(0.29, 0, -0.29), 0.095, py - 0.12, py + 0.24, plaster, shingle, 0.28, timber, gold)
	M.cyl(p, 0.007, 0.007, 0.22, iron, top + Vector3(0, 0.11, 0), Vector3.ZERO, 4)
	# Antorcha junto a la puerta
	Arch.wall_torch(p, Vector3(0.17, 0.48, 0.3), Vector3(0, 0, 1), iron)
	# Leña y escudo apoyados al pie
	_woodpile(p, Vector3(-0.4, 0.0, 0.2), 1.5708, M.tex_mat("wood", 2.5, Color(0.56, 0.42, 0.3)), M.mat(Color(0.86, 0.72, 0.5)))
	Arch.heater(p, Vector3(0.4, 0.12, 0.25), 1.2, 1.2, M.mat(FOREST), M.mat(CREAM), iron)
	Arch._ground_details(p, false)


# Etapa 2: gran torre de piedra con matacanes y un torreón-faro con linterna
func _tower_t2(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[2]
	var wall := M.tex_mat("bricks", 2.2, Color(0.88, 0.86, 0.82))
	var stones := [M.mat(Color(0.62, 0.6, 0.56)), M.mat(Color(0.53, 0.51, 0.48)), M.mat(Color(0.7, 0.68, 0.64))]
	var dark := M.mat(Color(0.4, 0.39, 0.37))
	var slate := M.tex_mat("roof", 3.0, Color(0.5, 0.56, 0.72))
	var iron := M.metal(IRON)
	var gold := M.metal(GOLD)
	var black := M.mat(Color(0.08, 0.07, 0.07))
	var y0 := 0.14
	var y1 := py - 0.2
	M.box(p, Vector3(0.9, 0.08, 0.9), dark, Vector3(0, 0.04, 0))
	M.box(p, Vector3(0.8, 0.07, 0.8), stones[1], Vector3(0, 0.105, 0))
	_taper(p, y0, y1, 0.35, 0.25, wall)
	_quoins(p, y0, y1, 0.35, 0.25, stones)
	for y: float in [0.6, 1.0]:
		_band(p, _half_at(y, y0, y1, 0.35, 0.25), y, stones[2])
	_corbels(p, 0.25, py, 5, stones, black)
	M.box(p, Vector3(0.72, 0.08, 0.72), stones[2], Vector3(0, py - 0.04, 0))
	Arch.parapet(p, 0.34, py + 0.045, 0.09, 0.06, wall)
	Arch.merlons(p, 0.34, py + 0.15, Vector3(0.1, 0.12, 0.1), 3, wall, stones[2])
	Arch._door(p, 0.335, stones[2], M.mat(Color(0.36, 0.22, 0.11)), iron)
	M.box(p, Vector3(0.34, 0.05, 0.12), stones[1], Vector3(0, 0.025, 0.44))
	for face: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]:
		for y: float in [0.8, 1.15]:
			if face.z > 0.5 and y < 1.0:
				continue
			_slit(p, face, y, _half_at(y, y0, y1, 0.35, 0.25), stones[2], black)
	# Torreón-faro (esquina trasera izquierda): fuste, galería y linterna con jaula de hierro
	var lp := Vector3(-0.3, 0, -0.3)
	M.cyl(p, 0.12, 0.04, 0.2, wall, lp + Vector3(0, py - 0.32, 0), Vector3.ZERO, 12)
	M.cyl(p, 0.12, 0.12, 0.56, wall, lp + Vector3(0, py + 0.06, 0), Vector3.ZERO, 14)
	M.cyl(p, 0.14, 0.14, 0.035, stones[2], lp + Vector3(0, py + 0.35, 0), Vector3.ZERO, 14)
	for k in 8:
		var a := TAU * k / 8.0
		M.box(p, Vector3(0.03, 0.06, 0.03), stones[k % 3], lp + Vector3(cos(a) * 0.125, py + 0.12, sin(a) * 0.125))
	M.cyl(p, 0.105, 0.105, 0.02, iron, lp + Vector3(0, py + 0.38, 0), Vector3.ZERO, 12)
	for k in 6:
		var a := TAU * k / 6.0
		M.cyl(p, 0.009, 0.009, 0.17, iron, lp + Vector3(cos(a) * 0.09, py + 0.47, sin(a) * 0.09), Vector3.ZERO, 4)
	M.sphere(p, 0.05, M.mat(LAMP, 2.2), lp + Vector3(0, py + 0.43, 0), Vector3.ONE, 12)
	# cristales ambarinos encendidos en la mitad exterior de la linterna (la llama se ve por dentro)
	var amber := M.mat(Color(1.0, 0.68, 0.25), 1.3)
	for k in 6:
		var a := TAU * (k + 0.5) / 6.0
		var d := Vector3(cos(a), 0, sin(a))
		if d.dot(Vector3(-1, 0, -1)) < 0.0:
			continue
		M.box(p, Vector3(0.075, 0.13, 0.008), amber, lp + d * 0.078 + Vector3(0, py + 0.47, 0), Vector3(0, rad_to_deg(atan2(d.x, d.z)), 0))
	M.cyl(p, 0.11, 0.11, 0.025, iron, lp + Vector3(0, py + 0.565, 0), Vector3.ZERO, 12)
	M.cyl(p, 0.0, 0.15, 0.2, slate, lp + Vector3(0, py + 0.68, 0), Vector3.ZERO, 14)
	M.sphere(p, 0.022, gold, lp + Vector3(0, py + 0.79, 0), Vector3.ONE, 8)
	M.cyl(p, 0.0, 0.014, 0.07, gold, lp + Vector3(0, py + 0.84, 0), Vector3.ZERO, 6)
	# Torrecilla trasera derecha con asta
	var top := Arch.turret(p, Vector3(0.3, 0, -0.3), 0.08, py - 0.12, py + 0.16, wall, slate, 0.22, stones[2], gold)
	M.cyl(p, 0.007, 0.007, 0.22, iron, top + Vector3(0, 0.11, 0), Vector3.ZERO, 4)
	# Estandarte del vigía (verde con sol dorado), escudos y antorchas
	Arch.hang_banner(p, Vector3(0, py - 0.3, 0.3), 0.0, 0.2, 0.36, M.mat(FOREST), gold, gold, 2)
	for sx: float in [-1.0, 1.0]:
		Arch.wall_torch(p, Vector3(0.17 * sx, 0.48, 0.325), Vector3(0, 0, 1), iron)
		Arch.heater(p, Vector3((_half_at(0.85, y0, y1, 0.35, 0.25) + 0.012) * sx, 0.85, 0.05), PI * 0.5 * sx, 1.3, M.mat(FOREST), M.mat(CREAM), iron)
	_woodpile(p, Vector3(-0.42, 0.0, 0.18), 1.5708, M.tex_mat("wood", 2.5, Color(0.56, 0.42, 0.3)), M.mat(Color(0.86, 0.72, 0.5)))
	Arch._ground_details(p, false)


# Etapa 3 (Maestría): torre de mármol y oro, torreones azules y el Ojo que Todo lo Ve
func _tower_t3(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[3]
	var wall := M.tex_mat("bricks", 2.2, MARBLE)
	var stones := [M.mat(Color(0.93, 0.91, 0.86)), M.mat(Color(0.86, 0.84, 0.8)), M.mat(Color(1.0, 0.98, 0.94))]
	var dark := M.mat(Color(0.74, 0.72, 0.68))
	var gold := M.metal(GOLD)
	var royal := M.mat(ROYAL)
	var slate := M.tex_mat("roof", 3.0, Color(0.42, 0.55, 0.95))
	var glow := M.mat(Color(1.0, 0.85, 0.5), 1.6)
	var blue_glow := M.mat(EYE_GLOW, 1.8)
	var y0 := 0.16
	var y1 := py - 0.2
	M.box(p, Vector3(0.92, 0.08, 0.92), dark, Vector3(0, 0.04, 0))
	M.box(p, Vector3(0.82, 0.08, 0.82), stones[2], Vector3(0, 0.12, 0))
	M.box(p, Vector3(0.84, 0.02, 0.84), gold, Vector3(0, 0.165, 0))
	_taper(p, y0, y1, 0.35, 0.25, wall)
	_quoins(p, y0, y1, 0.35, 0.25, stones)
	for y: float in [0.6, 1.0, 1.3]:
		_band(p, _half_at(y, y0, y1, 0.35, 0.25), y, gold, 0.03)
	_corbels(p, 0.25, py, 5, stones, glow)
	M.box(p, Vector3(0.72, 0.08, 0.72), stones[2], Vector3(0, py - 0.04, 0))
	M.box(p, Vector3(0.74, 0.02, 0.74), gold, Vector3(0, py - 0.085, 0))
	Arch.parapet(p, 0.34, py + 0.045, 0.09, 0.06, wall)
	# almenas con albardilla dorada (sin la del centro trasero, donde se alza la aguja del Ojo)
	for i in 3:
		for j in 3:
			if (i == 1 and j == 1) or (i == 1 and j == 0):
				continue
			var mp := Vector3(-0.34 + 0.34 * i, py + 0.15, -0.34 + 0.34 * j)
			M.box(p, Vector3(0.1, 0.12, 0.1), wall, mp)
			M.box(p, Vector3(0.12, 0.025, 0.12), gold, mp + Vector3(0, 0.07, 0))
	Arch._door(p, 0.335, gold, M.mat(Color(0.2, 0.24, 0.45)), gold)
	M.box(p, Vector3(0.36, 0.05, 0.12), stones[2], Vector3(0, 0.025, 0.44))
	for face: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]:
		for y: float in [0.8, 1.15]:
			if face.z > 0.5 and y < 1.0:
				continue
			_slit(p, face, y, _half_at(y, y0, y1, 0.35, 0.25), gold, glow)
	# Torreones traseros de pizarra azul y garitas delanteras
	for sx: float in [-1.0, 1.0]:
		var top := Arch.turret(p, Vector3(0.31 * sx, 0, -0.31), 0.1, py - 0.2, py + 0.26, wall, slate, 0.32, gold, gold)
		M.cyl(p, 0.008, 0.008, 0.16, gold, top + Vector3(0, 0.08, 0), Vector3.ZERO, 4)
		Arch.turret(p, Vector3(0.33 * sx, 0, 0.33), 0.07, py - 0.06, py + 0.1, wall, slate, 0.16, gold, gold)
	# Aguja central del Ojo: columna de mármol con anillos de oro y una cuna de tres garras
	var sp := Vector3(0, 0, -0.34)
	M.cyl(p, 0.08, 0.03, 0.16, stones[2], sp + Vector3(0, py - 0.14, 0), Vector3.ZERO, 12)
	M.cyl(p, 0.05, 0.065, 0.48, wall, sp + Vector3(0, py + 0.18, 0), Vector3.ZERO, 12)
	for y: float in [py + 0.02, py + 0.2, py + 0.4]:
		M.cyl(p, 0.07, 0.07, 0.025, gold, sp + Vector3(0, y, 0), Vector3.ZERO, 14)
	M.sphere(p, 0.03, blue_glow, sp + Vector3(0, py + 0.3, 0.05), Vector3(1, 1, 0.5), 8)
	M.cyl(p, 0.09, 0.05, 0.05, gold, sp + Vector3(0, py + 0.44, 0), Vector3.ZERO, 14)
	for k in 3:
		var a := TAU * k / 3.0 + PI * 0.5
		var d := Vector3(cos(a), 0, sin(a))
		M.segment(p, 0.013, gold, sp + Vector3(0, py + 0.45, 0) + d * 0.07, sp + Vector3(0, py + 0.55, 0) + d * 0.11, 6)
		M.segment(p, 0.011, gold, sp + Vector3(0, py + 0.55, 0) + d * 0.11, sp + Vector3(0, py + 0.62, 0) + d * 0.085, 6)
		M.sphere(p, 0.016, blue_glow, sp + Vector3(0, py + 0.625, 0) + d * 0.085, Vector3.ONE, 8)
	# Gran estandarte real con el sol dorado, escudos y antorchas doradas
	Arch.hang_banner(p, Vector3(0, py - 0.3, 0.3), 0.0, 0.22, 0.46, royal, gold, gold, 2)
	for sx: float in [-1.0, 1.0]:
		Arch.wall_torch(p, Vector3(0.17 * sx, 0.48, 0.325), Vector3(0, 0, 1), gold)
		Arch.heater(p, Vector3((_half_at(0.85, y0, y1, 0.35, 0.25) + 0.012) * sx, 0.85, 0.05), PI * 0.5 * sx, 1.4, royal, gold, gold)
		# pebeteros de mármol con orbe azul a los lados de la entrada
		M.box(p, Vector3(0.09, 0.14, 0.09), stones[2], Vector3(0.42 * sx, 0.07, 0.3))
		M.box(p, Vector3(0.11, 0.02, 0.11), gold, Vector3(0.42 * sx, 0.15, 0.3))
		M.sphere(p, 0.035, blue_glow, Vector3(0.42 * sx, 0.195, 0.3), Vector3.ONE, 12)
	Arch._ground_details(p, false)


# =====================================================================
# --- Vigía arquero ---
# =====================================================================

func _cloth() -> Material:
	match tier:
		0: return M.mat(Color(0.46, 0.4, 0.26))
		1: return M.mat(FOREST)
		2: return M.metal(Color(0.5, 0.52, 0.56))
	return M.metal(Color(0.85, 0.87, 0.9))


func _build_man(c: Node3D) -> void:
	var cloth := _cloth()
	var leather := M.mat(LEATHER)
	var leather_l := M.mat(Color(0.52, 0.36, 0.2))
	var gold := M.metal(GOLD)
	var steel := M.metal(STEEL)
	var trim: Material = [leather_l, leather, M.mat(FOREST), gold][tier]
	Human.body(c, cloth, trim)
	match tier:
		0:
			# capotillo de lana con capucha y cinto de cuerda
			M.sphere(c, 0.12, M.mat(Color(0.34, 0.42, 0.22)), Vector3(0, 0.29, 0.0), Vector3(1.35, 0.55, 1.2), 12)
		1:
			# jubón de cuero con tachuelas sobre la ropa verde
			for sz: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.2, 0.24, 0.02), leather_l, Vector3(0, 0.16, 0.122 * sz), Vector3(4.0 * sz, 0, 0))
			for k in 3:
				M.sphere(c, 0.011, M.metal(BRASS), Vector3(0, 0.1 + k * 0.06, -0.135), Vector3.ONE, 6)
		2:
			# sobreveste verde con el sol blanco y hombreras de acero
			for sz: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.18, 0.28, 0.02), M.mat(FOREST), Vector3(0, 0.13, 0.123 * sz), Vector3(4.0 * sz, 0, 0))
			M.sphere(c, 0.035, M.mat(CREAM), Vector3(0, 0.17, -0.137), Vector3(1, 1, 0.3), 10)
			for s: float in [-1.0, 1.0]:
				M.sphere(c, 0.07, steel, Vector3(0.13 * s, 0.285, 0), Vector3(1, 0.72, 1), 10)
		3:
			# sobreveste real con ribete y ojo dorado brillante; hombreras de oro
			for sz: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.18, 0.28, 0.02), M.mat(ROYAL), Vector3(0, 0.13, 0.124 * sz), Vector3(4.0 * sz, 0, 0))
			for sx: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.02, 0.28, 0.024), gold, Vector3(0.085 * sx, 0.13, -0.126), Vector3(-4, 0, 0))
			M.sphere(c, 0.04, gold, Vector3(0, 0.17, -0.137), Vector3(1.4, 0.8, 0.3), 12)
			M.sphere(c, 0.02, M.mat(EYE_GLOW, 2.0), Vector3(0, 0.17, -0.145), Vector3(1, 1, 0.4), 8)
			for s: float in [-1.0, 1.0]:
				M.sphere(c, 0.076, gold, Vector3(0.13 * s, 0.29, 0), Vector3(1, 0.7, 1), 12)
	# Cinto con hebilla, bolsa y vaina del catalejo
	var belt := TorusMesh.new()
	belt.inner_radius = 0.13
	belt.outer_radius = 0.155
	M.add(c, belt, leather, Vector3(0, 0.09, 0))
	M.box(c, Vector3(0.04, 0.035, 0.02), gold if tier >= 2 else M.metal(IRON), Vector3(0, 0.09, -0.15))
	M.box(c, Vector3(0.06, 0.07, 0.04), leather_l, Vector3(-0.12, 0.05, -0.1), Vector3(0, 30, 0))
	M.cyl(c, 0.03, 0.03, 0.05, leather, HIP + Vector3(0.0, -0.06, 0.0), Vector3.ZERO, 8)
	# Botas
	for sx: float in [-1.0, 1.0]:
		M.cyl(c, 0.045, 0.05, 0.05, leather, Vector3(0.06 * sx, 0.01, -0.02), Vector3.ZERO, 8)
	# Carcaj a la espalda con flechas de plumas
	M.cyl(c, 0.045, 0.04, 0.28, leather if tier < 3 else M.mat(ROYAL), Vector3(0.07, 0.3, 0.15), Vector3(15, 0, -25), 10)
	if tier >= 2:
		M.cyl(c, 0.05, 0.05, 0.025, gold if tier == 3 else steel, Vector3(0.11, 0.39, 0.17), Vector3(15, 0, -25), 10)
	var fletch := M.mat([CREAM, Color(0.85, 0.3, 0.2), CREAM, Color(0.3, 0.45, 0.95)][tier])
	for fp: Vector3 in [Vector3(0.13, 0.44, 0.18), Vector3(0.1, 0.45, 0.15), Vector3(0.15, 0.42, 0.14), Vector3(0.12, 0.43, 0.2)]:
		M.sphere(c, 0.022, M.mat(CREAM), fp, Vector3(1, 1.5, 1), 6)
		M.sphere(c, 0.012, fletch, fp + Vector3(0, 0.03, 0), Vector3.ONE, 6)
	# Cabeza: capucha, sombrero de ala con pluma, capacete o yelmo real
	match tier:
		0:
			var h0 := Human.head(c, true, true, Color(0.45, 0.28, 0.14))
			var hood := M.mat(Color(0.34, 0.42, 0.22))
			M.sphere(h0, 0.155, hood, Vector3(0, 0.03, 0.035), Vector3.ONE, 14)
			M.cyl(h0, 0.0, 0.06, 0.16, hood, Vector3(0, 0.05, 0.17), Vector3(-60, 0, 0), 8)
		1:
			var h1 := Human.head(c, true, true, Color(0.36, 0.22, 0.12))
			var felt := M.mat(Color(0.3, 0.24, 0.16))
			M.cyl(h1, 0.21, 0.21, 0.02, felt, Vector3(0, 0.07, 0.01), Vector3(-6, 0, 0), 18)
			M.cyl(h1, 0.1, 0.135, 0.1, felt, Vector3(0, 0.13, 0.01), Vector3(-6, 0, 0), 14)
			M.cyl(h1, 0.137, 0.137, 0.025, M.mat(FOREST), Vector3(0, 0.095, 0.01), Vector3(-6, 0, 0), 14)
			M.box(h1, Vector3(0.012, 0.2, 0.035), M.mat(RED), Vector3(0.11, 0.18, 0.06), Vector3(-30, 0, -25))
			M.box(h1, Vector3(0.01, 0.14, 0.03), M.mat(CREAM), Vector3(0.125, 0.16, 0.08), Vector3(-40, 0, -35))
		2:
			var h2 := Human.head(c, true, true, Color(0.3, 0.2, 0.12))
			var hood2 := M.mat(Color(0.2, 0.34, 0.18))
			M.sphere(h2, 0.155, hood2, Vector3(0, 0.03, 0.035), Vector3.ONE, 14)
			M.sphere(h2, 0.16, steel, Vector3(0, 0.09, 0.03), Vector3(1.0, 0.6, 1.0), 14)
			M.cyl(h2, 0.17, 0.205, 0.02, steel, Vector3(0, 0.07, 0.03), Vector3(-5, 0, 0), 18)
			M.box(h2, Vector3(0.018, 0.02, 0.2), M.metal(IRON), Vector3(0, 0.185, 0.03))
		_:
			var h3 := Human.head(c, false, false)
			var shiny := M.metal(Color(0.88, 0.9, 0.94))
			M.sphere(h3, 0.152, shiny, Vector3(0, 0.04, 0.03), Vector3(1.0, 0.92, 1.0), 16)
			M.cyl(h3, 0.157, 0.157, 0.03, gold, Vector3(0, 0.0, 0.03), Vector3(-6, 0, 0), 18)
			M.box(h3, Vector3(0.025, 0.05, 0.24), gold, Vector3(0, 0.17, 0.03))
			M.sphere(h3, 0.022, M.mat(EYE_GLOW, 2.2), Vector3(0, 0.07, -0.145), Vector3(1, 1, 0.5), 8)
			for k in 4:
				M.sphere(h3, 0.04, M.mat(ROYAL) if k % 2 == 0 else M.mat(Color(0.98, 0.97, 0.95)), Vector3(0, 0.2 + k * 0.01, 0.08 + k * 0.045), Vector3(0.6, 1.0, 1.4), 8)
			for s: float in [-1.0, 1.0]:
				M.box(h3, Vector3(0.012, 0.09, 0.05), gold, Vector3(0.155 * s, 0.07, 0.04), Vector3(-30, 0, 15.0 * s))
	# Arco largo (segmentos) con empuñadura y, según la etapa, puntas de metal o de oro
	var limb := M.mat([BOW_WOOD, Color(0.5, 0.27, 0.12), Color(0.4, 0.22, 0.1), Color(0.3, 0.15, 0.08)][tier])
	var n := 10
	for i in n:
		var a0 := -BOW_SPAN + 2.0 * BOW_SPAN * i / n
		var a1 := -BOW_SPAN + 2.0 * BOW_SPAN * (i + 1) / n
		M.segment(c, 0.016, limb, bow_point(a0), bow_point(a1), 6)
	M.segment(c, 0.022, leather if tier < 3 else M.mat(ROYAL), bow_point(-0.1), bow_point(0.1), 6)
	if tier >= 1:
		var tipm: Material = M.metal(BRASS) if tier == 1 else (steel if tier == 2 else gold)
		M.sphere(c, 0.02, tipm, bow_point(-BOW_SPAN), Vector3.ONE, 8)
		M.sphere(c, 0.02, tipm, bow_point(BOW_SPAN), Vector3.ONE, 8)
	if tier == 3:
		for a: float in [-0.45, 0.45]:
			M.segment(c, 0.02, gold, bow_point(a - 0.05), bow_point(a + 0.05), 6)
	# Brazo que sostiene el arco, con brazal
	var grip := bow_point(0.0) + Vector3(0, 0, 0.02)
	M.segment(c, 0.04, cloth, L_SHOULDER, grip, 8)
	M.segment(c, 0.047, gold if tier == 3 else leather, L_SHOULDER.lerp(grip, 0.55), L_SHOULDER.lerp(grip, 0.85), 8)
	M.sphere(c, 0.042, leather if tier >= 2 else M.mat(Human.SKIN), grip, Vector3(1, 1.1, 0.9), 8)


# Catalejo (ocular en el origen, el objetivo hacia -Z)
func _build_spyglass(g: Node3D) -> void:
	var brass := M.metal(BRASS) if tier < 3 else M.metal(GOLD)
	var body := M.mat(LEATHER) if tier < 2 else (M.mat(FOREST) if tier == 2 else M.mat(ROYAL))
	M.cyl(g, 0.013, 0.013, 0.04, brass, Vector3(0, 0, -0.02), Vector3(90, 0, 0), 8)
	M.cyl(g, 0.017, 0.017, 0.07, brass, Vector3(0, 0, -0.07), Vector3(90, 0, 0), 10)
	M.cyl(g, 0.021, 0.021, 0.012, brass, Vector3(0, 0, -0.106), Vector3(90, 0, 0), 10)
	M.cyl(g, 0.022, 0.022, 0.08, body, Vector3(0, 0, -0.15), Vector3(90, 0, 0), 10)
	M.cyl(g, 0.027, 0.024, 0.035, brass, Vector3(0, 0, -0.205), Vector3(90, 0, 0), 12)
	M.cyl(g, 0.02, 0.02, 0.006, M.mat(Color(0.6, 0.85, 1.0), 1.2), Vector3(0, 0, -0.223), Vector3(90, 0, 0), 10)


func _build_moving_parts() -> void:
	var c := cat_pivot
	_tip_bot = bow_point(-BOW_SPAN)
	_tip_top = bow_point(BOW_SPAN)
	# Capa (ondea)
	_cape = Node3D.new()
	_cape.position = Vector3(0, 0.33, 0.1)
	c.add_child(_cape)
	var cape_col: Color = [Color(0.34, 0.42, 0.22), FOREST, Color(0.16, 0.3, 0.15), ROYAL][tier]
	var cape_h: float = [0.22, 0.3, 0.34, 0.4][tier]
	M.box(_cape, Vector3(0.28 if tier == 0 else 0.3, cape_h, 0.02), M.mat(cape_col), Vector3(0, -cape_h * 0.47, 0))
	if tier == 3:
		var gold := M.metal(GOLD)
		M.box(_cape, Vector3(0.32, 0.03, 0.024), gold, Vector3(0, -cape_h * 0.94, 0))
		for sx: float in [-1.0, 1.0]:
			M.box(_cape, Vector3(0.024, cape_h, 0.024), gold, Vector3(0.15 * sx, -cape_h * 0.47, 0))
		M.sphere(_cape, 0.035, gold, Vector3(0, -cape_h * 0.45, 0.014), Vector3(1.3, 0.8, 0.4), 10)
		M.sphere(_cape, 0.018, M.mat(EYE_GLOW, 2.0), Vector3(0, -cape_h * 0.45, 0.026), Vector3(1, 1, 0.4), 8)
	# Cuerda del arco
	var string_mat := M.mat(CREAM)
	_str_bot = M.add(c, M.tube_mesh(0.005, 4), string_mat)
	_str_top = M.add(c, M.tube_mesh(0.005, 4), string_mat)
	# Flecha cargada (dorada en la Maestría)
	_nocked = Node3D.new()
	c.add_child(_nocked)
	Arch.build_arrow(_nocked, false, tier == 3)
	# Brazo derecho, mano y catalejo
	_arm_r = M.add(c, M.tube_mesh(0.04, 8), _cloth())
	_hand_r = M.sphere(c, 0.042, M.mat(LEATHER) if tier >= 2 else M.mat(Human.SKIN), Vector3.ZERO, Vector3(1, 1.1, 0.9), 8)
	_glass = Node3D.new()
	c.add_child(_glass)
	M.add_baked(_glass, M.baked("watch_glass_t%d" % tier, _build_spyglass))


# =====================================================================
# --- Adornos animados de cada etapa ---
# =====================================================================

func _build_tier_fx() -> void:
	var py: float = PLAT_BY_TIER[tier]
	match tier:
		0:
			_flames.append(Arch.flame_node(self, Vector3(-0.21, py + 0.7, -0.21), 1.3))
			_pennants.append(Arch.pennant_node(self, Vector3(0.235, py + 0.6, -0.235), Color(0.34, 0.5, 0.22), CREAM, 0.22, 0.4))
		1:
			_flames.append(Arch.flame_node(self, Vector3(-0.3, py + 0.43, -0.3), 1.6))
			_flames.append(Arch.flame_node(self, Vector3(0.17, 0.48 + 0.05, 0.3 + 0.075)))
			_pennants.append(Arch.pennant_node(self, Vector3(0.29, py + 0.74, -0.29), FOREST, CREAM, 0.26, 2.7))
		2:
			_flames.append(Arch.flame_node(self, Vector3(-0.3, py + 0.42, -0.3), 1.3, LAMP))
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.17 * sx, 0.53, 0.325 + 0.075)))
			_pennants.append(Arch.pennant_node(self, Vector3(0.3, py + 0.62, -0.3), FOREST, GOLD, 0.3, 2.7))
		3:
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.17 * sx, 0.53, 0.325 + 0.075), 1.1, Color(1.0, 0.82, 0.4)))
				_pennants.append(Arch.pennant_node(self, Vector3(0.31 * sx, py + 0.86, -0.31), ROYAL, GOLD, 0.3, 0.4 if sx < 0.0 else 2.7))
			# El Ojo que Todo lo Ve: flota sobre la aguja y gira vigilando en todas direcciones
			var eye_pos := Vector3(0, py + 0.69, -0.34)
			var eye := Node3D.new()
			eye.position = eye_pos
			eye.set_meta("base", eye_pos)
			add_child(eye)
			var gold := M.metal(GOLD)
			M.sphere(eye, 0.085, M.mat(Color(0.98, 0.97, 0.94), 0.5), Vector3.ZERO, Vector3(1.0, 0.82, 0.9), 16)
			M.cyl(eye, 0.05, 0.05, 0.02, M.mat(EYE_GLOW, 2.4), Vector3(0, 0, -0.072), Vector3(90, 0, 0), 16)
			M.cyl(eye, 0.022, 0.022, 0.024, M.mat(Color(0.05, 0.05, 0.12)), Vector3(0, 0, -0.078), Vector3(90, 0, 0), 12)
			M.sphere(eye, 0.008, M.mat(Color.WHITE, 2.0), Vector3(0.015, 0.015, -0.091), Vector3.ONE, 6)
			# párpados de oro y rayos alrededor
			for sy: float in [-1.0, 1.0]:
				M.sphere(eye, 0.09, gold, Vector3(0, 0.03 * sy, 0.01), Vector3(1.05, 0.45, 0.95), 14)
			for k in 8:
				var a := TAU * k / 8.0
				var ray := M.box(eye, Vector3(0.016, 0.06, 0.012), gold, Vector3(cos(a), sin(a), 0) * 0.125 + Vector3(0, 0, 0.0))
				ray.rotation.z = a - PI * 0.5
				M.sphere(eye, 0.012, M.mat(LAMP, 2.0), Vector3(cos(a), sin(a), 0) * 0.165, Vector3.ONE, 6)
			_floaters.append(eye)
			# anillos de oro que giran alrededor del Ojo
			var gyro := Node3D.new()
			gyro.position = eye_pos
			add_child(gyro)
			for k in 2:
				var ring := TorusMesh.new()
				ring.inner_radius = 0.15 + k * 0.025
				ring.outer_radius = 0.164 + k * 0.025
				ring.rings = 32
				M.add(gyro, ring, M.mat(GOLD, 1.0) if k == 0 else M.mat(EYE_GLOW, 1.4), Vector3.ZERO, Vector3(72.0 if k == 0 else -64.0, 0, 18.0 if k == 0 else -24.0))
			_spinners.append(Arch.aura_ring(self, 0.47, Color(1.0, 0.85, 0.4), 0.12))
			_spinners.append(gyro)
			add_child(Arch.sparkles(EYE_GLOW, eye_pos, Vector3(0.12, 0.08, 0.12), 10, 0.01))
			add_child(Arch.sparkles(Color(1.0, 0.88, 0.5), Vector3(0, 0.8, 0), Vector3(0.42, 0.7, 0.42), 18, 0.012))
