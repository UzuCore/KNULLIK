#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(pwd)}"

echo "Applying ROCKNIXK Batocera overlay..."

# ---------------------------------------------------------------------------
# 1) Silence optional ES API-key warnings.
#
# These files are optional local API key holders.  Some build steps grep them.
# Empty files are safe and avoid noisy "No such file or directory" messages.
# ---------------------------------------------------------------------------
mkdir -p "${ROOT}/package/emulationstation/knulli-emulationstation"
mkdir -p "${ROOT}/package/batocera/emulationstation/batocera-emulationstation"
: > "${ROOT}/package/emulationstation/knulli-emulationstation/keys.txt"
: > "${ROOT}/package/batocera/emulationstation/batocera-emulationstation/keys.txt"

# ---------------------------------------------------------------------------
# 2) ScummVM Ultima8 Korean binary patch.
#
# Buildroot applies *.patch files with normal patch(1), which cannot handle
# Git binary patches.  Keep the binary patch as *.gitpatch and apply it from
# scummvm.mk with "git apply --binary".
# ---------------------------------------------------------------------------
SCUMM_DIR="${ROOT}/package/batocera/emulators/scummvm"
SCUMM_MK="${SCUMM_DIR}/scummvm.mk"
SCUMM_GITPATCH="${SCUMM_DIR}/002-ultima8-korean.gitpatch"
SCUMM_NORMAL_PATCH="${SCUMM_DIR}/002-ultima8-korean.patch"

if [ -f "${SCUMM_GITPATCH}" ] && [ -f "${SCUMM_MK}" ]; then
  if [ -f "${SCUMM_NORMAL_PATCH}" ]; then
    mv -f "${SCUMM_NORMAL_PATCH}" "${SCUMM_NORMAL_PATCH}.disabled"
    echo "Disabled normal Ultima8 patch; using git binary patch instead"
  fi

  if ! grep -q "002-ultima8-korean.gitpatch" "${SCUMM_MK}"; then
    cat >> "${SCUMM_MK}" <<'EOF'

# ROCKNIXK: apply Ultima8 Korean Git binary patch after normal patches.
define SCUMMVM_APPLY_ULTIMA8_KOREAN_GITPATCH
	cd $(@D) && git apply --binary --whitespace=nowarn $(SCUMMVM_PKGDIR)/002-ultima8-korean.gitpatch
endef
SCUMMVM_POST_PATCH_HOOKS += SCUMMVM_APPLY_ULTIMA8_KOREAN_GITPATCH
EOF
    echo "Updated scummvm.mk: 002-ultima8-korean.gitpatch will be applied with git apply --binary"
  else
    echo "scummvm.mk already contains Ultima8 git binary patch hook"
  fi
fi

# ---------------------------------------------------------------------------
# 3) knulli-es-system Korean translation overlay.
#
# Keep the maintained translation under rocknixk/locales and copy it over the
# generated/locales tree before building.  This avoids keeping generated .po
# changes dirty while still applying the Korean translation for each build.
# ---------------------------------------------------------------------------
KNULLI_ES_SYSTEM_DIR="${ROOT}/package/emulationstation/knulli-es-system"
KNULLI_ES_SYSTEM_PO_SRC="${KNULLI_ES_SYSTEM_DIR}/rocknixk/locales/ko_KR/knulli-es-system.po"
KNULLI_ES_SYSTEM_PO_DST="${KNULLI_ES_SYSTEM_DIR}/locales/ko_KR/knulli-es-system.po"

if [ -f "${KNULLI_ES_SYSTEM_PO_SRC}" ]; then
  mkdir -p "$(dirname "${KNULLI_ES_SYSTEM_PO_DST}")"
  cp -f "${KNULLI_ES_SYSTEM_PO_SRC}" "${KNULLI_ES_SYSTEM_PO_DST}"
  echo "Applied Korean knulli-es-system.po overlay"
fi

echo "ROCKNIXK overlay done."
