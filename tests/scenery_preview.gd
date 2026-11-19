extends Node3D
## Vista previa del paisaje de un mapa: tablero sencillo + Scenery.build + captura.
## Uso: godot --path . res://tests/scenery_preview.tscn -- <idx> [game|close]
## Guarda user://screens/scenery_<idx>[_modo].png

func _ready() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	var idx := 0
	if args.size() > 0:
		idx = int(args[0])
	var mode: String = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute("user://screens")
	var info: Dictionary = MapGen.generate(idx)
	var map_def: Dictionary = GameData.MAPS[idx]
	var cols: int = info["cols"]
	var rows: int = info["rows"]
	var ground: Color = map_def["ground"]
	var path_col: Color = map_def["path"]
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = ground.darkened(0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.82, 0.95)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -40, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	world.add_child(sun)
	# Tablero como en game.gd
	V3.box(Vector3(cols + 0.5, 0.6, rows + 0.5), ground.darkened(0.45), Vector3(0, -0.42, 0), 0.0, world)
	var path_cells: Dictionary = info["path_cells"]
	var water: Dictionary = info["water"]
	var obstacles: Dictionary = info["obstacles"]
	for x in cols:
		for y in rows:
			var c := Vector2i(x, y)
			if path_cells.has(c) or water.has(c) or obstacles.has(c):
				continue
			var center := MapGen.cell_to_3d(c, cols, rows)
			var tc := ground.lightened(0.05) if (x + y) % 2 == 0 else ground
			V3.box(Vector3(0.96, 0.12, 0.96), tc, center + Vector3(0, -0.06, 0), 0.0, world)
	for c in path_cells.keys():
		var center := MapGen.cell_to_3d(c, cols, rows)
		V3.box(Vector3(1.0, 0.06, 1.0), path_col, center + Vector3(0, -0.09, 0), 0.0, world)
	var exit: Vector2i = info["exit"]
	var castle := V3.build_castle()
	castle.position = MapGen.cell_to_3d(exit, cols, rows) + Vector3(0, 0, 0.9)
	castle.rotation.y = -PI * 0.5
	world.add_child(castle)
	for pts in info["paths"]:
		var a: Vector2i = pts[0]
		var portal := V3.torus(0.38, 0.48, Color(0.65, 0.3, 1.0), MapGen.cell_to_3d(a, cols, rows, 0.5), 2.5, world)
		portal.rotation.x = PI * 0.5
	var t0 := Time.get_ticks_msec()
	var sc := Scenery.build(world, info, map_def)
	print("Scenery.build: %d ms, nodos: %d" % [Time.get_ticks_msec() - t0, _count(sc)])
	if "detail" in args:
		var line := ""
		for ch in sc.get_children():
			var surf := 1
			var inst := 1
			if ch is MultiMeshInstance3D:
				surf = (ch as MultiMeshInstance3D).multimesh.mesh.get_surface_count()
				inst = (ch as MultiMeshInstance3D).multimesh.instance_count
			elif ch is MeshInstance3D and (ch as MeshInstance3D).mesh != null:
				surf = (ch as MeshInstance3D).mesh.get_surface_count()
			line += "%s:%dx%d " % [ch.name, surf, inst]
		print(line)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 47.0
	world.add_child(cam)
	if mode == "game":
		var k := (cols + 0.5) / 9.5
		cam.look_at_from_position(Vector3(0, 0, 3.2) + (Vector3(0, 16.5, 9.9) - Vector3(0, 0, 3.2)) * k, Vector3(0, 0, 3.2 * k * 0.5), Vector3.UP)
	elif mode == "close":
		cam.look_at_from_position(Vector3(0, 6, rows * 0.5 + 7.0), Vector3(0, 0, rows * 0.5 - 1.0), Vector3.UP)
	else:
		var target := Vector3(0, 0, 1.5)
		var dist := 19.0 + cols * 0.5
		var ang := deg_to_rad(55.0)
		cam.look_at_from_position(target + Vector3(0, sin(ang), cos(ang)) * dist, target, Vector3.UP)
	cam.current = true
	sc.visible = false
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var base_calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	sc.visible = true
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	print("draw calls: %d (paisaje: %d)  primitivas: %d" % [calls, calls - base_calls, prims])
	var name := "scenery_%d%s" % [idx, ("_" + mode) if mode != "" else ""]
	get_viewport().get_texture().get_image().save_png("user://screens/%s.png" % name)
	print("saved ", ProjectSettings.globalize_path("user://screens/%s.png" % name))
	get_tree().quit()


func _count(n: Node) -> int:
	var t := 1
	for c in n.get_children():
		t += _count(c)
	return t
