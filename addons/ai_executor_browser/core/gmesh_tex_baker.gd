@tool
class_name GMeshTexBaker

static func bake(data: Dictionary) -> Image:
	var w = int(data.get("size", [512, 512])[0])
	var h = int(data.get("size", [512, 512])[1])
	
	var final_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	final_img.fill(Color(0, 0, 0, 0))
	
	var current_layer_img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	current_layer_img.fill(Color(0, 0, 0, 0))
	
	var has_pending_layer = false
	
	for layer in data.get("layers", []):
		var op = str(layer.get("op", ""))
		
		if op == "blend":
			if has_pending_layer:
				_blend_layer(final_img, current_layer_img, layer)
				current_layer_img.fill(Color(0, 0, 0, 0))
				has_pending_layer = false
			continue
			
		if has_pending_layer:
			var temp = Image.create(w, h, false, Image.FORMAT_RGBA8)
			temp.fill(Color(0, 0, 0, 0))
			_generate_layer(temp, op, layer)
			_blend_layer(current_layer_img, temp, {"mode": "mix", "opacity": 1.0})
		else:
			_generate_layer(current_layer_img, op, layer)
			has_pending_layer = true
			
	if has_pending_layer:
		_blend_layer(final_img, current_layer_img, {"mode": "mix", "opacity": 1.0})
		
	return final_img

static func generate_normal_map(source_img: Image, strength: float = 2.0) -> Image:
	var w = source_img.get_width()
	var h = source_img.get_height()
	var normal_img = Image.create(w, h, false, Image.FORMAT_RGB8)
	
	for y in range(h):
		for x in range(w):
			var left = _get_lum(source_img, x - 1, y)
			var right = _get_lum(source_img, x + 1, y)
			var top = _get_lum(source_img, x, y - 1)
			var bottom = _get_lum(source_img, x, y + 1)
			
			var dx = (right - left) * strength
			var dy = (bottom - top) * strength
			
			var normal = Vector3(-dx, -dy, 1.0).normalized()
			
			var r = (normal.x + 1.0) * 0.5
			var g = (normal.y + 1.0) * 0.5
			var b = (normal.z + 1.0) * 0.5
			
			normal_img.set_pixel(x, y, Color(r, g, b))
			
	return normal_img

static func _get_lum(img: Image, x: int, y: int) -> float:
	var cx = clampi(x, 0, img.get_width() - 1)
	var cy = clampi(y, 0, img.get_height() - 1)
	var c = img.get_pixel(cx, cy)
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

static func _generate_layer(img: Image, op: String, layer: Dictionary) -> void:
	match op:
		"fill": img.fill(Color.from_string(layer.get("color", "#FFFFFF"), Color.WHITE))
		"noise": _gen_noise(img, layer)
		"gradient": _gen_gradient(img, layer)
		"checker": _gen_checker(img, layer)
		"stripes": _gen_stripes(img, layer)
		"brick": _gen_brick(img, layer)
		"voronoi": _gen_voronoi(img, layer)

static func _blend_layer(base: Image, layer: Image, blend_data: Dictionary) -> void:
	var mode = str(blend_data.get("mode", "mix"))
	var opacity = float(blend_data.get("opacity", 1.0))
	var w = base.get_width()
	var h = base.get_height()
	
	for y in range(h):
		for x in range(w):
			var c1 = base.get_pixel(x, y)
			var c2 = layer.get_pixel(x, y)
			var alpha = c2.a * opacity
			if alpha == 0.0: continue
			var out = c1
			if c1.a == 0.0:
				out = c2
				out.a = alpha
			else:
				match mode:
					"mix": out = c1.lerp(c2, alpha)
					"multiply": out = c1.lerp(c1 * c2, alpha)
					"add": out = c1.lerp(c1 + c2, alpha)
					"overlay":
						var ov = c1
						ov.r = 2.0 * c1.r * c2.r if c1.r < 0.5 else 1.0 - 2.0 * (1.0 - c1.r) * (1.0 - c2.r)
						ov.g = 2.0 * c1.g * c2.g if c1.g < 0.5 else 1.0 - 2.0 * (1.0 - c1.g) * (1.0 - c2.g)
						ov.b = 2.0 * c1.b * c2.b if c1.b < 0.5 else 1.0 - 2.0 * (1.0 - c1.b) * (1.0 - c2.b)
						out = c1.lerp(ov, alpha)
			base.set_pixel(x, y, out)

static func _gen_noise(img: Image, data: Dictionary) -> void:
	var w = img.get_width()
	var h = img.get_height()
	var noise = FastNoiseLite.new()
	noise.seed = int(data.get("seed", 1))
	noise.frequency = 1.0 / float(data.get("scale", 8.0))
	noise.fractal_octaves = int(data.get("octaves", 4))
	var colors = data.get("colors", ["#000000", "#FFFFFF"])
	var c_arr = []
	for c in colors: c_arr.append(Color.from_string(c, Color.BLACK))
	for y in range(h):
		for x in range(w):
			var val = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var t = val * (c_arr.size() - 1)
			var idx = int(t)
			var next_idx = min(idx + 1, c_arr.size() - 1)
			img.set_pixel(x, y, c_arr[idx].lerp(c_arr[next_idx], t - idx))

static func _gen_gradient(img: Image, data: Dictionary) -> void:
	var w = img.get_width()
	var h = img.get_height()
	var dir = str(data.get("direction", "vertical"))
	var stops_data = data.get("stops", [[0.0, "#000000"], [1.0, "#FFFFFF"]])
	stops_data.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for y in range(h):
		for x in range(w):
			var t = 0.0
			if dir == "vertical": t = float(y) / h
			elif dir == "horizontal": t = float(x) / w
			elif dir == "radial": t = Vector2(x, y).distance_to(Vector2(w, h) * 0.5) / (float(w) * 0.5)
			t = clamp(t, 0.0, 1.0)
			var c_out = Color.BLACK
			var found = false
			for i in range(stops_data.size() - 1):
				var p1 = float(stops_data[i][0])
				var p2 = float(stops_data[i+1][0])
				if t >= p1 and t <= p2:
					var lt = (t - p1) / (p2 - p1) if p2 > p1 else 0.0
					c_out = Color.from_string(stops_data[i][1], Color.BLACK).lerp(Color.from_string(stops_data[i+1][1], Color.BLACK), lt)
					found = true
					break
			if not found:
				c_out = Color.from_string(stops_data[0][1] if t < float(stops_data[0][0]) else stops_data[-1][1], Color.BLACK)
			img.set_pixel(x, y, c_out)

static func _gen_checker(img: Image, data: Dictionary) -> void:
	var cells = data.get("cells", [16, 16])
	var cw = float(img.get_width()) / int(cells[0])
	var ch = float(img.get_height()) / int(cells[1])
	var colors = data.get("colors", ["#000000", "#FFFFFF"])
	var c1 = Color.from_string(colors[0], Color.BLACK)
	var c2 = Color.from_string(colors[1], Color.WHITE)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			img.set_pixel(x, y, c1 if (int(x/cw) + int(y/ch)) % 2 == 0 else c2)

static func _gen_stripes(img: Image, data: Dictionary) -> void:
	var dir = str(data.get("direction", "vertical"))
	var width = float(data.get("width", 0.1))
	var colors = data.get("colors", ["#000000", "#FFFFFF"])
	var c1 = Color.from_string(colors[0], Color.BLACK)
	var c2 = Color.from_string(colors[1], Color.WHITE)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var val = 0.0
			if dir == "vertical": val = fmod(float(x) / img.get_width(), width * 2.0)
			elif dir == "horizontal": val = fmod(float(y) / img.get_height(), width * 2.0)
			elif dir == "diagonal": val = fmod((float(x) + float(y)) / img.get_width(), width * 2.0)
			img.set_pixel(x, y, c1 if val < width else c2)

static func _gen_brick(img: Image, data: Dictionary) -> void:
	var rows = int(data.get("rows", 8))
	var cols = int(data.get("cols", 4))
	var mortar_val = data.get("mortar", 0.05)
	var mw = 0.05
	var mh = 0.05
	var c_mortar = Color.WHITE
	if mortar_val is String:
		c_mortar = Color.from_string(mortar_val, Color.WHITE)
		mw = 0.05
		mh = 0.05
	elif mortar_val is float or mortar_val is int:
		mw = float(mortar_val)
		mh = float(mortar_val)
		var colors_fb = data.get("colors", ["#000000", "#FFFFFF"])
		c_mortar = Color.from_string(colors_fb[min(1, colors_fb.size()-1)], Color.WHITE)
	var brick_colors = []
	for c in data.get("colors", ["#000000"]): brick_colors.append(Color.from_string(c, Color.BLACK))
	var bh = float(img.get_height()) / rows
	var bw = float(img.get_width()) / cols
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var row = int(y / bh)
			var offset_x = bw * 0.5 if row % 2 == 1 else 0.0
			var bx = fmod(float(x) + offset_x, bw)
			var by = fmod(float(y), bh)
			if bx < (bw * mw) or by < (bh * mh):
				img.set_pixel(x, y, c_mortar)
			else:
				var calc_x = int((float(x) + offset_x) / bw)
				img.set_pixel(x, y, brick_colors[(row * cols + calc_x) % brick_colors.size()])

static func _gen_voronoi(img: Image, data: Dictionary) -> void:
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.seed = int(data.get("seed", 1))
	noise.frequency = float(data.get("cells", 32)) / 512.0
	var c_arr = []
	for c in data.get("colors", ["#000000", "#FFFFFF"]): c_arr.append(Color.from_string(c, Color.BLACK))
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var val = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			img.set_pixel(x, y, c_arr[int(val * c_arr.size()) % c_arr.size()])
