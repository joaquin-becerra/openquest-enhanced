extends Control
## OpenQuest's options (replaces escoria-core's): language, music and
## effects volume, graphics (original / advanced) and screen mode.
## Changes apply at once; "Back" saves them.

signal back_button_pressed

## Each language's name in its own language.
const LANGUAGE_NAMES := {
	"en": "English",
	"es": "Español",
	"fr": "Français",
	"de": "Deutsch",
	"it": "Italiano",
	"pt": "Português",
}

## Played when moving the effects volume (Zif's phone beep).
const EFFECTS_SAMPLE := "res://sounds/phone_snd.wav"

var _locales: Array[String] = []
var _sample: AudioStreamPlayer

@onready var _language: OptionButton = %language
@onready var _music: HSlider = %music
@onready var _effects: HSlider = %effects
@onready var _graphics: OptionButton = %graphics
@onready var _screen: OptionButton = %screen


func _ready() -> void:
	for locale in TranslationServer.get_loaded_locales():
		if not locale in _locales:
			_locales.append(locale)
			_language.add_item(LANGUAGE_NAMES.get(locale, locale))
	# language names are not translated
	_language.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_language.get_popup().auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_graphics.add_item("GRAPHICS_ORIGINAL")
	_graphics.add_item("GRAPHICS_HD")
	_screen.add_item("SCREEN_WINDOW")
	_screen.add_item("FULLSCREEN")
	for option in [_language, _graphics, _screen]:
		option.get_popup().about_to_popup.connect(_style_popup.bind(option))
	_sample = AudioStreamPlayer.new()
	_sample.process_mode = Node.PROCESS_MODE_ALWAYS  # the pause menu runs while the game is paused
	_sample.bus = "SFX"
	_sample.stream = load(EFFECTS_SAMPLE)
	add_child(_sample)


## The menu opens it with open() (Control's show() can't be overridden).
func open() -> void:
	_refresh()
	visible = true


func _refresh() -> void:
	var lang: String = ESCProjectSettingsManager.get_setting(ESCProjectSettingsManager.TEXT_LANG)
	var i := _locales.find(lang)
	if i < 0:
		i = _locales.find(TranslationServer.get_locale().substr(0, 2))
	_language.select(i)
	_music.set_value_no_signal(ESCProjectSettingsManager.get_setting(ESCProjectSettingsManager.MUSIC_VOLUME))
	_effects.set_value_no_signal(ESCProjectSettingsManager.get_setting(ESCProjectSettingsManager.SFX_VOLUME))
	_graphics.select(1 if hd_graphics.hd_enabled else 0)
	_screen.select(1 if ESCProjectSettingsManager.get_setting(ESCProjectSettingsManager.FULLSCREEN) else 0)


## The dropdown list is a separate window: it copies the button's font (which
## hd_graphics changes by mode) and the boxes' style.
func _style_popup(option: OptionButton) -> void:
	var popup := option.get_popup()
	popup.add_theme_font_override("font", option.get_theme_font("font"))
	popup.add_theme_font_size_override("font_size", option.get_theme_font_size("font_size"))
	popup.add_theme_stylebox_override("panel", %panel.get_theme_stylebox("panel"))
	popup.add_theme_stylebox_override("hover", option.get_theme_stylebox("hover"))
	popup.add_theme_color_override("font_color", option.get_theme_color("font_color"))
	popup.add_theme_color_override("font_hover_color", option.get_theme_color("font_hover_color"))
	popup.min_size.x = int(option.size.x)


func _on_language_selected(index: int) -> void:
	ESCProjectSettingsManager.set_setting(ESCProjectSettingsManager.TEXT_LANG, _locales[index])
	TranslationServer.set_locale(_locales[index])


func _on_music_changed(value: float) -> void:
	ESCProjectSettingsManager.set_setting(ESCProjectSettingsManager.MUSIC_VOLUME, value)
	escoria.settings_manager.apply_settings()


## Effects: sounds plus voices and ambience (everything that isn't music).
func _on_effects_changed(value: float) -> void:
	for setting in [ESCProjectSettingsManager.SFX_VOLUME, ESCProjectSettingsManager.SPEECH_VOLUME,
			ESCProjectSettingsManager.AMBIENT_VOLUME]:
		ESCProjectSettingsManager.set_setting(setting, value)
	escoria.settings_manager.apply_settings()
	# dragging sends many changes in a row: don't cut the beep that's playing
	if not _sample.playing:
		_sample.play()


func _on_graphics_selected(index: int) -> void:
	hd_graphics.set_hd(index == 1)


func _on_screen_selected(index: int) -> void:
	ESCProjectSettingsManager.set_setting(ESCProjectSettingsManager.FULLSCREEN, index == 1)
	escoria.settings_manager.apply_settings()


func _on_back_pressed() -> void:
	escoria.settings_manager.save_settings()
	back_button_pressed.emit()
