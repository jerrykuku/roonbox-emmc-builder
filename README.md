# Roonbox eMMC Builder

[English](./README.md) | [简体中文](./README.zh-CN.md)

Convert the original `roonbox-linuxx64-nuc4-usb-factoryreset.img.gz` into a Roon ROCK image with eMMC support.

## Features

The script automates the full workflow:

- Unpack the original recovery image
- Extract `IKCONFIG` from the original outer `5.15.72` kernel and inner `6.6.33` kernel
- Rebuild both kernels from the vendor configuration baseline
- Add `mmcblk*` detection to the installer `initramfs`
- Add `mmcblk` userspace support to the installed system `rootfs.img`
- Repack `install-os.tar`
- Replace `bzImage.efi`, `initramfs`, and `install-os.tar`
- Generate a new `.img`, `.img.gz`, and `.sha256`

## Project Layout

- `build-image.sh`: main build script
- `dist/`: local build artifacts, not committed to GitHub

## Requirements

Required tools:

- `bash`
- `curl`
- `xz`
- `fdisk`
- `cpio`
- `bzip2`
- `tar`
- `gzip`
- `mcopy`, `mdir`
- `unsquashfs`
- `mksquashfs`
- `make`
- `perl`
- `rg`
- `strings`

You also need a working kernel build environment, including compiler, linker, and common kernel build dependencies.

## Quick Start

Run from the repository directory:

```bash
cd roonbox-emmc-builder
./build-image.sh
```

Default input image:

```text
../roonbox-linuxx64-nuc4-usb-factoryreset.img.gz
```

Default output directory:

```text
./dist/
```

## Common Usage

Specify input image and output prefix:

```bash
./build-image.sh \
  --input /path/to/roonbox-linuxx64-nuc4-usb-factoryreset.img.gz \
  --output-prefix /path/to/output/roonbox-linuxx64-nuc4-usb-factoryreset-emmc
```

If the kernels are already cached and you only want to rebuild the image quickly:

```bash
./build-image.sh --fast
```

## Options

```text
--workdir <path>        Set the temporary working directory
--kernel-root <path>    Set the kernel source cache directory
--dist-dir <path>       Set the output directory
--jobs <n>              Set parallel build jobs
--fast                  Skip kernel extraction/build and reuse cached kernels and configs in dist/
--keep-work             Keep the temporary working directory
--force-rebuild         Force rebuilding both kernels
```

## Outputs

Successful runs typically produce:

- `*.img`
- `*.img.gz`
- `*.sha256`
- Two rebuilt kernels based on the original vendor config
- Two final `.config` files

## License

This project is distributed under the GNU General Public License Version 3.
