#!/bin/sh
# Install PS Vita firmware PUP files for Vita3K.
# Put PSP2UPDAT.PUP files in /userdata/bios/psvita or /storage/roms/bios/vita3k first.

VITA3K=/usr/bin/vita3k/Vita3K
[ -x "$VITA3K" ] || VITA3K=/usr/bin/Vita3K

for DIR in /userdata/bios/psvita /storage/roms/bios/vita3k; do
    [ -d "$DIR" ] || continue
    for FW in "$DIR"/*.PUP; do
        [ -f "$FW" ] || continue
        "$VITA3K" --firmware "$FW"
    done
done
