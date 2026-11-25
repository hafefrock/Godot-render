@tool
extends EditorPlugin
# Menambah tab "Video" di sebelah 2D, 3D, dan Script.

const VideoTab := preload("res://addons/video_tab/video_tab.gd")

var tab: Control


func _enter_tree() -> void:
    tab = VideoTab.new()
    EditorInterface.get_editor_main_screen().add_child(tab)
    _make_visible(false)


func _exit_tree() -> void:
    if tab:
        tab.queue_free()


func _has_main_screen() -> bool:
    return true


func _make_visible(visible: bool) -> void:
    if tab:
        tab.visible = visible


func _get_plugin_name() -> String:
    return "Video"


func _get_plugin_icon() -> Texture2D:
    return EditorInterface.get_editor_theme().get_icon("Animation", "EditorIcons")
