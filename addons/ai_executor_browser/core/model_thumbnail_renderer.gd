@tool
class_name ModelThumbnailRenderer
extends RefCounted

static func render_to_image(model_root: Node3D, size: int = 256) -> Image:
	var aabb = AABB()
	var has_bounds = false
	var meshes = []
	_find_meshes(model_root, meshes)

	for mi in meshes:
		var mesh_aabb = mi.get_aabb()
		if not has_bounds:
			aabb = mesh_aabb
			has_bounds = true
		else:
			aabb = aabb.merge(mesh_aabb)

	if not has_bounds:
		aabb = AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))

	var scene = EditorInterface.get_edited_scene_root()
	if not scene:
		return Image.new()
		
	var sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(size, size)
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.own_world_3d = true

	var env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.ambient_light_energy = 1.0
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	sub_viewport.add_child(world_env)

	var cam = Camera3D.new()
	sub_viewport.add_child(cam)
	
	var center = aabb.get_center()
	var radius = aabb.size.length() * 0.5
	if radius < 0.1:
		radius = 1.0
	var cam_dist = radius / tan(deg_to_rad(cam.fov * 0.5)) * 1.5
	
	var dir = Vector3(1, 1, 1).normalized()
	cam.position = center + dir * cam_dist
	cam.look_at_from_position(cam.position, center, Vector3.UP) # Исправлено: look_at_from_position
	cam.current = true

	var light = DirectionalLight3D.new()
	light.light_energy = 1.2
	light.rotation_degrees = Vector3(-45, 45, 0)
	sub_viewport.add_child(light)

	var duplicate = model_root.duplicate()
	sub_viewport.add_child(duplicate)

	scene.add_child(sub_viewport)
	
	await sub_viewport.get_tree().process_frame
	await sub_viewport.get_tree().process_frame

	var tex = sub_viewport.get_texture()
	var img = tex.get_image()
	
	sub_viewport.queue_free()
	return img

static func _find_meshes(node: Node, arr: Array) -> void:
	if node is MeshInstance3D:
		arr.append(node)
	for child in node.get_children():
		_find_meshes(child, arr)
