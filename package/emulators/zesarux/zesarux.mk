################################################################################
#
# zesarux
#
################################################################################

ZESARUX_VERSION = ZEsarUX-12.1
ZESARUX_SITE = $(call github,chernandezba,zesarux,$(ZESARUX_VERSION))
ZESARUX_LICENSE = GPL-3.0
ZESARUX_LICENSE_FILES = src/COPYING

ZESARUX_DEPENDENCIES = sdl2 alsa-lib

# Build with SDL2 video+audio; no X11, no framebuffer, no text/caca/aa drivers,
# no macOS-specific drivers, no PulseAudio, no OSS/DSP, no SSL dependency.
ZESARUX_CONF_OPTS = \
    --c-compiler $(TARGET_CC) \
    --disable-xwindows \
    --disable-xext \
    --disable-caca \
    --disable-aa \
    --disable-curses \
    --disable-cursesw \
    --disable-stdout \
    --disable-simpletext \
    --disable-fbdev \
    --disable-dsp \
    --disable-onebitspeaker \
    --disable-pcspeaker \
    --disable-coreaudio \
    --disable-cocoa \
    --disable-pulse \
    --enable-raspberry \
    --spectrum-reduced-core \
    --disable-memptr \
    --disable-visualmem \
    --disable-cpustats \
    --prefix /usr

define ZESARUX_CONFIGURE_CMDS
	cd $(@D)/src && \
	CFLAGS="$(TARGET_CFLAGS)" \
	LDFLAGS="$(TARGET_LDFLAGS)" \
	PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
	PKG_CONFIG_PATH="$(STAGING_DIR)/usr/lib/pkgconfig" \
	./configure $(ZESARUX_CONF_OPTS)
endef

define ZESARUX_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/src
endef

define ZESARUX_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/src/zesarux $(TARGET_DIR)/usr/bin/zesarux
endef

$(eval $(generic-package))
