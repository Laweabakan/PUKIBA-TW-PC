extends Node3D
## Modelo 3D "Pira del Dragón": torre octogonal de basalto oscuro con forma de fragua, grietas de
## lava, columnas basálticas, estandartes carmesí con llama dorada y una calavera de dragón con
## cuernos al frente cuya boca es la boca de la fragua. Arriba, un brasero-jaula de hierro con
## grandes llamas que parpadean. El operador es un sacerdote del fuego humano con túnica roja oscura
## y capucha, que empuña un báculo con cabeza de dragón.
## charge: las llamas crecen. fire: estallido de llamas y estocada del báculo.

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")

const BASALT := Color(0.24, 0.22, 0.24)
const BASALT_LIGHT := Color(0.33, 0.31, 0.33)
const IRON := Color(0.2, 0.2, 0.22)
const BONE := Color(0.84, 0.78, 0.64)
const BONE_DARK := Color(0.64, 0.58, 0.46)
const LAVA := Color(1.0, 0.36, 0.06)
const FLAME := Color(1.0, 0.42, 0.06)
const FLAME_CORE := Color(1.0, 0.72, 0.2)
const CRIMSON := Color(0.5, 0.06, 0.06)
const ROBE := Color(0.45, 0.08, 0.07)
const ROBE_DARK := Color(0.28, 0.05, 0.05)
const GOLD := Color(0.95, 0.72, 0.28)

const PLATFORM_Y := 1.04
const STAFF_HAND := Vector3(0.2, 0.26, -0.12)
const STAFF_HEAD := Vector3(0, 0.5, 0)
const LEFT_HAND := Vector3(-0.17, 0.34, -0.2)

var cat_pivot: Node3D
var _flames: Array[Node3D] = []
var _flame_base: Array[float] = []
var _staff: Node3D
var _staff_fire: Node3D
var _hand_fire: Node3D
var _embers: CPUParticles3D

## Altura del lecho de brasas (pies del sacerdote) en cada etapa visual
const TIER_PY := [0.62, 0.84, 1.04, 1.4]
## Etapa 3: el cuerpo de la torre se eleva sobre un zócalo de obsidiana
const T3_LIFT := 0.36

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


## level: nivel de la torre. Etapas: 0 pira de troncos sobre un círculo de piedras, 1 forja octogonal de
## basalto, 2 Pira del Dragón con calavera y jaula, 3 (Maestría) torre sobre obsidiana y oro con alas de dragón.
func _init(level := 0) -> void:
	_tier = _tier_of(level)
	_py = TIER_PY[_tier]
	M.add_baked(self, M.baked("inferno_tower_t%d" % _tier, _build_tower_tier))
	_build_flames()
	_embers = _make_embers()
	add_child(_embers)
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, _py, 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("inferno_human_t%d" % _tier, _build_human_body))
	_build_human_parts()
	animate({"t": 0.0, "charge": 0.0, "fire": 0.0, "has_target": false})


## s = {t, charge 0..1, fire 1 -> 0 tras disparar, has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = s.get("charge", 0.0)
	var fire: float = s.get("fire", 0.0)
	var has_target: bool = s.get("has_target", false)
	var c: float = charge if has_target else 0.0
	var grow := 0.85 + c * 0.55 + fire * 0.7
	for i in _flames.size():
		var f := _flames[i]
		var flick := 1.0 + 0.16 * sin(t * 13.0 + i * 1.9) + 0.08 * sin(t * 23.0 + i * 0.7)
		var base := _flame_base[i]
		f.scale = Vector3(base * grow * (1.0 - 0.06 * sin(t * 17.0 + i)), base * grow * flick, base * grow * (1.0 - 0.06 * sin(t * 17.0 + i)))
		f.rotation.y = t * 0.8 + i
	# Báculo: lo alza al cargar y lo lanza hacia delante al disparar
	_staff.rotation.x = lerpf(-0.12 + c * 0.35, -0.95, clampf(fire, 0.0, 1.0))
	_staff_fire.scale = Vector3.ONE * (0.6 + c * 0.7 + fire * 0.8 + sin(t * 15.0) * 0.06)
	_hand_fire.scale = Vector3.ONE * (0.7 + c * 0.5 + 0.12 * sin(t * 11.0))
	_embers.speed_scale = 0.7 + c * 0.8 + fire * 0.5


func muzzle_global() -> Vector3:
	return _staff_fire.global_position


# Chispas que suben del brasero
func _make_embers() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = [8, 12, 18, 30][_tier]
	p.lifetime = 1.2 if _tier < 3 else 1.5
	p.position = Vector3(0, _py + 0.15, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.33
	p.emission_ring_inner_radius = 0.25
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0, 0.3, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.45
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var mesh := SphereMesh.new()
	mesh.radius = 0.014
	mesh.height = 0.028
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = M.mat(FLAME_CORE, 1.5)
	p.mesh = mesh
	return p


# Llama: conos y esferas brillantes con la base en el origen
static func flame(parent: Node3D, h: float, r: float) -> void:
	var outer := M.mat(FLAME, 1.0)
	var core := M.mat(FLAME_CORE, 1.3)
	var red := M.mat(Color(0.9, 0.18, 0.04), 0.9)
	M.sphere(parent, r, red, Vector3(0, r * 0.7, 0), Vector3(1, 0.8, 1), 10)
	M.cyl(parent, 0.0, r * 0.95, h, outer, Vector3(0, r * 0.6 + h * 0.5, 0), Vector3.ZERO, 8)
	M.sphere(parent, r * 0.65, core, Vector3(0, r * 0.75, 0), Vector3.ONE, 8)
	M.cyl(parent, 0.0, r * 0.6, h * 0.6, core, Vector3(0, r * 0.6 + h * 0.3, 0), Vector3.ZERO, 6)
	# lenguas laterales
	for i in 3:
		var a := TAU * i / 3.0
		var tongue := Node3D.new()
		tongue.position = Vector3(cos(a) * r * 0.6, r * 0.6, sin(a) * r * 0.6)
		tongue.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)
		parent.add_child(tongue)
		M.cyl(tongue, 0.0, r * 0.5, h * 0.55, outer, Vector3(0, h * 0.27, 0), Vector3.ZERO, 6)


# --- Torre ---

func _build_tower_tier(parent: Node3D) -> void:
	match _tier:
		0:
			_build_pyre(parent)
		1:
			_build_forge(parent)
		2:
			_build_tower(parent)
		_:
			_build_plinth(parent)
			_build_tower(parent, T3_LIFT)
			_build_majestic(parent)


# --- Etapa 0: pira de troncos apilados en cruz sobre un círculo de piedras ---

func _build_pyre(parent: Node3D) -> void:
	var py := _py
	var log_m := M.mat(Color(0.4, 0.26, 0.15))
	var log_dark := M.mat(Color(0.24, 0.15, 0.09))
	var char_m := M.mat(Color(0.12, 0.09, 0.08))
	var stone := M.mat(Color(0.48, 0.46, 0.45))
	var stone2 := M.mat(Color(0.4, 0.38, 0.38))
	var lava := M.mat(LAVA, 0.9)
	var bone := M.mat(BONE)
	var iron := M.metal(IRON)
	# tierra quemada y círculo de piedras
	M.cyl(parent, 0.44, 0.46, 0.04, M.mat(Color(0.3, 0.24, 0.2)), Vector3(0, 0.02, 0), Vector3.ZERO, 18)
	for i in 12:
		var a := TAU * i / 12.0
		M.sphere(parent, 0.055, stone if i % 2 == 0 else stone2, Vector3(cos(a) * 0.41, 0.05, sin(a) * 0.41), Vector3(1.2, 0.8, 1.0), 8)
	# Pira: troncos cruzados por pares, cada vez con más hollín hacia arriba
	var n := int((py - 0.08) / 0.07)
	for k in n:
		var y := 0.08 + k * 0.07
		var m := log_m if k < n - 2 else log_dark
		for s in [-1.0, 1.0]:
			if k % 2 == 0:
				M.cyl(parent, 0.035, 0.035, 0.6, m, Vector3(0, y, 0.24 * s), Vector3(0, 0, 90), 7)
			else:
				M.cyl(parent, 0.035, 0.035, 0.6, m, Vector3(0.24 * s, y, 0), Vector3(90, 0, 0), 7)
	# relleno de brasas entre los troncos (se ve por los huecos)
	M.box(parent, Vector3(0.42, py - 0.12, 0.42), char_m, Vector3(0, 0.06 + (py - 0.12) / 2.0, 0))
	for p in [Vector3(0.0, 0.2, 0.22), Vector3(0.22, 0.34, 0.0), Vector3(-0.22, 0.27, 0.0), Vector3(0.0, 0.41, -0.22)]:
		M.sphere(parent, 0.04, lava, p, Vector3(1.4, 0.6, 0.4) if absf(p.z) > 0.1 else Vector3(0.4, 0.6, 1.4), 6)
	# Losas de piedra encima: el suelo del sacerdote, con lecho de brasas alrededor
	M.box(parent, Vector3(0.6, 0.05, 0.6), stone2, Vector3(0, py - 0.025, 0))
	var ember := M.mat(Color(1.0, 0.28, 0.04), 0.9)
	for i in 10:
		var a := TAU * i / 10.0
		M.sphere(parent, 0.035, char_m if i % 3 == 0 else ember, Vector3(cos(a) * 0.25, py + 0.005, sin(a) * 0.25), Vector3(1.2, 0.6, 1.2), 6)
	# Calavera de cabra en una estaca y un caldero de hierro junto a la pira
	var sk := Vector3(0.38, 0, 0.18)
	M.cyl(parent, 0.02, 0.025, 0.36, log_dark, sk + Vector3(0, 0.18, 0), Vector3.ZERO, 6)
	M.sphere(parent, 0.05, bone, sk + Vector3(0, 0.38, 0.0), Vector3(0.9, 0.8, 1.1), 10)
	M.box(parent, Vector3(0.05, 0.04, 0.06), bone, sk + Vector3(0, 0.36, 0.05))
	for s in [-1.0, 1.0]:
		M.sphere(parent, 0.012, M.mat(Color(0.08, 0.06, 0.05)), sk + Vector3(0.022 * s, 0.39, 0.045), Vector3.ONE, 6)
		var hn := Node3D.new()
		hn.position = sk + Vector3(0.03 * s, 0.41, -0.01)
		hn.rotation = Vector3(-0.6, 0, -0.5 * s)
		parent.add_child(hn)
		M.cyl(hn, 0.0, 0.016, 0.1, M.mat(BONE_DARK), Vector3(0, 0.05, 0), Vector3.ZERO, 6)
	M.cyl(parent, 0.07, 0.055, 0.08, iron, Vector3(-0.36, 0.08, 0.26), Vector3.ZERO, 10)
	M.cyl(parent, 0.06, 0.06, 0.01, lava, Vector3(-0.36, 0.12, 0.26), Vector3.ZERO, 10)
	# leña de reserva
	for i in 3:
		M.cyl(parent, 0.028, 0.028, 0.22, log_m, Vector3(-0.38, 0.06 + (0.05 if i == 2 else 0.0), -0.3 + i * 0.05 - (0.025 if i == 2 else 0.0)), Vector3(90, 0, 0), 7)


# --- Etapa 1: forja octogonal de basalto tosco, sin calavera ---

func _build_forge(parent: Node3D) -> void:
	var py := _py
	var stone := M.tex_mat("bricks", 2.2, Color(0.46, 0.44, 0.47))
	var basalt := M.mat(BASALT)
	var basalt_l := M.mat(BASALT_LIGHT)
	var iron := M.metal(IRON)
	var lava := M.mat(LAVA, 0.9)
	var crimson := M.mat(CRIMSON)
	var gold := M.metal(GOLD)
	var bone := M.mat(BONE)
	var sh := py - 0.2
	M.cyl(parent, 0.44, 0.46, 0.07, basalt, Vector3(0, 0.035, 0), Vector3(0, 22.5, 0), 8)
	M.cyl(parent, 0.31, 0.37, sh, stone, Vector3(0, 0.07 + sh / 2.0, 0), Vector3(0, 22.5, 0), 8)
	# algunas columnas basálticas detrás
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 6:
		var a := PI + 0.35 + i * 0.45
		var hh := rng.randf_range(0.14, 0.3)
		M.cyl(parent, 0.05, 0.055, hh, basalt if i % 2 == 0 else basalt_l, Vector3(cos(a) * 0.38, 0.07 + hh / 2.0, -absf(sin(a)) * 0.38), Vector3(0, rng.randf() * 60.0, 0), 6)
	# banda de hierro
	var r := 0.355
	M.cyl(parent, r, r, 0.04, iron, Vector3(0, 0.22, 0), Vector3(0, 22.5, 0), 8)
	# boca de la fragua con rejilla
	M.box(parent, Vector3(0.2, 0.18, 0.05), iron, Vector3(0, 0.17, 0.34))
	M.cyl(parent, 0.1, 0.1, 0.05, iron, Vector3(0, 0.26, 0.34), Vector3(90, 0, 0), 14)
	M.box(parent, Vector3(0.15, 0.16, 0.03), lava, Vector3(0, 0.16, 0.355))
	M.cyl(parent, 0.075, 0.075, 0.03, lava, Vector3(0, 0.24, 0.355), Vector3(90, 0, 0), 12)
	for k in 3:
		M.box(parent, Vector3(0.014, 0.22, 0.016), iron, Vector3(-0.045 + k * 0.045, 0.18, 0.375))
	# cráneo de toro sobre la fragua
	var sk := Vector3(0, 0.45, 0.32)
	M.sphere(parent, 0.06, bone, sk, Vector3(1.0, 0.9, 0.8), 10)
	M.box(parent, Vector3(0.06, 0.05, 0.06), bone, sk + Vector3(0, -0.04, 0.04))
	for s in [-1.0, 1.0]:
		M.sphere(parent, 0.014, M.mat(LAVA, 1.4), sk + Vector3(0.025 * s, 0.01, 0.048), Vector3.ONE, 6)
		M.segment(parent, 0.016, M.mat(BONE_DARK), sk + Vector3(0.05 * s, 0.03, 0), sk + Vector3(0.12 * s, 0.09, -0.02), 6)
		M.cyl(parent, 0.0, 0.016, 0.06, bone, sk + Vector3(0.13 * s, 0.13, -0.02), Vector3(0, 0, -15.0 * s), 6)
	# grietas de lava
	for a in [0.9, 2.3, 4.2]:
		var dir := Vector3(cos(a), 0, sin(a))
		var seg := Node3D.new()
		seg.position = dir * 0.345 + Vector3(0, 0.38, 0)
		seg.rotation.y = atan2(dir.x, dir.z)
		parent.add_child(seg)
		M.box(seg, Vector3(0.012, 0.13, 0.012), lava, Vector3.ZERO, Vector3(0, 0, 18))
	# estandarte carmesí en el costado derecho
	var b := Node3D.new()
	b.position = Vector3(0.335, py - 0.4, 0.0)
	b.rotation.y = PI / 2.0
	parent.add_child(b)
	M.box(b, Vector3(0.18, 0.025, 0.03), iron, Vector3(0, 0.16, 0.01))
	M.box(b, Vector3(0.15, 0.3, 0.015), crimson, Vector3(0, 0.0, 0.01))
	M.cyl(b, 0.0, 0.03, 0.08, gold, Vector3(0, 0.03, 0.02), Vector3.ZERO, 6)
	for k in [-1.0, 1.0]:
		M.cyl(b, 0.0, 0.035, 0.05, crimson, Vector3(0.035 * k, -0.17, 0.01), Vector3(180, 0, 0), 4)
	# corona: plato de hierro y anillo bajo con púas
	M.cyl(parent, 0.42, 0.33, 0.1, basalt, Vector3(0, py - 0.1, 0), Vector3(0, 22.5, 0), 8)
	M.cyl(parent, 0.42, 0.42, 0.05, iron, Vector3(0, py - 0.025, 0), Vector3(0, 22.5, 0), 8)
	var coal := M.mat(Color(0.12, 0.08, 0.07))
	var ember := M.mat(Color(1.0, 0.28, 0.04), 0.9)
	for i in 14:
		var a := TAU * i / 14.0
		M.sphere(parent, 0.04, coal if i % 3 == 0 else ember, Vector3(cos(a) * 0.32, py + 0.01, sin(a) * 0.32), Vector3(1.2, 0.6, 1.2), 6)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.39
	ring.outer_radius = 0.415
	ring.rings = 24
	M.add(parent, ring, iron, Vector3(0, py + 0.12, 0))
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		M.segment(parent, 0.014, iron, d * 0.4 + Vector3(0, py, 0), d * 0.405 + Vector3(0, py + 0.12, 0), 6)
		M.cyl(parent, 0.0, 0.02, 0.07, iron, d * 0.405 + Vector3(0, py + 0.16, 0), Vector3.ZERO, 6)
	M.box(parent, Vector3(0.28, 0.03, 0.08), basalt_l, Vector3(0, 0.015, 0.42))


# --- Etapa 3 (Maestría): zócalo de obsidiana con canales de lava y oro ---

func _build_plinth(parent: Node3D) -> void:
	var obsidian := M.mat(Color(0.13, 0.11, 0.14))
	var obs_l := M.mat(Color(0.2, 0.17, 0.21))
	var gold := M.metal(GOLD)
	var lava := M.mat(LAVA, 1.3)
	var lift := T3_LIFT + 0.08
	M.cyl(parent, 0.46, 0.47, 0.06, obs_l, Vector3(0, 0.03, 0), Vector3(0, 22.5, 0), 8)
	M.cyl(parent, 0.41, 0.44, lift, obsidian, Vector3(0, lift / 2.0, 0), Vector3(0, 22.5, 0), 8)
	for y in [0.08, lift - 0.02]:
		M.cyl(parent, 0.44, 0.44, 0.03, gold, Vector3(0, y, 0), Vector3(0, 22.5, 0), 8)
	# canales de lava en las aristas y llamas doradas talladas en las caras
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		M.box(parent, Vector3(0.03, lift - 0.12, 0.03), lava, d * 0.425 + Vector3(0, lift / 2.0, 0))
	for i in 8:
		var a := TAU * i / 8.0
		if absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.3:
			continue
		var d := Vector3(cos(a), 0, sin(a))
		var f := Node3D.new()
		f.position = d * 0.405 + Vector3(0, 0.22, 0)
		f.rotation.y = atan2(d.x, d.z)
		parent.add_child(f)
		M.cyl(f, 0.0, 0.035, 0.1, gold, Vector3(0, 0.03, 0.01), Vector3.ZERO, 6)
		M.sphere(f, 0.035, gold, Vector3(0, -0.02, 0.01), Vector3(1, 1.1, 0.5), 8)
	# puerta de lava al frente con marco de oro
	M.box(parent, Vector3(0.22, 0.24, 0.04), gold, Vector3(0, 0.16, 0.4))
	M.cyl(parent, 0.11, 0.11, 0.04, gold, Vector3(0, 0.28, 0.4), Vector3(90, 0, 0), 16)
	M.box(parent, Vector3(0.17, 0.22, 0.03), lava, Vector3(0, 0.15, 0.412))
	M.cyl(parent, 0.085, 0.085, 0.03, lava, Vector3(0, 0.26, 0.412), Vector3(90, 0, 0), 14)
	for k in 3:
		M.box(parent, Vector3(0.014, 0.26, 0.016), M.metal(IRON), Vector3(-0.045 + k * 0.045, 0.17, 0.428))


# Remates fijos de la Maestría: alas de dragón desplegadas detrás de la corona
func _build_majestic(parent: Node3D) -> void:
	var bone := M.mat(BONE)
	var membrane := M.mat(Color(0.62, 0.08, 0.06))
	var gold := M.metal(GOLD)
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(0.15 * s, _py + 0.12, -0.33)
		w.rotation = Vector3(0.2, -0.35 * s, 0)
		parent.add_child(w)
		# brazo del ala: hombro -> codo -> muñeca
		var elbow := Vector3(0.18 * s, 0.3, 0)
		var wrist := Vector3(0.36 * s, 0.6, 0)
		M.segment(w, 0.03, bone, Vector3.ZERO, elbow, 8)
		M.sphere(w, 0.035, bone, elbow, Vector3.ONE, 8)
		M.segment(w, 0.024, bone, elbow, wrist, 8)
		M.sphere(w, 0.03, gold, wrist, Vector3.ONE, 8)
		M.cyl(w, 0.0, 0.025, 0.09, gold, wrist + Vector3(0, 0.05, 0), Vector3(0, 0, -20.0 * s), 6)
		# dedos y membranas que caen desde la muñeca
		var tips := [Vector3(0.5 * s, 0.22, 0), Vector3(0.38 * s, 0.02, 0), Vector3(0.2 * s, -0.04, 0)]
		var prev := elbow
		for i in tips.size():
			var tip: Vector3 = tips[i]
			M.segment(w, 0.012, bone, tip, wrist, 6)
			# membrana: abanico plano con el vértice en la muñeca y la base entre dos dedos
			var mid := (prev + tip) * 0.5
			var hgt := (wrist - mid).length()
			var rad := maxf((prev - tip).length() / 1.5, 0.08)
			var tri := M.add(w, M.cyl_mesh(0.0, rad, hgt, 3), membrane)
			tri.position = (wrist + mid) * 0.5
			tri.basis = Basis(Quaternion(Vector3.UP, (wrist - mid).normalized())) * Basis.from_scale(Vector3(1, 1, 0.1))
			prev = tip
	# cuernos de oro sobre la calavera y remates dorados en la jaula
	for s in [-1.0, 1.0]:
		var hn := Node3D.new()
		hn.position = Vector3(0.3 * s, 0.95 + T3_LIFT, 0.3)
		hn.rotation = Vector3(0.7, 0, -0.7 * s)
		parent.add_child(hn)
		M.cyl(hn, 0.0, 0.035, 0.22, gold, Vector3(0, 0.11, 0), Vector3.ZERO, 8)


## lift: en la Maestría el cuerpo se eleva sobre el zócalo de obsidiana (las columnas basálticas quedan en el suelo).
func _build_tower(root: Node3D, lift := 0.0) -> void:
	var parent := Node3D.new()
	parent.position.y = lift
	root.add_child(parent)
	var stone := M.tex_mat("bricks", 2.2, Color(0.42, 0.4, 0.44))
	var basalt := M.mat(BASALT)
	var basalt_l := M.mat(BASALT_LIGHT)
	var iron := M.metal(IRON)
	var lava := M.mat(LAVA, 0.9)
	var bone := M.mat(BONE)
	var bone_dark := M.mat(BONE_DARK)
	var gold := M.metal(GOLD)
	var crimson := M.mat(CRIMSON)
	var black := M.mat(Color(0.06, 0.05, 0.05))

	# Zócalo octogonal con grietas de lava
	if lift == 0.0:
		M.cyl(parent, 0.45, 0.47, 0.08, basalt, Vector3(0, 0.04, 0), Vector3(0, 22.5, 0), 8)
		for a in [0.4, 1.3, 2.5, 3.6, 4.4, 5.5]:
			var crack := M.box(parent, Vector3(0.12, 0.012, 0.02), lava, Vector3(cos(a) * 0.4, 0.081, sin(a) * 0.4))
			crack.rotation.y = -a + 0.5
	# Fuste octogonal ahusado de basalto
	M.cyl(parent, 0.32, 0.39, 0.8, stone, Vector3(0, 0.48, 0), Vector3(0, 22.5, 0), 8)
	# Columnas basálticas alrededor de la base (no delante)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 11:
		var a := TAU * i / 11.0 + 0.2
		if absf(wrapf(a - PI / 2.0, -PI, PI)) < 0.6:
			continue
		var hh := rng.randf_range(0.18, 0.4)
		var r := 0.39
		M.cyl(root, 0.055, 0.06, hh + lift, basalt if i % 2 == 0 else basalt_l, Vector3(cos(a) * r * (1.12 if lift > 0.0 else 1.0), 0.08 + (hh + lift) / 2.0, sin(a) * r * (1.12 if lift > 0.0 else 1.0)), Vector3(0, rng.randf() * 60.0, 0), 6)
	# Grietas de lava subiendo por el fuste
	for a in [0.6, 2.5, 3.9, 5.2]:
		var dir := Vector3(cos(a), 0, sin(a))
		var y0 := rng.randf_range(0.3, 0.5)
		var r0 := lerpf(0.36, 0.32, y0)
		var seg := Node3D.new()
		seg.position = dir * (r0 + 0.004) + Vector3(0, y0, 0)
		seg.rotation.y = atan2(dir.x, dir.z)
		parent.add_child(seg)
		M.box(seg, Vector3(0.012, 0.14, 0.012), lava, Vector3(0, 0, 0), Vector3(0, 0, 18))
		M.box(seg, Vector3(0.01, 0.1, 0.012), lava, Vector3(0.03, 0.13, -0.004), Vector3(0, 0, -20))
	# Bandas de hierro remachadas
	for y in [0.2, 0.84]:
		var r := lerpf(0.39, 0.32, (y - 0.08) / 0.8) + 0.012
		M.cyl(parent, r, r, 0.045, iron, Vector3(0, y, 0), Vector3(0, 22.5, 0), 8)
		for i in 8:
			var a := TAU * i / 8.0
			M.sphere(parent, 0.014, gold, Vector3(cos(a) * r * 0.97, y, sin(a) * r * 0.97), Vector3.ONE, 6)

	# Estandartes carmesí con llama dorada en los costados (±X)
	for s in [-1.0, 1.0]:
		var b := Node3D.new()
		b.position = Vector3(0.33 * s, 0.55, 0.0)
		b.rotation.y = PI / 2.0 * s
		parent.add_child(b)
		M.box(b, Vector3(0.2, 0.025, 0.03), iron, Vector3(0, 0.18, 0.01))
		M.box(b, Vector3(0.16, 0.34, 0.015), crimson, Vector3(0, 0.0, 0.01))
		M.box(b, Vector3(0.17, 0.02, 0.02), gold, Vector3(0, -0.05, 0.012))
		for k in [-1.0, 1.0]:
			M.cyl(b, 0.0, 0.04, 0.06, crimson, Vector3(0.04 * k, -0.2, 0.01), Vector3(180, 0, 0), 4)
		M.cyl(b, 0.0, 0.035, 0.09, gold, Vector3(0, 0.06, 0.02), Vector3(0, 0, 0), 6)
		M.cyl(b, 0.0, 0.02, 0.06, gold, Vector3(-0.03, 0.03, 0.02), Vector3(0, 0, 25), 5)
		M.cyl(b, 0.0, 0.02, 0.06, gold, Vector3(0.03, 0.03, 0.02), Vector3(0, 0, -25), 5)

	# Ventanas-aspillera con resplandor (atrás y diagonales traseras)
	for a in [-PI / 2.0, -PI / 4.0, -3.0 * PI / 4.0]:
		var dir := Vector3(cos(a), 0, sin(a))
		var w := Node3D.new()
		w.position = dir * 0.31 + Vector3(0, 0.6, 0)
		w.rotation.y = atan2(dir.x, dir.z)
		parent.add_child(w)
		M.box(w, Vector3(0.07, 0.16, 0.04), black)
		M.box(w, Vector3(0.04, 0.13, 0.04), lava, Vector3(0, 0, 0.008))
		M.box(w, Vector3(0.1, 0.03, 0.05), basalt_l, Vector3(0, -0.09, 0.01))

	# Calavera de dragón al frente (+Z): su boca es la boca de la fragua
	_dragon_skull(parent, Vector3(0, 0.5, 0.33), bone, bone_dark, lava, black)
	if lift == 0.0:
		# Puerta de la fragua bajo la calavera, con rejilla y brasas
		M.box(parent, Vector3(0.22, 0.2, 0.05), iron, Vector3(0, 0.19, 0.355))
		M.cyl(parent, 0.11, 0.11, 0.05, iron, Vector3(0, 0.29, 0.355), Vector3(90, 0, 0), 16)
		M.box(parent, Vector3(0.17, 0.18, 0.03), lava, Vector3(0, 0.18, 0.37))
		M.cyl(parent, 0.085, 0.085, 0.03, lava, Vector3(0, 0.27, 0.37), Vector3(90, 0, 0), 14)
		for k in 4:
			M.box(parent, Vector3(0.014, 0.26, 0.016), iron, Vector3(-0.06 + k * 0.04, 0.2, 0.39))
		M.box(parent, Vector3(0.3, 0.03, 0.08), basalt_l, Vector3(0, 0.015, 0.42))
		for x in [-0.06, 0.0, 0.06]:
			M.sphere(parent, 0.02, lava, Vector3(x, 0.035, 0.4), Vector3(1, 0.5, 1), 6)

	# Corona del brasero: ménsulas, plato de hierro y jaula
	M.cyl(parent, 0.44, 0.33, 0.12, basalt, Vector3(0, 0.92, 0), Vector3(0, 22.5, 0), 8)
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var cb := M.box(parent, Vector3(0.06, 0.1, 0.06), basalt_l, Vector3(cos(a) * 0.34, 0.84, sin(a) * 0.34))
		cb.rotation.y = PI / 2.0 - a
	M.cyl(parent, 0.44, 0.44, 0.06, iron, Vector3(0, 1.01, 0), Vector3(0, 22.5, 0), 8)
	# lecho de brasas alrededor del sacerdote
	var coal := M.mat(Color(0.12, 0.08, 0.07))
	var ember := M.mat(Color(1.0, 0.28, 0.04), 0.9)
	for i in 16:
		var a := TAU * i / 16.0
		var r := 0.33 + (i % 2) * 0.03
		M.sphere(parent, 0.04, coal if i % 3 == 0 else ember, Vector3(cos(a) * r, PLATFORM_Y + 0.01, sin(a) * r), Vector3(1.2, 0.6, 1.2), 6)
	var cage := M.metal(IRON) if lift == 0.0 else M.metal(GOLD)
	# barrotes curvos de la jaula con púas
	var ring := TorusMesh.new()
	ring.inner_radius = 0.43
	ring.outer_radius = 0.455
	ring.rings = 24
	M.add(parent, ring, cage, Vector3(0, PLATFORM_Y + 0.3, 0))
	var ring2 := TorusMesh.new()
	ring2.inner_radius = 0.4
	ring2.outer_radius = 0.425
	ring2.rings = 24
	M.add(parent, ring2, iron, Vector3(0, PLATFORM_Y + 0.08, 0))
	for i in 8:
		var a := TAU * i / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		var p0 := d * 0.41 + Vector3(0, PLATFORM_Y, 0)
		var p1 := d * 0.44 + Vector3(0, PLATFORM_Y + 0.3, 0)
		M.segment(parent, 0.016, iron, p0, p1, 6)
		M.cyl(parent, 0.0, 0.022, 0.09, cage, p1 + Vector3(0, 0.04, 0) + d * 0.005, Vector3.ZERO, 6)
	# Cuernos de hierro en las diagonales delanteras de la corona
	for s in [-1.0, 1.0]:
		var hn := Node3D.new()
		hn.position = Vector3(0.3 * s, 0.95, 0.3)
		hn.rotation = Vector3(0.7, 0, -0.7 * s)
		parent.add_child(hn)
		M.cyl(hn, 0.0, 0.03, 0.14, bone_dark, Vector3(0, 0.07, 0), Vector3.ZERO, 8)


# Calavera de dragón: cráneo, hocico con dientes, cuencas brillantes, mandíbula y cuernos curvos
static func _dragon_skull(parent: Node3D, at: Vector3, bone: Material, bone_dark: Material, lava: Material, black: Material) -> void:
	# cráneo y cresta
	M.sphere(parent, 0.11, bone, at + Vector3(0, 0.07, 0.0), Vector3(1.15, 0.85, 0.9), 14)
	M.box(parent, Vector3(0.05, 0.06, 0.12), bone_dark, at + Vector3(0, 0.15, -0.01), Vector3(-15, 0, 0))
	# hocico alargado
	M.box(parent, Vector3(0.14, 0.07, 0.12), bone, at + Vector3(0, 0.04, 0.1), Vector3(8, 0, 0))
	M.box(parent, Vector3(0.11, 0.05, 0.06), bone, at + Vector3(0, 0.035, 0.155), Vector3(14, 0, 0))
	for s in [-1.0, 1.0]:
		M.sphere(parent, 0.012, black, at + Vector3(0.025 * s, 0.055, 0.185), Vector3(1, 0.7, 0.6), 6)
		# cuencas con brasas
		M.sphere(parent, 0.033, black, at + Vector3(0.052 * s, 0.085, 0.07), Vector3(1.2, 0.8, 0.6), 8)
		M.sphere(parent, 0.016, lava, at + Vector3(0.052 * s, 0.083, 0.088), Vector3.ONE, 6)
		# pómulos
		M.sphere(parent, 0.03, bone_dark, at + Vector3(0.09 * s, 0.03, 0.05), Vector3(1, 0.7, 1.3), 8)
		# dientes superiores
		for k in 3:
			M.cyl(parent, 0.0, 0.011, 0.04, bone, at + Vector3(0.05 * s, -0.005, 0.07 + k * 0.035), Vector3(180, 0, 0), 5)
		# cuerno curvado hacia atrás y arriba
		var pts := [at + Vector3(0.09 * s, 0.11, -0.01), at + Vector3(0.16 * s, 0.16, -0.02),
				at + Vector3(0.21 * s, 0.24, -0.04), at + Vector3(0.22 * s, 0.33, -0.08)]
		var radii := [0.032, 0.025, 0.018]
		for k in 3:
			var a: Vector3 = pts[k]
			var b: Vector3 = pts[k + 1]
			M.segment(parent, radii[k], bone_dark if k == 1 else bone, a, b, 8)
			M.sphere(parent, radii[k], bone_dark if k == 1 else bone, b, Vector3.ONE, 8)
		var tip := Node3D.new()
		tip.position = pts[3]
		tip.rotation = Vector3(-0.4, 0, -0.15 * s)
		parent.add_child(tip)
		M.cyl(tip, 0.0, 0.018, 0.07, bone, Vector3(0, 0.035, 0), Vector3.ZERO, 6)
	# fauces abiertas con fuego dentro y mandíbula inferior
	M.box(parent, Vector3(0.1, 0.06, 0.1), lava, at + Vector3(0, -0.035, 0.09))
	M.box(parent, Vector3(0.13, 0.04, 0.13), bone, at + Vector3(0, -0.08, 0.1), Vector3(-10, 0, 0))
	for s in [-1.0, 1.0]:
		for k in 2:
			M.cyl(parent, 0.0, 0.01, 0.035, bone, at + Vector3(0.045 * s, -0.05, 0.1 + k * 0.04), Vector3.ZERO, 5)


# Llamas del brasero (animadas)
func _build_flames() -> void:
	var spots := [[Vector3(0.0, 0, 0.33), 1.05], [Vector3(-0.3, 0, 0.17), 1.0], [Vector3(0.3, 0, 0.17), 1.0],
			[Vector3(-0.34, 0, -0.08), 0.85], [Vector3(0.34, 0, -0.08), 0.85], [Vector3(-0.22, 0, -0.27), 0.7],
			[Vector3(0.22, 0, -0.27), 0.7]]
	match _tier:
		0:
			spots = [[Vector3(-0.2, 0, -0.16), 0.6], [Vector3(0.2, 0, -0.16), 0.6], [Vector3(0.0, 0, -0.25), 0.7]]
		1:
			spots = [[Vector3(-0.28, 0, 0.12), 0.8], [Vector3(0.28, 0, 0.12), 0.8], [Vector3(-0.3, 0, -0.12), 0.75],
					[Vector3(0.3, 0, -0.12), 0.75], [Vector3(0.0, 0, -0.3), 0.85]]
		3:
			for sp in spots:
				var e: Array = sp
				e[1] = float(e[1]) * 1.25
	for sp in spots:
		var p: Vector3 = sp[0]
		var base: float = sp[1]
		var f := Node3D.new()
		f.position = p + Vector3(0, _py + 0.01, 0)
		add_child(f)
		flame(f, 0.24, 0.075)
		_flames.append(f)
		_flame_base.append(base)


# --- Sacerdote del fuego ---

func _build_human_body(c: Node3D) -> void:
	var robe := M.mat([Color(0.42, 0.24, 0.16), ROBE, ROBE, Color(0.62, 0.08, 0.06)][_tier])
	var robe_dark := M.mat([Color(0.3, 0.17, 0.11), ROBE_DARK, ROBE_DARK, Color(0.16, 0.04, 0.04)][_tier])
	var gold := M.metal(GOLD) if _tier > 0 else M.mat(Color(0.5, 0.36, 0.2))
	var black := M.mat(Color(0.1, 0.08, 0.08))
	Human.body(c, robe, gold)
	# túnica larga hasta el suelo con franja frontal negra y llamas doradas
	M.cyl(c, 0.15, 0.2, 0.1, robe, Vector3(0, 0.03, 0), Vector3.ZERO, 16)
	M.box(c, Vector3(0.07, 0.3, 0.03), black, Vector3(0, 0.13, -0.135), Vector3(-6, 0, 0))
	for k in 3:
		M.cyl(c, 0.0, 0.018, 0.05, gold, Vector3(0, 0.05 + k * 0.08, -0.155), Vector3(-6, 0, 0), 5)
	M.cyl(c, 0.153, 0.153, 0.03, black, Vector3(0, 0.15, 0), Vector3.ZERO, 16)
	M.cyl(c, 0.03, 0.03, 0.015, gold, Vector3(0, 0.15, -0.153), Vector3(90, 0, 0), 12)
	M.sphere(c, 0.012, M.mat(LAVA, 1.5), Vector3(0, 0.15, -0.162), Vector3.ONE, 6)
	# esclavina con capucha puntiaguda
	M.cyl(c, 0.12, 0.19, 0.11, robe_dark, Vector3(0, 0.3, 0.01), Vector3.ZERO, 16)
	var h := Human.head(c, false, false)
	M.sphere(h, 0.152, robe_dark, Vector3(0, 0.035, 0.035), Vector3(1.1, 1.1, 1.0), 14)
	var hood_tip := Node3D.new()
	hood_tip.position = Human.HEAD + Vector3(0, 0.1, 0.09)
	hood_tip.rotation = Vector3(-0.8, 0, 0)
	c.add_child(hood_tip)
	M.cyl(hood_tip, 0.0, 0.09, 0.18, robe_dark, Vector3(0, 0.08, 0), Vector3.ZERO, 10)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.1
	rim.outer_radius = 0.125
	M.add(h, rim, robe, Vector3(0, 0.0, -0.1), Vector3(90, 0, 0), Vector3(1.0, 1.0, 1.25))
	# pintura ritual en la frente y perilla
	M.box(h, Vector3(0.012, 0.035, 0.01), M.mat(LAVA, 1.2), Vector3(0, 0.06, -0.135))
	M.cyl(h, 0.0, 0.025, 0.06, M.mat(Color(0.18, 0.1, 0.08)), Vector3(0, -0.12, -0.11), Vector3(170, 0, 0), 8)
	if _tier == 3:
		# corona de cuernos dorados sobre la capucha y hombreras de escamas de oro
		for i in 6:
			var a := PI * (0.15 + 0.7 * i / 5.0)
			var hp := Human.HEAD + Vector3(cos(a) * 0.13, 0.13 + sin(a) * 0.03, -sin(a) * 0.06)
			var hn := Node3D.new()
			hn.position = hp
			hn.rotation = Vector3(-0.2, 0, (a - PI / 2.0) * 0.8)
			c.add_child(hn)
			M.cyl(hn, 0.0, 0.02, 0.09 if i % 2 == 0 else 0.06, gold, Vector3(0, 0.04, 0), Vector3.ZERO, 6)
		M.sphere(c, 0.022, M.mat(LAVA, 1.8), Human.HEAD + Vector3(0, 0.12, -0.13), Vector3(1, 1.2, 0.6), 8)
		for s in [-1.0, 1.0]:
			M.sphere(c, 0.075, gold, Vector3(0.14 * s, 0.29, 0), Vector3(1.0, 0.6, 1.0), 12)
			M.cyl(c, 0.0, 0.025, 0.07, gold, Vector3(0.17 * s, 0.33, 0.0), Vector3(0, 0, -40.0 * s), 6)
	# brazo derecho al báculo y brazo izquierdo con la palma en alto
	Human.arm(c, Human.R_SHOULDER, STAFF_HAND, robe, gold)
	Human.arm(c, Human.L_SHOULDER, LEFT_HAND, robe, gold)


func _build_human_parts() -> void:
	var c := cat_pivot
	_staff = Node3D.new()
	_staff.position = STAFF_HAND
	c.add_child(_staff)
	var wood := M.mat(Color(0.22, 0.13, 0.08) if _tier < 3 else Color(0.1, 0.08, 0.1))
	var iron := M.metal(IRON) if _tier < 3 else M.metal(GOLD)
	var gold := M.metal(GOLD) if _tier > 0 else M.mat(Color(0.5, 0.36, 0.2))
	var bone := M.mat(BONE)
	M.segment(_staff, 0.018, wood, Vector3(0, -0.26, 0), Vector3(0, 0.4, 0), 8)
	for y in [0.0, 0.3]:
		M.cyl(_staff, 0.024, 0.024, 0.03, gold, Vector3(0, y, 0), Vector3.ZERO, 8)
	# cabeza de dragón de hierro mirando hacia delante (-Z), con fuego en las fauces
	var hd := STAFF_HEAD
	M.sphere(_staff, 0.045, iron, hd + Vector3(0, -0.02, 0.02), Vector3(1, 1, 1.1), 10)
	M.box(_staff, Vector3(0.05, 0.035, 0.08), iron, hd + Vector3(0, 0.0, -0.05), Vector3(-10, 0, 0))
	M.box(_staff, Vector3(0.045, 0.02, 0.06), iron, hd + Vector3(0, -0.04, -0.04), Vector3(15, 0, 0))
	for s in [-1.0, 1.0]:
		M.sphere(_staff, 0.012, M.mat(LAVA, 2.0), hd + Vector3(0.026 * s, 0.018, -0.03), Vector3.ONE, 6)
		var horn := Node3D.new()
		horn.position = hd + Vector3(0.025 * s, 0.03, 0.03)
		horn.rotation = Vector3(0.9, 0, -0.35 * s)
		_staff.add_child(horn)
		M.cyl(horn, 0.0, 0.014, 0.08, bone, Vector3(0, 0.04, 0), Vector3.ZERO, 6)
	M.box(_staff, Vector3(0.012, 0.04, 0.07), M.metal(GOLD), hd + Vector3(0, 0.04, 0.03))
	_staff_fire = Node3D.new()
	_staff_fire.position = hd + Vector3(0, -0.01, -0.12)
	_staff.add_child(_staff_fire)
	M.sphere(_staff_fire, 0.045, M.mat(FLAME, 1.2), Vector3.ZERO, Vector3.ONE, 10)
	M.sphere(_staff_fire, 0.028, M.mat(FLAME_CORE, 1.5), Vector3(0, 0, -0.01), Vector3.ONE, 8)
	M.cyl(_staff_fire, 0.0, 0.035, 0.08, M.mat(FLAME, 1.0), Vector3(0, 0.05, 0), Vector3.ZERO, 6)
	# llamita sobre la palma izquierda
	_hand_fire = Node3D.new()
	_hand_fire.position = LEFT_HAND + Vector3(0, 0.04, 0)
	c.add_child(_hand_fire)
	flame(_hand_fire, 0.08, 0.03)
