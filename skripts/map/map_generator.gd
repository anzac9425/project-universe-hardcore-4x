extends Node
class_name MapGenerator
	
static func generate(
	base_seed: int
) -> GalaxyData:
	
	var galaxy = GalaxyData.new()
	galaxy.galaxy_seed = hash_int(base_seed, HashPurpose.GALAXY)
	var u1 = hash_float(galaxy.galaxy_seed * C.MERSENNE.CONST_1, HashPurpose.GALAXY)
	var u2 = hash_float(galaxy.galaxy_seed * C.MERSENNE.CONST_2, HashPurpose.GALAXY)
	galaxy.mass = exp(C.M_GAL_MU + C.M_GAL_SIGMA * C.get_Z(u1, u2))
	Log.info("%s" % [galaxy.mass/C.MILKYWAY_MASS])

	return galaxy
	
	
static func hash_int(p_seed: int, purpose: int, index: int = 0) -> int:
	var x = p_seed
	x ^= purpose * 0x9e3779b9
	x ^= index * 0x85ebca6b

	# 추가 mixing (핵심)
	x ^= x >> 16
	x *= 0x7feb352d
	x ^= x >> 15
	x *= 0x846ca68b
	x ^= x >> 16

	return x & 0xFFFFFFFF
	

static func hash_float(p_seed: int, purpose: int, index: int = 0) -> float:
	return float(hash_int(p_seed, purpose, index) & 0xFFFFFFFF) / 4294967296.0
	

enum HashPurpose {
	GALAXY,
	SYSTEM,

}


func get_z_score(u1: float, u2: float) -> float: # u1, u2: hash_float
	u1 = max(u1, 1e-9)
	return sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)
