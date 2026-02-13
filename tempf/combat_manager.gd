# combat_manager.gd
# 피격 이벤트 수집 및 처리.
# 현재는 CPU fallback 직접 호출. 추후 Compute Shader 배치 처리로 교체.

class_name CombatManager
extends RefCounted

func initialize() -> void:
	pass

func update(_sim_delta: float) -> void:
	pass  # 추후 Shader 디스패치/결과 수집 처리

func submit_hit(
	target_id: int,
	hit_x: int, hit_y: int,
	damage: int, penetration: int,
	angle_deg: float
) -> Variant:  # ShipInstance.HitResult 또는 null
	var inst := GameManager.simulation_manager.get_instance(target_id)
	if inst == null:
		return null
	return inst.apply_hit(hit_x, hit_y, damage, penetration, angle_deg)
