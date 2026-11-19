extends RefCounted
## Héroes de cuerpo entero (estilo plastilina, como los defensores de las torres):
## piernas y botas, túnica o armadura, capa, cabeza con cara, peinado o casco, arma y escudo.
## Cada héroe se describe con un diccionario de piezas (LOOKS) para que sea fácil añadir más.
## El personaje se modela mirando a -Z y se gira para que mire a +X (convención de V3.yaw).

const M := preload("res://scripts/towers3d/models.gd")
const Human := preload("res://scripts/towers3d/human_common.gd")

const STEEL := Color(0.72, 0.74, 0.8)
const DARK_STEEL := Color(0.38, 0.4, 0.46)
const GOLD := Color(0.95, 0.75, 0.25)
const LEATHER := Color(0.45, 0.28, 0.15)
const WOOD := Color(0.5, 0.33, 0.18)
const BOOT := Color(0.28, 0.18, 0.1)

## Piezas de cada héroe:
##  cloth/trim/pants: colores de ropa · robe: túnica larga hasta los pies · armor: color de la coraza
##  cape: color de la capa · head: "helm"|"horned"|"hood"|"wizard"|"crown"|"bandana"|"feather"|"leaves"|"circlet"|"witch"|"bald"|""
##  hair/hair_col · long_hair · braids · beard · elf (orejas puntiagudas) · eyepatch · short (enano)
##  weapon: "sword"|"bow"|"staff"|"hammer"|"axe"|"spear"|"lute"|"mace"|"flame_sword" · orb: color del orbe del bastón
##  shield: color del escudo · quiver · satchel · apron · wings
static var LOOKS := {
	"aldric": {"cloth": Color(0.25, 0.38, 0.75), "trim": GOLD, "pants": Color(0.3, 0.3, 0.35), "armor": STEEL,
		"cape": Color(0.75, 0.15, 0.15), "head": "helm", "plume": Color(0.85, 0.15, 0.15), "weapon": "sword", "shield": Color(0.75, 0.15, 0.15)},
	"gareth": {"cloth": Color(0.35, 0.55, 0.25), "trim": LEATHER, "pants": Color(0.4, 0.3, 0.2), "head": "hood",
		"hood_col": Color(0.3, 0.48, 0.2), "hair_col": Color(0.55, 0.35, 0.15), "weapon": "bow", "quiver": true},
	"mira": {"cloth": Color(0.92, 0.9, 0.8), "trim": Color(0.45, 0.7, 0.4), "robe": true, "head": "",
		"hair_col": Color(0.95, 0.8, 0.45), "long_hair": true, "weapon": "staff", "orb": Color(0.5, 1.0, 0.6), "satchel": true},
	"bram": {"cloth": Color(0.6, 0.35, 0.25), "trim": DARK_STEEL, "pants": Color(0.35, 0.3, 0.25), "head": "bald",
		"hair_col": Color(0.7, 0.3, 0.12), "beard": true, "short": true, "apron": true, "weapon": "hammer"},
	"osric": {"cloth": Color(0.5, 0.36, 0.22), "trim": Color(0.85, 0.8, 0.7), "pants": Color(0.3, 0.25, 0.2), "head": "hood",
		"hood_col": Color(0.85, 0.8, 0.7), "hair_col": Color(0.25, 0.18, 0.12), "beard": true, "cape": Color(0.6, 0.5, 0.35), "weapon": "spear"},
	"brunhild": {"cloth": Color(0.45, 0.5, 0.6), "trim": GOLD, "pants": Color(0.35, 0.3, 0.28), "armor": STEEL, "head": "horned",
		"hair_col": Color(0.95, 0.8, 0.4), "braids": true, "weapon": "axe", "shield": Color(0.55, 0.15, 0.12), "cape": Color(0.3, 0.35, 0.5)},
	"elara": {"cloth": Color(0.3, 0.55, 0.3), "trim": Color(0.6, 0.45, 0.25), "robe": true, "head": "leaves",
		"hair_col": Color(0.45, 0.28, 0.15), "long_hair": true, "weapon": "staff", "orb": Color(0.4, 0.9, 0.3), "staff_leaves": true},
	"korvin": {"cloth": Color(0.25, 0.22, 0.25), "trim": Color(0.6, 0.15, 0.15), "pants": Color(0.25, 0.2, 0.18), "head": "bandana",
		"bandana_col": Color(0.7, 0.15, 0.15), "hair_col": Color(0.15, 0.12, 0.1), "beard": true, "eyepatch": true, "weapon": "axe", "cape": Color(0.3, 0.2, 0.22)},
	"isolde": {"cloth": Color(0.85, 0.45, 0.6), "trim": GOLD, "robe": true, "head": "feather", "hat_col": Color(0.55, 0.25, 0.45),
		"hair_col": Color(0.6, 0.3, 0.15), "long_hair": true, "weapon": "lute"},
	"sylva": {"cloth": Color(0.3, 0.6, 0.4), "trim": Color(0.85, 0.75, 0.4), "pants": Color(0.35, 0.3, 0.22), "head": "circlet",
		"hair_col": Color(0.92, 0.92, 0.85), "long_hair": true, "elf": true, "cape": Color(0.25, 0.45, 0.3), "weapon": "bow", "quiver": true},
	"morgana": {"cloth": Color(0.3, 0.2, 0.38), "trim": Color(0.55, 0.85, 0.35), "robe": true, "head": "witch",
		"hat_col": Color(0.22, 0.14, 0.3), "hair_col": Color(0.15, 0.1, 0.12), "long_hair": true, "weapon": "staff", "orb": Color(0.75, 0.35, 1.0)},
	"ulric": {"cloth": Color(0.3, 0.42, 0.75), "trim": Color(0.85, 0.85, 0.95), "robe": true, "head": "circlet",
		"hair_col": Color(0.88, 0.88, 0.92), "long_hair": true, "beard": true, "cape": Color(0.2, 0.25, 0.45), "weapon": "staff", "orb": Color(0.6, 0.85, 1.0)},
	"lyra": {"cloth": Color(0.85, 0.3, 0.2), "trim": GOLD, "robe": true, "head": "wizard", "hat_col": Color(0.75, 0.2, 0.15),
		"hair_col": Color(0.85, 0.35, 0.15), "long_hair": true, "weapon": "staff", "orb": Color(1.0, 0.55, 0.15)},
	"theron": {"cloth": Color(0.95, 0.95, 0.9), "trim": GOLD, "pants": Color(0.85, 0.8, 0.65), "armor": GOLD.lightened(0.15),
		"cape": Color(0.97, 0.97, 0.95), "head": "helm", "helm_col": GOLD.lightened(0.15), "plume": Color(0.97, 0.97, 0.95), "weapon": "mace", "shield": Color(0.97, 0.95, 0.85), "glow": Color(1.0, 0.9, 0.5)},
	"vex": {"cloth": Color(0.35, 0.08, 0.1), "trim": Color(0.95, 0.5, 0.15), "pants": Color(0.2, 0.08, 0.08), "armor": Color(0.3, 0.12, 0.12),
		"cape": Color(0.12, 0.05, 0.06), "head": "horned", "helm_col": Color(0.25, 0.1, 0.1), "horn_col": Color(0.15, 0.1, 0.08), "weapon": "flame_sword", "wings": Color(0.45, 0.1, 0.1)},
	"tomas": {"cloth": Color(0.55, 0.4, 0.25), "trim": Color(0.85, 0.75, 0.5), "robe": true, "head": "bald",
		"hair_col": Color(0.4, 0.28, 0.15), "beard": true, "weapon": "staff", "orb": Color(1.0, 0.95, 0.7), "satchel": true},
	"wynn": {"cloth": Color(0.7, 0.25, 0.2), "trim": Color(0.3, 0.25, 0.2), "pants": Color(0.3, 0.3, 0.25), "head": "bandana",
		"bandana_col": Color(0.25, 0.45, 0.25), "hair_col": Color(0.85, 0.5, 0.2), "braids": true, "weapon": "axe"},
	"pip": {"cloth": Color(0.35, 0.35, 0.4), "trim": Color(0.6, 0.15, 0.2), "pants": Color(0.25, 0.22, 0.2), "head": "hood",
		"hood_col": Color(0.25, 0.25, 0.3), "hair_col": Color(0.3, 0.2, 0.12), "short": true, "weapon": "sword", "satchel": true},
	"gwen": {"cloth": Color(0.5, 0.15, 0.2), "trim": Color(0.75, 0.75, 0.8), "pants": Color(0.2, 0.18, 0.18), "head": "feather",
		"hat_col": Color(0.15, 0.12, 0.12), "hair_col": Color(0.12, 0.1, 0.1), "long_hair": true, "cape": Color(0.25, 0.08, 0.1), "weapon": "bow", "quiver": true},
	"hector": {"cloth": Color(0.25, 0.35, 0.65), "trim": GOLD, "pants": Color(0.3, 0.3, 0.35), "armor": STEEL, "head": "helm",
		"plume": Color(0.2, 0.3, 0.7), "hair_col": Color(0.3, 0.2, 0.12), "beard": true, "cape": Color(0.2, 0.3, 0.6), "weapon": "spear", "shield": Color(0.2, 0.3, 0.65)},
	"nyx": {"cloth": Color(0.18, 0.15, 0.28), "trim": Color(0.55, 0.45, 0.85), "pants": Color(0.12, 0.1, 0.18), "head": "hood",
		"hood_col": Color(0.15, 0.12, 0.25), "hair_col": Color(0.85, 0.85, 0.95), "long_hair": true, "elf": true, "cape": Color(0.1, 0.08, 0.18), "weapon": "sword"},
	"freya": {"cloth": Color(0.75, 0.8, 0.9), "trim": GOLD, "pants": Color(0.4, 0.42, 0.5), "armor": STEEL.lightened(0.1), "head": "helm",
		"hair_col": Color(0.95, 0.85, 0.5), "braids": true, "weapon": "spear", "shield": Color(0.85, 0.75, 0.35), "wings": Color(0.95, 0.95, 1.0)},
	"aurelia": {"cloth": Color(0.6, 0.82, 1.0), "trim": Color(0.95, 0.97, 1.0), "robe": true, "head": "crown",
		"hair_col": Color(0.92, 0.95, 1.0), "long_hair": true, "cape": Color(0.75, 0.9, 1.0), "weapon": "staff", "orb": Color(0.6, 0.9, 1.0), "glow": Color(0.7, 0.9, 1.0)},
	"goran": {"cloth": Color(0.55, 0.4, 0.28), "trim": GOLD, "pants": Color(0.35, 0.28, 0.22), "armor": DARK_STEEL, "head": "crown",
		"hair_col": Color(0.6, 0.35, 0.18), "beard": true, "short": true, "cape": Color(0.55, 0.12, 0.12), "weapon": "hammer"},
	"seraphina": {"cloth": Color(1.0, 0.97, 0.9), "trim": GOLD, "robe": true, "head": "circlet",
		"hair_col": Color(1.0, 0.85, 0.45), "long_hair": true, "weapon": "flame_sword", "shield": Color(1.0, 0.92, 0.6), "wings": Color(1.0, 1.0, 0.97), "glow": Color(1.0, 0.95, 0.6)},
	"malakar": {"cloth": Color(0.2, 0.08, 0.22), "trim": Color(0.5, 0.95, 0.6), "robe": true, "head": "hood",
		"hood_col": Color(0.15, 0.05, 0.15), "hair_col": Color(0.8, 0.8, 0.8), "beard": true, "cape": Color(0.1, 0.03, 0.1), "weapon": "staff", "orb": Color(0.45, 1.0, 0.55), "glow": Color(0.5, 1.0, 0.6)},
}


static func build(id: String) -> Node3D:
	var def: Dictionary = GameData.HEROES[id]
	var look: Dictionary = LOOKS.get(id, {"cloth": def["color"], "trim": GOLD, "weapon": "sword", "head": "helm"})
	var root := Node3D.new()
	root.name = "Hero_" + id
	# Peana con el color de la rareza
	var rc: Color = GameData.RARITIES[def["rarity"]]["color"]
	M.cyl(root, 0.36, 0.38, 0.06, M.mat(Color(0.3, 0.26, 0.22)), Vector3(0, 0.03, 0), Vector3.ZERO, 20)
	M.cyl(root, 0.39, 0.39, 0.03, M.mat(rc, 0.4), Vector3(0, 0.02, 0), Vector3.ZERO, 20)
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0, 0.06, 0)
	root.add_child(turret)
	var c := Node3D.new()
	c.rotation.y = -PI * 0.5 # modelado mirando a -Z → mira a +X
	c.scale = Vector3.ONE * (1.05 if look.get("short", false) else 1.15)
	turret.add_child(c)
	_character(c, look)
	var ready := MeshInstance3D.new()
	ready.name = "Ready"
	ready.mesh = M.sphere_mesh(0.07)
	ready.material_override = M.mat(Color(0.4, 1, 0.5), 2.5)
	ready.position = Vector3(0, 1.15, 0)
	root.add_child(ready)
	return root


static func _character(c: Node3D, L: Dictionary) -> void:
	var cloth := M.mat(L["cloth"])
	var trim := M.mat(L.get("trim", GOLD))
	var pants := M.mat(L.get("pants", Color(0.3, 0.25, 0.2)))
	var boot := M.mat(BOOT)
	var short: bool = L.get("short", false)
	var hip := 0.2 if short else 0.3
	# --- Piernas y botas
	for s in [-1.0, 1.0]:
		M.segment(c, 0.05, pants, Vector3(0.062 * s, hip, 0), Vector3(0.066 * s, 0.08, 0), 8)
		M.box(c, Vector3(0.09, 0.08, 0.15), boot, Vector3(0.066 * s, 0.04, -0.025))
	if L.get("robe", false):
		M.cyl(c, 0.12, 0.21, hip + 0.02, cloth, Vector3(0, (hip + 0.02) * 0.5, 0), Vector3.ZERO, 18)
		M.cyl(c, 0.215, 0.215, 0.025, trim, Vector3(0, 0.02, 0), Vector3.ZERO, 18)
	# --- Torso (pieza del kit de humanos)
	var u := Node3D.new()
	u.position = Vector3(0, hip - 0.04, 0)
	c.add_child(u)
	if short:
		u.scale = Vector3(1.15, 1.0, 1.1)
	Human.body(u, cloth, trim)
	M.cyl(u, 0.158, 0.158, 0.035, M.mat(LEATHER), Vector3(0, 0.05, 0), Vector3.ZERO, 16) # cinturón
	M.box(u, Vector3(0.05, 0.04, 0.02), M.metal(GOLD), Vector3(0, 0.05, -0.155)) # hebilla
	if L.has("armor"):
		var am := M.metal(L["armor"])
		M.sphere(u, 0.147, am, Vector3(0, 0.185, -0.012), Vector3(1.03, 1.08, 0.88), 14)
		for s in [-1.0, 1.0]:
			M.sphere(u, 0.075, am, Vector3(0.145 * s, 0.28, 0), Vector3(1.0, 0.75, 1.0), 10)
	if L.get("apron", false):
		M.box(u, Vector3(0.22, 0.3, 0.02), M.mat(LEATHER), Vector3(0, 0.08, -0.14), Vector3(-6, 0, 0))
	if L.get("satchel", false):
		M.box(u, Vector3(0.1, 0.09, 0.05), M.mat(LEATHER), Vector3(-0.16, 0.04, -0.03))
		M.segment(u, 0.012, M.mat(LEATHER), Vector3(-0.15, 0.06, -0.05), Vector3(0.1, 0.3, -0.1), 6)
	if L.get("quiver", false):
		M.cyl(u, 0.045, 0.045, 0.26, M.mat(LEATHER), Vector3(0.06, 0.22, 0.14), Vector3(0, 0, -20), 10)
		for k in 3:
			M.box(u, Vector3(0.02, 0.05, 0.02), M.mat(Color(0.9, 0.9, 0.85)), Vector3(0.1 + k * 0.015, 0.37, 0.14 + (k - 1) * 0.02), Vector3(0, 0, -20))
	if L.has("cape"):
		var cm := M.mat(L["cape"])
		M.box(u, Vector3(0.3, 0.06, 0.06), cm, Vector3(0, 0.3, 0.07))
		var cape_len := 0.42 + hip * 0.6
		M.box(u, Vector3(0.3, cape_len, 0.025), cm, Vector3(0, 0.3 - cape_len * 0.5, 0.13), Vector3(8, 0, 0))
	if L.has("wings"):
		var wm := M.mat(L["wings"])
		for s in [-1.0, 1.0]:
			M.box(u, Vector3(0.36, 0.2, 0.02), wm, Vector3(0.2 * s, 0.38, 0.17), Vector3(0, 20 * s, 30 * s))
			M.segment(u, 0.015, M.mat(Color(0.15, 0.08, 0.08)), Vector3(0.05 * s, 0.3, 0.16), Vector3(0.37 * s, 0.5, 0.2), 6)
	# --- Brazos: la mano derecha sostiene el arma delante
	var rh := Vector3(0.17, 0.12, -0.13)
	var lh := Vector3(-0.17, 0.12, -0.09)
	var weapon: String = L.get("weapon", "sword")
	if weapon == "bow":
		lh = Vector3(-0.12, 0.2, -0.2)
		rh = Vector3(0.05, 0.22, -0.06)
	elif weapon == "lute":
		rh = Vector3(0.06, 0.12, -0.17)
		lh = Vector3(-0.17, 0.2, -0.16)
	var sleeve := cloth if not L.has("armor") else M.metal(L["armor"])
	Human.arm(u, Human.R_SHOULDER, rh, sleeve, trim)
	Human.arm(u, Human.L_SHOULDER, lh, sleeve, trim)
	_weapon(u, weapon, rh, lh, L)
	if L.has("shield"):
		var sh := Node3D.new()
		sh.position = lh + Vector3(-0.03, 0.0, -0.04)
		sh.rotation_degrees = Vector3(90, 0, 0)
		u.add_child(sh)
		M.cyl(sh, 0.13, 0.13, 0.03, M.mat(L["shield"]), Vector3.ZERO, Vector3.ZERO, 18)
		M.cyl(sh, 0.135, 0.135, 0.02, M.metal(GOLD), Vector3(0, 0.004, 0), Vector3.ZERO, 18)
		M.cyl(sh, 0.04, 0.04, 0.03, M.metal(GOLD), Vector3(0, -0.02, 0), Vector3.ZERO, 10)
	# --- Cabeza
	var head_kind: String = L.get("head", "")
	var covered := head_kind in ["helm", "horned", "hood", "witch", "wizard"]
	var hair_col: Color = L.get("hair_col", Human.HAIR)
	var bald := head_kind == "bald"
	var h := Human.head(u, not covered, not covered and not bald, hair_col)
	_head_gear(h, head_kind, L, hair_col)
	if L.get("long_hair", false) and head_kind != "helm":
		var hm := M.mat(hair_col)
		M.box(h, Vector3(0.25, 0.26, 0.09), hm, Vector3(0, -0.1, 0.085))
		for s in [-1.0, 1.0]:
			M.box(h, Vector3(0.05, 0.2, 0.07), hm, Vector3(0.12 * s, -0.08, -0.02))
	if L.get("braids", false):
		var bm := M.mat(hair_col)
		for s in [-1.0, 1.0]:
			M.segment(h, 0.032, bm, Vector3(0.12 * s, -0.04, -0.02), Vector3(0.13 * s, -0.24, -0.06), 6)
			M.sphere(h, 0.025, M.mat(LEATHER), Vector3(0.13 * s, -0.25, -0.06))
	if L.get("beard", false):
		M.sphere(h, 0.1, M.mat(hair_col), Vector3(0, -0.1, -0.075), Vector3(1.05, 1.05 if not short else 1.35, 0.75), 12)
		M.box(h, Vector3(0.09, 0.015, 0.012), M.mat(hair_col.darkened(0.2)), Vector3(0, -0.055, -0.135)) # bigote
	if L.get("elf", false):
		for s in [-1.0, 1.0]:
			M.cyl(h, 0.0, 0.03, 0.1, M.mat(Human.SKIN_SHADE), Vector3(0.15 * s, 0.03, 0.01), Vector3(0, 0, -70 * s), 6)
	if L.get("eyepatch", false):
		M.box(h, Vector3(0.05, 0.04, 0.015), M.mat(Color(0.08, 0.06, 0.05)), Vector3(-0.048, 0.01, -0.132))
		M.segment(h, 0.006, M.mat(Color(0.08, 0.06, 0.05)), Vector3(-0.14, 0.04, 0.0), Vector3(0.13, 0.06, -0.02), 4)
	if L.has("glow"):
		var halo := M.cyl(h, 0.16, 0.16, 0.012, M.mat(L["glow"], 2.0), Vector3(0, 0.26, 0.02), Vector3(-10, 0, 0), 20)
		halo.scale = Vector3(1, 1, 1)


static func _head_gear(h: Node3D, kind: String, L: Dictionary, hair_col: Color) -> void:
	match kind:
		"helm":
			var hm := M.metal(L.get("helm_col", STEEL))
			M.sphere(h, 0.152, hm, Vector3(0, 0.025, 0.005), Vector3(1.0, 1.0, 1.02), 16)
			M.box(h, Vector3(0.2, 0.03, 0.03), M.mat(Color(0.1, 0.1, 0.12)), Vector3(0, 0.01, -0.145))
			M.box(h, Vector3(0.025, 0.1, 0.03), hm, Vector3(0, -0.04, -0.15)) # nasal
			if L.has("plume"):
				M.sphere(h, 0.07, M.mat(L["plume"]), Vector3(0, 0.17, 0.04), Vector3(0.45, 1.0, 1.8), 10)
		"horned":
			var hm := M.metal(L.get("helm_col", STEEL))
			M.sphere(h, 0.15, hm, Vector3(0, 0.035, 0.01), Vector3(1.0, 0.85, 1.0), 16)
			M.cyl(h, 0.152, 0.152, 0.03, M.metal(GOLD), Vector3(0, 0.0, 0.0), Vector3.ZERO, 16)
			var horn := M.mat(L.get("horn_col", Color(0.92, 0.88, 0.75)))
			for s in [-1.0, 1.0]:
				M.cyl(h, 0.0, 0.035, 0.16, horn, Vector3(0.17 * s, 0.1, 0.0), Vector3(0, 0, -55 * s), 8)
			M.box(h, Vector3(0.025, 0.09, 0.03), hm, Vector3(0, -0.03, -0.148))
		"hood":
			var hc := M.mat(L.get("hood_col", L["cloth"]))
			M.sphere(h, 0.158, hc, Vector3(0, 0.035, 0.045), Vector3(1.0, 1.05, 1.05), 16)
			M.cyl(h, 0.0, 0.06, 0.12, hc, Vector3(0, 0.08, 0.18), Vector3(-60, 0, 0), 8)
			M.sphere(h, 0.035, M.mat(hair_col), Vector3(0, 0.09, -0.11), Vector3(2.5, 0.7, 0.7), 8) # flequillo
		"wizard", "witch":
			var hc := M.mat(L.get("hat_col", L["cloth"]))
			var brim := 0.27 if kind == "witch" else 0.22
			M.sphere(h, 0.142, M.mat(hair_col), Vector3(0, 0.03, 0.025), Vector3.ONE, 14)
			M.cyl(h, brim, brim, 0.022, hc, Vector3(0, 0.1, 0.0), Vector3.ZERO, 20)
			M.cyl(h, 0.0, 0.13, 0.32, hc, Vector3(0, 0.27, 0.03), Vector3(-14, 0, 6), 14)
			M.cyl(h, 0.133, 0.133, 0.03, M.mat(L.get("trim", GOLD)), Vector3(0, 0.125, 0.0), Vector3.ZERO, 16)
		"crown", "circlet":
			var gm := M.metal(GOLD if kind == "crown" else Color(0.85, 0.87, 0.95))
			M.cyl(h, 0.142, 0.142, 0.025, gm, Vector3(0, 0.075, 0.0), Vector3.ZERO, 18)
			M.sphere(h, 0.022, M.mat(Color(0.4, 0.8, 1.0), 1.5), Vector3(0, 0.08, -0.14), Vector3.ONE, 8)
		"bandana":
			var bm := M.mat(L.get("bandana_col", Color(0.7, 0.15, 0.15)))
			M.sphere(h, 0.146, bm, Vector3(0, 0.05, 0.02), Vector3(1.0, 0.8, 1.0), 14)
			M.box(h, Vector3(0.04, 0.1, 0.03), bm, Vector3(0.04, -0.02, 0.15), Vector3(0, 0, 20))
		"feather":
			var hc := M.mat(L.get("hat_col", L["cloth"]))
			M.cyl(h, 0.2, 0.2, 0.02, hc, Vector3(0, 0.11, 0.0), Vector3(0, 0, 8), 18)
			M.cyl(h, 0.11, 0.13, 0.08, hc, Vector3(0, 0.15, 0.01), Vector3(0, 0, 8), 14)
			M.sphere(h, 0.06, M.mat(Color(0.97, 0.97, 0.95)), Vector3(-0.1, 0.22, 0.06), Vector3(0.35, 1.6, 0.6), 8)
		"leaves":
			var lm := M.mat(Color(0.3, 0.7, 0.25))
			for k in 7:
				var a := TAU * k / 7.0
				M.sphere(h, 0.035, lm, Vector3(cos(a) * 0.14, 0.08, sin(a) * 0.14), Vector3(1.4, 0.5, 0.8), 6)
			M.sphere(h, 0.025, M.mat(Color(0.95, 0.4, 0.5)), Vector3(0.1, 0.1, -0.1), Vector3.ONE, 6)


static func _weapon(u: Node3D, kind: String, rh: Vector3, lh: Vector3, L: Dictionary) -> void:
	var wood := M.mat(WOOD)
	match kind:
		"sword", "flame_sword":
			var flame := kind == "flame_sword"
			M.segment(u, 0.016, M.mat(LEATHER), rh + Vector3(0, -0.05, 0), rh + Vector3(0, 0.04, 0), 6)
			M.box(u, Vector3(0.13, 0.025, 0.035), M.metal(GOLD), rh + Vector3(0, 0.05, 0))
			var blade := M.box(u, Vector3(0.035, 0.38, 0.012), M.mat(Color(1.0, 0.45, 0.1), 2.2) if flame else M.metal(Color(0.9, 0.92, 0.96)), rh + Vector3(0, 0.25, -0.03), Vector3(-12, 0, 0))
			blade.name = "Blade"
		"bow":
			var bm := M.mat(WOOD.darkened(0.1))
			var pts: Array = []
			for k in 7:
				var t := (k / 6.0) * 2.0 - 1.0
				pts.append(lh + Vector3(0, t * 0.28, 0.07 * (1.0 - t * t) - 0.07))
			for k in 6:
				M.segment(u, 0.016, bm, pts[k], pts[k + 1], 6)
			M.segment(u, 0.004, M.mat(Color(0.95, 0.95, 0.9)), pts[0], rh, 4)
			M.segment(u, 0.004, M.mat(Color(0.95, 0.95, 0.9)), rh, pts[6], 4)
			M.segment(u, 0.008, M.mat(Color(0.85, 0.8, 0.7)), rh, lh + Vector3(0, 0, -0.1), 4) # flecha
		"staff":
			M.segment(u, 0.018, wood, rh + Vector3(0, -0.36, 0.02), rh + Vector3(0, 0.42, -0.02), 6)
			var orb: Color = L.get("orb", Color(0.6, 0.8, 1.0))
			M.sphere(u, 0.055, M.mat(orb, 2.2), rh + Vector3(0, 0.48, -0.02), Vector3.ONE, 12)
			for s in [-1.0, 1.0]:
				M.segment(u, 0.01, wood, rh + Vector3(0, 0.4, -0.02), rh + Vector3(0.04 * s, 0.5, -0.02), 4)
			if L.get("staff_leaves", false):
				for k in 3:
					M.sphere(u, 0.03, M.mat(Color(0.3, 0.7, 0.25)), rh + Vector3(0.04 * cos(k * 2.1), 0.42, 0.04 * sin(k * 2.1)), Vector3(1.3, 0.6, 0.9), 6)
		"hammer":
			M.segment(u, 0.017, wood, rh + Vector3(0, -0.08, 0), rh + Vector3(0, 0.3, -0.04), 6)
			M.box(u, Vector3(0.18, 0.1, 0.1), M.metal(DARK_STEEL), rh + Vector3(0, 0.32, -0.04))
		"axe":
			M.segment(u, 0.016, wood, rh + Vector3(0, -0.1, 0), rh + Vector3(0, 0.33, -0.04), 6)
			M.box(u, Vector3(0.025, 0.14, 0.12), M.metal(Color(0.85, 0.87, 0.92)), rh + Vector3(0.05, 0.3, -0.04), Vector3(0, 0, 0))
			M.sphere(u, 0.06, M.metal(Color(0.85, 0.87, 0.92)), rh + Vector3(0.07, 0.3, -0.04), Vector3(0.4, 1.1, 1.0), 10)
		"spear":
			M.segment(u, 0.014, wood, rh + Vector3(0, -0.4, 0.04), rh + Vector3(0, 0.55, -0.06), 6)
			M.cyl(u, 0.0, 0.03, 0.12, M.metal(Color(0.9, 0.9, 0.95)), rh + Vector3(0, 0.6, -0.065), Vector3(-6, 0, 0), 6)
		"mace":
			M.segment(u, 0.017, M.metal(GOLD), rh + Vector3(0, -0.06, 0), rh + Vector3(0, 0.24, -0.03), 6)
			M.sphere(u, 0.07, M.metal(GOLD.lightened(0.2)), rh + Vector3(0, 0.28, -0.03), Vector3.ONE, 12)
			for k in 6:
				var a := TAU * k / 6.0
				M.cyl(u, 0.0, 0.02, 0.05, M.metal(GOLD), rh + Vector3(cos(a) * 0.07, 0.28, -0.03 + sin(a) * 0.07), Vector3(0, -rad_to_deg(a), 90), 5)
		"lute":
			var body := Node3D.new()
			body.position = Vector3(0.0, 0.12, -0.19)
			body.rotation_degrees = Vector3(0, 0, 45)
			u.add_child(body)
			M.sphere(body, 0.09, M.mat(Color(0.75, 0.48, 0.25)), Vector3(0, 0, 0), Vector3(1.0, 1.25, 0.45), 14)
			M.sphere(body, 0.025, M.mat(Color(0.2, 0.12, 0.08)), Vector3(0, 0.02, -0.04), Vector3(1, 1, 0.3), 8)
			M.box(body, Vector3(0.035, 0.22, 0.025), M.mat(Color(0.4, 0.25, 0.12)), Vector3(0, 0.2, 0))
			M.box(body, Vector3(0.05, 0.06, 0.03), M.mat(Color(0.4, 0.25, 0.12)), Vector3(0, 0.33, 0.01), Vector3(-25, 0, 0))
