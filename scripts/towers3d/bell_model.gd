extends Node3D
## Modelo 3D del "Campanario" (id bell): torre de apoyo que tañe una campana santa que acelera
## a las torres vecinas y hace un pequeño daño sagrado.
## Sobre la torre se alza una espadaña (dos pilares con un arco) de la que cuelga una gran
## campana de bronce con su rueda; un monje campanero tira de la cuerda (con su "sally" de lana
## a rayas) y la campana se balancea al tocar, soltando ondas doradas de sonido.
## Etapas:
##   0 (nv 0-1): caballete de troncos con plataforma de tablones; horca de madera con tejadillo
##               y campana con pátina verde. Monje con hábito pardo y tonsura.
##   1 (nv 2-3): torre de sillares con ventanas de arco y lamas, parapeto almenado; espadaña de
##               piedra con arco de dovelas y tejadillo de pizarra con cruz de hierro.
##   2 (nv 4):   torre grande con contrafuertes, ventanas geminadas, pináculos, estandartes y
##               antorchas; arco de dovelas rojas y blancas, campana con bandas doradas y un
##               suave brillo dorado.
##   3 (nv 5):   Maestría: mármol blanco, oro y azul real, ventanas que brillan, frontón con
##               cruz radiante, campana dorada que resplandece, anillo de aura, destellos y
##               campanitas de oro flotando.
## Todo el conjunto de la espadaña, la campana y el monje va dentro de cat_pivot (mira a -Z).

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")
const Arch := preload("res://scripts/towers3d/archer_model.gd")

const STONE_DARK := Color(0.42, 0.4, 0.38)
const TIMBER := Color(0.3, 0.19, 0.1)
const IRON := Color(0.26, 0.26, 0.29)
const BRONZE := Color(0.74, 0.5, 0.24)
const BRONZE_DARK := Color(0.5, 0.33, 0.16)
const VERDIGRIS := Color(0.36, 0.62, 0.5)
const GOLD := Color(0.95, 0.75, 0.3)
const GOLD_BRIGHT := Color(1.0, 0.84, 0.42)
const HOLY := Color(1.0, 0.86, 0.45)
const MARBLE := Color(0.97, 0.95, 0.9)
const ROYAL := Color(0.16, 0.26, 0.62)
const RED := Color(0.72, 0.14, 0.12)
const WHITE := Color(0.95, 0.93, 0.88)
const ROPE := Color(0.84, 0.75, 0.56)
const SLATE := Color(0.5, 0.55, 0.68)

# Altura de la plataforma por etapa (la espadaña y el monje van encima)
const PLAT_BY_TIER := [0.42, 0.56, 0.66, 0.72]
const PIV := 0.86             # eje de la campana sobre la plataforma
const YS := PIV + 0.02        # arranque del arco de la espadaña
const PILLAR_X := 0.285       # centro de los pilares
const ARCH_RI := 0.235        # radio interior del arco
const ARCH_RO := 0.295        # radio exterior del arco
const WHEEL_X := 0.19         # plano de la rueda de la campana
const WHEEL_R := 0.118
const MAN_POS := Vector3(0.05, 0.0, -0.1)
const MAN_SCALE := 0.8
const ROPE_GAIN := 2.2        # recorrido de la cuerda por radián de giro (exagerado para que se lea)
const HAND_REST_Y := 0.56
const COIL := Vector3(0.2, 0.03, -0.3)

var cat_pivot: Node3D
var tier := 0
var _bell: Node3D
var _clapper: Node3D
var _man: Node3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _hand_l: MeshInstance3D
var _hand_r: MeshInstance3D
var _rope: MeshInstance3D
var _sally: Node3D
var _tail: MeshInstance3D
var _waves: Array[MeshInstance3D] = []
var _wave_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _light: OmniLight3D
var _halo: Node3D
var _flames: Array[Node3D] = []
var _pennants: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _floaters: Array[Node3D] = []


func _init(level := 0) -> void:
	tier = Arch.tier_of(level)
	M.add_baked(self, M.baked("bell_tower_t%d" % tier, _build_tower))
	cat_pivot = Node3D.new()
	cat_pivot.position = Vector3(0, PLAT_BY_TIER[tier], 0)
	add_child(cat_pivot)
	M.add_baked(cat_pivot, M.baked("bell_frame_t%d" % tier, _build_frame))
	_man = Node3D.new()
	_man.position = MAN_POS
	_man.scale = Vector3.ONE * MAN_SCALE
	cat_pivot.add_child(_man)
	M.add_baked(_man, M.baked("bell_man_t%d" % tier, _build_man))
	if tier == 3:
		_build_halo()
	_bell = Node3D.new()
	_bell.position = Vector3(0, PIV, 0)
	cat_pivot.add_child(_bell)
	_build_glow_mat()
	M.add_baked(_bell, M.baked("bell_bell_t%d" % tier, _build_bell))
	# Disco de la boca de la campana (brilla por dentro en las etapas altas)
	M.cyl(_bell, 0.148, 0.148, 0.01, _glow_mat, Vector3(0, -0.284, 0), Vector3.ZERO, 18)
	_clapper = Node3D.new()
	_clapper.position = Vector3(0, -0.05, 0)
	_bell.add_child(_clapper)
	M.segment(_clapper, 0.011, M.metal(IRON), Vector3.ZERO, Vector3(0, -0.2, 0), 6)
	M.sphere(_clapper, 0.033, M.metal(IRON if tier < 3 else GOLD), Vector3(0, -0.215, 0), Vector3(1, 1.15, 1), 10)
	_build_moving_parts()
	_build_tier_fx()
	animate({"t": 0.0, "charge": 0.0, "fire": 0.0, "has_target": false})


## s = {t, charge (0..1), fire (1 -> 0), has_target}
func animate(s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = clampf(s.get("charge", 0.0), 0.0, 1.0)
	var fire: float = clampf(s.get("fire", 0.0), 0.0, 1.0)
	var has_target: bool = s.get("has_target", false)
	var pull := charge if has_target else minf(charge, 0.3)
	# Balanceo: al cargar el monje tira y la boca se va hacia atrás; al tocar, la campana
	# se lanza hacia el objetivo y oscila amortiguándose.
	var swing := -0.42 * pull * (1.0 - fire)
	swing += 0.85 * fire * cos((1.0 - fire) * 10.0)
	swing += sin(t * 1.6) * 0.025
	_bell.rotation.x = swing
	# El badajo se retrasa y golpea el borde
	_clapper.rotation.x = clampf(-swing * 0.9 + sin(t * 23.0) * 0.08 * fire, -0.42, 0.42)
	# Cuerda: baja y sube con la rueda; las manos la siguen
	var top := Vector3(WHEEL_X, PIV, -WHEEL_R)
	var hy := clampf(HAND_REST_Y + swing * WHEEL_R * ROPE_GAIN, 0.3, 0.72)
	var hand_hi := Vector3(0.165, hy, -0.2)
	var hand_lo := Vector3(0.158, hy - 0.11, -0.205)
	var sally_end := hand_hi + Vector3(0.0, -0.17, -0.005)
	M.orient_segment(_rope, top, hand_hi + Vector3(0, 0.02, 0))
	M.orient_segment(_sally, sally_end, hand_hi + Vector3(0, 0.02, 0))
	M.orient_segment(_tail, COIL, sally_end)
	_hand_r.position = hand_hi
	_hand_l.position = hand_lo
	# El monje se agacha un poco al tirar
	_man.position = MAN_POS + Vector3(0, -pull * 0.025 + absf(sin(t * 1.4)) * 0.004, 0)
	_man.rotation.x = -pull * 0.06 + fire * 0.05
	M.orient_segment(_arm_r, _man.transform * Human.R_SHOULDER, hand_hi)
	M.orient_segment(_arm_l, _man.transform * Human.L_SHOULDER, hand_lo)
	# Ondas sagradas de sonido que se expanden al tocar
	for i in _waves.size():
		var w := _waves[i]
		var ph := clampf((1.0 - fire) * 1.15 - i * 0.22, 0.0, 1.0)
		w.visible = fire > 0.0 and ph > 0.0 and ph < 1.0
		w.scale = Vector3.ONE * (0.8 + ph * 2.4)
	_wave_mat.albedo_color.a = 0.55 * fire
	# Brillo dorado (etapas 2 y 3)
	var glow := 0.0
	if tier >= 2:
		glow = (0.9 if tier == 2 else 1.6) + charge * 0.6 + fire * 2.5 + sin(t * 3.0) * 0.15
		_glow_mat.emission_energy_multiplier = glow
	if _light:
		_light.light_energy = (0.35 if tier == 2 else 0.7) + charge * 0.3 + fire * 1.6
	if _halo:
		_halo.rotation.z = t * 0.6
	Arch.animate_fx(t, _flames, _pennants, _spinners, _floaters)


## Centro de la campana (posición global): de aquí sale el proyectil sagrado
func muzzle_global() -> Vector3:
	return _bell.to_global(Vector3(0, -0.17, 0))


# =====================================================================
# --- Campana (gira con _bell alrededor del eje X) ---
# =====================================================================

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


func _build_bell(b: Node3D) -> void:
	var body: Material = [M.metal(Color(0.62, 0.44, 0.24)), M.metal(BRONZE), M.metal(Color(0.8, 0.56, 0.26)), M.metal(GOLD_BRIGHT)][tier]
	var band: Material = [M.metal(BRONZE_DARK), M.metal(BRONZE_DARK), M.metal(GOLD), M.mat(ROYAL)][tier]
	var dots: Material = [M.mat(VERDIGRIS), M.metal(GOLD), M.metal(GOLD_BRIGHT), M.mat(HOLY, 1.4)][tier]
	var iron := M.metal(IRON)
	var wood := M.tex_mat("wood", 2.0, Color(0.62, 0.46, 0.32))
	var stock: Material = wood if tier < 3 else M.mat(ROYAL)
	var trim: Material = iron if tier < 2 else M.metal(GOLD)
	# Cepo (yugo de madera) con el eje y abrazaderas
	M.box(b, Vector3(0.36, 0.065, 0.075), stock, Vector3(0, 0.03, 0))
	for sx: float in [-1.0, 1.0]:
		M.box(b, Vector3(0.025, 0.075, 0.085), trim, Vector3(0.12 * sx, 0.03, 0))
		M.cyl(b, 0.016, 0.016, 0.07, iron, Vector3(0.205 * sx, 0.02, 0), Vector3(0, 0, 90), 8)
		M.box(b, Vector3(0.02, 0.08, 0.09), iron, Vector3(0.04 * sx, -0.015, 0))
	if tier == 3:
		M.box(b, Vector3(0.37, 0.012, 0.08), M.metal(GOLD), Vector3(0, 0.068, 0))
		M.sphere(b, 0.02, M.metal(GOLD), Vector3(0, 0.08, 0), Vector3.ONE, 8)
	# Cuerpo de la campana: cabeza, hombro, tercio, medio pie y labio
	M.sphere(b, 0.085, body, Vector3(0, -0.058, 0), Vector3(1, 0.55, 1), 16)
	M.cyl(b, 0.075, 0.095, 0.06, body, Vector3(0, -0.075, 0), Vector3.ZERO, 18)
	M.cyl(b, 0.095, 0.105, 0.08, body, Vector3(0, -0.14, 0), Vector3.ZERO, 18)
	M.cyl(b, 0.105, 0.15, 0.08, body, Vector3(0, -0.215, 0), Vector3.ZERO, 20)
	M.cyl(b, 0.15, 0.168, 0.04, body, Vector3(0, -0.272, 0), Vector3.ZERO, 20)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.148
	lip.outer_radius = 0.174
	lip.rings = 24
	M.add(b, lip, body, Vector3(0, -0.29, 0))
	# Bandas decorativas y relieves (inscripción)
	M.cyl(b, 0.088, 0.088, 0.014, band, Vector3(0, -0.06, 0), Vector3.ZERO, 18)
	M.cyl(b, 0.103, 0.103, 0.016, band, Vector3(0, -0.168, 0), Vector3.ZERO, 18)
	M.cyl(b, 0.155, 0.155, 0.014, band, Vector3(0, -0.258, 0), Vector3.ZERO, 20)
	for k in 10:
		var a := TAU * k / 10.0
		M.sphere(b, 0.009, dots, Vector3(cos(a) * 0.1, -0.11, sin(a) * 0.1), Vector3(1, 1.3, 0.7), 6)
	# Cruz en relieve en las dos caras
	for sz: float in [-1.0, 1.0]:
		var cm: Material = dots if tier > 0 else band
		M.box(b, Vector3(0.016, 0.06, 0.012), cm, Vector3(0, -0.205, 0.123 * sz), Vector3(-17.0 * sz, 0, 0))
		M.box(b, Vector3(0.045, 0.014, 0.012), cm, Vector3(0, -0.195, 0.12 * sz), Vector3(-17.0 * sz, 0, 0))
	if tier == 0:
		# pátina verde
		for k in 6:
			var a := TAU * k / 6.0 + 0.4
			M.sphere(b, 0.025, M.mat(VERDIGRIS), Vector3(cos(a) * 0.123, -0.2 - (k % 2) * 0.04, sin(a) * 0.123), Vector3(1, 1.4, 0.4), 6)
	if tier == 3:
		# corona de lises doradas sobre el hombro
		for k in 8:
			var a := TAU * k / 8.0
			M.cyl(b, 0.0, 0.014, 0.035, M.metal(GOLD), Vector3(cos(a) * 0.088, -0.03, sin(a) * 0.088), Vector3.ZERO, 4)
	# Rueda de la campana (en el plano YZ, gira con ella)
	var rim: Material = wood if tier < 3 else M.metal(GOLD)
	var spoke: Material = M.mat(TIMBER) if tier < 3 else M.mat(ROYAL)
	var ring := TorusMesh.new()
	ring.inner_radius = WHEEL_R - 0.014
	ring.outer_radius = WHEEL_R + 0.008
	ring.rings = 28
	M.add(b, ring, rim, Vector3(WHEEL_X, 0, 0), Vector3(0, 0, 90))
	for k in 4:
		M.box(b, Vector3(0.016, WHEEL_R * 2.0 - 0.02, 0.016), spoke, Vector3(WHEEL_X, 0, 0), Vector3(45.0 * k, 0, 0))
	M.cyl(b, 0.03, 0.03, 0.04, trim, Vector3(WHEEL_X, 0, 0), Vector3(0, 0, 90), 10)
	# tramo de cuerda en la garganta de la rueda (cuarto delantero inferior)
	for k in 5:
		var a := PI * 0.5 * k / 4.0
		M.sphere(b, 0.011, M.mat(ROPE), Vector3(WHEEL_X + 0.012, -sin(a) * WHEEL_R, -cos(a) * WHEEL_R), Vector3.ONE, 6)


# =====================================================================
# --- Espadaña / horca de la campana (dentro de cat_pivot) ---
# =====================================================================

func _build_frame(p: Node3D) -> void:
	var iron := M.metal(IRON)
	# Cojinetes del eje en los pilares
	for sx: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.04, 0.06, 0.07), iron if tier < 3 else M.metal(GOLD), Vector3((PILLAR_X - 0.06) * sx, PIV + 0.02, 0))
	# Rollo de cuerda en el suelo
	var coil := TorusMesh.new()
	coil.inner_radius = 0.025
	coil.outer_radius = 0.05
	M.add(p, coil, M.mat(ROPE), COIL + Vector3(0, -0.015, 0))
	M.add(p, coil, M.mat(ROPE), COIL + Vector3(0.01, 0.0, 0.005), Vector3(0, 30, 0))
	if tier == 0:
		_frame_wood(p)
	else:
		_frame_stone(p)


# Etapa 0: horca de troncos con tornapuntas y tejadillo de tablas
func _frame_wood(p: Node3D) -> void:
	var bark := M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36))
	var dark := M.mat(Color(0.4, 0.26, 0.15))
	var plank := M.tex_mat("wood", 2.0, Color(0.8, 0.64, 0.46))
	var rope := M.mat(ROPE)
	for sx: float in [-1.0, 1.0]:
		var x := PILLAR_X * sx
		M.cyl(p, 0.034, 0.04, PIV + 0.12, bark, Vector3(x, (PIV + 0.12) * 0.5, 0), Vector3.ZERO, 8)
		# tornapuntas hacia delante, atrás y fuera
		M.segment(p, 0.02, bark, Vector3(x, 0.0, 0.22), Vector3(x, 0.42, 0.0), 6)
		M.segment(p, 0.02, bark, Vector3(x, 0.0, -0.22), Vector3(x, 0.42, 0.0), 6)
		M.segment(p, 0.018, dark, Vector3(x * 1.25, 0.0, 0.0), Vector3(x, 0.3, 0.0), 6)
		M.cyl(p, 0.045, 0.045, 0.025, rope, Vector3(x, 0.42, 0), Vector3.ZERO, 8)
		M.box(p, Vector3(0.09, 0.03, 0.09), dark, Vector3(x, 0.015, 0))
	# travesaño y tejadillo a dos aguas
	M.box(p, Vector3(0.7, 0.05, 0.06), dark, Vector3(0, PIV + 0.12, 0))
	for sz: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.76, 0.022, 0.17), plank, Vector3(0, PIV + 0.19, 0.065 * sz), Vector3(-34.0 * sz, 0, 0))
	M.box(p, Vector3(0.78, 0.03, 0.03), dark, Vector3(0, PIV + 0.24, 0))
	# una pequeña cruz de madera
	M.box(p, Vector3(0.022, 0.12, 0.022), dark, Vector3(0, PIV + 0.31, 0))
	M.box(p, Vector3(0.07, 0.02, 0.022), dark, Vector3(0, PIV + 0.33, 0))


# Etapas 1-3: espadaña de piedra con arco de dovelas
func _frame_stone(p: Node3D) -> void:
	var wall: Material
	var stones: Array[Material] = []
	var trim: Material
	var cap: Material
	var cross_m: Material
	match tier:
		1:
			wall = M.tex_mat("bricks", 2.2, Color(0.84, 0.82, 0.77))
			stones = [M.mat(Color(0.64, 0.62, 0.58)), M.mat(Color(0.56, 0.54, 0.5)), M.mat(Color(0.7, 0.68, 0.64))]
			trim = M.mat(Color(0.7, 0.68, 0.64))
			cap = M.tex_mat("roof", 3.0, SLATE)
			cross_m = M.metal(IRON)
		2:
			wall = M.tex_mat("bricks", 2.2, Color(0.88, 0.85, 0.78))
			stones = [M.mat(Color(0.78, 0.25, 0.2)), M.mat(Color(0.94, 0.9, 0.82)), M.mat(Color(0.78, 0.25, 0.2))]
			trim = M.mat(Color(0.74, 0.72, 0.68))
			cap = M.tex_mat("roof", 3.0, SLATE)
			cross_m = M.metal(GOLD)
		_:
			wall = M.tex_mat("bricks", 2.2, MARBLE)
			stones = [M.metal(GOLD), M.mat(Color(1.0, 0.98, 0.94)), M.metal(GOLD)]
			trim = M.metal(GOLD)
			cap = M.tex_mat("roof", 3.0, Color(0.42, 0.55, 0.95))
			cross_m = M.mat(GOLD_BRIGHT, 1.3)
	var depth := 0.11
	for sx: float in [-1.0, 1.0]:
		var x := PILLAR_X * sx
		M.box(p, Vector3(0.13, 0.06, 0.14), trim, Vector3(x, 0.03, 0))
		M.box(p, Vector3(0.09, YS - 0.04, 0.1), wall, Vector3(x, 0.04 + (YS - 0.04) * 0.5, 0))
		M.box(p, Vector3(0.125, 0.045, 0.135), trim, Vector3(x, YS - 0.02, 0))
		if tier >= 2:
			# columnas adosadas en las dos caras
			for sz: float in [-1.0, 1.0]:
				M.cyl(p, 0.026, 0.026, YS - 0.1, wall if tier == 2 else M.mat(Color(1.0, 0.98, 0.94)), Vector3(x, 0.05 + (YS - 0.1) * 0.5, 0.058 * sz), Vector3.ZERO, 10)
				M.cyl(p, 0.04, 0.03, 0.04, trim, Vector3(x, YS - 0.06, 0.058 * sz), Vector3.ZERO, 10)
		if tier == 3:
			M.box(p, Vector3(0.02, YS - 0.2, 0.104), M.mat(ROYAL), Vector3(x - 0.046 * sx, 0.1 + (YS - 0.2) * 0.5, 0))
	# Arco de dovelas
	var n := 9
	for k in n:
		var a := PI * (k + 0.5) / n
		var r := (ARCH_RI + ARCH_RO) * 0.5
		M.box(p, Vector3(PI * r / n + 0.012, ARCH_RO - ARCH_RI, depth + 0.012), stones[k % 3],
				Vector3(cos(a) * r, YS + sin(a) * r, 0), Vector3(0, 0, rad_to_deg(a) - 90.0))
	# Enjutas escalonadas (quedan tapadas por las dovelas)
	var top := YS + ARCH_RO + 0.025
	var slices := 7
	for i in slices:
		var x0 := i * (PILLAR_X + 0.045) / slices
		var x1 := (i + 1) * (PILLAR_X + 0.045) / slices
		var y_low := sqrt(maxf(ARCH_RO * ARCH_RO - x1 * x1, 0.0)) - 0.012
		var h := top - (YS + y_low)
		if h <= 0.005:
			continue
		for sx: float in [-1.0, 1.0]:
			M.box(p, Vector3(x1 - x0 + 0.004, h, depth), wall, Vector3((x0 + x1) * 0.5 * sx, YS + y_low + h * 0.5, 0))
	# Cornisa
	M.box(p, Vector3(2.0 * PILLAR_X + 0.14, 0.04, depth + 0.05), trim, Vector3(0, top + 0.02, 0))
	var ct := top + 0.04
	if tier < 3:
		# Tejadillo a dos aguas de pizarra
		var w := 2.0 * PILLAR_X + 0.16 + tier * 0.03
		for sz: float in [-1.0, 1.0]:
			M.box(p, Vector3(w, 0.024, 0.12), cap, Vector3(0, ct + 0.035, 0.045 * sz), Vector3(-36.0 * sz, 0, 0))
		M.box(p, Vector3(w + 0.02, 0.03, 0.03), trim, Vector3(0, ct + 0.072, 0))
		if tier == 2:
			# pináculos sobre los pilares
			for sx: float in [-1.0, 1.0]:
				M.box(p, Vector3(0.07, 0.06, 0.07), trim, Vector3(PILLAR_X * sx, ct + 0.06, 0))
				M.cyl(p, 0.0, 0.045, 0.16, cap, Vector3(PILLAR_X * sx, ct + 0.17, 0), Vector3(0, 45, 0), 4)
				M.sphere(p, 0.016, M.metal(GOLD), Vector3(PILLAR_X * sx, ct + 0.26, 0), Vector3.ONE, 6)
		_cross(p, Vector3(0, ct + 0.17, 0), 1.0 + tier * 0.25, cross_m)
	else:
		# Frontón de mármol con tímpano azul, aristas doradas y cruz radiante
		var steps := 6
		for i in steps:
			var y := ct + 0.02 + i * 0.035
			var w := (2.0 * PILLAR_X + 0.06) * (1.0 - float(i) / steps)
			M.box(p, Vector3(w, 0.036, depth - 0.01), M.mat(ROYAL) if i > 0 else wall, Vector3(0, y, 0))
		var apex := Vector3(0, ct + 0.02 + steps * 0.035, 0)
		for sx: float in [-1.0, 1.0]:
			M.segment(p, 0.02, trim, Vector3((PILLAR_X + 0.06) * sx, ct + 0.0, 0), apex + Vector3(0, 0.01, 0), 8)
			M.cyl(p, 0.0, 0.035, 0.12, M.tex_mat("roof", 3.0, Color(0.42, 0.55, 0.95)), Vector3((PILLAR_X + 0.03) * sx, ct + 0.08, 0), Vector3.ZERO, 8)
			M.sphere(p, 0.018, trim, Vector3((PILLAR_X + 0.03) * sx, ct + 0.15, 0), Vector3.ONE, 8)
		M.sphere(p, 0.03, M.mat(HOLY, 1.6), apex + Vector3(0, -0.07, 0.05), Vector3(1, 1, 0.4), 10)
		M.sphere(p, 0.03, M.mat(HOLY, 1.6), apex + Vector3(0, -0.07, -0.05), Vector3(1, 1, 0.4), 10)
		_cross(p, apex + Vector3(0, 0.1, 0), 1.6, cross_m)
		# rayos de la cruz
		for k in 8:
			var a := TAU * k / 8.0
			var ray := M.box(p, Vector3(0.01, 0.07, 0.01), cross_m, apex + Vector3(0, 0.13, 0) + Vector3(cos(a), sin(a), 0) * 0.1)
			ray.rotation.z = a - PI * 0.5


# Cruz en el plano XY (se ve por las dos caras)
static func _cross(p: Node3D, pos: Vector3, s: float, m: Material) -> void:
	M.box(p, Vector3(0.022, 0.13, 0.022) * s, m, pos)
	M.box(p, Vector3(0.08, 0.022, 0.022) * s, m, pos + Vector3(0, 0.025 * s, 0))


# =====================================================================
# --- Monje campanero ---
# =====================================================================

func _build_man(c: Node3D) -> void:
	var habit: Material = [M.mat(Color(0.5, 0.36, 0.22)), M.mat(Color(0.52, 0.52, 0.54)), M.mat(Color(0.15, 0.14, 0.16)), M.mat(Color(0.98, 0.97, 0.94))][tier]
	var cord: Material = [M.mat(ROPE), M.mat(ROPE), M.mat(WHITE), M.metal(GOLD)][tier]
	var skin := M.mat(Human.SKIN)
	Human.body(c, habit, cord)
	# Hábito largo hasta el suelo
	M.cyl(c, 0.15, 0.19, 0.08, habit, Vector3(0, 0.03, 0), Vector3.ZERO, 16)
	# Escapulario (delante y detrás)
	if tier > 0:
		var scap: Material = [habit, M.mat(Color(0.26, 0.25, 0.28)), M.mat(WHITE), M.mat(ROYAL)][tier]
		for sz: float in [-1.0, 1.0]:
			M.box(c, Vector3(0.11, 0.32, 0.02), scap, Vector3(0, 0.15, 0.125 * sz), Vector3(4.0 * sz, 0, 0))
			if tier == 3:
				for sx: float in [-1.0, 1.0]:
					M.box(c, Vector3(0.012, 0.32, 0.024), M.metal(GOLD), Vector3(0.055 * sx, 0.15, 0.126 * sz), Vector3(4.0 * sz, 0, 0))
				M.box(c, Vector3(0.12, 0.015, 0.024), M.metal(GOLD), Vector3(0, 0.0, 0.132 * sz), Vector3(4.0 * sz, 0, 0))
	# Capucha caída a la espalda
	M.sphere(c, 0.1, habit, Vector3(0, 0.32, 0.09), Vector3(1.35, 0.75, 0.9), 12)
	M.cyl(c, 0.07, 0.085, 0.04, habit, Vector3(0, 0.34, 0.0), Vector3.ZERO, 14)
	# Cíngulo con nudos
	var belt := TorusMesh.new()
	belt.inner_radius = 0.135
	belt.outer_radius = 0.152
	M.add(c, belt, cord, Vector3(0, 0.1, 0))
	M.segment(c, 0.01, cord, Vector3(-0.07, 0.1, -0.125), Vector3(-0.085, -0.01, -0.15), 6)
	for k in 3:
		M.sphere(c, 0.016, cord, Vector3(-0.073 - k * 0.005, 0.07 - k * 0.035, -0.132 - k * 0.006), Vector3.ONE, 6)
	# Cruz pectoral
	var pect: Material = [M.mat(TIMBER), M.mat(TIMBER), M.metal(Color(0.85, 0.87, 0.9)), M.mat(GOLD_BRIGHT, 1.2)][tier]
	M.segment(c, 0.006, cord, Vector3(-0.06, 0.32, -0.08), Vector3(0, 0.22, -0.142), 4)
	M.segment(c, 0.006, cord, Vector3(0.06, 0.32, -0.08), Vector3(0, 0.22, -0.142), 4)
	M.box(c, Vector3(0.018, 0.065, 0.014), pect, Vector3(0, 0.19, -0.15), Vector3(-6, 0, 0))
	M.box(c, Vector3(0.045, 0.016, 0.014), pect, Vector3(0, 0.205, -0.149), Vector3(-6, 0, 0))
	# Pies (sandalias)
	for sx: float in [-1.0, 1.0]:
		M.sphere(c, 0.035, M.mat(Color(0.36, 0.22, 0.12)), Vector3(0.06 * sx, 0.01, -0.12), Vector3(1, 0.5, 1.4), 8)
	# Cabeza con tonsura (cerquillo)
	var hair_col: Color = [Human.HAIR, Color(0.38, 0.26, 0.16), Color(0.72, 0.72, 0.74), Color(0.95, 0.94, 0.9)][tier]
	var h := Human.head(c, true, true, hair_col)
	M.sphere(h, 0.088, skin, Vector3(0, 0.14, 0.025), Vector3(1.0, 0.42, 1.0), 14)
	if tier >= 2:
		# barba de abad
		M.sphere(h, 0.08, M.mat(hair_col), Vector3(0, -0.1, -0.06), Vector3(1.0, 0.85, 0.7), 12)
		M.box(h, Vector3(0.045, 0.008, 0.01), M.mat(Color(0.6, 0.3, 0.28)), Vector3(0, -0.07, -0.135))


# Aureola dorada detrás de la cabeza (Maestría): gira despacio
func _build_halo() -> void:
	_halo = Node3D.new()
	_halo.position = Human.HEAD + Vector3(0, 0.03, 0.12)
	_man.add_child(_halo)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.15
	ring.outer_radius = 0.175
	ring.rings = 28
	M.add(_halo, ring, M.mat(HOLY, 1.8), Vector3.ZERO, Vector3(90, 0, 0))
	for k in 8:
		var a := TAU * k / 8.0
		var r := M.box(_halo, Vector3(0.012, 0.04, 0.012), M.mat(HOLY, 2.2), Vector3(cos(a), sin(a), 0) * 0.2)
		r.rotation.z = a - PI * 0.5


func _build_moving_parts() -> void:
	var rope := M.mat(ROPE)
	_rope = M.add(cat_pivot, M.tube_mesh(0.009, 6), rope)
	_tail = M.add(cat_pivot, M.tube_mesh(0.009, 6), rope)
	# Sally: agarradera de lana a rayas (nodo de altura 1 que se estira)
	_sally = Node3D.new()
	cat_pivot.add_child(_sally)
	var cols: Array[Material] = [M.mat(RED), M.mat(WHITE), M.mat(Color(0.2, 0.36, 0.7))]
	if tier == 3:
		cols = [M.mat(ROYAL), M.metal(GOLD), M.mat(WHITE)]
	for k in 6:
		M.add(_sally, M.tube_mesh(0.022, 10), cols[k % 3], Vector3(0, -0.5 + (k + 0.5) / 6.0, 0), Vector3.ZERO, Vector3(1, 1.0 / 6.0, 1))
	# Brazos con mangas anchas
	var sleeve: Material = [M.mat(Color(0.5, 0.36, 0.22)), M.mat(Color(0.52, 0.52, 0.54)), M.mat(Color(0.15, 0.14, 0.16)), M.mat(Color(0.98, 0.97, 0.94))][tier]
	_arm_l = M.add(cat_pivot, M.tube_mesh(0.038, 8), sleeve)
	_arm_r = M.add(cat_pivot, M.tube_mesh(0.038, 8), sleeve)
	var skin := M.mat(Human.SKIN)
	_hand_l = M.sphere(cat_pivot, 0.034, skin, Vector3.ZERO, Vector3(1, 1.1, 0.9), 8)
	_hand_r = M.sphere(cat_pivot, 0.034, skin, Vector3.ZERO, Vector3(1, 1.1, 0.9), 8)


# =====================================================================
# --- Torre (estática) ---
# =====================================================================

func _build_tower(p: Node3D) -> void:
	match tier:
		0: _tower_t0(p)
		1: _tower_t1(p)
		2: _tower_t2(p)
		_: _tower_t3(p)


# Ventana de arco de medio punto con lamas, en la cara `face` del cuadrado de semilado `half`
static func _window(p: Node3D, face: Vector3, half: float, cx: float, y0: float, w: float, h: float,
		frame_m: Material, dark_m: Material, louver_m: Material) -> void:
	var g := Node3D.new()
	g.position = face * (half + 0.004)
	g.rotation.y = atan2(face.x, face.z)
	p.add_child(g)
	var rect_h := h - w * 0.5
	M.box(g, Vector3(w + 0.05, rect_h, 0.03), frame_m, Vector3(cx, y0 + rect_h * 0.5, 0))
	M.cyl(g, w * 0.5 + 0.025, w * 0.5 + 0.025, 0.03, frame_m, Vector3(cx, y0 + rect_h, 0), Vector3(90, 0, 0), 16)
	M.box(g, Vector3(w, rect_h, 0.032), dark_m, Vector3(cx, y0 + rect_h * 0.5, 0.003))
	M.cyl(g, w * 0.5, w * 0.5, 0.032, dark_m, Vector3(cx, y0 + rect_h, 0.003), Vector3(90, 0, 0), 16)
	if louver_m:
		var n := int(rect_h / 0.045)
		for k in n:
			M.box(g, Vector3(w - 0.008, 0.012, 0.03), louver_m, Vector3(cx, y0 + 0.03 + k * 0.045, 0.012), Vector3(-30, 0, 0))
	M.box(g, Vector3(w + 0.08, 0.025, 0.05), frame_m, Vector3(cx, y0 - 0.005, 0.01))
	M.box(g, Vector3(0.035, 0.045, 0.04), frame_m, Vector3(cx, y0 + h + 0.015, 0.006))


static func _faces() -> Array[Vector3]:
	return [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]


# Fuste cuadrado de piedra con zócalo, sillares, cornisa y suelo de la plataforma
static func _shaft(p: Node3D, py: float, half: float, wall: Material, stones: Array[Material], dark: Material, floor_m: Material) -> void:
	M.box(p, Vector3(2.0 * half + 0.16, 0.08, 2.0 * half + 0.16), dark, Vector3(0, 0.04, 0))
	M.box(p, Vector3(2.0 * half + 0.07, 0.07, 2.0 * half + 0.07), stones[1], Vector3(0, 0.115, 0))
	var h := py - 0.12
	M.box(p, Vector3(2.0 * half, h, 2.0 * half), wall, Vector3(0, 0.08 + h * 0.5, 0))
	# esquinales (sillares alternos)
	var rows := int((py - 0.2) / 0.1)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			for r in rows:
				var big := r % 2 == 0
				var sz3 := Vector3(0.12 if big else 0.07, 0.085, 0.07 if big else 0.12)
				M.box(p, sz3, stones[r % 3], Vector3(half * sx - (0.035 if big else 0.0) * sx + 0.012 * sx, 0.2 + r * 0.1, half * sz - (0.0 if big else 0.035) * sz + 0.012 * sz))
	# cornisa y suelo
	M.box(p, Vector3(2.0 * half + 0.1, 0.05, 2.0 * half + 0.1), stones[2], Vector3(0, py - 0.075, 0))
	M.box(p, Vector3(2.0 * half + 0.14, 0.05, 2.0 * half + 0.14), floor_m, Vector3(0, py - 0.025, 0))


# Etapa 0: caballete de troncos con plataforma de tablones y barandilla
func _tower_t0(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[0]
	var bark := M.tex_mat("wood", 2.5, Color(0.66, 0.5, 0.36))
	var bark2 := M.tex_mat("wood", 2.5, Color(0.58, 0.43, 0.3))
	var dark := M.mat(Color(0.4, 0.26, 0.15))
	var plank := M.tex_mat("wood", 2.0, Color(0.88, 0.74, 0.55))
	var plank2 := M.tex_mat("wood", 2.0, Color(0.76, 0.6, 0.43))
	var rope := M.mat(ROPE)
	var stone := M.mat(Color(0.6, 0.58, 0.55))
	M.cyl(p, 0.46, 0.47, 0.03, M.mat(Color(0.52, 0.4, 0.27)), Vector3(0, 0.015, 0), Vector3.ZERO, 18)
	var leg := 0.33
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.sphere(p, 0.07, stone, Vector3(leg * sx, 0.03, leg * sz), Vector3(1.2, 0.6, 1.2), 8)
			M.cyl(p, 0.042, 0.048, py + 0.12, bark, Vector3(leg * sx, (py + 0.12) * 0.5, leg * sz), Vector3.ZERO, 8)
			M.cyl(p, 0.0, 0.042, 0.06, dark, Vector3(leg * sx, py + 0.15, leg * sz), Vector3.ZERO, 8)
	# aspas de arriostramiento en las cuatro caras
	for face: Vector3 in _faces():
		var tg := Vector3(face.z, 0, face.x)
		var base := face * (leg + 0.01)
		M.segment(p, 0.02, bark2, base - tg * leg + Vector3(0, 0.06, 0), base + tg * leg + Vector3(0, py - 0.08, 0), 6)
		M.segment(p, 0.02, bark2, base + tg * leg + Vector3(0, 0.06, 0), base - tg * leg + Vector3(0, py - 0.08, 0), 6)
		M.cyl(p, 0.03, 0.03, 0.03, rope, base + Vector3(0, py * 0.5 - 0.01, 0), Vector3(90, 0, 0) if absf(face.z) > 0.5 else Vector3(0, 0, 90), 8)
	# vigas y tablones de la plataforma
	for s: float in [-1.0, 1.0]:
		M.box(p, Vector3(0.84, 0.05, 0.06), dark, Vector3(0, py - 0.07, 0.33 * s))
	for k in 8:
		M.box(p, Vector3(0.82 + (k % 3) * 0.02, 0.04, 0.1), plank if k % 2 == 0 else plank2, Vector3((k % 2) * 0.012, py - 0.02, -0.365 + k * 0.104), Vector3(0, (k % 3 - 1) * 2.0, 0))
	# barandilla de palos con cuerda
	for face: Vector3 in _faces():
		var tg := Vector3(face.z, 0, face.x)
		for o: float in [-0.18, 0.18]:
			M.cyl(p, 0.016, 0.018, 0.13, bark2, face * 0.38 + tg * o + Vector3(0, py + 0.065, 0), Vector3.ZERO, 6)
		M.box(p, tg.abs() * 0.7 + Vector3(0, 0.022, 0) + face.abs() * 0.022, dark, face * 0.38 + Vector3(0, py + 0.12, 0))
	# escalera de mano en el lado +X
	for sz: float in [-1.0, 1.0]:
		M.segment(p, 0.016, bark, Vector3(0.47, 0.0, 0.09 * sz), Vector3(0.4, py + 0.05, 0.09 * sz), 6)
	for k in 4:
		var f := (k + 0.6) / 4.5
		M.box(p, Vector3(0.022, 0.02, 0.2), dark, Vector3(lerpf(0.47, 0.4, f), f * (py + 0.05), 0))
	# farol colgado y cepillo de limosnas
	M.box(p, Vector3(0.025, 0.025, 0.1), dark, Vector3(-0.33, py - 0.12, -0.39))
	M.cyl(p, 0.03, 0.035, 0.06, M.metal(IRON), Vector3(-0.33, py - 0.17, -0.44), Vector3.ZERO, 6)
	M.box(p, Vector3(0.11, 0.09, 0.09), plank2, Vector3(-0.2, 0.075, -0.42))
	M.box(p, Vector3(0.12, 0.02, 0.1), dark, Vector3(-0.2, 0.125, -0.42))
	M.box(p, Vector3(0.04, 0.006, 0.01), M.mat(Color(0.05, 0.04, 0.04)), Vector3(-0.2, 0.137, -0.42))
	Arch._ground_details(p, false)


# Etapa 1: torre de sillares con ventanas de arco y parapeto almenado
func _tower_t1(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[1]
	var half := 0.34
	var wall := M.tex_mat("bricks", 2.2, Color(0.84, 0.82, 0.77))
	var stones: Array[Material] = [M.mat(Color(0.64, 0.62, 0.58)), M.mat(Color(0.56, 0.54, 0.5)), M.mat(Color(0.7, 0.68, 0.64))]
	var dark := M.mat(STONE_DARK)
	var black := M.mat(Color(0.08, 0.07, 0.07))
	var louver := M.mat(TIMBER)
	_shaft(p, py, half, wall, stones, dark, stones[2])
	for face: Vector3 in _faces():
		_window(p, face, half, 0.0, 0.2, 0.15, 0.25, stones[2], black, louver)
	# parapeto bajo con almenas pequeñas
	Arch.parapet(p, half + 0.03, py + 0.04, 0.06, 0.05, wall)
	Arch.merlons(p, half + 0.03, py + 0.1, Vector3(0.08, 0.07, 0.08), 3, wall, stones[2])
	# puerta en la cara +Z
	Arch._door(p, half + 0.005, stones[2], M.tex_mat("wood", 2.0, Color(0.62, 0.48, 0.38)), M.metal(IRON))
	M.box(p, Vector3(0.28, 0.04, 0.14), stones[0], Vector3(0, 0.02, half + 0.1))
	Arch.wall_torch(p, Vector3(0.22, 0.32, half), Vector3(0, 0, 1), M.metal(IRON))
	Arch._ground_details(p, false)


# Etapa 2: torre grande con contrafuertes, ventanas geminadas, pináculos y estandartes
func _tower_t2(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[2]
	var half := 0.35
	var wall := M.tex_mat("bricks", 2.2, Color(0.88, 0.85, 0.78))
	var stones: Array[Material] = [M.mat(Color(0.66, 0.64, 0.6)), M.mat(Color(0.57, 0.55, 0.51)), M.mat(Color(0.74, 0.72, 0.68))]
	var dark := M.mat(STONE_DARK)
	var black := M.mat(Color(0.08, 0.07, 0.07))
	var louver := M.mat(TIMBER)
	var slate := M.tex_mat("roof", 3.0, SLATE)
	var gold := M.metal(GOLD)
	var iron := M.metal(IRON)
	_shaft(p, py, half, wall, stones, dark, stones[2])
	# contrafuertes en talud
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(p, Vector3(0.1, 0.34, 0.1), stones[1], Vector3((half + 0.01) * sx, 0.25, (half + 0.01) * sz))
			M.cyl(p, 0.0, 0.075, 0.08, stones[2], Vector3((half + 0.01) * sx, 0.46, (half + 0.01) * sz), Vector3(0, 45, 0), 4)
	# ventanas geminadas con parteluz
	for face: Vector3 in _faces():
		for cx: float in [-0.085, 0.085]:
			_window(p, face, half, cx, 0.24, 0.11, 0.26, stones[2], black, louver)
		var g := Node3D.new()
		g.position = face * (half + 0.02)
		g.rotation.y = atan2(face.x, face.z)
		p.add_child(g)
		M.cyl(g, 0.018, 0.018, 0.22, stones[0], Vector3(0, 0.34, 0), Vector3.ZERO, 8)
		M.cyl(g, 0.03, 0.03, 0.03, M.mat(Color(0.78, 0.25, 0.2)), Vector3(0, 0.58, 0), Vector3(90, 0, 0), 12)
	# imposta dorada
	M.box(p, Vector3(2.0 * half + 0.025, 0.02, 2.0 * half + 0.025), gold, Vector3(0, 0.2, 0))
	# parapeto calado y pináculos de esquina
	Arch.parapet(p, half + 0.04, py + 0.05, 0.07, 0.05, wall)
	for face: Vector3 in _faces():
		var tg := Vector3(face.z, 0, face.x)
		for o: float in [-0.2, -0.07, 0.07, 0.2]:
			M.box(p, Vector3(0.03, 0.03, 0.03) + face.abs() * 0.03, black, face * (half + 0.04) + tg * o + Vector3(0, py + 0.055, 0))
		M.box(p, tg.abs() * (2.0 * half + 0.14) + Vector3(0, 0.025, 0) + face.abs() * 0.07, stones[2], face * (half + 0.04) + Vector3(0, py + 0.095, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3((half + 0.04) * sx, py, (half + 0.04) * sz)
			M.box(p, Vector3(0.09, 0.16, 0.09), stones[2], c + Vector3(0, 0.08, 0))
			M.cyl(p, 0.0, 0.06, 0.2, slate, c + Vector3(0, 0.26, 0), Vector3(0, 45, 0), 4)
			M.sphere(p, 0.016, gold, c + Vector3(0, 0.37, 0), Vector3.ONE, 6)
	# puerta, estandartes y antorchas
	Arch._door(p, half + 0.005, stones[2], M.tex_mat("wood", 2.0, Color(0.62, 0.48, 0.38)), iron)
	M.box(p, Vector3(0.28, 0.04, 0.14), stones[0], Vector3(0, 0.02, half + 0.1))
	for sx: float in [-1.0, 1.0]:
		Arch.wall_torch(p, Vector3(0.24 * sx, 0.36, half + 0.02), Vector3(0, 0, 1), iron)
		# astas para las banderolas en los pináculos traseros
		M.cyl(p, 0.007, 0.007, 0.16, iron, Vector3((half + 0.04) * sx, py + 0.46, -(half + 0.04)), Vector3.ZERO, 4)
	Arch._ground_details(p, false)


# Etapa 3 (Maestría): mármol, oro y azul real con ventanas que brillan
func _tower_t3(p: Node3D) -> void:
	var py: float = PLAT_BY_TIER[3]
	var half := 0.35
	var wall := M.tex_mat("bricks", 2.2, MARBLE)
	var stones: Array[Material] = [M.mat(Color(0.93, 0.91, 0.86)), M.mat(Color(0.86, 0.84, 0.8)), M.mat(Color(1.0, 0.98, 0.94))]
	var dark := M.mat(Color(0.74, 0.72, 0.68))
	var gold := M.metal(GOLD)
	var royal := M.mat(ROYAL)
	var glow := M.mat(HOLY, 1.5)
	var blue_roof := M.tex_mat("roof", 3.0, Color(0.42, 0.55, 0.95))
	_shaft(p, py, half, wall, stones, dark, royal)
	# bandas doradas
	for y: float in [0.155, 0.36]:
		M.box(p, Vector3(2.0 * half + 0.03, 0.022, 2.0 * half + 0.03), gold, Vector3(0, y, 0))
	M.box(p, Vector3(2.0 * half + 0.16, 0.02, 2.0 * half + 0.16), gold, Vector3(0, py - 0.05, 0))
	# contrafuertes de mármol con remate dorado
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(p, Vector3(0.1, 0.36, 0.1), stones[2], Vector3((half + 0.01) * sx, 0.26, (half + 0.01) * sz))
			M.cyl(p, 0.0, 0.075, 0.08, gold, Vector3((half + 0.01) * sx, 0.48, (half + 0.01) * sz), Vector3(0, 45, 0), 4)
	# ventanas geminadas que brillan, con marco dorado sobre fondo azul
	for face: Vector3 in _faces():
		var g := Node3D.new()
		g.position = face * (half + 0.003)
		g.rotation.y = atan2(face.x, face.z)
		p.add_child(g)
		M.box(g, Vector3(0.36, 0.38, 0.02), royal, Vector3(0, 0.39, 0))
		for cx: float in [-0.085, 0.085]:
			_window(p, face, half + 0.014, cx, 0.26, 0.11, 0.26, gold, glow, null)
		M.cyl(g, 0.018, 0.018, 0.22, gold, Vector3(0, 0.36, 0.03), Vector3.ZERO, 8)
		# rosetón dorado
		M.cyl(g, 0.035, 0.035, 0.03, gold, Vector3(0, 0.6, 0.02), Vector3(90, 0, 0), 14)
		M.cyl(g, 0.022, 0.022, 0.034, glow, Vector3(0, 0.6, 0.024), Vector3(90, 0, 0), 12)
	# balaustrada de mármol con pasamanos de oro y pináculos azules
	for face: Vector3 in _faces():
		var tg := Vector3(face.z, 0, face.x)
		for k in 7:
			var o := -0.27 + k * 0.09
			M.cyl(p, 0.016, 0.02, 0.08, stones[2], face * (half + 0.04) + tg * o + Vector3(0, py + 0.04, 0), Vector3.ZERO, 8)
		M.box(p, tg.abs() * (2.0 * half + 0.14) + Vector3(0, 0.025, 0) + face.abs() * 0.05, gold, face * (half + 0.04) + Vector3(0, py + 0.09, 0))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3((half + 0.04) * sx, py, (half + 0.04) * sz)
			M.box(p, Vector3(0.09, 0.17, 0.09), stones[2], c + Vector3(0, 0.085, 0))
			M.box(p, Vector3(0.1, 0.02, 0.1), gold, c + Vector3(0, 0.17, 0))
			M.cyl(p, 0.0, 0.06, 0.24, blue_roof, c + Vector3(0, 0.3, 0), Vector3(0, 45, 0), 4)
			M.sphere(p, 0.02, gold, c + Vector3(0, 0.43, 0), Vector3.ONE, 8)
			M.cyl(p, 0.0, 0.012, 0.05, gold, c + Vector3(0, 0.47, 0), Vector3.ZERO, 6)
	# puerta dorada y escalinata
	Arch._door(p, half + 0.005, gold, M.mat(ROYAL), gold)
	M.box(p, Vector3(0.32, 0.04, 0.16), stones[2], Vector3(0, 0.02, half + 0.1))
	for sx: float in [-1.0, 1.0]:
		Arch.wall_torch(p, Vector3(0.24 * sx, 0.36, half + 0.02), Vector3(0, 0, 1), gold)
		M.cyl(p, 0.008, 0.008, 0.18, gold, Vector3((half + 0.04) * sx, py + 0.56, -(half + 0.04)), Vector3.ZERO, 4)
	Arch._ground_details(p, false)


# =====================================================================
# --- Efectos por etapa ---
# =====================================================================

func _build_tier_fx() -> void:
	var py: float = PLAT_BY_TIER[tier]
	# Ondas de sonido sagradas (todas las etapas)
	_wave_mat = StandardMaterial3D.new()
	_wave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wave_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wave_mat.albedo_color = Color(HOLY.r, HOLY.g, HOLY.b, 0.0)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.19
	ring.outer_radius = 0.215
	ring.rings = 32
	ring.ring_segments = 6
	for i in 2:
		var w := M.add(cat_pivot, ring, _wave_mat, Vector3(0, PIV - 0.22, 0))
		w.visible = false
		_waves.append(w)
	match tier:
		0:
			_pennants.append(Arch.pennant_node(self, Vector3(0.33, py + 0.15, 0.33), RED, WHITE, 0.22, 2.4))
			_flames.append(Arch.flame_node(self, Vector3(-0.33, py - 0.17, -0.44), 0.6, Color(1.0, 0.75, 0.3)))
		1:
			_flames.append(Arch.flame_node(self, Vector3(0.22, 0.37, 0.34 + 0.075)))
		2:
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.24 * sx, 0.41, 0.37 + 0.075)))
				_pennants.append(Arch.pennant_node(self, Vector3(0.39 * sx, py + 0.53, -0.39), RED, WHITE, 0.26, 0.4 if sx < 0.0 else 2.7))
		3:
			for sx: float in [-1.0, 1.0]:
				_flames.append(Arch.flame_node(self, Vector3(0.24 * sx, 0.41, 0.37 + 0.075), 1.1, Color(1.0, 0.82, 0.4)))
				_pennants.append(Arch.pennant_node(self, Vector3(0.39 * sx, py + 0.64, -0.39), ROYAL, GOLD, 0.3, 0.4 if sx < 0.0 else 2.7))
			_spinners.append(Arch.aura_ring(self, 0.47, HOLY, 0.12))
			add_child(Arch.sparkles(Color(1.0, 0.88, 0.5), Vector3(0, py + 0.6, 0), Vector3(0.42, 0.5, 0.42), 22, 0.012))
			# campanitas de oro que flotan alrededor
			for k in 3:
				var a := TAU * k / 3.0 + 0.5
				var f := Node3D.new()
				var bp := Vector3(cos(a) * 0.44, py + 0.45 + k * 0.12, sin(a) * 0.44)
				f.position = bp
				f.set_meta("base", bp)
				add_child(f)
				M.sphere(f, 0.032, M.metal(GOLD), Vector3(0, 0.0, 0), Vector3(1, 0.8, 1), 10)
				M.cyl(f, 0.032, 0.048, 0.045, M.metal(GOLD), Vector3(0, -0.03, 0), Vector3.ZERO, 12)
				M.cyl(f, 0.045, 0.045, 0.006, M.mat(HOLY, 1.6), Vector3(0, -0.054, 0), Vector3.ZERO, 12)
				M.sphere(f, 0.012, M.mat(ROYAL), Vector3(0, 0.03, 0), Vector3.ONE, 6)
				_floaters.append(f)
	if tier >= 2:
		_light = OmniLight3D.new()
		_light.light_color = HOLY
		_light.omni_range = 0.9 if tier == 2 else 1.2
		_light.shadow_enabled = false
		_light.position = Vector3(0, PIV - 0.2, 0)
		cat_pivot.add_child(_light)
		# halo suave alrededor de la campana
		var soft := StandardMaterial3D.new()
		soft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		soft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		soft.albedo_color = Color(HOLY.r, HOLY.g, HOLY.b, 0.12 if tier == 2 else 0.2)
		M.add(_bell, M.sphere_mesh(0.24, 16), soft, Vector3(0, -0.16, 0))
