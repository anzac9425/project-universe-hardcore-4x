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

const M_GAL_MU: float = log(MILKYWAY_MASS) # MILKYWAY_MASS
const M_GAL_SIGMA: float = 0.8

static func get_Z(u1: float, u2: float) -> float: # 표준정규분포시드
		u1 = max(u1, 1e-9)
		return sqrt(-2.0 * log(u1)) * cos(2.0 * PI * u2)

const RD_MTP: float = 0.2
