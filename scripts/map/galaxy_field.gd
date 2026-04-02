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

const N_STAR_MAX: int = 2_000
const N_STAR_MIN: int = 2_000

const R_DISK_CUTOFF_RD: float = 6.0
const R_BULGE_CUTOFF_RE: float = 8.0
const BULGE_MAX_ATTEMPTS: int = 64

const KROUPA_MEAN_MASS_MSUN: float = 0.329
const ARM_PHI_SIGMA_RAD: float = 0.22
const STABLE_Q_THRESHOLD: float = 1.0


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
			arm_count = 0
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

static func compute_n_star(m_star_msun: float, n_max: int = N_STAR_MAX) -> int:
	var m_mean: float = max(KROUPA_MEAN_MASS_MSUN, 1e-6)
	var n_phys := int(round(max(m_star_msun, 0.0) / m_mean))
	return clampi(n_phys, N_STAR_MIN, n_max)


# ───────────────────────────────────────────────────────────────────────────
# STEP 24 — 별 위치 샘플링
# ───────────────────────────────────────────────────────────────────────────

static func _sample_R_disk(seed_: int, star_idx: int, Rd_kpc: float, R_max: float) -> float:
	var u1: float = max(_u(seed_, C.HashPurpose.GALAXY_STAR_R_DISK, star_idx * 2), 1e-12)
	var u2: float = max(_u(seed_, C.HashPurpose.GALAXY_STAR_R_DISK, star_idx * 2 + 1), 1e-12)
	return min(-Rd_kpc * (log(u1) + log(u2)), R_max)

static func _bulge_target_pdf(R_kpc: float, r_eff_kpc: float, n: float) -> float:
	var R: float = max(R_kpc, 1e-9)
	var bn := _bn(n)
	return R * exp(-bn * (pow(R / max(r_eff_kpc, 1e-6), 1.0 / n) - 1.0))

static func _bulge_proposal_pdf(R_kpc: float, R_peak: float) -> float:
	if R_kpc <= 0.0 or R_peak <= 0.0:
		return 0.0
	return (R_kpc / (R_peak * R_peak)) * exp(-R_kpc / R_peak)

static func _bulge_rejection_bound(r_eff_kpc: float, n: float) -> float:
	var bn := _bn(n)
	var R_peak: float = max(r_eff_kpc * pow(n / bn, n), 1e-3)
	var R_max: float = max(r_eff_kpc * R_BULGE_CUTOFF_RE, R_peak * 4.0)
	var best := 1e-30

	# coarse scan으로 sup(p/q) 근사
	for i in range(128):
		var t := float(i) / 127.0
		var R: float = max(1e-4, R_max * t)
		var p := _bulge_target_pdf(R, r_eff_kpc, n)
		var q: float = max(_bulge_proposal_pdf(R, R_peak), 1e-30)
		best = max(best, p / q)

	return best * 1.05

static func _sample_R_bulge(seed_: int, star_idx: int, r_eff_kpc: float, n: float) -> float:
	var bn := _bn(n)
	var R_peak: float = max(r_eff_kpc * pow(n / bn, n), 1e-3)
	var R_max: float = max(r_eff_kpc * R_BULGE_CUTOFF_RE, R_peak * 4.0)
	var M := _bulge_rejection_bound(r_eff_kpc, n)

	for attempt in range(BULGE_MAX_ATTEMPTS):
		var base := star_idx * BULGE_MAX_ATTEMPTS * 2 + attempt * 2
		var u1: float = max(_u(seed_, C.HashPurpose.GALAXY_STAR_R_BULGE, base), 1e-12)
		var u2: float = max(_u(seed_, C.HashPurpose.GALAXY_STAR_R_BULGE, base + 1), 1e-12)

		# Gamma(2, R_peak)
		var R_prop := -R_peak * (log(u1) + log(u2))
		if R_prop <= 0.0 or R_prop > R_max:
			continue

		var p := _bulge_target_pdf(R_prop, r_eff_kpc, n)
		var q: float = max(_bulge_proposal_pdf(R_prop, R_peak), 1e-30)
		var u_acc := _u(seed_, C.HashPurpose.GALAXY_STAR_R_BULGE, base + 1_000_000)

		if u_acc <= p / (M * q):
			return R_prop

	return R_peak


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
	Rd_kpc: float,
	r_eff_kpc: float,
	n_sersic: float,
	spiral: Dictionary,
	stable_inner_radius_kpc_: float = 0.0
) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(n_star)

	var f_total: float = max(f_disk + f_bulge, 1e-6)
	var p_disk := f_disk / f_total
	var R_disk_max: float = max(Rd_kpc * R_DISK_CUTOFF_RD, 0.01)
	var R_stable: float = max(stable_inner_radius_kpc_, 0.0)

	for i in range(n_star):
		var u_comp := _u(galaxy_seed, C.HashPurpose.GALAXY_STAR_COMPONENT, i)
		var R: float
		var phi: float

		if u_comp < p_disk:
			R = _sample_R_disk(galaxy_seed, i, Rd_kpc, R_disk_max)
			phi = _sample_phi(galaxy_seed, i, R, Rd_kpc, spiral)

			# 불안정 영역 재배치
			if R_stable > 0.0 and R < R_stable:
				var u_jit := _u(galaxy_seed, C.HashPurpose.GALAXY_STAR_PHI_UNIFORM, i + 20_000_000)
				R = R_stable + abs(_normal_from_hash(galaxy_seed, C.HashPurpose.GALAXY_STAR_PHI_ARM_JIT, i)) * max(0.12 * R_stable, 0.05)
				R = min(R, R_disk_max)
				phi = _wrap_angle(phi + (u_jit - 0.5) * 0.2)
		else:
			R = _sample_R_bulge(galaxy_seed, i, r_eff_kpc, n_sersic)
			phi = _u(galaxy_seed, C.HashPurpose.GALAXY_STAR_PHI_UNIFORM, i + 10_000_000) * TAU

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
	var rho_s := float(_halo_get(halo, "rho_s_msun_kpc3", 0.0))

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
	var rho_s := float(_halo_get(halo, "rho_s_msun_kpc3", 0.0))

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


static func apply_stability_filter(
	positions_kpc: PackedVector2Array,
	galaxy_seed: int,
	stable_inner_radius_kpc_: float
) -> PackedVector2Array:
	if stable_inner_radius_kpc_ <= 0.0:
		return positions_kpc

	var out := positions_kpc.duplicate()
	for i in range(out.size()):
		var p := out[i]
		var R := p.length()
		if R < stable_inner_radius_kpc_:
			var phi := atan2(p.y, p.x)
			var u := _u(galaxy_seed, C.HashPurpose.GALAXY_STAR_PHI_UNIFORM, i + 30_000_000)
			var jitter: float = abs(_normal_from_hash(galaxy_seed, C.HashPurpose.GALAXY_STAR_PHI_ARM_JIT, i))
			R = stable_inner_radius_kpc_ + max(0.05, 0.12 * stable_inner_radius_kpc_ * jitter)
			phi = _wrap_angle(phi + (u - 0.5) * 0.25)
			out[i] = Vector2(R * cos(phi), R * sin(phi))
	return out


# ───────────────────────────────────────────────────────────────────────────
# 최종 묶음: 한 번에 필요한 값 만들기
# ───────────────────────────────────────────────────────────────────────────

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
	galaxy_type: int,
	f_gas: float,
	age_gyr: float,
	feh: float,
	halo_spin: float,
	m_gas_msun: float
) -> Dictionary:
	# [use] galaxy_type -> spiral structure
	# [use] age_gyr / feh / m_gas / halo_spin -> StarPhysics population
	var spiral := sample_spiral_params(galaxy_seed, galaxy_type, f_gas, C.logx(max(M_star_msun, 1e-6)), halo_spin)

	var n_star := compute_n_star(M_star_msun)

	var sigma0 := 0.0
	if Rd_kpc > 0.0:
		sigma0 = M_disk_msun / (TAU * Rd_kpc * Rd_kpc)

	var rc := build_rotation_curve(halo, M_disk_msun, Rd_kpc, M_bulge_msun, r_eff_kpc)

	var v_ref := v_at_R(rc, max(2.2 * Rd_kpc, 0.1))
	var sigma_R := estimate_sigma_R_kms(v_ref)

	var toomre := build_toomre_profile(halo, M_disk_msun, Rd_kpc, sigma0, M_bulge_msun, r_eff_kpc, sigma_R)
	var stable_R := stable_inner_radius_kpc(toomre)

	var positions := sample_star_positions_kpc(
		galaxy_seed,
		n_star,
		f_disk,
		f_bulge,
		Rd_kpc,
		r_eff_kpc,
		n_sersic,
		spiral,
		stable_R
	)

	var star_population := StarPhysics.build_star_population(
		galaxy_seed,
		n_star,
		age_gyr,
		feh,
		galaxy_type,
		m_gas_msun, # [use] m_gas -> IMF bias
		halo_spin
	)

	return {
		"spiral": spiral,
		"n_star": n_star,
		"rotation_curve": rc,
		"toomre_profile": toomre,
		"stable_inner_radius_kpc": stable_R,
		"positions_kpc": positions,
		"star_population": star_population
	}
