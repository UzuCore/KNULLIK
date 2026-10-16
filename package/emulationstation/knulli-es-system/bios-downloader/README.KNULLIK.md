# KNULLIK BIOS Downloader — ROCKNIXK SDL port

This directory vendors the three Python modules of the BIOS downloader from
[UzuCore/ROCKNIXK](https://github.com/UzuCore/ROCKNIXK) `dev` at
commit `24c8802432d6851315c077d1faf4d76f53fe69b9` (2026-10-16).
The BIOS downloader was originally introduced there in `d5edd0009e`.
The original source files retain their `SPDX-License-Identifier: GPL-2.0-or-later`
headers. No actual BIOS ROMs are bundled in this repository.

KNULLIK-specific changes:
- Full cyan/dark interface palette, `KNULLIK` window heading and SDL WM class.
- Default destination `/userdata/bios` (same as KNULLIK's former tool).
- Preferred installed Korean NanumGothicBold and KNULLIK theme font paths.
- Update receipt named `.knullik-bios-download.json` with read compatibility
  for `.rocknix-bios-download.json`.
- Existing `TOOLS/download_bios.sh` launches
  `/usr/bin/knullik-bios-downloader`; backend modules live in the firmware
  at `/usr/share/knulli/bios-downloader`.
- Boot-time `S12populateshare` migrates only known, hash-matched official
  pre-SDL shortcuts and gamelists. Locally modified files are preserved.

Functional behavior otherwise follows the upstream implementation: source
commit checks, streamed verified downloads, ZIP traversal and decompression
limits, per-file hashes, atomic staged installs with rollback, cancellation,
retry/backoff, input handling and responsive SDL rendering. Default downloads
are from `UzuCore/minimal-Bios`. Users must ensure they have the rights to
use the firmware files they install.

To test the interface without downloading BIOS:

```sh
SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software \
 python3 main.py --size 640x480 --language ko_KR --demo-phase done \
 --duration 0.5 --screenshot /tmp/knullik-bios-ui.png
```
