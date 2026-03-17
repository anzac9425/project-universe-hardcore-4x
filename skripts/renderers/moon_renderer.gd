extends MultiMeshInstance2D
class_name MoonRenderer


var _moon_entries: Array = []
static var _white_texture: Texture2D


func build(planets:Array[PlanetData]) -> void:
	_moon_entries.clear()

	for planet in planets:
		for moon in planet.moons:
			_moon_entries.append({
				"planet": planet,
				"moon": moon
			})

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.color_format = MultiMesh.COLOR_FLOAT
	mm.instance_count = _moon_entries.size()

	for i in _moon_entries.size():
		var moon: MoonData = _moon_entries[i]["moon"]
		mm.set_instance_color(i, Color("#c9ced8"))
		_update_instance_transform(mm, i, _moon_entries[i]["planet"], moon)

	multimesh = mm
	texture = _shared_white_texture()


func refresh(camera_zoom:float) -> void:
	if multimesh == null:
		return

	var lod = _lod_from_zoom(camera_zoom)
	visible = lod < 4

	if not visible:
		return

	for i in _moon_entries.size():
		var entry = _moon_entries[i]
		_update_instance_transform(multimesh, i, entry["planet"], entry["moon"])

	material = PlanetMaterialManager.get_material(1, min(lod + 1, 3))


func _update_instance_transform(mm:MultiMesh, index:int, planet:PlanetData, moon:MoonData) -> void:
	var planet_position = Vector2(
		planet.orbit_radius * cos(planet.orbit_angle),
		planet.orbit_radius * sin(planet.orbit_angle)
	)

	var moon_position = Vector2(
		moon.orbit_radius * cos(moon.orbit_angle),
		moon.orbit_radius * sin(moon.orbit_angle)
	)

	var transform := Transform2D()
	transform = transform.scaled(Vector2.ONE * max(2.0, moon.size * 0.25))
	transform.origin = planet_position + moon_position

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


func _shared_white_texture() -> Texture2D:
	if _white_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white_texture = ImageTexture.create_from_image(image)

	return _white_texture
