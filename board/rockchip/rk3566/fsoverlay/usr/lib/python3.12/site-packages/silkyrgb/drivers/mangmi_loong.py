import os

# Mangmi "Loong" (miniloong) analog-stick RGB ring.
#
# The ring is 8 RGB LEDs driven by an Awinic AW20036 LED-matrix controller on
# i2c1. The mainline leds-aw200xx kernel driver exposes every matrix channel as
# a standard Linux LED-class device; this board's DTS labels the 8 populated
# LEDs as aw20036:{r,g,b}<0..7> (the other 12 matrix channels are unpopulated).
#
# Silky-RGB renders an [r,g,b] * leds framebuffer (software effects) and hands
# the flat 0-255 list to render()/write(). We keep one write-only fd per channel
# in framebuffer order (LED i -> r,g,b) so write() maps 1:1 onto the incoming
# list, exactly like the retroid_sm8250 reference driver.


class RGBDriver:
    LED_COUNT = 8
    BASE = "/sys/class/leds"

    def __init__(self, extra: dict = None) -> None:
        self.led_fds = []
        for i in range(self.LED_COUNT):
            for color in ("r", "g", "b"):
                leddir = os.path.join(self.BASE, "aw20036:%s%d" % (color, i))
                # Pin the AW20036 per-channel DIM (6-bit global-current scaler)
                # to max once, so animation only varies the 8-bit FADE/PWM. In
                # the driver's default "auto" DIM mode every brightness step also
                # steps the coarse 6-bit current -> visible banding/flicker.
                try:
                    with open(os.path.join(leddir, "dim"), "w") as d:
                        d.write("63")
                except OSError:
                    pass
                path = os.path.join(leddir, "brightness")
                try:
                    self.led_fds.append(os.open(path, os.O_WRONLY))
                except OSError as e:
                    print("mangmi_loong: cannot open %s: %s" % (path, e))
                    self.led_fds.append(None)

    # Software-rendered device: just pass the framebuffer through (trim to the
    # number of physical channels).
    def render(self, rgb_data: list) -> list:
        return rgb_data[:len(self.led_fds)]

    def write(self, led_data: list) -> None:
        if not led_data:
            return
        for i, value in enumerate(led_data):
            fd = self.led_fds[i] if i < len(self.led_fds) else None
            if fd is None:
                continue
            try:
                # Rewind first: sysfs brightness is parsed from offset 0, and the
                # fd position advances on every frame.
                os.lseek(fd, 0, os.SEEK_SET)
                os.write(fd, str(int(value)).encode("ascii"))
            except OSError:
                # device busy / transient i2c error -> skip this frame's channel
                pass

    def close(self) -> None:
        for fd in self.led_fds:
            if fd is not None:
                try:
                    os.close(fd)
                except OSError:
                    pass
        self.led_fds = []

    # Blank the ring when the daemon is told to stop.
    def onKill(self) -> None:
        for fd in self.led_fds:
            if fd is not None:
                try:
                    os.lseek(fd, 0, os.SEEK_SET)
                    os.write(fd, b"0")
                except OSError:
                    pass
