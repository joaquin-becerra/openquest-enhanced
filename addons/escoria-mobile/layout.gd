# Screen layout for phones and tablets: makes the room fill the screen
# instead of letterboxing the whole design (room + bottom panel).
#
# The design is e.g. 1280x800: a 1280x576 room on top and a 224 px panel
# (verbs, inventory) below. On a touch device the content scale switches to
# "expand" with the room as the base size, so Godot widens or heightens the
# view to the screen's shape. Then, by the space left under the room:
#
#   DOCKED  the whole panel fits under the room (tablets): stays as designed.
#   DRAWER  it doesn't (phones): the panel becomes a drawer. Closed, it sits
#           under the room (partly visible on 16:9, hidden on 20:9); open, it
#           slides up over the bottom of the room. It opens on the 1st tap on
#           an item or with the tab button, and closes after an action or a
#           walk (mobile_input.gd calls open()/close()).
#   FULL    something visible needs the full design size (a menu: buttons
#           both in and below the room), so the original letterboxed design
#           comes back while it's shown.
#
# In DRAWER mode, a group of buttons living only below the room (the dialog
# chooser's lines) slides up over the bottom of the room too, on a
# semi-transparent backdrop, and slides back when it's gone.
#
# Configured in Project Settings (escoria/mobile/layout/...): the room height
# and the panel's node path inside the game scene (escoria.game_scene).
extends Node

const Settings = preload("res://addons/escoria-mobile/settings.gd")

enum Mode { NONE, FULL, DOCKED, DRAWER }

const SLIDE_TIME := 0.18
const CHECK_EVERY := 0.2  # seconds between "does something need FULL?" scans

signal opened_changed(open: bool)

var mode := Mode.NONE
var is_open := false

var _design := Vector2.ZERO        # original content scale size
var _design_aspect: Window.ContentScaleAspect
var _room_h := 0.0
var _panel_path := ""
var _panel: Control = null
var _panel_home_y := 0.0           # panel's designed y (normally = room height)
var _tab_layer: CanvasLayer
var _tab: Control
var _tween: Tween
var _check_timer := 0.0
var _check_now := 0                # frames left that scan right away
var _cam: Camera2D = null          # camera whose bottom limit we lowered
var _scan := {"full": false, "groups": []}
var _shifted := {}                 # button group (Control) -> its designed y
var _last_scan_sig := ""
var _backdrops := {}               # button group -> its ColorRect
# look (escoria/mobile/style/* and layout/tab_*)
var _tab_size := Vector2(88, 44)
var _tab_right := true
var _tab_icon: Texture2D
var _bg: Color
var _fg: Color
var _border := 2.0
var _backdrop_color: Color


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var win := get_window()
	_design = Vector2(win.content_scale_size)
	if _design == Vector2.ZERO:
		_design = Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	_design_aspect = win.content_scale_aspect
	_room_h = float(Settings.get_value(Settings.LAYOUT_ROOM_HEIGHT))
	_panel_path = str(Settings.get_value(Settings.LAYOUT_PANEL))
	_tab_size = Settings.get_value(Settings.LAYOUT_TAB_SIZE)
	_tab_right = int(Settings.get_value(Settings.LAYOUT_TAB_SIDE)) == 0
	_tab_icon = Settings.get_icon(Settings.LAYOUT_TAB_ICON)
	_bg = Settings.get_value(Settings.STYLE_BACKGROUND)
	_fg = Settings.get_value(Settings.STYLE_FOREGROUND)
	_border = float(Settings.get_value(Settings.STYLE_BORDER))
	_backdrop_color = Settings.get_value(Settings.STYLE_BACKDROP)
	win.size_changed.connect(_relayout)
	# Menus open on input (Esc, the gear, a click) or come as new nodes: scan
	# at once then, after everything else this frame (late process), so the
	# first frame of a menu is already drawn in FULL, not cut by the room
	# scale. The periodic scan catches the rest.
	process_priority = 1000
	get_tree().node_added.connect(func(_n): _check_soon())
	_make_tab()


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion and not event is InputEventScreenDrag:
		_check_soon()


func _check_soon() -> void:
	_check_now = 3  # this frame and a couple more (things shown deferred)


func _process(delta: float) -> void:
	if _tween and _tween.is_running():
		_update_tab()
	_fix_camera_limit()
	_check_timer -= delta
	if _check_now > 0:
		_check_now -= 1
	elif _check_timer > 0.0:
		return
	_check_timer = CHECK_EVERY
	if _panel == null or not is_instance_valid(_panel):
		_panel = _find_panel()
		if _panel:
			_panel_home_y = _panel.position.y
	_relayout()


## Opens the drawer (DRAWER mode only).
func open() -> void:
	if mode == Mode.DRAWER and not is_open:
		is_open = true
		_place_panel(true)
		opened_changed.emit(true)


## Closes the drawer; instantly if not animate (e.g. right before clicking
## the room under it).
func close(animate := true) -> void:
	if mode == Mode.DRAWER and is_open:
		is_open = false
		_place_panel(animate)
		opened_changed.emit(false)


## True if vp (viewport coords) is on the open drawer, so a tap there must
## not reach the room hidden under it.
func covers(vp: Vector2) -> bool:
	return mode == Mode.DRAWER and is_open and _panel_visible() \
			and _panel.get_global_rect().has_point(vp)


# --- mode -----------------------------------------------------------------

func _relayout() -> void:
	_scan = _scan_buttons()
	var want := _wanted_mode()
	if want != mode:
		mode = want
		if is_open:
			is_open = false
			opened_changed.emit(false)
		_apply_scale()
		get_parent()._say("layout: %s" % Mode.keys()[mode])
	if not (_tween and _tween.is_running()):
		_place_panel(false)
	_update_groups()
	_update_tab()


func _wanted_mode() -> int:
	if _room_h <= 0.0 or _panel == null:
		return Mode.NONE
	if _scan.full:
		return Mode.FULL
	var view := _room_view_size()
	return Mode.DOCKED if view.y - _room_h >= _panel.size.y else Mode.DRAWER


## View size with the room as the base size and "expand" aspect.
func _room_view_size() -> Vector2:
	var screen := Vector2(get_window().size)
	var room := Vector2(_design.x, _room_h)
	if screen.y <= 0.0:
		return room
	var aspect := screen.x / screen.y
	if aspect >= room.x / room.y:
		return Vector2(room.y * aspect, room.y)
	return Vector2(room.x, room.x / aspect)


func _apply_scale() -> void:
	var win := get_window()
	match mode:
		Mode.DOCKED, Mode.DRAWER:
			win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
			win.content_scale_size = Vector2i(int(_design.x), int(_room_h))
		_:
			win.content_scale_aspect = _design_aspect
			win.content_scale_size = Vector2i(_design)


## Visible buttons (outside the panel) that reach below the room, grouped by
## parent. A group with buttons also inside the room (a menu) needs FULL; a
## group only below it (dialog chooser lines) can slide up instead.
## Positions are taken as designed, undoing any shift we applied.
func _scan_buttons() -> Dictionary:
	var buttons: Array = []
	_collect_buttons(get_tree().root, buttons)
	var below := {}
	for b: BaseButton in buttons:
		if _design_rect(b).end.y > _room_h + 1.0:
			below[b.get_parent()] = true
	var full := false
	for g in below:
		for c in g.get_children():
			if c is BaseButton and c.is_visible_in_tree() \
					and _design_rect(c).position.y < _room_h - 1.0:
				full = true
	var sig := "%d buttons, %d below, full %s" % [buttons.size(), below.size(), full]
	if sig != _last_scan_sig:
		_last_scan_sig = sig
		get_parent()._trace("scan: " + sig)
	return {"full": full, "groups": below.keys()}


## Every visible button in the tree. Hidden CanvasItems aren't pruned: what
## hangs from a CanvasLayer under them still shows (is_visible_in_tree() of
## each button knows), so the whole tree is walked.
func _collect_buttons(node: Node, out: Array) -> void:
	if node == _panel or node == _tab_layer or node == self:
		return
	if node is CanvasLayer and not node.visible:
		return
	if node is Window and node != get_tree().root:
		return  # popups have their own coordinates; they never need FULL
	if node is BaseButton and node.is_visible_in_tree():
		out.append(node)
	for child in node.get_children():
		_collect_buttons(child, out)


func _design_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var g := c.get_parent()
	if _shifted.has(g) and is_instance_valid(g):
		r.position.y -= g.position.y - _shifted[g]
	return r


# --- button groups below the room (dialog chooser) ------------------------

## In DRAWER mode, slide the groups up by (view height - design height) over a
## backdrop; put back the ones that are gone or when not in DRAWER mode.
func _update_groups() -> void:
	var want: Array = _scan.groups if mode == Mode.DRAWER else []
	for g in _shifted.keys():
		if not is_instance_valid(g):
			_drop_group(g)
		elif not want.has(g):
			g.position.y = _shifted[g]
			_drop_group(g)
	var delta := get_viewport().get_visible_rect().size.y - _design.y
	for g in want:
		if _shifted.has(g) or not (g is Control) or delta >= 0.0:
			continue
		_shifted[g] = g.position.y
		var bd := ColorRect.new()
		bd.color = _backdrop_color
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var parent: Node = g.get_parent()
		parent.add_child(bd)
		parent.move_child(bd, g.get_index())  # just behind the buttons
		# the band under the room, full view width, in the parent's coords
		var view_w := get_viewport().get_visible_rect().size.x
		var top_left := Vector2(0, _room_h)
		var bottom_right := Vector2(view_w, _design.y)
		if parent is CanvasItem:
			var inv: Transform2D = parent.get_global_transform().affine_inverse()
			top_left = inv * top_left
			bottom_right = inv * bottom_right
		bd.position = top_left
		bd.size = bottom_right - top_left
		_backdrops[g] = bd
		var tw := create_tween().set_parallel()
		tw.tween_property(g, "position:y", _shifted[g] + delta, SLIDE_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(bd, "position:y", top_left.y + delta, SLIDE_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		close()


func _drop_group(g) -> void:
	var bd = _backdrops.get(g)
	if bd and is_instance_valid(bd):
		bd.queue_free()
	_backdrops.erase(g)
	_shifted.erase(g)


# --- camera ----------------------------------------------------------------

## Escoria stretches every room's camera limits to at least the design height
## (esc_room.gd set_camera_limits), so a 576 px room gets an 800 px limit and,
## with a 576 px view, the camera would scroll down into the panel's black
## area. While the room fills the screen, lower that limit to the view (never
## under the room height); put it back for the full design. Checked every
## frame because Escoria sets the limits again on every room change.
func _fix_camera_limit() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != _cam and _cam != null and is_instance_valid(_cam):
		_restore_camera()
	if cam == null:
		_cam = null
		return
	var design_bottom := cam.limit_top + int(_design.y)
	var fill := mode == Mode.DOCKED or mode == Mode.DRAWER
	if fill:
		var bottom := cam.limit_top + int(maxf(_room_h, get_viewport().get_visible_rect().size.y))
		if cam.limit_bottom == design_bottom and bottom < design_bottom:
			cam.limit_bottom = bottom
			_cam = cam
	elif cam == _cam:
		_restore_camera()


func _restore_camera() -> void:
	if _cam and is_instance_valid(_cam):
		_cam.limit_bottom = _cam.limit_top + int(_design.y)
	_cam = null


# --- panel / drawer -----------------------------------------------------

func _find_panel() -> Control:
	var esc := get_node_or_null("/root/escoria")
	if esc == null or _panel_path.is_empty():
		return null
	var game = esc.get("game_scene")
	if game == null or not is_instance_valid(game) or not game.is_inside_tree():
		return null
	return game.get_node_or_null(_panel_path) as Control


func _panel_visible() -> bool:
	return _panel != null and is_instance_valid(_panel) and _panel.is_visible_in_tree()


func _panel_target_y() -> float:
	if mode != Mode.DRAWER:
		return _panel_home_y
	var view_h := get_viewport().get_visible_rect().size.y
	return view_h - _panel.size.y if is_open else _room_h


func _place_panel(animate: bool) -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var y := _panel_target_y()
	if is_equal_approx(_panel.position.y, y) and not (_tween and _tween.is_running()):
		return
	if _tween:
		_tween.kill()
	if animate:
		_tween = create_tween()
		_tween.tween_property(_panel, "position:y", y, SLIDE_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_callback(_update_tab)
	else:
		_panel.position.y = y


# --- tab button (opens / closes the drawer) -------------------------------

func _make_tab() -> void:
	_tab_layer = CanvasLayer.new()
	_tab_layer.layer = 105
	add_child(_tab_layer)
	_tab = Control.new()
	_tab.size = _tab_size
	_tab.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab.draw.connect(_draw_tab)
	_tab.gui_input.connect(_on_tab_input)
	_tab_layer.add_child(_tab)
	_tab.hide()


func _update_tab() -> void:
	var show := mode == Mode.DRAWER and _panel_visible()
	_tab.visible = show
	if not show:
		return
	var view := get_viewport().get_visible_rect().size
	var top := minf(_panel.position.y, view.y)
	var x := view.x - _tab_size.x - 12.0 if _tab_right else 12.0
	_tab.position = Vector2(x, top - _tab_size.y)
	_tab.queue_redraw()


func _on_tab_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_tab.accept_event()
		if is_open:
			close()
		else:
			open()


## The drawer tab is on the right side of the screen (else on the left).
func tab_on_right() -> bool:
	return _tab_right


func _draw_tab() -> void:
	var s := _tab_size
	var slant := minf(8.0, s.x / 4.0)
	var bg := PackedVector2Array([
		Vector2(slant, 0), Vector2(s.x - slant, 0), Vector2(s.x, s.y), Vector2(0, s.y)])
	_tab.draw_colored_polygon(bg, _bg)
	if _border > 0.0:
		_tab.draw_polyline(bg + PackedVector2Array([bg[0]]), Color(_fg, _fg.a * 0.9), _border)
	# up to open, down to close
	if _tab_icon:
		var side := minf(s.x, s.y) * 0.7
		var k := side / maxf(_tab_icon.get_width(), _tab_icon.get_height())
		var size := _tab_icon.get_size() * k
		if is_open:  # flipped vertically
			_tab.draw_set_transform(Vector2(0, s.y), 0.0, Vector2(1, -1))
		_tab.draw_texture_rect(_tab_icon, Rect2((s - size) / 2.0, size), false)
		_tab.draw_set_transform(Vector2.ZERO)
		return
	var u := s.y / 44.0  # the chevron is made for 44 px
	var c := Vector2(s.x / 2.0, s.y / 2.0 + 2 * u)
	var d := -1.0 if not is_open else 1.0
	_tab.draw_polyline(PackedVector2Array([
		c + Vector2(-14, -d * 7) * u, c + Vector2(0, d * 7) * u, c + Vector2(14, -d * 7) * u]),
		_fg, 5.0 * u)
