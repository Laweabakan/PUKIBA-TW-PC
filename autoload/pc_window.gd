extends Node
## Ventana del juego en PC: aplica pantalla completa y VSync al arrancar y atiende F11 / Alt+Intro
## en cualquier pantalla.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SettingsPanel.apply_window.call_deferred()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			SettingsPanel.toggle_fullscreen()
			get_viewport().set_input_as_handled()
