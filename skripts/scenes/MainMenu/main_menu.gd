extends Node2D

const SCENE_INGAME_PATH = "res://scenes/Ingame.tscn"

@export var base_seed: int = 0
@export var system_count: int = 128
@export var min_system_distance: float = 100.0
@export var galaxy_radius: float = 10000.0

func _on_start_button_pressed() -> void:
	var config = GameConfig.new()
	
	config.base_seed = base_seed
	config.system_count = system_count
	
	GameSession.start_new_game(config)
	SceneManager.change_scene_with_loading(SCENE_INGAME_PATH)
