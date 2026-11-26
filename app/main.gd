extends Control
# Akar aplikasi: berpindah antara layar awal dan layar editor, serta pengaturan.

const Ui = preload("res://ui.gd")
const Store = preload("res://store.gd")
const HomeScreen = preload("res://home.gd")
const EditorScreen = preload("res://editor.gd")
const AiClient = preload("res://ai.gd")

var _home: HomeScreen
var _editor: EditorScreen
var _ai: Node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()

	var bg := ColorRect.new()
	bg.color = Ui.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_ai = AiClient.new()
	add_child(_ai)

	_home = HomeScreen.new()
	add_child(_home)
	_home.create_requested.connect(_on_create)
	_home.blank_requested.connect(_on_blank)
	_home.open_requested.connect(_on_open)
	_home.settings_requested.connect(_open_settings)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	for cls in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", cls, Ui.box(Ui.PANEL2, 12, 12))
		t.set_stylebox("focus", cls, Ui.box(Ui.PANEL2.lightened(0.08), 12, 12))
		t.set_color("font_color", cls, Ui.TEXT)
		t.set_color("font_placeholder_color", cls, Ui.MUTED)
	t.set_stylebox("panel", "ItemList", Ui.box(Ui.PANEL, 12, 8))
	t.set_color("font_color", "Label", Ui.TEXT)
	return t


func _new_name() -> String:
	return "proyek-" + Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")


func _on_create(story: String) -> void:
	if story.strip_edges() == "":
		_home.set_busy(false, "Tulis ceritanya dulu.")
		return
	_home.set_busy(true, "AI sedang membuat adegan...")
	var result: Dictionary = await _ai.story_to_scene(story)
	if result.get("ok", false):
		_home.set_busy(false, "")
		_open_editor(_new_name(), result["scene"])
	else:
		_home.set_busy(false, str(result.get("error", "Gagal.")))


func _on_blank() -> void:
	_open_editor(_new_name(), Store.new_scene())


func _on_open(project_name: String) -> void:
	_open_editor(project_name, Store.load_project(project_name))


func _open_editor(project_name: String, scene: Dictionary) -> void:
	if _editor != null:
		_editor.queue_free()
	_editor = EditorScreen.new()
	add_child(_editor)
	_editor.setup(project_name, scene, _ai)
	_editor.closed.connect(_close_editor)
	_home.visible = false


func _close_editor() -> void:
	if _editor != null:
		_editor.queue_free()
		_editor = null
	_home.visible = true
	_home.refresh_projects()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _editor != null:
			_close_editor()
		else:
			get_tree().quit()


func _open_settings() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Pengaturan"
	dlg.ok_button_text = "Simpan"
	dlg.cancel_button_text = "Batal"
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 8)

	box.add_child(Ui.label("Kunci API Gemini (dari AI Studio)", 20, Ui.MUTED))
	var gemini := LineEdit.new()
	gemini.secret = true
	gemini.text = Store.get_setting("gemini_key")
	box.add_child(gemini)

	box.add_child(Ui.label("Token GitHub (hanya untuk render, satu repo saja)", 20, Ui.MUTED))
	var token := LineEdit.new()
	token.secret = true
	token.text = Store.get_setting("github_token")
	box.add_child(token)

	box.add_child(Ui.label("Repo render", 20, Ui.MUTED))
	var repo := LineEdit.new()
	repo.text = Store.get_setting("repo", "hafefrock/godot-render")
	box.add_child(repo)

	box.add_child(Ui.label("Kunci disimpan hanya di HP ini, bukan di repo.", 18, Ui.MUTED))
	dlg.add_child(box)
	dlg.confirmed.connect(func() -> void:
		Store.set_setting("gemini_key", gemini.text.strip_edges())
		Store.set_setting("github_token", token.text.strip_edges())
		Store.set_setting("repo", repo.text.strip_edges())
		dlg.queue_free())
	dlg.canceled.connect(func() -> void: dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()
