extends Control
# Timeline: satu baris per item. Ketuk baris angka di atas untuk memindah waktu,
# tarik tengah batang untuk memindah, tarik ujung batang untuk memotong durasi.

signal selected_changed(index: int)
signal drag_began
signal edited
signal scrubbed(t: float)

const ROW_H := 44.0
const TOP := 26.0
const HANDLE := 22.0

var scene: Dictionary = {}
var selected := -1
var time := 0.0

var _mode := ""
var _row := -1
var _dx := 0.0


func _duration() -> float:
	return maxf(float(scene.get("duration", 10.0)), 0.1)


func _items() -> Array:
	var items: Array = scene.get("items", [])
	return items


func refresh() -> void:
	custom_minimum_size = Vector2(0, TOP + _items().size() * ROW_H + 12.0)
	queue_redraw()


func _label_for(item: Dictionary) -> String:
	var kind := str(item.get("type", "text"))
	if kind == "text":
		return str(item.get("text", ""))
	if kind == "image":
		return "gambar"
	return "kotak"


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	var dur := _duration()
	var w := size.x
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.10, 0.12))
	var step := 1.0
	if dur > 30.0:
		step = 5.0
	elif dur > 12.0:
		step = 2.0
	var t := 0.0
	while t <= dur:
		var x := w * t / dur
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.07))
		draw_string(font, Vector2(x + 3, 17), "%ds" % int(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.55))
		t += step
	var items := _items()
	for i in items.size():
		var item: Dictionary = items[i]
		var y := TOP + i * ROW_H
		var x1 := w * float(item.get("start", 0.0)) / dur
		var x2 := w * float(item.get("end", dur)) / dur
		var r := Rect2(x1, y + 3.0, maxf(x2 - x1, 10.0), ROW_H - 8.0)
		var col := Color(0.30, 0.60, 1.0)
		if str(item.get("type", "text")) == "rect":
			col = Color(0.55, 0.45, 0.95)
		elif str(item.get("type", "text")) == "image":
			col = Color(0.30, 0.78, 0.55)
		if i == selected:
			col = Color(1.0, 0.83, 0.0)
		draw_rect(r, col)
		if i == selected:
			draw_rect(Rect2(r.position.x, r.position.y, 8.0, r.size.y), Color(0, 0, 0, 0.35))
			draw_rect(Rect2(r.end.x - 8.0, r.position.y, 8.0, r.size.y), Color(0, 0, 0, 0.35))
		draw_string(font, Vector2(r.position.x + 12.0, y + 29.0), _label_for(item), HORIZONTAL_ALIGNMENT_LEFT, maxf(r.size.x - 20.0, 10.0), 16, Color.BLACK)
	var px := w * clampf(time / dur, 0.0, 1.0)
	draw_line(Vector2(px, 0), Vector2(px, size.y), Color(1.0, 0.3, 0.3), 2.0)


func _gui_input(event: InputEvent) -> void:
	var dur := _duration()
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_press(mb.position, dur)
		else:
			_mode = ""
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _mode != "":
		_drag(mm.position, dur)


func _press(pos: Vector2, dur: float) -> void:
	if pos.y < TOP:
		_mode = "scrub"
		scrubbed.emit(clampf(pos.x / size.x * dur, 0.0, dur))
		return
	var row := int((pos.y - TOP) / ROW_H)
	var items := _items()
	if row < 0 or row >= items.size():
		selected = -1
		selected_changed.emit(-1)
		queue_redraw()
		return
	var item: Dictionary = items[row]
	var x1 := size.x * float(item.get("start", 0.0)) / dur
	var x2 := size.x * float(item.get("end", dur)) / dur
	_row = row
	selected = row
	selected_changed.emit(row)
	var tpos := pos.x / size.x * dur
	if pos.x <= x1 + HANDLE:
		_mode = "trim_start"
	elif pos.x >= x2 - HANDLE:
		_mode = "trim_end"
	else:
		_mode = "move"
		_dx = tpos - float(item.get("start", 0.0))
	drag_began.emit()
	queue_redraw()


func _drag(pos: Vector2, dur: float) -> void:
	var tpos := clampf(pos.x / size.x * dur, 0.0, dur)
	if _mode == "scrub":
		scrubbed.emit(tpos)
		return
	var items := _items()
	if _row < 0 or _row >= items.size():
		return
	var item: Dictionary = items[_row]
	var t_start := float(item.get("start", 0.0))
	var t_end := float(item.get("end", dur))
	match _mode:
		"move":
			var length := t_end - t_start
			var new_start := clampf(tpos - _dx, 0.0, maxf(dur - length, 0.0))
			item["start"] = snappedf(new_start, 0.1)
			item["end"] = snappedf(new_start + length, 0.1)
		"trim_start":
			item["start"] = snappedf(minf(tpos, t_end - 0.2), 0.1)
		"trim_end":
			item["end"] = snappedf(maxf(tpos, t_start + 0.2), 0.1)
	edited.emit()
	queue_redraw()
