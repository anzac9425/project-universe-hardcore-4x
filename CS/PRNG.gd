extends RefCounted
class_name PRNG

static var rng: RandomNumberGenerator = RandomNumberGenerator.new()

static func seed_with_u64(seed: int) -> void:
	rng.seed = seed

static func seed_with_string(seed: String) -> void:
	rng.seed = int(seed.hash())

static func next_int(min: int = 0, max: int = 2147483647) -> int:
	return rng.randi_range(min, max)

static func next_float(min: float = 0.0, max: float = 3.4028235e38) -> float:
	return rng.randf_range(min, max)
