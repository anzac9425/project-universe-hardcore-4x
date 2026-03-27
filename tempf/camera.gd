extends Camera2D

var zoom_speed: float = 0.02

func _process(delta):
	if Input.is_key_pressed(KEY_Z):
		zoom -= Vector2.ONE * zoom_speed
	elif Input.is_key_pressed(KEY_X):
		zoom += Vector2.ONE * zoom_speed
