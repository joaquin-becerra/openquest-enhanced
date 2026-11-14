extends Node
## Switches between the original and the advanced (HD) graphics while playing.
##
## HD graphics live in res://hd/ with the same path and name as the
## original (res://rooms/x/background.png -> res://hd/rooms/x/background.png).
## Rule: each HD image covers exactly the same area as its original; it can
## have more resolution, but as an exact multiple of the original size (Carol: x4).
## The factor is computed automatically and offset by the node's scale and offset,
## so positions, collisions and scripts don't change.
##
## If a graphic has no HD version, advanced mode keeps showing the
## original. Shortcut to test: F10.
##
## Margin (HD_MARGIN): the HD frames of a folder can have an extra transparent
## border of N HD px around them, so what sticks out of the original frame
## (fingers, weapons) isn't cut off. The size without the margin is still an
## exact multiple of the original, and the offset is corrected automatically.
##
## Fonts: in HD mode the bitmap fonts in FONT_MAP are replaced by TTF (in
## themes and in controls with their own font). The size is multiplied
## by "scale" (tuned by eye in the game: the verbs have to fit in the
## bar's boxes). A control whose text has characters the TTF lacks
## (the inventory and dialog arrows) keeps the bitmap font.

const HD_ROOT := "res://hd/"
const CONFIG_PATH := "user://graficos.cfg"
const TOGGLE_KEY := KEY_F10

const BANGERS := "res://hd/fonts/Bangers-Regular.ttf"
## Variable Nunito at weight 700 (FontVariation); the speech one with -1 spacing.
const NUNITO_BOLD := "res://hd/fonts/Nunito-Bold.tres"
const NUNITO_BOLD_SPEECH := "res://hd/fonts/Nunito-Bold-hablado.tres"
const FONT_MAP := {
	# speech: with an outline, like the bitmap font (which has it drawn in).
	# Nunito 700 at 31 px, spacing -1, almost black outline 17 (chosen in
	# ai_refs/fuentes/probador_fuentes.html). Nunito's line spacing is wide: reduced.
	"res://fonts/chtest.fnt": {"font": NUNITO_BOLD_SPEECH, "scale": 0.4844, "outline": 17,
			"outline_color": Color(0.141, 0.122, 0.192), "line_sep": -10},
	# dialog options
	"res://fonts/dialog_charset.fnt": {"font": NUNITO_BOLD, "scale": 0.875},
	# verbs and action sentence (40: "RECOGER" is 118 px wide and the box 158)
	"res://fonts/verb_chset.fnt": {"font": BANGERS, "scale": 1.0},
}
const FONT_SLOTS := {
	"font": "font_size",
	"normal_font": "normal_font_size",
	"bold_font": "bold_font_size",
	"italics_font": "italics_font_size",
}
const OUTLINE_TYPES := ["RichTextLabel", "Label"]
## Name of the line spacing constant for each control type.
const LINE_SEP_CONST := {"RichTextLabel": "line_separation", "Label": "line_spacing"}
## Inventory and dialog chooser arrows: they are verb_chset glyphs the
## TTFs don't have. In HD the glyph is replaced by an icon (white, tinted
## with the button's colors).
const ARROW_ICONS := {"\u0003": "res://hd/ui/arrow_up.png", "\u0002": "res://hd/ui/arrow_down.png"}
const ARROW_ICON_WIDTH := 28
## Transparent margin (HD px per side) of the HD frames in each folder.
const HD_MARGIN := {
	"res://hd/characters/ensign_zob/frames/": 64,
	"res://hd/characters/commander_zif/frames/": 64,
	"res://hd/characters/cube_actor/frames/": 64,
	"res://hd/characters/bluecup_actor/frames/": 64,
	"res://hd/characters/ufo_actor/frames/": 64,
}

## HD speech color per character (the character's scene; Zob's global_id
## is "player"). In original mode the scene's dialog_color stays.
const HD_DIALOG_COLORS := {
	"res://characters/ensign_zob/ensign_zob.tscn": Color(0.965, 0.380, 0.318),  # #f66151
}

var hd_enabled := true

var _exists_cache := {}


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		hd_enabled = cfg.get_value("graficos", "hd", hd_enabled)
	get_tree().node_added.connect(_apply_node)
	_apply_tree.call_deferred(get_tree().root)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == TOGGLE_KEY:
		set_hd(not hd_enabled)
		get_viewport().set_input_as_handled()


## Turns the advanced graphics on or off and saves it in the config.
func set_hd(enabled: bool) -> void:
	hd_enabled = enabled
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("graficos", "hd", hd_enabled)
	cfg.save(CONFIG_PATH)
	_apply_tree(get_tree().root)


func _apply_tree(node: Node) -> void:
	if node is Control:
		_apply_control(node)
	else:
		_apply_node(node)
	for child in node.get_children():
		_apply_tree(child)


func _apply_node(node: Node) -> void:
	if HD_DIALOG_COLORS.has(node.scene_file_path):
		_apply_dialog_color(node)
	if node is Sprite2D:
		_apply_sprite(node)
	elif node is AnimatedSprite2D:
		_apply_animated_sprite(node)
	elif node is AnimationPlayer:
		_apply_animations(node)
	elif node is Control:
		# Deferred: many controls get their font after entering the tree.
		_apply_control.call_deferred(node)
	elif node.get("inventory_texture") != null:
		_apply_item(node)


func _apply_dialog_color(item: Node) -> void:
	if not item.has_meta("hd_dialog_color"):
		item.set_meta("hd_dialog_color", item.get("dialog_color"))
	item.set("dialog_color", HD_DIALOG_COLORS[item.scene_file_path] if hd_enabled \
			else item.get_meta("hd_dialog_color"))


## Escoria objects: the inventory copies inventory_texture when showing them.
func _apply_item(item: Node) -> void:
	for prop in ["inventory_texture", "inventory_texture_hovered"]:
		var tex = item.get(prop)
		if tex is Texture2D:
			var t := _target(tex)
			if t != tex:
				item.set(prop, t)


## TextureRect and textured buttons (verb bar, inventory icons).
## HD UI textures have the same size as the originals.
func _apply_texture_control(control: Control) -> void:
	for prop in ["texture", "texture_normal", "texture_hover", "texture_pressed", "texture_focused"]:
		var tex = control.get(prop)
		if tex is Texture2D:
			var t := _target(tex)
			if t != tex:
				control.set(prop, t)


## Textured styles (menu buttons, which use the verb box).
## The HD texture has the same size as the original: the margins don't change.
const STYLE_SLOTS := ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed", "panel"]


func _apply_styleboxes(control: Control) -> void:
	for slot in STYLE_SLOTS:
		if not control.has_theme_stylebox_override(slot):
			continue
		var sb := control.get_theme_stylebox(slot)
		if sb is StyleBoxTexture:
			var t := _target(sb.texture)
			if t != sb.texture:
				sb.texture = t


func _apply_arrow(button: Button) -> void:
	var glyph: String = button.get_meta("hd_arrow", button.text)
	if not ARROW_ICONS.has(glyph):
		return
	button.set_meta("hd_arrow", glyph)
	if hd_enabled:
		button.text = ""
		button.icon = load(ARROW_ICONS[glyph])
		# Same alignment the glyph had: so the 28 px icon sits where the glyph
		# was drawn (centered in the bar's arrow boxes).
		button.icon_alignment = button.alignment
		button.add_theme_constant_override("icon_max_width", ARROW_ICON_WIDTH)
		for pair in [["icon_normal_color", "font_color"], ["icon_hover_color", "font_hover_color"],
				["icon_pressed_color", "font_pressed_color"], ["icon_hover_pressed_color", "font_hover_pressed_color"],
				["icon_focus_color", "font_focus_color"]]:
			button.add_theme_color_override(pair[0], button.get_theme_color(pair[1]))
	else:
		button.icon = null
		button.text = glyph


# --- Paths and textures -------------------------------------------------------

func _original_path(path: String) -> String:
	if path.begins_with(HD_ROOT):
		return "res://" + path.substr(HD_ROOT.length())
	return path


func _exists(path: String) -> bool:
	if not _exists_cache.has(path):
		_exists_cache[path] = ResourceLoader.exists(path)
	return _exists_cache[path]


## The texture for the current mode (or the same one, if it has no pair).
func _target(tex: Texture2D) -> Texture2D:
	if tex == null or tex.resource_path == "":
		return tex
	var orig := _original_path(tex.resource_path)
	var want := (HD_ROOT + orig.substr("res://".length())) if hd_enabled else orig
	if want == tex.resource_path or not _exists(want):
		return tex
	return load(want)


## Transparent margin (HD px per side) of `tex`; 0 if it has none.
func _margin(tex: Texture2D) -> int:
	if tex == null:
		return 0
	return HD_MARGIN.get(tex.resource_path.get_base_dir() + "/", 0)


## How many times bigger `tex` is than its original (1 if it is the original).
func _factor(tex: Texture2D) -> float:
	if tex == null or not tex.resource_path.begins_with(HD_ROOT):
		return 1.0
	var orig_path := _original_path(tex.resource_path)
	if not _exists(orig_path):
		return 1.0
	var orig: Texture2D = load(orig_path)
	return float(tex.get_width() - 2 * _margin(tex)) / float(orig.get_width())


# --- Nodes ----------------------------------------------------------------------

## Stores the node's scale, offset, region and filter as they come from the
## scene (with original graphics), to compensate and to go back.
func _base(node: Node2D) -> Dictionary:
	if not node.has_meta("hd_base"):
		var base := {
			"scale": node.scale,
			"offset": node.get("offset"),
			"filter": node.texture_filter,
		}
		if node is Sprite2D:
			base["region"] = node.region_rect
		node.set_meta("hd_base", base)
	return node.get_meta("hd_base")


func _fit(node: Node2D, factor: float, is_hd: bool, margin := 0) -> void:
	var base := _base(node)
	node.scale = base["scale"] / factor
	# with centered the margin is symmetric and moves nothing
	var shift := Vector2.ZERO if node.get("centered") else Vector2(margin, margin)
	node.set("offset", base["offset"] * factor - shift)
	if node is Sprite2D and node.region_enabled:
		var r: Rect2 = base["region"]
		node.region_rect = Rect2(r.position * factor, r.size * factor)
	if not is_hd:
		node.texture_filter = base["filter"]
	elif factor > 1.0:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _apply_sprite(sprite: Sprite2D) -> void:
	var tex := _target(sprite.texture)
	if tex == null:
		return
	_base(sprite)
	sprite.texture = tex
	_fit(sprite, _factor(tex), tex.resource_path.begins_with(HD_ROOT), _margin(tex))


func _apply_animated_sprite(sprite: AnimatedSprite2D) -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return
	_base(sprite)
	# All frames share a scale: the factor comes from an HD frame if there is
	# one. A frame without an HD pair would look small; a warning asks to add it.
	var sample: Texture2D = null
	var missing := 0
	for anim in frames.get_animation_names():
		for i in frames.get_frame_count(anim):
			var tex := _target(frames.get_frame_texture(anim, i))
			if tex != frames.get_frame_texture(anim, i):
				frames.set_frame(anim, i, tex, frames.get_frame_duration(anim, i))
			if tex == null:
				continue
			if tex.resource_path.begins_with(HD_ROOT):
				if sample == null or not sample.resource_path.begins_with(HD_ROOT):
					sample = tex
			else:
				missing += 1
				if sample == null:
					sample = tex
	if sample != null:
		var is_hd := sample.resource_path.begins_with(HD_ROOT)
		if is_hd and missing > 0:
			push_warning("hd_graphics: %s tiene %d cuadros sin version HD" % [sprite.get_parent().name, missing])
		_fit(sprite, _factor(sample), is_hd, _margin(sample))


# --- Fonts ----------------------------------------------------------------------

func _hd_font(original: Font) -> Dictionary:
	if original == null or not FONT_MAP.has(original.resource_path):
		return {}
	return FONT_MAP[original.resource_path]


## Native size of a bitmap font (for controls without their own size).
func _native_size(font: Font) -> int:
	var size = font.get("fixed_size")
	return size if size is int and size > 0 else 40


## Does the TTF have every character of the control's text?
func _text_fits(control: Control, font: Font) -> bool:
	var text = control.get("text")
	if not text is String:
		return true
	for c in text:
		if c != " " and c != "\n" and not font.has_char(c.unicode_at(0)):
			return false
	return true


func _apply_theme(theme: Theme) -> void:
	if not theme.has_meta("hd_base"):
		theme.set_meta("hd_base", {"font": theme.default_font, "size": theme.default_font_size})
	var base: Dictionary = theme.get_meta("hd_base")
	var map := _hd_font(base["font"])
	if map.is_empty():
		return
	if hd_enabled:
		theme.default_font = load(map["font"])
		theme.default_font_size = roundi(base["size"] * map["scale"])
		if map.has("outline"):
			for type in OUTLINE_TYPES:
				theme.set_constant("outline_size", type, map["outline"])
				theme.set_color("font_outline_color", type, map.get("outline_color", Color.BLACK))
		if map.has("line_sep"):
			for type in LINE_SEP_CONST:
				theme.set_constant(LINE_SEP_CONST[type], type, map["line_sep"])
	else:
		theme.default_font = base["font"]
		theme.default_font_size = base["size"]
		if map.has("outline"):
			for type in OUTLINE_TYPES:
				theme.clear_constant("outline_size", type)
				theme.clear_color("font_outline_color", type)
		if map.has("line_sep"):
			for type in LINE_SEP_CONST:
				theme.clear_constant(LINE_SEP_CONST[type], type)


func _apply_control(control: Control) -> void:
	if not is_instance_valid(control):
		return
	_apply_texture_control(control)
	_apply_styleboxes(control)
	if control is Button:
		_apply_arrow(control)
	if control.theme != null:
		_apply_theme(control.theme)
	var base: Dictionary = control.get_meta("hd_fonts", {})
	for slot in FONT_SLOTS:
		var size_slot: String = FONT_SLOTS[slot]
		if not base.has(slot):
			if not control.has_theme_font_override(slot):
				continue
			var font := control.get_theme_font(slot)
			if _hd_font(font).is_empty():
				continue
			var size := control.get_theme_font_size(size_slot) \
					if control.has_theme_font_size_override(size_slot) else _native_size(font)
			base[slot] = {"font": font, "size": size}
		var entry: Dictionary = base[slot]
		var map := _hd_font(entry["font"])
		var ttf: Font = load(map["font"])
		if hd_enabled and _text_fits(control, ttf):
			control.add_theme_font_override(slot, ttf)
			control.add_theme_font_size_override(size_slot, roundi(entry["size"] * map["scale"]))
			if map.has("outline"):
				control.add_theme_constant_override("outline_size", map["outline"])
				control.add_theme_color_override("font_outline_color", map.get("outline_color", Color.BLACK))
			if map.has("line_sep"):
				for type in LINE_SEP_CONST:
					if control.is_class(type):
						control.add_theme_constant_override(LINE_SEP_CONST[type], map["line_sep"])
		else:
			control.add_theme_font_override(slot, entry["font"])
			control.add_theme_font_size_override(size_slot, entry["size"])
			if map.has("outline"):
				control.remove_theme_constant_override("outline_size")
				control.remove_theme_color_override("font_outline_color")
			if map.has("line_sep"):
				for type in LINE_SEP_CONST:
					if control.is_class(type):
						control.remove_theme_constant_override(LINE_SEP_CONST[type])
	if not base.is_empty():
		control.set_meta("hd_fonts", base)


## Object states change the sprite's texture through animations
## ("sprite:texture"): those tracks' textures are swapped too.
func _apply_animations(player: AnimationPlayer) -> void:
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			var anim := lib.get_animation(anim_name)
			for t in anim.get_track_count():
				if anim.track_get_type(t) != Animation.TYPE_VALUE:
					continue
				for k in anim.track_get_key_count(t):
					var value = anim.track_get_key_value(t, k)
					if value is Texture2D:
						var tex := _target(value)
						if tex != value:
							anim.track_set_key_value(t, k, tex)
