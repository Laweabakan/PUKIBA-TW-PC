extends Node
## Metaprogresión: mejoras globales, cartas, sobres, recompensas diarias y misiones.

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


func card_upgrade_cost(level: int) -> int:
	return 150 * level * level


func can_level_card(id: String) -> bool:
	var c := Save.card(id)
	var lvl := int(c["level"])
	return lvl > 0 and lvl < card_cap() \
		and int(c["copies"]) >= copies_needed(lvl) and Save.coins() >= card_upgrade_cost(lvl)


func level_card(id: String) -> bool:
	if not can_level_card(id):
		return false
	var c: Dictionary = Save.data["cards"][id]
	var lvl := int(c["level"])
	if not Save.spend_coins(card_upgrade_cost(lvl)):
		return false
	c["copies"] = int(c["copies"]) - copies_needed(lvl)
	c["level"] = lvl + 1
	Save.save_game()
	return true


## Multiplicador de poder que da el nivel de la carta (x1.35 por nivel sobre el 1; máximo nivel 5).
func card_power(id: String) -> float:
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
	Firebase.log_event("pack_opened", {"pack": pack_id})
	track("packs", 1)
	Save.save_game()
	pack_opened.emit(results)
	return results


func buy_pack_with_gems(pack_id: String) -> Array:
	if bool(Save.data.get("minor", false)):
		return [] # sin sobres pagados para menores
	var price := int(GameData.PACKS[pack_id]["gems"])
	if not Save.spend_gems(price):
		return []
	return open_pack(pack_id)


## Sobre de Bronce comprado con oro: 100 de oro, 1 al día.
const GOLD_PACK_ID := "common"
const GOLD_PACK_PRICE := 100
const GOLD_PACK_DAILY := 1


func gold_packs_left_today() -> int:
	var d: Dictionary = Save.data.get("gold_packs_day", {})
	var used := int(d.get("n", 0)) if str(d.get("day", "")) == Save.today() else 0
	return maxi(0, GOLD_PACK_DAILY - used)


func buy_gold_pack() -> Array:
	if gold_packs_left_today() <= 0 or Save.coins() < GOLD_PACK_PRICE:
		return []
	Save.data["coins"] = Save.coins() - GOLD_PACK_PRICE
	var d: Dictionary = Save.data.get("gold_packs_day", {})
	if str(d.get("day", "")) != Save.today():
		d = {"day": Save.today(), "n": 0}
	d["n"] = int(d["n"]) + 1
	Save.data["gold_packs_day"] = d
	return open_pack(GOLD_PACK_ID)


## Compra y abre `qty` sobres de una vez (x1, x5, x10). Devuelve todas las cartas juntas.
func buy_packs_with_gems(pack_id: String, qty: int) -> Array:
	if bool(Save.data.get("minor", false)):
		return []
	var price := int(GameData.PACKS[pack_id]["gems"]) * qty
	if not Save.spend_gems(price):
		return []
	var all: Array = []
	for k in qty:
		all.append_array(open_pack(pack_id))
	return all


func free_pack_ready() -> bool:
	return Save.now() >= int(Save.data["free_pack_at"])


func free_pack_seconds_left() -> int:
	return maxi(int(Save.data["free_pack_at"]) - Save.now(), 0)


## Sobre por anuncio: uno cada 3 horas.
func ad_pack_ready() -> bool:
	return Save.now() >= int(Save.data.get("ad_pack_at", 0))


func ad_pack_seconds_left() -> int:
	return maxi(int(Save.data.get("ad_pack_at", 0)) - Save.now(), 0)


func claim_ad_pack() -> Array:
	if not ad_pack_ready():
		return []
	Save.data["ad_pack_at"] = Save.now() + GameData.AD_PACK_COOLDOWN
	return open_pack("common")


func claim_free_pack() -> Array:
	if not free_pack_ready():
		return []
	Save.data["free_pack_at"] = Save.now() + GameData.FREE_PACK_COOLDOWN
	return open_pack("common")


# ================================================================ Recompensas genéricas
## Entrega una recompensa {coins, gems, pack}. Devuelve las cartas si había sobre.
func grant(reward: Dictionary) -> Array:
	if reward.has("coins"):
		Save.data["coins"] = Save.coins() + int(reward["coins"])
	if reward.has("gems"):
		Save.data["gems"] = Save.gems() + int(reward["gems"])
	Save.save_game()
	if reward.has("legendary"):
		return [grant_legendary()]
	if reward.has("pack"):
		return open_pack(reward["pack"])
	return []


## Carta legendaria (torre o héroe) para el día 7: primero una que el jugador no tenga.
func grant_legendary() -> Dictionary:
	var pool := GameData.cards_of_rarity("legendary")
	var missing: Array = pool.filter(func(id): return not Save.owns(id))
	var from: Array = missing if not missing.is_empty() else pool
	var id: String = from[randi() % from.size()]
	var is_new := add_card(id)
	last_pack_id = "legendary"
	Save.save_game()
	return {"id": id, "rarity": "legendary", "new": is_new}


func reward_text(reward: Dictionary) -> String:
	var parts: Array = []
	if reward.has("coins"):
		parts.append("%s oro" % GameData.format_num(reward["coins"]))
	if reward.has("gems"):
		parts.append("%d gemas" % int(reward["gems"]))
	if reward.has("pack"):
		parts.append(GameData.PACKS[reward["pack"]]["name"])
	if reward.has("legendary"):
		parts.append("Torre o héroe LEGENDARIO")
	return " + ".join(parts)


# ================================================================ Diario
func _day_number(date: String) -> int:
	if date == "":
		return -999999
	return int(Time.get_unix_time_from_datetime_string(date + "T00:00:00") / 86400)


func daily_available() -> bool:
	return Save.data["daily"]["last_claim"] != Save.today()


## Índice (0..6) del premio que toca hoy (o que se reclamó hoy).
func daily_index() -> int:
	var d: Dictionary = Save.data["daily"]
	var streak := int(d["streak"])
	if daily_available():
		var gap := _day_number(Save.today()) - _day_number(d["last_claim"])
		if gap > 1:
			streak = 0 # Racha perdida: vuelve al día 1.
		return streak % 7
	return (streak - 1) % 7


func streak_broken() -> bool:
	var d: Dictionary = Save.data["daily"]
	return int(d["streak"]) > 0 and daily_available() \
		and _day_number(Save.today()) - _day_number(d["last_claim"]) > 1


func claim_daily() -> Array:
	if not daily_available():
		return []
	var idx := daily_index()
	var d: Dictionary = Save.data["daily"]
	d["streak"] = idx + 1
	d["last_claim"] = Save.today()
	d["doubled"] = false
	return grant(GameData.DAILY_REWARDS[idx])


func can_double_daily() -> bool:
	return not daily_available() and not bool(Save.data["daily"]["doubled"])


func double_daily() -> Array:
	if not can_double_daily():
		return []
	Save.data["daily"]["doubled"] = true
	var r: Dictionary = GameData.DAILY_REWARDS[daily_index()]
	return grant(GameData.DAILY_DAY7_DOUBLE if r.has("legendary") else r)


# ================================================================ Misiones diarias
func quests() -> Array:
	var q: Dictionary = Save.data["quests"]
	if q["date"] != Save.today():
		var pool: Array = GameData.QUEST_POOL.duplicate()
		pool.shuffle()
		var list: Array = []
		for i in 3:
			list.append({"id": pool[i]["id"], "progress": 0, "claimed": false})
		q["date"] = Save.today()
		q["list"] = list
		Save.save_game()
	return q["list"]


func quest_def(id: String) -> Dictionary:
	for qd in GameData.QUEST_POOL:
		if qd["id"] == id:
			return qd
	return {}


func track(id: String, amount: int) -> void:
	# Estadísticas para logros (kills/waves/packs/ads se cuentan en su origen)
	if id in ["bosses", "build", "upgrade", "flyers"]:
		var st: Dictionary = Save.data["stats"]
		st[id] = int(st.get(id, 0)) + amount
	if GameData.XP_SOURCES.has(id):
		add_xp(int(GameData.XP_SOURCES[id]) * amount)
	_track_weekly(id, amount)
	var changed_any := false
	for q in quests():
		if q["id"] == id and not q["claimed"]:
			q["progress"] = int(q["progress"]) + amount
			changed_any = true
	if changed_any:
		quest_progress.emit()


func claim_quest(i: int) -> bool:
	var q: Dictionary = quests()[i]
	var qd := quest_def(q["id"])
	if q["claimed"] or int(q["progress"]) < int(qd["goal"]):
		return false
	q["claimed"] = true
	Save.add_gems(int(qd["gems"]))
	return true


func has_claimable() -> bool:
	if daily_available() or free_pack_ready() or ad_pack_ready() or claimable_achievements() > 0 or season_claimable() > 0 or weekly_claimable() > 0 or monthly_ready() or not growth_claimable().is_empty():
		return true
	for q in quests():
		if not q["claimed"] and int(q["progress"]) >= int(quest_def(q["id"])["goal"]):
			return true
	return false


# ================================================================ Anuncios
func ads_left_today() -> int:
	var a: Dictionary = Save.data["ads_today"]
	if a["date"] != Save.today():
		a["date"] = Save.today()
		a["count"] = 0
	return GameData.MAX_REWARDED_ADS_PER_DAY - int(a["count"])


func register_ad_watched() -> void:
	ads_left_today()
	Save.data["ads_today"]["count"] = int(Save.data["ads_today"]["count"]) + 1
	Save.data["stats"]["ads"] = int(Save.data["stats"]["ads"]) + 1
	track("ads", 1)
	Save.save_game()


# ================================================================ Compras (llamado por IAP)
func grant_product(product_id: String) -> void:
	var p: Dictionary = GameData.IAP_PRODUCTS.get(product_id, {})
	if p.is_empty():
		return
	match product_id:
		"no_ads":
			Save.data["no_ads"] = true
			Save.data["gems"] = Save.gems() + 200
			Save.save_game()
		"starter_pack":
			Save.data["starter_bought"] = true
			grant({"gems": 500, "coins": 5000, "pack": "epic"})
		"season_pass":
			season()["premium"] = true
			Save.save_game()
		"growth_fund":
			Save.data["growth_fund"] = true
			Save.save_game()
		"monthly_card":
			var start := maxi(Save.now(), int(Save.data.get("monthly_until", 0)))
			Save.data["monthly_until"] = start + 30 * 86400
			Save.add_gems(300)
		_:
			var g := int(p.get("gems", 0))
			if not Save.data["first_buy"].has(product_id):
				Save.data["first_buy"][product_id] = true
				g *= 2 # x2 en la primera compra de cada paquete
			Save.add_gems(g)


# ================================================================ Nivel de cuenta
signal level_up(new_level: int, reward: Dictionary)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	amount = int(amount * event_mult("xp"))
	Save.data["xp"] = int(Save.data["xp"]) + amount
	var s := season()
	s["xp"] = int(s["xp"]) + amount
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


func claim_achievement(a: Dictionary) -> int:
	if not can_claim_achievement(a):
		return 0
	var t := achievement_next(a)
	var gems: int = GameData.ACHIEVEMENT_GEMS[mini(t, GameData.ACHIEVEMENT_GEMS.size() - 1)]
	Save.data["achievements"][a["id"]] = t + 1
	Save.add_gems(gems)
	return gems


func claimable_achievements() -> int:
	var n := 0
	for a in GameData.ACHIEVEMENTS:
		if can_claim_achievement(a):
			n += 1
	return n


# ================================================================ Pase de temporada
func season_id() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d" % [int(d["year"]), int(d["month"])]


func season() -> Dictionary:
	var s: Dictionary = Save.data["season"]
	if s["id"] != season_id():
		s["id"] = season_id()
		s["xp"] = 0
		s["premium"] = false
		s["free"] = []
		s["prem"] = []
	return s


func season_tier() -> int:
	return mini(int(season()["xp"]) / GameData.SEASON_XP_PER_TIER, GameData.SEASON_TIERS)


func season_days_left() -> int:
	var d := Time.get_date_dict_from_system()
	var days_in_month := [31, 29 if int(d["year"]) % 4 == 0 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return int(days_in_month[int(d["month"]) - 1]) - int(d["day"]) + 1


func can_claim_season(tier: int, premium: bool) -> bool:
	var s := season()
	if tier > season_tier() or (premium and not bool(s["premium"])):
		return false
	return not (tier in s["prem" if premium else "free"])


func claim_season(tier: int, premium: bool) -> Array:
	if not can_claim_season(tier, premium):
		return []
	var s := season()
	s["prem" if premium else "free"].append(tier)
	return grant(GameData.season_reward(tier, premium))


func season_claimable() -> int:
	var n := 0
	for t in range(1, season_tier() + 1):
		if can_claim_season(t, false):
			n += 1
		if can_claim_season(t, true):
			n += 1
	return n


# ================================================================ Tesoro del castillo
func treasury_amount() -> int:
	var since := int(Save.data["treasury_at"])
	if since <= 0:
		Save.data["treasury_at"] = Save.now()
		return 0
	var hours := minf((Save.now() - since) / 3600.0, GameData.TREASURY_MAX_HOURS)
	return int(hours * GameData.treasury_rate(int(Save.data["unlocked_maps"])))


func treasury_full() -> bool:
	return Save.now() - int(Save.data["treasury_at"]) >= int(GameData.TREASURY_MAX_HOURS * 3600.0)


func claim_treasury(doubled := false) -> int:
	var amount := treasury_amount() * (2 if doubled else 1)
	Save.data["treasury_at"] = Save.now()
	if amount > 0:
		Save.add_coins(amount)
	else:
		Save.save_game()
	return amount


# ================================================================ Oferta del día
func daily_deal() -> Dictionary:
	var day := _day_number(Save.today())
	return GameData.DAILY_DEALS[absi(day) % GameData.DAILY_DEALS.size()]


func deal_available() -> bool:
	return Save.data["deal_bought"] != Save.today()


func buy_daily_deal() -> Array:
	if not deal_available():
		return []
	var deal := daily_deal()
	if not Save.spend_gems(int(deal["gems"])):
		return []
	Save.data["deal_bought"] = Save.today()
	return grant(deal["reward"])


# ================================================================ Torres de progreso
## Torres que se desbloquean jugando (las demás se consiguen en sobres).
func is_progress_tower(id: String) -> bool:
	return GameData.TOWERS.has(id) and GameData.TOWERS[id].has("unlock")


func progress_unlocked(id: String) -> bool:
	var u: Dictionary = GameData.TOWERS[id]["unlock"]
	var m := int(u["map"])
	if not Save.is_map_unlocked(m):
		return false
	return Save.best_wave(m) >= int(u["wave"]) or int(u["wave"]) <= 1 and Save.is_map_unlocked(m)


## ¿Se puede construir esta torre?
func tower_available(id: String) -> bool:
	if is_progress_tower(id):
		return progress_unlocked(id)
	return Save.owns(id)


func unlock_text(id: String) -> String:
	var u: Dictionary = GameData.TOWERS[id]["unlock"]
	if int(u["wave"]) <= 1:
		return "Desbloquea el mapa %d" % (int(u["map"]) + 1)
	return "Llega a la oleada %d en %s" % [int(u["wave"]), GameData.MAPS[int(u["map"])]["name"]]


# ================================================================ Sobres pagados con anuncios
func pack_ads_needed(pack_id: String) -> int:
	return maxi(1, int(GameData.PACKS[pack_id].get("ads", 1)) + int(current_event().get("pack_ads", 0)))


func pack_ads_progress(pack_id: String) -> int:
	if not Save.data.has("pack_ads"):
		Save.data["pack_ads"] = {}
	return int(Save.data["pack_ads"].get(pack_id, 0))


## Sobres que se pueden abrir con anuncios cada día, según su rareza:
## bronce 3, plata 2, oro y Cofre del Rey 1.
func pack_ad_daily_limit(pack_id: String) -> int:
	var p: Dictionary = GameData.PACKS[pack_id]
	var tier: String = p.get("tier", "")
	if tier == "":
		tier = {"common": "bronze", "rare": "silver", "epic": "gold", "legendary": "gold"}.get(pack_id, "gold")
	return {"bronze": 3, "silver": 2, "gold": 1}.get(tier, 1)


func pack_ads_opened_today(pack_id: String) -> int:
	var d: Dictionary = Save.data.get("pack_ads_day", {})
	if str(d.get("day", "")) != Save.today():
		return 0
	return int((d.get("opened", {}) as Dictionary).get(pack_id, 0))


func pack_ads_left_today(pack_id: String) -> int:
	return maxi(0, pack_ad_daily_limit(pack_id) - pack_ads_opened_today(pack_id))


## Suma un anuncio visto para ese sobre; si se completan, abre el sobre y devuelve las cartas.
func add_pack_ad(pack_id: String) -> Array:
	if pack_ads_left_today(pack_id) <= 0:
		return []
	var n := pack_ads_progress(pack_id) + 1
	if n >= pack_ads_needed(pack_id):
		Save.data["pack_ads"][pack_id] = 0
		var d: Dictionary = Save.data.get("pack_ads_day", {})
		if str(d.get("day", "")) != Save.today():
			d = {"day": Save.today(), "opened": {}}
		d["opened"][pack_id] = int(d["opened"].get(pack_id, 0)) + 1
		Save.data["pack_ads_day"] = d
		return open_pack(pack_id)
	Save.data["pack_ads"][pack_id] = n
	Save.save_game()
	return []


# ================================================================ Semana: misiones y evento
func week_id() -> int:
	return (_day_number(Save.today()) + 3) / 7 # semanas que empiezan en lunes


func current_event() -> Dictionary:
	return GameData.WEEKLY_EVENTS[absi(week_id()) % GameData.WEEKLY_EVENTS.size()]


## Multiplicador del evento de la semana para `key` (gold, coins, boss_gems, xp); 1 si no aplica.
func event_mult(key: String) -> float:
	return float(current_event().get(key, 1.0))


func event_days_left() -> int:
	return 7 - ((_day_number(Save.today()) + 3) % 7)


func weekly() -> Dictionary:
	if not Save.data.has("weekly"):
		Save.data["weekly"] = {"week": -1, "list": [], "bonus": false}
	var w: Dictionary = Save.data["weekly"]
	if int(w["week"]) != week_id():
		var pool: Array = GameData.WEEKLY_POOL.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = week_id() * 7919
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi() % (i + 1)
			var tmp = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		var list: Array = []
		for i in 5:
			list.append({"id": pool[i]["id"], "progress": 0, "claimed": false})
		w["week"] = week_id()
		w["list"] = list
		w["bonus"] = false
		Save.save_game()
	return w


func weekly_def(id: String) -> Dictionary:
	for qd in GameData.WEEKLY_POOL:
		if qd["id"] == id:
			return qd
	return {}


func _track_weekly(id: String, amount: int) -> void:
	for q in weekly()["list"]:
		if q["id"] == id and not q["claimed"]:
			q["progress"] = int(q["progress"]) + amount


func claim_weekly(i: int) -> bool:
	var q: Dictionary = weekly()["list"][i]
	var qd := weekly_def(q["id"])
	if q["claimed"] or int(q["progress"]) < int(qd["goal"]):
		return false
	q["claimed"] = true
	Save.add_gems(int(qd["gems"]))
	return true


func weekly_bonus_ready() -> bool:
	var w := weekly()
	if bool(w["bonus"]):
		return false
	for q in w["list"]:
		if not q["claimed"]:
			return false
	return true


func claim_weekly_bonus() -> Array:
	if not weekly_bonus_ready():
		return []
	weekly()["bonus"] = true
	return grant(GameData.WEEKLY_BONUS)


func weekly_claimable() -> int:
	var n := 0
	for q in weekly()["list"]:
		if not q["claimed"] and int(q["progress"]) >= int(weekly_def(q["id"])["goal"]):
			n += 1
	return n + (1 if weekly_bonus_ready() else 0)


# ================================================================ Cooperativo
const COOP_RUNS_PER_DAY := 3


## Gemas por llegar a la oleada `wave` en cooperativo (máximo oleada 100 -> 50 gemas).
func coop_reward(wave: int) -> int:
	var w := mini(wave, 100)
	return (w / 10) * 3 + (20 if w >= 100 else 0)


func coop_runs_left() -> int:
	if not Save.data.has("coop_runs") or Save.data["coop_runs"].get("date", "") != Save.today():
		Save.data["coop_runs"] = {"date": Save.today(), "count": 0}
	return COOP_RUNS_PER_DAY - int(Save.data["coop_runs"]["count"])


## Entrega la recompensa (si quedan partidas con premio hoy, o si `ad` = true tras un anuncio).
func claim_coop_reward(wave: int, ad := false) -> int:
	if coop_runs_left() <= 0 and not ad:
		return 0
	if not ad:
		Save.data["coop_runs"]["count"] = int(Save.data["coop_runs"]["count"]) + 1
	var g := coop_reward(wave)
	Save.add_gems(g)
	return g


# ================================================================ Biblia de monetización: sistemas
func gems_usd(g: int) -> String:
	return "≈US$%.2f" % (g / GameData.GEMS_PER_USD)


func first_buy_bonus(product_id: String) -> bool:
	return GameData.IAP_PRODUCTS[product_id].has("gems") and not Save.data["first_buy"].has(product_id)


func pity_left(rarity: String) -> int:
	var cap := GameData.PITY_LEGENDARY if rarity == "legendary" else GameData.PITY_EPIC
	return cap - int(Save.data.get("pity", {}).get(rarity, 0))


## Oferta de inicio: aparece tras el primer jefe y dura 48 h reales.
func start_starter_offer() -> void:
	if not bool(Save.data["starter_bought"]) and int(Save.data.get("starter_until", 0)) == 0:
		Save.data["starter_until"] = Save.now() + GameData.STARTER_HOURS * 3600
		Save.save_game()


func starter_seconds_left() -> int:
	if bool(Save.data["starter_bought"]):
		return 0
	return maxi(int(Save.data.get("starter_until", 0)) - Save.now(), 0)


## Escudo de racha: si solo faltaste un día, puedes recuperar la racha.
func streak_recoverable() -> bool:
	var d: Dictionary = Save.data["daily"]
	if int(d["streak"]) <= 0 or not daily_available():
		return false
	var gap := _day_number(Save.today()) - _day_number(d["last_claim"])
	return gap == 2 and Save.data.get("streak_shield", "") != Save.today()


func recover_streak() -> void:
	if not streak_recoverable():
		return
	var y := _day_number(Save.today()) - 1
	Save.data["daily"]["last_claim"] = Time.get_date_string_from_unix_time(y * 86400)
	Save.data["streak_shield"] = Save.today()
	Save.save_game()


## Tienda diaria: 3 cartas concretas por monedas, distintas cada día.
func daily_shop() -> Array:
	var sh: Dictionary = Save.data["daily_shop"]
	if sh["date"] != Save.today():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Save.today() + "tienda")
		var ids: Array = GameData.all_card_ids()
		var items: Array = []
		while items.size() < 3:
			var id: String = ids[rng.randi() % ids.size()]
			if not id in items:
				items.append(id)
		sh["date"] = Save.today()
		sh["items"] = items
		sh["bought"] = []
		Save.save_game()
	return sh["items"]


func daily_shop_price(id: String) -> int:
	return int(GameData.DAILY_SHOP_PRICE[GameData.card_def(id)["rarity"]])


func daily_shop_copies(id: String) -> int:
	return int(GameData.DAILY_SHOP_COPIES[GameData.card_def(id)["rarity"]])


func daily_shop_bought(id: String) -> bool:
	return id in Save.data["daily_shop"]["bought"]


func buy_daily_card(id: String) -> bool:
	if daily_shop_bought(id) or not Save.spend_coins(daily_shop_price(id)):
		return false
	for k in daily_shop_copies(id):
		add_card(id)
	Save.data["daily_shop"]["bought"].append(id)
	Save.save_game()
	return true


## Bono de regreso tras 7 días o más sin jugar. Devuelve la recompensa (vacía si no aplica).
## Segundos que el jugador estuvo fuera (antes de actualizar "last_seen").
func seconds_away() -> int:
	var last := int(Save.data.get("last_seen", 0))
	return 0 if last <= 0 else Save.now() - last


func check_return_bonus() -> Dictionary:
	var last := int(Save.data.get("last_seen", 0))
	Save.data["last_seen"] = Save.now()
	if last > 0 and Save.now() - last >= 7 * 86400:
		return {"gems": 50, "coins": 3000, "pack": "rare"}
	Save.save_game()
	return {}


## Fondo del Reino: niveles con premio disponibles.
func growth_claimable() -> Array:
	var out: Array = []
	if not bool(Save.data.get("growth_fund", false)):
		return out
	for lvl in GameData.GROWTH_FUND.keys():
		if int(Save.data["level"]) >= int(lvl) and not int(lvl) in Save.data["growth_claimed"]:
			out.append(int(lvl))
	return out


func claim_growth(lvl: int) -> int:
	if not lvl in growth_claimable():
		return 0
	Save.data["growth_claimed"].append(lvl)
	var g := int(GameData.GROWTH_FUND[lvl])
	Save.add_gems(g)
	return g


## Cofre Mensual: 60 gemas al día mientras esté activo.
func monthly_active() -> bool:
	return Save.now() < int(Save.data.get("monthly_until", 0))


func monthly_days_left() -> int:
	return maxi(0, (int(Save.data.get("monthly_until", 0)) - Save.now()) / 86400)


func monthly_ready() -> bool:
	return monthly_active() and Save.data.get("monthly_claimed", "") != Save.today()


func claim_monthly() -> int:
	if not monthly_ready():
		return 0
	Save.data["monthly_claimed"] = Save.today()
	Save.add_gems(GameData.MONTHLY_DAILY_GEMS)
	return GameData.MONTHLY_DAILY_GEMS


func feature_unlocked(id: String) -> bool:
	return int(Save.data["level"]) >= int(GameData.FEATURE_LEVELS.get(id, 1))


# ================================================================ Fortaleza: mejoras con gemas
# ================================================================ Entrenamiento de torres
func tower_train_cost(id: String) -> int:
	var r: String = GameData.TOWERS[id]["rarity"]
	var mult := float(GameData.TOWER_TRAIN_RARITY_MULT.get(r, 1.0))
	return int(round(GameData.TOWER_TRAIN_BASE_GEMS * mult * pow(GameData.TOWER_TRAIN_GROWTH, Save.tower_train_level(id))))


func buy_tower_train(id: String) -> bool:
	if Save.tower_train_level(id) >= GameData.TOWER_TRAIN_MAX:
		return false
	if not Save.spend_gems(tower_train_cost(id)):
		return false
	if not Save.data.has("tower_train"):
		Save.data["tower_train"] = {}
	Save.data["tower_train"][id] = Save.tower_train_level(id) + 1
	Save.save_game()
	Firebase.log_event("tower_train", {"id": id, "level": Save.tower_train_level(id)})
	return true


## Nivel con el que se construye una torre (entrenamiento + Arquitectos Arcanos), sin llegar a la Maestría.
func tower_start_level(id: String) -> int:
	if not is_progress_tower(id):
		return 0 # las torres de cartas no usan niveles de partida
	return mini(Save.tower_train_level(id) + int(Save.gem_upgrade_value("g_start_level")), GameData.MAX_TOWER_LEVEL) # hasta la Maestría


func gem_upgrade_cost(id: String) -> int:
	var def: Dictionary = GameData.GEM_UPGRADES[id]
	return int(round(float(def["base_gems"]) * pow(float(def.get("growth", GameData.GEM_UPGRADE_GROWTH)), Save.gem_upgrade_level(id))))


func can_buy_gem_upgrade(id: String) -> bool:
	return Save.gem_upgrade_level(id) < int(GameData.GEM_UPGRADES[id]["max"]) and Save.gems() >= gem_upgrade_cost(id)


func buy_gem_upgrade(id: String) -> bool:
	if not can_buy_gem_upgrade(id):
		return false
	if not Save.spend_gems(gem_upgrade_cost(id)):
		return false
	if not Save.data.has("gem_upgrades"):
		Save.data["gem_upgrades"] = {}
	Save.data["gem_upgrades"][id] = Save.gem_upgrade_level(id) + 1
	Save.save_game()
	Firebase.log_event("gem_upgrade", {"id": id})
	return true


# ================================================================ Héroes: nivel permanente con gemas
func hero_level_cost(id: String) -> int:
	return int(round(GameData.HERO_LEVEL_BASE_GEMS * pow(GameData.HERO_LEVEL_GROWTH, Save.hero_level(id))))


func can_level_hero(id: String) -> bool:
	return Save.owns(id) and Save.hero_level(id) < GameData.HERO_MAX_LEVEL and Save.gems() >= hero_level_cost(id)


func level_hero(id: String) -> bool:
	if not can_level_hero(id) or not Save.spend_gems(hero_level_cost(id)):
		return false
	if not Save.data.has("hero_levels"):
		Save.data["hero_levels"] = {}
	Save.data["hero_levels"][id] = Save.hero_level(id) + 1
	Save.save_game()
	Firebase.log_event("hero_level", {"hero": id, "level": Save.hero_level(id)})
	return true
