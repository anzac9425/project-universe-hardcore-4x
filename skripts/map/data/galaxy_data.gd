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

var type: int = 3

var galaxy_seed: int

var mass: float
var f_baryon: float
var f_gas: float
var m_baryon: float
var m_gas: float
var m_star: float

var systems: Array[SystemData] =[]
