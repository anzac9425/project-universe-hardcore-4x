extends Camera2D

func _process(delta):
	if Input.is_key_pressed(KEY_Z):
		zoom += Vector2.ONE * delta * 0.4
	if Input.is_key_pressed(KEY_X):
		zoom -= Vector2.ONE * delta * 0.4
	if Input.is_key_pressed(KEY_W):
		position += Vector2.UP * delta * 160
	if Input.is_key_pressed(KEY_A):
		position += Vector2.LEFT * delta * 160
	if Input.is_key_pressed(KEY_S):
		position += Vector2.DOWN * delta * 160
	if Input.is_key_pressed(KEY_D):
		position += Vector2.RIGHT * delta * 160
