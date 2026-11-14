extends Control
## OpenQuest's main and pause menu (replaces escoria-core's).
## Intro background (buildings), game logo and buttons with the verb
## box. No saving or loading.
##
## The same scene serves both menus: with is_pause "Continue" shows
## and the menu keeps working while the game is paused.
##
## While the menu is shown the intro music plays (on the music bus, so
## the music volume controls it); the room's music pauses and resumes where
## it was when the menu closes.

const MENU_MUSIC := "res://music/intro.ogg"

@export var is_pause := false

@onready var _main: Control = $main
@onready var _options: Control = $options

var _music: AudioStreamPlayer


func _ready() -> void:
	if is_pause:
		process_mode = Node.PROCESS_MODE_ALWAYS
	$main/buttons/continue.visible = is_pause
	_music = AudioStreamPlayer.new()
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_music.bus = "Music"
	var stream: AudioStream = load(MENU_MUSIC)
	stream.loop = true
	_music.stream = stream
	add_child(_music)
	visibility_changed.connect(_on_visibility_changed)
	hide()


func _on_visibility_changed() -> void:
	var room_music := _room_music()
	if visible:
		if room_music:
			room_music.stream_paused = true
		_music.play()
	else:
		_music.stop()
		if room_music:
			room_music.stream_paused = false


## Escoria's music player (null before the game starts).
func _room_music() -> AudioStreamPlayer:
	if escoria.object_manager == null:
		return null
	var music = escoria.object_manager.get_object(ESCObjectManager.MUSIC)
	return music.node.stream if music and music.node else null


func _on_continue_pressed() -> void:
	escoria.main.current_scene.game.unpause_game()


func _on_new_game_pressed() -> void:
	escoria.new_game()
	if is_pause:
		escoria.main.current_scene.game.unpause_game()


func _on_options_pressed() -> void:
	_main.hide()
	_options.open()


func _on_quit_pressed() -> void:
	escoria.quit()


func _on_options_back_button_pressed() -> void:
	reset()


## Back to the button list (game.gd calls it when opening the menu).
func reset() -> void:
	_options.hide()
	_main.show()


## game.gd calls it when pausing; this menu has no "Save game".
func set_save_enabled(_p_enabled: bool) -> void:
	pass
