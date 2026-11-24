# godot-render

Mengubah file adegan JSON menjadi video mp4 memakai Godot dan FFmpeg.

## Cara pakai (dari HP)
1. Ubah `scene.json` (teks, posisi, waktu tampil).
2. Buka tab **Actions**, pilih **Render video**, tekan **Run workflow**.
3. Setelah hijau, buka run-nya dan unduh artifact **video** (zip berisi `out.mp4`).

## Format scene.json
- `duration`: lama video (detik). `background`: warna latar (`#RRGGBB`).
- `items`: daftar objek.
  - `type`: `text` (bawaan) atau `rect`.
  - `x`, `y`: posisi. Opsional `to_x`, `to_y`: bergerak ke posisi itu selama tampil.
  - `start`, `end`: kapan muncul dan hilang (detik). `fade`: lama fade (detik, bawaan 0.3).
  - Teks: `text`, `size`, `color`, `w` (lebar), `align` (`left`/`center`/`right`), `outline`.
  - Kotak: `w`, `h`, `color`.

Ukuran video tetap 1280x720, 30 FPS.
