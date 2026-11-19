extends RefCounted
## Pequeños nodos animados del paisaje (muy baratos: unas pocas operaciones por fotograma).
## Se usan desde Scenery: aspas del molino, bandadas, nubes que derivan y rocas que flotan.


## Gira sobre un eje local a velocidad constante (aspas del molino, anillos mágicos...).
class Spinner extends Node3D:
	var axis := Vector3.FORWARD
	var speed := 1.0

	func _process(delta: float) -> void:
		rotate_object_local(axis, speed * delta)


## Bandada de pájaros / murciélagos: cada uno da vueltas a un centro con un leve sube y baja.
## Un único MultiMesh: una sola llamada de dibujo para toda la bandada.
class Flock extends MultiMeshInstance3D:
	# Cada pájaro: [centro: Vector3, radio: float, vel. angular: float, fase: float, achatado: float, tamaño: float, temblor: float]
	var birds: Array = []
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		var mm := multimesh
		for i in birds.size():
			var b: Array = birds[i]
			var c: Vector3 = b[0]
			var r: float = b[1]
			var w: float = b[2]
			var ph: float = b[3]
			var sq: float = b[4]
			var sz: float = b[5]
			var jit: float = b[6]
			var a := ph + _t * w
			var wob := sin(_t * 3.7 + ph * 5.0) * jit
			var pos := c + Vector3(cos(a) * (r + wob), sin(a * 1.3 + ph) * 0.35, sin(a) * (r + wob) * sq)
			var vel := Vector3(-sin(a), 0.0, cos(a) * sq) * signf(w)
			var bas := Basis.looking_at(vel.normalized(), Vector3.UP).scaled(Vector3.ONE * sz)
			bas = bas * Basis(Vector3.FORWARD, -signf(w) * 0.35) # se inclina en la curva
			mm.set_instance_transform(i, Transform3D(bas, pos))


## Objetos que derivan en X y reaparecen por el otro lado (nubes, niebla densa).
class Drifter extends MultiMeshInstance3D:
	# Cada uno: [posición: Vector3, velocidad: float, escala: Vector3]
	var items: Array = []
	var x_min := -30.0
	var x_max := 30.0

	func _process(delta: float) -> void:
		var mm := multimesh
		for i in items.size():
			var it: Array = items[i]
			var p: Vector3 = it[0]
			var v: float = it[1]
			var s: Vector3 = it[2]
			p.x += v * delta
			if p.x > x_max:
				p.x = x_min
			elif p.x < x_min:
				p.x = x_max
			it[0] = p
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(s), p))


## Rocas que flotan: suben, bajan y giran despacio alrededor de su posición base.
class Bobber extends MultiMeshInstance3D:
	var bases: Array = []   # Transform3D
	var phases: Array = []  # float
	var amp := 0.15
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		var mm := multimesh
		for i in bases.size():
			var xf: Transform3D = bases[i]
			var ph: float = phases[i]
			var off := Vector3(0.0, sin(_t * 0.8 + ph) * amp, 0.0)
			var rot := Basis(Vector3.UP, sin(_t * 0.3 + ph) * 0.25)
			mm.set_instance_transform(i, Transform3D(rot * xf.basis, xf.origin + off))
