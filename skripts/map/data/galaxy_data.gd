extends Resource
class_name GalaxyData

enum GalaxyType {
	E,
	S0,
	Sa,
	Sb,
	Sc,
	Irr
}

var galaxy_seed: int
var mass: float
var systems: Array[SystemData] =[]
