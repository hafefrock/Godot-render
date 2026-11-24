#!/usr/bin/env python3
"""Ubah cerita jadi file adegan JSON lewat Gemini.

Pemakaian: python3 tools/make_scene.py "cerita" hasil.json
Butuh variabel GEMINI_API_KEY (opsional GEMINI_MODEL).
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request

PROMPT = """Ubah cerita berikut menjadi JSON adegan video 1280x720.
Keluarkan HANYA JSON mentah yang valid. Jangan pakai ```, jangan pakai garis miring terbalik.

Format:
{"language": "id", "background": "#101A2B",
 "items": [
  {"type":"text","text":"JUDUL","x":0,"y":200,"w":1280,"size":72,"color":"#FFFFFF","start":0.3,"end":4,"fade":0.5,"to_y":180},
  {"type":"text","text":"kalimat narasi","narrate":true,"x":80,"y":600,"w":1120,"size":52,"color":"#FFD400","fade":0.3,"to_y":585}
 ]}

Aturan:
- "language" adalah "id" atau "en", sesuai bahasa cerita.
- Item narasi (subtitle) memakai "narrate": true dan TIDAK memakai start/end. Waktunya diatur otomatis mengikuti suara.
- Satu kalimat pendek (maksimal 12 kata) per item narasi, urut sesuai cerita.
- Item judul tidak memakai narrate. Pakai start dan end tetap, maksimal 4 detik, di awal.
- Jangan menambah field lain di luar contoh.
- Bahasa teks sama dengan bahasa cerita.

Cerita:
{story}
"""

ALLOWED_TYPES = {"text", "rect", "image"}


def call_gemini(prompt):
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not key:
        sys.exit("GEMINI_API_KEY belum diisi. Isi di Settings > Secrets and variables > Actions > Secrets.")
    model = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    body = json.dumps({
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"responseMimeType": "application/json", "temperature": 0.4},
    }).encode("utf-8")
    req = urllib.request.Request(
        url, data=body,
        headers={"Content-Type": "application/json", "x-goog-api-key": key},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.load(resp)
    except urllib.error.HTTPError as err:
        sys.exit(f"Gemini menolak permintaan (kode {err.code}): {err.read().decode('utf-8', 'replace')[:300]}")
    except urllib.error.URLError as err:
        sys.exit(f"Tidak bisa menghubungi Gemini: {err.reason}")
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError, TypeError):
        sys.exit("Jawaban Gemini kosong atau tidak dikenali: " + json.dumps(data)[:300])


def clean_json(text):
    """Bersihkan sisa format dari AI, lalu ubah jadi objek Python."""
    text = text.strip()
    text = re.sub(r"^```[a-zA-Z]*\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    text = text.replace("\\[", "[").replace("\\]", "]")
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end == -1 or end < start:
        raise ValueError("Tidak ada objek JSON di jawaban AI.")
    return json.loads(text[start:end + 1])


def validate(scene):
    if not isinstance(scene, dict):
        raise ValueError("JSON harus berupa objek.")
    items = scene.get("items")
    if not isinstance(items, list) or not items:
        raise ValueError('Field "items" harus berupa daftar yang tidak kosong.')
    for i, item in enumerate(items, 1):
        if not isinstance(item, dict):
            raise ValueError(f"Item {i} bukan objek.")
        if item.get("type", "text") not in ALLOWED_TYPES:
            raise ValueError(f"Item {i} memakai type yang tidak dikenal: {item.get('type')}")
        if item.get("type", "text") == "text" and not str(item.get("text", "")).strip():
            raise ValueError(f"Item {i} bertipe text tapi teksnya kosong.")
    scene.setdefault("background", "#101A2B")
    scene.setdefault("duration", 10)
    return scene


def main():
    if len(sys.argv) != 3:
        sys.exit('Pemakaian: make_scene.py "cerita" hasil.json')
    story = sys.argv[1].strip()
    if not story:
        sys.exit("Ceritanya kosong.")
    raw = call_gemini(PROMPT.replace("{story}", story))
    try:
        scene = validate(clean_json(raw))
    except ValueError as err:
        sys.exit(f"Hasil AI tidak bisa dipakai: {err}\n--- jawaban AI ---\n{raw[:1500]}")
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump(scene, f, ensure_ascii=False, indent=2)
    print(f"Adegan dibuat: {len(scene['items'])} item -> {sys.argv[2]}")


if __name__ == "__main__":
    main()
