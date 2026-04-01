extends Node2D

@onready var progress_bar: ProgressBar = $ProgressBar


func _ready():
	await load_scene()


func load_scene():

	var path: String = SceneManager.target_scene_path

	if path.is_empty() or not ResourceLoader.exists(path):
		Log.error(ERR_CODE.LOADING_ERROR, path, "TARGET_INVALID")
		SceneManager.finish_loading(null)
		return

	var progress := []
	var request_result := ResourceLoader.load_threaded_request(path)

	if request_result != OK:
		Log.error(ERR_CODE.LOADING_ERROR, path, "REQUEST_FAILED")
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
			Log.error(ERR_CODE.LOADING_ERROR, path, "THREAD_FAILED")
			SceneManager.finish_loading(null)
			return

		frame_count += 1
		if frame_count > C.MAX_LOADING_FRAMES:
			Log.error(ERR_CODE.LOADING_ERROR, path, "TIMEOUT")
			SceneManager.finish_loading(null)
			return

		await get_tree().process_frame


	var packed: PackedScene = ResourceLoader.load_threaded_get(path)
	SceneManager.finish_loading(packed)
