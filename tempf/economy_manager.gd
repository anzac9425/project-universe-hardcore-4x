# economy_manager.gd
# 자원, 보급, 건조 큐 관리.

class_name EconomyManager
extends RefCounted

var resources: Dictionary = {}

signal resource_changed(id: String, amount: float)

func initialize() -> void:
	resources = {
		"metal":  1000.0,
		"fuel":   500.0,
		"energy": 200.0,
	}

func get_resource(id: String) -> float:
	return resources.get(id, 0.0)

func add_resource(id: String, amount: float) -> void:
	resources[id] = resources.get(id, 0.0) + amount
	resource_changed.emit(id, resources[id])

func consume_resource(id: String, amount: float) -> bool:
	var current := get_resource(id)
	if current < amount:
		return false
	resources[id] = current - amount
	resource_changed.emit(id, resources[id])
	return true

func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if get_resource(id) < cost[id]:
			return false
	return true
