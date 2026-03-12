extends Node2D

@onready var active_scene: Node = $ActiveScene


func _ready() -> void:
	SceneManager.initialize(active_scene)
	SceneManager.change_scene_with_loading("res://scenes/MainMenu.tscn")
