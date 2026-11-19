extends Node
## Definiciones estáticas del juego: torres, héroes, enemigos, mapas, mejoras y sobres.
## Todo el balance vive aquí para poder ajustarlo sin tocar la lógica.

const TILE := 72
# Tamaño del tablero del mapa actual (lo fija la partida al cargar el mapa; ver MapGen).
var COLS := 11
var ROWS := 18
const SCREEN := Vector2(1920, 1080) # tamaño base; el real (ventana con otra proporción) lo da screen()


## Tamaño real del área de juego (con stretch "expand" puede ser algo más ancho o alto que SCREEN).
func screen() -> Vector2:
	var vp := get_viewport()
	return vp.get_visible_rect().size if vp != null else SCREEN
const GRID_OFFSET := Vector2(0, 72)
const MAX_WAVES := 500
const UNLOCK_WAVE := 100
const MAX_TOWER_LEVEL := 15 # niveles de torre en la partida: 0..15 (el 15 es la Maestría, con oro)
const MAX_CARD_LEVEL := 5
const START_LIVES := 50 # vida de la fortaleza
const START_GOLD := 180

# Estado de navegación entre escenas (no constante).
var current_map := 0

# Enemigos y mapas: se copian de las constantes y se completan con los enemigos temáticos.
var ENEMIES: Dictionary = {}
var MAPS: Array = []


func _init() -> void:
	ENEMIES = BASE_ENEMIES.duplicate(true)
	MAPS = BASE_MAPS.duplicate(true)
	_build_themed_enemies()

# ---------------------------------------------------------------- Rarezas
const RARITIES := {
	"common": {"name": "Común", "color": Color(0.75, 0.75, 0.72)},
	"uncommon": {"name": "Poco común", "color": Color(0.35, 0.8, 0.35)},
	"rare": {"name": "Rara", "color": Color(0.3, 0.6, 1.0)},
	"epic": {"name": "Épica", "color": Color(0.72, 0.35, 0.95)},
	"legendary": {"name": "Legendaria", "color": Color(1.0, 0.72, 0.15)},
}
const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary"]

# ---------------------------------------------------------------- Tipos de daño
const DAMAGE_TYPES := {
	"physical": {"name": "Físico", "color": Color(0.85, 0.8, 0.7)},
	"magic": {"name": "Arcano", "color": Color(0.6, 0.45, 1.0)},
	"fire": {"name": "Fuego", "color": Color(1.0, 0.45, 0.15)},
	"ice": {"name": "Hielo", "color": Color(0.55, 0.85, 1.0)},
	"poison": {"name": "Veneno", "color": Color(0.45, 0.9, 0.3)},
	"lightning": {"name": "Rayo", "color": Color(1.0, 0.95, 0.4)},
	"holy": {"name": "Sagrado", "color": Color(1.0, 0.95, 0.7)},
}

# ---------------------------------------------------------------- Torres
# rate = ataques/segundo, range = casillas, splash = radio en casillas.
# "perks" se aplican al alcanzar el nivel 15 (maestría) y sobrescriben valores base.
const TOWERS := {
	# --- Torres de Cat Tower Defence (con defensores humanos) ---
	"archer": {
		"name": "Torre de Arqueros", "rarity": "common", "unlock": {"map": 0, "wave": 0}, "cost": 60,
		"damage": 9.0, "rate": 1.25, "range": 2.6, "dmg_type": "physical",
		"air": true, "ground": true, "projectile": "arrow",
		"color": Color(0.45, 0.82, 1.0),
		"desc": "Arquero veloz. Alcanza enemigos voladores.",
		"perk_desc": "Maestría: Lluvia de flechas (3 flechas por disparo).",
		"perks": {"multishot": 3},
	},
	"poison": {
		"name": "Torre de Flechas Venenosas", "rarity": "common", "unlock": {"map": 0, "wave": 10}, "cost": 75,
		"damage": 5.0, "rate": 1.2, "range": 2.4, "dmg_type": "poison",
		"air": true, "ground": true, "dot": 9.0, "dot_dur": 3.0, "slow": 0.5, "slow_dur": 3.0,
		"prefer": "unpoisoned", "projectile": "arrow_poison",
		"color": Color(0.45, 0.9, 0.3),
		"desc": "Flechas envenenadas: daño continuo y el enemigo va a mitad de velocidad.",
		"perk_desc": "Maestría: Doble flecha y veneno corrosivo (reduce armadura).",
		"perks": {"multishot": 2, "armor_break": 0.5},
	},
	"mage": {
		"name": "Maga de Fuego", "rarity": "common", "unlock": {"map": 1, "wave": 20}, "cost": 110,
		"damage": 48.0, "rate": 0.5, "range": 2.4, "dmg_type": "fire",
		"air": true, "ground": true, "projectile": "fireball",
		"color": Color(1.0, 0.45, 0.1),
		"desc": "Carga una bola de fuego durante 2 s y la lanza con mucho daño.",
		"perk_desc": "Maestría: Bola de fuego explosiva (daño en área y quemadura).",
		"perks": {"splash": 0.8, "dot": 20.0, "dot_dur": 3.0},
	},
	"frost": {
		"name": "Mago de Hielo", "rarity": "uncommon", "unlock": {"map": 2, "wave": 60}, "cost": 90,
		"damage": 6.0, "rate": 0.4, "range": 2.6, "dmg_type": "ice",
		"air": true, "ground": true, "stun_chance": 1.0, "stun_dur": 1.0, "prefer": "unfrozen",
		"projectile": "ice", "color": Color(0.5, 0.85, 1.0),
		"desc": "Carga lentamente un fragmento de hielo que congela al enemigo 1 s.",
		"perk_desc": "Maestría: Ventisca (congela en área 1.5 s).",
		"perks": {"splash": 0.8, "stun_dur": 1.5},
	},
	"rocket": {
		"name": "Lanzacohetes", "rarity": "rare", "cost": 160,
		"damage": 9.0, "rate": 0.28, "range": 3.2, "dmg_type": "fire",
		"air": false, "ground": true, "rockets": 6, "splash": 0.85, "projectile": "rocket",
		"color": Color(0.9, 0.25, 0.1),
		"desc": "Salva de 6 cohetes de pólvora que caen en área. No ataca voladores.",
		"perk_desc": "Maestría: Salva doble (10 cohetes).",
		"perks": {"rockets": 10},
	},
	"storm": {
		"name": "Hechicero del Trueno", "rarity": "epic", "cost": 180,
		"damage": 30.0, "rate": 0.7, "range": 2.6, "dmg_type": "lightning",
		"air": true, "ground": true, "chain": 3, "projectile": "",
		"color": Color(1.0, 0.85, 0.3),
		"desc": "Rayo desde su nube que salta en cadena a 3 enemigos cercanos.",
		"perk_desc": "Maestría: Tempestad (salta 6 veces, 10% aturdir).",
		"perks": {"chain": 6, "stun_chance": 0.1, "stun_dur": 0.8},
	},
	# --- Torres de asedio y gremio ---
	"cannon": {
		"name": "Trebuchet", "rarity": "common", "unlock": {"map": 0, "wave": 25}, "cost": 90,
		"damage": 24.0, "rate": 0.45, "range": 2.6, "dmg_type": "physical",
		"air": false, "ground": true, "splash": 0.9, "projectile": "rock",
		"color": Color(0.45, 0.42, 0.4),
		"desc": "Lanza rocas que hacen daño en área. No puede atacar a voladores.",
		"perk_desc": "Maestría: Impacto aturdidor (25% de aturdir 1 s).",
		"perks": {"stun_chance": 0.25, "stun_dur": 1.0},
	},
	"ballista": {
		"name": "Balista Real", "rarity": "uncommon", "unlock": {"map": 3, "wave": 40}, "cost": 140,
		"damage": 42.0, "rate": 0.5, "range": 3.4, "dmg_type": "physical",
		"air": true, "ground": false, "air_bonus": 2.0, "projectile": "bolt",
		"color": Color(0.6, 0.45, 0.25),
		"desc": "Antiaérea: SOLO ataca voladores, con doble daño (¡cazadragones!).",
		"perk_desc": "Maestría: Perforadragones (x3.5 contra voladores, 20% crítico).",
		"perks": {"air_bonus": 3.5, "crit_bonus": 0.2},
	},
	"crossbow": {
		"name": "Torre de Ballesteros", "rarity": "uncommon", "unlock": {"map": 1, "wave": 60}, "cost": 120,
		"damage": 50.0, "rate": 0.45, "range": 2.8, "dmg_type": "physical",
		"air": true, "ground": true, "armor_break": 0.4, "detect": true, "projectile": "bolt",
		"color": Color(0.55, 0.5, 0.45),
		"desc": "Virotes que rompen armaduras. Ojo de halcón: ve a los enemigos invisibles.",
		"perk_desc": "Maestría: Virote perforante (rompe toda la armadura, 25% crítico).",
		"perks": {"armor_break": 1.0, "crit_bonus": 0.25},
	},
	# --- Torres de oro nuevas (se desbloquean jugando) ---
	"pikes": {
		"name": "Cuartel de Lanceros", "rarity": "common", "unlock": {"map": 0, "wave": 45}, "cost": 100,
		"damage": 26.0, "rate": 0.9, "range": 1.6, "dmg_type": "physical",
		"air": false, "ground": true, "armor_break": 0.25, "projectile": "slash",
		"color": Color(0.7, 0.7, 0.75),
		"desc": "Lanceros cuerpo a cuerpo: golpes muy fuertes que perforan armadura. Solo tierra.",
		"perk_desc": "Maestría: Muro de picas (aturde un 25% de las veces).",
		"perks": {"armor_break": 0.5, "stun_chance": 0.25, "stun_dur": 0.7},
	},
	"bell": {
		"name": "Campanario", "rarity": "uncommon", "unlock": {"map": 2, "wave": 30}, "cost": 130,
		"damage": 6.0, "rate": 0.8, "range": 2.2, "dmg_type": "holy",
		"air": true, "ground": true, "speed_aura": 0.15, "aura_range": 1.6, "projectile": "holy",
		"color": Color(1.0, 0.85, 0.45),
		"desc": "Su campana acelera un 15% a las torres cercanas. Daño sagrado ligero.",
		"perk_desc": "Maestría: Repique real (+30% de velocidad y más alcance del aura).",
		"perks": {"speed_aura": 0.3, "aura_range": 2.1},
	},
	"watch": {
		"name": "Atalaya del Vigía", "rarity": "uncommon", "unlock": {"map": 4, "wave": 30}, "cost": 110,
		"damage": 7.0, "rate": 1.0, "range": 3.8, "dmg_type": "physical",
		"air": true, "ground": true, "detect": true, "projectile": "arrow",
		"color": Color(0.6, 0.8, 0.5),
		"desc": "Alcance enorme y ve a los enemigos invisibles. Poco daño.",
		"perk_desc": "Maestría: Ojo de halcón (+25% de crítico).",
		"perks": {"crit_bonus": 0.25},
	},
	"tar": {
		"name": "Catapulta de Brea", "rarity": "rare", "unlock": {"map": 5, "wave": 40}, "cost": 150,
		"damage": 14.0, "rate": 0.55, "range": 2.6, "dmg_type": "fire",
		"air": false, "ground": true, "splash": 0.8, "slow": 0.45, "slow_dur": 3.0, "dot": 6.0, "dot_dur": 3.0,
		"projectile": "rock", "color": Color(0.25, 0.2, 0.18),
		"desc": "Lanza brea ardiente: daño en área, quema y frena mucho. Solo tierra.",
		"perk_desc": "Maestría: Brea infernal (más área y quemadura).",
		"perks": {"splash": 1.1, "dot": 16.0},
	},
	"mortar": {
		"name": "Bombarda Real", "rarity": "rare", "unlock": {"map": 6, "wave": 40}, "cost": 220,
		"damage": 60.0, "rate": 0.3, "range": 4.2, "dmg_type": "physical",
		"air": false, "ground": true, "splash": 1.1, "stun_chance": 0.2, "stun_dur": 0.5,
		"projectile": "rock", "color": Color(0.45, 0.4, 0.35),
		"desc": "Cañón enorme de muy largo alcance: daño en área devastador. Lento. Solo tierra.",
		"perk_desc": "Maestría: Bala de fuego real (área gigante, aturde más).",
		"perks": {"splash": 1.5, "stun_chance": 0.4},
	},
	# --- Torres de oro de fin de juego (mapas 8-15): usan modelos existentes con su propia paleta ---
	"elite_archers": {
		"name": "Arqueros de la Guardia Real", "rarity": "rare", "unlock": {"map": 7, "wave": 40}, "cost": 260,
		"model": "archer", "hue": 0.62, "sat": 1.1,
		"damage": 38.0, "rate": 1.3, "range": 3.0, "dmg_type": "physical",
		"air": true, "ground": true, "multishot": 2, "projectile": "arrow",
		"color": Color(0.95, 0.8, 0.3),
		"desc": "Arqueros de élite: dos flechas por disparo, rápidos y de largo alcance.",
		"perk_desc": "Maestría: Tormenta de flechas (4 flechas por disparo, 15% crítico).",
		"perks": {"multishot": 4, "crit_bonus": 0.15},
	},
	"greek_fire": {
		"name": "Mortero de Fuego Griego", "rarity": "rare", "unlock": {"map": 8, "wave": 40}, "cost": 320,
		"model": "mortar", "hue": 0.05, "sat": 1.3,
		"damage": 110.0, "rate": 0.3, "range": 4.0, "dmg_type": "fire",
		"air": false, "ground": true, "splash": 1.2, "dot": 40.0, "dot_dur": 3.0,
		"projectile": "rock", "color": Color(1.0, 0.45, 0.1),
		"desc": "Bombas de fuego que arden en el suelo: gran área y quemadura. Solo tierra.",
		"perk_desc": "Maestría: Mar de llamas (más área y quemadura doble).",
		"perks": {"splash": 1.6, "dot": 80.0},
	},
	"siege_crossbow": {
		"name": "Gran Ballesta de Asedio", "rarity": "epic", "unlock": {"map": 9, "wave": 40}, "cost": 380,
		"model": "crossbow", "hue": 0.55, "sat": 0.9,
		"damage": 230.0, "rate": 0.35, "range": 3.6, "dmg_type": "physical",
		"air": true, "ground": true, "armor_break": 0.7, "crit_bonus": 0.15, "detect": true, "projectile": "bolt",
		"color": Color(0.5, 0.55, 0.65),
		"desc": "Virotes gigantes que atraviesan armaduras. Ve a los invisibles.",
		"perk_desc": "Maestría: Rompemurallas (rompe toda la armadura, 35% crítico).",
		"perks": {"armor_break": 1.0, "crit_bonus": 0.35},
	},
	"frost_sanctum": {
		"name": "Santuario de Escarcha", "rarity": "epic", "unlock": {"map": 10, "wave": 40}, "cost": 400,
		"model": "frost", "hue": 0.12, "sat": 1.2,
		"damage": 45.0, "rate": 0.4, "range": 2.8, "dmg_type": "ice",
		"air": true, "ground": true, "splash": 0.9, "stun_chance": 1.0, "stun_dur": 1.2, "prefer": "unfrozen",
		"projectile": "ice", "color": Color(0.6, 0.9, 1.0),
		"desc": "Fragmentos de hielo que congelan a todos los enemigos de la zona 1.2 s.",
		"perk_desc": "Maestría: Invierno eterno (congela 2 s en más área).",
		"perks": {"splash": 1.3, "stun_dur": 2.0},
	},
	"arcane_spire": {
		"name": "Aguja Arcana", "rarity": "epic", "unlock": {"map": 11, "wave": 40}, "cost": 460,
		"model": "storm", "hue": 0.72, "sat": 1.2,
		"damage": 140.0, "rate": 0.7, "range": 2.8, "dmg_type": "lightning",
		"air": true, "ground": true, "chain": 4, "projectile": "",
		"color": Color(0.7, 0.45, 1.0),
		"desc": "Rayos arcanos que saltan en cadena a 4 enemigos.",
		"perk_desc": "Maestría: Tormenta arcana (salta 8 veces, 15% aturdir).",
		"perks": {"chain": 8, "stun_chance": 0.15, "stun_dur": 0.8},
	},
	"cathedral": {
		"name": "Catedral de la Luz", "rarity": "legendary", "unlock": {"map": 12, "wave": 40}, "cost": 520,
		"model": "bell", "hue": 0.55, "sat": 0.8, "val": 1.15,
		"damage": 70.0, "rate": 0.8, "range": 2.6, "dmg_type": "holy",
		"air": true, "ground": true, "speed_aura": 0.25, "aura_range": 1.9, "projectile": "holy",
		"color": Color(1.0, 0.95, 0.75),
		"desc": "Sus campanas aceleran un 25% a las torres cercanas. Buen daño sagrado.",
		"perk_desc": "Maestría: Coro celestial (+45% de velocidad, aura más grande).",
		"perks": {"speed_aura": 0.45, "aura_range": 2.4},
	},
	"dragon_cannon": {
		"name": "Cañón del Dragón", "rarity": "legendary", "unlock": {"map": 14, "wave": 40}, "cost": 650,
		"model": "cannon", "hue": 0.95, "sat": 1.3, "val": 0.85,
		"damage": 420.0, "rate": 0.32, "range": 3.4, "dmg_type": "physical",
		"air": false, "ground": true, "splash": 1.3, "stun_chance": 0.25, "stun_dur": 0.6,
		"projectile": "rock", "color": Color(0.6, 0.15, 0.12),
		"desc": "La pieza de asedio definitiva: impactos enormes en área. Solo tierra.",
		"perk_desc": "Maestría: Aliento de dragón (área gigante y quemadura).",
		"perks": {"splash": 1.8, "dot": 120.0, "dot_dur": 3.0},
	},
	"herald": {
		"name": "Torre del Heraldo", "rarity": "rare", "cost": 150,
		"damage": 5.0, "rate": 0.6, "range": 2.0, "dmg_type": "holy",
		"air": true, "ground": true, "aura": 0.25, "range_aura": 0.15, "aura_range": 1.5, "projectile": "holy",
		"color": Color(0.35, 0.55, 1.0),
		"desc": "Su cuerno inspira a las torres de alrededor: +25% de daño y +15% de alcance.",
		"perk_desc": "Maestría: Clarín real (+45% de daño y +25% de alcance a un radio mayor).",
		"perks": {"aura": 0.45, "range_aura": 0.25, "aura_range": 2.2},
	},
	"alchemist": {
		"name": "Laboratorio Alquímico", "rarity": "uncommon", "cost": 120,
		"damage": 5.0, "rate": 0.6, "range": 2.3, "dmg_type": "poison",
		"air": false, "ground": true, "splash": 0.8, "dot": 10.0, "dot_dur": 3.0,
		"projectile": "flask", "color": Color(0.35, 0.6, 0.3),
		"desc": "Frascos de ácido en área que ignoran la armadura.",
		"perk_desc": "Maestría: Ácido corrosivo (veneno x2, reduce armadura).",
		"perks": {"dot": 20.0, "armor_break": 0.5},
	},
	# --- Torres místicas ---
	"inferno": {
		"name": "Pira del Dragón", "rarity": "epic", "cost": 170,
		"damage": 7.0, "rate": 2.6, "range": 2.0, "dmg_type": "fire",
		"air": true, "ground": true, "dot": 9.0, "dot_dur": 2.0,
		"projectile": "fire", "color": Color(0.75, 0.25, 0.1),
		"desc": "Llamas continuas que queman a los enemigos.",
		"perk_desc": "Maestría: Mar de llamas (fuego en área).",
		"perks": {"splash": 0.7},
	},
	"druid": {
		"name": "Círculo del Druida", "rarity": "epic", "cost": 160,
		"damage": 12.0, "rate": 0.5, "range": 2.5, "dmg_type": "poison",
		"air": false, "ground": true, "splash": 0.9, "stun_chance": 0.35, "stun_dur": 1.2,
		"projectile": "", "color": Color(0.35, 0.7, 0.3),
		"desc": "Raíces que brotan del suelo y atrapan a los enemigos en área.",
		"perk_desc": "Maestría: Bosque ancestral (60% de atrapar y espinas venenosas).",
		"perks": {"stun_chance": 0.6, "dot": 15.0, "dot_dur": 3.0},
	},
	"obelisk": {
		"name": "Obelisco del Vacío", "rarity": "legendary", "cost": 260,
		"damage": 170.0, "rate": 0.3, "range": 4.0, "dmg_type": "magic",
		"air": true, "ground": true, "detect": true, "projectile": "void",
		"color": Color(0.2, 0.1, 0.3),
		"desc": "Golpe arcano devastador a enorme distancia. Ve a los invisibles.",
		"perk_desc": "Maestría: Aniquilación (ejecuta enemigos no jefe bajo 15% de vida).",
		"perks": {"execute": 0.15},
	},
	"sanctuary": {
		"name": "Santuario Sagrado", "rarity": "legendary", "cost": 240,
		"damage": 26.0, "rate": 1.0, "range": 2.4, "dmg_type": "holy",
		"air": true, "ground": true, "aura": 0.2, "aura_range": 1.6, "detect": true, "reveal_range": 2.6, "projectile": "holy",
		"color": Color(0.95, 0.9, 0.65),
		"desc": "Daño sagrado (x2 a no-muertos). Potencia +20% a torres cercanas y revela invisibles para todas.",
		"perk_desc": "Maestría: Bendición (aura +45% y mayor radio).",
		"perks": {"aura": 0.45, "aura_range": 2.3},
	},
	# --- Torres de cartas nuevas (variantes con su propia paleta sobre un modelo existente) ---
	# Proporción por rareza: 12 comunes (de oro), 6 poco comunes, 5 raras, 4 épicas, 3 legendarias.
	"elf_archers": {
		"name": "Arqueros Élficos", "rarity": "uncommon", "cost": 110, "model": "archer", "hue": 0.62, "sat": 1.1,
		"damage": 8.0, "rate": 1.6, "range": 2.9, "dmg_type": "physical",
		"air": true, "ground": true, "multishot": 2, "detect": true, "projectile": "arrow",
		"color": Color(0.35, 0.8, 0.4),
		"desc": "Dos flechas por disparo, muy rápidas. Ven a los enemigos invisibles.",
		"perk_desc": "Maestría: Tormenta élfica (4 flechas por disparo).",
		"perks": {"multishot": 4},
	},
	"flame_archers": {
		"name": "Arqueros Ígneos", "rarity": "uncommon", "cost": 115, "model": "archer", "hue": 0.45, "sat": 1.2,
		"damage": 10.0, "rate": 1.2, "range": 2.6, "dmg_type": "fire",
		"air": true, "ground": true, "dot": 7.0, "dot_dur": 3.0, "projectile": "arrow",
		"color": Color(1.0, 0.5, 0.15),
		"desc": "Flechas encendidas que queman a los enemigos durante 3 s.",
		"perk_desc": "Maestría: Flechas de napalm (quemadura x2 y en área).",
		"perks": {"dot": 14.0, "splash": 0.6},
	},
	"frost_ward": {
		"name": "Guardián de Escarcha", "rarity": "uncommon", "cost": 105, "model": "frost", "hue": 0.88, "sat": 1.1,
		"damage": 12.0, "rate": 0.5, "range": 2.4, "dmg_type": "ice",
		"air": true, "ground": true, "splash": 0.7, "slow": 0.5, "slow_dur": 3.0, "projectile": "ice",
		"color": Color(0.4, 0.95, 0.85),
		"desc": "Carga un estallido de escarcha: daño en área y los enemigos van a mitad de velocidad.",
		"perk_desc": "Maestría: Hielo perpetuo (frena un 70% y congela un 20% de las veces).",
		"perks": {"slow": 0.3, "stun_chance": 0.2, "stun_dur": 1.0},
	},
	"war_drums": {
		"name": "Tambores de Guerra", "rarity": "uncommon", "cost": 120, "model": "bell", "hue": 0.9, "sat": 1.3, "val": 0.9,
		"damage": 6.0, "rate": 0.8, "range": 2.0, "dmg_type": "physical",
		"air": true, "ground": true, "aura": 0.15, "aura_range": 1.6, "projectile": "slash",
		"color": Color(0.85, 0.25, 0.2),
		"desc": "Su ritmo de guerra da +15% de daño a las torres cercanas.",
		"perk_desc": "Maestría: Redoble (+30% de daño y mayor radio).",
		"perks": {"aura": 0.3, "aura_range": 2.1},
	},
	"spike_ballista": {
		"name": "Balista de Púas", "rarity": "uncommon", "cost": 125, "model": "ballista", "hue": 0.55, "sat": 0.8, "val": 0.8,
		"damage": 30.0, "rate": 0.6, "range": 3.0, "dmg_type": "physical",
		"air": true, "ground": true, "armor_break": 0.3, "projectile": "bolt",
		"color": Color(0.45, 0.4, 0.5),
		"desc": "Virotes con púas que atacan tierra y aire y rompen armadura.",
		"perk_desc": "Maestría: Púas de acero (rompe toda la armadura y 20% crítico).",
		"perks": {"armor_break": 1.0, "crit_bonus": 0.2},
	},
	"tax_collector": {
		"name": "Torre del Recaudador", "rarity": "rare", "cost": 160, "model": "watch", "hue": 0.12, "sat": 1.3, "val": 1.05,
		"damage": 8.0, "rate": 0.9, "range": 2.6, "dmg_type": "physical",
		"air": true, "ground": true, "gold_per_wave": 35, "projectile": "arrow",
		"color": Color(1.0, 0.82, 0.3),
		"desc": "Cobra impuestos: te da oro extra al terminar cada oleada.",
		"perk_desc": "Maestría: Arcas reales (+40 de oro por oleada).",
		"perks": {"gold_bonus": 40},
	},
	"arcane_mage": {
		"name": "Mago Arcano", "rarity": "rare", "cost": 165, "model": "mage", "hue": 0.72, "sat": 1.1,
		"damage": 60.0, "rate": 0.45, "range": 2.6, "dmg_type": "magic",
		"air": true, "ground": true, "splash": 0.6, "detect": true, "projectile": "orb",
		"color": Color(0.65, 0.4, 1.0),
		"desc": "Carga un orbe arcano que estalla en área. Ve a los invisibles.",
		"perk_desc": "Maestría: Orbe inestable (más área y 25% de aturdir).",
		"perks": {"splash": 1.0, "stun_chance": 0.25, "stun_dur": 0.8},
	},
	"plague_mortar": {
		"name": "Mortero de la Peste", "rarity": "rare", "cost": 180, "model": "mortar", "hue": 0.3, "sat": 1.2,
		"damage": 30.0, "rate": 0.35, "range": 3.6, "dmg_type": "poison",
		"air": false, "ground": true, "splash": 1.0, "dot": 14.0, "dot_dur": 4.0, "slow": 0.7, "slow_dur": 2.0, "projectile": "flask",
		"color": Color(0.45, 0.85, 0.3),
		"desc": "Bombas de peste a gran distancia: veneno en área que frena. Solo tierra.",
		"perk_desc": "Maestría: Gran epidemia (veneno x2 y reduce armadura).",
		"perks": {"dot": 28.0, "armor_break": 0.4},
	},
	"thunder_crossbow": {
		"name": "Ballesta del Rayo", "rarity": "epic", "cost": 190, "model": "crossbow", "hue": 0.6, "sat": 1.3,
		"damage": 34.0, "rate": 0.6, "range": 3.0, "dmg_type": "lightning",
		"air": true, "ground": true, "chain": 3, "armor_break": 0.3, "projectile": "bolt",
		"color": Color(0.45, 0.65, 1.0),
		"desc": "Virotes cargados de rayo que saltan a 3 enemigos y rompen armadura.",
		"perk_desc": "Maestría: Tormenta de acero (salta 6 veces y aturde un 15%).",
		"perks": {"chain": 6, "stun_chance": 0.15, "stun_dur": 0.7},
	},
	"sun_obelisk": {
		"name": "Obelisco Solar", "rarity": "legendary", "cost": 270, "model": "obelisk", "hue": 0.25, "sat": 1.4, "val": 1.5,
		"damage": 120.0, "rate": 0.35, "range": 3.6, "dmg_type": "holy",
		"air": true, "ground": true, "splash": 0.8, "dot": 25.0, "dot_dur": 3.0, "detect": true, "projectile": "holy",
		"color": Color(1.0, 0.85, 0.35),
		"desc": "Rayo de sol que estalla en área y abrasa a los enemigos. Ve a los invisibles.",
		"perk_desc": "Maestría: Supernova (ejecuta enemigos no jefe bajo el 12% de vida).",
		"perks": {"execute": 0.12, "splash": 1.1},
	},
}

# ---------------------------------------------------------------- Héroes
const HEROES := {
	"aldric": {
		"name": "Sir Aldric", "title": "Caballero de la Corona", "rarity": "common",
		"damage": 30.0, "rate": 1.0, "range": 2.0, "dmg_type": "physical",
		"projectile": "slash", "color": Color(0.75, 0.75, 0.8),
		"ability": "warcry", "ability_name": "Grito de Guerra", "cooldown": 30.0,
		"ability_desc": "Aturde a todos los enemigos cercanos durante 3 s.",
	},
	"gareth": {
		"name": "Gareth", "title": "Arquero del Burgo", "rarity": "common",
		"damage": 14.0, "rate": 1.8, "range": 3.0, "dmg_type": "physical",
		"projectile": "arrow", "color": Color(0.45, 0.6, 0.3),
		"ability": "volley", "ability_name": "Lluvia de Flechas", "cooldown": 30.0,
		"ability_desc": "Golpea a todos los enemigos cercanos con 6x su daño.",
	},
	"mira": {
		"name": "Mira", "title": "Curandera de la Aldea", "rarity": "common",
		"damage": 16.0, "rate": 1.0, "range": 2.6, "dmg_type": "holy",
		"projectile": "holy", "color": Color(0.85, 0.85, 0.7),
		"ability": "heal", "ability_name": "Remedio de Hierbas", "cooldown": 45.0,
		"ability_desc": "La fortaleza recupera 6 de vida.",
	},
	"bram": {
		"name": "Bram", "title": "Herrero de la Montaña", "rarity": "common",
		"damage": 34.0, "rate": 0.8, "range": 1.8, "dmg_type": "physical",
		"projectile": "slash", "color": Color(0.55, 0.4, 0.3),
		"ability": "forge", "ability_name": "Filo Templado", "cooldown": 40.0,
		"ability_desc": "Todas las torres hacen +25% de daño durante 12 s.",
	},
	"osric": {
		"name": "Osric", "title": "Cazador de Bestias", "rarity": "common",
		"damage": 22.0, "rate": 1.2, "range": 2.4, "dmg_type": "physical",
		"projectile": "arrow", "color": Color(0.5, 0.35, 0.2),
		"ability": "net", "ability_name": "Red de Caza", "cooldown": 35.0,
		"ability_desc": "Los enemigos cercanos van un 70% más lentos durante 5 s.",
	},
	"brunhild": {
		"name": "Brunhild", "title": "Escudera del Norte", "rarity": "uncommon",
		"damage": 24.0, "rate": 1.1, "range": 2.0, "dmg_type": "physical",
		"projectile": "slash", "color": Color(0.55, 0.6, 0.7),
		"ability": "shieldwall", "ability_name": "Muro de Escudos", "cooldown": 40.0,
		"ability_desc": "Los enemigos cercanos van a mitad de velocidad 6 s y recibes +2 vidas.",
	},
	"elara": {
		"name": "Elara", "title": "Druida del Bosque", "rarity": "uncommon",
		"damage": 18.0, "rate": 1.1, "range": 2.8, "dmg_type": "poison", "dot": 10.0, "dot_dur": 3.0,
		"projectile": "arrow_poison", "color": Color(0.3, 0.6, 0.35),
		"ability": "thorns", "ability_name": "Zarzas Venenosas", "cooldown": 40.0,
		"ability_desc": "Envenena a todos los enemigos del mapa durante 6 s.",
	},
	"korvin": {
		"name": "Korvin", "title": "Mercenario Errante", "rarity": "uncommon",
		"damage": 36.0, "rate": 0.9, "range": 1.9, "dmg_type": "physical",
		"projectile": "slash", "color": Color(0.45, 0.3, 0.35),
		"ability": "bounty", "ability_name": "Recompensa", "cooldown": 60.0,
		"ability_desc": "Durante 15 s los enemigos dan el doble de oro.",
	},
	"isolde": {
		"name": "Isolde", "title": "Juglaresa de la Corte", "rarity": "uncommon",
		"damage": 15.0, "rate": 1.4, "range": 2.6, "dmg_type": "magic",
		"projectile": "holy", "color": Color(0.85, 0.45, 0.6),
		"ability": "anthem", "ability_name": "Himno de Batalla", "cooldown": 40.0,
		"ability_desc": "Todas las torres atacan un 50% más rápido durante 10 s.",
	},
	"sylva": {
		"name": "Sylva", "title": "Exploradora Élfica", "rarity": "rare",
		"damage": 16.0, "rate": 2.2, "range": 3.2, "dmg_type": "physical", "detect": true,
		"projectile": "arrow", "color": Color(0.35, 0.75, 0.4),
		"ability": "haste", "ability_name": "Viento Élfico", "cooldown": 45.0,
		"ability_desc": "Todas las torres atacan el doble de rápido durante 8 s.",
	},
	"morgana": {
		"name": "Morgana", "title": "Bruja del Pantano", "rarity": "rare",
		"damage": 26.0, "rate": 0.9, "range": 2.8, "dmg_type": "magic",
		"projectile": "void", "color": Color(0.35, 0.25, 0.45),
		"ability": "curse", "ability_name": "Maldición", "cooldown": 55.0,
		"ability_desc": "Todos los enemigos pierden el 20% de su vida (los jefes, el 6%).",
	},
	"ulric": {
		"name": "Ulric", "title": "Señor de la Tormenta", "rarity": "rare",
		"damage": 30.0, "rate": 1.0, "range": 2.8, "dmg_type": "lightning",
		"projectile": "", "chain": 2, "color": Color(0.4, 0.55, 0.85),
		"ability": "storm", "ability_name": "Tormenta", "cooldown": 45.0,
		"ability_desc": "12 rayos caen sobre enemigos: 10x su daño y los aturden 1 s.",
	},
	"lyra": {
		"name": "Lyra", "title": "Archimaga del Fuego", "rarity": "epic",
		"damage": 34.0, "rate": 0.8, "range": 2.8, "dmg_type": "fire", "splash": 0.7,
		"projectile": "fire", "color": Color(0.9, 0.35, 0.25),
		"ability": "meteor", "ability_name": "Lluvia de Meteoros", "cooldown": 55.0,
		"ability_desc": "Inflige 15x su daño a todos los enemigos del mapa.",
	},
	"theron": {
		"name": "Theron", "title": "Paladín de la Luz", "rarity": "epic",
		"damage": 28.0, "rate": 1.0, "range": 2.4, "dmg_type": "holy",
		"projectile": "holy", "color": Color(1.0, 0.9, 0.5),
		"ability": "blessing", "ability_name": "Luz Divina", "cooldown": 70.0,
		"ability_desc": "Recupera 3 vidas y las torres hacen +40% de daño 10 s.",
	},
	"vex": {
		"name": "Vex", "title": "Señor de los Dragones", "rarity": "legendary",
		"damage": 55.0, "rate": 1.0, "range": 3.0, "dmg_type": "fire", "dot": 25.0, "dot_dur": 3.0,
		"projectile": "fire", "color": Color(0.6, 0.1, 0.15),
		"ability": "dragonbreath", "ability_name": "Aliento Ancestral", "cooldown": 50.0,
		"ability_desc": "Quema y ralentiza a todos los enemigos durante 5 s.",
	},
	# --- Héroes nuevos (proporción por rareza: 8 comunes, 6 poco comunes, 5 raros, 4 épicos, 3 legendarios) ---
	"tomas": {
		"name": "Hermano Tomás", "title": "Monje Errante", "rarity": "common",
		"damage": 15.0, "rate": 1.0, "range": 2.4, "dmg_type": "holy",
		"projectile": "holy", "color": Color(0.7, 0.55, 0.35),
		"ability": "sanctify", "ability_name": "Plegaria", "cooldown": 45.0,
		"ability_desc": "Recuperas 3 vidas y aturde 1.5 s a los enemigos cercanos.",
	},
	"wynn": {
		"name": "Wynn", "title": "Leñadora del Valle", "rarity": "common",
		"damage": 30.0, "rate": 0.85, "range": 1.9, "dmg_type": "physical",
		"projectile": "slash", "color": Color(0.6, 0.3, 0.2),
		"ability": "timber", "ability_name": "¡Árbol va!", "cooldown": 35.0,
		"ability_desc": "Golpea a los enemigos cercanos con 8x su daño y los aturde 1 s.",
	},
	"pip": {
		"name": "Pip", "title": "Pícaro Callejero", "rarity": "common",
		"damage": 18.0, "rate": 1.5, "range": 2.2, "dmg_type": "physical",
		"projectile": "slash", "color": Color(0.4, 0.4, 0.45),
		"ability": "goldrain", "ability_name": "Bolsa Ajena", "cooldown": 50.0,
		"ability_desc": "Consigues oro al instante (más cuanto más avanzada la oleada).",
	},
	"gwen": {
		"name": "Gwendolyn", "title": "Cazadora de Brujas", "rarity": "uncommon",
		"damage": 22.0, "rate": 1.3, "range": 3.0, "dmg_type": "physical", "detect": true,
		"projectile": "arrow", "color": Color(0.55, 0.2, 0.25),
		"ability": "smite", "ability_name": "Flecha Marcada", "cooldown": 40.0,
		"ability_desc": "El enemigo con más vida recibe 30x su daño.",
	},
	"hector": {
		"name": "Héctor", "title": "Capitán de la Guardia", "rarity": "uncommon",
		"damage": 28.0, "rate": 1.0, "range": 2.0, "dmg_type": "physical",
		"projectile": "slash", "color": Color(0.25, 0.35, 0.65),
		"ability": "rally", "ability_name": "¡A las Murallas!", "cooldown": 45.0,
		"ability_desc": "Durante 8 s las torres hacen +25% de daño y atacan un 50% más rápido.",
	},
	"nyx": {
		"name": "Nyx", "title": "Sombra de la Noche", "rarity": "rare",
		"damage": 24.0, "rate": 1.4, "range": 2.6, "dmg_type": "magic", "detect": true,
		"projectile": "void", "color": Color(0.25, 0.2, 0.4),
		"ability": "timewarp", "ability_name": "Manto de Noche", "cooldown": 45.0,
		"ability_desc": "Todos los enemigos del mapa van un 60% más lentos durante 6 s.",
	},
	"freya": {
		"name": "Freya", "title": "Valquiria del Fiordo", "rarity": "rare",
		"damage": 32.0, "rate": 1.0, "range": 2.4, "dmg_type": "physical",
		"projectile": "slash", "color": Color(0.75, 0.8, 0.9),
		"ability": "skyspear", "ability_name": "Lanza del Cielo", "cooldown": 45.0,
		"ability_desc": "Los enemigos a 4 casillas reciben 12x su daño y quedan aturdidos 1.5 s.",
	},
	"aurelia": {
		"name": "Aurelia", "title": "Reina del Invierno", "rarity": "epic",
		"damage": 30.0, "rate": 0.9, "range": 2.8, "dmg_type": "magic", "splash": 0.6,
		"projectile": "ice", "color": Color(0.6, 0.85, 1.0),
		"ability": "frostnova", "ability_name": "Invierno Eterno", "cooldown": 55.0,
		"ability_desc": "Congela a todos los enemigos del mapa 3 s (los jefes, 1 s) y los frena después.",
	},
	"goran": {
		"name": "Goran", "title": "Rey de la Montaña", "rarity": "epic",
		"damage": 48.0, "rate": 0.75, "range": 1.9, "dmg_type": "physical", "splash": 0.5,
		"projectile": "slash", "color": Color(0.6, 0.45, 0.3),
		"ability": "earthquake", "ability_name": "Terremoto", "cooldown": 55.0,
		"ability_desc": "Todos los enemigos de tierra reciben 12x su daño y quedan aturdidos 1.5 s.",
	},
	"seraphina": {
		"name": "Seraphina", "title": "Arcángel del Alba", "rarity": "legendary",
		"damage": 45.0, "rate": 1.1, "range": 3.0, "dmg_type": "holy", "detect": true,
		"projectile": "holy", "color": Color(1.0, 0.95, 0.75),
		"ability": "dawn", "ability_name": "Amanecer", "cooldown": 70.0,
		"ability_desc": "Recuperas 6 vidas, todos los enemigos reciben 8x su daño y las torres hacen +40% de daño 10 s.",
	},
	"malakar": {
		"name": "Malakar", "title": "Nigromante Eterno", "rarity": "legendary",
		"damage": 50.0, "rate": 0.9, "range": 3.0, "dmg_type": "magic", "dot": 20.0, "dot_dur": 3.0,
		"projectile": "void", "color": Color(0.35, 0.15, 0.4),
		"ability": "harvest", "ability_name": "Cosecha de Almas", "cooldown": 65.0,
		"ability_desc": "Los enemigos (no jefes) con menos del 35% de vida mueren al instante; los jefes pierden el 10%.",
	},
}

# ---------------------------------------------------------------- Enemigos
# hp/speed son multiplicadores. armor reduce físico, resist reduce mágico/rayo.
const BASE_ENEMIES := {
	"goblin": {"name": "Goblin", "hp": 1.0, "speed": 1.0, "color": Color(0.4, 0.7, 0.25), "shape": "blob", "size": 0.24},
	"wolf": {"name": "Huargo", "hp": 0.55, "speed": 1.9, "color": Color(0.5, 0.5, 0.55), "shape": "beast", "size": 0.24, "desc": "Muy rápido, poca vida."},
	"orc": {"name": "Orco Guerrero", "hp": 2.2, "speed": 0.8, "armor": 0.35, "color": Color(0.3, 0.5, 0.2), "shape": "brute", "size": 0.3},
	"skeleton": {"name": "Esqueleto", "hp": 0.9, "speed": 1.0, "armor": 0.1, "color": Color(0.9, 0.9, 0.85), "shape": "blob", "size": 0.23, "traits": ["undead"]},
	"bat": {"name": "Murciélago Vampiro", "hp": 0.5, "speed": 1.7, "flying": true, "color": Color(0.35, 0.2, 0.35), "shape": "wings", "size": 0.2},
	"troll": {"name": "Troll", "hp": 3.0, "speed": 0.7, "color": Color(0.4, 0.55, 0.5), "shape": "brute", "size": 0.34, "traits": ["regen"], "desc": "Regenera vida."},
	"dark_mage": {"name": "Hechicero Oscuro", "hp": 1.3, "speed": 0.9, "resist": 0.55, "color": Color(0.3, 0.15, 0.45), "shape": "robe", "size": 0.25, "desc": "Resiste la magia."},
	"golem": {"name": "Gólem de Piedra", "hp": 5.0, "speed": 0.5, "armor": 0.6, "color": Color(0.5, 0.45, 0.4), "shape": "golem", "size": 0.36, "traits": ["slow_immune"], "desc": "Muy blindado, inmune a ralentización."},
	"wyvern": {"name": "Guiverno", "hp": 1.8, "speed": 1.3, "armor": 0.2, "flying": true, "color": Color(0.3, 0.55, 0.45), "shape": "wings", "size": 0.3},
	"dragon": {"name": "Dragón", "hp": 7.0, "speed": 0.7, "armor": 0.3, "resist": 0.3, "flying": true, "immune": ["fire"], "color": Color(0.7, 0.15, 0.1), "shape": "dragon", "size": 0.4, "desc": "Volador, inmune al fuego. Solo torres antiaéreas."},
	"ghost": {"name": "Espectro", "hp": 1.0, "speed": 1.1, "color": Color(0.7, 0.85, 0.95, 0.75), "shape": "ghost", "size": 0.25, "traits": ["ethereal", "undead"], "desc": "Etéreo: el daño físico apenas le afecta."},
	"slime": {"name": "Limo Ácido", "hp": 1.6, "speed": 0.9, "immune": ["poison"], "color": Color(0.5, 0.85, 0.3), "shape": "slime", "size": 0.3, "traits": ["split"], "desc": "Se divide al morir."},
	"slimelet": {"name": "Limo Pequeño", "hp": 0.45, "speed": 1.3, "immune": ["poison"], "color": Color(0.6, 0.9, 0.4), "shape": "slime", "size": 0.17},
	"shaman": {"name": "Chamán Orco", "hp": 1.4, "speed": 0.85, "color": Color(0.55, 0.4, 0.2), "shape": "robe", "size": 0.26, "traits": ["healer"], "desc": "Cura a los enemigos cercanos."},
	"dark_knight": {"name": "Caballero Negro", "hp": 3.0, "speed": 0.8, "armor": 0.45, "resist": 0.45, "color": Color(0.15, 0.15, 0.2), "shape": "brute", "size": 0.3},
	"necromancer": {"name": "Nigromante", "hp": 2.0, "speed": 0.75, "resist": 0.3, "color": Color(0.25, 0.35, 0.25), "shape": "robe", "size": 0.27, "traits": ["undead", "summoner"], "desc": "Invoca esqueletos."},
	"ice_elemental": {"name": "Elemental de Hielo", "hp": 2.4, "speed": 0.8, "immune": ["ice"], "color": Color(0.6, 0.85, 1.0), "shape": "golem", "size": 0.3, "traits": ["slow_immune"]},
	"fire_imp": {"name": "Diablillo de Fuego", "hp": 0.7, "speed": 1.8, "immune": ["fire"], "color": Color(1.0, 0.4, 0.1), "shape": "blob", "size": 0.2},
	"harpy": {"name": "Arpía", "hp": 0.9, "speed": 1.5, "flying": true, "color": Color(0.7, 0.55, 0.4), "shape": "wings", "size": 0.24},
	# Jefes
	"boss_goblin_king": {"name": "Rey Goblin", "hp": 40.0, "speed": 0.6, "armor": 0.2, "color": Color(0.35, 0.65, 0.2), "shape": "brute", "size": 0.44, "boss": true},
	"boss_troll": {"name": "Troll Ancestral", "hp": 60.0, "speed": 0.5, "armor": 0.25, "color": Color(0.35, 0.5, 0.45), "shape": "brute", "size": 0.46, "boss": true, "traits": ["regen"]},
	"boss_lich": {"name": "Liche", "hp": 50.0, "speed": 0.55, "resist": 0.5, "color": Color(0.5, 0.9, 0.7), "shape": "robe", "size": 0.42, "boss": true, "traits": ["undead", "summoner"]},
	"boss_frost_giant": {"name": "Gigante de Hielo", "hp": 90.0, "speed": 0.45, "armor": 0.5, "immune": ["ice"], "color": Color(0.65, 0.85, 1.0), "shape": "golem", "size": 0.48, "boss": true, "traits": ["slow_immune"]},
	"boss_dragon": {"name": "Dragón Ancestral", "hp": 80.0, "speed": 0.5, "armor": 0.3, "resist": 0.3, "flying": true, "immune": ["fire"], "color": Color(0.55, 0.05, 0.05), "shape": "dragon", "size": 0.5, "boss": true},
	"boss_demon": {"name": "Señor Demonio", "hp": 100.0, "speed": 0.5, "armor": 0.4, "resist": 0.4, "immune": ["fire"], "color": Color(0.5, 0.05, 0.1), "shape": "brute", "size": 0.5, "boss": true, "traits": ["regen"]},
}

# ---------------------------------------------------------------- Mapas
# Plantillas de camino (coordenadas de casilla, diseñadas en 16x9 y traspuestas
# a 9x16 para la pantalla vertical). Los extremos están fuera de la cuadrícula.
const PATH_TEMPLATES := [
	[Vector2i(-1, 1), Vector2i(13, 1), Vector2i(13, 4), Vector2i(2, 4), Vector2i(2, 7), Vector2i(16, 7)],
	[Vector2i(-1, 4), Vector2i(3, 4), Vector2i(3, 1), Vector2i(7, 1), Vector2i(7, 7), Vector2i(11, 7), Vector2i(11, 2), Vector2i(14, 2), Vector2i(14, 5), Vector2i(16, 5)],
	[Vector2i(2, -1), Vector2i(2, 6), Vector2i(6, 6), Vector2i(6, 2), Vector2i(10, 2), Vector2i(10, 6), Vector2i(13, 6), Vector2i(13, 1), Vector2i(16, 1)],
	[Vector2i(-1, 7), Vector2i(4, 7), Vector2i(4, 1), Vector2i(9, 1), Vector2i(9, 7), Vector2i(13, 7), Vector2i(13, 3), Vector2i(16, 3)],
	[Vector2i(-1, 1), Vector2i(5, 1), Vector2i(5, 7), Vector2i(10, 7), Vector2i(10, 1), Vector2i(14, 1), Vector2i(14, 9)],
	[Vector2i(7, -1), Vector2i(7, 2), Vector2i(1, 2), Vector2i(1, 6), Vector2i(12, 6), Vector2i(12, 2), Vector2i(16, 2)],
	[Vector2i(-1, 2), Vector2i(6, 2), Vector2i(6, 6), Vector2i(2, 6), Vector2i(2, 8), Vector2i(12, 8), Vector2i(12, 4), Vector2i(9, 4), Vector2i(9, 0), Vector2i(16, 0)],
	[Vector2i(-1, 3), Vector2i(4, 3), Vector2i(4, 0), Vector2i(8, 0), Vector2i(8, 8), Vector2i(12, 8), Vector2i(12, 3), Vector2i(16, 3)],
]

const BASE_MAPS := [
	{"name": "Pradera de Valdoria", "ground": Color(0.36, 0.55, 0.26), "path": Color(0.66, 0.55, 0.36), "deco": "meadow", "roster": ["goblin", "wolf", "orc", "bat"], "boss": "boss_goblin_king"},
	{"name": "Bosque Susurrante", "ground": Color(0.2, 0.4, 0.22), "path": Color(0.5, 0.4, 0.28), "deco": "whispering_forest", "roster": ["goblin", "wolf", "bat", "shaman", "troll"], "boss": "boss_troll"},
	{"name": "Colinas de Piedra", "ground": Color(0.45, 0.5, 0.35), "path": Color(0.6, 0.58, 0.52), "deco": "stone_hills", "roster": ["orc", "goblin", "harpy", "shaman", "golem"], "boss": "boss_troll"},
	{"name": "Pantano Maldito", "ground": Color(0.28, 0.35, 0.25), "path": Color(0.4, 0.36, 0.25), "deco": "swamp", "roster": ["slime", "skeleton", "bat", "ghost", "troll"], "boss": "boss_lich"},
	{"name": "Cementerio de Ravenholm", "ground": Color(0.28, 0.3, 0.3), "path": Color(0.45, 0.42, 0.4), "deco": "graveyard", "roster": ["skeleton", "ghost", "bat", "necromancer", "dark_knight"], "boss": "boss_lich"},
	{"name": "Montañas Escarchadas", "ground": Color(0.75, 0.82, 0.88), "path": Color(0.55, 0.55, 0.6), "deco": "frost_mountains", "roster": ["wolf", "orc", "harpy", "ice_elemental", "golem"], "boss": "boss_frost_giant"},
	{"name": "Glaciar Eterno", "ground": Color(0.8, 0.9, 0.97), "path": Color(0.6, 0.75, 0.85), "deco": "glacier", "roster": ["ice_elemental", "wolf", "wyvern", "golem", "ghost"], "boss": "boss_frost_giant"},
	{"name": "Desierto de Ceniza", "ground": Color(0.78, 0.66, 0.42), "path": Color(0.62, 0.5, 0.32), "deco": "ash_desert", "roster": ["fire_imp", "orc", "slime", "wyvern", "shaman"], "boss": "boss_goblin_king"},
	{"name": "Volcán de Azufre", "ground": Color(0.3, 0.2, 0.18), "path": Color(0.45, 0.3, 0.22), "deco": "volcano", "roster": ["fire_imp", "golem", "dark_mage", "wyvern", "dragon"], "boss": "boss_dragon"},
	{"name": "Ruinas Élficas", "ground": Color(0.35, 0.5, 0.4), "path": Color(0.7, 0.68, 0.6), "deco": "elven_ruins", "roster": ["dark_mage", "ghost", "harpy", "wolf", "dark_knight"], "boss": "boss_lich"},
	{"name": "Fortaleza Caída", "ground": Color(0.4, 0.38, 0.35), "path": Color(0.55, 0.5, 0.45), "deco": "fallen_fortress", "roster": ["dark_knight", "orc", "shaman", "necromancer", "wyvern"], "boss": "boss_demon"},
	{"name": "Cañón del Dragón", "ground": Color(0.6, 0.38, 0.25), "path": Color(0.5, 0.32, 0.22), "deco": "dragon_canyon", "roster": ["wyvern", "bat", "fire_imp", "golem", "dragon"], "boss": "boss_dragon"},
	{"name": "Bosque de Cristal", "ground": Color(0.3, 0.3, 0.45), "path": Color(0.5, 0.48, 0.6), "deco": "crystal_forest", "roster": ["slime", "dark_mage", "ice_elemental", "harpy", "troll"], "boss": "boss_frost_giant"},
	{"name": "Abismo Sombrío", "ground": Color(0.15, 0.12, 0.2), "path": Color(0.3, 0.25, 0.35), "deco": "void_abyss", "roster": ["ghost", "necromancer", "dark_mage", "dark_knight", "dragon"], "boss": "boss_lich"},
	{"name": "Ciudadela del Liche", "ground": Color(0.22, 0.26, 0.24), "path": Color(0.4, 0.42, 0.38), "deco": "lich_citadel", "roster": ["skeleton", "necromancer", "ghost", "wyvern", "dark_knight"], "boss": "boss_lich"},
	{"name": "Tierras Infernales", "ground": Color(0.35, 0.12, 0.1), "path": Color(0.5, 0.25, 0.15), "deco": "hellfire", "roster": ["fire_imp", "shaman", "golem", "dark_knight", "dragon"], "boss": "boss_demon"},
	{"name": "Islas Flotantes", "ground": Color(0.45, 0.65, 0.4), "path": Color(0.75, 0.7, 0.55), "deco": "sky_islands", "roster": ["harpy", "bat", "wyvern", "dark_mage", "dragon"], "boss": "boss_dragon"},
	{"name": "Trono de Hielo", "ground": Color(0.6, 0.72, 0.85), "path": Color(0.4, 0.5, 0.65), "deco": "ice_throne", "roster": ["ice_elemental", "golem", "ghost", "dark_knight", "dragon"], "boss": "boss_frost_giant"},
	{"name": "Puertas del Abismo", "ground": Color(0.2, 0.08, 0.15), "path": Color(0.38, 0.18, 0.25), "deco": "abyss_gate", "roster": ["necromancer", "fire_imp", "slime", "dark_knight", "dragon", "troll"], "boss": "boss_demon"},
	{"name": "Ciudadela del Caos", "ground": Color(0.12, 0.1, 0.12), "path": Color(0.35, 0.3, 0.35), "deco": "chaos_citadel", "roster": ["dark_knight", "ghost", "golem", "wyvern", "dragon", "necromancer", "shaman"], "boss": "boss_demon"},
]

# ---------------------------------------------------------------- Mejoras globales (permanentes)
const UPGRADES := {
	"damage": {"name": "Forja Real", "desc": "x1.06 daño de todas las torres (acumulativo)", "per_level": 0.06, "max": 300, "base_cost": 100,
		"growth": 1.13, "mult": true, "cap_base": 10, "cap_per_map": 8},
	"range": {"name": "Atalayas", "desc": "+2% alcance de las torres", "per_level": 0.02, "max": 20, "base_cost": 150, "cap_base": 3, "cap_per_map": 1},
	"speed": {"name": "Entrenamiento", "desc": "+2% velocidad de ataque", "per_level": 0.02, "max": 40, "base_cost": 150, "cap_base": 4, "cap_per_map": 2},
	"start_gold": {"name": "Tesoro Real", "desc": "+30 de oro mínimo al empezar una partida", "per_level": 30.0, "max": 40, "base_cost": 80},
	"lives": {"name": "Murallas", "desc": "+5 de vida de la fortaleza", "per_level": 5.0, "max": 40, "base_cost": 120},
	"gold_kill": {"name": "Botín de Guerra", "desc": "+4% oro por enemigo", "per_level": 0.04, "max": 50, "base_cost": 120},
	"crit": {"name": "Ojo de Halcón", "desc": "+1% probabilidad de crítico (x2)", "per_level": 0.01, "max": 25, "base_cost": 200},
	"discount": {"name": "Gremio de Albañiles", "desc": "-1% coste de torres y mejoras", "per_level": 0.01, "max": 25, "base_cost": 180},
	"hero": {"name": "Leyendas", "desc": "x1.05 poder de héroes (acumulativo)", "per_level": 0.05, "max": 200, "base_cost": 200,
		"growth": 1.13, "mult": true, "cap_base": 5, "cap_per_map": 6},
	"coins": {"name": "Tesorería", "desc": "+5% oro ganado", "per_level": 0.05, "max": 60, "base_cost": 250, "cap_base": 5, "cap_per_map": 3},
}
const UPGRADE_COST_GROWTH := 1.22
## Con el oro único (el de la batalla llega directo al bolsillo) las mejoras de oro cuestan el triple.
const UPGRADE_COST_MULT := 3.0
## Copias para pasar del nivel N al N+1 (índice N-1). Nivel 1 = obtener la carta.
const CARD_COPIES := [5, 15, 40, 100]

# ---------------------------------------------------------------- Sobres de cartas (se compran con oro)
## Versión de PC: no hay gemas ni anuncios. Los sobres se compran con el oro de las partidas y son
## la ÚNICA forma de desbloquear torres (solo la Torre de Arqueros viene de serie) y héroes.
const PACKS := {
	"common": {"name": "Sobre de Bronce", "cards": 5, "gold": 600,
		"weights": {"common": 72.0, "uncommon": 22.0, "rare": 5.0, "epic": 0.9, "legendary": 0.1}, "guarantee": "", "color": Color(0.7, 0.45, 0.25)},
	"rare": {"name": "Sobre de Plata", "cards": 5, "gold": 1800,
		"weights": {"common": 56.0, "uncommon": 29.0, "rare": 11.5, "epic": 3.0, "legendary": 0.5}, "guarantee": "uncommon", "color": Color(0.7, 0.75, 0.85)},
	"epic": {"name": "Sobre de Oro", "cards": 5, "gold": 5000,
		"weights": {"common": 45.0, "uncommon": 31.0, "rare": 17.0, "epic": 6.0, "legendary": 1.0}, "guarantee": "rare", "color": Color(0.95, 0.75, 0.2)},
	"legendary": {"name": "Cofre del Rey", "cards": 5, "gold": 12000,
		"weights": {"common": 30.0, "uncommon": 30.0, "rare": 25.0, "epic": 12.0, "legendary": 3.0}, "guarantee": "epic", "color": Color(0.8, 0.3, 0.95)},
	# Sobres de la tienda: de TORRES o de HÉROES, en bronce, plata y oro (más caros = mejores)
	"tower_bronze": {"name": "Torres de Bronce", "kind": "tower", "tier": "bronze", "cover": "archer", "cards": 5, "gold": 400,
		"weights": {"common": 72.0, "uncommon": 22.0, "rare": 5.0, "epic": 0.9, "legendary": 0.1}, "guarantee": "", "color": Color(0.8, 0.5, 0.28)},
	"tower_silver": {"name": "Torres de Plata", "kind": "tower", "tier": "silver", "cover": "mage", "cards": 5, "gold": 1500,
		"weights": {"common": 55.0, "uncommon": 30.0, "rare": 11.5, "epic": 3.0, "legendary": 0.5}, "guarantee": "rare", "color": Color(0.72, 0.77, 0.86)},
	"tower_gold": {"name": "Torres de Oro", "kind": "tower", "tier": "gold", "cover": "inferno", "cards": 5, "gold": 4500,
		"weights": {"common": 40.0, "uncommon": 32.0, "rare": 19.0, "epic": 7.5, "legendary": 1.5}, "guarantee": "epic", "color": Color(0.97, 0.78, 0.22)},
	"hero_bronze": {"name": "Héroes de Bronce", "kind": "hero", "tier": "bronze", "cover": "aldric", "cards": 5, "gold": 800,
		"weights": {"common": 72.0, "uncommon": 22.0, "rare": 5.0, "epic": 0.9, "legendary": 0.1}, "guarantee": "", "color": Color(0.8, 0.5, 0.28)},
	"hero_silver": {"name": "Héroes de Plata", "kind": "hero", "tier": "silver", "cover": "sylva", "cards": 5, "gold": 2600,
		"weights": {"common": 55.0, "uncommon": 30.0, "rare": 11.5, "epic": 3.0, "legendary": 0.5}, "guarantee": "rare", "color": Color(0.72, 0.77, 0.86)},
	"hero_gold": {"name": "Héroes de Oro", "kind": "hero", "tier": "gold", "cover": "vex", "cards": 5, "gold": 7500,
		"weights": {"common": 40.0, "uncommon": 32.0, "rare": 19.0, "epic": 7.5, "legendary": 1.5}, "guarantee": "epic", "color": Color(0.97, 0.78, 0.22)},
}
const SHOP_PACKS := {"tower": ["tower_bronze", "tower_silver", "tower_gold"], "hero": ["hero_bronze", "hero_silver", "hero_gold"]}
## Torre con la que se empieza: el resto se consigue en sobres.
const STARTER_TOWER := "archer"
## Lo que antes costaba (o daba) gemas ahora cuesta (o da) oro a este cambio.
const GEM_GOLD := 50

# ---------------------------------------------------------------- Nivel de cuenta
## XP para pasar del nivel `lvl` al siguiente.
const XP_SOURCES := {"waves": 10, "bosses": 60, "packs": 20, "build": 2, "upgrade": 2}


func xp_to_next(lvl: int) -> int:
	return int(120.0 * pow(float(lvl), 1.35))


## Recompensa al alcanzar el nivel `lvl`.
func level_reward(lvl: int) -> Dictionary:
	var r := {"coins": 150 * lvl}
	if lvl % 5 == 0:
		r["coins"] = int(r["coins"]) + (40 + lvl * 2) * GEM_GOLD
	if lvl % 10 == 0:
		r["pack"] = "rare" if lvl % 30 != 0 else "epic"
	elif lvl % 3 == 0:
		r["pack"] = "tower_bronze"
	return r


# ---------------------------------------------------------------- Logros (por niveles)
const ACHIEVEMENTS := [
	{"id": "kills", "name": "Azote de monstruos", "desc": "Derrota %s enemigos", "tiers": [100, 1000, 10000, 50000, 250000, 1000000]},
	{"id": "waves", "name": "Muralla inquebrantable", "desc": "Supera %s oleadas", "tiers": [25, 100, 500, 2000, 5000, 10000]},
	{"id": "bosses", "name": "Matagigantes", "desc": "Derrota %s jefes", "tiers": [1, 10, 50, 200, 500]},
	{"id": "build", "name": "Maestro constructor", "desc": "Construye %s torres", "tiers": [10, 100, 500, 2000, 10000]},
	{"id": "upgrade", "name": "Herrero real", "desc": "Mejora torres %s veces", "tiers": [20, 200, 1000, 5000, 20000]},
	{"id": "flyers", "name": "Cazadragones", "desc": "Derriba %s voladores", "tiers": [20, 200, 2000, 10000, 50000]},
	{"id": "packs", "name": "Coleccionista", "desc": "Abre %s sobres", "tiers": [1, 10, 50, 200, 1000]},
	{"id": "maps", "name": "Conquistador", "desc": "Desbloquea %s mapas", "tiers": [2, 5, 10, 15, 20]},
	{"id": "cards", "name": "Archivo del reino", "desc": "Consigue %s cartas distintas", "tiers": [6, 10, 14, 18, 20]},
	{"id": "level", "name": "Leyenda viva", "desc": "Alcanza el nivel de cuenta %s", "tiers": [5, 10, 25, 50, 100]},
]
## Oro por cada nivel de logro.
const ACHIEVEMENT_GOLD := [500, 1250, 2500, 5000, 10000, 20000]


# ================================================================ Helpers
func card_def(id: String) -> Dictionary:
	if TOWERS.has(id):
		return TOWERS[id]
	if HEROES.has(id):
		return HEROES[id]
	return {}


func is_hero(id: String) -> bool:
	return HEROES.has(id)


func all_card_ids() -> Array:
	var ids: Array = TOWERS.keys()
	ids.append_array(HEROES.keys())
	return ids


## Cartas de una rareza; `kind` = "tower" o "hero" para sobres de un solo tipo.
func cards_of_rarity(rarity: String, kind := "") -> Array:
	var out: Array = []
	for id in all_card_ids():
		if kind == "tower" and is_hero(id) or kind == "hero" and not is_hero(id):
			continue
		if card_def(id)["rarity"] == rarity:
			out.append(id)
	return out


func map_difficulty(map_idx: int) -> float:
	return 1.0 + 0.5 * map_idx + 0.03 * map_idx * map_idx


## Primer camino del mapa (puntos de giro). Los mapas con varias entradas tienen más: ver MapGen.
func map_path(map_idx: int) -> Array:
	return MapGen.generate(map_idx)["paths"][0]


func cell_center(c: Vector2i) -> Vector2:
	return GRID_OFFSET + Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE * 0.5)


func format_num(n: float) -> String:
	var a := absf(n)
	if a >= 1e12:
		return "%.1fT" % (n / 1e12)
	if a >= 1e9:
		return "%.1fB" % (n / 1e9)
	if a >= 1e6:
		return "%.1fM" % (n / 1e6)
	if a >= 1e4:
		return "%.1fK" % (n / 1e3)
	return str(int(n))


# ================================================================ Enemigos temáticos por mapa
## Arquetipos: estadísticas base que se combinan con el nombre/aspecto de cada mapa.
const ARCHETYPES := {
	"grunt": {"hp": 1.0, "speed": 1.0, "size": 0.24},
	"runner": {"hp": 0.55, "speed": 1.85, "size": 0.22},
	"brute": {"hp": 2.2, "speed": 0.8, "armor": 0.35, "size": 0.3},
	"flyer": {"hp": 0.7, "speed": 1.45, "flying": true, "size": 0.22},
	"caster": {"hp": 1.3, "speed": 0.9, "resist": 0.55, "size": 0.25},
	"tank": {"hp": 4.5, "speed": 0.5, "armor": 0.55, "size": 0.36, "traits": ["slow_immune"]},
	"healer": {"hp": 1.4, "speed": 0.85, "size": 0.26, "traits": ["healer"]},
	"regen": {"hp": 3.0, "speed": 0.7, "size": 0.32, "traits": ["regen"]},
	"ghost": {"hp": 1.0, "speed": 1.1, "size": 0.25, "traits": ["ethereal"]},
	"splitter": {"hp": 1.6, "speed": 0.9, "size": 0.28, "traits": ["split"]},
	"summoner": {"hp": 2.0, "speed": 0.75, "resist": 0.3, "size": 0.27, "traits": ["summoner"]},
	"bigflyer": {"hp": 5.0, "speed": 0.7, "armor": 0.3, "resist": 0.3, "flying": true, "size": 0.38},
}

## Por mapa: 5 enemigos [nombre, arquetipo, forma, color, extras] (de más fácil a más duro) y el jefe.
const THEMED := [
	{"enemies": [["Bandido", "grunt", "blob", Color(0.55, 0.4, 0.25)], ["Lobo Gris", "runner", "beast", Color(0.5, 0.5, 0.52)],
		["Jabalí Salvaje", "brute", "beast", Color(0.4, 0.28, 0.2)], ["Cuervo", "flyer", "wings", Color(0.12, 0.12, 0.15)],
		["Ogro Campesino", "tank", "brute", Color(0.55, 0.6, 0.35)]],
		"boss": ["Rey Bandido", "brute", Color(0.6, 0.35, 0.2), {}]},
	{"enemies": [["Duende", "runner", "blob", Color(0.35, 0.6, 0.25)], ["Araña Gigante", "grunt", "beast", Color(0.2, 0.15, 0.18)],
		["Polilla Nocturna", "flyer", "wings", Color(0.55, 0.45, 0.65)], ["Druida Oscuro", "healer", "robe", Color(0.25, 0.35, 0.2)],
		["Treant Joven", "regen", "golem", Color(0.38, 0.3, 0.18)]],
		"boss": ["Ent Corrompido", "golem", Color(0.3, 0.25, 0.15), {"traits": ["regen", "slow_immune"]}]},
	{"enemies": [["Kobold", "grunt", "blob", Color(0.75, 0.45, 0.2)], ["Lagarto de Roca", "runner", "beast", Color(0.55, 0.52, 0.42)],
		["Arpía de las Colinas", "flyer", "wings", Color(0.65, 0.5, 0.35)], ["Chamán Kobold", "healer", "robe", Color(0.6, 0.35, 0.2)],
		["Gólem de Piedra", "tank", "golem", Color(0.5, 0.48, 0.45)]],
		"boss": ["Gigante de las Colinas", "brute", Color(0.55, 0.45, 0.35), {"armor": 0.35}]},
	{"enemies": [["Hombre Rana", "grunt", "blob", Color(0.35, 0.55, 0.3)], ["Mosquito Gigante", "flyer", "wings", Color(0.4, 0.35, 0.25)],
		["Sanguijuela Gigante", "splitter", "slime", Color(0.5, 0.15, 0.15)], ["Bruja del Pantano", "caster", "robe", Color(0.3, 0.4, 0.25)],
		["Troll del Pantano", "regen", "brute", Color(0.35, 0.45, 0.35)]],
		"boss": ["Hidra del Pantano", "dragon", Color(0.25, 0.45, 0.3), {"traits": ["regen"]}]},
	{"enemies": [["Esqueleto", "grunt", "blob", Color(0.9, 0.9, 0.85), {"traits": ["undead"]}], ["Murciélago Vampiro", "flyer", "wings", Color(0.3, 0.15, 0.25)],
		["Espectro", "ghost", "ghost", Color(0.7, 0.85, 0.95, 0.75), {"traits": ["ethereal", "undead"]}], ["Zombi", "brute", "brute", Color(0.45, 0.55, 0.4), {"traits": ["undead"]}],
		["Nigromante", "summoner", "robe", Color(0.25, 0.3, 0.25), {"traits": ["summoner", "undead"]}]],
		"boss": ["Señor Vampiro", "robe", Color(0.45, 0.05, 0.1), {"traits": ["regen", "undead"], "resist": 0.4}]},
	{"enemies": [["Enano Renegado", "grunt", "brute", Color(0.6, 0.4, 0.3), {"armor": 0.25}], ["Lobo de las Nieves", "runner", "beast", Color(0.9, 0.92, 0.95)],
		["Halcón Helado", "flyer", "wings", Color(0.6, 0.75, 0.9), {"immune": ["ice"]}], ["Chamán de Escarcha", "healer", "robe", Color(0.4, 0.55, 0.75)],
		["Yeti", "regen", "brute", Color(0.92, 0.94, 0.98)]],
		"boss": ["Gigante de Escarcha", "golem", Color(0.65, 0.85, 1.0), {"immune": ["ice"], "traits": ["slow_immune"], "armor": 0.45}]},
	{"enemies": [["Merodeador Glacial", "runner", "beast", Color(0.7, 0.8, 0.9)], ["Fragmento Vivo", "splitter", "slime", Color(0.6, 0.85, 1.0), {"immune": ["ice"]}],
		["Espíritu Helado", "ghost", "ghost", Color(0.75, 0.9, 1.0, 0.7), {"immune": ["ice"]}], ["Elemental de Hielo", "tank", "golem", Color(0.55, 0.8, 1.0), {"immune": ["ice"]}],
		["Wyrm de Hielo", "bigflyer", "dragon", Color(0.7, 0.88, 1.0), {"immune": ["ice"]}]],
		"boss": ["Dragón Blanco", "dragon", Color(0.92, 0.96, 1.0), {"flying": true, "immune": ["ice"], "armor": 0.3}]},
	{"enemies": [["Bandido del Desierto", "grunt", "blob", Color(0.8, 0.65, 0.4)], ["Escorpión Gigante", "runner", "beast", Color(0.6, 0.35, 0.15), {"armor": 0.2}],
		["Buitre", "flyer", "wings", Color(0.35, 0.28, 0.22)], ["Djinn", "caster", "robe", Color(0.3, 0.55, 0.85), {"immune": ["fire"]}],
		["Momia", "regen", "brute", Color(0.85, 0.8, 0.65), {"traits": ["regen", "undead"]}]],
		"boss": ["Faraón Maldito", "robe", Color(0.9, 0.75, 0.25), {"traits": ["summoner", "undead"], "resist": 0.45}]},
	{"enemies": [["Diablillo de Fuego", "runner", "blob", Color(1.0, 0.4, 0.1), {"immune": ["fire"]}], ["Salamandra", "grunt", "beast", Color(0.9, 0.3, 0.1), {"immune": ["fire"]}],
		["Fénix Menor", "flyer", "wings", Color(1.0, 0.55, 0.15), {"immune": ["fire"]}], ["Sacerdote de Lava", "healer", "robe", Color(0.5, 0.15, 0.1)],
		["Gólem de Magma", "tank", "golem", Color(0.35, 0.18, 0.12), {"immune": ["fire"]}]],
		"boss": ["Dragón de Magma", "dragon", Color(0.75, 0.2, 0.05), {"flying": true, "immune": ["fire"], "armor": 0.3, "resist": 0.3}]},
	{"enemies": [["Hada Maligna", "flyer", "wings", Color(0.85, 0.5, 0.9)], ["Elfo Oscuro", "caster", "robe", Color(0.3, 0.2, 0.4)],
		["Espectro Élfico", "ghost", "ghost", Color(0.7, 0.95, 0.8, 0.7)], ["Dríade Corrupta", "healer", "robe", Color(0.4, 0.55, 0.3)],
		["Guardián Rúnico", "tank", "golem", Color(0.6, 0.65, 0.7), {"resist": 0.4}]],
		"boss": ["Reina Élfica Caída", "robe", Color(0.55, 0.35, 0.7), {"resist": 0.6, "traits": ["healer"]}]},
	{"enemies": [["Ballestero Renegado", "grunt", "blob", Color(0.45, 0.4, 0.38)], ["Grifo de Guerra", "flyer", "wings", Color(0.7, 0.6, 0.4)],
		["Caballero Negro", "brute", "brute", Color(0.15, 0.15, 0.2), {"resist": 0.4}], ["Capellán Oscuro", "healer", "robe", Color(0.25, 0.2, 0.25)],
		["Bestia de Asedio", "tank", "golem", Color(0.4, 0.3, 0.22)]],
		"boss": ["Señor de la Guerra", "brute", Color(0.35, 0.1, 0.1), {"armor": 0.5, "resist": 0.3}]},
	{"enemies": [["Kobold Dracónico", "runner", "blob", Color(0.75, 0.3, 0.2)], ["Dracónido", "brute", "brute", Color(0.6, 0.25, 0.15), {"immune": ["fire"]}],
		["Guiverno", "flyer", "wings", Color(0.3, 0.55, 0.45)], ["Hechicero Dracónico", "caster", "robe", Color(0.5, 0.15, 0.2)],
		["Dragón Joven", "bigflyer", "dragon", Color(0.7, 0.15, 0.1), {"immune": ["fire"]}]],
		"boss": ["Dragón Ancestral", "dragon", Color(0.55, 0.05, 0.05), {"flying": true, "immune": ["fire"], "armor": 0.35, "resist": 0.35}]},
	{"enemies": [["Hada de Cristal", "flyer", "wings", Color(0.75, 0.6, 1.0)], ["Limo Prismático", "splitter", "slime", Color(0.6, 0.8, 1.0)],
		["Escarabajo de Cristal", "brute", "beast", Color(0.45, 0.4, 0.75), {"armor": 0.6}], ["Mago Prismático", "caster", "robe", Color(0.6, 0.4, 0.85)],
		["Gólem de Cristal", "tank", "golem", Color(0.65, 0.55, 0.95), {"resist": 0.3}]],
		"boss": ["Coloso de Cristal", "golem", Color(0.7, 0.6, 1.0), {"armor": 0.5, "resist": 0.5, "traits": ["slow_immune"]}]},
	{"enemies": [["Acechador del Vacío", "runner", "ghost", Color(0.35, 0.15, 0.5, 0.8)], ["Ojo Flotante", "flyer", "blob", Color(0.6, 0.3, 0.7)],
		["Engendro del Vacío", "splitter", "slime", Color(0.3, 0.1, 0.4)], ["Profeta del Vacío", "summoner", "robe", Color(0.2, 0.1, 0.3)],
		["Horror Abisal", "regen", "brute", Color(0.25, 0.15, 0.35)]],
		"boss": ["Devorador del Vacío", "slime", Color(0.2, 0.05, 0.3), {"traits": ["regen", "split"], "resist": 0.4}]},
	{"enemies": [["Caballero Esqueleto", "brute", "brute", Color(0.85, 0.85, 0.8), {"traits": ["undead"]}], ["Banshee", "ghost", "ghost", Color(0.6, 0.95, 0.75, 0.7), {"traits": ["ethereal", "undead"]}],
		["Gárgola", "flyer", "wings", Color(0.45, 0.45, 0.48), {"armor": 0.4}], ["Liche Menor", "summoner", "robe", Color(0.4, 0.75, 0.55), {"traits": ["summoner", "undead"]}],
		["Abominación", "tank", "brute", Color(0.5, 0.6, 0.45), {"traits": ["regen", "undead"]}]],
		"boss": ["Liche Supremo", "robe", Color(0.5, 0.95, 0.7), {"traits": ["summoner", "undead"], "resist": 0.55}]},
	{"enemies": [["Demonio Menor", "grunt", "blob", Color(0.7, 0.1, 0.1), {"immune": ["fire"]}], ["Sabueso Infernal", "runner", "beast", Color(0.45, 0.1, 0.05), {"immune": ["fire"]}],
		["Súcubo", "flyer", "wings", Color(0.6, 0.15, 0.35)], ["Brujo Demoníaco", "caster", "robe", Color(0.4, 0.05, 0.15)],
		["Bruto Infernal", "tank", "brute", Color(0.5, 0.1, 0.05), {"immune": ["fire"]}]],
		"boss": ["Señor Demonio", "brute", Color(0.5, 0.05, 0.1), {"immune": ["fire"], "armor": 0.45, "resist": 0.4, "traits": ["regen"]}]},
	{"enemies": [["Pirata del Cielo", "grunt", "blob", Color(0.55, 0.4, 0.3)], ["Elemental de Viento", "runner", "ghost", Color(0.85, 0.95, 1.0, 0.7)],
		["Arpía Celeste", "flyer", "wings", Color(0.6, 0.75, 0.95)], ["Guardián de las Nubes", "healer", "robe", Color(0.9, 0.9, 0.95)],
		["Grifo Real", "bigflyer", "wings", Color(0.85, 0.7, 0.35)]],
		"boss": ["Roc Gigante", "wings", Color(0.6, 0.45, 0.3), {"flying": true, "armor": 0.3}]},
	{"enemies": [["Wendigo", "runner", "beast", Color(0.75, 0.8, 0.85), {"traits": ["regen"]}], ["Bruja de Hielo", "caster", "robe", Color(0.5, 0.7, 0.95), {"immune": ["ice"]}],
		["Caballero de Hielo", "brute", "brute", Color(0.65, 0.8, 0.95), {"immune": ["ice"]}], ["Wyrm Helado", "bigflyer", "dragon", Color(0.55, 0.75, 0.95), {"immune": ["ice"]}],
		["Guardia Real Congelado", "tank", "golem", Color(0.7, 0.85, 1.0), {"immune": ["ice"]}]],
		"boss": ["Reina de Hielo", "robe", Color(0.75, 0.9, 1.0), {"immune": ["ice"], "traits": ["summoner"], "resist": 0.5}]},
	{"enemies": [["Corcel Pesadilla", "runner", "beast", Color(0.2, 0.1, 0.15)], ["Demonio Alado", "flyer", "wings", Color(0.45, 0.1, 0.2)],
		["Diablo Abisal", "brute", "brute", Color(0.55, 0.12, 0.25), {"immune": ["fire"]}], ["Invocador Abisal", "summoner", "robe", Color(0.35, 0.05, 0.2)],
		["Señor del Pozo", "regen", "golem", Color(0.4, 0.1, 0.1), {"immune": ["fire"]}]],
		"boss": ["Guardián de la Puerta", "golem", Color(0.45, 0.05, 0.15), {"immune": ["fire"], "armor": 0.5, "traits": ["slow_immune", "regen"]}]},
	{"enemies": [["Hechicero del Caos", "caster", "robe", Color(0.6, 0.1, 0.35)], ["Engendro del Caos", "splitter", "slime", Color(0.5, 0.05, 0.3)],
		["Caballero del Caos", "brute", "brute", Color(0.25, 0.05, 0.15), {"resist": 0.45}], ["Quimera", "bigflyer", "dragon", Color(0.55, 0.3, 0.15)],
		["Bestia del Caos", "tank", "golem", Color(0.35, 0.05, 0.2), {"traits": ["regen", "slow_immune"]}]],
		"boss": ["Emperador del Caos", "brute", Color(0.6, 0.05, 0.3), {"armor": 0.5, "resist": 0.5, "traits": ["regen", "summoner"]}]},
]


## Crea las entradas de ENEMIES de cada mapa y asigna su lista y jefe a MAPS.
func _build_themed_enemies() -> void:
	for mi in THEMED.size():
		var t: Dictionary = THEMED[mi]
		var roster: Array = []
		var grunt_id := ""
		var all_enemies: Array = t["enemies"].duplicate()
		all_enemies.append_array(THEMED_LATE[mi])
		for k in all_enemies.size():
			var e: Array = all_enemies[k]
			var id := "m%d_%d" % [mi, k]
			var arch: Dictionary = ARCHETYPES[e[1]] if ARCHETYPES.has(e[1]) else LATE_ARCHETYPES[e[1]]
			var d: Dictionary = arch.duplicate(true)
			d["name"] = e[0]
			d["shape"] = e[2]
			d["color"] = e[3]
			if e.size() > 4:
				for key in e[4].keys():
					d[key] = e[4][key]
			if e[1] == "assassin":
				# Los asesinos son invisibles: solo los ven las torres detectoras
				var tr: Array = (d.get("traits", []) as Array).duplicate()
				if not "invisible" in tr:
					tr.append("invisible")
				d["traits"] = tr
			ENEMIES[id] = d
			roster.append(id)
			if grunt_id == "":
				grunt_id = id
			if "split" in d.get("traits", []):
				# versión pequeña que aparece al dividirse
				var mini_id := id + "_mini"
				var m := d.duplicate(true)
				m["hp"] = 0.35
				m["speed"] = 1.3
				m["size"] = 0.17
				m["traits"] = []
				ENEMIES[mini_id] = m
				d["spawn"] = mini_id
		for k in roster.size():
			if "summoner" in ENEMIES[roster[k]].get("traits", []):
				ENEMIES[roster[k]]["summon"] = grunt_id
		var b: Array = t["boss"]
		var boss_id := "m%d_boss" % mi
		var bd := {"name": b[0], "shape": b[1], "color": b[2], "boss": true,
			"hp": 40.0 + 4.0 * mi, "speed": 0.5, "size": 0.48}
		for key in b[3].keys():
			bd[key] = b[3][key]
		if "summoner" in bd.get("traits", []):
			bd["summon"] = grunt_id
		if "split" in bd.get("traits", []):
			var mini_any := grunt_id
			for rid in roster:
				if ENEMIES.has(rid + "_mini"):
					mini_any = rid + "_mini"
					break
			bd["spawn"] = mini_any
		ENEMIES[boss_id] = bd
		MAPS[mi]["roster"] = roster
		MAPS[mi]["boss"] = boss_id


# ================================================================ Jefes y niveles permanentes
const BOSS_EVERY := 10 # un jefe cada 10 oleadas
const FIRST_HERO := "aldric" # héroe por defecto si no tienes ninguno (no se regala: solo sale en sobres)
## Héroes: nivel permanente que se sube con oro (no se pierde entre partidas).
const HERO_MAX_LEVEL := 10
const HERO_LEVEL_BASE_GEMS := 25
const HERO_LEVEL_GROWTH := 1.45


## Oro extra por derrotar a un jefe.
func boss_gold(map_idx: int, wave: int) -> int:
	# Los jefes son el momento clave: dan un buen botín (crece con el mapa y la oleada)
	return (5 + map_idx * 2 + wave / 10) * GEM_GOLD


## Bono de oro la primera vez que se llega a un múltiplo de 50 oleadas en un mapa.
func milestone_gold(map_idx: int, wave: int) -> int:
	return (10 + map_idx * 2 + (wave / 50) * 5) * GEM_GOLD


# ---------------------------------------------------------------- Entrenamiento de torres (Fortaleza, oro)
## Cada torre tiene un nivel inicial permanente: al construirla, en cualquier mapa, empieza en ese nivel.
const TOWER_TRAIN_MAX := 15 # hasta la Maestría
const TOWER_TRAIN_BASE_GEMS := 12
const TOWER_TRAIN_GROWTH := 1.45
const TOWER_TRAIN_RARITY_MULT := {"common": 1.0, "uncommon": 1.3, "rare": 1.7, "epic": 2.2, "legendary": 3.0}


## Nivel "visual" (0..5) de los modelos 3D a partir del nivel de partida (0..15): el modelo
## cambia cada 3 niveles (0-2, 3-5, 6-8, 9-11, 12-14) y en la Maestría (15). Entre medias,
## cada nivel añade además su propia decoración (ver Tower._build_level_deco).
func visual_level(level: int) -> int:
	if level >= MAX_TOWER_LEVEL:
		return 5
	return clampi(level / 3, 0, 4)



## Arquetipos de los enemigos tardíos (aparecen en oleadas altas).
const LATE_ARCHETYPES := {
	"swarm": {"hp": 0.3, "speed": 1.7, "size": 0.17},
	"berserker": {"hp": 2.0, "speed": 1.35, "size": 0.27},
	"shielded": {"hp": 2.5, "speed": 0.85, "armor": 0.4, "resist": 0.4, "size": 0.29},
	"assassin": {"hp": 1.0, "speed": 2.1, "size": 0.22, "traits": ["invisible"]},
	"warlock": {"hp": 2.6, "speed": 0.7, "resist": 0.5, "size": 0.28, "traits": ["summoner", "healer"]},
	"wyrm": {"hp": 7.0, "speed": 0.65, "armor": 0.35, "resist": 0.35, "flying": true, "size": 0.42},
	"colossus": {"hp": 9.0, "speed": 0.4, "armor": 0.6, "size": 0.44, "traits": ["slow_immune"]},
	"juggernaut": {"hp": 14.0, "speed": 0.35, "armor": 0.7, "size": 0.48, "traits": ["regen", "slow_immune"]},
}

## 10 enemigos más por mapa (en orden de aparición, del 6.º al 15.º).
const THEMED_LATE := [
	[["Rata de Granero", "swarm", "beast", Color(0.45, 0.38, 0.32)], ["Halcón Salvaje", "flyer", "wings", Color(0.6, 0.45, 0.3)], ["Mercenario Furioso", "berserker", "brute", Color(0.6, 0.3, 0.2)], ["Bruja de la Aldea", "caster", "robe", Color(0.35, 0.3, 0.45)], ["Soldado Desertor", "shielded", "brute", Color(0.5, 0.5, 0.55)], ["Ladrón Sombrío", "assassin", "ghost", Color(0.2, 0.2, 0.25, 0.8)], ["Hechicero Errante", "warlock", "robe", Color(0.45, 0.25, 0.5)], ["Grifo Salvaje", "wyrm", "wings", Color(0.75, 0.6, 0.35)], ["Ogro Jefe", "colossus", "brute", Color(0.5, 0.55, 0.3)], ["Gigante de los Campos", "juggernaut", "golem", Color(0.55, 0.5, 0.4)]],
	[["Enjambre de Avispas", "swarm", "wings", Color(0.9, 0.75, 0.2)], ["Búho Maldito", "flyer", "wings", Color(0.45, 0.35, 0.3)], ["Oso Rabioso", "berserker", "beast", Color(0.35, 0.22, 0.12)], ["Hada Oscura", "caster", "robe", Color(0.4, 0.2, 0.5)], ["Guardabosques Caído", "shielded", "brute", Color(0.3, 0.4, 0.25)], ["Sombra del Bosque", "assassin", "ghost", Color(0.15, 0.25, 0.15, 0.8)], ["Archidruida Corrupto", "warlock", "robe", Color(0.2, 0.3, 0.15)], ["Wyvern del Bosque", "wyrm", "dragon", Color(0.3, 0.5, 0.25)], ["Treant Anciano", "colossus", "golem", Color(0.35, 0.28, 0.15)], ["Corazón del Bosque", "juggernaut", "golem", Color(0.25, 0.35, 0.15)]],
	[["Topo Excavador", "swarm", "beast", Color(0.4, 0.32, 0.28)], ["Águila de Roca", "flyer", "wings", Color(0.55, 0.45, 0.35)], ["Kobold Berserker", "berserker", "blob", Color(0.8, 0.4, 0.15)], ["Geomante", "caster", "robe", Color(0.55, 0.5, 0.35)], ["Guerrero de Granito", "shielded", "golem", Color(0.6, 0.58, 0.55)], ["Acechador de Cuevas", "assassin", "beast", Color(0.3, 0.28, 0.3)], ["Señor Kobold", "warlock", "robe", Color(0.7, 0.35, 0.2)], ["Guiverno de Piedra", "wyrm", "dragon", Color(0.55, 0.52, 0.48)], ["Gólem Ancestral", "colossus", "golem", Color(0.45, 0.43, 0.4)], ["Titán de las Montañas", "juggernaut", "golem", Color(0.5, 0.48, 0.42)]],
	[["Enjambre de Moscas", "swarm", "wings", Color(0.25, 0.3, 0.2)], ["Libélula Gigante", "flyer", "wings", Color(0.3, 0.6, 0.55)], ["Cocodrilo Furioso", "berserker", "beast", Color(0.3, 0.4, 0.25)], ["Hechicera de la Ciénaga", "caster", "robe", Color(0.25, 0.4, 0.3)], ["Guerrero Lagarto", "shielded", "brute", Color(0.35, 0.5, 0.3)], ["Fuego Fatuo", "assassin", "ghost", Color(0.6, 1.0, 0.6, 0.7)], ["Bruja Anciana", "warlock", "robe", Color(0.3, 0.35, 0.2)], ["Dragón del Pantano", "wyrm", "dragon", Color(0.3, 0.45, 0.25)], ["Gólem de Lodo", "colossus", "golem", Color(0.4, 0.35, 0.22)], ["Behemot de la Ciénaga", "juggernaut", "brute", Color(0.3, 0.4, 0.3)]],
	[["Rata de Cripta", "swarm", "beast", Color(0.4, 0.38, 0.38), {"traits": ["undead"]}], ["Cuervo Carroñero", "flyer", "wings", Color(0.1, 0.1, 0.12)], ["Necrófago", "berserker", "beast", Color(0.5, 0.55, 0.45), {"traits": ["undead"]}], ["Alma en Pena", "caster", "ghost", Color(0.6, 0.7, 0.9, 0.7), {"traits": ["ethereal", "undead"]}], ["Guardián de Tumba", "shielded", "brute", Color(0.6, 0.6, 0.55), {"traits": ["undead"]}], ["Segador", "assassin", "ghost", Color(0.15, 0.15, 0.2, 0.85), {"traits": ["ethereal", "undead"]}], ["Archinigromante", "warlock", "robe", Color(0.2, 0.3, 0.2), {"traits": ["summoner", "healer", "undead"]}], ["Dragón Óseo", "wyrm", "dragon", Color(0.85, 0.85, 0.78), {"traits": ["undead"]}], ["Coloso de Huesos", "colossus", "golem", Color(0.9, 0.88, 0.8), {"traits": ["undead", "slow_immune"]}], ["Señor de la Cripta", "juggernaut", "brute", Color(0.35, 0.4, 0.35), {"traits": ["undead", "regen", "slow_immune"]}]],
	[["Liebre de las Nieves", "swarm", "beast", Color(0.95, 0.95, 0.98)], ["Búho Nival", "flyer", "wings", Color(0.92, 0.94, 0.96)], ["Bárbaro Helado", "berserker", "brute", Color(0.6, 0.45, 0.35)], ["Druida de Hielo", "caster", "robe", Color(0.5, 0.7, 0.9), {"immune": ["ice"]}], ["Enano Acorazado", "shielded", "brute", Color(0.55, 0.55, 0.6)], ["Espíritu de la Ventisca", "assassin", "ghost", Color(0.85, 0.95, 1.0, 0.7), {"immune": ["ice"]}], ["Señor de las Nieves", "warlock", "robe", Color(0.6, 0.75, 0.95)], ["Dragón de Escarcha", "wyrm", "dragon", Color(0.7, 0.85, 1.0), {"immune": ["ice"]}], ["Mamut de Guerra", "colossus", "beast", Color(0.55, 0.42, 0.32)], ["Yeti Ancestral", "juggernaut", "brute", Color(0.95, 0.96, 1.0)]],
	[["Pez de Hielo", "swarm", "slime", Color(0.65, 0.85, 1.0), {"immune": ["ice"]}], ["Cuervo Helado", "flyer", "wings", Color(0.5, 0.65, 0.85)], ["Morsa Furiosa", "berserker", "beast", Color(0.55, 0.45, 0.4)], ["Hechicero Glacial", "caster", "robe", Color(0.45, 0.65, 0.9), {"immune": ["ice"]}], ["Centinela de Hielo", "shielded", "golem", Color(0.65, 0.85, 1.0), {"immune": ["ice"]}], ["Cazador Invernal", "assassin", "ghost", Color(0.8, 0.9, 1.0, 0.75)], ["Reina de la Escarcha", "warlock", "robe", Color(0.7, 0.88, 1.0), {"immune": ["ice"]}], ["Wyrm Glacial", "wyrm", "dragon", Color(0.6, 0.8, 0.95), {"immune": ["ice"]}], ["Coloso Glacial", "colossus", "golem", Color(0.6, 0.8, 1.0), {"immune": ["ice"]}], ["Corazón del Glaciar", "juggernaut", "golem", Color(0.45, 0.7, 0.95), {"immune": ["ice"]}]],
	[["Enjambre de Langostas", "swarm", "wings", Color(0.6, 0.55, 0.25)], ["Murciélago del Desierto", "flyer", "wings", Color(0.55, 0.4, 0.3)], ["Guerrero Nómada", "berserker", "brute", Color(0.7, 0.55, 0.35)], ["Sacerdote del Sol", "caster", "robe", Color(0.9, 0.7, 0.3), {"immune": ["fire"]}], ["Guardia del Templo", "shielded", "brute", Color(0.85, 0.7, 0.3)], ["Asesino de las Dunas", "assassin", "ghost", Color(0.75, 0.6, 0.4, 0.8)], ["Hechicero Momia", "warlock", "robe", Color(0.85, 0.8, 0.65), {"traits": ["summoner", "healer", "undead"]}], ["Esfinge", "wyrm", "wings", Color(0.85, 0.7, 0.4)], ["Gusano de Arena", "colossus", "slime", Color(0.75, 0.6, 0.4)], ["Coloso de Arenisca", "juggernaut", "golem", Color(0.8, 0.65, 0.45)]],
	[["Chispa Viviente", "swarm", "blob", Color(1.0, 0.7, 0.2), {"immune": ["fire"]}], ["Murciélago de Ceniza", "flyer", "wings", Color(0.3, 0.25, 0.25)], ["Berserker Ígneo", "berserker", "brute", Color(0.8, 0.3, 0.1), {"immune": ["fire"]}], ["Brujo de Azufre", "caster", "robe", Color(0.7, 0.6, 0.15)], ["Guerrero Obsidiana", "shielded", "golem", Color(0.15, 0.12, 0.15), {"immune": ["fire"]}], ["Sombra de Humo", "assassin", "ghost", Color(0.3, 0.3, 0.3, 0.75)], ["Señor de las Llamas", "warlock", "robe", Color(0.9, 0.35, 0.1), {"immune": ["fire"]}], ["Dragón de Fuego", "wyrm", "dragon", Color(0.9, 0.3, 0.05), {"immune": ["fire"]}], ["Titán de Lava", "colossus", "golem", Color(0.45, 0.15, 0.08), {"immune": ["fire"]}], ["Corazón del Volcán", "juggernaut", "golem", Color(0.6, 0.15, 0.05), {"immune": ["fire"]}]],
	[["Pixie Traviesa", "swarm", "wings", Color(0.9, 0.7, 0.95)], ["Cuervo Rúnico", "flyer", "wings", Color(0.3, 0.25, 0.45)], ["Danzarín de Espadas", "berserker", "robe", Color(0.5, 0.35, 0.6)], ["Oráculo Caído", "caster", "robe", Color(0.65, 0.6, 0.85)], ["Centinela Élfico", "shielded", "brute", Color(0.6, 0.7, 0.75)], ["Asesino Élfico", "assassin", "ghost", Color(0.35, 0.25, 0.45, 0.8)], ["Archimago Élfico", "warlock", "robe", Color(0.45, 0.3, 0.7)], ["Dragón Feérico", "wyrm", "dragon", Color(0.7, 0.55, 0.9)], ["Gólem de Mármol", "colossus", "golem", Color(0.9, 0.9, 0.88)], ["Árbol de la Vida Corrupto", "juggernaut", "golem", Color(0.35, 0.3, 0.45)]],
	[["Rata de Asedio", "swarm", "beast", Color(0.4, 0.35, 0.3)], ["Cuervo de Guerra", "flyer", "wings", Color(0.12, 0.1, 0.12)], ["Verdugo", "berserker", "brute", Color(0.3, 0.1, 0.1)], ["Clérigo Hereje", "caster", "robe", Color(0.35, 0.25, 0.2)], ["Paladín Caído", "shielded", "brute", Color(0.4, 0.4, 0.45)], ["Espía de la Corona", "assassin", "ghost", Color(0.2, 0.2, 0.25, 0.8)], ["Señor Hereje", "warlock", "robe", Color(0.45, 0.1, 0.15)], ["Grifo Acorazado", "wyrm", "wings", Color(0.55, 0.5, 0.45)], ["Torre de Asedio Viviente", "colossus", "golem", Color(0.45, 0.35, 0.25)], ["Rey Caído", "juggernaut", "brute", Color(0.35, 0.3, 0.1)]],
	[["Cría de Dragón", "swarm", "dragon", Color(0.8, 0.35, 0.2)], ["Guiverno Rojo", "flyer", "wings", Color(0.7, 0.2, 0.15)], ["Berserker Dracónido", "berserker", "brute", Color(0.65, 0.2, 0.15), {"immune": ["fire"]}], ["Chamán del Cañón", "caster", "robe", Color(0.6, 0.35, 0.2)], ["Guardián de Escamas", "shielded", "brute", Color(0.5, 0.2, 0.15)], ["Cazador de Dragones", "assassin", "ghost", Color(0.45, 0.25, 0.2, 0.8)], ["Sumo Sacerdote Dracónico", "warlock", "robe", Color(0.55, 0.1, 0.15)], ["Dragón Adulto", "wyrm", "dragon", Color(0.65, 0.1, 0.05), {"immune": ["fire"]}], ["Dragón Acorazado", "colossus", "dragon", Color(0.4, 0.15, 0.1), {"immune": ["fire"]}], ["Wyrm Primordial", "juggernaut", "dragon", Color(0.5, 0.05, 0.05), {"immune": ["fire"]}]],
	[["Esquirla Viva", "swarm", "slime", Color(0.75, 0.65, 1.0)], ["Mariposa de Cristal", "flyer", "wings", Color(0.6, 0.8, 1.0)], ["Bestia Prismática", "berserker", "beast", Color(0.7, 0.5, 0.95)], ["Vidente de Cristal", "caster", "robe", Color(0.55, 0.45, 0.9)], ["Caballero Cristalino", "shielded", "brute", Color(0.6, 0.6, 0.9)], ["Sombra Refractada", "assassin", "ghost", Color(0.7, 0.6, 1.0, 0.7)], ["Señor de los Prismas", "warlock", "robe", Color(0.65, 0.4, 0.95)], ["Dragón de Cristal", "wyrm", "dragon", Color(0.7, 0.6, 1.0)], ["Titán Amatista", "colossus", "golem", Color(0.55, 0.3, 0.75)], ["Corazón de Cristal", "juggernaut", "golem", Color(0.8, 0.7, 1.0)]],
	[["Larva del Vacío", "swarm", "slime", Color(0.3, 0.1, 0.4)], ["Raya Abisal", "flyer", "wings", Color(0.25, 0.1, 0.35)], ["Desgarrador", "berserker", "beast", Color(0.35, 0.15, 0.45)], ["Susurrador", "caster", "ghost", Color(0.45, 0.25, 0.6, 0.75)], ["Coraza del Vacío", "shielded", "golem", Color(0.2, 0.1, 0.3)], ["Cambiaformas", "assassin", "ghost", Color(0.35, 0.2, 0.45, 0.8)], ["Heraldo del Vacío", "warlock", "robe", Color(0.3, 0.1, 0.45)], ["Leviatán Celeste", "wyrm", "dragon", Color(0.25, 0.1, 0.4)], ["Titán del Abismo", "colossus", "golem", Color(0.2, 0.05, 0.3)], ["Ente Primigenio", "juggernaut", "slime", Color(0.15, 0.05, 0.25)]],
	[["Calavera Voladora", "swarm", "blob", Color(0.85, 0.85, 0.8), {"traits": ["undead"]}], ["Murciélago Espectral", "flyer", "wings", Color(0.5, 0.8, 0.65), {"traits": ["undead"]}], ["Caballero de la Muerte", "berserker", "brute", Color(0.2, 0.25, 0.2), {"traits": ["undead"]}], ["Hechicero Esquelético", "caster", "robe", Color(0.8, 0.8, 0.75), {"traits": ["undead"]}], ["Guardia Real Esquelética", "shielded", "brute", Color(0.75, 0.78, 0.7), {"traits": ["undead"]}], ["Espectro Asesino", "assassin", "ghost", Color(0.5, 0.95, 0.7, 0.7), {"traits": ["ethereal", "undead"]}], ["Archiliche", "warlock", "robe", Color(0.45, 0.9, 0.65), {"traits": ["summoner", "healer", "undead"]}], ["Dracoliche", "wyrm", "dragon", Color(0.7, 0.85, 0.75), {"traits": ["undead"]}], ["Gólem de Carne", "colossus", "brute", Color(0.6, 0.5, 0.45), {"traits": ["undead", "slow_immune"]}], ["Rey Liche", "juggernaut", "robe", Color(0.4, 0.85, 0.6), {"traits": ["undead", "regen", "slow_immune"]}]],
	[["Imp Burlón", "swarm", "blob", Color(0.85, 0.2, 0.1), {"immune": ["fire"]}], ["Gárgola Infernal", "flyer", "wings", Color(0.35, 0.1, 0.08)], ["Demonio Berserker", "berserker", "brute", Color(0.75, 0.1, 0.05), {"immune": ["fire"]}], ["Hechicera Infernal", "caster", "robe", Color(0.55, 0.05, 0.2)], ["Guardián del Averno", "shielded", "golem", Color(0.35, 0.08, 0.05), {"immune": ["fire"]}], ["Demonio Sombrío", "assassin", "ghost", Color(0.3, 0.05, 0.1, 0.8)], ["Archidemonio", "warlock", "robe", Color(0.6, 0.05, 0.1), {"immune": ["fire"]}], ["Dragón Infernal", "wyrm", "dragon", Color(0.55, 0.05, 0.05), {"immune": ["fire"]}], ["Balrog", "colossus", "brute", Color(0.4, 0.05, 0.05), {"immune": ["fire"]}], ["Príncipe del Averno", "juggernaut", "brute", Color(0.6, 0.0, 0.1), {"immune": ["fire"]}]],
	[["Gorrión de Tormenta", "swarm", "wings", Color(0.75, 0.8, 0.9)], ["Cometa Viviente", "flyer", "wings", Color(0.95, 0.9, 0.6)], ["Corsario Celeste", "berserker", "brute", Color(0.45, 0.35, 0.3)], ["Tormentista", "caster", "robe", Color(0.5, 0.55, 0.75)], ["Caballero Alado", "shielded", "brute", Color(0.8, 0.8, 0.85)], ["Fantasma del Viento", "assassin", "ghost", Color(0.9, 0.95, 1.0, 0.7)], ["Señor de las Tormentas", "warlock", "robe", Color(0.35, 0.4, 0.65)], ["Dragón de Tormenta", "wyrm", "dragon", Color(0.5, 0.6, 0.85)], ["Isla Viviente", "colossus", "golem", Color(0.45, 0.6, 0.35)], ["Titán Celeste", "juggernaut", "golem", Color(0.75, 0.8, 0.95)]],
	[["Duende de Hielo", "swarm", "blob", Color(0.7, 0.85, 1.0)], ["Lechuza Real", "flyer", "wings", Color(0.85, 0.9, 1.0)], ["Lobo Real Helado", "berserker", "beast", Color(0.75, 0.85, 0.95)], ["Consejero Helado", "caster", "robe", Color(0.6, 0.75, 0.95), {"immune": ["ice"]}], ["Guardia Imperial", "shielded", "brute", Color(0.7, 0.8, 0.95), {"immune": ["ice"]}], ["Asesino del Trono", "assassin", "ghost", Color(0.75, 0.85, 1.0, 0.7)], ["Hechicero Real", "warlock", "robe", Color(0.55, 0.7, 1.0), {"immune": ["ice"]}], ["Dragón Imperial", "wyrm", "dragon", Color(0.8, 0.9, 1.0), {"immune": ["ice"]}], ["Coloso del Trono", "colossus", "golem", Color(0.65, 0.8, 1.0), {"immune": ["ice"]}], ["Rey del Invierno", "juggernaut", "brute", Color(0.85, 0.92, 1.0), {"immune": ["ice"]}]],
	[["Diablillo del Pozo", "swarm", "blob", Color(0.7, 0.1, 0.2)], ["Ojo del Abismo", "flyer", "blob", Color(0.6, 0.1, 0.25)], ["Torturador", "berserker", "brute", Color(0.45, 0.08, 0.15)], ["Bruja del Abismo", "caster", "robe", Color(0.5, 0.05, 0.2)], ["Carcelero Infernal", "shielded", "golem", Color(0.35, 0.05, 0.12)], ["Pesadilla", "assassin", "ghost", Color(0.3, 0.05, 0.15, 0.8)], ["Archiinvocador", "warlock", "robe", Color(0.55, 0.05, 0.25)], ["Dragón del Abismo", "wyrm", "dragon", Color(0.45, 0.05, 0.15), {"immune": ["fire"]}], ["Coloso del Pozo", "colossus", "golem", Color(0.3, 0.05, 0.1), {"immune": ["fire"]}], ["Señor del Abismo", "juggernaut", "brute", Color(0.5, 0.02, 0.15), {"immune": ["fire"]}]],
	[["Enjambre del Caos", "swarm", "wings", Color(0.55, 0.1, 0.3)], ["Arpía del Caos", "flyer", "wings", Color(0.5, 0.15, 0.35)], ["Campeón del Caos", "berserker", "brute", Color(0.4, 0.05, 0.2)], ["Oráculo del Caos", "caster", "robe", Color(0.6, 0.15, 0.4)], ["Guardián Retorcido", "shielded", "golem", Color(0.3, 0.05, 0.2)], ["Sombra del Caos", "assassin", "ghost", Color(0.4, 0.05, 0.25, 0.8)], ["Archihechicero del Caos", "warlock", "robe", Color(0.55, 0.05, 0.35)], ["Dragón del Caos", "wyrm", "dragon", Color(0.5, 0.1, 0.3)], ["Titán del Caos", "colossus", "golem", Color(0.35, 0.05, 0.25)], ["Avatar del Caos", "juggernaut", "brute", Color(0.6, 0.05, 0.35)]],
]


## Oleada en la que aparece por primera vez el enemigo `k` (0..14) de un mapa:
## los 15 se conocen poco a poco; el último no llega hasta la oleada ~195.
func enemy_intro_wave(k: int) -> int:
	return maxi(1, int(round(pow(float(k), 1.6) * 2.86)))


# ================================================================ Torres de sobre: más poderosas
## Bono de daño de las torres que se consiguen en sobres (según su rango).
## Las torres de cartas (sobres) son más fuertes que las de oro: multiplican todo su daño
## (también veneno y quemaduras) y tienen +10% de alcance.
const PACK_TOWER_BONUS := {"common": 1.5, "uncommon": 1.7, "rare": 2.0, "epic": 2.4, "legendary": 3.0}
const PACK_TOWER_RANGE := 1.1


# ================================================================ Sobres: garantías y duplicados
## Garantías de los sobres (pity): cartas sin esa rareza hasta asegurarla.
const PITY_EPIC := 20
const PITY_LEGENDARY := 90
const SOFT_PITY_START := 70
## Oro por cada copia sobrante de una carta ya al nivel máximo (por rareza).
const DUPLICATE_COINS := {"common": 300, "uncommon": 600, "rare": 1200, "epic": 2500, "legendary": 5000}



# ================================================================ Fortaleza: mejoras especiales (con oro)
## Permanentes para todos los mapas; cada nivel cuesta GEM_UPGRADE_GROWTH veces más que el anterior.
const GEM_UPGRADES := {
	"g_damage": {"name": "Bendición Real", "desc": "x1.08 daño de todas las torres (acumulativo)", "per_level": 0.08, "max": 15, "base_gems": 40, "mult": true, "icon": "sword"},
	"g_start_level": {"name": "Arquitectos Arcanos", "desc": "Las torres se construyen con +1 nivel por mejora", "per_level": 1.0, "max": 15, "base_gems": 80, "growth": 1.25, "icon": "castle"},
	"g_hero_cd": {"name": "Cronomante", "desc": "-6% recarga de la habilidad del héroe", "per_level": 0.06, "max": 8, "base_gems": 60, "icon": "hero"},
	"g_coins": {"name": "Cofre Real", "desc": "+10% oro ganado", "per_level": 0.1, "max": 10, "base_gems": 50, "icon": "coin_bag"},
	"g_lives": {"name": "Bastión Encantado", "desc": "+15 de vida de la fortaleza", "per_level": 15.0, "max": 6, "base_gems": 45, "icon": "heart"},
}
const GEM_UPGRADE_GROWTH := 1.4 # el coste base ("base_gems") se multiplica por GEM_GOLD


## Ordena cartas por color de rareza (común → legendaria). Con `owned_first`, dentro de cada
## rareza van primero las que tienes. El orden es estable (respeta el original en los empates).
func sort_by_rarity(ids: Array, owned_first := false) -> Array:
	var order := {}
	for i in ids.size():
		order[ids[i]] = i
	var out := ids.duplicate()
	out.sort_custom(func(a, b) -> bool:
		var ra := RARITY_ORDER.find(card_def(a)["rarity"])
		var rb := RARITY_ORDER.find(card_def(b)["rarity"])
		if ra != rb:
			return ra < rb
		if owned_first:
			var oa: bool = Save.owns(a)
			var ob: bool = Save.owns(b)
			if oa != ob:
				return oa
		return order[a] < order[b])
	return out
