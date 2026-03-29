extends Node2D

@export var base_seed: int = 12345678910
@export var galaxy_type: int = 0

@export var system_count: int = 1000
@export var min_system_distance: float = 5.0
@export var galaxy_radius: float = 1000.0

func _on_start_button_pressed() -> void:
	var config = GameConfig.new()
	
	config.base_seed = base_seed
	
	config.system_count = system_count
	config.min_system_distance = min_system_distance
	config.galaxy_radius = galaxy_radius
	config.Rd = galaxy_radius * C.RD_MTP
	
	GameSession.start_new_game(config)
	SceneManager.change_scene_with_loading(C.SCENE_INGAME_PATH)
