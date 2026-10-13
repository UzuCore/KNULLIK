################################################################################
#
# libretro-hatari
#
################################################################################

LIBRETRO_HATARI_VERSION = a82e014ce2b05fc7724add284febba3816e4112a
LIBRETRO_HATARI_SITE = https://github.com/libretro/hatari.git
LIBRETRO_HATARI_SITE_METHOD = git
LIBRETRO_HATARI_GIT_SUBMODULES = YES
LIBRETRO_HATARI_DEPENDENCIES = libcapsimage zlib retroarch
LIBRETRO_HATARI_LICENSE = GPLv2
LIBRETRO_HATARI_SUPPORTS_IN_SOURCE_BUILD = NO

# Upstream replaced Makefile.libretro with CMake. Build only the core.
LIBRETRO_HATARI_CONF_OPTS += -DENABLE_LIBRETRO=ON -DLIBRETRO_STATIC=OFF
LIBRETRO_HATARI_CONF_OPTS += -DENABLE_HATARI=OFF -DENABLE_TOOLS=OFF
LIBRETRO_HATARI_CONF_OPTS += -DENABLE_SDL3=OFF
LIBRETRO_HATARI_CONF_OPTS += -DCMAKE_POSITION_INDEPENDENT_CODE=ON

define LIBRETRO_HATARI_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/src/hatari_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/hatari_libretro.so
endef

$(eval $(cmake-package))
