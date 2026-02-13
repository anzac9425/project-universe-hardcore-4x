# faction_manager.gd
# 세력 관계, 외교 상태 관리.

class_name FactionManager
extends RefCounted

const FACTION_PLAYER  := 0
const FACTION_NEUTRAL := 1
const FACTION_HOSTILE := 2

# key: "min_max" 형식, value: 관계 수치 (-100 적대 ~ 100 동맹)
var _relations: Dictionary = {}

signal relation_changed(faction_a: int, faction_b: int, value: int)

func initialize() -> void:
	_relations.clear()

func _key(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]

func get_relation(a: int, b: int) -> int:
	return _relations.get(_key(a, b), 0)

func set_relation(a: int, b: int, value: int) -> void:
	var clamped := clampi(value, -100, 100)
	_relations[_key(a, b)] = clamped
	relation_changed.emit(a, b, clamped)

func is_hostile(a: int, b: int) -> bool:
	return get_relation(a, b) < -50

func is_allied(a: int, b: int) -> bool:
	return get_relation(a, b) > 50
