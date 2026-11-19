extends Node
## Metaprogresión: mejoras globales, cartas, sobres (con oro), nivel de cuenta y logros.

signal pack_opened(results: Array)
signal quest_progress


# ================================================================ Mejoras globales
func upgrade_cost(id: String) -> int:
	var def: Dictionary = GameData.UPGRADES[id]
	var lvl := Save.upgrade_level(id)
	return int(float(def["base_cost"]) * GameData.UPGRADE_COST_MULT * pow(float(def.get("growth", GameData.UPGRADE_COST_GROWTH)), lvl))


## Nivel máximo de una mejora. No depende de los mapas: el freno es el precio, que crece
## exponencialmente, mientras que los mapas y oleadas avanzados dan muchas más monedas.
func upgrade_cap(id: String) -> int:
	return int(GameData.UPGRADES[id]["max"])


func can_buy_upgrade(id: String) -> bool:
	return Save.upgrade_level(id) < upgrade_cap(id) and Save.coins() >= upgrade_cost(id)


func buy_upgrade(id: String) -> bool:
	if not can_buy_upgrade(id):
		return false
	if not Save.spend_coins(upgrade_cost(id)):
		return false
	Save.data["upgrades"][id] = Save.upgrade_level(id) + 1
	Save.save_game()
	return true


# ================================================================ Cartas
## Copias necesarias para subir la carta del nivel actual al siguiente.
func copies_needed(level: int) -> int:
	return int(GameData.CARD_COPIES[clampi(level - 1, 0, GameData.CARD_COPIES.size() - 1)])


## Nivel máximo de las cartas: las cartas son una mecánica aparte y no dependen de los mapas
## (quien consiga muchas cartas será muy fuerte desde el primer mapa).
func card_cap() -> int:
	return GameData.MAX_CARD_LEVEL


## PC: subir una carta de nivel solo pide copias (sin oro).
func card_upgrade_cost(_level: int) -> int:
	return 0


func can_level_card(id: String) -> bool:
	var c := Save.card(id)
	var lvl := int(c["level"])
	return lvl > 0 and lvl < card_cap() and int(c["copies"]) >= copies_needed(lvl)


func level_card(id: String) -> bool:
	if not can_level_card(id):
		return false
	var c: Dictionary = Save.data["cards"][id]
	var lvl := int(c["level"])
	c["copies"] = int(c["copies"]) - copies_needed(lvl)
	c["level"] = lvl + 1
	Save.save_game()
	return true


## Sube la carta todos los niveles que permitan sus copias (se llama al recibir cartas).
func auto_level(id: String) -> int:
	var ups := 0
	while can_level_card(id):
		var c: Dictionary = Save.data["cards"][id]
		var lvl := int(c["level"])
		c["copies"] = int(c["copies"]) - copies_needed(lvl)
		c["level"] = lvl + 1
		ups += 1
	return ups


## Multiplicador de poder del nivel de carta (x1.35 por nivel sobre el 1). Las torres de oro no lo
## usan: su carta les da directamente el nivel de torre en la partida (CARD_TO_TOWER_LEVEL).
func card_power(id: String) -> float:
	if is_progress_tower(id):
		return 1.0
	return pow(1.35, maxi(Save.card_level(id) - 1, 0))


## Copias iguales que hacen falta para DESBLOQUEAR una carta de sobre: con la primera basta;
## las siguientes copias sirven para subirla de nivel (GameData.CARD_COPIES).
const UNLOCK_COPIES := {"common": 1, "uncommon": 1, "rare": 1, "epic": 1, "legendary": 1}


func unlock_copies(id: String) -> int:
	return int(UNLOCK_COPIES.get(GameData.card_def(id)["rarity"], 1))


## Suma una copia de la carta. Devuelve true si con ella la carta queda DESBLOQUEADA ahora.
func add_card(id: String) -> bool:
	var c: Dictionary = Save.data["cards"][id]
	if int(c["level"]) == 0:
		# Aún bloqueada: se juntan copias hasta llegar a las necesarias para su rareza
		c["copies"] = int(c["copies"]) + 1
		if int(c["copies"]) < unlock_copies(id):
			return false
		c["copies"] = int(c["copies"]) - unlock_copies(id)
		c["level"] = 1
		# Primer héroe que consigues: pasa a ser tu héroe en uso
		if GameData.is_hero(id) and not Save.owns(str(Save.data.get("selected_hero", ""))):
			Save.data["selected_hero"] = id
		return true
	if int(c["level"]) >= GameData.MAX_CARD_LEVEL:
		# Duplicado de una carta al máximo: nunca es inútil, se convierte en oro
		var rar: String = GameData.card_def(id)["rarity"]
		Save.data["coins"] = Save.coins() + int(GameData.DUPLICATE_COINS.get(rar, 300))
	else:
		c["copies"] = int(c["copies"]) + 1
		auto_level(id) # con las copias justas, la carta (y la torre) sube de nivel sola
	return false


# ================================================================ Sobres
func roll_rarity(weights: Dictionary) -> String:
	var total := 0.0
	for r in weights.keys():
		total += float(weights[r])
	var roll := randf() * total
	for r in GameData.RARITY_ORDER:
		roll -= float(weights.get(r, 0.0))
		if roll <= 0.0:
			return r
	return "common"


## Abre un sobre y devuelve [{id, rarity, new}]. No cobra: el llamador decide el pago.
var last_pack_id := "common" # para la animación de apertura (carátula del sobre)


func open_pack(pack_id: String) -> Array:
	var pack: Dictionary = GameData.PACKS[pack_id]
	last_pack_id = pack_id
	var results: Array = []
	var count := int(pack["cards"])
	var guarantee: String = pack["guarantee"]
	var best_idx := -1
	if not Save.data.has("pity"):
		Save.data["pity"] = {"epic": 0, "legendary": 0}
	var pity: Dictionary = Save.data["pity"]
	for i in count:
		var weights: Dictionary = (pack["weights"] as Dictionary).duplicate()
		# Soft pity: la probabilidad de legendaria sube a partir de SOFT_PITY_START cartas sin ella
		var over := int(pity["legendary"]) - GameData.SOFT_PITY_START
		if over > 0:
			weights["legendary"] = float(weights.get("legendary", 0.0)) * (1.0 + over * 0.6)
		var rarity := roll_rarity(weights)
		# Pity duro: garantías
		if int(pity["legendary"]) + 1 >= GameData.PITY_LEGENDARY:
			rarity = "legendary"
		elif int(pity["epic"]) + 1 >= GameData.PITY_EPIC and GameData.RARITY_ORDER.find(rarity) < GameData.RARITY_ORDER.find("epic"):
			rarity = "epic"
		if i == count - 1 and guarantee != "":
			# Garantía: la última carta sube de rareza si ninguna la alcanzó.
			if best_idx < GameData.RARITY_ORDER.find(guarantee):
				rarity = guarantee
		best_idx = maxi(best_idx, GameData.RARITY_ORDER.find(rarity))
		pity["legendary"] = 0 if rarity == "legendary" else int(pity["legendary"]) + 1
		pity["epic"] = 0 if GameData.RARITY_ORDER.find(rarity) >= GameData.RARITY_ORDER.find("epic") else int(pity["epic"]) + 1
		var kind: String = pack.get("kind", "")
		var pool := GameData.cards_of_rarity(rarity, kind)
		if pool.is_empty():
			pool = GameData.cards_of_rarity(rarity)
		var id: String = pool[randi() % pool.size()]
		var is_new := add_card(id)
		results.append({"id": id, "rarity": rarity, "new": is_new})
	Save.data["stats"]["packs"] = int(Save.data["stats"]["packs"]) + 1
	track("packs", 1)
	Save.save_game()
	pack_opened.emit(results)
	return results



## Precio en oro de un sobre.
func pack_price(pack_id: String) -> int:
	return int(GameData.PACKS[pack_id]["gold"])


## Compra y abre `qty` sobres de una vez (x1, x5, x10) con oro. Devuelve todas las cartas juntas.
func buy_packs(pack_id: String, qty := 1) -> Array:
	if not Save.spend_coins(pack_price(pack_id) * qty):
		return []
	var all: Array = []
	for k in qty:
		all.append_array(open_pack(pack_id))
	return all


# ================================================================ Recompensas genéricas
## Entrega una recompensa {coins, pack}. Devuelve las cartas si había sobre.
func grant(reward: Dictionary) -> Array:
	if reward.has("coins"):
		Save.data["coins"] = Save.coins() + int(reward["coins"])
	Save.save_game()
	if reward.has("pack"):
		return open_pack(reward["pack"])
	return []


func reward_text(reward: Dictionary) -> String:
	var parts: Array = []
	if reward.has("coins"):
		parts.append("%s oro" % GameData.format_num(reward["coins"]))
	if reward.has("pack"):
		parts.append(GameData.PACKS[reward["pack"]]["name"])
	return " + ".join(parts)


func track(id: String, amount: int) -> void:
	# Estadísticas para logros (kills/waves/packs se cuentan en su origen)
	if id in ["bosses", "build", "upgrade", "flyers"]:
		var st: Dictionary = Save.data["stats"]
		st[id] = int(st.get(id, 0)) + amount
	if GameData.XP_SOURCES.has(id):
		add_xp(int(GameData.XP_SOURCES[id]) * amount)
	quest_progress.emit()


# ================================================================ Nivel de cuenta
signal level_up(new_level: int, reward: Dictionary)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	Save.data["xp"] = int(Save.data["xp"]) + amount
	while int(Save.data["xp"]) >= GameData.xp_to_next(int(Save.data["level"])):
		Save.data["xp"] = int(Save.data["xp"]) - GameData.xp_to_next(int(Save.data["level"]))
		Save.data["level"] = int(Save.data["level"]) + 1
		var lvl := int(Save.data["level"])
		var reward := GameData.level_reward(lvl)
		# Los sobres de nivel se entregan como sobre pendiente para abrirlo en el menú
		var no_pack := reward.duplicate()
		no_pack.erase("pack")
		grant(no_pack)
		if reward.has("pack"):
			pending_packs().append(reward["pack"])
		level_up.emit(lvl, reward)


func pending_packs() -> Array:
	if not Save.data.has("pending_packs"):
		Save.data["pending_packs"] = []
	return Save.data["pending_packs"]


func open_pending_pack() -> Array:
	var pp := pending_packs()
	if pp.is_empty():
		return []
	var pack: String = pp.pop_front()
	return open_pack(pack)


# ================================================================ Logros
func achievement_value(id: String) -> int:
	match id:
		"maps": return int(Save.data["unlocked_maps"])
		"level": return int(Save.data["level"])
		"cards":
			var n := 0
			for cid in GameData.all_card_ids():
				if Save.owns(cid):
					n += 1
			return n
	return int(Save.data["stats"].get(id, 0))


func achievement_claimed(id: String) -> int:
	return int(Save.data["achievements"].get(id, 0))


## Índice del siguiente nivel a reclamar (o -1 si se completaron todos).
func achievement_next(a: Dictionary) -> int:
	var c := achievement_claimed(a["id"])
	return c if c < a["tiers"].size() else -1


func can_claim_achievement(a: Dictionary) -> bool:
	var t := achievement_next(a)
	return t >= 0 and achievement_value(a["id"]) >= int(a["tiers"][t])


## Oro del siguiente nivel de un logro.
func achievement_reward(a: Dictionary) -> int:
	var t := maxi(achievement_next(a), 0)
	return int(GameData.ACHIEVEMENT_GOLD[mini(t, GameData.ACHIEVEMENT_GOLD.size() - 1)])


func claim_achievement(a: Dictionary) -> int:
	if not can_claim_achievement(a):
		return 0
	var gold := achievement_reward(a)
	Save.data["achievements"][a["id"]] = achievement_next(a) + 1
	Save.add_coins(gold)
	return gold


func claimable_achievements() -> int:
	var n := 0
	for a in GameData.ACHIEVEMENTS:
		if can_claim_achievement(a):
			n += 1
	return n


# ================================================================ Torres
## Torres "de oro": se construyen las veces que quieras y se mejoran con oro en la partida
## (las demás son torres de cartas: únicas y más fuertes).
func is_progress_tower(id: String) -> bool:
	return GameData.TOWERS.has(id) and GameData.TOWERS[id].has("unlock")


## En PC todas las torres se desbloquean con su carta (sobres), salvo la torre inicial.
func progress_unlocked(id: String) -> bool:
	return id == GameData.STARTER_TOWER or Save.owns(id)


## ¿Se puede construir esta torre?
func tower_available(id: String) -> bool:
	return progress_unlocked(id)


func unlock_text(_id: String) -> String:
	return "Consíguela en los sobres de la Tienda"


# ================================================================ Cooperativo
## Oro por llegar a la oleada `wave` en cooperativo (máximo en la oleada 100).
func coop_reward(wave: int) -> int:
	var w := mini(wave, 100)
	return ((w / 10) * 3 + (20 if w >= 100 else 0)) * GameData.GEM_GOLD


func claim_coop_reward(wave: int) -> int:
	var g := coop_reward(wave)
	Save.add_coins(g)
	return g


func pity_left(rarity: String) -> int:
	var cap := GameData.PITY_LEGENDARY if rarity == "legendary" else GameData.PITY_EPIC
	return cap - int(Save.data.get("pity", {}).get(rarity, 0))


# ================================================================ Nivel de las torres
## Nivel con el que se construye una torre de oro: lo marca su carta (solo sube con cartas).
func tower_start_level(id: String) -> int:
	if not is_progress_tower(id):
		return 0 # las torres de cartas usan directamente su nivel de carta
	var cl := clampi(Save.card_level(id), 0, GameData.CARD_TO_TOWER_LEVEL.size() - 1)
	if id == GameData.STARTER_TOWER:
		cl = maxi(cl, 1)
	return int(GameData.CARD_TO_TOWER_LEVEL[cl])


# ================================================================ Fortaleza: mejoras especiales (oro)
func gem_upgrade_cost(id: String) -> int:
	var def: Dictionary = GameData.GEM_UPGRADES[id]
	return int(round(float(def["base_gems"]) * pow(float(def.get("growth", GameData.GEM_UPGRADE_GROWTH)), Save.gem_upgrade_level(id)))) * GameData.GEM_GOLD


func can_buy_gem_upgrade(id: String) -> bool:
	return Save.gem_upgrade_level(id) < int(GameData.GEM_UPGRADES[id]["max"]) and Save.coins() >= gem_upgrade_cost(id)


func buy_gem_upgrade(id: String) -> bool:
	if not can_buy_gem_upgrade(id):
		return false
	if not Save.spend_coins(gem_upgrade_cost(id)):
		return false
	if not Save.data.has("gem_upgrades"):
		Save.data["gem_upgrades"] = {}
	Save.data["gem_upgrades"][id] = Save.gem_upgrade_level(id) + 1
	Save.save_game()
	return true


# ================================================================ Héroes: el nivel lo marca su carta
func can_level_hero(_id: String) -> bool:
	return false # PC: los héroes, como las torres, solo suben de nivel con cartas


func level_hero(_id: String) -> bool:
	return false
