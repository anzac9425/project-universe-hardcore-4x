# cell_defs.gd
# Blueprint 셀 데이터 구조 정의
# 셀 1개 = 4바이트 (PackedByteArray 상 offset * 4)
#
# [Byte 0] material_id  : 소재 종류 (0 = 빈 셀)
# [Byte 1] module_id    : 모듈 슬롯 ID (0 = 없음, 1 이상 = 모듈 있음 표시)
# [Byte 2] hp_ratio     : 설계 시 최대 내구도 비율 (0~255, 255 = 100%)
# [Byte 3] flags        : 비트 플래그 (아래 상수 참고)

class_name CellDefs

# ── 바이트 오프셋 ──────────────────────────────────────────
const BYTE_MATERIAL  := 0
const BYTE_MODULE_ID := 1
const BYTE_HP_RATIO  := 2
const BYTE_FLAGS     := 3
const BYTES_PER_CELL := 4

# ── 플래그 비트 ───────────────────────────────────────────
const FLAG_OCCUPIED  := 0b00000001  # 셀이 채워져 있음
const FLAG_EXTERIOR  := 0b00000010  # 외장 셀 (장갑 판정 우선)
const FLAG_CRITICAL  := 0b00000100  # 핵심 부위 (파괴 시 치명적)
const FLAG_SEALED    := 0b00001000  # 기밀 유지 셀

# ── 소재 ID 테이블 (추후 Resource로 분리 가능) ─────────────
const MATERIAL_EMPTY         := 0
const MATERIAL_STEEL         := 1
const MATERIAL_TITANIUM      := 2
const MATERIAL_COMPOSITE     := 3
const MATERIAL_NANOMESH      := 4   # 중반 연구
const MATERIAL_ANTIMATTER    := 5   # 후반 연구

# ── 셀 인덱스 계산 ─────────────────────────────────────────
static func cell_index(x: int, y: int, width: int) -> int:
	return (y * width + x) * BYTES_PER_CELL

# ── 셀 읽기 ───────────────────────────────────────────────
static func get_material(data: PackedByteArray, x: int, y: int, width: int) -> int:
	return data[cell_index(x, y, width) + BYTE_MATERIAL]

static func get_module_id(data: PackedByteArray, x: int, y: int, width: int) -> int:
	return data[cell_index(x, y, width) + BYTE_MODULE_ID]

static func get_hp_ratio(data: PackedByteArray, x: int, y: int, width: int) -> int:
	return data[cell_index(x, y, width) + BYTE_HP_RATIO]

static func get_flags(data: PackedByteArray, x: int, y: int, width: int) -> int:
	return data[cell_index(x, y, width) + BYTE_FLAGS]

static func has_flag(data: PackedByteArray, x: int, y: int, width: int, flag: int) -> bool:
	return (get_flags(data, x, y, width) & flag) != 0

static func is_occupied(data: PackedByteArray, x: int, y: int, width: int) -> bool:
	return has_flag(data, x, y, width, FLAG_OCCUPIED)

# ── 셀 쓰기 ───────────────────────────────────────────────
static func set_cell(data: PackedByteArray, x: int, y: int, width: int,
		material: int, module_id: int, hp_ratio: int, flags: int) -> void:
	var idx := cell_index(x, y, width)
	data[idx + BYTE_MATERIAL]  = material
	data[idx + BYTE_MODULE_ID] = module_id
	data[idx + BYTE_HP_RATIO]  = hp_ratio
	data[idx + BYTE_FLAGS]     = flags

static func clear_cell(data: PackedByteArray, x: int, y: int, width: int) -> void:
	set_cell(data, x, y, width, MATERIAL_EMPTY, 0, 0, 0)
