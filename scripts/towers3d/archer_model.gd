extends Node3D
## Modelo 3D de las torres de gato arquero (inspiradas en el arte conceptual):
##  - "archer": torre de piedra con tejado de tejas y gatito de armadura azul.
##  - "poison": torre de madera con enredaderas, pociones y faroles verdes; gatito de cuero
##    con capa verde y flechas venenosas.
## El gatito mira hacia -Z dentro de cat_pivot; la torre rota cat_pivot hacia el enemigo.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")

const STONE_DARK := Color(0.4, 0.39, 0.37)
const WOOD_DARK := Color(0.36, 0.22, 0.11)
const IRON := Color(0.28, 0.28, 0.31)
const GOLD := Color(0.95, 0.75, 0.3)
const RED := Color(0.78, 0.15, 0.12)
const CREAM := Color(0.96, 0.89, 0.74)
const MOSS := Color(0.4, 0.56, 0.22)

const FUR := Color(0.98, 0.96, 0.93)
const FUR_GRAY := Color(0.58, 0.56, 0.55)
const FUR_STRIPE := Color(0.3, 0.28, 0.28)
const PINK := Color(0.96, 0.6, 0.58)
const NAVY := Color(0.18, 0.2, 0.32)
const NAVY_LIGHT := Color(0.28, 0.31, 0.45)
const BOW_WOOD := Color(0.5, 0.26, 0.11)
const SILVER := Color(0.85, 0.87, 0.9)
# Variante venenosa
const LEATHER := Color(0.32, 0.22, 0.13)
const LEATHER_LIGHT := Color(0.46, 0.32, 0.18)
const POISON := Color(0.28, 0.52, 0.18)
const POISON_GLOW := Color(0.5, 1.0, 0.3)
const BONE := Color(0.95, 0.92, 0.82)

const PLATFORM_Y := 1.06
# Arco (coordenadas locales del gatito)
const BOW_X := -0.17
const BOW_Y := 0.36
const BOW_C_Z := -0.06
const BOW_R := 0.22
const BOW_SPAN := 1.22          # ~70 grados a cada lado
const FULL_PULL_Z := -0.04      # posición de la cuerda totalmente tensada
const R_SHOULDER := Vector3(0.13, 0.27, -0.02)
const L_SHOULDER := Vector3(-0.13, 0.27, -0.02)

# Altura de la plataforma del arquero según la etapa visual (0..3)
const PLAT_BY_TIER := [0.8, 1.06, 1.32, 1.5]
const POISON_PLAT_BY_TIER := [0.78, 1.06, 1.3, 1.48]
const ROYAL := Color(0.16, 0.26, 0.62)
const MARBLE := Color(0.97, 0.95, 0.9)
const STRAW := Color(0.86, 0.72, 0.38)
const TOXIC := Color(0.3, 0.85, 0.16)
const VERDIGRIS := Color(0.34, 0.66, 0.4)

var variant := "archer"
var tier := 0
var cat_pivot: Node3D
var _cape: Node3D
var _string_top: Node3D
var _string_bottom: Node3D
var _nocked: Node3D
var _draw_arm: Node3D
var _draw_paw: Node3D
var _tip_top: Vector3
var _tip_bottom: Vector3
# Adornos animados de cada etapa (llamas, banderolas, piezas que giran o flotan)
var _flames: Array[Node3D] = []
var _pennants: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _floaters: Array[Node3D] = []


func _init(v := "archer", level := 0) -> void:
	variant = v
	tier = tier_of(level)
	var plat: float = (POISON_PLAT_BY_TIER if variant == "poison" else PLAT_BY_TIER)[tier]
	M.add_baked(self, M.baked("%s_tower_t%d" % [variant, tier], _build_tower_full))
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, plat, 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("%s_cat_t%d" % [variant, tier], _build_cat_full))
	_build_cat_parts()
	_build_tier_fx()
	set_pose(0.35, true, 0.0, 0.0)


## Etapa visual según el nivel (igual que TowerModels.tier): 0 = nv 0-1, 1 = nv 2-3, 2 = nv 4, 3 = nv 5.
static func tier_of(level: int) -> int:
	if level >= 5:
		return 3
	if level >= 4:
		return 2
	if level >= 2:
		return 1
	return 0


static func bow_point(a: float) -> Vector3:
	return Vector3(BOW_X, BOW_Y + BOW_R * sin(a), BOW_C_Z - BOW_R * cos(a))


# Punta de la flecha cargada, en coordenadas del gatito
static func arrow_tip_local() -> Vector3:
	return Vector3(BOW_X, BOW_Y, BOW_C_Z - BOW_R - 0.1)


## pull: 0 = relajado, 1 = tensado. recoil: 1 justo al soltar -> 0.
func set_pose(pull: float, has_arrow: bool, recoil: float, t: float) -> void:
	var nz := lerpf(_tip_top.z, FULL_PULL_Z, pull)
	if recoil > 0.0:
		nz = _tip_top.z + sin(t * 90.0) * recoil * 0.025
	var nock := Vector3(BOW_X, BOW_Y, nz)
	M.orient_segment(_string_bottom, _tip_bottom, nock)
	M.orient_segment(_string_top, nock, _tip_top)
	_nocked.visible = has_arrow
	_nocked.position = nock
	var hand := Vector3(BOW_X + 0.03, BOW_Y, FULL_PULL_Z + 0.03) if recoil > 0.0 else nock + Vector3(0.02, 0, 0.03)
	_draw_paw.position = hand
	M.orient_segment(_draw_arm, R_SHOULDER, hand)
	_cape.rotation.x = -deg_to_rad(18.0 + sin(t * 5.0) * 7.0)
	animate_fx(t, _flames, _pennants, _spinners, _floaters)


## Anima los adornos de etapa: llamas que parpadean, banderolas que ondean,
## anillos que giran y piezas que flotan. (Compartido con otros modelos.)
static func animate_fx(t: float, flames: Array[Node3D], pennants: Array[Node3D], spinners: Array[Node3D], floaters: Array[Node3D]) -> void:
	for i in flames.size():
		var fl := 0.85 + 0.15 * sin(t * 21.0 + i * 1.7) + 0.08 * sin(t * 37.0 + i)
		flames[i].scale = Vector3(1.0, fl, 1.0)
	for i in pennants.size():
		var pn := pennants[i]
		pn.rotation.y = pn.get_meta("yaw", 0.0) + sin(t * 2.2 + i * 1.3) * 0.3
		var tail := pn.get_child(pn.get_child_count() - 1) as Node3D
		tail.rotation.y = sin(t * 3.4 + i * 1.3 + 0.8) * 0.45
	for i in spinners.size():
		spinners[i].rotation.y = t * (0.6 if i % 2 == 0 else -0.9)
	for i in floaters.size():
		var fp: Vector3 = floaters[i].get_meta("base", Vector3.ZERO)
		floaters[i].position = fp + Vector3(0, sin(t * 2.0 + i) * 0.03, 0)
		floaters[i].rotation.y = t * 0.8


# Flecha apuntando a -Z con la cola (culatín) en el origen. La venenosa tiene punta verde brillante.
static func build_arrow(parent: Node3D, poison := false, golden := false) -> void:
	M.cyl(parent, 0.011, 0.011, 0.42, M.mat(BOW_WOOD), Vector3(0, 0, -0.21), Vector3(90, 0, 0), 6)
	var tip := M.mat(POISON_GLOW, 2.5) if poison else (M.mat(Color(1.0, 0.85, 0.45), 1.6) if golden else M.metal(SILVER))
	M.cyl(parent, 0.0, 0.034 if poison else 0.03, 0.09, tip, Vector3(0, 0, -0.46), Vector3(-90, 0, 0), 8)
	var fletch := M.mat(POISON_GLOW.darkened(0.3) if poison else FUR)
	M.box(parent, Vector3(0.07, 0.004, 0.09), fletch, Vector3(0, 0, -0.05))
	M.box(parent, Vector3(0.004, 0.07, 0.09), fletch, Vector3(0, 0, -0.05))
	M.cyl(parent, 0.016, 0.016, 0.015, M.mat(POISON if poison else RED), Vector3(0, 0, -0.11), Vector3(90, 0, 0), 6)


# --- Torre ---

func _build_tower(parent: Node3D) -> void:
	var bricks := M.tex_mat("bricks", 2.0)
	var stone_dark := M.mat(STONE_DARK)
	var wood := M.tex_mat("wood", 2.0)
	var wood_dark := M.mat(WOOD_DARK)
	var roof := M.tex_mat("roof", 2.5)
	var gold := M.metal(GOLD)
	var red := M.mat(RED)
	var cream := M.mat(CREAM)
	var iron := M.metal(IRON)

	# Base de piedra
	M.box(parent, Vector3(0.84, 0.08, 0.84), stone_dark, Vector3(0, 0.04, 0))
	M.box(parent, Vector3(0.72, 0.52, 0.72), bricks, Vector3(0, 0.34, 0))
	for p in [Vector3(-0.36, 0.09, 0.36), Vector3(0.37, 0.09, 0.3), Vector3(-0.3, 0.09, -0.37)]:
		M.sphere(parent, 0.08, M.mat(MOSS), p, Vector3(1, 0.5, 1), 8)

	# Estandarte frontal con huella
	M.box(parent, Vector3(0.22, 0.4, 0.02), red, Vector3(0, 0.36, 0.37))
	M.cyl(parent, 0.065, 0.065, 0.01, cream, Vector3(0, 0.44, 0.382), Vector3(90, 0, 0), 16)
	_paw(parent, Vector3(0, 0.44, 0.389), 0.011, red)
	for y in [0.22, 0.26]:
		M.box(parent, Vector3(0.18, 0.012, 0.004), cream, Vector3(0, y, 0.382))
	M.box(parent, Vector3(0.28, 0.025, 0.03), wood_dark, Vector3(0, 0.57, 0.38))
	M.sphere(parent, 0.02, gold, Vector3(-0.14, 0.57, 0.38))
	M.sphere(parent, 0.02, gold, Vector3(0.14, 0.57, 0.38))
	# Estandarte lateral
	M.box(parent, Vector3(0.02, 0.26, 0.16), red, Vector3(0.37, 0.4, 0.08))
	M.cyl(parent, 0.04, 0.04, 0.008, cream, Vector3(0.382, 0.44, 0.08), Vector3(0, 0, 90), 12)

	# Armazón de madera bajo el tejado
	M.box(parent, Vector3(0.56, 0.2, 0.56), M.mat(Color(0.2, 0.14, 0.09)), Vector3(0, 0.7, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.07, 0.22, 0.07), wood_dark, Vector3(0.3 * sx, 0.71, 0.3 * sz))
			M.box(parent, Vector3(0.1, 0.08, 0.1), iron, Vector3(0.3 * sx, 0.62, 0.3 * sz))
	for y in [0.66, 0.76]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.62, 0.045, 0.045), wood, Vector3(0, y, 0.3 * s))
			M.box(parent, Vector3(0.045, 0.045, 0.62), wood, Vector3(0.3 * s, y, 0))

	# Tejado de tejas con pomos dorados en las esquinas
	M.cyl(parent, 0.36, 0.68, 0.18, roof, Vector3(0, 0.91, 0), Vector3(0, 45, 0), 4)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.sphere(parent, 0.035, gold, Vector3(0.48 * sx, 0.83, 0.48 * sz), Vector3.ONE, 10)
	M.cyl(parent, 0.065, 0.065, 0.015, gold, Vector3(0, 0.92, 0.375), Vector3(52, 0, 0), 16)
	_paw(parent, Vector3(0, 0.927, 0.385), 0.01, wood_dark)

	# Plataforma con barandilla
	M.box(parent, Vector3(0.62, 0.06, 0.62), wood, Vector3(0, 1.03, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.05, 0.15, 0.05), wood_dark, Vector3(0.28 * sx, 1.12, 0.28 * sz))
			M.sphere(parent, 0.035, gold, Vector3(0.28 * sx, 1.21, 0.28 * sz), Vector3.ONE, 10)
	for y in [1.1, 1.16]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.56, 0.025, 0.025), wood_dark, Vector3(0, y, 0.28 * s))
			M.box(parent, Vector3(0.025, 0.025, 0.56), wood_dark, Vector3(0.28 * s, y, 0))

	# Caja de flechas y estacas
	M.box(parent, Vector3(0.16, 0.15, 0.13), wood, Vector3(-0.4, 0.075, 0.42))
	for k in 3:
		var x := -0.44 + k * 0.04
		M.box(parent, Vector3(0.01, 0.12, 0.01), cream, Vector3(x, 0.2, 0.42))
		M.box(parent, Vector3(0.03, 0.04, 0.006), red if k % 2 == 0 else cream, Vector3(x, 0.27, 0.42))
	for p in [Vector3(0.42, 0, 0.4), Vector3(0.45, 0, 0.26)]:
		M.cyl(parent, 0.025, 0.025, 0.2, wood_dark, p + Vector3(0, 0.1, 0), Vector3.ZERO, 6)
		M.cyl(parent, 0.0, 0.025, 0.05, wood_dark, p + Vector3(0, 0.225, 0), Vector3.ZERO, 6)


## Emblema heráldico (cruz de brazos anchos) en lugar de la huella de gato original.
func _paw(parent: Node3D, c: Vector3, s: float, col: Material) -> void:
	M.box(parent, Vector3(1.6 * s, 6.0 * s, 0.6 * s), col, c)
	M.box(parent, Vector3(5.0 * s, 1.6 * s, 0.6 * s), col, c + Vector3(0, 0.8 * s, 0))


# --- Arquero humano ---

# Partes fijas del gatito (se fusionan en una sola malla compartida por todas las torres)
func _build_cat_body(c: Node3D) -> void:
	var poison := variant == "poison"
	var skin := M.mat(Human.SKIN)
	var gold := M.metal(GOLD)
	var bow_wood := M.mat(BOW_WOOD)
	var fur := M.mat(FUR)
	var cloth := _sleeve_mat()
	var trim := _trim_mat()
	var leather := M.mat(LEATHER_LIGHT)
	var steel := M.metal(SILVER.darkened(0.25))
	var shiny := M.metal(SILVER)
	var mail := M.metal(Color(0.5, 0.52, 0.56))

	# Cuerpo: túnica, gambesón, cota de malla o armadura brillante según la etapa
	M.sphere(c, 0.14, cloth, Vector3(0, 0.18, 0), Vector3(1, 1.15, 0.9), 14)
	M.cyl(c, 0.045, 0.05, 0.06, skin, Vector3(0, 0.35, 0), Vector3.ZERO, 10)
	M.cyl(c, 0.143, 0.143, 0.035, trim, Vector3(0, 0.12, 0), Vector3.ZERO, 14)
	match tier:
		0:
			# túnica sencilla con cinturón de cuerda y faldón
			M.cyl(c, 0.12, 0.16, 0.1, cloth, Vector3(0, 0.06, 0), Vector3.ZERO, 12)
			for s: float in [-1.0, 1.0]:
				M.sphere(c, 0.06, cloth, Vector3(0.13 * s, 0.27, 0), Vector3.ONE, 10)
		1:
			M.sphere(c, 0.09, steel if not poison else leather, Vector3(0, 0.19, -0.065), Vector3(1, 1.15, 0.65), 12)
			M.sphere(c, 0.025, gold, Vector3(0, 0.12, -0.135), Vector3.ONE, 8)
			for s: float in [-1.0, 1.0]:
				M.sphere(c, 0.065, M.mat(LEATHER_LIGHT if poison else NAVY_LIGHT), Vector3(0.13 * s, 0.27, 0), Vector3.ONE, 10)
				M.sphere(c, 0.02, gold, Vector3(0.15 * s, 0.3, -0.04), Vector3.ONE, 6)
		2:
			if poison:
				# casaca verde oscura con bandolera de frascos brillantes
				M.cyl(c, 0.12, 0.165, 0.12, cloth, Vector3(0, 0.06, 0), Vector3.ZERO, 12)
				M.box(c, Vector3(0.035, 0.32, 0.02), leather, Vector3(0, 0.2, -0.125), Vector3(-10, 0, -35))
				for k in 3:
					M.cyl(c, 0.014, 0.014, 0.045, M.mat(POISON_GLOW, 1.6), Vector3(-0.06 + k * 0.05, 0.14 + k * 0.05, -0.14), Vector3(0, 0, -35), 6)
				for s: float in [-1.0, 1.0]:
					M.sphere(c, 0.066, leather, Vector3(0.13 * s, 0.27, 0), Vector3(1, 0.8, 1), 10)
					M.sphere(c, 0.018, M.metal(Color(0.72, 0.5, 0.25)), Vector3(0.15 * s, 0.31, -0.03), Vector3.ONE, 6)
			else:
				# cota de malla con sobreveste roja y cruz dorada, hombreras de acero
				M.cyl(c, 0.12, 0.165, 0.12, mail, Vector3(0, 0.06, 0), Vector3.ZERO, 12)
				M.box(c, Vector3(0.17, 0.28, 0.02), M.mat(RED), Vector3(0, 0.13, -0.123), Vector3(-4, 0, 0))
				M.box(c, Vector3(0.17, 0.28, 0.02), M.mat(RED), Vector3(0, 0.13, 0.123), Vector3(4, 0, 0))
				M.box(c, Vector3(0.03, 0.17, 0.012), gold, Vector3(0, 0.15, -0.136), Vector3(-4, 0, 0))
				M.box(c, Vector3(0.11, 0.03, 0.012), gold, Vector3(0, 0.19, -0.137), Vector3(-4, 0, 0))
				for s: float in [-1.0, 1.0]:
					M.sphere(c, 0.07, steel, Vector3(0.13 * s, 0.28, 0), Vector3(1, 0.75, 1), 10)
		3:
			# armadura brillante con sobreveste (real o veneno) y hombreras doradas
			var robe := M.mat(ROYAL if not poison else Color(0.12, 0.24, 0.12))
			M.cyl(c, 0.12, 0.17, 0.13, shiny if not poison else cloth, Vector3(0, 0.06, 0), Vector3.ZERO, 14)
			M.sphere(c, 0.095, shiny, Vector3(0, 0.2, -0.06), Vector3(1, 1.1, 0.65), 12)
			M.box(c, Vector3(0.15, 0.24, 0.02), robe, Vector3(0, 0.1, -0.128), Vector3(-6, 0, 0))
			M.box(c, Vector3(0.165, 0.02, 0.024), gold, Vector3(0, 0.215, -0.12), Vector3(-6, 0, 0))
			M.box(c, Vector3(0.02, 0.24, 0.024), gold, Vector3(0.075, 0.1, -0.13), Vector3(-6, 0, 0))
			M.box(c, Vector3(0.02, 0.24, 0.024), gold, Vector3(-0.075, 0.1, -0.13), Vector3(-6, 0, 0))
			M.sphere(c, 0.03, M.mat(POISON_GLOW if poison else Color(0.55, 0.85, 1.0), 1.8), Vector3(0, 0.15, -0.145), Vector3(1, 1, 0.5), 8)
			for s: float in [-1.0, 1.0]:
				M.sphere(c, 0.075, gold, Vector3(0.13 * s, 0.29, 0), Vector3(1, 0.7, 1), 12)
				M.sphere(c, 0.068, shiny, Vector3(0.135 * s, 0.26, 0), Vector3(1, 0.7, 1), 10)
				M.sphere(c, 0.016, gold, Vector3(0.15 * s, 0.33, -0.04), Vector3.ONE, 6)

	# Carcaj con flechas
	M.cyl(c, 0.045, 0.04, 0.26, M.mat(LEATHER) if tier == 0 else bow_wood, Vector3(-0.07, 0.3, 0.13), Vector3(15, 0, 25), 10)
	if tier == 3:
		M.cyl(c, 0.05, 0.05, 0.03, gold, Vector3(-0.1, 0.4, 0.145), Vector3(15, 0, 25), 10)
	var fletch := M.mat(POISON if poison else RED)
	for p: Vector3 in [Vector3(-0.13, 0.43, 0.16), Vector3(-0.1, 0.44, 0.13), Vector3(-0.15, 0.41, 0.12)]:
		M.sphere(c, 0.025, fur, p, Vector3(1, 1.4, 1), 6)
		M.sphere(c, 0.012, fletch, p + Vector3(0, 0.03, 0), Vector3.ONE, 6)

	# Cabeza: capucha (etapas 0-2) o yelmo brillante (Maestría del arquero)
	var hair := Color(0.45, 0.28, 0.14) if not poison else Color(0.2, 0.15, 0.1)
	var head := Human.head(c, true, true, hair)
	if tier == 3 and not poison:
		# yelmo plateado con cresta dorada y penacho blanco
		M.sphere(head, 0.152, shiny, Vector3(0, 0.04, 0.03), Vector3(1.0, 0.92, 1.0), 16)
		M.cyl(head, 0.155, 0.155, 0.03, gold, Vector3(0, 0.0, 0.03), Vector3(-6, 0, 0), 18)
		M.box(head, Vector3(0.025, 0.05, 0.24), gold, Vector3(0, 0.17, 0.03))
		for k in 4:
			M.sphere(head, 0.04, M.mat(Color(0.98, 0.97, 0.95)), Vector3(0, 0.2 + k * 0.01, 0.08 + k * 0.045), Vector3(0.6, 1.0, 1.4), 8)
		for s: float in [-1.0, 1.0]:
			# alas doradas a los lados
			M.box(head, Vector3(0.012, 0.09, 0.05), gold, Vector3(0.155 * s, 0.07, 0.04), Vector3(-30, 0, 15.0 * s))
			M.box(head, Vector3(0.012, 0.07, 0.04), gold, Vector3(0.16 * s, 0.11, 0.08), Vector3(-45, 0, 20.0 * s))
	else:
		var hood_col := Color(0.25, 0.4, 0.2) if not poison else LEATHER
		if poison and tier >= 2:
			hood_col = Color(0.16, 0.26, 0.13) if tier == 2 else Color(0.1, 0.18, 0.1)
		var hood := M.mat(hood_col)
		M.sphere(head, 0.155, hood, Vector3(0, 0.03, 0.035), Vector3(1.0, 1.0, 1.0), 14)
		M.cyl(head, 0.0, 0.06, 0.16, hood, Vector3(0, 0.05, 0.17), Vector3(-60, 0, 0), 8)
		if poison and tier == 3:
			var rim := TorusMesh.new()
			rim.inner_radius = 0.145
			rim.outer_radius = 0.162
			M.add(head, rim, gold, Vector3(0, 0.02, -0.04), Vector3(80, 0, 0))
		if not poison and tier == 2:
			# capacete de acero sobre la capucha
			M.sphere(head, 0.16, steel, Vector3(0, 0.09, 0.03), Vector3(1.0, 0.6, 1.0), 14)
			M.cyl(head, 0.17, 0.2, 0.02, steel, Vector3(0, 0.07, 0.03), Vector3(-5, 0, 0), 18)
		if not poison and tier == 0:
			# pluma en la capucha
			M.box(head, Vector3(0.012, 0.12, 0.03), M.mat(Color(0.9, 0.85, 0.7)), Vector3(0.1, 0.13, 0.09), Vector3(-25, 0, -20))

	# Arco curvo (segmentos), amarre y pomos (dorados desde la etapa 1)
	var n := 8
	var limb := bow_wood if tier < 3 else M.mat(Color(0.32, 0.16, 0.08))
	for i in n:
		var a0 := -BOW_SPAN + 2.0 * BOW_SPAN * i / n
		var a1 := -BOW_SPAN + 2.0 * BOW_SPAN * (i + 1) / n
		M.segment(c, 0.014, limb, bow_point(a0), bow_point(a1), 6)
	M.segment(c, 0.021, M.mat(LEATHER) if tier == 0 else fletch, bow_point(-0.15), bow_point(0.15), 6)
	if tier >= 1:
		M.sphere(c, 0.02, gold, bow_point(-BOW_SPAN), Vector3.ONE, 8)
		M.sphere(c, 0.02, gold, bow_point(BOW_SPAN), Vector3.ONE, 8)
	if tier == 3:
		for a: float in [-0.7, 0.7]:
			M.segment(c, 0.018, gold, bow_point(a - 0.08), bow_point(a + 0.08), 6)

	# Brazo que sostiene el arco (con brazal)
	var grip := bow_point(0.0) + Vector3(0, 0, 0.02)
	M.segment(c, 0.04, cloth, L_SHOULDER, grip, 8)
	M.segment(c, 0.047, gold if tier == 3 else leather, L_SHOULDER.lerp(grip, 0.55), L_SHOULDER.lerp(grip, 0.85), 8)
	M.sphere(c, 0.042, M.mat(LEATHER) if tier >= 2 else skin, grip, Vector3(1, 1.1, 0.9), 8)


# Material del cuerpo y las mangas según variante y etapa
func _sleeve_mat() -> Material:
	if variant == "poison":
		match tier:
			2: return M.mat(Color(0.2, 0.3, 0.16))
			3: return M.mat(Color(0.12, 0.18, 0.11))
		return M.mat(LEATHER)
	match tier:
		0: return M.mat(Color(0.47, 0.38, 0.24))
		2: return M.metal(Color(0.5, 0.52, 0.56))
		3: return M.metal(SILVER)
	return M.mat(NAVY)


func _trim_mat() -> Material:
	if tier == 0:
		return M.mat(Color(0.75, 0.62, 0.42))
	if tier == 3:
		return M.metal(GOLD)
	return M.mat(POISON if variant == "poison" else RED)


func _cape_color() -> Color:
	if variant == "poison":
		return [Color(0.3, 0.4, 0.18), POISON, Color(0.2, 0.4, 0.15), Color(0.16, 0.36, 0.14)][tier]
	return [Color(0.32, 0.46, 0.22), RED, RED, ROYAL][tier]


# Partes animadas: capa, cuerda, flecha cargada y brazo que tensa
func _build_cat_parts() -> void:
	var c := cat_pivot
	_tip_bottom = bow_point(-BOW_SPAN)
	_tip_top = bow_point(BOW_SPAN)

	_cape = Node3D.new()
	_cape.position = Vector3(0, 0.33, 0.1)
	c.add_child(_cape)
	var cape_m := M.mat(_cape_color())
	var cape_h: float = [0.24, 0.32, 0.34, 0.4][tier]
	M.box(_cape, Vector3(0.28 if tier == 0 else 0.3, cape_h, 0.02), cape_m, Vector3(0, -cape_h * 0.47, 0))
	if tier == 3:
		var gold := M.metal(GOLD)
		M.box(_cape, Vector3(0.32, 0.03, 0.024), gold, Vector3(0, -cape_h * 0.94, 0))
		M.box(_cape, Vector3(0.024, cape_h, 0.024), gold, Vector3(0.15, -cape_h * 0.47, 0))
		M.box(_cape, Vector3(0.024, cape_h, 0.024), gold, Vector3(-0.15, -cape_h * 0.47, 0))
		M.sphere(_cape, 0.035, M.mat(POISON_GLOW, 1.2) if variant == "poison" else gold, Vector3(0, -cape_h * 0.45, 0.014), Vector3(1, 1, 0.4), 10)

	var string_mat := M.mat(CREAM)
	_string_bottom = M.add(c, M.tube_mesh(0.005, 4), string_mat)
	_string_top = M.add(c, M.tube_mesh(0.005, 4), string_mat)

	_nocked = Node3D.new()
	c.add_child(_nocked)
	build_arrow(_nocked, variant == "poison", tier == 3)

	_draw_arm = M.add(c, M.tube_mesh(0.04, 8), _sleeve_mat())
	_draw_paw = M.sphere(c, 0.042, M.mat(LEATHER) if tier >= 2 else M.mat(Human.SKIN), Vector3.ZERO, Vector3(1, 1.1, 0.9), 8)


# --- Torre venenosa: madera, enredaderas, pociones verdes, faroles, colmillos y estandarte de serpiente ---

func _build_poison_tower(parent: Node3D) -> void:
	var stone := M.tex_mat("bricks", 2.0, Color(0.8, 0.8, 0.78))
	var wood := M.tex_mat("wood", 2.0, Color(0.75, 0.7, 0.6))
	var wood_dark := M.mat(Color(0.3, 0.19, 0.1))
	var iron := M.metal(IRON)
	var bronze := M.metal(Color(0.72, 0.5, 0.25))
	var glow := M.mat(POISON_GLOW, 2.2)
	var glass := M.mat(POISON_GLOW.darkened(0.15), 1.4)
	var leaf := M.mat(Color(0.3, 0.55, 0.2))
	var banner := M.mat(Color(0.2, 0.36, 0.16))
	var bone := M.mat(BONE)

	# Base de piedra y cuerpo de madera
	M.box(parent, Vector3(0.86, 0.1, 0.86), M.mat(STONE_DARK), Vector3(0, 0.05, 0))
	M.box(parent, Vector3(0.74, 0.3, 0.74), stone, Vector3(0, 0.25, 0))
	M.box(parent, Vector3(0.64, 0.62, 0.64), wood, Vector3(0, 0.71, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.08, 0.98, 0.08), wood_dark, Vector3(0.33 * sx, 0.59, 0.33 * sz))
			M.box(parent, Vector3(0.1, 0.06, 0.1), iron, Vector3(0.33 * sx, 0.44, 0.33 * sz))
	for y in [0.42, 0.98]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.72, 0.05, 0.05), wood_dark, Vector3(0, y, 0.34 * s))
			M.box(parent, Vector3(0.05, 0.05, 0.72), wood_dark, Vector3(0.34 * s, y, 0))

	# Gran matraz de veneno y botellas brillantes
	M.sphere(parent, 0.12, glass, Vector3(-0.17, 0.64, 0.33), Vector3.ONE, 14)
	M.cyl(parent, 0.035, 0.04, 0.08, glass, Vector3(-0.17, 0.78, 0.33), Vector3.ZERO, 10)
	M.cyl(parent, 0.04, 0.04, 0.03, bronze, Vector3(-0.17, 0.83, 0.33), Vector3.ZERO, 10)
	M.cyl(parent, 0.03, 0.03, 0.1, glass, Vector3(0.05, 0.82, 0.34), Vector3.ZERO, 8)
	M.cyl(parent, 0.035, 0.035, 0.12, glass, Vector3(0.36, 0.62, 0.05), Vector3(0, 0, 90), 8)
	# tubería de cobre
	M.segment(parent, 0.02, bronze, Vector3(-0.05, 0.62, 0.34), Vector3(0.0, 0.9, 0.34), 8)

	# Estandarte verde con serpiente
	M.box(parent, Vector3(0.22, 0.34, 0.02), banner, Vector3(0.17, 0.66, 0.345))
	var snake := [Vector3(0.12, 0.56, 0.358), Vector3(0.21, 0.61, 0.358), Vector3(0.13, 0.67, 0.358), Vector3(0.21, 0.73, 0.358)]
	for i in range(snake.size() - 1):
		var a: Vector3 = snake[i]
		var b: Vector3 = snake[i + 1]
		M.segment(parent, 0.013, bone, a, b, 6)
	M.sphere(parent, 0.022, bone, snake[snake.size() - 1], Vector3.ONE, 8)
	# escudo redondo con colmillos
	M.cyl(parent, 0.1, 0.1, 0.03, wood_dark, Vector3(0.0, 0.3, 0.385), Vector3(90, 0, 0), 16)
	M.cyl(parent, 0.1, 0.1, 0.02, bronze, Vector3(0.0, 0.3, 0.38), Vector3(90, 0, 0), 16)
	M.cyl(parent, 0.075, 0.075, 0.03, wood, Vector3(0.0, 0.3, 0.39), Vector3(90, 0, 0), 16)
	for s in [-1.0, 1.0]:
		M.cyl(parent, 0.0, 0.016, 0.06, bone, Vector3(0.025 * s, 0.29, 0.41), Vector3(180, 0, 0), 6)

	# Enredaderas con hojas y florecitas
	var vine := [Vector3(-0.33, 0.95, 0.35), Vector3(-0.28, 0.82, 0.36), Vector3(-0.3, 0.68, 0.37),
			Vector3(-0.25, 0.52, 0.37), Vector3(-0.29, 0.38, 0.38), Vector3(0.3, 0.9, 0.36), Vector3(0.33, 0.76, 0.33)]
	for i in vine.size():
		var p: Vector3 = vine[i]
		M.sphere(parent, 0.05, leaf, p, Vector3(1.2, 0.8, 0.5), 8)
		M.sphere(parent, 0.035, leaf, p + Vector3(0.04, -0.04, 0.01), Vector3(1.2, 0.8, 0.5), 8)
		if i % 2 == 0:
			M.sphere(parent, 0.016, M.mat(Color.WHITE), p + Vector3(-0.02, 0.03, 0.03), Vector3.ONE, 6)

	# Faroles verdes colgando a los lados
	for s in [-1.0, 1.0]:
		var lp := Vector3(0.46 * s, 0.8, 0.0)
		M.box(parent, Vector3(0.16, 0.03, 0.03), wood_dark, Vector3(0.39 * s, 0.97, 0.0))
		M.segment(parent, 0.006, iron, lp + Vector3(0, 0.07, 0), lp + Vector3(0, 0.17, 0), 4)
		M.box(parent, Vector3(0.09, 0.12, 0.09), iron, lp)
		M.box(parent, Vector3(0.07, 0.1, 0.1), glow, lp)
		M.box(parent, Vector3(0.1, 0.1, 0.07), glow, lp)
		M.cyl(parent, 0.0, 0.06, 0.05, iron, lp + Vector3(0, 0.085, 0), Vector3.ZERO, 4)

	# Plataforma con barandilla y colmillos en las esquinas
	M.box(parent, Vector3(0.66, 0.06, 0.66), wood, Vector3(0, 1.03, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.05, 0.16, 0.05), wood_dark, Vector3(0.3 * sx, 1.13, 0.3 * sz))
			var tusk := Node3D.new()
			tusk.position = Vector3(0.33 * sx, 1.12, 0.33 * sz)
			tusk.rotation = Vector3(0.6 * sz, 0, -0.6 * sx)
			parent.add_child(tusk)
			M.cyl(tusk, 0.0, 0.03, 0.16, bone, Vector3(0, 0.08, 0), Vector3.ZERO, 8)
	for y in [1.1, 1.17]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.58, 0.025, 0.025), wood_dark, Vector3(0, y, 0.3 * s))
			M.box(parent, Vector3(0.025, 0.025, 0.58), wood_dark, Vector3(0.3 * s, y, 0))
	# hierbas secas colgando de la barandilla
	M.sphere(parent, 0.04, M.mat(Color(0.55, 0.62, 0.3)), Vector3(-0.15, 1.08, 0.31), Vector3(0.7, 1.4, 0.5), 8)

	# Caja de flechas venenosas, estacas y cristales verdes
	M.box(parent, Vector3(0.16, 0.15, 0.13), wood, Vector3(-0.4, 0.075, 0.42))
	for k in 3:
		var x := -0.44 + k * 0.04
		M.box(parent, Vector3(0.01, 0.12, 0.01), wood_dark, Vector3(x, 0.2, 0.42))
		M.cyl(parent, 0.0, 0.018, 0.04, glow, Vector3(x, 0.28, 0.42), Vector3.ZERO, 4)
	for p in [Vector3(0.42, 0, 0.4), Vector3(0.45, 0, 0.26)]:
		M.cyl(parent, 0.025, 0.025, 0.2, wood_dark, p + Vector3(0, 0.1, 0), Vector3.ZERO, 6)
		M.cyl(parent, 0.0, 0.025, 0.05, bone, p + Vector3(0, 0.225, 0), Vector3.ZERO, 6)
	for c in [[Vector3(0.22, 0.06, 0.44), 15.0], [Vector3(0.28, 0.04, 0.47), -20.0]]:
		M.cyl(parent, 0.0, 0.035, 0.12, glow, c[0], Vector3(0, 0, c[1]), 5)

# --- Detalles extra (para parecerse más al arte conceptual) ---

func _build_tower_full(parent: Node3D) -> void:
	if variant == "poison":
		match tier:
			0: _poison_t0(parent)
			2: _poison_t2(parent)
			3: _poison_t3(parent)
			_:
				_build_poison_tower(parent)
				_poison_details(parent)
	else:
		match tier:
			0: _archer_t0(parent)
			2: _archer_t2(parent)
			3: _archer_t3(parent)
			_:
				_build_tower(parent)
				_archer_details(parent)
	_ground_details(parent, variant == "poison")


func _build_cat_full(c: Node3D) -> void:
	_build_cat_body(c)
	_cat_extras(c)
	if variant == "poison":
		if tier == 0:
			_cloth_mask(c)
		else:
			_gas_mask(c)


# Bloques de piedra que sobresalen en las caras de la base (salta las zonas indicadas)
static func _stone_blocks(parent: Node3D, half: float, y0: float, rows: int, skip: Array, mats: Array, moss: Material = null) -> void:
	var faces := [[Vector3(0, 0, 1), Vector3(1, 0, 0)], [Vector3(0, 0, -1), Vector3(1, 0, 0)],
			[Vector3(1, 0, 0), Vector3(0, 0, 1)], [Vector3(-1, 0, 0), Vector3(0, 0, 1)]]
	var k := 0
	for fi in faces.size():
		var n: Vector3 = faces[fi][0]
		var tg: Vector3 = faces[fi][1]
		for row in rows:
			for col in 3:
				var off := -0.22 + col * 0.22 + (0.08 if row % 2 == 1 else 0.0)
				if absf(off) > half - 0.1 or [fi, col] in skip:
					continue
				var pos := n * (half + 0.012) + tg * off + Vector3(0, y0 + row * 0.15, 0)
				var size := Vector3(0.19, 0.12, 0.045) if absf(n.z) > 0.5 else Vector3(0.045, 0.12, 0.19)
				M.box(parent, size, mats[k % mats.size()], pos)
				if moss and (k % 3 == 0):
					M.sphere(parent, 0.05, moss, pos + Vector3(0, 0.06, 0) + n * 0.01, Vector3(1.4, 0.4, 1.0), 8)
				k += 1


# Hierba, flores y piedrecitas alrededor de la base
static func _ground_details(parent: Node3D, mossy: bool) -> void:
	var grass := M.mat(Color(0.32, 0.6, 0.2))
	var flowers := [M.mat(Color.WHITE), M.mat(Color(1.0, 0.85, 0.3)), M.mat(Color(1.0, 0.6, 0.75))]
	var spots := [Vector3(-0.44, 0, -0.1), Vector3(-0.42, 0, 0.2), Vector3(0.44, 0, -0.2), Vector3(0.43, 0, 0.1),
			Vector3(-0.2, 0, -0.44), Vector3(0.15, 0, -0.45), Vector3(0.3, 0, 0.46), Vector3(-0.15, 0, 0.47)]
	for i in spots.size():
		var p: Vector3 = spots[i]
		for b in 4:
			var a := TAU * b / 4.0 + i
			var blade := Node3D.new()
			blade.position = p + Vector3(cos(a), 0, sin(a)) * 0.02
			blade.rotation = Vector3(sin(a) * 0.4, 0, -cos(a) * 0.4)
			parent.add_child(blade)
			M.cyl(blade, 0.0, 0.016, 0.1, grass, Vector3(0, 0.05, 0), Vector3.ZERO, 4)
		M.sphere(parent, 0.018, flowers[i % 3], p + Vector3(0.04, 0.05, 0.03), Vector3.ONE, 6)
		if mossy and i % 2 == 0:
			M.sphere(parent, 0.06, M.mat(Color(0.36, 0.56, 0.2)), p + Vector3(-0.03, 0.01, 0), Vector3(1.3, 0.35, 1.1), 8)
	for p in [Vector3(-0.47, 0, 0.0), Vector3(0.0, 0, -0.48), Vector3(0.47, 0, -0.35)]:
		M.sphere(parent, 0.04, M.mat(Color(0.6, 0.58, 0.55)), p + Vector3(0, 0.02, 0), Vector3(1.2, 0.6, 1), 8)


func _archer_details(parent: Node3D) -> void:
	var stones := [M.mat(Color(0.56, 0.54, 0.5)), M.mat(Color(0.48, 0.46, 0.43)), M.mat(Color(0.62, 0.6, 0.56))]
	var wood_dark := M.mat(WOOD_DARK)
	var gold := M.metal(GOLD)
	var red := M.mat(RED)
	# piedras talladas (sin tapar los estandartes)
	_stone_blocks(parent, 0.36, 0.16, 3, [[0, 1], [2, 1]], stones)
	# celosía de madera bajo el tejado
	for s in [-1.0, 1.0]:
		for o in [-0.15, 0.0, 0.15]:
			M.box(parent, Vector3(0.022, 0.2, 0.022), wood_dark, Vector3(o, 0.71, 0.305 * s))
			M.box(parent, Vector3(0.022, 0.2, 0.022), wood_dark, Vector3(0.305 * s, 0.71, o))
	# remaches dorados en los herrajes
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.sphere(parent, 0.014, gold, Vector3(0.3 * sx + 0.02 * sx, 0.62, 0.3 * sz + 0.05 * sz), Vector3.ONE, 6)
	# almenas de piedra en las esquinas del alero (estilo europeo)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.12, 0.1, 0.12), stones[2], Vector3(0.42 * sx, 0.86, 0.42 * sz))
	# escudo heráldico en el estandarte lateral
	M.box(parent, Vector3(0.012, 0.1, 0.08), M.metal(GOLD), Vector3(0.39, 0.33, 0.08))
	# cumbrera del tejado
	M.box(parent, Vector3(0.52, 0.04, 0.05), M.tex_mat("roof", 2.5), Vector3(0, 1.0, 0))
	# escalones de piedra
	M.box(parent, Vector3(0.42, 0.06, 0.12), stones[1], Vector3(0, 0.03, 0.48))
	# cuerdas en las estacas
	for p in [Vector3(0.42, 0, 0.4), Vector3(0.45, 0, 0.26)]:
		for y in [0.1, 0.16]:
			M.cyl(parent, 0.032, 0.032, 0.025, M.mat(Color(0.82, 0.7, 0.5)), p + Vector3(0, y, 0), Vector3.ZERO, 8)


func _poison_details(parent: Node3D) -> void:
	var stones := [M.mat(Color(0.52, 0.53, 0.49)), M.mat(Color(0.45, 0.47, 0.43))]
	var moss := M.mat(Color(0.36, 0.56, 0.2))
	var leaf := M.mat(Color(0.3, 0.55, 0.2))
	var glass := M.mat(POISON_GLOW.darkened(0.15), 1.4)
	var cork := M.mat(Color(0.62, 0.45, 0.28))
	var bronze := M.metal(Color(0.72, 0.5, 0.25))
	var wood_dark := M.mat(Color(0.3, 0.19, 0.1))
	# piedras con musgo en la base
	_stone_blocks(parent, 0.37, 0.15, 2, [[0, 1]], stones, moss)
	# enredaderas bajando por los lados
	for s in [-1.0, 1.0]:
		var z := -0.2
		var y := 1.0
		while y > 0.42:
			M.sphere(parent, 0.045, leaf, Vector3(0.345 * s, y, z), Vector3(0.5, 0.8, 1.2), 8)
			M.sphere(parent, 0.03, leaf, Vector3(0.35 * s, y - 0.04, z + 0.04), Vector3(0.5, 0.8, 1.2), 8)
			y -= 0.09
			z += 0.05 * sin(y * 20.0)
	# manojos de hierbas colgando de la barandilla
	for x in [-0.12, 0.12]:
		var top := Vector3(x, 1.09, 0.33)
		M.segment(parent, 0.006, M.mat(Color(0.75, 0.62, 0.42)), top + Vector3(0, -0.08, 0), top, 4)
		for k in 4:
			M.sphere(parent, 0.022, M.mat(Color(0.45, 0.62, 0.28)), top + Vector3(-0.025 + k * 0.017, -0.13, 0.01), Vector3(0.6, 1.8, 0.6), 6)
		M.sphere(parent, 0.012, M.mat(Color.WHITE), top + Vector3(0.0, -0.1, 0.03), Vector3.ONE, 6)
	# repisa con frascos de veneno en el lado izquierdo
	M.box(parent, Vector3(0.06, 0.02, 0.26), wood_dark, Vector3(-0.36, 0.47, 0.12))
	for k in 3:
		var bp := Vector3(-0.37, 0.53, 0.03 + k * 0.08)
		M.cyl(parent, 0.022 + k * 0.004, 0.026 + k * 0.004, 0.08, glass, bp, Vector3.ZERO, 8)
		M.cyl(parent, 0.012, 0.012, 0.02, cork, bp + Vector3(0, 0.05, 0), Vector3.ZERO, 6)
	# tuberías de cobre con codos
	M.segment(parent, 0.016, bronze, Vector3(0.36, 0.3, -0.2), Vector3(0.36, 0.62, -0.2), 8)
	M.sphere(parent, 0.024, bronze, Vector3(0.36, 0.62, -0.2), Vector3.ONE, 8)
	M.segment(parent, 0.016, bronze, Vector3(0.36, 0.62, -0.2), Vector3(0.36, 0.62, 0.0) + Vector3(0, 0.001, 0), 8)
	# borde rasgado del estandarte
	for k in 4:
		M.cyl(parent, 0.0, 0.028, 0.05, M.mat(Color(0.2, 0.36, 0.16)), Vector3(0.09 + k * 0.053, 0.47, 0.345), Vector3(180, 0, 0), 4)
	# setas brillantes en la base
	for p in [Vector3(-0.3, 0.1, 0.38), Vector3(-0.22, 0.1, 0.41), Vector3(0.38, 0.1, -0.3)]:
		M.cyl(parent, 0.012, 0.015, 0.05, M.mat(Color(0.9, 0.9, 0.8)), p + Vector3(0, -0.02, 0), Vector3.ZERO, 6)
		M.sphere(parent, 0.03, M.mat(POISON_GLOW, 1.8), p + Vector3(0, 0.01, 0), Vector3(1, 0.55, 1), 8)
	# cuerdas en las estacas
	for p in [Vector3(0.42, 0, 0.4), Vector3(0.45, 0, 0.26)]:
		for y in [0.1, 0.16]:
			M.cyl(parent, 0.032, 0.032, 0.025, M.mat(Color(0.82, 0.7, 0.5)), p + Vector3(0, y, 0), Vector3.ZERO, 8)


# Cuello de tela, correa del carcaj con hebilla dorada y bolsita
func _cat_extras(c: Node3D) -> void:
	var poison := variant == "poison"
	var scarf := TorusMesh.new()
	scarf.inner_radius = 0.085
	scarf.outer_radius = 0.125
	M.add(c, scarf, _trim_mat(), Vector3(0, 0.335, 0), Vector3(8, 0, 0))
	var strap := M.box(c, Vector3(0.03, 0.3, 0.02), M.mat(Color(0.4, 0.26, 0.14)), Vector3(0.0, 0.2, -0.128), Vector3(0, 0, 38))
	strap.rotation_degrees = Vector3(-12, 0, 38)
	M.box(c, Vector3(0.04, 0.035, 0.02), M.metal(IRON if tier == 0 else GOLD), Vector3(0.015, 0.2, -0.14))
	M.box(c, Vector3(0.065, 0.055, 0.045), M.mat(LEATHER_LIGHT if poison else Color(0.55, 0.36, 0.2)), Vector3(-0.1, 0.11, -0.1))
	M.sphere(c, 0.01, M.metal(GOLD), Vector3(-0.1, 0.125, -0.125), Vector3.ONE, 6)
	if poison:
		# frasquitos de veneno en el cinturón
		M.cyl(c, 0.016, 0.016, 0.05, M.mat(POISON_GLOW, 1.5), Vector3(0.1, 0.11, -0.11), Vector3.ZERO, 6)


# Máscara de gas: cubre la cara con gafas verdes brillantes, filtro frontal y correas
func _gas_mask(c: Node3D) -> void:
	var h := Vector3(0, 0.46, 0)
	var rubber := M.mat(Color(0.2, 0.23, 0.2))
	var metal := M.metal(Color(0.45, 0.5, 0.4))
	var bronze := M.metal(GOLD if tier == 3 else Color(0.72, 0.5, 0.25))
	var lens := M.mat(POISON_GLOW.darkened(0.2), 2.2 if tier == 3 else 1.3)
	M.sphere(c, 0.1, rubber, h + Vector3(0, -0.02, -0.12), Vector3(1.4, 0.9, 0.68), 16)
	for s in [-1.0, 1.0]:
		M.cyl(c, 0.044, 0.044, 0.03, bronze, h + Vector3(0.058 * s, 0.025, -0.178), Vector3(90, 0, 0), 14)
		M.cyl(c, 0.034, 0.034, 0.034, lens, h + Vector3(0.058 * s, 0.025, -0.18), Vector3(90, 0, 0), 14)
		M.sphere(c, 0.008, M.mat(Color.WHITE, 1.0), h + Vector3(0.058 * s - 0.012, 0.038, -0.198), Vector3.ONE, 6)
		# filtros laterales pequeños
		var side := Node3D.new()
		side.position = h + Vector3(0.105 * s, -0.06, -0.14)
		side.rotation = Vector3(0, -0.6 * s, PI / 2.0)
		c.add_child(side)
		M.cyl(side, 0.022, 0.022, 0.04, metal, Vector3.ZERO, Vector3.ZERO, 10)
	# filtro frontal con agujeros
	M.cyl(c, 0.04, 0.046, 0.07, metal, h + Vector3(0, -0.07, -0.2), Vector3(90, 0, 0), 14)
	M.cyl(c, 0.048, 0.048, 0.015, bronze, h + Vector3(0, -0.07, -0.238), Vector3(90, 0, 0), 14)
	for p in [Vector2(0, 0), Vector2(-0.018, -0.012), Vector2(0.018, -0.012), Vector2(0, 0.02)]:
		M.sphere(c, 0.007, M.mat(Color(0.08, 0.08, 0.08)), h + Vector3(p.x, -0.07 + p.y, -0.247), Vector3.ONE, 6)
	# correas alrededor de la cabeza
	var strap := TorusMesh.new()
	strap.inner_radius = 0.155
	strap.outer_radius = 0.172
	M.add(c, strap, rubber, h + Vector3(0, 0.02, 0.0), Vector3(-10, 0, 0))

# =====================================================================
# --- Etapas visuales (0 = madera humilde, 2 = gran torre, 3 = Maestría) ---
# =====================================================================

# Adornos animados de la etapa (no se hornean: llamas, banderolas, aura, cristal)
func _build_tier_fx() -> void:
	var py := cat_pivot.position.y
	if variant == "poison":
		match tier:
			0:
				_flames.append(flame_node(self, Vector3(-0.1, 0.03, 0.1), 0.7))
			1:
				pass
			2:
				for sx: float in [-1.0, 1.0]:
					_flames.append(flame_node(self, Vector3(0.21 * sx, 0.5, 0.35 + 0.075), 1.0, TOXIC))
				var pn := pennant_node(self, Vector3(-0.33, py + 0.93, -0.33), Color(0.2, 0.4, 0.16), BONE, 0.3, 0.5)
				_pennants.append(pn)
			3:
				for sx: float in [-1.0, 1.0]:
					_flames.append(flame_node(self, Vector3(0.21 * sx, 0.5, 0.34 + 0.075), 1.1, TOXIC))
					_pennants.append(pennant_node(self, Vector3(0.33 * sx, py + 1.0, -0.33), Color(0.14, 0.34, 0.12), GOLD, 0.32, 0.4 if sx < 0.0 else 2.7))
				var crystal := Node3D.new()
				crystal.position = Vector3(0, py + 0.66, -0.3)
				crystal.set_meta("base", crystal.position)
				add_child(crystal)
				var cg := M.mat(TOXIC, 1.6)
				M.cyl(crystal, 0.0, 0.085, 0.16, cg, Vector3(0, 0.08, 0), Vector3.ZERO, 6)
				M.cyl(crystal, 0.0, 0.085, 0.12, cg, Vector3(0, -0.06, 0), Vector3(180, 0, 0), 6)
				var ring := TorusMesh.new()
				ring.inner_radius = 0.11
				ring.outer_radius = 0.13
				M.add(crystal, ring, M.metal(GOLD), Vector3.ZERO, Vector3(75, 0, 0))
				_floaters.append(crystal)
				_spinners.append(aura_ring(self, 0.47, POISON_GLOW, 0.12))
				add_child(sparkles(POISON_GLOW, Vector3(0, 0.5, 0), Vector3(0.42, 0.45, 0.42), 16, 0.012))
		return
	match tier:
		0:
			_pennants.append(pennant_node(self, Vector3(-0.27, py + 0.88, -0.27), Color(0.32, 0.5, 0.22), STRAW, 0.22, 0.4))
		2:
			for sx: float in [-1.0, 1.0]:
				_flames.append(flame_node(self, Vector3(0.21 * sx, 0.5, 0.36 + 0.075)))
			_pennants.append(pennant_node(self, Vector3(-0.33, py + 0.93, -0.33), RED, GOLD, 0.32, 0.5))
		3:
			for sx: float in [-1.0, 1.0]:
				_flames.append(flame_node(self, Vector3(0.21 * sx, 0.5, 0.34 + 0.075), 1.1, Color(1.0, 0.82, 0.4)))
				_pennants.append(pennant_node(self, Vector3(0.33 * sx, py + 1.0, -0.33), ROYAL, GOLD, 0.34, 0.4 if sx < 0.0 else 2.7))
			_spinners.append(aura_ring(self, 0.47, Color(1.0, 0.85, 0.4), 0.12))
			add_child(sparkles(Color(1.0, 0.88, 0.5), Vector3(0, 0.7, 0), Vector3(0.45, 0.6, 0.45), 18, 0.012))


# --- Arquero: etapa 0, atalaya de madera ---

static func _leg(sx: float, sz: float, y: float, py: float) -> Vector3:
	var r := lerpf(0.34, 0.27, (y - 0.03) / (py + 0.23))
	return Vector3(r * sx, y, r * sz)


# Atalaya de troncos: patas con aspas, plataforma de tablones, barandilla y escalera (lado +X)
static func _watchtower(p: Node3D, py: float, bark: Material, log_dark: Material, plank_a: Material, plank_b: Material, rope: Material) -> void:
	var stone := M.mat(Color(0.58, 0.56, 0.52))
	var corners := [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]
	for c: Vector2 in corners:
		M.sphere(p, 0.075, stone, Vector3(0.34 * c.x, 0.03, 0.34 * c.y), Vector3(1.2, 0.6, 1.2), 8)
		var top := _leg(c.x, c.y, py + 0.26, py)
		M.segment(p, 0.046, bark, _leg(c.x, c.y, 0.03, py), top, 8)
		M.cyl(p, 0.0, 0.046, 0.07, log_dark, top + Vector3(0, 0.035, 0), Vector3.ZERO, 8)
		M.cyl(p, 0.05, 0.05, 0.03, rope, _leg(c.x, c.y, py + 0.1, py), Vector3.ZERO, 8)
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var y0 := 0.1
		var y1 := py - 0.1
		M.segment(p, 0.022, log_dark, _leg(a.x, a.y, y0, py), _leg(b.x, b.y, y1, py), 6)
		M.segment(p, 0.022, log_dark, _leg(b.x, b.y, y0, py), _leg(a.x, a.y, y1, py), 6)
		M.segment(p, 0.028, bark, _leg(a.x, a.y, 0.42, py), _leg(b.x, b.y, 0.42, py), 6)
		var mid := (_leg(a.x, a.y, (y0 + y1) * 0.5, py) + _leg(b.x, b.y, (y0 + y1) * 0.5, py)) * 0.5
		M.sphere(p, 0.032, rope, mid, Vector3.ONE, 8)
		# barandilla de troncos
		for y: float in [py + 0.1, py + 0.21]:
			M.segment(p, 0.019, bark, _leg(a.x, a.y, y, py), _leg(b.x, b.y, y, py), 6)
	# vigas y tablones de la plataforma
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.82, 0.05, 0.06), log_dark, Vector3(0, py - 0.07, 0.27 * s))
	for k in 8:
		var z := -0.35 + k * 0.1
		M.box(p, Vector3(0.78 + (k % 3) * 0.03, 0.04, 0.092), plank_a if k % 2 == 0 else plank_b,
				Vector3((k % 2) * 0.015 - 0.007, py - 0.02, z), Vector3(0, (k % 3 - 1) * 2.0, 0))
	# escalera
	for sz: float in [-1.0, 1.0]:
		M.segment(p, 0.018, bark, Vector3(0.48, 0.0, 0.1 * sz), Vector3(0.41, py + 0.08, 0.1 * sz), 6)
	for k in 6:
		var f := (k + 0.6) / 6.5
		M.box(p, Vector3(0.025, 0.022, 0.22), log_dark, Vector3(lerpf(0.48, 0.41, f), f * (py + 0.08), 0))


# Tejadillo de una sola agua sobre la mitad trasera (deja ver al tirador desde la cámara)
static func _lean_to(p: Node3D, py: float, post: Material, brace: Material, cover_a: Material, cover_b: Material, ties: Material) -> Node3D:
	for sx: float in [-1.0, 1.0]:
		M.segment(p, 0.034, post, Vector3(0.27 * sx, py + 0.2, -0.27), Vector3(0.27 * sx, py + 0.66, -0.27), 8)
		M.segment(p, 0.02, brace, Vector3(0.27 * sx, py + 0.42, -0.27), Vector3(0.31 * sx, py + 0.71, -0.07), 6)
	var roof := Node3D.new()
	roof.position = Vector3(0, py + 0.69, -0.24)
	roof.rotation_degrees.x = 18.0
	p.add_child(roof)
	M.box(roof, Vector3(0.86, 0.07, 0.46), cover_a, Vector3.ZERO)
	M.box(roof, Vector3(0.78, 0.05, 0.38), cover_b, Vector3(0, 0.05, -0.02))
	M.cyl(roof, 0.042, 0.042, 0.9, cover_a, Vector3(0, 0.03, 0.22), Vector3(0, 0, 90), 8)
	for k in 9:
		M.cyl(roof, 0.0, 0.03, 0.08, cover_b, Vector3(-0.4 + k * 0.1, -0.05, -0.22), Vector3(180, 0, 0), 4)
	for x: float in [-0.26, 0.0, 0.26]:
		M.box(roof, Vector3(0.016, 0.09, 0.47), ties, Vector3(x, 0.01, 0))
	return roof


func _archer_t0(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[0]
	var bark := M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36))
	var log_dark := M.mat(Color(0.4, 0.26, 0.15))
	var plank_a := M.tex_mat("wood", 2.0, Color(0.92, 0.78, 0.58))
	var plank_b := M.tex_mat("wood", 2.0, Color(0.8, 0.64, 0.46))
	var rope := M.mat(Color(0.82, 0.7, 0.5))
	var straw := M.mat(STRAW)
	var straw_d := M.mat(STRAW.darkened(0.22))
	var red := M.mat(RED)
	var cream := M.mat(CREAM)
	# suelo de tierra apisonada
	M.cyl(p, 0.45, 0.47, 0.03, M.mat(Color(0.52, 0.4, 0.27)), Vector3(0, 0.015, 0), Vector3.ZERO, 16)
	_watchtower(p, py, bark, log_dark, plank_a, plank_b, rope)
	_lean_to(p, py, bark, log_dark, straw, straw_d, rope)
	# asta con un trapo verde (la banderola ondea aparte)
	M.segment(p, 0.014, log_dark, Vector3(-0.27, py + 0.6, -0.27), Vector3(-0.27, py + 0.9, -0.27), 6)
	# diana de paja sobre trípode
	var tgt := Node3D.new()
	tgt.position = Vector3(-0.4, 0.22, 0.12)
	tgt.rotation_degrees = Vector3(-12, 55, 0)
	p.add_child(tgt)
	M.cyl(tgt, 0.1, 0.1, 0.05, straw, Vector3.ZERO, Vector3(90, 0, 0), 16)
	M.cyl(tgt, 0.075, 0.075, 0.054, cream, Vector3.ZERO, Vector3(90, 0, 0), 16)
	M.cyl(tgt, 0.05, 0.05, 0.058, red, Vector3.ZERO, Vector3(90, 0, 0), 14)
	M.cyl(tgt, 0.022, 0.022, 0.062, M.mat(Color(1.0, 0.85, 0.3)), Vector3.ZERO, Vector3(90, 0, 0), 10)
	M.segment(tgt, 0.007, M.mat(BOW_WOOD), Vector3(0.03, 0.02, 0.02), Vector3(0.06, 0.05, 0.16), 4)
	M.box(tgt, Vector3(0.04, 0.004, 0.04), cream, Vector3(0.06, 0.05, 0.15))
	for leg: Vector3 in [Vector3(-0.46, 0, 0.04), Vector3(-0.34, 0, 0.06), Vector3(-0.42, 0, 0.2)]:
		M.segment(p, 0.012, log_dark, leg, Vector3(-0.4, 0.2, 0.1), 4)
	# bala de paja y barril de flechas bajo la plataforma
	M.box(p, Vector3(0.26, 0.15, 0.17), straw, Vector3(0.06, 0.075, -0.08), Vector3(0, 10, 0))
	for x: float in [-0.04, 0.12]:
		M.box(p, Vector3(0.015, 0.155, 0.18), rope, Vector3(0.06 + x * cos(0.17), 0.075, -0.08 - x * sin(0.17)), Vector3(0, 10, 0))
	M.cyl(p, 0.065, 0.06, 0.16, plank_b, Vector3(-0.13, 0.08, 0.08), Vector3.ZERO, 12)
	for y: float in [0.03, 0.13]:
		M.cyl(p, 0.068, 0.068, 0.015, log_dark, Vector3(-0.13, y, 0.08), Vector3.ZERO, 12)
	for k in 4:
		var a := TAU * k / 4.0
		M.segment(p, 0.007, M.mat(BOW_WOOD), Vector3(-0.13 + cos(a) * 0.025, 0.12, 0.08 + sin(a) * 0.025), Vector3(-0.13 + cos(a) * 0.04, 0.27, 0.08 + sin(a) * 0.04), 4)
		M.box(p, Vector3(0.02, 0.035, 0.004), red if k % 2 == 0 else cream, Vector3(-0.13 + cos(a) * 0.04, 0.27, 0.08 + sin(a) * 0.04))


# --- Torre de piedra genérica (etapas 2 y 3) ---

# Torre cuadrada de sillares con zócalo, cornisa sobre ménsulas (matacanes), parapeto y almenas.
# La plataforma (suelo del adarve) queda a la altura `py`.
static func _stone_keep(p: Node3D, py: float, half: float, wall: Material, stones: Array, dark: Material, cap: Material, moss: Material = null, skip: Array = [[0, 1]]) -> void:
	var black := M.mat(Color(0.08, 0.07, 0.07))
	M.box(p, Vector3(2.0 * half + 0.18, 0.1, 2.0 * half + 0.18), dark, Vector3(0, 0.05, 0))
	M.box(p, Vector3(2.0 * half + 0.08, 0.08, 2.0 * half + 0.08), stones[1], Vector3(0, 0.13, 0))
	var h := py - 0.24
	M.box(p, Vector3(2.0 * half, h, 2.0 * half), wall, Vector3(0, 0.1 + h * 0.5, 0))
	_stone_blocks(p, half, 0.26, int((py - 0.5) / 0.15), skip, stones, moss)
	M.box(p, Vector3(2.0 * half + 0.04, 0.035, 2.0 * half + 0.04), stones[2], Vector3(0, py * 0.52, 0))
	# ménsulas, matacanes y suelo del adarve
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, face.x)
		for k in 5:
			var o := -half + 0.04 + k * (2.0 * half - 0.08) / 4.0
			M.box(p, Vector3(0.05, 0.1, 0.05), stones[k % 3], face * (half + 0.03) + tg * o + Vector3(0, py - 0.16, 0))
			if k < 4:
				M.box(p, Vector3(0.04, 0.03, 0.04) + tg.abs() * 0.04, black, face * (half + 0.05) + tg * (o + (half - 0.04) / 4.0) + Vector3(0, py - 0.085, 0))
	M.box(p, Vector3(2.0 * half + 0.16, 0.08, 2.0 * half + 0.16), stones[2], Vector3(0, py - 0.04, 0))
	parapet(p, half + 0.05, py + 0.045, 0.09, 0.06, wall)
	merlons(p, half + 0.05, py + 0.15, Vector3(0.11, 0.12, 0.11), 3, wall, cap)


# Puerta de madera con arco y herrajes en la cara +Z
static func _door(p: Node3D, z: float, frame: Material, wood: Material, iron: Material) -> void:
	M.cyl(p, 0.12, 0.12, 0.03, frame, Vector3(0, 0.3, z), Vector3(90, 0, 0), 14)
	M.box(p, Vector3(0.24, 0.17, 0.03), frame, Vector3(0, 0.215, z))
	M.cyl(p, 0.095, 0.095, 0.03, wood, Vector3(0, 0.3, z + 0.008), Vector3(90, 0, 0), 14)
	M.box(p, Vector3(0.19, 0.17, 0.03), wood, Vector3(0, 0.215, z + 0.008))
	for y: float in [0.2, 0.3]:
		M.box(p, Vector3(0.18, 0.018, 0.01), iron, Vector3(0, y, z + 0.026))
	M.sphere(p, 0.014, iron, Vector3(0.05, 0.25, z + 0.03), Vector3.ONE, 6)


static func _slits(p: Node3D, half: float, ys: Array, m: Material, front := false) -> void:
	for y: float in ys:
		for face: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1)]:
			M.box(p, Vector3(0.025, 0.13, 0.03) if absf(face.z) > 0.5 else Vector3(0.03, 0.13, 0.025), m, face * (half + 0.004) + Vector3(0, y, 0))
		if front:
			M.box(p, Vector3(0.025, 0.13, 0.03), m, Vector3(0.22, y, half + 0.004))
			M.box(p, Vector3(0.025, 0.13, 0.03), m, Vector3(-0.22, y, half + 0.004))


func _archer_t2(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[2]
	var half := 0.36
	var wall := M.tex_mat("bricks", 2.2, Color(0.88, 0.86, 0.82))
	var stones := [M.mat(Color(0.62, 0.6, 0.56)), M.mat(Color(0.53, 0.51, 0.48)), M.mat(Color(0.7, 0.68, 0.64))]
	var dark := M.mat(STONE_DARK)
	var slate := M.tex_mat("roof", 3.0, Color(0.5, 0.56, 0.72))
	var gold := M.metal(GOLD)
	var red := M.mat(RED)
	var iron := M.metal(IRON)
	var black := M.mat(Color(0.08, 0.07, 0.07))
	_stone_keep(p, py, half, wall, stones, dark, stones[2])
	_door(p, half + 0.004, stones[2], M.mat(WOOD_DARK), iron)
	M.box(p, Vector3(0.36, 0.05, 0.1), stones[1], Vector3(0, 0.025, 0.47))
	_slits(p, half, [0.5, 0.95], black)
	# torreón de esquina con tejado cónico de pizarra
	var top := turret(p, Vector3(-0.33, 0, -0.33), 0.13, py - 0.28, py + 0.32, wall, slate, 0.4, stones[2], gold)
	M.cyl(p, 0.008, 0.008, 0.2, iron, top + Vector3(0, 0.1, 0), Vector3.ZERO, 4)
	# estandarte rojo con cruz dorada y escudos en los costados
	hang_banner(p, Vector3(0, py - 0.25, half + 0.014), 0.0, 0.22, 0.46, red, gold, gold, 0)
	for sx: float in [-1.0, 1.0]:
		heater(p, Vector3((half + 0.012) * sx, py * 0.72, 0.1), PI * 0.5 * sx, 1.3, red, M.mat(CREAM), iron)
		wall_torch(p, Vector3(0.21 * sx, 0.45, half), Vector3(0, 0, 1), iron)
	# haz de flechas y barril junto al muro
	M.cyl(p, 0.06, 0.055, 0.15, M.tex_mat("wood", 2.0), Vector3(0.43, 0.075, -0.2), Vector3.ZERO, 12)
	for k in 3:
		M.segment(p, 0.007, M.mat(BOW_WOOD), Vector3(0.43, 0.1, -0.2 + (k - 1) * 0.02), Vector3(0.43 + (k - 1) * 0.02, 0.28, -0.2), 4)
	_archer_shields_rack(p, Vector3(0.44, 0.0, 0.18))


func _archer_shields_rack(p: Node3D, pos: Vector3) -> void:
	var wd := M.mat(WOOD_DARK)
	M.box(p, Vector3(0.04, 0.2, 0.04), wd, pos + Vector3(0, 0.1, -0.08))
	M.box(p, Vector3(0.04, 0.2, 0.04), wd, pos + Vector3(0, 0.1, 0.08))
	M.box(p, Vector3(0.03, 0.03, 0.2), wd, pos + Vector3(0, 0.18, 0))
	for k in 3:
		M.segment(p, 0.006, M.mat(BOW_WOOD), pos + Vector3(-0.02, 0.0, -0.06 + k * 0.06), pos + Vector3(0.0, 0.26, -0.06 + k * 0.06), 4)


func _archer_t3(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[3]
	var half := 0.35
	var wall := M.tex_mat("bricks", 2.2, MARBLE)
	var stones := [M.mat(Color(0.93, 0.91, 0.86)), M.mat(Color(0.86, 0.84, 0.8)), M.mat(Color(1.0, 0.98, 0.94))]
	var dark := M.mat(Color(0.74, 0.72, 0.68))
	var gold := M.metal(GOLD)
	var royal := M.mat(ROYAL)
	var slate := M.tex_mat("roof", 3.0, Color(0.42, 0.55, 0.95))
	var glow := M.mat(Color(1.0, 0.85, 0.5), 1.6)
	_stone_keep(p, py, half, wall, stones, dark, gold)
	# bandas doradas
	for y: float in [0.18, py * 0.33]:
		M.box(p, Vector3(2.0 * half + 0.03, 0.025, 2.0 * half + 0.03), gold, Vector3(0, y, 0))
	M.box(p, Vector3(2.0 * half + 0.18, 0.025, 2.0 * half + 0.18), gold, Vector3(0, py - 0.085, 0))
	_door(p, half + 0.004, gold, M.mat(Color(0.3, 0.2, 0.35)), gold)
	M.box(p, Vector3(0.38, 0.05, 0.1), stones[2], Vector3(0, 0.025, 0.47))
	_slits(p, half, [0.55, 1.05], glow)
	# torreones traseros altos y garitas delanteras, con tejados azules y remates dorados
	for sx: float in [-1.0, 1.0]:
		var top := turret(p, Vector3(0.33 * sx, 0, -0.33), 0.13, py - 0.3, py + 0.3, wall, slate, 0.46, gold, gold)
		M.cyl(p, 0.008, 0.008, 0.24, gold, top + Vector3(0, 0.12, 0), Vector3.ZERO, 4)
		turret(p, Vector3(0.34 * sx, 0, 0.34), 0.085, py - 0.12, py + 0.12, wall, slate, 0.2, gold, gold)
	# gran estandarte azul con sol dorado y escudos dorados en los costados
	hang_banner(p, Vector3(0, py - 0.24, half + 0.014), 0.0, 0.24, 0.6, royal, gold, gold, 2)
	for sx: float in [-1.0, 1.0]:
		heater(p, Vector3((half + 0.012) * sx, py * 0.72, 0.1), PI * 0.5 * sx, 1.4, royal, gold, gold)
		wall_torch(p, Vector3(0.21 * sx, 0.45, half - 0.01), Vector3(0, 0, 1), gold)
	# estatuas guardianas (pedestal y orbe) a los lados de la entrada
	for sx: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.1, 0.16, 0.1), stones[2], Vector3(0.43 * sx, 0.08, -0.05))
		M.box(p, Vector3(0.12, 0.025, 0.12), gold, Vector3(0.43 * sx, 0.17, -0.05))
		M.sphere(p, 0.04, M.mat(Color(0.6, 0.85, 1.0), 1.4), Vector3(0.43 * sx, 0.22, -0.05), Vector3.ONE, 12)


# --- Venenoso: etapa 0, choza de cazador sobre pilotes ---

func _poison_t0(p: Node3D) -> void:
	var py: float = POISON_PLAT_BY_TIER[0]
	var bark := M.tex_mat("wood", 2.5, Color(0.55, 0.45, 0.34))
	var log_dark := M.mat(Color(0.3, 0.2, 0.12))
	var plank_a := M.tex_mat("wood", 2.0, Color(0.74, 0.66, 0.5))
	var plank_b := M.tex_mat("wood", 2.0, Color(0.62, 0.55, 0.42))
	var rope := M.mat(Color(0.7, 0.62, 0.44))
	var hide := M.mat(Color(0.5, 0.36, 0.22))
	var hide_d := M.mat(Color(0.38, 0.27, 0.17))
	var leaf := M.mat(Color(0.3, 0.55, 0.2))
	var bone := M.mat(BONE)
	var glow := M.mat(POISON_GLOW, 2.2)
	var iron := M.metal(Color(0.22, 0.22, 0.24))
	M.cyl(p, 0.45, 0.47, 0.03, M.mat(Color(0.36, 0.34, 0.22)), Vector3(0, 0.015, 0), Vector3.ZERO, 16)
	_watchtower(p, py, bark, log_dark, plank_a, plank_b, rope)
	var roof := _lean_to(p, py, bark, log_dark, hide, hide_d, rope)
	# remiendos y costuras en las pieles
	M.box(roof, Vector3(0.16, 0.012, 0.14), M.mat(Color(0.6, 0.48, 0.3)), Vector3(0.18, 0.08, 0.02), Vector3(0, 12, 0))
	M.box(roof, Vector3(0.12, 0.012, 0.12), M.mat(Color(0.3, 0.42, 0.2)), Vector3(-0.2, 0.08, -0.06), Vector3(0, -8, 0))
	# enredaderas trepando por las patas delanteras
	for sx: float in [-1.0, 1.0]:
		for k in 7:
			var y := 0.08 + k * 0.11
			var lp := _leg(sx, 1.0, y, py) + Vector3(cos(k * 2.1) * 0.045, 0, sin(k * 2.1) * 0.045)
			M.sphere(p, 0.04, leaf, lp, Vector3(1.2, 0.7, 0.9), 8)
			if k % 3 == 0:
				M.sphere(p, 0.014, M.mat(Color.WHITE), lp + Vector3(0.02, 0.03, 0.02), Vector3.ONE, 6)
	# caldero de veneno burbujeante sobre piedras y brasas
	var cp := Vector3(-0.1, 0.0, 0.1)
	for k in 6:
		var a := TAU * k / 6.0
		M.sphere(p, 0.035, M.mat(Color(0.5, 0.48, 0.45)), cp + Vector3(cos(a) * 0.12, 0.025, sin(a) * 0.12), Vector3(1, 0.7, 1), 6)
	M.sphere(p, 0.1, iron, cp + Vector3(0, 0.13, 0), Vector3(1, 0.85, 1), 14)
	M.cyl(p, 0.085, 0.085, 0.02, glow, cp + Vector3(0, 0.19, 0), Vector3.ZERO, 14)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.08
	rim.outer_radius = 0.1
	M.add(p, rim, iron, cp + Vector3(0, 0.195, 0))
	for b: Vector3 in [Vector3(0.03, 0.21, 0.02), Vector3(-0.03, 0.215, -0.02), Vector3(0.0, 0.22, 0.04)]:
		M.sphere(p, 0.018, glow, cp + b, Vector3.ONE, 6)
	for s: float in [-1.0, 1.0]:
		M.segment(p, 0.012, iron, cp + Vector3(0.09 * s, 0.03, 0), cp + Vector3(0.09 * s, 0.14, 0), 4)
	# calavera en una estaca y frascos
	M.segment(p, 0.016, log_dark, Vector3(0.43, 0.0, 0.3), Vector3(0.43, 0.3, 0.3), 6)
	M.sphere(p, 0.05, bone, Vector3(0.43, 0.33, 0.3), Vector3(1, 0.95, 1.05), 10)
	for s: float in [-1.0, 1.0]:
		M.sphere(p, 0.012, M.mat(Color(0.1, 0.1, 0.08)), Vector3(0.43 + 0.018 * s, 0.335, 0.345), Vector3.ONE, 6)
	for k in 3:
		M.cyl(p, 0.02 + k * 0.004, 0.024 + k * 0.004, 0.07, M.mat(POISON_GLOW.darkened(0.15), 1.4), Vector3(0.15 + k * 0.06, py + 0.035, -0.3), Vector3.ZERO, 8)
	# farol verde colgando del tejadillo
	M.segment(p, 0.006, iron, Vector3(-0.33, py + 0.5, 0.0), Vector3(-0.33, py + 0.7, -0.08), 4)
	M.box(p, Vector3(0.08, 0.1, 0.08), iron, Vector3(-0.33, py + 0.45, 0.0))
	M.box(p, Vector3(0.06, 0.08, 0.09), M.mat(POISON_GLOW.darkened(0.2), 1.2), Vector3(-0.33, py + 0.45, 0.0))
	M.cyl(p, 0.0, 0.06, 0.04, iron, Vector3(-0.33, py + 0.52, 0.0), Vector3.ZERO, 4)
	# setas brillantes al pie
	for sp: Vector3 in [Vector3(-0.3, 0.0, -0.36), Vector3(0.2, 0.0, -0.4), Vector3(0.36, 0.0, -0.1)]:
		M.cyl(p, 0.01, 0.013, 0.05, M.mat(Color(0.9, 0.9, 0.8)), sp + Vector3(0, 0.025, 0), Vector3.ZERO, 6)
		M.sphere(p, 0.028, M.mat(POISON_GLOW, 1.8), sp + Vector3(0, 0.055, 0), Vector3(1, 0.55, 1), 8)


# --- Venenoso: etapa 2, torre de piedra musgosa con alambiques ---

func _poison_tanks(p: Node3D, half: float, glass: Material, bronze: Material, big: bool) -> void:
	# alambique esférico en el lado +X y depósito alto en el -X, con tuberías de cobre
	var tp := Vector3(half + 0.05, 0.42, 0.08)
	var r := 0.085 if not big else 0.095
	M.box(p, Vector3(0.1, 0.03, 0.14), bronze, Vector3(half + 0.03, tp.y - r - 0.01, tp.z))
	M.sphere(p, r, glass, tp, Vector3.ONE, 16)
	var band := TorusMesh.new()
	band.inner_radius = r - 0.005
	band.outer_radius = r + 0.012
	M.add(p, band, bronze, tp)
	M.cyl(p, 0.025, 0.03, 0.09, glass, tp + Vector3(0, r + 0.03, 0), Vector3.ZERO, 8)
	M.segment(p, 0.015, bronze, tp + Vector3(0, r + 0.07, 0), Vector3(half + 0.05, 0.95, 0.08), 6)
	M.sphere(p, 0.022, bronze, Vector3(half + 0.05, 0.95, 0.08), Vector3.ONE, 8)
	M.segment(p, 0.015, bronze, Vector3(half + 0.05, 0.95, 0.08), Vector3(half + 0.01, 0.95, 0.08), 6)
	var cp := Vector3(-half - 0.05, 0.3, 0.12)
	M.cyl(p, 0.06, 0.06, 0.3, glass, cp, Vector3.ZERO, 12)
	for y: float in [-0.15, 0.0, 0.15]:
		M.cyl(p, 0.066, 0.066, 0.02, bronze, cp + Vector3(0, y, 0), Vector3.ZERO, 12)
	M.cyl(p, 0.0, 0.066, 0.06, bronze, cp + Vector3(0, 0.19, 0), Vector3.ZERO, 12)
	M.segment(p, 0.014, bronze, cp + Vector3(0, 0.21, 0), Vector3(-half - 0.05, 0.75, 0.12), 6)
	M.segment(p, 0.014, bronze, Vector3(-half - 0.05, 0.75, 0.12), Vector3(-half, 0.75, 0.12), 6)


func _poison_t2(p: Node3D) -> void:
	var py: float = POISON_PLAT_BY_TIER[2]
	var half := 0.35
	var wall := M.tex_mat("bricks", 2.2, Color(0.72, 0.78, 0.68))
	var stones := [M.mat(Color(0.5, 0.54, 0.48)), M.mat(Color(0.42, 0.46, 0.4)), M.mat(Color(0.58, 0.62, 0.55))]
	var moss := M.mat(Color(0.36, 0.56, 0.2))
	var dark := M.mat(Color(0.3, 0.32, 0.28))
	var verd := M.tex_mat("roof", 3.0, VERDIGRIS)
	var bronze := M.metal(Color(0.72, 0.5, 0.25))
	var glass := M.mat(POISON_GLOW.darkened(0.15), 1.4)
	var banner := M.mat(Color(0.2, 0.36, 0.16))
	var bone := M.mat(BONE)
	var iron := M.metal(IRON)
	var glow_slit := M.mat(POISON_GLOW.darkened(0.3), 1.2)
	_stone_keep(p, py, half, wall, stones, dark, stones[2], moss)
	_door(p, half + 0.004, stones[2], M.mat(Color(0.25, 0.18, 0.1)), iron)
	M.box(p, Vector3(0.36, 0.05, 0.1), stones[1], Vector3(0, 0.025, 0.47))
	_slits(p, half, [0.95], glow_slit)
	var top := turret(p, Vector3(-0.33, 0, -0.33), 0.13, py - 0.28, py + 0.3, wall, verd, 0.42, bronze, bronze)
	M.cyl(p, 0.008, 0.008, 0.2, iron, top + Vector3(0, 0.1, 0), Vector3.ZERO, 4)
	hang_banner(p, Vector3(0, py - 0.25, half + 0.014), 0.0, 0.22, 0.46, banner, bronze, bone, 1)
	_poison_tanks(p, half, glass, bronze, false)
	for sx: float in [-1.0, 1.0]:
		wall_torch(p, Vector3(0.21 * sx, 0.45, half), Vector3(0, 0, 1), iron)
		# colmillos en las almenas delanteras
		var tusk := Node3D.new()
		tusk.position = Vector3(0.42 * sx, py + 0.18, 0.42)
		tusk.rotation = Vector3(0.7, 0, -0.7 * sx)
		p.add_child(tusk)
		M.cyl(tusk, 0.0, 0.03, 0.16, bone, Vector3(0, 0.08, 0), Vector3.ZERO, 8)
	# enredaderas por las esquinas delanteras
	for sx: float in [-1.0, 1.0]:
		var y := py - 0.2
		var k := 0
		while y > 0.2:
			M.sphere(p, 0.045, M.mat(Color(0.3, 0.55, 0.2)), Vector3((half + 0.01) * sx + sin(k * 1.7) * 0.02, y, half - 0.02), Vector3(1.1, 0.8, 0.6), 8)
			y -= 0.085
			k += 1
	for sp: Vector3 in [Vector3(-0.42, 0.0, -0.3), Vector3(0.36, 0.0, -0.42), Vector3(-0.2, 0.0, 0.42)]:
		M.cyl(p, 0.01, 0.013, 0.05, M.mat(Color(0.9, 0.9, 0.8)), sp + Vector3(0, 0.025, 0), Vector3.ZERO, 6)
		M.sphere(p, 0.03, M.mat(POISON_GLOW, 1.8), sp + Vector3(0, 0.055, 0), Vector3(1, 0.55, 1), 8)


# --- Venenoso: etapa 3 (Maestría), ciudadela de obsidiana y oro con cristal flotante ---

func _poison_t3(p: Node3D) -> void:
	var py: float = POISON_PLAT_BY_TIER[3]
	var half := 0.35
	var wall := M.tex_mat("bricks", 2.2, Color(0.46, 0.54, 0.46))
	var stones := [M.mat(Color(0.3, 0.36, 0.3)), M.mat(Color(0.24, 0.29, 0.24)), M.mat(Color(0.36, 0.42, 0.36))]
	var dark := M.mat(Color(0.18, 0.2, 0.17))
	var gold := M.metal(GOLD)
	var verd := M.tex_mat("roof", 3.0, VERDIGRIS.lightened(0.1))
	var glass := M.mat(POISON_GLOW, 1.9)
	var glow := M.mat(POISON_GLOW, 1.8)
	var banner := M.mat(Color(0.12, 0.26, 0.11))
	var iron := M.metal(IRON)
	_stone_keep(p, py, half, wall, stones, dark, gold)
	for y: float in [0.18, py * 0.33]:
		M.box(p, Vector3(2.0 * half + 0.03, 0.025, 2.0 * half + 0.03), gold, Vector3(0, y, 0))
	M.box(p, Vector3(2.0 * half + 0.18, 0.025, 2.0 * half + 0.18), gold, Vector3(0, py - 0.085, 0))
	_door(p, half + 0.004, gold, M.mat(Color(0.12, 0.2, 0.1)), gold)
	M.box(p, Vector3(0.38, 0.05, 0.1), stones[2], Vector3(0, 0.025, 0.47))
	_slits(p, half, [0.55, 1.05], glow)
	for sx: float in [-1.0, 1.0]:
		var top := turret(p, Vector3(0.33 * sx, 0, -0.33), 0.13, py - 0.3, py + 0.3, wall, verd, 0.46, gold, gold)
		M.cyl(p, 0.008, 0.008, 0.24, gold, top + Vector3(0, 0.12, 0), Vector3.ZERO, 4)
		turret(p, Vector3(0.34 * sx, 0, 0.34), 0.085, py - 0.12, py + 0.12, wall, verd, 0.2, gold, gold)
		wall_torch(p, Vector3(0.21 * sx, 0.45, half - 0.01), Vector3(0, 0, 1), gold)
		# brazos dorados que sostienen el cristal flotante
		M.segment(p, 0.014, gold, Vector3(0.24 * sx, py + 0.2, -0.33), Vector3(0.1 * sx, py + 0.56, -0.3), 6)
		M.sphere(p, 0.022, glow, Vector3(0.1 * sx, py + 0.57, -0.3), Vector3.ONE, 8)
	hang_banner(p, Vector3(0, py - 0.24, half + 0.014), 0.0, 0.24, 0.6, banner, gold, gold, 1)
	_poison_tanks(p, half, glass, gold, true)
	for sp: Vector3 in [Vector3(-0.42, 0.0, -0.3), Vector3(0.38, 0.0, -0.42), Vector3(-0.2, 0.0, 0.42), Vector3(0.42, 0.0, 0.25)]:
		M.cyl(p, 0.01, 0.013, 0.05, M.mat(Color(0.9, 0.9, 0.8)), sp + Vector3(0, 0.025, 0), Vector3.ZERO, 6)
		M.sphere(p, 0.03, glow, sp + Vector3(0, 0.055, 0), Vector3(1, 0.55, 1), 8)


# Pañuelo verde sobre la boca (venenoso, etapa 0)
func _cloth_mask(c: Node3D) -> void:
	var h := Vector3(0, 0.46, 0)
	var cloth := M.mat(Color(0.3, 0.45, 0.2))
	M.sphere(c, 0.1, cloth, h + Vector3(0, -0.06, -0.09), Vector3(1.3, 0.75, 0.75), 12)
	M.cyl(c, 0.0, 0.04, 0.08, cloth, h + Vector3(0, -0.12, -0.14), Vector3(180, 0, 0), 4)


# =====================================================================
# --- Piezas compartidas para las etapas (también las usan otros modelos) ---
# =====================================================================

## Muro bajo del parapeto alrededor de un cuadrado de semilado `half`
static func parapet(p: Node3D, half: float, y: float, h: float, th: float, m: Material) -> void:
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(2.0 * half + th, h, th), m, Vector3(0, y, half * s))
		M.box(p, Vector3(th, h, 2.0 * half + th), m, Vector3(half * s, y, 0))


## Almenas en el borde de un cuadrado (n por lado, contando esquinas) con albardilla opcional
static func merlons(p: Node3D, half: float, y: float, size: Vector3, n: int, m: Material, cap: Material = null) -> void:
	for i in n:
		for j in n:
			if i != 0 and i != n - 1 and j != 0 and j != n - 1:
				continue
			var pos := Vector3(-half + 2.0 * half * i / (n - 1), y, -half + 2.0 * half * j / (n - 1))
			M.box(p, size, m, pos)
			if cap != null:
				M.box(p, Vector3(size.x + 0.02, 0.025, size.z + 0.02), cap, pos + Vector3(0, size.y * 0.5 + 0.01, 0))


## Torreón cilíndrico sobre ménsula con tejado cónico; devuelve la punta del tejado
static func turret(p: Node3D, base: Vector3, r: float, y0: float, y1: float, wall: Material, roof: Material, roof_h: float, trim: Material, finial_m: Material) -> Vector3:
	M.cyl(p, r, r * 0.3, 0.16, wall, base + Vector3(0, y0 - 0.08, 0), Vector3.ZERO, 12)
	M.cyl(p, r, r, y1 - y0, wall, base + Vector3(0, (y0 + y1) * 0.5, 0), Vector3.ZERO, 14)
	M.cyl(p, r + 0.015, r + 0.015, 0.03, trim, base + Vector3(0, y1, 0), Vector3.ZERO, 14)
	var d := Vector3(base.x, 0, base.z).normalized()
	var win := M.box(p, Vector3(0.03, 0.09, 0.03), M.mat(Color(0.08, 0.07, 0.07)), base + d * (r - 0.005) + Vector3(0, (y0 + y1) * 0.5 + 0.04, 0))
	win.rotation.y = atan2(d.x, d.z)
	M.cyl(p, 0.0, r + 0.045, roof_h, roof, base + Vector3(0, y1 + 0.015 + roof_h * 0.5, 0), Vector3.ZERO, 14)
	var tip := base + Vector3(0, y1 + 0.015 + roof_h, 0)
	M.sphere(p, 0.022, finial_m, tip, Vector3.ONE, 8)
	M.cyl(p, 0.0, 0.014, 0.06, finial_m, tip + Vector3(0, 0.045, 0), Vector3.ZERO, 6)
	return tip


## Estandarte colgante con borde y cola de golondrina, mirando a +Z del nodo.
## kind: 0 = cruz, 1 = serpiente, 2 = sol, 3 = liso
static func hang_banner(p: Node3D, pos: Vector3, yaw: float, w: float, h: float, field: Material, trim: Material, emblem: Material, kind := 0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	p.add_child(n)
	M.box(n, Vector3(w + 0.08, 0.022, 0.022), trim, Vector3(0, 0, 0.012))
	for k: float in [-1.0, 1.0]:
		M.sphere(n, 0.018, trim, Vector3((w * 0.5 + 0.04) * k, 0, 0.012), Vector3.ONE, 8)
	M.box(n, Vector3(w + 0.02, h, 0.012), trim, Vector3(0, -h * 0.5, 0))
	M.box(n, Vector3(w - 0.02, h - 0.03, 0.018), field, Vector3(0, -h * 0.5 + 0.005, 0.003))
	for k: float in [-1.0, 1.0]:
		M.cyl(n, 0.0, w * 0.3, h * 0.22, field, Vector3(w * 0.27 * k, -h - h * 0.08, 0.003), Vector3(180, 45, 0), 4)
	var c := Vector3(0, -h * 0.42, 0.014)
	match kind:
		0:
			M.box(n, Vector3(w * 0.17, h * 0.5, 0.012), emblem, c)
			M.box(n, Vector3(w * 0.6, w * 0.17, 0.012), emblem, c + Vector3(0, h * 0.08, 0))
		1:
			var pts := [Vector3(-0.04, -0.12, 0), Vector3(0.04, -0.06, 0), Vector3(-0.04, 0.0, 0), Vector3(0.04, 0.06, 0), Vector3(0.0, 0.11, 0)]
			for i in pts.size() - 1:
				var a: Vector3 = pts[i]
				var b: Vector3 = pts[i + 1]
				M.segment(n, 0.014 * w / 0.22, emblem, c + a * (h / 0.46), c + b * (h / 0.46), 6)
			M.sphere(n, 0.024 * w / 0.22, emblem, c + Vector3(0.0, 0.12, 0) * (h / 0.46), Vector3(1.2, 0.9, 0.6), 8)
		2:
			M.sphere(n, w * 0.17, emblem, c, Vector3(1, 1, 0.3), 12)
			for k in 8:
				var ray := M.box(n, Vector3(0.012, w * 0.14, 0.01), emblem, c + Vector3(cos(TAU * k / 8.0), sin(TAU * k / 8.0), 0) * w * 0.26)
				ray.rotation.z = TAU * k / 8.0 - PI * 0.5


## Escudo de lágrima mirando a +Z del nodo (girado `yaw`), con una banda
static func heater(p: Node3D, pos: Vector3, yaw: float, s: float, field: Material, charge: Material, rim: Material) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	p.add_child(n)
	M.box(n, Vector3(0.15, 0.1, 0.02) * s, rim, Vector3(0, 0.03, -0.004) * s)
	M.box(n, Vector3(0.11, 0.11, 0.02) * s, rim, Vector3(0, -0.035, -0.004) * s, Vector3(0, 0, 45))
	M.box(n, Vector3(0.13, 0.085, 0.02) * s, field, Vector3(0, 0.03, 0.0) * s)
	M.box(n, Vector3(0.093, 0.093, 0.02) * s, field, Vector3(0, -0.033, 0.0) * s, Vector3(0, 0, 45))
	M.box(n, Vector3(0.035, 0.15, 0.024) * s, charge, Vector3(0, 0.0, 0.004) * s)


## Soporte de antorcha de pared (estático); la llama va en flame_node(pos + n*0.075 + (0,0.05,0))
static func wall_torch(p: Node3D, pos: Vector3, n: Vector3, iron: Material) -> void:
	M.box(p, Vector3(0.025, 0.025, 0.08) if absf(n.z) > 0.5 else Vector3(0.08, 0.025, 0.025), iron, pos + n * 0.04)
	M.cyl(p, 0.035, 0.02, 0.05, iron, pos + n * 0.075 + Vector3(0, 0.02, 0), Vector3.ZERO, 8)
	M.cyl(p, 0.014, 0.014, 0.08, M.mat(WOOD_DARK), pos + n * 0.075 - Vector3(0, 0.03, 0), Vector3.ZERO, 6)


## Llama animable (nodo independiente)
static func flame_node(parent: Node3D, pos: Vector3, s := 1.0, col := Color(1.0, 0.6, 0.15)) -> Node3D:
	var f := Node3D.new()
	f.position = pos
	parent.add_child(f)
	M.sphere(f, 0.04 * s, M.mat(col, 2.2), Vector3(0, 0.025 * s, 0), Vector3(1, 1.3, 1), 8)
	M.cyl(f, 0.0, 0.032 * s, 0.1 * s, M.mat(col.lightened(0.35), 2.5), Vector3(0, 0.08 * s, 0), Vector3.ZERO, 6)
	return f


## Banderola de dos tramos (el último hijo es la cola, que ondea por separado)
static func pennant_node(parent: Node3D, pos: Vector3, col: Color, trim: Color, length := 0.3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	n.set_meta("yaw", yaw)
	parent.add_child(n)
	var cm := M.mat(col)
	M.box(n, Vector3(length * 0.5, 0.1, 0.012), cm, Vector3(length * 0.25, -0.05, 0))
	M.box(n, Vector3(length * 0.5, 0.018, 0.016), M.mat(trim), Vector3(length * 0.25, -0.006, 0))
	var tail := Node3D.new()
	tail.position = Vector3(length * 0.5, 0, 0)
	n.add_child(tail)
	M.box(tail, Vector3(length * 0.42, 0.075, 0.012), cm, Vector3(length * 0.2, -0.045, 0))
	M.cyl(tail, 0.0, 0.04, 0.08, cm, Vector3(length * 0.43, -0.045, 0), Vector3(0, 0, -90), 4)
	return n


## Anillo mágico que gira a ras de suelo con runas brillantes
static func aura_ring(parent: Node3D, r: float, col: Color, y := 0.05) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(0, y, 0)
	parent.add_child(n)
	var ring := TorusMesh.new()
	ring.inner_radius = r - 0.018
	ring.outer_radius = r
	ring.rings = 32
	M.add(n, ring, M.mat(col, 1.4), Vector3.ZERO)
	for k in 8:
		var a := TAU * k / 8.0
		var rune := M.box(n, Vector3(0.05, 0.012, 0.025), M.mat(col, 2.0), Vector3(cos(a), 0, sin(a)) * (r - 0.01))
		rune.rotation.y = -a
	return n


## Destellos que suben (aura de Maestría)
static func sparkles(col: Color, pos: Vector3, ext: Vector3, amount := 16, size := 0.012) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.8
	p.position = pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0, 0.15, 0)
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = M.mat(col, 2.5)
	p.mesh = mesh
	return p
