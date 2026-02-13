# settings.gd
# 설정 화면. 인게임 오버레이 또는 메인메뉴에서 모두 호출 가능.

extends Control

func _ready() -> void:
	# 설정값 불러와서 UI에 반영
	_load_settings()

func _load_settings() -> void:
	# TODO: ConfigFile로 설정 불러오기
	pass

func _on_btn_back_pressed() -> void:
	# 인게임에서 열었으면 닫기, 메인메뉴에서 열었으면 메인메뉴로
	if GameManager.current_state == GameManager.GameState.INGAME:
		queue_free()
	else:
		GameManager.go_to_main_menu()

func _on_btn_apply_pressed() -> void:
	_save_settings()

func _save_settings() -> void:
	# TODO: ConfigFile로 설정 저장
	pass
