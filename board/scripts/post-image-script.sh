#!/bin/bash -e

# Enable for debug
# set -x

# PWD = source dir
# BASE_DIR = build dir
# BUILD_DIR = base dir/build
# HOST_DIR = base dir/host
# BINARIES_DIR = images dir
# TARGET_DIR = target dir

##### constants ################
KNULLI_BINARIES_DIR="${BINARIES_DIR}/knulli"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
RELEASES_DIR="${BASE_DIR}/releases"
UPDATES_DIR="${BASE_DIR}/updates"
################################

# KNULLI-KR: ensure H700 boot package files required by genimage.
# Some H700 genimage configs reference:
#   ../../h700-boot-packages/<device>_boot_package.fex
# The canonical files live under board/allwinner/h700/<device>/partitions/.
ensure_h700_boot_packages() {
    KNULLI_ROOT="${BR2_EXTERNAL_KNULLI_PATH:-/build}"
    H700_PART_ROOT="${KNULLI_ROOT}/board/allwinner/h700"

    [ -n "${BINARIES_DIR:-}" ] || return 0
    [ -d "${H700_PART_ROOT}" ] || return 0

    mkdir -p "${BINARIES_DIR}/h700-boot-packages" || exit 1

    for _bp in "${H700_PART_ROOT}"/*/partitions/boot_package.fex; do
        [ -f "${_bp}" ] || continue
        _dev="$(basename "$(dirname "$(dirname "${_bp}")")")"
        cp -f "${_bp}" "${BINARIES_DIR}/h700-boot-packages/${_dev}_boot_package.fex" || exit 1
    done
}

##### find images to build #####
KNULLI_TARGET=$(grep -E "^BR2_PACKAGE_BATOCERA_TARGET_[A-Z_0-9]*=y$" "${BR2_CONFIG}" | grep -vE "_ANY=" | grep -vE "_GLES[0-9]*=" | sed -e s+'^BR2_PACKAGE_BATOCERA_TARGET_\([A-Z_0-9]*\)=y$'+'\1'+)
KNULLI_LOWER_TARGET=$(echo "${KNULLI_TARGET}" | tr '[:upper:]' '[:lower:]')
KNULLI_IMAGES_TARGETS=$(grep -E "^BR2_TARGET_KNULLI_IMAGES[ ]*=[ ]*\".*\"[ ]*$" "${BR2_CONFIG}" | sed -e s+"^BR2_TARGET_KNULLI_IMAGES[ ]*=[ ]*\"\(.*\)\"[ ]*$"+"\1"+)
if test -z "${KNULLI_IMAGES_TARGETS}"
then
    echo "no BR2_TARGET_KNULLI_IMAGES defined." >&2
    exit 1
fi

if [ "${KNULLI_LOWER_TARGET}" = "h700" ]; then
    ensure_h700_boot_packages
fi
################################

#### common parent dir to al images #
if echo "${KNULLI_IMAGES_TARGETS}" | grep -qE '^[^ ]*$'
then
    # single board directory
    IMGMODE=single
else
    # when there are several one, the first one is the common directory where to find the create-boot-script.sh directory
    IMGMODE=multi
fi

#### clean the (previous if exists) target directory ###
if test -d "${KNULLI_BINARIES_DIR}"
then
    rm -rf "${KNULLI_BINARIES_DIR}" || exit 1
fi
mkdir -p "${KNULLI_BINARIES_DIR}/images" || exit 1

##### build images #############
#SUFFIXVERSION=$(cat "${TARGET_DIR}/usr/share/knulli/knulli.version" | sed -e s+'^\([0-9\.]*\).*$'+'\1'+) # xx.yy version
SUFFIXVERSION=$(awk '{if ($1 ~ /^[0-9\.]+$/) print $1; else print $1}' "${TARGET_DIR}/usr/share/knulli/knulli.version") # Handle numeric and codename strings versions

SUFFIXDATE=$(date +%Y%m%d)

#### build the images ###########
for KNULLI_PATHSUBTARGET in ${KNULLI_IMAGES_TARGETS}
do
    KNULLI_SUBTARGET=$(basename "${KNULLI_PATHSUBTARGET}")

    #### prepare the boot dir ######
    BOOTNAMEDDIR="${KNULLI_BINARIES_DIR}/boot_${KNULLI_SUBTARGET}"
    rm -rf "${BOOTNAMEDDIR}" || exit 1 # remove in case or rerun
    KNULLI_POST_IMAGE_SCRIPT="${BR2_EXTERNAL_KNULLI_PATH}/board/${KNULLI_PATHSUBTARGET}/create-boot-script.sh"
    # Some legacy board create-boot-script.sh files expect ${BINARIES_DIR}/firmware.sig
    # to exist before the boot directory is fully assembled. Create a temporary
    # placeholder so the legacy copy step succeeds. It will be replaced with the
    # real per-subtarget signature below, after the boot files are assembled.
    if [ ! -s "${BINARIES_DIR}/firmware.sig" ]; then
        cat > "${BINARIES_DIR}/firmware.sig" <<EOF
# Firmware Signature File
# Temporary placeholder generated before board boot assembly.
# Replaced by board/scripts/post-image-script.sh after boot files are assembled.
EOF
    fi

    bash "${KNULLI_POST_IMAGE_SCRIPT}" "${HOST_DIR}" "${BR2_EXTERNAL_KNULLI_PATH}/board/${KNULLI_PATHSUBTARGET}" "${BUILD_DIR}" "${BINARIES_DIR}" "${TARGET_DIR}" "${KNULLI_BINARIES_DIR}" || exit 1
    # add some common files
    # KNULLI-KR: knulli-boot.conf may already be generated in ${KNULLI_BINARIES_DIR}/boot.
    # Do not fail if the old top-level ${BINARIES_DIR}/knulli-boot.conf is absent.
    if [ -f "${BINARIES_DIR}/knulli-boot.conf" ]; then
        cp -f "${BINARIES_DIR}/knulli-boot.conf" "${KNULLI_BINARIES_DIR}/boot/"
    elif [ -f "${KNULLI_BINARIES_DIR}/boot/knulli-boot.conf" ]; then
        echo "[KNULLI-KR] using existing ${KNULLI_BINARIES_DIR}/boot/knulli-boot.conf"
    elif [ -f "${TARGET_DIR}/boot/knulli-boot.conf" ]; then
        cp -f "${TARGET_DIR}/boot/knulli-boot.conf" "${KNULLI_BINARIES_DIR}/boot/"
    else
        echo "[WARN] knulli-boot.conf not found; continuing without extra copy"
    fi
    echo   "${KNULLI_SUBTARGET}" > "${KNULLI_BINARIES_DIR}/boot/boot/knulli.board" || exit 1

    #### remove early bootloader logo before signatures/archive/image ##########
    # KNULLI-KR: keep board create-boot-script.sh files untouched, but remove
    # H700 bootlogo.bmp from the assembled boot directory. This prevents the
    # bootloader logo from being shown before the initramfs fb0 MOTD appears.
    # The removal happens before firmware.sig, boot.tar.gz, and the final image
    # are generated, so hashes and packaged images reflect the final contents.
    if [ "${KNULLI_LOWER_TARGET}" = "h700" ]; then
        if [ -f "${KNULLI_BINARIES_DIR}/boot/bootlogo.bmp" ]; then
            rm -f "${KNULLI_BINARIES_DIR}/boot/bootlogo.bmp" || exit 1
            echo "[KNULLI-KR] removed H700 bootlogo.bmp from assembled boot directory" >&2
        else
            echo "[KNULLI-KR] H700 bootlogo.bmp not present; skipping removal" >&2
        fi
    fi

    #### create the update signatures (after boot dir is assembled so we hash the actual on-device files) #####
    KNULLI_SIGNATURES_SCRIPT="${BR2_EXTERNAL_KNULLI_PATH}/board/scripts/generate_signature.sh"
    KNULLI_SIGNATURE_FILE="${KNULLI_BINARIES_DIR}/firmware-${KNULLI_SUBTARGET}.sig"
    KNULLI_BOOT_SIGNATURE_FILE="${KNULLI_BINARIES_DIR}/boot/boot/firmware.sig"

    # Generate a real per-subtarget signature file and then embed it into the boot FAT.
    # Do not rely on the legacy global ${BINARIES_DIR}/firmware.sig path; it is fragile
    # for multi-image builds and was the source of the missing firmware.sig failure.
    bash "${KNULLI_SIGNATURES_SCRIPT}" \
        "${BR2_EXTERNAL_KNULLI_PATH}/board/${KNULLI_PATHSUBTARGET}" \
        "${BINARIES_DIR}" \
        "${KNULLI_BINARIES_DIR}/boot" \
        "${KNULLI_SIGNATURE_FILE}" || exit 1

    echo "[KNULLI] post-image signature fix active: ${KNULLI_SIGNATURE_FILE}" >&2

    if [ ! -s "${KNULLI_SIGNATURE_FILE}" ]; then
        echo "[ERROR] firmware signature was not generated: ${KNULLI_SIGNATURE_FILE}" >&2
        exit 1
    fi

    # copy firmware.sig into the boot dir so it is included in the archive and the final image
    cp "${KNULLI_SIGNATURE_FILE}" "${KNULLI_BOOT_SIGNATURE_FILE}" || exit 1

    #### boot.tar.gz ###############
    echo "creating images/${KNULLI_SUBTARGET}/boot.tar.gxz"
    mkdir -p "${KNULLI_BINARIES_DIR}/images/${KNULLI_SUBTARGET}" || exit 1
    (cd "${KNULLI_BINARIES_DIR}/boot" && tar -cf - * | pigz -9 > "${KNULLI_BINARIES_DIR}/images/${KNULLI_SUBTARGET}/knulli-${KNULLI_LOWER_TARGET}-${KNULLI_SUBTARGET}-${SUFFIXVERSION}-${SUFFIXDATE}_boot.tar.gz") || exit 1

    # rename the squashfs : the .update is the version that will be renamed at boot to replace the old version
    mv "${KNULLI_BINARIES_DIR}/boot/boot/knulli.update" "${KNULLI_BINARIES_DIR}/boot/boot/knulli" || exit 1

    # create *.img
    if [ "${KNULLI_LOWER_TARGET}" = "${KNULLI_SUBTARGET}" ]; then
        KNULLIIMG="${KNULLI_BINARIES_DIR}/images/${KNULLI_SUBTARGET}/knulli-${KNULLI_SUBTARGET}-${SUFFIXVERSION}-${SUFFIXDATE}.img"
    else
        KNULLIIMG="${KNULLI_BINARIES_DIR}/images/${KNULLI_SUBTARGET}/knulli-${KNULLI_LOWER_TARGET}-${KNULLI_SUBTARGET}-${SUFFIXVERSION}-${SUFFIXDATE}.img"
    fi
    echo "creating images/${KNULLI_SUBTARGET}/"$(basename "${KNULLIIMG}")"..." >&2
    rm -rf "${GENIMAGE_TMP}" || exit 1
    GENIMAGEDIR="${BR2_EXTERNAL_KNULLI_PATH}/board/${KNULLI_PATHSUBTARGET}"
    GENIMAGEFILE="${GENIMAGEDIR}/genimage.cfg"

    # Generate the genimage config with proper file entries
    {
        # Copy everything before @files
        sed -n '1,/@files/p' "${GENIMAGEFILE}" | sed '/@files/d'
        
        # Generate file entries
        find "${KNULLI_BINARIES_DIR}/boot" -type f | sed -e "s|^${KNULLI_BINARIES_DIR}/boot/\(.*\)$|                        file \"\1\" { image = \"\1\" }|"
        
        # Copy everything after @files
        sed -n '/@files/,$p' "${GENIMAGEFILE}" | sed '1d'
        
    } > "${KNULLI_BINARIES_DIR}/genimage.cfg" || exit 1

    # install syslinux
    if grep -qE "^BR2_TARGET_SYSLINUX=y$" "${BR2_CONFIG}"
    then
        GENIMAGEBOOTFILE="${GENIMAGEDIR}/genimage-boot.cfg"
        echo "installing syslinux" >&2
        cat "${GENIMAGEBOOTFILE}" | sed -e s+'@files'+"${FILES}"+ | tr '@' '\n' > "${KNULLI_BINARIES_DIR}/genimage-boot.cfg" || exit 1
        genimage --rootpath="${TARGET_DIR}" --inputpath="${KNULLI_BINARIES_DIR}/boot" --outputpath="${KNULLI_BINARIES_DIR}" --config="${KNULLI_BINARIES_DIR}/genimage-boot.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1
        "${HOST_DIR}/bin/syslinux" -i "${KNULLI_BINARIES_DIR}/boot.vfat" -d "/boot/syslinux" || exit 1
        # remove genimage temp path as sometimes genimage v14 fails to start
        rm -rf ${GENIMAGE_TMP}
        mkdir ${GENIMAGE_TMP}
    fi

    # Generate knulli.img
    "${HOST_DIR}/bin/genimage" --rootpath="${TARGET_DIR}" --inputpath="${KNULLI_BINARIES_DIR}/boot" --outputpath="${KNULLI_BINARIES_DIR}" --config="${KNULLI_BINARIES_DIR}/genimage.cfg" --tmppath="${GENIMAGE_TMP}" || exit 1
 
    # Remove temporary images
    rm -f "${KNULLI_BINARIES_DIR}/boot.vfat" || exit 1
    rm -f "${KNULLI_BINARIES_DIR}/userdata.ext4" || exit 1
    mv "${KNULLI_BINARIES_DIR}/knulli.img" "${KNULLIIMG}" || exit 1
    pigz "${KNULLIIMG}" || exit 1

    # rename the boot to boot_arch
    mv "${KNULLI_BINARIES_DIR}/boot" "${BOOTNAMEDDIR}" || exit 1

    # copy the version file needed for version check
    cp "${TARGET_DIR}/usr/share/knulli/knulli.version" "${KNULLI_BINARIES_DIR}/images/${KNULLI_SUBTARGET}" || exit 1

    # copy the update signature file generated for this subtarget
    cp "${KNULLI_SIGNATURE_FILE}" "${KNULLI_BINARIES_DIR}/images/${KNULLI_SUBTARGET}/firmware.sig" || exit 1
done

#### Create the rootfs patches ##########
# Only process if there are previous rootfs files to diff against
if ls "${RELEASES_DIR}/"*"_rootfs.squashfs" 1> /dev/null 2>&1; then
    # Calculate the current rootfs.squashfs md5sum
    CURRENT_ROOTFS_MD5SUM=$(md5sum "${BINARIES_DIR}/rootfs.squashfs" | awk '{ print $1 }')
    for ROOTFS_TARGET in "${RELEASES_DIR}/"*"_rootfs.squashfs"
    do
        # ROOTFS_TARGET is in the form of md5sum_rootfs.squashfs. We need to extract the md5sum into a variable
        ROOTFS_MD5SUM=$(basename "${ROOTFS_TARGET}" | sed -e s+'^\([0-9a-f]*\)_rootfs.squashfs$'+'\1'+)
        echo "Creating delta from ${ROOTFS_TARGET} (source) to current rootfs.squashfs (target) with source md5sum ${ROOTFS_MD5SUM}"
        # Create patches directory if it does not exist
        mkdir -p "${UPDATES_DIR}/patches" || exit 1
        echo "Creating patch file ${UPDATES_DIR}/patches/${ROOTFS_MD5SUM}_to_${CURRENT_ROOTFS_MD5SUM}.patch"
        # create the delta.xdelta3 patch that can be applied to the old rootfs to get the new rootfs
        xdelta3 -e -S none -s "${ROOTFS_TARGET}" "${BINARIES_DIR}/rootfs.squashfs" "${UPDATES_DIR}/patches/${ROOTFS_MD5SUM}_to_${CURRENT_ROOTFS_MD5SUM}.patch" || exit 1
    done
else
    echo "No previous rootfs files found in ${RELEASES_DIR} - skipping delta creation"
fi

#### md5 and sha256 #######################
for FILE in "${KNULLI_BINARIES_DIR}/images/"*"/knulli-"*"_boot.tar.gz" "${KNULLI_BINARIES_DIR}/images/"*"/knulli-"*".img.gz"
do
    echo "creating ${FILE}.md5"
    CKS=$(md5sum "${FILE}" | sed -e s+'^\([^ ]*\) .*$'+'\1'+)
    echo "${CKS}" > "${FILE}.md5"
    echo "${CKS}  $(basename "${FILE}")" >> "${KNULLI_BINARIES_DIR}/MD5SUMS"
    echo "creating ${FILE}.sha256"
    CKS=$(sha256sum "${FILE}" | sed -e s+'^\([^ ]*\) .*$'+'\1'+)
    echo "${CKS}" > "${FILE}.sha256"
    echo "${CKS}  $(basename "${FILE}")" >> "${KNULLI_BINARIES_DIR}/SHA256SUMS"
done

#### update the target dir with some information files
cp "${TARGET_DIR}/usr/share/knulli/knulli.version" "${KNULLI_BINARIES_DIR}" || exit 1
"${BR2_EXTERNAL_KNULLI_PATH}"/scripts/linux/systemsReport.sh "${PWD}" "${KNULLI_BINARIES_DIR}" || exit 1
