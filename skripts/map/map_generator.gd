extends Node
class_name MapGenerator
	
static func generate(
	base_seed: int
) -> GalaxyData:
	
	var galaxy = GalaxyData.new()
	
	var galaxy_seed = C.hash_int(base_seed, C.HashPurpose.GALAXY)
	galaxy.galaxy_seed = galaxy_seed
	
	var u1 = C.hash_float(galaxy_seed, C.HashPurpose.GALAXY, 0)
	var u2 = C.hash_float(galaxy_seed, C.HashPurpose.GALAXY, 1)
	
	var m_vir_msun = pow(10.0, C.M_GAL_MU + C.M_GAL_SIGMA * C.get_Z(u1, u2))
	var m_vir = m_vir_msun * C.SOLAR_MASS
	galaxy.m_vir = m_vir
	
	var f_baryon = C.f_baryon(galaxy_seed, m_vir)
	galaxy.f_baryon = f_baryon
	
	var m_baryon = m_vir * f_baryon
	
	var f_gas = C.f_gas(galaxy_seed, m_baryon)
	galaxy.f_gas = f_gas
	
	var m_gas = m_baryon * f_gas # gas/baryon
	var m_star = m_baryon * (1.0 - f_gas) # star/baryon

	var f_star_halo = C.f_star_halo(galaxy_seed, m_star, f_gas)
	galaxy.f_star_halo = f_star_halo
	
	var Delta_physics = C.Delta_physics(galaxy_seed)
	var bd = C.f_bulge_disk(galaxy_seed, m_star, f_gas, Delta_physics, f_star_halo)
	var f_bulge = bd["f_bulge"]
	var f_disk  = bd["f_disk"]
	galaxy.f_bulge = f_bulge
	galaxy.f_disk = f_disk
	
	Log.info("%s" % [m_vir/C.MILKYWAY_MASS])
	Log.info("%s" % [f_baryon])
	Log.info("%s" % [f_gas])
	Log.info("%s" % [f_bulge])
	Log.info("%s" % [f_disk])
	Log.info("%s" % [f_star_halo])
	
	return galaxy
