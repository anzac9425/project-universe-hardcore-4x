extends Node2D

@onready var active_scene: Node = $ActiveScene

func _ready() -> void:
	MaterialData.register_defaults()
	SceneManager.initialize(active_scene)
	SceneManager.change_scene("res://scenes/MainMenu.tscn")
