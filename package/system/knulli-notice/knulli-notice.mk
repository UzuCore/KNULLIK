################################################################################
#
# Knulli notice
#
################################################################################
# Version.: Commits on April 05, 2025
KNULLI_NOTICE_VERSION = 25cb418f63a06dd68a5f70846183b975dce3db2a
KNULLI_NOTICE_SITE = $(call github,knulli-cfw,knulli-notice,$(KNULLI_NOTICE_VERSION))

define KNULLI_NOTICE_INSTALL_TARGET_CMDS
    mkdir -p $(TARGET_DIR)/usr/share/knulli/doc
    cp -r $(@D)/notice.pdf $(TARGET_DIR)/usr/share/knulli/doc/notice.pdf
endef

$(eval $(generic-package))
