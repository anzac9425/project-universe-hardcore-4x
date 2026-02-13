# simulation_manager.gd
# 모든 ShipInstance를 소유하고 물리를 업데이트.
# RefCounted 상속 - GameManager._process()에서 update() 호출.

class_name SimulationManager
extends RefCounted

# ── 인스턴스 저장소 ───────────────────────────────────────
# key: instance_id (int), value: ShipInstance
var _instances: Dictionary = {}

# ── 시그널 ────────────────────────────────────────────────
signal instance_added(inst: ShipInstance)
signal instance_removed(instance_id: int)
signal instance_destroyed(inst: ShipInstance)

# ── 초기화 ────────────────────────────────────────────────
func initialize() -> void:
	_instances.clear()

# ── GameManager._process()에서 호출 ───────────────────────
func update(sim_delta: float) -> void:
	# 순회 중 삭제를 안전하게 처리하기 위해 별도 배열에 수집
	var to_destroy: Array[int] = []
	for inst in _instances.values():
		inst.integrate(sim_delta)
		if inst.is_destroyed():
			to_destroy.append(inst.instance_id)

	for id in to_destroy:
		var inst: ShipInstance = _instances[id]
		instance_destroyed.emit(inst)
		_instances.erase(id)
		instance_removed.emit(id)

# ── 인스턴스 추가/제거 ────────────────────────────────────
func add_instance(bp: Blueprint, pos: Vector2, faction: int) -> ShipInstance:
	var inst := ShipInstance.create(bp, pos, faction)
	_instances[inst.instance_id] = inst
	instance_added.emit(inst)
	return inst

func remove_instance(instance_id: int) -> void:
	if not _instances.has(instance_id):
		return
	_instances.erase(instance_id)
	instance_removed.emit(instance_id)

func get_instance(instance_id: int) -> ShipInstance:
	return _instances.get(instance_id, null)

func get_all_instances() -> Array:
	return _instances.values()

# ── Floating Origin 이동 ──────────────────────────────────
func shift_origin(offset: Vector2) -> void:
	for inst in _instances.values():
		inst.position += offset

# ── 팩션별 조회 ───────────────────────────────────────────
func get_instances_by_faction(faction_id: int) -> Array:
	return _instances.values().filter(
		func(inst: ShipInstance) -> bool: return inst.faction_id == faction_id
	)

# ── 범위 내 인스턴스 조회 (렌더링 컬링용) ─────────────────
func get_instances_in_rect(rect: Rect2) -> Array:
	return _instances.values().filter(
		func(inst: ShipInstance) -> bool: return rect.has_point(inst.position)
	)
