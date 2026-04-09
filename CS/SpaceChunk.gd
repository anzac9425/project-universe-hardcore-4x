extends Node2D
class_name SpaceChunk

@export var coords_label: Label
@export var my_star: Star

func set_coords(coords: String) -> void:
	coords_label.text = coords
	PRNG.seed_with_string(coords)
	my_star.generate()
