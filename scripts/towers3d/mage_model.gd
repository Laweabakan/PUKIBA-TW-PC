extends Node3D
## Modelo 3D de la torre de la maga de fuego (inspirado en el arte conceptual):
## base de piedra con ventanas incandescentes, cuerpo de entramado de roble con adornos dorados,
## estandartes con llama, braseros encendidos y una maga humana con vestido rojo, sombrero, bastón y orbe de fuego.
## El personaje mira hacia -Z dentro de cat_pivot; la torre lo rota hacia el enemigo.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const ArcherModel := preload("res://scripts/towers3d/archer_model.gd")   # comparte piedras y hierba de la base

const RED := Color(0.78, 0.13, 0.1)
const RED_DARK := Color(0.5, 0.08, 0.06)
const GOLD := Color(1.0, 0.76, 0.28)
const FIRE := Color(1.0, 0.32, 0.04)
const FIRE_CORE := Color(1.0, 0.72, 0.18)
const EMBER := Color(1.0, 0.45, 0.12)
const STONE_DARK := Color(0.4, 0.37, 0.35)
const IRON := Color(0.25, 0.23, 0.24)

const FUR := Color(0.98, 0.96, 0.93)
const FUR_GRAY := Color(0.58, 0.56, 0.55)
const FUR_STRIPE := Color(0.3, 0.28, 0.28)
const PINK := Color(0.96, 0.6, 0.58)
const STAFF_WOOD := Color(0.45, 0.25, 0.12)
const HAIR := Color(0.7, 0.18, 0.1)          # melena rojo fuego de la maga
const HAIR_TIP := Color(1.0, 0.5, 0.15)

const PLATFORM_Y := 1.17
const R_SHOULDER := Vector3(0.13, 0.27, -0.02)
const L_SHOULDER := Vector3(-0.13, 0.27, -0.02)
const STAFF_HAND := Vector3(0.2, 0.26, -0.12)   # la pata derecha sujeta el bastón aquí
const ORB_LOCAL := Vector3(0, 0.52, 0)           # orbe, relativo al pivote del bastón

## Altura de la plataforma (pies de la maga) en cada etapa visual
const TIER_PY := [0.8, 1.0, 1.17, 1.52]
## Etapa 3: el cuerpo de la torre se eleva sobre un zócalo de sillería blanca
const T3_LIFT := 0.35

var cat_pivot: Node3D
var _staff: Node3D
var _orb: Node3D
var _orb_glow: Node3D
var _hand_flame: Node3D
var _cape: Node3D
var _flames: Array[Node3D] = []
var _sparks: CPUParticles3D
var _tier := 0
var _py := PLATFORM_Y
var _aura: Node3D                      # etapa 3: bolas de fuego que orbitan la torre
var _pennants: Array[Node3D] = []      # etapa 3: gallardetes que ondean


## Etapa visual según el nivel (igual que TowerModels.tier)
static func _tier_of(level: int) -> int:
	if level >= 5:
		return 3
	if level >= 4:
		return 2
	if level >= 2:
		return 1
	return 0


## level: nivel de la torre. Etapas: 0 choza de piedra y madera con un brasero, 1 torre de piedra con
## planta de entramado, 2 gran torre de fuego dorada, 3 (Maestría) aguja de sillería blanca y oro con aura de fuego.
func _init(level := 0) -> void:
	_tier = _tier_of(level)
	_py = TIER_PY[_tier]
	M.add_baked(self, M.baked("mage_tower_t%d" % _tier, _build_tower_full))
	# llamas de los braseros (animadas, no se fusionan)
	for fp in _flame_spots():
		var spot: Array = fp
		_flames.append(_flame(self, spot[0], spot[1]))
	add_child(_embers(_tier))
	if _tier == 3:
		_build_majestic_parts()
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, _py, 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("mage_cat_t%d" % _tier, _build_cat_full))
	_build_cat_parts()
	set_pose(0.3, 0.0, 0.0)


# Posición y tamaño de las llamas animadas de cada etapa
func _flame_spots() -> Array:
	var spots: Array = []
	match _tier:
		0:
			spots.append([Vector3(0.3, _py + 0.2, 0.3), 0.9])
		1:
			for s in [-1.0, 1.0]:
				spots.append([Vector3(0.31 * s, _py + 0.21, 0.31), 1.0])
			spots.append([Vector3(0.43, 0.42, 0.12), 0.8])
		_:
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					spots.append([Vector3(0.3 * sx, _py + 0.19, 0.3 * sz), 1.0 if _tier == 2 else 1.15])
			for s in [-1.0, 1.0]:
				spots.append([Vector3(0.42 * s, 0.465, 0.42), 1.35])
	return spots


## charge: 0..1 carga de la bola de fuego (el orbe crece y el gatito echa el bastón atrás).
## cast: 1 justo al lanzar -> 0 (estocada del bastón). charging: chispas que se concentran en el orbe.
func set_pose(charge: float, cast: float, t: float, charging := false) -> void:
	_staff.rotation.x = lerpf(-0.15 + charge * 0.5, -0.95, cast)
	var s := 0.5 + charge * 1.1 + sin(t * 9.0) * 0.06
	_orb.scale = Vector3.ONE * s
	_orb_glow.rotation.y = t * (5.0 + charge * 15.0)
	_sparks.emitting = charging
	_hand_flame.scale = Vector3(1.0, 1.0 + sin(t * 11.0) * 0.25, 1.0) * (0.7 + charge * 0.6)
	_cape.rotation.x = -deg_to_rad(18.0 + sin(t * 5.0) * 7.0)
	for i in _flames.size():
		var f := _flames[i]
		var k := sin(t * 10.0 + i * 1.7)
		f.scale = Vector3(1.0 - k * 0.12, 1.0 + k * 0.25, 1.0 - k * 0.12)
		f.rotation.z = sin(t * 7.0 + i) * 0.12
	if _aura:
		_aura.rotation.y = t * (0.8 + charge * 1.6)
		_aura.position.y = _py + 0.42 + sin(t * 2.0) * 0.03
		for i in _aura.get_child_count():
			var fb := _aura.get_child(i) as Node3D
			fb.scale = Vector3.ONE * (0.8 + charge * 0.4 + sin(t * 9.0 + i * 2.0) * 0.12)
	for i in _pennants.size():
		_pennants[i].rotation.y = sin(t * 3.0 + i * 1.7) * 0.35 + (0.25 if i == 0 else -0.25)


# Posición global del orbe (de ahí sale la bola de fuego)
func orb_global() -> Vector3:
	return _orb.global_position


# Llama en forma de gota: cuerpo rojo anaranjado redondeado con punta, y corazón amarillo
static func _flame(parent: Node3D, pos: Vector3, s: float) -> Node3D:
	var f := Node3D.new()
	f.position = pos
	parent.add_child(f)
	var outer := M.mat(FIRE, 0.9)
	M.sphere(f, 0.05 * s, outer, Vector3(0, 0.045 * s, 0), Vector3(1, 1.15, 1), 12)
	M.cyl(f, 0.0, 0.043 * s, 0.1 * s, outer, Vector3(0, 0.11 * s, 0), Vector3.ZERO, 10)
	M.cyl(f, 0.0, 0.02 * s, 0.06 * s, outer, Vector3(0.025 * s, 0.1 * s, 0), Vector3(0, 0, -25), 6)
	M.cyl(f, 0.0, 0.02 * s, 0.05 * s, outer, Vector3(-0.025 * s, 0.09 * s, 0), Vector3(0, 0, 25), 6)
	M.sphere(f, 0.032 * s, M.mat(FIRE_CORE, 1.4), Vector3(0, 0.04 * s, -0.022 * s), Vector3(1, 1.3, 1), 10)
	return f


# --- Maga humana ---

# Color del vestido: lana teñida en la etapa 0, rojo de maga después, carmesí intenso en la Maestría
func _robe_col() -> Color:
	return [Color(0.6, 0.3, 0.18), RED, RED, Color(0.86, 0.1, 0.08)][_tier]


# Ribetes: lino crudo en la etapa 0, oro después
func _trim_mat() -> Material:
	return M.mat(Color(0.86, 0.78, 0.6)) if _tier == 0 else M.metal(GOLD)


func _build_cat_body(c: Node3D) -> void:
	var fur := M.mat(FUR)
	var gray := M.mat(FUR_GRAY)
	var stripe := M.mat(FUR_STRIPE)
	var pink := M.mat(PINK)
	var robe := M.mat(_robe_col())
	var gold := _trim_mat()
	var black := M.mat(Color(0.05, 0.05, 0.05))

	# Túnica roja con ribetes dorados, cinturón y cascabel
	M.sphere(c, 0.145, robe, Vector3(0, 0.17, 0), Vector3(1.05, 1.15, 0.95), 14)
	# falda acampanada con bajo dorado y volante
	M.cyl(c, 0.12, 0.215, 0.16, robe, Vector3(0, 0.075, 0), Vector3.ZERO, 20)
	M.cyl(c, 0.218, 0.218, 0.022, gold, Vector3(0, 0.0, 0), Vector3.ZERO, 20)
	M.cyl(c, 0.2, 0.2, 0.018, M.mat(Color(0.98, 0.9, 0.8)), Vector3(0, 0.03, 0), Vector3.ZERO, 20)
	M.cyl(c, 0.15, 0.15, 0.03, M.mat(Color(0.95, 0.9, 0.8)), Vector3(0, 0.13, 0), Vector3.ZERO, 14)
	M.sphere(c, 0.03, gold, Vector3(0, 0.27, -0.13), Vector3.ONE, 10)
	M.sphere(c, 0.022, M.mat(Color(0.85, 0.15, 0.12)), Vector3(0.0, 0.13, -0.15), Vector3(1.4, 0.8, 0.6), 8)
	for s in [-1.0, 1.0]:
		M.sphere(c, 0.065, robe, Vector3(0.13 * s, 0.27, 0), Vector3.ONE, 10)
		M.cyl(c, 0.068, 0.068, 0.015, gold, Vector3(0.13 * s, 0.24, 0), Vector3.ZERO, 10)
	# bolsita dorada en la cintura
	M.box(c, Vector3(0.06, 0.06, 0.03), M.mat(Color(0.65, 0.48, 0.25)), Vector3(0.1, 0.11, -0.13))

	# Cabeza humana (el pelo largo y el sombrero se añaden aparte)
	var head := Human.head(c, false, false)
	for side in [-1.0, 1.0]:
		for k in 3:
			var lash := Node3D.new()
			lash.position = Vector3((0.062 + k * 0.006) * side, 0.022 - k * 0.006, -0.125)
			lash.rotation = Vector3(0, 0, -(55.0 + k * 22.0) * side * PI / 180.0)
			head.add_child(lash)
			M.box(lash, Vector3(0.005, 0.018, 0.005), black, Vector3(0, 0.009, 0))
	M.sphere(head, 0.012, M.mat(Color(0.75, 0.2, 0.2)), Vector3(0, -0.075, -0.13), Vector3(2.0, 0.7, 0.6), 6)

	# Brazo izquierdo extendido (lanza llamas con la pata) y brazo derecho que sujeta el bastón
	var paw_l := Vector3(-0.14, 0.33, -0.25)
	M.segment(c, 0.045, robe, L_SHOULDER, paw_l, 8)
	M.sphere(c, 0.042, M.mat(Human.SKIN), paw_l, Vector3(1, 1.1, 0.9), 8)
	M.segment(c, 0.045, robe, R_SHOULDER, STAFF_HAND, 8)
	M.sphere(c, 0.042, M.mat(Human.SKIN), STAFF_HAND, Vector3(1, 1.1, 0.9), 8)
	if _tier == 3:
		# hombreras doradas con rubí y fajín blanco bordado de la Maestría
		for s in [-1.0, 1.0]:
			M.sphere(c, 0.075, M.metal(GOLD), Vector3(0.14 * s, 0.29, 0), Vector3(1.0, 0.6, 1.0), 12)
			M.sphere(c, 0.018, M.mat(Color(1.0, 0.25, 0.1), 1.6), Vector3(0.15 * s, 0.31, -0.06), Vector3.ONE, 6)
		M.cyl(c, 0.152, 0.152, 0.035, M.mat(Color(0.98, 0.95, 0.88)), Vector3(0, 0.1, 0), Vector3.ZERO, 16)
		M.cyl(c, 0.225, 0.225, 0.012, M.metal(GOLD), Vector3(0, 0.05, 0), Vector3.ZERO, 20)


# Partes animadas: capa, bastón con orbe y llama en la pata
func _build_cat_parts() -> void:
	var c := cat_pivot
	_cape = Node3D.new()
	_cape.position = Vector3(0, 0.33, 0.1)
	c.add_child(_cape)
	match _tier:
		0:
			M.box(_cape, Vector3(0.26, 0.28, 0.02), M.mat(Color(0.42, 0.26, 0.16)), Vector3(0, -0.13, 0))
		3:
			# capa larga de Maestría: carmesí con orla dorada y llama bordada
			M.box(_cape, Vector3(0.36, 0.44, 0.02), M.mat(RED_DARK), Vector3(0, -0.21, 0))
			M.box(_cape, Vector3(0.38, 0.03, 0.03), M.metal(GOLD), Vector3(0, -0.43, 0))
			for s in [-1.0, 1.0]:
				M.box(_cape, Vector3(0.025, 0.44, 0.026), M.metal(GOLD), Vector3(0.18 * s, -0.21, 0))
			_gold_flame(_cape, Vector3(0, -0.22, 0.016), 1.3)
		_:
			M.box(_cape, Vector3(0.3, 0.32, 0.02), M.mat(RED_DARK), Vector3(0, -0.15, 0))
			M.box(_cape, Vector3(0.3, 0.025, 0.025), M.metal(GOLD), Vector3(0, -0.3, 0))

	# bastón: pivota en la mano para dar la estocada al lanzar
	_staff = Node3D.new()
	_staff.position = STAFF_HAND
	c.add_child(_staff)
	var wood := M.mat(STAFF_WOOD) if _tier < 3 else M.mat(Color(0.95, 0.92, 0.85))
	var gold := M.metal(GOLD) if _tier > 0 else M.mat(Color(0.5, 0.32, 0.18))
	M.segment(_staff, 0.018, wood, Vector3(0, -0.24, 0), Vector3(0, 0.42, 0), 8)
	if _tier == 3:
		for y in [-0.12, 0.15, 0.3]:
			M.cyl(_staff, 0.022, 0.022, 0.025, M.metal(GOLD), Vector3(0, y, 0), Vector3.ZERO, 8)
		for s in [-1.0, 1.0]:
			M.cyl(_staff, 0.0, 0.02, 0.09, M.metal(GOLD), ORB_LOCAL + Vector3(0.1 * s, 0.03, 0), Vector3(0, 0, -30.0 * s), 6)
	M.cyl(_staff, 0.024, 0.024, 0.04, gold, Vector3(0, 0.0, 0), Vector3.ZERO, 8)
	var hook := TorusMesh.new()
	hook.inner_radius = 0.075
	hook.outer_radius = 0.095
	M.add(_staff, hook, gold, ORB_LOCAL, Vector3(90, 0, 0))
	M.sphere(_staff, 0.025, gold, Vector3(0, 0.43, 0), Vector3.ONE, 8)
	_orb = Node3D.new()
	_orb.position = ORB_LOCAL
	_staff.add_child(_orb)
	M.sphere(_orb, 0.062, M.mat(FIRE_CORE, 1.6), Vector3.ZERO, Vector3.ONE, 12)
	# lenguas de fuego girando alrededor del orbe
	_orb_glow = Node3D.new()
	_orb.add_child(_orb_glow)
	for i in 4:
		var wisp := Node3D.new()
		wisp.rotation = Vector3(0, TAU * i / 4.0, 0.9)
		_orb_glow.add_child(wisp)
		M.cyl(wisp, 0.0, 0.03, 0.09, M.mat(FIRE, 0.9), Vector3(0, 0.08, 0), Vector3.ZERO, 6)

	_hand_flame = _flame(c, Vector3(-0.14, 0.36, -0.27), 0.7)

	# chispas que giran y se concentran en el orbe mientras carga
	_sparks = CPUParticles3D.new()
	_sparks.emitting = false
	_sparks.amount = 20
	_sparks.lifetime = 0.45
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	_sparks.emission_sphere_radius = 0.24
	_sparks.gravity = Vector3.ZERO
	_sparks.radial_accel_min = -3.5
	_sparks.radial_accel_max = -2.5
	_sparks.tangential_accel_min = 2.0
	_sparks.tangential_accel_max = 3.0
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.016
	spark_mesh.height = 0.032
	spark_mesh.radial_segments = 6
	spark_mesh.rings = 3
	spark_mesh.material = M.mat(FIRE_CORE, 1.8)
	_sparks.mesh = spark_mesh
	_orb.add_child(_sparks)


# Brasas que suben alrededor de la torre
static func _embers(tier: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = [6, 10, 14, 26][tier]
	p.lifetime = 1.8 if tier < 3 else 2.2
	p.position = Vector3(0, [0.7, 0.8, 0.9, 1.15][tier], 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.45, 0.4, 0.45) if tier > 0 else Vector3(0.3, 0.3, 0.3)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3(0, 0.35, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.014
	mesh.height = 0.028
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = M.mat(Color(1.0, 0.5, 0.12), 1.6)
	p.mesh = mesh
	return p


# Llamita dorada decorativa (emblema)
static func _gold_flame(parent: Node3D, pos: Vector3, s: float) -> void:
	var gold := M.metal(GOLD)
	M.sphere(parent, 0.035 * s, gold, pos, Vector3(1, 1.15, 0.5), 10)
	M.cyl(parent, 0.0, 0.03 * s, 0.07 * s, gold, pos + Vector3(0, 0.06 * s, 0), Vector3.ZERO, 8)
	M.cyl(parent, 0.0, 0.014 * s, 0.04 * s, gold, pos + Vector3(0.022 * s, 0.04 * s, 0), Vector3(0, 0, -30), 6)
	M.cyl(parent, 0.0, 0.014 * s, 0.04 * s, gold, pos + Vector3(-0.022 * s, 0.04 * s, 0), Vector3(0, 0, 30), 6)


# Ventana con forma de llama: marco de hierro y fuego dentro
static func _flame_window(parent: Node3D, pos: Vector3) -> void:
	var iron := M.metal(IRON)
	var ember := M.mat(EMBER, 1.6)
	M.sphere(parent, 0.058, iron, pos, Vector3(0.9, 1.15, 0.3), 12)
	M.cyl(parent, 0.0, 0.045, 0.09, iron, pos + Vector3(0, 0.085, 0), Vector3.ZERO, 8)
	M.sphere(parent, 0.044, ember, pos + Vector3(0, 0, 0.008), Vector3(0.9, 1.15, 0.3), 12)
	M.cyl(parent, 0.0, 0.032, 0.07, ember, pos + Vector3(0, 0.075, 0.008), Vector3.ZERO, 8)
	M.box(parent, Vector3(0.012, 0.1, 0.02), iron, pos + Vector3(0, 0.0, 0.02))


# --- Torre de fuego (fiel al arte conceptual) ---

## lift: en la Maestría el cuerpo entero se eleva sobre el zócalo blanco (los pedestales y estacas quedan en el suelo).
func _build_fire_tower(root: Node3D, lift := 0.0) -> void:
	var parent := Node3D.new()
	parent.position.y = lift
	root.add_child(parent)
	var stone_cols := [Color(0.58, 0.56, 0.53), Color(0.5, 0.48, 0.46), Color(0.64, 0.62, 0.58), Color(0.45, 0.43, 0.41)]
	if lift > 0.0:
		# Maestría: sillería blanca y caliza dorada
		stone_cols = [Color(0.95, 0.92, 0.86), Color(0.86, 0.83, 0.77), Color(1.0, 0.97, 0.92), Color(0.8, 0.77, 0.72)]
	# Estilo europeo: entramado de roble oscuro en lugar de madera lacada en rojo
	var red := M.mat(Color(0.4, 0.25, 0.14))
	var red_dark := M.mat(Color(0.26, 0.16, 0.09))
	var gold := M.metal(GOLD)
	var iron := M.metal(IRON)
	var ember := M.mat(EMBER, 1.6)
	var roof := M.tex_mat("roof", 2.5, Color(0.36, 0.36, 0.44) if lift == 0.0 else Color(0.85, 0.24, 0.16))
	var wood_dark := M.mat(Color(0.3, 0.17, 0.1))
	var rope := M.mat(Color(0.82, 0.7, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77

	# Base de grandes piedras irregulares (como bloques tallados a mano)
	if lift == 0.0:
		M.box(parent, Vector3(0.94, 0.08, 0.94), M.mat(Color(0.45, 0.43, 0.41)), Vector3(0, 0.04, 0))
	M.box(parent, Vector3(0.7, 0.5, 0.7), M.mat(Color(0.42, 0.4, 0.38) if lift == 0.0 else Color(0.82, 0.79, 0.74)), Vector3(0, 0.33, 0))
	var faces := [[Vector3(0, 0, 1), Vector3(1, 0, 0)], [Vector3(0, 0, -1), Vector3(1, 0, 0)],
			[Vector3(1, 0, 0), Vector3(0, 0, 1)], [Vector3(-1, 0, 0), Vector3(0, 0, 1)]]
	for fi in faces.size():
		var n: Vector3 = faces[fi][0]
		var tg: Vector3 = faces[fi][1]
		for row in 3:
			var x := -0.39 + (0.07 if row % 2 == 1 else 0.0)
			while x < 0.39:
				var w := rng.randf_range(0.15, 0.22)
				var cx := minf(x + w / 2.0, 0.36)
				x += w + 0.012
				# hueco para la puerta en el frente
				if fi == 0 and absf(cx) < 0.17 and row < 3 and lift == 0.0:
					continue
				var h := rng.randf_range(0.13, 0.155)
				var pos := n * (0.36 + rng.randf_range(0.0, 0.02)) + tg * cx + Vector3(0, 0.15 + row * 0.155, 0)
				var size := Vector3(w, h, 0.08) if absf(n.z) > 0.5 else Vector3(0.08, h, w)
				M.box(parent, size, M.mat(stone_cols[rng.randi() % stone_cols.size()]), pos)
	for p in [Vector3(-0.38, 0.1, 0.4), Vector3(0.39, 0.12, -0.2), Vector3(-0.2, 0.08, -0.42)]:
		M.sphere(root, 0.05, M.mat(Color(0.4, 0.55, 0.22)), p, Vector3(1.3, 0.5, 1.0), 8)
	# armazón de madera que abraza la base de piedra
	var frame_wood := M.tex_mat("wood", 2.5, Color(0.55, 0.32, 0.2))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.1, 0.56, 0.1), frame_wood, Vector3(0.385 * sx, 0.32, 0.385 * sz))
			M.box(parent, Vector3(0.12, 0.05, 0.12), iron, Vector3(0.385 * sx, 0.16, 0.385 * sz))
			M.sphere(parent, 0.013, gold, Vector3(0.385 * sx, 0.16, 0.385 * sz + 0.062 * sz), Vector3.ONE, 6)
	for s in [-1.0, 1.0]:
		M.box(parent, Vector3(0.84, 0.065, 0.07), frame_wood, Vector3(0, 0.575, 0.4 * s))
		M.box(parent, Vector3(0.07, 0.065, 0.84), frame_wood, Vector3(0.4 * s, 0.575, 0))
		M.box(parent, Vector3(0.07, 0.05, 0.84), frame_wood, Vector3(0.4 * s, 0.09, 0))
		M.box(parent, Vector3(0.84, 0.05, 0.07), frame_wood, Vector3(0, 0.09, -0.4))

	if lift == 0.0:
		# Puerta doble de madera en arco apuntado: marco de piedra, tablones, bandas de hierro y aldabas
		var door := Vector3(0, 0, 0.385)
		var door_wood := M.tex_mat("wood", 3.0, Color(0.62, 0.36, 0.22))
		var seam := M.mat(Color(0.2, 0.11, 0.06))
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.07, 0.36, 0.09), M.mat(stone_cols[2]), door + Vector3(0.16 * s, 0.22, 0))
		M.box(parent, Vector3(0.21, 0.21, 0.07), M.mat(stone_cols[2]), door + Vector3(0, 0.37, -0.012), Vector3(0, 0, 45))
		M.box(parent, Vector3(0.25, 0.3, 0.03), door_wood, door + Vector3(0, 0.19, 0.012))
		M.box(parent, Vector3(0.165, 0.165, 0.03), door_wood, door + Vector3(0, 0.34, 0.012), Vector3(0, 0, 45))
		for k in [-0.08, -0.04, 0.0, 0.04, 0.08]:
			var hgt := 0.4 - absf(k) * 2.2
			M.box(parent, Vector3(0.007 if k != 0.0 else 0.012, hgt, 0.01), seam, door + Vector3(k, 0.04 + hgt / 2.0, 0.03))
		for y in [0.1, 0.27]:
			M.box(parent, Vector3(0.25, 0.026, 0.012), iron, door + Vector3(0, y, 0.033))
			for x in [-0.1, -0.05, 0.05, 0.1]:
				M.sphere(parent, 0.011, gold, door + Vector3(x, y, 0.04), Vector3.ONE, 6)
		for s in [-1.0, 1.0]:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.016
			ring.outer_radius = 0.024
			M.add(parent, ring, gold, door + Vector3(0.035 * s, 0.17, 0.042), Vector3(90, 0, 0))
			M.sphere(parent, 0.013, gold, door + Vector3(0.035 * s, 0.195, 0.04), Vector3.ONE, 6)
		_gold_flame(parent, door + Vector3(0, 0.52, 0.01), 1.3)
		# escalón de piedra (bajo: delante quedan las gemas de nivel)
		M.box(parent, Vector3(0.36, 0.03, 0.08), M.mat(stone_cols[1]), Vector3(0, 0.015, 0.43))

	# Pedestales delanteros: piedra + farol de hierro con ventanas de llama + brasero dorado
	for s in [-1.0, 1.0]:
		var pc := Vector3(0.42 * s, 0, 0.42)
		M.box(root, Vector3(0.17, 0.2, 0.17), M.mat(stone_cols[0]), pc + Vector3(0, 0.1, 0))
		M.box(root, Vector3(0.13, 0.16, 0.13), iron, pc + Vector3(0, 0.28, 0))
		for face in [Vector3(0, 0, 1), Vector3(s, 0, 0)]:
			var win: Vector3 = pc + Vector3(0, 0.27, 0) + face * 0.067
			var holder := Node3D.new()
			holder.position = win
			holder.rotation.y = 0.0 if face.z > 0.5 else PI / 2.0 * s
			root.add_child(holder)
			M.sphere(holder, 0.03, ember, Vector3.ZERO, Vector3(0.9, 1.2, 0.3), 10)
			M.cyl(holder, 0.0, 0.024, 0.05, ember, Vector3(0, 0.045, 0), Vector3.ZERO, 6)
		M.box(root, Vector3(0.16, 0.025, 0.16), gold, pc + Vector3(0, 0.37, 0))
		M.cyl(root, 0.1, 0.055, 0.08, gold, pc + Vector3(0, 0.425, 0), Vector3.ZERO, 16)
		M.cyl(root, 0.085, 0.085, 0.012, M.mat(Color(0.25, 0.08, 0.03)), pc + Vector3(0, 0.46, 0), Vector3.ZERO, 14)
		for y in [0.05, 0.2]:
			M.sphere(root, 0.012, gold, pc + Vector3(0, y, 0.087), Vector3.ONE, 6)

	# Cuerpo superior de madera lacada roja con herrajes de hierro y remaches dorados
	var red_wood := M.tex_mat("wood", 2.2, Color(1.0, 0.42, 0.36))
	M.box(parent, Vector3(0.68, 0.36, 0.68), red_wood, Vector3(0, 0.75, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.085, 0.38, 0.085), wood_dark, Vector3(0.335 * sx, 0.75, 0.335 * sz))
			for y in [0.62, 0.88]:
				M.box(parent, Vector3(0.11, 0.075, 0.11), iron, Vector3(0.335 * sx, y, 0.335 * sz))
				for k in [-1.0, 1.0]:
					M.sphere(parent, 0.012, gold, Vector3(0.335 * sx + 0.025 * k, y, 0.335 * sz + 0.056 * sz), Vector3.ONE, 6)
	for y in [0.58, 0.92]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.72, 0.04, 0.04), wood_dark, Vector3(0, y, 0.35 * s))
			M.box(parent, Vector3(0.04, 0.04, 0.72), wood_dark, Vector3(0.35 * s, y, 0))
			M.box(parent, Vector3(0.72, 0.012, 0.012), gold, Vector3(0, y + 0.022, 0.37 * s))
	# ventanas en forma de llama (a los lados del estandarte central y en los laterales)
	for s in [-1.0, 1.0]:
		_flame_window(parent, Vector3(0.24 * s, 0.73, 0.352))
		_flame_window(parent, Vector3(0.352, 0.73, 0.14 * s))
		_flame_window(parent, Vector3(-0.352, 0.73, 0.14 * s))

	# Estandarte central grande: rojo con borde dorado, llama dorada, olas y borde dentado
	M.box(parent, Vector3(0.28, 0.025, 0.025), gold, Vector3(0, 0.9, 0.375))
	for s in [-1.0, 1.0]:
		M.sphere(parent, 0.022, gold, Vector3(0.15 * s, 0.9, 0.375), Vector3.ONE, 8)
	M.box(parent, Vector3(0.2, 0.42, 0.014), gold, Vector3(0, 0.68, 0.37))
	M.box(parent, Vector3(0.175, 0.4, 0.02), red, Vector3(0, 0.685, 0.373))
	M.cyl(parent, 0.06, 0.06, 0.012, gold, Vector3(0, 0.74, 0.386), Vector3(90, 0, 0), 18)
	M.cyl(parent, 0.048, 0.048, 0.014, red, Vector3(0, 0.74, 0.388), Vector3(90, 0, 0), 18)
	_gold_flame(parent, Vector3(0, 0.72, 0.397), 0.75)
	for k in 3:
		M.box(parent, Vector3(0.14, 0.01, 0.006), M.mat(GOLD), Vector3(0, 0.56 + k * 0.022, 0.386))
	for k in [-1.0, 0.0, 1.0]:
		M.cyl(parent, 0.0, 0.03, 0.045, red, Vector3(0.06 * k, 0.465, 0.373), Vector3(180, 0, 0), 4)

	# Estandartes laterales colgando de varas doradas por fuera de la torre
	for s in [-1.0, 1.0]:
		var bx: float = 0.53 * s
		M.box(parent, Vector3(0.26, 0.022, 0.022), gold, Vector3(0.45 * s, 0.92, 0.2))
		M.sphere(parent, 0.025, gold, Vector3(0.59 * s, 0.92, 0.2), Vector3.ONE, 8)
		for k in [-1.0, 1.0]:
			M.cyl(parent, 0.014, 0.014, 0.012, gold, Vector3(bx + 0.06 * k, 0.9, 0.2), Vector3(90, 0, 0), 8)
		M.box(parent, Vector3(0.17, 0.4, 0.014), gold, Vector3(bx, 0.68, 0.2))
		M.box(parent, Vector3(0.145, 0.38, 0.02), red, Vector3(bx, 0.685, 0.203))
		_gold_flame(parent, Vector3(bx, 0.71, 0.216), 0.65)
		for k in 2:
			M.box(parent, Vector3(0.11, 0.01, 0.006), M.mat(GOLD), Vector3(bx, 0.55 + k * 0.022, 0.215))
		for k in [-1.0, 1.0]:
			M.cyl(parent, 0.0, 0.03, 0.045, red, Vector3(bx + 0.035 * k, 0.465, 0.203), Vector3(180, 0, 0), 4)
		M.cyl(parent, 0.012, 0.028, 0.07, M.mat(RED_DARK), Vector3(bx, 0.42, 0.2), Vector3.ZERO, 8)

	# Tejado de tejas oscuras con ribete dorado, cuernos en media luna y medallón con llama
	M.cyl(parent, 0.38, 0.74, 0.22, roof, Vector3(0, 1.04, 0), Vector3(0, 45, 0), 4)
	for s in [-1.0, 1.0]:
		M.box(parent, Vector3(1.06, 0.035, 0.035), gold, Vector3(0, 0.935, 0.525 * s))
		M.box(parent, Vector3(0.035, 0.035, 1.06), gold, Vector3(0.525 * s, 0.935, 0))
	M.cyl(parent, 0.28, 0.28, 0.03, gold, Vector3(0, 1.15, 0), Vector3(0, 45, 0), 4)
	M.cyl(parent, 0.1, 0.1, 0.022, gold, Vector3(0, 1.05, 0.42), Vector3(52, 0, 0), 20)
	M.cyl(parent, 0.077, 0.077, 0.024, red, Vector3(0, 1.055, 0.425), Vector3(52, 0, 0), 20)
	var roof_emblem := Node3D.new()
	roof_emblem.position = Vector3(0, 1.045, 0.44)
	roof_emblem.rotation.x = deg_to_rad(-38)
	parent.add_child(roof_emblem)
	_gold_flame(roof_emblem, Vector3.ZERO, 0.8)
	# almenas de piedra en las esquinas (estilo europeo)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.14, 0.12, 0.14), M.mat(Color(0.55, 0.53, 0.5)), Vector3(0.5 * sx, 1.0, 0.5 * sz))

	# cabezas de las vigas asomando bajo el alero
	for k in 7:
		var o := -0.42 + k * 0.14
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.045, 0.045, 0.16), frame_wood, Vector3(o, 0.92, 0.44 * s))
			M.box(parent, Vector3(0.16, 0.045, 0.045), frame_wood, Vector3(0.44 * s, 0.92, o))

	# Plataforma de tablones con barandilla, remates dorados en forma de cebolla y braseros en las esquinas
	M.box(parent, Vector3(0.7, 0.07, 0.7), M.tex_mat("wood", 2.5, Color(0.7, 0.36, 0.26)), Vector3(0, 1.14, 0))
	for s in [-1.0, 1.0]:
		M.box(parent, Vector3(0.72, 0.04, 0.04), frame_wood, Vector3(0, 1.12, 0.35 * s))
		M.box(parent, Vector3(0.04, 0.04, 0.72), frame_wood, Vector3(0.35 * s, 1.12, 0))
	for y in [1.22, 1.28]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.6, 0.025, 0.025), red, Vector3(0, y, 0.3 * s))
			M.box(parent, Vector3(0.025, 0.025, 0.6), red, Vector3(0.3 * s, y, 0))
	for p in [Vector3(0, 0, 0.3), Vector3(0, 0, -0.3), Vector3(0.3, 0, 0), Vector3(-0.3, 0, 0)]:
		M.box(parent, Vector3(0.045, 0.13, 0.045), red_dark, p + Vector3(0, 1.24, 0))
		M.sphere(parent, 0.03, gold, p + Vector3(0, 1.33, 0), Vector3(1, 1.1, 1), 10)
		M.cyl(parent, 0.0, 0.02, 0.05, gold, p + Vector3(0, 1.38, 0), Vector3.ZERO, 6)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.065, 0.13, 0.065), red_dark, Vector3(0.3 * sx, 1.235, 0.3 * sz))
			M.cyl(parent, 0.085, 0.05, 0.07, gold, Vector3(0.3 * sx, 1.33, 0.3 * sz), Vector3.ZERO, 14)

	# Estacas rojas con cuerda y punta dorada a los lados
	for p in [Vector3(0.47, 0, 0.12), Vector3(-0.47, 0, 0.12), Vector3(0.47, 0, -0.3), Vector3(-0.47, 0, -0.3)]:
		M.cyl(root, 0.03, 0.03, 0.28, red_dark, p + Vector3(0, 0.14, 0), Vector3.ZERO, 6)
		M.cyl(root, 0.0, 0.035, 0.08, gold, p + Vector3(0, 0.32, 0), Vector3.ZERO, 4)
		for y in [0.1, 0.17]:
			M.cyl(root, 0.036, 0.036, 0.022, rope, p + Vector3(0, y, 0), Vector3.ZERO, 8)

# --- Detalles extra (para parecerse más al arte conceptual) ---

func _build_tower_full(parent: Node3D) -> void:
	match _tier:
		0:
			_build_hut(parent)
		1:
			_build_keep(parent)
		2:
			_build_fire_tower(parent)
		_:
			_build_plinth(parent)
			_build_fire_tower(parent, T3_LIFT)
			_build_majestic(parent)
	ArcherModel._ground_details(parent, false)


# --- Etapa 0: choza-torre de piedra de campo y troncos con un brasero ---

func _build_hut(parent: Node3D) -> void:
	var py := _py
	var stones := [M.mat(Color(0.56, 0.53, 0.5)), M.mat(Color(0.47, 0.45, 0.42)), M.mat(Color(0.63, 0.6, 0.55))]
	var earth := M.mat(Color(0.46, 0.35, 0.23))
	var planks := M.tex_mat("wood", 2.5, Color(0.78, 0.56, 0.38))
	var log_m := M.mat(Color(0.44, 0.29, 0.16))
	var log_dark := M.mat(Color(0.3, 0.19, 0.1))
	var iron := M.metal(IRON)
	var ember := M.mat(EMBER, 1.6)
	var rope := M.mat(Color(0.8, 0.68, 0.48))
	var cloth := M.mat(Color(0.7, 0.28, 0.14))

	# Suelo de tierra pisada y zócalo de piedras de campo
	M.cyl(parent, 0.44, 0.46, 0.04, earth, Vector3(0, 0.02, 0), Vector3.ZERO, 18)
	M.box(parent, Vector3(0.6, 0.3, 0.6), stones[1], Vector3(0, 0.18, 0))
	ArcherModel._stone_blocks(parent, 0.3, 0.1, 2, [[0, 1]], stones)
	# Puertecilla de tablas con travesaño
	M.box(parent, Vector3(0.17, 0.25, 0.03), M.mat(Color(0.42, 0.26, 0.14)), Vector3(0, 0.165, 0.305))
	for k in [-0.04, 0.0, 0.04]:
		M.box(parent, Vector3(0.006, 0.24, 0.01), log_dark, Vector3(k, 0.165, 0.322))
	M.box(parent, Vector3(0.17, 0.025, 0.012), log_dark, Vector3(0, 0.2, 0.324), Vector3(0, 0, 18))
	M.sphere(parent, 0.012, iron, Vector3(0.05, 0.16, 0.326), Vector3.ONE, 6)

	# Planta alta de tablones con postes de tronco en las esquinas
	M.box(parent, Vector3(0.54, py - 0.34, 0.54), planks, Vector3(0, 0.33 + (py - 0.34) / 2.0, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.cyl(parent, 0.04, 0.045, py, log_m, Vector3(0.28 * sx, py / 2.0, 0.28 * sz), Vector3.ZERO, 7)
	for y in [0.35, py - 0.06]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.6, 0.04, 0.045), log_dark, Vector3(0, y, 0.28 * s))
			M.box(parent, Vector3(0.045, 0.04, 0.6), log_dark, Vector3(0.28 * s, y, 0))
	# ventanucos con contraventana y el resplandor del fuego dentro
	for face in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var w := Node3D.new()
		w.position = face * 0.272 + Vector3(0, 0.56, 0)
		w.rotation.y = atan2(face.x, face.z)
		parent.add_child(w)
		M.box(w, Vector3(0.11, 0.12, 0.02), log_dark)
		M.box(w, Vector3(0.08, 0.09, 0.02), ember, Vector3(0, 0, 0.006))
		M.box(w, Vector3(0.012, 0.1, 0.015), log_dark, Vector3(0, 0, 0.014))
		M.box(w, Vector3(0.05, 0.11, 0.015), planks, Vector3(0.085, 0, 0.01), Vector3(0, -35, 0))

	# Plataforma de tablones con viguetas asomando y barandilla de troncos
	M.box(parent, Vector3(0.7, 0.06, 0.7), planks, Vector3(0, py - 0.03, 0))
	for k in 4:
		var o := -0.21 + k * 0.14
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.04, 0.04, 0.1), log_m, Vector3(o, py - 0.07, 0.34 * s))
	var corners := [Vector3(0.32, 0, 0.32), Vector3(-0.32, 0, 0.32), Vector3(-0.32, 0, -0.32), Vector3(0.32, 0, -0.32)]
	for i in 4:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		if i != 0:
			M.cyl(parent, 0.022, 0.026, 0.2, log_m, a + Vector3(0, py + 0.1, 0), Vector3.ZERO, 6)
		# lateral izquierdo abierto: por ahí sube la escalera
		if i == 1:
			continue
		M.segment(parent, 0.017, log_m, a + Vector3(0, py + 0.17, 0), b + Vector3(0, py + 0.17, 0), 6)
		M.segment(parent, 0.013, log_dark, a + Vector3(0, py + 0.08, 0), b + Vector3(0, py + 0.08, 0), 6)
	for p in [Vector3(-0.32, 0, 0.32), Vector3(0.32, 0, -0.32)]:
		M.cyl(parent, 0.03, 0.03, 0.02, rope, p + Vector3(0, py + 0.17, 0), Vector3.ZERO, 6)

	# Escalera de mano apoyada en el lado izquierdo
	for s in [-1.0, 1.0]:
		M.segment(parent, 0.016, log_m, Vector3(-0.46, 0.02, 0.09 * s), Vector3(-0.35, py + 0.12, 0.09 * s), 6)
	for k in 5:
		var f := (k + 0.6) / 5.6
		var lx := lerpf(-0.46, -0.35, f)
		var ly := 0.02 + f * (py + 0.1)
		M.segment(parent, 0.01, log_dark, Vector3(lx, ly, -0.09), Vector3(lx, ly + 0.0001, 0.09), 4)

	# Brasero de hierro sobre un poste en la esquina delantera
	var bp := Vector3(0.3, py, 0.3)
	M.cyl(parent, 0.03, 0.035, 0.16, log_m, bp + Vector3(0, 0.08, 0), Vector3.ZERO, 6)
	M.cyl(parent, 0.085, 0.045, 0.07, iron, bp + Vector3(0, 0.18, 0), Vector3.ZERO, 10)
	M.cyl(parent, 0.072, 0.072, 0.01, M.mat(Color(0.25, 0.08, 0.03)), bp + Vector3(0, 0.215, 0), Vector3.ZERO, 10)

	# Paño rojo con una llama pintada colgando de la barandilla
	M.box(parent, Vector3(0.18, 0.2, 0.012), cloth, Vector3(0, py + 0.06, 0.335))
	M.sphere(parent, 0.028, M.mat(Color(1.0, 0.62, 0.2)), Vector3(0, py + 0.05, 0.343), Vector3(1, 1.3, 0.3), 8)
	M.cyl(parent, 0.0, 0.024, 0.05, M.mat(Color(1.0, 0.62, 0.2)), Vector3(0, py + 0.1, 0.343), Vector3.ZERO, 5)
	for k in [-1.0, 1.0]:
		M.cyl(parent, 0.0, 0.03, 0.04, cloth, Vector3(0.05 * k, py - 0.06, 0.335), Vector3(180, 0, 0), 4)

	# Leña apilada, un tocón con hacha y un cubo junto a la base
	for i in 5:
		var row := 0 if i < 3 else 1
		var z := -0.36 + (i % 3) * 0.06 + row * 0.03
		M.cyl(parent, 0.028, 0.028, 0.22, log_m if i % 2 == 0 else log_dark, Vector3(0.38, 0.07 + row * 0.05, z), Vector3(90, 0, 0), 7)
	M.cyl(parent, 0.06, 0.065, 0.08, log_m, Vector3(0.39, 0.06, 0.2), Vector3.ZERO, 8)
	M.box(parent, Vector3(0.012, 0.12, 0.012), log_dark, Vector3(0.4, 0.15, 0.2), Vector3(0, 0, -25))
	M.box(parent, Vector3(0.05, 0.035, 0.01), iron, Vector3(0.375, 0.2, 0.2), Vector3(0, 0, -25))
	M.cyl(parent, 0.045, 0.04, 0.07, M.tex_mat("wood", 3.0, Color(0.7, 0.5, 0.32)), Vector3(-0.38, 0.06, 0.3), Vector3.ZERO, 8)
	M.cyl(parent, 0.047, 0.047, 0.01, iron, Vector3(-0.38, 0.08, 0.3), Vector3.ZERO, 8)


# --- Etapa 1: planta baja de piedra y planta alta de entramado con dos braseros ---

func _build_keep(parent: Node3D) -> void:
	var py := _py
	var stones := [M.mat(Color(0.58, 0.56, 0.53)), M.mat(Color(0.5, 0.48, 0.46)), M.mat(Color(0.64, 0.62, 0.58))]
	var timber := M.mat(Color(0.3, 0.18, 0.1))
	var plaster := M.mat(Color(0.92, 0.86, 0.72))
	var planks := M.tex_mat("wood", 2.5, Color(0.72, 0.42, 0.3))
	var iron := M.metal(IRON)
	var gold := M.metal(GOLD)
	var red := M.mat(RED)
	var roof := M.tex_mat("roof", 2.5, Color(0.42, 0.4, 0.46))

	# Zócalo y planta baja de piedra con bloques salientes
	M.box(parent, Vector3(0.88, 0.06, 0.88), M.mat(Color(0.45, 0.43, 0.41)), Vector3(0, 0.03, 0))
	M.box(parent, Vector3(0.66, 0.46, 0.66), M.tex_mat("bricks", 2.2, Color(0.74, 0.71, 0.66)), Vector3(0, 0.29, 0))
	ArcherModel._stone_blocks(parent, 0.33, 0.14, 3, [[0, 1]], stones)
	# esquinas reforzadas con flejes de hierro
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			for y in [0.16, 0.42]:
				M.box(parent, Vector3(0.09, 0.04, 0.09), iron, Vector3(0.33 * sx, y, 0.33 * sz))
	# Puerta de roble en arco con bandas de hierro
	var door := Vector3(0, 0, 0.335)
	M.box(parent, Vector3(0.24, 0.26, 0.05), stones[2], door + Vector3(0, 0.19, 0))
	M.cyl(parent, 0.12, 0.12, 0.05, stones[2], door + Vector3(0, 0.32, 0), Vector3(90, 0, 0), 16)
	M.box(parent, Vector3(0.18, 0.22, 0.03), planks, door + Vector3(0, 0.17, 0.02))
	M.cyl(parent, 0.09, 0.09, 0.03, planks, door + Vector3(0, 0.28, 0.02), Vector3(90, 0, 0), 14)
	for y in [0.11, 0.25]:
		M.box(parent, Vector3(0.19, 0.022, 0.012), iron, door + Vector3(0, y, 0.04))
	M.sphere(parent, 0.012, gold, door + Vector3(0.05, 0.18, 0.045), Vector3.ONE, 6)
	# Aplique con antorcha en la pared derecha
	M.box(parent, Vector3(0.1, 0.025, 0.03), iron, Vector3(0.38, 0.33, 0.12))
	M.cyl(parent, 0.03, 0.018, 0.09, M.mat(Color(0.35, 0.2, 0.1)), Vector3(0.43, 0.37, 0.12), Vector3.ZERO, 6)
	M.cyl(parent, 0.035, 0.035, 0.02, iron, Vector3(0.43, 0.41, 0.12), Vector3.ZERO, 6)

	# Planta alta de entramado: yeso crema y vigas oscuras con tornapuntas
	var y0 := 0.52
	var hh := py - 0.06 - y0
	M.box(parent, Vector3(0.62, hh, 0.62), plaster, Vector3(0, y0 + hh / 2.0, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			M.box(parent, Vector3(0.07, hh + 0.04, 0.07), timber, Vector3(0.31 * sx, y0 + hh / 2.0, 0.31 * sz))
	for y in [y0 + 0.02, y0 + hh]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.68, 0.05, 0.05), timber, Vector3(0, y, 0.315 * s))
			M.box(parent, Vector3(0.05, 0.05, 0.68), timber, Vector3(0.315 * s, y, 0))
	var diag := rad_to_deg(atan2(hh, 0.24))
	for face in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var f := Node3D.new()
		f.position = face * 0.312 + Vector3(0, y0 + hh / 2.0, 0)
		f.rotation.y = atan2(face.x, face.z)
		parent.add_child(f)
		for s in [-1.0, 1.0]:
			M.box(f, Vector3(0.035, sqrt(hh * hh + 0.24 * 0.24) - 0.05, 0.025), timber, Vector3(0.155 * s, 0, 0), Vector3(0, 0, (90.0 - diag) * s))
		if face.z < 0.5:
			_flame_window(f, Vector3(0, 0, 0.02))
	# Estandarte rojo con llama dorada al frente
	M.box(parent, Vector3(0.22, 0.02, 0.02), gold, Vector3(0, y0 + hh - 0.02, 0.345))
	M.box(parent, Vector3(0.17, 0.3, 0.016), red, Vector3(0, y0 + hh - 0.17, 0.345))
	_gold_flame(parent, Vector3(0, y0 + hh - 0.15, 0.356), 0.75)
	for k in [-1.0, 1.0]:
		M.cyl(parent, 0.0, 0.04, 0.05, red, Vector3(0.04 * k, y0 + hh - 0.34, 0.345), Vector3(180, 0, 0), 4)

	# Faldón de pizarra bajo la plataforma (alero)
	M.cyl(parent, 0.36, 0.52, 0.1, roof, Vector3(0, py - 0.11, 0), Vector3(0, 45, 0), 4)
	# Plataforma de tablones con barandilla
	M.box(parent, Vector3(0.72, 0.06, 0.72), planks, Vector3(0, py - 0.03, 0))
	for y in [py + 0.07, py + 0.14]:
		for s in [-1.0, 1.0]:
			M.box(parent, Vector3(0.62, 0.025, 0.025), timber, Vector3(0, y, 0.31 * s))
			M.box(parent, Vector3(0.025, 0.025, 0.62), timber, Vector3(0.31 * s, y, 0))
	for p in [Vector3(0, 0, -0.31), Vector3(0.31, 0, 0), Vector3(-0.31, 0, 0)]:
		M.box(parent, Vector3(0.04, 0.17, 0.04), timber, p + Vector3(0, py + 0.08, 0))
	# braseros de hierro en las esquinas delanteras y postes con pomo dorado detrás
	for sx in [-1.0, 1.0]:
		var bp := Vector3(0.31 * sx, py, 0.31)
		M.box(parent, Vector3(0.055, 0.17, 0.055), timber, bp + Vector3(0, 0.085, 0))
		M.cyl(parent, 0.08, 0.045, 0.07, iron, bp + Vector3(0, 0.2, 0), Vector3.ZERO, 12)
		M.cyl(parent, 0.068, 0.068, 0.01, M.mat(Color(0.25, 0.08, 0.03)), bp + Vector3(0, 0.235, 0), Vector3.ZERO, 12)
		M.box(parent, Vector3(0.055, 0.2, 0.055), timber, Vector3(0.31 * sx, py + 0.1, -0.31))
		M.sphere(parent, 0.028, gold, Vector3(0.31 * sx, py + 0.22, -0.31), Vector3.ONE, 8)

	# Leña y barril junto a la base
	var log_m := M.mat(Color(0.44, 0.29, 0.16))
	for i in 3:
		M.cyl(parent, 0.028, 0.028, 0.2, log_m, Vector3(-0.4, 0.09, -0.3 + i * 0.06), Vector3(0, 0, 90), 7)
	M.cyl(parent, 0.06, 0.06, 0.13, M.tex_mat("wood", 3.0, Color(0.7, 0.5, 0.32)), Vector3(0.38, 0.1, -0.33), Vector3.ZERO, 10)
	for y in [0.06, 0.14]:
		M.cyl(parent, 0.062, 0.062, 0.012, iron, Vector3(0.38, y, -0.33), Vector3.ZERO, 10)


# --- Etapa 3 (Maestría): zócalo de sillería blanca y oro sobre el que se eleva la torre ---

func _build_plinth(parent: Node3D) -> void:
	var marble := M.mat(Color(0.95, 0.92, 0.86))
	var gold := M.metal(GOLD)
	var ember := M.mat(EMBER, 1.8)
	var lift := T3_LIFT + 0.08
	M.box(parent, Vector3(0.94, 0.06, 0.94), marble, Vector3(0, 0.03, 0))
	M.box(parent, Vector3(0.78, lift, 0.78), M.mat(Color(0.88, 0.85, 0.8)), Vector3(0, lift / 2.0, 0))
	ArcherModel._stone_blocks(parent, 0.39, 0.12, 2, [[0, 1]], [marble, M.mat(Color(1.0, 0.98, 0.93)), M.mat(Color(0.92, 0.89, 0.83))])
	# cantoneras alternas y bandas de oro
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
	# gran portal apuntado incandescente con marco de oro
	var door := Vector3(0, 0, 0.4)
	M.box(parent, Vector3(0.24, 0.26, 0.03), gold, door + Vector3(0, 0.16, 0))
	M.cyl(parent, 0.12, 0.12, 0.03, gold, door + Vector3(0, 0.29, 0), Vector3(90, 0, 0), 18)
	M.box(parent, Vector3(0.19, 0.24, 0.03), ember, door + Vector3(0, 0.15, 0.008))
	M.cyl(parent, 0.095, 0.095, 0.03, ember, door + Vector3(0, 0.27, 0.008), Vector3(90, 0, 0), 16)
	M.box(parent, Vector3(0.012, 0.3, 0.02), gold, door + Vector3(0, 0.17, 0.02))
	_gold_flame(parent, door + Vector3(0, 0.15, 0.025), 0.9)
	# ventanas de llama en los laterales del zócalo
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(0.402 * s, 0.24, 0.0)
		w.rotation.y = PI / 2.0 * s
		parent.add_child(w)
		_flame_window(w, Vector3.ZERO)
	for s in [-1.0, 1.0]:
		_gold_flame(parent, Vector3(0.2 * s, 0.3, 0.41), 0.8)


# Remates fijos de la Maestría: mástiles blancos con remate de llama dorada
func _build_majestic(parent: Node3D) -> void:
	var gold := M.metal(GOLD)
	var marble := M.mat(Color(0.97, 0.94, 0.88))
	var py := _py
	for s in [-1.0, 1.0]:
		var mp := Vector3(0.36 * s, 0, -0.36)
		M.cyl(parent, 0.022, 0.026, 0.7, marble, mp + Vector3(0, py + 0.3, 0), Vector3.ZERO, 8)
		M.cyl(parent, 0.032, 0.032, 0.03, gold, mp + Vector3(0, py + 0.06, 0), Vector3.ZERO, 8)
		M.sphere(parent, 0.035, gold, mp + Vector3(0, py + 0.66, 0), Vector3.ONE, 10)
		_gold_flame(parent, mp + Vector3(0, py + 0.69, 0), 1.0)


# Partes animadas de la Maestría: aura de bolas de fuego en órbita y gallardetes al viento
func _build_majestic_parts() -> void:
	_aura = Node3D.new()
	_aura.position = Vector3(0, _py + 0.42, 0)
	add_child(_aura)
	for i in 6:
		var a := TAU * i / 6.0
		var fb := Node3D.new()
		fb.position = Vector3(cos(a), 0.0, sin(a)) * 0.5
		_aura.add_child(fb)
		M.sphere(fb, 0.035, M.mat(FIRE_CORE, 2.0), Vector3.ZERO, Vector3.ONE, 8)
		M.sphere(fb, 0.05, M.mat(FIRE, 1.2), Vector3.ZERO, Vector3(1.0, 0.8, 1.0), 8)
		M.cyl(fb, 0.0, 0.04, 0.09, M.mat(FIRE, 1.0), Vector3(0, 0.06, 0), Vector3.ZERO, 6)
	for s in [-1.0, 1.0]:
		var pn := Node3D.new()
		pn.position = Vector3(0.36 * s, _py + 0.58, -0.36)
		add_child(pn)
		_pennants.append(pn)
		var red := M.mat(Color(0.86, 0.1, 0.08))
		M.box(pn, Vector3(0.28, 0.1, 0.012), red, Vector3(-0.15 * s, 0, 0))
		M.box(pn, Vector3(0.28, 0.02, 0.014), M.metal(GOLD), Vector3(-0.15 * s, -0.045, 0))
		M.cyl(pn, 0.0, 0.05, 0.1, red, Vector3(-0.32 * s, 0, 0), Vector3(0, 0, 90.0 * s), 4)


func _build_cat_full(c: Node3D) -> void:
	_build_cat_body(c)
	_long_hair(c)
	_wizard_hat(c)
	_cat_extras(c)


# Sombrero rojo de mago: ala ancha, banda dorada, copa alta con la punta doblada y emblema de llama
func _wizard_hat(c: Node3D) -> void:
	var h := Vector3(0, 0.46, 0)
	var hat := M.mat([Color(0.55, 0.24, 0.14), Color(0.75, 0.12, 0.1), Color(0.75, 0.12, 0.1), Color(0.86, 0.1, 0.08)][_tier])
	var hat_dark := M.mat(RED_DARK if _tier > 0 else Color(0.4, 0.18, 0.1))
	var gold := M.metal(GOLD) if _tier > 0 else M.mat(Color(0.4, 0.26, 0.14))
	M.cyl(c, 0.21, 0.22, 0.03, hat, h + Vector3(0, 0.12, 0.01), Vector3(6, 0, 0), 24)
	M.cyl(c, 0.222, 0.222, 0.012, gold, h + Vector3(0, 0.105, 0.01), Vector3(6, 0, 0), 24)
	M.cyl(c, 0.12, 0.13, 0.05, gold, h + Vector3(0, 0.16, 0.01), Vector3.ZERO, 18)
	M.cyl(c, 0.075, 0.12, 0.2, hat, h + Vector3(0, 0.28, 0.02), Vector3.ZERO, 18)
	var tip := Node3D.new()
	tip.position = h + Vector3(0, 0.37, 0.03)
	tip.rotation = Vector3(0.7, 0, 0.15)
	c.add_child(tip)
	M.cyl(tip, 0.035, 0.075, 0.12, hat, Vector3(0, 0.05, 0), Vector3.ZERO, 14)
	var tip2 := Node3D.new()
	tip2.position = Vector3(0, 0.1, 0)
	tip2.rotation = Vector3(0.6, 0, 0)
	tip.add_child(tip2)
	M.cyl(tip2, 0.0, 0.035, 0.1, hat_dark, Vector3(0, 0.045, 0), Vector3.ZERO, 12)
	M.sphere(tip2, 0.025, gold, Vector3(0, 0.1, 0), Vector3.ONE, 8)
	if _tier == 0:
		return
	if _tier == 3:
		# corona de oro con puntas y rubíes sobre la banda
		for i in 8:
			var a := TAU * i / 8.0
			var cp := h + Vector3(cos(a) * 0.125, 0.205, sin(a) * 0.125 + 0.01)
			M.cyl(c, 0.0, 0.022, 0.06, gold, cp, Vector3.ZERO, 4)
			if i % 2 == 0:
				M.sphere(c, 0.012, M.mat(Color(1.0, 0.25, 0.08), 1.5), cp + Vector3(0, -0.02, 0), Vector3.ONE, 6)
	# emblema de llama en la banda y estrellitas doradas
	M.cyl(c, 0.0, 0.03, 0.08, M.metal(GOLD), h + Vector3(0, 0.19, -0.125), Vector3(-10, 0, 0), 6)
	M.cyl(c, 0.03, 0.03, 0.012, gold, h + Vector3(0, 0.165, -0.125), Vector3(80, 0, 0), 12)
	for p in [Vector3(0.06, 0.26, -0.085), Vector3(-0.07, 0.3, -0.06), Vector3(0.03, 0.33, -0.065)]:
		M.sphere(c, 0.012, M.mat(GOLD, 1.0), h + p, Vector3.ONE, 6)
	# broche dorado con rubí en la banda del sombrero
	M.sphere(c, 0.024, M.metal(GOLD), h + Vector3(0.105, 0.175, -0.07), Vector3(1, 1, 0.5), 8)
	M.sphere(c, 0.014, M.mat(Color(0.9, 0.1, 0.1), 1.2), h + Vector3(0.105, 0.175, -0.082), Vector3.ONE, 6)
	# lazo rojo con cintas en la parte de atrás
	for s in [-1.0, 1.0]:
		M.sphere(c, 0.03, M.mat(Color(0.9, 0.12, 0.12)), h + Vector3(0.035 * s, 0.17, 0.13), Vector3(1.3, 0.8, 0.5), 8)
		M.box(c, Vector3(0.03, 0.12, 0.01), M.mat(Color(0.9, 0.12, 0.12)), h + Vector3(0.025 * s, 0.1, 0.145), Vector3(15, 0, 12.0 * s))
	M.sphere(c, 0.016, M.metal(GOLD), h + Vector3(0, 0.17, 0.135), Vector3.ONE, 6)


# Cuello dorado, lazo rojo y puños dorados en las mangas
func _cat_extras(c: Node3D) -> void:
	var gold := _trim_mat()
	var collar := TorusMesh.new()
	collar.inner_radius = 0.085
	collar.outer_radius = 0.12
	M.add(c, collar, gold, Vector3(0, 0.335, 0), Vector3(8, 0, 0))
	for s in [-1.0, 1.0]:
		M.sphere(c, 0.03, M.mat(Color(0.9, 0.12, 0.12)), Vector3(0.035 * s, 0.2, -0.14), Vector3(1.3, 0.8, 0.5), 8)
		M.segment(c, 0.008, M.mat(Color(0.9, 0.12, 0.12)), Vector3(0.02 * s, 0.13, -0.142), Vector3(0.005 * s, 0.195, -0.142), 4)
	M.sphere(c, 0.016, gold, Vector3(0, 0.2, -0.145), Vector3.ONE, 6)
	if _tier == 0:
		return
	# colgante dorado con gema de fuego
	M.segment(c, 0.005, gold, Vector3(0, 0.255, -0.15), Vector3(0, 0.31, -0.11), 4)
	M.sphere(c, 0.022, gold, Vector3(0, 0.245, -0.155), Vector3(1, 1.2, 0.6), 8)
	M.sphere(c, 0.012, M.mat(Color(1.0, 0.35, 0.1), 1.5), Vector3(0, 0.245, -0.168), Vector3.ONE, 6)
	M.cyl(c, 0.05, 0.05, 0.03, gold, Vector3(-0.14, 0.33, -0.21), Vector3(70, 0, 0), 10)
	M.cyl(c, 0.05, 0.05, 0.03, gold, STAFF_HAND + Vector3(-0.03, 0.01, 0.04), Vector3(70, 0, 0), 10)

# Melena larga rojo fuego: volumen detrás de la cabeza, flequillo, mechones a los lados de la
# cara y una larga cola de pelo cayendo por la espalda con las puntas anaranjadas
func _long_hair(c: Node3D) -> void:
	var h := Vector3(0, 0.46, 0)
	var hair := M.mat(HAIR)
	var tip := M.mat(HAIR_TIP)
	M.sphere(c, 0.152, hair, h + Vector3(0, 0.0, 0.05), Vector3(1.12, 1.0, 0.92), 16)
	# flequillo sobre la frente (por encima de los ojos)
	for k in 5:
		var x := -0.08 + k * 0.04
		M.sphere(c, 0.036, hair, h + Vector3(x, 0.098 - absf(x) * 0.3, -0.122 + absf(x) * 0.25), Vector3(1.0, 0.7, 0.6), 8)
	# mechones laterales que enmarcan la cara y caen sobre los hombros
	for s in [-1.0, 1.0]:
		var pts := [Vector3(0.135, 0.02, -0.04), Vector3(0.15, -0.09, -0.03), Vector3(0.15, -0.19, -0.01), Vector3(0.14, -0.27, 0.0)]
		for i in pts.size():
			var p: Vector3 = pts[i]
			var r := lerpf(0.05, 0.03, float(i) / (pts.size() - 1))
			M.sphere(c, r, tip if i == pts.size() - 1 else hair, h + Vector3(p.x * s, p.y, p.z), Vector3(0.9, 1.3, 0.9), 10)
	# melena larga por la espalda (tres mechones que se ensanchan y se rizan al final)
	for x in [-0.07, 0.0, 0.07]:
		var pts := [Vector3(x, -0.04, 0.13), Vector3(x * 1.2, -0.15, 0.17), Vector3(x * 1.35, -0.26, 0.19),
				Vector3(x * 1.4, -0.36, 0.19), Vector3(x * 1.3 + 0.015, -0.43, 0.16)]
		for i in pts.size():
			var p: Vector3 = pts[i]
			var r := lerpf(0.075, 0.035, float(i) / (pts.size() - 1))
			M.sphere(c, r, tip if i == pts.size() - 1 else hair, h + p, Vector3(1.0, 1.35, 0.85), 10)