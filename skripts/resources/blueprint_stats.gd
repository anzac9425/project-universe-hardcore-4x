# blueprint_stats.gd
# Blueprint 설계 확정 시 자동 산출되는 스탯.
# 런타임 인스턴스는 이 값만 참조하면 되므로 Blueprint 전체를 들고 다닐 필요 없음.

class_name BlueprintStats
extends Resource

# ── 구조 스탯 ─────────────────────────────────────────────
@export var total_cells: int       = 0   # 전체 점유 셀 수
@export var area: int              = 0   # 외곽 포함 면적 (픽셀²)
@export var perimeter: int         = 0   # 외곽 둘레 (픽셀)
@export var total_mass: float      = 0.0 # 총 질량 (소재별 밀도 합산)
@export var center_of_mass: Vector2 = Vector2.ZERO

# ── 내구도 스탯 ───────────────────────────────────────────
@export var max_total_hp: int      = 0   # 전체 셀 내구도 합산
@export var critical_hp: int       = 0   # CRITICAL 플래그 셀 내구도 합산

# ── 건조 비용 (소재별 셀 수 집계) ─────────────────────────
# key: material_id (int), value: cell_count (int)
@export var material_cost: Dictionary = {}

# ── 건조 시간 (초) ────────────────────────────────────────
@export var build_time_sec: float  = 0.0

# ── 모듈 요약 ─────────────────────────────────────────────
# key: module_type (int), value: count (int)
@export var module_count: Dictionary = {}

# ── 산출 로직 ─────────────────────────────────────────────
func calculate(bp) -> void:
	_reset()

	var mass_sum := 0.0
	var cx_sum   := 0.0
	var cy_sum   := 0.0
	# 루프 내 cell_index() 중복 호출 제거 - 직접 오프셋 증가
	var w: int    = int(bp.width)
	var h: int    = int(bp.height)
	var stride: int = w * CellDefs.BYTES_PER_CELL

	for y in range(h):
		var row_base := y * stride
		for x in range(w):
			var base := row_base + x * CellDefs.BYTES_PER_CELL
			var flags := bp.cell_data[base + CellDefs.BYTE_FLAGS]

			if not (flags & CellDefs.FLAG_OCCUPIED):
				continue

			var mat  := bp.cell_data[base + CellDefs.BYTE_MATERIAL]
			var hp_r := bp.cell_data[base + CellDefs.BYTE_HP_RATIO]

			total_cells += 1
			material_cost[mat] = material_cost.get(mat, 0) + 1

			var cell_hp := _base_hp_for_material(mat) * hp_r / 255
			max_total_hp += int(cell_hp)
			if flags & CellDefs.FLAG_CRITICAL:
				critical_hp += int(cell_hp)

			var density := _density_for_material(mat)
			mass_sum += density
			cx_sum   += x * density
			cy_sum   += y * density

	total_mass = mass_sum
	if mass_sum > 0.0:
		center_of_mass = Vector2(cx_sum / mass_sum, cy_sum / mass_sum)

	perimeter      = _count_perimeter_cells(bp)
	area           = total_cells
	build_time_sec = total_cells * 0.5 + _material_build_weight(bp)

	for slot_id in bp.module_map:
		var mt: int = bp.module_map[slot_id].get("type", 0)
		module_count[mt] = module_count.get(mt, 0) + 1

# ── 내부 헬퍼 ─────────────────────────────────────────────
func _reset() -> void:
	total_cells    = 0
	area           = 0
	perimeter      = 0
	total_mass     = 0.0
	center_of_mass = Vector2.ZERO
	max_total_hp   = 0
	critical_hp    = 0
	material_cost.clear()
	build_time_sec = 0.0
	module_count.clear()

func _base_hp_for_material(mat: int) -> int:
	return MaterialData.get_hp(mat)

func _density_for_material(mat: int) -> float:
	return MaterialData.get_density(mat)

func _material_build_weight(_bp) -> float:
	var w := 0.0
	for mat in material_cost:
		var d := MaterialData.get_data(mat)
		w += material_cost[mat] * (d.build_weight if d else 1.0)
	return w

func _count_perimeter_cells(bp) -> int:
	# 점유 셀 중 상하좌우에 빈 셀이 하나라도 있는 셀 = 외장 셀
	# 핫패스 최적화: 임시 배열/메서드 호출 최소화
	var count := 0
	var w: int = int(bp.width)
	var h: int = int(bp.height)
	for y in range(h):
		for x in range(w):
			if not bp.is_occupied(x, y):
				continue
			if x == 0 or not bp.is_occupied(x - 1, y):
				count += 1
				continue
			if x == w - 1 or not bp.is_occupied(x + 1, y):
				count += 1
				continue
			if y == 0 or not bp.is_occupied(x, y - 1):
				count += 1
				continue
			if y == h - 1 or not bp.is_occupied(x, y + 1):
				count += 1
	return count
