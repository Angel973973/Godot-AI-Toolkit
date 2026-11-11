class_name AIExecutorBrowserSettings
extends RefCounted

const CONFIG_PATH := "user://ai_executor_browser.cfg"
const SECTION := "ai_executor_browser"
const DEFAULT_URL := "https://chat.openai.com"


static func get_start_url() -> String:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err == OK:
		return str(cfg.get_value(SECTION, "start_url", DEFAULT_URL))
	return DEFAULT_URL


static func set_start_url(url: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION, "start_url", url)
	cfg.save(CONFIG_PATH)


static func get_confirm_dangerous() -> bool:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err == OK:
		return bool(cfg.get_value(SECTION, "confirm_dangerous", true))
	return true


static func set_confirm_dangerous(value: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value(SECTION, "confirm_dangerous", value)
	cfg.save(CONFIG_PATH)