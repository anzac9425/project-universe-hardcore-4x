# ship_instance.gd
# 런타임에서 함선 하나를 표현하는 경량 데이터 구조.
# Blueprint는 Read-Only 참조만 하고, 변하는 데이터(내구도)만 독립적으로 보유.
# Node를 상속하지 않음 - RenderingServer/PhysicsServer에서 직접 관리.

class_name ShipInstance
extends RefCounted

# ── Blueprint 참조 (Read-Only) ────────────────────────────
var blueprint = null
var stats: Resource = null  # blueprint.cached_stats 단축 참조

# ── 런타임 상태 ───────────────────────────────────────────
# 셀별 현재 내구도. 크기 = width * height (셀당 1바이트, 0~255)
# 255 = 설계 최대치, 0 = 파괴
var hp_data: PackedByteArray = PackedByteArray()

# CRITICAL 셀 위치 캐시 - is_destroyed() 호출마다 전체 순회 방지
var _critical_cell_count: int = 0
var _alive_critical_count: int = 0

# 물리 상태
var position:         Vector2 = Vector2.ZERO
var velocity:         Vector2 = Vector2.ZERO
var rotation:         float   = 0.0
var angular_velocity: float   = 0.0

# 식별
var instance_id: int = 0
var faction_id:  int = 0

# RenderingServer 핸들
var canvas_item_rid: RID = RID()

# ── 생성 ──────────────────────────────────────────────────
static func create(bp, pos: Vector2, faction: int) -> ShipInstance:
	assert(bp.cached_stats != null, "Blueprint must be baked before instantiation")
	var inst          := ShipInstance.new()
	inst.blueprint    = bp
	inst.stats        = bp.cached_stats
	inst.position     = pos
	inst.faction_id   = faction
	inst.instance_id  = _next_id()
	inst._init_hp()
	return inst

func _init_hp() -> void:
	var w: int = int(blueprint.width)
	var h: int = int(blueprint.height)
	hp_data.resize(w * h)

	# 이중 루프 대신 직접 오프셋 계산으로 최적화
	var stride: int = w * CellDefs.BYTES_PER_CELL
	for y in range(h):
		var row_base := y * stride
		for x in range(w):
			var base  := row_base + x * CellDefs.BYTES_PER_CELL
			var hp_r  := blueprint.cell_data[base + CellDefs.BYTE_HP_RATIO]
			var flags := blueprint.cell_data[base + CellDefs.BYTE_FLAGS]
			hp_data[y * w + x] = hp_r

			if flags & CellDefs.FLAG_CRITICAL:
				_critical_cell_count += 1

	_alive_critical_count = _critical_cell_count

# ── HP 접근 ───────────────────────────────────────────────
func get_cell_hp(x: int, y: int) -> int:
	return hp_data[y * blueprint.width + x]

func set_cell_hp(x: int, y: int, value: int) -> void:
	hp_data[y * blueprint.width + x] = clampi(value, 0, 255)

func is_cell_alive(x: int, y: int) -> bool:
	return get_cell_hp(x, y) > 0

# ── 피격 처리 (단순 버전 - Compute Shader 전환 전 CPU fallback) ──
# hit_x, hit_y: 로컬 좌표 기준 피격 셀
# damage: 피해량 (0~255 스케일)
# penetration: 관통 깊이 (셀 단위)
# angle_deg: 입사각 (0 = 정면)
func apply_hit(hit_x: int, hit_y: int, damage: int, penetration: int, angle_deg: float) -> HitResult:
	var result := HitResult.new()

	# 도탄 판정: 입사각이 70도 이상이면 도탄
	if abs(angle_deg) > 70.0:
		result.ricocheted = true
		return result

	# 관통 경로를 따라 셀 파괴
	var dir           := _penetration_direction(angle_deg)
	var remaining_dmg := damage
	var cx            := hit_x
	var cy            := hit_y
	var bw            := blueprint.width
	var bh            := blueprint.height
	var bp_data       := blueprint.cell_data  # 로컬 참조로 반복 접근 최적화

	for _i in range(penetration):
		if cx < 0 or cx >= bw or cy < 0 or cy >= bh:
			break

		var base  := (cy * bw + cx) * CellDefs.BYTES_PER_CELL
		var flags := bp_data[base + CellDefs.BYTE_FLAGS]

		if not (flags & CellDefs.FLAG_OCCUPIED):
			cx += dir.x
			cy += dir.y
			continue

		var mat        := bp_data[base + CellDefs.BYTE_MATERIAL]
		var resist     := _material_resistance(mat)
		var actual_dmg := maxi(1, remaining_dmg - resist)

		var hp_idx     := cy * bw + cx
		var current_hp := hp_data[hp_idx]
		var new_hp     := maxi(0, current_hp - actual_dmg)
		hp_data[hp_idx] = new_hp

		result.hit_cells.append(Vector2i(cx, cy))
		remaining_dmg -= resist

		if new_hp == 0:
			result.destroyed_cells.append(Vector2i(cx, cy))
			# 캐시된 CRITICAL 카운터 갱신 (추가 순회 없음)
			if flags & CellDefs.FLAG_CRITICAL:
				result.critical_hit   = true
				_alive_critical_count = maxi(0, _alive_critical_count - 1)

		if remaining_dmg <= 0:
			break

		cx += dir.x
		cy += dir.y

	# 반동 적용 (화약 병기)
	result.recoil_impulse = Vector2(-dir.x, -dir.y) * damage * 0.01

	return result

func _penetration_direction(angle_deg: float) -> Vector2i:
	# 입사각 → 관통 방향 벡터
	# 8방향으로 양자화하여 셀 단위 이동에 맞춤
	var rad := deg_to_rad(angle_deg)
	var fx  := cos(rad)
	var fy  := sin(rad)
	# 절댓값이 더 큰 축을 주 방향으로, 나머지는 부호만 유지
	if absf(fx) >= absf(fy):
		return Vector2i(1 if fx >= 0.0 else -1, 0 if absf(fy) < 0.4 else (1 if fy >= 0.0 else -1))
	else:
		return Vector2i(0 if absf(fx) < 0.4 else (1 if fx >= 0.0 else -1), 1 if fy >= 0.0 else -1)

func _material_resistance(mat: int) -> int:
	return MaterialData.get_resistance(mat)

# ── 물리 업데이트 (PhysicsServer 전환 전 간이 버전) ──────
func integrate(delta: float) -> void:
	position += velocity * delta
	rotation += angular_velocity * delta

func apply_impulse(impulse: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
	if stats.total_mass <= 0.0:
		return
	velocity += impulse / stats.total_mass
	if offset != Vector2.ZERO:
		angular_velocity += offset.cross(impulse) / (stats.total_mass * 10.0)

# ── 생존 여부 (캐시 기반 - O(1)) ─────────────────────────
func is_destroyed() -> bool:
	if _critical_cell_count == 0:
		return false  # CRITICAL 셀이 없으면 파괴 불가
	return _alive_critical_count <= 0

# ── ID 생성기 ─────────────────────────────────────────────
static var _id_counter: int = 0
static func _next_id() -> int:
	_id_counter += 1
	return _id_counter


# ── HitResult 내부 클래스 ─────────────────────────────────
class HitResult:
	var ricocheted:      bool          = false
	var critical_hit:    bool          = false
	var hit_cells:       Array[Vector2i] = []
	var destroyed_cells: Array[Vector2i] = []
	var recoil_impulse:  Vector2       = Vector2.ZERO
