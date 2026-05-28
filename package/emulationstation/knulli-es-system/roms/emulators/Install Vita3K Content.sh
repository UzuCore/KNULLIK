#!/bin/sh
# Install PS Vita zip content for Vita3K.
# Put installable .zip files in /userdata/roms/psvita first.

VITA3K=/usr/bin/vita3k/Vita3K
[ -x "$VITA3K" ] || VITA3K=/usr/bin/Vita3K
ROMS_PATH=/userdata/roms/psvita
[ -d "$ROMS_PATH" ] || ROMS_PATH=/storage/roms/psvita

for FILE in "$ROMS_PATH"/*.zip; do
    [ -f "$FILE" ] || continue
    echo "Installing $FILE"
    "$VITA3K" "$FILE"
done
