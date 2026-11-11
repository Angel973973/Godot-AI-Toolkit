@tool
class_name GMeshValidator

const MAX_NODES := 200
const VALID_TYPES := ["Node3D", "MeshInstance3D"]
const VALID_KINDS := ["box", "sphere", "cylinder", "capsule", "plane", "torus", "prism", "quad"]
const VALID_KEYS := ["id", "type", "name", "transform", "children", "mesh", "material"]

static func validate(json_string: String, custom_max_nodes: int = MAX_NODES) -> Dictionary:
	var errors: PackedStringArray = []
	var data = JSON.parse_string(json_string)
	
	if data == null:
		return { "ok": false, "errors": ["Невалидный JSON. Проверьте синтаксис."], "data": {} }
	
	if not data is Dictionary:
		return { "ok": false, "errors": ["Корневой элемент должен быть объектом (Dictionary)."], "data": {} }
		
	if data.has("error"):
		var err = data["error"]
		var msg = "Ошибка от ИИ: " + str(err.get("message", "Неизвестно"))
		if err.has("questions"):
			msg += "\nУточнения: " + str(err["questions"])
		return { "ok": false, "errors": [msg], "data": {} }
		
	if not data.has("version") or str(data["version"]) != "1.0":
		errors.append("Отсутствует или неверная версия (должна быть '1.0').")
		return { "ok": false, "errors": errors, "data": {} }
		
	if not data.has("root") or not data["root"] is Dictionary:
		errors.append("Отсутствует корневой узел 'root'.")
		return { "ok": false, "errors": errors, "data": {} }

	var node_count := [0]
	var used_ids := {}
	_validate_node(data["root"], errors, node_count, used_ids, custom_max_nodes)
	
	return { "ok": errors.is_empty(), "errors": errors, "data": data if errors.is_empty() else {} }

static func _validate_node(node: Dictionary, errors: PackedStringArray, node_count: Array, used_ids: Dictionary, max_nodes: int) -> void:
	node_count[0] += 1
	if node_count[0] > max_nodes:
		errors.append("Превышен лимит узлов (максимум %d)." % max_nodes)
		return

	for key in node.keys():
		if key not in VALID_KEYS:
			errors.append("Неизвестный ключ узла: '%s'." % key)

	if not node.has("id") or not node["id"] is String or node["id"].is_empty():
		errors.append("Узел должен иметь непустой строковый 'id'.")
	else:
		if used_ids.has(node["id"]):
			errors.append("Дублирующийся id узла: '%s'." % node["id"])
		used_ids[node["id"]] = true

	if not node.has("type") or node["type"] not in VALID_TYPES:
		errors.append("Неверный или отсутствующий 'type' у узла '%s'. Разрешено: %s" % [node.get("id", "?"), VALID_TYPES])
		
	if node.has("transform"):
		_validate_transform(node["transform"], node.get("id", "?"), errors)

	if node.has("mesh"):
		if node.get("type") != "MeshInstance3D":
			errors.append("Узел '%s' имеет 'mesh', но type не MeshInstance3D." % node.get("id", "?"))
		_validate_mesh(node["mesh"], node.get("id", "?"), errors)

	if node.has("material"):
		_validate_material(node["material"], node.get("id", "?"), errors)

	if node.has("children"):
		if not node["children"] is Array:
			errors.append("'children' узла '%s' должен быть массивом." % node.get("id", "?"))
		else:
			for child in node["children"]:
				if child is Dictionary:
					_validate_node(child, errors, node_count, used_ids, max_nodes)
				else:
					errors.append("Дочерний узел в '%s' должен быть объектом." % node.get("id", "?"))

static func _validate_transform(tr: Dictionary, id: String, errors: PackedStringArray) -> void:
	if not tr is Dictionary:
		errors.append("Transform узла '%s' должен быть объектом." % id)
		return
	for key in ["position", "rotation_deg", "scale"]:
		if tr.has(key):
			var v = tr[key]
			if not v is Array or v.size() != 3:
				errors.append("Transform.%s узла '%s' должен быть массивом из 3 чисел." % [key, id])
			else:
				for num in v:
					if not (num is float or num is int) or is_nan(num) or is_inf(num):
						errors.append("Transform.%s узла '%s' содержит недопустимое число." % [key, id])

static func _validate_mesh(mesh: Dictionary, id: String, errors: PackedStringArray) -> void:
	if not mesh.has("kind") or mesh["kind"] not in VALID_KINDS:
		errors.append("Неверный или отсутствующий 'kind' у mesh узла '%s'. Разрешено: %s" % [id, VALID_KINDS])
	if mesh.has("params") and not mesh["params"] is Dictionary:
		errors.append("'params' у mesh узла '%s' должен быть объектом." % id)

static func _validate_material(mat: Dictionary, id: String, errors: PackedStringArray) -> void:
	if mat.has("albedo"):
		var c = str(mat["albedo"])
		var regex = RegEx.new()
		regex.compile("^#([A-Fa-f0-9]{6})$")
		if regex.search(c) == null:
			errors.append("Цвет albedo узла '%s' должен быть в формате #RRGGBB." % id)
			
	for key in ["metallic", "roughness", "emission_energy"]:
		if mat.has(key):
			var val = mat[key]
			if not (val is float or val is int) or val < 0.0 or val > 1.0:
				errors.append("Material.%s узла '%s' должен быть числом в диапазоне 0..1." % [key, id])
