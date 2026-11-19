class_name MapGen
extends RefCounted
## Generador determinista de mapas (misma semilla -> mismo mapa, así las partidas guardadas
## siguen siendo válidas). Pantalla vertical: los enemigos entran por arriba o por los lados
## y el castillo está abajo. Con varias entradas, los caminos se juntan en un cruce y
## siguen por un tronco común hasta el castillo.
##
## Resultado de generate(map_idx):
##   cols, rows: tamaño de la cuadrícula
##   paths: Array de caminos; cada camino es Array[Vector2i] de puntos de giro
##          (el primero y el último quedan fuera de la cuadrícula)
##   path_cells: {Vector2i: Vector2i dirección}  (incluye casillas fuera del tablero)
##   water: {Vector2i: true}   casillas de agua/lava/hielo (no construibles)
##   bridges: {Vector2i: Vector2i dirección del camino}  casillas de camino sobre el agua
##   obstacles: {Vector2i: String}  rocas, árboles, ruinas... (no construibles)
##   junction: Vector2i (o (-99,-99) si hay una sola entrada)
##   exit: Vector2i (punto final fuera del tablero, bajo el castillo)
##   theme: String (id de la temática del mapa)

const VERSION := 3 # cambiar si se altera la generación (invalida partidas guardadas)

## Disposición de cada mapa (versión de PC): tablero ancho (ocupa toda la pantalla horizontal) y
## alargado en vertical: los enemigos entran por arriba y el castillo está abajo. Más grandes que en el móvil, con más
## entradas (más caminos) y cada mapa algo más grande y complejo que el anterior.
static func layout(map_idx: int) -> Dictionary:
	var i := clampi(map_idx, 0, 19)
	var cols := 20 + i / 3                     # 20 -> 26 columnas: llenan el ancho de la pantalla
	var rows := 32 + i                         # 32 -> 51 filas: el mapa es alargado en vertical (se recorre con la cámara)
	var entries := 2 if i < 3 else (3 if i < 10 else 4)
	var water := "river" if i % 2 == 0 else "lake"
	if i >= 12:
		water = "both"
	return {
		"size": Vector2i(cols, rows),
		"entries": entries,
		"water": water,
		"obstacles": 0.06 + i * 0.005,         # 6% -> 15.5%
		"zigzag": 4 - i / 7,                    # tramos verticales más cortos = más curvas
	}


static var _cache := {}
static var _zigzag := 4


static func generate(map_idx: int) -> Dictionary:
	if _cache.has(map_idx):
		return _cache[map_idx]
	var lay: Dictionary = layout(map_idx)
	var result := {}
	for attempt in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("mapa:%d:%d:%d" % [map_idx, VERSION, attempt])
		result = _try_generate(map_idx, lay, rng)
		if not result.is_empty():
			break
	if result.is_empty():
		push_error("MapGen: no se pudo generar el mapa %d" % map_idx)
	else:
		result["heights"] = _make_heights(map_idx, result)
	_cache[map_idx] = result
	return result


static func _try_generate(map_idx: int, layout: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	_zigzag = int(layout.get("zigzag", 4))
	var size: Vector2i = layout["size"]
	var cols := size.x
	var rows := size.y
	var n_entries := int(layout["entries"])
	var paths: Array = []
	var junction := Vector2i(-99, -99)

	# Salida (castillo) abajo
	var exit_x := rng.randi_range(2, cols - 3)
	var exit_pt := Vector2i(exit_x, rows)

	if n_entries == 1:
		var start := Vector2i(rng.randi_range(1, cols - 2), -1)
		var pts := _serpentine(start, exit_pt, 1, cols - 2, rows, rng)
		if pts.is_empty():
			return {}
		paths.append(pts)
	else:
		# Cruce donde se juntan las entradas
		var jy := int(rows * rng.randf_range(0.5, 0.62))
		var jx := cols / 2 + rng.randi_range(-1, 1)
		junction = Vector2i(jx, jy)
		var trunk := _serpentine(junction, exit_pt, 1, cols - 2, rows, rng)
		if trunk.is_empty():
			return {}
		# Bandas verticales para cada entrada
		var bands: Array = []
		if n_entries == 2:
			bands = [[1, jx - 2], [jx + 2, cols - 2]]
		else:
			# 3 o más entradas: franjas iguales separadas por una columna libre
			var wdt := cols / n_entries
			for k in n_entries:
				var lo_k := k * wdt + 1
				var hi_k := (k + 1) * wdt - 1 if k < n_entries - 1 else cols - 2
				bands.append([lo_k, hi_k])
		for b in bands.size():
			var lo: int = bands[b][0]
			var hi: int = bands[b][1]
			if hi - lo < 1:
				return {}
			var start: Vector2i
			var side_entry := n_entries >= 3 and (b == 0 or b == bands.size() - 1) and rng.randf() < 0.5
			if side_entry:
				# Entrada lateral (por la pared izquierda o derecha)
				var ey := rng.randi_range(1, maxi(2, jy / 3))
				start = Vector2i(-1 if b == 0 else cols, ey)
			else:
				start = Vector2i(rng.randi_range(lo, hi), -1)
			var branch := _branch(start, junction, lo, hi, rng)
			if branch.is_empty():
				return {}
			# Camino completo = rama + tronco (sin repetir el cruce)
			var full: Array = branch.duplicate()
			for k in range(1, trunk.size()):
				full.append(trunk[k])
			paths.append(full)

	# Casillas de camino y validación de cruces
	var path_cells := {}
	var owner := {}
	for pi in paths.size():
		var pts: Array = paths[pi]
		for i in range(1, pts.size()):
			var a: Vector2i = pts[i - 1]
			var b2: Vector2i = pts[i]
			var dir := Vector2i(signi(b2.x - a.x), signi(b2.y - a.y))
			if dir.x != 0 and dir.y != 0:
				return {}
			var cur := a
			while true:
				if not path_cells.has(cur):
					path_cells[cur] = dir
				if _inside(cur, cols, rows):
					var o: int = owner.get(cur, -1)
					if o == -1:
						owner[cur] = pi
					elif o != pi and not _on_trunk(cur, junction, paths):
						return {} # dos ramas se tocan fuera del tronco común
				if cur == b2:
					break
				cur += dir
	if not _branches_separated(paths, path_cells, junction, cols, rows):
		return {}

	# Agua
	var water := {}
	var bridges := {}
	match layout["water"]:
		"river":
			_make_river(water, path_cells, cols, rows, rng)
		"lake":
			_make_lake(water, path_cells, cols, rows, rng)
		"both":
			_make_river(water, path_cells, cols, rows, rng)
			_make_lake(water, path_cells, cols, rows, rng)
	for c in water.keys():
		if path_cells.has(c):
			bridges[c] = path_cells[c]
			water.erase(c)
	# Demasiados puentes = el río va paralelo a un camino: reintentar
	var bridge_cells := 0
	for c in bridges.keys():
		if _inside(c, cols, rows):
			bridge_cells += 1
	if bridge_cells > 6:
		return {}

	# Obstáculos (dejan libres muchas casillas junto al camino para construir)
	var obstacles := {}
	var density := float(layout["obstacles"])
	var kinds := ["rock", "tree", "tree", "ruin", "log"]
	for x in cols:
		for y in rows:
			var c := Vector2i(x, y)
			if path_cells.has(c) or water.has(c):
				continue
			var near := _near_path(c, path_cells)
			var p := density * (0.35 if near else 1.6)
			if rng.randf() < p:
				obstacles[c] = kinds[rng.randi() % kinds.size()]
	# Un par de árboles y rocas más (se pueden demoler por oro para liberar la casilla)
	var extra := ["tree", "tree", "rock", "rock"]
	for tries in 200:
		if extra.is_empty():
			break
		var c3 := Vector2i(rng.randi() % cols, rng.randi() % rows)
		if path_cells.has(c3) or water.has(c3) or obstacles.has(c3):
			continue
		obstacles[c3] = extra.pop_back()
	# Garantiza un mínimo de casillas construibles junto al camino
	var buildable := 0
	for x in cols:
		for y in rows:
			var c2 := Vector2i(x, y)
			if not path_cells.has(c2) and not water.has(c2) and not obstacles.has(c2) and _near_path(c2, path_cells):
				buildable += 1
	if buildable < 30:
		return {}

	return {
		"cols": cols, "rows": rows, "paths": paths, "path_cells": path_cells,
		"water": water, "bridges": bridges, "obstacles": obstacles,
		"junction": junction, "exit": exit_pt, "theme": GameData.MAPS[map_idx]["deco"],
		"water_kind": theme_water(GameData.MAPS[map_idx]["deco"]),
	}


## Colinas: casillas construibles elevadas exactamente una casilla (1.0).
## Una torre en lo alto gana alcance. No toca caminos, agua ni obstáculos.
## Usa su propia semilla para no alterar el resto del mapa.
static func _make_heights(map_idx: int, info: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("alturas:%d" % map_idx)
	var cols: int = info["cols"]
	var rows: int = info["rows"]
	var heights := {}
	var free: Array = []
	for x in cols:
		for y in rows:
			var c := Vector2i(x, y)
			if not info["path_cells"].has(c) and not info["water"].has(c) and not info["obstacles"].has(c) and not info["bridges"].has(c):
				free.append(c)
	if free.is_empty():
		return heights
	# Varias colinas repartidas por el tablero (de una casilla suelta a mesetas de 3-4 de ancho),
	# siempre de una casilla de altura. Tope: ~28% de las casillas construibles.
	var hills := 5 + map_idx / 4 + rng.randi() % 3
	var max_cells := int(free.size() * 0.28)
	var centers: Array = []
	for k in hills:
		if heights.size() >= max_cells:
			break
		# Elige el centro más alejado de las colinas ya puestas entre unos cuantos candidatos
		var center: Vector2i = free[rng.randi() % free.size()]
		var best := -1.0
		for tries in 6:
			var cand: Vector2i = free[rng.randi() % free.size()]
			var dmin := 999.0
			for o in centers:
				dmin = minf(dmin, Vector2(cand - o).length())
			if dmin > best:
				best = dmin
				center = cand
		centers.append(center)
		var r := rng.randf_range(0.5, 2.0)
		for c in free:
			if Vector2(c - center).length() <= r:
				heights[c] = 1.0 # solo dos alturas: llano (0) o una casilla (1)
	return heights


## Camino en zigzag que baja desde `start` hasta `goal` dentro de las columnas [lo, hi].
static func _serpentine(start: Vector2i, goal: Vector2i, lo: int, hi: int, rows: int, rng: RandomNumberGenerator) -> Array:
	var pts: Array = [start]
	var cur := start
	if cur.y < 0:
		cur = Vector2i(cur.x, 0)
		pts.append(cur)
	var target_row := goal.y - 1 if goal.y >= rows else goal.y
	var guard := 0
	while target_row - cur.y > 2 and guard < 40:
		guard += 1
		var step := rng.randi_range(2, maxi(2, _zigzag))
		var ny := mini(cur.y + step, target_row - 1)
		if ny != cur.y:
			cur = Vector2i(cur.x, ny)
			pts.append(cur)
		var nx := cur.x
		for t in 10:
			nx = rng.randi_range(lo, hi)
			if absi(nx - cur.x) >= 3:
				break
		if nx != cur.x:
			cur = Vector2i(nx, cur.y)
			pts.append(cur)
	# Último tramo: alinearse con la meta y bajar
	if cur.y != target_row:
		cur = Vector2i(cur.x, target_row)
		pts.append(cur)
	if cur.x != goal.x:
		cur = Vector2i(goal.x, cur.y)
		pts.append(cur)
	if cur != goal:
		pts.append(goal)
	return _simplify(pts)


## Rama de una entrada hasta el cruce: baja en zigzag dentro de su banda y luego va al cruce.
static func _branch(start: Vector2i, junction: Vector2i, lo: int, hi: int, rng: RandomNumberGenerator) -> Array:
	var pts: Array = [start]
	var cur := start
	if start.x < 0 or start.x > hi + 5:
		# entrada lateral: avanzar hacia dentro de la banda
		cur = Vector2i(clampi(rng.randi_range(lo, hi), lo, hi), start.y)
		pts.append(cur)
	elif start.y < 0:
		cur = Vector2i(start.x, 0)
		pts.append(cur)
	var stop_row := junction.y - 2
	var guard := 0
	while stop_row - cur.y > 2 and guard < 30:
		guard += 1
		var ny := mini(cur.y + rng.randi_range(2, 3), stop_row)
		cur = Vector2i(cur.x, ny)
		pts.append(cur)
		if hi - lo >= 2:
			var nx := cur.x
			for t in 8:
				nx = rng.randi_range(lo, hi)
				if absi(nx - cur.x) >= 2:
					break
			if nx != cur.x:
				cur = Vector2i(nx, cur.y)
				pts.append(cur)
	# Bajar hasta la fila del cruce y girar hacia él
	cur = Vector2i(cur.x, junction.y)
	pts.append(cur)
	if cur.x != junction.x:
		pts.append(junction)
	return _simplify(pts)


static func _simplify(pts: Array) -> Array:
	var out: Array = []
	for p in pts:
		if out.is_empty() or out[out.size() - 1] != p:
			out.append(p)
	# quita puntos intermedios alineados
	var i := 1
	while i < out.size() - 1:
		var a: Vector2i = out[i - 1]
		var b: Vector2i = out[i]
		var c: Vector2i = out[i + 1]
		if (a.x == b.x and b.x == c.x) or (a.y == b.y and b.y == c.y):
			out.remove_at(i)
		else:
			i += 1
	return out


static func _inside(c: Vector2i, cols: int, rows: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


static func _on_trunk(c: Vector2i, junction: Vector2i, _paths: Array) -> bool:
	return junction.x > -50 and c.y >= junction.y


## Las ramas no deben ir pegadas entre sí (dejan sitio para construir entre ellas).
static func _branches_separated(paths: Array, _cells: Dictionary, junction: Vector2i, cols: int, rows: int) -> bool:
	if paths.size() < 2:
		return true
	var sets: Array = []
	for pts in paths:
		var s := {}
		for i in range(1, pts.size()):
			var a: Vector2i = pts[i - 1]
			var b: Vector2i = pts[i]
			var dir := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
			var cur := a
			while true:
				if _inside(cur, cols, rows) and cur.y < junction.y - 1:
					s[cur] = true
				if cur == b:
					break
				cur += dir
		sets.append(s)
	for i in sets.size():
		for j in range(i + 1, sets.size()):
			for c in sets[i].keys():
				for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if sets[j].has(c + d):
						return false
	return true


static func _near_path(c: Vector2i, path_cells: Dictionary) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if path_cells.has(c + Vector2i(dx, dy)):
				return true
	return false


static func _make_river(water: Dictionary, path_cells: Dictionary, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	# Río que cruza de lado a lado (se prolonga fuera del tablero para el paisaje)
	var best_row := -1
	var best_overlap := 9999
	var phase := rng.randf() * TAU
	for t in 12:
		var base := rng.randi_range(3, rows - 5)
		var overlap := 0
		for x in range(-6, cols + 6):
			var y := base + int(round(sin(x * 0.55 + phase) * 1.3))
			if path_cells.has(Vector2i(x, y)):
				overlap += 1
		if overlap < best_overlap:
			best_overlap = overlap
			best_row = base
	var width := 1 if rng.randf() < 0.6 else 2
	for x in range(-6, cols + 6):
		var y := best_row + int(round(sin(x * 0.55 + phase) * 1.3))
		for w in width:
			water[Vector2i(x, y + w)] = true
		# une los saltos verticales del meandro
		var y2 := best_row + int(round(sin((x + 1) * 0.55 + phase) * 1.3))
		for yy in range(mini(y, y2), maxi(y, y2) + 1):
			water[Vector2i(x, yy)] = true


static func _make_lake(water: Dictionary, path_cells: Dictionary, cols: int, rows: int, rng: RandomNumberGenerator) -> void:
	for t in 20:
		var cx := rng.randf_range(1.5, cols - 2.5)
		var cy := rng.randf_range(2.5, rows - 3.5)
		var rx := rng.randf_range(1.2, 2.2)
		var ry := rng.randf_range(1.2, 2.4)
		var cells: Array = []
		var hits := 0
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
				var dx := (x + 0.5 - cx) / rx
				var dy := (y + 0.5 - cy) / ry
				if dx * dx + dy * dy <= 1.0:
					var c := Vector2i(x, y)
					if path_cells.has(c) or _near_path(c, path_cells):
						hits += 1
					cells.append(c)
		if hits == 0 and cells.size() >= 4:
			for c in cells:
				if _inside(c, cols, rows):
					water[c] = true
			return


## Tipo de "agua" según la temática (el paisaje lo dibuja con su propio material).
static func theme_water(theme: String) -> String:
	match theme:
		"volcano", "hellfire", "abyss_gate": return "lava"
		"glacier", "frost_mountains", "ice_throne": return "ice"
		"swamp", "lich_citadel", "graveyard": return "swamp"
		"void_abyss", "chaos_citadel": return "void"
		"sky_islands": return "sky"
		"ash_desert": return "oasis"
		_: return "water"


## Celda (cuadrícula) -> posición 3D del centro de la casilla, para un tablero cols x rows.
static func cell_to_3d(c: Vector2i, cols: int, rows: int, h := 0.0) -> Vector3:
	return Vector3(c.x + 0.5 - cols * 0.5, h, c.y + 0.5 - rows * 0.5)
