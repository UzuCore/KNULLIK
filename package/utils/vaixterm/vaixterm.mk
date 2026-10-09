################################################################################
#
# vaixterm
#
################################################################################

# Last commit before the libvterm refactor (fd79eab); libvterm is not packaged
VAIXTERM_VERSION = 013e685b775ec4aa5a69a1b35c8fe64b6b4c13bd
VAIXTERM_SITE = https://github.com/Stanley00/vaixterm.git
VAIXTERM_SITE_METHOD = git
VAIXTERM_LICENSE = MIT
VAIXTERM_LICENSE_FILES = LICENSE

VAIXTERM_DEPENDENCIES = sdl2 sdl2_ttf sdl2_image

# Get SDL2 compilation and linking flags
VAIXTERM_SDL_CFLAGS = $(shell $(PKG_CONFIG_HOST_BINARY) --cflags sdl2 SDL2_ttf SDL2_image)
VAIXTERM_SDL_LIBS = $(shell $(PKG_CONFIG_HOST_BINARY) --libs sdl2 SDL2_ttf SDL2_image)

# Try to use the project's Makefile with proper environment variables
define VAIXTERM_BUILD_CMDS
    $(MAKE) $(TARGET_CONFIGURE_OPTS) \
        PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
        CFLAGS="$(TARGET_CFLAGS) $(VAIXTERM_SDL_CFLAGS) -Iinclude -Isrc" \
        LDFLAGS="$(TARGET_LDFLAGS) $(VAIXTERM_SDL_LIBS) -lm" \
        -C $(@D)
endef

define VAIXTERM_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/vaixterm $(TARGET_DIR)/usr/bin/vaixterm
endef

# Install resource files if they exist
define VAIXTERM_INSTALL_RES_CMDS
    if [ -d $(@D)/res ]; then \
        $(INSTALL) -d $(TARGET_DIR)/usr/share/vaixterm/res && \
        cp -r $(@D)/res/* $(TARGET_DIR)/usr/share/vaixterm/res/; \
    fi
endef

VAIXTERM_POST_INSTALL_TARGET_HOOKS += VAIXTERM_INSTALL_RES_CMDS

$(eval $(generic-package))