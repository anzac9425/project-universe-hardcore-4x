extends Node2D

@onready var camera: Camera2D = $Camera2D

@export var move_speed := 2000.0
@export var zoom_speed := 0.1

@export var min_zoom := 0.2
@export var max_zoom := 4

@export var smoothing := 100.0

var drag_active := false
var last_mouse_pos: Vector2

var target_position: Vector2


func _ready():
	target_position = global_position


func _process(delta):

	_handle_keyboard(delta)

	global_position = global_position.lerp(target_position, smoothing * delta)


func _handle_keyboard(delta):

	var dir := Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		dir.y -= 1

	if Input.is_key_pressed(KEY_S):
		dir.y += 1

	if Input.is_key_pressed(KEY_A):
		dir.x -= 1

	if Input.is_key_pressed(KEY_D):
		dir.x += 1
		
	if Input.is_key_pressed(KEY_Z):
		_zoom_camera(zoom_speed)
		
	if Input.is_key_pressed(KEY_X):
		_zoom_camera(-zoom_speed)

	if dir != Vector2.ZERO:
		dir = dir.normalized()
		target_position += dir * move_speed * camera.zoom.x * delta


func _input(event):

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_MIDDLE:
			drag_active = event.pressed
			last_mouse_pos = get_viewport().get_mouse_position()

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(-zoom_speed)

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(zoom_speed)


	if event is InputEventMouseMotion and drag_active:

		var mouse_pos = get_viewport().get_mouse_position()
		var delta = mouse_pos - last_mouse_pos

		target_position -= delta * camera.zoom

		last_mouse_pos = mouse_pos


func _zoom_camera(amount):

	var new_zoom: float = camera.zoom.x + amount
	new_zoom = clamp(new_zoom, min_zoom, max_zoom)

	camera.zoom = Vector2(new_zoom, new_zoom)
