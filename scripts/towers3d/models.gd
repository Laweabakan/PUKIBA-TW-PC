extends RefCounted
## Utilidades para construir modelos 3D estilo LOW-POLY DE PAPEL:
## caras planas (cada triángulo con su propia luz), materiales mates sin relieve
## y un reloj "stop motion" para las animaciones decorativas.

const Textures := preload("res://scripts/towers3d/textures.gd")

const STOP_MOTION_FPS := 12.0
## Móvil: aún menos polígonos. En PC se puede probar con: godot --path . -- --low-poly
static var LOW := OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--low-poly")
## Estilo de caras planas: esquinas en un solo corte (chaflán) y pocas caras por curva.
static var CORNER_STEPS := 1
static var BEVEL_STEPS := 1
## Divisor de segmentos de las curvas (cilindros, esferas): menos caras = facetas más visibles.
static func seg_count(segs: int) -> int:
	if segs <= 6:
		return segs
	return maxi(5 if LOW else 6, segs / (3 if LOW else 2))
static var _mats := {}
static var _outline: ShaderMaterial


## Pasada de contorno estilo dibujo animado (shaders/outline.gdshader). Se puede apagar en
## Ajustes ("Contornos") por si un móvil muy modesto va lento. Devuelve null si está apagado.
static func outline() -> Material:
	if not bool(Save.data.get("settings", {}).get("outline", true)):
		return null
	if _outline == null:
		_outline = ShaderMaterial.new()
		_outline.shader = load("res://shaders/outline.gdshader")
	return _outline
static var _meshes := {}


# Tiempo cuantizado a 12 fps: da el movimiento a saltitos de la animación con plastilina
static func stop_time() -> float:
	return floorf(Time.get_ticks_msec() / 1000.0 * STOP_MOTION_FPS) / STOP_MOTION_FPS


# --- Materiales ---

## Papel mate (estilo low-poly de caras planas): sin relieve, sin brillo de borde ni contorno.
## Las texturas con dibujo (ladrillo, madera) se siguen proyectando en las tres direcciones.
static func _clay(m: StandardMaterial3D, relief_scale: float, roughness: float) -> void:
	m.roughness = clampf(roughness + 0.3, 0.5, 1.0)
	m.metallic_specular = 0.2
	m.uv1_triplanar = m.albedo_texture != null
	m.uv1_scale = Vector3.ONE * relief_scale


# Plastilina mate de un color. Con emission > 0 se vuelve un material brillante (sin relieve).
static func mat(col: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "c%s|%s" % [col.to_html(), emission]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		if emission > 0.0:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = emission
		else:
			_clay(m, 2.5, 0.62)
		_mats[key] = m
	return _mats[key]


# Plastilina más brillante (dorados, hierro)
static func metal(col: Color) -> StandardMaterial3D:
	var key := "m%s" % col.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		_clay(m, 3.0, 0.32)
		_mats[key] = m
	return _mats[key]


# Plastilina con dibujo (ladrillo, madera, tejas) proyectado en las tres direcciones
static func tex_mat(tex_id: String, scale := 2.0, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "t%s|%s|%s" % [tex_id, scale, tint.to_html()]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = Textures.get_texture(tex_id)
		m.albedo_color = tint
		_clay(m, scale, 0.65)
		_mats[key] = m
	return _mats[key]


# --- Mallas redondeadas ---

static func box_mesh(size: Vector3) -> Mesh:
	var key := "b%s" % size
	if not _meshes.has(key):
		var r := minf(0.05, minf(size.x, minf(size.y, size.z)) * 0.3)
		var hx := size.x / 2.0
		var hz := size.z / 2.0
		var poly := PackedVector2Array([Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)])
		_meshes[key] = rounded_prism(poly, r, size.y, r)
	return _meshes[key]


# Cilindro (o cono si top = 0) con bordes redondeados
static func cyl_mesh(top: float, bottom: float, h: float, segs := 16) -> Mesh:
	segs = seg_count(segs)
	var key := "c%s|%s|%s|%s" % [top, bottom, h, segs]
	if not _meshes.has(key):
		var big := maxf(top, bottom)
		var poly := PackedVector2Array()
		for i in segs:
			poly.append(Vector2.from_angle(TAU * i / segs) * big)
		var corner := big * (0.25 if segs <= 6 else 0.12)
		var bevel := minf(corner, minf(h * 0.3, big * 0.3))
		_meshes[key] = rounded_prism(poly, corner, h, bevel, bottom / big, maxf(top / big, 0.04))
	return _meshes[key]


# Tejado rectangular a cuatro aguas (ancho en X, fondo en Z) con bordes redondeados
static func roof_mesh(w: float, d: float, h: float, top_scale := 0.35) -> Mesh:
	var key := "r%s|%s|%s|%s" % [w, d, h, top_scale]
	if not _meshes.has(key):
		var poly := PackedVector2Array([Vector2(-w / 2, -d / 2), Vector2(w / 2, -d / 2), Vector2(w / 2, d / 2), Vector2(-w / 2, d / 2)])
		var r := minf(0.04, h * 0.3)
		_meshes[key] = rounded_prism(poly, r, h, r, 1.0, top_scale)
	return _meshes[key]


static func sphere_mesh(r: float, segs := 12) -> SphereMesh:
	segs = seg_count(segs)
	var key := "s%s|%s" % [r, segs]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = segs
		m.rings = maxi(segs / 2, 4)
		_meshes[key] = m
	return _meshes[key]


# Cono sencillo sin biseles (montañas y árboles lejanos: pocos vértices)
static func cone_mesh(r: float, h: float, segs := 8) -> CylinderMesh:
	var key := "k%s|%s|%s" % [r, h, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = r
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func plane_mesh(size: Vector2) -> PlaneMesh:
	var key := "p%s" % size
	if not _meshes.has(key):
		var m := PlaneMesh.new()
		m.size = size
		_meshes[key] = m
	return _meshes[key]


## Prisma con esquinas y bordes redondeados a partir de un polígono convexo
## (en el plano XZ, sentido antihorario). Centrado en Y como las primitivas de Godot.
## bevel <= corner_r. bottom_scale/top_scale estrechan la pieza (conos, tejados).
static func rounded_prism(poly: PackedVector2Array, corner_r: float, height: float, bevel: float,
		bottom_scale := 1.0, top_scale := 1.0) -> ArrayMesh:
	var n := poly.size()
	# Contorno: para cada punto, el centro de su arco y su normal hacia fuera
	var centers := PackedVector2Array()
	var outward := PackedVector2Array()
	var avg_r := 0.0
	for i in n:
		var prev := poly[(i - 1 + n) % n]
		var v := poly[i]
		var nxt := poly[(i + 1) % n]
		avg_r += v.length() / n
		var e1 := (v - prev).normalized()
		var e2 := (nxt - v).normalized()
		var n1 := Vector2(e1.y, -e1.x)
		var n2 := Vector2(e2.y, -e2.x)
		var turn := n1.angle_to(n2)
		var c := v - (n1 + n2).normalized() * (corner_r / cos(turn / 2.0))
		for k in CORNER_STEPS + 1:
			centers.append(c)
			outward.append(n1.rotated(turn * k / CORNER_STEPS))
	var m := centers.size()

	# Anillos del perfil: bisel inferior, lados y bisel superior
	var tilt := (bottom_scale - top_scale) * avg_r / height
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var rings := 0
	for half in 2:
		for k in BEVEL_STEPS + 1:
			var phi := PI / 2.0 * (k + half * BEVEL_STEPS) / BEVEL_STEPS
			if half == 1:
				phi = PI / 2.0 + PI / 2.0 * k / BEVEL_STEPS
			var inset := bevel * (1.0 - sin(phi))
			var y := bevel * (1.0 - cos(phi)) if half == 0 else height - bevel - bevel * cos(phi)
			var sc := lerpf(bottom_scale, top_scale, y / height)
			for j in m:
				var p := centers[j] + outward[j] * (corner_r - inset)
				verts.append(Vector3(p.x * sc, y - height / 2.0, p.y * sc))
				var side := Vector3(outward[j].x, tilt, outward[j].y).normalized()
				norms.append((side * sin(phi) + Vector3(0, -cos(phi), 0)).normalized())
			rings += 1

	var indices := PackedInt32Array()
	for r in rings - 1:
		for j in m:
			var a := r * m + j
			var b := r * m + (j + 1) % m
			var c := (r + 1) * m + j
			var d := (r + 1) * m + (j + 1) % m
			_tri(indices, verts, norms, a, b, d)
			_tri(indices, verts, norms, a, d, c)
	# Tapas
	var bottom := verts.size()
	verts.append(Vector3(0, -height / 2.0, 0))
	norms.append(Vector3.DOWN)
	var top := verts.size()
	verts.append(Vector3(0, height / 2.0, 0))
	norms.append(Vector3.UP)
	var last := (rings - 1) * m
	for j in m:
		_tri(indices, verts, norms, bottom, j, (j + 1) % m)
		_tri(indices, verts, norms, top, last + j, last + (j + 1) % m)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# Añade un triángulo con la cara frontal hacia fuera (Godot usa orden horario)
static func _tri(idx: PackedInt32Array, v: PackedVector3Array, nr: PackedVector3Array, a: int, b: int, c: int) -> void:
	var geo := (v[b] - v[a]).cross(v[c] - v[a])
	if geo.dot(nr[a] + nr[b] + nr[c]) > 0.0:
		idx.append_array([a, c, b])
	else:
		idx.append_array([a, b, c])


# --- Nodos ---

static func add(parent: Node, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = facet(mesh) # caras planas
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, m: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	return add(parent, box_mesh(size), m, pos, rot_deg)


static func cyl(parent: Node, top: float, bottom: float, h: float, m: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, segs := 16) -> MeshInstance3D:
	return add(parent, cyl_mesh(top, bottom, h, segs), m, pos, rot_deg)


static func sphere(parent: Node, r: float, m: Material, pos := Vector3.ZERO, scl := Vector3.ONE, segs := 12) -> MeshInstance3D:
	return add(parent, sphere_mesh(r, segs), m, pos, Vector3.ZERO, scl)


# Coloca un nodo de altura 1 (eje Y) para que vaya del punto a al punto b.
# El tramo nunca debe apuntar exactamente hacia abajo.
static func orient_segment(node: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.0001:
		return
	node.position = (a + b) * 0.5
	node.basis = Basis(Quaternion(Vector3.UP, d / length)) * Basis.from_scale(Vector3(1, length, 1))


static func segment(parent: Node, radius: float, m: Material, a: Vector3, b: Vector3, segs := 8) -> MeshInstance3D:
	var mi := add(parent, tube_mesh(radius, segs), m)
	orient_segment(mi, a, b)
	return mi


# Tubo de altura 1 sin biseles (se estira con orient_segment)
static func tube_mesh(radius: float, segs := 8) -> CylinderMesh:
	var key := "u%s|%s" % [radius, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = radius
		m.bottom_radius = radius
		m.height = 1.0
		m.radial_segments = segs
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func multimesh(parent: Node, mesh: Mesh, m: Material, transforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	parent.add_child(mmi)
	return mmi


## Fusiona todas las MeshInstance3D bajo root en una sola malla con una superficie
## por material (muchas menos llamadas de dibujo). Las coordenadas son relativas a root.
static func bake(root: Node3D) -> ArrayMesh:
	var groups := {}   # material -> [verts, norms, indices]
	_collect(root, root, groups)
	var mesh := ArrayMesh.new()
	for m in groups:
		var g: Array = groups[m]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g[0]
		arrays[Mesh.ARRAY_NORMAL] = g[1]
		arrays[Mesh.ARRAY_INDEX] = g[2]
		arrays[Mesh.ARRAY_TEX_UV] = g[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	return facet(mesh) as ArrayMesh


static func _collect(node: Node, root: Node3D, groups: Dictionary) -> void:
	for child in node.get_children():
		_collect(child, root, groups)
		if not child is MeshInstance3D or not child.visible:
			continue
		var mi := child as MeshInstance3D
		var xf := mi.transform
		var p := mi.get_parent()
		while p != root:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var nxf := xf.basis.inverse().transposed()
		if not groups.has(mi.material_override):
			groups[mi.material_override] = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array(), PackedVector2Array()]
		var g: Array = groups[mi.material_override]
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var base: int = g[0].size()
			var vs: PackedVector3Array = g[0]
			var ns: PackedVector3Array = g[1]
			var ids: PackedInt32Array = g[2]
			var uvs: PackedVector2Array = g[3]
			var src_uv = arr[Mesh.ARRAY_TEX_UV]
			for i in verts.size():
				vs.append(xf * verts[i])
				ns.append((nxf * norms[i]).normalized())
				uvs.append(src_uv[i] if src_uv != null and i < (src_uv as PackedVector2Array).size() else Vector2.ZERO)
			g[3] = uvs
			if arr[Mesh.ARRAY_INDEX] != null:
				for idx in (arr[Mesh.ARRAY_INDEX] as PackedInt32Array):
					ids.append(base + idx)
			else:
				for i in verts.size():
					ids.append(base + i)
			g[0] = vs
			g[1] = ns
			g[2] = ids


# Construye con build(Node3D) una sola vez y devuelve la malla fusionada (en caché)
static func baked(key: String, build: Callable) -> ArrayMesh:
	if not _meshes.has(key):
		var root := Node3D.new()
		build.call(root)
		_meshes[key] = bake(root)
		root.free()
	return _meshes[key]


static func add_baked(parent: Node, mesh: Mesh, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


# --- Modelos ---

# Torre básica: base redondeada + bola de un solo color
static func build_basic_tower(col: Color) -> Node3D:
	var root := Node3D.new()
	var m := mat(col)
	cyl(root, 0.28, 0.34, 0.36, m, Vector3(0, 0.18, 0), Vector3.ZERO, 24)
	var ball := sphere(root, 0.27, m, Vector3(0, 0.6, 0), Vector3.ONE, 20)
	ball.name = "Ball"
	return root


# Enemigo: triángulo de plastilina con el vértice hacia +Z
static func enemy_mesh() -> Mesh:
	if not _meshes.has("enemy"):
		var poly := PackedVector2Array([Vector2(0, 0.34), Vector2(-0.27, -0.2), Vector2(0.27, -0.2)])
		_meshes["enemy"] = rounded_prism(poly, 0.08, 0.2, 0.07)
	return _meshes["enemy"]


# --- Caras planas (estilo low-poly de papel) ---

## Devuelve una copia de la malla en la que cada triángulo tiene su propia normal: la luz
## cambia de golpe entre caras y se ven las facetas. Se guarda en la propia malla (meta)
## para no repetir el trabajo. Las cajas y planos ya son planos y se devuelven tal cual.
static func facet(mesh: Mesh) -> Mesh:
	if mesh == null or mesh is BoxMesh or mesh is PlaneMesh or mesh is QuadMesh:
		return mesh
	if mesh.has_meta("_flat"):
		return mesh.get_meta("_flat")
	if mesh.has_meta("_is_flat"):
		return mesh
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return mesh # líneas o puntos: se dejan como están
		var arr := mesh.surface_get_arrays(s)
		if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null or (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() < 3:
			continue
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n_src = arr[Mesh.ARRAY_NORMAL]
		var c_src = arr[Mesh.ARRAY_COLOR]
		var uv_src = arr[Mesh.ARRAY_TEX_UV]
		var idx = arr[Mesh.ARRAY_INDEX]
		var order: PackedInt32Array
		if idx != null and (idx as PackedInt32Array).size() > 0:
			order = idx
		else:
			order = PackedInt32Array(range(v.size()))
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var nc := PackedColorArray()
		var nuv := PackedVector2Array()
		var has_n: bool = n_src != null and (n_src as PackedVector3Array).size() == v.size()
		var has_c: bool = c_src != null and (c_src as PackedColorArray).size() == v.size()
		var has_uv: bool = uv_src != null and (uv_src as PackedVector2Array).size() == v.size()
		nv.resize(order.size())
		nn.resize(order.size())
		if has_c:
			nc.resize(order.size())
		if has_uv:
			nuv.resize(order.size())
		for t in range(0, order.size() - 2, 3):
			var a := order[t]
			var b := order[t + 1]
			var c := order[t + 2]
			var fn := (v[b] - v[a]).cross(v[c] - v[a])
			if has_n:
				var sm: Vector3 = n_src[a] + n_src[b] + n_src[c]
				if fn.dot(sm) < 0.0:
					fn = -fn
			else:
				fn = -fn # orden horario de Godot
			fn = fn.normalized() if fn.length_squared() > 0.0 else Vector3.UP
			for k in 3:
				var src := order[t + k]
				nv[t + k] = v[src]
				nn[t + k] = fn
				if has_c:
					nc[t + k] = c_src[src]
				if has_uv:
					nuv[t + k] = uv_src[src]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = nv
		arrays[Mesh.ARRAY_NORMAL] = nn
		if has_c:
			arrays[Mesh.ARRAY_COLOR] = nc
		if has_uv:
			arrays[Mesh.ARRAY_TEX_UV] = nuv
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(s))
	if out.get_surface_count() != mesh.get_surface_count():
		return mesh # alguna parte vacía: se deja la malla original (los materiales por índice no cuadrarían)
	out.set_meta("_is_flat", true)
	mesh.set_meta("_flat", out)
	return out


## Pasa a caras planas todas las mallas de un modelo (torres, héroes, castillo...).
static func facet_tree(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.mesh = facet(mi.mesh)
	elif node is MultiMeshInstance3D:
		var mm := (node as MultiMeshInstance3D).multimesh
		if mm != null:
			mm.mesh = facet(mm.mesh)
	for c in node.get_children():
		facet_tree(c)
