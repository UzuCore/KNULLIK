################################################################################
#
# noods
#
################################################################################

NOODS_VERSION = 93086be34b9efc3b63b9d4e36a50abe8baeecd55
NOODS_SITE = $(call github,Hydr8gon,NooDS,$(NOODS_VERSION))
NOODS_LICENSE = GPL-3.0
NOODS_LICENSE_FILES = LICENSE

NOODS_DEPENDENCIES = sdl2 libpng

define NOODS_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) CXX="$(TARGET_CXX)" \
		CXXFLAGS="$(TARGET_CXXFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)" \
		PKG_CONFIG="$(PKG_CONFIG_HOST_BINARY)" \
		-C $(@D) -f Makefile.handheld
endef

define NOODS_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/noods $(TARGET_DIR)/usr/bin/noods
    
    # Create BIOS directory
    mkdir -p $(TARGET_DIR)/usr/share/knulli/datainit/bios/nds
endef

$(eval $(generic-package))