# Project Settings under escoria/mobile/...
extends RefCounted

const ENABLED := "escoria/mobile/enabled"            # 0 auto, 1 always, 2 never
const DOUBLE_TAP_MS := "escoria/mobile/double_tap_ms"
const LONG_PRESS_MS := "escoria/mobile/long_press_ms"
const TAP_SLOP_MM := "escoria/mobile/tap_slop_mm"      # finger travel still counted as a tap
const MIN_TARGET_MM := "escoria/mobile/min_target_mm"  # small buttons get at least this touch area
const TWO_TAP_ACTION := "escoria/mobile/two_tap_action"  # 1st tap = hover, 2nd = act
const SIMULATE_WITH_MOUSE := "escoria/mobile/debug/simulate_with_mouse"
const LOG := "escoria/mobile/debug/log"
const OVERLAY := "escoria/mobile/debug/overlay"      # last log lines on screen (for phones)
const HUD := "escoria/mobile/hud"                    # settings + highlight buttons
const HUD_HINT_NAMES := "escoria/mobile/hud_hint_names"  # names next to highlighted items
const WEB_FULLSCREEN := "escoria/mobile/web/fullscreen_on_first_touch"
const WEB_LANDSCAPE := "escoria/mobile/web/landscape"  # lock it in fullscreen; hint to turn the phone
const LAYOUT_ROOM_HEIGHT := "escoria/mobile/layout/room_height"  # 0 = keep the design letterboxed
const LAYOUT_PANEL := "escoria/mobile/layout/bottom_panel"       # panel node path in the game scene
const LAYOUT_TAB_SIDE := "escoria/mobile/layout/tab_side"        # drawer tab: right or left
const LAYOUT_TAB_SIZE := "escoria/mobile/layout/tab_size"
const LAYOUT_TAB_ICON := "escoria/mobile/layout/tab_icon"        # "" = drawn chevron (points up; flipped when open)

# HUD buttons (in game pixels, like the rest of the UI)
const HUD_CORNER := "escoria/mobile/hud_buttons/corner"
const HUD_BUTTON_SIZE := "escoria/mobile/hud_buttons/size"
const HUD_MARGIN := "escoria/mobile/hud_buttons/margin"          # from the screen edge and between buttons
const HUD_GEAR_ICON := "escoria/mobile/hud_buttons/settings_icon"  # "" = drawn gear
const HUD_STAR_ICON := "escoria/mobile/hud_buttons/highlight_icon" # "" = drawn star
const HUD_HIGHLIGHT_SECONDS := "escoria/mobile/hud_buttons/highlight_seconds"

# Look of everything the addon draws (HUD, drawer tab, highlights, hints)
const STYLE_BACKGROUND := "escoria/mobile/style/background"
const STYLE_FOREGROUND := "escoria/mobile/style/foreground"
const STYLE_ACCENT := "escoria/mobile/style/accent"              # the highlight button while active
const STYLE_BORDER := "escoria/mobile/style/border_width"
const STYLE_MARK_FILL := "escoria/mobile/style/mark_fill"        # highlighted item: circle
const STYLE_MARK_RING := "escoria/mobile/style/mark_ring"        #   and its outline
const STYLE_MARK_RADIUS := "escoria/mobile/style/mark_radius"
const STYLE_BACKDROP := "escoria/mobile/style/backdrop"          # behind the slid-up dialog chooser

const ICONS := "*.png,*.svg,*.webp"

const DEFAULTS := {
	ENABLED: [0, TYPE_INT, PROPERTY_HINT_ENUM, "Auto,Always,Never"],
	DOUBLE_TAP_MS: [300, TYPE_INT, PROPERTY_HINT_RANGE, "100,1000"],
	LONG_PRESS_MS: [500, TYPE_INT, PROPERTY_HINT_RANGE, "200,2000"],
	TAP_SLOP_MM: [3.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.5,10,0.1"],
	MIN_TARGET_MM: [9.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,20,0.5"],
	TWO_TAP_ACTION: [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	SIMULATE_WITH_MOUSE: [false, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	LOG: [false, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	OVERLAY: [false, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	HUD: [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	HUD_HINT_NAMES: [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	WEB_FULLSCREEN: [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	WEB_LANDSCAPE: [true, TYPE_BOOL, PROPERTY_HINT_NONE, ""],
	LAYOUT_ROOM_HEIGHT: [0, TYPE_INT, PROPERTY_HINT_RANGE, "0,4320"],
	LAYOUT_PANEL: ["", TYPE_STRING, PROPERTY_HINT_NONE, ""],
	LAYOUT_TAB_SIDE: [0, TYPE_INT, PROPERTY_HINT_ENUM, "Right,Left"],
	LAYOUT_TAB_SIZE: [Vector2(88, 44), TYPE_VECTOR2, PROPERTY_HINT_NONE, ""],
	LAYOUT_TAB_ICON: ["", TYPE_STRING, PROPERTY_HINT_FILE, ICONS],
	HUD_CORNER: [0, TYPE_INT, PROPERTY_HINT_ENUM, "Top left,Top right,Bottom left,Bottom right"],
	HUD_BUTTON_SIZE: [64, TYPE_INT, PROPERTY_HINT_RANGE, "24,256"],
	HUD_MARGIN: [12, TYPE_INT, PROPERTY_HINT_RANGE, "0,128"],
	HUD_GEAR_ICON: ["", TYPE_STRING, PROPERTY_HINT_FILE, ICONS],
	HUD_STAR_ICON: ["", TYPE_STRING, PROPERTY_HINT_FILE, ICONS],
	HUD_HIGHLIGHT_SECONDS: [3.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.5,30,0.5"],
	STYLE_BACKGROUND: [Color(0.094, 0.243, 0.408, 0.85), TYPE_COLOR, PROPERTY_HINT_NONE, ""],
	STYLE_FOREGROUND: [Color(0.886, 0.875, 0.863, 1), TYPE_COLOR, PROPERTY_HINT_NONE, ""],
	STYLE_ACCENT: [Color(1.0, 0.85, 0.2, 1), TYPE_COLOR, PROPERTY_HINT_NONE, ""],
	STYLE_BORDER: [2.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0,10,0.5"],
	STYLE_MARK_FILL: [Color(0.094, 0.243, 0.408, 0.35), TYPE_COLOR, PROPERTY_HINT_NONE, ""],
	STYLE_MARK_RING: [Color(0.094, 0.243, 0.408, 0.9), TYPE_COLOR, PROPERTY_HINT_NONE, ""],
	STYLE_MARK_RADIUS: [18.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "4,100,1"],
	STYLE_BACKDROP: [Color(0, 0, 0, 0.7), TYPE_COLOR, PROPERTY_HINT_NONE, ""],
}


static func register() -> void:
	for key in DEFAULTS:
		var d: Array = DEFAULTS[key]
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, d[0])
		ProjectSettings.set_initial_value(key, d[0])
		ProjectSettings.add_property_info({
			"name": key, "type": d[1], "hint": d[2], "hint_string": d[3],
		})


static func get_value(key: String) -> Variant:
	return ProjectSettings.get_setting(key, DEFAULTS[key][0])


## An icon setting's texture, or null (empty, or it can't be loaded).
static func get_icon(key: String) -> Texture2D:
	var path := str(get_value(key))
	if path.is_empty():
		return null
	var tex = load(path) if ResourceLoader.exists(path) else null
	if not tex is Texture2D:
		push_warning("escoria-mobile: %s: can't load the icon %s" % [key, path])
		return null
	return tex
