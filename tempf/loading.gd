# loading.gd
# 로딩 스크린. ResourceLoader로 InGame 씬을 백그라운드 로드하고
# 완료되면 GameManager에 알림.

extends Control

@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var label_status: Label       = $VBox/LabelStatus

var _load_path: String = GameManager.SCENE_INGAME

func _ready() -> void:
	label_status.text = "Loading..."
	progress_bar.value = 0.0
	# 백그라운드 로드 시작
	var err := ResourceLoader.load_threaded_request(_load_path)
	if err != OK:
		push_error("Failed to start loading: %s" % _load_path)
		# 실패 시 즉시 전환 시도
		GameManager.on_loading_complete()

func _process(_delta: float) -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_load_path, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = progress[0] * 100.0 if progress.size() > 0 else 0.0

		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			label_status.text  = "Done!"
			set_process(false)
			# 한 프레임 후 전환 (UI가 100% 표시될 시간 확보)
			await get_tree().process_frame
			GameManager.on_loading_complete()

		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Loading failed: %s" % _load_path)
			label_status.text = "Load failed. Returning to menu..."
			set_process(false)
			await get_tree().create_timer(2.0).timeout
			GameManager.go_to_main_menu()
