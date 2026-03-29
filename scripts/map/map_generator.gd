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
	
	var halo_dict := C.halo_state_from_mvir(galaxy_seed, m_vir, 0.0)
	if halo_dict.is_empty():
		Log.error(110, "galaxy_seed")
		return
		
	var halo := HaloData.new()
	
	halo.m200c = halo_dict["m200c"]
	halo.c200 = halo_dict["c200"]
	halo.r200c_kpc = halo_dict["r200c_kpc"]
	halo.rs_kpc = halo_dict["rs_kpc"]
	halo.rho_s_msun_kpc3 = halo_dict["rho_s_msun_kpc3"]
	halo.mvir_pred = halo_dict["mvir_pred"]
	halo.cvir = halo_dict["cvir"]
	halo.rvir_kpc = halo_dict["rvir_kpc"]
	halo.delta_vir = halo_dict["delta_vir"]
	halo.rho_crit_msun_kpc3 = halo_dict["rho_crit_msun_kpc3"]

	galaxy.halo = halo
	
	var disk_size := C.sample_disk_scale_length_from_galaxy(
		galaxy_seed,
		m_vir,
		f_baryon,
		f_gas,
		f_disk,
		0.0,
		halo_dict["r200c_kpc"]
	)
	
	Log.info("galaxy_seed: %s" % [galaxy.galaxy_seed])
	Log.info("m_vir/C.MILKYWAY_MASS: %s" % [galaxy.m_vir/C.MILKYWAY_MASS])
	Log.info("f_baryon: %s" % [galaxy.f_baryon])
	Log.info("f_gas: %s" % [galaxy.f_gas])
	Log.info("f_bulge: %s" % [galaxy.f_bulge])
	Log.info("f_disk: %s" % [galaxy.f_disk])
	Log.info("f_star_halo: %s" % [galaxy.f_star_halo])
	Log.info("m200c: %s" % [galaxy.halo.m200c])
	Log.info("c200: %s" % [galaxy.halo.c200])
	Log.info("r200c_kpc: %s" % [galaxy.halo.r200c_kpc])
	Log.info("rs_kpc: %s" % [galaxy.halo.rs_kpc])
	Log.info("rho_s_msun_kpc3: %s" % [galaxy.halo.rho_s_msun_kpc3])
	Log.info("mvir_pred: %s" % [galaxy.halo.mvir_pred])
	Log.info("cvir: %s" % [galaxy.halo.cvir])
	Log.info("rvir_kpc: %s" % [galaxy.halo.rvir_kpc])
	Log.info("delta_vir: %s" % [galaxy.halo.delta_vir])
	Log.info("rho_crit_msun_kpc3: %s" % [galaxy.halo.rho_crit_msun_kpc3])
	
	return galaxy
