extends Node2D

const SYSTEM_DOT_RADIUS := 60.0
const GALAXY_CENTER_COLOR := Color("ffd166")
const SYSTEM_COLOR := Color("74c0fc")


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if GameSession.galaxy == null:
		Log.error(ERR_CODE.GAMESESSION_GALAXY_NULL, "Galaxy data is null")
		return

	draw_circle(Vector2.ZERO, SYSTEM_DOT_RADIUS * 1.4, GALAXY_CENTER_COLOR)

	for system in GameSession.galaxy.systems:
		draw_circle(system.location, SYSTEM_DOT_RADIUS, SYSTEM_COLOR)
