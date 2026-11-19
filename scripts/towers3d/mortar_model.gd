extends Node3D
## Modelo 3D de la "Bombarda Real" (id mortar): bastión redondo y achaparrado sobre el que
## descansa una enorme bombarda de hierro o bronce montada en su cureña, con barriles de
## pólvora y pirámides de bolaños de piedra.
## La maneja un artillero humano con un botafuego (bota con mecha encendida) que acerca al
## oído del cañón y se tapa la oreja al disparar. Al disparar, el cañón retrocede y suelta
## una bocanada de humo. Todo lo que apunta va dentro de cat_pivot, mirando hacia -Z.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const Arch := preload("res://scripts/towers3d/archer_model.gd")

const STONE_DARK := Color(0.4, 0.39, 0.37)
const TIMBER := Color(0.3, 0.19, 0.1)
const IRON := Color(0.27, 0.27, 0.3)
const IRON_DARK := Color(0.17, 0.17, 0.19)
const BRONZE := Color(0.8, 0.53, 0.26)
const BRONZE_DARK := Color(0.55, 0.34, 0.16)
const GOLD := Color(0.95, 0.75, 0.3)
const RED := Color(0.72, 0.14, 0.12)
const YELLOW := Color(0.95, 0.78, 0.25)
const WHITE := Color(0.95, 0.93, 0.88)
const ROPE := Color(0.84, 0.75, 0.56)
const BALL := Color(0.62, 0.6, 0.57)
const POWDER := Color(0.12, 0.11, 0.11)
const SMOKE := Color(0.82, 0.8, 0.78)
const FLASH := Color(1.0, 0.7, 0.25)
const EMBER := Color(1.0, 0.45, 0.1)
const MARBLE := Color(0.97, 0.95, 0.9)
const ROYAL := Color(0.16, 0.26, 0.62)
const ROYAL_LIGHT := Color(0.3, 0.45, 0.9)

# Altura de la plataforma (suelo del bastión) por etapa
const PLAT_BY_TIER := [0.42, 0.56, 0.7, 0.82]
# Radio de la caña de la bombarda por etapa
const GUN_R_BY_TIER := [0.074, 0.08, 0.085, 0.088]
# Bombarda (coordenadas de la cureña): muñones en GUN_POS, la boca hacia -Z.
# La cureña entera (ruedas y pieza) se escala por etapa para que la bombarda imponga.
const CARR_SCALE_BY_TIER := [1.18, 1.24, 1.28, 1.3]
const GUN_POS := Vector3(-0.07, 0.22, -0.02)
const ELEV := 0.36
const MUZZLE_Z := -0.335
const TOUCH := Vector3(0, 0.066, 0.13)
const WHEEL_R := 0.1
const WHEEL_X := 0.145
const WHEEL_Z := -0.02
# Artillero
const MAN_POS := Vector3(0.2, 0, 0.2)
const MAN_YAW := 0.62
const LINSTOCK_LEN := 0.3

var cat_pivot: Node3D
var tier := 0
var _carriage: Node3D
var _gun: Node3D
var _wheels: Array[Node3D] = []
var _man: Node3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _hand_l: MeshInstance3D
var _hand_r: MeshInstance3D
var _linstock: Node3D
var _ember: Node3D
var _smoke: Node3D
var _flash: Node3D
var _puffs: Array[Node3D] = []
var _touch_smoke: Node3D
var _flames: Array[Node3D] = []
var _pennants: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _floaters: Array[Node3D] = []


func _init(level := 0) -> void:
	tier = Arch.tier_of(level)
	M.add_baked(self, M.baked("mortar_tower_t%d" % tier, _build_tower))
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, PLAT_BY_TIER[tier], 0)
	add_child(cat_pivot)
	# Pertrechos que giran con la pieza (bolaños, barril, atacador)
	M.add_baked(cat_pivot, M.baked("mortar_deck_t%d" % tier, _build_deck))
	_carriage = Node3D.new()
	_carriage.scale = Vector3.ONE * float(CARR_SCALE_BY_TIER[tier])
	cat_pivot.add_child(_carriage)
	M.add_baked(_carriage, M.baked("mortar_carriage_t%d" % tier, _build_carriage))
	if tier > 0:
		var wheel_mesh := M.baked("mortar_wheel_t%d" % tier, _build_wheel)
		for sx: float in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(GUN_POS.x + WHEEL_X * sx, WHEEL_R, WHEEL_Z)
			_carriage.add_child(w)
			M.add_baked(w, wheel_mesh)
			_wheels.append(w)
	_gun = Node3D.new()
	_gun.position = GUN_POS
	_carriage.add_child(_gun)
	M.add_baked(_gun, M.baked("mortar_gun_t%d" % tier, _build_gun))
	_man = Node3D.new()
	_man.position = MAN_POS
	_man.rotation.y = MAN_YAW
	cat_pivot.add_child(_man)
	M.add_baked(_man, M.baked("mortar_man_t%d" % tier, _build_man))
	_build_moving_parts()
	_build_smoke()
	_build_tier_fx()
	animate({"t": 0.0, "charge": 0.0, "fire": 0.0, "has_target": false})


## s = {t, charge (0..1), fire (1 -> 0), has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = s.get("charge", 0.0)
	var fire: float = s.get("fire", 0.0)
	var has_target: bool = s.get("has_target", false)
	var c := charge if has_target else minf(charge, 0.3)
	# Retroceso: la cureña rueda hacia atrás y la caña da un respingo
	var back := fire * fire * 0.07
	_carriage.position = Vector3(0, fire * 0.01, back)
	var cs := _carriage.scale.x
	for w in _wheels:
		w.rotation.x = back / (WHEEL_R * cs)
	var aim := ELEV if has_target else ELEV - 0.1
	_gun.position = GUN_POS + Vector3(0, 0, fire * 0.025)
	_gun.rotation.x = aim + fire * 0.16
	# Botafuego: en reposo lo lleva en alto; al cargar lo acerca al oído del cañón
	var reach := smoothstep(0.45, 0.92, c) if has_target else 0.0
	reach *= 1.0 - clampf(fire * 3.0, 0.0, 1.0)
	_man.position = MAN_POS + Vector3(0, absf(sin(t * 1.6)) * 0.005, fire * 0.03)
	_man.rotation = Vector3(-0.14 * reach + fire * 0.14, MAN_YAW, 0)
	var mx := _man.transform
	var sh_l := mx * Human.L_SHOULDER
	var sh_r := mx * Human.R_SHOULDER
	var gun_rest := Transform3D(Basis(Vector3.RIGHT, aim), GUN_POS)
	var touch := _carriage.transform * (gun_rest * TOUCH) + Vector3(0, 0.02, 0)
	var hand_rest := mx * Vector3(-0.16, 0.2, -0.12)
	var dir_rest := Vector3(0.05, 1.0, -0.25).normalized()
	var hand_reach := sh_l.lerp(touch, 0.36) + Vector3(0, 0.03, 0)
	var dir_reach := (touch - hand_reach).normalized()
	var hand_l := hand_rest.lerp(hand_reach, reach)
	var dir := dir_rest.lerp(dir_reach, reach).normalized()
	_linstock.position = hand_l
	if dir.y > -0.99:
		_linstock.basis = Basis(Quaternion(Vector3.UP, dir))
	var glow := 1.0 + 0.25 * sin(t * 17.0) + 0.6 * reach
	_ember.scale = Vector3.ONE * glow
	# Mano derecha: en la cadera; se tapa la oreja cuando va a sonar el estampido
	var ear := maxf(smoothstep(0.8, 0.97, c) if has_target else 0.0, clampf(fire * 2.0, 0.0, 1.0))
	var hand_r := (mx * Vector3(0.18, 0.12, -0.04)).lerp(mx * Vector3(0.15, 0.44, 0.0), ear)
	_hand_l.position = hand_l
	_hand_r.position = hand_r
	M.orient_segment(_arm_l, sh_l, hand_l)
	M.orient_segment(_arm_r, sh_r, hand_r)
	# Fogonazo y bocanada de humo en la boca; humillo en el oído del cañón
	_smoke.visible = fire > 0.01
	if _smoke.visible:
		var e := 1.0 - fire
		var muzzle := _carriage.transform * (gun_rest * Vector3(0, 0, MUZZLE_Z - 0.02))
		_smoke.position = muzzle + Vector3(0, e * 0.12, 0)
		_smoke.basis = gun_rest.basis
		_flash.visible = fire > 0.55
		_flash.scale = Vector3.ONE * (0.6 + fire * 0.7)
		for i in _puffs.size():
			var pf := _puffs[i]
			var base: Vector3 = pf.get_meta("base", Vector3.ZERO)
			pf.position = base * (0.6 + e * 1.6) + Vector3(0, e * e * 0.06 * (1 + i % 3), 0)
			pf.scale = Vector3.ONE * (0.45 + e * 1.1) * (1.0 - e * e * 0.55)
	_touch_smoke.visible = fire > 0.05
	if _touch_smoke.visible:
		var te := 1.0 - fire
		_touch_smoke.position = touch + Vector3(0, 0.02 + te * 0.15, 0)
		_touch_smoke.scale = Vector3.ONE * (0.5 + te * 1.2)
	Arch.animate_fx(t, _flames, _pennants, _spinners, _floaters)


## Boca de la bombarda (posición global)
func muzzle_global() -> Vector3:
	return _gun.to_global(Vector3(0, 0, MUZZLE_Z - 0.04))


# =====================================================================
# --- Piezas sueltas ---
# =====================================================================

# Caja de piezas mirando hacia fuera en el ángulo `a` (a = 0 -> +Z), a radio r y altura y
static func _ring_box(p: Node3D, a: float, r: float, y: float, size: Vector3, m: Material) -> MeshInstance3D:
	return M.box(p, size, m, Vector3(sin(a) * r, y, cos(a) * r), Vector3(0, rad_to_deg(a), 0))


# Nodo en la cara del muro redondo (su +Z local apunta hacia fuera)
static func _face(p: Node3D, a: float, r: float, y: float) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(sin(a) * r, y, cos(a) * r)
	n.rotation.y = a
	p.add_child(n)
	return n


# Parapeto redondo con almenas (y = base del muro)
static func _round_parapet(p: Node3D, r: float, y: float, h: float, th: float, n_merlons: int, mh: float, wall: Material, cap: Material) -> void:
	var n := 24
	for k in n:
		_ring_box(p, TAU * k / n, r, y + h * 0.5, Vector3(TAU * r / n * 1.12, h, th), wall)
	if n_merlons <= 0:
		return
	var mw := TAU * r / n_merlons * 0.48
	for k in n_merlons:
		var a := TAU * (k + 0.5) / n_merlons
		_ring_box(p, a, r, y + h + mh * 0.5, Vector3(mw, mh, th + 0.006), wall)
		if cap != null:
			_ring_box(p, a, r, y + h + mh + 0.012, Vector3(mw + 0.02, 0.024, th + 0.026), cap)


# Barril de pólvora (de pie o tumbado sobre el eje X)
static func _keg(p: Node3D, pos: Vector3, r: float, h: float, wood: Material, hoop: Material, lying := false) -> void:
	var n := Node3D.new()
	n.position = pos
	if lying:
		n.rotation.z = PI * 0.5
	p.add_child(n)
	M.cyl(n, r, r * 0.82, h * 0.5, wood, Vector3(0, -h * 0.25, 0), Vector3.ZERO, 14)
	M.cyl(n, r * 0.82, r, h * 0.5, wood, Vector3(0, h * 0.25, 0), Vector3.ZERO, 14)
	for y: float in [-0.36, -0.14, 0.14, 0.36]:
		var rr := r * (1.0 - absf(y) * 0.42) + 0.004
		M.cyl(n, rr, rr, 0.012, hoop, Vector3(0, y * h, 0), Vector3.ZERO, 14)
	M.cyl(n, r * 0.8, r * 0.8, 0.01, M.mat(TIMBER), Vector3(0, h * 0.5, 0), Vector3.ZERO, 14)
	if not lying:
		# tapón y un reguero de pólvora negra
		M.cyl(n, 0.012, 0.012, 0.012, M.mat(TIMBER), Vector3(r * 0.4, h * 0.5 + 0.008, 0), Vector3.ZERO, 6)


# Pirámide de bolaños de piedra (capas de 3x3, 2x2 y 1, o 2x2 y 1)
static func _ball_pile(p: Node3D, pos: Vector3, r: float, big: bool, m: Material) -> void:
	var layers := [3, 2, 1] if big else [2, 1]
	var y := r
	for n: int in layers:
		for i in n:
			for j in n:
				var off := Vector3((i - (n - 1) * 0.5) * r * 2.0, y, (j - (n - 1) * 0.5) * r * 2.0)
				M.sphere(p, r, m, pos + off, Vector3.ONE, 10)
		y += r * 1.41


# Plataforma de tablones (disco) con su borde
static func _deck_floor(p: Node3D, r: float, y: float, plank: Material, seam: Material) -> void:
	M.cyl(p, r, r, 0.05, plank, Vector3(0, y - 0.025, 0), Vector3.ZERO, 24)
	for k in 7:
		var x := -r + (k + 1) * 2.0 * r / 8.0
		var half := sqrt(maxf(r * r - x * x, 0.0)) * 0.96
		M.box(p, Vector3(0.008, 0.008, half * 2.0), seam, Vector3(x, y + 0.001, 0))


# =====================================================================
# --- Bastión ---
# =====================================================================

func _build_tower(p: Node3D) -> void:
	match tier:
		0: _tower_t0(p)
		1: _tower_t1(p)
		2: _tower_t2(p)
		_: _tower_t3(p)


# Etapa 0: terraplén con empalizada redonda de troncos y cestones de mimbre
func _tower_t0(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[0]
	var dirt := M.mat(Color(0.5, 0.38, 0.25))
	var bark := M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36))
	var bark2 := M.tex_mat("wood", 2.5, Color(0.57, 0.42, 0.29))
	var log_dark := M.mat(Color(0.4, 0.26, 0.15))
	var plank := M.tex_mat("wood", 2.0, Color(0.86, 0.72, 0.53))
	var wicker := M.tex_mat("wood", 4.0, Color(0.92, 0.8, 0.52))
	var rope := M.mat(ROPE)
	var iron := M.metal(IRON)
	# terraplén
	M.cyl(p, 0.44, 0.48, 0.07, dirt, Vector3(0, 0.035, 0), Vector3.ZERO, 24)
	# empalizada de troncos
	var n := 22
	for k in n:
		var a := TAU * k / n
		var h := py - 0.02 + (k % 3) * 0.015
		M.cyl(p, 0.046, 0.05, h, bark if k % 2 == 0 else bark2, Vector3(sin(a) * 0.38, 0.06 + h * 0.5, cos(a) * 0.38), Vector3.ZERO, 8)
	for y: float in [0.16, py - 0.06]:
		M.cyl(p, 0.405, 0.405, 0.03, rope, Vector3(0, y, 0), Vector3.ZERO, 24)
	_deck_floor(p, 0.4, py, plank, log_dark)
	# cestones de mimbre rellenos de tierra en el borde
	var nb := 10
	for k in nb:
		var a := TAU * (k + 0.5) / nb
		var bp := Vector3(sin(a) * 0.4, py, cos(a) * 0.4)
		M.cyl(p, 0.062, 0.056, 0.13, wicker, bp + Vector3(0, 0.065, 0), Vector3.ZERO, 10)
		for y: float in [0.03, 0.1]:
			M.cyl(p, 0.064, 0.064, 0.012, log_dark, bp + Vector3(0, y, 0), Vector3.ZERO, 10)
		M.sphere(p, 0.056, dirt, bp + Vector3(0, 0.13, 0), Vector3(1, 0.4, 1), 8)
	# escalera en el lado +X
	for sz: float in [-1.0, 1.0]:
		M.segment(p, 0.016, bark, Vector3(0.47, 0.0, 0.09 * sz), Vector3(0.43, py + 0.08, 0.09 * sz), 6)
	for k in 5:
		var f := (k + 0.7) / 5.6
		M.box(p, Vector3(0.024, 0.02, 0.2), log_dark, Vector3(lerpf(0.47, 0.43, f), f * (py + 0.08), 0))
	# puerta de tablas en +Z
	M.box(p, Vector3(0.2, 0.3, 0.03), plank, Vector3(0, 0.22, 0.41))
	for y: float in [0.13, 0.31]:
		M.box(p, Vector3(0.21, 0.022, 0.012), iron, Vector3(0, y, 0.428))
	# pertrechos al pie: barriles, bolaños y un cubo
	var ball := M.mat(BALL)
	_keg(p, Vector3(-0.37, 0.12, 0.36), 0.05, 0.11, plank, iron)
	_keg(p, Vector3(0.34, 0.11, -0.38), 0.046, 0.12, plank, iron, true)
	_ball_pile(p, Vector3(0.37, 0.05, 0.36), 0.032, false, ball)
	_ball_pile(p, Vector3(-0.38, 0.05, -0.36), 0.03, false, ball)
	M.cyl(p, 0.04, 0.032, 0.06, plank, Vector3(-0.42, 0.1, 0.2), Vector3.ZERO, 10)
	# mástil para la banderola
	M.cyl(p, 0.012, 0.014, 0.44, log_dark, Vector3(-0.3, py + 0.2, -0.27), Vector3.ZERO, 6)
	Arch._ground_details(p, false)


# Muro redondo de sillares: zócalo, talud, cuerpo, cordón y sillares salientes
static func _stone_drum(p: Node3D, py: float, r: float, wall: Material, stones: Array, dark: Material, foot: float) -> void:
	M.cyl(p, foot, foot + 0.01, 0.07, dark, Vector3(0, 0.035, 0), Vector3.ZERO, 28)
	M.cyl(p, r + 0.01, foot - 0.01, 0.26, wall, Vector3(0, 0.2, 0), Vector3.ZERO, 28)
	var body_h := py - 0.33
	M.cyl(p, r, r, body_h, wall, Vector3(0, 0.33 + body_h * 0.5, 0), Vector3.ZERO, 28)
	M.cyl(p, r + 0.022, r + 0.022, 0.035, stones[2], Vector3(0, 0.335, 0), Vector3.ZERO, 28)
	# sillares salientes, al tresbolillo
	var rows := int((body_h - 0.06) / 0.11)
	for row in rows:
		for k in 12:
			if (k + row) % 3 == 0:
				continue
			var a := TAU * (k + (0.5 if row % 2 == 1 else 0.0)) / 12.0
			_ring_box(p, a, r + 0.008, 0.41 + row * 0.11, Vector3(0.15, 0.085, 0.03), stones[(k + row) % stones.size()])


# Tronera para cañón en el muro redondo
static func _gunport(p: Node3D, a: float, r: float, y: float, frame: Material, hole: Material, shutter: Material) -> void:
	var f := _face(p, a, r, y)
	M.box(f, Vector3(0.14, 0.12, 0.04), frame, Vector3.ZERO)
	M.cyl(f, 0.04, 0.04, 0.046, hole, Vector3(0, 0, 0.002), Vector3(90, 0, 0), 12)
	if shutter != null:
		M.box(f, Vector3(0.1, 0.04, 0.016), shutter, Vector3(0, 0.07, 0.02), Vector3(-30, 0, 0))


# Etapa 1: bastión redondo de piedra con troneras y parapeto de almenas
func _tower_t1(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[1]
	var r := 0.4
	var wall := M.tex_mat("bricks", 2.4, Color(0.84, 0.82, 0.77))
	var stones: Array[Material] = [M.mat(Color(0.62, 0.6, 0.56)), M.mat(Color(0.53, 0.51, 0.48)), M.mat(Color(0.68, 0.66, 0.62))]
	var dark := M.mat(STONE_DARK)
	var black := M.mat(Color(0.07, 0.06, 0.06))
	var wood := M.tex_mat("wood", 2.0, Color(0.7, 0.53, 0.38))
	var iron := M.metal(IRON)
	_stone_drum(p, py, r, wall, stones, dark, 0.47)
	for a: float in [PI, PI * 0.5, -PI * 0.5]:
		_gunport(p, a, r + 0.01, py * 0.62, stones[2], black, null)
	Arch._door(p, r + 0.03, stones[2], wood, iron)
	# suelo del adarve con cornisa
	M.cyl(p, r + 0.035, r + 0.01, 0.06, stones[2], Vector3(0, py - 0.03, 0), Vector3.ZERO, 28)
	_deck_floor(p, r - 0.02, py + 0.002, M.tex_mat("wood", 2.0, Color(0.82, 0.68, 0.5)), M.mat(TIMBER))
	_round_parapet(p, r + 0.01, py, 0.09, 0.06, 8, 0.09, wall, stones[2])
	# escudo en el frente de batalla
	Arch.heater(p, Vector3(0, py * 0.62 + 0.13, -(r + 0.012)), PI, 1.3, M.mat(RED), M.metal(GOLD), iron)
	# pertrechos al pie
	var ball := M.mat(BALL)
	var plank := M.tex_mat("wood", 2.0, Color(0.8, 0.62, 0.44))
	_keg(p, Vector3(-0.38, 0.13, 0.37), 0.05, 0.12, plank, iron)
	_keg(p, Vector3(-0.3, 0.05, 0.42), 0.045, 0.11, plank, iron, true)
	_ball_pile(p, Vector3(0.37, 0.07, 0.36), 0.032, false, ball)
	_ball_pile(p, Vector3(0.37, 0.07, -0.37), 0.032, false, ball)
	_ball_pile(p, Vector3(-0.38, 0.07, -0.37), 0.03, false, ball)
	Arch.wall_torch(p, Vector3(0.17, 0.42, r - 0.005), Vector3(0, 0, 1), iron)
	M.cyl(p, 0.012, 0.014, 0.5, M.mat(TIMBER), Vector3(0.25, py + 0.25, 0.32), Vector3.ZERO, 6)
	Arch._ground_details(p, false)


# Ménsulas y matacanes alrededor de un muro redondo
static func _corbels(p: Node3D, r: float, y: float, n: int, stones: Array, black: Material) -> void:
	for k in n:
		var a := TAU * k / n
		_ring_box(p, a, r + 0.02, y, Vector3(0.05, 0.1, 0.06), stones[k % stones.size()])
		_ring_box(p, a + PI / n, r + 0.035, y + 0.035, Vector3(0.05, 0.03, 0.03), black)


# Etapa 2: gran bastión con matacanes, torreones traseros, estandartes y antorchas
func _tower_t2(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[2]
	var r := 0.41
	var wall := M.tex_mat("bricks", 2.4, Color(0.86, 0.84, 0.79))
	var stones: Array[Material] = [M.mat(Color(0.62, 0.6, 0.56)), M.mat(Color(0.53, 0.51, 0.48)), M.mat(Color(0.68, 0.66, 0.62))]
	var dark := M.mat(STONE_DARK)
	var black := M.mat(Color(0.07, 0.06, 0.06))
	var wood := M.tex_mat("wood", 2.0, Color(0.7, 0.53, 0.38))
	var iron := M.metal(IRON)
	var gold := M.metal(GOLD)
	var slate := M.tex_mat("roof", 3.0, Color(0.55, 0.6, 0.72))
	_stone_drum(p, py, r, wall, stones, dark, 0.48)
	M.cyl(p, r + 0.02, r + 0.02, 0.03, stones[2], Vector3(0, py * 0.7, 0), Vector3.ZERO, 28)
	for a: float in [PI, PI * 0.72, -PI * 0.72, PI * 0.4, -PI * 0.4]:
		_gunport(p, a, r + 0.01, py * 0.55, stones[2], black, iron)
	Arch._door(p, r + 0.03, stones[2], wood, iron)
	_corbels(p, r, py - 0.14, 18, stones, black)
	M.cyl(p, r + 0.05, r + 0.04, 0.07, stones[2], Vector3(0, py - 0.04, 0), Vector3.ZERO, 28)
	_deck_floor(p, r, py + 0.002, M.tex_mat("wood", 2.0, Color(0.82, 0.68, 0.5)), M.mat(TIMBER))
	_round_parapet(p, r + 0.02, py, 0.1, 0.06, 8, 0.1, wall, stones[2])
	# torreones traseros con tejado de pizarra
	for sx: float in [-1.0, 1.0]:
		Arch.turret(p, Vector3(0.335 * sx, 0, 0.335), 0.085, py - 0.2, py + 0.26, wall, slate, 0.3, stones[2], gold)
		Arch.wall_torch(p, Vector3(0.17 * sx, 0.42, r - 0.005), Vector3(0, 0, 1), iron)
	# estandartes (frente de batalla, costados) y escudos
	Arch.hang_banner(p, Vector3(0, py - 0.21, -(r + 0.05)), PI, 0.18, 0.3, M.mat(RED), gold, M.mat(YELLOW), 0)
	for sx: float in [-1.0, 1.0]:
		Arch.hang_banner(p, Vector3((r + 0.05) * sx, py - 0.21, 0), PI * 0.5 * sx, 0.15, 0.26, M.mat(RED), gold, M.mat(YELLOW), 2)
		Arch.heater(p, Vector3(sin(PI - 0.75 * sx) * (r + 0.012), py * 0.55 + 0.15, cos(PI - 0.75 * sx) * (r + 0.012)), PI - 0.75 * sx, 1.1, M.mat(RED), M.metal(GOLD), iron)
	# pertrechos al pie
	var ball := M.mat(BALL)
	var plank := M.tex_mat("wood", 2.0, Color(0.8, 0.62, 0.44))
	_keg(p, Vector3(-0.38, 0.14, 0.37), 0.05, 0.12, plank, iron)
	_keg(p, Vector3(0.39, 0.13, -0.3), 0.045, 0.12, plank, iron)
	_ball_pile(p, Vector3(0.37, 0.07, 0.37), 0.03, false, ball)
	_ball_pile(p, Vector3(-0.37, 0.07, -0.37), 0.032, false, ball)
	Arch._ground_details(p, false)


# Etapa 3 (Maestría): bastión real de mármol y oro con torreones de tejado azul
func _tower_t3(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[3]
	var r := 0.41
	var wall := M.tex_mat("bricks", 2.4, MARBLE)
	var stones: Array[Material] = [M.mat(Color(0.93, 0.91, 0.86)), M.mat(Color(0.86, 0.84, 0.8)), M.mat(Color(1.0, 0.98, 0.94))]
	var dark := M.mat(Color(0.74, 0.72, 0.68))
	var gold := M.metal(GOLD)
	var royal := M.mat(ROYAL)
	var blue_roof := M.tex_mat("roof", 3.0, Color(0.42, 0.55, 0.95))
	var glow := M.mat(Color(1.0, 0.85, 0.5), 1.6)
	var wood := M.tex_mat("wood", 2.0, Color(0.62, 0.45, 0.32))
	_stone_drum(p, py, r, wall, stones, dark, 0.48)
	# bandas doradas y friso azul real
	M.cyl(p, r + 0.02, r + 0.02, 0.03, gold, Vector3(0, py * 0.7, 0), Vector3.ZERO, 28)
	M.cyl(p, r + 0.005, r + 0.005, 0.06, royal, Vector3(0, py * 0.7 + 0.05, 0), Vector3.ZERO, 28)
	for k in 12:
		var a := TAU * (k + 0.5) / 12.0
		_ring_box(p, a, r + 0.012, py * 0.7 + 0.05, Vector3(0.025, 0.025, 0.01), gold).rotation.z = PI * 0.25
	M.cyl(p, 0.49, 0.49, 0.02, gold, Vector3(0, 0.075, 0), Vector3.ZERO, 28)
	for a: float in [PI, PI * 0.72, -PI * 0.72, PI * 0.4, -PI * 0.4]:
		_gunport(p, a, r + 0.01, py * 0.5, gold, glow, null)
	Arch._door(p, r + 0.03, gold, wood, gold)
	_corbels(p, r, py - 0.14, 18, [stones[2], gold, stones[0]], glow)
	M.cyl(p, r + 0.05, r + 0.04, 0.07, stones[2], Vector3(0, py - 0.04, 0), Vector3.ZERO, 28)
	M.cyl(p, r + 0.055, r + 0.055, 0.02, gold, Vector3(0, py - 0.005, 0), Vector3.ZERO, 28)
	_deck_floor(p, r, py + 0.002, M.tex_mat("wood", 2.0, Color(0.9, 0.78, 0.6)), gold)
	_round_parapet(p, r + 0.02, py, 0.1, 0.06, 8, 0.11, wall, gold)
	# torreones con tejado azul y remate de oro
	for sx: float in [-1.0, 1.0]:
		var top := Arch.turret(p, Vector3(0.335 * sx, 0, 0.335), 0.088, py - 0.22, py + 0.3, wall, blue_roof, 0.34, gold, gold)
		M.cyl(p, 0.007, 0.007, 0.2, gold, top + Vector3(0, 0.1, 0), Vector3.ZERO, 4)
		Arch.wall_torch(p, Vector3(0.17 * sx, 0.42, r - 0.005), Vector3(0, 0, 1), gold)
	# estandartes reales y escudos
	Arch.hang_banner(p, Vector3(0, py - 0.21, -(r + 0.05)), PI, 0.2, 0.36, royal, gold, gold, 2)
	for sx: float in [-1.0, 1.0]:
		Arch.hang_banner(p, Vector3((r + 0.05) * sx, py - 0.21, 0), PI * 0.5 * sx, 0.16, 0.3, royal, gold, gold, 0)
		Arch.heater(p, Vector3(sin(PI - 0.8 * sx) * (r + 0.012), py * 0.5 + 0.17, cos(PI - 0.8 * sx) * (r + 0.012)), PI - 0.8 * sx, 1.2, royal, gold, gold)
	# pertrechos al pie: bolaños dorados y barriles con aros de oro
	var ball := M.mat(Color(0.82, 0.8, 0.76))
	var plank := M.tex_mat("wood", 2.0, Color(0.72, 0.5, 0.36))
	_keg(p, Vector3(-0.38, 0.14, 0.38), 0.05, 0.12, plank, gold)
	_keg(p, Vector3(0.4, 0.14, -0.22), 0.045, 0.12, plank, gold)
	_ball_pile(p, Vector3(0.38, 0.09, 0.38), 0.03, false, ball)
	_ball_pile(p, Vector3(-0.37, 0.09, -0.38), 0.03, false, M.metal(GOLD))
	Arch._ground_details(p, false)


# =====================================================================
# --- Pertrechos sobre la plataforma (giran con la pieza) ---
# =====================================================================

func _build_deck(d: Node3D) -> void:
	var iron := M.metal(GOLD if tier == 3 else IRON)
	var plank := M.tex_mat("wood", 2.0, Color(0.78, 0.6, 0.42))
	var ball := M.mat(BALL) if tier < 3 else M.mat(Color(0.82, 0.8, 0.76))
	_keg(d, Vector3(-0.26, 0.065, 0.25), 0.048, 0.13, plank, iron)
	# reguero de pólvora y saquete de cuero
	M.sphere(d, 0.03, M.mat(POWDER), Vector3(-0.2, 0.005, 0.2), Vector3(1.4, 0.15, 1.0), 8)
	M.sphere(d, 0.032, M.mat(Color(0.5, 0.36, 0.22)), Vector3(0.05, 0.025, 0.33), Vector3(1.0, 0.8, 1.2), 8)
	_ball_pile(d, Vector3(-0.33, 0.0, -0.13), 0.03, false, ball)
	# atacador con su lanada apoyado en el barril
	var shaft := M.mat(Color(0.55, 0.38, 0.22))
	M.segment(d, 0.009, shaft, Vector3(-0.36, 0.0, 0.12), Vector3(-0.27, 0.44, 0.27), 6)
	M.cyl(d, 0.026, 0.026, 0.06, M.mat(Color(0.3, 0.24, 0.2)), Vector3(-0.265, 0.46, 0.278), Vector3(18, 0, -11), 10)
	if tier >= 2:
		# cubo de agua para refrescar la pieza
		M.cyl(d, 0.04, 0.034, 0.07, plank, Vector3(0.12, 0.035, -0.24), Vector3.ZERO, 12)
		M.cyl(d, 0.036, 0.036, 0.01, M.mat(Color(0.35, 0.55, 0.75)), Vector3(0.12, 0.068, -0.24), Vector3.ZERO, 12)
		M.cyl(d, 0.042, 0.042, 0.01, iron, Vector3(0.12, 0.05, -0.24), Vector3.ZERO, 12)


# =====================================================================
# --- Cureña ---
# =====================================================================

func _build_carriage(c: Node3D) -> void:
	var gx := GUN_POS.x
	if tier == 0:
		# Afuste de trineo: dos maderos, travesaños, horquillas para los muñones y una cuña
		var bark := M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36))
		var dark := M.mat(Color(0.4, 0.26, 0.15))
		var rope := M.mat(ROPE)
		var iron := M.metal(IRON)
		for sx: float in [-1.0, 1.0]:
			M.cyl(c, 0.034, 0.034, 0.56, bark, Vector3(gx + 0.1 * sx, 0.034, 0.05), Vector3(90, 0, 0), 8)
			M.box(c, Vector3(0.035, 0.2, 0.06), dark, Vector3(gx + 0.105 * sx, 0.15, GUN_POS.z))
			M.box(c, Vector3(0.04, 0.03, 0.02), iron, Vector3(gx + 0.105 * sx, GUN_POS.y + 0.012, GUN_POS.z - 0.025))
			M.box(c, Vector3(0.04, 0.03, 0.02), iron, Vector3(gx + 0.105 * sx, GUN_POS.y + 0.012, GUN_POS.z + 0.025))
			M.segment(c, 0.01, dark, Vector3(gx + 0.1 * sx, 0.06, 0.12), Vector3(gx + 0.105 * sx, 0.18, GUN_POS.z + 0.02), 6)
		for z: float in [-0.18, 0.05, 0.26]:
			M.box(c, Vector3(0.26, 0.035, 0.05), dark, Vector3(gx, 0.07, z))
		# cuña bajo la recámara
		M.box(c, Vector3(0.1, 0.045, 0.12), bark, Vector3(gx, 0.105, 0.17), Vector3(-10, 0, 0))
		for z: float in [-0.18, 0.26]:
			M.cyl(c, 0.112, 0.112, 0.02, rope, Vector3(gx, 0.07, z), Vector3(0, 0, 90), 8)
		return
	var wood: Material
	var dark: Material
	var strap: Material
	match tier:
		1:
			wood = M.tex_mat("wood", 2.0, Color(0.72, 0.52, 0.36))
			dark = M.mat(TIMBER)
			strap = M.metal(IRON)
		2:
			wood = M.tex_mat("wood", 2.0, Color(0.85, 0.32, 0.26))
			dark = M.mat(Color(0.45, 0.12, 0.1))
			strap = M.metal(IRON)
		_:
			wood = M.tex_mat("wood", 2.0, Color(0.42, 0.55, 0.95))
			dark = M.mat(ROYAL)
			strap = M.metal(GOLD)
	# gualderas (inclinadas: la cola toca el suelo)
	for sx: float in [-1.0, 1.0]:
		var x := gx + 0.098 * sx
		M.box(c, Vector3(0.036, 0.13, 0.38), wood, Vector3(x, 0.14, 0.08), Vector3(15, 0, 0))
		M.box(c, Vector3(0.04, 0.02, 0.36), strap, Vector3(x, 0.205, 0.07), Vector3(15, 0, 0))
		# sobremuñoneras
		M.cyl(c, 0.03, 0.03, 0.044, strap, Vector3(x, GUN_POS.y, GUN_POS.z), Vector3(0, 0, 90), 10)
		for z: float in [0.05, 0.17, 0.27]:
			M.sphere(c, 0.011, strap, Vector3(x + 0.02 * sx, 0.14 - (z - 0.09) * 0.27, z), Vector3.ONE, 6)
	# eje, telera y cola (contera)
	M.cyl(c, 0.022, 0.022, WHEEL_X * 2.0 + 0.02, dark, Vector3(gx, WHEEL_R, WHEEL_Z), Vector3(0, 0, 90), 8)
	M.box(c, Vector3(0.2, 0.05, 0.06), dark, Vector3(gx, 0.1, 0.17))
	M.box(c, Vector3(0.11, 0.04, 0.06), dark, Vector3(gx, 0.04, 0.27))
	M.box(c, Vector3(0.12, 0.02, 0.07), strap, Vector3(gx, 0.02, 0.28))
	# cuña de puntería bajo la recámara
	M.box(c, Vector3(0.1, 0.04, 0.12), M.tex_mat("wood", 2.0, Color(0.78, 0.6, 0.42)), Vector3(gx, 0.13, 0.17), Vector3(-10, 0, 0))
	M.sphere(c, 0.014, strap, Vector3(gx, 0.13, 0.235), Vector3.ONE, 6)
	if tier == 3:
		# medallones dorados en las gualderas
		for sx: float in [-1.0, 1.0]:
			M.cyl(c, 0.03, 0.03, 0.012, M.metal(GOLD), Vector3(gx + 0.12 * sx, 0.14, 0.12), Vector3(0, 0, 90), 12)
			M.cyl(c, 0.016, 0.016, 0.014, M.mat(ROYAL_LIGHT, 1.2), Vector3(gx + 0.122 * sx, 0.14, 0.12), Vector3(0, 0, 90), 10)


# Rueda (eje en X): llanta, rayos y cubo
func _build_wheel(w: Node3D) -> void:
	var wood: Material
	var tire: Material
	var hub: Material
	match tier:
		1:
			wood = M.tex_mat("wood", 2.0, Color(0.72, 0.52, 0.36))
			tire = M.metal(IRON)
			hub = M.metal(IRON)
		2:
			wood = M.tex_mat("wood", 2.0, Color(0.85, 0.32, 0.26))
			tire = M.metal(IRON)
			hub = M.metal(GOLD)
		_:
			wood = M.tex_mat("wood", 2.0, Color(0.42, 0.55, 0.95))
			tire = M.metal(GOLD)
			hub = M.metal(GOLD)
	var rim := TorusMesh.new()
	rim.inner_radius = WHEEL_R - 0.022
	rim.outer_radius = WHEEL_R
	rim.rings = 20
	rim.ring_segments = 8
	M.add(w, rim, tire, Vector3.ZERO, Vector3(0, 0, 90))
	var felloe := TorusMesh.new()
	felloe.inner_radius = WHEEL_R - 0.035
	felloe.outer_radius = WHEEL_R - 0.016
	felloe.rings = 20
	felloe.ring_segments = 6
	M.add(w, felloe, wood, Vector3.ZERO, Vector3(0, 0, 90))
	var n := 8
	for k in n:
		var a := TAU * k / n
		M.box(w, Vector3(0.016, WHEEL_R - 0.03, 0.016), wood, Vector3(0, cos(a), sin(a)) * (WHEEL_R - 0.03) * 0.5, Vector3(rad_to_deg(a), 0, 0))
	M.cyl(w, 0.026, 0.026, 0.05, hub, Vector3.ZERO, Vector3(0, 0, 90), 10)
	M.sphere(w, 0.014, hub, Vector3(0.03, 0, 0), Vector3.ONE, 6)
	M.sphere(w, 0.014, hub, Vector3(-0.03, 0, 0), Vector3.ONE, 6)


# =====================================================================
# --- Bombarda (gira y retrocede con _gun; la boca apunta a -Z) ---
# =====================================================================

func _build_gun(g: Node3D) -> void:
	var r: float = GUN_R_BY_TIER[tier]
	var black := M.mat(Color(0.05, 0.04, 0.04))
	var body: Material
	var band: Material
	match tier:
		0:
			body = M.metal(IRON_DARK)
			band = M.metal(IRON)
		1:
			body = M.metal(BRONZE)
			band = M.metal(BRONZE_DARK)
		2:
			body = M.metal(BRONZE)
			band = M.metal(GOLD)
		_:
			body = M.metal(GOLD)
			band = M.mat(ROYAL)
	# recámara (más estrecha), cascabel y muñones
	M.cyl(g, r * 0.8, r * 0.84, 0.15, body, Vector3(0, 0, 0.125), Vector3(90, 0, 0), 18)
	M.sphere(g, r * 0.62, body, Vector3(0, 0, 0.2), Vector3(1, 1, 0.75), 14)
	M.sphere(g, r * 0.3, band, Vector3(0, 0, 0.245), Vector3.ONE, 10)
	M.cyl(g, r * 0.32, r * 0.32, r * 2.0 + 0.1, body, Vector3.ZERO, Vector3(0, 0, 90), 10)
	# caña y brocal acampanado
	M.cyl(g, r, r * 1.06, 0.33, body, Vector3(0, 0, -0.115), Vector3(90, 0, 0), 22)
	M.cyl(g, r * 1.12, r * 1.34, 0.07, body, Vector3(0, 0, MUZZLE_Z + 0.035), Vector3(90, 0, 0), 22)
	var lip := TorusMesh.new()
	lip.inner_radius = r * 0.8
	lip.outer_radius = r * 1.36
	lip.rings = 22
	lip.ring_segments = 8
	M.add(g, lip, band if tier != 3 else body, Vector3(0, 0, MUZZLE_Z), Vector3(90, 0, 0), Vector3(1, 0.35, 1))
	M.cyl(g, r * 0.84, r * 0.84, 0.02, black, Vector3(0, 0, MUZZLE_Z - 0.004), Vector3(90, 0, 0), 18)
	# oído con cazoleta
	M.box(g, Vector3(0.04, 0.012, 0.04), band, Vector3(0, TOUCH.y - 0.004, TOUCH.z))
	M.cyl(g, 0.009, 0.009, 0.014, black, TOUCH + Vector3(0, 0.004, 0), Vector3.ZERO, 6)
	match tier:
		0:
			# bombarda forjada de duelas con muchos zunchos
			for k in 8:
				var a := TAU * k / 8.0
				M.box(g, Vector3(0.008, 0.008, 0.32), M.metal(IRON), Vector3(sin(a) * r * 1.01, cos(a) * r * 1.01, -0.115), Vector3(0, 0, -rad_to_deg(a)))
			for k in 7:
				var z := 0.03 - k * 0.048
				M.cyl(g, r * 1.1, r * 1.1, 0.022, band, Vector3(0, 0, z), Vector3(90, 0, 0), 18)
			for z: float in [0.1, 0.16]:
				M.cyl(g, r * 0.9, r * 0.9, 0.018, band, Vector3(0, 0, z), Vector3(90, 0, 0), 16)
			# argollas para moverla
			for sx: float in [-1.0, 1.0]:
				var ring := TorusMesh.new()
				ring.inner_radius = 0.012
				ring.outer_radius = 0.02
				M.add(g, ring, band, Vector3(r * 0.9 * sx, 0, 0.13), Vector3(0, 0, 90))
		1:
			for z: float in [0.04, -0.1, -0.24]:
				M.cyl(g, r * 1.1, r * 1.1, 0.024, band, Vector3(0, 0, z), Vector3(90, 0, 0), 20)
			M.cyl(g, r * 0.92, r * 0.92, 0.02, band, Vector3(0, 0, 0.17), Vector3(90, 0, 0), 18)
			_dolphins(g, r, band)
		2:
			for z: float in [0.04, -0.1, -0.24]:
				M.cyl(g, r * 1.1, r * 1.1, 0.024, band, Vector3(0, 0, z), Vector3(90, 0, 0), 20)
				M.cyl(g, r * 1.07, r * 1.07, 0.04, M.metal(BRONZE_DARK), Vector3(0, 0, z), Vector3(90, 0, 0), 20)
			M.cyl(g, r * 0.92, r * 0.92, 0.02, band, Vector3(0, 0, 0.17), Vector3(90, 0, 0), 18)
			_dolphins(g, r, band)
			# escudo de armas fundido en la caña
			var sh := Node3D.new()
			sh.position = Vector3(0, r * 1.02, -0.17)
			sh.rotation.x = -PI * 0.5
			g.add_child(sh)
			Arch.heater(sh, Vector3.ZERO, 0.0, 0.55, M.mat(RED), band, band)
		_:
			# bandas de esmalte azul con filetes de oro y runas brillantes
			var glow := M.mat(Color(1.0, 0.85, 0.45), 2.0)
			for z: float in [0.04, -0.1, -0.24]:
				M.cyl(g, r * 1.09, r * 1.09, 0.035, band, Vector3(0, 0, z), Vector3(90, 0, 0), 20)
				for dz: float in [-0.021, 0.021]:
					M.cyl(g, r * 1.12, r * 1.12, 0.008, M.metal(GOLD), Vector3(0, 0, z + dz), Vector3(90, 0, 0), 20)
			for k in 6:
				var a := TAU * k / 6.0
				M.box(g, Vector3(0.012, 0.012, 0.012), glow, Vector3(sin(a) * r * 1.1, cos(a) * r * 1.1, -0.1), Vector3(0, 0, 45))
			M.cyl(g, r * 0.92, r * 0.92, 0.024, band, Vector3(0, 0, 0.17), Vector3(90, 0, 0), 18)
			_dolphins(g, r, M.metal(GOLD))
			# melena de sol alrededor del brocal
			for k in 12:
				var a := TAU * (k + 0.5) / 12.0
				var sp := M.cyl(g, 0.0, 0.018, 0.05, body, Vector3(sin(a) * r * 1.45, cos(a) * r * 1.45, MUZZLE_Z + 0.04), Vector3.ZERO, 6)
				sp.rotation = Vector3(0, 0, -a)
			# corona sobre la recámara y oído encendido
			M.cyl(g, 0.03, 0.026, 0.02, M.metal(GOLD), Vector3(0, r * 0.84 + 0.01, 0.07), Vector3.ZERO, 10)
			for k in 5:
				var a := TAU * k / 5.0
				M.cyl(g, 0.0, 0.007, 0.022, M.metal(GOLD), Vector3(sin(a) * 0.026, r * 0.84 + 0.03, 0.07 + cos(a) * 0.026), Vector3.ZERO, 4)
			M.sphere(g, 0.01, M.mat(Color(0.5, 0.75, 1.0), 2.0), Vector3(0, r * 0.84 + 0.025, 0.07), Vector3.ONE, 8)
			M.sphere(g, 0.01, glow, TOUCH + Vector3(0, 0.008, 0), Vector3.ONE, 6)


# Asas de delfín sobre la caña (para izar la pieza)
static func _dolphins(g: Node3D, r: float, m: Material) -> void:
	for sx: float in [-1.0, 1.0]:
		var x := r * 0.42 * sx
		var a := Vector3(x, r * 0.9, 0.03)
		var b := Vector3(x, r * 0.9 + 0.045, -0.0)
		var c := Vector3(x, r * 0.9 + 0.045, -0.06)
		var d := Vector3(x, r * 0.95, -0.09)
		M.segment(g, 0.009, m, a, b, 6)
		M.segment(g, 0.009, m, b, c, 6)
		M.segment(g, 0.009, m, c, d, 6)
		M.sphere(g, 0.012, m, b, Vector3.ONE, 6)
		M.sphere(g, 0.012, m, c, Vector3.ONE, 6)


# =====================================================================
# --- Artillero ---
# =====================================================================

func _build_man(c: Node3D) -> void:
	var leather := M.mat(Color(0.36, 0.22, 0.12))
	var gold := M.metal(GOLD)
	var steel := M.metal(Color(0.6, 0.62, 0.66))
	var red := M.mat(RED)
	var yellow := M.mat(YELLOW)
	var royal := M.mat(ROYAL)
	match tier:
		0:
			# peón artillero: jubón de cuero y mandil chamuscado
			Human.body(c, M.mat(Color(0.55, 0.4, 0.26)), M.mat(Color(0.42, 0.3, 0.2)))
			M.box(c, Vector3(0.2, 0.22, 0.02), M.mat(Color(0.3, 0.24, 0.18)), Vector3(0, 0.09, -0.13), Vector3(-6, 0, 0))
		1:
			# librea de la artillería: jubón cuartelado rojo y amarillo
			Human.body(c, red, yellow)
			for sy: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.095, 0.13, 0.02), yellow, Vector3(0.0475 * sy, 0.2 - 0.0 * sy, -0.124), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.095, 0.13, 0.02), yellow, Vector3(-0.0475, 0.07, -0.122), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.095, 0.13, 0.02), red, Vector3(0.0475, 0.07, -0.122), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.095, 0.13, 0.02), red, Vector3(-0.0475, 0.2, -0.126), Vector3(-4, 0, 0))
		2:
			# bergantina roja tachonada
			Human.body(c, M.mat(Color(0.58, 0.12, 0.1)), gold)
			for i in 4:
				for j in 3:
					M.sphere(c, 0.009, gold, Vector3(-0.06 + j * 0.06, 0.07 + i * 0.065, -0.128 + i * 0.002), Vector3.ONE, 6)
			for sx: float in [-1.0, 1.0]:
				M.sphere(c, 0.07, steel, Vector3(0.135 * sx, 0.285, 0), Vector3(1, 0.7, 1), 10)
		_:
			# tabardo real azul con flor de oro y capa corta
			Human.body(c, M.metal(Color(0.8, 0.82, 0.88)), gold)
			M.box(c, Vector3(0.2, 0.28, 0.02), royal, Vector3(0, 0.14, -0.126), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.2, 0.28, 0.02), royal, Vector3(0, 0.14, 0.126), Vector3(4, 0, 0))
			M.box(c, Vector3(0.21, 0.02, 0.026), gold, Vector3(0, 0.005, -0.12))
			M.sphere(c, 0.03, gold, Vector3(0, 0.18, -0.14), Vector3(1, 1, 0.4), 8)
			for k in 4:
				var a := TAU * k / 4.0
				M.sphere(c, 0.016, gold, Vector3(sin(a) * 0.035, 0.18 + cos(a) * 0.035, -0.14), Vector3(1, 1, 0.4), 6)
			M.box(c, Vector3(0.26, 0.3, 0.02), M.mat(RED), Vector3(0, 0.16, 0.145), Vector3(10, 0, 0))
			M.box(c, Vector3(0.27, 0.025, 0.026), gold, Vector3(0, 0.02, 0.17), Vector3(10, 0, 0))
			for sx: float in [-1.0, 1.0]:
				M.sphere(c, 0.072, gold, Vector3(0.135 * sx, 0.285, 0), Vector3(1, 0.7, 1), 10)
	# cinturón, bandolera con cargas de pólvora y cuerno
	var belt := TorusMesh.new()
	belt.inner_radius = 0.13
	belt.outer_radius = 0.155
	M.add(c, belt, leather, Vector3(0, 0.09, 0))
	M.box(c, Vector3(0.04, 0.03, 0.02), gold if tier >= 1 else M.metal(IRON), Vector3(0, 0.09, -0.15))
	M.box(c, Vector3(0.035, 0.36, 0.02), leather, Vector3(0.0, 0.2, -0.122), Vector3(-4, 0, 38))
	M.box(c, Vector3(0.035, 0.36, 0.02), leather, Vector3(0.0, 0.2, 0.122), Vector3(4, 0, -38))
	for k in 3:
		var bp := Vector3(-0.07 + k * 0.05, 0.13 + k * 0.045, -0.135)
		M.cyl(c, 0.013, 0.013, 0.04, M.mat(Color(0.25, 0.18, 0.12)) if tier < 3 else gold, bp - Vector3(0, 0.02, 0), Vector3.ZERO, 6)
		M.cyl(c, 0.006, 0.006, 0.012, M.mat(TIMBER), bp + Vector3(0, 0.006, 0), Vector3.ZERO, 4)
	var horn := Node3D.new()
	horn.position = Vector3(0.16, 0.06, 0.03)
	horn.rotation_degrees = Vector3(0, 0, 70)
	c.add_child(horn)
	M.cyl(horn, 0.028, 0.008, 0.11, M.mat(Color(0.92, 0.86, 0.7)), Vector3.ZERO, Vector3.ZERO, 8)
	M.cyl(horn, 0.03, 0.03, 0.012, gold if tier >= 2 else leather, Vector3(0, 0.05, 0), Vector3.ZERO, 8)
	# piernas
	for sx: float in [-1.0, 1.0]:
		M.cyl(c, 0.045, 0.05, 0.05, M.mat(Color(0.25, 0.16, 0.1)), Vector3(0.06 * sx, 0.01, -0.02), Vector3.ZERO, 8)
	# cabeza y tocado
	match tier:
		0:
			# gorro de fieltro con el ala doblada y bigote
			var h0 := Human.head(c, true, true, Color(0.36, 0.22, 0.12))
			M.sphere(h0, 0.135, M.mat(Color(0.4, 0.42, 0.3)), Vector3(0, 0.07, 0.02), Vector3(1.0, 0.7, 1.0), 14)
			M.cyl(h0, 0.18, 0.18, 0.02, M.mat(Color(0.34, 0.36, 0.25)), Vector3(0, 0.04, 0.02), Vector3(-8, 0, 0), 16)
			M.box(h0, Vector3(0.07, 0.016, 0.02), M.mat(Color(0.36, 0.22, 0.12)), Vector3(0, -0.05, -0.135))
		1:
			# bonete rojo con pluma
			var h1 := Human.head(c, true, true, Color(0.5, 0.3, 0.14))
			M.sphere(h1, 0.15, red, Vector3(0.0, 0.075, 0.01), Vector3(1.05, 0.55, 1.05), 14)
			M.cyl(h1, 0.16, 0.16, 0.025, yellow, Vector3(0, 0.05, 0.01), Vector3.ZERO, 16)
			M.segment(h1, 0.012, M.mat(WHITE), Vector3(0.1, 0.1, 0.03), Vector3(0.16, 0.25, 0.12), 6)
			M.sphere(h1, 0.025, M.mat(WHITE), Vector3(0.14, 0.2, 0.09), Vector3(0.6, 1.6, 0.6), 6)
		_:
			# morrión de cresta (dorado en la Maestría) con penacho
			var hm := Human.head(c, true, false)
			var helm := steel if tier == 2 else gold
			M.sphere(hm, 0.15, helm, Vector3(0, 0.06, 0.015), Vector3(1.0, 0.85, 1.05), 14)
			var brim := Node3D.new()
			brim.position = Vector3(0, 0.03, 0.015)
			hm.add_child(brim)
			M.cyl(brim, 0.2, 0.2, 0.02, helm, Vector3.ZERO, Vector3.ZERO, 18)
			for sz: float in [-1.0, 1.0]:
				M.cyl(brim, 0.0, 0.05, 0.05, helm, Vector3(0, 0.02, 0.19 * sz), Vector3(-75.0 * sz, 0, 0), 8)
			M.box(hm, Vector3(0.016, 0.08, 0.24), gold if tier == 2 else M.metal(Color(1.0, 0.86, 0.45)), Vector3(0, 0.175, 0.015))
			var plume_a := M.mat(RED) if tier == 2 else M.mat(WHITE)
			var plume_b := M.mat(YELLOW) if tier == 2 else M.mat(ROYAL_LIGHT)
			for k in 4:
				M.sphere(hm, 0.032, plume_a if k % 2 == 0 else plume_b, Vector3(0, 0.22 + k * 0.012, 0.06 + k * 0.035), Vector3(0.6, 1.0, 1.4), 8)
			M.box(hm, Vector3(0.08, 0.016, 0.02), M.mat(Color(0.3, 0.2, 0.12)), Vector3(0, -0.05, -0.135))


func _build_moving_parts() -> void:
	var sleeve: Material = [M.mat(Color(0.55, 0.4, 0.26)), M.mat(YELLOW), M.mat(Color(0.58, 0.12, 0.1)), M.mat(ROYAL)][tier]
	var glove := M.mat(Color(0.36, 0.22, 0.12)) if tier < 3 else M.metal(GOLD)
	_arm_l = M.add(cat_pivot, M.tube_mesh(0.042, 8), sleeve)
	_arm_r = M.add(cat_pivot, M.tube_mesh(0.042, 8), sleeve)
	_hand_l = M.sphere(cat_pivot, 0.042, glove, Vector3.ZERO, Vector3.ONE, 8)
	_hand_r = M.sphere(cat_pivot, 0.042, glove, Vector3.ZERO, Vector3.ONE, 8)
	# Botafuego: asta con regatón y horquilla de serpiente que sujeta la mecha (a lo largo de +Y)
	_linstock = Node3D.new()
	cat_pivot.add_child(_linstock)
	var shaft := M.mat(Color(0.5, 0.33, 0.18)) if tier < 3 else M.mat(ROYAL)
	var fit := M.metal(IRON) if tier < 2 else M.metal(GOLD)
	M.cyl(_linstock, 0.01, 0.01, LINSTOCK_LEN + 0.08, shaft, Vector3(0, LINSTOCK_LEN * 0.5 - 0.04, 0), Vector3.ZERO, 6)
	M.cyl(_linstock, 0.0, 0.012, 0.04, fit, Vector3(0, -0.09, 0), Vector3(180, 0, 0), 6)
	M.cyl(_linstock, 0.014, 0.012, 0.03, fit, Vector3(0, LINSTOCK_LEN - 0.02, 0), Vector3.ZERO, 8)
	for sx: float in [-1.0, 1.0]:
		M.segment(_linstock, 0.006, fit, Vector3(0, LINSTOCK_LEN - 0.01, 0), Vector3(0.03 * sx, LINSTOCK_LEN + 0.03, 0), 4)
		M.sphere(_linstock, 0.009, fit, Vector3(0.032 * sx, LINSTOCK_LEN + 0.034, 0), Vector3.ONE, 6)
	# mecha de cuerda enrollada y su punta encendida
	M.segment(_linstock, 0.006, M.mat(ROPE), Vector3(0.03, LINSTOCK_LEN + 0.03, 0), Vector3(0.0, LINSTOCK_LEN + 0.06, -0.005), 4)
	M.segment(_linstock, 0.006, M.mat(ROPE), Vector3(-0.03, LINSTOCK_LEN + 0.03, 0), Vector3(-0.005, LINSTOCK_LEN + 0.075, 0.0), 4)
	_ember = Node3D.new()
	_ember.position = Vector3(0.0, LINSTOCK_LEN + 0.07, -0.003)
	_linstock.add_child(_ember)
	M.sphere(_ember, 0.014, M.mat(EMBER, 2.6), Vector3.ZERO, Vector3.ONE, 8)
	M.cyl(_ember, 0.0, 0.01, 0.035, M.mat(Color(1.0, 0.8, 0.35), 2.6), Vector3(0, 0.022, 0), Vector3.ZERO, 6)
	if tier == 3:
		M.sphere(_ember, 0.024, M.mat(Color(1.0, 0.7, 0.3), 1.2), Vector3.ZERO, Vector3.ONE, 8)


# Fogonazo + bocanada de humo (a lo largo de -Z) y humillo del oído
func _build_smoke() -> void:
	_smoke = Node3D.new()
	cat_pivot.add_child(_smoke)
	_flash = Node3D.new()
	_smoke.add_child(_flash)
	M.sphere(_flash, 0.07, M.mat(FLASH, 2.8), Vector3(0, 0, -0.04), Vector3(1, 1, 1.4), 10)
	M.cyl(_flash, 0.0, 0.06, 0.16, M.mat(Color(1.0, 0.9, 0.5), 3.0), Vector3(0, 0, -0.12), Vector3(-90, 0, 0), 8)
	for k in 6:
		var a := TAU * k / 6.0
		M.cyl(_flash, 0.0, 0.018, 0.08, M.mat(Color(1.0, 0.6, 0.2), 2.8), Vector3(sin(a) * 0.06, cos(a) * 0.06, -0.02), Vector3(rad_to_deg(-cos(a)) * 1.2, 0, rad_to_deg(-sin(a)) * 1.2), 4)
	var smoke := M.mat(SMOKE)
	var smoke_dark := M.mat(SMOKE.darkened(0.2))
	var bases := [Vector3(0, 0, -0.08), Vector3(0.05, 0.03, -0.15), Vector3(-0.05, 0.02, -0.16), Vector3(0, 0.06, -0.22),
			Vector3(0.07, -0.02, -0.06), Vector3(-0.07, 0.0, -0.05), Vector3(0.0, -0.03, -0.27), Vector3(0.03, 0.08, -0.1)]
	for i in bases.size():
		var pf := Node3D.new()
		pf.set_meta("base", bases[i])
		_smoke.add_child(pf)
		M.sphere(pf, 0.055 + (i % 3) * 0.012, smoke if i % 3 != 1 else smoke_dark, Vector3.ZERO, Vector3.ONE, 10)
		_puffs.append(pf)
	_touch_smoke = Node3D.new()
	cat_pivot.add_child(_touch_smoke)
	M.sphere(_touch_smoke, 0.025, smoke, Vector3.ZERO, Vector3.ONE, 8)
	M.sphere(_touch_smoke, 0.018, smoke_dark, Vector3(0.015, 0.03, 0.005), Vector3.ONE, 8)


# =====================================================================
# --- Adornos de etapa ---
# =====================================================================

func _build_tier_fx() -> void:
	var py: float = PLAT_BY_TIER[tier]
	match tier:
		0:
			_pennants.append(Arch.pennant_node(self, Vector3(-0.3, py + 0.41, -0.27), RED, WHITE, 0.22, 0.6))
		1:
			_flames.append(Arch.flame_node(self, Vector3(0.17, 0.47, 0.4 + 0.07)))
			_pennants.append(Arch.pennant_node(self, Vector3(0.25, py + 0.48, 0.32), RED, YELLOW, 0.26, 2.6))
		2:
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.17 * sx, 0.47, 0.41 + 0.07)))
				_pennants.append(Arch.pennant_node(self, Vector3(0.335 * sx, py + 0.62, 0.335), RED, YELLOW, 0.26, 0.4 if sx < 0.0 else 2.7))
		3:
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.17 * sx, 0.47, 0.41 + 0.07), 1.1, Color(1.0, 0.82, 0.4)))
				_pennants.append(Arch.pennant_node(self, Vector3(0.335 * sx, py + 0.85, 0.335), ROYAL, GOLD, 0.3, 0.4 if sx < 0.0 else 2.7))
			_spinners.append(Arch.aura_ring(self, 0.47, Color(1.0, 0.85, 0.4), 0.1))
			add_child(Arch.sparkles(Color(1.0, 0.88, 0.5), Vector3(0, 0.7, 0), Vector3(0.45, 0.6, 0.45), 18, 0.012))
