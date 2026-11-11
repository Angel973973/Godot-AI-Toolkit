@tool
class_name GMeshBuilder

static func build_from_data(data: Dictionary) -> Node3D:
	var root_data = data["root"]
	var scene_root = EditorInterface.get_edited_scene_root()
	
	if not scene_root:
		printerr("Нет открытой сцены для добавления модели!")
		return null

	var ur = EditorInterface.get_editor_undo_redo()
	ur.create_action("Создать модель из AI: %s" % root_data.get("name", "Model"))

	var root_node = _create_node(root_data)
	
	ur.add_do_method(scene_root, "add_child", root_node)
	ur.add_do_method(root_node, "set_owner", scene_root)
	_apply_owner_recursive(root_node, scene_root, ur)
	
	ur.add_do_reference(root_node)
	ur.add_undo_method(scene_root, "remove_child", root_node)
	ur.commit_action()
	
	return root_node

static func _apply_owner_recursive(node: Node, owner: Node, ur: EditorUndoRedoManager) -> void:
	for child in node.get_children():
		ur.add_do_method(child, "set_owner", owner) # Исправлено: используем метод вместо свойства
		_apply_owner_recursive(child, owner, ur)

static func _create_node(node_data: Dictionary) -> Node3D:
	var node: Node3D
	
	if node_data.get("type") == "MeshInstance3D":
		node = MeshInstance3D.new()
		if node_data.has("mesh"):
			(node as MeshInstance3D).mesh = _create_mesh(node_data["mesh"])
		if node_data.has("material"):
			(node as MeshInstance3D).material_override = _create_material(node_data["material"])
	else:
		node = Node3D.new()

	node.name = node_data.get("name", node_data.get("id", "Node"))
	
	if node_data.has("transform"):
		var tr = node_data["transform"]
		if tr.has("position"):
			node.position = Vector3(tr["position"][0], tr["position"][1], tr["position"][2])
		if tr.has("rotation_deg"):
			node.rotation_degrees = Vector3(tr["rotation_deg"][0], tr["rotation_deg"][1], tr["rotation_deg"][2])
		if tr.has("scale"):
			node.scale = Vector3(tr["scale"][0], tr["scale"][1], tr["scale"][2])

	if node_data.has("children"):
		for child_data in node_data["children"]:
			var child = _create_node(child_data)
			node.add_child(child)
			
	return node

static func _create_mesh(mesh_data: Dictionary) -> Mesh:
	var kind = mesh_data.get("kind", "box")
	var params = mesh_data.get("params", {})
	var mesh: Mesh
	
	match kind:
		"box":
			var m = BoxMesh.new()
			m.size = Vector3(params.get("x", 1.0), params.get("y", 1.0), params.get("z", 1.0))
			mesh = m
		"sphere":
			var m = SphereMesh.new()
			m.radius = params.get("radius", 0.5)
			m.height = params.get("height", 1.0)
			mesh = m
		"cylinder":
			var m = CylinderMesh.new()
			m.top_radius = params.get("top_radius", 0.5)
			m.bottom_radius = params.get("bottom_radius", 0.5)
			m.height = params.get("height", 1.0)
			mesh = m
		"capsule":
			var m = CapsuleMesh.new()
			m.radius = params.get("radius", 0.5)
			m.height = params.get("height", 1.0)
			mesh = m
		"plane":
			var m = PlaneMesh.new()
			m.size = Vector2(params.get("x", 1.0), params.get("z", 1.0))
			mesh = m
		"torus":
			var m = TorusMesh.new()
			m.inner_radius = params.get("inner_radius", 0.5)
			m.outer_radius = params.get("outer_radius", 1.0)
			mesh = m
		"prism":
			var m = PrismMesh.new()
			m.size = Vector3(params.get("x", 1.0), params.get("y", 1.0), params.get("z", 1.0))
			mesh = m
		"quad":
			var m = QuadMesh.new()
			m.size = Vector2(params.get("x", 1.0), params.get("y", 1.0))
			mesh = m
		_:
			mesh = BoxMesh.new()
			
	return mesh

static func _create_material(mat_data: Dictionary) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	if mat_data.has("albedo"):
		mat.albedo_color = Color.from_string(mat_data["albedo"], Color.WHITE)
	if mat_data.has("metallic"):
		mat.metallic = mat_data["metallic"]
	if mat_data.has("roughness"):
		mat.roughness = mat_data["roughness"]
	if mat_data.has("emission"):
		mat.emission_enabled = true
		mat.emission = Color.from_string(mat_data["emission"], Color.BLACK)
	if mat_data.has("emission_energy"):
		mat.emission_energy_multiplier = mat_data["emission_energy"]
	return mat
