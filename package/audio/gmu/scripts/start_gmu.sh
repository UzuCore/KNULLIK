#!/bin/sh
# KNULLI GMU launcher.  Adapted from the ROCKNIX GMU launcher for /userdata.

set -eu

USERDATA="${KNULLI_USERDATA_DIR:-/userdata}"
GMU_USER_DIR="${USERDATA}/system/.config/gmu"
GMU_SHARE_DIR="/usr/share/gmu"
GMU_DEFAULT_DIR="${GMU_SHARE_DIR}/defaults"
GMUCONFIG="${GMU_USER_DIR}/gmu.conf"
MUSIC_DIR="${USERDATA}/music"

msg() {
    if command -v message_stream >/dev/null 2>&1; then
        message_stream "$1"
    else
        echo "$1"
    fi
}

show_error() {
    if command -v text_viewer >/dev/null 2>&1; then
        text_viewer -t "GMU Music Player" -m "$1"
    else
        echo "$1" >&2
    fi
}

get_fb_size() {
    if [ -r /sys/class/graphics/fb0/virtual_size ]; then
        sed 's/,/ /' /sys/class/graphics/fb0/virtual_size
        return 0
    fi
    if command -v fbset >/dev/null 2>&1; then
        fbset 2>/dev/null | awk '
            /geometry/ { print $2, $3; found=1; exit }
            END { if (!found) exit 1 }
        ' && return 0
    fi
    echo "640 480"
}

if [ ! -x /usr/bin/gmu.bin ]; then
    show_error "GMU binary is missing: /usr/bin/gmu.bin"
    exit 1
fi

mkdir -p "$GMU_USER_DIR" "$MUSIC_DIR" "${GMU_USER_DIR}/playlists"

# Seed user config once.  Keep user edits on later runs.
for f in gmu.conf gmuinput.conf caanoo.keymap; do
    if [ ! -f "${GMU_USER_DIR}/${f}" ] && [ -f "${GMU_DEFAULT_DIR}/${f}" ]; then
        cp -f "${GMU_DEFAULT_DIR}/${f}" "${GMU_USER_DIR}/${f}"
    fi
done

# If no default config came from the package/source, create a minimal SDL config.
if [ ! -f "$GMUCONFIG" ]; then
    cat > "$GMUCONFIG" <<'EOF'
SDL.Width=640
SDL.Height=480
SDL.Fullscreen=yes
Skin=default-modern-large
EOF
fi

set -- $(get_fb_size)
FBWIDTH="${1:-640}"
FBHEIGHT="${2:-480}"

# Keep these substitutions tolerant: older/newer GMU configs may omit keys.
grep -q '^SDL.Width=' "$GMUCONFIG" && \
    sed -i "s~^SDL.Width=.*$~SDL.Width=${FBWIDTH}~" "$GMUCONFIG" || \
    printf 'SDL.Width=%s\n' "$FBWIDTH" >> "$GMUCONFIG"

grep -q '^SDL.Height=' "$GMUCONFIG" && \
    sed -i "s~^SDL.Height=.*$~SDL.Height=${FBHEIGHT}~" "$GMUCONFIG" || \
    printf 'SDL.Height=%s\n' "$FBHEIGHT" >> "$GMUCONFIG"

grep -q '^SDL.Fullscreen=' "$GMUCONFIG" && \
    sed -i 's~^SDL.Fullscreen=.*$~SDL.Fullscreen=yes~' "$GMUCONFIG" || \
    printf 'SDL.Fullscreen=yes\n' >> "$GMUCONFIG"

# ROCKNIX Korean branch prefers the large modern skin on handheld displays.
if grep -q 'default-modern' "$GMUCONFIG"; then
    sed -i 's~default-modern[^[:space:]]*~default-modern-large~g' "$GMUCONFIG"
fi

PLAYLIST=""
if [ "${1:-}" ] && [ -f "${1:-}" ]; then
    PLAYLIST="$1"
fi

msg "Starting GMU Music Player..."
cd "$GMU_SHARE_DIR" 2>/dev/null || cd /tmp
exec /usr/bin/gmu.bin -d "$GMU_USER_DIR" -c "$GMUCONFIG" ${PLAYLIST}
