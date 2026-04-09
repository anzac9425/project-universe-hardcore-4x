extends VBoxContainer
class_name PlanetUIElement

@export var name_ui: Label
@export var planet_gfx: TextureRect
@export var distance_ui: Label

func generate(last_dist: float = 0.0) -> float:
	name_ui.text = Naming.generate_name()

	var noise_texture: NoiseTexture2D = NoiseTexture2D.new()
	noise_texture.seamless = true
	noise_texture.width = 64
	noise_texture.height = 64

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.frequency = 0.05
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX

	noise_texture.noise = noise
	(planet_gfx.material as ShaderMaterial).set_shader_parameter("noiseTex", noise_texture)
	(planet_gfx.material as ShaderMaterial).set_shader_parameter("rotationDirection", Vector2(PRNG.next_float(0, 1) * 2 - 1, PRNG.next_float(0, 1) * 2 - 1))
	(planet_gfx.material as ShaderMaterial).set_shader_parameter("waterlevel", PRNG.next_float(0.4, 0.6))
	(planet_gfx.material as ShaderMaterial).set_shader_parameter("groundColor", Color(
		PRNG.next_float(0.45, 0.9),
		PRNG.next_float(0.45, 0.9),
		PRNG.next_float(0.25, 0.33),
		1.0
	))

	(planet_gfx.material as ShaderMaterial).set_shader_parameter("waterColor", Color(
		PRNG.next_float(0.1, 2.0),
		PRNG.next_float(0.1, 1.0),
		PRNG.next_float(1.1, 3.0),
		1.0
	))

	var dist: float = last_dist + PRNG.next_float(3, 240)
	var units: String = " Light Hours" if dist >= 60 else " Light Minutes"
	distance_ui.text = (str(dist / 60) if dist >= 60 else str(dist)) + units
	return dist
