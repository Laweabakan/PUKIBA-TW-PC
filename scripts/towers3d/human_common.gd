extends RefCounted
## Piezas comunes de los defensores humanos (cabeza, cuerpo con ropa y brazos).
## Adaptado de los gatitos de Cat Tower Defence. El personaje mira hacia -Z y sus coordenadas son relativas al pivote sobre la plataforma.

const M := preload("res://scripts/towers3d/models.gd")

const SKIN := Color(0.93, 0.76, 0.62)
const SKIN_SHADE := Color(0.84, 0.64, 0.5)
const HAIR := Color(0.32, 0.2, 0.12)
const FUR := SKIN  # (nombre heredado: manos y puños usan este color)
const FUR_GRAY := HAIR
const FUR_STRIPE := Color(0.2, 0.13, 0.08)
const PINK := Color(0.9, 0.55, 0.5)
const HEAD := Vector3(0, 0.46, 0)
const L_SHOULDER := Vector3(-0.13, 0.27, -0.02)
const R_SHOULDER := Vector3(0.13, 0.27, -0.02)


## Cabeza humana (mira a -Z): cara, pelo del color `hair_col`, ojos, cejas, nariz y orejas.
## `ears` = false cuando la cabeza queda bajo un sombrero o casco (sin pelo ni orejas visibles arriba).
## (Mantiene la firma de la cabeza de gato original para no tocar los modelos.)
static func head(c: Node3D, ears := true, hair := true, hair_col := HAIR, _beard_col := FUR_STRIPE) -> Node3D:
	var skin := M.mat(SKIN)
	var shade := M.mat(SKIN_SHADE)
	var hair_m := M.mat(hair_col)
	var black := M.mat(Color(0.08, 0.06, 0.05))
	var white := M.mat(Color(0.97, 0.97, 0.95))
	var h := Node3D.new()
	h.position = HEAD
	c.add_child(h)
	# Cráneo y mandíbula
	M.sphere(h, 0.135, skin, Vector3(0, 0.0, 0), Vector3(0.95, 1.08, 1.0), 16)
	M.sphere(h, 0.1, skin, Vector3(0, -0.06, -0.035), Vector3(0.95, 0.75, 0.95), 14)
	if hair:
		# Pelo: casquete detrás y arriba, con flequillo
		M.sphere(h, 0.142, hair_m, Vector3(0, 0.03, 0.025), Vector3(1.0, 1.0, 1.0), 14)
		M.box(h, Vector3(0.2, 0.045, 0.06), hair_m, Vector3(0, 0.1, -0.1), Vector3(-25, 0, 0))
	for s in [-1.0, 1.0]:
		if ears:
			M.sphere(h, 0.032, shade, Vector3(0.13 * s, -0.01, 0.0), Vector3(0.5, 1.0, 0.8), 8)
		# Ojos (blanco + pupila) y cejas
		M.sphere(h, 0.022, white, Vector3(0.048 * s, 0.01, -0.118), Vector3(1.1, 0.8, 0.6), 8)
		M.sphere(h, 0.012, black, Vector3(0.048 * s, 0.01, -0.13), Vector3.ONE, 6)
		M.box(h, Vector3(0.045, 0.01, 0.012), M.mat(hair_col.darkened(0.2)), Vector3(0.05 * s, 0.045, -0.125), Vector3(0, 0, -8.0 * s))
		M.sphere(h, 0.02, M.mat(PINK.lightened(0.2)), Vector3(0.075 * s, -0.04, -0.11), Vector3(1, 0.6, 0.4), 6)
	# Nariz y boca
	M.sphere(h, 0.02, shade, Vector3(0, -0.025, -0.14), Vector3(0.8, 1.1, 1.0), 6)
	M.box(h, Vector3(0.04, 0.008, 0.01), M.mat(Color(0.6, 0.3, 0.28)), Vector3(0, -0.075, -0.128))
	return h


## Los humanos no tienen cola: se conserva la función para no tocar los modelos.
static func tail(_c: Node3D, _base_col := FUR_GRAY, _stripe_col := FUR_STRIPE) -> void:
	pass


# Cuerpo vestido: torso, falda de la túnica y hombreras
static func body(c: Node3D, cloth: Material, trim: Material) -> void:
	M.sphere(c, 0.14, cloth, Vector3(0, 0.17, 0), Vector3(1.0, 1.2, 0.85), 14)
	M.cyl(c, 0.12, 0.17, 0.12, cloth, Vector3(0, 0.06, 0), Vector3.ZERO, 16)
	M.cyl(c, 0.045, 0.05, 0.06, M.mat(SKIN), Vector3(0, 0.35, 0), Vector3.ZERO, 10)  # cuello
	for s in [-1.0, 1.0]:
		M.sphere(c, 0.062, cloth, Vector3(0.13 * s, 0.27, 0), Vector3.ONE, 10)
		M.cyl(c, 0.065, 0.065, 0.015, trim, Vector3(0.13 * s, 0.24, 0), Vector3.ZERO, 10)


# Brazo (manga + mano) del hombro a la mano
static func arm(c: Node3D, shoulder: Vector3, hand: Vector3, sleeve: Material, cuff: Material) -> void:
	M.segment(c, 0.042, sleeve, shoulder, hand, 8)
	M.segment(c, 0.048, cuff, shoulder.lerp(hand, 0.78), shoulder.lerp(hand, 0.9), 8)
	M.sphere(c, 0.042, M.mat(SKIN), hand, Vector3(1, 1.1, 0.9), 8)


# Copo de nieve plano (en el plano XY, mirando a +Z)
static func snowflake(parent: Node3D, pos: Vector3, s: float, m: Material) -> void:
	for i in 3:
		var arm_node := Node3D.new()
		arm_node.position = pos
		arm_node.rotation.z = PI / 3.0 * i
		parent.add_child(arm_node)
		M.box(arm_node, Vector3(0.012, 0.11, 0.006) * Vector3(s, s, 1), m)
		for k in [-1.0, 1.0]:
			for side in [-1.0, 1.0]:
				M.box(arm_node, Vector3(0.008, 0.03, 0.006) * Vector3(s, s, 1), m,
						Vector3(0.012 * side * s, 0.035 * k * s, 0), Vector3(0, 0, 40.0 * side * k))


# Cristal de hielo hexagonal que apunta hacia +Y local
static func crystal(parent: Node3D, pos: Vector3, h: float, r: float, rot_deg: Vector3, m: Material) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = rot_deg
	parent.add_child(n)
	M.cyl(n, r * 0.7, r, h * 0.55, m, Vector3(0, h * 0.275, 0), Vector3.ZERO, 6)
	M.cyl(n, 0.0, r * 0.7, h * 0.45, m, Vector3(0, h * 0.775, 0), Vector3.ZERO, 6)


# Grupo de cristales en abanico
static func crystal_cluster(parent: Node3D, pos: Vector3, s: float, m: Material, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	crystal(parent, pos, 0.2 * s, 0.035 * s, Vector3(0, 0, 0), m)
	for i in 3:
		var a := TAU * i / 3.0 + rng.randf()
		crystal(parent, pos + Vector3(cos(a), 0, sin(a)) * 0.03 * s, rng.randf_range(0.1, 0.15) * s, 0.025 * s,
				Vector3(rad_to_deg(sin(a)) * 0.5, 0, -rad_to_deg(cos(a)) * 0.5), m)
