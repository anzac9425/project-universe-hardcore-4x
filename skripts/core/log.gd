extends Node
class_name Log


const ERROR_MESSAGES = {
	ERR_CODE.SCENEMANAGER_NOT_INITED: "ERR_SCENEMANAGER_NOT_INITIALIZED",
	ERR_CODE.SCENE_NOT_EXISTS: "ERR_SCENE_NOT_EXISTS",
	ERR_CODE.SCENE_LOAD_FAILED: "ERR_SCENE_LOAD_FAILED",
	
	ERR_CODE.LOADING_TARGET_INVALID: "ERR_LOADING_TARGET_INVALID",
	ERR_CODE.LOADING_REQUEST_FAILED: "ERR_LOADING_REQUEST_FAILED",
	ERR_CODE.LOADING_THREAD_FAILED: "ERR_LOADING_THREAD_FAILED",
	ERR_CODE.LOADING_TIMEOUT: "ERR_LOADING_TIMEOUT",
	
	ERR_CODE.GAMESESSION_CONFIG_NULL: "ERR_GAMESESSION_CONFIG_NULL",
	ERR_CODE.GAMESESSION_SYSTEM_NULL: "ERR_GAMESESSION_SYSTEM_NULL"
}


static func _get_msg(code: int) -> String:
	return ERROR_MESSAGES.get(code, "알 수 없는 오류가 발생했습니다. (Code: %s)" % code)


static func info(msg: String):
	print("[INFO]: %s" % [msg])
	
	
static func warn(code: int, detail: String):
	var msg = _get_msg(code)
	var full_log = "[WARN]: %s: %s" % [msg, detail]
	push_error(full_log)
	print_rich("[color=yellow]%s[/color]" % [full_log])
	
	
static func error(code: int, detail: String):
	var msg = _get_msg(code)
	var full_log = "[ERROR]: %s: %s" % [msg, detail]
	push_error(full_log)
	print_rich("[color=red]%s[/color]" % [full_log])
