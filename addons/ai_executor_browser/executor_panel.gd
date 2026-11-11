@tool
extends VBoxContainer

const DANGEROUS_PATTERNS := [
	"OS.execute",
	"OS.shell_open",
	"DirAccess.remove",
	"DirAccess.rename",
	"FileAccess.open",
	"ResourceSaver.save",
	"ProjectSettings.save",
	"get_tree().quit",
	"queue_free",
	"free()",
]

var _code_edit: TextEdit
var _output_log: RichTextLabel


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var toolbar := HBoxContainer.new()

	var execute_btn := Button.new()
	execute_btn.text = "Execute"
	execute_btn.pressed.connect(_on_execute_pressed)
	toolbar.add_child(execute_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear_pressed)
	toolbar.add_child(clear_btn)

	add_child(toolbar)

	_code_edit = TextEdit.new()
	_code_edit.name = "CodeEdit"
	_code_edit.placeholder_text = "Paste AI-generated GDScript here. Plain statements are wrapped in EditorScript._run()."
	_code_edit.custom_minimum_size = Vector2(0, 180)
	_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_code_edit)

	_output_log = RichTextLabel.new()
	_output_log.bbcode_enabled = true
	_output_log.scroll_following = true
	_output_log.custom_minimum_size = Vector2(0, 140)
	_output_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_output_log)


func set_code(code: String) -> void:
	if _code_edit == null:
		_code_edit = find_child("CodeEdit", true, false) as TextEdit
	if _code_edit != null:
		_code_edit.text = code
		_code_edit.grab_focus()


func _on_clear_pressed() -> void:
	if _output_log != null:
		_output_log.clear()


func _on_execute_pressed() -> void:
	var code := _code_edit.text.strip_edges()
	if code.is_empty():
		_log("Nothing to execute.", "yellow")
		return

	var dangers := _find_dangers(code)
	if not dangers.is_empty() and AIExecutorBrowserSettings.get_confirm_dangerous():
		_show_confirmation_dialog(code, dangers)
	else:
		_execute_code(code)


func _find_dangers(code: String) -> PackedStringArray:
	var found := PackedStringArray()
	var lower := code.to_lower()
	for pattern in DANGEROUS_PATTERNS:
		if lower.contains(pattern.to_lower()):
			found.append(pattern)
	return found


func _show_confirmation_dialog(code: String, dangers: PackedStringArray) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Confirm execution"
	dialog.dialog_text = "The code contains potentially dangerous operations:\n\n%s\n\nExecute anyway?" % ", ".join(dangers)
	dialog.confirmed.connect(func() -> void:
		dialog.queue_free()
		_execute_code(code)
	)
	dialog.canceled.connect(func() -> void:
		_log("Execution cancelled by user.", "yellow")
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(540, 220))


func _prepare_source(code: String) -> String:
	var trimmed := code.strip_edges()

	var extends_regex := RegEx.new()
	extends_regex.compile("(?m)^\\s*extends\\s+")
	var has_extends := extends_regex.search(trimmed) != null

	var tool_regex := RegEx.new()
	tool_regex.compile("(?m)^\\s*@tool\\b")
	var has_tool := tool_regex.search(trimmed) != null

	if has_extends:
		return trimmed if has_tool else "@tool\n" + trimmed

	var body := trimmed
	if body.begins_with("@tool"):
		body = body.trim_prefix("@tool").strip_edges()

	var func_regex := RegEx.new()
	func_regex.compile("(?m)^func\\s+")
	if func_regex.search(body) != null:
		return "@tool\nextends EditorScript\n\n" + body

	return "@tool\nextends EditorScript\n\nfunc _run():\n" + body.indent("    ")


func _execute_code(code: String) -> void:
	var source := _prepare_source(code)
	if source.is_empty():
		_log("Nothing to execute.", "yellow")
		return

	var run_regex := RegEx.new()
	run_regex.compile("(?m)^func\\s+_run\\s*\\(")
	if run_regex.search(source) == null:
		_log("Error: the script does not define _run(). Add 'func _run():' or provide plain statements.", "red")
		return

	var script := GDScript.new()
	script.source_code = source
	var err := script.reload()
	if err != OK:
		_log("Compilation failed (error %d). See the Output panel for parse errors." % err, "red")
		return

	if not script.can_instantiate():
		_log("Error: the script cannot be instantiated. Make sure it extends EditorScript.", "red")
		return

	var instance: Variant = script.new()
	if instance == null:
		_log("Error: failed to create a script instance.", "red")
		return

	if not instance is EditorScript:
		_log("Error: the script does not extend EditorScript. Use 'extends EditorScript' or provide plain statements.", "red")
		return

	_log("Execution started...", "cyan")
	var result: Variant = instance.call("_run")
	if result != null:
		_log("Return value: %s" % str(result), "green")
	_log("Execution finished.", "green")
	_log("Note: print() output is sent to the Godot Output panel, not this log.", "gray")


func _log(message: String, color: String = "white") -> void:
	if _output_log == null:
		return
	var safe := message.replace("[", "[lb]")
	_output_log.append_text("[color=%s]%s[/color]\n" % [color, safe])