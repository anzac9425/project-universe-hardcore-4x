extends Node
class_name MapGenerator

static func derive_seed(parent:int, index:int) -> int:
	var h = hash(str(parent) + ":" + str(index))
	return abs(h)
	
static func _roll_star_count(rng:RandomNumberGenerator) -> int:

	var r = rng.randf()

	if r < 0.7:
		return 1
	elif r < 0.95:
		return 2
	else:
		return 3
		
static func _roll_star_type(rng:RandomNumberGenerator) -> StarData.StarType:

	var r = rng.randf()

	if r < 0.0003:
		return StarData.StarType.O
	elif r < 0.002:
		return StarData.StarType.B
	elif r < 0.01:
		return StarData.StarType.A
	elif r < 0.04:
		return StarData.StarType.F
	elif r < 0.10:
		return StarData.StarType.G
	elif r < 0.25:
		return StarData.StarType.K
	else:
		return StarData.StarType.M
		
static func _roll_planet_type(rng:RandomNumberGenerator) -> PlanetData.PlanetType:

	var r = rng.randf()

	if r < 0.30:
		return PlanetData.PlanetType.ROCKY
	elif r < 0.45:
		return PlanetData.PlanetType.DESERT
	elif r < 0.60:
		return PlanetData.PlanetType.OCEAN
	elif r < 0.80:
		return PlanetData.PlanetType.GAS_GIANT
	elif r < 0.90:
		return PlanetData.PlanetType.ICE
	else:
		return PlanetData.PlanetType.LAVA
	
static func generate_galaxy(
	galaxy_seed:int,
	system_count:int,
	min_distance:float,
	radius:float
) -> GalaxyData:

	var rng := RandomNumberGenerator.new()
	rng.seed = galaxy_seed

	var galaxy := GalaxyData.new()
	galaxy.galaxy_seed = galaxy_seed

	var positions = _generate_system_positions(
		rng,
		system_count,
		min_distance,
		radius
	)

	for i in positions.size():

		var system := SystemData.new()

		system.position = positions[i]
		system.system_seed = derive_seed(galaxy_seed, i)

		galaxy.systems.append(system)

	return galaxy
	
static func generate_system(system:SystemData) -> void:

	if system.generated:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = system.system_seed

	var star_count = _roll_star_count(rng)

	for i in star_count:

		var star_seed = derive_seed(system.system_seed, i)

		system.stars.append(
			_generate_star(star_seed, i)
		)

	system.planets = _generate_planets(system.system_seed)

	system.generated = true
	
static func _generate_star(star_seed:int, _index:int) -> StarData:

	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed

	var star := StarData.new()

	star.type = _roll_star_type(rng) as StarData.StarType

	match star.type:

		StarData.StarType.O:
			star.temperature = rng.randf_range(30000,50000)
			star.radius = rng.randf_range(6,15)

		StarData.StarType.B:
			star.temperature = rng.randf_range(10000,30000)
			star.radius = rng.randf_range(3,7)

		StarData.StarType.A:
			star.temperature = rng.randf_range(7500,10000)
			star.radius = rng.randf_range(1.7,2.5)

		StarData.StarType.F:
			star.temperature = rng.randf_range(6000,7500)
			star.radius = rng.randf_range(1.3,1.7)

		StarData.StarType.G:
			star.temperature = rng.randf_range(5200,6000)
			star.radius = rng.randf_range(0.96,1.15)

		StarData.StarType.K:
			star.temperature = rng.randf_range(3700,5200)
			star.radius = rng.randf_range(0.7,0.96)

		StarData.StarType.M:
			star.temperature = rng.randf_range(2400,3700)
			star.radius = rng.randf_range(0.1,0.7)

	star.luminosity = pow(star.radius,2) * pow(star.temperature/5778.0,4)

	star.orbit_radius = rng.randf_range(0,50)
	star.orbit_angle = rng.randf_range(0,TAU)

	return star
	
static func _generate_planets(system_seed:int) -> Array[PlanetData]:

	var rng := RandomNumberGenerator.new()
	rng.seed = derive_seed(system_seed, 999)

	var planets: Array[PlanetData] = []

	var orbit := 200.0

	var planet_count = rng.randi_range(0,10)

	for i in planet_count:

		var planet := PlanetData.new()

		planet.planet_seed = derive_seed(system_seed, 1000 + i)

		orbit += rng.randf_range(120,300)

		planet.orbit_radius = orbit

		planet.size = rng.randf_range(20,80)

		planet.type = _roll_planet_type(rng) as PlanetData.PlanetType

		planets.append(planet)

	return planets

static func _generate_system_positions(
	rng:RandomNumberGenerator,
	count:int,
	min_distance:float,
	radius:float
) -> Array:

	var points:Array = []
	var attempts := 0

	while points.size() < count and attempts < count * 40:

		var pos = Vector2(
			rng.randf_range(-radius,radius),
			rng.randf_range(-radius,radius)
		)

		if pos.length() > radius:
			continue

		var valid := true

		for p in points:
			if pos.distance_to(p) < min_distance:
				valid = false
				break

		if valid:
			points.append(pos)

		attempts += 1

	return points
