extends Node2D

const START_SCENE_PATH := "res://scenes/Ingame.tscn"

func _on_start_button_pressed() -> void:
	SceneManager.change_scene(START_SCENE_PATH)
