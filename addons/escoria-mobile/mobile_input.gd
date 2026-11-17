# EscoriaMobile autoload: turns touch gestures into the mouse events that
# Escoria and its UIs already understand, so no UI has to change.
#
#   tap on a button / GUI       -> left click right away
#   1st tap on an item          -> mouse motion only (hover: name / verb shown)
#   2nd tap on the same item    -> left click (action)
#   tap on the floor            -> left click (walk)
#   double tap on the floor     -> double click (run)
#   long press                  -> right click
#   drag                        -> cursor follows the finger (motion only)
#
# Hover: Godot's physics picking is turned off while active (on desktop it
# polls the real OS pointer every frame, so hovering without touching would
# still work). Instead, each synthetic motion calls the same ESCItem handlers
# picking would (_on_input_event / _on_mouse_exited).
#
# Positions received in _input are in viewport coordinates; synthetic events
# go through Input.parse_input_event, which expects window coordinates (and
# updates Input's mouse position, which get_global_mouse_position() reads on
# touch devices).
extends Node

const Settings = preload("res://addons/escoria-mobile/settings.gd")

## Device id stamped on our synthetic mouse events, so we don't eat them.
const SYNTH_DEVICE := 0x4D42

var active := false
var _auto := false   # "Auto" mode: may still switch on at the first touch

var _simulate := false
var _log := false
var _two_tap := true
var _double_tap_ms := 300
var _long_press_ms := 500
var _slop_mm := 3.0
var _min_target_mm := 9.0
var _overlay: Label = null
var _overlay_lines: PackedStringArray = []

# current touch
var _finger := -1                   # index of the finger we follow (-1 none)
var _pressed := false
var _down_vp := Vector2.ZERO        # viewport coords
var _down_win := Vector2.ZERO       # window coords
var _down_ms := 0
var _moved := false
var _long_fired := false

# memory between taps
var _armed_item: Node = null        # item hovered by a 1st tap
var _last_floor_ms := -100000
var _last_floor_win := Vector2.ZERO
var _hovered: Array = []            # ESCItems under the cursor right now

# phone layout (layout.gd), and "object, then verb": a 1st tap on an item
# opens the drawer; choosing a verb there acts on that item.
var _layout: Node = null
var _verb_item: Node = null         # item waiting for a verb from the drawer
var _verb_vp := Vector2.ZERO        # where it was tapped
var _gui_tap := false               # a GUI tap is being processed

var _web := false
var _fullscreen_done := false       # asked once, at the first touch


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Desktop-only debug aid. Browsers send their own mouse events after
	# each touch, which would then count twice.
	_simulate = bool(Settings.get_value(Settings.SIMULATE_WITH_MOUSE)) \
			and not OS.has_feature("web")
	_log = bool(Settings.get_value(Settings.LOG))
	_two_tap = bool(Settings.get_value(Settings.TWO_TAP_ACTION))
	_double_tap_ms = int(Settings.get_value(Settings.DOUBLE_TAP_MS))
	_long_press_ms = int(Settings.get_value(Settings.LONG_PRESS_MS))
	_slop_mm = float(Settings.get_value(Settings.TAP_SLOP_MM))
	_min_target_mm = float(Settings.get_value(Settings.MIN_TARGET_MM))
	if bool(Settings.get_value(Settings.OVERLAY)):
		_make_overlay()
	match int(Settings.get_value(Settings.ENABLED)):
		0:
			_auto = true
			if DisplayServer.is_touchscreen_available() or _simulate:
				_activate()
		1: _activate()
	if not active:
		_say("inactive%s" % (" (until the first touch)" if _auto else ""))
	_web = OS.has_feature("web")
	if _web and bool(Settings.get_value(Settings.WEB_LANDSCAPE)):
		# whenever the page enters fullscreen (ours or the game's own
		# button), lock landscape where the browser allows it (Android)
		JavaScriptBridge.eval("""
			document.addEventListener('fullscreenchange', function () {
				if (document.fullscreenElement && screen.orientation && screen.orientation.lock)
					screen.orientation.lock('landscape').catch(function () {});
			});""", true)


func _activate() -> void:
	active = true
	# We synthesize the mouse events ourselves.
	Input.emulate_mouse_from_touch = false
	# We drive the hover ourselves (see header).
	get_viewport().physics_object_picking = false
	if int(Settings.get_value(Settings.LAYOUT_ROOM_HEIGHT)) > 0:
		_layout = preload("res://addons/escoria-mobile/layout.gd").new()
		add_child(_layout)
		_layout.opened_changed.connect(_on_drawer_changed)
	if bool(Settings.get_value(Settings.HUD)):
		add_child(preload("res://addons/escoria-mobile/hud.gd").new())
	if OS.has_feature("web") and bool(Settings.get_value(Settings.WEB_LANDSCAPE)):
		add_child(preload("res://addons/escoria-mobile/rotate_hint.gd").new())
	_connect_action_manager.call_deferred()
	_say("active%s, %d dpi" % [
		" (simulating touch with the mouse)" if _simulate else "",
		DisplayServer.screen_get_dpi()])


func _input(event: InputEvent) -> void:
	if _web and not _fullscreen_done and event is InputEventScreenTouch \
			and not event.pressed:
		_first_touch_fullscreen()
	if not active:
		# Some browsers don't report a touch screen (e.g. desktop Firefox
		# with touch simulation): switch on when the first real touch ends.
		# That touch already went through as Godot's emulated mouse click
		# (press and release, so no button is left stuck down).
		if _auto and event is InputEventScreenTouch and not event.pressed:
			_activate()
		return
	if event.device == SYNTH_DEVICE:
		# By now Input knows the new pointer position, so the ESCItem
		# handlers (which read get_global_mouse_position) see the right spot.
		if event is InputEventMouseMotion:
			_update_hover(event)
		return

	if event is InputEventScreenTouch:
		# Follow the first finger down, whatever its index (browsers don't
		# always number touches from 0); other fingers are ignored.
		_handled()
		if event.pressed and _finger == -1:
			_finger = event.index
			_touch_down(event.position)
		elif not event.pressed and event.index == _finger:
			_finger = -1
			_touch_up(event.position)
	elif event is InputEventScreenDrag:
		_handled()
		if event.index == _finger:
			_touch_drag(event.position)
	elif _simulate and event is InputEventMouse:
		# The real mouse plays the finger: only the left button exists,
		# and the pointer can't hover without touching.
		_handled()
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_touch_down(event.position)
			else:
				_touch_up(event.position)
		elif event is InputEventMouseMotion and _pressed:
			_touch_drag(event.position)


func _process(delta: float) -> void:
	if active:
		# Touches on an open popup (an OptionButton's list...) go to the
		# popup's own window, never through our _input: let Godot turn
		# them into mouse events itself while one is open.
		var popup_open := false
		for w: Window in get_viewport().get_embedded_subwindows():
			if w.visible:
				popup_open = true
				break
		if Input.emulate_mouse_from_touch != popup_open:
			Input.emulate_mouse_from_touch = popup_open
			_trace("popup %s" % ("open: Godot's touch->mouse on" if popup_open else "closed"))
	# A stalled frame (scene loading, shader compile) must not turn a quick
	# tap into a long press: the release is still queued behind the stall.
	if _pressed and delta > 0.1:
		_down_ms += int(delta * 1000.0)
	if _pressed and not _moved and not _long_fired \
			and Time.get_ticks_msec() - _down_ms >= _long_press_ms:
		_long_fired = true
		_trace("long press -> right click")
		_armed_item = null
		_close_drawer()
		_click(_down_vp, MOUSE_BUTTON_RIGHT)


# --- gestures -----------------------------------------------------------

func _touch_down(vp: Vector2) -> void:
	_pressed = true
	_moved = false
	_long_fired = false
	_down_vp = vp
	_down_win = _to_window(vp)
	_down_ms = Time.get_ticks_msec()
	_motion(vp)  # the cursor jumps under the finger: hover


func _touch_drag(vp: Vector2) -> void:
	if not _pressed:
		return
	if not _moved and _to_window(vp).distance_to(_down_win) > _mm_to_win(_slop_mm):
		_moved = true
	if _moved:
		_motion(vp)


func _touch_up(vp: Vector2) -> void:
	if not _pressed:
		return
	_pressed = false
	if _long_fired:
		_close_drawer()
		return
	if _moved:
		# released on a button: like a mouse release there, it's a click
		var gui := _gui_target(vp)
		if not gui.is_empty():
			_trace("drag end on %s -> click" % gui.control.name)
			_armed_item = null
			_click(gui.at, MOUSE_BUTTON_LEFT)
			return
		# otherwise the drag ends as a hover; the next tap on that item acts
		_armed_item = _item_at(vp)
		_trace("drag end, armed %s" % _name(_armed_item))
		return
	_tap(_down_vp)


func _tap(vp: Vector2) -> void:
	_connect_action_manager()
	var gui := _gui_target(vp)
	if not gui.is_empty():
		_trace("tap on %s -> click" % gui.control.name)
		_armed_item = null
		_gui_tap = true
		_click(gui.at, MOUSE_BUTTON_LEFT)
		_end_gui_tap.call_deferred()
		return
	if _layout and _layout.covers(vp):
		return  # on the open drawer but on no control: not the room below
	if not _in_default_state() or not _two_tap:
		_trace("tap -> click (not default state / one-tap mode)")
		_armed_item = null
		_click(vp, MOUSE_BUTTON_LEFT)
		return

	var item := _item_at(vp)
	if item and str(item.get("tooltip_name")).is_empty():
		# nameless item (e.g. a full-screen "click to start" area): a hover
		# would show nothing, so act at once
		_trace("tap on nameless %s -> click" % _name(item))
		_armed_item = null
		_close_drawer()
		_click(vp, MOUSE_BUTTON_LEFT)
		return
	if item:
		if item == _armed_item:
			_trace("2nd tap on %s -> click" % _name(item))
			_close_drawer()
			_click(vp, MOUSE_BUTTON_LEFT)
		else:
			_trace("1st tap on %s -> hover" % _name(item))
			_armed_item = item
			if _layout:
				_layout.open()
				_verb_item = item
				_verb_vp = vp
		return

	_armed_item = null
	_close_drawer()
	var now := Time.get_ticks_msec()
	var win := _to_window(vp)
	var double := now - _last_floor_ms <= _double_tap_ms \
			and win.distance_to(_last_floor_win) <= _mm_to_win(_slop_mm) * 2.0
	_trace("floor tap -> %s" % ("double click (run)" if double else "click (walk)"))
	_click(vp, MOUSE_BUTTON_LEFT, double)
	# a third quick tap starts a new pair instead of another double
	_last_floor_ms = -100000 if double else now
	_last_floor_win = win


# --- web: fullscreen at the first touch -------------------------------------

## Browsers only allow fullscreen from a user gesture: the first touch is one
## (Godot handles touch input inside the browser's event). Goes through
## Escoria's fullscreen setting when there is one, so the game's own options
## and buttons agree (not saved: it's for this session).
func _first_touch_fullscreen() -> void:
	_fullscreen_done = true
	if not bool(Settings.get_value(Settings.WEB_FULLSCREEN)):
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return
	_say("first touch -> fullscreen")
	ESCProjectSettingsManager.set_setting(ESCProjectSettingsManager.FULLSCREEN, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# --- drawer and "object, then verb" ----------------------------------------

func _close_drawer() -> void:
	_verb_item = null
	if _layout:
		_layout.close()


func _on_drawer_changed(open: bool) -> void:
	if not open:
		_verb_item = null


func _end_gui_tap() -> void:
	_gui_tap = false


func _connect_action_manager() -> void:
	var esc := _escoria()
	if esc and esc.action_manager and \
			not esc.action_manager.action_changed.is_connected(_on_action_changed):
		esc.action_manager.action_changed.connect(_on_action_changed)


## A verb was chosen. If it came from a tap on the drawer while an item was
## waiting, the drawer closes at once and the item is clicked: the verb acts
## on it (even if the open drawer was covering it).
func _on_action_changed() -> void:
	var esc := _escoria()
	if not _gui_tap or _verb_item == null or not is_instance_valid(_verb_item):
		return
	if esc.action_manager.current_action.is_empty() or esc.action_manager.current_tool != null:
		return
	var vp := _verb_vp
	_trace("verb %s -> on %s" % [esc.action_manager.current_action, _name(_verb_item)])
	_verb_item = null
	_armed_item = null
	if _layout:
		_layout.close(false)
	_click(vp, MOUSE_BUTTON_LEFT)


# --- what is under the finger --------------------------------------------

## The GUI Control a tap at vp is meant for (buttons, inventory slots,
## menus, dialog options: Controls that stop the mouse), and the point to
## click: {"control": Control, "at": Vector2 (viewport)}, or {} if none.
## Controls smaller than min_target_mm get a touch area of that size; a tap
## in it but outside the control snaps to the control's center.
func _gui_target(vp: Vector2) -> Dictionary:
	# An open popup (an OptionButton's list, a PopupMenu...) is a window of
	# its own on top of everything: a tap on it goes straight there, with no
	# snapping to the controls behind it.
	for w: Window in get_viewport().get_embedded_subwindows():
		if w.visible and Rect2(Vector2(w.position), Vector2(w.size)).has_point(vp):
			return {"control": w, "at": vp}
	var target_vp := _mm_to_win(_min_target_mm) / get_viewport().get_screen_transform().get_scale().x
	var exact: Control = null
	var near: Control = null
	var near_at := Vector2.ZERO
	var near_d := INF
	for c: Control in _stop_controls(get_tree().root, []):
		var xf := c.get_global_transform_with_canvas()
		var local: Vector2 = xf.affine_inverse() * vp
		var rect := Rect2(Vector2.ZERO, c.size)
		var target := target_vp / maxf(xf.get_scale().x, 0.0001)  # in the control's units
		var small := c.size.x < target or c.size.y < target
		if rect.has_point(local):
			if small:
				return {"control": c, "at": vp}
			exact = c  # the deepest one (found last) names the tap better
			continue
		if small:
			var gx := maxf(0.0, (target - c.size.x) / 2.0)
			var gy := maxf(0.0, (target - c.size.y) / 2.0)
			if rect.grow_individual(gx, gy, gx, gy).has_point(local):
				var center: Vector2 = xf * (c.size / 2.0)
				var d := center.distance_to(vp)
				if d < near_d:
					near = c
					near_d = d
					near_at = center
	if near:
		return {"control": near, "at": near_at}
	if exact:
		return {"control": exact, "at": vp}
	return {}


func _stop_controls(node: Node, out: Array) -> Array:
	# no pruning at hidden CanvasItems: a CanvasLayer under them still shows
	if node is CanvasLayer and not node.visible:
		return out
	if node is Window and node != get_tree().root:
		return out  # popups: checked on their own in _gui_target
	if node is Control and node.mouse_filter == Control.MOUSE_FILTER_STOP \
			and node.size.x > 0 and node.size.y > 0 and node.is_visible_in_tree():
		out.append(node)
	for child in node.get_children():
		_stop_controls(child, out)
	return out


## Topmost actionable ESCItem under the point, or null. The player's own
## character doesn't count: a tap on it walks there (and Escoria's hover
## then picks whatever is behind it).
func _item_at(vp: Vector2) -> Node:
	var esc := _escoria()
	var player = null
	if esc and esc.main and esc.main.current_scene:
		player = esc.main.current_scene.get("player")
	var best: Node = null
	for node in _items_at(vp):
		if node == player:
			continue
		if esc and not esc.action_manager.is_object_actionable(node.global_id):
			continue
		if best == null or node.z_index > best.z_index:
			best = node
	return best


## Every non-trigger ESCItem whose shape contains the point.
func _items_at(vp: Vector2) -> Array:
	var world := get_viewport().get_canvas_transform().affine_inverse() * vp
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = 0x7FFFFFFF
	var items: Array = []
	for hit in get_viewport().world_2d.direct_space_state.intersect_point(params, 32):
		var node = hit.collider
		if node is ESCItem and not node.is_trigger and not items.has(node):
			items.append(node)
	return items


## What physics picking would do for a motion event: mouse_exited on the
## items left behind, input_event on one item under the cursor (Escoria then
## works out the whole hover stack from there).
func _update_hover(motion: InputEventMouseMotion) -> void:
	var now := _items_at(motion.position)
	for node in _hovered:
		if is_instance_valid(node) and not now.has(node):
			node._on_mouse_exited()
	_hovered = now
	if not now.is_empty():
		now[0]._on_input_event(get_viewport(), motion, 0)


func _in_default_state() -> bool:
	var esc := _escoria()
	return esc == null or esc.current_state == esc.GameState.DEFAULT


func _escoria() -> Node:
	return get_node_or_null("/root/escoria")


# --- synthetic mouse events ------------------------------------------------

func _motion(vp: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.device = SYNTH_DEVICE
	ev.position = _to_window(vp)
	ev.global_position = ev.position
	Input.parse_input_event(ev)


func _click(vp: Vector2, button: MouseButton, double := false) -> void:
	_motion(vp)
	var win := _to_window(vp)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.device = SYNTH_DEVICE
		ev.position = win
		ev.global_position = win
		ev.button_index = button
		ev.pressed = pressed
		ev.double_click = double and pressed
		ev.button_mask = (1 << (button - 1)) if pressed else 0
		Input.parse_input_event(ev)


## Millimetres on the screen to window pixels.
func _mm_to_win(mm: float) -> float:
	return mm * DisplayServer.screen_get_dpi() / 25.4


func _to_window(vp: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * vp


func _handled() -> void:
	get_viewport().set_input_as_handled()


func _name(node: Node) -> String:
	return "nothing" if node == null else str(node.get("global_id"))


func _trace(msg: String) -> void:
	if _log or _overlay:
		_say(msg)


## Always printed; also shown on the debug overlay if it's on.
func _say(msg: String) -> void:
	print("EscoriaMobile: ", msg)
	if _overlay:
		_overlay_lines.append(msg)
		if _overlay_lines.size() > 6:
			_overlay_lines.remove_at(0)
		_overlay.text = "\n".join(_overlay_lines)


func _make_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 127
	add_child(layer)
	_overlay = Label.new()
	var y := 8.0
	if bool(Settings.get_value(Settings.HUD)) and int(Settings.get_value(Settings.HUD_CORNER)) < 2:
		y += float(Settings.get_value(Settings.HUD_MARGIN)) * 2.0 \
				+ float(Settings.get_value(Settings.HUD_BUTTON_SIZE))  # under the HUD buttons
	_overlay.position = Vector2(8, y)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_theme_font_size_override("font_size", 20)
	_overlay.add_theme_color_override("font_color", Color.YELLOW)
	_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override("outline_size", 6)
	layer.add_child(_overlay)
