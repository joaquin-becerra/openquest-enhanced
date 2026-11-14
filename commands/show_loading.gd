class_name ShowLoadingCommand
extends ESCBaseCommand
# `show_loading()`: shows the loading indicator (ui/loading_spinner.gd) until
# the room changes.


func configure() -> ESCCommandArgumentDescriptor:
	return ESCCommandArgumentDescriptor.new(0, [], [])


func run(_command_params: Array) -> int:
	LoadingSpinner.start()
	return ESCExecution.RC_OK


func interrupt():
	pass
