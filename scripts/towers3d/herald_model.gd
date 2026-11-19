extends Node3D
## Modelo 3D de la "Torre del Heraldo" (id herald): torre rara de apoyo que inspira a las torres
## vecinas. Sus colores son el azul y el oro: estandartes heráldicos con un cuerno dorado bordado,
## tambores de guerra y braseros. Arriba, un heraldo sostiene en la mano izquierda un estandarte
## alto cuya bandera ondea, y con la derecha alza un largo cuerno de guerra de latón con su
## banderola. Al recibir un objetivo se lleva el cuerno a la boca (hincha los mofletes) y en cada
## pulso de ánimo (fire) sopla: el pabellón se ensancha, salen ondas de sonido, las banderas
## ondean con fuerza y unos anillos dorados de "inspiración" se extienden alrededor de la torre.
## Etapas:
##   0 (nv 0-1): cabaña de tablones con plataforma, poste con banderola y tablón de pregones;
##               pregonero con túnica azul, capucha y cuerno de vaca.
##   1 (nv 2-3): torre de sillares almenada con estandartes azules en tres caras, tambor y
##               brasero; heraldo con tabardo cuartelado azul y oro y trompeta de latón.
##   2 (nv 4):   gran torre con contrafuertes y torreones de tejado azul, timbales con
##               gualdrapas, dos braseros; heraldo con sombrero de pluma, bigote y capa corta.
##   3 (nv 5):   Maestría: mármol, oro y azul real, emblemas que brillan, timbales de oro,
##               capa real con armiño, trompeta dorada que resplandece, aura y estrellas de oro.
## El heraldo, el estandarte y el cuerno van dentro de cat_pivot (miran a -Z).

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const Arch := preload("res://scripts/towers3d/archer_model.gd")

const STONE_DARK := Color(0.42, 0.4, 0.38)
const TIMBER := Color(0.3, 0.19, 0.1)
const IRON := Color(0.26, 0.26, 0.29)
const BRASS := Color(0.86, 0.64, 0.28)
const BRASS_DARK := Color(0.62, 0.43, 0.18)
const GOLD := Color(0.97, 0.76, 0.28)
const GOLD_BRIGHT := Color(1.0, 0.86, 0.42)
const HOLY := Color(1.0, 0.86, 0.45)
const BLUE := Color(0.2, 0.34, 0.7)
const BLUE_DARK := Color(0.13, 0.2, 0.46)
const BLUE_PALE := Color(0.32, 0.45, 0.74)
const ROYAL := Color(0.14, 0.24, 0.66)
const MARBLE := Color(0.97, 0.95, 0.9)
const CREAM := Color(0.96, 0.91, 0.8)
const WHITE := Color(0.97, 0.96, 0.93)
const LEATHER := Color(0.36, 0.22, 0.12)
const FELT := Color(0.5, 0.36, 0.22)
const HORN_IVORY := Color(0.93, 0.87, 0.72)
const HORN_TIP := Color(0.34, 0.26, 0.18)
const ROPE := Color(0.84, 0.75, 0.56)
const RED := Color(0.74, 0.15, 0.12)
const EMBER := Color(1.0, 0.45, 0.15)

# Altura de la plataforma por etapa (el heraldo va encima)
const PLAT_BY_TIER := [0.56, 0.72, 0.86, 0.98]
const MAN_POS := Vector3(0.05, 0.0, 0.03)
const MAN_SCALE := 0.86
# Estandarte (coordenadas del heraldo): asta a la izquierda, algo adelantada
const POLE_X := -0.25
const POLE_Z := -0.06
const POLE_TOP_BY_TIER := [0.95, 1.02, 1.1, 1.16]
const GRIP_L_Y := 0.33
const FLAG_SEGS := 4
const FLAG_SEG_LEN := 0.085
const FLAG_H := 0.24
# Cuerno: la boquilla en el origen de _horn y el pabellón hacia -Z
const HORN_LEN_BY_TIER := [0.34, 0.44, 0.52, 0.56]
const BELL_R_BY_TIER := [0.04, 0.058, 0.07, 0.078]
const HORN_GRIP := Vector3(0, -0.028, -0.11)
const MOUTH := Vector3(0, 0.385, -0.15)
const REST_POS := Vector3(0.21, 0.3, -0.06)
const BLOW_TILT := 0.4
const REST_TILT := 1.05

var cat_pivot: Node3D
var tier := 0
var _man: Node3D
var _horn: Node3D
var _bell_node: Node3D
var _standard: Node3D
var _flag_root: Node3D
var _flag_segs: Array[Node3D] = []
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _hand_l: MeshInstance3D
var _hand_r: MeshInstance3D
var _cheeks: Array[MeshInstance3D] = []
var _waves: Array[MeshInstance3D] = []
var _wave_mat: StandardMaterial3D
var _rings: Array[MeshInstance3D] = []
var _ring_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _light: OmniLight3D
var _blend := 0.0
var _snap := true
var _flames: Array[Node3D] = []
var _pennants: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _floaters: Array[Node3D] = []
var _no_pennants: Array[Node3D] = []


func _init(level := 0) -> void:
	tier = Arch.tier_of(level)
	M.add_baked(self, M.baked("herald_tower_t%d" % tier, _build_tower))
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, PLAT_BY_TIER[tier], 0)
	add_child(cat_pivot)
	_man = Node3D.new()
	_man.position = MAN_POS
	_man.scale = Vector3.ONE * MAN_SCALE
	cat_pivot.add_child(_man)
	M.add_baked(_man, M.baked("herald_man_t%d" % tier, _build_man))
	# Estandarte con su bandera ondeante
	_standard = Node3D.new()
	_man.add_child(_standard)
	M.add_baked(_standard, M.baked("herald_standard_t%d" % tier, _build_standard))
	_build_flag()
	# Cuerno de guerra y su pabellón (que se ensancha al soplar)
	_build_glow_mat()
	_horn = Node3D.new()
	_man.add_child(_horn)
	M.add_baked(_horn, M.baked("herald_horn_t%d" % tier, _build_horn))
	_bell_node = Node3D.new()
	_bell_node.position = _horn_point(1.0)
	_bell_node.basis = Basis(Quaternion(Vector3.UP, _horn_dir()))
	_horn.add_child(_bell_node)
	M.add_baked(_bell_node, M.baked("herald_bell_t%d" % tier, _build_bell))
	var br: float = BELL_R_BY_TIER[tier]
	M.cyl(_bell_node, br - 0.006, br - 0.006, 0.004, _glow_mat, Vector3(0, -0.008, 0), Vector3.ZERO, 16)
	_build_moving_parts()
	_build_tier_fx()
	animate({"t": 0.0, "charge": 0.0, "fire": 0.0, "has_target": false})
	_snap = true  # la primera pose real se aplica sin transición


## s = {t, charge (0..1), fire (1 -> 0), has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = clampf(s.get("charge", 0.0), 0.0, 1.0)
	var fire: float = clampf(s.get("fire", 0.0), 0.0, 1.0)
	var has_target: bool = s.get("has_target", false)
	# Con objetivo y carga suficiente se lleva el cuerno a la boca; al sonar lo mantiene
	var goal := 0.0
	if fire > 0.0:
		goal = 1.0
	elif has_target:
		goal = smoothstep(0.15, 0.55, charge)
	if _snap:
		_blend = goal
		_snap = false
	else:
		_blend = lerpf(_blend, goal, 0.3)
	var b := _blend
	# Cuerno: de alzado al costado (descanso) a la boca (soplando), con temblor al sonar
	_horn.position = REST_POS.lerp(MOUTH, b) + Vector3(0, fire * 0.012, fire * 0.012)
	_horn.rotation = Vector3(lerpf(REST_TILT, BLOW_TILT, b) + fire * 0.14,
			lerpf(-0.12, 0.0, b) + sin(t * 47.0) * 0.015 * fire, lerpf(-0.22, 0.0, b))
	_bell_node.scale = Vector3.ONE * (1.0 + fire * 0.3)
	# El heraldo se echa atrás al soplar y respira en reposo
	_man.position = MAN_POS + Vector3(0, absf(sin(t * 1.4)) * 0.005, 0)
	_man.rotation.x = b * 0.04 + fire * 0.1
	# El estandarte se alza con el toque
	_standard.position = Vector3(0, fire * 0.035, 0)
	_standard.rotation.z = sin(t * 1.1) * 0.02 - fire * 0.04
	# Manos y brazos
	var hl := _standard.transform * Vector3(POLE_X, GRIP_L_Y, POLE_Z)
	var hr := _horn.transform * HORN_GRIP
	_hand_l.position = hl
	_hand_r.position = hr
	M.orient_segment(_arm_l, Human.L_SHOULDER, hl)
	M.orient_segment(_arm_r, Human.R_SHOULDER, hr)
	# Mofletes hinchados al soplar
	var puff := clampf(b * 0.45 + fire * 0.8, 0.0, 1.0)
	for ch in _cheeks:
		ch.visible = puff > 0.05
		ch.scale = Vector3.ONE * maxf(puff, 0.01)
	# Bandera del estandarte: ondea siempre y con fuerza en cada toque
	var amp := 1.0 + fire * 1.6
	_flag_root.rotation.y = sin(t * 1.3) * 0.18
	for i in _flag_segs.size():
		_flag_segs[i].rotation.y = sin(t * 3.2 - i * 1.1) * (0.22 + 0.08 * i) * amp
	# Banderolas de las astas (también se agitan con el toque)
	for i in _pennants.size():
		var pn := _pennants[i]
		pn.rotation.y = pn.get_meta("yaw", 0.0) + sin(t * 2.2 + i * 1.3) * 0.3 * amp
		var tail := pn.get_child(pn.get_child_count() - 1) as Node3D
		tail.rotation.y = sin(t * 3.4 + i * 1.3 + 0.8) * 0.45 * amp
	# Ondas de sonido que salen del pabellón
	for i in _waves.size():
		var w := _waves[i]
		var ph := clampf((1.0 - fire) * 1.2 - i * 0.2, 0.0, 1.0)
		w.visible = fire > 0.0 and ph > 0.0 and ph < 1.0
		w.scale = Vector3.ONE * (1.0 + ph * 3.5)
		w.position = Vector3(0, 0.02 + ph * 0.28, 0)
	_wave_mat.albedo_color.a = 0.6 * fire
	# Anillos dorados de inspiración que se extienden hacia las torres vecinas
	for i in _rings.size():
		var r := _rings[i]
		var ph := clampf((1.0 - fire) * 1.15 - i * 0.25, 0.0, 1.0)
		r.visible = fire > 0.0 and ph > 0.0 and ph < 1.0
		r.scale = Vector3(1.0 + ph * 1.9, 1.0, 1.0 + ph * 1.9)
	_ring_mat.albedo_color.a = 0.75 * fire
	# Brillo del pabellón (etapas 2 y 3)
	if tier >= 2:
		_glow_mat.emission_energy_multiplier = (0.8 if tier == 2 else 1.5) + charge * 0.4 + fire * 2.5 + sin(t * 3.0) * 0.15
	if _light:
		_light.light_energy = (0.3 if tier == 2 else 0.6) + charge * 0.2 + fire * 1.6
	Arch.animate_fx(t, _flames, _no_pennants, _spinners, _floaters)


## Pabellón del cuerno (posición global): de aquí sale el proyectil sagrado
func muzzle_global() -> Vector3:
	return _bell_node.to_global(Vector3(0, 0.02, 0))


# =====================================================================
# --- Piezas comunes ---
# =====================================================================

static func _faces() -> Array[Vector3]:
	return [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]


## Cuerno de caza bordado (emblema del heraldo) en el plano XY, mirando a +Z del nodo
static func _horn_emblem(p: Node3D, c: Vector3, s: float, m: Material, yaw := 0.0) -> void:
	var n := Node3D.new()
	n.position = c
	n.rotation.y = yaw
	p.add_child(n)
	var pts: Array[Vector3] = []
	for i in 6:
		var a := lerpf(PI * 0.92, PI * 1.98, i / 5.0)
		pts.append(Vector3(0.065 * cos(a), 0.045 * sin(a) + 0.012, 0) * s)
	for i in 5:
		var r := lerpf(0.006, 0.012, i / 4.0) * s
		M.segment(n, r, m, pts[i], pts[i + 1], 6)
		M.sphere(n, r, m, pts[i + 1], Vector3(1, 1, 0.7), 6)
	M.sphere(n, 0.009 * s, m, pts[0], Vector3(1, 1, 0.7), 6)
	var d := (pts[5] - pts[4]).normalized()
	var bn := Node3D.new()
	bn.position = pts[5]
	bn.basis = Basis(Quaternion(Vector3.UP, d))
	n.add_child(bn)
	M.add(bn, M.cyl_mesh(0.03 * s, 0.012 * s, 0.035 * s, 10), m, Vector3(0, 0.0175 * s, 0), Vector3.ZERO, Vector3(1, 1, 0.6))
	# cordón colgante del cuerno
	M.segment(n, 0.004 * s, m, pts[1], Vector3(0.0, -0.065, 0) * s, 4)
	M.segment(n, 0.004 * s, m, pts[4], Vector3(0.0, -0.065, 0) * s, 4)
	M.sphere(n, 0.009 * s, m, Vector3(0.0, -0.068, 0) * s, Vector3(1, 1.4, 0.7), 6)


## Estandarte colgante con el cuerno bordado, mirando a +Z del nodo girado `yaw`
static func _banner(p: Node3D, pos: Vector3, yaw: float, w: float, h: float, field: Material, trim: Material, emblem: Material) -> void:
	Arch.hang_banner(p, pos, yaw, w, h, field, trim, emblem, 3)
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	p.add_child(n)
	# franjas verticales del borde y emblema
	for k: float in [-1.0, 1.0]:
		M.box(n, Vector3(0.014, h - 0.05, 0.012), trim, Vector3((w * 0.5 - 0.022) * k, -h * 0.5, 0.012))
	_horn_emblem(n, Vector3(0, -h * 0.46, 0.016), w / 0.19, emblem)


## Medallón de suelo azul con rosa de los vientos dorada (bajo el heraldo; se ve desde arriba)
static func _medallion(p: Node3D, y: float, r: float, field: Material, ring_m: Material, star_m: Material) -> void:
	M.cyl(p, r, r, 0.012, field, Vector3(0, y + 0.006, 0), Vector3.ZERO, 28)
	var ring := TorusMesh.new()
	ring.inner_radius = r - 0.016
	ring.outer_radius = r + 0.004
	ring.rings = 32
	ring.ring_segments = 6
	M.add(p, ring, ring_m, Vector3(0, y + 0.013, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	for k in 8:
		var a := TAU * k / 8.0
		var ln := r * (0.72 if k % 2 == 0 else 0.48)
		M.add(p, M.cyl_mesh(0.0, 0.032, ln, 4), star_m, Vector3(cos(a), 0, sin(a)) * (ln * 0.5 + 0.06) + Vector3(0, y + 0.015, 0),
				Vector3(0, -rad_to_deg(a), -90), Vector3(0.22, 1, 1))
	M.cyl(p, 0.07, 0.07, 0.016, ring_m, Vector3(0, y + 0.012, 0), Vector3.ZERO, 16)


## Tambor de guerra con cordaje en zigzag y baquetas cruzadas
static func _drum(p: Node3D, pos: Vector3, r: float, h: float, shell: Material, head_m: Material, hoop: Material, cord: Material, sticks: Material) -> void:
	M.cyl(p, r, r, h, shell, pos + Vector3(0, h * 0.5, 0), Vector3.ZERO, 16)
	M.cyl(p, r * 0.97, r * 0.97, 0.008, head_m, pos + Vector3(0, h + 0.002, 0), Vector3.ZERO, 16)
	for y: float in [0.012, h - 0.006]:
		M.cyl(p, r + 0.008, r + 0.008, 0.02, hoop, pos + Vector3(0, y, 0), Vector3.ZERO, 16)
	var n := 8
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 0.5) / n
		var a2 := TAU * (k + 1.0) / n
		var rr := r + 0.005
		M.segment(p, 0.004, cord, pos + Vector3(cos(a0) * rr, 0.024, sin(a0) * rr), pos + Vector3(cos(a1) * rr, h - 0.018, sin(a1) * rr), 4)
		M.segment(p, 0.004, cord, pos + Vector3(cos(a2) * rr, 0.024, sin(a2) * rr), pos + Vector3(cos(a1) * rr, h - 0.018, sin(a1) * rr), 4)
	for k: float in [-1.0, 1.0]:
		var a := pos + Vector3(-r * 0.75, h + 0.014, k * r * 0.35)
		var b := pos + Vector3(r * 0.75, h + 0.022, -k * r * 0.35)
		M.segment(p, 0.006, sticks, a, b, 6)
		M.sphere(p, 0.014, sticks, b, Vector3.ONE, 6)


## Timbal (caldero de metal) con gualdrapa colgante hacia `out`
static func _kettle(p: Node3D, pos: Vector3, r: float, out: Vector3, bowl: Material, head_m: Material, trim: Material,
		field: Material, fringe: Material, emblem: Material) -> void:
	for k in 3:
		var a := TAU * k / 3.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a))
		M.segment(p, 0.008, trim, pos + d * r * 0.95, pos + d * r * 0.55 + Vector3(0, r * 0.7, 0), 4)
	M.sphere(p, r * 0.36, bowl, pos + Vector3(0, r * 0.36, 0), Vector3(1, 0.7, 1), 12)
	M.cyl(p, r * 0.8, r * 0.36, r * 0.36, bowl, pos + Vector3(0, r * 0.44, 0), Vector3.ZERO, 16)
	M.cyl(p, r, r * 0.8, r * 0.34, bowl, pos + Vector3(0, r * 0.78, 0), Vector3.ZERO, 16)
	M.cyl(p, r * 0.98, r * 0.98, 0.008, head_m, pos + Vector3(0, r * 0.96, 0), Vector3.ZERO, 16)
	var ring := TorusMesh.new()
	ring.inner_radius = r - 0.006
	ring.outer_radius = r + 0.008
	ring.rings = 24
	ring.ring_segments = 6
	M.add(p, ring, trim, pos + Vector3(0, r * 0.95, 0))
	for k in 6:
		var a := TAU * k / 6.0
		M.box(p, Vector3(0.012, 0.03, 0.012), trim, pos + Vector3(cos(a) * (r + 0.004), r * 0.86, sin(a) * (r + 0.004)))
	# gualdrapa
	var n := Node3D.new()
	n.position = pos + out * (r + 0.006) + Vector3(0, r * 0.9, 0)
	n.rotation.y = atan2(out.x, out.z)
	p.add_child(n)
	M.box(n, Vector3(r * 1.5, r * 1.0, 0.01), field, Vector3(0, -r * 0.5, 0))
	M.box(n, Vector3(r * 1.5 + 0.01, 0.014, 0.014), fringe, Vector3(0, -r * 1.0, 0))
	for k in 5:
		M.box(n, Vector3(0.008, 0.026, 0.008), fringe, Vector3(-r * 0.66 + k * r * 0.33, -r * 1.0 - 0.018, 0))
	_horn_emblem(n, Vector3(0, -r * 0.48, 0.008), r * 7.0, emblem)
	# baquetas apoyadas
	for k: float in [-1.0, 1.0]:
		M.segment(p, 0.006, trim, pos + Vector3(-r * 0.6, r * 1.0, k * 0.02), pos + Vector3(r * 0.7, r * 1.02, k * 0.035), 6)


## Brasero de tres patas con brasas (la llama se añade en los efectos)
static func _brazier(p: Node3D, pos: Vector3, metal: Material, coal: Material) -> void:
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var d := Vector3(cos(a), 0, sin(a))
		M.segment(p, 0.009, metal, pos + d * 0.065, pos + d * 0.035 + Vector3(0, 0.13, 0), 4)
		M.sphere(p, 0.013, metal, pos + d * 0.065 + Vector3(0, 0.008, 0), Vector3.ONE, 6)
	M.cyl(p, 0.068, 0.035, 0.05, metal, pos + Vector3(0, 0.145, 0), Vector3.ZERO, 12)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.06
	ring.outer_radius = 0.074
	ring.rings = 20
	ring.ring_segments = 6
	M.add(p, ring, metal, pos + Vector3(0, 0.17, 0))
	for k in 5:
		var a := TAU * k / 5.0
		M.sphere(p, 0.024, coal, pos + Vector3(cos(a) * 0.03, 0.168, sin(a) * 0.03), Vector3(1, 0.7, 1), 6)


# Fuste cuadrado de piedra con zócalo, sillares, cornisa y suelo de la plataforma
static func _shaft(p: Node3D, py: float, half: float, wall: Material, stones: Array[Material], dark: Material, floor_m: Material) -> void:
	M.box(p, Vector3(2.0 * half + 0.16, 0.08, 2.0 * half + 0.16), dark, Vector3(0, 0.04, 0))
	M.box(p, Vector3(2.0 * half + 0.07, 0.07, 2.0 * half + 0.07), stones[1], Vector3(0, 0.115, 0))
	var h := py - 0.12
	M.box(p, Vector3(2.0 * half, h, 2.0 * half), wall, Vector3(0, 0.08 + h * 0.5, 0))
	var rows := int((py - 0.2) / 0.1)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for r in rows:
				var big := r % 2 == 0
				var sz3 := Vector3(0.12 if big else 0.07, 0.085, 0.07 if big else 0.12)
				M.box(p, sz3, stones[r % 3], Vector3(half * sx - (0.035 if big else 0.0) * sx + 0.012 * sx, 0.2 + r * 0.1, half * sz - (0.0 if big else 0.035) * sz + 0.012 * sz))
	M.box(p, Vector3(2.0 * half + 0.1, 0.05, 2.0 * half + 0.1), stones[2], Vector3(0, py - 0.075, 0))
	M.box(p, Vector3(2.0 * half + 0.14, 0.05, 2.0 * half + 0.14), floor_m, Vector3(0, py - 0.025, 0))


# =====================================================================
# --- Cuerno de guerra ---
# =====================================================================

## Punto del tubo del cuerno (u = 0 boquilla, u = 1 pabellón), en coordenadas de _horn
func _horn_point(u: float) -> Vector3:
	var ln: float = HORN_LEN_BY_TIER[tier]
	if tier == 0:
		return Vector3(0, 0.1 * u * u, -ln * u)
	return Vector3(0, 0, -ln * u)


func _horn_dir() -> Vector3:
	return (_horn_point(1.0) - _horn_point(0.95)).normalized()


func _build_glow_mat() -> void:
	_glow_mat = StandardMaterial3D.new()
	if tier >= 2:
		_glow_mat.albedo_color = HOLY
		_glow_mat.emission_enabled = true
		_glow_mat.emission = HOLY
		_glow_mat.emission_energy_multiplier = 1.0
	else:
		_glow_mat.albedo_color = Color(0.1, 0.07, 0.05)
		_glow_mat.roughness = 0.9


func _build_horn(h: Node3D) -> void:
	if tier == 0:
		# Cuerno de vaca: punta oscura, cuerpo de marfil, abrazaderas de latón y correa de cuero
		var ivory := M.mat(HORN_IVORY)
		var dark := M.mat(HORN_TIP)
		var brass := M.metal(BRASS)
		var n := 8
		for i in n:
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var r := lerpf(0.011, 0.04, u1)
			var m: Material = dark if i < 2 else ivory
			M.segment(h, r, m, _horn_point(u0), _horn_point(u1), 10)
			M.sphere(h, r, m, _horn_point(u1), Vector3.ONE, 10)
		M.cyl(h, 0.016, 0.009, 0.03, brass, Vector3(0, 0, 0.0), Vector3(90, 0, 0), 8)
		for u: float in [0.3, 0.93]:
			var r := lerpf(0.011, 0.04, u) + 0.005
			M.segment(h, r, brass, _horn_point(u - 0.025), _horn_point(u + 0.025), 10)
		var strap := M.mat(LEATHER)
		var a := _horn_point(0.3) + Vector3(0, -0.02, 0)
		var c := _horn_point(0.93) + Vector3(0, -0.036, 0)
		var mid := (a + c) * 0.5 + Vector3(0, -0.07, 0)
		M.segment(h, 0.006, strap, a, mid, 4)
		M.segment(h, 0.006, strap, mid, c, 4)
		return
	var ln: float = HORN_LEN_BY_TIER[tier]
	var body: Material = [null, M.metal(BRASS), M.metal(Color(0.93, 0.7, 0.3)), M.metal(GOLD_BRIGHT)][tier]
	var band: Material = [null, M.metal(BRASS_DARK), M.metal(GOLD), M.mat(ROYAL)][tier]
	var field: Material = [null, M.mat(BLUE), M.mat(BLUE), M.mat(ROYAL)][tier]
	var trim: Material = [null, M.metal(GOLD), M.metal(GOLD), M.metal(GOLD_BRIGHT)][tier]
	var emb: Material = [null, M.metal(GOLD), M.metal(GOLD_BRIGHT), M.mat(GOLD_BRIGHT, 1.4)][tier]
	# boquilla, tubo largo, virolas y nudo
	M.cyl(h, 0.02, 0.009, 0.03, body, Vector3(0, 0, -0.005), Vector3(90, 0, 0), 10)
	M.segment(h, 0.011, body, Vector3(0, 0, -0.02), Vector3(0, 0, -(ln - 0.09)), 8)
	for z: float in [-0.05, -ln * 0.42, -(ln - 0.12)]:
		M.cyl(h, 0.017, 0.017, 0.025, band, Vector3(0, 0, z), Vector3(90, 0, 0), 10)
	M.sphere(h, 0.022, body, Vector3(0, 0, -ln * 0.42), Vector3(1, 1, 1.7), 10)
	if tier == 3:
		for z: float in [-0.05, -(ln - 0.12)]:
			M.sphere(h, 0.008, M.mat(HOLY, 1.6), Vector3(0, 0.017, z), Vector3.ONE, 6)
	# banderola heráldica colgada del tubo
	var bw: float = [0.0, 0.17, 0.2, 0.22][tier]
	var bh: float = [0.0, 0.1, 0.12, 0.13][tier]
	var z0 := -0.14
	var cz := z0 - bw * 0.5
	M.box(h, Vector3(0.01, bh, bw), field, Vector3(0, -0.014 - bh * 0.5, cz))
	M.box(h, Vector3(0.016, 0.016, bw + 0.012), trim, Vector3(0, -0.012, cz))
	M.box(h, Vector3(0.014, 0.014, bw + 0.006), trim, Vector3(0, -0.014 - bh, cz))
	for k in 3:
		var z := z0 - bw / 6.0 - k * bw / 3.0
		M.add(h, M.cyl_mesh(0.0, bw / 6.0, 0.05, 4), field, Vector3(0, -0.014 - bh - 0.025, z), Vector3(180, 45, 0), Vector3(0.2, 1, 1))
		if tier >= 2:
			M.sphere(h, 0.01, trim, Vector3(0, -0.014 - bh - 0.054, z), Vector3(1, 1.5, 1), 6)
	for sx: float in [-1.0, 1.0]:
		_horn_emblem(h, Vector3(0.007 * sx, -0.014 - bh * 0.48, cz), bh / 0.11, emb, PI * 0.5 * sx)
	# cordones del tubo a la banderola
	for z: float in [z0 - 0.005, z0 - bw + 0.005]:
		M.sphere(h, 0.012, trim, Vector3(0, -0.006, z), Vector3.ONE, 6)


# Pabellón (en _bell_node: +Y apunta hacia fuera del cuerno)
func _build_bell(b: Node3D) -> void:
	var br: float = BELL_R_BY_TIER[tier]
	if tier == 0:
		var ring0 := TorusMesh.new()
		ring0.inner_radius = br - 0.006
		ring0.outer_radius = br + 0.006
		ring0.rings = 20
		ring0.ring_segments = 6
		M.add(b, ring0, M.metal(BRASS), Vector3(0, -0.004, 0))
		return
	var body: Material = [null, M.metal(BRASS), M.metal(Color(0.93, 0.7, 0.3)), M.metal(GOLD_BRIGHT)][tier]
	var band: Material = [null, M.metal(BRASS_DARK), M.metal(GOLD), M.mat(ROYAL)][tier]
	M.cyl(b, br * 0.42, 0.012, 0.07, body, Vector3(0, -0.075, 0), Vector3.ZERO, 14)
	M.cyl(b, br, br * 0.42, 0.045, body, Vector3(0, -0.02, 0), Vector3.ZERO, 18)
	var ring := TorusMesh.new()
	ring.inner_radius = br - 0.004
	ring.outer_radius = br + 0.01
	ring.rings = 24
	ring.ring_segments = 6
	M.add(b, ring, band if tier >= 2 else body, Vector3(0, 0.0, 0))
	M.cyl(b, 0.018, 0.018, 0.016, band, Vector3(0, -0.105, 0), Vector3.ZERO, 10)
	if tier == 3:
		# corona de pétalos dorados y gemas azules en el borde
		for k in 8:
			var a := TAU * k / 8.0
			var d := Vector3(cos(a), 0, sin(a))
			M.sphere(b, 0.011, M.mat(ROYAL), d * (br + 0.004) + Vector3(0, -0.012, 0), Vector3.ONE, 6)
			var pet := M.add(b, M.cyl_mesh(0.0, 0.014, 0.04, 4), M.metal(GOLD), d * (br + 0.012) + Vector3(0, 0.01, 0), Vector3.ZERO, Vector3(1, 1, 0.4))
			pet.basis = Basis(Quaternion(Vector3.UP, (d + Vector3(0, 1.2, 0)).normalized())) * Basis.from_scale(Vector3(1, 1, 0.4))


# =====================================================================
# --- Estandarte ---
# =====================================================================

func _build_standard(s: Node3D) -> void:
	var top: float = POLE_TOP_BY_TIER[tier]
	var pole: Material = [M.tex_mat("wood", 2.0, Color(0.72, 0.54, 0.36)), M.tex_mat("wood", 2.0, Color(0.6, 0.4, 0.25)), M.mat(BLUE_DARK), M.mat(ROYAL)][tier]
	var metal: Material = [M.metal(IRON), M.metal(BRASS), M.metal(GOLD), M.metal(GOLD)][tier]
	var base := Vector3(POLE_X, 0, POLE_Z)
	M.cyl(s, 0.016, 0.018, top, pole, base + Vector3(0, top * 0.5, 0), Vector3.ZERO, 8)
	M.cyl(s, 0.02, 0.012, 0.05, metal, base + Vector3(0, 0.02, 0), Vector3.ZERO, 8)
	M.cyl(s, 0.022, 0.022, 0.07, M.mat(LEATHER), base + Vector3(0, GRIP_L_Y, 0), Vector3.ZERO, 8)
	if tier >= 2:
		# anillas doradas a lo largo del asta
		for y: float in [0.12, 0.5, 0.68, top - 0.02]:
			M.cyl(s, 0.021, 0.021, 0.02, metal, base + Vector3(0, y, 0), Vector3.ZERO, 8)
	var tp := base + Vector3(0, top, 0)
	match tier:
		0:
			# punta de lanza de hierro con cintas
			M.sphere(s, 0.022, metal, tp + Vector3(0, 0.01, 0), Vector3.ONE, 8)
			M.sphere(s, 0.026, metal, tp + Vector3(0, 0.07, 0), Vector3(0.8, 2.2, 0.35), 8)
			for k: float in [-1.0, 1.0]:
				M.segment(s, 0.007, M.mat(CREAM), tp + Vector3(0, 0.01, 0), tp + Vector3(0.03 * k, -0.12, 0.02), 4)
		1:
			M.sphere(s, 0.032, metal, tp + Vector3(0, 0.03, 0), Vector3.ONE, 10)
			M.cyl(s, 0.0, 0.014, 0.07, metal, tp + Vector3(0, 0.09, 0), Vector3.ZERO, 6)
			for k: float in [-1.0, 1.0]:
				M.segment(s, 0.007, M.mat(BLUE), tp + Vector3(0, 0.0, 0), tp + Vector3(0.025 * k, -0.13, 0.02), 4)
				M.sphere(s, 0.014, M.metal(GOLD), tp + Vector3(0.025 * k, -0.14, 0.02), Vector3(1, 1.5, 1), 6)
		_:
			# sol dorado con rayos (radiante en la Maestría)
			var sun: Material = metal if tier == 2 else M.mat(HOLY, 1.8)
			var c := tp + Vector3(0, 0.085, 0)
			M.cyl(s, 0.022, 0.03, 0.04, metal, tp + Vector3(0, 0.01, 0), Vector3.ZERO, 10)
			M.cyl(s, 0.045, 0.045, 0.022, sun, c, Vector3(90, 0, 0), 16)
			M.cyl(s, 0.03, 0.03, 0.03, M.mat(ROYAL) if tier == 3 else M.mat(BLUE), c, Vector3(90, 0, 0), 14)
			var nr := 12 if tier == 3 else 8
			for k in nr:
				var a := TAU * k / nr
				var ln := 0.05 if k % 2 == 0 else 0.032
				var ray := M.add(s, M.cyl_mesh(0.0, 0.012, ln, 4), metal, c + Vector3(cos(a), sin(a), 0) * (0.045 + ln * 0.5), Vector3.ZERO, Vector3(1, 1, 0.4))
				ray.rotation.z = a - PI * 0.5
			if tier == 3:
				M.sphere(s, 0.012, M.mat(HOLY, 2.2), c + Vector3(0, 0, 0.018), Vector3.ONE, 6)
				M.sphere(s, 0.012, M.mat(HOLY, 2.2), c + Vector3(0, 0, -0.018), Vector3.ONE, 6)
			# borlas doradas
			for k: float in [-1.0, 1.0]:
				M.segment(s, 0.006, metal, tp + Vector3(0, 0.0, 0), tp + Vector3(0.03 * k, -0.12, 0.02), 4)
				M.sphere(s, 0.016, metal, tp + Vector3(0.03 * k, -0.135, 0.02), Vector3(1, 1.6, 1), 6)


# Bandera del estandarte: tramos encadenados que ondean (cola de golondrina al final)
func _build_flag() -> void:
	var top: float = POLE_TOP_BY_TIER[tier]
	var field := M.mat([BLUE_PALE, BLUE, BLUE, ROYAL][tier])
	var trim: Material = [M.mat(CREAM), M.metal(GOLD), M.metal(GOLD), M.metal(GOLD_BRIGHT)][tier]
	var emb: Material = [M.mat(CREAM), M.metal(GOLD), M.metal(GOLD_BRIGHT), M.mat(GOLD_BRIGHT, 1.4)][tier]
	_flag_root = Node3D.new()
	_flag_root.position = Vector3(POLE_X - 0.014, top - 0.06, POLE_Z)
	_standard.add_child(_flag_root)
	var parent: Node3D = _flag_root
	var pos := Vector3.ZERO
	for i in FLAG_SEGS:
		var seg := Node3D.new()
		seg.position = pos
		parent.add_child(seg)
		_flag_segs.append(seg)
		var last := i == FLAG_SEGS - 1
		var ln := FLAG_SEG_LEN * (0.55 if last else 1.0)
		M.box(seg, Vector3(ln + 0.008, FLAG_H, 0.012), field, Vector3(-ln * 0.5, -FLAG_H * 0.5, 0))
		for y: float in [-0.01, -FLAG_H + 0.01]:
			M.box(seg, Vector3(ln + 0.008, 0.022, 0.017), trim, Vector3(-ln * 0.5, y, 0))
		if i == 0:
			M.box(seg, Vector3(0.018, FLAG_H, 0.017), trim, Vector3(-0.008, -FLAG_H * 0.5, 0))
		if last:
			for y: float in [-FLAG_H * 0.25, -FLAG_H * 0.75]:
				M.add(seg, M.cyl_mesh(0.0, FLAG_H * 0.25, 0.1, 4), field, Vector3(-ln - 0.05, y, 0), Vector3(0, 0, 90), Vector3(1, 1, 0.14))
		if i == 1:
			for z: float in [-0.008, 0.008]:
				_horn_emblem(seg, Vector3(-FLAG_SEG_LEN * 0.4, -FLAG_H * 0.48, z), 0.9, emb)
		parent = seg
		pos = Vector3(-ln, 0, 0)


# =====================================================================
# --- Heraldo ---
# =====================================================================

func _tunic_color() -> Color:
	return [BLUE_PALE, BLUE, BLUE_DARK, WHITE][tier]


func _build_man(c: Node3D) -> void:
	var tunic := M.mat(_tunic_color())
	var gold := M.metal(GOLD)
	var leather := M.mat(LEATHER)
	var blue := M.mat(BLUE)
	var royal := M.mat(ROYAL)
	var white := M.mat(WHITE)
	var trim: Material = [M.mat(CREAM), gold, gold, gold][tier]
	Human.body(c, tunic, trim)
	# Botas
	var boot: Material = leather if tier < 3 else M.mat(Color(0.22, 0.16, 0.12))
	for sx: float in [-1.0, 1.0]:
		M.cyl(c, 0.045, 0.05, 0.05, boot, Vector3(0.06 * sx, 0.01, -0.02), Vector3.ZERO, 8)
		M.sphere(c, 0.036, boot, Vector3(0.06 * sx, 0.012, -0.07), Vector3(1, 0.6, 1.4), 8)
	match tier:
		0:
			# esclavina parda con capucha caída
			var hood := M.mat(FELT)
			M.sphere(c, 0.17, hood, Vector3(0, 0.29, 0.0), Vector3(1.0, 0.42, 0.95), 14)
			M.sphere(c, 0.1, hood, Vector3(0, 0.33, 0.1), Vector3(1.2, 0.8, 0.9), 12)
			M.cyl(c, 0.172, 0.172, 0.012, M.mat(CREAM), Vector3(0, 0.235, 0), Vector3.ZERO, 16)
		1:
			_tabard(c, blue, M.mat(Color(0.96, 0.8, 0.3)), null, gold)
		2:
			_tabard(c, blue, blue, gold, M.metal(GOLD_BRIGHT))
			# capa corta azul oscuro con ribete dorado
			M.box(c, Vector3(0.28, 0.24, 0.02), M.mat(BLUE_DARK), Vector3(0, 0.17, 0.145), Vector3(9, 0, 0))
			M.box(c, Vector3(0.29, 0.022, 0.026), gold, Vector3(0, 0.05, 0.165), Vector3(9, 0, 0))
		_:
			_tabard(c, royal, white, gold, M.mat(GOLD_BRIGHT, 1.3))
			# hombreras doradas
			for sx: float in [-1.0, 1.0]:
				M.sphere(c, 0.07, gold, Vector3(0.135 * sx, 0.285, 0), Vector3(1, 0.6, 1), 10)
			# capa real larga con borde dorado y cuello de armiño
			M.box(c, Vector3(0.31, 0.38, 0.022), royal, Vector3(0, 0.12, 0.16), Vector3(10, 0, 0))
			M.box(c, Vector3(0.32, 0.026, 0.028), gold, Vector3(0, -0.06, 0.19), Vector3(10, 0, 0))
			for sx: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.022, 0.38, 0.028), gold, Vector3(0.15 * sx, 0.12, 0.165), Vector3(10, 0, 0))
			M.cyl(c, 0.11, 0.15, 0.06, white, Vector3(0, 0.33, 0.01), Vector3.ZERO, 16)
			for k in 7:
				var a := PI * 0.15 + PI * 0.7 * k / 6.0
				M.sphere(c, 0.01, M.mat(Color(0.08, 0.07, 0.07)), Vector3(cos(a) * 0.14, 0.33, sin(a) * 0.12 + 0.01), Vector3(0.6, 1.4, 0.6), 4)
	# Cinturón con hebilla y rollo de pregón al costado
	var belt := TorusMesh.new()
	belt.inner_radius = 0.13
	belt.outer_radius = 0.153
	M.add(c, belt, leather if tier < 3 else gold, Vector3(0, 0.08, 0))
	M.box(c, Vector3(0.04, 0.036, 0.02), gold if tier > 0 else M.metal(IRON), Vector3(0, 0.08, -0.152))
	M.cyl(c, 0.022, 0.022, 0.12, M.mat(CREAM), Vector3(0.15, 0.05, -0.05), Vector3(0, 0, 70), 8)
	M.sphere(c, 0.017, M.mat(RED), Vector3(0.15, 0.05, -0.074), Vector3(1, 1, 0.5), 6)
	if tier >= 1:
		M.segment(c, 0.006, M.mat(RED), Vector3(0.15, 0.05, -0.074), Vector3(0.152, 0.0, -0.08), 4)
	# Cabeza y tocado
	var hair_col: Color = [Human.HAIR, Color(0.5, 0.3, 0.16), Color(0.24, 0.16, 0.1), Color(0.86, 0.84, 0.8)][tier]
	var h := Human.head(c, true, true, hair_col)
	if tier >= 2:
		# bigote de heraldo
		for sx: float in [-1.0, 1.0]:
			M.sphere(h, 0.022, M.mat(hair_col), Vector3(0.026 * sx, -0.052, -0.13), Vector3(1.4, 0.55, 0.6), 8)
			M.sphere(h, 0.012, M.mat(hair_col), Vector3(0.052 * sx, -0.046, -0.122), Vector3(1, 0.8, 0.8), 6)
	match tier:
		0:
			# gorro de fieltro caído con pluma
			var felt := M.mat(Color(0.44, 0.3, 0.18))
			M.sphere(h, 0.14, felt, Vector3(0.0, 0.1, 0.02), Vector3(1.06, 0.55, 1.06), 14)
			M.sphere(h, 0.07, felt, Vector3(-0.07, 0.15, 0.08), Vector3(1.0, 0.7, 1.0), 10)
			M.cyl(h, 0.148, 0.148, 0.03, M.mat(Color(0.36, 0.24, 0.14)), Vector3(0, 0.075, 0.015), Vector3.ZERO, 16)
			M.box(h, Vector3(0.012, 0.16, 0.035), M.mat(CREAM), Vector3(0.1, 0.17, 0.07), Vector3(-30, 0, -22))
		1:
			# boina azul con banda dorada y pluma blanca
			M.sphere(h, 0.155, blue, Vector3(0.02, 0.11, 0.02), Vector3(1.1, 0.48, 1.1), 14)
			M.cyl(h, 0.15, 0.15, 0.025, gold, Vector3(0, 0.08, 0.01), Vector3.ZERO, 16)
			M.box(h, Vector3(0.014, 0.2, 0.04), white, Vector3(0.1, 0.19, 0.07), Vector3(-35, 0, -25))
			M.sphere(h, 0.018, M.mat(RED), Vector3(0.11, 0.1, -0.02), Vector3.ONE, 6)
		_:
			# sombrero de ala ancha con penacho (azul real y oro en la Maestría)
			var hat: Material = M.mat(BLUE_DARK) if tier == 2 else royal
			var brim := Node3D.new()
			brim.position = Vector3(0, 0.08, 0.01)
			brim.rotation_degrees = Vector3(8, 0, -6)
			h.add_child(brim)
			M.cyl(brim, 0.23, 0.23, 0.02, hat, Vector3.ZERO, Vector3.ZERO, 20)
			var edge := TorusMesh.new()
			edge.inner_radius = 0.222
			edge.outer_radius = 0.24
			edge.rings = 28
			edge.ring_segments = 6
			M.add(brim, edge, gold, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.6, 1))
			M.cyl(brim, 0.115, 0.135, 0.11, hat, Vector3(0, 0.06, 0), Vector3.ZERO, 16)
			M.cyl(brim, 0.137, 0.137, 0.028, gold, Vector3(0, 0.025, 0), Vector3.ZERO, 16)
			# penacho que cae hacia atrás
			var plume: Array[Material] = [white, blue if tier == 2 else M.metal(GOLD_BRIGHT), white]
			for k in 3:
				M.sphere(brim, 0.045 - k * 0.006, plume[k], Vector3(0.1 - k * 0.012, 0.1 + k * 0.012, -0.02 + k * 0.055), Vector3(0.6, 0.7, 1.8), 10)
			M.sphere(brim, 0.022, gold if tier == 2 else M.mat(HOLY, 1.8), Vector3(0.11, 0.07, -0.06), Vector3(1, 1, 0.6), 8)


## Tabardo heráldico: delante y detrás cuartelado (f1/f2), alas sobre los hombros y emblema
func _tabard(c: Node3D, f1: Material, f2: Material, border: Material, emblem: Material) -> void:
	for sd: float in [-1.0, 1.0]:
		var a := f1 if sd < 0.0 else f2
		var b := f2 if sd < 0.0 else f1
		M.box(c, Vector3(0.095, 0.28, 0.02), a, Vector3(0.0475 * sd, 0.135, -0.124), Vector3(-4, 0, 0))
		M.box(c, Vector3(0.095, 0.28, 0.02), b, Vector3(0.0475 * sd, 0.135, 0.124), Vector3(4, 0, 0))
		# alas del tabardo sobre los hombros
		M.box(c, Vector3(0.07, 0.09, 0.14), b, Vector3(0.15 * sd, 0.245, 0), Vector3(0, 0, -18.0 * sd))
		if border != null:
			M.box(c, Vector3(0.074, 0.014, 0.144), border, Vector3(0.162 * sd, 0.2, 0), Vector3(0, 0, -18.0 * sd))
	if border != null:
		for sz: float in [-1.0, 1.0]:
			M.box(c, Vector3(0.2, 0.018, 0.026), border, Vector3(0, 0.0, 0.126 * sz), Vector3(4.0 * sz, 0, 0))
			for sx: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.014, 0.28, 0.026), border, Vector3(0.094 * sx, 0.135, 0.125 * sz), Vector3(4.0 * sz, 0, 0))
	# cuerno bordado en el pecho y en la espalda
	_horn_emblem(c, Vector3(0, 0.15, -0.14), 1.05, emblem, PI)
	_horn_emblem(c, Vector3(0, 0.15, 0.14), 1.05, emblem)


func _build_moving_parts() -> void:
	var sleeve := M.mat(_tunic_color() if tier < 3 else ROYAL)
	_arm_l = M.add(_man, M.tube_mesh(0.04, 8), sleeve)
	_arm_r = M.add(_man, M.tube_mesh(0.04, 8), sleeve)
	var glove: Material = M.mat(Human.SKIN) if tier < 2 else M.mat(WHITE)
	_hand_l = M.sphere(_man, 0.04, glove, Vector3.ZERO, Vector3(1, 1.1, 0.9), 8)
	_hand_r = M.sphere(_man, 0.04, glove, Vector3.ZERO, Vector3(1, 1.1, 0.9), 8)
	# mofletes (se hinchan al soplar)
	for sx: float in [-1.0, 1.0]:
		var ch := M.sphere(_man, 0.036, M.mat(Color(0.96, 0.7, 0.62)), Human.HEAD + Vector3(0.058 * sx, -0.058, -0.095), Vector3.ONE, 10)
		_cheeks.append(ch)


# =====================================================================
# --- Torre (estática) ---
# =====================================================================

func _build_tower(p: Node3D) -> void:
	match tier:
		0: _tower_t0(p)
		1: _tower_t1(p)
		_: _tower_grand(p, tier == 3)


# Etapa 0: cabaña de tablones con plataforma, poste de banderola y tablón de pregones
func _tower_t0(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[0]
	var bark := M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36))
	var bark2 := M.tex_mat("wood", 2.5, Color(0.58, 0.43, 0.3))
	var dark := M.mat(Color(0.4, 0.26, 0.15))
	var plank := M.tex_mat("wood", 2.0, Color(0.88, 0.74, 0.55))
	var plank2 := M.tex_mat("wood", 2.0, Color(0.76, 0.6, 0.43))
	var rope := M.mat(ROPE)
	var stone := M.mat(Color(0.6, 0.58, 0.55))
	var cloth := M.mat(BLUE_PALE)
	var cream := M.mat(CREAM)
	var iron := M.metal(IRON)
	M.cyl(p, 0.46, 0.47, 0.03, M.mat(Color(0.52, 0.4, 0.27)), Vector3(0, 0.015, 0), Vector3.ZERO, 18)
	var half := 0.29
	M.box(p, Vector3(2.0 * half - 0.04, py - 0.08, 2.0 * half - 0.04), dark, Vector3(0, (py - 0.08) * 0.5 + 0.03, 0))
	# paredes de tablas verticales con travesaños
	for face: Vector3 in _faces():
		var tg := Vector3(face.z, 0, face.x)
		var n := 7
		for k in n:
			var o := -half + (k + 0.5) * 2.0 * half / n
			var hh := py - 0.07 - (k % 3) * 0.012
			var sz := tg.abs() * (2.0 * half / n - 0.006) + Vector3(0, hh, 0) + face.abs() * 0.03
			M.box(p, sz, plank if k % 2 == 0 else plank2, face * half + tg * o + Vector3(0, 0.03 + hh * 0.5, 0))
		for y: float in [0.13, py - 0.15]:
			M.box(p, tg.abs() * (2.0 * half + 0.02) + Vector3(0, 0.04, 0) + face.abs() * 0.03, dark, face * (half + 0.025) + Vector3(0, y, 0))
	# postes de esquina (el trasero izquierdo sube para la banderola)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var cp := Vector3(0.305 * sx, 0, 0.305 * sz)
			var tall := py + (0.36 if sx < 0.0 and sz < 0.0 else 0.15)
			M.sphere(p, 0.065, stone, cp + Vector3(0, 0.03, 0), Vector3(1.2, 0.6, 1.2), 8)
			M.cyl(p, 0.04, 0.046, tall, bark, cp + Vector3(0, tall * 0.5, 0), Vector3.ZERO, 8)
			M.cyl(p, 0.0, 0.04, 0.06, dark, cp + Vector3(0, tall + 0.03, 0), Vector3.ZERO, 8)
			M.cyl(p, 0.05, 0.05, 0.025, rope, cp + Vector3(0, py - 0.1, 0), Vector3.ZERO, 8)
	# vigas y tablones de la plataforma
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.84, 0.05, 0.06), dark, Vector3(0, py - 0.07, 0.33 * s))
	for k in 8:
		M.box(p, Vector3(0.8 + (k % 3) * 0.02, 0.04, 0.1), plank if k % 2 == 0 else plank2, Vector3((k % 2) * 0.012, py - 0.02, -0.365 + k * 0.104), Vector3(0, (k % 3 - 1) * 2.0, 0))
	# barandilla de palos con cuerda
	for face: Vector3 in _faces():
		var tg := Vector3(face.z, 0, face.x)
		for o: float in [-0.15, 0.15]:
			M.cyl(p, 0.016, 0.018, 0.13, bark2, face * 0.38 + tg * o + Vector3(0, py + 0.065, 0), Vector3.ZERO, 6)
		M.box(p, tg.abs() * 0.68 + Vector3(0, 0.022, 0) + face.abs() * 0.022, dark, face * 0.38 + Vector3(0, py + 0.12, 0))
	# alfombra azul en el suelo de la plataforma
	M.box(p, Vector3(0.36, 0.012, 0.36), cloth, Vector3(0, py + 0.006, 0), Vector3(0, 45, 0))
	M.box(p, Vector3(0.3, 0.014, 0.3), cream, Vector3(0, py + 0.007, 0), Vector3(0, 45, 0))
	M.box(p, Vector3(0.26, 0.016, 0.26), cloth, Vector3(0, py + 0.008, 0), Vector3(0, 45, 0))
	# estandarte azul en la cara -Z y otro en la +X
	_banner(p, Vector3(0, py - 0.1, -(half + 0.035)), PI, 0.2, 0.28, cloth, cream, cream)
	_banner(p, Vector3(half + 0.035, py - 0.1, 0.04), PI * 0.5, 0.17, 0.24, cloth, cream, cream)
	# puerta de tablones en +Z
	var g := Node3D.new()
	g.position = Vector3(0, 0, half + 0.02)
	p.add_child(g)
	M.box(g, Vector3(0.2, 0.3, 0.03), dark, Vector3(0, 0.18, 0))
	M.box(g, Vector3(0.16, 0.27, 0.03), plank2, Vector3(0, 0.17, 0.008))
	for y: float in [0.1, 0.24]:
		M.box(g, Vector3(0.15, 0.018, 0.01), iron, Vector3(0, y, 0.026))
	M.sphere(g, 0.013, iron, Vector3(0.05, 0.17, 0.03), Vector3.ONE, 6)
	# tablón de pregones en la cara -X (papeles clavados con lacre rojo)
	var nb := Node3D.new()
	nb.position = Vector3(-(half + 0.03), 0, 0)
	nb.rotation.y = -PI * 0.5
	p.add_child(nb)
	M.box(nb, Vector3(0.26, 0.2, 0.02), dark, Vector3(0, 0.3, 0))
	M.box(nb, Vector3(0.3, 0.03, 0.04), bark, Vector3(0, 0.415, 0.01))
	var papers := [Vector3(-0.07, 0.31, 0), Vector3(0.05, 0.33, 0), Vector3(0.07, 0.25, 0), Vector3(-0.04, 0.24, 0)]
	for i in papers.size():
		var pp: Vector3 = papers[i]
		M.box(nb, Vector3(0.08, 0.09, 0.008), cream, pp + Vector3(0, 0, 0.013), Vector3(0, 0, (i % 3 - 1) * 7.0))
		M.sphere(nb, 0.01, M.mat(RED), pp + Vector3(0, 0.03, 0.018), Vector3(1, 1, 0.5), 6)
	# escalera de mano en el lado +X
	for sz: float in [-1.0, 1.0]:
		M.segment(p, 0.016, bark, Vector3(0.44, 0.0, -0.17 + 0.07 * sz), Vector3(0.38, py + 0.04, -0.17 + 0.07 * sz), 6)
	for k in 4:
		var f := (k + 0.6) / 4.5
		M.box(p, Vector3(0.022, 0.02, 0.16), dark, Vector3(lerpf(0.44, 0.38, f), f * (py + 0.04), -0.17))
	# tambor de pregonero en una esquina de la plataforma
	_drum(p, Vector3(0.24, py, 0.24), 0.06, 0.09, M.tex_mat("wood", 2.0, Color(0.7, 0.42, 0.28)), M.mat(CREAM), M.mat(BLUE_PALE), rope, dark)
	Arch._ground_details(p, false)


# Etapa 1: torre de sillares almenada con estandartes azules, tambor y brasero
func _tower_t1(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[1]
	var half := 0.33
	var wall := M.tex_mat("bricks", 2.2, Color(0.84, 0.82, 0.77))
	var stones: Array[Material] = [M.mat(Color(0.64, 0.62, 0.58)), M.mat(Color(0.56, 0.54, 0.5)), M.mat(Color(0.7, 0.68, 0.64))]
	var dark := M.mat(STONE_DARK)
	var iron := M.metal(IRON)
	var blue := M.mat(BLUE)
	var gold := M.metal(GOLD)
	_shaft(p, py, half, wall, stones, dark, stones[2])
	# estandartes en tres caras
	for face: Vector3 in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		_banner(p, face * (half + 0.03) + Vector3(0, py - 0.12, 0), atan2(face.x, face.z), 0.2, 0.36, blue, gold, gold)
	# puerta y antorcha en +Z
	Arch._door(p, half + 0.005, stones[2], M.tex_mat("wood", 2.0, Color(0.62, 0.48, 0.38)), iron)
	M.box(p, Vector3(0.28, 0.04, 0.14), stones[0], Vector3(0, 0.02, half + 0.1))
	Arch.wall_torch(p, Vector3(0.2, 0.34, half), Vector3(0, 0, 1), iron)
	# parapeto almenado
	Arch.parapet(p, half + 0.03, py + 0.04, 0.06, 0.05, wall)
	Arch.merlons(p, half + 0.03, py + 0.1, Vector3(0.08, 0.07, 0.08), 3, wall, stones[2])
	# medallón, tambor, brasero y asta de la banderola
	_medallion(p, py, 0.24, M.mat(BLUE), gold, gold)
	_drum(p, Vector3(0.22, py, 0.22), 0.065, 0.1, M.mat(Color(0.62, 0.2, 0.16)), M.mat(CREAM), gold, M.mat(ROPE), M.mat(TIMBER))
	_brazier(p, Vector3(-0.22, py, 0.22), iron, M.mat(EMBER, 1.6))
	M.cyl(p, 0.009, 0.009, 0.34, iron, Vector3(-(half + 0.03), py + 0.3, -(half + 0.03)), Vector3.ZERO, 6)
	M.sphere(p, 0.016, gold, Vector3(-(half + 0.03), py + 0.48, -(half + 0.03)), Vector3.ONE, 6)
	Arch._ground_details(p, false)


# Etapas 2 y 3: gran torre con contrafuertes, torreones, timbales y braseros
func _tower_grand(p: Node3D, master: bool) -> void:
	var py: float = PLAT_BY_TIER[tier]
	var half := 0.35
	var wall: Material
	var stones: Array[Material] = []
	var dark: Material
	var floor_m: Material
	var roof: Material
	var gold := M.metal(GOLD)
	var iron := M.metal(IRON)
	var field: Material
	var emblem: Material
	var metal: Material
	if master:
		wall = M.tex_mat("bricks", 2.2, MARBLE)
		stones = [M.mat(Color(0.93, 0.91, 0.86)), M.mat(Color(0.86, 0.84, 0.8)), M.mat(Color(1.0, 0.98, 0.94))]
		dark = M.mat(Color(0.74, 0.72, 0.68))
		floor_m = stones[2]
		roof = M.tex_mat("roof", 3.0, Color(0.42, 0.55, 0.95))
		field = M.mat(ROYAL)
		emblem = M.mat(GOLD_BRIGHT, 1.3)
		metal = gold
	else:
		wall = M.tex_mat("bricks", 2.2, Color(0.88, 0.85, 0.78))
		stones = [M.mat(Color(0.66, 0.64, 0.6)), M.mat(Color(0.57, 0.55, 0.51)), M.mat(Color(0.74, 0.72, 0.68))]
		dark = M.mat(STONE_DARK)
		floor_m = stones[2]
		roof = M.tex_mat("roof", 3.0, Color(0.36, 0.48, 0.86))
		field = M.mat(BLUE)
		emblem = M.metal(GOLD_BRIGHT)
		metal = iron
	_shaft(p, py, half, wall, stones, dark, floor_m)
	# contrafuertes en talud
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(p, Vector3(0.1, 0.36, 0.1), stones[2] if master else stones[1], Vector3((half + 0.01) * sx, 0.26, (half + 0.01) * sz))
			M.cyl(p, 0.0, 0.075, 0.08, gold if master else stones[2], Vector3((half + 0.01) * sx, 0.48, (half + 0.01) * sz), Vector3(0, 45, 0), 4)
	# bandas doradas
	for y: float in ([0.155, 0.36] if master else [0.2]):
		M.box(p, Vector3(2.0 * half + 0.03, 0.022, 2.0 * half + 0.03), gold, Vector3(0, y, 0))
	if master:
		M.box(p, Vector3(2.0 * half + 0.16, 0.02, 2.0 * half + 0.16), gold, Vector3(0, py - 0.05, 0))
	# grandes estandartes en tres caras
	for face: Vector3 in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		_banner(p, face * (half + 0.03) + Vector3(0, py - 0.12, 0), atan2(face.x, face.z), 0.24, 0.44, field, gold, emblem)
		if master:
			# joya brillante en la vara del estandarte y lámpara dorada bajo él
			var g := Node3D.new()
			g.position = face * (half + 0.03)
			g.rotation.y = atan2(face.x, face.z)
			p.add_child(g)
			M.cyl(g, 0.03, 0.03, 0.026, gold, Vector3(0, py - 0.12, 0.03), Vector3(90, 0, 0), 14)
			M.cyl(g, 0.019, 0.019, 0.03, M.mat(HOLY, 1.6), Vector3(0, py - 0.12, 0.034), Vector3(90, 0, 0), 12)
			for sx: float in [-1.0, 1.0]:
				M.sphere(g, 0.016, M.mat(HOLY, 1.6), Vector3(0.17 * sx, py - 0.2, 0.0), Vector3.ONE, 8)
				M.cyl(g, 0.02, 0.012, 0.03, gold, Vector3(0.17 * sx, py - 0.225, 0.0), Vector3.ZERO, 8)
	# puerta, escalinata y antorchas en +Z
	Arch._door(p, half + 0.005, gold if master else stones[2], M.mat(ROYAL) if master else M.tex_mat("wood", 2.0, Color(0.62, 0.48, 0.38)), gold if master else iron)
	M.box(p, Vector3(0.3, 0.04, 0.15), stones[2] if master else stones[0], Vector3(0, 0.02, half + 0.1))
	for sx: float in [-1.0, 1.0]:
		Arch.wall_torch(p, Vector3(0.22 * sx, 0.36, half + 0.02), Vector3(0, 0, 1), gold if master else iron)
	# parapeto: balaustrada de mármol con pasamanos de oro, o muro almenado
	if master:
		for face: Vector3 in _faces():
			var tg := Vector3(face.z, 0, face.x)
			for k in 5:
				var o := -0.2 + k * 0.1
				M.cyl(p, 0.016, 0.02, 0.08, stones[2], face * (half + 0.04) + tg * o + Vector3(0, py + 0.04, 0), Vector3.ZERO, 8)
			M.box(p, tg.abs() * (2.0 * half + 0.1) + Vector3(0, 0.025, 0) + face.abs() * 0.05, gold, face * (half + 0.04) + Vector3(0, py + 0.09, 0))
	else:
		Arch.parapet(p, half + 0.04, py + 0.05, 0.07, 0.05, wall)
		for face: Vector3 in _faces():
			var tg := Vector3(face.z, 0, face.x)
			for o: float in [-0.12, 0.12]:
				M.box(p, tg.abs() * 0.08 + Vector3(0, 0.07, 0) + face.abs() * 0.07, wall, face * (half + 0.04) + tg * o + Vector3(0, py + 0.12, 0))
	# torreones de esquina con tejado azul
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Arch.turret(p, Vector3(0.35 * sx, 0, 0.35 * sz), 0.075, py - 0.2, py + 0.17, wall, roof, 0.2, gold, gold)
	# medallón, timbales con gualdrapa y braseros
	_medallion(p, py, 0.25, M.mat(ROYAL) if master else M.mat(BLUE), gold, M.metal(GOLD_BRIGHT) if master else gold)
	for sx: float in [-1.0, 1.0]:
		var kp := Vector3(0.21 * sx, py, 0.18)
		_kettle(p, kp, 0.07, Vector3(0.5 * sx, 0, 0.86), M.metal(GOLD) if master else M.metal(Color(0.78, 0.5, 0.26)),
				M.mat(CREAM), gold if master else iron, field, gold, emblem)
		_brazier(p, Vector3(0.21 * sx, py, -0.19), metal, M.mat(Color(1.0, 0.7, 0.3) if master else EMBER, 1.8))
	Arch._ground_details(p, false)


# =====================================================================
# --- Efectos por etapa ---
# =====================================================================

func _build_tier_fx() -> void:
	var py: float = PLAT_BY_TIER[tier]
	# Ondas de sonido del cuerno
	_wave_mat = StandardMaterial3D.new()
	_wave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wave_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wave_mat.albedo_color = Color(HOLY.r, HOLY.g, HOLY.b, 0.0)
	var wave := TorusMesh.new()
	wave.inner_radius = 0.06
	wave.outer_radius = 0.075
	wave.rings = 24
	wave.ring_segments = 6
	for i in 3:
		var w := M.add(_bell_node, wave, _wave_mat, Vector3(0, 0.02, 0))
		w.visible = false
		_waves.append(w)
	# Anillos de inspiración a ras de la plataforma (se ven bien desde arriba)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring_mat.albedo_color = Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.34
	ring.outer_radius = 0.375
	ring.rings = 40
	ring.ring_segments = 6
	for i in 2:
		var r := M.add(self, ring, _ring_mat, Vector3(0, py + 0.04, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
		r.visible = false
		_rings.append(r)
	match tier:
		0:
			_pennants.append(Arch.pennant_node(self, Vector3(-0.305, py + 0.36, -0.305), BLUE_PALE, CREAM, 0.22, 0.4))
		1:
			_flames.append(Arch.flame_node(self, Vector3(0.2, 0.39, 0.33 + 0.075)))
			_flames.append(Arch.flame_node(self, Vector3(-0.22, py + 0.17, 0.22), 0.9))
			_pennants.append(Arch.pennant_node(self, Vector3(-0.36, py + 0.46, -0.36), BLUE, GOLD, 0.24, 0.4))
		_:
			var master := tier == 3
			var fc := Color(1.0, 0.82, 0.4) if master else Color(1.0, 0.6, 0.15)
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.22 * sx, 0.41, 0.37 + 0.075), 1.0, fc))
				_flames.append(Arch.flame_node(self, Vector3(0.21 * sx, py + 0.17, -0.19), 1.1, fc))
				_pennants.append(Arch.pennant_node(self, Vector3(0.35 * sx, py + 0.43, -0.35), ROYAL if master else BLUE, GOLD, 0.26, 0.4 if sx < 0.0 else 2.7))
			if master:
				_spinners.append(Arch.aura_ring(self, 0.47, HOLY, 0.12))
				add_child(Arch.sparkles(Color(1.0, 0.88, 0.5), Vector3(0, py + 0.6, 0), Vector3(0.42, 0.5, 0.42), 22, 0.012))
				# estrellas de oro que flotan alrededor
				for k in 3:
					var a := TAU * k / 3.0 + 0.5
					var f := Node3D.new()
					var bp := Vector3(cos(a) * 0.44, py + 0.5 + k * 0.1, sin(a) * 0.44)
					f.position = bp
					f.set_meta("base", bp)
					add_child(f)
					M.cyl(f, 0.0, 0.03, 0.05, M.metal(GOLD), Vector3(0, 0.025, 0), Vector3.ZERO, 4)
					M.cyl(f, 0.03, 0.0, 0.05, M.metal(GOLD), Vector3(0, -0.025, 0), Vector3.ZERO, 4)
					M.sphere(f, 0.018, M.mat(HOLY, 2.0), Vector3.ZERO, Vector3.ONE, 8)
					_floaters.append(f)
	if tier >= 2:
		_light = OmniLight3D.new()
		_light.light_color = HOLY
		_light.omni_range = 0.9 if tier == 2 else 1.2
		_light.shadow_enabled = false
		_light.position = Vector3(0, 0.5, -0.25)
		cat_pivot.add_child(_light)
