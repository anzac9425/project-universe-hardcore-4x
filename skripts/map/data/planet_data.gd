extends Resource
class_name PlanetData

enum PlanetType {
	ROCKY,
	OCEAN,
	DESERT,
	GAS_GIANT,
	ICE,
	LAVA
}

var planet_seed: int
var type: PlanetType
var orbit_radius: float
var orbit_angle: float
var size: float
