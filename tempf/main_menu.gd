# main_menu.gd
# 타이틀 / 메인 메뉴 씬.
# 버튼 입력을 받아 GameManager에 씬 전환 요청만 함.

extends Control

func _ready() -> void:
	# 포커스 설정 등 초기화
	$VBox/BtnNewGame.grab_focus()

func _on_btn_new_game_pressed() -> void:
	GameManager.go_to_ingame()

func _on_btn_continue_pressed() -> void:
	# TODO: 세이브 파일 존재 여부 확인 후 로드
	GameManager.go_to_ingame("autosave")

func _on_btn_settings_pressed() -> void:
	GameManager.go_to_settings()

func _on_btn_quit_pressed() -> void:
	get_tree().quit()
