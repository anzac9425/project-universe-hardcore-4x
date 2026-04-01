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
var accretion_disk: AccretionDiskData
var spiral_structure: SpiralStructureData

var sfr_msun_per_yr: float
var log10_sfr_msun_per_yr: float
var log10_sfr_sfms_msun_per_yr: float
var log10_sfr_quench_correction: float

var z_center_12_log_oh: float
var z_gradient_dex_per_kpc: float
var z_scatter_dex: float

var systems: Array[SystemData] =[]
