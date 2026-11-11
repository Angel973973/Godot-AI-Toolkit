@tool
extends VBoxContainer

var _model_prompt: String = """Ты — 3D-моделлер, который выдает данные строго в формате JSON (GMesh DSL v1). 
Твой ответ должен содержать ТОЛЬКО валидный JSON-объект без маркдауна и лишнего текста.

Формат:
{
  "version": "1.0",
  "meta": { "name": "Имя_модели", "description": "Описание", "warnings": [] },
  "root": {
	"id": "root",
	"type": "Node3D",
	"name": "ModelName",
	"transform": { "position": [0,0,0], "rotation_deg": [0,0,0], "scale": [1,1,1] },
	"children": [
      {
		"id": "уникальный_id",
		"type": "MeshInstance3D",
		"name": "Имя узла",
		"transform": { "position": [x,y,z], "rotation_deg": [x,y,z], "scale": [x,y,z] },
		"mesh": { "kind": "box|sphere|cylinder|capsule|plane|torus|prism|quad", "params": { ... } },
		"material": { "albedo": "#RRGGBB", "metallic": 0.0, "roughness": 0.5, "emission": "#000000", "emission_energy": 0.0 }
      }
    ]
  }
}

Правила для params:
- box: {"x": 1.0, "y": 1.0, "z": 1.0}
- sphere: {"radius": 0.5, "height": 1.0}
- cylinder: {"top_radius": 0.5, "bottom_radius": 0.5, "height": 1.0}
- capsule: {"radius": 0.5, "height": 1.0}
- plane: {"x": 1.0, "z": 1.0}
- torus: {"inner_radius": 0.5, "outer_radius": 1.0}
- prism: {"x": 1.0, "y": 1.0, "z": 1.0}
- quad: {"x": 1.0, "y": 1.0}

Правила для material:
- albedo: строго формат #RRGGBB (например #FF0000)
- metallic: от 0.0 до 1.0
- roughness: от 0.0 до 1.0

Сгенерируй 3D-модель: [ТВОЙ ЗАПРОС ЗДЕСЬ]"""

var _texture_prompt: String = """Ты — процедурный художник текстур. Выдавай ТОЛЬКО JSON (GMeshTex DSL v1) без лишнего текста.
Формат:
{
  "version": "1.0",
  "size": [512, 512],
  "layers": [
	{ "op": "fill", "color": "#RRGGBB" },
	{ "op": "blend", "mode": "mix", "opacity": 1.0 }
  ]
}
Доступные op:
- fill: color
- noise: scale, octaves, seed, colors
- gradient: direction (vertical|horizontal|radial), stops [[0.0,"#hex"],[1.0,"#hex"]]
- checker: cells [x,y], colors
- stripes: direction (vertical|horizontal|diagonal), width, colors
- brick: rows, cols, mortar, colors
- voronoi: cells, seed, colors
- blend: mode (mix|multiply|add|overlay), opacity

Помни, что слои применяются сверху вниз. Чтобы наложить слой, нужно использовать blend. Если blend не вызван, слой перезапишет предыдущий. 
Сгенерируй текстуру для: [ТВОЙ ЗАПРОС ЗДЕСЬ]"""

var _executor_prompt: String = """Ты — Senior Godot 4 Developer. Напиши GDScript код, который будет выполнен в контексте редактора Godot (EditorScript).
Выдавай ТОЛЬКО код в блоке ```gdscript ... ```, без лишних объяснений.

Правила:
1. Код должен начинаться с `@tool` и `extends EditorScript`.
2. Вся логика должна быть внутри `func _run():`.
3. Используй `EditorInterface.get_edited_scene_root()` для доступа к текущей сцене.
4. Для создания/удаления узлов используй `EditorInterface.get_editor_undo_redo()`, чтобы работал Ctrl+Z (Undo/Redo).
5. Если создаешь узлы, назначай им `owner` (корень сцены), чтобы они сохранялись.
6. Не используй `eval()`, `Expression` или загрузку внешних файлов без явной необходимости.

Задача: [ОПИШИ ЗДЕСЬ, ЧТО НУЖНО СДЕЛАТЬ]"""

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)

	# 1. Вкладка Промпт для Модели
	var model_vbox = VBoxContainer.new()
	model_vbox.name = "3D Модель"
	tabs.add_child(model_vbox)

	var model_btn = Button.new()
	model_btn.text = "Скопировать промпт для 3D-модели"
	model_btn.pressed.connect(func(): _copy_to_clipboard(_model_prompt))
	model_vbox.add_child(model_btn)

	var model_edit = TextEdit.new()
	model_edit.text = _model_prompt
	model_edit.editable = false
	model_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	model_vbox.add_child(model_edit)

	# 2. Вкладка Промпт для Текстуры
	var tex_vbox = VBoxContainer.new()
	tex_vbox.name = "Текстура"
	tabs.add_child(tex_vbox)

	var tex_btn = Button.new()
	tex_btn.text = "Скопировать промпт для Текстуры"
	tex_btn.pressed.connect(func(): _copy_to_clipboard(_texture_prompt))
	tex_vbox.add_child(tex_btn)

	var tex_edit = TextEdit.new()
	tex_edit.text = _texture_prompt
	tex_edit.editable = false
	tex_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tex_vbox.add_child(tex_edit)

	# 3. Вкладка Промпт для Выполнения кода (Executor)
	var exec_vbox = VBoxContainer.new()
	exec_vbox.name = "Выполнение кода"
	tabs.add_child(exec_vbox)

	var exec_btn = Button.new()
	exec_btn.text = "Скопировать промпт для Executor"
	exec_btn.pressed.connect(func(): _copy_to_clipboard(_executor_prompt))
	exec_vbox.add_child(exec_btn)

	var exec_edit = TextEdit.new()
	exec_edit.text = _executor_prompt
	exec_edit.editable = false
	exec_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	exec_vbox.add_child(exec_edit)

func _copy_to_clipboard(text: String) -> void:
	DisplayServer.clipboard_set(text)
	print("Промпт скопирован в буфер обмена!")
