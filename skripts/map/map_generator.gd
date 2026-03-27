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
	
	var f_b = C.f_baryon(galaxy)
	var f_g = C.f_gas(galaxy)
	
	var M_total = galaxy.mass
	var M_baryon = M_total * f_b
	var M_gas = M_baryon * f_g
	var M_star = M_baryon * (1.0 - f_g)
	
	galaxy.f_baryon = C.f_baryon(galaxy)
	galaxy.f_gas = C.f_gas(galaxy)
	galaxy.m_baryon = galaxy.f_baryon * galaxy.mass
	galaxy.m_gas = galaxy.f_gas * galaxy.m_baryon
	galaxy.m_star = galaxy.m_baryon * (1.0 - galaxy.f_gas)
	
	return galaxy
