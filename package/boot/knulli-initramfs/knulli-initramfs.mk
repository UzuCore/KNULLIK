################################################################################
#
# knulli-initramfs
#
################################################################################

KNULLI_INITRAMFS_VERSION = 1.36.1
KNULLI_INITRAMFS_SITE = http://www.busybox.net/downloads
KNULLI_INITRAMFS_SOURCE = busybox-$(KNULLI_INITRAMFS_VERSION).tar.bz2
KNULLI_INITRAMFS_LICENSE = GPLv2
KNULLI_INITRAMFS_LICENSE_FILES = LICENSE

KNULLI_INITRAMFS_DEPENDENCIES += host-uboot-tools libxcrypt
KNULLI_INITRAMFS_CFLAGS = $(TARGET_CFLAGS)
KNULLI_INITRAMFS_LDFLAGS = $(TARGET_LDFLAGS)
KNULLI_INITRAMFS_FBBOOT_SOURCE = $(BR2_EXTERNAL_KNULLI_PATH)/package/boot/knulli-initramfs/knulli-fbboot.c
KNULLI_INITRAMFS_BOOT_MOTD_SOURCE = $(BR2_EXTERNAL_KNULLI_PATH)/board/fsoverlay/etc/profile.d/30-welcome.sh
KNULLI_INITRAMFS_BOOT_MOTD_GEN = $(BR2_EXTERNAL_KNULLI_PATH)/scripts/rocknixk-generate-boot-motd-from-welcome.py
KNULLI_INITRAMFS_BOOT_MOTD_GENERATED = $(BUILD_DIR)/knulli-boot-motd/default-motd.txt

KNULLI_INITRAMFS_KCONFIG_FILE = \
    $(BR2_EXTERNAL_KNULLI_PATH)/package/boot/knulli-initramfs/busybox.config

INITRAMFS_DIR=$(BINARIES_DIR)/initramfs

# Allows the build system to tweak CFLAGS
KNULLI_INITRAMFS_MAKE_ENV = \
        $(TARGET_MAKE_ENV) \
        CFLAGS="$(KNULLI_INITRAMFS_CFLAGS)"
KNULLI_INITRAMFS_MAKE_OPTS = \
        CC="$(TARGET_CC)" \
        ARCH=$(KERNEL_ARCH) \
        PREFIX="$(INITRAMFS_DIR)" \
        EXTRA_LDFLAGS="$(KNULLI_INITRAMFS_LDFLAGS)" \
        CROSS_COMPILE="$(TARGET_CROSS)" \
        CONFIG_PREFIX="$(INITRAMFS_DIR)" \
        SKIP_STRIP=n

KNULLI_INITRAMFS_KCONFIG_OPTS = $(KNULLI_INITRAMFS_MAKE_OPTS)

KNULLI_INITRAMFS_DEPENDENCIES += host-lz4
define KNULLI_INITRAMFS_BUILD_CMDS
        $(KNULLI_INITRAMFS_MAKE_ENV) $(MAKE) $(KNULLI_INITRAMFS_MAKE_OPTS) -C $(@D)
        $(TARGET_CC) $(TARGET_CFLAGS) -Os -static -s \
            -o $(@D)/knulli-fbboot $(KNULLI_INITRAMFS_FBBOOT_SOURCE)
endef

ifeq ($(BR2_aarch64)$(BR2_TOOLCHAIN_OPTIONAL_LINARO_AARCH64),y)
KNULLI_INITRAMFS_INITRDA=arm64
else
KNULLI_INITRAMFS_INITRDA=arm
endif

# allwinner t527 u-boot workaround
ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_T527),y)
BATOCERA_INITRAMFS_INITRDA=arm
endif

ifeq ($(BR2_PACKAGE_BATOCERA_TARGET_SM8550),y)
KNULLI_INITRAMFS_DEPENDENCIES += firmware-armbian
define KNULLI_INITRAMFS_SM8550_EARLY_FIRMWARE
    mkdir -p $(INITRAMFS_DIR)/lib/firmware/qcom/sm8550/
    cp -R $(FIRMWARE_ARMBIAN_DIR)/qcom/sm8550/* \
        $(INITRAMFS_DIR)/lib/firmware/qcom/sm8550/
endef
KNULLI_INITRAMFS_PRE_INSTALL_TARGET_HOOKS += KNULLI_INITRAMFS_SM8550_EARLY_FIRMWARE
endif

define KNULLI_INITRAMFS_INSTALL_TARGET_CMDS
        mkdir -p $(INITRAMFS_DIR)
        cp $(BR2_EXTERNAL_KNULLI_PATH)/package/boot/knulli-initramfs/init \
            $(INITRAMFS_DIR)/init
        $(KNULLI_INITRAMFS_MAKE_ENV) $(MAKE) $(KNULLI_INITRAMFS_MAKE_OPTS) -C $(@D) install
        mkdir -p $(INITRAMFS_DIR)/bin $(TARGET_DIR)/usr/bin
        cp $(@D)/knulli-fbboot $(INITRAMFS_DIR)/bin/knulli-fbboot
        cp $(@D)/knulli-fbboot $(TARGET_DIR)/usr/bin/knulli-fbboot
	# KNULLI-KR generated boot MOTD install hook BEGIN
	@mkdir -p $(INITRAMFS_DIR)/etc $(TARGET_DIR)/usr/share/knulli $(dir $(KNULLI_INITRAMFS_BOOT_MOTD_GENERATED))
	@if test -f $(KNULLI_INITRAMFS_BOOT_MOTD_SOURCE); then 		BUILD_TEXT="$$(cat $(TARGET_DIR)/usr/share/knulli/knulli.version 2>/dev/null || true)"; 		KNULLI_BOOT_MOTD_MODEL="KNULLI" KNULLI_BOOT_MOTD_BUILD="$${BUILD_TEXT:-INITIALIZING}" 			python3 $(KNULLI_INITRAMFS_BOOT_MOTD_GEN) 			--welcome $(KNULLI_INITRAMFS_BOOT_MOTD_SOURCE) 			--output $(KNULLI_INITRAMFS_BOOT_MOTD_GENERATED) 			--max-logo-lines 9; 	else 		echo "WARNING: $(KNULLI_INITRAMFS_BOOT_MOTD_SOURCE) not found; using compiled fallback"; 	fi
	@if test -f $(KNULLI_INITRAMFS_BOOT_MOTD_GENERATED); then 		cp -f $(KNULLI_INITRAMFS_BOOT_MOTD_GENERATED) $(INITRAMFS_DIR)/etc/knulli-boot-motd; 		cp -f $(KNULLI_INITRAMFS_BOOT_MOTD_GENERATED) $(TARGET_DIR)/usr/share/knulli/boot-motd; 		echo "Installed generated KNULLI-KR boot MOTD from 30-welcome.sh"; 	fi
	# KNULLI-KR generated boot MOTD install hook END

        (cd $(INITRAMFS_DIR) && find . | cpio -H newc -o > $(BINARIES_DIR)/initrd)
        (cd $(BINARIES_DIR) && mkimage -A $(KNULLI_INITRAMFS_INITRDA) \
            -O linux -T ramdisk -C none -a 0 -e 0 -n initrd -d ./initrd ./uInitrd)
        $(COMPRESSION_TYPE_COMMAND)

endef

$(eval $(kconfig-package))
