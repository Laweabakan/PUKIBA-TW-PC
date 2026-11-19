extends Node
## Reproduce clics reales en la pestaña Fortaleza y en una mejora.
func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		# Coordenadas de ventana real (como un ratón de verdad), no del lienzo interno
		var scale := Vector2(DisplayServer.window_get_size()) / Vector2(720, 1280)
		ev.position = pos * scale
		ev.global_position = pos * scale
		Input.parse_input_event(ev)
		await get_tree().process_frame
		if pressed:
			# pequeño temblor del ratón entre pulsar y soltar, como en la realidad
			for k in 3:
				var mv := InputEventMouseMotion.new()
				mv.button_mask = MOUSE_BUTTON_MASK_LEFT
				mv.position = ev.position + Vector2(k + 1, k + 1)
				mv.global_position = mv.position
				mv.relative = Vector2(1, 1)
				Input.parse_input_event(mv)
				await get_tree().process_frame
			ev.position += Vector2(3, 3)
			ev.global_position = ev.position
		await get_tree().process_frame

func _ready() -> void:
	Save.save_path = "user://click_test.json"
	Save.reset_all()
	Save.data["coins"] = 5000
	var menu: Control = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	for i in 20:
		await get_tree().process_frame
	# Cerrar cualquier hoja abierta (diario) con un clic fuera
	print("CLICK hoja abierta: ", menu.sheet != null and is_instance_valid(menu.sheet))
	for i in 10:
		await get_tree().process_frame
	var dock_btn: Control = menu.tab_buttons["upgrades"]["button"]
	print("CLICK dock_btn: ", dock_btn, " rect=", dock_btn.get_global_rect() if dock_btn else "")
	if dock_btn:
		await _click(dock_btn.get_global_rect().get_center())
	for i in 20:
		await get_tree().process_frame
	print("CLICK tab actual: ", menu.current_tab)
	# Buscar el primer botón de compra visible
	var target: Button = null
	var stack: Array = [menu.content]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and (n as Button).is_visible_in_tree() and not (n as Button).disabled:
			var r := (n as Button).get_global_rect()
			if r.position.y > 400 and r.position.y < 1100 and r.size.x < 300:
				target = n
				break
		for c in n.get_children():
			stack.push_front(c)
	print("CLICK botón: ", target, " rect=", target.get_global_rect() if target else "")
	var coins_before := Save.coins()
	if target:
		await _click(target.get_global_rect().get_center())
	print("CLICK monedas antes=%d después=%d nivel forja=%d" % [coins_before, Save.coins(), Save.upgrade_level("damage")])
	var hovered := get_viewport().gui_get_hovered_control() if get_viewport().has_method("gui_get_hovered_control") else null
	print("CLICK control bajo el ratón: ", hovered, " ", hovered.get_path() if hovered else "")
	get_tree().quit()
