extends Node3D
## Modelo 3D del "Santuario Sagrado". Cambia de aspecto con la etapa visual (TowerModels.tier):
##   0 (nv 0-1): humilde santuario de camino: peana de lajas, campanil de madera con tejadillo de
##               tablillas, hornacina con una imagen, cruz de madera, velas y flores; novicia con
##               hábito pardo, toca blanca y un báculo de madera.
##   1 (nv 2-3): capillita de caliza con contrafuertes, vidrieras, rosetón y campanario abierto con
##               tejado de tablillas; sacerdotisa con túnica blanca, tabardo y escudo.
##   2 (nv 4):   capilla gótica más alta con adarve almenado, aguja de pizarra con buhardillas y
##               pináculos, cruz dorada y estandartes; sacerdotisa paladina con hombreras de acero.
##   3 (nv 5):   aguja de catedral gótica: piedra blanca con molduras doradas, pináculos altos con
##               remates de oro, aguja con bandas doradas y gran cruz radiante, vidrieras que brillan,
##               rayos de luz y motas doradas; paladina con armadura dorada, alas y gran halo.
## La sacerdotisa rodea el campanario al apuntar (mira hacia -Z dentro de cat_pivot).

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const ArcherModel := preload("res://scripts/towers3d/archer_model.gd")   # hierba de la base

const LIME := Color(0.86, 0.84, 0.78)
const LIME_DARK := Color(0.72, 0.7, 0.65)
const MARBLE := Color(0.97, 0.96, 0.92)
const SLATE := Color(0.34, 0.35, 0.4)
const GOLD := Color(1.0, 0.8, 0.32)
const BRONZE := Color(0.72, 0.5, 0.22)
const IRON := Color(0.25, 0.25, 0.28)
const WOOD := Color(0.42, 0.26, 0.14)
const HOLY := Color(1.0, 0.86, 0.45)
const GLASS_BLUE := Color(0.2, 0.4, 0.95)
const GLASS_RED := Color(0.9, 0.18, 0.2)
const GLASS_GOLD := Color(1.0, 0.75, 0.2)
const GLASS_GREEN := Color(0.25, 0.75, 0.35)
const ROBE := Color(0.97, 0.96, 0.92)
const HABIT := Color(0.5, 0.38, 0.26)
const BLONDE := Color(0.93, 0.78, 0.45)

const PLATFORM_HEIGHTS := [0.22, 0.6, 0.72, 0.84]
const SPIRE_HEIGHTS := [0.0, 0.32, 0.66, 0.9]
const OP_Z := -0.27            # la sacerdotisa se coloca delante del campanario
const SYMBOL_LOCAL := Vector3(0.17, 0.66, -0.13)
const FACES := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]

var cat_pivot: Node3D
var _tier := 0
var _py := 0.22
var _bell_y := 0.67            # punto del que cuelga la campana
var _holy_mat: StandardMaterial3D
var _light_mat: StandardMaterial3D
var _bell: Node3D
var _symbol: Node3D
var _light: MeshInstance3D
var _halo: Node3D
var _rays: Node3D


static func _tier_of(level: int) -> int:
	if level >= 5:
		return 3
	if level >= 4:
		return 2
	if level >= 2:
		return 1
	return 0


func _init(level := 0) -> void:
	_tier = _tier_of(level)
	_py = PLATFORM_HEIGHTS[_tier]
	_bell_y = _py + (0.45 if _tier == 0 else 0.39)
	M.add_baked(self, M.baked("sanctuary_tower_t%d" % _tier, _build_tower))
	_build_bell()
	if _tier == 3:
		_build_master_fx()
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, _py, 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("sanctuary_priestess_t%d" % _tier, _build_priestess_body))
	_build_priestess_parts()
	animate({"t": 0.0, "charge": 0.3, "fire": 0.0})


## s = {t, charge 0..1, fire 1 -> 0, has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = clampf(s.get("charge", 0.0), 0.0, 1.0)
	var fire: float = clampf(s.get("fire", 0.0), 0.0, 1.0)
	# La campana se balancea al disparar
	_bell.rotation.x = sin(t * 11.0) * fire * 0.7 + sin(t * 1.3) * 0.03
	# Luz sagrada que crece con la carga y destella al disparar
	var glow := 0.5 + charge * 1.3 + fire * 1.5 + (0.4 if _tier == 3 else 0.0)
	_holy_mat.emission_energy_multiplier = glow
	_light.scale = Vector3.ONE * (0.6 + charge * 0.9 + fire * 1.6 + sin(t * 4.0) * 0.05)
	_light_mat.albedo_color.a = 0.18 + charge * 0.2 + fire * 0.25
	_symbol.rotation.z = sin(t * 2.0) * 0.08
	_symbol.position.y = SYMBOL_LOCAL.y + fire * 0.04
	_halo.rotation.y = t * 0.8
	_halo.scale = Vector3.ONE * (1.0 + charge * 0.15)
	if _rays:
		_rays.rotation.y = t * 0.3


func muzzle_global() -> Vector3:
	return _symbol.global_position


# --- Adornos ---

# Arco gótico apuntado (rectángulo + rombo) en un nodo que mira hacia +Z local
static func gothic_arch(parent: Node3D, pos: Vector3, facing: Vector3, w: float, h: float, m: Material, depth := 0.02) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = atan2(facing.x, facing.z)
	parent.add_child(n)
	var rect_h := h - w * 0.5
	M.box(n, Vector3(w, rect_h, depth), m, Vector3(0, rect_h * 0.5, 0))
	var d := w / sqrt(2.0)
	M.box(n, Vector3(d, d, depth), m, Vector3(0, rect_h, 0), Vector3(0, 0, 45))
	return n


# Ventana ojival con vidriera de colores y emplomado
static func stained_window(parent: Node3D, pos: Vector3, facing: Vector3, w: float, h: float, frame_m: Material = null, bright := 0.9) -> void:
	var frame := gothic_arch(parent, pos, facing, w + 0.04, h + 0.03, frame_m if frame_m else M.mat(LIME_DARK))
	var glass := gothic_arch(frame, Vector3(0, 0.015, 0.008), Vector3(0, 0, 1), w, h, M.mat(GLASS_BLUE, bright))
	var rect_h := h - w * 0.5
	var lead := M.mat(Color(0.18, 0.17, 0.2))
	# paneles de colores
	M.box(glass, Vector3(w * 0.34, rect_h * 0.55, 0.02), M.mat(GLASS_RED, bright), Vector3(0, rect_h * 0.4, 0.003))
	M.box(glass, Vector3(w * 0.3, w * 0.3, 0.02), M.mat(GLASS_GOLD, bright + 0.1), Vector3(0, rect_h + w * 0.08, 0.003), Vector3(0, 0, 45))
	M.box(glass, Vector3(w * 0.8, rect_h * 0.12, 0.02), M.mat(GLASS_GREEN, bright), Vector3(0, rect_h * 0.08, 0.003))
	# emplomado
	M.box(glass, Vector3(0.008, h * 0.95, 0.024), lead, Vector3(0, h * 0.47, 0.004))
	for f: float in [0.3, 0.68]:
		M.box(glass, Vector3(w, 0.007, 0.024), lead, Vector3(0, rect_h * f, 0.004))
	# alféizar
	M.box(frame, Vector3(w + 0.07, 0.025, 0.04), frame_m if frame_m else M.mat(LIME), Vector3(0, 0.0, 0.01))


# Cruz (en el plano XY, mirando a +Z)
static func cross(parent: Node3D, pos: Vector3, s: float, m: Material, depth := 0.02) -> void:
	M.box(parent, Vector3(0.025 * s, 0.11 * s, depth), m, pos)
	M.box(parent, Vector3(0.075 * s, 0.022 * s, depth), m, pos + Vector3(0, 0.022 * s, 0))


# --- Torre ---

func _build_tower(parent: Node3D) -> void:
	if _tier == 0:
		_build_wayside(parent)
	else:
		_build_chapel(parent)
	ArcherModel._ground_details(parent, false)


# Etapa 0: santuario de camino con campanil de madera
func _build_wayside(parent: Node3D) -> void:
	var flag := [M.mat(Color(0.56, 0.54, 0.5)), M.mat(Color(0.48, 0.46, 0.43)), M.mat(Color(0.62, 0.6, 0.56))]
	var wood := M.tex_mat("wood", 2.2, Color(0.72, 0.55, 0.4))
	var wood_dark := M.mat(WOOD)
	var shingle := M.tex_mat("wood", 3.0, Color(0.55, 0.4, 0.3))
	var gold := M.metal(GOLD)
	var py := _py
	# Peana de lajas apiladas
	M.cyl(parent, 0.44, 0.46, 0.04, M.mat(Color(0.5, 0.42, 0.32)), Vector3(0, 0.02, 0), Vector3.ZERO, 12)
	M.box(parent, Vector3(0.76, py - 0.1, 0.72), flag[1], Vector3(0, 0.04 + (py - 0.1) * 0.5, 0), Vector3(0, 3, 0))
	M.box(parent, Vector3(0.7, 0.07, 0.68), flag[2], Vector3(0, py - 0.035, 0), Vector3(0, -4, 0))
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		M.box(parent, Vector3(0.14, 0.06, 0.1), flag[i % 3], Vector3(cos(a) * 0.4, 0.05, sin(a) * 0.38), Vector3(0, -rad_to_deg(a), 0))
	# Campanil de madera: dos postes, travesaño y tejadillo de tablillas a dos aguas
	var beam_y := _bell_y + 0.03
	for sx: float in [-1.0, 1.0]:
		M.cyl(parent, 0.028, 0.032, beam_y - py + 0.06, wood, Vector3(0.17 * sx, py + (beam_y - py + 0.06) * 0.5, 0), Vector3.ZERO, 6)
		M.segment(parent, 0.016, wood, Vector3(0.17 * sx, py + 0.02, -0.12), Vector3(0.17 * sx, py + 0.22, 0), 5)
		M.segment(parent, 0.016, wood, Vector3(0.17 * sx, py + 0.02, 0.12), Vector3(0.17 * sx, py + 0.22, 0), 5)
	M.box(parent, Vector3(0.42, 0.04, 0.05), wood_dark, Vector3(0, beam_y, 0))
	for s: float in [-1.0, 1.0]:
		var rf := Node3D.new()
		rf.position = Vector3(0, beam_y + 0.09, 0.07 * s)
		rf.rotation.x = 0.75 * s
		parent.add_child(rf)
		M.box(rf, Vector3(0.48, 0.02, 0.2), shingle)
		for k in 3:
			M.box(rf, Vector3(0.5, 0.012, 0.02), wood_dark, Vector3(0, 0.014, -0.07 + k * 0.07))
	M.box(parent, Vector3(0.5, 0.03, 0.03), wood_dark, Vector3(0, beam_y + 0.16, 0))
	cross(parent, Vector3(0, beam_y + 0.24, 0), 0.9, wood_dark, 0.025)
	# Hornacina de piedra con una imagen y velas (detrás a la izquierda)
	var nich := Vector3(-0.27, py, 0.24)
	M.box(parent, Vector3(0.16, 0.24, 0.12), flag[2], nich + Vector3(0, 0.12, 0))
	M.cyl(parent, 0.0, 0.12, 0.08, shingle, nich + Vector3(0, 0.28, 0), Vector3(0, 45, 0), 4)
	M.box(parent, Vector3(0.1, 0.14, 0.02), M.mat(Color(0.3, 0.26, 0.24)), nich + Vector3(0, 0.13, 0.055))
	M.sphere(parent, 0.025, M.mat(ROBE), nich + Vector3(0, 0.17, 0.05), Vector3.ONE, 8)
	M.cyl(parent, 0.02, 0.035, 0.08, M.mat(GLASS_BLUE.lightened(0.3)), nich + Vector3(0, 0.1, 0.05), Vector3.ZERO, 8)
	M.cyl(parent, 0.035, 0.035, 0.006, gold, nich + Vector3(0, 0.2, 0.04), Vector3(90, 0, 0), 10)
	var wax := M.mat(Color(0.95, 0.92, 0.82))
	var flame := M.mat(HOLY, 2.2)
	for p: Vector3 in [Vector3(-0.17, py, 0.3), Vector3(-0.36, py, 0.31), Vector3(-0.12, py, 0.24)]:
		M.cyl(parent, 0.014, 0.017, 0.05, wax, p + Vector3(0, 0.025, 0), Vector3.ZERO, 6)
		M.cyl(parent, 0.0, 0.01, 0.025, flame, p + Vector3(0, 0.063, 0), Vector3.ZERO, 5)
	# Cruz de madera y ramo de flores silvestres
	var cp := Vector3(0.36, py, 0.22)
	M.box(parent, Vector3(0.035, 0.32, 0.035), wood_dark, cp + Vector3(0, 0.16, 0))
	M.box(parent, Vector3(0.18, 0.035, 0.035), wood_dark, cp + Vector3(0, 0.24, 0))
	M.segment(parent, 0.005, M.mat(Color(0.8, 0.68, 0.48)), cp + Vector3(-0.02, 0.24, 0.02), cp + Vector3(0.02, 0.22, 0.02), 4)
	for k in 5:
		var fp := cp + Vector3(-0.05 + k * 0.025, 0.02, 0.05)
		M.segment(parent, 0.004, M.mat(Color(0.3, 0.55, 0.2)), fp, fp + Vector3(0, 0.06, 0), 4)
		M.sphere(parent, 0.014, M.mat([Color.WHITE, Color(1.0, 0.85, 0.3), Color(1.0, 0.6, 0.75)][k % 3]), fp + Vector3(0, 0.065, 0), Vector3.ONE, 6)
	# Banco de madera a un lado del camino
	M.box(parent, Vector3(0.08, 0.025, 0.24), wood, Vector3(0.42, 0.12, -0.18))
	for z: float in [-0.27, -0.09]:
		M.box(parent, Vector3(0.06, 0.1, 0.025), wood_dark, Vector3(0.42, 0.06, z))


# Etapas 1-3: capilla de caliza (2: aguja de pizarra; 3: aguja de catedral blanca y dorada)
func _build_chapel(parent: Node3D) -> void:
	var t := _tier
	var master := t == 3
	# piedra por etapa: arenisca tostada (1), caliza gris (2), mármol blanco (3)
	var stone_cols := [LIME, Color(0.74, 0.67, 0.55), Color(0.78, 0.78, 0.76), MARBLE]
	var dark_cols := [LIME_DARK, Color(0.6, 0.53, 0.43), Color(0.6, 0.61, 0.62), Color(0.84, 0.82, 0.76)]
	var lime := M.mat(stone_cols[t])
	var lime_dark := M.mat(dark_cols[t])
	var slate := M.mat(SLATE.lightened(0.08))
	var slate_m := M.mat(SLATE)
	if master:
		slate = M.tex_mat("roof", 3.0, Color(0.75, 0.85, 1.3))
		slate_m = M.mat(Color(0.3, 0.4, 0.75))
	var gold := M.metal(GOLD)
	var trim: Material = gold if master else lime_dark
	var iron := M.metal(IRON)
	var wood := M.tex_mat("wood", 2.0, Color(0.8, 0.6, 0.45))
	var shingle := M.tex_mat("wood", 3.0, Color(0.55, 0.4, 0.3))
	var py := _py
	var wall_h := py - 0.12
	var bright := 0.9 if not master else 1.6

	# Zócalo y cuerpo de la capilla
	M.box(parent, Vector3(0.92, 0.08, 0.92), M.mat(Color(0.6, 0.59, 0.56) if not master else Color(0.8, 0.78, 0.72)), Vector3(0, 0.04, 0))
	M.box(parent, Vector3(0.74, 0.06, 0.74), lime_dark, Vector3(0, 0.11, 0))
	if master:
		M.box(parent, Vector3(0.76, 0.02, 0.76), gold, Vector3(0, 0.145, 0))
	M.box(parent, Vector3(0.68, wall_h, 0.68), lime, Vector3(0, 0.1 + wall_h * 0.5, 0))
	M.box(parent, Vector3(0.72, 0.04, 0.72), trim, Vector3(0, py - 0.06, 0))
	# sillares de caliza en relieve (dejando libres puerta y ventanas)
	var blocks: Array
	if master:
		blocks = [M.mat(Color(0.94, 0.92, 0.86)), M.mat(Color(0.99, 0.98, 0.94)), M.mat(Color(0.9, 0.88, 0.82))]
	else:
		var bc: Color = stone_cols[t]
		blocks = [M.mat(bc.darkened(0.08)), M.mat(bc.lightened(0.06)), M.mat(bc.darkened(0.16))]
	ArcherModel._stone_blocks(parent, 0.34, 0.17, 3 if t < 3 else 4, [[0, 1], [1, 1], [2, 1], [3, 1]], blocks)
	# Contrafuertes escalonados en las esquinas con pináculos
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var cp := Vector3(0.35 * sx, 0, 0.35 * sz)
			var lo_h := wall_h * 0.6
			M.box(parent, Vector3(0.11, lo_h, 0.11), lime, cp + Vector3(0.012 * sx, 0.07 + lo_h * 0.5, 0.012 * sz))
			M.box(parent, Vector3(0.09, wall_h * 0.45, 0.09), lime, cp + Vector3(0, py - 0.14, 0))
			M.cyl(parent, 0.0, 0.05, 0.08, trim, cp + Vector3(0.012 * sx, 0.11 + lo_h, 0.012 * sz), Vector3(0, 45, 0), 4)
			if t == 3:
				# pináculo alto con remate dorado que sobresale del adarve
				M.box(parent, Vector3(0.08, 0.26, 0.08), lime, cp + Vector3(0.02 * sx, py + 0.13, 0.02 * sz))
				M.box(parent, Vector3(0.095, 0.02, 0.095), gold, cp + Vector3(0.02 * sx, py + 0.27, 0.02 * sz))
				M.cyl(parent, 0.0, 0.05, 0.26, lime, cp + Vector3(0.02 * sx, py + 0.41, 0.02 * sz), Vector3(0, 45, 0), 4)
				M.sphere(parent, 0.02, gold, cp + Vector3(0.02 * sx, py + 0.55, 0.02 * sz), Vector3.ONE, 8)
				M.cyl(parent, 0.0, 0.01, 0.07, gold, cp + Vector3(0.02 * sx, py + 0.6, 0.02 * sz), Vector3.ZERO, 5)
				for k in 2:
					M.sphere(parent, 0.016, gold, cp + Vector3(0.02 * sx + 0.05 * sx, py + 0.33 + k * 0.1, 0.02 * sz), Vector3(0.6, 1.4, 0.6), 5)

	# Puerta ojival de madera con herrajes (frente +Z), rosetón encima
	var door := gothic_arch(parent, Vector3(0, 0.14, 0.342), Vector3(0, 0, 1), 0.2, 0.28, trim if master else lime_dark)
	var leaf := gothic_arch(door, Vector3(0, 0.0, 0.008), Vector3(0, 0, 1), 0.16, 0.25, wood)
	M.box(leaf, Vector3(0.006, 0.24, 0.024), M.mat(Color(0.25, 0.15, 0.08)), Vector3(0, 0.12, 0.003))
	for y: float in [0.05, 0.15]:
		M.box(leaf, Vector3(0.15, 0.014, 0.026), gold if master else iron, Vector3(0, y, 0.004))
	M.sphere(leaf, 0.012, gold, Vector3(0.035, 0.1, 0.018), Vector3.ONE, 6)
	M.box(parent, Vector3(0.3, 0.04, 0.1), lime_dark, Vector3(0, 0.1, 0.4))
	var rose := Vector3(0, py - 0.15, 0.345)
	var rr := 0.055 if t < 3 else 0.07
	M.cyl(parent, rr, rr, 0.02, trim, rose, Vector3(90, 0, 0), 16)
	M.cyl(parent, rr - 0.011, rr - 0.011, 0.02, M.mat(GLASS_BLUE, bright), rose + Vector3(0, 0, 0.006), Vector3(90, 0, 0), 16)
	for i in 6:
		var a := TAU * i / 6.0
		M.sphere(parent, 0.013 * rr / 0.055, M.mat(GLASS_RED if i % 2 == 0 else GLASS_GOLD, bright + 0.1),
				rose + Vector3(cos(a) * 0.026, sin(a) * 0.026, 0.016) * Vector3(rr / 0.055, rr / 0.055, 1), Vector3(1, 1, 0.5), 6)
	M.sphere(parent, 0.012, M.mat(GLASS_GOLD, bright + 0.3), rose + Vector3(0, 0, 0.018), Vector3(1, 1, 0.5), 6)
	# Vidrieras en los otros tres lados
	var wh := minf(0.3 + (t - 1) * 0.08, wall_h - 0.2)
	for face: Vector3 in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		stained_window(parent, face * 0.342 + Vector3(0, 0.17, 0), face, 0.13, wh, gold if master else null, bright)
	# Estandartes blancos con cruz dorada a los lados de la puerta (etapas 2 y 3)
	if t >= 2:
		for s: float in [-1.0, 1.0]:
			var bx := 0.2 * s
			var top := py - 0.1
			M.box(parent, Vector3(0.12, 0.018, 0.018), gold if master else M.mat(WOOD), Vector3(bx, top, 0.36))
			M.box(parent, Vector3(0.1, 0.26, 0.012), M.mat(ROBE if not master else Color(0.2, 0.3, 0.75)), Vector3(bx, top - 0.13, 0.355))
			M.box(parent, Vector3(0.008, 0.26, 0.014), gold, Vector3(bx + 0.044, top - 0.13, 0.356))
			M.box(parent, Vector3(0.008, 0.26, 0.014), gold, Vector3(bx - 0.044, top - 0.13, 0.356))
			cross(parent, Vector3(bx, top - 0.11, 0.363), 0.8, gold, 0.01)
			for k: float in [-1.0, 1.0]:
				M.cyl(parent, 0.0, 0.03, 0.04, M.mat(ROBE if not master else Color(0.2, 0.3, 0.75)), Vector3(bx + 0.025 * k, top - 0.28, 0.355), Vector3(180, 0, 0), 4)

	# Adarve con almenas
	M.box(parent, Vector3(0.84, 0.05, 0.84), lime_dark, Vector3(0, py - 0.025, 0))
	for k in 6:
		var o: float = -0.32 + k * 0.128
		for face: Vector3 in FACES:
			var tg := Vector3(face.z, 0, face.x)
			M.box(parent, Vector3(0.045, 0.045, 0.045), lime, face * 0.4 + tg * o + Vector3(0, py - 0.065, 0))
	for k in 4:
		var o2: float = -0.33 + k * 0.22
		for face: Vector3 in FACES:
			var tg2 := Vector3(face.z, 0, face.x)
			var sz2 := Vector3(0.09, 0.07, 0.05) if absf(face.z) > 0.5 else Vector3(0.05, 0.07, 0.09)
			var mp := face * 0.395 + tg2 * o2 + Vector3(0, py + 0.035, 0)
			M.box(parent, sz2, lime, mp)
			if master:
				M.box(parent, sz2 * Vector3(1.1, 0.25, 1.1), gold, mp + Vector3(0, 0.04, 0))

	# Campanario abierto: pilares, arcos y viga de la campana
	var bt := py
	M.box(parent, Vector3(0.36, 0.04, 0.36), lime_dark, Vector3(0, bt + 0.02, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(parent, Vector3(0.065, 0.42, 0.065), lime, Vector3(0.145 * sx, bt + 0.25, 0.145 * sz))
	for face: Vector3 in FACES:
		var tg3 := Vector3(face.z, 0, face.x)
		var span := Vector3(0.36, 0.08, 0.05) if absf(face.z) > 0.5 else Vector3(0.05, 0.08, 0.36)
		M.box(parent, span, lime, face * 0.15 + Vector3(0, bt + 0.42, 0))
		# arco apuntado (dos piezas inclinadas bajo el dintel)
		for s: float in [-1.0, 1.0]:
			var n := Node3D.new()
			n.position = face * 0.15 + tg3 * (0.06 * s) + Vector3(0, bt + 0.355, 0)
			n.rotation.y = atan2(face.x, face.z)
			parent.add_child(n)
			M.box(n, Vector3(0.13, 0.03, 0.045), trim if master else lime, Vector3.ZERO, Vector3(0, 0, 30.0 * s))
	M.box(parent, Vector3(0.3, 0.035, 0.035), M.mat(WOOD), Vector3(0, _bell_y + 0.02, 0))
	M.box(parent, Vector3(0.38, 0.04, 0.38), trim, Vector3(0, bt + 0.48, 0))

	var sp := bt + 0.5
	var sh: float = SPIRE_HEIGHTS[t]
	if t == 1:
		# Tejado piramidal de tablillas con una cruz de hierro
		M.cyl(parent, 0.0, 0.27, sh, shingle, Vector3(0, sp + sh * 0.5, 0), Vector3(0, 45, 0), 4)
		M.cyl(parent, 0.27, 0.27, 0.025, M.mat(WOOD), Vector3(0, sp + 0.01, 0), Vector3(0, 45, 0), 4)
		M.sphere(parent, 0.02, iron, Vector3(0, sp + sh, 0), Vector3.ONE, 6)
		cross(parent, Vector3(0, sp + sh + 0.06, 0), 1.0, iron, 0.02)
		return

	# Aguja octogonal (pizarra; azul y oro en Maestría) con buhardillas, pináculos y cruz dorada
	var base_r := 0.2 if t == 2 else 0.22
	M.cyl(parent, 0.0, base_r, sh, slate, Vector3(0, sp + sh * 0.5, 0), Vector3(0, 22.5, 0), 8)
	M.cyl(parent, base_r + 0.01, base_r + 0.01, 0.03, trim if master else slate_m, Vector3(0, sp + 0.015, 0), Vector3(0, 22.5, 0), 8)
	# hileras en relieve (bandas doradas en Maestría)
	for f: float in [0.25, 0.45, 0.65, 0.8]:
		var rr2: float = base_r * (1.0 - f) + 0.008
		M.cyl(parent, rr2, rr2, 0.02, gold if master else slate_m, Vector3(0, sp + sh * f, 0), Vector3(0, 22.5, 0), 8)
	# buhardillas en la aguja
	for face: Vector3 in FACES:
		var dn := Node3D.new()
		dn.position = face * 0.13 + Vector3(0, sp + 0.13, 0)
		dn.rotation.y = atan2(face.x, face.z)
		parent.add_child(dn)
		M.box(dn, Vector3(0.07, 0.07, 0.06), lime, Vector3(0, 0, 0))
		M.cyl(dn, 0.0, 0.055, 0.06, slate_m, Vector3(0, 0.06, 0), Vector3(0, 45, 0), 4)
		M.box(dn, Vector3(0.03, 0.045, 0.02), M.mat(GLASS_GOLD, bright), Vector3(0, -0.005, 0.025))
		if master:
			M.sphere(dn, 0.01, gold, Vector3(0, 0.1, 0), Vector3.ONE, 5)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var pp := Vector3(0.17 * sx, sp + 0.02, 0.17 * sz)
			M.cyl(parent, 0.0, 0.035, 0.14 if t == 2 else 0.2, slate_m, pp + Vector3(0, 0.07 if t == 2 else 0.1, 0), Vector3(0, 45, 0), 4)
			M.sphere(parent, 0.013, gold, pp + Vector3(0, 0.15 if t == 2 else 0.21, 0), Vector3.ONE, 6)
	var top := sp + sh
	M.sphere(parent, 0.025 if t == 2 else 0.035, gold, Vector3(0, top, 0), Vector3.ONE, 8)
	cross(parent, Vector3(0, top + 0.07, 0), 1.3 if t == 2 else 1.7, gold, 0.025)
	if master:
		cross(parent, Vector3(0, top + 0.09, 0.0), 1.0, M.mat(HOLY, 2.4), 0.03)

	# Cruces de piedra (celtas) junto a la capilla
	for p: Vector3 in [Vector3(-0.43, 0, 0.3), Vector3(0.44, 0, -0.38)]:
		var g := Node3D.new()
		g.position = p
		g.rotation.y = 0.3
		parent.add_child(g)
		M.box(g, Vector3(0.08, 0.03, 0.05), lime_dark, Vector3(0, 0.015, 0))
		cross(g, Vector3(0, 0.08, 0), 1.0, lime, 0.025)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.016
		ring.outer_radius = 0.024
		M.add(g, ring, gold if master else lime, Vector3(0, 0.102, 0), Vector3(90, 0, 0))


# Campana de bronce que cuelga del campanario (animada)
func _build_bell() -> void:
	_bell = Node3D.new()
	_bell.position = Vector3(0, _bell_y, 0)
	add_child(_bell)
	var bronze := M.metal(GOLD if _tier == 3 else BRONZE)
	var s := 0.75 if _tier == 0 else 1.0
	M.cyl(_bell, 0.012, 0.012, 0.03, M.metal(IRON), Vector3(0, -0.01, 0), Vector3.ZERO, 6)
	M.sphere(_bell, 0.045 * s, bronze, Vector3(0, -0.05 * s, 0), Vector3(1, 0.8, 1), 12)
	M.cyl(_bell, 0.045 * s, 0.075 * s, 0.1 * s, bronze, Vector3(0, -0.1 * s, 0), Vector3.ZERO, 14)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.065 * s
	lip.outer_radius = 0.085 * s
	lip.rings = 16
	lip.ring_segments = 6
	M.add(_bell, lip, bronze, Vector3(0, -0.15 * s, 0))
	M.segment(_bell, 0.006, M.metal(IRON), Vector3(0, -0.17 * s, 0), Vector3(0, -0.06 * s, 0), 4)
	M.sphere(_bell, 0.018 * s, M.metal(IRON), Vector3(0, -0.175 * s, 0), Vector3.ONE, 6)


# Maestría: rayos de luz que giran alrededor de la aguja y motas doradas que ascienden
func _build_master_fx() -> void:
	_rays = Node3D.new()
	_rays.position = Vector3(0, _py + 0.5 + SPIRE_HEIGHTS[3] * 0.4, 0)
	add_child(_rays)
	var ray_m := StandardMaterial3D.new()
	ray_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ray_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray_m.albedo_color = Color(1.0, 0.9, 0.55, 0.2)
	for i in 6:
		var a := TAU * i / 6.0
		var r := Node3D.new()
		r.rotation.y = a
		_rays.add_child(r)
		M.add(r, M.box_mesh(Vector3(0.05, 0.9, 0.01)), ray_m, Vector3(0, 0, 0.12), Vector3(0, 0, 0))
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 1.8
	p.position = Vector3(0, _py * 0.6, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.45, _py * 0.5, 0.45)
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0, 0.15, 0)
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.16
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.0))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.02
	mesh.height = 0.04
	mesh.radial_segments = 4
	mesh.rings = 2
	mesh.material = M.mat(Color(1.0, 0.9, 0.5), 2.4)
	p.mesh = mesh
	add_child(p)


# --- Sacerdotisa paladina ---

func _build_priestess_body(root: Node3D) -> void:
	var t := _tier
	var c := Node3D.new()
	c.position = Vector3(0, 0, OP_Z)
	root.add_child(c)
	var robe := M.mat(ROBE)
	var gold := M.metal(GOLD)
	var hair := M.mat(BLONDE)
	var steel := M.metal(Color(0.78, 0.8, 0.84))
	var habit := M.mat(HABIT)
	var body_m: Material = habit if t == 0 else robe
	var trim: Material = M.mat(Color(0.36, 0.26, 0.17)) if t == 0 else gold
	Human.body(c, body_m, trim)
	# falda larga con bajo
	M.cyl(c, 0.15, 0.19, 0.08, body_m, Vector3(0, 0.04, 0), Vector3.ZERO, 16)
	if t >= 1:
		var hem := TorusMesh.new()
		hem.inner_radius = 0.17
		hem.outer_radius = 0.195
		M.add(c, hem, gold, Vector3(0, 0.012, 0))
	# hombreras (acero / oro)
	if t >= 2:
		for s: float in [-1.0, 1.0]:
			M.sphere(c, 0.07 if t == 2 else 0.08, steel if t == 2 else gold, Vector3(0.135 * s, 0.285, 0), Vector3(1, 0.7, 1), 10)
	if t == 0:
		# escapulario blanco y cordón
		M.box(c, Vector3(0.12, 0.28, 0.02), robe, Vector3(0, 0.16, -0.125), Vector3(-6, 0, 0))
		M.cyl(c, 0.148, 0.148, 0.02, M.mat(Color(0.85, 0.78, 0.6)), Vector3(0, 0.12, 0), Vector3.ZERO, 16)
		M.segment(c, 0.008, M.mat(Color(0.85, 0.78, 0.6)), Vector3(0.05, 0.12, -0.15), Vector3(0.06, 0.02, -0.16), 4)
		cross(c, Vector3(0.06, 0.0, -0.165), 0.4, M.mat(WOOD), 0.01)
	else:
		# tabardo blanco con ribete dorado y cruz dorada (peto dorado en Maestría)
		M.box(c, Vector3(0.16, 0.3, 0.02), gold, Vector3(0, 0.16, -0.125), Vector3(-6, 0, 0))
		M.box(c, Vector3(0.13, 0.28, 0.024), robe if t < 3 else gold, Vector3(0, 0.165, -0.128), Vector3(-6, 0, 0))
		var cn := Node3D.new()
		cn.position = Vector3(0, 0.19, -0.143)
		cn.rotation.x = deg_to_rad(-6.0)
		c.add_child(cn)
		cross(cn, Vector3.ZERO, 0.9, gold if t < 3 else M.mat(HOLY, 2.0), 0.01)
		M.cyl(c, 0.148, 0.148, 0.025, M.mat(Color(0.55, 0.36, 0.2)) if t < 3 else gold, Vector3(0, 0.1, 0), Vector3.ZERO, 16)
		M.box(c, Vector3(0.04, 0.035, 0.02), gold, Vector3(0, 0.1, -0.15))
		# capa blanca por detrás
		M.box(c, Vector3(0.3, 0.32, 0.025), robe, Vector3(0, 0.17, 0.12), Vector3(-8, 0, 0))
		M.box(c, Vector3(0.31, 0.025, 0.03), gold, Vector3(0, 0.02, 0.135))
	if t == 3:
		# alas de luz blancas y doradas a la espalda
		for s: float in [-1.0, 1.0]:
			var w := Node3D.new()
			w.position = Vector3(0.08 * s, 0.3, 0.15)
			w.rotation = Vector3(-0.3, 0.5 * s, -0.6 * s)
			c.add_child(w)
			M.sphere(w, 0.11, M.mat(Color(1.0, 0.98, 0.92)), Vector3(0.1 * s, 0.06, 0), Vector3(1.3, 0.5, 0.15), 10)
			M.sphere(w, 0.08, M.mat(Color(1.0, 0.9, 0.6), 0.8), Vector3(0.17 * s, 0.13, 0.005), Vector3(1.4, 0.35, 0.12), 8)
			M.sphere(w, 0.06, gold, Vector3(0.03 * s, 0.02, -0.005), Vector3(1.0, 0.6, 0.2), 8)
	# cabeza
	var h := Human.head(c, t >= 1, t >= 1, BLONDE)
	if t == 0:
		# toca blanca bajo velo pardo
		M.sphere(h, 0.152, robe, Vector3(0, 0.0, 0.02), Vector3(1.05, 1.1, 1.0), 14)
		M.sphere(h, 0.16, habit, Vector3(0, 0.04, 0.04), Vector3(1.08, 1.0, 1.02), 14)
		M.box(h, Vector3(0.24, 0.22, 0.05), habit, Vector3(0, -0.1, 0.09))
		M.box(h, Vector3(0.2, 0.06, 0.02), robe, Vector3(0, -0.12, -0.11))
	else:
		M.sphere(h, 0.12, hair, Vector3(0, -0.08, 0.06), Vector3(1.1, 1.3, 0.7), 12)
		M.box(h, Vector3(0.22, 0.2, 0.06), hair, Vector3(0, -0.14, 0.07))
		var tiara := TorusMesh.new()
		tiara.inner_radius = 0.13
		tiara.outer_radius = 0.148
		M.add(h, tiara, gold, Vector3(0, 0.06, -0.005), Vector3(-12, 0, 0))
		M.sphere(h, 0.015, M.mat(GLASS_BLUE, 1.0), Vector3(0, 0.085, -0.142), Vector3.ONE, 6)
		if t == 3:
			for k in 5:
				var a := PI + (k - 2) * 0.35
				M.cyl(h, 0.0, 0.014, 0.05 + (0.03 if k == 2 else 0.0), gold, Vector3(sin(a) * 0.14, 0.11, cos(a) * 0.14), Vector3.ZERO, 4)
	# brazo izquierdo con escudo de cometa blanco y cruz dorada (etapa 0: un rosario)
	var lh := Vector3(-0.19, 0.17, -0.1)
	Human.arm(c, Human.L_SHOULDER, lh, body_m, trim)
	if t >= 1:
		var sh := Node3D.new()
		sh.position = lh + Vector3(-0.03, 0.0, -0.035)
		sh.rotation = Vector3(0, deg_to_rad(-35.0), 0)
		c.add_child(sh)
		var ss := 1.0 if t < 3 else 1.2
		M.box(sh, Vector3(0.15, 0.13, 0.025) * ss, gold, Vector3(0, 0.02, 0))
		M.box(sh, Vector3(0.13, 0.12, 0.03) * ss, robe, Vector3(0, 0.022, 0))
		M.cyl(sh, 0.0, 0.075 * ss, 0.1 * ss, gold, Vector3(0, -0.085 * ss, 0), Vector3(180, 45, 0), 4)
		cross(sh, Vector3(0, 0.0, -0.018), 0.8 * ss, gold if t < 3 else M.mat(HOLY, 2.0), 0.01)
	else:
		for k in 5:
			M.sphere(c, 0.01, M.mat(WOOD), lh + Vector3(0.0, -0.03 - k * 0.018, -0.02), Vector3.ONE, 4)
	# brazo derecho alzado sosteniendo el símbolo sagrado
	Human.arm(c, Human.R_SHOULDER, SYMBOL_LOCAL + Vector3(0, -0.12, 0), body_m, trim)


func _build_priestess_parts() -> void:
	var t := _tier
	var c := Node3D.new()
	c.position = Vector3(0, 0, OP_Z)
	cat_pivot.add_child(c)
	_holy_mat = (M.mat(HOLY, 1.0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	var gold := M.metal(GOLD)
	var rod: Material = M.mat(WOOD) if t == 0 else gold
	var rim: Material = M.metal(BRONZE) if t == 0 else gold
	# Halo de luz sobre la cabeza (más grande y con rayos en Maestría)
	_halo = Node3D.new()
	_halo.position = Human.HEAD + Vector3(0, 0.17, 0.02)
	c.add_child(_halo)
	var ring := TorusMesh.new()
	var hr: float = [0.065, 0.085, 0.085, 0.11][t]
	ring.inner_radius = hr
	ring.outer_radius = hr + (0.014 if t == 0 else 0.02)
	ring.rings = 18
	ring.ring_segments = 6
	M.add(_halo, ring, _holy_mat, Vector3.ZERO, Vector3(-10, 0, 0))
	if t == 3:
		for i in 8:
			var a := TAU * i / 8.0
			M.cyl(_halo, 0.0, 0.01, 0.05, _holy_mat, Vector3(cos(a), 0, sin(a)) * (hr + 0.04), Vector3(0, -rad_to_deg(a), 90), 4)
	# Símbolo sagrado: vara con sol y cruz
	_symbol = Node3D.new()
	_symbol.position = SYMBOL_LOCAL
	c.add_child(_symbol)
	var ss: float = [0.75, 1.0, 1.0, 1.25][t]
	M.segment(_symbol, 0.01, rod, Vector3(0, -0.16 if t > 0 else -0.5, 0), Vector3(0, -0.04, 0), 6)
	M.cyl(_symbol, 0.055 * ss, 0.055 * ss, 0.018, rim, Vector3.ZERO, Vector3(90, 0, 0), 16)
	M.cyl(_symbol, 0.042 * ss, 0.042 * ss, 0.022, _holy_mat, Vector3.ZERO, Vector3(90, 0, 0), 16)
	var n_rays := 8 if t < 3 else 12
	for i in (n_rays if t > 0 else 0):
		var ray := Node3D.new()
		ray.rotation.z = TAU * i / n_rays
		_symbol.add_child(ray)
		M.cyl(ray, 0.0, 0.012, 0.035 * ss, gold, Vector3(0, 0.07 * ss, 0), Vector3.ZERO, 4)
	cross(_symbol, Vector3(0, -0.01, -0.014), 0.6 * ss, rim, 0.012)
	# Luz sagrada translúcida alrededor del símbolo
	_light_mat = StandardMaterial3D.new()
	_light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_light_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_light_mat.albedo_color = Color(1.0, 0.85, 0.3, 0.25)
	_light = M.add(_symbol, M.sphere_mesh(0.1 if t < 3 else 0.13, 14), _light_mat)
