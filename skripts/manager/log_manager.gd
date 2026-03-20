extends Node

var logs : Array = []


func print_log(msg: String) -> void:
	var time := Time.get_ticks_usec() / 1_000_000.0
	var formatted := "[%.3fs] %s" % [time, msg]
	logs.append(formatted)
	print(formatted)


func log_system_data(system: SystemData) -> void:
	if system == null:
		print_log("ERR_LOG_SYSTEM_NULL")
		return

	print_log(
		"SYSTEM seed=%d pos=(%.1f, %.1f) generated=%s stars=%d planets=%d" % [
			system.system_seed,
			system.position.x,
			system.position.y,
			str(system.generated),
			system.stars.size(),
			system.planets.size()
		]
	)

	for i in range(system.stars.size()):
		var star := system.stars[i]
		print_log(
			"STAR[%d] type=%s temp=%.1f radius=%.2f luminosity=%.2f orbit_radius=%.1f orbit_angle=%.3f" % [
				i,
				StarData.StarType.keys()[star.type],
				star.temperature,
				star.radius,
				star.luminosity,
				star.orbit_radius,
				star.orbit_angle
			]
		)

	for i in range(system.planets.size()):
		var planet := system.planets[i]
		print_log(
			"PLANET[%d] seed=%d type=%s orbit_radius=%.1f orbit_angle=%.3f size=%.1f" % [
				i,
				planet.planet_seed,
				PlanetData.PlanetType.keys()[planet.type],
				planet.orbit_radius,
				planet.orbit_angle,
				planet.size
			]
		)
