extends Node
class_name Log


const ERROR_MESSAGES = {
	ERR_CODE.SCENE_ERROR: "ERR_SCENE",
	
	ERR_CODE.LOADING_ERROR: "ERR_LOADING",
	
	ERR_CODE.GAMESESSION_ERROR: "ERR_GAMESESSION",
	
	ERR_CODE.SOLVE_C_FROM_RATIO_INVALID_TARGET_RATIO: "ERR_SOLVE_C_FROM_RATIO_INVALID_TARGET_RATIO",
	ERR_CODE.HALO_STATE_FROM_MVIR_FAILED_TO_BRACKET_ROOT: "ERR_HALO_STATE_FROM_MVIR_FAILED_TO_BRACKET_ROOT",
	ERR_CODE.LOG_MSUN_MASS_NEGATIVE: "ERR_LOG_MSUN_MASS_MUST_BE_POSITIVE",
	
	ERR_CODE.MAP_GENERATION_FAILED: "ERR_MAP_GENERATION_FAILED"
}


static func _get_msg(code: int) -> String:
	return ERROR_MESSAGES.get(code, "Unknown Error. (Code: %s)" % code)

static func _get_error_key(code: int, suffix: String = "") -> String:
	var base_key := _get_msg(code)
	if suffix.is_empty():
		return "%s[%s]" % [base_key, code]
	return "%s[%s:%s]" % [base_key, code, suffix]


static func info(msg: String):
	print("[INFO]: %s" % [msg])
	
	
static func warn(code: int, detail: String, suffix: String = ""):
	var msg = _get_error_key(code, suffix)
	var full_log = "[WARN]: %s: %s" % [msg, detail]
	push_error(full_log)
	print_rich("[color=yellow]%s[/color]" % [full_log])
	
	
static func error(code: int, detail: String, suffix: String = ""):
	var msg = _get_error_key(code, suffix)
	var full_log = "[ERROR]: %s: %s" % [msg, detail]
	push_error(full_log)
	print_rich("[color=red]%s[/color]" % [full_log])
