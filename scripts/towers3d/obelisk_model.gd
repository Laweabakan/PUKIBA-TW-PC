extends Node3D
## Modelo 3D del "Obelisco del Vacío". Cambia de aspecto con la etapa visual (TowerModels.tier):
##   0 (nv 0-1): menhir tosco sobre un túmulo de piedra seca, con pocas runas, menhires pequeños,
##               velas y un orbe sujeto con ramas atadas; ermitaño con hábito gris y bastón nudoso.
##   1 (nv 2-3): obelisco de piedra oscura sobre base de sillares con arcos góticos, bandas de
##               hierro y garras; dos piedras rúnicas orbitando; brujo con túnica violeta.
##   2 (nv 4):   obelisco más alto con balcón almenado, contrafuertes, braseros del vacío,
##               estandartes y cuatro piedras orbitando; brujo con hombreras de acero y capa.
##   3 (nv 5):   gran obelisco de obsidiana con molduras doradas, pináculos con remates dorados,
##               cristales del vacío flotando, runas intensas y bruma violeta; archibrujo con
##               túnica negra y oro, hombreras doradas, corona y capa de borde brillante.
## El brujo mira hacia -Z dentro de cat_pivot (desplazado delante del obelisco) y rodea el
## obelisco al apuntar.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const ArcherModel := preload("res://scripts/towers3d/archer_model.gd")   # hierba de la base

const STONE := Color(0.36, 0.34, 0.42)
const STONE_DARK := Color(0.22, 0.2, 0.27)
const STONE_LIGHT := Color(0.48, 0.46, 0.54)
const OBSIDIAN := Color(0.12, 0.1, 0.16)
const RUBBLE := Color(0.5, 0.49, 0.47)
const IRON := Color(0.22, 0.21, 0.25)
const GOLD := Color(0.95, 0.75, 0.3)
const VOID_GLOW := Color(0.6, 0.2, 0.95)
const VOID_DARK := Color(0.08, 0.02, 0.12)
const ROBE := Color(0.24, 0.12, 0.36)
const ROBE_DARK := Color(0.14, 0.07, 0.22)
const HERMIT := Color(0.46, 0.44, 0.42)
const HERMIT_DARK := Color(0.34, 0.32, 0.3)

# Por etapa: altura del balcón, altura del fuste y radios del fuste
const PLATFORM_HEIGHTS := [0.36, 0.6, 0.7, 0.82]
const SHAFT_HEIGHTS := [0.78, 0.9, 1.05, 1.22]
const SHAFT_BOTTOMS := [0.14, 0.14, 0.15, 0.17]
const SHAFT_TOPS := [0.075, 0.08, 0.085, 0.09]
const ORBIT_COUNTS := [1, 2, 4, 4]
const OP_Z := -0.27            # el brujo se coloca delante del obelisco
const STAFF_HAND := Vector3(0.2, 0.25, -0.1)
const FACES := [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]

var cat_pivot: Node3D
var _tier := 0
var _py := 0.36
var _shaft_h := 0.78
var _shaft_bottom := 0.14
var _shaft_top := 0.075
var _orb_y := 1.4
var _orbit_y := 1.0
var _rune_mat: StandardMaterial3D
var _pulse_mat: StandardMaterial3D
var _orb: Node3D
var _orb_ring: Node3D
var _pulse: MeshInstance3D
var _orbit: Node3D
var _stones: Array[Node3D] = []
var _staff: Node3D
var _hand_flame: Node3D
var _shards: Node3D


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
	_shaft_h = SHAFT_HEIGHTS[_tier]
	_shaft_bottom = SHAFT_BOTTOMS[_tier]
	_shaft_top = SHAFT_TOPS[_tier]
	_orb_y = _py + _shaft_h + (0.2 if _tier == 0 else 0.28)
	_orbit_y = _py + _shaft_h * 0.74
	M.add_baked(self, M.baked("obelisk_tower_t%d" % _tier, _build_tower))
	# Runas y arcos: malla aparte con un material propio para poder avivar su brillo
	_rune_mat = (M.mat(VOID_GLOW, 1.0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	var runes := M.add_baked(self, M.baked("obelisk_runes_t%d" % _tier, _build_runes))
	runes.material_override = _rune_mat
	_build_orb()
	_build_orbit()
	if _tier == 3:
		_build_master_fx()
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, _py, 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("obelisk_mage_t%d" % _tier, _build_mage_body))
	_build_mage_parts()
	animate({"t": 0.0, "charge": 0.3, "fire": 0.0})


## s = {t, charge 0..1, fire 1 -> 0, has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = clampf(s.get("charge", 0.0), 0.0, 1.0)
	var fire: float = clampf(s.get("fire", 0.0), 0.0, 1.0)
	var boost := 0.3 if _tier == 3 else 0.0
	# Orbe: crece al cargar y late al disparar
	_orb.position.y = _orb_y + sin(t * 1.7) * 0.02
	_orb.scale = Vector3.ONE * (0.75 + charge * 0.55 + fire * 0.35 + boost * 0.4)
	_orb_ring.rotation.y = t * (1.5 + charge * 4.0)
	# Runas más brillantes con la carga
	_rune_mat.emission_energy_multiplier = 0.45 + boost + charge * 1.3 + fire * 1.0 + sin(t * 3.0) * 0.15
	# Piedras rúnicas orbitando
	_orbit.rotation.y = t * (0.6 + charge * 1.6)
	for i in _stones.size():
		var st := _stones[i]
		st.position.y = sin(t * 2.0 + i * 1.6) * 0.04
	if _shards:
		_shards.rotation.y = -t * 0.4
	# Onda expansiva del pulso
	_pulse.visible = fire > 0.0
	_pulse.scale = Vector3.ONE * (1.0 + (1.0 - fire) * 3.0)
	_pulse_mat.albedo_color.a = fire * 0.55
	# Bastón: se inclina al cargar y empuja al lanzar
	_staff.rotation.x = -0.08 - charge * 0.12 - fire * 0.45
	_hand_flame.scale = Vector3.ONE * (0.7 + charge * 0.5 + sin(t * 9.0) * 0.08)


func muzzle_global() -> Vector3:
	return _orb.global_position


# --- Adornos ---

# Arco gótico apuntado (rectángulo + rombo) mirando hacia +Z local del nodo creado
static func gothic_arch(parent: Node3D, pos: Vector3, facing: Vector3, w: float, h: float, m: Material) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = atan2(facing.x, facing.z)
	parent.add_child(n)
	var rect_h := h - w * 0.5
	M.box(n, Vector3(w, rect_h, 0.02), m, Vector3(0, rect_h * 0.5, 0))
	var d := w / sqrt(2.0)
	M.box(n, Vector3(d, d, 0.02), m, Vector3(0, rect_h, 0), Vector3(0, 0, 45))
	return n


# Glifo rúnico pequeño en el plano XY (mirando a +Z)
static func glyph(parent: Node3D, pos: Vector3, k: int, s: float, m: Material) -> void:
	match k % 4:
		0:
			M.box(parent, Vector3(0.009, 0.05, 0.01) * s, m, pos)
			M.box(parent, Vector3(0.008, 0.026, 0.01) * s, m, pos + Vector3(0.009, 0.012, 0) * s, Vector3(0, 0, -45))
			M.box(parent, Vector3(0.008, 0.026, 0.01) * s, m, pos + Vector3(-0.009, 0.012, 0) * s, Vector3(0, 0, 45))
		1:
			M.box(parent, Vector3(0.024, 0.024, 0.01) * s, m, pos, Vector3(0, 0, 45))
			M.box(parent, Vector3(0.008, 0.06, 0.008) * s, m, pos)
		2:
			M.box(parent, Vector3(0.009, 0.05, 0.01) * s, m, pos)
			M.box(parent, Vector3(0.034, 0.008, 0.01) * s, m, pos + Vector3(0, 0.01, 0) * s)
			M.box(parent, Vector3(0.022, 0.008, 0.01) * s, m, pos + Vector3(0, -0.012, 0) * s)
		_:
			M.cyl(parent, 0.016 * s, 0.016 * s, 0.01, m, pos, Vector3(90, 0, 0), 8)
			M.box(parent, Vector3(0.008, 0.05, 0.01) * s, m, pos + Vector3(0, 0, 0.002))


# --- Torre ---

func _build_tower(parent: Node3D) -> void:
	if _tier == 0:
		_build_cairn(parent)
	else:
		_build_base(parent)
	_build_shaft(parent)
	ArcherModel._ground_details(parent, false)


# Etapa 0: túmulo de piedra seca con escalones, menhires pequeños y velas
func _build_cairn(parent: Node3D) -> void:
	var rub := [M.mat(RUBBLE), M.mat(RUBBLE.darkened(0.15)), M.mat(RUBBLE.lightened(0.1))]
	var stone := M.mat(STONE)
	var py := _py
	M.cyl(parent, 0.44, 0.46, 0.04, M.mat(Color(0.42, 0.4, 0.36)), Vector3(0, 0.02, 0), Vector3.ZERO, 12)
	M.cyl(parent, 0.34, 0.4, py - 0.06, rub[1], Vector3(0, 0.04 + (py - 0.06) * 0.5, 0), Vector3.ZERO, 10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for row in 2:
		for i in 11:
			var a := TAU * (i + row * 0.5) / 11.0
			var r := 0.38 - row * 0.03
			var b := M.box(parent, Vector3(0.14, 0.09, 0.08), rub[(i + row) % 3], Vector3(cos(a) * r, 0.1 + row * 0.12, sin(a) * r),
					Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)))
			b.rotation.y = PI / 2.0 - a
	M.cyl(parent, 0.37, 0.37, 0.05, rub[2], Vector3(0, py - 0.025, 0), Vector3.ZERO, 10)
	# escalones toscos delante
	M.box(parent, Vector3(0.24, 0.05, 0.1), rub[0], Vector3(0, 0.12, 0.38), Vector3(0, 4, 0))
	# Menhires pequeños alrededor (detrás y a los lados)
	for p: Vector3 in [Vector3(-0.4, 0, -0.32), Vector3(0.42, 0, -0.26), Vector3(-0.44, 0, 0.12)]:
		var h := 0.26 + absf(p.x) * 0.2
		var mh := M.cyl(parent, 0.035, 0.06, h, stone, p + Vector3(0, h * 0.5, 0), Vector3(0, 30, 0), 4)
		mh.rotation_degrees.z = 6.0 * signf(p.x)
		M.sphere(parent, 0.035, M.mat(Color(0.3, 0.5, 0.25)), p + Vector3(0.02, 0.03, 0.03), Vector3(1.3, 0.5, 1.0), 6)
	# Velas derretidas en el borde del túmulo
	var wax := M.mat(Color(0.92, 0.88, 0.76))
	var flame := M.mat(Color(0.8, 0.5, 1.0), 2.0)
	for a: float in [0.5, 1.3, 2.4, -0.4]:
		var cp := Vector3(cos(a) * 0.3, py, sin(a) * 0.3)
		M.cyl(parent, 0.016, 0.02, 0.06, wax, cp + Vector3(0, 0.03, 0), Vector3.ZERO, 6)
		M.cyl(parent, 0.0, 0.012, 0.03, flame, cp + Vector3(0, 0.075, 0), Vector3.ZERO, 5)
	# Cristal del vacío brotando entre las piedras
	Human.crystal_cluster(parent, Vector3(0.4, 0.0, 0.3), 0.45, M.mat(VOID_GLOW.darkened(0.25), 1.0), 3)


# Etapas 1-3: base escalonada de sillares con arcos góticos y balcón
func _build_base(parent: Node3D) -> void:
	var t := _tier
	var master := t == 3
	var bricks := M.tex_mat("bricks", 2.2, Color(0.4, 0.38, 0.48) if master else Color(0.58, 0.55, 0.66))
	var stone := M.mat(STONE if not master else Color(0.2, 0.18, 0.26))
	var dark := M.mat(STONE_DARK if not master else OBSIDIAN)
	var light := M.mat(STONE_LIGHT if not master else Color(0.3, 0.28, 0.36))
	var trim: Material = stone
	if master:
		trim = M.metal(GOLD)
	var iron := M.metal(IRON)
	var gold := M.metal(GOLD)
	var flame := M.mat(VOID_GLOW, 1.0)
	var py := _py
	var body_h := py - 0.24

	# Base escalonada de sillares
	M.box(parent, Vector3(0.92, 0.08, 0.92), dark, Vector3(0, 0.04, 0))
	M.box(parent, Vector3(0.8, 0.1, 0.8), stone, Vector3(0, 0.13, 0))
	if master:
		M.box(parent, Vector3(0.82, 0.02, 0.82), gold, Vector3(0, 0.18, 0))
	M.box(parent, Vector3(0.68, body_h + 0.02, 0.68), bricks, Vector3(0, 0.18 + body_h * 0.5, 0))
	# Contrafuertes en las esquinas con remate apuntado
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var cp := Vector3(0.34 * sx, 0, 0.34 * sz)
			M.box(parent, Vector3(0.12, body_h, 0.12), light, cp + Vector3(0, 0.18 + body_h * 0.5, 0))
			M.box(parent, Vector3(0.14, 0.05, 0.14), trim, cp + Vector3(0, 0.2, 0))
	# Marcos de los arcos góticos (el relleno brillante va en la malla de runas)
	var arch_h := minf(0.36, body_h + 0.04)
	for face: Vector3 in FACES:
		var a := gothic_arch(parent, face * 0.342 + Vector3(0, 0.2, 0), face, 0.22, arch_h, light)
		M.box(a, Vector3(0.26, 0.04, 0.03), trim, Vector3(0, 0.0, 0.005))
		M.box(a, Vector3(0.035, 0.05, 0.03), trim, Vector3(0, arch_h, 0.005))
	# Escalones delante de la puerta
	M.box(parent, Vector3(0.3, 0.05, 0.1), stone, Vector3(0, 0.025, 0.46))
	# Estandartes del vacío colgando de los contrafuertes laterales (etapas 2 y 3)
	if t >= 2:
		for s: float in [-1.0, 1.0]:
			var f := Node3D.new()
			f.position = Vector3(0.405 * s, py - 0.14, 0.0)
			f.rotation.y = PI / 2.0 * s
			parent.add_child(f)
			M.box(f, Vector3(0.2, 0.022, 0.022), gold if master else iron, Vector3(0, 0.03, 0.0))
			M.box(f, Vector3(0.15, 0.3, 0.014), M.mat(ROBE if not master else Color(0.1, 0.05, 0.16)), Vector3(0, -0.12, 0))
			if master:
				M.box(f, Vector3(0.012, 0.3, 0.016), gold, Vector3(0.07, -0.12, 0))
				M.box(f, Vector3(0.012, 0.3, 0.016), gold, Vector3(-0.07, -0.12, 0))
			for k: float in [-1.0, 1.0]:
				M.cyl(f, 0.0, 0.04, 0.05, M.mat(ROBE if not master else Color(0.1, 0.05, 0.16)), Vector3(0.037 * k, -0.295, 0), Vector3(180, 0, 0), 4)
			M.sphere(f, 0.026, gold, Vector3(0, -0.08, 0.012), Vector3(1, 1, 0.4), 8)

	# Balcón con ménsulas y almenas bajas
	M.box(parent, Vector3(0.86, 0.06, 0.86), dark, Vector3(0, py - 0.03, 0))
	M.box(parent, Vector3(0.8, 0.02, 0.8), trim, Vector3(0, py - 0.065, 0))
	for k in 5:
		var o: float = -0.3 + k * 0.15
		for face: Vector3 in FACES:
			var tg := Vector3(face.z, 0, face.x)
			M.box(parent, Vector3(0.05, 0.06, 0.05), stone, face * 0.36 + tg * o + Vector3(0, py - 0.1, 0))
	if t >= 2:
		for k in 4:
			var o2: float = -0.33 + k * 0.22
			for face: Vector3 in FACES:
				var tg2 := Vector3(face.z, 0, face.x)
				var sz := Vector3(0.09, 0.07, 0.05) if absf(face.z) > 0.5 else Vector3(0.05, 0.07, 0.09)
				var mp := face * 0.405 + tg2 * o2 + Vector3(0, py + 0.035, 0)
				M.box(parent, sz, light, mp)
				if master:
					M.box(parent, sz * Vector3(1.1, 0.25, 1.1), gold, mp + Vector3(0, 0.04, 0))
	else:
		# parapeto bajo y liso
		for face: Vector3 in FACES:
			var sz2 := Vector3(0.84, 0.05, 0.04) if absf(face.z) > 0.5 else Vector3(0.04, 0.05, 0.84)
			M.box(parent, sz2, light, face * 0.41 + Vector3(0, py + 0.025, 0))

	# Braseros de hierro con llama del vacío en las esquinas del balcón (etapas 2 y 3)
	if t >= 2:
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var bp := Vector3(0.37 * sx, py, 0.37 * sz)
				if master:
					# pináculo de obsidiana con remate dorado y llama
					M.box(parent, Vector3(0.09, 0.2, 0.09), dark, bp + Vector3(0, 0.1, 0))
					M.box(parent, Vector3(0.11, 0.025, 0.11), gold, bp + Vector3(0, 0.2, 0))
					M.cyl(parent, 0.0, 0.05, 0.22, dark, bp + Vector3(0, 0.32, 0), Vector3(0, 45, 0), 4)
					M.sphere(parent, 0.022, gold, bp + Vector3(0, 0.44, 0), Vector3.ONE, 8)
					M.cyl(parent, 0.0, 0.012, 0.07, gold, bp + Vector3(0, 0.48, 0), Vector3.ZERO, 5)
				else:
					M.cyl(parent, 0.012, 0.02, 0.1, iron, bp + Vector3(0, 0.05, 0), Vector3.ZERO, 6)
					M.cyl(parent, 0.05, 0.03, 0.04, iron, bp + Vector3(0, 0.12, 0), Vector3.ZERO, 8)
					M.cyl(parent, 0.0, 0.035, 0.09, flame, bp + Vector3(0, 0.18, 0), Vector3.ZERO, 6)

	# Cristales del vacío y piedras caídas alrededor de la base
	var shard := M.mat(VOID_GLOW.darkened(0.25), 1.2)
	Human.crystal_cluster(parent, Vector3(-0.42, 0.0, 0.3), 0.6 + t * 0.08, shard, 3)
	Human.crystal_cluster(parent, Vector3(0.43, 0.0, -0.4), 0.5 + t * 0.08, shard, 9)
	for p: Vector3 in [Vector3(0.44, 0.03, 0.3), Vector3(-0.46, 0.03, -0.3)]:
		M.box(parent, Vector3(0.1, 0.06, 0.08), stone, p, Vector3(0, 25, 8))


# Fuste del obelisco (cuadrado y afilado) con zócalo, bandas y remate
func _build_shaft(parent: Node3D) -> void:
	var t := _tier
	var master := t == 3
	var py := _py
	var iron := M.metal(IRON)
	var gold := M.metal(GOLD)
	var dark := M.mat(STONE_DARK if not master else OBSIDIAN)
	var light := M.mat(STONE_LIGHT)
	var band: Material = gold if master else iron
	var shaft_m: Material
	match t:
		0: shaft_m = M.mat(Color(0.4, 0.39, 0.42))
		3: shaft_m = M.mat(OBSIDIAN.lightened(0.05))
		_: shaft_m = M.mat(STONE_DARK.lightened(0.06))
	M.cyl(parent, 0.2, 0.2, 0.06, light if t > 0 else M.mat(RUBBLE), Vector3(0, py + 0.03, 0), Vector3(0, 45, 0), 4)
	if master:
		M.cyl(parent, 0.21, 0.21, 0.02, gold, Vector3(0, py + 0.065, 0), Vector3(0, 45, 0), 4)
	M.cyl(parent, _shaft_top, _shaft_bottom, _shaft_h, shaft_m, Vector3(0, py + _shaft_h * 0.5, 0), Vector3(0, 45, 0), 4)
	if t == 0:
		# musgo y una grieta en el menhir
		M.sphere(parent, 0.06, M.mat(Color(0.3, 0.5, 0.25)), Vector3(0.06, py + 0.1, 0.08), Vector3(1.2, 0.6, 0.6), 6)
	else:
		var bands: Array = [0.35, 0.7] if t < 3 else [0.2, 0.45, 0.7, 0.88]
		for f: float in bands:
			var r: float = lerpf(_shaft_bottom, _shaft_top, f) + 0.012
			M.cyl(parent, r, r, 0.03, band, Vector3(0, py + _shaft_h * f, 0), Vector3(0, 45, 0), 4)
	var top_y := py + _shaft_h
	if t == 0:
		# remate tosco y ramas atadas que sujetan el orbe
		M.cyl(parent, 0.0, 0.08, 0.08, M.mat(Color(0.4, 0.39, 0.42)), Vector3(0, top_y + 0.04, 0), Vector3(0, 45, 0), 4)
		var twig := M.mat(Color(0.36, 0.25, 0.15))
		for i in 3:
			var a := TAU * i / 3.0 + 0.4
			var d := Vector3(cos(a), 0, sin(a))
			M.segment(parent, 0.01, twig, d * 0.04 + Vector3(0, top_y - 0.04, 0), d * 0.09 + Vector3(0, top_y + 0.2, 0), 4)
		M.cyl(parent, 0.065, 0.065, 0.025, M.mat(Color(0.8, 0.68, 0.48)), Vector3(0, top_y - 0.02, 0), Vector3(0, 45, 0), 4)
		return
	# Remate: banda dorada, piramidión y garras que sujetan el orbe
	M.cyl(parent, _shaft_top + 0.02, _shaft_top + 0.02, 0.04, gold, Vector3(0, top_y, 0), Vector3(0, 45, 0), 4)
	M.cyl(parent, 0.0, _shaft_top + 0.01, 0.15, gold if master else dark, Vector3(0, top_y + 0.095, 0), Vector3(0, 45, 0), 4)
	var claw: Material = gold if master else iron
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var a0 := Vector3(0.07 * sx, top_y + 0.02, 0.07 * sz)
			var a1 := Vector3(0.12 * sx, top_y + 0.16, 0.12 * sz)
			var a2 := Vector3(0.08 * sx, top_y + 0.28, 0.08 * sz)
			M.segment(parent, 0.012, claw, a0, a1, 6)
			M.segment(parent, 0.01, claw, a1, a2, 6)
			M.cyl(parent, 0.0, 0.014, 0.04, gold, a2 + Vector3(0, 0.02, 0), Vector3.ZERO, 6)


# Partes brillantes (runas del fuste y relleno de los arcos): se avivan al cargar
func _build_runes(parent: Node3D) -> void:
	var glow := M.mat(VOID_GLOW, 1.0)
	var t := _tier
	var n_runes: int = [2, 4, 5, 7][t]
	for face: Vector3 in FACES:
		if t > 0:
			# vitral morado de los arcos
			var arch_h := minf(0.3, _py - 0.24)
			var a := gothic_arch(parent, face * 0.35 + Vector3(0, 0.22, 0), face, 0.16, arch_h, glow)
			a.position += face * 0.002
		# columna de runas en cada cara del fuste
		for k in n_runes:
			var f: float = 0.18 + k * (0.65 / maxf(1.0, n_runes - 1.0)) if n_runes > 1 else 0.4
			if t == 0:
				f = 0.3 + k * 0.3
			var y: float = _py + _shaft_h * f
			var apothem: float = lerpf(_shaft_bottom, _shaft_top, f) * 0.7071
			var n := Node3D.new()
			n.position = face * (apothem + 0.003) + Vector3(0, y, 0)
			n.rotation.y = atan2(face.x, face.z)
			parent.add_child(n)
			var sc: float = lerpf(1.2, 0.8, f)
			glyph(n, Vector3.ZERO, k + int(face.x * 2.0 + face.z * 3.0 + 3.0), sc, glow)
	if t == 3:
		# grietas brillantes en la base y círculo rúnico en el suelo delantero
		for face: Vector3 in FACES:
			var tg := Vector3(face.z, 0, face.x)
			for k: float in [-1.0, 1.0]:
				var g := Node3D.new()
				g.position = face * 0.405 + tg * 0.2 * k + Vector3(0, 0.13, 0)
				g.rotation.y = atan2(face.x, face.z)
				parent.add_child(g)
				glyph(g, Vector3.ZERO, int(k + 2.0), 1.0, glow)


# Orbe del vacío con anillo y onda del pulso
func _build_orb() -> void:
	_orb = Node3D.new()
	_orb.position = Vector3(0, _orb_y, 0)
	add_child(_orb)
	M.sphere(_orb, 0.07, M.mat(VOID_DARK), Vector3.ZERO, Vector3.ONE, 14)
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.albedo_color = Color(VOID_GLOW.r, VOID_GLOW.g, VOID_GLOW.b, 0.35 if _tier < 3 else 0.5)
	M.sphere(_orb, 0.1 if _tier < 3 else 0.12, halo, Vector3.ZERO, Vector3.ONE, 14)
	_orb_ring = Node3D.new()
	_orb_ring.rotation.x = 0.35
	_orb.add_child(_orb_ring)
	if _tier >= 1:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.1
		ring.outer_radius = 0.125
		ring.rings = 16
		ring.ring_segments = 6
		M.add(_orb_ring, ring, M.mat(VOID_GLOW, 2.2))
	if _tier == 3:
		var ring2 := TorusMesh.new()
		ring2.inner_radius = 0.15
		ring2.outer_radius = 0.165
		ring2.rings = 18
		ring2.ring_segments = 5
		M.add(_orb_ring, ring2, M.metal(GOLD), Vector3.ZERO, Vector3(0, 0, 70))
	for i in (3 if _tier >= 1 else 2):
		var a := TAU * i / 3.0
		M.sphere(_orb_ring, 0.016, M.mat(Color(0.95, 0.8, 1.0), 2.0), Vector3(cos(a), 0, sin(a)) * 0.15, Vector3.ONE, 6)
	# Onda expansiva al disparar
	_pulse_mat = StandardMaterial3D.new()
	_pulse_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pulse_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pulse_mat.albedo_color = Color(VOID_GLOW.r, VOID_GLOW.g, VOID_GLOW.b, 0.0)
	_pulse = M.add(self, M.sphere_mesh(0.1, 14), _pulse_mat, Vector3(0, _orb_y, 0))
	_pulse.visible = false


# Piedras rúnicas que flotan girando alrededor del obelisco
func _build_orbit() -> void:
	_orbit = Node3D.new()
	_orbit.position = Vector3(0, _orbit_y, 0)
	add_child(_orbit)
	var stone := M.mat(STONE_LIGHT if _tier < 3 else Color(0.2, 0.18, 0.26))
	var n: int = ORBIT_COUNTS[_tier]
	for i in n:
		var a := TAU * i / n + 0.4
		var holder := Node3D.new()
		holder.rotation.y = a
		_orbit.add_child(holder)
		var st := Node3D.new()
		holder.add_child(st)
		_stones.append(st)
		var face := Node3D.new()
		face.position = Vector3(0, 0, 0.3)
		face.rotation.z = 0.25 * (1.0 if i % 2 == 0 else -1.0)
		st.add_child(face)
		M.box(face, Vector3(0.07, 0.1, 0.045), stone)
		M.cyl(face, 0.0, 0.03, 0.04, stone, Vector3(0, 0.065, 0), Vector3.ZERO, 4)
		M.cyl(face, 0.0, 0.03, 0.04, stone, Vector3(0, -0.065, 0), Vector3(180, 0, 0), 4)
		if _tier == 3:
			M.box(face, Vector3(0.075, 0.012, 0.05), M.metal(GOLD), Vector3(0, 0.0, 0))
		glyph(face, Vector3(0, 0, 0.024), i, 1.0, _rune_mat)
		glyph(face, Vector3(0, 0, -0.024), i + 1, 1.0, _rune_mat)


# Maestría: cristales del vacío flotando a contragiro y bruma violeta que asciende
func _build_master_fx() -> void:
	_shards = Node3D.new()
	_shards.position = Vector3(0, _py + 0.35, 0)
	add_child(_shards)
	var m := M.mat(VOID_GLOW.lightened(0.1), 1.8)
	for i in 6:
		var a := TAU * i / 6.0
		var c := Node3D.new()
		c.position = Vector3(cos(a), (i % 2) * 0.12, sin(a)) * Vector3(0.48, 1.0, 0.48)
		c.rotation = Vector3(0.3 * (i % 3), a, 0.2)
		_shards.add_child(c)
		M.cyl(c, 0.0, 0.025, 0.07, m, Vector3(0, 0.035, 0), Vector3.ZERO, 4)
		M.cyl(c, 0.0, 0.025, 0.05, m, Vector3(0, -0.025, 0), Vector3(180, 0, 0), 4)
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 2.0
	p.position = Vector3(0, _py + 0.05, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.3
	p.emission_ring_inner_radius = 0.15
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 8.0
	p.gravity = Vector3(0, 0.15, 0)
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.022
	mesh.height = 0.044
	mesh.radial_segments = 5
	mesh.rings = 3
	mesh.material = M.mat(Color(0.75, 0.45, 1.0), 2.2)
	p.mesh = mesh
	add_child(p)


# --- Brujo humano ---

func _robe_mats() -> Array:
	match _tier:
		0: return [M.mat(HERMIT), M.mat(HERMIT_DARK), M.mat(Color(0.4, 0.3, 0.2))]
		3: return [M.mat(Color(0.1, 0.07, 0.14)), M.mat(Color(0.06, 0.04, 0.09)), M.metal(GOLD)]
	return [M.mat(ROBE), M.mat(ROBE_DARK), M.metal(GOLD)]


func _build_mage_body(root: Node3D) -> void:
	var t := _tier
	var c := Node3D.new()
	c.position = Vector3(0, 0, OP_Z)
	root.add_child(c)
	var mats := _robe_mats()
	var robe: Material = mats[0]
	var robe_dark: Material = mats[1]
	var trim: Material = mats[2]
	var gold := M.metal(GOLD)
	var glow := M.mat(VOID_GLOW, 1.6)
	Human.body(c, robe, trim)
	# túnica larga hasta los pies
	M.cyl(c, 0.15, 0.19, 0.08, robe_dark, Vector3(0, 0.04, 0), Vector3.ZERO, 16)
	if t >= 1:
		M.box(c, Vector3(0.05, 0.26, 0.03), robe_dark if t < 3 else gold, Vector3(0, 0.14, -0.13))
		for y: float in [0.2, 0.12]:
			M.sphere(c, 0.012, gold, Vector3(0, y, -0.148), Vector3.ONE, 6)
	# cinturón (cuerda en la etapa 0) con gema del vacío
	M.cyl(c, 0.145, 0.145, 0.025, M.mat(Color(0.8, 0.68, 0.48)) if t == 0 else M.mat(Color(0.18, 0.12, 0.1)), Vector3(0, 0.13, 0), Vector3.ZERO, 16)
	if t >= 1:
		M.sphere(c, 0.02, glow, Vector3(0, 0.13, -0.145), Vector3.ONE, 8)
	# cuello alto de la capa
	if t >= 1:
		var collar := TorusMesh.new()
		collar.inner_radius = 0.08
		collar.outer_radius = 0.14 if t < 3 else 0.16
		M.add(c, collar, robe_dark, Vector3(0, 0.33, 0.01), Vector3(10, 0, 0))
	# capa larga por detrás
	if t >= 1:
		M.box(c, Vector3(0.3, 0.34, 0.03), robe_dark, Vector3(0, 0.17, 0.12), Vector3(-8, 0, 0))
		M.box(c, Vector3(0.32, 0.025, 0.035), glow if t == 3 else gold, Vector3(0, 0.01, 0.135))
	if t >= 2:
		# hombreras (acero / oro)
		var pad := M.metal(Color(0.42, 0.42, 0.48)) if t == 2 else gold
		for s: float in [-1.0, 1.0]:
			M.sphere(c, 0.075, pad, Vector3(0.14 * s, 0.29, 0), Vector3(1, 0.62, 1), 10)
			M.cyl(c, 0.07, 0.07, 0.012, gold if t == 2 else glow, Vector3(0.145 * s, 0.26, 0), Vector3(0, 0, 18.0 * s), 10)
	# cabeza con capucha puntiaguda
	var h := Human.head(c, false, false)
	M.sphere(h, 0.158, robe, Vector3(0, 0.03, 0.04), Vector3.ONE, 14)
	M.cyl(h, 0.0, 0.07, 0.18, robe, Vector3(0, 0.08, 0.17), Vector3(-62, 0, 0), 8)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.12
	rim.outer_radius = 0.145
	M.add(h, rim, robe_dark if t < 3 else gold, Vector3(0, 0.0, -0.07), Vector3(80, 0, 0))
	if t == 0:
		# barba gris de ermitaño
		M.sphere(h, 0.06, M.mat(Color(0.75, 0.74, 0.72)), Vector3(0, -0.1, -0.1), Vector3(1.1, 1.2, 0.7), 8)
	else:
		M.sphere(h, 0.03, M.mat(Color(0.18, 0.12, 0.1)), Vector3(0, -0.11, -0.11), Vector3(0.8, 1.3, 0.7), 8)
	if t == 3:
		# corona de puntas doradas sobre la capucha
		for k in 5:
			var a := PI + (k - 2) * 0.4
			M.cyl(h, 0.0, 0.016, 0.06, gold, Vector3(sin(a) * 0.15, 0.13, cos(a) * 0.15 + 0.02), Vector3.ZERO, 4)
		M.sphere(h, 0.018, glow, Vector3(0, 0.1, -0.15), Vector3.ONE, 6)
	# brazo izquierdo alzado con una llama del vacío en la palma
	Human.arm(c, Human.L_SHOULDER, Vector3(-0.19, 0.42, -0.14), robe, trim)
	# brazo derecho que sostiene el bastón
	Human.arm(c, Human.R_SHOULDER, STAFF_HAND, robe, trim)


func _build_mage_parts() -> void:
	var t := _tier
	var c := Node3D.new()
	c.position = Vector3(0, 0, OP_Z)
	cat_pivot.add_child(c)
	var iron := M.metal(IRON)
	var gold := M.metal(GOLD)
	_hand_flame = Node3D.new()
	_hand_flame.position = Vector3(-0.19, 0.49, -0.15)
	c.add_child(_hand_flame)
	M.cyl(_hand_flame, 0.0, 0.035, 0.09, M.mat(VOID_GLOW, 2.0), Vector3.ZERO, Vector3.ZERO, 6)
	M.sphere(_hand_flame, 0.025, M.mat(Color(0.95, 0.8, 1.0), 2.0), Vector3(0, -0.02, 0), Vector3.ONE, 6)
	_staff = Node3D.new()
	_staff.position = STAFF_HAND
	c.add_child(_staff)
	if t == 0:
		# bastón nudoso de madera con un cristal atado
		var wood := M.mat(Color(0.42, 0.3, 0.18))
		M.segment(_staff, 0.016, wood, Vector3(0, -0.25, 0), Vector3(0.01, 0.2, 0), 6)
		M.segment(_staff, 0.016, wood, Vector3(0.01, 0.2, 0), Vector3(-0.01, 0.5, 0), 6)
		M.sphere(_staff, 0.022, wood, Vector3(0.01, 0.2, 0), Vector3.ONE, 6)
		M.cyl(_staff, 0.02, 0.02, 0.03, M.mat(Color(0.8, 0.68, 0.48)), Vector3(0, 0.48, 0), Vector3.ZERO, 6)
		M.cyl(_staff, 0.0, 0.02, 0.05, _rune_mat, Vector3(0, 0.55, 0), Vector3.ZERO, 5)
		return
	# bastón alto de madera oscura (dorado en Maestría) con garra y cristal del vacío
	var shaft_m: Material = gold if t == 3 else M.mat(Color(0.2, 0.13, 0.1))
	var claw: Material = gold if t >= 2 else iron
	M.segment(_staff, 0.016, shaft_m, Vector3(0, -0.25, 0), Vector3(0, 0.52, 0), 8)
	M.cyl(_staff, 0.022, 0.022, 0.03, gold, Vector3(0, 0.0, 0), Vector3.ZERO, 8)
	M.cyl(_staff, 0.03, 0.018, 0.05, claw, Vector3(0, 0.53, 0), Vector3.ZERO, 8)
	for i in 3:
		var a := TAU * i / 3.0
		var p := Vector3(cos(a), 0, sin(a))
		M.segment(_staff, 0.008, claw, p * 0.02 + Vector3(0, 0.54, 0), p * 0.04 + Vector3(0, 0.62, 0), 4)
	var cs := 1.0 if t < 3 else 1.4
	M.cyl(_staff, 0.0, 0.026 * cs, 0.06 * cs, _rune_mat, Vector3(0, 0.6, 0), Vector3.ZERO, 6)
	M.cyl(_staff, 0.0, 0.026 * cs, 0.05 * cs, _rune_mat, Vector3(0, 0.545, 0), Vector3(180, 0, 0), 6)
