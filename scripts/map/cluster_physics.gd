extends RefCounted
class_name ClusterPhysics

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ClusterPhysics.gd
# Phase 9 (Step 30): 성단 & 성운 생성
#
# 수정 사항 (v2):
#   - Poisson 샘플러: 정규근사 → Knuth(1969) + 정규 혼합 정확 구현
#   - f_gas: sample_gmcs() 에서 평균 GMC 질량 변조에 실제 사용
#   - age_gyr: OB 나이 상한 클램프 / GC 나이 상한 (은하 나이 초과 방지)
#   - feh: OB 크기·HII n_e 금속도 보정 / GC red 계통 조건부
#   - clamp() 인자 역전 방지: _safe_clamp_R() 헬퍼
#   - n_phys / n 분리: 물리 총계(n_phys)와 렌더 배열 크기(n) 구분
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ── OB 성협 ──────────────────────────────────────────────────────────────────
const OB_N_BASE: int        = 60
const OB_MASS_MIN: float    = 300.0
const OB_MASS_MAX: float    = 1.5e5
const OB_AGE_MIN_MYR: float = 0.5
const OB_AGE_MAX_MYR: float = 30.0
const OB_SIZE_MIN_PC: float = 8.0
const OB_SIZE_MAX_PC: float = 150.0
const OB_N_RENDER: int      = 300    # 렌더링 예산 (표시 상한)
const OB_N_PHYS: int        = 8_000  # 물리 계산 상한 (통계·총질량 추적용)

# ── 구상성단 ─────────────────────────────────────────────────────────────────
const GC_SN_REF: float       = 2.5
const GC_MASS_PEAK: float    = 2.0e5
const GC_SIGMA_DEX: float    = 0.6
const GC_AGE_MIN_GYR: float  = 7.0
const GC_AGE_MAX_GYR: float  = 13.5
const GC_R_HALF_PC: float    = 3.0
const GC_SIGMA_R_HALF: float = 0.35
const GC_N_RENDER: int       = 600
const GC_N_PHYS: int         = 20_000

# ── GMC ──────────────────────────────────────────────────────────────────────
const GMC_MASS_REF: float  = 3.16e5  # Msun; 10^5.5, f_gas=0.30 기준 평균
const GMC_MASS_MIN: float  = 1.0e4
const GMC_MASS_MAX: float  = 1.0e7
const GMC_CMF_ALPHA: float = 1.8     # dN/dM ~ M^-alpha (Solomon+1987)
const GMC_N_RENDER: int    = 400
const GMC_N_PHYS: int      = 15_000

# ── HII 전자 밀도 ─────────────────────────────────────────────────────────────
const HII_NE_MIN: float = 8.0
const HII_NE_MAX: float = 800.0


# ─────────────────────────────────────────────────────────────────────────────
# 내부 유틸
# ─────────────────────────────────────────────────────────────────────────────

static func _u(seed_: int, purpose: int, index: int) -> float:
	return C.hash_float(seed_, purpose, index)


static func _normal(seed_: int, purpose: int, index: int) -> float:
	var u1: float = max(_u(seed_, purpose, index * 2),     1e-12)
	var u2: float = max(_u(seed_, purpose, index * 2 + 1), 1e-12)
	return sqrt(-2.0 * log(u1)) * cos(TAU * u2)


## Poisson 샘플러 — Knuth(1969) 정확 알고리즘 + 정규근사 혼합
##
## lam < 30: Knuth 정확법
##   아이디어: 지수 inter-arrival 시간의 합 ≡ 균등 난수의 누적곱이
##            exp(-lam) 이하가 될 때까지 센 횟수 = Poisson(lam) 실현값
##   해시 인덱스를 0부터 순서대로 소비; purpose 격리로 다른 샘플링과 충돌 없음
##   기댓값 lam+1개, 최대 5*lam+20개 인덱스 사용
##
## lam >= 30: 정규근사 (오차 < 0.3%, 인덱스 2개만 사용)
static func _poisson(seed_: int, purpose: int, lam: float) -> int:
	if lam <= 0.0:
		return 0

	if lam >= 30.0:
		var z := _normal(seed_, purpose, 0)
		return int(max(round(lam + sqrt(lam) * z), 0.0))

	var L: float   = exp(-lam)
	var p: float   = 1.0
	var k: int     = 0
	var max_iter: int = int(lam * 5.0) + 20
	for idx in range(max_iter):
		p *= max(_u(seed_, purpose, idx), 1e-12)
		if p <= L:
			break
		k += 1
	return k


## 나선팔 편향 방위각 샘플링 (OB 성협·GMC 공용)
static func _sample_phi_spiral(
	seed_:        int,
	idx:          int,
	R_kpc:        float,
	Rd_kpc:       float,
	spiral:       Dictionary,
	purpose_mode: int,
	purpose_arm:  int
) -> float:
	var has_arms:  bool  = bool(spiral.get("has_arms", false))
	var arm_count: int   = int(spiral.get("arm_count", 0))
	var pitch_deg: float = float(spiral.get("pitch_deg", 0.0))
	var phases:    Array = spiral.get("phases", [])
	var contrast:  float = float(spiral.get("contrast", 0.0))

	var p_arm: float = 0.0
	if has_arms and arm_count > 0 and contrast > 0.01:
		p_arm = contrast / (1.0 + contrast)

	if _u(seed_, purpose_mode, idx) >= p_arm:
		return _u(seed_, purpose_arm, idx + 1_000_000) * TAU

	var u_sel := _u(seed_, purpose_arm, idx)
	var k: int = int(u_sel * arm_count) % arm_count
	var pitch_rad := deg_to_rad(max(pitch_deg, 3.0))
	var phi_arm: float = float(phases[k]) + \
		log(max(R_kpc, 0.01) / max(Rd_kpc, 0.01)) / max(tan(pitch_rad), 1e-6)

	var z_phi := _normal(seed_, purpose_arm, idx + 2_000_000)
	return phi_arm + 0.20 * z_phi


## Gamma(2, scale_kpc) 반경 샘플: 지수 디스크 2D marginal
static func _sample_R_disk(seed_: int, purpose: int, idx: int, scale_kpc: float) -> float:
	var u1: float = max(_u(seed_, purpose, idx * 2),     1e-12)
	var u2: float = max(_u(seed_, purpose, idx * 2 + 1), 1e-12)
	return -scale_kpc * (log(u1) + log(u2))


## clamp 인자 역전 방지: R_min < R_max 를 항상 보장
static func _safe_clamp_R(R: float, R_min: float, R_max_raw: float) -> float:
	return clamp(R, R_min, max(R_min + 0.01, R_max_raw))


# ─────────────────────────────────────────────────────────────────────────────
# 1. OB 성협 샘플링
#    참고: Lada & Lada 2003; McKee & Williams 1997; Bresolin+2012
# ─────────────────────────────────────────────────────────────────────────────

static func sample_ob_associations(
	galaxy_seed:     int,
	sfr_msun_per_yr: float,
	age_gyr:         float,  # [use] OB 나이 상한 = min(30 Myr, age_gyr*1000 Myr)
	feh:             float,  # [use] HII n_e 금속도 보정 + 성협 크기 변조
	Rd_kpc:          float,
	spiral:          Dictionary,
	galaxy_type:     int
) -> Dictionary:
	if galaxy_type == GalaxyData.GalaxyType.E:
		return _empty_ob()

	# <N_OB> ~ OB_N_BASE * (SFR/2)^0.75  (Lada & Lada 2003 스케일링)
	var sfr: float    = clamp(sfr_msun_per_yr, 1e-4, 100.0)
	var n_mean: float = OB_N_BASE * pow(sfr / 2.0, 0.75)
	if galaxy_type == GalaxyData.GalaxyType.Irr:
		n_mean *= 0.5

	var n_phys: int   = clampi(_poisson(galaxy_seed, C.HashPurpose.CLUSTER_OB_N, n_mean), 0, OB_N_PHYS)
	var n_render: int = mini(n_phys, OB_N_RENDER)

	if n_render == 0:
		var empty := _empty_ob(); empty["n_phys"] = n_phys; return empty

	# OB 나이 상한: 은하 나이(Gyr → Myr 변환)를 초과 불가
	var age_max_myr: float = max(min(OB_AGE_MAX_MYR, age_gyr * 1000.0), OB_AGE_MIN_MYR + 0.1)

	# [feh] HII n_e 보정: 금속풍부 → 선냉각 증가 → 더 조밀한 HII 영역
	#   Δlog(n_e)/Δ[Fe/H] ≈ +0.12  (Bresolin+2012)
	var feh_ne_factor: float  = pow(10.0, 0.12 * clamp(feh, -2.5, 0.7))

	# [feh] 크기 보정: 금속풍부 → 피드백 효율 ↑ → 약간 더 작은 성협
	#   Δlog(r)/Δ[Fe/H] ≈ -0.05
	var feh_size_factor: float = pow(10.0, -0.05 * clamp(feh, -2.5, 0.7))

	var pos_x    := PackedFloat32Array(); pos_x.resize(n_render)
	var pos_y    := PackedFloat32Array(); pos_y.resize(n_render)
	var masses   := PackedFloat32Array(); masses.resize(n_render)
	var ages_myr := PackedFloat32Array(); ages_myr.resize(n_render)
	var sizes_pc := PackedFloat32Array(); sizes_pc.resize(n_render)
	var hii_ne   := PackedFloat32Array(); hii_ne.resize(n_render)

	# CMF dN/dM ~ M^-2 역 CDF 상수
	var inv_min: float = 1.0 / OB_MASS_MIN
	var inv_max: float = 1.0 / OB_MASS_MAX

	for i in range(n_render):
		# 질량: 역 CDF
		var u_m := _u(galaxy_seed, C.HashPurpose.CLUSTER_OB_MASS, i)
		var mass: float = 1.0 / (inv_min - u_m * (inv_min - inv_max))

		# 나이: log-uniform in [OB_AGE_MIN, age_max_myr]
		var u_age := _u(galaxy_seed, C.HashPurpose.CLUSTER_OB_AGE, i)
		var age_myr: float = OB_AGE_MIN_MYR * pow(age_max_myr / OB_AGE_MIN_MYR, u_age)

		# 위치
		var R_kpc: float = _safe_clamp_R(
			_sample_R_disk(galaxy_seed, C.HashPurpose.CLUSTER_OB_R, i, Rd_kpc),
			0.01, Rd_kpc * 6.0
		)
		var phi := _sample_phi_spiral(
			galaxy_seed, i, R_kpc, Rd_kpc, spiral,
			C.HashPurpose.CLUSTER_OB_PHI, C.HashPurpose.CLUSTER_OB_PHI_ARM
		)
		pos_x[i]    = R_kpc * cos(phi)
		pos_y[i]    = R_kpc * sin(phi)
		masses[i]   = mass
		ages_myr[i] = age_myr

		# 물리적 크기: r ∝ M^0.5 + feh 보정 + 0.2 dex 산포
		var size_base: float = 30.0 * sqrt(max(mass, 1.0) / 1.0e4) * feh_size_factor
		var z_s := _normal(galaxy_seed, C.HashPurpose.CLUSTER_OB_SIZE, i)
		sizes_pc[i] = clamp(size_base * pow(10.0, 0.20 * z_s), OB_SIZE_MIN_PC, OB_SIZE_MAX_PC)

		# HII n_e: n_e ∝ M^0.35 * feh_ne_factor + 0.6 dex 산포
		var ne_base: float = 50.0 * pow(max(mass, 1.0) / 1.0e4, 0.35) * feh_ne_factor
		var u_ne := _u(galaxy_seed, C.HashPurpose.CLUSTER_HII_N_E, i)
		hii_ne[i] = clamp(ne_base * pow(10.0, (u_ne - 0.5) * 0.6), HII_NE_MIN, HII_NE_MAX)

	return {
		"n_phys":    n_phys,
		"n":         n_render,
		"pos_x_kpc": pos_x,
		"pos_y_kpc": pos_y,
		"mass_msun": masses,
		"age_myr":   ages_myr,
		"size_pc":   sizes_pc,
		"hii_ne_cm3":hii_ne
	}


static func _empty_ob() -> Dictionary:
	return {
		"n_phys": 0, "n": 0,
		"pos_x_kpc": PackedFloat32Array(), "pos_y_kpc": PackedFloat32Array(),
		"mass_msun": PackedFloat32Array(), "age_myr":   PackedFloat32Array(),
		"size_pc":   PackedFloat32Array(), "hii_ne_cm3":PackedFloat32Array()
	}


# ─────────────────────────────────────────────────────────────────────────────
# 2. 구상성단 샘플링
#    참고: Harris 1991; Harris+2013; Georgiev+2010; VandenBerg+2013
# ─────────────────────────────────────────────────────────────────────────────

static func sample_globular_clusters(
	galaxy_seed:       int,
	log10_m_star_msun: float,
	age_gyr:           float,  # [use] GC 나이 분포 중심 + 상한 (은하 나이 초과 방지)
	feh:               float,  # [use] red 계통 금속도 조건부
	galaxy_type:       int,
	rvir_kpc:          float,
	r200c_kpc:         float
) -> Dictionary:
	var m_star: float = pow(10.0, log10_m_star_msun)

	var s_n: float = GC_SN_REF
	match galaxy_type:
		GalaxyData.GalaxyType.E:   s_n *= 3.5
		GalaxyData.GalaxyType.S0:  s_n *= 2.0
		GalaxyData.GalaxyType.Irr: s_n *= 0.6

	# <N_GC> ~ S_N * (M_star / 10^9)^0.9  (Harris+2013)
	var n_mean: float = s_n * pow(max(m_star, 1e-6) / 1.0e9, 0.90)

	var n_phys: int   = clampi(_poisson(galaxy_seed, C.HashPurpose.CLUSTER_GC_N, n_mean), 0, GC_N_PHYS)
	var n_render: int = mini(n_phys, GC_N_RENDER)

	if n_render == 0:
		var empty := _empty_gc(); empty["n_phys"] = n_phys; return empty

	var r_outer: float = max(rvir_kpc if rvir_kpc > 0.0 else r200c_kpc * 1.5, 10.0)

	var pos_x    := PackedFloat32Array(); pos_x.resize(n_render)
	var pos_y    := PackedFloat32Array(); pos_y.resize(n_render)
	var pos_z    := PackedFloat32Array(); pos_z.resize(n_render)
	var masses   := PackedFloat32Array(); masses.resize(n_render)
	var ages_gyr := PackedFloat32Array(); ages_gyr.resize(n_render)
	var fehs     := PackedFloat32Array(); fehs.resize(n_render)
	var r_half   := PackedFloat32Array(); r_half.resize(n_render)
	var king_c   := PackedFloat32Array(); king_c.resize(n_render)

	# GC 나이 상한: 은하 자신보다 늙을 수 없음
	var age_hi: float = min(GC_AGE_MAX_GYR, age_gyr)

	for i in range(n_render):
		# 질량: log-normal GCMF
		var z_m := _normal(galaxy_seed, C.HashPurpose.CLUSTER_GC_MASS, i)
		var mass: float = clamp(pow(10.0, C.logx(GC_MASS_PEAK) + GC_SIGMA_DEX * z_m), 1.0e3, 1.0e7)

		# 3D 위치: r^-3.5 구형; 역 CDF r = 0.5 * (1-u)^{-1/2.5}
		var u_r := _u(galaxy_seed, C.HashPurpose.CLUSTER_GC_POS, i * 3)
		var r_kpc: float = _safe_clamp_R(
			0.5 * pow(max(1.0 - u_r, 1e-9), -1.0 / 2.5),
			0.5, r_outer
		)
		var u_phi := _u(galaxy_seed, C.HashPurpose.CLUSTER_GC_POS, i * 3 + 1)
		var u_cos := _u(galaxy_seed, C.HashPurpose.CLUSTER_GC_POS, i * 3 + 2)
		var cos_t: float = 1.0 - 2.0 * u_cos
		var sin_t: float = sqrt(max(1.0 - cos_t * cos_t, 0.0))
		var phi_gc: float = u_phi * TAU
		pos_x[i] = r_kpc * sin_t * cos(phi_gc)
		pos_y[i] = r_kpc * sin_t * sin(phi_gc)
		pos_z[i] = r_kpc * cos_t
		masses[i] = mass

		# 나이: 은하 나이 중심 Gaussian, [GC_AGE_MIN, age_hi] 클램프
		var age_center: float = clamp(age_gyr - 1.0, GC_AGE_MIN_GYR, age_hi)
		var z_age := _normal(galaxy_seed, C.HashPurpose.CLUSTER_GC_AGE, i)
		ages_gyr[i] = clamp(age_center + 1.2 * z_age, GC_AGE_MIN_GYR, age_hi)

		# 금속도: blue(60%) / red(40%) 이중 성분
		var u_pop := _u(galaxy_seed, C.HashPurpose.CLUSTER_GC_FEH, i * 2)
		var z_f   := _normal(galaxy_seed, C.HashPurpose.CLUSTER_GC_FEH, i)
		if u_pop < 0.60:
			fehs[i] = clamp(-1.60 + 0.28 * z_f, -2.5, -0.8)
		else:
			fehs[i] = clamp(-0.55 + 0.20 * z_f + 0.15 * feh, -1.2, 0.3)

		var z_rh := _normal(galaxy_seed, C.HashPurpose.CLUSTER_GC_KING, i * 2)
		r_half[i] = clamp(GC_R_HALF_PC * pow(10.0, GC_SIGMA_R_HALF * z_rh), 0.5, 30.0)

		king_c[i] = clamp(0.7 + 1.8 * _u(galaxy_seed, C.HashPurpose.CLUSTER_GC_KING, i * 2 + 1), 0.5, 2.5)

	return {
		"n_phys":    n_phys,
		"n":         n_render,
		"pos_x_kpc": pos_x,
		"pos_y_kpc": pos_y,
		"pos_z_kpc": pos_z,
		"mass_msun": masses,
		"age_gyr":   ages_gyr,
		"feh":       fehs,
		"r_half_pc": r_half,
		"king_c":    king_c
	}


static func _empty_gc() -> Dictionary:
	return {
		"n_phys": 0, "n": 0,
		"pos_x_kpc": PackedFloat32Array(), "pos_y_kpc": PackedFloat32Array(),
		"pos_z_kpc": PackedFloat32Array(), "mass_msun": PackedFloat32Array(),
		"age_gyr":   PackedFloat32Array(), "feh":       PackedFloat32Array(),
		"r_half_pc": PackedFloat32Array(), "king_c":    PackedFloat32Array()
	}


# ─────────────────────────────────────────────────────────────────────────────
# 3. 거대분자운 (GMC) 샘플링
#    참고: Solomon+1987 CMF; Larson 1981 크기-질량; Colombo+2014 f_gas 의존성
# ─────────────────────────────────────────────────────────────────────────────

static func sample_gmcs(
	galaxy_seed: int,
	f_gas:       float,  # [use] 평균 GMC 질량 변조 (f_gas ↑ → 소형 GMC 풍부)
	m_gas_msun:  float,
	Rd_kpc:      float,
	spiral:      Dictionary,
	galaxy_type: int
) -> Dictionary:
	if galaxy_type == GalaxyData.GalaxyType.E:
		return _empty_gmc()

	# [f_gas] 가스 분율이 높을수록 평균 GMC 질량 낮아짐 (파편화 효율 증가)
	#   Δlog<M_GMC>/Δlog(f_gas) ≈ -0.20  (Colombo+2014 PAWS 기반)
	var gmc_mean_mass: float = clamp(
		GMC_MASS_REF * pow(max(f_gas, 1e-3) / 0.30, -0.20),
		GMC_MASS_MIN * 2.0, GMC_MASS_MAX * 0.5
	)

	var n_mean: float = clamp(max(m_gas_msun, 0.0) / gmc_mean_mass, 0.0, float(GMC_N_PHYS))

	var n_phys: int   = clampi(_poisson(galaxy_seed, C.HashPurpose.CLUSTER_GMC_N, n_mean), 0, GMC_N_PHYS)
	var n_render: int = mini(n_phys, GMC_N_RENDER)

	if n_render == 0:
		var empty := _empty_gmc(); empty["n_phys"] = n_phys; return empty

	var pos_x    := PackedFloat32Array(); pos_x.resize(n_render)
	var pos_y    := PackedFloat32Array(); pos_y.resize(n_render)
	var masses   := PackedFloat32Array(); masses.resize(n_render)
	var radii_pc := PackedFloat32Array(); radii_pc.resize(n_render)

	# 역 CDF 상수: CMF dN/dM ~ M^{-1.8}
	var alpha_m1: float = GMC_CMF_ALPHA - 1.0  # = 0.8
	var ratio: float    = pow(GMC_MASS_MIN / GMC_MASS_MAX, alpha_m1)

	for i in range(n_render):
		var u_m := _u(galaxy_seed, C.HashPurpose.CLUSTER_GMC_MASS, i * 2)
		var mass: float = clamp(
			GMC_MASS_MIN * pow(max(1.0 - u_m * (1.0 - ratio), 1e-9), -1.0 / alpha_m1),
			GMC_MASS_MIN, GMC_MASS_MAX
		)

		# Larson(1981): R [pc] ~ 0.10 * sqrt(M [Msun]) + 0.2 dex 산포
		var z_r := _normal(galaxy_seed, C.HashPurpose.CLUSTER_GMC_MASS, i * 2 + 1)
		radii_pc[i] = clamp(0.10 * sqrt(mass) * pow(10.0, 0.20 * z_r), 5.0, 500.0)

		var R_kpc: float = _safe_clamp_R(
			_sample_R_disk(galaxy_seed, C.HashPurpose.CLUSTER_GMC_R, i, Rd_kpc),
			0.02, Rd_kpc * 5.0
		)
		var phi := _sample_phi_spiral(
			galaxy_seed, i, R_kpc, Rd_kpc, spiral,
			C.HashPurpose.CLUSTER_GMC_PHI, C.HashPurpose.CLUSTER_GMC_PHI_ARM
		)
		pos_x[i]  = R_kpc * cos(phi)
		pos_y[i]  = R_kpc * sin(phi)
		masses[i] = mass

	return {
		"n_phys":    n_phys,
		"n":         n_render,
		"pos_x_kpc": pos_x,
		"pos_y_kpc": pos_y,
		"mass_msun": masses,
		"radius_pc": radii_pc
	}


static func _empty_gmc() -> Dictionary:
	return {
		"n_phys": 0, "n": 0,
		"pos_x_kpc": PackedFloat32Array(), "pos_y_kpc": PackedFloat32Array(),
		"mass_msun": PackedFloat32Array(),  "radius_pc": PackedFloat32Array()
	}


# ─────────────────────────────────────────────────────────────────────────────
# 최종 묶음
# ─────────────────────────────────────────────────────────────────────────────

static func build_clusters(
	galaxy_seed:       int,
	galaxy_type:       int,
	sfr_msun_per_yr:   float,
	log10_m_star_msun: float,
	feh:               float,
	age_gyr:           float,
	f_gas:             float,
	m_gas_msun:        float,
	Rd_kpc:            float,
	spiral:            Dictionary,
	rvir_kpc:          float,
	r200c_kpc:         float
) -> Dictionary:
	var ob := sample_ob_associations(
		galaxy_seed, sfr_msun_per_yr, age_gyr, feh,
		Rd_kpc, spiral, galaxy_type
	)
	var gc := sample_globular_clusters(
		galaxy_seed, log10_m_star_msun, age_gyr, feh,
		galaxy_type, rvir_kpc, r200c_kpc
	)
	var gmc := sample_gmcs(
		galaxy_seed, f_gas, m_gas_msun,
		Rd_kpc, spiral, galaxy_type
	)
	return {
		"ob_associations":   ob,
		"globular_clusters": gc,
		"gmcs":              gmc
	}
