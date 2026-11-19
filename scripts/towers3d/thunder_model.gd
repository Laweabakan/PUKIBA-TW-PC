extends Node3D
## Modelo 3D de la torre del hechicero del trueno (inspirado en el arte conceptual):
## base de piedra con armazón de madera y tachones dorados en forma de rombo, estandartes azul
## marino con runa del rayo dorada, faroles con rayo, bobinas eléctricas brillantes en las esquinas,
## puerta resplandeciente con medallón del rayo y una nube de tormenta encima.
## El defensor es un guerrero nórdico rubio con casco alado, capa azul, cinturón de cuero y muñequeras.

const M := preload("res://scripts/towers3d/models.gd")
const Cat := preload("res://scripts/towers3d/human_common.gd")
const ArcherModel := preload("res://scripts/towers3d/archer_model.gd")   # piedras y hierba de la base

const NAVY := Color(0.14, 0.17, 0.42)
const NAVY_DARK := Color(0.09, 0.1, 0.27)
const GOLD := Color(1.0, 0.78, 0.28)
const ELECTRIC := Color(1.0, 0.86, 0.35)
const WOOD_DARK := Color(0.34, 0.2, 0.12)
const IRON := Color(0.26, 0.25, 0.27)
const ORANGE := Color(0.93, 0.76, 0.62)          # piel (guerrero humano)
const ORANGE_LIGHT := Color(0.97, 0.82, 0.7)
const ORANGE_STRIPE := Color(0.85, 0.62, 0.25)   # pelo y barba rubios
const HAIR_BLOND := Color(0.85, 0.62, 0.25)
const CLOUD := Color(0.6, 0.6, 0.65)

const PLATFORM_Y := 1.1
const CLOUD_Y := 2.45

var cat_pivot: Node3D
var _fist: Node3D
var _cape: Node3D
var _cloud: Node3D
var _cloud_flash: Node3D
var _coil_glows: Array[Node3D] = []

## Altura de la plataforma en cada etapa; la nube de tormenta crece y sube con la etapa
const TIER_PY := [0.78, 0.95, 1.1, 1.46]
const CLOUD_UP := [1.0, 1.18, 1.35, 1.5]
const CLOUD_SCALE := [0.55, 0.75, 1.0, 1.2]
## Etapa 3: el cuerpo de la torre se eleva sobre un zócalo de piedras rúnicas
const T3_LIFT := 0.36

var _tier := 0
var _py := PLATFORM_Y
var _cloud_y := CLOUD_Y
var _bolts: Array[Node3D] = []     # etapa 3: rayitos que chisporrotean bajo la nube


static func _tier_of(level: int) -> int:
	if level >= 5:
		return 3
	if level >= 4:
		return 2
	if level >= 2:
		return 1
	return 0


## level: nivel de la torre. Etapas: 0 atalaya vikinga de troncos, 1 salón de piedra y madera con pararrayos,
## 2 torre del trueno con bobinas, 3 (Maestría) torre sobre piedras rúnicas con grandes pararrayos de oro y
## una nube enorme que chisporrotea. La nube crece en cada etapa.
func _init(level := 0) -> void:
	_tier = _tier_of(level)
	_py = TIER_PY[_tier]
	_cloud_y = _py + CLOUD_UP[_tier]
	M.add_baked(self, M.baked("thunder_tower_t%d" % _tier, _build_tower_tier))
	_build_coil_glows()
	_build_cloud()
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, _py, 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("thunder_cat_t%d" % _tier, _build_cat_body))
	_build_cat_parts()
	set_pose(0.3, 0.0, 0.0)


## charge: 0..1 (las bobinas brillan más). strike: 1 justo al lanzar el rayo -> 0.
func set_pose(charge: float, strike: float, t: float) -> void:
	_fist.rotation = Vector3(-0.2 - strike * 0.5, 0, 0.25 - strike * 0.35)
	_cape.rotation.x = -deg_to_rad(20.0 + sin(t * 6.0) * 8.0 + strike * 15.0)
	for i in _coil_glows.size():
		var g := _coil_glows[i]
		var flicker := 0.85 + 0.15 * sin(t * 37.0 + i * 2.1)
		g.scale = Vector3.ONE * (0.6 + charge * 0.6 + strike * 0.6) * flicker
	_cloud.rotation.y = t * 0.3
	_cloud.position.y = _cloud_y + sin(t * 1.3) * 0.04
	_cloud_flash.visible = strike > 0.0 and fmod(t * 20.0, 2.0) < 1.2
	_cloud_flash.scale = Vector3.ONE * (0.7 + strike * 0.6)
	for i in _bolts.size():
		var b := _bolts[i]
		b.visible = fmod(t * (3.0 + i * 1.3) + i * 0.37, 1.0) < 0.35 + charge * 0.3
		b.rotation.y = float(int(t * 6.0 + i * 3.0)) * 1.7


# Punto bajo la nube de donde sale el rayo
func cloud_global() -> Vector3:
	return _cloud.global_position + Vector3(0, -0.15 * CLOUD_SCALE[_tier], 0)


# --- Adornos reutilizables ---

static func diamond_stud(parent: Node3D, pos: Vector3, s: float, facing := Vector3(0, 0, 1)) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = atan2(facing.x, facing.z)
	parent.add_child(n)
	M.box(n, Vector3(0.06, 0.06, 0.02) * s, M.metal(IRON), Vector3.ZERO, Vector3(0, 0, 45))
	M.box(n, Vector3(0.036, 0.036, 0.02) * s, M.metal(GOLD), Vector3(0, 0, 0.008 * s), Vector3(0, 0, 45))


# Rayo en zigzag (en el plano XY, mirando a +Z)
static func bolt_emblem(parent: Node3D, pos: Vector3, s: float, m: Material) -> void:
	M.box(parent, Vector3(0.016, 0.055, 0.012) * Vector3(s, s, 1), m, pos + Vector3(0.008, 0.026, 0) * s, Vector3(0, 0, -28))
	M.box(parent, Vector3(0.036, 0.014, 0.012) * Vector3(s, s, 1), m, pos + Vector3(0, 0.0, 0) * s, Vector3(0, 0, 20))
	M.box(parent, Vector3(0.016, 0.055, 0.012) * Vector3(s, s, 1), m, pos + Vector3(-0.008, -0.026, 0) * s, Vector3(0, 0, -28))


# Emblema tomoe (tres comas) en un disco, mirando a +Z
## Runa nórdica del rayo dentro de un anillo (reemplaza al emblema tomoe original).
static func tomoe(parent: Node3D, pos: Vector3, s: float, m: Material) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.042 * s
	ring.outer_radius = 0.05 * s
	M.add(parent, ring, m, pos, Vector3(90, 0, 0))
	M.box(parent, Vector3(0.01 * s, 0.035 * s, 0.006), m, pos + Vector3(-0.008 * s, 0.014 * s, 0.004), Vector3(0, 0, -25))
	M.box(parent, Vector3(0.03 * s, 0.009 * s, 0.006), m, pos + Vector3(0, 0, 0.004), Vector3(0, 0, -25))
	M.box(parent, Vector3(0.01 * s, 0.035 * s, 0.006), m, pos + Vector3(0.008 * s, -0.014 * s, 0.004), Vector3(0, 0, -25))


# --- Torre ---

func _build_tower_tier(parent: Node3D) -> void:
	match _tier:
		0:
			_build_lookout(parent)
		1:
			_build_hall(parent)
		2:
			_build_tower(parent)
		_:
			_build_plinth(parent)
			_build_tower(parent, T3_LIFT)
			_build_majestic(parent)


# Escudo redondo vikingo pintado en cuartos (mira a +Z del nodo)
static func round_shield(parent: Node3D, pos: Vector3, yaw: float, r: float, col_a: Color, col_b: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	M.cyl(n, r, r, 0.02, M.mat(col_a), Vector3.ZERO, Vector3(90, 0, 0), 14)
	M.box(n, Vector3(r * 1.3, r * 0.5, 0.022), M.mat(col_b), Vector3(0, 0, 0.002))
	M.box(n, Vector3(r * 0.5, r * 1.3, 0.022), M.mat(col_b), Vector3(0, 0, 0.002))
	var rim := TorusMesh.new()
	rim.inner_radius = r * 0.92
	rim.outer_radius = r * 1.05
	M.add(n, rim, M.metal(IRON), Vector3.ZERO, Vector3(90, 0, 0))
	M.sphere(n, r * 0.28, M.metal(Color(0.7, 0.72, 0.76)), Vector3(0, 0, 0.012), Vector3(1, 1, 0.6), 8)


# Pararrayos: mástil de hierro con espiras de cobre y punta dorada (el halo animado va aparte)
static func lightning_rod(parent: Node3D, base: Vector3, h: float, gold_tip := true, coil_f := 0.55) -> void:
	var iron := M.metal(IRON)
	var copper := M.metal(Color(0.85, 0.5, 0.28))
	M.cyl(parent, 0.018, 0.024, h, iron, base + Vector3(0, h / 2.0, 0), Vector3.ZERO, 8)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.026
	ring.outer_radius = 0.042
	for k in 4:
		M.add(parent, ring, copper, base + Vector3(0, h * coil_f + k * 0.045, 0))
	M.cyl(parent, 0.0, 0.03, 0.1, M.metal(GOLD) if gold_tip else iron, base + Vector3(0, h + 0.05, 0), Vector3.ZERO, 6)


# --- Etapa 0: atalaya vikinga de troncos sobre zancos ---

func _build_lookout(parent: Node3D) -> void:
	var py := _py
	var earth := M.mat(Color(0.45, 0.35, 0.23))
	var log_m := M.mat(Color(0.45, 0.3, 0.17))
	var log_dark := M.mat(WOOD_DARK)
	var planks := M.tex_mat("wood", 2.5, Color(0.75, 0.55, 0.38))
	var rope := M.mat(Color(0.82, 0.72, 0.52))
	var iron := M.metal(IRON)

	M.cyl(parent, 0.44, 0.46, 0.04, earth, Vector3(0, 0.02, 0), Vector3.ZERO, 18)
	# Zancos de tronco con zapatas de piedra y arriostramiento en aspa
	var legs := [Vector3(0.27, 0, 0.27), Vector3(-0.27, 0, 0.27), Vector3(-0.27, 0, -0.27), Vector3(0.27, 0, -0.27)]
	for p in legs:
		var lp: Vector3 = p
		M.box(parent, Vector3(0.12, 0.06, 0.12), M.mat(Color(0.55, 0.53, 0.5)), lp + Vector3(0, 0.05, 0))
		M.cyl(parent, 0.04, 0.05, py, log_m, lp + Vector3(0, py / 2.0 + 0.04, 0), Vector3.ZERO, 7)
	for i in 4:
		var a: Vector3 = legs[i]
		var b: Vector3 = legs[(i + 1) % 4]
		M.segment(parent, 0.02, log_dark, a + Vector3(0, 0.14, 0), b + Vector3(0, py - 0.12, 0), 6)
		M.segment(parent, 0.02, log_dark, b + Vector3(0, 0.14, 0), a + Vector3(0, py - 0.12, 0), 6)
		M.segment(parent, 0.022, log_m, a + Vector3(0, 0.12, 0), b + Vector3(0, 0.12, 0), 6)
	# Barriles y un hacha bajo la atalaya
	for p in [Vector3(-0.08, 0, -0.06), Vector3(0.1, 0, 0.04)]:
		M.cyl(parent, 0.065, 0.065, 0.15, M.tex_mat("wood", 3.0, Color(0.7, 0.5, 0.32)), p + Vector3(0, 0.115, 0), Vector3.ZERO, 10)
		for y in [0.07, 0.16]:
			M.cyl(parent, 0.067, 0.067, 0.012, iron, p + Vector3(0, y, 0), Vector3.ZERO, 10)

	# Plataforma de tablones con empalizada de troncos afilados
	M.box(parent, Vector3(0.7, 0.06, 0.7), planks, Vector3(0, py - 0.03, 0))
	for k in 4:
		var o := -0.21 + k * 0.14
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.04, 0.04, 0.1), log_m, Vector3(o, py - 0.07, 0.34 * s))
	for i in 4:
		var a: Vector3 = legs[i] * 1.18
		var b: Vector3 = legs[(i + 1) % 4] * 1.18
		if i == 1:
			continue   # lateral izquierdo abierto para la escalera
		for k in 5:
			var p := a.lerp(b, (k + 0.5) / 5.0)
			M.cyl(parent, 0.022, 0.024, 0.14, log_m if k % 2 == 0 else log_dark, p + Vector3(0, py + 0.07, 0), Vector3.ZERO, 6)
			M.cyl(parent, 0.0, 0.022, 0.04, log_m, p + Vector3(0, py + 0.16, 0), Vector3.ZERO, 6)
		M.segment(parent, 0.012, rope, a + Vector3(0, py + 0.1, 0), b + Vector3(0, py + 0.1, 0), 4)
	# Escudos redondos colgados de la empalizada
	round_shield(parent, Vector3(0.0, py + 0.07, 0.345), 0.0, 0.085, NAVY, ELECTRIC.darkened(0.15))
	round_shield(parent, Vector3(0.345, py + 0.07, 0.0), PI / 2.0, 0.08, Color(0.7, 0.2, 0.15), Color(0.9, 0.85, 0.7))
	round_shield(parent, Vector3(0.0, py + 0.07, -0.345), PI, 0.08, Color(0.9, 0.85, 0.7), NAVY)
	# Escalera de mano en el lado izquierdo
	for s in [-1.0, 1.0]:
		M.segment(parent, 0.016, log_m, Vector3(-0.47, 0.02, 0.09 * s), Vector3(-0.35, py + 0.1, 0.09 * s), 6)
	for k in 5:
		var f := (k + 0.6) / 5.6
		var lx := lerpf(-0.47, -0.35, f)
		var ly := 0.02 + f * (py + 0.08)
		M.segment(parent, 0.01, log_dark, Vector3(lx, ly, -0.09), Vector3(lx, ly + 0.0001, 0.09), 4)
	# Pararrayos rústico en la esquina trasera derecha
	lightning_rod(parent, Vector3(0.31, py, -0.31), 0.32, false)

	# Piedra rúnica con el rayo grabado (brilla) junto a la base
	var rs := Node3D.new()
	rs.position = Vector3(0.39, 0, 0.18)
	rs.rotation.y = -0.4
	parent.add_child(rs)
	M.box(rs, Vector3(0.12, 0.26, 0.07), M.mat(Color(0.5, 0.5, 0.5)), Vector3(0, 0.13, 0), Vector3(0, 0, 4))
	M.cyl(rs, 0.04, 0.05, 0.05, M.mat(Color(0.5, 0.5, 0.5)), Vector3(0, 0.27, 0), Vector3(90, 0, 0), 8)
	bolt_emblem(rs, Vector3(0, 0.15, 0.037), 1.2, M.mat(ELECTRIC, 1.3))
	M.sphere(rs, 0.04, M.mat(Color(0.4, 0.56, 0.22)), Vector3(0.03, 0.02, 0.03), Vector3(1.3, 0.6, 1.0), 8)
	ArcherModel._ground_details(parent, false)


# --- Etapa 1: salón de piedra y madera con cabezas de dragón, estandarte y pararrayos ---

func _build_hall(parent: Node3D) -> void:
	var py := _py
	var stone := M.tex_mat("bricks", 2.2, Color(0.75, 0.72, 0.68))
	var stones := [M.mat(Color(0.6, 0.58, 0.55)), M.mat(Color(0.52, 0.5, 0.48)), M.mat(Color(0.67, 0.64, 0.6))]
	var planks := M.tex_mat("wood", 2.2, Color(0.62, 0.42, 0.3))
	var wood_dark := M.mat(WOOD_DARK)
	var log_m := M.mat(Color(0.45, 0.3, 0.17))
	var iron := M.metal(IRON)
	var gold := M.metal(GOLD)
	var navy := M.mat(NAVY)
	var glow := M.mat(ELECTRIC, 1.4)
	var rope := M.mat(Color(0.92, 0.88, 0.78))

	M.box(parent, Vector3(0.88, 0.06, 0.88), M.mat(Color(0.45, 0.43, 0.41)), Vector3(0, 0.03, 0))
	M.box(parent, Vector3(0.66, 0.44, 0.66), stone, Vector3(0, 0.28, 0))
	ArcherModel._stone_blocks(parent, 0.33, 0.14, 3, [[0, 1]], stones)
	# puerta de tablones con herrajes y rayo brillante en el dintel
	var door := Vector3(0, 0, 0.335)
	M.box(parent, Vector3(0.22, 0.27, 0.04), iron, door + Vector3(0, 0.19, 0))
	M.box(parent, Vector3(0.18, 0.24, 0.03), planks, door + Vector3(0, 0.18, 0.016))
	for y in [0.1, 0.24]:
		M.box(parent, Vector3(0.19, 0.022, 0.012), iron, door + Vector3(0, y, 0.035))
	M.box(parent, Vector3(0.26, 0.05, 0.05), wood_dark, door + Vector3(0, 0.345, 0.01))
	bolt_emblem(parent, door + Vector3(0, 0.4, 0.01), 1.1, glow)
	for s in [-1.0, 1.0]:
		M.cyl(parent, 0.0, 0.07, 0.17, stones[1], Vector3(0.22 * s, 0.085, 0.38), Vector3.ZERO, 5)

	# Planta alta de tablones oscuros con postes y vigas
	var y0 := 0.5
	var hh := py - 0.05 - y0
	M.box(parent, Vector3(0.62, hh, 0.62), planks, Vector3(0, y0 + hh / 2.0, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.08, hh + 0.04, 0.08), wood_dark, Vector3(0.31 * sx, y0 + hh / 2.0, 0.31 * sz))
			diamond_stud(parent, Vector3(0.31 * sx, y0 + hh / 2.0, 0.31 * sz + 0.042 * sz), 0.5, Vector3(0, 0, sz))
	for y in [y0 + 0.02, y0 + hh]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.7, 0.05, 0.05), wood_dark, Vector3(0, y, 0.33 * s))
			M.box(parent, Vector3(0.05, 0.05, 0.7), wood_dark, Vector3(0.33 * s, y, 0))
	# ventanas con barrotes y luz eléctrica en los costados
	for face in [Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var w := Node3D.new()
		w.position = face * 0.312 + Vector3(0, y0 + hh * 0.5, 0)
		w.rotation.y = atan2(face.x, face.z)
		parent.add_child(w)
		M.box(w, Vector3(0.12, 0.13, 0.02), iron)
		M.box(w, Vector3(0.09, 0.1, 0.02), glow, Vector3(0, 0, 0.006))
		for k in 2:
			M.box(w, Vector3(0.012, 0.12, 0.015), iron, Vector3(-0.02 + k * 0.04, 0, 0.012))
	# estandarte azul marino con runa del rayo
	M.box(parent, Vector3(0.22, 0.022, 0.022), gold, Vector3(0, y0 + hh - 0.02, 0.335))
	M.box(parent, Vector3(0.16, 0.28, 0.016), navy, Vector3(0, y0 + hh - 0.16, 0.333))
	tomoe(parent, Vector3(0, y0 + hh - 0.13, 0.345), 0.9, gold)
	for k in [-1.0, 1.0]:
		M.cyl(parent, 0.0, 0.035, 0.05, navy, Vector3(0.035 * k, y0 + hh - 0.32, 0.333), Vector3(180, 0, 0), 4)

	# Plataforma con empalizada, cabezas de dragón talladas y escudos
	M.box(parent, Vector3(0.74, 0.06, 0.74), M.tex_mat("wood", 2.5, Color(0.7, 0.5, 0.36)), Vector3(0, py - 0.03, 0))
	var corners := [Vector3(0.33, 0, 0.33), Vector3(-0.33, 0, 0.33), Vector3(-0.33, 0, -0.33), Vector3(0.33, 0, -0.33)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		for k in 5:
			var p := a.lerp(b, (k + 0.5) / 5.0)
			M.cyl(parent, 0.022, 0.024, 0.15, log_m if k % 2 == 0 else wood_dark, p + Vector3(0, py + 0.075, 0), Vector3.ZERO, 6)
			M.cyl(parent, 0.0, 0.022, 0.04, log_m, p + Vector3(0, py + 0.17, 0), Vector3.ZERO, 6)
		M.segment(parent, 0.012, rope, a + Vector3(0, py + 0.11, 0), b + Vector3(0, py + 0.11, 0), 4)
	for s in [-1.0, 1.0]:
		# cabeza de dragón tallada en la esquina delantera (proa de drakkar)
		var dh := Node3D.new()
		dh.position = Vector3(0.36 * s, py + 0.02, 0.36)
		dh.rotation.y = 0.6 * s
		parent.add_child(dh)
		M.segment(dh, 0.03, wood_dark, Vector3.ZERO, Vector3(0, 0.18, 0.04), 7)
		M.box(dh, Vector3(0.06, 0.06, 0.12), wood_dark, Vector3(0, 0.2, 0.08), Vector3(-15, 0, 0))
		M.cyl(dh, 0.0, 0.02, 0.07, wood_dark, Vector3(0, 0.26, 0.02), Vector3(-40, 0, 0), 5)
		M.sphere(dh, 0.012, glow, Vector3(0.028 * s, 0.215, 0.1), Vector3.ONE, 6)
		round_shield(parent, Vector3(0.36 * s, py + 0.07, 0.0), PI / 2.0 * s, 0.085, NAVY, ELECTRIC.darkened(0.15))
	round_shield(parent, Vector3(0.0, py + 0.07, -0.36), PI, 0.085, Color(0.7, 0.2, 0.15), Color(0.9, 0.85, 0.7))
	# pararrayos con espiras de cobre en las esquinas traseras
	for s in [-1.0, 1.0]:
		lightning_rod(parent, Vector3(0.3 * s, py, -0.3), 0.36)

	for p in [Vector3(0.46, 0, 0.3), Vector3(-0.46, 0, 0.3)]:
		M.cyl(parent, 0.03, 0.03, 0.24, wood_dark, p + Vector3(0, 0.12, 0), Vector3.ZERO, 6)
		M.cyl(parent, 0.0, 0.036, 0.07, iron, p + Vector3(0, 0.275, 0), Vector3.ZERO, 4)
		M.cyl(parent, 0.036, 0.036, 0.022, rope, p + Vector3(0, 0.12, 0), Vector3.ZERO, 8)
	ArcherModel._ground_details(parent, false)


# --- Etapa 3 (Maestría): zócalo de piedras rúnicas blancas con oro y runas eléctricas ---

func _build_plinth(parent: Node3D) -> void:
	var marble := M.mat(Color(0.94, 0.93, 0.9))
	var gold := M.metal(GOLD)
	var glow := M.mat(ELECTRIC, 1.8)
	var lift := T3_LIFT + 0.08
	M.box(parent, Vector3(0.94, 0.06, 0.94), marble, Vector3(0, 0.03, 0))
	M.box(parent, Vector3(0.78, lift, 0.78), M.mat(Color(0.88, 0.85, 0.8)), Vector3(0, lift / 2.0, 0))
	ArcherModel._stone_blocks(parent, 0.39, 0.12, 2, [[0, 1]], [marble, M.mat(Color(1.0, 0.98, 0.93)), M.mat(Color(0.92, 0.89, 0.83))])
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
	# portal resplandeciente con rayo blanco y arco de oro
	var door := Vector3(0, 0, 0.4)
	M.box(parent, Vector3(0.24, 0.24, 0.03), gold, door + Vector3(0, 0.15, 0))
	M.cyl(parent, 0.12, 0.12, 0.03, gold, door + Vector3(0, 0.27, 0), Vector3(90, 0, 0), 18)
	M.box(parent, Vector3(0.19, 0.22, 0.03), glow, door + Vector3(0, 0.14, 0.008))
	M.cyl(parent, 0.095, 0.095, 0.03, glow, door + Vector3(0, 0.25, 0.008), Vector3(90, 0, 0), 16)
	bolt_emblem(parent, door + Vector3(0, 0.18, 0.03), 1.6, M.mat(Color.WHITE, 1.4))
	# runas eléctricas grabadas en los costados y a los lados del portal
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(0.402 * s, 0.22, 0.0)
		w.rotation.y = PI / 2.0 * s
		parent.add_child(w)
		tomoe(w, Vector3(0, 0, 0.005), 1.6, glow)
		bolt_emblem(parent, Vector3(0.22 * s, 0.22, 0.405), 1.2, glow)


# Remates fijos de la Maestría: grandes pararrayos dorados en las esquinas traseras
func _build_majestic(parent: Node3D) -> void:
	for rb in _t3_rods():
		var base: Vector3 = rb
		var h := _py + 0.55 - base.y
		M.cyl(parent, 0.05, 0.065, 0.1, M.metal(GOLD), base + Vector3(0, 0.05, 0), Vector3.ZERO, 8)
		lightning_rod(parent, base, h, true, 0.8)
		for k in 3:
			M.cyl(parent, 0.03, 0.03, 0.02, M.metal(GOLD), base + Vector3(0, 0.2 + k * 0.3, 0), Vector3.ZERO, 8)


# Base de los grandes pararrayos de la Maestría (esquinas traseras del zócalo)
func _t3_rods() -> Array:
	return [Vector3(0.42, T3_LIFT + 0.08, -0.42), Vector3(-0.42, T3_LIFT + 0.08, -0.42)]


## lift: en la Maestría el cuerpo se eleva sobre el zócalo rúnico (rocas, estacas y hierba quedan en el suelo).
func _build_tower(root: Node3D, lift := 0.0) -> void:
	var parent := Node3D.new()
	parent.position.y = lift
	root.add_child(parent)
	var stone := M.tex_mat("bricks", 2.2, Color(0.75, 0.72, 0.68) if lift == 0.0 else Color(0.97, 0.95, 0.9))
	var stones := [M.mat(Color(0.6, 0.58, 0.55)), M.mat(Color(0.52, 0.5, 0.48)), M.mat(Color(0.67, 0.64, 0.6))] if lift == 0.0 else [M.mat(Color(0.94, 0.92, 0.88)), M.mat(Color(0.86, 0.84, 0.8)), M.mat(Color(1.0, 0.98, 0.94))]
	var wood := M.tex_mat("wood", 2.2, Color(0.75, 0.5, 0.35))
	var wood_dark := M.mat(WOOD_DARK)
	var gold := M.metal(GOLD)
	var iron := M.metal(IRON)
	var navy := M.mat(NAVY)
	var glow := M.mat(ELECTRIC, 1.6)
	var rope := M.mat(Color(0.92, 0.88, 0.78))

	# Base de piedra con escalones
	if lift == 0.0:
		M.box(parent, Vector3(0.92, 0.08, 0.92), M.mat(Color(0.45, 0.43, 0.41)), Vector3(0, 0.04, 0))
	M.box(parent, Vector3(0.72, 0.5, 0.72), stone, Vector3(0, 0.33, 0))
	ArcherModel._stone_blocks(parent, 0.37, 0.15, 3, [[0, 1]] if lift == 0.0 else [], stones)
	if lift == 0.0:
		# escalones bajos (delante quedan las gemas de nivel) y rocas puntiagudas junto a la puerta
		M.box(parent, Vector3(0.36, 0.03, 0.08), stones[2], Vector3(0, 0.015, 0.43))
		for s in [-1.0, 1.0]:
			M.cyl(parent, 0.0, 0.08, 0.2, stones[1], Vector3(0.24 * s, 0.1, 0.4), Vector3.ZERO, 5)

	if lift == 0.0:
		# Puerta resplandeciente con rayo, arco de hierro y medallón del rayo encima
		var door := Vector3(0, 0, 0.372)
		M.box(parent, Vector3(0.28, 0.3, 0.03), iron, door + Vector3(0, 0.23, 0))
		M.cyl(parent, 0.14, 0.14, 0.03, iron, door + Vector3(0, 0.38, 0), Vector3(90, 0, 0), 20)
		M.box(parent, Vector3(0.21, 0.27, 0.02), glow, door + Vector3(0, 0.22, 0.013))
		M.cyl(parent, 0.105, 0.105, 0.02, glow, door + Vector3(0, 0.36, 0.013), Vector3(90, 0, 0), 18)
		for k in 5:
			M.box(parent, Vector3(0.014, 0.34, 0.016), iron, door + Vector3(-0.08 + k * 0.04, 0.25, 0.026))
		bolt_emblem(parent, door + Vector3(0, 0.24, 0.036), 1.5, M.mat(Color.WHITE, 1.2))
		M.cyl(parent, 0.095, 0.095, 0.025, gold, door + Vector3(0, 0.62, 0.012), Vector3(90, 0, 0), 20)
		M.cyl(parent, 0.075, 0.075, 0.027, iron, door + Vector3(0, 0.62, 0.016), Vector3(90, 0, 0), 20)
		bolt_emblem(parent, door + Vector3(0, 0.62, 0.032), 1.6, gold)
		for p in [Vector2(0, 0.73), Vector2(-0.1, 0.62), Vector2(0.1, 0.62)]:
			diamond_stud(parent, door + Vector3(p.x, p.y, 0.02), 0.7)

	# Armazón de madera con vigas y tachones de rombo dorados
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.1, 1.0, 0.1), wood, Vector3(0.38 * sx, 0.58, 0.38 * sz))
			for y in [0.3, 0.62, 0.95]:
				M.box(parent, Vector3(0.12, 0.07, 0.12), iron, Vector3(0.38 * sx, y, 0.38 * sz))
				diamond_stud(parent, Vector3(0.38 * sx, y, 0.38 * sz + 0.062 * sz), 0.6, Vector3(0, 0, sz))
	# cuerpo superior de madera
	M.box(parent, Vector3(0.7, 0.42, 0.7), wood, Vector3(0, 0.78, 0))
	for y in [0.58, 0.98]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.82, 0.06, 0.06), wood_dark, Vector3(0, y, 0.39 * s))
			M.box(parent, Vector3(0.06, 0.06, 0.82), wood_dark, Vector3(0.39 * s, y, 0))
	for x in [-0.27, -0.09, 0.09, 0.27]:
		diamond_stud(parent, Vector3(x, 0.98, 0.42), 0.6)
	# ventanas brillantes con barrotes en los laterales y atrás
	for face in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)]:
		var w := Node3D.new()
		w.position = face * 0.352 + Vector3(0, 0.78, 0)
		w.rotation.y = atan2(face.x, face.z)
		parent.add_child(w)
		M.box(w, Vector3(0.14, 0.16, 0.02), iron)
		M.box(w, Vector3(0.11, 0.13, 0.02), glow, Vector3(0, 0, 0.006))
		for k in 3:
			M.box(w, Vector3(0.012, 0.14, 0.015), iron, Vector3(-0.035 + k * 0.035, 0, 0.012))

	# Estandartes azul marino con tomoe dorado, borde dentado y olas
	M.box(parent, Vector3(0.66, 0.03, 0.03), gold, Vector3(0, 0.98, 0.43))
	for s in [-1.0, 1.0]:
		M.sphere(parent, 0.026, gold, Vector3(0.34 * s, 0.98, 0.43), Vector3.ONE, 8)
		var bx: float = 0.17 * s
		M.box(parent, Vector3(0.16, 0.34, 0.014), gold, Vector3(bx, 0.79, 0.43))
		M.box(parent, Vector3(0.14, 0.32, 0.02), navy, Vector3(bx, 0.795, 0.433))
		tomoe(parent, Vector3(bx, 0.84, 0.447), 1.0, gold)
		for k in 2:
			M.box(parent, Vector3(0.1, 0.01, 0.006), M.mat(GOLD), Vector3(bx, 0.69 + k * 0.022, 0.446))
		for k in [-1.0, 1.0]:
			M.cyl(parent, 0.0, 0.035, 0.05, navy, Vector3(bx + 0.035 * k, 0.615, 0.433), Vector3(180, 0, 0), 4)
	# Faroles con rayo colgando a los lados
	for s in [-1.0, 1.0]:
		var lp := Vector3(0.52 * s, 0.62, 0.15)
		M.box(parent, Vector3(0.16, 0.035, 0.035), wood_dark, Vector3(0.45 * s, 0.82, 0.15))
		M.segment(parent, 0.007, iron, lp + Vector3(0, 0.09, 0), lp + Vector3(0, 0.2, 0), 4)
		M.cyl(parent, 0.055, 0.055, 0.15, iron, lp, Vector3.ZERO, 8)
		M.cyl(parent, 0.046, 0.046, 0.13, glow, lp, Vector3.ZERO, 8)
		bolt_emblem(parent, lp + Vector3(0, 0, 0.05), 0.9, M.mat(Color.WHITE, 1.0))
		M.cyl(parent, 0.0, 0.06, 0.06, gold, lp + Vector3(0, 0.105, 0), Vector3.ZERO, 8)
		M.sphere(parent, 0.022, gold, lp + Vector3(0, -0.095, 0), Vector3.ONE, 8)

	# Plataforma de madera con barandilla y bobinas eléctricas en las esquinas
	M.box(parent, Vector3(0.78, 0.07, 0.78), wood_dark, Vector3(0, 1.065, 0))
	for y in [1.15, 1.22]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.66, 0.03, 0.03), wood, Vector3(0, y, 0.33 * s))
			M.box(parent, Vector3(0.03, 0.03, 0.66), wood, Vector3(0.33 * s, y, 0))
	for s in [-1.0, 1.0]:
		diamond_stud(parent, Vector3(0.15 * s, 1.185, 0.35), 0.6)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.04
	ring.outer_radius = 0.06
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var cp := Vector3(0.36 * sx, 1.1, 0.36 * sz)
			M.box(parent, Vector3(0.1, 0.1, 0.1), iron, cp + Vector3(0, 0.05, 0))
			M.cyl(parent, 0.025, 0.025, 0.28, gold, cp + Vector3(0, 0.24, 0), Vector3.ZERO, 8)
			for k in 4:
				M.add(parent, ring, glow, cp + Vector3(0, 0.15 + k * 0.055, 0))
			M.cyl(parent, 0.04, 0.04, 0.03, gold, cp + Vector3(0, 0.39, 0), Vector3.ZERO, 10)
			M.cyl(parent, 0.0, 0.04, 0.1, gold, cp + Vector3(0, 0.45, 0), Vector3.ZERO, 6)

	# Estacas con cuerda y punta dorada
	for p in [Vector3(0.47, 0, 0.42), Vector3(-0.47, 0, 0.42), Vector3(0.47, 0, -0.25), Vector3(-0.47, 0, -0.25)]:
		M.cyl(root, 0.03, 0.03, 0.24, wood_dark, p + Vector3(0, 0.12, 0), Vector3.ZERO, 6)
		M.cyl(root, 0.0, 0.036, 0.07, gold, p + Vector3(0, 0.275, 0), Vector3.ZERO, 4)
		for y in [0.1, 0.16]:
			M.cyl(root, 0.036, 0.036, 0.022, rope, p + Vector3(0, y, 0), Vector3.ZERO, 8)
	ArcherModel._ground_details(root, false)


# Halos que laten en las bobinas (animados)
func _build_coil_glows() -> void:
	var spots: Array = []
	match _tier:
		0:
			spots.append([Vector3(0.31, _py + 0.32 * 0.55 + 0.07, -0.31), 0.6])
		1:
			for s in [-1.0, 1.0]:
				spots.append([Vector3(0.3 * s, _py + 0.36 * 0.55 + 0.07, -0.3), 0.7])
		_:
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					spots.append([Vector3(0.36 * sx, _py + 0.22, 0.36 * sz), 1.0])
			if _tier == 3:
				for rb in _t3_rods():
					var base: Vector3 = rb
					var h := _py + 0.55 - base.y
					spots.append([base + Vector3(0, h * 0.8 + 0.07, 0), 1.2])
	for sp in spots:
		var spot: Array = sp
		var g := M.sphere(self, 0.07 * float(spot[1]), M.mat(ELECTRIC, 1.2), spot[0], Vector3(1, 2.2, 1), 10)
		_coil_glows.append(g)


# Nube de tormenta oscura sobre la torre
func _build_cloud() -> void:
	_cloud = Node3D.new()
	_cloud.position = Vector3(0, _cloud_y, 0)
	_cloud.scale = Vector3.ONE * float(CLOUD_SCALE[_tier])
	add_child(_cloud)
	# la nube se oscurece al crecer la tormenta
	var tone: float = [0.0, 0.05, 0.12, 0.3][_tier]
	var dark := M.mat(CLOUD.darkened(tone))
	var darker := M.mat(CLOUD.darkened(0.15 + tone))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 9:
		var a := TAU * i / 9.0
		var r := rng.randf_range(0.18, 0.28)
		M.sphere(_cloud, r, dark if i % 2 == 0 else darker,
				Vector3(cos(a) * 0.3, rng.randf_range(-0.05, 0.08), sin(a) * 0.3), Vector3(1, 0.75, 1), 12)
	M.sphere(_cloud, 0.3, dark, Vector3(0, 0.08, 0), Vector3(1.1, 0.8, 1.1), 14)
	M.sphere(_cloud, 0.22, darker, Vector3(0.05, -0.08, 0.02), Vector3(1.4, 0.6, 1.3), 12)
	_cloud_flash = M.sphere(_cloud, 0.3, M.mat(ELECTRIC, 2.5), Vector3(0, -0.06, 0), Vector3(1.2, 0.6, 1.2), 12)
	_cloud_flash.visible = false
	if _tier == 3:
		# rayitos en zigzag que chisporrotean bajo la nube de la Maestría
		var bolt_m := M.mat(Color(1.0, 0.95, 0.6), 2.2)
		for i in 3:
			var a := TAU * i / 3.0 + 0.5
			var b := Node3D.new()
			b.position = Vector3(cos(a) * 0.22, -0.12, sin(a) * 0.22)
			_cloud.add_child(b)
			var p0 := Vector3.ZERO
			var pts := [Vector3(0.04, -0.09, 0.0), Vector3(-0.03, -0.17, 0.02), Vector3(0.03, -0.27, 0.0)]
			for q in pts:
				var p1: Vector3 = q
				M.segment(b, 0.012, bolt_m, p1, p0, 4)
				p0 = p1
			_bolts.append(b)


# --- Guerrero nórdico del trueno ---

func _build_cat_body(c: Node3D) -> void:
	var orange := M.mat(ORANGE)
	var light := M.mat(ORANGE_LIGHT)
	var navy := M.mat(NAVY)
	var gold := M.metal(GOLD)
	var rope := M.mat(Color(0.4, 0.26, 0.14))  # cinturón de cuero
	if _tier == 0:
		navy = M.mat(Color(0.36, 0.33, 0.3))      # calzas de lana parda
	if _tier == 3:
		gold = M.metal(Color(1.0, 0.84, 0.36))
	Cat.tail(c, ORANGE, ORANGE_STRIPE)
	# torso musculoso: pectorales y abdominales marcados
	M.sphere(c, 0.15, orange, Vector3(0, 0.2, 0), Vector3(1.2, 1.1, 0.95), 16)
	for s in [-1.0, 1.0]:
		M.sphere(c, 0.06, light, Vector3(0.055 * s, 0.26, -0.11), Vector3(1.1, 0.8, 0.6), 10)
		for y in [0.11, 0.155, 0.2]:
			M.sphere(c, 0.024, light, Vector3(0.03 * s, y, -0.135), Vector3(1.0, 0.8, 0.5), 8)
		M.sphere(c, 0.08, orange, Vector3(0.16 * s, 0.28, 0), Vector3.ONE, 12)
	match _tier:
		0:
			# túnica de lana sin mangas con ribete
			M.sphere(c, 0.155, M.mat(Color(0.55, 0.42, 0.28)), Vector3(0, 0.18, 0), Vector3(1.2, 1.05, 0.98), 16)
			M.cyl(c, 0.17, 0.17, 0.025, M.mat(Color(0.4, 0.3, 0.2)), Vector3(0, 0.27, 0), Vector3.ZERO, 16)
		1:
			# chaleco de cuero tachonado sobre el torso
			M.sphere(c, 0.155, M.mat(Color(0.42, 0.28, 0.16)), Vector3(0, 0.17, 0), Vector3(1.2, 1.0, 0.98), 16)
			for k in 3:
				for s in [-1.0, 1.0]:
					M.sphere(c, 0.012, M.metal(IRON), Vector3(0.06 * s, 0.12 + k * 0.06, -0.15), Vector3.ONE, 6)
		_:
			# banda azul cruzada con cascabeles dorados
			M.segment(c, 0.022, navy, Vector3(-0.12, 0.1, -0.11), Vector3(0.13, 0.33, -0.08), 8)
			for k in 3:
				M.sphere(c, 0.02, gold, Vector3(-0.07 + k * 0.08, 0.15 + k * 0.07, -0.13), Vector3.ONE, 8)
	if _tier >= 2:
		# manto de piel sobre los hombros (blanco y con broches de oro en la Maestría)
		var fur_col := Color(0.55, 0.45, 0.35) if _tier == 2 else Color(0.97, 0.96, 0.93)
		var mantle := TorusMesh.new()
		mantle.inner_radius = 0.1
		mantle.outer_radius = 0.2
		M.add(c, mantle, M.mat(fur_col), Vector3(0, 0.3, 0.025), Vector3(6, 0, 0), Vector3(1.08, 0.55, 1.0))
	if _tier == 3:
		# arnés de oro con disco del trueno en el pecho
		M.cyl(c, 0.06, 0.06, 0.02, gold, Vector3(0, 0.24, -0.15), Vector3(80, 0, 0), 16)
		bolt_emblem(c, Vector3(0, 0.24, -0.163), 1.0, M.mat(ELECTRIC, 1.5))
		for s in [-1.0, 1.0]:
			M.sphere(c, 0.085, gold, Vector3(0.16 * s, 0.3, 0), Vector3(1.0, 0.65, 1.0), 12)
	# pantalón azul, cinturón de cuerda y medallón tomoe
	M.cyl(c, 0.15, 0.17, 0.12, navy, Vector3(0, 0.04, 0), Vector3.ZERO, 16)
	var belt := TorusMesh.new()
	belt.inner_radius = 0.14
	belt.outer_radius = 0.175
	M.add(c, belt, rope, Vector3(0, 0.09, 0))
	M.cyl(c, 0.05, 0.05, 0.02, gold, Vector3(0, 0.09, -0.16), Vector3(90, 0, 0), 16)
	tomoe(c, Vector3(0, 0.09, -0.172), 0.75, M.mat(NAVY_DARK))
	for s in [-1.0, 1.0]:
		M.cyl(c, 0.012, 0.03, 0.08, navy, Vector3(0.06 * s, 0.02, -0.16), Vector3.ZERO, 8)
	# cabeza atigrada anaranjada con boca abierta (contento)
	var h := Cat.head(c, true, true, HAIR_BLOND)
	# barba trenzada nórdica y casco alado
	M.sphere(h, 0.09, M.mat(HAIR_BLOND), Vector3(0, -0.11, -0.08), Vector3(1.0, 1.1, 0.7), 10)
	M.cyl(h, 0.02, 0.03, 0.1, M.mat(HAIR_BLOND), Vector3(0, -0.2, -0.1), Vector3.ZERO, 6)
	match _tier:
		0:
			# gorro de cuero
			M.sphere(h, 0.146, M.mat(Color(0.42, 0.28, 0.16)), Vector3(0, 0.05, 0.01), Vector3(1.0, 0.65, 1.0), 14)
			M.cyl(h, 0.145, 0.145, 0.025, M.mat(Color(0.32, 0.2, 0.11)), Vector3(0, 0.04, 0.01), Vector3.ZERO, 16)
		1:
			# yelmo de hierro con nasal (sin alas)
			M.sphere(h, 0.148, M.metal(Color(0.5, 0.5, 0.54)), Vector3(0, 0.05, 0.01), Vector3(1.0, 0.75, 1.0), 14)
			M.box(h, Vector3(0.025, 0.08, 0.02), M.metal(Color(0.5, 0.5, 0.54)), Vector3(0, 0.0, -0.145))
			M.cyl(h, 0.148, 0.148, 0.025, M.metal(IRON), Vector3(0, 0.04, 0.01), Vector3.ZERO, 16)
		_:
			var helm_col := Color(0.7, 0.72, 0.76) if _tier == 2 else Color(1.0, 0.82, 0.36)
			var wing_col := Color(0.95, 0.95, 0.92)
			M.sphere(h, 0.148, M.metal(helm_col), Vector3(0, 0.05, 0.01), Vector3(1.0, 0.7, 1.0), 14)
			var wl := 0.12 if _tier == 2 else 0.17
			for s2 in [-1.0, 1.0]:
				M.box(h, Vector3(0.02, wl, 0.07), M.mat(wing_col), Vector3(0.15 * s2, 0.1 + wl * 0.2, 0.02), Vector3(0, 0, -30.0 * s2))
				if _tier == 3:
					M.box(h, Vector3(0.018, wl * 0.75, 0.06), M.mat(wing_col), Vector3(0.16 * s2, 0.08 + wl * 0.1, 0.07), Vector3(-25, 0, -50.0 * s2))
			if _tier == 3:
				M.sphere(h, 0.022, M.mat(ELECTRIC, 1.8), Vector3(0, 0.07, -0.14), Vector3(1, 1, 0.6), 8)
	M.sphere(h, 0.025, M.mat(Color(0.45, 0.12, 0.12)), Vector3(0, -0.075, -0.15), Vector3(1.2, 0.8, 0.5), 8)
	# brazo derecho flexionado (bíceps) con muñequera
	var shoulder := Vector3(0.16, 0.28, 0)
	var elbow := Vector3(0.27, 0.22, -0.06)
	var fist := Vector3(0.24, 0.36, -0.12)
	M.segment(c, 0.055, orange, elbow, shoulder if shoulder.y > elbow.y else elbow, 8)
	M.sphere(c, 0.062, orange, Vector3(0.23, 0.27, -0.03), Vector3(1.1, 1.0, 1.0), 10)
	M.segment(c, 0.048, orange, elbow, fist, 8)
	M.cyl(c, 0.055, 0.055, 0.05, navy if _tier < 3 else gold, elbow.lerp(fist, 0.75), Vector3(30, 0, 15), 10)
	M.sphere(c, 0.058, M.mat(Cat.FUR), fist, Vector3.ONE, 10)


# Partes animadas: capa y brazo izquierdo con el puño en alto
func _build_cat_parts() -> void:
	var c := cat_pivot
	_cape = Node3D.new()
	_cape.position = Vector3(0, 0.34, 0.11)
	c.add_child(_cape)
	match _tier:
		0:
			M.box(_cape, Vector3(0.3, 0.26, 0.02), M.mat(Color(0.45, 0.36, 0.26)), Vector3(0, -0.12, 0))
		1:
			M.box(_cape, Vector3(0.34, 0.3, 0.02), M.mat(NAVY), Vector3(0, -0.14, 0))
			M.box(_cape, Vector3(0.36, 0.025, 0.025), M.mat(Color(0.8, 0.7, 0.5)), Vector3(0, -0.29, 0))
		2:
			M.box(_cape, Vector3(0.36, 0.34, 0.02), M.mat(NAVY), Vector3(0, -0.16, 0))
			M.box(_cape, Vector3(0.38, 0.03, 0.03), M.metal(GOLD), Vector3(0, -0.33, 0))
			tomoe(_cape, Vector3(0, -0.15, 0.012), 1.2, M.metal(GOLD))
		_:
			M.box(_cape, Vector3(0.4, 0.46, 0.02), M.mat(NAVY), Vector3(0, -0.22, 0))
			M.box(_cape, Vector3(0.42, 0.035, 0.03), M.metal(GOLD), Vector3(0, -0.45, 0))
			for s in [-1.0, 1.0]:
				M.box(_cape, Vector3(0.025, 0.46, 0.026), M.metal(GOLD), Vector3(0.2 * s, -0.22, 0))
			tomoe(_cape, Vector3(0, -0.2, 0.012), 1.7, M.mat(ELECTRIC, 1.3))
	_fist = Node3D.new()
	_fist.position = Vector3(-0.16, 0.28, 0)
	c.add_child(_fist)
	var orange := M.mat(ORANGE)
	M.sphere(_fist, 0.062, orange, Vector3(-0.04, 0.08, 0), Vector3(1.0, 1.1, 1.0), 10)
	M.segment(_fist, 0.05, orange, Vector3.ZERO, Vector3(-0.06, 0.26, -0.02), 8)
	var bracer: Material = [M.mat(Color(0.42, 0.28, 0.16)), M.mat(NAVY), M.mat(NAVY), M.metal(Color(1.0, 0.84, 0.36))][_tier]
	M.cyl(_fist, 0.058, 0.058, 0.07, bracer, Vector3(-0.055, 0.24, -0.02), Vector3(0, 0, 13), 10)
	if _tier > 0:
		bolt_emblem(_fist, Vector3(-0.055, 0.24, -0.08), 0.9, M.metal(GOLD) if _tier < 3 else M.mat(ELECTRIC, 1.6))
	M.sphere(_fist, 0.062, M.mat(Cat.FUR), Vector3(-0.065, 0.3, -0.02), Vector3.ONE, 10)
