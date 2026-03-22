extends Resource
class_name StarData

enum StarType { O, B, A, F, G, K, M }

var star_seed: int = 0
var mass_solar: float = 0.0
var luminosity_solar: float = 0.0
var temperature_k: float = 0.0
var radius_solar: float = 0.0
var spectral_type: StarType = StarType.G
var habitable_zone_inner_au: float = 0.0
var habitable_zone_outer_au: float = 0.0
var snow_line_au: float = 0.0
var hot_zone_au: float = 0.0
