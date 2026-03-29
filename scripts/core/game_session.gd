extends Node

var config: GameConfig
var galaxy: GalaxyData

var current_system = SystemData
var game_started = false
var pause = false


func start_new_game(new_config: GameConfig):

	if new_config == null:
		Log.error(20, "")
		return

	config = new_config
	galaxy = MapGenerator.generate(
		config.base_seed
	)
	
	game_started = true


func enter_system(system: SystemData):

	if system == null:
		Log.error(21, "")
		return

	current_system = system

	Log.info("System Entered: %s" % [system])


func save_data() -> Dictionary:
	return {}


func load_data(data: Dictionary):
	pass
	
	
func reset():
	config = null
	galaxy = null
	
	game_started = false
