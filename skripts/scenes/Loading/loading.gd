extends Node2D

@onready var progress_bar: ProgressBar = $ProgressBar


func _ready():
	await load_scene()


func load_scene():

	var path = SceneManager.target_scene_path
	var progress := []

	ResourceLoader.load_threaded_request(path)

	while true:

		var status = ResourceLoader.load_threaded_get_status(path, progress)

		if progress.size() > 0:
			SceneManager.loading_progress = progress[0]

			if progress_bar:
				progress_bar.value = progress[0] * 100

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break

		await get_tree().process_frame


	var packed: PackedScene = ResourceLoader.load_threaded_get(path)

	await get_tree().process_frame

	SceneManager.finish_loading(packed)
	
