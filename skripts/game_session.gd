extends Node


# =========================
# Session State
# =========================

var config: GameConfig
var galaxy: GalaxyData

var current_system: SystemData


# =========================
# Gameplay State
# =========================

var player_faction
var factions := []


# =========================
# Runtime Flags
# =========================

var game_started := false
var paused := false

func start_new_game(new_config:GameConfig):

	if new_config == null:
		push_error("ERR_GAMESESSION_CONFIG_NULL")
		return

	config = new_config

	config.apply_difficulty()
	config.validate()

	_generate_galaxy()
	
func _generate_galaxy():

	galaxy = MapGenerator.generate_galaxy(
		config.seed,
		config.system_count,
		config.min_system_distance,
		config.galaxy_radius
	)

	game_started = true
	
func enter_system(system:SystemData):

	if system == null:
		push_error("ERR_GAMESESSION_SYSTEM_NULL")
		return

	current_system = system

	MapGenerator.generate_system(system)

func get_random_system() -> SystemData:

	if config == null:
		push_error("ERR_GAMESESSION_CONFIG_NOT_READY")
		return null

	if galaxy == null or galaxy.systems.is_empty():
		push_error("ERR_GAMESESSION_GALAXY_NOT_READY")
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	var index = rng.randi_range(0, galaxy.systems.size()-1)

	return galaxy.systems[index]
	
func create_save_data() -> Dictionary:

	if config == null or galaxy == null:
		push_error("ERR_GAMESESSION_SAVE_NOT_READY")
		return {}

	return {
		"config": config.to_dict(),
		"player": {},
		"current_system": galaxy.systems.find(current_system)
	}
	
func load_save_data(data:Dictionary):

	if not data.has("config"):
		push_error("ERR_GAMESESSION_SAVE_MISSING_CONFIG")
		return

	config = GameConfig.new()
	config.from_dict(data["config"])

	_generate_galaxy()

	if galaxy == null or galaxy.systems.is_empty():
		push_error("ERR_GAMESESSION_LOAD_EMPTY_GALAXY")
		return

	var index: int = data.get("current_system", 0)
	index = clamp(index, 0, galaxy.systems.size() - 1)

	current_system = galaxy.systems[index]

	MapGenerator.generate_system(current_system)

	game_started = true
	
func reset():

	config = null
	galaxy = null
	current_system = null

	player_faction = null
	factions.clear()

	game_started = false
