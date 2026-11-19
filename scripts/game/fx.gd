class_name Fx
extends Node2D
## Efectos efímeros. Explosiones, muertes, construcciones y rayos son 3D (en game.world);
## los textos flotantes y el destello de pantalla se dibujan en 2D encima.
## Tipos: burst, heal, bolt, text, screen, build, levelup, death, boss_death, impact, hit.
## Cada efecto se libera solo; su vista 3D se borra en _exit_tree.

## Duración mínima real de cada tipo (las partículas necesitan terminar su vida).
const MIN_LIFE := {"build": 1.0, "levelup": 1.4, "death": 0.85, "boss_death": 2.2, "impact": 0.9,
	"burst": 0.9, "heal": 0.9, "bolt": 0.3}
const TEXT_SIZE := 26

var game: Node
var kind := "burst"
var color := Color.WHITE
var radius := 30.0 # en píxeles de plano
var life := 0.4
var max_life := 0.4
var text := ""
var points: PackedVector2Array = PackedVector2Array()
var heights: Array = []
var plane_pos := Vector2.ZERO
var height := 0.4
var view: Node3D
var _age := 0.0
var _anims: Array = []
var _hit: MeshInstance3D
var _spiral: Array = []
var _light: OmniLight3D
var _light_energy := 0.0
var _text_start := Vector2.ZERO
# Rayo encadenado
var _bolt_mesh: ImmediateMesh
var _bolt_mat: StandardMaterial3D
var _bolt_nodes := PackedVector3Array()
var _bolt_timer := 0.0
var _cam_pos := Vector3(0, 10, 10)


## Pieza animada: escala de s0 a s1 (salida suave) y alfa que se apaga.
class Anim:
	var node: Node3D
	var mat: StandardMaterial3D
	var t0 := 0.0
	var t1 := 1.0
	var s0 := Vector3.ONE
	var s1 := Vector3.ONE
	var a0 := 1.0
	var fade_pow := 1.0

	func update(age: float) -> void:
		if age < t0:
			node.visible = false
			return
		var u := clampf((age - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
		node.visible = u < 1.0
		var e := 1.0 - pow(1.0 - u, 3.0)
		node.scale = s0.lerp(s1, e)
		if mat != null:
			mat.albedo_color.a = a0 * pow(1.0 - u, fade_pow)


func setup(g: Node, k: String, pos: Vector2, r: float, c: Color, duration := 0.4) -> void:
	game = g
	kind = k
	plane_pos = pos
	radius = r
	color = c
	life = duration
	z_index = 10
	match k:
		"text":
			position = g.screen_pos(pos, 1.2)
		"screen":
			position = Vector2.ZERO
		"hit":
			life = minf(duration, 0.22)
	life = maxf(life, float(MIN_LIFE.get(k, 0.0)))
	max_life = life


func _ready() -> void:
	_text_start = position
	if kind == "text" or kind == "screen":
		if kind == "text":
			scale = Vector2.ONE * 0.3
		return
	view = Node3D.new()
	game.world.add_child(view)
	var r := maxf(radius / float(GameData.TILE), 0.2)
	match kind:
		"hit": _build_hit(r)
		"bolt": _build_bolt()
		"burst": _build_impact("fire", maxf(r, 0.5))
		"impact": _build_impact(VFX.element_of(color), r)
		"heal": _build_heal(r)
		"build": _build_build(r)
		"levelup": _build_levelup(r)
		"death": _build_death(r)
		"boss_death": _build_boss(r)
		_: _build_impact("physical", r)


# ================================================================ Piezas comunes
## Destello breve (siempre visible por encima: no se corta con el suelo).
func _flash(pos: Vector3, size: float, col: Color, t1: float, t0 := 0.0, tex := "glow", add := true) -> Anim:
	var m := VFX.new_bill_mat(tex, col, add, true)
	var mi := VFX.bill(view, tex, col, size, pos, add, m)
	return _anim(mi, m, t0, t1, Vector3.ONE * size * 0.5, Vector3.ONE * size, col.a, 1.6)


func _ring(r: float, col: Color, t0: float, t1: float, h := 0.06, tex := "ring") -> Anim:
	var m := VFX.new_flat_mat(tex, col, false)
	var mi := MeshInstance3D.new()
	mi.mesh = VFX.mesh("quad")
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.x = -PI * 0.5
	mi.position = Vector3(0, h, 0)
	view.add_child(mi)
	return _anim(mi, m, t0, t1, Vector3.ONE * r * 0.3, Vector3.ONE * r * 2.0, col.a, 1.3)


func _anim(n: Node3D, m: StandardMaterial3D, t0: float, t1: float, s0: Vector3, s1: Vector3, a0: float, fp: float) -> Anim:
	var a := Anim.new()
	a.node = n
	a.mat = m
	a.t0 = t0
	a.t1 = t1
	a.s0 = s0
	a.s1 = s1
	a.a0 = a0
	a.fade_pow = fp
	n.scale = s0
	n.visible = t0 <= 0.0
	_anims.append(a)
	return a


## Ráfaga radial de partículas billboard (one-shot).
func _burst(tex: String, add: bool, amount: int, lifetime: float, col: Color, ramp: String, smin: float, smax: float,
		vmin: float, vmax: float, pos := Vector3.ZERO) -> CPUParticles3D:
	var p := VFX.particles(view, "quad", VFX.pmat(tex, add), amount, lifetime, true)
	p.position = pos
	p.color = col
	p.color_ramp = VFX.grad(ramp)
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.scale_amount_curve = VFX.curve("shrink")
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.lifetime_randomness = 0.35
	return p


## Ráfaga de piezas de malla con luz (arcilla): humo, polvo, astillas, monedas.
func _chunks(mesh_kind: String, amount: int, lifetime: float, col: Color, smin: float, smax: float,
		vmin: float, vmax: float, grav: float, pos := Vector3.ZERO, gloss := false) -> CPUParticles3D:
	var p := VFX.particles(view, mesh_kind, VFX.clay(gloss), amount, lifetime, true)
	p.position = pos
	p.color = col
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.scale_amount_curve = VFX.curve("hold")
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0, grav, 0)
	p.lifetime_randomness = 0.3
	if grav < -1.0:
		p.direction = Vector3(0, 1, 0)
		p.spread = 60.0
		p.particle_flag_rotate_y = true
		p.angular_velocity_min = -400.0
		p.angular_velocity_max = 400.0
		p.angle_max = 360.0
	return p


## Bolitas de humo/polvo de arcilla que se hinchan y desaparecen.
func _puffs(amount: int, lifetime: float, col: Color, smin: float, smax: float, vmin: float, vmax: float,
		rise: float, pos := Vector3.ZERO, ramp := "") -> CPUParticles3D:
	var p := VFX.particles(view, "ball", VFX.clay(), amount, lifetime, true)
	p.position = pos
	p.color = col
	if ramp != "":
		p.color_ramp = VFX.grad(ramp)
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.scale_amount_curve = VFX.curve("puff")
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.damping_min = vmax * 1.2
	p.damping_max = vmax * 1.8
	p.gravity = Vector3(0, rise, 0)
	p.lifetime_randomness = 0.3
	return p


# ================================================================ Golpe simple (muy barato)
## Un único destello en estrella con material compartido por color: sólo se anima la escala.
func _build_hit(r: float) -> void:
	view.position = V3.to3(plane_pos, 0.4)
	_hit = VFX.bill(view, "star", Color(color.lerp(Color.WHITE, 0.3), 0.9), 0.01, Vector3.ZERO, true)
	radius = r


func _update_hit() -> void:
	var u := _age / max_life
	var s := radius * 1.5 * (u / 0.25 if u < 0.25 else 1.0 - (u - 0.25) / 0.75)
	_hit.scale = Vector3.ONE * maxf(s, 0.001)


# ================================================================ Impactos de área por elemento
func _build_impact(el: String, r: float) -> void:
	var h := 0.22
	view.position = V3.to3(plane_pos, 0.0)
	var c := color
	match el:
		"fire":
			_flash(Vector3(0, h + 0.1, 0), r * 1.3, Color(1.0, 0.7, 0.3, 0.7), 0.25)
			_ring(r, Color(1.0, 0.42, 0.08, 0.85), 0.0, 0.35)
			var fl := _burst("glow", false, 16, 0.6, Color(1, 1, 1, 1), "fire", r * 0.6, r * 1.0, 0.6, 1.6 * r + 0.4, Vector3(0, h, 0))
			fl.direction = Vector3(0, 1, 0)
			fl.spread = 75.0
			fl.gravity = Vector3(0, 1.5, 0)
			fl.damping_min = 2.0
			fl.damping_max = 3.0
			fl.scale_amount_curve = VFX.curve("puff")
			var core := _burst("glow", true, 4, 0.25, Color(1, 0.85, 0.5, 0.9), "fade", r * 0.5, r * 0.7, 0.2, 0.6, Vector3(0, h, 0))
			core.scale_amount_curve = VFX.curve("pop")
			var em := _burst("star", true, 8, 0.7, Color(1, 0.6, 0.2), "fire", 0.1, 0.16, 2.0, 3.5, Vector3(0, h, 0))
			em.direction = Vector3(0, 1, 0)
			em.spread = 70.0
			em.gravity = Vector3(0, -3.0, 0)
			_puffs(4, 0.9, Color(0.45, 0.4, 0.38), r * 0.14, r * 0.24, 0.5, 1.0, 1.0, Vector3(0, h + 0.2, 0))
		"ice":
			_flash(Vector3(0, h + 0.05, 0), r * 1.2, Color(0.6, 0.85, 1.0, 0.6), 0.25)
			_ring(r, Color(0.35, 0.72, 1.0, 0.85), 0.0, 0.45)
			var sh := VFX.particles(view, "shard", VFX.clay(true), 10, 0.6, true)
			sh.position = Vector3(0, h, 0)
			sh.color = Color(0.6, 0.86, 1.0)
			sh.direction = Vector3(0, 1, 0)
			sh.spread = 80.0
			sh.initial_velocity_min = 1.8
			sh.initial_velocity_max = 3.2 * maxf(r, 0.6)
			sh.gravity = Vector3(0, -7.0, 0)
			sh.particle_flag_align_y = true
			sh.scale_amount_min = 0.16
			sh.scale_amount_max = 0.28
			sh.scale_amount_curve = VFX.curve("hold")
			_burst("star", true, 8, 0.6, Color(0.7, 0.9, 1.0), "frost", 0.1, 0.18, 0.3, 1.2 * r + 0.3, Vector3(0, h, 0))
			var mist := _burst("glow", false, 5, 0.7, Color(0.55, 0.8, 1.0, 0.6), "fadein", r * 0.6, r * 0.9, 0.2, 0.5, Vector3(0, 0.12, 0))
			mist.scale_amount_curve = VFX.curve("grow")
		"poison":
			_ring(r, Color(0.3, 0.8, 0.12, 0.85), 0.0, 0.45)
			_flash(Vector3(0, h, 0), r * 1.1, Color(0.5, 1.0, 0.3, 0.5), 0.25)
			var cl := _burst("smoke", false, 7, 0.85, Color(0.3, 0.7, 0.15, 0.85), "fadein", r * 0.55, r * 0.9, 0.3, 0.8, Vector3(0, 0.15, 0))
			cl.scale_amount_curve = VFX.curve("grow")
			cl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			cl.emission_sphere_radius = r * 0.4
			var bub := _burst("bubble", false, 10, 0.75, Color(0.45, 0.95, 0.25, 1.0), "fade", 0.1, 0.2, 0.4, 1.1, Vector3(0, 0.1, 0))
			bub.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			bub.emission_sphere_radius = r * 0.5
			bub.gravity = Vector3(0, 1.4, 0)
			bub.scale_amount_curve = VFX.curve("pop")
			_chunks("ball", 5, 0.5, Color(0.35, 0.8, 0.15), 0.05, 0.09, 1.5, 2.6, -8.0, Vector3(0, h, 0))
		"lightning":
			_flash(Vector3(0, h + 0.05, 0), r * 1.3, Color(1.0, 0.95, 0.6, 0.8), 0.18)
			_ring(r, Color(1.0, 0.85, 0.2, 0.85), 0.0, 0.25)
			var sp := VFX.particles(view, "spark", VFX.pmat_mesh_add(), 14, 0.3, true)
			sp.position = Vector3(0, h, 0)
			sp.color = Color(1.0, 0.95, 0.6)
			sp.color_ramp = VFX.grad("fade")
			sp.particle_flag_align_y = true
			sp.initial_velocity_min = 3.0
			sp.initial_velocity_max = 5.5
			sp.damping_min = 6.0
			sp.damping_max = 10.0
			sp.scale_amount_min = 0.12
			sp.scale_amount_max = 0.25
			_burst("star", true, 5, 0.25, Color(1, 1, 0.8), "fade", 0.15, 0.3, 0.5, 1.5, Vector3(0, h, 0))
		"holy":
			_flash(Vector3(0, h + 0.1, 0), r * 1.3, Color(1.0, 0.9, 0.6, 0.7), 0.3)
			_ring(r * 1.1, Color(1.0, 0.78, 0.2, 0.9), 0.0, 0.5)
			_ring(r * 0.7, Color(1.0, 0.92, 0.6, 0.8), 0.12, 0.55)
			var hs := _burst("star", false, 12, 0.8, Color(1, 0.85, 0.4), "gold", 0.12, 0.2, 0.6, 1.4, Vector3(0, 0.1, 0))
			hs.direction = Vector3(0, 1, 0)
			hs.spread = 50.0
			hs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			hs.emission_sphere_radius = r * 0.5
			hs.scale_amount_curve = VFX.curve("pop")
		"magic":
			_flash(Vector3(0, h + 0.05, 0), r * 1.3, Color(c, 0.75), 0.25)
			_ring(r, Color(c.darkened(0.1), 0.9), 0.0, 0.4)
			_burst("star", false, 12, 0.55, c.lerp(Color.WHITE, 0.2), "fade", 0.12, 0.2, 1.0, 2.4, Vector3(0, h, 0))
			var mg := _burst("glow", false, 6, 0.45, Color(c, 0.8), "fade", r * 0.4, r * 0.7, 0.3, 1.0, Vector3(0, h, 0))
			mg.scale_amount_curve = VFX.curve("puff")
		_:
			# Físico: polvo + piedras
			_flash(Vector3(0, h, 0), r * 1.0, Color(1.0, 0.92, 0.75, 0.45), 0.15)
			_ring(r, Color(0.5, 0.42, 0.3, 0.6), 0.0, 0.4)
			var d := _puffs(10, 0.8, Color(0.62, 0.54, 0.43), r * 0.22, r * 0.38, 1.2, 2.2, 0.4, Vector3(0, 0.1, 0))
			d.direction = Vector3(0, 1, 0)
			d.spread = 85.0
			d.flatness = 0.6
			_chunks("rock", 7, 0.75, Color(0.48, 0.44, 0.4), 0.08, 0.14, 2.2, 3.6, -10.0, Vector3(0, h, 0))


# ================================================================ Curación (grito de guerra)
func _build_heal(r: float) -> void:
	view.position = V3.to3(plane_pos, 0.0)
	_ring(r * 0.5, Color(color, 0.85), 0.0, 0.6, 0.08)
	_ring(r * 0.35, Color(color.lerp(Color.WHITE, 0.4), 0.7), 0.12, 0.7, 0.09)
	var s := _burst("star", true, 16, 0.8, color.lerp(Color.WHITE, 0.3), "fade", 0.1, 0.2, 0.5, 1.2, Vector3(0, 0.15, 0))
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	s.emission_ring_axis = Vector3.UP
	s.emission_ring_radius = r * 0.45
	s.emission_ring_inner_radius = r * 0.2
	s.emission_ring_height = 0.0
	s.direction = Vector3(0, 1, 0)
	s.spread = 20.0
	s.scale_amount_curve = VFX.curve("pop")


# ================================================================ Torre construida
func _build_build(r: float) -> void:
	view.position = V3.to3(plane_pos, 0.0)
	_ring(r * 1.3, Color(0.55, 0.45, 0.32, 0.7), 0.0, 0.45, 0.07)
	var d := _puffs(14, 0.9, color.darkened(0.12), 0.2, 0.34, 1.0, 2.0, 0.5, Vector3(0, 0.12, 0))
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	d.emission_ring_axis = Vector3.UP
	d.emission_ring_radius = r * 0.7
	d.emission_ring_inner_radius = r * 0.4
	d.emission_ring_height = 0.0
	d.direction = Vector3(0, 1, 0)
	d.spread = 80.0
	d.flatness = 0.5
	var ch := _chunks("chip", 12, 0.95, Color.WHITE, 0.06, 0.11, 2.5, 4.2, -10.0, Vector3(0, 0.3, 0))
	ch.color_initial_ramp = VFX.grad("build")
	ch.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ch.emission_sphere_radius = r * 0.35
	_flash(Vector3(0, 0.4, 0), 0.9, Color(1.0, 0.95, 0.8, 0.4), 0.2)


# ================================================================ Mejora de torre
func _build_levelup(r: float) -> void:
	view.position = V3.to3(plane_pos, 0.0)
	_ring(r * 1.1, Color(1.0, 0.72, 0.12, 0.95), 0.0, 0.6, 0.08)
	_ring(r * 0.8, Color(1, 0.88, 0.45, 0.8), 0.2, 0.8, 0.09)
	# Columna de luz breve
	var cm := VFX.new_flat_mat("beam", Color(1.0, 0.85, 0.4, 0.75))
	var col := MeshInstance3D.new()
	col.mesh = VFX.mesh("beam")
	col.material_override = cm
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pivot := Node3D.new()
	view.add_child(pivot)
	pivot.add_child(col)
	col.position = Vector3(0, 0.5, 0)
	_anim(pivot, cm, 0.0, 0.75, Vector3(r * 1.2, 0.2, r * 1.2), Vector3(r * 0.25, 2.8, r * 0.25), 0.75, 1.2)
	# Espiral dorada de chispas (material compartido; sólo cambian posición y escala)
	for i in 14:
		var s := VFX.bill(view, "star", Color(1.0, 0.85, 0.35), 0.01, Vector3.ZERO, true)
		_spiral.append(s)
	var up := _burst("star", true, 12, 1.0, Color(1, 1, 1), "gold", 0.07, 0.13, 0.8, 1.6, Vector3(0, 0.2, 0))
	up.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	up.emission_sphere_radius = r * 0.5
	up.direction = Vector3(0, 1, 0)
	up.spread = 25.0
	up.scale_amount_curve = VFX.curve("pop")
	_flash(Vector3(0, 1.0, 0), 1.1, Color(1.0, 0.85, 0.4, 0.55), 0.5, 0.05)


func _update_spiral() -> void:
	var n := _spiral.size()
	var r := maxf(radius / float(GameData.TILE), 0.2)
	for i in n:
		var s: MeshInstance3D = _spiral[i]
		var u := clampf((_age - i * 0.035) / 0.85, 0.0, 1.0)
		if u <= 0.0 or u >= 1.0:
			s.visible = false
			continue
		s.visible = true
		var ang := i * 0.9 + _age * 7.0
		var rad := r * (0.85 - 0.45 * u)
		s.position = Vector3(cos(ang) * rad, 0.1 + u * 1.9, sin(ang) * rad)
		s.scale = Vector3.ONE * (0.24 * sin(u * PI) + 0.02)


# ================================================================ Muerte de enemigo
func _build_death(r: float) -> void:
	view.position = V3.to3(plane_pos, 0.0)
	var h := 0.3
	var light := color.lerp(Color.WHITE, 0.15)
	_flash(Vector3(0, h, 0), r * 1.2 + 0.2, Color(light, 0.55), 0.15)
	var p := _puffs(9, 0.55, light, r * 0.3 + 0.05, r * 0.5 + 0.08, 1.0, 2.0, 0.8, Vector3(0, h, 0))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r * 0.3
	var ch := _chunks("chip", 7, 0.7, color.darkened(0.1), 0.05 + r * 0.06, 0.08 + r * 0.08, 1.8, 3.0, -9.0, Vector3(0, h, 0))
	ch.hue_variation_min = -0.03
	ch.hue_variation_max = 0.03
	_burst("star", true, 4, 0.4, light, "fade", 0.08, 0.14, 1.0, 2.0, Vector3(0, h, 0))


# ================================================================ Muerte de jefe
func _build_boss(r: float) -> void:
	view.position = V3.to3(plane_pos, 0.0)
	var h := 0.45
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.8, 0.4)
	_light.omni_range = 3.5
	_light_energy = 2.0
	_light.light_energy = _light_energy
	_light.position = Vector3(0, 1.0, 0)
	view.add_child(_light)
	_flash(Vector3(0, h, 0), r * 1.2, Color(1.0, 0.95, 0.75, 0.9), 0.4)
	_flash(Vector3(0, h + 0.2, 0), r * 1.6, Color(1.0, 0.55, 0.1, 0.7), 0.6, 0.05, "glow", false)
	_ring(r * 1.5, Color(1.0, 0.85, 0.35, 0.95), 0.0, 0.6, 0.07)
	_ring(r * 2.0, Color(1.0, 1.0, 0.9, 0.7), 0.15, 0.9, 0.08)
	var fb := _burst("glow", true, 36, 0.9, Color(1, 1, 1), "fire", 0.4, 0.8, 1.5, 4.5, Vector3(0, h, 0))
	fb.damping_min = 3.0
	fb.damping_max = 5.0
	fb.gravity = Vector3(0, 1.2, 0)
	_puffs(14, 1.4, Color(0.8, 0.74, 0.66), 0.35, 0.6, 1.5, 3.0, 0.7, Vector3(0, h, 0))
	var coins := _chunks("coin", 26, 1.6, Color(1.0, 0.8, 0.25), 0.16, 0.22, 3.5, 6.5, -9.8, Vector3(0, h, 0), true)
	coins.spread = 45.0
	var gems := _chunks("gem", 14, 1.6, Color.WHITE, 0.12, 0.18, 3.0, 6.0, -9.8, Vector3(0, h, 0), true)
	gems.color_initial_ramp = VFX.grad("gems")
	gems.spread = 50.0
	var sp := _burst("star", true, 30, 1.4, Color(1, 1, 1), "gold", 0.1, 0.22, 1.0, 3.5, Vector3(0, h, 0))
	sp.damping_min = 1.5
	sp.damping_max = 2.5
	sp.gravity = Vector3(0, 0.5, 0)
	sp.scale_amount_curve = VFX.curve("pop")


# ================================================================ Rayo encadenado
func _build_bolt() -> void:
	var w: Node3D = game.world
	var cam: Camera3D = w.get_viewport().get_camera_3d()
	if cam != null:
		_cam_pos = cam.global_position
	for i in points.size():
		var hh: float = float(heights[i]) if i < heights.size() else 0.5
		_bolt_nodes.append(V3.to3(points[i], hh))
	_bolt_mat = VFX.new_lightning_mat()
	_bolt_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _bolt_mesh
	mi.material_override = _bolt_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.add_child(mi)
	for i in _bolt_nodes.size():
		var p := _bolt_nodes[i]
		if i > 0:
			_flash(p, 0.6, Color(color.lerp(Color.WHITE, 0.4), 0.9), max_life * 0.9, 0.0, "star")
		else:
			_flash(p, 0.4, Color(color, 0.6), max_life * 0.7)
	_draw_bolt()


## Regenera el zigzag (cada ~45 ms el rayo "chisporrotea" con otra forma).
func _draw_bolt() -> void:
	_bolt_mesh.clear_surfaces()
	if _bolt_nodes.size() < 2:
		return
	_bolt_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow := Color(color.lerp(Color.WHITE, 0.15), 0.65)
	for i in _bolt_nodes.size() - 1:
		var path := _jagged(_bolt_nodes[i], _bolt_nodes[i + 1], 1.0)
		_ribbon(path, 0.2, glow)
		_ribbon(path, 0.06, Color(1, 1, 1, 1))
		# Ramas: una pequeña bifurcación por tramo
		if path.size() > 3 and randf() < 0.75:
			var j := randi_range(1, path.size() - 2)
			var a := path[j]
			var dir := (path[j + 1] - path[j - 1]).normalized()
			var off := Vector3(randf_range(-1, 1), randf_range(-0.2, 0.6), randf_range(-1, 1)).normalized()
			var b := a + (dir + off).normalized() * randf_range(0.25, 0.45)
			var br := _jagged(a, b, 0.6)
			_ribbon(br, 0.1, Color(glow, 0.45))
			_ribbon(br, 0.03, Color(1, 1, 1, 0.8))
	_bolt_mesh.surface_end()


func _jagged(a: Vector3, b: Vector3, amp_k: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var dv := b - a
	var length := dv.length()
	var n := clampi(int(length / 0.2), 2, 10)
	var d := dv / maxf(length, 0.001)
	var p1 := d.cross(Vector3.UP)
	if p1.length_squared() < 0.01:
		p1 = d.cross(Vector3.RIGHT)
	p1 = p1.normalized()
	var p2 := d.cross(p1).normalized()
	var amp := minf(0.06 + length * 0.07, 0.28) * amp_k
	for i in n + 1:
		var t := float(i) / n
		var p := a + dv * t
		if i > 0 and i < n:
			var env := sin(t * PI)
			p += (p1 * randf_range(-1.0, 1.0) + p2 * randf_range(-1.0, 1.0) * 0.7) * amp * (0.5 + env * 0.5)
		out.append(p)
	return out


## Cinta orientada a cámara a lo largo de un camino (UV.y = perfil transversal suave).
func _ribbon(path: PackedVector3Array, w: float, col: Color) -> void:
	var n := path.size()
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in n:
		var p := path[i]
		var dir := path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]
		var side := dir.cross(_cam_pos - p).normalized() * w * 0.5
		var l := p + side
		var r := p - side
		if i > 0:
			var u0 := float(i - 1) / (n - 1)
			var u1 := float(i) / (n - 1)
			_v(prev_l, u0, 0.0, col)
			_v(prev_r, u0, 1.0, col)
			_v(l, u1, 0.0, col)
			_v(prev_r, u0, 1.0, col)
			_v(r, u1, 1.0, col)
			_v(l, u1, 0.0, col)
		prev_l = l
		prev_r = r


func _v(p: Vector3, u: float, v: float, col: Color) -> void:
	_bolt_mesh.surface_set_color(col)
	_bolt_mesh.surface_set_uv(Vector2(u, v))
	_bolt_mesh.surface_add_vertex(p)


# ================================================================ Bucle
func _process(delta: float) -> void:
	_age += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	match kind:
		"text":
			_update_text()
			queue_redraw()
			return
		"screen":
			queue_redraw()
			return
		"hit":
			_update_hit()
			return
		"bolt":
			_bolt_timer -= delta
			if _bolt_timer <= 0.0:
				_bolt_timer = 0.045
				_draw_bolt()
			var k := clampf(life / max_life, 0.0, 1.0)
			_bolt_mat.albedo_color.a = k * (0.75 + 0.25 * sin(_age * 90.0))
		"levelup":
			_update_spiral()
	if _light != null:
		_light.light_energy = _light_energy * clampf(1.0 - _age / 0.9, 0.0, 1.0)
	for a in _anims:
		a.update(_age)


func _update_text() -> void:
	# Aparece con un "pop" elástico, sube con frenado y se desvanece al final
	var s := 1.0
	if _age < 0.12:
		s = lerpf(0.3, 1.3, _age / 0.12)
	elif _age < 0.24:
		s = lerpf(1.3, 1.0, (_age - 0.12) / 0.12)
	scale = Vector2.ONE * s
	var u := clampf(_age / max_life, 0.0, 1.0)
	position = _text_start + Vector2(0, -52.0 * (1.0 - pow(1.0 - u, 3.0)))


func _draw() -> void:
	match kind:
		"screen":
			var k := clampf(life / max_life, 0.0, 1.0)
			var sz: Vector2 = GameData.SCREEN
			draw_rect(Rect2(Vector2.ZERO, sz), Color(color, 0.18 * k))
			# Viñeta: bordes más intensos
			var e := 70.0
			var c := Color(color, 0.35 * k)
			draw_rect(Rect2(0, 0, sz.x, e), c)
			draw_rect(Rect2(0, sz.y - e, sz.x, e), c)
			draw_rect(Rect2(0, e, e, sz.y - 2 * e), c)
			draw_rect(Rect2(sz.x - e, e, e, sz.y - 2 * e), c)
		"text":
			var a := clampf(life / 0.3, 0.0, 1.0)
			var font := UIKit.font(true)
			var w := 260.0
			var o := Vector2(-w * 0.5, TEXT_SIZE * 0.35)
			draw_string(font, o + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_CENTER, w, TEXT_SIZE, Color(0, 0, 0, 0.35 * a))
			draw_string_outline(font, o, text, HORIZONTAL_ALIGNMENT_CENTER, w, TEXT_SIZE, 8, Color(color.darkened(0.78), a))
			draw_string(font, o, text, HORIZONTAL_ALIGNMENT_CENTER, w, TEXT_SIZE, Color(color.lerp(Color.WHITE, 0.15), a))


func _exit_tree() -> void:
	if view != null:
		view.queue_free()
		view = null
