class_name EnemyModels
extends RefCounted
## Modelos 3D de los enemigos, estilo plastilina low-poly, construidos por código.
##
## build() devuelve una raíz (script enemy_anim.gd) que mira hacia +X con el origen a los pies
## (los voladores, en el centro del cuerpo). Dentro va "Body" (el juego lo escala al recibir
## daño y lo hace girar al aturdirse), y dentro "Rig", escalado por el radio del enemigo.
## Todo se modela en "unidades de radio" (r = 1): un humanoide normal mide unas 2.5 unidades.
##
## Rendimiento: la primera vez que aparece cada tipo se construye su modelo con muchas piezas
## y se "hornea" en unas pocas mallas (una para el cuerpo fijo y una por cada pieza articulada:
## piernas, brazos, cola, alas...). Las mallas usan color por vértice, así que cada una tiene
## como mucho 4 superficies (plastilina, metal, brillo y translúcido) compartidas por TODOS los
## enemigos. Las siguientes apariciones solo instancian esas mallas cacheadas.

const Anim := preload("res://scripts/game/enemy_anim.gd")
const Textures := preload("res://scripts/towers3d/textures.gd")
const Models := preload("res://scripts/towers3d/models.gd")

enum { CLAY, METAL, GLOW, GHOST }

const DARK := Color(0.07, 0.05, 0.06)
const WHITE := Color(0.96, 0.95, 0.9)
const BONE := Color(0.9, 0.87, 0.78)
const WOOD := Color(0.45, 0.3, 0.17)
const WOOD_DARK := Color(0.3, 0.2, 0.12)
const LEATHER := Color(0.38, 0.24, 0.14)
const IRON := Color(0.6, 0.62, 0.66)
const STEEL := Color(0.78, 0.8, 0.84)
const GOLD := Color(1.0, 0.78, 0.25)
const SKIN := Color(0.93, 0.74, 0.6)
const ROPE := Color(0.72, 0.6, 0.4)
const RED_GLOW := Color(1.0, 0.25, 0.15)
const FIRE := Color(1.0, 0.55, 0.12)
const FIRE_HOT := Color(1.0, 0.85, 0.35)
const ICE := Color(0.7, 0.9, 1.0)
const ICE_GLOW := Color(0.55, 0.9, 1.0)
const GREEN_GLOW := Color(0.45, 1.0, 0.55)
const PURPLE_GLOW := Color(0.85, 0.45, 1.0)
const ELITE := Color(1.0, 0.3, 0.9)

# Pistas de animación (ver enemy_anim.gd)
const ROT := 0
const POS := 1
const SCL := 2
const SINE := 0
const BOUNCE := 1
const FLICKER := 2
const SPIN := 3
const WALK := 9.0  # mismo ritmo que el saltito de pasos del juego (sin(anim * 9))

static var _templates := {}
static var _mats := {}
static var _meshes := {}
static var _LOW := OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--low-poly") # móvil: menos polígonos


# ================================================================ API

static func build(id: String, def: Dictionary, r: float, elite: bool) -> Node3D:
	var tpl: Dictionary
	if _templates.has(id):
		tpl = _templates[id]
	else:
		tpl = _make_template(def)
		_templates[id] = tpl
	var root: Node3D = Anim.new()
	root.name = "Enemy"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var rig := Node3D.new()
	rig.name = "Rig"
	rig.scale = Vector3.ONE * r
	body.add_child(rig)
	if tpl["static"] != null:
		var mi := MeshInstance3D.new()
		mi.mesh = tpl["static"]
		rig.add_child(mi)
	var nodes: Array = []
	for part in tpl["parts"]:
		var n := Node3D.new()
		n.name = part["name"]
		var parent: Node3D = rig
		var pi: int = part["parent"]
		if pi >= 0:
			parent = nodes[pi]
		var xf: Transform3D = part["xform"]
		if part["wing"] and pi < 0:
			# Las alas cuelgan de Body (el juego las busca ahí) con la escala del rig
			parent = body
			xf = Transform3D(Basis.from_scale(Vector3.ONE * r), Vector3.ZERO) * xf
		parent.add_child(n)
		n.transform = xf
		if part["mesh"] != null:
			var pm := MeshInstance3D.new()
			pm.mesh = part["mesh"]
			n.add_child(pm)
		nodes.append(n)
		for tr in part["tracks"]:
			root.add_track(n, tr[0], tr[1], tr[2], tr[3], tr[4], tr[5], tr[6])
	if elite:
		var ring := MeshInstance3D.new()
		ring.mesh = _elite_ring()
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.scale = Vector3.ONE * r
		ring.position.y = 0.03 - (1.15 if def.get("flying", false) else 0.0)
		root.add_child(ring)
		root.add_track(ring, ROT, 1, 1.0, 1.2, 0.0, false, SPIN)
	return root


## Libera las plantillas cacheadas (p. ej. al cambiar de mapa si se quiere ahorrar memoria).
static func clear_cache() -> void:
	_templates.clear()


# ================================================================ Plantillas

static func _make_template(def: Dictionary) -> Dictionary:
	var rig := Node3D.new()
	var o := _recipe(def)
	_build_kind(rig, o)
	var tpl := {"static": _bake_owner(rig), "parts": []}
	_collect_parts(rig, rig, -1, tpl["parts"])
	rig.free()
	return tpl


static func _collect_parts(node: Node, anchor: Node3D, parent_idx: int, parts: Array) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		if child.has_meta("pivot"):
			var idx := parts.size()
			parts.append({
				"name": String(child.name),
				"parent": parent_idx,
				"xform": _rel_xform(child, anchor),
				"mesh": _bake_owner(child),
				"tracks": child.get_meta("tracks", []),
				"wing": String(child.name).begins_with("Wing"),
			})
			_collect_parts(child, child, idx, parts)
		elif not child is MeshInstance3D:
			_collect_parts(child, anchor, parent_idx, parts)


static func _rel_xform(node: Node3D, anchor: Node3D) -> Transform3D:
	var xf := node.transform
	var p := node.get_parent()
	while p != anchor and p != null:
		xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Fusiona las piezas de `owner` (sin entrar en sus sub-articulaciones) en una malla
## con color por vértice y una superficie por tipo de material.
static func _bake_owner(owner: Node3D) -> ArrayMesh:
	var groups := {}
	_collect_geo(owner, Transform3D.IDENTITY, groups)
	if groups.is_empty():
		return null
	var mesh := ArrayMesh.new()
	for k in [CLAY, METAL, GHOST, GLOW]:
		if not groups.has(k):
			continue
		var g: Array = groups[k]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g[0]
		arrays[Mesh.ARRAY_NORMAL] = g[1]
		arrays[Mesh.ARRAY_COLOR] = g[2]
		arrays[Mesh.ARRAY_INDEX] = g[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(k))
	return Models.facet(mesh) as ArrayMesh # estilo low-poly de caras planas


static func _collect_geo(node: Node, parent_xf: Transform3D, groups: Dictionary) -> void:
	for child in node.get_children():
		if child.has_meta("pivot") or not child is Node3D:
			continue
		var xf: Transform3D = parent_xf * (child as Node3D).transform
		if child is MeshInstance3D and child.has_meta("c"):
			_append(groups, (child as MeshInstance3D).mesh, xf, child.get_meta("c"), child.get_meta("k"))
		_collect_geo(child, xf, groups)


static func _append(groups: Dictionary, mesh: Mesh, xf: Transform3D, col: Color, k: int) -> void:
	if not groups.has(k):
		groups[k] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedInt32Array()]
	var g: Array = groups[k]
	var vs: PackedVector3Array = g[0]
	var ns: PackedVector3Array = g[1]
	var cs: PackedColorArray = g[2]
	var ids: PackedInt32Array = g[3]
	var nb := xf.basis.inverse().transposed()
	var flip := xf.basis.determinant() < 0.0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var base := vs.size()
		vs.append_array(xf * verts)
		for nv in norms:
			ns.append((nb * nv).normalized())
		var c0 := cs.size()
		cs.resize(c0 + verts.size())
		for i in verts.size():
			cs[c0 + i] = col
		var src = arr[Mesh.ARRAY_INDEX]
		if src != null and (src as PackedInt32Array).size() > 0:
			var si: PackedInt32Array = src
			if flip:
				for i in range(0, si.size(), 3):
					ids.append(base + si[i])
					ids.append(base + si[i + 2])
					ids.append(base + si[i + 1])
			else:
				for i in si:
					ids.append(base + i)
		else:
			for i in verts.size():
				ids.append(base + i)
	g[0] = vs
	g[1] = ns
	g[2] = cs
	g[3] = ids


static func _material(k: int) -> Material:
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true # Forward+: colores de vértice en sRGB
	m.vertex_color_is_srgb = true
	match k:
		CLAY, METAL:
			# Papel mate (estilo low-poly de caras planas): sin relieve ni contorno
			m.roughness = 0.95 if k == CLAY else 0.5
			m.metallic = 0.0 if k == CLAY else 0.2
			m.metallic_specular = 0.2 if k == CLAY else 0.5
		GLOW:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		GHOST:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.4
			m.rim_enabled = true
			m.rim = 0.5
			m.rim_tint = 0.2
			m.emission_enabled = true
			m.emission = Color(0.35, 0.35, 0.4)
			m.emission_energy_multiplier = 0.6
	_mats[k] = m
	return m


static func _elite_ring() -> Mesh:
	if not _meshes.has("elite_ring"):
		var t := TorusMesh.new()
		t.inner_radius = 1.25
		t.outer_radius = 1.5
		t.rings = 24
		t.ring_segments = 6
		var mesh := ArrayMesh.new()
		var arr := t.surface_get_arrays(0)
		var cols := PackedColorArray()
		cols.resize((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		cols.fill(ELITE)
		arr[Mesh.ARRAY_COLOR] = cols
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, _material(GLOW))
		_meshes["elite_ring"] = mesh
	return _meshes["elite_ring"]


# ================================================================ Piezas (unidades de radio)

static func _cyl_mesh(top: float, bot: float, h: float, segs: int) -> Mesh:
	segs = Models.seg_count(segs)
	var key := "c%.3f|%.3f|%.3f|%d" % [top, bot, h, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bot
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func _sph_mesh(rad: float, segs: int) -> Mesh:
	segs = Models.seg_count(segs)
	var key := "s%.3f|%d" % [rad, segs]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = rad
		m.height = rad * 2.0
		m.radial_segments = segs
		m.rings = maxi(segs / 2, 4)
		_meshes[key] = m
	return _meshes[key]


static func _m(p: Node3D, mesh: Mesh, col: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, k := CLAY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.set_meta("c", col)
	mi.set_meta("k", k)
	p.add_child(mi)
	return mi


static func _sph(p: Node3D, rad: float, col: Color, pos: Vector3, scl := Vector3.ONE, k := CLAY, segs := 10) -> MeshInstance3D:
	return _m(p, _sph_mesh(rad, segs), col, pos, Vector3.ZERO, scl, k)


static func _box(p: Node3D, size: Vector3, col: Color, pos: Vector3, rot := Vector3.ZERO, k := CLAY) -> MeshInstance3D:
	return _m(p, Models.box_mesh(size), col, pos, rot, Vector3.ONE, k)


static func _cyl(p: Node3D, top: float, bot: float, h: float, col: Color, pos: Vector3, rot := Vector3.ZERO, k := CLAY, segs := 10) -> MeshInstance3D:
	return _m(p, _cyl_mesh(top, bot, h, segs), col, pos, rot, Vector3.ONE, k)


static func _cone(p: Node3D, rad: float, h: float, col: Color, pos: Vector3, rot := Vector3.ZERO, k := CLAY, segs := 8) -> MeshInstance3D:
	return _m(p, _cyl_mesh(0.0, rad, h, segs), col, pos, rot, Vector3.ONE, k)


## Tramo (cilindro o cono truncado) del punto a (radio ra) al punto b (radio rb)
static func _seg(p: Node3D, ra: float, rb: float, col: Color, a: Vector3, b: Vector3, k := CLAY, segs := 8) -> MeshInstance3D:
	var mi := _m(p, _cyl_mesh(rb, ra, 1.0, segs), col, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, k)
	var d := b - a
	var length := d.length()
	if length < 0.0001:
		mi.visible = false
		return mi
	var dir := d / length
	var rot := Basis.IDENTITY
	if dir.y < -0.9999:
		rot = Basis(Vector3.RIGHT, PI)
	elif dir.y < 0.9999:
		rot = Basis(Quaternion(Vector3.UP, dir))
	mi.transform = Transform3D(rot * Basis.from_scale(Vector3(1, length, 1)), (a + b) * 0.5)
	return mi


## Cadena de tramos por una lista de puntos con radios interpolados (colas, cuellos, tentáculos)
static func _chain(p: Node3D, pts: Array, r0: float, r1: float, col: Color, k := CLAY, joints := true) -> void:
	var n := pts.size()
	for i in n - 1:
		var ra := lerpf(r0, r1, float(i) / (n - 1))
		var rb := lerpf(r0, r1, float(i + 1) / (n - 1))
		_seg(p, ra, rb, col, pts[i], pts[i + 1], k)
		if joints and i > 0:
			_sph(p, ra, col, pts[i], Vector3.ONE, k, 8)


## Placa plana convexa (alas membranosas, hojas, aletas) en el plano XZ con grosor `th`
static func _plate(p: Node3D, pts: Array, th: float, col: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, k := CLAY) -> MeshInstance3D:
	var c := Vector2.ZERO
	for v in pts:
		c += v
	c /= pts.size()
	var sorted: Array = pts.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return (a - c).angle() < (b - c).angle())
	var poly := PackedVector2Array()
	for v in sorted:
		poly.append(v - c)
	var corner := minf(th * 0.5, 0.03)
	var mesh := Models.rounded_prism(poly, corner, th, corner * 0.9)
	var g := _grp(p, pos, rot)
	return _m(g, mesh, col, Vector3(c.x, 0, c.y), Vector3.ZERO, Vector3.ONE, k)


static func _grp(p: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation_degrees = rot
	g.scale = scl
	p.add_child(g)
	return g


## Articulación animada (se hornea aparte). `tracks`: lista de _tr(...)
static func _pivot(p: Node3D, name: String, pos: Vector3, rot := Vector3.ZERO, tracks := []) -> Node3D:
	var g := Node3D.new()
	g.name = name
	g.position = pos
	g.rotation_degrees = rot
	g.set_meta("pivot", true)
	g.set_meta("tracks", tracks)
	p.add_child(g)
	return g


static func _tr(prop: int, axis: int, amp: float, freq: float, off := 0.0, walk := true, mode := SINE) -> Array:
	return [prop, axis, amp, freq, off, walk, mode]


# Ojo: blanco + pupila (o brillante si glow tiene alfa > 0)
static func _eye(p: Node3D, pos: Vector3, size: float, glow := Color(0, 0, 0, 0), pupil := DARK) -> void:
	if glow.a > 0.0:
		_sph(p, size, glow, pos, Vector3(0.7, 1.0, 1.0), GLOW, 8)
	else:
		_sph(p, size, WHITE, pos, Vector3(0.6, 1.0, 1.0), CLAY, 8)
		_sph(p, size * 0.55, pupil, pos + Vector3(size * 0.45, 0, 0), Vector3.ONE, CLAY, 6)


static func _crown(p: Node3D, pos: Vector3, s: float, col := GOLD, gem := Color(0.9, 0.1, 0.2)) -> void:
	_cyl(p, 0.3 * s, 0.27 * s, 0.16 * s, col, pos, Vector3.ZERO, METAL, 10)
	for i in 6:
		var a := TAU * i / 6.0
		var d := Vector3(cos(a), 0, sin(a))
		_cone(p, 0.07 * s, 0.2 * s, col, pos + d * 0.27 * s + Vector3(0, 0.16 * s, 0), Vector3.ZERO, METAL, 4)
		_sph(p, 0.035 * s, col, pos + d * 0.27 * s + Vector3(0, 0.27 * s, 0), Vector3.ONE, METAL, 6)
	_sph(p, 0.06 * s, gem, pos + Vector3(0.29 * s, 0.01 * s, 0), Vector3(0.6, 1, 1), GLOW, 6)
	for z in [-1.0, 1.0]:
		_sph(p, 0.04 * s, Color(0.2, 0.5, 1.0), pos + Vector3(0.2 * s, 0.01 * s, 0.2 * s * z), Vector3(0.6, 1, 1), GLOW, 6)


static func _horn(p: Node3D, base: Vector3, dir: Vector3, curl: Vector3, length: float, r0: float, col: Color, k := CLAY) -> void:
	var pts: Array = []
	var pos := base
	var d := dir.normalized()
	for i in 5:
		pts.append(pos)
		pos += d * length / 4.0
		d = (d + curl * 0.35).normalized()
	_chain(p, pts, r0, r0 * 0.12, col, k)


static func _norm(s: String) -> String:
	var t := s.to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ñ", "n"], ["ü", "u"]]:
		t = t.replace(pair[0], pair[1])
	return " " + t + " "


static func _has(n: String, words: Array) -> bool:
	for w in words:
		if n.contains(w):
			return true
	return false


# ================================================================ Recetas: del nombre al modelo

## Traduce la definición (sobre todo el NOMBRE) a una receta: tipo de cuerpo + accesorios.
static func _recipe(def: Dictionary) -> Dictionary:
	var n := _norm(str(def.get("name", "")))
	var col: Color = def.get("color", Color.WHITE)
	var immune: Array = def.get("immune", [])
	var traits: Array = def.get("traits", [])
	var hp := float(def.get("hp", 1.0))
	var o := {
		"name": n, "col": Color(col, 1.0), "alpha": col.a, "shape": str(def.get("shape", "blob")),
		"boss": bool(def.get("boss", false)), "fly": bool(def.get("flying", false)),
		"fire": "fire" in immune, "ice": "ice" in immune, "undead": "undead" in traits,
		"healer": "healer" in traits, "summoner": "summoner" in traits, "regen": "regen" in traits,
		# colosos y titanes (vida enorme): más adornados
		"grand": hp >= 8.5 and not bool(def.get("boss", false)),
		"crowned": _has(n, [" rey ", "principe", "emperador", "avatar", "reina"]),
	}
	if _has(n, ["calavera"]):
		o.merge({"kind": "eye", "var": "skull"})
	elif _has(n, ["cometa"]):
		o.merge({"kind": "eye", "var": "comet"})
	elif _has(n, ["chispa", "fuego fatuo"]):
		o.merge({"kind": "ghost", "var": "wisp"})
	elif _has(n, ["enjambre", "gorrion"]):
		o.merge({"kind": "swarm"})
	elif _has(n, [" raya "]):
		o.merge({"kind": "ray"})
	elif _has(n, ["esfinge"]):
		o.merge({"kind": "bird", "var": "sphinx"})
	elif _has(n, ["gusano"]):
		o.merge({"kind": "slime", "var": "worm"})
	elif _has(n, [" pez "]):
		o.merge({"kind": "slime", "var": "fish"})
	elif _has(n, ["larva"]):
		o.merge({"kind": "slime", "var": "larva"})
	elif _has(n, ["fragmento", "esquirla"]):
		o.merge({"kind": "slime", "var": "shard"})
	elif _has(n, ["guerrero lagarto"]):
		pass  # humanoide (más abajo)
	# --- Cuadrúpedos
	elif _has(n, ["corcel", "caballo"]):
		o.merge({"kind": "quad", "var": "horse"})
	elif _has(n, ["lobo", "huargo", "sabueso", "merodeador"]):
		o.merge({"kind": "quad", "var": "hellhound" if _has(n, ["sabueso"]) else ("prowler" if _has(n, ["merodeador"]) else "wolf")})
	elif _has(n, ["jabali"]):
		o.merge({"kind": "quad", "var": "boar"})
	elif _has(n, ["cocodrilo", "caiman"]):
		o.merge({"kind": "quad", "var": "croc"})
	elif _has(n, ["acechador de cuevas"]):
		o.merge({"kind": "quad", "var": "cave"})
	elif _has(n, ["salamandra", "lagarto"]):
		o.merge({"kind": "quad", "var": "lizard"})
	elif _has(n, [" rata "]):
		o.merge({"kind": "quad", "var": "rat"})
	elif _has(n, [" topo "]):
		o.merge({"kind": "quad", "var": "mole"})
	elif _has(n, [" oso "]):
		o.merge({"kind": "quad", "var": "bear"})
	elif _has(n, ["liebre", "conejo"]):
		o.merge({"kind": "quad", "var": "hare"})
	elif _has(n, ["morsa"]):
		o.merge({"kind": "quad", "var": "walrus"})
	elif _has(n, ["mamut"]):
		o.merge({"kind": "quad", "var": "mammoth"})
	elif _has(n, ["behemot"]):
		o.merge({"kind": "quad", "var": "behemoth"})
	elif _has(n, ["bestia de asedio"]):
		o.merge({"kind": "quad", "var": "siege"})
	elif _has(n, ["bestia del caos"]):
		o.merge({"kind": "quad", "var": "chaos"})
	elif _has(n, ["bestia prisma"]):
		o.merge({"kind": "quad", "var": "prism"})
	elif _has(n, ["desgarrador"]):
		o.merge({"kind": "quad", "var": "ripper"})
	# --- Bichos
	elif _has(n, ["escarabajo"]):
		o.merge({"kind": "beetle"})
	elif _has(n, ["arana"]):
		o.merge({"kind": "spider"})
	elif _has(n, ["escorpion"]):
		o.merge({"kind": "scorpion"})
	# --- Dragones
	elif _has(n, ["quimera"]):
		o.merge({"kind": "dragon", "var": "chimera"})
	elif _has(n, ["hidra"]):
		o.merge({"kind": "hydra"})
	elif _has(n, ["wyrm", "leviatan"]):
		o.merge({"kind": "dragon", "var": "wyrm"})
	elif _has(n, ["guiverno", "wyvern"]):
		o.merge({"kind": "dragon", "var": "wyvern"})
	elif _has(n, [" dragon ", "dracoliche"]):
		o.merge({"kind": "dragon", "var": "dragon"})
	# --- Voladores
	elif _has(n, [" ojo "]):
		o.merge({"kind": "eye"})
	elif _has(n, ["polilla", "mariposa"]):
		o.merge({"kind": "insect", "var": "moth"})
	elif _has(n, ["mosquito"]):
		o.merge({"kind": "insect", "var": "mosquito"})
	elif _has(n, ["libelula"]):
		o.merge({"kind": "insect", "var": "dragonfly"})
	elif _has(n, [" hada ", "pixie"]):
		o.merge({"kind": "insect", "var": "fairy"})
	elif _has(n, ["murcielago"]):
		o.merge({"kind": "bat", "var": "bat"})
	elif _has(n, ["gargola"]):
		o.merge({"kind": "bat", "var": "gargoyle"})
	elif _has(n, ["sucubo", "succubo"]):
		o.merge({"kind": "bat", "var": "succubus"})
	elif _has(n, ["demonio alado"]):
		o.merge({"kind": "bat", "var": "demon"})
	elif _has(n, ["arpia"]):
		o.merge({"kind": "bird", "var": "harpy"})
	elif _has(n, ["grifo"]):
		o.merge({"kind": "bird", "var": "griffin"})
	elif _has(n, ["buho", "lechuza"]):
		o.merge({"kind": "bird", "var": "owl"})
	elif _has(n, ["cuervo", "buitre", "halcon", "fenix", " roc ", "aguila"]):
		o.merge({"kind": "bird", "var": "crow"})
		if _has(n, ["buitre"]):
			o["var"] = "vulture"
		elif _has(n, ["halcon", "aguila"]):
			o["var"] = "hawk"
		elif _has(n, ["fenix"]):
			o["var"] = "phoenix"
		elif _has(n, [" roc "]):
			o["var"] = "roc"
	# --- Limos y engendros
	elif _has(n, ["sanguijuela"]):
		o.merge({"kind": "slime", "var": "leech"})
	elif _has(n, ["devorador", "ente primigenio"]):
		o.merge({"kind": "slime", "var": "devourer"})
	elif _has(n, ["engendro"]):
		o.merge({"kind": "slime", "var": "spawn"})
	elif _has(n, ["limo"]):
		o.merge({"kind": "slime", "var": "prism" if _has(n, ["prisma"]) else "slime"})
	# --- Espíritus
	elif _has(n, ["elemental de viento", "torbellino"]):
		o.merge({"kind": "tornado"})
	elif _has(n, ["segador"]):
		o.merge({"kind": "ghost", "var": "reaper"})
	elif _has(n, ["espectro", "banshee", "espiritu", "acechador", "fantasma", "alma en pena", "sombra", "susurrador", "cambiaformas", "pesadilla"]):
		o.merge({"kind": "ghost", "var": "wraith"})
		if _has(n, ["banshee"]):
			o["var"] = "banshee"
		elif _has(n, ["acechador", "cambiaformas", "pesadilla", "demonio"]):
			o["var"] = "stalker"
		elif _has(n, ["elfico"]):
			o["var"] = "elf"
	# --- Árboles y gólems
	elif _has(n, ["treant", " ent ", "arbol", "corazon del bosque"]):
		o.merge({"kind": "treant"})
	elif _has(n, ["torre de asedio"]):
		o.merge({"kind": "golem", "var": "tower"})
	elif _has(n, ["golem de carne"]):
		pass  # humanoide cosido (más abajo)
	elif _has(n, ["guardian de la puerta", "guardian del averno", "guardian retorcido", "obsidiana", "coloso del pozo", "titan del caos"]):
		o.merge({"kind": "golem", "var": "obsidian"})
	elif _has(n, ["coraza del vacio", "titan del abismo"]):
		o.merge({"kind": "golem", "var": "void"})
	elif _has(n, ["golem", "elemental", "coloso", "titan", "guardian runico", "guerrero de granito", "corazon", "centinela de hielo"]):
		o.merge({"kind": "golem", "var": "stone"})
		if _has(n, ["cristal", "amatista"]):
			o["var"] = "crystal"
		elif _has(n, ["magma", "lava", "volcan"]):
			o["var"] = "magma"
		elif _has(n, ["lodo"]):
			o["var"] = "mud"
		elif _has(n, ["huesos"]):
			o["var"] = "bone"
		elif _has(n, ["marmol", "celeste"]):
			o["var"] = "marble"
		elif _has(n, ["isla"]):
			o["var"] = "island"
		elif _has(n, ["hielo", "escarcha", "glacia", "trono"]) or o.get("ice", false):
			o["var"] = "ice"
		elif _has(n, ["runico"]):
			o["var"] = "rune"
	elif _has(n, ["isla viviente"]):
		o.merge({"kind": "golem", "var": "island"})
	if not o.has("kind"):
		_humanoid_recipe(n, o)
	if not o.has("kind"):
		_shape_fallback(o)
	return o


## Humanoides: piel, ropa, cabeza, sombrero y armas según el nombre
static func _humanoid_recipe(n: String, o: Dictionary) -> void:
	var c: Color = o["col"]
	var no := Color(0, 0, 0, 0)
	var h := {"kind": "humanoid", "frame": "normal", "skin": SKIN, "cloth": c, "cloth2": c.darkened(0.35),
		"head": "human", "hat": "", "hair": Color(0.3, 0.2, 0.12), "rh": "", "lh": "", "eye": no}
	var icy: bool = _has(n, ["hielo", "helad", "escarcha", "nieve", "glacial", "invierno", "congelad"]) or o.get("ice", false)
	var infernal := _has(n, ["infernal", "averno", "abismo", "pozo", "demon", "azufre", "llamas"])
	var chaos := _has(n, ["caos"])
	var void_ := _has(n, ["vacio"])
	var glow := ICE_GLOW if icy else (FIRE if infernal else (Color(1.0, 0.3, 0.6) if chaos else (PURPLE_GLOW if void_ else no)))
	if _has(n, ["djinn", "genio"]):
		h.merge({"smoke": true, "skin": c.lightened(0.15), "cloth": Color(0.55, 0.2, 0.55), "head": "djinn", "hat": "turban",
			"hat_col": WHITE, "hair": Color(0.1, 0.1, 0.15), "beard": Color(0.1, 0.1, 0.15), "lh": "orb", "item_col": Color(0.6, 0.95, 1.0),
			"eye": Color(0.7, 1.0, 1.0), "bare": true}, true)
	elif _has(n, ["faraon"]):
		h.merge({"mummy": true, "skin": Color(0.86, 0.8, 0.64), "cloth": Color(0.86, 0.8, 0.64), "head": "mummy", "hat": "nemes",
			"hat_col": c, "rh": "crook", "lh": "flail", "eye": Color(0.3, 1.0, 0.6), "cape": Color(0.15, 0.3, 0.7), "collar": true}, true)
	elif _has(n, ["momia"]):
		var caster := _has(n, ["hechicero", "sacerdote"])
		h.merge({"mummy": true, "skin": c, "cloth": c, "head": "mummy", "eye": Color(0.4, 1.0, 0.6), "zombie_arms": not caster,
			"rh": "skull_staff" if caster else "", "item_col": Color(0.4, 1.0, 0.6), "collar": caster, "hat": "nemes" if caster else "",
			"hat_col": Color(0.2, 0.35, 0.7)}, true)
	elif _has(n, ["caballero esqueleto", "guardia real esquelet", "guardian de tumba"]):
		var halb := _has(n, ["guardia"])
		h.merge({"frame": "skeleton", "skin": BONE, "cloth": Color(0.35, 0.33, 0.38), "armor": "plate", "metal": Color(0.45, 0.45, 0.5),
			"head": "skull", "hat": "helmet", "hat_col": Color(0.45, 0.45, 0.5), "rh": "halberd" if halb else "sword", "lh": "" if halb else "shield_kite",
			"shield_col": Color(0.3, 0.1, 0.12) if not _has(n, ["tumba"]) else Color(0.3, 0.3, 0.28), "eye": Color(0.4, 1.0, 0.7)}, true)
	elif _has(n, ["hechicero esquelet"]):
		h.merge({"robe": true, "skin": BONE, "cloth": Color(0.25, 0.2, 0.3), "cloth2": c, "head": "skull", "hat": "wizard",
			"hat_col": Color(0.25, 0.2, 0.3), "rh": "skull_staff", "item_col": GREEN_GLOW, "eye": GREEN_GLOW, "skeleton_hands": true}, true)
	elif _has(n, ["esqueleto"]):
		h.merge({"frame": "skeleton", "skin": c, "cloth": Color(0.4, 0.3, 0.25), "head": "skull", "rh": "sword",
			"lh": "shield_round", "eye": Color(0.4, 1.0, 0.7), "rags": true}, true)
	elif _has(n, ["liche"]):
		h.merge({"robe": true, "skin": BONE, "cloth": Color(0.22, 0.18, 0.3), "cloth2": c, "head": "skull", "hat": "lich_crown",
			"hat_col": Color(0.5, 0.55, 0.45), "rh": "skull_staff", "lh": "orb", "item_col": c.lightened(0.2), "eye": c.lightened(0.3),
			"skeleton_hands": true, "aura": c}, true)
		if _has(n, [" rey ", "archi"]):
			h.merge({"cape": Color(0.15, 0.1, 0.2), "hat": "crown" if _has(n, [" rey "]) else "lich_crown"}, true)
	elif _has(n, ["vampiro"]):
		h.merge({"frame": "slim", "skin": Color(0.85, 0.85, 0.9), "cloth": Color(0.12, 0.1, 0.14), "cloth2": Color(0.08, 0.07, 0.1),
			"head": "vampire", "hair": Color(0.08, 0.06, 0.08), "cape": c, "high_collar": true, "eye": RED_GLOW, "vest": c}, true)
	elif _has(n, ["abominacion", "golem de carne"]):
		h.merge({"frame": "brute", "skin": c, "cloth": Color(0.35, 0.3, 0.25), "head": "zombie", "rh": "cleaver", "lh": "hook",
			"eye": Color(0.8, 1.0, 0.3), "stitches": true, "belly": true, "bare": true}, true)
	elif _has(n, ["necrofago"]):
		h.merge({"frame": "gaunt", "skin": c, "cloth": Color(0.3, 0.28, 0.25), "head": "zombie", "eye": Color(0.8, 1.0, 0.4),
			"bare": true, "claws": true, "hair": Color(0.2, 0.2, 0.18)}, true)
	elif _has(n, ["zombi"]):
		h.merge({"skin": c, "cloth": Color(0.45, 0.38, 0.5), "cloth2": Color(0.3, 0.28, 0.25), "head": "zombie",
			"hair": Color(0.2, 0.18, 0.15), "zombie_arms": true, "eye": Color(0.85, 1.0, 0.4), "rags": true}, true)
	elif _has(n, ["senor de la cripta"]):
		h.merge({"frame": "brute", "skin": BONE, "cloth": c, "head": "skull", "armor": "spiky", "metal": Color(0.3, 0.35, 0.3),
			"rh": "greataxe", "eye": GREEN_GLOW, "cape": Color(0.15, 0.2, 0.15), "hat": "crown", "skeleton_hands": true}, true)
	elif _has(n, ["nigromante"]):
		h.merge({"robe": true, "cloth": c, "cloth2": c.darkened(0.4), "skin": Color(0.75, 0.78, 0.7), "hat": "hood",
			"hat_col": c.darkened(0.15), "rh": "skull_staff", "item_col": GREEN_GLOW, "eye": GREEN_GLOW, "shadow_face": true}, true)
		if _has(n, ["archi"]):
			h.merge({"lh": "orb", "cape": Color(0.1, 0.15, 0.1), "aura": GREEN_GLOW}, true)
	elif _has(n, ["balrog"]):
		h.merge({"frame": "brute", "skin": Color(0.18, 0.08, 0.06), "cloth": Color(0.12, 0.05, 0.05), "head": "demon", "horns": Color(0.12, 0.08, 0.08),
			"eye": FIRE_HOT, "tail": Color(0.18, 0.08, 0.06), "bare": true, "rh": "flail_sword", "wings": "bat", "flame_head": true,
			"embers": true}, true)
	elif _has(n, ["senor del pozo", "senor demonio", "diablo abisal", "bruto infernal", "principe del averno", "senor del abismo", "demonio berserker", "avatar del caos"]):
		var lord := _has(n, ["senor", "principe", "avatar"])
		h.merge({"frame": "brute", "skin": c, "cloth": Color(0.15, 0.08, 0.08), "head": "demon", "horns": Color(0.18, 0.12, 0.1),
			"eye": FIRE_HOT if not chaos else Color(1.0, 0.3, 0.7), "tail": c, "bare": true, "rh": "greataxe" if lord else "club",
			"club_col": Color(0.25, 0.2, 0.2), "wings": "bat" if lord else "", "metal": Color(0.25, 0.2, 0.2),
			"armor": "spiky" if lord or _has(n, ["diablo"]) else ""}, true)
		if _has(n, ["berserker"]):
			h.merge({"rh": "axe", "lh": "axe", "flame_head": true}, true)
	elif _has(n, ["demonio menor", "diablillo", " imp "]):
		h.merge({"frame": "small", "skin": c, "cloth": c.darkened(0.45), "head": "demon", "horns": Color(0.2, 0.12, 0.1),
			"tail": c, "eye": FIRE_HOT, "rh": "pitchfork" if _has(n, ["demonio", "pozo"]) else "", "bare": true,
			"flame_head": _has(n, ["fuego"])}, true)
	elif _has(n, ["carcelero"]):
		h.merge({"frame": "brute", "skin": c, "cloth": Color(0.15, 0.1, 0.1), "head": "demon", "horns": Color(0.15, 0.1, 0.1),
			"armor": "spiky", "metal": Color(0.3, 0.25, 0.25), "hat": "great_helm", "hat_col": Color(0.3, 0.25, 0.25), "rh": "mace",
			"lh": "lantern", "eye": FIRE_HOT, "tail": c}, true)
	elif _has(n, ["verdugo", "torturador"]):
		h.merge({"frame": "brute", "skin": Color(0.85, 0.65, 0.55) if not infernal and not _has(n, ["torturador"]) else c, "cloth": Color(0.15, 0.1, 0.1),
			"head": "human", "hat": "exec_hood", "hat_col": c if _has(n, ["verdugo"]) else Color(0.12, 0.08, 0.08), "rh": "greataxe" if _has(n, ["verdugo"]) else "cleaver",
			"lh": "" if _has(n, ["verdugo"]) else "hook", "bare": true, "eye": RED_GLOW, "belt": true}, true)
	elif _has(n, ["horror"]):
		h.merge({"frame": "brute", "skin": c, "cloth": c.darkened(0.4), "head": "octopus", "eye": PURPLE_GLOW, "bare": true,
			"tentacle_arms": true}, true)
	elif _has(n, ["wendigo"]):
		h.merge({"frame": "gaunt", "skin": c, "cloth": c.darkened(0.25), "head": "wendigo", "eye": ICE_GLOW, "bare": true,
			"claws": true, "fur": true}, true)
	elif _has(n, ["yeti"]):
		h.merge({"frame": "brute", "skin": c, "cloth": c, "head": "yeti", "eye": DARK, "bare": true, "fur": true, "claws": true}, true)
		if o["grand"]:
			h.merge({"eye": ICE_GLOW, "icicles": true, "rh": "ice_club"}, true)
	elif _has(n, ["gigante de escarcha", "gigante de hielo"]):
		h.merge({"frame": "brute", "skin": Color(0.55, 0.75, 0.95), "cloth": Color(0.35, 0.45, 0.6), "head": "giant",
			"hair": WHITE, "beard": Color(0.92, 0.96, 1.0), "rh": "ice_club", "eye": ICE_GLOW, "metal": Color(0.6, 0.8, 1.0),
			"armor": "ice", "fur": true}, true)
	elif _has(n, ["gigante"]):
		h.merge({"frame": "brute", "skin": Color(0.85, 0.66, 0.5), "cloth": c, "head": "giant", "hair": Color(0.45, 0.3, 0.18),
			"beard": Color(0.45, 0.3, 0.18), "rh": "tree_club", "belt": true}, true)
		if o["grand"]:
			h.merge({"hat": "straw", "hat_col": Color(0.9, 0.78, 0.4), "lh": "sack", "armor": "leather", "metal": IRON}, true)
	elif _has(n, ["ogro"]):
		var farmer := _has(n, ["campesino"])
		h.merge({"frame": "brute", "skin": c, "cloth": Color(0.55, 0.42, 0.28), "cloth2": Color(0.4, 0.3, 0.2), "head": "ogre",
			"hat": "straw" if farmer else "", "hat_col": Color(0.9, 0.78, 0.4), "rh": "pitchfork" if farmer else "club", "belt": true}, true)
		if _has(n, ["jefe"]):
			h.merge({"armor": "spiky", "metal": IRON, "rh": "greataxe", "cape": Color(0.5, 0.2, 0.1), "hat": "horned_helm", "hat_col": IRON}, true)
	elif _has(n, ["troll"]):
		h.merge({"frame": "brute", "skin": c, "cloth": Color(0.4, 0.33, 0.22), "head": "troll", "rh": "club",
			"eye": Color(1.0, 0.85, 0.2), "moss": _has(n, ["pantano"]), "hair": c.darkened(0.4), "bare": true}, true)
	elif _has(n, ["orco"]) and not _has(n, ["chaman"]):
		h.merge({"frame": "brute", "skin": c, "cloth": Color(0.4, 0.3, 0.2), "head": "orc", "rh": "axe", "lh": "shield_round",
			"armor": "leather", "metal": IRON, "eye": RED_GLOW, "hair": DARK}, true)
	elif _has(n, ["enano"]):
		var plate := _has(n, ["acorazado"])
		h.merge({"frame": "dwarf", "cloth": c, "cloth2": Color(0.35, 0.25, 0.18), "hat": "horned_helm",
			"hat_col": IRON if not plate else Color(0.65, 0.67, 0.72), "beard": Color(0.75, 0.35, 0.15), "hair": Color(0.75, 0.35, 0.15),
			"rh": "axe" if not plate else "hammer", "lh": "" if not plate else "shield_round", "shield_col": Color(0.55, 0.15, 0.12),
			"armor": "leather" if not plate else "plate", "metal": IRON if not plate else Color(0.65, 0.67, 0.72)}, true)
	elif _has(n, ["hombre rana"]):
		h.merge({"frame": "small", "skin": c, "cloth": Color(0.5, 0.42, 0.25), "head": "frog", "rh": "trident", "bare": true}, true)
	elif _has(n, ["draconido", "guerrero lagarto", "guardian de escamas"]):
		var shield := _has(n, ["guardian", "guerrero"])
		h.merge({"frame": "brute", "skin": c, "cloth": Color(0.3, 0.2, 0.15), "head": "lizard", "rh": "scimitar" if not _has(n, ["lagarto"]) else "spear",
			"lh": "shield_round" if shield or not _has(n, ["berserker"]) else "axe", "shield_col": c.darkened(0.3), "tail": c,
			"armor": "plate" if _has(n, ["guardian"]) else "leather", "metal": Color(0.55, 0.45, 0.35),
			"eye": FIRE_HOT if not _has(n, ["lagarto"]) else Color(1.0, 0.9, 0.3), "horns": Color(0.25, 0.18, 0.12) if not _has(n, ["lagarto"]) else no}, true)
		if _has(n, ["berserker"]):
			h.merge({"rh": "greataxe", "lh": "", "bare": true, "armor": ""}, true)
	elif _has(n, ["chaman kobold", "senor kobold"]):
		h.merge({"frame": "small", "robe": true, "skin": Color(0.75, 0.45, 0.2), "cloth": c, "head": "kobold", "tail": Color(0.75, 0.45, 0.2),
			"rh": "bone_staff", "item_col": GREEN_GLOW, "feathers": true, "eye": FIRE_HOT}, true)
		if _has(n, ["senor"]):
			h.merge({"hat": "crown", "cape": Color(0.5, 0.15, 0.1), "rh": "fire_staff", "item_col": FIRE}, true)
	elif _has(n, ["kobold"]):
		h.merge({"frame": "small", "skin": c, "cloth": Color(0.45, 0.32, 0.2), "head": "kobold", "tail": c, "rh": "spear",
			"eye": FIRE_HOT, "horns": Color(0.3, 0.2, 0.15) if _has(n, ["draco"]) else no}, true)
		if _has(n, ["berserker"]):
			h.merge({"rh": "axe", "lh": "axe", "bare": true}, true)
	elif _has(n, ["duende", "goblin"]):
		var ice_g := _has(n, ["hielo"])
		h.merge({"frame": "small", "skin": Color(0.45, 0.68, 0.28) if not ice_g else Color(0.6, 0.8, 0.95), "cloth": c.darkened(0.2) if _has(n, ["duende"]) else Color(0.5, 0.35, 0.22),
			"head": "goblin", "hat": "pointy" if _has(n, ["duende"]) else "", "hat_col": Color(0.6, 0.15, 0.1) if not ice_g else Color(0.3, 0.45, 0.8),
			"rh": "dagger", "lh": "sack" if _has(n, ["duende"]) and not ice_g else "", "eye": Color(1.0, 0.9, 0.2) if not ice_g else ICE_GLOW}, true)
	elif _has(n, ["chaman"]):
		var orc := _has(n, ["orco"])
		var frost := _has(n, ["escarcha"])
		h.merge({"robe": true, "skin": Color(0.45, 0.6, 0.3) if orc else SKIN, "head": "orc" if orc else "human",
			"hat": "fur_hood" if frost else ("hood" if not orc else ""), "hat_col": Color(0.9, 0.9, 0.88) if frost else c.darkened(0.2),
			"rh": "bone_staff" if not frost else "ice_staff", "item_col": GREEN_GLOW if not frost else ICE_GLOW, "feathers": not frost,
			"beard": Color(0.85, 0.85, 0.85) if frost else no, "cloth": c}, true)
	elif _has(n, ["druida"]):
		h.merge({"robe": true, "cloth": c, "hat": "hood", "hat_col": c.darkened(0.2), "antlers": true, "rh": "druid_staff",
			"item_col": GREEN_GLOW if not icy else ICE_GLOW, "eye": GREEN_GLOW if not icy else ICE_GLOW, "shadow_face": true, "leaves": not icy, "icicles": icy}, true)
		if _has(n, ["archi"]):
			h.merge({"cape": Color(0.15, 0.2, 0.1), "aura": GREEN_GLOW}, true)
	elif _has(n, ["driade"]):
		h.merge({"robe": true, "frame": "slim", "skin": Color(0.6, 0.5, 0.35), "cloth": c, "head": "dryad", "hair": Color(0.35, 0.5, 0.2),
			"rh": "druid_staff", "item_col": Color(0.8, 0.4, 1.0), "eye": Color(0.8, 0.4, 1.0), "leaves": true}, true)
	elif _has(n, ["bruja", "hechicera"]):
		var swamp: bool = not icy and not infernal
		h.merge({"robe": true, "frame": "slim", "skin": Color(0.7, 0.85, 0.95) if icy else (c.lightened(0.3) if infernal else Color(0.6, 0.72, 0.45)), "cloth": c,
			"head": "witch", "hair": WHITE if icy else Color(0.15, 0.12, 0.1), "hat": "witch", "hat_col": c.darkened(0.3),
			"rh": "ice_staff" if icy else ("fire_staff" if infernal else "broom"), "lh": "orb" if not swamp else "potion",
			"item_col": ICE_GLOW if icy else (FIRE if infernal else GREEN_GLOW), "icicles": icy,
			"horns": Color(0.15, 0.08, 0.08) if infernal else no}, true)
		if _has(n, ["anciana"]):
			h.merge({"hair": Color(0.85, 0.85, 0.8), "rh": "skull_staff", "item_col": GREEN_GLOW, "cape": Color(0.2, 0.15, 0.1)}, true)
	elif _has(n, ["reina"]):
		var fallen: bool = not icy
		h.merge({"robe": true, "frame": "slim", "skin": Color(0.85, 0.92, 1.0) if icy else Color(0.82, 0.78, 0.9), "cloth": c,
			"cloth2": WHITE if icy else Color(0.2, 0.12, 0.3), "head": "queen" if icy else "elf",
			"hair": WHITE if icy else Color(0.15, 0.1, 0.2), "long_hair": true, "hat": "ice_crown" if icy else "circlet",
			"rh": "ice_staff" if icy else "crystal_staff", "item_col": ICE_GLOW if icy else PURPLE_GLOW,
			"eye": ICE_GLOW if icy else PURPLE_GLOW, "cape": c.darkened(0.3), "wings": "fallen" if fallen else ""}, true)
	elif _has(n, ["danzarin"]):
		h.merge({"frame": "slim", "skin": Color(0.8, 0.75, 0.85), "cloth": c, "cloth2": c.darkened(0.4), "head": "elf", "hair": WHITE,
			"long_hair": true, "rh": "scimitar", "lh": "scimitar", "sash": GOLD, "eye": PURPLE_GLOW}, true)
	elif _has(n, ["elfo", "elfico"]) and not _has(n, ["centinela"]):
		h.merge({"robe": true, "frame": "slim", "skin": Color(0.55, 0.5, 0.65), "cloth": c, "head": "elf", "hair": WHITE,
			"long_hair": true, "rh": "crystal_staff", "item_col": PURPLE_GLOW, "eye": PURPLE_GLOW}, true)
		if _has(n, ["asesino"]):
			h.merge({"robe": false, "hat": "hood", "hat_col": c.darkened(0.2), "mask": true, "mask_col": c.darkened(0.4), "rh": "dagger", "lh": "dagger"}, true)
		if _has(n, ["archi"]):
			h.merge({"hat": "wizard", "hat_col": c.darkened(0.2), "cape": c.darkened(0.3), "lh": "orb"}, true)
	elif _has(n, ["guardian de las nubes"]):
		h.merge({"robe": true, "cloth": c, "cloth2": GOLD, "hair": Color(0.95, 0.85, 0.5), "hat": "halo",
			"rh": "spear_gold", "wings": "angel"}, true)
	elif _has(n, ["capellan", "sacerdote", "clerigo", "senor hereje"]):
		var lava := _has(n, ["lava"])
		var sun := _has(n, [" sol "])
		var draco := _has(n, ["draco"])
		h.merge({"robe": true, "cloth": c, "cloth2": GOLD if not lava else FIRE, "hat": "mitre", "hat_col": c.darkened(0.2) if not sun else WHITE,
			"rh": "mace" if not (lava or sun or draco) else ("fire_staff" if lava or draco else "orb_staff"), "lh": "censer" if not lava else "",
			"item_col": FIRE if (lava or draco) else (GOLD if sun else Color(0.7, 1.0, 0.5)),
			"shadow_face": not sun, "eye": FIRE_HOT if (lava or draco) else RED_GLOW, "skin": Color(0.6, 0.5, 0.45)}, true)
		if draco:
			h.merge({"head": "lizard", "skin": c.lightened(0.2), "shadow_face": false, "tail": c.lightened(0.2), "horns": Color(0.25, 0.15, 0.1)}, true)
		if sun:
			h.merge({"skin": Color(0.75, 0.55, 0.4), "collar": true}, true)
		if _has(n, ["senor", "sumo"]):
			h.merge({"cape": Color(0.4, 0.05, 0.08), "aura": h["item_col"]}, true)
	elif _has(n, ["profeta", "heraldo"]):
		h.merge({"robe": true, "cloth": c, "cloth2": PURPLE_GLOW, "hat": "hood", "hat_col": c, "rh": "eye_staff",
			"item_col": PURPLE_GLOW, "eye": PURPLE_GLOW, "shadow_face": true}, true)
		if _has(n, ["heraldo"]):
			h.merge({"lh": "orb", "cape": c.darkened(0.3)}, true)
	elif _has(n, ["oraculo", "vidente"]):
		h.merge({"robe": true, "frame": "slim", "cloth": c, "cloth2": GOLD, "head": "elf" if _has(n, ["caido"]) else "human",
			"hair": Color(0.9, 0.9, 0.95), "long_hair": true, "blindfold": true, "lh": "orb", "rh": "crystal_staff",
			"item_col": c.lightened(0.4) if not chaos else Color(1.0, 0.3, 0.6)}, true)
	elif _has(n, ["invocador", "brujo", "archidemonio"]):
		var sulfur := _has(n, ["azufre"])
		h.merge({"robe": true, "cloth": c, "cloth2": FIRE, "head": "demon", "skin": c.lightened(0.25) if not sulfur else Color(0.85, 0.75, 0.45),
			"horns": Color(0.15, 0.1, 0.1), "rh": "fire_staff", "item_col": FIRE if not sulfur else Color(0.9, 1.0, 0.3), "lh": "orb", "eye": FIRE_HOT,
			"tail": c.lightened(0.15)}, true)
		if _has(n, ["archi"]):
			h.merge({"cape": Color(0.25, 0.02, 0.05), "wings": "bat", "aura": FIRE}, true)
	elif _has(n, ["geomante"]):
		h.merge({"robe": true, "cloth": c, "cloth2": Color(0.45, 0.35, 0.25), "hat": "hood", "hat_col": c.darkened(0.2), "rh": "crystal_staff",
			"item_col": Color(1.0, 0.7, 0.3), "beard": Color(0.6, 0.55, 0.5), "lh": "orb"}, true)
	elif _has(n, ["senor de las", "senor de los", "consejero", "tormentista", "hechicero", "mago"]):
		var crystal := _has(n, ["prisma", "cristal"])
		var draco := _has(n, ["draco"])
		var storm := _has(n, ["tormenta"])
		var fire_l := _has(n, ["llamas"])
		var ic := Color(0.7, 0.5, 1.0) if crystal else (FIRE if draco or fire_l else (ICE_GLOW if icy else (Color(0.75, 0.9, 1.0) if storm else (Color(1.0, 0.3, 0.6) if chaos else PURPLE_GLOW))))
		var hooded := draco or chaos or _has(n, ["consejero"])
		h.merge({"robe": true, "cloth": c, "cloth2": GOLD, "hat": "hood" if hooded else "wizard", "hat_col": c.darkened(0.15),
			"rh": "crystal_staff" if crystal else ("fire_staff" if draco or fire_l else ("ice_staff" if icy else "orb_staff")), "item_col": ic,
			"beard": Color(0.85, 0.85, 0.88) if not (draco or chaos or fire_l) else no, "lh": "orb" if chaos or storm else "",
			"shadow_face": hooded, "eye": ic if hooded else no, "horns": Color(0.3, 0.15, 0.1) if draco or chaos else no}, true)
		if _has(n, ["senor de"]):
			h.merge({"cape": c.darkened(0.35), "aura": ic, "hat": "crown_hood", "hat_col": c.darkened(0.2), "shadow_face": true, "eye": ic, "beard": no}, true)
		if fire_l:
			h.merge({"flame_head": true, "hat": "", "head": "demon", "skin": Color(0.35, 0.1, 0.05), "horns": Color(0.15, 0.08, 0.05), "shadow_face": false}, true)
		if _has(n, ["archi"]):
			h.merge({"cape": c.darkened(0.35), "aura": ic}, true)
	elif _has(n, ["bandido", "ladron", "salteador"]):
		var desert := _has(n, ["desierto"])
		var king := _has(n, [" rey "])
		h.merge({"cloth": c, "cloth2": c.darkened(0.45), "hat": "turban" if desert else "hood", "hat_col": Color(0.9, 0.85, 0.72) if desert else c.darkened(0.25),
			"rh": "scimitar" if desert else "dagger", "lh": "sack" if not king else "dagger", "mask": true,
			"mask_col": Color(0.6, 0.15, 0.12) if not desert else Color(0.85, 0.8, 0.68), "belt": true}, true)
		if king:
			h.merge({"hat": "crown_hood", "cape": Color(0.6, 0.1, 0.12), "rh": "sword", "gold_trim": true}, true)
	elif _has(n, ["caballero", "guardia", "senor de la guerra", "emperador", "paladin", "centinela", " rey "]):
		var chaos_k := chaos
		var lord := _has(n, ["senor de la guerra", "emperador", " rey ", "campeon"])
		var metal := c.lightened(0.15) if not lord else Color(0.25, 0.22, 0.24)
		h.merge({"frame": "brute" if lord else "normal", "armor": "plate", "metal": metal, "cloth": c.darkened(0.2) if not lord else c,
			"head": "human", "hat": "great_helm", "hat_col": metal, "rh": "sword", "lh": "shield_kite", "shield_col": c}, true)
		if icy:
			h.merge({"rh": "halberd" if _has(n, ["guardia"]) else "sword", "lh": "" if _has(n, ["guardia"]) else "shield_kite",
				"icicles": true, "eye": ICE_GLOW, "metal": Color(0.7, 0.85, 1.0), "hat_col": Color(0.7, 0.85, 1.0), "plume": Color(0.3, 0.45, 0.9)}, true)
		if chaos_k:
			h.merge({"spikes": true, "eye": Color(1.0, 0.2, 0.5), "hat": "horned_great_helm", "rh": "flail_sword"}, true)
		if _has(n, ["negro"]):
			h.merge({"eye": RED_GLOW, "plume": Color(0.6, 0.05, 0.08)}, true)
		if _has(n, ["muerte"]):
			h.merge({"eye": GREEN_GLOW, "metal": Color(0.2, 0.24, 0.2), "hat_col": Color(0.2, 0.24, 0.2), "hat": "horned_great_helm", "rh": "flail_sword", "cape": Color(0.1, 0.12, 0.1)}, true)
		if _has(n, ["paladin"]):
			h.merge({"eye": RED_GLOW, "rh": "mace", "shield_col": Color(0.6, 0.55, 0.3), "cape": Color(0.35, 0.3, 0.3)}, true)
		if _has(n, ["templo"]):
			h.merge({"metal": GOLD, "hat_col": GOLD, "hat": "nemes", "head": "human", "skin": Color(0.75, 0.55, 0.4), "rh": "spear", "shield_col": Color(0.2, 0.35, 0.7)}, true)
		if _has(n, ["elfico"]):
			h.merge({"frame": "slim", "metal": Color(0.8, 0.85, 0.85), "hat_col": Color(0.8, 0.85, 0.85), "plume": Color(0.3, 0.6, 0.4), "rh": "spear"}, true)
		if _has(n, ["alado"]):
			h.merge({"wings": "angel", "plume": Color(0.3, 0.5, 0.9), "rh": "spear_gold"}, true)
		if _has(n, ["cristal"]):
			h.merge({"icicles": true, "metal": c.lightened(0.2), "hat_col": c.lightened(0.2), "eye": Color(0.8, 0.6, 1.0), "plume": Color(0.6, 0.3, 0.9)}, true)
		if _has(n, ["imperial"]):
			h.merge({"rh": "halberd", "lh": "", "plume": Color(0.2, 0.3, 0.8), "cape": Color(0.2, 0.3, 0.7)}, true)
		if lord:
			h.merge({"hat": "horned_great_helm" if not _has(n, [" rey "]) else "crown", "rh": "greataxe" if not _has(n, [" rey "]) else "sword", "lh": "",
				"cape": Color(0.6, 0.08, 0.1) if not icy else Color(0.3, 0.5, 0.9), "spikes": true,
				"eye": RED_GLOW if not chaos else Color(1.0, 0.3, 0.7)}, true)
			if _has(n, [" rey "]):
				h.merge({"head": "zombie" if _has(n, ["caido"]) else "giant", "skin": Color(0.6, 0.65, 0.55) if _has(n, ["caido"]) else Color(0.7, 0.85, 1.0),
					"beard": Color(0.9, 0.95, 1.0) if icy else no, "hair": Color(0.9, 0.95, 1.0) if icy else Color(0.25, 0.25, 0.2),
					"eye": ICE_GLOW if icy else Color(0.9, 0.9, 0.4), "lh": "shield_kite" if not icy else "", "rh": "sword" if not icy else "ice_club"}, true)
	elif _has(n, ["campeon"]):
		h.merge({"frame": "brute", "armor": "spiky", "metal": c.darkened(0.2), "cloth": c, "hat": "horned_great_helm", "hat_col": c.darkened(0.2),
			"rh": "greataxe", "eye": Color(1.0, 0.3, 0.7), "cape": c.darkened(0.4), "spikes": true}, true)
	elif _has(n, ["barbaro", "berserker", "mercenario"]):
		var fire_b := _has(n, ["igneo"])
		h.merge({"frame": "brute" if not _has(n, ["mercenario"]) else "normal", "skin": SKIN if not fire_b else Color(0.8, 0.4, 0.2), "cloth": c, "cloth2": Color(0.35, 0.25, 0.18),
			"bare": not _has(n, ["mercenario"]), "fur": icy, "hat": "horned_helm" if icy else "", "hat_col": IRON,
			"hair": Color(0.85, 0.55, 0.25) if not fire_b else FIRE, "beard": Color(0.85, 0.55, 0.25) if icy else no,
			"rh": "greataxe" if not _has(n, ["mercenario"]) else "sword", "lh": "" if not _has(n, ["mercenario"]) else "axe",
			"eye": RED_GLOW if _has(n, ["furioso"]) else no, "flame_head": fire_b, "armor": "leather" if _has(n, ["mercenario"]) else "", "metal": IRON, "belt": true}, true)
	elif _has(n, ["soldado"]):
		h.merge({"cloth": c, "cloth2": Color(0.35, 0.3, 0.25), "hat": "kettle", "hat_col": IRON, "rh": "spear", "lh": "shield_round",
			"shield_col": Color(0.55, 0.15, 0.12), "armor": "leather", "metal": IRON, "beard": Color(0.35, 0.25, 0.15)}, true)
	elif _has(n, ["ladron", "asesino", "espia", "cazador", "guardabosques"]):
		var hunter := _has(n, ["cazador", "guardabosques"])
		h.merge({"frame": "slim", "cloth": c, "cloth2": c.darkened(0.4), "hat": "hood" if not icy else "fur_hood", "hat_col": c.darkened(0.2) if not icy else WHITE,
			"mask": true, "mask_col": c.darkened(0.45), "rh": "dagger" if not hunter else "crossbow", "lh": "dagger" if not hunter else "",
			"eye": RED_GLOW if c.get_luminance() < 0.4 else no, "armor": "leather" if hunter else "", "metal": IRON, "quiver": hunter, "cape": c.darkened(0.3)}, true)
		if _has(n, ["dunas", "trono"]):
			h.merge({"hat": "turban", "hat_col": c.lightened(0.2), "rh": "scimitar"}, true)
		if _has(n, ["dragones"]):
			h.merge({"rh": "spear", "lh": "shield_round", "shield_col": Color(0.55, 0.2, 0.12), "hat": "helmet", "hat_col": IRON, "mask": false}, true)
	elif _has(n, ["guerrero nomada"]):
		h.merge({"cloth": Color(0.85, 0.8, 0.68), "cloth2": c, "hat": "turban", "hat_col": WHITE, "rh": "scimitar", "lh": "shield_round",
			"shield_col": c, "mask": true, "mask_col": Color(0.25, 0.3, 0.55), "skin": Color(0.75, 0.55, 0.4), "sash": Color(0.7, 0.15, 0.12)}, true)
	elif _has(n, ["ballestero"]):
		h.merge({"cloth": c, "cloth2": Color(0.3, 0.25, 0.2), "hat": "kettle", "hat_col": IRON, "rh": "crossbow",
			"armor": "leather", "metal": IRON, "beard": Color(0.3, 0.2, 0.12), "quiver": true}, true)
	elif _has(n, ["pirata", "corsario"]):
		h.merge({"cloth": Color(0.85, 0.82, 0.75), "cloth2": Color(0.25, 0.3, 0.5), "vest": c, "hat": "tricorn", "hat_col": Color(0.15, 0.12, 0.12),
			"rh": "scimitar", "eyepatch": true, "beard": Color(0.15, 0.1, 0.08), "sash": Color(0.75, 0.15, 0.12)}, true)
		if _has(n, ["corsario"]):
			h.merge({"lh": "scimitar", "frame": "brute", "eye": RED_GLOW}, true)
	else:
		return
	if h["eye"] == no and glow.a > 0.0 and h.get("robe", false):
		h["eye"] = glow
	o.merge(h, true)


static func _shape_fallback(o: Dictionary) -> void:
	var c: Color = o["col"]
	match o["shape"]:
		"beast":
			o.merge({"kind": "quad", "var": "wolf"})
		"brute":
			o.merge({"kind": "humanoid", "frame": "brute", "skin": c, "cloth": c.darkened(0.4), "cloth2": c.darkened(0.5), "head": "orc",
				"rh": "club", "lh": "", "eye": RED_GLOW, "hat": "", "hair": DARK})
		"robe":
			o.merge({"kind": "humanoid", "frame": "normal", "robe": true, "skin": SKIN, "cloth": c, "cloth2": GOLD, "head": "human",
				"hat": "hood", "hat_col": c.darkened(0.2), "rh": "orb_staff", "item_col": PURPLE_GLOW, "lh": "", "eye": PURPLE_GLOW,
				"shadow_face": true, "hair": DARK})
		"golem":
			o.merge({"kind": "golem", "var": "stone"})
		"wings":
			o.merge({"kind": "bird", "var": "crow"})
		"dragon":
			o.merge({"kind": "dragon", "var": "dragon"})
		"ghost":
			o.merge({"kind": "ghost", "var": "wraith"})
		"slime":
			o.merge({"kind": "slime", "var": "slime"})
		_:
			o.merge({"kind": "humanoid", "frame": "small", "skin": Color(0.45, 0.68, 0.28), "cloth": c, "cloth2": c.darkened(0.35),
				"head": "goblin", "hat": "", "rh": "dagger", "lh": "", "eye": Color(1.0, 0.9, 0.2), "hair": DARK})


const _FLOATERS := ["bird", "bat", "insect", "swarm", "ray"]


static func _build_kind(rig: Node3D, o: Dictionary) -> void:
	var host := rig
	if o["kind"] in _FLOATERS and not o.get("fly", false):
		# criatura voladora que, en el juego, va por el suelo: la subimos un poco
		host = _grp(rig, Vector3(0, 1.1, 0))
	match o["kind"]:
		"humanoid":
			_humanoid(host, o)
		"quad":
			_quadruped(host, o)
		"spider":
			_spider(host, o)
		"scorpion":
			_scorpion(host, o)
		"beetle":
			_beetle(host, o)
		"bird":
			_bird(host, o)
		"bat":
			_bat(host, o)
		"insect":
			_insect(host, o)
		"swarm":
			_swarm(host, o)
		"ray":
			_ray(host, o)
		"dragon":
			_dragon(host, o)
		"hydra":
			_hydra(host, o)
		"golem":
			_golem(host, o)
		"treant":
			_treant(host, o)
		"ghost":
			_ghost(host, o)
		"tornado":
			_tornado(host, o)
		"slime":
			_slime(host, o)
		"eye":
			_floating_eye(host, o)
		_:
			_slime(host, o)


# ================================================================ Humanoides

static func _frame(f: String) -> Dictionary:
	match f:
		"small":
			return {"hip": 0.5, "leg": 0.115, "top": 1.06, "tw": 0.31, "td": 0.26, "sh_y": 0.98, "sh_z": 0.37, "arm": 0.5, "arm_r": 0.09, "head_y": 1.44, "hr": 0.43, "hx": 0.0}
		"brute":
			return {"hip": 0.72, "leg": 0.2, "top": 1.85, "tw": 0.58, "td": 0.45, "sh_y": 1.66, "sh_z": 0.7, "arm": 0.98, "arm_r": 0.17, "head_y": 2.02, "hr": 0.31, "hx": 0.22}
		"dwarf":
			return {"hip": 0.45, "leg": 0.15, "top": 1.15, "tw": 0.44, "td": 0.34, "sh_y": 1.05, "sh_z": 0.52, "arm": 0.56, "arm_r": 0.12, "head_y": 1.5, "hr": 0.36, "hx": 0.0}
		"slim":
			return {"hip": 0.84, "leg": 0.105, "top": 1.56, "tw": 0.3, "td": 0.22, "sh_y": 1.47, "sh_z": 0.37, "arm": 0.66, "arm_r": 0.08, "head_y": 1.97, "hr": 0.34, "hx": 0.0}
		"skeleton":
			return {"hip": 0.8, "leg": 0.05, "top": 1.55, "tw": 0.3, "td": 0.2, "sh_y": 1.45, "sh_z": 0.4, "arm": 0.66, "arm_r": 0.045, "head_y": 1.97, "hr": 0.36, "hx": 0.0}
		"gaunt":
			return {"hip": 0.95, "leg": 0.08, "top": 1.75, "tw": 0.3, "td": 0.22, "sh_y": 1.66, "sh_z": 0.4, "arm": 0.98, "arm_r": 0.07, "head_y": 2.12, "hr": 0.3, "hx": 0.22}
	return {"hip": 0.78, "leg": 0.13, "top": 1.55, "tw": 0.36, "td": 0.26, "sh_y": 1.45, "sh_z": 0.45, "arm": 0.66, "arm_r": 0.1, "head_y": 1.98, "hr": 0.37, "hx": 0.0}


static func _humanoid(rig: Node3D, o: Dictionary) -> void:
	var fr := _frame(str(o.get("frame", "normal")))
	var hip: float = fr["hip"]
	var top: float = fr["top"]
	var tw: float = fr["tw"]
	var td: float = fr["td"]
	var hr: float = fr["hr"]
	var skin: Color = o.get("skin", SKIN)
	var cloth: Color = o.get("cloth", o["col"])
	var cloth2: Color = o.get("cloth2", cloth.darkened(0.35))
	var metal: Color = o.get("metal", IRON)
	var armor: String = o.get("armor", "")
	var bare: bool = o.get("bare", false)
	var skel: bool = o.get("frame", "") == "skeleton"
	var robe: bool = o.get("robe", false)
	var smoke: bool = o.get("smoke", false)
	var brute: bool = o.get("frame", "") == "brute"
	var small: bool = o.get("frame", "") == "small"
	var boss: bool = o.get("boss", false) or o.get("grand", false)
	var crowned: bool = o.get("boss", false) or o.get("crowned", false)
	var H := Vector3(fr["hx"], fr["head_y"], 0)
	var torso_col := skin if bare else cloth
	var mid := (hip + top) * 0.5

	# --- Tronco
	if skel:
		_seg(rig, 0.05, 0.05, BONE, Vector3(-0.04, hip, 0), Vector3(-0.04, top, 0))
		for i in 4:
			var y := hip + 0.25 + i * 0.13
			var w := tw * (0.8 + 0.25 * sin(i * 0.9 + 0.6))
			_sph(rig, 1.0, skin, Vector3(0, y, 0), Vector3(td * 0.95, 0.045, w))
		_sph(rig, 1.0, skin, Vector3(0, hip + 0.06, 0), Vector3(0.17, 0.09, tw * 0.75))  # pelvis
		_sph(rig, 1.0, skin, Vector3(0.0, top - 0.08, 0), Vector3(0.12, 0.05, tw * 1.05))  # clavículas
		if o.get("rags", false):
			_cyl(rig, tw * 0.75, tw * 0.95, 0.3, cloth, Vector3(0, hip - 0.02, 0), Vector3.ZERO, CLAY, 7)
	else:
		_sph(rig, 1.0, cloth2 if not bare else cloth, Vector3(0, hip + 0.06, 0), Vector3(td * 1.05, 0.22, tw * 1.02))
		_sph(rig, 1.0, torso_col, Vector3(0, mid + 0.06, 0), Vector3(td, (top - hip) * 0.55, tw))
		if bare and brute:
			# pectorales y barriga
			for z in [-1.0, 1.0]:
				_sph(rig, 1.0, skin.lightened(0.08), Vector3(td * 0.55, top - 0.32, tw * 0.42 * z), Vector3(0.22, 0.17, 0.26))
			_sph(rig, 1.0, skin.lightened(0.05), Vector3(td * 0.45, hip + 0.38, 0), Vector3(0.32, 0.3, tw * 0.75))
		if o.get("belly", false):
			_sph(rig, 1.0, skin.lightened(0.06), Vector3(td * 0.5, hip + 0.4, 0), Vector3(0.45, 0.42, tw * 0.85))
			for i in 4:
				_box(rig, Vector3(0.03, 0.02, 0.14), DARK, Vector3(td * 0.5 + 0.43, hip + 0.25 + i * 0.1, 0.05), Vector3(0, 0, 70))
		if o.get("stitches", false):
			for i in 3:
				_box(rig, Vector3(0.02, 0.28, 0.02), DARK, Vector3(td * 0.95, mid + 0.05, -0.2 + i * 0.18), Vector3(0, 0, -10))
		if o.has("vest"):
			var vc: Color = o["vest"]
			for z in [-1.0, 1.0]:
				_sph(rig, 1.0, vc, Vector3(0.02, mid + 0.08, tw * 0.5 * z), Vector3(td * 0.98, (top - hip) * 0.5, tw * 0.55))
		if o.get("mummy", false):
			for i in 6:
				_sph(rig, 1.0, skin.darkened(0.08 + 0.05 * (i % 2)), Vector3(0, hip + 0.1 + i * (top - hip) / 6.0, 0),
						Vector3(td * 1.02, 0.045, tw * 1.03), CLAY, 8)
		# cinturón
		if not robe:
			_sph(rig, 1.0, LEATHER, Vector3(0, hip + 0.16, 0), Vector3(td * 1.08, 0.065, tw * 1.06), CLAY, 12)
			_box(rig, Vector3(0.05, 0.11, 0.13), GOLD if o.get("gold_trim", false) else Color(0.75, 0.7, 0.55), Vector3(td * 1.06, hip + 0.16, 0), Vector3.ZERO, METAL)
		if o.has("sash"):
			_sph(rig, 1.0, o["sash"], Vector3(0, hip + 0.18, 0), Vector3(td * 1.1, 0.08, tw * 1.08), CLAY, 12)
			_box(rig, Vector3(0.05, 0.3, 0.1), o["sash"], Vector3(td * 0.7, hip + 0.02, tw * 0.6), Vector3(0, 0, 10))
	# cuello
	_cyl(rig, 0.07 if not brute else 0.14, 0.09 if not brute else 0.18, 0.2, skin if not skel else BONE, Vector3(H.x * 0.5, top + 0.02, 0), Vector3.ZERO, CLAY, 8)

	# --- Armaduras
	match armor:
		"plate", "spiky", "ice":
			_sph(rig, 1.0, metal, Vector3(0.03, mid + 0.12, 0), Vector3(td * 1.06, (top - hip) * 0.46, tw * 1.05), METAL, 14)
			_cyl(rig, tw * 1.0, tw * 1.12, 0.18, metal.darkened(0.15), Vector3(0, hip + 0.05, 0), Vector3.ZERO, METAL, 10)
			_box(rig, Vector3(0.06, (top - hip) * 0.55, 0.06), GOLD if boss else metal.lightened(0.25), Vector3(td * 1.05, mid + 0.12, 0), Vector3.ZERO, METAL)
			for z in [-1.0, 1.0]:
				var sp := Vector3(0, fr["sh_y"] + 0.05, (fr["sh_z"] - 0.02) * z)
				_sph(rig, 1.0, metal, sp, Vector3(0.24, 0.16, 0.22) * (1.5 if brute else 1.0), METAL, 12)
				_sph(rig, 1.0, metal.darkened(0.2), sp + Vector3(0, -0.07, 0.05 * z), Vector3(0.22, 0.08, 0.2) * (1.5 if brute else 1.0), METAL, 10)
				if armor == "spiky" or o.get("spikes", false):
					for k in 3:
						_cone(rig, 0.05 * (1.5 if brute else 1.0), 0.24 * (1.4 if brute else 1.0), metal.darkened(0.3),
								sp + Vector3(-0.08 + k * 0.08, 0.12, 0.06 * z), Vector3(-20 * z, 0, -15 + k * 15), METAL, 5)
				if armor == "ice" or o.get("icicles", false):
					_cone(rig, 0.06, 0.3, ICE, sp + Vector3(-0.05, 0.15, 0.05 * z), Vector3(-25 * z, 0, 10), GLOW, 5)
					_cone(rig, 0.045, 0.2, ICE, sp + Vector3(0.08, 0.12, 0.1 * z), Vector3(-40 * z, 0, -20), GLOW, 5)
		"leather":
			_sph(rig, 1.0, LEATHER, Vector3(0.02, mid + 0.1, 0), Vector3(td * 1.04, (top - hip) * 0.42, tw * 1.03), CLAY, 12)
			for i in 3:
				_sph(rig, 0.03, metal, Vector3(td * 1.02, mid - 0.05 + i * 0.12, tw * 0.45), Vector3.ONE, METAL, 6)
				_sph(rig, 0.03, metal, Vector3(td * 1.02, mid - 0.05 + i * 0.12, -tw * 0.45), Vector3.ONE, METAL, 6)
			_sph(rig, 1.0, metal, Vector3(0, fr["sh_y"] + 0.05, -fr["sh_z"]), Vector3(0.22, 0.14, 0.2) * (1.4 if brute else 1.0), METAL, 12)
	if o.get("collar", false):
		_cyl(rig, tw * 0.75, tw * 1.05, 0.14, GOLD, Vector3(0, top - 0.06, 0), Vector3.ZERO, METAL, 14)
		for i in 5:
			var a := -PI / 2.5 + i * PI / 5.0
			_sph(rig, 0.045, Color(0.15, 0.4, 0.9) if i % 2 == 0 else Color(0.85, 0.2, 0.15), Vector3(cos(a) * tw * 0.95, top - 0.1, sin(a) * tw * 0.95), Vector3.ONE, METAL, 6)
	if o.get("high_collar", false):
		for z in [-1.0, 1.0]:
			_plate(rig, [Vector2(-0.1, 0), Vector2(0.12, 0), Vector2(-0.08, 0.38), Vector2(0.06, 0.32)], 0.04, Color(o["col"]).darkened(0.2),
					Vector3(-0.05, top - 0.08, 0.2 * z), Vector3(80 * z, 0, 0))
	if o.get("fur", false) and not armor in ["plate", "spiky"]:
		for i in 7:
			var a := TAU * i / 7.0
			_sph(rig, 0.16 if not brute else 0.22, skin.lightened(0.06), Vector3(cos(a) * td * 0.9, top - 0.05, sin(a) * tw * 0.9), Vector3(1, 0.8, 1), CLAY, 8)
	if o.get("moss", false):
		for i in 5:
			var a := TAU * i / 5.0 + 0.4
			_sph(rig, 0.12, Color(0.3, 0.45, 0.15), Vector3(cos(a) * td * 0.8, top - 0.1 - (i % 2) * 0.3, sin(a) * tw * 0.85), Vector3(1, 0.6, 1), CLAY, 8)
	if o.get("feathers", false):
		for i in 3:
			_box(rig, Vector3(0.04, 0.3, 0.1), [Color(0.85, 0.2, 0.15), Color(0.95, 0.8, 0.2), Color(0.2, 0.5, 0.85)][i],
					Vector3(-td * 0.6, top + 0.05, -0.15 + i * 0.15), Vector3(0, 0, 25))
	if o.get("leaves", false):
		for i in 6:
			var a := TAU * i / 6.0
			_sph(rig, 0.1, Color(0.3, 0.55, 0.2).darkened(0.1 * (i % 3)), Vector3(cos(a) * td * 0.95, top - 0.08, sin(a) * tw * 0.95), Vector3(1.3, 0.5, 1), CLAY, 6)
	if o.get("quiver", false):
		var qg := _grp(rig, Vector3(-td - 0.05, mid + 0.1, 0), Vector3(25, 0, 10))
		_cyl(qg, 0.1, 0.09, 0.55, LEATHER, Vector3.ZERO, Vector3.ZERO, CLAY, 8)
		for i in 3:
			_seg(qg, 0.015, 0.015, WOOD, Vector3(0, 0.2, (i - 1) * 0.05), Vector3(0, 0.45, (i - 1) * 0.06))
			_box(qg, Vector3(0.02, 0.08, 0.06), WHITE, Vector3(0, 0.45, (i - 1) * 0.06))
	if o.has("aura"):
		_sph(rig, 0.08, Color(o["aura"]).lightened(0.3), Vector3(td + 0.05, mid + 0.15, 0), Vector3.ONE, GLOW, 8)
	if boss and not o.get("collar", false):
		# medallón del jefe
		_cyl(rig, 0.1, 0.1, 0.04, GOLD, Vector3(td * 1.08 + 0.02, mid + 0.18, 0), Vector3(0, 0, 90), METAL, 10)
		_sph(rig, 0.06, RED_GLOW, Vector3(td * 1.08 + 0.05, mid + 0.18, 0), Vector3(0.6, 1, 1), GLOW, 8)

	# --- Piernas, falda de túnica o cola de humo
	if robe:
		var skirt := _pivot(rig, "Robe", Vector3(0, hip + 0.2, 0), Vector3.ZERO, [_tr(ROT, 2, 0.06, WALK, 0.5)])
		var h := hip + 0.2
		_cyl(skirt, tw * 0.95, tw * 1.5, h, cloth, Vector3(0, -h * 0.5, 0), Vector3.ZERO, CLAY, 12)
		_cyl(skirt, tw * 1.5, tw * 1.55, 0.09, cloth2, Vector3(0, -h + 0.05, 0), Vector3.ZERO, CLAY, 12)
		_box(skirt, Vector3(0.05, h * 0.95, 0.14), cloth2, Vector3(tw * 1.18, -h * 0.5, 0), Vector3(0, 0, -16))
		for z in [-1.0, 1.0]:
			_sph(skirt, 0.1, LEATHER.darkened(0.3) if not o.get("skeleton_hands", false) else BONE, Vector3(tw * 1.35, -h + 0.04, 0.16 * z), Vector3(1.4, 0.7, 1), CLAY, 8)
		_cyl(rig, tw * 1.02, tw * 1.08, 0.08, cloth2, Vector3(0, hip + 0.14, 0), Vector3.ZERO, CLAY, 12)
	elif smoke:
		var tail := _pivot(rig, "Smoke", Vector3(0, hip + 0.1, 0), Vector3.ZERO, [_tr(ROT, 1, 0.5, 2.0, 0.0, false)])
		var sc := Color(Color(o["col"]).lightened(0.3), 0.75)
		for i in 6:
			var a := i * 1.3
			var f := 1.0 - i / 6.0
			_sph(tail, tw * (0.4 + 0.6 * f), sc, Vector3(cos(a) * 0.12 * (1.0 - f), -i * (hip / 6.0), sin(a) * 0.12 * (1.0 - f)), Vector3(1, 0.7, 1), GHOST, 10)
		_cyl(rig, tw * 1.02, tw * 1.05, 0.1, GOLD, Vector3(0, hip + 0.12, 0), Vector3.ZERO, METAL, 12)
	else:
		var leg_z := tw * (0.48 if not skel else 0.55)
		var amp := 0.55 if not brute else 0.38
		for z in [-1.0, 1.0]:
			var lp := _pivot(rig, "LegL" if z < 0 else "LegR", Vector3(0, hip, leg_z * z), Vector3.ZERO,
					[_tr(ROT, 2, amp, WALK, 0.0 if z < 0 else PI)])
			_leg(lp, o, fr, z)

	# --- Cola (kobolds, demonios, dracónidos)
	if o.has("tail") and not smoke:
		var tc: Color = o["tail"]
		var tp := _pivot(rig, "Tail", Vector3(-td * 0.8, hip + 0.1, 0), Vector3.ZERO, [_tr(ROT, 1, 0.35, WALK * 0.5, 0.0, false)])
		var L := 0.7 if not brute else 1.0
		var pts := [Vector3.ZERO, Vector3(-L * 0.35, -hip * 0.45, 0), Vector3(-L * 0.7, -hip * 0.75, 0.05), Vector3(-L, -hip * 0.85 + 0.05, -0.05)]
		_chain(tp, pts, 0.11 if not brute else 0.18, 0.03, tc)
		if o.get("head", "") == "demon":
			var tip: Vector3 = pts[3]
			_cone(tp, 0.08, 0.16, tc.darkened(0.3), tip + Vector3(-0.06, 0.02, 0), Vector3(0, 0, 90), CLAY, 4)

	# --- Capa
	if o.has("cape") or (boss and not robe and not smoke):
		var cc: Color = o.get("cape", Color(0.6, 0.1, 0.12))
		var cape := _pivot(rig, "Cape", Vector3(-td * 0.9, top - 0.05, 0), Vector3.ZERO, [_tr(ROT, 2, 0.12, WALK, 0.3)])
		var ch := top - 0.12
		_box(cape, Vector3(0.05, ch, tw * 2.0), cc, Vector3(-0.08, -ch * 0.5, 0), Vector3(0, 0, -9))
		_box(cape, Vector3(0.06, 0.12, tw * 2.15), GOLD if boss else cc.darkened(0.3), Vector3(-0.01, -0.03, 0), Vector3.ZERO, METAL if boss else CLAY)
		_cyl(cape, 0.02, 0.02, tw * 2.2, cc.darkened(0.25), Vector3(-0.16, -ch + 0.03, 0), Vector3(90, 0, 0), CLAY, 6)

	# --- Alas fijas a la espalda (decorativas)
	match str(o.get("wings", "")):
		"bat":
			for z in [-1.0, 1.0]:
				var wc: Color = Color(o["col"]).darkened(0.35)
				var base := Vector3(-td * 0.9, top - 0.1, tw * 0.5 * z)
				_seg(rig, 0.05, 0.03, wc, base, base + Vector3(-0.3, 0.55, 0.45 * z))
				for k in 3:
					var tip := base + Vector3(-0.3 - k * 0.25, 0.5 - k * 0.45, 0.5 * z + k * 0.15 * z)
					_seg(rig, 0.025, 0.015, wc, base + Vector3(-0.3, 0.55, 0.45 * z), tip)
				_plate(rig, [Vector2(0, 0), Vector2(-0.3, 0.55), Vector2(-0.8, -0.4), Vector2(-0.55, 0.1)], 0.03, wc.lightened(0.1),
						base + Vector3(0, 0, 0.25 * z), Vector3(-60 * z, 0, 0))
		"angel", "fallen":
			var fallen: bool = o["wings"] == "fallen"
			var fcol := WHITE if not fallen else Color(0.2, 0.15, 0.25)
			for z in [-1.0, 1.0]:
				var base := Vector3(-td * 0.9, top - 0.1, tw * 0.45 * z)
				for k in 5:
					var a := deg_to_rad(20 + k * 22)
					var L := 0.75 - k * 0.08
					var d := Vector3(-cos(a) * 0.6, sin(a) * 0.9, 0.45 * z).normalized()
					_seg(rig, 0.07, 0.03 if not fallen else 0.015, fcol.darkened(k * 0.04), base, base + d * L)

	# --- Brazos
	var rh: String = o.get("rh", "")
	var lh: String = o.get("lh", "")
	for z in [-1.0, 1.0]:
		var item := rh if z > 0 else lh
		var base_rot := 0.0
		if o.get("zombie_arms", false):
			base_rot = 75.0 if z > 0 else 85.0
		elif item in ["crossbow"]:
			base_rot = 55.0
		elif item != "":
			base_rot = 22.0 if item not in ["sack", "potion", "censer", "lantern"] else 5.0
		var amp := 0.42 if item == "" else 0.22
		if robe or smoke:
			amp *= 0.5
		if o.get("zombie_arms", false):
			amp = 0.12
		var ap := _pivot(rig, "ArmL" if z < 0 else "ArmR", Vector3(0, fr["sh_y"], fr["sh_z"] * z), Vector3(0, 0, base_rot),
				[_tr(ROT, 2, amp, WALK, PI if z < 0 else 0.0)])
		_arm(ap, o, fr, z, item)

	# --- Cabeza y sombrero
	_head(rig, o, H, hr)
	var hat_top := _hat(rig, o, H, hr)
	if crowned:
		var hat: String = o.get("hat", "")
		if hat not in ["crown", "crown_hood", "lich_crown", "ice_crown", "nemes", "witch", "wizard", "halo", "straw", "turban", "pointy", "exec_hood"]:
			_crown(rig, Vector3(H.x, hat_top + 0.06, 0), hr * 2.0 * (0.9 if hat == "" else 0.8))
	if o.get("flame_head", false):
		var fl := _pivot(rig, "Flame", Vector3(H.x - 0.05, H.y + hr * 0.7, 0), Vector3.ZERO, [_tr(SCL, 1, 0.25, 14.0, 0.0, false, FLICKER)])
		_cone(fl, hr * 0.6, hr * 1.2, FIRE, Vector3(0, hr * 0.5, 0), Vector3(0, 0, 15), GLOW, 7)
		_cone(fl, hr * 0.35, hr * 0.8, FIRE_HOT, Vector3(0.03, hr * 0.4, 0), Vector3(0, 0, 10), GLOW, 6)
	if o.get("fire", false) and not o.get("flame_head", false):
		# brasas en los hombros (inmune al fuego)
		for z in [-1.0, 1.0]:
			_sph(rig, 0.05, FIRE, Vector3(-0.05, fr["sh_y"] + 0.12, fr["sh_z"] * z * 0.9), Vector3.ONE, GLOW, 6)
	if o.get("ice", false) and armor != "ice" and not o.get("icicles", false):
		for z in [-1.0, 1.0]:
			_cone(rig, 0.05, 0.22, ICE, Vector3(-0.05, fr["sh_y"] + 0.1, fr["sh_z"] * z * 0.9), Vector3(-25 * z, 0, 10), GLOW, 5)


static func _leg(lp: Node3D, o: Dictionary, fr: Dictionary, z: float) -> void:
	var hip: float = fr["hip"]
	var r: float = fr["leg"]
	var skin: Color = o.get("skin", SKIN)
	var cloth2: Color = o.get("cloth2", Color(o["col"]).darkened(0.35))
	var armor: String = o.get("armor", "")
	var metal: Color = o.get("metal", IRON)
	var foot := Vector3(0.04, -hip + 0.06, 0)
	match str(o.get("frame", "")):
		"skeleton":
			_seg(lp, r, r * 0.8, BONE, Vector3.ZERO, Vector3(0, -hip * 0.5, 0))
			_sph(lp, r * 1.5, BONE, Vector3(0, -hip * 0.5, 0), Vector3.ONE, CLAY, 6)
			_seg(lp, r * 0.8, r * 0.7, BONE, Vector3(0, -hip * 0.5, 0), Vector3(0, -hip + 0.08, 0))
			if armor == "plate":
				_cyl(lp, 0.09, 0.08, 0.3, metal, Vector3(0.0, -hip * 0.72, 0), Vector3.ZERO, METAL, 8)
			_box(lp, Vector3(0.24, 0.07, 0.11), BONE if armor != "plate" else metal, foot + Vector3(0.05, -0.02, 0), Vector3.ZERO, CLAY if armor != "plate" else METAL)
			return
	var bare: bool = o.get("bare", false)
	var leg_col := cloth2
	if o.get("mummy", false):
		leg_col = skin
	elif bare and str(o.get("frame", "")) in ["brute", "gaunt", "small"]:
		leg_col = skin
	_seg(lp, r, r * 0.85, leg_col, Vector3(0, 0.02, 0), Vector3(0, -hip * 0.55, 0), CLAY, 8)
	_sph(lp, r * 0.92, leg_col, Vector3(0, -hip * 0.55, 0), Vector3.ONE, CLAY, 8)
	_seg(lp, r * 0.85, r * 0.75, leg_col, Vector3(0, -hip * 0.55, 0), Vector3(0, -hip + 0.1, 0), CLAY, 8)
	if o.get("mummy", false):
		_sph(lp, r * 1.05, skin.darkened(0.12), Vector3(0, -hip * 0.3, 0), Vector3(1, 0.3, 1), CLAY, 8)
		_sph(lp, r * 0.95, skin.darkened(0.12), Vector3(0, -hip * 0.75, 0), Vector3(1, 0.3, 1), CLAY, 8)
	if bare and o.get("frame", "") == "brute" and not o.get("fur", false):
		# taparrabos
		_box(lp, Vector3(0.05, 0.32, r * 1.6), Color(o.get("cloth", LEATHER)), Vector3(r * 0.9, -0.12, -0.04 * z), Vector3(0, 0, -6))
	if o.get("fur", false):
		_sph(lp, r * 1.25, skin.lightened(0.05), Vector3(0, -hip * 0.35, 0), Vector3(1, 1.2, 1), CLAY, 8)
	if armor in ["plate", "spiky", "ice"]:
		_cyl(lp, r * 1.15, r * 1.05, hip * 0.35, metal, Vector3(0, -hip * 0.78, 0), Vector3.ZERO, METAL, 8)
		_sph(lp, r * 1.15, metal.lightened(0.1), Vector3(r * 0.4, -hip * 0.55, 0), Vector3(0.8, 0.9, 1), METAL, 8)
	if o.get("claws", false) or o.get("head", "") in ["demon", "kobold", "lizard", "frog", "wendigo"] and bare:
		# pies con garras
		_sph(lp, 1.0, skin.darkened(0.1), foot + Vector3(0.05, 0, 0), Vector3(r * 1.9, r * 0.8, r * 1.4), CLAY, 8)
		for k in [-1.0, 0.0, 1.0]:
			_cone(lp, r * 0.25, r * 0.9, Color(0.15, 0.12, 0.1) if o.get("head", "") != "frog" else skin.lightened(0.15),
					foot + Vector3(r * 1.6, -0.02, k * r * 0.6), Vector3(0, 0, -90), CLAY, 4)
		return
	var boot := LEATHER.darkened(0.25)
	if armor in ["plate", "spiky", "ice"]:
		boot = metal.darkened(0.1)
	elif o.get("mummy", false):
		boot = skin.darkened(0.1)
	var bk := METAL if armor in ["plate", "spiky", "ice"] else CLAY
	_box(lp, Vector3(r * 2.6, 0.14, r * 1.9), boot, foot + Vector3(r * 0.5, 0, 0), Vector3.ZERO, bk)
	_cyl(lp, r * 1.05, r * 1.1, 0.16, boot, foot + Vector3(0, 0.1, 0), Vector3.ZERO, bk, 8)


static func _arm(ap: Node3D, o: Dictionary, fr: Dictionary, z: float, item: String) -> void:
	var L: float = fr["arm"]
	var r: float = fr["arm_r"]
	var skin: Color = o.get("skin", SKIN)
	var cloth: Color = o.get("cloth", o["col"])
	var bare: bool = o.get("bare", false)
	var armor: String = o.get("armor", "")
	var metal: Color = o.get("metal", IRON)
	var hand := Vector3(0.06, -L, 0.04 * z)
	var elbow := Vector3(-0.02, -L * 0.5, 0.03 * z)
	var skel: bool = o.get("frame", "") == "skeleton"
	if skel:
		_seg(ap, r, r * 0.9, BONE, Vector3.ZERO, elbow)
		_sph(ap, r * 1.4, BONE, elbow, Vector3.ONE, CLAY, 6)
		_seg(ap, r * 0.9, r * 0.8, BONE, elbow, hand)
		_sph(ap, r * 1.8, BONE, Vector3.ZERO, Vector3.ONE, CLAY, 8)
		if armor == "plate":
			_sph(ap, 1.0, metal, Vector3(0, 0.03, 0), Vector3(0.14, 0.11, 0.13), METAL, 10)
	elif o.get("tentacle_arms", false):
		var pts := [Vector3.ZERO, Vector3(0.05, -L * 0.35, 0.08 * z), Vector3(0.12, -L * 0.7, 0.02 * z), Vector3(0.25, -L * 0.95, 0.1 * z), Vector3(0.38, -L * 0.9, 0.12 * z)]
		_chain(ap, pts, r * 1.2, r * 0.3, skin)
		for i in 4:
			_sph(ap, r * 0.28, skin.lightened(0.35), (pts[i] as Vector3).lerp(pts[i + 1], 0.5) + Vector3(0.02, -r * 0.6, 0), Vector3.ONE, CLAY, 6)
		return
	else:
		var sleeve := skin if bare else cloth
		if o.get("robe", false):
			sleeve = cloth
		_sph(ap, r * 1.35, sleeve, Vector3.ZERO, Vector3.ONE, CLAY, 8)
		_seg(ap, r * 1.1, r, sleeve, Vector3.ZERO, elbow)
		_sph(ap, r, sleeve, elbow, Vector3.ONE, CLAY, 8)
		var fore := skin if (bare or o.get("mummy", false)) else sleeve
		_seg(ap, r, r * 0.9, fore, elbow, hand)
		if o.get("robe", false):
			# manga acampanada
			_cyl(ap, r * 1.2, r * 1.8, L * 0.35, cloth, hand.lerp(elbow, 0.3) + Vector3(0, 0.02, 0), Vector3(0, 0, 10), CLAY, 8)
		if o.get("mummy", false):
			for i in 3:
				_sph(ap, r * 1.08, skin.darkened(0.12), Vector3.ZERO.lerp(hand, 0.25 + i * 0.25), Vector3(1, 0.35, 1), CLAY, 8)
		if armor in ["plate", "spiky", "ice"]:
			_cyl(ap, r * 1.25, r * 1.15, L * 0.35, metal, elbow.lerp(hand, 0.5), Vector3.ZERO, METAL, 8)
		if o.get("fur", false):
			_sph(ap, r * 1.4, skin.lightened(0.05), elbow, Vector3(1, 1.4, 1), CLAY, 8)
	# mano
	var hand_col := skin
	if skel or o.get("skeleton_hands", false):
		hand_col = BONE
	elif armor in ["plate", "spiky", "ice"]:
		hand_col = metal.darkened(0.15)
	_sph(ap, r * 1.3, hand_col, hand, Vector3(1, 1.1, 0.9), METAL if hand_col == metal.darkened(0.15) else CLAY, 8)
	if o.get("claws", false) or o.get("head", "") in ["demon", "wendigo"]:
		for k in [-1.0, 0.0, 1.0]:
			_cone(ap, r * 0.28, r * (1.4 if o.get("claws", false) else 0.9), Color(0.12, 0.1, 0.1) if not o.get("fur", false) else Color(0.25, 0.25, 0.3),
					hand + Vector3(0.04, -r * 1.1, k * r * 0.5), Vector3(0, 0, -160), CLAY, 4)
	if item != "":
		_hand_item(ap, item, o, hand, z, r)


## Arma u objeto en la mano. El grupo se orienta para que su +Y sea la dirección del arma.
static func _hand_item(ap: Node3D, item: String, o: Dictionary, hand: Vector3, z: float, r: float) -> void:
	var ic: Color = o.get("item_col", PURPLE_GLOW)
	var boss: bool = o.get("boss", false)
	var s := 1.0
	if o.get("frame", "") == "brute":
		s = 1.45
	elif o.get("frame", "") in ["small", "dwarf"]:
		s = 0.85
	match item:
		"dagger", "sword", "scimitar", "flail_sword":
			var g := _grp(ap, hand, Vector3(0, 0, -62), Vector3.ONE * s)
			var L := 0.42 if item == "dagger" else 0.82
			_cyl(g, 0.035, 0.035, 0.2, LEATHER, Vector3(0, 0, 0), Vector3.ZERO, CLAY, 6)
			_sph(g, 0.05, GOLD if boss else IRON, Vector3(0, -0.12, 0), Vector3.ONE, METAL, 6)
			_box(g, Vector3(0.07, 0.06, 0.3 if item != "dagger" else 0.18), GOLD if boss else IRON, Vector3(0, 0.11, 0), Vector3.ZERO, METAL)
			if item == "scimitar":
				for i in 3:
					_box(g, Vector3(0.15 - i * 0.02, L / 3.0 + 0.04, 0.035), STEEL, Vector3(0.03 + i * i * 0.025, 0.17 + L / 6.0 + i * L / 3.0, 0), Vector3(0, 0, -i * 12), METAL)
			else:
				_box(g, Vector3(0.12, L, 0.035), STEEL, Vector3(0, 0.14 + L * 0.5, 0), Vector3.ZERO, METAL)
				_cone(g, 0.085, 0.14, STEEL, Vector3(0, 0.14 + L + 0.06, 0), Vector3(0, 45, 0), METAL, 4)
				_box(g, Vector3(0.03, L * 0.8, 0.045), STEEL.darkened(0.2), Vector3(0, 0.14 + L * 0.45, 0), Vector3.ZERO, METAL)
				if item == "flail_sword":
					for i in 3:
						_cone(g, 0.035, 0.12, Color(0.5, 0.1, 0.3), Vector3(0.07, 0.3 + i * 0.22, 0), Vector3(0, 0, -90), METAL, 4)
					_box(g, Vector3(0.025, L * 0.8, 0.05), Color(1.0, 0.3, 0.6), Vector3(0, 0.14 + L * 0.45, 0), Vector3.ZERO, GLOW)
		"axe", "greataxe":
			var big: bool = item == "greataxe"
			var g := _grp(ap, hand, Vector3(0, 0, -35), Vector3.ONE * s)
			var L := 1.0 if not big else 1.5
			_seg(g, 0.04, 0.04, WOOD, Vector3(0, -0.25, 0), Vector3(0, L - 0.25, 0))
			var hp := Vector3(0, L - 0.4, 0)
			for side in ([1.0] if not big else [1.0, -1.0]):
				_plate(g, [Vector2(0, -0.1), Vector2(0, 0.1), Vector2(0.32, -0.22), Vector2(0.36, 0.0), Vector2(0.32, 0.22)], 0.05,
						STEEL, hp + Vector3(0.03 * side, 0, 0), Vector3(90, 0, 0 if side > 0 else 180), METAL)
			_cyl(g, 0.06, 0.06, 0.16, IRON, hp, Vector3.ZERO, METAL, 6)
			if big:
				_cone(g, 0.05, 0.25, STEEL, Vector3(0, L - 0.12, 0), Vector3.ZERO, METAL, 5)
		"club", "tree_club", "ice_club":
			var g := _grp(ap, hand, Vector3(0, 0, -40), Vector3.ONE * s)
			var cc: Color = o.get("club_col", WOOD)
			if item == "ice_club":
				cc = ICE
			_seg(g, 0.06, 0.15, cc, Vector3(0, -0.15, 0), Vector3(0, 0.75, 0), CLAY if item != "ice_club" else GLOW)
			_sph(g, 0.16, cc, Vector3(0, 0.77, 0), Vector3.ONE, CLAY if item != "ice_club" else GLOW, 8)
			if item == "tree_club":
				for i in 3:
					_seg(g, 0.04, 0.015, WOOD_DARK, Vector3(0, 0.3 + i * 0.18, 0), Vector3(0.18 * (1 - 2 * (i % 2)), 0.45 + i * 0.2, 0.08))
					_sph(g, 0.08, Color(0.3, 0.5, 0.2), Vector3(0.19 * (1 - 2 * (i % 2)), 0.47 + i * 0.2, 0.08), Vector3.ONE, CLAY, 6)
			elif item == "ice_club":
				for i in 4:
					var a := TAU * i / 4.0
					_cone(g, 0.05, 0.2, ICE_GLOW, Vector3(cos(a) * 0.14, 0.7, sin(a) * 0.14), Vector3(rad_to_deg(sin(a)) * 0.8, 0, -rad_to_deg(cos(a)) * 0.8), GLOW, 4)
			else:
				for i in 4:
					var a := TAU * i / 4.0 + 0.4
					_cone(g, 0.03, 0.1, IRON, Vector3(cos(a) * 0.15, 0.7 + (i % 2) * 0.1, sin(a) * 0.15), Vector3(rad_to_deg(sin(a)), 0, -rad_to_deg(cos(a))), METAL, 4)
		"pitchfork", "trident", "spear", "spear_gold", "halberd":
			var g := _grp(ap, hand, Vector3(0, 0, -15), Vector3.ONE * s)
			var gold := item == "spear_gold"
			var shaft := WOOD if not gold else WHITE
			_seg(g, 0.035, 0.035, shaft, Vector3(0, -0.7, 0), Vector3(0, 0.95, 0))
			var tipc := STEEL if not gold else GOLD
			if item in ["pitchfork", "trident"]:
				_box(g, Vector3(0.05, 0.05, 0.3), tipc, Vector3(0, 0.95, 0), Vector3.ZERO, METAL)
				for k in [-1.0, 0.0, 1.0]:
					_cyl(g, 0.02, 0.025, 0.3, tipc, Vector3(0, 1.1, k * 0.13), Vector3.ZERO, METAL, 5)
					if item == "trident":
						_cone(g, 0.045, 0.1, tipc, Vector3(0, 1.28, k * 0.13), Vector3.ZERO, METAL, 4)
			elif item == "halberd":
				_cone(g, 0.05, 0.3, tipc, Vector3(0, 1.1, 0), Vector3.ZERO, METAL, 4)
				_plate(g, [Vector2(0, -0.12), Vector2(0, 0.12), Vector2(0.28, -0.2), Vector2(0.3, 0.15)], 0.04, tipc, Vector3(0.02, 0.85, 0), Vector3(90, 0, 0), METAL)
				_cone(g, 0.03, 0.15, tipc, Vector3(-0.1, 0.85, 0), Vector3(0, 0, 90), METAL, 4)
			else:
				_cone(g, 0.07, 0.28, tipc, Vector3(0, 1.08, 0), Vector3.ZERO, METAL, 4)
				if gold:
					_sph(g, 0.06, Color(0.7, 0.9, 1.0), Vector3(0, 0.93, 0), Vector3.ONE, GLOW, 8)
				else:
					_box(g, Vector3(0.04, 0.12, 0.12), Color(0.75, 0.2, 0.15), Vector3(0, 0.9, 0), Vector3.ZERO, CLAY)
		"orb_staff", "ice_staff", "crystal_staff", "fire_staff", "skull_staff", "bone_staff", "druid_staff", "eye_staff", "broom", "crook":
			var g := _grp(ap, hand, Vector3(0, 0, -18), Vector3.ONE * s)
			var stc := WOOD
			if item in ["ice_staff", "crystal_staff"]:
				stc = Color(0.85, 0.9, 1.0) if item == "ice_staff" else Color(0.3, 0.25, 0.4)
			elif item == "skull_staff" or item == "eye_staff":
				stc = Color(0.18, 0.15, 0.18)
			elif item == "bone_staff":
				stc = BONE
			elif item == "crook":
				stc = GOLD
			_seg(g, 0.04, 0.045, stc, Vector3(0, -0.85, 0), Vector3(0, 0.75, 0), METAL if item == "crook" else CLAY)
			var tp := Vector3(0, 0.82, 0)
			match item:
				"orb_staff":
					for k in 3:
						var a := TAU * k / 3.0
						_seg(g, 0.025, 0.015, GOLD, tp + Vector3(0, -0.08, 0), tp + Vector3(cos(a) * 0.12, 0.12, sin(a) * 0.12), METAL)
					_sph(g, 0.12, ic, tp + Vector3(0, 0.1, 0), Vector3.ONE, GLOW, 10)
				"ice_staff":
					for k in 4:
						var a := TAU * k / 4.0
						_cone(g, 0.045, 0.26, ICE_GLOW, tp + Vector3(cos(a) * 0.05, 0.05, sin(a) * 0.05), Vector3(rad_to_deg(sin(a)) * 0.4, 0, -rad_to_deg(cos(a)) * 0.4), GLOW, 5)
					_cone(g, 0.06, 0.4, ic, tp + Vector3(0, 0.15, 0), Vector3.ZERO, GLOW, 5)
				"crystal_staff":
					_cone(g, 0.08, 0.36, ic, tp + Vector3(0, 0.18, 0), Vector3.ZERO, GLOW, 5)
					_cone(g, 0.08, 0.14, ic, tp + Vector3(0, -0.04, 0), Vector3(180, 0, 0), GLOW, 5)
					for k in 2:
						_cone(g, 0.04, 0.2, ic.lightened(0.3), tp + Vector3(0, 0.05, 0.1 * (2 * k - 1)), Vector3(40 * (2 * k - 1), 0, 0), GLOW, 4)
				"fire_staff":
					_cyl(g, 0.1, 0.06, 0.1, IRON, tp, Vector3.ZERO, METAL, 8)
					_cone(g, 0.11, 0.32, FIRE, tp + Vector3(0, 0.2, 0), Vector3.ZERO, GLOW, 7)
					_cone(g, 0.06, 0.22, FIRE_HOT, tp + Vector3(0.01, 0.17, 0), Vector3.ZERO, GLOW, 6)
				"skull_staff", "bone_staff":
					_sph(g, 0.12, BONE, tp + Vector3(0, 0.08, 0), Vector3(1.0, 0.95, 0.9), CLAY, 8)
					_box(g, Vector3(0.1, 0.06, 0.12), BONE, tp + Vector3(0.04, -0.03, 0), Vector3.ZERO)
					for k in [-1.0, 1.0]:
						_sph(g, 0.035, ic, tp + Vector3(0.1, 0.09, 0.045 * k), Vector3.ONE, GLOW, 6)
					if item == "bone_staff":
						for k in 3:
							_box(g, Vector3(0.03, 0.2, 0.06), [Color(0.85, 0.2, 0.15), Color(0.95, 0.8, 0.2), WHITE][k], tp + Vector3(-0.05, -0.15, -0.06 + k * 0.06), Vector3(0, 0, 15 - k * 10))
				"druid_staff":
					_seg(g, 0.04, 0.03, stc, tp + Vector3(0, -0.07, 0), tp + Vector3(0.15, 0.2, 0.05))
					_seg(g, 0.035, 0.025, stc, tp + Vector3(0, -0.07, 0), tp + Vector3(-0.12, 0.22, -0.04))
					_sph(g, 0.1, ic, tp + Vector3(0.0, 0.12, 0), Vector3.ONE, GLOW, 8)
					for k in 4:
						var a := TAU * k / 4.0
						_sph(g, 0.06, Color(0.3, 0.55, 0.2), tp + Vector3(cos(a) * 0.12, 0.0, sin(a) * 0.12), Vector3(1.4, 0.5, 1), CLAY, 6)
				"eye_staff":
					_cyl(g, 0.14, 0.14, 0.03, Color(0.25, 0.15, 0.3), tp + Vector3(0, 0.14, 0), Vector3(0, 0, 90), METAL, 12)
					_sph(g, 0.1, WHITE, tp + Vector3(0.02, 0.14, 0), Vector3(0.6, 1, 1), CLAY, 8)
					_sph(g, 0.055, ic, tp + Vector3(0.06, 0.14, 0), Vector3(0.6, 1, 1), GLOW, 8)
				"broom":
					_cyl(g, 0.05, 0.16, 0.36, Color(0.75, 0.6, 0.3), Vector3(0, -0.98, 0), Vector3.ZERO, CLAY, 8)
					_cyl(g, 0.055, 0.055, 0.05, ROPE.darkened(0.3), Vector3(0, -0.82, 0), Vector3.ZERO, CLAY, 8)
				"crook":
					_chain(g, [tp, tp + Vector3(0.05, 0.14, 0), tp + Vector3(0.16, 0.2, 0), tp + Vector3(0.25, 0.12, 0)], 0.045, 0.04, GOLD, METAL)
					for k in 4:
						_cyl(g, 0.048, 0.048, 0.06, Color(0.15, 0.3, 0.75), Vector3(0, 0.1 + k * 0.17, 0), Vector3.ZERO, CLAY, 8)
		"hammer":
			var g := _grp(ap, hand, Vector3(0, 0, -40), Vector3.ONE * s)
			_seg(g, 0.035, 0.035, WOOD_DARK, Vector3(0, -0.15, 0), Vector3(0, 0.6, 0))
			_box(g, Vector3(0.22, 0.2, 0.36), STEEL, Vector3(0, 0.66, 0), Vector3.ZERO, METAL)
			_box(g, Vector3(0.24, 0.05, 0.38), GOLD, Vector3(0, 0.66, 0), Vector3.ZERO, METAL)
		"mace":
			var g := _grp(ap, hand, Vector3(0, 0, -45), Vector3.ONE * s)
			_seg(g, 0.035, 0.035, WOOD_DARK, Vector3(0, -0.12, 0), Vector3(0, 0.55, 0))
			_sph(g, 0.13, IRON, Vector3(0, 0.62, 0), Vector3.ONE, METAL, 8)
			for k in 6:
				var a := TAU * k / 6.0
				_cone(g, 0.04, 0.11, IRON, Vector3(cos(a) * 0.13, 0.62, sin(a) * 0.13), Vector3(rad_to_deg(sin(a)), 0, -rad_to_deg(cos(a))) * 1.0 + Vector3(0, 0, 0), METAL, 4)
		"cleaver":
			var g := _grp(ap, hand, Vector3(0, 0, -50), Vector3.ONE * s)
			_cyl(g, 0.04, 0.04, 0.22, WOOD_DARK, Vector3.ZERO, Vector3.ZERO, CLAY, 6)
			_box(g, Vector3(0.36, 0.55, 0.04), IRON, Vector3(0.1, 0.38, 0), Vector3.ZERO, METAL)
			_box(g, Vector3(0.05, 0.55, 0.05), Color(0.6, 0.15, 0.12), Vector3(0.28, 0.38, 0), Vector3.ZERO, CLAY)
		"hook":
			var g := _grp(ap, hand, Vector3(0, 0, 160), Vector3.ONE * s)
			_chain(g, [Vector3.ZERO, Vector3(0, 0.2, 0), Vector3(0.1, 0.32, 0), Vector3(0.2, 0.25, 0), Vector3(0.18, 0.12, 0)], 0.035, 0.02, IRON, METAL, false)
		"crossbow":
			var g := _grp(ap, hand, Vector3(0, 0, -95), Vector3.ONE * s)
			_box(g, Vector3(0.08, 0.6, 0.08), WOOD, Vector3(0, 0.15, -0.05 * z))
			var bp := Vector3(0, 0.42, -0.05 * z)
			for k in [-1.0, 1.0]:
				_seg(g, 0.025, 0.018, WOOD_DARK, bp, bp + Vector3(0.0, -0.08, 0.3 * k))
			_seg(g, 0.006, 0.006, WHITE, bp + Vector3(0, -0.08, 0.3), bp + Vector3(0, -0.08, -0.3))
			_box(g, Vector3(0.03, 0.4, 0.03), STEEL, Vector3(0.05, 0.3, -0.05 * z), Vector3.ZERO, METAL)
		"shield_round", "shield_kite":
			var sc: Color = o.get("shield_col", WOOD)
			var g := _grp(ap, hand + Vector3(0.0, 0.05, 0.1 * z), Vector3(0, -25 * z, 0), Vector3.ONE * s)
			if item == "shield_round":
				_cyl(g, 0.3, 0.3, 0.06, sc, Vector3.ZERO, Vector3(90, 0, 0), CLAY, 12)
				_cyl(g, 0.31, 0.31, 0.03, IRON, Vector3(0, 0, 0), Vector3(90, 0, 0), METAL, 12)
				_sph(g, 0.08, IRON, Vector3(0, 0, 0.05 * z), Vector3(1, 1, 0.6), METAL, 8)
				for k in 2:
					_box(g, Vector3(0.58, 0.04, 0.07), WOOD_DARK, Vector3(0, -0.1 + k * 0.2, 0.0), Vector3.ZERO)
			else:
				_plate(g, [Vector2(-0.24, -0.2), Vector2(0.24, -0.2), Vector2(-0.22, 0.12), Vector2(0.22, 0.12), Vector2(0, 0.42)], 0.06, sc,
						Vector3(0, 0.15, 0), Vector3(-90, 0, 180), CLAY)
				_plate(g, [Vector2(-0.27, -0.23), Vector2(0.27, -0.23), Vector2(-0.25, 0.13), Vector2(0.25, 0.13), Vector2(0, 0.47)], 0.03, IRON,
						Vector3(0, 0.15, -0.02 * z), Vector3(-90, 0, 180), METAL)
				_box(g, Vector3(0.06, 0.4, 0.03), GOLD, Vector3(0, 0.05, 0.04 * z), Vector3.ZERO, METAL)
				_box(g, Vector3(0.3, 0.06, 0.03), GOLD, Vector3(0, 0.1, 0.04 * z), Vector3.ZERO, METAL)
		"sack":
			var g := _grp(ap, hand, Vector3(0, 0, 0), Vector3.ONE * s)
			_sph(g, 0.2, Color(0.72, 0.6, 0.4), Vector3(0, -0.22, 0), Vector3(1, 1.1, 1), CLAY, 8)
			_cyl(g, 0.05, 0.08, 0.1, ROPE, Vector3(0, -0.04, 0), Vector3.ZERO, CLAY, 6)
			_sph(g, 0.05, GOLD, Vector3(0.12, -0.12, 0.08), Vector3.ONE, METAL, 6)
		"potion":
			var g := _grp(ap, hand, Vector3(0, 0, 0), Vector3.ONE * s)
			_sph(g, 0.11, Color(ic, 1.0), Vector3(0.05, -0.04, 0), Vector3.ONE, GLOW, 8)
			_cyl(g, 0.03, 0.035, 0.1, Color(0.8, 0.9, 0.85), Vector3(0.05, 0.08, 0), Vector3.ZERO, CLAY, 6)
		"censer", "lantern":
			var g := _grp(ap, hand, Vector3.ZERO, Vector3.ONE * s)
			_seg(g, 0.01, 0.01, IRON, Vector3.ZERO, Vector3(0, -0.22, 0), METAL)
			_sph(g, 0.1, GOLD if item == "censer" else IRON, Vector3(0, -0.3, 0), Vector3(1, 1.1, 1), METAL, 8)
			_sph(g, 0.06, ic if item == "censer" else FIRE_HOT, Vector3(0.06, -0.3, 0), Vector3.ONE, GLOW, 6)
			_sph(g, 0.07, Color(0.6, 0.65, 0.6, 0.5), Vector3(0.0, -0.08, 0), Vector3.ONE, GHOST, 6)
		"orb":
			_sph(ap, 0.13, ic, hand + Vector3(0.1, 0.12, 0), Vector3.ONE, GLOW, 10)
			_sph(ap, 0.2, Color(ic, 0.3), hand + Vector3(0.1, 0.12, 0), Vector3.ONE, GHOST, 10)
		"flail":
			var g := _grp(ap, hand, Vector3(0, 0, -40), Vector3.ONE * s)
			_seg(g, 0.03, 0.03, GOLD, Vector3(0, -0.05, 0), Vector3(0, 0.35, 0), METAL)
			for k in 3:
				_seg(g, 0.02, 0.02, Color(0.15, 0.3, 0.75), Vector3(0, 0.35, 0), Vector3(0.12 * (k - 1), 0.2, 0.08), CLAY)
				_cyl(g, 0.04, 0.04, 0.08, GOLD, Vector3(0.12 * (k - 1), 0.18, 0.08), Vector3.ZERO, METAL, 6)


# ---------------------------------------------------------------- Cabezas (miran a +X)

static func _head(p: Node3D, o: Dictionary, H: Vector3, hr: float) -> void:
	var skin: Color = o.get("skin", SKIN)
	var eye: Color = o.get("eye", Color(0, 0, 0, 0))
	var hair: Color = o.get("hair", Color(0.3, 0.2, 0.12))
	var hat: String = o.get("hat", "")
	var covered := hat in ["great_helm", "horned_great_helm", "hood", "crown_hood", "fur_hood", "nemes", "turban", "helmet", "kettle", "horned_helm", "witch", "wizard", "mitre", "tricorn", "straw", "pointy", "exec_hood"]
	var kind: String = o.get("head", "human")
	var ex := hr * 0.86  # profundidad de los ojos
	match kind:
		"skull":
			_sph(p, hr, BONE, H, Vector3(1.0, 1.0, 0.92), CLAY, 12)
			_box(p, Vector3(hr * 0.9, hr * 0.4, hr * 1.1), BONE.darkened(0.05), H + Vector3(hr * 0.35, -hr * 0.72, 0))
			for z in [-1.0, 1.0]:
				_sph(p, hr * 0.27, DARK, H + Vector3(hr * 0.78, hr * 0.05, hr * 0.36 * z), Vector3(0.6, 1, 1), CLAY, 8)
				_sph(p, hr * 0.12, eye if eye.a > 0 else GREEN_GLOW, H + Vector3(hr * 0.9, hr * 0.05, hr * 0.36 * z), Vector3.ONE, GLOW, 6)
			_cone(p, hr * 0.12, hr * 0.2, DARK, H + Vector3(hr * 0.92, -hr * 0.25, 0), Vector3(0, 0, 180), CLAY, 3)
			for i in 5:
				_box(p, Vector3(hr * 0.08, hr * 0.14, hr * 0.12), WHITE, H + Vector3(hr * 0.8, -hr * 0.55, (i - 2) * hr * 0.17))
			return
		"mummy":
			_sph(p, hr, skin, H, Vector3(1.0, 1.05, 0.95), CLAY, 12)
			for i in 5:
				_sph(p, hr * 1.03, skin.darkened(0.1 + 0.06 * (i % 2)), H + Vector3(0, -hr * 0.6 + i * hr * 0.3, 0), Vector3(1, 0.18, 0.97), CLAY, 10)
			_sph(p, hr * 0.32, DARK, H + Vector3(hr * 0.72, hr * 0.08, hr * 0.32), Vector3(0.6, 0.5, 1), CLAY, 8)
			_sph(p, hr * 0.15, eye if eye.a > 0 else GREEN_GLOW, H + Vector3(hr * 0.88, hr * 0.08, hr * 0.32), Vector3.ONE, GLOW, 6)
			_box(p, Vector3(hr * 0.3, hr * 0.12, hr * 0.9), skin.darkened(0.2), H + Vector3(hr * 0.85, hr * 0.15, -hr * 0.1), Vector3(25, 0, 0))
			return
		"octopus":
			_sph(p, hr, skin, H + Vector3(-hr * 0.2, hr * 0.25, 0), Vector3(1.3, 1.25, 1.0), CLAY, 12)
			for z in [-1.0, 1.0]:
				_sph(p, hr * 0.22, eye, H + Vector3(hr * 0.75, hr * 0.2, hr * 0.42 * z), Vector3.ONE, GLOW, 8)
			for i in 5:
				var zz := (i - 2) * hr * 0.32
				var b := H + Vector3(hr * 0.7, -hr * 0.2, zz)
				_chain(p, [b, b + Vector3(hr * 0.25, -hr * 0.6, zz * 0.2), b + Vector3(hr * 0.1, -hr * 1.2, zz * 0.4), b + Vector3(hr * 0.35, -hr * 1.6, zz * 0.5)], hr * 0.16, hr * 0.04, skin.lightened(0.08))
			return
		"wendigo":
			_sph(p, hr, BONE, H, Vector3(1.0, 0.95, 0.85), CLAY, 10)
			_box(p, Vector3(hr * 1.4, hr * 0.55, hr * 0.7), BONE, H + Vector3(hr * 0.9, -hr * 0.3, 0), Vector3(0, 0, -12))
			for z in [-1.0, 1.0]:
				_sph(p, hr * 0.24, DARK, H + Vector3(hr * 0.6, hr * 0.15, hr * 0.42 * z), Vector3(0.7, 1, 1), CLAY, 8)
				_sph(p, hr * 0.12, eye, H + Vector3(hr * 0.72, hr * 0.15, hr * 0.42 * z), Vector3.ONE, GLOW, 6)
				_antler(p, H + Vector3(-hr * 0.1, hr * 0.7, hr * 0.4 * z), z, hr * 2.2, Color(0.35, 0.28, 0.22))
			for i in 4:
				_cone(p, hr * 0.06, hr * 0.2, WHITE, H + Vector3(hr * 1.45, -hr * 0.55, (i - 1.5) * hr * 0.14), Vector3(0, 0, 180), CLAY, 4)
			return
		"frog":
			_sph(p, hr * 1.1, skin, H + Vector3(0.05, -hr * 0.15, 0), Vector3(1.0, 0.7, 1.15), CLAY, 12)
			_sph(p, hr * 0.9, skin.lightened(0.3), H + Vector3(hr * 0.3, -hr * 0.55, 0), Vector3(0.9, 0.5, 1.05), CLAY, 10)
			_box(p, Vector3(hr * 0.1, hr * 0.06, hr * 1.7), DARK, H + Vector3(hr * 1.02, -hr * 0.3, 0), Vector3(0, 0, -10))
			for z in [-1.0, 1.0]:
				_sph(p, hr * 0.38, skin, H + Vector3(hr * 0.35, hr * 0.45, hr * 0.5 * z), Vector3.ONE, CLAY, 10)
				_sph(p, hr * 0.32, Color(0.95, 0.85, 0.3), H + Vector3(hr * 0.5, hr * 0.5, hr * 0.5 * z), Vector3(0.8, 1, 1), CLAY, 8)
				_sph(p, hr * 0.15, DARK, H + Vector3(hr * 0.75, hr * 0.5, hr * 0.5 * z), Vector3(0.5, 1, 0.5), CLAY, 6)
			return

	# --- Cabezas de carne y hueso
	var sx := 1.0
	var sy := 1.08
	if kind in ["ogre", "orc", "giant"]:
		sx = 1.05
		sy = 1.0
	if kind == "kobold" or kind == "lizard":
		_sph(p, hr, skin, H, Vector3(1.0, 0.95, 0.9), CLAY, 12)
		_box(p, Vector3(hr * 1.3, hr * 0.62, hr * 0.95), skin, H + Vector3(hr * 0.75, -hr * 0.3, 0), Vector3(0, 0, -6))
		_box(p, Vector3(hr * 1.05, hr * 0.22, hr * 0.8), skin.lightened(0.2), H + Vector3(hr * 0.75, -hr * 0.65, 0))
		for z in [-1.0, 1.0]:
			_sph(p, hr * 0.06, DARK, H + Vector3(hr * 1.38, -hr * 0.1, hr * 0.2 * z), Vector3.ONE, CLAY, 4)
			_sph(p, hr * 0.2, eye if eye.a > 0 else FIRE_HOT, H + Vector3(hr * 0.68, hr * 0.28, hr * 0.48 * z), Vector3(0.8, 0.8, 1), GLOW, 8)
			_box(p, Vector3(hr * 0.5, hr * 0.1, hr * 0.15), skin.darkened(0.2), H + Vector3(hr * 0.6, hr * 0.5, hr * 0.42 * z), Vector3(0, 0, -15))
		if kind == "kobold":
			for z in [-1.0, 1.0]:
				_plate(p, [Vector2(0, 0), Vector2(-0.6, 0.0), Vector2(-0.4, 0.45)], 0.04, skin.darkened(0.2), H + Vector3(-hr * 0.4, hr * 0.1, hr * 0.7 * z), Vector3(80 * z, 0, 0))
		for i in 4:
			_cone(p, hr * 0.12, hr * 0.35, skin.darkened(0.3), H + Vector3(-hr * 0.2 - i * hr * 0.3, hr * (0.8 - i * 0.25), 0), Vector3(0, 0, 30 + i * 15), CLAY, 4)
		for i in 3:
			_cone(p, hr * 0.05, hr * 0.14, WHITE, H + Vector3(hr * 1.2, -hr * 0.5, (i - 1) * hr * 0.25), Vector3(0, 0, 180), CLAY, 3)
	else:
		_sph(p, hr, skin, H, Vector3(sx, sy, 1.0), CLAY, 14)
		# mandíbulas
		match kind:
			"orc", "ogre", "troll", "giant":
				_sph(p, hr * 0.75, skin, H + Vector3(hr * 0.35, -hr * 0.45, 0), Vector3(1.0, 0.7, 1.2), CLAY, 10)
			"goblin", "demon", "vampire":
				_sph(p, hr * 0.6, skin, H + Vector3(hr * 0.4, -hr * 0.42, 0), Vector3(0.9, 0.7, 1.0), CLAY, 10)
			_:
				_sph(p, hr * 0.7, skin, H + Vector3(hr * 0.25, -hr * 0.3, 0), Vector3(0.95, 0.8, 1.0), CLAY, 10)
	# --- Ojos
	if o.get("shadow_face", false):
		_sph(p, hr * 0.82, DARK, H + Vector3(hr * 0.22, -hr * 0.05, 0), Vector3(1, 1.0, 0.95), CLAY, 12)
		for z in [-1.0, 1.0]:
			_sph(p, hr * 0.13, eye if eye.a > 0 else Color(0.9, 0.9, 0.7), H + Vector3(hr * 1.0, hr * 0.05, hr * 0.3 * z), Vector3(0.6, 0.8, 1), GLOW, 6)
	elif kind not in ["kobold", "lizard"]:
		var ey := hr * 0.12
		var ez := hr * 0.36
		var es := hr * 0.2
		if kind in ["orc", "ogre", "troll", "giant"]:
			ey = hr * 0.22
			es = hr * 0.15
		elif kind == "goblin":
			es = hr * 0.26
			ez = hr * 0.4
		for z in [-1.0, 1.0]:
			if kind == "zombie" and z > 0:
				_sph(p, es * 0.9, DARK, H + Vector3(ex, ey, ez * z), Vector3(0.6, 1, 1), CLAY, 6)
				_box(p, Vector3(0.02, es * 2.5, 0.02), DARK, H + Vector3(ex + 0.02, ey - es * 2.0, ez * z), Vector3(0, 0, 0))
				continue
			if eye.a > 0:
				_sph(p, es * 0.75, DARK, H + Vector3(ex - 0.02, ey, ez * z), Vector3(0.6, 1, 1.1), CLAY, 6)
				_eye(p, H + Vector3(ex + 0.01, ey, ez * z), es * 0.7, eye)
			elif kind == "yeti":
				_sph(p, es * 0.6, DARK, H + Vector3(ex + 0.02, ey, ez * z), Vector3(0.6, 1, 1), CLAY, 6)
			else:
				_eye(p, H + Vector3(ex, ey, ez * z), es)
			if kind != "yeti":
				# cejas
				var brow := hair.darkened(0.2) if kind in ["human", "giant", "elf", "queen", "witch", "djinn", "vampire"] else skin.darkened(0.3)
				var ang: float = -15.0 * z if kind in ["orc", "ogre", "troll", "demon", "goblin", "vampire", "witch", "giant"] else -5.0 * z
				_box(p, Vector3(hr * 0.12, hr * 0.08, hr * 0.38), brow, H + Vector3(ex, ey + es * 1.25, ez * z), Vector3(ang * 2.0, 0, 0))
	# --- Rasgos por especie
	match kind:
		"human", "giant", "vampire", "djinn", "queen", "elf", "witch", "dryad":
			if kind == "witch":
				_seg(p, hr * 0.14, hr * 0.03, skin.darkened(0.08), H + Vector3(hr * 0.88, -hr * 0.05, 0), H + Vector3(hr * 1.5, -hr * 0.4, 0))
				_sph(p, hr * 0.06, skin.darkened(0.3), H + Vector3(hr * 1.1, -hr * 0.2, hr * 0.08), Vector3.ONE, CLAY, 4)
				_sph(p, hr * 0.2, skin, H + Vector3(hr * 0.6, -hr * 0.8, 0), Vector3(1, 1.2, 1), CLAY, 6)
			elif not o.get("shadow_face", false):
				_sph(p, hr * 0.14, skin.darkened(0.1), H + Vector3(hr * 0.98, -hr * 0.12, 0), Vector3(1.0, 1.1, 0.9), CLAY, 6)
			if not o.get("mask", false) and not o.get("shadow_face", false):
				_box(p, Vector3(hr * 0.06, hr * 0.06, hr * 0.32), Color(0.55, 0.25, 0.22), H + Vector3(hr * 0.86, -hr * 0.45, 0))
			if kind in ["elf", "queen", "vampire", "djinn", "dryad"] and kind != "queen":
				for z in [-1.0, 1.0]:
					_seg(p, hr * 0.12, hr * 0.02, skin, H + Vector3(-hr * 0.05, 0, hr * 0.9 * z), H + Vector3(-hr * 0.45, hr * 0.55, hr * 1.4 * z))
			elif not covered:
				for z in [-1.0, 1.0]:
					_sph(p, hr * 0.17, skin.darkened(0.08), H + Vector3(0, -hr * 0.05, hr * 0.95 * z), Vector3(0.6, 1.0, 0.6), CLAY, 6)
			if kind == "vampire":
				for z in [-1.0, 1.0]:
					_cone(p, hr * 0.05, hr * 0.15, WHITE, H + Vector3(hr * 0.9, -hr * 0.55, hr * 0.1 * z), Vector3(0, 0, 180), CLAY, 4)
		"goblin":
			_seg(p, hr * 0.16, hr * 0.04, skin.darkened(0.05), H + Vector3(hr * 0.85, -hr * 0.05, 0), H + Vector3(hr * 1.35, -hr * 0.25, 0))
			for z in [-1.0, 1.0]:
				_seg(p, hr * 0.22, hr * 0.03, skin, H + Vector3(0, hr * 0.05, hr * 0.85 * z), H + Vector3(-hr * 0.25, hr * 0.4, hr * 1.75 * z))
				_sph(p, hr * 0.12, Color(0.85, 0.5, 0.45), H + Vector3(-hr * 0.05, hr * 0.12, hr * 1.1 * z), Vector3(0.4, 0.8, 1.5), CLAY, 6)
			_box(p, Vector3(hr * 0.08, hr * 0.08, hr * 0.6), DARK, H + Vector3(hr * 0.88, -hr * 0.5, 0), Vector3(0, 0, -10))
			for z in [-1.0, 1.0]:
				_cone(p, hr * 0.06, hr * 0.15, WHITE, H + Vector3(hr * 0.9, -hr * 0.42, hr * 0.18 * z), Vector3(0, 0, 180), CLAY, 4)
		"orc", "ogre", "troll":
			if kind == "troll":
				_seg(p, hr * 0.22, hr * 0.06, skin.darkened(0.05), H + Vector3(hr * 0.85, 0, 0), H + Vector3(hr * 1.7, -hr * 0.5, 0))
			else:
				_sph(p, hr * 0.2, skin.darkened(0.1), H + Vector3(hr * 1.0, -hr * 0.02, 0), Vector3(1, 0.8, 1.2), CLAY, 6)
			_box(p, Vector3(hr * 0.1, hr * 0.1, hr * 0.9), DARK, H + Vector3(hr * 1.02, -hr * 0.55, 0))
			for z in [-1.0, 1.0]:
				var tl := hr * (0.45 if kind != "ogre" else 0.28)
				_cone(p, hr * 0.12, tl, WHITE if kind != "troll" else Color(0.95, 0.9, 0.7), H + Vector3(hr * 1.0, -hr * 0.45, hr * 0.38 * z), Vector3(-10 * z, 0, 0), CLAY, 5)
				if kind == "troll":
					_seg(p, hr * 0.2, hr * 0.02, skin, H + Vector3(0, 0, hr * 0.9 * z), H + Vector3(-hr * 0.5, hr * 0.15, hr * 1.7 * z))
				elif not covered:
					_sph(p, hr * 0.24, skin.darkened(0.08), H + Vector3(0, 0, hr * 1.0 * z), Vector3(0.5, 1.0, 0.7), CLAY, 6)
			if kind == "orc" and not covered:
				_cyl(p, hr * 0.15, hr * 0.25, hr * 0.5, o.get("hair", DARK), H + Vector3(-hr * 0.2, hr * 1.1, 0), Vector3(0, 0, 20), CLAY, 6)
			if kind == "troll":
				for i in 5:
					_cone(p, hr * 0.15, hr * 0.5, o.get("hair", skin.darkened(0.4)), H + Vector3(-hr * 0.3 + i * 0.03, hr * 0.8, (i - 2) * hr * 0.25), Vector3((i - 2) * 15.0, 0, 30), CLAY, 4)
		"zombie":
			_box(p, Vector3(hr * 0.2, hr * 0.25, hr * 0.5), DARK, H + Vector3(hr * 0.85, -hr * 0.45, 0))
			_sph(p, hr * 0.13, skin.darkened(0.15), H + Vector3(hr * 0.98, -hr * 0.1, 0), Vector3.ONE, CLAY, 6)
			for i in 3:
				_box(p, Vector3(0.015, hr * 0.5, 0.015), DARK, H + Vector3(hr * 0.2, hr * 0.7, -hr * 0.3 + i * hr * 0.15), Vector3(0, 0, 70))
			for i in 4:
				_cone(p, hr * 0.06, hr * 0.3, o.get("hair", DARK), H + Vector3(-hr * 0.2, hr * 0.9, (i - 1.5) * hr * 0.3), Vector3((i - 1.5) * 20.0, 0, 20), CLAY, 4)
		"demon":
			_sph(p, hr * 0.15, skin.darkened(0.1), H + Vector3(hr * 0.98, -hr * 0.1, 0), Vector3.ONE, CLAY, 6)
			_cone(p, hr * 0.15, hr * 0.45, Color(0.12, 0.08, 0.08), H + Vector3(hr * 0.75, -hr * 0.95, 0), Vector3(0, 0, 160), CLAY, 5)
			_box(p, Vector3(hr * 0.08, hr * 0.07, hr * 0.5), DARK, H + Vector3(hr * 0.9, -hr * 0.45, 0))
			for z in [-1.0, 1.0]:
				_cone(p, hr * 0.05, hr * 0.14, WHITE, H + Vector3(hr * 0.92, -hr * 0.5, hr * 0.15 * z), Vector3(0, 0, 180), CLAY, 4)
				_seg(p, hr * 0.14, hr * 0.02, skin, H + Vector3(0, 0, hr * 0.9 * z), H + Vector3(-hr * 0.35, hr * 0.3, hr * 1.4 * z))
		"yeti":
			_sph(p, hr * 0.7, skin.darkened(0.45).lerp(Color(0.5, 0.6, 0.75), 0.5), H + Vector3(hr * 0.45, -hr * 0.05, 0), Vector3(0.6, 0.9, 1.0), CLAY, 10)
			_box(p, Vector3(hr * 0.15, hr * 0.18, hr * 0.7), DARK, H + Vector3(hr * 0.9, -hr * 0.4, 0))
			for z in [-1.0, 1.0]:
				_cone(p, hr * 0.07, hr * 0.2, WHITE, H + Vector3(hr * 0.96, -hr * 0.36, hr * 0.22 * z), Vector3(0, 0, 0), CLAY, 4)
				_horn(p, H + Vector3(-hr * 0.1, hr * 0.6, hr * 0.6 * z), Vector3(0, 0.6, 1.0 * z), Vector3(0, -1, 0), hr * 0.9, hr * 0.15, Color(0.4, 0.35, 0.3))
			for i in 6:
				var a := TAU * i / 6.0
				_sph(p, hr * 0.35, skin, H + Vector3(-hr * 0.3 + cos(a) * hr * 0.2, hr * 0.5 + sin(a) * hr * 0.1, sin(a) * hr * 0.7), Vector3.ONE, CLAY, 8)
	if kind == "giant" or o.has("beard"):
		var bc: Color = o.get("beard", hair)
		if bc.a > 0.0:
			_sph(p, hr * 0.65, bc, H + Vector3(hr * 0.55, -hr * 0.65, 0), Vector3(0.7, 0.9, 1.2), CLAY, 10)
			_cone(p, hr * 0.5, hr * 1.1, bc, H + Vector3(hr * 0.65, -hr * 1.25, 0), Vector3(0, 0, 175), CLAY, 8)
			_box(p, Vector3(hr * 0.12, hr * 0.12, hr * 0.7), bc.darkened(0.1), H + Vector3(hr * 0.98, -hr * 0.25, 0))  # bigote
	# --- Cuernos
	var hc: Color = o.get("horns", Color(0, 0, 0, 0))
	if hc.a > 0.0 and not hat in ["horned_helm", "horned_great_helm"]:
		for z in [-1.0, 1.0]:
			if kind == "demon":
				_horn(p, H + Vector3(hr * 0.2, hr * 0.7, hr * 0.5 * z), Vector3(-0.3, 1.0, 0.5 * z), Vector3(-0.6, -0.3, 0), hr * (1.4 if o.get("boss", false) or o.get("frame", "") == "brute" else 0.9), hr * 0.2, hc)
			else:
				_horn(p, H + Vector3(-hr * 0.3, hr * 0.5, hr * 0.45 * z), Vector3(-1.0, 0.4, 0.2 * z), Vector3(0, -0.4, 0), hr * 0.9, hr * 0.15, hc)
	if o.get("antlers", false):
		for z in [-1.0, 1.0]:
			_antler(p, H + Vector3(-hr * 0.1, hr * 0.85, hr * 0.45 * z), z, hr * 1.6, Color(0.4, 0.3, 0.2))
	# --- Pelo
	if not covered and kind in ["human", "giant", "vampire", "elf", "queen", "witch", "dryad", "djinn"]:
		if kind == "dryad":
			for i in 9:
				var a := TAU * i / 9.0
				_sph(p, hr * 0.38, hair.lightened(0.08 * (i % 3)), H + Vector3(-hr * 0.25 + cos(a) * hr * 0.55, hr * 0.55 + sin(a) * hr * 0.35, sin(a) * hr * 0.8), Vector3(1, 0.8, 1), CLAY, 6)
		elif kind == "djinn":
			_cyl(p, hr * 0.12, hr * 0.2, hr * 0.5, hair, H + Vector3(-hr * 0.1, hr * 1.1, 0), Vector3.ZERO, CLAY, 6)
			_sph(p, hr * 0.15, GOLD, H + Vector3(-hr * 0.1, hr * 0.92, 0), Vector3(1, 0.5, 1), METAL, 6)
		else:
			_sph(p, hr * 1.06, hair, H + Vector3(-hr * 0.14, hr * 0.12, 0), Vector3(1.0, 1.0, 1.04), CLAY, 12)
			if kind == "vampire":
				_cone(p, hr * 0.25, hr * 0.4, hair, H + Vector3(hr * 0.72, hr * 0.62, 0), Vector3(0, 0, 120), CLAY, 4)
			else:
				_box(p, Vector3(hr * 0.3, hr * 0.25, hr * 1.4), hair, H + Vector3(hr * 0.6, hr * 0.68, 0), Vector3(0, 0, -30))
			if o.get("long_hair", false) or kind in ["witch", "queen"]:
				_box(p, Vector3(hr * 0.4, hr * 2.2, hr * 1.6), hair, H + Vector3(-hr * 0.6, -hr * 0.8, 0), Vector3(0, 0, -8))
	# --- Máscara, parche
	if o.get("mask", false):
		var mc: Color = o.get("mask_col", Color(0.6, 0.15, 0.12))
		_sph(p, hr * 1.03, mc, H + Vector3(hr * 0.05, -hr * 0.38, 0), Vector3(1.0, 0.5, 1.0), CLAY, 12)
		_cone(p, hr * 0.2, hr * 0.5, mc, H + Vector3(-hr * 0.95, -hr * 0.5, 0.0), Vector3(0, 0, 120), CLAY, 4)
	if o.get("eyepatch", false):
		_cyl(p, hr * 0.17, hr * 0.17, 0.03, DARK, H + Vector3(ex + 0.02, hr * 0.12, hr * 0.36), Vector3(0, 0, 90), CLAY, 8)
		_box(p, Vector3(hr * 0.04, hr * 0.04, hr * 2.05), DARK, H + Vector3(0, hr * 0.3, 0), Vector3(0, 0, 30))
	if o.get("blindfold", false):
		_sph(p, hr * 1.04, o.get("cloth2", WHITE), H + Vector3(0, hr * 0.12, 0), Vector3(1, 0.22, 1), CLAY, 12)


static func _antler(p: Node3D, base: Vector3, z: float, L: float, col: Color) -> void:
	var a := base
	var b := base + Vector3(-L * 0.15, L * 0.5, L * 0.35 * z)
	var c := b + Vector3(-L * 0.2, L * 0.45, L * 0.15 * z)
	_chain(p, [a, b, c], L * 0.07, L * 0.03, col)
	_seg(p, L * 0.05, L * 0.02, col, b, b + Vector3(L * 0.25, L * 0.3, L * 0.05 * z))
	_seg(p, L * 0.04, L * 0.015, col, a.lerp(b, 0.5), a.lerp(b, 0.5) + Vector3(L * 0.2, L * 0.15, L * 0.15 * z))
	_seg(p, L * 0.04, L * 0.015, col, c, c + Vector3(L * 0.1, L * 0.2, -L * 0.1 * z))


# ---------------------------------------------------------------- Sombreros y cascos (devuelven la altura de la parte de arriba)

static func _hat(p: Node3D, o: Dictionary, H: Vector3, hr: float) -> float:
	var hat: String = o.get("hat", "")
	var hc: Color = o.get("hat_col", Color(o["col"]).darkened(0.25))
	var topy := H.y + hr * 1.05
	match hat:
		"hood", "crown_hood", "fur_hood", "exec_hood":
			var fur := hat == "fur_hood"
			_sph(p, hr * 1.2, hc, H + Vector3(-hr * 0.28, hr * 0.08, 0), Vector3(1.0, 1.05, 1.02), CLAY, 12)
			if hat != "exec_hood":
				_cone(p, hr * 0.5, hr * 0.9, hc, H + Vector3(-hr * 1.1, hr * 0.15, 0), Vector3(0, 0, 100), CLAY, 8)
			# borde de la capucha
			for i in 7:
				var a := -PI * 0.5 + PI * i / 6.0
				_sph(p, hr * (0.22 if fur else 0.16), hc.lightened(0.12) if not fur else WHITE, H + Vector3(hr * 0.55, sin(a) * hr * 0.95 + hr * 0.05, cos(a) * hr * 0.95), Vector3(0.8, 1, 1), CLAY, 6)
			_sph(p, hr * 1.5, hc, H + Vector3(-hr * 0.2, -hr * 1.05, 0), Vector3(1.0, 0.45, 1.05), CLAY, 12)  # esclavina
			if hat == "exec_hood":
				_sph(p, hr * 1.08, hc, H + Vector3(0.0, hr * 0.0, 0), Vector3(1.0, 1.08, 1.0), CLAY, 12)
				for z in [-1.0, 1.0]:
					_sph(p, hr * 0.12, DARK, H + Vector3(hr * 1.0, hr * 0.15, hr * 0.32 * z), Vector3(0.5, 1, 1.4), CLAY, 6)
					_sph(p, hr * 0.06, o.get("eye", RED_GLOW), H + Vector3(hr * 1.06, hr * 0.15, hr * 0.32 * z), Vector3.ONE, GLOW, 6)
			topy = H.y + hr * 1.3
			if hat == "crown_hood":
				_crown(p, H + Vector3(-hr * 0.1, hr * 1.25, 0), hr * 1.9)
				topy = H.y + hr * 1.9
		"helmet", "kettle":
			_sph(p, hr * 1.1, hc, H + Vector3(0, hr * 0.18, 0), Vector3(1, 0.8, 1), METAL, 12)
			if hat == "kettle":
				_cyl(p, hr * 1.55, hr * 1.55, 0.04, hc.darkened(0.1), H + Vector3(0, hr * 0.25, 0), Vector3.ZERO, METAL, 14)
			else:
				_box(p, Vector3(0.05, hr * 0.7, 0.08), hc, H + Vector3(hr * 1.02, -hr * 0.05, 0), Vector3.ZERO, METAL)
				_cyl(p, hr * 1.12, hr * 1.12, 0.06, hc.darkened(0.15), H + Vector3(0, hr * 0.2, 0), Vector3.ZERO, METAL, 14)
			topy = H.y + hr * 1.1
		"great_helm", "horned_great_helm":
			_cyl(p, hr * 1.05, hr * 1.08, hr * 2.0, hc, H + Vector3(0, -hr * 0.05, 0), Vector3.ZERO, METAL, 12)
			_sph(p, hr * 1.05, hc, H + Vector3(0, hr * 0.92, 0), Vector3(1, 0.4, 1), METAL, 12)
			_box(p, Vector3(0.06, hr * 0.14, hr * 1.4), DARK, H + Vector3(hr * 1.04, hr * 0.15, 0))
			_box(p, Vector3(0.07, hr * 1.4, hr * 0.12), hc.lightened(0.2), H + Vector3(hr * 1.06, -hr * 0.1, 0), Vector3.ZERO, METAL)
			var eye: Color = o.get("eye", Color(0, 0, 0, 0))
			if eye.a > 0:
				for z in [-1.0, 1.0]:
					_sph(p, hr * 0.1, eye, H + Vector3(hr * 1.08, hr * 0.15, hr * 0.32 * z), Vector3(0.4, 0.8, 1.6), GLOW, 6)
			for i in 3:
				_sph(p, hr * 0.05, DARK, H + Vector3(hr * 1.06, -hr * 0.35 - i * hr * 0.18, hr * 0.35), Vector3.ONE, CLAY, 4)
			topy = H.y + hr * 1.3
			if o.has("plume"):
				var pc: Color = o["plume"]
				for i in 5:
					_sph(p, hr * 0.28, pc.lightened(0.05 * i), H + Vector3(-hr * 0.2 - i * hr * 0.28, hr * (1.35 - i * 0.12), 0), Vector3(1, 0.9, 0.7), CLAY, 8)
			if hat == "horned_great_helm":
				for z in [-1.0, 1.0]:
					_horn(p, H + Vector3(0, hr * 0.6, hr * 0.9 * z), Vector3(0.1, 0.4, 1.0 * z), Vector3(0, 1.0, -0.3 * z), hr * 1.6, hr * 0.22, BONE if o.get("eye", RED_GLOW) != Color(1.0, 0.3, 0.6) else Color(0.25, 0.05, 0.15))
		"horned_helm":
			_sph(p, hr * 1.08, hc, H + Vector3(0, hr * 0.2, 0), Vector3(1, 0.78, 1), METAL, 12)
			_cyl(p, hr * 1.1, hr * 1.1, 0.07, GOLD if o.get("boss", false) else hc.darkened(0.2), H + Vector3(0, hr * 0.22, 0), Vector3.ZERO, METAL, 14)
			_box(p, Vector3(0.05, hr * 0.7, 0.08), hc, H + Vector3(hr * 1.02, -hr * 0.02, 0), Vector3.ZERO, METAL)
			for z in [-1.0, 1.0]:
				_horn(p, H + Vector3(0, hr * 0.5, hr * 0.85 * z), Vector3(0.2, 0.3, 1.0 * z), Vector3(0, 1.0, 0), hr * 1.1, hr * 0.18, BONE)
			topy = H.y + hr * 1.05
		"crown":
			_crown(p, H + Vector3(0, hr * 0.95, 0), hr * 2.0)
			topy = H.y + hr * 1.5
		"circlet":
			_cyl(p, hr * 1.03, hr * 1.03, 0.06, GOLD, H + Vector3(0, hr * 0.42, 0), Vector3(0, 0, -8), METAL, 14)
			_sph(p, hr * 0.13, o.get("item_col", PURPLE_GLOW), H + Vector3(hr * 1.02, hr * 0.5, 0), Vector3(0.6, 1, 1), GLOW, 6)
		"lich_crown":
			_cyl(p, hr * 0.95, hr * 0.85, hr * 0.35, Color(0.3, 0.32, 0.3), H + Vector3(0, hr * 0.85, 0), Vector3.ZERO, METAL, 8)
			for i in 8:
				var a := TAU * i / 8.0
				var tall := 0.9 if i % 2 == 0 else 0.55
				_cone(p, hr * 0.12, hr * tall, Color(0.3, 0.32, 0.3), H + Vector3(cos(a) * hr * 0.9, hr * (1.0 + tall * 0.5), sin(a) * hr * 0.9), Vector3.ZERO, METAL, 4)
			_sph(p, hr * 0.16, o.get("item_col", GREEN_GLOW), H + Vector3(hr * 0.95, hr * 0.88, 0), Vector3(0.6, 1, 1), GLOW, 8)
			topy = H.y + hr * 1.7
		"ice_crown":
			_cyl(p, hr * 0.95, hr * 0.95, hr * 0.15, Color(0.85, 0.95, 1.0), H + Vector3(0, hr * 0.75, 0), Vector3.ZERO, METAL, 10)
			for i in 7:
				var a := TAU * i / 7.0
				var tall := 1.2 if i == 0 else 0.6 + 0.3 * (i % 2)
				_cone(p, hr * 0.13, hr * tall, ICE_GLOW, H + Vector3(cos(a) * hr * 0.9, hr * (0.8 + tall * 0.5), sin(a) * hr * 0.9), Vector3(rad_to_deg(sin(a)) * 0.2, 0, -rad_to_deg(cos(a)) * 0.2), GLOW, 5)
			topy = H.y + hr * 2.0
		"witch", "wizard":
			var w := hat == "witch"
			_cyl(p, hr * (1.75 if w else 1.6), hr * (1.75 if w else 1.6), 0.05, hc, H + Vector3(0, hr * 0.6, 0), Vector3(0, 0, -6), CLAY, 16)
			_cyl(p, hr * 0.72, hr * 0.95, hr * 0.8, hc, H + Vector3(0, hr * 1.0, 0), Vector3.ZERO, CLAY, 12)
			_cyl(p, hr * 0.9, hr * 0.97, hr * 0.18, GOLD if not w else Color(0.6, 0.3, 0.6), H + Vector3(0, hr * 0.75, 0), Vector3.ZERO, METAL if not w else CLAY, 12)
			if w:
				_cone(p, hr * 0.72, hr * 1.1, hc, H + Vector3(-hr * 0.2, hr * 1.9, 0), Vector3(0, 0, 25), CLAY, 10)
				_cone(p, hr * 0.25, hr * 0.6, hc, H + Vector3(-hr * 0.7, hr * 2.4, 0), Vector3(0, 0, 80), CLAY, 6)
				_box(p, Vector3(0.04, hr * 0.25, hr * 0.25), GOLD, H + Vector3(hr * 0.92, hr * 0.75, 0), Vector3.ZERO, METAL)
			else:
				_cone(p, hr * 0.72, hr * 1.5, hc, H + Vector3(-hr * 0.15, hr * 2.1, 0), Vector3(0, 0, 12), CLAY, 10)
				for i in 3:
					_sph(p, hr * 0.09, GOLD, H + Vector3(hr * (0.6 - i * 0.18), hr * (1.15 + i * 0.4), hr * (0.25 - i * 0.2)), Vector3.ONE, GLOW, 4)
			topy = H.y + hr * 2.6
		"turban":
			for i in 3:
				_sph(p, hr * (1.12 - i * 0.12), hc.darkened(0.05 * i), H + Vector3(-hr * 0.05, hr * (0.45 + i * 0.25), 0), Vector3(1, 0.45, 1), CLAY, 12)
			_sph(p, hr * 0.16, Color(0.2, 0.8, 0.5) if not o.get("boss", false) else RED_GLOW, H + Vector3(hr * 1.0, hr * 0.55, 0), Vector3(0.6, 1, 1), GLOW, 6)
			_box(p, Vector3(0.04, hr * 0.5, hr * 0.12), GOLD, H + Vector3(hr * 1.02, hr * 0.85, 0), Vector3(0, 0, -15), METAL)
			topy = H.y + hr * 1.2
		"nemes":
			_sph(p, hr * 1.12, hc, H + Vector3(-hr * 0.08, hr * 0.12, 0), Vector3(1, 1.0, 1.05), METAL, 12)
			for i in 4:
				_sph(p, hr * 1.14, Color(0.15, 0.3, 0.75), H + Vector3(-hr * 0.08, hr * (-0.3 + i * 0.3), 0), Vector3(1, 0.12, 1.06), CLAY, 12)
			for z in [-1.0, 1.0]:
				_box(p, Vector3(hr * 0.35, hr * 1.5, hr * 0.5), hc, H + Vector3(hr * 0.1, -hr * 0.85, hr * 1.0 * z), Vector3(0, 0, 0), METAL)
				for i in 3:
					_box(p, Vector3(hr * 0.37, hr * 0.1, hr * 0.52), Color(0.15, 0.3, 0.75), H + Vector3(hr * 0.1, -hr * (0.4 + i * 0.4), hr * 1.0 * z))
			_box(p, Vector3(hr * 0.3, hr * 0.8, hr * 0.5), hc, H + Vector3(-hr * 0.9, -hr * 0.6, 0), Vector3.ZERO, METAL)
			# cobra (ureo)
			_chain(p, [H + Vector3(hr * 1.0, hr * 0.5, 0), H + Vector3(hr * 1.15, hr * 0.7, 0), H + Vector3(hr * 1.1, hr * 0.95, 0)], hr * 0.1, hr * 0.08, GOLD, METAL)
			_sph(p, hr * 0.06, RED_GLOW, H + Vector3(hr * 1.18, hr * 0.95, 0), Vector3.ONE, GLOW, 4)
			topy = H.y + hr * 1.2
		"tricorn":
			_sph(p, hr * 1.02, hc, H + Vector3(0, hr * 0.42, 0), Vector3(1, 0.65, 1), CLAY, 12)
			for i in 3:
				var a := TAU * i / 3.0
				_box(p, Vector3(hr * 0.25, hr * 0.45, hr * 1.6), hc, H + Vector3(cos(a) * hr * 0.85, hr * 0.62, sin(a) * hr * 0.85), Vector3(0, -rad_to_deg(a), -12), CLAY)
			_sph(p, hr * 0.12, GOLD, H + Vector3(hr * 0.95, hr * 0.85, 0), Vector3.ONE, METAL, 6)
			topy = H.y + hr * 1.1
		"straw":
			_cyl(p, hr * 1.7, hr * 1.75, 0.05, hc, H + Vector3(0, hr * 0.65, 0), Vector3(0, 0, -8), CLAY, 14)
			_cyl(p, hr * 0.7, hr * 0.85, hr * 0.5, hc, H + Vector3(0, hr * 0.9, 0), Vector3(0, 0, -8), CLAY, 10)
			_cyl(p, hr * 0.86, hr * 0.87, hr * 0.12, Color(0.75, 0.2, 0.15), H + Vector3(0, hr * 0.75, 0), Vector3(0, 0, -8), CLAY, 10)
			topy = H.y + hr * 1.2
		"pointy":
			_cyl(p, hr * 0.92, hr * 1.02, hr * 0.3, hc, H + Vector3(0, hr * 0.55, 0), Vector3.ZERO, CLAY, 12)
			_cone(p, hr * 0.85, hr * 1.4, hc, H + Vector3(-hr * 0.35, hr * 1.25, 0), Vector3(0, 0, 35), CLAY, 10)
			_sph(p, hr * 0.15, WHITE, H + Vector3(-hr * 1.1, hr * 1.7, 0), Vector3.ONE, CLAY, 6)
			topy = H.y + hr * 1.6
		"mitre":
			_plate(p, [Vector2(-0.5, -0.55), Vector2(0.5, -0.55), Vector2(-0.35, 0.4), Vector2(0.35, 0.4), Vector2(0, 0.8)], hr * 0.9, hc,
					H + Vector3(0, hr * 1.05, 0), Vector3(-90, 0, 0), CLAY)
			_box(p, Vector3(hr * 0.95, hr * 0.12, 0.05), GOLD, H + Vector3(hr * 0.45, hr * 0.85, 0), Vector3(0, 90, 0), METAL)
			_box(p, Vector3(0.05, hr * 1.0, hr * 0.12), GOLD, H + Vector3(hr * 0.47, hr * 1.3, 0), Vector3.ZERO, METAL)
			topy = H.y + hr * 2.0
		"halo":
			_m(p, _torus_mesh(hr * 0.7, hr * 0.85), Color(1.0, 0.95, 0.6), H + Vector3(-hr * 0.1, hr * 1.35, 0), Vector3(0, 0, -10), Vector3.ONE, GLOW)
			topy = H.y + hr * 1.4
	return topy


static func _torus_mesh(inner: float, outer: float) -> Mesh:
	var key := "t%.3f|%.3f" % [inner, outer]
	if not _meshes.has(key):
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 16
		t.ring_segments = 6
		_meshes[key] = t
	return _meshes[key]


# ================================================================ Cuadrúpedos

static func _quad_dims(v: String) -> Dictionary:
	match v:
		"boar":
			return {"bl": 0.72, "by": 0.72, "ry": 0.5, "rz": 0.44, "hip": 0.55, "lr": 0.11, "hr": 0.38, "neck": Vector3(0.2, 0.0, 0)}
		"lizard", "cave":
			return {"bl": 0.7, "by": 0.38, "ry": 0.24, "rz": 0.32, "hip": 0.36, "lr": 0.09, "hr": 0.26, "neck": Vector3(0.15, 0.05, 0), "sprawl": true}
		"croc":
			return {"bl": 0.95, "by": 0.36, "ry": 0.26, "rz": 0.36, "hip": 0.34, "lr": 0.1, "hr": 0.26, "neck": Vector3(0.12, 0.0, 0), "sprawl": true}
		"horse":
			return {"bl": 0.75, "by": 1.25, "ry": 0.38, "rz": 0.3, "hip": 1.2, "lr": 0.09, "hr": 0.24, "neck": Vector3(0.3, 0.55, 0)}
		"siege", "behemoth", "mammoth", "chaos":
			return {"bl": 0.85, "by": 1.1, "ry": 0.66, "rz": 0.58, "hip": 0.85, "lr": 0.21, "hr": 0.45, "neck": Vector3(0.25, 0.05, 0)}
		"rat":
			return {"bl": 0.55, "by": 0.42, "ry": 0.32, "rz": 0.28, "hip": 0.36, "lr": 0.06, "hr": 0.25, "neck": Vector3(0.15, 0.05, 0)}
		"mole":
			return {"bl": 0.55, "by": 0.38, "ry": 0.36, "rz": 0.34, "hip": 0.3, "lr": 0.08, "hr": 0.26, "neck": Vector3(0.12, 0.0, 0)}
		"bear":
			return {"bl": 0.75, "by": 0.9, "ry": 0.52, "rz": 0.46, "hip": 0.72, "lr": 0.17, "hr": 0.36, "neck": Vector3(0.2, 0.08, 0)}
		"hare":
			return {"bl": 0.42, "by": 0.5, "ry": 0.33, "rz": 0.28, "hip": 0.42, "lr": 0.07, "hr": 0.25, "neck": Vector3(0.12, 0.2, 0)}
		"walrus":
			return {"bl": 0.75, "by": 0.5, "ry": 0.5, "rz": 0.5, "hip": 0.3, "lr": 0.13, "hr": 0.4, "neck": Vector3(0.15, 0.15, 0), "sprawl": true}
	return {"bl": 0.7, "by": 0.85, "ry": 0.36, "rz": 0.31, "hip": 0.82, "lr": 0.1, "hr": 0.3, "neck": Vector3(0.25, 0.25, 0)}


static func _quadruped(rig: Node3D, o: Dictionary) -> void:
	var v: String = o.get("var", "wolf")
	var d := _quad_dims(v)
	var c: Color = o["col"]
	var belly := c.lightened(0.25)
	var dark := c.darkened(0.35)
	var bl: float = d["bl"]
	var by: float = d["by"]
	var ry: float = d["ry"]
	var rz: float = d["rz"]
	var hip: float = d["hip"]
	var lr: float = d["lr"]
	var hr: float = d["hr"]
	var eye: Color = o.get("eye", Color(0, 0, 0, 0))
	if v == "hellhound" or v == "chaos":
		eye = FIRE_HOT
	elif v == "prowler" or o.get("ice", false):
		eye = ICE_GLOW
	elif v in ["wolf", "cave", "rat"] and (o.get("undead", false) or o.get("grand", false) or v == "cave"):
		eye = Color(0.7, 1.0, 0.5) if o.get("undead", false) else FIRE_HOT
	elif v == "prism":
		eye = Color(0.9, 0.6, 1.0)
	if v == "prism" or v == "ripper":
		d = _quad_dims("wolf")
	# --- Tronco
	match v:
		"horse":
			_sph(rig, 1.0, c, Vector3(0, by, 0), Vector3(bl, ry, rz), CLAY, 14)
		"walrus":
			_sph(rig, 1.0, c, Vector3(-0.1, by, 0), Vector3(bl, ry, rz), CLAY, 14)
			_sph(rig, 1.0, c.lightened(0.05), Vector3(0.35, by + 0.15, 0), Vector3(0.45, 0.48, 0.45), CLAY, 12)
		_:
			_sph(rig, 1.0, c, Vector3(-bl * 0.25, by, 0), Vector3(bl * 0.8, ry * 0.95, rz * 0.95), CLAY, 14)
			_sph(rig, 1.0, c, Vector3(bl * 0.3, by + ry * 0.08, 0), Vector3(bl * 0.6, ry * 1.05, rz * 1.02), CLAY, 14)
			_sph(rig, 1.0, belly, Vector3(0, by - ry * 0.35, 0), Vector3(bl * 0.75, ry * 0.6, rz * 0.8), CLAY, 12)
	# Rasgos del lomo
	match v:
		"wolf", "hellhound", "prowler", "prism", "ripper":
			for i in 5:  # gorguera de pelo
				var a := TAU * i / 5.0
				_cone(rig, 0.14, 0.35, c.lightened(0.08), Vector3(bl * 0.55 + cos(a) * 0.05, by + sin(a) * ry * 0.7, sin(a) * rz * 0.85 + cos(a) * 0.1), Vector3(rad_to_deg(sin(a)) * 0.8, 0, 100 + cos(a) * 30), CLAY, 5)
			for i in 4:
				_cone(rig, 0.08, 0.22, dark, Vector3(bl * (0.45 - i * 0.3), by + ry * 0.95, 0), Vector3(0, 0, 110), CLAY, 4)
		"boar":
			for i in 7:
				_box(rig, Vector3(0.12, 0.22, 0.06), Color(0.15, 0.1, 0.08), Vector3(bl * (0.55 - i * 0.18), by + ry * 0.95 - absf(i - 2.0) * 0.03, 0), Vector3(0, 0, -15))
		"lizard", "croc", "cave":
			for i in 6:
				var sc := Color(0.4, 0.38, 0.35) if str(o.get("name", "")).contains("roca") else dark
				_cone(rig, 0.08, 0.16, sc, Vector3(bl * (0.6 - i * 0.24), by + ry * 0.9, 0), Vector3.ZERO, CLAY, 4)
			if str(o.get("name", "")).contains("roca"):
				for i in 4:
					_sph(rig, 0.18, Color(0.45, 0.43, 0.4), Vector3(bl * (0.4 - i * 0.3), by + ry * 0.7, (0.12 if i % 2 == 0 else -0.12)), Vector3(1.2, 0.5, 1), CLAY, 6)
			if o.get("fire", false):
				for i in 5:
					_sph(rig, 0.07, FIRE, Vector3(bl * (0.5 - i * 0.25), by + ry * 0.75, rz * 0.6 * (1 - 2 * (i % 2))), Vector3.ONE, GLOW, 6)
		"siege":
			_box(rig, Vector3(bl * 1.6, 0.12, rz * 2.2), metal_plate(), Vector3(0, by + ry * 0.75, 0), Vector3.ZERO, METAL)
			for z in [-1.0, 1.0]:
				_box(rig, Vector3(bl * 1.5, ry * 1.2, 0.08), Color(0.5, 0.35, 0.2), Vector3(0, by + 0.05, rz * 1.0 * z), Vector3(10 * z, 0, 0))
				for i in 4:
					_sph(rig, 0.05, IRON, Vector3(-bl * 0.6 + i * bl * 0.4, by + 0.25, rz * 1.06 * z), Vector3.ONE, METAL, 6)
			_box(rig, Vector3(0.5, 0.5, 0.6), WOOD, Vector3(-0.1, by + ry + 0.25, 0))
			_box(rig, Vector3(0.56, 0.08, 0.66), WOOD_DARK, Vector3(-0.1, by + ry + 0.52, 0))
			for k in 4:
				_box(rig, Vector3(0.1, 0.12, 0.1), WOOD_DARK, Vector3(-0.32 + (k % 2) * 0.44, by + ry + 0.62, -0.24 + (k / 2) * 0.48))
			_cyl(rig, 0.02, 0.02, 0.6, WOOD_DARK, Vector3(-0.1, by + ry + 0.9, 0), Vector3.ZERO, CLAY, 4)
			_box(rig, Vector3(0.3, 0.2, 0.02), Color(0.7, 0.1, 0.1), Vector3(0.05, by + ry + 1.08, 0))
		"mammoth":
			for i in 8:
				var a := TAU * i / 8.0
				_cone(rig, 0.2, 0.55, c.darkened(0.1), Vector3(cos(a) * bl * 0.5, by - ry * 0.5, sin(a) * rz * 0.85), Vector3(0, 0, 180), CLAY, 5)
			# castillete de guerra
			_box(rig, Vector3(0.9, 0.08, 1.1), Color(0.65, 0.15, 0.15), Vector3(-0.1, by + ry * 0.85, 0), Vector3.ZERO)
			_box(rig, Vector3(0.6, 0.45, 0.65), WOOD, Vector3(-0.1, by + ry + 0.2, 0))
			for k in 4:
				_cyl(rig, 0.03, 0.03, 0.5, WOOD_DARK, Vector3(-0.38 + (k % 2) * 0.56, by + ry + 0.6, -0.3 + (k / 2) * 0.6), Vector3.ZERO, CLAY, 5)
			_box(rig, Vector3(0.7, 0.06, 0.75), Color(0.85, 0.75, 0.5), Vector3(-0.1, by + ry + 0.85, 0))
			_cyl(rig, 0.02, 0.02, 0.5, WOOD_DARK, Vector3(-0.1, by + ry + 1.1, 0), Vector3.ZERO, CLAY, 4)
			_box(rig, Vector3(0.3, 0.2, 0.02), Color(0.2, 0.35, 0.75), Vector3(0.05, by + ry + 1.25, 0))
		"chaos", "ripper", "behemoth":
			for i in 6:
				_cone(rig, 0.12 if v != "ripper" else 0.07, 0.45 if v != "ripper" else 0.28, Color(0.15, 0.05, 0.1) if v != "behemoth" else c.darkened(0.45), Vector3(bl * (0.5 - i * 0.22), by + ry * 0.9, 0.12 * (1 - 2 * (i % 2))), Vector3(15 * (1 - 2 * (i % 2)), 0, 15), CLAY, 4)
			if v == "chaos":
				for i in 3:
					_sph(rig, 0.07, Color(1.0, 0.3, 0.6), Vector3(bl * (0.3 - i * 0.3), by + ry * 0.4, rz * 0.98), Vector3(0.6, 1, 1), GLOW, 6)
		"bear":
			_sph(rig, 1.0, c, Vector3(bl * 0.4, by + ry * 0.3, 0), Vector3(0.4, 0.45, rz * 0.95), CLAY, 12)  # joroba
		"horse":
			# crin y cola de fuego
			for i in 6:
				_cone(rig, 0.1, 0.4, FIRE if v == "horse" else c, Vector3(bl * 0.75 + i * 0.07, by + 0.35 + i * 0.12, 0), Vector3(0, 0, 70), GLOW, 5)
			_box(rig, Vector3(bl * 0.8, 0.08, rz * 2.1), Color(0.15, 0.1, 0.1), Vector3(0, by + ry * 0.9, 0))  # silla
			for z in [-1.0, 1.0]:
				_box(rig, Vector3(0.4, 0.35, 0.04), Color(0.5, 0.05, 0.08), Vector3(0, by + 0.1, rz * 1.02 * z), Vector3(8 * z, 0, 0))
	if v == "prowler" or v == "prism" or (o.get("ice", false) and v == "wolf"):
		var kc := ICE_GLOW if v != "prism" else Color(0.75, 0.55, 1.0)
		for i in 5:
			_cone(rig, 0.08, 0.35 + 0.08 * (i % 2), kc, Vector3(bl * (0.5 - i * 0.28), by + ry * 0.85, 0.08 * (1 - 2 * (i % 2))), Vector3(20 * (1 - 2 * (i % 2)), 0, 20), GLOW, 5)
	if v == "hellhound":
		for i in 4:
			_cone(rig, 0.09, 0.28, FIRE, Vector3(bl * (0.4 - i * 0.28), by + ry * 0.9, 0), Vector3(0, 0, 20), GLOW, 5)
	if o.get("boss", false) or o.get("grand", false):
		_box(rig, Vector3(bl * 1.1, 0.08, rz * 2.15), Color(0.55, 0.1, 0.12), Vector3(0, by + ry * 0.92, 0))
		for z in [-1.0, 1.0]:
			_box(rig, Vector3(bl * 1.0, ry * 0.9, 0.04), Color(0.55, 0.1, 0.12), Vector3(0, by + ry * 0.4, rz * 1.02 * z), Vector3(5 * z, 0, 0))
			_box(rig, Vector3(bl * 1.02, 0.07, 0.05), GOLD, Vector3(0, by - ry * 0.02, rz * 1.05 * z), Vector3.ZERO, METAL)

	# --- Patas (pares en diagonal)
	var amp := 0.5
	if v in ["siege", "mammoth", "behemoth", "chaos", "walrus"]:
		amp = 0.3
	var sprawl: bool = d.get("sprawl", false)
	for i in 4:
		var front := i < 2
		var z := -1.0 if i % 2 == 0 else 1.0
		var hx := bl * (0.6 if front else -0.55)
		var off := 0.0 if (front == (z < 0)) else PI
		var mode := SINE
		var lp := _pivot(rig, ["LegFL", "LegFR", "LegBL", "LegBR"][i], Vector3(hx, hip, rz * (0.55 if not sprawl else 0.85) * z), Vector3.ZERO,
				[_tr(ROT, 2, amp if v != "hare" else 0.7, WALK, off if v != "hare" else (0.0 if front else PI), true, mode)])
		_quad_leg(lp, v, o, d, front, z, c, sprawl)

	# --- Cola
	var tp := _pivot(rig, "Tail", Vector3(-bl * 0.95, by + ry * 0.2, 0), Vector3.ZERO, [_tr(ROT, 1, 0.4 if v not in ["siege", "mammoth"] else 0.2, WALK * 0.5, 0.0, false)])
	match v:
		"wolf", "hellhound", "prowler", "prism", "ripper":
			_chain(tp, [Vector3.ZERO, Vector3(-0.25, 0.1, 0), Vector3(-0.5, 0.0, 0), Vector3(-0.7, -0.2, 0)], 0.1, 0.06, c)
			_sph(tp, 0.14, c.lightened(0.15) if v != "hellhound" else FIRE, Vector3(-0.68, -0.18, 0), Vector3(1.4, 0.9, 0.9), CLAY if v != "hellhound" else GLOW, 8)
		"boar":
			_chain(tp, [Vector3.ZERO, Vector3(-0.12, 0.05, 0), Vector3(-0.2, -0.12, 0)], 0.04, 0.02, dark)
			_cone(tp, 0.05, 0.12, Color(0.15, 0.1, 0.08), Vector3(-0.22, -0.2, 0), Vector3(0, 0, 180), CLAY, 4)
		"lizard", "croc", "cave":
			var L := 1.1 if v != "croc" else 1.4
			_chain(tp, [Vector3.ZERO, Vector3(-L * 0.35, -0.08, 0), Vector3(-L * 0.7, -0.18, 0.05), Vector3(-L, -0.24, -0.05)], ry * 0.9, 0.03, c)
			if o.get("fire", false):
				_cone(tp, 0.1, 0.3, FIRE, Vector3(-L, -0.15, -0.05), Vector3(0, 0, 60), GLOW, 5)
		"horse":
			for k in 3:
				_cone(tp, 0.1, 0.55, FIRE if k != 1 else FIRE_HOT, Vector3(-0.15, -0.15 - k * 0.04, (k - 1) * 0.06), Vector3(0, 0, 130 + k * 10), GLOW, 5)
		"rat":
			_chain(tp, [Vector3.ZERO, Vector3(-0.4, -0.15, 0), Vector3(-0.8, -0.3, 0.1), Vector3(-1.1, -0.32, -0.05)], 0.05, 0.015, Color(0.85, 0.6, 0.6))
		"bear", "mole":
			_sph(tp, 0.1, c, Vector3(-0.02, 0, 0), Vector3.ONE, CLAY, 6)
		"hare":
			_sph(tp, 0.14, WHITE, Vector3(-0.04, 0.05, 0), Vector3.ONE, CLAY, 8)
		"walrus":
			_plate(tp, [Vector2(0, -0.1), Vector2(0, 0.1), Vector2(-0.35, -0.3), Vector2(-0.35, 0.3)], 0.06, c.darkened(0.15), Vector3(-0.05, -by + 0.06, 0))
		"siege", "mammoth", "behemoth", "chaos":
			_chain(tp, [Vector3.ZERO, Vector3(-0.15, -0.3, 0), Vector3(-0.2, -0.6, 0)], 0.06, 0.03, c.darkened(0.1))
			_sph(tp, 0.08, dark, Vector3(-0.2, -0.65, 0), Vector3(1, 1.5, 1), CLAY, 6)

	# --- Cabeza
	var hp := _pivot(rig, "Head", Vector3(bl * 0.85, by, 0) + (d["neck"] as Vector3), Vector3.ZERO, [_tr(ROT, 2, 0.08, WALK, 0.6)])
	_quad_head(hp, v, o, d, c, eye)


static func metal_plate() -> Color:
	return Color(0.45, 0.45, 0.5)


static func _quad_leg(lp: Node3D, v: String, o: Dictionary, d: Dictionary, front: bool, z: float, c: Color, sprawl: bool) -> void:
	var hip: float = d["hip"]
	var lr: float = d["lr"]
	var foot := Vector3(0.04, -hip + lr * 0.6, 0)
	if sprawl:
		var knee := Vector3(0.0, -hip * 0.15, 0.3 * z)
		_sph(lp, lr * 1.6, c, Vector3.ZERO, Vector3.ONE, CLAY, 8)
		_seg(lp, lr * 1.3, lr, c, Vector3.ZERO, knee)
		_seg(lp, lr, lr * 0.8, c, knee, Vector3(0.05, -hip + 0.05, 0.35 * z))
		if v == "walrus":
			_plate(lp, [Vector2(0, -0.12), Vector2(0, 0.12), Vector2(0.35, -0.2), Vector2(0.4, 0.15)], 0.05, c.darkened(0.15), Vector3(0.0, -hip + 0.04, 0.38 * z))
			return
		for k in 3:
			_cone(lp, 0.035, 0.14, c.darkened(0.3), Vector3(0.12, -hip + 0.04, 0.35 * z + (k - 1) * 0.06), Vector3(0, (k - 1) * 20.0, -90), CLAY, 4)
		return
	var thick := 1.0
	if v in ["boar", "bear", "siege", "mammoth", "behemoth", "chaos"]:
		thick = 1.0
	var knee := Vector3(0.06 if not front else -0.03, -hip * 0.5, 0)
	_sph(lp, lr * 1.9, c, Vector3(0, 0.05, 0), Vector3(1.2, 1.4, 1.0), CLAY, 8)
	_seg(lp, lr * 1.5 * thick, lr * thick, c, Vector3.ZERO, knee)
	_seg(lp, lr * thick, lr * 0.85 * thick, c, knee, foot)
	match v:
		"horse":
			_cyl(lp, lr * 1.1, lr * 1.4, 0.12, DARK, foot + Vector3(0, -lr * 0.3, 0), Vector3.ZERO, CLAY, 8)
			_cone(lp, lr * 1.3, 0.2, FIRE, foot + Vector3(-0.02, 0.05, 0), Vector3(0, 0, 160), GLOW, 6)
		"boar":
			_cyl(lp, lr * 0.9, lr * 1.2, 0.1, DARK, foot + Vector3(0.02, -lr * 0.4, 0), Vector3.ZERO, CLAY, 6)
		"siege", "mammoth", "behemoth":
			_cyl(lp, lr * 1.3, lr * 1.45, 0.16, c.darkened(0.2) if v != "siege" else metal_plate(), foot + Vector3(0, -lr * 0.25, 0), Vector3.ZERO, CLAY if v != "siege" else METAL, 10)
			for k in 3:
				_sph(lp, lr * 0.25, BONE, foot + Vector3(lr * 1.2, -lr * 0.3, (k - 1) * lr * 0.6), Vector3(0.6, 0.6, 1), CLAY, 6)
		"mole":
			_sph(lp, lr * 1.8, Color(0.9, 0.65, 0.6), foot + Vector3(0.06, 0, 0.03 * z), Vector3(1.2, 0.5, 1.4), CLAY, 8)
			for k in 3:
				_cone(lp, 0.03, 0.12, WHITE, foot + Vector3(0.18, -0.02, (k - 1) * 0.06 + 0.03 * z), Vector3(0, 0, -90), CLAY, 4)
		_:
			_sph(lp, lr * 1.35, c.darkened(0.08), foot + Vector3(0.04, -lr * 0.25, 0), Vector3(1.4, 0.7, 1.1), CLAY, 8)
			if v in ["bear", "wolf", "hellhound", "prowler", "chaos", "ripper", "prism", "rat"]:
				for k in 3:
					_cone(lp, lr * 0.2, lr * 0.8, Color(0.15, 0.12, 0.1) if v != "bear" else WHITE.darkened(0.2), foot + Vector3(lr * 1.3, -lr * 0.4, (k - 1) * lr * 0.5), Vector3(0, 0, -100), CLAY, 4)


static func _quad_head(hp: Node3D, v: String, o: Dictionary, d: Dictionary, c: Color, eye: Color) -> void:
	var hr: float = d["hr"]
	var dark := c.darkened(0.35)
	var nose := Color(0.12, 0.08, 0.08)
	match v:
		"boar":
			_sph(hp, hr, c, Vector3.ZERO, Vector3(1.1, 0.95, 0.9), CLAY, 12)
			_cyl(hp, hr * 0.45, hr * 0.55, hr * 0.7, c.lightened(0.1), Vector3(hr * 0.9, -hr * 0.2, 0), Vector3(0, 0, -95), CLAY, 10)
			_cyl(hp, hr * 0.46, hr * 0.46, 0.04, Color(0.75, 0.5, 0.45), Vector3(hr * 1.27, -hr * 0.23, 0), Vector3(0, 0, -95), CLAY, 10)
			for z in [-1.0, 1.0]:
				_sph(hp, hr * 0.09, nose, Vector3(hr * 1.3, -hr * 0.23, hr * 0.15 * z), Vector3.ONE, CLAY, 4)
				_horn(hp, Vector3(hr * 0.9, -hr * 0.45, hr * 0.35 * z), Vector3(0.3, 1.0, 0.3 * z), Vector3(-0.6, 0, 0), hr * 0.7, hr * 0.12, Color(0.95, 0.92, 0.8))
				_cone(hp, hr * 0.25, hr * 0.45, dark, Vector3(-hr * 0.2, hr * 0.75, hr * 0.5 * z), Vector3(-30 * z, 0, 20), CLAY, 4)
				_eye(hp, Vector3(hr * 0.65, hr * 0.3, hr * 0.48 * z), hr * 0.13, eye if eye.a > 0 else Color(0, 0, 0, 0))
				_box(hp, Vector3(hr * 0.1, hr * 0.08, hr * 0.35), Color(0.15, 0.1, 0.08), Vector3(hr * 0.72, hr * 0.48, hr * 0.42 * z), Vector3(-25 * z, 0, 0))
		"lizard", "croc", "cave":
			var long := 1.6 if v == "croc" else 1.0
			_sph(hp, hr, c, Vector3.ZERO, Vector3(1.2, 0.75, 1.0), CLAY, 12)
			_box(hp, Vector3(hr * 1.6 * long, hr * 0.5, hr * 1.2), c, Vector3(hr * (0.75 + 0.5 * long), -hr * 0.1, 0))
			_box(hp, Vector3(hr * 1.5 * long, hr * 0.25, hr * 1.1), c.lightened(0.2), Vector3(hr * (0.7 + 0.5 * long), -hr * 0.42, 0))
			for z in [-1.0, 1.0]:
				_sph(hp, hr * 0.28, c, Vector3(hr * 0.35, hr * 0.42, hr * 0.42 * z), Vector3.ONE, CLAY, 8)
				_eye(hp, Vector3(hr * 0.52, hr * 0.5, hr * 0.42 * z), hr * 0.17, eye if eye.a > 0 else (FIRE_HOT if o.get("fire", false) else Color(0, 0, 0, 0)), DARK)
				if v == "croc":
					for k in 4:
						_cone(hp, hr * 0.06, hr * 0.18, WHITE, Vector3(hr * (0.6 + k * 0.4), -hr * 0.28, hr * 0.55 * z), Vector3(0, 0, 180), CLAY, 3)
			if o.get("fire", false):
				for k in 3:
					_cone(hp, hr * 0.15, hr * 0.6, FIRE, Vector3(-hr * 0.2 - k * hr * 0.3, hr * 0.55, 0), Vector3(0, 0, 50), GLOW, 5)
		"horse":
			_box(hp, Vector3(hr * 1.1, hr * 2.2, hr * 1.2), c, Vector3(-hr * 0.2, -hr * 0.4, 0), Vector3(0, 0, -30))  # cuello
			_box(hp, Vector3(hr * 2.2, hr * 1.0, hr * 1.0), c, Vector3(hr * 0.9, hr * 0.5, 0), Vector3(0, 0, -25))
			_box(hp, Vector3(hr * 0.7, hr * 0.85, hr * 0.95), DARK, Vector3(hr * 1.85, hr * 0.0, 0), Vector3(0, 0, -25))
			for z in [-1.0, 1.0]:
				_sph(hp, hr * 0.18, eye if eye.a > 0 else FIRE_HOT, Vector3(hr * 0.75, hr * 0.85, hr * 0.48 * z), Vector3(0.6, 1, 1), GLOW, 6)
				_cone(hp, hr * 0.18, hr * 0.5, c, Vector3(hr * 0.05, hr * 1.3, hr * 0.3 * z), Vector3(0, 0, 10), CLAY, 4)
				_sph(hp, hr * 0.1, FIRE, Vector3(hr * 2.15, -hr * 0.1, hr * 0.2 * z), Vector3.ONE, GLOW, 4)
			_horn(hp, Vector3(hr * 0.35, hr * 1.15, 0), Vector3(0.6, 1.0, 0), Vector3(1, 0, 0), hr * 0.8, hr * 0.12, Color(0.15, 0.1, 0.1))
		"siege", "behemoth", "mammoth", "chaos":
			_sph(hp, hr, c, Vector3(hr * 0.1, 0, 0), Vector3(1.1, 1.0, 1.0), CLAY, 12)
			if v == "mammoth":
				_chain(hp, [Vector3(hr * 0.9, -hr * 0.1, 0), Vector3(hr * 1.2, -hr * 0.8, 0), Vector3(hr * 1.15, -hr * 1.5, 0), Vector3(hr * 1.4, -hr * 1.9, 0)], hr * 0.32, hr * 0.15, c)
				for z in [-1.0, 1.0]:
					_horn(hp, Vector3(hr * 0.8, -hr * 0.5, hr * 0.4 * z), Vector3(1.0, -0.6, 0.25 * z), Vector3(0, 1.0, 0.2 * z), hr * 2.2, hr * 0.17, Color(0.95, 0.92, 0.82))
					_sph(hp, hr * 0.7, c.darkened(0.05), Vector3(-hr * 0.1, hr * 0.0, hr * 0.85 * z), Vector3(0.3, 1.0, 0.8), CLAY, 8)
					_eye(hp, Vector3(hr * 0.78, hr * 0.3, hr * 0.5 * z), hr * 0.1)
				_sph(hp, hr * 0.6, c.darkened(0.15), Vector3(-hr * 0.1, hr * 0.7, 0), Vector3(1, 0.7, 1), CLAY, 8)
			else:
				_box(hp, Vector3(hr * 1.1, hr * 0.9, hr * 1.2), c.lightened(0.05), Vector3(hr * 0.8, -hr * 0.3, 0))
				for z in [-1.0, 1.0]:
					_sph(hp, hr * 0.17, eye if eye.a > 0 else (RED_GLOW if v != "behemoth" else Color(1.0, 0.9, 0.3)), Vector3(hr * 0.8, hr * 0.35, hr * 0.5 * z), Vector3(0.6, 1, 1), GLOW, 6)
					_horn(hp, Vector3(hr * 0.2, hr * 0.6, hr * 0.6 * z), Vector3(0.3, 0.6, 1.0 * z), Vector3(0.6, 0.6, -0.3 * z), hr * 1.3, hr * 0.2, BONE if v != "chaos" else Color(0.2, 0.05, 0.1))
				if v == "siege":
					_box(hp, Vector3(hr * 0.5, hr * 1.4, hr * 1.5), metal_plate(), Vector3(hr * 1.4, -hr * 0.2, 0), Vector3.ZERO, METAL)
					_cone(hp, hr * 0.25, hr * 0.8, IRON, Vector3(hr * 1.6, hr * 0.5, 0), Vector3(0, 0, -30), METAL, 6)
					for z in [-1.0, 1.0]:
						_cone(hp, hr * 0.12, hr * 0.4, IRON, Vector3(hr * 1.7, -hr * 0.5, hr * 0.45 * z), Vector3(0, 0, -90), METAL, 4)
				else:
					_cone(hp, hr * 0.22, hr * 0.7, BONE, Vector3(hr * 1.35, hr * 0.15, 0), Vector3(0, 0, -50), CLAY, 6)
					for k in 4:
						_cone(hp, hr * 0.07, hr * 0.22, WHITE, Vector3(hr * 1.3, -hr * 0.75, (k - 1.5) * hr * 0.3), Vector3(0, 0, 180), CLAY, 3)
		"rat", "mole", "hare":
			_sph(hp, hr, c, Vector3.ZERO, Vector3(1.0, 0.95, 0.9), CLAY, 12)
			_cone(hp, hr * 0.6, hr * 1.2, c, Vector3(hr * 0.9, -hr * 0.1, 0), Vector3(0, 0, -90), CLAY, 10)
			_sph(hp, hr * 0.17, Color(0.95, 0.6, 0.65) if v != "rat" else DARK, Vector3(hr * 1.5, -hr * 0.1, 0), Vector3.ONE, CLAY, 6)
			for z in [-1.0, 1.0]:
				if v == "mole":
					_sph(hp, hr * 0.06, DARK, Vector3(hr * 0.75, hr * 0.25, hr * 0.38 * z), Vector3.ONE, CLAY, 4)
				else:
					_eye(hp, Vector3(hr * 0.55, hr * 0.3, hr * 0.45 * z), hr * 0.17, eye, DARK)
				for k in 2:
					_seg(hp, 0.006, 0.006, DARK, Vector3(hr * 1.3, -hr * 0.1, hr * 0.15 * z), Vector3(hr * 1.45, -hr * (0.05 + k * 0.15), hr * 0.7 * z))
				if v == "rat":
					_cyl(hp, hr * 0.4, hr * 0.4, 0.04, Color(0.85, 0.6, 0.6), Vector3(-hr * 0.1, hr * 0.85, hr * 0.5 * z), Vector3(80 * z, 0, 0), CLAY, 10)
				elif v == "hare":
					_sph(hp, hr * 0.3, c, Vector3(-hr * 0.3, hr * 1.5, hr * 0.35 * z), Vector3(0.5, 2.6, 0.9), CLAY, 8)
					_sph(hp, hr * 0.22, Color(0.95, 0.75, 0.75), Vector3(-hr * 0.22, hr * 1.5, hr * 0.38 * z), Vector3(0.3, 2.3, 0.7), CLAY, 6)
			if v == "rat" or v == "hare":
				_box(hp, Vector3(0.03, hr * 0.25, hr * 0.3), WHITE, Vector3(hr * 1.38, -hr * 0.45, 0))
		"bear":
			_sph(hp, hr, c, Vector3.ZERO, Vector3(1.0, 0.95, 1.0), CLAY, 12)
			_sph(hp, hr * 0.55, c.lightened(0.25), Vector3(hr * 0.8, -hr * 0.25, 0), Vector3(1.0, 0.8, 0.9), CLAY, 10)
			_sph(hp, hr * 0.18, nose, Vector3(hr * 1.3, -hr * 0.12, 0), Vector3.ONE, CLAY, 6)
			_box(hp, Vector3(hr * 0.15, hr * 0.12, hr * 0.5), Color(0.5, 0.1, 0.1), Vector3(hr * 1.2, -hr * 0.55, 0))
			for z in [-1.0, 1.0]:
				_sph(hp, hr * 0.28, c, Vector3(-hr * 0.1, hr * 0.85, hr * 0.6 * z), Vector3(0.6, 1, 1), CLAY, 8)
				_eye(hp, Vector3(hr * 0.7, hr * 0.3, hr * 0.42 * z), hr * 0.15, Color(1.0, 0.3, 0.15) if str(o.get("name", "")).contains("rabioso") else Color(0, 0, 0, 0))
				_cone(hp, hr * 0.07, hr * 0.22, WHITE, Vector3(hr * 1.15, -hr * 0.5, hr * 0.15 * z), Vector3(0, 0, 180), CLAY, 4)
		"walrus":
			_sph(hp, hr, c, Vector3.ZERO, Vector3(1.0, 0.9, 1.0), CLAY, 12)
			for z in [-1.0, 1.0]:
				_sph(hp, hr * 0.45, c.lightened(0.15), Vector3(hr * 0.75, -hr * 0.3, hr * 0.3 * z), Vector3.ONE, CLAY, 8)
				_seg(hp, hr * 0.13, hr * 0.04, Color(0.98, 0.95, 0.85), Vector3(hr * 0.9, -hr * 0.5, hr * 0.25 * z), Vector3(hr * 1.1, -hr * 1.6, hr * 0.3 * z))
				_eye(hp, Vector3(hr * 0.75, hr * 0.35, hr * 0.42 * z), hr * 0.12, Color(1.0, 0.3, 0.15) if str(o.get("name", "")).contains("furios") else Color(0, 0, 0, 0))
				for k in 3:
					_seg(hp, 0.008, 0.008, WHITE, Vector3(hr * 1.1, -hr * 0.3, hr * 0.4 * z), Vector3(hr * 1.4, -hr * (0.2 + k * 0.15), hr * 0.8 * z))
		_:
			# lobo, sabueso, merodeador
			_sph(hp, hr, c, Vector3.ZERO, Vector3(1.0, 0.95, 0.95), CLAY, 12)
			_box(hp, Vector3(hr * 1.4, hr * 0.6, hr * 0.8), c, Vector3(hr * 0.9, -hr * 0.2, 0), Vector3(0, 0, -8))
			_box(hp, Vector3(hr * 1.2, hr * 0.25, hr * 0.7), c.lightened(0.25), Vector3(hr * 0.85, -hr * 0.55, 0), Vector3(0, 0, -4))
			_sph(hp, hr * 0.17, nose, Vector3(hr * 1.6, -hr * 0.05, 0), Vector3(1, 0.8, 1.2), CLAY, 6)
			_box(hp, Vector3(hr * 0.9, 0.025, hr * 0.75), DARK, Vector3(hr * 1.0, -hr * 0.42, 0), Vector3(0, 0, -6))
			for z in [-1.0, 1.0]:
				_cone(hp, hr * 0.3, hr * 0.65, c.darkened(0.1), Vector3(-hr * 0.15, hr * 0.85, hr * 0.48 * z), Vector3(-15 * z, 0, -10), CLAY, 4)
				_eye(hp, Vector3(hr * 0.68, hr * 0.28, hr * 0.42 * z), hr * 0.16, eye if eye.a > 0 else Color(1.0, 0.85, 0.2))
				_box(hp, Vector3(hr * 0.12, hr * 0.06, hr * 0.38), c.darkened(0.45), Vector3(hr * 0.75, hr * 0.47, hr * 0.38 * z), Vector3(-25 * z, 0, 0))
				_cone(hp, hr * 0.06, hr * 0.22, WHITE, Vector3(hr * 1.45, -hr * 0.42, hr * 0.22 * z), Vector3(0, 0, 180), CLAY, 4)
			if v == "hellhound" or v == "ripper":
				for z in [-1.0, 1.0]:
					_horn(hp, Vector3(hr * 0.1, hr * 0.7, hr * 0.35 * z), Vector3(-0.6, 1.0, 0.3 * z), Vector3(-1, 0, 0), hr * 0.9, hr * 0.15, Color(0.15, 0.08, 0.08))
			if o.get("boss", false) or o.get("crowned", false):
				_crown(hp, Vector3(-hr * 0.1, hr * 0.9, 0), hr * 1.4)


# ================================================================ Arañas, escorpiones y escarabajos

## Cuatro grupos de patas (marcha en trípode): izquierda A/B y derecha A/B
static func _leg_groups(rig: Node3D, center: Vector3, amp: float) -> Array:
	var gs: Array = []
	var names := ["LegsLA", "LegsLB", "LegsRA", "LegsRB"]
	for i in 4:
		var left := i < 2
		var phase := 0.0 if (i == 0 or i == 3) else PI
		gs.append(_pivot(rig, names[i], center, Vector3.ZERO, [_tr(ROT, 1, amp * (1.0 if left else -1.0), WALK * 1.3, phase)]))
	return gs


static func _spider(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	var hair := c.lightened(0.15)
	var center := Vector3(0.15, 0.55, 0)
	# abdomen con dibujo de reloj de arena y pelos
	_sph(rig, 0.62, c, Vector3(-0.5, 0.78, 0), Vector3(1.15, 0.95, 1.0), CLAY, 14)
	_sph(rig, 0.2, Color(0.85, 0.15, 0.1), Vector3(-0.62, 1.32, 0), Vector3(1.2, 0.35, 0.7), CLAY, 8)
	_sph(rig, 0.14, Color(0.85, 0.15, 0.1), Vector3(-0.32, 1.33, 0), Vector3(1.0, 0.35, 0.6), CLAY, 8)
	for i in 10:
		var a := TAU * i / 10.0
		_cone(rig, 0.05, 0.18, hair, Vector3(-0.5 + cos(a) * 0.55, 0.78 + sin(a) * 0.45, sin(a * 2.0) * 0.4), Vector3(rad_to_deg(sin(a)) * 0.5, 0, -rad_to_deg(cos(a))), CLAY, 4)
	_cone(rig, 0.08, 0.15, c.darkened(0.3), Vector3(-1.15, 0.7, 0), Vector3(0, 0, 90), CLAY, 6)  # hileras
	# cefalotórax
	_sph(rig, 0.36, c.lightened(0.05), Vector3(0.28, 0.6, 0), Vector3(1.15, 0.85, 1.0), CLAY, 12)
	# ocho ojos rojos
	for i in 4:
		for z in [-1.0, 1.0]:
			var s := 0.07 if i < 2 else 0.045
			_sph(rig, s, RED_GLOW, Vector3(0.62 - i * 0.04, 0.72 + (i % 2) * 0.09 + (0.04 if i >= 2 else 0.0), (0.08 + i * 0.06) * z), Vector3.ONE, GLOW, 6)
	# quelíceros con colmillos
	for z in [-1.0, 1.0]:
		_sph(rig, 0.11, c.darkened(0.2), Vector3(0.66, 0.48, 0.1 * z), Vector3(1, 1.3, 1), CLAY, 8)
		_cone(rig, 0.04, 0.16, Color(0.95, 0.9, 0.75), Vector3(0.7, 0.32, 0.1 * z), Vector3(0, 0, 160), CLAY, 4)
		# pedipalpos
		_chain(rig, [Vector3(0.55, 0.5, 0.18 * z), Vector3(0.75, 0.5, 0.3 * z), Vector3(0.82, 0.3, 0.3 * z)], 0.04, 0.03, c)
	if o.get("boss", false) or o.get("crowned", false):
		_crown(rig, Vector3(0.25, 0.92, 0), 0.6)
	# patas
	var gs := _leg_groups(rig, center, 0.22)
	var dx := [0.45, 0.15, -0.15, -0.42]
	for side in [-1.0, 1.0]:
		for k in 4:
			var gi := (0 if k % 2 == 0 else 1) + (0 if side < 0 else 2)
			var g: Node3D = gs[gi]
			var base := Vector3(0.3 + (0.15 - k * 0.1), 0.6, 0.22 * side) - center
			var knee := base + Vector3(float(dx[k]) * 0.6, 0.55, 0.55 * side)
			var foot := base + Vector3(float(dx[k]) * 1.3, -0.6, 1.1 * side)
			_chain(g, [base, knee, foot], 0.065, 0.025, c, CLAY)
			_sph(g, 0.06, hair, knee, Vector3.ONE, CLAY, 6)
			for t in 3:
				_cone(g, 0.02, 0.08, hair, base.lerp(knee, 0.3 + t * 0.25) + Vector3(0, 0.03, 0), Vector3(0, 0, -30), CLAY, 3)


static func _scorpion(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	var shell := c.darkened(0.15)
	var center := Vector3(0, 0.4, 0)
	for i in 5:  # segmentos del cuerpo
		_sph(rig, 0.34 - i * 0.02, c if i % 2 == 0 else shell, Vector3(0.35 - i * 0.2, 0.42, 0), Vector3(0.75, 0.55, 1.0), CLAY, 12)
	_sph(rig, 0.3, c.lightened(0.05), Vector3(0.55, 0.42, 0), Vector3(0.9, 0.6, 1.0), CLAY, 12)
	for z in [-1.0, 1.0]:
		_sph(rig, 0.05, Color(0.1, 0.06, 0.04), Vector3(0.8, 0.52, 0.08 * z), Vector3.ONE, CLAY, 6)
		_sph(rig, 0.035, RED_GLOW if o.get("grand", false) else Color(0.1, 0.06, 0.04), Vector3(0.78, 0.56, 0.16 * z), Vector3.ONE, GLOW if o.get("grand", false) else CLAY, 6)
	if o.get("boss", false):
		_crown(rig, Vector3(0.5, 0.65, 0), 0.5)
	var gs := _leg_groups(rig, center, 0.2)
	for side in [-1.0, 1.0]:
		for k in 4:
			var gi := (0 if k % 2 == 0 else 1) + (0 if side < 0 else 2)
			var g: Node3D = gs[gi]
			var base := Vector3(0.35 - k * 0.2, 0.4, 0.25 * side) - center
			var knee := base + Vector3(0.05 - k * 0.05, 0.25, 0.4 * side)
			var foot := base + Vector3(0.1 - k * 0.12, -0.4, 0.75 * side)
			_chain(g, [base, knee, foot], 0.05, 0.025, shell)
	# pinzas
	var claws := _pivot(rig, "Claws", Vector3(0.75, 0.42, 0), Vector3.ZERO, [_tr(ROT, 1, 0.12, 4.0, 0.0, false)])
	for z in [-1.0, 1.0]:
		var a := Vector3(0, 0, 0.18 * z)
		var b := Vector3(0.25, 0.05, 0.45 * z)
		var cl := Vector3(0.55, 0.1, 0.4 * z)
		_chain(claws, [a, b, cl], 0.07, 0.06, c)
		_sph(claws, 0.16, c.lightened(0.05), cl, Vector3(1.3, 0.8, 0.9), CLAY, 10)
		_cone(claws, 0.07, 0.3, shell, cl + Vector3(0.25, 0.0, 0.05 * z), Vector3(0, -20 * z, -95), CLAY, 6)
		_cone(claws, 0.05, 0.22, shell, cl + Vector3(0.22, -0.02, -0.08 * z), Vector3(0, 20 * z, -95), CLAY, 6)
	# cola con aguijón
	var tail := _pivot(rig, "Tail", Vector3(-0.55, 0.45, 0), Vector3.ZERO, [_tr(ROT, 2, 0.15, 3.0, 0.0, false)])
	var pts := [Vector3.ZERO, Vector3(-0.3, 0.3, 0), Vector3(-0.35, 0.7, 0), Vector3(-0.15, 1.0, 0), Vector3(0.15, 1.1, 0)]
	for i in pts.size():
		_sph(tail, 0.15 - i * 0.015, c if i % 2 == 0 else shell, pts[i], Vector3.ONE, CLAY, 10)
	_chain(tail, pts, 0.11, 0.08, c, CLAY, false)
	_sph(tail, 0.13, Color(0.9, 0.75, 0.3) if not o.get("grand", false) else GREEN_GLOW, Vector3(0.28, 1.05, 0), Vector3(1.1, 0.9, 0.9), GLOW, 8)
	_cone(tail, 0.06, 0.22, DARK, Vector3(0.38, 0.92, 0), Vector3(0, 0, 140), CLAY, 5)


static func _beetle(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	var crystal: bool = str(o.get("name", "")).contains("cristal")
	var center := Vector3(0, 0.45, 0)
	_sph(rig, 0.6, c, Vector3(-0.15, 0.62, 0), Vector3(1.25, 0.8, 1.0), METAL, 14)
	_box(rig, Vector3(1.4, 0.04, 0.04), c.darkened(0.5), Vector3(-0.15, 1.1, 0), Vector3(0, 0, -5))
	_sph(rig, 0.3, c.darkened(0.2), Vector3(0.55, 0.52, 0), Vector3(0.9, 0.8, 1.1), METAL, 12)
	_sph(rig, 0.2, c.darkened(0.3), Vector3(0.82, 0.45, 0), Vector3.ONE, CLAY, 10)
	for z in [-1.0, 1.0]:
		_sph(rig, 0.06, Color(0.9, 0.7, 1.0), Vector3(0.93, 0.52, 0.12 * z), Vector3.ONE, GLOW, 6)
		_chain(rig, [Vector3(0.92, 0.55, 0.08 * z), Vector3(1.1, 0.75, 0.18 * z), Vector3(1.2, 0.8, 0.3 * z)], 0.015, 0.012, DARK)
	_horn(rig, Vector3(0.95, 0.5, 0), Vector3(1, 0.6, 0), Vector3(-0.3, 1, 0), 0.55, 0.08, c.lightened(0.2), METAL)
	if crystal:
		for i in 6:
			var a := i * 1.1
			_cone(rig, 0.1, 0.4 + 0.15 * (i % 2), Color(0.8, 0.65, 1.0), Vector3(-0.15 + cos(a) * 0.4, 1.0, sin(a) * 0.3), Vector3(rad_to_deg(sin(a)) * 0.4, 0, -rad_to_deg(cos(a)) * 0.4), GLOW, 5)
	var gs := _leg_groups(rig, center, 0.22)
	for side in [-1.0, 1.0]:
		for k in 3:
			var gi := (0 if k % 2 == 0 else 1) + (0 if side < 0 else 2)
			var g: Node3D = gs[gi]
			var base := Vector3(0.35 - k * 0.3, 0.45, 0.35 * side) - center
			var knee := base + Vector3(0.1 - k * 0.1, 0.2, 0.35 * side)
			var foot := base + Vector3(0.2 - k * 0.2, -0.45, 0.6 * side)
			_chain(g, [base, knee, foot], 0.05, 0.03, c.darkened(0.4))


# ================================================================ Aves

## Ala de plumas que se extiende hacia `s` (-1 = izquierda, +1 = derecha) a lo largo de Z
static func _feather_wing(w: Node3D, s: float, col: Color, tip: Color, span: float, k := CLAY, glow_tips := false) -> void:
	_seg(w, 0.09 * span, 0.05 * span, col, Vector3.ZERO, Vector3(-0.05, 0.05, 0.55 * span * s), k)
	_plate(w, [Vector2(0.12, 0), Vector2(-0.3, 0.0), Vector2(0.05, 0.6 * span * s), Vector2(-0.35, 0.55 * span * s)], 0.06, col, Vector3.ZERO, Vector3.ZERO, k)
	for i in 6:
		var t := i / 5.0
		var root := Vector3(-0.1 - t * 0.05, 0, (0.25 + t * 0.42) * span * s)
		var L := (0.45 + t * 0.45) * span
		var dir := Vector3(-cos(t * 1.1), 0, sin(t * 1.1) * s).normalized()
		var g := _grp(w, root + dir * L * 0.5, Vector3(0, rad_to_deg(atan2(-dir.z, dir.x)), 0))
		_box(g, Vector3(L, 0.035, 0.13 * span), tip if i % 2 == 0 else tip.darkened(0.1), Vector3.ZERO, Vector3.ZERO, GLOW if glow_tips else k)


static func _bird(rig: Node3D, o: Dictionary) -> void:
	var v: String = o.get("var", "crow")
	var c: Color = o["col"]
	var n: String = str(o.get("name", ""))
	var beak := Color(0.25, 0.22, 0.2)
	var chest := c.lightened(0.15)
	var span := 1.15
	var eye := Color(0, 0, 0, 0)
	var head_r := 0.3
	match v:
		"vulture":
			beak = Color(0.85, 0.8, 0.6)
		"hawk":
			beak = Color(0.95, 0.75, 0.2)
			chest = WHITE.lerp(c, 0.25)
			eye = Color(1.0, 0.85, 0.2)
			span = 1.3
		"phoenix":
			beak = GOLD
			eye = FIRE_HOT
			span = 1.3
		"roc":
			beak = GOLD
			span = 1.4
			eye = Color(1.0, 0.85, 0.2)
		"owl":
			beak = Color(0.4, 0.35, 0.25)
			head_r = 0.38
		"griffin", "sphinx":
			beak = GOLD if v == "griffin" else beak
			span = 1.4
			eye = Color(1.0, 0.85, 0.2)
	if n.contains("runico"):
		eye = Color(0.5, 0.8, 1.0)
	if n.contains("helad") or o.get("ice", false):
		eye = ICE_GLOW
	if n.contains("maldito") or n.contains("carron"):
		eye = Color(0.7, 1.0, 0.4)
	var feather_k := GLOW if v == "phoenix" else CLAY
	var wc := c.darkened(0.08)
	var tip := c.darkened(0.3)
	if v == "phoenix":
		wc = FIRE
		tip = FIRE_HOT
	elif v == "hawk":
		tip = c.darkened(0.4)
	if v in ["griffin", "sphinx"]:
		_lion_body(rig, o, c, v)
		wc = c.lightened(0.1) if v == "sphinx" else Color(0.55, 0.4, 0.25).lerp(c, 0.5)
		tip = wc.darkened(0.3)
	elif v == "harpy":
		_harpy_body(rig, o, c)
	else:
		# cuerpo
		_sph(rig, 0.45, c, Vector3(0, 0, 0), Vector3(1.3, 0.85, 0.85), feather_k if v == "phoenix" else CLAY, 14)
		_sph(rig, 0.35, chest, Vector3(0.22, -0.08, 0), Vector3(1.0, 0.95, 0.85), feather_k if v == "phoenix" else CLAY, 12)
		# patas recogidas con garras
		for z in [-1.0, 1.0]:
			_seg(rig, 0.05, 0.04, Color(0.85, 0.7, 0.3), Vector3(-0.05, -0.3, 0.12 * z), Vector3(-0.2, -0.45, 0.12 * z))
			for k in 3:
				_cone(rig, 0.025, 0.1, DARK, Vector3(-0.15, -0.48, 0.12 * z + (k - 1) * 0.04), Vector3(0, 0, -120), CLAY, 3)
		# cabeza
		var H := Vector3(0.55, 0.25, 0)
		if v == "vulture":
			_chain(rig, [Vector3(0.35, 0.1, 0), Vector3(0.55, 0.35, 0), Vector3(0.7, 0.35, 0)], 0.09, 0.07, Color(0.85, 0.55, 0.5))
			for i in 8:
				var a := TAU * i / 8.0
				_sph(rig, 0.12, WHITE, Vector3(0.38, 0.12 + sin(a) * 0.12, cos(a) * 0.17), Vector3.ONE, CLAY, 6)
			H = Vector3(0.75, 0.38, 0)
			_sph(rig, 0.17, Color(0.85, 0.5, 0.45), H, Vector3.ONE, CLAY, 10)
			head_r = 0.17
		elif v == "owl":
			H = Vector3(0.38, 0.32, 0)
			_sph(rig, head_r, c, H, Vector3(0.9, 0.95, 1.05), CLAY, 12)
			for z in [-1.0, 1.0]:
				_cyl(rig, 0.16, 0.16, 0.05, chest.lightened(0.2), H + Vector3(0.28, 0.02, 0.15 * z), Vector3(0, 0, 90), CLAY, 12)
				_sph(rig, 0.1, Color(1.0, 0.65, 0.1), H + Vector3(0.31, 0.02, 0.15 * z), Vector3(0.5, 1, 1), GLOW, 8)
				_sph(rig, 0.05, DARK, H + Vector3(0.36, 0.02, 0.15 * z), Vector3(0.5, 1, 1), CLAY, 6)
				_cone(rig, 0.07, 0.22, c.darkened(0.2), H + Vector3(0.0, 0.35, 0.22 * z), Vector3(-15 * z, 0, -10), CLAY, 4)
			_cone(rig, 0.05, 0.14, beak, H + Vector3(0.36, -0.08, 0), Vector3(0, 0, 160), CLAY, 4)
		else:
			_sph(rig, head_r, c if v != "hawk" else chest, H, Vector3(1.1, 1.0, 0.95), feather_k if v == "phoenix" else CLAY, 12)
		if v != "owl":
			# pico curvo
			_cone(rig, head_r * 0.42, head_r * 1.2, beak, H + Vector3(head_r * 1.25, -head_r * 0.1, 0), Vector3(0, 0, -100), CLAY, 6)
			_cone(rig, head_r * 0.2, head_r * 0.35, beak.darkened(0.2), H + Vector3(head_r * 1.8, -head_r * 0.35, 0), Vector3(0, 0, 180), CLAY, 4)
			for z in [-1.0, 1.0]:
				_eye(rig, H + Vector3(head_r * 0.5, head_r * 0.25, head_r * 0.62 * z), head_r * 0.22, eye)
				_box(rig, Vector3(head_r * 0.5, head_r * 0.12, head_r * 0.25), c.darkened(0.4), H + Vector3(head_r * 0.55, head_r * 0.55, head_r * 0.55 * z), Vector3(-20 * z, 0, -15))
		if v == "phoenix" or v == "roc":
			for k in 4:
				_cone(rig, 0.06, 0.4, FIRE_HOT if v == "phoenix" else Color(0.85, 0.2, 0.15), H + Vector3(-0.1 - k * 0.08, 0.2 + k * 0.03, 0), Vector3(0, 0, 50 + k * 12), GLOW if v == "phoenix" else CLAY, 4)
		if n.contains("guerra") or n.contains("acoraz"):
			_sph(rig, head_r * 1.08, IRON, H + Vector3(-0.02, head_r * 0.2, 0), Vector3(1, 0.7, 1), METAL, 10)
			_cone(rig, 0.05, 0.25, Color(0.7, 0.1, 0.1), H + Vector3(-0.1, head_r * 0.8, 0), Vector3(0, 0, 40), CLAY, 4)
		if n.contains("runico"):
			for k in 3:
				_box(rig, Vector3(0.12, 0.03, 0.03), Color(0.5, 0.8, 1.0), Vector3(-0.1 + k * 0.15, 0.25, 0.38), Vector3(0, 0, 45 * (k % 2)), GLOW)
		if o.get("boss", false) or o.get("crowned", false):
			_crown(rig, H + Vector3(0, head_r * 0.9, 0), head_r * 1.6)
	# cola
	var tail := _pivot(rig, "Tail", Vector3(-0.5, 0.0, 0) if v not in ["griffin", "sphinx"] else Vector3(-0.8, 0.1, 0), Vector3.ZERO, [_tr(ROT, 2, 0.15, 4.0, 0.0, false)])
	if v in ["griffin", "sphinx"]:
		_chain(tail, [Vector3.ZERO, Vector3(-0.3, -0.15, 0), Vector3(-0.55, -0.1, 0), Vector3(-0.7, 0.1, 0)], 0.06, 0.04, c)
		_sph(tail, 0.12, c.darkened(0.35), Vector3(-0.72, 0.15, 0), Vector3(1.2, 1.4, 1), CLAY, 8)
	elif v == "phoenix":
		for k in 5:
			var a := deg_to_rad(-30 + k * 15)
			_seg(tail, 0.07, 0.02, FIRE if k % 2 == 0 else FIRE_HOT, Vector3.ZERO, Vector3(-1.0 - (k % 2) * 0.3, -0.1, sin(a) * 0.6), GLOW)
			_sph(tail, 0.08, FIRE_HOT, Vector3(-1.0 - (k % 2) * 0.3, -0.1, sin(a) * 0.6), Vector3(1.4, 0.4, 1), GLOW, 6)
	else:
		for k in 5:
			var a := deg_to_rad(-28 + k * 14)
			var g := _grp(tail, Vector3(-0.22, 0, sin(a) * 0.12), Vector3(0, rad_to_deg(a), 0))
			_box(g, Vector3(0.5, 0.04, 0.14), tip if k % 2 == 0 else c, Vector3.ZERO, Vector3.ZERO, CLAY)
	# alas
	var wy := 0.12 if v not in ["griffin", "sphinx"] else 0.5
	var wx := 0.05 if v not in ["griffin", "sphinx"] else 0.2
	for s in [-1.0, 1.0]:
		var w := _pivot(rig, "WingL" if s < 0 else "WingR", Vector3(wx, wy, 0.28 * s), Vector3(0, 0, 0))
		_feather_wing(w, s, wc, tip, span, CLAY if v != "phoenix" else GLOW, v == "phoenix")
		if v == "griffin" and (n.contains("acoraz") or n.contains("guerra")):
			_plate(w, [Vector2(0.1, 0), Vector2(-0.2, 0), Vector2(0.05, 0.4 * s), Vector2(-0.2, 0.35 * s)], 0.07, IRON, Vector3(0, 0.03, 0), Vector3.ZERO, METAL)


## Cuerpo de león para grifos y esfinges (vuela con las patas colgando)
static func _lion_body(rig: Node3D, o: Dictionary, c: Color, v: String) -> void:
	var n: String = str(o.get("name", ""))
	var fur := c if v == "sphinx" else Color(0.85, 0.65, 0.3).lerp(c, 0.4)
	_sph(rig, 1.0, fur, Vector3(-0.15, 0, 0), Vector3(0.75, 0.38, 0.36), CLAY, 14)
	_sph(rig, 1.0, fur, Vector3(0.3, 0.08, 0), Vector3(0.42, 0.42, 0.38), CLAY, 12)
	for i in 4:
		var front := i < 2
		var z := -1.0 if i % 2 == 0 else 1.0
		var hx := 0.4 if front else -0.55
		var foot := Vector3(hx + (0.25 if front else -0.25), -0.55, 0.2 * z)
		_seg(rig, 0.11, 0.08, fur, Vector3(hx, -0.1, 0.2 * z), foot)
		var claw := Color(0.95, 0.8, 0.3) if (front and v == "griffin") else fur.darkened(0.1)
		_sph(rig, 0.1, claw, foot, Vector3(1.3, 0.8, 1), CLAY, 8)
		if front and v == "griffin":
			for k in 3:
				_cone(rig, 0.025, 0.12, DARK, foot + Vector3(0.1, -0.03, (k - 1) * 0.05), Vector3(0, 0, -110), CLAY, 3)
	var H := Vector3(0.72, 0.42, 0)
	if v == "griffin":
		_sph(rig, 0.38, Color(0.95, 0.93, 0.88), Vector3(0.48, 0.25, 0), Vector3(0.9, 1.0, 1.0), CLAY, 12)  # pechera de plumas
		_sph(rig, 0.28, Color(0.97, 0.95, 0.9), H, Vector3(1.1, 1.0, 0.95), CLAY, 12)
		_cone(rig, 0.12, 0.35, GOLD, H + Vector3(0.35, -0.03, 0), Vector3(0, 0, -100), METAL, 6)
		_cone(rig, 0.06, 0.1, GOLD.darkened(0.2), H + Vector3(0.5, -0.1, 0), Vector3(0, 0, 180), METAL, 4)
		for z in [-1.0, 1.0]:
			_eye(rig, H + Vector3(0.14, 0.07, 0.17 * z), 0.06, Color(1.0, 0.8, 0.2))
			_cone(rig, 0.06, 0.25, WHITE, H + Vector3(-0.15, 0.2, 0.1 * z), Vector3(0, 0, 70), CLAY, 4)
		if n.contains("acoraz") or n.contains("guerra"):
			_sph(rig, 0.3, IRON, H + Vector3(-0.02, 0.06, 0), Vector3(1.05, 0.7, 1.0), METAL, 10)
			_cone(rig, 0.07, 0.4, Color(0.7, 0.1, 0.1), H + Vector3(-0.1, 0.3, 0), Vector3(0, 0, 50), CLAY, 4)
			_box(rig, Vector3(0.7, 0.08, 0.78), Color(0.6, 0.12, 0.12), Vector3(-0.1, 0.38, 0))
			_box(rig, Vector3(0.72, 0.1, 0.3), IRON, Vector3(-0.1, 0.42, 0), Vector3.ZERO, METAL)
		if n.contains("real") or o.get("boss", false):
			_crown(rig, H + Vector3(-0.02, 0.25, 0), 0.5)
			_box(rig, Vector3(0.7, 0.08, 0.78), Color(0.2, 0.3, 0.75), Vector3(-0.1, 0.37, 0))
			_box(rig, Vector3(0.72, 0.04, 0.8), GOLD, Vector3(-0.1, 0.33, 0), Vector3.ZERO, METAL)
	else:
		# esfinge: cabeza humana con nemes
		_sph(rig, 0.3, SKIN.lerp(c, 0.5), H, Vector3(1, 1.08, 0.95), CLAY, 12)
		var fake := o.duplicate()
		fake.merge({"hat": "nemes", "hat_col": GOLD, "skin": SKIN.lerp(c, 0.5), "eye": Color(0.3, 0.9, 1.0), "head": "human"}, true)
		_hat(rig, fake, H, 0.3)
		for z in [-1.0, 1.0]:
			_eye(rig, H + Vector3(0.26, 0.04, 0.11 * z), 0.06, Color(0.3, 0.9, 1.0))
		_sph(rig, 0.05, SKIN.lerp(c, 0.5).darkened(0.1), H + Vector3(0.3, -0.06, 0), Vector3.ONE, CLAY, 6)
		_cone(rig, 0.08, 0.3, Color(0.15, 0.3, 0.75), H + Vector3(0.12, -0.4, 0), Vector3(0, 0, 175), CLAY, 6)  # barba ceremonial


static func _harpy_body(rig: Node3D, o: Dictionary, c: Color) -> void:
	var skin := Color(0.9, 0.75, 0.65).lerp(c, 0.2)
	_sph(rig, 0.4, c, Vector3(-0.1, -0.15, 0), Vector3(1.1, 0.9, 0.9), CLAY, 12)  # plumaje inferior
	_sph(rig, 0.28, skin, Vector3(0.1, 0.18, 0), Vector3(0.9, 1.1, 0.95), CLAY, 12)
	_sph(rig, 0.3, c.lightened(0.1), Vector3(0.05, 0.05, 0), Vector3(0.95, 0.5, 1.05), CLAY, 12)
	var H := Vector3(0.22, 0.6, 0)
	var fake := {"skin": skin, "hair": c.darkened(0.4), "eye": RED_GLOW if str(o.get("name", "")).contains("caos") else Color(1.0, 0.85, 0.2), "head": "witch", "long_hair": true, "col": c, "boss": false}
	_head(rig, fake, H, 0.24)
	for i in 4:
		_cone(rig, 0.08, 0.35, c.darkened(0.3), H + Vector3(-0.15 - i * 0.04, 0.1 + i * 0.03, (i - 1.5) * 0.08), Vector3((i - 1.5) * 15, 0, 60), CLAY, 4)
	for z in [-1.0, 1.0]:
		_seg(rig, 0.05, 0.04, Color(0.85, 0.7, 0.3), Vector3(-0.1, -0.45, 0.13 * z), Vector3(0.05, -0.7, 0.13 * z))
		for k in 3:
			_cone(rig, 0.03, 0.14, DARK, Vector3(0.1, -0.72, 0.13 * z + (k - 1) * 0.05), Vector3(0, 0, -100), CLAY, 3)


# ================================================================ Murciélagos y demonios alados

static func _membrane_wing(w: Node3D, s: float, bone: Color, skin: Color, span: float, k := CLAY) -> void:
	var wrist := Vector3(0.1, 0.05, 0.55 * span * s)
	_seg(w, 0.06 * span, 0.04 * span, bone, Vector3.ZERO, wrist, k)
	var tips := [Vector3(0.2, 0, 1.15 * span * s), Vector3(-0.2, 0, 1.1 * span * s), Vector3(-0.55, 0, 0.8 * span * s)]
	var prev := Vector3(-0.4, 0, 0.05 * s)
	for t in tips:
		_seg(w, 0.03 * span, 0.012 * span, bone, wrist, t, k)
	_plate(w, [Vector2(0, 0), Vector2(wrist.x, wrist.z), Vector2(prev.x, prev.z), Vector2(-0.45, 0.5 * span * s)], 0.03, skin, Vector3.ZERO, Vector3.ZERO, k)
	var pts2 := [wrist, tips[0], tips[1]]
	_plate(w, [Vector2(wrist.x, wrist.z), Vector2(tips[0].x, tips[0].z), Vector2(tips[1].x, tips[1].z)], 0.03, skin, Vector3.ZERO, Vector3.ZERO, k)
	_plate(w, [Vector2(wrist.x, wrist.z), Vector2(tips[1].x, tips[1].z), Vector2(tips[2].x, tips[2].z), Vector2(-0.45, 0.5 * span * s)], 0.03, skin, Vector3.ZERO, Vector3.ZERO, k)
	_cone(w, 0.03 * span, 0.12 * span, bone.darkened(0.3), wrist + Vector3(0.05, 0.05, 0), Vector3(0, 0, -60), CLAY, 4)


static func _bat(rig: Node3D, o: Dictionary) -> void:
	var v: String = o.get("var", "bat")
	var c: Color = o["col"]
	var n: String = str(o.get("name", ""))
	var spectral := n.contains("espectral")
	var k := GHOST if spectral else CLAY
	var body_c := Color(c, 0.7) if spectral else c
	var span := 1.0
	var eye := RED_GLOW
	if spectral:
		eye = Color(0.6, 1.0, 0.8)
	match v:
		"bat":
			_sph(rig, 0.38, body_c, Vector3(0, 0, 0), Vector3(1.0, 0.95, 0.9), k, 12)
			_sph(rig, 0.3, body_c.lightened(0.15), Vector3(0.12, -0.05, 0), Vector3(0.9, 1.0, 0.85), k, 10)
			var H := Vector3(0.38, 0.18, 0)
			_sph(rig, 0.25, body_c, H, Vector3.ONE, k, 12)
			_sph(rig, 0.12, body_c.lightened(0.25), H + Vector3(0.18, -0.06, 0), Vector3(0.8, 0.7, 1.0), k, 8)
			for z in [-1.0, 1.0]:
				_cone(rig, 0.12, 0.35, body_c, H + Vector3(-0.02, 0.28, 0.13 * z), Vector3(-15 * z, 0, -10), k, 5)
				_cone(rig, 0.07, 0.25, Color(0.85, 0.5, 0.55, body_c.a), H + Vector3(0.0, 0.27, 0.14 * z), Vector3(-15 * z, 0, -10), k, 4)
				_sph(rig, 0.06, eye, H + Vector3(0.2, 0.06, 0.1 * z), Vector3.ONE, GLOW, 6)
				_cone(rig, 0.025, 0.09, WHITE, H + Vector3(0.24, -0.15, 0.05 * z), Vector3(0, 0, 180), CLAY, 3)
				_seg(rig, 0.03, 0.02, body_c.darkened(0.3), Vector3(-0.2, -0.25, 0.1 * z), Vector3(-0.35, -0.4, 0.1 * z), k)
			if n.contains("ceniza"):
				for i in 4:
					_sph(rig, 0.04, FIRE, Vector3(-0.2 + i * 0.12, 0.3, 0.15 * (1 - 2 * (i % 2))), Vector3.ONE, GLOW, 4)
			if n.contains("desierto"):
				_cone(rig, 0.08, 0.3, c.darkened(0.2), H + Vector3(0.05, 0.35, 0), Vector3(0, 0, -20), CLAY, 4)
		"gargoyle":
			span = 1.05
			eye = FIRE_HOT if n.contains("infernal") else Color(1.0, 0.85, 0.3)
			var fake := {"col": c, "boss": o.get("boss", false), "frame": "small", "skin": c, "cloth": c.darkened(0.2), "head": "demon", "bare": true,
				"horns": c.darkened(0.4), "eye": eye, "tail": c, "claws": true}
			var g := _grp(rig, Vector3(0, -0.75, 0), Vector3(0, 0, -25))
			_humanoid_static(g, fake)
		"succubus", "demon":
			span = 1.1
			eye = FIRE_HOT if v == "demon" else Color(1.0, 0.4, 0.8)
			var fake := {"col": c, "boss": o.get("boss", false), "frame": "slim" if v == "succubus" else "small", "skin": c.lightened(0.15) if v == "succubus" else c,
				"cloth": Color(0.12, 0.05, 0.1), "head": "demon" if v == "demon" else "witch", "bare": v == "demon", "hair": Color(0.12, 0.05, 0.1),
				"long_hair": true, "horns": Color(0.15, 0.08, 0.08), "eye": eye, "tail": c, "claws": v == "demon", "rh": "pitchfork" if v == "demon" else ""}
			var g := _grp(rig, Vector3(0, -1.0 if v == "succubus" else -0.75, 0), Vector3(0, 0, -20))
			_humanoid_static(g, fake)
	for s in [-1.0, 1.0]:
		var w := _pivot(rig, "WingL" if s < 0 else "WingR", Vector3(-0.05, 0.15, 0.25 * s))
		var wc := Color(c.darkened(0.3), body_c.a) if v != "gargoyle" else c.darkened(0.15)
		_membrane_wing(w, s, wc.darkened(0.2), wc if v != "succubus" else Color(0.3, 0.05, 0.15), span, k)


## Construye un humanoide sin articulaciones (todo fijo) dentro de `g`: para jinetes y
## criaturas aladas en las que solo se mueven las alas.
static func _humanoid_static(g: Node3D, o: Dictionary) -> void:
	_humanoid(g, o)
	_flatten_pivots(g)


static func _flatten_pivots(n: Node) -> void:
	for ch in n.get_children():
		if ch.has_meta("pivot"):
			ch.remove_meta("pivot")
		_flatten_pivots(ch)


# ================================================================ Insectos voladores y hadas

static func _insect(rig: Node3D, o: Dictionary) -> void:
	var v: String = o.get("var", "moth")
	var c: Color = o["col"]
	var n: String = str(o.get("name", ""))
	match v:
		"moth", "butterfly":
			var crystal := n.contains("cristal")
			_sph(rig, 0.2, c.darkened(0.2), Vector3(0.15, 0, 0), Vector3(1.0, 1.0, 1.0), CLAY, 10)
			for i in 4:
				_sph(rig, 0.17 - i * 0.025, c.darkened(0.1 * (i % 2)), Vector3(-0.08 - i * 0.16, -0.03, 0), Vector3(1.0, 0.9, 0.9), CLAY, 8)
			_sph(rig, 0.16, c.lightened(0.1), Vector3(0.35, 0.05, 0), Vector3.ONE, CLAY, 10)
			for z in [-1.0, 1.0]:
				_sph(rig, 0.07, Color(0.9, 0.85, 0.3) if not crystal else ICE_GLOW, Vector3(0.45, 0.1, 0.09 * z), Vector3.ONE, GLOW, 6)
				_chain(rig, [Vector3(0.45, 0.18, 0.05 * z), Vector3(0.6, 0.45, 0.15 * z), Vector3(0.7, 0.55, 0.3 * z)], 0.015, 0.01, DARK)
				if not crystal:
					for k in 4:
						_seg(rig, 0.006, 0.006, DARK, Vector3(0.55 + k * 0.035, 0.32 + k * 0.06, (0.1 + k * 0.05) * z), Vector3(0.6 + k * 0.035, 0.3 + k * 0.06, (0.18 + k * 0.05) * z))
			for s in [-1.0, 1.0]:
				var w := _pivot(rig, "WingL" if s < 0 else "WingR", Vector3(0.1, 0.08, 0.1 * s))
				var wc := c if not crystal else Color(c, 0.65)
				var wk := CLAY if not crystal else GHOST
				_plate(w, [Vector2(0.15, 0), Vector2(-0.1, 0), Vector2(0.45, 0.8 * s), Vector2(0.0, 0.9 * s), Vector2(0.35, 0.55 * s)], 0.03, wc, Vector3.ZERO, Vector3.ZERO, wk)
				_plate(w, [Vector2(0.0, 0), Vector2(-0.3, 0.0), Vector2(-0.55, 0.55 * s), Vector2(-0.2, 0.65 * s)], 0.03, wc.darkened(0.12), Vector3(0, -0.01, 0), Vector3.ZERO, wk)
				# ocelos
				_cyl(w, 0.12, 0.12, 0.035, c.darkened(0.45) if not crystal else WHITE, Vector3(0.18, 0.005, 0.55 * s), Vector3.ZERO, CLAY if not crystal else GLOW, 10)
				_cyl(w, 0.06, 0.06, 0.04, Color(1.0, 0.85, 0.4) if not crystal else c, Vector3(0.18, 0.01, 0.55 * s), Vector3.ZERO, GLOW, 8)
				_cyl(w, 0.07, 0.07, 0.035, c.lightened(0.35), Vector3(-0.3, 0.005, 0.45 * s), Vector3.ZERO, CLAY if not crystal else GLOW, 8)
		"mosquito", "dragonfly":
			var df := v == "dragonfly"
			_sph(rig, 0.16, c, Vector3(0.1, 0, 0), Vector3(1.2, 1, 1), CLAY, 10)
			_chain(rig, [Vector3(0.0, 0, 0), Vector3(-0.4, -0.05, 0), Vector3(-0.9 if df else -0.6, -0.1 if df else -0.2, 0)], 0.1 if not df else 0.07, 0.05 if not df else 0.03, c.lightened(0.1) if df else c.darkened(0.1))
			if not df:
				for i in 3:
					_sph(rig, 0.11, Color(0.9, 0.9, 0.85), Vector3(-0.15 - i * 0.15, -0.06 - i * 0.04, 0), Vector3(0.3, 1.0, 1.0), CLAY, 8)
			else:
				for i in 4:
					_sph(rig, 0.075, c.lightened(0.35), Vector3(-0.2 - i * 0.17, -0.05 - i * 0.012, 0), Vector3(0.3, 1, 1), GLOW, 6)
			_sph(rig, 0.12, c.darkened(0.1), Vector3(0.32, 0.03, 0), Vector3.ONE, CLAY, 8)
			for z in [-1.0, 1.0]:
				_sph(rig, 0.07 if not df else 0.09, RED_GLOW if not df else Color(0.3, 1.0, 0.8), Vector3(0.38, 0.07, 0.07 * z), Vector3.ONE, GLOW, 6)
				for k in 3:
					var a := Vector3(0.1 - k * 0.1, -0.1, 0.06 * z)
					_chain(rig, [a, a + Vector3(0.05, -0.15, 0.2 * z), a + Vector3(0.0 - k * 0.1, -0.5, 0.3 * z)], 0.012, 0.008, DARK)
			if not df:
				_seg(rig, 0.012, 0.005, DARK, Vector3(0.42, 0.0, 0), Vector3(0.8, -0.2, 0))
			for s in [-1.0, 1.0]:
				var w := _pivot(rig, "WingL" if s < 0 else "WingR", Vector3(0.08, 0.1, 0.06 * s))
				var wc := Color(0.85, 0.95, 1.0, 0.45)
				_plate(w, [Vector2(0.06, 0), Vector2(-0.06, 0), Vector2(0.05, 0.8 * s), Vector2(-0.12, 0.75 * s)], 0.02, wc, Vector3.ZERO, Vector3(0, 10 * s, 0), GHOST)
				if df:
					_plate(w, [Vector2(-0.12, 0), Vector2(-0.22, 0), Vector2(-0.15, 0.75 * s), Vector2(-0.32, 0.7 * s)], 0.02, wc, Vector3.ZERO, Vector3(0, -10 * s, 0), GHOST)
		"fairy":
			var crystal := n.contains("cristal")
			var dark := n.contains("oscura") or n.contains("maligna")
			var fake := {"col": c, "boss": o.get("boss", false), "frame": "slim", "skin": Color(0.95, 0.85, 0.8).lerp(c, 0.25), "cloth": c, "cloth2": c.lightened(0.2),
				"head": "elf", "hair": c.lightened(0.3) if not dark else Color(0.2, 0.1, 0.25), "long_hair": true, "robe": true,
				"eye": Color(1.0, 0.4, 0.9) if dark else Color(0.5, 0.9, 1.0), "rh": "orb_staff" if not n.contains("pixie") else "", "item_col": c.lightened(0.4)}
			var g := _grp(rig, Vector3(0, -0.65, 0), Vector3.ZERO, Vector3.ONE * 0.6)
			_humanoid_static(g, fake)
			_sph(rig, 0.25, Color(c.lightened(0.4), 0.3), Vector3(0, 0.0, 0), Vector3.ONE, GHOST, 10)
			for i in 5:
				var a := TAU * i / 5.0
				_sph(rig, 0.04, c.lightened(0.5), Vector3(cos(a) * 0.4, -0.3 + i * 0.12, sin(a) * 0.4), Vector3.ONE, GLOW, 4)
			for s in [-1.0, 1.0]:
				var w := _pivot(rig, "WingL" if s < 0 else "WingR", Vector3(-0.12, 0.25, 0.06 * s), Vector3(0, 0, 60))
				var wc := Color(c.lightened(0.45), 0.55) if not dark else Color(0.25, 0.1, 0.3, 0.7)
				_plate(w, [Vector2(0.1, 0), Vector2(-0.05, 0), Vector2(0.35, 0.6 * s), Vector2(0.0, 0.7 * s)], 0.02, wc, Vector3.ZERO, Vector3.ZERO, GHOST)
				_plate(w, [Vector2(0.0, 0), Vector2(-0.12, 0.0), Vector2(-0.35, 0.45 * s), Vector2(-0.1, 0.5 * s)], 0.02, wc, Vector3(0, -0.01, 0), Vector3.ZERO, GHOST)
				if crystal:
					_cone(w, 0.04, 0.3, ICE_GLOW, Vector3(0.15, 0, 0.5 * s), Vector3(90 * s, 0, 0), GLOW, 4)


## Enjambre: cinco bichos pequeños que revolotean cada uno a su ritmo
static func _swarm(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	var n: String = str(o.get("name", ""))
	var bird := n.contains("gorrion")
	var spots := [Vector3(0.3, 0.1, 0), Vector3(-0.1, 0.35, 0.35), Vector3(-0.15, -0.2, -0.4), Vector3(-0.45, 0.2, -0.05), Vector3(0.05, -0.3, 0.3)]
	for i in spots.size():
		var p := _pivot(rig, "Bug%d" % i, spots[i], Vector3(0, i * 25.0 - 50.0, 0), [_tr(POS, 1, 0.12, 7.0 + i * 1.3, i * 1.7, false)])
		var s := 0.55 + 0.12 * (i % 3)
		if bird:
			_sph(p, 0.17 * s, c, Vector3.ZERO, Vector3(1.3, 0.9, 0.9), CLAY, 8)
			_sph(p, 0.11 * s, c.lightened(0.15), Vector3(0.18 * s, 0.07 * s, 0), Vector3.ONE, CLAY, 8)
			_cone(p, 0.04 * s, 0.1 * s, Color(0.95, 0.75, 0.2), Vector3(0.3 * s, 0.06 * s, 0), Vector3(0, 0, -90), CLAY, 4)
			_sph(p, 0.03 * s, Color(0.4, 0.8, 1.0), Vector3(0.24 * s, 0.1 * s, 0.07 * s), Vector3.ONE, GLOW, 4)
			for z in [-1.0, 1.0]:
				_plate(p, [Vector2(0.05, 0), Vector2(-0.1, 0), Vector2(-0.15, 0.4 * z), Vector2(0.05, 0.3 * z)], 0.02 * s, c.darkened(0.2), Vector3(0, 0.05, 0), Vector3(-25 * z, 0, 0))
			_box(p, Vector3(0.2 * s, 0.02, 0.1 * s), c.darkened(0.3), Vector3(-0.2 * s, 0, 0))
		else:
			var stripe := DARK
			var body := c
			_sph(p, 0.12 * s, body, Vector3(0.1 * s, 0, 0), Vector3.ONE, CLAY, 8)
			_sph(p, 0.18 * s, body, Vector3(-0.15 * s, -0.02, 0), Vector3(1.3, 0.9, 0.9), CLAY, 8)
			if n.contains("avispa"):
				for k in 2:
					_sph(p, 0.181 * s, stripe, Vector3((-0.12 - k * 0.12) * s, -0.02, 0), Vector3(0.25, 0.9, 0.92), CLAY, 8)
				_cone(p, 0.04 * s, 0.14 * s, DARK, Vector3(-0.42 * s, -0.04, 0), Vector3(0, 0, 90), CLAY, 4)
			elif n.contains("langosta"):
				for z in [-1.0, 1.0]:
					_seg(p, 0.025 * s, 0.015 * s, c.darkened(0.3), Vector3(-0.05 * s, -0.05 * s, 0.05 * z * s), Vector3(-0.35 * s, 0.12 * s, 0.12 * z * s))
			_sph(p, 0.04 * s, RED_GLOW if not n.contains("caos") else Color(1.0, 0.3, 0.7), Vector3(0.18 * s, 0.03 * s, 0.05 * s), Vector3.ONE, GLOW, 4)
			for z in [-1.0, 1.0]:
				_plate(p, [Vector2(0.05, 0), Vector2(-0.08, 0), Vector2(-0.05, 0.35 * z), Vector2(0.1, 0.3 * z)], 0.015, Color(0.9, 0.95, 1.0, 0.5), Vector3(-0.05 * s, 0.1 * s, 0), Vector3(-30 * z, 0, 0) * 1.0, GHOST)


## Raya abisal: cuerpo plano con aletas-ala y cola de látigo
static func _ray(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	_sph(rig, 0.45, c, Vector3.ZERO, Vector3(1.3, 0.35, 0.9), CLAY, 14)
	_sph(rig, 0.35, c.lightened(0.15), Vector3(0.05, -0.06, 0), Vector3(1.2, 0.3, 0.8), CLAY, 12)
	for z in [-1.0, 1.0]:
		_sph(rig, 0.07, PURPLE_GLOW, Vector3(0.5, 0.06, 0.15 * z), Vector3.ONE, GLOW, 6)
		_cone(rig, 0.06, 0.25, c.darkened(0.2), Vector3(0.62, 0, 0.18 * z), Vector3(0, 0, -90), CLAY, 4)
	for i in 4:
		_sph(rig, 0.04, PURPLE_GLOW, Vector3(-0.15 - i * 0.1, 0.13, 0.15 * (1 - 2 * (i % 2))), Vector3.ONE, GLOW, 4)
	var tail := _pivot(rig, "Tail", Vector3(-0.5, 0, 0), Vector3.ZERO, [_tr(ROT, 1, 0.3, 3.0, 0.0, false)])
	_chain(tail, [Vector3.ZERO, Vector3(-0.4, 0.05, 0), Vector3(-0.8, -0.05, 0.1), Vector3(-1.2, 0.0, -0.05)], 0.06, 0.015, c.darkened(0.2))
	_cone(tail, 0.05, 0.2, PURPLE_GLOW, Vector3(-1.25, 0.0, -0.05), Vector3(0, 0, 90), GLOW, 4)
	for s in [-1.0, 1.0]:
		var w := _pivot(rig, "WingL" if s < 0 else "WingR", Vector3(0, 0, 0.3 * s))
		_plate(w, [Vector2(0.4, 0), Vector2(-0.4, 0), Vector2(-0.1, 0.85 * s), Vector2(0.1, 0.8 * s)], 0.06, c, Vector3.ZERO, Vector3.ZERO, CLAY)
		_sph(w, 0.05, PURPLE_GLOW, Vector3(0.0, 0.04, 0.5 * s), Vector3(1.5, 0.4, 1), GLOW, 6)


# ================================================================ Dragones

static func _dragon_palette(o: Dictionary) -> Dictionary:
	var c: Color = o["col"]
	var n: String = str(o.get("name", ""))
	var p := {"body": c, "belly": c.lightened(0.3).lerp(Color(0.95, 0.85, 0.6), 0.3), "horn": Color(0.95, 0.9, 0.78),
		"spike": c.darkened(0.35), "eye": FIRE_HOT, "wing": c.darkened(0.15), "membrane": c.darkened(0.3), "glow": Color(0, 0, 0, 0),
		"k_body": CLAY, "k_wing": CLAY, "bone": false, "crystal": false, "armored": false}
	if o.get("ice", false) or n.contains("blanco") or n.contains("hielo") or n.contains("glacial") or n.contains("escarcha") or n.contains("helado") or n.contains("imperial"):
		p.merge({"eye": ICE_GLOW, "spike": Color(0.75, 0.9, 1.0), "horn": Color(0.85, 0.95, 1.0), "glow": ICE_GLOW, "membrane": c.lightened(0.1).lerp(ICE, 0.4)}, true)
	if n.contains("magma") or n.contains("infernal") or n.contains("fuego") or n.contains("abismo"):
		p.merge({"glow": FIRE, "eye": FIRE_HOT, "horn": Color(0.15, 0.1, 0.1), "spike": Color(0.15, 0.1, 0.1)}, true)
		if n.contains("magma"):
			p.merge({"body": Color(0.22, 0.14, 0.12), "membrane": Color(0.4, 0.12, 0.05), "belly": Color(0.35, 0.18, 0.12)}, true)
	if n.contains("oseo") or n.contains("dracoliche"):
		p.merge({"body": BONE, "belly": BONE.darkened(0.1), "eye": GREEN_GLOW, "horn": BONE.darkened(0.2), "spike": BONE.darkened(0.25),
			"membrane": Color(c.darkened(0.2), 0.55), "k_wing": GHOST, "bone": true, "glow": GREEN_GLOW}, true)
	if n.contains("cristal"):
		p.merge({"crystal": true, "glow": c.lightened(0.3), "spike": c.lightened(0.35), "eye": c.lightened(0.4), "membrane": Color(c.lightened(0.2), 0.6), "k_wing": GHOST}, true)
	if n.contains("acorazado"):
		p["armored"] = true
	if n.contains("tormenta"):
		p.merge({"glow": Color(0.7, 0.85, 1.0), "eye": Color(0.8, 0.95, 1.0), "spike": Color(0.95, 0.85, 0.3)}, true)
	if n.contains("feerico"):
		p.merge({"membrane": Color(1.0, 0.75, 0.95, 0.6), "k_wing": GHOST, "glow": Color(1.0, 0.7, 1.0), "eye": Color(0.6, 1.0, 1.0)}, true)
	if n.contains("caos") or n.contains("leviatan"):
		p.merge({"glow": Color(1.0, 0.3, 0.7) if n.contains("caos") else PURPLE_GLOW, "eye": Color(1.0, 0.4, 0.8) if n.contains("caos") else PURPLE_GLOW}, true)
	if n.contains("pantano") or n.contains("bosque"):
		p.merge({"horn": Color(0.4, 0.35, 0.25), "eye": Color(0.9, 1.0, 0.3)}, true)
	if n.contains("piedra"):
		p.merge({"body": c, "spike": c.darkened(0.3), "eye": Color(1.0, 0.75, 0.3)}, true)
	return p


static func _dragon(rig: Node3D, o: Dictionary) -> void:
	var v: String = o.get("var", "dragon")
	var p := _dragon_palette(o)
	var c: Color = p["body"]
	var belly: Color = p["belly"]
	var kb: int = p["k_body"]
	var bone: bool = p["bone"]
	var ground: bool = not o.get("fly", false)
	var big: bool = o.get("boss", false) or o.get("grand", false)
	var holder := rig
	if ground:
		holder = _grp(rig, Vector3(0, 0.75, 0))
	if v == "wyrm":
		_wyrm(holder, o, p)
		return
	# --- Cuerpo
	if bone:
		_seg(holder, 0.1, 0.08, c, Vector3(-0.6, 0.05, 0), Vector3(0.55, 0.15, 0))
		for i in 5:
			var x := 0.35 - i * 0.18
			for z in [-1.0, 1.0]:
				_chain(holder, [Vector3(x, 0.12, 0), Vector3(x - 0.02, 0.0, 0.32 * z), Vector3(x - 0.05, -0.3, 0.18 * z)], 0.04, 0.03, c)
		_sph(holder, 0.32, Color(GREEN_GLOW, 0.45), Vector3(0.05, -0.05, 0), Vector3(1.3, 0.9, 0.9), GHOST, 10)
		_sph(holder, 0.25, c, Vector3(-0.55, -0.05, 0), Vector3(1, 0.6, 1), CLAY, 10)
	else:
		_sph(holder, 0.45, c, Vector3(0, 0, 0), Vector3(1.45, 0.85, 0.85), kb, 14)
		_sph(holder, 0.38, belly, Vector3(0.08, -0.14, 0), Vector3(1.4, 0.7, 0.8), kb, 12)
		for i in 5:  # placas del vientre
			_box(holder, Vector3(0.05, 0.03, 0.42), belly.darkened(0.12), Vector3(0.35 - i * 0.17, -0.38 + absf(i - 2.0) * 0.02, 0), Vector3(0, 0, 0))
	if v == "chimera":
		_sph(holder, 0.32, Color(0.85, 0.6, 0.25), Vector3(0.4, 0.15, 0), Vector3(1.1, 1.15, 1.1), CLAY, 12)  # melena
	for i in 6:  # púas dorsales
		var x := 0.5 - i * 0.2
		var s := 1.0 - absf(i - 2.0) * 0.15
		_cone(holder, 0.08 * s, 0.28 * s, p["spike"], Vector3(x, 0.38 - absf(i - 2.0) * 0.03, 0), Vector3(0, 0, 20), METAL if p["crystal"] else CLAY, 4)
	var glow: Color = p["glow"]
	if glow.a > 0.0 and not bone:
		for i in 4:  # grietas / escamas brillantes en los flancos
			for z in [-1.0, 1.0]:
				_box(holder, Vector3(0.18, 0.03, 0.03), glow, Vector3(0.3 - i * 0.22, 0.05 - (i % 2) * 0.08, 0.36 * z), Vector3(0, 0, 30 - 60 * (i % 2)), GLOW)
	if p["armored"]:
		_sph(holder, 0.46, Color(0.4, 0.38, 0.42), Vector3(0.0, 0.08, 0), Vector3(1.4, 0.7, 0.88), METAL, 12)
		for i in 4:
			_box(holder, Vector3(0.05, 0.06, 0.82), GOLD if big else Color(0.3, 0.28, 0.3), Vector3(0.4 - i * 0.25, 0.3, 0), Vector3(0, 0, -10), METAL)
	if p["crystal"]:
		for i in 5:
			var a := i * 1.3
			_cone(holder, 0.07, 0.35, glow, Vector3(0.3 - i * 0.18, 0.3, sin(a) * 0.2), Vector3(rad_to_deg(sin(a)) * 0.5, 0, 15), GLOW, 5)
	# --- Patas
	var legs := 4 if v not in ["wyvern"] else 2
	for i in legs:
		var front := i < 2 and legs == 4
		var z := -1.0 if i % 2 == 0 else 1.0
		var hx := 0.42 if front else -0.35
		var hip := Vector3(hx, -0.15, 0.28 * z)
		var foot: Vector3
		if ground:
			foot = Vector3(hx + 0.08, -0.73, 0.32 * z)
		else:
			foot = Vector3(hx - 0.25, -0.5, 0.22 * z)
		var lp := _pivot(holder, ["LegFL", "LegFR", "LegBL", "LegBR"][i if legs == 4 else i + 2], hip, Vector3.ZERO,
				[_tr(ROT, 2, 0.4 if ground else 0.1, WALK if ground else 3.0, (0.0 if (front == (z < 0)) else PI), ground)])
		var knee := (foot - hip) * 0.5 + Vector3(0.12 if not front else -0.06, 0.05, 0)
		_sph(lp, 0.16 if not bone else 0.08, c, Vector3.ZERO, Vector3(1.2, 1.3, 1), kb, 8)
		_chain(lp, [Vector3.ZERO, knee, foot - hip], 0.12 if not bone else 0.05, 0.07 if not bone else 0.04, c, kb)
		for k in 3:
			_cone(lp, 0.03, 0.13, p["horn"], foot - hip + Vector3(0.08, -0.03, (k - 1) * 0.06), Vector3(0, 0, -100), CLAY, 3)
	# --- Cola
	var tail := _pivot(holder, "Tail", Vector3(-0.6, 0.0, 0), Vector3.ZERO, [_tr(ROT, 1, 0.3, 2.5, 0.0, false)])
	var tpts := [Vector3.ZERO, Vector3(-0.4, -0.05, 0), Vector3(-0.8, 0.0, 0.1), Vector3(-1.15, 0.1, -0.05), Vector3(-1.45, 0.15, 0.0)]
	if v == "chimera":
		# cola de serpiente con cabeza
		_chain(tail, tpts, 0.12, 0.06, Color(0.3, 0.5, 0.25))
		_sph(tail, 0.1, Color(0.3, 0.5, 0.25), Vector3(-1.5, 0.2, 0), Vector3(1.4, 0.8, 0.9), CLAY, 8)
		for z in [-1.0, 1.0]:
			_sph(tail, 0.025, FIRE_HOT, Vector3(-1.45, 0.26, 0.05 * z), Vector3.ONE, GLOW, 4)
	else:
		_chain(tail, tpts, 0.2 if not bone else 0.06, 0.04, c, kb)
		if bone:
			for i in 6:
				_sph(tail, 0.06, c, (tpts[mini(i, 4)] as Vector3).lerp(tpts[mini(i + 1, 4)], 0.5), Vector3.ONE, CLAY, 6)
		for i in 3:
			_cone(tail, 0.06, 0.18, p["spike"], (tpts[i + 1] as Vector3) + Vector3(0, 0.12, 0), Vector3(0, 0, 25), CLAY, 4)
		_plate(tail, [Vector2(0, -0.15), Vector2(0, 0.15), Vector2(-0.35, 0)], 0.05, p["spike"] if glow.a <= 0.0 else glow, Vector3(-1.45, 0.15, 0), Vector3(90, 0, 0), CLAY if glow.a <= 0.0 else GLOW)
	# --- Cuello y cabeza
	var neck := _pivot(holder, "Head", Vector3(0.55, 0.12, 0), Vector3.ZERO, [_tr(ROT, 1, 0.15, 2.0, 0.5, false)])
	var npts := [Vector3.ZERO, Vector3(0.22, 0.2, 0), Vector3(0.4, 0.38, 0), Vector3(0.55, 0.45, 0)]
	_chain(neck, npts, 0.2 if not bone else 0.06, 0.15 if not bone else 0.05, c, kb)
	if bone:
		for i in 3:
			_sph(neck, 0.07, c, (npts[i] as Vector3).lerp(npts[i + 1], 0.5), Vector3.ONE, CLAY, 6)
	if v == "chimera":
		_lion_head(neck, Vector3(0.65, 0.45, 0), Color(0.85, 0.6, 0.25))
		# cabeza de cabra sobre el lomo
		_sph(holder, 0.14, Color(0.85, 0.82, 0.75), Vector3(0.05, 0.55, 0.15), Vector3(1.3, 1, 0.9), CLAY, 8)
		for z in [-1.0, 1.0]:
			_horn(holder, Vector3(0.0, 0.65, 0.15 + 0.07 * z), Vector3(-1, 0.5, 0.2 * z), Vector3(0, -1, 0), 0.3, 0.04, Color(0.4, 0.35, 0.3))
		_sph(holder, 0.03, RED_GLOW, Vector3(0.14, 0.6, 0.22), Vector3.ONE, GLOW, 4)
	else:
		_dragon_head(neck, Vector3(0.62, 0.48, 0), p, big, o)
	# --- Alas
	var span := 1.35 if v != "wyvern" else 1.5
	if big:
		span *= 1.1
	for s in [-1.0, 1.0]:
		var nm := ("WingL" if s < 0 else "WingR") if not ground else ("FoldL" if s < 0 else "FoldR")
		var w := _pivot(holder, nm, Vector3(0.12, 0.25, 0.22 * s), Vector3(0, 0, 0) if not ground else Vector3(55 * s, 0, 0))
		_membrane_wing(w, s, p["spike"] if bone else c.darkened(0.15), p["membrane"], span, p["k_wing"])


static func _dragon_head(g: Node3D, H: Vector3, p: Dictionary, big: bool, o: Dictionary) -> void:
	var c: Color = p["body"]
	var kb: int = p["k_body"]
	_sph(g, 0.22, c, H, Vector3(1.2, 0.9, 0.95), kb, 12)
	_box(g, Vector3(0.36, 0.16, 0.26), c, H + Vector3(0.27, -0.03, 0), Vector3(0, 0, -6), kb)  # hocico
	_box(g, Vector3(0.34, 0.07, 0.24), p["belly"], H + Vector3(0.25, -0.14, 0), Vector3(0, 0, 8), kb)  # mandíbula
	for z in [-1.0, 1.0]:
		_sph(g, 0.05, p["eye"], H + Vector3(0.1, 0.09, 0.15 * z), Vector3(0.7, 0.8, 1), GLOW, 6)
		_box(g, Vector3(0.14, 0.04, 0.06), c.darkened(0.3), H + Vector3(0.1, 0.15, 0.14 * z), Vector3(-15 * z, 0, -15))
		_horn(g, H + Vector3(-0.08, 0.12, 0.1 * z), Vector3(-1, 0.6, 0.25 * z), Vector3(0.2, 0.5, 0), 0.4 if not big else 0.55, 0.05 if not big else 0.07, p["horn"])
		_sph(g, 0.02, DARK, H + Vector3(0.44, 0.03, 0.06 * z), Vector3.ONE, CLAY, 4)
		for k in 3:
			_cone(g, 0.02, 0.06, WHITE, H + Vector3(0.18 + k * 0.08, -0.1, 0.11 * z), Vector3(0, 0, 180), CLAY, 3)
		_cone(g, 0.04, 0.16, p["spike"], H + Vector3(0.0, -0.08, 0.17 * z), Vector3(0, 0, 110), CLAY, 4)
	if p["glow"] != Color(0, 0, 0, 0) and (o.get("fire", false) or str(str(o.get("name", ""))).contains("fuego")):
		_sph(g, 0.05, FIRE_HOT, H + Vector3(0.45, -0.1, 0), Vector3(1, 0.6, 1.4), GLOW, 6)
	if o.get("boss", false) or o.get("crowned", false):
		_crown(g, H + Vector3(-0.05, 0.2, 0), 0.4)


static func _lion_head(g: Node3D, H: Vector3, c: Color) -> void:
	for i in 10:
		var a := TAU * i / 10.0
		_cone(g, 0.1, 0.3, c.darkened(0.25), H + Vector3(-0.05, sin(a) * 0.15, cos(a) * 0.15), Vector3(rad_to_deg(cos(a)) * 0.0 + 90.0 * cos(a), 0, 90 + 60 * sin(a)), CLAY, 4)
	_sph(g, 0.2, c, H, Vector3(1.0, 1.0, 1.0), CLAY, 12)
	_sph(g, 0.11, c.lightened(0.2), H + Vector3(0.17, -0.06, 0), Vector3(1, 0.8, 1.1), CLAY, 8)
	_sph(g, 0.04, DARK, H + Vector3(0.27, -0.02, 0), Vector3.ONE, CLAY, 4)
	for z in [-1.0, 1.0]:
		_eye(g, H + Vector3(0.14, 0.07, 0.09 * z), 0.04, FIRE_HOT)
		_cone(g, 0.02, 0.08, WHITE, H + Vector3(0.22, -0.13, 0.05 * z), Vector3(0, 0, 180), CLAY, 3)


## Wyrm / leviatán: cuerpo de serpiente ondulante con alas pequeñas y crestas
static func _wyrm(rig: Node3D, o: Dictionary, p: Dictionary) -> void:
	var c: Color = p["body"]
	var big: bool = o.get("boss", false) or o.get("grand", false)
	var pts: Array = []
	for i in 8:
		pts.append(Vector3(0.6 - i * 0.28, sin(i * 0.9) * 0.15, cos(i * 0.9) * 0.25))
	for i in pts.size():
		var r := 0.26 - i * 0.025
		_sph(rig, r, c, pts[i], Vector3(1.2, 1, 1), p["k_body"], 10)
		_sph(rig, r * 0.85, p["belly"], (pts[i] as Vector3) + Vector3(0, -r * 0.35, 0), Vector3(1.1, 0.6, 0.9), CLAY, 8)
		_cone(rig, r * 0.35, r * 1.1, p["spike"], (pts[i] as Vector3) + Vector3(0, r * 1.0, 0), Vector3(0, 0, 25), CLAY, 4)
		var glow: Color = p["glow"]
		if glow.a > 0.0 and i % 2 == 0:
			for z in [-1.0, 1.0]:
				_sph(rig, r * 0.18, glow, (pts[i] as Vector3) + Vector3(0, 0, r * 0.95 * z), Vector3.ONE, GLOW, 4)
	_chain(rig, pts, 0.24, 0.08, c, p["k_body"], false)
	var tail := _pivot(rig, "Tail", pts[7], Vector3.ZERO, [_tr(ROT, 1, 0.4, 2.5, 0.0, false)])
	_chain(tail, [Vector3.ZERO, Vector3(-0.3, 0.1, -0.1), Vector3(-0.6, 0.05, 0.1)], 0.07, 0.02, c)
	_plate(tail, [Vector2(0, -0.12), Vector2(0, 0.12), Vector2(-0.3, 0)], 0.04, p["spike"], Vector3(-0.6, 0.05, 0.1), Vector3(90, 0, 0))
	var neck := _pivot(rig, "Head", Vector3(0.65, 0.05, 0), Vector3.ZERO, [_tr(ROT, 1, 0.2, 2.0, 0.0, false)])
	_chain(neck, [Vector3.ZERO, Vector3(0.2, 0.2, 0), Vector3(0.3, 0.38, 0)], 0.22, 0.17, c)
	_dragon_head(neck, Vector3(0.38, 0.42, 0), p, big, o)
	# barbas y aletas
	for z in [-1.0, 1.0]:
		_chain(neck, [Vector3(0.62, 0.32, 0.08 * z), Vector3(0.75, 0.15, 0.15 * z), Vector3(0.7, -0.05, 0.2 * z)], 0.025, 0.01, p["spike"])
	var span := 0.95 if not big else 1.15
	for s in [-1.0, 1.0]:
		var w := _pivot(rig, ("WingL" if s < 0 else "WingR") if o.get("fly", false) else ("FoldL" if s < 0 else "FoldR"), Vector3(0.35, 0.15, 0.2 * s))
		_membrane_wing(w, s, c.darkened(0.15), p["membrane"], span, p["k_wing"])


# ================================================================ Hidra (no vuela)

static func _hydra(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	var belly := c.lightened(0.3)
	_sph(rig, 0.6, c, Vector3(-0.1, 0.75, 0), Vector3(1.35, 0.85, 1.0), CLAY, 14)
	_sph(rig, 0.5, belly, Vector3(0.0, 0.58, 0), Vector3(1.3, 0.6, 0.9), CLAY, 12)
	for i in 5:
		_cone(rig, 0.1, 0.32, c.darkened(0.35), Vector3(0.3 - i * 0.22, 1.22, 0), Vector3(0, 0, 20), CLAY, 4)
	for i in 4:  # patas cortas (fijas: la hidra se arrastra)
		var z := -1.0 if i % 2 == 0 else 1.0
		var x := 0.35 if i < 2 else -0.5
		_seg(rig, 0.18, 0.15, c, Vector3(x, 0.55, 0.45 * z), Vector3(x + 0.05, 0.1, 0.55 * z))
		_sph(rig, 0.18, c.darkened(0.1), Vector3(x + 0.1, 0.08, 0.55 * z), Vector3(1.3, 0.6, 1.1), CLAY, 8)
		for k in 3:
			_cone(rig, 0.03, 0.12, BONE, Vector3(x + 0.28, 0.05, 0.55 * z + (k - 1) * 0.08), Vector3(0, 0, -100), CLAY, 3)
	var tail := _pivot(rig, "Tail", Vector3(-0.85, 0.7, 0), Vector3.ZERO, [_tr(ROT, 1, 0.3, WALK * 0.4, 0.0, false)])
	_chain(tail, [Vector3.ZERO, Vector3(-0.4, -0.3, 0), Vector3(-0.8, -0.5, 0.15), Vector3(-1.1, -0.55, -0.1)], 0.22, 0.04, c)
	var p := {"body": c, "belly": belly, "horn": Color(0.4, 0.35, 0.25), "spike": c.darkened(0.35), "eye": Color(0.9, 1.0, 0.3), "k_body": CLAY, "glow": Color(0, 0, 0, 0)}
	var bases := [Vector3(0.45, 1.0, -0.35), Vector3(0.6, 1.05, 0), Vector3(0.45, 1.0, 0.35)]
	for i in 3:
		var nk := _pivot(rig, "Neck%d" % i, bases[i], Vector3(0, (1 - i) * 25.0, 0), [_tr(ROT, 2, 0.18, 2.2 + i * 0.4, i * 2.0, false)])
		var L := 0.9 if i == 1 else 0.75
		var npts := [Vector3.ZERO, Vector3(0.15, L * 0.45, 0), Vector3(0.3, L * 0.85, 0), Vector3(0.45, L, 0)]
		_chain(nk, npts, 0.2, 0.13, c)
		for k in 3:
			_cone(nk, 0.05, 0.16, c.darkened(0.35), (npts[k] as Vector3).lerp(npts[k + 1], 0.5) + Vector3(-0.12, 0.05, 0), Vector3(0, 0, 60), CLAY, 4)
		_dragon_head(nk, Vector3(0.5, L + 0.03, 0), p, o.get("boss", false) and i == 1, o)


# ================================================================ Gólems y árboles

static func _golem(rig: Node3D, o: Dictionary) -> void:
	var v: String = o.get("var", "stone")
	var c: Color = o["col"]
	var n: String = str(o.get("name", ""))
	var big: bool = o.get("boss", false) or o.get("grand", false)
	var k := CLAY
	var rock := c
	var accent := Color(1.0, 0.75, 0.25)
	var eye := Color(1.0, 0.75, 0.25)
	match v:
		"ice":
			k = METAL
			accent = ICE_GLOW
			eye = ICE_GLOW
		"magma":
			rock = c.darkened(0.2)
			accent = FIRE
			eye = FIRE_HOT
		"crystal":
			k = METAL
			accent = c.lightened(0.35)
			eye = c.lightened(0.5)
		"rune", "marble":
			accent = Color(0.45, 0.8, 1.0)
			eye = accent
			if v == "marble":
				accent = GOLD
		"obsidian":
			rock = c.darkened(0.3)
			accent = FIRE if not n.contains("caos") and not n.contains("retorcido") else Color(1.0, 0.3, 0.7)
			eye = accent
			k = METAL
		"void":
			rock = c
			accent = PURPLE_GLOW
			eye = PURPLE_GLOW
			k = METAL
		"mud":
			accent = Color(0.55, 0.65, 0.25)
			eye = Color(0.9, 1.0, 0.4)
		"bone":
			rock = BONE
			accent = GREEN_GLOW
			eye = GREEN_GLOW
		"island":
			rock = Color(0.5, 0.45, 0.4)
			accent = Color(0.5, 0.85, 1.0)
			eye = accent
		"stone":
			if n.contains("granito"):
				rock = c
			if n.contains("arenisca"):
				accent = Color(0.3, 0.6, 1.0)
				eye = accent
	if v == "tower":
		_siege_tower(rig, o)
		return
	var dark := rock.darkened(0.3)
	# --- Torso: rocas apiladas
	var tw := 0.62
	_box(rig, Vector3(0.9, 0.85, 1.3), rock, Vector3(0, 1.35, 0), Vector3(0, 0, -6), k)
	_box(rig, Vector3(0.7, 0.5, 0.9), rock.darkened(0.08), Vector3(-0.02, 0.85, 0), Vector3(0, 0, 4), k)
	_sph(rig, 0.3, rock.lightened(0.05), Vector3(0.1, 1.55, 0.35), Vector3(1, 0.8, 1), k, 8)
	_sph(rig, 0.28, rock.darkened(0.05), Vector3(-0.15, 1.5, -0.35), Vector3(1, 0.9, 1), k, 8)
	if v == "bone":
		for i in 4:
			_sph(rig, 1.0, BONE.darkened(0.08 * (i % 2)), Vector3(0.3, 1.1 + i * 0.17, 0), Vector3(0.18, 0.05, 0.6), CLAY, 8)
		for i in 6:
			var a := i * 1.1
			_sph(rig, 0.13, BONE, Vector3(cos(a) * 0.4, 1.0 + (i % 3) * 0.3, sin(a) * 0.6), Vector3.ONE, CLAY, 8)
	# núcleo / grietas
	if v in ["magma", "rune", "crystal", "ice", "obsidian", "void", "island", "marble"] or big:
		_sph(rig, 0.18, accent, Vector3(0.44, 1.35, 0), Vector3(0.5, 1, 1), GLOW, 8)
		for i in 4:
			_box(rig, Vector3(0.03, 0.3, 0.04), accent, Vector3(0.46, 1.1 + (i % 2) * 0.4, -0.4 + i * 0.27), Vector3(25 - 50 * (i % 2), 0, 0), GLOW)
	if v == "rune" or v == "marble":
		for i in 3:
			_box(rig, Vector3(0.03, 0.12, 0.12), accent, Vector3(0.46, 1.55, -0.3 + i * 0.3), Vector3(45, 0, 0), GLOW)
	if v == "mud":
		for i in 6:
			_cone(rig, 0.07, 0.25, rock.darkened(0.15), Vector3(0.3 - (i % 3) * 0.3, 0.8, -0.5 + i * 0.2), Vector3(0, 0, 180), CLAY, 5)
		for i in 3:
			_sph(rig, 0.12, Color(0.35, 0.5, 0.2), Vector3(0.2 - i * 0.2, 1.8, 0.3 - i * 0.3), Vector3(1.2, 0.5, 1), CLAY, 6)
	if v == "island":
		_cyl(rig, 0.75, 0.7, 0.18, Color(0.35, 0.6, 0.25), Vector3(0, 1.85, 0), Vector3.ZERO, CLAY, 10)
		for i in 3:
			var a := i * 2.1
			var tp := Vector3(cos(a) * 0.4, 1.95, sin(a) * 0.45)
			_cyl(rig, 0.04, 0.06, 0.35, WOOD, tp + Vector3(0, 0.15, 0), Vector3.ZERO, CLAY, 6)
			_cone(rig, 0.22, 0.5, Color(0.25, 0.5, 0.25), tp + Vector3(0, 0.5, 0), Vector3.ZERO, CLAY, 7)
		_box(rig, Vector3(0.25, 0.22, 0.25), Color(0.9, 0.85, 0.75), Vector3(0.1, 2.05, 0.05))
		_roof_cone(rig, Vector3(0.1, 2.25, 0.05), 0.24, Color(0.75, 0.25, 0.2))
		for i in 4:
			_cone(rig, 0.1, 0.35, rock.darkened(0.2), Vector3(0.3 - i * 0.2, 0.55, -0.3 + i * 0.2), Vector3(0, 0, 180), CLAY, 5)
	# cristales / carámbanos / cuernos
	match v:
		"ice", "crystal":
			for i in 6:
				var a := i * 1.05
				var hgt := 0.4 + 0.2 * (i % 3)
				_cone(rig, 0.1, hgt, accent if v == "crystal" else ICE, Vector3(-0.15 + cos(a) * 0.25, 1.78, sin(a) * 0.5), Vector3(rad_to_deg(sin(a)) * 0.5, 0, 10 - rad_to_deg(cos(a)) * 0.3), GLOW, 5)
		"magma", "obsidian":
			for z in [-1.0, 1.0]:
				_horn(rig, Vector3(0.1, 2.0, 0.25 * z), Vector3(0.2, 0.8, 0.6 * z), Vector3(0.3, 0.6, -0.4 * z), 0.6 if not big else 0.8, 0.1, Color(0.12, 0.08, 0.08))
			for i in 4:
				_sph(rig, 0.05, FIRE, Vector3(-0.3 + i * 0.15, 1.82, -0.3 + i * 0.2), Vector3.ONE, GLOW, 4)
		"stone", "rune", "mud", "marble":
			for i in 3:
				_sph(rig, 0.14, Color(0.35, 0.5, 0.22) if v != "marble" else GOLD, Vector3(-0.3 + i * 0.25, 1.8, -0.35 + i * 0.3), Vector3(1.3, 0.4, 1.1), CLAY if v != "marble" else METAL, 6)
		"void":
			for i in 5:
				var a := i * 1.25
				_cone(rig, 0.07, 0.4, Color(0.15, 0.05, 0.2), Vector3(cos(a) * 0.3, 1.8, sin(a) * 0.5), Vector3(rad_to_deg(sin(a)) * 0.4, 0, -rad_to_deg(cos(a)) * 0.4), METAL, 4)
	# --- Cabeza (pequeña, hundida entre los hombros)
	var H := Vector3(0.3, 2.0, 0)
	if v == "bone":
		var fake := {"head": "skull", "eye": GREEN_GLOW, "col": c, "boss": false}
		_head(rig, fake, H, 0.28)
	else:
		_box(rig, Vector3(0.42, 0.36, 0.44), rock.lightened(0.06), H, Vector3(0, 0, -8), k)
		_box(rig, Vector3(0.12, 0.08, 0.46), dark, H + Vector3(0.18, 0.1, 0), Vector3.ZERO, k)
		for z in [-1.0, 1.0]:
			_sph(rig, 0.06, eye, H + Vector3(0.22, 0.02, 0.11 * z), Vector3(0.5, 0.7, 1.2), GLOW, 6)
		if v == "marble" or n.contains("celeste"):
			_box(rig, Vector3(0.3, 0.3, 0.05), GOLD, H + Vector3(0.0, 0.25, 0), Vector3(0, 90, 0), METAL)
	if o.get("boss", false) or o.get("crowned", false):
		_crown(rig, H + Vector3(-0.02, 0.24, 0), 0.7, GOLD if v not in ["obsidian", "void"] else Color(0.25, 0.2, 0.22))
	# --- Brazos enormes
	for z in [-1.0, 1.0]:
		var ap := _pivot(rig, "ArmL" if z < 0 else "ArmR", Vector3(0, 1.6, 0.8 * z), Vector3(0, 0, 10),
				[_tr(ROT, 2, 0.3, WALK * 0.75, PI if z < 0 else 0.0)])
		_sph(ap, 0.32, rock, Vector3.ZERO, Vector3(1, 0.9, 1), k, 10)
		_box(ap, Vector3(0.36, 0.55, 0.36), rock.darkened(0.05), Vector3(0.02, -0.38, 0.05 * z), Vector3(0, 0, 5), k)
		_box(ap, Vector3(0.32, 0.5, 0.32), rock, Vector3(0.08, -0.85, 0.06 * z), Vector3(0, 0, -8), k)
		_sph(ap, 0.3, rock.lightened(0.05) if v != "magma" else rock, Vector3(0.12, -1.18, 0.06 * z), Vector3(1.1, 1, 1.05), k, 10)
		if v in ["magma", "obsidian", "void", "crystal", "ice", "rune"]:
			_box(ap, Vector3(0.04, 0.4, 0.04), accent, Vector3(0.2, -0.6, 0.18 * z), Vector3(0, 0, 10), GLOW)
		if v == "magma":
			_sph(ap, 0.14, FIRE, Vector3(0.22, -1.2, 0.1 * z), Vector3.ONE, GLOW, 6)
		if v == "island":
			_cyl(ap, 0.05, 0.05, 0.25, WOOD, Vector3(0.0, 0.25, 0.0), Vector3.ZERO, CLAY, 5)
			_cone(ap, 0.14, 0.3, Color(0.3, 0.55, 0.25), Vector3(0.0, 0.45, 0), Vector3.ZERO, CLAY, 6)
	# --- Piernas cortas
	for z in [-1.0, 1.0]:
		var lp := _pivot(rig, "LegL" if z < 0 else "LegR", Vector3(0, 0.62, 0.35 * z), Vector3.ZERO,
				[_tr(ROT, 2, 0.32, WALK * 0.75, 0.0 if z < 0 else PI)])
		_box(lp, Vector3(0.4, 0.42, 0.4), rock.darkened(0.08), Vector3(0, -0.2, 0), Vector3.ZERO, k)
		_box(lp, Vector3(0.52, 0.22, 0.46), rock.darkened(0.15), Vector3(0.06, -0.5, 0), Vector3.ZERO, k)


static func _roof_cone(p: Node3D, pos: Vector3, r: float, col: Color) -> void:
	_cone(p, r * 1.2, r * 1.1, col, pos + Vector3(0, r * 0.4, 0), Vector3.ZERO, CLAY, 4)


## Torre de asedio viviente: torre de madera con almenas sobre patas
static func _siege_tower(rig: Node3D, o: Dictionary) -> void:
	_box(rig, Vector3(1.0, 1.7, 1.0), WOOD, Vector3(0, 1.45, 0))
	for i in 4:
		_box(rig, Vector3(1.04, 0.06, 1.04), WOOD_DARK, Vector3(0, 0.75 + i * 0.45, 0))
	for z in [-1.0, 1.0]:
		_box(rig, Vector3(0.05, 1.75, 0.08), WOOD_DARK, Vector3(0.52, 1.45, 0.45 * z))
		_box(rig, Vector3(0.05, 1.75, 0.08), WOOD_DARK, Vector3(-0.52, 1.45, 0.45 * z))
	_box(rig, Vector3(1.2, 0.12, 1.2), WOOD_DARK, Vector3(0, 2.35, 0))
	for i in 4:
		for j in 4:
			if i in [1, 2] and j in [1, 2]:
				continue
			_box(rig, Vector3(0.18, 0.2, 0.18), WOOD, Vector3(-0.5 + i * 0.33, 2.52, -0.5 + j * 0.33))
	_box(rig, Vector3(0.05, 0.75, 0.6), WOOD.darkened(0.15), Vector3(0.53, 1.95, 0), Vector3(0, 0, 8))  # rampa
	for i in 3:
		_box(rig, Vector3(0.06, 0.04, 0.62), IRON, Vector3(0.55, 1.7 + i * 0.25, 0), Vector3.ZERO, METAL)
	for z in [-1.0, 1.0]:
		_sph(rig, 0.1, FIRE_HOT, Vector3(0.52, 1.25, 0.25 * z), Vector3(0.4, 1, 1), GLOW, 6)
	_box(rig, Vector3(0.3, 0.06, 0.1), DARK, Vector3(0.53, 1.05, 0))
	_cyl(rig, 0.025, 0.025, 0.8, WOOD_DARK, Vector3(-0.3, 2.9, 0.3), Vector3.ZERO, CLAY, 4)
	_box(rig, Vector3(0.35, 0.22, 0.02), Color(0.7, 0.12, 0.12), Vector3(-0.12, 3.15, 0.3))
	for i in 3:
		_cone(rig, 0.07, 0.25, IRON, Vector3(0.6, 0.9 + i * 0.5, 0.35 - i * 0.35), Vector3(0, 0, -90), METAL, 4)
	for z in [-1.0, 1.0]:
		var lp := _pivot(rig, "LegL" if z < 0 else "LegR", Vector3(0, 0.62, 0.32 * z), Vector3.ZERO, [_tr(ROT, 2, 0.35, WALK * 0.7, 0.0 if z < 0 else PI)])
		_seg(lp, 0.1, 0.09, WOOD_DARK, Vector3.ZERO, Vector3(0.0, -0.5, 0))
		_cyl(lp, 0.16, 0.16, 0.1, IRON, Vector3(0.04, -0.55, 0), Vector3(90, 0, 0), METAL, 10)
	for z in [-1.0, 1.0]:
		var ap := _pivot(rig, "ArmL" if z < 0 else "ArmR", Vector3(0, 1.8, 0.55 * z), Vector3.ZERO, [_tr(ROT, 2, 0.3, WALK * 0.7, PI if z < 0 else 0.0)])
		_seg(ap, 0.08, 0.07, WOOD_DARK, Vector3.ZERO, Vector3(0.2, -0.8, 0.1 * z))
		_cyl(ap, 0.14, 0.14, 0.3, IRON, Vector3(0.25, -0.9, 0.1 * z), Vector3.ZERO, METAL, 8)


static func _treant(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	var n: String = str(o.get("name", ""))
	var corrupt: bool = n.contains("corrupt") or o.get("boss", false)
	var big: bool = o.get("boss", false) or o.get("grand", false)
	var bark := c
	var leaf := Color(0.3, 0.55, 0.2) if not corrupt else Color(0.35, 0.25, 0.4)
	var eye := Color(1.0, 0.85, 0.3) if not corrupt else PURPLE_GLOW
	if n.contains("corazon"):
		eye = GREEN_GLOW
	var trunk_h := 1.6
	_cyl(rig, 0.4, 0.55, trunk_h, bark, Vector3(0, 0.55 + trunk_h * 0.5, 0), Vector3.ZERO, CLAY, 9)
	for i in 6:  # vetas de la corteza
		var a := TAU * i / 6.0 + 0.3
		_box(rig, Vector3(0.06, trunk_h * 0.9, 0.08), bark.darkened(0.25), Vector3(cos(a) * 0.45, 0.55 + trunk_h * 0.5, sin(a) * 0.45), Vector3(rad_to_deg(sin(a)) * 0.08, -rad_to_deg(a), 0))
	# cara tallada
	_sph(rig, 0.1, DARK, Vector3(0.42, 1.75, 0.15), Vector3(0.5, 1, 1.2), CLAY, 6)
	_sph(rig, 0.1, DARK, Vector3(0.42, 1.75, -0.15), Vector3(0.5, 1, 1.2), CLAY, 6)
	for z in [-1.0, 1.0]:
		_sph(rig, 0.05, eye, Vector3(0.47, 1.75, 0.15 * z), Vector3.ONE, GLOW, 6)
		_box(rig, Vector3(0.08, 0.06, 0.2), bark.darkened(0.3), Vector3(0.45, 1.88, 0.15 * z), Vector3(-20 * z, 0, 0))
	_sph(rig, 0.16, DARK, Vector3(0.42, 1.38, 0), Vector3(0.4, 0.7, 1.3), CLAY, 8)
	_cone(rig, 0.07, 0.25, bark.darkened(0.1), Vector3(0.55, 1.6, 0), Vector3(0, 0, -100), CLAY, 5)
	if n.contains("corazon") or n.contains("vida"):
		_sph(rig, 0.18, GREEN_GLOW if not corrupt else PURPLE_GLOW, Vector3(0.42, 1.05, 0), Vector3(0.5, 1, 1), GLOW, 8)
	# musgo y setas
	for i in 4:
		var a := i * 1.6
		_sph(rig, 0.12, Color(0.35, 0.5, 0.2), Vector3(cos(a) * 0.48, 0.9 + i * 0.25, sin(a) * 0.48), Vector3(1, 0.5, 1), CLAY, 6)
	if corrupt:
		for i in 3:
			_cyl(rig, 0.1, 0.03, 0.05, PURPLE_GLOW, Vector3(-0.3 + i * 0.1, 1.0 + i * 0.3, 0.45), Vector3(80, 0, 0), GLOW, 8)
	# copa
	var top := 0.55 + trunk_h
	var crown_s := 1.0 if not big else 1.25
	for i in 7:
		var a := TAU * i / 7.0
		_sph(rig, 0.42 * crown_s, leaf.lightened(0.06 * (i % 3)), Vector3(cos(a) * 0.45 - 0.1, top + 0.25 + (i % 2) * 0.2, sin(a) * 0.55), Vector3.ONE, CLAY, 8)
	_sph(rig, 0.55 * crown_s, leaf.lightened(0.04), Vector3(-0.1, top + 0.55, 0), Vector3.ONE, CLAY, 10)
	if corrupt:
		for i in 6:
			var a := TAU * i / 6.0
			_seg(rig, 0.05, 0.01, Color(0.15, 0.1, 0.12), Vector3(-0.1 + cos(a) * 0.3, top + 0.6, sin(a) * 0.4), Vector3(-0.1 + cos(a) * 0.7, top + 1.1, sin(a) * 0.8))
	if o.get("boss", false):
		_crown(rig, Vector3(-0.1, top + 1.05, 0), 0.8, Color(0.3, 0.2, 0.15), PURPLE_GLOW)
	# brazos-rama
	for z in [-1.0, 1.0]:
		var ap := _pivot(rig, "ArmL" if z < 0 else "ArmR", Vector3(0, 1.75, 0.45 * z), Vector3(0, 0, 15), [_tr(ROT, 2, 0.25, WALK * 0.6, PI if z < 0 else 0.0)])
		var pts := [Vector3.ZERO, Vector3(0.05, -0.3, 0.3 * z), Vector3(0.2, -0.7, 0.35 * z), Vector3(0.35, -0.95, 0.3 * z)]
		_chain(ap, pts, 0.14, 0.06, bark)
		for k in 3:
			var tip: Vector3 = (pts[3] as Vector3) + Vector3(0.1 * (k - 1), -0.15, 0.08 * (k - 1))
			_seg(ap, 0.05, 0.015, bark.darkened(0.15), pts[3], tip)
		_sph(ap, 0.2, leaf, (pts[1] as Vector3) + Vector3(0, 0.1, 0.1 * z), Vector3(1, 0.7, 1), CLAY, 6)
	# piernas-raíz
	for z in [-1.0, 1.0]:
		var lp := _pivot(rig, "LegL" if z < 0 else "LegR", Vector3(0, 0.6, 0.28 * z), Vector3.ZERO, [_tr(ROT, 2, 0.35, WALK * 0.6, 0.0 if z < 0 else PI)])
		_seg(lp, 0.2, 0.16, bark.darkened(0.1), Vector3.ZERO, Vector3(0.0, -0.5, 0.05 * z))
		for k in 3:
			_seg(lp, 0.09, 0.03, bark.darkened(0.15), Vector3(0, -0.5, 0.05 * z), Vector3(0.25 - k * 0.2, -0.58, (0.1 + 0.12 * absf(k - 1)) * z))


# ================================================================ Espíritus

static func _ghost(rig: Node3D, o: Dictionary) -> void:
	var v: String = o.get("var", "wraith")
	var n: String = str(o.get("name", ""))
	var c: Color = o["col"]
	var a: float = clampf(o["alpha"], 0.55, 0.85)
	var body := Color(c, a)
	var eye := Color(0.85, 1.0, 1.0)
	if c.get_luminance() < 0.35:
		eye = RED_GLOW
	if o.get("ice", false):
		eye = ICE_GLOW
	if v == "stalker" or n.contains("vacio") or n.contains("abismo"):
		eye = PURPLE_GLOW
	if n.contains("caos"):
		eye = Color(1.0, 0.3, 0.7)
	if v == "wisp":
		_wisp(rig, o)
		return
	# todo el cuerpo flota arriba y abajo
	var fl := _pivot(rig, "Float", Vector3(0, 0.35, 0), Vector3.ZERO, [_tr(POS, 1, 0.12, 3.0, 0.0, false)])
	# sábana que se estrecha en una estela
	_sph(fl, 0.5, body, Vector3(0, 1.0, 0), Vector3(0.95, 1.0, 0.95), GHOST, 14)
	_cyl(fl, 0.48, 0.3, 0.6, body, Vector3(-0.05, 0.6, 0), Vector3(0, 0, 10), GHOST, 12)
	_cone(fl, 0.3, 0.7, body, Vector3(-0.35, 0.2, 0), Vector3(0, 0, 130), GHOST, 10)
	for i in 5:  # bajo deshilachado
		var ang := TAU * i / 5.0
		_cone(fl, 0.1, 0.35, body.darkened(0.1), Vector3(-0.05 + cos(ang) * 0.3, 0.3, sin(ang) * 0.32), Vector3(0, 0, 180 + cos(ang) * 25), GHOST, 5)
	var H := Vector3(0.12, 1.35, 0)
	match v:
		"banshee":
			_sph(fl, 0.3, Color(0.92, 0.95, 0.95, 0.85), H, Vector3(1, 1.1, 0.95), GHOST, 12)
			for z in [-1.0, 1.0]:
				_sph(fl, 0.08, DARK, H + Vector3(0.24, 0.05, 0.11 * z), Vector3(0.5, 1.2, 1), CLAY, 6)
				_sph(fl, 0.035, eye, H + Vector3(0.28, 0.05, 0.11 * z), Vector3.ONE, GLOW, 4)
			_sph(fl, 0.09, DARK, H + Vector3(0.25, -0.15, 0), Vector3(0.5, 1.5, 0.9), CLAY, 6)  # boca que grita
			for i in 7:  # melena al viento
				var zz := (i - 3) * 0.08
				_chain(fl, [H + Vector3(-0.1, 0.25, zz), H + Vector3(-0.45, 0.1, zz * 1.5), H + Vector3(-0.8, -0.15, zz * 2.0), H + Vector3(-1.05, -0.05, zz * 2.2)], 0.08, 0.02, Color(c.lightened(0.3), 0.8), GHOST)
		"stalker":
			_sph(fl, 0.32, body.darkened(0.3), H, Vector3(1.2, 0.9, 1.0), GHOST, 12)
			for i in 5:
				_sph(fl, 0.045, eye, H + Vector3(0.3, 0.08 - (i % 2) * 0.1, (i - 2) * 0.09), Vector3.ONE, GLOW, 4)
			for z in [-1.0, 1.0]:
				_horn(fl, H + Vector3(0, 0.2, 0.15 * z), Vector3(-1, 0.6, 0.3 * z), Vector3(0, -0.5, 0), 0.4, 0.05, Color(0.1, 0.05, 0.12))
		"elf":
			_sph(fl, 0.28, Color(c.lightened(0.2), 0.8), H, Vector3(1, 1.08, 0.95), GHOST, 12)
			for z in [-1.0, 1.0]:
				_sph(fl, 0.05, eye, H + Vector3(0.24, 0.03, 0.1 * z), Vector3.ONE, GLOW, 4)
				_seg(fl, 0.05, 0.01, Color(c.lightened(0.2), 0.8), H + Vector3(0, 0, 0.25 * z), H + Vector3(-0.15, 0.2, 0.45 * z), GHOST)
			_cyl(fl, 0.29, 0.29, 0.04, GOLD, H + Vector3(0, 0.12, 0), Vector3(0, 0, -10), METAL, 12)
			_box(fl, Vector3(0.15, 0.6, 0.45), Color(c.lightened(0.4), 0.7), H + Vector3(-0.25, -0.3, 0), Vector3(0, 0, -10), GHOST)
		_:
			# capucha de aparecido
			_sph(fl, 0.36, body.darkened(0.15), H + Vector3(-0.06, 0.04, 0), Vector3(1.05, 1.1, 1.0), GHOST, 12)
			_cone(fl, 0.2, 0.4, body.darkened(0.15), H + Vector3(-0.3, 0.25, 0), Vector3(0, 0, 70), GHOST, 6)
			_sph(fl, 0.28, DARK, H + Vector3(0.1, -0.02, 0), Vector3(0.7, 0.95, 0.9), CLAY, 10)
			for z in [-1.0, 1.0]:
				_sph(fl, 0.05, eye, H + Vector3(0.3, 0.02, 0.1 * z), Vector3(0.6, 1, 1), GLOW, 6)
	if n.contains("ventisca") or o.get("ice", false):
		for i in 4:
			var ang := TAU * i / 4.0
			_cone(fl, 0.05, 0.22, ICE_GLOW, Vector3(cos(ang) * 0.6, 0.9 + (i % 2) * 0.3, sin(ang) * 0.6), Vector3(rad_to_deg(sin(ang)), 0, -rad_to_deg(cos(ang))), GLOW, 4)
	if n.contains("humo"):
		for i in 4:
			_sph(fl, 0.18 - i * 0.03, Color(0.4, 0.4, 0.4, 0.5), Vector3(-0.3 - i * 0.2, 1.4 + i * 0.12, 0.1 * (1 - 2 * (i % 2))), Vector3.ONE, GHOST, 8)
	if n.contains("refract"):
		for i in 4:
			_cone(fl, 0.06, 0.3, c.lightened(0.4), Vector3(-0.1 + i * 0.07, 1.4, -0.3 + i * 0.2), Vector3(-30 + i * 20, 0, -10), GLOW, 4)
	# brazos espectrales que se estiran hacia delante
	var reaper := v == "reaper"
	for z in [-1.0, 1.0]:
		var ap := _pivot(fl, "ArmL" if z < 0 else "ArmR", Vector3(0.05, 1.1, 0.42 * z), Vector3(0, 0, 55 if not reaper else 30),
				[_tr(ROT, 2, 0.15, 2.5, PI if z < 0 else 0.0, false)])
		_cyl(ap, 0.12, 0.07, 0.6, body, Vector3(0, -0.3, 0), Vector3.ZERO, GHOST, 8)
		var hand := Vector3(0, -0.62, 0)
		if v == "stalker" or n.contains("pesadilla") or n.contains("demonio"):
			for k in 3:
				_cone(ap, 0.03, 0.3, Color(0.1, 0.05, 0.12), hand + Vector3(0, -0.1, (k - 1) * 0.05), Vector3(0, 0, 180 - (k - 1) * 10), CLAY, 4)
		else:
			for k in 3:
				_cone(ap, 0.025, 0.16, Color(c.lightened(0.3), 0.8), hand + Vector3(0, -0.05, (k - 1) * 0.04), Vector3(0, 0, 180), GHOST, 4)
		if reaper and z > 0:
			var g := _grp(ap, hand, Vector3(0, 0, -15))
			_seg(g, 0.035, 0.035, WOOD_DARK, Vector3(0, -0.9, 0), Vector3(0, 0.9, 0))
			_plate(g, [Vector2(0, -0.05), Vector2(0.02, 0.06), Vector2(0.6, 0.0), Vector2(0.75, -0.2)], 0.04, STEEL, Vector3(0, 0.85, 0), Vector3(-90, 0, 0), METAL)
		if (n.contains("cazador") or n.contains("asesino") or n.contains("espia") or n.contains("ladron")) and true:
			var g2 := _grp(ap, hand, Vector3(0, 0, -60))
			_box(g2, Vector3(0.08, 0.4, 0.03), STEEL, Vector3(0, 0.25, 0), Vector3.ZERO, METAL)
	if o.get("boss", false) or o.get("crowned", false):
		_crown(fl, H + Vector3(0, 0.35, 0), 0.6)


## Fuego fatuo / chispa: orbe brillante con estela
static func _wisp(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	var fl := _pivot(rig, "Float", Vector3(0, 0.9, 0), Vector3.ZERO, [_tr(POS, 1, 0.18, 4.0, 0.0, false)])
	var core := c.lightened(0.4)
	_sph(fl, 0.28, Color(c, 0.4), Vector3.ZERO, Vector3.ONE, GHOST, 12)
	_sph(fl, 0.18, core, Vector3.ZERO, Vector3.ONE, GLOW, 10)
	for z in [-1.0, 1.0]:
		_sph(fl, 0.04, DARK, Vector3(0.16, 0.04, 0.06 * z), Vector3(0.5, 1.2, 1), CLAY, 4)
	var flame := _pivot(fl, "Flame", Vector3(-0.1, 0.05, 0), Vector3(0, 0, 70), [_tr(SCL, 1, 0.25, 12.0, 0.0, false, FLICKER)])
	_cone(flame, 0.2, 0.6, Color(c, 0.6), Vector3(0, 0.3, 0), Vector3.ZERO, GHOST, 8)
	_cone(flame, 0.11, 0.4, c, Vector3(0, 0.2, 0), Vector3.ZERO, GLOW, 6)
	for i in 4:
		var a := TAU * i / 4.0
		_sph(fl, 0.035, core, Vector3(cos(a) * 0.4, sin(a * 2.0) * 0.15, sin(a) * 0.4), Vector3.ONE, GLOW, 4)


static func _tornado(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	var spin := _pivot(rig, "Spin", Vector3.ZERO, Vector3.ZERO, [_tr(ROT, 1, 1.0, 6.0, 0.0, false, SPIN)])
	for i in 6:
		var r := 0.15 + i * 0.12
		var g := _grp(spin, Vector3(sin(i * 1.3) * 0.06, 0.2 + i * 0.3, cos(i * 1.3) * 0.06), Vector3(8 * sin(i), i * 40.0, 6))
		_m(g, _torus_mesh(r * 0.7, r), Color(c.lightened(0.1 * (i % 2)), 0.6), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.6, 1), GHOST)
		_box(g, Vector3(0.08, 0.04, 0.03), WOOD if i % 2 == 0 else Color(0.35, 0.55, 0.25), Vector3(r, 0, 0), Vector3(0, 0, 30))
	for z in [-1.0, 1.0]:
		_sph(rig, 0.07, Color(0.8, 0.95, 1.0), Vector3(0.45, 1.55, 0.14 * z), Vector3(0.6, 1, 1), GLOW, 6)
	_sph(rig, 0.3, Color(c, 0.35), Vector3(0, 1.6, 0), Vector3(1.4, 0.8, 1.4), GHOST, 10)


# ================================================================ Limos, gusanos y engendros

static func _slime(rig: Node3D, o: Dictionary) -> void:
	var v: String = o.get("var", "slime")
	var c: Color = o["col"]
	var n: String = str(o.get("name", ""))
	match v:
		"leech", "larva":
			_leech(rig, o)
			return
		"shard":
			_shard(rig, o)
			return
		"worm":
			_sandworm(rig, o)
			return
		"fish":
			_fish(rig, o)
			return
	var blob := _pivot(rig, "Blob", Vector3.ZERO, Vector3.ZERO, [_tr(SCL, 1, 0.12, WALK, 0.0, false, SINE)])
	var gel := Color(c, 0.78)
	var dark := v in ["spawn", "devourer"]
	_sph(blob, 0.85, gel, Vector3(0, 0.62, 0), Vector3(1.15, 0.8, 1.1), GHOST, 16)
	_sph(blob, 0.6, Color(c.lightened(0.2), 0.5), Vector3(0, 0.38, 0), Vector3(1.5, 0.5, 1.4), GHOST, 12)
	_sph(blob, 0.18, Color(1, 1, 1, 0.6), Vector3(0.25, 1.05, 0.25), Vector3(1.2, 0.6, 1), GHOST, 8)  # brillo
	match v:
		"slime":
			for i in 4:  # burbujas dentro
				_sph(blob, 0.08 + 0.03 * (i % 2), c.lightened(0.4), Vector3(-0.2 + i * 0.12, 0.45 + (i % 3) * 0.15, -0.2 + i * 0.13), Vector3.ONE, GLOW, 6)
			_sph(blob, 0.1, c.darkened(0.3), Vector3(-0.3, 0.55, 0.1), Vector3.ONE, CLAY, 6)  # hueso tragado
			_seg(blob, 0.04, 0.04, BONE, Vector3(-0.2, 0.35, -0.2), Vector3(0.1, 0.5, -0.35))
		"prism":
			for i in 5:
				var a := i * 1.25
				_cone(blob, 0.08, 0.35, c.lightened(0.3), Vector3(cos(a) * 0.35, 0.55, sin(a) * 0.35), Vector3(rad_to_deg(sin(a)) * 0.6, 0, -rad_to_deg(cos(a)) * 0.6), GLOW, 5)
		"spawn", "devourer":
			for i in 6:
				var a := TAU * i / 6.0
				_sph(blob, 0.07, eye_col(n), Vector3(cos(a) * 0.6, 0.8 + sin(a * 3.0) * 0.15, sin(a) * 0.65), Vector3.ONE, GLOW, 6)
			if n.contains("caos"):
				for i in 5:
					var a := TAU * i / 5.0
					_cone(blob, 0.06, 0.3, Color(0.2, 0.02, 0.1), Vector3(cos(a) * 0.5, 1.05, sin(a) * 0.5), Vector3(rad_to_deg(sin(a)) * 0.5, 0, -rad_to_deg(cos(a)) * 0.5), CLAY, 4)
	# boca y ojos frontales
	if v == "devourer" or n.contains("primigenio"):
		_sph(blob, 0.42, DARK, Vector3(0.68, 0.55, 0), Vector3(0.5, 0.75, 1.0), CLAY, 12)
		for i in 9:
			var a := TAU * i / 9.0
			_cone(blob, 0.05, 0.17, WHITE, Vector3(0.82, 0.55 + sin(a) * 0.28, cos(a) * 0.38), Vector3(rad_to_deg(cos(a)) * 1.5, 0, 90 - rad_to_deg(sin(a)) * 1.3 - 90.0) + Vector3(0, 0, 0), CLAY, 4)
		_sph(blob, 0.12, PURPLE_GLOW, Vector3(0.6, 1.12, 0), Vector3.ONE, GLOW, 8)
	else:
		for z in [-1.0, 1.0]:
			_sph(blob, 0.16, WHITE, Vector3(0.62, 0.85, 0.22 * z), Vector3(0.6, 1, 1), CLAY, 8)
			_sph(blob, 0.08, DARK if not dark else eye_col(n), Vector3(0.72, 0.85, 0.22 * z), Vector3(0.5, 1, 1), CLAY if not dark else GLOW, 6)
		_box(blob, Vector3(0.05, 0.05, 0.3), DARK, Vector3(0.82, 0.55, 0), Vector3(0, 0, -20))
	if o.get("boss", false) or o.get("crowned", false):
		_crown(blob, Vector3(0, 1.3, 0), 0.9, GOLD if not dark else Color(0.3, 0.2, 0.35), PURPLE_GLOW)
	if v in ["spawn", "devourer"]:
		for z in [-1.0, 1.0]:
			var tp := _pivot(rig, "TentL" if z < 0 else "TentR", Vector3(0.1, 0.5, 0.6 * z), Vector3.ZERO, [_tr(ROT, 0, 0.35 * z, 3.0, 0.0 if z < 0 else 1.5, false)])
			_chain(tp, [Vector3.ZERO, Vector3(0.2, 0.3, 0.25 * z), Vector3(0.45, 0.4, 0.35 * z), Vector3(0.65, 0.25, 0.4 * z)], 0.12, 0.03, c.lightened(0.1))


static func eye_col(n: String) -> Color:
	if n.contains("caos"):
		return Color(1.0, 0.3, 0.7)
	return PURPLE_GLOW


static func _leech(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	var larva: bool = o.get("var", "") == "larva"
	for i in 6:
		var seg: Node3D = null
		if i % 2 == 0:
			seg = _pivot(rig, "Seg%d" % i, Vector3(0.5 - i * 0.22, 0.25, 0), Vector3.ZERO, [_tr(POS, 1, 0.07, WALK, i * 0.8, false)])
		var parent: Node3D = seg if seg != null else rig
		var pos := Vector3.ZERO if seg != null else Vector3(0.5 - i * 0.22, 0.25, 0)
		var r := 0.28 - absf(i - 1.5) * 0.03
		_sph(parent, r, c.lightened(0.05 * (i % 2)), pos, Vector3(0.9, 0.95, 1.0), CLAY, 12)
		if larva:
			_sph(parent, r * 1.01, c.lightened(0.25), pos, Vector3(0.3, 1.0, 1.0), CLAY, 10)
	# boca circular con dientes
	_cyl(rig, 0.22, 0.25, 0.08, c.darkened(0.2), Vector3(0.75, 0.25, 0), Vector3(0, 0, 90), CLAY, 12)
	_cyl(rig, 0.15, 0.15, 0.09, Color(0.5, 0.08, 0.1), Vector3(0.77, 0.25, 0), Vector3(0, 0, 90), CLAY, 12)
	for i in 8:
		var a := TAU * i / 8.0
		_cone(rig, 0.025, 0.08, WHITE, Vector3(0.82, 0.25 + sin(a) * 0.13, cos(a) * 0.13), Vector3(rad_to_deg(cos(a)) * 0.0, 0, -90), CLAY, 3)
	if larva:
		for z in [-1.0, 1.0]:
			_sph(rig, 0.04, PURPLE_GLOW, Vector3(0.7, 0.45, 0.12 * z), Vector3.ONE, GLOW, 4)


static func _shard(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	var body := _pivot(rig, "Hop", Vector3.ZERO, Vector3.ZERO, [_tr(POS, 1, 0.25, WALK * 0.7, 0.0, true, BOUNCE)])
	_cone(body, 0.35, 1.1, c, Vector3(0, 0.55, 0), Vector3(0, 0, -5), METAL, 6)
	_cone(body, 0.35, 0.3, c, Vector3(0, 0.0, 0), Vector3(180, 0, 0), METAL, 6)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		_cone(body, 0.14, 0.55, c.lightened(0.15), Vector3(cos(a) * 0.3, 0.35, sin(a) * 0.3), Vector3(rad_to_deg(sin(a)) * 0.7, 0, -rad_to_deg(cos(a)) * 0.7), METAL, 5)
	_sph(body, 0.12, c.lightened(0.5), Vector3(0, 0.5, 0), Vector3.ONE, GLOW, 8)
	for z in [-1.0, 1.0]:
		_sph(body, 0.07, WHITE, Vector3(0.3, 0.6, 0.12 * z), Vector3(0.5, 1, 1), CLAY, 6)
		_sph(body, 0.035, DARK, Vector3(0.33, 0.6, 0.12 * z), Vector3(0.5, 1, 1), CLAY, 4)


static func _fish(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	var body := _pivot(rig, "Hop", Vector3(0, 0.25, 0), Vector3(0, 0, 0), [_tr(POS, 1, 0.45, WALK * 0.6, 0.0, true, BOUNCE)])
	_sph(body, 0.35, c, Vector3(0, 0.1, 0), Vector3(1.3, 0.8, 0.6), METAL, 12)
	_sph(body, 0.28, c.lightened(0.3), Vector3(0.05, 0.0, 0), Vector3(1.2, 0.6, 0.55), METAL, 10)
	_plate(body, [Vector2(0, -0.2), Vector2(0, 0.2), Vector2(-0.3, 0)], 0.04, c.darkened(0.15), Vector3(-0.45, 0.1, 0), Vector3(90, 0, 0))
	_plate(body, [Vector2(-0.1, 0), Vector2(0.15, 0), Vector2(-0.15, 0.2)], 0.03, ICE_GLOW, Vector3(0.0, 0.33, 0), Vector3(90, 0, 0), GLOW)
	for z in [-1.0, 1.0]:
		_eye(body, Vector3(0.32, 0.18, 0.13 * z), 0.06)
		_plate(body, [Vector2(0, 0), Vector2(-0.15, 0), Vector2(-0.12, 0.15 * z)], 0.02, c.darkened(0.1), Vector3(0.1, 0.0, 0.18 * z), Vector3(-30 * z, 0, 0))
	_box(body, Vector3(0.03, 0.03, 0.12), DARK, Vector3(0.45, 0.05, 0))


static func _sandworm(rig: Node3D, o: Dictionary) -> void:
	var c: Color = o["col"]
	# montículo de arena del que asoma el gusano
	_sph(rig, 0.9, c.lightened(0.15), Vector3(-0.2, 0.0, 0), Vector3(1.3, 0.35, 1.1), CLAY, 12)
	for i in 4:
		_sph(rig, 0.15, c.lightened(0.2), Vector3(-0.9 + i * 0.5, 0.1, 0.7 * (1 - 2 * (i % 2))), Vector3(1.2, 0.5, 1), CLAY, 6)
	var w := _pivot(rig, "Worm", Vector3(0.1, 0.2, 0), Vector3.ZERO, [_tr(ROT, 2, 0.12, 2.0, 0.0, false)])
	var pts := [Vector3.ZERO, Vector3(0.05, 0.45, 0), Vector3(0.15, 0.9, 0), Vector3(0.35, 1.25, 0), Vector3(0.6, 1.45, 0)]
	for i in pts.size():
		_sph(w, 0.48 - i * 0.03, c if i % 2 == 0 else c.darkened(0.12), pts[i], Vector3(1, 0.7, 1), CLAY, 12)
		_cyl(w, 0.49 - i * 0.03, 0.49 - i * 0.03, 0.05, c.darkened(0.25), pts[i] + Vector3(0, 0.15, 0), Vector3(0, 0, -i * 12.0), CLAY, 12)
	# boca de lamprea
	var m := Vector3(0.78, 1.55, 0)
	_cyl(w, 0.42, 0.36, 0.14, c.darkened(0.2), m, Vector3(0, 0, -60), CLAY, 14)
	_cyl(w, 0.3, 0.3, 0.15, Color(0.45, 0.08, 0.1), m + Vector3(0.02, 0.01, 0), Vector3(0, 0, -60), CLAY, 12)
	for i in 10:
		var a := TAU * i / 10.0
		var d := Basis(Vector3(0, 0, 1), deg_to_rad(-60)) * Vector3(cos(a) * 0.27, 0, sin(a) * 0.27)
		_cone(w, 0.05, 0.16, WHITE, m + d + Vector3(0.05, 0.03, 0), Vector3(0, 0, -150), CLAY, 4)
	if o.get("grand", false) or o.get("boss", false):
		for i in 3:
			_cone(w, 0.08, 0.3, c.darkened(0.3), pts[i + 1] + Vector3(-0.4, 0.05, 0), Vector3(0, 0, 70), CLAY, 4)


# ================================================================ Ojos y calaveras flotantes, cometas

static func _floating_eye(rig: Node3D, o: Dictionary) -> void:
	var v: String = o.get("var", "eye")
	var c: Color = o["col"]
	var holder := rig
	if not o.get("fly", false):
		holder = _pivot(rig, "Float", Vector3(0, 1.0, 0), Vector3.ZERO, [_tr(POS, 1, 0.12, 3.0, 0.0, false)])
	match v:
		"skull":
			var fake := {"head": "skull", "eye": GREEN_GLOW, "col": c, "boss": false}
			_head(holder, fake, Vector3.ZERO, 0.42)
			var fl := _pivot(holder, "Flame", Vector3(-0.2, 0.15, 0), Vector3(0, 0, 60), [_tr(SCL, 1, 0.3, 13.0, 0.0, false, FLICKER)])
			_cone(fl, 0.32, 0.8, Color(GREEN_GLOW, 0.6), Vector3(0, 0.35, 0), Vector3.ZERO, GHOST, 8)
			_cone(fl, 0.18, 0.55, GREEN_GLOW, Vector3(0, 0.25, 0), Vector3.ZERO, GLOW, 6)
		"comet":
			_sph(holder, 0.35, c.lightened(0.3), Vector3.ZERO, Vector3.ONE, GLOW, 12)
			_sph(holder, 0.5, Color(c, 0.35), Vector3.ZERO, Vector3.ONE, GHOST, 12)
			for z in [-1.0, 1.0]:
				_sph(holder, 0.06, DARK, Vector3(0.3, 0.06, 0.12 * z), Vector3(0.5, 1.2, 1), CLAY, 4)
			var fl := _pivot(holder, "Flame", Vector3(-0.25, 0, 0), Vector3(0, 0, 90), [_tr(SCL, 1, 0.25, 11.0, 0.0, false, FLICKER)])
			_cone(fl, 0.4, 1.5, Color(c, 0.5), Vector3(0, 0.7, 0), Vector3.ZERO, GHOST, 10)
			_cone(fl, 0.22, 1.1, Color(1.0, 0.95, 0.8), Vector3(0, 0.5, 0), Vector3.ZERO, GLOW, 8)
			for i in 4:
				_sph(holder, 0.05, WHITE, Vector3(-0.6 - i * 0.3, sin(i * 2.0) * 0.25, cos(i * 2.0) * 0.25), Vector3.ONE, GLOW, 4)
		_:
			_sph(holder, 0.5, WHITE.lerp(c, 0.12), Vector3.ZERO, Vector3.ONE, CLAY, 16)
			_cyl(holder, 0.26, 0.26, 0.06, c.lightened(0.3), Vector3(0.46, 0, 0), Vector3(0, 0, 90), GLOW, 14)
			_cyl(holder, 0.12, 0.12, 0.07, DARK, Vector3(0.48, 0, 0), Vector3(0, 0, 90), CLAY, 10)
			for i in 5:
				var a := TAU * i / 5.0
				_seg(holder, 0.012, 0.006, Color(0.85, 0.2, 0.2), Vector3(0.1, sin(a) * 0.45, cos(a) * 0.45), Vector3(0.38, sin(a) * 0.28, cos(a) * 0.28))
			# párpados
			for z in [-1.0, 1.0]:
				_sph(holder, 0.52, c, Vector3(-0.12, 0.0, 0.06 * z), Vector3(0.9, 0.98, 0.9), CLAY, 14)
			_box(holder, Vector3(0.1, 0.06, 0.6), c.darkened(0.3), Vector3(0.38, 0.32, 0), Vector3(0, 0, -30))
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				_horn(holder, Vector3(-0.2 + cos(a) * 0.1, 0.35, sin(a) * 0.35), Vector3(-0.5, 1, sin(a)), Vector3(-1, 0, 0), 0.4, 0.05, c.darkened(0.3))
			for z in [-1.0, 1.0]:
				var tp := _pivot(holder, "TentL" if z < 0 else "TentR", Vector3(-0.1, -0.35, 0.18 * z), Vector3.ZERO, [_tr(ROT, 0, 0.3 * z, 3.0, 0.0 if z < 0 else 1.5, false)])
				_chain(tp, [Vector3.ZERO, Vector3(-0.15, -0.3, 0.05 * z), Vector3(-0.1, -0.6, 0.1 * z), Vector3(-0.3, -0.85, 0.05 * z)], 0.08, 0.02, c.darkened(0.15))
			var tm := _pivot(holder, "TentM", Vector3(-0.3, -0.25, 0), Vector3.ZERO, [_tr(ROT, 2, 0.3, 2.5, 0.8, false)])
			_chain(tm, [Vector3.ZERO, Vector3(-0.25, -0.25, 0), Vector3(-0.4, -0.55, 0), Vector3(-0.6, -0.7, 0)], 0.08, 0.02, c.darkened(0.15))
