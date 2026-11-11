@tool
extends VBoxContainer

var _text_edit: TextEdit
var _log: RichTextLabel
var _status: Label
var _preview: TextureRect
var _preview_normal: TextureRect

var _original_img: Image
var _current_tex: ImageTexture
var _current_normal_tex: ImageTexture

var _slider_brightness: HSlider
var _slider_contrast: HSlider
var _slider_saturation: HSlider

var _slider_metallic: HSlider
var _slider_roughness: HSlider
var _color_tint: ColorPickerButton

var _spin_uv_x: SpinBox
var _spin_uv_y: SpinBox
var _spin_uv_off_x: SpinBox
var _spin_uv_off_y: SpinBox

var _slider_normal_strength: HSlider

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	var hbox_top = HFlowContainer.new()
	add_child(hbox_top)
	
	var bake_btn = Button.new()
	bake_btn.text = "Bake Texture"
	bake_btn.pressed.connect(_on_bake_pressed)
	hbox_top.add_child(bake_btn)
	
	var apply_btn = Button.new()
	apply_btn.text = "Apply to Selection"
	apply_btn.pressed.connect(_on_apply_pressed)
	hbox_top.add_child(apply_btn)
	
	var save_btn = Button.new()
	save_btn.text = "Save PNG..."
	save_btn.pressed.connect(_on_save_pressed)
	hbox_top.add_child(save_btn)
	
	var save_hist_btn = Button.new()
	save_hist_btn.text = "Save to History"
	save_hist_btn.pressed.connect(_on_save_history_pressed)
	hbox_top.add_child(save_hist_btn)

	var preview_hbox = HBoxContainer.new()
	add_child(preview_hbox)

	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(96, 96)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.tooltip_text = "Albedo (Цвет)"
	preview_hbox.add_child(_preview)

	_preview_normal = TextureRect.new()
	_preview_normal.custom_minimum_size = Vector2(96, 96)
	_preview_normal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_normal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_normal.tooltip_text = "Normal Map (Рельеф)"
	preview_hbox.add_child(_preview_normal)

	_text_edit = TextEdit.new()
	_text_edit.placeholder_text = "Вставьте JSON (GMeshTex DSL v1)..."
	_text_edit.custom_minimum_size = Vector2(0, 80)
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_text_edit)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var settings_box = VBoxContainer.new()
	settings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(settings_box)

	var lbl_img = Label.new()
	lbl_img.text = "--- Image Adjustments ---"
	settings_box.add_child(lbl_img)

	_slider_brightness = _create_slider_row(settings_box, "Brightness", -1.0, 1.0, 0.0)
	_slider_brightness.value_changed.connect(func(v): _update_preview_image())

	_slider_contrast = _create_slider_row(settings_box, "Contrast", 0.0, 2.0, 1.0)
	_slider_contrast.value_changed.connect(func(v): _update_preview_image())

	_slider_saturation = _create_slider_row(settings_box, "Saturation", 0.0, 2.0, 1.0)
	_slider_saturation.value_changed.connect(func(v): _update_preview_image())

	var lbl_mat = Label.new()
	lbl_mat.text = "--- Material Override ---"
	settings_box.add_child(lbl_mat)

	_slider_metallic = _create_slider_row(settings_box, "Metallic", 0.0, 1.0, 0.0)
	_slider_roughness = _create_slider_row(settings_box, "Roughness", 0.0, 1.0, 0.5)
	
	var tint_hbox = HBoxContainer.new()
	tint_hbox.add_child(Label.new())
	tint_hbox.get_child(0).text = "Tint Color:"
	_color_tint = ColorPickerButton.new()
	_color_tint.color = Color.WHITE
	_color_tint.custom_minimum_size = Vector2(50, 20)
	tint_hbox.add_child(_color_tint)
	settings_box.add_child(tint_hbox)

	var lbl_norm = Label.new()
	lbl_norm.text = "--- Normal Map ---"
	settings_box.add_child(lbl_norm)
	
	_slider_normal_strength = _create_slider_row(settings_box, "Strength", 0.0, 5.0, 2.0)
	_slider_normal_strength.value_changed.connect(func(v): _on_bake_pressed())

	var lbl_uv = Label.new()
	lbl_uv.text = "--- UV Transform ---"
	settings_box.add_child(lbl_uv)

	var uv_hbox1 = HBoxContainer.new()
	uv_hbox1.add_child(Label.new())
	uv_hbox1.get_child(0).text = "Scale X/Y:"
	_spin_uv_x = SpinBox.new()
	_spin_uv_x.step = 0.1
	_spin_uv_x.value = 1.0
	_spin_uv_y = SpinBox.new()
	_spin_uv_y.step = 0.1
	_spin_uv_y.value = 1.0
	uv_hbox1.add_child(_spin_uv_x)
	uv_hbox1.add_child(_spin_uv_y)
	settings_box.add_child(uv_hbox1)

	var uv_hbox2 = HBoxContainer.new()
	uv_hbox2.add_child(Label.new())
	uv_hbox2.get_child(0).text = "Offset X/Y:"
	_spin_uv_off_x = SpinBox.new()
	_spin_uv_off_x.step = 0.1
	_spin_uv_off_y = SpinBox.new()
	_spin_uv_off_y.step = 0.1
	uv_hbox2.add_child(_spin_uv_off_x)
	uv_hbox2.add_child(_spin_uv_off_y)
	settings_box.add_child(uv_hbox2)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.custom_minimum_size = Vector2(0, 40)
	add_child(_log)

	_status = Label.new()
	_status.text = "Готов к генерации."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

func set_json(json_text: String) -> void:
	# Безопасная установка текста (обход бага с gutter)
	if is_instance_valid(_text_edit):
		_text_edit.set_text(json_text)
		_status.text = "JSON загружен из истории."

func _create_slider_row(parent: Node, label_text: String, min_v: float, max_v: float, default_value: float) -> HSlider:
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 80
	hbox.add_child(lbl)
	
	var slider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.value = default_value
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(slider)
	
	parent.add_child(hbox)
	return slider

func _on_bake_pressed() -> void:
	if not _log: return
	_log.clear()
	var val = GMeshTexValidator.validate(_text_edit.text)
	if not val.ok:
		for err in val.errors:
			_log.append_text("[color=red]Ошибка: %s[/color]\n" % err)
		return
		
	_original_img = GMeshTexBaker.bake(val.data)
	_update_preview_image()
	_status.text = "Текстура сгенерирована."

func _update_preview_image() -> void:
	if not _original_img: return
	
	var img = _original_img.duplicate()
	if _slider_brightness.value != 0.0 or _slider_contrast.value != 1.0 or _slider_saturation.value != 1.0:
		img.adjust_bcs(_slider_brightness.value, _slider_contrast.value, _slider_saturation.value)
		
	_current_tex = ImageTexture.create_from_image(img)
	_preview.texture = _current_tex
	
	var strength = 2.0
	if is_instance_valid(_slider_normal_strength):
		strength = _slider_normal_strength.value
		
	var normal_img = GMeshTexBaker.generate_normal_map(img, strength)
	_current_normal_tex = ImageTexture.create_from_image(normal_img)
	_preview_normal.texture = _current_normal_tex

func _on_apply_pressed() -> void:
	if not _current_tex or not _current_normal_tex:
		_status.text = "Сначала нажмите Bake."
		return
		
	var selection = EditorInterface.get_selection().get_selected_nodes()
	if selection.is_empty():
		_status.text = "Выделите объект в сцене."
		return
		
	var ur = EditorInterface.get_editor_undo_redo()
	ur.create_action("Apply AI Texture with Normal")
	var applied = 0
	
	for node in selection:
		if node is Node3D and not node is MeshInstance3D:
			for child in node.find_children("*", "MeshInstance3D", true, false):
				_apply_all_settings_to_node(child, ur)
				applied += 1
		elif node is MeshInstance3D:
			_apply_all_settings_to_node(node, ur)
			applied += 1
			
	ur.commit_action()
	_status.text = "Применено к %d мешам." % applied

func _apply_all_settings_to_node(mi: MeshInstance3D, ur: EditorUndoRedoManager) -> void:
	var mat = mi.material_override
	if not mat is StandardMaterial3D:
		mat = StandardMaterial3D.new()
		ur.add_do_property(mi, "material_override", mat)
		
	ur.add_do_property(mat, "albedo_texture", _current_tex)
	ur.add_do_property(mat, "metallic", _slider_metallic.value)
	ur.add_do_property(mat, "roughness", _slider_roughness.value)
	ur.add_do_property(mat, "albedo_color", _color_tint.color)
	ur.add_do_property(mat, "uv1_scale", Vector3(_spin_uv_x.value, _spin_uv_y.value, 1.0))
	ur.add_do_property(mat, "uv1_offset", Vector3(_spin_uv_off_x.value, _spin_uv_off_y.value, 0.0))
	
	ur.add_do_property(mat, "normal_enabled", true)
	ur.add_do_property(mat, "normal_texture", _current_normal_tex)
	ur.add_do_property(mat, "normal_scale", 1.0)

func _on_save_pressed() -> void:
	if not _current_tex: return
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.add_filter("*.png", "PNG Image")
	dialog.file_selected.connect(func(path):
		var img = _current_tex.get_image()
		img.save_png(path)
		var norm_img = _current_normal_tex.get_image()
		norm_img.save_png(path.replace(".png", "_normal.png"))
		_status.text = "Сохранено (Цвет + Нормали)."
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)

func _on_save_history_pressed() -> void:
	if not _current_tex:
		_status.text = "Сначала нажмите Bake."
		return
		
	var name_dialog = AcceptDialog.new()
	name_dialog.title = "Save to History"
	
	var vbox = VBoxContainer.new()
	vbox.add_child(Label.new())
	vbox.get_child(0).text = "Texture Name:"
	var name_edit = LineEdit.new()
	name_edit.text = "Tex_" + str(Time.get_datetime_string_from_system()).replace(":", "-")
	vbox.add_child(name_edit)
	name_dialog.add_child(vbox)
	
	name_dialog.confirmed.connect(func():
		var img = _current_tex.get_image()
		TextureHistoryStore.add_entry(name_edit.text, _text_edit.text, img)
		_status.text = "Сохранено в историю."
		name_dialog.queue_free()
	)
	name_dialog.canceled.connect(func(): name_dialog.queue_free())
	add_child(name_dialog)
	name_dialog.popup_centered(Vector2i(400, 150))
