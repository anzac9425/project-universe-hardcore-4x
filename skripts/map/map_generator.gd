extends Node
class_name MapGenerator
	
	
static func hash_int(seed: int, purpose: int, index: int) -> int:
	var x = seed
	x ^= purpose * 0x9e3779b9
	x ^= index * 0x85ebca6b

	# 추가 mixing (핵심)
	x ^= x >> 16
	x *= 0x7feb352d
	x ^= x >> 15
	x *= 0x846ca68b
	x ^= x >> 16

	return x & 0x7FFFFFFF
	

static func hash_float(seed: int, purpose: int, index: int) -> float:
	return float(hash_int(seed, purpose, index)) / float(0x80000000)
	

static func derive_seed(parent: int, purpose: int, index: int = 0) -> int:
	return hash_int(parent, purpose, index)
	

enum SeedPurpose {
	GALAXY,
	SYSTEM,

	RADIUS,
	ARM,
	ANGLE,
	SPREAD,
	NOISE
}
	
	
static func generate(
	base_seed: int,
	system_count: int,
	min_distance: float,
	Rd: float
) -> GalaxyData:
	
	var galaxy = GalaxyData.new()
	galaxy.galaxy_seed = derive_seed(base_seed, SeedPurpose.GALAXY)
	
	var raw_positions = _sample_density_field(galaxy.galaxy_seed, system_count * 3, Rd)  # 과샘플링
	var filtered = _poisson_filter(raw_positions, min_distance)  # 최소 거리 필터
	filtered = filtered.slice(0, system_count)

	for i in range(filtered.size()):
		var system = SystemData.new()
		system.location = filtered[i]
		system.system_seed = derive_seed(galaxy.galaxy_seed, SeedPurpose.SYSTEM, i)
		system.generated = false
		galaxy.systems.append(system)

	return galaxy


static func _sample_density_field(
	galaxy_seed: int,
	system_count: int,
	Rd: float
) -> Array[Vector2]:

	var positions: Array[Vector2] = []

	const ARM_COUNT = 4
	const ARM_SPREAD = 0.35
	const K = 0.35

	for i in range(system_count):

		# --- r 샘플링 ---
		var u = hash_float(galaxy_seed, SeedPurpose.RADIUS, i)
		var r = -Rd * log(1.0 - u)

		# --- arm ---
		var arm_idx = int(hash_float(galaxy_seed, SeedPurpose.ARM, i) * ARM_COUNT)
		var arm_phase = (TAU / ARM_COUNT) * arm_idx

		var r_safe = max(r, 1e-4)
		var base_angle = K * log(r_safe)
		var arm_angle = fmod(base_angle + arm_phase, TAU)

		# --- spread (가우시안 근사) ---
		var spread_scale = lerp(0.5, 2.0, r / (Rd * 4.0))

		var spread = (
			hash_float(galaxy_seed, SeedPurpose.SPREAD, i * 2) - 0.5 +
			hash_float(galaxy_seed, SeedPurpose.SPREAD, i * 2 + 1) - 0.5
		) * ARM_SPREAD * spread_scale

		# --- noise ---
		var noise = (hash_float(galaxy_seed, SeedPurpose.NOISE, i) * 2.0 - 1.0) * 0.2

		var angle = arm_angle + spread + noise

		positions.append(Vector2(cos(angle), sin(angle)) * r)

	return positions


static func _poisson_filter(
	candidates: Array[Vector2],
	min_dist: float
) -> Array[Vector2]:

	var accepted: Array[Vector2] = []

	for candidate in candidates:
		var valid = true
		for existing in accepted:
			if candidate.distance_to(existing) < min_dist:
				valid = false
				break
		if valid:
			accepted.append(candidate)
			
	return accepted
