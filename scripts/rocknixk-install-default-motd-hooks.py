#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('.')
mk = root / 'package/boot/knulli-initramfs/knulli-initramfs.mk'
if not mk.exists():
    sys.exit(f'ERROR: {mk} not found. Run from repository root.')

text = mk.read_text()

# Remove older static default-motd variables from previous iterations.
text = re.sub(r'^KNULLI_INITRAMFS_BOOT_MOTD\s*=.*default-motd\.txt\n', '', text, flags=re.M)
for var in [
    'KNULLI_INITRAMFS_BOOT_MOTD_SOURCE',
    'KNULLI_INITRAMFS_BOOT_MOTD_GEN',
    'KNULLI_INITRAMFS_BOOT_MOTD_GENERATED',
]:
    text = re.sub(rf'^{var}\s*=.*\n', '', text, flags=re.M)

vars_block = (
    'KNULLI_INITRAMFS_BOOT_MOTD_SOURCE = $(BR2_EXTERNAL_KNULLI_PATH)/board/fsoverlay/etc/profile.d/30-welcome.sh\n'
    'KNULLI_INITRAMFS_BOOT_MOTD_GEN = $(BR2_EXTERNAL_KNULLI_PATH)/scripts/rocknixk-generate-boot-motd-from-welcome.py\n'
    'KNULLI_INITRAMFS_BOOT_MOTD_GENERATED = $(BUILD_DIR)/knulli-boot-motd/default-motd.txt\n'
)

# Place variables near fbboot source if possible.
insert_after = 'KNULLI_INITRAMFS_FBBOOT_SOURCE'
lines = text.splitlines(True)
out = []
inserted = False
for line in lines:
    out.append(line)
    if not inserted and line.startswith(insert_after):
        out.append(vars_block)
        inserted = True
if not inserted:
    out.insert(0, vars_block + '\n')
text = ''.join(out)

start_marker = '# KNULLI-KR generated boot MOTD install hook BEGIN'
end_marker = '# KNULLI-KR generated boot MOTD install hook END'
old_start = '# KNULLI-KR default boot MOTD install hook BEGIN'
old_end = '# KNULLI-KR default boot MOTD install hook END'

for s, e in [(start_marker, end_marker), (old_start, old_end)]:
    if s in text and e in text:
        before, rest = text.split(s, 1)
        _, after = rest.split(e, 1)
        text = before.rstrip() + '\n' + after.lstrip('\n')

block = f'''
	{start_marker}
	@mkdir -p $(INITRAMFS_DIR)/etc $(TARGET_DIR)/usr/share/knulli $(dir $(KNULLI_INITRAMFS_BOOT_MOTD_GENERATED))
	@if test -f $(KNULLI_INITRAMFS_BOOT_MOTD_SOURCE); then \
		BUILD_TEXT="$$(cat $(TARGET_DIR)/usr/share/knulli/knulli.version 2>/dev/null || true)"; \
		KNULLI_BOOT_MOTD_MODEL="KNULLI" KNULLI_BOOT_MOTD_BUILD="$${{BUILD_TEXT:-INITIALIZING}}" \
			python3 $(KNULLI_INITRAMFS_BOOT_MOTD_GEN) \
			--welcome $(KNULLI_INITRAMFS_BOOT_MOTD_SOURCE) \
			--output $(KNULLI_INITRAMFS_BOOT_MOTD_GENERATED) \
			--max-logo-lines 9; \
	else \
		echo "WARNING: $(KNULLI_INITRAMFS_BOOT_MOTD_SOURCE) not found; using compiled fallback"; \
	fi
	@if test -f $(KNULLI_INITRAMFS_BOOT_MOTD_GENERATED); then \
		cp -f $(KNULLI_INITRAMFS_BOOT_MOTD_GENERATED) $(INITRAMFS_DIR)/etc/knulli-boot-motd; \
		cp -f $(KNULLI_INITRAMFS_BOOT_MOTD_GENERATED) $(TARGET_DIR)/usr/share/knulli/boot-motd; \
		echo "Installed generated KNULLI-KR boot MOTD from 30-welcome.sh"; \
	fi
	{end_marker}
'''

define = 'define KNULLI_INITRAMFS_INSTALL_TARGET_CMDS'
pos = text.find(define)
if pos < 0:
    sys.exit('ERROR: KNULLI_INITRAMFS_INSTALL_TARGET_CMDS not found. Add the MOTD hook manually.')

# The generated /etc/knulli-boot-motd must be present before initrd is packed.
# Inserting near endef silently copies the file after cpio/mkimage, so the early
# initramfs screen falls back to the compiled title instead of the real MOTD.
pack_marker = '        cp $(@D)/knulli-fbboot $(INITRAMFS_DIR)/bin/knulli-fbboot\n        cp $(@D)/knulli-fbboot $(TARGET_DIR)/usr/bin/knulli-fbboot\n'
insert = text.find(pack_marker, pos)
if insert < 0:
    sys.exit('ERROR: initramfs install marker not found. Add the MOTD hook before cpio/mkimage manually.')
insert += len(pack_marker)
text = text[:insert] + block + text[insert:]

mk.write_text(text)
print('Updated', mk)
print('  - source MOTD script:   board/fsoverlay/etc/profile.d/30-welcome.sh')
print('  - generated build file: $(BUILD_DIR)/knulli-boot-motd/default-motd.txt')
print('  - initramfs target:     /etc/knulli-boot-motd')
print('  - rootfs fallback:      /usr/share/knulli/boot-motd')
