@tool
class_name GMeshTexValidator

const MAX_SIZE := 2048
const MAX_LAYERS := 100
const VALID_OPS := ["fill", "noise", "gradient", "checker", "stripes", "brick", "voronoi", "blend"]
const VALID_KEYS := ["version", "size", "seed", "layers", "tiling", "filter", "mipmaps"]

static func validate(json_string: String) -> Dictionary:
	var errors: PackedStringArray = []
	var data = JSON.parse_string(json_string)
	
	if data == null:
		return { "ok": false, "errors": ["Невалидный JSON. Проверьте синтаксис."], "data": {} }
	
	if not data is Dictionary:
		return { "ok": false, "errors": ["Корневой элемент должен быть объектом."], "data": {} }
		
	if not data.has("version") or str(data["version"]) != "1.0":
		errors.append("Версия должна быть '1.0'.")
		
	if not data.has("size") or not data["size"] is Array or data["size"].size() != 2:
		errors.append("Поле 'size' должно быть массивом из 2 чисел [width, height].")
	else:
		var w = data["size"][0]
		var h = data["size"][1]
		if not (w is int or w is float) or not (h is int or h is float):
			errors.append("Размеры 'size' должны быть числами.")
		elif w < 16 or w > MAX_SIZE or h < 16 or h > MAX_SIZE:
			errors.append("Размеры 'size' должны быть от 16 до %d." % MAX_SIZE)

	if not data.has("layers") or not data["layers"] is Array:
		errors.append("Поле 'layers' должно быть массивом.")
	elif data["layers"].size() > MAX_LAYERS:
		errors.append("Превышен лимит слоев (максимум %d)." % MAX_LAYERS)
	else:
		for i in range(data["layers"].size()):
			var layer = data["layers"][i]
			if not layer is Dictionary:
				errors.append("Слой %d должен быть объектом." % i)
				continue
			if not layer.has("op") or layer["op"] not in VALID_OPS:
				errors.append("Слой %d имеет неверный 'op'. Разрешено: %s" % [i, VALID_OPS])
			else:
				_validate_layer(layer, i, errors)

	return { "ok": errors.is_empty(), "errors": errors, "data": data if errors.is_empty() else {} }

static func _validate_layer(layer: Dictionary, index: int, errors: PackedStringArray) -> void:
	var op = layer["op"]
	
	if op == "fill" and layer.has("color") and not _is_valid_color(layer["color"]):
		errors.append("Слой %d (fill): неверный формат цвета." % index)
		
	if op == "blend":
		if layer.has("opacity") and (not (layer["opacity"] is float or layer["opacity"] is int) or layer["opacity"] < 0 or layer["opacity"] > 1):
			errors.append("Слой %d (blend): opacity должен быть от 0 до 1." % index)
			
	if op in ["noise", "checker", "stripes", "brick", "voronoi"] and layer.has("colors"):
		if not layer["colors"] is Array or layer["colors"].size() < 2:
			errors.append("Слой %d (%s): 'colors' должен быть массивом из минимум 2 цветов." % [index, op])
		else:
			for c in layer["colors"]:
				if not _is_valid_color(c):
					errors.append("Слой %d (%s): неверный формат цвета." % [index, op])
					
	if op == "gradient" and layer.has("stops"):
		if not layer["stops"] is Array or layer["stops"].size() < 2:
			errors.append("Слой %d (gradient): 'stops' должен быть массивом из минимум 2 точек." % index)

static func _is_valid_color(c: Variant) -> bool:
	if not c is String: return false
	var regex = RegEx.new()
	regex.compile("^#([A-Fa-f0-9]{6})$")
	return regex.search(c) != null
