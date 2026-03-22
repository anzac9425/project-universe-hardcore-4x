extends Resource
class_name OrbitData

var semi_major_axis_au: float = 0.0
var eccentricity: float = 0.0
var inclination_rad: float = 0.0
var argument_of_periapsis_rad: float = 0.0
var longitude_of_ascending_node_rad: float = 0.0
var mean_anomaly_at_epoch_rad: float = 0.0
var period_days: float = 0.0
var mean_motion_rad_per_day: float = 0.0
var phase_offset_rad: float = 0.0


func mean_anomaly_at_time(time_days: float) -> float:
	return wrapf(mean_anomaly_at_epoch_rad + mean_motion_rad_per_day * time_days, 0.0, TAU)


func true_anomaly_at_time(time_days: float) -> float:
	var mean_anomaly := mean_anomaly_at_time(time_days)
	var e := clamp(eccentricity, 0.0, 0.35)
	return wrapf(
		mean_anomaly
		+ (2.0 * e - 0.25 * pow(e, 3.0)) * sin(mean_anomaly)
		+ 1.25 * pow(e, 2.0) * sin(2.0 * mean_anomaly),
		0.0,
		TAU
	)


func radial_distance_au_at_time(time_days: float) -> float:
	var nu := true_anomaly_at_time(time_days)
	return semi_major_axis_au * (1.0 - eccentricity * eccentricity) / max(0.00001, 1.0 + eccentricity * cos(nu))
