extends Control
## End credits: they scroll up from the bottom when ending.esc sets the global
## credits_start = 1 (the ship is gone). At the end "Thanks for playing" stays;
## a click quits the game (like the original ending).
##
## Each line: [style, text]. "title" = heading (translated), "name" =
## proper name (not translated), "gap" = space, "logo" = the game's logo.

const LINES := [
	["logo", ""],
	["gap", ""],
	["title", "CREDITS_GAME"],
	["name", "Michael Sheail"],
	["gap", ""],
	["title", "CREDITS_AGS"],
	["name", "Chris Jones"],
	["gap", ""],
	["title", "CREDITS_SCUMMC"],
	["name", "Jennifer McMurray"],
	["gap", ""],
	["title", "CREDITS_GODOT"],
	["name", "Joaquin A. Becerra"],
	["gap", ""],
]
const SPEED := 45.0          # px per second
const TOP := 0.0             # top edge of the credits area
const BOTTOM := 576.0        # shown over the room's background

const COLOR_TITLE := Color(0.749, 0.741, 0.376)
const COLOR_NAME := Color(0.886, 0.886, 0.886)
const COLOR_OUTLINE := Color(0.094, 0.243, 0.408)

var _started := false
var _finished := false

@onready var _roll: VBoxContainer = $roll
@onready var _thanks: Label = $thanks


func _ready() -> void:
	for line in LINES:
		_roll.add_child(_make(line[0], line[1]))
	_roll.position.y = BOTTOM
	_thanks.modulate.a = 0.0


func _make(style: String, text: String) -> Control:
	match style:
		"logo":
			var logo := TextureRect.new()
			logo.texture = load("res://rooms/title_screen/title_logo.png")
			logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			return logo
		"gap":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 40)
			return gap
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if style == "name":
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var font_path := "res://fonts/verb_chset.fnt" if style == "title" else "res://fonts/dialog_charset.fnt"
	label.add_theme_font_override("font", load(font_path))
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", COLOR_TITLE if style == "title" else COLOR_NAME)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", 8)
	# the bitmap font has no outline: the shadow makes it readable over the sky
	label.add_theme_color_override("font_shadow_color", COLOR_OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	return label


func _process(delta: float) -> void:
	if not _started:
		if escoria.globals_manager.get_global("credits_start") == 1:
			_started = true
		return
	if _finished:
		return
	_roll.position.y -= SPEED * delta
	if _roll.position.y + _roll.size.y < TOP:
		_finished = true
		create_tween().tween_property(_thanks, "modulate:a", 1.0, 1.5)


func _input(event: InputEvent) -> void:
	if not _started:
		return
	var click: bool = event is InputEventMouseButton and event.pressed
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	if not (click or key):
		return
	get_viewport().set_input_as_handled()
	if _finished:
		escoria.quit()
	else:
		# a click speeds up: jump to the end of the roll
		_roll.position.y = TOP - _roll.size.y
