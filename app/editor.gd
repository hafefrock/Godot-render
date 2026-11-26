extends Control
# Layar editor: pratinjau, timeline, panel properti, perintah AI, dan render.

const Ui = preload("res://ui.gd")
const Store = preload("res://store.gd")
const ScenePreview = preload("res://preview.gd")
const SceneTimeline = preload("res://timeline.gd")
const CloudRender = preload("res://cloud.gd")

signal closed

var scene: Dictionary = {}
var project_name := ""
var selected := -1
var time := 0.0
var playing := false

var _ai: Node
var _cloud: Node
var _history: Array = []
var _redo: Array = []
var _last_snap_ms := 0
var _updating := false
var _save_timer: Timer

var _preview: ScenePreview
var _timeline: SceneTimeline
var _slider: HSlider
var _time_label: Label
var _play_button: Button
var _status: Label
var _title: Label
var _props: VBoxContainer
var _no_sel: Label
var _f_text_label: Label
var _f_text: LineEdit
var _f_narrate: CheckBox
var _f_start: SpinBox
var _f_end: SpinBox
var _f_x: SpinBox
var _f_y: SpinBox
var _f_size: SpinBox
var _f_color: ColorPickerButton
var _ai_input: LineEdit
var _narration_check: CheckBox


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_cloud = CloudRender.new()
	add_child(_cloud)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 1.0
	_save_timer.timeout.connect(_save_now)
	add_child(_save_timer)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# Bilah atas
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	var back := Ui.button("Beranda")
	back.pressed.connect(func() -> void: closed.emit())
	top.add_child(back)
	_title = Ui.label("", 24)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_title)
	var undo := Ui.button("Urung")
	undo.pressed.connect(_undo)
	top.add_child(undo)
	var redo := Ui.button("Ulang")
	redo.pressed.connect(_redo_action)
	top.add_child(redo)
	var render := Ui.button("Render", true)
	render.pressed.connect(_on_render)
	top.add_child(render)

	# Isi
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)

	_preview = ScenePreview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_preview)

	var transport := HBoxContainer.new()
	transport.add_theme_constant_override("separation", 8)
	left.add_child(transport)
	_play_button = Ui.button("Putar", true)
	_play_button.custom_minimum_size = Vector2(130, 48)
	_play_button.pressed.connect(_toggle_play)
	transport.add_child(_play_button)
	_slider = HSlider.new()
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.min_value = 0.0
	_slider.max_value = 10.0
	_slider.step = 0.05
	_slider.value_changed.connect(_on_slider)
	transport.add_child(_slider)
	_time_label = Ui.label("0.0 / 0.0 s", 20, Ui.MUTED)
	transport.add_child(_time_label)

	var tl_scroll := ScrollContainer.new()
	tl_scroll.custom_minimum_size = Vector2(0, 160)
	tl_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(tl_scroll)
	_timeline = SceneTimeline.new()
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.selected_changed.connect(_on_timeline_selected)
	_timeline.drag_began.connect(_snapshot)
	_timeline.edited.connect(_on_timeline_edited)
	_timeline.scrubbed.connect(_on_scrub)
	tl_scroll.add_child(_timeline)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	left.add_child(tools)
	var b_text := Ui.button("+ Teks")
	b_text.pressed.connect(_add_text)
	tools.add_child(b_text)
	var b_rect := Ui.button("+ Kotak")
	b_rect.pressed.connect(_add_rect)
	tools.add_child(b_rect)
	var b_dup := Ui.button("Duplikat")
	b_dup.pressed.connect(_duplicate)
	tools.add_child(b_dup)
	var b_del := Ui.button("Hapus")
	b_del.pressed.connect(_delete)
	tools.add_child(b_del)

	# Panel kanan
	var sheet := Ui.panel()
	sheet.custom_minimum_size = Vector2(400, 0)
	body.add_child(sheet)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)

	box.add_child(Ui.label("Minta AI", 24, Ui.ACCENT))
	_ai_input = LineEdit.new()
	_ai_input.placeholder_text = "Contoh: judul lebih besar, warna biru"
	_ai_input.text_submitted.connect(func(_t: String) -> void: _on_ai_send())
	box.add_child(_ai_input)
	var ai_send := Ui.button("Kirim ke AI")
	ai_send.pressed.connect(_on_ai_send)
	box.add_child(ai_send)
	box.add_child(HSeparator.new())

	box.add_child(Ui.label("Item terpilih", 24, Ui.ACCENT))
	_no_sel = Ui.label("Ketuk sebuah batang di timeline.", 20, Ui.MUTED)
	box.add_child(_no_sel)
	_props = VBoxContainer.new()
	_props.add_theme_constant_override("separation", 8)
	box.add_child(_props)

	_f_text_label = Ui.label("Teks", 20, Ui.MUTED)
	_props.add_child(_f_text_label)
	_f_text = LineEdit.new()
	_f_text.text_changed.connect(_on_text)
	_props.add_child(_f_text)
	_f_narrate = CheckBox.new()
	_f_narrate.text = "Dibacakan (narasi)"
	_f_narrate.toggled.connect(_on_narrate)
	_props.add_child(_f_narrate)
	_f_start = _spin(0.0, 600.0, 0.1, "start", "Mulai (detik)")
	_f_end = _spin(0.0, 600.0, 0.1, "end", "Selesai (detik)")
	_f_x = _spin(-2000.0, 4000.0, 1.0, "x", "Posisi x")
	_f_y = _spin(-2000.0, 4000.0, 1.0, "y", "Posisi y")
	_f_size = _spin(8.0, 400.0, 1.0, "size", "Ukuran huruf")
	_props.add_child(Ui.label("Warna", 20, Ui.MUTED))
	_f_color = ColorPickerButton.new()
	_f_color.custom_minimum_size = Vector2(0, 48)
	_f_color.color_changed.connect(_on_color)
	_props.add_child(_f_color)

	box.add_child(HSeparator.new())
	_narration_check = CheckBox.new()
	_narration_check.text = "Suara narasi saat render"
	_narration_check.button_pressed = true
	box.add_child(_narration_check)

	_status = Ui.label("", 20, Ui.MUTED)
	root.add_child(_status)

	_fill_props()


func _spin(min_v: float, max_v: float, step_v: float, key: String, caption: String) -> SpinBox:
	_props.add_child(Ui.label(caption, 20, Ui.MUTED))
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step_v
	s.allow_greater = true
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(_on_num.bind(key))
	_props.add_child(s)
	return s


func setup(p_name: String, p_scene: Dictionary, p_ai: Node) -> void:
	project_name = p_name
	scene = p_scene
	_ai = p_ai
	if not scene.has("items"):
		scene["items"] = []
	Store.finalize_scene(scene)
	time = 0.0
	_refresh_all()
	_save_now()


func _duration() -> float:
	return maxf(float(scene.get("duration", 10.0)), 0.5)


func _items() -> Array:
	var items: Array = scene.get("items", [])
	return items


func _refresh_all() -> void:
	_title.text = project_name
	_preview.clear_cache()
	_preview.set_scene(scene)
	_timeline.scene = scene
	_timeline.selected = selected
	_timeline.refresh()
	_slider.max_value = _duration()
	_set_time(time)
	_fill_props()


func _after_edit() -> void:
	_preview.set_scene(scene)
	_timeline.scene = scene
	_timeline.refresh()
	_slider.max_value = _duration()
	_save_timer.start()


func _set_status(text: String) -> void:
	_status.text = text


func _save_now() -> void:
	if project_name != "":
		Store.save_project(project_name, scene)


# ---------- Waktu dan pemutaran ----------

func _set_time(t: float) -> void:
	time = clampf(t, 0.0, _duration())
	_slider.set_value_no_signal(time)
	_time_label.text = "%.1f / %.1f s" % [time, _duration()]
	_preview.set_time(time)
	_timeline.time = time
	_timeline.queue_redraw()


func _process(delta: float) -> void:
	if playing:
		_set_time(time + delta)
		if time >= _duration():
			playing = false
			_play_button.text = "Putar"


func _toggle_play() -> void:
	playing = not playing
	if playing and time >= _duration() - 0.05:
		_set_time(0.0)
	_play_button.text = "Jeda" if playing else "Putar"


func _on_slider(value: float) -> void:
	_set_time(value)


func _on_scrub(t: float) -> void:
	_set_time(t)


# ---------- Urung / ulang ----------

func _snapshot() -> void:
	_history.append(JSON.stringify(scene))
	if _history.size() > 60:
		_history.pop_front()
	_redo.clear()


func _snapshot_soon() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_snap_ms > 800:
		_snapshot()
	_last_snap_ms = now


func _restore(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		scene = parsed
		selected = -1
		_refresh_all()
		_save_timer.start()


func _undo() -> void:
	if _history.is_empty():
		return
	_redo.append(JSON.stringify(scene))
	_restore(str(_history.pop_back()))


func _redo_action() -> void:
	if _redo.is_empty():
		return
	_history.append(JSON.stringify(scene))
	_restore(str(_redo.pop_back()))


# ---------- Item ----------

func _on_timeline_selected(index: int) -> void:
	selected = index
	_fill_props()


func _on_timeline_edited() -> void:
	_after_edit()
	_fill_props()


func _add_item(item: Dictionary) -> void:
	_snapshot()
	var items := _items()
	items.append(item)
	selected = items.size() - 1
	_timeline.selected = selected
	_after_edit()
	_fill_props()


func _add_text() -> void:
	_add_item({"type": "text", "text": "Teks baru", "x": 80, "y": 300, "w": 1120, "size": 52, "color": "#FFFFFF", "start": snappedf(time, 0.1), "end": snappedf(minf(time + 3.0, _duration()), 0.1)})


func _add_rect() -> void:
	_add_item({"type": "rect", "x": 0, "y": 300, "w": 1280, "h": 6, "color": "#FFD400", "start": snappedf(time, 0.1), "end": snappedf(minf(time + 3.0, _duration()), 0.1)})


func _duplicate() -> void:
	var items := _items()
	if selected < 0 or selected >= items.size():
		return
	var copy: Dictionary = (items[selected] as Dictionary).duplicate(true)
	_add_item(copy)


func _delete() -> void:
	var items := _items()
	if selected < 0 or selected >= items.size():
		return
	_snapshot()
	items.remove_at(selected)
	selected = -1
	_timeline.selected = -1
	_after_edit()
	_fill_props()


# ---------- Panel properti ----------

func _fill_props() -> void:
	_updating = true
	var items := _items()
	var ok := selected >= 0 and selected < items.size()
	_props.visible = ok
	_no_sel.visible = not ok
	if ok:
		var item: Dictionary = items[selected]
		var kind := str(item.get("type", "text"))
		_f_text_label.text = "File gambar" if kind == "image" else "Teks"
		_f_text.editable = kind != "rect"
		_f_text.text = str(item.get("src" if kind == "image" else "text", ""))
		_f_narrate.visible = kind == "text"
		_f_narrate.set_pressed_no_signal(bool(item.get("narrate", false)))
		_f_start.set_value_no_signal(float(item.get("start", 0.0)))
		_f_end.set_value_no_signal(float(item.get("end", _duration())))
		_f_x.set_value_no_signal(float(item.get("x", 0)))
		_f_y.set_value_no_signal(float(item.get("y", 0)))
		_f_size.set_value_no_signal(float(item.get("size", 48)))
		_f_color.color = Color.html(str(item.get("color", "#ffffff")))
	_updating = false


func _selected_item() -> Dictionary:
	var items := _items()
	if selected < 0 or selected >= items.size():
		return {}
	return items[selected]


func _on_text(value: String) -> void:
	if _updating or selected < 0:
		return
	var item := _selected_item()
	if item.is_empty():
		return
	_snapshot_soon()
	item["src" if str(item.get("type", "text")) == "image" else "text"] = value
	_preview.clear_cache()
	_after_edit()


func _on_narrate(pressed: bool) -> void:
	if _updating or selected < 0:
		return
	var item := _selected_item()
	if item.is_empty():
		return
	_snapshot()
	item["narrate"] = pressed
	_after_edit()


func _on_num(value: float, key: String) -> void:
	if _updating or selected < 0:
		return
	var item := _selected_item()
	if item.is_empty():
		return
	_snapshot_soon()
	item[key] = value
	_after_edit()


func _on_color(color: Color) -> void:
	if _updating or selected < 0:
		return
	var item := _selected_item()
	if item.is_empty():
		return
	_snapshot_soon()
	item["color"] = "#" + color.to_html(false)
	_after_edit()


# ---------- AI dan render ----------

func _on_ai_send() -> void:
	var command := _ai_input.text.strip_edges()
	if command == "":
		return
	_set_status("AI sedang mengubah adegan...")
	var result: Dictionary = await _ai.edit_scene(scene, command)
	if result.get("ok", false):
		_snapshot()
		scene = result["scene"]
		selected = -1
		_ai_input.text = ""
		_refresh_all()
		_save_timer.start()
		_set_status("Selesai. Jika kurang pas, tekan Urung.")
	else:
		_set_status(str(result.get("error", "Gagal.")))


func _on_render() -> void:
	_save_now()
	_set_status("Menyiapkan render...")
	var result: Dictionary = await _cloud.render(JSON.stringify(scene, "  ", false), _narration_check.button_pressed, Callable(self, "_set_status"))
	_set_status(str(result.get("message", result.get("error", ""))))
