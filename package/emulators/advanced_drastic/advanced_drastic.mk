################################################################################
#
# advanced_drastic
#
################################################################################

ADVANCED_DRASTIC_VERSION = eaf41ab9bc8adcc15c010bf9517bc94c38e7bffd
ADVANCED_DRASTIC_SITE = $(call github,trngaje,advanced_drastic,$(ADVANCED_DRASTIC_VERSION))
ADVANCED_DRASTIC_DEPENDENCIES = drastic_layout sdl2_drastic

define ADVANCED_DRASTIC_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/share/advanced_drastic

	cp -r $(@D)/* $(TARGET_DIR)/usr/share/advanced_drastic

	# ROCKNIXK/Korean QoL: optional board-specific Advanced DraStic overrides.
	if test -d $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/advanced_drastic/rocknixk/devices; then \
		mkdir -p $(TARGET_DIR)/usr/share/advanced_drastic/devices; \
		cp -r $(BR2_EXTERNAL_KNULLI_PATH)/package/emulators/advanced_drastic/rocknixk/devices/* \
			$(TARGET_DIR)/usr/share/advanced_drastic/devices/; \
	fi
endef

$(eval $(generic-package))
