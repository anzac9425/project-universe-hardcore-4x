extends Node
class_name MapGenerator

const SOLAR_MASS_TO_EARTH_MASS: float = 332_946.0
const EARTH_RADIUS_TO_AU: float = 4.26352e-5
const GOLDEN_ANGLE: float = 2.399963229728653


static func derive_seed(parent: int, index: int) -> int:
	return _hash_int(parent, "seed:%d" % index)


static func generate_galaxy(
	galaxy_seed: int,
	system_count: int,
	min_distance: float,
	radius: float
) -> GalaxyData:
	var galaxy: GalaxyData = GalaxyData.new()
	galaxy.galaxy_seed = galaxy_seed
	galaxy.systems = _generate_system_shell(galaxy_seed, system_count, min_distance, radius)
	return galaxy


static func generate_system(system: SystemData) -> void:
	if system == null or system.generated:
		return

	var star_seed: int = derive_seed(system.system_seed, 0)
	var star: StarData = _generate_star(star_seed)
	var formation: Dictionary = _generate_planetary_architecture(system.system_seed, star)
	var stars: Array[StarData] = []
	var planets: Array[PlanetData] = formation["planets"]
	var belts: Array[AsteroidBeltData] = formation["belts"]

	stars.append(star)
	system.stars = stars
	system.planets = planets
	system.asteroid_belts = belts
	system.generated = true


static func analyze_seed(
	galaxy_seed: int,
	system_count: int,
	min_distance: float,
	radius: float,
	sample_limit: int = -1
) -> Dictionary:
	var galaxy: GalaxyData = generate_galaxy(galaxy_seed, system_count, min_distance, radius)
	var systems_to_sample: int = galaxy.systems.size()
	if sample_limit > 0:
		systems_to_sample = mini(systems_to_sample, sample_limit)

	var summary: Dictionary = {
		"seed": galaxy_seed,
		"sampled_systems": systems_to_sample,
		"planet_count": 0,
		"moon_count": 0,
		"belt_count": 0,
		"habitable_candidates": 0,
		"first_star_type": StarData.StarType.G,
		"first_star_temperature_k": 0.0,
		"best_system_index": -1,
		"best_system_seed": 0,
		"best_system_habitable_candidates": 0,
		"best_system_planet_count": 0,
		"best_system_belt_count": 0
	}

	for system_index in range(systems_to_sample):
		var system: SystemData = galaxy.systems[system_index]
		generate_system(system)

		var system_habitable_candidates: int = 0
		summary["planet_count"] += system.planets.size()
		summary["belt_count"] += system.asteroid_belts.size()

		if system_index == 0 and not system.stars.is_empty():
			summary["first_star_type"] = system.stars[0].spectral_type
			summary["first_star_temperature_k"] = system.stars[0].temperature_k

		for planet in system.planets:
			summary["moon_count"] += planet.moons.size()
			if _is_habitable_candidate(planet):
				system_habitable_candidates += 1

		summary["habitable_candidates"] += system_habitable_candidates

		if system_habitable_candidates > summary["best_system_habitable_candidates"]:
			summary["best_system_index"] = system_index
			summary["best_system_seed"] = system.system_seed
			summary["best_system_habitable_candidates"] = system_habitable_candidates
			summary["best_system_planet_count"] = system.planets.size()
			summary["best_system_belt_count"] = system.asteroid_belts.size()

	return summary


static func _generate_star(star_seed: int) -> StarData:
	var star: StarData = StarData.new()
	star.star_seed = star_seed
	star.mass_solar = _sample_initial_mass_function(_hash_float(star_seed, "mass"))
	star.luminosity_solar = pow(star.mass_solar, 3.5)
	star.radius_solar = pow(star.mass_solar, 0.8)
	star.temperature_k = 5772.0 * pow(
		star.luminosity_solar / max(0.0001, star.radius_solar * star.radius_solar),
		0.25
	)
	star.spectral_type = _classify_spectral_type(star.temperature_k)
	star.habitable_zone_inner_au = 0.95 * sqrt(star.luminosity_solar)
	star.habitable_zone_outer_au = 1.67 * sqrt(star.luminosity_solar)
	star.snow_line_au = 2.7 * sqrt(star.luminosity_solar)
	star.hot_zone_au = max(0.05, pow(278.0 / 500.0, 2.0) * sqrt(star.luminosity_solar))
	return star


static func _generate_planetary_architecture(system_seed: int, star: StarData) -> Dictionary:
	var planets: Array[PlanetData] = []
	var skipped_slots: Array[Dictionary] = []
	var disk_fraction: float = lerp(0.01, 0.10, _hash_float(system_seed, "disk_fraction"))
	var disk_mass_solar: float = star.mass_solar * disk_fraction
	var disk_inner_au: float = max(0.12, star.hot_zone_au * 0.55)
	var disk_outer_au: float = max(star.snow_line_au * 2.2, 18.0 * pow(star.mass_solar, 0.45) + 12.0)
	var spacing_factor: float = lerp(1.45, 1.90, _hash_float(system_seed, "orbit_spacing"))
	var template_radius: float = disk_inner_au * lerp(1.15, 1.40, _hash_float(system_seed, "orbit_start"))
	var sigma0: float = _disk_sigma0(disk_mass_solar, disk_inner_au, disk_outer_au)
	var previous_planet: PlanetData = null
	var slot_index: int = 0

	while template_radius <= disk_outer_au and slot_index < 24:
		var slot_key: String = "slot:%d" % slot_index
		var semi_major_axis: float = template_radius
		var zone_width: float = _orbit_zone_width(semi_major_axis, spacing_factor)
		var slot_data: Dictionary = _evaluate_slot(
			system_seed,
			star,
			slot_index,
			semi_major_axis,
			zone_width,
			sigma0,
			disk_inner_au,
			disk_outer_au
		)

		if previous_planet != null and slot_data["total_mass_earth"] >= 0.15:
			var required_gap: float = 10.0 * _mutual_hill_radius_au(
				previous_planet.orbit.semi_major_axis_au,
				semi_major_axis,
				previous_planet.mass_earth / SOLAR_MASS_TO_EARTH_MASS,
				slot_data["total_mass_earth"] / SOLAR_MASS_TO_EARTH_MASS,
				star.mass_solar
			)
			if semi_major_axis - previous_planet.orbit.semi_major_axis_au < required_gap:
				semi_major_axis = previous_planet.orbit.semi_major_axis_au + required_gap
				if semi_major_axis > disk_outer_au:
					break
				zone_width = _orbit_zone_width(semi_major_axis, spacing_factor)
				slot_data = _evaluate_slot(
					system_seed,
					star,
					slot_index,
					semi_major_axis,
					zone_width,
					sigma0,
					disk_inner_au,
					disk_outer_au
				)

		if slot_data["total_mass_earth"] >= 0.15:
			var orbit: OrbitData = _build_orbit_data(system_seed, slot_key, semi_major_axis, star.mass_solar, previous_planet)
			var planet: PlanetData = _create_planet(system_seed, slot_index, star, orbit, slot_data)
			planet.moons = _generate_moons(system_seed, star, planet)
			planets.append(planet)
			previous_planet = planet
		else:
			skipped_slots.append({
				"slot_index": slot_index,
				"semi_major_axis": semi_major_axis,
				"zone_width": zone_width,
				"solid_mass_earth": slot_data["solid_mass_earth"],
				"temperature_k": slot_data["temperature_k"]
			})

		template_radius = semi_major_axis * spacing_factor
		slot_index += 1

	var belts: Array[AsteroidBeltData] = _generate_asteroid_belts(system_seed, star, planets, skipped_slots)
	return {
		"planets": planets,
		"belts": belts
	}


static func _evaluate_slot(
	system_seed: int,
	star: StarData,
	slot_index: int,
	semi_major_axis: float,
	zone_width: float,
	sigma0: float,
	disk_inner_au: float,
	disk_outer_au: float
) -> Dictionary:
	var slot_seed: int = derive_seed(system_seed, 1_000 + slot_index)
	var inner_edge: float = max(disk_inner_au, semi_major_axis - zone_width * 0.5)
	var outer_edge: float = min(disk_outer_au, semi_major_axis + zone_width * 0.5)
	var ring_mass_solar: float = _disk_ring_mass(sigma0, inner_edge, outer_edge)
	var solid_fraction: float = 0.015 if semi_major_axis < star.snow_line_au else 0.040
	var thermal_factor: float = clamp(pow(semi_major_axis / max(star.hot_zone_au, 0.05), 0.22), 0.35, 1.15)
	var turbulence: float = lerp(0.92, 1.08, _hash_float(slot_seed, "turbulence"))
	var accretion_efficiency: float = clamp((0.42 if semi_major_axis < star.snow_line_au else 0.58) * thermal_factor * turbulence, 0.08, 0.85)
	var solid_mass_earth: float = ring_mass_solar * SOLAR_MASS_TO_EARTH_MASS * solid_fraction
	var core_mass_earth: float = solid_mass_earth * accretion_efficiency
	var gas_capture: float = 0.0
	if semi_major_axis >= star.snow_line_au * 0.85:
		gas_capture = clamp((core_mass_earth - 6.0) / 18.0, 0.0, 1.0)
		gas_capture *= clamp(pow(star.snow_line_au / max(0.1, semi_major_axis), 0.35), 0.4, 1.4)
	var total_mass_earth: float = core_mass_earth + core_mass_earth * 8.0 * gas_capture
	var temperature_k: float = _equilibrium_temperature_k(star.luminosity_solar, semi_major_axis)
	return {
		"solid_mass_earth": solid_mass_earth,
		"core_mass_earth": core_mass_earth,
		"total_mass_earth": total_mass_earth,
		"gas_capture": gas_capture,
		"temperature_k": temperature_k
	}


static func _create_planet(
	system_seed: int,
	slot_index: int,
	star: StarData,
	orbit: OrbitData,
	slot_data: Dictionary
) -> PlanetData:
	var planet_seed: int = derive_seed(system_seed, 2_000 + slot_index)
	var planet: PlanetData = PlanetData.new()
	planet.planet_seed = planet_seed
	planet.name = "P-%02d" % (slot_index + 1)
	planet.mass_earth = slot_data["total_mass_earth"]
	planet.temperature_k = slot_data["temperature_k"]
	planet.type = _classify_planet_type(star, orbit.semi_major_axis_au, planet.mass_earth, slot_data["gas_capture"], planet.temperature_k)
	planet.composition = _planet_composition_label(planet.type, orbit.semi_major_axis_au, star.snow_line_au, planet.temperature_k)
	planet.radius_earth = _planet_radius_earth(planet.type, planet.mass_earth)
	planet.orbit = orbit
	return planet


static func _generate_moons(system_seed: int, star: StarData, planet: PlanetData) -> Array[MoonData]:
	var moons: Array[MoonData] = []
	if planet.mass_earth < 0.2:
		return moons

	var hill_radius_au: float = planet.orbit.semi_major_axis_au * (1.0 - planet.orbit.eccentricity) * pow(
		(planet.mass_earth / SOLAR_MASS_TO_EARTH_MASS) / max(0.000001, 3.0 * star.mass_solar),
		1.0 / 3.0
	)
	var inner_limit_au: float = max(_roche_limit_au(planet), planet.radius_earth * EARTH_RADIUS_TO_AU * 3.0)
	var outer_limit_au: float = hill_radius_au * 0.4
	if outer_limit_au <= inner_limit_au * 1.2:
		return moons

	var budget_fraction: float = lerp(0.01, 0.08, _hash_float(planet.planet_seed, "moon_budget"))
	if planet.type == PlanetData.PlanetType.ROCKY or planet.type == PlanetData.PlanetType.OCEAN:
		budget_fraction *= 0.6
	var total_moon_mass: float = planet.mass_earth * budget_fraction
	if total_moon_mass < 0.01:
		return moons

	var spacing_factor: float = lerp(1.55, 2.05, _hash_float(planet.planet_seed, "moon_spacing"))
	var orbit_radius: float = inner_limit_au * lerp(1.10, 1.35, _hash_float(planet.planet_seed, "moon_start"))
	var max_count: int = clampi(int(floor(log(outer_limit_au / orbit_radius) / log(spacing_factor))) + 1, 1, 8)
	var weight_sum: float = 0.0
	var weights: Array[float] = []
	var major_moon: bool = _hash_float(planet.planet_seed, "major_moon") > 0.965 and total_moon_mass > 0.4

	for moon_index in range(max_count):
		var weight: float = 1.0 / (1.0 + moon_index)
		weight *= lerp(0.85, 1.15, _hash_float(planet.planet_seed, "moon_weight:%d" % moon_index))
		if major_moon and moon_index == 0:
			weight *= 5.5
		weights.append(weight)
		weight_sum += weight

	for moon_index in range(max_count):
		if orbit_radius > outer_limit_au:
			break
		var moon: MoonData = MoonData.new()
		var moon_seed: int = derive_seed(planet.planet_seed, moon_index)
		var mass_earth: float = total_moon_mass * weights[moon_index] / max(weight_sum, 0.0001)
		moon.moon_seed = moon_seed
		moon.name = "%s-%s" % [planet.name, String.chr(97 + moon_index)]
		moon.mass_earth = mass_earth
		moon.temperature_k = planet.temperature_k
		moon.type = _classify_moon_type(planet, mass_earth, major_moon and moon_index == 0)
		moon.composition = _moon_composition_label(moon.type, planet.temperature_k)
		moon.radius_earth = _moon_radius_earth(moon.type, moon.mass_earth)
		moon.orbit = _build_satellite_orbit(planet, orbit_radius, moon_seed)
		moons.append(moon)
		orbit_radius *= spacing_factor

	return moons


static func _generate_asteroid_belts(
	system_seed: int,
	star: StarData,
	planets: Array[PlanetData],
	skipped_slots: Array[Dictionary]
) -> Array[AsteroidBeltData]:
	var belts: Array[AsteroidBeltData] = []
	for slot in skipped_slots:
		var resonance: Dictionary = _strongest_resonance(slot["semi_major_axis"], planets)
		var should_form_belt: bool = slot["solid_mass_earth"] >= 0.03
		should_form_belt = should_form_belt and (resonance["strength"] > 0.45 or slot["temperature_k"] < 1_000.0)
		if not should_form_belt:
			continue
		var belt: AsteroidBeltData = AsteroidBeltData.new()
		belt.belt_seed = derive_seed(system_seed, 3_000 + slot["slot_index"])
		belt.name = "Belt-%02d" % (slot["slot_index"] + 1)
		belt.width_au = slot["zone_width"] * 0.75
		belt.mass_earth = min(slot["solid_mass_earth"], 2.5)
		belt.dominant_material = "silicate rubble" if slot["semi_major_axis"] < star.snow_line_au else "carbonaceous ice-rock mix"
		belt.resonance_tag = resonance["tag"]
		belt.orbit = _build_orbit_data(system_seed, "belt:%d" % slot["slot_index"], slot["semi_major_axis"], star.mass_solar, null)
		belts.append(belt)
	return belts


static func _strongest_resonance(radius_au: float, planets: Array[PlanetData]) -> Dictionary:
	var best_strength: float = 0.0
	var best_tag: String = "none"
	var resonances: Array[Dictionary] = [
		{"p": 2.0, "q": 1.0, "tag": "2:1"},
		{"p": 3.0, "q": 2.0, "tag": "3:2"},
		{"p": 5.0, "q": 2.0, "tag": "5:2"}
	]
	for planet in planets:
		if planet.type != PlanetData.PlanetType.GAS_GIANT and planet.type != PlanetData.PlanetType.ICE_GIANT:
			continue
		for resonance in resonances:
			var inner_resonance: float = planet.orbit.semi_major_axis_au * pow(resonance["q"] / resonance["p"], 2.0 / 3.0)
			var outer_resonance: float = planet.orbit.semi_major_axis_au * pow(resonance["p"] / resonance["q"], 2.0 / 3.0)
			var distance: float = min(abs(radius_au - inner_resonance), abs(radius_au - outer_resonance))
			var width: float = max(0.05, radius_au * 0.08)
			var strength: float = clamp(1.0 - distance / width, 0.0, 1.0)
			if strength > best_strength:
				best_strength = strength
				best_tag = resonance["tag"]
	return {"strength": best_strength, "tag": best_tag}


static func _build_orbit_data(
	system_seed: int,
	key: String,
	semi_major_axis: float,
	central_mass_solar: float,
	previous_planet: PlanetData
) -> OrbitData:
	var orbit: OrbitData = OrbitData.new()
	var eccentricity_bias: float = pow(_hash_float(system_seed, "%s:ecc" % key), 2.4)
	orbit.semi_major_axis_au = semi_major_axis
	orbit.eccentricity = min(0.18, 0.12 * eccentricity_bias + 0.01)
	if previous_planet != null:
		var gap_ratio: float = (semi_major_axis - previous_planet.orbit.semi_major_axis_au) / semi_major_axis
		orbit.eccentricity *= clamp(gap_ratio * 3.0, 0.55, 1.0)
	orbit.inclination_rad = deg_to_rad(3.0 * pow(_hash_float(system_seed, "%s:inc" % key), 2.0))
	orbit.argument_of_periapsis_rad = TAU * _hash_float(system_seed, "%s:argp" % key)
	orbit.longitude_of_ascending_node_rad = TAU * _hash_float(system_seed, "%s:loan" % key)
	orbit.mean_anomaly_at_epoch_rad = TAU * _hash_float(system_seed, "%s:mean" % key)
	orbit.phase_offset_rad = orbit.mean_anomaly_at_epoch_rad
	orbit.period_days = 365.25 * sqrt(pow(semi_major_axis, 3.0) / max(0.0001, central_mass_solar))
	orbit.mean_motion_rad_per_day = TAU / max(0.001, orbit.period_days)
	return orbit


static func _build_satellite_orbit(planet: PlanetData, orbital_radius_au: float, moon_seed: int) -> OrbitData:
	var orbit: OrbitData = OrbitData.new()
	orbit.semi_major_axis_au = orbital_radius_au
	orbit.eccentricity = min(0.08, 0.05 * pow(_hash_float(moon_seed, "ecc"), 2.0) + 0.005)
	orbit.inclination_rad = deg_to_rad(1.5 * pow(_hash_float(moon_seed, "inc"), 2.0))
	orbit.argument_of_periapsis_rad = TAU * _hash_float(moon_seed, "argp")
	orbit.longitude_of_ascending_node_rad = TAU * _hash_float(moon_seed, "loan")
	orbit.mean_anomaly_at_epoch_rad = TAU * _hash_float(moon_seed, "mean")
	orbit.phase_offset_rad = orbit.mean_anomaly_at_epoch_rad
	orbit.period_days = 365.25 * sqrt(
		pow(orbital_radius_au, 3.0) / max(0.0000001, planet.mass_earth / SOLAR_MASS_TO_EARTH_MASS)
	)
	orbit.mean_motion_rad_per_day = TAU / max(0.001, orbit.period_days)
	return orbit


static func _sample_initial_mass_function(u: float) -> float:
	var segments: Array[Dictionary] = [
		{"min": 0.08, "max": 0.50, "alpha": 1.3},
		{"min": 0.50, "max": 1.00, "alpha": 2.3},
		{"min": 1.00, "max": 20.0, "alpha": 2.35}
	]
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for segment in segments:
		var weight: float = _power_law_integral(segment["min"], segment["max"], segment["alpha"])
		weights.append(weight)
		total_weight += weight
	var scaled: float = u * total_weight
	for index in range(segments.size()):
		if scaled <= weights[index]:
			return _sample_power_law(scaled / weights[index], segments[index]["min"], segments[index]["max"], segments[index]["alpha"])
		scaled -= weights[index]
	var last: Dictionary = segments[segments.size() - 1]
	return _sample_power_law(1.0, last["min"], last["max"], last["alpha"])


static func _sample_power_law(u: float, min_mass: float, max_mass: float, alpha: float) -> float:
	if is_equal_approx(alpha, 1.0):
		return min_mass * pow(max_mass / min_mass, u)
	var exponent: float = 1.0 - alpha
	var min_term: float = pow(min_mass, exponent)
	var max_term: float = pow(max_mass, exponent)
	return pow(min_term + u * (max_term - min_term), 1.0 / exponent)


static func _power_law_integral(min_mass: float, max_mass: float, alpha: float) -> float:
	if is_equal_approx(alpha, 1.0):
		return log(max_mass / min_mass)
	var exponent: float = 1.0 - alpha
	return (pow(max_mass, exponent) - pow(min_mass, exponent)) / exponent


static func _classify_spectral_type(temperature_k: float) -> StarData.StarType:
	if temperature_k >= 30_000.0:
		return StarData.StarType.O
	if temperature_k >= 10_000.0:
		return StarData.StarType.B
	if temperature_k >= 7_500.0:
		return StarData.StarType.A
	if temperature_k >= 6_000.0:
		return StarData.StarType.F
	if temperature_k >= 5_200.0:
		return StarData.StarType.G
	if temperature_k >= 3_700.0:
		return StarData.StarType.K
	return StarData.StarType.M


static func _classify_planet_type(
	star: StarData,
	semi_major_axis_au: float,
	mass_earth: float,
	gas_capture: float,
	temperature_k: float
) -> PlanetData.PlanetType:
	if mass_earth >= 30.0 and gas_capture >= 0.35:
		return PlanetData.PlanetType.GAS_GIANT
	if mass_earth >= 8.0 and semi_major_axis_au >= star.snow_line_au * 0.8:
		return PlanetData.PlanetType.ICE_GIANT
	if semi_major_axis_au >= star.snow_line_au or temperature_k < 220.0:
		return PlanetData.PlanetType.ICE
	if temperature_k >= 240.0 and temperature_k <= 330.0 and mass_earth >= 0.4 and mass_earth <= 6.0:
		return PlanetData.PlanetType.OCEAN
	return PlanetData.PlanetType.ROCKY


static func _planet_composition_label(
	planet_type: PlanetData.PlanetType,
	semi_major_axis_au: float,
	snow_line_au: float,
	temperature_k: float
) -> String:
	match planet_type:
		PlanetData.PlanetType.GAS_GIANT:
			return "H/He envelope over volatile-rich core"
		PlanetData.PlanetType.ICE_GIANT:
			return "high-pressure ice mantle with modest H/He envelope"
		PlanetData.PlanetType.ICE:
			return "silicate core with deep water-ammonia ice shell"
		PlanetData.PlanetType.OCEAN:
			return "silicate world with stable surface hydrosphere"
		_:
			if semi_major_axis_au < snow_line_au * 0.5 or temperature_k > 500.0:
				return "metal-rich refractory silicates"
			return "silicate mantle with limited volatiles"


static func _classify_moon_type(planet: PlanetData, mass_earth: float, major_moon: bool) -> MoonData.MoonType:
	if major_moon and mass_earth >= 0.2:
		return MoonData.MoonType.MAJOR
	if planet.temperature_k < 220.0:
		return MoonData.MoonType.ICE
	if planet.temperature_k <= 310.0 and mass_earth >= 0.05:
		return MoonData.MoonType.OCEAN
	return MoonData.MoonType.ROCKY


static func _moon_composition_label(moon_type: MoonData.MoonType, temperature_k: float) -> String:
	match moon_type:
		MoonData.MoonType.MAJOR:
			return "differentiated silicate-ice body"
		MoonData.MoonType.ICE:
			return "water-ice crust over rocky interior"
		MoonData.MoonType.OCEAN:
			return "rocky body with retained volatiles"
		_:
			return "dry silicate crust" if temperature_k > 330.0 else "rocky crust with trace ice"


static func _planet_radius_earth(planet_type: PlanetData.PlanetType, mass_earth: float) -> float:
	match planet_type:
		PlanetData.PlanetType.GAS_GIANT:
			return clamp(4.0 + 7.0 * (1.0 - exp(-mass_earth / 90.0)), 4.0, 13.5)
		PlanetData.PlanetType.ICE_GIANT:
			return clamp(2.2 * pow(max(mass_earth, 0.1), 0.22), 2.0, 5.0)
		PlanetData.PlanetType.ICE:
			return 1.20 * pow(max(mass_earth, 0.05), 0.27)
		PlanetData.PlanetType.OCEAN:
			return 1.08 * pow(max(mass_earth, 0.05), 0.27)
		_:
			return pow(max(mass_earth, 0.05), 0.28)


static func _moon_radius_earth(moon_type: MoonData.MoonType, mass_earth: float) -> float:
	if moon_type == MoonData.MoonType.ICE:
		return 1.15 * pow(max(mass_earth, 0.01), 0.28)
	return pow(max(mass_earth, 0.01), 0.30)


static func _is_habitable_candidate(planet: PlanetData) -> bool:
	if planet == null:
		return false

	if planet.type != PlanetData.PlanetType.ROCKY and planet.type != PlanetData.PlanetType.OCEAN:
		return false

	return planet.temperature_k >= 240.0 and planet.temperature_k <= 330.0


static func _equilibrium_temperature_k(luminosity_solar: float, distance_au: float) -> float:
	return 278.0 * pow(luminosity_solar, 0.25) / sqrt(max(0.05, distance_au))


static func _disk_sigma0(disk_mass_solar: float, inner_au: float, outer_au: float) -> float:
	return disk_mass_solar / max(0.0001, 4.0 * PI * (sqrt(outer_au) - sqrt(inner_au)))


static func _disk_ring_mass(sigma0: float, inner_au: float, outer_au: float) -> float:
	return 4.0 * PI * sigma0 * max(0.0, sqrt(outer_au) - sqrt(inner_au))


static func _orbit_zone_width(semi_major_axis: float, spacing_factor: float) -> float:
	var root_spacing: float = sqrt(spacing_factor)
	return semi_major_axis * (root_spacing - 1.0 / root_spacing)


static func _mutual_hill_radius_au(a1: float, a2: float, m1_solar: float, m2_solar: float, star_mass_solar: float) -> float:
	var mean_axis: float = 0.5 * (a1 + a2)
	return mean_axis * pow((m1_solar + m2_solar) / max(0.000001, 3.0 * star_mass_solar), 1.0 / 3.0)


static func _roche_limit_au(planet: PlanetData) -> float:
	var density_ratio: float = 1.5
	if planet.type == PlanetData.PlanetType.ROCKY or planet.type == PlanetData.PlanetType.OCEAN:
		density_ratio = 1.1
	return 2.44 * planet.radius_earth * EARTH_RADIUS_TO_AU * pow(density_ratio, 1.0 / 3.0)


static func _generate_system_shell(galaxy_seed: int, count: int, min_distance: float, radius: float) -> Array[SystemData]:
	var systems: Array[SystemData] = []
	for index in range(count):
		var system: SystemData = SystemData.new()
		var radial_fraction: float = sqrt((float(index) + 0.5) / max(1.0, float(count)))
		var radial_jitter: float = lerp(-0.5, 0.5, _hash_float(galaxy_seed, "system:%d:radius" % index))
		var angle_jitter: float = lerp(-0.35, 0.35, _hash_float(galaxy_seed, "system:%d:angle" % index))
		var distance: float = radial_fraction * max(radius, min_distance * 0.5) + radial_jitter * min_distance * 0.4
		distance = clamp(distance, min_distance * 0.5, radius)
		var angle: float = float(index) * GOLDEN_ANGLE + angle_jitter
		system.position = Vector2.RIGHT.rotated(angle) * distance
		system.system_seed = derive_seed(galaxy_seed, index)
		systems.append(system)
	return systems


static func _hash_float(seed: int, key: String) -> float:
	var digest: String = ("%d:%s" % [seed, key]).sha256_text()
	var accumulator: float = 0.0
	for char_index in range(13):
		accumulator = accumulator * 16.0 + float(_hex_digit_value(digest.unicode_at(char_index)))
	return accumulator / 4_503_599_627_370_495.0


static func _hash_int(seed: int, key: String) -> int:
	return int(floor(_hash_float(seed, key) * 2_147_483_647.0))


static func _hex_digit_value(codepoint: int) -> int:
	if codepoint >= 48 and codepoint <= 57:
		return codepoint - 48
	if codepoint >= 97 and codepoint <= 102:
		return codepoint - 87
	return 0
