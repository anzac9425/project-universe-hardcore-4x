extends Control
class_name StarUI

@export var close_button: Control
@export var star_name: Label
@export var planet_ui_element: PackedScene
@export var planet_container: Control

func _ready() -> void:
	close_button.gui_input.connect(handle_close)

func handle_close(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			visible = false

func populate_star_info(star: Star) -> void:
	for n: Node in planet_container.get_children():
		n.queue_free()

	PRNG.seed_with_u64(star.get_star_seed())
	star_name.text = star.get_star_name()
	var last_dist: float = 0.0
	for i in range(star.get_planet_count()):
		var p: PlanetUIElement = planet_ui_element.instantiate()
		last_dist = p.generate(last_dist)
		planet_container.add_child(p)
