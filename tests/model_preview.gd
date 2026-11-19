extends Node3D
## Renderiza los modelos de torre en fila y guarda una captura en user://screens/models.png.
## Uso: godot --path . res://tests/model_preview.tscn [-- id1 id2 ...]

func _ready() -> void:
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = GameData.TOWERS.keys()
	# "tiers": cada torre en sus 4 etapas de nivel (0, 2, 4, 5) en una fila
	var levels: Array = []
	var heroes := "heroes" in ids
	if heroes:
		ids = GameData.HEROES.keys()
	if "tiers" in ids:
		ids.erase("tiers")
		var expanded: Array = []
		for id in ids:
			for lv in [0, 2, 4, 5]:
				expanded.append(id)
				levels.append(lv)
		ids = expanded
	DirAccess.make_dir_recursive_absolute("user://screens")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.7, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.95)
	e.ambient_light_energy = 0.55
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var cols := 5 if heroes else (4 if not levels.is_empty() else mini(ids.size(), 3))
	var spacing := 1.6
	for i in ids.size():
		var id: String = ids[i]
		var lv: int = levels[i] if not levels.is_empty() else 3
		var m: Node3D = V3.build_hero(id) if heroes else TowerModels.build(id, lv)
		var x := (i % cols - (cols - 1) * 0.5) * spacing
		var z := float(i / cols) * spacing * 1.25
		m.position = Vector3(x, 0, z)
		m.rotation.y = -PI * 0.5 if heroes else PI # el personaje mira hacia la cámara
		add_child(m)
		if not heroes:
			TowerModels.animate(m, {"t": 0.4, "charge": 0.6, "fire": 0.0, "has_target": true})
		var lbl := Label3D.new()
		lbl.text = id if levels.is_empty() else "%s nv%d" % [id, lv]
		lbl.font_size = 40
		lbl.pixel_size = 0.004
		lbl.position = Vector3(x, -0.15, z + 0.6)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(lbl)
	var rows := ceili(ids.size() / float(cols))
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 50
	add_child(cam)
	var cz := (rows - 1) * spacing * 1.25 * 0.5
	cam.look_at_from_position(Vector3(0, 3.2 + rows * 1.2, cz + 3.5 + rows * 1.6), Vector3(0, 0.7, cz), Vector3.UP)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var uargs := Array(OS.get_cmdline_user_args())
	var name := "models" if uargs.is_empty() else "models_" + "_".join(uargs)
	get_viewport().get_texture().get_image().save_png("user://screens/%s.png" % name)
	print("saved ", ProjectSettings.globalize_path("user://screens/%s.png" % name))
	get_tree().quit()
