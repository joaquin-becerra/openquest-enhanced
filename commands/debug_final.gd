class_name DebugFinalCommand
extends ESCBaseCommand
# Test shortcut: `debug_final()` queues the gun's `:give "commander_zif"`
# event (the end of the game). queue_event can't pick events with a
# target, hence this command. Used from secret_room.esc with
# debug_saltar_al_final = 1 (start_game.esc).


func configure() -> ESCCommandArgumentDescriptor:
	return ESCCommandArgumentDescriptor.new(0, [], [])


func run(_command_params: Array) -> int:
	var script: ESCScript = escoria.esc_compiler.load_esc_file("res://items/inventory/inv_gun.esc")
	escoria.event_manager.queue_event(script.get_event_with_target("give", "commander_zif"))
	return ESCExecution.RC_OK


func interrupt():
	pass
