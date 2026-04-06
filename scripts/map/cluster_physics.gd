extends RefCounted
class_name ClusterPhysics

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
#   Kroupa & Boily (2002)              – 성단 질량 함수 dN/dM ∝ M⁻²
#   Lada & Lada (2003)                 – embedded cluster survival / CMF
#   Goddard+2010, Adamo+2011           – cluster formation efficiency Γ_cl
#   Kennicutt (1998)                   – Q_H per unit SFR (Salpeter IMF)
#   Vacca (1994)                       – Kroupa IMF 이온화 광자율 보정
#   Schaerer (2003)                    – UV photon temporal evolution
#   Wood & Churchwell (1989)           – HII 영역 전자밀도 분포
#   Osterbrock (1989)                  – Strömgren sphere
#   Elmegreen & Efremov (1997)         – OB 성협 크기-질량 관계
#   Mel'nik & Efremov (1995)           – MW OB 성협 목록 (~70–100개)
#   Alfaro+2008                        – MW OB 성협 외부 확장 (~200개)
#   Harris (1991, 2015)                – GC specific frequency, GCMF
#   Harris, Harris & Hudson (2015)     – M_GC,tot/M_halo ≈ η = 3.5×10⁻⁵
#   Burkert & Forbes (2020)            – 은하 타입별 η 변동
#   Jordan+2007                        – evolved GCMF (log-normal turnover)
#   Peng+2006 (ACSVCS)                 – GC 금속도 이중 계통 파라미터
#   van den Bergh (1994)               – GC 크기-질량 관계
#   McLaughlin & van der Marel (2005)  – King 프로파일 집중도 통계
#   Solomon+1987                       – GMC 질량 함수, Larson 법칙 재교정
#   Rosolowsky+2005, Colombo+2014      – GMC 질량 함수
#   Larson (1981)                      – size–linewidth relation
#   Blitz & Rosolowsky (2006)          – R_mol vs midplane pressure (β=0.92)
#   Elmegreen (1993)                   – ISM midplane pressure formula
#   Federrath & Klessen (2012)         – turbulence–SFR link
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ─────────────────────────────────────────────────────────────────────────────
# HashPurpose 별칭  — C.HashPurpose 열거형 값을 그대로 사용 (임의 정수 금지)
# ─────────────────────────────────────────────────────────────────────────────
const _HP_OB_N        := C.HashPurpose.CLUSTER_OB_N
const _HP_OB_MASS     := C.HashPurpose.CLUSTER_OB_MASS
const _HP_OB_AGE      := C.HashPurpose.CLUSTER_OB_AGE
const _HP_OB_R        := C.HashPurpose.CLUSTER_OB_R
const _HP_OB_PHI      := C.HashPurpose.CLUSTER_OB_PHI
const _HP_OB_PHI_ARM  := C.HashPurpose.CLUSTER_OB_PHI_ARM
const _HP_OB_SIZE     := C.HashPurpose.CLUSTER_OB_SIZE
const _HP_HII_N_E     := C.HashPurpose.CLUSTER_HII_N_E
const _HP_GC_N        := C.HashPurpose.CLUSTER_GC_N
const _HP_GC_MASS     := C.HashPurpose.CLUSTER_GC_MASS
const _HP_GC_POS      := C.HashPurpose.CLUSTER_GC_POS
const _HP_GC_AGE      := C.HashPurpose.CLUSTER_GC_AGE
const _HP_GC_FEH      := C.HashPurpose.CLUSTER_GC_FEH
const _HP_GC_KING     := C.HashPurpose.CLUSTER_GC_KING
const _HP_GMC_N       := C.HashPurpose.CLUSTER_GMC_N
const _HP_GMC_MASS    := C.HashPurpose.CLUSTER_GMC_MASS
const _HP_GMC_R       := C.HashPurpose.CLUSTER_GMC_R
const _HP_GMC_PHI     := C.HashPurpose.CLUSTER_GMC_PHI
const _HP_GMC_PHI_ARM := C.HashPurpose.CLUSTER_GMC_PHI_ARM
const _HP_TURB_MODE   := C.HashPurpose.CLUSTER_TURB_MODE

# ─────────────────────────────────────────────────────────────────────────────
# 렌더링 / 성능 상한
# ─────────────────────────────────────────────────────────────────────────────
const N_OB_MAX:  int = 500
const N_GC_MAX:  int = 5000
const N_GMC_MAX: int = 3000

# ─────────────────────────────────────────────────────────────────────────────
# STEP 30a — OB 성협 물리 상수
# ─────────────────────────────────────────────────────────────────────────────

# 성단 질량 함수: dN/dM ∝ M⁻²  (Kroupa & Boily 2002; Lada & Lada 2003)
const ALPHA_OB:      float = 2.0
# M_OB_MIN: O 별 형성 최소 질량 조건 (~10 O 별 × ~10 Msun/star)
# 관측: 은하수 내 최소 OB 성협 질량 ~ 100–200 Msun (Mel'nik & Efremov 1995)
const M_OB_MIN_MSUN: float = 100.0
const M_OB_MAX_MSUN: float = 2.0e5

# OB 성협 개수 경험식 교정 (순환 논리 제거)
# 기준: 은하수 SFR=2 Msun/yr → 인식된 OB 성협 ~150개
#   Mel'nik & Efremov 1995: ~70–100 (2 kpc 이내 완전성)
#   Alfaro+2008: ~200 (전 디스크 외삽 포함)
#   중앙값 채택: N_OB_MW = 150
# β_OB = 0.85: 높은 SFR에서 성협 병합·블렌딩 → 아선형 스케일링
const N_OB_MW:   float = 150.0
const SFR_MW:    float = 2.0       # [Msun/yr]
const BETA_OB:   float = 0.85

# OB 성협 이온화 단계 수명 (이온화 광자율이 임계값 이상인 기간)
const TAU_OB_MYR: float = 20.0     # [Myr]

# 이온화 광자율: Kennicutt (1998) Salpeter 값에 Kroupa IMF 보정 +11%
# Vacca (1994): Kroupa IMF는 질량 범위 [0.1, 120] Msun에서
#   q_H0/SFR ≈ 1.0e53 photons/s per Msun/yr (Kennicutt 기준의 ~1.11배)
# → Q_H0_PER_MSUN = 1.40e46 × 1.11 ≈ 1.55e46 photons s⁻¹ Msun⁻¹
const Q_H0_PER_MSUN: float = 1.55e46   # [photons s⁻¹ Msun⁻¹]
# Schaerer (2003): τ_Q ~ 3–5 Myr (집단 별 탄생에 대한 q_H0 지수 감소)
const TAU_Q_MYR:     float = 4.0       # [Myr]

# Strömgren 반지름 (Osterbrock 1989)
const ALPHA_B_CM3_S: float = 2.6e-13  # case-B 재결합 계수 @ T=10^4 K [cm³ s⁻¹]
const N_E_REF_CM3:   float = 10.0     # 기준 전자 밀도 [cm⁻³]
const PC_TO_CM:      float = 3.085677581e18

# OB 성협 물리 크기: r_c [pc] = A × (M/1000 Msun)^0.5  (Elmegreen & Efremov 1997)
# Soft 산포: log-정규 σ=0.25 dex (관측 크기 분산 반영)
const OB_SIZE_A_PC:    float = 12.0   # M=1000 Msun 기준 반지름 [pc]
const OB_SIZE_IDX:     float = 0.50
const OB_SIZE_SIGMA:   float = 0.25   # [dex]

# ─────────────────────────────────────────────────────────────────────────────
# STEP 30b — 구상성단(GC) 물리 상수
# ─────────────────────────────────────────────────────────────────────────────

# Harris, Harris & Hudson (2015) 헤일로 질량 비율
# M_GC,tot / M_halo = η, 산포 σ=0.25 dex (Figure 7)
# 은하수 검증: M_halo=10^12 Msun → M_GC,tot=3.5×10^7 Msun
#             N_GC = M_GC,tot / <M_GC> ≈ 3.5e7 / 2.8e5 ≈ 125  ✓ (관측 ~150)
const ETA_GC:       float = 3.5e-5
const ETA_GC_SIGMA: float = 0.25   # [dex]

# 진화된 GCMF: log-정규 (Harris 1991; Jordan+2007)
# turnover: ~2×10⁵ Msun, σ=0.52 dex
const M_GC_MU_LOG10:    float = 5.30    # log₁₀(2×10⁵)
const M_GC_SIGMA_LOG10: float = 0.52
const M_GC_MIN_MSUN:    float = 1.0e3
const M_GC_MAX_MSUN:    float = 1.0e7
# GCMF 평균 질량 (log-정규: <M> = 10^(μ + σ²·ln10/2))
# = 10^(5.30 + 0.52²×1.151/2) = 10^(5.30+0.155) ≈ 2.83×10⁵ Msun
const M_GC_MEAN_MSUN:   float = 2.83e5

# GC 금속도 이중 계통 (Peng+2006, ACSVCS 순처녀자리 GC 관측)
# 청색 계통 (원시 헤일로, metal-poor): 비율 ~70%
const GC_FEH_BLUE_MU:    float = -1.55  # [dex]
const GC_FEH_BLUE_SIGMA: float = 0.25   # [dex]
# 적색 계통 (후기 disk/bulge, metal-rich): 비율 ~30%
const GC_FEH_RED_MU:     float = -0.38  # [dex]
const GC_FEH_RED_SIGMA:  float = 0.24   # [dex]
const GC_FRAC_BLUE:      float = 0.70

# 반값 반지름 크기-질량 관계 (van den Bergh 1994; Masters+2010)
# r_h [pc] = R_H_REF × (M/M_REF)^β ± σ_rh [dex]
const R_H_GC_REF_PC:  float = 3.0      # M=2×10⁵ Msun 기준
const M_GC_REF_MSUN:  float = 2.0e5
const BETA_RH_GC:     float = 0.10     # 약한 질량 의존성
const SIGMA_RH_GC:    float = 0.18     # [dex] (McLaughlin & van der Marel 2005)

# King 프로파일 집중도 c = log₁₀(r_t / r_c)
# McLaughlin & van der Marel (2005): 은하수 GC 분포
#   중앙: c = 1.40, 산포 σ=0.30 dex
# 질량 의존성: 더 질량 있는 GC → 더 집중 (이완·조석 증발 진행)
#   Δc ≈ +0.07 × log₁₀(M/M_ref)  (경험 기울기, McLaughlin+2005)
const C_KING_MU:     float = 1.40
const C_KING_SIGMA:  float = 0.30
const C_KING_MASS_A: float = 0.07    # [dex/dex]

# ─────────────────────────────────────────────────────────────────────────────
# STEP 31a — 분자운(GMC) 물리 상수
# ─────────────────────────────────────────────────────────────────────────────

# 질량 함수: dN/dM ∝ M⁻¹·⁸  (Solomon+1987; Rosolowsky 2005; Colombo+2014)
const ALPHA_GMC:      float = 1.8
const M_GMC_MIN_MSUN: float = 1.0e4
const M_GMC_MAX_MSUN: float = 1.0e7

# N_GMC / M_H₂ 비율 (질량 함수 이중 적분)
# Numerator: ∫M^-1.8 dM / |e| = (M_min^-0.8 - M_max^-0.8) / 0.8 ≈ 7.85e-4
# Denominator: ∫M^0.2 dM / 0.2 = (M_max^0.2 - M_min^0.2) / 0.2 ≈ 94.05
# NM_RATIO = 7.85e-4 / 94.05 ≈ 8.35e-6 Msun⁻¹
# 검증: 은하수 M_H₂~10⁹ Msun → N_GMC~8350 (cap 3000으로 렌더 제한)
const NM_RATIO_GMC: float = 8.35e-6  # [Msun⁻¹]

# Larson 법칙 (Solomon+1987 재교정)
# σ_v [km/s] = L0 × (R [pc])^β,  관측 산포 ~0.20 dex
const LARSON_L0:    float = 0.72
const LARSON_BV:    float = 0.50
const LARSON_SIGMA: float = 0.20   # [dex] Solomon+1987 scatter

# 표면 밀도 (Solomon+1987)
# Σ_GMC [Msun/pc²] ~ 170, 관측 산포 ~0.30 dex
const SIGMA_GMC_REF:   float = 170.0  # [Msun pc⁻²]
const SIGMA_GMC_SIGMA: float = 0.30   # [dex] Solomon+1987 observed scatter

# ─────────────────────────────────────────────────────────────────────────────
# STEP 31b — Kolmogorov 난류 상수
# ─────────────────────────────────────────────────────────────────────────────

# 3D 파워 스펙트럼: P(k) ∝ k⁻¹¹/³ (Kolmogorov 1941)
# 진폭 스펙트럼: A(k) ∝ k⁻¹¹/⁶
# 외부 스케일 ~ 2 kpc, 내부 스케일 ~ 20 pc
const TURB_K_MIN:   float = 0.5        # [kpc⁻¹]
const TURB_K_MAX:   float = 50.0       # [kpc⁻¹]
const TURB_ALPHA:   float = 11.0 / 6.0
const N_TURB_MODES: int   = 32


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
## CDF 역함수: M = (M_min^e + u × (M_max^e - M_min^e))^(1/e),  e = 1 - α
static func _sample_powerlaw(u: float, alpha: float, m_min: float, m_max: float) -> float:
	var e   := 1.0 - alpha              # e < 0
	var lo  := pow(m_min, e)            # lo > hi (e < 0)
	var hi  := pow(m_max, e)
	return pow(clamp(lo + u * (hi - lo), 1e-300, 1e300), 1.0 / e)

## 지수 디스크 2D 한계 분포: R ~ Gamma(2, Rd)  (Box-Muller 변형)
## P(R < r) = 1 − (1 + r/Rd)·exp(−r/Rd)  →  R = −Rd·(ln u1 + ln u2)
static func _sample_R_disk(seed_: int, purpose: int, idx: int, Rd_kpc: float) -> float:
	var u1: float = max(_u(seed_, purpose, idx * 2),     1e-12)
	var u2: float = max(_u(seed_, purpose, idx * 2 + 1), 1e-12)
	return -Rd_kpc * (log(u1) + log(u2))

## 방위각 샘플: 균일 분포 또는 나선팔 편향
static func _sample_phi(
	seed_: int, phi_purpose: int, arm_purpose: int, idx: int,
	R_kpc: float, Rd_kpc: float, spiral: Dictionary
) -> float:
	var has_arms: bool   = bool(spiral.get("has_arms", false))
	var contrast: float  = float(spiral.get("contrast", 0.0))
	var arm_count: int   = int(spiral.get("arm_count", 2))
	var pitch_deg: float = float(spiral.get("pitch_deg", 20.0))
	var phases: Array    = spiral.get("phases", [])

	if not has_arms or contrast < 0.05 or arm_count == 0 or phases.is_empty():
		return _u(seed_, phi_purpose, idx) * TAU

	var p_arm := contrast / (1.0 + contrast)
	if _u(seed_, phi_purpose, idx) >= p_arm:
		return _u(seed_, arm_purpose, idx) * TAU

	var k: int    = int(_u(seed_, arm_purpose, idx + 500_000) * arm_count) % arm_count
	var pitch_rad := deg_to_rad(max(pitch_deg, 3.0))
	var phi_arm: float = float(phases[k]) \
		+ log(max(R_kpc, 0.01) / max(Rd_kpc, 0.01)) / max(tan(pitch_rad), 1e-6)

	var u1: float = max(_u(seed_, arm_purpose, (idx + 2_000_000) * 2),     1e-12)
	var u2: float = max(_u(seed_, arm_purpose, (idx + 2_000_000) * 2 + 1), 1e-12)
	return phi_arm + 0.22 * sqrt(-2.0 * log(u1)) * cos(TAU * u2)

## Soft 경계 로그정규 샘플 (logistic-normal 패턴)
## center_val: 중심 기대값, lo/hi: 물리 범위, sigma_logit: logit 공간 산포
## 관측 산포가 있는 물리량에 hard clamp 대신 사용
static func _lognormal_soft(z_raw: float, center_val: float,
		lo: float, hi: float, sigma_dex: float) -> float:
	# (1) 중심값을 logit 공간으로 변환
	var p0: float = clamp((C.logx(center_val) - C.logx(lo)) / max(C.logx(hi / lo), 1e-9), 1e-6, 1.0 - 1e-6)
	var x_logit := C.logit(p0) + sigma_dex * z_raw * 2.0  # σ_dex를 logit 스케일로 근사 변환
	# (2) sigmoid 역변환으로 [lo, hi] 내 soft 경계 적용
	return lo * pow(hi / lo, C.sigmoid(x_logit))


# ─────────────────────────────────────────────────────────────────────────────
# 분자 가스 분율  (Blitz & Rosolowsky 2006)
# ─────────────────────────────────────────────────────────────────────────────

## ISM 중간면 압력 → 분자 가스 분율 계산
##
## 압력 공식 (Elmegreen 1993; 중력 자기장 지배 다층 가스층):
##   P_mid/k_B [K/cm³] ≈ 7.2×10³ × Σ_gas² [Msun/pc²]²
##   (단위 환산: G×Σ²/2k_B, G=4.30e-3 pc Msun⁻¹ (km/s)², k_B=SI)
##
## 분자/원자 비율 (Blitz & Rosolowsky 2006):
##   R_mol = (P_mid/P_0)^β,  β=0.92,  P_0/k_B=4.3×10⁴ K/cm³
##
## 금속도 보정 (Fuchs+2009; Leroy+2011):
##   더 높은 금속도 → 더 많은 먼지 → H₂ 자기차폐 효율 증가
##   Δlog₁₀R_mol ≈ +0.30 × [Fe/H]
##
## f_mol = R_mol / (1 + R_mol)
static func f_mol_from_params(m_gas_msun: float, Rd_kpc: float, feh: float) -> float:
	if m_gas_msun <= 0.0 or Rd_kpc <= 0.0:
		return 0.0
	var Rd_pc := Rd_kpc * 1000.0
	# 디스크 평균 가스 표면 밀도 [Msun/pc²]
	# 지수 디스크: Σ_avg = M_gas / (2π Rd²)
	var sigma_g: float = m_gas_msun / max(2.0 * PI * Rd_pc * Rd_pc, 1.0)

	# log₁₀(P_mid/k_B) = log₁₀(7.2×10³) + 2×log₁₀(Σ_gas)
	#                  ≈ 3.857 + 2×log₁₀(Σ_gas)
	var log10_sigma := C.logx(max(sigma_g, 1e-6))
	var log10_P_mid := 3.857 + 2.0 * log10_sigma

	# Blitz & Rosolowsky (2006): log₁₀(P_0/k_B) = log₁₀(4.3×10⁴) ≈ 4.633
	const LOG10_P0: float = 4.633
	const BETA_BR:  float = 0.92
	var log10_R_mol: float = BETA_BR * (log10_P_mid - LOG10_P0) + 0.30 * feh
	var R_mol := pow(10.0, log10_R_mol)

	# f_mol 범위: 물리적 하한 1% (분자 가스가 전혀 없는 극단 억제)
	# soft 포화: f_mol → 1은 R_mol → ∞이므로 수치 포화만 방지
	return clamp(R_mol / (1.0 + R_mol), 0.01, 0.97)


# ─────────────────────────────────────────────────────────────────────────────
# STEP 30a — OB 성협 + HII 영역
# ─────────────────────────────────────────────────────────────────────────────

## Strömgren 구 반지름 [pc]
## R_S = (3Q_H / 4π α_B n_e²)^(1/3)  (Osterbrock 1989, eq 2.28)
static func _stromgren_radius_pc(q_h: float, n_e_cm3: float) -> float:
	if q_h <= 0.0 or n_e_cm3 <= 0.0:
		return 0.0
	var r_cm := pow(3.0 * q_h / (4.0 * PI * ALPHA_B_CM3_S * n_e_cm3 * n_e_cm3), 1.0 / 3.0)
	return r_cm / PC_TO_CM

## OB 성협 · HII 영역 생성  (Step 30a)
##
## 개수 경험식:
##   N_OB = N_OB_MW × (SFR / SFR_MW)^β_OB
##   N_OB_MW = 150  @  SFR_MW = 2 Msun/yr
##   (Mel'nik & Efremov 1995; Alfaro+2008 관측치 중앙값)
##
##   보정 항:
##   × 10^(-0.10 × feh)    — 저금속도 → 강한 이온화 → 가시성 향상 (Vacca 1994)
##   × (1+z)^0.30          — 적색편이 진화: Γ_cl 증가 (Adamo+2011)
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

	# ── 평균 개수 ────────────────────────────────────────────────────────
	var n_mean: float = N_OB_MW * pow(max(sfr_msun_per_yr, 1e-4) / SFR_MW, BETA_OB)
	n_mean *= pow(10.0, -0.10 * feh)           # 저금속도 보정
	n_mean *= pow(1.0 + max(z, 0.0), 0.30)     # z 진화 (Adamo+2011)

	# log-정규 개수 산포 σ=0.30 dex
	var z_n  := _normal(galaxy_seed, _HP_OB_N, 0)
	var n_ob := int(round(max(n_mean * pow(10.0, 0.30 * z_n), 0.0)))
	n_ob = clampi(n_ob, 0, N_OB_MAX)

	var result: Array = []
	result.resize(n_ob)

	for i in range(n_ob):
		# --- 질량: dN/dM ∝ M⁻² (역 CDF) ---
		var u_m       := _u(galaxy_seed, _HP_OB_MASS, i)
		var mass_msun := _sample_powerlaw(u_m, ALPHA_OB, M_OB_MIN_MSUN, M_OB_MAX_MSUN)

		# --- 나이: 균일 [0, τ_OB] (이온화 단계 생존 분포) ---
		var age_myr := _u(galaxy_seed, _HP_OB_AGE, i) * TAU_OB_MYR

		# --- 이온화 광자율: 나이와 함께 지수 감소 (Schaerer 2003) ---
		var q_h := Q_H0_PER_MSUN * mass_msun * exp(-age_myr / TAU_Q_MYR)

		# --- 전자 밀도: log-정규 (Wood & Churchwell 1989)
		# 기준 n_e = 10 cm⁻³ (전형적 HII 영역), σ=0.50 dex
		# 나이 인수: 내장 초기에 더 조밀 → 팽창으로 희박 (f_age)
		var z_ne     := _normal(galaxy_seed, _HP_HII_N_E, i)
		var age_frac: float = clamp(1.0 - age_myr / TAU_OB_MYR, 0.05, 1.0)
		var n_e      := N_E_REF_CM3 * pow(10.0, 0.50 * z_ne) * pow(age_frac, 0.35)

		# --- HII 영역 Strömgren 반지름 [pc] ---
		var hii_r_pc := _stromgren_radius_pc(q_h, n_e)

		# --- 물리 크기: log-정규 soft 경계 [0.5, 400] pc ---
		# 중심값: r_c = A × (M/1000)^0.5  (Elmegreen & Efremov 1997)
		# σ=0.25 dex 산포, logistic-normal으로 [0.5, 400] pc 내 soft 경계
		var r_central := OB_SIZE_A_PC * pow(mass_msun / 1000.0, OB_SIZE_IDX)
		var z_sz      := _normal(galaxy_seed, _HP_OB_SIZE, i)
		var size_pc   := _lognormal_soft(z_sz, r_central, 0.5, 400.0, OB_SIZE_SIGMA)

		# --- 위치: 지수 디스크 + 나선팔 편향 ---
		var R_kpc := _sample_R_disk(galaxy_seed, _HP_OB_R, i, Rd_kpc)
		var phi   := _sample_phi(galaxy_seed, _HP_OB_PHI, _HP_OB_PHI_ARM, i,
			R_kpc, Rd_kpc, spiral)

		result[i] = {
			"pos_kpc":       Vector2(R_kpc * cos(phi), R_kpc * sin(phi)),
			"R_kpc":         R_kpc,
			"mass_msun":     mass_msun,
			"age_myr":       age_myr,
			"size_pc":       size_pc,
			"q_h":           q_h,
			"hii_radius_pc": hii_r_pc,   # Strömgren 반지름 복원
			"n_e_cm3":       n_e
		}

	return result


# ─────────────────────────────────────────────────────────────────────────────
# STEP 30b — 구상성단 (Globular Clusters)
# ─────────────────────────────────────────────────────────────────────────────

## 은하 타입별 η_GC 보정 계수
## E/S0: 초기 격렬한 별 형성 / 더 깊은 포텐셜 우물 → 높은 η
## Irr: 낮은 금속도 + 얕은 우물 → 낮은 η
## Burkert & Forbes (2020) + Harris+2015 타입별 평균에서 도출
static func _eta_factor_for_type(galaxy_type: int) -> float:
	match galaxy_type:
		GalaxyData.GalaxyType.E:   return 1.60
		GalaxyData.GalaxyType.S0:  return 1.25
		GalaxyData.GalaxyType.Sa:  return 1.05
		GalaxyData.GalaxyType.Sb:  return 0.90
		GalaxyData.GalaxyType.Sc:  return 0.65
		GalaxyData.GalaxyType.Irr: return 0.35
	return 0.80

## 구상성단 생성  (Step 30b)
##
## 개수:
##   M_GC,tot = ETA_GC × η_type × M_halo,  산포 σ=0.25 dex
##   N_GC = M_GC,tot / <M_GC>              (<M_GC> = 2.83×10⁵ Msun)
##
## 공간 분포: n_3D(r) ∝ r⁻³·⁵  (Harris 1976; Djorgovski & Meylan 1994)
##   dN/dr ∝ r^(2−3.5) = r⁻¹·⁵  → _sample_powerlaw(u, 1.5, r_in, r_out)
##
## 금속도 이중 계통 (Peng+2006):
##   청색 (70%): [Fe/H] = −1.55 ± 0.25
##   적색 (30%): [Fe/H] = −0.38 ± 0.24
##
## 나이 soft 경계: tanh 압축으로 [0.5, 13.8] Gyr 내 부드럽게 제한
static func sample_globular_clusters(
	galaxy_seed:  int,
	m_vir_msun:   float,
	_m_star_msun:  float,
	galaxy_type:  int,
	age_gyr:      float,
	_feh:          float,
	rvir_kpc:     float
) -> Array:
	# ── 총 GC 질량 → 개수 ────────────────────────────────────────────
	var eta_type  := _eta_factor_for_type(galaxy_type)
	var z_n_log   := _normal(galaxy_seed, _HP_GC_N, 0)
	var m_gc_tot  := ETA_GC * eta_type * m_vir_msun * pow(10.0, ETA_GC_SIGMA * z_n_log)
	var n_gc      := int(round(max(m_gc_tot / M_GC_MEAN_MSUN, 0.0)))
	n_gc = clampi(n_gc, 0, N_GC_MAX)

	var result: Array = []
	result.resize(n_gc)

	var r_in_kpc  := 0.10
	var r_out_kpc: float = max(rvir_kpc, 5.0)

	for i in range(n_gc):
		# --- 질량: 진화된 GCMF log-정규, soft tanh 경계 ---
		var z_m       := _normal(galaxy_seed, _HP_GC_MASS, i)
		var log10_m_raw := M_GC_MU_LOG10 + M_GC_SIGMA_LOG10 * z_m
		# soft 경계: hard clamp 대신 tanh 압축 (상수.gd 금속도 프로파일 동일 패턴)
		const MID_LOG := 5.0; const HALF_LOG := 2.0
		var log10_m := MID_LOG + HALF_LOG * tanh((log10_m_raw - MID_LOG) / HALF_LOG)
		var mass_msun := pow(10.0, log10_m)

		# --- 금속도: 이중 계통 (Peng+2006) ---
		var u_pop   := _u(galaxy_seed, _HP_GC_FEH, i * 2)
		var z_feh   := _normal(galaxy_seed, _HP_GC_FEH, i * 2 + 1)
		var gc_feh: float
		if u_pop < GC_FRAC_BLUE:
			# 청색 계통: [Fe/H] = -1.55 ± 0.25, soft 경계 [-2.8, -0.6]
			var raw := GC_FEH_BLUE_MU + GC_FEH_BLUE_SIGMA * z_feh
			gc_feh = -1.7 + 1.1 * tanh((raw + 1.7) / 1.1)
		else:
			# 적색 계통: [Fe/H] = -0.38 ± 0.24, soft 경계 [-1.2, 0.5]
			var raw := GC_FEH_RED_MU + GC_FEH_RED_SIGMA * z_feh
			gc_feh = -0.35 + 0.85 * tanh((raw + 0.35) / 0.85)

		# --- 나이: 대부분 초기 우주 형성 (z>2) ---
		# 청색: galaxy_age × 0.92 ± 1.5 Gyr  (더 오래됨)
		# 적색: galaxy_age × 0.78 ± 1.5 Gyr  (더 최근, bulge/disk 형성 연계)
		var z_age   := _normal(galaxy_seed, _HP_GC_AGE, i)
		var is_blue := u_pop < GC_FRAC_BLUE
		var base_a: float = max(age_gyr * (0.92 if is_blue else 0.78), 1.0)
		var gc_age_raw: float = base_a + 1.5 * z_age
		# soft 경계 [0.5, 13.8] Gyr
		const AGE_MID  := 7.15
		const AGE_HALF := 6.65
		var gc_age := AGE_MID + AGE_HALF * tanh((gc_age_raw - AGE_MID) / AGE_HALF)

		# --- 3D 위치: n(r) ∝ r⁻³·⁵ 구형 헤일로 ---
		# dN/dr ∝ r^{2-3.5} = r^{-1.5}  → alpha=1.5
		var u_r    := _u(galaxy_seed, _HP_GC_POS, i * 3)
		var R3d    := _sample_powerlaw(u_r, 1.5, r_in_kpc, r_out_kpc)

		var u_theta    := _u(galaxy_seed, _HP_GC_POS, i * 3 + 1)
		var u_phi      := _u(galaxy_seed, _HP_GC_POS, i * 3 + 2)
		var cos_th     := 1.0 - 2.0 * u_theta
		var sin_th     := sqrt(max(1.0 - cos_th * cos_th, 0.0))
		var phi_3d     := u_phi * TAU
		var x_kpc      := R3d * sin_th * cos(phi_3d)
		var y_kpc      := R3d * sin_th * sin(phi_3d)
		var z_kpc      := R3d * cos_th

		# --- 반값 반지름 (van den Bergh 1994; McLaughlin & van der Marel 2005) ---
		# σ=0.18 dex, logistic-normal soft 경계 [0.5, 30] pc
		var z_rh    := _normal(galaxy_seed, _HP_GC_KING, i * 2)
		var rh_cen  := R_H_GC_REF_PC * pow(mass_msun / M_GC_REF_MSUN, BETA_RH_GC)
		var r_h_pc  := _lognormal_soft(z_rh, rh_cen, 0.5, 30.0, SIGMA_RH_GC)

		# --- King 집중도 c = log₁₀(r_t/r_c) ---
		# 질량 의존성: 더 질량 있는 GC → 더 집중 (이완·조석 침식으로 분리됨)
		var z_c     := _normal(galaxy_seed, _HP_GC_KING, i * 2 + 1)
		var c_center := C_KING_MU + C_KING_MASS_A * (C.logx(mass_msun) - C.logx(M_GC_REF_MSUN))
		# soft 경계 [0.4, 2.8]: 물리 범위 (McLaughlin & van der Marel 2005 최대 c~2.5 관측)
		var c_raw   := c_center + C_KING_SIGMA * z_c
		var c_king  := 1.6 + 1.2 * tanh((c_raw - 1.6) / 1.2)

		result[i] = {
			"pos_kpc":   Vector2(x_kpc, y_kpc),
			"pos_z_kpc": z_kpc,
			"R3d_kpc":   R3d,
			"mass_msun": mass_msun,
			"age_gyr":   gc_age,
			"feh":       gc_feh,
			"r_half_pc": r_h_pc,
			"c_king":    c_king,
			"is_blue":   is_blue
		}

	return result


# ─────────────────────────────────────────────────────────────────────────────
# STEP 31a — 분자운 (Giant Molecular Clouds)
# ─────────────────────────────────────────────────────────────────────────────

## GMC 물리 반지름 [pc]: M = π R² Σ_GMC  →  R = sqrt(M / πΣ)
static func _gmc_radius_pc(mass_msun: float, sigma_surf: float) -> float:
	return sqrt(max(mass_msun, 1.0) / (PI * max(sigma_surf, 1.0)))

## GMC 내부 속도 분산 [km/s]: Larson 법칙 σ_v = L0 × R^β_v  (Solomon+1987)
## 산포 σ=0.20 dex (log-정규)
static func _gmc_sigma_v(radius_pc: float, z_v: float) -> float:
	return LARSON_L0 * pow(max(radius_pc, 0.1), LARSON_BV) * pow(10.0, LARSON_SIGMA * z_v)

## GMC 자기 진동 매개변수 (gravitational virial parameter)
## α_vir = 5 σ_v² R / (G M)   (McKee & Zweibel 1992)
## 자기 속박 기준: α_vir ~ 1–2
## G [pc (km/s)² / Msun] = 4.300917e-3
static func _gmc_virial(mass_msun: float, radius_pc: float, sigma_v_kms: float) -> float:
	const G_PC_KM2_S2_MSUN: float = 4.300917e-3
	if mass_msun <= 0.0 or radius_pc <= 0.0:
		return 999.0
	return 5.0 * sigma_v_kms * sigma_v_kms * radius_pc / (G_PC_KM2_S2_MSUN * mass_msun)

## 분자운 생성  (Step 31a)
##
## 총 분자 가스 질량: M_H₂ = f_mol × M_gas
## GMC 개수:         N_GMC = NM_RATIO × M_H₂  (질량 함수 적분)
##   Milky Way: M_H₂~10⁹ Msun → N_GMC_theory~8350 (렌더 cap 3000)
static func sample_molecular_clouds(
	galaxy_seed: int,
	m_gas_msun:  float,
	feh:         float,
	_z:           float,
	Rd_kpc:      float,
	spiral:      Dictionary
) -> Array:
	var f_mol    := f_mol_from_params(m_gas_msun, Rd_kpc, feh)
	var m_h2     := m_gas_msun * f_mol

	# GMC 개수: log-정규 산포 σ=0.25 dex
	var n_theory := int(round(m_h2 * NM_RATIO_GMC))
	var z_n      := _normal(galaxy_seed, _HP_GMC_N, 0)
	var n_gmc    := int(round(max(float(n_theory) * pow(10.0, 0.25 * z_n), 0.0)))
	n_gmc = clampi(n_gmc, 0, N_GMC_MAX)

	var result: Array = []
	result.resize(n_gmc)

	for i in range(n_gmc):
		# --- 질량: dN/dM ∝ M⁻¹·⁸ 역 CDF ---
		var u_m       := _u(galaxy_seed, _HP_GMC_MASS, i)
		var mass_msun := _sample_powerlaw(u_m, ALPHA_GMC, M_GMC_MIN_MSUN, M_GMC_MAX_MSUN)

		# --- 표면 밀도: log-정규 σ=0.30 dex (Solomon+1987 관측 산포) ---
		var z_sig    := _normal(galaxy_seed, _HP_GMC_MASS, i + 5_000_000)
		var sigma_s  := SIGMA_GMC_REF * pow(10.0, SIGMA_GMC_SIGMA * z_sig)

		# --- 물리 반지름 [pc] ---
		var radius_pc := _gmc_radius_pc(mass_msun, sigma_s)

		# --- 속도 분산: Larson 법칙 + 산포 (σ=0.20 dex) ---
		var z_v          := _normal(galaxy_seed, _HP_GMC_MASS, i + 10_000_000)
		var sigma_v_kms  := _gmc_sigma_v(radius_pc, z_v)

		# --- 자기 진동 매개변수 ---
		var alpha_vir := _gmc_virial(mass_msun, radius_pc, sigma_v_kms)

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
			"sigma_surf":  sigma_s,
			"alpha_vir":   alpha_vir    # 자기 속박 지표
		}

	return result


# ─────────────────────────────────────────────────────────────────────────────
# STEP 31b — Kolmogorov 난류 밀도장 (Fourier 모드 분해)
# ─────────────────────────────────────────────────────────────────────────────
#
# 난류 가스 밀도 변조:
#   δρ/ρ(x,y) = Σ_k  A_k · cos(kx·x + ky·y + φ_k)
#
# 3D Kolmogorov 에너지 스펙트럼: E(k) ∝ k⁻⁵/³
# → 3D 파워 스펙트럼: P(k) ∝ k⁻¹¹/³
# → 진폭 스펙트럼: A(k) ∝ k⁻¹¹/⁶
#
# Parseval 정규화: Σ A_k² = σ_turb²
#   σ_turb (상대 밀도 변동폭): Federrath & Klessen (2012)에서
#     σ_ρ/ρ ~ b·M_s  (M_s: 음속 마하수, b~0.3–1.0)
#   현재 σ_turb ≈ 0.35·SFR^0.5 는 관측 기반 경험식으로 사용
#   MW SFR=2 Msun/yr: σ_turb ≈ 0.49  →  δρ/ρ ~ 50%: 와류 원반에 적합
#
# 간헐성 보정: 진폭 log-정규 산포 σ=0.15 dex (실제 난류 간헐성 모사)

static func build_turbulence_field(
	galaxy_seed:       int,
	_Rd_kpc:            float,
	sfr_msun_per_yr:   float = 1.0
) -> Dictionary:
	var sigma_turb: float = clamp(0.35 * pow(max(sfr_msun_per_yr, 1e-3), 0.50), 0.05, 1.20)

	var log_k_min := log(TURB_K_MIN)
	var log_k_max := log(TURB_K_MAX)

	# Parseval 정규화: Σ A_k² = σ_turb²
	var sq_sum := 0.0
	for i in range(N_TURB_MODES):
		var t   := (float(i) + 0.5) / float(N_TURB_MODES)
		var k_i := exp(lerp(log_k_min, log_k_max, t))
		sq_sum  += pow(k_i, -2.0 * TURB_ALPHA)
	var amp_norm: float = sigma_turb / max(sqrt(sq_sum), 1e-30)

	var modes: Array = []
	modes.resize(N_TURB_MODES)

	for i in range(N_TURB_MODES):
		var t     := (float(i) + 0.5) / float(N_TURB_MODES)
		var k_mag := exp(lerp(log_k_min, log_k_max, t))

		# 기본 진폭: A ∝ k^{-11/6}  (Kolmogorov)
		var amp_base := amp_norm * pow(k_mag, -TURB_ALPHA)

		# 파수 방향: 균일 구면 샘플 → 등방성 난류
		var u_theta := _u(galaxy_seed, _HP_TURB_MODE, i * 3)
		var kx      := k_mag * cos(u_theta * TAU)
		var ky      := k_mag * sin(u_theta * TAU)

		# 위상: 균일 [0, 2π)
		var phi := _u(galaxy_seed, _HP_TURB_MODE, i * 3 + 1) * TAU

		# 진폭 산포: log-정규 σ=0.15 dex (간헐성 보정)
		var z_amp     := _normal(galaxy_seed, _HP_TURB_MODE, i * 3 + 2)
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

## 임의 위치 (x, y) [kpc] 의 난류 밀도 변조값 δρ/ρ
## 실제 상대 밀도 = 1 + turbulent_density_at(...)
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
