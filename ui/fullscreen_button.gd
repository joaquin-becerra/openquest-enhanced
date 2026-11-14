extends CanvasLayer
## Fullscreen button in the top right corner, always visible
## (over rooms, menus and transitions). It changes the same setting
## as the menu's "Screen" option, so both agree. On the web the
## browser only allows fullscreen from a click, and this is one.

const SIZE := 40.0
const MARGIN := 12.0
const COLOR := Color(0.886, 0.875, 0.863, 0.75)
const COLOR_HOVER := Color(1, 1, 1, 1)
const SHADOW := Color(0.094, 0.243, 0.408, 0.8)

var _button: Control
var _hover := false


func _ready() -> void:
	layer = 110
	process_mode = PROCESS_MODE_ALWAYS
	_button = Control.new()
	_button.size = Vector2(SIZE, SIZE)
	_button.position = Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width") - SIZE - MARGIN, MARGIN)
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.draw.connect(_draw_icon)
	_button.gui_input.connect(_on_gui_input)
	_button.mouse_entered.connect(_set_hover.bind(true))
	_button.mouse_exited.connect(_set_hover.bind(false))
	add_child(_button)
	get_window().size_changed.connect(_button.queue_redraw)


func _set_hover(on: bool) -> void:
	_hover = on
	_button.queue_redraw()


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_button.accept_event()
		ESCProjectSettingsManager.set_setting(ESCProjectSettingsManager.FULLSCREEN, not _is_fullscreen())
		escoria.settings_manager.apply_settings()
		escoria.settings_manager.save_settings()
		_button.queue_redraw()


## Four corners: pointing out to enter fullscreen, pointing in
## to leave it.
func _draw_icon() -> void:
	var color := COLOR_HOVER if _hover else COLOR
	var s := SIZE
	var l := s * 0.32       # length of each stroke
	var w := 5.0
	var inward := _is_fullscreen()
	for shadow in [true, false]:
		var off := Vector2(2, 2) if shadow else Vector2.ZERO
		var c: Color = SHADOW if shadow else color
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			var p: Vector2 = corner * s
			var dir := Vector2(1 - 2 * corner.x, 1 - 2 * corner.y)   # towards the center
			if inward:
				p += dir * l
				dir = -dir
			_button.draw_line(p + off, p + Vector2(dir.x * l, 0) + off, c, w)
			_button.draw_line(p + off, p + Vector2(0, dir.y * l) + off, c, w)
