################################################################################
#
# advanced_drastic
#
################################################################################

ADVANCED_DRASTIC_VERSION = d5a16e027ba28c7f5edf61ca9ba0f69aa3d93cf4
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
