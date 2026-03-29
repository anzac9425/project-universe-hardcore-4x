extends Node2D

const SCENE_MAINMENU_PATH = "res://scenes/MainMenu.tscn"

@onready var active_scene: Node = $ActiveScene


func _ready() -> void:
	SceneManager.initialize(active_scene)
	SceneManager.change_scene(SCENE_MAINMENU_PATH)
