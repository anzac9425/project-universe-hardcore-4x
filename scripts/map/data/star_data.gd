extends Resource
class_name StarData

enum StarType{
	O,
	B,
	A,
	F,
	G,
	K,
	M
}

var star_seed: int
var mass_solar: float
var luminosity_solar: float
var temp: float
var radius_solar: float
var type: StarType
var habitable_zone_inner_au: float
var habitable_zone_outer_au: float
var snow_line_au: float
var hot_zone_au: float
