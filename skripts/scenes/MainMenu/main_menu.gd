extends Node2D

const START_SCENE_PATH := "res://scenes/Ingame.tscn"

var seed = 1
var system_count = 100
var difficulty = "EASY"

func _on_start_button_pressed() -> void:
	SceneManager.change_scene(START_SCENE_PATH)
	var config = GameConfig.new()

	config.seed = seed
	config.system_count = system_count
	config.difficulty = difficulty

	config.apply_difficulty()
	config.validate()

	#GameSession.config = config
