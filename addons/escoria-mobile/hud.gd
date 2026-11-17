# Touch HUD: two buttons in a corner of the room.
#
#   gear   opens the pause menu (settings, save, load...): sends "ui_cancel",
#          the same as the Esc key, so it works with any Escoria UI.
#   star   shows every interactive item of the room for a few seconds (a
#          circle and, if escoria/mobile/hud_hint_names, its name); tapping it
#          again hides them.
#
# The buttons only show while the game accepts room input (Escoria's DEFAULT
# state) and, with the phone layout, while the game's panel is visible (not
# in menus, cutscenes or the title screen).
#
# Position, size, colors and icons: Project Settings escoria/mobile/hud_buttons/*
# and escoria/mobile/style/* (see settings.gd). The gear sits in the corner,
# the star next to it toward the middle of the screen.
extends CanvasLayer

const Settings = preload("res://addons/escoria-mobile/settings.gd")

enum Corner { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }

var _gear: Control
var _star: Control
var _marks: Control
var _highlight_left := 0.0
var _names := true

# from the settings
var _corner := Corner.TOP_LEFT
var _size := 64.0
var _margin := 12.0
var _seconds := 3.0
var _bg: Color
var _fg: Color
var _accent: Color
var _border := 2.0
var _mark_fill: Color
var _mark_ring: Color
var _mark_radius := 18.0
var _gear_icon: Texture2D
var _star_icon: Texture2D


func _ready() -> void:
	layer = 105
	process_mode = Node.PROCESS_MODE_ALWAYS
	_names = bool(Settings.get_value(Settings.HUD_HINT_NAMES))
	_corner = int(Settings.get_value(Settings.HUD_CORNER))
	_size = float(Settings.get_value(Settings.HUD_BUTTON_SIZE))
	_margin = float(Settings.get_value(Settings.HUD_MARGIN))
	_seconds = float(Settings.get_value(Settings.HUD_HIGHLIGHT_SECONDS))
	_bg = Settings.get_value(Settings.STYLE_BACKGROUND)
	_fg = Settings.get_value(Settings.STYLE_FOREGROUND)
	_accent = Settings.get_value(Settings.STYLE_ACCENT)
	_border = float(Settings.get_value(Settings.STYLE_BORDER))
	_mark_fill = Settings.get_value(Settings.STYLE_MARK_FILL)
	_mark_ring = Settings.get_value(Settings.STYLE_MARK_RING)
	_mark_radius = float(Settings.get_value(Settings.STYLE_MARK_RADIUS))
	_gear_icon = Settings.get_icon(Settings.HUD_GEAR_ICON)
	_star_icon = Settings.get_icon(Settings.HUD_STAR_ICON)

	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	_gear = _make_button(_draw_gear, _on_gear)
	_star = _make_button(_draw_star, _on_star)
	get_viewport().size_changed.connect(_place)
	_place()


## The buttons' corner of the visible view (it changes with the layout).
func _place() -> void:
	var view := get_viewport().get_visible_rect().size
	var right := _corner == Corner.TOP_RIGHT or _corner == Corner.BOTTOM_RIGHT
	var bottom := _corner == Corner.BOTTOM_LEFT or _corner == Corner.BOTTOM_RIGHT
	var y := _margin
	if bottom:
		# above the game's panel and the drawer tab, when they're on screen
		var edge := view.y
		var layout: Node = get_parent()._layout
		if layout and layout._panel != null and is_instance_valid(layout._panel) \
				and layout._panel_visible():
			edge = minf(edge, layout._panel.position.y)
			if layout._tab.visible and layout.tab_on_right() == right:
				edge -= layout._tab.size.y
		y = edge - _margin - _size
	var step := _size + _margin
	var x := view.x - _margin - _size if right else _margin
	_gear.position = Vector2(x, y)
	_star.position = Vector2(x - step if right else x + step, y)


func _process(delta: float) -> void:
	var show := _room_input()
	_gear.visible = show
	_star.visible = show
	if show:
		_place()  # cheap; the view's size changes with the phone layout
	if _highlight_left > 0.0:
		_highlight_left = maxf(0.0, _highlight_left - delta) if show else 0.0
		_marks.size = get_viewport().get_visible_rect().size
		_marks.queue_redraw()  # items and camera may move
		if _highlight_left == 0.0:
			_star.queue_redraw()


func _room_input() -> bool:
	var esc := get_node_or_null("/root/escoria")
	if esc == null or esc.current_state != esc.GameState.DEFAULT:
		return false
	var layout: Node = get_parent()._layout
	if layout and layout._panel != null and is_instance_valid(layout._panel):
		return layout._panel_visible()
	return true


# --- buttons ----------------------------------------------------------------

func _make_button(drawer: Callable, action: Callable) -> Control:
	var b := Control.new()
	b.size = Vector2(_size, _size)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.draw.connect(func():
		var r := Rect2(Vector2.ZERO, b.size)
		b.draw_rect(r, _bg)
		if _border > 0.0:
			b.draw_rect(r, _fg, false, _border)
		drawer.call(b))
	b.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			b.accept_event()
			action.call())
	add_child(b)
	return b


func _on_gear() -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	ev.device = get_parent().SYNTH_DEVICE
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _on_star() -> void:
	_highlight_left = 0.0 if _highlight_left > 0.0 else _seconds
	_marks.queue_redraw()
	_star.queue_redraw()


## An icon centered in the button, 70% of its size, keeping its shape.
func _draw_icon(b: Control, icon: Texture2D, tint: Color) -> void:
	var side := b.size.x * 0.7
	var s := icon.get_size()
	var k := side / maxf(s.x, s.y)
	var draw_size := s * k
	b.draw_texture_rect(icon, Rect2((b.size - draw_size) / 2.0, draw_size), false, tint)


func _draw_gear(b: Control) -> void:
	if _gear_icon:
		_draw_icon(b, _gear_icon, Color.WHITE)
		return
	var u := b.size.x / 64.0  # the drawing is made for 64 px
	var c := b.size / 2.0
	for i in 8:
		var a := TAU * i / 8.0
		var dir := Vector2(cos(a), sin(a))
		b.draw_line(c + dir * 14.0 * u, c + dir * 22.0 * u, _fg, 8.0 * u)
	b.draw_circle(c, 15.0 * u, _fg)
	b.draw_circle(c, 7.0 * u, Color(_bg, 1.0))


func _draw_star(b: Control) -> void:
	var on := _highlight_left > 0.0
	if _star_icon:
		_draw_icon(b, _star_icon, _accent if on else Color.WHITE)
		return
	var u := b.size.x / 64.0
	var c := b.size / 2.0
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 - PI / 2.0
		var r := (22.0 if i % 2 == 0 else 7.0) * u
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	b.draw_colored_polygon(pts, _accent if on else _fg)


# --- highlighted items --------------------------------------------------------

func _draw_marks() -> void:
	if _highlight_left <= 0.0:
		return
	var esc := get_node_or_null("/root/escoria")
	if esc == null:
		return
	var player = esc.main.current_scene.get("player") if esc.main and esc.main.current_scene else null
	var to_screen: Transform2D = get_viewport().get_canvas_transform()
	var font := ThemeDB.fallback_font
	var alpha := clampf(_highlight_left / 0.4, 0.0, 1.0)  # fade out at the end
	for item in get_tree().get_nodes_in_group(esc.GROUP_ITEM_CAN_COLLIDE):
		if not (item is ESCItem) or item.is_trigger or item == player \
				or not item.is_visible_in_tree() or str(item.tooltip_name).is_empty() \
				or not esc.action_manager.is_object_actionable(item.global_id):
			continue
		var area := _item_rect(item)
		if area.size == Vector2.ZERO:
			continue
		var p: Vector2 = to_screen * area.get_center()
		_marks.draw_circle(p, _mark_radius, Color(_mark_fill, _mark_fill.a * alpha))
		_marks.draw_arc(p, _mark_radius, 0.0, TAU, 48, Color(_mark_ring, _mark_ring.a * alpha), 3.0, true)
		if not _names:
			continue
		var text := tr(item.tooltip_name)
		var size := 26
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := p + Vector2(-w / 2.0, -_mark_radius - 8.0)
		_marks.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6,
				Color(0, 0, 0, alpha))
		_marks.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
				Color(1, 1, 1, alpha))


## The item's collision area in world coordinates (bounding rect).
func _item_rect(item: Node2D) -> Rect2:
	var rect := Rect2()
	var first := true
	for child in item.get_children():
		var pts := PackedVector2Array()
		if child is CollisionPolygon2D:
			for v in child.polygon:
				pts.append(child.global_transform * v)
		elif child is CollisionShape2D and child.shape:
			var r: Rect2 = child.shape.get_rect()
			for v in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y)]:
				pts.append(child.global_transform * v)
		for v in pts:
			if first:
				rect = Rect2(v, Vector2.ZERO)
				first = false
			else:
				rect = rect.expand(v)
	return rect
