class_name VFX
extends RefCounted
## Efectos visuales hechos a mano: modelos de proyectiles con estelas y el kit
## compartido de partículas que usa Fx (explosiones, muertes, construcciones...).
##
## Rendimiento (móvil, GL Compatibility):
##  - Texturas, mallas, materiales, gradientes y curvas se generan UNA vez y se
##    cachean en diccionarios estáticos. En vuelo no se asigna nada nuevo.
##  - Los brillos son billboards aditivos sin luz (baratos en GLES3).
##  - El humo y el polvo son "bolitas de arcilla" opacas que crecen y encogen:
##    encajan con el estilo low-poly y no generan sobre-dibujado transparente.
##  - Las estelas son CPUParticles3D con pocas partículas y local_coords = false;
##    al impactar se sueltan en el mundo y se apagan solas (no desaparecen de golpe).
##
## Convención de los proyectiles: el eje +X local apunta en la dirección de vuelo.
## Metadatos que lee projectile.gd:
##  "spin"      -> Node3D que gira (rodar / dar volteretas)
##  "spin_rate" -> Vector3 en rad/s
##  "pulse"     -> Node3D cuyo tamaño parpadea (llamas, brillos)
##  "trails"    -> Array de CPUParticles3D a soltar al impactar

const WOOD := Color(0.56, 0.37, 0.2)
const WOOD_DARK := Color(0.4, 0.25, 0.13)
const STEEL := Color(0.8, 0.82, 0.88)
const IRON := Color(0.38, 0.4, 0.45)
const GOLD := Color(1.0, 0.78, 0.25)

const TEX_SIZE := 64

static var _tex := {}
static var _mats := {}
static var _meshes := {}
static var _grads := {}
static var _curves := {}
static var _elements := {}


## Genera por adelantado texturas y mallas (evita un tirón con el primer disparo).
## Opcional: game.gd puede llamarlo al cargar la partida.
static func prewarm() -> void:
	for t in ["glow", "star", "ring", "soft", "beam", "bubble", "smoke"]:
		tex(t)
	for m in ["quad", "ball", "shard", "gem", "chip", "spark", "coin", "beam", "rock", "crystal", "crescent", "streak"]:
		mesh(m)


# ================================================================ Texturas procedurales
## Texturas en escala de grises con alfa: glow, star, ring, soft, beam, bubble.
static func tex(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var n := TEX_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var dx := (x - c) / c
			var dy := (y - c) / c
			var d := sqrt(dx * dx + dy * dy)
			var a := 0.0
			var lum := 1.0
			match kind:
				"glow":
					a = pow(clampf(1.0 - d, 0.0, 1.0), 1.6)
				"star":
					# Destello de 4 puntas con núcleo brillante y halo suave
					var core := pow(clampf(1.0 - d * 2.2, 0.0, 1.0), 1.5)
					var sx := clampf(1.0 - absf(dy) * 11.0, 0.0, 1.0) * pow(clampf(1.0 - absf(dx), 0.0, 1.0), 2.0)
					var sy := clampf(1.0 - absf(dx) * 11.0, 0.0, 1.0) * pow(clampf(1.0 - absf(dy), 0.0, 1.0), 2.0)
					var halo := 0.35 * pow(clampf(1.0 - d, 0.0, 1.0), 3.0)
					a = clampf(core + maxf(sx, sy) + halo, 0.0, 1.0)
				"ring":
					var band := pow(clampf(1.0 - absf(d - 0.8) / 0.16, 0.0, 1.0), 1.6)
					var fill := 0.18 * clampf(d / 0.8, 0.0, 1.0) * (1.0 if d < 0.8 else 0.0)
					a = clampf(band + fill, 0.0, 1.0)
				"soft":
					# Perfil transversal de un rayo: centro intenso, bordes suaves
					var w := clampf(1.0 - absf(dy), 0.0, 1.0)
					a = clampf(pow(w, 2.0) * 0.8 + pow(w, 10.0), 0.0, 1.0)
				"beam":
					# Columna de luz: intensa abajo (v = 1), se desvanece hacia arriba
					var v := float(y) / float(n - 1)
					a = pow(v, 1.7)
				"bubble":
					var rim := pow(clampf(1.0 - absf(d - 0.82) / 0.16, 0.0, 1.0), 2.0)
					var hl := pow(clampf(1.0 - Vector2(dx + 0.35, dy + 0.35).length() / 0.22, 0.0, 1.0), 1.5)
					var inner := 0.15 * (1.0 if d < 0.82 else 0.0)
					a = clampf(rim * 0.9 + hl + inner, 0.0, 1.0)
				"smoke":
					a = pow(clampf(1.0 - d, 0.0, 1.0), 1.4)
					lum = lerpf(0.72, 1.0, clampf(0.5 - dy * 0.5, 0.0, 1.0))
			img.set_pixel(x, y, Color(lum, lum, lum, a))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


# ================================================================ Mallas compartidas
static func mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh = null
	match kind:
		"quad":
			var q := QuadMesh.new()
			q.size = Vector2.ONE
			m = q
		"ball":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 8
			s.rings = 4
			m = s
		"shard":
			# Diamante alargado en Y (cristales de hielo, esquirlas)
			var s2 := SphereMesh.new()
			s2.radius = 0.2
			s2.height = 1.0
			s2.radial_segments = 4
			s2.rings = 1
			m = s2
		"gem":
			var s3 := SphereMesh.new()
			s3.radius = 0.5
			s3.height = 1.2
			s3.radial_segments = 5
			s3.rings = 1
			m = s3
		"chip":
			var b := BoxMesh.new()
			b.size = Vector3(1.0, 0.55, 0.75)
			m = b
		"spark":
			var b2 := BoxMesh.new()
			b2.size = Vector3(0.06, 1.0, 0.06)
			m = b2
		"coin":
			var cy := CylinderMesh.new()
			cy.top_radius = 0.5
			cy.bottom_radius = 0.5
			cy.height = 0.16
			cy.radial_segments = 10
			cy.rings = 1
			m = cy
		"beam":
			var cy2 := CylinderMesh.new()
			cy2.top_radius = 0.5
			cy2.bottom_radius = 0.5
			cy2.height = 1.0
			cy2.radial_segments = 16
			cy2.rings = 1
			cy2.set("cap_top", false)
			cy2.set("cap_bottom", false)
			m = cy2
		"rock":
			m = _rock_mesh()
		"crystal":
			m = _crystal_mesh()
		"crescent":
			m = _crescent_mesh()
		"streak":
			m = _streak_mesh()
	_meshes[kind] = m
	return m


## Roca low-poly irregular con sombreado plano (radio ~0.5).
static func _rock_mesh() -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 7
	sm.rings = 4
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in v.size():
		var p := v[i]
		# Desplazamiento determinista por posición: las costuras siguen cerradas
		var f := 1.0 + 0.2 * sin(p.x * 13.1 + p.y * 7.7 + p.z * 5.3) + 0.12 * cos(p.z * 11.0 - p.x * 6.0)
		v[i] = Vector3(p.x * f, p.y * f * 0.85, p.z * f)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, idx.size(), 3):
		_tri(st, v[idx[t]], v[idx[t + 1]], v[idx[t + 2]])
	return st.commit()


## Cristal de hielo: punta larga hacia +X, base corta hacia -X, 6 caras.
static func _crystal_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0.3, 0, 0)
	var back := Vector3(-0.14, 0, 0)
	var ring: Array = []
	for i in 6:
		var a := i * TAU / 6.0
		ring.append(Vector3(0.0, cos(a) * 0.07, sin(a) * 0.07))
	for i in 6:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i + 1) % 6]
		_tri(st, tip, p1, p0)
		_tri(st, back, p0, p1)
	return st.commit()


## Media luna plana (plano XZ), abombada hacia +X, con alfa en las puntas.
static func _crescent_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var prev_o := Vector3.ZERO
	var prev_i := Vector3.ZERO
	var prev_a := 0.0
	for i in n + 1:
		var t := float(i) / n
		var ang := lerpf(-1.25, 1.25, t)
		var thick := sin(t * PI)
		var o := Vector3(cos(ang) * 0.34 - 0.2, 0, sin(ang) * 0.34)
		var inn := Vector3(cos(ang) * (0.34 - 0.13 * thick) - 0.2 - 0.05 * thick, 0, sin(ang) * (0.34 - 0.13 * thick))
		var al := clampf(thick * 1.6, 0.0, 1.0)
		if i > 0:
			_ctri(st, prev_o, o, prev_i, prev_a, al, prev_a * 0.5)
			_ctri(st, o, inn, prev_i, al, al * 0.5, prev_a * 0.5)
		prev_o = o
		prev_i = inn
		prev_a = al
	return st.commit()


## Estela: dos planos cruzados a lo largo de -X (0 -> -1), alfa 1 delante y 0 detrás.
static func _streak_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plane in 2:
		var side := Vector3(0, 0.5, 0) if plane == 0 else Vector3(0, 0, 0.5)
		var a := Vector3.ZERO + side
		var b := Vector3.ZERO - side
		var c := Vector3(-1, 0, 0) + side * 0.3
		var d := Vector3(-1, 0, 0) - side * 0.3
		_ctri(st, a, b, c, 1.0, 1.0, 0.0)
		_ctri(st, b, d, c, 1.0, 0.0, 0.0)
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (c - a).cross(b - a).normalized()
	st.set_normal(n)
	st.add_vertex(a)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_normal(n)
	st.add_vertex(c)


static func _ctri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, aa: float, ab: float, ac: float) -> void:
	st.set_normal(Vector3.UP)
	st.set_color(Color(1, 1, 1, aa))
	st.add_vertex(a)
	st.set_color(Color(1, 1, 1, ab))
	st.add_vertex(b)
	st.set_color(Color(1, 1, 1, ac))
	st.add_vertex(c)


# ================================================================ Materiales
static func _base_fx_mat(texname: String, add: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.set("disable_fog", true)
	if texname != "":
		m.albedo_texture = tex(texname)
	return m


## Material de partículas billboard (el color sale de la partícula).
static func pmat(texname: String, add := true) -> StandardMaterial3D:
	var key := "p|%s|%s" % [texname, add]
	if _mats.has(key):
		return _mats[key]
	var m := _base_fx_mat(texname, add)
	m.vertex_color_use_as_albedo = true
	# BILLBOARD_PARTICLES ignora la escala de cada partícula en GL Compatibility (4.3):
	# BILLBOARD_ENABLED + keep_scale sí la respeta.
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	_mats[key] = m
	return m


## Material aditivo para mallas de partículas sin billboard (chispas alargadas).
static func pmat_mesh_add() -> StandardMaterial3D:
	if _mats.has("pmadd"):
		return _mats["pmadd"]
	var m := _base_fx_mat("", true)
	m.vertex_color_use_as_albedo = true
	_mats["pmadd"] = m
	return m


## Arcilla opaca con luz para partículas de malla (humo, polvo, astillas, monedas).
static func clay(gloss := false) -> StandardMaterial3D:
	var key := "clay|%s" % gloss
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.25 if gloss else 1.0
	if gloss:
		m.metallic = 0.3
		m.metallic_specular = 0.9
	_mats[key] = m
	return m


## Billboard estático (malla individual) con color fijo; cacheado por color.
static func bill_mat(texname: String, color: Color, add := true) -> StandardMaterial3D:
	var key := "b|%s|%s|%s" % [texname, color.to_html(), add]
	if _mats.has(key):
		return _mats[key]
	var m := new_bill_mat(texname, color, add)
	_mats[key] = m
	return m


## Billboard con material propio (para animar su alfa).
static func new_bill_mat(texname: String, color: Color, add := true, on_top := false) -> StandardMaterial3D:
	var m := _base_fx_mat(texname, add)
	m.no_depth_test = on_top
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	return m


## Material plano (decal en el suelo, columnas) con material propio para animar alfa.
static func new_flat_mat(texname: String, color: Color, add := true) -> StandardMaterial3D:
	var m := _base_fx_mat(texname, add)
	m.albedo_color = color
	return m


## Material para mallas con alfa por vértice (estelas, media luna).
static func vcol_add(color: Color) -> StandardMaterial3D:
	var key := "vc|%s" % color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := _base_fx_mat("", true)
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	_mats[key] = m
	return m


## Material del rayo encadenado (ImmediateMesh con color por vértice). Uno por rayo: anima alfa.
static func new_lightning_mat() -> StandardMaterial3D:
	var m := _base_fx_mat("soft", true)
	m.vertex_color_use_as_albedo = true
	return m


# ================================================================ Gradientes y curvas
static func grad(kind: String) -> Gradient:
	if _grads.has(kind):
		return _grads[kind]
	var g := Gradient.new()
	var pts: Array = []
	match kind:
		"fade": pts = [0.0, Color(1, 1, 1, 1), 0.55, Color(1, 1, 1, 0.75), 1.0, Color(1, 1, 1, 0)]
		"fadein": pts = [0.0, Color(1, 1, 1, 0), 0.15, Color(1, 1, 1, 1), 0.6, Color(1, 1, 1, 0.7), 1.0, Color(1, 1, 1, 0)]
		"fire": pts = [0.0, Color(1, 0.95, 0.6, 1), 0.2, Color(1, 0.65, 0.15, 1), 0.55, Color(0.95, 0.28, 0.05, 0.8), 1.0, Color(0.35, 0.08, 0.04, 0)]
		"rocket": pts = [0.0, Color(1, 0.95, 0.6), 0.12, Color(1, 0.55, 0.15), 0.35, Color(0.45, 0.42, 0.4), 1.0, Color(0.82, 0.8, 0.78)]
		"smoke": pts = [0.0, Color(0.5, 0.46, 0.44), 1.0, Color(0.78, 0.76, 0.74)]
		"frost": pts = [0.0, Color(1, 1, 1, 1), 0.5, Color(0.7, 0.92, 1, 0.8), 1.0, Color(0.45, 0.75, 1, 0)]
		"gold": pts = [0.0, Color(1, 1, 0.85, 1), 0.45, Color(1, 0.8, 0.3, 1), 1.0, Color(1, 0.5, 0.1, 0)]
		"void": pts = [0.0, Color(0.55, 0.25, 0.85), 0.5, Color(0.25, 0.08, 0.4), 1.0, Color(0.08, 0.02, 0.12)]
		"build": pts = [0.0, Color(0.62, 0.42, 0.24), 0.35, Color(0.48, 0.32, 0.18), 0.55, Color(0.62, 0.6, 0.58), 0.8, Color(0.75, 0.72, 0.68), 1.0, Color(0.5, 0.48, 0.46)]
		"gems": pts = [0.0, Color(1, 0.2, 0.3), 0.2, Color(0.25, 0.55, 1), 0.4, Color(0.3, 1, 0.45), 0.6, Color(0.8, 0.35, 1), 0.8, Color(0.3, 0.95, 1), 1.0, Color(1, 0.2, 0.3)]
		_: pts = [0.0, Color.WHITE, 1.0, Color.WHITE]
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in range(0, pts.size(), 2):
		offs.append(float(pts[i]))
		cols.append(pts[i + 1])
	g.offsets = offs
	g.colors = cols
	if kind == "gems":
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	_grads[kind] = g
	return g


static func curve(kind: String) -> Curve:
	if _curves.has(kind):
		return _curves[kind]
	var c := Curve.new()
	match kind:
		"shrink":
			c.add_point(Vector2(0, 1))
			c.add_point(Vector2(1, 0))
		"pop":
			c.add_point(Vector2(0, 0.3))
			c.add_point(Vector2(0.15, 1))
			c.add_point(Vector2(1, 0))
		"puff":
			c.add_point(Vector2(0, 0.35))
			c.add_point(Vector2(0.3, 1))
			c.add_point(Vector2(1, 0))
		"grow":
			c.add_point(Vector2(0, 0.35))
			c.add_point(Vector2(1, 1))
		"hold":
			c.add_point(Vector2(0, 1))
			c.add_point(Vector2(0.75, 1))
			c.add_point(Vector2(1, 0))
		_:
			c.add_point(Vector2(0, 1))
			c.add_point(Vector2(1, 1))
	_curves[kind] = c
	return c


# ================================================================ Partículas
## Emisor CPU genérico (coordenadas de mundo). El llamador ajusta el resto.
static func particles(parent: Node3D, mesh_kind: String, material: Material, amount: int, lifetime: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = mesh(mesh_kind)
	p.material_override = material
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gravity = Vector3.ZERO
	p.spread = 180.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	# Arranque diferido: set_emitting(true) emite al instante con la configuración
	# de ese momento, así que se activa cuando el llamador ya terminó de configurarlo
	# (y la vista ya está colocada en su sitio).
	p.emitting = false
	parent.add_child(p)
	p.set_deferred("emitting", true)
	return p


## Billboard individual (brillos fijos de los proyectiles).
## add = false -> mezcla alfa (el color se lee bien sobre el suelo claro);
## add = true -> aditivo (sólo para núcleos calientes y chispas pequeñas).
static func bill(parent: Node3D, texname: String, color: Color, size: float, pos := Vector3.ZERO, add := false, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh("quad")
	mi.material_override = material if material != null else bill_mat(texname, color, add)
	mi.scale = Vector3.ONE * size
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Elemento de daño a partir del color (el juego sólo pasa el color a Fx).
static func element_of(c: Color) -> String:
	var key := c.to_rgba32()
	if _elements.has(key):
		return _elements[key]
	var best := "physical"
	var bd := 99.0
	for k in GameData.DAMAGE_TYPES:
		var dc: Color = GameData.DAMAGE_TYPES[k]["color"]
		var d := absf(dc.r - c.r) + absf(dc.g - c.g) + absf(dc.b - c.b)
		if d < bd:
			bd = d
			best = k
	_elements[key] = best
	return best


## Suelta las estelas de un proyectil en el mundo para que se desvanezcan solas.
static func release_trails(view: Node3D, world: Node3D) -> void:
	if view == null or not view.has_meta("trails") or world == null or not world.is_inside_tree():
		return
	var trails: Array = view.get_meta("trails")
	for t in trails:
		var p := t as CPUParticles3D
		if p == null or not is_instance_valid(p):
			continue
		p.reparent(world, true)
		p.emitting = false
		world.get_tree().create_timer(p.lifetime + 0.1, false).timeout.connect(p.queue_free)
	view.remove_meta("trails")


# ================================================================ Proyectiles
static func build_projectile(style: String, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Proj"
	var spin := Node3D.new()
	spin.name = "Spin"
	root.add_child(spin)
	var trails: Array = []
	var rate := Vector3.ZERO
	var pulse: Node3D = null
	match style:
		"arrow":
			_arrow(root, spin, 1.0, Color(0.96, 0.94, 0.88), Color(0.8, 0.18, 0.14), STEEL, false)
			_streak(root, Color(1, 1, 1, 0.35), 0.55, 0.05)
			rate = Vector3(22, 0, 0)
		"arrow_poison":
			_arrow(root, spin, 1.0, Color(0.35, 0.6, 0.25), Color(0.2, 0.35, 0.15), Color(0.5, 1.0, 0.3), true)
			pulse = Node3D.new()
			pulse.position = Vector3(0.25, 0, 0)
			root.add_child(pulse)
			bill(pulse, "glow", Color(0.3, 0.9, 0.15, 0.85), 0.3)
			bill(pulse, "glow", Color(0.8, 1.0, 0.6, 0.8), 0.12, Vector3.ZERO, true)
			var tp := particles(root, "quad", pmat("glow", false), 16, 0.45, false)
			tp.position = Vector3(0.2, 0, 0)
			tp.color = Color(0.3, 0.85, 0.15, 0.7)
			tp.color_ramp = grad("fade")
			tp.scale_amount_min = 0.12
			tp.scale_amount_max = 0.2
			tp.scale_amount_curve = curve("shrink")
			tp.gravity = Vector3(0, -1.2, 0)
			trails.append(tp)
			rate = Vector3(18, 0, 0)
		"bolt":
			_arrow(root, spin, 1.45, Color(0.55, 0.38, 0.22), Color(0.3, 0.3, 0.32), IRON, false)
			V3.cyl(0.03, 0.03, 0.03, IRON, Vector3(0.12, 0, 0), 0.0, spin, 6).rotation.z = PI * 0.5
			_streak(root, Color(1, 0.97, 0.9, 0.4), 0.8, 0.07)
			rate = Vector3(14, 0, 0)
		"rock":
			var r := MeshInstance3D.new()
			r.mesh = mesh("rock")
			r.material_override = V3.mat(Color(0.52, 0.48, 0.44))
			r.scale = Vector3.ONE * 0.3
			spin.add_child(r)
			# Musgo y grietas: un par de bultos de arcilla más oscuros
			V3.sphere(0.05, Color(0.42, 0.5, 0.3), Vector3(0.06, 0.09, 0.03), 0.0, spin)
			V3.sphere(0.04, Color(0.4, 0.37, 0.34), Vector3(-0.08, -0.05, 0.09), 0.0, spin)
			var dust := particles(root, "ball", clay(), 9, 0.55, false)
			dust.color = Color(0.72, 0.64, 0.52)
			dust.color_initial_ramp = grad("smoke")
			dust.scale_amount_min = 0.06
			dust.scale_amount_max = 0.1
			dust.scale_amount_curve = curve("puff")
			dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			dust.emission_sphere_radius = 0.1
			dust.initial_velocity_max = 0.25
			trails.append(dust)
			rate = Vector3(7, 3, 9)
		"flask":
			var glass := Color(0.85, 0.95, 1.0, 0.28)
			var liquid := color.lerp(Color(0.45, 1.0, 0.35), 0.5)
			V3.sphere(0.075, liquid, Vector3(-0.01, 0, 0), 1.6, spin)
			V3.sphere(0.1, glass, Vector3.ZERO, 0.0, spin)
			V3.cyl(0.03, 0.035, 0.08, glass, Vector3(0, 0.12, 0), 0.0, spin, 8)
			V3.cyl(0.032, 0.028, 0.045, Color(0.6, 0.42, 0.25), Vector3(0, 0.18, 0), 0.0, spin, 8)
			V3.sphere(0.022, Color(1, 1, 1, 0.8), Vector3(-0.04, 0.05, 0.06), 0.0, spin)
			pulse = Node3D.new()
			root.add_child(pulse)
			bill(pulse, "glow", Color(liquid, 0.7), 0.42)
			var drip := particles(root, "quad", pmat("glow", false), 10, 0.4, false)
			drip.color = Color(liquid.darkened(0.15), 0.85)
			drip.color_ramp = grad("fade")
			drip.scale_amount_min = 0.1
			drip.scale_amount_max = 0.16
			drip.scale_amount_curve = curve("shrink")
			drip.gravity = Vector3(0, -3.0, 0)
			trails.append(drip)
			rate = Vector3(4, 0, 10)
		"fireball", "fire":
			var k := 1.0 if style == "fireball" else 0.72
			V3.sphere(0.1 * k, Color(1.0, 0.72, 0.25), Vector3.ZERO, 2.2, root)
			pulse = Node3D.new()
			root.add_child(pulse)
			bill(pulse, "glow", Color(0.95, 0.28, 0.04, 0.8), 0.62 * k, Vector3(-0.03, 0, 0))
			bill(pulse, "glow", Color(1.0, 0.58, 0.1, 0.95), 0.4 * k)
			bill(pulse, "glow", Color(1.0, 0.85, 0.45, 0.8), 0.22 * k, Vector3(0.02, 0, 0), true)
			# Lenguas de fuego que giran alrededor (en Spin)
			for i in 3:
				var a := i * TAU / 3.0
				bill(spin, "glow", Color(1.0, 0.42, 0.06, 0.85), 0.2 * k, Vector3(-0.04, cos(a) * 0.07 * k, sin(a) * 0.07 * k))
			var fl := particles(root, "quad", pmat("glow", false), 22, 0.34, false)
			fl.color = Color(1, 1, 1, 0.85)
			fl.color_ramp = grad("fire")
			fl.scale_amount_min = 0.3 * k
			fl.scale_amount_max = 0.45 * k
			fl.scale_amount_curve = curve("shrink")
			fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			fl.emission_sphere_radius = 0.06 * k
			fl.gravity = Vector3(0, 1.0, 0)
			trails.append(fl)
			var em := particles(root, "quad", pmat("star"), 6, 0.55, false)
			em.color = Color(1.0, 0.6, 0.2, 0.8)
			em.color_ramp = grad("fire")
			em.scale_amount_min = 0.08
			em.scale_amount_max = 0.13
			em.initial_velocity_min = 0.3
			em.initial_velocity_max = 0.8
			em.gravity = Vector3(0, 0.9, 0)
			trails.append(em)
			rate = Vector3(9, 0, 0)
		"ice":
			var c := MeshInstance3D.new()
			c.mesh = mesh("crystal")
			c.material_override = V3.mat(Color(0.55, 0.85, 1.0), 0.3)
			c.scale = Vector3.ONE * 1.1
			spin.add_child(c)
			for i in 2:
				var s := MeshInstance3D.new()
				s.mesh = c.mesh
				s.material_override = V3.mat(Color(0.75, 0.93, 1.0), 0.35)
				s.scale = Vector3.ONE * 0.5
				s.position = Vector3(-0.05, 0.06 if i == 0 else -0.06, 0.03 if i == 0 else -0.03)
				s.rotation = Vector3(0, 0, 0.5 if i == 0 else -0.5)
				spin.add_child(s)
			bill(root, "glow", Color(0.3, 0.65, 1.0, 0.7), 0.42)
			var fr := particles(root, "quad", pmat("star"), 12, 0.45, false)
			fr.color = Color(0.6, 0.85, 1.0, 0.9)
			fr.color_ramp = grad("frost")
			fr.scale_amount_min = 0.1
			fr.scale_amount_max = 0.16
			fr.scale_amount_curve = curve("pop")
			fr.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			fr.emission_sphere_radius = 0.08
			fr.initial_velocity_max = 0.3
			fr.gravity = Vector3(0, -0.4, 0)
			trails.append(fr)
			rate = Vector3(10, 0, 0)
		"rocket":
			var body := V3.cyl(0.042, 0.042, 0.24, Color(0.78, 0.16, 0.12), Vector3.ZERO, 0.0, spin, 8)
			body.rotation.z = PI * 0.5
			V3.cyl(0.045, 0.045, 0.035, Color(0.95, 0.9, 0.8), Vector3(0.05, 0, 0), 0.0, spin, 8).rotation.z = PI * 0.5
			V3.cyl(0.0, 0.045, 0.1, GOLD, Vector3(0.17, 0, 0), 0.3, spin, 8).rotation.z = -PI * 0.5
			for i in 4:
				var a := i * TAU / 4.0
				var f := V3.box(Vector3(0.08, 0.07, 0.012), Color(0.3, 0.3, 0.34), Vector3(-0.1, cos(a) * 0.055, sin(a) * 0.055), 0.0, spin)
				f.rotation.x = a
			pulse = Node3D.new()
			pulse.position = Vector3(-0.16, 0, 0)
			root.add_child(pulse)
			bill(pulse, "glow", Color(1.0, 0.5, 0.08, 0.9), 0.32)
			bill(pulse, "glow", Color(1.0, 0.85, 0.5, 0.8), 0.12, Vector3.ZERO, true)
			var sm := particles(root, "ball", clay(), 24, 0.7, false)
			sm.position = Vector3(-0.16, 0, 0)
			sm.color = Color.WHITE
			sm.color_ramp = grad("rocket")
			sm.scale_amount_min = 0.08
			sm.scale_amount_max = 0.14
			sm.scale_amount_curve = curve("puff")
			sm.initial_velocity_max = 0.25
			sm.gravity = Vector3(0, 0.35, 0)
			trails.append(sm)
			rate = Vector3(12, 0, 0)
		"void":
			V3.sphere(0.09, Color(0.06, 0.02, 0.1), Vector3.ZERO, 0.0, root)
			bill(root, "glow", Color(0.5, 0.12, 0.85, 0.75), 0.42)
			bill(root, "ring", Color(0.8, 0.45, 1.0, 0.9), 0.26)
			var ring := V3.torus(0.12, 0.14, Color(0.7, 0.35, 1.0), Vector3.ZERO, 2.5, spin)
			ring.rotation = Vector3(0.6, 0, 0.4)
			var vt := particles(root, "ball", clay(), 14, 0.45, false)
			vt.color = Color.WHITE
			vt.color_ramp = grad("void")
			vt.scale_amount_min = 0.07
			vt.scale_amount_max = 0.12
			vt.scale_amount_curve = curve("shrink")
			vt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			vt.emission_sphere_radius = 0.07
			trails.append(vt)
			var vs := particles(root, "quad", pmat("star"), 6, 0.4, false)
			vs.color = Color(0.75, 0.4, 1.0, 0.8)
			vs.color_ramp = grad("fade")
			vs.scale_amount_min = 0.1
			vs.scale_amount_max = 0.15
			vs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			vs.emission_sphere_radius = 0.12
			trails.append(vs)
			rate = Vector3(3, 9, 2)
		"holy":
			V3.sphere(0.07, Color(1.0, 0.98, 0.85), Vector3.ZERO, 3.0, root)
			bill(root, "glow", Color(1.0, 0.72, 0.15, 0.8), 0.5)
			pulse = Node3D.new()
			root.add_child(pulse)
			bill(pulse, "star", Color(1.0, 0.9, 0.6, 0.85), 0.34, Vector3.ZERO, true)
			var halo := V3.torus(0.15, 0.17, GOLD, Vector3(0, 0.0, 0), 2.5, spin)
			halo.rotation.x = 0.35
			var hs := particles(root, "quad", pmat("star", false), 14, 0.5, false)
			hs.color = Color(1, 0.8, 0.3)
			hs.color_ramp = grad("gold")
			hs.scale_amount_min = 0.1
			hs.scale_amount_max = 0.16
			hs.scale_amount_curve = curve("pop")
			hs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			hs.emission_sphere_radius = 0.1
			hs.gravity = Vector3(0, 0.6, 0)
			trails.append(hs)
			rate = Vector3(0, 4, 0)
		"slash":
			var cr := MeshInstance3D.new()
			cr.mesh = mesh("crescent")
			cr.material_override = vcol_add(Color(0.75, 0.85, 1.0, 0.85))
			cr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cr.scale = Vector3(1.0, 1.0, 1.3)
			spin.add_child(cr)
			var cr2 := MeshInstance3D.new()
			cr2.mesh = cr.mesh
			cr2.material_override = vcol_add(Color(0.3, 0.5, 1.0, 0.5))
			cr2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cr2.scale = Vector3(1.25, 1.0, 1.55)
			cr2.position = Vector3(-0.06, 0, 0)
			spin.add_child(cr2)
			_streak(root, Color(0.6, 0.75, 1.0, 0.2), 0.45, 0.22)
			rate = Vector3(6, 0, 0)
		_:
			# "orb" y cualquier otro: orbe arcano con chispas orbitando
			var col := color.lerp(Color.WHITE, 0.15)
			V3.sphere(0.08, col, Vector3.ZERO, 1.5, root)
			bill(root, "glow", Color(col, 0.85), 0.5)
			bill(root, "glow", Color(col.lerp(Color.WHITE, 0.5), 0.6), 0.16, Vector3.ZERO, true)
			for i in 2:
				bill(spin, "star", Color(col.lerp(Color.WHITE, 0.4), 0.9), 0.14, Vector3(0, 0.15 if i == 0 else -0.15, 0), true)
			var ot := particles(root, "quad", pmat("glow", false), 16, 0.4, false)
			ot.color = Color(col, 0.75)
			ot.color_ramp = grad("fade")
			ot.scale_amount_min = 0.14
			ot.scale_amount_max = 0.22
			ot.scale_amount_curve = curve("shrink")
			trails.append(ot)
			rate = Vector3(12, 0, 0)
	_no_shadows(root, style in ["rock", "flask", "rocket"])
	root.set_meta("spin", spin)
	root.set_meta("spin_rate", rate)
	if pulse != null:
		root.set_meta("pulse", pulse)
	if not trails.is_empty():
		_stretch_emission(trails)
		root.set_meta("trails", trails)
	return root


## Las CPUParticles no interpolan la posición de emisión entre fotogramas: a x3 las
## estelas saldrían en grumos con huecos. Emitir desde una caja alargada en el eje de
## vuelo (+X local) rellena el tramo recorrido en cada fotograma.
static func _stretch_emission(trails: Array) -> void:
	for t in trails:
		var p: CPUParticles3D = t
		var rr := 0.02
		if p.emission_shape == CPUParticles3D.EMISSION_SHAPE_SPHERE:
			rr = p.emission_sphere_radius
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(0.14, rr, rr)


## Flecha / virote: astil, punta y 3 plumas. k escala (virote = 1.45).
static func _arrow(root: Node3D, spin: Node3D, k: float, feather: Color, feather2: Color, head_col: Color, glow_head: bool) -> void:
	var shaft := V3.cyl(0.018 * k, 0.018 * k, 0.42 * k, WOOD, Vector3(-0.02 * k, 0, 0), 0.0, spin, 5)
	shaft.rotation.z = PI * 0.5
	var head := V3.cyl(0.0, 0.045 * k, 0.12 * k, head_col, Vector3(0.24 * k, 0, 0), 2.2 if glow_head else 0.0, spin, 4)
	head.rotation.z = -PI * 0.5
	for i in 3:
		var a := i * TAU / 3.0 + 0.3
		var f := V3.box(Vector3(0.13 * k, 0.06 * k, 0.01), feather2 if i == 0 else feather, Vector3(-0.19 * k, cos(a) * 0.035 * k, sin(a) * 0.035 * k), 0.0, spin)
		f.rotation.x = a
	V3.box(Vector3(0.025 * k, 0.03 * k, 0.03 * k), WOOD_DARK, Vector3(-0.24 * k, 0, 0), 0.0, spin)


static func _streak(root: Node3D, color: Color, length: float, width: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh("streak")
	mi.material_override = vcol_add(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(length, width, width)
	mi.position = Vector3(-0.12, 0, 0)
	root.add_child(mi)


## Los proyectiles no proyectan sombra salvo la pieza principal de los que vuelan en arco
## (la sombra en el suelo ayuda a leer la parábola).
static func _no_shadows(n: Node, keep_first: bool) -> void:
	var kept := not keep_first
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for ch in cur.get_children():
			stack.append(ch)
			var gi := ch as GeometryInstance3D
			if gi != null:
				if not kept and gi is MeshInstance3D and gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					kept = true
					continue
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
