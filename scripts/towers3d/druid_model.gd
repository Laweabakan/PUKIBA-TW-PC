extends Node3D
## Modelo 3D del "Círculo del Druida": un anillo de menhires musgosos (estilo Stonehenge, con
## dinteles y espirales celtas brillantes) alrededor de un roble antiguo y retorcido que crece
## sobre un túmulo; entre sus ramas hay una plataforma de madera. Encima, un druida humano de
## larga barba gris, túnica verde con capucha, corona de astas y bastón con cristal verde brillante.
## El druida mira hacia -Z dentro de cat_pivot.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")

const GRASS := Color(0.36, 0.55, 0.22)
const GRASS_DARK := Color(0.28, 0.45, 0.18)
const EARTH := Color(0.42, 0.3, 0.18)
const MOSS := Color(0.38, 0.58, 0.2)
const STONE := Color(0.55, 0.55, 0.52)
const STONE_DARK := Color(0.46, 0.46, 0.44)
const BARK := Color(0.36, 0.25, 0.16)
const BARK_DARK := Color(0.27, 0.18, 0.11)
const LEAF := Color(0.3, 0.55, 0.18)
const LEAF_LIGHT := Color(0.42, 0.66, 0.24)
const LEAF_DARK := Color(0.22, 0.42, 0.14)
const NATURE_GLOW := Color(0.3, 0.9, 0.25)
const ROBE := Color(0.24, 0.42, 0.2)
const ROBE_DARK := Color(0.16, 0.3, 0.14)
const BEARD := Color(0.72, 0.72, 0.7)
const ANTLER := Color(0.88, 0.82, 0.68)

const PLATFORM_Y := 0.95
const STAFF_HAND := Vector3(0.2, 0.25, -0.11)
const CRYSTAL_LOCAL := Vector3(0, 0.6, 0)

var cat_pivot: Node3D
var _glow_mat: StandardMaterial3D
var _wave_mat: StandardMaterial3D
var _leaves: Node3D
var _staff: Node3D
var _crystal: Node3D
var _roots: Array[Node3D] = []
var _wave: MeshInstance3D

## Altura de la plataforma (pies del druida) en cada etapa visual
const TIER_PY := [0.32, 0.62, 0.95, 1.3]
## Arbolillo de la etapa 0
const SAPLING_POS := Vector3(-0.27, 0.0, -0.2)

var _tier := 0
var _py := PLATFORM_Y


static func _tier_of(level: int) -> int:
	if level >= 5:
		return 3
	if level >= 4:
		return 2
	if level >= 2:
		return 1
	return 0


## level: nivel de la torre. Etapas: 0 tres piedras, un tocón y un arbolillo, 1 roble joven con anillo de
## menhires, 2 círculo de menhires con dinteles y roble, 3 (Maestría) santuario de un roble milenario con
## piedras blancas y oro, muérdago dorado y luciérnagas.
func _init(level := 0) -> void:
	_tier = _tier_of(level)
	_py = TIER_PY[_tier]
	_glow_mat = (M.mat(NATURE_GLOW, 1.0) as StandardMaterial3D).duplicate() as StandardMaterial3D
	M.add_baked(self, M.baked("druid_tower_t%d" % _tier, _build_tower))
	_leaves = Node3D.new()
	_leaves.position = Vector3(0, _py, 0)
	add_child(_leaves)
	M.add_baked(_leaves, M.baked("druid_leaves_t%d" % _tier, _build_leaves))
	_build_roots()
	if _tier == 3:
		add_child(_fireflies())
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, _py, 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("druid_druid_t%d" % _tier, _build_druid_body))
	_build_druid_parts()
	animate({"t": 0.0, "charge": 0.3, "fire": 0.0})


## s = {t, charge 0..1, fire 1 -> 0, has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = clampf(s.get("charge", 0.0), 0.0, 1.0)
	var fire: float = clampf(s.get("fire", 0.0), 0.0, 1.0)
	# Las hojas se mecen con el viento
	_leaves.rotation = Vector3(sin(t * 1.3) * 0.03, sin(t * 0.7) * 0.04, sin(t * 1.1 + 0.5) * 0.035)
	# El cristal brilla con la carga
	_glow_mat.emission_energy_multiplier = 0.35 + charge * 1.3 + fire * 0.9
	_crystal.scale = Vector3.ONE * (0.85 + charge * 0.35 + sin(t * 6.0) * 0.04 * charge)
	_crystal.rotation.y = t * (0.5 + charge * 3.0)
	# Golpe de bastón al lanzar
	_staff.rotation.x = -0.08 + charge * 0.12 - fire * 0.45
	_staff.position.y = STAFF_HAND.y + charge * 0.05 - fire * 0.06
	# Raíces y enredaderas que brotan del suelo mientras carga
	for i in _roots.size():
		var r := _roots[i]
		var grow: float = clampf(charge * 1.3 - i * 0.06, 0.0, 1.0)
		r.visible = grow > 0.02
		r.scale = Vector3(0.6 + grow * 0.4, grow, 0.6 + grow * 0.4)
		r.rotation.y = float(i) * 1.3 + sin(t * 2.0 + i) * 0.1 * grow
	# Onda verde en la plataforma tras el golpe
	_wave.visible = fire > 0.0
	_wave.scale = Vector3.ONE * (1.0 + (1.0 - fire) * 2.5)
	_wave_mat.albedo_color.a = fire * 0.6


func muzzle_global() -> Vector3:
	return _crystal.global_position


# --- Torre: césped, túmulo, menhires y roble ---

func _build_tower(parent: Node3D) -> void:
	var py := _py
	var grass := M.mat(GRASS)
	var grass_dark := M.mat(GRASS_DARK)
	var moss := M.mat(MOSS)
	var earth := M.mat(EARTH)
	var stones := [M.mat(STONE), M.mat(STONE_DARK), M.mat(STONE.lightened(0.08))]
	if _tier == 3:
		# Maestría: piedras claras como hueso, con remates de oro
		stones = [M.mat(Color(0.86, 0.85, 0.8)), M.mat(Color(0.78, 0.77, 0.72)), M.mat(Color(0.92, 0.91, 0.87))]
	var spiral := M.mat(NATURE_GLOW.darkened(0.15), 1.0 if _tier < 3 else 1.6)
	var gold := M.metal(Color(1.0, 0.8, 0.32))

	# Césped y túmulo
	M.cyl(parent, 0.46, 0.47, 0.06, grass_dark, Vector3(0, 0.03, 0), Vector3.ZERO, 20)
	M.sphere(parent, 0.32, earth, Vector3(0, 0.04, 0), Vector3(1, 0.42, 1), 16)
	M.sphere(parent, 0.3, grass, Vector3(0, 0.06, 0), Vector3(1, 0.4, 1), 16)

	# Anillo de menhires (hueco al frente +Z). [ángulo, altura, dintel]
	var ring: Array = [[-2.4, 0.4, true], [-1.75, 0.42, true], [-1.0, 0.36, false], [-0.3, 0.44, true],
			[0.35, 0.44, true], [1.05, 0.38, false], [2.35, 0.34, false]]
	var wscale := 1.0
	match _tier:
		0:
			ring = [[-1.7, 0.24, false], [-0.25, 0.3, false], [1.25, 0.21, false]]
			wscale = 0.8
		1:
			ring = [[-2.2, 0.3, false], [-1.3, 0.34, false], [-0.4, 0.36, true], [0.4, 0.36, true], [1.3, 0.32, false], [2.2, 0.3, false]]
			wscale = 0.9
		3:
			ring = [[-2.4, 0.46, true], [-1.75, 0.5, true], [-1.05, 0.48, true], [-0.35, 0.52, true],
					[0.35, 0.52, true], [1.05, 0.48, true], [1.75, 0.5, true], [2.4, 0.46, true]]
			wscale = 1.05
	var tops := []
	for i in ring.size():
		var e: Array = ring[i]
		var a: float = float(e[0]) - PI * 0.5
		var h: float = e[1]
		var p := Vector3(cos(a), 0, sin(a)) * 0.39
		var n := Node3D.new()
		n.position = p
		n.rotation = Vector3(0, -a + PI * 0.5, 0.04 * (1.0 if i % 2 == 0 else -1.0))
		parent.add_child(n)
		M.box(n, Vector3(0.1 * wscale, h, 0.075 * wscale), stones[i % 3], Vector3(0, h * 0.5, 0))
		M.cyl(n, 0.035 * wscale, 0.05 * wscale, 0.04, stones[(i + 1) % 3], Vector3(0, h + 0.005, 0), Vector3.ZERO, 6)
		M.sphere(n, 0.045, moss, Vector3(0.01, h + 0.01, 0), Vector3(1.3, 0.45, 1.0), 8)
		M.sphere(n, 0.035, moss, Vector3(-0.03, 0.04, 0.03), Vector3(1.2, 0.8, 0.8), 8)
		# espiral celta brillante en la cara interior (menhires altos; todos en la Maestría)
		if (h > 0.4 or _tier == 3) and _tier > 0:
			var sp := TorusMesh.new()
			sp.inner_radius = 0.016
			sp.outer_radius = 0.024
			sp.rings = 12
			sp.ring_segments = 4
			M.add(n, sp, spiral, Vector3(0, h * 0.55, -0.04), Vector3(90, 0, 0))
			M.sphere(n, 0.009, spiral, Vector3(0, h * 0.55, -0.042), Vector3.ONE, 6)
			if _tier == 3:
				M.add(n, sp, spiral, Vector3(0, h * 0.55, 0.04), Vector3(90, 0, 0))
				M.box(n, Vector3(0.11 * wscale, 0.02, 0.085 * wscale), gold, Vector3(0, h * 0.2, 0))
		tops.append([p, h, e[2]])
	# dinteles sobre parejas contiguas
	for i in range(tops.size() - 1):
		var t0: Array = tops[i]
		var t1: Array = tops[i + 1]
		if t0[2] and t1[2]:
			var p0: Vector3 = t0[0]
			var p1: Vector3 = t1[0]
			var y: float = minf(t0[1], t1[1]) + 0.03
			var lin := Node3D.new()
			lin.position = (p0 + p1) * 0.5 + Vector3(0, y, 0)
			lin.rotation.y = atan2(-(p1 - p0).z, (p1 - p0).x)
			parent.add_child(lin)
			M.box(lin, Vector3((p1 - p0).length() + 0.1, 0.055, 0.075), stones[2])
			M.sphere(lin, 0.04, moss, Vector3(0.05, 0.03, 0), Vector3(1.6, 0.4, 1.0), 8)
			if _tier == 3:
				M.box(lin, Vector3((p1 - p0).length() + 0.1, 0.015, 0.08), gold, Vector3(0, -0.02, 0))
	# piedra del altar al frente (detrás de la franja de las gemas de nivel)
	M.box(parent, Vector3(0.18, 0.05, 0.1), stones[1], Vector3(0, 0.07, 0.33), Vector3(0, 0, 3))
	if _tier == 3:
		M.sphere(parent, 0.03, M.mat(NATURE_GLOW, 1.5), Vector3(0, 0.12, 0.33), Vector3(1, 0.8, 1), 8)

	var bark := M.mat(BARK)
	var bark_dark := M.mat(BARK_DARK)
	var wood := M.tex_mat("wood", 2.5, Color(0.85, 0.7, 0.55))
	var rope := M.mat(Color(0.8, 0.7, 0.5))
	if _tier == 0:
		_build_stump(parent, bark, bark_dark)
	else:
		# Tronco retorcido del roble (más grueso cuanto más antiguo)
		var tk: float = [0.0, 0.72, 1.0, 1.35][_tier]
		var trunk := [Vector3(0, 0.12, 0), Vector3(0.03, py * 0.37, 0.02), Vector3(-0.02, py * 0.61, -0.02), Vector3(0.02, py * 0.84, 0.01), Vector3(0, py - 0.02, 0)]
		var radii := [0.13, 0.11, 0.1, 0.095, 0.09]
		for i in range(trunk.size() - 1):
			var a0: Vector3 = trunk[i]
			var a1: Vector3 = trunk[i + 1]
			M.segment(parent, float(radii[i]) * tk, bark, a0, a1, 10)
			M.sphere(parent, float(radii[i + 1]) * tk, bark, a1, Vector3.ONE, 10)
		# vetas y nudos de la corteza
		for k in 6:
			var ang := TAU * k / 6.0 + 0.3
			var d := Vector3(cos(ang), 0, sin(ang))
			M.segment(parent, 0.022 * tk, bark_dark, d * 0.12 * tk + Vector3(0, 0.15, 0), d * 0.095 * tk + Vector3(0, py * 0.74, 0), 6)
		M.sphere(parent, 0.035 * tk, bark_dark, Vector3(0.0, py * 0.53, 0.1 * tk), Vector3(1, 1.3, 0.6), 8)
		M.sphere(parent, 0.02 * tk, M.mat(Color(0.12, 0.08, 0.05)) if _tier < 3 else M.mat(NATURE_GLOW, 1.4), Vector3(0.0, py * 0.53, 0.12 * tk), Vector3(1, 1.4, 0.5), 6)
		# raíces que se hunden en el túmulo
		for k in (5 if _tier < 3 else 7):
			var ang2 := TAU * k / (5.0 if _tier < 3 else 7.0) + 0.6
			var d2 := Vector3(cos(ang2), 0, sin(ang2))
			M.segment(parent, 0.04 * tk, bark, d2 * 0.27 + Vector3(0, 0.06, 0), d2 * 0.08 + Vector3(0, 0.28, 0), 6)
			M.sphere(parent, 0.04 * tk, bark, d2 * 0.27 + Vector3(0, 0.06, 0), Vector3.ONE, 6)
		# ramas que abrazan la plataforma
		var pr: float = [0.0, 0.22, 0.25, 0.28][_tier]
		for k in 5:
			var ang3 := TAU * k / 5.0 + 0.2
			var d3 := Vector3(cos(ang3), 0, sin(ang3))
			var b0 := d3 * 0.06 + Vector3(0, py - 0.15, 0)
			var b1 := d3 * (pr + 0.02) + Vector3(0, py - 0.02, 0)
			var b2 := d3 * (pr + 0.11) + Vector3(0, py + 0.26 + 0.04 * (k % 2), 0)
			M.segment(parent, 0.045 * minf(tk, 1.15), bark, b0, b1, 8)
			M.sphere(parent, 0.045 * minf(tk, 1.15), bark, b1, Vector3.ONE, 8)
			M.segment(parent, 0.032 * minf(tk, 1.15), bark, b1, b2, 8)
			var side := d3.rotated(Vector3.UP, 0.8)
			M.segment(parent, 0.018, bark_dark, b1.lerp(b2, 0.4), b1.lerp(b2, 0.4) + side * 0.12 + Vector3(0, 0.1, 0), 6)
		# Plataforma de tablones entre las ramas
		M.cyl(parent, pr, pr - 0.02, 0.045, wood, Vector3(0, py - 0.022, 0), Vector3.ZERO, 10)
		var rim := TorusMesh.new()
		rim.inner_radius = pr - 0.015
		rim.outer_radius = pr + 0.01
		rim.rings = 20
		rim.ring_segments = 6
		M.add(parent, rim, M.mat(BARK_DARK) if _tier < 3 else gold, Vector3(0, py - 0.02, 0))
		for k in 6:
			var ang4 := TAU * k / 6.0
			var pp := Vector3(cos(ang4), 0, sin(ang4)) * (pr - 0.01) + Vector3(0, py, 0)
			M.cyl(parent, 0.016, 0.02, 0.1, M.mat(BARK_DARK), pp + Vector3(0, 0.03, 0), Vector3.ZERO, 6)
			M.cyl(parent, 0.024, 0.024, 0.015, rope if _tier < 3 else gold, pp + Vector3(0, 0.05, 0), Vector3.ZERO, 6)
		# escalera de cuerda colgando del frente
		var lz := pr + 0.02
		for s: float in [-1.0, 1.0]:
			M.segment(parent, 0.008, rope, Vector3(0.05 * s, 0.25, lz + 0.03), Vector3(0.05 * s, py - 0.03, lz), 4)
		var rungs := int((py - 0.35) / 0.13) + 1
		for k in rungs:
			var y2: float = 0.32 + k * 0.13
			M.box(parent, Vector3(0.12, 0.016, 0.022), M.mat(BARK), Vector3(0, y2, lz + 0.03 - (y2 - 0.25) / (py - 0.28) * 0.03))

	# Setas, helechos y flores silvestres en el césped
	var cap := M.mat(Color(0.78, 0.2, 0.15))
	for p: Vector3 in [Vector3(-0.2, 0.1, 0.2), Vector3(0.22, 0.1, 0.18), Vector3(0.17, 0.11, -0.22)]:
		M.cyl(parent, 0.008, 0.01, 0.04, M.mat(Color(0.95, 0.92, 0.85)), p, Vector3.ZERO, 6)
		M.sphere(parent, 0.022, cap, p + Vector3(0, 0.025, 0), Vector3(1, 0.55, 1), 8)
	var flowers := [M.mat(Color.WHITE), M.mat(Color(1.0, 0.85, 0.3)), M.mat(Color(0.75, 0.55, 1.0))]
	for i in 8:
		var fa := TAU * i / 8.0 + 0.2
		var fp := Vector3(cos(fa), 0, sin(fa)) * (0.44 if i % 2 == 0 else 0.26) + Vector3(0, 0.065 if i % 2 == 0 else 0.1, 0)
		for b in 3:
			var blade := Node3D.new()
			var ba := TAU * b / 3.0 + i
			blade.position = fp + Vector3(cos(ba), 0, sin(ba)) * 0.015
			blade.rotation = Vector3(sin(ba) * 0.4, 0, -cos(ba) * 0.4)
			parent.add_child(blade)
			M.cyl(blade, 0.0, 0.014, 0.08, grass, Vector3(0, 0.04, 0), Vector3.ZERO, 4)
		M.sphere(parent, 0.016, flowers[i % 3], fp + Vector3(0.025, 0.04, 0.0), Vector3.ONE, 6)


# Etapa 0: viejo tocón ancho donde se planta el druida y un arbolillo joven detrás
func _build_stump(parent: Node3D, bark: Material, bark_dark: Material) -> void:
	var py := _py
	M.cyl(parent, 0.2, 0.24, py - 0.04, bark, Vector3(0, 0.04 + (py - 0.04) / 2.0, 0), Vector3.ZERO, 12)
	for k in 8:
		var ang := TAU * k / 8.0 + 0.2
		var d := Vector3(cos(ang), 0, sin(ang))
		M.segment(parent, 0.02, bark_dark, d * 0.215 + Vector3(0, 0.08, 0), d * 0.195 + Vector3(0, py - 0.03, 0), 6)
	# corte con anillos del tronco
	M.cyl(parent, 0.19, 0.19, 0.02, M.mat(Color(0.82, 0.66, 0.45)), Vector3(0, py - 0.01, 0), Vector3.ZERO, 14)
	for r in [0.06, 0.11, 0.15]:
		var ring := TorusMesh.new()
		ring.inner_radius = r - 0.006
		ring.outer_radius = r + 0.006
		ring.rings = 16
		ring.ring_segments = 4
		M.add(parent, ring, M.mat(Color(0.6, 0.44, 0.28)), Vector3(0, py, 0), Vector3.ZERO, Vector3(1, 0.3, 1))
	# raíces que se abren sobre el césped
	for k in 5:
		var ang2 := TAU * k / 5.0 + 0.4
		var d2 := Vector3(cos(ang2), 0, sin(ang2))
		M.segment(parent, 0.035, bark, d2 * 0.33 + Vector3(0, 0.05, 0), d2 * 0.18 + Vector3(0, 0.16, 0), 6)
		M.sphere(parent, 0.035, bark, d2 * 0.33 + Vector3(0, 0.05, 0), Vector3.ONE, 6)
	M.sphere(parent, 0.05, M.mat(MOSS), Vector3(0.12, py - 0.06, 0.14), Vector3(1.3, 0.6, 1.0), 8)
	# arbolillo joven (sus hojas van en la copa animada)
	var sp := SAPLING_POS
	M.segment(parent, 0.022, bark, sp + Vector3(0, 0.04, 0), sp + Vector3(0.02, 0.4, 0), 6)
	M.segment(parent, 0.016, bark, sp + Vector3(0.02, 0.4, 0), sp + Vector3(-0.01, 0.6, 0.01), 6)
	M.segment(parent, 0.01, bark, sp + Vector3(0.015, 0.34, 0), sp + Vector3(0.1, 0.48, 0.03), 5)


# Copa del árbol (malla aparte para que se meza); coordenadas relativas a la plataforma
func _build_leaves(parent: Node3D) -> void:
	var leaf := [M.mat(LEAF), M.mat(LEAF_LIGHT), M.mat(LEAF_DARK)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	if _tier == 0:
		# copa del arbolillo
		var c0 := SAPLING_POS + Vector3(0.0, 0.62 - _py, 0.0)
		M.sphere(parent, 0.11, leaf[0], c0, Vector3(1.1, 0.85, 1.1), 12)
		M.sphere(parent, 0.075, leaf[1], c0 + Vector3(0.07, 0.03, 0.04), Vector3.ONE, 10)
		M.sphere(parent, 0.07, leaf[2], c0 + Vector3(-0.06, -0.02, -0.03), Vector3.ONE, 10)
		M.sphere(parent, 0.06, leaf[1], c0 + Vector3(0.1, -0.12, 0.03), Vector3.ONE, 10)
		return
	var clumps: int = [0, 4, 5, 6][_tier]
	var cr: float = [0.0, 0.3, 0.37, 0.4][_tier]
	var cs: float = [0.0, 0.1, 0.13, 0.145][_tier]
	for k in clumps:
		var ang := TAU * k / clumps + 0.2
		var d := Vector3(cos(ang), 0, sin(ang))
		var c := d * cr + Vector3(0, 0.3 + 0.04 * (k % 2), 0)
		M.sphere(parent, cs, leaf[k % 3], c, Vector3(1.1, 0.75, 1.1), 12)
		for j in 3:
			var o := Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.02, 0.08), rng.randf_range(-0.1, 0.1))
			M.sphere(parent, rng.randf_range(0.06, 0.09) * cs / 0.13, leaf[(k + j + 1) % 3], c + o + d * 0.04, Vector3(1, 0.8, 1), 10)
		# bellotas (y muérdago dorado en la Maestría)
		M.sphere(parent, 0.016, M.mat(Color(0.6, 0.42, 0.2)), c + Vector3(0, -0.09, 0) + d * 0.05, Vector3(1, 1.2, 1), 6)
		if _tier == 3:
			for j in 3:
				M.sphere(parent, 0.017, M.mat(Color(1.0, 0.86, 0.4), 1.2), c + Vector3(0.03 * j - 0.03, -0.1, 0.02 * j) - d * 0.03, Vector3.ONE, 6)
	if _tier < 2:
		return
	# farolillos verdes colgando de las ramas
	var lamps := [Vector3(0.26, 0.12, 0.2)]
	if _tier == 3:
		lamps.append(Vector3(-0.28, 0.12, 0.16))
		lamps.append(Vector3(0.05, 0.14, -0.33))
	for lpv in lamps:
		var lp: Vector3 = lpv
		M.segment(parent, 0.004, M.mat(Color(0.8, 0.7, 0.5)), lp + Vector3(0, 0.04, 0), lp + Vector3(0, 0.2, 0), 4)
		M.box(parent, Vector3(0.05, 0.065, 0.05), M.metal(Color(0.3, 0.28, 0.25)), lp)
		M.box(parent, Vector3(0.04, 0.05, 0.055), M.mat(NATURE_GLOW, 1.4), lp)
		M.cyl(parent, 0.0, 0.035, 0.03, M.metal(Color(0.3, 0.28, 0.25)), lp + Vector3(0, 0.045, 0), Vector3(0, 45, 0), 4)


# Luciérnagas que flotan alrededor del roble milenario (Maestría)
func _fireflies() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 3.0
	p.position = Vector3(0, _py + 0.1, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, 0.03, 0)
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.08
	p.tangential_accel_min = 0.1
	p.tangential_accel_max = 0.25
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.3, 1))
	curve.add_point(Vector2(0.7, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var mesh := SphereMesh.new()
	mesh.radius = 0.014
	mesh.height = 0.028
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = M.mat(Color(0.8, 1.0, 0.45), 2.0)
	p.mesh = mesh
	return p


# Raíces y enredaderas que brotan del suelo durante la carga
func _build_roots() -> void:
	var bark := M.mat(BARK)
	var vine := M.mat(LEAF)
	for i in 5:
		var a := TAU * i / 5.0 + 0.95
		var r := Node3D.new()
		r.position = Vector3(cos(a), 0, sin(a)) * 0.3 + Vector3(0, 0.05, 0)
		add_child(r)
		r.visible = false
		_roots.append(r)
		var g := Node3D.new()
		g.scale = Vector3.ONE * 1.5
		r.add_child(g)
		M.cyl(g, 0.012, 0.035, 0.14, bark, Vector3(0, 0.07, 0), Vector3(0, 0, 10), 6)
		M.cyl(g, 0.0, 0.014, 0.1, bark, Vector3(-0.015, 0.18, 0), Vector3(0, 0, -15), 6)
		M.sphere(g, 0.022, vine, Vector3(0.02, 0.1, 0.0), Vector3(1.3, 0.5, 0.8), 6)
		M.sphere(g, 0.014, _glow_mat, Vector3(-0.025, 0.235, 0), Vector3.ONE, 6)


# --- Druida humano ---

func _build_druid_body(c: Node3D) -> void:
	var robe := M.mat([Color(0.46, 0.34, 0.22), ROBE, ROBE, Color(0.94, 0.93, 0.87)][_tier])
	var robe_dark := M.mat([Color(0.34, 0.25, 0.16), ROBE_DARK, ROBE_DARK, Color(0.24, 0.42, 0.2)][_tier])
	var leather := M.mat(Color(0.45, 0.3, 0.17)) if _tier < 3 else M.metal(Color(1.0, 0.8, 0.32))
	var beard := M.mat(BEARD)
	var beard_shade := M.mat(BEARD.darkened(0.12))
	var antler := M.mat(ANTLER)
	Human.body(c, robe, leather)
	# túnica larga, cinturón de cuerda y bolsa de hierbas
	M.cyl(c, 0.15, 0.19, 0.08, robe_dark, Vector3(0, 0.04, 0), Vector3.ZERO, 16)
	var belt := TorusMesh.new()
	belt.inner_radius = 0.135
	belt.outer_radius = 0.16
	M.add(c, belt, M.mat(Color(0.8, 0.7, 0.5)), Vector3(0, 0.12, 0))
	M.box(c, Vector3(0.06, 0.06, 0.04), leather, Vector3(-0.1, 0.09, -0.11), Vector3(0, 20, 0))
	M.sphere(c, 0.02, M.mat(LEAF_LIGHT), Vector3(-0.1, 0.13, -0.12), Vector3(1.2, 0.6, 1), 6)
	# capa de hojas por detrás
	M.box(c, Vector3(0.3, 0.34, 0.03), robe_dark, Vector3(0, 0.17, 0.12), Vector3(-8, 0, 0))
	for k in 4:
		M.cyl(c, 0.0, 0.035, 0.06, M.mat(LEAF_DARK), Vector3(-0.11 + k * 0.073, 0.0, 0.14), Vector3(180, 0, 0), 4)
	# cabeza con capucha
	var h := Human.head(c, false, false)
	M.sphere(h, 0.158, robe, Vector3(0, 0.03, 0.04), Vector3.ONE, 14)
	M.cyl(h, 0.0, 0.07, 0.16, robe, Vector3(0, 0.02, 0.17), Vector3(-75, 0, 0), 8)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.12
	rim.outer_radius = 0.145
	M.add(h, rim, robe_dark, Vector3(0, 0.0, -0.07), Vector3(80, 0, 0))
	# cejas pobladas, bigote y larga barba gris
	for s: float in [-1.0, 1.0]:
		var brow := M.sphere(h, 0.028, beard, Vector3(0.05 * s, 0.05, -0.13), Vector3(1.6, 0.6, 0.7), 8)
		brow.rotation.z = -0.3 * s
		var stache := M.sphere(h, 0.032, beard, Vector3(0.04 * s, -0.065, -0.145), Vector3(1.6, 0.6, 0.7), 8)
		stache.rotation.z = 0.35 * s
	var bd := [[Vector3(0, -0.11, -0.115), 0.085, 1.2], [Vector3(0, -0.19, -0.13), 0.07, 1.05],
			[Vector3(0, -0.26, -0.135), 0.055, 0.95], [Vector3(0, -0.32, -0.135), 0.04, 0.85]]
	for i in bd.size():
		var b: Array = bd[i]
		M.sphere(h, b[1], beard if i % 2 == 0 else beard_shade, b[0], Vector3(b[2], 1.0, 0.65), 10)
	M.cyl(h, 0.0, 0.026, 0.07, beard, Vector3(0, -0.375, -0.135), Vector3(180, 0, 0), 6)
	# corona de astas sobre la capucha (diadema de ramitas en la etapa 0, astas de oro y luz en la Maestría)
	var band := TorusMesh.new()
	band.inner_radius = 0.135
	band.outer_radius = 0.155
	M.add(h, band, M.mat(Color(0.5, 0.36, 0.2)) if _tier < 3 else M.metal(Color(1.0, 0.8, 0.32)), Vector3(0, 0.07, 0.01), Vector3(-8, 0, 0))
	var ak: float = [0.0, 0.65, 1.0, 1.25][_tier]
	if _tier == 0:
		for s: float in [-1.0, 1.0]:
			M.segment(h, 0.008, M.mat(BARK), Vector3(0.1 * s, 0.1, 0.0), Vector3(0.14 * s, 0.17, 0.0), 4)
			M.segment(h, 0.007, M.mat(BARK), Vector3(0.06 * s, 0.11, -0.08), Vector3(0.08 * s, 0.17, -0.1), 4)
	for s: float in ([] if _tier == 0 else [-1.0, 1.0]):
		var a0 := Vector3(0.09 * s, 0.11, 0.0)
		var a1 := a0 + Vector3(0.08 * s, 0.13, 0.02) * ak
		var a2 := a1 + Vector3(0.03 * s, 0.1, 0.04) * ak
		M.segment(h, 0.016, antler, a0, a1, 6)
		M.segment(h, 0.013, antler, a1, a2, 6)
		M.segment(h, 0.011, antler, a1, a1 + Vector3(-0.03 * s, 0.1, -0.02) * ak, 6)
		M.segment(h, 0.01, antler, a0.lerp(a1, 0.5), a0.lerp(a1, 0.5) + Vector3(0.07 * s, 0.05, -0.03) * ak, 6)
		M.segment(h, 0.01, antler, a2, a2 + Vector3(0.05 * s, 0.05, 0.0) * ak, 5)
		if _tier == 3:
			for tp in [a2 + Vector3(0.05 * s, 0.05, 0.0) * ak, a1 + Vector3(-0.03 * s, 0.1, -0.02) * ak]:
				M.sphere(h, 0.017, M.mat(NATURE_GLOW, 1.8), tp, Vector3.ONE, 6)
	# hojas en la corona
	for s: float in [-1.0, 0.0, 1.0]:
		M.sphere(h, 0.025, M.mat(LEAF_LIGHT), Vector3(0.07 * s, 0.11, -0.1 + absf(s) * 0.03), Vector3(1.2, 0.5, 0.8), 6)
	if _tier == 3:
		# hoz de oro al cinto, broche de hoja y estola verde con orla dorada
		var gold := M.metal(Color(1.0, 0.8, 0.32))
		var sickle := TorusMesh.new()
		sickle.inner_radius = 0.04
		sickle.outer_radius = 0.052
		M.add(c, sickle, gold, Vector3(0.13, 0.07, -0.09), Vector3(90, 30, 0), Vector3(1, 1, 0.6))
		M.box(c, Vector3(0.016, 0.06, 0.016), M.mat(BARK), Vector3(0.12, 0.13, -0.1))
		for s: float in [-1.0, 1.0]:
			M.box(c, Vector3(0.05, 0.3, 0.025), M.mat(ROBE), Vector3(0.05 * s, 0.17, -0.13), Vector3(-6, 0, 0))
			M.box(c, Vector3(0.052, 0.012, 0.027), gold, Vector3(0.05 * s, 0.03, -0.145), Vector3(-6, 0, 0))
		M.sphere(c, 0.025, M.mat(NATURE_GLOW, 1.5), Vector3(0, 0.28, -0.14), Vector3(1, 1.2, 0.6), 8)
	# brazos: izquierdo abierto hacia delante, derecho sujetando el bastón
	Human.arm(c, Human.L_SHOULDER, Vector3(-0.17, 0.25, -0.2), robe, leather)
	Human.arm(c, Human.R_SHOULDER, STAFF_HAND, robe, leather)


func _build_druid_parts() -> void:
	var c := cat_pivot
	var bark := M.mat(BARK)
	# Bastón de madera retorcida con cristal verde entre raíces
	_staff = Node3D.new()
	_staff.position = STAFF_HAND
	c.add_child(_staff)
	M.segment(_staff, 0.017, bark, Vector3(0, -0.24, 0), Vector3(0.01, 0.1, 0), 6)
	M.segment(_staff, 0.016, bark, Vector3(0.01, 0.1, 0), Vector3(-0.005, 0.5, 0), 6)
	M.sphere(_staff, 0.02, bark, Vector3(0.01, 0.1, 0), Vector3.ONE, 6)
	for i in 3:
		var a := TAU * i / 3.0
		var d := Vector3(cos(a), 0, sin(a))
		M.segment(_staff, 0.009, bark, Vector3(0, 0.49, 0) + d * 0.012, CRYSTAL_LOCAL + d * 0.04 + Vector3(0, 0.03, 0), 5)
	M.sphere(_staff, 0.02, M.mat(LEAF_LIGHT), Vector3(0.02, 0.45, 0), Vector3(1.3, 0.6, 1), 6)
	_crystal = Node3D.new()
	_crystal.position = CRYSTAL_LOCAL
	_staff.add_child(_crystal)
	Human.crystal(_crystal, Vector3(0, -0.06, 0), 0.13, 0.03, Vector3.ZERO, _glow_mat)
	Human.crystal(_crystal, Vector3(0, -0.06, 0), 0.08, 0.02, Vector3(0, 0, 160), _glow_mat)
	if _tier == 3:
		# Maestría: cristales extra y anillos de oro en el bastón
		for i in 3:
			Human.crystal(_crystal, Vector3(0, -0.05, 0), 0.09, 0.016, Vector3(30, 120.0 * i, 0), _glow_mat)
		for y in [0.0, 0.25, 0.45]:
			M.cyl(_staff, 0.022, 0.022, 0.02, M.metal(Color(1.0, 0.8, 0.32)), Vector3(0, y, 0), Vector3.ZERO, 8)
	# Onda verde del golpe
	_wave_mat = StandardMaterial3D.new()
	_wave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wave_mat.albedo_color = Color(NATURE_GLOW.r, NATURE_GLOW.g, NATURE_GLOW.b, 0.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.14
	ring.outer_radius = 0.18
	ring.rings = 20
	ring.ring_segments = 4
	_wave = M.add(self, ring, _wave_mat, Vector3(0, _py + 0.02, 0), Vector3.ZERO, Vector3(1, 0.3, 1))
	_wave.visible = false
