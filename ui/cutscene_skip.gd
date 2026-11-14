extends Node
# Esc during a cutscene (Escoria input mode SKIP) fast-forwards it instead of
# opening the pause menu, like SCUMM's cutscene override. The scripts still run
# every statement, only much faster and muted, so the game ends in exactly the
# same state as if the scene had played out. It stops on its own when the
# cutscene gives control back or when the room changes.

const SPEED := 20.0

var _room: Node


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	set_process(false)


## Called by the UI instead of opening the pause menu. Returns true if Esc was
## used to skip.
func try_skip() -> bool:
	if escoria.inputs_manager.input_mode != escoria.inputs_manager.INPUT_SKIP:
		return false
	if not is_processing():
		_room = escoria.main.current_scene
		Engine.time_scale = SPEED
		AudioServer.set_bus_mute(0, true)
		set_process(true)
	return true


func _process(_delta: float) -> void:
	if escoria.inputs_manager.input_mode != escoria.inputs_manager.INPUT_SKIP \
			or escoria.main.current_scene != _room:
		Engine.time_scale = 1.0
		AudioServer.set_bus_mute(0, false)
		set_process(false)
