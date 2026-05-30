#!/usr/bin/env python3
"""Install an idempotent Buildroot hook for a full Korean emulationstation2.po overlay.

The managed source file is intentionally kept outside the generated build tree:
  package/emulationstation/knulli-es-system/rocknixk/locales/ko_KR/emulationstation2.po

This hook copies that full PO into the EmulationStation source tree after it is
extracted and also installs compiled emulationstation2.mo files into target for
both ko and ko_KR, so the translation is not reduced by knulli-es-system.pot.
"""
from __future__ import annotations

from pathlib import Path
import sys

BEGIN_BLOCK = "# ROCKNIXK_ES2_PO_OVERLAY_BEGIN"
END_BLOCK = "# ROCKNIXK_ES2_PO_OVERLAY_END"
BEGIN_HOOKS = "# ROCKNIXK_ES2_PO_HOOKS_BEGIN"
END_HOOKS = "# ROCKNIXK_ES2_PO_HOOKS_END"

BLOCK = r'''
# ROCKNIXK_ES2_PO_OVERLAY_BEGIN
# Full Korean EmulationStation translation overlay.
# Managed source:
#   package/emulationstation/knulli-es-system/rocknixk/locales/ko_KR/emulationstation2.po
#
# Do not route this file through knulli-es-system.po generation: that package
# msgmerges against knulli-es-system.pot and can drop/obsolete many real
# emulationstation2 entries. This hook applies the full PO directly to the
# emulationstation2 domain.
KNULLI_EMULATIONSTATION_KOREAN_ES2_PO = $(firstword $(wildcard \
	$(BR2_EXTERNAL_KNULLI_PATH)/package/emulationstation/knulli-es-system/rocknixk/locales/ko_KR/emulationstation2.po \
	$(KNULLI_EMULATIONSTATION_SOURCE_PATH)/rocknixk/locales/ko_KR/emulationstation2.po))

ifneq ($(KNULLI_EMULATIONSTATION_KOREAN_ES2_PO),)
define KNULLI_EMULATIONSTATION_KOREAN_ES2_PO_OVERLAY
	for lang in ko ko_KR; do \
		mkdir -p $(@D)/locale/lang/$$lang/LC_MESSAGES; \
		cp -f $(KNULLI_EMULATIONSTATION_KOREAN_ES2_PO) \
			$(@D)/locale/lang/$$lang/LC_MESSAGES/emulationstation2.po; \
		echo "Applied Korean emulationstation2.po overlay to $$lang"; \
	done
endef

define KNULLI_EMULATIONSTATION_KOREAN_ES2_PO_INSTALL
	for lang in ko ko_KR; do \
		mkdir -p $(TARGET_DIR)/usr/share/locale/$$lang/LC_MESSAGES; \
		$(HOST_DIR)/bin/msgfmt $(KNULLI_EMULATIONSTATION_KOREAN_ES2_PO) \
			-o $(TARGET_DIR)/usr/share/locale/$$lang/LC_MESSAGES/emulationstation2.mo; \
		echo "Installed Korean emulationstation2.mo for $$lang"; \
	done
endef
endif
# ROCKNIXK_ES2_PO_OVERLAY_END
'''.strip("\n")

HOOKS = r'''
# ROCKNIXK_ES2_PO_HOOKS_BEGIN
ifneq ($(KNULLI_EMULATIONSTATION_KOREAN_ES2_PO),)
KNULLI_EMULATIONSTATION_PRE_CONFIGURE_HOOKS += KNULLI_EMULATIONSTATION_KOREAN_ES2_PO_OVERLAY
KNULLI_EMULATIONSTATION_POST_INSTALL_TARGET_HOOKS += KNULLI_EMULATIONSTATION_KOREAN_ES2_PO_INSTALL
endif
# ROCKNIXK_ES2_PO_HOOKS_END
'''.strip("\n")


def replace_between(text: str, begin: str, end: str, replacement: str) -> tuple[str, bool]:
    start = text.find(begin)
    if start == -1:
        return text, False
    finish = text.find(end, start)
    if finish == -1:
        raise SystemExit(f"Found {begin}, but not {end}")
    finish += len(end)
    return text[:start] + replacement + text[finish:], True


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    mk = root / "package/emulationstation/knulli-emulationstation/knulli-emulationstation.mk"
    if not mk.exists():
        raise SystemExit(f"Missing file: {mk}")

    text = mk.read_text(encoding="utf-8")

    # Replace existing generated block if present; otherwise insert before the
    # first hook/function block that follows KNULLI_EMULATIONSTATION_SOURCE_PATH.
    text, replaced = replace_between(text, BEGIN_BLOCK, END_BLOCK, BLOCK)
    if not replaced:
        marker = "define KNULLI_EMULATIONSTATION_RPI_FIXUP"
        if marker not in text:
            raise SystemExit(f"Could not find insertion marker: {marker}")
        text = text.replace(marker, BLOCK + "\n\n" + marker, 1)

    text, hooks_replaced = replace_between(text, BEGIN_HOOKS, END_HOOKS, HOOKS)
    if not hooks_replaced:
        marker = "KNULLI_EMULATIONSTATION_PRE_CONFIGURE_HOOKS += KNULLI_EMULATIONSTATION_EXTERNAL_POS"
        if marker not in text:
            raise SystemExit(f"Could not find hook marker: {marker}")
        text = text.replace(marker, marker + "\n" + HOOKS, 1)

    mk.write_text(text, encoding="utf-8")
    print(f"Installed Korean emulationstation2.po overlay hook into {mk}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
