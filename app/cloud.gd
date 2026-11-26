extends Node
# Mengirim adegan ke repo GitHub lalu menjalankan workflow render di cloud.

const Store = preload("res://store.gd")
const BRANCH := "main"
const WORKFLOW := "render.yml"


func _request(url: String, method: HTTPClient.Method, body: String) -> Dictionary:
	var token := Store.get_setting("github_token").strip_edges()
	var headers := PackedStringArray([
		"Authorization: Bearer " + token,
		"Accept: application/vnd.github+json",
		"X-GitHub-Api-Version: 2022-11-28",
		"User-Agent: video-ai-app",
		"Content-Type: application/json",
	])
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": null}
	var res: Array = await http.request_completed
	http.queue_free()
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	return {"ok": int(res[0]) == HTTPRequest.RESULT_SUCCESS, "code": int(res[1]), "data": JSON.parse_string(text)}


func _fail(text: String, r: Dictionary) -> Dictionary:
	var msg := ""
	var data: Variant = r.get("data")
	if data is Dictionary:
		msg = str(data.get("message", ""))
	if not r.get("ok", false):
		return {"ok": false, "error": "Gagal terhubung. Periksa internet."}
	return {"ok": false, "error": "%s (kode %d). %s" % [text, int(r.get("code", 0)), msg]}


func render(scene_json: String, narration: bool, on_status: Callable) -> Dictionary:
	if Store.get_setting("github_token").strip_edges() == "":
		return {"ok": false, "error": "Isi token GitHub di Pengaturan."}
	var repo := Store.get_setting("repo", "hafefrock/godot-render").strip_edges()
	var url := "https://api.github.com/repos/%s/contents/scene.json" % repo

	on_status.call("1/3 Memeriksa repo...")
	var r1: Dictionary = await _request(url + "?ref=" + BRANCH, HTTPClient.METHOD_GET, "")
	var sha := ""
	if r1["code"] == 200 and r1["data"] is Dictionary:
		sha = str(r1["data"].get("sha", ""))
	elif r1["code"] != 404:
		return _fail("Gagal membaca repo", r1)

	on_status.call("2/3 Mengirim adegan...")
	var put_body := {
		"message": "Update scene.json dari aplikasi Video AI",
		"content": Marshalls.utf8_to_base64(scene_json),
		"branch": BRANCH,
	}
	if sha != "":
		put_body["sha"] = sha
	var r2: Dictionary = await _request(url, HTTPClient.METHOD_PUT, JSON.stringify(put_body))
	if r2["code"] != 200 and r2["code"] != 201:
		return _fail("Gagal mengirim adegan", r2)

	on_status.call("3/3 Menjalankan render...")
	var dispatch_url := "https://api.github.com/repos/%s/actions/workflows/%s/dispatches" % [repo, WORKFLOW]
	var dispatch_body := {
		"ref": BRANCH,
		"inputs": {"story": "", "narration": "ya" if narration else "tidak", "scene": "res://scene.json"},
	}
	var r3: Dictionary = await _request(dispatch_url, HTTPClient.METHOD_POST, JSON.stringify(dispatch_body))
	if r3["code"] != 204:
		return _fail("Gagal menjalankan render", r3)
	return {"ok": true, "message": "Render dimulai. Ambil hasilnya di tab Actions repo."}
