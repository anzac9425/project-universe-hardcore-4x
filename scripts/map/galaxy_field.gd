extends RefCounted
class_name GalaxyField

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GalaxyField.gd
# Phase 6 (Steps 17-20): 나선 구조 파라미터 샘플링
# Phase 7 (Steps 21-26): 공간 분포 PDF, 별 위치 샘플링, 회전 곡선, 안정성 필터
#
# 반환 좌표계: 디스크 평면 (x, y) [kpc]
# z 좌표는 후속 단계에서 부여
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const N_STAR_MAX: int = 1_000_000
const N_STAR_MIN: int = 0

const R_DISK_CUTOFF_RD: float = 6.0
const R_BULGE_CUTOFF_RE: float = 8.0
const BULGE_MAX_ATTEMPTS: int = 64

const KROUPA_MEAN_MASS_MSUN: float = 0.329
const ARM_PHI_SIGMA_RAD: float = 0.22
const STABLE_Q_THRESHOLD: float = 1.0

const MAX_DISK_RESAMPLE: int = 32


# ───────────────────────────────────────────────────────────────────────────
# 내부 유틸
# ───────────────────────────────────────────────────────────────────────────

static func _u(seed_: int, purpose: int, index: int) -> float:
	return C.hash_float(seed_, purpose, index)

static func _normal_from_hash(seed_: int, purpose: int, index: int) -> float:
	var u1: float = max(_u(seed_, purpose, index * 2), 1e-12)
	var u2: float = max(_u(seed_, purpose, index * 2 + 1), 1e-12)
	return sqrt(-2.0 * log(u1)) * cos(TAU * u2)

static func _bn(n: float) -> float:
	if n <= 0.0:
		return 1.0
	# Ciotti & Bertin 근사
	#var inv := 1.0 / n
	return 2.0 * n - 1.0 / 3.0 + 4.0 / (405.0 * n) + 46.0 / (25515.0 * n * n) + 131.0 / (1148175.0 * n * n * n)

static func _wrap_angle(phi: float) -> float:
	var p := fmod(phi, TAU)
	return p if p >= 0.0 else p + TAU

static func _halo_get(halo, key: StringName, default_value):
	if halo == null:
		return default_value
	if halo is Dictionary:
		return halo.get(key, default_value)
	var v = halo.get(key)
	return default_value if v == null else v


# ───────────────────────────────────────────────────────────────────────────
# PHASE 6 — 나선 구조 파라미터 (Steps 17-20)
# ───────────────────────────────────────────────────────────────────────────

static func sample_spiral_params(
	galaxy_seed: int,
	galaxy_type: int,
	f_gas: float,
	log10_m_star_msun: float,
	halo_spin: float
) -> Dictionary:
	# [use] galaxy_type -> arm existence / morphology
	# [use] halo_spin -> pitch/contrast modulation
	if galaxy_type == GalaxyData.GalaxyType.E or galaxy_type == GalaxyData.GalaxyType.S0:
		return {
			"has_arms": false,
			"arm_count": 0,
			"pitch_deg": 0.0,
			"contrast": 0.0,
			"phases": []
		}

	var u_arm := _u(galaxy_seed, C.HashPurpose.GALAXY_SPIRAL_ARM_COUNT, 0)
	var arm_count: int = 2

	match galaxy_type:
		GalaxyData.GalaxyType.Sa:
			arm_count = 2
		GalaxyData.GalaxyType.Sb:
			arm_count = 2 if u_arm < 0.55 else 4
		GalaxyData.GalaxyType.Sc:
			arm_count = 4 if u_arm < 0.70 else 2
		GalaxyData.GalaxyType.Irr:
			return {
			"has_arms": false,
			"arm_count": 0,
			"pitch_deg": 0.0,
			"contrast": 0.0,
			"phases": []
			}
		_:
			arm_count = 2

	var z_pitch := _normal_from_hash(galaxy_seed, C.HashPurpose.GALAXY_SPIRAL_PITCH, 0)
	var spin_term := C.logx(max(halo_spin, 1e-6) / 0.035)
	var mu_pitch: float = 22.0 - 3.5 * clamp(log10_m_star_msun - 10.5, -1.5, 1.5) + 4.0 * spin_term
	var pitch_deg: float = clamp(mu_pitch + 5.0 * z_pitch, 5.0, 35.0)

	var z_contrast := _normal_from_hash(galaxy_seed, C.HashPurpose.GALAXY_SPIRAL_CONTRAST, 0)
	var contrast: float = clamp((0.30 + 0.90 * f_gas + 0.20 * z_contrast) * (1.0 + 0.20 * spin_term), 0.05, 2.5)

	var phases: Array = []
	for k in range(arm_count):
		var base := TAU * float(k) / float(arm_count)
		var u_off := _u(galaxy_seed, C.HashPurpose.GALAXY_SPIRAL_PHASE, k)
		phases.append(base + 0.40 * (u_off - 0.5)) # [use] arm phase offset

	return {
		"has_arms": true,
		"arm_count": arm_count,
		"pitch_deg": pitch_deg,
		"contrast": contrast,
		"phases": phases
	}
	
	







# ───────────────────────────────────────────────────────────────────────────
# STEP 21 — 반경 방향 표면밀도 프로파일
# ───────────────────────────────────────────────────────────────────────────

static func sigma_disk(R_kpc: float, Rd_kpc: float) -> float:
	if Rd_kpc <= 0.0:
		return 0.0
	return exp(-R_kpc / Rd_kpc)

static func sigma_sersic(R_kpc: float, r_eff_kpc: float, n: float) -> float:
	if r_eff_kpc <= 0.0 or n <= 0.0:
		return 0.0
	var R: float = max(R_kpc, 1e-9)
	var bn := _bn(n)
	return exp(-bn * (pow(R / r_eff_kpc, 1.0 / n) - 1.0))


static func surface_density_pdf(
	R_kpc: float,
	phi: float,
	M_disk_msun: float,
	Rd_kpc: float,
	M_bulge_msun: float,
	r_eff_kpc: float,
	n_sersic: float,
	spiral: Dictionary,
	poisson_noise_sigma: float = 0.0
) -> float:
	var disk: float = max(M_disk_msun, 0.0) * sigma_disk(R_kpc, Rd_kpc)
	var bulge: float = max(M_bulge_msun, 0.0) * sigma_sersic(R_kpc, r_eff_kpc, n_sersic)

	var arm_factor := 1.0
	if bool(spiral.get("has_arms", false)):
		arm_factor = arm_density_factor(
			R_kpc,
			phi,
			int(spiral.get("arm_count", 0)),
			float(spiral.get("pitch_deg", 0.0)),
			spiral.get("phases", []),
			float(spiral.get("contrast", 0.0)),
			Rd_kpc
		)

	var density := disk * arm_factor + bulge

	# Poisson noise 근사: multiplicative jitter
	if poisson_noise_sigma > 0.0:
		var noise := 1.0 + poisson_noise_sigma * _normal_from_hash(
			int(M_disk_msun + M_bulge_msun),
			C.HashPurpose.GALAXY_STAR_COMPONENT,
			int(abs(R_kpc) * 1000.0) + int(abs(phi) * 1000.0)
		)
		density *= max(noise, 0.0)

	return max(density, 0.0)


# ───────────────────────────────────────────────────────────────────────────
# STEP 22 — 나선팔 변조 PDF
# ───────────────────────────────────────────────────────────────────────────

static func arm_density_factor(
	R_kpc: float,
	phi: float,
	arm_count: int,
	pitch_deg: float,
	phases: Array,
	contrast: float,
	Rd_kpc: float
) -> float:
	if arm_count <= 0 or contrast <= 0.0:
		return 1.0

	var pitch_rad := deg_to_rad(clamp(pitch_deg, 3.0, 40.0))
	var inv_tan_pitch: float = 1.0 / max(tan(pitch_rad), 1e-6)
	var period := TAU / float(arm_count)
	var log_R := log(max(R_kpc, 0.05) / max(Rd_kpc, 0.01))
	var sum := 0.0

	for k in range(arm_count):
		var phi_arm := float(phases[k]) + log_R * inv_tan_pitch
		var dphi := phi - phi_arm
		dphi -= round(dphi / period) * period
		sum += exp(-0.5 * dphi * dphi / (ARM_PHI_SIGMA_RAD * ARM_PHI_SIGMA_RAD))

	return 1.0 + contrast * sum / float(arm_count)


# ───────────────────────────────────────────────────────────────────────────
# STEP 23 — 별 총 개수 결정
# ───────────────────────────────────────────────────────────────────────────

static func compute_n_star(m_star_msun: float, base_n_star_: int) -> int:
	var m_mean: float = max(KROUPA_MEAN_MASS_MSUN, 1e-6)
	var n_phys: float = max(m_star_msun, 0.0) / m_mean
	
	var n_phys_ref: float = max(C.M_STAR_MSUN_MILKYWAY, 1e-6) / m_mean
	var scale: float = n_phys / n_phys_ref
	
	var n_scaled_phys: int = int(round(base_n_star_ * scale))
	return clampi(n_scaled_phys, N_STAR_MIN, N_STAR_MAX)


# ───────────────────────────────────────────────────────────────────────────
# STEP 24 — 별 위치 샘플링
# ───────────────────────────────────────────────────────────────────────────

static func _sample_R_disk(seed_: int, star_idx: int, Rd_kpc: float) -> float:
	# Gamma(2, Rd) = 지수 디스크의 정확한 2D marginal. cutoff 불필요.
	# P(R > 10·Rd) ≈ 4.5e-4; 실질적으로 발산 없음.
	var u1: float = max(_u(seed_, C.HashPurpose.GALAXY_STAR_R_DISK, star_idx * 2),     1e-12)
	var u2: float = max(_u(seed_, C.HashPurpose.GALAXY_STAR_R_DISK, star_idx * 2 + 1), 1e-12)
	return -Rd_kpc * (log(u1) + log(u2))

# ── Sérsic 샘플링 사전계산 (은하당 1회) ─────────────────────────────────
static func _precompute_sersic_proposal(r_eff_kpc: float, n: float) -> Dictionary:
	var bn   := _bn(n)
	var R_max := r_eff_kpc * R_BULGE_CUTOFF_RE

	# 투영 PDF p(R) ∝ R·Σ(R)의 모드
	var R_mode: float = max(r_eff_kpc * pow(max(n / max(bn, 1e-3), 1e-9), n), 1e-5)

	# 3개 Gamma(2, scale) 혼합: 핵·본체·외곽
	var s0: float = max(R_mode * 0.8, r_eff_kpc * 1e-3)
	var s1 := r_eff_kpc * 0.30
	var s2 := r_eff_kpc * 0.90
	const W0 := 0.25; const W1 := 0.45; const W2 := 0.30

	# 로그 등간격 512점 스캔 → M = sup(target / proposal) 계산
	var log_R_min := log(max(R_mode * 0.05, 1e-5))
	var log_R_max := log(R_max)
	var M := 1e-30

	for i in range(512):
		var R := exp(lerp(log_R_min, log_R_max, (float(i) + 0.5) / 512.0))
		var tgt := R * exp(-bn * (pow(R / r_eff_kpc, 1.0 / n) - 1.0))
		var q0  := (R / (s0 * s0)) * exp(-R / s0)
		var q1  := (R / (s1 * s1)) * exp(-R / s1)
		var q2  := (R / (s2 * s2)) * exp(-R / s2)
		var q   := W0 * q0 + W1 * q1 + W2 * q2
		if q > 1e-30:
			M = max(M, tgt / q)

	return {
		"bn": bn, "n": n, "r_eff": r_eff_kpc, "R_max": R_max,
		"s0": s0, "s1": s1, "s2": s2,
		"w0": W0, "w1": W1, "w2": W2,
		"M": M * 1.05   # 5% 마진
	}


# ── 벌지 반경 샘플링 (사전계산된 제안 분포 사용) ───────────────────────────
static func _sample_R_bulge(seed_: int, star_idx: int, prop: Dictionary) -> float:
	var bn    := float(prop["bn"])
	var n     := float(prop["n"])
	var re    := float(prop["r_eff"])
	var R_max := float(prop["R_max"])
	var s0    := float(prop["s0"]); var s1 := float(prop["s1"]); var s2 := float(prop["s2"])
	var w0    := float(prop["w0"]); var w1 := float(prop["w1"]); var w2 := float(prop["w2"])
	var M     := float(prop["M"])

	const MAX_ATT := 512
	for attempt in range(MAX_ATT):
		var b  := star_idx * MAX_ATT * 4 + attempt * 4

		# 혼합 성분 선택
		var uc := _u(seed_, C.HashPurpose.GALAXY_STAR_R_BULGE, b)
		var scale := s2
		if   uc < w0:       scale = s0
		elif uc < w0 + w1:  scale = s1

		# Gamma(2, scale) 샘플
		var u1: float = max(_u(seed_, C.HashPurpose.GALAXY_STAR_R_BULGE, b + 1), 1e-12)
		var u2: float = max(_u(seed_, C.HashPurpose.GALAXY_STAR_R_BULGE, b + 2), 1e-12)
		var R_prop := -scale * (log(u1) + log(u2))
		if R_prop <= 0.0 or R_prop > R_max:
			continue

		# Rejection
		var tgt := R_prop * exp(-bn * (pow(R_prop / re, 1.0 / n) - 1.0))
		var q0  := (R_prop / (s0 * s0)) * exp(-R_prop / s0)
		var q1  := (R_prop / (s1 * s1)) * exp(-R_prop / s1)
		var q2  := (R_prop / (s2 * s2)) * exp(-R_prop / s2)
		var q   := w0 * q0 + w1 * q1 + w2 * q2
		var ua  := _u(seed_, C.HashPurpose.GALAXY_STAR_R_BULGE, b + 3)

		if q > 1e-30 and ua <= tgt / (M * q):
			return R_prop

	# 폴백: 단일점 수렴 대신 로그 균일 분포 (0.01·re ~ 1.5·re)
	var u_fb := _u(seed_, C.HashPurpose.GALAXY_STAR_R_BULGE, star_idx + 1_200_000_000)
	return re * exp(log(0.01) + (log(1.5) - log(0.01)) * u_fb)


static func _sample_phi(
	seed_: int,
	star_idx: int,
	R_kpc: float,
	Rd_kpc: float,
	spiral: Dictionary
) -> float:
	var has_arms: bool = bool(spiral.get("has_arms", false))
	var contrast: float = float(spiral.get("contrast", 0.0))
	var arm_count: int = int(spiral.get("arm_count", 0))
	var pitch_deg: float = float(spiral.get("pitch_deg", 0.0))
	var phases: Array = spiral.get("phases", [])

	var p_arm := 0.0
	if has_arms and contrast > 0.01:
		p_arm = contrast / (1.0 + contrast)

	var u_mode := _u(seed_, C.HashPurpose.GALAXY_STAR_PHI_MODE, star_idx)
	if u_mode >= p_arm:
		return _u(seed_, C.HashPurpose.GALAXY_STAR_PHI_UNIFORM, star_idx) * TAU

	# arm 선택
	var u_sel := _u(seed_, C.HashPurpose.GALAXY_STAR_PHI_ARM_SEL, star_idx)
	var k: int = int(u_sel * max(arm_count, 1)) % max(arm_count, 1)

	var pitch_rad := deg_to_rad(max(pitch_deg, 3.0))
	var phi_arm: float = float(phases[k]) + log(max(R_kpc, 0.01) / max(Rd_kpc, 0.01)) / max(tan(pitch_rad), 1e-6)

	# 가우시안 산포
	var u1: float = max(_u(seed_, C.HashPurpose.GALAXY_STAR_PHI_ARM_JIT, star_idx * 2), 1e-12)
	var u2: float = max(_u(seed_, C.HashPurpose.GALAXY_STAR_PHI_ARM_JIT, star_idx * 2 + 1), 1e-12)
	var z := sqrt(-2.0 * log(u1)) * cos(TAU * u2)

	return phi_arm + ARM_PHI_SIGMA_RAD * z


static func sample_star_positions_kpc(
	galaxy_seed: int,
	n_star: int,
	f_disk: float,
	f_bulge: float,
	f_star_halo: float,
	Rd_kpc: float,
	r_eff_kpc: float,
	n_sersic: float,
	spiral: Dictionary,
	r_halo_inner_kpc: float = 0.10,   # 기본값 변경 (0.1 kpc)
	r_halo_outer_kpc: float = 50.0
) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(n_star)

	var f_total: float = max(f_disk + f_bulge + f_star_halo, 1e-6)
	var p_disk  := f_disk  / f_total
	var p_bulge := f_bulge / f_total

	# R_disk_max 제거 — Gamma(2,Rd)로 자연 falloff
	var sersic_prop := _precompute_sersic_proposal(r_eff_kpc, n_sersic)

	for i in range(n_star):
		var u_comp := _u(galaxy_seed, C.HashPurpose.GALAXY_STAR_COMPONENT, i)
		var R: float; var phi: float

		if u_comp < p_disk:
			R   = _sample_R_disk(galaxy_seed, i, Rd_kpc)   # R_max 인수 없음
			phi = _sample_phi(galaxy_seed, i, R, Rd_kpc, spiral)

		elif u_comp < p_disk + p_bulge:
			R   = _sample_R_bulge(galaxy_seed, i, sersic_prop)
			phi = _u(galaxy_seed, C.HashPurpose.GALAXY_STAR_PHI_UNIFORM, i + 10_000_000) * TAU

		else:
			R   = _sample_R_halo(galaxy_seed, i, r_halo_inner_kpc, r_halo_outer_kpc)
			phi = _u(galaxy_seed, C.HashPurpose.GALAXY_STAR_PHI_HALO, i) * TAU

		out[i] = Vector2(R * cos(phi), R * sin(phi))

	return out


# ───────────────────────────────────────────────────────────────────────────
# STEP 25 — 회전 곡선
# ───────────────────────────────────────────────────────────────────────────

static func build_rotation_curve(
	halo,
	M_disk_msun: float,
	Rd_kpc: float,
	M_bulge_msun: float,
	r_eff_kpc: float,
	n_samples: int = 200,
	R_max_kpc: float = -1.0
) -> Dictionary:
	var rvir := float(_halo_get(halo, "rvir_kpc", 0.0))
	var rs := float(_halo_get(halo, "rs_kpc", 1.0))
	var rho_s := float(_halo_get(halo, "rho_s", _halo_get(halo, "rho_s_msun_kpc3", 0.0)))

	var R_max := rvir if R_max_kpc <= 0.0 else R_max_kpc
	R_max = max(R_max, 0.05)

	var R_arr := PackedFloat32Array()
	var V_arr := PackedFloat32Array()
	R_arr.resize(n_samples)
	V_arr.resize(n_samples)

	for i in range(n_samples):
		var t := 0.0
		if n_samples > 1:
			t = float(i) / float(n_samples - 1)

		# 중심부를 더 촘촘하게
		var R := 0.02 + (R_max - 0.02) * t * t
		var V := C.rotation_curve_kms(
			R,
			rs,
			rho_s,
			M_disk_msun,
			Rd_kpc,
			M_bulge_msun,
			r_eff_kpc
		)

		R_arr[i] = R
		V_arr[i] = V

	return {
		"R_kpc": R_arr,
		"V_kms": V_arr
	}


static func v_at_R(rc: Dictionary, R_kpc: float) -> float:
	var R_arr: PackedFloat32Array = rc.get("R_kpc", PackedFloat32Array())
	var V_arr: PackedFloat32Array = rc.get("V_kms", PackedFloat32Array())
	var n := R_arr.size()
	if n == 0:
		return 0.0
	if R_kpc <= R_arr[0]:
		return V_arr[0]
	if R_kpc >= R_arr[n - 1]:
		return V_arr[n - 1]

	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if R_arr[mid] <= R_kpc:
			lo = mid
		else:
			hi = mid

	var denom: float = max(R_arr[hi] - R_arr[lo], 1e-9)
	var t := (R_kpc - R_arr[lo]) / denom
	return lerp(V_arr[lo], V_arr[hi], t)


# ───────────────────────────────────────────────────────────────────────────
# STEP 26 — Jeans / Hill 안정성 필터
# ───────────────────────────────────────────────────────────────────────────

static func build_toomre_profile(
	halo,
	M_disk_msun: float,
	Rd_kpc: float,
	Sigma0_msun_kpc2: float,
	M_bulge_msun: float,
	r_eff_kpc: float,
	sigma_R_kms: float = 25.0,
	n_samples: int = 80
) -> Dictionary:
	var rvir := float(_halo_get(halo, "rvir_kpc", 0.0))
	var rs := float(_halo_get(halo, "rs_kpc", 1.0))
	var rho_s := float(_halo_get(halo, "rho_s", _halo_get(halo, "rho_s_msun_kpc3", 0.0)))

	var R_max: float = min(rvir, Rd_kpc * R_DISK_CUTOFF_RD)
	R_max = max(R_max, 0.1)

	var R_arr := PackedFloat32Array()
	var Q_arr := PackedFloat32Array()
	R_arr.resize(n_samples)
	Q_arr.resize(n_samples)

	for i in range(n_samples):
		var t := 0.0
		if n_samples > 1:
			t = float(i) / float(n_samples - 1)

		var R: float = 0.05 + (R_max - 0.05) * t
		var Sigma: float = max(Sigma0_msun_kpc2 * exp(-R / max(Rd_kpc, 1e-6)), 0.0)
		var kappa := C.epicyclic_kms_kpc(
			R,
			rs,
			rho_s,
			M_disk_msun,
			Rd_kpc,
			M_bulge_msun,
			r_eff_kpc
		)

		var Q := C.toomre_q(sigma_R_kms, kappa, Sigma)
		R_arr[i] = R
		Q_arr[i] = clamp(Q, 0.0, 50.0)

	return {
		"R_kpc": R_arr,
		"Q": Q_arr
	}


static func stable_inner_radius_kpc(toomre_profile: Dictionary) -> float:
	var R_arr: PackedFloat32Array = toomre_profile.get("R_kpc", PackedFloat32Array())
	var Q_arr: PackedFloat32Array = toomre_profile.get("Q", PackedFloat32Array())

	if R_arr.size() == 0 or Q_arr.size() == 0:
		return 0.0

	for i in range(min(R_arr.size(), Q_arr.size())):
		if Q_arr[i] >= STABLE_Q_THRESHOLD:
			return R_arr[i]

	return R_arr[R_arr.size() - 1]


static func hill_radius_kpc(R_kpc: float, m_star_msun: float, V_c_kms: float) -> float:
	if R_kpc <= 0.0 or V_c_kms <= 0.0 or m_star_msun <= 0.0:
		return 0.0

	# M_enc ≈ V²R/G
	var M_enc: float = V_c_kms * V_c_kms * R_kpc / max(C.G_KPC_KM2_S2_MSUN, 1e-30)
	return R_kpc * pow(m_star_msun / max(3.0 * M_enc, 1e-30), 1.0 / 3.0)


static func minimum_neighbor_distance_kpc(R_kpc: float, m_star_msun: float, V_c_kms: float) -> float:
	return 2.0 * hill_radius_kpc(R_kpc, m_star_msun, V_c_kms)


static func estimate_sigma_R_kms(v_circ_kms: float) -> float:
	return clamp(0.15 * max(v_circ_kms, 0.0), 8.0, 60.0)

# ───────────────────────────────────────────────────────────────────────────
# 최종 묶음: 한 번에 필요한 값 만들기
# ───────────────────────────────────────────────────────────────────────────

static func _sample_R_halo(
	seed_: int,
	star_idx: int,
	r_inner_kpc: float,
	r_outer_kpc: float
) -> float:
	# log-uniform → 투영 표면밀도 ∝ 1/R (stellar halo 근사)
	var u := _u(seed_, C.HashPurpose.GALAXY_STAR_R_HALO, star_idx)
	var r_in: float = max(r_inner_kpc,  1e-3)
	var r_out: float = max(r_outer_kpc,  r_in * 2.0)
	return r_in * pow(r_out / r_in, u)

static func build_galaxy_field(
	galaxy_seed: int,
	halo,
	M_star_msun: float,
	M_disk_msun: float,
	M_bulge_msun: float,
	Rd_kpc: float,
	r_eff_kpc: float,
	n_sersic: float,
	f_disk: float,
	f_bulge: float,
	f_star_halo: float,    # 추가
	galaxy_type: int,
	f_gas: float,
	age_gyr: float,
	feh: float,
	halo_spin: float,
	m_gas_msun: float,
	base_n_star_: int
) -> Dictionary:
	var spiral := sample_spiral_params(
		galaxy_seed, galaxy_type, f_gas,
		C.logx(max(M_star_msun, 1e-6)), halo_spin
	)

	var n_star := compute_n_star(M_star_msun, base_n_star_)

	var sigma0 := 0.0
	if Rd_kpc > 0.0:
		sigma0 = M_disk_msun / (TAU * Rd_kpc * Rd_kpc)

	var rc       := build_rotation_curve(halo, M_disk_msun, Rd_kpc, M_bulge_msun, r_eff_kpc)
	var v_ref    := v_at_R(rc, max(2.2 * Rd_kpc, 0.1))
	var sigma_R  := estimate_sigma_R_kms(v_ref)
	var toomre   := build_toomre_profile(halo, M_disk_msun, Rd_kpc, sigma0, M_bulge_msun, r_eff_kpc, sigma_R)
	var stable_R := stable_inner_radius_kpc(toomre)

	# ── Stellar halo 반경 ────────────────────────────────────────────────
	# inner: bulge effective radius (halo는 bulge 바깥에서 시작)
	# outer: rvir (halo 전체 범위), 없으면 r200c의 2배로 fallback
	var rs_kpc_val := float(_halo_get(halo, "rs_kpc", 1.0))
	var r_halo_in: float  = max(rs_kpc_val * 0.05, 0.10)  # 최소 100 pc
	# r_halo_out 기존 유지
	var rvir_kpc  := float(_halo_get(halo, "rvir_kpc",  0.0))
	var r200c_kpc := float(_halo_get(halo, "r200c_kpc", 0.0))
	var r_halo_out := rvir_kpc if rvir_kpc > 0.0 else r200c_kpc * 2.0
	r_halo_out = max(r_halo_out, r_eff_kpc * 4.0)

	# 기존 _bulge_rejection_bound 및 apply_stability_filter 호출 제거
	# stable_inner_radius는 분석/디버그용으로만 유지

	var positions := sample_star_positions_kpc(
		galaxy_seed,
		n_star,
		f_disk,
		f_bulge,
		f_star_halo,
		Rd_kpc,
		r_eff_kpc,
		n_sersic,
		spiral,
		# stable_inner_radius_kpc 파라미터 없음
		r_halo_in,
		r_halo_out
	)

	var star_population := StarPhysics.build_star_population(
		galaxy_seed, n_star, age_gyr, feh,
		galaxy_type, m_gas_msun, halo_spin
	)

	return {
		"spiral":                   spiral,
		"n_star":                   n_star,
		"rotation_curve":           rc,
		"toomre_profile":           toomre,
		"stable_inner_radius_kpc":  stable_R,
		"positions_kpc":            positions,
		"star_population":          star_population
	}
