@tool
extends VBoxContainer

signal code_ready(code: String)

var _integration: AIExecutorBrowserIntegration
var _webview: Control
var _webview_container: PanelContainer
var _address_edit: LineEdit
var _status_label: Label


func _ready() -> void:
	_build_ui()
	_setup_integration()
	call_deferred("_setup_browser")


func _build_ui() -> void:
	var toolbar := HBoxContainer.new()

	var back_btn := Button.new()
	back_btn.text = "◀"
	back_btn.tooltip_text = "Back"
	back_btn.pressed.connect(func() -> void:
		if _integration != null:
			_integration.go_back()
	)
	toolbar.add_child(back_btn)

	var forward_btn := Button.new()
	forward_btn.text = "▶"
	forward_btn.tooltip_text = "Forward"
	forward_btn.pressed.connect(func() -> void:
		if _integration != null:
			_integration.go_forward()
	)
	toolbar.add_child(forward_btn)

	var reload_btn := Button.new()
	reload_btn.text = "⟳"
	reload_btn.tooltip_text = "Reload"
	reload_btn.pressed.connect(func() -> void:
		if _integration != null:
			_integration.reload()
	)
	toolbar.add_child(reload_btn)

	_address_edit = LineEdit.new()
	_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address_edit.placeholder_text = "https://chat.openai.com"
	_address_edit.text_submitted.connect(_on_address_submitted)
	toolbar.add_child(_address_edit)

	var go_btn := Button.new()
	go_btn.text = "Go"
	go_btn.pressed.connect(func() -> void:
		_on_address_submitted(_address_edit.text)
	)
	toolbar.add_child(go_btn)

	var send_btn := Button.new()
	send_btn.text = "Send Code"
	send_btn.tooltip_text = "Copy selected text or code blocks from the page into the Executor tab."
	send_btn.pressed.connect(_on_send_code_pressed)
	toolbar.add_child(send_btn)

	var clipboard_btn := Button.new()
	clipboard_btn.text = "Paste Clipboard"
	clipboard_btn.pressed.connect(_on_paste_clipboard_pressed)
	toolbar.add_child(clipboard_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.pressed.connect(_on_settings_pressed)
	toolbar.add_child(settings_btn)

	var devtools_btn := Button.new()
	devtools_btn.text = "DevTools"
	devtools_btn.pressed.connect(func() -> void:
		if _integration != null:
			_integration.open_devtools()
	)
	toolbar.add_child(devtools_btn)

	add_child(toolbar)

	_webview_container = PanelContainer.new()
	_webview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_webview_container)

	_status_label = Label.new()
	_status_label.text = "Initializing browser..."
	add_child(_status_label)

	var note := Label.new()
	note.text = "WRY renders a native webview. On some platforms it may not embed into editor docks; use 'Open AI chat in external browser' if this area stays blank."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color(1, 1, 1, 0.65)
	add_child(note)


func _setup_integration() -> void:
	_integration = AIExecutorBrowserIntegration.new()
	_integration.url_changed.connect(_on_url_changed)
	_integration.load_finished.connect(_on_load_finished)
	_integration.code_captured.connect(_on_code_captured)
	_integration.browser_error.connect(_on_browser_error)


func _setup_browser() -> void:
	if _integration == null:
		return

	if not AIExecutorBrowserIntegration.is_wry_available():
		_show_wry_missing_ui("Godot WRY is not installed or not enabled in this project.")
		_status_label.text = "WRY not installed."
		return

	var webview := _integration.create_webview()
	if webview == null:
		_show_wry_missing_ui("WRY is installed, but the WebView node could not be created.")
		_status_label.text = "WebView creation failed."
		return

	_webview = webview
	_clear_container()
	_webview_container.add_child(_webview)
	_webview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_label.text = "Loading..."
	_integration.load_url(AIExecutorBrowserSettings.get_start_url())


func _clear_container() -> void:
	for child in _webview_container.get_children():
		child.queue_free()


func _show_wry_missing_ui(reason: String) -> void:
	_clear_container()

	var vbox := VBoxContainer.new()

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	var extra := ""
	if not reason.is_empty():
		extra = "\n[b]Details:[/b] " + reason
	label.text = """[font_size=16]WRY is not available[/font_size]

This dock uses the [b]Godot WRY[/b] GDExtension to embed a native webview.

[b]Installation[/b]
1. Open the [b]AssetLib[/b] tab.
2. Search for [b]Godot WRY[/b].
3. Download and install it into [code]addons/godot_wry[/code].
4. Restart the Godot editor.

You can also download a release ZIP from GitHub and extract it manually.%s""" % extra
	vbox.add_child(label)

	var github_btn := Button.new()
	github_btn.text = "Open Godot WRY GitHub"
	github_btn.pressed.connect(func() -> void:
		OS.shell_open("https://github.com/doceazedo/godot_wry")
	)
	vbox.add_child(github_btn)

	var external_btn := Button.new()
	external_btn.text = "Open AI chat in external browser"
	external_btn.pressed.connect(func() -> void:
		OS.shell_open(AIExecutorBrowserSettings.get_start_url())
	)
	vbox.add_child(external_btn)

	_webview_container.add_child(vbox)


func _on_address_submitted(new_text: String) -> void:
	var url := new_text.strip_edges()
	if url.is_empty():
		return
	if not url.begins_with("http://") and not url.begins_with("https://") and not url.begins_with("file://"):
		url = "https://" + url
	_address_edit.text = url

	if _integration != null and _integration.has_webview():
		_integration.load_url(url)
	else:
		OS.shell_open(url)


func _on_url_changed(url: String) -> void:
	if _address_edit != null and not _address_edit.has_focus():
		_address_edit.text = url


func _on_load_finished(url: String) -> void:
	_status_label.text = "Loaded: " + url


func _on_send_code_pressed() -> void:
	if _integration != null and _integration.has_webview():
		_integration.request_selected_code()
		_status_label.text = "Requesting selected text or code blocks from the page..."
	else:
		_on_paste_clipboard_pressed()


func _on_paste_clipboard_pressed() -> void:
	var text := DisplayServer.clipboard_get()
	if text.strip_edges().is_empty():
		_status_label.text = "Clipboard is empty."
		return
	code_ready.emit(text)
	_status_label.text = "Code sent from clipboard to Executor."


func _on_code_captured(code: String) -> void:
	code_ready.emit(code)
	_status_label.text = "Selected code sent to Executor."


func _on_browser_error(message: String) -> void:
	_status_label.text = "Browser error: " + message


func _on_settings_pressed() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "AI Executor Browser Settings"

	var vbox := VBoxContainer.new()

	var url_label := Label.new()
	url_label.text = "Start URL:"
	vbox.add_child(url_label)

	var url_edit := LineEdit.new()
	url_edit.text = AIExecutorBrowserSettings.get_start_url()
	url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(url_edit)

	var confirm_check := CheckBox.new()
	confirm_check.text = "Confirm potentially dangerous operations"
	confirm_check.button_pressed = AIExecutorBrowserSettings.get_confirm_dangerous()
	vbox.add_child(confirm_check)

	dialog.add_child(vbox)

	dialog.confirmed.connect(func() -> void:
		AIExecutorBrowserSettings.set_start_url(url_edit.text.strip_edges())
		AIExecutorBrowserSettings.set_confirm_dangerous(confirm_check.button_pressed)
		_status_label.text = "Settings saved."
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 200))