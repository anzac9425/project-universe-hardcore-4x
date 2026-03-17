extends RefCounted
class_name SystemSimulator


static func update_system(system:SystemData, delta:float) -> void:
	if system == null:
		return

	for star in system.stars:
		star.orbit_angle += delta * star.orbital_speed

	for planet in system.planets:
		planet.orbit_angle += delta * planet.orbital_speed

		for moon in planet.moons:
			moon.orbit_angle += delta * moon.orbital_speed
