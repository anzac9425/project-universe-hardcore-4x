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
	
	var m_baryon = galaxy.mass * f_b
	var m_gas = m_baryon * f_g
	var m_star = m_baryon * (1.0 - f_g)
	
	galaxy.f_baryon = f_b
	galaxy.f_gas = f_g
	galaxy.m_baryon = m_baryon
	galaxy.m_gas = m_gas
	galaxy.m_star = m_star
	
	Log.info("%s" % [galaxy.mass/C.MILKYWAY_MASS])
	Log.info("%s" % [galaxy.f_baryon])
	Log.info("%s" % [galaxy.f_gas])
	
	return galaxy
