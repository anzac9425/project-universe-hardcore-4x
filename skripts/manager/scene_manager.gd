extends Node

var container: Node = null

func initialize(scene_container: Node):
	container = scene_container

func change_scene(path: String):
	for child in container.get_children():
		child.queue_free()
	var scene = load(path).instantiate()
	container.add_child(scene)
