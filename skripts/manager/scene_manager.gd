extends Node

var container: Node = null

func initialize(scene_container: Node) -> void:
	container = scene_container

func change_scene(path: String) -> void:
	if container == null:
		push_error("SceneManager is not initialized")
		return
	if not ResourceLoader.exists(path):
		push_error("Scene path does not exist: %s" % path)
		return

	for child in container.get_children():
		child.queue_free()

	var packed: PackedScene = load(path)
	if packed == null:
		push_error("Failed to load scene: %s" % path)
		return

	var scene := packed.instantiate()
	container.add_child(scene)
