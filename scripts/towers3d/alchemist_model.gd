extends Node3D
## Modelo 3D "Laboratorio Alquímico". Cambia de aspecto con la etapa visual (TowerModels.tier):
##   0 (nv 0-1): choza-tonel de duelas de madera sobre un zócalo de piedra suelta, tejadillo de
##               paja, caldero sobre una hoguera en la azotea y un tubo de estufa torcido humeante;
##               aprendiz con hábito pardo, capucha y mandil.
##   1 (nv 2-3): torre redonda de mampostería con almenas, chimenea de ladrillo, ventanas verdes,
##               repisa de pociones y alambique; alquimista con túnica morada, mandil y gafas.
##   2 (nv 4):   torre de sillería más alta con matacanes, torreón con cúpula de cobre verdeado,
##               estandartes heráldicos y braseros de fuego verde; alquimista con hombreras de latón.
##   3 (nv 5):   torre de piedra blanca con molduras doradas, torreón con cúpula dorada, círculo de
##               runas verdes, frascos que orbitan y vapores brillantes; gran alquimista con túnica
##               blanca y oro, capa y gafas incandescentes.
## Al cargar levanta un frasco verde brillante; al disparar lo lanza.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const ArcherModel := preload("res://scripts/towers3d/archer_model.gd")   # hierba de la base

const STONE_DARK := Color(0.4, 0.38, 0.36)
const WOOD_DARK := Color(0.32, 0.2, 0.11)
const IRON := Color(0.26, 0.26, 0.29)
const COPPER := Color(0.8, 0.45, 0.25)
const VERDIGRIS := Color(0.3, 0.55, 0.47)
const BRASS := Color(0.86, 0.68, 0.32)
const GOLD := Color(1.0, 0.78, 0.3)
const GREEN_GLOW := Color(0.3, 0.9, 0.2)
const GLASS := Color(0.55, 0.78, 0.82)
const PLUM := Color(0.36, 0.2, 0.38)
const PLUM_DARK := Color(0.24, 0.13, 0.26)
const LEATHER := Color(0.48, 0.3, 0.16)
const LEATHER_DARK := Color(0.32, 0.2, 0.11)
const HOMESPUN := Color(0.5, 0.38, 0.26)
const HOMESPUN_DARK := Color(0.36, 0.26, 0.17)
const IVORY := Color(0.93, 0.9, 0.82)
const WHITE_STONE := Color(1.35, 1.3, 1.16)   # tinte >1: aclara el dibujo de ladrillo

const PLATFORM_HEIGHTS := [0.74, 1.04, 1.24, 1.44]
const TURRET := Vector3(0.26, 0.0, -0.26)    # detrás (la cámara del juego mira la cara +Z)
const CHIMNEY := Vector3(-0.26, 0.0, -0.25)
# Mano derecha del alquimista (coordenadas del personaje)
const HAND_REST := Vector3(0.19, 0.2, -0.17)
const HAND_UP := Vector3(0.12, 0.68, 0.0)
const HAND_THROW := Vector3(0.1, 0.46, -0.33)

var cat_pivot: Node3D
var _tier := 0
var _py := 0.74
var _cauldron := Vector3.ZERO
var _arm: Node3D
var _cuff: Node3D
var _hand: Node3D
var _flask: Node3D
var _flask_glow: Node3D
var _bubbles: Array[Node3D] = []
var _orbit: Node3D
var _orbit_flasks: Array[Node3D] = []


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
	_cauldron = Vector3(-0.22, _py, 0.19)
	M.add_baked(self, M.baked("alchemist_tower_t%d" % _tier, _build_tower))
	_build_cauldron_bubbles()
	add_child(_smoke())
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, _py, 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("alchemist_human_t%d" % _tier, _build_human_body))
	_build_human_parts()
	if _tier == 3:
		_build_master_fx()
	animate({"t": 0.0, "charge": 0.0, "fire": 0.0, "has_target": false})


## s = {t, charge 0..1, fire 1 -> 0 tras lanzar, has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = s.get("charge", 0.0)
	var fire: float = s.get("fire", 0.0)
	var has_target: bool = s.get("has_target", false)
	var lift: float = charge if has_target else 0.0
	# Brazo: de la cintura a por encima de la cabeza; al lanzar, estocada hacia delante
	var hand := HAND_REST.lerp(HAND_UP, lift)
	hand = hand.lerp(HAND_THROW, clampf(fire, 0.0, 1.0))
	hand.y += sin(t * 3.0) * 0.008
	M.orient_segment(_arm, Human.R_SHOULDER, hand)
	M.orient_segment(_cuff, Human.R_SHOULDER.lerp(hand, 0.78), Human.R_SHOULDER.lerp(hand, 0.9))
	_hand.position = hand
	_flask.position = hand + Vector3(0, 0.07, 0)
	_flask.rotation.z = sin(t * 4.0) * 0.12 + lift * 0.3
	_flask.visible = fire < 0.55   # el frasco acaba de salir volando: reaparece al poco
	_flask_glow.scale = Vector3.ONE * (0.8 + lift * 0.9 + sin(t * 11.0) * 0.06)
	# Burbujas del caldero: suben y se encogen en bucle
	for i in _bubbles.size():
		var u := fmod(t * 0.9 + i / float(_bubbles.size()), 1.0)
		var b := _bubbles[i]
		b.position.y = _cauldron.y + 0.2 + u * 0.08
		b.scale = Vector3.ONE * (1.0 - u * 0.7)
	# Maestría: frascos que orbitan alrededor de la torre
	if _orbit:
		_orbit.rotation.y = t * (0.5 + charge * 0.8)
		for i in _orbit_flasks.size():
			_orbit_flasks[i].position.y = sin(t * 2.2 + i * 2.1) * 0.04


func muzzle_global() -> Vector3:
	return _flask.global_position


# Humo de la chimenea (verde y brillante en Maestría)
func _smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.8
	p.position = _chimney_top()
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.05, 0.12, 0)
	p.initial_velocity_min = 0.12
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = M.mat(Color(0.5, 1.0, 0.45), 1.2) if _tier == 3 else M.mat(Color(0.62, 0.72, 0.6))
	p.mesh = mesh
	return p


func _chimney_top() -> Vector3:
	if _tier == 0:
		return Vector3(-0.3, _py + 0.5, -0.2)
	return CHIMNEY + Vector3(0, _py + 0.46, 0)


# --- Torre ---

func _build_tower(parent: Node3D) -> void:
	if _tier == 0:
		_build_hut(parent)
	else:
		_build_stone_tower(parent)
	_build_platform_props(parent)
	ArcherModel._ground_details(parent, false)


# Etapa 0: choza-tonel de duelas sobre piedra suelta
func _build_hut(parent: Node3D) -> void:
	var rubble := [M.mat(Color(0.56, 0.54, 0.5)), M.mat(Color(0.48, 0.46, 0.43)), M.mat(Color(0.62, 0.6, 0.55))]
	var stave := M.tex_mat("wood", 2.2, Color(0.78, 0.6, 0.42))
	var stave_dark := M.tex_mat("wood", 2.2, Color(0.6, 0.45, 0.3))
	var iron := M.metal(IRON)
	var wood_dark := M.mat(WOOD_DARK)
	var thatch := M.mat(Color(0.82, 0.68, 0.38))
	var thatch_dark := M.mat(Color(0.66, 0.52, 0.28))
	var glow := M.mat(GREEN_GLOW, 0.9)
	var rope := M.mat(Color(0.8, 0.68, 0.48))
	var py := _py

	# Zócalo de piedras sueltas
	M.cyl(parent, 0.4, 0.43, 0.06, rubble[1], Vector3(0, 0.03, 0), Vector3.ZERO, 12)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 16:
		var a := TAU * i / 16.0
		var r := 0.37 + rng.randf_range(-0.01, 0.02)
		var blk := M.sphere(parent, 0.075, rubble[i % 3], Vector3(cos(a) * r, 0.1 + (i % 2) * 0.05, sin(a) * r),
				Vector3(1.2, 0.75, 0.9), 6)
		blk.rotation.y = -a
	# Cuerpo de duelas con aros de hierro (como un gran tonel)
	var body_h := py - 0.2
	M.cyl(parent, 0.31, 0.34, body_h, stave, Vector3(0, 0.16 + body_h * 0.5, 0), Vector3.ZERO, 14)
	for i in 14:
		var a := TAU * (i + 0.5) / 14.0
		var d := Vector3(cos(a), 0, sin(a))
		var st := M.box(parent, Vector3(0.025, body_h, 0.02), stave_dark, d * 0.33 + Vector3(0, 0.16 + body_h * 0.5, 0))
		st.rotation.y = -a
	for y: float in [0.24, 0.16 + body_h * 0.55, py - 0.08]:
		M.cyl(parent, 0.345, 0.345, 0.03, iron, Vector3(0, y, 0), Vector3.ZERO, 14)
	# Puerta de tablones (+Z) y ventanuco con resplandor
	M.box(parent, Vector3(0.18, 0.26, 0.05), stave_dark, Vector3(0, 0.29, 0.32))
	for y: float in [0.22, 0.36]:
		M.box(parent, Vector3(0.19, 0.02, 0.012), iron, Vector3(0, y, 0.348))
	M.sphere(parent, 0.012, iron, Vector3(0.055, 0.3, 0.352), Vector3.ONE, 6)
	M.box(parent, Vector3(0.24, 0.04, 0.1), rubble[2], Vector3(0, 0.02, 0.42))
	for a: float in [0.6, 2.5, -0.8]:
		var dir := Vector3(cos(a), 0, sin(a))
		var w := Node3D.new()
		w.position = dir * 0.335 + Vector3(0, py * 0.62, 0)
		w.rotation.y = atan2(dir.x, dir.z)
		parent.add_child(w)
		M.box(w, Vector3(0.09, 0.09, 0.03), wood_dark)
		M.box(w, Vector3(0.065, 0.065, 0.03), glow, Vector3(0, 0, 0.006))
		M.box(w, Vector3(0.01, 0.07, 0.035), wood_dark, Vector3(0, 0, 0.01))
	# Piso de tablones de la azotea y barandilla de palos
	M.cyl(parent, 0.37, 0.37, 0.05, stave_dark, Vector3(0, py - 0.025, 0), Vector3.ZERO, 14)
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		var d := Vector3(cos(a), 0, sin(a))
		if d.distance_to(Vector3(-0.83, 0, -0.55)) < 0.35:
			continue   # hueco para el tubo de estufa
		M.cyl(parent, 0.016, 0.018, 0.17, wood_dark, d * 0.345 + Vector3(0, py + 0.085, 0), Vector3.ZERO, 5)
	var rail := TorusMesh.new()
	rail.inner_radius = 0.33
	rail.outer_radius = 0.36
	rail.rings = 18
	rail.ring_segments = 4
	M.add(parent, rail, wood_dark, Vector3(0, py + 0.16, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	# Tejadillo de paja sobre dos postes, en la parte trasera
	for sx: float in [-1.0, 1.0]:
		M.cyl(parent, 0.016, 0.018, 0.5, wood_dark, Vector3(0.24 * sx, py + 0.25, -0.24), Vector3.ZERO, 5)
	var roof := Node3D.new()
	roof.position = Vector3(0, py + 0.5, -0.2)
	roof.rotation_degrees.x = 24.0
	parent.add_child(roof)
	M.box(roof, Vector3(0.6, 0.06, 0.26), thatch)
	for k in 4:
		M.box(roof, Vector3(0.62, 0.03, 0.03), thatch_dark, Vector3(0, 0.03, -0.1 + k * 0.065))
	# Tubo de estufa torcido (humea)
	var p0 := Vector3(-0.3, py - 0.02, -0.2)
	M.segment(parent, 0.035, iron, Vector3(-0.34, py * 0.5, -0.2), p0, 8)
	M.segment(parent, 0.035, iron, p0, p0 + Vector3(0.02, 0.28, 0.0), 8)
	M.segment(parent, 0.035, iron, p0 + Vector3(0.02, 0.28, 0.0), Vector3(-0.3, py + 0.48, -0.2), 8)
	M.cyl(parent, 0.05, 0.04, 0.05, iron, Vector3(-0.3, py + 0.48, -0.2), Vector3.ZERO, 8)
	# Ristra de hierbas y frascos colgados de una cuerda bajo el tejadillo
	M.segment(parent, 0.005, rope, Vector3(-0.24, py + 0.42, -0.14), Vector3(0.24, py + 0.42, -0.14), 4)
	for k in 4:
		var hp := Vector3(-0.15 + k * 0.1, py + 0.36, -0.14)
		if k % 2 == 0:
			M.cyl(parent, 0.0, 0.025, 0.08, M.mat(Color(0.35, 0.6, 0.25)), hp, Vector3(180, 0, 0), 5)
		else:
			M.sphere(parent, 0.022, M.mat(Color(0.75, 0.35, 1.0), 1.0), hp + Vector3(0, -0.02, 0), Vector3.ONE, 8)
	# Leña, un barril y una cesta de setas al pie
	for k in 3:
		M.cyl(parent, 0.025, 0.025, 0.2, stave_dark, Vector3(-0.42, 0.03 + (k % 2) * 0.04, -0.1 + k * 0.045), Vector3(90, 10, 0), 6)
	M.cyl(parent, 0.06, 0.06, 0.14, stave, Vector3(0.42, 0.07, -0.22), Vector3.ZERO, 10)
	M.cyl(parent, 0.063, 0.063, 0.012, iron, Vector3(0.42, 0.12, -0.22), Vector3.ZERO, 10)
	M.cyl(parent, 0.07, 0.05, 0.06, rope, Vector3(0.4, 0.03, 0.18), Vector3.ZERO, 10)
	for k in 3:
		M.sphere(parent, 0.025, M.mat(Color(0.85, 0.25, 0.2)), Vector3(0.38 + k * 0.02, 0.07, 0.17 + (k % 2) * 0.03), Vector3(1, 0.6, 1), 8)


# Etapas 1-3: torre redonda de piedra (2: sillería y torreón; 3: piedra blanca y oro)
func _build_stone_tower(parent: Node3D) -> void:
	var t := _tier
	var master := t == 3
	var stone_col := WHITE_STONE if master else Color(0.82, 0.78, 0.7)
	var stone := M.tex_mat("bricks", 2.2, stone_col)
	var stones: Array
	if master:
		stones = [M.mat(Color(0.78, 0.75, 0.68)), M.mat(Color(0.7, 0.67, 0.6)), M.mat(Color(0.74, 0.71, 0.63))]
	else:
		stones = [M.mat(Color(0.6, 0.57, 0.52)), M.mat(Color(0.52, 0.5, 0.46)), M.mat(Color(0.66, 0.63, 0.58))]
	var dark := M.mat(Color(0.62, 0.58, 0.52) if master else STONE_DARK)
	var trim: Material = stones[1]
	if master:
		trim = M.metal(GOLD)
	var wood := M.tex_mat("wood", 2.0, Color(0.75, 0.6, 0.5))
	var wood_dark := M.mat(WOOD_DARK)
	var iron := M.metal(IRON)
	var copper := M.metal(COPPER)
	var verdi := M.metal(VERDIGRIS)
	var brass := M.metal(BRASS)
	var glow := M.mat(GREEN_GLOW, 0.9)
	var gold := M.metal(GOLD)
	var plum := M.mat(PLUM)
	var py := _py
	var shaft_h := py - 0.14

	# Zócalo y fuste redondo
	M.cyl(parent, 0.44, 0.46, 0.08, dark, Vector3(0, 0.04, 0), Vector3.ZERO, 20)
	if t >= 2:
		M.cyl(parent, 0.38, 0.44, 0.16, stones[1], Vector3(0, 0.16, 0), Vector3.ZERO, 20)   # talud
	M.cyl(parent, 0.33, 0.36, shaft_h, stone, Vector3(0, 0.08 + shaft_h * 0.5, 0), Vector3.ZERO, 24)
	M.cyl(parent, 0.375, 0.38, 0.06, stones[1], Vector3(0, 0.12, 0), Vector3.ZERO, 24)
	M.cyl(parent, 0.365, 0.36, 0.04 if not master else 0.035, trim, Vector3(0, py * 0.48, 0), Vector3.ZERO, 24)
	# sillares sueltos que sobresalen del fuste
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var n_blk := 14 + (t - 1) * 4
	for i in n_blk:
		var a := TAU * i / n_blk + rng.randf_range(-0.1, 0.1)
		if absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.45:
			continue   # deja libre la puerta (+Z)
		var y := 0.24 + (i % 4) * (shaft_h - 0.3) / 4.0 + rng.randf_range(-0.02, 0.02)
		var r := lerpf(0.36, 0.33, (y - 0.08) / shaft_h)
		var blk := M.box(parent, Vector3(0.13, 0.09, 0.04), stones[i % 3], Vector3(cos(a) * r, y, sin(a) * r))
		blk.rotation.y = PI / 2.0 - a

	# Puerta en arco con herrajes (+Z)
	M.box(parent, Vector3(0.26, 0.3, 0.06), stones[2], Vector3(0, 0.25, 0.335))
	M.cyl(parent, 0.13, 0.13, 0.06, trim if master else stones[2], Vector3(0, 0.4, 0.335), Vector3(90, 0, 0), 18)
	M.box(parent, Vector3(0.19, 0.27, 0.04), wood, Vector3(0, 0.235, 0.355))
	M.cyl(parent, 0.095, 0.095, 0.04, wood, Vector3(0, 0.37, 0.355), Vector3(90, 0, 0), 16)
	for y: float in [0.18, 0.32]:
		M.box(parent, Vector3(0.17, 0.02, 0.012), gold if master else iron, Vector3(0, y, 0.378))
	M.sphere(parent, 0.015, brass, Vector3(0.06, 0.27, 0.382), Vector3.ONE, 6)

	# Estandartes morados con alambique dorado
	var banner_xs: Array = [0.0] if t == 1 else [-0.15, 0.15]
	var by := py * 0.66
	for bx: float in banner_xs:
		var bz := sqrt(maxf(0.0, 0.345 * 0.345 - bx * bx)) + 0.01
		var bn := Node3D.new()
		bn.position = Vector3(bx, 0, bz)
		bn.rotation.y = atan2(bx, bz)
		parent.add_child(bn)
		M.box(bn, Vector3(0.2, 0.025, 0.025), gold if t >= 2 else wood_dark, Vector3(0, by + 0.14, 0))
		if t >= 2:
			M.box(bn, Vector3(0.16, 0.27, 0.012), gold, Vector3(0, by, -0.002))
		M.box(bn, Vector3(0.14 if t >= 2 else 0.17, 0.25, 0.016), plum, Vector3(0, by + 0.005, 0))
		for k: float in [-1.0, 1.0]:
			M.cyl(bn, 0.0, 0.04, 0.05, plum, Vector3(0.035 * k, by - 0.14, 0), Vector3(180, 0, 0), 4)
		M.sphere(bn, 0.032, gold, Vector3(0, by - 0.02, 0.012), Vector3(1, 1, 0.3), 10)
		M.box(bn, Vector3(0.02, 0.05, 0.008), gold, Vector3(0, by + 0.03, 0.012))
		M.box(bn, Vector3(0.05, 0.012, 0.008), gold, Vector3(0, by + 0.055, 0.012))

	# Ventanas en arco con resplandor verde
	var win_y := py * 0.67 if t == 1 else py * 0.4
	for a: float in [0.55, 2.6, -0.3, -1.57, -2.85]:
		var dir := Vector3(cos(a), 0, sin(a))
		var w := Node3D.new()
		w.position = dir * 0.335 + Vector3(0, win_y, 0)
		w.rotation.y = atan2(dir.x, dir.z)
		parent.add_child(w)
		M.box(w, Vector3(0.1, 0.12, 0.04), trim if master else dark)
		M.cyl(w, 0.05, 0.05, 0.04, trim if master else dark, Vector3(0, 0.06, 0), Vector3(90, 0, 0), 12)
		M.box(w, Vector3(0.07, 0.1, 0.04), glow, Vector3(0, -0.005, 0.006))
		M.cyl(w, 0.035, 0.035, 0.04, glow, Vector3(0, 0.05, 0.006), Vector3(90, 0, 0), 10)
		M.box(w, Vector3(0.012, 0.15, 0.045), iron, Vector3(0, 0.01, 0.01))
		M.box(w, Vector3(0.12, 0.025, 0.06), stones[2], Vector3(0, -0.07, 0.01))
	if t >= 2:
		# segunda hilera de ventanas, más arriba
		for a: float in [1.2, -0.9, -2.2]:
			var dir := Vector3(cos(a), 0, sin(a))
			var w := Node3D.new()
			w.position = dir * 0.335 + Vector3(0, py * 0.78, 0)
			w.rotation.y = atan2(dir.x, dir.z)
			parent.add_child(w)
			M.box(w, Vector3(0.07, 0.1, 0.04), trim if master else dark)
			M.box(w, Vector3(0.045, 0.08, 0.04), glow, Vector3(0, 0, 0.006))

	# Repisa lateral (-X) con frascos de colores
	var shelf := Node3D.new()
	shelf.position = Vector3(-0.35, 0.36, -0.05)
	shelf.rotation.y = -PI / 2.0
	parent.add_child(shelf)
	M.box(shelf, Vector3(0.24, 0.025, 0.08), wood, Vector3(0, 0, 0.04))
	for k: float in [-1.0, 1.0]:
		M.box(shelf, Vector3(0.015, 0.06, 0.06), iron, Vector3(0.1 * k, -0.035, 0.035), Vector3(45, 0, 0))
	var potions := [M.mat(Color(0.75, 0.35, 1.0), 1.2), M.mat(Color(0.3, 0.6, 1.0), 1.2), M.mat(GREEN_GLOW, 1.2)]
	for k in 3:
		var bp := Vector3(-0.07 + k * 0.07, 0.05, 0.045)
		if k == 1:
			M.sphere(shelf, 0.035, potions[k], bp + Vector3(0, -0.005, 0), Vector3.ONE, 10)
			M.cyl(shelf, 0.012, 0.014, 0.05, potions[k], bp + Vector3(0, 0.045, 0), Vector3.ZERO, 6)
		else:
			M.cyl(shelf, 0.022, 0.026, 0.07, potions[k], bp, Vector3.ZERO, 8)
		M.cyl(shelf, 0.012, 0.012, 0.02, M.mat(Color(0.65, 0.48, 0.3)), bp + Vector3(0, 0.05 if k != 1 else 0.075, 0), Vector3.ZERO, 6)

	# Tubería de cobre que baja por el muro hasta un alambique en el suelo (+X)
	M.segment(parent, 0.016, copper, Vector3(0.36, 0.2, -0.12), Vector3(0.355, py - 0.12, -0.12), 8)
	M.sphere(parent, 0.022, copper, Vector3(0.36, 0.2, -0.12), Vector3.ONE, 8)
	for y: float in [0.4, py * 0.68]:
		M.box(parent, Vector3(0.03, 0.025, 0.05), iron, Vector3(0.345, y, -0.12))
	M.segment(parent, 0.016, copper, Vector3(0.36, 0.2, -0.12), Vector3(0.44, 0.2, -0.24), 8)
	var glass := M.mat(GLASS, 0.15)
	M.sphere(parent, 0.07, glass, Vector3(0.44, 0.1, -0.28), Vector3.ONE, 12)
	M.sphere(parent, 0.055, glow, Vector3(0.44, 0.09, -0.28), Vector3(1, 0.7, 1), 10)
	M.cyl(parent, 0.02, 0.025, 0.08, glass, Vector3(0.44, 0.19, -0.27), Vector3.ZERO, 8)

	# Corona (con matacanes desde la etapa 2) y almenas
	var crown_y := py - 0.08
	M.cyl(parent, 0.4, 0.34, 0.08, stones[1], Vector3(0, crown_y, 0), Vector3.ZERO, 24)
	var n_corbel := 12 if t == 1 else 16
	for i in n_corbel:
		var a := TAU * (i + 0.5) / n_corbel
		var blk := M.box(parent, Vector3(0.04, 0.05 if t == 1 else 0.1, 0.03 if t == 1 else 0.05), dark,
				Vector3(cos(a) * 0.37, crown_y - (0.06 if t == 1 else 0.09), sin(a) * 0.37))
		blk.rotation.y = PI / 2.0 - a
	M.cyl(parent, 0.4, 0.4, 0.06, M.tex_mat("bricks", 2.5, stone_col.darkened(0.12)), Vector3(0, py - 0.03, 0), Vector3.ZERO, 24)
	if t >= 2:
		M.cyl(parent, 0.405, 0.405, 0.02, trim, Vector3(0, py - 0.065, 0), Vector3.ZERO, 24)
	for i in 10:
		var a := TAU * i / 10.0
		var mp := Vector3(cos(a) * 0.375, py + 0.05, sin(a) * 0.375)
		# sin almenas donde están el torreón y la chimenea
		if t >= 2 and mp.distance_to(Vector3(TURRET.x, mp.y, TURRET.z)) < 0.17:
			continue
		if mp.distance_to(Vector3(CHIMNEY.x, mp.y, CHIMNEY.z)) < 0.14:
			continue
		var m := M.box(parent, Vector3(0.11, 0.1, 0.06), stone, mp)
		m.rotation.y = PI / 2.0 - a
		if master:
			var cap := M.box(parent, Vector3(0.12, 0.02, 0.07), gold, mp + Vector3(0, 0.06, 0))
			cap.rotation.y = PI / 2.0 - a

	# Torreón con cúpula (cobre verdeado; dorada en Maestría)
	if t >= 2:
		var tp := TURRET
		var top := py + (0.5 if t == 2 else 0.66)
		M.cyl(parent, 0.12, 0.13, top - 0.08, stone, tp + Vector3(0, 0.08 + (top - 0.08) * 0.5, 0), Vector3.ZERO, 16)
		M.cyl(parent, 0.155, 0.125, 0.06, trim, tp + Vector3(0, top + 0.01, 0), Vector3.ZERO, 16)
		var dome: Material = gold if master else verdi
		M.sphere(parent, 0.15, dome, tp + Vector3(0, top + 0.04, 0), Vector3(1, 1.1 if master else 0.95, 1), 16)
		M.cyl(parent, 0.152, 0.152, 0.025, copper if not master else M.metal(Color(0.95, 0.9, 0.8)), tp + Vector3(0, top + 0.055, 0), Vector3.ZERO, 16)
		M.cyl(parent, 0.02, 0.03, 0.06, copper if not master else gold, tp + Vector3(0, top + 0.2 + (0.02 if master else 0.0), 0), Vector3.ZERO, 8)
		M.sphere(parent, 0.028, brass if not master else M.mat(GREEN_GLOW, 2.0), tp + Vector3(0, top + 0.25 + (0.02 if master else 0.0), 0), Vector3.ONE, 8)
		M.cyl(parent, 0.0, 0.012, 0.09 if not master else 0.16, brass if not master else gold,
				tp + Vector3(0, top + (0.31 if not master else 0.36), 0), Vector3.ZERO, 6)
		for a: float in [PI / 4.0, -PI / 4.0, PI * 0.75]:
			var dir := Vector3(cos(a), 0, sin(a))
			var w := Node3D.new()
			w.position = tp + dir * 0.125 + Vector3(0, top - 0.18, 0)
			w.rotation.y = atan2(dir.x, dir.z)
			parent.add_child(w)
			M.box(w, Vector3(0.06, 0.09, 0.03), trim if master else dark)
			M.box(w, Vector3(0.04, 0.07, 0.03), glow, Vector3(0, 0, 0.005))

	# Chimenea de ladrillo
	var cp := CHIMNEY
	M.box(parent, Vector3(0.11, 0.48, 0.11), M.tex_mat("bricks", 3.5, Color(0.72, 0.42, 0.32)), cp + Vector3(0, py + 0.2, 0))
	M.box(parent, Vector3(0.14, 0.04, 0.14), trim if master else dark, cp + Vector3(0, py + 0.45, 0))
	M.box(parent, Vector3(0.07, 0.02, 0.07), M.mat(Color(0.1, 0.1, 0.1)), cp + Vector3(0, py + 0.47, 0))

	# Braseros de fuego verde a los lados de la puerta (etapas 2 y 3)
	if t >= 2:
		var green_fire := M.mat(GREEN_GLOW.lightened(0.15), 2.0)
		for s: float in [-1.0, 1.0]:
			var tp2 := Vector3(0.24 * s, 0.5, 0.29)
			M.box(parent, Vector3(0.035, 0.05, 0.035), iron, tp2 + Vector3(0, -0.06, 0))
			M.segment(parent, 0.012, iron, tp2 + Vector3(0, -0.06, 0), tp2 + Vector3(0, 0.03, 0.05), 6)
			M.cyl(parent, 0.035, 0.02, 0.035, gold if master else iron, tp2 + Vector3(0, 0.04, 0.05), Vector3.ZERO, 8)
			M.cyl(parent, 0.0, 0.03, 0.09, green_fire, tp2 + Vector3(0, 0.1, 0.05), Vector3.ZERO, 6)

	# Barriles y cajas al pie de la torre
	for p: Vector3 in [Vector3(-0.42, 0, 0.3), Vector3(-0.44, 0, 0.16)]:
		M.cyl(parent, 0.06, 0.06, 0.15, wood, p + Vector3(0, 0.075, 0), Vector3.ZERO, 10)
		for y: float in [0.03, 0.12]:
			M.cyl(parent, 0.063, 0.063, 0.015, gold if master else iron, p + Vector3(0, y, 0), Vector3.ZERO, 10)
	M.box(parent, Vector3(0.13, 0.12, 0.12), wood, Vector3(0.4, 0.06, 0.3), Vector3(0, 15, 0))
	M.cyl(parent, 0.02, 0.025, 0.06, M.mat(GREEN_GLOW, 1.2), Vector3(0.38, 0.15, 0.3), Vector3.ZERO, 6)

	if not master:
		return
	# --- Maestría: anillos de runas y círculo alquímico dorado sobre la puerta ---
	var rune := M.mat(GREEN_GLOW, 1.8)
	for i in 18:
		var a := TAU * i / 18.0
		if absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.3:
			continue
		var d := Vector3(cos(a), 0, sin(a))
		var f := Node3D.new()
		f.position = d * 0.352 + Vector3(0, py * 0.56, 0)
		f.rotation.y = atan2(d.x, d.z)
		parent.add_child(f)
		match i % 3:
			0: M.box(f, Vector3(0.03, 0.03, 0.01), rune, Vector3.ZERO, Vector3(0, 0, 45))
			1: M.cyl(f, 0.018, 0.018, 0.01, rune, Vector3.ZERO, Vector3(90, 0, 0), 3)
			_:
				M.box(f, Vector3(0.008, 0.045, 0.01), rune)
				M.box(f, Vector3(0.03, 0.008, 0.01), rune, Vector3(0, 0.012, 0))
	var cc := Vector3(0, py * 0.66 + 0.02, 0.352)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.05
	ring.outer_radius = 0.062
	ring.rings = 18
	ring.ring_segments = 5
	M.add(parent, ring, gold, cc, Vector3(90, 0, 0))
	M.cyl(parent, 0.045, 0.045, 0.012, rune, cc, Vector3(90, 0, 0), 3)
	M.sphere(parent, 0.018, M.mat(Color(0.85, 1.0, 0.7), 2.2), cc + Vector3(0, 0, 0.01), Vector3.ONE, 8)


# Caldero, alambique y libros de la azotea (comunes a todas las etapas)
func _build_platform_props(parent: Node3D) -> void:
	var t := _tier
	var iron := M.metal(IRON)
	var copper := M.metal(COPPER)
	var glass := M.mat(GLASS, 0.15)
	var glow := M.mat(GREEN_GLOW, 0.9)
	var wood_dark := M.mat(WOOD_DARK)
	var gold := M.metal(GOLD)
	var cc := _cauldron
	if t == 0:
		# hoguera de leños y piedras bajo el caldero
		for i in 5:
			var a := TAU * i / 5.0
			M.sphere(parent, 0.03, M.mat(Color(0.5, 0.48, 0.45)), cc + Vector3(cos(a) * 0.1, 0.015, sin(a) * 0.1), Vector3(1, 0.6, 1), 6)
		for a: float in [0.3, 1.9]:
			M.cyl(parent, 0.016, 0.016, 0.16, wood_dark, cc + Vector3(0, 0.02, 0), Vector3(90, rad_to_deg(a), 0), 5)
	# Caldero de hierro sobre trípode y brasas, con líquido verde
	for i in 3:
		var a := TAU * i / 3.0 + 0.3
		M.segment(parent, 0.011, iron, cc + Vector3(cos(a) * 0.1, 0.0, sin(a) * 0.1), cc + Vector3(cos(a) * 0.06, 0.12, sin(a) * 0.06), 4)
	M.sphere(parent, 0.04, M.mat(Color(1.0, 0.45, 0.12), 1.8), cc + Vector3(0, 0.03, 0), Vector3(1.3, 0.5, 1.3), 8)
	var pot: Material = gold if t == 3 else (copper if t == 2 else iron)
	M.sphere(parent, 0.1, pot, cc + Vector3(0, 0.14, 0), Vector3(1, 0.85, 1), 14)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.085
	rim.outer_radius = 0.105
	M.add(parent, rim, pot, cc + Vector3(0, 0.205, 0))
	M.cyl(parent, 0.088, 0.088, 0.02, M.mat(GREEN_GLOW, 1.4 if t == 3 else 0.9), cc + Vector3(0, 0.198, 0), Vector3.ZERO, 14)
	for k: float in [-1.0, 1.0]:
		M.sphere(parent, 0.018, pot, cc + Vector3(0.1 * k, 0.17, 0), Vector3(0.6, 1, 1), 6)
	M.segment(parent, 0.008, wood_dark, cc + Vector3(0.02, 0.17, 0.02), cc + Vector3(0.09, 0.32, 0.07), 4)
	if t == 0:
		# mesa tosca con un matraz y un mortero
		var tb := Vector3(0.22, _py, 0.17)
		M.box(parent, Vector3(0.16, 0.025, 0.12), M.tex_mat("wood", 2.2, Color(0.6, 0.45, 0.3)), tb + Vector3(0, 0.1, 0))
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				M.cyl(parent, 0.01, 0.01, 0.1, wood_dark, tb + Vector3(0.065 * sx, 0.05, 0.045 * sz), Vector3.ZERO, 4)
		M.sphere(parent, 0.04, glass, tb + Vector3(-0.03, 0.15, 0), Vector3.ONE, 10)
		M.sphere(parent, 0.03, glow, tb + Vector3(-0.03, 0.145, 0), Vector3(1, 0.7, 1), 8)
		M.cyl(parent, 0.01, 0.014, 0.05, glass, tb + Vector3(-0.03, 0.2, 0), Vector3.ZERO, 6)
		M.cyl(parent, 0.03, 0.022, 0.035, M.mat(Color(0.6, 0.58, 0.55)), tb + Vector3(0.045, 0.13, 0.01), Vector3.ZERO, 8)
		return
	# Alambique de vidrio con serpentín y retorta
	var ap := Vector3(0.22, _py, 0.17)
	M.cyl(parent, 0.06, 0.07, 0.04, M.mat(Color(0.25, 0.2, 0.18)), ap + Vector3(0, 0.02, 0), Vector3.ZERO, 10)
	M.sphere(parent, 0.035, M.mat(Color(1.0, 0.5, 0.15), 1.8), ap + Vector3(0, 0.05, 0), Vector3(1, 0.5, 1), 8)
	M.sphere(parent, 0.065, glass, ap + Vector3(0, 0.12, 0), Vector3.ONE, 12)
	M.sphere(parent, 0.05, M.mat(Color(0.7, 0.4, 1.0), 1.3), ap + Vector3(0, 0.11, 0), Vector3(1, 0.75, 1), 10)
	M.cyl(parent, 0.016, 0.026, 0.1, glass, ap + Vector3(0, 0.22, 0), Vector3.ZERO, 8)
	M.sphere(parent, 0.035, gold if t == 3 else copper, ap + Vector3(0, 0.28, 0), Vector3.ONE, 10)
	M.segment(parent, 0.009, glass, ap + Vector3(0.1, 0.16, 0.08), ap + Vector3(0.0, 0.28, 0.0), 6)
	var rp := ap + Vector3(0.1, 0.0, -0.1)
	M.cyl(parent, 0.04, 0.045, 0.08, glass, rp + Vector3(0, 0.04, 0), Vector3.ZERO, 10)
	M.cyl(parent, 0.035, 0.04, 0.05, glow, rp + Vector3(0, 0.03, 0), Vector3.ZERO, 10)
	M.cyl(parent, 0.012, 0.012, 0.08, glass, rp + Vector3(0, 0.12, 0), Vector3.ZERO, 6)
	# Pila de libros y una calavera de estudio
	var bk := Vector3(0.3, _py, -0.04)
	M.box(parent, Vector3(0.12, 0.03, 0.08), M.mat(Color(0.55, 0.15, 0.15)), bk + Vector3(0, 0.015, 0))
	M.box(parent, Vector3(0.1, 0.03, 0.075), M.mat(Color(0.2, 0.3, 0.55)), bk + Vector3(0.005, 0.045, 0), Vector3(0, 12, 0))
	M.sphere(parent, 0.035, M.mat(Color(0.93, 0.9, 0.8)), bk + Vector3(-0.01, 0.09, 0), Vector3(1, 0.95, 1.05), 10)


# Burbujas del caldero (animadas)
func _build_cauldron_bubbles() -> void:
	var m := M.mat(GREEN_GLOW.lightened(0.2), 1.6)
	var offs := [Vector3(0.03, 0, 0.02), Vector3(-0.035, 0, -0.01), Vector3(0.0, 0, -0.04), Vector3(-0.01, 0, 0.04)]
	for i in offs.size():
		var o: Vector3 = offs[i]
		var b := M.sphere(self, 0.022, m, _cauldron + o, Vector3.ONE, 8)
		_bubbles.append(b)


# Maestría: frascos brillantes que orbitan y vapores verdes que suben alrededor de la torre
func _build_master_fx() -> void:
	_orbit = Node3D.new()
	_orbit.position = Vector3(0, _py * 0.72, 0)
	add_child(_orbit)
	var cols := [GREEN_GLOW, Color(0.75, 0.35, 1.0), Color(0.3, 0.75, 1.0)]
	for i in 3:
		var a := TAU * i / 3.0
		var holder := Node3D.new()
		holder.rotation.y = a
		_orbit.add_child(holder)
		var f := Node3D.new()
		holder.add_child(f)
		var inner := Node3D.new()
		inner.position = Vector3(0, 0, 0.47)
		f.add_child(inner)
		var c: Color = cols[i]
		M.sphere(inner, 0.035, M.mat(c, 1.8), Vector3.ZERO, Vector3.ONE, 10)
		M.cyl(inner, 0.011, 0.014, 0.04, M.mat(GLASS, 0.3), Vector3(0, 0.045, 0), Vector3.ZERO, 6)
		M.cyl(inner, 0.013, 0.013, 0.015, M.metal(GOLD), Vector3(0, 0.07, 0), Vector3.ZERO, 6)
		var halo := M.sphere(inner, 0.055, M.mat(c.lightened(0.3), 0.6), Vector3.ZERO, Vector3.ONE, 8)
		halo.transparency = 0.65
		_orbit_flasks.append(f)
	var p := CPUParticles3D.new()
	p.amount = 12
	p.lifetime = 1.8
	p.position = Vector3(0, _py * 0.5, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.42
	p.emission_ring_inner_radius = 0.38
	p.emission_ring_height = _py * 0.8
	p.direction = Vector3.UP
	p.spread = 10.0
	p.gravity = Vector3(0, 0.1, 0)
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.16
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.2))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.022
	mesh.height = 0.044
	mesh.radial_segments = 5
	mesh.rings = 3
	mesh.material = M.mat(Color(0.55, 1.0, 0.45), 2.0)
	p.mesh = mesh
	add_child(p)


# --- Alquimista ---

func _sleeve_mat() -> Material:
	match _tier:
		0: return M.mat(HOMESPUN)
		3: return M.mat(IVORY)
	return M.mat(PLUM)


func _build_human_body(c: Node3D) -> void:
	var t := _tier
	var robe: Material = _sleeve_mat()
	var robe_dark: Material
	match t:
		0: robe_dark = M.mat(HOMESPUN_DARK)
		3: robe_dark = M.mat(Color(0.8, 0.76, 0.66))
		_: robe_dark = M.mat(PLUM_DARK)
	var leather := M.mat(LEATHER)
	var leather_dark := M.mat(LEATHER_DARK)
	var brass := M.metal(BRASS)
	var gold := M.metal(GOLD)
	var trim: Material = gold if t == 3 else leather_dark
	Human.body(c, robe, trim)
	if t == 3:
		# túnica larga blanca con ribetes dorados y estola morada
		M.cyl(c, 0.15, 0.2, 0.09, robe, Vector3(0, 0.045, 0), Vector3.ZERO, 16)
		var hem := TorusMesh.new()
		hem.inner_radius = 0.18
		hem.outer_radius = 0.205
		M.add(c, hem, gold, Vector3(0, 0.01, 0))
		for s: float in [-1.0, 1.0]:
			M.box(c, Vector3(0.05, 0.3, 0.02), M.mat(PLUM), Vector3(0.055 * s, 0.17, -0.13), Vector3(-6, 0, 0))
			M.box(c, Vector3(0.055, 0.015, 0.025), gold, Vector3(0.055 * s, 0.03, -0.14))
		M.sphere(c, 0.026, M.mat(GREEN_GLOW, 2.0), Vector3(0, 0.24, -0.14), Vector3(1, 1, 0.5), 10)
		# capa con forro morado y ribete dorado
		M.box(c, Vector3(0.26, 0.36, 0.025), M.mat(PLUM_DARK), Vector3(0, 0.16, 0.15), Vector3(-14, 0, 0))
		M.box(c, Vector3(0.27, 0.025, 0.03), gold, Vector3(0, -0.01, 0.19), Vector3(-14, 0, 0))
		for s: float in [-1.0, 1.0]:
			M.sphere(c, 0.075, gold, Vector3(0.135 * s, 0.285, 0), Vector3(1, 0.6, 1), 10)
	else:
		# mandil de cuero con peto, bolsillo y correas
		M.box(c, Vector3(0.21, 0.24, 0.025), leather, Vector3(0, 0.1, -0.135), Vector3(-6, 0, 0))
		M.box(c, Vector3(0.14, 0.1, 0.025), leather, Vector3(0, 0.25, -0.125), Vector3(8, 0, 0))
		M.box(c, Vector3(0.08, 0.05, 0.012), leather_dark, Vector3(0.04, 0.08, -0.152), Vector3(-6, 0, 0))
		M.cyl(c, 0.01, 0.012, 0.045, M.mat(GREEN_GLOW, 1.2), Vector3(0.02, 0.115, -0.152), Vector3.ZERO, 6)
		for s: float in [-1.0, 1.0]:
			M.segment(c, 0.01, leather_dark, Vector3(0.065 * s, 0.29, -0.12), Vector3(0.06 * s, 0.35, -0.04), 4)
	if t == 2:
		# hombreras de latón y tabardo con alambique
		for s: float in [-1.0, 1.0]:
			M.sphere(c, 0.072, brass, Vector3(0.135 * s, 0.285, 0), Vector3(1, 0.62, 1), 10)
			M.cyl(c, 0.066, 0.066, 0.012, M.mat(PLUM_DARK), Vector3(0.14 * s, 0.26, 0), Vector3(0, 0, 18.0 * s), 10)
		M.box(c, Vector3(0.26, 0.3, 0.025), M.mat(PLUM_DARK), Vector3(0, 0.16, 0.14), Vector3(-10, 0, 0))
	# cinturón con frasquitos
	M.cyl(c, 0.152, 0.152, 0.025, gold if t == 3 else leather_dark, Vector3(0, 0.15, 0), Vector3.ZERO, 16)
	M.box(c, Vector3(0.035, 0.03, 0.015), brass, Vector3(0, 0.15, -0.152))
	if t >= 1:
		M.cyl(c, 0.015, 0.017, 0.05, M.mat(Color(0.75, 0.35, 1.0), 1.2), Vector3(-0.12, 0.13, -0.09), Vector3.ZERO, 6)
		M.cyl(c, 0.015, 0.017, 0.05, M.mat(Color(1.0, 0.55, 0.2), 1.2), Vector3(-0.145, 0.13, -0.03), Vector3.ZERO, 6)
	else:
		M.sphere(c, 0.035, leather, Vector3(-0.13, 0.11, -0.08), Vector3(1, 1.2, 1), 8)   # zurrón
	# cabeza bajo capucha
	var h := Human.head(c, false, false)
	M.sphere(h, 0.15, robe_dark, Vector3(0, 0.03, 0.04), Vector3(1.08, 1.08, 1.0), 14)
	M.cyl(c, 0.11, 0.17, 0.1, robe_dark, Vector3(0, 0.34, 0.02), Vector3.ZERO, 16)
	var tip := Node3D.new()
	tip.position = Human.HEAD + Vector3(0, 0.06, 0.13)
	tip.rotation = Vector3(-1.1 if t < 3 else -0.5, 0, 0)
	c.add_child(tip)
	M.cyl(tip, 0.0, 0.06, 0.12 if t < 3 else 0.2, robe_dark, Vector3(0, 0.05 if t < 3 else 0.09, 0), Vector3.ZERO, 8)
	if t == 3:
		var crown := TorusMesh.new()
		crown.inner_radius = 0.135
		crown.outer_radius = 0.155
		M.add(h, crown, gold, Vector3(0, 0.06, 0.0), Vector3(-12, 0, 0), Vector3(1.0, 0.6, 1.0))
	if t >= 1:
		# gafas de latón sobre la frente (incandescentes en Maestría)
		var band := TorusMesh.new()
		band.inner_radius = 0.13
		band.outer_radius = 0.148
		M.add(h, band, leather_dark, Vector3(0, 0.075, -0.01), Vector3(-12, 0, 0), Vector3(1.0, 0.6, 1.0))
		var lens := M.mat(Color(0.55, 0.95, 0.5), 0.9 if t < 3 else 2.2)
		for s: float in [-1.0, 1.0]:
			M.cyl(h, 0.034, 0.034, 0.03, gold if t == 3 else brass, Vector3(0.048 * s, 0.085, -0.122), Vector3(78, 0, 0), 12)
			M.cyl(h, 0.024, 0.024, 0.034, lens, Vector3(0.048 * s, 0.085, -0.124), Vector3(78, 0, 0), 12)
	# barba (larga y blanca en Maestría)
	if t == 3:
		M.sphere(h, 0.07, M.mat(Color(0.92, 0.9, 0.86)), Vector3(0, -0.11, -0.09), Vector3(1.1, 1.3, 0.7), 10)
	else:
		M.sphere(h, 0.06, M.mat(Color(0.35, 0.22, 0.13)), Vector3(0, -0.085, -0.095), Vector3(1.2, 0.8, 0.7), 10)
	# brazo izquierdo con un grimorio abierto
	var lh := Vector3(-0.16, 0.22, -0.2)
	Human.arm(c, Human.L_SHOULDER, lh, robe, trim)
	var book := Node3D.new()
	book.position = lh + Vector3(0.02, 0.03, -0.03)
	book.rotation = Vector3(-0.6, 0.3, 0)
	c.add_child(book)
	var cover := M.mat(Color(0.5, 0.14, 0.14)) if t < 3 else M.mat(Color(0.3, 0.15, 0.4))
	for s: float in [-1.0, 1.0]:
		M.box(book, Vector3(0.07, 0.012, 0.09), cover, Vector3(0.035 * s, 0, 0), Vector3(0, 0, -10.0 * s))
		M.box(book, Vector3(0.06, 0.012, 0.08), M.mat(Color(0.96, 0.92, 0.8)), Vector3(0.033 * s, 0.008, 0), Vector3(0, 0, -10.0 * s))
	if t == 3:
		M.sphere(book, 0.02, M.mat(GREEN_GLOW, 2.0), Vector3(0, 0.03, 0), Vector3.ONE, 8)


# Brazo derecho y frasco (animados)
func _build_human_parts() -> void:
	var c := cat_pivot
	_arm = M.add(c, M.tube_mesh(0.042, 8), _sleeve_mat())
	_cuff = M.add(c, M.tube_mesh(0.048, 8), M.metal(GOLD) if _tier == 3 else M.mat(LEATHER_DARK))
	_hand = M.sphere(c, 0.042, M.mat(Human.SKIN), Vector3.ZERO, Vector3(1, 1.1, 0.9), 8)
	_flask = Node3D.new()
	c.add_child(_flask)
	M.sphere(_flask, 0.045, M.mat(GREEN_GLOW, 1.6), Vector3.ZERO, Vector3.ONE, 12)
	M.cyl(_flask, 0.014, 0.018, 0.05, M.mat(GLASS, 0.3), Vector3(0, 0.055, 0), Vector3.ZERO, 8)
	M.cyl(_flask, 0.016, 0.016, 0.02, M.metal(GOLD) if _tier == 3 else M.mat(Color(0.65, 0.48, 0.3)), Vector3(0, 0.088, 0), Vector3.ZERO, 6)
	_flask_glow = M.sphere(_flask, 0.06, M.mat(Color(0.6, 1.0, 0.5), 0.6), Vector3.ZERO, Vector3.ONE, 10)
	_flask_glow.transparency = 0.6
