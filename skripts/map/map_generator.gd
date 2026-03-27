extends Node
class_name MapGenerator
	
static func generate(
	base_seed: int
) -> GalaxyData:
	
	var galaxy = GalaxyData.new()
	galaxy.galaxy_seed = C.hash_int(base_seed, C.HashPurpose.GALAXY)
	var u1 = C.hash_float(galaxy.galaxy_seed, C.HashPurpose.GALAXY, 0)
	var u2 = C.hash_float(galaxy.galaxy_seed, C.HashPurpose.GALAXY, 1)
	galaxy.mass = pow(10.0, C.M_GAL_MU + C.M_GAL_SIGMA * C.get_Z(u1, u2))
	
	Log.info("%s" % [C.Delta_type(galaxy.type)])
	return galaxy
