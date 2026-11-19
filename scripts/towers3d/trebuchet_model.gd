extends Node3D
## Modelo 3D de la torre "Trebuchet" (id cannon): fundíbulo de madera sobre una plataforma baja
## de sillares con almenas en las esquinas, escudo heráldico, estandarte y antorcha.
## El fundíbulo (bastidor, brazo con honda y contrapeso) gira entero sobre cat_pivot y apunta a -Z.
## Lo maneja un ingeniero humano con gorro de cuero que da vueltas al torno.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const Arch := preload("res://scripts/towers3d/archer_model.gd")

const STONE_DARK := Color(0.42, 0.41, 0.39)
const WOOD_DARK := Color(0.33, 0.21, 0.12)
const IRON := Color(0.27, 0.27, 0.3)
const ROPE := Color(0.82, 0.72, 0.52)
const LEATHER := Color(0.45, 0.28, 0.15)
const LEATHER_DARK := Color(0.3, 0.18, 0.1)
const TUNIC := Color(0.55, 0.42, 0.25)
const RED := Color(0.72, 0.14, 0.12)
const GOLD := Color(0.95, 0.75, 0.3)
const CREAM := Color(0.95, 0.9, 0.78)
const FLAME := Color(1.0, 0.6, 0.15)

const PLATFORM_Y := 0.26
# Por etapa: altura de la plataforma, eje del brazo, brazo largo, brazo corto y honda
# (etapa 0 = mangonel de madera con cuchara; 1 = fundíbulo original; 2-3 = gran fundíbulo sobre bastión)
const PLAT_BY_TIER := [0.03, 0.26, 0.44, 0.56]
const AXLE_BY_TIER := [Vector3(0, 0.42, -0.02), Vector3(0, 0.62, -0.02), Vector3(0, 0.68, -0.02), Vector3(0, 0.72, -0.02)]
const LONG_BY_TIER := [0.4, 0.5, 0.54, 0.58]
const SHORT_BY_TIER := [0.1, 0.17, 0.18, 0.19]
const SLING_BY_TIER := [0.0, 0.2, 0.21, 0.22]
const MARBLE := Color(0.97, 0.95, 0.9)
const EMBER := Color(1.0, 0.55, 0.15)
# Eje del brazo (coordenadas del pivote) y longitudes del brazo
const AXLE := Vector3(0, 0.62, -0.02)
const LONG := 0.5
const SHORT := 0.17
const SLING := 0.2
# Ángulos del brazo (giro en X): + inclina la punta larga hacia atrás (+Z)
const A_REST := 0.3
const A_COCK := 1.85
const A_FIRE := -0.8
# Torno y operador
const DRUM := Vector3(0, 0.13, 0.12)
const CRANK_X := 0.14
const CRANK_R := 0.07
const OP_POS := Vector3(0.31, 0, 0.1)
const OP_YAW := 0.9

var cat_pivot: Node3D
var _arm: Node3D
var _weight: Node3D
var _sling: Node3D
var _stone: Node3D
var _crank: Node3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _hand_l: MeshInstance3D
var _hand_r: MeshInstance3D
var _operator: Node3D
var _banner: Node3D
var _flame: Node3D
var tier := 0
var _axle := AXLE
var _long := LONG
var _short := SHORT
var _sling_len := SLING
var _flames: Array[Node3D] = []
var _pennants: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _floaters: Array[Node3D] = []


func _init(level := 0) -> void:
	tier = Arch.tier_of(level)
	_axle = AXLE_BY_TIER[tier]
	_long = LONG_BY_TIER[tier]
	_short = SHORT_BY_TIER[tier]
	_sling_len = SLING_BY_TIER[tier]
	M.add_baked(self, M.baked("trebuchet_tower_t%d" % tier, _build_tower))
	if tier == 1:
		_build_banner()
		_build_flame()
	_build_tier_fx()
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, PLAT_BY_TIER[tier], 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("trebuchet_frame_t%d" % tier, _build_frame))
	_operator = Node3D.new()
	_operator.position = OP_POS
	_operator.rotation.y = OP_YAW
	cat_pivot.add_child(_operator)
	M.add_baked(_operator, M.baked("trebuchet_engineer_t%d" % tier, _build_engineer))
	_build_moving_parts()
	animate({"t": 0.0, "charge": 0.0, "fire": 0.0, "has_target": false})


## s = {t, charge (0..1), fire (1 -> 0), has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = s.get("charge", 0.0)
	var fire: float = s.get("fire", 0.0)
	# Brazo: la carga lo baja hacia atrás (sube el contrapeso); el disparo lo lanza hacia delante
	var a := lerpf(A_REST, A_COCK, charge)
	if fire > 0.0:
		a = lerpf(a, A_FIRE, clampf(fire * 1.4, 0.0, 1.0))
	_arm.rotation.x = a
	# El contrapeso cuelga siempre vertical (con un pequeño balanceo)
	_weight.rotation.x = -a + sin(t * 4.0) * 0.04 * (1.0 - charge)
	# La honda cuelga; al disparar sale despedida siguiendo el brazo
	var hang := -a + sin(t * 3.0) * 0.08
	_sling.rotation.x = lerpf(hang, PI * 0.85, clampf(fire, 0.0, 1.0))
	_stone.visible = fire <= 0.05 and charge > 0.1
	# Torno: gira mientras se carga
	_crank.rotation.x = -charge * TAU * 1.5
	_update_hands(t)
	_operator.position.y = OP_POS.y + absf(sin(t * 2.0)) * 0.006
	# Estandarte, llamas, banderolas y aura de la etapa
	if _banner != null:
		_banner.rotation.y = sin(t * 1.7) * 0.18
		_banner.rotation.x = sin(t * 2.3 + 1.0) * 0.06
	if _flame != null:
		var fl := 0.85 + 0.15 * sin(t * 23.0) + 0.08 * sin(t * 41.0)
		_flame.scale = Vector3(1.0, fl, 1.0)
	Arch.animate_fx(t, _flames, _pennants, _spinners, _floaters)


## Punto de salida del proyectil: la bolsa de la honda en el momento de soltar.
func muzzle_global() -> Vector3:
	var dir := Vector3(0, cos(A_FIRE), sin(A_FIRE))
	var local := _axle + dir * (_long + _sling_len * 0.8)
	return cat_pivot.to_global(local)


# Manos del ingeniero sobre las manivelas del torno
func _update_hands(_t: float) -> void:
	var ang := _crank.rotation.x
	var handle := DRUM + Vector3(0, -sin(ang) * CRANK_R, cos(ang) * CRANK_R)
	var hr := handle + Vector3(CRANK_X + 0.075, 0, 0)
	var hl := handle + Vector3(CRANK_X + 0.025, 0.0, 0)
	var op_xf := _operator.transform
	_hand_r.position = hr
	_hand_l.position = hl
	M.orient_segment(_arm_r, op_xf * Human.R_SHOULDER, hr)
	M.orient_segment(_arm_l, op_xf * Human.L_SHOULDER, hl)


# --- Heráldica ---

# Escudo de lágrima (heater) mirando a +Z del nodo `n`, con un cheurón
static func heater_shield(n: Node3D, s: float, field: Material, charge_m: Material, rim: Material) -> void:
	M.box(n, Vector3(0.15, 0.1, 0.02) * s, rim, Vector3(0, 0.03, -0.004) * s)
	M.box(n, Vector3(0.11, 0.11, 0.02) * s, rim, Vector3(0, -0.035, -0.004) * s, Vector3(0, 0, 45))
	M.box(n, Vector3(0.13, 0.085, 0.02) * s, field, Vector3(0, 0.03, 0.0))
	M.box(n, Vector3(0.093, 0.093, 0.02) * s, field, Vector3(0, -0.033, 0.0) * s, Vector3(0, 0, 45))
	for k: float in [-1.0, 1.0]:
		M.box(n, Vector3(0.085, 0.022, 0.02) * s, charge_m, Vector3(0.028 * k, 0.0, 0.006) * s, Vector3(0, 0, 38.0 * k))


# --- Torre (base estática) ---

func _build_tower(p: Node3D) -> void:
	match tier:
		0: _tower_t0(p)
		2: _tower_t2(p)
		3: _tower_t3(p)
		_: _tower_t1(p)


# Etapa 1: plataforma baja de sillares (diseño original)
func _tower_t1(p: Node3D) -> void:
	var bricks := M.tex_mat("bricks", 2.2, Color(0.82, 0.8, 0.75))
	var dark := M.mat(STONE_DARK)
	var stones: Array[Material] = [M.mat(Color(0.6, 0.58, 0.54)), M.mat(Color(0.52, 0.5, 0.47)), M.mat(Color(0.66, 0.64, 0.6))]
	var flag := M.mat(Color(0.56, 0.54, 0.5))
	var wood_dark := M.mat(WOOD_DARK)
	var iron := M.metal(IRON)
	var red := M.mat(RED)
	var gold := M.metal(GOLD)
	var cream := M.mat(CREAM)

	# Zócalo y plataforma de sillares
	M.box(p, Vector3(0.9, 0.06, 0.9), dark, Vector3(0, 0.03, 0))
	M.box(p, Vector3(0.84, 0.18, 0.84), bricks, Vector3(0, 0.15, 0))
	M.box(p, Vector3(0.88, 0.04, 0.88), stones[1], Vector3(0, 0.25, 0))
	# Losas del suelo
	for ix in 3:
		for iz in 3:
			var lp := Vector3(-0.26 + ix * 0.26, 0.272, -0.26 + iz * 0.26)
			M.box(p, Vector3(0.24, 0.012, 0.24), flag if (ix + iz) % 2 == 0 else stones[0], lp)
	# Sillares salientes en las caras
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, face.x)
		for k in 4:
			var off := -0.3 + k * 0.2
			if absf(face.z) > 0.5 and k == 1 or absf(face.z) > 0.5 and k == 2:
				continue
			var size := Vector3(0.16, 0.07, 0.03) if absf(face.z) > 0.5 else Vector3(0.03, 0.07, 0.16)
			var row_y := 0.11 if k % 2 == 0 else 0.19
			M.box(p, size, stones[k % 3], face * 0.425 + tg * off + Vector3(0, row_y, 0))

	# Almenas en dos esquinas (las otras llevan estandarte y antorcha)
	for c: Vector3 in [Vector3(-0.37, 0, -0.37), Vector3(0.37, 0, 0.37)]:
		M.box(p, Vector3(0.15, 0.16, 0.15), bricks, c + Vector3(0, 0.35, 0))
		M.box(p, Vector3(0.17, 0.03, 0.17), stones[2], c + Vector3(0, 0.44, 0))

	# Escudos heráldicos en la cara delantera y trasera
	for sz: float in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(0, 0.16, 0.432 * sz)
		sh.rotation.y = 0.0 if sz > 0.0 else PI
		p.add_child(sh)
		heater_shield(sh, 1.0, red, M.mat(GOLD), iron)

	# Asta del estandarte (esquina +X -Z)
	var pole := Vector3(0.37, 0.28, -0.37)
	M.box(p, Vector3(0.14, 0.06, 0.14), stones[0], pole + Vector3(0, 0.03, 0))
	M.cyl(p, 0.018, 0.022, 0.9, wood_dark, pole + Vector3(0, 0.45, 0), Vector3.ZERO, 8)
	M.sphere(p, 0.03, gold, pole + Vector3(0, 0.92, 0), Vector3.ONE, 8)

	# Antorcha de hierro (esquina -X +Z)
	var tp := Vector3(-0.37, 0.28, 0.37)
	M.box(p, Vector3(0.12, 0.05, 0.12), stones[2], tp + Vector3(0, 0.025, 0))
	M.cyl(p, 0.02, 0.025, 0.36, wood_dark, tp + Vector3(0, 0.2, 0), Vector3.ZERO, 8)
	M.cyl(p, 0.05, 0.03, 0.07, iron, tp + Vector3(0, 0.4, 0), Vector3.ZERO, 8)
	for k in 4:
		var a := TAU * k / 4.0
		M.box(p, Vector3(0.012, 0.08, 0.012), iron, tp + Vector3(cos(a) * 0.045, 0.44, sin(a) * 0.045))

	# Montón de proyectiles de piedra y barril
	for b: Vector3 in [Vector3(-0.3, 0.315, -0.08), Vector3(-0.36, 0.315, 0.0), Vector3(-0.3, 0.315, 0.06), Vector3(-0.33, 0.37, -0.01)]:
		M.sphere(p, 0.045, stones[2], b, Vector3.ONE, 10)
	M.cyl(p, 0.05, 0.05, 0.04, wood_dark, Vector3(-0.33, 0.29, -0.01), Vector3.ZERO, 10)

	# Escalones y hierba
	M.box(p, Vector3(0.32, 0.06, 0.1), stones[1], Vector3(0, 0.03, 0.49))
	var grass := M.mat(Color(0.32, 0.6, 0.2))
	for gp: Vector3 in [Vector3(-0.46, 0, -0.1), Vector3(0.46, 0, 0.15), Vector3(-0.2, 0, -0.46), Vector3(0.25, 0, 0.47), Vector3(0.46, 0, -0.3)]:
		for b in 3:
			var ga := TAU * b / 3.0
			var blade := Node3D.new()
			blade.position = gp + Vector3(cos(ga), 0, sin(ga)) * 0.02
			blade.rotation = Vector3(sin(ga) * 0.4, 0, -cos(ga) * 0.4)
			p.add_child(blade)
			M.cyl(blade, 0.0, 0.016, 0.09, grass, Vector3(0, 0.045, 0), Vector3.ZERO, 4)
	M.sphere(p, 0.018, cream, Vector3(-0.44, 0.05, -0.07), Vector3.ONE, 6)


# Estandarte rojo con cruz dorada (animado, colgando del asta)
func _build_banner() -> void:
	_banner = Node3D.new()
	_banner.position = Vector3(0.37, 1.12, -0.37)
	add_child(_banner)
	var red := M.mat(RED)
	var gold := M.mat(GOLD)
	M.cyl(_banner, 0.012, 0.012, 0.26, M.mat(WOOD_DARK), Vector3(0, 0, 0.13), Vector3(90, 0, 0), 6)
	M.box(_banner, Vector3(0.016, 0.3, 0.22), red, Vector3(0, -0.15, 0.13))
	M.box(_banner, Vector3(0.022, 0.24, 0.04), gold, Vector3(0, -0.14, 0.13))
	M.box(_banner, Vector3(0.022, 0.04, 0.17), gold, Vector3(0, -0.1, 0.13))
	for k in 3:
		M.cyl(_banner, 0.0, 0.04, 0.06, red, Vector3(0, -0.32, 0.055 + k * 0.075), Vector3(180, 0, 0), 4)


func _build_flame() -> void:
	_flame = Node3D.new()
	_flame.position = Vector3(-0.37, 0.72, 0.37)
	add_child(_flame)
	M.sphere(_flame, 0.05, M.mat(FLAME, 2.2), Vector3(0, 0.03, 0), Vector3(1, 1.3, 1), 8)
	M.cyl(_flame, 0.0, 0.04, 0.12, M.mat(Color(1.0, 0.85, 0.35), 2.5), Vector3(0, 0.1, 0), Vector3.ZERO, 6)


# --- Fundíbulo (gira con el pivote) ---

func _build_frame(c: Node3D) -> void:
	if tier == 0:
		_frame_t0(c)
		return
	var wood := M.tex_mat("wood", 2.2, Color(0.78, 0.62, 0.5))
	var wood_dark := M.mat(WOOD_DARK)
	var iron := M.metal(GOLD) if tier == 3 else M.metal(IRON)
	var rope := M.mat(ROPE)

	# Trineo: largueros y travesaños
	for sx: float in [-1.0, 1.0]:
		M.box(c, Vector3(0.06, 0.06, 0.72), wood, Vector3(0.14 * sx, 0.04, 0.0))
		M.box(c, Vector3(0.07, 0.03, 0.07), iron, Vector3(0.14 * sx, 0.04, -0.37))
	for z: float in [-0.3, 0.3]:
		M.box(c, Vector3(0.34, 0.05, 0.06), wood_dark, Vector3(0, 0.05, z))
	# Caballetes en A hasta el eje
	for sx: float in [-1.0, 1.0]:
		var top := Vector3(0.14 * sx, _axle.y, _axle.z)
		M.segment(c, 0.034, wood, Vector3(0.14 * sx, 0.06, -0.3), top, 6)
		M.segment(c, 0.034, wood, Vector3(0.14 * sx, 0.06, 0.28), top, 6)
		M.segment(c, 0.02, wood_dark, Vector3(0.14 * sx, 0.06, 0.0), top + Vector3(0, -0.02, 0), 6)
		M.box(c, Vector3(0.05, 0.03, 0.42), wood_dark, Vector3(0.14 * sx, 0.3, -0.01))
		M.box(c, Vector3(0.07, 0.08, 0.08), iron, top)
	# Eje de hierro
	M.cyl(c, 0.022, 0.022, 0.36, iron, _axle, Vector3(0, 0, 90), 10)
	# Torno con tambor y cuerda (estático; las manivelas se animan)
	M.cyl(c, 0.045, 0.045, 0.22, wood_dark, DRUM, Vector3(0, 0, 90), 12)
	for k in 3:
		M.cyl(c, 0.049, 0.049, 0.015, rope, DRUM + Vector3(-0.05 + k * 0.05, 0, 0), Vector3(0, 0, 90), 12)
	for sx: float in [-1.0, 1.0]:
		M.box(c, Vector3(0.03, 0.12, 0.05), wood_dark, DRUM + Vector3(0.125 * sx, -0.04, 0))
	# Cuerda del torno hacia el brazo (cuando está cargado)
	M.segment(c, 0.008, rope, DRUM + Vector3(0, 0.04, 0.02), Vector3(0, 0.38, 0.32), 4)
	M.sphere(c, 0.018, iron, Vector3(0, 0.38, 0.32), Vector3.ONE, 6)


# Ingeniero humano: campesino con sombrero de paja (etapa 0), artesano con delantal (1),
# soldado con cota y tabardo (2) o maestro de asedio con armadura dorada y capa (3)
func _build_engineer(c: Node3D) -> void:
	var tunic := M.mat(TUNIC)
	var leather := M.mat(LEATHER)
	var leather_dark := M.mat(LEATHER_DARK)
	var gold := M.metal(GOLD)
	var red := M.mat(RED)
	match tier:
		0:
			Human.body(c, M.mat(Color(0.62, 0.55, 0.4)), M.mat(Color(0.5, 0.42, 0.3)))
		1:
			Human.body(c, tunic, leather_dark)
			M.box(c, Vector3(0.17, 0.2, 0.02), leather, Vector3(0, 0.11, -0.135), Vector3(-6, 0, 0))
		_:
			var body_m: Material = M.metal(Color(0.43, 0.45, 0.49)) if tier == 2 else M.metal(Color(0.8, 0.82, 0.88))
			Human.body(c, body_m, gold if tier == 3 else leather_dark)
			M.box(c, Vector3(0.18, 0.27, 0.02), red, Vector3(0, 0.13, -0.124), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.18, 0.27, 0.02), red, Vector3(0, 0.13, 0.124), Vector3(4, 0, 0))
			# cheurón dorado del escudo de la torre
			for k: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.09, 0.022, 0.012), M.mat(GOLD), Vector3(0.03 * k, 0.17, -0.137), Vector3(-4, 0, 38.0 * k))
			for sx: float in [-1.0, 1.0]:
				M.sphere(c, 0.07, gold if tier == 3 else M.metal(Color(0.47, 0.49, 0.54)), Vector3(0.135 * sx, 0.285, 0), Vector3(1, 0.7, 1), 10)
			if tier == 3:
				M.box(c, Vector3(0.26, 0.3, 0.02), red, Vector3(0, 0.16, 0.145), Vector3(10, 0, 0))
				M.box(c, Vector3(0.27, 0.025, 0.026), gold, Vector3(0, 0.02, 0.17), Vector3(10, 0, 0))
	var belt := TorusMesh.new()
	belt.inner_radius = 0.135
	belt.outer_radius = 0.16
	M.add(c, belt, leather_dark, Vector3(0, 0.1, 0), Vector3.ZERO)
	M.box(c, Vector3(0.02, 0.1, 0.02), M.mat(WOOD_DARK), Vector3(0.15, 0.06, 0.03), Vector3(0, 0, 10))
	M.box(c, Vector3(0.06, 0.03, 0.03), M.metal(IRON), Vector3(0.16, 0.11, 0.03))
	# piernas / botas
	for sx: float in [-1.0, 1.0]:
		M.cyl(c, 0.045, 0.05, 0.05, leather_dark, Vector3(0.06 * sx, 0.01, -0.02), Vector3.ZERO, 8)
	# cabeza con barba y tocado según la etapa
	var h := Human.head(c, true, true, Color(0.45, 0.28, 0.14))
	M.sphere(h, 0.08, M.mat(Color(0.45, 0.28, 0.14)), Vector3(0, -0.09, -0.06), Vector3(1.1, 0.8, 0.8), 10)
	M.box(h, Vector3(0.04, 0.008, 0.01), M.mat(Color(0.6, 0.3, 0.28)), Vector3(0, -0.07, -0.138))
	match tier:
		0:
			# sombrero de paja de ala ancha
			var straw := M.mat(Color(0.88, 0.75, 0.42))
			M.sphere(h, 0.13, straw, Vector3(0, 0.08, 0.02), Vector3(1.0, 0.7, 1.0), 12)
			M.cyl(h, 0.22, 0.24, 0.02, straw, Vector3(0, 0.06, 0.02), Vector3(-5, 0, 0), 16)
			M.cyl(h, 0.135, 0.135, 0.03, M.mat(Color(0.6, 0.2, 0.15)), Vector3(0, 0.085, 0.02), Vector3(-5, 0, 0), 14)
		1:
			M.sphere(h, 0.148, leather, Vector3(0, 0.07, 0.025), Vector3(1.0, 0.72, 1.0), 14)
			var band := TorusMesh.new()
			band.inner_radius = 0.13
			band.outer_radius = 0.155
			M.add(h, band, leather_dark, Vector3(0, 0.055, 0.02), Vector3(-8, 0, 0))
			M.sphere(h, 0.025, leather_dark, Vector3(0, 0.18, 0.02), Vector3.ONE, 8)
		_:
			# yelmo de acero (dorado con penacho en la Maestría)
			var helm: Material = M.metal(Color(0.47, 0.49, 0.54)) if tier == 2 else M.metal(Color(0.85, 0.87, 0.92))
			M.sphere(h, 0.15, helm, Vector3(0, 0.07, 0.02), Vector3(1.0, 0.8, 1.0), 14)
			M.cyl(h, 0.155, 0.17, 0.03, gold if tier == 3 else helm, Vector3(0, 0.03, 0.02), Vector3(-6, 0, 0), 16)
			M.box(h, Vector3(0.02, 0.03, 0.17), gold if tier == 3 else M.metal(IRON), Vector3(0, 0.17, 0.03))
			if tier == 3:
				for k in 3:
					M.sphere(h, 0.035, red if k == 1 else M.mat(Color(0.97, 0.96, 0.94)), Vector3(0, 0.2 + k * 0.012, 0.06 + k * 0.04), Vector3(0.6, 1.0, 1.4), 8)


# Brazo, contrapeso, honda, manivelas y brazos del ingeniero
func _build_moving_parts() -> void:
	var wood := M.tex_mat("wood", 2.2, Color(0.78, 0.62, 0.5))
	var wood_dark := M.mat(WOOD_DARK)
	var iron := M.metal(IRON)
	var rope := M.mat(ROPE)
	var leather := M.mat(LEATHER)

	if tier == 3:
		iron = M.metal(GOLD)
	_arm = Node3D.new()
	_arm.position = _axle
	cat_pivot.add_child(_arm)
	M.box(_arm, Vector3(0.07, _long + _short, 0.07), wood, Vector3(0, (_long - _short) * 0.5, 0))
	for y: float in [-0.1, 0.0, 0.18, 0.36]:
		M.box(_arm, Vector3(0.085, 0.03, 0.085), iron, Vector3(0, y, 0))
	M.cyl(_arm, 0.012, 0.012, 0.04, iron, Vector3(0, _long + 0.01, 0), Vector3.ZERO, 6)

	# Contrapeso: caja de madera con flejes y piedras, colgando de un perno
	_weight = Node3D.new()
	_weight.position = Vector3(0, -_short, 0)
	_arm.add_child(_weight)
	if tier == 0:
		_mangonel_parts(wood_dark, iron, rope, leather)
		_build_crank_and_arms(iron, wood_dark)
		return
	if tier >= 2:
		_weight.scale = Vector3.ONE * (1.12 if tier == 2 else 1.2)
	M.cyl(_weight, 0.018, 0.018, 0.1, iron, Vector3.ZERO, Vector3(0, 0, 90), 8)
	for sx: float in [-1.0, 1.0]:
		M.box(_weight, Vector3(0.014, 0.08, 0.03), iron, Vector3(0.045 * sx, -0.04, 0))
	M.box(_weight, Vector3(0.2, 0.16, 0.2), wood_dark, Vector3(0, -0.15, 0))
	for y: float in [-0.1, -0.18]:
		M.box(_weight, Vector3(0.21, 0.022, 0.21), iron, Vector3(0, y, 0))
	for k in 3:
		M.sphere(_weight, 0.04, M.mat(Color(0.55, 0.53, 0.5)), Vector3(-0.045 + k * 0.045, -0.07, 0.02 * (k - 1)), Vector3(1, 0.7, 1), 8)

	# Honda: dos cuerdas y bolsa de cuero con la piedra
	_sling = Node3D.new()
	_sling.position = Vector3(0, _long, 0)
	_arm.add_child(_sling)
	for sz: float in [-1.0, 1.0]:
		M.segment(_sling, 0.006, rope, Vector3(0, -_sling_len, 0.03 * sz), Vector3(0, 0, 0.004 * sz), 4)
	M.sphere(_sling, 0.045, leather, Vector3(0, -_sling_len, 0), Vector3(1.1, 0.6, 1.1), 10)
	_stone = M.sphere(_sling, 0.042, M.mat(EMBER, 1.8) if tier == 3 else M.mat(Color(0.62, 0.6, 0.56)), Vector3(0, -_sling_len + 0.02, 0), Vector3.ONE, 10)
	_build_crank_and_arms(iron, wood_dark)


# Manivelas del torno y brazos del ingeniero (se reorientan cada fotograma)
func _build_crank_and_arms(iron: Material, wood_dark: Material) -> void:
	# Manivelas del torno
	_crank = Node3D.new()
	_crank.position = DRUM
	cat_pivot.add_child(_crank)
	for sx: float in [-1.0, 1.0]:
		M.box(_crank, Vector3(0.02, 0.025, CRANK_R * 2.0 + 0.03), iron, Vector3(CRANK_X * sx, 0, 0))
	M.cyl(_crank, 0.012, 0.012, 0.1, wood_dark, Vector3(CRANK_X + 0.05, 0, CRANK_R), Vector3(0, 0, 90), 6)
	M.cyl(_crank, 0.012, 0.012, 0.1, wood_dark, Vector3(-CRANK_X - 0.05, 0, -CRANK_R), Vector3(0, 0, 90), 6)
	M.cyl(_crank, 0.015, 0.015, CRANK_X * 2.0, iron, Vector3.ZERO, Vector3(0, 0, 90), 6)

	# Brazos del ingeniero (se reorientan cada fotograma)
	var sleeve: Material = [M.mat(Color(0.62, 0.55, 0.4)), M.mat(TUNIC), M.metal(Color(0.43, 0.45, 0.49)), M.metal(Color(0.8, 0.82, 0.88))][tier]
	var skin := M.mat(Human.SKIN)
	_arm_l = M.add(cat_pivot, M.tube_mesh(0.04, 8), sleeve)
	_arm_r = M.add(cat_pivot, M.tube_mesh(0.04, 8), sleeve)
	_hand_l = M.sphere(cat_pivot, 0.042, skin, Vector3.ZERO, Vector3.ONE, 8)
	_hand_r = M.sphere(cat_pivot, 0.042, skin, Vector3.ZERO, Vector3.ONE, 8)


# =====================================================================
# --- Etapas visuales ---
# =====================================================================

func _build_tier_fx() -> void:
	var py: float = PLAT_BY_TIER[tier]
	match tier:
		0:
			_flames.append(Arch.flame_node(self, Vector3(-0.38, 0.05, 0.22), 0.8))
			_pennants.append(Arch.pennant_node(self, Vector3(0.4, 0.5, -0.3), RED, CREAM, 0.2, 2.6))
		2:
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.22 * sx, py - 0.1, 0.43 + 0.075)))
			_pennants.append(Arch.pennant_node(self, Vector3(-0.38, py + 0.81, -0.38), RED, GOLD, 0.26, 0.5))
		3:
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.22 * sx, py - 0.1, 0.43 + 0.075), 1.1, Color(1.0, 0.75, 0.3)))
				_pennants.append(Arch.pennant_node(self, Vector3(0.38 * sx, py + 0.87, -0.38), RED, GOLD, 0.3, 0.4 if sx < 0.0 else 2.7))
			_spinners.append(Arch.aura_ring(self, 0.47, Color(1.0, 0.65, 0.25), py + 0.02))
			add_child(Arch.sparkles(EMBER, Vector3(0, py + 0.4, 0), Vector3(0.42, 0.4, 0.42), 18, 0.012))


# Etapa 0: campo de tierra con cerca de estacas, piedras, carreta y una hoguera
func _tower_t0(p: Node3D) -> void:
	var bark := M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36))
	var log_dark := M.mat(Color(0.4, 0.26, 0.15))
	var plank := M.tex_mat("wood", 2.0, Color(0.86, 0.72, 0.52))
	var rope := M.mat(ROPE)
	var stone := M.mat(Color(0.6, 0.58, 0.54))
	M.cyl(p, 0.46, 0.48, 0.03, M.mat(Color(0.52, 0.4, 0.27)), Vector3(0, 0.015, 0), Vector3.ZERO, 18)
	# surcos del trineo en la tierra
	M.cyl(p, 0.36, 0.36, 0.004, M.mat(Color(0.45, 0.34, 0.22)), Vector3(0, 0.032, 0), Vector3.ZERO, 18)
	# cerca de estacas (atrás y a los lados; el frente queda libre)
	for k in 9:
		var a := PI * 0.15 + k * PI * 0.2125
		var pos := Vector3(sin(a + PI), 0, cos(a + PI)) * 0.45
		if pos.z > 0.3:
			continue
		M.cyl(p, 0.022, 0.025, 0.2, bark, pos + Vector3(0, 0.1, 0), Vector3.ZERO, 6)
		M.cyl(p, 0.0, 0.022, 0.05, log_dark, pos + Vector3(0, 0.225, 0), Vector3.ZERO, 6)
	for k in 8:
		var a0 := PI * 0.15 + k * PI * 0.2125
		var p0 := Vector3(sin(a0 + PI), 0, cos(a0 + PI)) * 0.45
		var p1 := Vector3(sin(a0 + PI * 1.2125), 0, cos(a0 + PI * 1.2125)) * 0.45
		if p0.z > 0.3 or p1.z > 0.3:
			continue
		M.segment(p, 0.013, log_dark, p0 + Vector3(0, 0.15, 0), p1 + Vector3(0, 0.15, 0), 4)
	# montón de piedras (munición) y cesto
	for b: Vector3 in [Vector3(-0.4, 0.05, -0.12), Vector3(-0.35, 0.05, -0.22), Vector3(-0.42, 0.05, -0.02), Vector3(-0.38, 0.1, -0.13)]:
		M.sphere(p, 0.045, stone, b, Vector3.ONE, 10)
	# hoguera con piedras alrededor
	for k in 6:
		var a := TAU * k / 6.0
		M.sphere(p, 0.025, stone, Vector3(-0.38 + cos(a) * 0.06, 0.04, 0.22 + sin(a) * 0.06), Vector3(1, 0.7, 1), 6)
	for k in 3:
		M.cyl(p, 0.012, 0.012, 0.1, log_dark, Vector3(-0.38, 0.045, 0.22), Vector3(90, k * 60.0, 0), 5)
	# rueda de carreta apoyada y fardo de paja
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.07
	wheel.outer_radius = 0.09
	M.add(p, wheel, plank, Vector3(0.42, 0.1, 0.12), Vector3(0, 0, 80))
	for k in 3:
		M.box(p, Vector3(0.012, 0.16, 0.012), log_dark, Vector3(0.42, 0.1, 0.12), Vector3(k * 60.0, 0, 80))
	M.box(p, Vector3(0.16, 0.1, 0.12), M.mat(Color(0.86, 0.72, 0.38)), Vector3(0.38, 0.05, -0.12), Vector3(0, 25, 0))
	M.box(p, Vector3(0.012, 0.105, 0.125), rope, Vector3(0.38, 0.05, -0.12), Vector3(0, 25, 0))
	# estaca con banderola
	M.cyl(p, 0.012, 0.016, 0.52, log_dark, Vector3(0.4, 0.26, -0.3), Vector3.ZERO, 6)
	Arch._ground_details(p, false)


# Bastión cuadrado con torres redondas en las esquinas; devuelve nada. `roofed` = tejados cónicos traseros
func _bastion(p: Node3D, py: float, wall: Material, stones: Array[Material], dark: Material, cap: Material, roof: Material, finial: Material, front_roofs: bool) -> void:
	M.box(p, Vector3(0.94, 0.06, 0.94), dark, Vector3(0, 0.03, 0))
	M.box(p, Vector3(0.86, py - 0.06, 0.86), wall, Vector3(0, 0.03 + (py - 0.06) * 0.5, 0))
	Arch._stone_blocks(p, 0.43, 0.12, int((py - 0.12) / 0.15) + 1, [[0, 1]], stones)
	M.box(p, Vector3(0.9, 0.04, 0.9), stones[1], Vector3(0, py - 0.02, 0))
	for ix in 3:
		for iz in 3:
			M.box(p, Vector3(0.24, 0.012, 0.24), stones[0] if (ix + iz) % 2 == 0 else stones[2], Vector3(-0.26 + ix * 0.26, py + 0.006, -0.26 + iz * 0.26))
	# parapeto bajo entre las torres
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.62, 0.08, 0.04), wall, Vector3(0, py + 0.04, 0.44 * s))
		M.box(p, Vector3(0.04, 0.08, 0.62), wall, Vector3(0.44 * s, py + 0.04, 0))
		M.box(p, Vector3(0.64, 0.02, 0.06), cap, Vector3(0, py + 0.09, 0.44 * s))
		M.box(p, Vector3(0.06, 0.02, 0.64), cap, Vector3(0.44 * s, py + 0.09, 0))
	# torres de esquina
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(0.38 * sx, 0, 0.38 * sz)
			var roofed := sz < 0.0 or front_roofs
			if roofed:
				Arch.turret(p, c, 0.1, py - 0.1, py + 0.26 if sz < 0.0 else py + 0.14, wall, roof, 0.34 if sz < 0.0 else 0.2, cap, finial)
				M.cyl(p, 0.1, 0.1, py - 0.1, wall, c + Vector3(0, (py - 0.1) * 0.5, 0), Vector3.ZERO, 14)
			else:
				M.cyl(p, 0.1, 0.1, py + 0.12, wall, c + Vector3(0, (py + 0.12) * 0.5, 0), Vector3.ZERO, 14)
				M.cyl(p, 0.115, 0.115, 0.03, cap, c + Vector3(0, py + 0.12, 0), Vector3.ZERO, 14)
				for k in 4:
					var a := TAU * k / 4.0 + PI * 0.25
					M.box(p, Vector3(0.05, 0.07, 0.05), wall, c + Vector3(cos(a) * 0.085, py + 0.17, sin(a) * 0.085))


# Etapa 2: bastión de sillares con torres, escudo heráldico y antorchas
func _tower_t2(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[2]
	var wall := M.tex_mat("bricks", 2.2, Color(0.84, 0.82, 0.77))
	var stones: Array[Material] = [M.mat(Color(0.6, 0.58, 0.54)), M.mat(Color(0.52, 0.5, 0.47)), M.mat(Color(0.66, 0.64, 0.6))]
	var iron := M.metal(IRON)
	var gold := M.metal(GOLD)
	var slate := M.tex_mat("roof", 3.0, Color(0.5, 0.56, 0.72))
	_bastion(p, py, wall, stones, M.mat(STONE_DARK), stones[2], slate, gold, false)
	var top := Vector3(-0.38, py + 0.26 + 0.015 + 0.34, -0.38)
	M.cyl(p, 0.007, 0.007, 0.2, iron, top + Vector3(0, 0.1, 0), Vector3.ZERO, 4)
	var sh := Node3D.new()
	sh.position = Vector3(0, py * 0.5, 0.445)
	p.add_child(sh)
	heater_shield(sh, 1.5, M.mat(RED), M.mat(GOLD), iron)
	for sx: float in [-1.0, 1.0]:
		Arch.wall_torch(p, Vector3(0.22 * sx, py - 0.15, 0.43), Vector3(0, 0, 1), iron)
	# montón de proyectiles
	for b: Vector3 in [Vector3(-0.26, py + 0.05, 0.3), Vector3(-0.18, py + 0.05, 0.33), Vector3(-0.22, py + 0.1, 0.3)]:
		M.sphere(p, 0.045, stones[2], b, Vector3.ONE, 10)
	Arch._ground_details(p, false)


# Etapa 3 (Maestría): bastión de mármol y oro con tejados rojos, proyectil de fuego y brasas
func _tower_t3(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[3]
	var wall := M.tex_mat("bricks", 2.2, MARBLE)
	var stones: Array[Material] = [M.mat(Color(0.93, 0.91, 0.86)), M.mat(Color(0.86, 0.84, 0.8)), M.mat(Color(1.0, 0.98, 0.94))]
	var gold := M.metal(GOLD)
	var roof := M.tex_mat("roof", 3.0, Color(0.95, 0.4, 0.32))
	_bastion(p, py, wall, stones, M.mat(Color(0.74, 0.72, 0.68)), gold, roof, gold, true)
	M.box(p, Vector3(0.88, 0.025, 0.88), gold, Vector3(0, py * 0.4, 0))
	for sx: float in [-1.0, 1.0]:
		var top := Vector3(0.38 * sx, py + 0.26 + 0.015 + 0.34, -0.38)
		M.cyl(p, 0.008, 0.008, 0.26, gold, top + Vector3(0, 0.13, 0), Vector3.ZERO, 4)
		Arch.wall_torch(p, Vector3(0.22 * sx, py - 0.15, 0.43), Vector3(0, 0, 1), gold)
	var sh := Node3D.new()
	sh.position = Vector3(0, py * 0.5, 0.445)
	p.add_child(sh)
	heater_shield(sh, 1.7, M.mat(RED), M.mat(GOLD), gold)
	# brasero de fuego con proyectiles incandescentes
	M.cyl(p, 0.07, 0.05, 0.06, gold, Vector3(-0.22, py + 0.03, 0.3), Vector3.ZERO, 12)
	for b: Vector3 in [Vector3(-0.24, py + 0.08, 0.3), Vector3(-0.19, py + 0.08, 0.31), Vector3(-0.22, py + 0.12, 0.28)]:
		M.sphere(p, 0.035, M.mat(EMBER, 1.8), b, Vector3.ONE, 10)
	Arch._ground_details(p, false)


# Etapa 0: bastidor del mangonel (postes, madeja de torsión, tope acolchado y ruedas)
func _frame_t0(c: Node3D) -> void:
	var wood := M.tex_mat("wood", 2.2, Color(0.78, 0.62, 0.5))
	var wood_dark := M.mat(WOOD_DARK)
	var iron := M.metal(IRON)
	var rope := M.mat(ROPE)
	for sx: float in [-1.0, 1.0]:
		M.box(c, Vector3(0.06, 0.06, 0.62), wood, Vector3(0.14 * sx, 0.06, 0.0))
		var top := Vector3(0.14 * sx, _axle.y, _axle.z)
		M.segment(c, 0.032, wood, Vector3(0.14 * sx, 0.08, _axle.z), top + Vector3(0, 0.04, 0), 6)
		M.segment(c, 0.02, wood_dark, Vector3(0.14 * sx, 0.08, 0.22), top + Vector3(0, -0.06, 0), 6)
		# poste delantero con el tope
		M.segment(c, 0.026, wood, Vector3(0.14 * sx, 0.08, -0.24), Vector3(0.14 * sx, 0.6, -0.2), 6)
		M.box(c, Vector3(0.06, 0.06, 0.06), iron, top)
		# ruedas macizas
		for wz: float in [-0.22, 0.22]:
			M.cyl(c, 0.075, 0.075, 0.035, wood_dark, Vector3(0.19 * sx, 0.075, wz), Vector3(0, 0, 90), 12)
			M.cyl(c, 0.025, 0.025, 0.04, iron, Vector3(0.2 * sx, 0.075, wz), Vector3(0, 0, 90), 8)
	for z: float in [-0.24, 0.24]:
		M.box(c, Vector3(0.34, 0.05, 0.06), wood_dark, Vector3(0, 0.07, z))
	M.box(c, Vector3(0.34, 0.05, 0.06), wood_dark, Vector3(0, 0.6, -0.2))
	M.sphere(c, 0.045, M.mat(LEATHER), Vector3(0, 0.62, -0.19), Vector3(1.3, 0.8, 0.8), 10)
	# madeja de cuerda retorcida alrededor del eje
	M.cyl(c, 0.05, 0.05, 0.22, rope, _axle, Vector3(0, 0, 90), 10)
	for k in 4:
		M.cyl(c, 0.054, 0.054, 0.012, M.mat(ROPE.darkened(0.25)), _axle + Vector3(-0.08 + k * 0.053, 0, 0), Vector3(0, 0, 90), 10)
	M.cyl(c, 0.018, 0.018, 0.34, iron, _axle, Vector3(0, 0, 90), 8)
	# torno
	M.cyl(c, 0.045, 0.045, 0.22, wood_dark, DRUM, Vector3(0, 0, 90), 12)
	for k in 3:
		M.cyl(c, 0.049, 0.049, 0.015, rope, DRUM + Vector3(-0.05 + k * 0.05, 0, 0), Vector3(0, 0, 90), 12)
	for sx: float in [-1.0, 1.0]:
		M.box(c, Vector3(0.03, 0.12, 0.05), wood_dark, DRUM + Vector3(0.125 * sx, -0.04, 0))


# Etapa 0: cuchara de madera en la punta del brazo (se mantiene horizontal y vuelca al disparar)
func _mangonel_parts(wood_dark: Material, iron: Material, rope: Material, leather: Material) -> void:
	_sling = Node3D.new()
	_sling.position = Vector3(0, _long, 0)
	_arm.add_child(_sling)
	M.cyl(_sling, 0.065, 0.04, 0.05, wood_dark, Vector3(0, 0.01, 0), Vector3.ZERO, 12)
	M.cyl(_sling, 0.068, 0.068, 0.012, iron, Vector3(0, 0.03, 0), Vector3.ZERO, 12)
	M.cyl(_sling, 0.05, 0.05, 0.01, leather, Vector3(0, 0.032, 0), Vector3.ZERO, 12)
	M.cyl(_weight, 0.03, 0.03, 0.06, rope, Vector3.ZERO, Vector3(0, 0, 90), 8)
	_stone = M.sphere(_sling, 0.04, M.mat(Color(0.62, 0.6, 0.56)), Vector3(0, 0.06, 0), Vector3.ONE, 10)
