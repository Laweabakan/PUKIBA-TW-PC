extends Node3D
## Modelo 3D del "Cuartel de Lanceros" (id pikes): cuartel fortificado con puerta de dos hojas,
## cobertizos con armeros llenos de picas, caballos de frisa y estandartes con dos picas cruzadas.
## Arriba, un piquero con cota de malla y capacete de ala (chapel de hierro) que embiste con una
## pica larga: al disparar la pica sale disparada hacia delante y vuelve. Mira hacia -Z dentro de cat_pivot.
## Etapas: 0 empalizada de troncos, 1 cuartel de piedra reforzado, 2 gran cuartel con torreones,
## 3 (Maestría) cuartel de mármol, oro y azul real con detalles brillantes.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const Arch := preload("res://scripts/towers3d/archer_model.gd")

const STONE_DARK := Color(0.42, 0.4, 0.38)
const TIMBER := Color(0.3, 0.19, 0.11)
const IRON := Color(0.26, 0.26, 0.29)
const STEEL := Color(0.5, 0.52, 0.57)
const MAIL := Color(0.43, 0.45, 0.49)
const BLUE := Color(0.2, 0.32, 0.62)
const YELLOW := Color(0.96, 0.8, 0.28)
const RED := Color(0.74, 0.15, 0.12)
const CREAM := Color(0.95, 0.91, 0.8)
const GOLD := Color(0.97, 0.76, 0.26)
const ROYAL := Color(0.14, 0.24, 0.66)
const MARBLE := Color(0.97, 0.95, 0.9)
const LEATHER := Color(0.36, 0.22, 0.12)
const ASH := Color(0.66, 0.5, 0.32)
const GLOW := Color(0.62, 0.86, 1.0)

const PLAT_BY_TIER := [0.72, 0.9, 1.08, 1.26]
# Pica (coordenadas de _pike): el puño en el origen, la punta hacia -Z
const PIKE_POS := Vector3(0.075, 0.22, -0.03)
const FRONT_GRIP := -0.17
const REAR_GRIP := 0.13
const BUTT_Z := 0.36
const HEAD_BASE := -0.6
const TIP_Z := -0.84
const THRUST := 0.26
const AIM_LOW := -0.1     # pica bajada en posición de ataque
const AIM_REST := 1.2     # pica casi vertical en descanso

var cat_pivot: Node3D
var _pike: Node3D
var _man: Node3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _hand_l: MeshInstance3D
var _hand_r: MeshInstance3D
var tier := 0
var _aim := AIM_REST
var _snap := true
var _flames: Array[Node3D] = []
var _pennants: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _floaters: Array[Node3D] = []


func _init(level := 0) -> void:
	tier = Arch.tier_of(level)
	M.add_baked(self, M.baked("pikes_tower_t%d" % tier, _build_tower))
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, PLAT_BY_TIER[tier], 0)
	add_child(cat_pivot)
	_man = Node3D.new()
	cat_pivot.add_child(_man)
	M.add_baked(_man, M.baked("pikes_man_t%d" % tier, _build_man))
	_pike = Node3D.new()
	_pike.position = PIKE_POS
	cat_pivot.add_child(_pike)
	M.add_baked(_pike, M.baked("pikes_weapon_t%d" % tier, _build_weapon))
	_build_arms()
	_build_tier_fx()
	animate({"t": 0.0, "charge": 0.0, "fire": 0.0, "has_target": false})
	_snap = true  # la primera pose real se aplica sin transición


## s = {t, charge (0..1), fire (1 -> 0), has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = s.get("charge", 0.0)
	var fire: float = s.get("fire", 0.0)
	var has_target: bool = s.get("has_target", false)
	# Baja la pica al ver un objetivo y la alza (casi vertical) en descanso
	var goal := AIM_LOW if has_target else AIM_REST
	if _snap:
		_aim = goal
		_snap = false
	else:
		_aim = lerpf(_aim, goal, 0.25)
	# Embestida: la pica sale de golpe (fire = 1) y vuelve poco a poco; antes, se echa atrás al cargar
	var ext := smoothstep(0.0, 1.0, fire) if fire > 0.0 else 0.0
	var wind := charge * 0.08 if has_target and ext <= 0.0 else 0.0
	_pike.rotation = Vector3(_aim - ext * 0.06, 0, 0)
	_pike.position = PIKE_POS + _pike.basis.z * (wind - ext * THRUST) + Vector3(0, -ext * 0.02, 0)
	# El piquero se inclina hacia delante al embestir y respira en reposo
	_man.position = Vector3(0, absf(sin(t * 1.4)) * 0.005, -ext * 0.07 + wind * 0.4)
	_man.rotation.x = -ext * 0.2 + wind * 0.6
	# Manos sobre el asta y brazos desde los hombros
	var front := _pike.transform * Vector3(0, 0, FRONT_GRIP)
	var rear := _pike.transform * Vector3(0, 0, REAR_GRIP)
	_hand_l.position = front
	_hand_r.position = rear
	M.orient_segment(_arm_l, _man.transform * Human.L_SHOULDER, front)
	M.orient_segment(_arm_r, _man.transform * Human.R_SHOULDER, rear)
	# Antorchas, banderolas y aura de la etapa
	Arch.animate_fx(t, _flames, _pennants, _spinners, _floaters)


## Punta de la pica (posición global)
func muzzle_global() -> Vector3:
	return _pike.to_global(Vector3(0, 0, TIP_Z))


# =====================================================================
# --- Piezas comunes ---
# =====================================================================

# Pica estática: asta de a (regatón) a b (cubo de la moharra) y hoja en forma de hoja de laurel
static func pike_static(p: Node3D, a: Vector3, b: Vector3, r: float, shaft: Material, head: Material, tassel: Material = null, hs := 1.0) -> void:
	M.segment(p, r, shaft, a, b, 6)
	var d := (b - a).normalized()
	var n := Node3D.new()
	n.position = b
	n.basis = Basis(Quaternion(Vector3.UP, d))
	p.add_child(n)
	M.cyl(n, r * 1.1, r * 1.5, 0.035 * hs, head, Vector3.ZERO, Vector3.ZERO, 6)
	M.sphere(n, 0.026 * hs, head, Vector3(0, 0.065 * hs, 0), Vector3(1.0, 2.6, 0.35), 8)
	M.cyl(n, 0.0, 0.011 * hs, 0.045 * hs, head, Vector3(0, 0.15 * hs, 0), Vector3.ZERO, 4)
	if tassel != null:
		M.sphere(n, 0.017 * hs, tassel, Vector3(0, -0.035 * hs, 0), Vector3(1, 1.5, 1), 6)


# Estaca afilada de a a b (la punta en b)
static func stake(p: Node3D, a: Vector3, b: Vector3, r: float, m: Material, tip: Material) -> void:
	M.segment(p, r, m, a, b, 6)
	var d := (b - a).normalized()
	var n := Node3D.new()
	n.position = b
	n.basis = Basis(Quaternion(Vector3.UP, d))
	p.add_child(n)
	M.cyl(n, 0.0, r, r * 2.4, tip, Vector3(0, r * 1.2, 0), Vector3.ZERO, 6)


# Dos picas cruzadas en el plano XY (mirando a +Z del nodo), centradas en c
static func crossed_pikes(n: Node3D, c: Vector3, s: float, shaft: Material, head: Material) -> void:
	for k: float in [-1.0, 1.0]:
		pike_static(n, c + Vector3(-0.09 * k, -0.12, 0) * s, c + Vector3(0.07 * k, 0.09, 0) * s, 0.009 * s, shaft, head, null, 1.25 * s)


# Nodo girado para que su +Z mire hacia `out` (para construir las caras con un único código)
static func side(p: Node3D, out: Vector3, dist: float, y := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = out * dist + Vector3(0, y, 0)
	n.rotation.y = atan2(out.x, out.z)
	p.add_child(n)
	return n


# Armero de picas (en el marco de `side`: la pared queda hacia -Z)
static func rack(n: Node3D, z: float, w: float, count: int, h: float, frame: Material, shaft: Material, head: Material, tassel: Material = null) -> void:
	for s: float in [-1.0, 1.0]:
		M.box(n, Vector3(0.03, 0.42, 0.03), frame, Vector3(w * 0.5 * s, 0.21, z))
		M.cyl(n, 0.0, 0.022, 0.04, frame, Vector3(w * 0.5 * s, 0.44, z), Vector3(0, 45, 0), 4)
	M.box(n, Vector3(w + 0.06, 0.028, 0.03), frame, Vector3(0, 0.34, z))
	M.box(n, Vector3(w + 0.04, 0.035, 0.07), frame, Vector3(0, 0.05, z + 0.01))
	for k in count:
		var o := -w * 0.5 + 0.04 + (w - 0.08) * k / maxf(count - 1, 1)
		pike_static(n, Vector3(o, 0.05, z + 0.03), Vector3(o + 0.006 * (k % 2), h, z - 0.035), 0.009, shaft, head, tassel, 0.8)


# Cobertizo de una sola agua que cubre el armero (marco de `side`)
static func shed(n: Node3D, w: float, d: float, y_top: float, y_low: float, post: Material, roof: Material) -> void:
	for s: float in [-1.0, 1.0]:
		M.box(n, Vector3(0.035, y_low, 0.035), post, Vector3(w * 0.5 * s, y_low * 0.5, d))
		M.segment(n, 0.012, post, Vector3(w * 0.5 * s, y_low - 0.12, d), Vector3(w * 0.5 * s, y_low + 0.02, d - 0.1), 4)
	M.box(n, Vector3(w + 0.04, 0.03, 0.035), post, Vector3(0, y_low, d))
	var ang := atan2(y_top - y_low, d)
	var slope := sqrt(d * d + (y_top - y_low) * (y_top - y_low)) + 0.06
	M.box(n, Vector3(w + 0.08, 0.03, slope), roof, Vector3(0, (y_top + y_low) * 0.5 + 0.03, d * 0.5), Vector3(rad_to_deg(ang), 0, 0))


# Caballo de frisa: tronco horizontal atravesado por estacas en aspa (marco de `side`)
static func cheval(n: Node3D, z: float, length: float, log_m: Material, stake_m: Material, tip_m: Material) -> void:
	M.cyl(n, 0.028, 0.028, length, log_m, Vector3(0, 0.075, z), Vector3(0, 0, 90), 8)
	var count := int(length / 0.12)
	for k in count + 1:
		var x := -length * 0.5 + 0.03 + (length - 0.06) * k / count
		var sgn := 1.0 if k % 2 == 0 else -1.0
		stake(n, Vector3(x, 0.0, z - 0.06 * sgn), Vector3(x, 0.17, z + 0.055 * sgn), 0.012, stake_m, tip_m)
		stake(n, Vector3(x, 0.0, z + 0.06 * sgn), Vector3(x, 0.17, z - 0.055 * sgn), 0.012, stake_m, tip_m)


# Puerta de dos hojas con herrajes, clavos y aldabas, centrada en x = 0, en la cara z (mira a +Z)
static func double_gate(p: Node3D, z: float, w: float, h: float, y0: float, arched: bool, wood: Material, seam: Material, iron: Material, gap: Material) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.011
	ring.outer_radius = 0.018
	ring.rings = 12
	ring.ring_segments = 6
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(w * 0.5 - 0.006, h, 0.03), wood, Vector3(s * w * 0.25, y0 + h * 0.5, z))
		for k in 2:
			M.box(p, Vector3(0.006, h - 0.02, 0.008), seam, Vector3(s * w * (k + 1) / 6.0, y0 + h * 0.5, z + 0.016))
		for y: float in [h * 0.2, h * 0.72]:
			M.box(p, Vector3(w * 0.5 - 0.02, 0.022, 0.01), iron, Vector3(s * w * 0.25, y0 + y, z + 0.02))
			for j in 3:
				M.sphere(p, 0.008, iron, Vector3(s * w * (0.07 + 0.14 * j), y0 + y, z + 0.026), Vector3.ONE, 6)
		M.add(p, ring, iron, Vector3(s * 0.03, y0 + h * 0.46, z + 0.03), Vector3(90, 0, 0))
	M.box(p, Vector3(0.008, h, 0.034), gap, Vector3(0, y0 + h * 0.5, z + 0.002))
	if arched:
		M.cyl(p, w * 0.5, w * 0.5, 0.03, wood, Vector3(0, y0 + h, z - 0.004), Vector3(90, 0, 0), 18)
		M.box(p, Vector3(0.008, w * 0.5, 0.03), gap, Vector3(0, y0 + h + w * 0.25, z - 0.001))
		M.box(p, Vector3(w * 0.8, 0.02, 0.01), iron, Vector3(0, y0 + h + w * 0.18, z + 0.012))


# Arco de dovelas alrededor de una puerta arqueada
static func voussoirs(p: Node3D, z: float, r: float, cy: float, stones: Array[Material], jambs: bool, y0: float) -> void:
	for k in 9:
		var a := PI * k / 8.0
		M.box(p, Vector3(0.05, 0.042, 0.04), stones[k % stones.size()], Vector3(cos(a) * r, cy + sin(a) * r, z), Vector3(0, 0, rad_to_deg(a) + 90.0))
	if jambs:
		var y := y0 + 0.035
		var k := 0
		while y < cy:
			for s: float in [-1.0, 1.0]:
				M.box(p, Vector3(0.05 if k % 2 == 0 else 0.065, 0.06, 0.04), stones[(k + 1) % stones.size()], Vector3(r * s, y, z))
			y += 0.065
			k += 1


# Estandarte colgante con dos picas cruzadas
static func pike_banner(p: Node3D, pos: Vector3, yaw: float, w: float, h: float, field: Material, trim: Material, shaft: Material, head: Material) -> void:
	Arch.hang_banner(p, pos, yaw, w, h, field, trim, trim, 3)
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	p.add_child(n)
	crossed_pikes(n, Vector3(0, -h * 0.47, 0.018), w / 0.2, shaft, head)


# Esquinas de sillares alternos (cadenas de esquina)
static func quoins(p: Node3D, half: float, y0: float, y1: float, stones: Array[Material]) -> void:
	var k := 0
	var y := y0
	while y < y1:
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var m: Material = stones[(k + int(sx + 1.0) + int(sz + 1.0)) % stones.size()]
				if k % 2 == 0:
					M.box(p, Vector3(0.14, 0.075, 0.09), m, Vector3(sx * (half - 0.058), y, sz * (half - 0.033)))
				else:
					M.box(p, Vector3(0.09, 0.075, 0.14), m, Vector3(sx * (half - 0.033), y, sz * (half - 0.058)))
		y += 0.085
		k += 1


# =====================================================================
# --- Torre ---
# =====================================================================

func _build_tower(p: Node3D) -> void:
	match tier:
		0: _tower_t0(p)
		1: _tower_t1(p)
		_: _tower_grand(p, tier == 3)


# Etapa 0: cuartel de troncos con empalizada, puerta de tablones y armeros de picas
func _tower_t0(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[0]
	var half := 0.3
	var bark := M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36))
	var bark2 := M.tex_mat("wood", 2.5, Color(0.57, 0.42, 0.29))
	var cut := M.mat(Color(0.86, 0.72, 0.5))
	var log_dark := M.mat(Color(0.4, 0.26, 0.15))
	var plank := M.tex_mat("wood", 2.0, Color(0.88, 0.74, 0.55))
	var plank2 := M.tex_mat("wood", 2.0, Color(0.74, 0.58, 0.41))
	var iron := M.metal(IRON)
	var black := M.mat(Color(0.08, 0.06, 0.05))
	var rope := M.mat(Color(0.84, 0.75, 0.56))
	var ash := M.mat(ASH)
	M.cyl(p, 0.46, 0.47, 0.03, M.mat(Color(0.52, 0.4, 0.27)), Vector3(0, 0.015, 0), Vector3.ZERO, 18)
	# Cabaña de troncos horizontales con las testas cruzadas en las esquinas
	M.box(p, Vector3(2.0 * half - 0.04, py - 0.12, 2.0 * half - 0.04), log_dark, Vector3(0, (py - 0.12) * 0.5 + 0.03, 0))
	var r := 0.042
	var y := 0.07
	var row := 0
	var ln := 2.0 * half + 0.1
	while y < py - 0.1:
		var m1 := bark if row % 2 == 0 else bark2
		var m2 := bark2 if row % 2 == 0 else bark
		for s: float in [-1.0, 1.0]:
			M.cyl(p, r, r, ln, m1, Vector3(0, y, half * s), Vector3(0, 0, 90), 8)
			M.cyl(p, r * 0.8, r * 0.8, 0.01, cut, Vector3(ln * 0.5 * s, y, half * s), Vector3(0, 0, 90), 8)
			M.cyl(p, r * 0.8, r * 0.8, 0.01, cut, Vector3(-ln * 0.5 * s, y, half * s), Vector3(0, 0, 90), 8)
			M.cyl(p, r, r, ln, m2, Vector3(half * s, y + 0.042, 0), Vector3(90, 0, 0), 8)
			M.cyl(p, r * 0.8, r * 0.8, 0.01, cut, Vector3(half * s, y + 0.042, ln * 0.5), Vector3(90, 0, 0), 8)
			M.cyl(p, r * 0.8, r * 0.8, 0.01, cut, Vector3(half * s, y + 0.042, -ln * 0.5), Vector3(90, 0, 0), 8)
		y += 0.084
		row += 1
	# Ventanucos con contraventanas en los costados
	for s: float in [-1.0, 1.0]:
		var f := side(p, Vector3(s, 0, 0), half + 0.04)
		M.box(f, Vector3(0.1, 0.08, 0.02), black, Vector3(0, 0.46, 0))
		M.box(f, Vector3(0.12, 0.02, 0.03), log_dark, Vector3(0, 0.51, 0.004))
	# Suelo de tablones en voladizo sobre vigas
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.84, 0.05, 0.06), log_dark, Vector3(0, py - 0.065, 0.33 * s))
	for k in 8:
		M.box(p, Vector3(0.76 + (k % 3) * 0.02, 0.04, 0.1), plank if k % 2 == 0 else plank2, Vector3((k % 2) * 0.01, py - 0.02, -0.37 + k * 0.105), Vector3(0, (k % 3 - 1) * 2.0, 0))
	# Postes de esquina afilados y parapeto de zarzo
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var cp := Vector3(0.37 * sx, 0, 0.37 * sz)
			M.cyl(p, 0.044, 0.048, py + 0.18, bark, cp + Vector3(0, (py + 0.18) * 0.5, 0), Vector3.ZERO, 8)
			M.cyl(p, 0.0, 0.044, 0.08, log_dark, cp + Vector3(0, py + 0.22, 0), Vector3.ZERO, 8)
			M.cyl(p, 0.052, 0.052, 0.025, rope, cp + Vector3(0, py + 0.08, 0), Vector3.ZERO, 8)
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var f := side(p, face, 0.37)
		for yy: float in [py + 0.04, py + 0.11]:
			M.box(f, Vector3(0.7, 0.022, 0.022), log_dark, Vector3(0, yy, 0))
		for k in 5:
			var o := -0.24 + k * 0.12
			M.cyl(f, 0.018, 0.02, 0.15, bark2, Vector3(o, py + 0.075, 0.012 * (k % 2)), Vector3.ZERO, 6)
			M.cyl(f, 0.0, 0.018, 0.05, log_dark, Vector3(o, py + 0.175, 0.012 * (k % 2)), Vector3.ZERO, 6)
	# Puerta de tablones con dintel de tronco, postes afilados y tejadillo
	var g := side(p, Vector3(0, 0, 1), half)
	for s: float in [-1.0, 1.0]:
		M.cyl(g, 0.034, 0.036, 0.5, bark, Vector3(0.14 * s, 0.25, 0.05), Vector3.ZERO, 8)
	M.cyl(g, 0.035, 0.035, 0.38, bark2, Vector3(0, 0.43, 0.055), Vector3(0, 0, 90), 8)
	double_gate(g, 0.05, 0.22, 0.38, 0.0, false, plank2, log_dark, iron, black)
	for s: float in [-1.0, 1.0]:
		M.box(g, Vector3(0.025, 0.24, 0.012), log_dark, Vector3(s * 0.055, 0.19, 0.072), Vector3(0, 0, 32.0 * s))
	M.box(g, Vector3(0.42, 0.025, 0.17), plank, Vector3(0, 0.51, 0.1), Vector3(24, 0, 0))
	for s: float in [-1.0, 1.0]:
		M.segment(g, 0.012, log_dark, Vector3(0.18 * s, 0.38, 0.0), Vector3(0.18 * s, 0.49, 0.15), 4)
	# Armeros de picas en los costados
	var head := M.metal(IRON)
	for s: float in [-1.0, 1.0]:
		var f := side(p, Vector3(s, 0, 0), half + 0.1)
		rack(f, 0.0, 0.26, 3, 0.46, log_dark, ash, head)
	# Caballo de frisa al frente (cara -Z) y bulto de suministros
	var back := side(p, Vector3(0, 0, -1), 0.0)
	cheval(back, half + 0.115, 0.52, bark, M.mat(Color(0.78, 0.64, 0.46)), log_dark)
	M.cyl(p, 0.055, 0.05, 0.13, plank, Vector3(-0.3, 0.065, 0.41), Vector3.ZERO, 12)
	for yy: float in [0.025, 0.105]:
		M.cyl(p, 0.058, 0.058, 0.012, log_dark, Vector3(-0.3, yy, 0.41), Vector3.ZERO, 12)
	M.box(p, Vector3(0.09, 0.08, 0.08), plank2, Vector3(0.3, 0.04, 0.41), Vector3(0, 12, 0))
	Arch._ground_details(p, false)


# Etapa 1: cuartel de piedra reforzado con cadenas de esquina, almenas y cobertizos de picas
func _tower_t1(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[1]
	var half := 0.34
	var wall := M.tex_mat("bricks", 2.2, Color(0.84, 0.82, 0.77))
	var stones: Array[Material] = [M.mat(Color(0.62, 0.6, 0.56)), M.mat(Color(0.53, 0.51, 0.48)), M.mat(Color(0.7, 0.68, 0.64))]
	var dark := M.mat(STONE_DARK)
	var timber := M.mat(TIMBER)
	var wood := M.tex_mat("wood", 2.0, Color(0.68, 0.5, 0.36))
	var slate := M.tex_mat("roof", 3.0, Color(0.72, 0.5, 0.4))
	var iron := M.metal(IRON)
	var steel := M.metal(STEEL)
	var black := M.mat(Color(0.07, 0.06, 0.06))
	var ash := M.mat(ASH)
	var blue := M.mat(BLUE)
	var yellow := M.mat(YELLOW)
	# Zócalo, muros y cadenas de esquina
	M.box(p, Vector3(0.88, 0.06, 0.88), dark, Vector3(0, 0.03, 0))
	M.box(p, Vector3(2.0 * half, py - 0.1, 2.0 * half), wall, Vector3(0, 0.06 + (py - 0.1) * 0.5, 0))
	quoins(p, half, 0.11, py - 0.12, stones)
	M.box(p, Vector3(2.0 * half + 0.03, 0.035, 2.0 * half + 0.03), stones[2], Vector3(0, 0.56, 0))
	# Ménsulas, suelo del adarve, parapeto y almenas
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var f := side(p, face, half + 0.025)
		for k in 5:
			M.box(f, Vector3(0.05, 0.08, 0.05), stones[k % 3], Vector3(-0.28 + k * 0.14, py - 0.1, 0))
	M.box(p, Vector3(2.0 * half + 0.12, 0.06, 2.0 * half + 0.12), stones[2], Vector3(0, py - 0.03, 0))
	Arch.parapet(p, half + 0.03, py + 0.04, 0.09, 0.06, wall)
	Arch.merlons(p, half + 0.03, py + 0.14, Vector3(0.1, 0.11, 0.1), 3, wall, stones[2])
	# Puerta arqueada de dos hojas con dovelas
	var g := side(p, Vector3(0, 0, 1), half)
	M.box(g, Vector3(0.3, 0.06, 0.12), stones[0], Vector3(0, 0.03, 0.06))
	M.box(g, Vector3(0.22, 0.38, 0.01), black, Vector3(0, 0.25, 0.004))
	double_gate(g, 0.02, 0.22, 0.27, 0.06, true, wood, timber, iron, black)
	voussoirs(g, 0.025, 0.135, 0.33, stones, true, 0.06)
	# Escudo con picas cruzadas sobre la puerta y antorchas
	var crest := side(p, Vector3(0, 0, 1), half + 0.01)
	crossed_pikes(crest, Vector3(0, 0.66, 0.0), 1.1, ash, steel)
	Arch.heater(p, Vector3(0, 0.67, half + 0.025), 0.0, 1.15, blue, yellow, iron)
	for s: float in [-1.0, 1.0]:
		Arch.wall_torch(p, Vector3(0.22 * s, 0.4, half), Vector3(0, 0, 1), iron)
	# Saeteras en la cara trasera
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.025, 0.12, 0.03), black, Vector3(0.18 * s, 0.4, -half - 0.004))
	# Cobertizos de tejas con armeros de picas en los costados
	for s: float in [-1.0, 1.0]:
		var f := side(p, Vector3(s, 0, 0), half)
		shed(f, 0.4, 0.11, 0.8, 0.66, timber, slate)
		rack(f, 0.065, 0.32, 4, 0.5, timber, ash, steel, M.mat(RED))
	# Estandarte y caballo de frisa en la cara -Z
	pike_banner(p, Vector3(0, py - 0.14, -half - 0.014), PI, 0.2, 0.32, blue, yellow, M.mat(CREAM), yellow)
	var back := side(p, Vector3(0, 0, -1), 0.0)
	cheval(back, half + 0.1, 0.56, wood, M.mat(Color(0.8, 0.66, 0.48)), steel)
	# Asta de la banderola en la esquina trasera izquierda
	M.cyl(p, 0.008, 0.008, 0.36, iron, Vector3(-(half + 0.03), py + 0.38, -(half + 0.03)), Vector3.ZERO, 4)
	M.sphere(p, 0.016, M.metal(GOLD), Vector3(-(half + 0.03), py + 0.57, -(half + 0.03)), Vector3.ONE, 6)
	Arch._ground_details(p, false)


# Etapas 2 y 3: gran cuartel con torreones de puerta, rastrillo, torreones traseros y estandartes.
# En la Maestría todo es de mármol, oro y azul real con la puerta y las picas brillando.
func _tower_grand(p: Node3D, royal: bool) -> void:
	var py: float = PLAT_BY_TIER[tier]
	var half := 0.36 if not royal else 0.355
	var wall: Material
	var stones: Array[Material]
	var dark: Material
	var trim: Material
	var roof: Material
	var gold := M.metal(GOLD)
	var iron := M.metal(IRON)
	var steel := M.metal(STEEL)
	var timber := M.mat(TIMBER)
	var black := M.mat(Color(0.07, 0.06, 0.06))
	var glow := M.mat(Color(1.0, 0.85, 0.5), 1.6)
	var blue_glow := M.mat(GLOW, 1.8)
	var field: Material
	var emblem: Material
	var shaft: Material
	var head: Material
	var tassel: Material
	var door: Material
	if royal:
		wall = M.tex_mat("bricks", 2.2, MARBLE)
		stones = [M.mat(Color(0.93, 0.91, 0.86)), M.mat(Color(0.86, 0.84, 0.8)), M.mat(Color(1.0, 0.98, 0.94))]
		dark = M.mat(Color(0.74, 0.72, 0.68))
		trim = gold
		roof = M.tex_mat("roof", 3.0, Color(0.42, 0.55, 0.95))
		field = M.mat(ROYAL)
		emblem = gold
		shaft = M.mat(ROYAL)
		head = gold
		tassel = M.mat(CREAM)
		door = M.tex_mat("wood", 2.0, Color(0.5, 0.62, 1.0))
	else:
		wall = M.tex_mat("bricks", 2.2, Color(0.86, 0.84, 0.79))
		stones = [M.mat(Color(0.62, 0.6, 0.56)), M.mat(Color(0.53, 0.51, 0.48)), M.mat(Color(0.68, 0.66, 0.62))]
		dark = M.mat(STONE_DARK)
		trim = stones[2]
		roof = M.tex_mat("roof", 3.0, Color(0.55, 0.6, 0.72))
		field = M.mat(BLUE)
		emblem = M.mat(YELLOW)
		shaft = M.mat(ASH)
		head = steel
		tassel = M.mat(RED)
		door = M.tex_mat("wood", 2.0, Color(0.66, 0.48, 0.34))
	# Torre del homenaje sin sillares en la fachada (allí va el cuerpo de la puerta)
	Arch._stone_keep(p, py, half, wall, stones, dark, trim, null, [[0, 0], [0, 1], [0, 2]])
	if royal:
		M.box(p, Vector3(2.0 * half + 0.03, 0.025, 2.0 * half + 0.03), gold, Vector3(0, py * 0.36, 0))
		M.box(p, Vector3(2.0 * half + 0.18, 0.025, 2.0 * half + 0.18), gold, Vector3(0, py - 0.085, 0))
	# Cuerpo de la puerta entre dos torreones
	var gy := 0.17
	M.box(p, Vector3(0.32, 0.66, 0.08), wall, Vector3(0, gy + 0.33, half + 0.02))
	M.box(p, Vector3(0.36, 0.04, 0.11), trim, Vector3(0, gy + 0.68, half + 0.025))
	for k in 3:
		M.box(p, Vector3(0.08, 0.08, 0.08), wall, Vector3(-0.12 + k * 0.12, gy + 0.74, half + 0.03))
		M.box(p, Vector3(0.1, 0.022, 0.1), trim, Vector3(-0.12 + k * 0.12, gy + 0.79, half + 0.03))
	var g := side(p, Vector3(0, 0, 1), half + 0.06)
	M.box(g, Vector3(0.22, 0.34, 0.01), black, Vector3(0, gy + 0.17, 0.0))
	double_gate(g, 0.006, 0.2, 0.26, gy, true, door, timber if not royal else gold, iron if not royal else gold, black if not royal else glow)
	voussoirs(g, 0.012, 0.125, gy + 0.26, stones, true, gy)
	if royal:
		M.box(g, Vector3(0.05, 0.05, 0.03), gold, Vector3(0, gy + 0.39, 0.02), Vector3(0, 0, 45))
		M.sphere(g, 0.016, blue_glow, Vector3(0, gy + 0.39, 0.035), Vector3.ONE, 8)
	# Rastrillo medio alzado con púas
	var bars := iron if not royal else gold
	for k in 5:
		M.box(g, Vector3(0.014, 0.12, 0.014), bars, Vector3(-0.08 + k * 0.04, gy + 0.33, 0.03))
		M.cyl(g, 0.0, 0.009, 0.03, bars, Vector3(-0.08 + k * 0.04, gy + 0.255, 0.03), Vector3(180, 0, 0), 4)
	M.box(g, Vector3(0.19, 0.014, 0.016), bars, Vector3(0, gy + 0.3, 0.034))
	# Matacán sobre la puerta y picas cruzadas con escudo
	for k in 4:
		M.box(g, Vector3(0.04, 0.06, 0.05), stones[k % 3], Vector3(-0.105 + k * 0.07, gy + 0.6, 0.02))
	M.box(g, Vector3(0.3, 0.06, 0.06), wall, Vector3(0, gy + 0.65, 0.03))
	crossed_pikes(g, Vector3(0, gy + 0.5, 0.0), 1.05, shaft, head)
	Arch.heater(p, Vector3(0, gy + 0.51, half + 0.08), 0.0, 1.0, field, emblem, trim if royal else iron)
	# Torreones que flanquean la puerta (de mármol pulido en la Maestría)
	var tw: Material = M.mat(MARBLE) if royal else wall
	for sx: float in [-1.0, 1.0]:
		var top := Arch.turret(p, Vector3(0.25 * sx, 0, 0.31), 0.1, gy + 0.02, gy + 0.62 + (0.06 if royal else 0.0), tw, roof, 0.3, trim, gold)
		if royal:
			M.cyl(p, 0.105, 0.105, 0.02, gold, Vector3(0.25 * sx, gy + 0.3, 0.31), Vector3.ZERO, 14)
			M.cyl(p, 0.006, 0.006, 0.12, gold, top + Vector3(0, 0.06, 0), Vector3.ZERO, 4)
		for yy: float in [gy + 0.22, gy + 0.44]:
			var d := Vector3(0.25 * sx, 0, 0.31).normalized()
			var sl := M.box(p, Vector3(0.025, 0.1, 0.02), glow if royal else black, Vector3(0.25 * sx, yy, 0.31) + Vector3(sx * 0.07, 0, 0.07))
			sl.rotation.y = atan2(d.x, d.z) + 0.5 * sx
		Arch.wall_torch(p, Vector3(0.25 * sx, 0.44, 0.41), Vector3(0, 0, 1), gold if royal else iron)
	# Torreones traseros de esquina
	for sx: float in [-1.0, 1.0]:
		var top := Arch.turret(p, Vector3(0.35 * sx, 0, -0.35), 0.12, py - 0.3, py + 0.28, tw, roof, 0.4 if royal else 0.36, trim, gold)
		M.cyl(p, 0.007, 0.007, 0.2, gold if royal else iron, top + Vector3(0, 0.1, 0), Vector3.ZERO, 4)
	# Cobertizos con armeros de picas en los costados (con escudos en el muro)
	for s: float in [-1.0, 1.0]:
		var f := side(p, Vector3(s, 0, 0), half)
		shed(f, 0.42, 0.11, 0.84, 0.7, timber if not royal else gold, roof)
		rack(f, 0.065, 0.34, 4, 0.52, timber if not royal else gold, shaft, head, tassel)
		Arch.heater(f, Vector3(0, py - 0.27, 0.012), 0.0, 1.25, field, emblem, trim if royal else iron)
		if royal:
			for k in 4:
				var o := -0.17 + 0.08 + (0.34 - 0.08) * k / 3.0
				M.sphere(f, 0.012, blue_glow, Vector3(o + 0.006 * (k % 2), 0.52 + 0.08, 0.06 - 0.035), Vector3.ONE, 6)
	# Estandartes con picas cruzadas en la cara -Z
	for s: float in [-1.0, 1.0]:
		pike_banner(p, Vector3(0.15 * s, py - 0.13, -half - 0.075), PI, 0.17, 0.42 if royal else 0.38, field, emblem, M.mat(CREAM) if not royal else gold, emblem)
	if royal:
		# Gran emblema dorado de picas cruzadas en la fachada trasera y saeteras brillantes
		var bk := side(p, Vector3(0, 0, -1), half + 0.012)
		crossed_pikes(bk, Vector3(0, 0.4, 0.0), 1.4, gold, gold)
		M.sphere(bk, 0.03, blue_glow, Vector3(0, 0.375, 0.012), Vector3(1, 1, 0.5), 10)
		Arch._slits(p, half, [0.82], glow)
	else:
		Arch._slits(p, half, [0.8], black)
	Arch._ground_details(p, false)


# =====================================================================
# --- Piquero ---
# =====================================================================

func _build_man(c: Node3D) -> void:
	var gambeson := M.mat(Color(0.62, 0.5, 0.33))
	var mail := M.metal(MAIL)
	var steel := M.metal(STEEL)
	var bright := M.metal(Color(0.62, 0.67, 0.78))
	var leather := M.mat(LEATHER)
	var gold := M.metal(GOLD)
	var blue := M.mat(BLUE if tier < 3 else ROYAL)
	var yellow := M.mat(YELLOW)
	var cream := M.mat(CREAM)
	match tier:
		0:
			# miliciano: gambesón acolchado con cota corta de malla encima
			Human.body(c, gambeson, leather)
			M.cyl(c, 0.135, 0.165, 0.1, mail, Vector3(0, 0.05, 0), Vector3.ZERO, 14)
			for k in 3:
				M.box(c, Vector3(0.26, 0.008, 0.012), M.mat(Color(0.5, 0.38, 0.24)), Vector3(0, 0.12 + k * 0.06, -0.122))
		_:
			Human.body(c, mail if tier < 3 else bright, yellow if tier < 3 else gold)
			# sobreveste cuartelada azul / amarilla (azul real y oro en la Maestría)
			for sd: float in [-1.0, 1.0]:
				var f1 := blue if sd < 0.0 or tier == 3 else yellow
				var f2 := yellow if sd < 0.0 and tier < 3 else blue
				M.box(c, Vector3(0.095, 0.27, 0.02), f1, Vector3(0.0475 * sd, 0.14, -0.124), Vector3(-4, 0, 0))
				M.box(c, Vector3(0.095, 0.27, 0.02), f2, Vector3(0.0475 * sd, 0.14, 0.124), Vector3(4, 0, 0))
			# picas cruzadas bordadas en el pecho
			var em := gold if tier == 3 else cream
			for k: float in [-1.0, 1.0]:
				M.box(c, Vector3(0.012, 0.15, 0.01), em, Vector3(0, 0.15, -0.138), Vector3(-4, 0, 30.0 * k))
				M.sphere(c, 0.012, em, Vector3(0.036 * k, 0.215, -0.14), Vector3(1, 1.6, 0.5), 6)
			if tier == 3:
				M.box(c, Vector3(0.19, 0.02, 0.024), gold, Vector3(0, 0.01, -0.12))
				M.box(c, Vector3(0.012, 0.27, 0.024), gold, Vector3(0, 0.14, -0.13), Vector3(-4, 0, 0))
				# capa corta azul real con borde dorado
				M.box(c, Vector3(0.26, 0.3, 0.02), blue, Vector3(0, 0.16, 0.135), Vector3(10, 0, 0))
				M.box(c, Vector3(0.27, 0.025, 0.026), gold, Vector3(0, 0.02, 0.16), Vector3(10, 0, 0))
			if tier >= 2:
				# hombreras y gola de acero (doradas en la Maestría)
				for sx: float in [-1.0, 1.0]:
					M.sphere(c, 0.072, gold if tier == 3 else steel, Vector3(0.135 * sx, 0.285, 0), Vector3(1, 0.7, 1), 10)
					M.sphere(c, 0.06, gold if tier == 3 else steel, Vector3(0.135 * sx, 0.255, 0), Vector3(1, 0.5, 1), 10)
				M.cyl(c, 0.075, 0.09, 0.04, gold if tier == 3 else steel, Vector3(0, 0.34, 0), Vector3.ZERO, 12)
			# escudo a la espalda
			Arch.heater(c, Vector3(0, 0.17, 0.15), 0.0, 1.25, blue, yellow if tier < 3 else gold, gold if tier == 3 else M.metal(IRON))
	var belt := TorusMesh.new()
	belt.inner_radius = 0.13
	belt.outer_radius = 0.155
	M.add(c, belt, leather, Vector3(0, 0.09, 0))
	M.box(c, Vector3(0.04, 0.04, 0.02), gold if tier == 3 else M.metal(IRON), Vector3(0, 0.09, -0.15))
	# espada corta envainada al costado
	M.segment(c, 0.016, leather, Vector3(-0.16, 0.1, 0.0), Vector3(-0.17, -0.06, 0.1), 6)
	M.box(c, Vector3(0.08, 0.014, 0.014), gold if tier == 3 else steel, Vector3(-0.158, 0.11, -0.005), Vector3(0, 0, -5))
	for sx: float in [-1.0, 1.0]:
		M.cyl(c, 0.045, 0.05, 0.05, leather, Vector3(0.06 * sx, 0.01, -0.02), Vector3.ZERO, 8)
	# cabeza: almófar (acolchado en la etapa 0) y capacete de ala ancha
	var hat := M.metal(IRON) if tier == 0 else (steel if tier < 3 else bright)
	var h := Human.head(c, false, false)
	if tier == 0:
		M.sphere(h, 0.146, M.mat(Color(0.74, 0.64, 0.46)), Vector3(0, -0.005, 0.035), Vector3(1.0, 1.05, 1.0), 14)
	else:
		M.sphere(h, 0.148, M.metal(MAIL), Vector3(0, 0.0, 0.035), Vector3(1.0, 1.05, 1.0), 14)
		M.cyl(h, 0.13, 0.17, 0.09, M.metal(MAIL), Vector3(0, -0.14, 0.01), Vector3.ZERO, 14)
	M.sphere(h, 0.15, hat, Vector3(0, 0.075, 0.02), Vector3(1.02, 0.8, 1.02), 14)
	M.cyl(h, 0.155, 0.225, 0.035, hat, Vector3(0, 0.05, 0.02), Vector3.ZERO, 18)
	M.cyl(h, 0.228, 0.228, 0.012, gold if tier == 3 else M.metal(IRON), Vector3(0, 0.033, 0.02), Vector3.ZERO, 18)
	M.box(h, Vector3(0.022, 0.024, 0.2), gold if tier >= 2 else hat, Vector3(0, 0.188, 0.02))
	if tier >= 2:
		# penacho (azul y amarillo; azul real y crema en la Maestría)
		for k in 3:
			var pm := cream if tier == 3 and k == 1 else (blue if k != 1 else yellow)
			M.sphere(h, 0.034, pm, Vector3(0, 0.205 + k * 0.014, 0.05 + k * 0.04), Vector3(0.6, 1.0, 1.4), 8)
	if tier == 3:
		M.sphere(h, 0.018, M.mat(GLOW, 1.8), Vector3(0, 0.12, -0.125), Vector3(1, 1, 0.5), 8)


# --- Pica larga (se mueve con _pike) ---

func _build_weapon(w: Node3D) -> void:
	var shaft := M.tex_mat("wood", 2.0, Color(0.84, 0.66, 0.44)) if tier < 3 else M.mat(ROYAL)
	var grip := M.mat(LEATHER)
	var steel := M.metal(STEEL if tier > 0 else IRON)
	var gold := M.metal(GOLD)
	var headm := gold if tier == 3 else steel
	# asta y regatón
	M.cyl(w, 0.015, 0.015, HEAD_BASE * -1.0 + BUTT_Z, shaft, Vector3(0, 0, (HEAD_BASE + BUTT_Z) * 0.5), Vector3(90, 0, 0), 8)
	M.cyl(w, 0.0, 0.017, 0.05, headm, Vector3(0, 0, BUTT_Z + 0.02), Vector3(90, 0, 0), 6)
	# empuñaduras de cuero
	for z: float in [FRONT_GRIP, REAR_GRIP]:
		M.cyl(w, 0.019, 0.019, 0.07, grip, Vector3(0, 0, z), Vector3(90, 0, 0), 8)
	if tier == 3:
		for z: float in [-0.4, 0.0, 0.26]:
			M.cyl(w, 0.019, 0.019, 0.018, gold, Vector3(0, 0, z), Vector3(90, 0, 0), 8)
	# moharra: cubo, lengüetas, hoja de laurel y punta
	M.cyl(w, 0.017, 0.021, 0.06, headm, Vector3(0, 0, HEAD_BASE - 0.02), Vector3(-90, 0, 0), 8)
	for s: float in [-1.0, 1.0]:
		M.box(w, Vector3(0.006, 0.01, 0.12), headm, Vector3(0.016 * s, 0, HEAD_BASE + 0.05))
	M.sphere(w, 0.034, headm, Vector3(0, 0, HEAD_BASE - 0.13), Vector3(1.0, 0.3, 2.9), 10)
	M.box(w, Vector3(0.006, 0.014, 0.16), M.metal(Color(0.7, 0.72, 0.78)) if tier < 3 else gold, Vector3(0, 0, HEAD_BASE - 0.13))
	M.cyl(w, 0.0, 0.012, 0.06, headm, Vector3(0, 0, TIP_Z + 0.03), Vector3(-90, 0, 0), 6)
	# cruceta (picas de etapas altas)
	if tier >= 2:
		M.box(w, Vector3(0.12, 0.014, 0.014), headm, Vector3(0, 0, HEAD_BASE - 0.01))
		for s: float in [-1.0, 1.0]:
			M.sphere(w, 0.012, headm, Vector3(0.06 * s, 0, HEAD_BASE - 0.01), Vector3.ONE, 6)
	# borla bajo la moharra
	var tas := M.mat(RED) if tier < 3 else M.mat(CREAM)
	if tier >= 1:
		for k in 3:
			M.sphere(w, 0.016, tas, Vector3(0.012 * (k - 1), -0.022 - 0.006 * (k % 2), HEAD_BASE + 0.04 + 0.01 * k), Vector3(1, 1.6, 1), 6)
	# gallardete (azul con borde amarillo; azul real y oro en la Maestría)
	if tier >= 2:
		var fl := M.mat(BLUE if tier < 3 else ROYAL)
		var tr := M.mat(YELLOW) if tier < 3 else gold
		M.box(w, Vector3(0.006, 0.085, 0.13), fl, Vector3(0, 0.055, HEAD_BASE + 0.12))
		M.box(w, Vector3(0.008, 0.016, 0.135), tr, Vector3(0, 0.1, HEAD_BASE + 0.12))
		M.cyl(w, 0.0, 0.045, 0.07, fl, Vector3(0, 0.055, HEAD_BASE + 0.2), Vector3(-90, 0, 0), 4)
	if tier == 3:
		# núcleo brillante en la hoja
		M.sphere(w, 0.016, M.mat(GLOW, 2.0), Vector3(0, 0, HEAD_BASE - 0.11), Vector3(0.8, 1.2, 2.2), 8)


func _build_arms() -> void:
	var sleeve: Material = [M.mat(Color(0.62, 0.5, 0.33)), M.metal(MAIL), M.metal(MAIL), M.metal(Color(0.8, 0.82, 0.88))][tier]
	var glove := M.mat(LEATHER) if tier < 3 else M.metal(GOLD)
	_arm_l = M.add(cat_pivot, M.tube_mesh(0.042, 8), sleeve)
	_arm_r = M.add(cat_pivot, M.tube_mesh(0.042, 8), sleeve)
	_hand_l = M.sphere(cat_pivot, 0.044, glove, Vector3.ZERO, Vector3.ONE, 8)
	_hand_r = M.sphere(cat_pivot, 0.044, glove, Vector3.ZERO, Vector3.ONE, 8)


# =====================================================================
# --- Etapas visuales (adornos animados) ---
# =====================================================================

func _build_tier_fx() -> void:
	var py: float = PLAT_BY_TIER[tier]
	match tier:
		0:
			_pennants.append(Arch.pennant_node(self, Vector3(-0.37, py + 0.26, -0.37), BLUE, CREAM, 0.22, 0.4))
		1:
			for s: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.22 * s, 0.45, 0.34 + 0.075)))
			_pennants.append(Arch.pennant_node(self, Vector3(-0.37, py + 0.56, -0.37), BLUE, YELLOW, 0.24, 0.4))
		2:
			for s: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.25 * s, 0.49, 0.41 + 0.075)))
				_pennants.append(Arch.pennant_node(self, Vector3(0.35 * s, py + 0.84, -0.35), BLUE, YELLOW, 0.28, 0.4 if s < 0.0 else 2.7))
		3:
			for s: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.25 * s, 0.49, 0.41 + 0.075), 1.1, Color(1.0, 0.82, 0.4)))
				_pennants.append(Arch.pennant_node(self, Vector3(0.35 * s, py + 0.88, -0.35), ROYAL, GOLD, 0.32, 0.4 if s < 0.0 else 2.7))
			_spinners.append(Arch.aura_ring(self, 0.47, Color(0.55, 0.75, 1.0), 0.12))
			add_child(Arch.sparkles(Color(1.0, 0.88, 0.5), Vector3(0, 0.7, 0), Vector3(0.45, 0.6, 0.45), 18, 0.012))
