class_name C

enum MERSENNE {
	CONST_1 = 131017,
	CONST_2 = 524287,
	CONST_3 = 82589933
}

#Scenes
const MAX_LOADING_FRAMES: int = 1800

const SCENE_MAIN_PATH = "res://scenes/Main.tscn"
const SCENE_LOADING_PATH = "res://scenes/Loading.tscn"
const SCENE_MAINMENU_PATH = "res://scenes/MainMenu.tscn"
const SCENE_INGAME_PATH = "res://scenes/Ingame.tscn"
const SCENE_SETTINGS_PATH = "res://scenes/Settings.tscn"


const GOLDEN_ANGLE: float = 2.399963229728653

# kg
const EARTH_MASS: float = 5.97219e24
const SOLAR_MASS: float = 1.98847e30
const MILKYWAY_MASS: float = 1.15e12 * SOLAR_MASS

# m
const AU: float = 149_597_870_700
const LY: float = 9_460_730_472_580_800


const M_GAL_MU: float = log(MILKYWAY_MASS / SOLAR_MASS) / log(10.0)
const M_GAL_SIGMA: float = 0.8


const RD_MTP: float = 0.2


static func logx(x: float, base: float = 10.0) -> float:
	return log(x) / log(base)
	

static func log_msun(mass): # Log Normalization M/MSUN
	return C.logx(mass/SOLAR_MASS) 
	
	
static func sigmoid(x: float) -> float:
	return 1.0 / (1.0 + exp(-x))


static func logit(p: float) -> float:
	p = clamp(p, 1e-6, 1.0 - 1e-6)
	return log(p / (1.0 - p))
	

static func hash_int(p_seed: int, purpose: int, index: int = 0) -> int:
	var x := p_seed & 0xFFFFFFFF
	x ^= (purpose * 0x9e3779b9) & 0xFFFFFFFF
	x ^= (index * 0x85ebca6b) & 0xFFFFFFFF

	x = (x ^ (x >> 16)) & 0xFFFFFFFF
	x = (x * 0x7feb352d) & 0xFFFFFFFF
	x = (x ^ (x >> 15)) & 0xFFFFFFFF
	x = (x * 0x846ca68b) & 0xFFFFFFFF
	x = (x ^ (x >> 16)) & 0xFFFFFFFF

	return x

static func hash_float(p_seed: int, purpose: int, index: int = 0) -> float:
	return float(hash_int(p_seed, purpose, index)) / 4294967296.0
	

enum HashPurpose {
	GALAXY,
	SYSTEM,
	GALAXY_BARYON,
	GALAXY_GAS,
	GALAXY_GAS_DELTA_PHYSICS,
	GALAXY_STAR_HALO,
	GALAXY_MORPHOLOGY
}

# f_baryon
static func get_Z(u1: float, u2: float) -> float: # 표준정규분포시드
		u1 = max(u1, 1e-9)
		return sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)		


static func _f_baryon_zero(mass: float) -> float:
	const M_0: float = 12.0 # ~12
	const SIGMA_B: float = 1.0 # ~1.0-1.5
	const F_COSMIC: float = 0.157 # ~~0.157
	
	var diff = log_msun(mass) - M_0
	var exponent = -(diff * diff) / (2.0 * SIGMA_B * SIGMA_B)
	return F_COSMIC * exp(exponent)


static func f_baryon(galaxy_seed: int, galaxy_mass: float) -> float:
	const SIGMA_B_SC: float = 0.1
	
	var u1 = hash_float(galaxy_seed, HashPurpose.GALAXY_BARYON, 0)
	var u2 = hash_float(galaxy_seed, HashPurpose.GALAXY_BARYON, 1)
	var Z_b = get_Z(u1, u2)
	
	var x = logit(_f_baryon_zero(galaxy_mass)) + SIGMA_B_SC * Z_b
	
	return sigmoid(x)
	
# f_gas
static func _mu_gas(mass: float) -> float: # m_baryon
	const a: float = -0.9
	const m_1: float = 10.8

	return a * (log_msun(mass) - m_1)
	
	
static func Delta_physics(galaxy_seed: int) -> float:
	var u1 = hash_float(galaxy_seed, HashPurpose.GALAXY_GAS_DELTA_PHYSICS, 0)
	var u2 = hash_float(galaxy_seed, HashPurpose.GALAXY_GAS_DELTA_PHYSICS, 1)
	var u3 = hash_float(galaxy_seed, HashPurpose.GALAXY_GAS_DELTA_PHYSICS, 2)
	var u4 = hash_float(galaxy_seed, HashPurpose.GALAXY_GAS_DELTA_PHYSICS, 3)
	var u5 = hash_float(galaxy_seed, HashPurpose.GALAXY_GAS_DELTA_PHYSICS, 4)
	var u6 = hash_float(galaxy_seed, HashPurpose.GALAXY_GAS_DELTA_PHYSICS, 5)

	var Z_lambda = get_Z(u1, u2)
	var Z_sf     = get_Z(u3, u4)
	var Z_morph  = get_Z(u5, u6)

	return 0.40 * Z_lambda - 0.25 * Z_sf + 0.30 * Z_morph


static func f_gas(galaxy_seed: int, m_baryon: float) -> float:
	const SIGMA_G_SC: float = 0.1
	
	var u1 = hash_float(galaxy_seed, HashPurpose.GALAXY_GAS, 0)
	var u2 = hash_float(galaxy_seed, HashPurpose.GALAXY_GAS, 1)
	var Z_g = get_Z(u1, u2)
	
	var x = _mu_gas(m_baryon) + Delta_physics(galaxy_seed) + SIGMA_G_SC * Z_g
	
	return sigmoid(x)
	

static func f_star_halo(galaxy_seed: int, m_star: float, f_gas_: float) -> float:
	var u1 = hash_float(galaxy_seed, HashPurpose.GALAXY_STAR_HALO, 0)
	var u2 = hash_float(galaxy_seed, HashPurpose.GALAXY_STAR_HALO, 1)
	var Z = get_Z(u1, u2)

	var logM = log_msun(m_star)
	var m_n = logM - 10.5

	var gas_logit = logit(f_gas_)

	const A0 = -2.2
	const A1 = 0.8     # mass
	const A2 = -0.6    # gas
	const SIGMA = 0.7  # >= 0.5 # scatter

	var x = A0 + A1 * m_n + A2 * gas_logit + SIGMA * Z

	return sigmoid(x)
	
	
static func f_bulge_disk(
	galaxy_seed: int,
	m_star: float,
	f_gas_: float,
	delta_physics: float,
	f_star_halo_: float
) -> Dictionary:
	
	var u1 = hash_float(galaxy_seed, HashPurpose.GALAXY_MORPHOLOGY, 0)
	var u2 = hash_float(galaxy_seed, HashPurpose.GALAXY_MORPHOLOGY, 1)
	var Z = get_Z(u1, u2)

	var logM = log_msun(m_star)
	var m_n = logM - 10.5

	var gas_logit = logit(f_gas_)

	# morphology score
	const B0 = -0.2
	const B1 = 0.7 # mass
	const B2 = 0.9 # gas (disk bias → minus later)
	const B3 = 0.5 # delta_physics
	const SIGMA = 0.4

	var s_bulge = B0 \
		+ B1 * m_n \
		- B2 * gas_logit \
		+ B3 * delta_physics \
		+ SIGMA * Z

	var p_bulge = sigmoid(s_bulge)
	var p_disk = 1.0 - p_bulge

	var f_remain = 1.0 - f_star_halo_

	var f_bulge = f_remain * p_bulge
	var f_disk  = f_remain * p_disk

	return {
		"f_bulge": f_bulge,
		"f_disk": f_disk,
		"s_morph": s_bulge
	}
	
# DM_HALO

const G_NEWTON: float = 6.67430e-11
const MPC_M: float = 3.0856775814913673e22
const MSUN_KG: float = 1.98847e30

# 필요하면 프로젝트 우주론에 맞게 바꾸세요.
const H0_KM_S_MPC: float = 67.7
const OMEGA_M0: float = 0.315
const OMEGA_L0: float = 0.685

# Dutton & Macciò (2014) scatter
const LOG10_C200_SCATTER_DEX: float = 0.11


static func omega_m_z(z: float, omega_m0: float = OMEGA_M0, omega_l0: float = OMEGA_L0) -> float:
	var ez2 := omega_m0 * pow(1.0 + z, 3.0) + omega_l0
	return omega_m0 * pow(1.0 + z, 3.0) / ez2


static func delta_vir_bn98(z: float, omega_m0: float = OMEGA_M0, omega_l0: float = OMEGA_L0) -> float:
	var x := omega_m_z(z, omega_m0, omega_l0) - 1.0
	return 18.0 * PI * PI + 82.0 * x - 39.0 * x * x


static func rho_crit_z(z: float, h0_km_s_mpc: float = H0_KM_S_MPC,
		omega_m0: float = OMEGA_M0, omega_l0: float = OMEGA_L0) -> float:
	var h0_si := h0_km_s_mpc * 1000.0 / MPC_M
	var ez2 := omega_m0 * pow(1.0 + z, 3.0) + omega_l0
	var hz := h0_si * sqrt(ez2)
	return 3.0 * hz * hz / (8.0 * PI * G_NEWTON)


static func g_nfw(x: float) -> float:
	return log(1.0 + x) - x / (1.0 + x)


static func random_normal(seed: int, purpose: int, index: int = 0) -> float:
	var u1: float = max(hash_float(seed, purpose, index * 2), 1e-12)
	var u2 := hash_float(seed, purpose, index * 2 + 1)
	return get_Z(u1, u2)


static func sample_log10_c200_mean(
	m200c: float,
	z: float = 0.0,
	h0_km_s_mpc: float = H0_KM_S_MPC
) -> float:
	# Dutton & Macciò (2014), Planck-era fit
	var h := h0_km_s_mpc / 100.0
	var a := 0.520 + (0.905 - 0.520) * exp(-0.617 * pow(z, 1.21))
	var b := -0.101 + 0.026 * z

	# relation is written in units of 1e12 h^-1 Msun
	var logm: float = log_msun(m200c) + logx(h) - 12.0
	return a + b * logm


static func sample_c200(
	galaxy_seed: int,
	m200c: float,
	z: float = 0.0,
	h0_km_s_mpc: float = H0_KM_S_MPC
) -> float:
	var mu := sample_log10_c200_mean(m200c, z, h0_km_s_mpc)
	var z_scatter := random_normal(galaxy_seed, HashPurpose.GALAXY_STAR_HALO, 0)
	var log10_c := mu + LOG10_C200_SCATTER_DEX * z_scatter
	return pow(10.0, log10_c)


static func solve_c_from_ratio(target_ratio: float) -> float:
	if not is_finite(target_ratio) or target_ratio <= 0.0:
		Log.error(100, "constans.gd")
		return NAN
	# Solve g(c)/c^3 = target_ratio
	# Monotonic for c > 0, so bisection is robust.
	var lo := 1e-4
	var hi := 1e4

	for i in range(80):
		var mid := 0.5 * (lo + hi)
		var val := g_nfw(mid) / pow(mid, 3.0)
		if val > target_ratio:
			lo = mid
		else:
			hi = mid

	return 0.5 * (lo + hi)


static func halo_state_from_m200c(
	galaxy_seed: int,
	m200c: float,
	z: float = 0.0,
	h0_km_s_mpc: float = H0_KM_S_MPC,
	omega_m0: float = OMEGA_M0,
	omega_l0: float = OMEGA_L0
) -> Dictionary:
	var rho_c := rho_crit_z(z, h0_km_s_mpc, omega_m0, omega_l0)
	var delta_vir := delta_vir_bn98(z, omega_m0, omega_l0)

	var c200 := sample_c200(galaxy_seed, m200c, z, h0_km_s_mpc)
	var g200 := g_nfw(c200)

	var r200c := pow(3.0 * m200c / (4.0 * PI * 200.0 * rho_c), 1.0 / 3.0)
	var rs := r200c / c200

	# Same NFW profile, different overdensity definition:
	# 200 * g(c200) / c200^3 = Delta_vir * g(cvir) / cvir^3
	var target_ratio := (200.0 / delta_vir) * g200 / pow(c200, 3.0)
	var cvir := solve_c_from_ratio(target_ratio)
	var gvir := g_nfw(cvir)

	var mvir_pred := m200c * gvir / g200
	var rvir := cvir * rs
	var rho_s := m200c / (4.0 * PI * pow(rs, 3.0) * g200)

	return {
		"m200c": m200c,
		"c200": c200,
		"r200c": r200c,
		"rs": rs,
		"rho_s": rho_s,
		"mvir_pred": mvir_pred,
		"cvir": cvir,
		"rvir": rvir,
		"delta_vir": delta_vir,
		"rho_crit": rho_c
	}


static func halo_state_from_mvir(
	galaxy_seed: int,
	m_vir: float,
	z: float = 0.0,
	h0_km_s_mpc: float = H0_KM_S_MPC,
	omega_m0: float = OMEGA_M0,
	omega_l0: float = OMEGA_L0
) -> Dictionary:
	# Solve for M200c so that the resulting NFW halo reproduces the requested Mvir.
	var lo := m_vir * 1e-4
	var hi := m_vir * 1e4

	var f_lo := 0.0
	var f_hi := 0.0
	
	var bracketed := false
	for _expand in range(10):
		var s_lo := halo_state_from_m200c(galaxy_seed, lo, z, h0_km_s_mpc, omega_m0, omega_l0)
		var s_hi := halo_state_from_m200c(galaxy_seed, hi, z, h0_km_s_mpc, omega_m0, omega_l0)

		f_lo = log(s_lo["mvir_pred"] / m_vir)
		f_hi = log(s_hi["mvir_pred"] / m_vir)

		if f_lo * f_hi <= 0.0:
			bracketed = true
			break

		lo *= 0.1
		hi *= 10.0
	if not bracketed:
		Log.error(101, "constants.gd")
		return {}

	# Bisection in log-space.
	var mid := m_vir
	for _i in range(64):
		mid = sqrt(lo * hi)
		var s_mid := halo_state_from_m200c(galaxy_seed, mid, z, h0_km_s_mpc, omega_m0, omega_l0)
		var f_mid := log(s_mid["mvir_pred"] / m_vir)

		if abs(f_mid) < 1e-8:
			return s_mid

		if f_lo * f_mid <= 0.0:
			hi = mid
			f_hi = f_mid
		else:
			lo = mid
			f_lo = f_mid

	var result := halo_state_from_m200c(galaxy_seed, mid, z, h0_km_s_mpc, omega_m0, omega_l0)
	result["mvir_input"] = m_vir
	return result
