class_name TowerModels
extends RefCounted
## Registro de modelos 3D de torres. Cada modelo es un Node3D con:
##   - `cat_pivot` (o `pivot`): nodo que gira para apuntar; el personaje mira a -Z.
##   - una función de pose. Los modelos nuevos implementan `animate(state)`; los
##     portados de Cat Tower Defence usan su `set_pose(...)` original (adaptado aquí).
## state = {t: tiempo stop-motion, charge: 0..1 carga, fire: 1 al disparar -> 0, has_target: bool, tubes: Array}

const ArcherModel := preload("res://scripts/towers3d/archer_model.gd")
const MageModel := preload("res://scripts/towers3d/mage_model.gd")
const IceModel := preload("res://scripts/towers3d/ice_model.gd")
const RocketModel := preload("res://scripts/towers3d/rocket_model.gd")
const ThunderModel := preload("res://scripts/towers3d/thunder_model.gd")

## Modelos nuevos (mismo estilo), por id de torre -> ruta del script.
const NEW_MODELS := {
	"cannon": "res://scripts/towers3d/trebuchet_model.gd",
	"ballista": "res://scripts/towers3d/ballista_model.gd",
	"alchemist": "res://scripts/towers3d/alchemist_model.gd",
	"inferno": "res://scripts/towers3d/inferno_model.gd",
	"obelisk": "res://scripts/towers3d/obelisk_model.gd",
	"sanctuary": "res://scripts/towers3d/sanctuary_model.gd",
	"crossbow": "res://scripts/towers3d/crossbow_model.gd",
	"druid": "res://scripts/towers3d/druid_model.gd",
	"pikes": "res://scripts/towers3d/pikes_model.gd",
	"bell": "res://scripts/towers3d/bell_model.gd",
	"watch": "res://scripts/towers3d/watch_model.gd",
	"tar": "res://scripts/towers3d/tar_model.gd",
	"mortar": "res://scripts/towers3d/mortar_model.gd",
	"herald": "res://scripts/towers3d/herald_model.gd",
}


## Etapa visual según el nivel VISUAL (0..5; ver GameData.visual_level, que convierte los niveles 0..15 de partida): 0 = humilde (madera),
## 1 = reforzada (piedra), 2 = gran torre, 3 = Maestría (majestuosa).
static func tier(level: int) -> int:
	if level >= 5:
		return 3
	if level >= 4:
		return 2
	if level >= 2:
		return 1
	return 0


## Construye el modelo de la torre `id` con el aspecto de su nivel.
## Contrato: los scripts de modelo aceptan el nivel en _init (los del arquero, además la variante).
static func build(id: String, level := 0) -> Node3D:
	var m := _build(id, level)
	ArcherModel.M.facet_tree(m) # estilo low-poly de caras planas
	return m


static func _build(id: String, level := 0) -> Node3D:
	# Torres variante: usan el modelo de otra torre ("model") con su propia paleta ("hue", "sat")
	var def: Dictionary = GameData.TOWERS.get(id, {})
	if def.has("model") and def["model"] != id:
		var m := build(def["model"], level)
		recolor(m, float(def.get("hue", 0.0)), float(def.get("sat", 1.0)), float(def.get("val", 1.0)))
		return m
	match id:
		"archer": return ArcherModel.new("archer", level)
		"poison": return ArcherModel.new("poison", level)
		"mage": return MageModel.new(level)
		"frost": return IceModel.new(level)
		"rocket": return RocketModel.new(level)
		"storm": return ThunderModel.new(level)
	if NEW_MODELS.has(id) and ResourceLoader.exists(NEW_MODELS[id]):
		return load(NEW_MODELS[id]).new(level)
	# Respaldo: modelo simple
	return V3.build_tower(id, level) if GameData.TOWERS.has(id) else Node3D.new()


static func pivot(model: Node3D) -> Node3D:
	var p = model.get("cat_pivot")
	if p == null:
		p = model.get("pivot")
	if p == null:
		p = model.get_node_or_null("Turret")
	return p


static func animate(model: Node3D, s: Dictionary) -> void:
	var t: float = s.get("t", 0.0)
	var charge: float = s.get("charge", 0.0)
	var fire: float = s.get("fire", 0.0)
	var has_target: bool = s.get("has_target", false)
	if model is ArcherModel:
		var pull := charge if has_target else minf(charge, 0.35)
		model.set_pose(pull, fire <= 0.0, fire, t)
	elif model is MageModel or model is IceModel:
		model.set_pose(charge, fire, t, has_target and charge > 0.0)
	elif model is RocketModel:
		model.set_pose(t, s.get("tubes", []))
	elif model is ThunderModel:
		model.set_pose(charge, fire, t)
	elif model.has_method("animate"):
		model.animate(s)


## Punto (global) desde el que sale el proyectil.
static func muzzle(model: Node3D, tube := 0) -> Vector3:
	if model is ArcherModel:
		return model.cat_pivot.to_global(ArcherModel.arrow_tip_local())
	if model is MageModel:
		return model.orb_global()
	if model is IceModel:
		return model.star_global()
	if model is RocketModel:
		return model.tube_mouth(tube)
	if model is ThunderModel:
		return model.cloud_global()
	if model.has_method("muzzle_global"):
		return model.muzzle_global()
	return model.global_position + Vector3(0, 1.3, 0)


static var _tinted := {} # "rid|hue|sat|val" -> Material


## Cambia la paleta de un modelo: gira el tono (hue, 0..1) y escala saturación y brillo
## de todos sus materiales. Los materiales nuevos se guardan para reutilizarlos.
static func recolor(root: Node, hue: float, sat := 1.0, val := 1.0) -> void:
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		if mi.material_override != null:
			mi.material_override = _tint(mi.material_override, hue, sat, val)
		elif mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m != null:
					mi.set_surface_override_material(i, _tint(m, hue, sat, val))
	elif root is MultiMeshInstance3D or root is GPUParticles3D or root is CPUParticles3D:
		var gi := root as GeometryInstance3D
		if gi.material_override != null:
			gi.material_override = _tint(gi.material_override, hue, sat, val)
	for c in root.get_children():
		recolor(c, hue, sat, val)


static func _shift(c: Color, hue: float, sat: float, val: float) -> Color:
	var h := fposmod(c.h + hue, 1.0)
	return Color.from_hsv(h, clampf(c.s * sat, 0.0, 1.0), clampf(c.v * val, 0.0, 1.0), c.a)


static func _tint(m: Material, hue: float, sat: float, val: float) -> Material:
	if not m is BaseMaterial3D:
		return m
	var key := "%d|%.3f|%.2f|%.2f" % [m.get_rid().get_id(), hue, sat, val]
	if _tinted.has(key):
		return _tinted[key]
	var n := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
	n.albedo_color = _shift(n.albedo_color, hue, sat, val)
	if n.emission_enabled:
		n.emission = _shift(n.emission, hue, sat, val)
	_tinted[key] = n
	return n
