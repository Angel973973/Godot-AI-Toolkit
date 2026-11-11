@tool
extends EditorPlugin

const DOCK_SCENE: PackedScene = preload("res://addons/ai_executor_browser/ai_dock.tscn")
const MODEL_DOCK_SCENE: PackedScene = preload("res://addons/ai_executor_browser/ui/model_from_ai_dock.tscn")

var _dock: Control
var _model_dock: Control

func _enter_tree() -> void:
	_dock = DOCK_SCENE.instantiate() as Control
	if _dock != null:
		_dock.name = "Godot AI Toolkit"
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _dock)

	_model_dock = MODEL_DOCK_SCENE.instantiate() as Control
	if _model_dock != null:
		_model_dock.name = "Model from AI"
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _model_dock)

func _exit_tree() -> void:
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.queue_free()
	_dock = null
	
	if is_instance_valid(_model_dock):
		remove_control_from_docks(_model_dock)
		_model_dock.queue_free()
	_model_dock = null
