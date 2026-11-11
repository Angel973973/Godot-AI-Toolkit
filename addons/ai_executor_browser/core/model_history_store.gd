@tool
class_name ModelHistoryStore
extends RefCounted

const HISTORY_DIR := "user://ai_executor_browser/history/"
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

static func add_entry(model_name: String, node_count: int, json_content: String, thumb_image: Image) -> void:
	_ensure_dir()
	var id = str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)
	var created_at = Time.get_datetime_string_from_system(true)
	
	var json_path = HISTORY_DIR + id + ".json"
	var thumb_path = HISTORY_DIR + id + ".png"

	var file = FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		file.store_string(json_content)
		file.close()

	if thumb_image:
		thumb_image.save_png(thumb_path)

	var index = load_index()
	index.push_front({
		"id": id,
		"name": model_name,
		"created_at": created_at,
		"node_count": node_count,
		"dsl_version": "1.0",
		"json_path": json_path,
		"thumb_path": thumb_path
	})

	while index.size() > MAX_HISTORY:
		var old = index.pop_back()
		_delete_files(old)

	save_index(index)

static func _delete_files(entry: Dictionary) -> void:
	if entry.has("json_path") and FileAccess.file_exists(entry["json_path"]):
		DirAccess.remove_absolute(entry["json_path"])
	if entry.has("thumb_path") and FileAccess.file_exists(entry["thumb_path"]):
		DirAccess.remove_absolute(entry["thumb_path"])

static func delete_entry(id: String) -> void:
	var index = load_index()
	for i in range(index.size() - 1, -1, -1):
		if index[i].get("id") == id:
			_delete_files(index[i])
			index.remove_at(i)
			break
	save_index(index)

static func clear_all() -> void:
	var index = load_index()
	for entry in index:
		_delete_files(entry)
	save_index([])
