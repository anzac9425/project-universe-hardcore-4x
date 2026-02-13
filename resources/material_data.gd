# material_data.gd
# 소재 하나의 속성 정의 Resource.
# 코드에 하드코딩하지 않고 .tres 파일로 관리하여
# 추후 연구 시스템, 밸런스 조정, 모드 지원이 용이해짐.

class_name MaterialData
extends Resource

@export var material_id:   int    = 0
@export var display_name:  String = "Unknown"
@export var color:         Color  = Color.MAGENTA   # 에디터 미리보기 색상

# ── 물리 속성 ─────────────────────────────────────────────
@export var density:       float  = 1.0   # 질량 계산에 사용
@export var base_hp:       int    = 100   # 셀 기준 내구도
@export var resistance:    int    = 10    # 관통 피해 감소량
@export var build_weight:  float  = 1.0   # 건조 시간 가중치

# ── 해금 조건 ─────────────────────────────────────────────
@export var research_required: String = ""  # 연구 ID, 빈 문자열 = 기본 해금


# ── 전역 레지스트리 (런타임에 등록하여 ID로 조회) ─────────
static var _registry: Dictionary = {}  # key: material_id, value: MaterialData

static func register(mat: MaterialData) -> void:
	_registry[mat.material_id] = mat

static func get_data(material_id: int) -> MaterialData:
	return _registry.get(material_id, null)

static func get_hp(material_id: int) -> int:
	var d := get_data(material_id)
	return d.base_hp if d else 50

static func get_resistance(material_id: int) -> int:
	var d := get_data(material_id)
	return d.resistance if d else 5

static func get_density(material_id: int) -> float:
	var d := get_data(material_id)
	return d.density if d else 0.2

static func get_color(material_id: int) -> Color:
	var d := get_data(material_id)
	return d.color if d else Color.MAGENTA


# ── 기본 소재 프리셋 생성 (게임 시작 시 한 번 호출) ────────
static func register_defaults() -> void:
	var defaults: Array[Dictionary] = [
		{ "id": 0, "name": "Empty",       "color": Color(0.05,0.05,0.08), "density": 0.0,  "hp": 0,   "res": 0,  "bw": 0.0  },
		{ "id": 1, "name": "Steel",       "color": Color(0.55,0.60,0.65), "density": 1.0,  "hp": 100, "res": 10, "bw": 1.0  },
		{ "id": 2, "name": "Titanium",    "color": Color(0.75,0.80,0.85), "density": 0.7,  "hp": 160, "res": 18, "bw": 1.5  },
		{ "id": 3, "name": "Composite",   "color": Color(0.30,0.70,0.50), "density": 0.5,  "hp": 220, "res": 25, "bw": 2.0  },
		{ "id": 4, "name": "Nanomesh",    "color": Color(0.20,0.80,0.90), "density": 0.3,  "hp": 350, "res": 40, "bw": 3.5, "research": "nano_materials" },
		{ "id": 5, "name": "Antimatter",  "color": Color(0.90,0.20,0.80), "density": 0.1,  "hp": 500, "res": 60, "bw": 6.0, "research": "antimatter_containment" },
	]
	for d in defaults:
		var mat               := MaterialData.new()
		mat.material_id        = d["id"]
		mat.display_name       = d["name"]
		mat.color              = d["color"]
		mat.density            = d["density"]
		mat.base_hp            = d["hp"]
		mat.resistance         = d["res"]
		mat.build_weight       = d["bw"]
		mat.research_required  = d.get("research", "")
		register(mat)
