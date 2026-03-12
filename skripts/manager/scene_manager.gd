extends Node

const ERR_NOT_INITIALIZED := "ERR_SCENEMANAGER_NOT_INITIALIZED"
const ERR_SCENE_NOT_EXISTS := "ERR_SCENE_NOT_EXISTS"
const ERR_LOAD_FAILED := "ERR_SCENE_LOAD_FAILED"

const LOADING_SCENE_PATH := "res://scenes/Loading.tscn"

var container: Node
var current_scene: Node
var target_scene_path: String

var loading_progress: float = 0.0
var is_loading := false


func initialize(scene_container: Node) -> void:
	container = scene_container


# -----------------------------
# 일반 씬 전환
# -----------------------------
func change_scene(path: String) -> void:

	if container == null:
		push_error(tr(ERR_NOT_INITIALIZED))
		return

	if not ResourceLoader.exists(path):
		push_error(tr(ERR_SCENE_NOT_EXISTS) % path)
		return

	var packed: PackedScene = load(path)

	if packed == null:
		push_error(tr(ERR_LOAD_FAILED) % path)
		return

	_replace_scene_packed(packed)


# -----------------------------
# 로딩씬 포함 전환
# -----------------------------
func change_scene_with_loading(path: String) -> void:

	if container == null:
		push_error(tr(ERR_NOT_INITIALIZED))
		return

	if not ResourceLoader.exists(path):
		push_error(tr(ERR_SCENE_NOT_EXISTS) % path)
		return

	target_scene_path = path
	loading_progress = 0.0
	is_loading = true

	var packed: PackedScene = load(LOADING_SCENE_PATH)

	if packed == null:
		push_error(tr(ERR_LOAD_FAILED) % LOADING_SCENE_PATH)
		return

	_replace_scene_packed(packed)


# -----------------------------
# PackedScene 교체
# -----------------------------
func _replace_scene_packed(packed: PackedScene) -> void:

	if current_scene:
		current_scene.queue_free()
		current_scene = null

	var scene := packed.instantiate()

	container.add_child(scene)

	current_scene = scene


# -----------------------------
# LoadingScene이 호출
# -----------------------------
func finish_loading(packed: PackedScene) -> void:

	is_loading = false
	loading_progress = 1.0

	_replace_scene_packed(packed)
