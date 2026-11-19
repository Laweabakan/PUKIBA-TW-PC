extends Node
## Compras integradas (Google Play Billing).
##
## Si existe el singleton "GodotGooglePlayBilling" (plugin oficial de Godot para
## Android) se usa la facturación real. En el editor / PC se SIMULA la compra
## (solo en builds de depuración) para poder probar el flujo.
## Verifica la API exacta de la versión del plugin que instales (ver README).

signal purchase_success(product_id: String)
signal purchase_failed(product_id: String, reason: String)

var _billing: Object = null
var _connected := false
var _pending_product := ""


func _ready() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = Engine.get_singleton("GodotGooglePlayBilling")
		_connect_signal("connected", _on_connected)
		_connect_signal("disconnected", func() -> void: _connected = false)
		_connect_signal("purchases_updated", _on_purchases_updated)
		_connect_signal("purchase_error", _on_purchase_error)
		_connect_signal("query_purchases_response", _on_query_purchases)
		_billing.call("startConnection")


func _connect_signal(sig: String, cb: Callable) -> void:
	if _billing.has_signal(sig):
		_billing.connect(sig, cb)


func is_real_billing() -> bool:
	return _billing != null


func purchase(product_id: String) -> void:
	if not GameData.IAP_PRODUCTS.has(product_id):
		return
	if bool(Save.data.get("minor", false)):
		purchase_failed.emit(product_id, "Las compras con dinero real están desactivadas para menores. Pide ayuda a un adulto.")
		return
	if product_id == "no_ads" and bool(Save.data["no_ads"]):
		purchase_failed.emit(product_id, "Ya lo tienes.")
		return
	if product_id == "growth_fund" and bool(Save.data.get("growth_fund", false)):
		purchase_failed.emit(product_id, "Ya tienes el Fondo del Reino.")
		return
	if product_id == "starter_pack" and bool(Save.data["starter_bought"]):
		purchase_failed.emit(product_id, "Solo se puede comprar una vez.")
		return
	if _billing != null:
		if not _connected:
			purchase_failed.emit(product_id, "Sin conexión con Google Play.")
			_billing.call("startConnection")
			return
		_pending_product = product_id
		_billing.call("purchase", product_id)
	elif OS.is_debug_build():
		# Simulación para pruebas.
		_deliver(product_id)
	else:
		purchase_failed.emit(product_id, "Tienda no disponible.")


func restore_purchases() -> void:
	if _billing != null and _connected:
		_billing.call("queryPurchases", "inapp")


func _deliver(product_id: String) -> void:
	Meta.grant_product(product_id)
	Firebase.log_event("purchase", {"product": product_id})
	purchase_success.emit(product_id)


# ---------------------------------------------------------------- Callbacks del plugin
func _on_connected() -> void:
	_connected = true
	restore_purchases()


func _on_purchases_updated(purchases: Array) -> void:
	for p in purchases:
		_handle_purchase(p)


func _on_query_purchases(result: Dictionary) -> void:
	# Restaura compras no consumibles (p. ej. "Sin anuncios" al reinstalar).
	if int(result.get("status", 1)) != 0:
		return
	for p in result.get("purchases", []):
		var pid := _product_of(p)
		if pid == "no_ads" and not bool(Save.data["no_ads"]):
			Save.data["no_ads"] = true
			Save.save_game()
		elif pid == "starter_pack":
			Save.data["starter_bought"] = true
			Save.save_game()
		elif pid == "growth_fund":
			Save.data["growth_fund"] = true
			Save.save_game()
		elif GameData.IAP_PRODUCTS.has(pid) and bool(GameData.IAP_PRODUCTS[pid]["consumable"]):
			# Consumible no procesado (p. ej. la app se cerró durante la compra).
			_handle_purchase(p)


func _handle_purchase(p: Dictionary) -> void:
	# purchase_state 1 = PURCHASED
	if int(p.get("purchase_state", 0)) != 1:
		return
	var pid := _product_of(p)
	var token: String = p.get("purchase_token", "")
	if not GameData.IAP_PRODUCTS.has(pid):
		return
	if bool(GameData.IAP_PRODUCTS[pid]["consumable"]):
		_billing.call("consumePurchase", token)
	elif not bool(p.get("is_acknowledged", false)):
		_billing.call("acknowledgePurchase", token)
	_deliver(pid)
	_pending_product = ""


func _product_of(p: Dictionary) -> String:
	if p.has("products") and p["products"].size() > 0:
		return p["products"][0]
	if p.has("skus") and p["skus"].size() > 0:
		return p["skus"][0]
	return p.get("sku", "")


func _on_purchase_error(code: int, message: String) -> void:
	purchase_failed.emit(_pending_product, "Error %d: %s" % [code, message])
	_pending_product = ""
