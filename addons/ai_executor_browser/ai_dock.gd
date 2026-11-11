@tool
extends VBoxContainer

@onready var _tabs: TabContainer = $TabContainer
@onready var _executor: VBoxContainer = $TabContainer/Executor
@onready var _browser: VBoxContainer = $TabContainer/Browser


func _ready() -> void:
	_tabs.set_tab_title(0, "Executor")
	_tabs.set_tab_title(1, "Browser")

	if _browser.has_signal("code_ready"):
		_browser.connect("code_ready", Callable(self, "_on_code_ready"))


func _on_code_ready(code: String) -> void:
	if _executor.has_method("set_code"):
		_executor.call("set_code", code)
	_tabs.current_tab = 0