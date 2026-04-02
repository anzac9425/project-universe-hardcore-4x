class_name C

#Scenes
const MAX_LOADING_FRAMES: int = 1800

const SCENE_MAIN_PATH = "res://scenes/Main.tscn"
const SCENE_LOADING_PATH = "res://scenes/Loading.tscn"
const SCENE_MAINMENU_PATH = "res://scenes/MainMenu.tscn"
const SCENE_INGAME_PATH = "res://scenes/Ingame.tscn"
const SCENE_SETTINGS_PATH = "res://scenes/Settings.tscn"

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
	

static func log_msun(mass: float) -> float: # Log Normalization M/MSUN
	if mass <= 0.0:
		Log.error(102, "constants.gd")
		return NAN
	return C.logx(mass / SOLAR_MASS)
	
	
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
	GALAXY_MORPHOLOGY,
	GALAXY_HALO_CONCENTRATION_SCATTER,
	GALAXY_DISK_SCALE_LENGTH,
	GALAXY_DISK_THICKNESS,
	GALAXY_BULGE_SERSIC,
	GALAXY_BULGE_SIZE,
	GALAXY_BH_MASS,
	GALAXY_ACCRETION_SPIN,
	GALAXY_ACCRETION_MODE,
	GALAXY_ACCRETION_OUTER_RADIUS,
	GALAXY_ACCRETION_EXISTENCE,
	GALAXY_ACCRETION_EDD_RATIO,
	GALAXY_AGN_OBSCURATION,   # Type 1/2 차폐 샘플링
	GALAXY_JET,               # 제트 존재 여부 + 산포
	GALAXY_JET_LORENTZ,       # 로렌츠 인수 산포
	GALAXY_SFR,               # SFMS + quenching 산포
	GALAXY_METALLICITY,        # 금속도 중심값/gradient 산포
	GALAXY_SPIRAL_ARM_COUNT,   # 나선팔 개수 샘플링
	GALAXY_SPIRAL_PITCH,       # 피치각 샘플링
	GALAXY_SPIRAL_CONTRAST,    # 팔 강도 샘플링
	GALAXY_SPIRAL_PHASE,       # 팔 위상 오프셋 샘플링
	GALAXY_STAR_COMPONENT,     # 디스크 vs 벌지 구성요소 선택
	GALAXY_STAR_R_DISK,        # 디스크 별 반경 샘플링 (Gamma)
	GALAXY_STAR_R_BULGE,       # 벌지 별 반경 rejection sampling
	GALAXY_STAR_PHI_MODE,      # 방위각 모드 (균일 vs 나선팔)
	GALAXY_STAR_PHI_UNIFORM,   # 균일 방위각
	GALAXY_STAR_PHI_ARM_SEL,   # 팔 인덱스 선택
	GALAXY_STAR_PHI_ARM_JIT,   # 팔 중심 주변 가우시안 산포
	GALAXY_Z_FORM,   # [use] z_form sampling
	GALAXY_HALO_SPIN,# [use] halo spin sampling
	STAR_MASS        # [use] IMF star mass sampling
}


const SOLAR_OH12: float = 8.69 # [use] feh = (12+log(O/H)) - solar zero-point

static func e_z(z: float, omega_m0: float = OMEGA_M0, omega_l0: float = OMEGA_L0) -> float:
	var ez2 := omega_m0 * pow(1.0 + z, 3.0) + omega_l0
	return sqrt(ez2)

static func hubble_time_gyr(h0_km_s_mpc: float = H0_KM_S_MPC) -> float:
	# 9.778 Gyr at H0=100 km/s/Mpc
	return 9.778 / (h0_km_s_mpc / 100.0)

static func lookback_time_gyr_from_z(
	z: float,
	h0_km_s_mpc: float = H0_KM_S_MPC,
	omega_m0: float = OMEGA_M0,
	omega_l0: float = OMEGA_L0
) -> float:
	# [use] z_form -> age_gyr 변환용
	z = max(z, 0.0)
	if z < 1e-9:
		return 0.0

	var n: int = 256
	var h := z / float(n)
	var sum := 0.0

	for i in range(n + 1):
		var zz := h * float(i)
		var weight := 1.0
		if i != 0 and i != n:
			weight = 4.0 if (i % 2 == 1) else 2.0
		sum += weight / ((1.0 + zz) * e_z(zz, omega_m0, omega_l0))

	return hubble_time_gyr(h0_km_s_mpc) * h * sum / 3.0

static func feh_from_oh12(oh12: float, solar_oh12: float = SOLAR_OH12) -> float:
	# [use] metallicity(OH) -> stellar evolution metallicity proxy
	return oh12 - solar_oh12

static func sample_z_form(galaxy_seed: int) -> float:
	# [use] formation redshift prior from the user's spec:
	# z_form ~ LogNormal(mu=0.8, sigma=0.5)
	var z_scatter := random_normal(galaxy_seed, HashPurpose.GALAXY_Z_FORM, 0)
	return max(exp(0.8 + 0.5 * z_scatter), 0.05)

static func sample_halo_spin(galaxy_seed: int) -> float:
	# [use] halo_spin -> disk size/shape
	# Bullock-style lognormal spin proxy; mean ~0.035.
	var z_spin := random_normal(galaxy_seed, HashPurpose.GALAXY_HALO_SPIN, 0)
	return clamp(exp(log(0.035) + 0.55 * z_spin), 0.005, 0.15)

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

	return 0.28 * Z_lambda - 0.18 * Z_sf + 0.22 * Z_morph


# GAS FRACTION RE-DESIGN
# -------------------------------------------------------------------
# Interpretation:
# - f_gas = M_gas / (M_gas + M_star)
# - This is a cold-gas proxy, not strictly HI-only or H2-only.
# - Uses a self-consistent fixed-point solve because M_star depends on f_gas.

static func _mu_gas_log10(
	logMstar: float,
	z: float,
	delta_physics: float
) -> float:
	# Tuned to observed trends:
	# - stronger gas fractions at lower M*
	# - stronger gas fractions at higher z
	# - mild boost from the existing "delta_physics" latent state
	#
	# This is a proxy relation, not a direct transcription of a single survey fit.

	const LOG10_MU0: float = -0.40   # baseline at M*=10^10.5 Msun, z=0
	const A_Z: float = 1.85          # between local xGASS and higher-z PHIBSS trends
	const A_M: float = -0.55         # steeper than pure molecular scaling because this is cold gas
	const A_DPHYS: float = 0.25      # mild structural / fueling boost

	return LOG10_MU0 \
		+ A_Z * logx(1.0 + z) \
		+ A_M * (logMstar - 10.5) \
		+ A_DPHYS * delta_physics


static func f_gas(
	galaxy_seed: int,
	m_vir_kg: float,
	f_baryon_: float,
	z: float = 0.0,
	delta_physics: float = 0.0
) -> float:
	const F_MIN: float = 0.01
	const F_MAX: float = 0.95
	const MIX: float = 0.35
	const N_ITER: int = 15

	if not is_finite(m_vir_kg) or m_vir_kg <= 0.0:
		Log.error(107, "res://scripts/core/constants.gd")
		return NAN

	if not is_finite(f_baryon_) or f_baryon_ <= 0.0:
		Log.error(108, "res://scripts/core/constants.gd")
		return NAN

	# deterministic scatter for gas content
	var z_scatter := random_normal(galaxy_seed, HashPurpose.GALAXY_GAS, 0)

	# initial guess
	var f_gas_est := 0.45

	for _i in range(N_ITER):
		var m_star_kg: float = max(m_vir_kg * f_baryon_ * (1.0 - f_gas_est), 1e-12)
		var logMstar := logx(m_star_kg / SOLAR_MASS)

		var log10_mu := _mu_gas_log10(logMstar, z, delta_physics) \
			+ 0.20 * z_scatter

		var mu := pow(10.0, log10_mu)
		var f_target: float = clamp(mu / (1.0 + mu), F_MIN, F_MAX)

		f_gas_est = lerp(f_gas_est, f_target, MIX)

	return clamp(f_gas_est, F_MIN, F_MAX)
	

static func f_star_halo(galaxy_seed: int, m_star: float, f_gas_: float) -> float:
	var u1 = hash_float(galaxy_seed, HashPurpose.GALAXY_STAR_HALO, 0)
	var u2 = hash_float(galaxy_seed, HashPurpose.GALAXY_STAR_HALO, 1)
	var Z = get_Z(u1, u2)

	var logM = log_msun(m_star)
	var m_n = logM - 10.5

	var gas_logit = logit(f_gas_)

	const A0 = -2.2
	const A1 = 0.5     # mass
	const A2 = 0.0    # gas
	const SIGMA = 0.6  # scatter

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

	# Observational anchors:
	# - intermediate-mass local SF galaxies: B/T typically below ~0.3
	# - massive SF galaxies above ~1e11 Msun: B/T ~0.4-0.5
	# - B/T decreases as galaxies move upward in the SFMS / become more gas-rich
	var mass_term = tanh((logM - 10.9) / 0.75)
	var gas_term = tanh((logit(f_gas_) + 0.4) / 1.0)
	var phys_term = tanh(delta_physics / 0.6)

	const B0: float = -1.05
	const B1: float = 0.45
	const B2: float = 0.55
	const B3: float = -0.20
	const SIGMA: float = 0.25

	var s_bulge = B0 \
		+ B1 * mass_term \
		- B2 * gas_term \
		+ B3 * phys_term \
		+ SIGMA * Z

	var p_bulge = sigmoid(s_bulge)

	var f_remain = 1.0 - f_star_halo_
	var f_bulge = f_remain * p_bulge
	var f_disk  = f_remain * (1.0 - p_bulge)

	return {
		"f_bulge": f_bulge,
		"f_disk": f_disk,
		"s_morph": s_bulge
	}
	
# DM_HALO
# Internal units:
# - mass: Msun
# - distance: kpc
# - density: Msun / kpc^3
# - H0: km/s/Mpc as input, converted internally to km/s/kpc

const G_KPC_KM2_S2_MSUN: float = 4.30091727003628e-6 # kpc (km/s)^2 / Msun

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


static func rho_crit_z(
		z: float,
		h0_km_s_mpc: float = H0_KM_S_MPC,
		omega_m0: float = OMEGA_M0,
		omega_l0: float = OMEGA_L0
	) -> float:
	# Return value: Msun / kpc^3
	# H0 input is km/s/Mpc, convert to km/s/kpc
	var h0_km_s_kpc := h0_km_s_mpc / 1000.0
	var ez2 := omega_m0 * pow(1.0 + z, 3.0) + omega_l0
	var hz_km_s_kpc := h0_km_s_kpc * sqrt(ez2)

	# rho_crit = 3 H^2 / (8 pi G)
	# with H in km/s/kpc and G in kpc (km/s)^2 / Msun
	return 3.0 * hz_km_s_kpc * hz_km_s_kpc / (8.0 * PI * G_KPC_KM2_S2_MSUN)


static func g_nfw(x: float) -> float:
	return log(1.0 + x) - x / (1.0 + x)


static func random_normal(seed_: int, purpose: int, index: int = 0) -> float:
	var u1: float = max(hash_float(seed_, purpose, index * 2), 1e-12)
	var u2 := hash_float(seed_, purpose, index * 2 + 1)
	return get_Z(u1, u2)


static func sample_log10_c200_mean(
	m200c_kg: float,
	z: float = 0.0,
	h0_km_s_mpc: float = H0_KM_S_MPC
) -> float:
	var h := h0_km_s_mpc / 100.0
	var m200c_msun := m200c_kg / SOLAR_MASS
	var logm: float = logx(m200c_msun) - 12.0 + logx(h)
	var a := 0.520 + (0.905 - 0.520) * exp(-0.617 * pow(z, 1.21))
	var b := -0.101 + 0.026 * z
	return a + b * logm


static func sample_c200(
	galaxy_seed: int,
	m200c: float,
	z: float = 0.0,
	h0_km_s_mpc: float = H0_KM_S_MPC
) -> float:
	var mu := sample_log10_c200_mean(m200c, z, h0_km_s_mpc)
	var z_scatter := random_normal(galaxy_seed, HashPurpose.GALAXY_HALO_CONCENTRATION_SCATTER, 0)
	var log10_c := mu + LOG10_C200_SCATTER_DEX * z_scatter
	return pow(10.0, log10_c)


static func solve_c_from_ratio(target_ratio: float) -> float:
	if not is_finite(target_ratio) or target_ratio <= 0.0:
		Log.error(100, "res://scripts/core/constants.gd")
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
	# 입력 m200c는 kg라고 가정
	# 내부 계산은 Msun으로 통일
	var m200c_msun := m200c / SOLAR_MASS

	var rho_c := rho_crit_z(z, h0_km_s_mpc, omega_m0, omega_l0)
	var delta_vir := delta_vir_bn98(z, omega_m0, omega_l0)

	var c200 := sample_c200(galaxy_seed, m200c, z, h0_km_s_mpc)
	var g200 := g_nfw(c200)

	var r200c := pow(3.0 * m200c_msun / (4.0 * PI * 200.0 * rho_c), 1.0 / 3.0)
	var rs := r200c / c200

	var target_ratio := (delta_vir / 200.0) * g200 / pow(c200, 3.0)
	var cvir := solve_c_from_ratio(target_ratio)
	var gvir := g_nfw(cvir)

	var mvir_pred_msun := m200c_msun * gvir / g200
	var rvir := cvir * rs
	var rho_s := m200c_msun / (4.0 * PI * pow(rs, 3.0) * g200)

	return {
		"m200c": m200c,                 # 원본 kg
		"m200c_msun": m200c_msun,       # 내부 계산용
		"c200": c200,
		"r200c_kpc": r200c,
		"rs_kpc": rs,
		"rho_s_msun_kpc3": rho_s,
		"mvir_pred": mvir_pred_msun * SOLAR_MASS,  # 반환은 kg로 유지
		"mvir_pred_msun": mvir_pred_msun,
		"cvir": cvir,
		"rvir_kpc": rvir,
		"delta_vir": delta_vir,
		"rho_crit_msun_kpc3": rho_c
	}


static func halo_state_from_mvir(
	galaxy_seed: int,
	m_vir: float,
	z: float = 0.0,
	h0_km_s_mpc: float = H0_KM_S_MPC,
	omega_m0: float = OMEGA_M0,
	omega_l0: float = OMEGA_L0
) -> Dictionary:
	# 입력 m_vir는 kg
	var m_vir_msun := m_vir / SOLAR_MASS

	var lo := m_vir_msun * 1e-4
	var hi := m_vir_msun * 1e4

	var f_lo := 0.0
	var f_hi := 0.0
	var bracketed := false

	for _expand in range(10):
		var s_lo := halo_state_from_m200c(galaxy_seed, lo * SOLAR_MASS, z, h0_km_s_mpc, omega_m0, omega_l0)
		var s_hi := halo_state_from_m200c(galaxy_seed, hi * SOLAR_MASS, z, h0_km_s_mpc, omega_m0, omega_l0)

		f_lo = log(s_lo["mvir_pred_msun"] / m_vir_msun)
		f_hi = log(s_hi["mvir_pred_msun"] / m_vir_msun)

		if f_lo * f_hi <= 0.0:
			bracketed = true
			break

		lo *= 0.1
		hi *= 10.0

	if not bracketed:
		Log.error(101, "res://scripts/core/constants.gd")
		return {}

	var mid := m_vir_msun
	for _i in range(64):
		mid = sqrt(lo * hi)
		var s_mid := halo_state_from_m200c(galaxy_seed, mid * SOLAR_MASS, z, h0_km_s_mpc, omega_m0, omega_l0)
		var f_mid := log(s_mid["mvir_pred_msun"] / m_vir_msun)

		if abs(f_mid) < 1e-8:
			return s_mid

		if f_lo * f_mid <= 0.0:
			hi = mid
			f_hi = f_mid
		else:
			lo = mid
			f_lo = f_mid

	var result := halo_state_from_m200c(galaxy_seed, mid * SOLAR_MASS, z, h0_km_s_mpc, omega_m0, omega_l0)
	result["mvir_input"] = m_vir
	result["mvir_input_msun"] = m_vir_msun
	return result

# DISK LENGTH
static func sample_disk_scale_length_si(
	galaxy_seed: int,
	m_disk_star_kg: float,
	z: float = 0.0,
	r200c_kpc: float = -1.0,
	halo_spin: float = 0.035
) -> Dictionary:
	# [use] halo_spin -> disk size scaling
	# Observational size-mass relation + Mo, Mao & White spin modulation.
	const KPC_M: float = 3.0856775814913673e19
	const MREF_KG: float = 5.0e10 * C.SOLAR_MASS
	const Z_REF: float = 0.25

	const LOG10_A_REF_KPC: float = 0.86
	const ALPHA_M: float = 0.25
	const BETA_Z: float = -0.75
	const SIGMA_DEX_RE: float = 0.16

	if not is_finite(m_disk_star_kg) or m_disk_star_kg <= 0.0:
		Log.error(103, "res://scripts/core/constants.gd")
		return {}

	var u1: float = max(C.hash_float(galaxy_seed, C.HashPurpose.GALAXY_DISK_SCALE_LENGTH, 0), 1e-12)
	var u2 := C.hash_float(galaxy_seed, C.HashPurpose.GALAXY_DISK_SCALE_LENGTH, 1)
	var z_scatter := C.get_Z(u1, u2)

	var spin_boost: float = clamp(halo_spin, 0.005, 0.15) / 0.035

	var log10_reff_kpc := LOG10_A_REF_KPC \
		+ ALPHA_M * C.logx(m_disk_star_kg / MREF_KG) \
		+ BETA_Z * C.logx((1.0 + z) / (1.0 + Z_REF)) \
		+ C.logx(spin_boost)

	var log10_reff_kpc_sampled := log10_reff_kpc + SIGMA_DEX_RE * z_scatter
	var reff_kpc := pow(10.0, log10_reff_kpc_sampled)
	var rd_kpc := reff_kpc / 1.678

	var rd_halo_check_m := NAN
	var reff_halo_check_m := NAN
	if is_finite(r200c_kpc) and r200c_kpc > 0.0:
		reff_halo_check_m = 0.015 * r200c_kpc * KPC_M
		rd_halo_check_m = (0.015 * r200c_kpc / 1.678) * KPC_M

	return {
		"r_eff_m": reff_kpc * KPC_M,
		"r_d_m": rd_kpc * KPC_M,
		"r_eff_kpc": reff_kpc,
		"r_d_kpc": rd_kpc,
		"log10_r_eff_kpc": log10_reff_kpc_sampled,
		"log10_r_d_kpc": log10_reff_kpc_sampled - C.logx(1.678),
		"r_eff_halo_check_m": reff_halo_check_m,
		"r_d_halo_check_m": rd_halo_check_m,
		"sigma_dex": SIGMA_DEX_RE
	}

static func sample_disk_scale_length_from_galaxy(
	galaxy_seed: int,
	m_vir_kg: float,
	f_baryon_: float,
	f_gas_: float,
	f_disk: float,
	z: float = 0.0,
	r200c_kpc: float = -1.0,
	halo_spin: float = 0.035
) -> Dictionary:
	# [use] halo_spin -> size scaling
	var m_star_total_kg := m_vir_kg * f_baryon_ * (1.0 - f_gas_)
	var m_disk_star_kg: float = m_star_total_kg * clamp(f_disk, 1e-6, 1.0)
	return sample_disk_scale_length_si(galaxy_seed, m_disk_star_kg, z, r200c_kpc, halo_spin)

#DISK THICKNESS
static func sample_disk_thickness_si(
	galaxy_seed: int,
	r_d_m: float,
	m_disk_star_kg: float,
	f_gas_: float,
	s_morph: float,
	z: float = 0.0,
	halo_spin: float = 0.035
) -> Dictionary:
	const KPC_M: float = 3.0856775814913673e19

	if not is_finite(r_d_m) or r_d_m <= 0.0:
		Log.error(104, "res://scripts/core/constants.gd")
		return {}

	if not is_finite(m_disk_star_kg) or m_disk_star_kg <= 0.0:
		Log.error(105, "res://scripts/core/constants.gd")
		return {}

	# [use] halo_spin -> disk thickness shape
	const Q0: float = 0.12
	const Q_MIN: float = 0.03
	const Q_MAX: float = 0.50
	const SIGMA_LOGIT: float = 0.35

	var p_bulge := C.sigmoid(s_morph)
	var logM := C.logx(m_disk_star_kg / C.SOLAR_MASS)
	var gas_logit := C.logit(clamp(f_gas_, 1e-6, 1.0 - 1e-6))

	var u1: float = max(C.hash_float(galaxy_seed, C.HashPurpose.GALAXY_DISK_THICKNESS, 0), 1e-12)
	var u2 := C.hash_float(galaxy_seed, C.HashPurpose.GALAXY_DISK_THICKNESS, 1)
	var z_scatter := C.get_Z(u1, u2)

	var spin_term := -0.12 * C.logx(clamp(halo_spin, 0.005, 0.15) / 0.035)

	var x := C.logit((Q0 - Q_MIN) / (Q_MAX - Q_MIN)) \
		+ 1.10 * (p_bulge - 0.30) \
		- 0.90 * (gas_logit - C.logit(0.30)) \
		+ 0.10 * (logM - 10.5) \
		+ 0.3 * C.logx(1.0 + z) \
		+ spin_term \
		+ SIGMA_LOGIT * z_scatter

	var q: float = Q_MIN + (Q_MAX - Q_MIN) * C.sigmoid(x)
	var z0_m := q * r_d_m

	return {
		"z0_m": z0_m,
		"z0_kpc": z0_m / KPC_M,
		"q_z0_over_rd": q,
		"sigma_logit": SIGMA_LOGIT
	}

# BULGE SERSIC + SIZE
static func sample_bulge_profile_si(
	galaxy_seed: int,
	m_bulge_star_kg: float,
	f_bulge_: float,
	s_morph: float,
	z: float = 0.0,
	r200c_kpc: float = -1.0
) -> Dictionary:
	const KPC_M: float = 3.0856775814913673e19
	const MREF_KG: float = 5.0e10 * SOLAR_MASS
	const Z_REF: float = 0.25

	if not is_finite(m_bulge_star_kg) or m_bulge_star_kg <= 0.0:
		Log.error(106, "res://scripts/core/constants.gd")
		return {}

	# Bulge effective-radius relation (early-type anchor):
	# van der Wel+2014, z~0.25 : log10(Re/kpc)=0.60+0.75*log10(M*/5e10Msun), sigma~0.14 dex
	# redshift evolution (early type): Re ∝ (1+z)^-1.48
	const LOG10_A_RE_KPC: float = 0.60
	const ALPHA_RE_MASS: float = 0.75
	const BETA_RE_Z: float = -1.48
	const SIGMA_DEX_RE: float = 0.14

	# Sersic index soft-bounded logistic-normal around observed classical-bulge regime.
	# n_min/n_max는 물리적 hard-cut이 아니라 tail를 부드럽게 줄이는 soft prior 역할.
	const N_MIN: float = 0.6
	const N_MAX: float = 8.5
	const N0: float = 2.6
	const SIGMA_LOGIT_N: float = 0.55
	const A_MASS_N: float = 1.05
	const A_BULGE_N: float = 0.55
	const A_MORPH_N: float = 0.65

	var logM_bulge := logx(m_bulge_star_kg / SOLAR_MASS)
	var mass_term := logM_bulge - 10.5
	var bulge_term := logit(clamp(f_bulge_, 1e-6, 1.0 - 1e-6)) - logit(0.25)
	var p_bulge := sigmoid(s_morph)

	var u1_n: float = max(hash_float(galaxy_seed, HashPurpose.GALAXY_BULGE_SERSIC, 0), 1e-12)
	var u2_n := hash_float(galaxy_seed, HashPurpose.GALAXY_BULGE_SERSIC, 1)
	var z_n := get_Z(u1_n, u2_n)

	var x_n := logit((N0 - N_MIN) / (N_MAX - N_MIN)) \
		+ A_MASS_N * mass_term \
		+ A_BULGE_N * bulge_term \
		+ A_MORPH_N * (p_bulge - 0.5) \
		+ SIGMA_LOGIT_N * z_n
	var n_sersic := N_MIN + (N_MAX - N_MIN) * sigmoid(x_n)

	var u1_re: float = max(hash_float(galaxy_seed, HashPurpose.GALAXY_BULGE_SIZE, 0), 1e-12)
	var u2_re := hash_float(galaxy_seed, HashPurpose.GALAXY_BULGE_SIZE, 1)
	var z_re := get_Z(u1_re, u2_re)

	var log10_reff_kpc := LOG10_A_RE_KPC \
		+ ALPHA_RE_MASS * logx(m_bulge_star_kg / MREF_KG) \
		+ BETA_RE_Z * logx((1.0 + z) / (1.0 + Z_REF)) \
		+ 0.08 * (n_sersic - 3.0)

	var log10_reff_kpc_sampled := log10_reff_kpc + SIGMA_DEX_RE * z_re
	var r_eff_kpc := pow(10.0, log10_reff_kpc_sampled)

	# soft halo consistency prior: r_eff/r200가 비현실적으로 커질수록 완만히 억제
	var halo_soft_prior := 1.0
	if is_finite(r200c_kpc) and r200c_kpc > 0.0:
		var x_halo := logx((0.035 * r200c_kpc) / max(r_eff_kpc, 1e-9))
		halo_soft_prior = 0.70 + 0.30 * sigmoid(4.0 * x_halo)
		r_eff_kpc *= halo_soft_prior
		log10_reff_kpc_sampled = logx(r_eff_kpc)

	return {
		"n_sersic": n_sersic,
		"r_eff_kpc": r_eff_kpc,
		"r_eff_m": r_eff_kpc * KPC_M,
		"log10_r_eff_kpc": log10_reff_kpc_sampled,
		"sigma_dex_re": SIGMA_DEX_RE,
		"sigma_logit_n": SIGMA_LOGIT_N,
		"halo_soft_prior": halo_soft_prior
	}

static func sample_bulge_profile_from_galaxy(
	galaxy_seed: int,
	m_vir_kg: float,
	f_baryon_: float,
	f_gas_: float,
	f_bulge_: float,
	s_morph: float,
	z: float = 0.0,
	r200c_kpc: float = -1.0
) -> Dictionary:
	var m_star_total_kg := m_vir_kg * f_baryon_ * (1.0 - f_gas_)
	var m_bulge_star_kg: float = m_star_total_kg * clamp(f_bulge_, 1e-6, 1.0)
	return sample_bulge_profile_si(galaxy_seed, m_bulge_star_kg, f_bulge_, s_morph, z, r200c_kpc)

# ACCRETION DISK (SMBH)
static func _isco_radius_rg(spin_a: float) -> float:
	# Kerr ISCO radius in units of r_g = GM/c^2.
	# Spin sign controls whether the orbit is prograde or retrograde.
	var a: float = clamp(spin_a, -0.998, 0.998)

	var z1 := 1.0 \
		+ pow(1.0 - a * a, 1.0 / 3.0) \
		* (pow(1.0 + a, 1.0 / 3.0) + pow(1.0 - a, 1.0 / 3.0))
	var z2 := sqrt(3.0 * a * a + z1 * z1)
	var sign_a := 1.0 if a >= 0.0 else -1.0

	return 3.0 + z2 - sign_a * sqrt((3.0 - z1) * (3.0 + z1 + 2.0 * z2))


static func _smoothstep01(x: float) -> float:
	x = clamp(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _bh_existence_probability(log10_mbulge: float, f_bulge_: float) -> float:
	# Dwarf / pseudobulge 계열에서 BH가 약하거나 없을 가능성을 반영
	var p_mass := sigmoid((log10_mbulge - 7.6) / 0.7)
	var p_bulge := sigmoid((f_bulge_ - 0.12) / 0.09)
	return clamp(0.001 + 0.98 * p_mass * p_bulge, 0.0, 1.0)


static func sample_accretion_disk_from_galaxy(
	galaxy_seed: int,
	m_vir_kg: float,
	f_baryon_: float,
	f_gas_: float,
	f_bulge_: float,
	s_morph: float,
	z: float = 0.0
) -> Dictionary:
	# 1) SMBH mass prior from bulge mass
	# - stronger suppression for pseudobulges
	# - larger scatter for pseudobulge / low-mass hosts
	# - weak redshift trend

	const ALPHA_BH: float = 8.69
	const BETA_BH: float = 1.16
	const GAMMA_Z: float = 0.5

	const SIGMA_BH_CLASSICAL: float = 0.28
	const SIGMA_BH_PSEUDO: float = 0.55

	var m_star_total_kg := m_vir_kg * f_baryon_ * (1.0 - f_gas_)
	var m_bulge_kg: float = max(m_star_total_kg * clamp(f_bulge_, 1e-6, 1.0), 1e-12)
	var log10_mbulge := logx(m_bulge_kg / SOLAR_MASS)

	# BH existence probability
	var p_bh_exist := _bh_existence_probability(log10_mbulge, f_bulge_)
	var u_exist := hash_float(galaxy_seed, HashPurpose.GALAXY_BH_MASS, 1)
	var has_bh := u_exist < p_bh_exist

	if not has_bh:
		return {
			"has_bh": false,
			"p_bh_exist": p_bh_exist,

			"has_disk": false,
			"p_disk": 0.0,
			"p_bh_mass": 0.0,
			"p_fuel": 0.0,

			"m_bh_kg": 0.0,
			"log10_m_bh_msun": NAN,

			"spin_a": 0.0,
			"eta_rad": 0.0,
			"log10_lambda_proxy": NAN,
			"p_coherent": 0.0,
			"r_out_rg": 0.0
		}

	var z_bh := random_normal(galaxy_seed, HashPurpose.GALAXY_BH_MASS, 0)

	# Pseudobulge correction
	var p_pseudobulge := sigmoid((0.22 - clamp(f_bulge_, 1e-6, 1.0)) / 0.10)
	var delta_pseudo_dex := -1 * p_pseudobulge

	# Low-mass hosts get slightly larger intrinsic scatter
	var sigma_bh_dex: float = lerp(SIGMA_BH_CLASSICAL, SIGMA_BH_PSEUDO, p_pseudobulge)
	sigma_bh_dex += 0.05 * clamp(10.0 - log10_mbulge, 0.0, 3.0) / 3.0

	var log10_mbh := ALPHA_BH \
		+ BETA_BH * (log10_mbulge - 11.0) \
		+ GAMMA_Z * logx(max(1.0 + z, 1e-6)) \
		+ delta_pseudo_dex \
		+ sigma_bh_dex * z_bh

	var m_bh_kg := pow(10.0, log10_mbh) * SOLAR_MASS

	# 2) Spin mixture
	const A_MIN: float = -0.998
	const A_MAX: float = 0.998

	var gas_centered: float = clamp((f_gas_ - 0.20) / 0.20, -2.0, 2.0)
	var morph_centered := sigmoid(s_morph) - 0.5
	var p_coherent := sigmoid(0.75 * gas_centered - 1.10 * morph_centered - 0.25 * (log10_mbh - 8.0))

	var z_spin := random_normal(galaxy_seed, HashPurpose.GALAXY_ACCRETION_SPIN, 0)
	var z_spin_skew := random_normal(galaxy_seed, HashPurpose.GALAXY_ACCRETION_MODE, 1)

	var spin_center: float = lerp(-0.12, 0.62, p_coherent)
	var spin_sigma: float = lerp(0.9, 0.4, p_coherent)
	var retro_tail: float = -0.15 * (1.0 - p_coherent) * z_spin_skew

	var x_spin := logit((spin_center - A_MIN) / (A_MAX - A_MIN)) \
		+ spin_sigma * z_spin \
		+ retro_tail

	var spin_a := A_MIN + (A_MAX - A_MIN) * sigmoid(x_spin)

	var r_isco_rg := _isco_radius_rg(spin_a)
	var sqrt_r := sqrt(r_isco_rg)
	var r_3_2: float = r_isco_rg * sqrt_r

	var e_num: float = r_3_2 - 2.0 * sqrt_r + spin_a
	var e_den := pow(r_isco_rg, 0.75) * sqrt(max(r_3_2 - 3.0 * sqrt_r + 2.0 * spin_a, 1e-9))
	var eta_raw: float = 1.0 - e_num / max(e_den, 1e-9)
	var eta_rad: float = clamp(eta_raw, 0.038, 0.42)
	#eta_rad *= 0.9

	# 3) Fueling proxy
	const LOG10_LAMBDA0: float = -2.8

	var mass_term := log10_mbh - 8.0
	var gas_term_soft := tanh(gas_centered)
	var morph_term := morph_centered
	var z_lambda := random_normal(galaxy_seed, HashPurpose.GALAXY_ACCRETION_EDD_RATIO, 0)
	var u_tail := hash_float(galaxy_seed, HashPurpose.GALAXY_ACCRETION_EDD_RATIO, 3)

	var sigma_lambda := 0.55
	if u_tail < (0.15 + 0.15 * p_coherent):
		sigma_lambda = 1.05

	var log10_lambda := LOG10_LAMBDA0 \
		+ 0.30 * gas_term_soft \
		- 0.15 * mass_term \
		+ 0.12 * morph_term \
		+ sigma_lambda * z_lambda

	# 4) Outer radius prior
	const LOG10_ROUT_MAX: float = 5.5
	const LOG10_ROUT_BASE: float = 3.35
	const SIGMA_LOG10_ROUT: float = 0.18

	var log10_mbh_clamped: float = clamp(log10_mbh, 5.0, 10.0)
	var lambda_term: float = clamp(log10_lambda + 2.8, -1.5, 1.5)
	var z_rout := random_normal(galaxy_seed, HashPurpose.GALAXY_ACCRETION_OUTER_RADIUS, 0)

	var log10_r_out_raw := LOG10_ROUT_BASE \
		+ 0.60 * (8.0 - log10_mbh_clamped) \
		+ 0.35 * lambda_term \
		+ SIGMA_LOG10_ROUT * z_rout

	var r_out_min := 5.0 * r_isco_rg
	var log10_r_out_min := logx(max(r_out_min, 1e-9))
	var log10_r_out_max := LOG10_ROUT_MAX

	var t: float = (log10_r_out_raw - log10_r_out_min) / max(log10_r_out_max - log10_r_out_min, 1e-6)
	var log10_r_out: float = lerp(log10_r_out_min, log10_r_out_max, _smoothstep01(t))
	var r_out_rg := pow(10.0, log10_r_out)

	# 5) Disk existence probability
	var p_bh_mass := sigmoid((log10_mbh - 6.2) / 0.70)
	var p_fuel := sigmoid((log10_lambda + 2.4) / 0.60)

	var p_disk: float = sigmoid((log10_lambda - (-1.70)) / 0.45)
	

	var u_disk := hash_float(galaxy_seed, HashPurpose.GALAXY_ACCRETION_EXISTENCE, 0)
	var has_disk := u_disk < p_disk

	return {
		"has_bh": true,
		"p_bh_exist": p_bh_exist,

		"has_disk": has_disk,
		"p_disk": p_disk,
		"p_bh_mass": p_bh_mass,
		"p_fuel": p_fuel,

		"m_bh_kg": m_bh_kg,
		"log10_m_bh_msun": log10_mbh,
		"spin_a": spin_a,
		"eta_rad": eta_rad,
		"log10_lambda_proxy": log10_lambda,
		"p_coherent": p_coherent,
		"r_out_rg": r_out_rg
	}

# ─────────────────────────────────────────────────────────────────
# AGN PROPERTIES  (Step 13)
# ─────────────────────────────────────────────────────────────────

static func _agn_obscuration_prob(
	log10_lambda: float,
	f_gas_: float
) -> float:
	# Receding torus model (Lawrence 1991, Hopkins et al. 2007)
	# 높은 Eddington 비율 → 강한 복사압 → torus 개구부 확장 → Type 1 비율 증가
	# 가스 분율이 높을수록 차폐 확률 상승
	var lambda_term := sigmoid((-log10_lambda - 1.5) / 0.8)
	var gas_boost: float = clamp(0.3 + 0.7 * f_gas_, 0.3, 1.0)
	return clamp(0.03 + 0.65 * lambda_term * gas_boost, 0.0, 1.0)


static func sample_agn_properties(
	galaxy_seed: int,
	log10_m_bh_msun: float,
	log10_lambda: float,
	has_bh: bool,        # ← has_disk 대신 has_bh로 gate
	has_disk: bool,      # spectral mode 결정용
	f_gas_: float
) -> Dictionary:
	# has_bh가 없으면 비활성
	if not has_bh:
		return {
			"log10_l_bol_lsun": NAN,
			"log10_l_edd_lsun": NAN,
			"is_obscured":      false,
			"p_obscured":       0.0,
			"agn_class":        "inactive"
		}

	# L_Edd, L_bol — disk 존재 무관하게 항상 계산
	const LOG10_LEDD_LSUN_OFFSET: float = 4.517
	var log10_l_edd_lsun := LOG10_LEDD_LSUN_OFFSET + log10_m_bh_msun
	var log10_l_bol_lsun := log10_l_edd_lsun + log10_lambda

	# 차폐(obscuration): torus 모델은 thin disk에서만 잘 적용됨
	# ADAF 모드(has_disk=false)에서는 obscuration 확률 대폭 감소
	var p_obs: float
	if has_disk:
		p_obs = _agn_obscuration_prob(log10_lambda, f_gas_)
	else:
		# ADAF/RIAF: 광학적으로 얇은 torus 구조 약함
		p_obs = clamp(_agn_obscuration_prob(log10_lambda, f_gas_) * 0.25, 0.0, 0.3)

	var u_obs  := hash_float(galaxy_seed, HashPurpose.GALAXY_AGN_OBSCURATION, 0)
	var is_obs := u_obs < p_obs

	# 분류: thin disk 유무로 spectral mode 분기
	var agn_class: String
	if has_disk:
		# 표준 thin disk 모드 — 기존 분류 그대로
		if log10_l_bol_lsun >= 12.0:
			agn_class = "quasar"
		elif log10_lambda >= -2.0:
			agn_class = "seyfert"
		elif log10_lambda >= -4.0:
			agn_class = "liner"
		else:
			agn_class = "weak"
		agn_class += ("_2" if is_obs else "_1")
	else:
		# ADAF/RIAF 모드 — radio-loud, 낮은 복사 효율
		# Type 1/2 구분 없음 (torus 형성 안 됨)
		if log10_lambda >= -2.5:
			agn_class = "adaf_seyfert"   # 전이 영역, 드물게 존재
		elif log10_lambda >= -4.0:
			agn_class = "adaf_liner"
		else:
			agn_class = "adaf_weak"

	return {
		"log10_l_bol_lsun": log10_l_bol_lsun,
		"log10_l_edd_lsun": log10_l_edd_lsun,
		"is_obscured": is_obs,
		"p_obscured": p_obs,
		"agn_class": agn_class
	}


# ─────────────────────────────────────────────────────────────────
# JET PROPERTIES  (Step 14)
# ─────────────────────────────────────────────────────────────────

static func sample_jet_properties(
	galaxy_seed: int,
	log10_m_bh_msun: float,
	spin_a: float,
	log10_lambda: float,
	eta_rad: float,
	has_bh: bool,    # ← has_disk 대신 has_bh로 gate
	has_disk: bool   # ADAF 여부 판단용
) -> Dictionary:
	var no_jet := {
		"has_jet":           false,
		"p_jet":             0.0,
		"log10_p_jet_w":     NAN,
		"jet_morphology":    "none",
		"jet_lorentz":       NAN,
		"jet_half_angle_deg":NAN
	}

	if not has_bh:           # ← 변경: disk 없어도 jet 가능
		return no_jet

	# ── 제트 존재 확률 ────────────────────────────────────────────
	# Blandford-Znajek 메커니즘: 제트 출력 ∝ a²
	# ADAF/RIAF 저 Eddington 모드에서 radio-loud 비율 상승 (Heckman & Best 2014)
	var spin2      := spin_a * spin_a
	var mass_term  := sigmoid((log10_m_bh_msun - 7.5) / 1.0)
	var adaf_boost := sigmoid((-log10_lambda - 2.2) / 0.6)

	# ADAF 모드(has_disk=false)에서 radio-loud jet 형성 훨씬 유리
	# Heckman & Best 2014: 낮은 Eddington 비율 → kinetic-mode feedback 우세
	var mode_factor: float = 1.8 if not has_disk else 1.0

	var p_jet: float = clamp(
		0.02 + 0.70 * spin2 * mass_term * (0.35 + 0.65 * adaf_boost) * mode_factor,
		0.0, 1.0
	)
	var u_jet := hash_float(galaxy_seed, HashPurpose.GALAXY_JET, 0)

	if u_jet >= p_jet:
		no_jet["p_jet"] = p_jet
		return no_jet

	# ── 제트 전력 (Blandford-Znajek 1977) ─────────────────────────
	# P_BZ ≈ κ · a² · (M_dot · c²)
	# κ ≈ 0.044  (Tchekhovskoy et al. 2010 평균; MAD 한계에서 ~1)
	# M_dot · c² = λ · L_Edd / η_rad
	# L_Edd [W] = 1.26e31 · (M_BH/Msun)  →  log10 offset = 31.100
	const LOG10_L_EDD_W_OFFSET: float = 31.100  # log10(1.26e31)
	const LOG10_KAPPA:          float = -1.357   # log10(0.044)

	var log10_l_edd_w := LOG10_L_EDD_W_OFFSET + log10_m_bh_msun
	var eta: float = clamp(eta_rad, 0.03, 0.42)
	var spin_term: float = max(spin_a * spin_a, 1e-4)
	var log10_mdot_c2_w := log10_l_edd_w + log10_lambda - logx(eta)
	var log10_p_bz_w := LOG10_KAPPA \
							+ logx(spin_term) \
							+ log10_mdot_c2_w

	# 자기장 환경 불확실성 산포 (σ ≈ 0.35 dex)
	var z_jet         := random_normal(galaxy_seed, HashPurpose.GALAXY_JET, 1)
	var log10_p_jet_w  := log10_p_bz_w + 0.35 * z_jet

	# ── FRI / FRII 분류 (Fanaroff & Riley 1974) ───────────────────
	# 볼로메트릭 제트 전력 기준:
	# FRII ≥ 10^38 W  : edge-brightened, 핫스팟, 강한 충격파
	# FRI  ≥ 10^35.5 W: center-brightened, 플룸, 난류 혼합
	# compact < 10^35.5 W: GPS/CSO, sub-kpc 스케일
	var jet_morphology: String
	if log10_p_jet_w >= 38.0:
		jet_morphology = "FRII"
	elif log10_p_jet_w >= 35.5:
		jet_morphology = "FRI"
	else:
		jet_morphology = "compact"

	# ── 로렌츠 인수 (lognormal 산포) ─────────────────────────────
	var gamma_base: float = 2.0
	match jet_morphology:
		"FRII":
			gamma_base = 10.0
		"FRI":
			gamma_base = 3.5
		_:
			gamma_base = 2.0

	var z_gamma := random_normal(galaxy_seed, HashPurpose.GALAXY_JET_LORENTZ, 0)
	const GAMMA_MIN: float = 1.5
	const GAMMA_MAX: float = 30.0
	var x_gamma := logit((gamma_base - GAMMA_MIN) / (GAMMA_MAX - GAMMA_MIN)) + 0.40 * z_gamma
	var jet_lorentz: float = GAMMA_MIN + (GAMMA_MAX - GAMMA_MIN) * sigmoid(x_gamma)

	# ── 반개구각 ─────────────────────────────────────────────────
	# θ ≈ 1/Γ [rad]; 관측 제트는 약간 더 넓음
	var z_theta := random_normal(galaxy_seed, HashPurpose.GALAXY_JET_LORENTZ, 2)
	# 대안: 반개구각도 logistic-normal로
	const THETA_MIN_DEG: float = 0.5
	const THETA_MAX_DEG: float = 20.0
	var theta_center_deg := rad_to_deg(1.0 / jet_lorentz)
	var x_theta := logit((theta_center_deg - THETA_MIN_DEG) / (THETA_MAX_DEG - THETA_MIN_DEG)) \
		+ 0.10 * z_theta
	var jet_half_angle_deg: float = THETA_MIN_DEG + (THETA_MAX_DEG - THETA_MIN_DEG) * sigmoid(x_theta)

	return {
		"has_jet": true,
		"p_jet": p_jet,
		"log10_p_jet_w": log10_p_jet_w,
		"jet_morphology": jet_morphology,
		"jet_lorentz": jet_lorentz,
		"jet_half_angle_deg": jet_half_angle_deg
	}


# ─────────────────────────────────────────────────────────────────
# STELLAR POPULATION  (Step 15~16)
# ─────────────────────────────────────────────────────────────────

static func sample_sfr_from_galaxy(
	galaxy_seed: int,
	m_star_kg: float,
	z: float,
	f_gas_: float,
	delta_physics: float,
	log10_lambda_proxy: float,
	has_jet: bool,
	log10_p_jet_w: float
) -> Dictionary:
	if not is_finite(m_star_kg) or m_star_kg <= 0.0:
		Log.error(114, "res://scripts/core/constants.gd")
		return {}

	var log10_m_star := logx(m_star_kg / SOLAR_MASS)
	var z_sfr := random_normal(galaxy_seed, HashPurpose.GALAXY_SFR, 0)

	# SFMS anchor:
	# log10(SFR/Msun yr^-1) = a * (logM* - 10.5) + b(z) + gas + latent physics + scatter
	var a_mass: float = 0.72 - 0.10 * clamp(z, 0.0, 2.0)
	var b_z := -0.12 + 1.10 * logx(1.0 + z)

	var gas_term := 0.65 * tanh((f_gas_ - 0.25) / 0.15)
	var phys_term := 0.18 * tanh(delta_physics / 0.8)
	var log10_sfr_sfms: float = a_mass * (log10_m_star - 10.5) + b_z + gas_term + phys_term

	# AGN feedback quenching:
	# - strong radio jet (kinetic mode) and high lambda both suppress SFR.
	var jet_quench := 0.0
	if has_jet and is_finite(log10_p_jet_w):
		jet_quench = 0.7 * tanh(max(log10_p_jet_w - 36.0, 0.0) / 2.0)

	var rad_quench: float = 0.0
	if is_finite(log10_lambda_proxy):
		rad_quench = 0.35 * tanh(max(log10_lambda_proxy + 2.0, 0.0) / 1.5)
	var log10_quench_total := jet_quench + rad_quench

	var log10_sfr := log10_sfr_sfms - log10_quench_total + 0.35 * z_sfr
	log10_sfr = clamp(log10_sfr, -4.0, 3.0)

	return {
		"log10_m_star_msun": log10_m_star,
		"log10_sfr_sfms_msun_per_yr": log10_sfr_sfms,
		"log10_sfr_msun_per_yr": log10_sfr,
		"sfr_msun_per_yr": pow(10.0, log10_sfr),
		"log10_quench_correction": log10_quench_total,
		"jet_quench_term": jet_quench,
		"rad_quench_term": rad_quench
	}


static func sample_metallicity_profile(
	galaxy_seed: int,
	log10_m_star_msun: float
) -> Dictionary:
	if not is_finite(log10_m_star_msun):
		Log.error(115, "res://scripts/core/constants.gd")
		return {}

	# 중심 금속도 (12 + log(O/H)) mass-metallicity relation
	# local MZR around z~0, mildly saturating near ~9.1
	var z_met_center := random_normal(galaxy_seed, HashPurpose.GALAXY_METALLICITY, 0)
	var x := log10_m_star_msun - 10.0
	var z0_center := 8.75 + 0.30 * x - 0.08 * x * x
	var z_center: float = clamp(z0_center + 0.10 * z_met_center, 7.6, 9.4)

	# gradient: -0.05 ~ -0.10 dex/kpc
	var u_grad := hash_float(galaxy_seed, HashPurpose.GALAXY_METALLICITY, 2)
	var grad_dex_per_kpc: float = lerp(-0.10, -0.05, u_grad)

	return {
		"z_center_12_log_oh": z_center,
		"gradient_dex_per_kpc": grad_dex_per_kpc,
		"scatter_dex": 0.10
	}

# ─────────────────────────────────────────────────────────────────────────────
# BESSEL FUNCTIONS  (Abramowitz & Stegun §9.8)
# Freeman(1970) 지수 디스크 회전 곡선에 사용
# 최대 오차: I0/I1 < 1.9×10⁻⁷, K0/K1 < 1.9×10⁻⁷
# ─────────────────────────────────────────────────────────────────────────────

static func _bessel_I0(x: float) -> float:
	var ax: float = abs(x)
	if ax <= 3.75:
		var t__ := (x / 3.75) * (x / 3.75)           # t = (x/3.75)²
		return 1.0 + t__*(3.5156329 + t__*(3.0899424 + t__*(1.2067492
			 + t__*(0.2659732 + t__*(0.0360768 + t__*0.0045813)))))
	var t_ := 3.75 / ax
	return (exp(ax) / sqrt(ax)) * (0.39894228 + t_*(0.01328592
		 + t_*(0.00225319 + t_*(-0.00157565 + t_*(0.00916281
		 + t_*(-0.02057706 + t_*(0.02635537 + t_*(-0.01647633 + t_*0.00392377))))))))


static func _bessel_I1(x: float) -> float:
	var ax: float = abs(x)
	if ax <= 3.75:
		var t_ := (x / 3.75) * (x / 3.75)
		return x * (0.5 + t_*(0.87890594 + t_*(0.51498869 + t_*(0.15084934
			 + t_*(0.02658733 + t_*(0.00301532 + t_*0.00032411))))))
	var t := 3.75 / ax
	var r := (exp(ax) / sqrt(ax)) * (0.39894228 + t*(-0.03988024
			+ t*(-0.00362018 + t*(0.00163801 + t*(-0.01031555
			+ t*(0.02282967 + t*(-0.02895312 + t*(0.01787654 - t*0.00420059))))))))
	return r if x >= 0.0 else -r


static func _bessel_K0(x: float) -> float:
	if x <= 0.0:
		return INF
	if x <= 2.0:
		var t_ := x * x * 0.25
		return -log(x * 0.5) * _bessel_I0(x) \
			+ (-0.57721566 + t_*(0.42278420 + t_*(0.23069756
			+ t_*(0.03488590 + t_*(0.00262698 + t_*(0.00010750 + t_*0.0000074))))))
	var t := 2.0 / x
	return (exp(-x) / sqrt(x)) * (1.25331414 + t*(-0.07832358
		+ t*(0.02189568 + t*(-0.01062446 + t*(0.00587872 + t*(-0.00251540 + t*0.00053208))))))


static func _bessel_K1(x: float) -> float:
	if x <= 0.0:
		return INF
	if x <= 2.0:
		var t_ := x * x * 0.25
		return log(x * 0.5) * _bessel_I1(x) \
			+ (1.0 / x) * (1.0 + t_*(0.15443144 + t_*(-0.67278579
			+ t_*(-0.18156897 + t_*(-0.01919402 + t_*(-0.00110404 + t_*(-0.00004686)))))))
	var t := 2.0 / x
	return (exp(-x) / sqrt(x)) * (1.25331414 + t*(0.23498619
		+ t*(-0.03655620 + t*(0.01504268 + t*(-0.00780353 + t*(0.00325614 - t*0.00068245))))))


# ─────────────────────────────────────────────────────────────────────────────
# ROTATION CURVE COMPONENTS  (Step 25)
# 단위: 입력 kpc / Msun / (kpc³·Msun⁻¹), 반환 V² [(km/s)²]
# ─────────────────────────────────────────────────────────────────────────────

## NFW 암흑물질 헤일로 기여
static func v2_nfw(R_kpc: float, rs_kpc: float, rho_s_msun_kpc3: float) -> float:
	if R_kpc < 1e-6:
		return 0.0
	var x     := R_kpc / rs_kpc
	var M_enc := 4.0 * PI * rho_s_msun_kpc3 * rs_kpc * rs_kpc * rs_kpc * g_nfw(x)
	return G_KPC_KM2_S2_MSUN * M_enc / R_kpc


## Freeman(1970) 지수 디스크 기여
## V²(R) = (G M_disk / Rd) · 2y² · [I₀(y)K₀(y) - I₁(y)K₁(y)],  y = R/(2Rd)
static func v2_disk(R_kpc: float, M_disk_msun: float, Rd_kpc: float) -> float:
	if R_kpc < 1e-6 or Rd_kpc < 1e-6 or M_disk_msun <= 0.0:
		return 0.0
	var y : float = clamp(R_kpc / (2.0 * Rd_kpc), 1e-6, 15.0)
	var bk := _bessel_I0(y) * _bessel_K0(y) - _bessel_I1(y) * _bessel_K1(y)
	return max(G_KPC_KM2_S2_MSUN * M_disk_msun / Rd_kpc * 2.0 * y * y * bk, 0.0)


## Hernquist(1990) 벌지 기여
## V²(R) = G M r / (r + a)²
## Sérsic r_eff → Hernquist a 변환: a = r_eff / 1.815 (2D projected half-mass 조건)
static func v2_hernquist(R_kpc: float, M_bulge_msun: float, a_kpc: float) -> float:
	if R_kpc < 1e-6 or M_bulge_msun <= 0.0 or a_kpc < 1e-9:
		return 0.0
	return G_KPC_KM2_S2_MSUN * M_bulge_msun * R_kpc / ((R_kpc + a_kpc) * (R_kpc + a_kpc))


## 합산 회전 속도 V_circ(R) [km/s]
static func rotation_curve_kms(
	R_kpc:         float,
	rs_kpc:        float,
	rho_s_msun_kpc3: float,
	M_disk_msun:   float,
	Rd_kpc:        float,
	M_bulge_msun:  float,
	r_eff_kpc:     float   # Sérsic → Hernquist: a = r_eff / 1.815
) -> float:
	var a_kpc := r_eff_kpc / 1.815
	var v2    := v2_nfw(R_kpc, rs_kpc, rho_s_msun_kpc3) \
			   + v2_disk(R_kpc, M_disk_msun, Rd_kpc) \
			   + v2_hernquist(R_kpc, M_bulge_msun, a_kpc)
	return sqrt(max(v2, 0.0))


# ─────────────────────────────────────────────────────────────────────────────
# EPICYCLIC FREQUENCY & TOOMRE Q  (Step 26)
# ─────────────────────────────────────────────────────────────────────────────

## 이심 진동 진동수 κ [km/s/kpc], 수치 미분으로 계산
## κ² = (2V/R)(dV/dR + V/R)
static func epicyclic_kms_kpc(
	R_kpc:           float,
	rs_kpc:          float,
	rho_s_msun_kpc3: float,
	M_disk_msun:     float,
	Rd_kpc:          float,
	M_bulge_msun:    float,
	r_eff_kpc:       float,
	dR:              float = 0.02   # 수치 미분 스텝 [kpc]
) -> float:
	if R_kpc < 1e-6:
		return 0.0
	var R1: float = max(R_kpc - dR, dR)
	var R2 := R_kpc + dR
	var V  := rotation_curve_kms(R_kpc, rs_kpc, rho_s_msun_kpc3, M_disk_msun, Rd_kpc, M_bulge_msun, r_eff_kpc)
	var V1 := rotation_curve_kms(R1,    rs_kpc, rho_s_msun_kpc3, M_disk_msun, Rd_kpc, M_bulge_msun, r_eff_kpc)
	var V2 := rotation_curve_kms(R2,    rs_kpc, rho_s_msun_kpc3, M_disk_msun, Rd_kpc, M_bulge_msun, r_eff_kpc)
	if V < 1e-6:
		return 0.0
	var dVdR  := (V2 - V1) / (R2 - R1)
	var Omega := V / R_kpc
	return sqrt(max(2.0 * Omega * (dVdR + Omega), 0.0))


## 별 디스크 Toomre Q (Binney & Tremaine 2008, eq. 6.71)
## Q = σ_R · κ / (3.36 G Σ)
static func toomre_q(
	sigma_R_kms:      float,
	kappa_kms_kpc:    float,
	Sigma_msun_kpc2:  float
) -> float:
	if Sigma_msun_kpc2 < 1e-6 or kappa_kms_kpc < 1e-6:
		return 1e6
	return sigma_R_kms * kappa_kms_kpc / (3.36 * G_KPC_KM2_S2_MSUN * Sigma_msun_kpc2)


## Hill 반지름 [kpc]: r_H ≈ R · (m / 3M_enc)^{1/3}
## M_enc(R) ≈ V_c² R / G (원형 궤도 근사)
static func hill_radius_kpc(
	R_kpc:       float,
	m_star_msun: float,
	V_c_kms:     float
) -> float:
	if V_c_kms < 1.0 or R_kpc < 1e-4:
		return 0.0
	var M_enc := V_c_kms * V_c_kms * R_kpc / G_KPC_KM2_S2_MSUN
	return R_kpc * pow(m_star_msun / max(3.0 * M_enc, 1e-30), 1.0 / 3.0)
