extends Node2D

const MapWorldScript = preload("res://skripts/map/map_world.gd")
const CAMERA_ZOOM_STEP := 0.1
const CAMERA_ZOOM_MIN := 0.35
const CAMERA_ZOOM_MAX := 2.2
const CHUNK_WORLD_SIZE := 128.0
const FLOATING_ORIGIN_THRESHOLD := 4096.0

@onready var renderer: Node2D = $Renderer
@onready var map_camera: Camera2D = $MapCamera

var map_world = null
var current_chunk_coord: Vector2i = Vector2i.ZERO

var drag_active: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO

# 누적된 월드 오프셋(대규모 맵 논리 좌표)
var world_offset_accumulated: Vector2 = Vector2.ZERO
# 로컬 원점 주변에서만 유지되는 오프셋(정밀도 보호)
var local_view_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	map_world = MapWorldScript.new()
	map_world.setup(20260213)
	map_camera.position = Vector2.ZERO
	_update_map_window(current_chunk_coord)

func _process(_delta: float) -> void:
	# 카메라는 항상 원점에 고정(보고 있는 좌표 0,0 유지)
	map_camera.position = Vector2.ZERO
	_apply_floating_origin_if_needed()
	_update_current_chunk_coord()
	_update_map_window(current_chunk_coord)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(-CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(CAMERA_ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			drag_active = event.pressed
			if drag_active:
				last_mouse_position = event.position
	elif event is InputEventMouseMotion and drag_active:
		var delta := event.position - last_mouse_position
		last_mouse_position = event.position
		_pan_by_screen_delta(delta)

func _adjust_zoom(delta_zoom: float) -> void:
	var next_zoom := clamp(map_camera.zoom.x + delta_zoom, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
	map_camera.zoom = Vector2(next_zoom, next_zoom)

func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	# 마우스 이동과 반대 방향으로 맵이 이동하도록 부호 반전
	local_view_offset -= screen_delta / map_camera.zoom.x
	renderer.position = local_view_offset

func _apply_floating_origin_if_needed() -> void:
	if local_view_offset.length() < FLOATING_ORIGIN_THRESHOLD:
		return
	# 로컬 오프셋을 누적 좌표로 이관하고, 로컬 좌표를 0 근처로 리셋
	world_offset_accumulated += local_view_offset
	local_view_offset = Vector2.ZERO
	renderer.position = local_view_offset

func _update_current_chunk_coord() -> void:
	var total_offset := world_offset_accumulated + local_view_offset
	current_chunk_coord = Vector2i(
		int(floor(total_offset.x / CHUNK_WORLD_SIZE)),
		int(floor(total_offset.y / CHUNK_WORLD_SIZE))
	)

func _update_map_window(center: Vector2i) -> void:
	for cy in range(center.y - 1, center.y + 2):
		for cx in range(center.x - 1, center.x + 2):
			map_world.ensure_chunk(Vector2i(cx, cy))
	map_world.unload_far_chunks(center, 2)
