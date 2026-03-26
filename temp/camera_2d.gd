extends Camera2D

func _process(delta):
	if Input.is_key_pressed(KEY_Z):
		zoom -= Vector2.ONE * delta
	if Input.is_key_pressed(KEY_X):
		zoom += Vector2.ONE * delta
