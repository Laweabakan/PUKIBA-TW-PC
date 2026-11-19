extends Node3D
## Raíz animada de un enemigo (ver EnemyModels). El juego llama a animate() en cada fotograma.
## Cada pista mueve una pieza articulada (pierna, brazo, cola, llama...) con una onda sencilla.
## Las poses se calculan a 12 fps ("stop motion" de plastilina): entre medias no se hace nada,
## así cien enemigos en pantalla apenas cuestan.

enum { ROT, POS, SCALE }
enum { SINE, BOUNCE, FLICKER, SPIN }

const FPS := 12.0

# Cada pista: [nodo, propiedad, eje, amplitud, frecuencia, fase, al_andar, modo, valor_base]
var tracks: Array = []
var _last := -1.0
var _moving := true


## Añade una pista. `walk` = solo se mueve mientras camina (piernas, brazos);
## si es false, se anima siempre (llamas, flotar, respirar).
func add_track(n: Node3D, prop: int, axis: int, amp: float, freq: float, off: float, walk: bool, mode: int) -> void:
	var base: Vector3 = n.rotation
	if prop == POS:
		base = n.position
	elif prop == SCALE:
		base = n.scale
	tracks.append([n, prop, axis, amp, freq, off, walk, mode, base])


func animate(t: float, moving: bool, slowed: bool) -> void:
	var tq := floorf(t * FPS) / FPS
	if tq == _last and moving == _moving:
		return
	_last = tq
	_moving = moving
	var pace := 0.55 if slowed else 1.0
	for tr in tracks:
		var n: Node3D = tr[0]
		var walk: bool = tr[6]
		var amp: float = tr[3]
		var base: Vector3 = tr[8]
		if walk and not moving:
			amp = 0.0
		var x: float = tq * float(tr[4]) * (pace if walk else 1.0) + float(tr[5])
		var v := 0.0
		match int(tr[7]):
			SINE:
				v = sin(x) * amp
			BOUNCE:
				v = absf(sin(x)) * amp
			FLICKER:
				v = (sin(x) * 0.6 + sin(x * 2.37 + 1.3) * 0.4) * amp
			SPIN:
				v = fmod(x, TAU) * amp
		var axis: int = tr[2]
		match int(tr[1]):
			ROT:
				var r := base
				r[axis] += v
				n.rotation = r
			POS:
				var p := base
				p[axis] += v
				n.position = p
			SCALE:
				n.scale = Vector3(base.x * (1.0 - v * 0.5), base.y * (1.0 + v), base.z * (1.0 - v * 0.5))
