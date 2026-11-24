# godot-render

Mengubah cerita atau file adegan JSON menjadi video mp4 memakai Godot, FFmpeg, dan (opsional) AI.

## Cara pakai (dari HP)
Tab **Actions** > **Render video** > **Run workflow**. Ada tiga kotak isian:

1. **Cerita**: tulis ceritamu di sini, dan Gemini membuat adegannya. Kosongkan untuk memakai file adegan di repo.
2. **Suara narasi**: `ya` atau `tidak`.
3. **File adegan**: dipakai kalau cerita kosong (bawaan `res://scene.json`, contoh narasi: `res://contoh_narasi.json`).

Setelah hijau, unduh artifact **video** (zip berisi `out.mp4`). Artifact **adegan** berisi JSON yang dipakai, supaya bisa disimpan dan diubah.

## Kunci (Settings > Secrets and variables > Actions > Secrets)
- `GEMINI_API_KEY`: wajib kalau memakai kotak Cerita.
- `ELEVENLABS_API_KEY`: opsional. Tanpa ini, suara memakai edge-tts (gratis). `ELEVENLABS_VOICE_ID` bisa diisi untuk memilih suara.

## Format adegan
- `duration`, `background` (`#RRGGBB`), `language` (`id`/`en`, memilih suara).
- `items`: daftar objek, ditumpuk sesuai urutan.
  - Umum: `x`, `y`, `start`, `end`, `fade`, `to_x`, `to_y` (bergerak selama tampil), `zoom_from`, `zoom_to`.
  - `type: text`: `text`, `size`, `color`, `w`, `align`, `outline`.
    `narrate: true` membacakan teksnya, dan `start`/`end` dihitung otomatis. `voice` mengganti teks yang dibaca.
  - `type: rect`: `w`, `h`, `color`.
  - `type: image`: `src` (mis. `assets/latar.jpg`, simpan di repo), `w`, `h` (bawaan 1280x720, mengisi penuh tanpa gepeng).

Ukuran video tetap 1280x720, 30 FPS.
