# "Turn the phone" hint for the web: while the screen is in portrait, covers
# the game with a dark layer and a phone turning to landscape. Browsers that
# can't lock the orientation (iPhone, or before fullscreen) need it; it's
# drawn, not written, so it works in any language.
extends CanvasLayer

const Settings = preload("res://addons/escoria-mobile/settings.gd")

var FG: Color = Settings.get_value(Settings.STYLE_FOREGROUND)
var _view: Control


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_STOP  # the game below can't be played
	_view.draw.connect(_draw)
	add_child(_view)
	get_window().size_changed.connect(_update)
	_update()


func _update() -> void:
	var win := get_window().size
	visible = win.y > win.x
	_view.size = get_viewport().get_visible_rect().size
	_view.queue_redraw()


func _draw() -> void:
	var s := _view.size
	_view.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.92))
	var c := s / 2.0
	var u := minf(s.x, s.y) / 10.0
	# portrait phone (dim) -> landscape phone (bright), with an arrow
	_phone(c + Vector2(-u * 2.2, 0), Vector2(u * 1.6, u * 2.8), Color(FG, 0.45))
	_phone(c + Vector2(u * 2.2, 0), Vector2(u * 2.8, u * 1.6), FG)
	var a := c + Vector2(-u * 0.6, 0)
	var b := c + Vector2(u * 0.5, 0)
	_view.draw_line(a, b, FG, u * 0.18)
	_view.draw_colored_polygon(PackedVector2Array([
		b + Vector2(u * 0.45, 0), b + Vector2(-u * 0.1, -u * 0.4), b + Vector2(-u * 0.1, u * 0.4)]), FG)


func _phone(center: Vector2, size: Vector2, color: Color) -> void:
	var r := Rect2(center - size / 2.0, size)
	_view.draw_rect(r, color, false, maxf(2.0, size.x * 0.06))
	var dot := center + (Vector2(0, size.y * 0.38) if size.y > size.x else Vector2(size.x * 0.38, 0))
	_view.draw_circle(dot, minf(size.x, size.y) * 0.06, color)
