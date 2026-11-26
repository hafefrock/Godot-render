extends Control
# Layar awal: tulis cerita, atau buka proyek tersimpan.

const Ui = preload("res://ui.gd")
const Store = preload("res://store.gd")

signal create_requested(story: String)
signal blank_requested
signal open_requested(project_name: String)
signal settings_requested

var _story: TextEdit
var _list: ItemList
var _status: Label
var _create_button: Button
var _names: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 24)
	margin.add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 14)
	root.add_child(left)
	left.add_child(Ui.label("Video AI", 40, Ui.ACCENT))
	left.add_child(Ui.label("Tulis ceritamu, AI membuat videonya.", 22, Ui.MUTED))

	_story = TextEdit.new()
	_story.placeholder_text = "Contoh: Perjalanan pagi ke Bandung. Kami berangkat sebelum matahari terbit..."
	_story.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_story.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_story.add_theme_font_size_override("font_size", 24)
	left.add_child(_story)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	left.add_child(row)
	_create_button = Ui.button("Buat video dengan AI", true)
	_create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_button.pressed.connect(func() -> void: create_requested.emit(_story.text))
	row.add_child(_create_button)
	var blank := Ui.button("Mulai kosong")
	blank.pressed.connect(func() -> void: blank_requested.emit())
	row.add_child(blank)
	var settings := Ui.button("Pengaturan")
	settings.pressed.connect(func() -> void: settings_requested.emit())
	row.add_child(settings)

	_status = Ui.label("", 20, Ui.MUTED)
	left.add_child(_status)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)
	right.add_child(Ui.label("Proyek tersimpan", 24))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 22)
	_list.item_selected.connect(_on_project_selected)
	right.add_child(_list)

	refresh_projects()


func refresh_projects() -> void:
	_names = Store.list_projects()
	_list.clear()
	for n in _names:
		_list.add_item(str(n))


func _on_project_selected(index: int) -> void:
	if index >= 0 and index < _names.size():
		open_requested.emit(str(_names[index]))


func set_busy(busy: bool, message: String) -> void:
	_create_button.disabled = busy
	_status.text = message
