extends Node
class_name MapGenerator

static func generate(base_seed: int, base_n_star: int) -> GalaxyData:
	var galaxy = GalaxyData.new()

	var galaxy_seed := C.hash_int(base_seed, C.HashPurpose.GALAXY)
	galaxy.galaxy_seed = galaxy_seed
	
	galaxy.base_n_star = base_n_star

	# [use] z_form -> age_gyr
	var z_form := C.sample_z_form(galaxy_seed)
	z_form = 0.5
	# lookback_time_gyr_from_z(0) ≡ 0 이므로 단순화
	var age_gyr: float = C.lookback_time_gyr_from_z(z_form)
	galaxy.z_form = z_form
	galaxy.age_gyr = age_gyr

	# [use] halo_spin -> disk size / thickness / spiral structure
	var halo_spin := C.sample_halo_spin(galaxy_seed)
	galaxy.halo_spin = halo_spin

	var u1 := C.hash_float(galaxy_seed, C.HashPurpose.GALAXY, 0)
	var u2 := C.hash_float(galaxy_seed, C.HashPurpose.GALAXY, 1)

	var m_vir_msun := pow(10.0, C.M_GAL_MU + C.M_GAL_SIGMA * C.get_Z(u1, u2))
	var m_vir := m_vir_msun * C.SOLAR_MASS
	galaxy.m_vir = m_vir

	var z := z_form

	var f_baryon := C.f_baryon(galaxy_seed, m_vir)
	galaxy.f_baryon = f_baryon

	var m_baryon := m_vir * f_baryon

	var delta_physics := C.Delta_physics(galaxy_seed)
	var f_gas := C.f_gas(galaxy_seed, m_vir, f_baryon, z, delta_physics)
	galaxy.f_gas = f_gas

	var m_gas := m_baryon * f_gas
	var m_star := m_baryon * (1.0 - f_gas)
	galaxy.m_gas = m_gas # [use] m_gas -> star population IMF bias

	var f_star_halo := C.f_star_halo(galaxy_seed, m_star, f_gas)
	galaxy.f_star_halo = f_star_halo

	var bulge_disk_dict := C.f_bulge_disk(galaxy_seed, m_star, f_gas, delta_physics, f_star_halo)
	var f_bulge: float = bulge_disk_dict["f_bulge"]
	var f_disk: float = bulge_disk_dict["f_disk"]
	var s_morph: float = bulge_disk_dict["s_morph"]
	galaxy.f_bulge = f_bulge
	galaxy.f_disk = f_disk

	# [use] structural parameters -> galaxy.type
	var type_score := 1.60 * f_bulge - 1.20 * f_gas + 0.35 * f_star_halo + 0.25 * delta_physics \
		+ 0.20 * C.logx(max(halo_spin, 1e-6) / 0.035)

	var galaxy_type := GalaxyData.GalaxyType.Sc
	if f_star_halo > 0.72 and f_gas < 0.12:
		galaxy_type = GalaxyData.GalaxyType.E
	elif f_star_halo > 0.55 and f_gas < 0.20:
		galaxy_type = GalaxyData.GalaxyType.S0
	elif type_score > 0.85:
		galaxy_type = GalaxyData.GalaxyType.Sa
	elif type_score > 0.20:
		galaxy_type = GalaxyData.GalaxyType.Sb
	elif type_score > -0.25:
		galaxy_type = GalaxyData.GalaxyType.Sc
	else:
		galaxy_type = GalaxyData.GalaxyType.Irr
	galaxy.type = galaxy_type

	# --- DM halo ---
	var halo_dict := C.halo_state_from_mvir(galaxy_seed, m_vir, z)
	if halo_dict.is_empty():
		Log.error(ERR_CODE.MAP_GENERATION_FAILED, "MapGenerator.gd", "HALO")
		return null

	var halo := HaloData.new()
	halo.m200c = halo_dict["m200c"]
	halo.m200c_msun = halo_dict["m200c_msun"]
	halo.c200 = halo_dict["c200"]
	halo.r200c_kpc = halo_dict["r200c_kpc"]
	halo.rs_kpc = halo_dict["rs_kpc"]
	halo.rho_s_msun_kpc3 = halo_dict["rho_s_msun_kpc3"]
	halo.mvir_pred = halo_dict["mvir_pred"]
	halo.mvir_pred_msun = halo_dict["mvir_pred_msun"]
	halo.cvir = halo_dict["cvir"]
	halo.rvir_kpc = halo_dict["rvir_kpc"]
	halo.delta_vir = halo_dict["delta_vir"]
	halo.rho_crit_msun_kpc3 = halo_dict["rho_crit_msun_kpc3"]
	galaxy.halo = halo

	# --- metallicity -> feh ---
	var metallicity_dict := C.sample_metallicity_profile(
		galaxy_seed, C.logx(max(m_star / C.SOLAR_MASS, 1e-6)), z
	)
	if metallicity_dict.is_empty():
		Log.error(ERR_CODE.MAP_GENERATION_FAILED, "MapGenerator.gd", "METALLICITY")
		return null
	galaxy.z_center_12_log_oh = metallicity_dict["z_center_12_log_oh"]
	galaxy.z_gradient_dex_per_kpc = metallicity_dict["gradient_dex_per_kpc"]
	galaxy.z_scatter_dex = metallicity_dict["scatter_dex"]

	var feh := C.feh_from_oh12(galaxy.z_center_12_log_oh)
	galaxy.feh_center = feh # [use] metallicity -> stellar evolution shift

	# --- Disk scale length ---
	var disk_size_dict := C.sample_disk_scale_length_from_galaxy(
		galaxy_seed, m_vir, f_baryon, f_gas, f_disk, z, halo_dict["r200c_kpc"], halo_spin
	)
	if disk_size_dict.is_empty():
		Log.error(ERR_CODE.MAP_GENERATION_FAILED, "MapGenerator.gd", "DISK_SIZE")
		return null

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

	# --- Disk thickness ---
	var disk_thickness_dict := C.sample_disk_thickness_si(
		galaxy_seed, disk_size_dict["r_d_m"], f_disk * m_star, f_gas, s_morph, z, halo_spin
	)
	if disk_thickness_dict.is_empty():
		Log.error(ERR_CODE.MAP_GENERATION_FAILED, "MapGenerator.gd", "DISK_THICKNESS")
		return null

	var disk_thickness := DiskThickness.new()
	disk_thickness.z0_m = disk_thickness_dict["z0_m"]
	disk_thickness.z0_kpc = disk_thickness_dict["z0_kpc"]
	disk_thickness.q_z0_over_rd = disk_thickness_dict["q_z0_over_rd"]
	disk_thickness.sigma_logit = disk_thickness_dict["sigma_logit"]
	galaxy.disk_thickness = disk_thickness

	# --- Bulge profile ---
	var bulge_profile_dict := C.sample_bulge_profile_from_galaxy(
		galaxy_seed, m_vir, f_baryon, f_gas, f_bulge, s_morph, z, halo_dict["r200c_kpc"]
	)
	if bulge_profile_dict.is_empty():
		Log.error(ERR_CODE.MAP_GENERATION_FAILED, "MapGenerator.gd", "BULGE_PROFILE")
		return null

	var bulge_profile := BulgeProfile.new()
	bulge_profile.n_sersic = bulge_profile_dict["n_sersic"]
	bulge_profile.r_eff_kpc = bulge_profile_dict["r_eff_kpc"]
	bulge_profile.r_eff_m = bulge_profile_dict["r_eff_m"]
	bulge_profile.log10_r_eff_kpc = bulge_profile_dict["log10_r_eff_kpc"]
	bulge_profile.sigma_dex_re = bulge_profile_dict["sigma_dex_re"]
	bulge_profile.sigma_logit_n = bulge_profile_dict["sigma_logit_n"]
	bulge_profile.halo_soft_prior = bulge_profile_dict["halo_soft_prior"]
	galaxy.bulge_profile = bulge_profile

	# --- Accretion disk (SMBH) ---
	var accretion_disk_dict := C.sample_accretion_disk_from_galaxy(
		galaxy_seed, m_vir, f_baryon, f_gas, f_bulge, s_morph, z
	)

	var accretion_disk := AccretionDiskData.new()
	accretion_disk.has_bh = accretion_disk_dict["has_bh"]
	accretion_disk.p_bh_exist = accretion_disk_dict["p_bh_exist"]
	accretion_disk.has_disk = accretion_disk_dict["has_disk"]
	accretion_disk.p_disk = accretion_disk_dict["p_disk"]
	accretion_disk.p_bh_mass = accretion_disk_dict["p_bh_mass"]
	accretion_disk.p_fuel = accretion_disk_dict["p_fuel"]
	accretion_disk.m_bh_kg = accretion_disk_dict["m_bh_kg"]
	accretion_disk.log10_m_bh_msun = accretion_disk_dict["log10_m_bh_msun"]
	accretion_disk.spin_a = accretion_disk_dict["spin_a"]
	accretion_disk.eta_rad = accretion_disk_dict["eta_rad"]
	accretion_disk.log10_lambda_proxy = accretion_disk_dict["log10_lambda_proxy"]
	accretion_disk.p_coherent = accretion_disk_dict["p_coherent"]
	accretion_disk.r_out_rg = accretion_disk_dict["r_out_rg"]
	galaxy.accretion_disk = accretion_disk

	# --- AGN properties ---
	var agn_dict := C.sample_agn_properties(
		galaxy_seed,
		accretion_disk_dict["log10_m_bh_msun"],
		accretion_disk_dict["log10_lambda_proxy"],
		accretion_disk_dict["has_bh"],
		accretion_disk_dict["has_disk"],
		f_gas
	)

	accretion_disk.log10_l_bol_lsun = agn_dict["log10_l_bol_lsun"]
	accretion_disk.log10_l_edd_lsun = agn_dict["log10_l_edd_lsun"]
	accretion_disk.is_obscured = agn_dict["is_obscured"]
	accretion_disk.p_obscured = agn_dict["p_obscured"]
	accretion_disk.agn_class = agn_dict["agn_class"]

	# --- Jet properties ---
	var jet_dict := C.sample_jet_properties(
		galaxy_seed,
		accretion_disk_dict["log10_m_bh_msun"],
		accretion_disk_dict["spin_a"],
		accretion_disk_dict["log10_lambda_proxy"],
		accretion_disk_dict["eta_rad"],
		accretion_disk_dict["has_bh"],
		accretion_disk_dict["has_disk"]
	)
	accretion_disk.has_jet = jet_dict["has_jet"]
	accretion_disk.p_jet = jet_dict["p_jet"]
	accretion_disk.log10_p_jet_w = jet_dict["log10_p_jet_w"]
	accretion_disk.jet_morphology = jet_dict["jet_morphology"]
	accretion_disk.jet_lorentz = jet_dict["jet_lorentz"]
	accretion_disk.jet_half_angle_deg = jet_dict["jet_half_angle_deg"]

	# --- Stellar population : SFR ---
	var sfr_dict := C.sample_sfr_from_galaxy(
		galaxy_seed,
		m_star,
		z,
		f_gas,
		delta_physics,
		accretion_disk.log10_lambda_proxy,
		accretion_disk.has_jet,
		accretion_disk.log10_p_jet_w
	)
	if sfr_dict.is_empty():
		Log.error(ERR_CODE.MAP_GENERATION_FAILED, "MapGenerator.gd", "SFR")
		return null
	galaxy.sfr_msun_per_yr = sfr_dict["sfr_msun_per_yr"]
	galaxy.log10_sfr_msun_per_yr = sfr_dict["log10_sfr_msun_per_yr"]
	galaxy.log10_sfr_sfms_msun_per_yr = sfr_dict["log10_sfr_sfms_msun_per_yr"]
	galaxy.log10_sfr_quench_correction = sfr_dict["log10_quench_correction"]

	# --- Stellar population : metallicity profile ---
	# [use] feh -> stellar evolution
	galaxy.z_center_12_log_oh = metallicity_dict["z_center_12_log_oh"]
	galaxy.z_gradient_dex_per_kpc = metallicity_dict["gradient_dex_per_kpc"]
	galaxy.z_scatter_dex = metallicity_dict["scatter_dex"]

	# --- Phase 7: galaxy field / star distribution ---
	var m_star_msun: float = m_star / C.SOLAR_MASS
	var m_disk_msun: float = (f_disk * m_star) / C.SOLAR_MASS
	var m_bulge_msun: float = (f_bulge * m_star) / C.SOLAR_MASS
	var m_gas_msun: float = m_gas / C.SOLAR_MASS # [use] m_gas -> StarPhysics IMF bias

	var galaxy_field_dict: Dictionary = GalaxyField.build_galaxy_field(
		galaxy_seed,
		halo,
		m_star_msun,
		m_disk_msun,
		m_bulge_msun,
		disk_size.r_d_kpc,
		bulge_profile.r_eff_kpc,
		bulge_profile.n_sersic,
		f_disk,
		f_bulge,
		f_star_halo,    # 추가 ← galaxy.f_star_halo과 동일 값
		galaxy_type,
		f_gas,
		age_gyr,
		feh,
		halo_spin,
		m_gas_msun,
		base_n_star
	)

	var galaxy_field = GalaxyFieldData.new()
	galaxy_field.spiral = galaxy_field_dict["spiral"]
	galaxy_field.n_star = galaxy_field_dict["n_star"]
	galaxy_field.rotation_curve = galaxy_field_dict["rotation_curve"]
	galaxy_field.toomre_profile = galaxy_field_dict["toomre_profile"]
	galaxy_field.stable_inner_radius_kpc = galaxy_field_dict["stable_inner_radius_kpc"]
	galaxy_field.positions_kpc = galaxy_field_dict["positions_kpc"]
	galaxy_field.star_population = galaxy_field_dict["star_population"] # [use] StarPhysics output
	galaxy.galaxy_field = galaxy_field

	_log_galaxy(galaxy)
	return galaxy

static func _log_galaxy(galaxy: GalaxyData) -> void:
	if not OS.is_debug_build():
		return
	Log.info("=== GalaxyData (seed: %s) ===" % galaxy.galaxy_seed)
	Log.info("  base_n_star: %s" % galaxy.base_n_star)
	Log.info("  z_form: %s" % galaxy.z_form)
	Log.info("  age_gyr: %s" % galaxy.age_gyr)
	Log.info("  halo_spin: %s" % galaxy.halo_spin)
	Log.info("  feh_center: %s" % galaxy.feh_center)
	Log.info("  type: %s" % galaxy.type)
	Log.info("  m_vir / MILKYWAY: %s" % (galaxy.m_vir / C.MILKYWAY_MASS))
	Log.info("  m_gas: %s" % galaxy.m_gas)
	Log.info("  f_baryon: %s" % galaxy.f_baryon)
	Log.info("  f_gas: %s " % galaxy.f_gas)
	Log.info("  f_bulge: %s" % galaxy.f_bulge)
	Log.info("  f_disk: %s" % galaxy.f_disk)
	Log.info("  f_star_halo: %s" % galaxy.f_star_halo)
	Log.info("  --- halo ---")
	Log.info("  m200c: %s" % galaxy.halo.m200c)
	Log.info("  m200c_msun: %s" % galaxy.halo.m200c_msun)
	Log.info("  c200: %s" % galaxy.halo.c200)
	Log.info("  r200c_kpc: %s" % galaxy.halo.r200c_kpc)
	Log.info("  rs_kpc: %s" % galaxy.halo.rs_kpc)
	Log.info("  rho_s: %s" % galaxy.halo.rho_s_msun_kpc3)
	Log.info("  mvir_pred: %s" % galaxy.halo.mvir_pred)
	Log.info("  mvir_pred_msun: %s" % galaxy.halo.mvir_pred_msun)
	Log.info("  cvir: %s" % galaxy.halo.cvir)
	Log.info("  rvir_kpc: %s" % galaxy.halo.rvir_kpc)
	Log.info("  delta_vir: %s" % galaxy.halo.delta_vir)
	Log.info("  rho_crit: %s" % galaxy.halo.rho_crit_msun_kpc3)
	Log.info("  --- disk ---")
	Log.info("  r_eff_m: %s" % galaxy.disk_size.r_eff_m)
	Log.info("  r_d_m: %s" % galaxy.disk_size.r_d_m)
	Log.info("  z0_m: %s" % galaxy.disk_thickness.z0_m)
	Log.info("  q_z0_over_rd: %s" % galaxy.disk_thickness.q_z0_over_rd)
	Log.info("  --- bulge ---")
	Log.info("  n_sersic : %s" % galaxy.bulge_profile.n_sersic)
	Log.info("  r_eff_kpc: %s" % galaxy.bulge_profile.r_eff_kpc)
	Log.info("  --- SMBH ---")
	Log.info("  has_bh: %s" % galaxy.accretion_disk.has_bh)
	Log.info("  has_disk: %s" % galaxy.accretion_disk.has_disk)
	Log.info("  log10_m_bh_msun: %s" % galaxy.accretion_disk.log10_m_bh_msun)
	Log.info("  log10_lambda: %s" % galaxy.accretion_disk.log10_lambda_proxy)
	Log.info("  p_coherent: %s" % galaxy.accretion_disk.p_coherent)
	Log.info("  r_out_rg: %s" % galaxy.accretion_disk.r_out_rg)
	Log.info("  spin_a: %s" % galaxy.accretion_disk.spin_a)
	Log.info("  eta_rad: %s" % galaxy.accretion_disk.eta_rad)
	Log.info("  agn_class: %s" % galaxy.accretion_disk.agn_class)
	Log.info("  log10_l_bol_lsun: %s" % galaxy.accretion_disk.log10_l_bol_lsun)
	Log.info("  has_jet: %s" % galaxy.accretion_disk.has_jet)
	Log.info("  jet_morphology: %s" % galaxy.accretion_disk.jet_morphology)
	Log.info("  log10_p_jet_w: %s" % galaxy.accretion_disk.log10_p_jet_w)
	Log.info("  jet_lorentz: %s"       % galaxy.accretion_disk.jet_lorentz)
	Log.info("  --- stellar population ---")
	Log.info("  sfr [Msun/yr]: %s" % galaxy.sfr_msun_per_yr)
	Log.info("  log10_sfr: %s" % galaxy.log10_sfr_msun_per_yr)
	Log.info("  log10_sfr_sfms: %s" % galaxy.log10_sfr_sfms_msun_per_yr)
	Log.info("  log10_quench: %s" % galaxy.log10_sfr_quench_correction)
	Log.info("  Z_center (12+logO/H): %s" % galaxy.z_center_12_log_oh)
	Log.info("  Z_gradient [dex/kpc]: %s" % galaxy.z_gradient_dex_per_kpc)
	Log.info("  Z_scatter [dex]: %s" % galaxy.z_scatter_dex)
	Log.info("  spiral: %s" % galaxy.galaxy_field.spiral)
	Log.info("  n_star: %s" % galaxy.galaxy_field.n_star)
	Log.info("  stable_inner_radius_kpc: %s" % galaxy.galaxy_field.stable_inner_radius_kpc)
	#Log.info("  star_population: %s" % galaxy.galaxy_field.star_population)
