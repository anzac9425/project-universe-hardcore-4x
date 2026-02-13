extends Camera2D

var dragging: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom *= 0.9

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed
			if dragging:
				last_mouse_pos = get_global_mouse_position()
	
	elif event is InputEventMouseMotion and dragging:
		var mouse_delta = get_global_mouse_position() - last_mouse_pos
		position -= mouse_delta * zoom.x
		last_mouse_pos = get_global_mouse_position()
