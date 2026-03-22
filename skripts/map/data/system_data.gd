extends Resource
class_name SystemData

var system_seed: int
var position: Vector2

var generated: bool = false

var stars: Array[StarData] = []
var planets: Array[PlanetData] = []
var asteroid_belts: Array[AsteroidBeltData] = []


func get_bodies() -> Array[Resource]:
	var bodies: Array[Resource] = []
	for planet in planets:
		bodies.append(planet)
	for belt in asteroid_belts:
		bodies.append(belt)
	return bodies
