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
const MILKYWAY_MASS: float = 1.15e12 * SOLAR_MASS
const SOLAR_MASS: float = 1.98847e30
const EARTH_MASS: float = 5.97219e24

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


static func classify_morphology( # minimalized, need change
	f_bulge: float,
	f_disk: float,
	f_gas_: float,
	f_star_halo_: float
) -> int:

	if f_bulge > 0.7 and f_gas_ < 0.1:
		return GalaxyData.GalaxyType.E

	if f_bulge > 0.5:
		return GalaxyData.GalaxyType.S0

	if f_disk > 0.6 and f_gas_ > 0.3:
		return GalaxyData.GalaxyType.Sc

	if f_disk > 0.5:
		return GalaxyData.GalaxyType.Sb

	if f_disk > 0.4:
		return GalaxyData.GalaxyType.Sa

	if f_star_halo_ > 0.1:
		return GalaxyData.GalaxyType.Irr

	return GalaxyData.GalaxyType.S0
