class_name Tower
extends Node2D
## Torre o héroe colocado en la cuadrícula. Las mejoras de nivel (0-5) solo
## duran la partida actual; el nivel de carta y las mejoras globales son permanentes.

const TARGET_MODES := ["first", "strong", "close", "last"]
const TARGET_NAMES := {"first": "Primero", "strong": "Más fuerte", "close": "Cercano", "last": "Último"}

var game: Node
var id := ""
var def: Dictionary = {}
var is_hero := false
var is_card := false # torre de sobre: línea evolutiva propia (nivel de carta)
var speed_aura_mult := 1.0 # Campanario cercano: ataca más rápido
var range_aura_mult := 1.0 # Torre del Heraldo cercana: más alcance
var level := 0
var cell := Vector2i.ZERO
var spent := 0
var cooldown := 0.0
var target_mode := "first"
var aura_mult := 1.0 # recalculado por el juego (Santuario)
var ability_cd := 0.0
var selected := false
var _aim := 0.0
var _anim := 0.0
var _recoil := 0.0


func setup(g: Node, tower_id: String, c: Vector2i, hero := false) -> void:
	game = g
	id = tower_id
	is_hero = hero
	def = GameData.HEROES[id] if hero else GameData.TOWERS[id]
	# Torres de cartas (sobres): su nivel es el de la carta (1..5, con copias); no se mejoran con oro
	is_card = not hero and not Meta.is_progress_tower(id)
	cell = c
	position = GameData.cell_center(c)


# ---------------------------------------------------------------- Estadísticas
## ¿Tiene la Maestría? Torres de oro: nivel 15 en la partida. Torres de cartas: carta al nivel 5.
func mastered() -> bool:
	if is_card:
		return Save.card_level(id) >= GameData.MAX_CARD_LEVEL
	return level >= GameData.MAX_TOWER_LEVEL


## Nivel visual (0..5) del modelo 3D.
func view_level() -> int:
	if is_card:
		return [0, 0, 2, 3, 4, 5][clampi(Save.card_level(id), 0, 5)]
	return GameData.visual_level(level)


func stat(key: String, default_value = 0.0):
	if mastered() and def.has("perks") and def["perks"].has(key):
		return def["perks"][key]
	return def.get(key, default_value)


func damage() -> float:
	var d := float(def.get("damage", 0.0))
	d *= 1.0 + 0.2 * level
	d *= Meta.card_power(id)
	d *= pack_mult() # las torres de sobre son más fuertes
	d *= 1.0 + Save.upgrade_value("damage")
	d *= 1.0 + Save.gem_upgrade_value("g_damage")
	if is_hero:
		d *= 1.0 + Save.upgrade_value("hero")
	d *= aura_mult * game.global_damage_mult()
	return d


## Bonificación de las torres de cartas (sobres) frente a las de oro.
func pack_mult() -> float:
	if is_hero or Meta.is_progress_tower(id):
		return 1.0
	return float(GameData.PACK_TOWER_BONUS.get(def["rarity"], 1.5))


func range_px() -> float:
	var r := float(def.get("range", 0.0)) * (1.0 + 0.03 * level)
	if pack_mult() > 1.0:
		r *= GameData.PACK_TOWER_RANGE
	r *= range_aura_mult
	if game != null:
		r *= 1.0 + game.HEIGHT_RANGE_BONUS * game.cell_h(cell) # en lo alto de una colina ve más lejos
	r *= 1.0 + Save.upgrade_value("range")
	return r * GameData.TILE


func rate() -> float:
	var r := float(def.get("rate", 0.0)) * (1.0 + 0.04 * level) * speed_aura_mult
	r *= 1.0 + Save.upgrade_value("speed")
	return r * game.global_speed_mult()


func upgrade_cost() -> int:
	if is_hero:
		return -1 if level >= GameData.HERO_MAX_LEVEL else 0 # los héroes suben con gemas
	if is_card or level >= GameData.MAX_TOWER_LEVEL:
		return -1 # las torres de cartas suben juntando cartas, no con oro
	var base := 120 if is_hero else int(def["cost"])
	var c := int(base * (0.7 + 0.36 * level)) # el doble que antes: el oro es uno solo y sobra
	if level == GameData.MAX_TOWER_LEVEL - 1:
		c *= 3 # la Maestría (nivel 15) ya no pide gemas, pero cuesta el triple de oro
	return game.discounted(c)


## Gemas necesarias para la siguiente mejora: solo los héroes (nivel permanente).
## Las torres llegan a la Maestría (nivel 15) solo con oro.
func upgrade_gem_cost() -> int:
	if is_hero:
		return Meta.hero_level_cost(id) if level < GameData.HERO_MAX_LEVEL else 0
	return 0


func sell_value() -> int:
	return int(spent * 0.7)


func can_attack() -> bool:
	return float(def.get("rate", 0.0)) > 0.0


## (Sin uso: el oro solo se gana matando enemigos.)
func gold_per_wave() -> int:
	if not def.has("gold_per_wave"):
		return 0
	var g := int(def["gold_per_wave"]) + 15 * level + int(stat("gold_bonus", 0))
	return int(g * Meta.card_power(id))


func can_target(e: Enemy) -> bool:
	if e.dead:
		return false
	if not e.is_revealed() and not bool(def.get("detect", false)):
		return false # invisible: solo torres detectoras (o reveladas por un Santuario)
	if e.flying:
		return is_hero or bool(def.get("air", false))
	return is_hero or bool(def.get("ground", true))


# ---------------------------------------------------------------- Bucle
func _process(delta: float) -> void:
	_anim += delta
	if game == null:
		return
	_recoil = maxf(_recoil - delta * 5.0, 0.0)
	if is_hero and ability_cd > 0.0:
		ability_cd -= delta
	_update_view(delta)
	if not can_attack():
		return
	if def.get("model", id) in ["mage", "frost"]:
		# Torres que cargan (maga de fuego, mago de hielo): sin objetivo, la carga se apaga.
		var period := 1.0 / maxf(rate(), 0.01)
		var found := find_targets()
		_has_target = not found.is_empty()
		if not _has_target:
			cooldown = minf(cooldown + delta * 0.4, period)
			_process_salvo(delta)
			return
	cooldown = maxf(cooldown - delta, 0.0)
	if cooldown <= 0.0:
		var targets := find_targets()
		_has_target = not targets.is_empty()
		if not targets.is_empty():
			attack(targets)
			cooldown = 1.0 / maxf(rate(), 0.01)
	_process_salvo(delta)


func find_targets() -> Array:
	var r := range_px()
	var best: Enemy = null
	var best_score := -INF
	for e in game.enemies:
		var en: Enemy = e
		if not can_target(en):
			continue
		var dist := position.distance_to(en.position)
		if dist > r + en.radius:
			continue
		var score := 0.0
		match target_mode:
			"first": score = en.progress
			"last": score = -en.progress
			"strong": score = en.hp
			"close": score = -dist
		# El arquero venenoso prefiere enemigos sin veneno y el mago de hielo, no congelados.
		match def.get("prefer", ""):
			"unpoisoned":
				for d in en.dots:
					if d["type"] == "poison":
						score -= 1e9
			"unfrozen":
				if en.stun_time > 0.0:
					score -= 1e9
		if score > best_score:
			best_score = score
			best = en
	if best == null:
		return []
	var out: Array = [best]
	var multishot := int(stat("multishot", 1))
	if multishot > 1:
		for e in game.enemies:
			if out.size() >= multishot:
				break
			if e != best and can_target(e) and position.distance_to(e.position) <= r:
				out.append(e)
	return out


func make_payload() -> Dictionary:
	var crit := Save.upgrade_value("crit") + float(stat("crit_bonus", 0.0))
	var dmg := damage()
	var is_crit := randf() < crit
	if is_crit:
		dmg *= 2.0
	return {
		"damage": dmg,
		"type": def.get("dmg_type", "physical"),
		"crit": is_crit,
		"splash": float(stat("splash", 0.0)) * GameData.TILE,
		"slow": float(stat("slow", 0.0)),
		"slow_dur": float(stat("slow_dur", 0.0)),
		"dot": float(stat("dot", 0.0)) * (1.0 + 0.2 * level) * Meta.card_power(id) * pack_mult() * (1.0 + Save.upgrade_value("damage")),
		"dot_dur": float(stat("dot_dur", 0.0)),
		"stun_chance": float(stat("stun_chance", 0.0)),
		"stun_dur": float(stat("stun_dur", 0.0)),
		"air_bonus": float(stat("air_bonus", 1.0)),
		"execute": float(stat("execute", 0.0)),
		"armor_break": float(stat("armor_break", 0.0)),
		"chain": int(stat("chain", 0)),
		"air_ok": is_hero or bool(def.get("air", false)),
		"ground_ok": is_hero or bool(def.get("ground", true)),
	}


const SALVO_GAP := 0.12
const SALVO_SPREAD := 0.28 # casillas

var _salvo_left := 0
var _salvo_timer := 0.0
var _salvo_aim := Vector2.ZERO
var _tubes: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]


func attack(targets: Array) -> void:
	_recoil = 1.0
	var first: Enemy = targets[0]
	_aim = (first.position - position).angle()
	if def.has("rockets"):
		# Salva de cohetes que caen alrededor del punto donde está el enemigo
		_salvo_left = int(stat("rockets", 6))
		_salvo_timer = 0.0
		_salvo_aim = first.position
		return
	var style: String = def.get("projectile", "")
	Audio.shot(style)
	var muzzle := _muzzle()
	for t in targets:
		var payload := make_payload()
		if style == "":
			# Ataque instantáneo (rayo en cadena, raíces del druida).
			game.resolve_hit(payload, t, t.position, muzzle[0], muzzle[1])
		else:
			game.spawn_projectile(muzzle[0], muzzle[1], t, payload, style)


func _process_salvo(delta: float) -> void:
	if _salvo_left <= 0:
		return
	_salvo_timer -= delta
	if _salvo_timer > 0.0:
		return
	_salvo_timer = SALVO_GAP
	_salvo_left -= 1
	var tube := _salvo_left % _tubes.size()
	_tubes[tube] = 1.0
	var a := randf() * TAU
	var spot := _salvo_aim + Vector2(cos(a), sin(a)) * randf() * SALVO_SPREAD * GameData.TILE
	var m := _muzzle(tube)
	game.spawn_projectile(m[0], m[1], null, make_payload(), "rocket", spot)
	Audio.shot("rocket")


## [posición en el plano, altura] de la boca del arma del modelo.
func _muzzle(tube := 0) -> Array:
	if is_hero or view == null:
		return [position, 0.6]
	var g := TowerModels.muzzle(view, tube)
	return [V3.to2(g), g.y]


# ---------------------------------------------------------------- Vista 3D
var view: Node3D
var _turret: Node3D
var _barrel: Node3D
var _ready_mark: Node3D
var _range_disc: Node3D
var _aura_disc: Node3D
var _view_level := -1
var _turret_yaw := 0.0
var _has_target := false
var _view_tier := -1
var _view_vl := -1 # etapa visual del modelo (0..5): al cambiar se reconstruye


func _rebuild_view() -> void:
	if view != null:
		view.queue_free()
	if is_hero:
		view = V3.build_hero(id)
		_turret = view.get_node_or_null("Turret")
	else:
		view = TowerModels.build(id, view_level())
		_turret = TowerModels.pivot(view)
		if _turret != null:
			_turret.rotation.y = _turret_yaw
	_view_tier = TowerModels.tier(view_level())
	_view_vl = view_level()
	_demolish_mark = null
	view.position = V3.to3(position, game.cell_h(cell))
	_barrel = null
	_ready_mark = view.get_node_or_null("Ready")
	_range_disc = _make_disc(Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.6))
	if def.has("aura_range"):
		_aura_disc = _make_disc(Color(1, 0.9, 0.5, 0.0), Color(1, 0.85, 0.4, 0.8))
	game.world.add_child(view)
	_view_level = -1


## Gemas de nivel en la base de la torre (doradas; rosas en maestría).
func _rebuild_level_gems() -> void:
	var old := view.get_node_or_null("LevelGems")
	if old != null:
		old.free()
	var g := V3.node("LevelGems", Vector3.ZERO, view)
	var col := Color(1, 0.4, 0.9) if mastered() else Color(1, 0.82, 0.2)
	var n := level
	if is_card:
		# Torre de cartas: gemas del color de su rareza, una por nivel de carta
		col = GameData.RARITIES[def["rarity"]]["color"]
		n = Save.card_level(id)
	# Hasta 15 gemas pequeñas en dos filas (8 + 7)
	for i in n:
		V3.sphere(0.035, col, Vector3(-0.35 + (i % 8) * 0.1, 0.08, 0.47 - (i / 8) * 0.08), 1.5, g)
	_build_level_deco(g, level if not is_card else Save.card_level(id) * 3)
	TowerModels.ArcherModel.M.facet_tree(g)


## Mejora gráfica de CADA nivel (acumulativa): cada nivel añade algo visible alrededor de la
## torre, además de los cambios del propio modelo en los niveles 3, 6, 9, 12 y 15.
func _build_level_deco(g: Node3D, n: int) -> void:
	var accent: Color = def.get("color", Color(0.8, 0.7, 0.4))
	var stone := Color(0.62, 0.58, 0.52)
	var gold := Color(1.0, 0.8, 0.25)
	var wood := Color(0.45, 0.3, 0.18)
	var corners := [Vector3(0.4, 0, 0.4), Vector3(-0.4, 0, 0.4), Vector3(0.4, 0, -0.4), Vector3(-0.4, 0, -0.4)]
	if n >= 1: # base de piedra
		V3.cyl(0.47, 0.5, 0.06, stone, Vector3(0, 0.03, 0), 0.0, g, 8)
	if n >= 9: # segundo escalón, más ancho
		V3.cyl(0.52, 0.55, 0.04, stone.darkened(0.15), Vector3(0, 0.0, 0), 0.0, g, 8)
	for k in [0, 1]: # estandartes (1 en nivel 2, 2 en nivel 3; con remate dorado desde el 10)
		if n >= 2 + k:
			var p: Vector3 = corners[k]
			V3.cyl(0.015, 0.018, 0.7, wood, p + Vector3(0, 0.35, 0), 0.0, g, 5)
			var big := n >= 10
			V3.box(Vector3(0.2 if big else 0.16, 0.14 if big else 0.11, 0.012), accent, p + Vector3(0.1 * (1 if k == 0 else -1), 0.6, 0), 0.0, g)
			if big:
				V3.sphere(0.035, gold, p + Vector3(0, 0.72, 0), 0.6, g)
	if n >= 4: # moldura dorada alrededor de la base
		V3.torus(0.45, 0.49, gold, Vector3(0, 0.07, 0), 0.3, g)
	if n >= 5: # mojones de piedra en las esquinas
		for p in corners:
			V3.box(Vector3(0.08, 0.1, 0.08), stone.lightened(0.1), p * 1.12 + Vector3(0, 0.05, 0), 0.0, g)
	for k in 4: # antorchas (2 en nivel 6, 4 en nivel 7)
		if n >= (6 if k < 2 else 7):
			var tp: Vector3 = corners[3 - k] * 1.05
			V3.cyl(0.012, 0.016, 0.32, wood, tp + Vector3(0, 0.16, 0), 0.0, g, 5)
			V3.sphere(0.04, Color(1.0, 0.6, 0.15), tp + Vector3(0, 0.35, 0), 2.2, g)
	if n >= 8: # escudos con el color de la torre en los lados
		for d in [Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5)]:
			var sh := V3.cyl(0.07, 0.07, 0.02, accent, d + Vector3(0, 0.1, 0), 0.0, g, 6)
			sh.rotation = Vector3(PI * 0.5, atan2(d.x, d.z), 0)
			V3.sphere(0.02, gold, d * 1.04 + Vector3(0, 0.1, 0), 0.4, g)
	if n >= 11: # anillo de runas brillante
		V3.torus(0.56, 0.585, accent.lightened(0.3), Vector3(0, 0.16, 0), 1.6, g)
	if n >= 12: # cristales mágicos
		for p in corners:
			var cr := V3.cyl(0.0, 0.05, 0.2, accent.lightened(0.4), p * 1.2 + Vector3(0, 0.1, 0), 1.2, g, 5)
			cr.rotation = Vector3(0.2, 0, 0.15)
	if n >= 13: # corona de picos dorados
		for i in 8:
			var a := TAU * i / 8.0
			V3.cyl(0.0, 0.03, 0.1, gold, Vector3(cos(a) * 0.5, 0.12, sin(a) * 0.5), 0.5, g, 4)
	if n >= 14: # halo de luz en el suelo
		V3.cyl(0.66, 0.66, 0.005, Color(accent.r, accent.g, accent.b, 0.22), Vector3(0, 0.012, 0), 0.8, g, 24)
	if n >= GameData.MAX_TOWER_LEVEL: # Maestría: gran anillo rosa y cristales
		V3.torus(0.62, 0.66, Color(1, 0.45, 0.95), Vector3(0, 0.25, 0), 2.5, g)
		for i in 3:
			var a := TAU * i / 3.0 + 0.5
			V3.sphere(0.05, Color(1, 0.55, 1.0), Vector3(cos(a) * 0.62, 0.42, sin(a) * 0.62), 2.0, g)
	_view_level = level


func _make_disc(fill: Color, edge: Color) -> Node3D:
	var d := V3.node("Range", Vector3(0, 0.04, 0), view)
	if fill.a > 0.0:
		V3.cyl(1.0, 1.0, 0.01, fill, Vector3.ZERO, 0.0, d, 48)
	V3.torus(0.97, 1.0, edge, Vector3(0, 0.01, 0), 1.0, d)
	d.visible = false
	return d


func _update_view(delta: float) -> void:
	if game == null or game.world == null:
		return
	if view == null or (not is_hero and view_level() != _view_vl):
		_rebuild_view() # cada etapa de nivel tiene su propio aspecto
	if _view_level != level and not is_hero:
		_rebuild_level_gems()
	var dir := Vector2.from_angle(_aim)
	if _turret != null:
		if is_hero:
			_turret_yaw = lerp_angle(_turret_yaw, V3.yaw(_aim), minf(delta * 12.0, 1.0))
		else:
			# Los modelos miran a -Z (como en Cat Tower Defence)
			_turret_yaw = lerp_angle(_turret_yaw, atan2(-dir.x, -dir.y), minf(delta * 10.0, 1.0))
		_turret.rotation.y = _turret_yaw
	if not is_hero:
		for k in _tubes.size():
			_tubes[k] = maxf(float(_tubes[k]) - delta * 1.2, 0.0)
		var period := 1.0 / maxf(rate(), 0.01)
		TowerModels.animate(view, {
			"t": TowerModels.ArcherModel.M.stop_time(),
			"charge": clampf(1.0 - cooldown / period, 0.0, 1.0) if can_attack() else 0.0,
			"fire": clampf(_recoil, 0.0, 1.0),
			"has_target": _has_target,
			"tubes": _tubes,
		})
	if _ready_mark != null:
		_ready_mark.visible = ability_cd <= 0.0
		_ready_mark.position.y = 1.15 + sin(_anim * 4.0) * 0.06
	var show_range: bool = selected or game.show_all_ranges
	if _range_disc != null:
		var rr := range_px() / GameData.TILE
		_range_disc.visible = show_range and rr > 0.0
		_range_disc.scale = Vector3(rr, 1, rr)
	if _aura_disc != null:
		var ar := float(stat("aura_range", 0.0))
		_aura_disc.visible = show_range
		_aura_disc.scale = Vector3(ar, 1, ar)


var _demolish_mark: Node3D


## Anillo rojo bajo la torre mientras está activo el modo Demoler.
func set_demolish_mark(on: bool) -> void:
	if view == null:
		return
	if on and _demolish_mark == null:
		_demolish_mark = V3.node("Demoler", Vector3(0, 0.05, 0), view)
		V3.cyl(0.5, 0.5, 0.02, Color(1, 0.2, 0.15, 0.35), Vector3.ZERO, 0.0, _demolish_mark, 24)
		V3.torus(0.46, 0.52, Color(1, 0.25, 0.15), Vector3(0, 0.02, 0), 1.5, _demolish_mark)
	if _demolish_mark != null:
		_demolish_mark.visible = on


func _exit_tree() -> void:
	if view != null:
		view.queue_free()
		view = null
