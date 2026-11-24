extends Node2D
# Membaca adegan dari file JSON lalu menggambarnya frame demi frame.
# Dipanggil oleh render.sh:
#   godot --path . --write-movie ... -- --scene=/path/adegan.json

const DEFAULT_SCENE := "res://scene.json"

var duration := 5.0
var entries: Array = []
var time := 0.0


func _ready() -> void:
    var path := DEFAULT_SCENE
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--scene="):
            path = arg.substr(8)
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Tidak bisa membuka file adegan: " + path)
        get_tree().quit(1)
        return
    var raw := file.get_as_text()
    # Bersihkan sisa format dari AI: pagar kode dan garis miring sebelum kurung siku.
    raw = raw.replace("\\[", "[").replace("\\]", "]")
    raw = raw.replace("```json", "").replace("```", "")
    var json := JSON.new()
    if json.parse(raw) != OK:
        push_error("JSON tidak valid di baris %d: %s" % [json.get_error_line(), json.get_error_message()])
        get_tree().quit(1)
        return
    var parsed = json.data
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Isi JSON harus berupa objek { ... }")
        get_tree().quit(1)
        return
    duration = float(parsed.get("duration", 5.0))
    RenderingServer.set_default_clear_color(Color.html(str(parsed.get("background", "#000000"))))
    for item in parsed.get("items", []):
        _build_item(item)


func _load_texture(src: String) -> Texture2D:
    if src == "":
        return null
    var path := src
    if not src.begins_with("/"):
        path = ProjectSettings.globalize_path("res://" + src.trim_prefix("res://"))
    var img := Image.load_from_file(path)
    if img == null or img.is_empty():
        return null
    return ImageTexture.create_from_image(img)


func _build_item(item: Dictionary) -> void:
    var node: Control
    var kind := str(item.get("type", "text"))
    if kind == "rect":
        var rect := ColorRect.new()
        rect.color = Color.html(str(item.get("color", "#ffffff")))
        rect.size = Vector2(float(item.get("w", 100)), float(item.get("h", 100)))
        node = rect
    elif kind == "image":
        var tex := _load_texture(str(item.get("src", "")))
        if tex == null:
            push_warning("Gambar tidak ditemukan, dilewati: " + str(item.get("src", "")))
            return
        var pic := TextureRect.new()
        pic.texture = tex
        pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        pic.size = Vector2(float(item.get("w", 1280)), float(item.get("h", 720)))
        node = pic
    else:
        var label := Label.new()
        label.text = str(item.get("text", ""))
        label.add_theme_font_size_override("font_size", int(item.get("size", 48)))
        label.add_theme_color_override("font_color", Color.html(str(item.get("color", "#ffffff"))))
        label.add_theme_color_override("font_outline_color", Color.BLACK)
        label.add_theme_constant_override("outline_size", int(item.get("outline", 8)))
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.custom_minimum_size = Vector2(float(item.get("w", 1280)), 0)
        label.size = label.custom_minimum_size
        match str(item.get("align", "center")):
            "left":
                label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
            "right":
                label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
            _:
                label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        node = label
    var base := Vector2(float(item.get("x", 0)), float(item.get("y", 0)))
    var target := Vector2(float(item.get("to_x", base.x)), float(item.get("to_y", base.y)))
    node.position = base
    node.visible = false
    add_child(node)
    entries.append({
        "node": node,
        "base": base,
        "to": target,
        "start": float(item.get("start", 0.0)),
        "end": float(item.get("end", duration)),
        "fade": float(item.get("fade", 0.3)),
        "zoom_from": float(item.get("zoom_from", 1.0)),
        "zoom_to": float(item.get("zoom_to", 1.0)),
    })


func _process(delta: float) -> void:
    time += delta
    for e in entries:
        var node: Control = e["node"]
        var active: bool = time >= e["start"] and time < e["end"]
        node.visible = active
        if not active:
            continue
        var span: float = maxf(e["end"] - e["start"], 0.001)
        var t: float = clampf((time - e["start"]) / span, 0.0, 1.0)
        node.position = e["base"].lerp(e["to"], t)
        if e["zoom_from"] != 1.0 or e["zoom_to"] != 1.0:
            node.pivot_offset = node.size / 2.0
            node.scale = Vector2.ONE * lerpf(e["zoom_from"], e["zoom_to"], t)
        var alpha := 1.0
        if e["fade"] > 0.0:
            alpha = minf((time - e["start"]) / e["fade"], (e["end"] - time) / e["fade"])
        node.modulate.a = clampf(alpha, 0.0, 1.0)
    if time >= duration:
        get_tree().quit()
