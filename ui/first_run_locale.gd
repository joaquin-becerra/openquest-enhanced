extends Node
## The first time the game opens (no saved settings.tres yet) it picks the
## system language, or on the web the browser's preferred one, if the
## game has it. Runs before Escoria loads and creates the settings; after
## that, the player's choice in Options rules.

const TEXT_LANG := "escoria/main/text_lang"


func _ready() -> void:
	var folder: String = ProjectSettings.get_setting("escoria/main/settings_path")
	if FileAccess.file_exists(folder.path_join("settings.tres")):
		return
	var lang := OS.get_locale_language()   # "es", "it"... (navigator.language on the web)
	if lang in TranslationServer.get_loaded_locales():
		ProjectSettings.set_setting(TEXT_LANG, lang)
		TranslationServer.set_locale(lang)
