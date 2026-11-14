class_name LoadingSpinner
extends CanvasLayer
# Loading indicator: an arc spinning in the middle of the room area, over
# ScummScreen's transitions. It removes itself when the room changes.
# While Godot loads the new room the page freezes (loading is
# synchronous), so the arc stops at that moment, but stays visible.

const CENTER := Vector2(640, 288)
const RADIUS := 28.0
const WIDTH := 6.0
const COLOR := Color(0.886, 0.875, 0.863)
const SPEED := TAU  # turns per second * TAU

var _room: Node
var _angle := 0.0
var _arc: Control


static func start() -> void:
	if escoria.get_node_or_null("LoadingSpinner") != null:
		return
	var spinner := LoadingSpinner.new()
	spinner.name = "LoadingSpinner"
	escoria.add_child(spinner)


func _init() -> void:
	layer = 101
	process_mode = PROCESS_MODE_ALWAYS
	_arc = Control.new()
	_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arc.draw.connect(_draw_arc)
	add_child(_arc)


func _ready() -> void:
	_room = escoria.main.current_scene


func _process(delta: float) -> void:
	if escoria.main.current_scene != _room:
		queue_free()
		return
	_angle = fmod(_angle + SPEED * delta, TAU)
	_arc.queue_redraw()


func _draw_arc() -> void:
	_arc.draw_arc(CENTER, RADIUS, _angle, _angle + TAU * 0.75, 32, COLOR, WIDTH, true)
