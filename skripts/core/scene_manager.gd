extends Node

const LOADING_SCENE_PATH := "res://scenes/Loading.tscn"

var container: Node
var current_scene: Node
var target_scene_path: String

var loading_progress: float = 0.0
var is_loading := false


func initialize(scene_container: Node):
	container = scene_container


func change_scene(path: String) -> void:

	if container == null:
		Log.error(1, "")
		return

	if not ResourceLoader.exists(path):
		Log.error(2, path)
		return

	var packed: PackedScene = load(path)

	if packed == null:
		Log.error(3, LOADING_SCENE_PATH)
		return

	_replace_scene(packed)


func change_scene_with_loading(path: String):

	if container == null:
		Log.error(1, "")
		return

	if not ResourceLoader.exists(path):
		Log.error(2, path)
		return

	target_scene_path = path
	loading_progress = 0.0
	is_loading = true

	var packed: PackedScene = load(LOADING_SCENE_PATH)

	if packed == null:
		is_loading = false
		Log.error(3, LOADING_SCENE_PATH)
		return

	_replace_scene(packed)


func _replace_scene(packed: PackedScene) -> void:

	if current_scene:
		current_scene.queue_free()
		current_scene = null

	var scene := packed.instantiate()

	container.add_child(scene)

	current_scene = scene


func finish_loading(packed: PackedScene) -> void:

	if packed == null:
		is_loading = false
		Log.error(3, target_scene_path)
		return

	is_loading = false
	loading_progress = 1.0

	_replace_scene(packed)
