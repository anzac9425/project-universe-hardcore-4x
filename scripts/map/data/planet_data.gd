extends Resource
class_name PlanetData

enum PlanetType{
	ROCKY,
	OCEAN,
	ICE,
	GAS_GIANT,
	ICE_GIANT
}

var planet_seed: int
var type: PlanetType
var mass_earth: float
var radius_earth: float
var temp: float
var moons: Array[PlanetData] = []
