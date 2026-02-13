# blueprint.gd
# 함선 / 거점 / 정거장 공용 Blueprint Resource
# 구조체 종류는 없음 - 부착된 모듈의 조합이 역할을 결정함.
# 설계 단계에서만 사용되며, 런타임 인스턴스는 이 Resource를 Read-Only로 참조함.

class_name Blueprint
extends Resource

const BlueprintStatsScript = preload("res://skripts/resources/blueprint_stats.gd")

# ── 기본 메타데이터 ────────────────────────────────────────
@export var blueprint_name: String = "Unnamed"
@export var width: int = 64
@export var height: int = 64

# ── 핵심 셀 데이터 ────────────────────────────────────────
# 크기 = width * height * CellDefs.BYTES_PER_CELL
@export var cell_data: PackedByteArray = PackedByteArray()

# ── 모듈 배치 정보 ────────────────────────────────────────
# key: module_slot_id (int, 1 이상 자동 증가 - 재사용 없음)
# value: { "type": int, "x": int, "y": int, "w": int, "h": int, "parts": Array }
@export var module_map: Dictionary = {}

# 모듈 슬롯 ID 자동 증가 카운터
var _next_slot_id: int = 1

# ── 자동 산출 스탯 (설계 확정 시 캐싱) ────────────────────
@export var cached_stats: Resource = null

# ── 초기화 ────────────────────────────────────────────────
func init_empty(w: int, h: int) -> void:
	width  = w
	height = h
	cell_data.resize(w * h * CellDefs.BYTES_PER_CELL)
	cell_data.fill(0)
	module_map.clear()
	cached_stats = null

# ── 셀 접근 래퍼 ──────────────────────────────────────────
func get_material(x: int, y: int) -> int:
	return CellDefs.get_material(cell_data, x, y, width)

func get_module_id(x: int, y: int) -> int:
	return CellDefs.get_module_id(cell_data, x, y, width)

func is_occupied(x: int, y: int) -> bool:
	return CellDefs.is_occupied(cell_data, x, y, width)

func set_cell(x: int, y: int, material: int, module_id: int, hp_ratio: int, flags: int) -> void:
	CellDefs.set_cell(cell_data, x, y, width, material, module_id, hp_ratio, flags)

func clear_cell(x: int, y: int) -> void:
	CellDefs.clear_cell(cell_data, x, y, width)

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

# ── 모듈 등록 ─────────────────────────────────────────────
# slot_id를 자동 발급하고 반환함
func register_module(type: int, x: int, y: int, w: int, h: int, parts: Array) -> int:
	var slot_id := _next_slot_id
	_next_slot_id += 1
	module_map[slot_id] = {
		"type":  type,
		"x":     x,
		"y":     y,
		"w":     w,
		"h":     h,
		"parts": parts,
	}
	# 해당 영역 셀에 module_id 기록
	# slot_id가 255를 넘으면 셀 바이트에 저장 불가 → 셀에는 포화값 255로 기록하고
	# 실제 조회는 module_map 기준으로 함 (셀의 module_id는 "모듈 있음" 표시용)
	var cell_mid := mini(slot_id, 255)
	for dy in range(h):
		for dx in range(w):
			var cx := x + dx
			var cy := y + dy
			if in_bounds(cx, cy) and is_occupied(cx, cy):
				var idx := CellDefs.cell_index(cx, cy, width) + CellDefs.BYTE_MODULE_ID
				cell_data[idx] = cell_mid
	return slot_id

func remove_module(slot_id: int) -> void:
	if not module_map.has(slot_id):
		return
	var m: Dictionary = module_map[slot_id]
	for dy in range(m["h"]):
		for dx in range(m["w"]):
			var cx: int = m["x"] + dx
			var cy: int = m["y"] + dy
			if in_bounds(cx, cy):
				var idx := CellDefs.cell_index(cx, cy, width) + CellDefs.BYTE_MODULE_ID
				cell_data[idx] = 0
	module_map.erase(slot_id)

# ── 스탯 산출 (설계 확정 시 호출) ─────────────────────────
func bake_stats() -> Resource:
	cached_stats = BlueprintStatsScript.new()
	cached_stats.calculate(self)
	return cached_stats

# ── 직렬화 (저장/불러오기) ────────────────────────────────
func serialize() -> Dictionary:
	return {
		"version":       1,
		"name":          blueprint_name,
		"width":         width,
		"height":        height,
		"cell_data_b64": Marshalls.raw_to_base64(cell_data),
		"module_map":    module_map,
		"next_slot_id":  _next_slot_id,
	}

static func deserialize(data: Dictionary):
	var bp := Blueprint.new()
	bp.blueprint_name = data.get("name", "Unnamed")
	bp.width          = data.get("width", 64)
	bp.height         = data.get("height", 64)
	bp.cell_data      = Marshalls.base64_to_raw(data.get("cell_data_b64", ""))
	bp.module_map     = data.get("module_map", {})
	bp._next_slot_id  = data.get("next_slot_id", 1)
	return bp
