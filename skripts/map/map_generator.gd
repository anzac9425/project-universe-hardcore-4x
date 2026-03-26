extends Node
class_name MapGenerator

const SOLAR_MASS_TO_EARTH_MASS: float = 332_946.0
const EARTH_RADIUS_TO_AU: float = 4.26352e-5
const GOLDEN_ANGLE: float = 2.399963229728653


static func derive_seed(parent: int, purpose: String, index: int = 0) -> int:
	var digest = ("%d:%s:%d" % [parent, purpose, index]).sha256_text()
	return digest.left(8).hex_to_int() & 0x7FFFFFFF
	
	
static func make_rng(input: int) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = input
	return rng
	
	
static func generate(
	base_seed: int,
	system_count: int,
	min_distance: float,
	radius: float
) -> GalaxyData:
	
	var galaxy = GalaxyData.new()
	galaxy.galaxy_seed = derive_seed(base_seed, "galaxy")
	var rng = make_rng(galaxy.galaxy_seed)
	
	var raw_positions = _sample_density_field(rng, system_count * 3, radius)  # 과샘플링
	var filtered = _poisson_filter(raw_positions, radius * 0.05)  # 최소 거리 필터
	filtered = filtered.slice(0, system_count)

	for i in range(filtered.size()):
		var system = SystemData.new()
		system.location = filtered[i]
		system.system_seed = derive_seed(galaxy.galaxy_seed, "system", i)
		system.generated = false
		galaxy.systems.append(system)
		
	return galaxy


static func _sample_density_field(
	rng: RandomNumberGenerator,
	system_count: int,
	radius: float
) -> Array[Vector2]:

	var positions: Array[Vector2] = []
	const ARM_COUNT = 4
	const ARM_SPREAD = 0.35   # 팔 분산 (rad)
	const K = 0.35   # 나선 감김 계수

	for _i in range(system_count):
		# inverse CDF: r = −Rd × ln(1−u)  →  지수 분포 샘플링
		var u = rng.randf_range(0.0001, 0.9999)
		var r = -radius * log(1.0 - u)

		# 나선팔 중심각
		var arm_idx   = rng.randi_range(0, ARM_COUNT - 1)
		var arm_phase = (TAU / ARM_COUNT) * arm_idx
		var arm_angle = fmod(K * log(max(r, 0.01)) + arm_phase, TAU)

		# 팔 분산 추가 (가우시안 근사: 균등 2회 합산)
		var spread = (rng.randf() - 0.5 + rng.randf() - 0.5) * ARM_SPREAD
		var angle  = arm_angle + spread

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
