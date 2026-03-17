extends Resource
class_name StarData

enum StarType { O, B, A, F, G, K, M }

var seed: int
var type: StarType
var temperature: float
var radius: float
var luminosity: float

var orbit_radius: float
var orbit_angle: float
var orbital_speed: float
