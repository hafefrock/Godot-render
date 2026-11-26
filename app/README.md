# Video AI (aplikasi Godot)

Aplikasi video: tulis cerita, AI membuat adegannya, edit dengan timeline, lalu render di cloud.
Adegan memakai format `scene.json` yang sama dengan proyek render di folder induk.

## Menjalankan di editor Godot (HP)
1. Unduh ZIP repo ini, ekstrak, lalu **Import** file `app/project.godot`.
2. Tekan **Play**.
3. Di layar awal tekan **Pengaturan**: isi kunci Gemini (untuk AI) dan token GitHub (untuk render).
4. Tulis cerita, tekan **Buat video dengan AI**.

## Fitur versi 0.1
- Layar awal: tulis cerita atau buka proyek tersimpan (otomatis tersimpan).
- Editor: pratinjau, putar, timeline (geser batang, tarik ujung untuk memotong), + Teks, + Kotak, Duplikat, Hapus, Urung/Ulang.
- Minta AI: ketik perintah untuk mengubah adegan.
- Render: kirim adegan ke repo dan jalankan workflow render.

Belum ada: gambar dari galeri, musik, rasio 9:16, ekspor APK otomatis.
