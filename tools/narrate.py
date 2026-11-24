#!/usr/bin/env python3
"""Buat suara narasi dan atur ulang waktu adegan mengikuti panjang suara.

Pemakaian: python3 tools/narrate.py adegan.json adegan_waktu.json narasi.wav

Item dengan "narrate": true dibacakan. Waktu start/end item itu dihitung ulang
supaya subtitle pas dengan suara. Item lain tidak diubah.
Suara: ElevenLabs bila ELEVENLABS_API_KEY ada, selain itu edge-tts (tanpa kunci).
"""
import asyncio
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

START_AT = 0.5   # detik, mulai narasi pertama
GAP = 0.35       # jeda antar kalimat
TAIL = 0.2       # subtitle bertahan sedikit setelah suara selesai
END_PAD = 1.0    # video berakhir sedikit setelah narasi terakhir

DEFAULT_VOICES = {"id": "id-ID-ArdiNeural", "en": "en-US-GuyNeural"}


def tts_edge(text, voice, path):
    import edge_tts  # dipasang lewat pip di workflow

    async def run():
        await edge_tts.Communicate(text, voice).save(path)

    asyncio.run(run())


def tts_elevenlabs(text, path):
    key = os.environ["ELEVENLABS_API_KEY"].strip()
    voice_id = os.environ.get("ELEVENLABS_VOICE_ID", "JBFqnCBsd6RMkjVDRZzb")
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
    body = json.dumps({"text": text, "model_id": "eleven_multilingual_v2"}).encode("utf-8")
    req = urllib.request.Request(
        url, data=body,
        headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp, open(path, "wb") as out:
            out.write(resp.read())
    except urllib.error.HTTPError as err:
        raise RuntimeError(f"ElevenLabs menolak (kode {err.code})") from err


def synthesize(text, language, path):
    if os.environ.get("ELEVENLABS_API_KEY", "").strip():
        tts_elevenlabs(text, path)
    else:
        voice = os.environ.get("VOICE") or DEFAULT_VOICES.get(language, DEFAULT_VOICES["id"])
        tts_edge(text, voice, path)


def estimate_duration(text):
    """Perkiraan lama baca (detik) bila suara tidak dibuat."""
    return max(1.5, len(text.split()) * 0.4)


def audio_duration(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", path],
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    return float(out)


def retime(items, durations):
    """Hitung start/end baru untuk item narasi. durations: {indeks_item: detik}."""
    t = START_AT
    for idx in sorted(durations):
        items[idx]["start"] = round(t, 2)
        items[idx]["end"] = round(t + durations[idx] + TAIL, 2)
        t = items[idx]["end"] + GAP
    return items


def mix(files_and_starts, out_wav):
    cmd = ["ffmpeg", "-y", "-v", "error"]
    for path, _ in files_and_starts:
        cmd += ["-i", path]
    parts, labels = [], []
    for i, (_, start) in enumerate(files_and_starts):
        ms = int(round(start * 1000))
        parts.append(f"[{i}:a]adelay={ms}|{ms}[a{i}]")
        labels.append(f"[a{i}]")
    if len(files_and_starts) == 1:
        graph = parts[0].replace("[a0]", "[out]")
    else:
        graph = ";".join(parts) + ";" + "".join(labels) + \
            f"amix=inputs={len(files_and_starts)}:normalize=0:dropout_transition=0[out]"
    cmd += ["-filter_complex", graph, "-map", "[out]", "-ar", "44100", "-ac", "2", out_wav]
    subprocess.run(cmd, check=True)


def main():
    if len(sys.argv) != 4:
        sys.exit("Pemakaian: narrate.py adegan.json adegan_waktu.json narasi.wav")
    src, dst, wav = sys.argv[1:4]
    with open(src, encoding="utf-8") as f:
        scene = json.load(f)
    items = scene.get("items", [])
    narrated = [i for i, it in enumerate(items)
                if it.get("narrate") and str(it.get("text", "")).strip()]
    if not narrated:
        print("Tidak ada item narrate, narasi dilewati.")
        with open(dst, "w", encoding="utf-8") as f:
            json.dump(scene, f, ensure_ascii=False, indent=2)
        return

    language = scene.get("language", "id")
    want_audio = os.environ.get("NARRATE_AUDIO", "1") != "0"
    durations, files = {}, {}
    if want_audio:
        try:
            with tempfile.TemporaryDirectory() as tmp:
                for n, idx in enumerate(narrated):
                    path = os.path.join(tmp, f"n{n}.mp3")
                    text = str(items[idx].get("voice") or items[idx]["text"])
                    synthesize(text, language, path)
                    durations[idx] = audio_duration(path)
                    files[idx] = path
                retime(items, durations)
                mix([(files[idx], items[idx]["start"]) for idx in sorted(files)], wav)
        except Exception as err:  # noqa: BLE001 - apa pun kegagalannya, lanjut tanpa suara
            print(f"PERINGATAN: suara gagal dibuat ({err}). Waktu subtitle diperkirakan.", file=sys.stderr)
            want_audio = False
            if os.path.exists(wav):
                os.remove(wav)
    if not want_audio:
        durations = {idx: estimate_duration(str(items[idx].get("voice") or items[idx]["text"]))
                     for idx in narrated}
        retime(items, durations)

    ends = [float(it.get("end", 0)) for it in items if "end" in it]
    scene["duration"] = round(max(ends) + END_PAD, 2)
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(scene, f, ensure_ascii=False, indent=2)
    mode = "dengan suara" if want_audio else "tanpa suara (waktu diperkirakan)"
    print(f"Narasi: {len(narrated)} kalimat {mode}, durasi video {scene['duration']} detik.")


if __name__ == "__main__":
    main()
