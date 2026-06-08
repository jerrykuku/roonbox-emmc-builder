#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR="${SCRIPT_DIR}"
REPO_DIR=$(cd "${PROJECT_DIR}/.." && pwd)

DEFAULT_INPUT="${REPO_DIR}/roonbox-linuxx64-nuc4-usb-factoryreset.img.gz"
DEFAULT_WORKDIR="/tmp/roonbox-emmc-builder"
DEFAULT_KERNEL_ROOT="/tmp/kernelbuild"
DEFAULT_DIST_DIR="${PROJECT_DIR}/dist"
DEFAULT_OFFICIAL_IMAGE_URL="https://download.roonlabs.net/builds/roonbox-linuxx64-nuc4-usb-factoryreset.img.gz"
JOBS=$(nproc)

INPUT_IMAGE="${DEFAULT_INPUT}"
WORKDIR="${DEFAULT_WORKDIR}"
KERNEL_ROOT="${DEFAULT_KERNEL_ROOT}"
DIST_DIR="${DEFAULT_DIST_DIR}"
OFFICIAL_IMAGE_URL="${DEFAULT_OFFICIAL_IMAGE_URL}"
KEEP_WORK=0
FORCE_REBUILD=0
FAST_MODE=0
DOWNLOAD_OFFICIAL=0
OUTPUT_PREFIX=""

KERNEL_5_VER="5.15.72"
KERNEL_6_VER="6.6.33"
KERNEL_5_URL="https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${KERNEL_5_VER}.tar.xz"
KERNEL_6_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_6_VER}.tar.xz"

log() {
    printf '[%s] %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S')" "$*"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Build a Roon ROCK eMMC-enabled image from the original factory-reset image.

Options:
  -i, --input <path>         Source .img.gz or .img
  -u, --official-url <url>   Official image URL (default: ${DEFAULT_OFFICIAL_IMAGE_URL})
  -o, --output-prefix <path> Output prefix without .img/.gz suffix
  -w, --workdir <path>       Working directory (default: ${DEFAULT_WORKDIR})
  -k, --kernel-root <path>   Kernel source cache/build root (default: ${DEFAULT_KERNEL_ROOT})
  -d, --dist-dir <path>      Output directory for artifacts (default: ${DEFAULT_DIST_DIR})
  -j, --jobs <n>             Parallel build jobs (default: nproc)
      --download-official    Download the official image from Roon before building
      --fast                 Skip kernel extraction/build and reuse cached kernel artifacts
      --keep-work            Keep working directory after success
      --force-rebuild        Rebuild kernels even if cached outputs already exist
  -h, --help                 Show this help

Example:
  $(basename "$0") \\
    --download-official \\
    --output-prefix ./dist/roonbox-linuxx64-nuc4-usb-factoryreset-emmc
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--input)
            INPUT_IMAGE="$2"
            shift 2
            ;;
        -o|--output-prefix)
            OUTPUT_PREFIX="$2"
            shift 2
            ;;
        -u|--official-url)
            OFFICIAL_IMAGE_URL="$2"
            shift 2
            ;;
        -w|--workdir)
            WORKDIR="$2"
            shift 2
            ;;
        -k|--kernel-root)
            KERNEL_ROOT="$2"
            shift 2
            ;;
        -d|--dist-dir)
            DIST_DIR="$2"
            shift 2
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        --keep-work)
            KEEP_WORK=1
            shift
            ;;
        --fast)
            FAST_MODE=1
            shift
            ;;
        --download-official)
            DOWNLOAD_OFFICIAL=1
            shift
            ;;
        --force-rebuild)
            FORCE_REBUILD=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1"
            ;;
    esac
done

need_tool() {
    command -v "$1" >/dev/null 2>&1 || die "Required tool not found: $1"
}

cleanup() {
    if [[ ${KEEP_WORK} -eq 0 && -d "${WORKDIR}" ]]; then
        rm -rf "${WORKDIR}"
    fi
}

trap cleanup EXIT

require_tools() {
    local tools=(
        awk bzip2 cpio curl fdisk file find grep gzip make mcopy mdir mksquashfs
        perl sed sha256sum strings tar unsquashfs xz yes
    )
    local tool
    for tool in "${tools[@]}"; do
        need_tool "${tool}"
    done
}

require_cached_kernels() {
    [[ -f "${KERNEL5_OUTPUT}" ]] || die "Missing cached kernel: ${KERNEL5_OUTPUT}"
    [[ -f "${KERNEL6_OUTPUT}" ]] || die "Missing cached kernel: ${KERNEL6_OUTPUT}"
    [[ -f "${CONFIG5_OUTPUT}" ]] || die "Missing cached config: ${CONFIG5_OUTPUT}"
    [[ -f "${CONFIG6_OUTPUT}" ]] || die "Missing cached config: ${CONFIG6_OUTPUT}"
}

prepare_dirs() {
    mkdir -p "${DIST_DIR}" "${KERNEL_ROOT}"
    rm -rf "${WORKDIR}"
    mkdir -p "${WORKDIR}"
    STAGE_DIR="${WORKDIR}/stage"
    SRC_DIR="${WORKDIR}/src"
    OUTER_DIR="${WORKDIR}/outer"
    INSTALL_OS_DIR="${WORKDIR}/installos"
    ROOTFS_DIR="${WORKDIR}/rootfs"
    INITRAMFS_DIR="${WORKDIR}/initramfs"
    ARTIFACT_DIR="${WORKDIR}/artifacts"
    VERIFY_DIR="${WORKDIR}/verify"
    mkdir -p "${STAGE_DIR}" "${SRC_DIR}" "${OUTER_DIR}" "${INSTALL_OS_DIR}" \
        "${ROOTFS_DIR}" "${INITRAMFS_DIR}" "${ARTIFACT_DIR}" "${VERIFY_DIR}"
}

normalize_input() {
    local source_name

    if [[ ${DOWNLOAD_OFFICIAL} -eq 1 ]]; then
        local downloaded_image
        source_name=$(basename "${OFFICIAL_IMAGE_URL%%\?*}")
        downloaded_image="${SRC_DIR}/official-factoryreset.img.gz"
        log "Downloading official image from ${OFFICIAL_IMAGE_URL}"
        curl -L --fail --output "${downloaded_image}" "${OFFICIAL_IMAGE_URL}"
        INPUT_IMAGE="${downloaded_image}"
    else
        source_name=$(basename "${INPUT_IMAGE}")
    fi

    [[ -f "${INPUT_IMAGE}" ]] || die "Input image not found: ${INPUT_IMAGE}"

    case "${INPUT_IMAGE}" in
        *.img.gz)
            ORIGINAL_IMG="${SRC_DIR}/source.img"
            log "Decompressing source image"
            gzip -dc "${INPUT_IMAGE}" > "${ORIGINAL_IMG}"
            ;;
        *.img)
            ORIGINAL_IMG="${SRC_DIR}/source.img"
            cp "${INPUT_IMAGE}" "${ORIGINAL_IMG}"
            ;;
        *)
            die "Input must be .img or .img.gz"
            ;;
    esac

    if [[ -z "${OUTPUT_PREFIX}" ]]; then
        local base
        base="${source_name}"
        base=${base%.gz}
        base=${base%.img}
        OUTPUT_PREFIX="${DIST_DIR}/${base}-emmc"
    fi

    OUTPUT_IMG="${OUTPUT_PREFIX}.img"
    OUTPUT_IMG_GZ="${OUTPUT_PREFIX}.img.gz"
}

get_partition_offset() {
    local img="$1"
    local start
    start=$(fdisk -l "${img}" | awk -v want="${img}1" '$1 == want { print $2; exit }')
    [[ -n "${start}" ]] || die "Failed to locate EFI partition start for ${img}"
    echo $((start * 512))
}

copy_from_image() {
    local img="$1"
    local offset="$2"
    local src="$3"
    local dst="$4"
    rm -f "${dst}"
    mcopy -o -i "${img}@@${offset}" "${src}" "${dst}"
}

copy_to_image() {
    local img="$1"
    local offset="$2"
    local src="$3"
    local dst="$4"
    mcopy -o -i "${img}@@${offset}" "${src}" "${dst}"
}

fetch_kernel_tree() {
    local version="$1"
    local url="$2"
    local tarball="${KERNEL_ROOT}/linux-${version}.tar.xz"
    local tree="${KERNEL_ROOT}/linux-${version}"

    if [[ ! -f "${tarball}" ]]; then
        log "Downloading linux-${version}"
        curl -L --fail --output "${tarball}" "${url}"
    fi

    if [[ ! -d "${tree}" ]]; then
        log "Extracting linux-${version}"
        tar -C "${KERNEL_ROOT}" -xf "${tarball}"
    fi

    echo "${tree}"
}

ensure_objtool_wrapper() {
    local tree="$1"
    local header="${tree}/tools/include/asm/byteorder.h"
    mkdir -p "$(dirname "${header}")"
    cat > "${header}" <<'EOF'
#ifndef _TOOLS_ASM_BYTEORDER_H
#define _TOOLS_ASM_BYTEORDER_H

#include "../../../arch/x86/include/uapi/asm/byteorder.h"

#endif
EOF
}

extract_original_assets() {
    EFI_OFFSET=$(get_partition_offset "${ORIGINAL_IMG}")
    log "EFI partition offset: ${EFI_OFFSET}"

    copy_from_image "${ORIGINAL_IMG}" "${EFI_OFFSET}" "::bzImage.efi" "${OUTER_DIR}/bzImage.efi"
    copy_from_image "${ORIGINAL_IMG}" "${EFI_OFFSET}" "::initramfs" "${OUTER_DIR}/initramfs"
    copy_from_image "${ORIGINAL_IMG}" "${EFI_OFFSET}" "::install-os.tar" "${OUTER_DIR}/install-os.tar"

    tar -xf "${OUTER_DIR}/install-os.tar" -C "${INSTALL_OS_DIR}"
}

extract_ikconfig() {
    local tree="$1"
    local kernel="$2"
    local output="$3"
    sh "${tree}/scripts/extract-ikconfig" "${kernel}" > "${output}"
    [[ -s "${output}" ]] || die "Failed to extract IKCONFIG from ${kernel}"
}

build_kernel() {
    local version="$1"
    local tree="$2"
    local source_config="$3"
    local output_kernel="$4"
    local output_config="$5"

    if [[ ${FORCE_REBUILD} -eq 0 && -f "${output_kernel}" && -f "${output_config}" ]]; then
        log "Reusing cached kernel ${version}: ${output_kernel}"
        return 0
    fi

    log "Building kernel ${version}"
    make -C "${tree}" mrproper >/dev/null
    ensure_objtool_wrapper "${tree}"
    cp "${source_config}" "${tree}/.config"
    make -C "${tree}" olddefconfig </dev/null >/dev/null
    "${tree}/scripts/config" --file "${tree}/.config" \
        --enable MMC \
        --enable MMC_BLOCK \
        --enable MMC_SDHCI \
        --enable MMC_SDHCI_PCI \
        --enable MMC_SDHCI_ACPI \
        --enable MMC_RICOH_MMC \
        --enable MMC_CQHCI \
        --enable MMC_TOSHIBA_PCI
    make -C "${tree}" olddefconfig </dev/null >/dev/null
    make -C "${tree}" -j"${JOBS}" bzImage
    cp "${tree}/arch/x86/boot/bzImage" "${output_kernel}"
    cp "${tree}/.config" "${output_config}"
}

patch_installer_init() {
    local file="$1"
    local tmp="${file}.tmp"
    local mode
    mode=$(stat -c '%a' "${file}")

    if ! grep -q 'get_partprefix()' "${file}"; then
        awk '
            $0 == "DISKS=\"\"" {
                print "get_partprefix() {"
                print "    case \"$1\" in"
                print "        *nvme*|*mmcblk*) echo p ;;"
                print "        *) echo ;;"
                print "    esac"
                print "}"
                print ""
                print "compute_partition_sizes() {"
                print "    DISK_DEV=$(basename \"$INSTALLDISK\")"
                print "    DISK_SECTORS=$(cat /sys/block/$DISK_DEV/size 2>/dev/null)"
                print "    [ -n \"$DISK_SECTORS\" ] || die \"Could not determine disk size\""
                print "    DISK_MIB=$((DISK_SECTORS / 2048))"
                print ""
                print "    EFI_MIB=100"
                print "    if [ \"$DISK_MIB\" -ge 43000 ]; then"
                print "        OS_MIB=16384"
                print "        APP_MIB=16384"
                print "    elif [ \"$DISK_MIB\" -ge 22000 ]; then"
                print "        OS_MIB=8192"
                print "        APP_MIB=8192"
                print "    elif [ \"$DISK_MIB\" -ge 12000 ]; then"
                print "        OS_MIB=4096"
                print "        APP_MIB=4096"
                print "    else"
                print "        die \"Install disk is too small (${DISK_MIB} MiB). Minimum supported size is about 12 GiB.\""
                print "    fi"
                print "}"
                print ""
            }
            { print }
        ' "${file}" > "${tmp}"
        chmod "${mode}" "${tmp}"
        mv "${tmp}" "${file}"
    fi

    sed -i 's|for i in /sys/block/sd\* /sys/block/nvme\*; do|for i in /sys/block/sd* /sys/block/nvme* /sys/block/mmcblk*; do|g' "${file}"

    if ! grep -q 'PARTPREFIX=$(get_partprefix "$INSTALLDISK")' "${file}"; then
        sed -i '/INSTALLDISK=\/dev\/\$INSTALLDISK/i\    PARTPREFIX=$(get_partprefix "$INSTALLDISK")' "${file}"
    fi

    if ! grep -q 'compute_partition_sizes' "${file}"; then
        die "Failed to inject compute_partition_sizes into installer init"
    fi

    sed -i '/if \[ -e \/dev\/nvme0n1 \]; then/,/fi/c\    if [ -e /dev/nvme0n1 ]; then\
        INSTALLDISK=/dev/nvme0n1\
    elif [ -e /dev/mmcblk0 ]; then\
        INSTALLDISK=/dev/mmcblk0\
    else\
        INSTALLDISK=/dev/sda\
    fi' "${file}"

    sed -i '/# clear partition table/i\    compute_partition_sizes' "${file}"
    sed -i 's|sgdisk -n 2::+16GB $INSTALLDISK|sgdisk -n 2::+${OS_MIB}M $INSTALLDISK|g' "${file}"
    sed -i 's|sgdisk -n 3::+16GB $INSTALLDISK|sgdisk -n 3::+${APP_MIB}M $INSTALLDISK|g' "${file}"

    grep -q 'mmcblk' "${file}" || die "Failed to patch installer init"
}

patch_profile_platform() {
    local file="$1"
    perl -0pi -e "s/grep nvme /grep -E 'nvme|mmcblk' /g" "${file}"
    grep -q 'nvme\|mmcblk' "${file}" || die "Failed to patch profile.platform"
}

patch_mdev_conf() {
    local file="$1"
    if ! grep -q '^mmcblk\[0-9\]p\[0-9\]' "${file}"; then
        perl -0pi -e 's|(nvme\[0-9\]n\[0-9\]p\[0-9\]\s+root:root 660 ! \*/roon/sys/storage/automount\.sh\n)|$1mmcblk[0-9]p[0-9]      root:root 660 ! */roon/sys/storage/automount.sh\n|' "${file}"
    fi
    grep -q '^mmcblk\[0-9\]p\[0-9\]' "${file}" || die "Failed to patch mdev.conf"
}

patch_automount() {
    local file="$1"
    local tmp="${file}.tmp"
    local mode
    mode=$(stat -c '%a' "${file}")

    if ! grep -q 'partition_to_disk()' "${file}"; then
        awk '
            $0 == "exec 1> >(exec logger -t storage/automount.sh) 2>&1" {
                print
                print ""
                print "partition_to_disk()"
                print "{"
                print "    case \"$1\" in"
                print "        nvme*n*p*|mmcblk*p*)"
                print "            echo \"$1\" | sed '\''s/p[0-9][0-9]*$//'\''"
                print "            ;;"
                print "        *)"
                print "            echo \"$1\" | sed '\''s/[0-9][0-9]*$//'\''"
                print "            ;;"
                print "    esac"
                print "}"
                print ""
                print "partition_number()"
                print "{"
                print "    case \"$1\" in"
                print "        nvme*n*p*|mmcblk*p*)"
                print "            echo \"$1\" | sed '\''s/^.*p//'\''"
                print "            ;;"
                print "        *)"
                print "            echo \"$1\" | sed '\''s/^[^0-9]*//'\''"
                print "            ;;"
                print "    esac"
                print "}"
                print ""
                next
            }
            { print }
        ' "${file}" > "${tmp}"
        chmod "${mode}" "${tmp}"
        mv "${tmp}" "${file}"
    fi

    awk '
        index($0, "drive=$(echo -n $1 | sed '\''s/[0-9]*$//'\'')") {
            match($0, /^[ \t]*/)
            print substr($0, RSTART, RLENGTH) "drive=$(partition_to_disk \"$1\")"
            next
        }
        index($0, "DEV=\"$(echo \"$PARTITION_DEV\" | sed '\''s/[0-9]*$//'\'')\"") {
            match($0, /^[ \t]*/)
            print substr($0, RSTART, RLENGTH) "DEV=\"$(partition_to_disk \"$PARTITION_DEV\")\""
            next
        }
        index($0, "PART=\"$(echo \"$PARTITION_DEV\" | sed '\''s/^[^0-9]*//'\'')\"") {
            match($0, /^[ \t]*/)
            print substr($0, RSTART, RLENGTH) "PART=\"$(partition_number \"$PARTITION_DEV\")\""
            next
        }
        { print }
    ' "${file}" > "${tmp}"
    chmod "${mode}" "${tmp}"
    mv "${tmp}" "${file}"

    grep -q 'mmcblk' "${file}" || die "Failed to patch automount.sh"
}

patch_format_internal_storage() {
    local file="$1"
    perl -0pi -e "s/grep nvme /grep -E 'nvme|mmcblk' /g" "${file}"
    grep -q 'nvme\|mmcblk' "${file}" || die "Failed to patch format_internal_storage"
}

rebuild_installer_initramfs() {
    log "Patching installer initramfs"
    (
        cd "${INITRAMFS_DIR}"
        bzip2 -dc "${OUTER_DIR}/initramfs" | cpio -idmu >/dev/null 2>&1
    )
    patch_installer_init "${INITRAMFS_DIR}/init"
    chmod 755 "${INITRAMFS_DIR}/init"
    (
        cd "${INITRAMFS_DIR}"
        find . -print0 | cpio --null -o -H newc -R 0:0 2>/dev/null | bzip2 -9 > "${ARTIFACT_DIR}/initramfs"
    )
}

rebuild_rootfs() {
    log "Patching installed rootfs"
    unsquashfs -d "${ROOTFS_DIR}" "${INSTALL_OS_DIR}/A/rootfs.img" >/dev/null
    patch_profile_platform "${ROOTFS_DIR}/etc/profile.platform"
    patch_mdev_conf "${ROOTFS_DIR}/etc/mdev.conf"
    patch_automount "${ROOTFS_DIR}/roon/sys/storage/automount.sh"
    patch_format_internal_storage "${ROOTFS_DIR}/roon/sys/roonconfig/format_internal_storage"
    mksquashfs "${ROOTFS_DIR}" "${ARTIFACT_DIR}/rootfs.img" -noappend -comp gzip >/dev/null
}

repack_install_os() {
    log "Repacking install-os.tar"
    cp "${KERNEL6_OUTPUT}" "${INSTALL_OS_DIR}/A/bzImage.efi"
    cp "${ARTIFACT_DIR}/rootfs.img" "${INSTALL_OS_DIR}/A/rootfs.img"
    tar --numeric-owner --owner=0 --group=0 -cf "${ARTIFACT_DIR}/install-os.tar" -C "${INSTALL_OS_DIR}" .
}

repack_image() {
    log "Writing final image"
    cp "${ORIGINAL_IMG}" "${OUTPUT_IMG}"
    copy_to_image "${OUTPUT_IMG}" "${EFI_OFFSET}" "${KERNEL5_OUTPUT}" "::bzImage.efi"
    copy_to_image "${OUTPUT_IMG}" "${EFI_OFFSET}" "${ARTIFACT_DIR}/initramfs" "::initramfs"
    copy_to_image "${OUTPUT_IMG}" "${EFI_OFFSET}" "${ARTIFACT_DIR}/install-os.tar" "::install-os.tar"
    gzip -c "${OUTPUT_IMG}" > "${OUTPUT_IMG_GZ}"
}

verify_output() {
    log "Verifying output image"
    local verify_outer="${VERIFY_DIR}/outer-bzImage.efi"
    local verify_tar="${VERIFY_DIR}/install-os.tar"
    local verify_rootfs="${VERIFY_DIR}/A/rootfs.img"
    mkdir -p "${VERIFY_DIR}/A"

    copy_from_image "${OUTPUT_IMG}" "${EFI_OFFSET}" "::bzImage.efi" "${verify_outer}"
    copy_from_image "${OUTPUT_IMG}" "${EFI_OFFSET}" "::install-os.tar" "${verify_tar}"

    grep -a -q "${KERNEL_5_VER}" "${verify_outer}" || die "Outer kernel verification failed"
    tar -xf "${verify_tar}" -C "${VERIFY_DIR}" ./A/bzImage.efi ./A/rootfs.img
    grep -a -q "${KERNEL_6_VER}" "${VERIFY_DIR}/A/bzImage.efi" || die "Inner kernel verification failed"

    unsquashfs -cat "${verify_rootfs}" etc/profile.platform | grep -q 'nvme\|mmcblk' || die "profile.platform patch missing"
    unsquashfs -cat "${verify_rootfs}" etc/mdev.conf | grep -q '^mmcblk\[0-9\]p\[0-9\]' || die "mdev.conf patch missing"
    unsquashfs -cat "${verify_rootfs}" roon/sys/storage/automount.sh | grep -Eq 'partition_to_disk|mmcblk' || die "automount.sh patch missing"
    unsquashfs -cat "${verify_rootfs}" roon/sys/roonconfig/format_internal_storage | grep -q 'nvme\|mmcblk' || die "format_internal_storage patch missing"
}

main() {
    require_tools
    prepare_dirs
    normalize_input

    ORIG_CONFIG5="${DIST_DIR}/config-${KERNEL_5_VER}-original"
    ORIG_CONFIG6="${DIST_DIR}/config-${KERNEL_6_VER}-original"
    KERNEL5_OUTPUT="${DIST_DIR}/bzImage-${KERNEL_5_VER}-emmc-from-original.efi"
    KERNEL6_OUTPUT="${DIST_DIR}/bzImage-${KERNEL_6_VER}-emmc-from-original.efi"
    CONFIG5_OUTPUT="${DIST_DIR}/config-${KERNEL_5_VER}-emmc-from-original"
    CONFIG6_OUTPUT="${DIST_DIR}/config-${KERNEL_6_VER}-emmc-from-original"

    extract_original_assets

    if [[ ${FAST_MODE} -eq 1 ]]; then
        log "Fast mode enabled, reusing cached kernels/configs"
        require_cached_kernels
    else
        local tree5 tree6
        tree5=$(fetch_kernel_tree "${KERNEL_5_VER}" "${KERNEL_5_URL}")
        tree6=$(fetch_kernel_tree "${KERNEL_6_VER}" "${KERNEL_6_URL}")

        log "Extracting original kernel configs"
        extract_ikconfig "${tree5}" "${OUTER_DIR}/bzImage.efi" "${ORIG_CONFIG5}"
        extract_ikconfig "${tree6}" "${INSTALL_OS_DIR}/A/bzImage.efi" "${ORIG_CONFIG6}"

        build_kernel "${KERNEL_5_VER}" "${tree5}" "${ORIG_CONFIG5}" "${KERNEL5_OUTPUT}" "${CONFIG5_OUTPUT}"
        build_kernel "${KERNEL_6_VER}" "${tree6}" "${ORIG_CONFIG6}" "${KERNEL6_OUTPUT}" "${CONFIG6_OUTPUT}"
    fi

    rebuild_installer_initramfs
    rebuild_rootfs
    repack_install_os
    repack_image
    verify_output

    sha256sum "${OUTPUT_IMG}" "${OUTPUT_IMG_GZ}" > "${OUTPUT_PREFIX}.sha256"

    log "Done"
    log "Image: ${OUTPUT_IMG}"
    log "Compressed image: ${OUTPUT_IMG_GZ}"
    log "SHA256: ${OUTPUT_PREFIX}.sha256"
}

main "$@"
