extends Node2D

@export var base_seed: int = 112219
# 1122: 61.63MW, 
@export var base_n_star: int = 10_00

func _on_start_button_pressed() -> void:
	var config = GameConfig.new()
	
	config.base_seed = base_seed
	config.base_n_star = base_n_star
	
	GameSession.start_new_game(config)
	SceneManager.change_scene_with_loading(C.SCENE_INGAME_PATH)
