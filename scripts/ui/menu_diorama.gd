class_name MenuDiorama
extends Node3D
## Fondo animado del menú (PC): una maqueta 3D low-poly con el castillo en el centro, torres,
## casas, árboles y montañas alrededor, y la cámara girando muy despacio. Se oscurece un poco
## por los bordes para que la interfaz se lea bien.

const SC_PATH := "res://scripts/game/scenery_models.gd"

var _pivot: Node3D



func _ready() -> void:
	_build()

func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotation.y += delta * 0.035


func _build() -> void:
	var SC: GDScript = load(SC_PATH)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.36, 0.5, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.95)
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_white = 6.0
	e.tonemap_exposure = 1.1
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color(0.62, 0.72, 0.85)
	e.fog_depth_begin = 34.0
	e.fog_depth_end = 90.0
	e.ssao_enabled = true
	e.ssao_intensity = 2.0
	e.glow_enabled = true
	e.glow_intensity = 0.4
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -30, 0)
	sun.light_color = Color(1.0, 0.86, 0.68)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.0
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	_pivot = Node3D.new()
	add_child(_pivot)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	# Suelo: isla redonda de hierba con borde de tierra
	var ground := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 26.0
	gm.bottom_radius = 24.0
	gm.height = 1.2
	gm.radial_segments = 28
	ground.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.42, 0.68, 0.28)
	gmat.roughness = 1.0
	ground.material_override = gmat
	ground.position.y = -0.6
	_pivot.add_child(ground)
	# Camino de tierra en espiral hasta el castillo
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.82, 0.66, 0.42)
	pmat.roughness = 1.0
	for k in 40:
		var a := k * 0.32
		var r := 3.2 + k * 0.42
		var tile := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.6, 0.06, 1.6)
		tile.mesh = bm
		tile.material_override = pmat
		tile.position = Vector3(cos(a) * r, 0.02, sin(a) * r)
		tile.rotation.y = -a
		_pivot.add_child(tile)
	# Castillo en el centro
	var castle := V3.build_castle()
	castle.scale = Vector3.ONE * 1.6
	_pivot.add_child(castle)
	# Torres a lo largo del camino
	var tower_ids := ["archer", "mage", "cannon", "frost", "crossbow", "bell", "mortar", "storm", "inferno", "obelisk"]
	for k in tower_ids.size():
		var a := 0.9 + k * 1.15
		var r := 5.5 + k * 1.1
		var t := TowerModels.build(tower_ids[k], 2 + k % 3)
		t.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		t.rotation.y = rng.randf() * TAU
		_pivot.add_child(t)
	# Árboles, rocas y casas alrededor (lo más lejano, montañas)
	var pal: Dictionary = SC.palette("")
	var ids := ["oak", "oak", "oak_dark", "poplar", "birch", "bush", "pebble", "haystack", "flowers"]
	for k in 170:
		var a := rng.randf() * TAU
		var r := rng.randf_range(8.0, 24.0)
		var pos := Vector3(cos(a) * r, 0.0, sin(a) * r)
		# Deja libre el camino
		var too_close := false
		for c in _pivot.get_children():
			if c is Node3D and (c as Node3D).position.distance_to(pos) < 1.6:
				too_close = true
				break
		if too_close:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = SC.get_mesh("", ids[rng.randi() % ids.size()], pal)
		mi.position = pos
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * rng.randf_range(1.4, 2.2)
		_pivot.add_child(mi)
	for k in 6:
		var a := k * TAU / 6.0 + 0.4
		var house := MeshInstance3D.new()
		house.mesh = SC.get_mesh("", "house_stone" if k % 2 == 0 else "windmill_body", pal)
		house.position = Vector3(cos(a) * 18.0, 0.0, sin(a) * 18.0)
		house.scale = Vector3.ONE * 2.2
		house.rotation.y = -a
		_pivot.add_child(house)
	for k in 12:
		var a := k * TAU / 12.0
		var m := MeshInstance3D.new()
		m.mesh = SC.get_mesh("", "mountain" if k % 3 else "mountain_snow", pal)
		m.position = Vector3(cos(a) * 40.0, -1.0, sin(a) * 40.0)
		m.scale = Vector3.ONE * rng.randf_range(9.0, 14.0)
		m.rotation.y = rng.randf() * TAU
		_pivot.add_child(m)
	preload("res://scripts/towers3d/models.gd").facet_tree(_pivot)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	# Mira a la izquierda del castillo: así queda a la derecha de la pantalla, junto al menú
	cam.look_at_from_position(Vector3(-7.0, 12.0, 25.0), Vector3(-8.5, 1.5, 0.0), Vector3.UP)
	cam.current = true
