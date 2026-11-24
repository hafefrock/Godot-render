#!/usr/bin/env bash
# Pemakaian: bash render.sh [adegan.json] [hasil.mp4]
# Butuh: godot (Linux), xvfb, ffmpeg.
set -euo pipefail

SCENE="${1:-res://scene.json}"
OUT="${2:-out.mp4}"
FPS="${FPS:-30}"
GODOT="${GODOT:-godot}"

rm -rf frames
mkdir frames

# Siapkan cache proyek (boleh gagal, tidak fatal).
"$GODOT" --headless --path . --import || true

# Render tiap frame jadi gambar PNG (kualitas penuh) lewat layar virtual.
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . \
  --rendering-driver opengl3 --audio-driver Dummy \
  --write-movie "$PWD/frames/out.png" --fixed-fps "$FPS" \
  -- --scene="$SCENE"

echo "Jumlah frame: $(ls frames/*.png | wc -l)"

# Gabungkan jadi mp4 (H.264).
ffmpeg -y -framerate "$FPS" -pattern_type glob -i 'frames/out*.png' \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart "$OUT"

echo "Selesai: $OUT"
