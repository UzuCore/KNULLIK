#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
OVERLAY="${PROJECT_DIR}/overlays/rocknixk/batocera"
BATO="${PROJECT_DIR}/batocera"

if [ ! -d "${OVERLAY}" ]; then
  exit 0
fi

if [ ! -d "${BATO}/package" ]; then
  echo "ERROR: batocera submodule is not initialized." >&2
  echo "Run: git submodule update --init --recursive batocera buildroot" >&2
  exit 1
fi

echo "Applying ROCKNIXK Batocera overlay..."
cp -a "${OVERLAY}/." "${BATO}/"

SCUMM_DIR="${BATO}/package/batocera/emulators/scummvm"
SCUMM_MK="${SCUMM_DIR}/scummvm.mk"
GITPATCH="${SCUMM_DIR}/002-ultima8-korean.gitpatch"
DISABLED="${SCUMM_DIR}/002-ultima8-korean.patch.disabled"

if [ -d "${SCUMM_DIR}" ] && [ -f "${GITPATCH}" ]; then
  # The Ultima8 Korean patch contains a Git binary patch for dists/engine-data/ultima8.dat.
  # Buildroot's automatic .patch step uses normal patch(1), which cannot apply Git binary patches.
  # Therefore keep the full patch as .gitpatch and make sure the .patch name is not auto-applied.
  rm -f "${SCUMM_DIR}/002-ultima8-korean.patch" \
        "${SCUMM_DIR}/002-ultima8-korean-dat.gitbinary"

  if [ ! -f "${DISABLED}" ]; then
    cp -f "${GITPATCH}" "${DISABLED}"
  fi

  if [ -f "${SCUMM_MK}" ]; then
    python3 - "${SCUMM_MK}" <<'PY'
from pathlib import Path
import re
import sys

mk = Path(sys.argv[1])
s = mk.read_text()

# Remove older failed/experimental hooks if they are present.
patterns = [
    r'\ndefine SCUMMVM_APPLY_KOREAN_ULTIMA8_DAT_BINARY\n.*?endef\nSCUMMVM_POST_EXTRACT_HOOKS \+= SCUMMVM_APPLY_KOREAN_ULTIMA8_DAT_BINARY\n\n',
    r'\ndefine SCUMMVM_COPY_KOREAN_ULTIMA8_DAT\n.*?endef\nSCUMMVM_POST_PATCH_HOOKS \+= SCUMMVM_COPY_KOREAN_ULTIMA8_DAT\n\n',
    r'\ndefine SCUMMVM_APPLY_KOREAN_ULTIMA8_GITPATCH\n.*?endef\nSCUMMVM_POST_PATCH_HOOKS \+= SCUMMVM_APPLY_KOREAN_ULTIMA8_GITPATCH\n\n',
]
for pat in patterns:
    s = re.sub(pat, '\n', s, flags=re.S)

block = r'''
define SCUMMVM_APPLY_KOREAN_ULTIMA8_GITPATCH
	cd $(@D) && git apply --binary --whitespace=nowarn $(SCUMMVM_PKGDIR)/002-ultima8-korean.gitpatch
endef
SCUMMVM_POST_PATCH_HOOKS += SCUMMVM_APPLY_KOREAN_ULTIMA8_GITPATCH

'''

idx = s.rfind('$(eval $(')
if idx == -1:
    s = s.rstrip() + '\n\n' + block
else:
    s = s[:idx] + block + s[idx:]

mk.write_text(s)
print('Updated scummvm.mk: 002-ultima8-korean.gitpatch will be applied with git apply --binary')
PY
  fi
fi
