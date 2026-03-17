extends Node2D

@onready var stars_root: Node2D = $SystemView/Stars
@onready var planet_renderer: PlanetRenderer = $SystemView/PlanetRenderer
@onready var moon_renderer: MoonRenderer = $SystemView/MoonRenderer
@onready var map_camera = $MapCamera

var _star_visuals: Array[StarVisual] = []


func _ready():
	if not GameSession.game_started:
		return

	var system = GameSession.get_random_system()
	if system == null:
		return

	GameSession.enter_system(system)
	_build_system_view(system)


func _process(delta:float) -> void:
	var system = GameSession.current_system
	if system == null:
		return

	SystemSimulator.update_system(system, delta)
	_refresh_system_view(system)


func _build_system_view(system:SystemData) -> void:
	for child in stars_root.get_children():
		child.queue_free()

	_star_visuals.clear()

	for star in system.stars:
		var visual := StarVisual.new()
		visual.initialize(star)
		stars_root.add_child(visual)
		_star_visuals.append(visual)

	planet_renderer.build(system.planets)
	moon_renderer.build(system.planets)

	_refresh_system_view(system)


func _refresh_system_view(system:SystemData) -> void:
	for i in _star_visuals.size():
		var star = system.stars[i]
		var pos = Vector2(
			star.orbit_radius * cos(star.orbit_angle),
			star.orbit_radius * sin(star.orbit_angle)
		)
		_star_visuals[i].set_world_position(pos)

	var camera_zoom = map_camera.camera.zoom.x
	planet_renderer.refresh(camera_zoom)
	moon_renderer.refresh(camera_zoom)
