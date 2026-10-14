################################################################################
#
# aethersx2
#
################################################################################

AETHERSX2_VERSION = 1.0.0
AETHERSX2_SITE = https://github.com/ROCKNIX/packages/raw/refs/heads/main
AETHERSX2_SOURCE = aethersx2.tar.gz
AETHERSX2_LICENSE = LGPL
AETHERSX2_LICENSE_FILES = LICENSE

AETHERSX2_DEPENDENCIES = toolchain qt6base libgpg-error libfuse xz libpcap

AETHERSX2_TOOLCHAIN = manual

# Let Buildroot handle extraction automatically (no custom EXTRACT_CMDS needed)

define AETHERSX2_CONFIGURE_CMDS
    # No configuration needed for prebuilt binary
    true
endef

define AETHERSX2_BUILD_CMDS
    # No build needed for prebuilt binary
    true
endef

define AETHERSX2_INSTALL_TARGET_CMDS
    mkdir -p $(TARGET_DIR)/usr/bin
    mkdir -p $(TARGET_DIR)/usr/share/aethersx2
    mkdir -p $(TARGET_DIR)/usr/config/aethersx2
    mkdir -p $(TARGET_DIR)/usr/share/evmapy
    mkdir -p $(TARGET_DIR)/usr/share/knulli/datainit/bios/ps2

    # Install shared resources
    if [ -d $(@D)/usr/share ]; then \
        cp -rf $(@D)/usr/share/* $(TARGET_DIR)/usr/share/aethersx2/; \
    fi

    # Install custom sources/config
    if [ -d $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/sources ]; then \
        cp -rf $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/sources/* $(TARGET_DIR)/usr/share/aethersx2/; \
    fi

    # Install scripts
    if [ -d $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/scripts ]; then \
        cp -rf $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/scripts/* $(TARGET_DIR)/usr/bin/; \
        chmod 755 $(TARGET_DIR)/usr/bin/*; \
    fi

    # Install device-specific config
    if [ -d $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/config/$(KNULLI_DEVICE) ]; then \
        cp -rf $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/config/$(KNULLI_DEVICE)/aethersx2 $(TARGET_DIR)/usr/config/; \
    fi

    # Install evmapy keymap for AetherSX2
    if [ -f $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/ps2.aethersx2.keys ]; then \
        cp -f $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/ps2.aethersx2.keys $(TARGET_DIR)/usr/share/evmapy/ps2.aethersx2.keys; \
    fi

    # Install patches.zip for AetherSX2
    if [ -f $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/patches.zip ]; then \
        cp -f $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/patches.zip $(TARGET_DIR)/usr/share/knulli/datainit/bios/ps2/patches.zip; \
    fi

    # Copy updated qt.conf
    if [ -d $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/qt.conf ]; then \
        cp -rf $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/aethersx2/qt.conf $(TARGET_DIR)/usr/share/aethersx2/; \
    fi

endef

$(eval $(generic-package))
