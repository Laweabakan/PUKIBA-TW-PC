extends RefCounted
## Texturas procedurales estilo plastilina (generadas al vuelo, sin archivos).
## "clay_bump" es un mapa de normales con abolladuras y huellas de dedos.

const SIZE := 128

static var _cache := {}


static func get_texture(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var img: Image
	match id:
		"clay_bump":
			img = _clay_bump(rng)
		"bricks":
			img = _bricks(rng)
		"wood":
			img = _wood(rng)
		"roof":
			img = _roof(rng)
		"meadow":
			img = _meadow(rng)
		_:
			img = Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
			img.fill(Color.WHITE)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex


static func _vary(c: Color, amount: float, rng: RandomNumberGenerator) -> Color:
	var v := rng.randf_range(-amount, amount)
	return c.lightened(v) if v > 0.0 else c.darkened(-v)


# --- Relieve: abolladuras suaves + huellas con surcos (tileable) ---

static func _clay_bump(rng: RandomNumberGenerator) -> Image:
	var h := PackedFloat32Array()
	h.resize(SIZE * SIZE)
	h.fill(0.5)
	# bultos y hundimientos amplios
	for i in 18:
		_dent(h, rng.randi() % SIZE, rng.randi() % SIZE, rng.randi_range(14, 30), rng.randf_range(-0.12, 0.12), 0.0)
	# huellas de dedos (hundimiento con surcos concéntricos)
	for i in 7:
		_dent(h, rng.randi() % SIZE, rng.randi() % SIZE, rng.randi_range(10, 18), -0.18, 0.025)
	# pequeñas marcas de herramienta
	for i in 30:
		_dent(h, rng.randi() % SIZE, rng.randi() % SIZE, rng.randi_range(2, 4), rng.randf_range(-0.08, 0.05), 0.0)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var v := clampf(h[y * SIZE + x], 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	img.bump_map_to_normal_map(3.0)
	return img


static func _dent(h: PackedFloat32Array, cx: int, cy: int, r: int, depth: float, ridges: float) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := sqrt(float(x * x + y * y))
			if d >= r:
				continue
			var f := 1.0 - d / r
			var v := depth * f * f * (3.0 - 2.0 * f)
			if ridges > 0.0:
				v += ridges * sin(d * 1.6) * f
			var idx := posmod(cy + y, SIZE) * SIZE + posmod(cx + x, SIZE)
			h[idx] += v


# --- Pradera: manchas suaves de luz y sombra (se tiñe con el color del pasto) ---

static func _meadow(rng: RandomNumberGenerator) -> Image:
	var h := PackedFloat32Array()
	h.resize(SIZE * SIZE)
	h.fill(0.88)
	for i in 26:
		_dent(h, rng.randi() % SIZE, rng.randi() % SIZE, rng.randi_range(10, 26), rng.randf_range(-0.14, 0.14), 0.0)
	for i in 60:
		_dent(h, rng.randi() % SIZE, rng.randi() % SIZE, rng.randi_range(1, 3), rng.randf_range(-0.12, 0.1), 0.0)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var v := clampf(h[y * SIZE + x], 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v * 1.02, v * 0.95))
	return img


# --- Ladrillos de plastilina: piezas suaves con juntas redondeadas ---

static func _bricks(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var mortar := Color(0.42, 0.39, 0.37)
	for row in 8:
		var off := 16 if row % 2 == 1 else 0
		for col in 4:
			var brick := _vary(Color(0.66, 0.62, 0.58), 0.08, rng)
			for y in range(row * 16, row * 16 + 16):
				for x in range(col * 32 + off, col * 32 + off + 32):
					var lx := x - (col * 32 + off)
					var ly := y - row * 16
					var edge := minf(minf(lx, 31 - lx), minf(ly, 15 - ly))
					var t := clampf((edge - 1.0) / 3.0, 0.0, 1.0)
					var c := mortar.lerp(brick, t)
					if ly < 5:
						c = c.lightened(0.05 * (5 - ly) / 5.0 * t)
					img.set_pixel(posmod(x, SIZE), y, c)
	return img


# --- Madera: tablones con vetas onduladas ---

static func _wood(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for plank in 4:
		var base := _vary(Color(0.72, 0.48, 0.27), 0.07, rng)
		var phase := rng.randf() * TAU
		for y in range(plank * 32, plank * 32 + 32):
			var ly := y - plank * 32
			for x in SIZE:
				var grain := sin(x * 0.09 + phase + sin(x * 0.03 + ly * 0.4) * 2.0 + ly * 0.7)
				var c := base.darkened(0.08 * maxf(grain, 0.0))
				var edge := minf(ly, 31 - ly)
				if edge < 3:
					c = c.darkened(0.25 * (3 - edge) / 3.0)
				img.set_pixel(x, y, c)
	return img


# --- Tejas en escama ---

static func _roof(rng: RandomNumberGenerator) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for row in 8:
		var off := 8 if row % 2 == 1 else 0
		for col in 8:
			var tile := _vary(Color(0.38, 0.42, 0.62), 0.06, rng)
			var cx := col * 16 + off + 8
			for y in range(row * 16, row * 16 + 16):
				for x in range(cx - 8, cx + 8):
					var ly := y - row * 16
					var d := Vector2(x - cx, (ly - 2) * 0.9).length()
					var t := clampf(d / 9.0, 0.0, 1.0)
					var c := tile.lightened(0.12 * (1.0 - t)).darkened(0.25 * t * t)
					img.set_pixel(posmod(x, SIZE), y, c)
	return img
