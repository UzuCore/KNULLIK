# silky-rgb support: Mangmi "Loong" (miniloong) analog-stick RGB ring

Drop-in additions for the [silky-rgb](https://github.com/chrizzo-hb/silky-rgb)
repo to support the Mangmi Loong (a.k.a. miniloong, RK3566) analog-stick RGB ring.

Files (mirror the silky-rgb repo layout):

- `drivers/mangmi_loong.py`     -> `silkyrgb/drivers/mangmi_loong.py`
- `device_configs/miniloong.json` -> `silkyrgb/device_configs/miniloong.json`

`device.py` selects the config by `/boot/boot/knulli.board` (== `miniloong`),
which sets `"driver": "mangmi_loong"`.

## Hardware

The ring is an **Awinic AW20036** 3x12 LED-matrix controller on i2c1 @ 0x3a
(HWEN on gpio4 PC3). It is driven by the **mainline `leds-aw200xx`** kernel
driver (back-ported into the BSP 6.1 kernel), which exposes each matrix channel
as a standard `/sys/class/leds` device.

- **8 populated RGB LEDs**, indices 0..7. (The matrix has 36 channels but only
  regs 0..23 have physical LEDs; regs 24..35 are unpopulated.)
- Each LED is a consecutive matrix triplet wired **Blue, Green, Red**. The board
  DTS labels them so userspace sees, per LED `i`:
  `/sys/class/leds/aw20036:r<i>`, `aw20036:g<i>`, `aw20036:b<i>`  (i = 0..7).

## Driver notes

`mangmi_loong.py` is a software-rendered driver (no hardware effect engine),
modelled on `retroid_sm8250.py`:

- Pre-opens the 24 channel `brightness` fds in framebuffer order (LED i -> R,G,B)
  so silky's flat `[r,g,b]*8` list maps 1:1 in `write()`.
- `lseek(0)` before each write (sysfs brightness parses from offset 0).
- **Pins the AW20036 per-channel `dim` (6-bit current scaler) to 63 at init** so
  animation only varies the 8-bit FADE/PWM. Without this, the driver's default
  "auto" DIM mode steps the coarse current on every brightness change, which
  looks like banding/flicker. This is the key smoothness fix.

## Ring geometry (measured on hardware)

`miniloong.json` lists the ring zone angle-sorted: `led_indexes` is the
framebuffer index at each ring position, `led_angles` its angle (0 deg = top,
clockwise). Measured clock positions:

| LED | clock | angle |
|-----|-------|-------|
| 0   | 2:00  | 60    |
| 1   | 1:00  | 30    |
| 2   | 11:00 | 330   |
| 3   | 9:00  | 270   |
| 4   | 3:00  | 90    |
| 5   | 5:00  | 150   |
| 6   | 6:00  | 180   |
| 7   | 8:00  | 240   |

(Positions are approximate; tune `led_angles` if effects look off.)
