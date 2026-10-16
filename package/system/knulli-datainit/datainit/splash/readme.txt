KNULLIK SHARE/splash folder

KNULLIK boot image (all supported build targets):
The firmware supplies a default KNULLIK 720x480 boot.png in this folder.
Boot splash defaults to CUSTOM IMAGE on clean installations.
In EmulationStation: SYSTEM SETTINGS > BOOT SPLASH > MOTD / CUSTOM IMAGE.
Replace SHARE/splash/boot.png to select your own PNG; firmware updates will
not overwrite your personal file. The original PNG is never modified.
When the graphics renderer cannot display a picture, the previous boot
display remains the safe fallback.

The renderer detects the active framebuffer geometry (320x480, 640x480,
720x480, 1280x720 and other sizes) and STRETCHES the artwork to fill the
ENTIRE screen. Source aspect ratio is intentionally not preserved: the logo
can be wider or taller, but there are no added black borders, letterboxing,
or crops. If the framebuffer scan-out is portrait while the image is
landscape, the artwork is rotated 90 degrees first; known devices with
opposite native panel direction use a 270-degree or unrotated preset instead.

If a specific panel needs a different orientation, put a single line in
the boot partition's boot/knullik-splash.rotate file: auto, 0, 90, 180, or
270 (degrees clockwise). This overrides the device preset. The PNG stays
identical regardless of screen orientation or size.

Automatic logo replacement (H700):
While KNULLIK is running and CUSTOM IMAGE is selected, simply overwrite
SHARE/splash/boot.png with a new PNG. Once the copy/rename completes,
an inotify event refreshes the boot cache automatically, so ONE normal
reboot is enough; there is no need to reselect the menu option.
The shutdown service also synchronizes the cache before an orderly reboot.
An incomplete PNG upload does not disable the existing custom selection.

If you replace the file on the SD card while the device is powered off,
the earliest splash of the first boot can still use the previous cached
image (the initramfs cannot access userdata yet). The root filesystem
updates the cache on startup, and later boots use the new logo.
