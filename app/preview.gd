extends Control
# Pratinjau adegan pada waktu tertentu (rumus gerak, fade, dan zoom sama seperti saat render).

var scene: Dictionary = {}
var time := 0.0
var _textures: Dictionary = {}


func _init() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(320, 180)


func set_scene(value: Dictionary) -> void:
	scene = value
	queue_redraw()


func set_time(value: float) -> void:
	time = value
	queue_redraw()


func clear_cache() -> void:
	_textures.clear()


func _get_texture(src: String) -> Texture2D:
	if src == "":
		return null
	if _textures.has(src):
		return _textures[src]
	var tex: Texture2D = null
	var path := src
	if not src.begins_with("/") and not src.begins_with("user://") and not src.begins_with("res://"):
		path = "res://" + src
	var img := Image.load_from_file(path)
	if img != null and not img.is_empty():
		tex = ImageTexture.create_from_image(img)
	_textures[src] = tex
	return tex


func _draw() -> void:
	var avail := size
	var s := minf(avail.x / 1280.0, avail.y / 720.0)
	if s <= 0.0:
		return
	var canvas := Vector2(1280.0, 720.0) * s
	var origin := (avail - canvas) / 2.0
	draw_rect(Rect2(Vector2.ZERO, avail), Color(0.04, 0.04, 0.05))
	draw_rect(Rect2(origin, canvas), Color.html(str(scene.get("background", "#000000"))))

	var font: Font = ThemeDB.fallback_font
	var total := float(scene.get("duration", 10.0))
	var items: Array = scene.get("items", [])
	for raw in items:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		var start := float(item.get("start", 0.0))
		var t_end := float(item.get("end", total))
		if time < start or time >= t_end:
			continue
		var span := maxf(t_end - start, 0.001)
		var t := clampf((time - start) / span, 0.0, 1.0)
		var fade := float(item.get("fade", 0.3))
		var alpha := 1.0
		if fade > 0.0:
			alpha = clampf(minf((time - start) / fade, (t_end - time) / fade), 0.0, 1.0)
		var base := Vector2(float(item.get("x", 0)), float(item.get("y", 0)))
		var target := Vector2(float(item.get("to_x", base.x)), float(item.get("to_y", base.y)))
		var pos := origin + base.lerp(target, t) * s
		var zoom := lerpf(float(item.get("zoom_from", 1.0)), float(item.get("zoom_to", 1.0)), t)
		var kind := str(item.get("type", "text"))

		if kind == "text":
			var text := str(item.get("text", ""))
			var fs := maxi(6, int(float(item.get("size", 48)) * s * zoom))
			var w := float(item.get("w", 1280)) * s
			var align := HORIZONTAL_ALIGNMENT_CENTER
			var align_name := str(item.get("align", "center"))
			if align_name == "left":
				align = HORIZONTAL_ALIGNMENT_LEFT
			elif align_name == "right":
				align = HORIZONTAL_ALIGNMENT_RIGHT
			var col := Color.html(str(item.get("color", "#ffffff")))
			col.a *= alpha
			var p := pos + Vector2(0, font.get_ascent(fs))
			draw_multiline_string(font, p + Vector2(2, 2), text, align, w, fs, -1, Color(0, 0, 0, 0.8 * alpha))
			draw_multiline_string(font, p, text, align, w, fs, -1, col)
		else:
			var default_w := 1280.0 if kind == "image" else 100.0
			var default_h := 720.0 if kind == "image" else 100.0
			var size0 := Vector2(float(item.get("w", default_w)), float(item.get("h", default_h))) * s
			var center := pos + size0 / 2.0
			var size1 := size0 * zoom
			var r := Rect2(center - size1 / 2.0, size1)
			if kind == "rect":
				var col2 := Color.html(str(item.get("color", "#ffffff")))
				col2.a *= alpha
				draw_rect(r, col2)
			else:
				var tex := _get_texture(str(item.get("src", "")))
				if tex == null:
					draw_rect(r, Color(0.4, 0.4, 0.4, 0.5 * alpha))
				else:
					var ts := tex.get_size()
					var k := maxf(r.size.x / ts.x, r.size.y / ts.y)
					var src_size := r.size / k
					var src := Rect2((ts - src_size) / 2.0, src_size)
					draw_texture_rect_region(tex, r, src, Color(1, 1, 1, alpha))
	draw_rect(Rect2(origin, canvas), Color(1, 1, 1, 0.15), false, 1.0)
