#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"
ROOT="$(cd "$ROOT" && pwd)"

echo "Applying ROCKNIXK Batocera overlay..."

# -----------------------------------------------------------------------------
# Local-only ignore rules for generated/private build helper files.
# Keep Wi-Fi credentials and generated overlays out of commits.
# -----------------------------------------------------------------------------
INFO_EXCLUDE="${ROOT}/.git/info/exclude"
if [ -d "${ROOT}/.git" ]; then
  mkdir -p "$(dirname "${INFO_EXCLUDE}")"
  touch "${INFO_EXCLUDE}"
  grep -qxF "wifi.txt" "${INFO_EXCLUDE}" || echo "wifi.txt" >> "${INFO_EXCLUDE}"
  grep -qxF "board/fsoverlay/etc/init.d/S31wifi-from-build" "${INFO_EXCLUDE}" || echo "board/fsoverlay/etc/init.d/S31wifi-from-build" >> "${INFO_EXCLUDE}"
fi

# -----------------------------------------------------------------------------
# Suppress optional EmulationStation API key warnings.
# -----------------------------------------------------------------------------
mkdir -p "${ROOT}/package/emulationstation/knulli-emulationstation"
mkdir -p "${ROOT}/package/batocera/emulationstation/batocera-emulationstation"
touch "${ROOT}/package/emulationstation/knulli-emulationstation/keys.txt"
touch "${ROOT}/package/batocera/emulationstation/batocera-emulationstation/keys.txt"

# -----------------------------------------------------------------------------
# ScummVM Ultima8 Korean binary patch hook.
# The patch contains GIT binary patch data, so normal Buildroot patch application
# is not enough. Add an idempotent post-patch hook to use git apply --binary.
# -----------------------------------------------------------------------------
SCUMM_DIR="${ROOT}/package/batocera/emulators/scummvm"
SCUMM_MK="${SCUMM_DIR}/scummvm.mk"
GITPATCH="${SCUMM_DIR}/002-ultima8-korean.gitpatch"

if [ -f "${SCUMM_MK}" ] && [ -f "${GITPATCH}" ]; then
  if ! grep -q "002-ultima8-korean.gitpatch" "${SCUMM_MK}"; then
    python3 - "${SCUMM_MK}" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
block = r'''

define SCUMMVM_APPLY_ULTIMA8_KOREAN_GITPATCH
	cd $(@D) && git apply --binary --whitespace=nowarn $(SCUMMVM_PKGDIR)/002-ultima8-korean.gitpatch
endef
SCUMMVM_POST_PATCH_HOOKS += SCUMMVM_APPLY_ULTIMA8_KOREAN_GITPATCH
'''
marker = '$(eval $(generic-package))'
if marker not in text:
    raise SystemExit(f"Could not find {marker} in {path}")
text = text.replace(marker, block + "\n" + marker, 1)
path.write_text(text)
PY
    echo "Updated scummvm.mk: 002-ultima8-korean.gitpatch will be applied with git apply --binary"
  fi
fi

# -----------------------------------------------------------------------------
# Korean translation overlay for knulli-es-system.
# Runtime ES locale on Knulli is 'ko' (not ko_KR), but keep both directories in
# sync to avoid language-code mismatches during generation.
# Managed source:
#   package/emulationstation/knulli-es-system/rocknixk/locales/ko_KR/knulli-es-system.po
# Build-time destinations:
#   package/emulationstation/knulli-es-system/locales/ko/knulli-es-system.po
#   package/emulationstation/knulli-es-system/locales/ko_KR/knulli-es-system.po
# -----------------------------------------------------------------------------
KNULLI_ES_SYSTEM_DIR="${ROOT}/package/emulationstation/knulli-es-system"
KNULLI_ES_SYSTEM_PO_SRC="${KNULLI_ES_SYSTEM_DIR}/rocknixk/locales/ko_KR/knulli-es-system.po"

if [ -f "${KNULLI_ES_SYSTEM_PO_SRC}" ]; then
  for lang in ko ko_KR; do
    dst="${KNULLI_ES_SYSTEM_DIR}/locales/${lang}/knulli-es-system.po"
    mkdir -p "$(dirname "${dst}")"
    cp -f "${KNULLI_ES_SYSTEM_PO_SRC}" "${dst}"
    echo "Applied Korean knulli-es-system.po overlay to ${lang}"
  done
fi

# -----------------------------------------------------------------------------
# Optional Wi-Fi preset overlay.
# Put wifi.txt at the repository root to bake a first-boot Wi-Fi configurator
# into the image. This is for local testing and is intentionally ignored by git.
#
# Supported wifi.txt formats:
#   wifi.ssid=MyWifi
#   wifi.key=MyPassword
#   wifi.country=KR
#
#   SSID=MyWifi
#   PASSWORD=MyPassword
#   COUNTRY=KR
#
#   MyWifi
#   MyPassword
#   KR
# -----------------------------------------------------------------------------
WIFI_TXT="${ROOT}/wifi.txt"
WIFI_INIT="${ROOT}/board/fsoverlay/etc/init.d/S31wifi-from-build"

if [ -f "${WIFI_TXT}" ]; then
  python3 - "${WIFI_TXT}" "${WIFI_INIT}" <<'PY'
from pathlib import Path
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])

raw_lines = src.read_text(encoding='utf-8', errors='ignore').replace('\r\n', '\n').replace('\r', '\n').split('\n')
kv = {}
plain = []

aliases = {
    'ssid': 'ssid',
    'wifi.ssid': 'ssid',
    'wifi_ssid': 'ssid',
    'password': 'password',
    'pass': 'password',
    'psk': 'password',
    'key': 'password',
    'wifi.key': 'password',
    'wifi.password': 'password',
    'wifi_pass': 'password',
    'country': 'country',
    'wifi.country': 'country',
    'wifi_country': 'country',
}

for line in raw_lines:
    s = line.strip()
    if not s or s.startswith('#') or s.startswith(';'):
        continue
    if '=' in s:
        k, v = s.split('=', 1)
        key = aliases.get(k.strip().lower())
        if key:
            val = v.strip()
            if (len(val) >= 2) and ((val[0] == val[-1] == '"') or (val[0] == val[-1] == "'")):
                val = val[1:-1]
            kv[key] = val
    else:
        plain.append(s)

ssid = kv.get('ssid') or (plain[0] if len(plain) >= 1 else '')
password = kv.get('password') or (plain[1] if len(plain) >= 2 else '')
country = kv.get('country') or (plain[2] if len(plain) >= 3 else 'KR')

if not ssid:
    raise SystemExit('wifi.txt found, but SSID is empty')

def shq(s: str) -> str:
    return "'" + s.replace("'", "'\\''") + "'"

script = f'''#!/bin/sh
# Auto-generated from repository-root wifi.txt by scripts/rocknixk-apply-batocera-overlay.sh.
# Do not commit this file; it may contain Wi-Fi credentials.

CONF="/userdata/system/knulli.conf"

set_setting() {{
    key="$1"
    value="$2"
    mkdir -p "$(dirname "$CONF")"
    touch "$CONF"
    tmp="${{CONF}}.tmp"
    grep -v "^${{key}}=" "$CONF" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$CONF"
    printf '%s=%s\n' "$key" "$value" >> "$CONF"
}}

set_setting wifi.enabled 1
set_setting wifi.ssid {shq(ssid)}
set_setting wifi.key {shq(password)}
set_setting wifi.country {shq(country)}

exit 0
'''

dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_text(script, encoding='utf-8')
dst.chmod(0o755)
print(f"Generated Wi-Fi preset init script from wifi.txt: {dst}")
PY
else
  # If wifi.txt was removed, also remove the generated private overlay file so
  # future builds do not keep stale credentials.
  if [ -f "${WIFI_INIT}" ]; then
    rm -f "${WIFI_INIT}"
    echo "Removed stale generated Wi-Fi preset init script"
  fi
fi
