class_name Enemy
extends Node2D

const BASE_SPEED := 1.15 # casillas por segundo

var game: Node
var id := ""
var def: Dictionary = {}
var max_hp := 1.0
var hp := 1.0
var speed := 60.0
var armor := 0.0
var resist := 0.0
var flying := false
var is_boss := false
var elite := false
var immune: Array = []
var traits: Array = []
var gold_value := 1
var radius := 16.0
var path: Array = []
var path_idx := 1
var progress := 0.0 # distancia recorrida (para "apuntar al primero")
var dead := false
var invisible := false # solo lo atacan torres detectoras (o si está revelado)
var reveal_time := 0.0
var _geoms: Array = []
var _shown := -1
var puppet := false # cooperativo (cliente): lo mueve el anfitrión
var net_pos := Vector2.ZERO
var uid := 0

var slow_factor := 1.0
var slow_time := 0.0
var stun_time := 0.0
var armor_break := 0.0
var dots: Array = [] # [{dps, time, type}]
var flash := 0.0
var anim := 0.0
var _trait_timer := 0.0


func setup(g: Node, enemy_id: String, hp_value: float, gold: int, p: Array, start_idx := 1, start_pos := Vector2.INF) -> void:
	game = g
	id = enemy_id
	def = GameData.ENEMIES[enemy_id]
	max_hp = hp_value * float(def.get("hp", 1.0))
	hp = max_hp
	speed = BASE_SPEED * float(def.get("speed", 1.0)) * GameData.TILE
	armor = float(def.get("armor", 0.0))
	resist = float(def.get("resist", 0.0))
	flying = bool(def.get("flying", false))
	height = V3.FLY_HEIGHT if flying else 0.0
	is_boss = bool(def.get("boss", false))
	immune = def.get("immune", [])
	traits = def.get("traits", [])
	invisible = "invisible" in traits
	gold_value = gold
	radius = float(def.get("size", 0.25)) * GameData.TILE
	path = p
	path_idx = start_idx
	position = path[0] if start_pos == Vector2.INF else start_pos
	anim = randf() * 10.0
	z_index = 3 if flying else 1


func _process(delta: float) -> void:
	if dead:
		return
	anim += delta
	if puppet:
		position = position.lerp(net_pos, minf(1.0, delta * 12.0))
		flash = maxf(flash - delta * 4.0, 0.0)
		if view == null and game != null:
			_make_view()
		_update_view()
		return
	flash = maxf(flash - delta * 4.0, 0.0)
	_process_effects(delta)
	if dead:
		return
	_process_traits(delta)
	if stun_time <= 0.0:
		_move(delta)
	if view == null and game != null and not dead:
		_make_view()
	_update_view()


func _move(delta: float) -> void:
	var step := speed * slow_factor * delta
	while step > 0.0 and path_idx < path.size():
		var target: Vector2 = path[path_idx]
		var d := position.distance_to(target)
		if d <= step:
			position = target
			step -= d
			progress += d
			path_idx += 1
		else:
			position += (target - position).normalized() * step
			progress += step
			step = 0.0
	if path_idx >= path.size():
		dead = true
		game.on_enemy_leaked(self)
		queue_free()


func _process_effects(delta: float) -> void:
	if stun_time > 0.0:
		stun_time -= delta
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_factor = 1.0
	var i := dots.size() - 1
	while i >= 0:
		var d: Dictionary = dots[i]
		d["time"] = float(d["time"]) - delta
		take_damage(float(d["dps"]) * delta, d["type"], true)
		if dead:
			return
		if float(d["time"]) <= 0.0:
			dots.remove_at(i)
		i -= 1


func _process_traits(delta: float) -> void:
	if traits.is_empty():
		return
	_trait_timer += delta
	if "regen" in traits:
		hp = minf(max_hp, hp + max_hp * 0.015 * delta)
	if _trait_timer >= 3.0:
		_trait_timer = 0.0
		if "healer" in traits:
			game.heal_area(position, GameData.TILE * 1.6, 0.12)
			game.spawn_fx("heal", position, GameData.TILE * 1.6, Color(0.4, 1.0, 0.4, 0.5))
		if "summoner" in traits:
			var count := 3 if is_boss else 1
			for k in count:
				game.spawn_enemy_at(def.get("summon", "skeleton"), max_hp / float(def.get("hp", 1.0)) * 0.6, self)


## Aplica daño teniendo en cuenta tipo, armaduras e inmunidades. Devuelve el daño real.
func take_damage(amount: float, dmg_type: String, is_dot := false) -> float:
	if dead or amount <= 0.0:
		return 0.0
	if puppet:
		flash = 1.0 # en el cliente solo se ve el golpe; el daño lo calcula el anfitrión
		return 0.0
	if dmg_type in immune:
		if not is_dot and randf() < 0.15:
			game.float_text(position + Vector2(0, -radius - 8), "INMUNE", Color(0.8, 0.8, 0.8))
		return 0.0
	var eff_armor := maxf(armor - armor_break, 0.0)
	match dmg_type:
		"physical":
			amount *= 1.0 - eff_armor
			if "ethereal" in traits:
				amount *= 0.25
		"magic", "lightning":
			amount *= 1.0 - resist
		"fire", "ice":
			amount *= 1.0 - resist * 0.5
		"holy":
			amount *= 1.0 - resist * 0.5
			if "undead" in traits:
				amount *= 2.0
		"poison":
			pass # El veneno ignora armadura y resistencia.
	hp -= amount
	if not is_dot:
		flash = 1.0
	if hp <= 0.0:
		die()
	return amount


func apply_slow(factor: float, duration: float) -> void:
	if "slow_immune" in traits:
		return
	if is_boss:
		factor = lerpf(factor, 1.0, 0.5)
	slow_factor = minf(slow_factor, factor)
	slow_time = maxf(slow_time, duration)


func apply_stun(duration: float) -> void:
	if "slow_immune" in traits:
		return
	stun_time = maxf(stun_time, duration * (0.35 if is_boss else 1.0))


func apply_dot(dps: float, duration: float, dmg_type: String) -> void:
	if dmg_type in immune:
		return
	# Un DoT del mismo tipo se refresca en lugar de acumularse indefinidamente.
	for d in dots:
		if d["type"] == dmg_type:
			d["dps"] = maxf(float(d["dps"]), dps)
			d["time"] = maxf(float(d["time"]), duration)
			return
	dots.append({"dps": dps, "time": duration, "type": dmg_type})


func die() -> void:
	if dead:
		return
	dead = true
	if "split" in traits:
		for k in 2:
			game.spawn_enemy_at(def.get("spawn", "slimelet"), max_hp / float(def.get("hp", 1.0)), self, Vector2(randf_range(-10, 10), randf_range(-10, 10)))
	game.on_enemy_killed(self)
	Audio.sfx("death", -12.0, 0.2, 0.06)
	queue_free()


# ---------------------------------------------------------------- Vista 3D
var view: Node3D
var height := 0.0
var _wing_l: Node3D
var _wing_r: Node3D
var _body: Node3D
var _face := 0.0
var _prev := Vector2.INF


const ENEMY_MODELS := "res://scripts/game/enemy_models.gd"


func _make_view() -> void:
	var r := radius / float(GameData.TILE)
	if ResourceLoader.exists(ENEMY_MODELS):
		view = load(ENEMY_MODELS).build(id, def, r, elite)
	else:
		view = V3.build_enemy(def, r, elite)
	height = V3.FLY_HEIGHT if flying else 0.0
	_body = view.get_node("Body")
	_wing_l = _body.get_node_or_null("WingL")
	_wing_r = _body.get_node_or_null("WingR")
	game.world.add_child(view)
	_update_view()


func is_revealed() -> bool:
	return not invisible or reveal_time > 0.0


## Invisible: casi transparente; revelado: se ve con un brillo tenue.
func _update_visibility() -> void:
	if not invisible or view == null:
		return
	var state := 1 if reveal_time > 0.0 else 0
	if state == _shown:
		return
	_shown = state
	if _geoms.is_empty():
		var stack: Array = [view]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is GeometryInstance3D:
				_geoms.append(n)
			stack.append_array(n.get_children())
	for g in _geoms:
		(g as GeometryInstance3D).transparency = 0.2 if state == 1 else 0.82
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if state == 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _update_view() -> void:
	if view == null:
		return
	if invisible:
		reveal_time = maxf(reveal_time - get_process_delta_time(), 0.0)
		_update_visibility()
	if _prev != Vector2.INF and position.distance_squared_to(_prev) > 0.01:
		_face = lerp_angle(_face, (position - _prev).angle(), 0.3)
	_prev = position
	var bob := absf(sin(anim * 9.0)) * 0.05 if not flying else sin(anim * 3.0) * 0.08
	if stun_time > 0.0:
		bob = 0.0
	view.position = V3.to3(position, height + bob)
	view.rotation.y = V3.yaw(_face)
	var pulse := 1.0 + flash * 0.25
	_body.scale = Vector3(pulse, pulse, pulse)
	if _wing_l != null:
		var flap := sin(anim * (14.0 if def.get("shape") == "wings" else 6.0)) * 0.7
		_wing_l.rotation.x = flap
		_wing_r.rotation.x = -flap
	if stun_time > 0.0:
		_body.rotation.y += 0.3
	else:
		_body.rotation.y = 0.0
	if view.has_method("animate"):
		view.animate(anim, stun_time <= 0.0, slow_time > 0.0)


func _exit_tree() -> void:
	if view != null:
		view.queue_free()
		view = null
