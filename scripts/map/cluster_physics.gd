extends RefCounted
class_name ClusterPhysics

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ClusterPhysics.gd  –  Phase 9 (Steps 30–31)
#
# Step 30 : OB 성협 · 구상성단(GC) · HII 영역 생성
# Step 31 : 분자운(GMC) 질량 함수 샘플링 + Kolmogorov 난류 밀도장
#
# 단위 규약
#   거리  kpc  (pc 별도 명시)
#   질량  Msun
#   속도  km/s
#   시간  Myr (클러스터 나이) / Gyr (GC 나이)
#   이온화 광자율  photons s⁻¹
#
# 주요 참고문헌
#   Lada & Lada (2003)         – embedded cluster survival / CMF
#   Kroupa & Boily (2002)      – dN/dM ∝ M⁻²
#   Goddard+2010, Adamo+2011   – cluster formation efficiency Γ_cl
#   Kennicutt (1998)           – Q_H per unit SFR
#   Osterbrock (1989)          – Strömgren sphere
#   Harris (1991, 2015)        – GC specific frequency, GCMF
#   Jordan+2007                – evolved GCMF (log-normal)
#   van den Bergh (1994)       – GC size–mass
#   Solomon+1987, Rosolowsky+2005, Colombo+2014 – GMC mass function
#   Larson (1981)              – size–linewidth relation
#   Blitz & Rosolowsky (2006)  – molecular-to-atomic ratio vs pressure
#   Federrath & Klessen (2012) – turbulence–SFR link
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ─────────────────────────────────────────────────────────────────────────────
# HashPurpose 확장 (constants.gd의 C.HashPurpose 열거형 말미에 추가할 것)
# 기존 마지막 값 GALAXY_STAR_PHI_HALO = 38 이후
# ─────────────────────────────────────────────────────────────────────────────
const _HP_OB_N:        int = C.HashPurpose.CLUSTER_OB_N
const _HP_OB_MASS:     int = C.HashPurpose.CLUSTER_OB_MASS
const _HP_OB_AGE:      int = 102   # OB 성협 나이
const _HP_OB_R:        int = 103   # OB 성협 반경 위치
const _HP_OB_PHI:      int = 104   # OB 성협 방위각 (균일/암 선택)
const _HP_OB_PHI_ARM:  int = 105   # OB 성협 나선팔 산포
const _HP_OB_SIZE:     int = 106   # OB 성협 물리적 크기 산포
const _HP_HII_N_E:     int = 107   # HII 영역 전자 밀도 산포
const _HP_GC_N:        int = 108   # GC 개수 산포
const _HP_GC_MASS:     int = 109   # GC 질량 (log-normal GCMF)
const _HP_GC_POS:      int = 110   # GC 3D 위치
const _HP_GC_AGE:      int = 111   # GC 나이
const _HP_GC_FEH:      int = 112   # GC 금속도 (이중 계통)
const _HP_GC_KING:     int = 113   # GC King 반값 반지름 · 집중도
const _HP_GMC_N:       int = 114   # GMC 개수 산포
const _HP_GMC_MASS:    int = 115   # GMC 질량 (MF 역CDF) + Σ 산포
const _HP_GMC_R:       int = 116   # GMC 반경 위치
const _HP_GMC_PHI:     int = 117   # GMC 방위각 (균일/암 선택)
const _HP_GMC_PHI_ARM: int = 118   # GMC 나선팔 산포
const _HP_TURB_MODE:   int = 119   # 난류 Fourier 모드

# ─────────────────────────────────────────────────────────────────────────────
# 렌더링 / 성능 상한
# ─────────────────────────────────────────────────────────────────────────────
const N_OB_MAX:  int = 500
const N_GC_MAX:  int = 5000
const N_GMC_MAX: int = 3000

# ─────────────────────────────────────────────────────────────────────────────
# STEP 30a — OB 성협 물리 상수
# ─────────────────────────────────────────────────────────────────────────────

# 성단 질량 함수: dN/dM ∝ M⁻² (Kroupa & Boily 2002; Lada & Lada 2003)
const ALPHA_OB:       float = 2.0
const M_OB_MIN_MSUN:  float = 50.0       # OB 성협 질량 하한
const M_OB_MAX_MSUN:  float = 1.0e5      # OB 성협 질량 상한

# 클러스터 형성 효율 (Goddard+2010, Adamo+2011)
# N_OB ≈ Γ_cl × SFR × τ_OB / <M_OB>
const GAMMA_CL:       float = 0.10       # SFR 중 성단 형성 비율
const TAU_OB_MYR:     float = 20.0       # OB 성협 이온화 수명 [Myr]
# <M_OB> = ln(M_max/M_min)/(1/M_min − 1/M_max) ≈ 400 Msun  (α=2 분포)
const M_OB_MEAN_MSUN: float = 400.0

# OB 성협 물리적 크기: r_c [pc] ~ A × (M/1000)^0.5  (Elmegreen & Efremov 1997)
const OB_SIZE_A_PC:   float = 10.0       # M=1000 Msun 기준 반지름 [pc]
const OB_SIZE_IDX:    float = 0.50       # 지수

# 이온화 광자율: Q_H₀ × M × f(age)  (Kennicutt 1998, Kroupa IMF 보정)
# f(age) = exp(−age / τ_Q),  τ_Q ~ 4 Myr (Schaerer 2003)
const Q_H0_PER_MSUN:  float = 1.4e46    # photons s⁻¹ Msun⁻¹
const TAU_Q_MYR:      float = 4.0

# Strömgren 반지름 (Osterbrock 1989): R_S = (3Q_H / 4π α_B n_e²)^{1/3}
const ALPHA_B_CM3_S:  float = 2.6e-13   # case-B 재결합 계수 [cm³ s⁻¹]
const N_E_REF_CM3:    float = 10.0      # 기준 전자 밀도 [cm⁻³]
const PC_TO_CM:       float = 3.085677581e18

# ─────────────────────────────────────────────────────────────────────────────
# STEP 30b — 구상성단(GC) 물리 상수
# ─────────────────────────────────────────────────────────────────────────────

# 진화된 GCMF: log-정규 (Harris 1991; Jordan+2007)
# 전환 질량 (turnover): ~2×10⁵ Msun
const M_GC_MU_LOG10:    float = 5.30    # log₁₀(M_turn / Msun)
const M_GC_SIGMA_LOG10: float = 0.52    # [dex]
const M_GC_MIN_MSUN:    float = 1.0e3
const M_GC_MAX_MSUN:    float = 1.0e7

# 반값 반지름 크기-질량 관계 (van den Bergh 1994; Masters+2010)
# r_h [pc] = r_h_ref × (M/M_ref)^β
const R_H_GC_REF_PC:  float = 3.0       # M = 2×10⁵ Msun 기준
const M_GC_REF_MSUN:  float = 2.0e5
const BETA_RH_GC:     float = 0.10      # 약한 질량 의존성

# King 프로파일 집중도 c = log₁₀(r_t / r_c): log-정규
const C_KING_MU:      float = 1.40
const C_KING_SIGMA:   float = 0.35

# ─────────────────────────────────────────────────────────────────────────────
# STEP 31a — 분자운(GMC) 물리 상수
# ─────────────────────────────────────────────────────────────────────────────

# 질량 함수: dN/dM ∝ M⁻¹·⁸  (Solomon+1987; Rosolowsky 2005; Colombo+2014)
const ALPHA_GMC:          float = 1.8
const M_GMC_MIN_MSUN:     float = 1.0e4   # 최소 GMC 질량
const M_GMC_MAX_MSUN:     float = 1.0e7   # 최대 GMC 질량

# N_GMC / M_H₂ 비율 (질량 함수 이중 적분, M_min=1e4, M_max=1e7)
# = [(M_min⁻⁰·⁸ − M_max⁻⁰·⁸)/0.8] / [(M_max⁰·² − M_min⁰·²)/0.2] = 8.35e-6 Msun⁻¹
const NM_RATIO_GMC: float = 8.35e-6

# Larson 법칙 (Larson 1981; Solomon+1987 재교정)
# σ_v [km/s] = L0 × (R [pc])^β_v
const LARSON_L0:    float = 0.72
const LARSON_BV:    float = 0.50

# 표면 밀도-질량 관계: Σ_GMC [Msun/pc²] ~ 170  (Solomon+1987)
# → R [pc] = sqrt(M / (π Σ))
const SIGMA_GMC_REF: float = 170.0        # [Msun pc⁻²]

# ─────────────────────────────────────────────────────────────────────────────
# STEP 31b — Kolmogorov 난류 상수
# ─────────────────────────────────────────────────────────────────────────────

# 3D 파워 스펙트럼: P(k) ∝ k⁻¹¹/³  →  진폭 A(k) ∝ k⁻¹¹/⁶
const TURB_K_MIN:    float = 0.5          # [kpc⁻¹] 외부 스케일 ~2 kpc
const TURB_K_MAX:    float = 50.0         # [kpc⁻¹] 내부 스케일 ~20 pc
const TURB_ALPHA:    float = 11.0 / 6.0   # 진폭 스펙트럼 지수
const N_TURB_MODES:  int   = 32

# ─────────────────────────────────────────────────────────────────────────────
# 내부 유틸리티
# ─────────────────────────────────────────────────────────────────────────────

static func _u(seed_: int, purpose: int, index: int) -> float:
	return C.hash_float(seed_, purpose, index)

static func _normal(seed_: int, purpose: int, index: int) -> float:
	var u1: float = max(_u(seed_, purpose, index * 2),     1e-12)
	var u2: float = max(_u(seed_, purpose, index * 2 + 1), 1e-12)
	return sqrt(-2.0 * log(u1)) * cos(TAU * u2)

## 멱함수 dN/dM ∝ M⁻α 역 CDF 샘플링  (1 < α < 2)
## CDF: F(M) = (M_min^e − M^e) / (M_min^e − M_max^e),  e = 1 − α < 0
static func _sample_powerlaw(u: float, alpha: float, m_min: float, m_max: float) -> float:
	var e   := 1.0 - alpha
	var lo  := pow(m_min, e)                           # lo > hi  (e < 0)
	var hi  := pow(m_max, e)
	var val: float = clamp(lo + u * (hi - lo), 1e-300, 1e300)
	return pow(val, 1.0 / e)

## 지수 디스크 2D 한계 분포: R ~ Gamma(2, Rd)  (정확한 역 CDF)
## P(R < r) = 1 − (1 + r/Rd) exp(−r/Rd)  → Box-Muller 변형
static func _sample_R_disk(seed_: int, purpose: int, idx: int, Rd_kpc: float) -> float:
	var u1: float = max(_u(seed_, purpose, idx * 2),     1e-12)
	var u2: float = max(_u(seed_, purpose, idx * 2 + 1), 1e-12)
	return -Rd_kpc * (log(u1) + log(u2))

## 방위각 샘플 — 균일 또는 나선팔 편향 (약식 GalaxyField._sample_phi)
## phi_purpose: 모드/균일 선택,  arm_purpose: 팔 위상·산포
static func _sample_phi(
	seed_: int, phi_purpose: int, arm_purpose: int, idx: int,
	R_kpc: float, Rd_kpc: float, spiral: Dictionary
) -> float:
	var has_arms: bool   = bool(spiral.get("has_arms", false))
	var contrast: float  = float(spiral.get("contrast", 0.0))
	var arm_count: int   = int(spiral.get("arm_count", 2))
	var pitch_deg: float = float(spiral.get("pitch_deg", 20.0))
	var phases: Array    = spiral.get("phases", [])

	# 나선팔 없거나 대비 미약 → 균일 분포
	if not has_arms or contrast < 0.05 or arm_count == 0 or phases.is_empty():
		return _u(seed_, phi_purpose, idx) * TAU

	var p_arm := contrast / (1.0 + contrast)
	if _u(seed_, phi_purpose, idx) >= p_arm:
		return _u(seed_, arm_purpose, idx) * TAU

	# 나선팔 위상
	var k: int    = int(_u(seed_, arm_purpose, idx + 500_000) * arm_count) % arm_count
	var pitch_rad := deg_to_rad(max(pitch_deg, 3.0))
	var phi_arm: float = float(phases[k]) \
		+ log(max(R_kpc, 0.01) / max(Rd_kpc, 0.01)) / max(tan(pitch_rad), 1e-6)

	# 가우시안 산포 (ARM_PHI_SIGMA_RAD ~ 0.22 rad)
	var u1: float = max(_u(seed_, arm_purpose, (idx + 2_000_000) * 2),     1e-12)
	var u2: float = max(_u(seed_, arm_purpose, (idx + 2_000_000) * 2 + 1), 1e-12)
	return phi_arm + 0.22 * sqrt(-2.0 * log(u1)) * cos(TAU * u2)

# ─────────────────────────────────────────────────────────────────────────────
# 분자 가스 분율 (Blitz & Rosolowsky 2006)
# ─────────────────────────────────────────────────────────────────────────────

## 은하 면 평균 표면 밀도로부터 분자 가스 분율 계산
##
## ISM 중간면 압력 (자기중력 지배 가스층):
##   P_mid/k_B [K/cm³] ≈ 7.2×10³ × Σ_gas² [Msun/pc²]²
##   (단위 환산: G × Σ² / (2 k_B),  G=4.30e-3 pc Msun⁻¹ (km/s)²)
##
## 분자/원자 가스 비율:
##   R_mol = (P_mid / P_0)^{β}  (β=0.92, P_0/k_B = 4.3×10⁴ K/cm³)
##
## f_mol = R_mol / (1 + R_mol)
## 금속도 보정: 먼지 차폐 ↑ → H₂ 형성 ↑  (Fuchs+2009: Δlog₁₀R_mol ≈ 0.30 × feh)
static func f_mol_from_params(m_gas_msun: float, Rd_kpc: float, feh: float) -> float:
	if m_gas_msun <= 0.0 or Rd_kpc <= 0.0:
		return 0.0
	# 디스크 평균 가스 표면 밀도 [Msun/pc²]
	var Rd_pc           := Rd_kpc * 1000.0
	var sigma_g: float = m_gas_msun / max(2.0 * PI * Rd_pc * Rd_pc, 1.0)
	# log₁₀(P_mid/k_B) = log₁₀(7.2e3) + 2 × log₁₀(Σ_gas)  ≈ 3.857 + 2 log₁₀(Σ)
	var log10_sigma     := C.logx(max(sigma_g, 1e-6))
	var log10_P_mid     := 3.857 + 2.0 * log10_sigma
	# log₁₀(P_0/k_B) = log₁₀(4.3e4) ≈ 4.633
	const LOG10_P0: float = 4.633
	var log10_R_mol     := 0.92 * (log10_P_mid - LOG10_P0) + 0.30 * feh
	var R_mol           := pow(10.0, log10_R_mol)
	return clamp(R_mol / (1.0 + R_mol), 0.01, 0.95)

# ─────────────────────────────────────────────────────────────────────────────
# STEP 30a — OB 성협 + HII 영역 (Osterbrock 1989)
# ─────────────────────────────────────────────────────────────────────────────

## Strömgren 구 반지름 [pc]
## R_S = (3 Q_H / 4π α_B n_e²)^{1/3}
static func _stromgren_radius_pc(q_h: float, n_e_cm3: float) -> float:
	if q_h <= 0.0 or n_e_cm3 <= 0.0:
		return 0.0
	var r_cm := pow(3.0 * q_h / (4.0 * PI * ALPHA_B_CM3_S * n_e_cm3 * n_e_cm3), 1.0 / 3.0)
	return r_cm / PC_TO_CM

## OB 성협 · HII 영역 생성  (Step 30a)
##
## 개수 추정:
##   N_OB_mean = Γ_cl × SFR [Msun/yr] × τ_OB [yr] / <M_OB>
##   단, 렌더링 관측 대표값에 맞게 추가 계수 적용
##   → sfr=1 Msun/yr 시 N_OB_mean ~ 130 (Milky Way 관측 OB 성협 수와 정합)
static func sample_ob_associations(
	galaxy_seed:       int,
	sfr_msun_per_yr:   float,
	feh:               float,
	z:                 float,
	Rd_kpc:            float,
	spiral:            Dictionary
) -> Array:
	if sfr_msun_per_yr <= 0.0:
		return []

	# --- 개수 ---
	# 이론값 Γ_cl × SFR × τ [yr] / M_mean 에서
	# 관측 불완전성·임계값 보정 계수 k_obs 적용 → sfr=1 → ~130개
	var k_obs := 130.0 / (GAMMA_CL * (TAU_OB_MYR * 1.0e6) / M_OB_MEAN_MSUN)
	var n_mean := k_obs * GAMMA_CL * sfr_msun_per_yr \
		* (TAU_OB_MYR * 1.0e6) / M_OB_MEAN_MSUN
	# 저금속도 → 더 강한 이온화 → 관측 확률 ↑
	n_mean *= pow(10.0, -0.12 * feh)
	# log-정규 산포 σ=0.30 dex
	var z_n  := _normal(galaxy_seed, _HP_OB_N, 0)
	var n_ob := int(round(max(n_mean * pow(10.0, 0.30 * z_n), 0.0)))
	n_ob = clampi(n_ob, 0, N_OB_MAX)

	var result: Array = []
	result.resize(n_ob)

	for i in range(n_ob):
		# --- 질량: dN/dM ∝ M⁻² ---
		var u_m      := _u(galaxy_seed, _HP_OB_MASS, i)
		var mass_msun := _sample_powerlaw(u_m, ALPHA_OB, M_OB_MIN_MSUN, M_OB_MAX_MSUN)

		# --- 나이: 균일 [0, τ_OB] (이온화 단계 생존군) ---
		var u_age  := _u(galaxy_seed, _HP_OB_AGE, i)
		var age_myr := u_age * TAU_OB_MYR

		# --- 이온화 광자율: 나이와 함께 지수 감소 ---
		var q_h := Q_H0_PER_MSUN * mass_msun * exp(-age_myr / TAU_Q_MYR)

		# --- 전자 밀도: log-정규 (기준 10 cm⁻³, σ=0.5 dex) ---
		# 젊은 성협 → 내장 단계 → 더 조밀한 HII 영역
		var z_ne  := _normal(galaxy_seed, _HP_HII_N_E, i)
		var n_e   := N_E_REF_CM3 * pow(10.0, 0.50 * z_ne) \
			* pow(max(1.0 - age_myr / TAU_OB_MYR, 0.05), 0.40)

		# --- HII 영역 Strömgren 반지름 [pc] ---
		var hii_r_pc := _stromgren_radius_pc(q_h, n_e)

		# --- 물리적 크기: r ~ A × (M/1000)^0.5  (Elmegreen & Efremov 1997) ---
		var z_sz  := _normal(galaxy_seed, _HP_OB_SIZE, i)
		var size_pc: float = clamp(
			OB_SIZE_A_PC * pow(mass_msun / 1000.0, OB_SIZE_IDX) * pow(10.0, 0.20 * z_sz),
			1.0, 500.0
		)

		# --- 위치: 지수 디스크 + 나선팔 편향 ---
		var R_kpc := _sample_R_disk(galaxy_seed, _HP_OB_R, i, Rd_kpc)
		var phi   := _sample_phi(galaxy_seed, _HP_OB_PHI, _HP_OB_PHI_ARM, i,
			R_kpc, Rd_kpc, spiral)

		result[i] = {
			"pos_kpc":      Vector2(R_kpc * cos(phi), R_kpc * sin(phi)),
			"R_kpc":        R_kpc,
			"mass_msun":    mass_msun,
			"age_myr":      age_myr,
			"size_pc":      size_pc,
			"q_h":          q_h,
			#"hii_radius_pc": hii_radius_pc,
			"n_e_cm3":      n_e
		}

	return result

# ─────────────────────────────────────────────────────────────────────────────
# STEP 30b — 구상성단 (Globular Clusters)
# ─────────────────────────────────────────────────────────────────────────────

## 은하 타입별 GC specific frequency S_N  (Harris 1991)
static func _sn_for_type(galaxy_type: int) -> float:
	match galaxy_type:
		GalaxyData.GalaxyType.E:   return 3.5
		GalaxyData.GalaxyType.S0:  return 2.0
		GalaxyData.GalaxyType.Sa:  return 1.5
		GalaxyData.GalaxyType.Sb:  return 1.0
		GalaxyData.GalaxyType.Sc:  return 0.55
		GalaxyData.GalaxyType.Irr: return 0.30
	return 0.70

## 평균 GC 개수
## 보정된 Harris (2017) 헤일로 질량 관계:
##   N_GC ≈ 120 × S_N_type × (M_vir / 10¹² Msun)^{0.98}
## Milky Way (M_vir~10¹² Msun, Sb): N_GC ~ 120 × 1.0 × 1 = 120  ✓ (관측 ~150)
static func _n_gc_mean(m_vir_msun: float, galaxy_type: int) -> float:
	var sn   := _sn_for_type(galaxy_type)
	return max(120.0 * sn * pow(max(m_vir_msun / 1.0e12, 1e-6), 0.98), 0.0)

## 구상성단 생성  (Step 30b)
##
## 공간 분포: n_GC(r) ∝ r⁻³·⁵ (3D 구형)
##   ↔ dN/dr ∝ r⁻¹·⁵  →  _sample_powerlaw(u, 1.5, r_in, r_out)
##
## 이중 금속도 계통:
##   청색(70%): [Fe/H] ~ −1.5 ± 0.30  (원시, 금속 빈약)
##   적색(30%): [Fe/H] ~ −0.5 ± 0.30  (후기, 금속 풍부)
static func sample_globular_clusters(
	galaxy_seed:  int,
	m_vir_msun:   float,
	m_star_msun:  float,
	galaxy_type:  int,
	age_gyr:      float,
	feh:          float,
	rvir_kpc:     float
) -> Array:
	# --- 개수: log-정규 산포 σ=0.35 dex ---
	var n_mean := _n_gc_mean(m_vir_msun, galaxy_type)
	var z_n    := _normal(galaxy_seed, _HP_GC_N, 0)
	var n_gc   := int(round(max(n_mean * pow(10.0, 0.35 * z_n), 0.0)))
	n_gc = clampi(n_gc, 0, N_GC_MAX)

	var result: Array = []
	result.resize(n_gc)

	var r_in_kpc  := 0.10                        # 핵 병합 회피 하한
	var r_out_kpc: float = max(rvir_kpc, 5.0)

	for i in range(n_gc):
		# --- 질량: 진화된 GCMF (log-정규 turnover) ---
		var z_m      := _normal(galaxy_seed, _HP_GC_MASS, i)
		var log10_m: float = clamp(M_GC_MU_LOG10 + M_GC_SIGMA_LOG10 * z_m,
			C.logx(M_GC_MIN_MSUN), C.logx(M_GC_MAX_MSUN))
		var mass_msun := pow(10.0, log10_m)

		# --- 금속도: 이중 계통 ---
		var u_pop   := _u(galaxy_seed, _HP_GC_FEH, i * 2)
		var z_feh   := _normal(galaxy_seed, _HP_GC_FEH, i * 2 + 1)
		var gc_feh: float
		if u_pop < 0.70:
			# 청색 계통 (원시)
			gc_feh = clamp(-1.50 + 0.30 * z_feh, -2.5, -0.80)
		else:
			# 적색 계통 (후기)
			gc_feh = clamp(-0.50 + 0.30 * z_feh, -1.20, 0.50)

		# --- 나이: 청색 GC > 적색 GC ---
		# 은하 나이 × 0.90 ± 1.5 Gyr (대부분 초기 우주에서 형성)
		var z_age := _normal(galaxy_seed, _HP_GC_AGE, i)
		var base_a: float = max(age_gyr * (0.92 if u_pop < 0.70 else 0.78), 1.0)
		var gc_age: float = clamp(base_a + 1.5 * z_age, 0.5, 13.8)

		# --- 3D 위치: n(r) ∝ r⁻³·⁵ 구형 헤일로 ---
		# dN/dr ∝ r^{2-3.5} = r⁻¹·⁵  →  alpha = 1.5
		var u_r   := _u(galaxy_seed, _HP_GC_POS, i * 3)
		var R3d   := _sample_powerlaw(u_r, 1.5, r_in_kpc, r_out_kpc)

		# 구면 좌표 (균일 구면 샘플)
		var u_theta    := _u(galaxy_seed, _HP_GC_POS, i * 3 + 1)
		var u_phi      := _u(galaxy_seed, _HP_GC_POS, i * 3 + 2)
		var cos_th     := 1.0 - 2.0 * u_theta
		var sin_th     := sqrt(max(1.0 - cos_th * cos_th, 0.0))
		var phi_3d     := u_phi * TAU
		var x_kpc      := R3d * sin_th * cos(phi_3d)
		var y_kpc      := R3d * sin_th * sin(phi_3d)
		var z_kpc      := R3d * cos_th

		# --- 반값 반지름: r_h [pc] = r_h_ref × (M/M_ref)^β ± 산포 ---
		var z_rh  := _normal(galaxy_seed, _HP_GC_KING, i * 2)
		var r_h_pc: float = clamp(
			R_H_GC_REF_PC * pow(mass_msun / M_GC_REF_MSUN, BETA_RH_GC) \
				* pow(10.0, 0.18 * z_rh),
			0.5, 30.0
		)

		# --- King 집중도 c = log₁₀(r_t/r_c) ---
		var z_c   := _normal(galaxy_seed, _HP_GC_KING, i * 2 + 1)
		var c_king: float = clamp(C_KING_MU + C_KING_SIGMA * z_c, 0.5, 2.5)

		result[i] = {
			"pos_kpc":   Vector2(x_kpc, y_kpc),
			"pos_z_kpc": z_kpc,
			"R3d_kpc":   R3d,
			"mass_msun": mass_msun,
			"age_gyr":   gc_age,
			"feh":       gc_feh,
			"r_half_pc": r_h_pc,
			"c_king":    c_king,
			"is_blue":   u_pop < 0.70
		}

	return result

# ─────────────────────────────────────────────────────────────────────────────
# STEP 31a — 분자운 (Giant Molecular Clouds)
# ─────────────────────────────────────────────────────────────────────────────

## GMC 물리 반지름 [pc]: M = π R² Σ_GMC  →  R = sqrt(M / πΣ)
static func _gmc_radius_pc(mass_msun: float, sigma_surf: float) -> float:
	return sqrt(max(mass_msun, 1.0) / (PI * max(sigma_surf, 1.0)))

## GMC 내부 속도 분산 [km/s]: Larson 법칙 σ_v = L0 × R^β
static func _gmc_sigma_v(radius_pc: float) -> float:
	return LARSON_L0 * pow(max(radius_pc, 0.1), LARSON_BV)

## 분자운 생성  (Step 31a)
##
## 총 분자 가스 질량:  M_H₂ = f_mol × M_gas
## GMC 개수 추정:      N_GMC = NM_RATIO × M_H₂  (질량 함수 적분 기반)
##   NM_RATIO = 8.35e-6 Msun⁻¹  (M_min=10⁴, M_max=10⁷, α=1.8)
##   Milky Way: M_H₂~10⁹ Msun → N_GMC~8350 (cap 3000)
static func sample_molecular_clouds(
	galaxy_seed: int,
	m_gas_msun:  float,
	feh:         float,
	z:           float,
	Rd_kpc:      float,
	spiral:      Dictionary
) -> Array:
	# 분자 가스 분율 및 총 H₂ 질량
	var f_mol    := f_mol_from_params(m_gas_msun, Rd_kpc, feh)
	var m_h2     := m_gas_msun * f_mol

	# GMC 개수 (log-정규 산포 σ=0.25 dex)
	var n_theory := int(round(m_h2 * NM_RATIO_GMC))
	var z_n      := _normal(galaxy_seed, _HP_GMC_N, 0)
	var n_gmc    := int(round(max(float(n_theory) * pow(10.0, 0.25 * z_n), 0.0)))
	n_gmc = clampi(n_gmc, 0, N_GMC_MAX)

	var result: Array = []
	result.resize(n_gmc)

	for i in range(n_gmc):
		# --- 질량: dN/dM ∝ M⁻¹·⁸ 역 CDF ---
		var u_m      := _u(galaxy_seed, _HP_GMC_MASS, i)
		var mass_msun := _sample_powerlaw(u_m, ALPHA_GMC, M_GMC_MIN_MSUN, M_GMC_MAX_MSUN)

		# --- 표면 밀도 산포: log-정규 σ=0.20 dex (Solomon+1987 scatter) ---
		var z_sig    := _normal(galaxy_seed, _HP_GMC_MASS, i + 5_000_000)
		var sigma_s  := SIGMA_GMC_REF * pow(10.0, 0.20 * z_sig)

		# --- 크기 / 운동학 ---
		var radius_pc   := _gmc_radius_pc(mass_msun, sigma_s)
		var sigma_v_kms := _gmc_sigma_v(radius_pc)

		# --- 위치: 지수 디스크 + 나선팔 편향 ---
		var R_kpc := _sample_R_disk(galaxy_seed, _HP_GMC_R, i, Rd_kpc)
		var phi   := _sample_phi(galaxy_seed, _HP_GMC_PHI, _HP_GMC_PHI_ARM, i,
			R_kpc, Rd_kpc, spiral)

		result[i] = {
			"pos_kpc":     Vector2(R_kpc * cos(phi), R_kpc * sin(phi)),
			"R_kpc":       R_kpc,
			"mass_msun":   mass_msun,
			"radius_pc":   radius_pc,
			"sigma_v_kms": sigma_v_kms,
			"sigma_surf":  sigma_s
		}

	return result

# ─────────────────────────────────────────────────────────────────────────────
# STEP 31b — Kolmogorov 난류 밀도장 (Fourier 모드 분해)
# ─────────────────────────────────────────────────────────────────────────────
#
# 난류 가스 밀도 변조:
#   δρ/ρ(x,y) = Σ_k  A_k · cos(kx·x + ky·y + φ_k)
#
# 3D Kolmogorov: P(k) ∝ k⁻¹¹/³  →  A(k) ∝ k⁻¹¹/⁶
# Parseval 정규화: Σ A_k² = σ_turb²
#   σ_turb ~ 0.35 × SFR^0.5  (Federrath & Klessen 2012)
#
# 파수 방향: 균일 랜덤 → 등방성 난류
# 각 모드 진폭 추가 산포: log-정규 σ=0.15 dex (간헐성 모델)

static func build_turbulence_field(
	galaxy_seed:       int,
	Rd_kpc:            float,
	sfr_msun_per_yr:   float = 1.0
) -> Dictionary:
	# 전체 σ_turb: SFR↑ → 더 강한 피드백 → 더 큰 난류
	var sigma_turb: float = clamp(0.35 * pow(max(sfr_msun_per_yr, 1e-3), 0.50), 0.05, 1.20)

	# 로그 등간격 파수
	var log_k_min := log(TURB_K_MIN)
	var log_k_max := log(TURB_K_MAX)

	# Parseval 정규화 계수
	# Σ A_k² = σ_turb²  →  (amp_norm × k_i^{-α})² 합산 = σ_turb²
	var sq_sum := 0.0
	for i in range(N_TURB_MODES):
		var t := (float(i) + 0.5) / float(N_TURB_MODES)
		var k_i := exp(lerp(log_k_min, log_k_max, t))
		sq_sum += pow(k_i, -2.0 * TURB_ALPHA)
	var amp_norm: float = sigma_turb / max(sqrt(sq_sum), 1e-30)

	var modes: Array = []
	modes.resize(N_TURB_MODES)

	for i in range(N_TURB_MODES):
		var t     := (float(i) + 0.5) / float(N_TURB_MODES)
		var k_mag := exp(lerp(log_k_min, log_k_max, t))

		# 기본 진폭: A ∝ k^{-11/6}
		var amp_base := amp_norm * pow(k_mag, -TURB_ALPHA)

		# 모드 방향: 균일 구면 → 등방성
		var u_theta := _u(galaxy_seed, _HP_TURB_MODE, i * 3)
		var kx := k_mag * cos(u_theta * TAU)
		var ky := k_mag * sin(u_theta * TAU)

		# 위상: 균일 [0, 2π)
		var phi := _u(galaxy_seed, _HP_TURB_MODE, i * 3 + 1) * TAU

		# 진폭 산포 (간헐성 보정: log-정규 σ=0.15 dex)
		var z_amp := _normal(galaxy_seed, _HP_TURB_MODE, i * 3 + 2)
		var amplitude := amp_base * pow(10.0, 0.15 * z_amp)

		modes[i] = {
			"kx":        kx,
			"ky":        ky,
			"amplitude": amplitude,
			"phase":     phi
		}

	return {
		"modes":      modes,
		"k_min":      TURB_K_MIN,
		"k_max":      TURB_K_MAX,
		"sigma_turb": sigma_turb,
		"n_modes":    N_TURB_MODES
	}

## 임의 위치 (x, y) [kpc] 의 난류 밀도 변조값 계산
## 반환값 δρ/ρ: 실제 상대 밀도 = 1 + turbulent_density_at(...)
static func turbulent_density_at(x_kpc: float, y_kpc: float, turb: Dictionary) -> float:
	var modes: Array = turb.get("modes", [])
	var val := 0.0
	for mode in modes:
		val += float(mode["amplitude"]) \
			* cos(float(mode["kx"]) * x_kpc \
				+ float(mode["ky"]) * y_kpc \
				+ float(mode["phase"]))
	return val

# ─────────────────────────────────────────────────────────────────────────────
# 최종 묶음 함수
# ─────────────────────────────────────────────────────────────────────────────

static func build_cluster_field(
	galaxy_seed:     int,
	m_vir_msun:      float,
	m_star_msun:     float,
	m_gas_msun:      float,
	sfr_msun_per_yr: float,
	feh:             float,
	z:               float,
	age_gyr:         float,
	galaxy_type:     int,
	Rd_kpc:          float,
	rvir_kpc:        float,
	spiral:          Dictionary
) -> Dictionary:
	# Step 30a: OB 성협 + HII 영역
	var ob_assoc := sample_ob_associations(
		galaxy_seed, sfr_msun_per_yr, feh, z, Rd_kpc, spiral
	)

	# Step 30b: 구상성단
	var glob_cl := sample_globular_clusters(
		galaxy_seed, m_vir_msun, m_star_msun, galaxy_type, age_gyr, feh, rvir_kpc
	)

	# Step 31a: 분자운
	var mol_cl := sample_molecular_clouds(
		galaxy_seed, m_gas_msun, feh, z, Rd_kpc, spiral
	)

	# Step 31b: 난류 밀도장
	var turb := build_turbulence_field(galaxy_seed, Rd_kpc, sfr_msun_per_yr)

	var f_mol := f_mol_from_params(m_gas_msun, Rd_kpc, feh)

	return {
		"ob_associations":   ob_assoc,
		"globular_clusters": glob_cl,
		"molecular_clouds":  mol_cl,
		"turbulence_field":  turb,
		"n_ob":              ob_assoc.size(),
		"n_gc":              glob_cl.size(),
		"n_gmc":             mol_cl.size(),
		"f_mol":             f_mol,
		"m_h2_msun":         m_gas_msun * f_mol
	}
