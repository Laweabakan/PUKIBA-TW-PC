extends Node3D
## Renderiza los enemigos de uno o varios mapas (15 + jefe + una copia élite) con etiquetas
## y guarda capturas en user://screens/enemies_<mapa>.png.
## Uso: godot --path . res://tests/enemy_preview.tscn [-- 0 1 2 ...] (sin argumentos: todos)
## "base" muestra los enemigos genéricos antiguos (BASE_ENEMIES).

const EnemyModelsScript := preload("res://scripts/game/enemy_models.gd")
const COLS := 2
const CELL := 1.5


func _ready() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	if args.is_empty():
		for i in GameData.THEMED.size():
			args.append(str(i))
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
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(cam)
	for a in args:
		var ids: Array = []
		var tag := str(a)
		if tag.contains(","):
			ids = Array(tag.split(","))
		elif tag == "base":
			for id in GameData.BASE_ENEMIES.keys():
				ids.append(id)
		else:
			var mi := int(tag)
			for k in 15:
				ids.append("m%d_%d" % [mi, k])
			ids.append("m%d_boss" % mi)
		var all_cells: Array = ids.duplicate()
		if not tag.contains(","):
			all_cells.append(ids[0])  # copia élite
		var pages := ceili(all_cells.size() / 6.0)
		for pg in pages:
			await _page(cam, tag + ("" if pages == 1 else "_%d" % pg), all_cells.slice(pg * 6, pg * 6 + 6), pg == pages - 1)
	get_tree().quit()


func _page(cam: Camera3D, tag: String, cells: Array, last_elite: bool) -> void:
		var holder := Node3D.new()
		add_child(holder)
		var t0 := Time.get_ticks_msec()
		for i in cells.size():
			var id: String = cells[i]
			if not GameData.ENEMIES.has(id):
				continue
			var def: Dictionary = GameData.ENEMIES[id]
			var elite := last_elite and i == cells.size() - 1
			var r := float(def.get("size", 0.25))
			var m: Node3D = EnemyModelsScript.build(id, def, r, elite)
			var x := (i % COLS - (COLS - 1) * 0.5) * CELL
			var z := float(i / COLS) * CELL * 1.15
			var fly := bool(def.get("flying", false))
			m.position = Vector3(x, 0.55 if fly else 0.0, z)
			m.rotation.y = -0.55
			holder.add_child(m)
			if m.has_method("animate"):
				m.animate(0.3 + i * 0.37, true, false)
			var lbl := Label3D.new()
			lbl.text = "%s%s\n%s r%.2f%s" % [def.get("name", id), " (ÉLITE)" if elite else "", id, r, " vuela" if fly else ""]
			lbl.font_size = 28
			lbl.outline_size = 8
			lbl.pixel_size = 0.0035
			lbl.position = Vector3(x, -0.12, z + 0.5)
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			holder.add_child(lbl)
		print("build %s: %d ms" % [tag, Time.get_ticks_msec() - t0])
		var rows := ceili(cells.size() / float(COLS))
		var cz := (rows - 1) * CELL * 1.15 * 0.5
		cam.look_at_from_position(Vector3(0, 3.0, cz + 4.4), Vector3(0, 0.4, cz + 0.9), Vector3.UP)
		for f in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "user://screens/enemies_%s.png" % tag
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		holder.queue_free()
		await get_tree().process_frame
