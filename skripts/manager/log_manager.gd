extends Node

var logs: Array = []


func print_log(msg: String) -> void:
	var time: float = Time.get_ticks_usec() / 1_000_000.0
	var formatted: String = "[%.3fs] %s" % [time, msg]
	logs.append(formatted)
	print(formatted)


func log_system_data(system: SystemData) -> void:
	if system == null:
		print_log("ERR_LOG_SYSTEM_NULL")
		return

	var bodies: Array[Resource] = system.get_bodies()
	print_log(
		"SYSTEM seed=%d pos=(%.1f, %.1f) generated=%s stars=%d planets=%d belts=%d bodies=%d" % [
			system.system_seed,
			system.position.x,
			system.position.y,
			str(system.generated),
			system.stars.size(),
			system.planets.size(),
			system.asteroid_belts.size(),
			bodies.size()
		]
	)

	for i in range(system.stars.size()):
		var star: StarData = system.stars[i]
		print_log(
			"STAR[%d] seed=%d spectral=%s mass_solar=%.6f luminosity_solar=%.6f temperature_k=%.3f radius_solar=%.6f habitable_zone_inner_au=%.6f habitable_zone_outer_au=%.6f snow_line_au=%.6f hot_zone_au=%.6f" % [
				i,
				star.star_seed,
				StarData.StarType.keys()[star.spectral_type],
				star.mass_solar,
				star.luminosity_solar,
				star.temperature_k,
				star.radius_solar,
				star.habitable_zone_inner_au,
				star.habitable_zone_outer_au,
				star.snow_line_au,
				star.hot_zone_au
			]
		)

	for i in range(system.planets.size()):
		var planet: PlanetData = system.planets[i]
		print_log(
			"PLANET[%d] seed=%d name=%s type=%s mass_earth=%.6f radius_earth=%.6f temperature_k=%.3f composition=%s moons=%d" % [
				i,
				planet.planet_seed,
				planet.name,
				PlanetData.PlanetType.keys()[planet.type],
				planet.mass_earth,
				planet.radius_earth,
				planet.temperature_k,
				planet.composition,
				planet.moons.size()
			]
		)
		_log_orbit_data("PLANET[%d].ORBIT" % i, planet.orbit)

		for moon_index in range(planet.moons.size()):
			var moon: MoonData = planet.moons[moon_index]
			print_log(
				"MOON[%d,%d] seed=%d name=%s type=%s mass_earth=%.6f radius_earth=%.6f temperature_k=%.3f composition=%s" % [
					i,
					moon_index,
					moon.moon_seed,
					moon.name,
					MoonData.MoonType.keys()[moon.type],
					moon.mass_earth,
					moon.radius_earth,
					moon.temperature_k,
					moon.composition
				]
			)
			_log_orbit_data("MOON[%d,%d].ORBIT" % [i, moon_index], moon.orbit)

	for i in range(system.asteroid_belts.size()):
		var belt: AsteroidBeltData = system.asteroid_belts[i]
		print_log(
			"BELT[%d] seed=%d name=%s width_au=%.6f mass_earth=%.6f dominant_material=%s resonance_tag=%s" % [
				i,
				belt.belt_seed,
				belt.name,
				belt.width_au,
				belt.mass_earth,
				belt.dominant_material,
				belt.resonance_tag
			]
		)
		_log_orbit_data("BELT[%d].ORBIT" % i, belt.orbit)


func _log_orbit_data(label: String, orbit: OrbitData) -> void:
	if orbit == null:
		print_log("%s null" % label)
		return

	print_log(
		"%s semi_major_axis_au=%.6f eccentricity=%.6f inclination_rad=%.6f argument_of_periapsis_rad=%.6f longitude_of_ascending_node_rad=%.6f mean_anomaly_at_epoch_rad=%.6f period_days=%.6f mean_motion_rad_per_day=%.6f phase_offset_rad=%.6f" % [
			label,
			orbit.semi_major_axis_au,
			orbit.eccentricity,
			orbit.inclination_rad,
			orbit.argument_of_periapsis_rad,
			orbit.longitude_of_ascending_node_rad,
			orbit.mean_anomaly_at_epoch_rad,
			orbit.period_days,
			orbit.mean_motion_rad_per_day,
			orbit.phase_offset_rad
		]
	)
