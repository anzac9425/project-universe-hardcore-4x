extends Node2D
class_name SpaceSceneManager

@export var space_chunk_scene: PackedScene
@export var chunk_map_node: Node2D
@export var star_info_ui: StarUI
@export var help_info_ui: HelpUI

var chunk_map: Dictionary = {}
var chunk_size: int = 256

var holding: bool = false
var hold_timer: float = 0.0
var hold_threhold: float = 0.075

static var instance: SpaceSceneManager

func _ready() -> void:
	instance = self
	chunk_map_node.position += Vector2.RIGHT * 4 * 256
	chunk_map_node.position += Vector2.DOWN * 2 * 256

func _process(delta: float) -> void:
	if holding:
		hold_timer += delta
	else:
		hold_timer = 0

	var view_rect_size: Vector2 = get_viewport().get_visible_rect().size
	var chunk_rows: int = int(view_rect_size.x / chunk_size) + 4
	var chunk_cols: int = int(view_rect_size.y / chunk_size) + 4

	var keys := chunk_map.keys()
	for i in range(keys.size() - 1, -1, -1):
		var key: Vector2i = keys[i]
		if key.x >= round((-chunk_map_node.position.x - chunk_size * 2) / float(chunk_size)) \
		and key.x <= round((-chunk_map_node.position.x - chunk_size * 2 + chunk_rows * chunk_size) / float(chunk_size)) \
		and key.y >= round((-chunk_map_node.position.y - chunk_size * 2) / float(chunk_size)) \
		and key.y <= round((-chunk_map_node.position.y - chunk_size * 2 + chunk_cols * chunk_size) / float(chunk_size)):
			continue

		(chunk_map[key] as Node2D).queue_free()
		chunk_map.erase(key)

	var top_left_chunk_cord: Vector2i = Vector2i(
		int(round(-chunk_map_node.position.x - chunk_size * 2)) / chunk_size,
		int(round(-chunk_map_node.position.y - chunk_size * 2)) / chunk_size
	)

	for x in range(chunk_rows):
		for y in range(chunk_cols):
			var chunk_idx: Vector2i = top_left_chunk_cord + Vector2i.RIGHT * x + Vector2i.DOWN * y
			if not chunk_map.has(chunk_idx):
				var n: SpaceChunk = space_chunk_scene.instantiate()
				n.position = chunk_idx * chunk_size
				n.set_coords(str(chunk_idx))
				chunk_map[chunk_idx] = n
				chunk_map_node.add_child(n)

func _input(event: InputEvent) -> void:
	if is_ui_open():
		return

	if event is InputEventMouseMotion:
		var mouse_motion: InputEventMouseMotion = event
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			holding = true
			if hold_timer < hold_threhold:
				return

			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			chunk_map_node.position += mouse_motion.relative
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			holding = false
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_H:
			help_info_ui.visible = true

func open_star_ui(star: Star) -> void:
	star_info_ui.populate_star_info(star)
	star_info_ui.visible = true

func is_ui_open() -> bool:
	return star_info_ui.visible or help_info_ui.visible
