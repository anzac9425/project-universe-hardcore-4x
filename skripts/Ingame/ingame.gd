extends Node2D

const MapWorldScript = preload("res://skripts/map/map_world.gd")

@onready var renderer: Node2D = $Renderer

var map_world = null
var current_chunk_coord: Vector2i = Vector2i.ZERO

func _ready() -> void:
	map_world = MapWorldScript.new()
	map_world.setup(20260213)
	_update_map_window(current_chunk_coord)

func _process(_delta: float) -> void:
	# TODO: camera/world position 기반 청크 좌표 계산으로 교체
	_update_map_window(current_chunk_coord)

func _update_map_window(center: Vector2i) -> void:
	for cy in range(center.y - 1, center.y + 2):
		for cx in range(center.x - 1, center.x + 2):
			map_world.ensure_chunk(Vector2i(cx, cy))
	map_world.unload_far_chunks(center, 2)
