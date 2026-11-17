@tool
# Registers the EscoriaMobile autoload and its Project Settings.
extends EditorPlugin

const AUTOLOAD_NAME := "EscoriaMobile"
const AUTOLOAD_PATH := "res://addons/escoria-mobile/mobile_input.gd"
const Settings = preload("res://addons/escoria-mobile/settings.gd")


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
	Settings.register()
	ProjectSettings.save()


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
