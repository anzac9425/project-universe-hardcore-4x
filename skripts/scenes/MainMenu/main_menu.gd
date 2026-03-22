extends Node2D

const START_SCENE_PATH := "res://scenes/Ingame.tscn"
const DEFAULT_SEED_SEARCH_WINDOW := 128
const PREVIEW_SAMPLE_SYSTEMS := 24
const ANY_STAR_TYPE := -1
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
@onready var search_window_spin_box: SpinBox = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderControls/SearchWindowSpinBox
@onready var star_type_option_button: OptionButton = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderControls/StarTypeOptionButton
@onready var min_planets_spin_box: SpinBox = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderControls/MinPlanetsSpinBox
@onready var min_moons_spin_box: SpinBox = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderControls/MinMoonsSpinBox
@onready var min_belts_spin_box: SpinBox = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderControls/MinBeltsSpinBox
@onready var min_habitable_spin_box: SpinBox = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderControls/MinHabitableSpinBox
@onready var min_rocky_spin_box: SpinBox = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderControls/MinRockySpinBox
@onready var min_ocean_spin_box: SpinBox = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderControls/MinOceanSpinBox
@onready var min_ice_spin_box: SpinBox = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderControls/MinIceSpinBox
@onready var min_gas_giant_spin_box: SpinBox = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderControls/MinGasGiantSpinBox
@onready var min_ice_giant_spin_box: SpinBox = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderControls/MinIceGiantSpinBox
@onready var preview_label: Label = $UI/PanelContainer/MarginContainer/VBoxContainer/PreviewLabel
@onready var finder_status_label: Label = $UI/PanelContainer/MarginContainer/VBoxContainer/FinderStatusLabel

func _ready() -> void:
	_setup_finder_controls()
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
	var criteria: Dictionary = _build_finder_criteria()
	var result: Dictionary = _find_next_matching_seed(
		start_seed + 1,
		int(search_window_spin_box.value),
		criteria
	)
	if result.is_empty():
		finder_status_label.text = "No seed matched all selected criteria in the next %d seeds." % int(search_window_spin_box.value)
		return

	start_seed = result["seed"]
	_sync_seed_ui()
	finder_status_label.text = "Found seed %d matching: %s" % [result["seed"], _format_finder_criteria(criteria)]
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


func _find_next_matching_seed(first_seed: int, search_window: int, criteria: Dictionary) -> Dictionary:
	var config: GameConfig = _build_preview_config()
	for seed in range(first_seed, first_seed + search_window):
		var summary: Dictionary = MapGenerator.analyze_seed(
			seed,
			config.system_count,
			config.min_system_distance,
			config.galaxy_radius,
			PREVIEW_SAMPLE_SYSTEMS
		)
		if _summary_matches_criteria(summary, criteria):
			return summary

	return {}


func _build_preview_config() -> GameConfig:
	var config := GameConfig.new()
	config.system_count = system_count
	return config


func _setup_finder_controls() -> void:
	search_window_spin_box.value = DEFAULT_SEED_SEARCH_WINDOW
	star_type_option_button.clear()
	star_type_option_button.add_item("Any Star", ANY_STAR_TYPE)
	for star_type in [
		StarData.StarType.O,
		StarData.StarType.B,
		StarData.StarType.A,
		StarData.StarType.F,
		StarData.StarType.G,
		StarData.StarType.K,
		StarData.StarType.M
	]:
		star_type_option_button.add_item("%s Star" % STAR_TYPE_LABELS[star_type], star_type)


func _build_finder_criteria() -> Dictionary:
	return {
		"star_type": star_type_option_button.get_selected_id(),
		"min_planets": int(min_planets_spin_box.value),
		"min_moons": int(min_moons_spin_box.value),
		"min_belts": int(min_belts_spin_box.value),
		"min_habitable": int(min_habitable_spin_box.value),
		"min_rocky": int(min_rocky_spin_box.value),
		"min_ocean": int(min_ocean_spin_box.value),
		"min_ice": int(min_ice_spin_box.value),
		"min_gas_giants": int(min_gas_giant_spin_box.value),
		"min_ice_giants": int(min_ice_giant_spin_box.value)
	}


func _summary_matches_criteria(summary: Dictionary, criteria: Dictionary) -> bool:
	if criteria["star_type"] != ANY_STAR_TYPE and summary["first_star_type"] != criteria["star_type"]:
		return false

	if summary["planet_count"] < criteria["min_planets"]:
		return false
	if summary["moon_count"] < criteria["min_moons"]:
		return false
	if summary["belt_count"] < criteria["min_belts"]:
		return false
	if summary["habitable_candidates"] < criteria["min_habitable"]:
		return false
	if summary["rocky_planets"] < criteria["min_rocky"]:
		return false
	if summary["ocean_planets"] < criteria["min_ocean"]:
		return false
	if summary["ice_planets"] < criteria["min_ice"]:
		return false
	if summary["gas_giants"] < criteria["min_gas_giants"]:
		return false
	if summary["ice_giants"] < criteria["min_ice_giants"]:
		return false

	return true


func _format_finder_criteria(criteria: Dictionary) -> String:
	var tokens: Array[String] = []
	if criteria["star_type"] != ANY_STAR_TYPE:
		tokens.append("%s star" % STAR_TYPE_LABELS.get(criteria["star_type"], "?"))

	var labeled_thresholds := [
		{"value": criteria["min_planets"], "label": "planets"},
		{"value": criteria["min_moons"], "label": "moons"},
		{"value": criteria["min_belts"], "label": "belts"},
		{"value": criteria["min_habitable"], "label": "habitable"},
		{"value": criteria["min_rocky"], "label": "rocky"},
		{"value": criteria["min_ocean"], "label": "ocean"},
		{"value": criteria["min_ice"], "label": "ice"},
		{"value": criteria["min_gas_giants"], "label": "gas giants"},
		{"value": criteria["min_ice_giants"], "label": "ice giants"}
	]
	for entry in labeled_thresholds:
		if entry["value"] > 0:
			tokens.append("%d+ %s" % [entry["value"], entry["label"]])

	if tokens.is_empty():
		return "no filters (first sampled seed)"

	return ", ".join(tokens)


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
		"Rocky: %d  |  Ocean: %d  |  Ice: %d" % [
			summary["rocky_planets"],
			summary["ocean_planets"],
			summary["ice_planets"]
		],
		"Gas giants: %d  |  Ice giants: %d" % [
			summary["gas_giants"],
			summary["ice_giants"]
		],
		"Life-friendly candidates: %d" % summary["habitable_candidates"],
		"Best sampled system: %s" % best_system_text
	])
