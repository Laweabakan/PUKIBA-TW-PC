class_name Projectile
extends Node2D
## Proyectil: la lógica avanza en el plano 2D y la vista 3D añade altura
## (los morteros y frascos vuelan en parábola, como en el tutorial de Catlike).

const SPEEDS := {"arrow": 620.0, "arrow_poison": 600.0, "fireball": 420.0, "rocket": 300.0, "bolt": 760.0, "rock": 330.0, "orb": 460.0, "ice": 440.0,
	"flask": 320.0, "fire": 520.0, "void": 700.0, "holy": 520.0, "slash": 900.0}

var game: Node
var target: Enemy
var target_pos := Vector2.ZERO
var payload: Dictionary = {}
var style := "arrow"
var speed := 500.0
var origin := Vector2.ZERO
var from_h := 1.0
var to_h := 0.3
var arc := 0.0
var total := 1.0
var view: Node3D
var _prev3 := Vector3.INF
# Animación de la vista (datos que deja VFX en los metadatos del modelo)
var _spin: Node3D
var _spin_rate := Vector3.ZERO
var _pulse: Node3D
var _t := 0.0


func setup(g: Node, from: Vector2, from_height: float, t: Enemy, p: Dictionary, s: String, fixed_pos := Vector2.INF) -> void:
	game = g
	position = from
	origin = from
	from_h = from_height
	target = t
	target_pos = t.position if t != null else fixed_pos
	payload = p
	style = s
	speed = SPEEDS.get(s, 500.0)
	arc = V3.arc_height(s)
	total = maxf(from.distance_to(target_pos), 1.0)
	to_h = t.height + 0.3 if t != null else 0.05


func _ready() -> void:
	var col: Color = GameData.DAMAGE_TYPES[payload["type"]]["color"]
	view = VFX.build_projectile(style, col)
	if view.has_meta("spin"):
		_spin = view.get_meta("spin")
		_spin_rate = view.get_meta("spin_rate")
	if view.has_meta("pulse"):
		_pulse = view.get_meta("pulse")
	_t = randf() * 10.0
	game.world.add_child(view)
	_update_view()


func _process(delta: float) -> void:
	if is_instance_valid(target) and not target.dead:
		target_pos = target.position
		to_h = target.height + 0.3
	var to := target_pos - position
	var step := speed * delta
	if to.length() <= step:
		position = target_pos
		var hit_target: Enemy = target if is_instance_valid(target) and not target.dead else null
		game.resolve_hit(payload, hit_target, position, origin, from_h)
		_release_view()
		queue_free()
		return
	position += to.normalized() * step
	_update_view()
	_animate(delta)


## Giro y parpadeo del modelo (sin asignaciones por fotograma).
func _animate(delta: float) -> void:
	_t += delta
	if _spin != null:
		_spin.rotation += _spin_rate * delta
	if _pulse != null:
		_pulse.scale = Vector3.ONE * (1.0 + 0.13 * sin(_t * 31.0) + 0.07 * sin(_t * 57.0))


## Al impactar, las estelas se sueltan en el mundo y se apagan poco a poco.
func _release_view() -> void:
	if view == null:
		return
	VFX.release_trails(view, game.world)
	view.queue_free()
	view = null


func _update_view() -> void:
	if view == null:
		return
	var remaining := position.distance_to(target_pos)
	var frac := clampf(1.0 - remaining / maxf(total, remaining), 0.0, 1.0)
	var h := lerpf(from_h, to_h, frac) + arc * 4.0 * frac * (1.0 - frac)
	var p3 := V3.to3(position, h)
	if _prev3 != Vector3.INF:
		var d := p3 - _prev3
		if d.length_squared() > 0.000001:
			view.rotation = Vector3(0, V3.yaw(atan2(d.z, d.x)), atan2(d.y, Vector2(d.x, d.z).length()))
	_prev3 = p3
	view.position = p3


func _exit_tree() -> void:
	if view != null:
		view.queue_free()
		view = null
