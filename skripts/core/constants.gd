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


const M_GAL_MU: float = log(MILKYWAY_MASS) / log(10.0)
const M_GAL_SIGMA: float = 0.8


const RD_MTP: float = 0.2


static func logx(x: float, base: float = 10.0) -> float:
	return log(x) / log(base)
	

static func log_msun(mass): # Log Normalization M/MSUN
	return C.logx(mass/SOLAR_MASS) 
	

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
	BARYON
}


static func get_Z(u1: float, u2: float) -> float: # 표준정규분포시드
		u1 = max(u1, 1e-9)
		return sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)		


static func f_baryon_zero(mass: float) -> float:
	const M_0: float = 12.0 # ~12
	const SIGMA_B: float = 1.0 # ~1.0-1.5
	const F_COSMIC: float = 0.157 # ~~0.157
	
	var diff = log_msun(mass) - M_0
	var exponent = -(diff * diff) / (2.0 * SIGMA_B * SIGMA_B)
	return F_COSMIC * exp(exponent)


static func f_baryon(mass: float, galaxy_seed) -> float:
	const SIGMA_B_SC: float = 0.2
	
	var u1 = hash_float(galaxy_seed, HashPurpose.BARYON, 0)
	var u2 = hash_float(galaxy_seed, HashPurpose.BARYON, 1)
	var Z_b = get_Z(u1, u2)
	return f_baryon_zero(mass) * pow(10.0, SIGMA_B_SC * Z_b)
	

static func mu_gas(mass) -> float:
	const a: float = -1.0
	const m_1: float = 11.0

	return a * (log_msun(mass) - m_1)
	
