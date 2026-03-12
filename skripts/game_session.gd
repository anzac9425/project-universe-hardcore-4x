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

	current_system = system

	MapGenerator.generate_system(system)
	
func get_random_system() -> SystemData:

	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed

	var index = rng.randi_range(0, galaxy.systems.size()-1)

	return galaxy.systems[index]
	
func create_save_data() -> Dictionary:

	return {
		"config": config.to_dict(),
		"player": {},
		"current_system": galaxy.systems.find(current_system)
	}
	
func load_save_data(data:Dictionary):

	config = GameConfig.new()
	config.from_dict(data["config"])

	_generate_galaxy()

	var index = data.get("current_system",0)

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
