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
	var bulge_disk_dict = C.f_bulge_disk(galaxy_seed, m_star, f_gas, Delta_physics, f_star_halo)
	var f_bulge = bulge_disk_dict["f_bulge"]
	var f_disk  = bulge_disk_dict["f_disk"]
	var s_morph  = bulge_disk_dict["s_morph"]
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
	
	var disk_size_dict := C.sample_disk_scale_length_from_galaxy(
		galaxy_seed,
		m_vir,
		f_baryon,
		f_gas,
		f_disk,
		0.0,
		halo_dict["r200c_kpc"]
	)
	
	if disk_size_dict.is_empty():
		Log.error(111, "galaxy_seed")
		return
		
	var disk_size := DiskSize.new()
	
	disk_size.r_eff_m = disk_size_dict["r_eff_m"]
	disk_size.r_d_m = disk_size_dict["r_d_m"]
	disk_size.r_eff_kpc = disk_size_dict["r_eff_kpc"]
	disk_size.r_d_kpc = disk_size_dict["r_d_kpc"]
	disk_size.log10_r_eff_kpc = disk_size_dict["log10_r_eff_kpc"]
	disk_size.log10_r_d_kpc = disk_size_dict["log10_r_d_kpc"]
	disk_size.r_eff_halo_check_m = disk_size_dict["r_eff_halo_check_m"]
	disk_size.r_d_halo_check_m = disk_size_dict["r_d_halo_check_m"]
	disk_size.sigma_dex = disk_size_dict["sigma_dex"]
	
	galaxy.disk_size = disk_size
	
	var disk_thickness_dict := C.sample_disk_thickness_si(
		galaxy_seed,
		disk_size_dict["r_d_m"],
		f_disk * m_star,
		f_gas,
		bulge_disk_dict["s_morph"],
		0.0, # z = (관측된 파장 - 원래 파장) / 원래 파장 (Distance)
	)
	
	if disk_thickness_dict.is_empty():
		Log.error(111, "galaxy_seed")
		return
		
	var disk_thickness := DiskThickness.new()
	
	disk_thickness.z0_m = disk_thickness_dict["z0_m"]
	disk_thickness.z0_kpc = disk_thickness_dict["z0_kpc"]
	disk_thickness.q_z0_over_rd = disk_thickness_dict["q_z0_over_rd"]
	disk_thickness.sigma_logit = disk_thickness_dict["sigma_logit"]
	
	galaxy.disk_thickness = disk_thickness

	var bulge_profile_dict := C.sample_bulge_profile_from_galaxy(
		galaxy_seed,
		m_vir,
		f_baryon,
		f_gas,
		f_bulge,
		s_morph,
		0.0,
		halo_dict["r200c_kpc"]
	)

	if bulge_profile_dict.is_empty():
		Log.error(112, "galaxy_seed")
		return

	var bulge_profile := BulgeProfile.new()
	bulge_profile.n_sersic = bulge_profile_dict["n_sersic"]
	bulge_profile.r_eff_kpc = bulge_profile_dict["r_eff_kpc"]
	bulge_profile.r_eff_m = bulge_profile_dict["r_eff_m"]
	bulge_profile.log10_r_eff_kpc = bulge_profile_dict["log10_r_eff_kpc"]
	bulge_profile.sigma_dex_re = bulge_profile_dict["sigma_dex_re"]
	bulge_profile.sigma_logit_n = bulge_profile_dict["sigma_logit_n"]
	bulge_profile.halo_soft_prior = bulge_profile_dict["halo_soft_prior"]
	galaxy.bulge_profile = bulge_profile

	var accretion_disk_dict := C.sample_accretion_disk_from_galaxy(
		galaxy_seed,
		m_vir,
		f_baryon,
		f_gas,
		f_bulge,
		s_morph
	)

	if accretion_disk_dict.is_empty():
		Log.error(113, "galaxy_seed")
		return

	var accretion_disk := AccretionDiskData.new()
	accretion_disk.has_disk = accretion_disk_dict["has_disk"]
	accretion_disk.p_disk = accretion_disk_dict["p_disk"]
	accretion_disk.m_bh_kg = accretion_disk_dict["m_bh_kg"]
	accretion_disk.log10_m_bh_msun = accretion_disk_dict["log10_m_bh_msun"]
	accretion_disk.spin_a = accretion_disk_dict["spin_a"]
	accretion_disk.eta_rad = accretion_disk_dict["eta_rad"]
	accretion_disk.log10_lambda_proxy = accretion_disk_dict["log10_lambda_proxy"]
	accretion_disk.p_coherent = accretion_disk_dict["p_coherent"]
	galaxy.accretion_disk = accretion_disk
	
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
	Log.info("r_eff_m: %s" % [galaxy.disk_size.r_eff_m])
	Log.info("r_d_m: %s" % [galaxy.disk_size.r_d_m])
	Log.info("z0_m: %s" % [galaxy.disk_thickness.z0_m])
	Log.info("q_z0_over_rd: %s" % [galaxy.disk_thickness.q_z0_over_rd])
	Log.info("bulge_n_sersic: %s" % [galaxy.bulge_profile.n_sersic])
	Log.info("bulge_r_eff_kpc: %s" % [galaxy.bulge_profile.r_eff_kpc])
	Log.info("accretion_has_disk: %s" % [galaxy.accretion_disk.has_disk])
	Log.info("accretion_log10_m_bh_msun: %s" % [galaxy.accretion_disk.log10_m_bh_msun])
	Log.info("accretion_log10_lambda_proxy: %s" % [galaxy.accretion_disk.log10_lambda_proxy])
	Log.info("accretion_p_coherent: %s" % [galaxy.accretion_disk.p_coherent])
	
	return galaxy
