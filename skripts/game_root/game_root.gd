extends Node

@onready var scene_container = $SceneContainer

func _ready():
	SceneManager.initialize($SceneContainer)
	SceneManager.change_scene("res://scenes/main_scene.tscn")
