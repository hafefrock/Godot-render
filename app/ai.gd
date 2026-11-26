extends Node
# Memanggil Gemini untuk membuat adegan dari cerita dan mengedit adegan dari perintah.

const Store = preload("res://store.gd")
const MODEL := "gemini-2.5-flash"

const STORY_PROMPT := """Ubah cerita berikut menjadi JSON adegan video 1280x720.
Keluarkan HANYA JSON mentah yang valid. Jangan pakai ```, jangan pakai garis miring terbalik.

Format:
{"language": "id", "background": "#101A2B",
 "items": [
  {"type":"text","text":"JUDUL","x":0,"y":200,"w":1280,"size":72,"color":"#FFFFFF","start":0.3,"end":4,"fade":0.5,"to_y":180},
  {"type":"text","text":"kalimat narasi","narrate":true,"x":80,"y":600,"w":1120,"size":52,"color":"#FFD400","fade":0.3,"to_y":585}
 ]}

Aturan:
- "language" adalah "id" atau "en", sesuai bahasa cerita.
- Item narasi (subtitle) memakai "narrate": true dan TIDAK memakai start/end. Waktunya diatur otomatis.
- Satu kalimat pendek (maksimal 12 kata) per item narasi, urut sesuai cerita.
- Item judul tidak memakai narrate. Pakai start dan end tetap, maksimal 4 detik, di awal.
- Jangan menambah field lain di luar contoh.
- Bahasa teks sama dengan bahasa cerita.

Cerita:
{story}
"""

const EDIT_PROMPT := """Kamu mengedit adegan video dalam format JSON. Terapkan perintah pengguna pada adegan di bawah.
Keluarkan HANYA JSON lengkap hasil edit dengan struktur dan field yang sama. Jangan hapus field yang tidak diminta untuk diubah.
Jangan pakai ```, jangan pakai garis miring terbalik. Kanvas 1280x720. Waktu dalam detik dan tidak boleh melebihi duration, kecuali pengguna meminta menambah durasi.

Perintah: {command}

Adegan:
{scene}
"""


func _ask(prompt: String) -> Dictionary:
	var key := Store.get_setting("gemini_key").strip_edges()
	if key == "":
		return {"ok": false, "error": "Isi kunci Gemini di Pengaturan."}
	var http := HTTPRequest.new()
	http.timeout = 90.0
	add_child(http)
	var body := JSON.stringify({
		"contents": [{"parts": [{"text": prompt}]}],
		"generationConfig": {"responseMimeType": "application/json", "temperature": 0.4},
	})
	var headers := PackedStringArray(["Content-Type: application/json", "x-goog-api-key: " + key])
	var url := "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent" % MODEL
	var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "Tidak bisa memulai permintaan (kode %d)." % err}
	var res: Array = await http.request_completed
	http.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "Gagal terhubung. Periksa internet."}
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text)
	if int(res[1]) != 200:
		var msg := ""
		if data is Dictionary and data.get("error") is Dictionary:
			msg = str(data["error"].get("message", ""))
		return {"ok": false, "error": "Gemini menolak (kode %d). %s" % [int(res[1]), msg]}
	if not (data is Dictionary):
		return {"ok": false, "error": "Jawaban Gemini tidak dikenali."}
	var cands: Array = data.get("candidates", [])
	if cands.is_empty():
		return {"ok": false, "error": "Gemini tidak memberi jawaban."}
	var content: Dictionary = cands[0].get("content", {})
	var parts: Array = content.get("parts", [])
	if parts.is_empty():
		return {"ok": false, "error": "Jawaban Gemini kosong."}
	return {"ok": true, "text": str(parts[0].get("text", ""))}


func story_to_scene(story: String) -> Dictionary:
	var r: Dictionary = await _ask(STORY_PROMPT.replace("{story}", story))
	if not r.get("ok", false):
		return r
	var scene := Store.parse_scene_text(str(r["text"]))
	if scene.is_empty():
		return {"ok": false, "error": "Hasil AI tidak bisa dipakai. Coba lagi."}
	Store.finalize_scene(scene)
	return {"ok": true, "scene": scene}


func edit_scene(scene: Dictionary, command: String) -> Dictionary:
	var prompt := EDIT_PROMPT.replace("{command}", command).replace("{scene}", JSON.stringify(scene, "  ", false))
	var r: Dictionary = await _ask(prompt)
	if not r.get("ok", false):
		return r
	var edited := Store.parse_scene_text(str(r["text"]))
	if edited.is_empty():
		return {"ok": false, "error": "Hasil AI tidak bisa dipakai. Coba kalimat lain."}
	Store.finalize_scene(edited)
	return {"ok": true, "scene": edited}
