extends MultiMeshInstance2D
class_name PlanetRenderer


var _planets: Array[PlanetData] = []


func build(planets:Array[PlanetData]) -> void:
	_planets = planets

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.color_format = MultiMesh.COLOR_FLOAT
	mm.instance_count = planets.size()

	for i in planets.size():
		var planet = planets[i]
		mm.set_instance_color(i, _planet_color(planet.type))
		_update_instance_transform(mm, i, planet)

	multimesh = mm
	texture = _shared_white_texture()


func refresh(camera_zoom:float) -> void:
	if multimesh == null:
		return

	var lod = _lod_from_zoom(camera_zoom)
	visible = lod < 4

	if not visible:
		return

	for i in _planets.size():
		_update_instance_transform(multimesh, i, _planets[i])

	material = PlanetMaterialManager.get_material(0, lod)


func _update_instance_transform(mm:MultiMesh, index:int, planet:PlanetData) -> void:
	var position = Vector2(
		planet.orbit_radius * cos(planet.orbit_angle),
		planet.orbit_radius * sin(planet.orbit_angle)
	)

	var transform := Transform2D()
	transform = transform.scaled(Vector2.ONE * max(4.0, planet.size * 0.2))
	transform.origin = position

	mm.set_instance_transform_2d(index, transform)


func _lod_from_zoom(zoom:float) -> int:
	if zoom > 2.0:
		return 0
	if zoom > 1.0:
		return 1
	if zoom > 0.5:
		return 2
	if zoom > 0.2:
		return 3
	return 4


func _planet_color(planet_type:PlanetData.PlanetType) -> Color:
	match planet_type:
		PlanetData.PlanetType.ROCKY:
			return Color("#9f8772")
		PlanetData.PlanetType.OCEAN:
			return Color("#4f7fd4")
		PlanetData.PlanetType.DESERT:
			return Color("#cfa35d")
		PlanetData.PlanetType.GAS_GIANT:
			return Color("#d4a98a")
		PlanetData.PlanetType.ICE:
			return Color("#b6dcff")
		PlanetData.PlanetType.LAVA:
			return Color("#e7682f")
		_:
			return Color.GRAY


func _shared_white_texture() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
