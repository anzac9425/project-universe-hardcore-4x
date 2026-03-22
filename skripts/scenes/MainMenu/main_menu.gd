extends Node2D

const START_SCENE_PATH := "res://scenes/Ingame.tscn"
const SEED_SEARCH_WINDOW := 128
const PREVIEW_SAMPLE_SYSTEMS := 24
const STAR_TYPE_LABELS := {
	StarData.StarType.O: "O",
	StarData.StarType.B: "B",
	StarData.StarType.A: "A",
	StarData.StarType.F: "F",
	StarData.StarType.G: "G",
	StarData.StarType.K: "K",
	StarData.StarType.M: "M"
}

@export var start_seed := 1
@export var system_count := 100
@export var difficulty: int = GameConfig.Difficulty.EASY

@onready var seed_spin_box: SpinBox = $UI/PanelContainer/MarginContainer/VBoxContainer/SeedRow/SeedSpinBox
@onready var preview_label: Label = $UI/PanelContainer/MarginContainer/VBoxContainer/PreviewLabel
@onready var finder_status_label: Label = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderStatusLabel

func _ready() -> void:
	_sync_seed_ui()
	_refresh_seed_preview()

func _on_start_button_pressed() -> void:
	var config = GameConfig.new()

	config.world_seed = start_seed
	config.system_count = system_count
	config.difficulty = difficulty

	GameSession.start_new_game(config)

	SceneManager.change_scene_with_loading(START_SCENE_PATH)


func _on_seed_spin_box_value_changed(value: float) -> void:
	start_seed = int(value)
	_refresh_seed_preview()


func _on_prev_seed_button_pressed() -> void:
	start_seed -= 1
	_sync_seed_ui()
	_refresh_seed_preview()


func _on_next_seed_button_pressed() -> void:
	start_seed += 1
	_sync_seed_ui()
	_refresh_seed_preview()


func _on_random_seed_button_pressed() -> void:
	start_seed = int(Time.get_unix_time_from_system())
	_sync_seed_ui()
	_refresh_seed_preview()


func _on_preview_button_pressed() -> void:
	_refresh_seed_preview()


func _on_find_seed_button_pressed() -> void:
	var result: Dictionary = _find_next_seed_with_habitable_candidate(start_seed + 1, SEED_SEARCH_WINDOW)
	if result.is_empty():
		finder_status_label.text = "No life-friendly seed found in the next %d seeds." % SEED_SEARCH_WINDOW
		return

	start_seed = result["seed"]
	_sync_seed_ui()
	finder_status_label.text = "Found seed %d with %d candidate worlds." % [
		result["seed"],
		result["habitable_candidates"]
	]
	_refresh_seed_preview(result)


func _sync_seed_ui() -> void:
	seed_spin_box.value = start_seed


func _refresh_seed_preview(summary: Dictionary = {}) -> void:
	var preview: Dictionary = summary
	if preview.is_empty():
		var config: GameConfig = _build_preview_config()
		preview = MapGenerator.analyze_seed(
			start_seed,
			config.system_count,
			config.min_system_distance,
			config.galaxy_radius,
			PREVIEW_SAMPLE_SYSTEMS
		)

	preview_label.text = _format_seed_preview(preview)


func _find_next_seed_with_habitable_candidate(first_seed: int, search_window: int) -> Dictionary:
	var config: GameConfig = _build_preview_config()
	for seed in range(first_seed, first_seed + search_window):
		var summary: Dictionary = MapGenerator.analyze_seed(
			seed,
			config.system_count,
			config.min_system_distance,
			config.galaxy_radius,
			PREVIEW_SAMPLE_SYSTEMS
		)
		if summary["habitable_candidates"] > 0:
			return summary

	return {}


func _build_preview_config() -> GameConfig:
	var config := GameConfig.new()
	config.system_count = system_count
	return config


func _format_seed_preview(summary: Dictionary) -> String:
	var star_type: String = STAR_TYPE_LABELS.get(summary["first_star_type"], "?")
	var best_system_text := "none"
	if summary["best_system_index"] >= 0:
		best_system_text = "#%d / planets %d / belts %d / candidates %d" % [
			int(summary["best_system_index"]) + 1,
			summary["best_system_planet_count"],
			summary["best_system_belt_count"],
			summary["best_system_habitable_candidates"]
		]

	return "\n".join([
		"Seed %d preview (%d sampled systems)" % [summary["seed"], summary["sampled_systems"]],
		"First star: type %s / %.0f K" % [star_type, summary["first_star_temperature_k"]],
		"Planets: %d  |  Moons: %d  |  Belts: %d" % [
			summary["planet_count"],
			summary["moon_count"],
			summary["belt_count"]
		],
		"Life-friendly candidates: %d" % summary["habitable_candidates"],
		"Best sampled system: %s" % best_system_text
	])
