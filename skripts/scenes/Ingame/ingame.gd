extends Node

func _ready():

	if not GameSession.game_started:
		return

	var system = GameSession.get_random_system()

	GameSession.enter_system(system)
