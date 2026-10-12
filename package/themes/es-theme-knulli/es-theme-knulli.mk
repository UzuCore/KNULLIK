################################################################################
#
# EmulationStation theme "Knulli"
#
################################################################################
# Version: Commits on Jul 19, 2026
ES_THEME_KNULLI_VERSION = ad6013bfa2875ad18cc2056762eb56b24cf46bb5
ES_THEME_KNULLI_SITE = $(call github,symbuzzer,es-theme-knulli,$(ES_THEME_KNULLI_VERSION))

define ES_THEME_KNULLI_INSTALL_TARGET_CMDS
    mkdir -p $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-knulli
    cp -r $(@D)/* $(TARGET_DIR)/usr/share/emulationstation/themes/es-theme-knulli
endef

$(eval $(generic-package))
