# research_manager.gd
# 연구 테크트리 및 진행 상태 관리.

class_name ResearchManager
extends RefCounted

var unlocked_research: Array[String] = []

signal research_unlocked(research_id: String)

func initialize() -> void:
	unlocked_research = [
		"chemical_thruster",
		"monolithic_armor",
		"autocannon",
		"active_radar",
	]

func is_unlocked(research_id: String) -> bool:
	return research_id in unlocked_research

func unlock(research_id: String) -> void:
	if is_unlocked(research_id):
		return
	unlocked_research.append(research_id)
	research_unlocked.emit(research_id)
