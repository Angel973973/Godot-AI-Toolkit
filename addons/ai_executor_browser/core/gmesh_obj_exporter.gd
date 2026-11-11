@tool
class_name GMeshObjExporter

static func export(root_node: Node3D, save_path: String) -> void:
	var obj_file = FileAccess.open(save_path, FileAccess.WRITE)
	if not obj_file:
		printerr("Не удалось создать файл OBJ: ", save_path)
		return
		
	var mtl_path = save_path.get_basename() + ".mtl"
	obj_file.store_line("mtllib " + mtl_path.get_file())
	
	var v_offset = 1
	var vn_offset = 1
	var vt_offset = 1
	var materials = {}
	var mtl_lines = PackedStringArray()
	
	_process_node(root_node, obj_file, materials, mtl_lines, [v_offset, vn_offset, vt_offset])
	obj_file.close()
	
	var mtl_file = FileAccess.open(mtl_path, FileAccess.WRITE)
	if mtl_file:
		for line in mtl_lines:
			mtl_file.store_line(line)
		mtl_file.close()

static func _process_node(node: Node, obj_file: FileAccess, materials: Dictionary, mtl_lines: PackedStringArray, offsets: Array) -> void:
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		var mesh = mi.mesh
		if mesh:
			obj_file.store_line("o " + mi.name) # Группируем объекты по именам
			var mat_name = _get_material_name(mi, materials, mtl_lines)
			obj_file.store_line("usemtl " + mat_name)
			
			var g_transform = mi.global_transform
			var normal_matrix = g_transform.basis.inverse().transposed()
			
			for surf_idx in range(mesh.get_surface_count()):
				var arrays = mesh.surface_get_arrays(surf_idx)
				var verts = arrays[Mesh.ARRAY_VERTEX]
				var normals = arrays[Mesh.ARRAY_NORMAL]
				var uvs = arrays[Mesh.ARRAY_TEX_UV]
				var indices = arrays[Mesh.ARRAY_INDEX]
				
				if verts == null:
					continue
				
				var v_start = offsets[0]
				var vn_start = offsets[1]
				var vt_start = offsets[2]
				
				for v in verts:
					var gv = g_transform * v
					obj_file.store_line("v %f %f %f" % [gv.x, gv.y, gv.z])
				offsets[0] += verts.size()
				
				if normals:
					for n in normals:
						var gn = (normal_matrix * n).normalized()
						obj_file.store_line("vn %f %f %f" % [gn.x, gn.y, gn.z])
					offsets[1] += normals.size()
					
				if uvs:
					for uv in uvs:
						obj_file.store_line("vt %f %f" % [uv.x, 1.0 - uv.y])
					offsets[2] += uvs.size()
					
				if indices:
					for i in range(0, indices.size(), 3):
						var i0 = indices[i]
						var i1 = indices[i+1]
						var i2 = indices[i+2]
						
						var f0 = _format_face(v_start, vn_start, vt_start, i0, normals != null, uvs != null)
						var f1 = _format_face(v_start, vn_start, vt_start, i1, normals != null, uvs != null)
						var f2 = _format_face(v_start, vn_start, vt_start, i2, normals != null, uvs != null)
						
						# Возвращаем стандартный обход вершин (без инверсии)
						obj_file.store_line("f %s %s %s" % [f0, f1, f2])

	for child in node.get_children():
		_process_node(child, obj_file, materials, mtl_lines, offsets)

static func _format_face(v_start: int, vn_start: int, vt_start: int, idx: int, has_n: bool, has_uv: bool) -> String:
	var v = v_start + idx
	if has_n and has_uv:
		return "%d/%d/%d" % [v, vt_start + idx, vn_start + idx]
	elif has_n:
		return "%d//%d" % [v, vn_start + idx]
	else:
		return str(v)

static func _get_material_name(mi: MeshInstance3D, materials: Dictionary, mtl_lines: PackedStringArray) -> String:
	var mat = mi.material_override
	if not mat and mi.mesh and mi.mesh.get_surface_count() > 0:
		mat = mi.mesh.surface_get_material(0)
		
	if mat is StandardMaterial3D:
		var sm = mat as StandardMaterial3D
		var sig = "%s_%s_%s_%s_%s_%s" % [
			sm.albedo_color.to_html(), sm.metallic, sm.roughness, 
			sm.emission_enabled, sm.emission.to_html(), sm.emission_energy_multiplier
		]
		
		if not materials.has(sig):
			var name = "mat_" + str(materials.size())
			materials[sig] = name
			
			mtl_lines.append("newmtl " + name)
			mtl_lines.append("Ka 1.0 1.0 1.0")
			mtl_lines.append("Kd %f %f %f" % [sm.albedo_color.r, sm.albedo_color.g, sm.albedo_color.b])
			mtl_lines.append("Ks %f %f %f" % [sm.metallic, sm.metallic, sm.metallic])
			mtl_lines.append("Ns %f" % ((1.0 - sm.roughness) * 1000.0))
			mtl_lines.append("d 1.0")
			mtl_lines.append("illum 2")
			if sm.emission_enabled:
				var e = sm.emission * sm.emission_energy_multiplier
				mtl_lines.append("Ke %f %f %f" % [e.r, e.g, e.b])
			mtl_lines.append("")
		return materials[sig]
		
	return "default"
