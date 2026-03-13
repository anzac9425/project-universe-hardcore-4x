extends Node2D

@onready var progress_bar: ProgressBar = $ProgressBar

const MAX_LOADING_FRAMES := 1800


func _ready():
	await load_scene()


func load_scene():

	var path: String = SceneManager.target_scene_path

	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("ERR_LOADING_TARGET_INVALID: %s" % path)
		SceneManager.finish_loading(null)
		return

	var progress := []
	var request_result := ResourceLoader.load_threaded_request(path)

	if request_result != OK:
		push_error("ERR_LOADING_REQUEST_FAILED: %s" % path)
		SceneManager.finish_loading(null)
		return

	var frame_count := 0

	while true:

		var status = ResourceLoader.load_threaded_get_status(path, progress)

		if progress.size() > 0:
			SceneManager.loading_progress = progress[0]

			if progress_bar:
				progress_bar.value = progress[0] * 100

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break

		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("ERR_LOADING_THREAD_FAILED: %s" % path)
			SceneManager.finish_loading(null)
			return

		frame_count += 1
		if frame_count > MAX_LOADING_FRAMES:
			push_error("ERR_LOADING_TIMEOUT: %s" % path)
			SceneManager.finish_loading(null)
			return

		await get_tree().process_frame


	var packed: PackedScene = ResourceLoader.load_threaded_get(path)
	SceneManager.finish_loading(packed)
	
