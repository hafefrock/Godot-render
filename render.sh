#!/usr/bin/env bash
# Pemakaian: bash render.sh [adegan.json] [hasil.mp4]
# Variabel opsional:
#   STORY      cerita; kalau diisi, adegan dibuat AI (butuh GEMINI_API_KEY)
#   NARRATION  "ya" untuk suara narasi (item dengan "narrate": true)
#   FPS, GODOT
set -euo pipefail

SCENE="${1:-res://scene.json}"
OUT="${2:-out.mp4}"
FPS="${FPS:-30}"
GODOT="${GODOT:-godot}"
NARRATION="${NARRATION:-tidak}"
STORY="${STORY:-}"

rm -rf frames build
mkdir frames build

# 1. Adegan: dari cerita (AI) atau dari file di repo.
if [ -n "$STORY" ]; then
  python3 tools/make_scene.py "$STORY" build/scene.json
  SCENE_FILE="build/scene.json"
else
  SCENE_FILE="${SCENE#res://}"
fi
[ -f "$SCENE_FILE" ] || { echo "File adegan tidak ada: $SCENE_FILE"; exit 1; }

# 2. Waktu adegan. Item "narrate": true diberi waktu otomatis.
#    NARRATION=ya  -> ada suara (bila gagal, tetap jalan tanpa suara)
#    selain itu    -> tanpa suara, waktu diperkirakan dari panjang teks
AUDIO=""
if [ "$NARRATION" = "ya" ]; then export NARRATE_AUDIO=1; else export NARRATE_AUDIO=0; fi
python3 tools/narrate.py "$SCENE_FILE" build/scene_timed.json build/narration.wav
SCENE_FILE="build/scene_timed.json"
[ -f build/narration.wav ] && AUDIO="build/narration.wav"

# 3. Siapkan cache proyek (boleh gagal, tidak fatal).
"$GODOT" --headless --path . --import || true

# 4. Render tiap frame jadi PNG lewat layar virtual.
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . \
  --rendering-driver opengl3 --audio-driver Dummy \
  --write-movie "$PWD/frames/out.png" --fixed-fps "$FPS" \
  -- --scene="$PWD/$SCENE_FILE"

echo "Jumlah frame: $(ls frames/*.png | wc -l)"

# 5. Gabungkan jadi mp4 (H.264), dengan suara bila ada.
if [ -n "$AUDIO" ]; then
  ffmpeg -y -framerate "$FPS" -pattern_type glob -i 'frames/out*.png' -i "$AUDIO" \
    -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -b:a 160k \
    -af apad -shortest -movflags +faststart "$OUT"
else
  ffmpeg -y -framerate "$FPS" -pattern_type glob -i 'frames/out*.png' \
    -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart "$OUT"
fi

echo "Selesai: $OUT"
