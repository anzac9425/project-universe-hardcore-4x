extends Node

var logs : Array = []


func print_log(msg: String) -> void:
	var time: float = Time.get_ticks_usec() / 1_000_000.0
	var formatted: String = "[%.3fs] %s" % [time, msg]
	logs.append(formatted)
	print(formatted)


func log_system_data(system: SystemData) -> void:
	if system == null:
		print_log("ERR_LOG_SYSTEM_NULL")
		return

	print_log(
		"SYSTEM seed=%d pos=(%.1f, %.1f) generated=%s stars=%d planets=%d belts=%d" % [
			system.system_seed,
			system.position.x,
			system.position.y,
			str(system.generated),
			system.stars.size(),
			system.planets.size(),
			system.asteroid_belts.size()
		]
	)

	for i in range(system.stars.size()):
		var star: StarData = system.stars[i]
		print_log(
			"STAR[%d] type=%s mass=%.2fMsun temp=%.0fK radius=%.2fRsun luminosity=%.2fLsun hz=(%.2f-%.2f) snow=%.2f" % [
				i,
				StarData.StarType.keys()[star.spectral_type],
				star.mass_solar,
				star.temperature_k,
				star.radius_solar,
				star.luminosity_solar,
				star.habitable_zone_inner_au,
				star.habitable_zone_outer_au,
				star.snow_line_au
			]
		)

	for i in range(system.planets.size()):
		var planet: PlanetData = system.planets[i]
		print_log(
			"PLANET[%d] seed=%d type=%s mass=%.2fMe radius=%.2fRe temp=%.0fK a=%.2fAU e=%.3f moons=%d" % [
				i,
				planet.planet_seed,
				PlanetData.PlanetType.keys()[planet.type],
				planet.mass_earth,
				planet.radius_earth,
				planet.temperature_k,
				planet.orbit.semi_major_axis_au,
				planet.orbit.eccentricity,
				planet.moons.size()
			]
		)

	for i in range(system.asteroid_belts.size()):
		var belt: AsteroidBeltData = system.asteroid_belts[i]
		print_log(
			"BELT[%d] seed=%d mass=%.2fMe a=%.2fAU width=%.2fAU resonance=%s" % [
				i,
				belt.belt_seed,
				belt.mass_earth,
				belt.orbit.semi_major_axis_au,
				belt.width_au,
				belt.resonance_tag
			]
		)
