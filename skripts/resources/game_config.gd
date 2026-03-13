extends Resource
class_name GameConfig


# =========================
# Version
# =========================
var version: float = 0.0


# =========================
# Core
# =========================
var world_seed: int
var game_mode: int
var difficulty: int


# =========================
# Galaxy Settings
# =========================
var system_count: int
var galaxy_radius: float
var min_system_distance: float


# =========================
# Gameplay
# =========================
var ai_factions: int
var starting_resources: int


# =========================
# Constructor
# =========================
func _init():

	world_seed = int(Time.get_unix_time_from_system())

	game_mode = GameMode.SANDBOX
	difficulty = Difficulty.NORMAL

	system_count = 1000
	galaxy_radius = 10000
	min_system_distance = 200

	ai_factions = 5
	starting_resources = 1000

enum GameMode {
	SANDBOX,
	CAMPAIGN
}

enum Difficulty {
	EASY,
	NORMAL,
	HARD,
	INSANE
}

func validate():

	system_count = clamp(system_count, 10, 10000)

	galaxy_radius = max(galaxy_radius, 1000)

	min_system_distance = clamp(min_system_distance, 10, 1000)

	ai_factions = clamp(ai_factions, 0, 50)

	starting_resources = max(starting_resources, 0)

func apply_difficulty():

	match difficulty:

		Difficulty.EASY:
			ai_factions = 3
			starting_resources = 2000

		Difficulty.NORMAL:
			ai_factions = 5
			starting_resources = 1000

		Difficulty.HARD:
			ai_factions = 7
			starting_resources = 800

		Difficulty.INSANE:
			ai_factions = 10
			starting_resources = 500
			
func get_config_hash() -> int:

	var data = [
		world_seed,
		game_mode,
		difficulty,
		system_count,
		galaxy_radius,
		min_system_distance,
		ai_factions,
		starting_resources
	]

	return hash(str(data))
	
func to_dict() -> Dictionary:

	return {
		"version": version,
		"seed": world_seed,
		"game_mode": game_mode,
		"difficulty": difficulty,
		"system_count": system_count,
		"galaxy_radius": galaxy_radius,
		"min_system_distance": min_system_distance,
		"ai_factions": ai_factions,
		"starting_resources": starting_resources
	}
	
func from_dict(data:Dictionary):

	version = data.get("version", 1)

	world_seed = int(data.get("seed", 0))
	game_mode = data.get("game_mode", 0)
	difficulty = data.get("difficulty", 1)

	system_count = data.get("system_count", 1000)
	galaxy_radius = data.get("galaxy_radius", 10000)
	min_system_distance = data.get("min_system_distance", 200)

	ai_factions = data.get("ai_factions", 5)
	starting_resources = data.get("starting_resources", 1000)
