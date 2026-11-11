@tool
extends VBoxContainer

signal load_to_editor(json_text: String)

var _grid: GridContainer

func _ready() -> void:
	_setup_ui()
	refresh_list()

func _setup_ui() -> void:
	var top_bar = HFlowContainer.new()
	
	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(refresh_list)
	top_bar.add_child(refresh_btn)

	var clear_btn = Button.new()
	clear_btn.text = "Clear All"
	clear_btn.pressed.connect(_on_clear_all)
	top_bar.add_child(clear_btn)
	add_child(top_bar)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

func refresh_list() -> void:
	if not is_instance_valid(_grid):
		return
	for child in _grid.get_children():
		child.queue_free()
	
	var index = TextureHistoryStore.load_index()
	for entry in index:
		_create_item(entry)

func _create_item(entry: Dictionary) -> void:
	var vbox = VBoxContainer.new()
	
	var btn = TextureButton.new()
	btn.custom_minimum_size = Vector2(64, 64)
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	
	var thumb_path = entry.get("png_path", "")
	if FileAccess.file_exists(thumb_path):
		var img = Image.load_from_file(thumb_path)
		if img:
			btn.texture_normal = ImageTexture.create_from_image(img)
			
	btn.tooltip_text = "Name: %s\nDate: %s" % [
		entry.get("name", "?"), 
		entry.get("created_at", "?")
	]
	vbox.add_child(btn)
	
	var actions = HFlowContainer.new()
	actions.alignment = FlowContainer.ALIGNMENT_CENTER
	
	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.tooltip_text = "Вставить JSON в редактор текстур"
	load_btn.pressed.connect(func(): _on_load(entry["json"]))
	actions.add_child(load_btn)
	
	var del_btn = Button.new()
	del_btn.text = "Del"
	del_btn.tooltip_text = "Удалить"
	del_btn.pressed.connect(func(): _on_delete(entry["id"]))
	actions.add_child(del_btn)

	vbox.add_child(actions)
	_grid.add_child(vbox)

func _on_load(json_text: String) -> void:
	load_to_editor.emit(json_text)

func _on_delete(id: String) -> void:
	TextureHistoryStore.delete_entry(id)
	refresh_list()

func _on_clear_all() -> void:
	TextureHistoryStore.clear_all()
	refresh_list()
