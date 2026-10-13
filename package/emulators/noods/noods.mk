################################################################################
#
# noods
#
################################################################################

NOODS_VERSION = 4cb1439c330248b26cdf5f8dbcfa4e5ac53dcda0
NOODS_SITE = $(call github,Hydr8gon,NooDS,$(NOODS_VERSION))
NOODS_LICENSE = GPL-3.0
NOODS_LICENSE_FILES = LICENSE

NOODS_DEPENDENCIES = sdl2 libpng

define NOODS_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) CXX="$(TARGET_CXX)" LD="$(TARGET_LD)" \
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