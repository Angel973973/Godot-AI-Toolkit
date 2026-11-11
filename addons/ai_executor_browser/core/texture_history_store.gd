@tool
class_name TextureHistoryStore
extends RefCounted

const HISTORY_DIR := "user://ai_executor_browser/textures_history/"
const INDEX_FILE := HISTORY_DIR + "index.json"
const MAX_HISTORY := 50

static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(HISTORY_DIR):
		DirAccess.make_dir_recursive_absolute(HISTORY_DIR)

static func load_index() -> Array:
	_ensure_dir()
	if not FileAccess.file_exists(INDEX_FILE):
		return []
	var file = FileAccess.open(INDEX_FILE, FileAccess.READ)
	if not file:
		return []
	var text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data is Array:
		return data
	return []

static func save_index(index: Array) -> void:
	_ensure_dir()
	var file = FileAccess.open(INDEX_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(index, "\t"))
		file.close()

static func add_entry(name: String, json_content: String, thumb_image: Image) -> void:
	_ensure_dir()
	var id = str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)
	var created_at = Time.get_datetime_string_from_system(true)
	
	var png_path = HISTORY_DIR + id + ".png"
	
	if thumb_image:
		thumb_image.save_png(png_path)

	var index = load_index()
	index.push_front({
		"id": id,
		"name": name,
		"created_at": created_at,
		"json": json_content,
		"png_path": png_path
	})

	while index.size() > MAX_HISTORY:
		var old = index.pop_back()
		_delete_file(old)

	save_index(index)

static func _delete_file(entry: Dictionary) -> void:
	if entry.has("png_path") and FileAccess.file_exists(entry["png_path"]):
		DirAccess.remove_absolute(entry["png_path"])

static func delete_entry(id: String) -> void:
	var index = load_index()
	for i in range(index.size() - 1, -1, -1):
		if index[i].get("id") == id:
			_delete_file(index[i])
			index.remove_at(i)
			break
	save_index(index)

static func clear_all() -> void:
	var index = load_index()
	for entry in index:
		_delete_file(entry)
	save_index([])
