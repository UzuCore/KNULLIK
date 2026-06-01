################################################################################
#
# gmu
#
################################################################################

GMU_VERSION = 99175d492b54eba514ec6d3f8b88591d74aedcc4
GMU_SITE = $(call github,trngaje,gmu,$(GMU_VERSION))
GMU_LICENSE = GPL-2.0
GMU_DEPENDENCIES = sdl2 sdl2_image opus mpg123 libvorbis flac speex

GMU_CONFIG_DIR = $(TARGET_DIR)/usr/share/gmu/defaults

# GMU's configure is not autoconf.  It writes config.mk, including the CFLAGS
# that define FILE_HW_H, STATIC, TARGET and plugin settings.  Do not pass
# TARGET_CONFIGURE_OPTS to the later make invocation, because make-command-line
# CFLAGS override GMU's own CFLAGS and cause FILE_HW_H/STATIC to disappear.
define GMU_CONFIGURE_CMDS
	(cd $(@D) && \
		$(TARGET_CONFIGURE_OPTS) \
		SDL2CONFIG=$(STAGING_DIR)/usr/bin/sdl2-config \
		./configure \
			--prefix=/usr \
			--target-device=unknown \
			--disable=web-frontend \
			--disable=lirc-frontend \
			--disable=notify-frontend \
			--disable=SDL_gfx \
			--enable=sdl-frontend)
endef

# The SDL player (gmu.bin) is the only binary launched by ES.  The optional
# console client (gmuc) can fail to link on Buildroot with "DSO missing from
# command line" for libtinfo/ncurses, after gmu.bin has already linked.
# Treat the build as successful once the SDL binary exists.
define GMU_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) || \
		(test -x $(@D)/gmu.bin || test -x $(@D)/src/gmu.bin || test -x $(@D)/gmu || test -x $(@D)/src/gmu)
endef

define GMU_INSTALL_TARGET_CMDS
	if test -x $(@D)/gmu.bin; then \
		$(INSTALL) -D -m 0755 $(@D)/gmu.bin $(TARGET_DIR)/usr/bin/gmu.bin; \
	elif test -x $(@D)/src/gmu.bin; then \
		$(INSTALL) -D -m 0755 $(@D)/src/gmu.bin $(TARGET_DIR)/usr/bin/gmu.bin; \
	elif test -x $(@D)/gmu; then \
		$(INSTALL) -D -m 0755 $(@D)/gmu $(TARGET_DIR)/usr/bin/gmu.bin; \
	elif test -x $(@D)/src/gmu; then \
		$(INSTALL) -D -m 0755 $(@D)/src/gmu $(TARGET_DIR)/usr/bin/gmu.bin; \
	else \
		echo "ERROR: GMU SDL binary was not built"; \
		exit 1; \
	fi

	if test -d $(@D)/share/gmu; then \
		mkdir -p $(TARGET_DIR)/usr/share/gmu; \
		cp -a $(@D)/share/gmu/. $(TARGET_DIR)/usr/share/gmu/; \
	fi
	if test -d $(@D)/skins; then \
		mkdir -p $(TARGET_DIR)/usr/share/gmu/skins; \
		cp -a $(@D)/skins/. $(TARGET_DIR)/usr/share/gmu/skins/; \
	fi
	if test -d $(@D)/frontends/sdl/skins; then \
		mkdir -p $(TARGET_DIR)/usr/share/gmu/skins; \
		cp -a $(@D)/frontends/sdl/skins/. $(TARGET_DIR)/usr/share/gmu/skins/; \
	fi
	if test -d $(@D)/src/frontends/sdl/skins; then \
		mkdir -p $(TARGET_DIR)/usr/share/gmu/skins; \
		cp -a $(@D)/src/frontends/sdl/skins/. $(TARGET_DIR)/usr/share/gmu/skins/; \
	fi
	if test -d $(@D)/plugins; then \
		mkdir -p $(TARGET_DIR)/usr/lib/gmu/plugins; \
		find $(@D)/plugins -type f \( -name '*.so' -o -perm -111 \) -exec cp -a {} $(TARGET_DIR)/usr/lib/gmu/plugins/ \; ; \
	fi

	$(INSTALL) -D -m 0755 \
		$(BR2_EXTERNAL_KNULLI_PATH)/package/audio/gmu/scripts/start_gmu.sh \
		$(TARGET_DIR)/usr/bin/start_gmu.sh

	$(INSTALL) -d $(GMU_CONFIG_DIR)
	$(INSTALL) -m 0644 \
		$(BR2_EXTERNAL_KNULLI_PATH)/package/audio/gmu/config/gmuinput.conf \
		$(GMU_CONFIG_DIR)/gmuinput.conf
	$(INSTALL) -m 0644 \
		$(BR2_EXTERNAL_KNULLI_PATH)/package/audio/gmu/config/caanoo.keymap \
		$(GMU_CONFIG_DIR)/caanoo.keymap
	$(INSTALL) -m 0644 \
		$(BR2_EXTERNAL_KNULLI_PATH)/package/audio/gmu/config/gmu.conf \
		$(GMU_CONFIG_DIR)/gmu.conf
endef

$(eval $(generic-package))
