class_name V3
extends RefCounted
## Constructores de modelos 3D low-poly (estilo tablero de Catlike Coding).
## La lógica del juego trabaja en coordenadas 2D de "plano" (píxeles de la
## cuadrícula); aquí se convierten a 3D: 1 casilla = 1 unidad, eje Y hacia arriba.

const FLY_HEIGHT := 1.15

static var _mats := {}
static var _meshes := {}


# ---------------------------------------------------------------- Coordenadas
static func to3(p: Vector2, h := 0.0) -> Vector3:
	var t := float(GameData.TILE)
	return Vector3(p.x / t - GameData.COLS * 0.5, h, (p.y - GameData.GRID_OFFSET.y) / t - GameData.ROWS * 0.5)


static func to2(v: Vector3) -> Vector2:
	var t := float(GameData.TILE)
	return Vector2((v.x + GameData.COLS * 0.5) * t, (v.z + GameData.ROWS * 0.5) * t + GameData.GRID_OFFSET.y)


## Ángulo 2D (plano) -> rotación Y en 3D para que el eje +X local apunte ahí.
static func yaw(angle_2d: float) -> float:
	return -angle_2d


# ---------------------------------------------------------------- Materiales y mallas
static func mat(color: Color, emissive := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(), emissive]
	if _mats.has(key):
		return _mats[key]
	var m := new_mat(color, emissive)
	_mats[key] = m
	return m


static func new_mat(color: Color, emissive := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	if color.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shadow_to_opacity = false
	elif emissive <= 0.0:
		m.roughness = 0.95 # papel mate (sin contorno)
	return m


static func _mesh(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]


static func _inst(mesh: Mesh, color: Color, pos: Vector3, emissive := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color, emissive)
	mi.position = pos
	if color.a < 0.99 or emissive > 0.0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent != null:
		parent.add_child(mi)
	return mi


static func box(size: Vector3, color: Color, pos := Vector3.ZERO, emissive := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var m := _mesh("box%s" % size, func() -> Mesh:
		var b := BoxMesh.new()
		b.size = size
		return b)
	return _inst(m, color, pos, emissive, parent)


static func cyl(top_r: float, bottom_r: float, h: float, color: Color, pos := Vector3.ZERO, emissive := 0.0, parent: Node3D = null, segments := 12) -> MeshInstance3D:
	var m := _mesh("cyl%.3f/%.3f/%.3f/%d" % [top_r, bottom_r, h, segments], func() -> Mesh:
		var c := CylinderMesh.new()
		c.top_radius = top_r
		c.bottom_radius = bottom_r
		c.height = h
		c.radial_segments = segments
		c.rings = 1
		return c)
	return _inst(m, color, pos, emissive, parent)


static func sphere(r: float, color: Color, pos := Vector3.ZERO, emissive := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var m := _mesh("sph%.3f" % r, func() -> Mesh:
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = 12
		s.rings = 6
		return s)
	return _inst(m, color, pos, emissive, parent)


static func capsule(r: float, h: float, color: Color, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := _mesh("cap%.3f/%.3f" % [r, h], func() -> Mesh:
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = maxf(h, r * 2.0)
		c.radial_segments = 12
		c.rings = 4
		return c)
	return _inst(m, color, pos, 0.0, parent)


static func torus(inner: float, outer: float, color: Color, pos := Vector3.ZERO, emissive := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var m := _mesh("tor%.3f/%.3f" % [inner, outer], func() -> Mesh:
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 24
		t.ring_segments = 8
		return t)
	return _inst(m, color, pos, emissive, parent)


static func prism(size: Vector3, color: Color, pos := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := _mesh("pri%s" % size, func() -> Mesh:
		var p := PrismMesh.new()
		p.size = size
		return p)
	return _inst(m, color, pos, 0.0, parent)


static func node(name: String, pos := Vector3.ZERO, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	if parent != null:
		parent.add_child(n)
	return n


# ---------------------------------------------------------------- Torres
const STONE := Color(0.55, 0.53, 0.5)
const STONE_DARK := Color(0.35, 0.33, 0.31)
const WOOD := Color(0.45, 0.3, 0.16)

## Altura desde la que salen los proyectiles de cada torre.
static func muzzle_height(id: String, level: int) -> float:
	var grow := 1.0 + 0.08 * level
	var mid: String = GameData.TOWERS.get(id, {}).get("model", id) # las variantes usan el modelo de otra torre
	match mid:
		"cannon": return 0.6
		"ballista": return 0.55
		"mage": return 1.85 * grow
		"storm": return 1.9 * grow
		"obelisk": return 1.7 * grow
		"inferno": return 0.8
		"sanctuary": return 1.3
		"alchemist": return 1.1
		_: return 1.25 * grow


static func build_tower(id: String, level: int) -> Node3D:
	var def: Dictionary = GameData.TOWERS[id]
	var col: Color = def["color"]
	var root := node("Tower_" + id)
	var grow := 1.0 + 0.08 * level
	# Base de piedra común
	box(Vector3(0.84, 0.22, 0.84), STONE, Vector3(0, 0.11, 0), 0.0, root)
	box(Vector3(0.9, 0.05, 0.9), STONE_DARK, Vector3(0, 0.025, 0), 0.0, root)
	var turret := node("Turret", Vector3(0, 0.22, 0), root)
	match id:
		"archer":
			var h := 0.85 * grow
			cyl(0.26, 0.3, h, col, Vector3(0, 0.22 + h * 0.5, 0), 0.0, root, 10)
			for k in 4:
				var a := k * TAU / 4.0
				box(Vector3(0.12, 0.14, 0.12), col.lightened(0.15), Vector3(cos(a) * 0.22, 0.22 + h + 0.07, sin(a) * 0.22), 0.0, root)
			turret.position.y = 0.22 + h + 0.05
			sphere(0.09, Color(0.85, 0.7, 0.55), Vector3(0, 0.12, 0), 0.0, turret)
			box(Vector3(0.05, 0.05, 0.42), WOOD.darkened(0.2), Vector3(0.14, 0.12, 0), 0.0, turret)
			box(Vector3(0.36, 0.025, 0.025), Color(0.85, 0.85, 0.85), Vector3(0.2, 0.12, 0), 0.0, turret)
		"cannon":
			box(Vector3(0.6, 0.14, 0.5), WOOD, Vector3(0, 0.07, 0), 0.0, turret)
			box(Vector3(0.08, 0.3, 0.08), WOOD.darkened(0.2), Vector3(-0.05, 0.25, 0.18), 0.0, turret)
			box(Vector3(0.08, 0.3, 0.08), WOOD.darkened(0.2), Vector3(-0.05, 0.25, -0.18), 0.0, turret)
			var arm := node("Barrel", Vector3(-0.05, 0.35, 0), turret)
			arm.rotation.z = 0.55
			box(Vector3(0.75, 0.07, 0.09), WOOD.lightened(0.1), Vector3(0.2, 0, 0), 0.0, arm)
			sphere(0.11, Color(0.4, 0.38, 0.36), Vector3(0.55, 0.06, 0), 0.0, arm)
		"mage":
			var h := 1.05 * grow
			cyl(0.2, 0.3, h, col, Vector3(0, 0.22 + h * 0.5, 0), 0.0, root, 8)
			cyl(0.0, 0.32, 0.5, col.darkened(0.35), Vector3(0, 0.22 + h + 0.25, 0), 0.0, root, 8)
			turret.position.y = 0.22 + h + 0.7
			sphere(0.13 + level * 0.015, Color(0.75, 0.55, 1.0), Vector3.ZERO, 2.5, turret)
		"frost":
			var h := 0.8 * grow
			cyl(0.22, 0.3, h, col, Vector3(0, 0.22 + h * 0.5, 0), 0.4, root, 6)
			turret.position.y = 0.22 + h + 0.2
			for k in 3:
				var a := k * TAU / 3.0
				var c := cyl(0.0, 0.07, 0.28, Color(0.85, 0.95, 1.0), Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), 1.2, turret, 6)
				c.rotation.z = 0.3
		"ballista":
			box(Vector3(0.3, 0.25, 0.3), WOOD.darkened(0.2), Vector3(0, 0.12, 0), 0.0, turret)
			var b := node("Barrel", Vector3(0, 0.33, 0), turret)
			box(Vector3(0.8, 0.09, 0.12), WOOD, Vector3(0.05, 0, 0), 0.0, b)
			box(Vector3(0.08, 0.07, 0.85), WOOD.lightened(0.15), Vector3(0.25, 0.02, 0), 0.0, b)
			box(Vector3(0.7, 0.04, 0.04), Color(0.8, 0.8, 0.85), Vector3(0.15, 0.07, 0), 0.0, b)
		"alchemist":
			var h := 0.6 * grow
			cyl(0.28, 0.32, h, Color(0.4, 0.38, 0.33), Vector3(0, 0.22 + h * 0.5, 0), 0.0, root, 10)
			cyl(0.05, 0.05, 0.4, STONE_DARK, Vector3(0.18, 0.22 + h + 0.2, 0.12), 0.0, root, 6)
			turret.position.y = 0.22 + h + 0.2
			sphere(0.22, Color(0.45, 0.95, 0.3, 0.8), Vector3.ZERO, 0.8, turret)
			cyl(0.05, 0.07, 0.15, Color(0.6, 0.5, 0.4), Vector3(0, 0.25, 0), 0.0, turret, 6)
		"market":
			box(Vector3(0.7, 0.45, 0.6), Color(0.75, 0.6, 0.42), Vector3(0, 0.22 + 0.225, 0), 0.0, root)
			prism(Vector3(0.82, 0.32, 0.7), Color(0.75, 0.2, 0.18), Vector3(0, 0.22 + 0.45 + 0.16, 0), root).rotation.y = PI * 0.5
			turret.position.y = 1.2
			var coin := cyl(0.16, 0.16, 0.04, Color(1, 0.82, 0.2), Vector3.ZERO, 0.6, turret, 16)
			coin.rotation.x = PI * 0.5
		"storm":
			var h := 1.6 * grow
			cyl(0.05, 0.3, h, col, Vector3(0, 0.22 + h * 0.5, 0), 0.0, root, 6)
			torus(0.18, 0.24, Color(0.75, 0.75, 0.9), Vector3(0, 0.22 + h * 0.6, 0), 0.0, root)
			turret.position.y = 0.22 + h + 0.1
			sphere(0.12, Color(1, 1, 0.55), Vector3.ZERO, 3.0, turret)
		"inferno":
			cyl(0.36, 0.18, 0.45, col.darkened(0.2), Vector3(0, 0.22 + 0.22, 0), 0.0, root, 10)
			turret.position.y = 0.22 + 0.55
			sphere(0.2, Color(1.0, 0.45, 0.1, 0.9), Vector3.ZERO, 2.5, turret)
			sphere(0.11, Color(1.0, 0.9, 0.35), Vector3(0, 0.08, 0), 3.0, turret)
		"obelisk":
			var h := 1.7 * grow
			var ob := box(Vector3(0.3, h, 0.3), col, Vector3(0, 0.22 + h * 0.5, 0), 0.0, root)
			ob.rotation.y = PI * 0.25
			cyl(0.0, 0.21, 0.3, col, Vector3(0, 0.22 + h + 0.15, 0), 0.0, root, 4).rotation.y = PI * 0.25
			turret.position.y = 0.22 + h * 0.7
			sphere(0.1 + level * 0.012, Color(0.75, 0.3, 1.0), Vector3(0.2, 0, 0.2), 3.0, turret)
		"sanctuary":
			box(Vector3(0.68, 0.6, 0.68), col, Vector3(0, 0.22 + 0.3, 0), 0.0, root)
			prism(Vector3(0.8, 0.35, 0.8), Color(0.85, 0.7, 0.35), Vector3(0, 0.22 + 0.6 + 0.17, 0), root)
			turret.position.y = 0.22 + 1.1
			box(Vector3(0.06, 0.4, 0.06), Color(1, 0.95, 0.6), Vector3.ZERO, 1.5, turret)
			box(Vector3(0.26, 0.06, 0.06), Color(1, 0.95, 0.6), Vector3(0, 0.08, 0), 1.5, turret)
	# Indicadores de nivel: gemas doradas en la base (rosas en maestría)
	for i in level:
		var lc := Color(1, 0.4, 0.9) if level >= GameData.MAX_TOWER_LEVEL else Color(1, 0.82, 0.2)
		sphere(0.045, lc, Vector3(-0.3 + i * 0.15, 0.24, 0.43), 1.2, root)
	return root


static func build_hero(id: String) -> Node3D:
	if ResourceLoader.exists(HERO_MODELS):
		var hm: Node3D = load(HERO_MODELS).build(id)
		preload("res://scripts/towers3d/models.gd").facet_tree(hm) # caras planas
		return hm
	var def: Dictionary = GameData.HEROES[id]
	var col: Color = def["color"]
	var root := node("Hero_" + id)
	torus(0.3, 0.38, Color(1, 0.85, 0.3), Vector3(0, 0.03, 0), 1.0, root)
	cyl(0.34, 0.34, 0.06, Color(0.3, 0.25, 0.2), Vector3(0, 0.03, 0), 0.0, root, 16)
	var turret := node("Turret", Vector3(0, 0.06, 0), root)
	capsule(0.17, 0.62, col, Vector3(0, 0.38, 0), turret)
	box(Vector3(0.06, 0.5, 0.34), col.darkened(0.35), Vector3(-0.15, 0.36, 0), 0.0, turret)
	sphere(0.13, Color(0.95, 0.8, 0.65), Vector3(0, 0.82, 0), 0.0, turret)
	match def["ability"]:
		"warcry":
			box(Vector3(0.55, 0.05, 0.06), Color(0.9, 0.9, 1.0), Vector3(0.3, 0.45, 0.12), 0.3, turret)
			cyl(0.14, 0.14, 0.05, Color(0.7, 0.15, 0.15), Vector3(0.05, 0.42, -0.2), 0.0, turret, 12).rotation.x = PI * 0.5
		"haste":
			box(Vector3(0.05, 0.05, 0.55), WOOD, Vector3(0.18, 0.5, 0), 0.0, turret)
		"shieldwall":
			cyl(0.2, 0.2, 0.04, Color(0.55, 0.15, 0.12), Vector3(-0.02, 0.42, -0.22), 0.0, turret, 14).rotation.x = PI * 0.5
			cyl(0.07, 0.07, 0.05, Color(0.8, 0.7, 0.3), Vector3(-0.02, 0.42, -0.25), 0.0, turret, 10).rotation.x = PI * 0.5
			box(Vector3(0.45, 0.04, 0.05), Color(0.8, 0.8, 0.85), Vector3(0.28, 0.45, 0.1), 0.3, turret)
		"meteor", "dragonbreath":
			cyl(0.025, 0.025, 0.9, WOOD.darkened(0.2), Vector3(0.22, 0.45, 0.1), 0.0, turret, 6)
			sphere(0.08, Color(1, 0.5, 0.15), Vector3(0.22, 0.92, 0.1), 3.0, turret)
		"blessing":
			box(Vector3(0.06, 0.6, 0.06), Color(1, 0.9, 0.5), Vector3(0.22, 0.5, 0.1), 0.8, turret)
			box(Vector3(0.06, 0.06, 0.24), Color(1, 0.9, 0.5), Vector3(0.22, 0.65, 0.1), 0.8, turret)
		"volley":
			# Arco largo
			torus(0.28, 0.31, WOOD, Vector3(0.2, 0.5, 0.0), 0.0, turret).rotation.x = PI * 0.5
			box(Vector3(0.012, 0.56, 0.012), Color(0.95, 0.95, 0.9), Vector3(0.2, 0.5, 0.0), 0.0, turret)
		"heal":
			cyl(0.025, 0.025, 0.8, WOOD, Vector3(0.22, 0.45, 0.1), 0.0, turret, 6)
			sphere(0.08, Color(0.5, 1.0, 0.6), Vector3(0.22, 0.88, 0.1), 2.0, turret)
			box(Vector3(0.14, 0.12, 0.08), Color(0.6, 0.45, 0.25), Vector3(-0.12, 0.3, 0.18), 0.0, turret)
		"forge":
			cyl(0.025, 0.025, 0.45, WOOD, Vector3(0.24, 0.45, 0.1), 0.0, turret, 6)
			box(Vector3(0.2, 0.12, 0.12), Color(0.35, 0.35, 0.4), Vector3(0.24, 0.68, 0.1), 0.0, turret)
			sphere(0.16, Color(0.55, 0.3, 0.15), Vector3(0, 0.66, 0.02), 0.0, turret)
		"net":
			cyl(0.02, 0.02, 0.95, WOOD, Vector3(0.22, 0.48, 0.1), 0.0, turret, 6)
			cyl(0.0, 0.04, 0.12, Color(0.8, 0.8, 0.85), Vector3(0.22, 1.0, 0.1), 0.0, turret, 6)
			sphere(0.13, Color(0.7, 0.6, 0.4), Vector3(-0.15, 0.4, -0.12), 0.0, turret)
		"thorns":
			cyl(0.025, 0.025, 0.85, WOOD.darkened(0.2), Vector3(0.22, 0.45, 0.1), 0.0, turret, 6)
			for k in 3:
				sphere(0.07, Color(0.3, 0.7, 0.25), Vector3(0.22 + 0.06 * cos(k * 2.1), 0.9, 0.1 + 0.06 * sin(k * 2.1)), 0.0, turret)
		"bounty":
			cyl(0.025, 0.025, 0.55, WOOD, Vector3(0.24, 0.45, 0.1), 0.0, turret, 6)
			box(Vector3(0.05, 0.2, 0.22), Color(0.75, 0.75, 0.8), Vector3(0.24, 0.7, 0.18), 0.3, turret)
			sphere(0.07, Color(1.0, 0.8, 0.2), Vector3(-0.15, 0.25, 0.15), 0.6, turret)
		"anthem":
			sphere(0.13, Color(0.7, 0.45, 0.25), Vector3(0.18, 0.42, 0.15), 0.0, turret)
			box(Vector3(0.04, 0.04, 0.3), Color(0.45, 0.3, 0.15), Vector3(0.18, 0.5, -0.02), 0.0, turret)
			cyl(0.0, 0.15, 0.25, Color(0.85, 0.45, 0.6), Vector3(0, 0.98, 0), 0.0, turret, 10)
		"curse":
			cyl(0.0, 0.17, 0.35, Color(0.2, 0.12, 0.28), Vector3(0, 1.0, 0), 0.0, turret, 10)
			cyl(0.25, 0.25, 0.02, Color(0.2, 0.12, 0.28), Vector3(0, 0.86, 0), 0.0, turret, 16)
			cyl(0.02, 0.025, 0.8, WOOD.darkened(0.4), Vector3(0.22, 0.45, 0.1), 0.0, turret, 6)
			sphere(0.07, Color(0.7, 0.3, 1.0), Vector3(0.22, 0.88, 0.1), 2.5, turret)
		"storm":
			cyl(0.025, 0.025, 0.9, Color(0.5, 0.5, 0.55), Vector3(0.22, 0.45, 0.1), 0.0, turret, 6)
			sphere(0.09, Color(0.6, 0.85, 1.0), Vector3(0.22, 0.95, 0.1), 3.0, turret)
			cyl(0.0, 0.05, 0.12, Color(0.85, 0.75, 0.3), Vector3(0.06, 0.95, 0.08), 0.0, turret, 6)
			cyl(0.0, 0.05, 0.12, Color(0.85, 0.75, 0.3), Vector3(0.06, 0.95, -0.08), 0.0, turret, 6)
	if def["ability"] == "dragonbreath":
		cyl(0.0, 0.06, 0.15, Color(0.2, 0.05, 0.05), Vector3(0.03, 0.97, 0.08), 0.0, turret, 6)
		cyl(0.0, 0.06, 0.15, Color(0.2, 0.05, 0.05), Vector3(0.03, 0.97, -0.08), 0.0, turret, 6)
	var ready := sphere(0.07, Color(0.4, 1, 0.5), Vector3(0, 1.15, 0), 2.5, root)
	ready.name = "Ready"
	return root


# ---------------------------------------------------------------- Enemigos
static func build_enemy(def: Dictionary, r: float, elite := false) -> Node3D:
	var col: Color = def.get("color", Color.WHITE)
	var dark := Color(col.darkened(0.4), col.a)
	var root := node("Enemy")
	var body := node("Body", Vector3.ZERO, root)
	var eye := Color(0.1, 0.05, 0.05)
	match def.get("shape", "blob"):
		"blob":
			sphere(r, col, Vector3(0, r, 0), 0.0, body)
			sphere(r * 0.18, eye, Vector3(r * 0.85, r * 1.25, r * 0.35), 0.0, body)
			sphere(r * 0.18, eye, Vector3(r * 0.85, r * 1.25, -r * 0.35), 0.0, body)
		"beast":
			capsule(r * 0.7, r * 2.8, col, Vector3(0, r * 0.9, 0), body).rotation.z = PI * 0.5
			sphere(r * 0.6, col.lightened(0.1), Vector3(r * 1.4, r * 1.3, 0), 0.0, body)
			cyl(0.0, r * 0.2, r * 0.4, dark, Vector3(r * 1.3, r * 1.9, r * 0.25), 0.0, body, 4)
			cyl(0.0, r * 0.2, r * 0.4, dark, Vector3(r * 1.3, r * 1.9, -r * 0.25), 0.0, body, 4)
		"brute":
			box(Vector3(r * 1.5, r * 1.7, r * 1.7), col, Vector3(0, r * 0.95, 0), 0.0, body)
			sphere(r * 0.55, col.lightened(0.15), Vector3(r * 0.2, r * 2.1, 0), 0.0, body)
			box(Vector3(r * 0.5, r * 1.2, r * 0.45), dark, Vector3(0, r * 0.9, r * 1.1), 0.0, body)
			box(Vector3(r * 0.5, r * 1.2, r * 0.45), dark, Vector3(0, r * 0.9, -r * 1.1), 0.0, body)
		"robe":
			cyl(r * 0.25, r, r * 2.2, col, Vector3(0, r * 1.1, 0), 0.0, body, 8)
			sphere(r * 0.45, col.lightened(0.3), Vector3(0, r * 2.4, 0), 0.0, body)
			cyl(0.0, r * 0.5, r * 0.8, dark, Vector3(0, r * 2.9, 0), 0.0, body, 8)
			sphere(r * 0.22, Color(0.5, 1.0, 0.7), Vector3(r * 0.7, r * 1.8, r * 0.5), 2.0, body)
		"golem":
			box(Vector3(r * 1.8, r * 1.8, r * 1.8), col, Vector3(0, r * 1.1, 0), 0.0, body)
			box(Vector3(r * 0.6, r * 1.4, r * 0.6), dark, Vector3(0, r * 0.9, r * 1.3), 0.0, body)
			box(Vector3(r * 0.6, r * 1.4, r * 0.6), dark, Vector3(0, r * 0.9, -r * 1.3), 0.0, body)
			sphere(r * 0.2, Color(1.0, 0.75, 0.25), Vector3(r * 0.92, r * 1.45, 0), 2.5, body)
		"wings":
			sphere(r * 0.75, col, Vector3.ZERO, 0.0, body)
			sphere(r * 0.12, Color(1, 0.2, 0.2), Vector3(r * 0.6, r * 0.25, r * 0.25), 2.0, body)
			sphere(r * 0.12, Color(1, 0.2, 0.2), Vector3(r * 0.6, r * 0.25, -r * 0.25), 2.0, body)
			var wl := node("WingL", Vector3(0, 0, r * 0.5), body)
			box(Vector3(r * 0.9, r * 0.06, r * 1.8), dark, Vector3(0, 0, r * 0.9), 0.0, wl)
			var wr := node("WingR", Vector3(0, 0, -r * 0.5), body)
			box(Vector3(r * 0.9, r * 0.06, r * 1.8), dark, Vector3(0, 0, -r * 0.9), 0.0, wr)
		"dragon":
			capsule(r * 0.55, r * 2.4, col, Vector3.ZERO, body).rotation.z = PI * 0.5
			sphere(r * 0.45, col.lightened(0.1), Vector3(r * 1.35, r * 0.35, 0), 0.0, body)
			sphere(r * 0.1, Color(1, 0.9, 0.2), Vector3(r * 1.7, r * 0.5, r * 0.18), 2.5, body)
			sphere(r * 0.1, Color(1, 0.9, 0.2), Vector3(r * 1.7, r * 0.5, -r * 0.18), 2.5, body)
			cyl(0.0, r * 0.3, r * 1.4, dark, Vector3(-r * 1.6, 0, 0), 0.0, body, 6).rotation.z = PI * 0.5
			var dl := node("WingL", Vector3(0, r * 0.2, r * 0.4), body)
			box(Vector3(r * 1.3, r * 0.06, r * 2.4), dark, Vector3(0, 0, r * 1.2), 0.0, dl)
			var dr := node("WingR", Vector3(0, r * 0.2, -r * 0.4), body)
			box(Vector3(r * 1.3, r * 0.06, r * 2.4), dark, Vector3(0, 0, -r * 1.2), 0.0, dr)
		"ghost":
			capsule(r * 0.8, r * 2.4, Color(col, 0.55), Vector3(0, r * 1.3, 0), body)
			sphere(r * 0.16, eye, Vector3(r * 0.72, r * 1.8, r * 0.3), 0.0, body)
			sphere(r * 0.16, eye, Vector3(r * 0.72, r * 1.8, -r * 0.3), 0.0, body)
		"slime":
			var s := sphere(r, Color(col, 0.8), Vector3(0, r * 0.7, 0), 0.3, body)
			s.scale = Vector3(1.1, 0.75, 1.1)
			sphere(r * 0.3, Color(col.lightened(0.5), 0.9), Vector3(r * 0.2, r * 0.8, 0), 0.0, body)
	if def.get("boss", false):
		var crown := node("Crown", Vector3(0, r * (2.6 if def.get("shape") in ["brute", "robe", "golem", "ghost"] else 1.8), 0), body)
		cyl(r * 0.45, r * 0.4, r * 0.3, Color(1, 0.8, 0.1), Vector3.ZERO, 0.6, crown, 8)
		for k in 5:
			var a := k * TAU / 5.0
			cyl(0.0, r * 0.08, r * 0.3, Color(1, 0.8, 0.1), Vector3(cos(a) * r * 0.42, r * 0.28, sin(a) * r * 0.42), 0.6, crown, 4)
	if elite:
		torus(r * 1.3, r * 1.5, Color(1, 0.3, 0.9), Vector3(0, 0.03, 0), 2.0, root)
	return root


# ---------------------------------------------------------------- Proyectiles
static func build_projectile(style: String, color: Color) -> Node3D:
	var root := node("Proj")
	match style:
		"arrow":
			box(Vector3(0.36, 0.03, 0.03), WOOD, Vector3.ZERO, 0.0, root)
			box(Vector3(0.08, 0.06, 0.06), Color(0.8, 0.8, 0.85), Vector3(0.2, 0, 0), 0.0, root)
		"bolt":
			box(Vector3(0.6, 0.05, 0.05), WOOD, Vector3.ZERO, 0.0, root)
			box(Vector3(0.12, 0.1, 0.1), Color(0.85, 0.85, 0.9), Vector3(0.32, 0, 0), 0.0, root)
		"rock":
			sphere(0.13, Color(0.45, 0.42, 0.4), Vector3.ZERO, 0.0, root)
		"arrow_poison":
			box(Vector3(0.36, 0.03, 0.03), WOOD, Vector3.ZERO, 0.0, root)
			box(Vector3(0.08, 0.06, 0.06), Color(0.5, 1.0, 0.3), Vector3(0.2, 0, 0), 2.0, root)
		"fireball":
			sphere(0.16, Color(1.0, 0.4, 0.08, 0.85), Vector3.ZERO, 2.5, root)
			sphere(0.09, Color(1.0, 0.85, 0.3), Vector3.ZERO, 3.0, root)
		"rocket":
			cyl(0.035, 0.035, 0.22, Color(0.75, 0.15, 0.1), Vector3.ZERO, 0.0, root, 8).rotation.z = PI * 0.5
			cyl(0.0, 0.04, 0.08, Color(0.85, 0.7, 0.3), Vector3(0.15, 0, 0), 0.0, root, 8).rotation.z = -PI * 0.5
			sphere(0.05, Color(1.0, 0.6, 0.15), Vector3(-0.13, 0, 0), 3.0, root)
		"flask":
			sphere(0.1, Color(0.5, 0.95, 0.3), Vector3.ZERO, 1.0, root)
		"slash":
			torus(0.15, 0.2, Color(1, 1, 1), Vector3.ZERO, 2.0, root)
		"void":
			sphere(0.16, Color(0.75, 0.3, 1.0), Vector3.ZERO, 3.0, root)
		_:
			sphere(0.1, color, Vector3.ZERO, 3.0, root)
	return root


## Altura máxima del arco de cada proyectil (los morteros vuelan en parábola).
static func arc_height(style: String) -> float:
	match style:
		"rock", "flask": return 1.8
		"rocket": return 1.3
		"fireball": return 0.25
		"arrow_poison": return 0.35
		"arrow": return 0.35
		"bolt": return 0.15
		_: return 0.0


# ---------------------------------------------------------------- Castillo feudal (destino de los enemigos)
## Castillo europeo de unas 2.6 x 2.6 casillas. La puerta mira a -X (hacia el camino que llega).
const CASTLE_HEIGHT := 1.6
const HERO_MODELS := "res://scripts/towers3d/hero_models.gd"


static func build_castle(banner: Color = Color(0.7, 0.1, 0.12)) -> Node3D:
	var root := node("Castle")
	var stone := Color(0.66, 0.63, 0.58)
	var stone_dk := Color(0.5, 0.48, 0.44)
	var roof := Color(0.32, 0.36, 0.55)
	var half := 1.1
	var wall_h := 0.75
	# Colina / base de tierra y foso
	cyl(1.75, 1.95, 0.2, Color(0.35, 0.3, 0.22), Vector3(0, 0.1, 0), 0.0, root, 20)
	torus(1.5, 1.72, Color(0.2, 0.35, 0.55), Vector3(0, 0.2, 0), 0.3, root)
	# Todo el alzado (murallas, torres, homenaje y puerta) es más alto: la fortaleza domina el paisaje
	var up := node("Alzado", Vector3(0, 0.2 - 0.2 * CASTLE_HEIGHT, 0), root)
	up.scale = Vector3(1.0, CASTLE_HEIGHT, 1.0)
	# Murallas con almenas (adarve)
	for side in 4:
		var a := side * PI * 0.5
		var dir := Vector3(cos(a), 0, sin(a))
		var along := Vector3(-dir.z, 0, dir.x)
		var w := node("Muro", dir * half + Vector3(0, 0.2, 0), up)
		w.rotation.y = -a
		if side == 2:
			# Lado de la puerta: dos tramos con hueco al centro
			box(Vector3(0.18, wall_h, 0.62), stone, Vector3(0, wall_h * 0.5, 0.79), 0.0, w)
			box(Vector3(0.18, wall_h, 0.62), stone, Vector3(0, wall_h * 0.5, -0.79), 0.0, w)
		else:
			box(Vector3(0.18, wall_h, half * 2.0), stone, Vector3(0, wall_h * 0.5, 0), 0.0, w)
		for k in 9:
			var z := -half + 0.12 + k * 0.245
			if side == 2 and absf(z) < 0.45:
				continue
			box(Vector3(0.2, 0.12, 0.12), stone_dk, Vector3(0, wall_h + 0.06, z), 0.0, w)
		var _unused := along
	# Torres redondas en las esquinas con tejado cónico
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			var p := Vector3(cx * half, 0.2, cz * half)
			cyl(0.26, 0.3, 1.25, stone, p + Vector3(0, 0.62, 0), 0.0, up, 12)
			cyl(0.31, 0.31, 0.1, stone_dk, p + Vector3(0, 1.3, 0), 0.0, up, 12)
			cyl(0.0, 0.34, 0.6, roof, p + Vector3(0, 1.65, 0), 0.0, up, 12)
			box(Vector3(0.015, 0.25, 0.015), Color(0.3, 0.25, 0.2), p + Vector3(0, 2.05, 0), 0.0, up)
			box(Vector3(0.015, 0.1, 0.16), banner, p + Vector3(0, 2.12, 0.08), 0.0, up)
			# Saeteras
			for k in 3:
				var a2 := k * TAU / 3.0 + 0.4
				box(Vector3(0.04, 0.16, 0.04), Color(0.12, 0.1, 0.1), p + Vector3(cos(a2) * 0.29, 0.75, sin(a2) * 0.29), 0.0, up)
	# Torre del homenaje (donjon) cuadrada
	var keep := node("Torre del homenaje", Vector3(0.2, 0.2, 0), up)
	box(Vector3(0.9, 1.5, 0.9), stone.lightened(0.05), Vector3(0, 0.75, 0), 0.0, keep)
	box(Vector3(1.0, 0.08, 1.0), stone_dk, Vector3(0, 1.52, 0), 0.0, keep)
	for k in 4:
		for side in 4:
			var a3 := side * PI * 0.5
			var off := -0.36 + k * 0.24
			var pos := Vector3(cos(a3) * 0.45, 1.64, sin(a3) * 0.45) + Vector3(-sin(a3), 0, cos(a3)) * off
			box(Vector3(0.12, 0.16, 0.12), stone_dk, pos, 0.0, keep)
	for side in 4:
		var a4 := side * PI * 0.5
		box(Vector3(0.05, 0.2, 0.12), Color(0.15, 0.12, 0.1), Vector3(cos(a4) * 0.46, 1.05, sin(a4) * 0.46), 0.0, keep).rotation.y = -a4
	# Torreta de vigía sobre el homenaje con el estandarte real
	cyl(0.14, 0.16, 0.45, stone, Vector3(0.25, 1.95, 0.25), 0.0, keep, 10)
	cyl(0.0, 0.2, 0.35, roof, Vector3(0.25, 2.35, 0.25), 0.0, keep, 10)
	box(Vector3(0.02, 0.5, 0.02), Color(0.3, 0.25, 0.2), Vector3(0, 1.9, 0), 0.0, keep)
	box(Vector3(0.02, 0.22, 0.36), banner, Vector3(0, 2.02, 0.18), 0.2, keep)
	sphere(0.04, Color(1, 0.8, 0.2), Vector3(0, 2.16, 0), 0.5, keep)
	# Cuerpo de guardia con rastrillo, en el lado -X
	var gate := node("Puerta", Vector3(-half, 0.2, 0), up)
	box(Vector3(0.4, 1.0, 0.3), stone, Vector3(0, 0.5, 0.33), 0.0, gate)
	box(Vector3(0.4, 1.0, 0.3), stone, Vector3(0, 0.5, -0.33), 0.0, gate)
	box(Vector3(0.4, 0.3, 0.96), stone, Vector3(0, 0.85, 0), 0.0, gate)
	for k in 5:
		box(Vector3(0.12, 0.12, 0.12), stone_dk, Vector3(0, 1.06, -0.4 + k * 0.2), 0.0, gate)
	box(Vector3(0.06, 0.65, 0.36), Color(0.2, 0.17, 0.14), Vector3(-0.15, 0.35, 0), 0.0, gate)
	for k in 4:
		box(Vector3(0.07, 0.62, 0.025), Color(0.25, 0.25, 0.27), Vector3(-0.19, 0.36, -0.13 + k * 0.087), 0.0, gate)
	box(Vector3(0.07, 0.025, 0.36), Color(0.25, 0.25, 0.27), Vector3(-0.19, 0.5, 0), 0.0, gate)
	# Puente levadizo sobre el foso
	box(Vector3(0.7, 0.05, 0.36), Color(0.45, 0.3, 0.16), Vector3(-0.5, 0.0, 0), 0.0, gate)
	# Estandartes colgando junto a la puerta
	box(Vector3(0.02, 0.4, 0.14), banner, Vector3(-0.21, 0.6, 0.33), 0.2, gate)
	box(Vector3(0.02, 0.4, 0.14), banner, Vector3(-0.21, 0.6, -0.33), 0.2, gate)
	return root


# ---------------------------------------------------------------- Decoración
static func build_deco(kind: String, s: float) -> Node3D:
	var root := node("Deco")
	root.scale = Vector3.ONE * s
	match kind:
		"tree":
			cyl(0.05, 0.06, 0.3, Color(0.4, 0.25, 0.12), Vector3(0, 0.15, 0), 0.0, root, 6)
			sphere(0.2, Color(0.22, 0.5, 0.18), Vector3(0, 0.42, 0), 0.0, root)
		"pine", "pine_snow":
			cyl(0.04, 0.05, 0.2, Color(0.35, 0.22, 0.1), Vector3(0, 0.1, 0), 0.0, root, 6)
			cyl(0.0, 0.2, 0.55, Color(0.12, 0.32, 0.16), Vector3(0, 0.45, 0), 0.0, root, 7)
			if kind == "pine_snow":
				cyl(0.0, 0.09, 0.2, Color.WHITE, Vector3(0, 0.66, 0), 0.0, root, 7)
		"rock":
			sphere(0.16, Color(0.52, 0.5, 0.47), Vector3(0, 0.06, 0), 0.0, root).scale = Vector3(1.2, 0.7, 1.0)
		"swamp":
			cyl(0.22, 0.22, 0.02, Color(0.18, 0.3, 0.25, 0.85), Vector3(0, 0.01, 0), 0.0, root, 12)
			cyl(0.01, 0.015, 0.3, Color(0.4, 0.45, 0.2), Vector3(0.1, 0.15, 0.05), 0.0, root, 4)
		"grave":
			box(Vector3(0.08, 0.3, 0.2), Color(0.58, 0.58, 0.6), Vector3(0, 0.15, 0), 0.0, root)
			box(Vector3(0.2, 0.03, 0.28), Color(0.35, 0.3, 0.25), Vector3(0.12, 0.015, 0), 0.0, root)
		"crystal":
			cyl(0.0, 0.08, 0.45, Color(0.6, 0.75, 1.0, 0.85), Vector3(0, 0.22, 0), 0.8, root, 5)
			cyl(0.0, 0.05, 0.28, Color(0.75, 0.6, 1.0, 0.85), Vector3(0.1, 0.14, 0.06), 0.8, root, 5)
		"lava":
			cyl(0.2, 0.2, 0.02, Color(1.0, 0.4, 0.1), Vector3(0, 0.012, 0), 2.0, root, 10)
		"cactus":
			cyl(0.06, 0.06, 0.45, Color(0.3, 0.55, 0.25), Vector3(0, 0.22, 0), 0.0, root, 8)
			cyl(0.04, 0.04, 0.18, Color(0.3, 0.55, 0.25), Vector3(0.1, 0.28, 0), 0.0, root, 8)
		"ruin":
			box(Vector3(0.14, 0.45, 0.14), Color(0.68, 0.66, 0.6), Vector3(-0.1, 0.22, 0), 0.0, root)
			box(Vector3(0.14, 0.25, 0.14), Color(0.62, 0.6, 0.55), Vector3(0.12, 0.12, 0.08), 0.0, root)
		"cloud":
			sphere(0.14, Color(1, 1, 1, 0.8), Vector3(0, 0.6, 0), 0.0, root)
			sphere(0.11, Color(1, 1, 1, 0.8), Vector3(0.14, 0.58, 0.04), 0.0, root)
			sphere(0.12, Color(0.4, 0.65, 0.35), Vector3(0, 0.05, 0), 0.0, root).scale = Vector3(1.4, 0.4, 1.4)
	return root
