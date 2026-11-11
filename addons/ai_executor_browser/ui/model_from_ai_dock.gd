@tool
extends VBoxContainer

const HISTORY_PANEL_SCENE: PackedScene = preload("res://addons/ai_executor_browser/ui/history_panel.tscn")
const TEXTURE_PANEL_SCENE: PackedScene = preload("res://addons/ai_executor_browser/ui/texture_panel.tscn")
const PROMPT_HELPER_SCENE: PackedScene = preload("res://addons/ai_executor_browser/ui/prompt_helper.tscn")
const TEXTURE_HISTORY_SCENE: PackedScene = preload("res://addons/ai_executor_browser/ui/texture_history_panel.tscn")

var _tabs: TabContainer
var _text_edit: TextEdit
var _log: RichTextLabel
var _status: Label
var _max_nodes_spin: SpinBox
var _history_panel: Control
var _texture_panel: Control
var _prompt_helper: Control
var _texture_history_panel: Control

var _obj_dialog: FileDialog
var _tscn_dialog: FileDialog
var _last_built_node: Node3D

func _ready() -> void:
	_setup_ui()
	_setup_dialogs()

func _setup_dialogs() -> void:
	_obj_dialog = FileDialog.new()
	_obj_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_obj_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_obj_dialog.add_filter("*.obj", "Wavefront OBJ")
	_obj_dialog.file_selected.connect(_on_obj_path_selected)
	add_child(_obj_dialog)
	
	_tscn_dialog = FileDialog.new()
	_tscn_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_tscn_dialog.access = FileDialog.ACCESS_RESOURCES
	_tscn_dialog.add_filter("*.tscn", "Godot Scene")
	_tscn_dialog.file_selected.connect(_on_tscn_path_selected)
	add_child(_tscn_dialog)

func _setup_ui() -> void:
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)

	var build_tab = VBoxContainer.new()
	build_tab.name = "Build"
	_tabs.add_child(build_tab)

	var hbox = HFlowContainer.new()
	build_tab.add_child(hbox)

	var validate_btn = Button.new()
	validate_btn.text = "Validate"
	validate_btn.pressed.connect(_on_validate_pressed)
	hbox.add_child(validate_btn)

	var build_btn = Button.new()
	build_btn.text = "Build"
	build_btn.pressed.connect(_on_build_pressed)
	hbox.add_child(build_btn)

	var export_obj_btn = Button.new()
	export_obj_btn.text = "Export OBJ"
	export_obj_btn.pressed.connect(_on_export_obj_pressed)
	hbox.add_child(export_obj_btn)
	
	var save_tscn_btn = Button.new()
	save_tscn_btn.text = "Save .tscn"
	save_tscn_btn.pressed.connect(_on_save_tscn_pressed)
	hbox.add_child(save_tscn_btn)
	
	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear_pressed)
	hbox.add_child(clear_btn)

	hbox.add_child(VSeparator.new())
	
	var max_label = Label.new()
	max_label.text = "Max Nodes:"
	hbox.add_child(max_label)

	_max_nodes_spin = SpinBox.new()
	_max_nodes_spin.min_value = 1
	_max_nodes_spin.max_value = 5000
	_max_nodes_spin.value = 200
	_max_nodes_spin.step = 10
	hbox.add_child(_max_nodes_spin)

	_text_edit = TextEdit.new()
	_text_edit.placeholder_text = "Вставьте сюда JSON (GMesh DSL v1)..."
	_text_edit.custom_minimum_size = Vector2(0, 100)
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_tab.add_child(_text_edit)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0, 60)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_tab.add_child(_log)

	_status = Label.new()
	_status.text = "Готов к работе"
	build_tab.add_child(_status)

	_history_panel = HISTORY_PANEL_SCENE.instantiate()
	_history_panel.name = "History"
	_history_panel.load_to_editor.connect(_on_history_load)
	_history_panel.rebuild_in_scene.connect(_on_history_rebuild)
	_tabs.add_child(_history_panel)
	
	_texture_panel = TEXTURE_PANEL_SCENE.instantiate()
	_texture_panel.name = "Texture AI"
	_tabs.add_child(_texture_panel)
	
	_texture_history_panel = TEXTURE_HISTORY_SCENE.instantiate()
	_texture_history_panel.name = "Tex History"
	_texture_history_panel.load_to_editor.connect(_on_texture_history_load)
	_tabs.add_child(_texture_history_panel)
	
	_prompt_helper = PROMPT_HELPER_SCENE.instantiate()
	_prompt_helper.name = "Промпты"
	_tabs.add_child(_prompt_helper)

func _on_history_load(json_text: String) -> void:
	if is_instance_valid(_text_edit):
		_text_edit.set_text(json_text)
	_tabs.current_tab = 0
	_status.text = "Загружено из истории."

func _on_history_rebuild(json_text: String) -> void:
	if is_instance_valid(_text_edit):
		_text_edit.set_text(json_text)
	_tabs.current_tab = 0
	_on_build_pressed()
	
func _on_texture_history_load(json_text: String) -> void:
	_texture_panel.set_json(json_text)
	_tabs.current_tab = 2
	_texture_panel.set("_status", "JSON текстуры загружен из истории.")

func _on_validate_pressed() -> void:
	_log.clear()
	var result = GMeshValidator.validate(_text_edit.text, int(_max_nodes_spin.value))
	if result.ok:
		_log.append_text("[color=green]Успех! JSON валиден.[/color]\n")
		_status.text = "Валидация пройдена."
	else:
		for err in result.errors:
			_log.append_text("[color=red]Ошибка: %s[/color]\n" % err)
		_status.text = "Ошибки валидации."

func _build_current() -> Node3D:
	_log.clear()
	var result = GMeshValidator.validate(_text_edit.text, int(_max_nodes_spin.value))
	if not result.ok:
		for err in result.errors:
			_log.append_text("[color=red]Ошибка: %s[/color]\n" % err)
		_status.text = "Сборка отменена."
		return null
		
	var node = GMeshBuilder.build_from_data(result.data)
	if node:
		_last_built_node = node
		_log.append_text("[color=green]Модель '%s' создана![/color]\n" % node.name)
		_status.text = "Построено."
		_save_to_history(result.data, _text_edit.text, node)
		return node
	else:
		_log.append_text("[color=red]Ошибка при создании нодов.[/color]\n")
		_status.text = "Ошибка сборки."
		return null

func _on_build_pressed() -> void:
	_build_current()

func _on_export_obj_pressed() -> void:
	var node = _build_current()
	if node:
		_obj_dialog.popup_centered_ratio(0.6)

func _on_save_tscn_pressed() -> void:
	var node = _build_current()
	if node:
		_tscn_dialog.popup_centered_ratio(0.6)

func _on_clear_pressed() -> void:
	if is_instance_valid(_text_edit):
		_text_edit.set_text("")
	_log.clear()
	_status.text = "Очищено."

func _on_obj_path_selected(path: String) -> void:
	if is_instance_valid(_last_built_node):
		GMeshObjExporter.export(_last_built_node, path)
		_status.text = "OBJ сохранен."

func _on_tscn_path_selected(path: String) -> void:
	if is_instance_valid(_last_built_node):
		var copy = _last_built_node.duplicate() as Node3D
		copy.owner = null
		_set_owner_recursive(copy, copy)
		
		for child in copy.find_children("*", "MeshInstance3D", true, false):
			var mi = child as MeshInstance3D
			if mi.material_override:
				mi.material_override = mi.material_override.duplicate()
			if mi.mesh:
				for i in range(mi.mesh.get_surface_count()):
					var mat = mi.mesh.surface_get_material(i)
					if mat:
						mi.mesh.surface_set_material(i, mat.duplicate())
				
		var packed = PackedScene.new()
		packed.pack(copy)
		var err = ResourceSaver.save(packed, path)
		copy.queue_free()
		
		if err == OK:
			_status.text = "TSCN сохранен."

func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)

func _save_to_history(data: Dictionary, json_text: String, node: Node3D) -> void:
	var model_name = data["root"].get("name", "Model")
	var node_count = _count_nodes(node)
	
	var img = await ModelThumbnailRenderer.render_to_image(node)
	ModelHistoryStore.add_entry(model_name, node_count, json_text, img)
	
	if is_instance_valid(_history_panel):
		_history_panel.refresh_list()

func _count_nodes(node: Node) -> int:
	var count = 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
