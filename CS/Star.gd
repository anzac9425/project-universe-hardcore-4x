extends Area2D
class_name Star

@export var gfx: Sprite2D

var max_xy_offset: float = 48
var star_seed: int
var name: String
var planets: int
var rotation_direction: Vector2

func generate() -> void:
	var scale_value: float = PRNG.next_float(0.25, 4)
	var x_off: float = PRNG.next_float(0, 1) * (max_xy_offset * 2) - max_xy_offset
	var y_off: float = PRNG.next_float(0, 1) * (max_xy_offset * 2) - max_xy_offset
	var c: Color = Color(PRNG.next_float(0.1, 1), PRNG.next_float(0.1, 1), PRNG.next_float(0.1, 1), 1)
	star_seed = PRNG.next_int()
	planets = PRNG.next_int(1, 12)
	rotation_direction = Vector2(PRNG.next_float(0, 1) * 2 - 1, PRNG.next_float(0, 1) * 2 - 1)
	name = Naming.generate_name()

	var noise_texture: NoiseTexture2D = NoiseTexture2D.new()
	noise_texture.seamless = true
	noise_texture.width = 64
	noise_texture.height = 64

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = star_seed
	noise.frequency = 0.1
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR

	noise_texture.noise = noise
	(gfx.material as ShaderMaterial).set_shader_parameter("noiseTex", noise_texture)
	(gfx.material as ShaderMaterial).set_shader_parameter("rotationDirection", rotation_direction)
	gfx.modulate = c

	position += Vector2.DOWN * x_off
	position += Vector2.RIGHT * y_off
	scale *= scale_value

func _input_event(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and not SpaceSceneManager.instance.is_ui_open():
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
			SpaceSceneManager.instance.open_star_ui(self)

func get_star_seed() -> int:
	return star_seed

func get_planet_count() -> int:
	return planets

func get_star_name() -> String:
	return name
