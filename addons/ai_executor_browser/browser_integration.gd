class_name AIExecutorBrowserIntegration
extends RefCounted

signal url_changed(url: String)
signal load_started(url: String)
signal load_finished(url: String)
signal code_captured(code: String)
signal browser_error(message: String)

var _webview: Control
var _current_url: String = ""


static func is_wry_available() -> bool:
	return ClassDB.class_exists("WebView") and ClassDB.can_instantiate("WebView")


func has_webview() -> bool:
	return is_instance_valid(_webview)


func create_webview() -> Control:
	if not is_wry_available():
		return null

	var instance := ClassDB.instantiate("WebView")
	if instance == null:
		browser_error.emit("WRY is installed, but ClassDB could not instantiate WebView.")
		return null

	if not instance is Control:
		browser_error.emit("WRY returned an object that is not a Control.")
		return null

	_webview = instance as Control
	_configure_webview()
	_connect_signals()
	return _webview


func _configure_webview() -> void:
	# In a dock we want the webview to respect the Control rect, not cover the viewport.
	_set_property_if_exists("full_window_size", false)
	_set_property_if_exists("transparent", false)
	_set_property_if_exists("devtools", true)
	_set_property_if_exists("zoom_hotkeys", true)
	_set_property_if_exists("clipboard", true)
	_set_property_if_exists("forward_input_events", true)


func _connect_signals() -> void:
	_connect_if_exists("page_load_started", Callable(self, "_on_page_load_started"))
	_connect_if_exists("page_load_finished", Callable(self, "_on_page_load_finished"))
	_connect_if_exists("ipc_message", Callable(self, "_on_ipc_message"))


func _connect_if_exists(signal_name: String, callable: Callable) -> void:
	if _webview != null and _webview.has_signal(signal_name):
		_webview.connect(signal_name, callable)


func _set_property_if_exists(property_name: String, value: Variant) -> void:
	if _webview == null:
		return
	for prop in _webview.get_property_list():
		if str(prop.get("name", "")) == property_name:
			_webview.set(property_name, value)
			return


func load_url(url: String) -> void:
	if not has_webview():
		return
	if _webview.has_method("load_url"):
		_webview.call("load_url", url)
	else:
		eval("window.location.href = %s" % JSON.stringify(url))


func reload() -> void:
	if not has_webview():
		return
	if _webview.has_method("reload"):
		_webview.call("reload")
	else:
		eval("window.location.reload()")


func go_back() -> void:
	if not has_webview():
		return
	if _webview.has_method("go_back"):
		_webview.call("go_back")
	else:
		eval("history.back()")


func go_forward() -> void:
	if not has_webview():
		return
	if _webview.has_method("go_forward"):
		_webview.call("go_forward")
	else:
		eval("history.forward()")


func open_devtools() -> void:
	if not has_webview():
		return
	if _webview.has_method("open_devtools"):
		_webview.call("open_devtools")


func eval(js: String) -> void:
	if not has_webview():
		return
	if _webview.has_method("eval"):
		_webview.call("eval", js)
	else:
		browser_error.emit("WRY WebView does not expose eval().")


func request_selected_code() -> void:
	if not has_webview():
		return

	var js := """
	(function() {
		if (typeof ipc === 'undefined') { return; }
		var code = window.getSelection().toString();
		if (!code || code.trim().length === 0) {
			var blocks = Array.from(document.querySelectorAll('pre code, pre, textarea'));
			code = blocks.map(function(b) { return b.innerText || b.value; }).join('\\n\\n');
		}
		ipc.postMessage(JSON.stringify({ type: 'ai_executor_code', code: code }));
	})();
	"""
	eval(js)


func get_current_url() -> String:
	return _current_url


func _on_page_load_started(url: String) -> void:
	_current_url = url
	url_changed.emit(url)
	load_started.emit(url)


func _on_page_load_finished(url: String) -> void:
	_current_url = url
	url_changed.emit(url)
	load_finished.emit(url)


func _on_ipc_message(message: String) -> void:
	var data: Variant = JSON.parse_string(message)
	if data is Dictionary:
		if str(data.get("type", "")) == "ai_executor_code":
			var code := str(data.get("code", ""))
			if not code.strip_edges().is_empty():
				code_captured.emit(code)