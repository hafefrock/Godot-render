extends RefCounted
# Penyimpanan pengaturan dan proyek di user:// (penyimpanan pribadi aplikasi),
# serta fungsi bantu untuk adegan JSON.

const SETTINGS_PATH := "user://settings.cfg"
const PROJECT_DIR := "user://projects"


static func get_setting(key: String, default_value: String = "") -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return default_value
	return str(cfg.get_value("app", key, default_value))


static func set_setting(key: String, value: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("app", key, value)
	cfg.save(SETTINGS_PATH)


static func new_scene() -> Dictionary:
	return {"duration": 10.0, "background": "#101A2B", "language": "id", "items": []}


static func list_projects() -> Array:
	DirAccess.make_dir_recursive_absolute(PROJECT_DIR)
	var names: Array = []
	var dir := DirAccess.open(PROJECT_DIR)
	if dir == null:
		return names
	for f in dir.get_files():
		if f.ends_with(".json"):
			names.append(f.trim_suffix(".json"))
	names.sort()
	names.reverse()
	return names


static func save_project(project_name: String, scene: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(PROJECT_DIR)
	var f := FileAccess.open("%s/%s.json" % [PROJECT_DIR, project_name], FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(scene, "  ", false))


static func load_project(project_name: String) -> Dictionary:
	var path := "%s/%s.json" % [PROJECT_DIR, project_name]
	if not FileAccess.file_exists(path):
		return new_scene()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get("items") is Array:
		return parsed
	return new_scene()


# Membersihkan jawaban AI (pagar kode, garis miring) lalu mengubahnya jadi adegan.
# Mengembalikan {} bila tidak valid.
static func parse_scene_text(text: String) -> Dictionary:
	var t := text.strip_edges()
	t = t.replace("```json", "").replace("```", "")
	t = t.replace("\\[", "[").replace("\\]", "]")
	var a := t.find("{")
	var b := t.rfind("}")
	if a == -1 or b <= a:
		return {}
	var parsed: Variant = JSON.parse_string(t.substr(a, b - a + 1))
	if parsed is Dictionary and parsed.get("items") is Array:
		return parsed
	return {}


static func needs_retime(scene: Dictionary) -> bool:
	var items: Array = scene.get("items", [])
	for raw in items:
		if raw is Dictionary and raw.get("narrate", false) and not raw.has("start"):
			return true
	return false


# Waktu untuk item narasi diperkirakan dari panjang teks (tanpa suara).
static func retime_narration(scene: Dictionary) -> void:
	var items: Array = scene.get("items", [])
	var t := 0.5
	var any := false
	for raw in items:
		if raw is Dictionary and raw.get("narrate", false):
			var item: Dictionary = raw
			var words: int = str(item.get("text", "")).split(" ", false).size()
			var dur: float = maxf(1.5, words * 0.4)
			item["start"] = snappedf(t, 0.05)
			item["end"] = snappedf(t + dur + 0.2, 0.05)
			t = float(item["end"]) + 0.35
			any = true
	if any:
		var end_max := 0.0
		for raw in items:
			if raw is Dictionary:
				end_max = maxf(end_max, float(raw.get("end", 0.0)))
		scene["duration"] = snappedf(end_max + 1.0, 0.1)


static func finalize_scene(scene: Dictionary) -> void:
	if not scene.has("background"):
		scene["background"] = "#101A2B"
	if not scene.has("duration"):
		scene["duration"] = 10.0
	if not scene.has("language"):
		scene["language"] = "id"
	if needs_retime(scene):
		retime_narration(scene)
