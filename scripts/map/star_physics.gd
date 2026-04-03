extends RefCounted
class_name StarPhysics

enum StellarPhase {
	MS,
	SGB,
	RGB,
	HB,
	AGB,
	WD,
	NS,
	BH
}

const SUN_T_EFF_K: float = 5772.0
const CHANDRASEKHAR_MCH_MSUN: float = 1.44
const RSUN_KM: float = 695700.0

# Kroupa IMF: dN/dm ∝ m^-1.3 (0.08–0.5), m^-2.3 (0.5–150)
const IMF_M_MIN: float = 0.08
const IMF_M_BREAK: float = 0.50
const IMF_M_MAX: float = 150.0
const IMF_ALPHA1: float = 1.3
const IMF_ALPHA2: float = 2.3

# precomputed normalization from the analytic integrals
const IMF_A1: float = 0.25290882083775484
const IMF_A2: float = 0.12645441041887742
const IMF_F_BREAK: float = 0.7606309417042441

# ZAMS anchor table (solar metallicity, approximate MIST/BaSTI-like calibration)
static var ZAMS_MASS_MSUN: PackedFloat32Array = PackedFloat32Array([
	0.08, 0.10, 0.15, 0.20, 0.30, 0.40, 0.50, 0.80,
	1.00, 1.50, 2.00, 3.00, 5.00, 10.0, 20.0, 60.0, 150.0
])

static var ZAMS_LOG10_L_LSUN: PackedFloat32Array = PackedFloat32Array([
	-3.05, -2.55, -2.00, -1.52, -1.05, -0.63, -0.38, -0.40,
	0.00, 0.85, 1.35, 2.10, 2.78, 4.00, 4.95, 5.55, 5.90
])

static var ZAMS_LOG10_TEFF_K: PackedFloat32Array = PackedFloat32Array([
	3.47, 3.49, 3.53, 3.56, 3.60, 3.64, 3.66, 3.716,
	3.762, 3.835, 3.885, 4.010, 4.200, 4.450, 4.600, 4.660, 4.680
])

static func _interp_table(x: float, xs: PackedFloat32Array, ys: PackedFloat32Array) -> float:
	if xs.size() == 0 or xs.size() != ys.size():
		return NAN
	if x <= xs[0]:
		return ys[0]
	if x >= xs[xs.size() - 1]:
		return ys[ys.size() - 1]

	var lo := 0
	var hi := xs.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if xs[mid] <= x:
			lo = mid
		else:
			hi = mid

	var denom: float = max(xs[hi] - xs[lo], 1e-9)
	var t := (x - xs[lo]) / denom
	return lerp(ys[lo], ys[hi], t)

static func _log10_radius_from_l_t(log10_l_lsun: float, log10_teff_k: float) -> float:
	# [use] Stefan-Boltzmann relation in log space
	return 0.5 * (log10_l_lsun - 4.0 * (log10_teff_k - C.logx(SUN_T_EFF_K)))

static func _radius_rsun_from_l_t(log10_l_lsun: float, log10_teff_k: float) -> float:
	return pow(10.0, _log10_radius_from_l_t(log10_l_lsun, log10_teff_k))

static func _zams_loglt(mass_msun: float, feh: float) -> Dictionary:
	# [use] feh -> ZAMS shift (metal-rich = slightly cooler / less luminous)
	var logl:= _interp_table(mass_msun, ZAMS_MASS_MSUN, ZAMS_LOG10_L_LSUN) - 0.08 * feh
	var logt := _interp_table(mass_msun, ZAMS_MASS_MSUN, ZAMS_LOG10_TEFF_K) - 0.035 * feh
	return {"logl": logl, "logt": logt}

static func _ms_lifetime_gyr(mass_msun: float, feh: float) -> float:
	# [use] age_gyr -> phase selection
	# Smooth blend of the common low/high-mass power-law scalings.
	var low := 12.5 * pow(mass_msun, -1.8)
	var high := 10.0 * pow(mass_msun, -2.5)
	var w := C.sigmoid((mass_msun - 1.0) / 0.25)
	return max(0.001, lerp(low, high, w) * pow(10.0, 0.12 * feh))

static func _post_ms_duration_gyr(mass_msun: float, ms_life_gyr: float, feh: float) -> float:
	# [use] post-MS duration from the user's rule-of-thumb ratios
	var ratio := 0.20
	if mass_msun >= 2.0 and mass_msun < 8.0:
		ratio = 0.10
	elif mass_msun >= 8.0:
		ratio = 0.05
	return max(0.001, ms_life_gyr * ratio * pow(10.0, 0.05 * feh))

static func _post_ms_fractions(mass_msun: float) -> Dictionary:
	# [use] mass-dependent phase partitioning
	if mass_msun < 2.0:
		return {"sgb": 0.12, "rgb": 0.56, "hb": 0.14, "agb": 0.18}
	elif mass_msun < 8.0:
		return {"sgb": 0.28, "rgb": 0.44, "hb": 0.20, "agb": 0.08}
	return {"sgb": 0.40, "rgb": 0.45, "hb": 0.00, "agb": 0.15}

static func _current_state(mass_msun: float, age_gyr: float, feh: float) -> Dictionary:
	var ms := _ms_lifetime_gyr(mass_msun, feh)
	var post := _post_ms_duration_gyr(mass_msun, ms, feh)
	var frac := _post_ms_fractions(mass_msun)

	if age_gyr <= ms:
		return {
			"phase": StellarPhase.MS,
			"f": clamp(age_gyr / max(ms, 1e-9), 0.0, 1.0),
			"ms": ms,
			"post": post
		}

	if age_gyr < ms + post:
		var p: float = clamp((age_gyr - ms) / max(post, 1e-9), 0.0, 1.0)

		if p < float(frac["sgb"]):
			return {"phase": StellarPhase.SGB, "f": p / float(frac["sgb"]), "ms": ms, "post": post}

		var p2: float = (p - float(frac["sgb"])) / max(float(frac["rgb"]), 1e-9)
		if p < float(frac["sgb"]) + float(frac["rgb"]):
			return {"phase": StellarPhase.RGB, "f": clamp(p2, 0.0, 1.0), "ms": ms, "post": post}

		var hb_end := float(frac["sgb"]) + float(frac["rgb"]) + float(frac["hb"])
		if p < hb_end and float(frac["hb"]) > 0.0:
			var p3: float = (p - float(frac["sgb"]) - float(frac["rgb"])) / max(float(frac["hb"]), 1e-9)
			return {"phase": StellarPhase.HB, "f": clamp(p3, 0.0, 1.0), "ms": ms, "post": post}

		var agb_span: float = max(float(frac["agb"]), 1e-9)
		var p4 := (p - float(frac["sgb"]) - float(frac["rgb"]) - float(frac["hb"])) / agb_span
		return {"phase": StellarPhase.AGB, "f": clamp(p4, 0.0, 1.0), "ms": ms, "post": post}

	# remnant gate
	if mass_msun < 8.0:
		return {"phase": StellarPhase.WD, "f": 1.0, "ms": ms, "post": post}
	elif mass_msun < 20.0:
		return {"phase": StellarPhase.NS, "f": 1.0, "ms": ms, "post": post}
	return {"phase": StellarPhase.BH, "f": 1.0, "ms": ms, "post": post}

static func _remnant_properties(mass_msun: float, age_gyr: float, ms_life_gyr: float, post_gyr: float) -> Dictionary:
	# [use] compact-object branch
	var t_cool: float = max(age_gyr - ms_life_gyr - post_gyr, 0.0)

	if mass_msun < 8.0:
		# White dwarf: IFMR + Nauenberg radius
		var m_wd: float = clamp(0.109 * mass_msun + 0.394, 0.45, 1.30)
		var x: float = clamp(m_wd / CHANDRASEKHAR_MCH_MSUN, 1e-6, 0.999999)
		var r_wd := 0.0112 * sqrt(max(1.0 - pow(x, 4.0 / 3.0), 1e-9)) / pow(x, 1.0 / 3.0)

		# cooling is a visualization proxy, not a full WD cooling track
		var log10_l := -2.25 - 1.10 * C.logx(1.0 + t_cool)
		var log10_t := 4.90 - 0.08 * C.logx(1.0 + t_cool)
		var l := pow(10.0, log10_l)
		var t := pow(10.0, log10_t)
		return {
			"phase": StellarPhase.WD,
			"phase_name": "WD",
			"m_remnant_msun": m_wd,
			"log10_l_lsun": log10_l,
			"log10_t_eff_k": log10_t,
			"l_lsun": l,
			"t_eff_k": t,
			"r_rsun": r_wd
		}

	if mass_msun < 20.0:
		# Neutron star: fixed observational scale
		var m_ns: float = clamp(1.25 + 0.04 * (mass_msun - 8.0), 1.20, 2.05)
		var r_ns := 12.0 / RSUN_KM
		return {
			"phase": StellarPhase.NS,
			"phase_name": "NS",
			"m_remnant_msun": m_ns,
			"log10_l_lsun": -5.0,
			"log10_t_eff_k": 5.70,
			"l_lsun": pow(10.0, -5.0),
			"t_eff_k": pow(10.0, 5.70),
			"r_rsun": r_ns
		}

	# Black hole: event-horizon scale only
	var m_bh: float = clamp(0.08 * mass_msun, 3.0, 60.0)
	var r_s_rsun := (2.95325008 * m_bh) / RSUN_KM
	return {
		"phase": StellarPhase.BH,
		"phase_name": "BH",
		"m_remnant_msun": m_bh,
		"log10_l_lsun": NAN,
		"log10_t_eff_k": NAN,
		"l_lsun": 0.0,
		"t_eff_k": 0.0,
		"r_rsun": r_s_rsun
	}

static func _rgb_base_logl(mass_msun: float, log10_l_zams: float, feh: float) -> float:
	if mass_msun < 2.0:
		return max(log10_l_zams + 0.20, 0.60 - 0.04 * feh)
	elif mass_msun < 8.0:
		return max(log10_l_zams + 0.12, 1.80 - 0.05 * feh)
	return max(log10_l_zams + 0.18, 3.60 - 0.06 * feh)

static func _rgb_tip_logl(mass_msun: float, feh: float) -> float:
	if mass_msun < 2.0:
		return 3.30 - 0.03 * feh
	elif mass_msun < 8.0:
		return 3.30 + 0.12 * C.logx(mass_msun / 2.0) - 0.03 * feh
	return 5.00 + 0.25 * C.logx(mass_msun / 8.0) - 0.05 * feh

static func _rgb_base_logt(mass_msun: float, log10_t_zams: float, feh: float) -> float:
	if mass_msun < 2.0:
		return min(log10_t_zams - 0.045 - 0.010 * feh, 3.69 - 0.020 * feh)
	elif mass_msun < 8.0:
		return min(log10_t_zams - 0.100 - 0.015 * feh, 3.78 - 0.025 * feh)
	return min(log10_t_zams - 0.120 - 0.020 * feh, 3.85 - 0.030 * feh)

static func _rgb_tip_logt(mass_msun: float, feh: float) -> float:
	if mass_msun < 2.0:
		return 3.58 - 0.015 * feh
	elif mass_msun < 8.0:
		return 3.62 - 0.020 * feh
	return 3.72 - 0.030 * feh

static func _hb_logl_bounds(mass_msun: float, feh: float) -> Dictionary:
	# secondary clump / HB proxy
	var l0 := 1.60 + 0.18 * C.logx(max(mass_msun, 0.6)) - 0.03 * feh
	var l1 := l0 + 0.20
	return {"l0": l0, "l1": l1}

static func _hb_logt_bounds(mass_msun: float, feh: float) -> Dictionary:
	var t0 := 3.76 - 0.015 * feh
	var t1 := 3.70 - 0.020 * feh
	if mass_msun >= 2.0:
		t0 = 3.72 - 0.010 * feh
		t1 = 3.68 - 0.015 * feh
	return {"t0": t0, "t1": t1}

static func _agb_tip_logl(mass_msun: float, feh: float) -> float:
	if mass_msun < 2.0:
		return 3.55 - 0.03 * feh
	elif mass_msun < 8.0:
		return 4.05 + 0.15 * C.logx(mass_msun / 2.0) - 0.04 * feh
	return 5.40 + 0.20 * C.logx(mass_msun / 8.0) - 0.05 * feh

static func _agb_tip_logt(mass_msun: float, feh: float) -> float:
	if mass_msun < 2.0:
		return 3.56 - 0.020 * feh
	elif mass_msun < 8.0:
		return 3.60 - 0.020 * feh
	return 3.68 - 0.030 * feh

static func stellar_phase(mass_msun: float, age_gyr: float, feh: float = 0.0) -> int:
	return int(_current_state(mass_msun, age_gyr, feh)["phase"])

static func stellar_properties(mass_msun: float, age_gyr: float, feh: float = 0.0) -> Dictionary:
	# [use] feh -> lifetime, ZAMS, post-MS track shifts
	if not is_finite(mass_msun) or mass_msun <= 0.0 or not is_finite(age_gyr) or age_gyr < 0.0:
		Log.error(201, "StarPhysics.gd")
		return {}

	var m: float = clamp(mass_msun, 0.08, 150.0)
	var z: float = clamp(feh, -2.5, 0.7)
	var zams := _zams_loglt(m, z)
	var ms := _ms_lifetime_gyr(m, z)
	var state := _current_state(m, age_gyr, z)
	var phase: int = int(state["phase"])
	var f: float = float(state["f"])
	var post := float(state["post"])

	var log10_l := 0.0
	var log10_t := 0.0
	var m_rem := 0.0
	var phase_name := "MS"

	match phase:
		StellarPhase.MS:
			phase_name = "MS"
			# [use] age_gyr -> main-sequence brightening
			log10_l = zams["logl"] + C.logx(1.0 + 1.5 * f)
			log10_t = zams["logt"] - 0.020 * f
			m_rem = 0.0

		StellarPhase.SGB:
			phase_name = "SGB"
			# [use] interpolation from TAMS toward the giant branch base
			var l0: float = zams["logl"] + C.logx(1.8)
			var t0: float = zams["logt"] - 0.018
			var l1 := _rgb_base_logl(m, zams["logl"], z)
			var t1 := _rgb_base_logt(m, zams["logt"], z)
			log10_l = lerp(l0, l1, f)
			log10_t = lerp(t0, t1, f)

		StellarPhase.RGB:
			phase_name = "RGB"
			var l0_rgb := _rgb_base_logl(m, zams["logl"], z)
			var t0_rgb := _rgb_base_logt(m, zams["logt"], z)
			var l1_rgb := _rgb_tip_logl(m, z)
			var t1_rgb := _rgb_tip_logt(m, z)
			log10_l = lerp(l0_rgb, l1_rgb, f)
			log10_t = lerp(t0_rgb, t1_rgb, f)

		StellarPhase.HB:
			phase_name = "HB"
			var hb_l := _hb_logl_bounds(m, z)
			var hb_t := _hb_logt_bounds(m, z)
			log10_l = lerp(float(hb_l["l0"]), float(hb_l["l1"]), f)
			log10_t = lerp(float(hb_t["t0"]), float(hb_t["t1"]), f)

		StellarPhase.AGB:
			phase_name = "AGB"
			var agb_l0 := _rgb_tip_logl(m, z)
			var agb_t0 := _rgb_tip_logt(m, z)
			var agb_l1 := _agb_tip_logl(m, z)
			var agb_t1 := _agb_tip_logt(m, z)
			log10_l = lerp(agb_l0, agb_l1, f)
			log10_t = lerp(agb_t0, agb_t1, f)

		StellarPhase.WD, StellarPhase.NS, StellarPhase.BH:
			return _remnant_properties(m, age_gyr, ms, post)

		_:
			return {}

	var l_lsun := pow(10.0, log10_l)
	var t_eff_k := pow(10.0, log10_t)
	var r_rsun := _radius_rsun_from_l_t(log10_l, log10_t)

	return {
		"mass_msun": m,
		"phase": phase,
		"phase_name": phase_name,
		"ms_lifetime_gyr": ms,
		"post_ms_duration_gyr": post,
		"m_remnant_msun": m_rem,
		"log10_l_lsun": log10_l,
		"log10_t_eff_k": log10_t,
		"l_lsun": l_lsun,
		"t_eff_k": t_eff_k,
		"r_rsun": r_rsun,
		"feh": z
	}

static func sample_star_mass_msun(galaxy_seed: int, star_index: int, gas_bias: float = 0.0) -> float:
	# [use] STAR_MASS hash purpose -> deterministic IMF sample
	var u := C.hash_float(galaxy_seed, C.HashPurpose.STAR_MASS, star_index)
	var expo: float = clamp(1.0 / (1.0 + 0.35 * gas_bias), 0.65, 1.45)
	u = clamp(pow(u, expo), 1e-12, 1.0 - 1e-12)

	if u < IMF_F_BREAK:
		# + 부호로 변경: = M_MIN^{-0.3} + (-0.3) * u/A1 = M_MIN^{-0.3} - 0.3 * u/A1  ← u가 커질수록 감소 → m 증가 ✓
		var inner_low := pow(IMF_M_MIN, 1.0 - IMF_ALPHA1) + (1.0 - IMF_ALPHA1) * (u / IMF_A1)
		return pow(max(inner_low, 1e-12), 1.0 / (1.0 - IMF_ALPHA1))

	#var u2: float = (u - IMF_F_BREAK) / max(1.0 - IMF_F_BREAK, 1e-12)
	var inner_hi = pow(IMF_M_BREAK, 1.0 - IMF_ALPHA2) + (1.0 - IMF_ALPHA2) * (u - IMF_F_BREAK) / IMF_A2
	return clamp(pow(max(inner_hi, 1e-12), 1.0 / (1.0 - IMF_ALPHA2)), IMF_M_BREAK, IMF_M_MAX)

static func build_star_population(
	galaxy_seed: int,
	n_star: int,
	age_gyr: float,
	feh: float,
	galaxy_type: int,
	m_gas_msun: float,
	halo_spin: float
) -> Dictionary:
	# [use] age_gyr -> phase selection
	# [use] feh -> stellar evolution shifts
	# [use] galaxy_type -> population bias
	# [use] m_gas_msun -> IMF sampling bias
	# [use] halo_spin -> disk-type dependent population bias
	if n_star <= 0:
		return {
			"masses_msun": PackedFloat32Array(),
			"phases": PackedInt32Array(),
			"log10_l_lsun": PackedFloat32Array(),
			"log10_t_eff_k": PackedFloat32Array(),
			"r_rsun": PackedFloat32Array(),
			"m_remnant_msun": PackedFloat32Array()
		}

	var type_factor := 1.0
	match galaxy_type:
		GalaxyData.GalaxyType.E:
			type_factor = 0.65
		GalaxyData.GalaxyType.S0:
			type_factor = 0.80
		GalaxyData.GalaxyType.Sa:
			type_factor = 0.95
		GalaxyData.GalaxyType.Sb:
			type_factor = 1.00
		GalaxyData.GalaxyType.Sc:
			type_factor = 1.10
		GalaxyData.GalaxyType.Irr:
			type_factor = 1.20
		_:
			type_factor = 1.0

	var gas_regime := C.logx(max(m_gas_msun, 1e-6) / 1.0e9)
	var spin_regime: float = clamp(halo_spin / 0.035, 0.6, 1.5)
	var gas_bias: float = clamp(gas_regime * type_factor * spin_regime, -0.6, 0.8)

	var masses := PackedFloat32Array()
	var phases := PackedInt32Array()
	var logls := PackedFloat32Array()
	var logts := PackedFloat32Array()
	var radii := PackedFloat32Array()
	var remnants := PackedFloat32Array()

	masses.resize(n_star)
	phases.resize(n_star)
	logls.resize(n_star)
	logts.resize(n_star)
	radii.resize(n_star)
	remnants.resize(n_star)

	for i in range(n_star):
		var m := sample_star_mass_msun(galaxy_seed, i, gas_bias)
		var props := stellar_properties(m, age_gyr, feh)

		masses[i] = m
		phases[i] = int(props["phase"])
		logls[i] = float(props["log10_l_lsun"])
		logts[i] = float(props["log10_t_eff_k"])
		radii[i] = float(props["r_rsun"])
		remnants[i] = float(props["m_remnant_msun"])

	return {
		"masses_msun": masses,
		"phases": phases,
		"log10_l_lsun": logls,
		"log10_t_eff_k": logts,
		"r_rsun": radii,
		"m_remnant_msun": remnants
	}
