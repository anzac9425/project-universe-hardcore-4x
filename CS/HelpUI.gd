extends Control
class_name HelpUI

@export var close_button: Control

func _ready() -> void:
	close_button.gui_input.connect(handle_close)

func handle_close(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			visible = false
