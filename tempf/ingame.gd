# ingame.gd
# 인게임 씬 루트.
# 매니저 초기화/종료를 GameManager에 위임하고,
# Renderer/UI 노드만 자식으로 가짐.
# 입력은 WorldManager와 UI에 위임.

extends Node

@onready var renderer:  Node2D      = $Renderer
@onready var ingame_ui: CanvasLayer = $InGameUI

func _ready() -> void:
	GameManager.initialize_managers()
	# Renderer 하위 Camera2D를 WorldManager에 등록
	# get_camera()는 Node2D에 없으므로 경로 직접 접근
	# Renderer.tscn 구성 시 Camera2D 노드 이름을 "Camera2D"로 통일
	var cam := renderer.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		push_error("Renderer/Camera2D 노드를 찾을 수 없음. Renderer.tscn에 Camera2D 노드가 있는지 확인")
		return
	GameManager.world_manager.register_camera(cam)

func _exit_tree() -> void:
	GameManager.shutdown_managers()

# ── 입력 ──────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	# 카메라 줌/이동은 항상 허용 (일시정지 중에도)
	GameManager.world_manager.handle_input(event)

	# ESC: 일시정지 + 포즈 메뉴 토글
	if event.is_action_pressed("ui_cancel"):
		if GameManager.is_paused():
			GameManager.release_pause()
			ingame_ui.hide_pause_menu()
		else:
			GameManager.request_pause()
			ingame_ui.show_pause_menu()
		get_viewport().set_input_as_handled()
		return

	# 속도 단축키는 포즈 메뉴가 닫혀있을 때만 동작
	if GameManager.is_paused():
		return

	# Space: 빠른 일시정지 토글 (메뉴 없이)
	if event.is_action_pressed("speed_pause"):
		GameManager.request_pause()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("speed_slow"):   GameManager.set_speed_slow()
	if event.is_action_pressed("speed_normal"): GameManager.set_speed_normal()
	if event.is_action_pressed("speed_fast"):   GameManager.set_speed_fast()
	if event.is_action_pressed("speed_vfast"):  GameManager.set_speed_very_fast()
