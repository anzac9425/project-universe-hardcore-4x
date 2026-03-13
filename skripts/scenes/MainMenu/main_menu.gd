extends Node2D

const START_SCENE_PATH := "res://scenes/Ingame.tscn"

@export var start_seed := 1
@export var system_count := 100
@export var difficulty: int = GameConfig.Difficulty.EASY

func _on_start_button_pressed() -> void:
	var config = GameConfig.new()

	config.world_seed = start_seed
	config.system_count = system_count
	config.difficulty = difficulty

	GameSession.start_new_game(config)

	SceneManager.change_scene_with_loading(START_SCENE_PATH)
