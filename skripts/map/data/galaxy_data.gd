extends Resource
class_name GalaxyData

enum GalaxyType {
	spiral,
	barred_spiral,
	elliptical,
	irregular
}

var galaxy_seed: int
var mass: float
var systems: Array[SystemData] =[]
