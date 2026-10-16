################################################################################
#
# knulli splash
#
################################################################################
KNULLI_SPLASH_VERSION = 5.5
KNULLI_SPLASH_SOURCE=

KNULLI_SPLASH_TGVERSION=$(KNULLI_SYSTEM_VERSION) $(KNULLI_SYSTEM_DATE)

# video or image
ifeq ($(BR2_PACKAGE_KNULLI_SPLASH_MPV),y)
    KNULLI_SPLASH_SCRIPT=Ssplash-mpv
    KNULLI_SPLASH_MEDIA=video
else
    KNULLI_SPLASH_SCRIPT=Ssplash-image
    KNULLI_SPLASH_MEDIA=image
endif

# MPV options
ifeq ($(BR2_PACKAGE_KNULLI_SPLASH_MPV),y)
    ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_X86_64_ANY),y)
        # drm doesn't work on my nvidia card. sdl run smoothly.
        KNULLI_SPLASH_PLAYER_OPTIONS=--vo=drm,sdl --hwdec=yes
    else ifeq ($(BR2_PACKAGE_ROCKCHIP_RGA),y)
        KNULLI_SPLASH_PLAYER_OPTIONS=--hwdec=auto
    else ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_AMLOGIC_ANY)$(BR2_PACKAGE_KNULLI_RPI_ANY)$(BR2_PACKAGE_BATOCERA_TARGET_RK3399)$(BR2_PACKAGE_BATOCERA_TARGET_H6)$(BR2_PACKAGE_BATOCERA_TARGET_H616),y)
        # hwdec=yes doesnt work for n2
        KNULLI_SPLASH_PLAYER_OPTIONS=
    else
        KNULLI_SPLASH_PLAYER_OPTIONS=--hwdec=yes
    endif
endif

KNULLI_SPLASH_POST_INSTALL_TARGET_HOOKS += KNULLI_SPLASH_INSTALL_SCRIPT

ifeq ($(KNULLI_SPLASH_MEDIA),image)
    KNULLI_SPLASH_POST_INSTALL_TARGET_HOOKS += KNULLI_SPLASH_INSTALL_IMAGE
    KNULLI_SPLASH_POST_INSTALL_TARGET_HOOKS += KNULLI_SPLASH_INSTALL_BOOT_LOGO
endif

ifeq ($(KNULLI_SPLASH_MEDIA),video)
    KNULLI_SPLASH_POST_INSTALL_TARGET_HOOKS += KNULLI_SPLASH_INSTALL_VIDEO
    KNULLI_SPLASH_POST_INSTALL_TARGET_HOOKS += KNULLI_SPLASH_INSTALL_BOOT_LOGO

    # Capcom video only for H3 build (for CHA)
    ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_H3),y)
        KNULLI_SPLASH_POST_INSTALL_TARGET_HOOKS += KNULLI_SPLASH_INSTALL_VIDEO_CAPCOM
    endif

    # alternative video
    ifeq ($(BR2_PACKAGE_KNULLI_RPI_ANY)$(BR2_PACKAGE_BATOCERA_TARGET_RK3326)$(BR2_PACKAGE_BATOCERA_TARGET_RK3128)$(BR2_PACKAGE_BATOCERA_TARGET_H3),y)
        BATO_SPLASH=$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/videos/splash720p.mp4
    else
        BATO_SPLASH=$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/videos/splash.mp4
    endif
endif

define KNULLI_SPLASH_INSTALL_SCRIPT
    mkdir -p $(TARGET_DIR)/etc/init.d
    install -m 0755 $(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/scripts/Ssystem-splash            $(TARGET_DIR)/etc/init.d/S03system-splash
    install -m 0755 $(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/scripts/Ssplashscreencontrol      $(TARGET_DIR)/etc/init.d/S30splashscreencontrol
    install -m 0755 $(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/scripts/$(KNULLI_SPLASH_SCRIPT) $(TARGET_DIR)/etc/init.d/S28splash
    sed -i -e s+"%PLAYER_OPTIONS%"+"$(KNULLI_SPLASH_PLAYER_OPTIONS)"+g $(TARGET_DIR)/etc/init.d/S28splash
endef

define KNULLI_SPLASH_INSTALL_BOOT_LOGO
    mkdir -p $(TARGET_DIR)/usr/share/knulli/splash
	# Universal KNULLIK logo used by the rootfs framebuffer fallback. This is
	# also installed on boards that do not include the custom initramfs package.
	python3 $(BR2_EXTERNAL_KNULLI_PATH)/scripts/knullik-boot-png-to-bmp.py \
	    --input $(BR2_EXTERNAL_KNULLI_PATH)/board/fsoverlay/usr/share/knulli/datainit/splash/boot.png \
	    --output $(TARGET_DIR)/usr/share/knulli/splash/knullik-default-splash.bmp
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo.png"               "${TARGET_DIR}/usr/share/knulli/splash/boot-logo.png"
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-240.png"           "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-320x240.png"
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-480p.png"          "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-640x480.png"
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-480p-rotate.png"   "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-480x640.png"
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-480p-rotate-left.png"   "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-480x640-left.png"
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-720p.png"          "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-1280x720.png"
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-768p.png"          "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-1024x768.png"
    
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-720p-square.png"   "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-720x720.png"

    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-3-2-480-rotate.png"    "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-320x480.png"
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-16-9-480-rotate.png"   "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-480x854.png"
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-720p-rotate.png"	    "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-720x1280.png"
#    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-800p-rotate.png"	    "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-800x1280.png"
#    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-1152-rotate.png"	    "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-1152x1920.png"
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-1080p-rotate.png"	    "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-1080x1920.png"
    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-1080p-rotate-left.png" "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-1080x1920-left.png"
#    cp "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-1200p-rotate.png"	    "${TARGET_DIR}/usr/share/knulli/splash/boot-logo-1200x1920.png"
endef

define KNULLI_SPLASH_INSTALL_VIDEO
    mkdir -p $(TARGET_DIR)/usr/share/knulli/splash
    cp $(BATO_SPLASH) $(TARGET_DIR)/usr/share/knulli/splash/splash.mp4
    echo -e "1\n00:00:00,000 --> 00:00:02,000\n$(KNULLI_SPLASH_TGVERSION)" > "${TARGET_DIR}/usr/share/knulli/splash/splash.srt"
endef

# Hack for CHA, custom Capcom splash video
define KNULLI_SPLASH_INSTALL_VIDEO_CAPCOM
    mkdir -p $(TARGET_DIR)/usr/share/knulli/splash
    cp $(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/videos/Capcom.mp4 $(TARGET_DIR)/usr/share/knulli/splash/Capcom.mp4
    echo -e "1\n00:00:00,000 --> 00:00:02,000\n$(KNULLI_SPLASH_TGVERSION)" > "${TARGET_DIR}/usr/share/knulli/splash/splash.srt"
endef

define KNULLI_SPLASH_INSTALL_IMAGE
    mkdir -p $(TARGET_DIR)/usr/share/knulli/splash
    convert "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo.png" -fill white -pointsize 30 -annotate +50+1020 "$(KNULLI_SPLASH_TGVERSION)" "${TARGET_DIR}/usr/share/knulli/splash/logo-version.png"
    convert "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-3-2-480-rotate.png" -fill white -pointsize 15 -annotate 270x270+300+440 "$(KNULLI_SPLASH_TGVERSION)" "${TARGET_DIR}/usr/share/knulli/splash/logo-version-320x480.png"
    convert "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-16-9-480-rotate.png" -fill white -pointsize 20 -annotate 270x270+440+814 "$(KNULLI_SPLASH_TGVERSION)" "${TARGET_DIR}/usr/share/knulli/splash/logo-version-480x854.png"
    convert "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-480p.png" -fill white -pointsize 20 -annotate +40+440 "$(KNULLI_SPLASH_TGVERSION)" "${TARGET_DIR}/usr/share/knulli/splash/logo-version-640x480.png"
    convert "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-240.png" -fill white -pointsize 15 -annotate +20+220 "$(KNULLI_SPLASH_TGVERSION)" "${TARGET_DIR}/usr/share/knulli/splash/logo-version-320x240.png"
#     convert "$(BR2_EXTERNAL_KNULLI_PATH)/package/system/knulli-splash/images/logo-480-dmg.png" -fill white -pointsize 20 -annotate +40+440 "$(KNULLI_SPLASH_TGVERSION)" "${TARGET_DIR}/usr/share/knulli/splash/logo-version-640x480-dmg.png"
endef

$(eval $(generic-package))
