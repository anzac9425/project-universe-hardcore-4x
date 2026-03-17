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

	system.stars = _generate_stars_for_system(system.system_seed, star_count)
	system.planets = _generate_planets(system.system_seed)

	system.generated = true


static func _generate_stars_for_system(system_seed:int, star_count:int) -> Array[StarData]:
	var stars: Array[StarData] = []

	for i in star_count:
		var star_seed = derive_seed(system_seed, i)
		stars.append(_generate_star(star_seed))

	if star_count == 1:
		stars[0].orbit_radius = 0.0
		stars[0].orbital_speed = 0.0
	elif star_count == 2:
		var binary_radius = 45.0
		stars[0].orbit_radius = binary_radius
		stars[1].orbit_radius = binary_radius
		stars[0].orbit_angle = 0.0
		stars[1].orbit_angle = PI
		stars[0].orbital_speed = 0.12
		stars[1].orbital_speed = 0.12
	elif star_count == 3:
		# Inner binary + outer companion layout for improved stability.
		stars[0].orbit_radius = 35.0
		stars[1].orbit_radius = 35.0
		stars[0].orbit_angle = 0.0
		stars[1].orbit_angle = PI
		stars[0].orbital_speed = 0.18
		stars[1].orbital_speed = 0.18

		stars[2].orbit_radius = 120.0
		stars[2].orbit_angle = PI * 0.6
		stars[2].orbital_speed = 0.05

	return stars
	
static func _generate_star(star_seed:int) -> StarData:

	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed

	var star := StarData.new()
	star.seed = star_seed

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
	star.orbit_radius = 0.0
	star.orbit_angle = rng.randf_range(0,TAU)
	star.orbital_speed = rng.randf_range(0.02, 0.12)

	return star
	
static func _generate_planets(system_seed:int) -> Array[PlanetData]:

	var rng := RandomNumberGenerator.new()
	rng.seed = derive_seed(system_seed, 999)

	var planets: Array[PlanetData] = []

	var orbit := 220.0

	var planet_count = rng.randi_range(0,10)

	for i in planet_count:

		var planet := PlanetData.new()

		planet.planet_seed = derive_seed(system_seed, 1000 + i)

		orbit += rng.randf_range(120,300)

		planet.orbit_radius = orbit
		planet.orbit_angle = rng.randf_range(0, TAU)
		planet.orbital_speed = rng.randf_range(0.01, 0.08)
		planet.size = rng.randf_range(20,80)

		planet.type = _roll_planet_type(rng) as PlanetData.PlanetType
		planet.moons = _generate_moons(planet.planet_seed, planet.size)

		planets.append(planet)

	return planets


static func _generate_moons(planet_seed:int, planet_size:float) -> Array[MoonData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = derive_seed(planet_seed, 77)

	var moon_count = rng.randi_range(0, 4)
	var orbit = max(planet_size * 0.9, 24.0)
	var moons: Array[MoonData] = []

	for i in moon_count:
		var moon := MoonData.new()
		moon.moon_seed = derive_seed(planet_seed, 200 + i)
		orbit += rng.randf_range(15.0, 40.0)
		moon.orbit_radius = orbit
		moon.orbit_angle = rng.randf_range(0, TAU)
		moon.orbital_speed = rng.randf_range(0.05, 0.22)
		moon.size = rng.randf_range(4.0, max(8.0, planet_size * 0.25))
		moons.append(moon)

	return moons

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
