#!/bin/bash
# Merekam tangkapan layar dan GIF demo EdgeNotes di layar virtual (Xephyr), memakai catatan demo
# docs/demo/notes.json. Tidak menyentuh catatan asli dan tidak merekam desktop yang sebenarnya.
#
#   tools/capture-demo.sh            # semua (png + gif) ke docs/img
#   tools/capture-demo.sh shots      # hanya png
#   tools/capture-demo.sh gif        # hanya gif
#
# Butuh: Xephyr, xfwm4, xdotool, imagemagick (import/convert/display), ffmpeg, python3.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
MODE=${1:-all}
OUT=${OUT:-$ROOT/docs/img}
W=1200; H=675; D=:77

# Tiap tema dan GIF dijalankan sebagai proses (dan sesi D-Bus) terpisah: dua sesi berturut-turut dalam
# satu sesi D-Bus kadang gagal karena instance aplikasi sebelumnya masih terdaftar.
if [ -z "${EN_INNER:-}" ] && { [ "$MODE" = all ] || [ "$MODE" = shots ]; }; then
  "$0" light && "$0" dark && { [ "$MODE" = shots ] || "$0" gif; }
  exit $?
fi

# Jalan di dalam sesi D-Bus sendiri supaya terisolasi dari sesi desktop sungguhan.
if [ -z "${EN_INNER:-}" ]; then
  exec env EN_INNER=1 dbus-run-session -- "$0" "$@"
fi

T=$(mktemp -d)
# Di sesi D-Bus terpisah tidak ada layanan portal; tanpa ini GTK menunggu ~25 detik saat start.
export GTK_USE_PORTAL=0 NO_AT_BRIDGE=1 GIO_USE_PORTALS=0
export XDG_DATA_HOME=$T/data XDG_CONFIG_HOME=$T/cfg XDG_RUNTIME_DIR=$T/run XDG_CACHE_HOME=$T/cache
mkdir -p "$XDG_DATA_HOME/edgenotes" "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR" "$XDG_CACHE_HOME" "$OUT"
chmod 700 "$XDG_RUNTIME_DIR"
PIDS=()   # hanya proses yang kita mulai sendiri; JANGAN pkill berdasarkan nama (bisa mengenai desktop asli)
killmine() {
  local p
  for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done
  for p in "${PIDS[@]:-}"; do [ -n "$p" ] && wait "$p" 2>/dev/null; done
  PIDS=()
  for _ in $(seq 1 40); do xdpyinfo -display $D >/dev/null 2>&1 || break; sleep 0.25; done
}
cleanup() { killmine; rm -rf "$T"; }
trap cleanup EXIT

prepare_data() {   # $1 = light|dark
  python3 -I - "$ROOT/docs/demo/notes.json" "$XDG_DATA_HOME/edgenotes" "$1" <<'PY'
import json, sys, time, datetime
src, dst, theme = sys.argv[1:4]
d = json.load(open(src, encoding="utf-8"))
now = time.time()
tomorrow = (datetime.datetime.now() + datetime.timedelta(days=1)).replace(hour=9, minute=0, second=0, microsecond=0)
soon = (datetime.datetime.now() + datetime.timedelta(days=3)).replace(hour=8, minute=0, second=0, microsecond=0)
for n in d["notes"]:
    n["created"] = n["updated"] = now - (9 - n["order"]) * 3600
    if n["reminder"] is not None:
        n["reminder"] = (tomorrow if n["group"] == "Work" else soon).timestamp()
json.dump(d, open(dst + "/notes.json", "w", encoding="utf-8"), ensure_ascii=False)
json.dump({"side": "right", "lang": "en", "theme": theme, "font": "system", "font_size": 11,
           "sort": "manual", "hide_fullscreen": True, "schema": 3, "group_filter": "", "hub_tab": "notes"},
          open(dst + "/config.json", "w"))
PY
}

wallpaper() {      # $1 = light|dark  -> $T/bg.png : gradasi lembut + jendela tiruan supaya strip terlihat "di atas pekerjaan"
  local a b win bar line
  if [ "$1" = dark ]; then a='#1b2030'; b='#3a2f55'; win='#252a3a'; bar='#2f3550'; line='#3b425c'
  else a='#cfe3ff'; b='#f3d9f0'; win='#ffffff'; bar='#eef1f6'; line='#dfe4ee'; fi
  convert -size ${W}x${H} gradient:"$a-$b" \
    -fill "$win" -stroke "$line" -draw "roundrectangle 90,70 880,610 12,12" \
    -fill "$bar" -stroke none -draw "roundrectangle 90,70 880,112 12,12" -draw "rectangle 90,100 880,112" \
    -fill "$line" -draw "circle 118,91 118,85" -draw "circle 140,91 140,85" -draw "circle 162,91 162,85" \
    -fill "$line" \
    -draw "roundrectangle 130,150 520,166 8,8" -draw "roundrectangle 130,190 700,204 7,7" \
    -draw "roundrectangle 130,224 640,238 7,7" -draw "roundrectangle 130,258 720,272 7,7" \
    -draw "roundrectangle 130,310 480,326 8,8" -draw "roundrectangle 130,350 690,364 7,7" \
    -draw "roundrectangle 130,384 610,398 7,7" -draw "roundrectangle 130,418 740,432 7,7" \
    -draw "roundrectangle 130,452 560,466 7,7" -draw "roundrectangle 130,500 460,516 8,8" \
    -draw "roundrectangle 130,540 700,554 7,7" \
    "$T/bg.png"
}

start_display() {  # $1 = light|dark
  Xephyr $D -ac -br -screen ${W}x${H} -title "EdgeNotes demo (virtual)" >"$T/xephyr.log" 2>&1 &
  PIDS+=($!)
  for _ in $(seq 1 40); do xdpyinfo -display $D >/dev/null 2>&1 && break; sleep 0.25; done
  export DISPLAY=$D GDK_BACKEND=x11
  wallpaper "$1"
  xfwm4 --display $D --compositor=on >"$T/xfwm4.log" 2>&1 &
  PIDS+=($!)
  sleep 2
  show_wallpaper
  sleep 0.8
}

# wallpaper sebagai jendela bertipe DESKTOP (rendah, memenuhi layar); lebih andal daripada `display -window root`
show_wallpaper() {
  python3 -I - "$T/bg.png" "$W" "$H" >"$T/bg.log" 2>&1 <<'WALLPAPER' &
import sys, gi
gi.require_version("Gtk", "3.0"); gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GdkPixbuf
path, w, h = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
win = Gtk.Window()
win.set_type_hint(Gdk.WindowTypeHint.DESKTOP)
win.set_decorated(False); win.set_default_size(w, h); win.move(0, 0)
win.add(Gtk.Image.new_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file(path)))
win.connect("destroy", Gtk.main_quit); win.show_all(); Gtk.main()
WALLPAPER
  PIDS+=($!)
}

start_app() {
  python3 "$ROOT/edgenotes" >"$T/app.log" 2>&1 &
  PIDS+=($!)
  # tunggu sampai jendela strip ("EdgeNotes") benar-benar ada, maksimal 40 detik
  for _ in $(seq 1 160); do xwininfo -root -tree 2>/dev/null | grep -q '"EdgeNotes"' && break; sleep 0.25; done
  sleep 1.5
}

stop_all() {
  python3 "$ROOT/edgenotes" --quit >/dev/null 2>&1; sleep 0.6
  killmine; sleep 0.8
}

shot() { import -window root "$OUT/$1.png"; }

# gerakkan pointer pelan-pelan (x0 y0 -> x1 y1) supaya terbaca sebagai gerakan nyata
glide() { # x0 y0 x1 y1 langkah jeda_dtk
  local x0=$1 y0=$2 x1=$3 y1=$4 n=${5:-12} dt=${6:-0.02} i
  for i in $(seq 1 $n); do
    xdotool mousemove $(( x0 + (x1 - x0) * i / n )) $(( y0 + (y1 - y0) * i / n )); sleep "$dt"
  done
}

STRIP_X=$((W - 14))     # tepi kanan layar virtual
PLUS_Y=616              # tombol "+" (menahan strip tetap terbuka tanpa memicu kartu)
NEUTRAL_X=600; NEUTRAL_Y=640

collapse() {            # keluar dari strip dan tunggu sampai kembali jadi pil
  xdotool mousemove $NEUTRAL_X $NEUTRAL_Y; sleep 1.6
}

fan_open() {            # masuk lewat pil di tengah, tunggu tab mengembang (tanpa memicu kartu)
  collapse
  glide $NEUTRAL_X $NEUTRAL_Y $STRIP_X 340 14 0.02; sleep 1.5
}

peek_at() {             # $1 = y tab di tata letak dasar; lompat langsung supaya posisinya pasti
  fan_open
  xdotool mousemove $STRIP_X $1; sleep 1.2
}

# potongan untuk README: pita strip (kanan), editor, jendela Notes
crop_strip()  { convert "$1" -crop 420x675+780+0 +repage "$2"; }

shots_for() {           # $1 = light|dark
  local t=$1 f="$T/f-$1"; mkdir -p "$f"
  prepare_data "$t"; start_display "$t"; start_app

  collapse;               import -window root "$f/rest.png"
  fan_open;               import -window root "$f/fan.png"
  peek_at 232;            import -window root "$f/call.png"
  peek_at 60;             import -window root "$f/launch.png"
  peek_at 160
  xdotool click 1; sleep 2.4;  import -window root "$f/editor.png"
  python3 "$ROOT/edgenotes" --hide >/dev/null 2>&1; sleep 0.8
  collapse
  python3 "$ROOT/edgenotes" --all >/dev/null 2>&1;      sleep 1.8; import -window root "$f/notes.png"
  python3 "$ROOT/edgenotes" --settings >/dev/null 2>&1; sleep 1.8; import -window root "$f/settings.png"
  stop_all

  # --- susun hasil akhir ---
  for n in rest fan call launch; do crop_strip "$f/$n.png" "$f/s-$n.png"; done
  local gap='#ffffff'; [ "$t" = dark ] && gap='#0e1020'
  convert "$f/s-rest.png" \( -size 14x675 xc:"$gap" \) "$f/s-fan.png" \( -size 14x675 xc:"$gap" \) \
          "$f/s-call.png" \( -size 14x675 xc:"$gap" \) "$f/s-launch.png" +append \
          -resize 1400x "$OUT/strip-$t.png"
  convert "$f/editor.png"   -crop 560x470+290+85 +repage "$OUT/editor-$t.png"
  convert "$f/notes.png"    -crop 580x675+0+0 +repage "$OUT/notes-$t.png"
  convert "$f/settings.png" -crop 580x675+0+0 +repage "$OUT/settings-$t.png"
  cp "$f/editor.png" "$T/last-editor-$t.png" 2>/dev/null
  echo "ok: strip/editor/notes/settings ($t)"
}

record_gif() {
  prepare_data light; start_display light; start_app
  local raw="$T/raw.mp4"
  xdotool mousemove $NEUTRAL_X $NEUTRAL_Y; sleep 0.6
  ffmpeg -y -loglevel error -f x11grab -draw_mouse 1 -framerate 25 -video_size ${W}x${H} -i $D \
         -t 17 -vf "crop=trunc(iw/2)*2:trunc(ih/2)*2:0:0" -c:v libx264 -preset ultrafast -crf 17 -pix_fmt yuv420p "$raw" 2>"$T/ffrec.log" &
  local FF=$!; PIDS+=($FF)
  sleep 1.6                                                           # diam: pil di tepi layar
  glide $NEUTRAL_X $NEUTRAL_Y $STRIP_X 340 24 0.025; sleep 1.7        # masuk -> tab mengembang berurutan
  xdotool mousemove $STRIP_X 232; sleep 1.9                           # kartu: Call Sam (pengingat + grup)
  glide $STRIP_X 232 $STRIP_X 470 26 0.045; sleep 0.9                 # menyusuri tab: kartu berpindah mulus
  glide $STRIP_X 470 $STRIP_X 300 18 0.045; sleep 1.2
  xdotool click 1; sleep 3.0                                          # buka editor, biarkan tampil
  python3 "$ROOT/edgenotes" --hide >/dev/null 2>&1; sleep 0.9         # tutup editor
  glide $STRIP_X 300 $NEUTRAL_X $NEUTRAL_Y 14 0.03                    # pointer keluar -> strip menutup
  wait $FF 2>/dev/null
  [ -s "$T/ffrec.log" ] && { echo "--- log perekam ffmpeg ---"; head -8 "$T/ffrec.log"; }
  ffprobe -v error -show_entries format=duration -of csv=p=0 "$raw" 2>&1 | sed 's/^/durasi rekaman (dtk): /'
  stop_all
  ffmpeg -y -loglevel error -i "$raw" \
    -vf "fps=14,scale=900:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
    "$OUT/demo.gif"
  ls -la "$OUT/demo.gif" | awk '{printf "ok: demo.gif %.1f MB\n", $5/1048576}'
}

case "$MODE" in
  shots) shots_for light; shots_for dark ;;
  light) shots_for light ;;
  dark)  shots_for dark ;;
  gif)   record_gif ;;
  all)   shots_for light; shots_for dark; record_gif ;;
  *)     echo "pakai: $0 [all|shots|gif]"; exit 1 ;;
esac
