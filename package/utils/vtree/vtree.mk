################################################################################
#
# vtree
#
################################################################################

VTREE_VERSION = 560205b6198ac9e0e28975d42fcaee4c28989015
VTREE_SITE    = https://github.com/MustardOS/vtree.git
VTREE_SITE_METHOD = git

VTREE_DEPENDENCIES = sdl2 sdl2_ttf sdl2_image

define VTREE_BUILD_CMDS
	$(MAKE) -C $(@D) release \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

define VTREE_INSTALL_TARGET_CMDS
	$(INSTALL) -d $(TARGET_DIR)/usr/share/vtree
	$(INSTALL) -m 0755 $(@D)/vtree      $(TARGET_DIR)/usr/share/vtree/vtree
	$(INSTALL) -m 0644 $(@D)/config.ini $(TARGET_DIR)/usr/share/vtree/
	$(INSTALL) -m 0644 $(@D)/theme.ini  $(TARGET_DIR)/usr/share/vtree/
	cp -r $(@D)/res   $(TARGET_DIR)/usr/share/vtree/
	cp -r $(@D)/fonts $(TARGET_DIR)/usr/share/vtree/
	printf '#!/bin/sh\ncd /usr/share/vtree && exec ./vtree "$$@"\n' \
		> $(TARGET_DIR)/usr/bin/vtree
	chmod 0755 $(TARGET_DIR)/usr/bin/vtree
endef

$(eval $(generic-package))

