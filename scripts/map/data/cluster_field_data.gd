extends Resource
class_name ClusterFieldData
 
var ob_associations:   Array      = []   # OB 성협 · HII 영역 딕셔너리 배열
var globular_clusters: Array      = []   # 구상성단 딕셔너리 배열
var molecular_clouds:  Array      = []   # 분자운(GMC) 딕셔너리 배열
var turbulence_field:  Dictionary = {}   # Kolmogorov 난류 모드
 
var n_ob:      int   = 0
var n_gc:      int   = 0
var n_gmc:     int   = 0
var f_mol:     float = 0.0   # 분자 가스 분율 (면 평균)
var m_h2_msun: float = 0.0   # 분자 가스 총 질량 [Msun]
