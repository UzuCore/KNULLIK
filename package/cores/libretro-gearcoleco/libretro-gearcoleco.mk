################################################################################
#
# libretro-gearcoleco
#
################################################################################
# Version: Commits on Mar 12, 2023
$123743bcdd76b79e0c70801ce2ce170ac5edc9a12
LIBRETRO_GEARCOLECO_SITE = $(call github,drhelius,Gearcoleco,$(LIBRETRO_GEARCOLECO_VERSION))
LIBRETRO_GEARCOLECO_LICENSE = GPLv3

define LIBRETRO_GEARCOLECO_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) CXX="$(TARGET_CXX)" CC="$(TARGET_CC)" -C \
        $(@D)/platforms/libretro -f Makefile platform="unix"
endef

define LIBRETRO_GEARCOLECO_INSTALL_TARGET_CMDS
	$(INSTALL) -D $(@D)/platforms/libretro/gearcoleco_libretro.so \
		$(TARGET_DIR)/usr/lib/libretro/gearcoleco_libretro.so
endef

$(eval $(generic-package))
