extends Node
class_name Log

static func info(msg: String):
	print("WARN: %s" % [msg])
	
static func warn(msg: String):
	print_rich("[color=yellow]WARN: %s[/color]" % [msg])
	
static func error(msg: String):
	print_rich("[color=red]ERROR: %s[/color]" % [msg])
