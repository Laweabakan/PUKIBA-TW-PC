extends RefCounted
## Biblioteca de modelos del paisaje (árboles, rocas, ruinas, casas...) estilo plastilina low-poly.
## Cada modelo se construye una vez por temática y se fusiona en una sola malla
## (una superficie por material) para dibujarlo con MultiMesh.
## Todos tienen la base en y = 0 y caben en una casilla (≈ 0.9 x 0.9) salvo los edificios.

const M := preload("res://scripts/towers3d/models.gd")
const FOLIAGE_SHADER := preload("res://shaders/foliage.gdshader")

static var _fol_mats := {}
static var _low := {}
static var _flat := {}


# ---------------------------------------------------------------- Paletas por temática
static func palette(theme: String) -> Dictionary:
	var p := {
		"bark": Color(0.42, 0.28, 0.16), "leaf": Color(0.28, 0.52, 0.2), "leaf2": Color(0.36, 0.6, 0.24),
		"rock": Color(0.56, 0.54, 0.5), "rock2": Color(0.42, 0.41, 0.39), "stone": Color(0.7, 0.67, 0.6),
		"wood": Color(0.5, 0.34, 0.18), "roof": Color(0.66, 0.28, 0.18), "roof2": Color(0.5, 0.36, 0.22),
		"wall": Color(0.92, 0.88, 0.76), "accent": Color(1.0, 0.85, 0.4), "snow": false,
		"bone": Color(0.9, 0.87, 0.78), "moss": Color(0.35, 0.5, 0.22), "glow": Color(1.0, 0.6, 0.2),
		"hay": Color(0.88, 0.74, 0.36),
	}
	match theme:
		"whispering_forest":
			p.leaf = Color(0.15, 0.36, 0.18); p.leaf2 = Color(0.22, 0.44, 0.2); p.bark = Color(0.32, 0.22, 0.14)
			p.rock = Color(0.46, 0.48, 0.44); p.moss = Color(0.26, 0.45, 0.2); p.roof = Color(0.42, 0.32, 0.2)
			p.glow = Color(0.75, 1.0, 0.45)
		"stone_hills":
			p.rock = Color(0.5, 0.49, 0.46); p.rock2 = Color(0.4, 0.39, 0.37); p.leaf = Color(0.3, 0.46, 0.22)
			p.leaf2 = Color(0.42, 0.54, 0.26); p.roof = Color(0.45, 0.47, 0.52); p.wall = Color(0.72, 0.69, 0.62)
		"swamp":
			p.leaf = Color(0.3, 0.38, 0.18); p.leaf2 = Color(0.38, 0.42, 0.2); p.bark = Color(0.3, 0.25, 0.17)
			p.rock = Color(0.38, 0.4, 0.33); p.moss = Color(0.4, 0.52, 0.18); p.wood = Color(0.36, 0.28, 0.18)
			p.glow = Color(0.6, 1.0, 0.4); p.roof = Color(0.4, 0.36, 0.22)
		"graveyard":
			p.bark = Color(0.26, 0.22, 0.2); p.leaf = Color(0.25, 0.27, 0.22); p.rock = Color(0.45, 0.46, 0.48)
			p.stone = Color(0.58, 0.58, 0.6); p.glow = Color(0.6, 0.9, 1.0); p.roof = Color(0.25, 0.25, 0.3)
		"frost_mountains":
			p.leaf = Color(0.14, 0.32, 0.24); p.leaf2 = Color(0.2, 0.38, 0.28); p.rock = Color(0.55, 0.58, 0.64)
			p.rock2 = Color(0.42, 0.45, 0.52); p.snow = true; p.roof = Color(0.55, 0.3, 0.2)
		"glacier":
			p.rock = Color(0.62, 0.74, 0.86); p.rock2 = Color(0.45, 0.6, 0.78); p.snow = true
			p.leaf = Color(0.55, 0.78, 0.95); p.stone = Color(0.75, 0.85, 0.95); p.glow = Color(0.6, 0.9, 1.0)
		"ash_desert":
			p.rock = Color(0.72, 0.56, 0.36); p.rock2 = Color(0.6, 0.44, 0.28); p.leaf = Color(0.36, 0.5, 0.2)
			p.leaf2 = Color(0.44, 0.56, 0.24); p.wall = Color(0.84, 0.72, 0.52); p.roof = Color(0.7, 0.5, 0.32)
			p.bark = Color(0.5, 0.38, 0.24); p.stone = Color(0.8, 0.68, 0.48)
		"volcano":
			p.rock = Color(0.2, 0.17, 0.16); p.rock2 = Color(0.12, 0.1, 0.1); p.bark = Color(0.16, 0.12, 0.1)
			p.glow = Color(1.0, 0.45, 0.08); p.stone = Color(0.3, 0.26, 0.24); p.leaf = Color(0.2, 0.16, 0.14)
		"elven_ruins":
			p.leaf = Color(0.55, 0.72, 0.3); p.leaf2 = Color(0.85, 0.72, 0.3); p.bark = Color(0.9, 0.9, 0.86)
			p.stone = Color(0.88, 0.87, 0.82); p.rock = Color(0.55, 0.6, 0.55); p.glow = Color(0.5, 1.0, 0.85)
			p.roof = Color(0.3, 0.62, 0.6); p.wall = Color(0.92, 0.92, 0.88); p.moss = Color(0.4, 0.6, 0.3)
		"fallen_fortress":
			p.bark = Color(0.18, 0.15, 0.13); p.leaf = Color(0.3, 0.3, 0.22); p.rock = Color(0.36, 0.34, 0.32)
			p.stone = Color(0.44, 0.41, 0.38); p.glow = Color(1.0, 0.5, 0.15); p.roof = Color(0.3, 0.22, 0.18)
		"dragon_canyon":
			p.rock = Color(0.7, 0.42, 0.26); p.rock2 = Color(0.55, 0.3, 0.2); p.bark = Color(0.36, 0.26, 0.2)
			p.leaf = Color(0.45, 0.42, 0.22); p.bone = Color(0.92, 0.88, 0.78); p.glow = Color(1.0, 0.5, 0.15)
		"crystal_forest":
			p.leaf = Color(0.45, 0.6, 1.0); p.leaf2 = Color(0.8, 0.5, 1.0); p.bark = Color(0.3, 0.26, 0.4)
			p.rock = Color(0.38, 0.36, 0.5); p.stone = Color(0.6, 0.6, 0.72); p.glow = Color(0.6, 0.8, 1.0)
		"void_abyss":
			p.rock = Color(0.18, 0.14, 0.24); p.rock2 = Color(0.1, 0.08, 0.15); p.glow = Color(0.65, 0.3, 1.0)
			p.stone = Color(0.25, 0.2, 0.32); p.bark = Color(0.15, 0.12, 0.2); p.leaf = Color(0.4, 0.2, 0.6)
		"lich_citadel":
			p.rock = Color(0.32, 0.36, 0.34); p.rock2 = Color(0.2, 0.23, 0.22); p.bark = Color(0.5, 0.52, 0.48)
			p.stone = Color(0.3, 0.33, 0.32); p.glow = Color(0.4, 1.0, 0.5); p.leaf = Color(0.3, 0.36, 0.28)
		"hellfire":
			p.rock = Color(0.25, 0.1, 0.08); p.rock2 = Color(0.14, 0.05, 0.05); p.glow = Color(1.0, 0.35, 0.05)
			p.stone = Color(0.35, 0.15, 0.12); p.bark = Color(0.12, 0.06, 0.05); p.bone = Color(0.85, 0.78, 0.65)
		"sky_islands":
			p.leaf = Color(0.3, 0.58, 0.26); p.leaf2 = Color(0.45, 0.68, 0.3); p.rock = Color(0.62, 0.58, 0.5)
			p.roof = Color(0.3, 0.45, 0.7); p.wall = Color(0.95, 0.93, 0.86)
		"ice_throne":
			p.rock = Color(0.5, 0.62, 0.8); p.rock2 = Color(0.35, 0.45, 0.66); p.snow = true
			p.leaf = Color(0.5, 0.75, 1.0); p.stone = Color(0.62, 0.72, 0.86); p.glow = Color(0.5, 0.85, 1.0)
		"abyss_gate":
			p.rock = Color(0.24, 0.1, 0.16); p.rock2 = Color(0.12, 0.05, 0.1); p.glow = Color(1.0, 0.25, 0.4)
			p.stone = Color(0.3, 0.14, 0.2); p.bark = Color(0.14, 0.06, 0.1); p.bone = Color(0.85, 0.8, 0.72)
		"chaos_citadel":
			p.rock = Color(0.16, 0.13, 0.16); p.rock2 = Color(0.08, 0.06, 0.08); p.glow = Color(1.0, 0.2, 0.3)
			p.stone = Color(0.24, 0.2, 0.24); p.bark = Color(0.1, 0.08, 0.1); p.leaf = Color(0.5, 0.15, 0.3)
	return p


# ---------------------------------------------------------------- Materiales
## Material de follaje que se mece (compartido por todas las instancias del mismo color).
static func fol(col: Color, emission := 0.0, sway := 0.035) -> ShaderMaterial:
	var key := "%s|%s|%s" % [col.to_html(), emission, sway]
	if not _fol_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = FOLIAGE_SHADER
		m.set_shader_parameter("albedo", col)
		m.set_shader_parameter("emission", emission)
		m.set_shader_parameter("sway", sway)
		_fol_mats[key] = m
	return _fol_mats[key]


static func mat(col: Color, emission := 0.0) -> StandardMaterial3D:
	return M.mat(col, emission)


## Material plano sin relieve (paisaje lejano: más barato)
static func flat(col: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [col.to_html(), emission]
	if not _flat.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.9
		if emission > 0.0:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = emission
		_flat[key] = m
	return _flat[key]


# ---------------------------------------------------------------- Mallas low-poly
static func lcyl(top: float, bottom: float, h: float, segs := 7) -> Mesh:
	var key := "c%s|%s|%s|%s" % [top, bottom, h, segs]
	if not _low.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_low[key] = m
	return _low[key]


static func lsph(r: float, segs := 8) -> Mesh:
	var key := "s%s|%s" % [r, segs]
	if not _low.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = segs
		m.rings = maxi(segs / 2, 3)
		_low[key] = m
	return _low[key]


static func lbox(size: Vector3) -> Mesh:
	var key := "b%s" % size
	if not _low.has(key):
		var m := BoxMesh.new()
		m.size = size
		_low[key] = m
	return _low[key]


static func lprism(size: Vector3) -> Mesh:
	var key := "p%s" % size
	if not _low.has(key):
		var m := PrismMesh.new()
		m.size = size
		_low[key] = m
	return _low[key]


# Atajos para construir (r = raíz donde se añade la pieza)
# ---------------------------------------------------------------- Tejado de paja
const STRAW := Color(0.86, 0.7, 0.4)
const STRAW_DARK := Color(0.64, 0.49, 0.25)


## Tejado de paja a dos aguas: capa gruesa con alero, hileras de paja y cumbrera redondeada.
## `across` = ancho entre aleros, `h` = altura, `length` = largo de la cumbrera (eje Z local),
## `pos` = centro del tejado, `yaw_deg` = giro. `snow` añade nieve encima.
static func thatch(r: Node3D, across: float, h: float, length: float, pos: Vector3, yaw_deg := 0.0, snow := false) -> void:
	var roof := Node3D.new()
	roof.position = pos
	roof.rotation_degrees = Vector3(0, yaw_deg, 0)
	r.add_child(roof)
	# capa inferior más oscura y algo mayor: se ve el grosor de la paja en el alero
	pr(roof, Vector3(across + 0.1, h + 0.05, length + 0.1), mat(STRAW_DARK), Vector3(0, -0.04, 0))
	pr(roof, Vector3(across, h, length), mat(STRAW), Vector3.ZERO)
	# hileras de paja paralelas a la cumbrera
	var a := atan2(h, across * 0.5)
	for side in [-1.0, 1.0]:
		for f in [0.22, 0.5, 0.76]:
			var eave := Vector3(side * across * 0.5, -h * 0.5, 0)
			var apex := Vector3(0, h * 0.5, 0)
			var p := eave.lerp(apex, f) + Vector3(side * sin(a), cos(a), 0) * 0.012
			bx(roof, Vector3(0.05, 0.022, length + 0.03), mat(STRAW_DARK if f != 0.5 else STRAW.lightened(0.08)), p, Vector3(0, 0, -side * rad_to_deg(a)))
	# cumbrera redondeada
	cy(roof, 0.05, 0.05, length + 0.06, mat(STRAW_DARK), Vector3(0, h * 0.5, 0), Vector3(90, 0, 0), 8)
	if snow:
		pr(roof, Vector3(across * 0.92, h * 0.55, length + 0.04), mat(Color(0.95, 0.97, 1.0)), Vector3(0, h * 0.24, 0))


static func cy(r: Node3D, top: float, bottom: float, h: float, m: Material, pos: Vector3, rot := Vector3.ZERO, segs := 7) -> MeshInstance3D:
	return M.add(r, lcyl(top, bottom, h, segs), m, pos, rot)


static func sp(r: Node3D, rad: float, m: Material, pos: Vector3, scl := Vector3.ONE, segs := 8) -> MeshInstance3D:
	return M.add(r, lsph(rad, segs), m, pos, Vector3.ZERO, scl)


static func bx(r: Node3D, size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return M.add(r, lbox(size), m, pos, rot)


static func pr(r: Node3D, size: Vector3, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return M.add(r, lprism(size), m, pos, rot)


static func sg(r: Node3D, rad: float, m: Material, a: Vector3, b: Vector3, segs := 6) -> MeshInstance3D:
	return M.segment(r, rad, m, a, b, segs)


# ---------------------------------------------------------------- Acceso a modelos
## Malla fusionada del modelo `id` con los colores de la temática (en caché).
static func get_mesh(theme: String, id: String, pal_in: Dictionary = {}) -> ArrayMesh:
	var pal := pal_in if not pal_in.is_empty() else palette(theme)
	return M.baked("sc:%s:%s" % [theme, id], func(root: Node3D) -> void: build(root, id, pal))


static func build(r: Node3D, id: String, p: Dictionary) -> void:
	var bark := mat(p.bark)
	var rock := mat(p.rock)
	var rock2 := mat(p.rock2)
	var stone := mat(p.stone)
	var wood := mat(p.wood)
	var snow := mat(Color(0.96, 0.98, 1.0))
	var glow := mat(p.glow, 2.0)
	var bone := mat(p.bone)
	var has_snow: bool = p.snow
	match id:
		# ------------------------------------------------ Árboles
		"oak":
			cy(r, 0.06, 0.09, 0.4, bark, Vector3(0, 0.2, 0))
			var lf := fol(p.leaf)
			var lf2 := fol(p.leaf2)
			sp(r, 0.3, lf, Vector3(0, 0.62, 0), Vector3(1, 0.85, 1))
			sp(r, 0.21, lf2, Vector3(0.17, 0.52, 0.1))
			sp(r, 0.22, lf, Vector3(-0.15, 0.55, -0.1))
			sp(r, 0.17, lf2, Vector3(0.02, 0.86, 0.04))
		"oak_dark":
			cy(r, 0.06, 0.11, 0.45, bark, Vector3(0, 0.22, 0))
			sg(r, 0.035, bark, Vector3(0, 0.35, 0), Vector3(0.22, 0.55, 0.05))
			var lf := fol(p.leaf)
			sp(r, 0.34, lf, Vector3(0, 0.7, 0), Vector3(1.1, 0.75, 1.0))
			sp(r, 0.24, fol(p.leaf2), Vector3(0.24, 0.6, 0.1))
			sp(r, 0.2, lf, Vector3(-0.2, 0.6, -0.12))
		"pine", "snowpine":
			# Pino de papel plegado: faldas en capas, cada una con dos conos de 6 caras girados
			# entre sí (borde en picos) y de dos tonos, como pliegues de papel.
			cy(r, 0.045, 0.065, 0.3, bark, Vector3(0, 0.15, 0), Vector3.ZERO, 5)
			var lf := fol(p.leaf, 0.0, 0.025)
			var lf2 := fol(p.leaf2, 0.0, 0.025)
			var sn := fol(Color(0.95, 0.97, 1.0), 0.0, 0.025)
			var hs := [[0.42, 0.4, 0.34], [0.34, 0.36, 0.56], [0.26, 0.32, 0.77], [0.17, 0.3, 0.97]]
			for k in hs.size():
				var e: Array = hs[k]
				var yaw := k * 17.0
				cy(r, 0.0, e[0], e[1], lf, Vector3(0, e[2], 0), Vector3(0, yaw, 0), 6)
				cy(r, 0.0, e[0] * 0.88, e[1] * 0.94, lf2, Vector3(0, e[2] + 0.025, 0), Vector3(0, yaw + 30.0, 0), 6)
				if id == "snowpine" or has_snow:
					cy(r, 0.0, e[0] * 0.55, e[1] * 0.5, sn, Vector3(0, e[2] + e[1] * 0.26, 0), Vector3(0, yaw + 15.0, 0), 6)
		"poplar":
			cy(r, 0.04, 0.06, 0.3, bark, Vector3(0, 0.15, 0))
			sp(r, 0.2, fol(p.leaf2), Vector3(0, 0.75, 0), Vector3(0.85, 2.2, 0.85))
		"birch":
			cy(r, 0.045, 0.06, 0.7, bark, Vector3(0, 0.35, 0))
			for k in 3:
				bx(r, Vector3(0.1, 0.025, 0.1), mat(Color(0.2, 0.2, 0.2)), Vector3(0, 0.15 + k * 0.18, 0), Vector3(0, k * 40, 0))
			sp(r, 0.24, fol(p.leaf2), Vector3(0.05, 0.78, 0), Vector3(1, 1.2, 1))
			sp(r, 0.2, fol(p.leaf), Vector3(-0.1, 0.62, 0.08))
		"dead", "burnt":
			var bk := bark if id == "dead" else mat(Color(0.1, 0.08, 0.07))
			cy(r, 0.04, 0.08, 0.6, bk, Vector3(0, 0.3, 0))
			sg(r, 0.03, bk, Vector3(0, 0.45, 0), Vector3(0.25, 0.75, 0.05))
			sg(r, 0.025, bk, Vector3(0, 0.38, 0), Vector3(-0.22, 0.62, -0.08))
			sg(r, 0.02, bk, Vector3(0, 0.58, 0), Vector3(-0.05, 0.85, 0.18))
			sg(r, 0.015, bk, Vector3(0.18, 0.66, 0.04), Vector3(0.3, 0.72, -0.12))
			if id == "burnt":
				sp(r, 0.04, glow, Vector3(0.25, 0.75, 0.05), Vector3.ONE, 6)
				sp(r, 0.035, glow, Vector3(0.02, 0.1, 0.07), Vector3.ONE, 6)
		"willow":
			cy(r, 0.06, 0.11, 0.5, bark, Vector3(0, 0.25, 0))
			var lf := fol(p.leaf, 0.0, 0.05)
			var lf2 := fol(p.leaf2, 0.0, 0.07)
			sp(r, 0.36, lf, Vector3(0, 0.66, 0), Vector3(1.15, 0.7, 1.15))
			for k in 9:
				var a := TAU * k / 9.0
				# cortinas de ramas colgantes: conos invertidos que bajan del borde de la copa
				cy(r, 0.11, 0.03, 0.34, lf2, Vector3(cos(a) * 0.33, 0.5, sin(a) * 0.33), Vector3(sin(a) * 12.0, 0, -cos(a) * 12.0), 5)
		"palm":
			var prev := Vector3.ZERO
			for k in 5:
				var nxt := Vector3(0.025 * k * k * 0.5, 0.15 * (k + 1), 0)
				sg(r, 0.05 - k * 0.005, bark, prev, nxt)
				prev = nxt
			var lf := fol(p.leaf, 0.0, 0.05)
			for k in 7:
				var a := TAU * k / 7.0
				var leaf := bx(r, Vector3(0.42, 0.02, 0.1), lf, prev + Vector3(cos(a) * 0.18, -0.04, sin(a) * 0.18))
				leaf.rotation = Vector3(0, -a, -0.45)
			sp(r, 0.05, mat(Color(0.4, 0.28, 0.15)), prev + Vector3(0, -0.04, 0))
		"crystal_tree":
			cy(r, 0.04, 0.09, 0.4, bark, Vector3(0, 0.2, 0))
			var c1 := fol(p.leaf, 0.35, 0.01)
			var c2 := fol(p.leaf2, 0.35, 0.01)
			var c3 := fol(Color(1.0, 0.55, 0.85), 0.35, 0.01)
			cy(r, 0.0, 0.16, 0.95, c1, Vector3(0, 0.8, 0), Vector3.ZERO, 5)
			cy(r, 0.0, 0.11, 0.6, c2, Vector3(0.2, 0.62, 0.05), Vector3(0, 0, -28), 5)
			cy(r, 0.0, 0.11, 0.62, c3, Vector3(-0.18, 0.62, -0.06), Vector3(10, 0, 28), 5)
			cy(r, 0.0, 0.08, 0.42, c2, Vector3(0.02, 0.55, 0.2), Vector3(32, 0, 0), 5)
			cy(r, 0.0, 0.07, 0.35, c1, Vector3(0.02, 0.55, -0.2), Vector3(-32, 0, 0), 5)
		"mushroom":
			cy(r, 0.06, 0.08, 0.4, mat(Color(0.88, 0.85, 0.75)), Vector3(0, 0.2, 0))
			sp(r, 0.3, fol(p.glow, 0.25, 0.01), Vector3(0, 0.45, 0), Vector3(1, 0.45, 1))
			cy(r, 0.04, 0.05, 0.22, mat(Color(0.88, 0.85, 0.75)), Vector3(0.24, 0.11, 0.12))
			sp(r, 0.13, fol(p.leaf2, 0.2, 0.01), Vector3(0.24, 0.24, 0.12), Vector3(1, 0.5, 1))
		"ice_spike":
			var ice := M.metal(p.leaf)
			var ice2 := M.metal(p.rock)
			cy(r, 0.0, 0.18, 0.95, ice, Vector3(0, 0.47, 0), Vector3.ZERO, 5)
			cy(r, 0.0, 0.12, 0.6, ice2, Vector3(0.2, 0.28, 0.1), Vector3(0, 0, -15), 5)
			cy(r, 0.0, 0.1, 0.5, ice, Vector3(-0.18, 0.24, -0.12), Vector3(12, 0, 18), 5)
			cy(r, 0.0, 0.08, 0.35, ice2, Vector3(0.0, 0.17, 0.24), Vector3(20, 0, 0), 5)
		"obsidian", "demon_spikes":
			var ob := M.metal(Color(0.08, 0.06, 0.09) if id == "obsidian" else p.rock2)
			cy(r, 0.0, 0.16, 0.9, ob, Vector3(0, 0.45, 0), Vector3(4, 0, 3), 5)
			cy(r, 0.0, 0.11, 0.6, ob, Vector3(0.22, 0.28, 0.08), Vector3(0, 0, -22), 5)
			cy(r, 0.0, 0.1, 0.5, ob, Vector3(-0.2, 0.24, -0.1), Vector3(14, 0, 24), 5)
			sp(r, 0.2, glow, Vector3(0, 0.0, 0), Vector3(1.4, 0.25, 1.4), 8)
		"void_spire":
			var vr := M.metal(p.rock)
			cy(r, 0.0, 0.17, 1.0, vr, Vector3(0, 0.5, 0), Vector3.ZERO, 4)
			cy(r, 0.0, 0.1, 0.55, vr, Vector3(0.2, 0.3, 0.1), Vector3(0, 0, -18), 4)
			cy(r, 0.0, 0.08, 0.4, vr, Vector3(-0.2, 0.22, -0.05), Vector3(0, 0, 20), 4)
			sp(r, 0.07, mat(p.glow, 2.5), Vector3(0, 1.05, 0), Vector3(1, 1.6, 1), 6)
			sp(r, 0.05, mat(p.glow, 2.5), Vector3(0.28, 0.6, 0.1), Vector3(1, 1.6, 1), 6)
		# ------------------------------------------------ Rocas
		"boulder", "boulder_mossy", "snow_rock":
			sp(r, 0.3, rock, Vector3(-0.05, 0.12, 0.02), Vector3(1.2, 0.85, 1.0), 9)
			sp(r, 0.2, rock2, Vector3(0.24, 0.08, -0.16), Vector3(1.0, 0.8, 1.1), 8)
			sp(r, 0.15, rock, Vector3(0.18, 0.05, 0.24), Vector3(1.2, 0.7, 1.0), 7)
			if id == "boulder_mossy":
				sp(r, 0.24, mat(p.moss), Vector3(-0.07, 0.3, 0.0), Vector3(1.2, 0.3, 1.0), 8)
			if id == "snow_rock" or (has_snow and id == "boulder"):
				sp(r, 0.25, snow, Vector3(-0.07, 0.3, 0.02), Vector3(1.2, 0.35, 1.0), 8)
		"ice_block":
			var ice := M.metal(p.leaf)
			var ice2 := M.metal(p.rock)
			M.box(r, Vector3(0.5, 0.45, 0.45), ice, Vector3(-0.08, 0.22, 0.02), Vector3(0, 15, 0))
			M.box(r, Vector3(0.32, 0.3, 0.3), ice2, Vector3(0.25, 0.15, -0.2), Vector3(0, -20, 6))
			M.box(r, Vector3(0.26, 0.28, 0.26), ice, Vector3(0.0, 0.58, 0.0), Vector3(10, 35, 8))
			M.box(r, Vector3(0.22, 0.18, 0.22), ice2, Vector3(0.22, 0.09, 0.26), Vector3(0, 40, 0))
		"lava_rock":
			sp(r, 0.3, rock2, Vector3(0, 0.14, 0), Vector3(1.2, 0.9, 1.0), 7)
			sp(r, 0.2, rock, Vector3(0.24, 0.1, -0.18), Vector3(1.0, 0.9, 1.0), 6)
			sp(r, 0.16, rock2, Vector3(-0.22, 0.08, 0.22), Vector3(1.1, 0.8, 1.0), 6)
			bx(r, Vector3(0.5, 0.03, 0.035), glow, Vector3(0, 0.3, 0.05), Vector3(0, 30, 25))
			bx(r, Vector3(0.35, 0.03, 0.035), glow, Vector3(0.05, 0.22, -0.1), Vector3(0, -50, -20))
			sp(r, 0.28, glow, Vector3(0, 0.0, 0), Vector3(1.5, 0.15, 1.5), 8)
		"crystal_cluster":
			var c1 := mat(p.leaf, 0.8)
			var c2 := mat(p.leaf2, 0.8)
			sp(r, 0.25, rock, Vector3(0, 0.03, 0), Vector3(1.4, 0.35, 1.3), 7)
			cy(r, 0.0, 0.11, 0.7, c1, Vector3(0, 0.35, 0), Vector3(5, 0, 6), 5)
			cy(r, 0.0, 0.08, 0.5, c2, Vector3(0.18, 0.25, 0.05), Vector3(0, 0, -30), 5)
			cy(r, 0.0, 0.08, 0.45, c1, Vector3(-0.17, 0.22, -0.08), Vector3(15, 0, 30), 5)
			cy(r, 0.0, 0.06, 0.32, c2, Vector3(0.0, 0.16, 0.22), Vector3(35, 0, 0), 5)
		"floating_rock":
			cy(r, 0.34, 0.0, 0.5, rock, Vector3(0, 0.3, 0), Vector3.ZERO, 7)
			cy(r, 0.35, 0.33, 0.08, mat(p.leaf), Vector3(0, 0.58, 0), Vector3.ZERO, 7)
			sp(r, 0.12, fol(p.leaf2), Vector3(0.1, 0.68, 0.05))
			cy(r, 0.02, 0.02, 0.3, wood, Vector3(-0.1, 0.75, -0.08))
		"void_rock":
			cy(r, 0.3, 0.0, 0.55, rock, Vector3(0, 0.38, 0), Vector3(0, 20, 0), 5)
			sp(r, 0.12, mat(p.glow, 2.0), Vector3(0, 0.12, 0), Vector3(1, 0.6, 1), 6)
			bx(r, Vector3(0.4, 0.03, 0.03), mat(p.glow, 2.0), Vector3(0, 0.6, 0.1), Vector3(0, 30, 0))
		"skull_pile":
			for k in 6:
				var a := TAU * k / 6.0
				var pos := Vector3(cos(a) * 0.2, 0.09, sin(a) * 0.2)
				if k == 5:
					pos = Vector3(0, 0.25, 0)
				sp(r, 0.1, bone, pos, Vector3(1, 0.9, 1.1), 7)
				var fwd := Vector3(cos(a), 0, sin(a)) * 0.09
				bx(r, Vector3(0.03, 0.03, 0.03), mat(p.glow, 2.5), pos + fwd + Vector3(0.03, 0.02, 0))
			sp(r, 0.28, rock2, Vector3(0, 0.0, 0), Vector3(1.2, 0.3, 1.2), 7)
		"sand_rock":
			bx(r, Vector3(0.7, 0.2, 0.6), rock2, Vector3(0, 0.1, 0), Vector3(0, 10, 0))
			bx(r, Vector3(0.55, 0.2, 0.5), rock, Vector3(0.02, 0.3, 0.0), Vector3(0, 25, 0))
			bx(r, Vector3(0.38, 0.2, 0.36), rock2, Vector3(-0.03, 0.5, 0.02), Vector3(0, 40, 0))
			bx(r, Vector3(0.22, 0.12, 0.2), rock, Vector3(0.25, 0.06, 0.28), Vector3(0, 5, 0))
		# ------------------------------------------------ Ruinas / construcciones
		"haystack":
			var hay := mat(p.hay)
			M.cyl(r, 0.3, 0.33, 0.35, hay, Vector3(0, 0.17, 0), Vector3.ZERO, 12)
			cy(r, 0.0, 0.33, 0.3, hay, Vector3(0, 0.49, 0), Vector3.ZERO, 12)
			M.cyl(r, 0.13, 0.15, 0.18, hay, Vector3(0.32, 0.09, 0.22), Vector3.ZERO, 10)
			cy(r, 0.0, 0.15, 0.14, hay, Vector3(0.32, 0.25, 0.22), Vector3.ZERO, 10)
			sg(r, 0.012, wood, Vector3(-0.3, 0.0, 0.3), Vector3(-0.15, 0.6, 0.2))
		"standing_stones":
			for k in 5:
				var a := TAU * k / 5.0 + 0.3
				M.box(r, Vector3(0.12, 0.42 + (k % 2) * 0.15, 0.1), rock, Vector3(cos(a) * 0.3, 0.24, sin(a) * 0.3), Vector3(0, -rad_to_deg(a), (k - 2) * 3))
			M.box(r, Vector3(0.3, 0.06, 0.2), rock2, Vector3(0, 0.04, 0))
		"shrine":
			M.box(r, Vector3(0.5, 0.1, 0.5), rock2, Vector3(0, 0.05, 0))
			M.box(r, Vector3(0.12, 0.55, 0.12), rock, Vector3(-0.17, 0.37, 0))
			M.box(r, Vector3(0.12, 0.55, 0.12), rock, Vector3(0.17, 0.37, 0))
			M.box(r, Vector3(0.6, 0.1, 0.16), rock, Vector3(0, 0.68, 0))
			sp(r, 0.08, mat(p.glow, 2.0), Vector3(0, 0.3, 0), Vector3.ONE, 8)
			sp(r, 0.2, mat(p.moss), Vector3(-0.17, 0.68, 0), Vector3(1.5, 0.4, 0.8), 7)
		"gravestones":
			var gs := mat(p.stone)
			M.box(r, Vector3(0.18, 0.32, 0.07), gs, Vector3(-0.2, 0.16, -0.15), Vector3(0, 8, -6))
			M.box(r, Vector3(0.16, 0.26, 0.07), gs, Vector3(0.2, 0.13, -0.2), Vector3(0, -6, 8))
			M.box(r, Vector3(0.06, 0.4, 0.06), gs, Vector3(0.05, 0.2, 0.18))
			M.box(r, Vector3(0.24, 0.06, 0.06), gs, Vector3(0.05, 0.3, 0.18))
			bx(r, Vector3(0.2, 0.05, 0.32), mat(Color(0.3, 0.25, 0.2)), Vector3(-0.2, 0.02, 0.05))
			bx(r, Vector3(0.18, 0.05, 0.3), mat(Color(0.3, 0.25, 0.2)), Vector3(0.2, 0.02, 0.02))
		"crypt":
			M.box(r, Vector3(0.7, 0.08, 0.8), rock2, Vector3(0, 0.04, 0))
			M.box(r, Vector3(0.58, 0.45, 0.65), stone, Vector3(0, 0.3, 0))
			pr(r, Vector3(0.68, 0.25, 0.75), mat(p.roof), Vector3(0, 0.65, 0))
			bx(r, Vector3(0.24, 0.32, 0.03), mat(Color(0.1, 0.08, 0.1)), Vector3(0, 0.24, 0.33))
			bx(r, Vector3(0.04, 0.2, 0.04), stone, Vector3(0, 0.88, 0.0))
			bx(r, Vector3(0.14, 0.04, 0.04), stone, Vector3(0, 0.92, 0.0))
			sp(r, 0.04, mat(p.glow, 2.5), Vector3(0, 0.26, 0.35), Vector3.ONE, 6)
		"pillar_ruin", "pillar_ruin_white":
			var st := stone if id == "pillar_ruin" else mat(Color(0.92, 0.92, 0.88))
			M.box(r, Vector3(0.75, 0.08, 0.75), rock2, Vector3(0, 0.04, 0))
			M.cyl(r, 0.1, 0.1, 0.7, st, Vector3(-0.2, 0.43, -0.2), Vector3.ZERO, 10)
			M.cyl(r, 0.1, 0.1, 0.35, st, Vector3(0.22, 0.26, -0.18), Vector3.ZERO, 10)
			M.box(r, Vector3(0.26, 0.08, 0.26), st, Vector3(-0.2, 0.82, -0.2))
			M.cyl(r, 0.09, 0.09, 0.5, st, Vector3(0.08, 0.15, 0.22), Vector3(0, 30, 90), 10)
			sp(r, 0.14, mat(p.moss), Vector3(0.22, 0.1, 0.2), Vector3(1.5, 0.4, 1.2), 6)
		"elven_arch":
			var wh := mat(Color(0.94, 0.94, 0.9))
			M.box(r, Vector3(0.8, 0.06, 0.4), rock2, Vector3(0, 0.03, 0))
			M.cyl(r, 0.06, 0.07, 0.75, wh, Vector3(-0.3, 0.42, 0), Vector3.ZERO, 10)
			M.cyl(r, 0.06, 0.07, 0.75, wh, Vector3(0.3, 0.42, 0), Vector3.ZERO, 10)
			for k in 7:
				var a := PI * k / 6.0
				M.box(r, Vector3(0.12, 0.06, 0.1), wh, Vector3(cos(a) * 0.3, 0.8 + sin(a) * 0.22, 0), Vector3(0, 0, rad_to_deg(a) + 90))
			sp(r, 0.07, mat(p.glow, 2.5), Vector3(0, 0.98, 0), Vector3(1, 1.4, 1), 8)
			sp(r, 0.16, fol(p.leaf2, 0.0, 0.03), Vector3(-0.3, 0.8, 0.05), Vector3(1, 0.7, 1))
		"broken_wall":
			M.box(r, Vector3(0.85, 0.08, 0.4), rock2, Vector3(0, 0.04, 0))
			M.box(r, Vector3(0.8, 0.45, 0.2), stone, Vector3(0, 0.3, 0))
			M.box(r, Vector3(0.3, 0.25, 0.2), stone, Vector3(-0.25, 0.65, 0))
			M.box(r, Vector3(0.12, 0.12, 0.22), stone, Vector3(-0.32, 0.83, 0))
			M.box(r, Vector3(0.12, 0.12, 0.22), stone, Vector3(-0.12, 0.83, 0))
			M.box(r, Vector3(0.16, 0.12, 0.14), rock, Vector3(0.25, 0.06, 0.25), Vector3(0, 25, 10))
			M.box(r, Vector3(0.12, 0.1, 0.12), rock, Vector3(0.05, 0.05, 0.28), Vector3(10, 50, 0))
			if has_snow:
				bx(r, Vector3(0.8, 0.04, 0.22), snow, Vector3(0, 0.54, 0))
		"watchtower_ruin":
			M.cyl(r, 0.3, 0.34, 0.65, stone, Vector3(0, 0.33, 0), Vector3.ZERO, 12)
			for k in 5:
				var a := TAU * k / 7.0
				M.box(r, Vector3(0.12, 0.14, 0.12), stone, Vector3(cos(a) * 0.27, 0.72, sin(a) * 0.27), Vector3(0, -rad_to_deg(a), 0))
			bx(r, Vector3(0.1, 0.22, 0.05), mat(Color(0.1, 0.08, 0.08)), Vector3(0, 0.4, 0.32))
			if has_snow:
				cy(r, 0.31, 0.31, 0.04, snow, Vector3(0, 0.67, 0), Vector3.ZERO, 12)
		"frozen_statue":
			var ice := M.metal(Color(0.6, 0.82, 0.95))
			M.box(r, Vector3(0.5, 0.1, 0.5), rock2, Vector3(0, 0.05, 0))
			var st := stone
			cy(r, 0.1, 0.13, 0.4, st, Vector3(0, 0.3, 0))
			sp(r, 0.09, st, Vector3(0, 0.58, 0))
			sg(r, 0.025, st, Vector3(0.12, 0.42, 0), Vector3(0.14, 0.85, 0.02))
			M.box(r, Vector3(0.3, 0.06, 0.08), st, Vector3(0.0, 0.4, 0.1))
			M.box(r, Vector3(0.46, 0.75, 0.42), ice, Vector3(0.0, 0.47, 0.0), Vector3(0, 12, 4))
		"dragon_bones":
			sp(r, 0.17, bone, Vector3(-0.28, 0.12, 0.0), Vector3(1.4, 0.8, 0.9), 8)
			cy(r, 0.0, 0.04, 0.22, bone, Vector3(-0.3, 0.26, 0.06), Vector3(-30, 0, 30), 5)
			cy(r, 0.0, 0.04, 0.22, bone, Vector3(-0.3, 0.26, -0.06), Vector3(30, 0, 30), 5)
			sg(r, 0.035, bone, Vector3(-0.15, 0.08, 0), Vector3(0.42, 0.05, 0))
			for k in 4:
				var x := -0.05 + k * 0.13
				var h := 0.45 - k * 0.06
				sg(r, 0.02, bone, Vector3(x, 0.06, 0), Vector3(x + 0.02, h, 0.22))
				sg(r, 0.02, bone, Vector3(x, 0.06, 0), Vector3(x + 0.02, h, -0.22))
				sg(r, 0.018, bone, Vector3(x + 0.02, h, 0.22), Vector3(x + 0.04, 0.02, 0.3))
				sg(r, 0.018, bone, Vector3(x + 0.02, h, -0.22), Vector3(x + 0.04, 0.02, -0.3))
		"dark_obelisk":
			M.box(r, Vector3(0.55, 0.1, 0.55), rock2, Vector3(0, 0.05, 0))
			M.box(r, Vector3(0.24, 0.8, 0.24), M.metal(p.stone), Vector3(0, 0.5, 0))
			cy(r, 0.0, 0.18, 0.2, M.metal(p.stone), Vector3(0, 1.0, 0), Vector3(0, 45, 0), 4)
			for k in 3:
				bx(r, Vector3(0.1, 0.04, 0.02), mat(p.glow, 2.5), Vector3(0, 0.35 + k * 0.2, 0.125))
				bx(r, Vector3(0.02, 0.04, 0.1), mat(p.glow, 2.5), Vector3(0.125, 0.45 + k * 0.18, 0))
			for k in 4:
				var a := TAU * k / 4.0 + 0.78
				M.box(r, Vector3(0.08, 0.2, 0.08), rock, Vector3(cos(a) * 0.32, 0.1, sin(a) * 0.32))
		"tent":
			var cloth := mat(Color(0.82, 0.68, 0.48) if not has_snow else Color(0.6, 0.45, 0.35))
			cy(r, 0.0, 0.4, 0.6, cloth, Vector3(0, 0.3, 0), Vector3.ZERO, 6)
			bx(r, Vector3(0.16, 0.24, 0.02), mat(Color(0.15, 0.1, 0.08)), Vector3(0, 0.12, 0.33), Vector3(-30, 0, 0))
			sg(r, 0.015, wood, Vector3(0, 0.5, 0), Vector3(0, 0.75, 0))
			bx(r, Vector3(0.02, 0.06, 0.12), mat(Color(0.75, 0.2, 0.15)), Vector3(0, 0.72, 0.06))
		"stilt_hut":
			for x in [-0.25, 0.25]:
				for z in [-0.22, 0.22]:
					cy(r, 0.025, 0.03, 0.35, wood, Vector3(x, 0.17, z))
			bx(r, Vector3(0.7, 0.05, 0.6), wood, Vector3(0, 0.35, 0))
			bx(r, Vector3(0.5, 0.32, 0.45), mat(p.wood.darkened(0.2)), Vector3(0, 0.53, 0))
			pr(r, Vector3(0.62, 0.3, 0.58), mat(p.roof), Vector3(0, 0.84, 0))
			bx(r, Vector3(0.1, 0.1, 0.02), mat(p.glow, 2.0), Vector3(0.1, 0.55, 0.23))
		"demon_altar":
			M.box(r, Vector3(0.7, 0.12, 0.7), rock2, Vector3(0, 0.06, 0))
			M.box(r, Vector3(0.5, 0.25, 0.36), M.metal(p.stone), Vector3(0, 0.24, 0))
			for x in [-0.28, 0.28]:
				cy(r, 0.0, 0.07, 0.6, bone, Vector3(x, 0.4, -0.2), Vector3(0, 0, -x * 40), 5)
			sp(r, 0.12, mat(p.glow, 3.0), Vector3(0, 0.45, 0), Vector3(1, 1.4, 1), 7)
			sp(r, 0.07, mat(Color(1, 0.9, 0.5), 3.0), Vector3(0, 0.55, 0), Vector3(1, 1.3, 1), 6)
		"gazebo":
			var wh := mat(p.wall)
			M.cyl(r, 0.38, 0.4, 0.08, stone, Vector3(0, 0.04, 0), Vector3.ZERO, 12)
			for k in 6:
				var a := TAU * k / 6.0
				cy(r, 0.035, 0.035, 0.5, wh, Vector3(cos(a) * 0.3, 0.33, sin(a) * 0.3))
			sp(r, 0.36, mat(p.roof), Vector3(0, 0.6, 0), Vector3(1, 0.55, 1), 10)
			sp(r, 0.05, mat(p.accent, 1.0), Vector3(0, 0.8, 0))
		"well":
			M.cyl(r, 0.24, 0.26, 0.25, stone, Vector3(0, 0.125, 0), Vector3.ZERO, 12)
			cy(r, 0.18, 0.18, 0.02, mat(Color(0.15, 0.3, 0.45)), Vector3(0, 0.24, 0), Vector3.ZERO, 10)
			cy(r, 0.02, 0.02, 0.5, wood, Vector3(-0.22, 0.45, 0))
			cy(r, 0.02, 0.02, 0.5, wood, Vector3(0.22, 0.45, 0))
			pr(r, Vector3(0.6, 0.2, 0.4), mat(p.roof), Vector3(0, 0.78, 0))
		# ------------------------------------------------ Troncos / objetos
		"log_pile", "frozen_log", "charred_log":
			var lw := wood if id == "log_pile" else (mat(Color(0.12, 0.09, 0.08)) if id == "charred_log" else bark)
			var ring := mat(Color(0.85, 0.7, 0.45) if id != "charred_log" else Color(0.2, 0.12, 0.08))
			for k in 3:
				var z := -0.17 + k * 0.17
				M.cyl(r, 0.09, 0.09, 0.75, lw, Vector3(0, 0.09, z), Vector3(0, 0, 90), 10)
				cy(r, 0.075, 0.075, 0.76, ring, Vector3(0, 0.09, z), Vector3(0, 0, 90), 8)
			M.cyl(r, 0.09, 0.09, 0.7, lw, Vector3(0, 0.25, -0.08), Vector3(0, 0, 90), 10)
			M.cyl(r, 0.09, 0.09, 0.7, lw, Vector3(0, 0.25, 0.09), Vector3(0, 0, 90), 10)
			if id == "frozen_log" or has_snow:
				bx(r, Vector3(0.7, 0.05, 0.3), snow, Vector3(0, 0.34, 0))
			if id == "charred_log":
				bx(r, Vector3(0.5, 0.03, 0.03), glow, Vector3(0, 0.18, 0.09))
				sp(r, 0.05, glow, Vector3(0.3, 0.3, 0.0), Vector3.ONE, 6)
		"cart":
			M.box(r, Vector3(0.62, 0.08, 0.42), wood, Vector3(0, 0.24, 0))
			M.box(r, Vector3(0.62, 0.14, 0.04), wood, Vector3(0, 0.34, 0.2))
			M.box(r, Vector3(0.62, 0.14, 0.04), wood, Vector3(0, 0.34, -0.2))
			for z in [-0.25, 0.25]:
				M.cyl(r, 0.15, 0.15, 0.04, mat(p.wood.darkened(0.3)), Vector3(-0.1, 0.15, z), Vector3(90, 0, 0), 10)
			sg(r, 0.02, wood, Vector3(0.3, 0.24, 0.1), Vector3(0.5, 0.06, 0.12))
			sg(r, 0.02, wood, Vector3(0.3, 0.24, -0.1), Vector3(0.5, 0.06, -0.12))
			sp(r, 0.22, mat(p.hay), Vector3(0, 0.38, 0), Vector3(1.3, 0.55, 0.85))
		"barrels":
			for e in [[-0.18, -0.12], [0.18, -0.15], [0.0, 0.2]]:
				M.cyl(r, 0.13, 0.13, 0.32, wood, Vector3(e[0], 0.16, e[1]), Vector3.ZERO, 12)
				cy(r, 0.135, 0.135, 0.03, M.metal(Color(0.3, 0.3, 0.32)), Vector3(e[0], 0.08, e[1]), Vector3.ZERO, 12)
				cy(r, 0.135, 0.135, 0.03, M.metal(Color(0.3, 0.3, 0.32)), Vector3(e[0], 0.25, e[1]), Vector3.ZERO, 12)
			M.box(r, Vector3(0.22, 0.2, 0.22), mat(p.wood.lightened(0.15)), Vector3(0.3, 0.1, 0.25), Vector3(0, 20, 0))
		"bones":
			sp(r, 0.12, bone, Vector3(0.18, 0.08, 0.1), Vector3(1.3, 0.8, 1), 7)
			cy(r, 0.0, 0.03, 0.18, bone, Vector3(0.24, 0.15, 0.18), Vector3(-40, 0, -30), 5)
			cy(r, 0.0, 0.03, 0.18, bone, Vector3(0.24, 0.15, 0.02), Vector3(40, 0, -30), 5)
			for k in 4:
				sg(r, 0.022, bone, Vector3(-0.3 + k * 0.08, 0.03, -0.3), Vector3(-0.22 + k * 0.1, 0.03, 0.05))
			sg(r, 0.03, bone, Vector3(-0.35, 0.03, 0.25), Vector3(0.0, 0.03, 0.32))
			sp(r, 0.05, bone, Vector3(-0.35, 0.03, 0.25))
			sp(r, 0.05, bone, Vector3(0.0, 0.03, 0.32))
		"mushrooms":
			var cap := mat(Color(0.8, 0.2, 0.15)) if not p.has("mush_glow") else mat(p.glow, 1.5)
			for k in 7:
				var a := TAU * k / 7.0
				var rr := 0.28 if k % 2 == 0 else 0.18
				var s := 0.7 + (k % 3) * 0.25
				var pos := Vector3(cos(a) * rr, 0, sin(a) * rr)
				cy(r, 0.025 * s, 0.03 * s, 0.16 * s, mat(Color(0.9, 0.88, 0.78)), pos + Vector3(0, 0.08 * s, 0))
				sp(r, 0.08 * s, fol(p.glow, 1.0, 0.0) if k % 2 == 0 else cap, pos + Vector3(0, 0.17 * s, 0), Vector3(1, 0.55, 1), 7)
			sp(r, 0.26, mat(p.moss), Vector3(0, 0.0, 0), Vector3(1.3, 0.15, 1.3), 7)
		"weapons":
			sp(r, 0.25, rock, Vector3(0, 0.0, 0), Vector3(1.3, 0.3, 1.1), 7)
			var steel := M.metal(Color(0.55, 0.56, 0.6))
			for e in [[-0.15, 0.0, -10], [0.12, 0.12, 15], [0.0, -0.18, 5]]:
				bx(r, Vector3(0.04, 0.45, 0.015), steel, Vector3(e[0], 0.25, e[1]), Vector3(0, e[2] * 3, e[2]))
				bx(r, Vector3(0.14, 0.025, 0.03), mat(Color(0.35, 0.25, 0.15)), Vector3(e[0], 0.4, e[1]), Vector3(0, e[2] * 3, e[2]))
			M.cyl(r, 0.16, 0.16, 0.04, mat(Color(0.55, 0.15, 0.12)), Vector3(0.22, 0.1, -0.2), Vector3(70, 20, 0), 12)
			sp(r, 0.04, steel, Vector3(0.24, 0.13, -0.18))
		"cage":
			M.box(r, Vector3(0.5, 0.06, 0.5), rock2, Vector3(0, 0.03, 0))
			var iron := M.metal(Color(0.2, 0.2, 0.22))
			for k in 8:
				var a := TAU * k / 8.0
				cy(r, 0.012, 0.012, 0.55, iron, Vector3(cos(a) * 0.2, 0.33, sin(a) * 0.2), Vector3.ZERO, 4)
			cy(r, 0.0, 0.24, 0.15, iron, Vector3(0, 0.67, 0), Vector3.ZERO, 8)
			sp(r, 0.07, bone, Vector3(0, 0.12, 0))
			sp(r, 0.05, mat(p.glow, 2.0), Vector3(0, 0.4, 0))
		"crystal_shards":
			var c1 := mat(p.leaf, 0.8)
			for k in 5:
				var a := TAU * k / 5.0
				cy(r, 0.0, 0.06, 0.3, c1 if k % 2 == 0 else mat(p.leaf2, 0.8), Vector3(cos(a) * 0.22, 0.08, sin(a) * 0.22), Vector3(rad_to_deg(sin(a)) * 1.2, 0, 60 - k * 25), 5)
			sp(r, 0.2, rock, Vector3(0, 0.02, 0), Vector3(1.2, 0.4, 1.0), 7)
		# ------------------------------------------------ Edificios del paisaje
		"house_timber", "house_timber2", "house_snow":
			var big := id == "house_timber2"
			var w := 0.9 if big else 0.75
			var d := 0.65 if big else 0.6
			var h := 0.5 if big else 0.42
			var wall := mat(p.wall)
			var beam := mat(Color(0.32, 0.2, 0.12))
			bx(r, Vector3(w + 0.06, 0.12, d + 0.06), mat(p.rock), Vector3(0, 0.06, 0))
			bx(r, Vector3(w, h, d), wall, Vector3(0, 0.12 + h * 0.5, 0))
			for sx in [-1, 1]:
				bx(r, Vector3(0.04, h, 0.04), beam, Vector3(sx * w * 0.5, 0.12 + h * 0.5, d * 0.5 + 0.005))
				bx(r, Vector3(0.04, h, 0.04), beam, Vector3(sx * w * 0.5, 0.12 + h * 0.5, -d * 0.5 - 0.005))
			bx(r, Vector3(w + 0.02, 0.04, d + 0.02), beam, Vector3(0, 0.12 + h * 0.55, 0))
			for k in 3:
				var x := -w * 0.3 + k * w * 0.3
				bx(r, Vector3(0.03, h * 0.9, 0.02), beam, Vector3(x, 0.12 + h * 0.5, d * 0.5 + 0.01), Vector3(0, 0, 30 if k % 2 == 0 else -30))
			bx(r, Vector3(0.14, 0.24, 0.02), mat(Color(0.3, 0.2, 0.12)), Vector3(w * 0.15, 0.24, d * 0.5 + 0.015))
			bx(r, Vector3(0.12, 0.1, 0.02), mat(Color(1.0, 0.85, 0.45), 0.8), Vector3(-w * 0.28, 0.12 + h * 0.75, d * 0.5 + 0.015))
			# Tejado de paja
			thatch(r, d + 0.26, 0.46, w + 0.2, Vector3(0, 0.12 + h + 0.21, 0), 90.0, id == "house_snow" or has_snow)
			bx(r, Vector3(0.1, 0.3, 0.1), mat(p.rock2), Vector3(w * 0.3, 0.12 + h + 0.35, -d * 0.15))
		"house_stone":
			var st := mat(p.wall)
			bx(r, Vector3(0.82, 0.5, 0.62), st, Vector3(0, 0.25, 0))
			for k in 4:
				bx(r, Vector3(0.1, 0.07, 0.02), mat(p.rock2), Vector3(-0.3 + k * 0.2, 0.08 + (k % 2) * 0.2, 0.315))
			bx(r, Vector3(0.14, 0.24, 0.02), mat(Color(0.3, 0.2, 0.12)), Vector3(0.12, 0.12, 0.315))
			bx(r, Vector3(0.1, 0.1, 0.02), mat(Color(1.0, 0.85, 0.45), 0.8), Vector3(-0.22, 0.32, 0.315))
			thatch(r, 0.8, 0.4, 0.98, Vector3(0, 0.69, 0), 90.0, has_snow)
			bx(r, Vector3(0.12, 0.3, 0.12), mat(p.rock2), Vector3(-0.25, 0.8, 0.0))
		"house_adobe":
			var ad := mat(p.wall)
			bx(r, Vector3(0.75, 0.45, 0.65), ad, Vector3(0, 0.225, 0))
			bx(r, Vector3(0.45, 0.3, 0.45), ad, Vector3(0.1, 0.6, -0.05))
			bx(r, Vector3(0.8, 0.04, 0.7), mat(p.roof), Vector3(0, 0.46, 0))
			bx(r, Vector3(0.14, 0.24, 0.02), mat(Color(0.3, 0.2, 0.12)), Vector3(-0.15, 0.12, 0.33))
			bx(r, Vector3(0.08, 0.08, 0.02), mat(Color(0.15, 0.1, 0.08)), Vector3(0.2, 0.32, 0.33))
			sp(r, 0.18, ad, Vector3(0.1, 0.75, -0.05), Vector3(1, 0.7, 1))
			for k in 3:
				cy(r, 0.015, 0.015, 0.3, wood, Vector3(-0.3 + k * 0.15, 0.35, 0.36), Vector3(90, 0, 0), 4)
		"house_elven":
			var wh := mat(p.wall)
			M.cyl(r, 0.3, 0.32, 0.55, wh, Vector3(0, 0.28, 0), Vector3.ZERO, 12)
			cy(r, 0.0, 0.38, 0.65, mat(p.roof), Vector3(0, 0.88, 0), Vector3.ZERO, 10)
			sp(r, 0.04, mat(p.glow, 2.0), Vector3(0, 1.22, 0))
			bx(r, Vector3(0.12, 0.25, 0.02), mat(Color(0.25, 0.3, 0.25)), Vector3(0, 0.15, 0.31))
			bx(r, Vector3(0.08, 0.12, 0.02), mat(p.glow, 1.5), Vector3(0.16, 0.38, 0.27), Vector3(0, 30, 0))
		"house_ruin":
			var st := mat(p.stone)
			bx(r, Vector3(0.8, 0.08, 0.65), mat(p.rock2), Vector3(0, 0.04, 0))
			bx(r, Vector3(0.8, 0.4, 0.06), st, Vector3(0, 0.24, -0.3))
			bx(r, Vector3(0.06, 0.55, 0.65), st, Vector3(-0.38, 0.3, 0))
			bx(r, Vector3(0.06, 0.25, 0.35), st, Vector3(0.38, 0.16, -0.12))
			bx(r, Vector3(0.3, 0.18, 0.06), st, Vector3(-0.2, 0.12, 0.3))
			sg(r, 0.03, mat(Color(0.12, 0.1, 0.08)), Vector3(-0.35, 0.55, -0.28), Vector3(0.3, 0.3, 0.25))
			sg(r, 0.03, mat(Color(0.12, 0.1, 0.08)), Vector3(-0.35, 0.55, 0.0), Vector3(0.25, 0.12, 0.1))
			bx(r, Vector3(0.18, 0.1, 0.15), mat(p.rock), Vector3(0.15, 0.08, 0.1), Vector3(0, 20, 10))
		"chapel":
			var wall := mat(p.wall)
			bx(r, Vector3(0.7, 0.55, 1.1), wall, Vector3(0, 0.275, 0))
			var rf := pr(r, Vector3(0.84, 0.45, 1.16), mat(p.roof), Vector3(0, 0.77, 0))
			rf.rotation_degrees = Vector3.ZERO
			bx(r, Vector3(0.4, 0.95, 0.4), wall, Vector3(0, 0.475, 0.6))
			cy(r, 0.0, 0.32, 0.6, mat(p.roof), Vector3(0, 1.25, 0.6), Vector3(0, 45, 0), 4)
			bx(r, Vector3(0.03, 0.2, 0.03), M.metal(Color(0.85, 0.7, 0.3)), Vector3(0, 1.62, 0.6))
			bx(r, Vector3(0.12, 0.03, 0.03), M.metal(Color(0.85, 0.7, 0.3)), Vector3(0, 1.64, 0.6))
			bx(r, Vector3(0.16, 0.3, 0.02), mat(Color(0.3, 0.2, 0.12)), Vector3(0, 0.15, 0.81))
			for z in [-0.3, 0.0, 0.3]:
				bx(r, Vector3(0.02, 0.2, 0.1), mat(Color(0.5, 0.65, 0.9), 0.6), Vector3(0.355, 0.32, z))
				bx(r, Vector3(0.02, 0.2, 0.1), mat(Color(0.5, 0.65, 0.9), 0.6), Vector3(-0.355, 0.32, z))
		"windmill_body":
			var wall := mat(p.wall)
			cy(r, 0.32, 0.45, 1.4, wall, Vector3(0, 0.7, 0), Vector3.ZERO, 8)
			cy(r, 0.0, 0.42, 0.5, mat(p.roof), Vector3(0, 1.65, 0), Vector3.ZERO, 8)
			bx(r, Vector3(0.18, 0.3, 0.03), mat(Color(0.3, 0.2, 0.12)), Vector3(0, 0.15, 0.44))
			bx(r, Vector3(0.12, 0.12, 0.03), mat(Color(0.2, 0.15, 0.1)), Vector3(0, 0.85, 0.37))
			cy(r, 0.06, 0.06, 0.3, wood, Vector3(0, 1.35, 0.42), Vector3(90, 0, 0), 6)
		"windmill_blades":
			var cloth := mat(Color(0.93, 0.9, 0.82))
			for k in 4:
				var a := k * 90.0
				var arm := Node3D.new()
				arm.rotation_degrees = Vector3(0, 0, a)
				r.add_child(arm)
				bx(arm, Vector3(0.05, 0.95, 0.03), wood, Vector3(0, 0.5, 0))
				bx(arm, Vector3(0.2, 0.7, 0.015), cloth, Vector3(0.12, 0.6, 0.01))
			sp(r, 0.07, wood, Vector3.ZERO)
		"fence":
			for x in [-0.5, 0.0, 0.5]:
				bx(r, Vector3(0.05, 0.28, 0.05), wood, Vector3(x, 0.14, 0))
			bx(r, Vector3(1.04, 0.035, 0.025), wood, Vector3(0, 0.2, 0))
			bx(r, Vector3(1.04, 0.035, 0.025), wood, Vector3(0, 0.1, 0))
		"iron_fence":
			var iron := M.metal(Color(0.15, 0.15, 0.17))
			for k in 6:
				cy(r, 0.0, 0.015, 0.4, iron, Vector3(-0.42 + k * 0.17, 0.2, 0), Vector3.ZERO, 4)
			bx(r, Vector3(1.0, 0.025, 0.025), iron, Vector3(0, 0.3, 0))
			bx(r, Vector3(1.0, 0.025, 0.025), iron, Vector3(0, 0.08, 0))
		"grave_small":
			M.box(r, Vector3(0.16, 0.28, 0.06), mat(p.stone), Vector3(0, 0.14, 0), Vector3(0, 0, 4))
			bx(r, Vector3(0.18, 0.04, 0.3), mat(Color(0.28, 0.24, 0.2)), Vector3(0, 0.02, 0.18))
		"grave_cross":
			bx(r, Vector3(0.05, 0.36, 0.05), mat(p.stone), Vector3(0, 0.18, 0))
			bx(r, Vector3(0.2, 0.05, 0.05), mat(p.stone), Vector3(0, 0.26, 0))
		"bush":
			sp(r, 0.18, fol(p.leaf2, 0.0, 0.03), Vector3(0, 0.1, 0), Vector3(1.2, 0.8, 1.1), 7)
			sp(r, 0.13, fol(p.leaf, 0.0, 0.03), Vector3(0.14, 0.08, 0.06), Vector3.ONE, 6)
		"reeds":
			var rd := fol(p.leaf2 if not has_snow else p.rock, 0.0, 0.12)
			for k in 6:
				var a := TAU * k / 6.0
				cy(r, 0.0, 0.018, 0.4 + (k % 3) * 0.08, rd, Vector3(cos(a) * 0.08, 0.2, sin(a) * 0.08), Vector3(cos(a) * 8, 0, sin(a) * 8), 4)
			cy(r, 0.02, 0.02, 0.08, fol(Color(0.4, 0.25, 0.12), 0.0, 0.12), Vector3(0.05, 0.42, 0.0), Vector3.ZERO, 5)
		"grass":
			var gr := fol(p.leaf2, 0.0, 0.1)
			for k in 5:
				var a := TAU * k / 5.0
				cy(r, 0.0, 0.02, 0.16, gr, Vector3(cos(a) * 0.05, 0.08, sin(a) * 0.05), Vector3(cos(a) * 20, 0, sin(a) * 20), 3)
		"flowers":
			var cols := [Color(0.95, 0.85, 0.3), Color(0.95, 0.5, 0.6)]
			for k in 5:
				var a := TAU * k / 5.0
				var pos := Vector3(cos(a) * 0.12, 0, sin(a) * 0.12)
				cy(r, 0.006, 0.006, 0.12, fol(p.leaf2, 0.0, 0.1), pos + Vector3(0, 0.06, 0), Vector3.ZERO, 3)
				sp(r, 0.035, fol(cols[k % cols.size()], 0.15, 0.1), pos + Vector3(0, 0.13, 0), Vector3.ONE, 5)
		"pebble":
			sp(r, 0.12, rock, Vector3(0, 0.02, 0), Vector3(1.3, 0.55, 1.0), 6)
		"pebble2":
			sp(r, 0.1, rock2, Vector3(0, 0.02, 0), Vector3(1.0, 0.6, 1.3), 6)
		"sheep":
			sp(r, 0.13, mat(Color(0.95, 0.95, 0.92)), Vector3(0, 0.15, 0), Vector3(1.3, 0.9, 1.0), 7)
			sp(r, 0.06, mat(Color(0.2, 0.18, 0.18)), Vector3(0.17, 0.18, 0), Vector3(1.2, 1, 0.9), 6)
			for x in [-0.08, 0.08]:
				for z in [-0.05, 0.05]:
					cy(r, 0.015, 0.015, 0.1, mat(Color(0.2, 0.18, 0.18)), Vector3(x, 0.05, z), Vector3.ZERO, 4)
		# ------------------------------------------------ Montañas y relieve lejano
		"mountain":
			cy(r, 0.0, 1.0, 1.0, flat(p.rock), Vector3(0, 0.5, 0), Vector3.ZERO, 7)
			cy(r, 0.0, 0.55, 0.62, flat(p.rock2), Vector3(0.45, 0.31, 0.25), Vector3.ZERO, 6)
		"mountain_snow":
			cy(r, 0.0, 1.0, 1.0, flat(p.rock), Vector3(0, 0.5, 0), Vector3.ZERO, 7)
			cy(r, 0.0, 0.36, 0.36, flat(Color(0.96, 0.97, 1.0)), Vector3(0, 0.825, 0), Vector3.ZERO, 7)
			cy(r, 0.0, 0.55, 0.62, flat(p.rock2), Vector3(0.45, 0.31, 0.25), Vector3.ZERO, 6)
			cy(r, 0.0, 0.17, 0.19, flat(Color(0.96, 0.97, 1.0)), Vector3(0.45, 0.53, 0.25), Vector3.ZERO, 6)
		"hill":
			sp(r, 1.0, flat(p.get("ground", p.leaf).darkened(0.08)), Vector3(0, 0, 0), Vector3(1, 0.45, 1), 10)
		"mesa":
			cy(r, 0.75, 1.0, 0.35, flat(p.rock2), Vector3(0, 0.17, 0), Vector3.ZERO, 7)
			cy(r, 0.7, 0.75, 0.35, flat(p.rock), Vector3(0, 0.52, 0), Vector3.ZERO, 7)
			cy(r, 0.62, 0.7, 0.3, flat(p.rock2.lightened(0.1)), Vector3(0, 0.85, 0), Vector3.ZERO, 7)
		"volcano_cone":
			cy(r, 0.22, 1.0, 1.0, flat(p.rock), Vector3(0, 0.5, 0), Vector3.ZERO, 9)
			cy(r, 0.2, 0.2, 0.02, flat(p.glow, 1.6), Vector3(0, 1.0, 0), Vector3.ZERO, 9)
			for k in 3:
				var a := TAU * k / 3.0 + 0.4
				sg(r, 0.025, flat(p.glow.darkened(0.35), 0.8), Vector3(cos(a) * 0.2, 0.99, sin(a) * 0.2), Vector3(cos(a) * 0.79, 0.26, sin(a) * 0.79), 4)
		"spire":
			cy(r, 0.0, 0.5, 1.0, flat(p.rock), Vector3(0, 0.5, 0), Vector3.ZERO, 5)
			cy(r, 0.0, 0.25, 0.6, flat(p.rock2), Vector3(0.35, 0.3, 0.1), Vector3(0, 0, -18), 5)
			cy(r, 0.0, 0.06, 0.3, flat(p.glow, 2.5), Vector3(0, 0.88, 0), Vector3.ZERO, 4)
		"dune":
			sp(r, 1.0, flat(p.get("ground", p.rock).lightened(0.04)), Vector3(0, 0, 0), Vector3(1.6, 0.22, 0.8), 10)
		"dark_tower":
			cy(r, 0.18, 0.26, 1.4, flat(p.stone), Vector3(0, 0.7, 0), Vector3.ZERO, 8)
			cy(r, 0.0, 0.3, 0.6, flat(p.rock2), Vector3(0, 1.7, 0), Vector3.ZERO, 8)
			bx(r, Vector3(0.08, 0.14, 0.05), flat(p.glow, 2.5), Vector3(0, 1.1, 0.2))
			bx(r, Vector3(0.08, 0.14, 0.05), flat(p.glow, 2.5), Vector3(0, 0.6, 0.24))
		"sky_island":
			cy(r, 1.0, 0.0, 1.4, flat(p.rock), Vector3(0, -0.7, 0), Vector3.ZERO, 8)
			cy(r, 1.02, 1.0, 0.15, flat(p.leaf), Vector3(0, 0.07, 0), Vector3.ZERO, 8)
			sp(r, 0.28, fol(p.leaf2), Vector3(0.3, 0.35, 0.1))
			sp(r, 0.22, fol(p.leaf), Vector3(-0.35, 0.3, -0.2))
		"cloud":
			var cm := flat(Color(1, 1, 1))
			sp(r, 0.5, cm, Vector3(0, 0, 0), Vector3(1.2, 0.7, 1), 8)
			sp(r, 0.38, cm, Vector3(0.55, -0.08, 0.1), Vector3(1.2, 0.7, 1), 8)
			sp(r, 0.4, cm, Vector3(-0.55, -0.06, -0.1), Vector3(1.2, 0.7, 1), 8)
			sp(r, 0.3, cm, Vector3(0.1, 0.22, 0.15), Vector3(1.2, 0.8, 1), 8)
		"cloud_dark":
			var cm := flat(Color(0.25, 0.22, 0.27))
			sp(r, 0.5, cm, Vector3(0, 0, 0), Vector3(1.4, 0.6, 1), 8)
			sp(r, 0.4, cm, Vector3(0.6, -0.05, 0.1), Vector3(1.2, 0.6, 1), 8)
			sp(r, 0.42, cm, Vector3(-0.6, -0.05, -0.1), Vector3(1.2, 0.6, 1), 8)
		"giant_gate":
			var st := flat(p.stone)
			bx(r, Vector3(0.5, 2.6, 0.5), st, Vector3(-1.2, 1.3, 0))
			bx(r, Vector3(0.5, 2.6, 0.5), st, Vector3(1.2, 1.3, 0))
			bx(r, Vector3(3.0, 0.5, 0.6), st, Vector3(0, 2.75, 0))
			cy(r, 0.0, 0.3, 0.9, flat(p.rock2), Vector3(-1.2, 3.1, 0), Vector3.ZERO, 4)
			cy(r, 0.0, 0.3, 0.9, flat(p.rock2), Vector3(1.2, 3.1, 0), Vector3.ZERO, 4)
			bx(r, Vector3(1.9, 2.5, 0.1), flat(p.glow, 2.0), Vector3(0, 1.25, 0))
		"ribcage":
			for k in 6:
				var z := -1.0 + k * 0.4
				var h := 1.2 - absf(k - 2.5) * 0.2
				sg(r, 0.07, bone, Vector3(0, 0.1, z), Vector3(0.7, h, z + 0.1))
				sg(r, 0.07, bone, Vector3(0, 0.1, z), Vector3(-0.7, h, z + 0.1))
				sg(r, 0.06, bone, Vector3(0.7, h, z + 0.1), Vector3(0.95, 0.0, z + 0.2))
				sg(r, 0.06, bone, Vector3(-0.7, h, z + 0.1), Vector3(-0.95, 0.0, z + 0.2))
			sg(r, 0.1, bone, Vector3(0, 0.12, -1.3), Vector3(0, 0.12, 1.3))
			sp(r, 0.4, bone, Vector3(0, 0.25, 1.75), Vector3(0.8, 0.6, 1.3), 8)
		# ------------------------------------------------ Puentes (el camino va a lo largo de Z; tablero en y = 0)
		"bridge_wood":
			var pl := mat(p.wood.lightened(0.08))
			var pl2 := mat(p.wood.darkened(0.08))
			for k in 7:
				var z := -0.43 + k * 0.1433
				bx(r, Vector3(0.9, 0.04, 0.13), pl if k % 2 == 0 else pl2, Vector3(0, -0.02, z), Vector3(0, (k % 3 - 1) * 2.0, 0))
			for sx in [-1, 1]:
				bx(r, Vector3(0.07, 0.09, 1.0), wood, Vector3(sx * 0.45, -0.06, 0))
				for sz in [-1, 1]:
					cy(r, 0.035, 0.04, 0.7, wood, Vector3(sx * 0.47, -0.1, sz * 0.42))
				bx(r, Vector3(0.04, 0.04, 1.0), pl, Vector3(sx * 0.47, 0.2, 0))
				bx(r, Vector3(0.03, 0.03, 0.9), pl2, Vector3(sx * 0.47, 0.1, 0))
			bx(r, Vector3(0.85, 0.06, 0.06), wood, Vector3(0, -0.15, 0))
		"bridge_stone":
			var st := stone
			M.box(r, Vector3(0.98, 0.12, 1.0), st, Vector3(0, -0.06, 0))
			for sx in [-1, 1]:
				M.box(r, Vector3(0.1, 0.2, 1.0), mat(p.stone.darkened(0.12)), Vector3(sx * 0.47, 0.08, 0))
				bx(r, Vector3(0.12, 0.05, 0.14), mat(p.stone.darkened(0.2)), Vector3(sx * 0.47, 0.2, 0.43))
			for sz in [-1, 1]:
				M.box(r, Vector3(0.9, 0.35, 0.1), mat(p.stone.darkened(0.25)), Vector3(0, -0.28, sz * 0.45))
			for k in 4:
				bx(r, Vector3(0.9, 0.005, 0.02), mat(p.stone.darkened(0.2)), Vector3(0, 0.001, -0.375 + k * 0.25))
		_:
			sp(r, 0.25, rock, Vector3(0, 0.1, 0))
