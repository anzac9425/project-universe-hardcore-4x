extends Resource
class_name MoonData

enum MoonType {
	ROCKY,
	OCEAN,
	ICE,
	MAJOR
}

var moon_seed: int = 0
var name: String = ""
var type: MoonType = MoonType.ROCKY
var mass_earth: float = 0.0
var radius_earth: float = 0.0
var temperature_k: float = 0.0
var composition: String = ""
var orbit: OrbitData
