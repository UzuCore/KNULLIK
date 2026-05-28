#!/bin/sh
# ROCKNIXK/Knulli PPSSPP Korean font toggle.
# Font files are intentionally not bundled here.
# Put these files in /usr/config/ppsspp/assets if you want the toggle to copy them:
#   orig.jpn0.pgf orig.kr0.pgf patch.jpn0.pgf patch.kr0.pgf

SRC=/usr/config/ppsspp/assets
DST=/storage/.config/ppsspp/assets/flash0/font
mkdir -p "$DST"

copy_pair() {
    local jp="$1"
    local kr="$2"
    [ -f "$SRC/$jp" ] && cp -f "$SRC/$jp" "$DST/jpn0.pgf"
    [ -f "$SRC/$kr" ] && cp -f "$SRC/$kr" "$DST/kr0.pgf"
}

case "$1" in
    1|on|true|enabled|enable)
        copy_pair patch.jpn0.pgf patch.kr0.pgf
        ;;
    *)
        copy_pair orig.jpn0.pgf orig.kr0.pgf
        ;;
esac

exit 0
