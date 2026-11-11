#!/bin/bash
# Membangun paket .deb (arsitektur "all") dari berkas di repositori ini.
#   packaging/build-deb.sh          -> dist/edgenotes_<versi>_all.deb
# Butuh: dpkg-deb (dan fakeroot, opsional). Versi diambil dari VERSION di skrip edgenotes.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(sed -n 's/^VERSION = "\(.*\)"/\1/p' "$ROOT/edgenotes" | head -1)
[ -n "$VERSION" ] || { echo "VERSION tidak ditemukan di edgenotes" >&2; exit 1; }
PKG=edgenotes
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
OUT="$ROOT/dist"; mkdir -p "$OUT"

install -Dm755 "$ROOT/edgenotes"               "$STAGE/usr/bin/edgenotes"
install -Dm644 "$ROOT/data/edgenotes.desktop"  "$STAGE/usr/share/applications/edgenotes.desktop"
install -Dm644 "$ROOT/data/edgenotes.svg"      "$STAGE/usr/share/icons/hicolor/scalable/apps/edgenotes.svg"
install -Dm644 "$ROOT/data/qris.jpg"           "$STAGE/usr/share/edgenotes/qris.jpg"
install -Dm644 "$ROOT/README.md"               "$STAGE/usr/share/doc/$PKG/README.md"
install -Dm644 "$ROOT/README.id.md"            "$STAGE/usr/share/doc/$PKG/README.id.md"

cat > "$STAGE/usr/share/doc/$PKG/copyright" <<'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: EdgeNotes
Source: https://github.com/ibeeng/edgenotes

Files: *
Copyright: 2026 ibedes and EdgeNotes contributors
License: GPL-3+
 This program is free software: you can redistribute it and/or modify it under
 the terms of the GNU General Public License as published by the Free Software
 Foundation, either version 3 of the License, or (at your option) any later
 version.
 .
 On Debian systems, the complete text of the GNU General Public License
 version 3 can be found in /usr/share/common-licenses/GPL-3.
EOF

chmod 644 "$STAGE/usr/share/doc/$PKG/copyright"
mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: utils
Priority: optional
Architecture: all
Depends: python3 (>= 3.8), python3-gi, python3-gi-cairo, python3-cairo, gir1.2-gtk-3.0
Recommends: gir1.2-wnck-3.0
Maintainer: ibeeng <ibeeng@users.noreply.github.com>
Homepage: https://github.com/ibeeng/edgenotes
Description: Sticky notes that live on the edge of your screen
 EdgeNotes docks a thin strip to the screen edge. Hover to fan out colored
 tabs, peek at a note, click to edit. Reminders, quick search, groups,
 checklists, images, version history, light and dark themes.
 .
 Notes stay on your computer: no account, no cloud, no network access.
EOF

# izin berkas/folder seragam
find "$STAGE" -type d -exec chmod 755 {} +
FILE="$OUT/${PKG}_${VERSION}_all.deb"
if command -v fakeroot >/dev/null; then
  fakeroot dpkg-deb --build -Zxz --root-owner-group "$STAGE" "$FILE" >/dev/null
else
  dpkg-deb --build -Zxz --root-owner-group "$STAGE" "$FILE" >/dev/null
fi
echo "dibangun: $FILE ($(du -h "$FILE" | cut -f1))"
