extends Node3D
## Modelo 3D de la "Torre de Ballesteros" (id crossbow): casa-puerta con planta baja de sillares,
## pasaje abovedado con rastrillo de hierro, piso alto con entramado de madera (paredes encaladas,
## vigas oscuras y aspas de San Andrés), dos garitas con tejado cónico de pizarra y un cadalso de
## madera con paveses pintados colgados del parapeto.
## Arriba, un ballestero humano con almófar de malla y capacete de ala que carga con el torno
## una ballesta pesada. Mira hacia -Z dentro de cat_pivot.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const Arch := preload("res://scripts/towers3d/archer_model.gd")

const STONE_DARK := Color(0.42, 0.4, 0.38)
const TIMBER := Color(0.27, 0.17, 0.1)
const PLASTER := Color(0.93, 0.89, 0.8)
const IRON := Color(0.26, 0.26, 0.29)
const STEEL := Color(0.47, 0.49, 0.54)
const MAIL := Color(0.43, 0.45, 0.49)
const RED := Color(0.72, 0.14, 0.12)
const WHITE := Color(0.95, 0.93, 0.88)
const GREEN := Color(0.2, 0.42, 0.22)
const GOLD := Color(0.95, 0.75, 0.3)
const ROPE := Color(0.84, 0.75, 0.56)
const FLAME := Color(1.0, 0.6, 0.15)

const PLATFORM_Y := 0.98
const PLAT_BY_TIER := [0.74, 0.98, 1.2, 1.4]
const MARBLE := Color(0.97, 0.95, 0.9)
const ROYAL := Color(0.16, 0.26, 0.62)
# Ballesta (coordenadas de _xbow): culata en el origen, apunta a -Z
const XB_POS := Vector3(0.09, 0.3, -0.1)
const PROD_Z := -0.38
const PROD_HALF := 0.22
const NOCK_REST := -0.36
const NOCK_DRAWN := -0.1
const BOLT_LEN := 0.32
const WINDLASS := Vector3(0, 0.0, 0.03)
const CRANK_R := 0.05

var cat_pivot: Node3D
var _xbow: Node3D
var _windlass: Node3D
var _str_l: MeshInstance3D
var _str_r: MeshInstance3D
var _cord: MeshInstance3D
var _bolt: Node3D
var _man: Node3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _hand_l: MeshInstance3D
var _hand_r: MeshInstance3D
var tier := 0
var _flames: Array[Node3D] = []
var _pennants: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _floaters: Array[Node3D] = []


func _init(level := 0) -> void:
	tier = Arch.tier_of(level)
	M.add_baked(self, M.baked("crossbow_tower_t%d" % tier, _build_tower))
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, PLAT_BY_TIER[tier], 0)
	add_child(cat_pivot)
	_man = Node3D.new()
	cat_pivot.add_child(_man)
	M.add_baked(_man, M.baked("crossbow_man_t%d" % tier, _build_man))
	_xbow = Node3D.new()
	_xbow.position = XB_POS
	cat_pivot.add_child(_xbow)
	M.add_baked(_xbow, M.baked("crossbow_weapon_t%d" % tier, _build_weapon))
	_build_moving_parts()
	_build_tier_fx()
	animate({"t": 0.0, "charge": 0.0, "fire": 0.0, "has_target": false})


## s = {t, charge (0..1), fire (1 -> 0), has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = s.get("charge", 0.0)
	var fire: float = s.get("fire", 0.0)
	var has_target: bool = s.get("has_target", false)
	var pull := charge if has_target else minf(charge, 0.4)
	# Retroceso: la ballesta salta hacia atrás y arriba
	_xbow.position = XB_POS + Vector3(0, fire * 0.02, fire * 0.05)
	_xbow.rotation.x = fire * 0.28 + (0.0 if has_target else -0.12 + sin(t * 1.3) * 0.03)
	# Torno: gira mientras tensa la cuerda
	_windlass.rotation.x = -pull * TAU * 2.0
	var nz := lerpf(NOCK_REST, NOCK_DRAWN, pull)
	if fire > 0.0:
		nz = NOCK_REST - 0.02 + sin(t * 80.0) * 0.02 * fire
	var nock := Vector3(0, 0.035, nz)
	var tip_r := Vector3(PROD_HALF, 0.02, PROD_Z + 0.05 + (nz - NOCK_REST) * 0.12)
	var tip_l := tip_r * Vector3(-1, 1, 1)
	M.orient_segment(_str_r, nock, tip_r)
	M.orient_segment(_str_l, nock, tip_l)
	_cord.visible = pull > 0.03 and fire <= 0.0
	if _cord.visible:
		M.orient_segment(_cord, WINDLASS + Vector3(0, 0.035, -0.03), nock)
	_bolt.visible = fire <= 0.05 and pull > 0.6
	_bolt.position = nock
	# Manos: derecha en la manivela del torno, izquierda bajo la caja
	var handle := _xbow.transform * (_windlass.transform * Vector3(0.1, 0, CRANK_R))
	var grip := _xbow.transform * Vector3(-0.035, -0.03, -0.22)
	_hand_r.position = handle
	_hand_l.position = grip
	_man.position = Vector3(0, absf(sin(t * 1.5)) * 0.005, fire * 0.02)
	M.orient_segment(_arm_r, _man.transform * Human.R_SHOULDER, handle)
	M.orient_segment(_arm_l, _man.transform * Human.L_SHOULDER, grip)
	# Antorchas, banderolas y aura de la etapa
	Arch.animate_fx(t, _flames, _pennants, _spinners, _floaters)


## Punta del virote cargado (posición global)
func muzzle_global() -> Vector3:
	return _xbow.to_global(Vector3(0, 0.035, NOCK_DRAWN - BOLT_LEN - 0.05))


# --- Heráldica ---

# Pavés: escudo alto con la parte superior redondeada, mirando a +Z del nodo.
# kind 0 = partido rojo/blanco con cruz, 1 = blanco con cheurón rojo, 2 = verde con banda blanca
static func pavise(p: Node3D, pos: Vector3, yaw: float, kind: int) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation = Vector3(-0.12, yaw, 0)
	p.add_child(n)
	var red := M.mat(RED)
	var white := M.mat(WHITE)
	var green := M.mat(GREEN)
	var rim := M.metal(IRON)
	M.box(n, Vector3(0.15, 0.2, 0.02), rim, Vector3(0, 0, -0.004))
	M.cyl(n, 0.075, 0.075, 0.02, rim, Vector3(0, 0.1, -0.004), Vector3(90, 0, 0), 12)
	var base := white if kind == 1 else (green if kind == 2 else red)
	M.box(n, Vector3(0.13, 0.19, 0.02), base, Vector3(0, -0.003, 0.0))
	M.cyl(n, 0.065, 0.065, 0.02, base, Vector3(0, 0.1, 0.0), Vector3(90, 0, 0), 12)
	match kind:
		0:
			M.box(n, Vector3(0.065, 0.19, 0.022), white, Vector3(0.032, -0.003, 0.002))
			M.cyl(n, 0.065, 0.065, 0.022, white, Vector3(0.0, 0.1, 0.002), Vector3(90, 0, 0), 12)
			M.box(n, Vector3(0.065, 0.06, 0.024), red, Vector3(-0.032, 0.12, 0.002))
			M.box(n, Vector3(0.02, 0.15, 0.03), M.metal(GOLD), Vector3(0, 0.03, 0.006))
			M.box(n, Vector3(0.1, 0.02, 0.03), M.metal(GOLD), Vector3(0, 0.07, 0.006))
		1:
			for k: float in [-1.0, 1.0]:
				M.box(n, Vector3(0.09, 0.03, 0.026), red, Vector3(0.03 * k, 0.02, 0.004), Vector3(0, 0, 38.0 * k))
		_:
			M.box(n, Vector3(0.03, 0.22, 0.026), white, Vector3(0, 0.02, 0.004), Vector3(0, 0, -30))
	M.sphere(n, 0.016, rim, Vector3(0, 0.03, 0.014), Vector3(1, 1, 0.5), 8)


# --- Torre ---

func _build_tower(p: Node3D) -> void:
	match tier:
		0: _tower_t0(p)
		2: _tower_t2(p)
		3: _tower_t3(p)
		_: _tower_t1(p)


# Etapa 1: casa-puerta con planta baja de sillares y piso alto entramado (diseño original)
func _tower_t1(p: Node3D) -> void:
	var bricks := M.tex_mat("bricks", 2.2, Color(0.84, 0.82, 0.77))
	var dark := M.mat(STONE_DARK)
	var stones: Array[Material] = [M.mat(Color(0.62, 0.6, 0.56)), M.mat(Color(0.53, 0.51, 0.48)), M.mat(Color(0.68, 0.66, 0.62))]
	var plaster := M.mat(PLASTER)
	var timber := M.mat(TIMBER)
	var wood := M.tex_mat("wood", 2.0, Color(0.62, 0.48, 0.38))
	var iron := M.metal(IRON)
	var black := M.mat(Color(0.07, 0.06, 0.06))
	var slate := M.tex_mat("roof", 3.0, Color(0.55, 0.6, 0.72))

	# Planta baja de sillares con contrafuertes
	M.box(p, Vector3(0.88, 0.06, 0.88), dark, Vector3(0, 0.03, 0))
	M.box(p, Vector3(0.74, 0.46, 0.74), bricks, Vector3(0, 0.29, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(p, Vector3(0.12, 0.36, 0.12), stones[1], Vector3(0.37 * sx, 0.21, 0.37 * sz))
			M.cyl(p, 0.0, 0.085, 0.08, stones[2], Vector3(0.37 * sx, 0.43, 0.37 * sz), Vector3(0, 45, 0), 4)
	# Pasaje abovedado con rastrillo en las dos caras
	for sz: float in [-1.0, 1.0]:
		var g := Node3D.new()
		g.position = Vector3(0, 0, 0.372 * sz)
		g.rotation.y = 0.0 if sz > 0.0 else PI
		p.add_child(g)
		M.cyl(g, 0.15, 0.15, 0.03, stones[2], Vector3(0, 0.26, 0), Vector3(90, 0, 0), 16)
		M.box(g, Vector3(0.3, 0.2, 0.03), stones[2], Vector3(0, 0.16, 0))
		M.cyl(g, 0.12, 0.12, 0.032, black, Vector3(0, 0.26, 0.002), Vector3(90, 0, 0), 16)
		M.box(g, Vector3(0.24, 0.2, 0.032), black, Vector3(0, 0.16, 0.002))
		for k in 5:
			M.box(g, Vector3(0.016, 0.24, 0.016), iron, Vector3(-0.1 + k * 0.05, 0.27, 0.022))
		for y: float in [0.2, 0.28, 0.36]:
			M.box(g, Vector3(0.22, 0.014, 0.016), iron, Vector3(0, y, 0.024))
		for k in 5:
			M.cyl(g, 0.0, 0.01, 0.03, iron, Vector3(-0.1 + k * 0.05, 0.14, 0.022), Vector3(180, 0, 0), 4)
		# dovelas del arco
		for k in 7:
			var a := PI * k / 6.0
			M.box(g, Vector3(0.05, 0.04, 0.035), stones[k % 3], Vector3(cos(a) * 0.15, 0.26 + sin(a) * 0.15, 0.004), Vector3(0, 0, rad_to_deg(a) + 90.0))
	M.box(p, Vector3(0.3, 0.04, 0.16), stones[0], Vector3(0, 0.02, 0.45))

	# Piso alto con entramado (sobresale un poco: voladizo)
	M.box(p, Vector3(0.84, 0.05, 0.84), timber, Vector3(0, 0.545, 0))
	for k in 5:
		var off := -0.32 + k * 0.16
		for sz: float in [-1.0, 1.0]:
			M.box(p, Vector3(0.04, 0.04, 0.05), timber, Vector3(off, 0.51, 0.395 * sz))
			M.box(p, Vector3(0.05, 0.04, 0.04), timber, Vector3(0.395 * sz, 0.51, off))
	M.box(p, Vector3(0.8, 0.34, 0.8), plaster, Vector3(0, 0.74, 0))
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var f := Node3D.new()
		f.position = face * 0.402
		f.rotation.y = atan2(face.x, face.z)
		p.add_child(f)
		# postes, soleras y aspas de San Andrés
		for x: float in [-0.38, -0.13, 0.13, 0.38]:
			M.box(f, Vector3(0.045, 0.36, 0.02), timber, Vector3(x, 0.74, 0))
		for y: float in [0.58, 0.9]:
			M.box(f, Vector3(0.82, 0.04, 0.022), timber, Vector3(0, y, 0))
		for side: float in [-1.0, 1.0]:
			var cx := 0.255 * side
			M.box(f, Vector3(0.03, 0.38, 0.018), timber, Vector3(cx, 0.74, 0), Vector3(0, 0, 37))
			M.box(f, Vector3(0.03, 0.38, 0.018), timber, Vector3(cx, 0.74, 0), Vector3(0, 0, -37))
		# ventana central con contraventanas
		M.box(f, Vector3(0.14, 0.15, 0.02), timber, Vector3(0, 0.76, 0.002))
		M.box(f, Vector3(0.1, 0.11, 0.022), M.mat(Color(1.0, 0.78, 0.4), 0.8), Vector3(0, 0.76, 0.004))
		M.box(f, Vector3(0.012, 0.11, 0.026), timber, Vector3(0, 0.76, 0.006))
		M.box(f, Vector3(0.1, 0.012, 0.026), timber, Vector3(0, 0.76, 0.006))
		for side: float in [-1.0, 1.0]:
			M.box(f, Vector3(0.05, 0.13, 0.015), M.mat(GREEN), Vector3(0.1 * side, 0.76, 0.012), Vector3(0, 20.0 * side, 0))

	# Garitas de esquina (traseras) con tejado cónico de pizarra
	for sx: float in [-1.0, 1.0]:
		var bp := Vector3(0.39 * sx, 0, -0.39)
		M.cyl(p, 0.1, 0.03, 0.12, stones[1], bp + Vector3(0, 0.6, 0), Vector3.ZERO, 10)
		M.cyl(p, 0.1, 0.1, 0.26, plaster, bp + Vector3(0, 0.79, 0), Vector3.ZERO, 12)
		for k in 4:
			var a := TAU * k / 4.0 + PI / 4.0
			M.box(p, Vector3(0.025, 0.26, 0.025), timber, bp + Vector3(cos(a) * 0.098, 0.79, sin(a) * 0.098))
		M.box(p, Vector3(0.02, 0.07, 0.02), black, bp + Vector3(0.0, 0.8, -0.1))
		M.cyl(p, 0.11, 0.11, 0.025, timber, bp + Vector3(0, 0.93, 0), Vector3.ZERO, 12)
		M.cyl(p, 0.0, 0.14, 0.24, slate, bp + Vector3(0, 1.06, 0), Vector3.ZERO, 12)
		M.cyl(p, 0.006, 0.006, 0.05, iron, bp + Vector3(0, 1.19, 0), Vector3.ZERO, 4)
		M.sphere(p, 0.018, M.metal(GOLD), bp + Vector3(0, 1.21, 0), Vector3.ONE, 6)

	# Cadalso de madera: suelo, postes y parapeto de tablas
	M.box(p, Vector3(0.86, 0.06, 0.86), wood, Vector3(0, 0.95, 0))
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.6, 0.1, 0.03), wood, Vector3(0, 1.03, 0.4 * s))
		M.box(p, Vector3(0.03, 0.1, 0.6), wood, Vector3(0.4 * s, 1.03, 0))
		M.box(p, Vector3(0.62, 0.025, 0.04), timber, Vector3(0, 1.09, 0.4 * s))
		M.box(p, Vector3(0.04, 0.025, 0.62), timber, Vector3(0.4 * s, 1.09, 0))
	for sx: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.05, 0.16, 0.05), timber, Vector3(0.4 * sx, 1.04, 0.4))
		M.cyl(p, 0.0, 0.04, 0.06, timber, Vector3(0.4 * sx, 1.15, 0.4), Vector3(0, 45, 0), 4)
	# Paveses colgados por fuera del parapeto
	var kinds := [0, 1, 0, 2, 1, 0, 2, 1]
	var i := 0
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, -face.x)
		for off: float in [-0.15, 0.15]:
			var k: int = kinds[i]
			pavise(p, face * 0.43 + tg * off + Vector3(0, 0.99, 0), atan2(face.x, face.z), k)
			i += 1

	# Soporte de la antorcha sobre el arco
	M.box(p, Vector3(0.03, 0.03, 0.12), iron, Vector3(0, 0.58, 0.45))
	M.cyl(p, 0.035, 0.022, 0.06, iron, Vector3(0, 0.63, 0.5), Vector3.ZERO, 8)

	# Hierba al pie
	var grass := M.mat(Color(0.32, 0.6, 0.2))
	for gp: Vector3 in [Vector3(-0.46, 0, -0.05), Vector3(0.46, 0, 0.15), Vector3(-0.2, 0, -0.46), Vector3(0.28, 0, 0.47), Vector3(-0.3, 0, 0.47)]:
		for b in 3:
			var ga := TAU * b / 3.0
			var blade := Node3D.new()
			blade.position = gp + Vector3(cos(ga), 0, sin(ga)) * 0.02
			blade.rotation = Vector3(sin(ga) * 0.4, 0, -cos(ga) * 0.4)
			p.add_child(blade)
			M.cyl(blade, 0.0, 0.016, 0.09, grass, Vector3(0, 0.045, 0), Vector3.ZERO, 4)


# --- Ballestero ---

func _build_man(c: Node3D) -> void:
	var gambeson := M.mat(Color(0.6, 0.48, 0.32))
	var red := M.mat(RED)
	var white := M.mat(WHITE)
	var mail := M.metal(MAIL)
	var steel := M.metal(STEEL)
	var leather := M.mat(Color(0.36, 0.22, 0.12))
	var gold := M.metal(GOLD)
	if tier == 0:
		# miliciano: gambesón sin sobreveste y gorro acolchado
		Human.body(c, gambeson, M.mat(Color(0.45, 0.34, 0.22)))
	else:
		Human.body(c, gambeson if tier == 1 else (mail if tier == 2 else M.metal(Color(0.78, 0.8, 0.85))), red if tier < 3 else gold)
		# sobreveste partida rojo/blanco (blanca con cruz dorada en la Maestría)
		for side: float in [-1.0, 1.0]:
			var f1 := red if side < 0.0 else white
			var f2 := white if side < 0.0 else red
			if tier == 3:
				f1 = white
				f2 = white
			M.box(c, Vector3(0.095, 0.27, 0.02), f1, Vector3(0.0475 * side, 0.14, -0.124), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.095, 0.27, 0.02), f2, Vector3(0.0475 * side, 0.14, 0.124), Vector3(4, 0, 0))
		if tier == 3:
			M.box(c, Vector3(0.03, 0.2, 0.012), gold, Vector3(0, 0.15, -0.137), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.12, 0.03, 0.012), gold, Vector3(0, 0.19, -0.138), Vector3(-4, 0, 0))
			M.box(c, Vector3(0.19, 0.02, 0.024), gold, Vector3(0, 0.01, -0.12))
			# capa corta roja con borde dorado
			M.box(c, Vector3(0.26, 0.3, 0.02), red, Vector3(0, 0.16, 0.14), Vector3(10, 0, 0))
			M.box(c, Vector3(0.27, 0.025, 0.026), gold, Vector3(0, 0.02, 0.165), Vector3(10, 0, 0))
		if tier >= 2:
			# hombreras y gola de acero (doradas en la Maestría)
			for sx: float in [-1.0, 1.0]:
				M.sphere(c, 0.072, gold if tier == 3 else steel, Vector3(0.135 * sx, 0.285, 0), Vector3(1, 0.7, 1), 10)
			M.cyl(c, 0.075, 0.09, 0.04, steel, Vector3(0, 0.34, 0), Vector3.ZERO, 12)
	var belt := TorusMesh.new()
	belt.inner_radius = 0.13
	belt.outer_radius = 0.155
	M.add(c, belt, leather, Vector3(0, 0.09, 0))
	# carcaj de virotes en la cadera
	M.box(c, Vector3(0.07, 0.15, 0.06), leather, Vector3(-0.16, 0.08, 0.05), Vector3(0, 0, -10))
	for k in 3:
		M.cyl(c, 0.008, 0.008, 0.06, M.mat(Color(0.5, 0.32, 0.16)), Vector3(-0.18 + k * 0.02, 0.18, 0.05), Vector3.ZERO, 4)
	for sx: float in [-1.0, 1.0]:
		M.cyl(c, 0.045, 0.05, 0.05, leather, Vector3(0.06 * sx, 0.01, -0.02), Vector3.ZERO, 8)
	if tier == 0:
		var h0 := Human.head(c, true, true, Color(0.4, 0.26, 0.14))
		M.sphere(h0, 0.15, M.mat(Color(0.74, 0.64, 0.46)), Vector3(0, 0.055, 0.025), Vector3(1.0, 0.78, 1.0), 14)
		M.cyl(h0, 0.15, 0.15, 0.03, M.mat(Color(0.6, 0.5, 0.34)), Vector3(0, 0.02, 0.02), Vector3(-6, 0, 0), 16)
		return
	# cabeza con almófar de malla y capacete de ala caída
	var hat := steel if tier < 3 else M.metal(Color(0.85, 0.87, 0.92))
	var h := Human.head(c, false, false)
	M.sphere(h, 0.148, mail, Vector3(0, 0.0, 0.035), Vector3(1.0, 1.05, 1.0), 14)
	M.cyl(h, 0.13, 0.17, 0.09, mail, Vector3(0, -0.14, 0.01), Vector3.ZERO, 14)
	M.sphere(h, 0.148, hat, Vector3(0, 0.07, 0.02), Vector3(1.02, 0.75, 1.02), 14)
	M.cyl(h, 0.15, 0.21, 0.035, hat, Vector3(0, 0.055, 0.02), Vector3.ZERO, 16)
	M.box(h, Vector3(0.02, 0.02, 0.15), gold if tier == 3 else M.metal(IRON), Vector3(0, 0.168, 0.03))
	if tier == 3:
		M.cyl(h, 0.212, 0.212, 0.012, gold, Vector3(0, 0.045, 0.02), Vector3.ZERO, 18)
	if tier >= 2:
		# penacho (rojo; blanco y rojo en la Maestría)
		for k in 3:
			M.sphere(h, 0.035, white if tier == 3 and k != 1 else red, Vector3(0, 0.19 + k * 0.012, 0.06 + k * 0.04), Vector3(0.6, 1.0, 1.4), 8)


# --- Ballesta pesada (retrocede con _xbow) ---

func _build_weapon(w: Node3D) -> void:
	var wood := M.tex_mat("wood", 2.0, Color(0.72, 0.52, 0.38))
	var timber := M.mat(TIMBER)
	var iron := M.metal(IRON)
	var steel := M.metal(STEEL)
	# Caja (tablero) con nuez y llave
	M.box(w, Vector3(0.06, 0.05, 0.44), wood, Vector3(0, 0.0, -0.17))
	M.box(w, Vector3(0.075, 0.07, 0.1), wood, Vector3(0, -0.01, 0.0))
	M.box(w, Vector3(0.018, 0.01, 0.4), timber, Vector3(0, 0.027, -0.18))
	M.cyl(w, 0.018, 0.018, 0.07, iron, Vector3(0, 0.02, NOCK_DRAWN), Vector3(0, 0, 90), 8)
	M.box(w, Vector3(0.012, 0.12, 0.012), iron, Vector3(0, -0.07, -0.05), Vector3(-25, 0, 0))
	# Arco de acero (curvo hacia delante) y estribo
	var pts: Array[Vector3] = []
	for k in 7:
		var u := -1.0 + 2.0 * k / 6.0
		pts.append(Vector3(u * PROD_HALF, 0.02, PROD_Z + (1.0 - u * u) * -0.05 + 0.05))
	var prod := steel if tier > 0 else M.mat(Color(0.45, 0.28, 0.14))
	for k in 6:
		M.segment(w, 0.017, prod, pts[k], pts[k + 1], 6)
	if tier == 3:
		var gold := M.metal(GOLD)
		for z: float in [-0.05, -0.28]:
			M.box(w, Vector3(0.072, 0.062, 0.025), gold, Vector3(0, 0.0, z))
		M.sphere(w, 0.022, gold, Vector3(0, 0.04, PROD_Z), Vector3.ONE, 8)
	M.box(w, Vector3(0.08, 0.05, 0.05), iron, Vector3(0, 0.01, PROD_Z))
	M.segment(w, 0.01, iron, Vector3(-0.04, 0.0, PROD_Z - 0.02), Vector3(0, 0.0, PROD_Z - 0.1), 4)
	M.segment(w, 0.01, iron, Vector3(0.04, 0.0, PROD_Z - 0.02), Vector3(0, 0.0, PROD_Z - 0.1), 4)
	# Soportes del torno en la culata
	for sx: float in [-1.0, 1.0]:
		M.box(w, Vector3(0.012, 0.06, 0.04), iron, WINDLASS + Vector3(0.045 * sx, -0.01, 0))


func _build_moving_parts() -> void:
	var iron := M.metal(IRON)
	var timber := M.mat(TIMBER)
	var rope := M.mat(ROPE)
	var steel := M.metal(STEEL)
	# Torno de manivelas
	_windlass = Node3D.new()
	_windlass.position = WINDLASS
	_xbow.add_child(_windlass)
	M.cyl(_windlass, 0.022, 0.022, 0.1, timber, Vector3.ZERO, Vector3(0, 0, 90), 8)
	for sx: float in [-1.0, 1.0]:
		M.box(_windlass, Vector3(0.012, 0.018, CRANK_R * 2.0 + 0.02), iron, Vector3(0.065 * sx, 0, 0))
		M.cyl(_windlass, 0.011, 0.011, 0.05, timber, Vector3(0.09 * sx, 0, CRANK_R * sx), Vector3(0, 0, 90), 6)
	# Cuerda del arco y cordel del torno
	_str_r = M.add(_xbow, M.tube_mesh(0.006, 4), rope)
	_str_l = M.add(_xbow, M.tube_mesh(0.006, 4), rope)
	_cord = M.add(_xbow, M.tube_mesh(0.005, 4), M.mat(Color(0.6, 0.5, 0.36)))
	# Virote (cola en el origen, apunta a -Z)
	_bolt = Node3D.new()
	_xbow.add_child(_bolt)
	M.cyl(_bolt, 0.011, 0.011, BOLT_LEN, M.mat(Color(0.5, 0.32, 0.16)), Vector3(0, 0, -BOLT_LEN * 0.5), Vector3(90, 0, 0), 6)
	M.cyl(_bolt, 0.0, 0.024, 0.07, steel, Vector3(0, 0, -BOLT_LEN - 0.03), Vector3(-90, 0, 0), 4)
	M.box(_bolt, Vector3(0.06, 0.005, 0.06), M.mat(RED), Vector3(0, 0, -0.04))
	M.box(_bolt, Vector3(0.005, 0.05, 0.06), M.mat(WHITE), Vector3(0, 0.015, -0.04))
	# Brazos del ballestero
	var sleeve: Material = [M.mat(Color(0.6, 0.48, 0.32)), M.mat(Color(0.6, 0.48, 0.32)), M.metal(MAIL), M.metal(Color(0.78, 0.8, 0.85))][tier]
	var glove := M.mat(Color(0.36, 0.22, 0.12))
	_arm_l = M.add(cat_pivot, M.tube_mesh(0.042, 8), sleeve)
	_arm_r = M.add(cat_pivot, M.tube_mesh(0.042, 8), sleeve)
	_hand_l = M.sphere(cat_pivot, 0.042, glove, Vector3.ZERO, Vector3.ONE, 8)
	_hand_r = M.sphere(cat_pivot, 0.042, glove, Vector3.ZERO, Vector3.ONE, 8)


# =====================================================================
# --- Etapas visuales ---
# =====================================================================

func _build_tier_fx() -> void:
	var py: float = PLAT_BY_TIER[tier]
	match tier:
		0:
			_pennants.append(Arch.pennant_node(self, Vector3(-0.34, py + 0.27, -0.34), RED, WHITE, 0.22, 0.4))
		1:
			_flames.append(Arch.flame_node(self, Vector3(0.0, 0.66, 0.5)))
		2:
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.23 * sx, 0.47, 0.37 + 0.075)))
				_pennants.append(Arch.pennant_node(self, Vector3(0.36 * sx, py + 0.86, -0.36), RED, WHITE, 0.28, 0.4 if sx < 0.0 else 2.7))
		3:
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.23 * sx, 0.47, 0.35 + 0.075), 1.1, Color(1.0, 0.82, 0.4)))
				_pennants.append(Arch.pennant_node(self, Vector3(0.35 * sx, py + 0.97, -0.35), RED, GOLD, 0.32, 0.4 if sx < 0.0 else 2.7))
			_spinners.append(Arch.aura_ring(self, 0.47, Color(1.0, 0.85, 0.4), 0.12))
			add_child(Arch.sparkles(Color(1.0, 0.88, 0.5), Vector3(0, 0.7, 0), Vector3(0.45, 0.6, 0.45), 18, 0.012))


# Pasaje abovedado con rastrillo en la cara z = half * sz
static func _gate(p: Node3D, sz: float, half: float, stones: Array, black: Material, bars: Material) -> void:
	var g := Node3D.new()
	g.position = Vector3(0, 0, (half + 0.002) * sz)
	g.rotation.y = 0.0 if sz > 0.0 else PI
	p.add_child(g)
	M.cyl(g, 0.15, 0.15, 0.03, stones[2], Vector3(0, 0.26, 0), Vector3(90, 0, 0), 16)
	M.box(g, Vector3(0.3, 0.2, 0.03), stones[2], Vector3(0, 0.16, 0))
	M.cyl(g, 0.12, 0.12, 0.032, black, Vector3(0, 0.26, 0.002), Vector3(90, 0, 0), 16)
	M.box(g, Vector3(0.24, 0.2, 0.032), black, Vector3(0, 0.16, 0.002))
	for k in 5:
		M.box(g, Vector3(0.016, 0.24, 0.016), bars, Vector3(-0.1 + k * 0.05, 0.27, 0.022))
		M.cyl(g, 0.0, 0.01, 0.03, bars, Vector3(-0.1 + k * 0.05, 0.14, 0.022), Vector3(180, 0, 0), 4)
	for y: float in [0.2, 0.28, 0.36]:
		M.box(g, Vector3(0.22, 0.014, 0.016), bars, Vector3(0, y, 0.024))
	for k in 7:
		var a := PI * k / 6.0
		M.box(g, Vector3(0.05, 0.04, 0.035), stones[k % 3], Vector3(cos(a) * 0.15, 0.26 + sin(a) * 0.15, 0.004), Vector3(0, 0, rad_to_deg(a) + 90.0))


# Etapa 0: blocao de empalizada con suelo de tablones y estacas afiladas
func _tower_t0(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[0]
	var bark := M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36))
	var bark2 := M.tex_mat("wood", 2.5, Color(0.58, 0.43, 0.3))
	var log_dark := M.mat(Color(0.4, 0.26, 0.15))
	var plank := M.tex_mat("wood", 2.0, Color(0.88, 0.74, 0.55))
	var plank2 := M.tex_mat("wood", 2.0, Color(0.76, 0.6, 0.43))
	var iron := M.metal(IRON)
	var rope := M.mat(ROPE)
	M.cyl(p, 0.45, 0.47, 0.03, M.mat(Color(0.52, 0.4, 0.27)), Vector3(0, 0.015, 0), Vector3.ZERO, 16)
	var half := 0.31
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, face.x)
		for k in 7:
			var o := -0.27 + k * 0.09
			var h := py - 0.05 + (k % 2) * 0.02
			M.cyl(p, 0.042, 0.046, h, bark if k % 2 == 0 else bark2, face * half + tg * o + Vector3(0, h * 0.5, 0), Vector3.ZERO, 8)
		for y: float in [0.16, 0.5]:
			M.box(p, tg.abs() * 0.66 + Vector3(0, 0.035, 0) + face.abs() * 0.03, log_dark, face * (half + 0.045) + Vector3(0, y, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var cp := Vector3(0.34 * sx, 0, 0.34 * sz)
			M.cyl(p, 0.052, 0.056, py + 0.2, bark, cp + Vector3(0, (py + 0.2) * 0.5, 0), Vector3.ZERO, 8)
			M.cyl(p, 0.0, 0.052, 0.08, log_dark, cp + Vector3(0, py + 0.24, 0), Vector3.ZERO, 8)
			M.cyl(p, 0.06, 0.06, 0.03, rope, cp + Vector3(0, py - 0.1, 0), Vector3.ZERO, 8)
	# suelo de tablones en voladizo
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.9, 0.05, 0.06), log_dark, Vector3(0, py - 0.065, 0.36 * s))
	for k in 8:
		M.box(p, Vector3(0.84 + (k % 3) * 0.02, 0.04, 0.1), plank if k % 2 == 0 else plank2, Vector3((k % 2) * 0.012, py - 0.02, -0.37 + k * 0.105), Vector3(0, (k % 3 - 1) * 2.0, 0))
	# parapeto de estacas afiladas
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, face.x)
		for k in 5:
			var o := -0.24 + k * 0.12
			var sp := face * 0.4 + tg * o
			M.cyl(p, 0.026, 0.028, 0.15, bark2, sp + Vector3(0, py + 0.075, 0), Vector3.ZERO, 6)
			M.cyl(p, 0.0, 0.026, 0.06, log_dark, sp + Vector3(0, py + 0.18, 0), Vector3.ZERO, 6)
		M.box(p, tg.abs() * 0.74 + Vector3(0, 0.03, 0) + face.abs() * 0.03, log_dark, face * 0.42 + Vector3(0, py + 0.08, 0))
	# puerta de tablones con herrajes
	M.box(p, Vector3(0.2, 0.36, 0.03), plank2, Vector3(0, 0.18, half + 0.05))
	for y: float in [0.09, 0.27]:
		M.box(p, Vector3(0.21, 0.025, 0.01), iron, Vector3(0, y, half + 0.067))
	M.sphere(p, 0.014, iron, Vector3(0.06, 0.18, half + 0.07), Vector3.ONE, 6)
	# escalera en el lado +X
	for sz: float in [-1.0, 1.0]:
		M.segment(p, 0.018, bark, Vector3(0.47, 0.0, 0.1 * sz), Vector3(0.44, py + 0.1, 0.1 * sz), 6)
	for k in 6:
		var f := (k + 0.6) / 6.5
		M.box(p, Vector3(0.025, 0.022, 0.22), log_dark, Vector3(lerpf(0.47, 0.44, f), f * (py + 0.1), 0))
	# paveses de tablas sin pintar apoyados en el parapeto
	for sx: float in [-1.0, 1.0]:
		var n := Node3D.new()
		n.position = Vector3(0.18 * sx, py + 0.1, 0.45)
		n.rotation = Vector3(-0.15, 0, 0.05 * sx)
		p.add_child(n)
		M.box(n, Vector3(0.14, 0.2, 0.022), plank, Vector3.ZERO)
		M.box(n, Vector3(0.15, 0.025, 0.028), log_dark, Vector3(0, 0.06, 0))
		M.box(n, Vector3(0.15, 0.025, 0.028), log_dark, Vector3(0, -0.06, 0))
	# caja de virotes y tonel
	M.box(p, Vector3(0.1, 0.09, 0.15), plank2, Vector3(-0.42, 0.045, -0.15))
	for k in 3:
		M.cyl(p, 0.007, 0.007, 0.08, M.mat(Color(0.5, 0.32, 0.16)), Vector3(-0.42, 0.11, -0.2 + k * 0.05), Vector3(20, 0, 0), 4)
	M.cyl(p, 0.06, 0.055, 0.14, plank, Vector3(-0.41, 0.07, 0.1), Vector3.ZERO, 12)
	for y: float in [0.03, 0.11]:
		M.cyl(p, 0.063, 0.063, 0.014, log_dark, Vector3(-0.41, y, 0.1), Vector3.ZERO, 12)
	Arch._ground_details(p, false)


# Contrafuertes de esquina en talud
static func _buttresses(p: Node3D, half: float, h: float, m: Material, cap: Material) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(p, Vector3(0.13, h, 0.13), m, Vector3(half * sx, h * 0.5, half * sz))
			M.cyl(p, 0.0, 0.092, 0.09, cap, Vector3(half * sx, h + 0.04, half * sz), Vector3(0, 45, 0), 4)


# Etapa 2: casa-puerta de sillares con torreones, matacanes, paveses heráldicos y antorchas
func _tower_t2(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[2]
	var half := 0.37
	var wall := M.tex_mat("bricks", 2.2, Color(0.86, 0.84, 0.79))
	var stones: Array[Material] = [M.mat(Color(0.62, 0.6, 0.56)), M.mat(Color(0.53, 0.51, 0.48)), M.mat(Color(0.68, 0.66, 0.62))]
	var dark := M.mat(STONE_DARK)
	var slate := M.tex_mat("roof", 3.0, Color(0.55, 0.6, 0.72))
	var iron := M.metal(IRON)
	var black := M.mat(Color(0.07, 0.06, 0.06))
	var gold := M.metal(GOLD)
	Arch._stone_keep(p, py, half, wall, stones, dark, stones[2], null, [[0, 1], [1, 1]])
	_buttresses(p, half, 0.46, stones[1], stones[2])
	for sz: float in [-1.0, 1.0]:
		_gate(p, sz, half, stones, black, iron)
	M.box(p, Vector3(0.3, 0.04, 0.16), stones[0], Vector3(0, 0.02, 0.45))
	Arch._slits(p, half, [0.75], black)
	for sx: float in [-1.0, 1.0]:
		var top := Arch.turret(p, Vector3(0.36 * sx, 0, -0.36), 0.12, py - 0.3, py + 0.28, wall, slate, 0.38, stones[2], gold)
		M.cyl(p, 0.007, 0.007, 0.2, iron, top + Vector3(0, 0.1, 0), Vector3.ZERO, 4)
		Arch.wall_torch(p, Vector3(0.23 * sx, 0.42, half), Vector3(0, 0, 1), iron)
	# paveses pintados colgados del parapeto (frente y costados)
	var kinds := [0, 1, 2, 0, 1, 2]
	var i := 0
	for face: Vector3 in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var tg := Vector3(face.z, 0, -face.x)
		for off: float in [-0.19, 0.19]:
			var k: int = kinds[i]
			pavise(p, face * (half + 0.1) + tg * off + Vector3(0, py - 0.02, 0), atan2(face.x, face.z), k)
			i += 1
	Arch.hang_banner(p, Vector3(0, py - 0.24, half + 0.014), 0.0, 0.18, 0.3, M.mat(RED), gold, M.mat(WHITE), 0)
	Arch._ground_details(p, false)


# Etapa 3 (Maestría): casa-puerta de mármol blanco y oro con cuatro torreones de tejado azul
func _tower_t3(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[3]
	var half := 0.36
	var wall := M.tex_mat("bricks", 2.2, MARBLE)
	var stones: Array[Material] = [M.mat(Color(0.93, 0.91, 0.86)), M.mat(Color(0.86, 0.84, 0.8)), M.mat(Color(1.0, 0.98, 0.94))]
	var dark := M.mat(Color(0.74, 0.72, 0.68))
	var gold := M.metal(GOLD)
	var slate := M.tex_mat("roof", 3.0, Color(0.42, 0.55, 0.95))
	var glow := M.mat(Color(1.0, 0.85, 0.5), 1.6)
	Arch._stone_keep(p, py, half, wall, stones, dark, gold, null, [[0, 1], [1, 1]])
	_buttresses(p, half, 0.5, stones[2], gold)
	M.box(p, Vector3(2.0 * half + 0.03, 0.025, 2.0 * half + 0.03), gold, Vector3(0, py * 0.36, 0))
	M.box(p, Vector3(2.0 * half + 0.18, 0.025, 2.0 * half + 0.18), gold, Vector3(0, py - 0.085, 0))
	for sz: float in [-1.0, 1.0]:
		_gate(p, sz, half, stones, glow, gold)
	M.box(p, Vector3(0.32, 0.04, 0.16), stones[2], Vector3(0, 0.02, 0.45))
	Arch._slits(p, half, [0.8, 1.05], glow)
	for sx: float in [-1.0, 1.0]:
		var top := Arch.turret(p, Vector3(0.35 * sx, 0, -0.35), 0.125, py - 0.3, py + 0.3, wall, slate, 0.44, gold, gold)
		M.cyl(p, 0.008, 0.008, 0.22, gold, top + Vector3(0, 0.11, 0), Vector3.ZERO, 4)
		Arch.turret(p, Vector3(0.35 * sx, 0, 0.35), 0.085, py - 0.12, py + 0.12, wall, slate, 0.2, gold, gold)
		Arch.wall_torch(p, Vector3(0.23 * sx, 0.42, half - 0.01), Vector3(0, 0, 1), gold)
		Arch.heater(p, Vector3((half + 0.012) * sx, py * 0.62, 0.0), PI * 0.5 * sx, 1.4, M.mat(RED), gold, gold)
	Arch.hang_banner(p, Vector3(0, py - 0.22, half + 0.014), 0.0, 0.22, 0.42, M.mat(RED), gold, gold, 0)
	Arch._ground_details(p, false)
