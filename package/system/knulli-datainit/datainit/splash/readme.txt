Place your splashscreens files here
They will be copied to /boot/splash automatically

Attention! Every data will be copied! There is no difference
between pictures, movies, music and gamesdata

If you delete some data it will be removed from /boot/splash, too
Remember if your board does not support video splashes then they won't be played!

KNULLIK H700 custom boot image:
Copy one PNG named boot.png to this folder (SHARE/splash/boot.png).
In EmulationStation: SYSTEM SETTINGS > BOOT SPLASH > CUSTOM IMAGE.
The default is MOTD. Missing or invalid PNG files fall back to MOTD.
The PNG is converted to a temporary display cache; the original is unchanged.

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
