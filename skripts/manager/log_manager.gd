extends Node

var logs : Array = []


func print_log(msg: String) -> void:
	var time := Time.get_ticks_usec() / 1_000_000.0
	var formatted := "[%.3fs] %s" % [time, msg]
	logs.append(formatted)
	print(formatted)
