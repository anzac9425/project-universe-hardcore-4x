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

var type: int

var galaxy_seed: int

var m_vir: float
var f_baryon: float
var f_gas: float
var f_bulge: float
var f_disk: float
var f_star_halo: float

var halo: HaloData
var disk_size: DiskSize
var disk_thickness: DiskThickness
var bulge_profile: BulgeProfile

var systems: Array[SystemData] =[]
