# Integration patches rebased for the pinned emulator development sources.
# Explicit targets replace the original package patch directory while retaining global patches.
ifneq ($(AMIBERRY_TARGET_PATCH),)
$(AMIBERRY_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/amiberry $(addsuffix /$(AMIBERRY_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_AMIBERRY_TARGET_PATCH),)
$(HOST_AMIBERRY_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/amiberry $(addsuffix /$(HOST_AMIBERRY_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(APPLEWIN_TARGET_PATCH),)
$(APPLEWIN_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/applewin $(addsuffix /$(APPLEWIN_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_APPLEWIN_TARGET_PATCH),)
$(HOST_APPLEWIN_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/applewin $(addsuffix /$(HOST_APPLEWIN_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(DOSBOX_X_TARGET_PATCH),)
$(DOSBOX_X_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/dosbox-x $(addsuffix /$(DOSBOX_X_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_DOSBOX_X_TARGET_PATCH),)
$(HOST_DOSBOX_X_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/dosbox-x $(addsuffix /$(HOST_DOSBOX_X_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(FLYCAST_TARGET_PATCH),)
$(FLYCAST_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/flycast $(addsuffix /$(FLYCAST_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_FLYCAST_TARGET_PATCH),)
$(HOST_FLYCAST_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/flycast $(addsuffix /$(HOST_FLYCAST_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(GZDOOM_TARGET_PATCH),)
$(GZDOOM_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/gzdoom $(addsuffix /$(GZDOOM_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_GZDOOM_TARGET_PATCH),)
$(HOST_GZDOOM_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/gzdoom $(addsuffix /$(HOST_GZDOOM_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_BENNUGD_TARGET_PATCH),)
$(LIBRETRO_BENNUGD_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-bennugd $(addsuffix /$(LIBRETRO_BENNUGD_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_BENNUGD_TARGET_PATCH),)
$(HOST_LIBRETRO_BENNUGD_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-bennugd $(addsuffix /$(HOST_LIBRETRO_BENNUGD_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_DOLPHIN_TARGET_PATCH),)
$(LIBRETRO_DOLPHIN_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-dolphin $(addsuffix /$(LIBRETRO_DOLPHIN_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_DOLPHIN_TARGET_PATCH),)
$(HOST_LIBRETRO_DOLPHIN_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-dolphin $(addsuffix /$(HOST_LIBRETRO_DOLPHIN_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_FLYCASTVL_TARGET_PATCH),)
$(LIBRETRO_FLYCASTVL_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-flycastvl $(addsuffix /$(LIBRETRO_FLYCASTVL_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_FLYCASTVL_TARGET_PATCH),)
$(HOST_LIBRETRO_FLYCASTVL_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-flycastvl $(addsuffix /$(HOST_LIBRETRO_FLYCASTVL_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_GEOLITH_TARGET_PATCH),)
$(LIBRETRO_GEOLITH_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-geolith $(addsuffix /$(LIBRETRO_GEOLITH_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_GEOLITH_TARGET_PATCH),)
$(HOST_LIBRETRO_GEOLITH_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-geolith $(addsuffix /$(HOST_LIBRETRO_GEOLITH_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_HATARI_TARGET_PATCH),)
$(LIBRETRO_HATARI_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-hatari $(addsuffix /$(LIBRETRO_HATARI_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_HATARI_TARGET_PATCH),)
$(HOST_LIBRETRO_HATARI_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-hatari $(addsuffix /$(HOST_LIBRETRO_HATARI_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_HATARIB_TARGET_PATCH),)
$(LIBRETRO_HATARIB_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-hatarib $(addsuffix /$(LIBRETRO_HATARIB_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_HATARIB_TARGET_PATCH),)
$(HOST_LIBRETRO_HATARIB_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-hatarib $(addsuffix /$(HOST_LIBRETRO_HATARIB_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_LUTRO_TARGET_PATCH),)
$(LIBRETRO_LUTRO_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-lutro $(addsuffix /$(LIBRETRO_LUTRO_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_LUTRO_TARGET_PATCH),)
$(HOST_LIBRETRO_LUTRO_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-lutro $(addsuffix /$(HOST_LIBRETRO_LUTRO_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_O2EM_TARGET_PATCH),)
$(LIBRETRO_O2EM_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-o2em $(addsuffix /$(LIBRETRO_O2EM_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_O2EM_TARGET_PATCH),)
$(HOST_LIBRETRO_O2EM_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-o2em $(addsuffix /$(HOST_LIBRETRO_O2EM_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_PANDA3DS_TARGET_PATCH),)
$(LIBRETRO_PANDA3DS_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-panda3ds $(addsuffix /$(LIBRETRO_PANDA3DS_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_PANDA3DS_TARGET_PATCH),)
$(HOST_LIBRETRO_PANDA3DS_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-panda3ds $(addsuffix /$(HOST_LIBRETRO_PANDA3DS_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_PARALLEL_N64_TARGET_PATCH),)
$(LIBRETRO_PARALLEL_N64_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-parallel-n64 $(addsuffix /$(LIBRETRO_PARALLEL_N64_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_PARALLEL_N64_TARGET_PATCH),)
$(HOST_LIBRETRO_PARALLEL_N64_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-parallel-n64 $(addsuffix /$(HOST_LIBRETRO_PARALLEL_N64_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_PPSSPP_TARGET_PATCH),)
$(LIBRETRO_PPSSPP_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-ppsspp $(addsuffix /$(LIBRETRO_PPSSPP_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_PPSSPP_TARGET_PATCH),)
$(HOST_LIBRETRO_PPSSPP_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-ppsspp $(addsuffix /$(HOST_LIBRETRO_PPSSPP_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_PS2_TARGET_PATCH),)
$(LIBRETRO_PS2_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-ps2 $(addsuffix /$(LIBRETRO_PS2_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_PS2_TARGET_PATCH),)
$(HOST_LIBRETRO_PS2_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-ps2 $(addsuffix /$(HOST_LIBRETRO_PS2_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(LIBRETRO_PUAE_TARGET_PATCH),)
$(LIBRETRO_PUAE_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-puae $(addsuffix /$(LIBRETRO_PUAE_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_LIBRETRO_PUAE_TARGET_PATCH),)
$(HOST_LIBRETRO_PUAE_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-puae $(addsuffix /$(HOST_LIBRETRO_PUAE_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(MAME_TARGET_PATCH),)
$(MAME_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/mame $(addsuffix /$(MAME_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_MAME_TARGET_PATCH),)
$(HOST_MAME_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/mame $(addsuffix /$(HOST_MAME_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(MUPEN64PLUS_CORE_TARGET_PATCH),)
$(MUPEN64PLUS_CORE_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/mupen64plus-core $(addsuffix /$(MUPEN64PLUS_CORE_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_MUPEN64PLUS_CORE_TARGET_PATCH),)
$(HOST_MUPEN64PLUS_CORE_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/mupen64plus-core $(addsuffix /$(HOST_MUPEN64PLUS_CORE_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(PANDA3DS_TARGET_PATCH),)
$(PANDA3DS_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/panda3ds $(addsuffix /$(PANDA3DS_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_PANDA3DS_TARGET_PATCH),)
$(HOST_PANDA3DS_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/panda3ds $(addsuffix /$(HOST_PANDA3DS_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(PCSX2_TARGET_PATCH),)
$(PCSX2_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/pcsx2 $(addsuffix /$(PCSX2_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_PCSX2_TARGET_PATCH),)
$(HOST_PCSX2_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/pcsx2 $(addsuffix /$(HOST_PCSX2_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(PPSSPP_TARGET_PATCH),)
$(PPSSPP_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/ppsspp $(addsuffix /$(PPSSPP_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_PPSSPP_TARGET_PATCH),)
$(HOST_PPSSPP_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/ppsspp $(addsuffix /$(HOST_PPSSPP_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(SIMCOUPE_TARGET_PATCH),)
$(SIMCOUPE_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/simcoupe $(addsuffix /$(SIMCOUPE_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_SIMCOUPE_TARGET_PATCH),)
$(HOST_SIMCOUPE_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/simcoupe $(addsuffix /$(HOST_SIMCOUPE_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(SNES9X_TARGET_PATCH),)
$(SNES9X_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/snes9x $(addsuffix /$(SNES9X_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_SNES9X_TARGET_PATCH),)
$(HOST_SNES9X_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/snes9x $(addsuffix /$(HOST_SNES9X_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(SUPERMODEL_ES_TARGET_PATCH),)
$(SUPERMODEL_ES_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/supermodel-es $(addsuffix /$(SUPERMODEL_ES_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_SUPERMODEL_ES_TARGET_PATCH),)
$(HOST_SUPERMODEL_ES_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/supermodel-es $(addsuffix /$(HOST_SUPERMODEL_ES_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(VITA3K_TARGET_PATCH),)
$(VITA3K_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/vita3k $(addsuffix /$(VITA3K_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif
ifneq ($(HOST_VITA3K_TARGET_PATCH),)
$(HOST_VITA3K_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/vita3k $(addsuffix /$(HOST_VITA3K_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
endif

$(LIBRETRO_DOSBOX_PURE_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-dosbox-pure $(addsuffix /$(LIBRETRO_DOSBOX_PURE_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))

$(LIBRETRO_PC98_TARGET_PATCH): PATCH_BASE_DIRS = $(BR2_EXTERNAL_KNULLI_PATH)/package/emulator-patches/libretro-pc98 $(addsuffix /$(LIBRETRO_PC98_RAWNAME),$(call qstrip,$(BR2_GLOBAL_PATCH_DIR)))
