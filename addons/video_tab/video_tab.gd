@tool
extends VBoxContainer
# Tab "Video": mengatur adegan (scene.json) lewat daftar item dan timeline.
# Versi 0.1: muat, ubah, simpan, dan salin JSON. Belum ada pratinjau.

const SCENE_PATH := "res://scene.json"
const ROW_H := 34.0

var meta := {"duration": 10.0, "background": "#101A2B", "language": "id"}
var items: Array = []
var selected := -1
var _updating := false

var status: Label
var list: ItemList
var timeline: TimelineView
var form: GridContainer
var f_text_label: Label
var f_text: LineEdit
var f_start: SpinBox
var f_end: SpinBox
var f_x: SpinBox
var f_y: SpinBox
var f_size: SpinBox
var f_color: ColorPickerButton
var f_duration: SpinBox


# ---------- Timeline ----------
class TimelineView extends Control:
    const ROW_H := 34.0
    const TOP := 18.0
    var tab
    var _drag := -1
    var _drag_dx := 0.0

    func _draw() -> void:
        var dur: float = maxf(float(tab.meta["duration"]), 0.1)
        var w := size.x
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.14))
        var step := 1.0
        if dur > 30.0:
            step = 5.0
        elif dur > 12.0:
            step = 2.0
        var t := 0.0
        while t <= dur:
            var x := w * t / dur
            draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.08))
            draw_string(ThemeDB.fallback_font, Vector2(x + 2, 12), "%d" % int(t), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))
            t += step
        for i in tab.items.size():
            var it: Dictionary = tab.items[i]
            var y := TOP + i * ROW_H
            var x1 := w * float(it.get("start", 0.0)) / dur
            var x2 := w * float(it.get("end", dur)) / dur
            var col := Color(0.3, 0.6, 1.0)
            if i == tab.selected:
                col = Color(1.0, 0.8, 0.2)
            draw_rect(Rect2(x1, y, maxf(x2 - x1, 4.0), ROW_H - 6.0), col)
            draw_string(ThemeDB.fallback_font, Vector2(x1 + 4, y + 16), tab.item_label(it), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)

    func _gui_input(event: InputEvent) -> void:
        var dur: float = maxf(float(tab.meta["duration"]), 0.1)
        var mb := event as InputEventMouseButton
        if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed:
                var row := int((mb.position.y - TOP) / ROW_H)
                if row >= 0 and row < tab.items.size():
                    tab.select_item(row)
                    var it: Dictionary = tab.items[row]
                    _drag = row
                    _drag_dx = mb.position.x / size.x * dur - float(it.get("start", 0.0))
            else:
                _drag = -1
            return
        var mm := event as InputEventMouseMotion
        if mm != null and _drag >= 0 and _drag < tab.items.size():
            var it2: Dictionary = tab.items[_drag]
            var length := float(it2.get("end", dur)) - float(it2.get("start", 0.0))
            var new_start := clampf(mm.position.x / size.x * dur - _drag_dx, 0.0, maxf(dur - length, 0.0))
            it2["start"] = snappedf(new_start, 0.1)
            it2["end"] = snappedf(new_start + length, 0.1)
            tab.on_timeline_changed()


# ---------- Susunan layar ----------
func _ready() -> void:
    name = "Video"
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _build_ui()
    _load_scene()


func _button(label: String, action: Callable) -> Button:
    var b := Button.new()
    b.text = label
    b.pressed.connect(action)
    return b


func _spin(min_v: float, max_v: float, step: float, key: String) -> SpinBox:
    var s := SpinBox.new()
    s.min_value = min_v
    s.max_value = max_v
    s.step = step
    s.allow_greater = true
    s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    s.value_changed.connect(_on_num.bind(key))
    return s


func _build_ui() -> void:
    var bar := HFlowContainer.new()
    add_child(bar)
    bar.add_child(_button("Muat", _load_scene))
    bar.add_child(_button("Simpan", _save_scene))
    bar.add_child(_button("Salin JSON", _copy_json))
    bar.add_child(_button("+ Teks", _add_item.bind("text")))
    bar.add_child(_button("+ Kotak", _add_item.bind("rect")))
    bar.add_child(_button("+ Gambar", _add_item.bind("image")))
    bar.add_child(_button("Hapus", _delete_item))
    status = Label.new()
    bar.add_child(status)

    var dur_row := HBoxContainer.new()
    add_child(dur_row)
    var dl := Label.new()
    dl.text = "Durasi (detik)"
    dur_row.add_child(dl)
    f_duration = SpinBox.new()
    f_duration.min_value = 1.0
    f_duration.max_value = 600.0
    f_duration.step = 0.5
    f_duration.value_changed.connect(_on_duration)
    dur_row.add_child(f_duration)

    var scroll_t := ScrollContainer.new()
    scroll_t.custom_minimum_size = Vector2(0, 190)
    scroll_t.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll_t)
    timeline = TimelineView.new()
    timeline.tab = self
    timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll_t.add_child(timeline)

    list = ItemList.new()
    list.custom_minimum_size = Vector2(0, 120)
    list.item_selected.connect(select_item)
    add_child(list)

    var scroll_f := ScrollContainer.new()
    scroll_f.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll_f.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    add_child(scroll_f)
    form = GridContainer.new()
    form.columns = 2
    form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll_f.add_child(form)

    f_text_label = _form_label("Teks")
    f_text = LineEdit.new()
    f_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    f_text.text_changed.connect(_on_text)
    form.add_child(f_text)
    f_start = _spin(0.0, 600.0, 0.1, "start")
    _form_row("Mulai (detik)", f_start)
    f_end = _spin(0.0, 600.0, 0.1, "end")
    _form_row("Selesai (detik)", f_end)
    f_x = _spin(-2000.0, 4000.0, 1.0, "x")
    _form_row("Posisi x", f_x)
    f_y = _spin(-2000.0, 4000.0, 1.0, "y")
    _form_row("Posisi y", f_y)
    f_size = _spin(8.0, 400.0, 1.0, "size")
    _form_row("Ukuran huruf", f_size)
    _form_label("Warna")
    f_color = ColorPickerButton.new()
    f_color.custom_minimum_size = Vector2(0, 40)
    f_color.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    f_color.color_changed.connect(_on_color)
    form.add_child(f_color)


func _form_label(text: String) -> Label:
    var l := Label.new()
    l.text = text
    form.add_child(l)
    return l


func _form_row(text: String, control: Control) -> void:
    _form_label(text)
    form.add_child(control)


# ---------- Data ----------
func item_label(it: Dictionary) -> String:
    var kind := str(it.get("type", "text"))
    if kind == "text":
        return str(it.get("text", ""))
    if kind == "image":
        return "gambar: " + str(it.get("src", ""))
    return "kotak"


func _text_key(it: Dictionary) -> String:
    return "src" if str(it.get("type", "text")) == "image" else "text"


func _load_scene() -> void:
    items = []
    selected = -1
    if FileAccess.file_exists(SCENE_PATH):
        var raw := FileAccess.get_file_as_string(SCENE_PATH)
        raw = raw.replace("\\[", "[").replace("\\]", "]")
        var json := JSON.new()
        if json.parse(raw) == OK and typeof(json.data) == TYPE_DICTIONARY:
            var data: Dictionary = json.data
            for key in data:
                if key != "items":
                    meta[key] = data[key]
            for it in data.get("items", []):
                if typeof(it) == TYPE_DICTIONARY:
                    items.append(it)
            _say("Dimuat: %d item" % items.size())
        else:
            _say("scene.json tidak valid, mulai kosong")
    else:
        _say("scene.json belum ada, mulai kosong")
    f_duration.set_value_no_signal(float(meta.get("duration", 10.0)))
    _refresh()


func _to_json() -> String:
    var data := meta.duplicate()
    data["items"] = items
    return JSON.stringify(data, "  ")


func _save_scene() -> void:
    var f := FileAccess.open(SCENE_PATH, FileAccess.WRITE)
    if f == null:
        _say("Gagal menyimpan")
        return
    f.store_string(_to_json())
    f.close()
    _say("Tersimpan ke scene.json")


func _copy_json() -> void:
    DisplayServer.clipboard_set(_to_json())
    _say("JSON disalin. Tempel di GitHub.")


func _say(text: String) -> void:
    status.text = text


func _add_item(kind: String) -> void:
    var it := {}
    match kind:
        "rect":
            it = {"type": "rect", "x": 0, "y": 300, "w": 1280, "h": 6, "color": "#FFD400", "start": 0.0, "end": 3.0}
        "image":
            it = {"type": "image", "src": "assets/latar.jpg", "x": 0, "y": 0, "w": 1280, "h": 720, "start": 0.0, "end": 5.0}
        _:
            it = {"type": "text", "text": "Teks baru", "x": 80, "y": 300, "w": 1120, "size": 52, "color": "#FFFFFF", "start": 0.0, "end": 3.0}
    items.append(it)
    _refresh()
    select_item(items.size() - 1)


func _delete_item() -> void:
    if selected < 0 or selected >= items.size():
        return
    items.remove_at(selected)
    selected = -1
    _refresh()


# ---------- Tampilan ----------
func _refresh() -> void:
    list.clear()
    for i in items.size():
        list.add_item("%d. %s" % [i + 1, item_label(items[i])])
    timeline.custom_minimum_size = Vector2(0, TimelineView.TOP + items.size() * TimelineView.ROW_H + 8.0)
    timeline.queue_redraw()
    if selected >= items.size():
        selected = -1
    _fill_form()


func select_item(index: int) -> void:
    selected = index
    if index >= 0 and index < list.item_count:
        list.select(index)
    _fill_form()
    timeline.queue_redraw()


func on_timeline_changed() -> void:
    _fill_form()
    timeline.queue_redraw()


func _fill_form() -> void:
    _updating = true
    var ok := selected >= 0 and selected < items.size()
    form.get_parent().visible = ok
    if ok:
        var it: Dictionary = items[selected]
        var kind := str(it.get("type", "text"))
        f_text_label.text = "File gambar" if kind == "image" else "Teks"
        f_text.editable = kind != "rect"
        f_text.text = str(it.get(_text_key(it), ""))
        f_start.set_value_no_signal(float(it.get("start", 0.0)))
        f_end.set_value_no_signal(float(it.get("end", float(meta["duration"]))))
        f_x.set_value_no_signal(float(it.get("x", 0)))
        f_y.set_value_no_signal(float(it.get("y", 0)))
        f_size.set_value_no_signal(float(it.get("size", 48)))
        f_color.color = Color.html(str(it.get("color", "#ffffff")))
    _updating = false


# ---------- Perubahan dari formulir ----------
func _on_duration(value: float) -> void:
    meta["duration"] = value
    timeline.queue_redraw()


func _on_text(new_text: String) -> void:
    if _updating or selected < 0:
        return
    var it: Dictionary = items[selected]
    it[_text_key(it)] = new_text
    list.set_item_text(selected, "%d. %s" % [selected + 1, item_label(it)])
    timeline.queue_redraw()


func _on_num(value: float, key: String) -> void:
    if _updating or selected < 0:
        return
    items[selected][key] = value
    timeline.queue_redraw()


func _on_color(color: Color) -> void:
    if _updating or selected < 0:
        return
    items[selected]["color"] = "#" + color.to_html(false)
    timeline.queue_redraw()
